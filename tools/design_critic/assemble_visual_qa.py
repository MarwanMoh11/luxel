#!/usr/bin/env python3
"""Luxel Round 2 Visual QA Contact-Sheet & 8-Island Door Strip Assembler.

Reads `<dir>/isl<N>/shot_01.png..shot_06.png` and `manifest.json`, upscales each
320x180 capture 2x nearest-neighbor (640x360), adds clean dark header bars, and
writes:
  - `<dir>/isl<N>_sheet.png`   (1316x1160 crisp 2x3 contact sheet)
  - `<dir>/all_doors_strip.png` (8-island side-by-side comparison of door_key + door_boss_or_ward)

Usage:
  uv run --no-project --with pillow python tools/design_critic/assemble_visual_qa.py <dir> [--island <1..8>]
"""

from __future__ import annotations

import argparse
import json
import os
from typing import Any, Dict, List, Optional, Sequence, Tuple

from PIL import Image, ImageDraw, ImageFont

# Sheet geometry: exact 1316 x 1160
TILE_W = 640
TILE_H = 360
TILE_HDR_H = 16
SHEET_TOP_H = 20
MARGIN_X = 12
GAP_X = 12
GAP_Y = 4
MARGIN_BOTTOM = 4
SHEET_W = MARGIN_X + TILE_W + GAP_X + TILE_W + MARGIN_X  # 1316
SHEET_H = SHEET_TOP_H + 3 * (TILE_HDR_H + TILE_H) + 2 * GAP_Y + MARGIN_BOTTOM  # 1160

# Last Light dark UI colours
BG_SHEET = (13, 11, 30, 255)
BG_HEADER = (24, 20, 44, 255)
BG_TILE_HDR = (33, 26, 59, 255)
BG_MISSING = (20, 16, 36, 255)
BORDER_TILE = (61, 44, 92, 255)
BORDER_ACCENT = (120, 169, 218, 255)
TEXT_MAIN = (255, 244, 220, 255)
TEXT_GOLD = (255, 217, 140, 255)
TEXT_SKY = (120, 169, 218, 255)
TEXT_MUTED = (194, 167, 174, 255)
TEXT_CORAL = (226, 114, 91, 255)

ISLAND_NAMES: Dict[int, str] = {
    1: "Bell Isle",
    2: "Salt Harbor",
    3: "Briar Hollow",
    4: "Lotus Conservatory",
    5: "Starlight Orrery",
    6: "Ash Kiln",
    7: "Mirror Spire",
    8: "Eclipse Sanctum",
}


