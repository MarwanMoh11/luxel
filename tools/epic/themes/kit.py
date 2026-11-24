"""Shared numpy + PIL Last Light 20-colour painting kit for Luxel Epic themes.

Strictly enforces the 20 Last Light colours from docs/art_concepts/lastlight/core.py,
world-anchored 4x4 Bayer dithering, zero semi-transparent pixels (alpha 0 or 255).
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[3]
LASTLIGHT_DIR = REPO_ROOT / "docs" / "art_concepts" / "lastlight"
if str(LASTLIGHT_DIR) not in sys.path:
    sys.path.insert(0, str(LASTLIGHT_DIR))

import core  # noqa: E402
from core import COOL, LIGHT, NAME, PAL, RAMPS, RGB, RGBA, SHADE, dither, fbm, hash01  # noqa: E402

NAMES: list[str] = list(PAL.keys())
IX: dict[str, int] = {n: i for i, n in enumerate(NAMES)}
PAL_RGB_ARR: np.ndarray = np.array([RGB[n] for n in NAMES], dtype=np.uint8)
SHADE_IX: np.ndarray = np.array([IX[SHADE[n]] for n in NAMES], dtype=np.uint8)
LIGHT_IX: np.ndarray = np.array([IX[LIGHT[n]] for n in NAMES], dtype=np.uint8)
COOL_IX: np.ndarray = np.array([IX[COOL[n]] for n in NAMES], dtype=np.uint8)

BAYER_4X4: np.ndarray = (
    np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) + 0.5
) / 16.0

TRANSPARENT = (0, 0, 0, 0)
TAU = math.tau

# Canonical tile classifications
WALKABLE_TYPES = {"ground", "path", "bramble", "cracked", "carpet", "dais", "stairs", "grate", "rail", "hearth"}
LAND_TYPES = WALKABLE_TYPES | {"wall", "foliage"}
ABYSS_TYPES = {"pit", "void", "phantom"}
OPEN_TYPES = {"water", "pit", "void", "tide", "phantom"}


def bayer_grid(h: int, w: int, ox: int = 0, oy: int = 0) -> np.ndarray:
    yy = (np.arange(h, dtype=np.int32) + oy) & 3
    xx = (np.arange(w, dtype=np.int32) + ox) & 3
    return BAYER_4X4[yy[:, None], xx[None, :]]


def hash01_grid(x: np.ndarray, y: np.ndarray, seed: int = 0) -> np.ndarray:
    n = (
        x.astype(np.uint64) * np.uint64(374761393)
        + y.astype(np.uint64) * np.uint64(668265263)
        + np.uint64(seed) * np.uint64(982451653)
    ) & np.uint64(0xFFFFFFFF)
    n = ((n ^ (n >> np.uint64(13))) * np.uint64(1274126177)) & np.uint64(0xFFFFFFFF)
    return ((n ^ (n >> np.uint64(16))) & np.uint64(0xFFFF)).astype(np.float32) / 65535.0


def vnoise_grid(h: int, w: int, scale: float, seed: int = 0, ox: float = 0.0, oy: float = 0.0) -> np.ndarray:
    gx = (np.arange(w, dtype=np.float32)[None, :] + ox) / max(1.0, scale)
    gy = (np.arange(h, dtype=np.float32)[:, None] + oy) / max(1.0, scale)
    x0 = np.floor(gx).astype(np.int64)
    y0 = np.floor(gy).astype(np.int64)
    fx = gx - x0
    fy = gy - y0
    sx = fx * fx * (3.0 - 2.0 * fx)
    sy = fy * fy * (3.0 - 2.0 * fy)
    a = hash01_grid(x0, y0, seed)
    b = hash01_grid(x0 + 1, y0, seed)
    c = hash01_grid(x0, y0 + 1, seed)
    d = hash01_grid(x0 + 1, y0 + 1, seed)
    return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy


def fbm_grid(
    h: int,
    w: int,
    scale: float,
    seed: int = 0,
    octaves: int = 3,
    sx: float = 1.0,
    sy: float = 1.0,
) -> np.ndarray:
    """Fast vectorized fBm on an (h, w) pixel grid with optional axis stretch."""
    gx_base = np.arange(w, dtype=np.float32)[None, :] * sx
    gy_base = np.arange(h, dtype=np.float32)[:, None] * sy
    total = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        sc = max(1.0, scale / (2 ** o))
        gx = gx_base / sc
        gy = gy_base / sc
        x0 = np.floor(gx).astype(np.int64)
        y0 = np.floor(gy).astype(np.int64)
        fx = gx - x0
        fy = gy - y0
        ux = fx * fx * (3.0 - 2.0 * fx)
        uy = fy * fy * (3.0 - 2.0 * fy)
        sd = seed + o * 31
        a = hash01_grid(x0, y0, sd)
        b = hash01_grid(x0 + 1, y0, sd)
        c = hash01_grid(x0, y0 + 1, sd)
        d = hash01_grid(x0 + 1, y0 + 1, sd)
        total += (a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def chamfer_dist(mask: np.ndarray) -> np.ndarray:
    """Fast approximate Euclidean distance (in pixels) from False pixels for every True pixel."""
    h, w = mask.shape
    d = np.where(mask, 1e6, 0.0).astype(np.float32)
    r2 = np.float32(1.4142135)
    for y in range(h):
        row = d[y]
        if y > 0:
            prev = d[y - 1]
            row = np.minimum(row, prev + 1.0)
            row[1:] = np.minimum(row[1:], prev[:-1] + r2)
            row[:-1] = np.minimum(row[:-1], prev[1:] + r2)
        for x in range(1, w):
            if row[x] > row[x - 1] + 1.0:
                row[x] = row[x - 1] + 1.0
        d[y] = row
    for y in range(h - 1, -1, -1):
        row = d[y]
        if y < h - 1:
            nxt = d[y + 1]
            row = np.minimum(row, nxt + 1.0)
            row[1:] = np.minimum(row[1:], nxt[:-1] + r2)
            row[:-1] = np.minimum(row[:-1], nxt[1:] + r2)
        for x in range(w - 2, -1, -1):
            if row[x] > row[x + 1] + 1.0:
                row[x] = row[x + 1] + 1.0
        d[y] = row
    return d


def buf_to_image(buf: np.ndarray, alpha_mask: np.ndarray | None = None) -> Image.Image:
    """Convert a palette-index buffer (H, W) uint8 to strict Last Light RGBA PNG."""
    rgb = PAL_RGB_ARR[buf]
    if alpha_mask is None:
        a = np.full((buf.shape[0], buf.shape[1], 1), 255, dtype=np.uint8)
    else:
        a = np.where(alpha_mask[:, :, None], np.uint8(255), np.uint8(0))
        rgb = np.where(alpha_mask[:, :, None], rgb, np.uint8(0))
    rgba = np.concatenate([rgb, a], axis=2)
    return Image.fromarray(rgba, mode="RGBA")


def ramp_blend(ramp: tuple[str, ...] | list[str], field: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Map a float field in [0, 1] through an ordered palette ramp using Bayer dithering."""
    n = len(ramp) - 1
    if n <= 0:
        return np.full(field.shape, IX[ramp[0]], dtype=np.uint8)
    f = np.clip(field, 0.0, 0.9999) * float(n)
    idx_lo = np.floor(f).astype(np.int32)
    frac = f - idx_lo
    idx = np.where(frac > bg, np.minimum(idx_lo + 1, n), idx_lo)
    lut = np.array([IX[c] for c in ramp], dtype=np.uint8)
    return lut[idx]


