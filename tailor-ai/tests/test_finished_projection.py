"""Approved-template geometry, identities and separate photo views are immutable."""
import io,json,unittest
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from tailor_ai.garment3d import finished_projection as u
from tailor_ai.garment3d import garment_photo_projection as p

def png(im):
    b=io.BytesIO();im.save(b,'PNG');return b.getvalue()
def photos(category,back=False):
    im=Image.new('RGBA',(500,760),(0,255,0,0));mask=Image.new('L',im.size,0);d=ImageDraw.Draw(im);m=ImageDraw.Draw(mask)
    shape=([(125,50),(375,50),(365,240),(335,700),(280,700),(250,245),(220,700),(165,700),(135,240)] if category in {'trousers','shorts'} else [(170,60),(330,60),(420,690),(80,690)] if category=='skirt' else [(145,80),(355,80),(440,610),(385,630),(350,200),(355,690),(145,690),(150,200),(115,630),(60,610)])
    d.polygon(shape,fill=(50,70,190,255) if back else (190,70,50,255));m.polygon(shape,fill=255);d.text((220,250),'BACK' if back else 'FRONT',fill=(0,0,0,255));return png(im),png(mask)
class FinishedProjectionTests(unittest.TestCase):
    def test_all_twenty_models_keep_exact_triangle_positions_normals_and_node_transforms(self):
        self.assertEqual(len(u.REGISTRY),20)
        self.assertEqual(len([s for s in u.REGISTRY if s['profile']=='male_average']),9)
        for spec in u.REGISTRY:
            with self.subTest(profile=spec['profile'],style=spec['style']):
                before=(u.ROOT/spec['filename']).read_bytes();f,fm=photos(spec['category']);b,bm=photos(spec['category'],True)
                glb,meta=u.generate(spec['profile'],spec['category'],f,b,fm,bm,b'original-front',b'original-back',final_template_style=spec['style'])
                _,_,doc,parts,_=u.calibration(spec['profile'],spec['style']);new,blob=p.decode_glb(glb)
                self.assertEqual(new.get('scene'),doc.get('scene'))
                self.assertEqual(new['nodes'][:len(doc['nodes'])],doc['nodes'])
                for before_scene,after_scene in zip(doc['scenes'],new['scenes']):
                    self.assertEqual(after_scene['nodes'][:len(before_scene['nodes'])],before_scene['nodes'])
                repair=meta['geometryAdjustment']
                self.assertEqual(len(new['meshes']),len(doc['meshes'])+(1 if repair else 0))
                if repair:
                    self.assertEqual(repair['original_vertices_moved'],0)
                    self.assertEqual(repair['original_triangles_removed'],0)
                    self.assertLessEqual(repair['max_x_span_metres'],.045001)
                    self.assertLessEqual(repair['max_z_span_metres'],.045001)
                    self.assertEqual(repair['source_template_sha256'],spec['sha256'])
                    self.assertLessEqual(repair['max_cover_offset_metres'],.008001)
                    self.assertLessEqual(repair['added_triangles'],6000)
                    self.assertLessEqual(repair['covered_intersections'],1000)
                    expected=sum(h['boundary_vertices']-2 for h in repair['holes'])+len(repair['surface_covers'])
                    self.assertEqual(repair['source_triangles'],expected)
                    self.assertEqual(repair['added_triangles'],expected*4**repair['subdivision_steps'])
                for part in parts:
                    pr=new['meshes'][part['mesh']]['primitives'][part['primitive']];idx=p.accessor(new,blob,pr['indices']).ravel()
                    np.testing.assert_array_equal(p.accessor(new,blob,pr['attributes']['POSITION'])[idx],part['pos'][part['index']])
                    np.testing.assert_array_equal(p.accessor(new,blob,pr['attributes']['NORMAL'])[idx],part['normal'][part['index']])
                    uv=p.accessor(new,blob,pr['attributes']['TEXCOORD_0']);self.assertTrue(np.isfinite(uv).all());self.assertGreaterEqual(float(uv.min()),0);self.assertLessEqual(float(uv.max()),1)
                self.assertEqual(meta['templateSha256'],spec['sha256']);self.assertEqual(meta['bodyProfile'],spec['profile']);self.assertEqual(meta['sourceCategory'],spec['category']);self.assertEqual(meta['finalTemplateStyle']['resolved'],spec['style']);self.assertTrue(meta['suppliedGeometry']['preserved']);self.assertTrue(meta['avatarFit']['bypassed']);self.assertEqual(meta['glbSha256'],p.digest(glb));self.assertFalse(meta['userReviewed']);self.assertEqual((u.ROOT/spec['filename']).read_bytes(),before)
                self.assertFalse(any('uri'in x for x in new.get('images',[])+new.get('buffers',[])));self.assertEqual(len(new['images']),1);self.assertLess(len(glb),24*1024*1024)
                self.assertEqual(meta['partMapping']['front']['mode'],'canonical_material_panels_v1')
                self.assertEqual(meta['fabricAppearance']['canonical2D']['version'],'canonical_material_panels_v1')
    def test_style_category_and_avatar_cannot_be_substituted(self):
        f,fm=photos('short_sleeve_top');b,bm=photos('short_sleeve_top',True)
        for profile,category,style in [('female_average','short_sleeve_top','zip_hoodie'),('male_average','short_sleeve_top','sweater'),('male_average','trousers','skinny_jeans'),('female_average','dress','tshirt')]:
            with self.subTest(style=style),self.assertRaises(p.ProjectionError):u.generate(profile,category,f,b,fm,bm,b'f',b'b',final_template_style=style)
    def test_modified_finished_template_is_rejected(self):
        spec=u.REGISTRY[0];old=spec['sha256'];u.calibration.cache_clear()
        try:
            spec['sha256']='bad'
            with self.assertRaises(p.ProjectionError):u.calibration(spec['profile'],spec['style'])
        finally:spec['sha256']=old;u.calibration.cache_clear()
    def test_automatic_style_is_explicitly_a_default_not_an_ai_subtype_claim(self):
        f,fm=photos('trousers');b,bm=photos('trousers',True)
        spec,resolution,hem=u.resolve_template('female_average','trousers','auto',f,b,fm,bm,'auto');self.assertEqual(spec['style'],'skinny_jeans');self.assertEqual(resolution['source'],'default')
if __name__=='__main__':unittest.main()
