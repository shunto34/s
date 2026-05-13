"""テスト用ダミーチャート画像（1920x1080）を生成。

FAD APEX 風のレイアウトを模倣：
  - 黒背景に格子
  - 緑/赤キャンドル列
  - 左下に CONFIDENCE パネル風の四角
  - 右下に TREND パネル風の四角
  - 上部に EXIT マーカー（赤い▼）
  - 中央付近に「-{pips}pips」「+{profit}円」の数値
"""
from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUT = PROJECT_ROOT / "assets" / "sample" / "dummy_chart.png"
W, H = 1920, 1080


def _pick_font() -> ImageFont.FreeTypeFont:
    # フォント未DLでも崩れないように複数候補
    candidates = [
        PROJECT_ROOT / "assets" / "fonts" / "NotoSansCJKjp-Bold.otf",
        Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"),
        Path("/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
    ]
    for c in candidates:
        if c.exists():
            try:
                return ImageFont.truetype(str(c), 36)
            except OSError:
                continue
    return ImageFont.load_default()


def make_dummy_chart(out_path: Path = OUT, seed: int = 7) -> Path:
    rnd = random.Random(seed)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", (W, H), (10, 12, 18))
    d = ImageDraw.Draw(img)

    # grid
    for x in range(0, W, 80):
        d.line([(x, 0), (x, H)], fill=(28, 30, 38), width=1)
    for y in range(0, H, 80):
        d.line([(0, y), (W, y)], fill=(28, 30, 38), width=1)

    # candles
    base_y = 500
    x = 80
    price = 0
    while x < W - 160:
        delta = rnd.randint(-25, 18)  # slight bearish
        h = abs(delta) * 4 + 6
        color = (60, 200, 110) if delta >= 0 else (220, 70, 70)
        top = base_y + price - (h if delta >= 0 else 0)
        bottom = top + h
        d.rectangle((x, top, x + 10, bottom), fill=color)
        # wick
        d.line([(x + 5, top - 8), (x + 5, bottom + 8)], fill=color, width=2)
        x += 16
        price += -delta * 2

    # EXIT markers (red triangles, downward)
    for ex in [(568, 290), (1207, 379)]:
        d.polygon(
            [(ex[0] - 18, ex[1] - 30), (ex[0] + 18, ex[1] - 30), (ex[0], ex[1])],
            fill=(255, 70, 70),
        )
        f = _pick_font()
        d.text((ex[0] + 22, ex[1] - 40), "EXIT", fill=(255, 70, 70), font=f)

    # CONFIDENCE panel (left-bottom)
    cp = (309, 685, 309 + 200, 685 + 200)
    d.rectangle(cp, outline=(120, 220, 255), width=3)
    f = _pick_font()
    d.text((cp[0] + 14, cp[1] + 10), "CONFIDENCE", fill=(120, 220, 255), font=f)
    d.text((cp[0] + 14, cp[1] + 70), "55", fill=(255, 235, 50), font=ImageFont.truetype(f.path, 80) if hasattr(f, "path") else f)
    d.text((cp[0] + 14, cp[1] + 160), "BEAR", fill=(255, 90, 90), font=f)

    # TREND panel (right-bottom)
    tp = (1685, 750, 1685 + 240, 750 + 200)
    d.rectangle(tp, outline=(120, 220, 255), width=3)
    d.text((tp[0] + 14, tp[1] + 10), "TREND", fill=(120, 220, 255), font=f)
    d.text((tp[0] + 14, tp[1] + 50), "H3:↓", fill=(255, 90, 90), font=f)
    d.text((tp[0] + 14, tp[1] + 90), "H1:↓", fill=(255, 90, 90), font=f)
    d.text((tp[0] + 14, tp[1] + 130), "M15:↓", fill=(255, 90, 90), font=f)

    # Profit overlay (mock)
    pp = (760, 480, 760 + 400, 480 + 120)
    d.rectangle(pp, outline=(255, 235, 50), width=3)
    d.text((pp[0] + 12, pp[1] + 14), "PROFIT", fill=(255, 235, 50), font=f)
    big_font = ImageFont.truetype(f.path, 60) if hasattr(f, "path") else f
    d.text((pp[0] + 12, pp[1] + 50), "+38,974 JPY", fill=(255, 235, 50), font=big_font)

    # Title
    title_font = ImageFont.truetype(f.path, 42) if hasattr(f, "path") else f
    d.text((30, 20), "FAD APEX — USDJPY M15  (DEMO CHART)", fill=(220, 220, 220), font=title_font)

    img.save(out_path, format="PNG")
    return out_path


if __name__ == "__main__":
    p = make_dummy_chart()
    print(f"wrote {p}")
