import unittest
import numpy as np
from PIL import Image,ImageDraw
from tailor_ai.garment3d.material_reconstruction import reconstruct

class MaterialReconstructionTests(unittest.TestCase):
 def photo(self,base=(150,145,148),graphic=False):
  h,w=420,300;yy,xx=np.indices((h,w));mask=(xx>30)&(xx<270)&(yy>20)&(yy<400)
  light=.48+.50*xx/w+.12*np.sin(yy/65)+.10*np.sin(xx/18)
  rgb=np.clip(np.array(base)[None,None,:]*light[:,:,None],0,255).astype('uint8');rgba=np.dstack([rgb,(mask*255).astype('uint8')]);image=Image.fromarray(rgba)
  if graphic:
   d=ImageDraw.Draw(image);d.rectangle((90,130,210,165),fill=(12,12,12,255));d.text((110,190),'PRINT',fill=(10,10,10,255))
  return image,mask
 def test_neutral_plain_fabric_does_not_keep_broad_illumination_gradient(self):
  image,mask=self.photo();before=np.asarray(image).copy();views={'front':(image,mask),'back':(image.copy(),mask.copy())};crop={v:{'x':.1,'y':.05,'w':.8,'h':.9} for v in views}
  out,meta,_=reconstruct(views,crop);safe=mask.copy();safe[:80]=False;safe[350:]=False
  source=np.asarray(image)[:,:,:3][safe].mean(1);clean=np.asarray(out['front'])[:,:,:3][safe].mean(1)
  self.assertLess(float(clean.std()),float(source.std())*.15)
  np.testing.assert_array_equal(np.asarray(image),before);self.assertFalse(meta['generated_artwork']);self.assertTrue(meta['original_media_preserved'])
 def test_high_contrast_graphic_is_not_erased_when_fabric_is_flattened(self):
  image,mask=self.photo(graphic=True);views={'front':(image,mask),'back':self.photo()};crop={v:{'x':.1,'y':.05,'w':.8,'h':.9} for v in views}
  out,meta,mattes=reconstruct(views,crop);center=np.asarray(out['front'])[135:160,100:200,:3]
  self.assertGreater(float((center.mean(2)<65).mean()),.80)
  self.assertGreater(meta['views']['front']['design_pixels'],1500)
  self.assertLess(meta['views']['back']['design_pixels'],meta['views']['front']['design_pixels'])
 def test_different_front_and_back_fabric_colours_are_not_forced_to_match(self):
  views={'front':self.photo((180,40,35)),'back':self.photo((35,60,185))};crop={v:{'x':.1,'y':.05,'w':.8,'h':.9} for v in views}
  out,meta,_=reconstruct(views,crop);front=np.array(meta['views']['front']['base_rgb']);back=np.array(meta['views']['back']['base_rgb'])
  self.assertGreater(front[0],front[2]*2);self.assertGreater(back[2],back[0]*2)
 def test_background_pixels_cannot_change_the_reconstructed_material(self):
  image,mask=self.photo(graphic=True);changed=np.array(image);changed[~mask,:3]=(255,0,255);other=Image.fromarray(changed)
  crop={v:{'x':.1,'y':.05,'w':.8,'h':.9} for v in ['front','back']}
  clean,_,_=reconstruct({'front':(image,mask),'back':(image.copy(),mask)},crop)
  replacement,_,_=reconstruct({'front':(other,mask),'back':(other.copy(),mask)},crop)
  np.testing.assert_array_equal(np.asarray(clean['front']),np.asarray(replacement['front']))
if __name__=='__main__':unittest.main()
