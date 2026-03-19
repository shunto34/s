"""Main video composition pipeline."""

from __future__ import annotations

import logging
from pathlib import Path

import numpy as np
from moviepy import (
    AudioFileClip,
    CompositeVideoClip,
    ImageClip,
    VideoFileClip,
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
from tradecut.effects.transitions import apply_transition
from tradecut.effects.zoom_pan import apply_zoom_effect
from tradecut.utils.audio import load_background_music
from tradecut.utils.export import PRESETS, get_ffmpeg_params
from tradecut.utils.image_prep import load_image, resize_to_vertical

logger = logging.getLogger(__name__)


class VideoComposer:
    """Assembles timeline segments into a final video."""

    def __init__(self, timeline: Timeline):
        self.timeline = timeline
        self.bg_frame = create_gradient_frame()

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
            # We add the card bg first, then re-place the image
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

    def _build_title_clip(self, segment: Segment) -> ImageClip:
        """Build a title card clip."""
        canvas = render_title_card(
            self.bg_frame.copy(),
            segment.text,
            segment.subtitle,
        )
        frame_array = frame_to_numpy(canvas)
        return ImageClip(frame_array, duration=segment.duration)

    def _build_pnl_clip(self, segment: Segment) -> ImageClip:
        """Build a P&L display clip."""
        canvas = render_pnl_card(self.bg_frame.copy(), segment.metadata)
        frame_array = frame_to_numpy(canvas)
        return ImageClip(frame_array, duration=segment.duration)

    def _build_video_clip(self, segment: Segment) -> VideoFileClip:
        """Build a clip from a video file."""
        clip = VideoFileClip(str(segment.source))
        if segment.duration and clip.duration > segment.duration:
            clip = clip.subclipped(0, segment.duration)

        # Resize to fit canvas
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

    def compose(self) -> CompositeVideoClip:
        """Compose all segments into a single video clip."""
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
