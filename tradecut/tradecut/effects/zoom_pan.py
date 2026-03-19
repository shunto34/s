"""Zoom and pan effects for making static images dynamic."""

from __future__ import annotations

from typing import Any

import numpy as np
from moviepy import VideoClip
from PIL import Image


def apply_zoom_effect(clip: VideoClip, effect: dict[str, Any]) -> VideoClip:
    """Apply a zoom/pan effect to a clip based on effect config.

    Effect types:
        ken_burns: Slow zoom in from start_zoom to end_zoom
        focus_zoom: Zoom into a specific point
        slow_zoom: Simple slow zoom in
    """
    effect_type = effect.get("type", "slow_zoom")

    if effect_type == "ken_burns":
        return _ken_burns(
            clip,
            start_zoom=effect.get("start_zoom", 1.0),
            end_zoom=effect.get("end_zoom", 1.15),
            center=effect.get("center", (0.5, 0.5)),
        )
    elif effect_type == "focus_zoom":
        return _focus_zoom(
            clip,
            target=effect.get("target", (0.5, 0.5)),
            max_zoom=effect.get("max_zoom", 1.5),
            hold_ratio=effect.get("hold_ratio", 0.4),
        )
    elif effect_type == "slow_zoom":
        return _ken_burns(
            clip,
            start_zoom=1.0,
            end_zoom=effect.get("end_zoom", 1.1),
            center=(0.5, 0.5),
        )

    return clip


def _ken_burns(
    clip: VideoClip,
    start_zoom: float = 1.0,
    end_zoom: float = 1.15,
    center: tuple[float, float] = (0.5, 0.5),
) -> VideoClip:
    """Ken Burns effect - slow zoom with optional pan."""
    w, h = clip.size
    cx_ratio, cy_ratio = center

    def zoom_filter(get_frame, t):
        frame = get_frame(t)
        progress = t / clip.duration if clip.duration > 0 else 0
        zoom = start_zoom + (end_zoom - start_zoom) * progress

        # Calculate crop region
        crop_w = int(w / zoom)
        crop_h = int(h / zoom)

        cx = int(w * cx_ratio)
        cy = int(h * cy_ratio)

        x1 = max(0, min(cx - crop_w // 2, w - crop_w))
        y1 = max(0, min(cy - crop_h // 2, h - crop_h))
        x2 = x1 + crop_w
        y2 = y1 + crop_h

        # Crop and resize back to original dimensions
        cropped = frame[y1:y2, x1:x2]
        pil_img = Image.fromarray(cropped)
        pil_img = pil_img.resize((w, h), Image.LANCZOS)
        return np.array(pil_img)

    return clip.transform(zoom_filter)


def _focus_zoom(
    clip: VideoClip,
    target: tuple[float, float] = (0.5, 0.5),
    max_zoom: float = 1.5,
    hold_ratio: float = 0.4,
) -> VideoClip:
    """Zoom into a target point, hold, then zoom back out.

    Good for highlighting entry/exit points on a chart.
    """
    w, h = clip.size
    tx, ty = target

    def zoom_filter(get_frame, t):
        frame = get_frame(t)
        progress = t / clip.duration if clip.duration > 0 else 0

        # Zoom in -> hold -> zoom out
        zoom_in_end = (1 - hold_ratio) / 2
        zoom_out_start = 1 - zoom_in_end

        if progress < zoom_in_end:
            # Zooming in
            p = progress / zoom_in_end
            # Ease in-out
            p = p * p * (3 - 2 * p)
            zoom = 1.0 + (max_zoom - 1.0) * p
        elif progress < zoom_out_start:
            # Holding
            zoom = max_zoom
        else:
            # Zooming out
            p = (progress - zoom_out_start) / zoom_in_end
            p = p * p * (3 - 2 * p)
            zoom = max_zoom - (max_zoom - 1.0) * p

        crop_w = int(w / zoom)
        crop_h = int(h / zoom)

        cx = int(w * tx)
        cy = int(h * ty)

        x1 = max(0, min(cx - crop_w // 2, w - crop_w))
        y1 = max(0, min(cy - crop_h // 2, h - crop_h))
        x2 = x1 + crop_w
        y2 = y1 + crop_h

        cropped = frame[y1:y2, x1:x2]
        pil_img = Image.fromarray(cropped)
        pil_img = pil_img.resize((w, h), Image.LANCZOS)
        return np.array(pil_img)

    return clip.transform(zoom_filter)
