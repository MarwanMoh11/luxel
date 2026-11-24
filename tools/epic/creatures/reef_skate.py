#!/usr/bin/env python3
"""Island 2 Enemy: Reef Skate (tidal manta flanker) — 60x52, anchor [30, 41]."""
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

RAY_BODY = ("night", "deep", "blue", "sky")
RAY_WING = ("deep", "blue", "sky", "ice")
BELLY = ("blue", "sky", "ice", "cream")
TAIL_RAMP = ("void", "night", "deep", "blue")


def draw_reef_skate(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 54
    ax, ay = 32.0, 42.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = 4.0 + math.sin(ph) * 1.8
    flap = math.sin(ph) * 4.5
    tail_sway = math.sin(lph) * 4.2
    sx, sy = 1.0, 1.0
    lunge = 0.0

    if ctx.is_tell:
        hover = 5.5 + 2.5 * u
        flap = -5.5 * u
        tail_sway = -4.0 * u
        lunge = -3.5 * u
        sx, sy = 0.92, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        hover = 2.0
        flap = 5.5 * sm
        lunge = 6.5 * sm
        sx, sy = 1.14, 0.88
    elif ctx.is_recover:
        hover = 1.0
        flap = math.sin(ph * 2.0) * 1.5
        sx, sy = 1.06, 0.94
    elif ctx.is_stagger:
        hover = 0.5 + abs(math.sin(ph * 2.0)) * 2.0
        flap = math.sin(ph * 2.0) * 5.0
        sx, sy = 1.04, 0.95

    cx = ax + (lunge if d == "side" else 0.0)
    cy = ay - 9.0 - hover
    shadow.contact_shadow(ax, ay + 1.0, 12.5, 2.0, "night")

    if ctx.is_stagger:
        # Flopped belly-up vulnerable pose!
        body.shaded_poly([
            (cx - 17, cy + flap * 0.3), (cx - 7, cy - 5), (cx + 7, cy - 5),
            (cx + 17, cy - flap * 0.3), (cx + 6, cy + 7), (cx - 6, cy + 7),
        ], BELLY)
        body.line(cx - 4, cy - 1, cx - 2, cy - 1, "blue")
        body.line(cx + 2, cy - 1, cx + 4, cy - 1, "blue")
        body.line(cx - 3, cy + 2, cx + 3, cy + 2, "deep")
        body.bezier_limb((cx, cy + 6), (cx + tail_sway, cy + 12), (cx + tail_sway * 1.4, cy + 15), 2.0, 0.7, TAIL_RAMP, tip_col="ice")
    elif d == "front":
        # Barbed whip tail trailing behind
        body.bezier_limb((cx, cy - 4), (cx + tail_sway * 0.5, cy - 11), (cx + tail_sway, cy - 16), 2.0, 0.7, TAIL_RAMP, tip_col="ice")
        # Wide sweeping manta pectoral wings
        wing_pts = [
            (cx - 20, cy + 1 + flap * 0.7),
            (cx - 11, cy - 7 + flap * 0.25),
            (cx, cy - 6),
            (cx + 11, cy - 7 + flap * 0.25),
            (cx + 20, cy + 1 + flap * 0.7),
            (cx + 10, cy + 7),
            (cx, cy + 9),
            (cx - 10, cy + 7),
        ]
        body.shaded_poly(wing_pts, RAY_WING)
        # Central ridged dorsal spine
        body.shaded_ellipse(cx, cy + 1, 7.5, 6.2, RAY_BODY)
        # Iconic manta cephalic horns flanking mouth
        body.bezier_limb((cx - 5, cy + 5), (cx - 8, cy + 9), (cx - 6, cy + 12), 1.8, 0.8, RAY_WING, tip_col="ice")
        body.bezier_limb((cx + 5, cy + 5), (cx + 8, cy + 9), (cx + 6, cy + 12), 1.8, 0.8, RAY_WING, tip_col="ice")
        # Pale coastal spots along wings
        for sx_o in (-12, -8, 8, 12):
            body.set(cx + sx_o, cy - 1 + flap * 0.3, "ice", protect=True)
        # Bright gold eyes on wide brow
        body.eye(cx - 5.5, cy + 1.5, "gold", "cream", "void", 2, 2)
        body.eye(cx + 3.5, cy + 1.5, "gold", "cream", "void", 2, 2)
    elif d == "back":
        wing_pts = [
            (cx - 20, cy + 1 + flap * 0.7),
            (cx - 11, cy - 6 + flap * 0.25),
            (cx, cy - 8),
            (cx + 11, cy - 6 + flap * 0.25),
            (cx + 20, cy + 1 + flap * 0.7),
            (cx + 10, cy + 6),
            (cx, cy + 7),
            (cx - 10, cy + 6),
        ]
        body.shaded_poly(wing_pts, RAY_WING)
        body.shaded_ellipse(cx, cy, 7.2, 5.8, RAY_BODY)
        for ry in (-3, 0, 3):
            body.rect(cx - 1, cy + ry, 2, 2, "ice")
        for sx_o in (-12, -8, 8, 12):
            body.set(cx + sx_o, cy - 1 + flap * 0.3, "ice", protect=True)
        # Long trailing whip tail in foreground
        body.bezier_limb((cx, cy + 5), (cx + tail_sway * 0.6, cy + 12), (cx + tail_sway, cy + 17), 2.4, 0.7, TAIL_RAMP, tip_col="gold")
    else:
        # Side view (faces right): sleek hydrofoil silhouette + whipping tail left
        body.bezier_limb((cx - 8, cy + 1), (cx - 16, cy + 2 + tail_sway * 0.5), (cx - 22, cy - 1 + tail_sway * 0.8), 2.4, 0.7, TAIL_RAMP, tip_col="gold")
        # Far wing rising behind
        fx_back.shaded_poly([
            (cx - 6, cy - 2), (cx + 1, cy - 11 - flap * 0.7), (cx + 8, cy - 6 - flap * 0.4), (cx + 6, cy - 1),
        ], ("night", "deep", "blue"))
        # Streamlined diamond body
        body.shaded_poly([
            (cx - 11, cy + 1), (cx - 2, cy - 6), (cx + 11, cy - 3),
            (cx + 16, cy + 2), (cx + 8, cy + 6), (cx - 6, cy + 5),
        ], RAY_BODY)
        # Near sweeping wing
        body.shaded_poly([
            (cx - 6, cy + 1), (cx + 2, cy + 2), (cx + 7, cy + 8 + flap * 0.7), (cx - 5, cy + 9 + flap * 0.6),
        ], RAY_WING)
        # Forward cephalic horn
        body.bezier_limb((cx + 12, cy + 2), (cx + 16, cy + 3), (cx + 18, cy + 1), 1.6, 0.7, RAY_WING, tip_col="ice")
        # Pale belly strip + gill notches
        body.line(cx - 3, cy + 5, cx + 10, cy + 4, "ice")
        body.set(cx + 1, cy + 3, "night")
        body.set(cx + 4, cy + 3, "night")
        body.eye(cx + 8.0, cy - 1.5, "gold", "cream", "void", 2, 2)

    # FX layers
    if ctx.is_tell and u > 0.3:
        gx = cx + (15 if d == "side" else 0)
        gy = cy + (-2 if d == "side" else 5)
        fx_front.star4(gx, gy, 3 if u > 0.7 else 2, "cream", "gold")
        fx_back.ring(cx, cy + 4, 10.0 + u * 5.0, "ice", 1.0, 0, 360, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 6, cy + 1, 17, 9, -55, 55, 4.8, ("blue", "sky", "cream"))
            fx_back.line(cx - 14, cy + 4, cx - 24, cy + 4, "ice", protect=True)
            fx_back.line(cx - 12, cy - 2, cx - 22, cy - 2, "sky", protect=True)
        else:
            fx_front.slash_arc(cx, cy + 5, 19, 8, 15, 165, 4.8, ("blue", "sky", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 10, 9.0, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="reef_skate", name="Reef Skate", out_dir=ART_ENEMIES,
    frame=(64, 54), anchor=(32, 42),
    body_radius=5.5, hit_radius=10.0, body_centre=(32, 30),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_reef_skate,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
