"""FastAPI application for the frozen Tailor prototype."""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import os
import time
import uuid
from collections import defaultdict, deque
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, File, Form, Header, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles

from tailor_ai.api.automatic_preview import register_automatic_preview
from tailor_ai.digitization.assets import TemporaryAssetStore
from tailor_ai.digitization.correction import Correction
from tailor_ai.digitization.images import prepare
from tailor_ai.digitization.pipeline import DigitizationPipeline
from tailor_ai.garment3d.generator import Garment3DError, digest, generator_for
from tailor_ai.garment3d.temporary import Temporary3DStore
from tailor_ai.inference.runtime import (
    CLASSES,
    THRESHOLD,
    InputError,
    TailorRuntime,
    from_environment,
)
from tailor_ai.providers.segmentation.sam2_tiny import Sam2TinySegmenter

STATIC = Path(__file__).parents[1] / "static"
LIMITATION = "Tailor baseline v0.1 does not support sleeveless_top."
BASE_WARNINGS = ["sleeveless_top_not_supported", "model_not_validated_on_textyle_camera_images"]


class Limiter:
    def __init__(self, operation: str = "classification", limit: int = 30) -> None:
        self.events: dict[str, deque[float]] = defaultdict(deque)
        self.operation = operation
        self.limit = limit

    def check(self, identity: str) -> None:
        now = time.monotonic()
        queue = self.events[identity]
        while queue and queue[0] < now - 60:
            queue.popleft()
        if len(queue) >= self.limit:
            raise HTTPException(429, f"{self.operation} rate limit exceeded")
        queue.append(now)


def key_file() -> Path:
    return Path(
        os.environ.get("TAILOR_API_KEY_FILE", "C:/TextyleData/tailor/secrets/tailor_api_key.txt")
    )


def load_key() -> str:
    value = key_file().read_text(encoding="utf-8").strip()
    if len(value) < 32:
        raise RuntimeError("API key file is missing or invalid")
    return value


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.runtime = from_environment()
    app.state.api_key = load_key()
    app.state.limiter = Limiter()
    app.state.digitization_limiter = Limiter("digitization", 10)
    app.state.semaphore = asyncio.Semaphore(1)
    app.state.digitizer_lock = asyncio.Lock()
    app.state.digitizer = None
    cache = Path(
        os.environ.get(
            "TAILOR_DIGITIZATION_CACHE", "C:/TextyleData/tailor/cache/digitization"
        )
    )
    app.state.asset_store = TemporaryAssetStore(cache)
    app.state.garment3d_store = Temporary3DStore()
    app.state.garment3d_limiter = Limiter("3D generation", 6)
    yield


def require_key(request: Request, supplied: str | None) -> None:
    if not supplied or not hmac.compare_digest(supplied, request.app.state.api_key):
        raise HTTPException(401, "missing or invalid API key")


async def get_digitizer(request: Request) -> DigitizationPipeline:
    if request.app.state.digitizer is None:
        async with request.app.state.digitizer_lock:
            if request.app.state.digitizer is None:
                runtime: TailorRuntime = request.app.state.runtime
                segmenter = await asyncio.to_thread(Sam2TinySegmenter, runtime.device)
                request.app.state.digitizer = DigitizationPipeline(
                    segmenter, request.app.state.asset_store
                )
    return request.app.state.digitizer


app = FastAPI(
    title="Tailor Prototype API", version="1.0", lifespan=lifespan, docs_url=None, redoc_url=None
)
configured_origins = [
    origin.strip()
    for origin in os.environ.get("TAILOR_CORS_ORIGINS", "").split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=configured_origins,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "X-API-Key", "X-Request-ID"],
)
app.mount("/static", StaticFiles(directory=STATIC), name="static")


@app.exception_handler(InputError)
async def input_error_response(request: Request, error: InputError) -> JSONResponse:
    return JSONResponse({"detail": str(error), "request_id": request.state.request_id}, status_code=error.status)


@app.middleware("http")
async def request_context(request: Request, call_next):
    request.state.request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    try:
        response = await call_next(request)
    except Exception:
        response = JSONResponse(
            {"detail": "safe internal failure", "request_id": request.state.request_id},
            status_code=500,
        )
    response.headers["X-Request-ID"] = request.state.request_id
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@app.get("/", include_in_schema=False)
def root() -> FileResponse:
    return FileResponse(STATIC / "index.html")


@app.get("/docs", include_in_schema=False)
def docs() -> FileResponse:
    """Serve dependency-free API documentation without an external CDN."""
    return FileResponse(STATIC / "docs.html")


@app.get("/healthz")
def health() -> dict:
    return {"status": "alive"}


