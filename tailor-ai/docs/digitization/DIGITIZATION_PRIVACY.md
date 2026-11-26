# Digitization Privacy and Retention

Garment inference stays between Textyle and Tailor on the user's host. No image is sent to an external AI service.

Tailor handles uploaded image bytes in memory. It writes only processed normalized PNGs and masks under `C:\TextyleData\tailor\cache\digitization` for authenticated transfer. Opaque files expire after 15 minutes and old files are removed at store startup/access cleanup. Original uploads are not intentionally retained by Tailor.

Textyle stores original front/back images, normalized front/back images, and masks in same-origin IndexedDB under `textyle.garment-media.v1`. Wardrobe JSON stores only stable `indexeddb://` references and metadata. Browser quotas, private-browsing policy, site-data clearing, and origin changes can remove or isolate these assets. This is prototype-local durable storage, not backup or device synchronization.

Tailor does not intentionally log image bytes, masks, API keys, or full user paths.

