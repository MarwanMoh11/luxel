#!/usr/bin/env python3
"""Island 5 Mini-Boss: The Apogee Hound (iron-crested meteor wolf with blazing furnace ribs & star tail) — 84x76, anchor [42, 62]."""
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

BASALT = ("void", "night", "deep", "blue")
IRON = ("night", "deep", "blue", "sky")
BRASS = ("plum", "coral", "apricot", "gold")
FURNACE = ("coral", "apricot", "gold", "cream")


def draw_apogee_hound(ctx: FrameCtx) -> Image.Image:
    w, h = 94, 82
    ax, ay = 47.0, 68.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = abs(math.sin(ph)) * 2.4 if ctx.anim in ("routine", "phase2") else 0.0
    stride = math.sin(ph) * 6.0 if ctx.anim in ("routine", "phase2") else 0.0
    tail_wave = math.sin(lph) * 5.0
    lunge = 0.0
    crouch = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 4.5 * u
        lunge = -5.5 * u
        sx, sy = 1.08, 0.90
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        lunge = 6.0 * sm
        crouch = -2.5 * sm
        stride = 7.0 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        lunge = 3.5 * (1.0 - u)
        crouch = 2.8
    elif ctx.is_stagger:
        lunge = -3.0 + math.sin(ph * 2.0) * 2.2
        crouch = 4.2

    cx = ax + (lunge if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 2.0, 21.0 if d == "side" else 17.0, 2.8, "night")

    if p2:
        fx_back.ring(cx, cy - 19.0, 22.0, "coral", 1.2)

    if d == "side":
        # Streaming star-comet tail behind haunches
        tx, ty = cx - 16.0, cy - 17.0
        fx_back.bezier_limb(
            (tx, ty), (tx - 9.0, ty - 6.0 + tail_wave * 0.6),
            (tx - 16.5, ty - 2.0 + tail_wave), 5.2, 1.2, ("coral", "apricot", "gold"),
            tip_col="cream", protect=True,
        )
        fx_back.bezier_limb(
            (tx, ty + 2), (tx - 7.5, ty + 4.0 + tail_wave * 0.4),
            (tx - 13.5, ty + 3.0 + tail_wave * 0.7), 2.8, 0.8, ("blue", "sky", "ice"),
            tip_col="cream", protect=True,
        )
        fx_back.star4(tx - 15.0, ty - 2.0 + tail_wave, 3, "cream", "ice")

        # Far muscular legs
        body.capsule(cx - 12, cy - 11, cx - 15 - stride * 0.7, cy - 1, 3.0, 2.0, BASALT)
        body.capsule(cx + 9, cy - 12, cx + 12 + stride * 0.7, cy - 1, 3.0, 2.0, BASALT)

        # Exposed glowing amber-gold rear ribs & furnace haunch (visual weakspot!)
        body.shaded_ellipse(cx - 11.5, cy - 15.0, 9.0, 7.2, IRON)
        body.shaded_ellipse(cx - 2.5, cy - 16.5, 10.5, 6.8, IRON)
        # Three blazing amber furnace rib slats on flank
        for ri in range(3):
            rx = cx - 11.0 + ri * 4.2
            body.line(rx, cy - 19.5, rx - 1.5, cy - 13.0, "gold" if not p2 else "cream", protect=True)
            body.line(rx + 1.0, cy - 19.0, rx - 0.5, cy - 13.5, "coral", protect=True)
        # Broad armored chest & shoulder
        body.shaded_ellipse(cx + 8.5, cy - 18.5, 9.2, 8.2, IRON, spec_col="ice")

        # Near legs with iron greaves & ice claws
        body.capsule(cx - 9, cy - 11, cx - 11 + stride, cy, 3.3, 2.1, IRON)
        body.capsule(cx + 10, cy - 12, cx + 14 - stride, cy, 3.5, 2.2, IRON)
        body.rect(cx - 13 + stride, cy - 2, 5, 3, "ice")
        body.rect(cx + 12 - stride, cy - 2, 5, 3, "ice")

        # Heavy brass astrolabe collar + dinner bell (rings when dizzy!)
        body.shaded_ellipse(cx + 12.5, cy - 21.5, 4.4, 7.8, BRASS)
        bell_x = cx + 15.5 + (math.sin(ph * 3.0) * 2.5 if ctx.is_stagger else 0.0)
        body.circle(bell_x, cy - 13.0, 2.8, "gold", protect=True)
        body.set(bell_x, cy - 13.0, "cream", protect=True)

        # Blazing comet mane crest
        ms = tail_wave * 0.4
        body.shaded_poly([
            (cx + 9, cy - 26), (cx - 6, cy - 33 + ms), (cx + 1, cy - 22),
            (cx - 9, cy - 24 + ms), (cx + 4, cy - 17), (cx + 13, cy - 19),
        ], FURNACE)

        # Heavy iron-browed meteor wolf head (front shield visor!)
        hx, hy = cx + 18.0, cy - 25.5 - crouch * 0.25
        body.shaded_poly([(hx - 7, hy - 5), (hx - 13, hy - 14 + ms * 0.3), (hx - 1, hy - 7)], IRON)
        body.shaded_poly([(hx - 3, hy - 6), (hx - 7, hy - 15 + ms * 0.3), (hx + 3, hy - 6)], ("deep", "blue", "sky", "ice"))
        body.shaded_ellipse(hx, hy, 7.5, 5.8, IRON, spec_col="ice")
        # Thick angular meteor-iron brow plate protecting snout!
        body.shaded_poly([
            (hx - 2, hy - 6.5), (hx + 9.5, hy - 3.0), (hx + 12.5, hy + 2.5),
            (hx + 8.5, hy + 5.5), (hx + 1, hy + 4.5),
        ], BASALT)
        body.line(hx, hy - 5.5, hx + 9.0, hy - 2.2, "sky")
        if p2:
            body.crack(hx + 1, hy - 4, hx + 9, hy + 2, "void", "coral", seed=23)
        body.eye(hx + 2.5, hy - 1.5, "cream" if (ctx.is_tell or p2) else "gold", "cream", "void", 3, 2)
    elif d == "front":
        # Towering armored front view: iron brow helm & brass astrolabe collar dominant!
        fx_back.bezier_limb(
            (cx, cy - 24), (cx + 11 + tail_wave * 0.8, cy - 38), (cx + 3 + tail_wave, cy - 45),
            4.8, 1.2, ("coral", "apricot", "gold"), tip_col="cream", protect=True,
        )
        # Wide rear haunches
        body.shaded_ellipse(cx - 13.0, cy - 11.5, 6.2, 7.5, BASALT)
        body.shaded_ellipse(cx + 13.0, cy - 11.5, 6.2, 7.5, BASALT)
        # Planted armored forelegs
        body.capsule(cx - 8, cy - 15, cx - 10.5, cy, 3.8, 2.5, IRON)
        body.capsule(cx + 8, cy - 15, cx + 10.5, cy, 3.8, 2.5, IRON)
        body.rect(cx - 12.5, cy - 2, 5, 3, "ice")
        body.rect(cx + 7.5, cy - 2, 5, 3, "ice")
        # Broad chest + brass astrolabe collar + hanging collar bell
        body.shaded_ellipse(cx, cy - 18.0, 12.8, 9.6, IRON, spec_col="ice")
        body.ring(cx, cy - 22.5, 11.2, "gold", 2.4)
        body.circle(cx + (math.sin(ph * 3.0) * 2.5 if ctx.is_stagger else 0.0), cy - 13.0, 3.2, "gold", protect=True)
        body.set(cx, cy - 13.0, "cream", protect=True)
        # Swept blazing comet ruff
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (cx + sgn * 6, cy - 27), (cx + sgn * 17, cy - 33 + tail_wave * 0.25),
                (cx + sgn * 14, cy - 24), (cx + sgn * 19, cy - 19 + tail_wave * 0.2),
                (cx + sgn * 11, cy - 17), (cx + sgn * 6, cy - 20),
            ], FURNACE)
        # Armored iron-browed wolf head
        hx, hy = cx, cy - 29.0 + crouch * 0.3
        body.shaded_poly([(hx - 7, hy - 4), (hx - 13, hy - 16), (hx - 3, hy - 7)], IRON)
        body.shaded_poly([(hx + 7, hy - 4), (hx + 13, hy - 16), (hx + 3, hy - 7)], IRON)
        body.shaded_ellipse(hx, hy, 9.5, 7.6, BASALT, spec_col="sky")
        # Jagged iron meteor crest plate across brow & snout
        body.shaded_poly([
            (hx - 8.5, hy - 4.0), (hx, hy - 8.5), (hx + 8.5, hy - 4.0),
            (hx + 5.5, hy + 5.5), (hx - 5.5, hy + 5.5),
        ], IRON)
        body.line(hx - 6.0, hy - 3.5, hx + 6.0, hy - 3.5, "ice")
        if p2:
            body.crack(hx - 4, hy - 6, hx + 4, hy + 3, "void", "coral", seed=29)
        body.eye(hx - 5.2, hy - 1.5, "cream" if p2 else "gold", "cream", "void", 3, 2)
        body.eye(hx + 2.2, hy - 1.5, "cream" if p2 else "gold", "cream", "void", 3, 2)
    else:
        # Back view: glowing amber furnace ribs & sweeping star-comet tail clearly readable as rear weakspot!
        body.shaded_ellipse(cx - 11.5, cy - 11.5, 6.6, 8.0, IRON)
        body.shaded_ellipse(cx + 11.5, cy - 11.5, 6.6, 8.0, IRON)
        body.capsule(cx - 9, cy - 13, cx - 10.5, cy, 3.6, 2.4, IRON)
        body.capsule(cx + 9, cy - 13, cx + 10.5, cy, 3.6, 2.4, IRON)
        body.shaded_ellipse(cx, cy - 19.0, 12.8, 10.0, IRON)
        # Glowing exposed amber rear core ribs
        body.shaded_ellipse(cx, cy - 17.5, 7.2, 5.2, FURNACE, spec_col="cream")
        body.shaded_ellipse(cx, cy - 28.0, 9.8, 7.2, BASALT)
        body.shaded_poly([(cx - 7, cy - 32), (cx - 13, cy - 43), (cx - 3, cy - 33)], IRON)
        body.shaded_poly([(cx + 7, cy - 32), (cx + 13, cy - 43), (cx + 3, cy - 33)], IRON)
        body.shaded_ellipse(cx, cy - 25.5, 14.0, 4.4, FURNACE)
        body.bezier_limb(
            (cx, cy - 14), (cx + tail_wave, cy - 28), (cx - tail_wave * 0.6, cy - 40),
            5.2, 1.3, ("coral", "apricot", "gold"), tip_col="cream", protect=True,
        )
        fx_front.star4(cx - tail_wave * 0.6, cy - 40, 3, "cream", "ice")

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.32:
        gx = cx + (18 if d == "side" else 0)
        fx_front.star4(gx, cy - 27, 4 if u > 0.70 else 2, "cream", "gold")
        fx_back.ring(cx, cy - 16, 19.0 - u * 5.0, "gold" if p2 else "sky", 1.4)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 18, 20, 14, -62, 58, 6.0, ("coral", "gold", "cream"))
            fx_back.line(cx - 26, cy - 20, cx - 10, cy - 20, "gold", protect=True)
            fx_back.line(cx - 24, cy - 14, cx - 12, cy - 14, "ice", protect=True)
        else:
            fx_front.slash_arc(cx, cy - 18, 21, 14, -155, -25, 5.8, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx + (10 if d == "side" else 0), cy - 40, 12.0, 3.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="apogee_hound", name="The Apogee Hound", out_dir=ART_BOSSES,
    frame=(94, 82), anchor=(47, 68),
    body_radius=10.5, hit_radius=15.0, body_centre=(47, 46),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_apogee_hound,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
