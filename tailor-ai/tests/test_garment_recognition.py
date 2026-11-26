"""Geometry preparation and fail-closed two-view decision checks; no model mocks disguised as accuracy."""
import io,unittest
import numpy as np
from PIL import Image,ImageDraw
from tailor_ai.inference.garment_recognition import FAMILIES,RecognitionError,rank_categories,whole_garment

def png(im):
 b=io.BytesIO();im.save(b,'PNG');return b.getvalue()
class RecognitionTests(unittest.TestCase):
 def test_full_width_sleeves_survive_letterboxing_and_background_is_removed(self):
  im=Image.new('RGB',(900,300),'magenta');mask=Image.new('L',im.size,0)
  ImageDraw.Draw(mask).rectangle((10,80,889,220),fill=255);ImageDraw.Draw(im).rectangle((10,80,889,220),fill='blue')
  out=whole_garment(png(im),png(mask));rgb=np.array(out)
  self.assertEqual(out.width,out.height);self.assertEqual(int((rgb[:,:,2]==255).sum()),out.width*out.height)
  blue=(rgb[:,:,0]==0)&(rgb[:,:,1]==0);yy,xx=np.nonzero(blue)
  self.assertEqual(xx.max()-xx.min()+1,880);self.assertEqual(yy.max()-yy.min()+1,141);self.assertTrue((rgb[0]==255).all())
 def test_mismatched_or_empty_cutouts_are_rejected(self):
  with self.assertRaises(RecognitionError):whole_garment(png(Image.new('RGB',(120,100))),png(Image.new('L',(120,100))))
  with self.assertRaises(RecognitionError):whole_garment(png(Image.new('RGB',(120,100))),png(Image.new('L',(90,100),255)))
 def scores(self,a,b=None):
  out=np.zeros((2,len(FAMILIES)));out[0,list(FAMILIES).index(a)]=.1;out[1,list(FAMILIES).index(b or a)]=.12;return out
 def test_both_views_agree_before_automatic_category_selection(self):
  for category in ['short_sleeve_top','long_sleeve_top','outerwear','trousers','shorts','skirt']:
   selected,evidence=rank_categories(self.scores(category));self.assertEqual(selected,category);self.assertEqual(len(evidence['views']),2)
 def test_mixed_views_and_unsupported_clothes_cannot_be_forced_into_supported_templates(self):
  for scores in [self.scores('shorts','short_sleeve_top'),self.scores('dress'),self.scores('sleeveless_top'),self.scores('unsupported'),np.zeros((2,len(FAMILIES))),np.full((2,len(FAMILIES)),np.nan)]:
   with self.assertRaises(RecognitionError):rank_categories(scores)
if __name__=='__main__':unittest.main()
