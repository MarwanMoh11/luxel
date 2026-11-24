#!/usr/bin/env python3
"""Island 7 Enemy: Glass Knight (faceted stained-glass sentinel with mirror kite-shield & crystal lance) — 66x58, anchor [30, 46]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_ENEMIES, CACHE_DIR, ENEMY_ANIMS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

GLASS = ("deep", "blue", "sky", "ice", "cream")
SHADOW_GLASS = ("night", "deep", "blue", "sky")
ROSE_PANE = ("plum", "wine", "rose", "cream")


def _draw_crystal_lance(buf: PixelBuf, px: float, py: float, ang_deg: float, thrust: float) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ox = px + thrust
    tmp.capsule(ox - 8, py, ox + 2, py, 1.3, 1.6, ("night", "deep", "sky"))
    tmp.shaded_poly([(ox, py - 3.0), (ox + 17, py), (ox, py + 3.0), (ox - 2, py)], GLASS)
    tmp.line(ox + 1, py, ox + 15, py, "cream", protect=True)
    tmp.line(ox + 2, py - 1, ox + 10, py - 1, "ice", protect=True)
    tmp.shaded_poly([(ox, py - 5), (ox + 2, py), (ox, py + 5), (ox - 2, py)], ("plum", "rose", "cream"))
    buf.composite(rotate_buf(tmp, px, py, ang_deg))


def _draw_mirror_shield(buf: PixelBuf, cx: float, cy: float, shimmer_u: float) -> None:
    pts = [(cx, cy - 9), (cx + 6, cy - 4), (cx + 5, cy + 4), (cx, cy + 9), (cx - 6, cy + 4), (cx - 6, cy - 4)]
    buf.shaded_poly(pts, GLASS)
    buf.line(cx, cy - 8, cx, cy + 8, "night")
    buf.line(cx - 5, cy - 1, cx + 5, cy - 1, "night")
    gy = cy - 5 + shimmer_u * 8.0
    buf.line(cx - 3, gy, cx + 3, gy - 3, "cream", protect=True)


def draw_glass_knight(ctx: FrameCtx) -> Image.Image:
    w, h = 68, 62
    ax, ay = 32.0, 50.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = math.sin(ph) * 1.4 if ctx.anim == "routine" else 0.0
    lean = 0.0
    lance_ang = -8.0
    thrust = 0.0
    ribbon_lag = math.sin(lph) * 2.8
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -3.0 * u
        lance_ang = -16.0 * u
        thrust = -4.5 * u
        sx, sy = 0.94, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lean = 4.5 * sm
        lance_ang = 3.0 * sm
        thrust = 9.0 * sm
        sx, sy = 1.08, 0.95
    elif ctx.is_recover:
        lean = 2.8 * (1.0 - u)
        lance_ang = 15.0
        thrust = 3.0
    elif ctx.is_stagger:
        lean = -3.0 + math.sin(ph * 2.0) * 1.5
        lance_ang = -42.0

    cx = ax + (lean - 2.0 if d == "side" else 0.0)
    cy = ay - hover
    shadow.contact_shadow(ax, ay + 1.0, 9.5, 1.8, "night")

    stride = math.sin(ph) * 2.2 if ctx.anim == "routine" else 0.0
    body.shaded_poly([(cx - 6, cy - 9), (cx - 2, cy - 9), (cx - 3 - stride, cy), (cx - 7 - stride, cy)], SHADOW_GLASS)
    body.shaded_poly([(cx + 2, cy - 9), (cx + 6, cy - 9), (cx + 7 + stride, cy), (cx + 3 + stride, cy)], GLASS)

    if d == "side":
        fx_back.shaded_poly([
            (cx - 4, cy - 22), (cx - 14 - ribbon_lag, cy - 4), (cx - 7 - ribbon_lag * 0.5, cy - 2), (cx - 2, cy - 10),
        ], ("deep", "blue", "sky"))
        fx_back.line(cx - 4, cy - 18, cx - 11 - ribbon_lag * 0.8, cy - 5, "ice")

    body.shaded_poly([
        (cx - 8, cy - 23), (cx + 8, cy - 23), (cx + 10, cy - 15),
        (cx + 6, cy - 7), (cx, cy - 5), (cx - 6, cy - 7), (cx - 10, cy - 15),
    ], GLASS)
    body.line(cx, cy - 22, cx, cy - 6, "night")
    body.line(cx - 8, cy - 15, cx + 8, cy - 15, "night")
    body.shaded_poly([(cx, cy - 20), (cx + 4, cy - 15), (cx, cy - 10), (cx - 4, cy - 15)], ROSE_PANE)
    body.set(cx - 1, cy - 16, "cream", protect=True)

    for sgn in (-1.0, 1.0):
        px_s = cx + sgn * (9.5 if d != "side" else 4.5)
        body.shaded_poly([
            (px_s - sgn * 3, cy - 23), (px_s + sgn * 4, cy - 26),
            (px_s + sgn * 5, cy - 19), (px_s - sgn * 2, cy - 18),
        ], GLASS)

    hx = cx + (1.5 if d == "side" else 0.0)
    hy = cy - 29.0
    body.shaded_poly([
        (hx, hy - 10), (hx + 6, hy - 4), (hx + 5, hy + 4),
        (hx, hy + 6), (hx - 5, hy + 4), (hx - 6, hy - 4),
    ], GLASS)
    body.line(hx, hy - 9, hx, hy + 5, "night")
    body.line(hx - 4, hy - 3, hx - 1, hy - 7, "cream", protect=True)

    if d == "front":
        body.rect(hx - 4, hy - 1, 8, 3, "void", protect=True)
        body.eye(hx - 3, hy - 0.5, "ice", "cream", "void", 2, 2)
        body.eye(hx + 1, hy - 0.5, "ice", "cream", "void", 2, 2)
        _draw_mirror_shield(body, cx - 10, cy - 13, u)
        _draw_crystal_lance(body, cx + 10, cy - 14, lance_ang - 65, thrust * 0.45)
    elif d == "side":
        body.rect(hx + 1, hy - 1, 4, 3, "void", protect=True)
        body.eye(hx + 2.5, hy - 0.5, "ice", "cream", "void", 2, 2)
        _draw_crystal_lance(body, cx + 5, cy - 14, lance_ang, thrust)
        body.shaded_rect(cx + 1, cy - 20, 4, 14, GLASS)
    else:
        body.shaded_poly([
            (cx - 9, cy - 22), (cx + 9, cy - 22),
            (cx + 12 + ribbon_lag * 0.3, cy - 4), (cx, cy - 1), (cx - 12 + ribbon_lag * 0.3, cy - 4),
        ], SHADOW_GLASS)
        body.shaded_ellipse(cx, cy - 13, 5.5, 5.5, ROSE_PANE)
        body.line(cx - 5, cy - 13, cx + 5, cy - 13, "night")
        body.line(cx, cy - 18, cx, cy - 8, "night")
        body.set(cx, cy - 13, "gold", protect=True)
        _draw_crystal_lance(body, cx + 10, cy - 16, -72.0, 0.0)

    if ctx.is_stagger:
        body.crack(cx - 6, cy - 20, cx + 5, cy - 10, "void", "cream", seed=23)
        fx_front.dizzy_stars(hx, hy - 12, 8.5, 2.6, ph)
        fx_front.poly([(cx - 13, cy - 22 + ctx.fi), (cx - 11, cy - 25 + ctx.fi), (cx - 10, cy - 21 + ctx.fi)], "ice", protect=True)
        fx_front.poly([(cx + 12, cy - 18 + ctx.fi), (cx + 14, cy - 21 + ctx.fi), (cx + 15, cy - 17 + ctx.fi)], "sky", protect=True)
    elif ctx.is_tell and u > 0.35:
        gx = cx + (17 if d == "side" else 11)
        fx_front.star4(gx, cy - 16, 3 if u > 0.70 else 2, "cream", "ice")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 11, cy - 14, 17, 9, -38, 38, 5.4, ("blue", "ice", "cream"))
            fx_front.line(cx + 10, cy - 14, cx + 27, cy - 14, "cream", protect=True)
            fx_front.star4(cx + 26, cy - 14, 2, "cream", "ice")
        else:
            fx_front.slash_arc(cx + 2, cy - 15, 17, 11, -35, 130, 4.8, ("blue", "ice", "cream"))

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="glass_knight", name="Glass Knight", out_dir=ART_ENEMIES,
    frame=(68, 62), anchor=(32, 50),
    body_radius=7.5, hit_radius=11.0, body_centre=(32, 35),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_glass_knight,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
