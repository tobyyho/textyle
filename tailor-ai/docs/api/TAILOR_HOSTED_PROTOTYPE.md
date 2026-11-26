# Tailor Hosted Prototype

The hosted prototype serves a browser demonstration and API from one FastAPI origin
on the existing Windows development computer. Uvicorn listens on
`127.0.0.1:8000` with one worker. Tailscale Funnel publishes only that origin at
`https://tailor-server.tail857b40.ts.net/` over HTTPS 443.

At startup, Tailor verifies the frozen checkpoint SHA-256, class mapping, threshold,
and a seven-logit smoke inference before reporting ready. `TAILOR_DEVICE=auto` uses
the RTX 5080 CUDA device when available and otherwise falls back to CPU.

The runtime package is
`C:\TextyleData\tailor\artifacts\runtime\tailor-prototype-v0.1\20260806-01`.
The active checkpoint identity is
`E3C6B4CD15207E917E712489561AC7415CEDA670ED7FCA399659753883120130`.

This is a manually operated, zero-application-cost capstone prototype. It is offline
when the PC sleeps, loses power/network, Tailscale is unavailable, or the API process
is stopped. It is not a production service and has no availability guarantee.
