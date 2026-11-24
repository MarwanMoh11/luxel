#!/usr/bin/env python3
"""Island 7 Mini-Boss: Kaleidoscope Duchess (Crystalline moth-noble with 4-faceted chromatic diamond wings & prism parasol) — 86x86, anchor [43, 72]."""
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

WING_GOLD = ("apricot", "gold", "cream")
WING_BLUE = ("deep", "blue", "sky", "ice")
WING_ROSE = ("plum", "wine", "rose", "cream")
WING_ICE = ("blue", "sky", "ice", "cream")
BODICE = ("night", "deep", "blue", "sky")


def draw_kaleidoscope_duchess(ctx: FrameCtx) -> Image.Image:
    w, h = 86, 86
    ax, ay = 43.0, 72.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.4
    wing_flap = math.sin(ph * 1.5) * 4.0
    para_spin = math.sin(lph * 2.0) * 3.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = -2.8 * u
        wing_flap = -7.0 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        wing_flap = 8.0 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        hover = 2.8
        wing_flap = 4.0
    elif ctx.is_stagger:
        hover = 4.5
        wing_flap = 7.0
        sx, sy = 1.08, 0.90

    cx = ax
    cy = ay - 7.0 + hover

    # Crisp SE truth shadow (the signature Duchess tell!)
    shadow.contact_shadow(ax + 4.0, ay + 2.0, 14.0, 3.0, "night")
    shadow.set(ax + 12.0, ay + 3.0, "gold", protect=True)

    # 4-Faceted Stained-Glass Diamond Wings (Gold NW, Ice NE, Blue SW, Rose SE — unmistakable silhouette!)
    if d != "side":
        # Upper Left Wing: GOLD facet
        body.shaded_poly([
            (cx - 5, cy - 28), (cx - 24, cy - 42 - wing_flap),
            (cx - 32, cy - 29 - wing_flap * 0.4), (cx - 18, cy - 20), (cx - 6, cy - 23),
        ], WING_GOLD)
        body.line(cx - 6, cy - 27, cx - 28, cy - 31 - wing_flap * 0.4, "cream", protect=True)
        # Upper Right Wing: ICE facet
        body.shaded_poly([
            (cx + 5, cy - 28), (cx + 24, cy - 42 - wing_flap),
            (cx + 32, cy - 29 - wing_flap * 0.4), (cx + 18, cy - 20), (cx + 6, cy - 23),
        ], WING_ICE)
        body.line(cx + 6, cy - 27, cx + 28, cy - 31 - wing_flap * 0.4, "cream", protect=True)
        # Lower Left Wing: BLUE facet
        body.shaded_poly([
            (cx - 5, cy - 21), (cx - 22, cy - 17),
            (cx - 26, cy - 4 + wing_flap * 0.4), (cx - 12, cy - 5), (cx - 5, cy - 14),
        ], WING_BLUE)
        # Lower Right Wing: ROSE facet
        body.shaded_poly([
            (cx + 5, cy - 21), (cx + 22, cy - 17),
            (cx + 26, cy - 4 + wing_flap * 0.4), (cx + 12, cy - 5), (cx + 5, cy - 14),
        ], WING_ROSE)
        # Diamond leading-edge veins
        for sx_g in (-1.0, 1.0):
            body.star4(cx + sx_g * 22, cy - 33 - wing_flap * 0.5, 2, "cream", "gold" if sx_g < 0 else "rose")
    else:
        fx_back.shaded_poly([
            (cx - 3, cy - 29), (cx - 24, cy - 44 - wing_flap),
            (cx - 29, cy - 26), (cx - 12, cy - 19),
        ], WING_GOLD)
        fx_back.shaded_poly([
            (cx - 3, cy - 20), (cx - 22, cy - 16),
            (cx - 24, cy - 3 + wing_flap * 0.4), (cx - 7, cy - 11),
        ], WING_ROSE)
        fx_back.line(cx - 5, cy - 27, cx - 25, cy - 30 - wing_flap * 0.3, "cream", protect=True)

    # Faceted crystal skirt & slim moth-noble bodice
    sw = 12.0 if d != "side" else 10.0
    body.shaded_poly([
        (cx - 4.5, cy - 29), (cx + 4.5, cy - 29),
        (cx + sw, cy - 5), (cx + 5, cy + 2),
        (cx, cy - 2), (cx - 5, cy + 2), (cx - sw, cy - 5),
    ], BODICE)
    body.shaded_poly([(cx, cy - 27), (cx + 4.5, cy - 17), (cx, cy - 7), (cx - 4.5, cy - 17)], WING_ICE)
    body.line(cx - sw + 1, cy - 5, cx + sw - 1, cy - 5, "gold", protect=True)

    # Twirling Crystalline Prism Parasol held aloft!
    px = cx + (15.0 if d == "side" else 14.0)
    py = cy - 46.0 + para_spin * 0.4
    fx_front.line(cx + (6 if d != "side" else 4), cy - 25, px, py + 4, "gold", protect=True)
    # Multi-color faceted parasol dome
    fx_front.shaded_poly([
        (px - 14, py + 5), (px - 7, py - 3), (px, py - 6),
        (px + 7, py - 3), (px + 14, py + 5),
    ], WING_ICE if not p2 else WING_ROSE)
    fx_front.shaded_poly([(px - 12, py + 4), (px - 5, py - 2), (px, py + 4)], WING_GOLD)
    fx_front.shaded_poly([(px + 12, py + 4), (px + 5, py - 2), (px, py + 4)], WING_ROSE)
    fx_front.line(px - 14, py + 5, px + 14, py + 5, "cream", protect=True)
    fx_front.star4(px, py - 7, 2, "cream", "gold")

    # Crystalline noble head & pointed diamond tiara
    hx = cx + (1.0 if d == "side" else 0.0)
    hy = cy - 37.0
    body.shaded_ellipse(hx, hy, 5.8, 6.4, WING_ICE, spec_col="cream")
    body.shaded_poly([
        (hx - 5, hy - 5), (hx, hy - 14), (hx + 5, hy - 5),
    ], WING_GOLD)
    body.set(hx, hy - 11, "rose", protect=True)

    if d == "front":
        body.eye(hx - 2.3, hy - 0.5, "deep", "cream", "void", 2, 2)
        body.eye(hx + 1.8, hy - 0.5, "rose", "cream", "void", 2, 2)
        body.line(hx - 1.5, hy + 2.8, hx + 1.5, hy + 2.8, "wine", protect=True)
    elif d == "side":
        body.eye(hx + 2.5, hy - 0.5, "rose", "cream", "void", 2, 2)
    else:
        body.shaded_poly([(hx, hy - 4), (hx + 3, hy), (hx, hy + 4), (hx - 3, hy)], WING_ROSE)

    # Tell / Commit / Stagger / P2 FX
    if ctx.is_tell and u > 0.25:
        fx_front.ring(cx, cy - 22, 7.0 + (1.0 - u) * 9.0, "gold", 1.3)
        fx_front.star4(cx, cy - 37, 3, "cream", "ice")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx, cy - 22, 28, 18, -45, 225, 5.0, ("blue", "ice", "cream"))
        fx_front.slash_arc(cx, cy - 22, 22, 13, 0, 180, 3.0, ("wine", "rose", "gold"))
    elif ctx.is_stagger:
        # Comedy beat: covers eyes in shock when bonked by own reflected laser!
        fx_front.dizzy_stars(hx, hy - 14, 11.0, 2.8, ph)
    elif p2:
        # 4-color prism halo ticks
        for ci, ccol in enumerate(("gold", "sky", "rose", "ice")):
            a = ph + ci * (math.pi * 0.5)
            fx_front.star4(cx + math.cos(a) * 25.0, cy - 22.0 + math.sin(a) * 14.0, 2, "cream", ccol)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="kaleidoscope_duchess", name="Kaleidoscope Duchess", out_dir=ART_BOSSES,
    frame=(86, 86), anchor=(43, 72),
    body_radius=10.5, hit_radius=14.5, body_centre=(43, 46),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_kaleidoscope_duchess,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
