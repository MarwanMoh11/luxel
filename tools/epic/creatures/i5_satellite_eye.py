#!/usr/bin/env python3
"""Island 5 Enemy: Satellite Eye (floating brass astrolabe turret with sky front eye & coral rear gem) — 56x50, anchor [28, 40]."""
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

BRASS = ("plum", "coral", "apricot", "gold")
BRASS_DK = ("night", "plum", "coral", "apricot")
ASTRAL = ("night", "deep", "blue", "sky")
GEM = ("wine", "coral", "apricot", "cream")


def draw_satellite_eye(ctx: FrameCtx) -> Image.Image:
    w, h = 60, 50
    ax, ay = 30.0, 40.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = math.sin(ph) * 2.2 if ctx.anim == "routine" else 0.0
    recoil = 0.0
    tilt = math.sin(lph) * 2.5
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = -1.5 * u
        recoil = -2.8 * u
        sx, sy = 0.94, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        recoil = 4.0 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        hover = 2.8 * (1.0 - u) + 1.5
        recoil = -1.5 * (1.0 - u)
    elif ctx.is_stagger:
        hover = 3.5 + math.sin(ph * 2.0) * 1.4
        recoil = math.sin(ph * 2.0) * 2.2

    cx = ax + (recoil if d == "side" else 0.0)
    cy = ay - 16.0 - hover
    shadow.contact_shadow(ax, ay + 1.0, 9.5, 1.8, "night")

    # Orbiting mini brass gimbal ring behind body
    orb_a = ph if not ctx.is_stagger else ph * 1.8
    for k in range(2):
        a = orb_a + k * math.pi
        ox = cx + math.cos(a) * 12.5
        oy = cy + math.sin(a) * 4.5
        if math.sin(a) < 0.0:
            fx_back.circle(ox, oy, 1.8, "gold" if k == 0 else "sky", protect=True)
            fx_back.set(ox, oy, "cream", protect=True)

    # Outer brass astrolabe halo ring with cardinal notches
    body.ring(cx, cy, 11.2, "apricot", 2.0)
    body.ring(cx, cy, 9.8, "gold", 1.0)
    for k in range(4):
        na = k * math.pi * 0.5 + (0.25 if ctx.is_tell else 0.0)
        nx = cx + math.cos(na) * 12.6
        ny = cy + math.sin(na) * 12.6
        body.rect(nx - 1, ny - 1, 2, 2, "gold")

    # Small hanging stabilizer fin / antenna below ring
    body.bezier_limb(
        (cx, cy + 10.5), (cx + tilt * 0.4, cy + 14.5), (cx + tilt * 0.8, cy + 17.5),
        1.8, 0.8, BRASS, tip_col="ice" if not ctx.is_recover else "coral",
    )

    if d == "front":
        # Armored brass front hemisphere + glowing sky/ice aperture eye
        body.shaded_ellipse(cx, cy, 8.2, 8.2, BRASS, spec_col="cream")
        body.shaded_ellipse(cx, cy, 6.2, 6.2, ASTRAL)
        # Mechanical brass iris blades closing slightly on tell
        gap = 1.6 if ctx.is_tell else (2.8 if ctx.is_commit else 2.2)
        body.shaded_ellipse(cx, cy, 4.6, 4.6, ("deep", "blue", "sky", "ice"), spec_col="cream")
        body.eye(cx, cy, "cream" if (ctx.is_tell or ctx.is_commit) else "ice", "cream", "deep", 3, 3)
        body.line(cx - 5.5, cy - gap - 2.0, cx + 5.5, cy - gap - 2.0, "gold")
        body.line(cx - 5.5, cy + gap + 2.0, cx + 5.5, cy + gap + 2.0, "plum")
    elif d == "side":
        # Right side = heavy curved brass shield & sky lens; Left side = EXPOSED glowing coral rear crystal gem!
        # Exposed rear gem (bright coral/cream weakspot with wine bezel!)
        body.shaded_ellipse(cx - 5.6, cy, 4.8, 5.8, ("night", "wine", "coral", "apricot"))
        body.shaded_ellipse(cx - 6.2, cy, 3.6, 4.4, GEM, spec_col="cream")
        body.circle(cx - 7.0, cy - 0.5, 1.8, "cream", protect=True)
        body.set(cx - 5.5, cy + 1.5, "gold", protect=True)
        # Main astrolabe chassis
        body.shaded_ellipse(cx + 0.5, cy, 6.5, 7.8, BRASS, spec_col="gold")
        # Front armored shield cowl facing right
        body.shaded_poly([
            (cx + 2, cy - 8.5), (cx + 8.5, cy - 5.5), (cx + 9.5, cy),
            (cx + 8.5, cy + 5.5), (cx + 2, cy + 8.5), (cx + 4.5, cy),
        ], BRASS)
        # Front protruding sky/ice focus eye
        body.shaded_ellipse(cx + 7.2, cy, 3.0, 4.2, ("deep", "blue", "sky", "ice"))
        body.eye(cx + 8.0, cy - 0.5, "cream" if ctx.is_commit else "ice", "cream", "deep", 2, 2)
    else:
        # Back view: wide exposed glowing coral/cream rear crystal lens cradled by brass clamps!
        body.shaded_ellipse(cx, cy, 8.2, 8.2, BRASS_DK)
        body.shaded_ellipse(cx, cy, 6.4, 6.4, GEM, spec_col="cream")
        body.circle(cx, cy, 3.6, "coral", protect=True)
        body.circle(cx - 0.8, cy - 0.8, 2.0, "gold", protect=True)
        body.set(cx - 1.0, cy - 1.0, "cream", protect=True)
        # Brass clamp teeth framing the vulnerable gem
        for sx_c in (-1.0, 1.0):
            body.rect(cx + sx_c * 6.5 - 1.5, cy - 3, 3, 6, "apricot")

    # Orbiting front gimbal pip
    for k in range(2):
        a = orb_a + k * math.pi
        ox = cx + math.cos(a) * 12.5
        oy = cy + math.sin(a) * 4.5
        if math.sin(a) >= 0.0:
            fx_front.circle(ox, oy, 1.8, "gold" if k == 0 else "sky", protect=True)
            fx_front.set(ox, oy, "cream", protect=True)

    # Tell / Commit / Recover / Stagger FX
    if ctx.is_tell and u > 0.30:
        fx_x = cx + (10.5 if d == "side" else 0.0)
        fx_front.star4(fx_x, cy, 3 if u > 0.70 else 2, "cream", "sky")
        if d == "side":
            fx_front.line(fx_x + 2, cy, fx_x + 11, cy, "ice", protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.line(cx + 9, cy, cx + 19, cy, "sky", protect=True)
            fx_front.line(cx + 9, cy - 1, cx + 18, cy - 1, "ice", protect=True)
            fx_front.line(cx + 9, cy + 1, cx + 18, cy + 1, "cream", protect=True)
            fx_front.star4(cx + 10, cy, 4, "cream", "sky")
        else:
            fx_front.star4(cx, cy, 5, "cream", "sky")
            fx_front.ring(cx, cy, 10.5, "ice", 1.2)
    elif ctx.is_recover:
        # Cooling vent pips rising
        vy = cy - 10.0 - u * 6.0
        fx_front.set(cx - 4, vy, "gold", protect=True)
        fx_front.set(cx + 4, vy + 2, "apricot", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 14.0, 8.5, 2.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="satellite_eye", name="Satellite Eye", out_dir=ART_ENEMIES,
    frame=(60, 50), anchor=(30, 40),
    body_radius=6.0, hit_radius=9.5, body_centre=(30, 24),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_satellite_eye,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
