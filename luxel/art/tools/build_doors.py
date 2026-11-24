#!/usr/bin/env python3
"""Bespoke 8-Island Door Sprite Architecture generator for Luxel 1.0.

Generates 8 handcrafted pixel-art door atlases:
  luxel/art/props/island1_doors.png + island1_doors.json
  ...
  luxel/art/props/island8_doors.png + island8_doors.json

Strictly enforces the 20-colour Last Light palette (0 off-palette opaque pixels,
0 semi-transparent pixels: alpha is strictly 0 or 255).

Run:
  uv run --no-project --with pillow python luxel/art/tools/build_doors.py
"""
from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[3]
OUT_DIR = REPO_ROOT / "luxel" / "art" / "props"

PAL: dict[str, str] = {
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

RGB: dict[str, tuple[int, int, int]] = {
    k: (int(v[1:3], 16), int(v[3:5], 16), int(v[5:7], 16))
    for k, v in PAL.items()
}
RGBA: dict[str, tuple[int, int, int, int]] = {k: v + (255,) for k, v in RGB.items()}
ALLOWED_RGB: set[tuple[int, int, int]] = set(RGB.values())
TRANSPARENT = (0, 0, 0, 0)


class Canvas:
    """Strict pixel-art surface that only writes exact Last Light RGBA pixels."""

    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.img = Image.new("RGBA", (w, h), TRANSPARENT)
        self.pix = self.img.load()

    def px(self, x: int, y: int, col: str | None) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.pix[x, y] = TRANSPARENT if col is None else RGBA[col]

    def get(self, x: int, y: int) -> tuple[int, int, int, int]:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.pix[x, y]
        return TRANSPARENT

    def is_opaque(self, x: int, y: int) -> bool:
        return self.get(x, y)[3] == 255

    def hline(self, x0: int, x1: int, y: int, col: str | None) -> None:
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.px(x, y, col)

    def vline(self, x: int, y0: int, y1: int, col: str | None) -> None:
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.px(x, y, col)

    def rect(self, x: int, y: int, w: int, h: int, col: str | None) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, col)

    def box(self, x: int, y: int, w: int, h: int, col: str) -> None:
        if w <= 0 or h <= 0:
            return
        self.hline(x, x + w - 1, y, col)
        self.hline(x, x + w - 1, y + h - 1, col)
        self.vline(x, y, y + h - 1, col)
        self.vline(x + w - 1, y, y + h - 1, col)

    def bevel_rect(
        self,
        x: int,
        y: int,
        w: int,
        h: int,
        fill: str,
        hi: str,
        lo: str,
        outline: str | None = None,
    ) -> None:
        if outline is not None:
            self.rect(x, y, w, h, outline)
            x += 1
            y += 1
            w -= 2
            h -= 2
        if w <= 0 or h <= 0:
            return
        self.rect(x, y, w, h, fill)
        self.hline(x, x + w - 1, y, hi)
        self.vline(x, y, y + h - 1, hi)
        self.hline(x, x + w - 1, y + h - 1, lo)
        self.vline(x + w - 1, y + 1, y + h - 1, lo)

    def dither_rect(
        self,
        x: int,
        y: int,
        w: int,
        h: int,
        c0: str | None,
        c1: str | None,
        phase: int = 0,
    ) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, c0 if ((xx + yy + phase) & 1) == 0 else c1)

    def line(self, x0: int, y0: int, x1: int, y1: int, col: str) -> None:
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        x, y = x0, y0
        while True:
            self.px(x, y, col)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def circle_fill(self, cx: int, cy: int, r: float, col: str) -> None:
        r2 = r * r
        ri = int(math.ceil(r))
        for dy in range(-ri, ri + 1):
            for dx in range(-ri, ri + 1):
                if dx * dx + dy * dy <= r2:
                    self.px(cx + dx, cy + dy, col)

    def outline_transparent(self, col: str = "void") -> None:
        """Add a 1px outline around opaque pixels into adjacent transparent pixels."""
        to_paint: list[tuple[int, int]] = []
        for y in range(self.h):
            for x in range(self.w):
                if self.is_opaque(x, y):
                    continue
                if (
                    self.is_opaque(x - 1, y)
                    or self.is_opaque(x + 1, y)
                    or self.is_opaque(x, y - 1)
                    or self.is_opaque(x, y + 1)
                ):
                    to_paint.append((x, y))
        for x, y in to_paint:
            self.px(x, y, col)


@dataclass(frozen=True)
class IslandTheme:
    island_id: int
    name: str
    # Frame / masonry / hull architecture ramp (dark -> hi)
    out: str
    frame_dk: str
    frame_mid: str
    frame_hi: str
    frame_rim: str
    # Door panel surface ramp (dark -> hi)
    panel_dk: str
    panel_mid: str
    panel_hi: str
    # Accent / lock / metal / trim ramp
    trim_dk: str
    trim_mid: str
    trim_hi: str
    trim_core: str
    # Conduit / switch / combat energy ramp
    sig_dk: str
    sig_mid: str
    sig_hi: str
    sig_core: str
    # Ward / light bridge energy ramp
    ward_dk: str
    ward_mid: str
    ward_hi: str
    ward_core: str
    # Secondary organic/ornament accent (moss, glass, ember, rose, etc.)
    deco_dk: str
    deco_mid: str
    deco_hi: str
    # Bridge plank/stone ramp
    br_dk: str
    br_mid: str
    br_hi: str
    br_rim: str


THEMES: dict[int, IslandTheme] = {
    1: IslandTheme(
        island_id=1,
        name="Bell Isle",
        out="void", frame_dk="night", frame_mid="dusk", frame_hi="mauve", frame_rim="stone",
        panel_dk="dusk", panel_mid="plum", panel_hi="mauve",
        trim_dk="wine", trim_mid="coral", trim_hi="apricot", trim_core="gold",
        sig_dk="wine", sig_mid="coral", sig_hi="gold", sig_core="cream",
        ward_dk="deep", ward_mid="blue", ward_hi="sky", ward_core="ice",
        deco_dk="pine", deco_mid="jade", deco_hi="lime",
        br_dk="dusk", br_mid="mauve", br_hi="stone", br_rim="gold",
    ),
    2: IslandTheme(
        island_id=2,
        name="Tide Harbor",
        out="void", frame_dk="night", frame_mid="pine", frame_hi="teal", frame_rim="mauve",
        panel_dk="night", panel_mid="pine", panel_hi="teal",
        trim_dk="coral", trim_mid="apricot", trim_hi="gold", trim_core="cream",
        sig_dk="deep", sig_mid="blue", sig_hi="sky", sig_core="ice",
        ward_dk="pine", ward_mid="teal", ward_hi="sky", ward_core="ice",
        deco_dk="deep", deco_mid="sky", deco_hi="ice",
        br_dk="night", br_mid="pine", br_hi="teal", br_rim="apricot",
    ),
    3: IslandTheme(
        island_id=3,
        name="Thornwood",
        out="void", frame_dk="night", frame_mid="plum", frame_hi="wine", frame_rim="coral",
        panel_dk="night", panel_mid="plum", panel_hi="wine",
        trim_dk="coral", trim_mid="apricot", trim_hi="gold", trim_core="cream",
        sig_dk="pine", sig_mid="teal", sig_hi="jade", sig_core="lime",
        ward_dk="pine", ward_mid="jade", ward_hi="lime", ward_core="cream",
        deco_dk="pine", deco_mid="jade", deco_hi="lime",
        br_dk="night", br_mid="plum", br_hi="wine", br_rim="jade",
    ),
    4: IslandTheme(
        island_id=4,
        name="Mist Marsh",
        out="void", frame_dk="night", frame_mid="pine", frame_hi="teal", frame_rim="sky",
        panel_dk="pine", panel_mid="teal", panel_hi="sky",
        trim_dk="wine", trim_mid="mauve", trim_hi="rose", trim_core="cream",
        sig_dk="teal", sig_mid="sky", sig_hi="ice", sig_core="rose",
        ward_dk="teal", ward_mid="sky", ward_hi="ice", ward_core="rose",
        deco_dk="mauve", deco_mid="rose", deco_hi="cream",
        br_dk="pine", br_mid="teal", br_hi="sky", br_rim="ice",
    ),
    5: IslandTheme(
        island_id=5,
        name="Starfall Peak",
        out="void", frame_dk="night", frame_mid="deep", frame_hi="blue", frame_rim="sky",
        panel_dk="night", panel_mid="deep", panel_hi="blue",
        trim_dk="coral", trim_mid="apricot", trim_hi="gold", trim_core="cream",
        sig_dk="deep", sig_mid="blue", sig_hi="gold", sig_core="cream",
        ward_dk="deep", ward_mid="blue", ward_hi="gold", ward_core="cream",
        deco_dk="blue", deco_mid="sky", deco_hi="ice",
        br_dk="night", br_mid="deep", br_hi="blue", br_rim="gold",
    ),
    6: IslandTheme(
        island_id=6,
        name="Ash Caldera",
        out="void", frame_dk="void", frame_mid="night", frame_hi="dusk", frame_rim="mauve",
        panel_dk="void", panel_mid="night", panel_hi="dusk",
        trim_dk="wine", trim_mid="coral", trim_hi="apricot", trim_core="gold",
        sig_dk="wine", sig_mid="coral", sig_hi="apricot", sig_core="gold",
        ward_dk="wine", ward_mid="coral", ward_hi="apricot", ward_core="cream",
        deco_dk="dusk", deco_mid="mauve", deco_hi="stone",
        br_dk="void", br_mid="night", br_hi="dusk", br_rim="coral",
    ),
    7: IslandTheme(
        island_id=7,
        name="Mirror Shoals",
        out="void", frame_dk="night", frame_mid="deep", frame_hi="sky", frame_rim="ice",
        panel_dk="deep", panel_mid="blue", panel_hi="sky",
        trim_dk="dusk", trim_mid="mauve", trim_hi="stone", trim_core="cream",
        sig_dk="deep", sig_mid="sky", sig_hi="ice", sig_core="cream",
        ward_dk="deep", ward_mid="sky", ward_hi="ice", ward_core="cream",
        deco_dk="sky", deco_mid="ice", deco_hi="cream",
        br_dk="deep", br_mid="sky", br_hi="ice", br_rim="cream",
    ),
    8: IslandTheme(
        island_id=8,
        name="The Bell Sanctum",
        out="void", frame_dk="night", frame_mid="dusk", frame_hi="plum", frame_rim="mauve",
        panel_dk="void", panel_mid="night", panel_hi="dusk",
        trim_dk="wine", trim_mid="rose", trim_hi="gold", trim_core="cream",
        sig_dk="plum", sig_mid="wine", sig_hi="rose", sig_core="gold",
        ward_dk="plum", ward_mid="wine", ward_hi="rose", ward_core="gold",
        deco_dk="wine", deco_mid="rose", deco_hi="gold",
        br_dk="night", br_mid="dusk", br_hi="plum", br_rim="rose",
    ),
}


# ---------------------------------------------------------------------------
# Shared micro-texture & emblem helpers
# ---------------------------------------------------------------------------

