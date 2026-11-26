"""A live-model regression, not mocked classifier accuracy."""
import io,json,unittest
from pathlib import Path
from PIL import Image,ImageOps
from tailor_ai.digitization.plain_background import candidate
from tailor_ai.digitization.normalization import normalize
from tailor_ai.inference.garment_recognition import get_recognizer
from tailor_ai.inference.garment_details import agreed_detail,WAISTBAND

class RealGarmentDetailsTests(unittest.TestCase):
 def test_supplied_open_hem_pants_do_not_select_cuffed_ankles(self):
  base=Path(__file__).parent/'fixtures'/'recognition_details'
  views=[]
  for name in ['IMG_4512.jpg','IMG_4513.jpg']:
   image=ImageOps.exif_transpose(Image.open(base/name)).convert('RGB');image.thumbnail((1400,1400))
   cutout=candidate(image);self.assertIsNotNone(cutout,'The supplied photo must produce a contrast cutout.')
   normalized=normalize(image,cutout.mask);views.append(normalized)
  from tailor_ai.garment3d.finished_projection import REGISTRY
  result=get_recognizer().recognize(views[0].rgba_png,views[1].rgba_png,views[0].mask_png,views[1].mask_png,'male_average',REGISTRY)
  print('\nLive supplied-pants recognition: '+json.dumps(result,sort_keys=True),flush=True)
  self.assertEqual(result['category'],'trousers')
  self.assertEqual(result['construction_details']['pattern']['value'],'plain','Plain-fabric policy requires live two-view evidence.')
  self.assertEqual(result['construction_details']['hem']['value'],'open','Live model did not reliably identify the visible open hems; update must not be treated as validated.')
  self.assertNotIn(result['style'],{'baggy_sweats','drawstring_sweats'})
  waistband=result['construction_details']['waistband']
  self.assertIn(waistband['value'],{None,'elastic_gathered'})
  self.assertFalse(waistband['calibrated'])
  self.assertEqual(len(waistband['scores']),2)
  self.assertTrue(all(row['elastic_gathered']>row['flat'] for row in waistband['scores']))
  # Keep the original threshold. Weak supporting detail must remain uncertain;
  # full-garment style evidence can still choose the correctly described model.
  checked=agreed_detail([[row[k] for k in WAISTBAND] for row in waistband['scores']],WAISTBAND,minimum_margin=.012)
  self.assertEqual(waistband['value'],checked['value'])
  self.assertEqual(waistband['reason'],checked['reason'])
  self.assertGreater(result['style_margin'],.008)
  self.assertGreater(result['style_scores']['ankle_sweats'],result['style_scores'].get('baggy_sweats',-1))
  self.assertEqual(result['style'],'ankle_sweats')
  self.assertNotIn('ankle_sweats',result['excluded_contradictory_styles'])
  self.assertIn('drawstring_sweats',result['excluded_contradictory_styles'])
  if waistband['value']=='elastic_gathered':self.assertIn('baggy_sweats',result['excluded_contradictory_styles'])
  else:self.assertNotIn('baggy_sweats',result['excluded_contradictory_styles'])
if __name__=='__main__':unittest.main()
