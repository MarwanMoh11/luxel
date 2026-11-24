#!/usr/bin/env python3
"""Island 1 Mini-Boss: The Toll-Hound (blindfolded bronze-collared hound-toad) — 84x80, anchor [42, 62]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame,
)

HIDE = ("void", "night", "dusk", "plum")
SNOUT = ("night", "dusk", "mauve", "stone")
BLINDFOLD = ("mauve", "stone", "cream")
BRASS = ("plum", "coral", "apricot", "gold")


def _draw_collar_bell(buf: PixelBuf, bx: float, by: float, swing: float, p2: bool) -> None:
    cx = bx + swing
    buf.shaded_dome(cx, by + 1.0, 5.4, 6.2, BRASS, bottom_cut=0.45, spec_col="cream")
    buf.rect(cx - 6.0, by + 3.5, 12.0, 2.2, "gold")
    buf.circle(cx + swing * 0.25, by + 6.5, 2.0, "coral" if p2 else "cream", protect=True)
    if p2:
        buf.crack(cx - 3, by - 3, cx + 3, by + 3, "void", "coral", seed=13)


def draw_toll_hound(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 62.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = abs(math.sin(ph)) * 2.2 if ctx.anim in ("routine", "phase2") else 0.0
    stride = math.sin(ph) * 4.5 if ctx.anim in ("routine", "phase2") else 0.0
    crouch = 0.0
    lunge = 0.0
    ear_flat = 0.0
    tail_wag = math.sin(lph * 2.0) * 4.2
    bell_swing = math.sin(lph) * 3.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 4.5 * u
        lunge = -4.5 * u
        ear_flat = 1.0 * u
        bell_swing = -4.0 * u
        sx, sy = 1.09, 0.90
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lunge = 5.0 * sm
        crouch = -1.5 * sm
        ear_flat = 1.0
        stride = 5.5 * sm
        bell_swing = 5.0 * sm
        sx, sy = 1.12, 0.89
    elif ctx.is_recover:
        crouch = 3.0
        lunge = 2.0 * (1.0 - u)
        ear_flat = 0.2
    elif ctx.is_stagger:
        crouch = 4.2
        lunge = -2.5 + math.sin(ph * 2.5) * 2.5
        ear_flat = -0.35
        bell_swing = math.sin(ph * 3.0) * 5.0

    cx = ax + (lunge if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 2.0, 21.0 if d == "side" else 17.5, 2.8, "night")

    if d == "side":
        # Stubby wagging hound-toad tail
        body.bezier_limb(
            (cx - 16, cy - 17), (cx - 21, cy - 21 + tail_wag * 0.5),
            (cx - 24, cy - 24 + tail_wag), 3.4, 1.6, HIDE, tip_col="mauve",
        )
        # Far legs
        body.capsule(cx - 12, cy - 12, cx - 15 - stride * 0.7, cy - 1, 3.4, 2.2, ("void", "night", "dusk"))
        body.capsule(cx + 9, cy - 13, cx + 11 + stride * 0.7, cy - 1, 3.6, 2.4, ("void", "night", "dusk"))
        # Hulking barrel-chested hound-toad torso
        body.shaded_ellipse(cx - 9.0, cy - 16.0, 10.5, 8.8, HIDE)
        body.shaded_ellipse(cx + 3.5, cy - 19.0, 12.0, 10.5, HIDE)
        # Near clawed legs
        body.capsule(cx - 9, cy - 12, cx - 11 + stride, cy, 3.8, 2.5, HIDE)
        body.capsule(cx + 10, cy - 13, cx + 13 - stride, cy, 4.0, 2.6, HIDE)
        body.rect(cx - 12 + stride, cy - 2, 5, 2, "stone")
        body.rect(cx + 12 - stride, cy - 2, 5, 2, "stone")

        # Heavy bronze bell-collar around thick neck
        body.shaded_ellipse(cx + 11.5, cy - 22.0, 4.8, 9.2, BRASS)
        if p2:
            body.crack(cx + 9, cy - 27, cx + 14, cy - 17, "void", "coral", seed=19)
        _draw_collar_bell(body, cx + 15.0, cy - 14.0, bell_swing, p2)

        # Broad hound-toad head + wide acoustic listening ears + stitched blindfold!
        hx, hy = cx + 16.5, cy - 27.5 - crouch * 0.15
        # Giant sweeping acoustic ears (flatten tightly back on tell/commit!)
        ear_dy = 6.5 * ear_flat
        ear_dx = -6.0 * ear_flat
        body.shaded_poly([
            (hx - 4, hy - 5), (hx - 14 + ear_dx, hy - 18 + ear_dy),
            (hx - 8 + ear_dx, hy - 7 + ear_dy * 0.5), (hx + 1, hy - 6),
        ], ("night", "dusk", "plum", "wine"))
        body.shaded_poly([
            (hx - 1, hy - 6), (hx - 10 + ear_dx, hy - 20 + ear_dy),
            (hx - 4 + ear_dx, hy - 8 + ear_dy * 0.5), (hx + 3, hy - 6),
        ], ("dusk", "plum", "rose"))

        body.shaded_ellipse(hx, hy, 8.8, 7.2, HIDE)
        # Broad snout with tusks & wet nose
        body.shaded_ellipse(hx + 7.5, hy + 2.2, 6.2, 4.4, SNOUT)
        body.rect(hx + 11.5, hy + 0.5, 3, 2, "void")
        body.set(hx + 12.0, hy + 0.5, "stone", protect=True)
        body.shaded_poly([(hx + 6, hy + 4), (hx + 8, hy + 7.5), (hx + 9.5, hy + 4)], ("stone", "cream"))
        # Stitched blindfold wrapped across eyes + streaming ribbon knot behind!
        body.shaded_rect(hx - 6.5, hy - 4.2, 13.5, 4.2, BLINDFOLD)
        body.line(hx - 5, hy - 2, hx + 6, hy - 2, "dusk")
        fx_back.bezier_limb(
            (hx - 6, hy - 2), (hx - 13, hy - 4 + tail_wag * 0.35),
            (hx - 18, hy - 1 + tail_wag * 0.5), 2.0, 1.0, BLINDFOLD,
        )
    elif d == "front":
        # Wide hulking chest, planted forelegs, giant splayed ears & massive bronze bell-collar!
        body.shaded_ellipse(cx - 13.0, cy - 11.0, 6.5, 7.5, ("void", "night", "dusk"))
        body.shaded_ellipse(cx + 13.0, cy - 11.0, 6.5, 7.5, ("void", "night", "dusk"))
        body.capsule(cx - 10, cy - 15, cx - 12, cy, 4.2, 3.0, HIDE)
        body.capsule(cx + 10, cy - 15, cx + 12, cy, 4.2, 3.0, HIDE)
        body.rect(cx - 14, cy - 2, 6, 2, "stone")
        body.rect(cx + 8, cy - 2, 6, 2, "stone")

        body.shaded_ellipse(cx, cy - 19.0, 14.5, 11.5, HIDE)
        # Thick bronze collar ring + hanging sanctuary bell
        body.shaded_ellipse(cx, cy - 23.5, 13.5, 5.2, BRASS)
        if p2:
            body.crack(cx - 8, cy - 25, cx + 7, cy - 21, "void", "coral", seed=29)
        _draw_collar_bell(body, cx, cy - 14.5, bell_swing, p2)

        hx, hy = cx, cy - 31.0 + crouch * 0.2
        ear_dy = 7.0 * ear_flat
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (hx + sgn * 7, hy - 4),
                (hx + sgn * 22, hy - 14 + ear_dy),
                (hx + sgn * 18, hy - 2 + ear_dy * 0.6),
                (hx + sgn * 8, hy + 1),
            ], HIDE)
            body.shaded_poly([
                (hx + sgn * 9, hy - 3),
                (hx + sgn * 19, hy - 11 + ear_dy),
                (hx + sgn * 15, hy - 3 + ear_dy * 0.6),
            ], ("plum", "wine", "rose"))

        body.shaded_ellipse(hx, hy, 10.5, 8.2, HIDE)
        body.shaded_ellipse(hx, hy + 4.0, 7.2, 4.4, SNOUT)
        body.rect(hx - 2, hy + 1.5, 4, 2, "void")
        body.shaded_poly([(hx - 5.5, hy + 5), (hx - 4, hy + 8.5), (hx - 2.5, hy + 5)], ("stone", "cream"))
        body.shaded_poly([(hx + 2.5, hy + 5), (hx + 4, hy + 8.5), (hx + 5.5, hy + 5)], ("stone", "cream"))
        # Stitched blindfold across brow
        body.shaded_rect(hx - 10.0, hy - 4.2, 20.0, 4.5, BLINDFOLD)
        body.line(hx - 8, hy - 2, hx + 8, hy - 2, "dusk")
        body.set(hx - 4, hy - 2, "coral" if p2 else "gold", protect=True)
        body.set(hx + 4, hy - 2, "coral" if p2 else "gold", protect=True)
    else:
        # Back view: wide haunches, knotted blindfold ribbons, bronze collar rim, wagging stubby tail
        body.shaded_ellipse(cx - 11.5, cy - 11.5, 6.8, 8.0, HIDE)
        body.shaded_ellipse(cx + 11.5, cy - 11.5, 6.8, 8.0, HIDE)
        body.capsule(cx - 10, cy - 13, cx - 11, cy, 4.0, 2.8, HIDE)
        body.capsule(cx + 10, cy - 13, cx + 11, cy, 4.0, 2.8, HIDE)
        body.shaded_ellipse(cx, cy - 19.0, 14.5, 11.5, HIDE)
        body.shaded_ellipse(cx, cy - 25.0, 13.2, 4.8, BRASS)
        hx, hy = cx, cy - 32.0 + crouch * 0.2
        ear_dy = 7.0 * ear_flat
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (hx + sgn * 7, hy - 4), (hx + sgn * 22, hy - 14 + ear_dy),
                (hx + sgn * 17, hy - 1 + ear_dy * 0.6), (hx + sgn * 8, hy + 1),
            ], HIDE)
        body.shaded_ellipse(hx, hy, 10.2, 8.0, HIDE)
        # Knotted blindfold + fluttering tails
        body.shaded_rect(hx - 9.5, hy - 4.0, 19.0, 4.0, BLINDFOLD)
        body.circle(hx, hy - 2.0, 2.5, "cream")
        body.bezier_limb((hx, hy - 1), (hx - 5 + tail_wag * 0.4, hy + 5), (hx - 8 + tail_wag * 0.6, hy + 10), 2.0, 1.0, BLINDFOLD)
        body.bezier_limb((hx, hy - 1), (hx + 5 + tail_wag * 0.4, hy + 5), (hx + 7 + tail_wag * 0.6, hy + 9), 2.0, 1.0, BLINDFOLD)
        # Stubby wagging tail
        body.bezier_limb((cx, cy - 13), (cx + tail_wag * 0.7, cy - 18), (cx + tail_wag, cy - 22), 3.6, 1.8, HIDE, tip_col="mauve")

    # Phase 2 cracked collar resonance aura
    if p2:
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 20, cy - 20 + math.sin(a) * 11, "coral" if k % 2 == 0 else "gold", protect=True)
            fx_back.ring(cx, cy - 20, 22.0 + math.sin(ph) * 1.6, "coral", 1.0, k * 90 + 12, k * 90 + 60, protect=True)

    # Telegraph / commit / stagger FX
    if ctx.is_tell and u > 0.30:
        gx = cx + (18 if d == "side" else 0)
        fx_front.ring(gx, cy - 25, 11.0 - u * 4.5, "coral" if p2 else "gold", 1.2, protect=True)
        if u > 0.65:
            fx_front.star4(gx, cy - 28, 3, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 10, cy - 18, 18, 15, -65, 65, 5.6, ("coral", "apricot", "cream"))
            fx_back.line(cx - 24, cy - 22, cx - 10, cy - 22, "gold", protect=True)
            fx_back.line(cx - 22, cy - 16, cx - 12, cy - 16, "apricot", protect=True)
        else:
            fx_front.slash_arc(cx, cy - 16, 22, 13, -155, -25, 5.6, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx + (12 if d == "side" else 0), cy - 42, 12.0, 3.6, ph)
        fx_front.ring(cx + (12 if d == "side" else 0), cy - 36, 14.0, "gold", 1.0, -35, 35, protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="toll_hound", name="The Toll-Hound", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 62),
    body_radius=11.0, hit_radius=15.0, body_centre=(42, 42),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_toll_hound,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
