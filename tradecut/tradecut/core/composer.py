"""Main video composition pipeline with animations, SE, and TTS."""

from __future__ import annotations

import logging
from pathlib import Path

import numpy as np
from moviepy import (
    AudioFileClip,
    CompositeAudioClip,
    CompositeVideoClip,
    ImageClip,
    VideoClip,
    VideoFileClip,
    concatenate_audioclips,
    concatenate_videoclips,
)
from PIL import Image

from tradecut.assets.colors import BACKGROUND_DARK, BACKGROUND_CARD
from tradecut.core.canvas import (
    WIDTH,
    HEIGHT,
    FPS,
    CHART_ZONE,
    HEADER_ZONE,
    CAPTION_ZONE,
    PNL_ZONE,
    Region,
    create_gradient_frame,
    place_on_canvas,
    add_rounded_rect,
    frame_to_numpy,
)
from tradecut.core.timeline import Segment, Timeline
from tradecut.effects.text_overlay import (
    render_title_card,
    render_caption,
    render_pnl_card,
)
from tradecut.effects.text_animation import (
    animated_title,
    count_up,
    typewriter,
)
from tradecut.effects.sound_effects import (
    generate_impact,
    generate_whoosh,
    generate_success,
    generate_fail,
    generate_notification,
)
from tradecut.effects.transitions import apply_transition
from tradecut.effects.zoom_pan import apply_zoom_effect
from tradecut.utils.audio import load_background_music
from tradecut.utils.export import PRESETS, get_ffmpeg_params
from tradecut.utils.image_prep import load_image, resize_to_vertical

logger = logging.getLogger(__name__)


