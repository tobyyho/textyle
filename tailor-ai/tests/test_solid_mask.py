import io,tempfile,unittest
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from tailor_ai.digitization.solid_mask import preserve_interior
from tailor_ai.digitization.pipeline import DigitizationPipeline
from tailor_ai.digitization.assets import TemporaryAssetStore
from tailor_ai.providers.segmentation.base import SegmentationResult

class SolidMaskTests(unittest.TestCase):
    def test_enclosed_white_print_and_large_internal_holes_are_retained(self):
        mask=np.zeros((240,240),bool);mask[20:220,20:220]=True;mask[60:170,70:160]=False
        out,count=preserve_interior(mask);self.assertEqual(count,110*90)
        self.assertTrue(out[60:170,70:160].all());self.assertFalse(out[0].any())
        self.assertTrue(np.all(out[mask]))
    def test_neckline_and_sleeve_and_leg_gaps_connected_to_outside_stay_open(self):
        mask=np.zeros((300,260),bool);mask[30:270,20:240]=True
        mask[:80,100:160]=False;mask[180:,100:160]=False;mask[90:240,:45]=False
        out,count=preserve_interior(mask);np.testing.assert_array_equal(out,mask);self.assertEqual(count,0)
    def test_diagonal_background_connection_is_preserved(self):
        mask=np.ones((20,20),bool);np.fill_diagonal(mask,False)
        out,count=preserve_interior(mask);np.testing.assert_array_equal(out,mask);self.assertEqual(count,0)
    def test_invalid_input_fails(self):
        for mask in (np.zeros(10),np.full((10,10),np.nan)):
            with self.assertRaises(ValueError):preserve_interior(mask)
    def test_pipeline_restores_original_rgb_without_fabricating_review(self):
        im=Image.new('RGB',(300,340),(75,40,25));ImageDraw.Draw(im).rectangle((115,135,184,204),fill=(245,240,230))
        mask=np.zeros((340,300),bool);mask[30:310,30:270]=True;mask[135:205,115:185]=False
        class Segmenter:
            def segment(self,image):return SegmentationResult(mask,(30,30,270,310),float(mask.mean()),.97,(),'stub')
        b=io.BytesIO();im.save(b,'PNG')
        with tempfile.TemporaryDirectory() as temp:
            store=TemporaryAssetStore(Path(temp));result=DigitizationPipeline(Segmenter(),store).process_view(b.getvalue(),'front',allow_plain_background=True)
            self.assertTrue(result['segmentation']['candidate_accepted']);self.assertFalse(result['segmentation']['user_approved'])
            self.assertEqual(result['segmentation']['interior_pixels_restored'],4900)
            source_mask=np.asarray(Image.open(store.get(result['preview_assets']['source_mask']['id'])))
            self.assertTrue(source_mask[135:205,115:185].all())
            rgba=np.asarray(Image.open(store.get(result['preview_assets']['normalized']['id'])))
            center=rgba[512,512];self.assertEqual(int(center[3]),255)
            np.testing.assert_array_equal(center[:3],[245,240,230])
            working=np.asarray(Image.open(store.get(result['preview_assets']['working']['id'])))
            np.testing.assert_array_equal(working,np.asarray(im))
if __name__=='__main__':unittest.main()
