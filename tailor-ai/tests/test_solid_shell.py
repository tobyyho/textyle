import unittest
import numpy as np
from tailor_ai.garment3d import garment_photo_projection as p
class SolidShellTests(unittest.TestCase):
    def test_displacement_is_bounded_and_coincident_mesh_vertices_stay_welded(self):
        spec,doc,parts,_=p.calibration('male_long_sleeve_photo_v1');new=p.shell_positions(spec,doc,parts);matrices=p.mesh_transforms(doc)
        old_world=[];new_world=[]
        for part,pos in zip(parts,new):
            m=matrices[part['mesh']];old_world.append(part['world']);new_world.append(pos@m[:3,:3].T+m[:3,3])
        old=np.concatenate(old_world);updated=np.concatenate(new_world);delta=updated-old
        distance=np.linalg.norm(delta,axis=1)
        self.assertLessEqual(float(distance.max()),.00401);self.assertGreater(float(np.median(distance)),.0039)
        keys,inverse=np.unique(np.round(old/1e-6).astype(np.int64),axis=0,return_inverse=True)
        low=np.full((len(keys),3),np.inf);high=-low.copy();np.minimum.at(low,inverse,delta);np.maximum.at(high,inverse,delta)
        self.assertLess(float((high-low).max()),2e-6)
    def test_other_templates_keep_their_original_shape(self):
        for spec in p.REGISTRY:
            if spec['version']=='male_long_sleeve_photo_v1':continue
            spec,doc,parts,_=p.calibration(spec['version'])
            for part,pos in zip(parts,p.shell_positions(spec,doc,parts)):
                np.testing.assert_array_equal(pos,part['pos'])
if __name__=='__main__':unittest.main()
