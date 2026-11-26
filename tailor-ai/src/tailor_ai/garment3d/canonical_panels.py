"""Fixed front/back material panels; proportional photo placement in model units.

Each region has a single similarity transform (rotation, translation, uniform
scale). No row-wise silhouette stretching is performed. Missing observations
are filled with the already reconstructed fabric estimate, never background.
This is a visualization layout, not a recovered sewing pattern or measured fit.
"""
import io
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from tailor_ai.garment3d import garment_photo_projection as p

VERSION = 'canonical_material_panels_v1'


def _box(mask):
    yy, xx = np.nonzero(mask)
    if not len(xx):
        raise p.ProjectionError('A garment panel has no usable photo pixels.')
    return (float(xx.min()), float(yy.min()), float(xx.max()+1), float(yy.max()+1))


def _crop(mask):
    x0, y0, x1, y1 = _box(mask)
    h, w = mask.shape
    return dict(x=x0/w, y=y0/h, w=(x1-x0)/w, h=(y1-y0)/h)


def _frame(mask, rotate=False):
    yy, xx = np.nonzero(mask)
    points = np.column_stack((xx, yy)).astype(float)
    center = points.mean(0)
    down = np.array([0., 1.])
    if rotate and len(points) > 4:
        values, vectors = np.linalg.eigh(np.cov((points-center).T))
        if values[-1] > values[0]*1.15:
            down = vectors[:, -1]
            if down[1] < 0:
                down = -down
    right = np.array([down[1], -down[0]])
    local = np.column_stack(((points-center)@right, (points-center)@down))
    lo, hi = local.min(0)-.5, local.max(0)+.5
    return center, right, down, lo, hi


def _place(image, mask, dimensions, size, base, rotate=False):
    """Sample once from source into a physical rectangle and record the mapping."""
    width, height = map(float, dimensions)
    if min(width, height) <= 0 or not np.isfinite([width, height]).all():
        raise p.ProjectionError('The standard garment panel dimensions are invalid.')
    center, right, down, lo, hi = _frame(mask, rotate)
    extent = hi-lo
    scale = min(width/extent[0], height/extent[1])
    # Pixel centers correspond to the same physical coordinates used by UVs.
    x = ((np.arange(size[0])+.5)/size[0]-.5)*width
    y = ((np.arange(size[1])+.5)/size[1]-.5)*height
    a, b = np.meshgrid(x/scale+(lo[0]+hi[0])/2,
                       y/scale+(lo[1]+hi[1])/2)
    sx = center[0]+right[0]*a+down[0]*b
    sy = center[1]+right[1]*a+down[1]*b
    # Premultiplied sampling prevents wall/hanger colors bleeding at boundaries.
    rgb = np.asarray(image.convert('RGB'), dtype=float)
    alpha = ndi.map_coordinates(mask.astype(float), [sy, sx], order=1, mode='constant', cval=0)
    out = np.empty((*sy.shape, 3))
    for c in range(3):
        observed = ndi.map_coordinates(rgb[:, :, c]*mask, [sy, sx], order=1, mode='constant', cval=0)
        out[:, :, c] = observed + base[c]*(1-alpha)
    matrix = scale*np.stack((right, down))
    report = {'mode': 'similarity', 'source_to_panel_linear': matrix.tolist(),
              'metres_per_source_pixel': float(scale), 'dimensions_metres': [width, height],
              'source_frame_center': center.tolist(), 'source_local_bounds': [lo.tolist(), hi.tolist()],
              'source_pixels': int(mask.sum()), 'observed_fraction': round(float(alpha.mean()), 5),
              'unobserved_fill': 'reconstructed_fabric_estimate', 'row_stretch': False}
    return Image.fromarray(np.clip(np.rint(out), 0, 255).astype('uint8')), report


def prepare_mapping(mapping, parts):
    """Copy calibration, leaving cached calibration and original vertices intact."""
    result = dict(mapping)
    result['canonical_panels_version'] = VERSION
    if 'body_min' not in mapping:
        lo, hi = mapping['min'], mapping['max']
        ratio = float(mapping['crotch_ratio'])
        if ratio < 1:
            split = hi[1] - ratio*(hi[1]-lo[1])
            world = np.concatenate([part['world'] for part in parts])
            middle = (lo[0]+hi[0])/2
            bounds = []
            for left in (True, False):
                selected = (world[:, 1] <= split) & ((world[:, 0] < middle) if left else (world[:, 0] >= middle))
                if not selected.any():
                    raise p.ProjectionError('The model does not have two calibrated leg panels.')
                bounds.append([float(world[selected, 0].min()), float(world[selected, 0].max())])
            result['canonical_leg_bounds'] = bounds
    return result


