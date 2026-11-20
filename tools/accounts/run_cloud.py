"""Run the configured Chrome app on the stable email-redirect origin."""
import json
from pathlib import Path
import shutil
import subprocess
from urllib.parse import urlsplit
root=Path(__file__).resolve().parents[2]
config=root/'config/cloud.local.json'
if not config.is_file():raise SystemExit('Run python3.12 tools/accounts/configure_cloud.py first.')
flutter=shutil.which('flutter')
if not flutter:raise SystemExit('Flutter is not on PATH.')
settings=json.loads(config.read_text());app=urlsplit(settings['APP_URL']);port=app.port or 7357
raise SystemExit(subprocess.call([flutter,'run','-d','chrome',f'--web-port={port}',f'--dart-define-from-file={config}'],cwd=root))
