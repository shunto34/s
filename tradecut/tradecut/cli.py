"""CLI entry point for TradeCut."""

from __future__ import annotations

import logging
import shutil
from pathlib import Path

import click
import yaml

from tradecut.config import ProjectConfig, load_config
from tradecut.core.composer import VideoComposer
from tradecut.core.timeline import Timeline
from tradecut.templates.trade_recap import TradeRecapTemplate
from tradecut.templates.signal_showcase import SignalShowcaseTemplate
from tradecut.templates.pnl_summary import PnlSummaryTemplate

TEMPLATES = {
    "trade_recap": TradeRecapTemplate,
    "signal_showcase": SignalShowcaseTemplate,
    "pnl_summary": PnlSummaryTemplate,
}

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)


@click.group()
@click.version_option(version="0.1.0")
def main():
    """TradeCut - Trading video automation for TikTok/YouTube Shorts."""
    pass


@main.command()
@click.argument("name")
@click.option(
    "--template", "-t",
    type=click.Choice(list(TEMPLATES.keys())),
    default="trade_recap",
    help="Template to use for the project.",
)
def new(name: str, template: str):
    """Create a new video project."""
    project_dir = Path(name)

    if project_dir.exists():
        click.echo(f"Error: Directory '{name}' already exists.", err=True)
        raise SystemExit(1)

    # Create project structure
    project_dir.mkdir(parents=True)
    (project_dir / "materials").mkdir()

    # Generate project.yaml
    config = {
        "template": template,
        "duration": 30,
        "trade": {
            "pair": "USDJPY",
            "direction": "long",
            "entry_price": 0.0,
            "exit_price": 0.0,
            "pnl_pips": 0,
            "pnl_dollars": 0.0,
            "result": "win",
        },
        "materials": {
            "context_chart": "materials/h1_chart.png",
            "entry_chart": "materials/entry_chart.png",
            "result_chart": "materials/result_chart.png",
        },
        "style": {
            "color_scheme": "vlm_default",
            "background_music": None,
            "music_volume": 0.15,
            "tts_enabled": False,
            "tts_voice": "ja-JP-NanamiNeural",
            "sound_effects": True,
        },
        "captions": {
            "context": "上位足の環境認識",
            "entry": "エントリーポイント",
            "progress": "トレード経過",
            "result": "トレード結果",
        },
        "output": {
            "filename": name,
            "platforms": ["tiktok", "shorts"],
        },
    }

    with open(project_dir / "project.yaml", "w") as f:
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

    click.echo(f"Created project: {project_dir}/")
    click.echo(f"  Template: {template}")
    click.echo(f"  Config:   {project_dir}/project.yaml")
    click.echo(f"  Materials: {project_dir}/materials/")
    click.echo("")
    click.echo("Next steps:")
    click.echo("  1. Place chart screenshots in materials/")
    click.echo("  2. Edit project.yaml with trade details")
    click.echo(f"  3. Run: tradecut build {name}/")


@main.command()
@click.argument("project_path")
@click.option(
    "--platform", "-p",
    type=click.Choice(["tiktok", "shorts", "preview"]),
    default="tiktok",
    help="Export platform preset.",
)
@click.option("--output", "-o", default=None, help="Output file path.")
@click.option("--quiet", "-q", is_flag=True, help="Suppress progress output.")
def build(project_path: str, platform: str, output: str | None, quiet: bool):
    """Build a video from a project."""
    config = load_config(project_path)

    # Determine template
    template_cls = TEMPLATES.get(config.template)
    if not template_cls:
        click.echo(
            f"Error: Unknown template '{config.template}'. "
            f"Available: {', '.join(TEMPLATES.keys())}",
            err=True,
        )
        raise SystemExit(1)

    template = template_cls(config)
    timeline = template.build_timeline()

    # Validate timeline
    warnings = timeline.validate()
    for w in warnings:
        click.echo(f"Warning: {w}", err=True)

    # Determine output path
    if output:
        output_path = Path(output)
    else:
        output_dir = config.project_dir / "output"
        ext = ".mp4"
        output_path = output_dir / f"{config.output_filename}_{platform}{ext}"

    click.echo(f"Building video...")
    click.echo(f"  Template:  {config.template}")
    click.echo(f"  Segments:  {timeline.segment_count}")
    click.echo(f"  Duration:  {timeline.total_duration:.1f}s")
    click.echo(f"  Platform:  {platform}")
    click.echo(f"  Output:    {output_path}")
    click.echo("")

    composer = VideoComposer(
        timeline,
        tts_enabled=config.style.tts_enabled,
        tts_voice=config.style.tts_voice,
    )
    result_path = composer.render(
        output_path,
        platform=platform,
        verbose=not quiet,
    )

    click.echo(f"\nDone! Video saved to: {result_path}")


@main.command()
@click.argument("project_path")
def preview(project_path: str):
    """Quick low-quality preview of a project."""
    config = load_config(project_path)

    template_cls = TEMPLATES.get(config.template)
    if not template_cls:
        click.echo(f"Error: Unknown template '{config.template}'", err=True)
        raise SystemExit(1)

    template = template_cls(config)
    timeline = template.build_timeline()

    output_dir = config.project_dir / "output"
    output_path = output_dir / f"{config.output_filename}_preview.mp4"

    click.echo(f"Generating preview ({timeline.total_duration:.1f}s)...")

    composer = VideoComposer(
        timeline,
        tts_enabled=config.style.tts_enabled,
        tts_voice=config.style.tts_voice,
    )
    result_path = composer.render(output_path, platform="preview", verbose=True)

    click.echo(f"\nPreview saved to: {result_path}")


@main.command(name="templates")
def list_templates():
    """List available video templates."""
    click.echo("Available templates:\n")
    for name, cls in TEMPLATES.items():
        t = cls.__new__(cls)
        click.echo(f"  {name}")
        click.echo(f"    {cls.description}")
        click.echo(f"    Default duration: {cls.default_duration}s")
        click.echo("")


if __name__ == "__main__":
    main()
