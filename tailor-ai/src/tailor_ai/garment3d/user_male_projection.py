"""Photo mapping on the seven supplied male models; no geometry fitting."""
from functools import lru_cache
from pathlib import Path
import copy,json,hashlib
import numpy as np
from PIL import Image,ImageDraw
from scipy.spatial import cKDTree
from tailor_ai.garment3d import garment_photo_projection as p
from tailor_ai.garment3d.hem_style import rib_evidence,resolve_style
ROOT=Path(__file__).resolve().parent
REGISTRY=json.loads((ROOT/'user_male_registry.json').read_text())
MAPPING_VERSION='calibrated_garment_parts_v6_user_male'
STYLES={s['style']:s for s in REGISTRY}
CATEGORIES={'short_sleeve_top','long_sleeve_top','trousers','shorts'}

def resolve_template(category,style,front_png,back_png,front_mask,back_mask,long_sleeve_style):
    if category not in CATEGORIES:raise p.ProjectionError('No supplied male template supports this category.')
    if style!='auto':
        spec=STYLES.get(style)
        if spec is None or spec['category']!=category:raise p.ProjectionError('The garment style does not match its category.')
        return spec,{'source':'user','requested':style,'resolved':style},None
    hem=None
    if category=='long_sleeve_top':
        evidence={}
        for view,png,mask in [('front',front_png,front_mask),('back',back_png,back_mask)]:
            im,binary=p._load_cutout(png,mask);evidence[view]=rib_evidence(im,binary,p.torso_crop(binary))
        hem=resolve_style(long_sleeve_style,evidence);key='sweater' if hem['resolved']=='sweater' else 'long_tee'
    else:key={'short_sleeve_top':'tshirt','trousers':'jeans','shorts':'shorts'}[category]
    return STYLES[key],{'source':'default' if category=='trousers' else 'category_or_hem','requested':'auto','resolved':key},hem

