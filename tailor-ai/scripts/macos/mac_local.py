"""Local macOS launch/configuration. Does not reuse Windows secrets or wheels."""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import secrets
import sys
import time
import urllib.request

PROJECT = Path(__file__).resolve().parents[2]
BUNDLE = PROJECT.parent
SOURCE = PROJECT / 'src'
ARTIFACTS = BUNDLE / 'classifier-runtime'
sys.path.insert(0, str(SOURCE))
EXPECTED_HASH = 'E3C6B4CD15207E917E712489561AC7415CEDA670ED7FCA399659753883120130'


def model_settings() -> tuple[str, str]:
    tree = ast.parse((SOURCE / 'tailor_ai/providers/segmentation/sam2_tiny.py').read_text())
    values = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Constant):
            for target in node.targets:
                if isinstance(target, ast.Name):
                    values[target.id] = node.value.value
    return values['MODEL_ID'], values['MODEL_REVISION']


def data_root() -> Path:
    configured = os.environ.get('TAILOR_MAC_DATA_ROOT')
    return Path(configured).expanduser() if configured else Path.home() / 'Library/Application Support/textyle-tailor'


def configure() -> dict[str, Path]:
    root = data_root()
    locations = {'root': root, 'key': root / 'secrets/local_api_key.txt',
                 'cache': root / 'cache/huggingface/hub', 'digitization': root / 'cache/digitization'}
    locations['key'].parent.mkdir(parents=True, exist_ok=True)
    locations['cache'].mkdir(parents=True, exist_ok=True)
    locations['digitization'].mkdir(parents=True, exist_ok=True)
    if not locations['key'].exists():
        try:
            descriptor = os.open(locations['key'], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            pass
        else:
            with os.fdopen(descriptor, 'w') as stream:
                stream.write(secrets.token_urlsafe(36) + '\n')
    os.chmod(locations['key'], 0o600)
    if len(locations['key'].read_text().strip()) < 32:
        raise RuntimeError('The existing local API key file is invalid; inspect it before restarting.')
    os.environ.update(TAILOR_RUNTIME_DIR=str(ARTIFACTS), TAILOR_API_KEY_FILE=str(locations['key']),
                      TAILOR_HF_CACHE=str(locations['cache']),
                      TAILOR_DIGITIZATION_CACHE=str(locations['digitization']), TAILOR_DEVICE='cpu')
    return locations


def verify() -> None:
    manifest = json.loads((ARTIFACTS / 'artifact_manifest.json').read_text(encoding='utf-8-sig'))
    checkpoint = ARTIFACTS / 'best_model_state.pt'
    actual = hashlib.sha256(checkpoint.read_bytes()).hexdigest().upper()
    if actual != EXPECTED_HASH or manifest['checkpoint_sha256'] != actual or checkpoint.stat().st_size != manifest['checkpoint_size']:
        raise RuntimeError('Classifier checkpoint verification failed.')
    for path in ['tailor_ai/api/app.py', 'tailor_ai/api/automatic_preview.py',
                 'tailor_ai/garment3d/photo_projection.py', 'tailor_ai/static/index.html']:
        if not (SOURCE / path).is_file():
            raise RuntimeError(f'Missing runtime source: {path}')
    template = SOURCE / 'tailor_ai/garment3d/photo_templates/tshirtm.glb'
    if hashlib.sha256(template.read_bytes()).hexdigest() != '520b39f5e4ba332a65726be488c6417df34f4bf23be1bcefb1c21c0ea8d2ad0e':
        raise RuntimeError('Fitted T-shirt template verification failed.')
    model_id, revision = model_settings()
    print('Classifier checkpoint and fitted T-shirt template verified.', flush=True)
    print(f'SAM dependency: {model_id}, revision {revision}.', flush=True)


def download_sam() -> None:
    from huggingface_hub import snapshot_download
    locations = configure()
    model_id, revision = model_settings()
    print('Downloading the separate SAM2 Tiny weights/configuration once…', flush=True)
    snapshot_download(repo_id=model_id, revision=revision, cache_dir=locations['cache'],
                      allow_patterns=['*.json', '*.safetensors', 'README.md'])
    print('SAM2 files cached. Inference loads these files locally.', flush=True)


def smoke() -> None:
    verify()
    configure()
    from PIL import Image, ImageDraw
    from tailor_ai.inference.runtime import from_environment
    from tailor_ai.providers.segmentation.sam2_tiny import Sam2TinySegmenter
    print('Loading classifier on CPU…', flush=True)
    runtime = from_environment()
    print('Classifier startup inference passed.', flush=True)
    print('Loading cached SAM2 Tiny on CPU…', flush=True)
    segmenter = Sam2TinySegmenter(runtime.device)
    image = Image.new('RGB', (256, 256), 'white')
    ImageDraw.Draw(image).polygon([(80,40),(175,40),(220,90),(185,110),(180,225),(75,225),(70,110),(35,90)], fill='navy')
    started = time.perf_counter()
    result = segmenter.segment(image)
    if result.mask.shape != (256, 256):
        raise RuntimeError('SAM2 returned an unexpected mask shape.')
    print(f'SAM2 synthetic inference completed in {time.perf_counter()-started:.1f}s (not a real-photo quality test).', flush=True)
    # Import the real FastAPI app too, catching missing runtime dependencies.
    from tailor_ai.api.app import app
    if '/api/v1/clothing/automatic-preview' not in {route.path for route in app.routes}:
        raise RuntimeError('Automatic preview endpoint is not registered.')
    print('API imports and automatic-preview route passed.', flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['verify', 'download-sam', 'smoke', 'serve', 'key', 'check'])
    parser.add_argument('--port', type=int, default=8000)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error('Port must be between 1 and 65535.')
    if args.command == 'verify':
        verify()
    elif args.command == 'download-sam':
        download_sam()
    elif args.command == 'smoke':
        smoke()
    elif args.command == 'key':
        print(configure()['key'].read_text().strip())
    elif args.command == 'check':
        locations = configure()
        request = urllib.request.Request(f'http://127.0.0.1:{args.port}/readyz',
                    headers={'X-API-Key': locations['key'].read_text().strip()})
        with urllib.request.urlopen(request, timeout=20) as response:
            print(response.read().decode())
    else:
        verify()
        configure()
        import uvicorn
        print(f'Local Tailor: http://127.0.0.1:{args.port}/ (CPU mode)', flush=True)
        uvicorn.run('tailor_ai.api.app:app', host='127.0.0.1', port=args.port,
                    workers=1, app_dir=str(SOURCE), access_log=False)


if __name__ == '__main__':
    main()
