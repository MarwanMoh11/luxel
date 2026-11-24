#!/usr/bin/env python3
"""Luxel Round 4 8-Shot Live Action Visual QA Contact-Sheet Assembler.

Reads `<dir>/action_01.png..action_08.png` and `manifest.json`, upscales each
320x180 capture 2x nearest-neighbor (640x360), adds crisp dark title strips,
and writes a 2x4 contact sheet (`docs/visual_qa/action_sheet.png` by default).

Usage:
  uv run --no-project --with pillow python tools/design_critic/assemble_action_qa.py [dir] [--out <path>]
"""

from __future__ import annotations

import argparse
import json
import os
from typing import Any, Dict, List, Optional, Sequence

from PIL import Image, ImageDraw, ImageFont

# 2x4 Sheet geometry: 1316 x 1564
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
TEXT_MAIN = (255, 244, 220, 255)
TEXT_GOLD = (255, 217, 140, 255)
TEXT_SKY = (120, 169, 218, 255)
TEXT_CORAL = (226, 114, 91, 255)

DEFAULT_SHOTS: List[Dict[str, Any]] = [
    {"index": 1, "file": "action_01.png", "slot": "01_prism_split", "title": "Prism Split Fan", "island": 2, "region": "lighthouse_r2"},
    {"index": 2, "file": "action_02.png", "slot": "02_true_lens", "title": "True Lens Reveal", "island": 5, "region": "orrery_r1"},
    {"index": 3, "file": "action_03.png", "slot": "03_sunflare", "title": "Sunflare Detonation", "island": 6, "region": "kiln_r1"},
    {"index": 4, "file": "action_04.png", "slot": "04_boss_p2", "title": "Boss Phase 2 Fight", "island": 6, "region": "kiln_r10"},
    {"index": 5, "file": "action_05.png", "slot": "05_dawn_wave", "title": "Great Lamp Dawn Wave", "island": 1, "region": "belfry_r7"},
    {"index": 6, "file": "action_06.png", "slot": "06_shrine_claim", "title": "Shrine Claim Ceremony", "island": 5, "region": "orrery_r5"},
    {"index": 7, "file": "action_07.png", "slot": "07_door_unlock", "title": "Boss Door Unlock Burst", "island": 5, "region": "orrery_r9"},
    {"index": 8, "file": "action_08.png", "slot": "08_blue_portal", "title": "Blue Portal Warp", "island": 4, "region": "conservatory_r1"},
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


def _load_manifest(action_dir: str) -> List[Dict[str, Any]]:
    mf_path = os.path.join(action_dir, "manifest.json")
    if os.path.exists(mf_path):
        with open(mf_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        shots = data.get("shots", [])
        if isinstance(shots, list) and shots:
            return shots
    return [dict(item) for item in DEFAULT_SHOTS]


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
    title = str(shot.get("title", shot.get("slot", "Action Shot")))
    isl = shot.get("island", "?")
    region = str(shot.get("region", "?"))
    note = str(shot.get("note", ""))
    extra = f" [{note}]" if note else ""
    return f"#{idx} {title}  |  ISL {isl} {region}{extra}"


def build_action_sheet(action_dir: str, out_path: str) -> str:
    shots = _load_manifest(action_dir)
    font_top = _load_font(12)
    font_tile = _load_font(11)

    canvas = Image.new("RGBA", (SHEET_W, SHEET_H), BG_SHEET)
    draw = ImageDraw.Draw(canvas)

    draw.rectangle([0, 0, SHEET_W - 1, SHEET_TOP_H - 1], fill=BG_HEADER)
    draw.text(
        (MARGIN_X, 4),
        "LUXEL ROUND 4 LIVE ACTION QA  |  8-SHOT 2x4 CONTACT SHEET  (640x360 2x nearest)",
        fill=TEXT_GOLD,
        font=font_top,
    )

    for i in range(8):
        shot = shots[i] if i < len(shots) else dict(DEFAULT_SHOTS[i])
        col = i % COLS
        row = i // COLS
        x0 = MARGIN_X + col * (TILE_W + GAP_X)
        y0 = SHEET_TOP_H + row * (TILE_HDR_H + TILE_H + GAP_Y)

        draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H - 1], fill=BG_TILE_HDR)
        slot = str(shot.get("slot", ""))
        is_gold_shot = slot in ("03_sunflare", "04_boss_p2", "05_dawn_wave")
        is_sky_shot = slot in ("01_prism_split", "02_true_lens", "08_blue_portal")
        label_col = TEXT_GOLD if is_gold_shot else (TEXT_SKY if is_sky_shot else TEXT_MAIN)
        draw.text((x0 + 6, y0 + 2), _format_tile_label(shot)[:90], fill=label_col, font=font_tile)

        shot_path = os.path.join(action_dir, str(shot.get("file", f"action_{i + 1:02d}.png")))
        tile_img = _load_upscaled_shot(shot_path, font_top, f"Missing: {os.path.basename(shot_path)}")
        canvas.paste(tile_img, (x0, y0 + TILE_HDR_H))

        border_col = BORDER_GOLD if is_gold_shot else (BORDER_ACCENT if is_sky_shot else BORDER_TILE)
        draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H + TILE_H - 1], outline=border_col, width=1)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    canvas.save(out_path)
    return out_path


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Assemble Luxel 8-Shot Live Action Visual QA 2x4 contact sheet")
    parser.add_argument("dir", nargs="?", default="docs/visual_qa/action", help="Directory containing action_01..08.png")
    parser.add_argument("--out", default="", help="Output PNG path (default: <parent>/action_sheet.png)")
    args = parser.parse_args(argv)

    action_dir = os.path.abspath(args.dir)
    if not os.path.isdir(action_dir):
        print(f"ERROR: directory not found: {action_dir}")
        return 1

    if args.out:
        out_path = os.path.abspath(args.out)
    elif os.path.basename(action_dir) == "action":
        out_path = os.path.join(os.path.dirname(action_dir), "action_sheet.png")
    else:
        out_path = os.path.join(action_dir, "action_sheet.png")

    written = build_action_sheet(action_dir, out_path)
    print(f"Wrote action sheet ({SHEET_W}x{SHEET_H}): {written}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
