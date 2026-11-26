"""Automatic photo projection onto one calibrated, already-fitted T-shirt.

This creates an unreviewed outfit preview, not a new garment shape or fit estimate.
Uses NumPy, Pillow and SciPy, already included in the Tailor runtime.
"""
from __future__ import annotations

import copy
import hashlib
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image

VERSION = 'male_tshirt_auto_projection_v1'
MAPPING_VERSION = 'mask_sleeve_regions_v4_soft_seams'
TEMPLATE_SHA256 = '520b39f5e4ba332a65726be488c6417df34f4bf23be1bcefb1c21c0ea8d2ad0e'
TEMPLATE_PATH = Path(__file__).with_name('photo_templates') / 'tshirtm.glb'
X0, X1 = -252.23594665527344, 261.69287109375
Z0, Z1 = -1633.0225830078125, -904.7359008789062


class ProjectionError(ValueError):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def decode_glb(data: bytes) -> tuple[dict, bytes]:
    if len(data) < 28 or struct.unpack_from('<III', data) != (0x46546C67, 2, len(data)):
        raise ProjectionError('Invalid GLB container.')
    count, kind = struct.unpack_from('<II', data, 12)
    if kind != 0x4E4F534A or 28 + count > len(data):
        raise ProjectionError('Invalid GLB JSON chunk.')
    manifest = json.loads(data[20:20 + count])
    length, kind = struct.unpack_from('<II', data, 20 + count)
    if kind != 0x004E4942 or 28 + count + length != len(data):
        raise ProjectionError('Invalid GLB binary chunk.')
    return manifest, data[28 + count:]


def accessor(manifest: dict, binary: bytes, index: int) -> np.ndarray:
    a = manifest['accessors'][index]
    v = manifest['bufferViews'][a['bufferView']]
    dimensions = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]
    dtype = {5123: '<u2', 5125: '<u4', 5126: '<f4'}[a['componentType']]
    if 'byteStride' in v or 'sparse' in a:
        raise ProjectionError('Unexpected calibrated template layout.')
    return np.frombuffer(binary, dtype=dtype, count=a['count'] * dimensions,
                         offset=v.get('byteOffset', 0) + a.get('byteOffset', 0)).reshape(a['count'], dimensions)


def _load_cutout(rgba_png: bytes, mask_png: bytes) -> tuple[Image.Image, np.ndarray]:
    image = Image.open(io.BytesIO(rgba_png)).convert('RGBA')
    mask = Image.open(io.BytesIO(mask_png)).convert('L')
    if image.size != mask.size or min(image.size) < 32 or max(image.size) > 4096:
        raise ProjectionError('Cutout and mask sizes do not match or are unsupported.')
    pixels = np.array(image)
    binary = (np.array(mask) >= 128) & (pixels[:, :, 3] >= 128)
    fraction = float(binary.mean())
    if fraction < .015 or fraction > .95:
        raise ProjectionError('Garment mask is empty, tiny or covers the whole image.')
    pixels[:, :, 3] = np.where(binary, pixels[:, :, 3], 0)
    return Image.fromarray(pixels), binary


def automatic_torso_crop(binary: np.ndarray) -> dict:
    """Find shoulders/hem from stable row widths, then exclude short sleeves.

    This is calibrated short-sleeve alignment. It cannot semantically guarantee
    removal of connected hanger/tag pixels; failed masks must be corrected.
    """
    if binary.ndim != 2 or not binary.any():
        raise ProjectionError('A nonempty two-dimensional garment mask is required.')
    height, width = binary.shape
    active = binary.any(axis=1)
    left = np.argmax(binary, axis=1)
    right = width - np.argmax(binary[:, ::-1], axis=1)
    spans = np.where(active, right - left, 0)
    counts = binary.sum(axis=1)
    peak = int(spans.max())
    broad = (spans >= peak * .38) & (counts >= peak * .25)
    # Reject thin hanger bars/noisy rows above the substantial garment body.
    stable_length = max(4, int(active.sum() * .035))
    stable = np.convolve(broad.astype(np.int32), np.ones(stable_length, dtype=np.int32), mode='valid')
    starts = np.flatnonzero(stable == stable_length)
    if len(starts) == 0:
        raise ProjectionError('Could not locate a stable shirt body in the mask.')
    top, bottom = int(starts[0]), int(starts[-1] + stable_length)
    rows = np.arange(top + int((bottom - top) * .55), top + int((bottom - top) * .86))
    rows = rows[broad[rows]]
    if len(rows) < 3:
        raise ProjectionError('The lower shirt body is too incomplete to align.')
    x0, x1 = int(np.median(left[rows])), int(np.median(right[rows]))
    if x1 - x0 < peak * .25 or bottom - top < height * .2:
        raise ProjectionError('Unreliable shirt-body proportions; retry the photos.')
    return {'x': x0 / width, 'y': top / height,
            'w': (x1 - x0) / width, 'h': (bottom - top) / height}


