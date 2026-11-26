"""Whole-garment, two-view fashion recognition; no upload leaves this machine.

Similarity scores are NOT calibrated probabilities. The frozen v0.1 classifier
and its original prediction remain separate, unmodified evidence in the API.
"""
from __future__ import annotations
import hashlib
import io
import json
import os
from functools import lru_cache
from pathlib import Path
import numpy as np
from PIL import Image

VERSION = 'fashion-siglip-details-v2'
MODEL_ID = 'Marqo/marqo-fashionSigLIP'
REVISION = 'c56244cc94f92419e8369fa71efdaf403b124ce8'
MODEL_SHA256 = '88908200434959fa3154ef79d408aac33341e8797fe5ca8ca6f0463aab32e6b3'
# A shared vocabulary avoids making an unsupported garment look supported simply
# by omitting it from the choices for a particular avatar.
FAMILIES = {
    'short_sleeve_top': ('a short sleeve t-shirt', 'a tee shirt with short sleeves'),
    'long_sleeve_top': ('a long sleeve t-shirt or crewneck sweater', 'a long sleeved shirt without a hood'),
    'outerwear': ('a hooded sweatshirt', 'a pullover hoodie or zip-up hoodie'),
    'shorts': ('a pair of shorts', 'short pants ending above the knees'),
    'trousers': ('a pair of long pants', 'trousers or sweatpants or jeans'),
    'skirt': ('a skirt', 'a pleated skirt'),
    'dress': ('a dress', 'a one-piece dress'),
    'sleeveless_top': ('a sleeveless tank top', 'a vest top without sleeves'),
    'unsupported': ('a jacket or coat', 'shoes or a handbag'),
}
STYLES = {
    'short_sleeve_top': {
        'tshirt': ('a short sleeve t-shirt', 'a crew neck short sleeved tee shirt')},
    'long_sleeve_top': {
        'long_tee': ('a long sleeve t-shirt with a plain hem', 'a lightweight long sleeve tee'),
        'sweater': ('a crewneck sweatshirt with ribbed cuffs and waistband', 'a knitted sweater or pullover'),
        'button_up': ('a long sleeve button-up shirt with a collar', 'a collared shirt with buttons down the front')},
    'outerwear': {
        'hoodie': ('a pullover hooded sweatshirt', 'a hoodie without a front zipper'),
        'zip_hoodie': ('a full zip hooded sweatshirt', 'a zip-up hoodie with a zipper down the front')},
    'trousers': {
        'ankle_sweats': ('a pair of tapered cuffed sweatpants', 'jogger sweatpants with elastic ankle cuffs'),
        'drawstring_sweats': ('a pair of sweatpants with a visible drawstring waist', 'drawstring jogger pants'),
        'baggy_sweats': ('a pair of baggy wide leg sweatpants', 'loose straight leg sweatpants'),
        'skinny_jeans': ('a pair of skinny denim jeans', 'slim fitted jeans'),
        'capris': ('a pair of capri pants ending below the knees', 'cropped calf length pants'),
        'sweats': ('a pair of relaxed sweatpants', 'straight leg jogging pants')},
    'shorts': {'shorts': ('a pair of shorts', 'short pants')},
    'skirt': {'pleated_skirt': ('a pleated skirt', 'a short tennis skirt')},
}

from tailor_ai.inference.garment_details import detail_views, agreed_detail, compatible_styles, HEMS, WAIST, FASTENING, PATTERN, WAISTBAND, MALE_ANKLE_SWEATS

class RecognitionError(ValueError):
    pass


def cache_directory():
    return Path(os.environ.get('TAILOR_FASHION_MODEL_DIR',
        str(Path.home() / '.cache/textyle/fashion-siglip-v1'))).expanduser()


