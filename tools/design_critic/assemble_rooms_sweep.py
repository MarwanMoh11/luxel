#!/usr/bin/env python3
"""Luxel Round 9 Dungeon Sweep Contact-Sheet Assembler (Tier-1 16-room & Tier-2 8-room).

Reads `<dir>/room_01.png..room_NN.png` and `manifest.json`, upscales each
320x180 capture 2x nearest-neighbor (640x360), adds crisp dark title strips,
and writes:
  - For 16 shots (Tier-1): TWO 2x4 contact sheets:
      * `<dir>/rooms_sweep_part1.png` (rooms 1-8)
      * `<dir>/rooms_sweep_part2.png` (rooms 9-16)
  - For <= 8 shots (Tier-2): ONE 2x4 contact sheet:
      * `<dir>/rooms_sweep_tier2.png` (or `--out <path>` if specified)

Usage:
  uv run --no-project --with pillow python tools/design_critic/assemble_rooms_sweep.py [dir] [--out path.png]
"""

from __future__ import annotations

import argparse
import json
import os
from typing import Any, Dict, List, Optional, Sequence, Tuple

from PIL import Image, ImageDraw, ImageFont

# 2x4 Sheet geometry: 1316 x 1564 (640x360 2x nearest per panel)
TILE_W = 640
TILE_H = 360
TILE_HDR_H = 18
SHEET_TOP_H = 22
MARGIN_X = 12
GAP_X = 12
GAP_Y = 6
MARGIN_BOTTOM = 6
COLS = 2
ROWS = 4
SHEET_W = MARGIN_X + COLS * TILE_W + (COLS - 1) * GAP_X + MARGIN_X  # 1316
SHEET_H = SHEET_TOP_H + ROWS * (TILE_HDR_H + TILE_H) + (ROWS - 1) * GAP_Y + MARGIN_BOTTOM  # 1564

# Last Light dark UI colours
BG_SHEET = (13, 11, 30, 255)
BG_HEADER = (24, 20, 44, 255)
BG_TILE_HDR = (33, 26, 59, 255)
BG_MISSING = (20, 16, 36, 255)
BORDER_TILE = (61, 44, 92, 255)
BORDER_ACCENT = (120, 169, 218, 255)
BORDER_GOLD = (255, 217, 140, 255)
BORDER_CORAL = (226, 114, 91, 255)
TEXT_MAIN = (255, 244, 220, 255)
TEXT_GOLD = (255, 217, 140, 255)
TEXT_SKY = (120, 169, 218, 255)
TEXT_CORAL = (226, 114, 91, 255)

DEFAULT_SHOTS: List[Dict[str, Any]] = [
    {"index": 1, "file": "room_01.png", "slot": "01_lighthouse_r5", "title": "Prism Split Shrine", "island": 2, "region": "lighthouse_r5"},
    {"index": 2, "file": "room_02.png", "slot": "02_lighthouse_r7", "title": "Master Mirror & Portal Gallery", "island": 2, "region": "lighthouse_r7"},
    {"index": 3, "file": "room_03.png", "slot": "03_oak_r5", "title": "Beam Shrine", "island": 3, "region": "oak_r5"},
    {"index": 4, "file": "room_04.png", "slot": "04_oak_r7", "title": "Weaver's Loom", "island": 3, "region": "oak_r7"},
    {"index": 5, "file": "room_05.png", "slot": "05_oak_r3", "title": "Briar Combat Hall", "island": 3, "region": "oak_r3"},
    {"index": 6, "file": "room_06.png", "slot": "06_conservatory_r5", "title": "Moth Wings Shrine", "island": 4, "region": "conservatory_r5"},
    {"index": 7, "file": "room_07.png", "slot": "07_conservatory_r6", "title": "Conservatory Mini-Boss Arena", "island": 4, "region": "conservatory_r6"},
    {"index": 8, "file": "room_08.png", "slot": "08_orrery_r5", "title": "True Lens Shrine", "island": 5, "region": "orrery_r5"},
    {"index": 9, "file": "room_09.png", "slot": "09_orrery_r7", "title": "Orrery Split Puzzle", "island": 5, "region": "orrery_r7"},
    {"index": 10, "file": "room_10.png", "slot": "10_orrery_r8", "title": "Orrery Combat Hall", "island": 5, "region": "orrery_r8"},
    {"index": 11, "file": "room_11.png", "slot": "11_kiln_r2", "title": "Kiln Key Vault", "island": 6, "region": "kiln_r2"},
    {"index": 12, "file": "room_12.png", "slot": "12_kiln_r5", "title": "Sunflare Shrine", "island": 6, "region": "kiln_r5"},
    {"index": 13, "file": "room_13.png", "slot": "13_kiln_r6", "title": "Kiln Mini-Boss Arena", "island": 6, "region": "kiln_r6"},
    {"index": 14, "file": "room_14.png", "slot": "14_kiln_r7", "title": "Five-Signal Brazier Vault", "island": 6, "region": "kiln_r7"},
    {"index": 15, "file": "room_15.png", "slot": "15_spire_r5", "title": "Mirror Spire Long-Sightline Hall", "island": 7, "region": "spire_r5"},
    {"index": 16, "file": "room_16.png", "slot": "16_sanctum_r4", "title": "Sanctum Mini-Boss Arena", "island": 8, "region": "sanctum_r4"},
]


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


