#!/usr/bin/env python3
"""Island 7 Enemy: Puppet (Tethered Porcelain Marionette with rose-gold cords & cross-bar) — 62x58, anchor [31, 48]."""
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

VELVET = ("night", "plum", "wine", "rose")
PORCELAIN = ("mauve", "stone", "ice", "cream")
GOLD_TRIM = ("wine", "apricot", "gold", "cream")


def draw_puppet(ctx: FrameCtx) -> Image.Image:
    w, h = 68, 72
    ax, ay = 34.0, 58.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    sway = math.sin(ph) * 2.5 if ctx.anim == "routine" else 0.0
    jerk = math.sin(lph) * 2.2
    slump = 0.0
    arm_lift = math.sin(ph) * 3.0
    slash = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Strings yank violently taut!
        slump = -3.0 * u
        arm_lift = -7.0 * u
        sx, sy = 0.92, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        slash = sm
        arm_lift = 6.0 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        slump = 3.5
        arm_lift = 5.0
    elif ctx.is_stagger:
        # Cord cut / slumped collapsed doll!
        slump = 6.0
        arm_lift = 5.0
        sway = math.sin(ph * 2.0) * 1.5
        sx, sy = 1.08, 0.88

    cx = ax + sway
    cy = ay - 3.0 + slump
    shadow.contact_shadow(ax, ay + 1.5, 9.0, 1.8, "night")

    # Overhead marionette cross-bar & taut rose-gold strings (iconic silhouette!)
    if not ctx.is_stagger:
        bar_y = 14.0 + (math.sin(ph) * 1.0 if ctx.anim == "routine" else (-1.5 if ctx.is_tell else 0.0))
        body.capsule(ax - 11, bar_y, ax + 11, bar_y, 1.3, 1.3, GOLD_TRIM)
        body.capsule(ax, bar_y - 2.5, ax, bar_y + 2.5, 1.2, 1.2, GOLD_TRIM)
        str_col = "cream" if (ctx.is_tell and u > 0.5) else "rose"
        fx_back.line(ax - 8, bar_y + 1, cx - (9 if d != "side" else 2), cy - 14 + arm_lift * 0.4, str_col, protect=True)
        fx_back.line(ax + 8, bar_y + 1, cx + (9 if d != "side" else 8), cy - 14 - arm_lift * 0.4, str_col, protect=True)
        fx_back.line(ax, bar_y + 1, cx, cy - 26, "gold", protect=True)
    else:
        # Snapped curly thread stubs!
        fx_front.bezier_limb((cx - 6, cy - 15), (cx - 10, cy - 21), (cx - 7, cy - 24), 0.9, 0.5, ("wine", "rose"), tip_col="gold")
        fx_front.bezier_limb((cx + 6, cy - 15), (cx + 10, cy - 20), (cx + 8, cy - 24), 0.9, 0.5, ("wine", "rose"), tip_col="gold")

    # Dangling jointed legs with porcelain ball-knees
    leg_l = math.sin(ph) * 2.5 if ctx.anim == "routine" else 0.0
    body.capsule(cx - 4, cy - 8, cx - 5 - leg_l, cy - 1, 1.5, 1.3, PORCELAIN)
    body.capsule(cx + 4, cy - 8, cx + 5 + leg_l, cy - 1, 1.5, 1.3, PORCELAIN)
    body.circle(cx - 4.5 - leg_l * 0.5, cy - 4.5, 1.6, "gold")
    body.circle(cx + 4.5 + leg_l * 0.5, cy - 4.5, 1.6, "gold")

    # Harlequin wine-velvet marionette bodice with diamond ruffle skirt
    body.shaded_poly([
        (cx - 6, cy - 20), (cx + 6, cy - 20), (cx + 8, cy - 10),
        (cx + 10, cy - 6), (cx + 4, cy - 8), (cx, cy - 5),
        (cx - 4, cy - 8), (cx - 10, cy - 6), (cx - 8, cy - 10),
    ], VELVET)
    body.shaded_poly([(cx - 5, cy - 20), (cx + 5, cy - 20), (cx, cy - 14)], GOLD_TRIM)
    body.set(cx, cy - 12, "gold", protect=True)
    body.set(cx, cy - 9, "cream", protect=True)

    # Articulated jointed porcelain arms & twin scissor-blades
    if d != "side":
        l_hand = (cx - 11, cy - 12 + arm_lift)
        r_hand = (cx + 11, cy - 12 - arm_lift)
        body.capsule(cx - 6, cy - 18, l_hand[0], l_hand[1], 1.5, 1.3, PORCELAIN)
        body.capsule(cx + 6, cy - 18, r_hand[0], r_hand[1], 1.5, 1.3, PORCELAIN)
        body.circle(cx - 8.5, cy - 15 + arm_lift * 0.5, 1.6, "gold")
        body.circle(cx + 8.5, cy - 15 - arm_lift * 0.5, 1.6, "gold")
        # Twin needle-blades
        body.line(l_hand[0], l_hand[1], l_hand[0] - 4, l_hand[1] + 5, "ice", protect=True)
        body.line(r_hand[0], r_hand[1], r_hand[0] + 4, r_hand[1] + 5, "ice", protect=True)
    else:
        fx_back.capsule(cx - 1, cy - 17, cx + 6 + slash * 5, cy - 14 - arm_lift * 0.5, 1.4, 1.2, PORCELAIN)
        hand_x = cx + 8 + slash * 8
        hand_y = cy - 13 + arm_lift * 0.4
        body.capsule(cx + 1, cy - 18, hand_x, hand_y, 1.6, 1.3, PORCELAIN)
        body.circle(cx + 4.5 + slash * 3, cy - 15.5, 1.6, "gold")
        body.shaded_poly([(hand_x, hand_y - 1.5), (hand_x + 9, hand_y + 1), (hand_x + 1, hand_y + 2.5)], ("sky", "ice", "cream"))

    # Tilted porcelain doll-moth head (with uncanny painted smile & rose cheeks)
    hx = cx + (1.5 if d == "side" else jerk * 0.5)
    hy = cy - 26.0
    body.shaded_ellipse(hx, hy, 6.2, 6.0, PORCELAIN, spec_col="cream")
    # Small lace bow / moth ears
    body.shaded_poly([(hx - 5, hy - 5), (hx - 9, hy - 8), (hx - 4, hy - 2)], VELVET)
    body.shaded_poly([(hx + 5, hy - 5), (hx + 9, hy - 8), (hx + 4, hy - 2)], VELVET)

    if d == "front":
        body.eye(hx - 2.8, hy - 0.5, "wine", "cream", "void", 2, 2)
        body.eye(hx + 1.8, hy - 0.5, "wine", "cream", "void", 2, 2)
        body.set(hx - 4, hy + 1.5, "rose", protect=True)
        body.set(hx + 4, hy + 1.5, "rose", protect=True)
        body.line(hx - 2, hy + 2.8, hx + 2, hy + 2.8, "void", protect=True)
    elif d == "side":
        body.eye(hx + 2.5, hy - 0.5, "wine", "cream", "void", 2, 2)
        body.set(hx + 2.0, hy + 2.0, "rose", protect=True)
    else:
        body.line(hx - 3, hy - 3, hx + 3, hy + 3, "plum")
        body.circle(hx, hy, 2.0, "gold")

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.35:
        fx_front.star4(ax, 14.0, 2, "cream", "rose")
        fx_front.star4(cx + (12 if d == "side" else 0), cy - 14, 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 10, cy - 13, 15, 11, -55, 55, 4.8, ("wine", "rose", "cream"))
            fx_front.slash_arc(cx + 12, cy - 13, 12, 8, -35, 35, 3.0, ("gold", "cream", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 12, 16, 10, -25, 205, 4.6, ("wine", "rose", "cream"))
    elif ctx.is_stagger:
        body.crack(hx - 3, hy - 3, hx + 2, hy + 3, "void", "rose", seed=31)
        fx_front.dizzy_stars(hx, hy - 9, 7.5, 2.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="puppet", name="Puppet", out_dir=ART_ENEMIES,
    frame=(68, 72), anchor=(34, 58),
    body_radius=6.5, hit_radius=10.0, body_centre=(34, 41),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_puppet,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
