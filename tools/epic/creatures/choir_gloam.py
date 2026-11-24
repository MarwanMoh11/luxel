#!/usr/bin/env python3
"""Island 8 Enemy: Choir Gloam (tall void-violet eclipse-singer with glowing ice score) — 56x58, anchor [28, 48]."""
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

ROBE = ("void", "night", "deep", "blue")
STOLE = ("deep", "blue", "sky", "ice")
MITER = ("void", "night", "dusk", "deep")


def draw_choir_gloam(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 72
    ax, ay = 32.0, 59.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = math.sin(ph) * 2.4 if ctx.anim == "routine" else 0.0
    sway = math.sin(lph) * 2.4
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = 3.2 * u
        sx, sy = 0.93, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        hover = 2.0 * sm
        sx, sy = 1.08, 0.94
    elif ctx.is_recover:
        hover = -1.5
    elif ctx.is_stagger:
        hover = -2.8
        sway = math.sin(ph * 2.0) * 3.5

    cx = ax
    cy = ay - 16.5 - hover
    shadow.contact_shadow(ax, ay + 1.0, 7.5, 1.5, "night")

    # Floating trailing choir stole ribbons (lagged)
    body.bezier_limb((cx - 5, cy + 4), (cx - 8 + sway, cy + 11), (cx - 6 + sway * 1.3, cy + 15), 2.0, 0.8, STOLE)
    body.bezier_limb((cx + 5, cy + 4), (cx + 8 + sway, cy + 11), (cx + 6 + sway * 1.3, cy + 15), 2.0, 0.8, STOLE)

    # Tall slender cathedral choir robe tapering down to wispy hem
    body.shaded_poly([
        (cx - 7, cy - 11), (cx + 7, cy - 11),
        (cx + 9, cy + 8), (cx + 3, cy + 12),
        (cx, cy + 9), (cx - 3, cy + 12), (cx - 9, cy + 8),
    ], ROBE)
    # Liturgical sky/ice vertical stole stripe
    if d == "front":
        body.rect(cx - 2, cy - 9, 4, 17, "deep")
        body.rect(cx - 1, cy - 8, 2, 15, "sky")
        body.set(cx, cy - 6, "ice", protect=True)
        body.set(cx, cy, "ice", protect=True)
    elif d == "back":
        body.line(cx, cy - 10, cx, cy + 8, "blue")
        body.rect(cx - 4, cy - 7, 8, 2, "sky")

    # Tall eclipse-miter hood
    hx = cx + (1.5 if d == "side" else 0.0)
    hy = cy - 17.0
    body.shaded_poly([
        (hx - 7, hy + 5), (hx - 6, hy - 5),
        (hx, hy - 14),
        (hx + 6, hy - 5), (hx + 7, hy + 5),
    ], MITER)
    # Crescent eclipse emblem on miter peak + sky trim
    body.line(hx - 6, hy - 3, hx, hy - 13, "sky")
    body.circle(hx, hy - 8, 2.3, "ice", protect=True)
    body.circle(hx + 1.0, hy - 8.2, 1.8, "void", protect=True)

    # Singing hollow mask + glowing ice eyes & open singing O-mouth during tell/commit
    singing = ctx.is_tell or ctx.is_commit
    if d == "front":
        body.shaded_ellipse(hx, hy + 1.0, 4.8, 4.4, ("void", "void", "night"))
        body.eye(hx - 2.6, hy - 0.8, "ice", "cream", "void", 2, 2)
        body.eye(hx + 0.8, hy - 0.8, "ice", "cream", "void", 2, 2)
        if singing:
            body.ellipse(hx, hy + 3.0, 2.2, 2.6, "ice", protect=True)
            body.set(hx, hy + 3.0, "cream", protect=True)
    elif d == "side":
        body.shaded_ellipse(hx + 2.8, hy + 1.0, 3.4, 4.2, ("void", "void", "night"))
        body.eye(hx + 3.0, hy - 0.8, "ice", "cream", "void", 2, 2)
        if singing:
            body.ellipse(hx + 4.5, hy + 3.0, 1.8, 2.4, "ice", protect=True)

    # Floating glowing ice sheet-music folio held in front!
    if d != "back":
        sx_m = cx + (9.5 if d == "side" else 0.0)
        sy_m = cy - 3.5 - (2.5 if singing else 0.0)
        body.shaded_rect(sx_m - 5, sy_m - 4, 10, 7, ("blue", "sky", "ice", "cream"))
        body.line(sx_m - 3, sy_m - 2, sx_m + 3, sy_m - 2, "deep", protect=True)
        body.line(sx_m - 3, sy_m, sx_m + 3, sy_m, "deep", protect=True)
        body.set(sx_m - 1, sy_m - 2, "void", protect=True)
        body.set(sx_m + 2, sy_m, "void", protect=True)

    # Tell / commit / stagger FX (ice harmonic rings & floating musical notes!)
    if ctx.is_tell and u > 0.25:
        nx = hx + (8 if d == "side" else 0)
        ny = hy - 2 - u * 5.0
        fx_front.ring(nx, hy + 2, 10.0 - u * 4.0, "ice", 1.2, protect=True)
        fx_front.rect(nx - 2, ny, 2, 2, "cream", protect=True)
        fx_front.line(nx, ny, nx, ny - 4, "ice", protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        ox = cx + (9 if d == "side" else 0)
        oy = cy - 6
        r1 = 7.0 + ctx.fi * 3.8
        fx_front.ring(ox, oy, r1, "sky", 1.8, -60, 60 if d == "side" else 240, protect=True)
        fx_front.ring(ox, oy, r1 + 3.0, "ice", 1.2, -50, 50 if d == "side" else 230, protect=True)
        fx_front.star4(ox + (4 if d == "side" else 0), oy, 2, "cream", "ice")
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 14, 7.5, 2.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="choir_gloam", name="Choir Gloam", out_dir=ART_ENEMIES,
    frame=(64, 72), anchor=(32, 59),
    body_radius=6.0, hit_radius=10.0, body_centre=(32, 38),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_choir_gloam,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
