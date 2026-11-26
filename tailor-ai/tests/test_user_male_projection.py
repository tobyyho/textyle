import unittest,hashlib
import numpy as np
from tailor_ai.garment3d import garment_photo_projection as p
from tailor_ai.garment3d import user_male_projection as u
from test_garment_photo_projection import top,pants
class UserMaleProjectionTests(unittest.TestCase):
    def test_all_seven_models_preserve_triangle_positions_normals_and_transforms(self):
        for spec in u.REGISTRY:
            with self.subTest(style=spec['style']):
                f,fm=pants() if spec['category'] in {'trousers','shorts'} else top(short=spec['style']=='tshirt')
                b,bm=pants(True) if spec['category'] in {'trousers','shorts'} else top(True,short=spec['style']=='tshirt')
                glb,meta=u.generate(spec['category'],f,b,fm,bm,b'front',b'back',male_template_style=spec['style'])
                _,old,parts,mapping=u.calibration(spec['style']);new,blob=p.decode_glb(glb)
                self.assertEqual(new['nodes'],old['nodes']);self.assertEqual(new['scenes'],old['scenes']);self.assertEqual(len(new['meshes']),len(old['meshes']))
                self.assertEqual(meta['templateSha256'],spec['sha256']);self.assertEqual(meta['sourceCategory'],spec['category'])
                self.assertTrue(meta['suppliedGeometry']['preserved']);self.assertTrue(meta['avatarFit']['bypassed']);self.assertIsNone(meta['geometryAdjustment'])
                self.assertEqual(meta['glbSha256'],hashlib.sha256(glb).hexdigest())
                for part in parts:
                    pr=new['meshes'][part['mesh']]['primitives'][part['primitive']];idx=p.accessor(new,blob,pr['indices']).ravel()
                    np.testing.assert_array_equal(p.accessor(new,blob,pr['attributes']['POSITION'])[idx],part['pos'][part['index']])
                    np.testing.assert_array_equal(p.accessor(new,blob,pr['attributes']['NORMAL'])[idx],part['normal'][part['index']])
                    uv=p.accessor(new,blob,pr['attributes']['TEXCOORD_0']);self.assertTrue(np.isfinite(uv).all());self.assertGreaterEqual(uv.min(),0);self.assertLessEqual(uv.max(),1)
                self.assertFalse(any('uri' in x for x in new.get('images',[])+new.get('buffers',[])))
    def test_category_and_explicit_style_must_agree(self):
        f,fm=top();b,bm=top(True)
        with self.assertRaises(p.ProjectionError):u.generate('short_sleeve_top',f,b,fm,bm,b'f',b'b',male_template_style='sweater')
        with self.assertRaises(p.ProjectionError):u.generate('trousers',f,b,fm,bm,b'f',b'b',male_template_style='unrecognised')
    def test_default_pants_are_jeans_and_dont_claim_style_classification(self):
        f,fm=pants();b,bm=pants(True)
        _,meta=u.generate('trousers',f,b,fm,bm,b'f',b'b')
        self.assertEqual(meta['maleTemplateStyle']['resolved'],'jeans');self.assertEqual(meta['maleTemplateStyle']['source'],'default')
        self.assertIn('pants_style_defaults_to_jeans_choose_style_to_change',meta['warnings'])
    def test_long_sleeve_override_selects_user_model(self):
        f,fm=top();b,bm=top(True)
        for style,key in [('tee','long_tee'),('sweater','sweater')]:
            _,meta=u.generate('long_sleeve_top',f,b,fm,bm,b'f',b'b',long_sleeve_style=style)
            self.assertEqual(meta['maleTemplateStyle']['resolved'],key)
if __name__=='__main__':unittest.main()
