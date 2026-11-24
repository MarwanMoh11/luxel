#!/usr/bin/env python3
"""Island 7 Enemy: Moon Jelly (Translucent Lunar Bell Jellyfish with crescent core & ribbon tentacles) — 56x54, anchor [28, 45]."""
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

BELL_GLASS = ("deep", "blue", "sky", "ice")
BELL_RIM = ("blue", "sky", "ice", "cream")
TENTACLE_RAMP = ("night", "deep", "blue", "sky")


def draw_moon_jelly(ctx: FrameCtx) -> Image.Image:
    w, h = 62, 60
    ax, ay = 31.0, 49.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = math.sin(ph) * 2.5
    pulse_w = 1.0 + math.sin(ph) * 0.08
    pulse_h = 1.0 - math.sin(ph) * 0.06
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Inflates taut before static discharge!
        pulse_w = 1.0 + 0.24 * u
        pulse_h = 1.0 + 0.14 * u
        bob = -2.0 * u
        sx, sy = 1.08, 0.96
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        pulse_w = 1.25 - 0.35 * sm
        pulse_h = 0.85 + 0.25 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        pulse_w = 0.92
        pulse_h = 1.08
        bob = 2.0
    elif ctx.is_stagger:
        pulse_w = 0.86
        pulse_h = 1.12
        bob = 3.5

    cx = ax
    cy = ay - 16.0 + bob
    shadow.contact_shadow(ax, ay + 1.0, 8.5, 1.6, "night")

    # 5 trailing ribbon tentacles with lagged sinusoidal drift
    t_xs = (-9.0, -4.5, 0.0, 4.5, 9.0) if d != "side" else (-7.0, -3.5, 0.0, 3.5, 6.5)
    for ti, tx in enumerate(t_xs):
        wave1 = math.sin(lph + ti * 0.9) * 2.8
        wave2 = math.sin(lph + ti * 0.9 + 1.1) * 4.2
        length = 14.0 if (ti % 2 == 0) else 11.0
        target_buf = fx_back if ti in (1, 3) else body
        target_buf.bezier_limb(
            (cx + tx * pulse_w, cy + 2.0),
            (cx + tx * 0.95 + wave1, cy + 2.0 + length * 0.55),
            (cx + tx * 0.85 + wave2, cy + 2.0 + length),
            1.4, 0.6, TENTACLE_RAMP if ti % 2 == 1 else BELL_GLASS, tip_col="ice",
        )

    # Scalloped translucent lunar dome bell
    rx = 12.0 * pulse_w if d != "side" else 11.0 * pulse_w
    ry = 11.0 * pulse_h
    body.shaded_dome(cx, cy + 2.0, rx, ry, BELL_GLASS, bottom_cut=0.05)
    # Scalloped cream-ice frill along bell hem
    for fi_x in range(-3, 4):
        fx_p = cx + fi_x * (rx * 0.28)
        body.circle(fx_p, cy + 2.5, 2.2, "ice")
        body.set(fx_p, cy + 2.0, "cream", protect=True)

    # Glowing crescent moon nucleus inside the bell!
    mx = cx + (2.5 if d == "side" else 0.0)
    my = cy - 4.0
    body.circle(mx, my, 4.5, "cream", protect=True)
    body.circle(mx + (1.8 if d != "back" else -1.8), my - 1.0, 3.6, "blue")
    # Specular crescent highlight on upper left dome
    body.line(cx - rx * 0.55, cy - ry * 0.55, cx - rx * 0.2, cy - ry * 0.78, "cream", protect=True)

    # Subtle bioluminescent eyes on front/side
    if d == "front":
        body.eye(cx - 3.5, cy - 0.5, "ice", "cream", "deep", 2, 2)
        body.eye(cx + 1.5, cy - 0.5, "ice", "cream", "deep", 2, 2)
    elif d == "side":
        body.eye(cx + 4.0, cy - 0.5, "ice", "cream", "deep", 2, 2)

    # Static tell / commit ripple FX
    if ctx.is_tell and u > 0.30:
        fx_front.ring(cx, cy - 2.0, rx + 2.0 + (1.0 - u) * 5.0, "ice" if u > 0.65 else "sky", 1.3)
        fx_front.star4(cx, cy - ry - 2.0, 2, "cream", "ice")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.ring(cx, cy - 1.0, rx + 6.0 + ctx.fi * 2.0, "cream", 1.5)
        fx_front.ring(cx, cy - 1.0, rx + 3.0 + ctx.fi * 2.0, "sky", 1.2)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - ry - 4.0, 7.5, 2.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="moon_jelly", name="Moon Jelly", out_dir=ART_ENEMIES,
    frame=(62, 60), anchor=(31, 49),
    body_radius=6.5, hit_radius=10.0, body_centre=(31, 32),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_moon_jelly,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
