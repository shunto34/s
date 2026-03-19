"""Text overlay rendering for titles, captions, and P&L displays."""

from __future__ import annotations

from typing import Any

from PIL import Image, ImageDraw, ImageFont

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


def _get_font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    """Get a font, falling back to default if custom fonts aren't available."""
    font_names = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    if not bold:
        font_names = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        ] + font_names

    for name in font_names:
        try:
            return ImageFont.truetype(name, size)
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


def render_title_card(
    canvas: Image.Image,
    title: str,
    subtitle: str = "",
) -> Image.Image:
    """Render a full-screen title card on the canvas."""
    # Add semi-transparent card background
    card_region = Region(60, HEIGHT // 2 - 200, WIDTH - 120, 400)
    canvas = add_rounded_rect(canvas, card_region, BACKGROUND_CARD, alpha=220, radius=30)

    draw = ImageDraw.Draw(canvas)

    # Title
    title_font = _get_font(64, bold=True)
    _draw_text_centered(draw, title, HEIGHT // 2 - 80, title_font, CYAN)

    # Subtitle
    if subtitle:
        sub_font = _get_font(36, bold=False)
        _draw_text_centered(draw, subtitle, HEIGHT // 2 + 20, sub_font, TEXT_GRAY)

    # Decorative line under title
    line_y = HEIGHT // 2 - 5
    line_w = 200
    line_x = (WIDTH - line_w) // 2
    draw.line(
        [(line_x, line_y), (line_x + line_w, line_y)],
        fill=CYAN,
        width=3,
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

    # Word-wrap the text
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
    """Render a P&L result card."""
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

    draw = ImageDraw.Draw(canvas)

    # Pair and direction
    pair_font = _get_font(48, bold=True)
    _draw_text_centered(
        draw,
        f"{pair} {'LONG' if direction == 'long' else 'SHORT'}",
        HEIGHT // 2 - 200,
        pair_font,
        direction_color,
    )

    # Decorative line
    line_y = HEIGHT // 2 - 130
    draw.line(
        [(200, line_y), (WIDTH - 200, line_y)],
        fill=result_color,
        width=2,
    )

    # P&L pips (large)
    pips_sign = "+" if pnl_pips >= 0 else ""
    pips_font = _get_font(96, bold=True)
    _draw_text_centered(
        draw,
        f"{pips_sign}{pnl_pips:.0f} pips",
        HEIGHT // 2 - 100,
        pips_font,
        result_color,
    )

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
    """Render an outro/CTA card."""
    card_region = Region(100, HEIGHT // 2 - 150, WIDTH - 200, 300)
    canvas = add_rounded_rect(canvas, card_region, BACKGROUND_CARD, alpha=220, radius=25)

    draw = ImageDraw.Draw(canvas)
    font = _get_font(42, bold=True)
    _draw_text_centered(draw, text, HEIGHT // 2 - 30, font, accent_color)

    return canvas
