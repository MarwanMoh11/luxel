#!/usr/bin/env python3
"""Island 3 Briar Court Joust 2: Dame Spindle (silk-swinging duelist) — 64x68, anchor [32, 54]."""
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

CAPE = ("dusk", "mauve", "stone", "ice")
ARMOR = ("night", "dusk", "plum", "wine")
NEEDLE = ("wine", "coral", "apricot", "gold")
GOLD_SPOOL = ("plum", "apricot", "gold", "cream")


def _draw_needle_lance(buf: PixelBuf, x: float, y: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ramp = ("coral", "gold", "cream") if hot else NEEDLE
    tmp.shaded_poly([
        (x - 2.0, y - 2.0), (x + 21.0, y), (x - 2.0, y + 2.0),
    ], ramp)
    tmp.line(x, y, x + 20.0, y, "cream" if hot else "gold", protect=True)
    # Ornate rose-gold basket hilt
    tmp.ring(x - 1.5, y, 3.2, "gold", 1.2)
    tmp.circle(x - 1.5, y, 1.5, "ice" if hot else "rose", protect=True)
    buf.composite(rotate_buf(tmp, x, y, ang_deg))


def draw_knight_spindle(ctx: FrameCtx) -> Image.Image:
    w, h = 80, 76
    ax, ay = 40.0, 62.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = math.sin(ph) * 2.0 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    lift = 0.0
    lance_ang = -14.0 + math.sin(ph) * 6.0
    cape_billow = math.sin(lph) * 4.5
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lift = 4.5 * u
        lean = -4.0 * u
        lance_ang = -32.0 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 6.5 * sm
        lift = 5.0 * sm
        lance_ang = 8.0 * sm
        sx, sy = 1.09, 0.92
    elif ctx.is_recover:
        lift = -3.0
        lance_ang = 28.0
    elif ctx.is_stagger:
        lift = -5.0
        lean = math.sin(ph * 2.0) * 3.0
        lance_ang = 54.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 3.0 + bob - lift
    shadow.contact_shadow(ax, ay + 2.0, 12.0 if lift < 2.0 else 9.0, 2.0, "night")

    # Silk swing tether gleaming overhead during tell/commit
    if ctx.is_tell or ctx.is_commit:
        fx_back.line(cx - 2.0, 4.0, cx - 2.0, cy - 28.0, "gold" if ctx.is_tell else "cream", protect=True)

    # Dramatic billowing silk mantle (distinctive triangular silhouette!)
    if d == "side":
        cape_pts = [
            (cx - 2.0, cy - 26.0),
            (cx - 17.0, cy - 16.0 + cape_billow * 0.5),
            (cx - 21.0, cy - 4.0 + cape_billow),
            (cx - 8.0, cy - 3.0 + cape_billow * 0.4),
            (cx + 1.0, cy - 14.0),
        ]
    else:
        cape_pts = [
            (cx - 7.0, cy - 27.0), (cx + 7.0, cy - 27.0),
            (cx + 15.0 + cape_billow * 0.4, cy - 4.0),
            (cx + cape_billow * 0.3, cy - 1.5),
            (cx - 15.0 + cape_billow * 0.4, cy - 4.0),
        ]
    body.shaded_poly(cape_pts, CAPE)
    # Silvery trim line on cape
    if d != "side":
        body.line(cx - 12.0 + cape_billow * 0.3, cy - 6.0, cx + 12.0 + cape_billow * 0.3, cy - 6.0, "ice")

    # Agile fencing boots
    st = math.sin(ph) * 2.6 if ctx.anim in ("routine", "phase2") else 0.0
    if d == "side":
        body.capsule(cx - 3.0, cy - 11.0, cx - 5.0 + st, min(ay, cy - 1.0), 2.1, 1.4, ARMOR)
        body.capsule(cx + 2.0, cy - 11.0, cx + 5.0 - st, min(ay, cy - 1.0), 2.1, 1.4, ARMOR)
    else:
        body.capsule(cx - 3.5, cy - 11.0, cx - 5.0, min(ay, cy - 1.0 + st * 0.4), 2.1, 1.4, ARMOR)
        body.capsule(cx + 3.5, cy - 11.0, cx + 5.0, min(ay, cy - 1.0 - st * 0.4), 2.1, 1.4, ARMOR)

    # Slender aristocratic cuirass + wine silk sash (hidden behind mantle on back view!)
    if d != "back":
        body.shaded_ellipse(cx, cy - 19.0, 6.0 if d != "side" else 5.2, 8.6, ARMOR)
        body.line(cx - 4.5, cy - 22.0, cx + 4.5, cy - 22.0, "gold")
        body.line(cx - 4.0, cy - 16.0, cx + 4.0, cy - 16.0, "rose")
    else:
        # Back view: full draped silk mantle with golden spindle heraldry clasp
        body.shaded_poly([
            (cx - 7.5, cy - 27.0), (cx + 7.5, cy - 27.0),
            (cx + 14.0 + cape_billow * 0.4, cy - 3.5),
            (cx + cape_billow * 0.3, cy - 1.5),
            (cx - 14.0 + cape_billow * 0.4, cy - 3.5),
        ], CAPE)
        body.line(cx, cy - 25.0, cx + cape_billow * 0.25, cy - 5.0, "gold")
        body.shaded_ellipse(cx, cy - 25.0, 4.5, 2.4, GOLD_SPOOL)

    # Tall conical spindle-spire knight helmet + flowing silver silk streamer
    hx, hy = cx + (1.5 if d == "side" else 0.0), cy - 31.0
    body.shaded_ellipse(hx, hy, 5.8, 5.8, ARMOR)
    # Tall spire finial (strictly y >= 5)
    body.shaded_poly([
        (hx - 4.8, hy - 3.0), (hx, hy - 14.0), (hx + 4.8, hy - 3.0),
    ], CAPE)
    body.circle(hx, hy - 14.0, 1.5, "gold", protect=True)
    # Silk streamer trailing from spire
    body.bezier_limb((hx, hy - 12.0), (hx - 8.0, hy - 10.0 + cape_billow * 0.5), (hx - 15.0, hy - 5.0 + cape_billow), 1.6, 0.6, ("ice", "cream"))

    if d == "front":
        body.line(hx - 3.5, hy - 0.5, hx + 3.5, hy - 0.5, "void", protect=True)
        body.set(hx - 1.8, hy - 0.5, "ice" if not p2 else "gold", protect=True)
        body.set(hx + 1.8, hy - 0.5, "ice" if not p2 else "gold", protect=True)
    elif d == "side":
        body.line(hx + 0.5, hy - 0.5, hx + 5.0, hy - 0.5, "void", protect=True)
        body.set(hx + 3.5, hy - 0.5, "ice" if not p2 else "gold", protect=True)

    # Off-hand brass silk spool buckler
    sp_x = cx - (4.0 if d == "side" else 8.0)
    sp_y = cy - 19.5 - (4.0 if ctx.is_tell else 0.0)
    body.shaded_ellipse(sp_x, sp_y, 3.6, 4.2, GOLD_SPOOL)
    body.circle(sp_x, sp_y, 1.6, "ice", protect=True)

    # Slender gilded needle-rapier
    hot = p2 or ctx.is_tell or ctx.is_commit
    if d == "side":
        _draw_needle_lance(body, cx + 4.0, cy - 19.0, lance_ang, hot)
    elif d == "front":
        _draw_needle_lance(body, cx + 7.0, cy - 19.0, -52.0 + lance_ang * 0.4, hot)
    else:
        _draw_needle_lance(body, cx + 7.0, cy - 20.0, -64.0, hot)

    if p2:
        fx_back.ring(cx, cy - 20.0, 16.0, "ice", 1.0, 0, 360, protect=True)
        for k in range(3):
            a = ph + k * 2.094
            fx_front.set(cx + math.cos(a) * 16.0, cy - 20.0 + math.sin(a) * 9.0, "gold" if k % 2 == 0 else "ice", protect=True)

    if ctx.is_tell and u > 0.35:
        fx_front.star4(hx, hy - 14.0, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 10.0, cy - 18.0, 17.0, 11.0, -65, 65, 5.2, ("ice", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 13.0, 20.0, 10.0, 12, 168, 5.0, ("ice", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 12.0, 9.0, 3.0, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="knight_spindle", name="Dame Spindle", out_dir=ART_BOSSES,
    frame=(80, 76), anchor=(40, 62),
    body_radius=9.5, hit_radius=13.5, body_centre=(40, 40),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_knight_spindle,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
