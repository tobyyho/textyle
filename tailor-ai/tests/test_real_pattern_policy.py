"""Live supplied-photo regression; limited examples, not calibrated accuracy."""
import io,os,unittest
from pathlib import Path
from PIL import Image,ImageOps
from tailor_ai.digitization.plain_background import candidate
from tailor_ai.digitization.normalization import normalize
from tailor_ai.inference.garment_recognition import get_recognizer,whole_garment
from tailor_ai.inference.garment_details import PATTERN,agreed_detail

class RealPatternPolicyTests(unittest.TestCase):
 def test_plain_pants_and_printed_holdouts(self):
  # Match the Mac launcher's default cache, respecting explicit configuration.
  root=Path(os.environ.get('TAILOR_MAC_DATA_ROOT',str(Path.home()/'Library/Application Support/textyle-tailor'))).expanduser()
  os.environ.setdefault('TAILOR_HF_CACHE',str(root/'cache/huggingface/hub'))
  os.environ['HF_HUB_OFFLINE']='1'
  os.environ['TRANSFORMERS_OFFLINE']='1'
  model=get_recognizer();segmenter=None
  base=Path(__file__).parent/'fixtures/pattern_policy'
  for label,names,expected in [
   ('pants',('IMG_4512.jpg','IMG_4513.jpg'),'plain'),
   ('printed_tshirt',('IMG_4508.jpg','IMG_4509.jpg'),'printed'),
   ('printed_front_plain_back',('long_front.png','long_back.png'),None)]:
   with self.subTest(label=label):
    images=[]
    for name in names:
     with Image.open(base/name) as src:image=ImageOps.exif_transpose(src).convert('RGB')
     image.thumbnail((1400,1400));cutout=candidate(image)
     if cutout is None:
      from tailor_ai.providers.segmentation.sam2_tiny import Sam2TinySegmenter
      from tailor_ai.digitization.quality import assess
      if segmenter is None:segmenter=Sam2TinySegmenter(device='cpu')
      cutout=segmenter.segment_solid(image)
      accepted,warnings=assess(cutout.mask,image.width,image.height,cutout.confidence)
      self.assertTrue(accepted and not cutout.warnings,str(warnings)+str(cutout.warnings))
     normalized=normalize(image,cutout.mask)
     images.append(whole_garment(normalized.rgba_png,normalized.mask_png))
    result=agreed_detail(model.scores(images,PATTERN),PATTERN,minimum_margin=.02)
    print('\nLive pattern '+label+': '+str(result),flush=True)
    self.assertEqual(result['value'],expected)
    if label!='pants':self.assertNotEqual(result['value'],'plain','Printed artwork must not qualify for flattening.')
if __name__=='__main__':unittest.main()
