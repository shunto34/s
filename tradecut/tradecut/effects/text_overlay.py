"""Text overlay rendering for titles, captions, and P&L displays."""

from __future__ import annotations

from typing import Any

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from tradecut.assets.colors import (
    BACKGROUND_CARD,
    CYAN,
    PROFIT_GREEN,
    LOSS_RED,
    ROSE,
    TEXT_GRAY,
    TEXT_WHITE,
    WARNING_ORANGE,
    get_direction_color,
    get_result_color,
)
from tradecut.core.canvas import (
    WIDTH,
    HEIGHT,
    HEADER_ZONE,
    CAPTION_ZONE,
    Region,
    add_rounded_rect,
)


# Japanese-capable font paths (priority order)
_FONT_PATHS_BOLD = [
    "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
    "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
    "/usr/share/fonts/opentype/unifont/unifont_jp.otf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
]

_FONT_PATHS_REGULAR = [
    "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
    "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
    "/usr/share/fonts/opentype/unifont/unifont_jp.otf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
]


def _get_font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    """Get a font with Japanese support, falling back gracefully."""
    paths = _FONT_PATHS_BOLD if bold else _FONT_PATHS_REGULAR
    for path in paths:
        try:
            return ImageFont.truetype(path, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def _draw_text_centered(
    draw: ImageDraw.ImageDraw,
    text: str,
    y: int,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int] = TEXT_WHITE,
    shadow: bool = True,
) -> None:
    """Draw horizontally centered text with optional shadow."""
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    x = (WIDTH - text_w) // 2

    if shadow:
        draw.text((x + 2, y + 2), text, font=font, fill=(0, 0, 0))
    draw.text((x, y), text, font=font, fill=fill)


def _draw_glow_text(
    canvas: Image.Image,
    text: str,
    y: int,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int] = CYAN,
    glow_radius: int = 8,
    glow_intensity: int = 3,
) -> Image.Image:
    """Draw text with a neon glow effect.

    Renders text on a separate layer, blurs it for the glow,
    then composites the sharp text on top.
    """
    # Create glow layer
    glow_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)

    bbox = glow_draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    x = (WIDTH - text_w) // 2

    glow_color = (*fill, 180)
    # Draw text multiple times for stronger glow base
    for _ in range(glow_intensity):
        glow_draw.text((x, y), text, font=font, fill=glow_color)

    # Blur for glow effect
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=glow_radius))

    # Draw sharp text on top
    sharp_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sharp_draw = ImageDraw.Draw(sharp_layer)
    sharp_draw.text((x, y), text, font=font, fill=(*fill, 255))

    # Composite: canvas -> glow -> sharp text
    result = canvas.convert("RGBA")
    result = Image.alpha_composite(result, glow_layer)
    result = Image.alpha_composite(result, sharp_layer)
    return result.convert("RGB")


def _draw_glow_line(
    canvas: Image.Image,
    xy: list[tuple[int, int]],
    fill: tuple[int, int, int] = CYAN,
    width: int = 4,
    glow_radius: int = 6,
) -> Image.Image:
    """Draw a line with a glow effect."""
    glow_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow_layer)
    draw.line(xy, fill=(*fill, 200), width=width + 4)
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=glow_radius))

    sharp_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sharp_draw = ImageDraw.Draw(sharp_layer)
    sharp_draw.line(xy, fill=(*fill, 255), width=width)

    result = canvas.convert("RGBA")
    result = Image.alpha_composite(result, glow_layer)
    result = Image.alpha_composite(result, sharp_layer)
    return result.convert("RGB")


