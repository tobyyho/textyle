# Tailor API v1

**Validated:** 2026-09-12  
**Prototype model:** Tailor baseline v0.1

## Endpoints

| Method | Path | Authentication | Purpose |
|---|---|---|---|
| GET | `/` | none | Browser prototype |
| GET | `/healthz` | none | Process liveness |
| GET | `/readyz` | none | Loaded-model readiness |
| GET | `/api/v1/model` | none | Frozen model metadata |
| GET | `/api/v1/categories` | none | Product and model category support |
| GET | `/docs` | none | Dependency-free API reference |
| GET | `/openapi.json` | none | Machine-readable OpenAPI document |
| POST | `/api/v1/clothing/classify` | `X-API-Key` | Classify one garment image |

## Classification request

Send `multipart/form-data` with exactly one `front_image` (required), one
`back_image` (optional), `source` (`mobile_camera`, `closet_camera`, or `unknown`),
and optional `client_request_id` of at most 128 characters. JPEG, PNG, and WebP are
accepted. Each image is limited to 10 MiB, 25 million decoded pixels, and at least
96 pixels on each axis.

The v0.1 model uses only the front image. A valid back image is accepted and
reported with `back_image_ignored_by_model_v0_1`.

## Response contract

A successful response contains `request_id`, `api_version`, `status`, `prediction`,
`derived_attributes`, `model`, `capabilities`, `warnings`, and `timing`.
`prediction.top_predictions` contains the three highest supported logits. A maximum
confidence below 0.70 produces category `unknown` and status `abstained`.

Model logits, in order, are `short_sleeve_top`, `long_sleeve_top`, `outerwear`,
`shorts`, `trousers`, `skirt`, and `dress`. `sleeveless_top` is part of the product
taxonomy but is unsupported by baseline v0.1.

## Status codes

- `200`: success.
- `400`: invalid source, request identifier, or front-image multiplicity.
- `401`: missing or invalid API key.
- `413`: encoded image exceeds 10 MiB.
- `415`: unsupported decoded image format.
- `422`: empty, corrupt, unsafe, too-small, or otherwise invalid image.
- `429`: more than 30 classification requests per minute for the API-key identity.
- `503`: model unavailable or single-inference slot busy.

All responses include `X-Request-ID`, `Cache-Control: no-store`, and
`X-Content-Type-Options: nosniff`.

## Browser integration

Local Flutter web origins matching `localhost` or `127.0.0.1` are permitted for
development. Other browser origins must be explicitly listed in the host environment
variable `TAILOR_CORS_ORIGINS` as a comma-separated set of exact origins. Wildcard
origins and credentialed CORS are not enabled.
