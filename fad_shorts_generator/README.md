# fad_shorts_generator

日本のFXトレーダー向け **YouTube Shorts / TikTok / X (旧Twitter)** 用の 9:16 / 30秒動画を、
1コマンドで自動生成するツールです。

> **位置づけ**
> このツールは「fad」ブランド（FAD APEX MT5 インジケーター、株式会社ゴゴジャン経由で販売／
> 関東財務局長(金商)第1960号）の運用者が、**個人の学習記録・考察**を発信するための
> 編集自動化ツールです。**投資助言ではありません。**

---

## 1. クイックスタート (macOS)

```bash
# 0. 前提: Homebrew, Docker Desktop が入っていること
git clone <this-repo>
cd fad_shorts_generator
./setup.sh                                  # FFmpeg / VOICEVOX / venv / フォント / 動作テスト
source .venv/bin/activate

# 1本生成
python generate.py \
  --chart input/today.png \
  --profit 38974 --score 55 --bias BEAR --pattern pattern_a
# → output/2026-05-13_001.mp4
```

---

## 2. 必要環境

| 名前 | バージョン | 用途 |
|---|---|---|
| Python | 3.11 以上 | 本体 |
| FFmpeg | 6.x 以上 | MoviePy のバックエンド |
| ImageMagick | 6.x 以上 | （MoviePy 2.x は PIL バックエンドに移行済みのため原則不要だが、setup.sh は念のため導入） |
| Docker | 任意 | VOICEVOX ENGINE 起動用（ネイティブ版でも可） |

`setup.sh` は macOS + Homebrew + Docker Desktop 前提。
Linux で動かす場合は `brew` を `apt-get` 等に読み替えてください。

---

## 3. CLI 引数

| 引数 | 必須 | 既定 | 説明 |
|---|---|---|---|
| `--chart` | ✅ | — | チャート画像パス（1920x1080 想定） |
| `--profit` | ✅ | — | 損益（円、整数） |
| `--score` | | 55 | APEX スコア (0–100) |
| `--bias` | | BEAR | `BEAR` or `BULL` |
| `--pattern` | | pattern_a | `pattern_a` / `pattern_b` / `pattern_c` |
| `--pips` | | 20 | 下落/上昇 pips |
| `--voice` | | genno | `genno` / `genno_normal` / `metan` |
| `--output` | | 日付_連番.mp4 | 出力ファイル名 |
| `--hook-text` | | テンプレート値 | フックテロップ上書き |
| `--bgm` | | なし | `assets/bgm/` 配下のファイル名 |
| `--dry-run` | | false | 動画書き出しをスキップ |
| `--allow-silent-fallback` | | false | VOICEVOX 未起動時に無音 WAV で代用（開発用） |
| `--config` | | config.yaml | 設定ファイル |
| `--verbose` | | false | DEBUG ログ |

---

## 4. 出力仕様

- 解像度: **1080x1920 (9:16)**
- フレームレート: **30 fps**
- コーデック: **H.264 (libx264) / yuv420p**
- 音声: **AAC 192 kbps**
- 長さ: **30 秒固定**
- ファイルサイズ目標: **10 MB 以下**

---

## 5. シーン構成（30秒）

| シーン | 時刻 | 内容 |
|---|---|---|
| 1 | 0.0–1.5s | フック（チャートフラッシュイン＋ズーム、煽りテロップ） |
| 2 | 1.5–6.0s | EXIT マーカー強調（赤丸＋矢印＋黄色テロップ） |
| 3 | 6.0–12.0s | パネル数値強調（CONFIDENCE → TREND へスライドパン） |
| 4 | 12.0–20.0s | 下落の早送り（横スクロール、pips カウンタ） |
| 5 | 20.0–25.0s | 含み益強調（2.5倍ズーム、振動アニメ） |
| 6 | 25.0–30.0s | CTA（Discord 誘導）＋ 3秒間の免責表示 |

---

## 6. VOICEVOX

### 起動・停止

```bash
# 初回起動
docker run -d --name voicevox -p 50021:50021 \
  voicevox/voicevox_engine:cpu-ubuntu20.04-latest

# 以降の起動・停止
docker start voicevox
docker stop voicevox
```

ヘルスチェック:

```bash
curl http://localhost:50021/version
```

### 採用キャラ・スタイル

| `--voice` | キャラ | スタイル | speaker_id | 個人事業主の事前申請 |
|---|---|---|---|---|
| `genno` (既定) | 玄野武宏 | ツンギレ（≒「つよげ」） | 33 | **不要** |
| `genno_normal` | 玄野武宏 | ノーマル | 11 | **不要** |
| `metan` | 四国めたん | ノーマル | 2 | **不要** |

> ⚠️ **青山龍星**は個人事業主は事前申請必須のため本ツールでは採用しません。

- 玄野武宏 利用規約: <https://www.virvoxproject.com/voicevox%E3%81%AE%E5%88%A9%E7%94%A8%E8%A6%8F%E7%B4%84>
- 四国めたん 利用規約: <https://zunko.jp/con_ongen_kiyaku.html>
- VOICEVOX 全体: <https://voicevox.hiroshiba.jp/term/>

**クレジット表記**は本ツールが自動で動画末尾シーン6に
「VOICEVOX:玄野武宏」を含めて挿入します。YouTube 概要欄にも必ず記載してください
（YouTube テンプレートは本 README 末尾参照）。

---

## 7. BGM・効果音の準備

本リポジトリには **BGM / 効果音は同梱しません**。以下から手動で DL してください。

### BGM（`assets/bgm/` に配置）

- DOVA-SYNDROME (Lo-Fi 系推奨): <https://dova-s.jp>
- 甘茶の音楽工房: <https://amachamusic.chagasi.com>

### 効果音（`assets/sfx/` に配置）

