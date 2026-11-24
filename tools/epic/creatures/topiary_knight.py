#!/usr/bin/env python3
"""Island 4 Enemy: Topiary Knight (sculpted gothic hedge-knight with garden shears) — 64x56, anchor [30, 44]."""
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

HEDGE = ("night", "pine", "teal", "jade")
STONE = ("dusk", "mauve", "stone", "cream")
ROSE = ("plum", "wine", "rose", "cream")
BLADE = ("dusk", "mauve", "stone", "ice")


def _draw_shears(buf: PixelBuf, px: float, py: float, ang_deg: float, open_deg: float) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    for sgn in (-1.0, 1.0):
        b = PixelBuf(buf.w, buf.h)
        b.capsule(px - 6, py + sgn * 1.5, px, py, 1.3, 1.1, ("night", "plum", "wine"))
        pts = [(px, py - sgn * 1.5), (px + 12, py - sgn * 0.4), (px + 14, py + sgn * 0.6), (px + 2, py + sgn * 1.8)]
        b.shaded_poly(pts, BLADE)
        b.line(px + 2, py, px + 13, py, "cream")
        tmp.composite(rotate_buf(b, px, py, sgn * open_deg))
    tmp.circle(px, py, 1.5, "gold", protect=True)
    buf.composite(rotate_buf(tmp, px, py, ang_deg))


