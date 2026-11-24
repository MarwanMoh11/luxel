#!/usr/bin/env python3
"""Luxel Round 8 Opening 5 Minutes & Credits Visual QA Contact-Sheet Assembler.

Reads `<dir>/open_01.png..open_06.png` and `manifest.json`, upscales each
320x180 capture 2x nearest-neighbor (640x360), adds crisp dark title strips,
and writes a 2x3 contact sheet (`docs/visual_qa/opening_r8_sheet.png` by default).

Usage:
  uv run --no-project --with pillow python tools/design_critic/assemble_opening_qa.py [dir] [--out <path>]
"""

from __future__ import annotations

import argparse
import json
import os
from typing import Any, Dict, List, Optional, Sequence

from PIL import Image, ImageDraw, ImageFont

# 2x3 Sheet geometry: 1316 x 1174
TILE_W = 640
TILE_H = 360
TILE_HDR_H = 18
SHEET_TOP_H = 22
MARGIN_X = 12
GAP_X = 12
GAP_Y = 6
MARGIN_BOTTOM = 6
COLS = 2
ROWS = 3
SHEET_W = MARGIN_X + COLS * TILE_W + (COLS - 1) * GAP_X + MARGIN_X  # 1316
SHEET_H = SHEET_TOP_H + ROWS * (TILE_HDR_H + TILE_H) + (ROWS - 1) * GAP_Y + MARGIN_BOTTOM  # 1174

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
    {"index": 1, "file": "open_01.png", "slot": "01_intro_sequence", "title": "Intro Sequence", "sub": "Cards t=4.2s"},
    {"index": 2, "file": "open_02.png", "slot": "02_awakening_lantern", "title": "Awakening & Floor Lantern", "sub": "Bell Isle Plaza"},
    {"index": 3, "file": "open_03.png", "slot": "03_first_combat", "title": "First Combat Encounter", "sub": "Plaza Warden"},
    {"index": 4, "file": "open_04.png", "slot": "04_first_shrine", "title": "First Shrine (Dash)", "sub": "Lantern Orchard"},
    {"index": 5, "file": "open_05.png", "slot": "05_first_beacon", "title": "First Beacon Relit", "sub": "Orchard Beacon"},
    {"index": 6, "file": "open_06.png", "slot": "06_credits_roll", "title": "Credits Roll", "sub": "Archipelago Starfield"},
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


def _load_manifest(opening_dir: str) -> List[Dict[str, Any]]:
    mf_path = os.path.join(opening_dir, "manifest.json")
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


def _format_tile_label(shot: Dict[str, Any], idx_fallback: int) -> str:
    idx = shot.get("index", idx_fallback)
    title = str(shot.get("title", shot.get("slot", "Opening Shot")))
    sub = str(shot.get("sub", ""))
    note = str(shot.get("note", ""))
    tail = f"  |  {sub}" if sub else ""
    extra = f"  [{note}]" if note else ""
    return f"#{idx} {title}{tail}{extra}"


def build_opening_sheet(opening_dir: str, out_path: str) -> str:
    shots = _load_manifest(opening_dir)
    font_top = _load_font(12)
    font_tile = _load_font(11)

    canvas = Image.new("RGBA", (SHEET_W, SHEET_H), BG_SHEET)
    draw = ImageDraw.Draw(canvas)

    draw.rectangle([0, 0, SHEET_W - 1, SHEET_TOP_H - 1], fill=BG_HEADER)
    draw.text(
        (MARGIN_X, 4),
        "LUXEL ROUND 8 OPENING 5 MIN & CREDITS QA  |  6-SHOT 2x3 CONTACT SHEET  (640x360 2x nearest)",
        fill=TEXT_GOLD,
        font=font_top,
    )

    for i in range(6):
        shot = shots[i] if i < len(shots) else dict(DEFAULT_SHOTS[i])
        col = i % COLS
        row = i // COLS
        x0 = MARGIN_X + col * (TILE_W + GAP_X)
        y0 = SHEET_TOP_H + row * (TILE_HDR_H + TILE_H + GAP_Y)

        draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H - 1], fill=BG_TILE_HDR)
        slot = str(shot.get("slot", ""))
        is_gold_shot = slot in ("01_intro_sequence", "02_awakening_lantern", "05_first_beacon")
        is_sky_shot = slot in ("04_first_shrine", "06_credits_roll")
        label_col = TEXT_GOLD if is_gold_shot else (TEXT_SKY if is_sky_shot else TEXT_MAIN)
        border_col = BORDER_GOLD if is_gold_shot else (BORDER_ACCENT if is_sky_shot else BORDER_TILE)

        draw.text((x0 + 6, y0 + 2), _format_tile_label(shot, i + 1)[:92], fill=label_col, font=font_tile)

        shot_path = os.path.join(opening_dir, str(shot.get("file", f"open_{i + 1:02d}.png")))
        tile_img = _load_upscaled_shot(shot_path, font_top, f"Missing: {os.path.basename(shot_path)}")
        canvas.paste(tile_img, (x0, y0 + TILE_HDR_H))

        draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + TILE_HDR_H + TILE_H - 1], outline=border_col, width=1)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    canvas.save(out_path)
    return out_path


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Assemble Luxel Opening 5 Min & Credits Visual QA 2x3 contact sheet")
    parser.add_argument("dir", nargs="?", default="docs/visual_qa/opening_r8", help="Directory containing open_01..06.png")
    parser.add_argument("--out", default="", help="Output PNG path (default: <parent>/opening_r8_sheet.png)")
    args = parser.parse_args(argv)

    opening_dir = os.path.abspath(args.dir)
    if not os.path.isdir(opening_dir):
        print(f"ERROR: directory not found: {opening_dir}")
        return 1

    if args.out:
        out_path = os.path.abspath(args.out)
    elif os.path.basename(opening_dir) == "opening_r8":
        out_path = os.path.join(os.path.dirname(opening_dir), "opening_r8_sheet.png")
    else:
        out_path = os.path.join(opening_dir, "opening_sheet.png")

    written = build_opening_sheet(opening_dir, out_path)
    print(f"Wrote opening sheet ({SHEET_W}x{SHEET_H}): {written}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
