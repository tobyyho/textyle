import unittest
import numpy as np
from PIL import Image
from tailor_ai.garment3d.capri_mapping import pants_panel
from tailor_ai.garment3d import garment_photo_projection as p

class CapriMappingTests(unittest.TestCase):
 def image(self,split=.63):
  m=np.zeros((600,400),bool);m[30:570,50:350]=True
  m[int(30+540*split):,180:220]=False
  im=Image.new('RGBA',(400,600),(60,60,60,255));im.putalpha(Image.fromarray((m*255).astype('uint8')))
  return im,m
 def test_visible_short_lower_legs_map_without_moving_the_model(self):
  im,m=self.image()
  with self.assertRaises(p.ProjectionError):p.pants_panel(im,m,.45)
  panel,crop,meta=pants_panel(im,m,.45)
  self.assertEqual(panel.size,(1024,1536));self.assertEqual(len(meta['legs']),2)
  self.assertTrue(all(v['observed_pixels']>10000 for v in meta['legs']))
 def test_standard_pants_keep_the_original_mapping(self):
  im,m=self.image(.4);before=p.pants_panel(im,m,.45);after=pants_panel(im,m,.45)
  np.testing.assert_array_equal(np.asarray(before[0]),np.asarray(after[0]));self.assertEqual(before[1:],after[1:])
 def test_joined_legs_still_fail(self):
  im,m=self.image();m[350:570,180:220]=True
  with self.assertRaises(p.ProjectionError):pants_panel(im,m,.45)
 def test_one_missing_leg_still_fails(self):
  im,m=self.image();m[300:,220:]=False
  with self.assertRaises(p.ProjectionError):pants_panel(im,m,.45)
if __name__=='__main__':unittest.main()
