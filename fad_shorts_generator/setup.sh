#!/usr/bin/env bash
# fad_shorts_generator — 初期セットアップ（macOS 想定）
# 注意: Linux で動かす場合は apt-get/dnf 等に置き換えてください。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

step() { printf "\n\033[1;36m[%s]\033[0m %s\n" "$1" "$2"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$1"; }
err()  { printf "\033[1;31m[err ]\033[0m %s\n" "$1" >&2; }

# 1. macOS 前提チェック
step "1/7" "OS 確認"
if [[ "$(uname)" == "Darwin" ]]; then
  echo "  macOS detected."
else
  warn "macOS 以外を検出しました。brew コマンドは Linuxbrew か apt に読み替えてください。"
fi

# 2. brew + ffmpeg + imagemagick
step "2/7" "Homebrew / FFmpeg / ImageMagick"
if ! command -v brew >/dev/null 2>&1; then
  err "Homebrew が見つかりません。https://brew.sh/ からインストールしてください。"
  exit 1
fi
brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg
brew list imagemagick >/dev/null 2>&1 || brew install imagemagick

# 3. Docker
step "3/7" "Docker"
if ! command -v docker >/dev/null 2>&1; then
  err "Docker が見つかりません。https://www.docker.com/ からインストールしてください。"
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  warn "Docker デーモンが起動していません。Docker Desktop を起動してください。"
  echo "  起動後、もう一度 setup.sh を実行してください。"
  exit 1
fi

# 4. VOICEVOX ENGINE
step "4/7" "VOICEVOX ENGINE (Docker)"
if ! docker image inspect voicevox/voicevox_engine:cpu-ubuntu20.04-latest >/dev/null 2>&1; then
  docker pull voicevox/voicevox_engine:cpu-ubuntu20.04-latest
fi
if ! docker ps --format '{{.Names}}' | grep -q '^voicevox$'; then
  if docker ps -a --format '{{.Names}}' | grep -q '^voicevox$'; then
    docker start voicevox
  else
    docker run -d --name voicevox -p 50021:50021 \
      voicevox/voicevox_engine:cpu-ubuntu20.04-latest
  fi
fi
echo "  VOICEVOX ENGINE → http://localhost:50021"

# 5. Python venv + deps
step "5/7" "Python venv & 依存関係"
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 6. Noto Sans CJK JP フォント
step "6/7" "Noto Sans CJK JP フォント DL"
python scripts/download_font.py

# 7. 動作テスト（ダミーチャートで dry-run）
step "7/7" "動作テスト（dummy chart, dry-run）"
python scripts/make_dummy_chart.py
python generate.py \
  --chart assets/sample/dummy_chart.png \
  --profit 38974 --score 55 --bias BEAR --pattern pattern_a \
  --dry-run --allow-silent-fallback

printf "\n\033[1;32m== セットアップ完了 ==\033[0m\n"
echo "本番生成:"
echo "  source .venv/bin/activate"
echo "  python generate.py --chart input/today.png --profit 38974 --score 55 --bias BEAR --pattern pattern_a"
