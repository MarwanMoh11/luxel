#!/usr/bin/env python3
"""Island 5 Enemy: Comet Hound (astral sapphire wolf-hound with blazing comet mane & tail) — 60x50, anchor [30, 40]."""
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

ASTRAL = ("night", "deep", "blue", "sky")
BRASS = ("plum", "coral", "apricot", "gold")
COMET = ("coral", "apricot", "gold", "cream")


def draw_comet_hound(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 54
    ax, ay = 32.0, 44.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = abs(math.sin(ph)) * 2.0 if ctx.anim == "routine" else 0.0
    lunge = 0.0
    crouch = 0.0
    stride = math.sin(ph) * 4.2 if ctx.anim == "routine" else 0.0
    tail_wave = math.sin(lph) * 3.8
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 3.2 * u
        lunge = -4.0 * u
        sx, sy = 1.07, 0.91
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lunge = 6.5 * sm
        crouch = -2.0 * sm
        stride = 5.5 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        lunge = 3.0 * (1.0 - u)
        crouch = 2.0
    elif ctx.is_stagger:
        lunge = -2.5 + math.sin(ph * 2.0) * 1.6
        crouch = 3.0

    cx = ax + (lunge if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 1.0, 13.0 if d == "side" else 11.0, 1.8, "night")

    if d == "side":
        # Streaming blazing comet tail behind haunches (strictly inside frame!)
        tx, ty = cx - 11.0, cy - 12.0
        fx_back.bezier_limb(
            (tx, ty), (tx - 6.0, ty - 4.0 + tail_wave * 0.5),
            (tx - 11.5, ty - 1.5 + tail_wave * 0.8), 3.6, 0.8, ("coral", "apricot", "gold"),
            tip_col="cream", protect=True,
        )
        fx_back.star4(tx - 10.5, ty - 1.5 + tail_wave * 0.8, 2, "cream", "gold")

        # Far legs
        body.capsule(cx - 8, cy - 8, cx - 10 - stride * 0.65, cy - 1, 2.0, 1.3, ("void", "night", "deep"))
        body.capsule(cx + 6, cy - 9, cx + 8 + stride * 0.65, cy - 1, 2.0, 1.3, ("void", "night", "deep"))

        # Sleek muscular hound ribcage + haunch + constellation freckles!
        body.shaded_ellipse(cx - 7.5, cy - 10.5, 6.2, 4.8, ASTRAL)
        body.shaded_ellipse(cx - 1.0, cy - 11.5, 7.5, 4.6, ASTRAL)
        body.shaded_ellipse(cx + 5.5, cy - 13.0, 6.2, 5.4, ASTRAL, spec_col="ice")
        body.set(cx - 6, cy - 11, "ice", protect=True)
        body.set(cx - 2, cy - 10, "cream", protect=True)
        body.set(cx + 1, cy - 12, "sky", protect=True)

        # Near legs with glowing ice paws
        body.capsule(cx - 6, cy - 8, cx - 7 + stride, cy, 2.2, 1.4, ASTRAL)
        body.capsule(cx + 7, cy - 9, cx + 10 - stride, cy, 2.2, 1.4, ASTRAL)
        body.rect(cx - 8 + stride, cy - 1, 3, 2, "ice")
        body.rect(cx + 9 - stride, cy - 1, 3, 2, "ice")

        # Brass astrolabe collar + blazing swept comet mane
        body.shaded_ellipse(cx + 8.5, cy - 15.0, 3.2, 5.2, BRASS)
        mane_shift = tail_wave * 0.35
        body.shaded_poly([
            (cx + 5, cy - 18), (cx - 4, cy - 22 + mane_shift), (cx + 1, cy - 15),
            (cx - 6, cy - 16 + mane_shift), (cx + 3, cy - 12), (cx + 9, cy - 14),
        ], COMET)

        # Angular wolf-hound snout & swept astral ears
        hx, hy = cx + 12.0, cy - 18.0 - crouch * 0.2
        body.shaded_poly([(hx - 5, hy - 3), (hx - 9, hy - 9 + mane_shift * 0.35), (hx - 1, hy - 5)], ASTRAL)
        body.shaded_poly([(hx - 2, hy - 4), (hx - 5, hy - 10 + mane_shift * 0.35), (hx + 2, hy - 4)], ("deep", "blue", "sky", "ice"))
        body.shaded_ellipse(hx, hy, 5.2, 4.0, ASTRAL, spec_col="ice")
        body.shaded_poly([(hx + 2, hy - 2), (hx + 8.5, hy + 1), (hx + 6.5, hy + 3), (hx + 1, hy + 3)], ASTRAL)
        body.set(hx + 7.5, hy + 1, "cream", protect=True)
        body.eye(hx + 1.5, hy - 1.5, "gold" if not ctx.is_tell else "cream", "cream", "void", 2, 2)
    elif d == "front":
        # Wide athletic wolf stance: hind haunches peeking wide behind planted forelegs!
        fx_back.bezier_limb(
            (cx, cy - 15), (cx + 7 + tail_wave * 0.7, cy - 26), (cx + 1 + tail_wave, cy - 31),
            3.2, 0.8, ("coral", "apricot", "gold"), tip_col="cream", protect=True,
        )
        # Rear haunches visible wide on flanks
        body.shaded_ellipse(cx - 8.5, cy - 7.5, 4.0, 5.0, ("void", "night", "deep"))
        body.shaded_ellipse(cx + 8.5, cy - 7.5, 4.0, 5.0, ("void", "night", "deep"))
        body.rect(cx - 11, cy - 2, 3, 2, "sky")
        body.rect(cx + 8, cy - 2, 3, 2, "sky")
        # Planted muscular forelegs (angled outward slightly for power!)
        body.capsule(cx - 5, cy - 11, cx - 7, cy, 2.5, 1.7, ASTRAL)
        body.capsule(cx + 5, cy - 11, cx + 7, cy, 2.5, 1.7, ASTRAL)
        body.rect(cx - 8, cy - 1, 4, 2, "ice")
        body.rect(cx + 4, cy - 1, 4, 2, "ice")
        # Broad constellation-speckled chest + round brass astrolabe collar
        body.shaded_ellipse(cx, cy - 12.5, 8.6, 6.4, ASTRAL, spec_col="ice")
        body.set(cx - 4, cy - 11, "ice", protect=True)
        body.set(cx + 4, cy - 12, "cream", protect=True)
        body.ring(cx, cy - 16.5, 7.6, "gold", 1.8)
        body.circle(cx, cy - 11.0, 2.0, "gold", protect=True)
        # Swept-back golden comet fur-mane framing neck (organic jagged ruff, not triangles!)
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (cx + sgn * 4, cy - 19), (cx + sgn * 11, cy - 23 + tail_wave * 0.25),
                (cx + sgn * 9, cy - 17), (cx + sgn * 12, cy - 14 + tail_wave * 0.2),
                (cx + sgn * 7, cy - 12), (cx + sgn * 4, cy - 14),
            ], COMET)
        # Wolf head, pointed ears & snout
        hx, hy = cx, cy - 20.5 + crouch * 0.3
        body.shaded_poly([(hx - 5, hy - 3), (hx - 9, hy - 11), (hx - 2, hy - 5)], ASTRAL)
        body.shaded_poly([(hx + 5, hy - 3), (hx + 9, hy - 11), (hx + 2, hy - 5)], ASTRAL)
        body.shaded_ellipse(hx, hy, 6.4, 5.2, ASTRAL, spec_col="ice")
        body.shaded_poly([(hx - 3.5, hy + 1), (hx + 3.5, hy + 1), (hx + 2, hy + 5.5), (hx - 2, hy + 5.5)], ("deep", "blue", "sky"))
        body.set(hx, hy + 4.5, "ice", protect=True)
        body.eye(hx - 3.8, hy - 1.5, "gold", "cream", "void", 2, 2)
        body.eye(hx + 1.8, hy - 1.5, "gold", "cream", "void", 2, 2)
    else:
        # Back view: wide planted haunches, starry sapphire back, sweeping comet tail!
        body.shaded_ellipse(cx - 7.5, cy - 8.0, 4.5, 5.5, ASTRAL)
        body.shaded_ellipse(cx + 7.5, cy - 8.0, 4.5, 5.5, ASTRAL)
        body.capsule(cx - 6, cy - 9, cx - 7, cy, 2.4, 1.6, ASTRAL)
        body.capsule(cx + 6, cy - 9, cx + 7, cy, 2.4, 1.6, ASTRAL)
        body.shaded_ellipse(cx, cy - 13, 8.6, 6.8, ASTRAL)
        body.shaded_ellipse(cx, cy - 19, 6.8, 5.0, ASTRAL)
        body.set(cx - 4, cy - 14, "ice", protect=True)
        body.set(cx + 5, cy - 15, "cream", protect=True)
        body.shaded_poly([(cx - 5, cy - 22), (cx - 9, cy - 30), (cx - 2, cy - 23)], ASTRAL)
        body.shaded_poly([(cx + 5, cy - 22), (cx + 9, cy - 30), (cx + 2, cy - 23)], ASTRAL)
        body.shaded_ellipse(cx, cy - 18.0, 9.5, 3.0, COMET)
        body.bezier_limb(
            (cx, cy - 10), (cx + tail_wave, cy - 19), (cx - tail_wave * 0.6, cy - 28),
            3.8, 0.9, ("coral", "apricot", "gold"), tip_col="cream", protect=True,
        )
        fx_front.star4(cx - tail_wave * 0.6, cy - 28, 2, "cream", "gold")

    if ctx.is_tell and u > 0.35:
        gx = cx + (13 if d == "side" else 0)
        fx_front.star4(gx, cy - 20, 3 if u > 0.72 else 2, "cream", "ice")
        fx_back.ring(cx, cy - 11, 13.0 - u * 4.0, "sky", 1.0)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 6, cy - 13, 17, 11, -60, 60, 5.4, ("blue", "sky", "cream"))
            fx_back.line(cx - 21, cy - 14, cx - 6, cy - 14, "gold", protect=True)
            fx_back.line(cx - 19, cy - 10, cx - 8, cy - 10, "ice", protect=True)
        else:
            fx_front.slash_arc(cx, cy - 13, 17, 11, -155, -25, 5.0, ("blue", "sky", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx + (6 if d == "side" else 0), cy - 30, 8.0, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="comet_hound", name="Comet Hound", out_dir=ART_ENEMIES,
    frame=(64, 54), anchor=(32, 44),
    body_radius=7.0, hit_radius=10.5, body_centre=(32, 31),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_comet_hound,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
