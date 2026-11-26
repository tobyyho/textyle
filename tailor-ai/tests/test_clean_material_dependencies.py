"""Check the import and callable contract on the installed projection baseline."""
import inspect
import unittest
import numpy as np
from tailor_ai.garment3d import garment_photo_projection as p
from tailor_ai.garment3d.material_reconstruction import reconstruct
from tailor_ai.garment3d.tee_albedo import prepare_tee
from tailor_ai.garment3d.finished_projection import generate
from tailor_ai.garment3d.finished_surface import stable_parts, add_seam_covers
from tailor_ai.garment3d.closer_fit import body, nearest

class CleanMaterialDependencyTests(unittest.TestCase):
 def test_material_and_finished_modules_import_with_required_entrypoints(self):
  for function in [reconstruct,prepare_tee,generate,stable_parts,add_seam_covers]:self.assertTrue(callable(function))
 def test_installed_projection_module_supports_the_existing_call_contract(self):
  for name in ['digest','decode_glb','accessor','mesh_transforms','calibration','_load_cutout','torso_crop','projected_uv','_arm_axes','_padded_rgb']:
   self.assertTrue(callable(getattr(p,name,None)),name)
  inspect.signature(p.make_atlas).bind(*[None]*7)
  inspect.signature(p.texture_template).bind(*[None]*6)
  inspect.signature(p.projected_uv).bind(*[None]*5)
 def test_verified_static_avatar_clearance_data_is_available(self):
  for profile in ['male','female']:
   triangles,tree=body(profile)
   self.assertEqual(triangles.shape[1:],(3,3));self.assertTrue(np.isfinite(triangles).all())
   points=triangles[:1].mean(1);near,normals,distance=nearest(points,triangles,tree)
   self.assertEqual(near.shape,(1,3));self.assertTrue(np.isfinite(near).all());self.assertTrue(np.isfinite(normals).all());self.assertTrue(np.isfinite(distance).all())
if __name__=='__main__':unittest.main()
