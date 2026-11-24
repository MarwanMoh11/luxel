#!/usr/bin/env python3
"""Luxel Epic Creature Art Kit (`tools/epic/creature.py`).

Deterministic pixel-rig library locked strictly to the 20 Last Light colours.
Features:
- Dithering-free 3-tone/4-tone WNW shading primitives (ellipse, dome, rect, poly,
  capsule, bezier_limb, crescent, ring, eye, chain, crack, flame, slash_arc, star4)
- WNW rim light (warm or cool) + 1 px Last Light selective lit-side outline
- Grounded contact shadow, nearest-neighbor squash/stretch & rotation
- Keyframed parts (KeyframeTrack) with easing + hierarchical Rig with secondary-motion lag
- Separate wear (pre-outline) and glow/FX (post-outline, front & back) layers
- Exact LxSpriteSheet PNG + JSON exporter matching luxel/enemies/brain.gd animations
- Labelled contact-sheet PNG, 1x readability strip, animated GIF, and side-by-side comparison sheets

Run with:
  uv run --no-project --with pillow python <script.py>
"""
from __future__ import annotations

import json
import math
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parents[2]
ART_ENEMIES = REPO_ROOT / "luxel" / "art" / "enemies"
ART_BOSSES = REPO_ROOT / "luxel" / "art" / "bosses"
CACHE_DIR = REPO_ROOT / ".swarm" / "cache"
WICK_PNG = REPO_ROOT / "luxel" / "art" / "wick" / "wick.png"

# Strict 20-colour Last Light palette (source of truth: docs/art_concepts/lastlight/core.py)
PAL: dict[str, str] = {
    "void": "#0d0b1e", "night": "#211a3b", "dusk": "#3d2c5c", "plum": "#6a3d6f",
    "wine": "#a0466a", "coral": "#e2725b", "apricot": "#f5a96a", "gold": "#ffd98c",
    "cream": "#fff4dc", "pine": "#1d3d4c", "teal": "#2b6b68", "jade": "#4c9e78",
    "lime": "#a3cf7d", "deep": "#263873", "blue": "#3e6db0", "sky": "#78a9da",
    "ice": "#c7e5ef", "mauve": "#8a6e91", "stone": "#c2a7ae", "rose": "#ec9fa8",
}
RGB: dict[str, tuple[int, int, int]] = {
    k: (int(v[1:3], 16), int(v[3:5], 16), int(v[5:7], 16)) for k, v in PAL.items()
}
RGBA: dict[str, tuple[int, int, int, int]] = {k: v + (255,) for k, v in RGB.items()}
ALLOWED_RGB: set[tuple[int, int, int]] = set(RGB.values())

# Selective outline shade step (1 step darker on sunlit side)
SHADE: dict[str, str] = {
    "void": "void", "night": "void", "dusk": "night", "plum": "dusk", "wine": "plum",
    "coral": "wine", "apricot": "coral", "gold": "apricot", "cream": "stone",
    "pine": "night", "teal": "pine", "jade": "teal", "lime": "jade",
    "deep": "night", "blue": "deep", "sky": "blue", "ice": "sky",
    "mauve": "dusk", "stone": "mauve", "rose": "wine",
}
# Warm WNW rim light step (1 step lighter)
LIGHT: dict[str, str] = {
    "void": "night", "night": "dusk", "dusk": "plum", "plum": "wine", "wine": "coral",
    "coral": "apricot", "apricot": "gold", "gold": "cream", "cream": "cream",
    "pine": "teal", "teal": "jade", "jade": "lime", "lime": "gold",
    "deep": "blue", "blue": "sky", "sky": "ice", "ice": "cream",
    "mauve": "stone", "stone": "cream", "rose": "cream",
}
# Cool moonlight rim step (for Tidewater / Starfall / Moon Shoals)
COOL: dict[str, str] = {
    "void": "night", "night": "deep", "dusk": "deep", "plum": "mauve", "wine": "mauve",
    "coral": "rose", "apricot": "stone", "gold": "cream", "cream": "ice",
    "pine": "teal", "teal": "sky", "jade": "sky", "lime": "ice",
    "deep": "blue", "blue": "sky", "sky": "ice", "ice": "cream",
    "mauve": "sky", "stone": "ice", "rose": "ice",
}

# Material 3-tone / 4-tone ramps (dark -> mid -> light [-> spec])
RAMPS: dict[str, tuple[str, ...]] = {
    "stone": ("dusk", "mauve", "stone"),
    "slate": ("night", "dusk", "mauve", "stone"),
    "earth": ("night", "dusk", "plum", "mauve"),
    "wood": ("night", "plum", "wine", "coral"),
    "foliage": ("pine", "teal", "jade", "lime"),
    "hedge": ("night", "pine", "teal", "jade"),
    "sea": ("deep", "blue", "sky", "ice"),
    "glass": ("deep", "blue", "sky", "ice", "cream"),
    "brass": ("plum", "coral", "apricot", "gold"),
    "gold": ("wine", "apricot", "gold", "cream"),
    "ember": ("wine", "coral", "apricot", "gold"),
    "blossom": ("plum", "wine", "rose", "cream"),
    "cloak": ("night", "dusk", "plum", "wine"),
    "astral": ("night", "deep", "blue", "sky"),
    "basalt": ("void", "night", "dusk", "mauve"),
}

DIRS_3: tuple[str, ...] = ("front", "back", "side")
# WNW light vector (left-up-front)
LX, LY, LZ = -0.58, -0.56, 0.59

# Canonical animation schedules matching luxel/enemies/brain.gd (_STATE_ANIMS + phase2)
ENEMY_ANIMS: list[tuple[str, bool, list[float]]] = [
    ("routine", True, [150.0, 150.0, 150.0, 150.0, 150.0, 150.0]),
    ("tell", False, [85.0, 85.0, 85.0, 90.0, 95.0, 110.0]),
    ("commit", False, [60.0, 65.0, 70.0, 75.0, 85.0, 95.0]),
    ("recover", True, [190.0, 190.0, 190.0, 190.0]),
    ("stagger", True, [110.0, 110.0, 110.0, 110.0, 110.0, 110.0]),
]
BOSS_ANIMS: list[tuple[str, bool, list[float]]] = ENEMY_ANIMS + [
    ("phase2", True, [130.0, 130.0, 130.0, 130.0, 130.0, 130.0]),
]


