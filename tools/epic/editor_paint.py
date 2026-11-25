#!/usr/bin/env python3
"""Repaint one room right after an edit in the level editor (luxel/editor).

  uv run --no-project --with pillow --with numpy python tools/epic/editor_paint.py 1:belfry_r6 [--base old.map] [--out DIR]

Themed rooms: the whole ground and its layers through repaint.py (under a second).
Rooms on the old pixel painter (the overworlds, 8-25 s for a full paint): only the tiles that differ from --base,
with a margin, so it stays quick. Hand-tuned grounds (repaint.HAND_TUNED_GROUNDS) take only the pixels the edit changed, over the untouched copy kept in
docs/level_edits/base/<room>_ground.png (delete that copy and its .map after repainting such a ground by hand).
--out writes the PNGs to another folder instead of luxel/art/islands/<n> (tests).
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.epic import repaint as rp  # noqa: E402

lp = rp.legacy_paint
MARGIN = 2  # tiles around an edit whose look can change (cliffs, shores, shadows)
CONTEXT = 3  # extra tiles painted so the margin sees its real neighbours


def changed_boxes(a: List[List[str]], b: List[List[str]]) -> List[Tuple[int, int, int, int]]:
    h, w = len(b), len(b[0])
    cells = [(x, y) for y in range(h) for x in range(w) if y >= len(a) or x >= len(a[0]) or a[y][x] != b[y][x]]
    boxes: List[List[int]] = []
    for x, y in cells:
        for bx in boxes:
            if bx[0] - 6 <= x <= bx[2] + 6 and bx[1] - 6 <= y <= bx[3] + 6:
                bx[0], bx[1], bx[2], bx[3] = min(bx[0], x), min(bx[1], y), max(bx[2], x), max(bx[3], y)
                break
        else:
            boxes.append([x, y, x, y])
    return [tuple(bx) for bx in boxes]


def paint_window(grid: List[List[str]], ts: int, meta: Dict[str, Any], isl: int, box: Tuple[int, int, int, int]) -> Image.Image:
    """rp._paint_legacy_buffer limited to a tile window; same pixels away from the window's own rim."""
    h, w = len(grid), len(grid[0])
    img_w, img_h = w * ts, h * ts
    dungeon = bool(meta.get("is_dungeon", False))
    island = max(1, min(8, int(meta.get("island_id", isl) or isl or 1)))
    organic = not dungeon
    bio = (lp.DUNGEON_BIOMES if dungeon else lp.BIOMES).get(island, (lp.DUNGEON_BIOMES if dungeon else lp.BIOMES)[1])
    x0t, y0t = max(0, box[0] - MARGIN - CONTEXT), max(0, box[1] - MARGIN - CONTEXT)
    x1t, y1t = min(w - 1, box[2] + MARGIN + CONTEXT), min(h - 1, box[3] + MARGIN + CONTEXT)
    im = Image.new("RGBA", (img_w, img_h), lp.RGBA["void"])
    px = im.load()
    col = [["void"] * img_w for _ in range(img_h)]
    land = [[False] * img_w for _ in range(img_h)]
    for ty in range(y0t, y1t + 1):
        for tx in range(x0t, x1t + 1):
            base_t = grid[ty][tx]
            up_t, down_t = lp._tile(grid, tx, ty - 1, w, h), lp._tile(grid, tx, ty + 1, w, h)
            left_t, right_t = lp._tile(grid, tx - 1, ty, w, h), lp._tile(grid, tx + 1, ty, w, h)
            nw_t = lp._tile(grid, tx - 1, ty - 1, w, h)
            tile_h = lp.hash01(tx, ty, 41)
            for ly in range(ts):
                wy = ty * ts + ly
                for lx in range(ts):
                    wx = tx * ts + lx
                    t = lp._resolve_organic_tile(grid, tx, ty, lx, ly, ts, w, h, wx, wy) if organic else base_t
                    land[wy][wx] = t in lp.LAND_TILES
                    warm = lp.warmth(wx * (lp.core.W / float(max(1, img_w))))
                    c = lp._paint_pixel(wx, wy, lx, ly, ts, t, warm, up_t, down_t, left_t, right_t, tile_h, bio)
                    walk = t in ("ground", "path", "bramble", "cracked")
                    if walk and up_t == "wall" and ly < 4 and (ly == 0 or lp.dither(wx, wy, 1.0 - ly / 4.5)):
                        c = lp.SHADE[c]
                    if walk and left_t == "wall" and lx < 4 and (lx == 0 or lp.dither(wx, wy, 1.0 - lx / 4.5)):
                        c = lp.SHADE[c]
                    if walk and up_t != "wall" and nw_t == "wall" and lx < 3 and ly < 3 and lp.dither(wx, wy, 0.5):
                        c = lp.SHADE[c]
                    if warm < 0.25 and t == "wall" and lx == 0 and left_t != "wall":
                        c = lp.COOL[c]
                    px[wx, wy] = lp.RGBA[c]
                    col[wy][wx] = c
    if organic:
        lp._apply_south_cliff_overhang(px, col, land, grid, w, h, ts, bio)
    exits = meta.get("exits", [])
    if isinstance(exits, list) and exits:
        lp._paint_exit_framing(px, col, grid, w, h, ts, exits, bio)
    return im


