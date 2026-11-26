import unittest
import numpy as np
from PIL import Image
from tailor_ai.garment3d.hem_style import rib_evidence,resolve_style
from tailor_ai.garment3d import garment_photo_projection as p
from test_garment_photo_projection import top
class HemStyleTests(unittest.TestCase):
    def test_plain_fabric_defaults_to_tee_without_claiming_certainty(self):
        image=Image.new('RGBA',(400,600),(140,90,70,255));m=np.ones((600,400),bool)
        e=rib_evidence(image,m,{'x':0,'y':0,'w':1,'h':1});self.assertFalse(e['ribbed'])
        style=resolve_style('auto',{'front':e,'back':e});self.assertEqual(style['resolved'],'tee');self.assertTrue(style['uncertain'])
    def test_consistent_fine_vertical_ribs_in_both_views_keep_band(self):
        a=np.full((600,400,4),(140,90,70,255),dtype=np.uint8)
        signal=(15*np.cos(np.arange(400)*2*np.pi/8)).astype(int)
        for c in range(3):a[480:580,:,c]=np.clip(a[480:580,:,c].astype(int)+signal,0,255)
        e=rib_evidence(Image.fromarray(a),np.ones((600,400),bool),{'x':0,'y':0,'w':1,'h':1})
        self.assertTrue(e['ribbed'],e);self.assertEqual(resolve_style('auto',{'front':e,'back':e})['resolved'],'sweater')
        self.assertEqual(resolve_style('auto',{'front':e,'back':{'ribbed':False}})['resolved'],'tee')
    def test_user_override_and_invalid_style(self):
        self.assertEqual(resolve_style('sweater',{})['source'],'user')
        self.assertEqual(resolve_style('tee',{})['resolved'],'tee')
        with self.assertRaises(ValueError):resolve_style('dress',{})
    def test_band_meshes_are_removed_only_for_tee_on_both_profiles(self):
        f,fm=top();b,bm=top(True)
        for profile,n,removed in [('male_average',10,3),('female_average',9,2)]:
            for style in ['tee','sweater']:
                glb,side=p.generate(profile,'long_sleeve_top',f,b,fm,bm,b'front',b'back',long_sleeve_style=style)
                doc,_=p.decode_glb(glb);self.assertEqual(len(doc['meshes']),n-removed if style=='tee' else n)
                self.assertEqual(side['hemStyle']['resolved'],style)
                self.assertFalse(side['userReviewed']);self.assertEqual(side['geometryAdjustment']['waistband_present'],style=='sweater')
                for node in doc['nodes']:
                    if 'mesh'in node:self.assertLess(node['mesh'],len(doc['meshes']))
    def test_hip_correction_is_finite_bounded_and_does_not_move_cuffs(self):
        spec,doc,parts,_=p.calibration('male_long_sleeve_photo_v1');matrices=p.mesh_transforms(doc)
        for part,position in zip(parts,p.styled_positions(spec,doc,parts,'sweater')):
            self.assertTrue(np.isfinite(position).all())
            movement=np.linalg.norm((position-part['pos'])@matrices[part['mesh']][:3,:3].T,axis=1)
            self.assertLess(float(movement.max()),.175 if part['mesh'] in (6,7) else .085)
            if part['mesh'] in (0,1,4,5):self.assertLessEqual(float(movement.max()),.00401)

    def test_legacy_direct_generation_still_preserves_original_mesh_count(self):
        f,fm=top();b,bm=top(True);glb,side=p.generate('male_average','long_sleeve_top',f,b,fm,bm,b'front',b'back')
        self.assertEqual(len(p.decode_glb(glb)[0]['meshes']),10)
if __name__=='__main__':unittest.main()
