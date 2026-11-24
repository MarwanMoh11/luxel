#!/usr/bin/env python3
"""Island 1 Enemy: Lamp Butler (tuxedoed toad-valet with hooded bullseye lamp shield & cane) — 64x58, anchor [32, 48]."""
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

COAT = ("void", "night", "dusk", "plum")
TOAD = ("night", "pine", "teal", "jade")
BRASS = ("plum", "coral", "apricot", "gold")
SILVER = ("dusk", "mauve", "stone", "cream")


def _draw_cane(buf: PixelBuf, x: float, y: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.capsule(x, y + 9, x, y - 10, 1.2, 1.1, ("void", "night", "dusk"))
    tmp.circle(x, y - 11.5, 2.4, "gold" if hot else "cream", protect=True)
    tmp.set(x, y - 12.0, "cream", protect=True)
    buf.composite(rotate_buf(tmp, x, y, ang_deg))


def _draw_bullseye_lamp(buf: PixelBuf, x: float, y: float, side_view: bool, lit: bool) -> None:
    # Hooded brass bullseye lamp (acts as frontal bolt shield!)
    buf.shaded_dome(x, y - 4.0, 5.2, 4.2, BRASS, bottom_cut=0.25)
    buf.shaded_rect(x - 4.5, y - 4.0, 9.0, 9.0, BRASS)
    lx = x + (2.5 if side_view else 0.0)
    buf.circle(lx, y + 0.5, 3.0 if lit else 2.2, "gold" if lit else "apricot", protect=True)
    if lit:
        buf.circle(lx, y + 0.5, 1.5, "cream", protect=True)
    buf.ring(x, y - 7.0, 2.0, "gold", 1.0)


def draw_lamp_butler(ctx: FrameCtx) -> Image.Image:
    w, h = 68, 60
    ax, ay = 34.0, 49.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = abs(math.sin(ph)) * 1.4 if ctx.anim == "routine" else 0.0
    lean = 0.0
    cane_ang = math.sin(ph) * 8.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -2.5 * u
        cane_ang = -52.0 * u
        sx, sy = 0.96, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lean = 5.8 * sm
        cane_ang = 68.0 * sm - 15.0 * (1.0 - sm)
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        lean = 2.2 * (1.0 - u)
        cane_ang = 28.0
    elif ctx.is_stagger:
        lean = -3.0 + math.sin(ph * 2.0) * 2.2
        cane_ang = -40.0 + math.sin(ph * 2.0) * 14.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob
    shadow.contact_shadow(ax, ay + 1.5, 12.0, 2.0, "night")

    # Polished shoes
    stride = math.sin(ph) * 2.4 if ctx.anim == "routine" else 0.0
    if d == "side":
        body.shaded_ellipse(cx - 4.0 + stride, ay - 1.2, 4.2, 2.2, ("void", "night", "dusk"))
        body.shaded_ellipse(cx + 4.5 - stride, ay - 1.0, 4.2, 2.2, ("void", "night", "dusk"))
    else:
        body.shaded_ellipse(cx - 5.2, ay - 1.0 + stride * 0.4, 3.8, 2.2, ("void", "night", "dusk"))
        body.shaded_ellipse(cx + 5.2, ay - 1.0 - stride * 0.4, 3.8, 2.2, ("void", "night", "dusk"))

    # Formal plum tailcoat body
    coat_w = 11.5 if d != "side" else 9.2
    body.shaded_ellipse(cx, cy - 13.0, coat_w, 11.0, COAT)
    tail_lag = math.sin(lph) * 1.6
    if d == "back":
        # Split coattails + exposed cream collar/back (visually reads as sneak-attack vulnerable!)
        body.shaded_poly([(cx - 8, cy - 10), (cx - 1, cy - 10), (cx - 3 + tail_lag, cy - 1), (cx - 10 + tail_lag, cy - 2)], COAT)
        body.shaded_poly([(cx + 1, cy - 10), (cx + 8, cy - 10), (cx + 10 + tail_lag, cy - 2), (cx + 3 + tail_lag, cy - 1)], COAT)
        body.set(cx - 3, cy - 12, "gold", protect=True)
        body.set(cx + 3, cy - 12, "gold", protect=True)
        body.rect(cx - 4, cy - 22, 8, 2, "cream")
    elif d == "front":
        # Crisp cream tuxedo shirtfront + wine bow-tie
        body.shaded_poly([(cx - 4.5, cy - 21), (cx + 4.5, cy - 21), (cx + 2.5, cy - 8), (cx - 2.5, cy - 8)], SILVER)
        body.rect(cx - 3, cy - 20, 6, 2, "wine")
        body.set(cx, cy - 19, "coral", protect=True)
        body.set(cx, cy - 14, "gold", protect=True)
        body.set(cx, cy - 11, "gold", protect=True)
    else:
        # Swept coattail behind in side view + cream cravat in front
        body.shaded_poly([(cx - 5, cy - 12), (cx - 12 + tail_lag, cy - 2), (cx - 6 + tail_lag, cy - 1), (cx - 1, cy - 8)], COAT)
        body.rect(cx + 5, cy - 20, 3, 7, "cream")
        body.rect(cx + 6, cy - 20, 2, 2, "wine")

    # Dignified broad toad-valet head + butler bowler/side-tufts
    hx = cx + (2.5 if d == "side" else 0.0)
    hy = cy - 25.5
    body.shaded_ellipse(hx, hy, 8.2 if d != "side" else 7.2, 6.2, TOAD)
    # Neat little plum bowler hat with gold band!
    body.shaded_dome(hx, hy - 5.0, 6.5, 5.2, COAT, bottom_cut=0.15)
    body.shaded_ellipse(hx, hy - 4.2, 9.2, 2.0, COAT)
    body.line(hx - 6, hy - 5.2, hx + 6, hy - 5.2, "gold", protect=True)

    if d == "front":
        body.line(hx - 5, hy + 2.5, hx + 5, hy + 2.5, "void", protect=True)
        body.eye(hx - 4.2, hy - 1.2, "gold", "cream", "void", 2, 2)
        body.eye(hx + 2.0, hy - 1.2, "gold", "cream", "void", 2, 2)
        # Brass monocle ring on right eye
        body.ring(hx + 3.0, hy - 0.5, 2.4, "gold", 1.0)
    elif d == "side":
        body.line(hx + 2, hy + 2.5, hx + 7, hy + 2.5, "void", protect=True)
        body.eye(hx + 2.6, hy - 1.2, "gold", "cream", "void", 2, 2)
        body.ring(hx + 3.5, hy - 0.5, 2.4, "gold", 1.0)

    # Weapons: hooded bullseye lamp + silver walking cane
    lit = not ctx.is_stagger
    if d == "front":
        _draw_bullseye_lamp(body, cx - 10.0, cy - 13.5, False, lit)
        _draw_cane(body, cx + 11.0, cy - 13.0, cane_ang, ctx.is_tell or ctx.is_commit)
    elif d == "side":
        _draw_cane(fx_back, cx - 2.0, cy - 14.0, cane_ang + 12.0, ctx.is_tell or ctx.is_commit)
        _draw_bullseye_lamp(body, cx + 10.5, cy - 13.5, True, lit)
    else:
        _draw_bullseye_lamp(fx_back, cx - 10.0, cy - 13.5, False, lit)
        _draw_cane(body, cx + 11.0, cy - 13.0, cane_ang * 0.5, False)

    # Telegraph / commit / stagger FX
    if ctx.is_tell and u > 0.35:
        gx = cx + (11 if d == "side" else 11)
        fx_front.star4(gx, cy - 26, 3 if u > 0.72 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 13, 18, 13, -68, 65, 5.2, ("stone", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 10, 19, 11, 12, 168, 5.0, ("stone", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 12, 9.0, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="lamp_butler", name="Lamp Butler", out_dir=ART_ENEMIES,
    frame=(68, 60), anchor=(34, 49),
    body_radius=6.5, hit_radius=11.0, body_centre=(34, 30),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_lamp_butler,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
