#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ "$(uname -s)" != 'Darwin' ]]; then
  echo 'This installer is for macOS. It has not installed anything.' >&2
  exit 1
fi
tailor_python=''
for candidate in python3.12 /opt/homebrew/bin/python3.12 /Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12 python3; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys,platform; sys.exit(0 if sys.version_info[:2] == (3,12) and platform.machine() == "arm64" else 1)' 2>/dev/null; then
    tailor_python="$(command -v "$candidate")"
    break
  fi
done
if [[ -z "$tailor_python" ]]; then
  echo 'Install native Apple Silicon Python 3.12, then rerun this installer.' >&2
  echo 'Your existing Python installations will not be replaced.' >&2
  exit 1
fi
"$tailor_python" "$project_root/scripts/macos/mac_local.py" verify
if [[ ! -d "$project_root/.venv-mac" ]]; then
  "$tailor_python" -m venv "$project_root/.venv-mac"
fi
venv_python="$project_root/.venv-mac/bin/python"
"$venv_python" -c 'import sys,platform; assert sys.version_info[:2]==(3,12) and platform.machine()=="arm64", "Existing .venv-mac is not native Python 3.12."'
"$venv_python" -m pip install --upgrade pip
"$venv_python" -m pip install --only-binary=:all: --index-url https://pypi.org/simple -r "$project_root/requirements/macos-inference.txt"
"$venv_python" -m pip check
"$venv_python" -m pip freeze > "$project_root/local-mac-freeze.txt"
"$venv_python" "$project_root/scripts/macos/mac_local.py" download-sam
"$venv_python" "$project_root/scripts/macos/mac_local.py" smoke
echo 'Setup passed. Start Tailor with: bash scripts/macos/start.sh'