def shift_grid(grid: list[list[str]], dr: int, dc: int, default: str = "void") -> list[list[str]]:
    h = len(grid)
    w = len(grid[0]) if h else 0
    out: list[list[str]] = []
    for r in range(h):
        nr = r + dr
        row: list[str] = []
        for c in range(w):
            nc = c + dc
            if 0 <= nr < h and 0 <= nc < w:
                row.append(grid[nr][nc])
            else:
                row.append(default)
        out.append(row)
    return out


def expand_tile_mask(grid: list[list[str]], types: set[str], ts: int) -> np.ndarray:
    h = len(grid)
    w = len(grid[0]) if h else 0
    m = np.array([[grid[r][c] in types for c in range(w)] for r in range(h)], dtype=bool)
    return np.repeat(np.repeat(m, ts, axis=0), ts, axis=1)


def expand_neighbor_mask(grid: list[list[str]], dr: int, dc: int, types: set[str], ts: int, default: str = "void") -> np.ndarray:
    sh = shift_grid(grid, dr, dc, default=default)
    return expand_tile_mask(sh, types, ts)


def shade_buf(buf: np.ndarray, mask: np.ndarray) -> None:
    buf[mask] = SHADE_IX[buf[mask]]


def light_buf(buf: np.ndarray, mask: np.ndarray) -> None:
    buf[mask] = LIGHT_IX[buf[mask]]


def verify_image_palette(im: Image.Image, label: str = "") -> None:
    arr = np.asarray(im.convert("RGBA"))
    a = arr[:, :, 3]
    semi = np.count_nonzero((a > 0) & (a < 255))
    if semi:
        raise ValueError(f"Palette violation in {label}: {semi} semi-transparent pixels")
    opaque = arr[a == 255][:, :3]
    if opaque.size == 0:
        return
    # Fast packed 24-bit RGB check
    packed = (
        (opaque[:, 0].astype(np.uint32) << 16)
        | (opaque[:, 1].astype(np.uint32) << 8)
        | opaque[:, 2].astype(np.uint32)
    )
    allowed = np.array(
        [(r << 16) | (g << 8) | b for (r, g, b) in RGB.values()],
        dtype=np.uint32,
    )
    bad = np.count_nonzero(~np.isin(packed, allowed))
    if bad:
        raise ValueError(f"Palette violation in {label}: {bad} off-palette pixels")
