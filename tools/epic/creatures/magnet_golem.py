#!/usr/bin/env python3
"""Island 6 Enemy: Magnet Golem (boxy iron-and-mauve coil golem crowned by a massive coral/sky U-horseshoe magnet) — 66x64, anchor [33, 54]."""
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

IRON = ("void", "night", "dusk", "mauve")
SLATE = ("night", "dusk", "mauve", "stone")
POLE_RED = ("plum", "wine", "coral", "apricot")
POLE_BLUE = ("deep", "blue", "sky", "ice")


def draw_magnet_golem(ctx: FrameCtx) -> Image.Image:
    w, h = 66, 64
    ax, ay = 33.0, 54.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = abs(math.sin(ph)) * 1.2 if ctx.anim == "routine" else 0.0
    arm_lift = 0.0
    lean = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        arm_lift = -5.5 * u
        sx, sy = 1.06, 0.95
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.4) * math.pi)
        arm_lift = -7.0 * sm
        lean = 2.5 * sm
        sx, sy = 1.08, 0.94
    elif ctx.is_recover:
        arm_lift = 3.0
        sx, sy = 0.96, 1.04
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.0) * 2.5
        arm_lift = 2.0
        sx, sy = 0.95, 1.05

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob
    shadow.contact_shadow(ax, ay + 1.0, 13.0, 2.3, "night")

    # Heavy blocky iron feet
    step = math.sin(ph) * 2.0 if ctx.anim == "routine" else 0.0
    if d == "side":
        body.shaded_rect(cx - 6 + step, ay - 6, 5, 6, IRON)
        body.shaded_rect(cx + 2 - step, ay - 6, 5, 6, SLATE)
    else:
        body.shaded_rect(cx - 9, ay - 6 + step * 0.5, 6, 6, SLATE)
        body.shaded_rect(cx + 3, ay - 6 - step * 0.5, 6, 6, SLATE)

    # Boxy riveted copper-coil torso
    tw = 20 if d != "side" else 16
    body.shaded_rect(cx - tw * 0.5, cy - 26, tw, 20, SLATE)
    body.shaded_rect(cx - tw * 0.5 + 2, cy - 24, tw - 4, 16, IRON)
    # Horizontal copper/brass induction coils wrapped around chest
    for ry in (-21, -17, -13):
        body.line(cx - tw * 0.5 + 2, cy + ry, cx + tw * 0.5 - 3, cy + ry, "apricot")
    # Glowing core chest furnace/magnetic inductor
    if d == "front":
        body.rect(cx - 4, cy - 21, 8, 6, "void", protect=True)
        body.rect(cx - 3, cy - 20, 6, 4, "sky" if not ctx.is_stagger else "coral", protect=True)
        body.rect(cx - 1, cy - 19, 2, 2, "cream", protect=True)
        # Single Cyclops gauge eye above coils
        body.eye(cx - 1, cy - 24.5, "ice", "cream", "void", 3, 2)
    elif d == "side":
        body.rect(cx + 2, cy - 21, 5, 6, "void", protect=True)
        body.rect(cx + 3, cy - 20, 3, 4, "sky" if not ctx.is_stagger else "coral", protect=True)
        body.eye(cx + 4, cy - 24.5, "ice", "cream", "void", 2, 2)
    else:
        # Rear riveted power-box panel
        body.shaded_rect(cx - 6, cy - 22, 12, 10, IRON)
        body.line(cx - 4, cy - 18, cx + 4, cy - 18, "sky")

    # Boxy coil arms
    if d != "side":
        body.shaded_rect(cx - 14, cy - 22 + arm_lift, 5, 13, SLATE)
        body.shaded_rect(cx + 9, cy - 22 + arm_lift, 5, 13, SLATE)
        body.rect(cx - 14, cy - 11 + arm_lift, 5, 3, "coral")
        body.rect(cx + 9, cy - 11 + arm_lift, 5, 3, "sky")
    else:
        body.shaded_rect(cx + 1, cy - 21 + arm_lift, 6, 13, SLATE)
        body.rect(cx + 2, cy - 11 + arm_lift, 5, 3, "sky")

    # MASSIVE unmistakable U-shaped HORSESHOE MAGNET CROWN!
    my = cy - 27.0
    if d != "side":
        # Base bridge of U-magnet
        body.shaded_rect(cx - 12, my - 4, 24, 5, IRON)
        # Left prong (coral red pole + cream/stone tip)
        body.shaded_rect(cx - 13, my - 17, 5, 14, POLE_RED)
        body.shaded_rect(cx - 13, my - 20, 5, 4, ("mauve", "stone", "cream"))
        # Right prong (sky blue pole + ice/cream tip)
        body.shaded_rect(cx + 8, my - 17, 5, 14, POLE_BLUE)
        body.shaded_rect(cx + 8, my - 20, 5, 4, ("sky", "ice", "cream"))
        if ctx.is_stagger:
            body.crack(cx - 6, my - 4, cx + 5, my, "void", "ice", seed=13)
    else:
        # Side view: U-magnet angled forward so both coral & sky prongs read unmistakably!
        body.shaded_rect(cx - 7, my - 4, 14, 5, IRON)
        body.shaded_rect(cx - 8, my - 17, 5, 14, POLE_RED)
        body.shaded_rect(cx - 8, my - 20, 5, 4, ("mauve", "stone", "cream"))
        body.shaded_rect(cx + 3, my - 17, 5, 14, POLE_BLUE)
        body.shaded_rect(cx + 3, my - 20, 5, 4, ("sky", "ice", "cream"))
        if ctx.is_stagger:
            body.crack(cx - 3, my - 4, cx + 3, my, "void", "ice", seed=13)

    # Crackling electric arcs between magnet prongs & magnetic pull rings
    p_left = cx - (6 if d == "side" else 10)
    p_right = cx + (5 if d == "side" else 10)
    arc_y = my - 19.0
    if ctx.anim == "routine" and ctx.fi % 2 == 0:
        fx_front.line(p_left + 2, arc_y, cx, arc_y - 2, "sky", protect=True)
        fx_front.line(cx, arc_y - 2, p_right - 2, arc_y, "ice", protect=True)
    elif ctx.is_tell:
        zig = 3.0 if (ctx.fi % 2 == 0) else -3.0
        fx_front.line(p_left + 2, arc_y, cx, arc_y + zig, "cream", protect=True)
        fx_front.line(cx, arc_y + zig, p_right - 2, arc_y, "gold", protect=True)
        if u > 0.4:
            fx_front.star4(cx, arc_y, 2, "cream", "sky")
        fx_back.ring(cx, cy - 18, 22.0 - u * 8.0, "sky", 1.0, 0, 360, protect=True)
    elif ctx.is_commit:
        r_in = 22.0 - (u * 14.0)
        fx_back.ring(cx, cy - 18, max(7.0, r_in), "ice", 1.5, 0, 360, protect=True)
        fx_front.line(p_left + 2, arc_y, cx, arc_y - 3, "cream", protect=True)
        fx_front.line(cx, arc_y - 3, p_right - 2, arc_y, "ice", protect=True)
        fx_front.star4(cx, arc_y - 1, 3, "cream", "gold")
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, my - 22, 9.5, 3.0, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="magnet_golem", name="Magnet Golem", out_dir=ART_ENEMIES,
    frame=(66, 64), anchor=(33, 54),
    body_radius=7.5, hit_radius=12.0, body_centre=(33, 36),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_magnet_golem,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6")