class VideoComposer:
    """Assembles timeline segments into a final video with pro effects."""

    def __init__(self, timeline: Timeline, tts_enabled: bool = False, tts_voice: str = "ja-JP-NanamiNeural"):
        self.timeline = timeline
        self.bg_frame = create_gradient_frame()
        self.tts_enabled = tts_enabled
        self.tts_voice = tts_voice

    def _build_image_clip(self, segment: Segment) -> ImageClip:
        """Build a moviepy clip from an image segment."""
        canvas = self.bg_frame.copy()

        if segment.source and Path(segment.source).exists():
            img = load_image(segment.source)
            canvas = place_on_canvas(canvas, img, CHART_ZONE, fit_mode="fit")

            # Add rounded card background behind chart
            chart_bg_region = Region(
                CHART_ZONE.x - 10,
                CHART_ZONE.y - 10,
                CHART_ZONE.w + 20,
                CHART_ZONE.h + 20,
            )
            canvas_with_bg = add_rounded_rect(
                self.bg_frame.copy(), chart_bg_region, BACKGROUND_CARD, alpha=180
            )
            canvas = place_on_canvas(canvas_with_bg, img, CHART_ZONE, fit_mode="fit")

        # Add caption if present
        if segment.caption:
            canvas = render_caption(canvas, segment.caption, CAPTION_ZONE)

        frame_array = frame_to_numpy(canvas)
        clip = ImageClip(frame_array, duration=segment.duration)

        # Apply zoom/pan effects
        for effect in segment.effects:
            effect_type = effect.get("type", "")
            if effect_type in ("ken_burns", "focus_zoom", "slow_zoom"):
                clip = apply_zoom_effect(clip, effect)

        return clip

    def _build_title_clip(self, segment: Segment) -> VideoClip:
        """Build an animated title card clip."""
        return animated_title(
            text=segment.text,
            subtitle=segment.subtitle,
            duration=segment.duration,
            bg_frame=self.bg_frame.copy(),
        )

    def _build_pnl_clip(self, segment: Segment) -> VideoClip:
        """Build a P&L display with count-up animation."""
        metadata = segment.metadata
        pnl_pips = metadata.get("pnl_pips", 0)
        pnl_dollars = metadata.get("pnl_dollars", 0)
        result = metadata.get("result", "win")
        pair = metadata.get("pair", "")
        direction = metadata.get("direction", "long")

        from tradecut.assets.colors import get_result_color, get_direction_color
        result_color = get_result_color(result)

        # Prepare background with card and pair label
        canvas = self.bg_frame.copy()
        card_region = Region(80, HEIGHT // 2 - 250, WIDTH - 160, 500)
        canvas = add_rounded_rect(canvas, card_region, BACKGROUND_CARD, alpha=230, radius=30)

        # Add pair/direction header using glow text
        from tradecut.effects.text_overlay import _get_font, _draw_glow_text, _draw_glow_line
        pair_font = _get_font(48, bold=True)
        direction_color = get_direction_color(direction)
        pair_text = f"{pair} {'LONG' if direction == 'long' else 'SHORT'}"
        canvas = _draw_glow_text(canvas, pair_text, HEIGHT // 2 - 200, pair_font, direction_color, glow_radius=6)

        # Decorative glow line
        line_y = HEIGHT // 2 - 130
        canvas = _draw_glow_line(canvas, [(200, line_y), (WIDTH - 200, line_y)], result_color, width=2)

        # Use count_up animation for the pips number
        prefix = "+" if pnl_pips >= 0 else ""
        return count_up(
            end_value=pnl_pips,
            duration=segment.duration,
            prefix=prefix,
            suffix=" pips",
            bg_frame=canvas,
            color=result_color,
            font_size=96,
            count_duration=min(1.5, segment.duration * 0.6),
        )

    def _build_video_clip(self, segment: Segment) -> VideoFileClip:
        """Build a clip from a video file."""
        clip = VideoFileClip(str(segment.source))
        if segment.duration and clip.duration > segment.duration:
            clip = clip.subclipped(0, segment.duration)

        clip = clip.resized((WIDTH, HEIGHT))
        return clip

    def _build_segment_clip(self, segment: Segment):
        """Build the appropriate clip type for a segment."""
        builders = {
            "image": self._build_image_clip,
            "title_card": self._build_title_clip,
            "pnl_card": self._build_pnl_clip,
            "video": self._build_video_clip,
        }
        builder = builders.get(segment.segment_type, self._build_image_clip)
        return builder(segment)

    def _generate_se_track(self, segments: list[Segment], clip_start_times: list[float]) -> list[tuple]:
        """Generate sound effects for each segment.

        Returns list of (AudioClip, start_time) tuples.
        """
        se_entries = []

        for i, segment in enumerate(segments):
            start = clip_start_times[i]

            # Title cards get an impact sound
            if segment.segment_type == "title_card":
                se_entries.append((generate_impact(0.3, volume=0.4), start))

            # P&L cards get success or fail sound
            elif segment.segment_type == "pnl_card":
                result = segment.metadata.get("result", "win")
                if result == "win":
                    se_entries.append((generate_success(0.6, volume=0.35), start + 0.3))
                elif result == "loss":
                    se_entries.append((generate_fail(0.5, volume=0.3), start + 0.3))
                else:
                    se_entries.append((generate_notification(0.4, volume=0.25), start + 0.3))

            # Transition whoosh between segments
            if i > 0 and segment.transition_in not in ("cut", ""):
                se_entries.append((generate_whoosh(0.4, volume=0.25), max(0, start - 0.2)))

        return se_entries

    def _generate_tts_track(self, segments: list[Segment], clip_start_times: list[float]) -> list[tuple]:
        """Generate TTS narration for segments with captions.

        Returns list of (AudioClip, start_time) tuples.
        """
        if not self.tts_enabled:
            return []

        try:
            from tradecut.effects.tts import generate_tts
        except ImportError:
            logger.warning("TTS module not available")
            return []

        tts_entries = []
        for i, segment in enumerate(segments):
            text = segment.caption or segment.text
            if not text:
                continue

            start = clip_start_times[i]
            clip = generate_tts(text, voice=self.tts_voice)
            if clip is not None:
                # Trim TTS if longer than segment
                if clip.duration > segment.duration:
                    clip = clip.subclipped(0, segment.duration)
                tts_entries.append((clip, start + 0.3))  # slight delay for natural feel

        return tts_entries

    def compose(self) -> CompositeVideoClip:
        """Compose all segments into a single video with SE and TTS."""
        if not self.timeline.segments:
            raise ValueError("Timeline has no segments")

        clips = []
        for i, segment in enumerate(self.timeline.segments):
            logger.info(
                f"Building segment {i + 1}/{len(self.timeline.segments)}: "
                f"{segment.segment_type}"
            )
            clip = self._build_segment_clip(segment)
            clips.append(clip)

        # Apply transitions between clips
        final_clips = []
        for i, clip in enumerate(clips):
            segment = self.timeline.segments[i]
            if i > 0 and segment.transition_in != "cut":
                dur = segment.transition_duration
                clip = apply_transition(
                    clip, segment.transition_in, dur, direction="in"
                )
            if (
                i < len(clips) - 1
                and segment.transition_out != "cut"
            ):
                dur = segment.transition_duration
                clip = apply_transition(
                    clip, segment.transition_out, dur, direction="out"
                )
            final_clips.append(clip)

        video = concatenate_videoclips(final_clips, method="compose")

        # Calculate segment start times for audio placement
        clip_start_times = []
        current_time = 0.0
        for clip in final_clips:
            clip_start_times.append(current_time)
            current_time += clip.duration

        # Generate SE and TTS audio tracks
        se_entries = self._generate_se_track(self.timeline.segments, clip_start_times)
        tts_entries = self._generate_tts_track(self.timeline.segments, clip_start_times)

        # Combine all audio
        all_audio_entries = se_entries + tts_entries
        if all_audio_entries:
            audio_clips = []
            for audio_clip, start_time in all_audio_entries:
                audio_clips.append(audio_clip.with_start(start_time))

            # If video already has audio, include it
            if video.audio is not None:
                audio_clips.insert(0, video.audio)

            video = video.with_audio(CompositeAudioClip(audio_clips))

        return video

    def render(
        self,
        output_path: str | Path,
        platform: str = "tiktok",
        verbose: bool = True,
    ) -> Path:
        """Render the final video to disk.

        Args:
            output_path: Where to save the video.
            platform: Export preset to use (tiktok, shorts, preview).
            verbose: Show progress bar.

        Returns:
            Path to the rendered video file.
        """
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        preset = PRESETS.get(platform, PRESETS["tiktok"])
        params = get_ffmpeg_params(preset)

        video = self.compose()

        # Add background music if specified
        if self.timeline.background_music:
            music_path = Path(self.timeline.background_music)
            if music_path.exists():
                music = load_background_music(
                    music_path,
                    video.duration,
                    volume=self.timeline.music_volume,
                )
                # If we have TTS, duck the music volume during speech
                if self.tts_enabled:
                    music = music.with_volume_scaled(0.6)

                if video.audio is not None:
                    # Mix BGM with existing audio (SE + TTS)
                    video = video.with_audio(
                        CompositeAudioClip([music, video.audio])
                    )
                else:
                    video = video.with_audio(music)

        # Resize if preview
        if preset.width != WIDTH:
            video = video.resized((preset.width, preset.height))

        logger.info(f"Rendering {video.duration:.1f}s video to {output_path}")

        video.write_videofile(
            str(output_path),
            fps=preset.fps,
            codec=params["codec"],
            bitrate=params["bitrate"],
            audio_codec=params["audio_codec"],
            audio_bitrate=params["audio_bitrate"],
            logger="bar" if verbose else None,
        )

        video.close()
        logger.info(f"Done: {output_path}")
        return output_path
