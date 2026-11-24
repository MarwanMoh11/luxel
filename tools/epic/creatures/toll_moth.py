#!/usr/bin/env python3
"""Island 1 Enemy: Toll Moth (velvet bell-patterned moth with swinging brass clapper-bell) — 60x52, anchor [30, 42]."""
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

VELVET = ("night", "dusk", "plum", "wine")
BRASS = ("plum", "coral", "apricot", "gold")
RUFF = ("mauve", "stone", "cream")


def _draw_wing(buf: PixelBuf, ox: float, oy: float, sgn: float, lift: float, wide: float) -> None:
    buf.shaded_poly([
        (ox, oy - 2),
        (ox + sgn * (15 * wide), oy - 11 - lift),
        (ox + sgn * (18 * wide), oy - 4 - lift * 0.6),
        (ox + sgn * (14 * wide), oy + 3 - lift * 0.2),
        (ox, oy + 2),
    ], VELVET)
    buf.shaded_poly([
        (ox, oy + 1),
        (ox + sgn * (13 * wide), oy + 3 - lift * 0.2),
        (ox + sgn * (11 * wide), oy + 10),
        (ox + sgn * (4 * wide), oy + 9),
        (ox, oy + 4),
    ], ("night", "dusk", "plum"))
    ex = ox + sgn * (9.5 * wide)
    ey = oy - 4.0 - lift * 0.55
    buf.shaded_dome(ex, ey + 1.5, 2.8 * wide, 3.4, ("coral", "apricot", "gold"), bottom_cut=0.55, protect=True)
    buf.set(ex, ey, "cream", protect=True)
    buf.set(ox + sgn * (16 * wide), oy - 4 - lift * 0.6, "apricot", protect=True)
    buf.set(ox + sgn * (13 * wide), oy + 1 - lift * 0.2, "gold", protect=True)


def draw_toll_moth(ctx: FrameCtx) -> Image.Image:
    w, h = 66, 58
    ax, ay = 33.0, 47.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = math.sin(ph) * 2.4 if ctx.anim == "routine" else 0.0
    wing_lift = math.sin(ph) * 5.6
    wing_wide = 0.85 + 0.14 * math.cos(ph)
    bell_swing = math.sin(lph) * 3.6
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        wing_lift = 7.0 * u
        wing_wide = 0.72 + 0.24 * (1.0 - u)
        bell_swing = -5.5 * u
        hover = -2.0 * u
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        wing_lift = 6.5 - 14.0 * sm
        wing_wide = 1.04
        bell_swing = 7.0 * sm
        hover = 1.8 * sm
        sx, sy = 1.07, 0.94
    elif ctx.is_recover:
        wing_lift = -3.0 + 4.0 * u
        bell_swing = 2.0 * math.cos(ph)
    elif ctx.is_stagger:
        wing_lift = math.sin(ph * 2.0) * 5.5
        bell_swing = -4.2 * math.cos(ph * 2.0)
        hover = 2.8

    cx = ax
    cy = ay - 16.5 - hover
    shadow.contact_shadow(ax, ay + 1.0, 8.5 - hover * 0.3, 1.6, "night")

    if d != "side":
        _draw_wing(body, cx - 2, cy, -1.0, wing_lift, wing_wide)
        _draw_wing(body, cx + 2, cy, 1.0, wing_lift, wing_wide)
    else:
        _draw_wing(fx_back, cx - 2, cy - 2, -1.0, wing_lift + 2.8, 0.90)
        _draw_wing(body, cx - 1, cy, -1.0, wing_lift, 1.00)

    bx = cx + bell_swing
    by = cy + 10.0
    body.line(cx, cy + 4, bx, by - 3, "gold")
    body.shaded_dome(bx, by + 1, 4.4, 5.4, BRASS, bottom_cut=0.55, spec_col="cream")
    body.rect(bx - 5, by + 3, 10, 2, "gold")
    body.circle(bx + bell_swing * 0.25, by + 5.5, 1.6, "cream", protect=True)

    body.shaded_ellipse(cx, cy + 1, 4.8, 5.6, VELVET)
    body.shaded_ellipse(cx, cy - 4.0, 5.5, 3.0, RUFF)

    hx = cx + (2.5 if d == "side" else 0.0)
    hy = cy - 7.5
    body.shaded_ellipse(hx, hy, 4.2, 3.8, ("night", "dusk", "plum"))
    ant_lag = math.sin(lph) * 1.7
    if d != "side":
        body.bezier_limb((hx - 2, hy - 3), (hx - 6, hy - 9 + ant_lag), (hx - 9, hy - 8 + ant_lag), 1.4, 0.7, ("apricot", "gold"), tip_col="cream")
        body.bezier_limb((hx + 2, hy - 3), (hx + 6, hy - 9 - ant_lag), (hx + 9, hy - 8 - ant_lag), 1.4, 0.7, ("apricot", "gold"), tip_col="cream")
    else:
        body.bezier_limb((hx + 1, hy - 3), (hx + 5, hy - 10 + ant_lag), (hx + 9, hy - 9 + ant_lag), 1.4, 0.7, ("apricot", "gold"), tip_col="cream")
        body.bezier_limb((hx - 1, hy - 3), (hx + 2, hy - 10 - ant_lag), (hx + 5, hy - 11 - ant_lag), 1.2, 0.6, ("coral", "gold"))

    if d == "front":
        body.eye(hx - 2.8, hy - 0.8, "gold", "cream", "void", 2, 2)
        body.eye(hx + 0.8, hy - 0.8, "gold", "cream", "void", 2, 2)
    elif d == "side":
        body.eye(hx + 1.8, hy - 0.8, "gold", "cream", "void", 2, 2)
    else:
        body.rect(cx - 1, cy - 2, 2, 5, "gold", protect=True)
        body.set(cx, cy - 3, "cream", protect=True)

    if ctx.is_tell and u > 0.30:
        fx_front.ring(bx, by + 2, 9.0 - u * 3.5, "gold", 1.0)
        if u > 0.65:
            fx_front.star4(bx, by + 4, 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        r1 = 8.5 + ctx.fi * 2.8
        fx_front.ring(bx, by + 2, r1, "gold", 1.5, -55, 55 if d == "side" else 235, protect=True)
        fx_front.ring(bx, by + 2, r1 + 2.8, "cream", 1.0, -45, 45 if d == "side" else 225, protect=True)
        fx_front.star4(bx + (5 if d == "side" else 0), by + 3, 2, "cream", "gold")
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 9, 8.0, 2.4, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="toll_moth", name="Toll Moth", out_dir=ART_ENEMIES,
    frame=(66, 58), anchor=(33, 47),
    body_radius=6.5, hit_radius=10.0, body_centre=(33, 30),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_toll_moth,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
