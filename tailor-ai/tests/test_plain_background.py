"""Plain-background contrast gates; synthetic regressions, not model accuracy."""
import unittest
import numpy as np
from PIL import Image,ImageDraw
from tailor_ai.digitization.plain_background import candidate

class PlainBackgroundTests(unittest.TestCase):
    def shirt(self):
        im=Image.new('RGB',(500,650),(245,238,223));d=ImageDraw.Draw(im)
        d.polygon([(110,80),(190,60),(310,60),(390,80),(425,585),(365,600),(340,180),(340,610),(160,610),(160,180),(135,600),(75,585)],fill=(134,87,65))
        d.rectangle((220,220,280,240),fill=(22,17,15))
        d.line((230,58,250,5,270,58),fill=(180,175,160),width=3)
        return im
    def test_plain_background_preserves_print_and_sleeves(self):
        c=candidate(self.shirt());self.assertIsNotNone(c)
        self.assertTrue(c.mask[230,250]);self.assertTrue(c.mask[550,100]);self.assertTrue(c.mask[550,400])
        self.assertFalse(c.mask[640,250]);self.assertFalse(c.mask[5,250]);self.assertFalse(c.checks['calibrated_probability'])
    def test_low_contrast_abstains(self):
        im=Image.new('RGB',(500,650),(210,210,210));ImageDraw.Draw(im).rectangle((100,100,400,600),fill=(205,205,205))
        self.assertIsNone(candidate(im))
    def test_busy_background_abstains(self):
        rng=np.random.default_rng(7);im=Image.fromarray(rng.integers(0,255,(650,500,3),dtype=np.uint8))
        self.assertIsNone(candidate(im))
    def test_second_substantial_object_abstains(self):
        im=self.shirt();ImageDraw.Draw(im).rectangle((440,100,490,500),fill=(10,10,10))
        self.assertIsNone(candidate(im))
    def test_clipped_garment_abstains(self):
        im=self.shirt();ImageDraw.Draw(im).rectangle((150,450,350,649),fill=(134,87,65))
        self.assertIsNone(candidate(im))
    def test_sleeve_and_pant_gaps_not_blanket_filled(self):
        c=candidate(self.shirt());self.assertIsNotNone(c);self.assertFalse(c.mask[450,145])
    def test_mask_is_deterministic_and_matches_source_dimensions(self):
        a=candidate(self.shirt());b=candidate(self.shirt())
        np.testing.assert_array_equal(a.mask,b.mask);self.assertEqual(a.mask.shape,(650,500))
if __name__=='__main__':unittest.main()
