#!/usr/bin/env python3
"""Island 3 Enemy: Vine Strangler (coiled ambush briar-vine pillar with glowing gold heart-knot) — 58x58, anchor [29, 48]."""
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

VINE = ("night", "pine", "teal", "jade")
WOOD = ("void", "night", "plum", "wine")
KNOT = ("coral", "apricot", "gold", "cream")
THORN = ("plum", "wine", "coral", "rose")


def draw_vine_strangler(ctx: FrameCtx) -> Image.Image:
    w, h = 58, 58
    ax, ay = 29.0, 48.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    sway = math.sin(ph) * 1.4 if ctx.anim == "routine" else 0.0
    coil = 0.0
    reach = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        coil = -4.0 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        reach = 11.0 * sm
        sx, sy = 1.08, 0.93
    elif ctx.is_recover:
        reach = 3.0 * (1.0 - u)
        sx, sy = 1.04, 0.95
    elif ctx.is_stagger:
        sway = math.sin(ph * 2.0) * 2.8

    cx = ax + sway
    cy = ay
    shadow.contact_shadow(ax, ay + 1.0, 11.5, 2.0, "night")

    # Rooted base coil gripping the floor
    body.shaded_ellipse(cx, cy - 3.5, 11.5, 4.4, WOOD)
    body.shaded_ellipse(cx, cy - 5.5, 9.5, 3.6, VINE)

    # Braided upright vine trunk (reads like an ivy pillar that unwinds to lash!)
    body.bezier_limb((cx - 4.0, cy - 5.0), (cx - 7.0 + coil * 0.4, cy - 17.0), (cx - 2.0, cy - 29.0), 4.2, 3.0, VINE)
    body.bezier_limb((cx + 4.0, cy - 5.0), (cx + 7.0 - coil * 0.4, cy - 16.0), (cx + 2.0, cy - 29.0), 4.0, 2.8, WOOD)
    body.shaded_ellipse(cx, cy - 19.0, 8.6, 11.0, VINE)

    # Crown vine hood with drooping briar tendril & rose thorns breaking silhouette
    body.shaded_dome(cx, cy - 28.5, 8.5, 7.2, VINE, bottom_cut=0.18)
    body.bezier_limb((cx - 2, cy - 34), (cx - 8, cy - 38 + math.sin(lph)), (cx - 12, cy - 33), 2.0, 0.8, VINE, tip_col="rose")
    body.bezier_limb((cx + 2, cy - 34), (cx + 7, cy - 37 - math.sin(lph)), (cx + 10, cy - 32), 1.8, 0.8, VINE, tip_col="lime")
    for tx, ty, dx in [(-9, -24, -3), (9, -23, 3), (-8, -14, -3), (8, -15, 3)]:
        body.poly([(cx + tx, cy + ty), (cx + tx + dx, cy + ty - 3), (cx + tx + dx * 0.4, cy + ty + 2)], "rose")

    # Exposed glowing gold heart-knot (opens wide during recover & stagger!)
    knot_r = 4.6 if (ctx.is_recover or ctx.is_stagger) else (3.6 if ctx.is_tell else 2.8)
    if d != "back":
        kx = cx + (3.5 if d == "side" else 0.0)
        ky = cy - 17.5
        body.circle(kx, ky, knot_r + 1.4, "wine")
        body.shaded_ellipse(kx, ky, knot_r, knot_r * 0.88, KNOT, protect=True)
        body.set(kx - 0.5, ky - 0.5, "cream", protect=True)

    # Grasping vine whip tentacles
    if d == "side":
        # Back curl vine
        body.bezier_limb((cx - 5, cy - 18), (cx - 12 + math.sin(lph) * 2, cy - 23), (cx - 14, cy - 15), 2.2, 1.0, VINE, tip_col="rose")
        # Front lashing root-tether
        body.bezier_limb(
            (cx + 4, cy - 16),
            (cx + 10 + coil + reach * 0.6, cy - 22 + math.sin(lph) * 2),
            (cx + 12 + coil + reach, cy - 13),
            2.4, 1.0, THORN if (ctx.is_tell or ctx.is_commit) else VINE, tip_col="coral",
        )
        body.eye(cx + 4.0, cy - 27.5, "rose", "cream", "void", 2, 2)
    elif d == "front":
        for sgn in (-1.0, 1.0):
            body.bezier_limb(
                (cx + sgn * 6, cy - 17),
                (cx + sgn * (12 + reach * 0.35), cy - 22 + coil * 0.5 + math.sin(lph + sgn) * 2),
                (cx + sgn * (14 + reach * 0.55), cy - 12),
                2.3, 1.0, THORN if (ctx.is_tell or ctx.is_commit) else VINE, tip_col="rose",
            )
        body.eye(cx - 4.0, cy - 27.5, "rose", "cream", "void", 2, 2)
        body.eye(cx + 2.0, cy - 27.5, "rose", "cream", "void", 2, 2)
    else:
        # Back view: thick gnarled woody ivy tangle
        body.line(cx - 5, cy - 26, cx + 4, cy - 10, "wine")
        body.line(cx + 5, cy - 25, cx - 4, cy - 9, "pine")
        for sgn in (-1.0, 1.0):
            body.bezier_limb((cx + sgn * 6, cy - 18), (cx + sgn * 12, cy - 22), (cx + sgn * 13, cy - 13), 2.1, 0.9, VINE, tip_col="rose")

    if ctx.is_tell and u > 0.30:
        # Pulsing coral vein warning along tether
        fx_front.star4(cx + (12 if d == "side" else 0), cy - 18, 3 if u > 0.7 else 2, "cream", "coral")
        fx_front.line(cx, cy - 17, cx + (14 if d == "side" else 0), cy - 13, "coral", protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 11, cy - 16, 15, 11, -65, 65, 4.8, ("wine", "coral", "rose"))
        else:
            fx_front.slash_arc(cx, cy - 14, 18, 10, 15, 165, 4.6, ("wine", "coral", "rose"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 36.0, 8.5, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="vine_strangler", name="Vine Strangler", out_dir=ART_ENEMIES,
    frame=(58, 58), anchor=(29, 48),
    body_radius=6.5, hit_radius=10.5, body_centre=(29, 29),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_vine_strangler,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
