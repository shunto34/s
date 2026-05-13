#!/usr/bin/env bash
# Web UI 起動ショートカット
# 使い方: ./serve.sh  → http://127.0.0.1:8765
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ ! -d .venv ]]; then
  echo "[err] .venv が見つかりません。先に ./setup.sh を実行してください。"
  exit 1
fi

source .venv/bin/activate
exec python -m web.app
