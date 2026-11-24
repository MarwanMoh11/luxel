#!/usr/bin/env python3
"""Island 8 Superboss: The First Dark (obsidian eclipse-oculus inside 3 counter-rotating gothic astrolabe rings) — 106x106, anchor [53, 84]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

OBSIDIAN = ("void", "void", "night", "dusk")
ASTROLABE = ("night", "dusk", "plum", "wine")
BRASS = ("plum", "coral", "apricot", "gold")


def _draw_astrolabe_ring(
    buf: PixelBuf, cx: float, cy: float, rx: float, ry: float,
    tilt_deg: float, rot: float, ring_col: str, tick_col: str, spikes: int,
) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    steps = 48
    for i in range(steps):
        a0 = (i / steps) * math.tau
        a1 = ((i + 1) / steps) * math.tau
        x0, y0 = cx + math.cos(a0) * rx, cy + math.sin(a0) * ry
        x1, y1 = cx + math.cos(a1) * rx, cy + math.sin(a1) * ry
        tmp.line(x0, y0, x1, y1, ring_col)
        tmp.line(x0, y0 - 1, x1, y1 - 1, "night")
    for k in range(spikes):
        a = rot + k * (math.tau / spikes)
        px0 = cx + math.cos(a) * rx
        py0 = cy + math.sin(a) * ry
        px1 = cx + math.cos(a) * (rx + 5.0)
        py1 = cy + math.sin(a) * (ry + 5.0)
        tmp.line(px0, py0, px1, py1, tick_col, protect=True)
        tmp.rect(px1 - 1, py1 - 1, 2, 2, "cream" if k % 2 == 0 else tick_col, protect=True)
    buf.composite(rotate_buf(tmp, cx, cy, tilt_deg))


def draw_first_dark(ctx: FrameCtx) -> Image.Image:
    w, h = 106, 106
    ax, ay = 53.0, 84.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.5 if ctx.anim in ("routine", "phase2") else 0.0
    ring_scale = 1.0
    eye_open = 1.0
    spin = ph * (1.2 if p2 else 0.7)
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        ring_scale = 1.0 - 0.14 * u
        eye_open = 1.0 + 0.35 * u
        spin += u * 1.8
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.4) * math.pi)
        ring_scale = 1.0 + 0.16 * sm
        eye_open = 1.45
        spin += sm * 2.6
        sx, sy = 1.09, 0.93
    elif ctx.is_recover:
        hover = -2.2
        ring_scale = 0.94
        eye_open = 0.65
    elif ctx.is_stagger:
        hover = -3.8
        ring_scale = 1.08
        eye_open = 1.35

    cx = ax
    cy = ay - 33.0 - hover
    shadow.contact_shadow(ax, ay + 2.0, 20.0, 3.0, "void")

    # Outer gothic astrolabe ring 1 (tilted wide)
    r1x = (33.0 if d != "side" else 22.0) * ring_scale
    r1y = 31.0 * ring_scale
    _draw_astrolabe_ring(fx_back, cx, cy, r1x, r1y, -18.0 + math.sin(lph) * 5.0, spin, "plum", "gold", 8)

    # Mid counter-rotating astrolabe ring 2
    r2x = (25.0 if d != "side" else 17.0) * ring_scale
    r2y = 25.0 * ring_scale
    _draw_astrolabe_ring(body, cx, cy, r2x, r2y, 28.0 - math.sin(lph) * 6.0, -spin * 1.3, "wine" if p2 else "dusk", "ice" if p2 else "apricot", 6)

    # Inner meridian ring 3
    r3x = (19.0 if d != "side" else 13.0) * ring_scale
    r3y = 19.0 * ring_scale
    _draw_astrolabe_ring(body, cx, cy, r3x, r3y, 72.0, spin * 1.8, "mauve", "gold", 4)

    # Central Primordial Obsidian Eclipse Sphere
    sphere_rx = 14.0 if d != "side" else 12.0
    sphere_ry = 14.0
    # Radiant corona halo behind obsidian core
    corona_col = "cream" if (p2 or ctx.is_commit) else "gold"
    body.ring(cx, cy, sphere_rx + 1.5, corona_col, 1.8, protect=True)
    body.shaded_ellipse(cx, cy, sphere_rx, sphere_ry, OBSIDIAN)

    # Fractures on stagger or P2 revealing blinding cream starlight underneath!
    if p2 or ctx.is_stagger:
        body.crack(cx - 8, cy - 9, cx + 9, cy + 8, "gold", "cream", seed=7)
        body.crack(cx + 7, cy - 8, cx - 7, cy + 9, "ice", "cream", seed=19)

    if d == "front":
        # Haunting primordial eclipse oculus (almond ice/gold corona + pitch void slit)
        eh = max(2.0, 5.2 * eye_open)
        body.shaded_ellipse(cx, cy, 8.5, eh, ("deep", "sky", "ice", "cream"))
        body.shaded_ellipse(cx, cy, 5.5, max(1.6, eh * 0.72), ("coral", "apricot", "gold", "cream"))
        body.shaded_ellipse(cx, cy, 2.2, max(1.4, eh * 0.85), ("void", "void", "void", "night"))
        body.rect(cx - 1, cy - 2, 2, 2, "cream", protect=True)
    elif d == "side":
        eh = max(2.0, 5.0 * eye_open)
        body.shaded_ellipse(cx + 5.5, cy, 4.5, eh, ("deep", "sky", "ice", "cream"))
        body.shaded_ellipse(cx + 6.5, cy, 2.2, max(1.4, eh * 0.75), ("void", "void", "void", "night"))
        body.rect(cx + 5.5, cy - 2, 2, 2, "cream", protect=True)
        # Trailing eclipse-flare comet tail behind side profile
        fx_back.bezier_limb((cx - 10, cy - 4), (cx - 24, cy - 8 + math.sin(lph) * 4), (cx - 34, cy - 4), 3.0, 0.8, ASTROLABE, "ice")
        fx_back.bezier_limb((cx - 10, cy + 4), (cx - 24, cy + 8 - math.sin(lph) * 4), (cx - 34, cy + 4), 3.0, 0.8, ASTROLABE, "gold")
    else:
        # Back view: dark umbra shell with engraved golden star-meridian cross
        body.ring(cx, cy, 8.0, "plum", 1.2)
        body.line(cx - 10, cy, cx + 10, cy, "gold")
        body.line(cx, cy - 10, cx, cy + 10, "gold")
        body.circle(cx, cy, 2.5, "ice" if p2 else "dusk", protect=True)

    # Orbiting tiny golden rescued Moth-Sparks (iconic 80-moth superboss motif!)
    moth_n = 8 if p2 else 4
    for m in range(moth_n):
        ma = -ph * 1.1 + m * (math.tau / moth_n)
        mx = cx + math.cos(ma) * (34.0 if d != "side" else 28.0)
        my = cy + math.sin(ma) * 32.0
        fx_front.rect(mx - 1, my, 3, 1, "gold", protect=True)
        fx_front.set(mx, my - 1, "cream", protect=True)

    if ctx.is_tell and u > 0.22:
        fx_front.ring(cx, cy, 36.0 - u * 12.0, "ice" if p2 else "gold", 1.4, protect=True)
        fx_front.star4(cx + (6 if d == "side" else 0), cy, 4 if u > 0.65 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.ring(cx, cy, 24.0 + ctx.fi * 5.0, "coral", 2.4, protect=True)
        fx_front.ring(cx, cy, 21.0 + ctx.fi * 5.0, "gold", 1.6, protect=True)
        fx_front.ring(cx, cy, 18.0 + ctx.fi * 5.0, "cream", 1.0, protect=True)
        for k in range(4):
            ca = spin + k * (math.tau / 4.0)
            fx_front.line(cx + math.cos(ca) * 14, cy + math.sin(ca) * 14, cx + math.cos(ca) * 38, cy + math.sin(ca) * 38, "gold", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 22, 14.0, 3.8, ph)
        fx_front.star4(cx, cy, 5, "cream", "gold")

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="first_dark", name="The First Dark", out_dir=ART_BOSSES,
    frame=(106, 106), anchor=(53, 84),
    body_radius=14.0, hit_radius=18.5, body_centre=(53, 52),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="void",
    draw_frame=draw_first_dark,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