@lru_cache(maxsize=7)
def calibration(style):
    spec=STYLES[style];raw=(ROOT/spec['filename']).read_bytes()
    if p.digest(raw)!=spec['sha256']:raise p.ProjectionError('The supplied male template changed. Recalibration is required.')
    doc,binary=p.decode_glb(raw)
    if doc.get('skins') or doc.get('animations'):raise p.ProjectionError('Animated supplied models are unsupported.')
    matrices=p.mesh_transforms(doc);parts=[]
    is_bottom=spec['category'] in {'trousers','shorts'}
    if not is_bottom:
        _,_,reference,_=p.calibration('male_long_sleeve_photo_v1')
        groups={g:[] for g in (0,1,2)}
        for part in reference:
            for g in groups:
                index=part['index'].reshape(-1,3)[part['parts']==g].ravel()
                if len(index):groups[g].append(part['world'][index])
        trees={g:cKDTree(np.concatenate(points)) for g,points in groups.items()}
    for mi,mesh in enumerate(doc['meshes']):
        matrix=matrices[mi]
        for pi,primitive in enumerate(mesh['primitives']):
            if primitive.get('mode',4)!=4 or primitive.get('targets'):raise p.ProjectionError('Unsupported supplied mesh topology.')
            pos=p.accessor(doc,binary,primitive['attributes']['POSITION']);normal=p.accessor(doc,binary,primitive['attributes']['NORMAL'])
            index=p.accessor(doc,binary,primitive['indices']).ravel() if 'indices'in primitive else np.arange(len(pos))
            world=pos@matrix[:3,:3].T+matrix[:3,3];normals=normal@np.linalg.inv(matrix[:3,:3]);normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
            centers=world[index].reshape(-1,3,3).mean(1)
            labels=np.zeros(len(index)//3,dtype=int) if is_bottom else np.stack([trees[g].query(centers)[0] for g in (0,1,2)]).argmin(0)
            parts.append({'mesh':mi,'primitive':pi,'pos':pos,'normal':normal,'index':index,'world':world,'normals':normals,'parts':labels})
    internal=dict(spec)
    if is_bottom:
        internal['category']='trousers'
        world=np.concatenate([x['world'] for x in parts]);low=world.min(0);high=world.max(0)
        silhouette=Image.new('1',(512,1024));draw=ImageDraw.Draw(silhouette)
        for part in parts:
            xy=(part['world'][:,[0,1]]-low[[0,1]])/(high-low)[[0,1]];xy[:,0]*=511;xy[:,1]=(1-xy[:,1])*1023
            for triangle in xy[part['index']].reshape(-1,3,2):draw.polygon([tuple(x) for x in triangle],fill=1)
        silhouette=np.asarray(silhouette);profiles=[]
        for region in [silhouette,silhouette&(np.arange(512)[None,:]<256),silhouette&(np.arange(512)[None,:]>=256)]:
            valid=region.any(1);rows=np.flatnonzero(valid)
            left=np.argmax(region,1);right=512-np.argmax(region[:,::-1],1)
            profiles.append((np.interp(np.arange(1024),rows,left[valid])/511,np.interp(np.arange(1024),rows,right[valid])/511))
        # First sustained centre gap in the template's front silhouette.
        center=round((0-low[0])/(high[0]-low[0])*511)
        gap=~silhouette[:,max(0,center-2):min(512,center+3)].any(1)
        candidates=np.flatnonzero(np.convolve(gap.astype(int),np.ones(12,dtype=int),'valid')==12)
        candidates=candidates[(candidates>150)&(candidates<950)]
        crotch=float(candidates[0]/1023) if len(candidates) else float((high[1]-.785)/(high[1]-low[1]))
        mapping={'min':low,'max':high,'profiles':profiles,'crotch_ratio':float(np.clip(crotch,.2,.9))}
    else:
        groups={g:[] for g in (0,1,2)}
        for part in parts:
            for g in groups:
                idx=part['index'].reshape(-1,3)[part['parts']==g].ravel()
                if len(idx):groups[g].append(part['world'][idx])
        if not all(groups.values()):raise p.ProjectionError('Could not identify body and sleeves in supplied model.')
        groups={g:np.concatenate(v) for g,v in groups.items()}
        mapping={'body_min':groups[0].min(0),'body_max':groups[0].max(0),'arms':{g:p._arm_axes(groups[g]) for g in (1,2)}}
    return internal,doc,parts,mapping

def generate(category,front_png,back_png,front_mask,back_mask,original_front,original_back,*,male_template_style='auto',long_sleeve_style='auto'):
    chosen,resolution,hem=resolve_template(category,male_template_style,front_png,back_png,front_mask,back_mask,long_sleeve_style)
    spec,doc,parts,mapping=calibration(chosen['style']);fabric={}
    atlas,crops,details=p.make_atlas(front_png,back_png,front_mask,back_mask,spec,mapping,fabric)
    # A unique version and style=None bypass all prior shell/hem adjustments.
    glb=p.texture_template(atlas,spec,doc,parts,mapping,None)
    meta={'templateVersion':chosen['version'],'templateSha256':chosen['sha256'],'bodyProfile':'male_average','sourceCategory':category,
          'method':chosen['method'],'mappingVersion':MAPPING_VERSION,'userReviewed':False,
          'frontSha256':p.digest(original_front),'backSha256':p.digest(original_back),'displayFrontSha256':p.digest(front_png),'displayBackSha256':p.digest(back_png),
          'frontMaskSha256':p.digest(front_mask),'backMaskSha256':p.digest(back_mask),'frontCrop':crops['front'],'backCrop':crops['back'],
          'glbSha256':p.digest(glb),'partMapping':details,'fabricAppearance':fabric,
          'maleTemplateStyle':resolution,'suppliedGeometry':{'style':chosen['style'],'sha256':chosen['sha256'],'preserved':True},
          'avatarFit':{'bypassed':True,'reason':'user_supplied_fitted_geometry'},'geometryAdjustment':None,
          'warnings':['automatic_preview_unreviewed','template_shape_not_measured_fit','side_texture_approximate']}
    if category=='long_sleeve_top':
        meta['hemStyle']=hem or {'requested':long_sleeve_style,'resolved':'sweater' if chosen['style']=='sweater' else 'tee','source':'user','uncertain':False}
    if category=='trousers' and male_template_style=='auto':meta['warnings'].append('pants_style_defaults_to_jeans_choose_style_to_change')
    return glb,meta
