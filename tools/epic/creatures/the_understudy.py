#!/usr/bin/env python3
"""Island 7 Boss: The Understudy (Moth-duelist in gilded wine-velvet cloak, porcelain theatre mask, chest move-medallion) — 80x84, anchor [40, 70]."""
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

CLOAK = ("void", "night", "plum", "wine")
VELVET_BRIGHT = ("plum", "wine", "coral", "apricot")
GOLD_TRIM = ("wine", "apricot", "gold", "cream")
PORCELAIN = ("sky", "ice", "cream")
SHADOW_STEEL = ("night", "deep", "blue", "ice")


def draw_the_understudy(ctx: FrameCtx) -> Image.Image:
    w, h = 80, 84
    ax, ay = 40.0, 70.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    stride = math.sin(ph) * 2.2
    cape_billow = math.sin(lph) * 3.5
    lean_x = 0.0
    bob = abs(math.sin(ph)) * 1.6
    sword_raise = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean_x = -4.0 * u if d == "side" else 0.0
        sword_raise = -9.0 * u
        cape_billow = -6.0 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        lean_x = 8.0 * sm if d == "side" else 0.0
        sword_raise = 6.0 * sm
        cape_billow = 8.0 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        # Theatrical low flourish bow during punish window!
        bob = -3.0
        sword_raise = 5.0
        lean_x = 2.0 if d == "side" else 0.0
    elif ctx.is_stagger:
        bob = -4.0
        sword_raise = 8.0
        sx, sy = 1.08, 0.90

    cx = ax + lean_x
    cy = ay - 3.0 - bob

    # Theatrical spotlight shadow
    shadow.contact_shadow(ax + 2.0, ay + 2.0, 14.0, 3.0, "night")

    # Dramatic sweeping gilded opera cloak (asymmetrical flaring silhouette!)
    cape_w = 18.0 if d != "side" else 14.0
    if d != "side":
        fx_back.shaded_poly([
            (cx - 9, cy - 35), (cx + 9, cy - 35),
            (cx + cape_w + cape_billow * 0.5, cy - 12),
            (cx + cape_w + 2 + cape_billow, cy + 1),
            (cx + 6, cy - 3), (cx, cy), (cx - 6, cy - 3),
            (cx - cape_w - 2 + cape_billow * 0.5, cy + 1),
            (cx - cape_w, cy - 12),
        ], CLOAK)
        fx_back.line(cx - cape_w - 1, cy, cx + cape_w + 1, cy, "gold", protect=True)
    else:
        fx_back.shaded_poly([
            (cx - 2, cy - 35), (cx - 18 - cape_billow, cy - 22),
            (cx - 23 - cape_billow, cy - 2), (cx - 7, cy + 1), (cx + 4, cy - 10),
        ], CLOAK)
        fx_back.line(cx - 22 - cape_billow, cy - 2, cx - 7, cy + 1, "gold", protect=True)

    # Agile duelist boots
    if d != "side":
        body.capsule(cx - 4.5, cy - 10, cx - 5.5, cy + stride * 0.5, 2.3, 1.8, CLOAK)
        body.capsule(cx + 4.5, cy - 10, cx + 5.5, cy - stride * 0.5, 2.3, 1.8, CLOAK)
    else:
        body.capsule(cx - 2.0, cy - 10, cx - 5.0 - stride, cy + 0.5, 2.4, 1.8, CLOAK)
        body.capsule(cx + 2.0, cy - 10, cx + 6.0 + stride, cy + 0.5, 2.4, 1.8, CLOAK)

    # Fitted wine-velvet duelist doublet + gilded shoulder mantle
    body.shaded_poly([
        (cx - 9, cy - 33), (cx + 9, cy - 33),
        (cx + 7, cy - 11), (cx - 7, cy - 11),
    ], VELVET_BRIGHT if p2 else CLOAK)
    body.shaded_poly([
        (cx - 12, cy - 34), (cx - 5, cy - 41), (cx, cy - 34),
        (cx + 5, cy - 41), (cx + 12, cy - 34), (cx + 8, cy - 29), (cx - 8, cy - 29),
    ], GOLD_TRIM)

    # Chest Move-Medallion (pulses with stolen ability!)
    if d != "back":
        mx = cx + (3.0 if d == "side" else 0.0)
        my = cy - 23.0
        body.circle(mx, my, 4.2, "void", protect=True)
        body.ring(mx, my, 4.0, "gold", 1.2)
        med_col = "coral" if (ctx.is_tell or p2) else "ice"
        body.circle(mx, my, 2.3, med_col, protect=True)
        body.set(mx, my, "cream", protect=True)

    # Duelist arms & gleaming Stage-Lantern Foil / Ribbon
    if d != "side":
        # Left arm clutching cloak edge / spotlight ribbon
        body.capsule(cx - 9, cy - 31, cx - 16, cy - 21 + sword_raise * 0.5, 2.2, 1.5, CLOAK)
        # Right fencing arm holding stolen-light lantern blade
        rx, ry = cx + 15.0, cy - 24.0 + sword_raise
        body.capsule(cx + 9, cy - 31, rx, ry, 2.2, 1.5, CLOAK)
        fx_front.line(rx, ry, rx + 8, ry - 15, "ice", protect=True)
        fx_front.line(rx + 1, ry, rx + 9, ry - 15, "cream", protect=True)
        fx_front.circle(rx, ry, 2.5, "gold", protect=True)
    else:
        rx, ry = cx + 13.0, cy - 25.0 + sword_raise
        body.capsule(cx + 3, cy - 31, rx, ry, 2.3, 1.6, CLOAK)
        fx_front.line(rx, ry, rx + 18, ry - 4, "ice", protect=True)
        fx_front.line(rx, ry - 1, rx + 18, ry - 5, "cream", protect=True)
        fx_front.circle(rx, ry, 2.6, "gold", protect=True)

    # Porcelain Theatre Mask & Moth Antenna Plumes
    hx = cx + (2.0 if d == "side" else 0.0)
    hy = cy - 42.0
    # Tall moth antennae curving out behind the mask
    fx_back.bezier_limb((hx - 3, hy - 6), (hx - 9, hy - 14), (hx - 12, hy - 18), 1.6, 0.8, GOLD_TRIM, tip_col="cream")
    fx_back.bezier_limb((hx + 3, hy - 6), (hx + 9, hy - 14), (hx + 12, hy - 18), 1.6, 0.8, GOLD_TRIM, tip_col="cream")

    body.shaded_ellipse(hx, hy, 6.8, 7.6, PORCELAIN if d != "back" else CLOAK, spec_col="cream")
    if d == "front":
        body.line(hx - 5, hy - 6, hx + 5, hy - 6, "gold", protect=True)
        body.eye(hx - 2.8, hy - 0.8, "void", "coral" if p2 else "gold", "void", 2, 2)
        body.eye(hx + 2.2, hy - 0.8, "void", "coral" if p2 else "gold", "void", 2, 2)
        # Serene painted theatrical smirk
        body.line(hx - 2.0, hy + 3.5, hx + 2.0, hy + 3.5, "wine", protect=True)
    elif d == "side":
        body.eye(hx + 3.0, hy - 0.8, "void", "coral" if p2 else "gold", "void", 2, 2)
        body.line(hx + 1.0, hy + 3.5, hx + 5.0, hy + 3.0, "wine", protect=True)
    else:
        body.shaded_poly([(hx - 5, hy - 4), (hx + 5, hy - 4), (hx, hy + 5)], GOLD_TRIM)

    # Hovering stolen-move Spotlight Mask charm in P2/Tell!
    if p2 or ctx.is_tell:
        my_f = hy - 10.0 + math.sin(ph * 1.5) * 2.0
        mx_f = cx - 16.0 if d != "side" else cx + 16.0
        fx_front.line(cx, cy - 23, mx_f, my_f, "gold", protect=True)
        fx_front.shaded_ellipse(mx_f, my_f, 4.2, 4.8, PORCELAIN)
        fx_front.ring(mx_f, my_f, 5.8, "coral" if p2 else "gold", 1.0)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.25:
        fx_front.star4(hx, hy - 10, 3 if u > 0.65 else 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (15 if d == "side" else 4), cy - 24, 24, 16, -65, 65, 5.5, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        # Mask visibly cracks cleanly down the middle during standing-ovation stagger!
        body.crack(hx - 3, hy - 6, hx + 3, hy + 6, "void", "coral", seed=71)
        fx_front.dizzy_stars(hx, hy - 14, 10.0, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="the_understudy", name="The Understudy", out_dir=ART_BOSSES,
    frame=(80, 84), anchor=(40, 70),
    body_radius=10.5, hit_radius=14.5, body_centre=(40, 44),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="night",
    draw_frame=draw_the_understudy,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
