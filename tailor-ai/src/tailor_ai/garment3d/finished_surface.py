"""Stable photo-view partitioning and bounded additive shoulder-seam covers."""
import copy,hashlib,json,struct
from collections import defaultdict
from scipy.spatial import cKDTree
import numpy as np
from tailor_ai.garment3d import garment_photo_projection as p
VERSION='bounded_shoulder_seams_v1'

def stable_parts(parts,mapping):
 if 'body_min' not in mapping:return parts
 groups={g:[] for g in [0,1,2]}
 for part in parts:
  for g in groups:
   idx=part['index'].reshape(-1,3)[part['parts']==g].ravel()
   if len(idx):groups[g].append(part['world'][idx])
 centers={}
 for g,points in groups.items():
  cloud=np.concatenate(points);axis=np.array([0.,1.]) if g==0 else mapping['arms'][g][1]
  t=cloud[:,:2]@axis;edges=np.linspace(t.min()-1e-6,t.max()+1e-6,25);values=[];where=[]
  for a,b in zip(edges[:-1],edges[1:]):
   z=cloud[(t>=a)&(t<b),2]
   if len(z)<8:continue
   values.append(float(np.mean(np.quantile(z,[.08,.92]))));where.append((a+b)/2)
  centers[g]=(axis,np.array(where),np.array(values))
 result=[]
 for part in parts:
  votes=np.zeros((len(part['world']),3),int)
  for g in groups:
   np.add.at(votes[:,g],part['index'].reshape(-1,3)[part['parts']==g].ravel(),1)
  labels=votes.argmax(1);normal=part['normals'].copy()
  for g,(axis,where,values) in centers.items():
   selected=labels==g;world=part['world'][selected];distance=world[:,2]-np.interp(world[:,:2]@axis,where,values)
   normal[selected,2]=distance*100
  result.append(dict(part,normals=normal))
 return result

def _ears(points):
 # Ear clipping a simple, small boundary projected onto its PCA plane.
 centered=points-points.mean(0);_,_,basis=np.linalg.svd(centered,full_matrices=False);q=centered@basis[:2].T
 area=np.sum(q[:,0]*np.roll(q[:,1],-1)-np.roll(q[:,0],-1)*q[:,1]);order=list(range(len(q)))
 if area<0:order.reverse()
 triangles=[];iterations=0
 def cross(a,b):return a[0]*b[1]-a[1]*b[0]
 while len(order)>3 and iterations<len(q)*len(q):
  iterations+=1;found=False
  for i in range(len(order)):
   a,b,c=order[i-1],order[i],order[(i+1)%len(order)];u,v,w=q[[a,b,c]]
   if cross(v-u,w-v)<=1e-12:continue
   rest=[n for n in order if n not in (a,b,c)]
   inside=any(cross(v-u,q[n]-u)>=-1e-12 and cross(w-v,q[n]-v)>=-1e-12 and cross(u-w,q[n]-w)>=-1e-12 for n in rest)
   if inside:continue
   triangles.append((a,b,c));order.pop(i);found=True;break
  if not found:return []
 if len(order)==3:triangles.append(tuple(order))
 return triangles

def _spatial_triangulation(points):
 # Minimal-area triangulation for a narrow non-planar slit whose projection
 # may overlap. Every new vertex still coincides with an original boundary.
 n=len(points);cost=np.full((n,n),np.inf);split={}
 for i in range(n-1):cost[i,i+1]=0
 for length in range(2,n):
  for i in range(n-length):
   j=i+length
   for k in range(i+1,j):
    tri=points[[i,k,j]];edges=[np.linalg.norm(tri[a]-tri[b]) for a,b in [(0,1),(1,2),(2,0)]]
    area=np.linalg.norm(np.cross(tri[1]-tri[0],tri[2]-tri[0]))*.5
    value=cost[i,k]+cost[k,j]+area+.01*sum(e*e for e in edges)
    if value<cost[i,j]:cost[i,j]=value;split[i,j]=k
 result=[]
 def visit(i,j):
  if j<=i+1:return
  k=split[i,j];result.append((i,k,j));visit(i,k);visit(k,j)
 visit(0,n-1);return result

