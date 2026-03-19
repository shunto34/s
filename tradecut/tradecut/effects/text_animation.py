"""Animated text effects using frame-by-frame PIL rendering.

Each function returns a moviepy VideoClip with dynamic text.
"""

from __future__ import annotations

import numpy as np
from moviepy import VideoClip
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from tradecut.assets.colors import BACKGROUND_CARD, CYAN, TEXT_WHITE
from tradecut.core.canvas import WIDTH, HEIGHT, FPS, Region, add_rounded_rect
from tradecut.effects.text_overlay import _get_font, _draw_glow_text


def _ease_out_cubic(t: float) -> float:
    """Cubic ease-out for smooth deceleration."""
    return 1 - (1 - t) ** 3


def _ease_out_back(t: float) -> float:
    """Ease-out with slight overshoot for bouncy feel."""
    c1 = 1.70158
    c3 = c1 + 1
    return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2


def animated_title(
    text: str,
    subtitle: str = "",
    duration: float = 3.0,
    bg_frame: Image.Image | None = None,
    color: tuple[int, int, int] = CYAN,
    anim_duration: float = 0.8,
) -> VideoClip:
    """Title card with text that fades in and slides up.

    The title slides up from below with a glow effect,
    the underline draws from center outward, and subtitle fades in after.
    """
    font = _get_font(64, bold=True)
    sub_font = _get_font(36, bold=False)

    def make_frame(t):
        if bg_frame is not None:
            canvas = bg_frame.copy()
        else:
            canvas = Image.new("RGB", (WIDTH, HEIGHT), (15, 15, 25))

        # Card background (always visible)
        card_region = Region(60, HEIGHT // 2 - 200, WIDTH - 120, 400)
        canvas = add_rounded_rect(canvas, card_region, BACKGROUND_CARD, alpha=220, radius=30)

        # Title animation: slide up + fade in (0 to anim_duration)
        progress = min(t / anim_duration, 1.0)
        eased = _ease_out_cubic(progress)

        # Slide from 40px below to final position
        title_y = int(HEIGHT // 2 - 80 + 40 * (1 - eased))
        alpha_val = int(255 * eased)

        # Draw title with glow (fade via alpha on overlay)
        title_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        title_draw = ImageDraw.Draw(title_layer)
        bbox = title_draw.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        x = (WIDTH - text_w) // 2

        # Glow
        glow_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow_layer)
        for _ in range(3):
            glow_draw.text((x, title_y), text, font=font, fill=(*color, int(120 * eased)))
        glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=10))

        # Sharp text
        title_draw.text((x, title_y), text, font=font, fill=(*color, alpha_val))

        result = canvas.convert("RGBA")
        result = Image.alpha_composite(result, glow_layer)
        result = Image.alpha_composite(result, title_layer)

        # Underline animation (starts at 30% of anim_duration)
        line_progress = max(0, min((t - anim_duration * 0.3) / (anim_duration * 0.7), 1.0))
        if line_progress > 0:
            line_eased = _ease_out_cubic(line_progress)
            line_y = HEIGHT // 2 - 5
            total_w = 300
            half_w = int(total_w * line_eased / 2)
            center_x = WIDTH // 2
            line_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
            ld = ImageDraw.Draw(line_layer)
            ld.line(
                [(center_x - half_w, line_y), (center_x + half_w, line_y)],
                fill=(*color, int(255 * line_eased)),
                width=4,
            )
            glow_line = line_layer.filter(ImageFilter.GaussianBlur(radius=6))
            result = Image.alpha_composite(result, glow_line)
            result = Image.alpha_composite(result, line_layer)

        # Subtitle fade in (starts after title animation)
        if subtitle:
            sub_progress = max(0, min((t - anim_duration * 0.7) / (anim_duration * 0.5), 1.0))
            if sub_progress > 0:
                sub_alpha = int(255 * _ease_out_cubic(sub_progress))
                sub_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
                sd = ImageDraw.Draw(sub_layer)
                sbbox = sd.textbbox((0, 0), subtitle, font=sub_font)
                sw = sbbox[2] - sbbox[0]
                sx = (WIDTH - sw) // 2
                sd.text((sx, HEIGHT // 2 + 20), subtitle, font=sub_font, fill=(180, 180, 200, sub_alpha))
                result = Image.alpha_composite(result, sub_layer)

        return np.array(result.convert("RGB"))

    return VideoClip(make_frame, duration=duration).with_fps(FPS)


def slide_in_text(
    text: str,
    bg_frame: Image.Image | None = None,
    direction: str = "left",
    duration: float = 2.0,
    color: tuple[int, int, int] = TEXT_WHITE,
    font_size: int = 36,
    y_position: int | None = None,
    anim_duration: float = 0.6,
) -> VideoClip:
    """Text that slides in from a direction with easing.

    Args:
        direction: 'left', 'right', or 'up'
    """
    font = _get_font(font_size, bold=True)

    def make_frame(t):
        if bg_frame is not None:
            canvas = bg_frame.copy()
        else:
            canvas = Image.new("RGB", (WIDTH, HEIGHT), (15, 15, 25))

        draw = ImageDraw.Draw(canvas)
        bbox = draw.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]

        final_x = (WIDTH - text_w) // 2
        y = y_position if y_position is not None else (HEIGHT - text_h) // 2

        progress = min(t / anim_duration, 1.0)
        eased = _ease_out_back(progress)

        if direction == "left":
            x = int(-text_w + (final_x + text_w) * eased)
        elif direction == "right":
            x = int(WIDTH - (WIDTH - final_x) * eased)
        else:  # up
            start_y = HEIGHT
            y = int(start_y - (start_y - y) * eased)
            x = final_x

        # Shadow
        draw.text((x + 2, y + 2), text, font=font, fill=(0, 0, 0))
        draw.text((x, y), text, font=font, fill=color)

        return np.array(canvas.convert("RGB"))

    return VideoClip(make_frame, duration=duration).with_fps(FPS)


def count_up(
    end_value: float,
    duration: float = 3.0,
    start_value: float = 0,
    prefix: str = "+",
    suffix: str = " pips",
    bg_frame: Image.Image | None = None,
    color: tuple[int, int, int] = (0, 255, 100),
    font_size: int = 96,
    count_duration: float = 1.5,
) -> VideoClip:
    """Animated number counting up from start to end value.

    Great for P&L displays - numbers roll up dramatically.
    """
    font = _get_font(font_size, bold=True)
    small_font = _get_font(font_size // 2, bold=True)

    def make_frame(t):
        if bg_frame is not None:
            canvas = bg_frame.copy()
        else:
            canvas = Image.new("RGB", (WIDTH, HEIGHT), (15, 15, 25))

        progress = min(t / count_duration, 1.0)
        eased = _ease_out_cubic(progress)
        current = start_value + (end_value - start_value) * eased

        # Format number
        if abs(end_value) == int(abs(end_value)):
            text = f"{prefix}{int(current)}{suffix}"
        else:
            text = f"{prefix}{current:.2f}{suffix}"

        # Scale effect: text starts slightly larger and settles
        scale_factor = 1.0 + 0.15 * (1 - eased)
        effective_size = int(font_size * scale_factor)
        current_font = _get_font(effective_size, bold=True)

        # Draw with glow
        canvas = _draw_glow_text(
            canvas, text, HEIGHT // 2 - effective_size // 2,
            current_font, color, glow_radius=int(12 * (1 - eased * 0.5))
        )

        return np.array(canvas.convert("RGB"))

    return VideoClip(make_frame, duration=duration).with_fps(FPS)


def typewriter(
    text: str,
    duration: float = 3.0,
    bg_frame: Image.Image | None = None,
    color: tuple[int, int, int] = TEXT_WHITE,
    font_size: int = 28,
    y_position: int | None = None,
    chars_per_second: float = 15.0,
) -> VideoClip:
    """Typewriter effect - text appears character by character with a cursor."""
    font = _get_font(font_size, bold=False)

    def make_frame(t):
        if bg_frame is not None:
            canvas = bg_frame.copy()
        else:
            canvas = Image.new("RGB", (WIDTH, HEIGHT), (15, 15, 25))

        draw = ImageDraw.Draw(canvas)

        # Calculate visible characters
        n_chars = min(int(t * chars_per_second), len(text))
        visible = text[:n_chars]

        y = y_position if y_position is not None else HEIGHT // 2

        bbox = draw.textbbox((0, 0), visible, font=font)
        text_w = bbox[2] - bbox[0]
        x = (WIDTH - draw.textbbox((0, 0), text, font=font)[2]) // 2  # aligned to full text

        # Shadow + text
        draw.text((x + 1, y + 1), visible, font=font, fill=(0, 0, 0))
        draw.text((x, y), visible, font=font, fill=color)

        # Blinking cursor
        if n_chars < len(text) or int(t * 3) % 2 == 0:
            cursor_x = x + text_w + 2
            draw.rectangle(
                [cursor_x, y + 2, cursor_x + 3, y + font_size - 2],
                fill=color,
            )

        return np.array(canvas.convert("RGB"))

    return VideoClip(make_frame, duration=duration).with_fps(FPS)