@app.get("/readyz")
def ready(request: Request) -> dict:
    runtime: TailorRuntime = request.app.state.runtime
    if not runtime.ready:
        raise HTTPException(503, "model not ready")
    return {"status": "ready", "model_version": "0.1", "device": str(runtime.device)}


@app.get("/api/v1/model")
def model_info(request: Request) -> dict:
    runtime: TailorRuntime = request.app.state.runtime
    return {
        "name": "tailor-baseline",
        "version": "0.1",
        "architecture": "efficientnet_b0",
        "checkpoint_identity": "sha256:E3C6B4CD15207E917E712489561AC7415CEDA670ED7FCA399659753883120130",
        "threshold": THRESHOLD,
        "class_order": list(CLASSES),
        "supported_categories": list(CLASSES),
        "unsupported_categories": ["sleeveless_top"],
        "device": str(runtime.device),
        "preprocessing": "resize-256-bicubic-center-crop-224-imagenet-normalization",
        "limitations": [LIMITATION, "Not validated on Textyle-camera images."],
    }


@app.get("/api/v1/categories")
def categories() -> dict:
    return {
        "product_taxonomy": [
            "short_sleeve_top",
            "long_sleeve_top",
            "sleeveless_top",
            "outerwear",
            "shorts",
            "trousers",
            "skirt",
            "dress",
            "unknown",
        ],
        "supported_logits": list(CLASSES),
        "unsupported_categories": ["sleeveless_top"],
        "unknown_policy": "abstention outcome; not a trained logit",
        "limitations": [LIMITATION],
    }


@app.post("/api/v1/clothing/classify")
async def classify(
    request: Request,
    front_image: list[UploadFile] = File(...),
    back_image: UploadFile | None = File(None),
    source: str = Form("unknown"),
    client_request_id: str | None = Form(None),
    x_api_key: str | None = Header(None, alias="X-API-Key"),
) -> JSONResponse:
    started = time.perf_counter()
    require_key(request, x_api_key)
    if source not in {"mobile_camera", "closet_camera", "unknown"}:
        raise HTTPException(400, "invalid source")
    if client_request_id is not None and len(client_request_id) > 128:
        raise HTTPException(400, "client_request_id exceeds 128 characters")
    if len(front_image) != 1:
        raise HTTPException(400, "exactly one front_image is required")
    request.app.state.limiter.check(hash(x_api_key))
    runtime: TailorRuntime = request.app.state.runtime
    try:
        data = await front_image[0].read(10 * 1024 * 1024 + 1)
        decoded_started = time.perf_counter()
        decoded = runtime.decode(data)
        preprocessing_ms = (time.perf_counter() - decoded_started) * 1000
        warnings = list(BASE_WARNINGS)
        if back_image is not None:
            back_data = await back_image.read(10 * 1024 * 1024 + 1)
            runtime.decode(back_data)
            warnings.append("back_image_ignored_by_model_v0_1")
        try:
            await asyncio.wait_for(request.app.state.semaphore.acquire(), timeout=0.1)
        except TimeoutError as exc:
            raise HTTPException(503, "inference busy") from exc
        try:
            result = await asyncio.to_thread(runtime.predict, decoded)
        finally:
            request.app.state.semaphore.release()
    except InputError as exc:
        raise HTTPException(exc.status, str(exc)) from exc
    warnings.extend(result["warnings"])
    payload = {
        "request_id": request.state.request_id,
        "api_version": "v1",
        "status": "abstained" if result["abstained"] else "predicted",
        "prediction": {
            "category": result["category"],
            "confidence": result["confidence"],
            "abstained": result["abstained"],
            "threshold": THRESHOLD,
            "top_predictions": result["top_predictions"],
        },
        "derived_attributes": {
            "sleeve_type": result["sleeve_type"],
            "sleeve_source": "derived_from_category",
        },
        "model": {
            "name": "tailor-baseline",
            "version": "0.1",
            "architecture": "efficientnet_b0",
            "checkpoint_identity": "sha256:E3C6B4CD15207E917E712489561AC7415CEDA670ED7FCA399659753883120130",
            "device": str(runtime.device),
        },
        "capabilities": {
            "supported_categories": list(CLASSES),
            "unsupported_categories": ["sleeveless_top"],
            "front_image_used": True,
            "back_image_supported": False,
        },
        "warnings": list(dict.fromkeys(warnings)),
        "timing": {
            "preprocessing_ms": preprocessing_ms,
            "inference_ms": result["inference_ms"],
            "total_request_ms": (time.perf_counter() - started) * 1000,
        },
    }
    return JSONResponse(payload)


