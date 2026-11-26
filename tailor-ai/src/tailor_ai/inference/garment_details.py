"""Masked construction-detail views and conservative contradiction checks.

Similarity margins are heuristic evidence, not calibrated probabilities.
"""
import io
import numpy as np
from PIL import Image

HEMS={
 'open':('pants with a straight open hem and no elastic ankle cuff','an open trouser leg opening without a ribbed cuff'),
 'cuffed':('pants with gathered elastic ankle cuffs','a ribbed jogger cuff narrowing the ankle opening')}
WAIST={
 'visible_drawstring':('a waistband with visible drawstring cords','a waist with an exposed tied drawstring'),
 'no_visible_drawstring':('an elastic waistband without visible cords','a waistband with no exposed drawstring')}
WAISTBAND={
 'elastic_gathered':('a gathered elastic waistband on sweatpants','a stretchy ribbed waistband with fabric gathered below it'),
 'flat':('a flat smooth waistband without elastic gathers','a plain straight trouser waist without a gathered elastic band')}
# Audited against the exact male finished models. Style IDs are retained for
# storage compatibility; the name ankle_sweats does not imply an ankle cuff.
MALE_ANKLE_SWEATS=('sweatpants with a gathered elastic waistband and open ankle hems',
                   'relaxed straight leg sweatpants with an elastic waist and no ankle cuffs')

FASTENING={
 'buttons':('a shirt with a row of buttons down the front','a collared button-up shirt placket'),
 'zipper':('a hoodie with a zipper down the front','a hooded jacket with a full front zipper'),
 'none':('a pullover shirt without a front opening','a closed shirt front without buttons or a zipper')}


def detail_views(png,mask_png,part):
 image=Image.open(io.BytesIO(png)).convert('RGB')
 mask=np.asarray(Image.open(io.BytesIO(mask_png)).convert('L'))>127
 if mask.shape!=(image.height,image.width) or not mask.any():return []
 yy,xx=np.nonzero(mask);x0,x1=int(xx.min()),int(xx.max()+1);y0,y1=int(yy.min()),int(yy.max()+1)
 w=x1-x0;h=y1-y0
 boxes=[]
 if part=='hem':
  # Independent legs retain both hems even when one leg hangs lower.
  mid=(x0+x1)//2
  for left,right in [(x0,mid),(mid,x1)]:
   region=mask.copy();region[:int(y0+h*.65)]=False;region[:,:left]=False;region[:,right:]=False
   ys,xs=np.nonzero(region)
   if len(xs)<max(16,mask.sum()*.015):continue
   bottom=int(ys.max()+1);top=max(int(y0+h*.60),int(bottom-h*.20))
   local=mask[top:bottom,left:right];ly,lx=np.nonzero(local)
   if len(lx):boxes.append((left+int(lx.min()),top,left+int(lx.max()+1),bottom))
 elif part in {'waist','waistband'}:boxes=[(x0,y0,x1,int(y0+h*.25))]
 elif part=='fastening':boxes=[(int(x0+w*.25),y0,int(x1-w*.25),int(y0+h*.65))]
 clean=Image.new('RGB',image.size,'white');clean.paste(image,(0,0),Image.fromarray((mask*255).astype('uint8')))
 output=[]
 for box in boxes:
  crop=clean.crop(box)
  if min(crop.size)<8:continue
  side=max(crop.size);pad=max(4,round(side*.06));square=Image.new('RGB',(side+pad*2,side+pad*2),'white')
  square.paste(crop,((square.width-crop.width)//2,(square.height-crop.height)//2));output.append(square)
 return output


def agreed_detail(scores,labels,minimum_margin=.012):
 scores=np.asarray(scores,float);keys=list(labels)
 if scores.ndim!=2 or len(scores)<2 or scores.shape[1]!=len(keys) or not np.isfinite(scores).all():
  return {'value':None,'reason':'insufficient_detail','calibrated':False}
 order=np.argsort(-scores,axis=1);margins=scores[np.arange(len(scores)),order[:,0]]-scores[np.arange(len(scores)),order[:,1]]
 # Every view must support the same feature. Absence is not inferred from a tie.
 accepted=len(set(order[:,0]))==1 and float(margins.min())>=minimum_margin
 return {'value':keys[int(order[0,0])] if accepted else None,
  'reason':'two_view_agreement' if accepted else 'detail_uncertain',
  'minimum_margin':round(float(margins.min()),6),'scores':[{k:round(float(row[i]),6) for i,k in enumerate(keys)} for row in scores],
  'calibrated':False,'score_type':'cosine_similarity_not_probability'}


def compatible_styles(category,details,profile=None):
 blocked=set()
 if category=='trousers':
  male=profile=='male_average'
  if details.get('hem',{}).get('value')=='open':
   blocked.update({'drawstring_sweats'} if male else {'ankle_sweats','drawstring_sweats'})
  if details.get('hem',{}).get('value')=='cuffed':
   blocked.update({'baggy_sweats','capris','skinny_jeans','sweats'})
   if male:blocked.add('ankle_sweats')
  if male:
   waistband=details.get('waistband',{}).get('value')
   if waistband=='elastic_gathered':blocked.add('baggy_sweats')
   elif waistband=='flat':blocked.update({'ankle_sweats','drawstring_sweats'})
  if details.get('waist',{}).get('value')=='no_visible_drawstring':blocked.add('drawstring_sweats')
 if category=='outerwear':
  if details.get('fastening',{}).get('value')=='zipper':blocked.add('hoodie')
  if details.get('fastening',{}).get('value')=='none':blocked.add('zip_hoodie')
 if category=='long_sleeve_top':
  if details.get('fastening',{}).get('value')=='buttons':blocked.update({'long_tee','sweater'})
  if details.get('fastening',{}).get('value')=='none':blocked.add('button_up')
 return blocked

PATTERN={
 'plain':('plain solid colour fabric without a printed design','unprinted solid fabric clothing with seams and folds'),
 'printed':('fabric with a printed graphic logo or pattern','clothing with visible artwork stripes or a contrasting decorative design')}
