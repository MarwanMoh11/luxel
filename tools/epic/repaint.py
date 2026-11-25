#!/usr/bin/env python3
"""Smart incremental ground & layer repainter for Luxel Epic (uv + pillow + numpy).

For each targeted region, paints `<region>_ground.png` and every required
`<region>__<layer_id>.png` into memory using the region's current `.map`, `.json`,
and theme (or legacy biome painter when no `"theme"` is set), compares pixels
against the existing PNG on disk, lists stale/missing ones, and writes ONLY
those that differ or are missing.

Protects hand-tuned ground PNGs (e.g. `1:overworld`, `2:overworld`) unless
`--force-protected` is explicitly passed.

Usage:
  uv run --no-project --with pillow --with numpy python tools/epic/repaint.py --island 1 --check
  uv run --no-project --with pillow --with numpy python tools/epic/repaint.py --island 0 --island 1 --island 2
  uv run --no-project --with pillow --with numpy python tools/epic/repaint.py --region 2:lighthouse_r1
  uv run --no-project --with pillow --with numpy python tools/epic/repaint.py --all --check
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

import numpy as np
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
LEGACY_MAPS_DIR = REPO_ROOT / "docs" / "fullgame" / "swarm" / "tools" / "maps"
if str(LEGACY_MAPS_DIR) not in sys.path:
    sys.path.insert(0, str(LEGACY_MAPS_DIR))

import paint as legacy_paint  # noqa: E402
from tools.epic.themes import get_theme, resolve_theme_id  # noqa: E402
from tools.epic.themes.kit import IX, buf_to_image, verify_image_palette  # noqa: E402
from tools.epic.themes.layers import MIDNIGHT_LUT, _apply_tile_patches  # noqa: E402

# Hand-tuned grounds that differ materially from procedural painters; never overwrite by default.
HAND_TUNED_GROUNDS = {
    "1:overworld",
    "2:overworld",
}


def _paint_legacy_buffer(
    grid: list[list[str]],
    ts: int,
    meta: Dict[str, Any],
    island_id: int,
    organic: bool = True,
) -> np.ndarray:
    """Paint a non-themed region using legacy paint.py rules into a Last Light palette-index buffer."""
    h = len(grid)
    w = len(grid[0]) if h else 0
    img_w, img_h = w * ts, h * ts
    is_dungeon = bool(meta.get("is_dungeon", False))
    resolved_island = max(1, min(8, int(meta.get("island_id", island_id) or island_id or 1)))
    use_organic = organic and not is_dungeon
    bio = (legacy_paint.DUNGEON_BIOMES if is_dungeon else legacy_paint.BIOMES).get(
        resolved_island,
        legacy_paint.DUNGEON_BIOMES[1] if is_dungeon else legacy_paint.BIOMES[1],
    )

    im = Image.new("RGBA", (img_w, img_h), legacy_paint.RGBA["void"])
    px = im.load()
    col_grid: list[list[str]] = [["void"] * img_w for _ in range(img_h)]
    land_mask: list[list[bool]] = [[False] * img_w for _ in range(img_h)]

    for ty in range(h):
        for tx in range(w):
            base_t = grid[ty][tx]
            up_t = legacy_paint._tile(grid, tx, ty - 1, w, h)
            down_t = legacy_paint._tile(grid, tx, ty + 1, w, h)
            left_t = legacy_paint._tile(grid, tx - 1, ty, w, h)
            right_t = legacy_paint._tile(grid, tx + 1, ty, w, h)
            nw_t = legacy_paint._tile(grid, tx - 1, ty - 1, w, h)
            tile_h = legacy_paint.hash01(tx, ty, 41)
            x0, y0 = tx * ts, ty * ts
            for ly in range(ts):
                wy = y0 + ly
                for lx in range(ts):
                    wx = x0 + lx
                    ttype = (
                        legacy_paint._resolve_organic_tile(grid, tx, ty, lx, ly, ts, w, h, wx, wy)
                        if use_organic
                        else base_t
                    )
                    land_mask[wy][wx] = ttype in legacy_paint.LAND_TILES
                    warm = legacy_paint.warmth(wx * (legacy_paint.core.W / float(max(1, img_w))))
                    col = legacy_paint._paint_pixel(
                        wx, wy, lx, ly, ts, ttype, warm, up_t, down_t, left_t, right_t, tile_h, bio
                    )
                    walk_t = ttype in ("ground", "path", "bramble", "cracked")
                    if walk_t and up_t == "wall" and ly < 4:
                        if ly == 0 or legacy_paint.dither(wx, wy, 1.0 - ly / 4.5):
                            col = legacy_paint.SHADE[col]
                    if walk_t and left_t == "wall" and lx < 4:
                        if lx == 0 or legacy_paint.dither(wx, wy, 1.0 - lx / 4.5):
                            col = legacy_paint.SHADE[col]
                    if walk_t and up_t != "wall" and nw_t == "wall" and lx < 3 and ly < 3:
                        if legacy_paint.dither(wx, wy, 0.5):
                            col = legacy_paint.SHADE[col]
                    if warm < 0.25 and ttype == "wall" and lx == 0 and left_t != "wall":
                        col = legacy_paint.COOL[col]
                    px[wx, wy] = legacy_paint.RGBA[col]
                    col_grid[wy][wx] = col

    if use_organic:
        legacy_paint._apply_south_cliff_overhang(px, col_grid, land_mask, grid, w, h, ts, bio)

    exits = meta.get("exits", [])
    if isinstance(exits, list) and exits:
        legacy_paint._paint_exit_framing(px, col_grid, grid, w, h, ts, exits, bio)

    buf = np.empty((img_h, img_w), dtype=np.uint8)
    for wy in range(img_h):
        row = col_grid[wy]
        for wx in range(img_w):
            buf[wy, wx] = IX[row[wx]]
    return buf


def _paint_layer_image(
    grid: list[list[str]],
    ts: int,
    meta: Dict[str, Any],
    island_id: int,
    base_theme: str,
    layer: Dict[str, Any],
    base_buf: Optional[np.ndarray] = None,
) -> Image.Image:
    """Paint one dynamic layer overlay into memory (themed or legacy)."""
    h_t = len(grid)
    w_t = len(grid[0]) if h_t else 0
    H, W = h_t * ts, w_t * ts

    lid = str(layer.get("id", "")).strip()
    patches = layer.get("tiles", [])
    if not isinstance(patches, list):
        patches = []
    patched_grid, tile_rects = _apply_tile_patches(grid, patches)

    layer_theme_id = str(layer.get("theme", "")).strip()
    tint = str(layer.get("tint", "")).strip().lower()
    if not tint and ("midnight" in lid.lower() or "midnight" in str(layer.get("when", "")).lower()):
        tint = "midnight"

    layer_meta = dict(meta)
    has_custom_decor = isinstance(layer.get("decor"), list)
    if has_custom_decor:
        layer_meta["decor"] = layer["decor"]

    use_theme = layer_theme_id or base_theme
    if base_buf is not None and not tile_rects and not layer_theme_id and not has_custom_decor:
        buf = base_buf.copy()
    elif use_theme:
        painter = get_theme(resolve_theme_id(use_theme))
        buf, _ = painter.paint_buffer(patched_grid, ts=ts, meta=layer_meta)
    else:
        buf = _paint_legacy_buffer(patched_grid, ts=ts, meta=layer_meta, island_id=island_id)

    if tint == "midnight":
        buf = MIDNIGHT_LUT[buf]

    full_frame = bool(layer.get("full_frame", False)) or (tint == "midnight") or (not tile_rects)
    if full_frame:
        im = buf_to_image(buf)
    else:
        alpha = np.zeros((H, W), dtype=bool)
        margin = 4
        for x0, y0, x1, y1 in tile_rects:
            px0 = max(0, x0 * ts - margin)
            py0 = max(0, y0 * ts - margin)
            px1 = min(W, x1 * ts + margin)
            py1 = min(H, y1 * ts + margin)
            alpha[py0:py1, px0:px1] = True
        im = buf_to_image(buf, alpha_mask=alpha)

    verify_image_palette(im, f"layer:{lid}")
    return im


def _images_equal(path: Path, gen_im: Image.Image) -> bool:
    if not path.exists():
        return False
    try:
        cur = np.asarray(Image.open(path).convert("RGBA"))
        gen = np.asarray(gen_im.convert("RGBA"))
        if cur.shape != gen.shape:
            return False
        return bool(np.array_equal(cur, gen))
    except Exception:
        return False


def _layer_needs_png(layer: Dict[str, Any], out_path: Path) -> bool:
    """True if this layer alters visuals (tiles/theme/tint/full_frame) or already has a PNG on disk."""
    if out_path.exists():
        return True
    tiles = layer.get("tiles", [])
    if isinstance(tiles, list) and len(tiles) > 0:
        return True
    if str(layer.get("theme", "")).strip():
        return True
    if str(layer.get("tint", "")).strip():
        return True
    if bool(layer.get("full_frame", False)):
        return True
    lid = str(layer.get("id", "")).strip().lower()
    when = str(layer.get("when", "")).strip().lower()
    if "midnight" in lid or "midnight" in when:
        return True
    return False


def discover_targets(
    islands: Sequence[int],
    regions: Sequence[str],
    all_islands: bool,
    include_internal: bool,
) -> List[Tuple[int, Path]]:
    out: List[Tuple[int, Path]] = []
    seen: set[Tuple[int, str]] = set()
    islands_root = REPO_ROOT / "luxel" / "islands"

    if regions:
        for raw in regions:
            spec = raw.strip()
            if not spec:
                continue
            if ":" in spec:
                isl_s, rid = spec.split(":", 1)
                isl_i = int(isl_s)
                mf = islands_root / str(isl_i) / f"{rid}.map"
                if not mf.exists():
                    raise SystemExit(f"Map not found: {mf}")
                key = (isl_i, rid)
                if key not in seen:
                    seen.add(key)
                    out.append((isl_i, mf))
            else:
                matches = []
                search_isls = list(islands) if islands else list(range(0, 9))
                for isl_i in search_isls:
                    mf = islands_root / str(isl_i) / f"{spec}.map"
                    if mf.exists():
                        matches.append((isl_i, mf))
                if not matches:
                    raise SystemExit(f"Region not found: {spec}")
                for isl_i, mf in matches:
                    key = (isl_i, mf.stem)
                    if key not in seen:
                        seen.add(key)
                        out.append((isl_i, mf))
        return sorted(out, key=lambda t: (t[0], t[1].stem))

    target_isls = list(range(0, 9)) if all_islands else sorted(set(islands))
    for isl_i in target_isls:
        idir = islands_root / str(isl_i)
        if not idir.is_dir():
            continue
        for mf in sorted(idir.glob("*.map")):
            if not include_internal and mf.stem.startswith("_"):
                continue
            key = (isl_i, mf.stem)
            if key not in seen:
                seen.add(key)
                out.append((isl_i, mf))
    return out


def process_region(
    isl_id: int,
    map_path: Path,
    check_only: bool,
    force_protected: bool,
) -> Dict[str, Any]:
    rid = map_path.stem
    rkey = f"{isl_id}:{rid}"
    json_path = map_path.with_suffix(".json")
    meta: Dict[str, Any] = json.loads(json_path.read_text(encoding="utf-8")) if json_path.exists() else {}
    w, h, ts, grid = legacy_paint.parse_map(map_path)
    theme = str(meta.get("theme", "")).strip()
    art_dir = REPO_ROOT / "luxel" / "art" / "islands" / str(isl_id)
    ground_path = art_dir / f"{rid}_ground.png"

    res: Dict[str, Any] = {
        "key": rkey,
        "theme": theme or "<legacy>",
        "ground": "fresh",
        "layers_stale": [],
        "layers_missing": [],
        "layers_fresh": 0,
        "written": [],
    }

    # 1. Ground PNG
    base_buf: Optional[np.ndarray] = None
    if rkey in HAND_TUNED_GROUNDS and not force_protected and ground_path.exists():
        res["ground"] = "protected"
    else:
        if theme:
            painter = get_theme(resolve_theme_id(theme))
            base_buf, _ = painter.paint_buffer(grid, ts=ts, meta=meta)
            gen_ground = buf_to_image(base_buf)
            verify_image_palette(gen_ground, f"theme:{theme}")
        else:
            base_buf = _paint_legacy_buffer(grid, ts=ts, meta=meta, island_id=isl_id)
            gen_ground = buf_to_image(base_buf)
            verify_image_palette(gen_ground, f"legacy:{rkey}")

        if not ground_path.exists():
            res["ground"] = "missing"
            if not check_only:
                ground_path.parent.mkdir(parents=True, exist_ok=True)
                gen_ground.save(ground_path)
                res["written"].append(ground_path)
        elif not _images_equal(ground_path, gen_ground):
            res["ground"] = "stale"
            if not check_only:
                ground_path.parent.mkdir(parents=True, exist_ok=True)
                gen_ground.save(ground_path)
                res["written"].append(ground_path)

    # 2. Layer overlay PNGs
    layers = meta.get("layers", [])
    if isinstance(layers, list):
        for lay in layers:
            if not isinstance(lay, dict):
                continue
            lid = str(lay.get("id", "")).strip()
            if not lid:
                continue
            ov_path = art_dir / f"{rid}__{lid}.png"
            if not _layer_needs_png(lay, ov_path):
                continue
            gen_lay = _paint_layer_image(grid, ts, meta, isl_id, theme, lay, base_buf=base_buf)
            if not ov_path.exists():
                res["layers_missing"].append(lid)
                if not check_only:
                    ov_path.parent.mkdir(parents=True, exist_ok=True)
                    gen_lay.save(ov_path)
                    res["written"].append(ov_path)
            elif not _images_equal(ov_path, gen_lay):
                res["layers_stale"].append(lid)
                if not check_only:
                    ov_path.parent.mkdir(parents=True, exist_ok=True)
                    gen_lay.save(ov_path)
                    res["written"].append(ov_path)
            else:
                res["layers_fresh"] += 1

    return res


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Check or incrementally repaint stale/missing Luxel region ground & layer PNGs.")
    ap.add_argument("--island", action="append", default=[], help="Island ID (0..8), repeatable or comma-separated")
    ap.add_argument("--region", action="append", default=[], help="Region key (e.g. 2:lighthouse_r1 or lighthouse_r1), repeatable")
    ap.add_argument("--all", action="store_true", help="Scan all islands (0..8)")
    ap.add_argument("--check", action="store_true", help="Dry-run: report stale/missing files without writing")
    ap.add_argument("--include-internal", action="store_true", help="Include _-prefixed proof/demo maps")
    ap.add_argument("--force-protected", action="store_true", help="Allow overwriting hand-tuned overworld grounds")
    args = ap.parse_args(argv)

    islands: List[int] = []
    for raw in args.island:
        for part in str(raw).split(","):
            p = part.strip()
            if p:
                islands.append(int(p))

    if not args.all and not islands and not args.region:
        ap.error("Specify --island, --region, or --all")

    targets = discover_targets(islands, args.region, args.all, args.include_internal)
    if not targets:
        print("REPAINT: no matching regions")
        return 0

    g_stale = g_miss = g_fresh = g_prot = 0
    l_stale = l_miss = l_fresh = 0
    total_written = 0

    for isl_id, mf in targets:
        r = process_region(isl_id, mf, check_only=args.check, force_protected=args.force_protected)
        gs = r["ground"]
        if gs == "stale":
            g_stale += 1
        elif gs == "missing":
            g_miss += 1
        elif gs == "protected":
            g_prot += 1
        else:
            g_fresh += 1
        l_stale += len(r["layers_stale"])
        l_miss += len(r["layers_missing"])
        l_fresh += int(r["layers_fresh"])
        total_written += len(r["written"])

        dirty = gs in ("stale", "missing") or r["layers_stale"] or r["layers_missing"]
        if dirty or gs == "protected":
            bits = [f"ground={gs}"]
            if r["layers_missing"]:
                bits.append("layers_missing=" + ",".join(r["layers_missing"]))
            if r["layers_stale"]:
                bits.append("layers_stale=" + ",".join(r["layers_stale"]))
            action = "CHECK" if args.check else ("PROTECTED" if gs == "protected" and not (r["layers_missing"] or r["layers_stale"]) else "REPAINTED")
            print(f"[{action:9s}] {r['key']:26s} ({r['theme']:18s}) " + " ".join(bits))

    mode = "CHECK" if args.check else "DONE"
    print(
        f"REPAINT {mode}: regions={len(targets)} "
        f"grounds(stale={g_stale} missing={g_miss} fresh={g_fresh} protected={g_prot}) "
        f"layers(stale={l_stale} missing={l_miss} fresh={l_fresh}) "
        f"written={total_written}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
