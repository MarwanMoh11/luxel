#!/usr/bin/env python3
"""Island 3 Enemy: Dandelion Drifter (floating wind-borne puff spirit) — 54x58, anchor [27, 46]."""
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

STEM = ("night", "pine", "teal", "jade")
LEAF = ("pine", "teal", "jade", "lime")
PUFF = ("dusk", "mauve", "stone", "cream")
CORE = ("coral", "apricot", "gold", "cream")


def draw_dandelion_drifter(ctx: FrameCtx) -> Image.Image:
    w, h = 54, 58
    ax, ay = 27.0, 46.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = 6.5 + math.sin(ph) * 2.4
    sway = math.sin(lph) * 2.5
    puff_scale = 1.0
    tilt = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        puff_scale = 1.0 + 0.24 * u
        hover += 1.5 * u
        sx, sy = 1.06 + 0.06 * u, 0.94
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        puff_scale = 1.15 - 0.35 * sm
        tilt = 4.0 * sm
        sx, sy = 1.08, 0.92
    elif ctx.is_recover:
        puff_scale = 0.78
        hover -= 2.0
    elif ctx.is_stagger:
        tilt = math.sin(ph * 2.0) * 4.0
        hover -= 2.5
        puff_scale = 0.85

    cx = ax + (tilt if d == "side" else 0.0)
    cy = ay - hover
    shadow.contact_shadow(ax, ay + 1.0, 8.0, 1.6, "night")

    # Dangling leafy dandelion stem & curling tendrils
    stem_tip_x = cx - sway * 1.2
    body.bezier_limb((cx, cy - 10.0), (cx - sway * 0.5, cy - 3.0), (stem_tip_x, cy + 4.0), 2.4, 0.9, STEM, tip_col="lime")
    # Calyx leaf skirt flaring around stem waist
    for sgn in (-1.0, 1.0):
        lx = cx + sgn * (5.5 if d != "side" else 3.5)
        body.shaded_poly([
            (cx, cy - 12.0), (lx + sgn * 3.0, cy - 7.0 + math.sin(lph + sgn) * 1.5),
            (lx - sgn * 1.0, cy - 5.5), (cx, cy - 9.0),
        ], LEAF)
    # Central calyx collar bulb
    body.shaded_ellipse(cx, cy - 13.5, 5.2, 4.8, STEM)

    # Fluffy spherical dandelion pappus halo crown
    hx = cx + (1.0 if d == "side" else 0.0)
    hy = cy - 22.0
    hr = 10.2 * puff_scale
    body.shaded_ellipse(hx, hy, hr, hr * 0.92, PUFF, spec_col="cream")
    # Radial pappus fluff tufts breaking the silhouette into a true dandelion orb!
    tuft_n = 10 if not ctx.is_recover else 6
    for k in range(tuft_n):
        a = (k / float(tuft_n)) * math.tau + math.sin(lph) * 0.08
        tx = hx + math.cos(a) * (hr + 1.8)
        ty = hy + math.sin(a) * (hr * 0.92 + 1.8)
        body.circle(tx, ty, 2.3 if k % 2 == 0 else 1.8, "cream" if math.sin(a) < 0.25 else "stone")
        if k % 2 == 0:
            fx_front.set(hx + math.cos(a) * (hr + 3.2), hy + math.sin(a) * (hr * 0.92 + 3.2), "cream", protect=True)

    # Warm glowing seed-core & expressive golden eye peeking from calyx
    if d == "front":
        body.shaded_ellipse(cx, cy - 14.5, 3.8, 3.0, ("night", "pine", "teal"))
        body.eye(cx - 1.5, cy - 15.0, "gold" if not ctx.is_tell else "cream", "cream", "void", 3, 2)
        body.circle(hx, hy + 1.0, 2.4, "gold" if ctx.is_tell else "apricot", protect=True)
    elif d == "side":
        body.eye(cx + 2.0, cy - 15.0, "gold" if not ctx.is_tell else "cream", "cream", "void", 2, 2)
        body.circle(hx + 2.5, hy + 0.5, 2.2, "gold" if ctx.is_tell else "apricot", protect=True)
    else:
        # Back view: leafy sepals hugging the fluffy white head
        body.shaded_poly([(cx - 5, cy - 14), (cx, cy - 19), (cx + 5, cy - 14), (cx, cy - 10)], LEAF)

    if ctx.is_tell and u > 0.30:
        fx_front.ring(hx, hy, hr + 3.5 - u * 2.0, "cream" if u > 0.7 else "gold", 1.0, protect=True)
        fx_front.star4(hx + (6 if d == "side" else 0), hy, 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        # Burst of 3 floating dandelion seed-mines shooting outward
        for k, ang_d in enumerate((-28, 0, 28)):
            rad = math.radians(ang_d if d == "side" else (ang_d + 90))
            dist = 9.0 + ctx.fi * 3.8
            sx_m = hx + math.cos(rad) * dist
            sy_m = hy + math.sin(rad) * dist
            fx_front.circle(sx_m, sy_m, 2.0, "cream", protect=True)
            fx_front.set(sx_m, sy_m, "gold", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 12.0, 8.0, 2.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="dandelion_drifter", name="Dandelion Drifter", out_dir=ART_ENEMIES,
    frame=(54, 58), anchor=(27, 46),
    body_radius=5.5, hit_radius=9.0, body_centre=(27, 24),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_dandelion_drifter,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
