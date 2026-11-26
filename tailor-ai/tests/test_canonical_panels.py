"""Physical proportions, isolation and UV layout across the 2D-to-3D boundary."""
import io
import unittest
import numpy as np
from PIL import Image, ImageDraw
from tailor_ai.garment3d import canonical_panels as c
from tailor_ai.garment3d import garment_photo_projection as p


def png(image):
    stream = io.BytesIO(); image.save(stream, 'PNG'); return stream.getvalue()


class CanonicalPanelTests(unittest.TestCase):
    def test_circle_stays_round_in_model_units_for_different_template_aspects(self):
        image = Image.new('RGB', (200, 300), (60, 40, 30))
        ImageDraw.Draw(image).ellipse((70, 110, 130, 170), fill=(240, 230, 220))
        mask = np.zeros((300, 200), bool); mask[10:290, 20:180] = True
        for dims in ((.5, .7), (.8, .5), (.25, .8)):
            tile, report = c._place(image, mask, dims, (512, 512), [60, 40, 30])
            singular = np.linalg.svd(report['source_to_panel_linear'], compute_uv=False)
            np.testing.assert_allclose(singular, singular[0], rtol=1e-6)
            yy, xx = np.nonzero(np.asarray(tile)[:, :, 0] > 180)
            physical_ratio = (np.ptp(xx)+1)*dims[0]/((np.ptp(yy)+1)*dims[1])
            self.assertAlmostEqual(physical_ratio, 1, delta=.04)

    def test_background_cannot_bleed_into_fabric_or_print(self):
        mask = np.zeros((100, 100), bool); mask[20:80, 30:70] = True
        a = np.zeros((100, 100, 3), np.uint8); a[mask] = [140, 50, 25]
        b = a.copy(); b[~mask] = [0, 255, 0]
        aa, _ = c._place(Image.fromarray(a), mask, (.4, .6), (256, 256), [80, 60, 40])
        bb, _ = c._place(Image.fromarray(b), mask, (.4, .6), (256, 256), [80, 60, 40])
        np.testing.assert_array_equal(aa, bb)

    def test_angled_sleeve_uses_rotation_and_uniform_scale(self):
        image = Image.new('RGB', (220, 300), (70, 40, 30))
        mask_image = Image.new('L', image.size)
        ImageDraw.Draw(mask_image).polygon([(25, 25), (65, 10), (200, 270), (160, 290)], fill=255)
        mask = np.asarray(mask_image) > 0
        _, report = c._place(image, mask, (.2, .6), (256, 512), [70, 40, 30], rotate=True)
        matrix = np.asarray(report['source_to_panel_linear'])
        self.assertGreater(abs(matrix[0, 1]), .00001)
        singular = np.linalg.svd(matrix, compute_uv=False)
        self.assertAlmostEqual(float(singular[0]), float(singular[1]), places=9)

    def test_bottom_uv_does_not_squeeze_rows_or_flip_back_artwork(self):
        mapping = {'min': np.array([-.4, 0, 0]), 'max': np.array([.4, 1, .1]), 'canonical_panels_version': c.VERSION}
        points = np.array([[-.2, .8, 0], [.2, .8, 0], [-.2, .2, 0], [.2, .2, 0]])
        front = p.projected_uv(points, np.zeros(4), np.ones(4, bool), {'category': 'trousers'}, mapping)
        back = p.projected_uv(points, np.zeros(4), np.zeros(4, bool), {'category': 'trousers'}, mapping)
        self.assertAlmostEqual(float(front[1, 0]-front[0, 0]), float(front[3, 0]-front[2, 0]))
        np.testing.assert_allclose(front[:, 0]+back[:, 0], 1, atol=1e-6)

    def test_front_and_back_have_independent_colours_and_panel_reports(self):
        mask = np.zeros((300, 240), bool); mask[20:280, 40:200] = True
        binary = png(Image.fromarray(mask.astype('uint8')*255))
        front = png(Image.new('RGBA', (240, 300), (100, 60, 30, 255)))
        back = png(Image.new('RGBA', (240, 300), (30, 60, 100, 255)))
        mapping = {'body_min': np.array([-.3, 0, 0]), 'body_max': np.array([.3, .7, .1]),
                   'arms': {g: (None, None, None, 0, .5, 0, .2) for g in (1, 2)}}
        fabric = {'reconstruction': {'views': {'front': {'base_rgb': [100, 60, 30]}, 'back': {'base_rgb': [30, 60, 100]}}}}
        atlas, crops, details = c.make_atlas(front, back, binary, binary, {'category': 'short_sleeve_top'}, mapping, fabric)
        pixels = np.asarray(atlas)
        np.testing.assert_array_equal(pixels[500, 512], [100, 60, 30])
        np.testing.assert_array_equal(pixels[500, 1536], [30, 60, 100])
        np.testing.assert_array_equal(pixels[1900, 512], [100, 60, 30])
        self.assertFalse(details['front']['panels']['torso']['row_stretch'])
        self.assertEqual(fabric['canonical2D']['version'], c.VERSION)
        self.assertEqual(set(crops), {'front', 'back'})

    def test_short_pants_have_two_legs_and_joined_or_missing_legs_fail(self):
        mask = np.zeros((500, 300), bool); mask[20:220, 50:250] = True
        mask[220:450, 50:130] = True; mask[220:420, 170:250] = True
        regions, split = c._pants_regions(mask)
        self.assertEqual(len(regions), 3)
        self.assertLess(split, 250)
        joined = mask.copy(); joined[220:450, 130:170] = True
        missing = mask.copy(); missing[220:, 170:] = False
        for invalid in (joined, missing):
            with self.assertRaises(p.ProjectionError): c._pants_regions(invalid)

    def test_skirts_use_whole_panel_instead_of_waist_and_leg_detection(self):
        mask = np.zeros((300, 200), bool); mask[10:290, 20:180] = True
        binary = png(Image.fromarray(mask.astype('uint8')*255))
        image = png(Image.new('RGBA', (200, 300), (90, 50, 30, 255)))
        mapping = {'min': np.array([-.3, 0, 0]), 'max': np.array([.3, .7, .1]), 'crotch_ratio': 1.1}
        fabric = {'reconstruction': {'views': {v: {'base_rgb': [90, 50, 30]} for v in ('front', 'back')}}}
        _, _, details = c.make_atlas(image, image, binary, binary, {'category': 'trousers'}, mapping, fabric)
        self.assertEqual(set(details['front']['panels']), {'skirt'})


if __name__ == '__main__': unittest.main()
