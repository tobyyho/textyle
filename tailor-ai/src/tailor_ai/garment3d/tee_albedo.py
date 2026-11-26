"""Flat fabric plus confidently different-colour print for solid-colour tees.

This intentionally abstains for neutral or strongly patterned fabrics. Saved
source media is immutable; these are generated appearance estimates only.
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from tailor_ai.garment3d.fabric_albedo import balance_view
VERSION='solid-tee-print-layer-v1'

def prepare_tee(views,crops,base):
    if base is None or np.linalg.norm(base/base.sum()-1/3)<.045:
        return None,{'mode':'photo_fallback','reason':'solid_colour_not_separable_from_shading','version':VERSION}
    result={};evidence={}
    for name,(image,mask) in views.items():
        a=np.array(image);rgb=a[:,:,:3].astype(float);h,w=mask.shape;c=crops[name]
        x,y,bw,bh=[int(round(c[k]*n)) for k,n in [('x',w),('y',h),('w',w),('h',h)]]
        yy,xx=np.indices(mask.shape)
        torso=(xx>=x)&(xx<x+bw)&(yy>=y)&(yy<y+bh)
        safe=ndi.binary_erosion(mask,iterations=3)&torso&(xx>x+bw*.03)&(xx<x+bw*.97)&(yy>y+bh*.18)&(yy<y+bh*.96)
        chroma=rgb/np.maximum(1,rgb.sum(2,keepdims=True));distance=np.linalg.norm(chroma-base/base.sum(),axis=2)
        gray=rgb.mean(2);local=ndi.gaussian_filter(gray,10)
        saturation=np.linalg.norm(chroma-1/3,axis=2);base_saturation=np.linalg.norm(base/base.sum()-1/3)
        hue=np.sum((chroma-1/3)*(base/base.sum()-1/3),axis=2)/np.maximum(saturation*base_saturation,1e-8)
        dark_pigment=(saturation<base_saturation*.85)|((hue<.8)&(distance>.08))
        dark_detail=(gray<local*.78-2)&dark_pigment
        pigment=(gray>=base.mean()*.85)|dark_detail
        ink=ndi.binary_opening(safe&(gray<local*.70-3),structure=np.ones((1,3),bool))
        candidate=(safe&(distance>.055)&(gray>15)&pigment)|ink
        labels,n=ndi.label(candidate);matte=np.zeros(mask.shape,float);retained=0
        for label,box in enumerate(ndi.find_objects(labels),start=1):
            if box is None:continue
            iy,ix=np.nonzero(labels[box]==label);iy+=box[0].start;ix+=box[1].start
            if len(ix)<4:continue
            width=ix.max()-ix.min()+1;height=iy.max()-iy.min()+1
            if height>bh*.025 and height>width*2.2:continue
            if np.median(distance[iy,ix])<.075 and ink[iy,ix].mean()<.60:continue
            if len(ix)>bw*bh*.20:
                return None,{'mode':'photo_fallback','reason':'large_contrasting_panel_or_pattern','version':VERSION}
            strength=np.maximum(np.clip((distance[iy,ix]-.045)/.035,0,1),ink[iy,ix].astype(float))
            matte[iy,ix]=strength;retained+=len(ix)
        seeds=matte>0
        if seeds.any():
            near=ndi.distance_transform_edt(~seeds)<max(3,bw*.018)
            grown=near&safe&(gray<local*.78-2)
            alpha=np.clip((local-gray)/np.maximum(1,local*.40),0,1)
            matte[grown]=np.maximum(matte[grown],alpha[grown])
            retained=int((matte>0).sum())
        # Reject narrow vertical camera folds after growth as well.
        final_labels,_=ndi.label(matte>0)
        for label,box in enumerate(ndi.find_objects(final_labels),start=1):
            if box is None:continue
            height=box[0].stop-box[0].start;width=box[1].stop-box[1].start
            if height>bh*.025 and height>width*2.2:matte[final_labels==label]=0
        # Group nearby strokes so separate letters belong to one design.
        # Tiny isolated high-pass fragments are camera noise unless supported
        # spatially by a larger graphic. Keep the observed source for review.
        groups,_=ndi.label(ndi.binary_dilation(matte>0,iterations=3))
        strong=[];minimum=max(64,int((torso&mask).sum()*.002))
        for label,box in enumerate(ndi.find_objects(groups),start=1):
            if box is None:continue
            region=(groups[box]==label)&(matte[box]>0)
            if region.sum()>=minimum:strong.append(box)
        supported=np.zeros(mask.shape,bool)
        for box in strong:
            y1=max(0,box[0].start-int(bh*.25));y2=min(h,box[0].stop+int(bh*.04))
            x1=max(0,box[1].start-int(bw*.08));x2=min(w,box[1].stop+int(bw*.08))
            supported[y1:y2,x1:x2]=True
        matte[~supported]=0
        retained=int((matte>0).sum())
        # Dense small fragments across most of the torso can be a real all-over
        # pattern. Preserve the photo rather than simplify an uncertain design.
        if retained>max(1,safe.sum())*.20:
            return None,{'mode':'photo_fallback','reason':'dense_pattern','version':VERSION}
        out=np.array(balance_view(image,mask,base));flat=np.broadcast_to(base,rgb.shape)
        printed=flat*(1-matte[:,:,None])+rgb*matte[:,:,None]
        out[:,:,:3][torso]=np.clip(np.round(printed[torso]),0,255).astype(np.uint8)
        result[name]=Image.fromarray(out)
        evidence[name]={'retained_print_pixels':retained,'torso_pixels':int((torso&mask).sum()),'print_is_estimated':True}
    return result,{'mode':'flat_fabric_plus_print','base_rgb':np.round(base).astype(int).tolist(),'views':evidence,'version':VERSION}
