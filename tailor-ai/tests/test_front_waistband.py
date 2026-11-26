import unittest
import numpy as np
from tailor_ai.garment3d import garment_photo_projection as p
from test_garment_photo_projection import top

class FrontWaistbandTests(unittest.TestCase):
    def test_front_band_reaches_rear_hem_and_overlaps_torso(self):
        spec,doc,parts,_=p.calibration('male_long_sleeve_photo_v1')
        matrices=p.mesh_transforms(doc)
        worlds={part['mesh']:pos@matrices[part['mesh']][:3,:3].T+matrices[part['mesh']][:3,3]
                for part,pos in zip(parts,p.styled_positions(spec,doc,parts,'sweater'))}
        front=worlds[6];rear=worlds[3]
        self.assertLess(abs(front[:,1].min()-rear[:,1].min()),.015)
        self.assertGreater(front[:,1].max(),1.035)
        self.assertTrue(np.isfinite(front).all())
        # Unrelated sleeve/cuff positions retain their previous shell treatment.
        shell=p.shell_positions(spec,doc,parts)
        for part,a,b in zip(parts,shell,p.styled_positions(spec,doc,parts,'sweater')):
            if part['mesh'] in (0,1,4,5):np.testing.assert_allclose(a,b,atol=1e-6)
    def test_only_right_front_band_changes_from_previous_fix(self):
        namespace=dict(vars(p))
        exec("def styled_positions(spec,doc,primitives,style):\n    positions=shell_positions(spec,doc,primitives)\n    if style is None or spec['version']!='male_long_sleeve_photo_v1':return positions\n    rows=json.loads((ROOT/'male_hip_envelope.json').read_text())['rows']\n    heights=np.array([r['y'] for r in rows]);centers=np.array([r['center_z'] for r in rows]);radii=np.array([r['radius'] for r in rows])\n    matrices=mesh_transforms(doc);result=[]\n    for part,pos in zip(primitives,positions,strict=True):\n        matrix=matrices[part['mesh']];world=pos@matrix[:3,:3].T+matrix[:3,3]\n        # The calibrated male asset's front waistband and lining were exported\n        # 150 mm above its rear hem. Align both pieces before hip clearance.\n        if style=='sweater' and part['mesh'] in (6,7):\n            world[:,1]-=.150-.060*np.clip((world[:,1]-1.071)/.065,0,1)\n        index=part['index'].reshape(-1,3);body=np.zeros(len(pos),bool)\n        body[index[part['parts']==0].ravel()]=True\n        selected=body&(world[:,1]<1.17)\n        p=world[selected].copy();y=p[:,1];center=np.interp(y,heights,centers)\n        theta=np.arctan2(p[:,2]-center,p[:,0]);angle=(theta+np.pi)*72/(2*np.pi)\n        lo=np.floor(angle).astype(int)%72;f=angle-np.floor(angle)\n        layer=np.clip(np.searchsorted(heights,y)-1,0,len(heights)-2);mix=np.clip((y-heights[layer])/(heights[layer+1]-heights[layer]),0,1)\n        radius0=radii[layer,lo]*(1-f)+radii[layer,(lo+1)%72]*f\n        radius1=radii[layer+1,lo]*(1-f)+radii[layer+1,(lo+1)%72]*f\n        target=radius0*(1-mix)+radius1*mix+.006\n        radial=np.hypot(p[:,0],p[:,2]-center)\n        fade=np.clip((1.17-y)/.035,0,1);extra=np.maximum(0,target-radial)*fade\n        p[:,0]+=np.cos(theta)*extra;p[:,2]+=np.sin(theta)*extra\n        world[selected]=p\n        result.append(((world-matrix[:3,3])@np.linalg.inv(matrix[:3,:3]).T).astype('<f4'))\n    return result\n\n",namespace)
        spec,doc,parts,_=p.calibration('male_long_sleeve_photo_v1')
        matrices=p.mesh_transforms(doc)
        previous=namespace['styled_positions'](spec,doc,parts,'sweater')
        updated=p.styled_positions(spec,doc,parts,'sweater')
        for part,old,new in zip(parts,previous,updated):
            if part['mesh']!=6:np.testing.assert_allclose(new,old,atol=1e-7,rtol=0)
            else:
                mat=matrices[6]
                before=old@mat[:3,:3].T+mat[:3,3];after=new@mat[:3,:3].T+mat[:3,3]
                np.testing.assert_allclose(after[before[:,0]<=.070],before[before[:,0]<=.070],atol=1e-7,rtol=0)
                np.testing.assert_allclose(after[:,1:],before[:,1:],atol=1e-7,rtol=0)
                self.assertGreater(float(after[:,0].max()),.20)
                self.assertGreater(float((after[:,0]-before[:,0]).max()),.02)

    def test_sweater_exports_corrected_band_and_opaque_material(self):
        f,fm=top();b,bm=top(True)
        glb,meta=p.generate('male_average','long_sleeve_top',f,b,fm,bm,b'f',b'b',long_sleeve_style='sweater')
        doc,binary=p.decode_glb(glb)
        self.assertEqual(len(doc['meshes']),10)
        self.assertEqual(meta['waistbandAlignment']['version'],'male_right_hem_fill_v3')
        self.assertEqual(doc['materials'][0].get('alphaMode','OPAQUE'),'OPAQUE')
    def test_tee_does_not_receive_band_alignment(self):
        f,fm=top();b,bm=top(True)
        glb,meta=p.generate('male_average','long_sleeve_top',f,b,fm,bm,b'f',b'b',long_sleeve_style='tee')
        self.assertNotIn('waistbandAlignment',meta)
        self.assertFalse(meta['geometryAdjustment']['waistband_present'])
if __name__=='__main__':unittest.main()
