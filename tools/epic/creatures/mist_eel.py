#!/usr/bin/env python3
"""Island 4 Enemy: Mist Eel (serpentine ribbon eel with luminous ice dorsal fin) — 66x50, anchor [33, 40]."""
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

EEL = ("night", "deep", "teal", "sky")
FIN = ("blue", "sky", "ice", "cream")
BELLY = ("pine", "teal", "jade", "ice")


def draw_mist_eel(ctx: FrameCtx) -> Image.Image:
    w, h = 66, 50
    ax, ay = 33.0, 40.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    wave = math.sin(ph)
    wave2 = math.sin(lph + 0.9)
    lift = 0.0
    arch = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Coils tight & raises head over water splash rings
        lift = 2.0 * u
        arch = -5.0 * u
        sx, sy = 0.92, 1.09
    elif ctx.is_commit:
        # High leaping water-ribbon arc
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        lift = 10.5 * sm
        arch = 6.0 * sm
        sx, sy = 1.14, 0.89
    elif ctx.is_recover:
        lift = 0.0
        arch = 2.0
    elif ctx.is_stagger:
        # Flopping helplessly on dry ground (SUN stranded!)
        lift = abs(math.sin(ph * 2.0)) * 3.5
        sx, sy = 1.06, 0.92

    cx = ax
    cy = ay - lift
    shadow.contact_shadow(ax, ay + 1.5, 13.0 if d == "side" else 10.0, 2.2, "night")

    # Flat perspective water-ripple arcs beneath eel during swim/tell
    if not ctx.is_commit and not ctx.is_stagger:
        rw1 = 12.0 + wave * 1.5
        rw2 = 16.0 - wave * 1.5
        for ang_deg in range(0, 360, 12):
            a = math.radians(ang_deg)
            if 15 <= ang_deg <= 165 or 200 <= ang_deg <= 340:
                fx_back.set(ax + math.cos(a) * rw1, ay + 0.5 + math.sin(a) * 3.2, "sky", protect=True)
            if 25 <= ang_deg <= 155:
                fx_back.set(ax + math.cos(a) * rw2, ay + 1.5 + math.sin(a) * 4.2, "blue", protect=True)

    if d == "side":
        # Full serpentine ribbon body sweeping from tail (left) to head (right)
        p_tail = (cx - 19.0, cy - 5.0 + wave2 * 4.5)
        p_mid1 = (cx - 9.0, cy - 11.0 - wave * 3.5 - arch * 0.4)
        p_mid2 = (cx + 2.0, cy - 5.0 + wave * 3.5)
        p_head = (cx + 12.0 + arch * 0.4, cy - 11.5 - arch * 0.4 + wave * 2.0)

        # Translucent ice dorsal fin ribbon along back
        body.bezier_limb(
            (p_tail[0] + 2, p_tail[1] - 3),
            (p_mid1[0], p_mid1[1] - 6.5),
            (p_head[0] - 3, p_head[1] - 5.0),
            1.4, 2.2, FIN, tip_col="cream",
        )
        # Main ribbon body in two bezier arcs
        body.bezier_limb(p_tail, p_mid1, p_mid2, 1.5, 4.2, EEL)
        body.bezier_limb(p_mid2, (cx + 7.0, cy - 4.0), p_head, 4.2, 4.6, EEL)
        # Pale belly sheen + gills
        body.line(p_mid1[0], p_mid1[1] + 2, p_mid2[0], p_mid2[1] + 2, "ice")
        body.set(p_head[0] - 5, p_head[1] + 1, "ice", protect=True)
        body.set(p_head[0] - 3, p_head[1] + 2, "sky", protect=True)
        # Sleek eel head & luminous golden eye + whisker barbels
        body.shaded_ellipse(p_head[0] + 2.0, p_head[1], 5.6, 3.8, EEL, spec_col="ice")
        body.eye(p_head[0] + 3.0, p_head[1] - 1.2, "gold", "cream", "void", 2, 2)
        body.line(p_head[0] + 4.0, p_head[1] + 1.5, p_head[0] + 7.5, p_head[1] + 1.5, "void", protect=True)
        body.line(p_head[0] + 5.0, p_head[1] + 2.0, p_head[0] + 9.0, p_head[1] + 4.5 + wave2, "ice")
    elif d == "front":
        # Coiled upright S-loop facing player with flared ice fins!
        body.bezier_limb((cx - 10, cy - 3), (cx - 12, cy - 11 + wave * 2), (cx - 2, cy - 10), 2.4, 4.2, EEL)
        body.bezier_limb((cx + 10, cy - 3), (cx + 12, cy - 11 - wave * 2), (cx + 2, cy - 10), 2.4, 4.2, EEL)
        # Flared ice cheek-fins
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (cx + sgn * 4, cy - 18), (cx + sgn * 12, cy - 22 + wave2 * 2),
                (cx + sgn * 10, cy - 14), (cx + sgn * 4, cy - 13),
            ], FIN)
        body.shaded_ellipse(cx, cy - 14.5, 5.6, 5.8, EEL, spec_col="ice")
        body.shaded_ellipse(cx, cy - 11.5, 3.4, 2.8, BELLY)
        body.eye(cx - 3.0, cy - 16.0, "gold", "cream", "void", 2, 2)
        body.eye(cx + 1.4, cy - 16.0, "gold", "cream", "void", 2, 2)
        body.line(cx - 2.0, cy - 12.5, cx + 2.0, cy - 12.5, "void", protect=True)
        # High ice dorsal crest
        body.shaded_poly([(cx - 1.5, cy - 19), (cx + wave2 * 2, cy - 27), (cx + 2.0, cy - 19)], FIN)
    else:
        # Back view: rising luminous dorsal fin ridge + coiled tail
        body.bezier_limb((cx - 9, cy - 4), (cx - 11, cy - 12), (cx, cy - 10), 2.2, 4.2, EEL)
        body.bezier_limb((cx + 9, cy - 4), (cx + 11, cy - 12), (cx, cy - 10), 2.2, 4.2, EEL)
        body.shaded_ellipse(cx, cy - 15.0, 5.4, 5.6, EEL)
        body.shaded_poly([(cx - 2.0, cy - 11), (cx + wave2 * 2.5, cy - 27), (cx + 2.0, cy - 11)], FIN)
        body.line(cx, cy - 12, cx + wave2 * 1.5, cy - 24, "cream", protect=True)

    # FX
    if ctx.is_tell and u > 0.25:
        rw = 10.0 + u * 8.0
        for ang_deg in range(0, 360, 10):
            a = math.radians(ang_deg)
            fx_front.set(ax + math.cos(a) * rw, ay + 0.5 + math.sin(a) * 3.4, "ice", protect=True)
        fx_front.star4(cx + (13 if d == "side" else 0), cy - 16, 2, "cream", "sky")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (4 if d == "side" else 0), cy - 10, 18, 11, -155, -25, 4.8, ("blue", "sky", "cream"))
        for k in range(4):
            fx_front.rect(cx - 12 + k * 8, cy - 2 - (k % 2) * 4, 2, 2, "ice" if k % 2 == 0 else "sky", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 22.0, 8.5, 2.6, ph)
        fx_front.rect(cx - 9, cy - 5, 2, 2, "sky", protect=True)
        fx_front.rect(cx + 8, cy - 6, 2, 2, "ice", protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="mist_eel", name="Mist Eel", out_dir=ART_ENEMIES,
    frame=(66, 50), anchor=(33, 40),
    body_radius=6.0, hit_radius=10.5, body_centre=(33, 28),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_mist_eel,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
