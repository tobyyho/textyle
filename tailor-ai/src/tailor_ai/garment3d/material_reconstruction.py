"""Estimated fabric albedo + observed print; originals remain immutable.

This is an image-based reconstruction, not a generative model. Hidden artwork
is never invented. Approximation limits are recorded with the generated model.
"""
import io
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from tailor_ai.garment3d.fabric_albedo import shared_base
from tailor_ai.garment3d.tee_albedo import prepare_tee
VERSION='fabric-print-reconstruction-v4'

def _representative(rgb,mask):
 safe=ndi.binary_erosion(mask,iterations=3)
 if not safe.any():safe=mask
 pixels=rgb[safe][::max(1,int(safe.sum()/40000))].astype(float)
 light=pixels.mean(1);lo,hi=np.percentile(light,[58,78]);chosen=pixels[(light>=lo)&(light<=hi)]
 return np.median(chosen if len(chosen) else pixels,axis=0)

def _neutral_print(rgb,mask,crop,base,view='front'):
 h,w=mask.shape;x,y,bw,bh=[int(round(crop[k]*s)) for k,s in [('x',w),('y',h),('w',w),('h',h)]]
 yy,xx=np.indices((h,w));safe=ndi.binary_erosion(mask,iterations=max(2,round(bw*.008)))
 safe&=(yy>y+bh*.10)&(yy<y+bh*.94)
 # Ignore the small central collar-lining region, not the full upper chest.
 if view=='front':safe&=~((yy<y+bh*.18)&(xx>x+bw*.28)&(xx<x+bw*.72))
 gray=rgb.mean(2);filled=gray.copy();near=ndi.distance_transform_edt(~mask,return_distances=False,return_indices=True);filled[~mask]=gray[near[0][~mask],near[1][~mask]]
 # Morphological envelopes suppress broad illumination while retaining strokes.
 size=max(9,round(bw*.055));size+=1-size%2
 large=max(size,round(bw*.22));large+=1-large%2
 upper=ndi.grey_closing(filled,size=(large,large));lower=ndi.grey_opening(filled,size=(large,large))
 dark=np.maximum(ndi.grey_closing(filled,size=(size,size))-filled,(upper-filled)*(filled<upper*.55))
 bright=np.maximum(filled-ndi.grey_opening(filled,size=(size,size)),(filled-lower)*(filled>np.maximum(60,lower*1.8)))
 low=ndi.gaussian_filter(filled,max(4,bw*.035));contrast=np.maximum(dark,bright)
 # Infer ink polarity from observed contrast, not an absolute fabric value.
 # A charcoal tee photographed brighter than 85 must not switch to dark ink.
 bright_support=safe&(gray>base.mean()+max(25,base.mean()*.3))
 dark_support=safe&(gray<base.mean()*.55)
 # Torso artwork must not lose a polarity vote to folded sleeve shadows.
 # Restrict voting only; observed sleeve artwork can still be extracted.
 voting=safe&(xx>x+bw*.04)&(xx<x+bw*.96)
 dark_votes=int((dark_support&voting&(dark>18)).sum())
 bright_votes=int((bright_support&voting&(bright>18)).sum())
 dark_ink=bool(dark_votes>bright_votes)
 if not (dark_support.any() or bright_support.any()):dark_ink=base.mean()>127
 reference=np.maximum(low,upper) if dark_ink else np.minimum(low,lower)
 polarity=((gray<low-10)|(gray<upper*.55)) if dark_ink else ((gray>low+12)|(gray>np.maximum(75,lower*1.8)))
 evidence=dark if dark_ink else bright
 if not dark_ink:polarity&=gray>base.mean()+20
 seed=safe&polarity&(evidence>max(12,float(base.mean())*.12))
 # Dense print rows distinguish logos from sparse vertical camera creases.
 row_density=ndi.gaussian_filter1d(seed.sum(1).astype(float),max(2,bh*.006))
 if row_density.max(initial=0)>max(16,bw*.04):
  rows=row_density>max(9,bw*.035,row_density.max()*.14)
  rows=ndi.binary_closing(rows,iterations=max(2,round(bh*.012)))
  rows=ndi.binary_dilation(rows,iterations=max(3,round(bh*.018)))
  seed&=rows[:,None]
 # Sparse tall creases are not artwork; retain nearby fine strokes in logos.
 density=ndi.uniform_filter(seed.astype(float),size=max(15,round(bw*.15)))
 connected,n=ndi.label(ndi.binary_dilation(seed,iterations=max(1,round(bw*.012))))
 matte=np.zeros((h,w),float)
 for label,box in enumerate(ndi.find_objects(connected),start=1):
  if box is None:continue
  region=(connected[box]==label)&seed[box];count=int(region.sum())
  height=box[0].stop-box[0].start;width=box[1].stop-box[1].start
  if count<max(30,int(bw*bh*.0006)):continue
  if height>width*2.7 and density[box][region].mean()<.12:continue
  # Dilate only within locally supported contrast; don't copy an entire box.
  support=np.zeros((h,w),bool);support[box]=connected[box]==label
  support=ndi.binary_dilation(support,iterations=max(1,round(bw*.006)))&safe
  enclosed=ndi.binary_fill_holes(support)&safe
  solid=(gray<base.mean()*.55) if dark_ink else (gray>max(75,base.mean()+35))
  detail=support&(evidence>5)&polarity
  matte[detail]=np.clip((evidence[detail]-4)/12,0,1)
  matte[enclosed&solid]=1
 # Sparse long vertical ridges remain likely capture wrinkles, even when
 # they happen to touch a logo. Dense artwork keeps its original strokes.
 busy=ndi.uniform_filter((matte>.1).astype(float),size=max(15,round(bw*.09)))>.13
 vertical=ndi.binary_opening(matte>.1,structure=np.ones((max(24,round(bh*.065)),1),bool))
 crease=ndi.binary_dilation(vertical,structure=np.ones((3,5),bool))&~busy
 matte[crease]=0
 fragments,_=ndi.label(matte>.1)
 for label,box in enumerate(ndi.find_objects(fragments),start=1):
  if box is None:continue
  height=box[0].stop-box[0].start;width=box[1].stop-box[1].start;region=fragments[box]==label
  if height>max(28,bh*.045) and height>width*2.5 and busy[box][region].mean()<.25:
   patch=matte[box];patch[region]=0
 # Estimate print pigments independent of broad camera illumination.
 illumination=np.clip(reference/max(float(base.mean()),1),.85,1.25)
 pigment=np.clip(rgb/illumination[:,:,None],0,255)
 return matte,pigment