@app.get("/api/v1/digitization/assets/{asset_id}")
def digitization_asset(
    request: Request,
    asset_id: str,
    x_api_key: str | None = Header(None, alias="X-API-Key"),
) -> FileResponse:
    require_key(request, x_api_key)
    path = request.app.state.asset_store.get(asset_id)
    if path is None:
        raise HTTPException(404, "asset unavailable or expired")
    return FileResponse(path, media_type="image/png", filename=asset_id)


@app.post("/api/v1/clothing/3d/generate")
async def generate_garment_3d(
    request: Request,
    source_image: UploadFile = File(...),
    front_normalized: UploadFile = File(...),
    front_mask: UploadFile = File(...),
    category: str = Form(...),
    garment_id: str = Form(...),
    approval_json: str = Form(...),
    x_api_key: str | None = Header(None, alias="X-API-Key"),
) -> JSONResponse:
    require_key(request, x_api_key)
    request.app.state.garment3d_limiter.check(hash(x_api_key))
    try:
        generator = generator_for(category)
    except Garment3DError as exc:
        return JSONResponse({"status": exc.code, "detail": str(exc)}, status_code=422)
    try:
        approval = json.loads(approval_json)
        if not isinstance(approval, dict) or len(approval_json) > 16384:
            raise ValueError
    except ValueError as exc:
        raise HTTPException(422, "invalid approval record") from exc
    source, front, mask = await asyncio.gather(*(
        upload.read(10 * 1024 * 1024 + 1)
        for upload in (source_image, front_normalized, front_mask)
    ))
    try:
        result = await asyncio.to_thread(
            generator.generate, garment_id, category, source, front, mask, approval
        )
    except Garment3DError as exc:
        status = 409 if exc.code == "approval_mismatch" else 422
        return JSONResponse({"status": exc.code, "detail": str(exc)}, status_code=status)
    sidecar = json.dumps(result.sidecar, sort_keys=True, separators=(",", ":")).encode()
    asset_id = request.app.state.garment3d_store.put(result.glb, sidecar)
    base = f"/api/v1/clothing/3d/assets/{asset_id}"
    return JSONResponse({
        "status": "ready", "category": category,
        "asset_fingerprint": result.sidecar["asset_fingerprint"],
        "generator_version": result.sidecar["versions"]["generator"],
        "template_version": result.sidecar["versions"]["template"],
        "canonicalization_version": result.sidecar["versions"]["canonicalizer"],
        "validation": {"status": "passed", "mesh": result.sidecar["mesh"],
                       "boundary_loops": result.sidecar["boundary_loops"]},
        "glb": {"url": f"{base}/glb", "sha256": digest(result.glb),
                "content_type": "model/gltf-binary", "bytes": len(result.glb)},
        "sidecar": {"url": f"{base}/sidecar", "sha256": digest(sidecar),
                    "content_type": "application/json", "bytes": len(sidecar)},
        "expires_in_seconds": request.app.state.garment3d_store.ttl_seconds,
        "warnings": ["normalized_scale_not_measured", "template_derived_back", "no_avatar_fit"],
        "timing_ms": result.sidecar["timing_ms"],
    })


@app.get("/api/v1/clothing/3d/assets/{asset_id}/{kind}")
def garment_3d_temporary_asset(
    request: Request, asset_id: str, kind: str,
    x_api_key: str | None = Header(None, alias="X-API-Key"),
) -> Response:
    require_key(request, x_api_key)
    data = request.app.state.garment3d_store.get(asset_id, kind)
    if data is None:
        raise HTTPException(404, "asset unavailable or expired")
    return Response(data, media_type="model/gltf-binary" if kind == "glb" else "application/json")


