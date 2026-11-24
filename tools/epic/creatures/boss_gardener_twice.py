#!/usr/bin/env python3
"""Island 4 Boss: The Gardener, Twice (tall cloche-domed coat, gold hourglass ribs, rose twin shears) — 84x80, anchor [42, 66]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

COAT = ("void", "night", "dusk", "plum")
COAT_TRIM = ("night", "dusk", "plum", "wine")
GLASS = ("deep", "blue", "sky", "ice")
GOLD = ("wine", "apricot", "gold", "cream")
ROSE_BLADE = ("plum", "wine", "rose", "cream")


def _draw_twin_shears(buf: PixelBuf, px: float, py: float, ang_deg: float, open_deg: float, flip: bool = False) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    s = -1.0 if flip else 1.0
    for sgn in (-1.0, 1.0):
        b = PixelBuf(buf.w, buf.h)
        # Ornate rose-gold pruning blade
        pts = [
            (px - s * 5, py + sgn * 1.4),
            (px + s * 14, py - sgn * 1.2),
            (px + s * 18, py + sgn * 0.4),
            (px + s * 2, py + sgn * 2.2),
        ]
        b.shaded_poly(pts, ROSE_BLADE)
        b.line(px + s * 2, py, px + s * 16, py, "cream", protect=True)
        tmp.composite(rotate_buf(b, px, py, s * sgn * open_deg))
    tmp.circle(px, py, 2.0, "gold", protect=True)
    tmp.set(px, py, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, ang_deg))


def draw_boss_gardener_twice(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 66.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    glide = math.sin(ph) * 1.6 if ctx.anim in ("routine", "phase2") else 0.0
    sway = math.sin(lph) * 3.0
    lean = 0.0
    shear_ang = -16.0
    shear_open = 12.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -4.5 * u
        shear_ang = -46.0 * u - 14.0
        shear_open = 14.0 + 28.0 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lean = 7.5 * sm
        shear_ang = -32.0 + 82.0 * sm
        shear_open = 38.0 * (1.0 - sm) + 4.0
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        lean = 3.5
        shear_ang = 26.0
        shear_open = 4.0
    elif ctx.is_stagger:
        lean = -3.0 + math.sin(ph * 2.0) * 2.2
        shear_ang = -52.0
        shear_open = 24.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 1.5 - glide
    shadow.contact_shadow(ax, ay + 1.5, 14.5, 2.4, "night")

    # Phase 2 rose-echo twin silhouette ghost trailing behind him!
    if p2:
        gx = cx - (9.0 if d == "side" else 7.0) + math.sin(lph) * 2.0
        fx_back.ring(gx, cy - 28.0, 14.0, "rose", 1.0, 20, 340, protect=True)
        fx_back.ellipse(gx, cy - 42.0, 6.0, 8.0, "wine", protect=True)
        fx_back.ellipse(gx, cy - 22.0, 8.0, 14.0, "wine", protect=True)

    # Tall sweeping aristocratic gothic coat (flared hem with falling gold sand trim)
    coat_w = 13.5 if d != "side" else 11.5
    body.shaded_poly([
        (cx - coat_w * 0.65, cy - 36), (cx + coat_w * 0.65, cy - 36),
        (cx + coat_w + sway * 0.3, cy - 3), (cx + coat_w * 0.3, cy - 6),
        (cx, cy - 2), (cx - coat_w * 0.3, cy - 6), (cx - coat_w + sway * 0.3, cy - 3),
    ], COAT)
    # Coat pleats & rose-thorn lapel trim
    body.line(cx - 5, cy - 32, cx - 8 + sway * 0.25, cy - 5, "void")
    body.line(cx + 5, cy - 32, cx + 8 + sway * 0.25, cy - 5, "void")
    body.shaded_dome(cx, cy - 34.0, 13.5 if d != "side" else 10.5, 6.5, COAT_TRIM, bottom_cut=0.25)

    # Signature GOLD HOURGLASS RIBCAGE on chest/back with glowing falling sand!
    hg_x = cx + (3.5 if d == "side" else 0.0)
    hg_y = cy - 23.0
    # Upper & lower brass hourglass frames
    body.rect(hg_x - 6, hg_y - 9, 12, 2, "gold", protect=True)
    body.rect(hg_x - 6, hg_y + 7, 12, 2, "gold", protect=True)
    body.line(hg_x - 5, hg_y - 7, hg_x - 5, hg_y + 7, "apricot")
    body.line(hg_x + 5, hg_y - 7, hg_x + 5, hg_y + 7, "apricot")
    # Hourglass glass bulbs + glowing golden sand cones
    body.shaded_poly([(hg_x - 4, hg_y - 7), (hg_x + 4, hg_y - 7), (hg_x, hg_y)], GOLD)
    body.shaded_poly([(hg_x, hg_y), (hg_x - 4, hg_y + 7), (hg_x + 4, hg_y + 7)], GOLD)
    body.line(hg_x, hg_y - 2, hg_x, hg_y + 5, "cream", protect=True)

    # Tall cracked ICE GLASS BELL-JAR CLOCHE DOME helmet!
    hx = cx + (2.0 if d == "side" else 0.0)
    hy = cy - 45.0
    # Brass collar ring holding the cloche
    body.shaded_ellipse(hx, hy + 7.5, 9.5, 2.8, GOLD)
    # Translucent glass bell-jar dome + finial knob
    body.shaded_dome(hx, hy + 6.5, 9.2, 15.5, GLASS, bottom_cut=0.06, spec_col="cream")
    body.circle(hx, hy - 10.5, 2.4, "gold", protect=True)
    body.set(hx - 0.5, hy - 11.0, "cream", protect=True)
    # Specular glass highlight streak on left edge
    body.line(hx - 5.5, hy - 4.0, hx - 5.5, hy + 4.0, "cream", protect=True)
    # Inside the cloche: floating golden rose & luminous eyes!
    if d == "front":
        body.shaded_ellipse(hx, hy + 1.0, 5.2, 5.4, ("void", "night", "dusk"))
        body.eye(hx - 3.0, hy - 0.5, "rose" if p2 else "gold", "cream", "void", 2, 2)
        body.eye(hx + 1.4, hy - 0.5, "rose" if p2 else "gold", "cream", "void", 2, 2)
        # Blooming rose floating above brow inside cloche
        body.circle(hx, hy - 5.0, 2.2, "rose", protect=True)
        body.set(hx, hy - 5.5, "cream", protect=True)
    elif d == "side":
        body.shaded_ellipse(hx + 1.5, hy + 1.0, 4.4, 5.2, ("void", "night", "dusk"))
        body.eye(hx + 2.8, hy - 0.5, "rose" if p2 else "gold", "cream", "void", 2, 2)
        body.circle(hx, hy - 5.0, 2.2, "rose", protect=True)
    else:
        body.shaded_ellipse(hx, hy + 1.0, 4.8, 5.0, ("void", "night", "dusk"))
        body.circle(hx, hy - 4.0, 2.4, "rose", protect=True)
        body.set(hx, hy - 4.5, "cream", protect=True)

    # Cracked cloche fissure (subtle in P1, glowing rose/gold in P2!)
    body.crack(hx + 3, hy - 7, hx + 6, hy + 4, "deep", "rose" if p2 else "cream", seed=17)

    # Oversized ROSE TWIN SHEARS in both hands
    if d == "front":
        _draw_twin_shears(body, cx - 14.0, cy - 24.0, -shear_ang - 24.0, shear_open, flip=True)
        _draw_twin_shears(body, cx + 14.0, cy - 24.0, shear_ang + 24.0, shear_open, flip=False)
    elif d == "side":
        _draw_twin_shears(body, cx + 9.0, cy - 24.0, shear_ang, shear_open, flip=False)
    else:
        _draw_twin_shears(body, cx - 14.0, cy - 25.0, -shear_ang - 36.0, shear_open, flip=True)
        _draw_twin_shears(body, cx + 14.0, cy - 25.0, shear_ang + 36.0, shear_open, flip=False)

    # Phase 2 / Tell / Commit / Stagger FX
    if p2:
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 18, cy - 28 + math.sin(a) * 13, "rose" if k % 2 == 0 else "gold", protect=True)

    if ctx.is_tell and u > 0.28:
        fx_back.ring(hx, hy, 12.0 + u * 5.0, "rose", 1.2, protect=True)
        gx = cx + (17 if d == "side" else 0)
        fx_front.star4(gx, cy - 28, 4 if u > 0.72 else 3, "cream", "rose")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 10, cy - 24, 20, 15, -68, 68, 5.8, ("wine", "rose", "cream"))
            fx_front.slash_arc(cx + 12, cy - 24, 16, 12, -55, 55, 3.2, ("apricot", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 20, 24, 13, 10, 170, 5.6, ("wine", "rose", "cream"))
        for k in range(4):
            fx_front.rect(cx - 12 + k * 9, cy - 34 + (k % 2) * 10, 2, 2, "rose" if k % 2 == 0 else "gold", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 14.0, 10.5, 3.2, ph)
        fx_front.ring(hx, hy, 12.5, "ice", 1.0, -40, 40, protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="boss_gardener_twice", name="The Gardener, Twice", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 66),
    body_radius=10.5, hit_radius=15.0, body_centre=(42, 42),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="dusk",
    draw_frame=draw_boss_gardener_twice,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