def _pants_regions(binary):
    """Find waist and two independent visible legs, including shorter capris."""
    geom = ndi.binary_fill_holes(binary)
    x0, y0, x1, y1 = map(int, _box(geom))
    h, w = y1-y0, x1-x0
    stable = max(4, int(h*.025))
    valid = []
    for y in range(y0, y1):
        runs = [(a, b) for a, b in p._runs(geom[y]) if b-a > w*.10]
        valid.append(len(runs) == 2 and runs[1][0]-runs[0][1] > max(2, w*.012))
    check = np.convolve(np.asarray(valid, int), np.ones(stable, int), 'valid')
    begin, end = int(h*.16), int(h*.74)
    candidates = np.flatnonzero(check[begin:end] == stable)
    if not len(candidates):
        raise p.ProjectionError('Separate both pants legs and show the waistband and hems. The photo does not expose two usable legs.')
    split = y0+begin+int(candidates[0])
    lower = geom.copy(); lower[:split] = False
    labels, count = ndi.label(lower)
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    chosen = np.argsort(sizes)[-2:]
    if count < 2 or min(sizes[chosen]) < geom.sum()*.10:
        raise p.ProjectionError('Two complete pants legs are required for automatic mapping.')
    regions = sorted([labels == i for i in chosen], key=lambda r: np.nonzero(r)[1].mean())
    for region in regions:
        if _box(region)[3]-split < h*.24:
            raise p.ProjectionError('A pants leg is folded or cropped. Show both complete legs.')
    waist = binary.copy(); waist[split:] = False
    return [waist] + [r & binary for r in regions], split


