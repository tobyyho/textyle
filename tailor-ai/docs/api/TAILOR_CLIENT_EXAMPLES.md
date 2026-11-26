# Tailor API v1 Client Examples

Use the actual key locally; the placeholders below are intentional. Never commit a
key or ship the shared prototype key in a public application build.

## curl

```powershell
curl.exe -X POST "https://tailor-server.tail857b40.ts.net/api/v1/clothing/classify" `
  -H "X-API-Key: YOUR_KEY" `
  -F "front_image=@C:\path\garment.jpg" `
  -F "source=mobile_camera"
```

## PowerShell

```powershell
$headers = @{ 'X-API-Key' = 'YOUR_KEY' }
$form = @{ front_image = Get-Item 'C:\path\garment.jpg'; source = 'mobile_camera' }
Invoke-RestMethod -Method Post -Uri 'https://tailor-server.tail857b40.ts.net/api/v1/clothing/classify' -Headers $headers -Form $form
```

## Python

```python
import requests

with open("garment.jpg", "rb") as image:
    response = requests.post(
        "https://tailor-server.tail857b40.ts.net/api/v1/clothing/classify",
        headers={"X-API-Key": "YOUR_KEY"},
        files={"front_image": ("garment.jpg", image, "image/jpeg")},
        data={"source": "mobile_camera"},
        timeout=30,
    )
response.raise_for_status()
print(response.json())
```

## Browser JavaScript

```javascript
const data = new FormData();
data.append("front_image", fileInput.files[0]);
data.append("source", "mobile_camera");
const response = await fetch("/api/v1/clothing/classify", {
  method: "POST",
  headers: { "X-API-Key": apiKey },
  body: data,
});
const result = await response.json();
```

For Flutter integration, do not embed the shared prototype key in a release build.
Milestone 7 should define secure configuration and the canonical client schema before
Textyle code changes.
