"""Luxel Epic Themes package: data-driven + subclassable ground, layer & scenery painters."""
from __future__ import annotations

from pathlib import Path
from typing import Any

from .base import ThemePainter, ThemeSpec
from .layers import paint_layers
from .registry import ALIASES, get_spec, get_theme, has_theme, list_themes, resolve_theme_id


def paint_themed_map(
    grid: list[list[str]],
    out_path: Path,
    theme_id: str,
    ts: int = 16,
    meta: dict[str, Any] | None = None,
    organic_override: bool | None = None,
    paint_dynamic_layers: bool = True,
) -> tuple[Path, list[Path]]:
    """Paint a map grid using `theme_id` and any JSON `layers` overlays."""
    painter = get_theme(theme_id)
    meta = meta or {}
    im = painter.paint(grid, ts=ts, meta=meta, organic_override=organic_override)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    im.save(out_path)

    layer_paths: list[Path] = []
    if paint_dynamic_layers and meta.get("layers"):
        layer_paths = paint_layers(
            grid,
            out_path,
            painter,
            meta,
            get_theme,
            ts=ts,
            organic_override=organic_override,
        )
    return out_path, layer_paths


__all__ = [
    "ALIASES",
    "ThemePainter",
    "ThemeSpec",
    "get_spec",
    "get_theme",
    "has_theme",
    "list_themes",
    "paint_layers",
    "paint_themed_map",
    "resolve_theme_id",
]