def make_atlas(front_png, back_png, front_mask, back_mask, spec, mapping, fabric_details):
    atlas = Image.new('RGB', (2048, 2048))
    crops, details = {}, {}
    bottom = 'body_min' not in mapping
    for vi, (view, png, mask_png) in enumerate((('front', front_png, front_mask), ('back', back_png, back_mask))):
        image, binary = p._load_cutout(png, mask_png)
        base = np.asarray(fabric_details['reconstruction']['views'][view]['base_rgb'], float)
        # Every unused atlas pixel is fabric, so mipmaps cannot sample black voids.
        atlas.paste(Image.new('RGB', (1024, 2048), tuple(np.rint(base).astype(int))), (vi*1024, 0))
        info = {'mode': VERSION, 'panels': {}}
        if bottom:
            lo, hi = mapping['min'], mapping['max']
            dimensions = (hi[0]-lo[0], hi[1]-lo[1])
            crops[view] = _crop(binary)
            if mapping['crotch_ratio'] >= 1:
                tile, report = _place(image, binary, dimensions, (1024, 1536), base)
                info['panels']['skirt'] = report
            else:
                regions, split = _pants_regions(binary)
                ratio = float(mapping['crotch_ratio'])
                cut = int(round(ratio*1536))
                tile = Image.new('RGB', (1024, 1536), tuple(np.rint(base).astype(int)))
                waist, report = _place(image, regions[0], (dimensions[0], dimensions[1]*ratio), (1024, cut), base)
                tile.paste(waist, (0, 0)); info['panels']['waist'] = report
                for side in (0, 1):
                    model_side = side if view == 'front' else 1-side
                    a, b = mapping['canonical_leg_bounds'][model_side]
                    if view == 'back': a, b = lo[0]+hi[0]-b, lo[0]+hi[0]-a
                    px0 = int(round((a-lo[0])/dimensions[0]*1024))
                    px1 = int(round((b-lo[0])/dimensions[0]*1024))
                    leg, report = _place(image, regions[side+1], (b-a, dimensions[1]*(1-ratio)), (max(1, px1-px0), 1536-cut), base, rotate=True)
                    tile.paste(leg, (px0, cut))
                    info['panels']['left_leg' if side == 0 else 'right_leg'] = report
                info['source_crotch_y'] = split/image.height
            atlas.paste(tile, (vi*1024, 0))
        else:
            crop = p.torso_crop(binary); crops[view] = crop
            yy, xx = np.indices(binary.shape)
            x0, x1 = crop['x']*image.width, (crop['x']+crop['w'])*image.width
            y0, y1 = crop['y']*image.height, (crop['y']+crop['h'])*image.height
            body = binary & (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
            dims = mapping['body_max']-mapping['body_min']
            tile, report = _place(image, body, dims[:2], (1024, 1024), base)
            atlas.paste(tile, (vi*1024, 0)); info['panels']['torso'] = report
            for si, side in enumerate(('left', 'right')):
                region = binary & ((xx < x0) if si == 0 else (xx >= x1)) & (yy >= y0)
                labels, n = ndi.label(region)
                if n:
                    sizes = np.bincount(labels.ravel()); sizes[0] = 0
                    region = labels == sizes.argmax()
                g = (1 if si == 0 else 2) if view == 'front' else (2 if si == 0 else 1)
                arm = mapping['arms'][g]
                if region.sum() < max(20, body.sum()*.012):
                    tile = Image.new('RGB', (512, 1024), tuple(np.rint(base).astype(int)))
                    report = {'mode': 'fabric_estimate', 'reason': 'sleeve_not_separately_visible'}
                else:
                    tile, report = _place(image, region, (arm[6], arm[4]), (512, 1024), base, rotate=True)
                atlas.paste(tile, (vi*1024+si*512, 1024)); info['panels'][side+'_sleeve'] = report
        details[view] = info
    stream = io.BytesIO(); atlas.save(stream, 'PNG')
    fabric_details.update(tone={'mode': 'reconstructed_material_passthrough'},
                          canonical2D={'version': VERSION, 'size': [2048, 2048],
                                       'front_rect': [0, 0, 1024, 2048], 'back_rect': [1024, 0, 1024, 2048],
                                       'atlasSha256': p.digest(stream.getvalue()), 'embedded_in_glb': True,
                                       'placement': 'uniform_scale_per_panel_in_model_units',
                                       'limitations': ['photo_folds_and_perspective_not_recovered', 'unseen_fabric_estimated', 'not_a_sewing_pattern']},
                          projection_samples={v: {'mode': VERSION} for v in crops},
                          unobserved_padding='per_view_reconstructed_fabric')
    return atlas, crops, details


def bottom_uv(points, front, mapping):
    """Constant planar coordinates: no silhouette-dependent stretch on each row."""
    lo, hi = mapping['min'], mapping['max']
    x = np.clip((points[:, 0]-lo[0])/(hi[0]-lo[0]), 0, 1)
    y = np.clip((hi[1]-points[:, 1])/(hi[1]-lo[1]), 0, 1)
    uv = np.empty((len(points), 2), dtype='<f4')
    uv[:, 0] = (np.where(front, 0, 1024)+np.where(front, x, 1-x)*1023+.5)/2048
    uv[:, 1] = (y*1535+.5)/2048
    return uv


def projected_uv(points, parts, front, spec, mapping):
    if 'body_min' not in mapping:
        return bottom_uv(points, front, mapping)
    uv = np.empty((len(points), 2), dtype='<f4')
    body = parts == 0
    lo, hi = mapping['body_min'], mapping['body_max']
    x = np.clip((points[body, 0]-lo[0])/(hi[0]-lo[0]), 0, 1)
    y = np.clip((hi[1]-points[body, 1])/(hi[1]-lo[1]), 0, 1)
    uv[body, 0] = (np.where(front[body], 0, 1024)+np.where(front[body], x, 1-x)*1023+.5)/2048
    uv[body, 1] = (y*1023+.5)/2048
    for g in (1, 2):
        chosen = parts == g
        center, axis, across, a0, aw, b0, bw = mapping['arms'][g]
        q = points[chosen, :2]-center
        t = np.clip((q@axis-a0)/aw, 0, 1)
        s = np.clip((q@across-b0)/bw, 0, 1)
        image_right = np.where(front[chosen], g == 2, g == 1)
        uv[chosen, 0] = (np.where(front[chosen], 0, 1024)+image_right*512+np.where(front[chosen], s, 1-s)*511+.5)/2048
        uv[chosen, 1] = (1024+t*1023+.5)/2048
    return uv
