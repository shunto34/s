"""Base template class for video generation."""

from __future__ import annotations

from abc import ABC, abstractmethod

from tradecut.config import ProjectConfig
from tradecut.core.timeline import Timeline


class BaseTemplate(ABC):
    """Abstract base class for video templates."""

    name: str = "base"
    description: str = "Base template"
    default_duration: float = 30.0

    def __init__(self, config: ProjectConfig):
        self.config = config

    @abstractmethod
    def build_timeline(self) -> Timeline:
        """Build the video timeline from project config.

        Returns:
            A Timeline object ready for rendering.
        """
        ...

    def _resolve_path(self, relative: str | None) -> str | None:
        """Resolve a material path relative to project directory."""
        if not relative:
            return None
        path = self.config.project_dir / relative
        if path.exists():
            return str(path)
        return None
