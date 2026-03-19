"""Chart annotation and highlighting effects for trading visuals."""

from __future__ import annotations

from PIL import Image, ImageDraw

from tradecut.assets.colors import (
    CYAN,
    PROFIT_GREEN,
    ROSE,
    TP_GREEN,
    WARNING_ORANGE,
)


def draw_entry_marker(
    img: Image.Image,
    x: int,
    y: int,
    direction: str = "long",
    size: int = 30,
) -> Image.Image:
    """Draw a buy/sell arrow marker at the specified position."""
    img = img.copy()
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    color = CYAN if direction == "long" else ROSE

    if direction == "long":
        # Upward arrow
        points = [
            (x, y - size),
            (x - size // 2, y),
            (x - size // 4, y),
            (x - size // 4, y + size // 2),
            (x + size // 4, y + size // 2),
            (x + size // 4, y),
            (x + size // 2, y),
        ]
    else:
        # Downward arrow
        points = [
            (x, y + size),
            (x - size // 2, y),
            (x - size // 4, y),
            (x - size // 4, y - size // 2),
            (x + size // 4, y - size // 2),
            (x + size // 4, y),
            (x + size // 2, y),
        ]

    draw.polygon(points, fill=(*color, 220))

    img = img.convert("RGBA")
    img = Image.alpha_composite(img, overlay)
    return img.convert("RGB")


def draw_exit_marker(
    img: Image.Image,
    x: int,
    y: int,
    result: str = "win",
    size: int = 24,
) -> Image.Image:
    """Draw an exit marker (circle with X or checkmark)."""
    img = img.copy()
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    color = TP_GREEN if result == "win" else ROSE

    # Draw circle
    draw.ellipse(
        [(x - size, y - size), (x + size, y + size)],
        outline=(*color, 220),
        width=3,
    )

    if result == "win":
        # Checkmark
        draw.line(
            [(x - size // 2, y), (x - size // 6, y + size // 3), (x + size // 2, y - size // 3)],
            fill=(*color, 220),
            width=3,
        )
    else:
        # X mark
        offset = size // 2
        draw.line([(x - offset, y - offset), (x + offset, y + offset)], fill=(*color, 220), width=3)
        draw.line([(x + offset, y - offset), (x - offset, y + offset)], fill=(*color, 220), width=3)

    img = img.convert("RGBA")
    img = Image.alpha_composite(img, overlay)
    return img.convert("RGB")


def draw_zone(
    img: Image.Image,
    x1: int,
    y1: int,
    x2: int,
    y2: int,
    color: tuple[int, int, int] = TP_GREEN,
    alpha: int = 60,
    label: str = "",
) -> Image.Image:
    """Draw a semi-transparent zone (for SL/TP areas)."""
    img = img.copy()
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    draw.rectangle([(x1, y1), (x2, y2)], fill=(*color, alpha))
    draw.rectangle([(x1, y1), (x2, y2)], outline=(*color, 150), width=2)

    if label:
        from tradecut.effects.text_overlay import _get_font
        font = _get_font(20, bold=True)
        draw.text((x1 + 8, y1 + 4), label, font=font, fill=(*color, 220))

    img = img.convert("RGBA")
    img = Image.alpha_composite(img, overlay)
    return img.convert("RGB")


def draw_trendline(
    img: Image.Image,
    points: list[tuple[int, int]],
    color: tuple[int, int, int] = WARNING_ORANGE,
    width: int = 3,
    dashed: bool = False,
) -> Image.Image:
    """Draw a trendline through the specified points."""
    img = img.copy()
    draw = ImageDraw.Draw(img)

    if len(points) < 2:
        return img

    if dashed:
        for i in range(len(points) - 1):
            _draw_dashed_line(
                draw, points[i], points[i + 1], color, width, dash_length=10
            )
    else:
        draw.line(points, fill=color, width=width)

    return img


def _draw_dashed_line(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    color: tuple[int, int, int],
    width: int = 2,
    dash_length: int = 10,
) -> None:
    """Draw a dashed line between two points."""
    import math

    dx = end[0] - start[0]
    dy = end[1] - start[1]
    length = math.sqrt(dx * dx + dy * dy)

    if length == 0:
        return

    dashes = int(length / dash_length)
    for i in range(0, dashes, 2):
        t1 = i / dashes
        t2 = min((i + 1) / dashes, 1.0)
        x1 = int(start[0] + dx * t1)
        y1 = int(start[1] + dy * t1)
        x2 = int(start[0] + dx * t2)
        y2 = int(start[1] + dy * t2)
        draw.line([(x1, y1), (x2, y2)], fill=color, width=width)