def seam_triangles(parts,mapping):
 if 'body_min' not in mapping:return [],[]
 world=np.concatenate([q['world'] for q in parts]);normals=np.concatenate([q['normals'] for q in parts]);tri=[];offset=0
 for q in parts:tri.append(q['index'].astype(np.int64).reshape(-1,3)+offset);offset+=len(q['world'])
 tri=np.concatenate(tri);keys,first,inv=np.unique(np.round(world/1e-6).astype(np.int64),axis=0,return_index=True,return_inverse=True);vertices=world[first];unique_normals=normals[first];faces=inv[tri]
 directed=np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]);edges=np.sort(directed,axis=1);
 unique,inverse,count=np.unique(edges,axis=0,return_inverse=True,return_counts=True);boundary=directed[count[inverse]==1]
 adjacency=defaultdict(list)
 for a,b in boundary:adjacency[int(a)].append(int(b));adjacency[int(b)].append(int(a))
 # Boundary contours may touch at one vertex. Split the Eulerian graph
 # into simple cycles instead of discarding the whole component at a pinch.
 pending={tuple(sorted((int(a),int(b)))) for a,b in boundary};rings=[]
 while pending:
  start=min(pending)[0];path=[];seen_at={};current=start
  while current not in seen_at:
   seen_at[current]=len(path);path.append(current)
   choices=[v for v in adjacency[current] if tuple(sorted((current,v))) in pending and (len(path)<2 or v!=path[-2])]
   if not choices:break
   current=min(choices)
  if current not in seen_at:
   # Non-closed boundaries are not safe to repair automatically.
   for a,b in zip(path,path[1:]):pending.discard(tuple(sorted((a,b))))
   if len(path)<2:pending.discard(next(iter(pending)))
   continue
  ring=path[seen_at[current]:]
  if len(ring)<3:
   pending.discard(tuple(sorted(next(iter(pending)))))
   continue
  for a,b in zip(ring,ring[1:]+ring[:1]):pending.discard(tuple(sorted((a,b))))
  rings.append(ring)
 patches=[];evidence=[];low=mapping['body_min'][1];high=mapping['body_max'][1];height=high-low;full_width=np.ptp(world[:,0])
 for ring in rings:
  if not 3<=len(ring)<=80:continue
  cloud=vertices[ring];center=cloud.mean(0);extent=np.ptp(cloud,axis=0)
  # Restrict to narrow upper lateral holes, preserving neck/hem/cuff openings.
  if cloud[:,1].min()<low+height*.36 or cloud[:,1].max()>high-.025:continue
  if not full_width*.16<abs(center[0])<full_width*.37:continue
  if extent[0]>.045 or extent[2]>.045 or extent[1]>.16:continue
  coords=vertices[ring];triangles=_ears(coords)
  if len(triangles)!=len(ring)-2:triangles=_spatial_triangulation(coords)
  # Width bound in PCA coordinates rejects broad/non-sliver holes.
  _,singular,_=np.linalg.svd(coords-coords.mean(0),full_matrices=False)
  if singular[1]/max(singular[0],1e-12)>.55:continue
  normal=unique_normals[ring].mean(0);normal/=max(np.linalg.norm(normal),1e-12)
  added=[]
  for a,b,c in triangles:
   t=coords[[a,b,c]]
   if np.dot(np.cross(t[1]-t[0],t[2]-t[0]),normal)<0:t=t[[0,2,1]]
   added.append(t)
  patches.extend(added);evidence.append({'boundary_vertices':len(ring),'bounds_min':cloud.min(0).tolist(),'bounds_max':cloud.max(0).tolist()})
 return patches,evidence

