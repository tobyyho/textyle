"""Photo projection for calibrated long sleeves, trousers and female T-shirts.

Templates retain their original geometry and node transforms. New UV islands
and textures provide approximate outfit visualization, never measured fit.
"""
from __future__ import annotations
import copy
from functools import lru_cache
import hashlib
import io
import json
from pathlib import Path
import struct
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from scipy.spatial import cKDTree
from tailor_ai.garment3d.photo_projection import ProjectionError, _load_cutout
from tailor_ai.garment3d.hem_style import rib_evidence, resolve_style
from tailor_ai.garment3d.fabric_albedo import shared_base, balance_view, projection_samples, soften_upper_seams

ROOT=Path(__file__).resolve().parent
METHOD='automatic_photo_parts_v1'
MAPPING_VERSION='calibrated_garment_parts_v4_shared_fabric'
REGISTRY=json.loads((ROOT/'photo_template_registry.json').read_text())

def digest(data):return hashlib.sha256(data).hexdigest()
def find_template(profile,category):
    for spec in REGISTRY:
        if spec['profile']==profile and spec['category']==category:return spec
    raise ProjectionError('No automatic template is installed for this garment and avatar. Use manual wardrobe review.')

def decode_glb(data):
    if len(data)<28 or struct.unpack_from('<III',data)!=(0x46546C67,2,len(data)):
        raise ProjectionError('Invalid calibrated GLB.')
    n,kind=struct.unpack_from('<II',data,12)
    if kind!=0x4E4F534A or n+28>len(data):raise ProjectionError('Invalid GLB manifest.')
    doc=json.loads(data[20:20+n]);size,kind=struct.unpack_from('<II',data,20+n)
    if kind!=0x004E4942 or size+n+28!=len(data):raise ProjectionError('Invalid GLB binary data.')
    return doc,data[28+n:]

