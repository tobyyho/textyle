# Tailor Prototype v0.1 Limitations

- `sleeveless_top` is unsupported; the seven-logit model may confidently map a
  sleeveless garment to a supported category.
- `unknown` is a confidence-policy abstention, not a trained class or OOD detector.
- The 0.70 threshold was selected on Fashionpedia validation data and has not been
  validated on Textyle mobile/closet-camera images.
- The model is front-only. A back image is validated but ignored.
- No colour, pattern, season, segmentation, person-worn-garment, 3D, or virtual
  try-on behavior is implemented.
- Fashionpedia domain, crop framing, and image rights do not guarantee performance
  or deployment rights for new images.
- One shared API key, in-memory limiting, one worker, and one inference slot are
  prototype controls, not multi-user production security or scalability.
- Hosting depends on one Windows PC, home power/network, the Tailor process, and a
  beta Tailscale Funnel service. There is no uptime SLA or failover.
- Manual corrections in the browser are local UI state and are not persisted.
- Public metadata/health routes are unauthenticated. Classification images should
  be non-sensitive and are not intentionally saved, but transport/service operators
  remain part of the data path.