# =============================================================================
# Easing & Keyframe Tracks
# =============================================================================
def ease(u: float, mode: str = "linear") -> float:
    u = max(0.0, min(1.0, u))
    if mode == "ease_in":
        return u * u
    if mode == "ease_out":
        return 1.0 - (1.0 - u) * (1.0 - u)
    if mode in ("ease_in_out", "smooth"):
        return u * u * (3.0 - 2.0 * u)
    if mode == "anticipation":
        return u * u * (2.7 * u - 1.7)
    if mode == "bounce":
        return math.sin(u * math.pi)
    if mode == "step":
        return 0.0 if u < 1.0 else 1.0
    return u


class KeyframeTrack:
    """Deterministic keyframed value track over normalized u in [0, 1]."""

    def __init__(self, keys: list[tuple[float, float, str]] | list[tuple[float, float]]):
        self.keys: list[tuple[float, float, str]] = []
        for k in keys:
            if len(k) == 2:
                self.keys.append((float(k[0]), float(k[1]), "smooth"))
            else:
                self.keys.append((float(k[0]), float(k[1]), str(k[2])))
        self.keys.sort(key=lambda item: item[0])

    def sample(self, u: float) -> float:
        if not self.keys:
            return 0.0
        u = max(0.0, min(1.0, u))
        if u <= self.keys[0][0]:
            return self.keys[0][1]
        for i in range(len(self.keys) - 1):
            t0, v0, mode = self.keys[i]
            t1, v1, _ = self.keys[i + 1]
            if u <= t1:
                span = max(1e-6, t1 - t0)
                return v0 + (v1 - v0) * ease((u - t0) / span, mode)
        return self.keys[-1][1]


def hash01(x: int, y: int, seed: int = 0) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 982451653) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def rot_pt(x: float, y: float, px: float, py: float, deg: float) -> tuple[float, float]:
    rad = math.radians(deg)
    ca, sa = math.cos(rad), math.sin(rad)
    dx, dy = x - px, y - py
    return px + dx * ca - dy * sa, py + dx * sa + dy * ca


def pick_tone(ramp: tuple[str, ...] | list[str], val: float) -> str:
    """Dithering-free crisp cel-shaded band selection along a dark-to-light ramp."""
    n = len(ramp)
    if n <= 1:
        return ramp[0]
    idx = int(max(0.0, min(0.9999, val)) * n)
    return ramp[idx]