def _foreground_colour(image: Image.Image, region: np.ndarray) -> tuple[int, int, int]:
    pixels = np.asarray(image)[:, :, :3][region]
    if len(pixels) == 0:
        raise ProjectionError('No visible garment fabric is available.')
    return tuple(np.median(pixels, axis=0).astype(np.uint8).tolist())


def sleeve_tile(image: Image.Image, binary: np.ndarray, crop: dict, side: str) -> tuple[Image.Image, dict]:
    """Estimate one visible sleeve from mask geometry, independently of print.

    No fixed photo coordinates, colours, garment identity or uploaded example
    are used. This does not semantically reconstruct occluded fabric.
    """
    from scipy import ndimage

    height, width = binary.shape
    x0, x1 = crop['x'] * width, (crop['x'] + crop['w']) * width
    y0, body_height = crop['y'] * height, crop['h'] * height
    body_width = x1 - x0
    yy, xx = np.indices(binary.shape)
    lateral = xx < x0 if side == 'left' else xx > x1
    candidate = binary & lateral & (yy >= y0) & (yy < y0 + body_height * .70)
    # Remove thin torso-edge slivers that can masquerade as a long sleeve.
    opening = max(3, min(7, int(body_width * .02) | 1))
    candidate = ndimage.binary_opening(candidate, structure=np.ones((opening, opening), dtype=bool))
    labels, number = ndimage.label(candidate)
    components = np.bincount(labels.ravel())
    if number:
        components[0] = 0
        region = labels == int(components.argmax())
    else:
        region = np.zeros_like(binary)
    base_colour = _foreground_colour(image, binary)
    fallback = Image.new('RGB', (512, 512), base_colour)
    info = {'mode': 'estimated_colour', 'reason': 'sleeve_not_separately_visible',
            'observed_pixels': int(region.sum()), 'coverage': 0.0}
    if region.sum() < max(64, body_width * body_height * .012):
        return fallback, info
    ys, xs = np.nonzero(region)
    points = np.column_stack((xs, ys)).astype(float)
    center = points.mean(axis=0)
    values, vectors = np.linalg.eigh(np.cov((points - center).T))
    ratio = float(values[-1] / max(values[0], 1e-8))
    if ratio < 1.15:
        info['reason'] = 'ambiguous_sleeve_direction'
        return fallback, info
    boundary = x0 if side == 'left' else x1
    root_points = points[np.abs(points[:, 0] - boundary) < max(3, body_width * .045)]
    if len(root_points) < 6:
        info['reason'] = 'missing_shoulder_attachment'
        return fallback, info
    root = np.median(root_points, axis=0)
    axis = vectors[:, -1]
    if np.dot(axis, center - root) < 0:
        axis = -axis
    if np.dot(axis, center - root) < body_width * .025:
        info['reason'] = 'ambiguous_shoulder_to_cuff'
        return fallback, info
    # Across-sleeve direction follows camera left-to-right, preventing mirrors.
    transverse = np.array([axis[1], -axis[0]])
    if transverse[0] < 0:
        transverse = -transverse
    a = (points - center) @ axis
    b = (points - center) @ transverse
    a0, a1 = np.quantile(a, [.015, .985])
    b0, b1 = np.quantile(b, [.015, .985])
    if a1 - a0 < body_height * .10 or b1 - b0 < body_width * .07:
        info['reason'] = 'sleeve_region_too_incomplete'
        return fallback, info
    # Rotate the actual sleeve pixels from shoulder to cuff into their own tile.
    # Pixels outside the selected mask component are never sampled as fabric.
    pixels = np.array(image)
    pixels[:, :, 3] = np.where(region, pixels[:, :, 3], 0)
    source = Image.fromarray(pixels)
    origin = center + axis * a0 + transverse * b0
    across = transverse * (b1 - b0) / 511
    along = axis * (a1 - a0) / 511
    coefficients = (across[0], along[0], origin[0], across[1], along[1], origin[1])
    warped = source.transform((512, 512), Image.Transform.AFFINE, coefficients,
                              resample=Image.Resampling.BILINEAR)
    coverage = float((np.asarray(warped)[:, :, 3] > 200).mean())
    info['coverage'] = round(coverage, 4)
    if coverage < .55:
        info['reason'] = 'insufficient_visible_sleeve_area'
        return fallback, info
    observed_colour = _foreground_colour(image, region)
    # Pad the observed sleeve boundary with nearby observed pixels. A solid
    # colour under transparent warp corners creates visible grey slashes at
    # template joins. This padding is an estimated continuation, never a claim
    # that hidden sleeve artwork was photographed.
    visible=np.asarray(warped)[:,:,3]>200
    _,nearest=ndimage.distance_transform_edt(~visible,return_indices=True)
    rgb=np.asarray(warped)[:,:,:3]
    padded=rgb[nearest[0],nearest[1]].astype(float)
    padded=ndimage.gaussian_filter(padded,sigma=(1.2,1.2,0))
    output = Image.fromarray(np.clip(padded,0,255).astype(np.uint8)).convert('RGBA')
    output.alpha_composite(warped)
    info.update(mode='projected_estimate', reason='visible_mask_region',
                shoulder_to_cuff_axis=axis.tolist(), transverse_axis=transverse.tolist(),
                axis_ratio=round(ratio, 4))
    return output.convert('RGB'), info


