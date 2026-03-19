"""P&L summary template - weekly/monthly trading results.

Structure (default 25s):
1. Title (2s) - period and header
2. Trade cards (3s each, up to 5) - individual trade results
3. Total P&L (3s) - aggregated result
4. Outro (3s) - CTA
"""

from __future__ import annotations

from tradecut.config import ProjectConfig
from tradecut.core.timeline import Segment, Timeline
from tradecut.templates.base import BaseTemplate


class PnlSummaryTemplate(BaseTemplate):
    name = "pnl_summary"
    description = "Weekly or monthly P&L summary with multiple trades"
    default_duration = 25.0

    def build_timeline(self) -> Timeline:
        trade = self.config.trade
        timeline = Timeline(total_target_duration=self.config.duration)

        # Background music
        if self.config.style.background_music:
            music_path = self._resolve_path(self.config.style.background_music)
            if music_path:
                timeline.background_music = music_path
                timeline.music_volume = self.config.style.music_volume

        # 1. Title card
        timeline.add_title_card(
            text="Trading Results",
            subtitle=f"{trade.pair} | Weekly Summary",
            duration=2.0,
            transition_in="fade",
        )

        # 2. Individual trade card (using main trade info)
        # In a full implementation, the YAML would contain a list of trades.
        # For now, show the single configured trade.
        timeline.add_pnl_card(
            duration=4.0,
            metadata={
                "pair": trade.pair,
                "direction": trade.direction,
                "pnl_pips": trade.pnl_pips,
                "pnl_dollars": trade.pnl_dollars,
                "result": trade.result,
            },
        )

        # 3. Show charts if available
        for chart_attr in ["context_chart", "entry_chart", "result_chart"]:
            chart_path = getattr(self.config.materials, chart_attr, None)
            if chart_path:
                resolved = self._resolve_path(chart_path)
                if resolved:
                    timeline.add_image(
                        path=resolved,
                        duration=3.0,
                        effects=[{"type": "slow_zoom", "end_zoom": 1.06}],
                        transition_in="fade",
                    )

        # 4. Total P&L summary
        pips_sign = "+" if trade.pnl_pips >= 0 else ""
        timeline.add_title_card(
            text=f"Total: {pips_sign}{trade.pnl_pips:.0f} pips",
            subtitle=f"${abs(trade.pnl_dollars):.2f}",
            duration=3.0,
            transition_in="slide_up",
        )

        # 5. Outro
        timeline.add_title_card(
            text="Follow for weekly updates",
            subtitle="",
            duration=3.0,
            transition_in="fade",
        )

        return timeline
