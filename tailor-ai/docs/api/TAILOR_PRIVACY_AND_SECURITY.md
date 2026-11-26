# Tailor Privacy and Security

This integration-specific record complements `TAILOR_API_V1_SECURITY.md`.

Textyle sends the selected front image, optional back image, source value, and an
optional client request ID to the configured Tailor origin over HTTPS. Tailor
processes uploads in memory and intentionally writes no uploaded image, correction,
or inference request to disk, a database, analytics, or training data.

Classification requires `X-API-Key`. The host key remains outside both repositories.
Textyle receives it only through local build configuration. This reduces accidental
source disclosure but does not make a key embedded in a distributed client secret.

Loopback Flutter web origins are allowed for development. Other browser origins are
denied unless explicitly listed through `TAILOR_CORS_ORIGINS`. No external AI
provider receives images in Milestone 7, and no new telemetry was added.
