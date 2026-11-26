"""Recovery acceptance tests for the frozen hosted prototype."""

from __future__ import annotations

import io
import shutil
import sys
from pathlib import Path

import pytest
import torch
from fastapi.testclient import TestClient
from PIL import Image

ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT / "src"))

from tailor_ai.api.app import BASE_WARNINGS, app  # noqa: E402
from tailor_ai.digitization.assets import TemporaryAssetStore  # noqa: E402
from tailor_ai.digitization.pipeline import DigitizationPipeline  # noqa: E402
from tailor_ai.inference.runtime import (  # noqa: E402
    CLASSES,
    EXPECTED_HASH,
    THRESHOLD,
    UNSUPPORTED,
    InputError,
    TailorRuntime,
    sha256,
)
from tailor_ai.providers.segmentation.base import (  # noqa: E402
    GarmentSegmenter,
    SegmentationResult,
)

ARTIFACT = Path("C:/TextyleData/tailor/artifacts/runtime/tailor-prototype-v0.1/20260806-01")
KEY_FILE = Path("C:/TextyleData/tailor/secrets/tailor_api_key.txt")


def image_bytes(fmt: str = "PNG", size: tuple[int, int] = (224, 224)) -> bytes:
    stream = io.BytesIO()
    Image.new("RGB", size, (70, 110, 140)).save(stream, fmt)
    return stream.getvalue()


class ApiFakeSegmenter(GarmentSegmenter):
    def segment_prompted(self, image, correction):
        return self.segment(image)

    def segment(self, image: Image.Image) -> SegmentationResult:
        mask = torch.zeros((image.height, image.width), dtype=torch.bool).numpy()
        mask[35:-35, 35:-35] = True
        return SegmentationResult(mask, (35, 35, image.width - 35, image.height - 35),
                                  float(mask.mean()), 0.99, processor_version="fake-v1")


class ApiRejectingSegmenter(GarmentSegmenter):
    def segment(self, image: Image.Image) -> SegmentationResult:
        mask = torch.ones((image.height, image.width), dtype=torch.bool).numpy()
        return SegmentationResult(mask, (0, 0, image.width, image.height), 1.0, 0.99,
                                  processor_version="fake-reject-v1")


@pytest.fixture(scope="module")
def runtime() -> TailorRuntime:
    return TailorRuntime(ARTIFACT, "cpu")


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
    monkeypatch.setenv("TAILOR_RUNTIME_DIR", str(ARTIFACT))
    monkeypatch.setenv("TAILOR_API_KEY_FILE", str(KEY_FILE))
    monkeypatch.setenv("TAILOR_DEVICE", "cpu")
    with TestClient(app) as instance:
        store = TemporaryAssetStore(tmp_path / "digitization")
        instance.app.state.asset_store = store
        instance.app.state.digitizer = DigitizationPipeline(ApiFakeSegmenter(), store)
        yield instance


def test_frozen_artifact_identity_and_seven_logits(runtime: TailorRuntime) -> None:
    assert sha256(ARTIFACT / "best_model_state.pt") == EXPECTED_HASH
    assert runtime.config["class_order"] == list(CLASSES)
    assert THRESHOLD == 0.70 and UNSUPPORTED == ("sleeveless_top",)
    with torch.inference_mode():
        assert runtime.model(torch.zeros(1, 3, 224, 224)).shape == (1, 7)


def test_incorrect_checkpoint_hash_fails(tmp_path: Path) -> None:
    for path in ARTIFACT.iterdir():
        shutil.copy2(path, tmp_path / path.name)
    with (tmp_path / "best_model_state.pt").open("ab") as stream:
        stream.write(b"corrupt")
    with pytest.raises(RuntimeError, match="checkpoint verification"):
        TailorRuntime(tmp_path, "cpu")


@pytest.mark.parametrize("fmt", ["JPEG", "PNG", "WEBP"])
def test_allowed_image_formats(runtime: TailorRuntime, fmt: str) -> None:
    decoded = runtime.decode(image_bytes(fmt))
    assert decoded.tensor.shape == (3, 224, 224)


