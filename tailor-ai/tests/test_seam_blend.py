import importlib.util
from pathlib import Path
import unittest
import numpy as np
from PIL import Image
spec=importlib.util.spec_from_file_location('seam_test',Path(__file__).resolve().parents[1]/'src/tailor_ai/garment3d/photo_projection.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
class SeamBlendTests(unittest.TestCase):
    def test_only_narrow_sleeve_gutters_change(self):
        atlas=Image.new('RGB',(2048,2048),(220,30,30))
        atlas.paste((20,50,220),(0,1536,2048,2048))
        before=np.array(atlas);after=np.array(p.blend_sleeve_boundaries(atlas))
        np.testing.assert_array_equal(before[:1536],after[:1536])
        changed=np.any(before[1536:]!=after[1536:],axis=2)
        self.assertGreater(changed.sum(),100)
        self.assertLess(changed.mean(),.2)
        self.assertGreater(after[1536:,:,0].max(),200)
        # Original source buffer must remain unmodified.
        np.testing.assert_array_equal(before,atlas)
if __name__=='__main__':unittest.main()
