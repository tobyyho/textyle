"""Actual processed-photo regression plus independent collar/abstention cases."""
import importlib.util
import io
from pathlib import Path
import unittest
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('collar_test',ROOT/'src/tailor_ai/garment3d/photo_projection.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)


def png(im):
    stream=io.BytesIO();im.save(stream,'PNG');return stream.getvalue()


def scene(shade=160, shift=0, radius=65, depth=65):
    im=Image.new('RGBA',(420,620),(0,255,0,0))
    mask=Image.new('L',im.size,0)
    ImageDraw.Draw(mask).rectangle((70,55,350,590),fill=255)
    d=ImageDraw.Draw(im);d.rectangle((70,55,350,590),fill=(shade,shade,shade,255))
    center=210+shift; edge_top=55; bottom=edge_top+depth
    xs=np.linspace(center-radius,center+radius,240)
    ys=edge_top+depth*np.sqrt(np.maximum(0,1-((xs-center)/radius)**2))
    poly=[(center-radius,55),(center+radius,55)]+list(zip(xs[::-1],ys[::-1]))
    d.polygon(poly,fill=(shade-25,shade-25,shade-25,255))
    d.line(list(zip(xs,ys)),fill=(shade-50,)*3+(255,),width=3)
    # Missing central tag with bright remnants around its sides.
    d.rectangle((center-12,bottom-28,center+12,bottom-3),fill=(255,255,255,255))
    ImageDraw.Draw(mask).rectangle((center-8,bottom-25,center+8,bottom-3),fill=0)
    im.putalpha(mask)
    d=ImageDraw.Draw(im);d.rectangle((170,200,250,250),fill=(20,30,50,255))
    binary=np.array(mask)>127
    return im,binary


class FrontCollarTests(unittest.TestCase):
    def test_real_processed_photo_removes_label_fragments_and_preserves_artwork(self):
        fixture=ROOT/'tests/fixtures'
        im,b=p._load_cutout((fixture/'front-collar-rgba.png').read_bytes(),(fixture/'front-collar-mask.png').read_bytes())
        original=np.array(im)
        out,info=p.clean_front_neckline(im,b,p.automatic_torso_crop(b))
        a=np.array(out)
        self.assertEqual(info['mode'],'estimated_collar_continuation')
        # Fixture-only region where excluded label and white remnants occurred.
        self.assertEqual(int(a[150:182,480:531,3].min()),255)
        self.assertLess(float(a[150:182,480:531,:3].std()),3)
        np.testing.assert_array_equal(a[225:],original[225:])
        np.testing.assert_array_equal(a[:, :360],original[:, :360])
        np.testing.assert_array_equal(a[:, 650:],original[:, 650:])
        np.testing.assert_array_equal(a[210:222,440:570],original[210:222,440:570])

    def test_independent_colours_collar_sizes_and_offsets(self):
        for shade,shift,radius,depth in [(80,-8,62,64),(170,5,72,70),(230,0,65,66)]:
            with self.subTest(shade=shade):
                im,b=scene(shade,shift,radius,depth)
                out,info=p.clean_front_neckline(im,b,p.automatic_torso_crop(b))
                self.assertEqual(info['mode'],'estimated_collar_continuation')
                np.testing.assert_array_equal(np.array(out)[190:],np.array(im)[190:])
                center=210+shift;bottom=55+depth
                self.assertLess(float(np.array(out)[bottom-23:bottom-6,center-9:center+10,:3].std()),5)

    def test_no_mask_anchor_leaves_photographed_logo_untouched(self):
        im,b=scene();b[:]=False;b[55:591,70:351]=True
        im.putalpha(Image.fromarray(b.astype(np.uint8)*255))
        out,info=p.clean_front_neckline(im,b,p.automatic_torso_crop(b))
        self.assertEqual(info['mode'],'unchanged')
        np.testing.assert_array_equal(out,im)

    def test_gap_without_supported_collar_does_not_erase_fabric(self):
        im,b=scene();im=Image.new('RGBA',im.size,(150,150,150,255))
        im.putalpha(Image.fromarray(b.astype(np.uint8)*255))
        out,info=p.clean_front_neckline(im,b,p.automatic_torso_crop(b))
        self.assertEqual(info['mode'],'unchanged')
        np.testing.assert_array_equal(out,im)

    def test_back_panel_is_byte_identical_to_previous_projection(self):
        im,b=scene();data=png(im);m=png(Image.fromarray(b.astype(np.uint8)*255))
        details={};collar={};atlas,_=p.make_atlas(data,data,m,m,details,collar)
        expected,_=p._panel(im,b,p.automatic_torso_crop(b))
        np.testing.assert_array_equal(np.asarray(Image.open(io.BytesIO(atlas)))[:1536,1024:],expected)
        self.assertEqual(collar['mode'],'estimated_collar_continuation')
        self.assertEqual(set(details['back']),{'left','right'})


if __name__=='__main__':unittest.main()
