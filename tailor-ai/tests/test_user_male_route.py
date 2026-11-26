import unittest,hashlib
from unittest.mock import patch
import test_automatic_garment_route as harness_module
from test_garment_photo_projection import top,pants
class UserMaleRouteTests(unittest.TestCase):
    def setUp(self):
        self.h=harness_module.RouteTests();self.h.setUp()
        original=self.h.digitize
        def digitize(front,back,classification,**kwargs):
            previous=self.h.category
            if classification['category'] in {'shorts','trousers'}:self.h.category='trousers'
            try:return original(front,back,classification,**kwargs)
            finally:self.h.category=previous
        self.h.digitize=digitize
    def tearDown(self):self.h.tearDown()
    def post(self,category,style='auto',profile='male_average',confirmed=None,key='test-key',long='auto'):
        self.h.category=category
        f,_=pants() if category in {'trousers','shorts'} else top();b,_=pants(True) if category in {'trousers','shorts'} else top(True)
        return self.h.client.post('/api/v1/clothing/automatic-preview',headers={'X-API-Key':key},
            data={'garment_id':'route-test','body_profile':profile,'source':'closet_camera','male_template_style':style,'long_sleeve_style':long,
                  **({'confirmed_category':confirmed} if confirmed else {})},
            files={'front_image':('front.png',f,'image/png'),'back_image':('back.png',b,'image/png')})
    def test_each_supplied_style_reaches_its_exact_geometry_identity(self):
        for category,style in [('short_sleeve_top','tshirt'),('long_sleeve_top','long_tee'),('long_sleeve_top','sweater'),('trousers','jeans'),('trousers','black_pants'),('trousers','ankle_sweats'),('shorts','shorts')]:
            with self.subTest(style=style):
                response=self.post(category,style)
                self.assertEqual(response.status_code,200,response.text)
                glb,meta=self.h.saved;self.assertEqual(meta['templateVersion'],'male_user_'+style+'_v1')
                self.assertTrue(meta['suppliedGeometry']['preserved']);self.assertTrue(meta['avatarFit']['bypassed'])
                self.assertEqual(meta['glbSha256'],hashlib.sha256(glb).hexdigest())
    def test_female_path_stays_on_existing_templates(self):
        response=self.post('trousers',profile='female_average');self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(self.h.saved[1]['templateVersion'],'female_trousers_photo_v1');self.assertNotIn('suppliedGeometry',self.h.saved[1])
        self.assertEqual(self.post('shorts',profile='female_average').status_code,422)
    def test_rejects_wrong_style_failed_masks_and_missing_auth(self):
        self.assertEqual(self.post('short_sleeve_top','jeans').status_code,422)
        self.assertEqual(self.post('trousers','jeans',profile='female_average').status_code,422)
        self.assertEqual(self.post('shorts','shorts',key='wrong').status_code,401)
        self.h.accepted=False;self.assertEqual(self.post('shorts','shorts').status_code,422)
    def test_manual_shorts_selection_preserves_classifier_uncertainty(self):
        self.h.abstained=True;response=self.post('outerwear','shorts',confirmed='shorts')
        self.assertEqual(response.status_code,200,response.text);meta=self.h.saved[1]
        self.assertEqual(meta['originalClassification']['category'],'outerwear');self.assertTrue(meta['originalClassification']['abstained'])
        self.assertEqual(meta['sourceCategory'],'shorts')
if __name__=='__main__':unittest.main()
