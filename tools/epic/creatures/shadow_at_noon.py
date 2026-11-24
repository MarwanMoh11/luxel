#!/usr/bin/env python3
"""Island 7 Superboss: Your Shadow at Noon (Razor-flat living eclipse shadow of Wick with blazing solar corona rim & inverted sundial lantern) — 74x78, anchor [37, 64]."""
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

SHADOW_BODY = ("void", "void", "night", "dusk")
ECLIPSE_RIM = ("coral", "apricot", "gold", "cream")


def draw_shadow_at_noon(ctx: FrameCtx) -> Image.Image:
    w, h = 76, 84
    ax, ay = 38.0, 69.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.0
    stretch_x = 1.0
    stretch_y = 1.0
    blade_swing = 0.0

    if ctx.is_tell:
        hover = -1.8 * u
        stretch_x = 0.90
        stretch_y = 1.07
        blade_swing = -10.0 * u
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        stretch_x = 1.14 if d == "side" else 1.08
        stretch_y = 0.92
        blade_swing = 12.0 * sm
    elif ctx.is_recover:
        # Stretched vulnerable noon shadow body!
        stretch_x = 1.12
        stretch_y = 0.92
        hover = 2.0
    elif ctx.is_stagger:
        stretch_x = 1.18
        stretch_y = 0.84
        hover = 4.0

    cx = ax
    cy = ay - 6.0 + hover

    # Blazing golden Zenith Sundial foreshortened ellipse directly underfoot (0-degree sun!)
    shadow.contact_shadow(ax, ay + 1.0, 15.0, 3.2, "void")
    fx_back.ellipse(ax, ay + 1.5, 18.0, 5.0, "gold" if not p2 else "coral")
    fx_back.ellipse(ax, ay + 1.5, 15.5, 3.8, "void")
    for k in range(8):
        a = k * (math.tau / 8.0) + ph * 0.25
        fx_back.line(
            ax + math.cos(a) * 14.0, ay + 1.5 + math.sin(a) * 3.8,
            ax + math.cos(a) * 20.0, ay + 1.5 + math.sin(a) * 5.6,
            "cream" if k % 2 == 0 else "apricot", protect=True,
        )

    # Blazing Solar Eclipse Corona behind head & cloak (unmistakable silhouette!)
    cor_y = cy - 26.0
    cor_r = 15.0 if not p2 else 17.0
    fx_back.ring(cx, cor_y, cor_r, "coral", 2.0)
    fx_back.ring(cx, cor_y, cor_r - 1.5, "gold", 1.2)
    for k in range(12):
        a = k * (math.tau / 12.0) + lph * 0.4
        r0 = cor_r
        r1 = cor_r + (5.5 if k % 2 == 0 else 3.0)
        fx_back.line(
            cx + math.cos(a) * r0, cor_y + math.sin(a) * r0,
            cx + math.cos(a) * r1, cor_y + math.sin(a) * r1,
            "cream" if k % 2 == 0 else "gold", protect=True,
        )

    # Razor-flat ink-void Wick cloak silhouette with jagged noon-shadow hem!
    cw = 13.0 if d != "side" else 10.5
    body.shaded_poly([
        (cx - 6, cy - 26), (cx + 6, cy - 26),
        (cx + cw, cy - 8), (cx + cw + 3, cy + 2),
        (cx + 6, cy - 4), (cx + 1, cy + 3),
        (cx - 4, cy - 4), (cx - cw - 3, cy + 2),
        (cx - cw, cy - 8),
    ], SHADOW_BODY)
    # Sharp burning solar rim along shadow cloak edges
    body.line(cx - cw - 2, cy + 1, cx - 6, cy - 25, "gold", protect=True)
    body.line(cx + cw + 2, cy + 1, cx + 6, cy - 25, "coral", protect=True)
    body.line(cx - 5, cy - 25, cx + 5, cy - 25, "cream", protect=True)

    # Razor flat Wick hood & twin moth antennae (pure void core + golden eclipse rim!)
    hx = cx + (1.5 if d == "side" else 0.0)
    hy = cy - 33.0
    body.shaded_poly([
        (hx - 7.5, hy + 4), (hx - 6.5, hy - 5), (hx, hy - 11),
        (hx + 6.5, hy - 5), (hx + 7.5, hy + 4),
    ], SHADOW_BODY)
    # Crisp antenna crescents
    body.bezier_limb((hx - 3, hy - 8), (hx - 9, hy - 15), (hx - 12, hy - 12), 1.5, 0.7, SHADOW_BODY, tip_col="gold")
    body.bezier_limb((hx + 3, hy - 8), (hx + 9, hy - 15), (hx + 12, hy - 12), 1.5, 0.7, SHADOW_BODY, tip_col="gold")

    # Piercing noon-cream glowing moth eyes (only thing visible inside the ink-black hood!)
    if d == "front":
        body.shaded_rect(hx - 4.5, hy - 2.0, 3.0, 2.0, ("gold", "cream"))
        body.shaded_rect(hx + 1.5, hy - 2.0, 3.0, 2.0, ("gold", "cream"))
    elif d == "side":
        body.shaded_rect(hx + 2.0, hy - 2.0, 3.5, 2.0, ("gold", "cream"))
    else:
        body.line(hx, hy - 9, hx, hy + 2, "gold", protect=True)

    # Inverted Solar-Black Lantern held in outstretched shadow hand!
    lx = cx + (15.0 if d == "side" else 14.0)
    ly = cy - 18.0 + blade_swing * 0.4
    body.capsule(cx + (4 if d != "side" else 2), cy - 22, lx, ly, 2.0, 1.3, SHADOW_BODY)
    fx_front.shaded_rect(lx - 3.5, ly - 4.0, 7, 8, ECLIPSE_RIM)
    fx_front.shaded_rect(lx - 2.0, ly - 2.5, 4, 5, SHADOW_BODY)
    fx_front.set(lx, ly, "cream", protect=True)

    # P2 Twin flanking sundial crescent echoes!
    if p2:
        for sgn in (-1.0, 1.0):
            ex = cx + sgn * 22.0
            ey = cy - 18.0 + math.sin(ph + sgn) * 3.0
            fx_back.shaded_poly([(ex, ey - 8), (ex + sgn * 4, ey), (ex, ey + 8), (ex - sgn * 2, ey)], SHADOW_BODY)
            fx_back.line(ex, ey - 8, ex + sgn * 4, ey, "gold", protect=True)
            fx_back.line(ex + sgn * 4, ey, ex, ey + 8, "coral", protect=True)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.2:
        fx_front.ring(cx, cy - 20, 8.0 + (1.0 - u) * 10.0, "gold", 1.5)
        fx_front.star4(lx, ly, 3, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (9 if d == "side" else 0), cy - 18, 22, 15, -80, 100, 5.5, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        # Solar flash peels shadow flat!
        fx_front.ring(cx, cy - 16, 14.0, "cream", 1.4)
        fx_front.dizzy_stars(hx, hy - 11, 10.0, 2.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="gold", sx=stretch_x, sy=stretch_y, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="shadow_at_noon", name="Your Shadow at Noon", out_dir=ART_BOSSES,
    frame=(76, 84), anchor=(38, 69),
    body_radius=9.5, hit_radius=13.5, body_centre=(38, 46),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="stone",
    draw_frame=draw_shadow_at_noon,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
