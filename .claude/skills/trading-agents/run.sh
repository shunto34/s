#!/usr/bin/env bash
# TradingAgents を必要なら自動インストールして、非対話モードで1銘柄を分析する。
# 使い方: bash .claude/skills/trading-agents/run.sh <TICKER> [YYYY-MM-DD] [quick|deep] [analysts]
set -euo pipefail

TICKER="${1:?ティッカーを指定してください (例: NVDA, GC=F, BTC-USD)}"
DATE="${2:-$(date +%F)}"
DEPTH="${3:-quick}"
ANALYSTS="${4:-}"

# 動作確認済みのコミットに固定（更新するときはここを書き換える）
TA_REPO="https://github.com/TauricResearch/TradingAgents.git"
TA_COMMIT="c4544913a14ed3df5f1ed7b9e8483270ce20682a"   # v0.7.1 (2026-10-27)
TA_DIR="${TRADINGAGENTS_SRC:-$HOME/.cache/tradingagents-src}"
VENV="$TA_DIR/.venv"

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "ERROR: ANTHROPIC_API_KEY が未設定です。クラウド環境の設定で環境変数として登録してください。" >&2
  exit 2
fi

if [ ! -x "$VENV/bin/tradingagents" ]; then
  echo ">> TradingAgents を初回セットアップ中 ($TA_COMMIT)..." >&2
  rm -rf "$TA_DIR"
  git init -q "$TA_DIR"
  git -C "$TA_DIR" remote add origin "$TA_REPO"
  git -C "$TA_DIR" fetch -q --depth 1 origin "$TA_COMMIT"
  git -C "$TA_DIR" checkout -q FETCH_HEAD
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --upgrade pip
  "$VENV/bin/pip" install -q "$TA_DIR"
fi

export TRADINGAGENTS_LLM_PROVIDER="${TRADINGAGENTS_LLM_PROVIDER:-anthropic}"
export TRADINGAGENTS_DEEP_THINK_LLM="${TRADINGAGENTS_DEEP_THINK_LLM:-claude-opus-5-5}"
export TRADINGAGENTS_QUICK_THINK_LLM="${TRADINGAGENTS_QUICK_THINK_LLM:-claude-sonnet-5}"
export TRADINGAGENTS_OUTPUT_LANGUAGE="${TRADINGAGENTS_OUTPUT_LANGUAGE:-Japanese}"
if [ "$DEPTH" = "deep" ]; then
  export TRADINGAGENTS_MAX_DEBATE_ROUNDS="${TRADINGAGENTS_MAX_DEBATE_ROUNDS:-3}"
  export TRADINGAGENTS_MAX_RISK_ROUNDS="${TRADINGAGENTS_MAX_RISK_ROUNDS:-3}"
else
  export TRADINGAGENTS_MAX_DEBATE_ROUNDS="${TRADINGAGENTS_MAX_DEBATE_ROUNDS:-1}"
  export TRADINGAGENTS_MAX_RISK_ROUNDS="${TRADINGAGENTS_MAX_RISK_ROUNDS:-1}"
fi
export TRADINGAGENTS_NO_UPDATE_CHECK=1
export TRADINGAGENTS_RESULTS_DIR="${TRADINGAGENTS_RESULTS_DIR:-$PWD/trading-reports}"
mkdir -p "$TRADINGAGENTS_RESULTS_DIR"

ARGS=(--ticker "$TICKER" --date "$DATE" --save --no-show --html)
[ -n "$ANALYSTS" ] && ARGS+=(--analysts "$ANALYSTS")

"$VENV/bin/tradingagents" "${ARGS[@]}" < /dev/null

echo ">> レポート保存先: $TRADINGAGENTS_RESULTS_DIR" >&2
find "$TRADINGAGENTS_RESULTS_DIR" -type f \( -name '*.md' -o -name '*.html' \) -newer "$0" -mmin -120 2>/dev/null | sort | tail -20
