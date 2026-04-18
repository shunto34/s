# FAD APEX v4.59 — AI セットアップガイド

このドキュメントは、v4.59 の **Layer 1（ONNX 勝率予測）** を使うための手順書です。

> **Layer 2（自己学習）は `.onnx` ファイル不要で即動作します。**
> このガイドは「勝率% をシグナルに併記したい」場合のみ必要。

---

## 必要なもの

| 要件 | 詳細 |
|---|---|
| MetaTrader 5 | **build 3440 以上**（ヘルプ → バージョン情報で確認） |
| Python | **3.9 以上**（訓練時のみ、購入者は不要） |
| 過去データ CSV | MT5 History Center から出力、最低3年分推奨 |
| ディスク容量 | 訓練 300MB、生成 .onnx は 50-200KB |

---

## ステップ 1 — Python 環境セットアップ（訓練する人のみ）

```bash
# Python 3.9+ を公式サイトからインストール
# https://www.python.org/downloads/

# ライブラリをインストール
pip install lightgbm scikit-learn skl2onnx onnxmltools onnxruntime pandas numpy
```

---

## ステップ 2 — 過去データをエクスポート

MT5 を起動し：

1. `表示 → ヒストリーセンター`（F2）
2. `USDJPY` を選択 → `M15` をダブルクリック
3. `エクスポート` ボタン → `USDJPY_M15.csv` で保存
4. **最低3年分**のデータがあることを確認

---

## ステップ 3 — モデル訓練

```bash
cd /path/to/FadApex/
python FadApex_AI_train.py --csv USDJPY_M15.csv --symbol USDJPY --pip 0.01
```

### 引数

| 引数 | 説明 | 例 |
|---|---|---|
| `--csv` | 入力 CSV パス | `USDJPY_M15.csv` |
| `--pip` | pip サイズ | JPY ペア: `0.01` / その他: `0.0001` |
| `--symbol` | ラベル用（任意） | `USDJPY` |
| `--out` | 出力 ONNX パス | `FadApex_AI.onnx`（既定） |

### 期待される出力

```
[load] USDJPY_M15.csv (pip=0.01)
[load] 70000 bars from 2022-01-01 to 2026-04-18
[build] extracting signals + labeling...
[build] 1250 samples; win-rate in data = 0.47
[split] train/test split 80/20
[train] LightGBM classifier...
[eval] test AUC     = 0.68
[eval] test accuracy= 0.62
[export] writing FadApex_AI.onnx
[done] model size = 87.3 KB
[done] place 'FadApex_AI.onnx' into MetaTrader5 -> Files -> MQL5/Files/
```

**AUC 0.65 以上** なら実用レベル。0.60 未満ならデータ量・品質を見直し。

---

## ステップ 4 — ONNX を MT5 に配置

1. MT5 メニュー: `ファイル → データフォルダを開く`
2. `MQL5 / Files /` フォルダへ `FadApex_AI.onnx` をコピー
3. MT5 を **再起動**（またはチャートにインジケータを再適用）

---

## ステップ 5 — 動作確認

チャートにインジケータを適用し、「エキスパート」タブで以下のログを確認：

```
FAPX AI: ONNX model loaded, win-rate scoring active.
```

新しいシグナルが発生したとき、**ラベルに % が付きます**：

```
BULL S ★ 72%    ← AI 予測勝率
BEAR A 58%
BULL B 41%
```

---

## トラブルシュート

### Q: `FAPX AI: OnnxCreate('FadApex_AI.onnx') failed`
**A:** `.onnx` ファイルが `MQL5/Files/` に正しく配置されていない。パスを再確認。

### Q: `MT5 build 3440 < ... ONNX unsupported`
**A:** MT5 が古い。`ヘルプ → アップデートの確認` で最新にする（無料）。

### Q: シグナルに % が出ない
**A:** 以下を確認：
- `InpUseAI = true`
- `InpAIShowScore = true`
- エキスパートタブに `ONNX model loaded` のログがあるか

### Q: 訓練で `Too few training samples` エラー
**A:** データ不足。3年分以上の M15 データを用意（約 70,000 本）。

### Q: AI勝率 60% 未満を非表示にしたい
**A:** `InpAIMinWinRate = 60` に設定。

---

## 特徴量 (18次元) 仕様

訓練スクリプトと MQL5 側で**完全一致**している必要があります：

| # | 名前 | 内容 |
|---|---|---|
| 0 | `mtf_align` | MTF一致度 (0-3) / 3.0 |
| 1 | `ema_order` | 完全EMA順配列 (0/1) |
| 2 | `body_atr` | ローソク実体 / ATR |
| 3 | `ribbon_atr` | リボン幅 / ATR |
| 4 | `score_norm` | ランクスコア (0-4) / 4.0 |
| 5-7 | `regime_oh` | レジーム one-hot (Trend/Range/Brk) |
| 8 | `vol_bucket` | ATR / ATR平均30 |
| 9-11 | `session_oh` | セッション one-hot (Asia/Lon/NY) |
| 12 | `dow_norm` | 曜日 (0-6) / 6.0 |
| 13 | `bars_since` | log1p(前回シグナル経過バー数) |
| 14 | `adx_norm` | ADX / 50.0 |
| 15 | `ema_compress` | EMA8本stdev / 価格 |
| 16 | `htf_align` | HTF一致度 (0-3) / 3.0 |
| 17 | `direction` | +1=BULL / -1=BEAR |

---

## 注意事項

- 訓練した通貨ペア・時間足と**同じ環境**で使う（USDJPY M15 モデルは USDJPY M15 専用）
- 汎用化したい場合は複数通貨の CSV を連結して訓練
- ONNX ファイルなしでも **Layer 2（自己学習）は動作** — 完全フォールバック設計
- 訓練済みモデルはリポジトリに同梱しない（訓練データ依存のため）