def _sleeve_uv(positions: np.ndarray, front: np.ndarray) -> np.ndarray:
    """Independent left/right, front/back sleeve islands on the same template.

    Image front-left maps to world-left; image back-left maps to world-right.
    Shoulder/cuff coordinates come from the template mesh itself, not a photo.
    """
    uv = np.empty((len(positions), 2), dtype='<f4')
    mid = (X0 + X1) / 2
    left = np.repeat(positions.reshape(-1, 3, 3)[:, :, 0].mean(axis=1) < mid, 3)
    for physical_left in (True, False):
        selected = left == physical_left
        if not selected.any():
            continue
        points = positions[selected][:, [0, 2]].astype(float)
        center = points.mean(axis=0)
        _, vectors = np.linalg.eigh(np.cov((points - center).T))
        axis = vectors[:, -1]
        if axis[1] < 0:
            axis = -axis  # template's local +Z goes from shoulder to cuff
        transverse = np.array([axis[1], -axis[0]])
        a = (points - center) @ axis
        b = (points - center) @ transverse
        t = np.clip((a - a.min()) / max(float(np.ptp(a)), 1e-8), 0, 1)
        s = np.clip((b - b.min()) / max(float(np.ptp(b)), 1e-8), 0, 1)
        face_front = front[selected]
        # Physical left appears on camera right in the back photograph.
        image_right = np.where(face_front, not physical_left, physical_left)
        tile_x = np.where(face_front, 0, 1024) + image_right.astype(int) * 512
        s = np.where(face_front, s, 1 - s)
        uv[selected, 0] = (tile_x + 2 + s * 508) / 2048
        uv[selected, 1] = (1536 + 2 + t * 508) / 2048
    return uv


