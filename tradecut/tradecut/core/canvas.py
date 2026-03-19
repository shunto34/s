"""Canvas management for 1080x1920 vertical video frames."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageDraw

from tradecut.assets.colors import BACKGROUND_DARK


# Standard vertical video dimensions
WIDTH = 1080
HEIGHT = 1920
FPS = 30


@dataclass
class Region:
    """A rectangular region on the canvas."""
    x: int
    y: int
    w: int
    h: int

    @property
    def center(self) -> tuple[int, int]:
        return self.x + self.w // 2, self.y + self.h // 2

    @property
    def box(self) -> tuple[int, int, int, int]:
        """Return (left, top, right, bottom) for PIL."""
        return self.x, self.y, self.x + self.w, self.y + self.h


# Pre-defined safe zones for vertical video
# Top 150px reserved for TikTok UI elements
HEADER_ZONE = Region(40, 160, WIDTH - 80, 140)
# Main chart area (largest region)
CHART_ZONE = Region(30, 320, WIDTH - 60, 1050)
# Caption area below chart
CAPTION_ZONE = Region(60, 1400, WIDTH - 120, 200)
# P&L display area
PNL_ZONE = Region(60, 1150, WIDTH - 120, 200)
# Bottom safe zone (above TikTok buttons)
FOOTER_ZONE = Region(60, 1650, WIDTH - 120, 120)


def create_blank_frame(
    color: tuple[int, int, int] = BACKGROUND_DARK,
) -> Image.Image:
    """Create a blank 1080x1920 frame with the given background color."""
    return Image.new("RGB", (WIDTH, HEIGHT), color)


def create_gradient_frame(
    top_color: tuple[int, int, int] = (20, 20, 35),
    bottom_color: tuple[int, int, int] = (10, 10, 20),
) -> Image.Image:
    """Create a vertical gradient background frame."""
    img = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)

    for i in range(3):
        gradient = np.linspace(top_color[i], bottom_color[i], HEIGHT, dtype=np.uint8)
        pixels[:, :, i] = gradient[:, np.newaxis]

    return Image.fromarray(pixels)


def fit_image_to_region(
    img: Image.Image,
    region: Region,
    mode: str = "fit",
) -> Image.Image:
    """Resize an image to fit within a region.

    Args:
        img: Source image.
        region: Target region on canvas.
        mode: "fit" (preserve aspect, may letterbox),
              "fill" (preserve aspect, crop to fill),
              "stretch" (ignore aspect ratio).
    """
    target_w, target_h = region.w, region.h

    if mode == "stretch":
        return img.resize((target_w, target_h), Image.LANCZOS)

    src_w, src_h = img.size
    src_ratio = src_w / src_h
    target_ratio = target_w / target_h

    if mode == "fill":
        if src_ratio > target_ratio:
            new_h = target_h
            new_w = int(new_h * src_ratio)
        else:
            new_w = target_w
            new_h = int(new_w / src_ratio)
        resized = img.resize((new_w, new_h), Image.LANCZOS)
        left = (new_w - target_w) // 2
        top = (new_h - target_h) // 2
        return resized.crop((left, top, left + target_w, top + target_h))

    # mode == "fit"
    if src_ratio > target_ratio:
        new_w = target_w
        new_h = int(new_w / src_ratio)
    else:
        new_h = target_h
        new_w = int(new_h * src_ratio)
    return img.resize((new_w, new_h), Image.LANCZOS)


def place_on_canvas(
    canvas: Image.Image,
    img: Image.Image,
    region: Region,
    fit_mode: str = "fit",
) -> Image.Image:
    """Place an image onto the canvas within the specified region."""
    fitted = fit_image_to_region(img, region, fit_mode)

    # Center the fitted image within the region
    offset_x = region.x + (region.w - fitted.width) // 2
    offset_y = region.y + (region.h - fitted.height) // 2

    canvas = canvas.copy()
    if fitted.mode == "RGBA":
        canvas.paste(fitted, (offset_x, offset_y), fitted)
    else:
        canvas.paste(fitted, (offset_x, offset_y))
    return canvas


def add_rounded_rect(
    canvas: Image.Image,
    region: Region,
    color: tuple[int, int, int],
    alpha: int = 200,
    radius: int = 20,
) -> Image.Image:
    """Draw a semi-transparent rounded rectangle on the canvas."""
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    fill = (*color, alpha)
    draw.rounded_rectangle(region.box, radius=radius, fill=fill)

    canvas = canvas.convert("RGBA")
    canvas = Image.alpha_composite(canvas, overlay)
    return canvas.convert("RGB")


def frame_to_numpy(frame: Image.Image) -> np.ndarray:
    """Convert a PIL Image to a numpy array for moviepy."""
    return np.array(frame.convert("RGB"))


def numpy_to_frame(arr: np.ndarray) -> Image.Image:
    """Convert a numpy array back to PIL Image."""
    return Image.fromarray(arr)
