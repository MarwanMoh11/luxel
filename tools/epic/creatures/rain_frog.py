#!/usr/bin/env python3
"""Island 4 Enemy: Rain Frog (weather-swelling marsh toad with bubble throat sac) — 60x52, anchor [30, 42]."""
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

TOAD = ("night", "pine", "teal", "jade")
TOAD_HI = ("pine", "teal", "jade", "lime")
BUBBLE = ("deep", "blue", "sky", "ice")


def draw_rain_frog(ctx: FrameCtx) -> Image.Image:
    w, h = 60, 52
    ax, ay = 30.0, 42.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hop = abs(math.sin(ph)) * 3.0 if ctx.anim == "routine" else 0.0
    puff = 1.0 + math.sin(lph) * 0.08
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Huge swollen cheek & bubble throat inflation!
        puff = 1.15 + 0.45 * u
        sx, sy = 1.0 + 0.14 * u, 1.0 - 0.10 * u
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.65) * math.pi)
        puff = 1.45 - 0.65 * sm
        sx, sy = 0.90 + 0.18 * sm, 1.14 - 0.14 * sm
    elif ctx.is_recover:
        puff = 0.72
        sx, sy = 1.04, 0.94
    elif ctx.is_stagger:
        # Shrunk / sun-dried timid pose!
        puff = 0.62
        sx, sy = 0.84, 0.86

    cx = ax
    cy = ay - hop
    shadow.contact_shadow(ax, ay + 1.5, 11.5 * (0.9 if ctx.is_stagger else 1.0), 2.0, "night")

    # Webbed marsh toad haunches & feet
    if d == "side":
        body.shaded_ellipse(cx - 5.0, cy - 4.0, 6.2, 4.4, TOAD)
        body.rect(cx - 10, ay - 2, 7, 2, "jade")
        body.rect(cx + 3, ay - 2, 6, 2, "jade")
    else:
        for sgn in (-1.0, 1.0):
            body.shaded_ellipse(cx + sgn * 8.0, cy - 4.0, 4.8, 4.2, TOAD)
            body.rect(cx + sgn * 8.0 - 3, ay - 2, 6, 2, "jade")

    # Plump squat marsh-toad body with glossy raindrops on back
    rx = (10.5 if d != "side" else 10.0) * (0.88 if ctx.is_stagger else 1.0)
    ry = (8.8) * (0.86 if ctx.is_stagger else 1.0)
    body.shaded_ellipse(cx, cy - 9.5, rx, ry, TOAD, spec_col="lime")
    # Dark marsh spots along flanks/back
    for bx, by in [(-5, -12), (4, -11), (0, -14)]:
        body.circle(cx + bx, cy + by, 1.7, "pine")
    # Small water-lily raincap bud on crown
    body.shaded_ellipse(cx, cy - 18.0, 5.2, 2.2, TOAD_HI)
    body.circle(cx, cy - 20.5, 2.0, "sky", protect=True)
    body.set(cx - 0.5, cy - 21.0, "cream", protect=True)

    # Translucent sky/ice inflated bubble throat sac (signature visual!)
    sac_r = 5.4 * puff
    if d == "front":
        body.shaded_ellipse(cx, cy - 5.0, sac_r * 1.15, sac_r * 0.88, BUBBLE, spec_col="cream")
        body.circle(cx - sac_r * 0.35, cy - 6.5, 1.3, "cream", protect=True)
        # Wide amphibian brow bumps + big expressive golden eyes
        body.shaded_ellipse(cx - 4.5, cy - 15.5, 3.2, 2.8, TOAD_HI)
        body.shaded_ellipse(cx + 4.5, cy - 15.5, 3.2, 2.8, TOAD_HI)
        body.eye(cx - 5.5, cy - 16.0, "gold", "cream", "void", 2, 2)
        body.eye(cx + 3.5, cy - 16.0, "gold", "cream", "void", 2, 2)
        body.line(cx - 5.0, cy - 10.5, cx + 5.0, cy - 10.5, "void", protect=True)
    elif d == "side":
        body.shaded_ellipse(cx + 6.5, cy - 6.0, sac_r * 1.02, sac_r * 0.90, BUBBLE, spec_col="cream")
        body.circle(cx + 6.5 + sac_r * 0.2, cy - 8.0, 1.3, "cream", protect=True)
        body.shaded_ellipse(cx + 4.5, cy - 15.5, 3.4, 2.8, TOAD_HI)
        body.eye(cx + 4.8, cy - 16.0, "gold", "cream", "void", 2, 2)
        body.line(cx + 5.0, cy - 11.0, cx + 10.5, cy - 11.0, "void", protect=True)
    else:
        # Back view: rain-beaded dorsal ridge & puffed bubble peeking from cheeks
        body.shaded_ellipse(cx - 7.0, cy - 6.0, sac_r * 0.5, sac_r * 0.5, BUBBLE)
        body.shaded_ellipse(cx + 7.0, cy - 6.0, sac_r * 0.5, sac_r * 0.5, BUBBLE)
        body.line(cx, cy - 16.5, cx, cy - 5.5, "lime")
        body.set(cx - 3, cy - 11, "sky", protect=True)
        body.set(cx + 3, cy - 13, "ice", protect=True)

    # FX
    if ctx.is_tell and u > 0.28:
        bx = cx + (11 if d == "side" else 0)
        fx_front.ring(bx, cy - 7.0, 5.0 + u * 4.5, "ice", 1.2, protect=True)
        if u > 0.65:
            fx_front.star4(bx, cy - 12.0, 2, "cream", "sky")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        # Bursting puddle-bomb glob spray
        gx = cx + (13 + ctx.fi * 3 if d == "side" else 0)
        gy = cy - 9 + (0 if d == "side" else 2 + ctx.fi)
        fx_front.shaded_ellipse(gx, gy, 4.6, 3.4, BUBBLE, spec_col="cream")
        for k in range(4):
            a = k * 1.57 + ctx.fi * 0.4
            fx_front.rect(gx + math.cos(a) * 5.8, gy + math.sin(a) * 3.8, 2, 2, "ice" if k % 2 == 0 else "sky", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 22.0, 7.5, 2.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="rain_frog", name="Rain Frog", out_dir=ART_ENEMIES,
    frame=(60, 52), anchor=(30, 42),
    body_radius=6.0, hit_radius=10.0, body_centre=(30, 30),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="pine",
    draw_frame=draw_rain_frog,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
