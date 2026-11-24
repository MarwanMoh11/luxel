#!/usr/bin/env python3
"""Island 8 Enemy: Censer (hooded incense-moth swinging a dusk-smoke thurible) — 64x56, anchor [32, 46]."""
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

COWL = ("void", "night", "dusk", "plum")
ROBE = ("night", "dusk", "plum", "wine")
BRASS = ("plum", "coral", "apricot", "gold")


def _draw_thurible(buf: PixelBuf, fx_b: PixelBuf, tx: float, ty: float, hot: bool, ph: float) -> None:
    # Dusk-smoke trail behind thurible
    for k in range(3):
        sx = tx - math.cos(ph + k * 0.9) * (3.0 + k * 2.5)
        sy = ty - 4.0 - k * 3.0
        fx_b.circle(sx, sy, 3.2 - k * 0.6, "plum" if k < 2 else "dusk")
    # Pierced brass incense orb with glowing coral ember core
    buf.shaded_ellipse(tx, ty, 4.6, 5.0, BRASS, spec_col="cream")
    buf.rect(tx - 4, ty - 1, 8, 2, "void", protect=True)
    buf.rect(tx - 2, ty - 1, 4, 2, "coral" if not hot else "cream", protect=True)
    buf.line(tx, ty - 6, tx, ty - 4, "gold")
    buf.circle(tx, ty + 5.2, 1.4, "gold")


def draw_censer(ctx: FrameCtx) -> Image.Image:
    w, h = 72, 66
    ax, ay = 36.0, 52.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = math.sin(ph) * 2.2 if ctx.anim == "routine" else 0.0
    swing_ang = math.sin(lph) * 0.75
    chain_len = 14.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = -2.2 * u
        swing_ang = -1.65 * u - 0.35 * math.sin(u * math.pi)
        chain_len = 15.5
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        swing_ang = -1.4 + 3.1 * min(1.0, u * 1.4)
        chain_len = 17.5
        sx, sy = 1.09, 0.93
    elif ctx.is_recover:
        hover = 2.0
        swing_ang = 0.55 + math.sin(ph) * 0.25
    elif ctx.is_stagger:
        hover = 3.5
        swing_ang = math.sin(ph * 2.0) * 1.1
        sx, sy = 1.06, 0.94

    cx = ax
    cy = ay - 15.0 - hover
    shadow.contact_shadow(ax, ay + 1.0, 9.5, 1.8, "night")

    # Tattered moth-wing capelets behind torso
    wing_fl = math.sin(ph) * 2.5
    if d != "side":
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (cx + sgn * 4, cy - 6),
                (cx + sgn * 14, cy - 8 - wing_fl),
                (cx + sgn * 16, cy + 2 - wing_fl * 0.4),
                (cx + sgn * 10, cy + 7),
                (cx + sgn * 4, cy + 4),
            ], ROBE)
            body.set(cx + sgn * 13, cy - 2 - wing_fl * 0.4, "coral", protect=True)
    else:
        body.shaded_poly([
            (cx - 2, cy - 6), (cx - 14, cy - 9 - wing_fl),
            (cx - 16, cy + 1 - wing_fl * 0.4), (cx - 9, cy + 7), (cx - 1, cy + 4),
        ], ROBE)
        body.set(cx - 13, cy - 3 - wing_fl * 0.4, "coral", protect=True)

    # Flowing hooded gothic cassock with jagged hem
    body.shaded_poly([
        (cx - 6, cy - 8), (cx + 6, cy - 8),
        (cx + 9, cy + 10), (cx + 4, cy + 8),
        (cx, cy + 11), (cx - 4, cy + 8), (cx - 9, cy + 10),
    ], COWL)
    body.line(cx - 5, cy - 4, cx + 5, cy - 4, "wine")
    body.line(cx - 4, cy - 3, cx + 4, cy - 3, "coral")

    # Pointed moth-cowl hood + dark face void + glowing coral eyes
    hx = cx + (2.0 if d == "side" else 0.0)
    hy = cy - 13.0
    body.shaded_poly([
        (hx - 8, hy + 4), (hx - 6, hy - 6),
        (hx - (2 if d == "side" else 0), hy - 12),
        (hx + 6, hy - 6), (hx + 8, hy + 4),
    ], COWL)
    # Feathered wine-coral antennae poking out of cowl
    body.bezier_limb((hx - 2, hy - 9), (hx - 6, hy - 14), (hx - 8, hy - 13), 1.3, 0.6, ("wine", "coral"), tip_col="apricot")
    body.bezier_limb((hx + 2, hy - 9), (hx + 6, hy - 14), (hx + 8, hy - 13), 1.3, 0.6, ("wine", "coral"), tip_col="apricot")

    if d == "front":
        body.shaded_ellipse(hx, hy + 0.5, 5.2, 4.0, ("void", "void", "night"))
        body.eye(hx - 3.0, hy - 0.5, "coral" if not ctx.is_tell else "gold", "cream", "void", 2, 2)
        body.eye(hx + 1.0, hy - 0.5, "coral" if not ctx.is_tell else "gold", "cream", "void", 2, 2)
    elif d == "side":
        body.shaded_ellipse(hx + 3.2, hy + 0.5, 3.6, 3.8, ("void", "void", "night"))
        body.eye(hx + 3.5, hy - 0.5, "coral" if not ctx.is_tell else "gold", "cream", "void", 2, 2)
    else:
        body.line(hx, hy - 10, hx, hy + 3, "wine")
        body.rect(cx - 2, cy - 4, 4, 8, "plum")

    # Swinging brass chain & smoking thurible (in stagger, chain hangs limp!)
    hand_x = cx + (7.0 if d == "side" else 9.0)
    hand_y = cy - 2.0
    if ctx.is_stagger:
        tx, ty = hand_x + 2.0, ay - 4.0
    else:
        tx = hand_x + math.sin(swing_ang) * chain_len
        ty = hand_y + math.cos(swing_ang) * (chain_len * 0.72)
    tx = max(8.0, min(w - 8.0, tx))
    ty = max(8.0, min(h - 8.0, ty))
    body.chain((hand_x, hand_y), (tx, ty - 4.0), 2.5, "apricot", "gold", "plum", links=5)
    _draw_thurible(body, fx_back, tx, ty, ctx.is_tell or ctx.is_commit, ph)

    if ctx.is_tell and u > 0.35:
        fx_front.ring(tx, ty, 7.5 - u * 3.0, "coral", 1.2, protect=True)
        if u > 0.65:
            fx_front.star4(tx, ty, 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (4 if d == "side" else 0), cy + 1, 21, 14, -75, 85, 5.4, ("wine", "coral", "apricot"))
        for k in range(3):
            fx_front.circle(tx + (k - 1) * 5.0, ty - 3.0 - k * 2.0, 2.5, "plum" if k % 2 == 0 else "dusk")
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 13, 8.0, 2.4, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="censer", name="Censer", out_dir=ART_ENEMIES,
    frame=(72, 66), anchor=(36, 52),
    body_radius=6.5, hit_radius=10.5, body_centre=(36, 35),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_censer,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
