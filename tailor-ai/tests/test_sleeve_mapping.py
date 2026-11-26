"""Generic synthetic pose/visibility tests, independent of any user's shirt."""
from __future__ import annotations

import importlib.util
import io
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image, ImageDraw

MODULE = Path(__file__).resolve().parents[1] / 'src/tailor_ai/garment3d/photo_projection.py'
spec = importlib.util.spec_from_file_location('sleeve_projection_test', MODULE)
projection = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = projection
spec.loader.exec_module(projection)


def shirt(angle=0, length=320, shade=160, sleeves=True):
    image = Image.new('RGBA', (320, 360), (0, 255, 0, 0))
    mask = Image.new('L', image.size, 0)
    body = [(105,65),(215,65),(220,length),(100,length)]
    left = [(110,65),(67,77),(25,127),(65,164),(111,131)]
    right = [(320-x,y) for x,y in left]
    draw = ImageDraw.Draw(image); md = ImageDraw.Draw(mask)
    draw.polygon(body, fill=(shade,shade,shade,255)); md.polygon(body, fill=255)
    # Deliberately put a high-contrast BODY graphic where the old sampler read.
    draw.rectangle((109,132,130,195), fill=(0,0,0,255))
    if sleeves:
        draw.polygon(left,fill=(220,30,40,255));md.polygon(left,fill=255)
        draw.polygon(right,fill=(30,60,220,255));md.polygon(right,fill=255)
        draw.line((48,119,74,145),fill=(255,230,150,255),width=8)
    if angle:
        image=image.rotate(angle,Image.Resampling.BILINEAR)
        mask=mask.rotate(angle,Image.Resampling.NEAREST)
    return image,np.array(mask)>127


def png(image):
    stream=io.BytesIO();image.save(stream,'PNG');return stream.getvalue()


class SleeveMappingTests(unittest.TestCase):
    def test_visible_left_right_sleeves_use_their_own_pixels(self):
        image,mask=shirt();crop=projection.automatic_torso_crop(mask)
        left,li=projection.sleeve_tile(image,mask,crop,'left')
        right,ri=projection.sleeve_tile(image,mask,crop,'right')
        self.assertEqual(li['mode'],'projected_estimate')
        self.assertEqual(ri['mode'],'projected_estimate')
        l=np.asarray(left);r=np.asarray(right)
        self.assertGreater(float((l[:,:,0]>l[:,:,2]+50).mean()),.75)
        self.assertGreater(float((r[:,:,2]>r[:,:,0]+50).mean()),.75)
        # Body graphic must not be copied repeatedly onto either sleeve.
        self.assertLess(float((l.mean(2)<20).mean()),.01)
        self.assertLess(float((r.mean(2)<20).mean()),.01)

    def test_visible_sleeve_detail_is_not_replaced_with_a_solid_colour(self):
        image,mask=shirt();crop=projection.automatic_torso_crop(mask)
        tile,info=projection.sleeve_tile(image,mask,crop,'left')
        self.assertEqual(info['mode'],'projected_estimate')
        pixels=np.asarray(tile)
        self.assertGreater(float(((pixels[:,:,0]>245)&(pixels[:,:,1]>180)).mean()),.01)

    def test_absent_or_folded_sleeves_have_constant_colour_fallback(self):
        image,mask=shirt(sleeves=False);crop=projection.automatic_torso_crop(mask)
        for side in ('left','right'):
            tile,info=projection.sleeve_tile(image,mask,crop,side)
            self.assertEqual(info['mode'],'estimated_colour')
            self.assertEqual(np.unique(np.asarray(tile).reshape(-1,3),axis=0).shape[0],1)

    def test_multiple_tilts_lengths_and_exposures_do_not_break_mapping(self):
        for angle,length,shade in [(-12,290,65),(0,320,160),(14,305,230)]:
            with self.subTest(angle=angle,length=length,shade=shade):
                image,mask=shirt(angle,length,shade)
                crop=projection.automatic_torso_crop(mask)
                for side in ('left','right'):
                    tile,info=projection.sleeve_tile(image,mask,crop,side)
                    self.assertEqual(tile.size,(512,512))
                    self.assertIn(info['mode'],('projected_estimate','estimated_colour'))
                    self.assertGreaterEqual(info['coverage'],0)
                    self.assertLessEqual(info['coverage'],1)

    def test_background_alpha_is_never_projected_as_visible_fabric(self):
        image,mask=shirt();crop=projection.automatic_torso_crop(mask)
        for side in ('left','right'):
            tile,_=projection.sleeve_tile(image,mask,crop,side)
            px=np.asarray(tile)
            # Transparent background is bright green, unlike all garment colours.
            self.assertLess(float(((px[:,:,1]>240)&(px[:,:,0]<10)&(px[:,:,2]<10)).mean()),.001)

    def test_four_atlas_islands_are_allocated_by_view_and_physical_side(self):
        doc,binary=projection.decode_glb(projection.TEMPLATE_PATH.read_bytes())
        primitive=doc['meshes'][0]['primitives'][1]
        indices=projection.accessor(doc,binary,primitive['indices']).ravel()
        positions=projection.accessor(doc,binary,primitive['attributes']['POSITION'])[indices]
        normals=projection.accessor(doc,binary,primitive['attributes']['NORMAL'])[indices]
        uv=projection.projected_uv(positions,normals,True)
        front=np.repeat(normals.reshape(-1,3,3)[:,:,1].sum(1)>=0,3)
        left=np.repeat(positions.reshape(-1,3,3)[:,:,0].mean(1)<(projection.X0+projection.X1)/2,3)
        expected={ (True,True):0,(True,False):1,(False,False):2,(False,True):3 }
        for (f,l),tile in expected.items():
            selected=(front==f)&(left==l)
            self.assertTrue(selected.any())
            self.assertTrue((uv[selected,0]>tile/4).all())
            self.assertTrue((uv[selected,0]<(tile+1)/4).all())
        self.assertTrue(np.isfinite(uv).all())
        self.assertTrue((uv[:,1]>.75).all())

    def test_generation_records_estimated_sleeves_without_claiming_review(self):
        image,mask=shirt(sleeves=False)
        rgba=png(image);m=png(Image.fromarray(mask.astype(np.uint8)*255))
        _,sidecar=projection.generate(rgba,rgba,m,m,b'front',b'back')
        self.assertEqual(sidecar['mappingVersion'],'mask_sleeve_regions_v4_soft_seams')
        self.assertFalse(sidecar['userReviewed'])
        self.assertIn('some_sleeve_regions_use_estimated_colour',sidecar['warnings'])
        self.assertEqual(sidecar['sleeveMapping']['front']['left']['mode'],'estimated_colour')

if __name__=='__main__':unittest.main()