def clean_front_neckline(image: Image.Image, binary: np.ndarray, crop: dict) -> tuple[Image.Image, dict]:
    """Continue observed collar fabric over an exposed neck interior.

    A central enclosed mask gap anchors the search. This may be a neck opening
    or an excluded label. Without that evidence and a supported curved seam we
    abstain: a foreground mask alone cannot identify inside/back fabric.
    Operates on a copy used only for the front atlas, never the saved cutout.
    """
    from scipy import ndimage as ndi

    unchanged = {'mode': 'unchanged', 'reason': 'no_supported_front_collar'}
    height, width = binary.shape
    bw, bh = crop['w'] * width, crop['h'] * height
    mid = (crop['x'] + crop['w'] / 2) * width
    active_y = np.nonzero(binary)[0]
    top = float(np.quantile(active_y, .005))
    filled = ndi.binary_fill_holes(binary)
    labels, count = ndi.label(filled & ~binary)
    anchors = []
    for label in range(1, count + 1):
        yy, xx = np.nonzero(labels == label)
        if len(xx) < max(12, bw * bh * .00015):
            continue
        cx, cy = float(np.median(xx)), float(np.median(yy))
        if (abs(cx-mid) < bw*.18 and top < cy < top+bh*.19
                and bw*.02 < np.ptp(xx) < bw*.42
                and bh*.008 < np.ptp(yy) < bh*.16):
            anchors.append((len(xx), cx, float(yy.max()), label))
    if not anchors:
        return image, unchanged
    _, anchor_x, anchor_y, anchor_label = max(anchors)
    # Normalize resolution for stable derivative thresholds and bounded work.
    scale = min(1., 360. / bw)
    size = (max(32, round(width*scale)), max(32, round(height*scale)))
    rgb = np.asarray(image.resize(size, Image.Resampling.BILINEAR))[:, :, :3].astype(float)/255
    valid = np.asarray(Image.fromarray(binary).resize(size, Image.Resampling.NEAREST))
    safe = ndi.binary_erosion(valid, iterations=2)
    gray = ndi.gaussian_filter(rgb @ np.array([.2126,.7152,.0722]), .8)
    gy, gx = np.gradient(gray)
    bw_s, bh_s = bw*scale, bh*scale
    anchor_x *= scale; anchor_y *= scale; top *= scale
    # Side arcs supply evidence; a rectangular label is not a U-shaped seam.
    t = np.concatenate((np.linspace(-.94,-.25,45), np.linspace(.25,.94,45)))
    shape = np.sqrt(1-t*t)
    best = None
    for cx in anchor_x + np.linspace(-.035,.035,5)*bw_s:
        for radius in np.linspace(.20,.34,12)*bw_s:
            xs = cx + radius*t
            for center_y in anchor_y + np.linspace(0.,.022,7)*bh_s:
                for depth in np.linspace(.065,.16,9)*bh_s:
                    edge_top = center_y-depth
                    if not top-bh_s*.045 <= edge_top <= top+bh_s*.055:
                        continue
                    for slope in (-.08,0.,.08):
                        ys = center_y-depth+depth*shape+slope*radius*t
                        support = ndi.map_coordinates(safe.astype(float),[ys,xs],order=0,mode='constant')>.5
                        # Gradient projected onto the normal of the candidate seam.
                        derivative = -depth/radius*t/shape+slope
                        normalizer = np.sqrt(1+derivative**2)
                        strengths = []
                        for delta in (-1.,0.,1.):
                            a = ndi.map_coordinates(gy,[ys+delta,xs],order=1,mode='constant')
                            b = ndi.map_coordinates(gx,[ys+delta,xs],order=1,mode='constant')
                            strengths.append(np.abs(a-derivative*b)/normalizer)
                        strength=np.maximum.reduce(strengths)
                        present=(strength>.0045)&support
                        halves=min(present[:45].mean(),present[45:].mean())
                        if support.mean()<.84 or present.mean()<.68 or halves<.60:
                            continue
                        score=float(np.minimum(strength,.025).mean())*float(present.mean())
                        if best is None or score>best[0]:
                            best=(score,cx,radius,center_y,depth,slope,float(present.mean()))
    if best is None:
        return image, unchanged
    score,cx,radius,center_y,depth,slope,coverage=best
    xs=np.arange(width,dtype=float)
    u=(xs*scale-cx)/radius
    curve=(center_y-depth+depth*np.sqrt(np.maximum(0,1-u*u))+slope*radius*u)/scale
    inside_x=np.abs(u)<.94
    yy=np.arange(height)[:,None]
    # Include a two-pixel seam tolerance for antialiased label fringes.
    # The wider collar band below the inner seam remains observed fabric.
    # Fill small mask holes inside this region as well:
    # otherwise a missing label is filled with an unrelated whole-shirt median.
    interior=filled & inside_x[None,:] & (yy<curve[None,:]+2./scale)
    interior |= labels == anchor_label
    if not interior.any():
        return image, unchanged
    source=np.array(image)
    # One robust collar colour, sampled below the arc, avoids copying stripes
    # from print into vertical bands. Smooth illumination remains approximate.
    offsets=np.arange(3, max(5,round(bh*.018)))
    rows=np.clip((curve[:,None]+offsets).astype(int),0,height-1)
    cols=np.broadcast_to(np.arange(width)[:,None],rows.shape)
    sample_ok=binary[rows,cols] & (np.abs(u[:,None])<.85)
    samples=source[rows,cols,:3][sample_ok]
    if len(samples)<32:
        return image, unchanged
    color=np.median(samples,axis=0).astype(np.uint8)
    # Blend outward into the observed collar band; keep the entire tag region
    # at full replacement strength so antialiased tag fragments cannot return.
    distance=ndi.distance_transform_edt(~interior)
    blend_width=max(3.,bw*.018)
    weight=np.clip(1-distance/blend_width,0,1)
    weight=weight*weight*(3-2*weight)
    out=source.copy()
    out[:,:,:3]=np.clip(source[:,:,:3]*(1-weight[:,:,None])+color*weight[:,:,None],0,255).astype(np.uint8)
    out[:,:,3][interior]=255
    return Image.fromarray(out), {'mode':'estimated_collar_continuation',
        'anchor':'enclosed_upper_mask_gap','edge_coverage':round(coverage,4),
        'changed_pixels':int(interior.sum()), 'colour':color.tolist(),
        'curve':{'center_x':float(cx/scale),'radius':float(radius/scale),
                 'center_y':float(center_y/scale),'depth':float(depth/scale),'slope':slope},
        'limitation':'neck_interior_fabric_is_estimated_not_reconstructed'}


