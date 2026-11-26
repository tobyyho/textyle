import unittest
import numpy as np
from scipy.spatial import cKDTree
from tailor_ai.garment3d import finished_projection as f
from tailor_ai.garment3d import garment_photo_projection as p
from tailor_ai.garment3d.finished_surface import stable_parts,seam_triangles,add_seam_covers
from test_finished_projection import photos

class FinishedSurfaceTests(unittest.TestCase):
 def test_real_long_sleeve_slits_are_covered_without_moving_original_geometry(self):
  for profile in ['male_average','female_average']:
   chosen,spec,doc,parts,mapping=f.calibration(profile,'long_tee');triangles,holes=seam_triangles(parts,mapping)
   self.assertGreaterEqual(len(holes),4);points=np.asarray(triangles).reshape(-1,3);all_points=np.concatenate([part['world'] for part in parts]);self.assertLess(float(cKDTree(all_points).query(points)[0].max()),1e-6)
   low,high=mapping['body_min'][1],mapping['body_max'][1]
   for hole in holes:
    self.assertGreaterEqual(hole['bounds_min'][1],low+(high-low)*.36)
    self.assertLess(hole['bounds_max'][1],high-.0249)
    self.assertLessEqual(hole['bounds_max'][0]-hole['bounds_min'][0],.045001)
    self.assertLessEqual(hole['bounds_max'][2]-hole['bounds_min'][2],.045001)
 def test_view_partition_is_independent_of_flipped_vertex_normals(self):
  _,_,_,parts,mapping=f.calibration('male_average','long_tee');changed=[dict(q,normals=-q['normals']) for q in parts]
  a=stable_parts(parts,mapping);b=stable_parts(changed,mapping)
  for original,left,right in zip(parts,a,b):
   np.testing.assert_array_equal(left['normals'][:,2],right['normals'][:,2])
   np.testing.assert_array_equal(original['normal'],left['normal'])
   np.testing.assert_array_equal(original['pos'],left['pos'])
if __name__=='__main__':unittest.main()
