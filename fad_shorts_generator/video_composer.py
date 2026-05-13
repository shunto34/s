"""6シーン動画コンポジター（MoviePy 2.x）。

仕様：
  - 解像度 1080x1920 / 30fps / 30秒 / H.264 + AAC 192kbps
  - シーン構成は generate.py 側から build_scenes() で受け取る

MoviePy 2.x のAPI差分メモ:
  - `set_duration` / `set_position` → `with_duration` / `with_position`
  - `set_audio` → `with_audio`
  - `TextClip(text=..., font=...)` のフォントは絶対パス必須
  - `ColorClip(size=..., color=...)` は同様
  - `concatenate_videoclips`, `CompositeVideoClip` はそのまま
  - `CompositeAudioClip` 使用、`AudioFileClip.with_volume_scaled` で音量制御
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Sequence

import numpy as np
from PIL import Image

from moviepy import (
    AudioFileClip,
    ColorClip,
    CompositeAudioClip,
    CompositeVideoClip,
    ImageClip,
    VideoClip,
    concatenate_videoclips,
    afx,
)

VIDEO_W = 1080
VIDEO_H = 1920


# ---------------------------------------------------------------------------
# ヘルパー：PIL.Image → ImageClip
# ---------------------------------------------------------------------------

def pil_to_clip(img: Image.Image, duration: float) -> ImageClip:
    arr = np.array(img.convert("RGBA"))
    return ImageClip(arr, transparent=True, duration=duration)


def pil_rgb_to_clip(img: Image.Image, duration: float) -> ImageClip:
    arr = np.array(img.convert("RGB"))
    return ImageClip(arr, duration=duration)


# ---------------------------------------------------------------------------
# シーン構造
# ---------------------------------------------------------------------------

@dataclass
class TextOverlay:
    text_img: Image.Image          # 事前にレンダ済みテロップ
    start: float                   # シーン内の開始秒
    duration: float
    pos: tuple[str | int, str | int] = ("center", 200)  # (x, y) or "center"
    fade_in: float = 0.15
    fade_out: float = 0.15


@dataclass
class NarrationTrack:
    wav_path: Path
    start: float = 0.0
    volume: float = 1.0


@dataclass
class SfxTrack:
    wav_path: Path
    start: float = 0.0
    volume: float = 0.6


@dataclass
class Scene:
    duration: float
    # 背景: 各フレームを返す関数 t -> PIL.Image または 静的画像
    background: Image.Image | Callable[[float], Image.Image]
    overlays: list[TextOverlay] = field(default_factory=list)
    narration: NarrationTrack | None = None
    sfx: list[SfxTrack] = field(default_factory=list)


# ---------------------------------------------------------------------------
# シーン → VideoClip
# ---------------------------------------------------------------------------

def _bg_to_clip(scene: Scene) -> VideoClip:
    bg = scene.background
    if isinstance(bg, Image.Image):
        return pil_rgb_to_clip(bg, scene.duration).resized((VIDEO_W, VIDEO_H))

    # callable → frame function
    def make_frame(t):
        img = bg(t)
        if img.size != (VIDEO_W, VIDEO_H):
            img = img.resize((VIDEO_W, VIDEO_H), Image.LANCZOS)
        return np.array(img.convert("RGB"))

    return VideoClip(make_frame, duration=scene.duration)


def _overlay_to_clip(o: TextOverlay) -> VideoClip:
    clip = pil_to_clip(o.text_img, o.duration).with_start(o.start)
    clip = clip.with_position(o.pos)
    # fade in/out（Effectsはmoviepy 2系では .with_effects([...])）
    effects = []
    if o.fade_in > 0:
        from moviepy.video.fx import CrossFadeIn
        effects.append(CrossFadeIn(o.fade_in))
    if o.fade_out > 0:
        from moviepy.video.fx import CrossFadeOut
        effects.append(CrossFadeOut(o.fade_out))
    if effects:
        clip = clip.with_effects(effects)
    return clip


def build_scene_clip(scene: Scene) -> VideoClip:
    bg_clip = _bg_to_clip(scene)
    layers: list[VideoClip] = [bg_clip]
    for o in scene.overlays:
        layers.append(_overlay_to_clip(o))
    return CompositeVideoClip(layers, size=(VIDEO_W, VIDEO_H)).with_duration(scene.duration)


# ---------------------------------------------------------------------------
# 動画全体ビルド
# ---------------------------------------------------------------------------

def _build_audio(scenes: Sequence[Scene], bgm_path: Path | None, bgm_volume: float) -> "CompositeAudioClip | None":
    audio_layers = []
    cursor = 0.0
    total = sum(s.duration for s in scenes)
    for s in scenes:
        if s.narration:
            a = AudioFileClip(str(s.narration.wav_path))
            a = a.with_start(cursor + s.narration.start)
            try:
                a = a.with_volume_scaled(s.narration.volume)
            except AttributeError:
                # 旧API fallback (使われない想定だが念のため)
                a = a.with_effects([afx.MultiplyVolume(s.narration.volume)])
            audio_layers.append(a)
        for sfx in s.sfx:
            a = AudioFileClip(str(sfx.wav_path))
            a = a.with_start(cursor + sfx.start)
            try:
                a = a.with_volume_scaled(sfx.volume)
            except AttributeError:
                a = a.with_effects([afx.MultiplyVolume(sfx.volume)])
            audio_layers.append(a)
        cursor += s.duration

    if bgm_path and bgm_path.exists():
        bgm = AudioFileClip(str(bgm_path))
        # BGM を total 秒にループ/カット
        if bgm.duration < total:
            n = int(math.ceil(total / bgm.duration))
            from moviepy.audio.AudioClip import concatenate_audioclips
            bgm = concatenate_audioclips([bgm] * n)
        bgm = bgm.subclipped(0, total)
        try:
            bgm = bgm.with_volume_scaled(bgm_volume)
        except AttributeError:
            bgm = bgm.with_effects([afx.MultiplyVolume(bgm_volume)])
        audio_layers.append(bgm)

    if not audio_layers:
        return None
    return CompositeAudioClip(audio_layers)


def compose(
    scenes: Sequence[Scene],
    out_path: Path,
    *,
    bgm_path: Path | None = None,
    bgm_volume: float = 0.3,
    fps: int = 30,
    audio_bitrate: str = "192k",
    codec: str = "libx264",
    audio_codec: str = "aac",
    preset: str = "medium",
    threads: int = 2,
) -> Path:
    video = concatenate_videoclips(
        [build_scene_clip(s) for s in scenes], method="compose"
    )
    audio = _build_audio(scenes, bgm_path, bgm_volume)
    if audio is not None:
        video = video.with_audio(audio)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    video.write_videofile(
        str(out_path),
        fps=fps,
        codec=codec,
        audio_codec=audio_codec,
        audio_bitrate=audio_bitrate,
        preset=preset,
        threads=threads,
        ffmpeg_params=["-pix_fmt", "yuv420p", "-movflags", "+faststart"],
    )
    return out_path