def _panel(image: Image.Image, binary: np.ndarray, crop: dict) -> tuple[Image.Image, Image.Image]:
    x, y = round(crop['x'] * image.width), round(crop['y'] * image.height)
    w, h = round(crop['w'] * image.width), round(crop['h'] * image.height)
    body = image.crop((x, y, x + w, y + h))
    # Fill transparent neckline/edge pixels with observed garment colour. We
    # never fill them with room pixels or retain the template's original print.
    values = np.array(image)[:, :, :3][binary]
    color = tuple(np.median(values, axis=0).astype(np.uint8).tolist())
    opaque = Image.new('RGBA', body.size, (*color, 255))
    opaque.alpha_composite(body)
    swatch = Image.new('RGB', (1024, 512), color)
    return opaque.convert('RGB').resize((1024, 1536), Image.Resampling.LANCZOS), swatch.convert('RGB').resize((1024, 512), Image.Resampling.LANCZOS)


def blend_sleeve_boundaries(atlas: Image.Image) -> Image.Image:
    """Blend narrow sleeve gutters to the body at shared template vertices.

    Only a calibrated mesh seam supplies colour correspondences. No photo
    coordinates are inferred, no torso artwork is blurred, and geometry stays
    unchanged. The transition is an estimate, not recovered hidden artwork.
    """
    from scipy import ndimage
    from scipy.spatial import cKDTree

    template = TEMPLATE_PATH.read_bytes()
    if digest(template) != TEMPLATE_SHA256:
        raise ProjectionError('The calibrated male T-shirt template is missing or changed.')
    doc, blob = decode_glb(template)
    bodies, sleeves = [], []
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            index = accessor(doc, blob, primitive['indices']).ravel()
            pos = accessor(doc, blob, primitive['attributes']['POSITION'])[index]
            norm = accessor(doc, blob, primitive['attributes']['NORMAL'])[index]
            is_sleeve = doc['materials'][primitive['material']]['name'].startswith('Photographed sleeve projection')
            (sleeves if is_sleeve else bodies).append((pos, norm))
    if not bodies or not sleeves:
        return atlas
    tree = cKDTree(np.concatenate([part[0] for part in bodies]))
    original = np.array(atlas)
    seeds = np.zeros((512,2048), dtype=bool)
    colors = np.zeros((512,2048,3), dtype=float)
    for pos, norm in sleeves:
        matched = tree.query(pos)[0] < .001
        suv = projected_uv(pos,norm,True)*2048
        buv = projected_uv(pos,norm,False)*2048
        for start in range(0,len(pos),3):
            for a,b in ((0,1),(1,2),(2,0)):
                i,j=start+a,start+b
                if not (matched[i] and matched[j]):
                    continue
                length = int(np.ceil(np.linalg.norm(suv[i]-suv[j])))
                if length > 512:
                    continue
                t=np.linspace(0,1,max(2,length*2+1))[:,None]
                target=np.rint(suv[i]*(1-t)+suv[j]*t).astype(int)
                source=buv[i]*(1-t)+buv[j]*t
                tx=np.clip(target[:,0],0,2047);ty=np.clip(target[:,1]-1536,0,511)
                sample=np.stack([ndimage.map_coordinates(original[:,:,c].astype(float),
                    [source[:,1],source[:,0]],order=1,mode='nearest') for c in range(3)],axis=1)
                seeds[ty,tx]=True;colors[ty,tx]=sample
    result=original.copy()
    for tile in range(4):
        x=tile*512; region=seeds[:,x:x+512]
        if not region.any():
            continue
        distance,nearest=ndimage.distance_transform_edt(~region,return_indices=True)
        sampled=colors[:,x:x+512][nearest[0],nearest[1]]
        # A narrow smooth gutter joins the seams without blurring sleeve prints.
        amount=np.clip(1-distance/18.,0,1)
        amount=amount*amount*(3-2*amount)
        tile_pixels=original[1536:,x:x+512].astype(float)
        result[1536:,x:x+512]=np.clip(tile_pixels*(1-amount[:,:,None])+sampled*amount[:,:,None],0,255).astype(np.uint8)
    return Image.fromarray(result)


