import io,unittest
import numpy as np
from PIL import Image,ImageDraw
from tailor_ai.inference.garment_details import detail_views,agreed_detail,compatible_styles,HEMS
from tailor_ai.inference.garment_recognition import FashionRecognizer,FAMILIES,STYLES,RecognitionError

def png(im):
 b=io.BytesIO();im.save(b,'PNG');return b.getvalue()
class DetailTests(unittest.TestCase):
 def photos(self):
  image=Image.new('RGB',(320,500),'magenta');mask=Image.new('L',image.size,0)
  d=ImageDraw.Draw(mask);d.rectangle((50,30,270,210),fill=255);d.rectangle((50,210,135,440),fill=255);d.rectangle((180,210,270,475),fill=255)
  image.paste(Image.new('RGB',image.size,(70,70,70)),(0,0),mask)
  ImageDraw.Draw(image).rectangle((0,400,319,499),fill='blue')
  return png(image),png(mask)
 def test_independent_hems_include_the_higher_and_lower_leg(self):
  im,m=self.photos();out=detail_views(im,m,'hem');self.assertEqual(len(out),2)
  for image in out:
   a=np.asarray(image);self.assertTrue(((a[:,:,2]==255)&(a[:,:,0]==0)).any());self.assertFalse(((a[:,:,0]==255)&(a[:,:,2]==255)&(a[:,:,1]==0)).any())
 def test_absence_requires_agreement_and_a_margin(self):
  self.assertEqual(agreed_detail([[.2,.1],[.22,.1]],HEMS)['value'],'open')
  for scores in [[[.2,.1],[.1,.2]],[[.2,.199],[.2,.199]],[[.2,.1]],[[float('nan'),0],[0,1]]]:
   self.assertIsNone(agreed_detail(scores,HEMS)['value'])
 def test_contradictory_cuffed_style_is_excluded(self):
  details={'hem':{'value':'open'}}
  male=compatible_styles('trousers',details,'male_average')
  self.assertNotIn('ankle_sweats',male)
  self.assertIn('drawstring_sweats',male)
  self.assertNotIn('baggy_sweats',male)
  female=compatible_styles('trousers',details,'female_average')
  self.assertIn('ankle_sweats',female)
 def test_catalog_limits_do_not_hide_observed_capri_style(self):
  class Stub(FashionRecognizer):
   def __init__(self,waistband):self.waistband=waistband
   def scores(self,images,labels):
    out=np.zeros((len(images),len(labels)))
    key='trousers' if labels is FAMILIES else 'capris' if 'capris' in labels else 'open' if 'open' in labels else self.waistband if 'elastic_gathered' in labels else 'no_visible_drawstring'
    if key in labels:out[:,list(labels).index(key)]=.2
    if 'ankle_sweats' in labels:out[:,list(labels).index('ankle_sweats')]=.19
    if 'baggy_sweats' in labels:out[:,list(labels).index('baggy_sweats')]=.15
    return out
  im,m=self.photos()
  for waistband,expected in [('flat','baggy_sweats'),('elastic_gathered','ankle_sweats'),(None,'ankle_sweats')]:
   with self.subTest(waistband=waistband):
    result=Stub(waistband).recognize(im,im,m,m,'male_average',[{'profile':'male_average','category':'trousers','style':x} for x in ['ankle_sweats','baggy_sweats','drawstring_sweats']])
    self.assertEqual(result['observed_style'],'capris')
    self.assertEqual(result['style'],expected)
    self.assertEqual(result['construction_details']['waistband']['value'],waistband)
    self.assertTrue(result['template_is_approximate'])
    self.assertTrue(result['style_uncertain'])
    self.assertFalse(result['calibrated'])
    self.assertFalse(result['observed_style_available'])
if __name__=='__main__':unittest.main()
