import hashlib,unittest
import numpy as np
from PIL import Image
from tailor_ai.garment3d import garment_photo_projection as p
from tailor_ai.garment3d.closer_fit import fit_glb

class CloserFitTests(unittest.TestCase):
    def test_every_supported_shape_keeps_uvs_hem_heights_and_finite_geometry(self):
        versions=[('male_tshirt','male_average','short_sleeve_top',None)]
        versions += [(s['version'],s['profile'],s['category'],'tee' if s.get('derived_plain_tee') else 'sweater' if s['category']=='long_sleeve_top' else None) for s in p.REGISTRY+getattr(p,'PLAIN_TEES',[])]
        for version,profile,category,style in versions:
            with self.subTest(version=version):
                if version=='male_tshirt':
                    # Original fitted male tee, using its actual asset geometry.
                    data=(p.ROOT/'photo_templates/tshirtm.glb').read_bytes()
                else:
                    spec,doc,parts,mapping=p.calibration(version)
                    data=p.texture_template(Image.new('RGB',(2048,2048),(140,90,70)),spec,doc,parts,mapping,style)
                output,details=fit_glb(data,profile,category,style)
                a,ab=p.decode_glb(data);b,bb=p.decode_glb(output)
                self.assertEqual(a['nodes'],b['nodes']);self.assertEqual(a.get('materials'),b.get('materials'))
                self.assertGreater(details['vertices_adjusted'],0)
                self.assertLessEqual(details['max_displacement_metres'],.025001)
                ma=p.mesh_transforms(a);mb=p.mesh_transforms(b)
                for mi,(mesh,mesh2) in enumerate(zip(a['meshes'],b['meshes'])):
                    for old,new in zip(mesh['primitives'],mesh2['primitives']):
                        va=p.accessor(a,ab,old['attributes']['POSITION']);vb=p.accessor(b,bb,new['attributes']['POSITION'])
                        wa=va@ma[mi][:3,:3].T+ma[mi][:3,3];wb=vb@mb[mi][:3,:3].T+mb[mi][:3,3]
                        self.assertTrue(np.isfinite(vb).all());np.testing.assert_allclose(wa[:,1],wb[:,1],atol=1e-6,rtol=0)
                        protected=wa[:,1]<= (1.12 if category!='trousers' else .15)
                        np.testing.assert_allclose(wa[protected],wb[protected],atol=1e-6,rtol=0)
                        for key,index in old['attributes'].items():
                            if key!='POSITION':np.testing.assert_array_equal(p.accessor(a,ab,index),p.accessor(b,bb,new['attributes'][key]))
                        idx=p.accessor(a,ab,old['indices']).ravel().reshape(-1,3)
                        before=np.cross(wa[idx[:,1]]-wa[idx[:,0]],wa[idx[:,2]]-wa[idx[:,0]])
                        after=np.cross(wb[idx[:,1]]-wb[idx[:,0]],wb[idx[:,2]]-wb[idx[:,0]])
                        significant=np.linalg.norm(before,axis=1)>1e-10
                        self.assertTrue((np.sum(before[significant]*after[significant],axis=1)>0).all())
                if a.get('images'):
                    def image_bytes(doc,blob):
                        view=doc['bufferViews'][doc['images'][0]['bufferView']];return blob[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
                    self.assertEqual(hashlib.sha256(image_bytes(a,ab)).hexdigest(),hashlib.sha256(image_bytes(b,bb)).hexdigest())
    def test_rejects_unknown_avatar_or_category(self):
        data=(p.ROOT/'photo_templates/tshirtm.glb').read_bytes()
        with self.assertRaises(ValueError):fit_glb(data,'unknown','short_sleeve_top')
        with self.assertRaises(ValueError):fit_glb(data,'male_average','dress')
if __name__=='__main__':unittest.main()
