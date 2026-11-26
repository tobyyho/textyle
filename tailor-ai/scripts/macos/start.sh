#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/../.." && pwd)"
venv_python="$project_root/.venv-mac/bin/python"
if [[ ! -x "$venv_python" ]]; then
  echo 'Run bash scripts/macos/bootstrap.sh first.' >&2
  exit 1
fi
exec "$venv_python" "$project_root/scripts/macos/mac_local.py" serve "$@"
