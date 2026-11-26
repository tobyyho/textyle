import unittest
import numpy as np
from PIL import Image
from tailor_ai.garment3d.fabric_albedo import shared_base,balance_view,projection_samples,soften_upper_seams
from tailor_ai.garment3d.garment_photo_projection import _body_tile
class FabricAlbedoTests(unittest.TestCase):
    def fixture(self):
        a=np.zeros((360,300,4),np.uint8);shade=np.linspace(.65,1.20,300)
        a[:,:,:3]=np.round(np.array([150,95,70])[None,None,:]*shade[None,:,None]);a[:,:,3]=255
        a[160:190,100:130,:3]=[8,8,8];a[210:240,150:190,:3]=[245,245,245]
        a[270:300,220:260,:3]=[25,80,190]
        return Image.fromarray(a),np.ones((360,300),bool)
    def test_shared_tone_softens_shadows_and_keeps_graphics_and_other_colours(self):
        im,m=self.fixture();before=np.asarray(im).copy();base,info=shared_base({'front':(im,m),'back':(im,m)})
        self.assertIsNotNone(base);self.assertEqual(info['mode'],'shared_base_preserve_details')
        adjusted=np.asarray(balance_view(im,m,base))
        self.assertLess(float(adjusted[100,:,0].std()),float(before[100,:,0].std()))
        for y,x in [(175,115),(225,170),(285,240)]:np.testing.assert_array_equal(adjusted[y,x],before[y,x])
        np.testing.assert_array_equal(np.asarray(im),before)
    def test_different_front_back_colours_are_not_forced_to_match(self):
        m=np.ones((300,300),bool)
        a=Image.new('RGBA',(300,300),(200,30,40,255));b=Image.new('RGBA',(300,300),(30,50,210,255))
        base,info=shared_base({'front':(a,m),'back':(b,m)});self.assertIsNone(base)
    def test_neutral_grey_designs_keep_their_original_pixels(self):
        a=Image.new('RGBA',(300,300),(150,150,150,255));m=np.ones((300,300),bool)
        out=balance_view(a,m,np.array([155.,155.,155.]));np.testing.assert_array_equal(np.asarray(out),np.asarray(a))
    def test_projection_excludes_inner_label_but_keeps_chest_print_and_large_panel(self):
        a=np.full((400,400,4),(140,90,70,255),dtype=np.uint8);m=np.ones((400,400),bool)
        a[15:30,150:250,:3]=[235,230,220];a[160:190,160:240,:3]=[245,245,245]
        a[0:230,20:80,:3]=[245,245,245]
        im=Image.fromarray(a);sample,info=projection_samples(im,m,{'x':0,'y':0,'w':1,'h':1},np.array([140,90,70]),'front')
        self.assertFalse(sample[20,200]);self.assertTrue(sample[175,200]);self.assertTrue(sample[100,50]);self.assertTrue(sample[10,50])
        np.testing.assert_array_equal(np.asarray(im),a);self.assertTrue(m.all())
    def test_narrow_upper_edge_fringe_is_not_sampled_as_fabric(self):
        a=np.full((400,400,4),(140,90,70,255),dtype=np.uint8);m=np.ones((400,400),bool)
        a[70:115,390:393,:3]=[220,205,190]
        sample,_=projection_samples(Image.fromarray(a),m,{'x':0,'y':0,'w':1,'h':1},np.array([140,90,70]),'back')
        self.assertFalse(sample[90,391]);self.assertTrue(sample[200,200])
    def test_unobserved_padding_uses_base_instead_of_stretched_neck_pixels(self):
        a=np.full((200,200,4),(140,90,70,255),dtype=np.uint8);m=np.ones((200,200),bool);m[:80,170:]=False
        a[120:150,90:120,:3]=[5,5,5]
        tile=np.asarray(_body_tile(Image.fromarray(a),m,{'x':0,'y':0,'w':1,'h':1},np.array([140,90,70])))
        np.testing.assert_array_equal(tile[100,950],[140,90,70]);self.assertLess(int(tile[680,530,0]),10)
    def test_seam_padding_preserves_bright_and_dark_designs(self):
        a=np.full((200,200,3),(160,105,80),np.uint8);a[10:30,0:30]=[245,245,245];a[40:60,0:30]=[5,5,5]
        out=np.asarray(soften_upper_seams(Image.fromarray(a),np.array([140,90,70])))
        np.testing.assert_array_equal(out[20,10],[245,245,245]);np.testing.assert_array_equal(out[50,10],[5,5,5])
        self.assertLess(int(out[10,199,0]),145)
if __name__=='__main__':unittest.main()
