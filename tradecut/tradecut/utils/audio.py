"""Audio utilities for background music and sound effects."""

from __future__ import annotations

from pathlib import Path

from moviepy import AudioFileClip, CompositeAudioClip, concatenate_audioclips


def load_background_music(
    path: str | Path,
    target_duration: float,
    volume: float = 0.15,
    fade_in: float = 1.0,
    fade_out: float = 2.0,
) -> AudioFileClip:
    """Load and prepare background music for the video.

    Loops the audio if shorter than target duration,
    trims if longer, and applies volume + fades.
    """
    music = AudioFileClip(str(path))

    # Loop if needed
    if music.duration < target_duration:
        loops_needed = int(target_duration / music.duration) + 1
        clips = [music] * loops_needed
        music = concatenate_audioclips(clips)

    # Trim to target
    music = music.subclipped(0, target_duration)

    # Apply volume
    music = music.with_volume_scaled(volume)

    # Apply fades
    if fade_in > 0:
        music = music.audio_fadein(fade_in)
    if fade_out > 0:
        music = music.audio_fadeout(fade_out)

    return music


def mix_audio(
    clips: list[AudioFileClip],
    target_duration: float,
) -> CompositeAudioClip:
    """Mix multiple audio clips together."""
    trimmed = []
    for clip in clips:
        if clip.duration > target_duration:
            clip = clip.subclipped(0, target_duration)
        trimmed.append(clip)
    return CompositeAudioClip(trimmed)
