"""Dynamic layer overlay painter for Region JSON `layers` (tide, worlds, midnight).

Writes `<region_stem>__<layer_id>.png` in strict 20-colour Last Light RGBA:
- Tile-patch layers (`tiles: [[tx, ty, tw, th, tile_type], ...]`) paint ONLY the patched
  region plus a crisp 4px edge margin (alpha=255), leaving untouched pixels alpha=0 so the
  overlay composites cleanly over `<region>_ground.png`.
- Full-swap layers (`theme` override, `tint: "midnight"`, or `full_frame: true`) paint the
  entire room in the alternate state (alpha=255).
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np

from .base import ThemePainter
from .kit import COOL_IX, IX, SHADE_IX, buf_to_image, verify_image_palette

# Midnight tint LUT: shifts warm sunlit tones toward hushed moonlit night/deep/dusk/ice
MIDNIGHT_LUT = np.array(
    [
        IX[
            {
                "void": "void",
                "night": "void",
                "dusk": "night",
                "plum": "dusk",
                "wine": "plum",
                "coral": "wine",
                "apricot": "mauve",
                "gold": "ice",
                "cream": "ice",
                "pine": "night",
                "teal": "pine",
                "jade": "teal",
                "lime": "sky",
                "deep": "night",
                "blue": "deep",
                "sky": "blue",
                "ice": "sky",
                "mauve": "dusk",
                "stone": "sky",
                "rose": "mauve",
            }[name]
        ]
        for name in (
            "void", "night", "dusk", "plum", "wine", "coral", "apricot", "gold", "cream",
            "pine", "teal", "jade", "lime", "deep", "blue", "sky", "ice", "mauve", "stone", "rose",
        )
    ],
    dtype=np.uint8,
)


def _apply_tile_patches(grid: list[list[str]], patches: list[Any]) -> tuple[list[list[str]], list[tuple[int, int, int, int]]]:
    h = len(grid)
    w = len(grid[0]) if h else 0
    patched = [list(row) for row in grid]
    rects: list[tuple[int, int, int, int]] = []
    for p in patches:
        if not (isinstance(p, list) and len(p) >= 5):
            continue
        tx, ty, tw, th, ttype = int(p[0]), int(p[1]), int(p[2]), int(p[3]), str(p[4]).strip().lower()
        x0 = max(0, tx)
        y0 = max(0, ty)
        x1 = min(w, tx + tw)
        y1 = min(h, ty + th)
        if x1 <= x0 or y1 <= y0:
            continue
        for r in range(y0, y1):
            for c in range(x0, x1):
                patched[r][c] = ttype
        rects.append((x0, y0, x1, y1))
    return patched, rects


def paint_layers(
    grid: list[list[str]],
    base_out_path: Path,
    base_painter: ThemePainter,
    meta: dict[str, Any],
    get_theme_fn: Any,
    ts: int = 16,
    organic_override: bool | None = None,
) -> list[Path]:
    """Paint `<region>__<layer_id>.png` for every layer in `meta['layers']`."""
    layers = meta.get("layers", [])
    if not isinstance(layers, list) or not layers:
        return []

    h_t = len(grid)
    w_t = len(grid[0]) if h_t else 0
    H, W = h_t * ts, w_t * ts

    # Strip trailing `_ground` if present so `<region>_ground.png` -> `<region>__<layer>.png`
    stem = base_out_path.stem
    if stem.endswith("_ground"):
        region_prefix = stem[: -len("_ground")]
    else:
        region_prefix = stem

    written: list[Path] = []
    for layer in layers:
        if not isinstance(layer, dict):
            continue
        lid = str(layer.get("id", "")).strip()
        if not lid:
            continue

        patches = layer.get("tiles", [])
        if not isinstance(patches, list):
            patches = []
        patched_grid, tile_rects = _apply_tile_patches(grid, patches)

        layer_theme_id = str(layer.get("theme", "")).strip()
        painter = get_theme_fn(layer_theme_id) if layer_theme_id else base_painter

        tint = str(layer.get("tint", "")).strip().lower()
        if not tint and ("midnight" in lid.lower() or "midnight" in str(layer.get("when", "")).lower()):
            tint = "midnight"

        layer_meta = dict(meta)
        if isinstance(layer.get("decor"), list):
            layer_meta["decor"] = layer["decor"]

        buf, _ = painter.paint_buffer(patched_grid, ts=ts, meta=layer_meta, organic_override=organic_override)

        if tint == "midnight":
            buf = MIDNIGHT_LUT[buf]

        full_frame = bool(layer.get("full_frame", False)) or (tint == "midnight") or (not tile_rects)

        if full_frame:
            im = buf_to_image(buf)
        else:
            # Transparent outside patched tiles (+ 4px margin for clean rims & AO edges)
            alpha = np.zeros((H, W), dtype=bool)
            margin = 4
            for x0, y0, x1, y1 in tile_rects:
                px0 = max(0, x0 * ts - margin)
                py0 = max(0, y0 * ts - margin)
                px1 = min(W, x1 * ts + margin)
                py1 = min(H, y1 * ts + margin)
                alpha[py0:py1, px0:px1] = True
            im = buf_to_image(buf, alpha_mask=alpha)

        out_layer_path = base_out_path.parent / f"{region_prefix}__{lid}.png"
        verify_image_palette(im, f"layer:{out_layer_path.name}")
        out_layer_path.parent.mkdir(parents=True, exist_ok=True)
        im.save(out_layer_path)
        written.append(out_layer_path)

    return written