| キー | デフォルトファイル名 | 推奨入手元 |
|---|---|---|
| `flash` | `flash.wav` | 効果音ラボ「フラッシュ・カメラ」<https://soundeffect-lab.info> |
| `swipe` | `swipe.wav` | 効果音ラボ「スワイプ」 |
| `click` | `click.wav` | 効果音ラボ「カチカチ」 |
| `sparkle` | `sparkle.wav` | 効果音ラボ「キラッ」 |

- 効果音ラボはクレジット不要・商用可。
- ファイル名は `config.yaml` の `sfx:` セクションで変更できます。
- ファイルが見つからない場合、その効果音はスキップされます（エラーにはしません）。

音量バランス（既定）: ナレ 100% / BGM 30% / SFX 60%

---

## 8. チャート座標調整 (`config.yaml`)

FAD APEX の表示要素は MT5 のチャート設定により位置が変わるので、`config.yaml`
の `markers:` で座標を微調整してください。

```yaml
markers:
  exit_markers:
    - { x: 568, y: 290, label: "EXIT1" }
    - { x: 1207, y: 379, label: "EXIT2" }
  confidence_panel: { x: 309, y: 685, width: 200, height: 200 }
  trend_panel:      { x: 1685, y: 750, width: 240, height: 200 }
  profit_panel:     { x: 760, y: 480, width: 400, height: 120 }
```

`crop.mode`:
- `letterbox`（推奨）: アスペクト維持で 1080 幅にフィット、上下黒帯
- `stretch`: 仕様書記述どおり「中央720幅クロップ→1080x1920に拡大」

---

## 9. NG ワード自動チェック

`generate.py` は以下のワードがテロップ／ナレ／テンプレート YAML に含まれている
場合、動画生成を即停止します。

```
絶対 / 確実 / 100%勝てる / 必ず勝てる / 保証 / 儲かります /
投資助言 / 投資顧問 / 推奨 / 元本保証 / リスクなし / 誰でも稼げる
```

リスト変更は `ng_word_check.py` の `NG_WORDS` を編集。

---

## 10. 法令遵守の必須仕様（自動挿入）

シーン6 の 3 秒間、画面下に以下が固定表示されます:

```
個人の学習記録・考察です／投資助言ではありません
販売：株式会社ゴゴジャン（関東財務局長(金商)第1960号）
VOICEVOX:玄野武宏
```

**この表示を改変しないでください**（金商法・投資助言業に該当しない位置づけを担保しているため）。

---

## 11. YouTube 概要欄テンプレート

```
本動画は個人の学習記録・考察です。投資助言ではありません。

▼ 紹介ツール
FAD APEX (MT5 インジケーター)
販売：株式会社ゴゴジャン（関東財務局長(金商)第1960号）
https://www.gogojungle.co.jp/

▼ クレジット
ナレーション: VOICEVOX:玄野武宏
BGM/SFX: DOVA-SYNDROME / 効果音ラボ

▼ ハッシュタグ
#FX #FAD #自動売買 #MT5 #インジケーター
```

---

## 12. トラブルシュート

| 症状 | 原因 | 対処 |
|---|---|---|
| `VOICEVOX 未起動` | Docker コンテナ未起動 | `docker start voicevox` |
| `日本語フォントが見つかりません` | Noto Sans CJK JP 未配置 | `python scripts/download_font.py` |
| `MoviePy: cannot find FFmpeg` | FFmpeg 未インストール | `brew install ffmpeg` |
| `OSError: cannot open resource` (Pillow) | フォントパスが相対 | `config.yaml` のパスを絶対パスに変更 |
| `ImageMagick policy.xml: not authorized` | （MoviePy 2.x なら基本不要） | `/etc/ImageMagick-*/policy.xml` の `<policy domain="path"` 行をコメント |
| 出力 mp4 が 10MB 超え | プリセット重い | `config.yaml` の `video.preset: ultrafast` か `crf: 28` に上げる |
| ナレーション速度が遅い | preset 速度低 | `config.yaml` の `voicevox.voices.genno.speed` を 1.15–1.2 |

---

## 13. 商用利用時の注意

- **インジケーター本体の販売**は株式会社ゴゴジャン（金商業者）経由でのみ実施。
  本ツールが生成する動画はその告知補助の位置づけです。
- 動画内で具体的な売買シグナル・利益保証・他人の運用判断への助言を**含めないこと**。
  NG ワードチェッカーは最低限のフィルタであって完全ではないので、運用者自身がレビューしてください。
- VOICEVOX キャラのクレジットは動画内（自動挿入済み）と概要欄の両方に必須。
- BGM・効果音のライセンス条件（クレジット要否、商用可否）を必ず DL 元で確認してください。

---

## 14. ディレクトリ構成

```
fad_shorts_generator/
├── generate.py
├── config.yaml
├── narration.py          # VOICEVOX HTTP クライアント (＋無音フォールバック)
├── image_processor.py    # チャート加工・テロップ画像生成
├── video_composer.py     # MoviePy 2.x コンポジター
├── ng_word_check.py
├── setup.sh
├── scripts/
│   ├── download_font.py
│   └── make_dummy_chart.py
├── templates/
│   ├── pattern_a_hook.yaml
│   ├── pattern_b_evidence.yaml
│   └── pattern_c_result.yaml
├── assets/
│   ├── fonts/            # Noto Sans CJK JP (DL)
│   ├── sfx/              # ユーザー配置
│   ├── bgm/              # ユーザー配置
│   └── sample/dummy_chart.png
├── input/                # チャート画像置き場
├── output/               # 完成 mp4
└── tests/
```

---

## 15. ライセンス

このコード本体は内部利用想定で公開予定はありません。第三者ライブラリのライセンスは各々を参照。
