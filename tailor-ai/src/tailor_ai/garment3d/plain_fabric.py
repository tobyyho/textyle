"""Only confirmed plain bottoms use flat estimated albedo. Geometry is untouched."""
import copy
import numpy as np
from PIL import Image

def apply_plain_policy(source,rebuilt,appearance,category,policy):
 if (category not in {'trousers','shorts'} or not isinstance(policy,dict) or
     policy.get('value')!='plain' or policy.get('reason')!='two_view_agreement' or
     policy.get('calibrated') is not False or policy.get('minimum_margin',0)<.02):
  return rebuilt,appearance
 meta=copy.deepcopy(appearance);result={}
 for name,(image,mask) in source.items():
  base=np.asarray(meta['views'][name]['base_rgb'],dtype=np.uint8)
  rgba=np.empty((*mask.shape,4),np.uint8);rgba[:,:,:3]=base;rgba[:,:,3]=np.where(mask,255,0)
  result[name]=Image.fromarray(rgba)
  meta['views'][name]['design_pixels']=0
 meta.update(mode='confirmed_plain_fabric',plain_fabric_policy='two_view_pattern_v1',pattern_evidence=copy.deepcopy(policy))
 return result,meta
