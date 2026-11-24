#!/usr/bin/env python3
"""Island 2 Enemy: Brine Lamprey (sinuous aquatic eel stalker & skiff leech) — 58x50, anchor [29, 40]."""
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

EEL = ("void", "night", "dusk", "wine")
MAW = ("wine", "coral", "rose", "cream")
FIN = ("stone", "cream")


def draw_brine_lamprey(ctx: FrameCtx) -> Image.Image:
    w, h = 68, 58
    ax, ay = 34.0, 40.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    wave = math.sin(ph) * 3.5
    lag_w = math.sin(lph) * 4.0
    lift = 0.0
    lunge = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lift = 4.0 * u
        lunge = -3.0 * u
        wave = math.sin(u * math.pi * 3.0) * 2.0
        sx, sy = 0.90, 1.12
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lift = 8.0 * sm
        lunge = 8.0 * sm
        sx, sy = 1.16, 0.86
    elif ctx.is_recover:
        wave = math.sin(ph * 2.0) * 5.0
        sx, sy = 1.06, 0.94
    elif ctx.is_stagger:
        wave = math.sin(ph * 2.0) * 4.5
        lift = 2.0

    cx = ax + (lunge if d == "side" else 0.0)
    cy = ay - 9.0 - lift
    shadow.contact_shadow(ax, ay + 1.0, 11.0, 2.0, "night")

    # Water surface ripple ring under eel
    rip_col = "coral" if ctx.is_tell else "sky"
    fx_back.ring(ax, ay - 2.0, 11.5 + math.sin(ph) * 1.5, rip_col, 1.1, 0, 360, protect=True)
    fx_back.ring(ax, ay - 2.0, 7.5 + math.cos(ph) * 1.2, "rose" if ctx.is_tell else "ice", 0.9, 0, 360, protect=True)

    if d == "side":
        # Sinuous arched S-curve sea-lamprey lunging right
        p0 = (cx - 17, cy + 4 + lag_w * 0.6)
        p1 = (cx - 6, cy - 7 + wave * 0.5)
        p2 = (cx + 8, cy - 1 - lift * 0.2)
        body.bezier_limb(p0, p1, p2, 2.0, 4.8, EEL)
        # Cream dorsal fin ridge along spine
        body.bezier_limb((cx - 14, cy + 1 + lag_w * 0.4), (cx - 5, cy - 10 + wave * 0.4), (cx + 3, cy - 5), 1.3, 0.8, FIN, tip_col="cream")
        # Circular rose toothed sucker maw at front
        mx, my = cx + 11.0, cy - 1.0
        body.shaded_ellipse(mx, my, 4.6, 5.2, MAW)
        body.ellipse(mx + 1.5, my, 2.6, 3.2, "void")
        for ty in (-3, -1, 1, 3):
            body.set(mx + 2.5, my + ty, "cream", protect=True)
        # Small gill dots + pale eye
        body.eye(cx + 5.0, cy - 3.5, "gold", "cream", "void", 2, 2)
        for gx in (-1, 1, 3):
            body.set(cx + gx, cy, "rose")
    elif d == "front":
        # Coiled body arching behind, terrifying circular sucker maw dead center!
        body.bezier_limb((cx - 10, cy + 6 + lag_w * 0.4), (cx - 11, cy - 6 + wave * 0.4), (cx, cy - 8), 2.4, 4.2, EEL)
        body.bezier_limb((cx + 10, cy + 5 - lag_w * 0.4), (cx + 10, cy - 4 - wave * 0.4), (cx, cy - 8), 2.0, 4.0, EEL)
        # Cream dorsal crest atop arch
        body.shaded_poly([(cx - 2, cy - 12), (cx, cy - 17), (cx + 2, cy - 12)], FIN)
        # Front sucker maw
        body.shaded_ellipse(cx, cy + 1, 6.2, 6.2, MAW)
        body.circle(cx, cy + 1, 3.6, "void")
        for k in range(6):
            a = k * (math.tau / 6.0) + ph * 0.2
            body.set(cx + math.cos(a) * 3.6, cy + 1 + math.sin(a) * 3.6, "cream", protect=True)
        body.eye(cx - 4.2, cy - 5.5, "gold", "cream", "void", 2, 2)
        body.eye(cx + 2.2, cy - 5.5, "gold", "cream", "void", 2, 2)
    else:
        # Back view: arched finned eel spine + thrashing tail
        body.bezier_limb((cx, cy - 9), (cx + wave * 0.7, cy - 1), (cx + lag_w, cy + 8), 4.6, 1.8, EEL)
        body.bezier_limb((cx, cy - 12), (cx + wave * 0.5, cy - 2), (cx + lag_w * 0.8, cy + 7), 1.4, 0.7, FIN, tip_col="cream")
        body.shaded_ellipse(cx, cy - 8, 5.2, 4.6, EEL)

    if ctx.is_tell and u > 0.25:
        fx_front.star4(cx + (11 if d == "side" else 0), cy - 3, 2, "cream", "coral")
        fx_front.ring(ax, ay - 2, 13.0 - u * 4.0, "coral", 1.2, 0, 360, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 7, cy - 1, 15, 9, -55, 55, 4.2, ("wine", "rose", "cream"))
        else:
            fx_front.slash_arc(cx, cy + 2, 15, 9, 10, 170, 4.2, ("wine", "rose", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 14, 8.5, 2.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="brine_lamprey", name="Brine Lamprey", out_dir=ART_ENEMIES,
    frame=(68, 58), anchor=(34, 40),
    body_radius=5.0, hit_radius=9.5, body_centre=(34, 30),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_brine_lamprey,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
