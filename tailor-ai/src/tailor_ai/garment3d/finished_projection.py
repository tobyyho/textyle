"""Photo projection on approved finished models. Geometry is immutable."""
from functools import lru_cache
from tailor_ai.garment3d.material_reconstruction import reconstruct
from tailor_ai.garment3d.canonical_panels import make_atlas as reconstructed_atlas, prepare_mapping
from tailor_ai.garment3d.finished_surface import stable_parts,add_seam_covers
from pathlib import Path
import io,json
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
from scipy.spatial import cKDTree
from tailor_ai.garment3d import garment_photo_projection as p
from tailor_ai.garment3d.hem_style import rib_evidence,resolve_style
ROOT=Path(__file__).resolve().parent
REGISTRY=json.loads((ROOT/'finished_template_registry.json').read_text())
MAPPING_VERSION='canonical_material_panels_v1'
CATALOG='finished_v1'
STYLES={(s['profile'],s['style']):s for s in REGISTRY}

def category_supported(profile,category):
    return any(s['profile']==profile and s['category']==category for s in REGISTRY)

def resolve_template(profile,category,style,front_png,back_png,front_mask,back_mask,long_sleeve_style):
    available=[s for s in REGISTRY if s['profile']==profile and s['category']==category]
    if not available:raise p.ProjectionError('No finished model is available for this garment type and avatar.')
    hem=None
    if style!='auto':
        chosen=STYLES.get((profile,style))
        if chosen is None or chosen['category']!=category:raise p.ProjectionError('The selected 3D style does not match the garment type and avatar.')
        resolution={'source':'user','requested':style,'resolved':style}
    else:
        if category=='long_sleeve_top' and len(available)>1:
            evidence={}
            for view,png,mask in [('front',front_png,front_mask),('back',back_png,back_mask)]:
                image,binary=p._load_cutout(png,mask);evidence[view]=rib_evidence(image,binary,p.torso_crop(binary))
            hem=resolve_style(long_sleeve_style,evidence);key='sweater' if hem['resolved']=='sweater' else 'long_tee'
        elif category=='trousers':key='drawstring_sweats' if profile=='male_average' else 'skinny_jeans'
        else:key=available[0]['style']
        chosen=next((s for s in available if s['style']==key),available[0])
        resolution={'source':'category_default' if len(available)==1 else 'hem_detail' if category=='long_sleeve_top' else 'default','requested':'auto','resolved':chosen['style']}
    if category=='long_sleeve_top':
        resolved='tee' if chosen['style'] in {'long_tee','button_up'} else 'sweater'
        if style=='auto' and long_sleeve_style!='auto' and long_sleeve_style!=resolved:
            raise p.ProjectionError('That long-sleeve shape is not in the finished catalog for this avatar. Choose an available 3D style.')
        hem=hem or {'requested':long_sleeve_style,'resolved':resolved,'source':'user' if style!='auto' or long_sleeve_style!='auto' else 'available_template','uncertain':False}
    return chosen,resolution,hem

