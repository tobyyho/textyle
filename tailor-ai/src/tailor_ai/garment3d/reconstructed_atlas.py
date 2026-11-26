"""Atlas sampling for reconstructed materials, without a second colour correction."""
import numpy as np
from PIL import Image
from tailor_ai.garment3d import garment_photo_projection as p
from tailor_ai.garment3d.capri_mapping import pants_panel


def make_atlas(front_png,back_png,front_mask,back_mask,spec,mapping,fabric_details):
    atlas=Image.new('RGB',(2048,2048));crops={};details={}
    reconstruction=fabric_details['reconstruction']
    fabric_details.update(tone={'mode':'reconstructed_material_passthrough'},
        projection_samples={},unobserved_padding='per_view_reconstructed_fabric')
    for vi,(view,png,mask) in enumerate([('front',front_png,front_mask),('back',back_png,back_mask)]):
        image,binary=p._load_cutout(png,mask)
        base=np.asarray(reconstruction['views'][view]['base_rgb'],dtype=float)
        if spec['category']=='trousers':
            panel,crop,info=pants_panel(image,binary,mapping['crotch_ratio'])
            atlas.paste(panel,(vi*1024,0))
        else:
            crop=p.torso_crop(binary)
            # Material reconstruction already removes lining, shadows and fringe.
            # A second dominant-colour estimate can mistake a large print for cloth.
            atlas.paste(p._body_tile(image,binary,crop,base),(vi*1024,0))
            info={}
            for si,side in enumerate(('left','right')):
                tile,observation=p.sleeve_tile(image,binary,crop,side,spec['category']=='long_sleeve_top')
                if observation['mode']=='estimated_colour':
                    tile=Image.new('RGB',tile.size,tuple(np.round(base).astype(int)))
                    observation['colour_source']='per_view_reconstructed_base'
                atlas.paste(tile,(vi*1024+si*512,1024));info[side]=observation
        crops[view]=crop;details[view]=info
        fabric_details['projection_samples'][view]={'mode':'reconstructed_material_passthrough'}
    return atlas,crops,details
