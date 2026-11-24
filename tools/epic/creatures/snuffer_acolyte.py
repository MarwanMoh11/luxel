#!/usr/bin/env python3
"""Island 1 Enemy: Snuffer Acolyte (hooded moth-monk with brass candle-snuffer pole) — 60x56, anchor [30, 46]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_ENEMIES, CACHE_DIR, ENEMY_ANIMS, RAMPS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

ROBE = ("void", "night", "dusk", "plum")
HOOD = ("night", "dusk", "plum", "mauve")
BRASS = ("plum", "coral", "apricot", "gold")
SASH = ("mauve", "stone", "cream")


def _draw_snuffer_pole(buf: PixelBuf, px: float, py: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.capsule(px, py + 8, px, py - 18, 1.3, 1.2, RAMPS["wood"])
    # Curved brass crook and inverted candle-snuffer cone bell
    tmp.line(px, py - 18, px + 5, py - 20, "gold")
    tmp.line(px + 5, py - 20, px + 7, py - 17, "apricot")
    cx, cy = px + 7, py - 13
    cone_ramp = ("coral", "apricot", "gold", "cream") if hot else BRASS
    tmp.shaded_poly([
        (cx, cy - 5),
        (cx - 4.8, cy + 3.5),
        (cx + 4.8, cy + 3.5),
    ], cone_ramp)
    tmp.line(cx - 5, cy + 3.5, cx + 5, cy + 3.5, "cream" if hot else "gold", protect=True)
    tmp.set(cx, cy - 5, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, ang_deg))


def draw_snuffer_acolyte(ctx: FrameCtx) -> Image.Image:
    w, h = 66, 62
    ax, ay = 33.0, 52.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = abs(math.sin(ph)) * 1.8 if ctx.anim == "routine" else 0.0
    lean = 0.0
    pole_ang = math.sin(ph) * 6.0
    crouch = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 2.6 * u
        pole_ang = -36.0 * u
        lean = -2.2 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        lean = 5.5 * sm
        crouch = 1.5 * sm
        pole_ang = 52.0 * sm - 12.0 * (1.0 - sm)
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        lean = 2.0 * (1.0 - u)
        crouch = 2.8
        pole_ang = 24.0
    elif ctx.is_stagger:
        lean = -2.0 + math.sin(ph * 2.0) * 1.8
        pole_ang = -28.0 + math.sin(ph * 2.0) * 10.0
        crouch = 2.5

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 1.5, 9.5, 1.8, "night")

    # Small scurrying robe feet
    stride = math.sin(ph) * 2.6 if ctx.anim == "routine" else (3.5 if ctx.is_commit else 0.0)
    if d == "side":
        body.shaded_ellipse(cx - 3.5 + stride, ay - 1.2, 3.2, 2.0, ("void", "night", "dusk"))
        body.shaded_ellipse(cx + 3.5 - stride, ay - 1.0, 3.2, 2.0, ("void", "night", "dusk"))
    else:
        body.shaded_ellipse(cx - 4.2, ay - 1.0 + stride * 0.4, 3.0, 2.0, ("void", "night", "dusk"))
        body.shaded_ellipse(cx + 4.2, ay - 1.0 - stride * 0.4, 3.0, 2.0, ("void", "night", "dusk"))

    # Back snuffer pole for back view
    if d == "back":
        _draw_snuffer_pole(fx_back, cx + 6.0, cy - 13.0, pole_ang * 0.5 - 12.0, ctx.is_tell or ctx.is_commit)

    # Tall slender gothic robe skirt
    skirt_w = 10.0 if d != "side" else 8.8
    body.shaded_poly([
        (cx - skirt_w * 0.65, cy - 22),
        (cx + skirt_w * 0.65, cy - 22),
        (cx + skirt_w, cy - 2),
        (cx - skirt_w, cy - 2),
    ], ROBE)
    # Robe vertical folds & cream/gold trim hem
    body.line(cx - 3, cy - 18, cx - 4, cy - 4, "void")
    body.line(cx + 3, cy - 18, cx + 4, cy - 4, "void")
    body.line(cx - skirt_w + 1, cy - 3, cx + skirt_w - 1, cy - 3, "plum")

    # Hanging cream/gold acolyte stole sash
    if d == "front":
        body.shaded_rect(cx - 2.2, cy - 19, 4.4, 15.0, SASH)
        body.rect(cx - 1.0, cy - 17, 2, 2, "gold", protect=True)
        body.rect(cx - 1.0, cy - 11, 2, 2, "apricot", protect=True)
    elif d == "back":
        # Moth-wing stitch motif on back cloak
        body.shaded_poly([(cx, cy - 18), (cx - 6, cy - 12), (cx - 4, cy - 7), (cx, cy - 12)], ("plum", "mauve"))
        body.shaded_poly([(cx, cy - 18), (cx + 6, cy - 12), (cx + 4, cy - 7), (cx, cy - 12)], ("plum", "mauve"))
        body.set(cx - 3, cy - 12, "gold", protect=True)
        body.set(cx + 3, cy - 12, "gold", protect=True)

    # Shoulder mantle + pointed monk cowl
    hx = cx + (2.5 if d == "side" else 0.0)
    hy = cy - 24.5
    body.shaded_dome(cx, cy - 19.5, 9.5 if d != "side" else 8.5, 6.2, HOOD, bottom_cut=0.2)
    hood_tip_lag = math.sin(lph) * 2.2
    body.shaded_poly([
        (hx - 7.0, hy + 4),
        (hx - 5.5, hy - 5),
        (hx + (-2.5 if d == "side" else 0.0) + hood_tip_lag * 0.5, hy - 12.5),
        (hx + 6.0, hy - 4),
        (hx + 7.0, hy + 4),
    ], HOOD)

    # Tiny moth antennae peeking out from under hood brim
    ant_x = hx + (4.0 if d == "side" else 0.0)
    if d != "back":
        body.ellipse(hx + (2.2 if d == "side" else 0.0), hy + 0.5, 4.6 if d == "front" else 3.4, 4.0, "void")
        if d == "front":
            body.eye(hx - 2.6, hy - 0.5, "apricot" if not ctx.is_tell else "coral", "cream", "void", 2, 2)
            body.eye(hx + 1.0, hy - 0.5, "apricot" if not ctx.is_tell else "coral", "cream", "void", 2, 2)
            body.line(hx - 2, hy - 4, hx - 5, hy - 8 + hood_tip_lag * 0.4, "gold")
            body.line(hx + 2, hy - 4, hx + 5, hy - 8 - hood_tip_lag * 0.4, "gold")
        else:
            body.eye(hx + 2.5, hy - 0.5, "apricot" if not ctx.is_tell else "coral", "cream", "void", 2, 2)
            body.line(ant_x, hy - 4, ant_x + 4, hy - 8 + hood_tip_lag * 0.4, "gold")
            body.line(ant_x - 1, hy - 4, ant_x + 2, hy - 9 - hood_tip_lag * 0.4, "apricot")
    else:
        body.line(hx - 1, hy - 11, hx - 2 + hood_tip_lag, hy - 4, "plum")

    # Front / Side brass candle-snuffer pole
    hot = ctx.is_tell or ctx.is_commit
    if d == "front":
        _draw_snuffer_pole(body, cx + 8.0, cy - 13.0, pole_ang + 8.0, hot)
    elif d == "side":
        _draw_snuffer_pole(body, cx + 5.5, cy - 13.0, pole_ang + 18.0, hot)

    # Telegraph / commit / stagger FX
    if ctx.is_tell and u > 0.35:
        gx = cx + (10 if d == "side" else 8)
        fx_front.star4(gx, cy - 28, 3 if u > 0.72 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 6, cy - 13, 14, 11, -75, 55, 4.6, ("plum", "coral", "gold"))
        else:
            fx_front.slash_arc(cx + 2, cy - 12, 15, 9, 10, 165, 4.6, ("plum", "coral", "gold"))
        fx_front.ring(cx + (11 if d == "side" else 4), cy - 8, 4.0 + ctx.fi * 1.4, "mauve", 1.2, protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 12, 7.5, 2.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="snuffer_acolyte", name="Snuffer Acolyte", out_dir=ART_ENEMIES,
    frame=(66, 62), anchor=(33, 52),
    body_radius=6.0, hit_radius=10.5, body_centre=(33, 33),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_snuffer_acolyte,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
