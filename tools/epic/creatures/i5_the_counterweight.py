#!/usr/bin/env python3
"""Island 5 Fall Set-Piece Boss: The Counterweight (towering faceted brass plumb-bob on 3 glowing chains) — 88x92, anchor [44, 78]."""
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

BRASS = ("plum", "coral", "apricot", "gold")
IRON = ("void", "night", "dusk", "mauve")
CHAIN_GLOW = ("blue", "sky", "ice", "cream")
FURNACE = ("coral", "apricot", "gold", "cream")


def draw_the_counterweight(ctx: FrameCtx) -> Image.Image:
    w, h = 88, 92
    ax, ay = 44.0, 78.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    sway = math.sin(ph) * 6.5 if ctx.anim in ("routine", "phase2") else 0.0
    lift = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Haul high on taut chains before hammering downward!
        lift = 7.5 * u
        sway = (-6.0 if d == "side" else 0.0) * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lift = -4.5 * sm
        sway = (7.0 if d == "side" else 0.0) * sm
        sx, sy = 1.10, 0.90
    elif ctx.is_recover:
        lift = -3.0
        sway = math.sin(ph) * 2.0
    elif ctx.is_stagger:
        lift = -2.0 + math.sin(ph * 2.0) * 1.8
        sway = math.sin(ph * 2.5) * 7.0

    cx = ax + sway
    cy = ay - 30.0 - lift
    sh_r = max(10.0, 20.0 - lift * 0.45)
    shadow.contact_shadow(ax + sway * 0.5, ay + 2.0, sh_r, 3.0, "night")

    # ---- Three Glowing Celestial Brass Chains Anchored Overhead ----
    top_y = 10.0
    shackle_y = cy - 17.0
    chain_offsets = [(-10.0, 0.0), (0.0, -2.0), (10.0, 0.0)] if d != "side" else [(-6.0, 0.0), (0.0, -2.0), (6.0, 0.0)]
    for ci, (ox, oy) in enumerate(chain_offsets):
        if p2 and ci == 0:
            # Snapped dangling chain link sparking in P2!
            body.chain((cx + ox, shackle_y + oy), (cx + ox - 8.0, shackle_y + 12.0 + math.sin(lph) * 3.0), 3.0, "sky", "cream", "night", links=4)
            fx_front.star4(cx + ox - 8.0, shackle_y + 12.0 + math.sin(lph) * 3.0, 2, "cream", "ice")
            continue
        col_link = "ice" if (ci == 1 or p2) else "gold"
        body.chain((ax + ox * 0.8, top_y), (cx + ox, shackle_y + oy), 2.0 if ctx.is_stagger else 0.4, col_link, "cream", "night", links=5)
        fx_front.set(cx + ox, (top_y + shackle_y) * 0.5, "cream", protect=True)

    # Heavy brass suspension collar / yoke at top of plumb-bob
    body.shaded_rect(cx - 13.0, shackle_y - 3.0, 26.0, 7.0, BRASS)
    body.circle(cx, shackle_y, 3.5, "gold")
    body.set(cx, shackle_y - 0.5, "cream", protect=True)

    # ---- Faceted Colossal Brass Plumb-Bob Body ----
    # Broad upper octagon crown tapering cleanly to a razor-sharp pointed plumb tip!
    bw = 18.0 if d != "side" else 16.5
    plumb_poly = [
        (cx - bw * 0.72, cy - 16.0),
        (cx + bw * 0.72, cy - 16.0),
        (cx + bw, cy - 4.0),
        (cx + bw * 0.68, cy + 12.0),
        (cx, cy + 27.0),
        (cx - bw * 0.68, cy + 12.0),
        (cx - bw, cy - 4.0),
    ]
    body.shaded_poly(plumb_poly, BRASS)
    # Armored dark-iron front brow/cowling flanges (bounces straight front bolts!)
    if d != "back":
        fx_off = 3.0 if d == "side" else 0.0
        body.shaded_poly([
            (cx - bw * 0.65 + fx_off, cy - 13.0),
            (cx + bw * 0.65 + fx_off, cy - 13.0),
            (cx + bw * 0.85 + fx_off, cy + 1.0),
            (cx - bw * 0.85 + fx_off, cy + 1.0),
        ], IRON)
        # Riveted brass meridian band across waist
        body.line(cx - bw + 2, cy - 4, cx + bw - 2, cy - 4, "gold", protect=True)
        body.line(cx - bw * 0.65, cy + 12, cx + bw * 0.65, cy + 12, "gold")
        # Glowing furnace-slit visor eye!
        if d == "side":
            body.shaded_rect(cx + 3.0, cy - 9.0, 10.0, 4.5, ("void", "night", "wine"))
            body.eye(cx + 7.5, cy - 7.0, "cream" if (p2 or ctx.is_tell) else "gold", "cream", "void", 3, 2)
        else:
            body.shaded_rect(cx - 10.0, cy - 9.0, 20.0, 4.5, ("void", "night", "wine"))
            body.eye(cx - 5.5, cy - 7.0, "cream" if (p2 or ctx.is_tell) else "gold", "cream", "void", 3, 2)
            body.eye(cx + 3.5, cy - 7.0, "cream" if (p2 or ctx.is_tell) else "gold", "cream", "void", 3, 2)
    else:
        # Back view: exposed glowing ice-cream chain-gear escapement weakspot!
        body.shaded_ellipse(cx, cy - 2.0, 9.0, 9.0, ("void", "night", "deep"))
        body.ring(cx, cy - 2.0, 8.2, "ice", 1.5)
        body.circle(cx, cy - 2.0, 5.2, "sky", protect=True)
        body.circle(cx, cy - 2.0, 2.8, "cream", protect=True)

    # Pointed steel plumb needle tip at bottom + vertical facet bevel ridges
    body.line(cx - bw * 0.25, cy + 1.0, cx - 1.5, cy + 20.0, "gold")
    body.line(cx + bw * 0.25, cy + 1.0, cx + 1.5, cy + 20.0, "wine")
    body.shaded_poly([(cx - 4.5, cy + 18.0), (cx + 4.5, cy + 18.0), (cx, cy + 27.5)], CHAIN_GLOW)
    body.set(cx, cy + 26.5, "cream", protect=True)

    if p2:
        body.crack(cx - 8, cy - 10, cx + 6, cy + 14, "void", "coral", seed=37)
        fx_back.ring(cx, cy, 22.0, "coral", 1.2)

    # ---- Telegraph / Commit / Stagger FX (kept cleanly inside y <= 86!) ----
    if ctx.is_tell and u > 0.25:
        fx_front.slash_arc(cx, ay - 6.0, 14.0 + u * 8.0, 6.0 + u * 3.0, 10, 170, 3.0, ("wine", "coral", "gold"))
        fx_front.star4(cx, cy + 26.0, 3 if u > 0.65 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx, ay - 7.0, 16.0 + ctx.fi * 5.0, 7.0 + ctx.fi * 2.0, 8, 172, 4.8, ("coral", "gold", "cream"))
        fx_front.slash_arc(cx, ay - 8.0, 14.0 + ctx.fi * 4.0, 6.0 + ctx.fi * 1.5, -172, -8, 3.2, ("sky", "ice", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 20.0, 12.0, 3.4, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="the_counterweight", name="The Counterweight", out_dir=ART_BOSSES,
    frame=(88, 92), anchor=(44, 78),
    body_radius=12.5, hit_radius=17.0, body_centre=(44, 46),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_the_counterweight,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
