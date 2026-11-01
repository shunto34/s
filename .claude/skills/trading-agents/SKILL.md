---
name: trading-agents
description: >-
  TradingAgents（TauricResearch のマルチエージェントLLMトレード分析）を実行する。
  ユーザーが「〇〇を分析して」「TradingAgentsで見て」「AIチームで判断して」
  「NVDA/金/ビットコインの売買判断は？」のように、銘柄・指数・先物・暗号資産の
  総合分析や BUY/HOLD/SELL 判断を求めたときに使う。チャート画像の読み取りだけ
  の質問や、day-trader 系 (trader-*) スキルで足りる短期スキャンには使わない。
---

# TradingAgents 実行スキル

アナリスト4人（テクニカル/ニュース/センチメント/ファンダ）→ 強気vs弱気ディベート →
トレーダー → リスク管理 → ポートフォリオマネージャー、の流れで最終判断を出す。

## 手順

1. 依頼からティッカーを決める（yfinance 表記）。
   - 米国株: `NVDA`, `AAPL` / 日本株: `7203.T` / 香港: `0700.HK`
   - 金: `GC=F`（XAUUSD の代用。FX 現物は yfinance に無い）/ 銀: `SI=F` / 原油: `CL=F`
   - 暗号資産: `BTC-USD`, `ETH-USD` / 指数: `^GSPC`, `^N225`
   - 判別できなければユーザーに聞く。
2. 日付は指定がなければ今日。週末・祝日なら直前の営業日にする。
3. 深さ: 通常は `quick`。ユーザーが「じっくり」「詳しく」と言ったら `deep`。
4. 先物・指数・FX系はファンダメンタルが機能しないので analysts を
   `market,news,sentiment` に絞る。個別株は空（全員）でよい。
5. 実行（数分〜十数分かかる。初回はインストールで +数分）:

   ```bash
   bash .claude/skills/trading-agents/run.sh <TICKER> [YYYY-MM-DD] [quick|deep] [analysts]
   ```

   タイムアウト対策として Bash は `run_in_background: true` で起動し、終了通知を待つ。
6. 出力されたレポート（`trading-reports/` 配下の md / html）を読み、日本語で要約する:
   - 最終判断（BUY / HOLD / SELL）と根拠トップ3
   - 強気派・弱気派それぞれの主張の要点
   - リスク管理チームの指摘（損切り・ポジションサイズ）
   - 末尾に「研究用ツールの出力で投資助言ではない」と一言添える。

## エラー時

- `ANTHROPIC_API_KEY が未設定` → クラウド環境の設定（タイトルバーの環境メニュー → Edit）
  で環境変数 `ANTHROPIC_API_KEY` を追加し、新しいセッションで再実行するよう伝える。
  キーをチャットに貼らせない。
- インストール失敗 → エラー行をそのまま伝える。結果を捏造しない。
