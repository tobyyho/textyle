"""Exercise actual SAM candidate selection without loading or running weights."""
import ast,importlib.util,types,unittest
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]/'src/tailor_ai'

def load_pure_module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

# These dependencies are pure NumPy/SciPy modules. Load their actual files
# without executing package __init__ code that imports the ML runtime.
quality=load_pure_module('solid_test_quality',ROOT/'digitization/quality.py')
interior=load_pure_module('solid_test_interior',ROOT/'digitization/solid_mask.py')
source=ROOT/'providers/segmentation/sam2_tiny.py'
tree=ast.parse(source.read_text(),filename=str(source))
names={'_iou','_select','_select_solid'}
functions=[node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name in names]
if {node.name for node in functions} != names:
    raise RuntimeError('SAM candidate selection helpers were not found')
namespace={'np':np,'assess':quality.assess,'preserve_interior':interior.preserve_interior}
# Execute the production selection helpers verbatim, with no model construction,
# no replacement of torch/transformers, and no mutation of sys.modules.
exec(compile(ast.Module(body=functions,type_ignores=[]),str(source),'exec'),namespace)
provider=types.SimpleNamespace(**{name:namespace[name] for name in names})

class SolidProviderTests(unittest.TestCase):
    def masks(self):
        mask=np.zeros((2,3,320,320),bool);mask[:,:,40:280,50:270]=True;mask[:,:,100:220,120:200]=False
        return mask
    def test_holes_filled_before_consensus_without_lowering_confidence(self):
        mask,confidence,warnings=provider._select_solid(self.masks(),np.full((2,3),.93))
        self.assertTrue(mask[100:220,120:200].all());self.assertEqual(confidence,.93);self.assertFalse(warnings)
    def test_low_confidence_and_prompt_disagreement_remain_blocked(self):
        _,_,warnings=provider._select_solid(self.masks(),np.full((2,3),.4));self.assertIn('ambiguous_foreground',warnings)
        masks=np.zeros((2,3,320,320),bool);masks[0,:,50:240,20:130]=True;masks[1,:,50:240,190:300]=True
        self.assertIn('ambiguous_foreground',provider._select_solid(masks,np.full((2,3),.95))[2])
if __name__=='__main__':unittest.main()
