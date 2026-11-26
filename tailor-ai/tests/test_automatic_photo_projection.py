"""Run from the Tailor checkout with: python -m unittest discover -s tests -p test_automatic_photo_projection.py -v"""
from __future__ import annotations

import importlib.util
import io
import json
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image, ImageDraw

MODULE = Path(__file__).resolve().parents[1] / 'src/tailor_ai/garment3d/photo_projection.py'
spec = importlib.util.spec_from_file_location('photo_projection_under_test', MODULE)
projection = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = projection
spec.loader.exec_module(projection)


def fixture(color, hanger=False):
    image = Image.new('RGBA', (256, 256), (20, 250, 20, 0))
    mask = Image.new('L', (256, 256), 0)
    polygon = [(87, 40), (109, 49), (146, 49), (169, 40), (222, 80),
               (203, 109), (186, 97), (186, 229), (70, 229), (70, 97), (50, 109), (32, 80)]
    ImageDraw.Draw(image).polygon(polygon, fill=(*color, 255))
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    if hanger:
        ImageDraw.Draw(image).rectangle((60, 22, 195, 24), fill=(1, 2, 3, 255))
        ImageDraw.Draw(mask).rectangle((60, 22, 195, 24), fill=255)
    def png(im):
        s = io.BytesIO(); im.save(s, 'PNG'); return s.getvalue()
    return png(image), png(mask)


class AutomaticProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.front, cls.fm = fixture((220, 30, 40), hanger=True)
        cls.back, cls.bm = fixture((30, 60, 220))
        cls.output, cls.sidecar = projection.generate(cls.front, cls.back, cls.fm, cls.bm, b'front-original', b'back-original')

    def test_automatic_crop_excludes_thin_hanger_and_sleeves(self):
        image, mask = projection._load_cutout(self.front, self.fm)
        crop = projection.automatic_torso_crop(mask)
        self.assertGreater(crop['y'], 24 / 256)
        self.assertGreater(crop['x'], 60 / 256)
        self.assertLess(crop['w'], .6)
        self.assertGreater(crop['h'], .6)

    def test_output_hashes_are_bound_to_both_source_views(self):
        self.assertEqual(self.sidecar['frontSha256'], projection.digest(b'front-original'))
        self.assertEqual(self.sidecar['backSha256'], projection.digest(b'back-original'))
        self.assertEqual(self.sidecar['displayFrontSha256'], projection.digest(self.front))
        self.assertEqual(self.sidecar['frontMaskSha256'], projection.digest(self.fm))
        self.assertEqual(self.sidecar['glbSha256'], projection.digest(self.output))
        self.assertFalse(self.sidecar['userReviewed'])

    def test_output_keeps_all_original_node_transforms_and_triangle_positions(self):
        old, old_binary = projection.decode_glb(projection.TEMPLATE_PATH.read_bytes())
        new, new_binary = projection.decode_glb(self.output)
        self.assertEqual(old['nodes'], new['nodes'])
        self.assertEqual(old['scenes'], new['scenes'])
        triangles = 0
        for op, np_ in zip(old['meshes'][0]['primitives'], new['meshes'][0]['primitives']):
            indices = projection.accessor(old, old_binary, op['indices']).ravel()
            expected = projection.accessor(old, old_binary, op['attributes']['POSITION'])[indices]
            actual = projection.accessor(new, new_binary, np_['attributes']['POSITION'])
            np.testing.assert_array_equal(expected, actual)
            triangles += len(actual) // 3
        self.assertEqual(triangles, 27362)

    def test_front_back_texture_pixels_and_uv_partitions(self):
        new, binary = projection.decode_glb(self.output)
        v = new['bufferViews'][new['images'][0]['bufferView']]
        atlas = Image.open(io.BytesIO(binary[v['byteOffset']:v['byteOffset']+v['byteLength']]))
        self.assertEqual(atlas.size, (2048, 2048))
        self.assertEqual(atlas.getpixel((512, 800)), (220, 30, 40))
        self.assertEqual(atlas.getpixel((1536, 800)), (30, 60, 220))
        for p in new['meshes'][0]['primitives']:
            normals = projection.accessor(new, binary, p['attributes']['NORMAL'])
            uv = projection.accessor(new, binary, p['attributes']['TEXCOORD_0'])
            front = np.repeat(normals.reshape(-1,3,3)[:,:,1].sum(1)>=0,3)
            self.assertTrue((uv[front,0]<.5).all())
            self.assertTrue((uv[~front,0]>.5).all())
            self.assertTrue(np.isfinite(uv).all())

    def test_no_external_resources_or_original_photo_textures(self):
        new, _ = projection.decode_glb(self.output)
        self.assertEqual(len(new['images']), 1)
        self.assertEqual(len(new['materials']), 1)
        self.assertTrue(all('uri' not in x for x in new['images'] + new['buffers']))
        self.assertNotIn('red_black', json.dumps(new).lower())

    def test_reject_empty_or_mismatched_masks(self):
        empty = Image.new('L', (256,256), 0); stream=io.BytesIO();empty.save(stream,'PNG')
        with self.assertRaises(projection.ProjectionError):
            projection.make_atlas(self.front,self.back,stream.getvalue(),self.bm)
        wrong = Image.new('L', (128,128), 255);stream=io.BytesIO();wrong.save(stream,'PNG')
        with self.assertRaises(projection.ProjectionError):
            projection.make_atlas(self.front,self.back,stream.getvalue(),self.bm)

    def test_reject_changed_template(self):
        with self.assertRaises(projection.ProjectionError):
            projection.texture_template(b'png', template_data=b'wrong model')

    def test_generation_is_deterministic(self):
        output, sidecar = projection.generate(self.front,self.back,self.fm,self.bm,b'front-original',b'back-original')
        self.assertEqual(output,self.output)
        self.assertEqual(sidecar,self.sidecar)

if __name__ == '__main__':
    unittest.main()