def _load_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.ttf",
        "/System/Library/Fonts/Supplemental/Courier New.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def _load_manifest(isl_dir: str, isl_id: int) -> List[Dict[str, Any]]:
    mf_path = os.path.join(isl_dir, "manifest.json")
    if os.path.exists(mf_path):
        with open(mf_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        shots = data.get("shots", [])
        if isinstance(shots, list) and shots:
            return shots
    defaults = [
        ("ow_spawn", "Overworld Spawn"),
        ("ow_landmark", "Overworld Landmark"),
        ("door_key", "Key Door"),
        ("door_boss_or_ward", "Boss / Ward Door"),
        ("puzzle_toy", "Puzzle Toy"),
        ("dungeon_hub", "Dungeon Hub"),
    ]
    return [
        {
            "index": i + 1,
            "file": f"shot_{i + 1:02d}.png",
            "slot": slot,
            "title": title,
            "region": "?",
            "pos": [0, 0],
            "door_type": "",
            "target_id": "",
        }
        for i, (slot, title) in enumerate(defaults)
    ]


def _load_upscaled_shot(path: str, font_label: ImageFont.ImageFont, missing_text: str) -> Image.Image:
    if os.path.exists(path):
        im = Image.open(path).convert("RGBA")
        if im.size != (TILE_W, TILE_H):
            im = im.resize((TILE_W, TILE_H), Image.Resampling.NEAREST)
        return im
    placeholder = Image.new("RGBA", (TILE_W, TILE_H), BG_MISSING)
    draw = ImageDraw.Draw(placeholder)
    draw.rectangle([1, 1, TILE_W - 2, TILE_H - 2], outline=TEXT_CORAL, width=1)
    draw.text((20, TILE_H // 2 - 8), missing_text, fill=TEXT_CORAL, font=font_label)
    return placeholder


def _format_tile_label(shot: Dict[str, Any]) -> str:
    idx = shot.get("index", "?")
    title = str(shot.get("title", shot.get("slot", "Shot")))
    region = str(shot.get("region", "?"))
    dtype = str(shot.get("door_type", ""))
    pos = shot.get("pos", [])
    pos_s = f" @({int(pos[0])},{int(pos[1])})" if isinstance(pos, list) and len(pos) >= 2 else ""
    extra = f" [{dtype}]" if dtype else ""
    return f"#{idx} {title} | {region}{extra}{pos_s}"


def build_island_sheet(base_dir: str, isl_id: int) -> Optional[str]:
    isl_dir = os.path.join(base_dir, f"isl{isl_id}")
    if not os.path.isdir(isl_dir):
        return None
    shots = _load_manifest(isl_dir, isl_id)
    font_top = _load_font(12)
    font_tile = _load_font(10)

    canvas = Image.new("RGBA", (SHEET_W, SHEET_H), BG_SHEET)
    draw = ImageDraw.Draw(canvas)

    # Top title bar
    draw.rectangle([0, 0, SHEET_W - 1, SHEET_TOP_H - 1], fill=BG_HEADER)
    iname = ISLAND_NAMES.get(isl_id, f"Island {isl_id}")
    draw.text(
        (MARGIN_X, 3),
        f"LUXEL VISUAL QA  |  ISLAND {isl_id}: {iname.upper()}  (640x360 2x nearest)",
        fill=TEXT_GOLD,
        font=font_top,
    )

    for i in range(6):
        shot = shots[i] if i < len(shots) else {
            "index": i + 1, "file": f"shot_{i + 1:02d}.png", "slot": f"shot_{i + 1}", "title": f"Shot {i + 1}", "region": "?"
        }
        col = i % 2
        row = i // 2
        x0 = MARGIN_X + col * (TILE_W + GAP_X)
        y0 = SHEET_TOP_H + row * (TILE_HDR_H + TILE_H + GAP_Y)

        # Header strip above tile
        draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H - 1], fill=BG_TILE_HDR)
        label = _format_tile_label(shot)
        slot = str(shot.get("slot", ""))
        label_col = TEXT_SKY if slot.startswith("door_") else TEXT_MAIN
        draw.text((x0 + 6, y0 + 2), label[:92], fill=label_col, font=font_tile)

        # Upscaled 2x screenshot
        shot_path = os.path.join(isl_dir, str(shot.get("file", f"shot_{i + 1:02d}.png")))
        tile_img = _load_upscaled_shot(shot_path, font_top, f"Missing: {os.path.basename(shot_path)}")
        canvas.paste(tile_img, (x0, y0 + TILE_HDR_H))

        # Crisp border around tile + header
        border_col = BORDER_ACCENT if slot.startswith("door_") else BORDER_TILE
        draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H + TILE_H - 1], outline=border_col, width=1)

    out_path = os.path.join(base_dir, f"isl{isl_id}_sheet.png")
    canvas.save(out_path)
    return out_path


def _find_shot_by_slot(shots: List[Dict[str, Any]], slot: str, fallback_idx: int) -> Dict[str, Any]:
    for s in shots:
        if str(s.get("slot", "")) == slot:
            return s
    if 0 <= fallback_idx < len(shots):
        return shots[fallback_idx]
    return {"index": fallback_idx + 1, "file": f"shot_{fallback_idx + 1:02d}.png", "slot": slot, "title": slot, "region": "?"}


