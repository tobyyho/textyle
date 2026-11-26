"""Real HTTP routing/auth tests; classifier and segmentation are explicit stubs."""
import asyncio,copy,hashlib,importlib.util,json
from pathlib import Path
import sys,tempfile,types,unittest
from unittest.mock import patch
from fastapi import FastAPI,HTTPException
from fastapi.testclient import TestClient
from test_garment_photo_projection import top,pants

MODULE=Path(__file__).resolve().parents[1]/'src/tailor_ai/api/automatic_preview.py'

def fake_prepare(data):return types.SimpleNamespace(source=data,classifier_data=data)
spec=importlib.util.spec_from_file_location('automatic_garment_route_test',MODULE)
route=importlib.util.module_from_spec(spec)
with patch.dict(sys.modules,{'tailor_ai.digitization.images':types.SimpleNamespace(prepare=fake_prepare)}):
    spec.loader.exec_module(route)

class RouteTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.counter=0;self.category='long_sleeve_top';self.abstained=False;self.accepted=True
        self.saved=None;self.app=FastAPI();state=self.app.state
        @self.app.middleware('http')
        async def request_id(request,call_next):
            request.state.request_id='test-request';return await call_next(request)
        state.semaphore=asyncio.Semaphore(1)
        state.digitization_limiter=state.garment3d_limiter=types.SimpleNamespace(check=lambda key:None)
        state.asset_store=types.SimpleNamespace(get=lambda key:str(Path(self.tmp.name)/key))
        state.garment3d_store=types.SimpleNamespace(put=self.store_model,ttl_seconds=900)
        state.runtime=types.SimpleNamespace(decode=lambda image:image,predict=self.classify)
        route.register_automatic_preview(self.app,require_key=self.require_key,get_digitizer=self.get_digitizer)
        self.client=TestClient(self.app)
    def tearDown(self):self.client.close();self.tmp.cleanup()
    def require_key(self,request,key):
        if key!='test-key':raise HTTPException(401,'API key required')
    def classify(self,data):
        return {'category':self.category,'confidence':.96,'abstained':self.abstained,
            'top_predictions':[{'category':self.category,'confidence':.96}],
            'sleeve_type':'not_applicable' if self.category=='trousers' else 'long_sleeve'}
    async def get_digitizer(self,request):return types.SimpleNamespace(process=self.digitize)
    def asset(self,data):
        self.counter+=1;key=str(self.counter);(Path(self.tmp.name)/key).write_bytes(data)
        return {'id':key,'sha256':hashlib.sha256(data).hexdigest()}
    def digitize(self,front,back,classification,**kwargs):
        views={}
        for name,image in [('front',front),('back',back)]:
            normalized,mask=pants(name=='back') if self.category=='trousers' else top(name=='back',short=self.category=='short_sleeve_top')
            nr,mr=self.asset(normalized),self.asset(mask)
            views[name]={'view':name,'segmentation':{'candidate_accepted':self.accepted},
                'identity':{'source_image_sha256':hashlib.sha256(image.source).hexdigest(),
                    'normalized_image_sha256':nr['sha256'],'mask_sha256':mr['sha256']},
                'preview_assets':{'normalized':nr,'mask':mr}}
        return {'views':views,'readiness':{'segmentation_ready':False,'try_on_ready':False},'warnings':[]}
    def store_model(self,glb,sidecar):self.saved=(glb,json.loads(sidecar));return 'generated-test'
    def post(self,profile='male_average',key='test-key',confirmed=None,style='auto'):
        f,_=pants() if self.category=='trousers' else top();b,_=pants(True) if self.category=='trousers' else top(True)
        return self.client.post('/api/v1/clothing/automatic-preview',headers={'X-API-Key':key},
            data={'garment_id':'route-test','body_profile':profile,'source':'closet_camera','long_sleeve_style':style, **({'confirmed_category':confirmed} if confirmed else {})},
            files={'front_image':('front.png',f,'image/png'),'back_image':('back.png',b,'image/png')})
    def test_explicit_category_confirmation_preserves_original_uncertainty(self):
        self.category='outerwear';self.abstained=True
        r=self.post(confirmed='long_sleeve_top');self.assertEqual(r.status_code,200,r.text)
        response=r.json();self.assertEqual(response['classification']['category'],'long_sleeve_top')
        self.assertEqual(response['classification']['confidence'],0)
        self.assertEqual(response['classification']['original_model_prediction']['category'],'outerwear')
        self.assertTrue(response['classification']['original_model_prediction']['abstained'])
        self.assertEqual(self.saved[1]['categoryResolution'],{'source':'user','confirmed_category':'long_sleeve_top'})
        self.assertFalse(self.saved[1]['userReviewed'])
    def test_type_selection_cannot_bypass_bad_masks_or_allow_unknown_templates(self):
        self.abstained=True;self.accepted=False
        self.assertEqual(self.post(confirmed='long_sleeve_top').status_code,422)
        self.assertIsNone(self.saved)
        self.assertEqual(self.post(confirmed='dress').status_code,422)

    def test_style_override_roundtrips_and_invalid_values_are_rejected(self):
        r=self.post(style='sweater');self.assertEqual(r.status_code,200,r.text)
        self.assertEqual(r.json()['generated_preview']['hem_style']['resolved'],'sweater')
        self.assertEqual(self.saved[1]['hemStyle']['source'],'user')
        self.assertEqual(self.saved[1]['suppliedGeometry']['style'],'sweater')
        self.assertEqual(self.post(style='unknown').status_code,422)

    def test_long_sleeve_and_pants_dispatch_to_each_avatar_template(self):
        for profile,category,version in [
            ('male_average','long_sleeve_top','male_user_long_tee_v1'),
            ('female_average','long_sleeve_top','female_long_sleeve_photo_v1'),
            ('male_average','trousers','male_user_jeans_v1'),
            ('female_average','trousers','female_trousers_photo_v1'),
            ('female_average','short_sleeve_top','female_tshirt_auto_projection_v1')]:
            with self.subTest(profile=profile,category=category):
                self.category=category;r=self.post(profile);self.assertEqual(r.status_code,200,r.text)
                self.assertEqual(r.json()['generated_preview']['template_version'],version)
                self.assertEqual(self.saved[1]['bodyProfile'],profile);self.assertEqual(self.saved[1]['sourceCategory'],category)
                self.assertFalse(self.saved[1]['userReviewed']);self.assertTrue(self.saved[1]['segmentationCandidatesAccepted'])
    def test_male_tshirt_uses_supplied_geometry_generator(self):
        self.category='short_sleeve_top'
        with patch.object(route,'generate_user_male',wraps=route.generate_user_male) as old:
            r=self.post();self.assertEqual(r.status_code,200,r.text);old.assert_called_once()
        self.assertEqual(r.json()['generated_preview']['template_version'],'male_user_tshirt_v1')
    def test_unauthenticated_requests_cannot_generate_models(self):
        self.assertEqual(self.post(key='wrong').status_code,401);self.assertIsNone(self.saved)
    def test_abstention_unsupported_category_and_rejected_masks_do_not_generate_models(self):
        self.abstained=True;self.assertEqual(self.post().status_code,422);self.assertIsNone(self.saved)
        self.abstained=False;self.category='dress';self.assertEqual(self.post().status_code,422);self.assertIsNone(self.saved)
        self.category='long_sleeve_top';self.accepted=False;self.assertEqual(self.post().status_code,422);self.assertIsNone(self.saved)

if __name__=='__main__':unittest.main()
