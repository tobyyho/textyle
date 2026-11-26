# Tailor Prototype v0.1 Remote Test Report

**Host-side public test date:** 2026-09-12  
**Public URL:** `https://tailor-server.tail857b40.ts.net/`

## Host-side public acceptance

The public root, health, readiness, model, categories, docs, authorized
classification, corrupt-image rejection, and optional-back warning passed through
the public HTTPS hostname. An unauthenticated classification returned 401. Funnel
reported HTTPS 443 mapped only to `http://127.0.0.1:8000`.

During the stability test, stopping Tailor caused the unchanged public health URL to
return 502. After starting Tailor, the same hostname passed all remote acceptance
checks. Initial URL and URL after restart were identical.

## External-device browser acceptance

| Field | Result |
|---|---|
| Device type | iPhone 14 Max |
| Browser | OperaGX |
| Network type | Cellular data |
| Pass/fail | Pass |
| Timestamp | 2026-09-12 18:45 EDT |

The user confirmed that the external-device browser acceptance passed from cellular
data. The test covered page load, the visible sleeveless warning, local API-key
entry, classification, top-three display, manual correction, and API-key clearing on
refresh. The API key itself was not recorded.
