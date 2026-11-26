# Tailor Web Demo

Open `https://tailor-server.tail857b40.ts.net/`, enter the private API key locally,
choose one front garment image, optionally choose a back image, select the capture
source, and choose **Classify garment**.

The result displays the category, confidence, abstention status, top-three model
predictions, derived sleeve value, and warnings. The correction selector lets a user
confirm or correct the displayed category locally; corrections are not submitted,
stored, or used for training. **Reset** reloads the page and clears the API key,
files, previews, and result.

The page visibly warns that baseline v0.1 does not support `sleeveless_top`. It uses
same-origin HTML, CSS, and JavaScript only, with no external CDN dependency. Uploaded
images are processed transiently and are not intentionally persisted by Tailor.

Use ordinary non-sensitive garment photographs. The result is research-prototype
output and should always be reviewed.