def accessor(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    if 'sparse'in a or a.get('normalized'):raise ProjectionError('Unsupported calibrated accessor.')
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    dtype=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']])
    offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    return np.ndarray((a['count'],count),dtype=dtype,buffer=binary,offset=offset,
        strides=(v.get('byteStride',count*dtype.itemsize),dtype.itemsize)).copy()

def node_matrix(node):
    if 'matrix'in node:return np.array(node['matrix'],float).reshape(4,4).T
    x,y,z,w=node.get('rotation',[0,0,0,1]);m=np.eye(4)
    m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
        [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
        [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    m[:3,:3]=m[:3,:3]@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m

def mesh_transforms(doc):
    result={}
    def visit(i,parent,chain):
        if i in chain:raise ProjectionError('Template node cycle.')
        node=doc['nodes'][i];world=parent@node_matrix(node)
        if 'mesh'in node:
            index=node['mesh']
            if index in result and not np.allclose(result[index],world):raise ProjectionError('Instanced template needs separate calibration.')
            result[index]=world
        for child in node.get('children',[]):visit(child,world,chain|{i})
    for node in doc['scenes'][doc.get('scene',0)]['nodes']:visit(node,np.eye(4),set())
    return result

def _arm_axes(points):
    p=points[:,[0,1]].astype(float);center=p.mean(0)
    _,vectors=np.linalg.eigh(np.cov((p-center).T));axis=vectors[:,-1]
    if axis[1]>0:axis=-axis
    transverse=np.array([-axis[1],axis[0]])
    a=(p-center)@axis;b=(p-center)@transverse
    return center,axis,transverse,float(a.min()),float(np.ptp(a)),float(b.min()),float(np.ptp(b))

@lru_cache(maxsize=8)
def calibration(version):
    spec=next((s for s in REGISTRY if s['version']==version),None)
    if spec is None:raise ProjectionError('Unknown garment template.')
    data=(ROOT/'photo_templates'/spec['filename']).read_bytes()
    if digest(data)!=spec['sha256']:raise ProjectionError('The fitted garment template has changed; reinstall its calibrated version.')
    doc,binary=decode_glb(data)
    if doc.get('skins') or doc.get('animations'):raise ProjectionError('Animated templates need separate calibration.')
    transforms=mesh_transforms(doc);primitives=[];seeds={0:[],1:[],2:[]}
    for mi,mesh in enumerate(doc['meshes']):
        matrix=transforms.get(mi,np.eye(4))
        for pi,primitive in enumerate(mesh['primitives']):
            if primitive.get('mode',4)!=4 or primitive.get('targets'):raise ProjectionError('Unsupported garment topology.')
            pos=accessor(doc,binary,primitive['attributes']['POSITION'])
            normal=accessor(doc,binary,primitive['attributes']['NORMAL'])
            index=accessor(doc,binary,primitive['indices']).ravel() if 'indices'in primitive else np.arange(len(pos))
            if len(index)%3:raise ProjectionError('Invalid triangle count.')
            world=pos@matrix[:3,:3].T+matrix[:3,3]
            normals=normal@np.linalg.inv(matrix[:3,:3]);normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
            label=None
            if spec['category']!='trousers':
                for group,key in enumerate(('body','left','right')):
                    if mi in spec['parts'].get(key,[]):label=group;seeds[group].append(world)
            primitives.append({'mesh':mi,'primitive':pi,'pos':pos,'normal':normal,'index':index,
                'world':world,'normals':normals,'label':label})
    if spec['category']!='trousers':
        if not all(seeds.values()):raise ProjectionError('Incomplete torso/sleeve template calibration.')
        trees={g:cKDTree(np.concatenate(v)) for g,v in seeds.items()}
        for part in primitives:
            n=len(part['index'])//3
            if part['label'] is not None:part['parts']=np.full(n,part['label'],dtype=int)
            else:
                if part['mesh'] not in spec['parts'].get('nearest',[]):raise ProjectionError('Uncalibrated garment mesh.')
                centers=part['world'][part['index']].reshape(-1,3,3).mean(1)
                part['parts']=np.stack([trees[g].query(centers)[0] for g in (0,1,2)]).argmin(0)
        groups={g:[] for g in (0,1,2)}
        for part in primitives:
            for g in groups:
                idx=part['index'].reshape(-1,3)[part['parts']==g].ravel()
                if len(idx):groups[g].append(part['world'][idx])
        groups={g:np.concatenate(v) for g,v in groups.items()}
        body=groups[0];mapping={'body_min':body.min(0),'body_max':body.max(0),
            'arms':{g:_arm_axes(groups[g]) for g in (1,2)}}
    else:
        points=np.concatenate([p['world'] for p in primitives]);low=points.min(0);high=points.max(0)
        mask=Image.new('1',(512,1024));draw=ImageDraw.Draw(mask)
        for part in primitives:
            xy=(part['world'][:,[0,1]]-low[[0,1]])/(high-low)[[0,1]]
            xy[:,0]*=511;xy[:,1]=(1-xy[:,1])*1023
            for t in xy[part['index']].reshape(-1,3,2):draw.polygon([tuple(v) for v in t],fill=1)
        mask=np.asarray(mask);profiles=[]
        for region in (mask,mask& (np.arange(512)[None,:]<256),mask&(np.arange(512)[None,:]>=256)):
            valid=region.any(1);rows=np.flatnonzero(valid)
            left=np.argmax(region,1);right=512-np.argmax(region[:,::-1],1)
            profiles.append((np.interp(np.arange(1024),rows,left[valid])/511,
                np.interp(np.arange(1024),rows,right[valid])/511))
        mapping={'min':low,'max':high,'profiles':profiles,
            'crotch_ratio':float((high[1]-spec['parts']['crotch_y'])/(high[1]-low[1]))}
        for part in primitives:part['parts']=np.zeros(len(part['index'])//3,dtype=int)
    return spec,doc,primitives,mapping

def _padded_rgb(image,mask):
    pixels=np.asarray(image)
    valid=mask & (pixels[:,:,3]>=128)
    if not valid.any():raise ProjectionError('No usable garment pixels.')
    _,nearest=ndi.distance_transform_edt(~valid,return_indices=True)
    return Image.fromarray(pixels[:,:,:3][nearest[0],nearest[1]])

def _runs(row):
    edges=np.diff(np.r_[False,row,False].astype(int));return list(zip(np.flatnonzero(edges==1),np.flatnonzero(edges==-1)))

def torso_crop(binary):
    geom=ndi.binary_fill_holes(binary)
    ys,xs=np.nonzero(geom);left,right=int(xs.min()),int(xs.max()+1);middle=(left+right)//2
    half=max(2,int((right-left)*.04));central=geom[:,middle-half:middle+half].sum(1)>half
    rows=np.flatnonzero(central)
    if not len(rows):raise ProjectionError('Could not locate the torso. Retake the garment upright.')
    bottom=int(rows[-1]+1);top=int(rows[0]);h=bottom-top
    spans=[]
    for y in range(top+int(h*.5),top+int(h*.87)):
        spans.extend((a,b) for a,b in _runs(geom[y]) if a<=middle<b)
    if len(spans)<5:raise ProjectionError('The torso mask is incomplete.')
    x0,x1=np.median(np.asarray(spans),axis=0).astype(int);bw=x1-x0
    broad=geom[:bottom].sum(1)>=bw*.65
    stable=max(4,int(h*.035));counts=np.convolve(broad.astype(int),np.ones(stable,dtype=int),mode='valid')
    starts=np.flatnonzero(counts==stable)
    if not len(starts) or bw<binary.shape[1]*.08:raise ProjectionError('Could not align the torso.')
    top=int(starts[0])
    return {'x':float(x0/binary.shape[1]),'y':float(top/binary.shape[0]),
        'w':float(bw/binary.shape[1]),'h':float((bottom-top)/binary.shape[0])}

def _body_tile(image,binary,crop,base=None):
    x,y,w,h=[int(round(crop[k]*size)) for k,size in [('x',image.width),('y',image.height),('w',image.width),('h',image.height)]]
    valid=binary[y:y+h,x:x+w]
    padded=_padded_rgb(image.crop((x,y,x+w,y+h)),valid)
    if base is not None:
        pixels=np.array(padded);pixels[~valid]=np.round(base).astype(np.uint8)
        padded=Image.fromarray(pixels)
    return padded.resize((1024,1024),Image.Resampling.LANCZOS)

def sleeve_tile(image,binary,crop,side,long):
    h,w=binary.shape;x0=crop['x']*w;x1=(crop['x']+crop['w'])*w;y0=crop['y']*h;bh=crop['h']*h;bw=x1-x0
    yy,xx=np.indices(binary.shape);candidate=binary&((xx<x0) if side=='left' else (xx>=x1))&(yy>=y0)
    candidate=ndi.binary_opening(candidate,iterations=max(1,int(bw*.006)))
    labels,n=ndi.label(candidate);sizes=np.bincount(labels.ravel());sizes[0]=0
    region=labels==int(sizes.argmax()) if n else np.zeros_like(binary)
    color=np.median(np.asarray(image)[:,:,:3][binary],axis=0).astype(np.uint8)
    info={'mode':'estimated_colour','reason':'sleeve_not_separately_visible'}
    if region.sum()<bw*bh*.012:return Image.new('RGB',(512,1024),tuple(color)),info
    ys,xs=np.nonzero(region);points=np.column_stack((xs,ys)).astype(float);center=points.mean(0)
    values,vectors=np.linalg.eigh(np.cov((points-center).T));axis=vectors[:,-1]
    upper=points[points[:,1]<=np.quantile(points[:,1],.18)];root=upper[np.argmin(np.abs(upper[:,0]-(x0 if side=='left' else x1)))]
    if np.dot(axis,center-root)<0:axis=-axis
    across=np.array([axis[1],-axis[0]])
    if across[0]<0:across=-across
    a=(points-center)@axis;b=(points-center)@across;a0,a1=np.quantile(a,[.005,.995]);b0,b1=np.quantile(b,[.005,.995])
    if a1-a0<bh*(.25 if long else .1) or values[-1]<values[0]*1.15:
        info['reason']='sleeve_direction_or_visibility_uncertain';return Image.new('RGB',(512,1024),tuple(color)),info
    rgba=np.array(image);rgba[:,:,3]=np.where(region,rgba[:,:,3],0)
    origin=center+axis*a0+across*b0;dx=across*(b1-b0)/511;dy=axis*(a1-a0)/1023
    warped=Image.fromarray(rgba).transform((512,1024),Image.Transform.AFFINE,
        (dx[0],dy[0],origin[0],dx[1],dy[1],origin[1]),resample=Image.Resampling.BILINEAR)
    visible=np.asarray(warped)[:,:,3]>200
    coverage=float(visible.mean())
    if coverage<.45:info['reason']='sleeve_area_incomplete';return Image.new('RGB',(512,1024),tuple(color)),info
    return _padded_rgb(warped,visible),{'mode':'projected_estimate','coverage':round(coverage,4),
        'shoulder_to_cuff_axis':axis.tolist(),'unseen_pixels':'nearest_observed_fabric_padding'}

def pants_panel(image,binary,crotch_ratio):
    geom=ndi.binary_fill_holes(binary);ys,xs=np.nonzero(geom);x0,x1=int(xs.min()),int(xs.max()+1);y0,y1=int(ys.min()),int(ys.max()+1)
    h=y1-y0;w=x1-x0
    broad=geom[y0:y1].sum(1)>w*.5;stable=max(4,int(h*.025));starts=np.flatnonzero(np.convolve(broad.astype(int),np.ones(stable,dtype=int),mode='valid')==stable)
    if not len(starts):raise ProjectionError('Could not locate a pants waistband.')
    y0+=int(starts[0]);h=y1-y0
    valid=[]
    for y in range(y0,y1):
        runs=[(a,b) for a,b in _runs(geom[y]) if b-a>w*.10]
        valid.append(len(runs)==2 and runs[1][0]-runs[0][1]>max(2,w*.012))
    begin=int(h*.16);end=int(h*.58);stable=max(4,int(h*.025))
    check=np.convolve(np.asarray(valid,dtype=int),np.ones(stable,dtype=int),mode='valid')
    candidates=np.flatnonzero(check[begin:end]==stable)
    if not len(candidates):raise ProjectionError('Separate both pants legs and show the waistband and hems. The photo does not expose two usable legs.')
    split=y0+begin+int(candidates[0]);lower=geom.copy();lower[:split]=False
    labels,n=ndi.label(lower);sizes=np.bincount(labels.ravel());sizes[0]=0;chosen=np.argsort(sizes)[-2:]
    if n<2 or min(sizes[chosen])<geom.sum()*.10:raise ProjectionError('Two complete pants legs are required for automatic mapping.')
    regions=sorted([labels==i for i in chosen],key=lambda r:np.nonzero(r)[1].mean())
    def row_warp(region,top,bottom,width,height):
        present=region.any(1);rows=np.flatnonzero(present)
        l=np.argmax(region,axis=1);r=region.shape[1]-np.argmax(region[:,::-1],axis=1)-1
        sy=np.linspace(top,bottom-1,height);lx=np.interp(sy,rows,l[present]);rx=np.interp(sy,rows,r[present])
        xx=lx[:,None]+np.linspace(0,1,width)[None,:]*(rx-lx)[:,None]
        yy=np.broadcast_to(sy[:,None],xx.shape)
        padded=np.asarray(_padded_rgb(image,binary & region))
        out=np.stack([ndi.map_coordinates(padded[:,:,c].astype(float),[yy,xx],order=1,mode='nearest') for c in range(3)],axis=2)
        return Image.fromarray(np.clip(out,0,255).astype(np.uint8))
    cut=int(round(crotch_ratio*1536));panel=Image.new('RGB',(1024,1536))
    waist=geom.copy();waist[split:]=False
    panel.paste(row_warp(waist,y0,split,1024,cut),(0,0))
    details=[]
    for i,region in enumerate(regions):
        ly,lx=np.nonzero(region);bottom=int(ly.max()+1)
        if bottom-split<h*.42:raise ProjectionError('A pants leg is folded or cropped. Show both complete legs.')
        panel.paste(row_warp(region,split,bottom,512,1536-cut),(i*512,cut))
        details.append({'image_side':'left' if i==0 else 'right','top':int(split),'bottom':bottom,'observed_pixels':int(region.sum())})
    crop={'x':x0/image.width,'y':y0/image.height,'w':(x1-x0)/image.width,'h':(y1-y0)/image.height}
    return panel,crop,{'mode':'waist_and_separate_leg_rows','source_crotch_y':split/image.height,'legs':details}

def make_atlas(front_png,back_png,front_mask,back_mask,spec,mapping,fabric_details=None):
    atlas=Image.new('RGB',(2048,2048));crops={};details={}
    source_views={'front':_load_cutout(front_png,front_mask),'back':_load_cutout(back_png,back_mask)}
    base,tone=shared_base(source_views) if spec['category']!='trousers' else (None,{'mode':'unchanged','reason':'pants_not_adjusted'})
    if fabric_details is not None:fabric_details.update(tone=tone,projection_samples={},unobserved_padding='shared_base_estimate' if base is not None else 'nearest_observed_fabric')
    for vi,(view,png,mask) in enumerate([('front',front_png,front_mask),('back',back_png,back_mask)]):
        original,binary=source_views[view]
        image=balance_view(original,binary,base)
        if spec['category']=='trousers':
            panel,crop,info=pants_panel(image,binary,mapping['crotch_ratio']);atlas.paste(panel,(vi*1024,0));details[view]=info
        else:
            crop=torso_crop(binary);sampling,neck=projection_samples(original,binary,crop,base,view)
            if fabric_details is not None:fabric_details['projection_samples'][view]=neck
            atlas.paste(soften_upper_seams(_body_tile(image,sampling,crop,base),base),(vi*1024,0));info={}
            for si,side in enumerate(('left','right')):
                tile,observation=sleeve_tile(image,binary,crop,side,spec['category']=='long_sleeve_top')
                if base is not None and observation['mode']=='estimated_colour':
                    tile=Image.new('RGB',tile.size,tuple(np.round(base).astype(int)))
                    observation['colour_source']='shared_observed_base'
                atlas.paste(tile,(vi*1024+si*512,1024));info[side]=observation
            details[view]=info
        crops[view]=crop
    return atlas,crops,details

def projected_uv(points,parts,front,spec,mapping):
    if mapping.get('canonical_panels_version'):
        from tailor_ai.garment3d.canonical_panels import projected_uv as canonical_uv
        return canonical_uv(points,parts,front,spec,mapping)
    uv=np.empty((len(points),2),dtype='<f4')
    if spec['category']=='trousers':
        low,high=mapping['min'],mapping['max'];xy=(points[:,[0,1]]-low[[0,1]])/(high-low)[[0,1]]
        y=np.clip(1-xy[:,1],0,1);row=y*1023;full_l,full_r=mapping['profiles'][0]
        left=np.interp(row,np.arange(1024),full_l);right=np.interp(row,np.arange(1024),full_r)
        u=np.clip((xy[:,0]-left)/np.maximum(right-left,1e-6),0,1)
        for side,profile in enumerate(mapping['profiles'][1:]):
            selected=xy[:,0]<.5 if side==0 else xy[:,0]>=.5
            l=np.interp(row[selected],np.arange(1024),profile[0]);r=np.interp(row[selected],np.arange(1024),profile[1])
            leg=(side+np.clip((xy[selected,0]-l)/np.maximum(r-l,1e-6),0,1))*.5
            mix=np.clip((y[selected]-mapping['crotch_ratio']+.025)/.05,0,1);mix=mix*mix*(3-2*mix)
            u[selected]=u[selected]*(1-mix)+leg*mix
        uv[:,0]=(np.where(front,0,1024)+2+np.where(front,u,1-u)*1020)/2048
        uv[:,1]=(2+y*1532)/2048
        return uv
    body=parts==0;low=mapping['body_min'];high=mapping['body_max']
    x=np.clip((points[body,0]-low[0])/(high[0]-low[0]),0,1);y=np.clip((high[1]-points[body,1])/(high[1]-low[1]),0,1)
    uv[body,0]=(np.where(front[body],0,1024)+2+np.where(front[body],x,1-x)*1020)/2048
    uv[body,1]=(2+y*1020)/2048
    for g in (1,2):
        chosen=parts==g
        center,axis,across,a0,aw,b0,bw=mapping['arms'][g];p=points[chosen][:,[0,1]]-center
        t=np.clip(((p@axis)-a0)/aw,0,1);s=np.clip(((p@across)-b0)/bw,0,1)
        image_right=np.where(front[chosen],g==2,g==1)
        uv[chosen,0]=(np.where(front[chosen],0,1024)+image_right.astype(int)*512+2+np.where(front[chosen],s,1-s)*508)/2048
        uv[chosen,1]=(1026+t*1020)/2048
    return uv

def shell_positions(spec, doc, primitives):
    """Four millimetres of calibrated clearance on the male sweater shell.

    Coincident vertices share one world-space displacement, so separate sleeve
    and body meshes do not pull apart at their seams. All other templates use
    exact original positions. Original assets on disk are never modified.
    """
    if spec['version']!='male_long_sleeve_photo_v1':
        return [part['pos'] for part in primitives]
    matrices=mesh_transforms(doc)
    world=np.concatenate([part['world'] for part in primitives])
    normals=np.concatenate([part['normals'] for part in primitives])
    _,groups=np.unique(np.round(world/1e-6).astype(np.int64),axis=0,return_inverse=True)
    summed=np.zeros((int(groups.max())+1,3))
    np.add.at(summed,groups,normals)
    length=np.linalg.norm(summed,axis=1,keepdims=True)
    # Opposing coincident lining normals have no reliable outward direction.
    direction=np.divide(summed,length,out=np.zeros_like(summed),where=length>1e-6)
    delta=direction[groups]*.004
    result=[];offset=0
    for part in primitives:
        n=len(part['pos']);m=matrices.get(part['mesh'],np.eye(4))
        local_delta=delta[offset:offset+n]@np.linalg.inv(m[:3,:3]).T
        result.append((part['pos']+local_delta).astype('<f4'));offset+=n
    return result

def styled_positions(spec,doc,primitives,style):
    positions=shell_positions(spec,doc,primitives)
    if style is None or spec['version']!='male_long_sleeve_photo_v1':return positions
    rows=json.loads((ROOT/'male_hip_envelope.json').read_text())['rows']
    heights=np.array([r['y'] for r in rows]);centers=np.array([r['center_z'] for r in rows]);radii=np.array([r['radius'] for r in rows])
    matrices=mesh_transforms(doc);result=[]
    for part,pos in zip(primitives,positions,strict=True):
        matrix=matrices[part['mesh']];world=pos@matrix[:3,:3].T+matrix[:3,3]
        # The calibrated male asset's front waistband and lining were exported
        # 150 mm above its rear hem. Align both pieces before hip clearance.
        if style=='sweater' and part['mesh'] in (6,7):
            world[:,1]-=.150-.060*np.clip((world[:,1]-1.071)/.065,0,1)
        index=part['index'].reshape(-1,3);body=np.zeros(len(pos),bool)
        body[index[part['parts']==0].ravel()]=True
        selected=body&(world[:,1]<1.17)
        p=world[selected].copy();y=p[:,1];center=np.interp(y,heights,centers)
        theta=np.arctan2(p[:,2]-center,p[:,0]);angle=(theta+np.pi)*72/(2*np.pi)
        lo=np.floor(angle).astype(int)%72;f=angle-np.floor(angle)
        layer=np.clip(np.searchsorted(heights,y)-1,0,len(heights)-2);mix=np.clip((y-heights[layer])/(heights[layer+1]-heights[layer]),0,1)
        radius0=radii[layer,lo]*(1-f)+radii[layer,(lo+1)%72]*f
        radius1=radii[layer+1,lo]*(1-f)+radii[layer+1,(lo+1)%72]*f
        target=radius0*(1-mix)+radius1*mix+.006
        radial=np.hypot(p[:,0],p[:,2]-center)
        fade=np.clip((1.17-y)/.035,0,1);extra=np.maximum(0,target-radial)*fade
        p[:,0]+=np.cos(theta)*extra;p[:,2]+=np.sin(theta)*extra
        world[selected]=p
        # Fill only the camera-right front hem join. Retain the original
        # curved lower edge and every vertex on the left half.
        if style=='sweater' and part['mesh']==6:
            right=world[:,0]>.070
            ys=np.arange(.91,1.061,.005)
            observed=np.array([world[np.abs(world[:,1]-y)<.012,0].max() if np.any(np.abs(world[:,1]-y)<.012) else .174 for y in ys])
            edge=np.interp(world[right,1],ys,observed)
            target=.193+.020*np.clip((world[right,1]-.92)/.08,0,1)
            weight=np.clip((world[right,0]-.070)/np.maximum(edge-.070,.01),0,1)
            world[right,0]+=np.maximum(target-edge,0)*weight
        result.append(((world-matrix[:3,3])@np.linalg.inv(matrix[:3,:3]).T).astype('<f4'))
    return result

def texture_template(atlas,spec,doc,primitives,mapping,style=None):
    out=copy.deepcopy(doc);out['bufferViews']=[];out['accessors']=[]
    out.pop('extensionsUsed',None);out.pop('extensionsRequired',None)
    out['asset']={'version':'2.0','generator':spec['version']+'/'+MAPPING_VERSION}
    out['materials']=[{'name':'Automatic calibrated photo projection','doubleSided':True,
        'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':.85}}]
    out['textures']=[{'source':0,'sampler':0}];out['samplers']=[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}]
    payload=bytearray()
    def view(data,target=None):
        payload.extend(b'\0'*(-len(payload)%4));v={'buffer':0,'byteOffset':len(payload),'byteLength':len(data)}
        if target is not None:v['target']=target
        out['bufferViews'].append(v);payload.extend(data);return len(out['bufferViews'])-1
    def add(values,kind,indices=False,bounds=False):
        values=values.astype('<u4' if indices else '<f4');v=view(values.tobytes(),34963 if indices else 34962)
        a={'bufferView':v,'componentType':5125 if indices else 5126,'count':len(values),'type':kind}
        if bounds:a.update(min=values.min(0).tolist(),max=values.max(0).tolist())
        out['accessors'].append(a);return len(out['accessors'])-1
    positions=styled_positions(spec,doc,primitives,style)
    omitted=set(([3,6,7] if spec['profile']=='male_average' else [2,3]) if style=='tee' and spec['category']=='long_sleeve_top' else [])
    mesh_map={i:len([j for j in range(i) if j not in omitted]) for i in range(len(doc['meshes'])) if i not in omitted}
    out['meshes']=[copy.deepcopy(m) for i,m in enumerate(doc['meshes']) if i not in omitted]
    for node in out['nodes']:
        if 'mesh' in node:
            if node['mesh'] in omitted:node.pop('mesh')
            else:node['mesh']=mesh_map[node['mesh']]
    for part,position in zip(primitives,positions,strict=True):
        if part['mesh'] in omitted:continue
        idx=part['index'];front=np.repeat(part['normals'][idx].reshape(-1,3,3)[:,:,2].mean(1)>=0,3)
        group=np.repeat(part['parts'],3)
        keys,inverse=np.unique(np.column_stack((idx,group,front.astype(int))),axis=0,return_inverse=True)
        vertex=keys[:,0].astype(int);g=keys[:,1].astype(int);f=keys[:,2].astype(bool)
        uv_world=part['world'][vertex].copy()
        if style=='sweater' and spec['version']=='male_long_sleeve_photo_v1' and part['mesh'] in (6,7):
            uv_world[:,1]-=.150-.060*np.clip((uv_world[:,1]-1.071)/.065,0,1)
        uv=projected_uv(uv_world,g,f,spec,mapping)
        out['meshes'][mesh_map[part['mesh']]]['primitives'][part['primitive']]={'mode':4,'material':0,
            'indices':add(inverse.reshape(-1,1),'SCALAR',True),
            'attributes':{'POSITION':add(position[vertex],'VEC3',bounds=True),
                'NORMAL':add(part['normal'][vertex],'VEC3'),'TEXCOORD_0':add(uv,'VEC2')}}
    stream=io.BytesIO();atlas.save(stream,'PNG')
    out['images']=[{'mimeType':'image/png','bufferView':view(stream.getvalue())}]
    out['buffers']=[{'byteLength':len(payload)}]
    encoded=json.dumps(out,separators=(',',':'),allow_nan=False).encode();encoded+=b' '*(-len(encoded)%4);payload.extend(b'\0'*(-len(payload)%4))
    size=28+len(encoded)+len(payload)
    if size>24*1024*1024:raise ProjectionError('The generated texture is too large; use less detailed, lower-resolution photos.')
    return struct.pack('<III',0x46546C67,2,size)+struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(payload),0x004E4942)+payload

def generate(profile,category,front_png,back_png,front_mask,back_mask,original_front,original_back,long_sleeve_style=None):
    spec=find_template(profile,category);spec,doc,primitives,mapping=calibration(spec['version'])
    fabric={}
    atlas,crops,details=make_atlas(front_png,back_png,front_mask,back_mask,spec,mapping,fabric)
    hem=None
    if category=='long_sleeve_top' and long_sleeve_style is not None:
        evidence={}
        for view,png,mask in [('front',front_png,front_mask),('back',back_png,back_mask)]:
            image,binary=_load_cutout(png,mask);evidence[view]=rib_evidence(image,binary,crops[view])
        try:hem=resolve_style(long_sleeve_style,evidence)
        except ValueError as error:raise ProjectionError(str(error)) from error
    glb=texture_template(atlas,spec,doc,primitives,mapping,hem['resolved'] if hem else None)
    sidecar={'templateVersion':spec['version'],'templateSha256':spec['sha256'],'bodyProfile':profile,'sourceCategory':category,
        'method':METHOD,'mappingVersion':MAPPING_VERSION,'userReviewed':False,
        'frontSha256':digest(original_front),'backSha256':digest(original_back),
        'displayFrontSha256':digest(front_png),'displayBackSha256':digest(back_png),
        'frontMaskSha256':digest(front_mask),'backMaskSha256':digest(back_mask),
        'frontCrop':crops['front'],'backCrop':crops['back'],'glbSha256':digest(glb),'partMapping':details,'fabricAppearance':fabric,
        'geometryAdjustment':{'version':'male_sweater_clearance_v1','max_world_metres':.004}
            if spec['version']=='male_long_sleeve_photo_v1' else None,
        'warnings':['automatic_preview_unreviewed','template_shape_not_measured_fit','side_texture_approximate']}
    if profile=='male_average' and hem is not None and hem['resolved']=='sweater':
        sidecar['waistbandAlignment']={'version':'male_right_hem_fill_v3','front_band_vertical_offset_metres':-.150}
    if hem is not None:
        sidecar['hemStyle']=hem
        sidecar['geometryAdjustment']={'version':'male_hip_clearance_v2' if profile=='male_average' else 'female_hem_style_v1',
            'waistband_present':hem['resolved']=='sweater','fit_is_estimated':True,
            'max_calibrated_band_adjustment_metres':.085 if profile=='male_average' else 0}
        if hem['uncertain']:sidecar['warnings'].append('long_sleeve_style_uncertain_plain_hem_used')
    if category!='trousers' and any(p['mode']=='estimated_colour' for v in details.values() for p in v.values()):
        sidecar['warnings'].append('some_sleeve_regions_use_estimated_colour')
    return glb,sidecar
