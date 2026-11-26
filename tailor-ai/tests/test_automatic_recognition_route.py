"""Automatic HTTP orchestration with explicit recognition stubs and real model projection."""
import hashlib,unittest
from unittest.mock import patch
from test_finished_route import FinishedRouteTests,route
from tailor_ai.inference.garment_recognition import RecognitionError,VERSION

class AutomaticRecognitionRouteTests(FinishedRouteTests):
 def digitize(self,*args,**kwargs):
  result=super().digitize(*args,**kwargs);result['attributes']={};return result
 def recognized(self,front,back,front_mask,back_mask,profile,registry):
  self.calls+=1
  self.assertEqual(profile,self.target['profile']);self.assertEqual(len(registry),20)
  return {'category':self.target['category'],'style':self.target['style'],'source':'fashion_model',
   'model_version':VERSION,'revision':'test-revision','score_type':'cosine_similarity_not_probability','calibrated':False,
   'style_uncertain':False,'front_sha256':hashlib.sha256(front).hexdigest(),'back_sha256':hashlib.sha256(back).hexdigest()}
 def test_all_twenty_models_generate_without_category_or_style_choice_even_if_legacy_model_abstains(self):
  self.calls=0;self.abstained=True
  import types
  recognizer=types.SimpleNamespace(recognize=self.recognized)
  with patch.object(route,'get_recognizer',return_value=recognizer),patch.object(route,'fit_glb',side_effect=AssertionError('No finished-model refit')):
   for target in route.FINISHED_STYLES.values():
    self.target=target
    with self.subTest(profile=target['profile'],style=target['style']):
     response=self.post(target['profile'],target['category'],'auto')
     self.assertEqual(response.status_code,200,response.text)
     body=response.json();meta=self.saved[1]
     self.assertEqual(meta['finalTemplateStyle'],{'requested':'auto','resolved':target['style'],'source':'fashion_model'})
     self.assertEqual(meta['automaticRecognition']['category'],target['category'])
     self.assertEqual(body['classification']['confidence'],0)
     self.assertFalse(body['classification']['resolution']['confidence_available'])
     self.assertTrue(body['classification']['original_model_prediction']['abstained'])
     self.assertEqual(body['classification']['model_version'],VERSION)
     self.assertFalse(meta['userReviewed']);self.assertTrue(meta['suppliedGeometry']['preserved'])
     self.assertEqual(meta['suppliedGeometry']['sha256'],target['sha256'])
     self.assertFalse(body['readiness']['segmentation_ready'])
  self.assertEqual(self.calls,20)
 def test_bad_cutouts_and_auth_fail_before_new_model_is_invoked(self):
  self.accepted=False
  with patch.object(route,'get_recognizer',side_effect=AssertionError('Should not load model')):
   response=self.post('male_average','long_sleeve_top','auto');self.assertEqual(response.status_code,422);self.assertIsNone(self.saved)
   response=self.post('male_average','long_sleeve_top','auto',key='bad');self.assertEqual(response.status_code,401)
 def test_uncertain_or_mixed_photos_do_not_save_a_default_model(self):
  import types
  with patch.object(route,'get_recognizer',return_value=types.SimpleNamespace(recognize=lambda *args:(_ for _ in ()).throw(RecognitionError('Retake both photos.')))):
   response=self.post('female_average','short_sleeve_top','auto');self.assertEqual(response.status_code,422);self.assertIsNone(self.saved)
 def test_invalid_style_from_model_cannot_substitute_another_avatar(self):
  import types
  self.target={'profile':'male_average','category':'skirt','style':'pleated_skirt'};self.calls=0
  with patch.object(route,'get_recognizer',return_value=types.SimpleNamespace(recognize=self.recognized)):
   response=self.post('male_average','short_sleeve_top','auto');self.assertEqual(response.status_code,422);self.assertIsNone(self.saved)
if __name__=='__main__':unittest.main()
