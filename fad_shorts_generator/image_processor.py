"""チャート画像の加工（クロップ・ズーム・マーキング・矢印・テロップ用キャンバス）。

入力：1920x1080 想定の FAD APEX チャート画像
出力：シーンごとの 1080x1920 (9:16) PNG / Pillow Image
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


VIDEO_W = 1080
VIDEO_H = 1920
SOURCE_W = 1920
SOURCE_H = 1080


# ---------------------------------------------------------------------------
# 基本変換
# ---------------------------------------------------------------------------

def load_chart(path: str | Path) -> Image.Image:
    """元チャート画像を読み込み RGB に正規化、1920x1080 にフィットさせる。"""
    img = Image.open(path).convert("RGB")
    if img.size != (SOURCE_W, SOURCE_H):
        # アスペクト維持してフィット
        img.thumbnail((SOURCE_W, SOURCE_H), Image.LANCZOS)
        canvas = Image.new("RGB", (SOURCE_W, SOURCE_H), (0, 0, 0))
        x = (SOURCE_W - img.width) // 2
        y = (SOURCE_H - img.height) // 2
        canvas.paste(img, (x, y))
        img = canvas
    return img


def fit_to_9_16(chart: Image.Image, mode: str = "letterbox", center_crop_width: int = 720) -> Image.Image:
    """1920x1080 を 1080x1920 9:16 フレームに収める。

    mode:
      letterbox: アスペクト維持で 1080 幅にフィット、上下黒帯
      stretch:   中央 center_crop_width をクロップして 1080x1920 に引き伸ばし（仕様書記述）
    """
    if mode == "stretch":
        cx = chart.width // 2
        half = center_crop_width // 2
        cropped = chart.crop((cx - half, 0, cx + half, chart.height))
        return cropped.resize((VIDEO_W, VIDEO_H), Image.LANCZOS)
    # letterbox
    new_w = VIDEO_W
    new_h = int(round(chart.height * (VIDEO_W / chart.width)))
    resized = chart.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGB", (VIDEO_W, VIDEO_H), (0, 0, 0))
    y = (VIDEO_H - new_h) // 2
    canvas.paste(resized, (0, y))
    return canvas


# ---------------------------------------------------------------------------
# 描画ユーティリティ
# ---------------------------------------------------------------------------

@dataclass
class Marker:
    x: int
    y: int
    label: str = ""


def draw_red_circle(img: Image.Image, x: int, y: int, radius: int = 80, width: int = 8) -> Image.Image:
    """指定座標に半透明赤丸を描画。座標は img のピクセル座標。"""
    out = img.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    bbox = (x - radius, y - radius, x + radius, y + radius)
    draw.ellipse(bbox, outline=(255, 40, 40, 255), width=width)
    return out


def draw_arrow(img: Image.Image, start: tuple[int, int], end: tuple[int, int],
               color: tuple[int, int, int] = (255, 255, 255), width: int = 8,
               head_size: int = 28) -> Image.Image:
    """直線＋矢じり。"""
    out = img.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    draw.line([start, end], fill=color + (255,), width=width)
    # arrowhead
    dx, dy = end[0] - start[0], end[1] - start[1]
    angle = math.atan2(dy, dx)
    a1 = angle + math.radians(150)
    a2 = angle - math.radians(150)
    p1 = (end[0] + head_size * math.cos(a1), end[1] + head_size * math.sin(a1))
    p2 = (end[0] + head_size * math.cos(a2), end[1] + head_size * math.sin(a2))
    draw.polygon([end, p1, p2], fill=color + (255,))
    return out


def draw_box(img: Image.Image, x: int, y: int, w: int, h: int,
             color: tuple[int, int, int] = (255, 40, 40), width: int = 8) -> Image.Image:
    out = img.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    draw.rectangle((x, y, x + w, y + h), outline=color + (255,), width=width)
    return out


def crop_zoom(img: Image.Image, cx: int, cy: int, zoom: float,
              out_w: int = VIDEO_W, out_h: int = VIDEO_H) -> Image.Image:
    """中心 (cx, cy)、倍率 zoom でクロップして 9:16 にスケール。

    cx, cy は img 座標系。zoom はクロップ窓のサイズ縮小倍率
    (zoom=1.5 → 元解像度の 1/1.5 領域を切り出して拡大)。
    """
    crop_w = int(out_w / zoom)
    crop_h = int(out_h / zoom)
    x0 = max(0, min(img.width - crop_w, cx - crop_w // 2))
    y0 = max(0, min(img.height - crop_h, cy - crop_h // 2))
    region = img.crop((x0, y0, x0 + crop_w, y0 + crop_h))
    return region.resize((out_w, out_h), Image.LANCZOS)


def map_source_to_9_16(x: int, y: int, mode: str = "letterbox",
                       center_crop_width: int = 720) -> tuple[int, int]:
    """元 1920x1080 上の座標を、9:16 配置後の座標に写像する。"""
    if mode == "stretch":
        cx = SOURCE_W // 2
        half = center_crop_width // 2
        # x が [cx-half, cx+half] にあるとき、1080 幅に線形マップ
        nx = (x - (cx - half)) * VIDEO_W / (2 * half)
        ny = y * VIDEO_H / SOURCE_H
        return int(nx), int(ny)
    # letterbox
    scale = VIDEO_W / SOURCE_W
    new_h = int(SOURCE_H * scale)
    y_off = (VIDEO_H - new_h) // 2
    return int(x * scale), int(y * scale + y_off)


# ---------------------------------------------------------------------------
# テロップ（PIL ベース、moviepy 2.x の TextClip と棲み分け）
# ---------------------------------------------------------------------------

def make_text_image(
    text: str,
    font_path: str,
    font_size: int,
    *,
    color: tuple[int, int, int] = (255, 255, 255),
    stroke_color: tuple[int, int, int] | None = (255, 40, 40),
    stroke_width: int = 3,
    bg: tuple[int, int, int, int] | None = None,
    padding: int = 24,
    max_width: int | None = None,
) -> Image.Image:
    """縁取り付きテロップ PNG（透過 or 背景色付き）を生成。"""
    font = ImageFont.truetype(font_path, font_size)
    # 大きめの仮キャンバスでテキストの実寸を測ってからクロップ
    tmp = Image.new("RGBA", (4000, 800), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    bbox = d.textbbox((0, 0), text, font=font, stroke_width=stroke_width or 0)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    w = tw + padding * 2
    h = th + padding * 2
    if max_width and w > max_width:
        w = max_width

    canvas = Image.new("RGBA", (w, h), bg if bg else (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    x = (w - tw) // 2 - bbox[0]
    y = padding - bbox[1]
    if stroke_color is not None and stroke_width > 0:
        draw.text((x, y), text, font=font, fill=color,
                  stroke_width=stroke_width, stroke_fill=stroke_color)
    else:
        draw.text((x, y), text, font=font, fill=color)
    return canvas


def blur_image(img: Image.Image, radius: int = 20) -> Image.Image:
    return img.filter(ImageFilter.GaussianBlur(radius=radius))


def to_np(img: Image.Image) -> np.ndarray:
    return np.array(img.convert("RGB"))


if __name__ == "__main__":
    # 簡易テスト
    import sys
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/sample/dummy_chart.png")
    chart = load_chart(src)
    out = fit_to_9_16(chart, mode="letterbox")
    out = draw_red_circle(out, 540, 960, radius=120, width=10)
    out.save("/tmp/image_processor_test.png")
    print("wrote /tmp/image_processor_test.png", out.size)