def _load_manifest_with_meta(sweep_dir: str) -> Tuple[List[Dict[str, Any]], str]:
    mf_path = os.path.join(sweep_dir, "manifest.json")
    if os.path.exists(mf_path):
        with open(mf_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        shots = data.get("shots", [])
        set_name = str(data.get("set", "")).strip().lower()
        if isinstance(shots, list) and shots:
            return shots, set_name
    return [dict(item) for item in DEFAULT_SHOTS], "tier1"


def _load_manifest(sweep_dir: str) -> List[Dict[str, Any]]:
    shots, _ = _load_manifest_with_meta(sweep_dir)
    return shots


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


def _format_tile_label(shot: Dict[str, Any], idx_fallback: int) -> str:
    idx = shot.get("index", idx_fallback)
    title = str(shot.get("title", shot.get("slot", f"Room #{idx}")))
    isl = shot.get("island", "?")
    region = str(shot.get("region", "?"))
    return f"#{idx:02d} {title}  |  ISL {isl} {region}"


def _accent_for_island(isl: int) -> Tuple[Tuple[int, int, int, int], Tuple[int, int, int, int]]:
    if isl == 8:
        return TEXT_CORAL, BORDER_CORAL
    if isl == 6:
        return TEXT_GOLD, BORDER_GOLD
    if isl in (2, 5, 7):
        return TEXT_SKY, BORDER_ACCENT
    return TEXT_MAIN, BORDER_TILE


def build_part_sheet(
    sweep_dir: str,
    shots: Sequence[Dict[str, Any]],
    start_idx: int,
    part_num: int,
    out_path: str,
    header_text: Optional[str] = None,
    single_sheet: bool = False,
) -> str:
    font_top = _load_font(12)
    font_tile = _load_font(11)

    canvas = Image.new("RGBA", (SHEET_W, SHEET_H), BG_SHEET)
    draw = ImageDraw.Draw(canvas)

    range_label = f"ROOMS {start_idx + 1:02d}-{start_idx + 8:02d}"
    top_title = header_text or (
        f"LUXEL TIER-1 DUNGEON SWEEP (PART {part_num}/2: {range_label})  |  2x4 CONTACT SHEET  (640x360 2x nearest)"
    )
    draw.rectangle([0, 0, SHEET_W - 1, SHEET_TOP_H - 1], fill=BG_HEADER)
    draw.text((MARGIN_X, 4), top_title, fill=TEXT_GOLD, font=font_top)

    panel_count = min(8, max(0, len(shots) - start_idx)) if single_sheet else 8
    for slot_i in range(panel_count):
        global_i = start_idx + slot_i
        shot = shots[global_i] if global_i < len(shots) else dict(DEFAULT_SHOTS[global_i])
        col = slot_i % COLS
        row = slot_i // COLS
        x0 = MARGIN_X + col * (TILE_W + GAP_X)
        y0 = SHEET_TOP_H + row * (TILE_HDR_H + TILE_H + GAP_Y)

        draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H - 1], fill=BG_TILE_HDR)
        label_col, border_col = _accent_for_island(int(shot.get("island", 1)))
        draw.text((x0 + 6, y0 + 2), _format_tile_label(shot, global_i + 1)[:92], fill=label_col, font=font_tile)

        shot_path = os.path.join(sweep_dir, str(shot.get("file", f"room_{global_i + 1:02d}.png")))
        tile_img = _load_upscaled_shot(shot_path, font_top, f"Missing: {os.path.basename(shot_path)}")
        canvas.paste(tile_img, (x0, y0 + TILE_HDR_H))

        draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H + TILE_H - 1], outline=border_col, width=1)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    canvas.save(out_path)
    return out_path


def build_single_sheet(
    sweep_dir: str,
    shots: Sequence[Dict[str, Any]],
    out_path: Optional[str] = None,
    set_name: str = "tier2",
) -> str:
    target = os.path.abspath(out_path) if out_path else os.path.join(sweep_dir, "rooms_sweep_tier2.png")
    tier_tag = "TIER-2" if set_name in ("", "tier2") else set_name.upper()
    hdr = (
        f"LUXEL {tier_tag} MINI-BOSS & DUNGEON SWEEP (ROOMS 01-{len(shots):02d})"
        "  |  2x4 CONTACT SHEET  (640x360 2x nearest)"
    )
    return build_part_sheet(sweep_dir, shots, 0, 1, target, header_text=hdr, single_sheet=True)


def build_rooms_sweep_sheets(sweep_dir: str) -> Tuple[str, str]:
    shots = _load_manifest(sweep_dir)
    part1 = build_part_sheet(sweep_dir, shots, 0, 1, os.path.join(sweep_dir, "rooms_sweep_part1.png"))
    part2 = build_part_sheet(sweep_dir, shots, 8, 2, os.path.join(sweep_dir, "rooms_sweep_part2.png"))
    return part1, part2


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Assemble Luxel Dungeon Sweep 2x4 contact sheets (16-room Tier-1 or <=8-room Tier-2)"
    )
    parser.add_argument("dir", nargs="?", default="docs/visual_qa/rooms_sweep_r8", help="Directory containing room_01..NN.png")
    parser.add_argument("--out", default=None, help="Output PNG path for <=8-shot single-sheet mode (default: <dir>/rooms_sweep_tier2.png)")
    args = parser.parse_args(argv)

    sweep_dir = os.path.abspath(args.dir)
    if not os.path.isdir(sweep_dir):
        print(f"ERROR: directory not found: {sweep_dir}")
        return 1

    shots, set_name = _load_manifest_with_meta(sweep_dir)
    if len(shots) <= 8:
        out_file = build_single_sheet(sweep_dir, shots, out_path=args.out, set_name=set_name)
        print(f"Wrote Tier-2 sheet ({SHEET_W}x{SHEET_H}): {out_file}")
        return 0

    p1, p2 = build_rooms_sweep_sheets(sweep_dir)
    print(f"Wrote part 1 ({SHEET_W}x{SHEET_H}): {p1}")
    print(f"Wrote part 2 ({SHEET_W}x{SHEET_H}): {p2}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
