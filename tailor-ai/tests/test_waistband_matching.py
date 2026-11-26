"""Construction matching uses actual male template traits, not style-ID wording."""
import io,unittest
import numpy as np
from PIL import Image,ImageDraw
from tailor_ai.inference.garment_details import compatible_styles,agreed_detail,WAISTBAND
from tailor_ai.inference.garment_recognition import FashionRecognizer,FAMILIES,MODEL_SHA256

class WaistbandMatchingTests(unittest.TestCase):
 def test_gathered_waist_and_open_hems_keep_only_the_matching_male_template(self):
  d={'hem':{'value':'open'},'waistband':{'value':'elastic_gathered'}}
  blocked=compatible_styles('trousers',d,'male_average')
  self.assertNotIn('ankle_sweats',blocked)
  self.assertIn('drawstring_sweats',blocked);self.assertIn('baggy_sweats',blocked)
 def test_waist_does_not_override_cuffed_hems(self):
  blocked=compatible_styles('trousers',{'hem':{'value':'cuffed'},'waistband':{'value':'elastic_gathered'}},'male_average')
  self.assertIn('ankle_sweats',blocked);self.assertNotIn('drawstring_sweats',blocked)
 def test_uncertain_waistband_does_not_exclude_flat_or_gathered_models(self):
  details={'hem':{'value':'open'},'waistband':{'value':None}}
  blocked=compatible_styles('trousers',details,'male_average')
  self.assertNotIn('ankle_sweats',blocked);self.assertNotIn('baggy_sweats',blocked)
  self.assertIn('drawstring_sweats',blocked)
 def test_female_cuffed_template_keeps_its_own_traits(self):
  self.assertIn('ankle_sweats',compatible_styles('trousers',{'hem':{'value':'open'}},'female_average'))
  self.assertNotIn('ankle_sweats',compatible_styles('trousers',{'hem':{'value':'cuffed'}},'female_average'))
 def test_waistband_still_requires_two_views_and_margin(self):
  self.assertIsNone(agreed_detail([[.2,.1],[.1,.2]],WAISTBAND)['value'])
  self.assertIsNone(agreed_detail([[.2,.195],[.2,.1]],WAISTBAND)['value'])
  self.assertEqual(agreed_detail([[.2,.1],[.3,.1]],WAISTBAND)['value'],'elastic_gathered')
 def test_full_recognition_filters_contradictory_model_even_when_it_scores_highest(self):
  # Contract regression with deterministic scores; real-photo inference is a
  # separate mandatory installer check, not represented by this test.
  class Stub(FashionRecognizer):
   def __init__(self,uncertain=False):self.uncertain=uncertain
   def scores(self,images,labels):
    keys=list(labels)
    rows=np.zeros((len(images),len(keys)))
    if keys==list(FAMILIES):rows[:,keys.index('trousers')]=.2
    elif 'open' in keys:rows[:,keys.index('open')]=.1
    elif 'visible_drawstring' in keys:rows[:]=.05 # remain uncertain
    elif 'plain' in keys:rows[:,keys.index('plain')]=.1
    elif 'elastic_gathered' in keys:
     rows[:,keys.index('elastic_gathered')]=.005 if self.uncertain else .1
    else:
     rows[:,keys.index('baggy_sweats')]=.2 if self.uncertain else .3
     rows[:,keys.index('ankle_sweats')]=.3 if self.uncertain else .2
    return rows
  mask=Image.new('L',(160,240));d=ImageDraw.Draw(mask)
  d.rectangle((20,10,140,100),fill=255);d.rectangle((20,100,65,230),fill=255);d.rectangle((95,100,140,230),fill=255)
  image=Image.new('RGBA',mask.size,(90,80,70,255))
  def png(im):
   b=io.BytesIO();im.save(b,'PNG');return b.getvalue()
  im,ma=png(image),png(mask)
  registry=[{'style':k,'profile':'male_average','category':'trousers'} for k in ['ankle_sweats','baggy_sweats','drawstring_sweats']]
  for uncertain in [False,True]:
   with self.subTest(uncertain_waistband=uncertain):
    result=Stub(uncertain).recognize(im,im,ma,ma,'male_average',registry)
    self.assertEqual(result['style'],'ankle_sweats')
    self.assertEqual(result['construction_details']['waistband']['value'],None if uncertain else 'elastic_gathered')
    self.assertFalse(result['construction_details']['waistband']['calibrated'])
if __name__=='__main__':unittest.main()