def render_title_card(
    canvas: Image.Image,
    title: str,
    subtitle: str = "",
) -> Image.Image:
    """Render a full-screen title card with glow effects."""
    # Add semi-transparent card background
    card_region = Region(60, HEIGHT // 2 - 200, WIDTH - 120, 400)
    canvas = add_rounded_rect(canvas, card_region, BACKGROUND_CARD, alpha=220, radius=30)

    # Title with glow
    title_font = _get_font(64, bold=True)
    canvas = _draw_glow_text(
        canvas, title, HEIGHT // 2 - 80, title_font, CYAN, glow_radius=10
    )

    # Subtitle (no glow, just clean text)
    if subtitle:
        sub_font = _get_font(36, bold=False)
        draw = ImageDraw.Draw(canvas)
        _draw_text_centered(draw, subtitle, HEIGHT // 2 + 20, sub_font, TEXT_GRAY)

    # Glowing underline
    line_y = HEIGHT // 2 - 5
    line_w = 300
    line_x = (WIDTH - line_w) // 2
    canvas = _draw_glow_line(
        canvas,
        [(line_x, line_y), (line_x + line_w, line_y)],
        CYAN,
        width=4,
    )

    return canvas


def render_caption(
    canvas: Image.Image,
    text: str,
    region: Region | None = None,
) -> Image.Image:
    """Render a caption overlay on the canvas."""
    if region is None:
        region = CAPTION_ZONE

    # Add dark background for readability
    canvas = add_rounded_rect(canvas, region, BACKGROUND_CARD, alpha=200, radius=15)

    draw = ImageDraw.Draw(canvas)
    font = _get_font(28, bold=False)

    # Word-wrap the text (handles both Latin and CJK characters)
    words = text.split()
    lines = []
    current_line = ""
    for word in words:
        test = f"{current_line} {word}".strip()
        bbox = draw.textbbox((0, 0), test, font=font)
        if bbox[2] - bbox[0] > region.w - 40:
            if current_line:
                lines.append(current_line)
            current_line = word
        else:
            current_line = test
    if current_line:
        lines.append(current_line)

    # Draw lines
    line_height = 38
    total_height = len(lines) * line_height
    start_y = region.y + (region.h - total_height) // 2

    for i, line in enumerate(lines):
        _draw_text_centered(
            draw, line, start_y + i * line_height, font, TEXT_WHITE
        )

    return canvas


def render_pnl_card(
    canvas: Image.Image,
    metadata: dict[str, Any],
) -> Image.Image:
    """Render a P&L result card with glow effects."""
    pair = metadata.get("pair", "")
    direction = metadata.get("direction", "long")
    pnl_pips = metadata.get("pnl_pips", 0)
    pnl_dollars = metadata.get("pnl_dollars", 0)
    result = metadata.get("result", "win")

    result_color = get_result_color(result)
    direction_color = get_direction_color(direction)

    # Main card background
    card_region = Region(80, HEIGHT // 2 - 250, WIDTH - 160, 500)
    canvas = add_rounded_rect(canvas, card_region, BACKGROUND_CARD, alpha=230, radius=30)

    # Pair and direction with glow
    pair_font = _get_font(48, bold=True)
    pair_text = f"{pair} {'LONG' if direction == 'long' else 'SHORT'}"
    canvas = _draw_glow_text(
        canvas, pair_text, HEIGHT // 2 - 200, pair_font, direction_color, glow_radius=6
    )

    # Decorative glow line
    line_y = HEIGHT // 2 - 130
    canvas = _draw_glow_line(
        canvas,
        [(200, line_y), (WIDTH - 200, line_y)],
        result_color,
        width=2,
    )

    # P&L pips (large, with glow)
    pips_sign = "+" if pnl_pips >= 0 else ""
    pips_font = _get_font(96, bold=True)
    canvas = _draw_glow_text(
        canvas,
        f"{pips_sign}{pnl_pips:.0f} pips",
        HEIGHT // 2 - 100,
        pips_font,
        result_color,
        glow_radius=12,
    )

    draw = ImageDraw.Draw(canvas)

    # P&L dollars
    dollar_sign = "+" if pnl_dollars >= 0 else ""
    dollar_font = _get_font(44, bold=True)
    _draw_text_centered(
        draw,
        f"{dollar_sign}${abs(pnl_dollars):.2f}",
        HEIGHT // 2 + 30,
        dollar_font,
        result_color,
    )

    # Result label
    label = {"win": "PROFIT", "loss": "LOSS", "breakeven": "BREAKEVEN"}.get(
        result, "RESULT"
    )
    label_font = _get_font(36, bold=True)
    _draw_text_centered(
        draw, label, HEIGHT // 2 + 110, label_font, result_color
    )

    return canvas


def render_outro_card(
    canvas: Image.Image,
    text: str = "Follow for more signals",
    accent_color: tuple[int, int, int] = CYAN,
) -> Image.Image:
    """Render an outro/CTA card with glow."""
    card_region = Region(100, HEIGHT // 2 - 150, WIDTH - 200, 300)
    canvas = add_rounded_rect(canvas, card_region, BACKGROUND_CARD, alpha=220, radius=25)

    font = _get_font(42, bold=True)
    canvas = _draw_glow_text(canvas, text, HEIGHT // 2 - 30, font, accent_color)

    return canvas
