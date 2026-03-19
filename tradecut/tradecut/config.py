"""Project configuration loading and validation."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


@dataclass
class TradeInfo:
    pair: str = "USDJPY"
    direction: str = "long"  # long | short
    entry_price: float = 0.0
    exit_price: float = 0.0
    pnl_pips: float = 0.0
    pnl_dollars: float = 0.0
    result: str = "win"  # win | loss | breakeven


@dataclass
class Materials:
    context_chart: str | None = None
    entry_chart: str | None = None
    progress_clip: str | None = None
    result_chart: str | None = None
    extra_images: list[str] = field(default_factory=list)


@dataclass
class Style:
    color_scheme: str = "vlm_default"
    font: str = "Montserrat-Bold"
    background_music: str | None = None
    music_volume: float = 0.15
    watermark: str | None = None
    watermark_opacity: float = 0.6


@dataclass
class Captions:
    context: str = ""
    entry: str = ""
    progress: str = ""
    result: str = ""


@dataclass
class ProjectConfig:
    template: str = "trade_recap"
    duration: float = 30.0
    trade: TradeInfo = field(default_factory=TradeInfo)
    materials: Materials = field(default_factory=Materials)
    style: Style = field(default_factory=Style)
    captions: Captions = field(default_factory=Captions)
    output_filename: str = "output"
    platforms: list[str] = field(default_factory=lambda: ["tiktok", "shorts"])
    project_dir: Path = field(default_factory=lambda: Path("."))


def _build_dataclass(cls: type, data: dict[str, Any]) -> Any:
    """Build a dataclass from a dict, ignoring unknown keys."""
    valid_fields = {f.name for f in cls.__dataclass_fields__.values()}
    filtered = {k: v for k, v in data.items() if k in valid_fields}
    return cls(**filtered)


def load_config(path: str | Path) -> ProjectConfig:
    """Load a project configuration from a YAML file."""
    path = Path(path)

    if path.is_dir():
        path = path / "project.yaml"

    if not path.exists():
        raise FileNotFoundError(f"Config not found: {path}")

    with open(path) as f:
        raw = yaml.safe_load(f) or {}

    project_dir = path.parent

    config = ProjectConfig(
        template=raw.get("template", "trade_recap"),
        duration=float(raw.get("duration", 30)),
        output_filename=raw.get("output", {}).get("filename", "output"),
        platforms=raw.get("output", {}).get("platforms", ["tiktok", "shorts"]),
        project_dir=project_dir,
    )

    if "trade" in raw:
        config.trade = _build_dataclass(TradeInfo, raw["trade"])

    if "materials" in raw:
        config.materials = _build_dataclass(Materials, raw["materials"])

    if "style" in raw:
        config.style = _build_dataclass(Style, raw["style"])

    if "captions" in raw:
        config.captions = _build_dataclass(Captions, raw["captions"])

    return config


def resolve_material_path(config: ProjectConfig, relative_path: str) -> Path:
    """Resolve a material path relative to the project directory."""
    p = Path(relative_path)
    if p.is_absolute():
        return p
    return config.project_dir / p
