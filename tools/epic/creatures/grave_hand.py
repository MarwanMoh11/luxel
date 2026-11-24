#!/usr/bin/env python3
"""Island 1 Enemy: Grave Hand (brass-cuffed skeletal hand erupting from crypt soil) — 56x54, anchor [28, 44]."""
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

SOIL = ("void", "night", "dusk", "pine")
BONE = ("dusk", "mauve", "stone", "cream")
CUFF = ("plum", "coral", "apricot", "gold")


def draw_grave_hand(ctx: FrameCtx) -> Image.Image:
    w, h = 56, 54
    ax, ay = 28.0, 44.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    rise = 0.0
    spread = 0.0
    lean = 0.0
    curl = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        rise = 4.5 * u
        spread = 4.2 * u
        sx, sy = 1.06, 0.94
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        rise = 6.0 * sm
        lean = 6.5 * sm
        curl = 7.5 * sm
        sx, sy = 1.10, 0.91
    elif ctx.is_recover:
        rise = -3.0
        curl = -3.0
        spread = 2.0
    elif ctx.is_stagger:
        rise = -2.0
        lean = math.sin(ph * 2.5) * 2.5
        curl = 4.0

    cx = ax + (lean * 0.45 if d == "side" else 0.0)
    cy = ay - 4.0
    shadow.contact_shadow(ax, ay + 1.5, 12.5, 2.2, "night")

    # Heaped crypt soil mound + scattered dirt pebbles
    mound_sw = 1.4 if ctx.is_tell else 0.0
    body.shaded_dome(ax, ay + 0.5, 12.5 + mound_sw, 6.2 + mound_sw * 0.5, SOIL, bottom_cut=0.15)
    for px_d, py_d in [(-10, -1), (-5, -3), (4, -3), (10, -1), (0, -2)]:
        body.rect(ax + px_d, ay + py_d, 2, 2, "mauve" if px_d % 2 == 0 else "dusk")

    # Tarnished brass gauntlet wrist cuff bursting from mound
    wx, wy = cx, cy - 3.0 - rise * 0.25
    # Skeletal forearm bones connecting cuff cleanly into palm (no gap on rise!)
    px_c = wx + (lean * 0.35 if d == "side" else 0.0)
    py_c = wy - 7.0 - rise * 0.40
    body.capsule(wx - 2.0, wy - 2.0, px_c - 1.5, py_c + 2.5, 1.8, 1.6, BONE)
    body.capsule(wx + 2.0, wy - 2.0, px_c + 1.5, py_c + 2.5, 1.8, 1.6, BONE)
    body.shaded_rect(wx - 6.0, wy - 3.5, 12.0, 6.5, CUFF)
    body.line(wx - 5.5, wy - 2.5, wx + 5.5, wy - 2.5, "gold", protect=True)
    body.set(wx, wy, "cream", protect=True)
    if ctx.is_stagger:
        body.crack(wx - 4, wy - 3, wx + 4, wy + 2, "void", "coral", seed=7)

    # Skeletal palm
    palm_rx = 6.8 if d != "side" else 5.2
    body.shaded_ellipse(px_c, py_c, palm_rx, 5.5, BONE)
    if d == "back":
        # Prominent bony metacarpal knuckle ridges
        for kx in (-4, -1, 2, 5):
            body.line(px_c + kx, py_c - 3, px_c + kx * 0.7, py_c + 3, "mauve")
            body.set(px_c + kx, py_c - 4, "cream", protect=True)
    elif d == "front":
        # Hollow palm shadow & brass-rivet center sigil
        body.ellipse(px_c, py_c + 0.5, 3.6, 2.8, "dusk")
        body.set(px_c, py_c, "apricot" if not ctx.is_tell else "coral", protect=True)

    # Five articulated skeletal fingers (tapping wave in routine, splaying in tell, clutching in commit!)
    if d != "side":
        fingers = [
            (-7.0, -2.0, -10.5 - spread, -9.5),
            (-4.2, -4.5, -6.2 - spread * 0.7, -14.5),
            (0.0, -5.2, 0.0, -16.5),
            (4.2, -4.5, 6.2 + spread * 0.7, -14.5),
            (7.0, -2.0, 10.2 + spread, -9.5),
        ]
        for idx, (bx, by, tx, ty) in enumerate(fingers):
            tap = math.sin(ph + idx * 1.1) * 2.4 if ctx.anim == "routine" else 0.0
            p0 = (px_c + bx, py_c + by)
            p1 = (px_c + (bx + tx) * 0.5, py_c + (by + ty) * 0.5 - 2.0 + tap * 0.5)
            p2 = (px_c + tx, py_c + ty + curl + tap)
            body.bezier_limb(p0, p1, p2, 1.8, 0.9, BONE, tip_col="coral" if ctx.is_commit else "cream")
    else:
        # Side clawing profile: arched fingers reaching right + opposable thumb below
        for idx, (dy, reach_x, lift_y) in enumerate([(-4.5, 11.5, -9.0), (-2.0, 13.0, -6.5), (0.5, 11.0, -3.5)]):
            tap = math.sin(ph + idx * 1.3) * 2.2 if ctx.anim == "routine" else 0.0
            p0 = (px_c + 2.5, py_c + dy)
            p1 = (px_c + reach_x * 0.55, py_c + lift_y - spread * 0.5 + tap * 0.5)
            p2 = (px_c + reach_x + lean * 0.35, py_c + lift_y + 4.5 + curl * 0.7 + tap)
            body.bezier_limb(p0, p1, p2, 1.8, 0.9, BONE, tip_col="coral" if ctx.is_commit else "cream")
        # Thumb
        body.bezier_limb(
            (px_c + 2.0, py_c + 2.0), (px_c + 7.0, py_c + 3.0), (px_c + 9.5, py_c + 0.5 - spread * 0.3),
            1.7, 0.9, BONE, tip_col="cream",
        )

    # Telegraph / commit / stagger FX
    if ctx.is_tell and u > 0.30:
        # Flat soil ripple arcs strictly inside frame
        fx_back.line(ax - 13 - u * 3, ay + 2, ax - 7, ay + 4, "coral" if u > 0.65 else "apricot", protect=True)
        fx_back.line(ax + 7, ay + 4, ax + 13 + u * 3, ay + 2, "coral" if u > 0.65 else "apricot", protect=True)
        fx_back.line(ax - 8, ay + 5, ax + 8, ay + 5, "gold", protect=True)
        if u > 0.65:
            fx_front.star4(px_c + (6 if d == "side" else 0), py_c - 12, 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(px_c + 5, py_c - 2, 13, 11, -65, 65, 4.4, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(px_c, py_c - 5, 14, 9, -155, -25, 4.4, ("coral", "apricot", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(px_c, py_c - 14, 7.5, 2.4, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="grave_hand", name="Grave Hand", out_dir=ART_ENEMIES,
    frame=(56, 54), anchor=(28, 44),
    body_radius=5.5, hit_radius=9.5, body_centre=(28, 28),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_grave_hand,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
