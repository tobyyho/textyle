"""Conservative shared fabric tone; source media is never modified.

Correct only colours close to a dominant fabric chromaticity. Distinct panels,
bright prints and dark graphics remain observed pixels. This is an approximate
albedo correction, not illumination recovery or design reconstruction.
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
VERSION='shared-fabric-albedo-v1'

def shared_base(views):
    samples=[]
    for image,mask in views.values():
        rgb=np.asarray(image)[:,:,:3].astype(float)
        safe=ndi.binary_erosion(mask,iterations=3)
        # Lower/central samples avoid inner neckline labels dominating evidence.
        y,x=np.nonzero(safe)
        if not len(y):return None,{'mode':'unchanged','reason':'no_safe_fabric'}
        safe[:int(y.min()+(y.max()-y.min())*.20)]=False
        pix=rgb[safe][::max(1,int(safe.sum()/30000))]
        samples.append(pix)
    allrgb=np.concatenate(samples);valid=(allrgb.mean(1)>25)&(allrgb.mean(1)<235)
    if valid.mean()<.65:return None,{'mode':'unchanged','reason':'insufficient_dominant_colour'}
    rgb=allrgb[valid];chroma=rgb/np.maximum(1,rgb.sum(1,keepdims=True))
    key=np.round(chroma[:,:2]*32).astype(int)
    unique,count=np.unique(key,axis=0,return_counts=True);peak=unique[count.argmax()]/32
    near=np.linalg.norm(chroma[:,:2]-peak,axis=1)<.045
    if near.mean()<.65:return None,{'mode':'unchanged','reason':'multiple_fabric_colours'}
    center=np.median(chroma[near],axis=0)
    distance=np.linalg.norm(chroma-center,axis=1)
    near=distance<.035
    if near.mean()<.65:return None,{'mode':'unchanged','reason':'multiple_fabric_colours'}
    fabric=rgb[near]
    brightness=fabric.mean(1);lit=np.percentile(brightness,65)
    representative=fabric[(brightness>=lit*.90)&(brightness<=lit*1.10)]
    base=np.median(representative if len(representative) else fabric,axis=0)
    # Each view must independently support the same base. A red front and blue
    # back must not be forced into one colour by pixel-count imbalance.
    for sample in samples:
        c=sample/np.maximum(1,sample.sum(1,keepdims=True))
        if (np.linalg.norm(c-center,axis=1)<.035).mean()<.60:
            return None,{'mode':'unchanged','reason':'views_have_different_base_colours'}
    return base,{'mode':'shared_base_preserve_details','base_rgb':np.round(base).astype(int).tolist(),
        'dominant_fraction':round(float(near.mean()),4),
        'strength':0 if np.linalg.norm(base/base.sum()-1/3)<.04 else .65,'version':VERSION}

def balance_view(image,mask,base):
    if base is None or np.linalg.norm(base/base.sum()-1/3)<.04:return image
    pixels=np.array(image);rgb=pixels[:,:,:3].astype(float)
    # Estimate cloth membership from gently smoothed colour, then blend the
    # original RGB. This avoids speckled correction in noisy, shadowed photos.
    smooth=ndi.gaussian_filter(rgb,sigma=(1.5,1.5,0))
    chroma=smooth/np.maximum(1,smooth.sum(2,keepdims=True));center=base/max(1,base.sum())
    distance=np.linalg.norm(chroma-center,axis=2);luma=rgb.mean(2);target=base.mean()
    raw_chroma=rgb/np.maximum(1,rgb.sum(2,keepdims=True))
    # Preserve graphics with distinct colour or strong brightness contrast.
    plain=mask&(distance<.035)&(np.linalg.norm(raw_chroma-center,axis=2)<.07)&(luma>target*.35)&(luma<target*1.55)
    gray=rgb@np.array([.2126,.7152,.0722]);low=ndi.minimum_filter(gray,size=5);high=ndi.maximum_filter(gray,size=5)
    edge=(high-low)>45
    plain &= ~ndi.binary_dilation(edge,iterations=1)
    weight=.65*np.clip((.035-distance)/.015,0,1)*plain
    adjusted=rgb*(1-weight[:,:,None])+base*weight[:,:,None]
    pixels[:,:,:3]=np.clip(np.round(adjusted),0,255).astype(np.uint8)
    return Image.fromarray(pixels)

def projection_samples(image,binary,crop,base,view):
    """Suppress pale inner-neck labels/lining only in projection sampling.

    Large contrasting panels extending down the shirt are preserved. No mask
    is changed in storage. Geometry uses the original silhouette, and RGB atlas
    padding continues observed outer fabric across excluded sampling pixels.
    """
    if base is None:return binary,{'mode':'unchanged','reason':'no_shared_base'}
    rgb=np.asarray(image)[:,:,:3].astype(float);h,w=binary.shape
    x0=crop['x']*w;bw=crop['w']*w;y0=crop['y']*h;bh=crop['h']*h
    yy,xx=np.indices(binary.shape)
    upper=(yy<y0+bh*.18)&(yy>=y0-bh*.04)
    pale=binary&(rgb.mean(2)>base.mean()+45)&(rgb.min(2)>base.min()+35)
    labels,n=ndi.label(pale);sample=binary.copy();removed=0;eligible=np.zeros_like(binary)
    boundary=~ndi.binary_erosion(binary,iterations=2)
    for i,box in enumerate(ndi.find_objects(labels),start=1):
        if box is None:continue
        ys,xs=np.nonzero(labels[box]==i);ys+=box[0].start;xs+=box[1].start
        if not len(xs):continue
        in_neck=((xs>x0+bw*.22)&(xs<x0+bw*.78)).mean()>.5
        at_upper_boundary=bool((upper[ys,xs]&boundary[ys,xs]).any())
        outer=((xs<x0+bw*.15)|(xs>x0+bw*.85)).mean()>.90
        thin_edge=outer and xs.max()-xs.min()<bw*.08 and len(xs)<bw*bh*.01 and ys.max()<y0+bh*.45
        neck_or_edge=ys.max()<=y0+bh*.18 and ((view=='front' and in_neck) or at_upper_boundary)
        if neck_or_edge or thin_edge:
            sample[ys,xs]=False;removed+=len(xs)
            if view=='front' and in_neck and neck_or_edge:eligible[ys,xs]=True
    # Pale stitches and label letters form separate components. Once observed
    # in the central neck interior, exclude the complete bounded interior from
    # sampling rather than leaving grey antialiased fragments between letters.
    neck=eligible&upper&(xx>x0+bw*.22)&(xx<x0+bw*.78)
    if view=='front' and neck.sum()>max(12,bw*bh*.0005):
        ys,xs=np.nonzero(neck)
        if ys.max()<y0+bh*.18:
            area=(xx>=xs.min()-bw*.025)&(xx<=xs.max()+bw*.025)&(yy<=ys.max()+bh*.025)&(yy>=y0-bh*.04)
            removed+=int((sample&area).sum());sample[area]=False
    # Ignore only a narrow bright antialias fringe as an atlas sample. This
    # never erodes the stored silhouette or the 3D mesh; unseen texels receive
    # the common fabric estimate rather than a magnified camera-edge pixel.
    distance=ndi.distance_transform_edt(binary)
    outer=(xx<x0+bw*.15)|(xx>x0+bw*.85)
    fringe=binary&(distance<=3)&outer&(yy<y0+bh*.45)&(rgb.mean(2)>base.mean()+20)&(rgb.min(2)>base.min()+10)
    removed+=int((sample&fringe).sum());sample[fringe]=False
    return sample,{'mode': 'outer_fabric_sampling' if removed else 'unchanged',
        'excluded_pale_neck_or_edge_pixels':removed,'original_cutout_preserved':True}

def soften_upper_seams(tile,base):
    """Continue plain base fabric at upper atlas borders, retaining designs.

    The extreme torso UV borders represent unobserved side/shoulder padding,
    where hanger-photo lighting and background fringes otherwise stretch into
    visible seams. This changes only the projection, not captured media.
    """
    if base is None:return tile
    rgb=np.asarray(tile).astype(float);h,w=rgb.shape[:2]
    y,x=np.indices((h,w));u=x/max(1,w-1);v=y/max(1,h-1)
    edge=np.clip(1-np.minimum(u,1-u)/.14,0,1)*np.clip((.40-v)/.12,0,1)
    chroma=rgb/np.maximum(1,rgb.sum(2,keepdims=True));center=base/base.sum()
    similar=np.linalg.norm(chroma-center,axis=2)<.06
    # Keep high-contrast print edges and genuinely different-colour panels.
    gray=rgb.mean(2);detail=ndi.maximum_filter(gray,size=5)-ndi.minimum_filter(gray,size=5)>35
    eligible=similar&(gray>base.mean()*.45)&~ndi.binary_dilation(detail,iterations=2)
    weight=edge*eligible
    out=rgb*(1-weight[:,:,None])+base*weight[:,:,None]
    return Image.fromarray(np.clip(np.round(out),0,255).astype(np.uint8))