def build_all_doors_strip(base_dir: str, island_ids: Sequence[int]) -> Optional[str]:
    present = [i for i in island_ids if os.path.isdir(os.path.join(base_dir, f"isl{i}"))]
    if not present:
        return None
    font_top = _load_font(12)
    font_tile = _load_font(10)

    top_h = 24
    rows = len(present)
    strip_w = MARGIN_X + TILE_W + GAP_X + TILE_W + MARGIN_X  # 1316
    strip_h = top_h + rows * (TILE_HDR_H + TILE_H) + max(0, rows - 1) * GAP_Y + MARGIN_BOTTOM + 4

    canvas = Image.new("RGBA", (strip_w, strip_h), BG_SHEET)
    draw = ImageDraw.Draw(canvas)
    draw.rectangle([0, 0, strip_w - 1, top_h - 1], fill=BG_HEADER)
    draw.text(
        (MARGIN_X, 5),
        f"LUXEL 8-ISLAND DOOR COMPARISON STRIP  |  LEFT: KEY DOORS  |  RIGHT: BOSS / WARD DOORS  ({rows} islands)",
        fill=TEXT_GOLD,
        font=font_top,
    )

    for r_idx, isl_id in enumerate(present):
        isl_dir = os.path.join(base_dir, f"isl{isl_id}")
        shots = _load_manifest(isl_dir, isl_id)
        key_shot = _find_shot_by_slot(shots, "door_key", 2)
        bw_shot = _find_shot_by_slot(shots, "door_boss_or_ward", 3)
        iname = ISLAND_NAMES.get(isl_id, f"Island {isl_id}")

        y0 = top_h + r_idx * (TILE_HDR_H + TILE_H + GAP_Y)
        for col, (tag, s) in enumerate((("KEY DOOR", key_shot), ("BOSS / WARD", bw_shot))):
            x0 = MARGIN_X + col * (TILE_W + GAP_X)
            draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H - 1], fill=BG_TILE_HDR)
            reg = str(s.get("region", "?"))
            dt = str(s.get("door_type", ""))
            tid = str(s.get("target_id", ""))
            lbl = f"ISL {isl_id} ({iname}) | {tag} | {reg} [{dt}] {tid}"
            draw.text((x0 + 6, y0 + 2), lbl[:92], fill=TEXT_SKY if col == 0 else TEXT_GOLD, font=font_tile)

            shot_path = os.path.join(isl_dir, str(s.get("file", "")))
            tile_img = _load_upscaled_shot(shot_path, font_top, f"Missing ISL {isl_id} {tag}")
            canvas.paste(tile_img, (x0, y0 + TILE_HDR_H))
            draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H + TILE_H - 1], outline=BORDER_ACCENT, width=1)

    out_path = os.path.join(base_dir, "all_doors_strip.png")
    canvas.save(out_path)
    return out_path


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Assemble Luxel Visual QA contact sheets and door comparison strip")
    parser.add_argument("dir", help="Base directory containing isl1..isl8 capture folders")
    parser.add_argument("--island", type=int, default=0, help="Assemble only one island sheet (1..8); 0 = all")
    args = parser.parse_args(argv)

    base_dir = os.path.abspath(args.dir)
    if not os.path.isdir(base_dir):
        print(f"ERROR: directory not found: {base_dir}")
        return 1

    target_islands = [args.island] if 1 <= args.island <= 8 else list(range(1, 9))
    built_sheets: List[str] = []
    for isl_id in target_islands:
        out = build_island_sheet(base_dir, isl_id)
        if out:
            built_sheets.append(out)
            print(f"Wrote sheet ({SHEET_W}x{SHEET_H}): {out}")

    strip = build_all_doors_strip(base_dir, list(range(1, 9)))
    if strip:
        print(f"Wrote door strip: {strip}")

    if not built_sheets and not strip:
        print(f"WARNING: no isl1..isl8 folders found under {base_dir}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
