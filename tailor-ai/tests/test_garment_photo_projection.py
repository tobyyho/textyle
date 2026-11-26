"""Generic synthetic inputs + exact supplied-template geometry regressions."""
from pathlib import Path
import io,json,unittest
import numpy as np
from PIL import Image,ImageDraw
from tailor_ai.garment3d import garment_photo_projection as p


def png(image):
    stream=io.BytesIO();image.save(stream,'PNG');return stream.getvalue()

def top(back=False,short=False,folded=False):
    im=Image.new('RGBA',(500,700),(0,255,0,0));mask=Image.new('L',im.size,0)
    draw=ImageDraw.Draw(im);md=ImageDraw.Draw(mask)
    body=[(150,90),(350,90),(355,610),(145,610)]
    draw.polygon(body,fill=(70,180,80,255) if back else (170,170,170,255));md.polygon(body,fill=255)
    left=[(150,90),(95,115),(45,520),(105,540),(154,190)]
    if short:left=[(150,90),(90,110),(60,230),(120,245),(154,160)]
    if not folded:
        for side,poly,col in [('left',left,(230,140,20,255) if back else (220,30,40,255)),
            ('right',[(500-x,y) for x,y in left],(140,40,180,255) if back else (30,60,220,255))]:
            draw.polygon(poly,fill=col);md.polygon(poly,fill=255)
        if not back:draw.line((65,340,110,348),fill=(255,240,190,255),width=12)
    draw.text((240,260),'B' if back else 'F',fill=(0,0,0,255))
    return png(im),png(mask)

def pants(back=False,joined=False):
    im=Image.new('RGBA',(500,760),(0,255,0,0));m=Image.new('L',im.size,0);d=ImageDraw.Draw(im);md=ImageDraw.Draw(m)
    shape=[(125,50),(375,50),(365,240),(335,700),(280,700),(250,245),(220,700),(165,700),(135,240)]
    d.polygon(shape,fill=(70,180,80,255) if back else (170,170,170,255));md.polygon(shape,fill=255)
    for poly,col in [([(135,230),(250,230),(220,700),(165,700)],(230,140,20,255) if back else (220,30,40,255)),
        ([(250,230),(365,230),(335,700),(280,700)],(140,40,180,255) if back else (30,60,220,255))]:
        d.polygon(poly,fill=col)
    if joined:
        md.rectangle((210,200,290,700),fill=255);d.rectangle((210,200,290,700),fill=(170,170,170,255))
    return png(im),png(m)


class GarmentPhotoProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated={}
        for spec in p.REGISTRY:
            f,fm=pants() if spec['category']=='trousers' else top(short=spec['category']=='short_sleeve_top')
            b,bm=pants(True) if spec['category']=='trousers' else top(True,short=spec['category']=='short_sleeve_top')
            cls.generated[spec['version']]=p.generate(spec['profile'],spec['category'],f,b,fm,bm,b'original-front',b'original-back')

    def test_template_topology_normals_transforms_and_bounded_sweater_clearance(self):
        for spec in p.REGISTRY:
            with self.subTest(version=spec['version']):
                _,old,parts,_=p.calibration(spec['version']);new,blob=p.decode_glb(self.generated[spec['version']][0])
                self.assertEqual(new['nodes'],old['nodes']);self.assertEqual(new['scenes'],old['scenes'])
                for part in parts:
                    primitive=new['meshes'][part['mesh']]['primitives'][part['primitive']]
                    index=p.accessor(new,blob,primitive['indices']).ravel()
                    emitted=p.accessor(new,blob,primitive['attributes']['POSITION'])[index]
                    original=part['pos'][part['index']]
                    if spec['version']=='male_long_sleeve_photo_v1':
                        matrix=p.mesh_transforms(old)[part['mesh']]
                        displacement=(emitted-original)@matrix[:3,:3].T
                        self.assertLessEqual(float(np.linalg.norm(displacement,axis=1).max()),.00401)
                    else:
                        np.testing.assert_array_equal(emitted,original)
                    np.testing.assert_array_equal(p.accessor(new,blob,primitive['attributes']['NORMAL'])[index],part['normal'][part['index']])

    def test_every_profile_category_has_the_matching_model_and_unreviewed_provenance(self):
        for spec in p.REGISTRY:
            glb,sidecar=self.generated[spec['version']]
            self.assertEqual(sidecar['templateSha256'],spec['sha256']);self.assertEqual(sidecar['bodyProfile'],spec['profile'])
            self.assertEqual(sidecar['sourceCategory'],spec['category']);self.assertEqual(sidecar['glbSha256'],p.digest(glb))
            self.assertEqual(sidecar['frontSha256'],p.digest(b'original-front'));self.assertFalse(sidecar['userReviewed'])
            self.assertLess(len(glb),24*1024*1024)
            json.dumps(sidecar,allow_nan=False)

    def test_sleeves_route_by_physical_side_and_view_without_body_print_repetition(self):
        f,fm=top();b,bm=top(True);spec=p.find_template('female_average','long_sleeve_top');_,_,_,mapping=p.calibration(spec['version'])
        atlas,_,details=p.make_atlas(f,b,fm,bm,spec,mapping);a=np.asarray(atlas)
        self.assertEqual(details['front']['left']['mode'],'projected_estimate')
        self.assertGreater(float((a[1200:1900,80:430,0]>a[1200:1900,80:430,2]+50).mean()),.6)
        center,axis,across,a0,aw,b0,bw=mapping['arms'][1]
        point2=center+axis*(a0+aw*.5)+across*(b0+bw*.5)
        points=np.array([[point2[0],point2[1],0],[point2[0],point2[1],0]])
        uv=p.projected_uv(points,np.array([1,1]),np.array([True,False]),spec,mapping)
        self.assertLess(uv[0,0],.25);self.assertGreater(uv[1,0],.75)
        self.assertTrue((uv[:,1]>.5).all())

    def test_pants_use_separate_camera_left_and_right_leg_pixels(self):
        f,fm=pants();image,binary=p._load_cutout(f,fm)
        panel,crop,details=p.pants_panel(image,binary,.31);a=np.asarray(panel)
        self.assertGreater(a[1300,200,0],a[1300,200,2]+50)
        self.assertGreater(a[1300,800,2],a[1300,800,0]+50)
        self.assertEqual(len(details['legs']),2)
        self.assertLess(crop['x']+crop['w'],1.0001)

    def test_ambiguous_joined_pants_legs_are_rejected(self):
        f,fm=pants(joined=True);image,binary=p._load_cutout(f,fm)
        with self.assertRaises(p.ProjectionError):p.pants_panel(image,binary,.31)

    def test_folded_or_absent_sleeves_are_explicit_estimates(self):
        f,fm=top(folded=True);image,binary=p._load_cutout(f,fm);crop=p.torso_crop(binary)
        for side in ('left','right'):
            _,info=p.sleeve_tile(image,binary,crop,side,True);self.assertEqual(info['mode'],'estimated_colour')

    def test_models_embed_only_the_new_atlas_and_have_finite_partitioned_uvs(self):
        for spec in p.REGISTRY:
            doc,binary=p.decode_glb(self.generated[spec['version']][0])
            self.assertEqual(len(doc['images']),1);self.assertEqual(len(doc['materials']),1)
            self.assertTrue(all('uri' not in x for x in doc['images']+doc['buffers']))
            for mesh in doc['meshes']:
                for part in mesh['primitives']:
                    uv=p.accessor(doc,binary,part['attributes']['TEXCOORD_0']);self.assertTrue(np.isfinite(uv).all())
                    self.assertGreaterEqual(uv.min(),0);self.assertLessEqual(uv.max(),1)

    def test_unsupported_avatar_or_category_fails_closed(self):
        for profile,category in [('male_average','dress'),('child','trousers'),('female_average','outerwear')]:
            with self.assertRaises(p.ProjectionError):p.find_template(profile,category)

    def test_generation_is_deterministic(self):
        f,fm=pants();b,bm=pants(True)
        again=p.generate('male_average','trousers',f,b,fm,bm,b'original-front',b'original-back')
        self.assertEqual(again,self.generated['male_trousers_photo_v1'])

    def test_transparent_room_pixels_never_become_visible_fabric(self):
        f,fm=top();b,bm=top(True);spec=p.find_template('male_average','long_sleeve_top');_,_,_,mapping=p.calibration(spec['version'])
        atlas,_,_=p.make_atlas(f,b,fm,bm,spec,mapping);a=np.asarray(atlas)
        self.assertFalse(((a[:,:,0]<10)&(a[:,:,1]>240)&(a[:,:,2]<10)).any())

if __name__=='__main__':unittest.main()