def reconstruct(views,crops):
 shared,tone=shared_base(views);bases={k:_representative(np.asarray(im)[:,:,:3],mask) for k,(im,mask) in views.items()}
 if shared is None and len(bases)==2:
  values=list(bases.values());a,b=values
  chroma_distance=np.linalg.norm(a/max(a.sum(),1)-b/max(b.sum(),1))
  light_ratio=max(a.mean(),b.mean())/max(1,min(a.mean(),b.mean()))
  # Only modest exposure differences on the same near-neutral cloth qualify.
  neutral=all(np.linalg.norm(c/max(c.sum(),1)-1/3)<.09 for c in values)
  if neutral and chroma_distance<.035 and light_ratio<=1.35:
   shared=np.median(np.stack(values),axis=0)
 if shared is not None:bases={k:shared for k in views}
 result={};record={};matte_views={}
 # The existing chromatic-ink extractor is useful evidence on coloured cloth;
 # its raw photo fallback is never used as the finished material.
 chromatic=None
 if shared is not None and np.linalg.norm(shared/max(1,shared.sum())-1/3)>=.09:
  chromatic,_=prepare_tee(views,crops,shared)
 for name,(image,mask) in views.items():
  source=np.asarray(image);rgb=source[:,:,:3].astype(float);base=bases[name];h,w=mask.shape
  x,y,bw,bh=[int(round(crops[name][k]*s)) for k,s in [('x',w),('y',h),('w',w),('h',h)]]
  yy,xx=np.indices(mask.shape);body=(xx>=x)&(xx<x+bw)&(yy>=y)&(yy<y+bh)&mask
  matte,pigment=_neutral_print(rgb,mask,crops[name],base,name)
  if chromatic is not None:
   printed=np.asarray(chromatic[name])[:,:,:3].astype(float)
   colour_matte=body&(np.linalg.norm(printed-base,axis=2)>4)
   colour_matte&=(yy>y+bh*.12)&(yy<y+bh*.94)&ndi.binary_erosion(mask,iterations=3)
   # Keep luminance evidence: warm lighting does not turn gray ink into cloth.
   extra=colour_matte&(matte<.1)
   pigment[extra]=printed[extra]
   matte[extra]=1
  # Distinct coloured artwork/panels remain supported, including sleeves.
  chroma=rgb/np.maximum(rgb.sum(2,keepdims=True),1);center=base/max(1,base.sum())
  saturation=np.linalg.norm(chroma-1/3,axis=2);base_saturation=np.linalg.norm(center-1/3)
  hue=(np.sum((chroma-1/3)*(center-1/3),axis=2)/np.maximum(saturation*base_saturation,1e-8))
  vivid=(saturation>.075)&((hue<.5) if base_saturation>.045 else True)
  pale=(rgb.mean(2)>base.mean()*1.45)&(saturation<.055)&(base_saturation>.045)
  colour=mask&(np.linalg.norm(chroma-center,axis=2)>.11)&(rgb.mean(2)>28)&(vivid|pale)
  colour&=ndi.binary_erosion(mask,iterations=3)&(yy>y+bh*.12)
  labels,n=ndi.label(colour)
  for i,box in enumerate(ndi.find_objects(labels),start=1):
   if box is None:continue
   local=labels[box]==i
   if local.sum()<max(12,int(mask.sum()*.00008)):continue
   region=np.zeros_like(mask);region[box]=local
   matte[region]=1
   # Each contrasting pigment gets one stable colour; this removes its shadows.
   pixels=rgb[region];light=pixels.mean(1);selected=pixels[light>=np.percentile(light,55)]
   pigment[region]=np.median(selected if len(selected) else pixels,axis=0)
  matte=np.clip(matte,0,1)*mask
  rendered=np.broadcast_to(base,rgb.shape).copy()*(1-matte[:,:,None])+pigment*matte[:,:,None]
  # Fill all unseen/padding texels with fabric, not a stretched bright fringe.
  out=np.empty((h,w,4),np.uint8);out[:,:,:3]=np.clip(np.round(rendered),0,255).astype(np.uint8);out[:,:,3]=np.where(mask,255,0)
  result[name]=Image.fromarray(out);matte_views[name]=matte
  record[name]={'base_rgb':np.round(base).astype(int).tolist(),'design_pixels':int((matte>.1).sum()),'fabric_pixels':int(mask.sum()),'source_shading_retained':False}
 return result,{'version':VERSION,'mode':'reconstructed_fabric_and_observed_print','views':record,'original_media_preserved':True,'generated_artwork':False,'hidden_design_recovery':False,'colour_is_estimated':True},matte_views
