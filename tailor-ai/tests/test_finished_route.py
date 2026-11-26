"""HTTP auth, confirmed categories, avatar separation and geometry-fit bypass."""
import asyncio,hashlib,importlib.util,json,sys,tempfile,types,unittest
from pathlib import Path
from unittest.mock import patch
from fastapi import FastAPI,HTTPException
from fastapi.testclient import TestClient
from test_finished_projection import photos
MODULE=Path(__file__).resolve().parents[1]/'src/tailor_ai/api/automatic_preview.py'
spec=importlib.util.spec_from_file_location('finished_route_under_test',MODULE);route=importlib.util.module_from_spec(spec)
with patch.dict(sys.modules,{'tailor_ai.digitization.images':types.SimpleNamespace(prepare=lambda data:types.SimpleNamespace(source=data,classifier_data=data))}):spec.loader.exec_module(route)
class FinishedRouteTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.counter=0;self.saved=None;self.category='short_sleeve_top';self.abstained=False;self.accepted=True;self.app=FastAPI();state=self.app.state
        @self.app.middleware('http')
        async def request_id(request,call_next):request.state.request_id='test';return await call_next(request)
        state.semaphore=asyncio.Semaphore(1);state.digitization_limiter=state.garment3d_limiter=types.SimpleNamespace(check=lambda key:None);state.asset_store=types.SimpleNamespace(get=lambda key:str(Path(self.tmp.name)/key));state.garment3d_store=types.SimpleNamespace(put=self.save,ttl_seconds=900);state.runtime=types.SimpleNamespace(decode=lambda image:image,predict=lambda image:{'category':self.category,'confidence':.65,'abstained':self.abstained,'top_predictions':[{'category':self.category,'confidence':.65}],'sleeve_type':'long_sleeve'})
        route.register_automatic_preview(self.app,require_key=self.require_key,get_digitizer=self.get_digitizer);self.client=TestClient(self.app)
    def tearDown(self):self.client.close();self.tmp.cleanup()
    def require_key(self,request,key):
        if key!='test-key':raise HTTPException(401,'API key required')
    def asset(self,data):
        self.counter+=1;key=str(self.counter);(Path(self.tmp.name)/key).write_bytes(data);return {'id':key,'sha256':hashlib.sha256(data).hexdigest()}
    async def get_digitizer(self,request):return types.SimpleNamespace(process=self.digitize)
    def digitize(self,front,back,classification,**kwargs):
        views={}
        for view,original in [('front',front),('back',back)]:
            image,mask=photos(classification['category'],view=='back');nr,mr=self.asset(image),self.asset(mask);views[view]={'view':view,'segmentation':{'candidate_accepted':self.accepted},'identity':{'source_image_sha256':hashlib.sha256(original.source).hexdigest(),'normalized_image_sha256':nr['sha256'],'mask_sha256':mr['sha256']},'preview_assets':{'normalized':nr,'mask':mr}}
        return {'views':views,'readiness':{'segmentation_ready':False,'try_on_ready':False},'warnings':[]}
    def save(self,glb,sidecar):self.saved=(glb,json.loads(sidecar));return 'test-model'
    def post(self,profile,category,style,key='test-key',confirmed=None,extra=None):
        self.category=category;self.saved=None;f,_=photos(category);b,_=photos(category,True);data={'body_profile':profile,'garment_id':'test-garment','template_catalog':'finished_v1','final_template_style':style,**({'confirmed_category':confirmed} if confirmed else {}),**(extra or {})}
        return self.client.post('/api/v1/clothing/automatic-preview',headers={'X-API-Key':key},data=data,files={'front_image':('front.png',f,'image/png'),'back_image':('back.png',b,'image/png')})
    def test_skirt_hoodie_and_both_avatar_pants_use_final_models_and_never_refit(self):
        for profile,category,style in [('female_average','skirt','pleated_skirt'),('male_average','outerwear','zip_hoodie'),('female_average','outerwear','hoodie'),('female_average','long_sleeve_top','button_up'),('female_average','long_sleeve_top','long_tee'),('female_average','trousers','capris'),('male_average','trousers','drawstring_sweats')]:
            with self.subTest(style=style),patch.object(route,'fit_glb',side_effect=AssertionError('Finished geometry must never be refitted')):
                response=self.post(profile,category,style);self.assertEqual(response.status_code,200,response.text);self.assertEqual(self.saved[1]['finalTemplateStyle']['resolved'],style);self.assertTrue(self.saved[1]['avatarFit']['bypassed']);self.assertEqual(response.json()['generated_preview']['template_catalog'],'finished_v1')
    def test_auth_bad_masks_wrong_category_wrong_avatar_and_mixed_legacy_style_fail(self):
        self.assertEqual(self.post('female_average','trousers','skinny_jeans',key='bad').status_code,401)
        self.assertEqual(self.post('female_average','trousers','zip_hoodie').status_code,422)
        self.assertEqual(self.post('male_average','short_sleeve_top','shorts').status_code,422)
        self.assertEqual(self.post('male_average','trousers','ankle_sweats',extra={'male_template_style':'jeans'}).status_code,422)
        self.accepted=False;self.assertEqual(self.post('female_average','skirt','pleated_skirt').status_code,422);self.assertIsNone(self.saved)
    def test_confirmed_type_does_not_invent_classifier_confidence_or_user_review(self):
        self.abstained=True;response=self.post('female_average','outerwear','pleated_skirt',confirmed='skirt');self.assertEqual(response.status_code,200,response.text);meta=self.saved[1];self.assertEqual(meta['originalClassification']['category'],'outerwear');self.assertTrue(meta['originalClassification']['abstained']);self.assertFalse(meta['userReviewed']);self.assertEqual(response.json()['classification']['confidence'],0)
if __name__=='__main__':unittest.main()
