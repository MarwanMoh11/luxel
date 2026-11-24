#!/usr/bin/env python3
"""Island 3 Enemy: Jumping Spider (pit-vaulting orb-weaver with 4 ice eyes & silk) — 58x48, anchor [29, 38]."""
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

BODY = ("void", "night", "dusk", "plum")
MARK = ("dusk", "plum", "mauve", "stone")
LEG = ("night", "plum", "mauve", "stone")


def draw_jumping_spider(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 54
    ax, ay = 32.0, 44.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hop = abs(math.sin(ph)) * 1.8 if ctx.anim == "routine" else 0.0
    stride = math.sin(ph) * 2.6 if ctx.anim == "routine" else 0.0
    crouch = 0.0
    leap_y = 0.0
    lunge = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 3.5 * u
        sx, sy = 1.12, 0.86
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.35) * math.pi)
        leap_y = 9.0 * sm
        lunge = 5.5 * sm
        sx, sy = 0.93, 1.12
    elif ctx.is_recover:
        crouch = 2.8
        sx, sy = 1.10, 0.90
    elif ctx.is_stagger:
        crouch = 2.0
        lunge = math.sin(ph * 2.0) * 1.8

    cx = ax + (lunge if d == "side" else 0.0)
    cy = ay - hop - leap_y + crouch
    shadow.contact_shadow(ax, ay + 1.0, 11.5 - leap_y * 0.35, 1.8, "night")

    # Taut vertical silk guide-thread in tell
    if ctx.is_tell:
        fx_back.line(cx, cy - 16, cx, 7, "ice", protect=True)

    if d == "side":
        # 4 articulated spring legs on near/far side
        for k, (ox, reach_x, knee_y) in enumerate([(-6, -13, -15), (-2, -8, -17), (3, 10, -16), (6, 15, -14)]):
            st = stride * (1.0 if k % 2 == 0 else -1.0)
            foot_y = cy - (4.5 if ctx.is_commit else 0.0)
            body.bezier_limb(
                (cx + ox, cy - 9.0),
                (cx + ox + (reach_x - ox) * 0.5, cy + knee_y - crouch * 0.6),
                (cx + reach_x + st, foot_y),
                1.7, 0.8, LEG, tip_col="stone",
            )
        # Plump banded orb abdomen behind + head thorax in front
        body.shaded_ellipse(cx - 6.5, cy - 11.5, 7.6, 6.4, BODY)
        body.ring(cx - 7.5, cy - 12.0, 4.6, "mauve", 1.2, -50, 70)
        body.circle(cx - 13.5, cy - 10.5, 1.5, "ice", protect=True)  # Spinneret
        body.shaded_ellipse(cx + 4.5, cy - 10.0, 5.4, 4.8, BODY)
        # Pair of side jewel ice eyes + small fangs
        body.eye(cx + 5.5, cy - 11.5, "ice", "cream", "void", 2, 2)
        body.eye(cx + 8.0, cy - 10.5, "sky", "cream", "void", 2, 1)
        body.rect(cx + 8.5, cy - 7.5, 2, 2, "coral")
    elif d == "front":
        # Wide symmetrical splayed arachnid spring-legs (distinct crab/spider silhouette!)
        for sgn in (-1.0, 1.0):
            for k, (kx, ky, fx_p) in enumerate([(11, -18, 16), (13, -15, 18), (9, -12, 13)]):
                st = math.sin(ph + k * 1.5) * 1.8 * sgn
                foot_y = cy - (4.0 if ctx.is_commit else 0.0) + k * 0.8
                body.bezier_limb(
                    (cx + sgn * 5.0, cy - 9.0),
                    (cx + sgn * kx, cy + ky - crouch * 0.7),
                    (cx + sgn * fx_p, foot_y + st * 0.4),
                    1.7, 0.8, LEG, tip_col="stone",
                )
        # Rear plump abdomen peaking over cephalothorax
        body.shaded_ellipse(cx, cy - 14.5, 8.2, 6.4, BODY)
        body.shaded_ellipse(cx, cy - 15.8, 4.5, 2.2, MARK)
        body.shaded_ellipse(cx, cy - 9.5, 6.8, 5.4, BODY)
        # 4 iconic gleaming ice jewel eyes (2 large central + 2 outer!)
        body.eye(cx - 3.5, cy - 11.0, "ice", "cream", "void", 2, 2)
        body.eye(cx + 1.5, cy - 11.0, "ice", "cream", "void", 2, 2)
        body.set(cx - 5.5, cy - 10.0, "sky", protect=True)
        body.set(cx + 5.0, cy - 10.0, "sky", protect=True)
        # Chelicerae fangs
        body.rect(cx - 3, cy - 6, 2, 2, "coral")
        body.rect(cx + 1, cy - 6, 2, 2, "coral")
    else:
        # Back view: banded orb abdomen + glowing ice silk spinneret + legs
        for sgn in (-1.0, 1.0):
            for k, (kx, ky, fx_p) in enumerate([(11, -18, 16), (13, -14, 18), (9, -11, 13)]):
                st = math.sin(ph + k * 1.5) * 1.6
                body.bezier_limb(
                    (cx + sgn * 5.0, cy - 9.0),
                    (cx + sgn * kx, cy + ky - crouch * 0.6),
                    (cx + sgn * fx_p, cy + st * 0.4),
                    1.7, 0.8, LEG, tip_col="stone",
                )
        body.shaded_ellipse(cx, cy - 11.5, 8.6, 7.0, BODY)
        body.shaded_poly([(cx - 4, cy - 15), (cx, cy - 18), (cx + 4, cy - 15), (cx, cy - 11)], MARK)
        body.circle(cx, cy - 7.0, 2.0, "ice", protect=True)

    if ctx.is_tell and u > 0.35:
        fx_front.star4(cx + (6 if d == "side" else 0), cy - 14, 3 if u > 0.72 else 2, "cream", "gold")
        fx_back.ring(ax, ay - 3.0, 9.5 - u * 3.0, "coral", 1.0)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 9, 13, 11, -55, 65, 4.4, ("sky", "ice", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 6, 16, 10, 10, 170, 4.4, ("sky", "ice", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 22.0, 8.0, 2.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="jumping_spider", name="Jumping Spider", out_dir=ART_ENEMIES,
    frame=(64, 54), anchor=(32, 44),
    body_radius=6.0, hit_radius=9.5, body_centre=(32, 33),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_jumping_spider,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
