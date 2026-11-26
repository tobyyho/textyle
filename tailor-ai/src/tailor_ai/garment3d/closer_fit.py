"""Conservative static-avatar clearance adjustment for generated previews."""
from functools import lru_cache
from pathlib import Path
import hashlib,json,struct
import numpy as np
from scipy.spatial import cKDTree
from tailor_ai.garment3d.garment_photo_projection import decode_glb,accessor,mesh_transforms
ROOT=Path(__file__).resolve().parent
VERSION='avatar_closer_fit_v1'
BODY_HASHES={'male': '7a7f64d38306734b5f6f8ef889583c10a007f10f084a3a17794f5c7385b447d5', 'female': '21eaa4d8905584a163f0d23203403d6b3aafee9d2d9aa016e03bbf5cdac62cd3'}
@lru_cache(maxsize=2)
def body(gender):
    path=ROOT/(gender+'_body.npz')
    if hashlib.sha256(path.read_bytes()).hexdigest()!=BODY_HASHES[gender]:raise ValueError('Avatar clearance data changed')
    triangles=np.load(path)['triangles'].astype(float)
    return triangles,cKDTree(triangles.mean(1))

def nearest(points,triangles,tree):
    ids=tree.query(points,k=32)[1];t=triangles[ids];a,b,c=t[:,:,0],t[:,:,1],t[:,:,2];q=points[:,None,:]
    ab=b-a;ac=c-a;n=np.cross(ab,ac);n/=np.maximum(np.linalg.norm(n,axis=2,keepdims=True),1e-10)
    signed=np.sum((q-a)*n,axis=2);projected=q-signed[:,:,None]*n
    v=projected-a;d00=np.sum(ab*ab,axis=2);d01=np.sum(ab*ac,axis=2);d11=np.sum(ac*ac,axis=2);d20=np.sum(v*ab,axis=2);d21=np.sum(v*ac,axis=2);den=d00*d11-d01*d01
    u=(d11*d20-d01*d21)/np.maximum(den,1e-20);w=(d00*d21-d01*d20)/np.maximum(den,1e-20)
    candidates=[projected];distances=[np.where((u>=0)&(w>=0)&(u+w<=1),np.sum((q-projected)**2,axis=2),np.inf)]
    for x,y in [(a,b),(b,c),(c,a)]:
        edge=y-x;f=np.clip(np.sum((q-x)*edge,axis=2)/np.maximum(np.sum(edge*edge,axis=2),1e-20),0,1)
        point=x+edge*f[:,:,None];candidates.append(point);distances.append(np.sum((q-point)**2,axis=2))
    distances=np.stack(distances,axis=2);pick=distances.argmin(2)
    near=np.take_along_axis(np.stack(candidates,axis=2),pick[:,:,None,None],axis=2)[:,:,0]
    dist=distances.min(2);j=dist.argmin(1);row=np.arange(len(points))
    return near[row,j],n[row,j],np.sqrt(dist[row,j])

def fitted(points,profile,category,style):
    gender={'male_average':'male','female_average':'female'}.get(profile)
    if gender is None:raise ValueError('Unsupported fitted avatar')
    if category not in {'short_sleeve_top','long_sleeve_top','trousers'}:raise ValueError('Unsupported fitted category')
    triangles,tree=body(gender);out=points.copy();total=0;maximum=0.
    for start in range(0,len(points),800):
        p=points[start:start+800];near,n,distance=nearest(p,triangles,tree)
        signed=np.sum((p-near)*n,axis=1)
        direction=near-p;direction[:,1]=0;length=np.linalg.norm(direction,axis=1)
        direction/=np.maximum(length[:,None],1e-12)
        projection=-np.sum(direction*n,axis=1)
        collar=(p[:,1]>(1.585 if gender=='female' else 1.60))&(np.hypot(p[:,0],p[:,2]+.015)<.14)&(category!='trousers')
        ease=np.where(collar,.004,.012 if style=='sweater' else .008)
        amount=np.minimum(np.maximum(distance-ease,0)*np.where(collar,.85,.35),np.where(collar,.025,.008))
        # Protect hem and cuff heights; no Y coordinate ever changes.
        support=np.clip((p[:,1]-1.12)/.10,0,1) if category!='trousers' else np.minimum(np.clip((p[:,1]-.15)/.10,0,1),np.clip((1.02-p[:,1])/.08,0,1))
        amount*=support
        amount=np.minimum(amount,np.maximum(signed-ease,0)/np.maximum(projection,1e-12))
        active=(signed>ease)&(distance<.12)&(projection>.15)&(length>1e-8)
        amount=np.where(active,amount,0)
        moved=p+direction*amount[:,None]
        # Recheck against the nearby avatar surfaces after movement. Back off
        # any candidate whose local nearest surface would be crossed.
        near2,n2,dist2=nearest(moved,triangles,tree)
        signed2=np.sum((moved-near2)*n2,axis=1)
        reject=(amount>0)&((signed2<ease-.0005)|(dist2<ease-.0005))
        moved[reject]=p[reject];amount[reject]=0
        out[start:start+len(p)]=moved;total+=int((amount>1e-7).sum());maximum=max(maximum,float(amount.max(initial=0)))
    return out,{'version':VERSION,'vertices_adjusted':total,'max_displacement_metres':maximum,'neck_clearance_target_metres':.004,'static_avatar_only':True,'measured_fit':False}