def draw_topiary_knight(ctx: FrameCtx) -> Image.Image:
    w, h = 66, 64
    ax, ay = 32.0, 52.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hop = abs(math.sin(ph)) * 1.6 if ctx.anim == "routine" else 0.0
    lean = 0.0
    shear_ang = -14.0
    shear_open = 10.0
    crest_lag = math.sin(lph) * 1.8
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        shear_ang = -42.0 * u - 14.0
        shear_open = 12.0 + 24.0 * u
        sx, sy = 0.96, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lean = 4.5 * sm
        shear_ang = -28.0 + 70.0 * sm
        shear_open = 34.0 * (1.0 - sm) + 4.0
        sx, sy = 1.07, 0.94
    elif ctx.is_recover:
        lean = 2.8
        shear_ang = 24.0
        shear_open = 3.0
    elif ctx.is_stagger:
        lean = -3.0 + math.sin(ph * 2.0) * 1.5
        shear_ang = -44.0
        shear_open = 22.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - hop
    shadow.contact_shadow(ax, ay + 1.0, 10.5, 1.8, "night")

    # Carved gothic stone garden plinth & mossy sabatons
    body.shaded_rect(cx - 9, cy - 4, 18, 5, STONE)
    body.shaded_rect(cx - 7, cy - 7, 14, 4, ("night", "dusk", "mauve"))

    # Sculpted jagged boxwood hedge cuirass (not a smooth pill — tufted foliage silhouette!)
    body.shaded_poly([
        (cx - 10, cy - 23), (cx + 10, cy - 23),
        (cx + 12, cy - 16), (cx + 10, cy - 12), (cx + 11, cy - 8),
        (cx + 8, cy - 6), (cx - 8, cy - 6),
        (cx - 11, cy - 8), (cx - 10, cy - 12), (cx - 12, cy - 16),
    ], HEDGE)
    # Deep dark pine leaf-shadow crevices + jagged twig-leaf tufts breaking outline
    body.line(cx - 6, cy - 18, cx - 2, cy - 14, "night")
    body.line(cx + 5, cy - 19, cx + 2, cy - 13, "night")
    for tx, ty in [(-11, -18), (11, -17), (-10, -10), (10, -9)]:
        body.poly([(cx + tx, cy + ty), (cx + tx + (3 if tx > 0 else -3), cy + ty - 2), (cx + tx, cy + ty + 2)], "jade")

    # Spiky clipped topiary pauldrons with rosebud rivets
    for sgn in (-1.0, 1.0):
        px_s = cx + sgn * (9.5 if d != "side" else 4.5)
        body.shaded_poly([
            (px_s - sgn * 3, cy - 23), (px_s + sgn * 4, cy - 25),
            (px_s + sgn * 5, cy - 18), (px_s - sgn * 2, cy - 17),
        ], HEDGE)
        body.circle(px_s + sgn * 2, cy - 21, 1.4, "rose", protect=True)

    # Diagonal briar-vine sash & stone rose-clasp belt
    body.line(cx - 7, cy - 21, cx + 7, cy - 12, "wine")
    body.rect(cx - 8, cy - 12, 16, 2, "mauve")
    body.rect(cx - 2, cy - 13, 4, 4, "rose", protect=True)
    body.set(cx - 1, cy - 12, "cream", protect=True)

    # Knightly visored hedge helm + carved stone cheek guards + blooming layered rose crest
    hx = cx + (1.5 if d == "side" else 0.0)
    hy = cy - 28.0
    body.shaded_poly([
        (hx - 7, hy - 5), (hx - 4, hy - 9), (hx + 4, hy - 9), (hx + 7, hy - 5),
        (hx + 8, hy + 2), (hx + 5, hy + 5), (hx - 5, hy + 5), (hx - 8, hy + 2),
    ], HEDGE)
    # Blooming crimson rose crest + dark thorn leaves
    rx, ry = hx + crest_lag * 0.6, hy - 9.0
    body.shaded_ellipse(rx, ry, 5.2, 3.8, ROSE, spec_col="cream")
    body.circle(rx - 4.0, ry + 1.8, 2.2, "wine")
    body.circle(rx + 4.0, ry + 1.8, 2.2, "rose")
    body.poly([(rx - 7, ry + 2), (rx - 4, ry + 1), (rx - 5, ry + 4)], "lime")
    body.poly([(rx + 7, ry + 2), (rx + 4, ry + 1), (rx + 5, ry + 4)], "lime")

    if d == "front":
        # Carved stone cheek plates + dark visor slit + fierce rose-gold eyes
        body.rect(hx - 7, hy - 3, 2, 6, "stone")
        body.rect(hx + 5, hy - 3, 2, 6, "stone")
        body.rect(hx - 5, hy - 2, 10, 4, "void", protect=True)
        body.eye(hx - 3.5, hy - 1.5, "rose", "cream", "void", 2, 2)
        body.eye(hx + 1.5, hy - 1.5, "rose", "cream", "void", 2, 2)
        # Sculpted heraldic leaf-buckler with rose emblem
        body.shaded_poly([(cx - 15, cy - 16), (cx - 10, cy - 23), (cx - 5, cy - 16), (cx - 10, cy - 9)], HEDGE)
        body.line(cx - 10, cy - 21, cx - 10, cy - 11, "lime")
        body.circle(cx - 10, cy - 16, 1.8, "rose", protect=True)
        _draw_shears(body, cx + 11, cy - 16, shear_ang - 25, shear_open)
    elif d == "side":
        body.rect(hx + 2, hy - 2, 5, 4, "void", protect=True)
        body.eye(hx + 3.5, hy - 1.5, "rose", "cream", "void", 2, 2)
        body.shaded_poly([(cx - 5, cy - 21), (cx - 13 - crest_lag, cy - 8), (cx - 7, cy - 7)], ("void", "pine", "teal"))
        _draw_shears(body, cx + 6, cy - 15, shear_ang, shear_open)
    else:
        body.shaded_poly([(cx - 10, cy - 21), (cx + 10, cy - 21), (cx + 12, cy - 7), (cx, cy - 10), (cx - 12, cy - 7)], ("night", "pine", "teal"))
        for bx, by in [(-5, -16), (4, -14), (0, -19)]:
            body.circle(cx + bx, cy + by, 1.6, "rose", protect=True)
            body.set(cx + bx, cy + by, "cream", protect=True)
        _draw_shears(body, cx + 10, cy - 16, shear_ang - 40, shear_open)

    if ctx.is_tell and u > 0.35:
        gx = cx + (14 if d == "side" else 13)
        fx_front.star4(gx, cy - 20, 3 if u > 0.72 else 2, "cream", "rose")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 15, 15, 12, -62, 62, 5.0, ("jade", "lime", "cream"))
        else:
            fx_front.slash_arc(cx + 3, cy - 14, 17, 11, -30, 145, 4.8, ("jade", "lime", "cream"))
        for k in range(3):
            fx_front.rect(cx + 10 + k * 3, cy - 20 + k * 4, 2, 1, "rose" if k % 2 == 0 else "lime", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 13, 8.5, 2.8, ph)
        fx_front.rect(cx - 12, cy - 24 + ctx.fi * 2, 2, 2, "lime", protect=True)
        fx_front.rect(cx + 11, cy - 22 + ctx.fi * 2, 2, 2, "rose", protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="topiary_knight", name="Topiary Knight", out_dir=ART_ENEMIES,
    frame=(66, 64), anchor=(32, 52),
    body_radius=7.5, hit_radius=11.0, body_centre=(32, 37),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_topiary_knight,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
