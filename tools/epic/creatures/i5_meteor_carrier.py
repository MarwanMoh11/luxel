#!/usr/bin/env python3
"""Island 5 Enemy: Meteor Carrier (stout brass scarab beetle hauling a glowing cracked meteor boulder) — 64x56, anchor [32, 46]."""
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

SHELL = ("night", "dusk", "deep", "blue")
BRASS = ("plum", "coral", "apricot", "gold")
METEOR = ("night", "wine", "coral", "apricot")


def _draw_meteor(buf: PixelBuf, mx: float, my: float, r: float, hot: bool, seed: int = 7) -> None:
    buf.shaded_ellipse(mx, my, r * 1.08, r * 0.95, METEOR, spec_col="gold" if hot else "apricot")
    buf.crack(mx - r * 0.55, my - r * 0.4, mx + r * 0.45, my + r * 0.35, "void", "cream" if hot else "gold", seed=seed)
    buf.crack(mx + r * 0.4, my - r * 0.5, mx - r * 0.2, my + r * 0.5, "void", "gold" if hot else "apricot", seed=seed + 3)
    if hot:
        buf.circle(mx, my, r * 0.36, "gold", protect=True)
        buf.set(mx, my, "cream", protect=True)


def draw_meteor_carrier(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 56
    ax, ay = 32.0, 46.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    step = math.sin(ph) * 2.6 if ctx.anim == "routine" else 0.0
    bob = abs(math.sin(ph)) * 1.4 if ctx.anim == "routine" else 0.0
    heft = 0.0
    has_boulder = True
    hot_boulder = False
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        heft = 5.5 * u
        hot_boulder = True
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        has_boulder = ctx.fi <= 1
        heft = 6.0
        hot_boulder = True
        sx, sy = 1.10, 0.90
    elif ctx.is_recover:
        # Empty back! Digging a new boulder out of the rock
        has_boulder = u > 0.72
        bob = -2.2
        sx, sy = 1.04, 0.94
    elif ctx.is_stagger:
        has_boulder = False
        bob = -1.5 + math.sin(ph * 2.0) * 1.0
        sx, sy = 1.06, 0.92

    cx = ax
    cy = ay - bob
    shadow.contact_shadow(ax, ay + 1.0, 13.5, 2.2, "night")

    if d == "side":
        # Far beetle legs
        for lx, phase_s in [(-8, 1.0), (0, -1.0), (8, 1.0)]:
            body.capsule(cx + lx, cy - 6, cx + lx + step * phase_s, cy - 1, 1.8, 1.3, ("void", "night", "deep"))

        # Glowing meteor boulder cradled on back (or hefted high on tell!)
        if has_boulder:
            mx = cx - 2.0 + (4.0 * u if ctx.is_tell else 0.0)
            my = cy - 19.5 - heft
            _draw_meteor(body, mx, my, 8.2, hot_boulder, seed=11)

        # Stout brass-trimmed scarab carapace
        body.shaded_ellipse(cx - 2.0, cy - 9.5, 11.5, 6.2, SHELL, spec_col="sky")
        body.shaded_ellipse(cx - 1.5, cy - 12.2, 10.5, 2.6, BRASS)
        # Head + horned brass mandibles on right
        body.shaded_ellipse(cx + 9.5, cy - 8.5, 4.8, 4.4, BRASS, spec_col="cream")
        body.shaded_poly([
            (cx + 12, cy - 10), (cx + 18, cy - 13 - heft * 0.3), (cx + 15, cy - 7),
        ], BRASS)
        body.eye(cx + 10.5, cy - 9.2, "gold" if not hot_boulder else "cream", "cream", "void", 2, 2)

        # Near sturdy legs
        for lx, phase_s in [(-7, -1.0), (1, 1.0), (8, -1.0)]:
            body.capsule(cx + lx, cy - 6, cx + lx + step * phase_s, cy, 2.1, 1.4, BRASS)
    elif d == "front":
        # Massive meteor looming behind scarab head!
        if has_boulder:
            _draw_meteor(body, cx, cy - 22.0 - heft, 8.8, hot_boulder, seed=13)
        # Side legs
        for sgn in (-1.0, 1.0):
            body.capsule(cx + sgn * 8, cy - 7, cx + sgn * 12, cy, 2.0, 1.4, BRASS)
            body.capsule(cx + sgn * 6, cy - 6, cx + sgn * 9, cy + 0.5, 2.0, 1.4, SHELL)
        # Broad armored chest & head
        body.shaded_ellipse(cx, cy - 10.0, 10.8, 6.8, SHELL, spec_col="sky")
        body.shaded_ellipse(cx, cy - 13.0, 9.8, 2.6, BRASS)
        body.shaded_ellipse(cx, cy - 7.5, 6.4, 4.6, BRASS, spec_col="gold")
        # Twin scarab horns framing snout
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (cx + sgn * 4, cy - 9), (cx + sgn * 9, cy - 14 - heft * 0.25), (cx + sgn * 7, cy - 7),
            ], BRASS)
        body.eye(cx - 3.2, cy - 7.8, "gold", "cream", "void", 2, 2)
        body.eye(cx + 1.6, cy - 7.8, "gold", "cream", "void", 2, 2)
    else:
        # Back view: stout shell & prominent boulder cradle
        for sgn in (-1.0, 1.0):
            body.capsule(cx + sgn * 8, cy - 7, cx + sgn * 11.5, cy, 2.1, 1.4, BRASS)
        body.shaded_ellipse(cx, cy - 10.0, 11.2, 6.8, SHELL)
        body.shaded_ellipse(cx, cy - 12.5, 10.0, 2.8, BRASS)
        if has_boulder:
            _draw_meteor(body, cx, cy - 21.0 - heft, 9.0, hot_boulder, seed=17)
        else:
            # Empty concave brass cradle on back
            body.shaded_ellipse(cx, cy - 13.5, 6.5, 3.0, ("void", "night", "dusk"))

    # Tell / Commit / Recover / Stagger FX
    if ctx.is_tell and u > 0.30:
        fx_front.star4(cx + (2 if d == "side" else 0), cy - 29.0 - heft * 0.5, 3 if u > 0.72 else 2, "cream", "gold")
        fx_back.ring(cx, cy - 21.0 - heft, 10.0 + u * 2.5, "coral", 1.2)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 10, cy - 16, 15, 13, -75, 35, 5.0, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 18, 16, 11, -155, -25, 5.0, ("coral", "apricot", "cream"))
    elif ctx.is_recover:
        # Digging pebbles kicking up
        fx_front.rect(cx - 8 + math.sin(ph) * 2, cy - 3, 2, 2, "stone")
        fx_front.rect(cx + 7 - math.sin(ph) * 2, cy - 4, 2, 2, "apricot")
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 22.0, 9.5, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="meteor_carrier", name="Meteor Carrier", out_dir=ART_ENEMIES,
    frame=(64, 56), anchor=(32, 46),
    body_radius=7.5, hit_radius=11.5, body_centre=(32, 29),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="deep",
    draw_frame=draw_meteor_carrier,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