def fit_glb(data,profile,category,style=None):
    doc,binary=decode_glb(data);payload=bytearray(binary);matrices=mesh_transforms(doc);items=[];worlds=[]
    for mi,mesh in enumerate(doc['meshes']):
        matrix=matrices[mi]
        for primitive in mesh['primitives']:
            index=primitive['attributes']['POSITION'];pos=accessor(doc,binary,index)
            world=pos@matrix[:3,:3].T+matrix[:3,3];items.append((index,matrix,len(pos)));worlds.append(world)
    world=np.concatenate(worlds)
    _,first,inverse=np.unique(np.round(world/1e-6).astype(np.int64),axis=0,return_index=True,return_inverse=True)
    unique=world[first];adjusted,details=fitted(unique,profile,category,style)
    delta=(adjusted-unique)[inverse]
    def quantized_world():
        chunks=[];offset=0
        for index,matrix,n in items:
            original_local=accessor(doc,binary,index)
            local=(original_local+delta[offset:offset+n]@np.linalg.inv(matrix[:3,:3]).T).astype('<f4')
            chunks.append(local@matrix[:3,:3].T+matrix[:3,3]);offset+=n
        return np.concatenate(chunks)
    new_world=quantized_world()
    # Reject local foldovers while keeping coincident seam vertices together.
    offset=0;faces=[]
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            count=doc['accessors'][primitive['attributes']['POSITION']]['count']
            ids=(accessor(doc,binary,primitive['indices']).ravel() if 'indices' in primitive else np.arange(count)).reshape(-1,3)
            faces.append(ids+offset);offset+=count
    faces=np.concatenate(faces)
    original=np.cross(world[faces[:,1]]-world[faces[:,0]],world[faces[:,2]]-world[faces[:,0]])
    for _ in range(256):
        changed=np.cross(new_world[faces[:,1]]-new_world[faces[:,0]],new_world[faces[:,2]]-new_world[faces[:,0]])
        bad=(np.sum(changed*original,axis=1)<.10*np.sum(original*original,axis=1))&(np.linalg.norm(original,axis=1)>1e-12)
        if not bad.any():break
        groups=np.unique(inverse[faces[bad].ravel()]);delta[np.isin(inverse,groups)]=0;new_world=quantized_world()
    else:
        delta[:]=0;new_world=world.copy()
    details['vertices_adjusted']=int((np.linalg.norm(delta,axis=1)>1e-7).sum())
    details['max_displacement_metres']=float(np.linalg.norm(delta,axis=1).max(initial=0))
    offset=0;written=set()
    for index,matrix,n in items:
        local=(accessor(doc,binary,index)+delta[offset:offset+n]@np.linalg.inv(matrix[:3,:3]).T).astype('<f4');offset+=n
        if index in written:raise ValueError('Shared position accessor needs explicit calibration')
        written.add(index);a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        if a['componentType']!=5126 or a['type']!='VEC3':raise ValueError('Unsupported fitted positions')
        arr=np.ndarray((n,3),dtype='<f4',buffer=payload,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',12),4));arr[:]=local
        a['min']=local.min(0).tolist();a['max']=local.max(0).tolist()
    encoded=json.dumps(doc,separators=(',',':'),allow_nan=False).encode();encoded+=b' '*(-len(encoded)%4)
    result=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(payload))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(payload),0x004e4942)+payload
    return result,details
