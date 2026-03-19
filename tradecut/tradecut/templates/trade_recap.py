"""Trade recap template - the primary video format.

Structure (default 30s):
1. Intro card (2s) - pair, direction, result
2. Context chart (5s) - higher timeframe with slow zoom
3. Entry chart (6s) - entry point with annotation
4. Trade progress (5s) - price movement or clip
5. Result chart (5s) - exit with highlight
6. P&L card (3s) - profit/loss display
7. Outro card (4s) - CTA
"""

from __future__ import annotations

from tradecut.config import ProjectConfig
from tradecut.core.timeline import Segment, Timeline
from tradecut.templates.base import BaseTemplate


class TradeRecapTemplate(BaseTemplate):
    name = "trade_recap"
    description = "Trade recap video showing entry, progress, and result"
    default_duration = 30.0

    def build_timeline(self) -> Timeline:
        trade = self.config.trade
        materials = self.config.materials
        captions = self.config.captions
        style = self.config.style

        timeline = Timeline(
            total_target_duration=self.config.duration,
        )

        # Set background music
        if style.background_music:
            music_path = self._resolve_path(style.background_music)
            if music_path:
                timeline.background_music = music_path
                timeline.music_volume = style.music_volume

        # 1. Intro title card
        direction_label = "LONG" if trade.direction == "long" else "SHORT"
        pips_sign = "+" if trade.pnl_pips >= 0 else ""
        title = f"{trade.pair} {direction_label}"
        subtitle = f"{pips_sign}{trade.pnl_pips:.0f} pips | ${abs(trade.pnl_dollars):.0f}"

        timeline.add_title_card(
            text=title,
            subtitle=subtitle,
            duration=2.0,
            transition_in="fade",
        )

        # 2. Context chart (higher timeframe)
        context_path = self._resolve_path(materials.context_chart)
        if context_path:
            timeline.add_image(
                path=context_path,
                duration=5.0,
                caption=captions.context or f"{trade.pair} higher timeframe analysis",
                effects=[{"type": "slow_zoom", "end_zoom": 1.1}],
                transition_in="fade",
            )

        # 3. Entry chart
        entry_path = self._resolve_path(materials.entry_chart)
        if entry_path:
            timeline.add_image(
                path=entry_path,
                duration=6.0,
                caption=captions.entry or f"Entry signal on {trade.pair}",
                effects=[{
                    "type": "focus_zoom",
                    "target": (0.5, 0.5),
                    "max_zoom": 1.3,
                    "hold_ratio": 0.4,
                }],
                transition_in="slide_up",
            )

        # 4. Trade progress
        progress_path = self._resolve_path(materials.progress_clip)
        if progress_path:
            if progress_path.endswith((".mp4", ".mov", ".avi")):
                timeline.add_video(
                    path=progress_path,
                    duration=5.0,
                    caption=captions.progress or "Trade in progress",
                    transition_in="fade",
                )
            else:
                timeline.add_image(
                    path=progress_path,
                    duration=5.0,
                    caption=captions.progress or "Trade in progress",
                    effects=[{"type": "slow_zoom", "end_zoom": 1.08}],
                    transition_in="fade",
                )

        # 5. Result chart
        result_path = self._resolve_path(materials.result_chart)
        if result_path:
            timeline.add_image(
                path=result_path,
                duration=5.0,
                caption=captions.result or f"Result: {pips_sign}{trade.pnl_pips:.0f} pips",
                effects=[{"type": "slow_zoom", "end_zoom": 1.05}],
                transition_in="slide_left",
            )

        # 6. P&L card
        timeline.add_pnl_card(
            duration=3.0,
            metadata={
                "pair": trade.pair,
                "direction": trade.direction,
                "pnl_pips": trade.pnl_pips,
                "pnl_dollars": trade.pnl_dollars,
                "result": trade.result,
            },
        )

        # 7. Outro
        timeline.add_title_card(
            text="Follow for more signals",
            subtitle="",
            duration=4.0,
            transition_in="fade",
        )

        # If no materials provided, add placeholder segments
        if timeline.segment_count <= 3:
            # Only intro + P&L + outro exist, add placeholders
            timeline.segments.insert(1, Segment(
                segment_type="title_card",
                duration=5.0,
                text=f"{trade.pair} Analysis",
                subtitle=f"Direction: {direction_label}",
                transition_in="fade",
            ))

        return timeline