def test_upload_validation_and_quality_warnings(runtime: TailorRuntime) -> None:
    with pytest.raises(InputError, match="empty"):
        runtime.decode(b"")
    with pytest.raises(InputError, match="invalid"):
        runtime.decode(b"not an image")
    with pytest.raises(InputError, match="below"):
        runtime.decode(image_bytes(size=(95, 96)))
    assert "extreme_aspect_ratio" in runtime.decode(image_bytes(size=(900, 100))).warnings


def test_prediction_contract(runtime: TailorRuntime) -> None:
    result = runtime.predict(runtime.decode(image_bytes()))
    assert len(result["top_predictions"]) == 3
    confidences = [item["confidence"] for item in result["top_predictions"]]
    assert confidences == sorted(confidences, reverse=True)
    assert all(item["category"] in CLASSES for item in result["top_predictions"])
    assert result["category"] != "sleeveless_top"


def test_public_metadata_endpoints_and_browser(client: TestClient) -> None:
    assert client.get("/").status_code == 200
    assert "does not support sleeveless_top" in client.get("/").text
    assert client.get("/healthz").json() == {"status": "alive"}
    assert client.get("/readyz").json()["status"] == "ready"
    assert client.get("/api/v1/model").json()["threshold"] == THRESHOLD
    categories = client.get("/api/v1/categories").json()
    assert categories["supported_logits"] == list(CLASSES)
    assert categories["unsupported_categories"] == ["sleeveless_top"]
    assert client.get("/docs").status_code == 200
    assert client.get("/openapi.json").status_code == 200


def test_api_key_and_classification_contract(client: TestClient) -> None:
    files = {"front_image": ("synthetic.png", image_bytes(), "image/png")}
    assert client.post("/api/v1/clothing/classify", files=files).status_code == 401
    assert (
        client.post(
            "/api/v1/clothing/classify", files=files, headers={"X-API-Key": "invalid"}
        ).status_code
        == 401
    )
    key = KEY_FILE.read_text(encoding="utf-8").strip()
    response = client.post("/api/v1/clothing/classify", files=files, headers={"X-API-Key": key})
    assert response.status_code == 200
    body = response.json()
    assert set(BASE_WARNINGS).issubset(body["warnings"])
    assert body["prediction"]["threshold"] == THRESHOLD
    assert body["model"]["checkpoint_identity"].endswith(EXPECTED_HASH)
    assert body["capabilities"]["front_image_used"] is True


def test_back_warning_corrupt_and_duplicate_front(client: TestClient) -> None:
    key = KEY_FILE.read_text(encoding="utf-8").strip()
    headers = {"X-API-Key": key}
    image = image_bytes()
    response = client.post(
        "/api/v1/clothing/classify",
        files={
            "front_image": ("front.png", image, "image/png"),
            "back_image": ("back.png", image, "image/png"),
        },
        headers=headers,
    )
    assert "back_image_ignored_by_model_v0_1" in response.json()["warnings"]
    assert (
        client.post(
            "/api/v1/clothing/classify",
            files={"front_image": ("bad.png", b"bad", "image/png")},
            headers=headers,
        ).status_code
        == 422
    )
    duplicate = [
        ("front_image", ("a.png", image, "image/png")),
        ("front_image", ("b.png", image, "image/png")),
    ]
    assert (
        client.post("/api/v1/clothing/classify", files=duplicate, headers=headers).status_code
        == 400
    )


