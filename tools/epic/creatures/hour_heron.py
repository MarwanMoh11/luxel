#!/usr/bin/env python3
"""Island 4 Enemy: Hour Heron (marble metronome lancer with gold pendulum collar) — 62x64, anchor [31, 54]."""
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

MARBLE = ("dusk", "mauve", "stone", "ice")
MARBLE_DARK = ("night", "dusk", "mauve", "stone")
GOLD = ("wine", "apricot", "gold", "cream")
PLUME = ("deep", "blue", "sky", "ice")


def _draw_beak(buf: PixelBuf, bx: float, by: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ramp = GOLD if hot else ("dusk", "mauve", "gold", "cream")
    # Clock-hand lance beak with ornamental counter-ring
    tmp.ring(bx - 2.0, by, 2.0, "gold", 1.0, protect=True)
    pts = [(bx, by - 2.0), (bx + 12.5, by - 0.5), (bx + 14.5, by), (bx + 12.5, by + 0.8), (bx, by + 1.8)]
    tmp.shaded_poly(pts, ramp)
    tmp.line(bx + 2.0, by, bx + 12.5, by, "cream", protect=True)
    buf.composite(rotate_buf(tmp, bx, by, ang_deg))


def draw_hour_heron(ctx: FrameCtx) -> Image.Image:
    w, h = 62, 64
    ax, ay = 31.0, 56.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    # Metronome crisp step bob (snappy mechanical cadence)
    step = math.sin(ph) * 2.5 if ctx.anim == "routine" else 0.0
    bob = abs(math.sin(ph)) * 1.4 if ctx.anim == "routine" else 0.0
    pend_sway = math.sin(lph) * 4.5
    lean = 0.0
    beak_ang = 4.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -3.8 * u
        beak_ang = -16.0 * u
        pend_sway = -5.5 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lean = 4.5 * sm
        beak_ang = 4.0 * sm
        pend_sway = 5.0 * sm
        sx, sy = 1.09, 0.92
    elif ctx.is_recover:
        lean = 3.5
        beak_ang = 26.0
        pend_sway = math.sin(ph) * 2.0
    elif ctx.is_stagger:
        lean = -2.5 + math.sin(ph * 2.0) * 1.8
        beak_ang = -32.0
        pend_sway = math.sin(ph * 2.5) * 6.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob
    shadow.contact_shadow(ax, ay + 1.5, 9.5, 1.8, "night")

    # Tall carved marble heron legs with brass ankle bands
    if d == "side":
        l_foot_x = cx - 3.5 + step
        r_foot_x = cx + 3.5 - step
        body.capsule(cx - 1.5, cy - 15, l_foot_x, ay - 1, 1.6, 1.1, MARBLE_DARK)
        body.capsule(cx + 1.5, cy - 15, r_foot_x, ay - 1, 1.6, 1.1, MARBLE)
        body.rect(l_foot_x - 2, ay - 2, 5, 2, "gold")
        body.rect(r_foot_x - 2, ay - 2, 5, 2, "gold")
    else:
        body.capsule(cx - 4.0, cy - 15, cx - 4.5, ay - 1 + step * 0.4, 1.6, 1.1, MARBLE)
        body.capsule(cx + 4.0, cy - 15, cx + 4.5, ay - 1 - step * 0.4, 1.6, 1.1, MARBLE)
        body.rect(cx - 6.5, ay - 2 + step * 0.4, 4, 2, "gold")
        body.rect(cx + 2.5, ay - 2 - step * 0.4, 4, 2, "gold")

    # Sculpted marble torso (tall tapered urn-chest with wing folds)
    if d == "side":
        body.shaded_ellipse(cx - 1.0, cy - 22.0, 8.5, 10.2, MARBLE, spec_col="cream")
        # Folded slate-ice wing blade sweeping back
        body.shaded_poly([
            (cx - 2, cy - 29), (cx - 12 - pend_sway * 0.25, cy - 19),
            (cx - 10, cy - 14), (cx + 1, cy - 16),
        ], PLUME)
        body.line(cx - 4, cy - 26, cx - 10, cy - 18, "ice")
    else:
        body.shaded_ellipse(cx, cy - 22.0, 9.2, 10.2, MARBLE, spec_col="cream")
        # Symmetrical marble wing mantles on flanks
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (cx + sgn * 5, cy - 30), (cx + sgn * 11, cy - 21),
                (cx + sgn * 9, cy - 14), (cx + sgn * 5, cy - 16),
            ], PLUME)
            body.line(cx + sgn * 7, cy - 27, cx + sgn * 9, cy - 17, "ice")

    # Carved Roman sundial chest emblem & swinging gold pendulum collar
    if d == "front":
        body.shaded_ellipse(cx, cy - 23.0, 4.8, 4.8, GOLD, spec_col="cream")
        body.circle(cx, cy - 23.0, 3.0, "night")
        body.line(cx, cy - 23.0, cx, cy - 25.5, "cream", protect=True)
        body.line(cx, cy - 23.0, cx + 2.0, cy - 22.0, "gold", protect=True)
    elif d == "back":
        body.shaded_ellipse(cx, cy - 22.0, 4.5, 6.0, MARBLE_DARK)
        body.line(cx, cy - 28, cx, cy - 16, "gold")
    # Brass collar ring + hanging pendulum bob (sways with lag_phase!)
    collar_y = cy - 31.5
    body.shaded_ellipse(cx + (1.0 if d == "side" else 0.0), collar_y, 6.2, 2.2, GOLD)
    if d != "back":
        px0 = cx + (4.5 if d == "side" else 0.0)
        px1 = px0 + pend_sway * (0.45 if d == "side" else 0.75)
        py1 = collar_y + 9.5
        body.line(px0, collar_y + 1.0, px1, py1, "gold", protect=True)
        body.circle(px1, py1, 2.2, "apricot")
        body.circle(px1, py1, 1.3, "cream", protect=True)

    # Slender curving marble heron neck & crested head
    hx = cx + (3.5 if d == "side" else 0.0)
    hy = cy - 41.0 + (2.5 if ctx.is_recover else 0.0)
    body.bezier_limb(
        (cx, cy - 31.0),
        (cx - (1.5 if d == "side" else 0.0), cy - 36.5),
        (hx, hy + 2.0),
        2.8, 2.2, MARBLE,
    )
    body.shaded_ellipse(hx, hy, 5.2 if d != "side" else 5.8, 4.4, MARBLE, spec_col="cream")
    # Swept ice-feather crest plume (secondary motion lag)
    crest_dx = (-7.5 - pend_sway * 0.35) if d == "side" else (pend_sway * 0.35)
    body.bezier_limb((hx, hy - 3.5), (hx + crest_dx * 0.5, hy - 8.0), (hx + crest_dx, hy - 6.5), 2.0, 0.7, PLUME, tip_col="ice")

    if d == "front":
        body.eye(hx - 2.8, hy - 0.5, "gold", "cream", "night", 2, 2)
        body.eye(hx + 1.2, hy - 0.5, "gold", "cream", "night", 2, 2)
        # Pointed downward lance beak (foreshortened)
        body.shaded_poly([(hx - 2.0, hy + 1.5), (hx + 2.0, hy + 1.5), (hx, hy + 10.5)], GOLD)
        body.line(hx, hy + 2.0, hx, hy + 9.5, "cream", protect=True)
    elif d == "side":
        body.eye(hx + 1.8, hy - 0.8, "gold", "cream", "night", 2, 2)
        _draw_beak(body, hx + 4.0, hy + 0.5, beak_ang, ctx.is_tell or ctx.is_commit)
    else:
        body.line(hx, hy - 3.0, hx, hy + 3.0, "gold")

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.30:
        gx = hx + (14 if d == "side" else 0)
        gy = hy + (0 if d == "side" else 9)
        fx_front.star4(gx, gy, 3 if u > 0.70 else 2, "cream", "gold")
        if u > 0.55:
            fx_back.ring(cx, cy - 23.0, 11.0 + u * 4.0, "gold", 1.0, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.line(hx + 3, hy, hx + 16, hy + 1, "gold", protect=True)
            fx_front.line(hx + 5, hy - 1, hx + 17, hy, "cream", protect=True)
            fx_front.slash_arc(hx + 6, hy, 11, 7, -38, 38, 3.8, ("sky", "ice", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 22, 16, 11, 20, 160, 4.2, ("gold", "ice", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 9.0, 7.5, 2.5, ph)
        body.crack(cx - 3, cy - 26, cx + 3, cy - 18, "night", "gold", seed=4)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="hour_heron", name="Hour Heron", out_dir=ART_ENEMIES,
    frame=(62, 64), anchor=(31, 56),
    body_radius=6.0, hit_radius=10.5, body_centre=(31, 36),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="pine",
    draw_frame=draw_hour_heron,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
