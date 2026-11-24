#!/usr/bin/env python3
"""Island 7 Boss: Queen in the Glass (Slender Moth-Queen in alabaster-ice hoop gown with floating mirror-halo) — 86x82, anchor [43, 68]."""
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

ALABASTER = ("blue", "sky", "ice", "cream")
GOWN_SHADOW = ("night", "deep", "blue", "sky")
ROSE_GLASS = ("plum", "wine", "rose", "cream")
SILVER_CROWN = ("deep", "sky", "ice", "cream")


def _draw_shard_pane(buf: PixelBuf, cx: float, cy: float, p2: bool) -> None:
    ramp = ROSE_GLASS if p2 else ALABASTER
    buf.shaded_poly([(cx, cy - 8), (cx + 4.5, cy), (cx, cy + 8), (cx - 4.5, cy)], ramp)
    buf.line(cx, cy - 7, cx, cy + 7, "cream", protect=True)


def draw_queen_in_glass(ctx: FrameCtx) -> Image.Image:
    w, h = 88, 92
    ax, ay = 44.0, 77.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.2
    lag = math.sin(lph) * 2.6
    arm_raise = 0.0
    shard_spread = 22.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = -2.5 * u
        arm_raise = -7.0 * u
        shard_spread = 22.0 + 5.0 * u
        sx, sy = 0.95, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        arm_raise = 5.0 * sm
        shard_spread = 26.0 + 4.0 * sm
        sx, sy = 1.08, 0.94
    elif ctx.is_recover:
        hover = 2.5
        arm_raise = 3.0
        shard_spread = 19.0
    elif ctx.is_stagger:
        hover = 4.0
        arm_raise = 6.0
        shard_spread = 17.0
        sx, sy = 1.06, 0.92

    cx = ax
    cy = ay - 4.0 + hover
    # Regal SE shadow beneath hoop gown
    shadow.contact_shadow(ax + 2.0, ay + 2.0, 17.0, 3.2, "night")

    # Floating hexagonal mirror-halo behind head & shoulders (THE regal silhouette!)
    hy = cy - 42.0
    hx = cx + (1.5 if d == "side" else 0.0)
    halo_r = 16.0 if not p2 else 17.5
    halo_pts = []
    for k in range(6):
        ang = -math.pi * 0.5 + k * (math.tau / 6.0) + (ph * 0.15 if p2 else 0.0)
        halo_pts.append((hx + math.cos(ang) * halo_r, hy + 2.0 + math.sin(ang) * (halo_r * 0.85)))
    for k in range(6):
        p0, p1 = halo_pts[k], halo_pts[(k + 1) % 6]
        fx_back.line(p0[0], p0[1], p1[0], p1[1], "rose" if (p2 and k % 2 == 1) else "ice", protect=True)
    # Halo inner star rays
    fx_back.ring(hx, hy + 2.0, halo_r - 3.5, "sky" if not p2 else "rose", 1.0)

    # Grand faceted alabaster-ice hoop gown
    gw = 16.0 if d != "side" else 13.0
    gown_pts = [
        (cx - 5, cy - 28), (cx + 5, cy - 28),
        (cx + gw * 0.72, cy - 14), (cx + gw, cy + 2),
        (cx + gw * 0.5, cy + 5), (cx, cy + 3),
        (cx - gw * 0.5, cy + 5), (cx - gw, cy + 2),
        (cx - gw * 0.72, cy - 14),
    ]
    body.shaded_poly(gown_pts, ALABASTER)
    # Stained-glass lattice ribs & rose-glass apron panels
    body.line(cx, cy - 27, cx, cy + 3, "night")
    body.line(cx - gw * 0.45, cy - 15, cx - gw * 0.65, cy + 4, "deep")
    body.line(cx + gw * 0.45, cy - 15, cx + gw * 0.65, cy + 4, "deep")
    body.shaded_poly([(cx - 4, cy - 27), (cx + 4, cy - 27), (cx + 6, cy - 16), (cx, cy - 11), (cx - 6, cy - 16)], ROSE_GLASS)
    # Translucent scalloped gown hem
    body.line(cx - gw + 1, cy + 1, cx + gw - 1, cy + 1, "cream", protect=True)

    # Slender waist & translucent moth-queen cloak wings
    w_lift = math.sin(ph) * 2.5
    if d != "side":
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (cx + sgn * 4, cy - 33), (cx + sgn * 17, cy - 38 - w_lift),
                (cx + sgn * 19, cy - 26 - w_lift * 0.5), (cx + sgn * 12, cy - 18), (cx + sgn * 5, cy - 25),
            ], GOWN_SHADOW)
            body.line(cx + sgn * 5, cy - 32, cx + sgn * 16, cy - 36 - w_lift, "ice", protect=True)
    else:
        fx_back.shaded_poly([(cx - 3, cy - 33), (cx - 17, cy - 39 - w_lift), (cx - 19, cy - 25), (cx - 6, cy - 21)], GOWN_SHADOW)
        fx_back.line(cx - 4, cy - 32, cx - 16, cy - 37 - w_lift, "ice", protect=True)

    # Slender arms holding glass scepter / gesturing
    if d != "side":
        body.capsule(cx - 5, cy - 32, cx - 14, cy - 26 + arm_raise, 1.6, 1.2, ALABASTER)
        body.capsule(cx + 5, cy - 32, cx + 14, cy - 26 + arm_raise, 1.6, 1.2, ALABASTER)
    else:
        body.capsule(cx + 1, cy - 32, cx + 13, cy - 26 + arm_raise, 1.7, 1.3, ALABASTER)
        body.line(cx + 13, cy - 35 + arm_raise, cx + 13, cy - 16 + arm_raise, "cream", protect=True)
        body.shaded_poly([(cx + 13, cy - 38 + arm_raise), (cx + 16, cy - 34 + arm_raise), (cx + 13, cy - 30 + arm_raise), (cx + 10, cy - 34 + arm_raise)], ROSE_GLASS)

    # Porcelain moth-queen head & tall crystal tiara-crown
    body.shaded_ellipse(hx, hy, 6.2, 6.8, ALABASTER, spec_col="cream")
    body.shaded_poly([
        (hx - 6, hy - 5), (hx - 5, hy - 13), (hx - 2, hy - 8),
        (hx, hy - 16), (hx + 2, hy - 8), (hx + 5, hy - 13), (hx + 6, hy - 5),
    ], SILVER_CROWN)
    body.set(hx, hy - 14, "rose", protect=True)

    # Calm porcelain face (front/side) or stained-glass spine (back)
    if d == "front":
        body.eye(hx - 2.6, hy - 0.5, "plum", "cream", "void", 2, 2)
        body.eye(hx + 1.6, hy - 0.5, "plum", "cream", "void", 2, 2)
        body.line(hx - 1.5, hy + 3.0, hx + 1.5, hy + 3.0, "mauve", protect=True)
    elif d == "side":
        body.eye(hx + 2.6, hy - 0.5, "plum", "cream", "void", 2, 2)
    else:
        body.line(hx, hy - 5, hx, hy + 5, "deep")
        body.shaded_poly([(cx, cy - 32), (cx + 4, cy - 24), (cx, cy - 16), (cx - 4, cy - 24)], ROSE_GLASS)

    # Orbiting floating glass mirror-shards at her flanks!
    orbit_y = cy - 24.0 + lag * 0.9
    if d != "side":
        _draw_shard_pane(fx_front, cx - shard_spread, orbit_y, p2)
        _draw_shard_pane(fx_front, cx + shard_spread, cy - 24.0 - lag * 0.9, p2)
    else:
        _draw_shard_pane(fx_front, cx + 20.0, orbit_y, p2)
        _draw_shard_pane(fx_back, cx - 18.0, cy - 26.0 - lag, p2)

    # Phase 2 rose mirror-fractures on gown & face-crack FX
    if p2:
        body.crack(cx - 8, cy - 18, cx + 6, cy - 2, "void", "rose", seed=53)
        body.crack(cx + 3, cy - 26, cx - 6, cy - 8, "void", "ice", seed=59)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.25:
        fx_front.star4(hx, hy - 16, 3 if u > 0.65 else 2, "cream", "rose" if p2 else "ice")
        fx_front.ring(cx + (15 if d == "side" else 0), cy - 26, 4.0 + (1.0 - u) * 7.0, "ice", 1.3)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 15, cy - 24, 21, 16, -65, 65, 5.5, ("blue", "ice", "cream"))
            fx_front.line(cx + 12, cy - 26, cx + 34, cy - 26, "cream", protect=True)
        else:
            fx_front.slash_arc(cx, cy - 22, 26, 15, -30, 210, 5.5, ("blue", "ice", "cream"))
            fx_front.star4(cx - shard_spread, orbit_y, 2, "cream", "rose")
            fx_front.star4(cx + shard_spread, cy - 24.0 - lag * 0.9, 2, "cream", "rose")
    elif ctx.is_stagger:
        body.crack(hx - 4, hy - 4, hx + 4, hy + 4, "void", "rose", seed=61)
        fx_front.dizzy_stars(hx, hy - 14, 11.0, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="queen_in_glass", name="Queen in the Glass", out_dir=ART_BOSSES,
    frame=(88, 92), anchor=(44, 77),
    body_radius=11.0, hit_radius=15.0, body_centre=(44, 48),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_queen_in_glass,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
