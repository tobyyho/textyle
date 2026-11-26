"""Pipeline regression with an intentionally damaged segmenter boundary stub."""
import io,tempfile,unittest
from pathlib import Path
import numpy as np
from PIL import Image
from tailor_ai.digitization.pipeline import DigitizationPipeline
from tailor_ai.digitization.assets import TemporaryAssetStore
from tailor_ai.digitization.plain_background import candidate
from tailor_ai.providers.segmentation.base import SegmentationResult
import test_plain_background as fixtures

class DamagedSegmenter:
    def __init__(self,im):self.im=im
    def segment(self,image):
        c=candidate(self.im);mask=c.mask.copy();mask[200:300,230:270]=False
        return SegmentationResult(mask,(0,0,500,650),float(mask.mean()),.9,('ambiguous_foreground',),'stub-damaged')
    def segment_prompted(self,image,correction):return self.segment(image)

class ContrastPipelineTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();im=fixtures.PlainBackgroundTests().shirt();self.pipeline=DigitizationPipeline(DamagedSegmenter(im),TemporaryAssetStore(Path(self.tmp.name)))
        b=io.BytesIO();im.save(b,'PNG');self.data=b.getvalue()
    def tearDown(self):self.tmp.cleanup()
    def test_validated_contrast_restores_fabric_and_preserves_unreviewed_state(self):
        result=self.pipeline.process_view(self.data,'front',allow_plain_background=True)
        meta=result['segmentation'];self.assertTrue(meta['candidate_accepted']);self.assertIsNone(meta['confidence'])
        self.assertEqual(meta['confidence_source'],'deterministic_checks');self.assertFalse(meta['user_approved'])
        self.assertIn('visual_review_required',meta['warnings']);self.assertNotIn('ambiguous_foreground',meta['warnings'])
        source=result['preview_assets']['source_mask'];mask=np.asarray(Image.open(self.pipeline.assets.get(source['id'])))
        self.assertTrue(mask[230,250]);self.assertTrue(mask[550,100])
        self.assertIn('source_image_sha256',result['identity'])
    def test_standard_review_keeps_existing_provider_contract(self):
        result=self.pipeline.process_view(self.data,'front')
        self.assertFalse(result['segmentation']['candidate_accepted'])
        self.assertIn('ambiguous_foreground',result['segmentation']['warnings'])
    def test_user_correction_is_not_replaced(self):
        class Correction:
            def to_dict(self):return {'box':[0,0,1,1]}
        result=self.pipeline.process_view(self.data,'front',Correction(),allow_plain_background=True)
        self.assertEqual(result['segmentation']['processor_version'],'stub-damaged')
        self.assertFalse(result['segmentation']['candidate_accepted']);self.assertIsNone(result['segmentation']['contrast_checks'])
if __name__=='__main__':unittest.main()