def test_digitization_auth_contract_assets_and_backward_compatibility(client: TestClient) -> None:
    files = {"front_image": ("synthetic.png", image_bytes(), "image/png")}
    assert client.post("/api/v1/clothing/digitize", files=files).status_code == 401
    key = KEY_FILE.read_text(encoding="utf-8").strip()
    response = client.post(
        "/api/v1/clothing/digitize", files=files, headers={"X-API-Key": key}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["readiness"]["candidate_ready"] is True
    assert body["readiness"]["segmentation_ready"] is False
    assert body["readiness"]["three_d_ready"] is False
    assert body["processor"]["segmentation_model"] == "sam2.1_tiny_provisional_primary"
    assert body["processor"]["representative_real_world_validation"] == "PENDING"
    normalized = body["assets"]["front"]["normalized"]
    assert "C:\\" not in str(body)
    asset = client.get(normalized["url"], headers={"X-API-Key": key})
    assert asset.status_code == 200 and asset.headers["content-type"] == "image/png"
    assert client.get(normalized["url"]).status_code == 401
    assert client.post("/api/v1/clothing/classify", files=files,
                       headers={"X-API-Key": key}).status_code == 200


def test_digitization_segmentation_failure_returns_partial_classification(client: TestClient) -> None:
    client.app.state.digitizer = DigitizationPipeline(
        ApiRejectingSegmenter(), client.app.state.asset_store
    )
    key = KEY_FILE.read_text(encoding="utf-8").strip()
    response = client.post(
        "/api/v1/clothing/digitize",
        files={"front_image": ("synthetic.png", image_bytes(), "image/png")},
        headers={"X-API-Key": key},
    )
    body = response.json()
    assert response.status_code == 200 and body["status"] == "partial"
    assert body["classification"]["top_predictions"]
    assert body["readiness"]["classification_ready"] is True
    assert body["readiness"]["segmentation_ready"] is False
    assert body["readiness"]["try_on_ready"] is False


def test_static_browser_has_no_secret_persistence_or_external_assets() -> None:
    javascript = (ROOT / "src/tailor_ai/static/app.js").read_text(encoding="utf-8")
    html = (ROOT / "src/tailor_ai/static/index.html").read_text(encoding="utf-8")
    combined = javascript + html
    assert "localStorage" not in combined and "sessionStorage" not in combined
    assert "TAILOR_API_KEY" not in combined
    assert "http://" not in combined and "https://" not in combined
    assert "POST /api/v1/clothing/classify" not in javascript
    assert 'fetch("/api/v1/clothing/classify"' in javascript


def test_local_flutter_web_cors_preflight(client: TestClient) -> None:
    response = client.options(
        "/api/v1/clothing/classify",
        headers={
            "Origin": "http://localhost:5000",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "X-API-Key,Content-Type",
        },
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5000"
    assert "X-API-Key" in response.headers["access-control-allow-headers"]


def test_unlisted_remote_origin_does_not_receive_cors_permission(client: TestClient) -> None:
    response = client.options(
        "/api/v1/clothing/classify",
        headers={
            "Origin": "https://unlisted.example",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert "access-control-allow-origin" not in response.headers


def test_correction_auth_identity_expired_assets_and_front_authority(client: TestClient, monkeypatch) -> None:
    import hashlib
    import json

    from tailor_ai.digitization.correction import SPACE
    data = image_bytes()
    fields = {'view': 'back', 'source_image_sha256': hashlib.sha256(data).hexdigest(),
              'prompts': json.dumps({'coordinate_space': SPACE, 'box': [.1, .1, .9, .9]})}
    files = {'image': ('source.png', data, 'image/png')}
    endpoint = '/api/v1/clothing/digitize/correct'
    assert client.post(endpoint, data=fields, files=files).status_code == 401
    # Ephemeral test credential: pytest assertion introspection must never expose
    # the live hosting credential in failure output.
    import secrets
    client.app.state.api_key = secrets.token_urlsafe(40)
    headers = {'X-API-Key': client.app.state.api_key}
    assert client.post(endpoint, data={**fields, 'source_image_sha256': '0' * 64}, files=files, headers=headers).status_code == 409
    assert client.post(endpoint, data={**fields, 'view': 'other'}, files=files, headers=headers).status_code == 422
    invalid_status = client.post(endpoint, data={**fields, 'prompts': '{}'}, files=files, headers=headers).status_code
    assert invalid_status == 422
    def no_classifier(*args):
        raise AssertionError('view correction must not classify the back or rerun the front')
    monkeypatch.setattr(client.app.state.runtime, 'predict', no_classifier)
    response = client.post(endpoint, data=fields, files=files, headers=headers)
    assert response.status_code == 200
    body = response.json()
    assert 'classification' not in body
    assert body['candidate']['view'] == 'back'
    assert body['candidate']['identity']['source_image_sha256'] == fields['source_image_sha256']
    assert not any(body['readiness'].values())
    # Correction uses original upload only: no expired-transfer dependency.
    client.app.state.asset_store.ttl_seconds = -1
    assert client.post(endpoint, data=fields, files=files, headers=headers).status_code == 200
    statuses = [client.post(endpoint, data=fields, files=files, headers=headers).status_code for _ in range(6)]
    assert 429 in statuses
