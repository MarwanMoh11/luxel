#!/usr/bin/env python3
"""Island 5 Enemy: Star Jelly (nebula dome jellyfish with dangling gold star tendrils) — 58x54, anchor [29, 44]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_ENEMIES, CACHE_DIR, ENEMY_ANIMS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame,
)

NEBULA = ("night", "plum", "rose", "ice")
NEBULA_COOL = ("deep", "blue", "sky", "ice")
TENDRIL = ("coral", "apricot", "gold", "cream")


def draw_star_jelly(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 60
    ax, ay = 32.0, 48.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    pulse = math.sin(ph)
    drift_y = pulse * 2.4 if ctx.anim == "routine" else 0.0
    bell_rx = 9.5 + pulse * 0.9
    bell_ry = 8.2 - pulse * 0.7
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Bell bloats wide and taut before shock-pulse!
        bell_rx = 9.5 + 3.8 * u
        bell_ry = 8.2 + 2.6 * u
        drift_y = -2.0 * u
        sx, sy = 1.06, 1.04
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        bell_rx = 12.2 - 3.5 * sm
        bell_ry = 7.0 + 2.5 * sm
        drift_y = -3.0 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        # Deflated drooping bell
        bell_rx = 7.4 + 1.2 * u
        bell_ry = 6.2 + 1.0 * u
        drift_y = 3.5 * (1.0 - u) + 1.2
        sx, sy = 0.92, 1.05
    elif ctx.is_stagger:
        bell_rx = 8.4 + math.sin(ph * 2.0) * 1.4
        bell_ry = 6.8
        drift_y = 3.0

    cx = ax + (1.5 if d == "side" else 0.0)
    cy = ay - 22.0 + drift_y
    shadow.contact_shadow(ax, ay + 1.0, 9.0, 1.6, "night")

    # Four trailing golden star tendrils (secondary motion via lag_phase!)
    tendril_offsets = [-6.5, -2.2, 2.2, 6.5] if d != "side" else [-5.5, -1.8, 1.8, 5.0]
    side_sweep = -5.5 if d == "side" else 0.0
    for idx, ox in enumerate(tendril_offsets):
        wave = math.sin(lph + idx * 1.15) * (3.2 if not ctx.is_recover else 1.4)
        t_len = (13.0 if idx in (1, 2) else 10.5) * (0.78 if ctx.is_recover else 1.0)
        p0 = (cx + ox, cy + bell_ry * 0.45)
        p1 = (cx + ox + side_sweep * 0.5 + wave * 0.6, cy + bell_ry * 0.45 + t_len * 0.55)
        p2 = (cx + ox + side_sweep + wave, cy + bell_ry * 0.45 + t_len)
        target_buf = fx_back if idx in (0, 3) else body
        target_buf.bezier_limb(p0, p1, p2, 1.7, 0.7, TENDRIL, tip_col="cream")
        if idx in (1, 2):
            fx_front.set(p2[0], p2[1], "cream", protect=True)

    # Translucent-feeling nebula bell dome (plum/rose outer + sky/ice inner starlight glow)
    body.shaded_dome(cx, cy + 1.5, bell_rx, bell_ry, NEBULA, bottom_cut=0.12, spec_col="ice")
    body.shaded_dome(cx - (1.0 if d == "side" else 0.0), cy + 1.0, bell_rx * 0.68, bell_ry * 0.68, NEBULA_COOL, bottom_cut=0.18, spec_col="cream")
    # Frilled translucent skirt rim
    for k in range(-2, 3):
        fx = cx + k * (bell_rx * 0.34)
        fy = cy + bell_ry * 0.32 + (1.0 if k % 2 == 0 else 0.0)
        body.circle(fx, fy, 2.3, "rose" if k % 2 == 0 else "sky")

    # Star-freckles inside nebula bell
    body.set(cx - 3.5, cy - 3.5, "cream", protect=True)
    body.set(cx + 2.5, cy - 4.5, "gold", protect=True)
    body.set(cx, cy - 1.5, "ice", protect=True)

    if d == "front":
        # Two bright golden star eyes peeking under the nebula dome
        body.eye(cx - 3.4, cy + 1.0, "gold", "cream", "night", 2, 2)
        body.eye(cx + 1.8, cy + 1.0, "gold", "cream", "night", 2, 2)
    elif d == "side":
        # Forward-facing eye + sweeping dorsal nebula crest
        body.eye(cx + 4.2, cy + 0.5, "gold", "cream", "night", 2, 2)
        body.shaded_poly([
            (cx - 2, cy - bell_ry + 1), (cx - 10, cy - bell_ry + 4), (cx - 5, cy - 1),
        ], ("plum", "rose", "sky"))
    else:
        # Back view: glowing constellation spine along dorsal bell
        body.line(cx, cy - bell_ry + 2.5, cx, cy + 2.5, "gold", protect=True)
        body.set(cx, cy - 3.0, "cream", protect=True)
        body.set(cx, cy + 0.5, "ice", protect=True)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.30:
        fx_front.ring(cx, cy, bell_rx + 2.0 + u * 2.2, "rose" if u < 0.72 else "cream", 1.2)
        fx_front.star4(cx, cy - bell_ry - 2.0, 2 if u < 0.72 else 3, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3, 4):
        rad = 10.0 + ctx.fi * 2.4
        fx_front.ring(cx, cy, rad, "sky" if ctx.fi % 2 == 0 else "gold", 1.8)
        fx_front.ring(cx, cy, max(6.0, rad - 2.2), "cream", 1.0)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - bell_ry - 4.0, 8.5, 2.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="star_jelly", name="Star Jelly", out_dir=ART_ENEMIES,
    frame=(64, 60), anchor=(32, 48),
    body_radius=6.5, hit_radius=10.0, body_centre=(32, 26),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_star_jelly,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
