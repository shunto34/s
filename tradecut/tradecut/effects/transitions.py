"""Video transition effects between clips."""

from __future__ import annotations

from moviepy import VideoClip


def apply_transition(
    clip: VideoClip,
    transition_type: str,
    duration: float = 0.5,
    direction: str = "in",
) -> VideoClip:
    """Apply a transition effect to a clip.

    Args:
        clip: The video clip to apply the transition to.
        transition_type: Type of transition (fade, slide_left, slide_up, glitch).
        duration: Duration of the transition in seconds.
        direction: "in" for entrance, "out" for exit.
    """
    if transition_type == "fade":
        return _fade(clip, duration, direction)
    elif transition_type == "slide_left":
        return _slide(clip, duration, direction, axis="x")
    elif transition_type == "slide_up":
        return _slide(clip, duration, direction, axis="y")
    elif transition_type == "glitch":
        return _glitch(clip, duration, direction)
    return clip


def _fade(clip: VideoClip, duration: float, direction: str) -> VideoClip:
    """Simple fade in/out."""
    if direction == "in":
        return clip.with_effects([_FadeIn(duration)])
    return clip.with_effects([_FadeOut(duration)])


class _FadeIn:
    """Fade in effect compatible with moviepy 2.x."""

    def __init__(self, duration: float):
        self.duration = duration

    def apply(self, clip: VideoClip) -> VideoClip:
        return clip.crossfadein(self.duration)


class _FadeOut:
    """Fade out effect compatible with moviepy 2.x."""

    def __init__(self, duration: float):
        self.duration = duration

    def apply(self, clip: VideoClip) -> VideoClip:
        return clip.crossfadeout(self.duration)


def _slide(
    clip: VideoClip,
    duration: float,
    direction: str,
    axis: str = "x",
) -> VideoClip:
    """Slide in/out effect."""
    w, h = clip.size

    def position_func(t):
        if t >= duration:
            return (0, 0)

        progress = t / duration
        if direction == "out":
            progress = 1.0 - progress

        if axis == "x":
            return (int(-w * (1 - progress)), 0)
        return (0, int(-h * (1 - progress)))

    return clip.with_position(position_func)


def _glitch(clip: VideoClip, duration: float, direction: str) -> VideoClip:
    """Quick glitch transition - rapid opacity flicker."""
    import numpy as np

    def glitch_filter(get_frame, t):
        frame = get_frame(t)
        if direction == "in" and t < duration:
            progress = t / duration
            if np.random.random() > progress:
                # Random horizontal shift
                shift = np.random.randint(-20, 20)
                frame = np.roll(frame, shift, axis=1)
        elif direction == "out" and t > clip.duration - duration:
            progress = (clip.duration - t) / duration
            if np.random.random() > progress:
                shift = np.random.randint(-20, 20)
                frame = np.roll(frame, shift, axis=1)
        return frame

    return clip.transform(glitch_filter)