@app.post("/api/v1/clothing/digitize")
async def digitize(
    request: Request,
    front_image: list[UploadFile] = File(...),
    back_image: UploadFile | None = File(None),
    source: str = Form("unknown"),
    client_request_id: str | None = Form(None),
    x_api_key: str | None = Header(None, alias="X-API-Key"),
) -> JSONResponse:
    started = time.perf_counter()
    require_key(request, x_api_key)
    if source not in {"mobile_camera", "closet_camera", "unknown"}:
        raise HTTPException(400, "invalid source")
    if client_request_id is not None and len(client_request_id) > 128:
        raise HTTPException(400, "client_request_id exceeds 128 characters")
    if len(front_image) != 1:
        raise HTTPException(400, "exactly one front_image is required")
    request.app.state.digitization_limiter.check(hash(x_api_key))
    runtime: TailorRuntime = request.app.state.runtime
    front_data = await front_image[0].read(10 * 1024 * 1024 + 1)
    back_data = await back_image.read(10 * 1024 * 1024 + 1) if back_image else None
    try:
        await asyncio.wait_for(request.app.state.semaphore.acquire(), timeout=0.1)
    except TimeoutError as exc:
        raise HTTPException(503, "inference busy") from exc
    try:
        # Serialize bounded decode as well as inference to limit request memory.
        front_prepared = await asyncio.to_thread(prepare, front_data)
        back_prepared = await asyncio.to_thread(prepare, back_data) if back_data is not None else None
        front_validated = await asyncio.to_thread(runtime.decode, front_prepared.classifier_data)
        if back_prepared is not None:
            await asyncio.to_thread(runtime.decode, back_prepared.classifier_data)
        classification = await asyncio.to_thread(runtime.predict, front_validated)
        digitizer = await get_digitizer(request)
        try:
            result = await asyncio.to_thread(
                digitizer.process, front_prepared, back_prepared, classification
            )
        except Exception:
            result = {
                "status": "partial",
                "segmentation": {"front": {"status": "failed", "warnings": ["segmentation_failed"]}, "back": None},
                "attributes": {"primary_color": None, "back_color": None,
                               "pattern": {"value": "unknown", "source": "unknown", "confidence": None,
                                           "user_confirmed": False, "analysis_version": "pattern-abstention-v1"},
                               "suggested_seasons": [], "season_source": "system_default",
                               "layer_role": "unknown"},
                "assets": {"front": {}, "back": None},
                "identity": {"asset_version": "1", "front": None, "back": None},
                "readiness": {"classification_ready": True, "segmentation_ready": False,
                              "try_on_ready": False, "three_d_ready": False},
                "warnings": ["segmentation_failed"],
                "processor": {"digitization_version": "tailor-digitization-v0.1",
                              "segmentation_model": "sam2.1_tiny_provisional_primary",
                              "representative_real_world_validation": "PENDING"},
                "timing": {},
            }
    finally:
        request.app.state.semaphore.release()
    classification_payload = {
        "category": classification["category"], "confidence": classification["confidence"],
        "abstained": classification["abstained"], "threshold": THRESHOLD,
        "top_predictions": classification["top_predictions"],
        "sleeve_type": classification["sleeve_type"], "model_version": "0.1",
    }
    payload = {"request_id": request.state.request_id, "api_version": "v1",
               "status": result.pop("status"), "classification": classification_payload, **result}
    payload["timing"]["classification_ms"] = classification["inference_ms"]
    payload["timing"]["total_ms"] = (time.perf_counter() - started) * 1000
    return JSONResponse(payload)


@app.post("/api/v1/clothing/digitize/correct")
async def correct_view(
    request: Request,
    image: UploadFile = File(...),
    view: str = Form(...),
    source_image_sha256: str = Form(...),
    prompts: str = Form(...),
    x_api_key: str | None = Header(None, alias="X-API-Key"),
) -> JSONResponse:
    require_key(request, x_api_key)
    request.app.state.digitization_limiter.check(hash(x_api_key))
    if view not in {"front", "back"}:
        raise HTTPException(422, "view must be front or back")
    correction = Correction.parse(prompts)
    data = await image.read(10 * 1024 * 1024 + 1)
    if len(data) > 10 * 1024 * 1024:
        raise InputError("image exceeds 10 MiB", 413)
    if (len(source_image_sha256) != 64 or any(c not in "0123456789abcdef" for c in source_image_sha256)
            or not hmac.compare_digest(hashlib.sha256(data).hexdigest(), source_image_sha256)):
        raise HTTPException(409, "correction source identity mismatch")
    try:
        await asyncio.wait_for(request.app.state.semaphore.acquire(), timeout=0.1)
    except TimeoutError as exc:
        raise HTTPException(503, "inference busy") from exc
    try:
        prepared = await asyncio.to_thread(prepare, data)
        correction.pixels(*prepared.image.size)
        digitizer = await get_digitizer(request)
        result = await asyncio.to_thread(digitizer.process_view, prepared, view, correction)
    finally:
        request.app.state.semaphore.release()
    # View-only correction never reuses or redefines classification. The client
    # must keep its original front classification bound to that source digest.
    return JSONResponse({"request_id": request.state.request_id, "api_version": "v1",
                         "status": "review_required" if result["segmentation"]["candidate_accepted"] else "partial",
                         "candidate": result,
                         "readiness": {"segmentation_ready": False, "try_on_ready": False, "three_d_ready": False}})


# Automatic photo projection is separate from reviewed M11 generation.
register_automatic_preview(app, require_key=require_key, get_digitizer=get_digitizer)