def whole_garment(png: bytes, mask_png: bytes) -> Image.Image:
    """Tight garment bbox with padding; letterbox rather than crop off sleeves."""
    image = Image.open(io.BytesIO(png)).convert('RGB')
    mask = np.asarray(Image.open(io.BytesIO(mask_png)).convert('L')) > 127
    if mask.shape != (image.height, image.width) or not mask.any():
        raise RecognitionError('The garment cutout is empty or mismatched. Retake both photos.')
    yy, xx = np.nonzero(mask)
    box = (int(xx.min()), int(yy.min()), int(xx.max())+1, int(yy.max())+1)
    white = Image.new('RGB', image.size, 'white')
    white.paste(image, (0, 0), Image.fromarray((mask*255).astype('uint8')))
    crop = white.crop(box)
    edge = max(crop.size)
    pad = max(4, round(edge * .045))
    square = Image.new('RGB', (edge+pad*2, edge+pad*2), 'white')
    square.paste(crop, ((square.width-crop.width)//2, (square.height-crop.height)//2))
    return square


def rank_categories(scores):
    """Require two independent views to agree on a supported family.

    These conservative similarity/margin checks are heuristic screening rules,
    not a calibrated accuracy claim; ambiguous pictures require a new capture.
    """
    scores = np.asarray(scores, dtype=float)
    keys = list(FAMILIES)
    if scores.shape != (2, len(keys)) or not np.isfinite(scores).all():
        raise RecognitionError('Recognition returned invalid results. Retry processing.')
    order = np.argsort(-scores, axis=1)
    combined = scores.mean(axis=0)
    winner = int(combined.argmax())
    margins = [float(row[idx[0]]-row[idx[1]]) for row,idx in zip(scores,order)]
    if int(order[0,0]) != int(order[1,0]):
        raise RecognitionError('The two photos do not clearly identify the same garment type. Retake front and back with the sleeves visible.')
    if float(combined[winner]) < .035 or min(margins) < .004:
        raise RecognitionError('The garment shape is unclear. Retake front and back against a plain background with the full garment visible.')
    category = keys[winner]
    if category not in STYLES:
        raise RecognitionError('This garment type has no matching 3D model. No substitute was saved.')
    return category, {'scores': {key:round(float(combined[i]),6) for i,key in enumerate(keys)},
        'views': [{'category': keys[int(idx[0])], 'margin':round(margin,6)} for idx,margin in zip(order,margins)]}


class FashionRecognizer:
    def __init__(self, directory=None):
        # Import lazily so legacy endpoints do not require the extra model.
        import torch
        import open_clip
        from open_clip.tokenizer import HFTokenizer
        root = Path(directory) if directory else cache_directory()
        manifest = root / 'verified.json'
        if not manifest.is_file():
            raise RecognitionError('Automatic recognition is not installed. Run the automatic-upload installer, then restart Tailor.')
        record = json.loads(manifest.read_text())
        if record.get('revision') != REVISION:
            raise RecognitionError('Automatic recognition model version does not match this update.')
        for filename, expected in record['files'].items():
            path = root / filename
            if path.parent != root or not path.is_file():
                raise RecognitionError('An automatic recognition model file is missing or changed. Rerun the installer.')
            with path.open('rb') as stream:
                actual = hashlib.file_digest(stream, 'sha256').hexdigest()
            if actual != expected:
                raise RecognitionError('An automatic recognition model file is missing or changed. Rerun the installer.')
        if record['files'].get('open_clip_model.safetensors') != MODEL_SHA256:
            raise RecognitionError('Automatic recognition model checksum is invalid.')
        # Native OpenCLIP + safetensors; no trust_remote_code or network in requests.
        cfg = json.loads((root/'open_clip_config.json').read_text())
        local_cfg = root/'textyle-fashion-v1.json'
        if not local_cfg.is_file() or json.loads(local_cfg.read_text()) != cfg['model_cfg']:
            raise RecognitionError('Automatic recognition configuration is invalid.')
        open_clip.add_model_config(local_cfg)
        self.torch = torch
        self.model, _, self.preprocess = open_clip.create_model_and_transforms(
            'textyle-fashion-v1', pretrained=str(root/'open_clip_model.safetensors'),
            device='cpu', pretrained_text=False, image_mean=(.5,.5,.5), image_std=(.5,.5,.5),
            image_resize_mode='squash', image_interpolation='bicubic')
        self.model.eval()
        self.tokenizer = HFTokenizer(str(root), context_length=64, clean='canonicalize', local_files_only=True)
        self._text_cache = {}

    def scores(self, images, labels):
        torch = self.torch
        prompts = [f'A photo of {description}.' for phrases in labels.values() for description in phrases]
        key = tuple(prompts)
        with torch.inference_mode():
            if key not in self._text_cache:
                features = self.model.encode_text(self.tokenizer(prompts), normalize=True)
                self._text_cache[key] = features.reshape(len(labels), -1, features.shape[-1]).mean(1)
                self._text_cache[key] = torch.nn.functional.normalize(self._text_cache[key], dim=-1)
            image_features = self.model.encode_image(torch.stack([self.preprocess(i) for i in images]), normalize=True)
            return (image_features @ self._text_cache[key].T).cpu().numpy()

    def recognize(self, front_png, back_png, front_mask, back_mask, profile, registry):
        images = [whole_garment(front_png,front_mask), whole_garment(back_png,back_mask)]
        family_scores = self.scores(images, FAMILIES)
        category, evidence = rank_categories(family_scores)
        available = {s['style']: s for s in registry if s['profile']==profile and s['category']==category}
        if not available:
            raise RecognitionError('This garment type has no matching model for your avatar.')
        # Identify style before restricting to this avatar's catalog.
        all_labels=dict(STYLES[category])
        if category=='trousers' and profile=='male_average':
            all_labels['ankle_sweats']=MALE_ANKLE_SWEATS
        observed_scores=self.scores(images,all_labels)
        observed_combined=.7*observed_scores[0]+.3*observed_scores[1]
        observed_style=list(all_labels)[int(observed_combined.argmax())]
        details={}
        tasks=({'hem':HEMS,'waist':WAIST} if category=='trousers' else
               {'fastening':FASTENING} if category in {'outerwear','long_sleeve_top'} else {})
        if category in {'trousers','shorts'}:tasks['pattern']=PATTERN
        if category=='trousers' and profile=='male_average':tasks['waistband']=WAISTBAND
        for part,vocabulary in tasks.items():
            front_details=[images[0]] if part=='pattern' else detail_views(front_png,front_mask,part)
            back_details=[images[1]] if part=='pattern' else detail_views(back_png,back_mask,part)
            # A missing/occluded view cannot act as negative evidence.
            if not front_details or not back_details:
                details[part]={'value':None,'reason':'insufficient_detail','calibrated':False}
            else:
                details[part]=agreed_detail(self.scores(front_details+back_details,vocabulary),vocabulary,minimum_margin=.02 if part=='pattern' else .012)
        blocked=compatible_styles(category,details,profile)
        labels={key:value for key,value in all_labels.items() if key in available and key not in blocked}
        if not labels:
            raise RecognitionError('The visible construction details do not match an installed model for this avatar. No contradictory substitute was saved.')
        combined=np.array([observed_combined[list(all_labels).index(k)] for k in labels])
        order=np.argsort(-combined)
        selected=list(labels)[int(order[0])]
        margin=float(combined[order[0]]-combined[order[1]]) if len(order)>1 else None
        catalog_approximate=observed_style not in available or observed_style in blocked
        return {'category':category, 'style':selected, 'source':'fashion_model',
            'model_version':VERSION, 'model_id':MODEL_ID, 'revision':REVISION,
            'score_type':'cosine_similarity_not_probability', 'calibrated':False,
            'family_evidence':evidence, 'style_scores':{key:round(float(combined[i]),6) for i,key in enumerate(labels)},
            'style_margin':None if margin is None else round(margin,6),
            'style_uncertain':catalog_approximate or (margin is not None and margin<.008),
            'observed_style':observed_style,'observed_style_available':observed_style in available,
            'template_is_approximate':catalog_approximate,'construction_details':details,
            'excluded_contradictory_styles':sorted(blocked),
            'front_sha256':hashlib.sha256(front_png).hexdigest(),
            'back_sha256':hashlib.sha256(back_png).hexdigest()}


@lru_cache(maxsize=1)
def get_recognizer():
    return FashionRecognizer()
