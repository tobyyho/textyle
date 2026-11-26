"""M10 category, integrity, topology, export and HTTP transfer contracts."""

from __future__ import annotations

import io
import json
from pathlib import Path

import pytest
import trimesh
from fastapi.testclient import TestClient

from tailor_ai.api.app import Limiter, app
from tailor_ai.garment3d.generator import (
    Garment3DError,
    _approval_fingerprint,
    digest,
    generator_for,
    validate_approval,
)
from tailor_ai.garment3d.temporary import Temporary3DStore

APPROVAL = Path(r"C:\Textyle\output\evaluations\m9-triposr-local-20261002\approved-input-gate\approval_record.json")


@pytest.fixture(scope="module")
def approved_input():
    if not APPROVAL.exists():
        pytest.skip("approved local M9 input not on this host")
    record = json.loads(APPROVAL.read_text(encoding="utf-8"))
    assert record["approved_for_m9_input"] is True
    files = [Path(record[key]) for key in ("source_path", "normalized_front_path", "front_mask_path")]
    if not all(path.exists() for path in files):
        pytest.skip("approved local image files not on this host")
    source, front, mask = [path.read_bytes() for path in files]
    assert digest(source).upper() == record["source_sha256"]
    assert digest(front).upper() == record["normalized_front_sha256"]
    assert digest(mask).upper() == record["front_mask_sha256"]
    identity = {"source_image_sha256": digest(source),
                "normalized_image_sha256": digest(front), "mask_sha256": digest(mask),
                "processor_version": "sam2.1-tiny-provisional-primary-box-consensus-v4",
                "m10_reference_approval": record["candidate_id"]}
    approval = {"view": "front", "candidate_accepted": True, "user_approved": True,
                "identity": identity, "approval_fingerprint": _approval_fingerprint(identity)}
    return source, front, mask, approval


def test_registry_unsupported_and_approval_integrity(approved_input):
    with pytest.raises(Garment3DError, match="not available"):
        generator_for("trousers")
    source, front, mask, approval = approved_input
    assert validate_approval(source, front, mask, approval)["mask_sha256"] == digest(mask)
    with pytest.raises(Garment3DError) as mismatch:
        validate_approval(source, front + b"changed", mask, approval)
    assert mismatch.value.code == "approval_mismatch"
    with pytest.raises(Garment3DError):
        validate_approval(source, front, mask, {**approval, "user_approved": False})


def test_reference_generation_reproducible_and_open(approved_input):
    source, front, mask, approval = approved_input
    kwargs = dict(garment_id="test-reference", category="long_sleeve_top",
                  source=source, front=front, mask=mask, approval=approval)
    first = generator_for("long_sleeve_top").generate(**kwargs)
    second = generator_for("long_sleeve_top").generate(**kwargs)
    assert first.glb == second.glb
    assert first.sidecar["asset_fingerprint"] == second.sidecar["asset_fingerprint"]
    assert set(first.sidecar["boundary_loops"]) == {"neck", "left_cuff", "right_cuff", "hem"}
    assert first.sidecar["mesh"]["silhouette_control_iou"] >= 0.90
    assert first.sidecar["mesh"]["nonmanifold_edges"] == 0
    assert first.sidecar["scale_provenance"] == "normalized_template_not_measured_meters"
    scene = trimesh.load(io.BytesIO(first.glb), file_type="glb", force="scene")
    assert set(scene.geometry) == {"garment_front", "garment_back", "garment_seams"}


def test_temporary_store_expires_and_rejects_paths():
    store = Temporary3DStore(ttl_seconds=100)
    asset_id = store.put(b"glb", b"{}")
    assert store.get(asset_id, "glb") == b"glb"
    assert store.get(asset_id, "sidecar") == b"{}"
    assert store.get("../" + asset_id, "glb") is None
    store.ttl_seconds = -1
    assert store.get(asset_id, "glb") is None


def test_http_auth_generation_retrieval_and_unsupported(approved_input):
    source, front, mask, approval = approved_input
    app.state.api_key = "test-key-never-production"
    app.state.garment3d_limiter = Limiter("3D test", 20)
    app.state.garment3d_store = Temporary3DStore()
    data = {"category": "long_sleeve_top", "garment_id": "test-item",
            "approval_json": json.dumps(approval)}
    def files():
        return {"source_image": ("source.jpg", source, "image/jpeg"),
                "front_normalized": ("front.png", front, "image/png"),
                "front_mask": ("mask.png", mask, "image/png")}
    client = TestClient(app)
    assert client.post("/api/v1/clothing/3d/generate", data=data, files=files()).status_code == 401
    headers = {"X-API-Key": "test-key-never-production"}
    unsupported = client.post("/api/v1/clothing/3d/generate", headers=headers,
                              data={**data, "category": "trousers"}, files=files())
    assert unsupported.status_code == 422
    assert unsupported.json()["status"] == "unsupported_category"
    response = client.post("/api/v1/clothing/3d/generate", headers=headers,
                           data=data, files=files())
    assert response.status_code == 200, response.text
    result = response.json()
    assert result["status"] == "ready"
    for kind in ("glb", "sidecar"):
        ref = result[kind]
        assert client.get(ref["url"]).status_code == 401
        fetched = client.get(ref["url"], headers=headers)
        assert fetched.status_code == 200
        assert digest(fetched.content) == ref["sha256"]
    assert client.get("/api/v1/clothing/3d/assets/../../etc/glb", headers=headers).status_code != 200
