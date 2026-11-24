#!/usr/bin/env python3
"""Build the shared Last Light pixel-art atlas for Luxel puzzle interactables.

Outputs:
  luxel/art/props/puzzle_interactables.png
  luxel/art/props/puzzle_interactables.json

Run via uv (Pillow is provided ephemeral):
  uv run --no-project --with pillow python luxel/art/tools/build_puzzle_props.py
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

from PIL import Image

# Strict 20 Last Light colours (docs/ART_STYLE.md & luxel/ui/palette.gd)
PAL_HEX: Dict[str, str] = {
    "void": "#0d0b1e",
    "night": "#211a3b",
    "dusk": "#3d2c5c",
    "plum": "#6a3d6f",
    "wine": "#a0466a",
    "coral": "#e2725b",
    "apricot": "#f5a96a",
    "gold": "#ffd98c",
    "cream": "#fff4dc",
    "pine": "#1d3d4c",
    "teal": "#2b6b68",
    "jade": "#4c9e78",
    "lime": "#a3cf7d",
    "deep": "#263873",
    "blue": "#3e6db0",
    "sky": "#78a9da",
    "ice": "#c7e5ef",
    "mauve": "#8a6e91",
    "stone": "#c2a7ae",
    "rose": "#ec9fa8",
}

RGBA: Dict[str, Tuple[int, int, int, int]] = {
    k: (int(v[1:3], 16), int(v[3:5], 16), int(v[5:7], 16), 255)
    for k, v in PAL_HEX.items()
}
TRANS = (0, 0, 0, 0)
VALID_RGBA = set(RGBA.values()) | {TRANS}

# Single-character palette codes for hand-crafted pixel grids ('.' = transparent)
CHAR_MAP: Dict[str, str] = {
    "v": "void",
    "n": "night",
    "d": "dusk",
    "p": "plum",
    "w": "wine",
    "c": "coral",
    "a": "apricot",
    "g": "gold",
    "e": "cream",
    "i": "pine",
    "t": "teal",
    "j": "jade",
    "l": "lime",
    "q": "deep",
    "b": "blue",
    "s": "sky",
    "f": "ice",
    "m": "mauve",
    "r": "stone",
    "o": "rose",
}


class Canvas:
    """Pixel-exact RGBA drawing buffer restricted to the 20 Last Light colours."""

    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.img = Image.new("RGBA", (w, h), TRANS)
        self.px = self.img.load()

    def put(self, x: int, y: int, col: str) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = RGBA[col]

    def clear(self, x: int, y: int) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = TRANS

    def get(self, x: int, y: int) -> Tuple[int, int, int, int]:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return TRANS

    def rect(self, x: int, y: int, w: int, h: int, col: str) -> None:
        c = RGBA[col]
        for yy in range(max(0, y), min(self.h, y + h)):
            for xx in range(max(0, x), min(self.w, x + w)):
                self.px[xx, yy] = c

    def hline(self, x0: int, x1: int, y: int, col: str) -> None:
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, col)

    def vline(self, x: int, y0: int, y1: int, col: str) -> None:
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, col)

    def line(self, x0: int, y0: int, x1: int, y1: int, col: str) -> None:
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        x, y = x0, y0
        while True:
            self.put(x, y, col)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def stamp_grid(self, rows: Sequence[str], ox: int = 0, oy: int = 0, remap: Dict[str, str] | None = None) -> None:
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in (".", " "):
                    continue
                key = CHAR_MAP[ch]
                if remap and key in remap:
                    key = remap[key]
                self.put(ox + x, oy + y, key)

    def outline(self, col: str = "void", include_diag: bool = False) -> None:
        """Add a 1px crisp pixel outline around all opaque pixels."""
        src = self.img.copy()
        spx = src.load()
        dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        if include_diag:
            dirs += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        c = RGBA[col]
        for y in range(self.h):
            for x in range(self.w):
                if spx[x, y][3] != 0:
                    continue
                for dx, dy in dirs:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and spx[nx, ny][3] != 0:
                        self.px[x, y] = c
                        break


def from_grid(w: int, h: int, rows: Sequence[str], remap: Dict[str, str] | None = None) -> Image.Image:
    assert len(rows) == h, f"Expected {h} rows, got {len(rows)}"
    for i, r in enumerate(rows):
        assert len(r) == w, f"Row {i} expected width {w}, got {len(r)}: {r!r}"
    cv = Canvas(w, h)
    cv.stamp_grid(rows, 0, 0, remap=remap)
    return cv.img


# ============================================================================
# 1. BLUE PORTAL (24x24, anchor [12, 12])
# ============================================================================

def _draw_portal_ring(cv: Canvas, mode: str, frame: int = 0) -> None:
    """Draw a carved octagonal slate floor ring with 4 cardinal rune sockets."""
    cx, cy = 11.5, 11.5
    # Octagonal distance metric: max(|dx|, |dy|, (|dx|+|dy|)*0.72)
    for y in range(24):
        for x in range(24):
            dx = x - cx
            dy = y - cy
            adx, ady = abs(dx), abs(dy)
            oct_d = max(adx, ady, (adx + ady) * 0.71)
            if oct_d > 11.4:
                continue
            if oct_d > 10.3:
                cv.put(x, y, "void")
            elif oct_d > 7.4:
                # Carved beveled slate stone ring, top-left lit
                light = -(dx * 0.65 + dy * 0.75)
                if oct_d > 9.4:
                    # Outer chamfer
                    if light > 3.2:
                        col = "stone" if mode != "reject" else "apricot"
                    elif light > -1.0:
                        col = "mauve" if mode != "reject" else "coral"
                    else:
                        col = "night"
                elif oct_d > 8.1:
                    # Main carved masonry face with recessed stone joints
                    is_joint = (abs(dx) < 0.7 or abs(dy) < 0.7 or abs(adx - ady) < 0.75)
                    if is_joint:
                        col = "night"
                    elif light > 3.8:
                        col = "stone"
                    elif light > 0.2:
                        col = "mauve"
                    elif light > -4.2:
                        col = "dusk"
                    else:
                        col = "night"
                else:
                    # Inner bevel lip facing portal cavity
                    if mode == "active":
                        col = "sky" if (x + y + frame) % 2 == 0 else "blue"
                    elif mode == "reject":
                        col = "coral" if (x + y) % 2 == 0 else "wine"
                    else:
                        col = "deep" if light < 0 else "dusk"
                cv.put(x, y, col)
            else:
                # Recessed interior well
                if oct_d > 6.6:
                    cv.put(x, y, "void" if mode == "dormant" else ("deep" if mode == "active" else "wine"))
                else:
                    cv.put(x, y, "void")

    # 4 cardinal carved crystal sockets on the octagonal rim
    sockets = [(11, 2), (11, 20), (2, 11), (20, 11)]
    for si, (sx, sy) in enumerate(sockets):
        # 2x2 framed crystal inlay
        for oy in (-1, 0, 1, 2):
            for ox in (-1, 0, 1, 2):
                if (ox in (-1, 2)) and (oy in (-1, 2)):
                    continue
                cv.put(sx + ox, sy + oy, "void")
        if mode == "active":
            pulse = (frame + si) % 2 == 0
            cv.put(sx, sy, "cream" if pulse else "ice")
            cv.put(sx + 1, sy, "ice" if pulse else "sky")
            cv.put(sx, sy + 1, "sky")
            cv.put(sx + 1, sy + 1, "blue")
        elif mode == "reject":
            cv.put(sx, sy, "gold")
            cv.put(sx + 1, sy, "apricot")
            cv.put(sx, sy + 1, "coral")
            cv.put(sx + 1, sy + 1, "wine")
        else:
            cv.put(sx, sy, "blue")
            cv.put(sx + 1, sy, "deep")
            cv.put(sx, sy + 1, "deep")
            cv.put(sx + 1, sy + 1, "night")


def build_portal_dormant() -> List[Image.Image]:
    cv = Canvas(24, 24)
    _draw_portal_ring(cv, "dormant")
    # Recessed dormant rune channels inside the dark stone pit
    for y in range(6, 18):
        for x in range(6, 18):
            dx, dy = x - 11.5, y - 11.5
            r = math.hypot(dx, dy)
            if 5.1 <= r <= 6.2:
                cv.put(x, y, "night")
            elif 3.3 <= r <= 4.3:
                cv.put(x, y, "deep" if (x + y) % 2 == 0 else "night")
    # Diagonal carved rune grooves
    for d in (2, 3, 4):
        cv.put(11 - d, 11 - d, "deep")
        cv.put(12 + d, 11 - d, "deep")
        cv.put(11 - d, 12 + d, "deep")
        cv.put(12 + d, 12 + d, "deep")
    # Center dormant crystal node
    cv.rect(10, 10, 4, 4, "night")
    cv.put(11, 11, "blue")
    cv.put(12, 11, "deep")
    cv.put(11, 12, "deep")
    cv.put(12, 12, "deep")
    return [cv.img]


def build_portal_active() -> List[Image.Image]:
    frames: List[Image.Image] = []
    cx, cy = 11.5, 11.5
    for f in range(4):
        cv = Canvas(24, 24)
        _draw_portal_ring(cv, "active", frame=f)
        phase = f * (math.pi * 0.5)
        for y in range(5, 19):
            for x in range(5, 19):
                dx, dy = x - cx, y - cy
                r = math.hypot(dx, dy)
                if r > 6.65:
                    continue
                ang = math.atan2(dy, dx)
                # 2-arm logarithmic pixel-stepped spiral vortex
                arm = math.sin(2.0 * (ang + phase) - r * 0.95)
                if r <= 1.55:
                    col = "cream" if (f % 2 == 0 or r < 1.0) else "ice"
                elif r <= 3.1:
                    if arm > 0.25:
                        col = "cream" if r < 2.2 else "ice"
                    elif arm > -0.35:
                        col = "sky"
                    else:
                        col = "blue"
                elif r <= 5.0:
                    if arm > 0.45:
                        col = "ice"
                    elif arm > -0.1:
                        col = "sky"
                    elif arm > -0.6:
                        col = "blue"
                    else:
                        col = "deep"
                else:
                    if arm > 0.35:
                        col = "sky"
                    elif arm > -0.3:
                        col = "blue"
                    else:
                        col = "deep"
                cv.put(x, y, col)
        # Orbiting crisp 1px rune sparks on the inner bevel
        for k in range(4):
            a = phase + k * (math.pi * 0.5) + 0.35
            sx = int(round(cx + math.cos(a) * 6.0))
            sy = int(round(cy + math.sin(a) * 6.0))
            cv.put(sx, sy, "cream" if k % 2 == f % 2 else "ice")
        frames.append(cv.img)
    return frames


def build_portal_reject() -> List[Image.Image]:
    cv = Canvas(24, 24)
    _draw_portal_ring(cv, "reject")
    # Cracked amber/coral rejection sparks inside pit
    for y in range(6, 18):
        for x in range(6, 18):
            r = math.hypot(x - 11.5, y - 11.5)
            if 4.8 <= r <= 6.2:
                cv.put(x, y, "wine" if (x + y) % 2 == 0 else "night")
    # Jagged amber spark bolts
    cv.line(7, 8, 10, 10, "coral")
    cv.line(10, 10, 13, 13, "gold")
    cv.line(13, 13, 16, 15, "coral")
    cv.line(16, 8, 13, 11, "apricot")
    cv.line(10, 13, 7, 16, "apricot")
    cv.put(11, 11, "cream")
    cv.put(12, 12, "gold")
    # Rim spark flecks
    for sx, sy, col in [(5, 5, "gold"), (18, 6, "coral"), (6, 18, "apricot"), (18, 17, "gold")]:
        cv.put(sx, sy, col)
    return [cv.img]


# ============================================================================
# 2. MIRROR / BLUE TRANSFORMER (20x24, anchor [10, 14])
# ============================================================================

def _build_mirror_base(pushable: bool) -> Image.Image:
    """Carved octagonal stone/brass turntable base (20x24, base sits y=10..22)."""
    cv = Canvas(20, 24)
    # Octagonal stone/slate plinth footprint: x=2..17, y=10..21
    # Top face of turntable y=10..17, front bevel y=18..21
    for y in range(10, 22):
        for x in range(2, 18):
            dx = abs(x - 9.5)
            dy = abs(y - 15.5)
            if dx + dy > 11.2:
                continue
            if y >= 19:
                # Front pedestal skirt
                if x <= 6:
                    cv.put(x, y, "mauve" if y == 19 else "dusk")
                elif x <= 13:
                    cv.put(x, y, "dusk" if y == 19 else "night")
                else:
                    cv.put(x, y, "night")
            else:
                # Top turntable deck
                if dx > 6.3 or dy > 4.3 or (dx + dy > 9.8):
                    # Chamfer rim (top-left lit)
                    if x + y < 23:
                        cv.put(x, y, "stone")
                    elif x + y < 28:
                        cv.put(x, y, "mauve")
                    else:
                        cv.put(x, y, "dusk")
                else:
                    # Inner recessed gear turntable disk
                    r = math.hypot(x - 9.5, (y - 14.2) * 1.25)
                    if r < 4.5:
                        cv.put(x, y, "night")
                    elif r < 5.6:
                        cv.put(x, y, "deep" if pushable else "dusk")
                    else:
                        cv.put(x, y, "dusk" if x > 10 else "mauve")
    # Crisp 1px void outline around base
    cv.outline("void")

    # Cardinal gear-notches / brass indexing rivets on the turntable
    for gx, gy in [(9, 10), (10, 10), (9, 19), (10, 19)]:
        cv.put(gx, gy, "gold" if not pushable else "sky")
    cv.put(9, 10, "cream" if not pushable else "ice")

    if pushable:
        # Prominent side push-grip handles (left x=0..2, right x=17..19) + top/bottom rail cleats
        # Left handle
        cv.rect(0, 13, 2, 5, "void")
        cv.put(1, 14, "ice")
        cv.put(1, 15, "sky")
        cv.put(1, 16, "blue")
        cv.put(2, 14, "sky")
        cv.put(2, 15, "blue")
        cv.put(2, 16, "deep")
        # Right handle
        cv.rect(18, 13, 2, 5, "void")
        cv.put(18, 14, "sky")
        cv.put(18, 15, "blue")
        cv.put(18, 16, "deep")
        cv.put(17, 14, "blue")
        cv.put(17, 15, "deep")
        cv.put(17, 16, "night")
        # Front brass/blue rail notch cleats
        cv.put(6, 21, "sky")
        cv.put(7, 21, "blue")
        cv.put(12, 21, "blue")
        cv.put(13, 21, "deep")
    else:
        # Fixed stone anchor bolts at 4 corners
        for bx, by in [(4, 12), (15, 12), (4, 18), (15, 18)]:
            cv.put(bx, by, "apricot")
            cv.put(bx, by + 1, "wine")
        cv.put(4, 12, "gold")
    return cv.img


def _build_mirror_crystal(angle_deg: int, palette_kind: str) -> Image.Image:
    r"""Crisp faceted upright crystal / brass mirror slab at exact 0/45/90/135 deg.

    angle_deg is the surface normal angle (matching LxMirror.normal):
      0   -> vertical slab (|)
      45  -> slash diagonal (/)
      90  -> horizontal slab (—)
      135 -> backslash diagonal (\)
    """
    cv = Canvas(20, 24)
    if palette_kind == "blue":
        c_dark, c_mid, c_hi, c_spec, c_core = "deep", "blue", "sky", "ice", "cream"
        c_frame_dk, c_frame_lt = "night", "mauve"
    else:
        c_dark, c_mid, c_hi, c_spec, c_core = "wine", "coral", "apricot", "gold", "cream"
        c_frame_dk, c_frame_lt = "plum", "gold"

    if angle_deg == 0:
        # Vertical slab (|) — tall narrow faceted crystal blade facing left & right
        cv.rect(8, 14, 4, 3, c_frame_dk)
        cv.put(8, 14, c_frame_lt)
        cv.rect(8, 3, 4, 11, c_mid)
        cv.vline(8, 4, 13, c_hi)      # lit left bevel
        cv.vline(9, 2, 13, c_spec)    # sharp ridge highlight
        cv.vline(10, 2, 13, c_mid)
        cv.vline(11, 4, 13, c_dark)   # right shadow bevel
        cv.put(9, 2, c_core)
        cv.put(10, 2, c_spec)
        cv.put(9, 5, c_core)
        cv.put(9, 6, c_core)
        cv.put(8, 7, c_spec)
        cv.put(10, 9, c_hi)
        cv.put(11, 12, c_frame_dk)
    elif angle_deg == 90:
        # Horizontal slab (—) — sleek beveled wide crystal prism facing up & down
        cv.rect(3, 12, 2, 4, c_frame_dk)
        cv.rect(15, 12, 2, 4, c_frame_dk)
        cv.put(3, 12, c_frame_lt)
        cv.put(15, 12, c_frame_lt)
        cv.rect(4, 7, 12, 6, c_mid)
        cv.hline(5, 14, 6, c_spec)    # chamfered top crest
        cv.hline(4, 14, 7, c_hi)
        cv.hline(4, 15, 11, c_dark)
        cv.hline(5, 14, 12, c_dark)
        cv.vline(4, 7, 11, c_hi)
        cv.vline(15, 7, 11, c_dark)
        for i in range(4):
            cv.put(6 + i, 10 - i, c_spec)
            cv.put(7 + i, 10 - i, c_hi)
        cv.put(7, 7, c_core)
        cv.put(8, 6, c_core)
        cv.put(12, 7, c_spec)
        cv.put(13, 6, c_core)
    elif angle_deg == 45:
        # Slash diagonal (/) — top-right to bottom-left faceted prism wall
        for step in range(10):
            bx = 5 + step
            by = 15 - step
            for h in range(5):
                yy = by - h
                if h == 4:
                    col = c_core if step in (2, 3, 7) else c_spec
                elif h == 3:
                    col = c_spec if step < 5 else c_hi
                elif h == 2:
                    col = c_hi if step < 6 else c_mid
                elif h == 1:
                    col = c_mid
                else:
                    col = c_dark
                cv.put(bx, yy, col)
            cv.put(bx + 1, by - 1, c_dark)
            cv.put(bx + 1, by - 2, c_mid if step < 5 else c_dark)
        cv.put(5, 15, c_frame_lt)
        cv.put(5, 16, c_frame_dk)
        cv.put(14, 6, c_frame_lt)
        cv.put(15, 6, c_frame_dk)
        cv.put(8, 8, c_core)
        cv.put(9, 7, c_core)
        cv.put(7, 10, c_spec)
    else:  # 135 deg
        # Backslash diagonal (\) — top-left to bottom-right faceted prism wall
        for step in range(10):
            bx = 5 + step
            by = 6 + step
            for h in range(5):
                yy = by - h
                if h == 4:
                    col = c_core if step in (1, 2, 6) else c_spec
                elif h == 3:
                    col = c_spec if step < 6 else c_hi
                elif h == 2:
                    col = c_hi if step < 5 else c_mid
                elif h == 1:
                    col = c_mid
                else:
                    col = c_dark
                cv.put(bx, yy, col)
            cv.put(bx - 1, by - 1, c_hi if step < 5 else c_mid)
            cv.put(bx - 1, by, c_dark)
        cv.put(5, 6, c_frame_lt)
        cv.put(4, 6, c_frame_dk)
        cv.put(14, 15, c_frame_lt)
        cv.put(14, 16, c_frame_dk)
        cv.put(7, 4, c_core)
        cv.put(8, 5, c_core)
        cv.put(11, 9, c_spec)

    cv.outline("void")
    return cv.img


def _build_mirror_flash(palette_kind: str) -> Image.Image:
    """Bright crisp pixel-art crystal starburst overlay on light bounce."""
    cv = Canvas(20, 24)
    c_mid, c_hi, c_core = ("sky", "ice", "cream") if palette_kind == "blue" else ("apricot", "gold", "cream")
    cx, cy = 10, 9
    # 8-ray crisp star burst + dither ring
    cv.hline(cx - 7, cx + 7, cy, c_mid)
    cv.hline(cx - 5, cx + 5, cy, c_hi)
    cv.vline(cx, cy - 7, cy + 7, c_mid)
    cv.vline(cx, cy - 5, cy + 5, c_hi)
    for d in (1, 2, 3, 4):
        col = c_core if d <= 1 else (c_hi if d <= 2 else c_mid)
        cv.put(cx - d, cy - d, col)
        cv.put(cx + d, cy - d, col)
        cv.put(cx - d, cy + d, col)
        cv.put(cx + d, cy + d, col)
    cv.rect(cx - 1, cy - 1, 3, 3, c_core)
    # Outer corner sparkle pips
    for sx, sy in [(cx - 6, cy - 4), (cx + 6, cy - 4), (cx - 6, cy + 4), (cx + 6, cy + 4)]:
        cv.put(sx, sy, c_hi)
    return cv.img


# ============================================================================
# 3. SWITCH EYE (20x22, anchor [10, 14]; eye socket center at (10, 10) -> local (0, -4))
# ============================================================================

def _build_switch_eye(is_blue: bool, lit: bool, frame: int = 0) -> Image.Image:
    cv = Canvas(20, 22)
    # Stepped carved stone pedestal: y=15..20
    cv.rect(4, 18, 12, 3, "night")
    cv.rect(4, 18, 10, 2, "dusk")
    cv.hline(4, 12, 18, "mauve")
    cv.hline(4, 8, 18, "stone")

    cv.rect(6, 14, 8, 4, "night")
    cv.rect(6, 14, 6, 4, "dusk")
    cv.vline(6, 14, 17, "mauve")
    cv.vline(7, 14, 16, "stone")

    # Carved almond-shaped eye-plinth housing: centered at (10, 10), x=2..17, y=5..15
    cx, cy = 9.5, 10.0
    for y in range(4, 16):
        for x in range(2, 18):
            dx = (x - cx) / 7.2
            dy = (y - cy) / 4.8
            # Almond / pointed eye shape
            almond = abs(dy) + 0.42 * (dx * dx)
            if almond > 1.05:
                continue
            if almond > 0.72:
                # Outer sculpted brow & lower eyelid rim
                top_lit = (y < 10) and (x < 13)
                if is_blue:
                    if lit:
                        col = "ice" if top_lit else ("sky" if y < 12 else "blue")
                    else:
                        col = "sky" if top_lit else ("blue" if y < 12 else "deep")
                else:
                    if lit:
                        col = "gold" if top_lit else ("apricot" if y < 12 else "coral")
                    else:
                        col = "stone" if top_lit else ("mauve" if y < 12 else "dusk")
                cv.put(x, y, col)
            elif almond > 0.56:
                # Inner eyelid bevel — kept crisp even when lit so almond silhouette pops!
                if is_blue:
                    col = "deep" if lit else "blue"
                else:
                    col = "wine" if lit else ("apricot" if y < 10 else "wine")
                cv.put(x, y, col)
            else:
                # Recessed eyeball cavity
                if lit:
                    r_eye = math.hypot((x - cx) * 0.75, y - cy)
                    if is_blue:
                        if r_eye < 1.5:
                            col = "cream"
                        elif r_eye < 2.8:
                            col = "ice" if frame == 0 else "cream"
                        else:
                            col = "sky" if frame == 0 else "ice"
                    else:
                        if r_eye < 1.5:
                            col = "cream"
                        elif r_eye < 2.8:
                            col = "gold" if frame == 0 else "cream"
                        else:
                            col = "apricot" if frame == 0 else "gold"
                    cv.put(x, y, col)
                else:
                    # Deep recessed sclera/socket — leaves room for dynamic pixel pupil!
                    if y <= 8:
                        cv.put(x, y, "night")
                    elif abs(x - cx) < 3.6 and abs(y - cy) < 2.0:
                        cv.put(x, y, "deep" if not is_blue else "blue")
                    else:
                        cv.put(x, y, "void")

    # Crown crest above the eye
    if is_blue:
        # Faceted sapphire prism crest (unmistakable "Requires Blue Light" silhouette)
        cv.put(9, 2, "ice" if lit else "sky")
        cv.put(10, 2, "cream" if lit else "ice")
        cv.rect(8, 3, 4, 2, "sky" if lit else "blue")
        cv.put(8, 3, "ice")
        cv.put(9, 3, "cream" if lit else "ice")
        cv.put(11, 4, "deep")
    else:
        # Carved golden sun-arch finial
        cv.put(9, 3, "gold")
        cv.put(10, 3, "apricot")
        cv.rect(8, 4, 4, 1, "gold" if lit else "apricot")
        if lit:
            cv.put(9, 2, "cream")
            cv.put(10, 2, "gold")

    # Corner carved eyelid wing-tips
    cv.put(2, 10, "gold" if not is_blue else "sky")
    cv.put(17, 10, "apricot" if not is_blue else "blue")

    cv.outline("void")

    # Ordered pixel-dither sparkles when lit (outside outline, zero alpha blur!)
    if lit:
        sp_c = "cream" if frame == 0 else ("ice" if is_blue else "gold")
        sp_m = "sky" if is_blue else "apricot"
        sparks = [(2, 4), (17, 4), (1, 10), (18, 10), (5, 2), (14, 2)]
        for i, (sx, sy) in enumerate(sparks):
            if (i + frame) % 2 == 0:
                cv.put(sx, sy, sp_c)
            else:
                cv.put(sx, sy, sp_m)
    return cv.img


# ============================================================================
# 4. BRAMBLE (16x16 tiled, anchor [8, 8])
# ============================================================================

def build_bramble_tile() -> List[Image.Image]:
    # Organic tangled dark-pine & wine thorn briar with jade/lime leaf clusters & rose buds
    grid0 = [
        "vvniitjtivdpwivv",
        "vniitjljtiwpmniv",
        "niitjltinvpwocnv",
        "vniitindpwpiwinv",
        "vdpwpndwmiitjinv",
        "dpwocwniitjljtiv",
        "vpwpinniitjltiiv",
        "nviitjinvdpwpiiv",
        "niitjljtvpwccwiv",
        "iitjltiivpwocwnv",
        "niitiivndpwpinnv",
        "vniivdpwmiitjinv",
        "vnvdpwpinijljtiv",
        "vdpwocwnitjltiiv",
        "vnpwpinniitjtiiv",
        "vvvnnivvniitiivv",
    ]
    # Frame 1: gentle 1px leaf/bud sway in the breeze
    grid1 = [
        "vvniijttivdpwivv",
        "vniitjljtiwpmniv",
        "niijjltinvpwocnv",
        "vniitindpwpiwinv",
        "vdpwpndwmiitjinv",
        "dpwocwniitjjltiv",
        "vpwpinniitjltiiv",
        "nviitjinvdpwpiiv",
        "niitjjltvpwccwiv",
        "iitjltiivpwocwnv",
        "niitiivndpwpinnv",
        "vniivdpwmiitjinv",
        "vnvdpwpinijjltiv",
        "vdpwocwnitjltiiv",
        "vnpwpinniijttiiv",
        "vvvnnivvniitiivv",
    ]
    return [from_grid(16, 16, grid0), from_grid(16, 16, grid1)]


def build_bramble_charred() -> List[Image.Image]:
    # Transparent background! Subtle charred root-stumps & ash flecks
    grid = [
        "................",
        "..vn............",
        ".vndm.....r.....",
        "..vp............",
        "................",
        "..........nv....",
        "....m....ndpv...",
        "..........vn....",
        "................",
        "................",
        ".vn.............",
        ".ndp......m.....",
        "..nv............",
        ".........vnr....",
        ".....r...ndv....",
        "................",
    ]
    return [from_grid(16, 16, grid)]


# ============================================================================
# 5. CRACKED WALL (16x16 tiled, anchor [8, 8])
# ============================================================================

def _build_cracked_wall(stone_ramp: Tuple[str, str, str, str], glint_pair: Tuple[str, str]) -> List[Image.Image]:
    """Richly shaded coursed masonry with hand-plotted jagged cracks & glowing fissure core."""
    s_dk, s_md, s_lt, s_hi = stone_ramp
    g_dim, g_hot = glint_pair
    frames: List[Image.Image] = []
    for f in range(2):
        cv = Canvas(16, 16)
        # Base mortar fill
        cv.rect(0, 0, 16, 16, "void")
        # 3 staggered ashlar stone courses (rows 0..4, 6..10, 12..15)
        bricks = [
            # (x, y, w, h)
            (1, 1, 7, 4), (9, 1, 6, 4),
            (1, 6, 4, 4), (6, 6, 6, 4), (13, 6, 2, 4),
            (1, 11, 8, 4), (10, 11, 5, 4),
        ]
        for bx, by, bw, bh in bricks:
            cv.rect(bx, by, bw, bh, s_md)
            cv.hline(bx, bx + bw - 1, by, s_lt)       # top bevel
            cv.vline(bx, by, by + bh - 1, s_lt)       # left bevel
            cv.put(bx, by, s_hi)                      # top-left bright corner
            cv.hline(bx, bx + bw - 1, by + bh - 1, s_dk)  # bottom shadow
            cv.vline(bx + bw - 1, by + 1, by + bh - 1, s_dk)
        # Weathering chips & texture specks
        cv.put(4, 2, s_dk)
        cv.put(11, 3, s_dk)
        cv.put(7, 8, s_dk)
        cv.put(3, 13, s_dk)
        cv.put(12, 12, s_hi)

        # Hand-plotted asymmetric jagged masonry fracture meeting at hub (7, 8)
        crack_pts = [
            # Main jagged trunk from top-left mortar down through center to bottom-right
            (4, 1), (4, 2), (5, 3), (5, 4), (6, 5), (6, 6), (7, 7), (7, 8),
            (8, 8), (9, 9), (9, 10), (10, 11), (11, 11), (12, 12), (12, 13), (13, 14),
            # Irregular right-up fork
            (8, 7), (9, 6), (10, 6), (11, 5), (12, 4), (13, 4), (14, 3),
            # Short lower-left splinter
            (6, 9), (5, 10), (4, 10), (3, 11), (2, 12),
        ]
        # Highlighted fractured stone bevel on lit side of the main crack
        for cx, cy in crack_pts:
            if cx >= 2 and cy >= 2:
                cv.put(cx - 1, cy, s_hi)
        for cx, cy in crack_pts:
            cv.put(cx, cy, "void")
        cv.put(7, 8, "void")
        cv.put(8, 8, "void")

        # Subtle glowing gold fissure seam at the hub (pulses gently between frame 0 & 1)
        if f == 0:
            cv.put(7, 8, "gold")
            cv.put(8, 8, g_dim)
            cv.put(7, 7, g_dim)
        else:
            cv.put(7, 8, "cream")
            cv.put(8, 8, g_hot)
            cv.put(7, 7, g_hot)
            cv.put(9, 9, g_dim)
            cv.put(8, 7, g_dim)
        frames.append(cv.img)
    return frames


def build_cracked_rubble() -> List[Image.Image]:
    # Transparent background! Scattered shattered rubble ring around edges
    grid = [
        "................",
        ".vnv........vn..",
        ".vrmv......vdmv.",
        "..vv........vv..",
        "................",
        ".............vn.",
        ".............vmv",
        "..vn..........v.",
        "..vrv...........",
        "...v............",
        "................",
        "............vn..",
        ".vnv.......vrmv.",
        ".vdmv......vddv.",
        "..vvv.......vv..",
        "................",
    ]
    return [from_grid(16, 16, grid)]


# ============================================================================
# 6. TIDE GATE (16x16 tiled, anchor [8, 8])
# ============================================================================

def build_tide_closed() -> List[Image.Image]:
    """2f foaming surging tide over submerged dark iron-and-barnacle sluice grate."""
    frames: List[Image.Image] = []
    for f in range(2):
        cv = Canvas(16, 16)
        # Deep surging tide water base
        cv.rect(0, 0, 16, 16, "deep")
        # Submerged dark iron sluice grate bars visible beneath the water
        for gx in (2, 7, 12):
            cv.rect(gx, 0, 2, 16, "night")
            cv.vline(gx + 1, 0, 15, "pine")
        # Cross iron bar
        cv.rect(0, 7, 16, 2, "night")
        cv.hline(0, 15, 7, "pine")
        # Barnacle specks on grate bars
        for bx, by in [(2, 3), (7, 11), (12, 6), (3, 13)]:
            cv.put(bx, by, "teal")
        # Animated surging wave crests & foam sweeping across
        shift = f * 3
        for wy in (1, 5, 10, 14):
            for x in range(16):
                wave = (x + wy * 2 + shift) % 8
                if wave in (0, 1, 2):
                    cv.put(x, wy, "blue")
                if wave in (1, 2):
                    cv.put(x, wy + (1 if wy < 14 else 0), "sky")
                if wave == 2 and ((x + wy) % 3 != 0):
                    cv.put(x, wy, "ice")
                if wave == 1 and wy in (1, 10) and ((x + f) % 5 == 0):
                    cv.put(x, wy, "cream")
        frames.append(cv.img)
    return frames


def build_tide_open() -> List[Image.Image]:
    """1f weathered harbour timber-and-iron pier planks + corner bollards."""
    cv = Canvas(16, 16)
    cv.rect(0, 0, 16, 16, "void")
    # 4 horizontal weathered harbour timber planks (each 3px tall + 1px dark seam)
    planks = [
        (0, "dusk", "plum", "mauve"),
        (4, "dusk", "wine", "mauve"),
        (8, "night", "dusk", "plum"),
        (12, "dusk", "plum", "mauve"),
    ]
    for py, c_sh, c_md, c_hi in planks:
        cv.rect(1, py, 14, 3, c_md)
        cv.hline(1, 14, py, c_hi)       # top lit plank edge
        cv.hline(1, 14, py + 2, c_sh)   # bottom bevel
        cv.hline(0, 15, py + 3, "void") # plank gap
        # Damp harbour moss / sea-spray grain along ends
        cv.put(1, py + 1, "pine")
        cv.put(14, py + 1, "pine")
    # Staggered plank nail heads & wood grain
    for nx, ny in [(3, 1), (12, 1), (6, 5), (13, 5), (4, 9), (11, 9), (3, 13), (12, 13)]:
        cv.put(nx, ny, "night")
        cv.put(nx - 1, ny, "stone")
    # Vertical iron-strapped edge joists (x=0..1 and x=14..15)
    cv.vline(0, 0, 15, "void")
    cv.vline(15, 0, 15, "void")
    # Corner iron bollards / cleats
    for bx, by in [(1, 1), (13, 1), (1, 13), (13, 13)]:
        cv.rect(bx, by, 2, 2, "night")
        cv.put(bx, by, "stone")
        cv.put(bx + 1, by, "apricot")
    return [cv.img]


# ============================================================================
# 7. PHANTOM PLATFORM (16x16 tiled, anchor [8, 8])
# ============================================================================

def build_phantom_solid() -> List[Image.Image]:
    """2f starlight-filigree glass flagstone with deep/blue/sky/ice bevel & center star rune."""
    frames: List[Image.Image] = []
    for f in range(2):
        cv = Canvas(16, 16)
        # Outer dark glass border & inner deep sapphire glass pane
        cv.rect(0, 0, 16, 16, "night")
        cv.rect(1, 1, 14, 14, "deep")
        # Beveled glass top-left highlight & bottom-right shadow
        cv.hline(1, 14, 1, "sky")
        cv.vline(1, 1, 14, "sky")
        cv.hline(1, 14, 14, "night")
        cv.vline(14, 1, 14, "night")
        # Inner filigree diamond frame
        cv.rect(2, 2, 12, 12, "blue")
        cv.rect(3, 3, 10, 10, "deep")
        # Crisp corner filigree brackets
        for cx, cy in [(2, 2), (13, 2), (2, 13), (13, 13)]:
            cv.put(cx, cy, "ice")
        for cx, cy in [(3, 2), (2, 3), (12, 2), (13, 3), (3, 13), (2, 12), (12, 13), (13, 12)]:
            cv.put(cx, cy, "sky")
        # Center 4-point starlight rune (twinkles between frame 0 & 1)
        c_arm = "sky" if f == 0 else "ice"
        c_tip = "ice" if f == 0 else "sky"
        c_ctr = "cream" if f == 0 else "ice"
        cv.hline(5, 10, 7, c_arm)
        cv.hline(5, 10, 8, c_arm)
        cv.vline(7, 5, 10, c_arm)
        cv.vline(8, 5, 10, c_arm)
        cv.put(4, 7, c_tip)
        cv.put(11, 8, c_tip)
        cv.put(7, 4, c_tip)
        cv.put(8, 11, c_tip)
        cv.rect(7, 7, 2, 2, c_ctr)
        # Subtle glass sheen diagonal pips
        cv.put(4, 4, "ice" if f == 0 else "sky")
        cv.put(11, 11, "sky" if f == 0 else "ice")
        frames.append(cv.img)
    return frames


def build_phantom_warn() -> List[Image.Image]:
    """2f flickering coral/apricot/ice dither-dissolve warning right before True Lens expires."""
    frames: List[Image.Image] = []
    for f in range(2):
        cv = Canvas(16, 16)
        # Checkerboard dither-dissolve edges (transparent gaps show imminent vanish!)
        for y in range(16):
            for x in range(16):
                on_edge = x in (0, 15) or y in (0, 15)
                in_rim = x in (1, 14) or y in (1, 14)
                if on_edge:
                    if (x + y + f) % 2 == 0:
                        cv.put(x, y, "coral" if f == 0 else "apricot")
                elif in_rim:
                    if (x + y + f) % 3 != 0:
                        cv.put(x, y, "apricot" if f == 0 else "ice")
                else:
                    # Dissolving interior checkerboard
                    if (x + y + f) % 2 == 0:
                        cv.put(x, y, "wine" if (x + y) % 4 == 0 else "deep")
                    elif 5 <= x <= 10 and 5 <= y <= 10:
                        cv.put(x, y, "blue")
        # Destabilizing center star rune
        c_star = "ice" if f == 0 else "coral"
        c_core = "cream" if f == 0 else "apricot"
        cv.hline(5, 10, 7, c_star)
        cv.vline(7, 5, 10, c_star)
        cv.put(7, 7, c_core)
        cv.put(8, 8, c_core)
        # Bright alert corner brackets
        for cx, cy in [(1, 1), (14, 1), (1, 14), (14, 14)]:
            cv.put(cx, cy, "cream" if f == 0 else "coral")
        frames.append(cv.img)
    return frames


def build_phantom_hint() -> List[Image.Image]:
    """1f very subtle 4-corner deep star-dust glints on transparent background."""
    cv = Canvas(16, 16)
    # 4 tiny 2px corner L-glints in deep & blue — NO opaque box!
    for x, y, dx, dy in [(1, 1, 1, 1), (14, 1, -1, 1), (1, 14, 1, -1), (14, 14, -1, -1)]:
        cv.put(x, y, "blue")
        cv.put(x + dx, y, "deep")
        cv.put(x, y + dy, "deep")
    # Two faint inner star-dust flecks
    cv.put(5, 6, "deep")
    cv.put(10, 9, "deep")
    return [cv.img]


# ============================================================================
# 8. OBSIDIAN SEAL (16x16 tiled, anchor [8, 8])
# ============================================================================

def build_obsidian_tile() -> List[Image.Image]:
    """4f pulsing void/night/dusk chiselled obsidian monolith with solar-sigil veins."""
    frames: List[Image.Image] = []
    # 4-step solar pulse ramp
    vein_outer = ["wine", "wine", "coral", "wine"]
    vein_mid = ["coral", "apricot", "gold", "apricot"]
    vein_core = ["apricot", "gold", "cream", "gold"]
    for f in range(4):
        cv = Canvas(16, 16)
        cv.rect(0, 0, 16, 16, "void")
        # Chiselled obsidian monolith bevels
        cv.rect(1, 1, 14, 14, "night")
        cv.rect(2, 2, 11, 11, "dusk")
        cv.rect(4, 4, 8, 8, "night")
        # Sharp volcanic glass facets on top-left
        cv.hline(2, 12, 2, "mauve")
        cv.vline(2, 2, 11, "mauve")
        cv.put(2, 2, "stone")
        cv.put(3, 3, "dusk")
        # Diagonal chisel grooves
        cv.line(1, 14, 3, 12, "void")
        cv.line(14, 1, 12, 3, "void")
        cv.line(14, 14, 12, 12, "void")

        vo, vm, vc = vein_outer[f], vein_mid[f], vein_core[f]
        # Radiating solar-sigil veins from center (7..8, 7..8)
        for p in [(3, 3), (4, 4), (12, 3), (11, 4), (3, 12), (4, 11), (12, 12), (11, 11)]:
            cv.put(p[0], p[1], vo)
        for p in [(5, 5), (10, 5), (5, 10), (10, 10)]:
            cv.put(p[0], p[1], vm)
        # Cardinal solar rays
        cv.vline(7, 3, 12, vo)
        cv.vline(8, 3, 12, vo)
        cv.hline(3, 12, 7, vo)
        cv.hline(3, 12, 8, vo)
        cv.vline(7, 4, 11, vm)
        cv.hline(4, 11, 7, vm)
        # Carved solar ring & blazing core
        cv.rect(6, 6, 4, 4, vm)
        cv.rect(7, 7, 2, 2, vc)
        if f == 2:
            # Peak pulse flare on cardinal tips
            for sx, sy in [(7, 2), (8, 13), (2, 7), (13, 8)]:
                cv.put(sx, sy, "gold")
        frames.append(cv.img)
    return frames


def build_obsidian_shattered() -> List[Image.Image]:
    # Transparent background! Cracked obsidian shards & tiny dying ember fleck
    grid = [
        "................",
        "..vv........vn..",
        ".vdmv......vnmv.",
        ".vnnv.......vv..",
        "..vv............",
        "................",
        "............vv..",
        ".vn.........vdv.",
        ".vmv....w....v..",
        "..v.............",
        "................",
        ".............vn.",
        "..vn........vdmv",
        ".vnmv.......vnnv",
        "..vvv........vv.",
        "................",
    ]
    return [from_grid(16, 16, grid)]


# ============================================================================
# 9. BRAZIER (16x20, anchor [8, 14])
# ============================================================================

def _draw_brazier_body(cv: Canvas, lit: bool) -> None:
    """Sculpted dark iron bowl on fluted stone pedestal (base y=18..19 -> local +4..+5)."""
    # Stepped fluted stone pedestal (y=12..19)
    cv.rect(3, 17, 10, 2, "night")
    cv.rect(3, 17, 8, 1, "dusk")
    cv.hline(3, 7, 17, "mauve")
    cv.hline(3, 5, 17, "stone")

    cv.rect(5, 13, 6, 4, "night")
    cv.rect(5, 13, 4, 4, "dusk")
    cv.vline(5, 13, 16, "mauve")
    cv.put(5, 13, "stone")
    cv.vline(7, 14, 16, "mauve")  # flute ridge
    cv.vline(8, 14, 16, "night")  # flute shadow

    # Sculpted dark iron fire-bowl (y=8..13)
    cv.rect(4, 12, 8, 2, "night")
    cv.rect(4, 12, 5, 1, "plum")
    cv.rect(3, 10, 10, 2, "plum")
    cv.rect(9, 10, 4, 2, "night")
    cv.rect(2, 8, 12, 2, "plum")
    cv.rect(10, 8, 4, 2, "night")

    # Rim highlight (warm-lit when burning, muted wine/mauve when cold)
    if lit:
        cv.hline(2, 13, 8, "coral")
        cv.hline(3, 10, 8, "apricot")
        cv.hline(3, 6, 9, "wine")
    else:
        cv.hline(2, 11, 8, "wine")
        cv.hline(3, 7, 8, "mauve")
    # Decorative brass rivets on bowl band
    cv.put(3, 10, "gold" if lit else "apricot")
    cv.put(7, 10, "gold" if lit else "apricot")
    cv.put(11, 10, "apricot" if lit else "wine")

    # Recessed dark bowl interior
    cv.hline(4, 11, 8, "void")


def build_brazier_unlit() -> List[Image.Image]:
    cv = Canvas(16, 20)
    _draw_brazier_body(cv, lit=False)
    # Dark charred coals mounded in bowl (y=6..8)
    cv.rect(4, 7, 8, 2, "night")
    cv.rect(5, 6, 6, 2, "dusk")
    cv.put(6, 6, "plum")
    cv.put(9, 7, "wine")
    cv.put(5, 7, "wine")
    cv.outline("void")
    return [cv.img]


def build_brazier_lit() -> List[Image.Image]:
    """4f animated pixel flame in wine/coral/apricot/gold/cream — ZERO alpha halo!"""
    # 4 crisp hand-drawn flame shapes above y=8 (rows y=0..8)
    flame_frames = [
        [
            ".......c........",
            "......ca........",
            ".....cagc.......",
            "....caegac......",
            "...ccaeegac.....",
            "...caeeegac.....",
            "..wcaeeegacw....",
            "..wccaggaccw....",
            "...wwccccww.....",
        ],
        [
            "........c.......",
            ".......ag.......",
            "......cag.......",
            "....ccagac......",
            "...caeeegc......",
            "...caeeegac.....",
            "..wcaeeegacw....",
            "..wccaggaccw....",
            "...wwccccww.....",
        ],
        [
            "......c.........",
            "......ac........",
            ".....cagc.......",
            "....cagacc......",
            "...caeegac......",
            "...caeeegac.....",
            "..wcaeeegacw....",
            "..wccaggaccw....",
            "...wwccccww.....",
        ],
        [
            ".......g........",
            "......cag.......",
            ".....caegc......",
            "....caeeagc.....",
            "...caeeegac.....",
            "...caeeegac.....",
            "..wcaeeegacw....",
            "..wccaggaccw....",
            "...wwccccww.....",
        ],
    ]
    spark_coords = [
        [(3, 2, "gold"), (12, 3, "apricot")],
        [(4, 1, "cream"), (11, 2, "gold")],
        [(3, 3, "apricot"), (12, 1, "cream")],
        [(5, 0, "gold"), (11, 3, "apricot")],
    ]
    frames: List[Image.Image] = []
    for f in range(4):
        cv = Canvas(16, 20)
        _draw_brazier_body(cv, lit=True)
        cv.outline("void")
        # Stamp crisp pixel flame on top (no void outline around flame tip so fire stays luminous!)
        cv.stamp_grid(flame_frames[f], ox=0, oy=0)
        for sx, sy, col in spark_coords[f]:
            cv.put(sx, sy, col)
        frames.append(cv.img)
    return frames


# ============================================================================
# 10. WEB (16x16 tiled, anchor [8, 8])
# ============================================================================

def build_web_tile() -> List[Image.Image]:
    """1f corner-anchored spiderweb with delicate silky strands, dewdrops & dark anchor knots."""
    grid = [
        "vn.....n......nv",
        "ndm....m.....mdn",
        "..mr...r....rm..",
        "...mf.rfr..rm...",
        "....rm.r..mr....",
        "..r..rmrmrm..r..",
        ".r.m..rfrm..m.r.",
        "nmrmrr.e.rrmrmrn",
        ".r.m..mffm..m.r.",
        "..r..rmrmrm..r..",
        "....mr..r.mr....",
        "...rm..rfr.fm...",
        "..mr....r...rm..",
        "ndm.....m....mdn",
        "vn......n.....nv",
        "v..............v",
    ]
    return [from_grid(16, 16, grid)]


def build_web_torn() -> List[Image.Image]:
    """1f torn wispy silk stubs anchored at the corners on transparent background."""
    grid = [
        "vn............nv",
        "ndm..........mdn",
        ".mr..........rm.",
        "..m..........r..",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "..r..........m..",
        ".mr..........rm.",
        "ndm..........mdn",
        "vn............nv",
    ]
    return [from_grid(16, 16, grid)]


# ============================================================================
# ATLAS PACKING & VALIDATION
# ============================================================================

def collect_props() -> List[Tuple[str, Tuple[int, int], List[float], bool, List[Image.Image]]]:
    """Return ordered list of (prop_key, anchor, ms_list, loop, frames)."""
    return [
        # Blue Portal (24x24, anchor [12, 12])
        ("portal_dormant", (12, 12), [200.0], True, build_portal_dormant()),
        ("portal_active", (12, 12), [110.0, 110.0, 110.0, 110.0], True, build_portal_active()),
        ("portal_reject", (12, 12), [200.0], True, build_portal_reject()),
        # Mirror / Blue Transformer (20x24, anchor [10, 14])
        ("mirror_base_fixed", (10, 14), [200.0], True, [_build_mirror_base(False)]),
        ("mirror_base_push", (10, 14), [200.0], True, [_build_mirror_base(True)]),
        ("mirror_blue_0", (10, 14), [200.0], True, [_build_mirror_crystal(0, "blue")]),
        ("mirror_blue_45", (10, 14), [200.0], True, [_build_mirror_crystal(45, "blue")]),
        ("mirror_blue_90", (10, 14), [200.0], True, [_build_mirror_crystal(90, "blue")]),
        ("mirror_blue_135", (10, 14), [200.0], True, [_build_mirror_crystal(135, "blue")]),
        ("mirror_blue_flash", (10, 14), [120.0], True, [_build_mirror_flash("blue")]),
        ("mirror_brass_0", (10, 14), [200.0], True, [_build_mirror_crystal(0, "brass")]),
        ("mirror_brass_45", (10, 14), [200.0], True, [_build_mirror_crystal(45, "brass")]),
        ("mirror_brass_90", (10, 14), [200.0], True, [_build_mirror_crystal(90, "brass")]),
        ("mirror_brass_135", (10, 14), [200.0], True, [_build_mirror_crystal(135, "brass")]),
        ("mirror_brass_flash", (10, 14), [120.0], True, [_build_mirror_flash("brass")]),
        # Switch Eye (20x22, anchor [10, 14])
        ("eye_gold_dormant", (10, 14), [200.0], True, [_build_switch_eye(False, False, 0)]),
        ("eye_gold_lit", (10, 14), [260.0, 260.0], True, [_build_switch_eye(False, True, 0), _build_switch_eye(False, True, 1)]),
        ("eye_blue_dormant", (10, 14), [200.0], True, [_build_switch_eye(True, False, 0)]),
        ("eye_blue_lit", (10, 14), [260.0, 260.0], True, [_build_switch_eye(True, True, 0), _build_switch_eye(True, True, 1)]),
        # Bramble (16x16, anchor [8, 8])
        ("bramble_tile", (8, 8), [450.0, 450.0], True, build_bramble_tile()),
        ("bramble_charred", (8, 8), [200.0], True, build_bramble_charred()),
        # Cracked Wall (16x16, anchor [8, 8])
        ("cracked_slate", (8, 8), [550.0, 550.0], True, _build_cracked_wall(("night", "dusk", "mauve", "stone"), ("apricot", "gold"))),
        ("cracked_coastal", (8, 8), [550.0, 550.0], True, _build_cracked_wall(("night", "deep", "blue", "sky"), ("sky", "ice"))),
        ("cracked_basalt", (8, 8), [550.0, 550.0], True, _build_cracked_wall(("night", "dusk", "plum", "wine"), ("coral", "gold"))),
        ("cracked_rubble", (8, 8), [200.0], True, build_cracked_rubble()),
        # Tide Gate (16x16, anchor [8, 8])
        ("tide_closed", (8, 8), [280.0, 280.0], True, build_tide_closed()),
        ("tide_open", (8, 8), [200.0], True, build_tide_open()),
        # Phantom Platform (16x16, anchor [8, 8])
        ("phantom_solid", (8, 8), [360.0, 360.0], True, build_phantom_solid()),
        ("phantom_warn", (8, 8), [140.0, 140.0], True, build_phantom_warn()),
        ("phantom_hint", (8, 8), [200.0], True, build_phantom_hint()),
        # Obsidian Seal (16x16, anchor [8, 8])
        ("obsidian_tile", (8, 8), [220.0, 220.0, 220.0, 220.0], True, build_obsidian_tile()),
        ("obsidian_shattered", (8, 8), [200.0], True, build_obsidian_shattered()),
        # Brazier (16x20, anchor [8, 14])
        ("brazier_unlit", (8, 14), [200.0], True, build_brazier_unlit()),
        ("brazier_lit", (8, 14), [110.0, 110.0, 110.0, 110.0], True, build_brazier_lit()),
        # Web (16x16, anchor [8, 8])
        ("web_tile", (8, 8), [200.0], True, build_web_tile()),
        ("web_torn", (8, 8), [200.0], True, build_web_torn()),
    ]


def validate_palette(img: Image.Image) -> None:
    """Assert every single pixel in the atlas is strictly one of the 20 Last Light colours or transparent."""
    px = img.load()
    w, h = img.size
    bad: Dict[Tuple[int, int, int, int], int] = {}
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c not in VALID_RGBA:
                bad[c] = bad.get(c, 0) + 1
    if bad:
        raise ValueError(f"Palette violation! Found {len(bad)} non-Last-Light RGBA values: {list(bad.items())[:8]}")


def build_atlas(out_dir: Path, preview_path: Path | None = None) -> None:
    entries = collect_props()
    # Pack cleanly into rows with max width 192px (2px padding between frames/rows for zero bleed)
    pad = 2
    max_w = 192
    x = pad
    y = pad
    row_h = 0
    placements: List[Tuple[str, Tuple[int, int], List[float], bool, List[Image.Image], List[List[int]]]] = []

    for key, anchor, ms_list, loop, frames in entries:
        fw, fh = frames[0].size
        strip_w = len(frames) * fw + (len(frames) - 1) * pad
        if x + strip_w + pad > max_w and x > pad:
            x = pad
            y += row_h + pad
            row_h = 0
        rects: List[List[int]] = []
        for idx, _fr in enumerate(frames):
            rx = x + idx * (fw + pad)
            rects.append([rx, y, fw, fh])
        placements.append((key, anchor, ms_list, loop, frames, rects))
        x += strip_w + pad
        row_h = max(row_h, fh)

    sheet_w = max_w
    sheet_h = y + row_h + pad
    atlas = Image.new("RGBA", (sheet_w, sheet_h), TRANS)

    props_meta: Dict[str, dict] = {}
    for key, anchor, ms_list, loop, frames, rects in placements:
        fw, fh = frames[0].size
        for fr, rc in zip(frames, rects):
            atlas.paste(fr, (rc[0], rc[1]))
        props_meta[key] = {
            "frame": [fw, fh],
            "anchor": [anchor[0], anchor[1]],
            "frames": len(frames),
            "ms": ms_list,
            "loop": loop,
            "rects": rects,
        }

    validate_palette(atlas)

    out_dir.mkdir(parents=True, exist_ok=True)
    png_path = out_dir / "puzzle_interactables.png"
    json_path = out_dir / "puzzle_interactables.json"
    atlas.save(png_path, "PNG")

    meta = {
        "id": "puzzle_interactables",
        "name": "Luxel Shared Puzzle Interactables",
        "version": 1,
        "palette": PAL_HEX,
        "sheet": "puzzle_interactables.png",
        "sheet_size": [sheet_w, sheet_h],
        "props": props_meta,
    }
    json_path.write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    print(f"Wrote {png_path} ({sheet_w}x{sheet_h}, {len(props_meta)} props) and {json_path} — STRICT 20-colour palette OK.")

    if preview_path is not None:
        # 4x nearest-neighbor preview over a subtle mid-dark checkerboard so transparent sprites are easy to inspect
        scale = 4
        pw, ph = sheet_w * scale, sheet_h * scale
        bg = Image.new("RGBA", (pw, ph), RGBA["night"])
        bpx = bg.load()
        for py in range(ph):
            for px_i in range(pw):
                if ((px_i // 8) + (py // 8)) % 2 == 0:
                    bpx[px_i, py] = RGBA["dusk"]
        up = atlas.resize((pw, ph), Image.NEAREST)
        bg.alpha_composite(up)
        preview_path.parent.mkdir(parents=True, exist_ok=True)
        bg.save(preview_path, "PNG")
        print(f"Wrote 4x inspection preview: {preview_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build puzzle_interactables.png + .json")
    parser.add_argument("--preview", type=Path, default=None, help="Optional path to save a 4x preview PNG")
    args = parser.parse_args()
    repo_root = Path(__file__).resolve().parents[3]
    out_dir = repo_root / "luxel" / "art" / "props"
    build_atlas(out_dir, preview_path=args.preview)


if __name__ == "__main__":
    main()
