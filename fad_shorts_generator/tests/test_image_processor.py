"""image_processor 単体テスト。"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from PIL import Image  # noqa: E402

from image_processor import (  # noqa: E402
    crop_zoom,
    draw_arrow,
    draw_red_circle,
    fit_to_9_16,
    map_source_to_9_16,
)


def _src() -> Image.Image:
    img = Image.new("RGB", (1920, 1080), (10, 12, 18))
    return img


def test_fit_letterbox():
    out = fit_to_9_16(_src(), mode="letterbox")
    assert out.size == (1080, 1920)


def test_fit_stretch():
    out = fit_to_9_16(_src(), mode="stretch", center_crop_width=720)
    assert out.size == (1080, 1920)


def test_crop_zoom():
    out = crop_zoom(_src(), 960, 540, zoom=1.5)
    assert out.size == (1080, 1920)


def test_draw_helpers_dont_crash():
    base = fit_to_9_16(_src())
    base = draw_red_circle(base, 540, 960, radius=80)
    base = draw_arrow(base, (100, 100), (300, 200))
    assert base.size == (1080, 1920)


def test_map_source_to_9_16_letterbox():
    nx, ny = map_source_to_9_16(960, 540, mode="letterbox")
    # 960 -> 540 (中央), 540 -> 540*scale + offset where scale=1080/1920=0.5625
    assert 530 <= nx <= 550
    assert 800 <= ny <= 1100


if __name__ == "__main__":
    fns = [
        test_fit_letterbox, test_fit_stretch, test_crop_zoom,
        test_draw_helpers_dont_crash, test_map_source_to_9_16_letterbox,
    ]
    for fn in fns:
        fn()
        print(f"OK: {fn.__name__}")
    print("all passed")
