#!/usr/bin/env python3
"""Island 6 Iron Collision Skirmish Boss: Iron Phantom (Hollow Wick dark-cloaked twin carrying a black-glass unlit lantern with violet-coral temper sparks) — 64x62, anchor [32, 50]."""
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

CLOAK = ("void", "night", "dusk", "plum")
TRIM = ("night", "plum", "wine", "rose")
BLACK_GLASS = ("void", "night", "plum", "mauve")


def draw_hollow_ram_phantom(ctx: FrameCtx) -> Image.Image:
    w, h = 72, 68
    ax, ay = 36.0, 54.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.0 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    crouch = 0.0
    cloak_billow = math.sin(lph) * 4.0
    lan_x, lan_y = 12.0, -14.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 2.8 * u
        lean = -4.0 * u
        lan_x = 8.0 - 5.0 * u
        lan_y = -18.0 - 4.0 * u
        sx, sy = 0.92, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lean = 7.5 * sm
        lan_x = 16.0 + 4.0 * sm
        lan_y = -15.0
        sx, sy = 1.14, 0.89
    elif ctx.is_recover:
        crouch = 2.6
        lean = 2.0
        lan_x = 10.0
        lan_y = -10.0
    elif ctx.is_stagger:
        # Hood slips back slightly — exposing Wick's identical violet-ash eyes!
        lean = -3.0 + math.sin(ph * 2.0) * 2.0
        crouch = 3.0
        lan_x = 9.0
        lan_y = -9.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - hover + crouch
    shadow.contact_shadow(ax, ay + 1.5, 11.0, 2.0, "night")

    # Wind-swept tattered dark cloak tail (secondary motion using lag_phase!)
    tail_dir = -1.0 if d == "side" else 0.0
    body.shaded_poly([
        (cx - 8, cy - 22), (cx + 8, cy - 22),
        (cx + 11 + tail_dir * 6 + cloak_billow * 0.4, cy - 3),
        (cx + tail_dir * 9 + cloak_billow * 0.6, cy - 6),
        (cx - 11 + tail_dir * 7 + cloak_billow * 0.5, cy - 2),
    ], CLOAK)
    # Wine-rose inner lining hem
    body.line(cx - 9 + tail_dir * 6, cy - 4, cx + 9 + tail_dir * 5, cy - 4, "wine")

    # Shoulders & tall pointed Hollow Wick hood
    body.shaded_ellipse(cx, cy - 19, 9.0 if d != "side" else 7.5, 8.5, CLOAK)
    hx = cx + (2.0 if d == "side" else 0.0)
    hy = cy - 28.0
    # Pointed hood silhouette (swept back by train wind!) + Wick's twin shadowed moth-antenna crests!
    hood_tip_x = hx - 9.0 + cloak_billow * 0.5 if d == "side" else hx + cloak_billow * 0.4
    body.shaded_poly([
        (hx - 8, hy + 5), (hx - 7, hy - 5), (hood_tip_x, hy - 12),
        (hx + 7, hy - 5), (hx + 8, hy + 5),
    ], CLOAK)
    # Twin dark rose-tipped moth-antenna crests peeking out of the hood (unmistakably Wick's twin!)
    if d != "side":
        body.bezier_limb((hx - 3, hy - 9), (hx - 8, hy - 14), (hx - 10 + cloak_billow * 0.3, hy - 17), 1.6, 0.8, TRIM, tip_col="rose")
        body.bezier_limb((hx + 3, hy - 9), (hx + 8, hy - 14), (hx + 10 + cloak_billow * 0.3, hy - 17), 1.6, 0.8, TRIM, tip_col="rose")
    else:
        body.bezier_limb((hx - 1, hy - 9), (hx - 6, hy - 14), (hx - 10 + cloak_billow * 0.3, hy - 16), 1.6, 0.8, TRIM, tip_col="rose")
        body.bezier_limb((hx + 2, hy - 9), (hx - 2, hy - 15), (hx - 5 + cloak_billow * 0.3, hy - 18), 1.5, 0.8, TRIM, tip_col="rose")
    # Trim around hood opening
    if d == "front":
        body.ellipse(hx, hy - 1, 5.5, 5.0, "void", protect=True)
        # Eyes: dim violet-ash when staggered (hood slips revealing Wick's face!), glowing rose-cream in battle!
        ec = "rose" if ctx.is_stagger else ("cream" if p2 else "rose")
        body.eye(hx - 2.6, hy - 1, ec, "cream", "void", 2, 2)
        body.eye(hx + 1.8, hy - 1, ec, "cream", "void", 2, 2)
        if ctx.is_stagger:
            # Pale ash brow peek
            body.line(hx - 4, hy - 4, hx + 4, hy - 4, "mauve", protect=True)
    elif d == "side":
        body.ellipse(hx + 3.5, hy - 1, 3.6, 4.5, "void", protect=True)
        ec = "cream" if p2 else "rose"
        body.eye(hx + 4.5, hy - 1, ec, "cream", "void", 2, 2)
    else:
        # Back view: dark twin scarf tails streaming behind
        body.bezier_limb((hx, hy + 2), (hx - 4 + cloak_billow, hy + 10), (hx - 6 + cloak_billow * 1.2, hy + 18), 2.2, 0.9, TRIM)
        body.bezier_limb((hx + 2, hy + 2), (hx + 6 + cloak_billow * 0.8, hy + 11), (hx + 8 + cloak_billow, hy + 17), 2.0, 0.8, TRIM)

    # Black-glass UNLIT LANTERN held forward with flickering violet-coral temper sparks!
    lx = cx + (lan_x if d == "side" else 11.0)
    ly = cy + lan_y + math.sin(lph) * 1.5
    body.capsule(cx + 5, cy - 20, lx - 2, ly - 3, 1.8, 1.5, CLOAK)
    body.shaded_rect(lx - 3, ly - 4, 6, 8, BLACK_GLASS)
    body.rect(lx - 2, ly - 5, 4, 1, "rose")
    body.rect(lx - 2, ly + 4, 4, 1, "wine")
    # Inner dark-violet temper spark core
    core_c = "coral" if (ctx.is_tell or ctx.is_commit or p2) else "rose"
    body.rect(lx - 1, ly - 2, 2, 4, core_c, protect=True)
    body.set(lx, ly - 1, "cream", protect=True)

    # Phase 2 phantom afterimage wisps
    if p2:
        for k in range(4):
            a = ph + k * 1.57
            fx_back.set(cx + math.cos(a) * 14, cy - 18 + math.sin(a) * 9, "rose" if k % 2 == 0 else "coral", protect=True)

    # FX overlays
    if ctx.is_tell:
        fx_front.star4(lx, ly, 3 if u > 0.65 else 2, "cream", "rose")
        fx_front.ring(lx, ly, 10.0 - 5.0 * u, "coral", 1.0, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 9, cy - 16, 17, 11, -70, 70, 4.8, ("wine", "rose", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 12, 18, 10, 10, 170, 4.5, ("wine", "coral", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 12, 9.0, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="hollow_ram_phantom", name="Iron Phantom", out_dir=ART_BOSSES,
    frame=(72, 68), anchor=(36, 54),
    body_radius=8.5, hit_radius=13.0, body_centre=(36, 34),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="plum",
    draw_frame=draw_hollow_ram_phantom,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6b")