def crop_box(box: Tuple[int, int, int, int], ts: int, size: Tuple[int, int]) -> Tuple[int, int, int, int]:
    return (max(0, (box[0] - MARGIN) * ts), max(0, (box[1] - MARGIN) * ts),
            min(size[0], (box[2] + 1 + MARGIN) * ts), min(size[1], (box[3] + 1 + MARGIN) * ts))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("region")
    ap.add_argument("--base")
    ap.add_argument("--out")
    a = ap.parse_args()
    isl_s, rid = a.region.split(":", 1)
    isl = int(isl_s)
    mp = rp.REPO_ROOT / "luxel" / "islands" / isl_s / f"{rid}.map"
    meta: Dict[str, Any] = json.loads(mp.with_suffix(".json").read_text(encoding="utf-8"))
    art = rp.REPO_ROOT / "luxel" / "art" / "islands" / isl_s
    out = Path(a.out) if a.out else art
    out.mkdir(parents=True, exist_ok=True)
    ground, ground_out = art / f"{rid}_ground.png", out / f"{rid}_ground.png"
    if str(meta.get("theme", "")).strip() or not ground.exists():
        if a.out:
            w, h, ts, grid = lp.parse_map(mp)
            buf, _ = rp.get_theme(rp.resolve_theme_id(str(meta["theme"]))).paint_buffer(grid, ts=ts, meta=meta)
            rp.buf_to_image(buf).save(ground_out)
        else:
            rp.process_region(isl, mp, check_only=False, force_protected=False)
        print("EDITOR PAINT OK full")
        return 0
    w, h, ts, grid = lp.parse_map(mp)
    base_path: Optional[Path] = Path(a.base) if a.base else None
    if base_path is None or not base_path.exists():
        print("EDITOR PAINT SKIP: an old-painter room needs --base")
        return 1
    _, _, _, old = lp.parse_map(base_path)
    protected = a.region in rp.HAND_TUNED_GROUNDS
    if protected and not a.out:
        # Always start from the untouched art, so undoing an edit brings back every hand-tuned pixel.
        keep = rp.REPO_ROOT / "docs" / "level_edits" / "base"
        keep.mkdir(parents=True, exist_ok=True)
        pristine, pristine_map = keep / f"{isl}_{rid}_ground.png", keep / f"{isl}_{rid}_ground.map"
        if not pristine.exists():
            shutil.copyfile(ground, pristine)
            shutil.copyfile(base_path, pristine_map)
        cur = Image.open(pristine).convert("RGBA")
        _, _, _, old = lp.parse_map(pristine_map)
    else:
        cur = Image.open(ground).convert("RGBA")
    boxes = changed_boxes(old, grid)
    for box in boxes:
        c = crop_box(box, ts, cur.size)
        new = np.asarray(paint_window(grid, ts, meta, isl, box).crop(c))
        patch = np.array(cur.crop(c))
        if protected:
            was = np.asarray(paint_window(old, ts, meta, isl, box).crop(c))
            mask = (new != was).any(axis=2)
        else:
            mask = np.ones(new.shape[:2], dtype=bool)
        patch[mask] = new[mask]
        cur.paste(Image.fromarray(patch), c[:2])
    if boxes:
        cur.save(ground_out)
    elif protected and not a.out:
        shutil.copyfile(pristine, ground_out)
    print(f"EDITOR PAINT OK window boxes={len(boxes)} protected={protected}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
