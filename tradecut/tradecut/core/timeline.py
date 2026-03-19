"""Timeline sequencing for video segments."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class Segment:
    """A single segment in the video timeline."""
    source: str | Path | None = None  # image or video path; None for generated frames
    duration: float = 3.0  # seconds
    segment_type: str = "image"  # image | video | title_card | pnl_card
    effects: list[dict[str, Any]] = field(default_factory=list)
    transition_in: str = "fade"  # fade | slide_left | slide_up | cut | glitch
    transition_out: str = "fade"
    transition_duration: float = 0.5
    text: str = ""
    subtitle: str = ""
    caption: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass
class Timeline:
    """Ordered sequence of segments that compose a video."""
    segments: list[Segment] = field(default_factory=list)
    background_music: str | None = None
    music_volume: float = 0.15
    total_target_duration: float = 30.0

    def add_segment(self, segment: Segment) -> None:
        self.segments.append(segment)

    def add_title_card(
        self,
        text: str,
        subtitle: str = "",
        duration: float = 2.0,
        transition_in: str = "fade",
    ) -> None:
        self.segments.append(Segment(
            segment_type="title_card",
            duration=duration,
            text=text,
            subtitle=subtitle,
            transition_in=transition_in,
        ))

    def add_image(
        self,
        path: str | Path,
        duration: float = 5.0,
        caption: str = "",
        effects: list[dict[str, Any]] | None = None,
        transition_in: str = "fade",
    ) -> None:
        self.segments.append(Segment(
            source=str(path),
            segment_type="image",
            duration=duration,
            caption=caption,
            effects=effects or [],
            transition_in=transition_in,
        ))

    def add_video(
        self,
        path: str | Path,
        duration: float | None = None,
        caption: str = "",
        transition_in: str = "fade",
    ) -> None:
        self.segments.append(Segment(
            source=str(path),
            segment_type="video",
            duration=duration or 5.0,
            caption=caption,
            transition_in=transition_in,
        ))

    def add_pnl_card(
        self,
        duration: float = 3.0,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        self.segments.append(Segment(
            segment_type="pnl_card",
            duration=duration,
            metadata=metadata or {},
        ))

    @property
    def total_duration(self) -> float:
        return sum(s.duration for s in self.segments)

    @property
    def segment_count(self) -> int:
        return len(self.segments)

    def validate(self) -> list[str]:
        """Check timeline for issues. Returns list of warnings."""
        warnings = []
        if not self.segments:
            warnings.append("Timeline has no segments")
        total = self.total_duration
        if total > 60:
            warnings.append(
                f"Total duration ({total:.1f}s) exceeds YouTube Shorts limit (60s)"
            )
        for i, seg in enumerate(self.segments):
            if seg.segment_type in ("image", "video") and seg.source:
                if not Path(seg.source).exists():
                    warnings.append(f"Segment {i}: file not found: {seg.source}")
        return warnings
