# Tailor API v1 Security

## Implemented prototype controls

- Classification requires a constant-time compared `X-API-Key` value.
- The key is held outside the repository at
  `C:\TextyleData\tailor\secrets\tailor_api_key.txt` and is not embedded in the web
  page, JavaScript, logs, OpenAPI document, or examples.
- The Windows key file is intended to allow only the current user and `SYSTEM`.
- Tailor binds only to `127.0.0.1:8000`; Tailscale Funnel exposes HTTPS 443 and
  proxies only to that loopback origin.
- Uploads are decoded and inferred in memory. Tailor has no upload directory,
  database, object bucket, analytics, or training-capture path.
- Image size, pixel count, format, dimensions, decompression-bomb behavior, source,
  and request-ID length are bounded.
- One inference executes at a time and classification is limited to 30 requests per
  minute per API-key identity.
- Client-facing 500 responses are generic and carry a request identifier.
- Cross-origin browser access is limited to loopback development origins and exact
  origins configured through `TAILOR_CORS_ORIGINS`; wildcard origins are not used.

## Key handling

Display the key only on the host with `scripts\hosting\show_tailor_api_key.ps1`.
Never paste it into chat, source control, screenshots, documentation, or a client
build. The browser keeps the entered value only in the page's current memory;
refresh/reset clears it.

Rotate with `scripts\hosting\rotate_tailor_api_key.ps1`, then restart Tailor. Rotation
immediately invalidates the previous value after restart. Do not rotate during an
active external test.

## Prototype limitations

One shared static key is not user authentication, authorization, audit logging, or
abuse-resistant production security. Public health and metadata endpoints disclose
prototype status. The in-memory limiter resets with the process and is unsuitable
for distributed hosting. The system has no malware scanning, WAF, secret manager,
revocation service, or uptime monitoring. Use only non-sensitive garment photos.
