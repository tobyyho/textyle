"""Regression checks for warm neutral cloth and graphic-preserving atlas sampling."""
import io
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image,ImageDraw
from tailor_ai.garment3d.material_reconstruction import reconstruct
from tailor_ai.garment3d.reconstructed_atlas import make_atlas
from tailor_ai.garment3d import garment_photo_projection as p

def png(image):
    b=io.BytesIO();image.save(b,'PNG');return b.getvalue()

class PrintQualityTests(unittest.TestCase):
    def views(self, graphic=True):
        h,w=480,320;yy,xx=np.indices((h,w))
        mask=(xx>35)&(xx<285)&(yy>20)&(yy<460)
        rgb=np.clip(np.array([83,70,65])*(.80+.15*xx[:,:,None]/w),0,255).astype('uint8')
        image=Image.fromarray(np.dstack((rgb,(mask*255).astype('uint8'))))
        if graphic:
            d=ImageDraw.Draw(image)
            for x in range(75,240,28):
                d.rectangle((x,120,x+14,300),fill=(175,165,150,255))
            d.rectangle((90,320,230,350),fill=(170,160,148,255))
            d.rectangle((125,210,190,224),fill=(200,50,35,255))
        return image,mask
    def test_gray_print_on_warm_dark_cloth_keeps_brightness_and_shape(self):
        image,mask=self.views();plain,_=self.views(False)
        crops={v:{'x':.11,'y':.04,'w':.78,'h':.92} for v in ('front','back')}
        out,meta,_=reconstruct({'front':(plain,mask),'back':(image,mask)},crops)
        before=np.asarray(image)[125:290,78:87,:3].mean()
        after=np.asarray(out['back'])[125:290,78:87,:3].mean()
        self.assertGreater(after,before*.85)
        self.assertLess(after,before*1.25)
        self.assertGreater(meta['views']['back']['design_pixels'],10000)
        clean=np.asarray(out['front'])[:,:,:3][mask]
        self.assertLess(float(clean.mean(1).std()),2)
    def test_atlas_preserves_reconstructed_graphic_and_separate_view_colours(self):
        mask=np.zeros((300,240),bool);mask[20:280,40:200]=True
        front=Image.new('RGBA',(240,300),(90,70,60,255))
        back=Image.new('RGBA',front.size,(40,65,90,255))
        ImageDraw.Draw(back).rectangle((95,110,145,180),fill=(210,200,190,255))
        appearance={'views':{'front':{'base_rgb':[90,70,60]},'back':{'base_rgb':[40,65,90]}}}
        binary=png(Image.fromarray((mask*255).astype('uint8')))
        with patch.object(p,'balance_view',side_effect=AssertionError('second correction')):
            atlas,_,_=make_atlas(png(front),png(back),binary,binary,{'category':'short_sleeve_top'},{},{'reconstruction':appearance})
        pixels=np.asarray(atlas)
        np.testing.assert_array_equal(pixels[500,1536],(210,200,190))
        np.testing.assert_array_equal(pixels[500,512],(90,70,60))
        np.testing.assert_array_equal(pixels[1800,1500],(40,65,90))
class ExposureRegressionTests(unittest.TestCase):
    def photo(self, base, large):
        image=Image.new('RGBA',(320,480),(*base,255))
        mask=np.zeros((480,320),bool);mask[20:460,35:285]=True
        d=ImageDraw.Draw(image)
        if large:
            for x in range(65,245,28):
                d.rectangle((x,130,x+15,290),fill=(185,175,165,255))
            d.rectangle((85,320,235,365),fill=(180,170,160,255))
        else:d.rectangle((210,150,235,175),fill=(185,175,165,255))
        return image,mask
    def test_light_artwork_on_charcoal_above_old_brightness_boundary_is_retained(self):
        image,mask=self.photo((97,82,79),True)
        crops={v:{'x':.11,'y':.04,'w':.78,'h':.92} for v in ('front','back')}
        out,_,_=reconstruct({'front':(image,mask),'back':(image.copy(),mask.copy())},crops)
        center=np.asarray(out['back'])[325:360,95:225,:3].mean(2)
        self.assertGreater(float((center>135).mean()),.85)
    def test_moderate_neutral_exposure_difference_has_consistent_fabric(self):
        views={'front':self.photo((76,62,57),False),'back':self.photo((97,82,79),True)}
        crops={v:{'x':.11,'y':.04,'w':.78,'h':.92} for v in views}
        out,meta,_=reconstruct(views,crops)
        self.assertEqual(meta['views']['front']['base_rgb'],meta['views']['back']['base_rgb'])
    def test_front_collar_lining_is_flat_but_back_upper_print_is_kept(self):
        image,mask=self.photo((76,62,57),False)
        ImageDraw.Draw(image).rectangle((140,70,180,87),fill=(200,190,180,255))
        crops={v:{'x':.11,'y':.04,'w':.78,'h':.92} for v in ('front','back')}
        out,meta,_=reconstruct({'front':(image,mask),'back':(image.copy(),mask.copy())},crops)
        front=np.asarray(out['front'])[73:84,145:175,:3].mean()
        back=np.asarray(out['back'])[73:84,145:175,:3].mean()
        self.assertLess(front,100)
        self.assertGreater(back,135)
class SleeveShadowRegressionTests(unittest.TestCase):
    def test_dark_sleeve_folds_do_not_erase_light_chest_logo(self):
        from tailor_ai.garment3d.material_reconstruction import _neutral_print
        image=Image.new('RGB',(320,480),(78,66,62));d=ImageDraw.Draw(image)
        d.rectangle((30,120,45,330),fill=(10,9,8))
        d.rectangle((275,120,290,330),fill=(10,9,8))
        d.rectangle((190,150,215,185),fill=(190,180,165))
        mask=np.zeros((480,320),bool);mask[20:460,20:300]=True
        crop={'x':.25,'y':.04,'w':.5,'h':.92}
        rgb=np.asarray(image).astype(float);base=np.array([86,72,68])
        matte,pigment=_neutral_print(rgb,mask,crop,base,'front')
        rendered=base*(1-matte[:,:,None])+pigment*matte[:,:,None]
        self.assertGreater(float(rendered[155:180,195:210].mean()),145)
        self.assertLess(float(matte[130:320,35:60].mean()),.05)
if __name__=='__main__':unittest.main()
