"""Bounded contrast-based candidate for one opaque garment on a plain background.

Not a general segmentation model. Ambiguous backgrounds, low contrast, clipped
objects and multiple substantial foreground objects return None. Scores below
are deterministic image checks, never model probabilities or user approval.
"""
from dataclasses import dataclass
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from tailor_ai.digitization.solid_mask import preserve_interior, VERSION as INTERIOR_VERSION

VERSION='plain-background-contrast-v2-solid-interior'
@dataclass(frozen=True)
class Candidate:
    mask: np.ndarray
    checks: dict

def lab(rgb):
    v=np.asarray(rgb,dtype=np.float32)/255
    v=np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4)
    xyz=v@np.array([[.4124564,.3575761,.1804375],[.2126729,.7151522,.0721750],[.0193339,.1191920,.9503041]],np.float32).T
    xyz/=np.array([.95047,1,1.08883],np.float32)
    f=np.where(xyz>.008856,np.cbrt(xyz),7.787*xyz+16/116)
    return np.stack((116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])),axis=-1)

def candidate(image):
    small=image.convert('RGB').copy();small.thumbnail((768,768),Image.Resampling.LANCZOS)
    rgb=np.asarray(small);h,w=rgb.shape[:2]
    if min(h,w)<96:return None
    a=lab(rgb);band=max(2,round(min(h,w)*.018))
    rim=np.zeros((h,w),bool);rim[:band]=rim[-band:]=True;rim[:,:band]=True;rim[:,-band:]=True
    border=a[rim];bg=np.median(border,axis=0)
    # Lighting gradients are allowed; busy/saturated or multi-colour backgrounds
    # are not suitable for this deterministic path.
    spread=np.linalg.norm(border-bg,axis=1)
    if np.percentile(spread,95)>20:return None
    distance=np.linalg.norm(a-bg,axis=-1)
    strong=distance>max(25,float(np.percentile(spread,98))+10)
    weak=distance>max(15,float(np.percentile(spread,95))+5)
    seed=np.zeros((h,w),bool);seed[int(h*.25):int(h*.75),int(w*.3):int(w*.7)]=True
    if (strong&seed).sum()/max(1,seed.sum())<.65:return None
    labels,n=ndi.label(weak);sizes=np.bincount(labels.ravel());sizes[0]=0
    if not n:return None
    center=np.bincount(labels[seed&strong].ravel(),minlength=n+1);center[0]=0
    label=int(center.argmax());mask=labels==label
    if sizes[label]<.12*h*w or sizes[label]>.82*h*w:return None
    # Ignore specks, but reject a second substantial object.
    other=sizes.copy();other[label]=0
    if other.max(initial=0)>.04*mask.sum():return None
    # Hanger hooks and rods above shoulders are thin. Remove only the part above
    # a sustained broad silhouette; never erode the actual garment edge.
    counts=mask.sum(axis=1)
    broad=counts>max(w*.30,counts.max()*.48)
    starts=[y for y in range(h-5) if broad[y:y+5].all()]
    if not starts:return None
    start=starts[0]
    if start>h*.35:return None
    torso=a[seed & strong]
    fabric=np.median(torso,axis=0)
    top=mask[:start].copy()
    top &= np.linalg.norm(a[:start]-fabric,axis=-1)<35
    mask[:start]=top
    labels,n=ndi.label(mask);sizes=np.bincount(labels.ravel());sizes[0]=0
    mask=labels==int(sizes.argmax())
    if mask[rim].mean()>.01:return None
    # Keep source pixels regardless of their colour once enclosed by the outer
    # silhouette. Contrast acceptance below is measured before filling; a white
    # print is not evidence that the background selection is unreliable.
    gate_mask=mask.copy()
    mask,restored=preserve_interior(mask)
    if not mask.any():return None
    ys,xs=np.nonzero(mask)
    if xs.min()<2 or xs.max()>=w-2 or ys.max()>=h-2:return None
    # Strong membership over most of the selected fabric is essential. This
    # rejects weak contrast/shadow leakage instead of promoting a bad cutout.
    membership=float(strong[gate_mask].mean())
    if membership<.92:return None
    out=np.asarray(Image.fromarray(mask).resize(image.size,Image.Resampling.NEAREST),dtype=bool)
    return Candidate(out,{'method':VERSION,'border_spread_lab':round(float(np.percentile(spread,95)),2),
        'strong_foreground_fraction':round(membership,4),'calibrated_probability':False,
        'interior_policy':INTERIOR_VERSION,'interior_pixels_restored':restored})
