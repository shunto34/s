# このリポジトリについて

- `Visual_Logic_Masterpiece.mq5`: MT5 インジケーター。
- `.claude/skills/`: トレード分析用スキル。

## トレード系の依頼が来たら

- 「〇〇を分析して」「売買判断は？」などの総合判断 → `trading-agents` スキル
  （TradingAgents を自動インストールして実行。要 `ANTHROPIC_API_KEY`）。
- スキャン・ニュース・エントリー/エグジット・リスク・ロット計算・リプレイ
  → `trader-*` スキル（day-trader-skill, MIT, Jakeschincariol/day-trader-skill @ 3d0f4ef）。
- 発注系（trader-broker）は必ずペーパートレード既定、ユーザーの明示的な「はい」なしに進めない。
- 返答は日本語。分析結果の最後に「投資助言ではない」と一言添える。
- `trading-reports/` は生成物なのでコミットしない。
