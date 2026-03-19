"""Signal showcase template - highlights a trading signal.

Structure (default 20s):
1. Hook text (2s) - attention-grabbing result
2. Indicator screenshot (6s) - full indicator view with zoom
3. Multi-timeframe grid (5s) - show MTF alignment
4. Signal explanation (4s) - annotated chart
5. CTA (3s) - call to action
"""

from __future__ import annotations

from tradecut.config import ProjectConfig
from tradecut.core.timeline import Timeline
from tradecut.templates.base import BaseTemplate


class SignalShowcaseTemplate(BaseTemplate):
    name = "signal_showcase"
    description = "Showcase a trading signal with indicator details"
    default_duration = 20.0

    def build_timeline(self) -> Timeline:
        trade = self.config.trade
        materials = self.config.materials
        captions = self.config.captions

        timeline = Timeline(total_target_duration=self.config.duration)

        # Background music
        if self.config.style.background_music:
            music_path = self._resolve_path(self.config.style.background_music)
            if music_path:
                timeline.background_music = music_path
                timeline.music_volume = self.config.style.music_volume

        # 1. Hook
        pips_sign = "+" if trade.pnl_pips >= 0 else ""
        timeline.add_title_card(
            text=f"This signal caught {pips_sign}{trade.pnl_pips:.0f} pips",
            subtitle=trade.pair,
            duration=2.0,
            transition_in="glitch",
        )

        # 2. Indicator screenshot
        entry_path = self._resolve_path(materials.entry_chart)
        if entry_path:
            timeline.add_image(
                path=entry_path,
                duration=6.0,
                caption=captions.entry or "Signal detected by Visual Logic Masterpiece",
                effects=[{
                    "type": "ken_burns",
                    "start_zoom": 1.0,
                    "end_zoom": 1.2,
                    "center": (0.5, 0.4),
                }],
                transition_in="fade",
            )

        # 3. Context / MTF
        context_path = self._resolve_path(materials.context_chart)
        if context_path:
            timeline.add_image(
                path=context_path,
                duration=5.0,
                caption=captions.context or "Multi-timeframe confirmation",
                effects=[{"type": "slow_zoom", "end_zoom": 1.08}],
                transition_in="slide_left",
            )

        # 4. Result
        result_path = self._resolve_path(materials.result_chart)
        if result_path:
            timeline.add_image(
                path=result_path,
                duration=4.0,
                caption=captions.result or f"Result: {pips_sign}{trade.pnl_pips:.0f} pips",
                effects=[{"type": "slow_zoom", "end_zoom": 1.05}],
                transition_in="fade",
            )

        # 5. CTA
        timeline.add_title_card(
            text="Get the indicator",
            subtitle="Link in bio",
            duration=3.0,
            transition_in="fade",
        )

        return timeline
