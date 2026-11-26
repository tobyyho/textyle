"""Prompt validation, coordinates and conservative approval contract."""
import hashlib
import json

import pytest
from test_digitization import FakeSegmenter, fixture

from tailor_ai.digitization.assets import TemporaryAssetStore
from tailor_ai.digitization.correction import SPACE, Correction
from tailor_ai.digitization.pipeline import DigitizationPipeline
from tailor_ai.inference.runtime import InputError


def prompt(**kwargs):
    return json.dumps({"coordinate_space": SPACE, **kwargs})


@pytest.mark.parametrize("box,points", [
    ([.1, .2, .8, .9], []),
    (None, [{"x": .5, "y": .5, "label": 1}]),
    ([0, 0, 1, 1], [{"x": .2, "y": .3, "label": 0}]),
    ([0, 0, 1, 1], [{"x": .5, "y": .5, "label": 1}, {"x": .1, "y": .1, "label": 0}]),
])
def test_prompt_roundtrip_and_extreme_aspect_coordinates(box, points):
    result = Correction.parse(prompt(box=box, points=points))
    assert Correction.parse(json.dumps(result.to_dict())) == result
    for width, height in [(96, 4096), (4096, 96), (1024, 1024)]:
        pixel_box, pixel_points, labels = result.pixels(width, height)
        if box:
            assert pixel_box == [v * (width - 1 if i % 2 == 0 else height - 1) for i, v in enumerate(box)]
        assert labels == [p['label'] for p in points]
        assert all(0 <= x < width and 0 <= y < height for x, y in pixel_points)


@pytest.mark.parametrize("value", [
    '{}', '[]', 'null', '{broken', prompt(), prompt(points=[]),
    prompt(box=[.5, .5, .1, .1]), prompt(box=[0, 0, 0, 1]),
    prompt(box=[-1, 0, 1, 1]), prompt(box=[0, 0, 2, 1]),
    prompt(box=[0, 0, float('nan'), 1]), prompt(box=[False, 0, 1, 1]),
    prompt(points=[{'x': .1, 'y': .2, 'label': 0}]),
    prompt(points=[{'x': .1, 'y': .2, 'label': True}]),
    prompt(points=[{'x': .1, 'y': .2, 'label': 1}] * 21),
    prompt(points=[{'x': .1, 'y': .2, 'label': 1}, {'x': .1, 'y': .2, 'label': 0}]),
    json.dumps({'coordinate_space': 'raw_unoriented_pixels', 'box': [0, 0, 1, 1]}),
])
def test_invalid_prompts(value):
    with pytest.raises(InputError):
        Correction.parse(value)


def test_tiny_box_rejected():
    with pytest.raises(InputError):
        Correction.parse(prompt(box=[0, 0, .0001, .0001])).pixels(1024, 1024)


def test_prompted_view_bound_provenance_and_no_approval(tmp_path):
    class Prompted(FakeSegmenter):
        def segment_prompted(self, image, correction):
            assert correction.box
            return self.segment(image)
    _, mask, data = fixture()
    pipeline = DigitizationPipeline(Prompted(mask), TemporaryAssetStore(tmp_path))
    correction = Correction.parse(prompt(box=[.05, .05, .95, .95]))
    result = pipeline.process_view(data, 'back', correction)
    assert result['view'] == 'back'
    assert result['identity']['source_image_sha256'] == hashlib.sha256(data).hexdigest()
    assert result['identity']['correction'] == correction.to_dict()
    assert not result['identity']['user_approved']
    assert result['segmentation']['candidate_accepted']
    assert 'visual_review_required' in result['segmentation']['warnings']
    for kind, asset in result['preview_assets'].items():
        assert hashlib.sha256(pipeline.assets.get(asset['id']).read_bytes()).hexdigest() == asset['sha256'], kind
