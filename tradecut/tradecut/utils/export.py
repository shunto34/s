"""Video export settings for different platforms."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class ExportPreset:
    """Encoding parameters for a specific platform."""
    width: int
    height: int
    fps: int
    codec: str
    bitrate: str
    audio_codec: str
    audio_bitrate: str
    pixel_format: str


# Platform-optimized presets
PRESETS: dict[str, ExportPreset] = {
    "tiktok": ExportPreset(
        width=1080,
        height=1920,
        fps=30,
        codec="libx264",
        bitrate="8M",
        audio_codec="aac",
        audio_bitrate="192k",
        pixel_format="yuv420p",
    ),
    "shorts": ExportPreset(
        width=1080,
        height=1920,
        fps=30,
        codec="libx264",
        bitrate="10M",
        audio_codec="aac",
        audio_bitrate="192k",
        pixel_format="yuv420p",
    ),
    "preview": ExportPreset(
        width=360,
        height=640,
        fps=15,
        codec="libx264",
        bitrate="1M",
        audio_codec="aac",
        audio_bitrate="96k",
        pixel_format="yuv420p",
    ),
}


def get_ffmpeg_params(preset: ExportPreset) -> dict[str, str]:
    """Convert an ExportPreset to FFmpeg write_videofile parameters."""
    return {
        "codec": preset.codec,
        "bitrate": preset.bitrate,
        "audio_codec": preset.audio_codec,
        "audio_bitrate": preset.audio_bitrate,
        "ffmpeg_params": ["-pix_fmt", preset.pixel_format],
    }