def make_atlas(front_png: bytes, back_png: bytes, front_mask: bytes, back_mask: bytes,
               mapping_details: dict | None = None, collar_details: dict | None = None) -> tuple[bytes, dict]:
    atlas = Image.new('RGB', (2048, 2048))
    crops = {}
    for index, (view, png, mask) in enumerate((('front', front_png, front_mask), ('back', back_png, back_mask))):
        image, binary = _load_cutout(png, mask)
        crop = automatic_torso_crop(binary)
        panel_image, collar = clean_front_neckline(image, binary, crop) if view == 'front' else (image, {'mode':'not_applied_to_back'})
        body, _ = _panel(panel_image, binary, crop)
        if collar_details is not None and view == 'front':
            collar_details.update(collar)
        atlas.paste(body, (index * 1024, 0))
        observations = {}
        for side_index, side in enumerate(('left', 'right')):
            tile, observation = sleeve_tile(image, binary, crop, side)
            atlas.paste(tile, (index * 1024 + side_index * 512, 1536))
            observations[side] = observation
        if mapping_details is not None:
            mapping_details[view] = observations
        crops[view] = crop
    atlas = blend_sleeve_boundaries(atlas)
    output = io.BytesIO()
    atlas.save(output, 'PNG')
    return output.getvalue(), crops


def projected_uv(positions: np.ndarray, normals: np.ndarray, sleeves: bool) -> np.ndarray:
    if positions.shape != normals.shape or positions.shape[1:] != (3,) or len(positions) % 3:
        raise ProjectionError('Expected non-indexed position/normal triangles.')
    front = np.repeat(normals.reshape(-1, 3, 3)[:, :, 1].sum(axis=1) >= 0, 3)
    if sleeves:
        return _sleeve_uv(positions, front)
    x = np.clip((positions[:, 0] - X0) / (X1 - X0), 0, 1)
    y = np.clip((positions[:, 2] - Z0) / (Z1 - Z0), 0, 1)
    uv = np.empty((len(positions), 2), dtype='<f4')
    uv[:, 0] = ((~front).astype(np.float32) + .002 + np.where(front, x, 1 - x) * .996) / 2
    uv[:, 1] = .752 + y * .246 if sleeves else .002 + y * .746
    return uv


