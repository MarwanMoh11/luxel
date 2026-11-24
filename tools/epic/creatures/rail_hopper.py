#!/usr/bin/env python3
"""Island 6 Enemy: Rail Hopper (spring-heeled brass rail-locust with cyclops headlight eye) — 60x56, anchor [30, 46]."""
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

BRASS = ("plum", "coral", "apricot", "gold")
STEEL = ("void", "night", "dusk", "mauve", "stone")
DARK_IRON = ("void", "night", "dusk", "mauve")


def _draw_spring_leg(buf: PixelBuf, x0: float, y0: float, x1: float, y1: float, zig: float) -> None:
    mx1 = x0 + (x1 - x0) * 0.33 + zig
    my1 = y0 + (y1 - y0) * 0.33 - abs(zig) * 0.4
    mx2 = x0 + (x1 - x0) * 0.66 - zig * 0.7
    my2 = y0 + (y1 - y0) * 0.66
    buf.capsule(x0, y0, mx1, my1, 1.5, 1.3, BRASS)
    buf.capsule(mx1, my1, mx2, my2, 1.3, 1.2, STEEL)
    buf.capsule(mx2, my2, x1, y1, 1.2, 1.4, DARK_IRON)
    # Rail-claw foot
    buf.rect(x1 - 2, y1 - 1, 5, 2, "dusk")
    buf.set(x1 - 2, y1 + 1, "stone")
    buf.set(x1 + 2, y1 + 1, "stone")


def draw_rail_hopper(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 68
    ax, ay = 32.0, 52.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hop = abs(math.sin(ph)) * 2.5 if ctx.anim == "routine" else 0.0
    coil = 0.0
    sx, sy = 1.0, 1.0
    lean_x = 0.0

    if ctx.is_tell:
        coil = 4.5 * u
        sx, sy = 1.14, 0.84
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.4) * math.pi)
        hop = 9.5 * sm
        lean_x = 4.5 * sm
        sx, sy = 0.90, 1.15
    elif ctx.is_recover:
        coil = 3.2 + math.sin(ph) * 0.8
        sx, sy = 1.16, 0.84
    elif ctx.is_stagger:
        lean_x = math.sin(ph * 2.0) * 2.5
        hop = 1.5
        sx, sy = 1.06, 0.92

    cx = ax + (lean_x if d == "side" else 0.0)
    cy = ay - hop + coil
    shadow.contact_shadow(ax, ay + 1.0, 11.5 - hop * 0.25, 2.0, "night")

    # Coiled hind spring legs (distinctive locust silhouette!)
    zig = (4.0 if not ctx.is_tell else 6.0) * (1.0 if not ctx.is_commit else 0.5)
    foot_y = ay - 1.0 - (hop * 0.45 if ctx.is_commit else 0.0)
    if d == "side":
        # Back spring leg (far) + front spring leg (near)
        _draw_spring_leg(body, cx - 5, cy - 11, cx - 10, foot_y, -zig)
        _draw_spring_leg(body, cx + 1, cy - 10, cx - 3, foot_y + 0.5, zig * 0.8)
        # Front rail-claws
        body.capsule(cx + 6, cy - 8, cx + 10, foot_y, 1.1, 1.0, DARK_IRON)
    else:
        _draw_spring_leg(body, cx - 7, cy - 12, cx - 12, foot_y, -zig * 0.9)
        _draw_spring_leg(body, cx + 7, cy - 12, cx + 12, foot_y, zig * 0.9)

    # Arched segmented brass locust carapace
    if d == "side":
        # Rear abdomen segment
        body.shaded_ellipse(cx - 7.5, cy - 12.5, 6.2, 4.6, DARK_IRON)
        body.line(cx - 10, cy - 14, cx - 5, cy - 14, "apricot")
        # Mid brass thorax
        body.shaded_ellipse(cx - 0.5, cy - 14.5, 7.2, 5.6, BRASS, spec_col="cream")
        # Ribbed locomotive vent stripes
        for vx in (-4, -1, 2):
            body.line(cx + vx, cy - 18, cx + vx, cy - 12, "plum")
        # Forward locomotive-nose head
        hx, hy = cx + 7.5, cy - 13.0
        body.shaded_ellipse(hx, hy, 5.2, 5.0, STEEL)
        # Blazing cyclops train headlight!
        body.circle(hx + 3.2, hy - 0.5, 3.0, "night", protect=True)
        body.circle(hx + 3.4, hy - 0.5, 2.2, "gold" if not ctx.is_stagger else "coral", protect=True)
        body.set(hx + 4.0, hy - 1.0, "cream", protect=True)
    elif d == "front":
        body.shaded_dome(cx, cy - 13.0, 9.2, 8.2, BRASS, bottom_cut=0.22, spec_col="cream")
        body.shaded_rect(cx - 6, cy - 12, 12, 5, DARK_IRON)
        # Twin brass shoulder pistons
        body.shaded_ellipse(cx - 8, cy - 15, 2.6, 3.4, STEEL)
        body.shaded_ellipse(cx + 8, cy - 15, 2.6, 3.4, STEEL)
        # Center blazing cyclops headlight
        body.circle(cx, cy - 13.5, 3.6, "void", protect=True)
        body.circle(cx, cy - 13.5, 2.6, "gold" if not ctx.is_stagger else "coral", protect=True)
        body.circle(cx - 0.5, cy - 14.0, 1.2, "cream", protect=True)
    else:
        body.shaded_dome(cx, cy - 13.5, 9.2, 8.2, DARK_IRON, bottom_cut=0.2)
        body.shaded_ellipse(cx, cy - 16.5, 6.8, 4.4, BRASS)
        # Rear spring exhaust coils
        body.rect(cx - 4, cy - 12, 3, 4, "apricot")
        body.rect(cx + 1, cy - 12, 3, 4, "apricot")

    # Twin swept brass antennae (lag-phase Secondary Motion!)
    aw = math.sin(lph) * 2.5
    if d == "side":
        body.bezier_limb((cx + 7, cy - 17), (cx + 3, cy - 23 + aw * 0.4), (cx - 3, cy - 25 + aw), 1.0, 0.5, BRASS, tip_col="cream")
        body.bezier_limb((cx + 8, cy - 16), (cx + 11, cy - 22 - aw * 0.4), (cx + 14, cy - 24 - aw * 0.7), 0.9, 0.5, BRASS, tip_col="gold")
    else:
        body.bezier_limb((cx - 3, cy - 20), (cx - 7, cy - 26 + aw * 0.5), (cx - 11, cy - 27 + aw), 1.0, 0.5, BRASS, tip_col="cream")
        body.bezier_limb((cx + 3, cy - 20), (cx + 7, cy - 26 - aw * 0.5), (cx + 11, cy - 27 - aw), 1.0, 0.5, BRASS, tip_col="cream")

    # FX
    if ctx.is_tell:
        if u > 0.35:
            gx = cx + (12 if d == "side" else 0)
            gy = cy - 14
            fx_front.star4(gx, gy, 3 if u > 0.7 else 2, "cream", "gold")
        fx_back.ring(ax, ay - 2, 12.0 - u * 4.0, "gold", 1.0, 0, 360, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (6 if d == "side" else 0), cy - 12, 15, 11, -50, 70, 4.8, ("apricot", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 24, 8.5, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="rail_hopper", name="Rail Hopper", out_dir=ART_ENEMIES,
    frame=(64, 68), anchor=(32, 52),
    body_radius=5.5, hit_radius=10.0, body_centre=(32, 40),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_rail_hopper,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6")