# =============================================================================
# Fast Palette-Locked Pixel Buffer
# =============================================================================
class PixelBuf:
    """Fast 20-colour palette pixel surface with dithering-free 3-tone shading."""

    __slots__ = ("w", "h", "grid", "protect")

    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.grid: list[list[str | None]] = [[None] * w for _ in range(h)]
        self.protect: set[tuple[int, int]] = set()

    def copy(self) -> PixelBuf:
        b = PixelBuf(self.w, self.h)
        b.grid = [row[:] for row in self.grid]
        b.protect = set(self.protect)
        return b

    def set(self, x: float, y: float, col: str | None, protect: bool = False) -> None:
        ix, iy = int(round(x)), int(round(y))
        if 0 <= ix < self.w and 0 <= iy < self.h:
            self.grid[iy][ix] = col
            if col is None or not protect:
                self.protect.discard((ix, iy))
            else:
                self.protect.add((ix, iy))

    def get(self, x: float, y: float) -> str | None:
        ix, iy = int(round(x)), int(round(y))
        if 0 <= ix < self.w and 0 <= iy < self.h:
            return self.grid[iy][ix]
        return None

    def to_image(self) -> Image.Image:
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        px = im.load()
        rgba = RGBA
        grid = self.grid
        for y in range(self.h):
            row = grid[y]
            for x in range(self.w):
                c = row[x]
                if c is not None:
                    px[x, y] = rgba[c]
        return im

    def composite(self, other: PixelBuf, ox: int = 0, oy: int = 0) -> None:
        w, h = self.w, self.h
        grid = self.grid
        prot = self.protect
        oprot = other.protect
        for y in range(other.h):
            ty = y + oy
            if not (0 <= ty < h):
                continue
            orow = other.grid[y]
            trow = grid[ty]
            for x in range(other.w):
                c = orow[x]
                if c is not None:
                    tx = x + ox
                    if 0 <= tx < w:
                        trow[tx] = c
                        if (x, y) in oprot:
                            prot.add((tx, ty))
                        else:
                            prot.discard((tx, ty))

    # --- Basic & Shaded Primitives (tight bbox loops, zero dithering) --------

    def rect(self, x: float, y: float, w: float, h: float, col: str, protect: bool = False) -> None:
        x0 = max(0, int(round(x)))
        y0 = max(0, int(round(y)))
        x1 = min(self.w, int(round(x + w)))
        y1 = min(self.h, int(round(y + h)))
        grid = self.grid
        prot = self.protect
        for yy in range(y0, y1):
            row = grid[yy]
            for xx in range(x0, x1):
                row[xx] = col
                if protect:
                    prot.add((xx, yy))
                else:
                    prot.discard((xx, yy))

    def shaded_rect(
        self, x: float, y: float, w: float, h: float,
        ramp: tuple[str, ...] | list[str], protect: bool = False,
    ) -> None:
        """Beveled 3-tone plate/block (lit top-left edge, mid body, dark right-bottom)."""
        ix, iy = int(round(x)), int(round(y))
        iw, ih = max(1, int(round(w))), max(1, int(round(h)))
        dark = ramp[0]
        mid = ramp[len(ramp) // 2]
        lit = ramp[-1]
        self.rect(ix, iy, iw, ih, mid, protect=protect)
        if iw >= 2 and ih >= 2:
            self.rect(ix, iy, iw - 1, 1, lit, protect=protect)
            self.rect(ix, iy, 1, ih - 1, lit, protect=protect)
            self.rect(ix + 1, iy + ih - 1, iw - 1, 1, dark, protect=protect)
            self.rect(ix + iw - 1, iy + 1, 1, ih - 1, dark, protect=protect)

    def circle(self, cx: float, cy: float, r: float, col: str, protect: bool = False) -> None:
        if r <= 0.3:
            self.set(cx, cy, col, protect=protect)
            return
        r2 = r * r
        x0 = max(0, math.floor(cx - r))
        x1 = min(self.w, math.ceil(cx + r) + 1)
        y0 = max(0, math.floor(cy - r))
        y1 = min(self.h, math.ceil(cy + r) + 1)
        grid = self.grid
        prot = self.protect
        for yy in range(y0, y1):
            dy = (yy + 0.5) - cy
            dy2 = dy * dy
            row = grid[yy]
            for xx in range(x0, x1):
                dx = (xx + 0.5) - cx
                if dx * dx + dy2 <= r2:
                    row[xx] = col
                    if protect:
                        prot.add((xx, yy))
                    else:
                        prot.discard((xx, yy))

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, col: str, protect: bool = False) -> None:
        if rx <= 0.35 or ry <= 0.35:
            self.set(cx, cy, col, protect=protect)
            return
        inv_x, inv_y = 1.0 / rx, 1.0 / ry
        x0 = max(0, math.floor(cx - rx))
        x1 = min(self.w, math.ceil(cx + rx) + 1)
        y0 = max(0, math.floor(cy - ry))
        y1 = min(self.h, math.ceil(cy + ry) + 1)
        grid = self.grid
        prot = self.protect
        for yy in range(y0, y1):
            ny = ((yy + 0.5) - cy) * inv_y
            ny2 = ny * ny
            row = grid[yy]
            for xx in range(x0, x1):
                nx = ((xx + 0.5) - cx) * inv_x
                if nx * nx + ny2 <= 1.0:
                    row[xx] = col
                    if protect:
                        prot.add((xx, yy))
                    else:
                        prot.discard((xx, yy))

    def shaded_ellipse(
        self, cx: float, cy: float, rx: float, ry: float,
        ramp: tuple[str, ...] | list[str], bias: float = 0.0,
        spec_col: str | None = None, protect: bool = False,
    ) -> None:
        """Dithering-free 3D ellipsoidal form shaded from WNW light."""
        if rx <= 0.4 or ry <= 0.4:
            self.set(cx, cy, ramp[-1], protect=protect)
            return
        inv_x, inv_y = 1.0 / rx, 1.0 / ry
        x0 = max(0, math.floor(cx - rx))
        x1 = min(self.w, math.ceil(cx + rx) + 1)
        y0 = max(0, math.floor(cy - ry))
        y1 = min(self.h, math.ceil(cy + ry) + 1)
        grid = self.grid
        prot = self.protect
        n = len(ramp)
        lx, ly, lz = LX, LY, LZ
        for yy in range(y0, y1):
            ny = ((yy + 0.5) - cy) * inv_y
            ny2 = ny * ny
            row = grid[yy]
            for xx in range(x0, x1):
                nx = ((xx + 0.5) - cx) * inv_x
                r2 = nx * nx + ny2
                if r2 > 1.0:
                    continue
                nz = math.sqrt(1.0 - r2)
                ndotl = nx * lx + ny * ly + nz * lz
                if spec_col is not None and ndotl > 0.87:
                    col = spec_col
                else:
                    val = max(0.0, min(0.999, 0.46 + 0.56 * ndotl + bias))
                    col = ramp[int(val * n)]
                row[xx] = col
                if protect:
                    prot.add((xx, yy))
                else:
                    prot.discard((xx, yy))

    def shaded_dome(
        self, cx: float, cy: float, rx: float, ry: float,
        ramp: tuple[str, ...] | list[str], bottom_cut: float = 0.15,
        bias: float = 0.0, spec_col: str | None = None, protect: bool = False,
    ) -> None:
        """Upper dome/shell/helmet/carapace clipped cleanly at cy + ry*bottom_cut."""
        if rx <= 0.4 or ry <= 0.4:
            return
        inv_x, inv_y = 1.0 / rx, 1.0 / ry
        x0 = max(0, math.floor(cx - rx))
        x1 = min(self.w, math.ceil(cx + rx) + 1)
        y0 = max(0, math.floor(cy - ry))
        y1 = min(self.h, math.ceil(cy + ry * bottom_cut) + 1)
        grid = self.grid
        prot = self.protect
        n = len(ramp)
        lx, ly, lz = LX, LY, LZ
        for yy in range(y0, y1):
            ny = ((yy + 0.5) - cy) * inv_y
            ny2 = ny * ny
            row = grid[yy]
            for xx in range(x0, x1):
                nx = ((xx + 0.5) - cx) * inv_x
                r2 = nx * nx + ny2
                if r2 > 1.0:
                    continue
                nz = math.sqrt(1.0 - r2)
                ndotl = nx * lx + ny * ly + nz * lz
                if spec_col is not None and ndotl > 0.86:
                    col = spec_col
                else:
                    val = max(0.0, min(0.999, 0.48 + 0.56 * ndotl + bias))
                    col = ramp[int(val * n)]
                row[xx] = col
                if protect:
                    prot.add((xx, yy))
                else:
                    prot.discard((xx, yy))

    def poly(self, pts: list[tuple[float, float]], col: str, protect: bool = False) -> None:
        if len(pts) < 3:
            return
        tmp = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(tmp).polygon([(round(x), round(y)) for x, y in pts], fill=255)
        px = tmp.load()
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0 = max(0, math.floor(min(xs)))
        x1 = min(self.w, math.ceil(max(xs)) + 1)
        y0 = max(0, math.floor(min(ys)))
        y1 = min(self.h, math.ceil(max(ys)) + 1)
        grid = self.grid
        prot = self.protect
        for y in range(y0, y1):
            row = grid[y]
            for x in range(x0, x1):
                if px[x, y]:
                    row[x] = col
                    if protect:
                        prot.add((x, y))
                    else:
                        prot.discard((x, y))

    def shaded_poly(
        self, pts: list[tuple[float, float]], ramp: tuple[str, ...] | list[str],
        bias: float = 0.0, protect: bool = False,
    ) -> None:
        """Dithering-free WNW 3-tone directional polygon (great for capes, crystals, shields, wings)."""
        if len(pts) < 3:
            return
        tmp = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(tmp).polygon([(round(x), round(y)) for x, y in pts], fill=255)
        px = tmp.load()
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)
        mx = 0.5 * (min_x + max_x)
        my = 0.5 * (min_y + max_y)
        sc = max(2.5, 0.55 * max(max_x - min_x, max_y - min_y))
        x0 = max(0, math.floor(min_x))
        x1 = min(self.w, math.ceil(max_x) + 1)
        y0 = max(0, math.floor(min_y))
        y1 = min(self.h, math.ceil(max_y) + 1)
        grid = self.grid
        prot = self.protect
        n = len(ramp)
        for y in range(y0, y1):
            ny = (y - my) / sc
            row = grid[y]
            for x in range(x0, x1):
                if px[x, y]:
                    nx = (x - mx) / sc
                    val = max(0.0, min(0.999, 0.54 - 0.36 * nx - 0.34 * ny + bias))
                    row[x] = ramp[int(val * n)]
                    if protect:
                        prot.add((x, y))
                    else:
                        prot.discard((x, y))

    def line(self, x0: float, y0: float, x1: float, y1: float, col: str, protect: bool = False) -> None:
        ix0, iy0 = int(round(x0)), int(round(y0))
        ix1, iy1 = int(round(x1)), int(round(y1))
        dx, dy = abs(ix1 - ix0), -abs(iy1 - iy0)
        sx = 1 if ix0 < ix1 else -1
        sy = 1 if iy0 < iy1 else -1
        err = dx + dy
        while True:
            self.set(ix0, iy0, col, protect=protect)
            if ix0 == ix1 and iy0 == iy1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                ix0 += sx
            if e2 <= dx:
                err += dx
                iy0 += sy

    def capsule(
        self, x0: float, y0: float, x1: float, y1: float, r0: float, r1: float,
        ramp: tuple[str, ...] | list[str] | str, protect: bool = False,
    ) -> None:
        """Tapered limb/shaft with crisp 2/3-tone WNW shading."""
        cols = (ramp,) if isinstance(ramp, str) else tuple(ramp)
        dist = math.hypot(x1 - x0, y1 - y0)
        steps = max(2, int(dist * 1.8) + 1)
        dark = cols[0]
        mid = cols[len(cols) // 2]
        lit = cols[-1]
        for i in range(steps + 1):
            t = i / steps
            px = x0 + (x1 - x0) * t
            py = y0 + (y1 - y0) * t
            r = r0 + (r1 - r0) * t
            self.circle(px, py, r, dark, protect=protect)
        if len(cols) >= 2:
            for i in range(steps + 1):
                t = i / steps
                px = x0 + (x1 - x0) * t - 0.35
                py = y0 + (y1 - y0) * t - 0.45
                r = max(0.35, (r0 + (r1 - r0) * t) * 0.72)
                self.circle(px, py, r, mid, protect=protect)
        if len(cols) >= 3:
            for i in range(steps + 1):
                t = i / steps
                px = x0 + (x1 - x0) * t - 0.55
                py = y0 + (y1 - y0) * t - 0.65
                r = max(0.3, (r0 + (r1 - r0) * t) * 0.36)
                self.circle(px, py, r, lit, protect=protect)

    def bezier_limb(
        self, p0: tuple[float, float], p1: tuple[float, float], p2: tuple[float, float],
        r0: float, r1: float, ramp: tuple[str, ...] | list[str],
        tip_col: str | None = None, protect: bool = False,
    ) -> None:
        """Curved quadratic Bezier limb/horn/tail/tentacle with crisp 3-tone shading."""
        length = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) + math.hypot(p2[0] - p1[0], p2[1] - p1[1])
        steps = max(6, int(length * 1.8) + 1)
        pts = []
        for i in range(steps + 1):
            t = i / steps
            mt = 1.0 - t
            x = mt * mt * p0[0] + 2 * mt * t * p1[0] + t * t * p2[0]
            y = mt * mt * p0[1] + 2 * mt * t * p1[1] + t * t * p2[1]
            r = r0 + (r1 - r0) * t
            pts.append((x, y, r, t))
        dark = ramp[0]
        mid = ramp[len(ramp) // 2]
        lit = ramp[-1]
        for x, y, r, t in pts:
            self.circle(x, y, r, tip_col if (tip_col and t > 0.80) else dark, protect=protect)
        if len(ramp) >= 2:
            for x, y, r, t in pts:
                if tip_col and t > 0.82:
                    continue
                self.circle(x - 0.35, y - 0.45, max(0.3, r * 0.68), mid, protect=protect)
        if len(ramp) >= 3:
            for x, y, r, t in pts:
                if 0.06 < t < 0.78:
                    self.set(x - r * 0.45, y - r * 0.55, lit, protect=protect)

    def ring(
        self, cx: float, cy: float, r: float, col: str,
        thick: float = 1.0, a0_deg: float = 0.0, a1_deg: float = 360.0, protect: bool = False,
    ) -> None:
        steps = max(12, int(abs(a1_deg - a0_deg) * max(1.0, r) / 36.0))
        for i in range(steps + 1):
            ang = math.radians(a0_deg + (a1_deg - a0_deg) * (i / steps))
            px, py = cx + math.cos(ang) * r, cy + math.sin(ang) * r
            if thick <= 1.1:
                self.set(px, py, col, protect=protect)
            else:
                self.circle(px, py, thick * 0.5, col, protect=protect)

    def chain(
        self, p0: tuple[float, float], p1: tuple[float, float], sag: float,
        link_col: str = "mauve", hi_col: str = "stone", dark_col: str = "night",
        links: int = 7,
    ) -> None:
        """Hanging curved chain of alternating pixel links."""
        for i in range(links + 1):
            t = i / max(1, links)
            x = p0[0] + (p1[0] - p0[0]) * t
            y = p0[1] + (p1[1] - p0[1]) * t + math.sin(t * math.pi) * sag
            self.circle(x, y, 1.4 if i % 2 == 0 else 1.1, dark_col)
            self.set(x, y, hi_col if i % 2 == 0 else link_col)
            if i % 2 == 0:
                self.set(x - 1, y, link_col)

    def eye(
        self, cx: float, cy: float, iris_col: str = "gold",
        glint_col: str = "cream", socket_col: str = "void", w: int = 2, h: int = 2,
    ) -> None:
        """Crisp protected pixel eye with dark socket & luminous iris."""
        ix, iy = int(round(cx)), int(round(cy))
        self.rect(ix - 1, iy - 1, w + 2, h + 2, socket_col, protect=True)
        self.rect(ix, iy, w, h, iris_col, protect=True)
        self.set(ix, iy, glint_col, protect=True)

    def crack(
        self, x0: float, y0: float, x1: float, y1: float,
        dark_col: str = "void", glow_col: str | None = "coral", seed: int = 1,
    ) -> None:
        """Wear / phase-2 fissure stamped pre-outline with optional inner ember glow."""
        mx = 0.5 * (x0 + x1) + (hash01(int(x0), int(y0), seed) - 0.5) * 4.0
        my = 0.5 * (y0 + y1) + (hash01(int(x1), int(y1), seed + 7) - 0.5) * 4.0
        self.line(x0, y0, mx, my, dark_col, protect=True)
        self.line(mx, my, x1, y1, dark_col, protect=True)
        if glow_col is not None:
            self.set(mx, my, glow_col, protect=True)
            self.set((x0 + mx) * 0.5, (y0 + my) * 0.5, glow_col, protect=True)

    def star4(self, cx: float, cy: float, r: int = 2, core: str = "cream", ray: str = "gold") -> None:
        ix, iy = int(round(cx)), int(round(cy))
        self.set(ix, iy, core, protect=True)
        for d in range(1, r + 1):
            c = core if (d == 1 and r >= 3) else ray
            self.set(ix - d, iy, c, protect=True)
            self.set(ix + d, iy, c, protect=True)
            self.set(ix, iy - d, c, protect=True)
            self.set(ix, iy + d, c, protect=True)

    def dizzy_stars(self, cx: float, cy: float, rx: float, ry: float, phase: float, count: int = 3) -> None:
        for i in range(count):
            ang = phase + i * (math.tau / count)
            sx = cx + math.cos(ang) * rx
            sy = cy + math.sin(ang) * ry
            if math.sin(ang) > -0.1:
                self.star4(sx, sy, 2, "cream", "gold")
            else:
                self.star4(sx, sy, 1, "gold", "apricot")

    def slash_arc(
        self, cx: float, cy: float, rx: float, ry: float,
        a0_deg: float, a1_deg: float, max_thick: float,
        cols: tuple[str, str, str], reverse_taper: bool = False,
    ) -> None:
        """Tapered kinetic weapon smear ribbon (drawn on glow/FX layer)."""
        outer_c, mid_c, core_c = cols
        steps = 42
        for i in range(steps + 1):
            u = i / steps
            ang = math.radians(a0_deg + (a1_deg - a0_deg) * u)
            ca, sa = math.cos(ang), math.sin(ang)
            tp = (1.0 - u) if reverse_taper else u
            thick = max_thick * (max(0.0, math.sin(tp * math.pi)) ** 0.72) * (0.25 + 0.95 * tp)
            if thick < 0.45:
                continue
            rad_mul = 0.92 + 0.14 * tp
            px, py = cx + ca * rx * rad_mul, cy + sa * ry * rad_mul
            self.circle(px, py, thick * 0.55, outer_c, protect=True)
            if tp > 0.25:
                self.circle(px + ca * thick * 0.14, py + sa * thick * 0.14, thick * 0.34, mid_c, protect=True)
            if tp > 0.46:
                ex, ey = px + ca * thick * 0.30, py + sa * thick * 0.30
                self.set(ex, ey, core_c, protect=True)
                if tp > 0.68:
                    self.set(ex + ca * 0.8, ey + sa * 0.8, core_c, protect=True)

    def flame_wisp(self, cx: float, cy: float, r: float, h: float, phase: float, cols: tuple[str, str, str] = ("coral", "gold", "cream")) -> None:
        """Crisp animated pixel flame/lantern glow (dithering-free)."""
        sway = math.sin(phase) * 1.4
        self.ellipse(cx, cy, r, r * 0.85, cols[0], protect=True)
        self.poly([(cx - r, cy), (cx + sway, cy - h), (cx + r, cy)], cols[0], protect=True)
        self.ellipse(cx, cy - r * 0.15, r * 0.65, r * 0.65, cols[1], protect=True)
        self.poly([(cx - r * 0.55, cy - 0.5), (cx + sway * 0.7, cy - h * 0.7), (cx + r * 0.55, cy - 0.5)], cols[1], protect=True)
        self.circle(cx, cy - r * 0.1, max(0.7, r * 0.34), cols[2], protect=True)

    def contact_shadow(self, cx: float, cy: float, rx: float, ry: float = 1.6, col: str = "night") -> None:
        """Tight grounded 1-2 px sole shadow under feet (sits cleanly over brain.gd's ground oval)."""
        self.ellipse(cx, cy, rx, ry, col, protect=True)


# =============================================================================
# Transforms, Rim Light, Selective 1 px Outline & Finalization
# =============================================================================
def rotate_buf(src: PixelBuf, px: float, py: float, deg: float) -> PixelBuf:
    if abs(deg) < 0.05:
        return src.copy()
    rad = math.radians(deg)
    ca, sa = math.cos(rad), math.sin(rad)
    dst = PixelBuf(src.w, src.h)
    sw, sh = src.w, src.h
    sgrid, dgrid = src.grid, dst.grid
    sprot, dprot = src.protect, dst.protect
    for y in range(sh):
        dy = y - py
        drow = dgrid[y]
        for x in range(sw):
            dx = x - px
            ix = int(round(px + dx * ca + dy * sa))
            iy = int(round(py - dx * sa + dy * ca))
            if 0 <= ix < sw and 0 <= iy < sh:
                c = sgrid[iy][ix]
                if c is not None:
                    drow[x] = c
                    if (ix, iy) in sprot:
                        dprot.add((x, y))
    return dst


def squash_stretch(src: PixelBuf, sx: float, sy: float, ax: float, ay: float) -> PixelBuf:
    if abs(sx - 1.0) < 0.01 and abs(sy - 1.0) < 0.01:
        return src.copy()
    inv_x = 1.0 / max(0.2, sx)
    inv_y = 1.0 / max(0.2, sy)
    dst = PixelBuf(src.w, src.h)
    sw, sh = src.w, src.h
    sgrid, dgrid = src.grid, dst.grid
    sprot, dprot = src.protect, dst.protect
    for y in range(sh):
        iy = int(round(ay + (y - ay) * inv_y))
        if not (0 <= iy < sh):
            continue
        srow = sgrid[iy]
        drow = dgrid[y]
        for x in range(sw):
            ix = int(round(ax + (x - ax) * inv_x))
            if 0 <= ix < sw:
                c = srow[ix]
                if c is not None:
                    drow[x] = c
                    if (ix, iy) in sprot:
                        dprot.add((x, y))
    return dst


def apply_rim_light(buf: PixelBuf, cool: bool = False) -> PixelBuf:
    """Dithering-free WNW rim light: lifts exposed left/top silhouette pixels 1 palette step."""
    out = buf.copy()
    w, h = buf.w, buf.h
    src = buf.grid
    dst = out.grid
    prot = buf.protect
    lut = COOL if cool else LIGHT
    for y in range(h):
        row = src[y]
        drow = dst[y]
        up_row = src[y - 1] if y > 0 else None
        for x in range(w):
            c = row[x]
            if c is None or (x, y) in prot or c in ("void", "night", "cream"):
                continue
            left_empty = (x == 0 or row[x - 1] is None)
            top_empty = (up_row is None or up_row[x] is None)
            if left_empty or top_empty:
                drow[x] = lut[c]
    return out


def apply_selective_outline(buf: PixelBuf, shadow_col: str = "night") -> PixelBuf:
    """Last Light 1 px selective outline: shadow_col on shadow side (right/bottom),
    1 shade darker than neighbour on sunlit side (left/top). Never clips out of frame."""
    out = buf.copy()
    w, h = buf.w, buf.h
    src = buf.grid
    dst = out.grid
    shade = SHADE
    for y in range(h):
        row = src[y]
        drow = dst[y]
        up = src[y - 1] if y > 0 else None
        dn = src[y + 1] if y + 1 < h else None
        for x in range(w):
            if row[x] is not None:
                continue
            l_c = row[x - 1] if x > 0 else None
            u_c = up[x] if up is not None else None
            if l_c is not None or u_c is not None:
                drow[x] = shadow_col
            else:
                r_c = row[x + 1] if x + 1 < w else None
                d_c = dn[x] if dn is not None else None
                nb = r_c or d_c
                if nb is not None:
                    drow[x] = shade[nb]
    return out


def finalize_frame(
    body: PixelBuf,
    fx_front: PixelBuf | None = None,
    fx_back: PixelBuf | None = None,
    shadow_buf: PixelBuf | None = None,
    cool_rim: bool = False,
    outline_col: str = "night",
    sx: float = 1.0,
    sy: float = 1.0,
    anchor: tuple[float, float] | None = None,
) -> Image.Image:
    """Full Last Light frame pass: optional squash/stretch -> WNW rim light -> 1 px selective outline -> composite shadow & glow FX."""
    work = squash_stretch(body, sx, sy, anchor[0], anchor[1]) if (anchor and (abs(sx - 1.0) > 0.01 or abs(sy - 1.0) > 0.01)) else body
    lit = apply_rim_light(work, cool=cool_rim)
    outlined = apply_selective_outline(lit, shadow_col=outline_col)
    final = Image.new("RGBA", (body.w, body.h), (0, 0, 0, 0))
    if shadow_buf is not None:
        final.alpha_composite(shadow_buf.to_image())
    if fx_back is not None:
        final.alpha_composite(fx_back.to_image())
    final.alpha_composite(outlined.to_image())
    if fx_front is not None:
        final.alpha_composite(fx_front.to_image())
    return final


# =============================================================================
# Hierarchical Part Rig with Secondary Motion
# =============================================================================
@dataclass
class FrameCtx:
    anim: str
    direction: str
    fi: int
    nf: int
    u: float          # normalized [0..1] across animation
    phase: float      # radians [0..TAU) for cyclic anims
    lag_u: float      # 1-frame-lagged u for secondary motion!
    lag_phase: float  # 1-frame-lagged radians for secondary motion!
    is_phase2: bool = False
    is_tell: bool = False
    is_commit: bool = False
    is_recover: bool = False
    is_stagger: bool = False


def make_ctx(anim: str, direction: str, fi: int, nf: int) -> FrameCtx:
    u = fi / max(1, nf - 1) if nf > 1 else 0.0
    phase = (fi / max(1, nf)) * math.tau
    lag_fi = (fi - 1) % max(1, nf)
    lag_u = max(0.0, (fi - 1) / max(1, nf - 1)) if anim in ("tell", "commit") else (lag_fi / max(1, nf - 1))
    lag_phase = (lag_fi / max(1, nf)) * math.tau
    return FrameCtx(
        anim=anim, direction=direction, fi=fi, nf=nf, u=u, phase=phase,
        lag_u=lag_u, lag_phase=lag_phase,
        is_phase2=(anim == "phase2"), is_tell=(anim == "tell"),
        is_commit=(anim == "commit"), is_recover=(anim == "recover"),
        is_stagger=(anim == "stagger"),
    )


@dataclass
class RigPart:
    name: str
    z: int
    draw_fn: Callable[[PixelBuf, FrameCtx, tuple[float, float]], None]
    layer: str = "body"  # body | fx_back | fx_front | shadow | wear
    pivot: tuple[float, float] = (0.0, 0.0)
    offset_fn: Callable[[FrameCtx], tuple[float, float]] | None = None
    angle_fn: Callable[[FrameCtx], float] | None = None


@dataclass
class CreatureSpec:
    id: str
    name: str
    out_dir: Path
    frame: tuple[int, int]
    anchor: tuple[int, int]
    body_radius: float
    hit_radius: float
    body_centre: tuple[int, int]
    anims: list[tuple[str, bool, list[float]]] = field(default_factory=lambda: list(ENEMY_ANIMS))
    directions: tuple[str, ...] = DIRS_3
    cool_rim: bool = False
    outline_col: str = "night"
    biome_bg: str = "teal"
    draw_frame: Callable[[FrameCtx], Image.Image] | None = None
    parts: list[RigPart] = field(default_factory=list)
    squash_fn: Callable[[FrameCtx], tuple[float, float]] | None = None


def render_rig_frame(spec: CreatureSpec, ctx: FrameCtx) -> Image.Image:
    if spec.draw_frame is not None:
        return spec.draw_frame(ctx)
    fw, fh = spec.frame
    ax, ay = spec.anchor
    body = PixelBuf(fw, fh)
    fx_back = PixelBuf(fw, fh)
    fx_front = PixelBuf(fw, fh)
    shadow = PixelBuf(fw, fh)
    ordered = sorted(spec.parts, key=lambda p: p.z)
    for part in ordered:
        ox, oy = part.offset_fn(ctx) if part.offset_fn else (0.0, 0.0)
        deg = part.angle_fn(ctx) if part.angle_fn else 0.0
        target = body if part.layer in ("body", "wear") else (fx_back if part.layer == "fx_back" else (fx_front if part.layer == "fx_front" else shadow))
        if abs(deg) >= 0.1:
            tmp = PixelBuf(fw, fh)
            part.draw_fn(tmp, ctx, (ax + ox, ay + oy))
            rot = rotate_buf(tmp, ax + ox + part.pivot[0], ay + oy + part.pivot[1], deg)
            target.composite(rot)
        else:
            part.draw_fn(target, ctx, (ax + ox, ay + oy))
    sx, sy = spec.squash_fn(ctx) if spec.squash_fn else (1.0, 1.0)
    return finalize_frame(body, fx_front, fx_back, shadow, spec.cool_rim, spec.outline_col, sx, sy, (ax, ay))


# =============================================================================
# Strict Palette Audit + Engine Exporter + Previews
# =============================================================================
def assert_palette_clean(img: Image.Image, label: str) -> None:
    colors = img.getcolors(maxcolors=2_000_000)
    assert colors is not None, f"{label}: too many colors"
    bad = []
    for cnt, (r, g, b, a) in colors:
        if a == 0:
            continue
        if a < 255 or (r, g, b) not in ALLOWED_RGB:
            bad.append(f"rgba({r},{g},{b},{a})x{cnt}")
    if bad:
        raise ValueError(f"{label}: palette violation: {', '.join(bad[:6])}")


def export_creature(spec: CreatureSpec, preview_dir: Path | None = None, make_gif: bool = True) -> dict[tuple[str, str], list[Image.Image]]:
    t0 = time.perf_counter()
    fw, fh = spec.frame
    ax, ay = spec.anchor
    max_cols = max(len(ms) for _, _, ms in spec.anims)
    total_rows = len(spec.anims) * len(spec.directions)
    sheet_w, sheet_h = fw * max_cols, fh * total_rows
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    rendered: dict[tuple[str, str], list[Image.Image]] = {}
    anims_json: dict[str, dict] = {}
    row = 0
    edge_warns = 0
    for anim_name, loop, ms_list in spec.anims:
        nf = len(ms_list)
        dirs_json: dict[str, dict] = {}
        for d in spec.directions:
            frames: list[Image.Image] = []
            rects: list[list[int]] = []
            for fi in range(nf):
                ctx = make_ctx(anim_name, d, fi, nf)
                fr = render_rig_frame(spec, ctx)
                bbox = fr.getbbox()
                if bbox and (bbox[0] == 0 or bbox[1] == 0 or bbox[2] == fw or bbox[3] == fh):
                    edge_warns += 1
                x0, y0 = fi * fw, row * fh
                sheet.alpha_composite(fr, (x0, y0))
                frames.append(fr)
                rects.append([x0, y0, fw, fh])
            rendered[(anim_name, d)] = frames
            dirs_json[d] = {"row": row, "frames": nf, "ms": ms_list, "rects": rects}
            row += 1
        anims_json[anim_name] = {
            "loop": loop, "frame": [fw, fh], "anchor": [ax, ay], "dirs": dirs_json,
        }

    assert_palette_clean(sheet, spec.id)
    spec.out_dir.mkdir(parents=True, exist_ok=True)
    png_path = spec.out_dir / f"{spec.id}.png"
    json_path = spec.out_dir / f"{spec.id}.json"
    sheet.save(png_path)

    manifest = {
        "id": spec.id, "name": spec.name, "version": 1, "palette": PAL,
        "sheet": f"{spec.id}.png", "sheet_size": [sheet_w, sheet_h],
        "frame": [fw, fh], "anchor": [ax, ay],
        "directions": list(spec.directions),
        "mirror_left": "side faces right; flip horizontally on anchor x for left",
        "animations": anims_json,
        "hit_radius": spec.hit_radius, "body_radius": spec.body_radius,
        "body_centre": list(spec.body_centre),
    }
    json_path.write_text(json.dumps(manifest, indent=1) + "\n")
    dt = time.perf_counter() - t0
    warn_s = f" WARN_EDGE={edge_warns}" if edge_warns else ""
    print(f"[creature] {spec.id}: {sheet_w}x{sheet_h} ({total_rows} rows) in {dt:.2f}s{warn_s}")

    if preview_dir is not None:
        preview_dir.mkdir(parents=True, exist_ok=True)
        save_contact_sheet(rendered, spec, preview_dir / f"{spec.id}_contact.png", scale=3)
        if make_gif:
            save_animated_gif(rendered, spec, preview_dir / f"{spec.id}_preview.gif", scale=4)
    return rendered


def _load_wick_ref() -> Image.Image | None:
    if not WICK_PNG.is_file():
        return None
    return Image.open(WICK_PNG).convert("RGBA").crop((0, 0, 44, 40))


def save_contact_sheet(
    rendered: dict[tuple[str, str], list[Image.Image]],
    spec: CreatureSpec,
    out_path: Path,
    scale: int = 3,
) -> None:
    fw, fh = spec.frame
    anim_names = [a[0] for a in spec.anims]
    peak = {"routine": 0, "tell": -1, "commit": 1, "recover": 1, "stagger": 1, "phase2": 0}
    wick = _load_wick_ref()
    pad = 4
    cols = 1 + len(anim_names)
    bw = cols * (fw + pad) + pad * 2
    bh = len(spec.directions) * (fh + pad) + pad * 2
    im = Image.new("RGBA", (bw * 2 + pad, bh + fh + pad * 2), RGBA["void"])
    draw = ImageDraw.Draw(im)
    draw.rectangle([pad, pad, bw - pad, bh - pad], fill=RGBA["night"])
    draw.rectangle([bw + pad * 2, pad, bw * 2, bh - pad], fill=RGBA[spec.biome_bg])
    for ri, d in enumerate(spec.directions):
        ry = pad + ri * (fh + pad)
        if wick is not None:
            wx = pad + (fw - 44) // 2
            wy = ry + (spec.anchor[1] - 36)
            im.alpha_composite(wick, (wx, wy))
        for ci, an in enumerate(anim_names):
            frs = rendered[(an, d)]
            fr = frs[peak.get(an, 0)]
            im.alpha_composite(fr, (pad + (1 + ci) * (fw + pad), ry))
            alt = frs[(peak.get(an, 0) + 2) % len(frs)]
            im.alpha_composite(alt, (bw + pad * 2 + ci * (fw + pad), ry))
    # Zoomed top + 1x readability strip at bottom
    zoomed = im.crop((0, 0, im.width, bh)).resize((im.width * scale, bh * scale), Image.Resampling.NEAREST)
    strip_h = fh + 16
    out = Image.new("RGBA", (zoomed.width, zoomed.height + strip_h), RGBA["void"])
    out.alpha_composite(zoomed, (0, 0))
    # Draw 1x strip directly (true pixel size readability test!)
    ox = 8
    for an in anim_names:
        for d in spec.directions:
            fr = rendered[(an, d)][peak.get(an, 0)]
            if ox + fw < out.width:
                out.alpha_composite(fr, (ox, zoomed.height + 8))
                ox += fw + 4
    out.save(out_path)


def save_animated_gif(
    rendered: dict[tuple[str, str], list[Image.Image]],
    spec: CreatureSpec,
    out_path: Path,
    scale: int = 4,
) -> None:
    """Saves a smooth 4x animated GIF cycling all animations side-by-side (front + side)."""
    fw, fh = spec.frame
    pad = 4
    cw = fw * 2 + pad * 3
    ch = fh + pad * 2
    gif_frames: list[Image.Image] = []
    durations: list[int] = []
    d_a = "front" if "front" in spec.directions else spec.directions[0]
    d_b = "side" if "side" in spec.directions else spec.directions[-1]
    for anim_name, _loop, ms_list in spec.anims:
        frs_a = rendered[(anim_name, d_a)]
        frs_b = rendered[(anim_name, d_b)]
        for fi, ms in enumerate(ms_list):
            canvas = Image.new("RGBA", (cw, ch), RGBA["night"])
            canvas.alpha_composite(frs_a[fi], (pad, pad))
            canvas.alpha_composite(frs_b[fi], (fw + pad * 2, pad))
            big = canvas.resize((cw * scale, ch * scale), Image.Resampling.NEAREST)
            gif_frames.append(big.convert("P", palette=Image.Palette.ADAPTIVE, colors=32))
            durations.append(max(40, int(ms)))
    if gif_frames:
        gif_frames[0].save(
            out_path, save_all=True, append_images=gif_frames[1:],
            duration=durations, loop=0, disposal=2,
        )


def load_sheet_frame(json_path: Path, anim: str, direction: str, idx: int = 0) -> Image.Image:
    data = json.loads(json_path.read_text())
    png = Image.open(json_path.parent / data["sheet"]).convert("RGBA")
    anims = data["animations"]
    an_key = anim if anim in anims else ("routine" if "routine" in anims else next(iter(anims)))
    dirs = anims[an_key]["dirs"]
    d_key = direction if direction in dirs else next(iter(dirs))
    rects = dirs[d_key]["rects"]
    r = rects[idx % len(rects)]
    return png.crop((r[0], r[1], r[0] + r[2], r[1] + r[3]))


def save_comparison_sheet(
    pairs: list[tuple[str, Path, str, Path]],
    out_path: Path,
    scale: int = 2,
) -> None:
    """Side-by-side comparison grid: NEW creature (routine/front, tell/side, commit/side, back)
    vs EXISTING reference (routine/front, commit/side) + 1x silhouette strip."""
    cell_w, cell_h = 92, 88
    cols = 6
    pad = 6
    label_w = 132
    w = label_w + cols * (cell_w + pad) + pad
    h = 24 + len(pairs) * (cell_h + pad) + pad
    base = Image.new("RGBA", (w, h), RGBA["void"])
    draw = ImageDraw.Draw(base)
    headers = ["NEW routine/f", "NEW tell/s", "NEW commit/s", "NEW back", "REF routine/f", "REF commit/s"]
    for ci, hd in enumerate(headers):
        draw.text((label_w + ci * (cell_w + pad) + 4, 6), hd, fill=RGBA["gold"] if ci < 4 else RGBA["ice"])

    for ri, (new_lbl, new_json, ref_lbl, ref_json) in enumerate(pairs):
        y0 = 24 + ri * (cell_h + pad)
        draw.rectangle([4, y0, w - 4, y0 + cell_h], outline=RGBA["dusk"])
        draw.text((10, y0 + 14), f"NEW: {new_lbl}", fill=RGBA["gold"])
        draw.text((10, y0 + 30), f"REF: {ref_lbl}", fill=RGBA["ice"])
        # Also stamp 1x true-scale preview inside the label column (uncropped!)
        f1x = load_sheet_frame(new_json, "routine", "front", 0)
        bb = f1x.getbbox()
        if bb:
            crop1x = f1x.crop(bb)
            cx1 = 10 + max(0, (112 - crop1x.width) // 2)
            cy1 = y0 + 38 + max(0, (cell_h - 40 - crop1x.height) // 2)
            base.alpha_composite(crop1x, (cx1, min(y0 + cell_h - crop1x.height - 2, cy1)))

        slots = [
            (new_json, "routine", "front", 0),
            (new_json, "tell", "side", -1),
            (new_json, "commit", "side", 1),
            (new_json, "routine", "back", 0),
            (ref_json, "routine", "front", 0),
            (ref_json, "commit", "side", 1),
        ]
        for ci, (jp, an, dr, idx) in enumerate(slots):
            x0 = label_w + ci * (cell_w + pad)
            draw.rectangle([x0, y0 + 2, x0 + cell_w - 1, y0 + cell_h - 2], fill=RGBA["night"], outline=RGBA["plum"] if ci < 4 else RGBA["deep"])
            fr = load_sheet_frame(jp, an, dr, idx)
            px = x0 + (cell_w - fr.width) // 2
            py = y0 + (cell_h - fr.height) // 2
            base.alpha_composite(fr, (px, py))

    zoomed = base.resize((base.width * scale, base.height * scale), Image.Resampling.NEAREST)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    zoomed.save(out_path)
    print(f"[creature] wrote comparison {out_path.relative_to(REPO_ROOT)} ({zoomed.width}x{zoomed.height})")
