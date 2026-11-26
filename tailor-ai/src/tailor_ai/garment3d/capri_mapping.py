"""Allow visible short lower legs while retaining independent-leg checks."""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from tailor_ai.garment3d import garment_photo_projection as p
ProjectionError=p.ProjectionError
_runs=p._runs
_padded_rgb=p._padded_rgb

def pants_panel(image,binary,crotch_ratio):
    try:return p.pants_panel(image,binary,crotch_ratio)
    except ProjectionError as error:
        if str(error) not in {
            'Separate both pants legs and show the waistband and hems. The photo does not expose two usable legs.',
            'A pants leg is folded or cropped. Show both complete legs.'}:
            raise
    return _shorter_leg_panel(image,binary,crotch_ratio)

def _shorter_leg_panel(image,binary,crotch_ratio):
    geom=ndi.binary_fill_holes(binary);ys,xs=np.nonzero(geom);x0,x1=int(xs.min()),int(xs.max()+1);y0,y1=int(ys.min()),int(ys.max()+1)
    h=y1-y0;w=x1-x0
    broad=geom[y0:y1].sum(1)>w*.5;stable=max(4,int(h*.025));starts=np.flatnonzero(np.convolve(broad.astype(int),np.ones(stable,dtype=int),mode='valid')==stable)
    if not len(starts):raise ProjectionError('Could not locate a pants waistband.')
    y0+=int(starts[0]);h=y1-y0
    valid=[]
    for y in range(y0,y1):
        runs=[(a,b) for a,b in _runs(geom[y]) if b-a>w*.10]
        valid.append(len(runs)==2 and runs[1][0]-runs[0][1]>max(2,w*.012))
    begin=int(h*.16);end=int(h*.74);stable=max(4,int(h*.025))
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
        if bottom-split<h*.24:raise ProjectionError('A pants leg is folded or cropped. Show both complete legs.')
        panel.paste(row_warp(region,split,bottom,512,1536-cut),(i*512,cut))
        details.append({'image_side':'left' if i==0 else 'right','top':int(split),'bottom':bottom,'observed_pixels':int(region.sum())})
    crop={'x':x0/image.width,'y':y0/image.height,'w':(x1-x0)/image.width,'h':(y1-y0)/image.height}
    return panel,crop,{'mode':'waist_and_separate_leg_rows','source_crotch_y':split/image.height,'legs':details}
