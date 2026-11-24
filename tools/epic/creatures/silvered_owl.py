#!/usr/bin/env python3
"""Island 7 Enemy: Silvered Owl (Chrome Horned Stealth Sniper Owl with twin coral sights) — 64x56, anchor [32, 46]."""
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

CHROME = ("deep", "blue", "sky", "ice")
CHROME_BRIGHT = ("blue", "sky", "ice", "cream")
DARK_WING = ("void", "night", "deep", "blue")


def _draw_chrome_wing(buf: PixelBuf, ox: float, oy: float, sgn: float, flap: float, tuck: float) -> None:
    span = 18.0 * (1.0 - tuck * 0.45)
    pts = [
        (ox, oy - 2),
        (ox + sgn * (span * 0.65), oy - 9 - flap),
        (ox + sgn * span, oy - 3 - flap * 0.5),
        (ox + sgn * (span * 0.85), oy + 4 - flap * 0.2),
        (ox + sgn * (span * 0.35), oy + 6),
        (ox, oy + 4),
    ]
    buf.shaded_poly(pts, CHROME)
    buf.line(ox, oy - 2, ox + sgn * (span * 0.65), oy - 9 - flap, "cream", protect=True)
    buf.line(ox + sgn * (span * 0.35), oy + 2, ox + sgn * (span * 0.8), oy + 1 - flap * 0.2, "night")


def draw_silvered_owl(ctx: FrameCtx) -> Image.Image:
    w, h = 72, 68
    ax, ay = 36.0, 56.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = math.sin(ph) * 2.2
    flap = math.sin(ph) * 5.5
    tuck = 0.0
    dive_lean = 0.0
    alt = 12.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        tuck = 0.75 * u
        flap = 4.0 * u
        alt = 14.0 + 2.0 * u
        sx, sy = 0.92, 1.08
    elif ctx.is_commit:
        tuck = 0.90
        dive_lean = 5.0
        alt = 6.0
        sx, sy = 1.15, 0.88
    elif ctx.is_recover:
        # Perched grounded & vulnerable!
        tuck = 0.85
        alt = 2.0
        hover = 0.0
        flap = -2.0
    elif ctx.is_stagger:
        tuck = 0.30
        alt = 4.0
        flap = math.sin(ph * 2.0) * 4.0
        sx, sy = 1.06, 0.92

    cx = ax + (dive_lean if d == "side" else 0.0)
    cy = ay - alt + hover
    # Crisp dark floor shadow (key gameplay tell when stealth-cloaked!)
    shadow.contact_shadow(ax, ay + 1.5, 11.0, 2.2, "void")

    # Swept chrome wings
    if d != "side":
        _draw_chrome_wing(body, cx - 5, cy - 10, -1.0, flap, tuck)
        _draw_chrome_wing(body, cx + 5, cy - 10, 1.0, flap, tuck)
    else:
        _draw_chrome_wing(fx_back, cx - 2, cy - 12, -1.0, flap + 2.5, tuck * 0.8)
        _draw_chrome_wing(body, cx - 3, cy - 9, -1.0, flap, tuck)

    # Crescent tail feathers
    tail_lag = math.sin(lph) * 2.0
    body.shaded_poly([
        (cx - 4, cy - 2), (cx + 4, cy - 2),
        (cx + 6 + tail_lag * 0.4, cy + 5), (cx, cy + 3), (cx - 6 + tail_lag * 0.4, cy + 5),
    ], DARK_WING)

    # Faceted chrome owl torso
    body.shaded_poly([
        (cx, cy - 18), (cx + 7, cy - 12), (cx + 6, cy - 3),
        (cx, cy + 1), (cx - 6, cy - 3), (cx - 7, cy - 12),
    ], CHROME)
    # Mirror-breast chevron
    if d == "front":
        body.shaded_poly([(cx - 4, cy - 12), (cx + 4, cy - 12), (cx, cy - 4)], CHROME_BRIGHT)
        body.line(cx, cy - 12, cx, cy - 4, "night")
    elif d == "back":
        body.shaded_poly([(cx - 5, cy - 12), (cx + 5, cy - 12), (cx, cy - 2)], DARK_WING)
        body.line(cx, cy - 15, cx, cy - 2, "ice")

    # Horned owl head with sharp metallic ear tufts
    hx = cx + (2.5 if d == "side" else 0.0)
    hy = cy - 19.0
    body.shaded_ellipse(hx, hy, 6.5, 5.5, CHROME_BRIGHT, spec_col="cream")
    # Sharp chrome ear-horns
    if d != "side":
        body.shaded_poly([(hx - 3, hy - 4), (hx - 9, hy - 11), (hx - 1, hy - 6)], CHROME_BRIGHT)
        body.shaded_poly([(hx + 3, hy - 4), (hx + 9, hy - 11), (hx + 1, hy - 6)], CHROME_BRIGHT)
    else:
        body.shaded_poly([(hx - 1, hy - 4), (hx - 7, hy - 11), (hx + 2, hy - 5)], CHROME_BRIGHT)
        body.shaded_poly([(hx + 1, hy - 4), (hx - 2, hy - 10), (hx + 3, hy - 5)], CHROME)

    # Piercing coral targeting eyes & sharp beak
    if d == "front":
        body.eye(hx - 3.2, hy - 0.5, "coral", "cream", "void", 2, 2)
        body.eye(hx + 1.8, hy - 0.5, "coral", "cream", "void", 2, 2)
        body.poly([(hx - 1.5, hy + 1.5), (hx + 1.5, hy + 1.5), (hx, hy + 4.5)], "gold", protect=True)
    elif d == "side":
        body.eye(hx + 2.8, hy - 0.5, "coral", "cream", "void", 2, 2)
        body.poly([(hx + 5, hy + 0.5), (hx + 9, hy + 2.0), (hx + 5, hy + 3.5)], "gold", protect=True)
    else:
        body.line(hx, hy - 4, hx, hy + 4, "night")

    # Talons tucked or gripping ground on recover
    if ctx.is_recover:
        body.line(cx - 3, cy + 1, cx - 5, cy + 4, "gold")
        body.line(cx + 3, cy + 1, cx + 5, cy + 4, "gold")

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.25:
        gx = hx + (7.0 if d == "side" else 0.0)
        gy = hy + (1.0 if d == "side" else 5.0)
        fx_front.star4(gx, gy, 3 if u > 0.65 else 2, "cream", "coral")
        fx_front.ring(gx, gy, 3.0 + (1.0 - u) * 6.0, "coral", 1.2)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 10, cy - 8, 16, 10, -45, 45, 4.8, ("coral", "ice", "cream"))
            fx_front.line(cx - 10, cy - 10, cx + 18, cy - 8, "cream", protect=True)
        else:
            fx_front.slash_arc(cx, cy - 6, 18, 11, 15, 165, 4.8, ("coral", "ice", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 10, 8.5, 2.4, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="silvered_owl", name="Silvered Owl", out_dir=ART_ENEMIES,
    frame=(72, 68), anchor=(36, 56),
    body_radius=6.5, hit_radius=10.5, body_centre=(36, 40),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_silvered_owl,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
