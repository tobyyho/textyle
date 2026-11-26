import unittest,numpy as np
from PIL import Image
from tailor_ai.garment3d.plain_fabric import apply_plain_policy
class PlainFabricTests(unittest.TestCase):
 def test_confirmed_plain_bottoms_remove_false_print_but_keep_alpha(self):
  mask=np.ones((40,30),bool);mask[0]=False
  im=Image.new('RGBA',(30,40),(220,210,190,255));views={'front':(im,mask),'back':(im,mask)}
  rebuilt={v:im for v in views};appearance={'views':{v:{'base_rgb':[69,58,56],'design_pixels':100} for v in views}}
  before=np.array(im).copy();policy={'value':'plain','reason':'two_view_agreement','calibrated':False,'minimum_margin':.04}
  out,meta=apply_plain_policy(views,rebuilt,appearance,'trousers',policy)
  self.assertTrue(np.all(np.asarray(out['front'])[:,:,:3]==[69,58,56]));np.testing.assert_array_equal(np.array(out['front'])[:,:,3],np.where(mask,255,0))
  np.testing.assert_array_equal(np.asarray(im),before);self.assertEqual(appearance['views']['front']['design_pixels'],100)
  for category,p in [('short_sleeve_top',policy),('trousers',None),('trousers',{**policy,'value':'printed'}),('trousers',{**policy,'minimum_margin':.001})]:
   untouched,_=apply_plain_policy(views,rebuilt,appearance,category,p);self.assertIs(untouched,rebuilt)
if __name__=='__main__':unittest.main()