def _paint_panel_surface(
    c: Canvas, t: IslandTheme, x: int, y: int, w: int, h: int, vertical: bool = False
) -> None:
    """Paint biome-distinct door slab material inside [x, x+w) x [y, y+h)."""
    iid = t.island_id
    c.rect(x, y, w, h, t.panel_mid)
    if iid == 1:
        # Cathedral limestone blocks + carved recessed panel
        for yy in range(y, y + h):
            row = yy - y
            for xx in range(x, x + w):
                col = xx - x
                if row % 4 == 0:
                    c.px(xx, yy, t.panel_dk)
                elif (col + (2 if (row // 4) % 2 else 0)) % 6 == 0:
                    c.px(xx, yy, t.panel_dk)
                elif row % 4 == 1:
                    c.px(xx, yy, t.panel_hi)
    elif iid == 2:
        # Horizontal maritime driftwood / teak hull planks with brass rivets
        for yy in range(y, y + h):
            row = yy - y
            if row % 3 == 0:
                c.hline(x, x + w - 1, yy, t.panel_dk)
            elif row % 3 == 1:
                c.hline(x, x + w - 1, yy, t.panel_hi)
            else:
                c.hline(x, x + w - 1, yy, t.panel_mid)
        # Rivet heads near edges
        for yy in range(y + 1, y + h - 1, 3):
            c.px(x + 1, yy, t.trim_mid)
            c.px(x + w - 2, yy, t.trim_dk)
    elif iid == 3:
        # Vertical heartwood timber planks strapped with mossy creeping vines
        for xx in range(x, x + w):
            col = xx - x
            if col % 3 == 0:
                c.vline(xx, y, y + h - 1, t.panel_dk)
            elif col % 3 == 1:
                c.vline(xx, y, y + h - 1, t.panel_hi)
        # Diagonal creeping vine strap
        for i in range(max(w, h)):
            vx = x + (i % max(1, w))
            vy = y + ((i * 2) // 3)
            if y <= vy < y + h and x <= vx < x + w:
                if (i % 5) in (0, 1):
                    c.px(vx, vy, t.deco_mid)
                    if vy + 1 < y + h:
                        c.px(vx, vy + 1, t.deco_dk)
                elif i % 7 == 2:
                    c.px(vx, vy, t.deco_hi)
    elif iid == 4:
        # Frosted conservatory leaded diamond glass panes
        c.rect(x, y, w, h, "teal")
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                d1 = (xx + yy) % 6
                d2 = (xx - yy) % 6
                if d1 == 0 or d2 == 0:
                    c.px(xx, yy, "pine")
                elif d1 == 1:
                    c.px(xx, yy, "sky")
                elif d1 == 2 and (xx + yy) % 12 < 5:
                    c.px(xx, yy, "ice")
    elif iid == 5:
        # Cobalt observatory stone with engraved brass astrolabe arcs
        c.rect(x, y, w, h, "deep")
        cx, cy = x + w // 2, y + h // 2
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                dist = math.hypot(xx - cx, yy - cy)
                if abs(dist - 5.5) < 0.65 or abs(dist - 9.5) < 0.55:
                    c.px(xx, yy, "apricot" if yy <= cy else "coral")
                elif (xx * 7 + yy * 13) % 19 == 0:
                    c.px(xx, yy, "sky")
                elif yy == y or xx == x:
                    c.px(xx, yy, "blue")
    elif iid == 6:
        # Riveted cast-iron furnace plates with molten ember seam bands
        c.rect(x, y, w, h, "night")
        for yy in range(y, y + h):
            if (yy - y) in (2, h - 3):
                for xx in range(x, x + w):
                    c.px(xx, yy, "coral" if (xx % 3) != 0 else "apricot")
            elif (yy - y) in (1, h - 2):
                c.hline(x, x + w - 1, yy, "wine")
            elif (yy - y) % 4 == 0:
                c.hline(x, x + w - 1, yy, "dusk")
        # Iron plate rivets
        for xx in range(x + 1, x + w - 1, 4):
            c.px(xx, y, "mauve")
            c.px(xx, y + h - 1, "dusk")
    elif iid == 7:
        # Beveled silver-glass crystal slabs with crisp diagonal specular reflections
        c.rect(x, y, w, h, "blue")
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                diag = (xx - x) + (yy - y)
                if diag % 7 in (0, 1):
                    c.px(xx, yy, "ice")
                elif diag % 7 == 2:
                    c.px(xx, yy, "sky")
                elif diag % 7 == 6:
                    c.px(xx, yy, "deep")
                if diag % 14 == 0:
                    c.px(xx, yy, "cream")
        # Subtle lunar filigree border
        if w >= 6 and h >= 6:
            c.box(x, y, w, h, "mauve")
            c.hline(x + 1, x + w - 2, y, "stone")
    elif iid == 8:
        # Pointed Gothic cathedral oak & plum stone with stained-glass rose diamond
        c.rect(x, y, w, h, "night")
        for xx in range(x, x + w):
            if (xx - x) % 3 == 0:
                c.vline(xx, y, y + h - 1, "void")
            elif (xx - x) % 3 == 1:
                c.vline(xx, y, y + h - 1, "dusk")
        # Subtle stained-glass lancet diamond accents
        cy = y + h // 2
        for xx in range(x + 2, x + w - 2, 5):
            c.px(xx, cy, "rose")
            c.px(xx, cy - 1, "wine")
            c.px(xx, cy + 1, "plum")


def _paint_arch_crown_h(c: Canvas, t: IslandTheme, w: int, crown_h: int) -> None:
    """Paint the sculpted top archway crown for horizontal doors (y = 0..crown_h)."""
    iid = t.island_id
    cx = w // 2
    if iid == 1:
        # Rounded Romanesque cathedral limestone arch + mossy left shoulder
        for x in range(1, w - 1):
            dist = abs(x - (cx - 0.5)) / (w * 0.5)
            top = int(round(dist * dist * (crown_h - 1)))
            c.px(x, top, t.out)
            for yy in range(top + 1, crown_h + 1):
                # Voussoir stone wedges
                is_mortar = (x % 4 == 0)
                if yy == top + 1:
                    c.px(x, yy, t.frame_rim if x < cx + 4 else t.frame_hi)
                elif is_mortar:
                    c.px(x, yy, t.frame_dk)
                else:
                    c.px(x, yy, t.frame_hi if x < cx else t.frame_mid)
        # Mossy tufts on upper-left arch stones
        for mx, my in [(3, crown_h - 1), (4, crown_h - 2), (5, crown_h - 2), (6, crown_h - 1), (w - 6, crown_h - 1)]:
            c.px(mx, my, t.deco_mid)
            c.px(mx, my - 1, t.deco_hi if mx < cx else t.deco_dk)
    elif iid == 2:
        # Stepped maritime bulkhead beam with twin raised brass capstans
        c.rect(2, 1, w - 4, crown_h, t.frame_mid)
        c.hline(3, w - 4, 0, t.out)
        c.hline(3, w - 4, 1, t.frame_hi)
        c.hline(2, w - 3, 2, t.frame_rim)
        c.px(2, 1, t.out)
        c.px(w - 3, 1, t.out)
        # Brass ship rivets & raised capstan cleats
        for rx in (5, 10, w - 11, w - 6):
            c.px(rx, 1, t.trim_hi)
            c.px(rx, 2, t.trim_mid)
        # Center helm-arch bump
        c.rect(cx - 4, 0, 8, 3, t.trim_mid)
        c.hline(cx - 3, cx + 2, 0, t.out)
        c.hline(cx - 3, cx + 2, 1, t.trim_hi)
        c.px(cx - 1, 2, "sky")
        c.px(cx, 2, "ice")
    elif iid == 3:
        # Gnarled Hollow Oak bough arch with leafy moss shoots
        for x in range(1, w - 1):
            dist = abs(x - (cx - 0.5)) / (w * 0.5)
            top = int(round(dist * dist * (crown_h - 1)))
            c.px(x, top, t.out)
            for yy in range(top + 1, crown_h + 1):
                c.px(x, yy, t.frame_hi if (x + yy) % 3 == 0 else t.frame_mid)
        # Protruding leafy moss twigs
        for lx, ly in [(3, 2), (4, 1), (8, 0), (9, 1), (w - 9, 0), (w - 5, 1), (w - 4, 2)]:
            c.px(lx, ly, t.deco_hi if lx < cx + 4 else t.deco_mid)
            c.px(lx, ly + 1, t.deco_mid)
            if ly + 2 <= crown_h:
                c.px(lx, ly + 2, t.deco_dk)
    elif iid == 4:
        # Scalloped Victorian glasshouse transom arch
        for x in range(1, w - 1):
            dist = abs(x - (cx - 0.5)) / (w * 0.5)
            top = int(round(dist * dist * (crown_h - 0.5)))
            c.px(x, top, t.out)
            for yy in range(top + 1, crown_h + 1):
                if (x - cx) % 4 == 0:
                    c.px(x, yy, "pine")
                elif yy == top + 1:
                    c.px(x, yy, "ice")
                else:
                    c.px(x, yy, "sky" if x < cx + 2 else "teal")
        # Copper finial at apex
        c.px(cx - 1, 0, "rose")
        c.px(cx, 0, "cream")
    elif iid == 5:
        # Stepped cobalt observatory pediment inlaid with brass zenith pin
        c.rect(1, 2, w - 2, crown_h - 1, t.frame_mid)
        c.rect(5, 1, w - 10, crown_h, t.frame_hi)
        c.hline(6, w - 7, 0, t.out)
        c.hline(6, w - 7, 1, t.frame_rim)
        c.hline(2, 5, 1, t.out)
        c.hline(w - 6, w - 3, 1, t.out)
        c.hline(2, w - 3, 2, t.trim_hi)
        c.px(cx - 1, 0, "gold")
        c.px(cx, 0, "cream")
        c.px(cx - 1, 1, "apricot")
        c.px(cx, 1, "gold")
    elif iid == 6:
        # Heavy trapezoid cast-iron blast-furnace hood with corner lugs & glowing vent
        c.rect(1, 2, w - 2, crown_h - 1, "night")
        c.rect(3, 1, w - 6, crown_h, "dusk")
        c.hline(4, w - 5, 0, "void")
        c.hline(4, w - 5, 1, "mauve")
        # Corner exhaust bolt lugs
        for lx in (2, w - 4):
            c.rect(lx, 1, 2, 2, "dusk")
            c.px(lx, 1, "stone")
        # Glowing furnace slit across crown
        c.hline(cx - 5, cx + 4, crown_h - 1, "coral")
        c.hline(cx - 3, cx + 2, crown_h - 1, "apricot")
        c.hline(cx - 1, cx, crown_h - 1, "gold")
    elif iid == 7:
        # Sharp faceted silver-glass twin-peak chevron arch
        for x in range(1, w - 1):
            # Angular crystal gable
            dist = abs(x - (cx - 0.5)) / (w * 0.5)
            top = int(round(dist * crown_h))
            c.px(x, top, t.out)
            for yy in range(top + 1, crown_h + 1):
                if yy == top + 1:
                    c.px(x, yy, "cream" if x < cx else "ice")
                elif x < cx:
                    c.px(x, yy, "ice" if (x + yy) % 2 == 0 else "sky")
                else:
                    c.px(x, yy, "sky" if (x + yy) % 2 == 0 else "blue")
        c.px(cx - 1, 0, "cream")
        c.px(cx, 0, "ice")
    elif iid == 8:
        # Pointed Gothic ogive arch with carved stone crockets & stained glass top
        for x in range(1, w - 1):
            dist = abs(x - (cx - 0.5)) / (w * 0.5)
            top = int(round((dist ** 0.78) * crown_h))
            c.px(x, top, t.out)
            for yy in range(top + 1, crown_h + 1):
                if yy == top + 1:
                    c.px(x, yy, "plum" if x < cx else "dusk")
                else:
                    c.px(x, yy, "dusk" if x < cx else "night")
        # Stained-glass crimson rose transom jewel
        c.rect(cx - 3, 2, 6, max(2, crown_h - 1), "wine")
        c.px(cx - 1, 2, "rose")
        c.px(cx, 2, "gold")
        c.px(cx - 1, 3, "gold")
        c.px(cx, 3, "cream")
        # Gothic crocket spires on shoulders
        c.px(3, 1, "plum")
        c.px(w - 4, 1, "dusk")


def _paint_keyhole_escutcheon(c: Canvas, t: IslandTheme, cx: int, cy: int) -> None:
    """Paint an iconic, immediately-readable biome keyhole escutcheon centered at (cx, cy)."""
    iid = t.island_id
    # Dark outer silhouette backing for high contrast
    c.rect(cx - 4, cy - 4, 8, 9, t.out)
    if iid == 1:
        # Bronze bell-shield lock
        c.rect(cx - 3, cy - 3, 6, 6, t.trim_mid)
        c.hline(cx - 2, cx + 1, cy - 3, t.trim_hi)
        c.hline(cx - 3, cx + 2, cy + 2, t.trim_dk)
        c.hline(cx - 2, cx + 1, cy + 3, t.trim_dk)
        c.px(cx - 3, cy - 3, t.out)
        c.px(cx + 2, cy - 3, t.out)
    elif iid == 2:
        # Circular brass ship-porthole lock with sea-glass inner ring
        c.circle_fill(cx, cy, 3.8, t.out)
        c.circle_fill(cx, cy, 3.0, t.trim_mid)
        c.px(cx - 2, cy - 2, t.trim_hi)
        c.px(cx - 1, cy - 3, t.trim_core)
        c.px(cx + 2, cy + 2, "coral")
        c.rect(cx - 2, cy - 1, 4, 3, "deep")
        c.px(cx - 2, cy - 1, "sky")
        c.px(cx + 1, cy - 1, "ice")
    elif iid == 3:
        # Amber-leaf keyhole escutcheon with green stem
        c.rect(cx - 3, cy - 3, 6, 7, t.trim_mid)
        c.px(cx - 3, cy - 3, t.out)
        c.px(cx + 2, cy - 3, t.out)
        c.px(cx - 3, cy + 3, t.out)
        c.px(cx + 2, cy + 3, t.out)
        c.hline(cx - 2, cx + 1, cy - 3, t.trim_hi)
        c.px(cx - 1, cy - 4, t.deco_hi)
        c.px(cx, cy - 4, t.deco_mid)
        c.px(cx - 3, cy, t.deco_mid)
        c.px(cx + 2, cy, t.deco_dk)
    elif iid == 4:
        # Copper & rose Victorian filigree diamond lock
        c.rect(cx - 3, cy - 3, 6, 7, t.trim_mid)
        c.hline(cx - 2, cx + 1, cy - 3, "rose")
        c.hline(cx - 2, cx + 1, cy + 3, "wine")
        c.px(cx - 3, cy - 2, "cream")
        c.px(cx + 2, cy - 2, "rose")
        c.px(cx - 3, cy + 2, "wine")
        c.px(cx + 2, cy + 2, "wine")
    elif iid == 5:
        # Gilded brass astrolabe-ring lock
        c.rect(cx - 3, cy - 3, 6, 7, "deep")
        c.box(cx - 3, cy - 3, 6, 7, "gold")
        c.hline(cx - 2, cx + 1, cy - 3, "cream")
        c.hline(cx - 2, cx + 1, cy + 3, "apricot")
        c.px(cx - 4, cy, "gold")
        c.px(cx + 3, cy, "apricot")
    elif iid == 6:
        # Molten crucible-plate furnace lock
        c.rect(cx - 3, cy - 3, 6, 7, "dusk")
        c.box(cx - 3, cy - 3, 6, 7, "coral")
        c.hline(cx - 2, cx + 1, cy - 3, "apricot")
        c.px(cx - 3, cy - 3, "mauve")
        c.px(cx + 2, cy - 3, "mauve")
        c.px(cx - 3, cy + 3, "mauve")
        c.px(cx + 2, cy + 3, "mauve")
    elif iid == 7:
        # Faceted crystal-prism diamond lock
        c.rect(cx - 3, cy - 3, 6, 7, "sky")
        c.hline(cx - 2, cx + 1, cy - 3, "cream")
        c.vline(cx - 3, cy - 2, cy + 2, "ice")
        c.vline(cx + 2, cy - 2, cy + 2, "blue")
        c.hline(cx - 2, cx + 1, cy + 3, "mauve")
        c.px(cx - 3, cy - 3, t.out)
        c.px(cx + 2, cy - 3, t.out)
    elif iid == 8:
        # Gothic rose-gold lancet escutcheon
        c.rect(cx - 3, cy - 3, 6, 7, "wine")
        c.hline(cx - 2, cx + 1, cy - 3, "gold")
        c.px(cx - 1, cy - 4, "gold")
        c.px(cx, cy - 4, "cream")
        c.vline(cx - 3, cy - 2, cy + 2, "rose")
        c.vline(cx + 2, cy - 2, cy + 2, "plum")
        c.hline(cx - 2, cx + 1, cy + 3, "gold")

    # Iconic unmistakable keyhole cutout right at the center:
    # Bright glowing bezel ring surrounding a crisp dark void keyhole (2x2 head + 1x2 narrow slot)!
    ring_hi = "cream" if iid == 7 else "gold"
    ring_lo = "ice" if iid == 7 else "apricot"
    c.hline(cx - 2, cx + 1, cy - 2, ring_hi)
    c.vline(cx - 2, cy - 1, cy + 1, ring_lo)
    c.vline(cx + 1, cy - 1, cy + 1, ring_hi)
    c.hline(cx - 2, cx + 1, cy + 2, ring_lo)
    # Dark recessed keyhole slot (round top head + narrow lower stem)
    c.rect(cx - 1, cy - 1, 2, 2, "void")
    c.px(cx - 1, cy + 1, "void")
    c.px(cx, cy + 1, "void")
    # Crisp 1px keyhole specular glint so it reads even in shadow
    c.px(cx - 2, cy - 2, "cream")
    c.px(cx + 1, cy + 1, "cream" if iid == 7 else "gold")


def _paint_pier_block(
    c: Canvas, t: IslandTheme, x: int, y: int, w: int, h: int
) -> None:
    """Paint a sturdy biome stone/timber/iron architectural pier or jamb."""
    c.bevel_rect(x, y, w, h, t.frame_mid, t.frame_hi, t.frame_dk, t.out)
    # Lit top-left rim highlight
    if w >= 4 and h >= 4:
        c.hline(x + 1, x + w - 2, y + 1, t.frame_rim)
    # Biome detail inside pier
    if h >= 8 and w >= 5:
        for yy in range(y + 4, y + h - 3, 4):
            c.hline(x + 1, x + w - 2, yy, t.frame_dk)
            if yy + 1 < y + h - 2:
                c.px(x + 1, yy + 1, t.frame_rim)
    if t.island_id == 1 and w >= 5 and h >= 6:
        c.px(x + 1, y + 2, t.deco_mid)
        c.px(x + 2, y + 2, t.deco_hi)
    elif t.island_id == 2 and w >= 5 and h >= 6:
        c.px(x + w // 2, y + 2, t.trim_hi)
        c.px(x + w // 2, y + h - 3, t.trim_mid)
    elif t.island_id == 3 and w >= 5 and h >= 6:
        c.px(x + 1, y + 3, t.deco_hi)
        c.px(x + 2, y + 4, t.deco_mid)
    elif t.island_id == 5 and w >= 5 and h >= 6:
        c.hline(x + 1, x + w - 2, y + h // 2, "gold")
    elif t.island_id == 6 and w >= 5 and h >= 6:
        c.px(x + w // 2, y + h // 2, "coral")
    elif t.island_id == 7 and w >= 5 and h >= 6:
        c.line(x + 1, y + 2, x + min(w - 2, 3), y + 4, "cream")
    elif t.island_id == 8 and w >= 5 and h >= 6:
        c.px(x + w // 2, y + 2, "rose")
        c.px(x + w // 2, y + h - 3, "gold")


# ---------------------------------------------------------------------------
# Sprite Generators (22 canonical keys per island)
# ---------------------------------------------------------------------------

def draw_wick_key_h(t: IslandTheme) -> list[Canvas]:
    """32x20, 1f, origin [16, 12]: Sculpted horizontal locked key door."""
    c = Canvas(32, 20)
    # Main door body below crown (y = 4..19)
    c.rect(0, 4, 32, 16, t.out)
    # Left & right arch jamb piers
    _paint_pier_block(c, t, 0, 4, 5, 16)
    _paint_pier_block(c, t, 27, 4, 5, 16)
    # Double door recessed leaves (x = 5..15 and 16..26, y = 5..18)
    _paint_panel_surface(c, t, 5, 5, 10, 13)
    _paint_panel_surface(c, t, 17, 5, 10, 13)
    # Center seam between double leaves
    c.vline(15, 5, 18, t.out)
    c.vline(16, 5, 18, t.frame_dk)
    # Top lintel band & bottom threshold sill
    c.hline(5, 26, 5, t.trim_hi)
    c.hline(5, 26, 6, t.trim_mid)
    c.hline(5, 26, 17, t.trim_dk)
    c.hline(5, 26, 18, t.frame_dk)
    c.hline(1, 30, 19, t.out)
    # Sculpted biome archway crown overhead (y = 0..4)
    _paint_arch_crown_h(c, t, 32, 4)
    # Iconic centered keyhole escutcheon
    _paint_keyhole_escutcheon(c, t, 16, 12)
    return [c]


def draw_wick_key_v(t: IslandTheme) -> list[Canvas]:
    """16x48, 1f, origin [8, 24]: Sculpted vertical locked key door."""
    c = Canvas(16, 48)
    # Full vertical body outline
    c.rect(0, 0, 16, 48, t.out)
    # Sculpted top & bottom masonry/wood jamb caps
    _paint_pier_block(c, t, 0, 0, 16, 7)
    _paint_pier_block(c, t, 0, 41, 16, 7)
    # Trim collars beneath top cap and above bottom cap
    c.hline(1, 14, 7, t.trim_hi)
    c.hline(1, 14, 8, t.trim_mid)
    c.hline(1, 14, 39, t.trim_mid)
    c.hline(1, 14, 40, t.trim_dk)
    # Left & right side framing rails (x=1, x=14)
    c.vline(1, 8, 39, t.frame_hi)
    c.vline(2, 8, 39, t.frame_mid)
    c.vline(13, 8, 39, t.frame_mid)
    c.vline(14, 8, 39, t.frame_dk)
    # Ribbed vertical panels (upper leaf y=9..21, lower leaf y=27..38)
    _paint_panel_surface(c, t, 3, 9, 10, 30, vertical=True)
    # Horizontal reinforcing cross-straps
    for sy in (14, 33):
        c.hline(2, 13, sy - 1, t.out)
        c.hline(2, 13, sy, t.trim_hi)
        c.hline(2, 13, sy + 1, t.trim_dk)
        c.px(3, sy, t.trim_core)
        c.px(12, sy, t.trim_mid)
    # Center seam line vertically through panels
    c.vline(8, 9, 38, t.out)
    # Bold glowing centered keyhole lock at (8, 24)
    _paint_keyhole_escutcheon(c, t, 8, 24)
    return [c]


def draw_boss_key_h(t: IslandTheme) -> list[Canvas]:
    """36x24, 4f animated, origin [18, 16]: Monumental grand boss arch."""
    frames: list[Canvas] = []
    iid = t.island_id
    for f in range(4):
        c = Canvas(36, 24)
        # Massive side guardian buttresses (x=0..5 and 30..35, y=7..23)
        _paint_pier_block(c, t, 0, 7, 6, 17)
        _paint_pier_block(c, t, 30, 7, 6, 17)
        # Main vault door cavity (x=6..29, y=8..23)
        c.rect(5, 8, 26, 16, t.out)
        _paint_panel_surface(c, t, 6, 9, 11, 13)
        _paint_panel_surface(c, t, 19, 9, 11, 13)
        c.vline(17, 9, 22, t.out)
        c.vline(18, 9, 22, t.out)
        # Ornate boss lintel & sill beams
        c.hline(6, 29, 9, t.trim_core)
        c.hline(6, 29, 10, t.trim_hi)
        c.hline(6, 29, 21, t.trim_mid)
        c.hline(6, 29, 22, t.trim_dk)
        c.hline(1, 34, 23, t.out)
        # Twin side boss-ring knockers
        for kx in (9, 26):
            c.box(kx - 1, 14, 3, 4, t.out)
            c.px(kx, 15, t.trim_hi)
            c.px(kx, 16, t.trim_core if f % 2 == 0 else t.trim_mid)

        # ---- BESPOKE MONUMENTAL BOSS ARCH CROWN (y = 0..9) ----
        if iid == 1:
            # Crowned Bronze Bell Boss Arch: twin belfry turrets + grand bronze bell
            for tx in (1, 30):
                c.bevel_rect(tx, 3, 5, 5, "dusk", "stone", "night", "void")
                c.px(tx + 1, 2, "void")
                c.px(tx + 3, 2, "void")
                c.px(tx + 2, 3, "gold")
            # Grand rounded stone belfry arch (x=6..29)
            for x in range(6, 30):
                d = abs(x - 17.5) / 12.0
                top = int(round(1 + d * d * 6))
                c.px(x, top, "void")
                for yy in range(top + 1, 10):
                    c.px(x, yy, "stone" if yy == top + 1 else ("mauve" if x < 18 else "dusk"))
            # Moss tufts on stone belfry
            c.px(7, 6, "jade"); c.px(8, 5, "lime"); c.px(28, 6, "jade")
            # Crowned bronze bell niche in center
            c.rect(13, 2, 10, 8, "void")
            sway = (0, 1, 0, -1)[f]
            # Bell body
            c.rect(16 + sway, 3, 4, 4, "apricot")
            c.hline(15 + sway, 20 + sway, 7, "gold")
            c.hline(16 + sway, 19 + sway, 3, "gold")
            c.px(16 + sway, 4, "cream")
            c.px(17 + sway, 8, "cream" if f % 2 == 0 else "gold")  # clapper
            # Crown finial above bell
            c.hline(16, 19, 1, "gold")
            c.px(17, 0, "cream"); c.px(18, 0, "gold")
            # Animated warm aura motes around bell
            mote_x = (14, 21, 15, 20)[f]
            c.px(mote_x, 4 + (f % 2), "cream")
            c.px(35 - mote_x, 6 - (f % 2), "gold")

        elif iid == 2:
            # Giant Fresnel Lens & Anchor-Chain Boss Door
            for tx in (1, 31):
                c.bevel_rect(tx, 2, 4, 6, "pine", "teal", "night", "void")
                c.px(tx + 1, 1, "gold")
                c.px(tx + 2, 1, "cream" if f % 2 == 0 else "apricot")
            # Draped iron anchor chains from outer towers to central lens
            for cx_p in range(5, 13):
                cy_p = 5 + int(round(math.sin((cx_p - 5) / 7.0 * math.pi) * 2.5))
                c.px(cx_p, cy_p, "stone" if (cx_p + f) % 2 == 0 else "mauve")
                c.px(cx_p, cy_p + 1, "void")
                c.px(35 - cx_p, cy_p, "stone" if (cx_p + f) % 2 == 1 else "mauve")
                c.px(35 - cx_p, cy_p + 1, "void")
            # Giant domed Fresnel lens housing at center
            c.circle_fill(18, 6, 5.5, "void")
            c.circle_fill(18, 6, 4.5, "apricot")
            c.circle_fill(18, 6, 3.3, "deep")
            # Rotating Fresnel lighthouse beam rings across 4 frames
            beam_dx = (-2, -1, 1, 2)[f]
            c.circle_fill(18, 6, 2.2, "blue")
            c.vline(18 + beam_dx, 4, 8, "ice")
            c.px(18 + beam_dx, 6, "cream")
            c.px(18, 6, "cream")
            # Brass lantern cupola top
            c.hline(16, 20, 1, "gold")
            c.px(18, 0, "cream")

        elif iid == 3:
            # Horned Hollow Oak Root-Arch Boss Gate with emerald seed-flame
            # Sweeping gnarled oak antler-horns at left & right top
            c.line(2, 7, 1, 2, "void"); c.line(3, 7, 2, 2, "plum"); c.line(4, 7, 4, 3, "wine")
            c.line(2, 2, 7, 0, "plum"); c.px(6, 0, "coral"); c.px(3, 1, "lime"); c.px(4, 2, "jade")
            c.line(33, 7, 34, 2, "void"); c.line(32, 7, 33, 2, "plum"); c.line(31, 7, 31, 3, "wine")
            c.line(33, 2, 28, 0, "plum"); c.px(29, 0, "wine"); c.px(32, 1, "jade"); c.px(31, 2, "teal")
            # Root arch bridge
            for x in range(5, 31):
                d = abs(x - 17.5) / 13.0
                top = int(round(2 + d * d * 5))
                c.px(x, top, "void")
                for yy in range(top + 1, 10):
                    c.px(x, yy, "wine" if (x + yy) % 3 == 0 else "plum")
            # Mossy leaf clusters
            for lx, ly in [(8, 4), (9, 3), (10, 4), (25, 4), (26, 3), (27, 4)]:
                c.px(lx, ly, "lime" if (lx + f) % 2 == 0 else "jade")
            # Hollow core with beating emerald seed-flame (4 frames)
            c.rect(14, 2, 8, 8, "void")
            c.rect(15, 3, 6, 6, "pine")
            flame_h = (4, 5, 6, 5)[f]
            for fy in range(8 - flame_h, 9):
                w_f = 2 if fy > 5 else 1
                for fx in range(18 - w_f, 18 + w_f):
                    col = "cream" if fy >= 6 and abs(fx - 17.5) < 1 else ("lime" if fy >= 5 else "jade")
                    c.px(fx, fy, col)
            c.px(17 + (f % 2), 2 - (1 if f == 2 else 0), "lime")

        elif iid == 4:
            # Domed Ghost-Orchid Glass Conservatory Boss Portal
            # Vaulted glass dome spanning x=4..31
            for x in range(4, 32):
                d = abs(x - 17.5) / 14.0
                top = int(round(1 + d * d * 7))
                c.px(x, top, "void")
                for yy in range(top + 1, 10):
                    if (x - 18) % 5 == 0 or yy == top + 1:
                        c.px(x, yy, "ice" if yy == top + 1 else "pine")
                    else:
                        c.px(x, yy, "sky" if (x + yy) % 2 == 0 else "teal")
            # Wrought-iron dome finial
            c.vline(18, 0, 2, "rose")
            c.px(17, 1, "cream")
            # Glowing Ghost-Orchid blossom breathing at dome center
            bloom = (0, 1, 1, 0)[f]
            c.circle_fill(18, 6, 2.5 + bloom * 0.6, "mauve")
            # Orchid petals
            for px, py in [(18, 3 - bloom), (15 - bloom, 6), (21 + bloom, 6), (17, 8), (19, 8)]:
                c.px(px, py, "rose")
                c.px(px, max(1, py - 1), "cream" if f % 2 == 0 else "rose")
            c.rect(17, 5, 2, 2, "cream")
            # Drifting mist motes
            c.px(10 + f * 2, 4 + (f % 2), "ice")
            c.px(25 - f * 2, 5 - (f % 2), "rose")

        elif iid == 5:
            # Celestial Sun-and-Crescent Orrery Boss Arch
            # Stepped cobalt observatory crown
            c.rect(4, 5, 28, 5, "deep")
            c.rect(8, 3, 20, 4, "blue")
            c.hline(4, 31, 4, "void"); c.hline(8, 27, 2, "void")
            c.hline(5, 30, 5, "sky"); c.hline(9, 26, 3, "gold")
            # Twin brass astrolabe side fins
            for sx in (2, 32):
                c.rect(sx, 4, 2, 4, "apricot")
                c.px(sx, 3, "gold")
            # Concentric brass orrery halo
            c.circle_fill(18, 5, 5.2, "void")
            for a_i in range(16):
                ang = a_i * math.tau / 16.0
                ox = int(round(18 + math.cos(ang) * 4.4))
                oy = int(round(5 + math.sin(ang) * 4.0))
                c.px(ox, oy, "gold" if (a_i + f) % 2 == 0 else "apricot")
            # Orbiting celestial star pips (rotate across 4 frames)
            orb_ang = f * (math.tau / 4.0) + 0.4
            ox1 = int(round(18 + math.cos(orb_ang) * 4.4))
            oy1 = int(round(5 + math.sin(orb_ang) * 4.0))
            ox2 = int(round(18 - math.cos(orb_ang) * 4.4))
            oy2 = int(round(5 - math.sin(orb_ang) * 4.0))
            c.px(ox1, oy1, "cream"); c.px(ox2, oy2, "ice")
            # Central sun-and-crescent core
            c.circle_fill(18, 5, 2.2, "gold")
            c.px(17, 4, "cream"); c.px(18, 5, "cream")
            c.px(19, 5, "deep"); c.px(19, 4, "deep")  # crescent shadow cutout

        elif iid == 6:
            # Chained Crucible-Anvil Magma Boss Vault
            # Horned cast-iron furnace crown
            c.rect(2, 4, 32, 6, "night")
            c.rect(5, 2, 26, 5, "dusk")
            c.hline(5, 30, 1, "void"); c.hline(6, 29, 2, "mauve")
            # Anvil horn wings
            c.hline(1, 5, 3, "mauve"); c.hline(2, 5, 4, "dusk"); c.px(1, 2, "void")
            c.hline(30, 34, 3, "mauve"); c.hline(30, 33, 4, "dusk"); c.px(34, 2, "void")
            # Diagonal forged chains binding vault
            for i in range(6):
                c.px(6 + i, 5 + i // 2, "stone" if (i + f) % 2 == 0 else "mauve")
                c.px(29 - i, 5 + i // 2, "stone" if (i + f) % 2 == 1 else "mauve")
            # Molten crucible bowl pouring magma at center
            c.rect(13, 1, 10, 8, "void")
            c.rect(14, 3, 8, 5, "wine")
            c.rect(15, 3, 6, 4, "coral")
            # Bubbling animated molten metal & sparks
            c.hline(15, 20, 3, "apricot")
            c.hline(16, 19, 4, "gold")
            c.px(16 + (f % 3), 2, "gold")
            c.px(19 - (f % 3), 1, "cream")
            c.px(17 + (f % 2), 4, "cream")
            # Glowing magma drip down center seam
            drip_y = 8 + (f % 4)
            c.px(17, drip_y, "apricot"); c.px(18, drip_y, "gold")

        elif iid == 7:
            # Twin Inverted-Bell Crystal Boss Arch
            # Tall faceted crystal mirror-spires on left & right
            for sx, flip in [(2, 1), (33, -1)]:
                for dy in range(7):
                    c.px(sx, 1 + dy, "ice" if flip > 0 else "sky")
                    c.px(sx + flip, 2 + dy, "sky" if flip > 0 else "blue")
                    c.px(sx + flip * 2, 3 + dy, "blue" if flip > 0 else "deep")
                c.px(sx, 0, "cream")
            # Crystal chevron arch bridge
            for x in range(5, 31):
                d = abs(x - 17.5) / 13.0
                top = int(round(1 + d * 6))
                c.px(x, top, "void")
                for yy in range(top + 1, 10):
                    c.px(x, yy, "ice" if yy == top + 1 else ("sky" if x < 18 else "blue"))
            # Twin inverted-bell crystal prism at center (sculpted diamond silhouette!)
            for dy in range(-4, 5):
                span = 4 - abs(dy)
                c.hline(18 - span, 17 + span, 5 + dy, "deep")
                c.px(18 - span, 5 + dy, "ice" if dy <= 0 else "sky")
                c.px(17 + span, 5 + dy, "sky" if dy <= 0 else "blue")
            c.px(17, 0, "cream"); c.px(18, 0, "ice")
            # Upper upright crystal bell
            c.hline(17, 18, 2, "cream"); c.hline(16, 19, 3, "ice"); c.hline(15, 20, 4, "sky")
            # Horizon lunar mirror plane
            c.hline(14, 21, 5, "mauve")
            c.px(14, 5, "stone"); c.px(21, 5, "stone")
            # Lower inverted reflection bell
            c.hline(15, 20, 6, "sky"); c.hline(16, 19, 7, "ice"); c.hline(17, 18, 8, "mauve")
            # Gliding diamond sparkle across 4 frames
            sp_x = (16, 17, 19, 18)[f]
            sp_y = (3, 2, 3, 7)[f]
            c.px(sp_x, sp_y, "cream")
            c.px(sp_x, max(1, sp_y - 1), "ice")

        elif iid == 8:
            # Towering Hush-Sanctum Eclipse Boss Portal with Gothic finials
            # Soaring twin Gothic spire pinnacles
            for sx in (1, 32):
                c.rect(sx, 3, 3, 6, "night")
                c.vline(sx, 3, 8, "plum")
                c.px(sx + 1, 1, "gold")
                c.px(sx + 1, 2, "rose")
                c.px(sx + 1, 0, "void")
            # Pointed Gothic cathedral arch
            for x in range(4, 32):
                d = abs(x - 17.5) / 14.0
                top = int(round((d ** 0.72) * 7))
                c.px(x, top, "void")
                for yy in range(top + 1, 10):
                    c.px(x, yy, "plum" if yy == top + 1 else ("dusk" if x < 18 else "night"))
            # Luminous Hush-Sanctum Eclipse rose-window halo
            c.circle_fill(18, 5, 4.5, "wine")
            for a_i in range(8):
                ang = a_i * math.tau / 8.0 + f * (math.tau / 16.0)
                rx = int(round(18 + math.cos(ang) * 4.3))
                ry = int(round(5 + math.sin(ang) * 3.8))
                c.px(rx, ry, "gold" if a_i % 2 == 0 else "rose")
            c.circle_fill(18, 5, 3.0, "gold" if f % 2 == 0 else "rose")
            c.circle_fill(18, 5, 2.0, "void")  # Eclipse core!
            # Corona glint points
            c.px(18, 2, "cream"); c.px(18, 8, "gold")
            c.px(15, 5, "cream" if f in (0, 2) else "gold")
            c.px(21, 5, "gold" if f in (0, 2) else "cream")

        # Bold heroic central Boss Lock medallion (centered at x=18, y=16)
        c.rect(13, 12, 10, 9, "void")
        c.bevel_rect(14, 13, 8, 7, t.trim_mid, t.trim_core, t.trim_dk)
        # Animated inner boss flame jewel
        c.rect(16, 14, 4, 5, t.trim_dk)
        c.rect(17, 14, 2, 4, t.trim_core if f % 2 == 0 else t.trim_hi)
        c.px(17 + (f % 2), 14, "cream")
        c.px(17, 15, "cream")
        c.px(18, 17, t.trim_hi)
        frames.append(c)
    return frames


def draw_switch_door_h(t: IslandTheme) -> list[Canvas]:
    """32x18, 2f, origin [16, 10]: Biome shutter slab with glowing conduit & rune socket."""
    frames: list[Canvas] = []
    for f in range(2):
        c = Canvas(32, 18)
        c.rect(0, 0, 32, 18, t.out)
        # Top sculpted cornice lip
        c.hline(1, 30, 1, t.frame_rim)
        c.hline(1, 30, 2, t.frame_hi)
        # Side clamping piers
        _paint_pier_block(c, t, 0, 1, 4, 17)
        _paint_pier_block(c, t, 28, 1, 4, 17)
        # Main shutter body
        _paint_panel_surface(c, t, 4, 3, 24, 13)
        c.hline(4, 27, 16, t.frame_dk)
        # Carved horizontal glowing conduit channel at y=8..11
        c.hline(4, 27, 8, t.out)
        c.hline(4, 27, 11, t.out)
        c.rect(4, 9, 24, 2, t.sig_dk)
        c.hline(5, 26, 9, t.sig_mid if f == 0 else t.sig_hi)
        # Traveling conduit pulse dots
        for px in range(6 + f * 2, 26, 4):
            c.px(px, 9, t.sig_hi if f == 0 else t.sig_core)
            c.px(px + 1, 10, t.sig_mid)
        # Central biome rune socket at (16, 10)
        c.rect(12, 6, 8, 8, t.out)
        c.bevel_rect(13, 7, 6, 6, t.sig_dk, t.frame_rim, t.frame_dk)
        c.rect(14, 8, 4, 4, t.sig_mid if f == 0 else t.sig_hi)
        c.rect(15, 9, 2, 2, t.sig_hi if f == 0 else t.sig_core)
        c.px(15, 9, t.sig_core)
        frames.append(c)
    return frames


def draw_switch_door_v_cap(t: IslandTheme) -> list[Canvas]:
    """16x8, 1f, origin [8, 4]: Vertical switch shutter end cap."""
    c = Canvas(16, 8)
    _paint_pier_block(c, t, 0, 0, 16, 8)
    # Conduit entry notch in center
    c.rect(6, 5, 4, 3, t.out)
    c.rect(7, 6, 2, 2, t.sig_mid)
    c.px(7, 6, t.sig_hi)
    return [c]


def draw_switch_door_v_mid(t: IslandTheme) -> list[Canvas]:
    """16x16, 2f, origin [8, 8]: Vertical switch shutter modular slab."""
    frames: list[Canvas] = []
    for f in range(2):
        c = Canvas(16, 16)
        c.rect(0, 0, 16, 16, t.out)
        # Side vertical rails
        c.vline(1, 0, 15, t.frame_rim)
        c.vline(2, 0, 15, t.frame_hi)
        c.vline(13, 0, 15, t.frame_mid)
        c.vline(14, 0, 15, t.frame_dk)
        # Biome panel fill
        _paint_panel_surface(c, t, 3, 0, 10, 16, vertical=True)
        # Horizontal tile-seam bevel grooves (seamless tiling!)
        c.hline(3, 12, 0, t.frame_dk)
        c.hline(3, 12, 8, t.frame_dk)
        c.hline(3, 12, 1, t.frame_hi)
        c.hline(3, 12, 9, t.frame_hi)
        # Vertical glowing conduit channel down center (x=6..9)
        c.vline(6, 0, 15, t.out)
        c.vline(9, 0, 15, t.out)
        c.rect(7, 0, 2, 16, t.sig_dk)
        c.vline(7, 0, 15, t.sig_mid if f == 0 else t.sig_hi)
        for py in range(1 + f * 2, 15, 4):
            c.px(7, py, t.sig_core if f == 1 else t.sig_hi)
            c.px(8, py + 1, t.sig_mid)
        frames.append(c)
    return frames


def draw_switch_door_v_seal(t: IslandTheme) -> list[Canvas]:
    """16x16, 2f, origin [8, 8]: Vertical/square switch shutter with central rune socket."""
    mids = draw_switch_door_v_mid(t)
    for f, c in enumerate(mids):
        # Bold central rune socket centered at (8, 8)
        c.rect(4, 4, 8, 8, t.out)
        c.bevel_rect(5, 5, 6, 6, t.sig_dk, t.frame_rim, t.frame_dk)
        c.rect(6, 6, 4, 4, t.sig_mid if f == 0 else t.sig_hi)
        c.rect(7, 7, 2, 2, t.sig_hi if f == 0 else t.sig_core)
        c.px(7, 7, "cream" if f == 1 else t.sig_core)
    return mids


def _paint_gate_bars_h(c: Canvas, t: IslandTheme, x0: int, x1: int, y0: int, y1: int, f: int) -> None:
    """Paint biome-distinct vertical portcullis bars / lattice for horizontal combat gates."""
    iid = t.island_id
    # Dark passage interior behind bars
    c.rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, "void")
    # Horizontal cross-brace beam behind bars
    ymid = (y0 + y1) // 2
    c.hline(x0, x1, ymid - 1, t.frame_dk)
    c.hline(x0, x1, ymid, t.frame_mid)
    c.hline(x0, x1, ymid + 1, t.out)

    for bx in range(x0 + 1, x1, 4):
        if iid == 1:
            # Bell-tower iron portcullis spears
            c.vline(bx, y0, y1, "mauve")
            c.vline(bx + 1, y0, y1, "dusk")
            c.px(bx, y1 - 1, "stone")
        elif iid == 2:
            # Harpoon-iron harbor bars with barbed tips
            c.vline(bx, y0, y1, "sky")
            c.vline(bx + 1, y0, y1, "pine")
            c.px(bx - 1, y1 - 2, "teal")
            c.px(bx + 2, y1 - 2, "teal")
            c.px(bx, y1 - 1, "ice")
        elif iid == 3:
            # Rose-thorn briar lattice
            c.vline(bx, y0, y1, "jade")
            c.vline(bx + 1, y0, y1, "pine")
            c.px(bx - 1, y0 + 3, "rose" if f == 0 else "wine")
            c.px(bx + 2, y1 - 3, "wine" if f == 0 else "rose")
            c.hline(x0, x1, ymid, "teal")
        elif iid == 4:
            # Corroded wrought-iron conservatory trellis (diamond lattice)
            for yy in range(y0, y1 + 1):
                for xx in range(x0, x1 + 1):
                    if (xx + yy) % 5 == 0 or (xx - yy) % 5 == 0:
                        c.px(xx, yy, "sky" if (xx + yy) % 5 == 0 else "teal")
            break
        elif iid == 5:
            # Gilded meridian-iron observatory bars with brass ring collars
            c.vline(bx, y0, y1, "blue")
            c.vline(bx + 1, y0, y1, "deep")
            c.px(bx, ymid, "gold")
            c.px(bx + 1, ymid, "apricot")
            c.px(bx, y0 + 1, "sky")
        elif iid == 6:
            # Glowing forged iron chain-portcullis
            for yy in range(y0, y1 + 1):
                if yy % 3 == 0:
                    c.px(bx, yy, "mauve")
                    c.px(bx + 1, yy, "dusk")
                elif yy % 3 == 1:
                    c.px(bx, yy, "coral" if (yy + f) % 2 == 0 else "dusk")
                    c.px(bx + 1, yy, "stone")
                else:
                    c.px(bx, yy, "dusk")
                    c.px(bx + 1, yy, "wine")
        elif iid == 7:
            # Razor glass-shard crystal lattice
            for yy in range(y0, y1 + 1):
                off = ((yy - y0) % 4) - 1
                sx = max(x0, min(x1, bx + (1 if off == 1 else 0)))
                c.px(sx, yy, "cream" if (yy + f) % 3 == 0 else "ice")
                if sx + 1 <= x1:
                    c.px(sx + 1, yy, "sky")
        elif iid == 8:
            # Gothic spire-iron grate with lancet arch cusps
            c.vline(bx, y0, y1, "plum")
            c.vline(bx + 1, y0, y1, "night")
            c.px(bx - 1, y0 + 1, "dusk")
            c.px(bx + 2, y0 + 1, "dusk")
            c.px(bx, ymid, "rose" if f == 1 else "wine")


def _paint_combat_seal(c: Canvas, t: IslandTheme, cx: int, cy: int, f: int) -> None:
    """Paint the pulsing combat-seal emblem centered at (cx, cy)."""
    c.rect(cx - 3, cy - 3, 6, 6, "void")
    c.box(cx - 2, cy - 2, 4, 4, t.sig_dk)
    c.rect(cx - 2, cy - 2, 4, 4, t.sig_mid if f == 0 else t.sig_hi)
    c.rect(cx - 1, cy - 1, 2, 2, t.sig_hi if f == 0 else t.sig_core)
    c.px(cx - 1, cy - 1, "cream" if f == 1 else t.sig_core)
    # Cardinal seal spikes
    c.px(cx, cy - 3, t.sig_hi if f == 1 else t.sig_mid)
    c.px(cx, cy + 3, t.sig_mid)
    c.px(cx - 3, cy, t.sig_hi if f == 1 else t.sig_mid)
    c.px(cx + 3, cy, t.sig_mid)


def draw_combat_gate_h(t: IslandTheme) -> list[Canvas]:
    """32x18, 2f, origin [16, 10]: Biome portcullis with pulsing combat-seal."""
    frames: list[Canvas] = []
    for f in range(2):
        c = Canvas(32, 18)
        c.rect(0, 1, 32, 17, t.out)
        # Top heavy gate header beam
        c.bevel_rect(0, 0, 32, 4, t.frame_mid, t.frame_rim, t.frame_dk, t.out)
        # Left & right stone/iron piers
        _paint_pier_block(c, t, 0, 3, 4, 15)
        _paint_pier_block(c, t, 28, 3, 4, 15)
        # Portcullis bars
        _paint_gate_bars_h(c, t, 4, 27, 4, 16, f)
        c.hline(4, 27, 17, t.out)
        # Central pulsing combat-seal emblem
        _paint_combat_seal(c, t, 16, 10, f)
        frames.append(c)
    return frames


def draw_combat_gate_v_cap(t: IslandTheme) -> list[Canvas]:
    """16x8, 1f, origin [8, 4]: Heavy vertical combat gate cap."""
    c = Canvas(16, 8)
    _paint_pier_block(c, t, 0, 0, 16, 8)
    # Bolted iron gate housing lip
    c.hline(2, 13, 6, t.trim_mid)
    c.px(3, 6, t.trim_hi)
    c.px(12, 6, t.trim_hi)
    return [c]


def draw_combat_gate_v_mid(t: IslandTheme) -> list[Canvas]:
    """16x16, 2f, origin [8, 8]: HORIZONTAL-BAR vertical-passage portcullis (NOT toothpicks!)."""
    frames: list[Canvas] = []
    iid = t.island_id
    for f in range(2):
        c = Canvas(16, 16)
        # Dark void background behind horizontal bars
        c.rect(0, 0, 16, 16, "void")
        # Heavy side channel jamb rails (x=0..2 and x=13..15)
        c.vline(0, 0, 15, t.out)
        c.vline(1, 0, 15, t.frame_rim)
        c.vline(2, 0, 15, t.frame_mid)
        c.vline(13, 0, 15, t.frame_mid)
        c.vline(14, 0, 15, t.frame_dk)
        c.vline(15, 0, 15, t.out)
        # Subtle vertical tie-rod behind the horizontal bars
        c.vline(7, 0, 15, t.frame_dk)
        c.vline(8, 0, 15, t.frame_mid)

        # Three sturdy HORIZONTAL bars spanning left-to-right (y=1..3, y=6..8, y=11..13)
        for by in (1, 6, 11):
            if iid == 1:
                c.hline(3, 12, by, "stone")
                c.hline(3, 12, by + 1, "mauve")
                c.hline(3, 12, by + 2, "dusk")
                c.px(7, by + 1, "gold" if f == 1 else "apricot")
            elif iid == 2:
                # Barbed harpoon horizontal spears
                c.hline(3, 12, by, "ice")
                c.hline(3, 12, by + 1, "sky")
                c.hline(3, 12, by + 2, "pine")
                c.px(5, by + 2, "teal"); c.px(10, by + 2, "teal")
                c.px(8, by, "cream" if f == 1 else "gold")
            elif iid == 3:
                # Twisted rose-thorn horizontal briars
                c.hline(3, 12, by, "lime" if by == 6 else "jade")
                c.hline(3, 12, by + 1, "teal")
                c.hline(3, 12, by + 2, "pine")
                c.px(5, by - 1, "rose" if f == 0 else "wine")
                c.px(10, by + 2, "rose" if f == 1 else "wine")
            elif iid == 4:
                # Wrought-iron horizontal scrollwork & diamond ribs
                c.hline(3, 12, by, "ice")
                c.hline(3, 12, by + 1, "teal")
                c.hline(3, 12, by + 2, "pine")
                c.px(6, by + 3 if by < 11 else by - 1, "sky")
                c.px(9, by + 3 if by < 11 else by - 1, "sky")
                c.px(7, by + 1, "rose" if f == 1 else "mauve")
            elif iid == 5:
                # Gilded meridian horizontal bars
                c.hline(3, 12, by, "sky")
                c.hline(3, 12, by + 1, "blue")
                c.hline(3, 12, by + 2, "deep")
                c.hline(6, 9, by, "gold" if f == 1 else "apricot")
                c.px(7, by + 1, "cream" if f == 1 else "gold")
            elif iid == 6:
                # Glowing forged horizontal iron chains (high-contrast hot links)
                for xx in range(3, 13):
                    if xx % 3 == 0:
                        c.px(xx, by, "stone"); c.px(xx, by + 1, "mauve"); c.px(xx, by + 2, "dusk")
                    elif xx % 3 == 1:
                        c.px(xx, by, "apricot" if f == 1 else "coral")
                        c.px(xx, by + 1, "gold" if f == 1 else "apricot")
                        c.px(xx, by + 2, "wine")
                    else:
                        c.px(xx, by, "mauve"); c.px(xx, by + 1, "stone"); c.px(xx, by + 2, "dusk")
            elif iid == 7:
                # Razor horizontal crystal-shard bars
                c.hline(3, 12, by, "cream" if f == 1 else "ice")
                c.hline(3, 12, by + 1, "sky")
                c.hline(4, 11, by + 2, "blue")
                c.px(5, by + 2, "ice"); c.px(10, by - 1 if by > 1 else by + 2, "cream")
            elif iid == 8:
                # Gothic cusped horizontal ironwork
                c.hline(3, 12, by, "plum")
                c.hline(3, 12, by + 1, "dusk")
                c.hline(3, 12, by + 2, "night")
                c.px(7, by, "gold" if f == 1 else "rose")
                c.px(8, by + 1, "wine")
                c.px(5, by + 2, "plum"); c.px(10, by + 2, "plum")
        frames.append(c)
    return frames


def draw_combat_gate_sq(t: IslandTheme) -> list[Canvas]:
    """16x16, 2f, origin [8, 8]: Square 16x16 biome portcullis with central combat seal."""
    frames: list[Canvas] = []
    for f in range(2):
        c = Canvas(16, 16)
        c.rect(0, 0, 16, 16, t.out)
        c.bevel_rect(0, 0, 16, 3, t.frame_mid, t.frame_rim, t.frame_dk, t.out)
        c.bevel_rect(0, 13, 16, 3, t.frame_mid, t.frame_hi, t.frame_dk, t.out)
        c.vline(1, 2, 13, t.frame_rim)
        c.vline(2, 2, 13, t.frame_mid)
        c.vline(13, 2, 13, t.frame_mid)
        c.vline(14, 2, 13, t.frame_dk)
        _paint_gate_bars_h(c, t, 3, 12, 3, 12, f)
        _paint_combat_seal(c, t, 8, 8, f)
        frames.append(c)
    return frames


def _paint_ward_pylon(c: Canvas, t: IslandTheme, x: int, y: int, w: int, h: int, f: int) -> None:
    """Paint a sculpted biome ward pylon with glowing top crystal/finial."""
    _paint_pier_block(c, t, x, y + 3, w, h - 3)
    cx = x + w // 2
    # Glowing biome ward finial on top of pylon
    c.rect(cx - 2, y, 4, 4, t.out)
    c.rect(cx - 1, y + 1, 2, 2, t.ward_hi if f % 2 == 0 else t.ward_core)
    c.px(cx - 1, y + 1, "cream" if f in (0, 2) else t.ward_core)
    c.px(cx, y, t.ward_hi)


def draw_ward_barrier_h(t: IslandTheme) -> list[Canvas]:
    """32x20, 4f, origin [16, 12]: Twin biome pylons + shimmering rune energy curtain."""
    frames: list[Canvas] = []
    for f in range(4):
        c = Canvas(32, 20)
        # Shimmering translucent-look dithered energy veil between x=5..26, y=3..18
        for yy in range(4, 18):
            for xx in range(5, 27):
                wave = (xx + yy * 2 + f * 2) % 6
                if yy in (4, 17):
                    c.px(xx, yy, t.ward_hi if (xx + f) % 2 == 0 else t.ward_mid)
                elif wave == 0:
                    c.px(xx, yy, t.ward_core if (xx + yy) % 2 == 0 else t.ward_hi)
                elif wave in (1, 2) and ((xx + yy + f) & 1) == 0:
                    c.px(xx, yy, t.ward_mid)
                elif wave == 3 and ((xx + yy) & 1) == 1:
                    c.px(xx, yy, t.ward_dk)
        # Central floating rune diamond crest
        cx, cy = 16, 11
        bob = (0, -1, 0, 1)[f]
        for dy in range(-3, 4):
            span = 3 - abs(dy)
            for dx in range(-span, span + 1):
                if abs(dx) == span:
                    c.px(cx + dx, cy + dy + bob, t.ward_hi if dy <= 0 else t.ward_mid)
                elif abs(dx) <= 1 and abs(dy) <= 1:
                    c.px(cx + dx, cy + dy + bob, "cream" if f % 2 == 0 else t.ward_core)
                else:
                    c.px(cx + dx, cy + dy + bob, t.ward_core if dy < 0 else t.ward_hi)
        # Sparkling edge motes
        c.px(8 + f * 4, 6 + (f % 3), "cream")
        c.px(23 - f * 4, 14 - (f % 3), t.ward_core)
        # Twin sculpted biome pylons flanking the curtain
        _paint_ward_pylon(c, t, 0, 1, 6, 19, f)
        _paint_ward_pylon(c, t, 26, 1, 6, 19, f)
        frames.append(c)
    return frames


def draw_ward_barrier_v_cap(t: IslandTheme) -> list[Canvas]:
    """16x8, 1f, origin [8, 4]: Vertical ward pylon cap."""
    c = Canvas(16, 8)
    _paint_pier_block(c, t, 1, 0, 14, 8)
    # Glowing ward emitter jewel centered in cap
    c.rect(5, 2, 6, 4, t.out)
    c.rect(6, 3, 4, 2, t.ward_hi)
    c.px(7, 3, "cream")
    c.px(8, 3, t.ward_core)
    return [c]


def draw_ward_barrier_v_mid(t: IslandTheme) -> list[Canvas]:
    """16x16, 4f, origin [8, 8]: Vertical shimmering rune energy curtain."""
    frames: list[Canvas] = []
    for f in range(4):
        c = Canvas(16, 16)
        # Glowing vertical energy edge-rails at x=2..3 and x=12..13
        for yy in range(16):
            pulse = (yy + f * 2) % 4
            c.px(2, yy, t.ward_hi if pulse < 2 else t.ward_mid)
            c.px(13, yy, t.ward_hi if pulse >= 2 else t.ward_mid)
            c.px(3, yy, t.ward_dk)
            c.px(12, yy, t.ward_dk)
            for xx in range(4, 12):
                wave = (yy + abs(xx - 7) + f * 2) % 6
                if wave == 0:
                    c.px(xx, yy, t.ward_core if ((xx + yy) & 1) == 0 else t.ward_hi)
                elif wave in (1, 2) and ((xx + yy + f) & 1) == 0:
                    c.px(xx, yy, t.ward_mid)
                elif wave == 3 and ((xx + yy) & 1) == 1:
                    c.px(xx, yy, t.ward_dk)
        # Rising diamond glyph in center
        ry = (4 + f * 3) % 12 + 2
        c.px(7, ry, "cream"); c.px(8, ry, "cream")
        c.px(7, ry - 1, t.ward_core); c.px(8, ry + 1, t.ward_hi)
        c.px(6, ry, t.ward_hi); c.px(9, ry, t.ward_hi)
        frames.append(c)
    return frames


def draw_light_bridge_h(t: IslandTheme) -> list[Canvas]:
    """32x16, 4f, origin [16, 8]: Luminous horizontal energy causeway."""
    frames: list[Canvas] = []
    for f in range(4):
        c = Canvas(32, 16)
        # Luminous outer borders top & bottom
        c.hline(0, 31, 1, t.ward_dk)
        c.hline(0, 31, 2, t.ward_hi)
        c.hline(0, 31, 13, t.ward_hi)
        c.hline(0, 31, 14, t.ward_dk)
        # Glowing causeway deck (y=3..12) with animated chevron ripples
        for yy in range(3, 13):
            for xx in range(32):
                chev = (xx + abs(yy - 7) - f * 2) % 8
                if chev == 0:
                    c.px(xx, yy, "cream" if 5 <= yy <= 10 else t.ward_core)
                elif chev in (1, 2):
                    c.px(xx, yy, t.ward_hi)
                elif chev in (3, 4):
                    c.px(xx, yy, t.ward_mid)
                else:
                    if ((xx + yy) & 1) == 0:
                        c.px(xx, yy, t.ward_dk)
                    else:
                        c.px(xx, yy, t.ward_mid)
        # Rail light studs
        for sx in range((f * 2) % 8, 32, 8):
            c.px(sx, 2, "cream")
            c.px(sx, 13, "cream")
        frames.append(c)
    return frames


def draw_light_bridge_v(t: IslandTheme) -> list[Canvas]:
    """16x16, 4f, origin [8, 8]: Luminous vertical energy causeway."""
    frames: list[Canvas] = []
    for f in range(4):
        c = Canvas(16, 16)
        c.vline(1, 0, 15, t.ward_dk)
        c.vline(2, 0, 15, t.ward_hi)
        c.vline(13, 0, 15, t.ward_hi)
        c.vline(14, 0, 15, t.ward_dk)
        for yy in range(16):
            for xx in range(3, 13):
                chev = (yy + abs(xx - 7) - f * 2) % 8
                if chev == 0:
                    c.px(xx, yy, "cream" if 5 <= xx <= 10 else t.ward_core)
                elif chev in (1, 2):
                    c.px(xx, yy, t.ward_hi)
                elif chev in (3, 4):
                    c.px(xx, yy, t.ward_mid)
                else:
                    c.px(xx, yy, t.ward_dk if ((xx + yy) & 1) == 0 else t.ward_mid)
        for sy in range((f * 2) % 8, 16, 8):
            c.px(2, sy, "cream")
            c.px(13, sy, "cream")
        frames.append(c)
    return frames


def draw_bridge_tile(t: IslandTheme) -> list[Canvas]:
    """16x16, 1f, origin [8, 8]: Seamlessly tiling biome footbridge planks / flagstones."""
    c = Canvas(16, 16)
    iid = t.island_id
    c.rect(0, 0, 16, 16, t.br_mid)
    # Top & bottom deck curb edges
    c.hline(0, 15, 0, t.out)
    c.hline(0, 15, 1, t.br_rim)
    c.hline(0, 15, 14, t.br_dk)
    c.hline(0, 15, 15, t.out)

    if iid in (2, 3):
        # Vertical timber planks (maritime teak dock / forest log bridge)
        for xx in range(16):
            if xx % 4 == 0:
                c.vline(xx, 2, 13, t.br_dk)
            elif xx % 4 == 1:
                c.vline(xx, 2, 13, t.br_hi)
            else:
                c.vline(xx, 2, 13, t.br_mid)
        # Plank nails or vine lashings
        for xx in (2, 6, 10, 14):
            c.px(xx, 3, t.br_rim if iid == 2 else "lime")
            c.px(xx, 12, t.trim_dk if iid == 2 else "jade")
    elif iid in (1, 4, 8):
        # Cut stone / slate / cathedral nave flagstones
        for yy in range(2, 14):
            for xx in range(16):
                row = (yy - 2) // 4
                if (yy - 2) % 4 == 0 or (xx + row * 4) % 8 == 0:
                    c.px(xx, yy, t.br_dk)
                elif (yy - 2) % 4 == 1:
                    c.px(xx, yy, t.br_hi)
        if iid == 1:
            c.px(3, 6, "jade"); c.px(12, 10, "jade")
        elif iid == 4:
            c.hline(0, 15, 7, "ice")
        elif iid == 8:
            # Crimson & gold cathedral runner stripe
            c.hline(0, 15, 7, "wine"); c.hline(0, 15, 8, "wine")
            for xx in range(2, 16, 4):
                c.px(xx, 7, "gold"); c.px(xx + 1, 8, "rose")
    elif iid == 5:
        # Cobalt observatory marble inlaid with brass meridian track
        c.rect(0, 2, 16, 12, "deep")
        for xx in (0, 8):
            c.vline(xx, 2, 13, "night")
            c.vline(xx + 1, 2, 13, "blue")
        c.hline(0, 15, 7, "gold"); c.hline(0, 15, 8, "apricot")
        c.px(4, 7, "cream"); c.px(12, 7, "cream")
    elif iid == 6:
        # Riveted foundry iron grate with glowing ember seams underneath
        c.rect(0, 2, 16, 12, "night")
        for yy in range(3, 13, 3):
            c.hline(0, 15, yy, "dusk")
            for xx in range(2, 15, 4):
                c.px(xx, yy + 1, "coral" if (xx + yy) % 2 == 0 else "wine")
                c.px(xx + 1, yy, "mauve")
    elif iid == 7:
        # Polished mirror-glass stepping deck with diagonal ice gleams
        c.rect(0, 2, 16, 12, "blue")
        for yy in range(2, 14):
            for xx in range(16):
                d = (xx + yy) % 8
                if d == 0:
                    c.px(xx, yy, "cream")
                elif d in (1, 2):
                    c.px(xx, yy, "ice")
                elif d == 3:
                    c.px(xx, yy, "sky")
        c.hline(0, 15, 2, "mauve")
        c.hline(0, 15, 13, "mauve")
    return [c]


def draw_bridge_cap_h(t: IslandTheme) -> list[Canvas]:
    """8x16, 1f, origin [4, 8]: Biome bridge abutment pier (horizontal ends)."""
    c = Canvas(8, 16)
    _paint_pier_block(c, t, 0, 0, 8, 16)
    # Corner mooring bollards top & bottom
    for by in (1, 12):
        c.rect(2, by, 4, 3, t.out)
        c.rect(3, by + 1, 2, 1, t.br_rim)
    c.rect(3, 6, 2, 4, t.trim_mid)
    c.px(3, 6, t.trim_hi)
    return [c]


def draw_bridge_cap_v(t: IslandTheme) -> list[Canvas]:
    """16x8, 1f, origin [8, 4]: Biome bridge abutment pier (vertical ends)."""
    c = Canvas(16, 8)
    _paint_pier_block(c, t, 0, 0, 16, 8)
    for bx in (1, 12):
        c.rect(bx, 2, 3, 4, t.out)
        c.rect(bx + 1, 3, 1, 2, t.br_rim)
    c.rect(6, 3, 4, 2, t.trim_mid)
    c.px(6, 3, t.trim_hi)
    return [c]


def draw_opened_jamb_h(t: IslandTheme) -> list[Canvas]:
    """32x18, 1f, origin [16, 10]: Recessed left & right biome arch jambs, transparent center."""
    c = Canvas(32, 18)
    # Left & right recessed arch jamb piers (transparent walkable center x=6..25!)
    _paint_pier_block(c, t, 0, 1, 6, 17)
    _paint_pier_block(c, t, 26, 1, 6, 17)
    # Subtle sculpted arch shoulder stubs pointing inward at top
    c.rect(5, 1, 2, 3, t.frame_mid)
    c.px(5, 1, t.frame_rim); c.px(6, 1, t.out); c.px(6, 2, t.frame_hi)
    c.rect(25, 1, 2, 3, t.frame_mid)
    c.px(25, 1, t.out); c.px(26, 1, t.frame_hi); c.px(25, 2, t.frame_dk)
    # Subtle stepped floor threshold marks at bottom left/right edges (center stays clean!)
    c.hline(6, 9, 16, t.frame_dk)
    c.hline(6, 8, 15, t.frame_mid)
    c.hline(22, 25, 16, t.frame_dk)
    c.hline(23, 25, 15, t.frame_mid)
    return [c]


def draw_opened_jamb_v_top(t: IslandTheme) -> list[Canvas]:
    """16x8, 1f, origin [8, 4]: Recessed top arch stub when vertical doors open."""
    c = Canvas(16, 8)
    _paint_pier_block(c, t, 0, 0, 16, 6)
    # Open inward-facing threshold corners on bottom (center x=4..11 transparent!)
    c.rect(0, 5, 4, 3, t.out)
    c.rect(1, 5, 2, 2, t.frame_mid)
    c.rect(12, 5, 4, 3, t.out)
    c.rect(13, 5, 2, 2, t.frame_dk)
    return [c]


def draw_opened_jamb_v_bot(t: IslandTheme) -> list[Canvas]:
    """16x8, 1f, origin [8, 4]: Recessed bottom arch stub when vertical doors open."""
    c = Canvas(16, 8)
    _paint_pier_block(c, t, 0, 2, 16, 6)
    # Open inward-facing threshold corners on top (center x=4..11 transparent!)
    c.rect(0, 0, 4, 3, t.out)
    c.rect(1, 1, 2, 2, t.frame_hi)
    c.rect(12, 0, 4, 3, t.out)
    c.rect(13, 1, 2, 2, t.frame_mid)
    return [c]


# ---------------------------------------------------------------------------
# Canonical Door Atlas Specification (22 modular keys)
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class SpriteSpec:
    key: str
    w: int
    h: int
    origin: tuple[int, int]
    ms: tuple[float, ...]
    draw_fn: Callable[[IslandTheme], list[Canvas]]


SPRITE_SPECS: list[SpriteSpec] = [
    SpriteSpec("wick_key_h", 32, 20, (16, 12), (1000.0,), draw_wick_key_h),
    SpriteSpec("wick_key_v", 16, 48, (8, 24), (1000.0,), draw_wick_key_v),
    SpriteSpec("boss_key_h", 36, 24, (18, 16), (160.0, 160.0, 160.0, 160.0), draw_boss_key_h),
    SpriteSpec("switch_door_h", 32, 18, (16, 10), (420.0, 420.0), draw_switch_door_h),
    SpriteSpec("switch_door_v_cap", 16, 8, (8, 4), (1000.0,), draw_switch_door_v_cap),
    SpriteSpec("switch_door_v_mid", 16, 16, (8, 8), (420.0, 420.0), draw_switch_door_v_mid),
    SpriteSpec("switch_door_v_seal", 16, 16, (8, 8), (420.0, 420.0), draw_switch_door_v_seal),
    SpriteSpec("combat_gate_h", 32, 18, (16, 10), (320.0, 320.0), draw_combat_gate_h),
    SpriteSpec("combat_gate_v_cap", 16, 8, (8, 4), (1000.0,), draw_combat_gate_v_cap),
    SpriteSpec("combat_gate_v_mid", 16, 16, (8, 8), (320.0, 320.0), draw_combat_gate_v_mid),
    SpriteSpec("combat_gate_sq", 16, 16, (8, 8), (320.0, 320.0), draw_combat_gate_sq),
    SpriteSpec("ward_barrier_h", 32, 20, (16, 12), (180.0, 180.0, 180.0, 180.0), draw_ward_barrier_h),
    SpriteSpec("ward_barrier_v_cap", 16, 8, (8, 4), (1000.0,), draw_ward_barrier_v_cap),
    SpriteSpec("ward_barrier_v_mid", 16, 16, (8, 8), (180.0, 180.0, 180.0, 180.0), draw_ward_barrier_v_mid),
    SpriteSpec("light_bridge_h", 32, 16, (16, 8), (200.0, 200.0, 200.0, 200.0), draw_light_bridge_h),
    SpriteSpec("light_bridge_v", 16, 16, (8, 8), (200.0, 200.0, 200.0, 200.0), draw_light_bridge_v),
    SpriteSpec("bridge_tile", 16, 16, (8, 8), (1000.0,), draw_bridge_tile),
    SpriteSpec("bridge_cap_h", 8, 16, (4, 8), (1000.0,), draw_bridge_cap_h),
    SpriteSpec("bridge_cap_v", 16, 8, (8, 4), (1000.0,), draw_bridge_cap_v),
    SpriteSpec("opened_jamb_h", 32, 18, (16, 10), (1000.0,), draw_opened_jamb_h),
    SpriteSpec("opened_jamb_v_top", 16, 8, (8, 4), (1000.0,), draw_opened_jamb_v_top),
    SpriteSpec("opened_jamb_v_bot", 16, 8, (8, 4), (1000.0,), draw_opened_jamb_v_bot),
]


def verify_palette(img: Image.Image, label: str) -> None:
    """Strictly verify 0 off-palette opaque pixels and 0 semi-transparent pixels."""
    rgba = img.convert("RGBA")
    pixels = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    for r, g, b, a in pixels:
        if a == 0:
            continue
        if a != 255:
            raise AssertionError(f"{label}: semi-transparent pixel rgba({r},{g},{b},{a})")
        if (r, g, b) not in ALLOWED_RGB:
            raise AssertionError(f"{label}: off-palette pixel #{r:02x}{g:02x}{b:02x}")


def build_island_atlas(island_id: int) -> tuple[Path, Path, dict[str, list[Canvas]]]:
    theme = THEMES[island_id]
    rendered: dict[str, list[Canvas]] = {}
    sheet_w = 0
    sheet_h = 0
    for spec in SPRITE_SPECS:
        frames = spec.draw_fn(theme)
        if len(frames) != len(spec.ms):
            raise AssertionError(f"Island {island_id} {spec.key}: expected {len(spec.ms)} frames, got {len(frames)}")
        for fc in frames:
            if (fc.w, fc.h) != (spec.w, spec.h):
                raise AssertionError(f"Island {island_id} {spec.key}: expected {spec.w}x{spec.h}, got {fc.w}x{fc.h}")
        rendered[spec.key] = frames
        sheet_w = max(sheet_w, spec.w * len(frames))
        sheet_h += spec.h

    atlas = Image.new("RGBA", (sheet_w, sheet_h), TRANSPARENT)
    props_meta: dict[str, dict[str, object]] = {}
    y_cursor = 0
    for spec in SPRITE_SPECS:
        frames = rendered[spec.key]
        rects: list[list[int]] = []
        for idx, fc in enumerate(frames):
            x_cursor = idx * spec.w
            atlas.paste(fc.img, (x_cursor, y_cursor))
            rects.append([x_cursor, y_cursor, spec.w, spec.h])
        props_meta[spec.key] = {
            "frame": [spec.w, spec.h],
            "anchor": [spec.origin[0], spec.origin[1]],
            "origin": [spec.origin[0], spec.origin[1]],
            "frames": len(frames),
            "ms": list(spec.ms),
            "loop": True,
            "rects": rects,
        }
        y_cursor += spec.h

    png_name = f"island{island_id}_doors.png"
    json_name = f"island{island_id}_doors.json"
    png_path = OUT_DIR / png_name
    json_path = OUT_DIR / json_name

    verify_palette(atlas, png_name)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    atlas.save(png_path, format="PNG")

    meta = {
        "id": f"island{island_id}_doors",
        "name": f"{theme.name} Doors & Gates",
        "version": 1,
        "palette": PAL,
        "sheet": png_name,
        "image": png_name,
        "sheet_size": [sheet_w, sheet_h],
        "props": props_meta,
    }
    json_path.write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    return png_path, json_path, rendered


def write_preview_sheet(all_rendered: dict[int, dict[str, list[Canvas]]], out_path: Path, scale: int = 3) -> None:
    """Write an upscaled contact sheet comparing all 8 islands side-by-side."""
    keys = [
        "wick_key_h",
        "boss_key_h",
        "switch_door_h",
        "combat_gate_h",
        "ward_barrier_h",
        "opened_jamb_h",
        "wick_key_v",
        "combat_gate_v_mid",
        "switch_door_v_seal",
        "bridge_tile",
    ]
    col_widths = [40, 44, 40, 40, 40, 40, 24, 24, 24, 24]
    row_h = 54
    pad = 6
    total_w = pad + sum(col_widths) + pad
    total_h = pad + row_h * 8 + pad
    sheet = Image.new("RGBA", (total_w, total_h), RGBA["void"])
    for idx, iid in enumerate(range(1, 9)):
        ry = pad + idx * row_h
        # Alternating subtle dark strip background for contrast
        bg_c = RGBA["night"] if idx % 2 == 0 else RGBA["void"]
        for yy in range(ry, ry + row_h - 2):
            for xx in range(pad, total_w - pad):
                sheet.putpixel((xx, yy), bg_c)
        x_cur = pad
        for k, cw in zip(keys, col_widths):
            fc = all_rendered[iid][k][0]
            px = x_cur + (cw - fc.w) // 2
            py = ry + (row_h - 2 - fc.h) // 2
            sheet.alpha_composite(fc.img, (px, py))
            x_cur += cw
    upscaled = sheet.resize((total_w * scale, total_h * scale), Image.Resampling.NEAREST)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    upscaled.save(out_path, format="PNG")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build 8-island bespoke Luxel door sprite atlases.")
    parser.add_argument("--preview", type=Path, default=None, help="Optional upscaled preview strip PNG path.")
    args = parser.parse_args()

    all_rendered: dict[int, dict[str, list[Canvas]]] = {}
    for iid in range(1, 9):
        png_path, json_path, rendered = build_island_atlas(iid)
        all_rendered[iid] = rendered
        print(f"Built {png_path.name} + {json_path.name} ({len(SPRITE_SPECS)} keys, palette verified)")

    if args.preview is not None:
        write_preview_sheet(all_rendered, args.preview)
        print(f"Wrote preview strip: {args.preview}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