def texture_template(atlas_png: bytes, template_data: bytes | None = None) -> bytes:
    template = TEMPLATE_PATH.read_bytes() if template_data is None else template_data
    if digest(template) != TEMPLATE_SHA256:
        raise ProjectionError('The calibrated male T-shirt template is missing or changed.')
    source, binary = decode_glb(template)
    result = copy.deepcopy(source)
    result['accessors'], result['bufferViews'] = [], []
    result['materials'] = [{'name': 'Automatic front-back photo projection; sleeves approximate',
                           'doubleSided': True, 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0},
                           'metallicFactor': 0, 'roughnessFactor': .85}}]
    result['textures'] = [{'source': 0, 'sampler': 0}]
    result['samplers'] = [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 33071, 'wrapT': 33071}]
    result['asset'] = {'version': '2.0', 'generator': f'{VERSION}/{MAPPING_VERSION}'}
    payload = bytearray()

    def add_view(data: bytes, target: int | None = None) -> int:
        payload.extend(b'\0' * (-len(payload) % 4))
        view = {'buffer': 0, 'byteOffset': len(payload), 'byteLength': len(data)}
        if target is not None:
            view['target'] = target
        result['bufferViews'].append(view)
        payload.extend(data)
        return len(result['bufferViews']) - 1

    def add_array(values: np.ndarray, kind: str, bounds: bool = False) -> int:
        view = add_view(values.astype('<f4').tobytes(), 34962)
        a = {'bufferView': view, 'componentType': 5126, 'count': len(values), 'type': kind}
        if bounds:
            a.update(min=values.min(axis=0).tolist(), max=values.max(axis=0).tolist())
        result['accessors'].append(a)
        return len(result['accessors']) - 1

    for mesh_index, mesh in enumerate(source['meshes']):
        for primitive_index, p in enumerate(mesh['primitives']):
            if p.get('mode', 4) != 4:
                raise ProjectionError('Unsupported template primitive.')
            indices = accessor(source, binary, p['indices']).ravel()
            positions = accessor(source, binary, p['attributes']['POSITION'])[indices]
            normals = accessor(source, binary, p['attributes']['NORMAL'])[indices]
            sleeves = source['materials'][p['material']]['name'].startswith('Photographed sleeve projection')
            uv = projected_uv(positions, normals, sleeves)
            result['meshes'][mesh_index]['primitives'][primitive_index] = {
                'mode': 4, 'material': 0, 'attributes': {
                    'POSITION': add_array(positions, 'VEC3', True),
                    'NORMAL': add_array(normals, 'VEC3'),
                    'TEXCOORD_0': add_array(uv, 'VEC2')}}
    result['images'] = [{'mimeType': 'image/png', 'bufferView': add_view(atlas_png), 'name': 'automatic_front_back_atlas'}]
    result['buffers'] = [{'byteLength': len(payload)}]
    encoded = json.dumps(result, separators=(',', ':'), allow_nan=False).encode()
    encoded += b' ' * (-len(encoded) % 4)
    payload.extend(b'\0' * (-len(payload) % 4))
    size = 12 + 8 + len(encoded) + 8 + len(payload)
    return (struct.pack('<III', 0x46546C67, 2, size) + struct.pack('<II', len(encoded), 0x4E4F534A) + encoded
            + struct.pack('<II', len(payload), 0x004E4942) + payload)


def generate(front_png: bytes, back_png: bytes, front_mask: bytes, back_mask: bytes,
             original_front: bytes, original_back: bytes) -> tuple[bytes, dict]:
    sleeve_details, collar_details = {}, {}
    atlas, crops = make_atlas(front_png, back_png, front_mask, back_mask, sleeve_details, collar_details)
    glb = texture_template(atlas)
    sidecar = {'templateVersion': VERSION, 'templateSha256': TEMPLATE_SHA256,
               'bodyProfile': 'male_average', 'sourceCategory': 'short_sleeve_top',
               'method': 'automatic_mask_torso_v1', 'userReviewed': False,
               'frontSha256': digest(original_front), 'backSha256': digest(original_back),
               'displayFrontSha256': digest(front_png), 'displayBackSha256': digest(back_png),
               'frontMaskSha256': digest(front_mask), 'backMaskSha256': digest(back_mask),
               'frontCrop': crops['front'], 'backCrop': crops['back'], 'glbSha256': digest(glb),
               'sleeves': 'visible_regions_or_estimated_colour',
               'sleeveBoundaryBlend': 'shared_template_vertices_18px_smoothstep',
               'sleeveUnseenFill': 'estimated_nearest_visible_fabric_boundary',
               'mappingVersion': MAPPING_VERSION, 'frontCollar': collar_details, 'sleeveMapping': sleeve_details,
               'warnings': ['automatic_preview_unreviewed', 'sleeve_texture_approximate', 'template_shape_not_measured_fit']}
    if sidecar['frontCollar'].get('mode') == 'estimated_collar_continuation':
        sidecar['warnings'].append('front_neck_interior_uses_estimated_collar_colour')
    if any(part['mode'] == 'estimated_colour' for view in sleeve_details.values() for part in view.values()):
        sidecar['warnings'].append('some_sleeve_regions_use_estimated_colour')
    return glb, sidecar
