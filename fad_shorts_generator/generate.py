"""fad_shorts_generator — エントリポイント

例:
  python generate.py --chart input/today.png --profit 38974 --score 55 \\
      --bias BEAR --pattern pattern_a --pips 20
"""
from __future__ import annotations

import argparse
import datetime as dt
import logging
import os
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

import yaml
from PIL import Image

from image_processor import (
    VIDEO_H,
    VIDEO_W,
    draw_arrow,
    draw_box,
    draw_red_circle,
    crop_zoom,
    fit_to_9_16,
    load_chart,
    make_text_image,
    map_source_to_9_16,
    blur_image,
)
from narration import VoicePreset, synthesize_to_file, load_presets_from_config
from ng_word_check import assert_clean
from video_composer import (
    NarrationTrack,
    Scene,
    SfxTrack,
    TextOverlay,
    compose,
)


log = logging.getLogger("fad_shorts")


PROJECT_ROOT = Path(__file__).resolve().parent


# ---------------------------------------------------------------------------
# 数値→読み仮名（簡易）
# ---------------------------------------------------------------------------

def yen_to_speech(value: int) -> str:
    """38974 -> '3万8千974'。VOICEVOXは漢数字混じりも読めるが、
    煽り動画では「3万8千」のような略読が定着している。
    """
    n = int(value)
    sign = "マイナス" if n < 0 else ""
    n = abs(n)
    if n == 0:
        return "0"
    parts = []
    man = n // 10000
    rem = n % 10000
    if man:
        parts.append(f"{man}万")
    sen = rem // 1000
    rem2 = rem % 1000
    if sen:
        parts.append(f"{sen}千")
    if rem2:
        parts.append(str(rem2))
    return sign + "".join(parts)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="FAD APEX YouTube Shorts ジェネレータ")
    p.add_argument("--chart", required=True, help="チャート画像パス")
    p.add_argument("--profit", required=True, type=int, help="損益（円、整数）")
    p.add_argument("--score", type=int, default=55)
    p.add_argument("--bias", choices=["BEAR", "BULL"], default="BEAR")
    p.add_argument("--pattern", default="pattern_a")
    p.add_argument("--pips", type=int, default=20)
    p.add_argument("--voice", default="genno",
                   choices=["genno", "genno_normal", "metan"])
    p.add_argument("--output", default=None, help="出力 mp4 ファイル名（省略時は日付_連番）")
    p.add_argument("--hook-text", default=None, help="フックテロップ上書き")
    p.add_argument("--bgm", default=None, help="assets/bgm/ 配下のファイル名")
    p.add_argument("--dry-run", action="store_true",
                   help="ナレ生成と画像加工のみ実行、動画書き出しはしない")
    p.add_argument("--allow-silent-fallback", action="store_true",
                   help="VOICEVOX 未起動時に無音 WAV で代用（開発用）")
    p.add_argument("--config", default="config.yaml")
    p.add_argument("--verbose", action="store_true")
    return p.parse_args()


# ---------------------------------------------------------------------------
# 出力ファイル名
# ---------------------------------------------------------------------------

