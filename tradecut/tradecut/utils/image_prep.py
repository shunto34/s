"""Image preparation utilities for video frames."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

from tradecut.core.canvas import WIDTH, HEIGHT


def load_image(path: str | Path) -> Image.Image:
    """Load an image from disk."""
    return Image.open(path).convert("RGB")


def resize_to_vertical(
    img: Image.Image,
    target_w: int = WIDTH,
    target_h: int = HEIGHT,
    bg_blur: bool = True,
) -> Image.Image:
    """Resize any image to fit 9:16 vertical format.

    If the image doesn't match the aspect ratio, it will be centered
    with either black bars or a blurred background fill.
    """
    src_w, src_h = img.size
    target_ratio = target_w / target_h
    src_ratio = src_w / src_h

    if abs(src_ratio - target_ratio) < 0.01:
        return img.resize((target_w, target_h), Image.LANCZOS)

    # Create background
    if bg_blur:
        bg = img.resize((target_w, target_h), Image.LANCZOS)
        bg = bg.filter(ImageFilter.GaussianBlur(radius=30))
    else:
        bg = Image.new("RGB", (target_w, target_h), (15, 15, 25))

    # Fit the image
    if src_ratio > target_ratio:
        # Wider than target - fit by width
        new_w = target_w
        new_h = int(new_w / src_ratio)
    else:
        # Taller than target - fit by height
        new_h = target_h
        new_w = int(new_h * src_ratio)

    resized = img.resize((new_w, new_h), Image.LANCZOS)
    offset_x = (target_w - new_w) // 2
    offset_y = (target_h - new_h) // 2
    bg.paste(resized, (offset_x, offset_y))

    return bg


def crop_center(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """Crop an image from the center to the target dimensions."""
    src_w, src_h = img.size
    left = max(0, (src_w - target_w) // 2)
    top = max(0, (src_h - target_h) // 2)
    right = min(src_w, left + target_w)
    bottom = min(src_h, top + target_h)
    return img.crop((left, top, right, bottom))


def add_border_glow(
    img: Image.Image,
    color: tuple[int, int, int] = (0, 200, 220),
    width: int = 4,
    glow_radius: int = 15,
) -> Image.Image:
    """Add a glowing border effect around the image."""
    bordered = Image.new("RGB", (img.width + width * 2, img.height + width * 2), color)
    bordered.paste(img, (width, width))

    # Create glow layer
    glow = Image.new("RGB", bordered.size, (0, 0, 0))
    glow.paste(bordered, (0, 0))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=glow_radius))

    # Composite
    result = Image.blend(glow, bordered, 0.85)
    return result
