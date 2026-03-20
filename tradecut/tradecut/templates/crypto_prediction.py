"""Crypto prediction template - price forecast video.

Structure (default 25s):
1. Hook (2s) - attention-grabbing prediction headline
2. Higher TF chart (5s) - context/pattern analysis
3. Lower TF chart (6s) - signal confirmation (BOS, MSS, etc.)
4. Target card (4s) - price target with count-up animation
5. CTA (3s) - follow call to action
"""

from __future__ import annotations

from tradecut.config import ProjectConfig
from tradecut.core.timeline import Segment, Timeline
from tradecut.templates.base import BaseTemplate


class CryptoPredictionTemplate(BaseTemplate):
    name = "crypto_prediction"
    description = "Crypto price prediction video with target visualization"
    default_duration = 25.0

    def build_timeline(self) -> Timeline:
        trade = self.config.trade
        materials = self.config.materials
        captions = self.config.captions
        style = self.config.style

        timeline = Timeline(total_target_duration=self.config.duration)

        # Background music
        if style.background_music:
            music_path = self._resolve_path(style.background_music)
            if music_path:
                timeline.background_music = music_path
                timeline.music_volume = style.music_volume

        # 1. Hook - attention-grabbing prediction headline
        direction_label = "LONG" if trade.direction == "long" else "SHORT"
        target_price = trade.exit_price
        hook_text = f"BTC ${target_price:,.0f} ぶち上げ確定!?"
        timeline.add_title_card(
            text=hook_text,
            subtitle=f"{trade.pair} {direction_label}",
            duration=2.0,
            transition_in="glitch",
        )

        # 2. Higher TF chart - pattern/context analysis
        context_path = self._resolve_path(materials.context_chart)
        if context_path:
            timeline.add_image(
                path=context_path,
                duration=5.0,
                caption=captions.context or "上位足パターン分析",
                effects=[{
                    "type": "ken_burns",
                    "start_zoom": 1.0,
                    "end_zoom": 1.15,
                    "center": (0.5, 0.4),
                }],
                transition_in="fade",
            )

        # 3. Lower TF chart - signal confirmation
        entry_path = self._resolve_path(materials.entry_chart)
        if entry_path:
            timeline.add_image(
                path=entry_path,
                duration=6.0,
                caption=captions.entry or "シグナル確認",
                effects=[{
                    "type": "focus_zoom",
                    "target": (0.5, 0.45),
                    "max_zoom": 1.3,
                    "hold_ratio": 0.4,
                }],
                transition_in="slide_left",
            )

        # 4. Target price card - uses P&L card with prediction data
        current_price = trade.entry_price
        upside = ((target_price - current_price) / current_price) * 100 if current_price > 0 else 0
        timeline.add_pnl_card(
            duration=4.0,
            metadata={
                "pair": trade.pair,
                "direction": trade.direction,
                "pnl_pips": target_price - current_price,
                "pnl_dollars": target_price,
                "result": "win",
            },
        )

        # 5. Extra charts (if provided)
        result_path = self._resolve_path(materials.result_chart)
        if result_path:
            timeline.add_image(
                path=result_path,
                duration=4.0,
                caption=captions.result or "追加分析",
                effects=[{"type": "slow_zoom", "end_zoom": 1.08}],
                transition_in="fade",
            )

        # 6. CTA
        timeline.add_title_card(
            text="フォローで爆益シグナル配信",
            subtitle="いいね & 保存で応援よろしく",
            duration=3.0,
            transition_in="fade",
        )

        return timeline