def next_output_name(out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    today = dt.date.today().isoformat()
    existing = sorted(out_dir.glob(f"{today}_*.mp4"))
    if not existing:
        seq = 1
    else:
        seq = max(int(p.stem.split("_")[-1]) for p in existing) + 1
    return out_dir / f"{today}_{seq:03d}.mp4"


# ---------------------------------------------------------------------------
# フォント解決
# ---------------------------------------------------------------------------

def resolve_font(cfg: dict, role: str = "bold") -> str:
    """設定からフォント絶対パスを解決。見つからなければ fallback を順に試す。"""
    primary = PROJECT_ROOT / cfg["fonts"][role]
    if primary.exists():
        return str(primary)
    for cand in cfg["fonts"].get("fallback_search", []):
        if os.path.exists(cand):
            return cand
    raise FileNotFoundError(
        f"日本語フォントが見つかりません。setup.sh で Noto Sans CJK JP を DL してください。"
        f" 試行: {primary} と fallback_search 全て"
    )


# ---------------------------------------------------------------------------
# テンプレート読み込み
# ---------------------------------------------------------------------------

def load_template(name: str) -> dict:
    p = PROJECT_ROOT / "templates" / f"{name}.yaml"
    if not p.exists():
        # `pattern_a` を渡されたら `pattern_a_hook` などにマップ
        candidates = list((PROJECT_ROOT / "templates").glob(f"{name}_*.yaml"))
        if candidates:
            p = candidates[0]
        else:
            raise FileNotFoundError(f"テンプレート未存在: {name}")
    return yaml.safe_load(p.read_text(encoding="utf-8"))


# ---------------------------------------------------------------------------
# シーン構築
# ---------------------------------------------------------------------------

@dataclass
class BuildContext:
    chart_path: Path
    profit: int
    profit_speech: str
    score: int
    bias: str
    pips: int
    hook_text: str
    cfg: dict
    template: dict
    font_bold: str
    voice_preset: VoicePreset
    tmp_dir: Path
    bgm_path: Path | None
    sfx_dir: Path
    allow_silent_fallback: bool


def _sfx_path(ctx: BuildContext, key: str) -> Path | None:
    name = ctx.cfg.get("sfx", {}).get(key)
    if not name:
        return None
    p = ctx.sfx_dir / name
    return p if p.exists() else None


def _narration_clip(ctx: BuildContext, text: str, idx: int) -> Path:
    out = ctx.tmp_dir / f"narr_{idx:02d}.wav"
    synthesize_to_file(
        text,
        ctx.voice_preset,
        out,
        endpoint=ctx.cfg["voicevox"]["endpoint"],
        allow_silent_fallback=ctx.allow_silent_fallback,
    )
    return out


def build_scene_1_hook(ctx: BuildContext, chart_9_16: Image.Image) -> Scene:
    """0.0-1.5s フック。"""
    dur = 1.5

    def frame(t: float) -> Image.Image:
        # 0-0.3s: 黒→フラッシュイン (フェードイン)
        if t < 0.3:
            alpha = t / 0.3
            black = Image.new("RGB", (VIDEO_W, VIDEO_H), (0, 0, 0))
            return Image.blend(black, chart_9_16, alpha)
        # 0.3-1.5s: 1.05x → 1.0x ズーム
        u = (t - 0.3) / (dur - 0.3)
        zoom = 1.05 - 0.05 * u
        cw = int(VIDEO_W / zoom)
        ch = int(VIDEO_H / zoom)
        x0 = (VIDEO_W - cw) // 2
        y0 = (VIDEO_H - ch) // 2
        region = chart_9_16.crop((x0, y0, x0 + cw, y0 + ch))
        return region.resize((VIDEO_W, VIDEO_H), Image.LANCZOS)

    hook_img = make_text_image(
        ctx.hook_text,
        font_path=ctx.font_bold,
        font_size=110,
        color=(255, 255, 255),
        stroke_color=(220, 30, 30),
        stroke_width=6,
        padding=20,
    )
    overlay = TextOverlay(
        text_img=hook_img, start=0.3, duration=dur - 0.3,
        pos=("center", 220), fade_in=0.12, fade_out=0.0,
    )

    narr_text = f"{ctx.hook_text}です"
    narr = _narration_clip(ctx, narr_text, 1)

    sfx = []
    flash = _sfx_path(ctx, "flash")
    if flash:
        sfx.append(SfxTrack(wav_path=flash, start=0.0, volume=ctx.cfg["audio"]["sfx"]))

    return Scene(
        duration=dur, background=frame, overlays=[overlay],
        narration=NarrationTrack(wav_path=narr, start=0.1, volume=ctx.cfg["audio"]["narration"]),
        sfx=sfx,
    )


def build_scene_2_exit(ctx: BuildContext, chart_src: Image.Image) -> Scene:
    """1.5-6s EXITマーカー強調。"""
    dur = 4.5
    markers = ctx.cfg["markers"]["exit_markers"]
    if not markers:
        # マーカー未定義時は中央左
        markers = [{"x": 568, "y": 290, "label": "EXIT1"}]
    m = markers[0]
    crop_mode = ctx.cfg["crop"]["mode"]
    ccw = ctx.cfg["crop"].get("center_crop_width", 720)

    # 9:16フレーム上のEXIT座標
    ex_9_16 = map_source_to_9_16(m["x"], m["y"], crop_mode, ccw)
    base = fit_to_9_16(chart_src, mode=crop_mode, center_crop_width=ccw)
    # 中心をEXIT座標、1.5倍ズーム
    zoomed = crop_zoom(base, ex_9_16[0], ex_9_16[1], zoom=1.5)
    # 描画後の新座標（中心になる）
    cx, cy = VIDEO_W // 2, VIDEO_H // 2
    marked = draw_red_circle(zoomed, cx, cy, radius=120, width=12)
    marked = draw_arrow(marked, (cx - 320, cy - 220), (cx - 130, cy - 60),
                        color=(255, 235, 50), width=14, head_size=40)

    arrow_label = make_text_image(
        "→ EXIT", font_path=ctx.font_bold, font_size=78,
        color=(255, 235, 50), stroke_color=(0, 0, 0), stroke_width=4,
    )
    arrow_overlay = TextOverlay(
        text_img=arrow_label, start=0.4, duration=dur - 0.5,
        pos=(cx - 480, cy - 320), fade_in=0.2, fade_out=0.2,
    )
    yellow_text = make_text_image(
        "ここで売れと教えてくれた",
        font_path=ctx.font_bold, font_size=70,
        color=(20, 20, 20), stroke_color=None, stroke_width=0,
        bg=(255, 220, 50, 235), padding=32,
    )
    text_overlay = TextOverlay(
        text_img=yellow_text, start=0.6, duration=dur - 0.8,
        pos=("center", 1500), fade_in=0.2, fade_out=0.2,
    )

    narr = _narration_clip(ctx, "ここで売れって、インジが教えてくれた", 2)
    return Scene(
        duration=dur, background=marked,
        overlays=[arrow_overlay, text_overlay],
        narration=NarrationTrack(wav_path=narr, start=0.3, volume=ctx.cfg["audio"]["narration"]),
    )


def build_scene_3_panels(ctx: BuildContext, chart_src: Image.Image) -> Scene:
    """6-12s パネル数値強調（スライドパン）。"""
    dur = 6.0
    cfgm = ctx.cfg["markers"]
    conf = cfgm["confidence_panel"]
    trend = cfgm["trend_panel"]
    crop_mode = ctx.cfg["crop"]["mode"]
    ccw = ctx.cfg["crop"].get("center_crop_width", 720)

    # 各パネル中心の9:16座標
    c1 = map_source_to_9_16(conf["x"] + conf["width"] // 2,
                             conf["y"] + conf["height"] // 2, crop_mode, ccw)
    c2 = map_source_to_9_16(trend["x"] + trend["width"] // 2,
                             trend["y"] + trend["height"] // 2, crop_mode, ccw)
    base = fit_to_9_16(chart_src, mode=crop_mode, center_crop_width=ccw)

    def frame(t: float) -> Image.Image:
        u = max(0.0, min(1.0, t / dur))
        cx = int(c1[0] + (c2[0] - c1[0]) * u)
        cy = int(c1[1] + (c2[1] - c1[1]) * u)
        img = crop_zoom(base, cx, cy, zoom=1.6)
        # 赤枠（フェーズ前半=Confidence、後半=Trend）
        target_panel = conf if u < 0.5 else trend
        # 9:16空間の枠位置（中心(cx,cy)→クロップ後は中央）
        return draw_box(img, VIDEO_W // 2 - 180, VIDEO_H // 2 - 150,
                        360, 280, color=(255, 60, 60), width=12)

    texts = [
        (f"スコア{ctx.score} = 売り優勢" if ctx.bias == "BEAR" else f"スコア{ctx.score} = 買い優勢"),
        "3時間足ぜんぶ下向き" if ctx.bias == "BEAR" else "3時間足ぜんぶ上向き",
        "迷う理由ゼロ",
    ]
    overlays: list[TextOverlay] = []
    for i, t in enumerate(texts):
        img = make_text_image(
            t, font_path=ctx.font_bold, font_size=72,
            color=(255, 255, 255), stroke_color=(0, 0, 0), stroke_width=5,
        )
        overlays.append(TextOverlay(
            text_img=img, start=i * 2.0, duration=1.9,
            pos=("center", 320), fade_in=0.2, fade_out=0.2,
        ))

    bias_word = "売り優勢" if ctx.bias == "BEAR" else "買い優勢"
    direction = "下向き" if ctx.bias == "BEAR" else "上向き"
    narr_text = f"スコア{ctx.score}で{bias_word}、3時間足が全部{direction}、迷う理由ゼロ"
    narr = _narration_clip(ctx, narr_text, 3)
    sfx = []
    sw = _sfx_path(ctx, "swipe")
    if sw:
        sfx.append(SfxTrack(wav_path=sw, start=0.0, volume=ctx.cfg["audio"]["sfx"]))

    return Scene(
        duration=dur, background=frame, overlays=overlays,
        narration=NarrationTrack(wav_path=narr, start=0.2, volume=ctx.cfg["audio"]["narration"]),
        sfx=sfx,
    )


def build_scene_4_drop(ctx: BuildContext, chart_src: Image.Image) -> Scene:
    """12-20s 下落の早送り。"""
    dur = 8.0
    crop_mode = ctx.cfg["crop"]["mode"]
    ccw = ctx.cfg["crop"].get("center_crop_width", 720)
    base = fit_to_9_16(chart_src, mode=crop_mode, center_crop_width=ccw)
    # 横スクロール: 中心xを左→右へ
    left_x = VIDEO_W // 3
    right_x = VIDEO_W * 2 // 3
    cy = VIDEO_H // 2

    def frame(t: float) -> Image.Image:
        u = max(0.0, min(1.0, t / dur))
        cx = int(left_x + (right_x - left_x) * u)
        return crop_zoom(base, cx, cy, zoom=1.5)

    direction = "下落" if ctx.bias == "BEAR" else "上昇"
    sign = "-" if ctx.bias == "BEAR" else "+"
    counter_text = TextOverlay(
        text_img=make_text_image(
            f"↓ 30分後 ↓" if ctx.bias == "BEAR" else "↑ 30分後 ↑",
            font_path=ctx.font_bold, font_size=80,
            color=(255, 255, 255), stroke_color=(0, 0, 0), stroke_width=5,
        ),
        start=0.3, duration=2.5, pos=("center", 250), fade_in=0.2, fade_out=0.2,
    )
    big_pips = TextOverlay(
        text_img=make_text_image(
            f"{sign}{ctx.pips}pips{direction}",
            font_path=ctx.font_bold, font_size=98,
            color=(255, 235, 50), stroke_color=(0, 0, 0), stroke_width=6,
        ),
        start=3.0, duration=dur - 3.5, pos=("center", 420), fade_in=0.2, fade_out=0.3,
    )
    # 右下にカウンタを進める
    counter_overlays: list[TextOverlay] = []
    pip_steps = [5, 10, 15, ctx.pips]
    for i, p in enumerate(pip_steps):
        img = make_text_image(
            f"{sign}{p}pips", font_path=ctx.font_bold, font_size=72,
            color=(255, 80, 80) if ctx.bias == "BEAR" else (80, 220, 120),
            stroke_color=(0, 0, 0), stroke_width=4,
        )
        counter_overlays.append(TextOverlay(
            text_img=img, start=2.0 + i * 1.2, duration=1.2,
            pos=(700, 1600), fade_in=0.05, fade_out=0.05,
        ))

    narr_text = f"30分後、{ctx.pips}pips{direction}、淡々と取るだけ"
    narr = _narration_clip(ctx, narr_text, 4)
    sfx = []
    click = _sfx_path(ctx, "click")
    if click:
        for i in range(4):
            sfx.append(SfxTrack(wav_path=click, start=2.0 + i * 1.2,
                                volume=ctx.cfg["audio"]["sfx"]))

    return Scene(
        duration=dur, background=frame,
        overlays=[counter_text, big_pips, *counter_overlays],
        narration=NarrationTrack(wav_path=narr, start=0.2, volume=ctx.cfg["audio"]["narration"]),
        sfx=sfx,
    )


def build_scene_5_profit(ctx: BuildContext, chart_src: Image.Image) -> Scene:
    """20-25s 含み益表示（2.5倍ズーム + 振動）。"""
    dur = 5.0
    crop_mode = ctx.cfg["crop"]["mode"]
    ccw = ctx.cfg["crop"].get("center_crop_width", 720)
    profit_panel = ctx.cfg["markers"].get("profit_panel", {"x": 760, "y": 480, "width": 400, "height": 120})
    p_center = map_source_to_9_16(
        profit_panel["x"] + profit_panel["width"] // 2,
        profit_panel["y"] + profit_panel["height"] // 2,
        crop_mode, ccw,
    )
    base = fit_to_9_16(chart_src, mode=crop_mode, center_crop_width=ccw)
    zoomed = crop_zoom(base, p_center[0], p_center[1], zoom=2.5)

    import math as _m

    def frame(t: float) -> Image.Image:
        # 軽い振動（±4px）
        dx = int(4 * _m.sin(t * 28))
        dy = int(4 * _m.cos(t * 33))
        canvas = Image.new("RGB", (VIDEO_W, VIDEO_H), (0, 0, 0))
        canvas.paste(zoomed, (dx, dy))
        return canvas

    big = make_text_image(
        f"今日だけで +{ctx.profit:,}円",
        font_path=ctx.font_bold, font_size=100,
        color=(255, 235, 50), stroke_color=(0, 0, 0), stroke_width=6,
    )
    overlay = TextOverlay(
        text_img=big, start=0.3, duration=dur - 0.5,
        pos=("center", 1300), fade_in=0.25, fade_out=0.3,
    )

    narr_text = f"今日だけで、{ctx.profit_speech}円、控えめだけど、毎日これ"
    narr = _narration_clip(ctx, narr_text, 5)
    sfx = []
    sparkle = _sfx_path(ctx, "sparkle")
    if sparkle:
        sfx.append(SfxTrack(wav_path=sparkle, start=0.2,
                            volume=ctx.cfg["audio"]["sfx"]))

    return Scene(
        duration=dur, background=frame, overlays=[overlay],
        narration=NarrationTrack(wav_path=narr, start=0.3, volume=ctx.cfg["audio"]["narration"]),
        sfx=sfx,
    )


def build_scene_6_cta(ctx: BuildContext, chart_src: Image.Image) -> Scene:
    """25-30s CTA + 免責表示。"""
    dur = 5.0
    crop_mode = ctx.cfg["crop"]["mode"]
    ccw = ctx.cfg["crop"].get("center_crop_width", 720)
    base = fit_to_9_16(chart_src, mode=crop_mode, center_crop_width=ccw)
    blurred = blur_image(base, radius=18)
    # 暗くする
    dark = Image.new("RGB", (VIDEO_W, VIDEO_H), (0, 0, 0))
    bg = Image.blend(blurred, dark, 0.45)

    arrow = make_text_image(
        "↑↑↑", font_path=ctx.font_bold, font_size=180,
        color=(255, 255, 255), stroke_color=(220, 30, 30), stroke_width=8,
    )
    cta_text = make_text_image(
        "続きはDiscordで毎日配信中",
        font_path=ctx.font_bold, font_size=80,
        color=(255, 255, 255), stroke_color=(0, 0, 0), stroke_width=5,
    )
    profile_text = make_text_image(
        "↑ プロフィール ↑",
        font_path=ctx.font_bold, font_size=64,
        color=(255, 235, 50), stroke_color=(0, 0, 0), stroke_width=4,
    )
    overlays = [
        TextOverlay(text_img=arrow, start=0.1, duration=2.9,
                    pos=("center", 350), fade_in=0.2, fade_out=0.2),
        TextOverlay(text_img=cta_text, start=0.3, duration=2.7,
                    pos=("center", 700), fade_in=0.2, fade_out=0.2),
        TextOverlay(text_img=profile_text, start=0.6, duration=2.4,
                    pos=("center", 850), fade_in=0.2, fade_out=0.2),
    ]
    # 3-5s: 免責表示
    disclaimer_lines = [
        "個人の学習記録・考察です／投資助言ではありません",
        "販売：株式会社ゴゴジャン（関東財務局長(金商)第1960号）",
        "VOICEVOX:玄野武宏",
    ]
    for i, line in enumerate(disclaimer_lines):
        img = make_text_image(
            line, font_path=ctx.font_bold, font_size=36,
            color=(255, 255, 255), stroke_color=(0, 0, 0), stroke_width=2,
            bg=(0, 0, 0, 180), padding=14,
        )
        overlays.append(TextOverlay(
            text_img=img, start=3.0, duration=2.0,
            pos=("center", 1540 + i * 70), fade_in=0.15, fade_out=0.0,
        ))

    narr = _narration_clip(ctx, "続きはDiscord、プロフィールから飛べます", 6)
    return Scene(
        duration=dur, background=bg, overlays=overlays,
        narration=NarrationTrack(wav_path=narr, start=0.3, volume=ctx.cfg["audio"]["narration"]),
    )


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main() -> int:
    args = parse_args()
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )

    cfg_path = PROJECT_ROOT / args.config
    cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8"))
    template = load_template(args.pattern)
    hook_text = args.hook_text or template.get("hook_text") or "このインジ、ガチで反則"

    # NGワード事前チェック（テンプレート文 + 実引数文）
    candidate_texts: list[tuple[str, str]] = [
        ("hook_text", hook_text),
        ("template.title", template.get("title", "")),
    ]
    for k, v in (template.get("narrations") or {}).items():
        candidate_texts.append((f"template.narrations.{k}", str(v)))
    for k, v in (template.get("telops") or {}).items():
        candidate_texts.append((f"template.telops.{k}", str(v)))
    assert_clean(candidate_texts)

    presets = load_presets_from_config(cfg)
    if args.voice not in presets:
        print(f"未定義の voice: {args.voice}", file=sys.stderr)
        return 2
    voice_preset = presets[args.voice]

    # 出力名解決
    out_dir = PROJECT_ROOT / "output"
    out_path = (out_dir / args.output) if args.output else next_output_name(out_dir)
    if out_path.suffix != ".mp4":
        out_path = out_path.with_suffix(".mp4")

    # 作業ディレクトリ
    tmp_dir = PROJECT_ROOT / ".cache" / out_path.stem
    if tmp_dir.exists():
        shutil.rmtree(tmp_dir)
    tmp_dir.mkdir(parents=True, exist_ok=True)

    # フォント・BGM・SFX解決
    font_bold = resolve_font(cfg, "bold")
    bgm_path = None
    if args.bgm:
        bgm_path = PROJECT_ROOT / "assets" / "bgm" / args.bgm
        if not bgm_path.exists():
            log.warning("BGM ファイル未存在のためスキップ: %s", bgm_path)
            bgm_path = None
    sfx_dir = PROJECT_ROOT / "assets" / "sfx"

    # チャート読込・9:16基底版
    chart_src = load_chart(args.chart)
    chart_9_16 = fit_to_9_16(
        chart_src,
        mode=cfg["crop"]["mode"],
        center_crop_width=cfg["crop"].get("center_crop_width", 720),
    )

    ctx = BuildContext(
        chart_path=Path(args.chart),
        profit=args.profit,
        profit_speech=yen_to_speech(args.profit),
        score=args.score,
        bias=args.bias,
        pips=args.pips,
        hook_text=hook_text,
        cfg=cfg,
        template=template,
        font_bold=font_bold,
        voice_preset=voice_preset,
        tmp_dir=tmp_dir,
        bgm_path=bgm_path,
        sfx_dir=sfx_dir,
        allow_silent_fallback=args.allow_silent_fallback,
    )

    log.info("シーン構築開始 (pattern=%s, voice=%s)", args.pattern, args.voice)
    scenes = [
        build_scene_1_hook(ctx, chart_9_16),
        build_scene_2_exit(ctx, chart_src),
        build_scene_3_panels(ctx, chart_src),
        build_scene_4_drop(ctx, chart_src),
        build_scene_5_profit(ctx, chart_src),
        build_scene_6_cta(ctx, chart_src),
    ]
    total = sum(s.duration for s in scenes)
    log.info("総尺: %.2f 秒（仕様 30 秒）", total)

    if args.dry_run:
        log.info("--dry-run: 動画書き出しをスキップ。一時ファイル: %s", tmp_dir)
        return 0

    log.info("動画書き出し → %s", out_path)
    compose(
        scenes,
        out_path,
        bgm_path=bgm_path,
        bgm_volume=cfg["audio"]["bgm"],
        fps=cfg["video"]["fps"],
        audio_bitrate=cfg["video"]["audio_bitrate"],
        codec=cfg["video"]["codec"],
        audio_codec=cfg["video"]["audio_codec"],
        preset=cfg["video"].get("preset", "medium"),
    )
    size_mb = out_path.stat().st_size / (1024 * 1024)
    log.info("完了: %s (%.2f MB)", out_path, size_mb)
    return 0


if __name__ == "__main__":
    sys.exit(main())
