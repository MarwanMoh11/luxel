#!/usr/bin/env python3
"""Island 8 Boss: The Tollmaster (tall plum-velvet ledger-wraith, brass-scale crown & monocle) — 84x84, anchor [42, 68]."""
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

CLOAK = ("void", "night", "dusk", "plum")
VELVET = ("night", "dusk", "plum", "wine")
BRASS = ("plum", "coral", "apricot", "gold")
IRON = ("void", "night", "dusk", "mauve")


def _draw_scale_crown(buf: PixelBuf, hx: float, hy: float, tilt_deg: float, p2: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Tall gothic brass spire crown with wide balance beam & 2 swinging gold weighing pans!
    tmp.shaded_poly([(hx - 7, hy), (hx - 5, hy - 8), (hx, hy - 14), (hx + 5, hy - 8), (hx + 7, hy)], BRASS)
    rad = math.radians(tilt_deg)
    dx = math.cos(rad) * 16.0
    dy = math.sin(rad) * 16.0
    lx, ly = hx - dx, hy - 11.0 - dy
    rx, ry = hx + dx, hy - 11.0 + dy
    tmp.line(lx, ly, rx, ry, "gold")
    tmp.line(lx, ly - 1, rx, ry - 1, "cream", protect=True)
    # Hanging chains & weighted gold pans
    for px_p, py_p in ((lx, ly), (rx, ry)):
        tmp.line(px_p, py_p, px_p - 3, py_p + 7, "apricot")
        tmp.line(px_p, py_p, px_p + 3, py_p + 7, "apricot")
        tmp.shaded_dome(px_p, py_p + 8, 5.0, 3.0, BRASS, bottom_cut=0.5, spec_col="cream")
        if p2:
            tmp.circle(px_p, py_p + 6, 1.8, "coral", protect=True)
    buf.composite(tmp)


def _draw_great_ledger(buf: PixelBuf, lx: float, ly: float, tilt: float, glowing: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Massive iron-bound Great Ledger Shield!
    tmp.shaded_rect(lx - 8, ly - 16, 16, 30, IRON)
    tmp.shaded_rect(lx - 6, ly - 14, 12, 26, VELVET)
    # Brass corner clasps & glowing gold clasp lock
    for cx_o, cy_o in ((-8, -16), (4, -16), (-8, 10), (4, 10)):
        tmp.rect(lx + cx_o, ly + cy_o, 4, 4, "gold")
    tmp.rect(lx - 2, ly - 3, 5, 6, "cream" if glowing else "gold", protect=True)
    tmp.line(lx - 4, ly - 8, lx + 4, ly - 8, "apricot")
    tmp.line(lx - 4, ly + 6, lx + 4, ly + 6, "apricot")
    buf.composite(rotate_buf(tmp, lx, ly, tilt))


def _draw_coin_scepter(buf: PixelBuf, sx_p: float, sy_p: float, tilt: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.capsule(sx_p, sy_p + 10, sx_p + 4, sy_p - 15, 1.5, 1.5, BRASS)
    tmp.ring(sx_p + 5, sy_p - 18, 4.5, "gold", 1.5, protect=True)
    tmp.circle(sx_p + 5, sy_p - 18, 2.4, "cream" if hot else "coral", protect=True)
    buf.composite(rotate_buf(tmp, sx_p, sy_p, tilt))


def draw_tollmaster(ctx: FrameCtx) -> Image.Image:
    w, h = 98, 104
    ax, ay = 49.0, 84.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.2 if ctx.anim in ("routine", "phase2") else 0.0
    scale_tilt = math.sin(lph) * 11.0
    ledger_tilt = math.sin(lph) * 4.0
    scepter_tilt = -math.sin(lph) * 8.0
    lean = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = 3.5 * u
        scale_tilt = -24.0 * u
        ledger_tilt = -16.0 * u
        scepter_tilt = -34.0 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 6.5 * sm
        scale_tilt = 26.0 * sm
        ledger_tilt = 22.0 * sm
        scepter_tilt = 42.0 * sm
        sx, sy = 1.09, 0.93
    elif ctx.is_recover:
        hover = -2.2
        scale_tilt = 15.0
        ledger_tilt = 12.0
    elif ctx.is_stagger:
        hover = -3.5
        scale_tilt = 30.0 + math.sin(ph * 2.0) * 12.0
        lean = math.sin(ph * 2.0) * 3.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 12.0 - hover
    shadow.contact_shadow(ax, ay + 2.0, 16.0, 2.6, "night")

    # Towering tattered plum-velvet wraith coattails floating above ground
    sway = math.sin(lph) * 3.0
    body.shaded_poly([
        (cx - 12, cy - 26), (cx + 12, cy - 26),
        (cx + 16 + sway * 0.4, cy + 6), (cx + 9 + sway, cy + 12),
        (cx + 3 + sway * 0.6, cy + 6), (cx + sway, cy + 13),
        (cx - 4 + sway * 0.6, cy + 6), (cx - 10 + sway, cy + 12),
        (cx - 16 + sway * 0.4, cy + 6),
    ], CLOAK)
    # High regal wine-velvet collar & gold shoulder mantle
    body.shaded_poly([
        (cx - 15, cy - 24), (cx - 12, cy - 35),
        (cx, cy - 30),
        (cx + 12, cy - 35), (cx + 15, cy - 24),
        (cx + 11, cy - 16), (cx - 11, cy - 16),
    ], VELVET)
    body.line(cx - 13, cy - 22, cx + 13, cy - 22, "gold")
    if d == "front":
        # Gold pocket-watch chain across velvet waistcoat
        body.chain((cx - 7, cy - 14), (cx + 7, cy - 14), 3.2, "apricot", "gold", "plum", links=5)
        body.circle(cx, cy - 10, 2.2, "gold", protect=True)
    elif d == "back":
        body.line(cx, cy - 24, cx, cy + 6, "wine")
        body.rect(cx - 4, cy - 20, 8, 2, "gold")

    # Hooded spectral void face with gleaming SINGLE GOLD MONOCLE!
    hx = cx + (3.0 if d == "side" else 0.0)
    hy = cy - 36.0
    body.shaded_ellipse(hx, hy, 8.5 if d != "side" else 7.6, 8.5, ("void", "void", "night", "dusk"))
    if d == "front":
        # Glowing left eye + giant gleaming GOLD MONOCLE on right eye!
        body.eye(hx - 4.0, hy - 1.0, "gold" if not p2 else "coral", "cream", "void", 2, 2)
        body.ring(hx + 3.5, hy - 1.0, 3.6, "gold", 1.3, protect=True)
        body.circle(hx + 3.5, hy - 1.0, 2.2, "cream" if (ctx.is_tell or p2) else "gold", protect=True)
        body.set(hx + 3.5, hy - 1.0, "void", protect=True)
        # Hanging gold monocle chain!
        body.line(hx + 7, hy, hx + 8, hy + 8, "apricot")
    elif d == "side":
        body.ring(hx + 3.8, hy - 1.0, 3.4, "gold", 1.3, protect=True)
        body.circle(hx + 3.8, hy - 1.0, 2.0, "cream" if (ctx.is_tell or p2) else "gold", protect=True)
        body.set(hx + 4.4, hy - 1.0, "void", protect=True)
        body.line(hx + 5, hy + 2, hx + 4, hy + 9, "apricot")
    else:
        body.shaded_ellipse(hx, hy, 8.0, 8.2, VELVET)
        body.line(hx - 5, hy + 2, hx + 5, hy + 2, "gold")

    # Brass Balance-Scale Crown!
    _draw_scale_crown(body, hx, hy - 7.0, scale_tilt, p2)

    # Great Ledger Shield & Coin Scepter!
    hot = p2 or ctx.is_tell or ctx.is_commit
    if d == "front":
        _draw_great_ledger(body, cx - 17.0, cy - 12.0, -ledger_tilt, hot)
        _draw_coin_scepter(body, cx + 16.0, cy - 12.0, scepter_tilt, hot)
    elif d == "side":
        _draw_coin_scepter(fx_back, cx - 7.0, cy - 14.0, scepter_tilt, hot)
        _draw_great_ledger(body, cx + 13.5, cy - 12.0, ledger_tilt, hot)
    else:
        _draw_coin_scepter(body, cx - 16.0, cy - 12.0, -scepter_tilt, hot)
        _draw_great_ledger(body, cx + 17.0, cy - 12.0, ledger_tilt, hot)

    if p2:
        body.crack(cx - 5, cy - 20, cx + 4, cy - 8, "void", "coral", seed=31)
        for k in range(5):
            a = ph + k * (math.tau / 5.0)
            fx_front.circle(cx + math.cos(a) * 24, cy - 20 + math.sin(a) * 11, 1.8, "gold" if k % 2 == 0 else "cream", protect=True)

    if ctx.is_tell and u > 0.28:
        fx_front.star4(hx + (6 if d == "side" else 4), hy - 1, 3 if u > 0.7 else 2, "cream", "gold")
        fx_front.ring(cx, cy - 16, 26.0 - u * 7.0, "gold", 1.2, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 12, cy - 14, 24, 18, -75, 75, 6.2, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 10, 28, 14, 10, 170, 5.8, ("coral", "gold", "cream"))
        # Spraying gold coins!
        for k in range(4):
            ca = -0.5 + k * 0.35
            fx_front.circle(cx + math.cos(ca) * (16 + ctx.fi * 3.5), cy - 14 + math.sin(ca) * 12, 2.0, "gold", protect=True)
    elif ctx.is_stagger:
        # Popped monocle flying off in stagger!
        fx_front.ring(hx + 12, hy - 6 + math.sin(ph) * 3.0, 3.0, "gold", 1.2, protect=True)
        fx_front.dizzy_stars(hx, hy - 22, 12.0, 3.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="tollmaster", name="The Tollmaster", out_dir=ART_BOSSES,
    frame=(98, 104), anchor=(49, 84),
    body_radius=12.5, hit_radius=16.5, body_centre=(49, 55),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_tollmaster,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