def add_seam_covers(glb,parts,spec,mapping,template_sha):
 triangles,holes=seam_triangles(parts,mapping)
 covers=[]
 from tailor_ai.garment3d.closer_fit import body,nearest
 if 'body_min' in mapping:
  avatar_triangles,avatar_tree=body(spec['profile'].split('_')[0]);low=mapping['body_min'][1];high=mapping['body_max'][1];width=np.ptp(np.concatenate([q['world'] for q in parts])[:,0])
  for part in parts:
   faces=part['index'].reshape(-1,3);points=part['world'][faces];centers=points.mean(1)
   eligible=(centers[:,1]>low+(high-low)*.36)&(centers[:,1]<high-.025)&(abs(centers[:,0])>width*.16)&(abs(centers[:,0])<width*.37)
   ids=np.flatnonzero(eligible)
   for start in range(0,len(ids),512):
    selected=ids[start:start+512];near,normals,_=nearest(centers[selected],avatar_triangles,avatar_tree);signed=np.sum((centers[selected]-near)*normals,axis=1)
    garment_normals=part['normals'][faces[selected]].mean(1)
    accepted=(signed<.004)&(signed>-.008)
    for index in selected[accepted]:
     face=points[index];extent=np.ptp(face,axis=0)
     if extent[0]>.045 or extent[1]>.16 or extent[2]>.045:continue
     if len(covers)>=1000:continue
     triangles.append(face);covers.append({'bounds_min':face.min(0).tolist(),'bounds_max':face.max(0).tolist()})
 if not triangles:return glb,None
 source_triangles=len(triangles);subdivision=3
 while source_triangles*4**subdivision>6000 and subdivision>0:subdivision-=1
 triangle_array=np.asarray(triangles,dtype=float)
 for _ in range(subdivision):
  a,b,c=triangle_array[:,0],triangle_array[:,1],triangle_array[:,2];ab=(a+b)/2;bc=(b+c)/2;ca=(c+a)/2
  triangle_array=np.concatenate([np.stack([a,ab,ca],1),np.stack([ab,b,bc],1),np.stack([ca,bc,c],1),np.stack([ab,bc,ca],1)])
 doc,binary=p.decode_glb(glb);out=copy.deepcopy(doc);payload=bytearray(binary);positions=triangle_array.astype('<f4').reshape(-1,3);normals=np.concatenate([q['normals'] for q in parts])[cKDTree(np.concatenate([q['world'] for q in parts])).query(positions)[1]];normals=normals/np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
 # A planar cover can sit inside the mannequin even with valid boundary
 # endpoints. Offset only the NEW cover vertices against the verified static
 # avatar surface, by at most 8 mm. Original garment vertices stay immutable.
 from tailor_ai.garment3d.closer_fit import body,nearest
 avatar_triangles,avatar_tree=body(spec['profile'].split('_')[0])
 cover_offset=np.zeros(len(positions))
 for start in range(0,len(positions),512):
  points=positions[start:start+512].astype(float);near,avatar_normals,_=nearest(points,avatar_triangles,avatar_tree)
  signed=np.sum((points-near)*avatar_normals,axis=1);offset=np.clip(.0015-signed,.00035,.008)
  positions[start:start+len(points)]=(points+avatar_normals*offset[:,None]).astype('<f4');cover_offset[start:start+len(points)]=offset
 # Continue the same reconstructed artwork coordinates onto the added
 # covers. The source garment positions and its existing UV layout stay intact.
 view_parts=stable_parts(parts,mapping);signed=np.concatenate([q['normals'][:,2] for q in view_parts]);near_vertex=cKDTree(np.concatenate([q['world'] for q in parts])).query(positions)[1];front=np.repeat(signed[near_vertex].reshape(-1,3).mean(1)>=0,3)
 face_centers=np.concatenate([q['world'][q['index'].reshape(-1,3)].mean(1) for q in parts]);face_labels=np.concatenate([q['parts'] for q in parts]);groups=face_labels[cKDTree(face_centers).query(positions)[1]]
 uv=p.projected_uv(positions,groups,front,spec,mapping)
 def add(array,kind,index=False):
  array=array.astype('<u4' if index else '<f4');payload.extend(b'\0'*(-len(payload)%4));view={'buffer':0,'byteOffset':len(payload),'byteLength':array.nbytes};out['bufferViews'].append(view);payload.extend(array.tobytes());a={'bufferView':len(out['bufferViews'])-1,'componentType':5125 if index else 5126,'count':len(array),'type':kind}
  if kind=='VEC3':a.update(min=array.min(0).tolist(),max=array.max(0).tolist())
  out['accessors'].append(a);return len(out['accessors'])-1
 primitive={'mode':4,'material':0,'attributes':{'POSITION':add(positions,'VEC3'),'NORMAL':add(normals,'VEC3'),'TEXCOORD_0':add(uv,'VEC2')},'indices':add(np.arange(len(positions)).reshape(-1,1),'SCALAR',True)}
 mesh=len(out['meshes']);out['meshes'].append({'name':'Bounded shoulder seam covers','primitives':[primitive]});node=len(out['nodes']);out['nodes'].append({'name':'Additive seam repair; original fit unchanged','mesh':mesh});out['scenes'][out.get('scene',0)]['nodes'].append(node)
 out['buffers'][0]['byteLength']=len(payload);encoded=json.dumps(out,separators=(',',':'),allow_nan=False).encode();encoded+=b' '*(-len(encoded)%4);payload.extend(b'\0'*(-len(payload)%4));out['buffers'][0]['byteLength']=len(payload)
 # Payload length was already 4-byte aligned because attributes are float32.
 size=28+len(encoded)+len(payload);result=struct.pack('<III',0x46546C67,2,size)+struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(payload),0x004E4942)+payload
 return result,{'version':VERSION,'mode':'additive_seam_covers','source_template_sha256':template_sha,'original_vertices_moved':0,'original_triangles_removed':0,'max_cover_offset_metres':float(cover_offset.max(initial=0)),'added_triangles':len(triangle_array),'source_triangles':source_triangles,'subdivision_steps':subdivision,'repaired_holes':len(holes),'covered_intersections':len(covers),'surface_covers':covers,'max_x_span_metres':max(h['bounds_max'][0]-h['bounds_min'][0] for h in holes+covers),'max_z_span_metres':max(h['bounds_max'][2]-h['bounds_min'][2] for h in holes+covers),'holes':holes}