@lru_cache(maxsize=32)
def calibration(profile,style):
    chosen=STYLES.get((profile,style))
    if chosen is None:raise p.ProjectionError('Unknown finished garment style for this avatar.')
    raw=(ROOT/chosen['filename']).read_bytes()
    if p.digest(raw)!=chosen['sha256']:raise p.ProjectionError('A finished model changed. Install the matching catalog before processing photos.')
    doc,blob=p.decode_glb(raw)
    if doc.get('skins') or doc.get('animations'):raise p.ProjectionError('Finished templates must be static models.')
    matrices=p.mesh_transforms(doc);parts=[];bottom=chosen['category'] in {'trousers','shorts','skirt'};trees=None
    if not bottom:
        reference_version='male_long_sleeve_photo_v1' if profile=='male_average' else 'female_long_sleeve_photo_v1'
        _,_,ref,_=p.calibration(reference_version);groups={g:[] for g in (0,1,2)}
        for part in ref:
            for g in groups:
                idx=part['index'].reshape(-1,3)[part['parts']==g].ravel()
                if len(idx):groups[g].append(part['world'][idx])
        trees={g:cKDTree(np.concatenate(points)) for g,points in groups.items()}
    for mi,mesh in enumerate(doc['meshes']):
        if mi not in matrices:raise p.ProjectionError('Finished template contains an inactive mesh; export only the final garment.')
        matrix=matrices[mi]
        for pi,pr in enumerate(mesh['primitives']):
            if pr.get('mode',4)!=4 or pr.get('targets'):raise p.ProjectionError('Unsupported finished mesh topology.')
            pos=p.accessor(doc,blob,pr['attributes']['POSITION']);normal=p.accessor(doc,blob,pr['attributes']['NORMAL']);idx=p.accessor(doc,blob,pr['indices']).ravel() if 'indices'in pr else np.arange(len(pos))
            if len(idx)%3:raise p.ProjectionError('Invalid finished triangle count.')
            world=pos@matrix[:3,:3].T+matrix[:3,3];normals=normal@np.linalg.inv(matrix[:3,:3]);normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12);centers=world[idx].reshape(-1,3,3).mean(1)
            labels=np.zeros(len(idx)//3,dtype=int) if bottom else np.stack([trees[g].query(centers)[0] for g in (0,1,2)]).argmin(0)
            parts.append({'mesh':mi,'primitive':pi,'pos':pos,'normal':normal,'index':idx,'world':world,'normals':normals,'parts':labels})
    spec=dict(chosen)
    if chosen['category']=='outerwear':spec['category']='long_sleeve_top'
    if bottom:
        spec['category']='trousers';world=np.concatenate([q['world'] for q in parts]);lo=world.min(0);hi=world.max(0);sil=Image.new('1',(512,1024));draw=ImageDraw.Draw(sil)
        for q in parts:
            xy=(q['world'][:,[0,1]]-lo[[0,1]])/(hi-lo)[[0,1]];xy[:,0]*=511;xy[:,1]=(1-xy[:,1])*1023
            for triangle in xy[q['index']].reshape(-1,3,2):draw.polygon([tuple(v) for v in triangle],fill=1)
        sil=np.asarray(sil);profiles=[]
        for region in [sil,sil&(np.arange(512)[None,:]<256),sil&(np.arange(512)[None,:]>=256)]:
            present=region.any(1);rows=np.flatnonzero(present);left=np.argmax(region,1);right=512-np.argmax(region[:,::-1],1)
            profiles.append((np.interp(np.arange(1024),rows,left[present])/511,np.interp(np.arange(1024),rows,right[present])/511))
        center=round((0-lo[0])/(hi[0]-lo[0])*511);gap=~sil[:,max(0,center-2):min(512,center+3)].any(1);candidates=np.flatnonzero(np.convolve(gap.astype(int),np.ones(12,dtype=int),'valid')==12);candidates=candidates[(candidates>150)&(candidates<950)]
        crotch=float(candidates[0]/1023) if len(candidates) else .45
        mapping={'min':lo,'max':hi,'profiles':profiles,'crotch_ratio':1.1 if chosen['category']=='skirt' else float(np.clip(crotch,.2,.9))}
    else:
        groups={g:[] for g in (0,1,2)}
        for q in parts:
            for g in groups:
                idx=q['index'].reshape(-1,3)[q['parts']==g].ravel()
                if len(idx):groups[g].append(q['world'][idx])
        if not all(groups.values()):raise p.ProjectionError('The body and sleeve regions could not be calibrated.')
        groups={g:np.concatenate(v) for g,v in groups.items()};mapping={'body_min':groups[0].min(0),'body_max':groups[0].max(0),'arms':{g:p._arm_axes(groups[g]) for g in (1,2)}}
    return chosen,spec,doc,parts,mapping

def skirt_atlas(front_png,back_png,front_mask,back_mask):
    atlas=Image.new('RGB',(2048,2048));crops={};details={}
    for vi,(view,png,mask) in enumerate([('front',front_png,front_mask),('back',back_png,back_mask)]):
        image,binary=p._load_cutout(png,mask);geom=ndi.binary_fill_holes(binary);yy,xx=np.nonzero(geom);x0,x1=int(xx.min()),int(xx.max()+1);y0,y1=int(yy.min()),int(yy.max()+1);present=geom.any(1);rows=np.flatnonzero(present);left=np.argmax(geom,1);right=geom.shape[1]-np.argmax(geom[:,::-1],1)-1;sy=np.linspace(y0,y1-1,1536);lx=np.interp(sy,rows,left[present]);rx=np.interp(sy,rows,right[present]);sx=lx[:,None]+np.linspace(0,1,1024)[None,:]*(rx-lx)[:,None];sy=np.broadcast_to(sy[:,None],sx.shape);padded=np.asarray(p._padded_rgb(image,binary));tile=np.stack([ndi.map_coordinates(padded[:,:,c].astype(float),[sy,sx],order=1,mode='nearest') for c in range(3)],axis=2);atlas.paste(Image.fromarray(np.clip(tile,0,255).astype('uint8')),(vi*1024,0));crops[view]={'x':x0/image.width,'y':y0/image.height,'w':(x1-x0)/image.width,'h':(y1-y0)/image.height};details[view]={'mode':'whole_skirt_rows','observed_pixels':int(binary.sum()),'legs':[]}
    return atlas,crops,details

def generate(profile,category,front_png,back_png,front_mask,back_mask,original_front,original_back,*,final_template_style='auto',long_sleeve_style='auto',appearance_policy=None):
    chosen,resolution,hem=resolve_template(profile,category,final_template_style,front_png,back_png,front_mask,back_mask,long_sleeve_style);_,spec,doc,parts,mapping=calibration(profile,chosen['style']);fabric={}
    mapping=prepare_mapping(mapping,parts)
    source_views={'front':p._load_cutout(front_png,front_mask),'back':p._load_cutout(back_png,back_mask)}
    observed_crops={}
    for view,(_,binary) in source_views.items():
        if category not in {'trousers','shorts','skirt'}:observed_crops[view]=p.torso_crop(binary)
        else:
            yy,xx=np.nonzero(binary);observed_crops[view]={'x':float(xx.min()/binary.shape[1]),'y':float(yy.min()/binary.shape[0]),'w':float((xx.max()-xx.min()+1)/binary.shape[1]),'h':float((yy.max()-yy.min()+1)/binary.shape[0])}
    rebuilt,appearance,_=reconstruct(source_views,observed_crops)
    from tailor_ai.garment3d.plain_fabric import apply_plain_policy
    rebuilt,appearance=apply_plain_policy(source_views,rebuilt,appearance,category,appearance_policy)
    def png(image):
        stream=io.BytesIO();image.save(stream,'PNG');return stream.getvalue()
    render_front,render_back=png(rebuilt['front']),png(rebuilt['back'])
    fabric['reconstruction']=appearance
    atlas,crops,details=reconstructed_atlas(render_front,render_back,front_mask,back_mask,spec,mapping,fabric)
    fabric['reconstruction']=appearance
    fabric['view_partition']='surface_depth_v1'
    render_parts=stable_parts(parts,mapping)
    # A new immutable version and style=None bypass shell, waistband and hem edits.
    glb=p.texture_template(atlas,spec,doc,render_parts,mapping,None)
    glb,seam_repair=add_seam_covers(glb,parts,spec,mapping,chosen['sha256'])
    meta={'templateVersion':chosen['version'],'templateSha256':chosen['sha256'],'templateCatalog':CATALOG,'bodyProfile':profile,'sourceCategory':category,'method':chosen['method'],'mappingVersion':MAPPING_VERSION,'userReviewed':False,'frontSha256':p.digest(original_front),'backSha256':p.digest(original_back),'displayFrontSha256':p.digest(front_png),'displayBackSha256':p.digest(back_png),'frontMaskSha256':p.digest(front_mask),'backMaskSha256':p.digest(back_mask),'frontCrop':crops['front'],'backCrop':crops['back'],'glbSha256':p.digest(glb),'partMapping':details,'fabricAppearance':fabric,'finalTemplateStyle':resolution,'suppliedGeometry':{'style':chosen['style'],'profile':profile,'sha256':chosen['sha256'],'preserved':True},'avatarFit':{'bypassed':True,'reason':'finished_user_geometry'},'geometryAdjustment':seam_repair,'warnings':['automatic_preview_unreviewed','template_shape_not_measured_fit','side_texture_approximate','appearance_reconstructed_estimate','hidden_print_detail_not_recovered']}
    if hem is not None:meta['hemStyle']=hem
    if resolution['source']=='default':meta['warnings'].append('shape_uses_default_choose_3d_style_to_match_your_garment')
    return glb,meta
