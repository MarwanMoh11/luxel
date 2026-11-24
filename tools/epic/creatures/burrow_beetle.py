#!/usr/bin/env python3
"""Island 3 Enemy: Burrow Beetle (armored living-mirror rhinoceros beetle) — 58x48, anchor [29, 38]."""
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

SHELL = ("night", "pine", "teal", "jade")
MIRROR = ("blue", "sky", "ice", "cream")
HORN = ("night", "plum", "wine", "apricot")
LEG = ("void", "night", "dusk", "mauve")
BELLY = ("coral", "apricot", "gold", "cream")


def draw_burrow_beetle(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 52
    ax, ay = 32.0, 42.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = abs(math.sin(ph)) * 1.4 if ctx.anim == "routine" else 0.0
    stride = math.sin(ph) * 2.8 if ctx.anim == "routine" else 0.0
    lunge = 0.0
    crouch = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 2.6 * u
        lunge = -3.8 * u
        sx, sy = 1.08, 0.91
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lunge = 6.0 * sm
        crouch = 1.2 * sm
        sx, sy = 1.13, 0.89
    elif ctx.is_recover:
        lunge = 2.0 * (1.0 - u)
        crouch = 2.4
    elif ctx.is_stagger:
        lunge = math.sin(ph * 2.0) * 1.6
        crouch = 1.2

    cx = ax + (lunge if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 1.0, 13.5 if d == "side" else 11.5, 2.0, "night")

    if ctx.is_stagger:
        # Tipped up slightly exposing glowing gold belly & pedaling legs
        body.shaded_ellipse(cx, cy - 8.5, 11.5, 7.5, SHELL)
        body.shaded_ellipse(cx, cy - 11.0, 9.5, 5.2, BELLY)
        for sgn in (-1.0, 1.0):
            for k in range(3):
                lx = cx + sgn * (4.0 + k * 2.8)
                ly = cy - 13.0 + math.sin(ph * 2.2 + k * 1.4) * 2.5
                body.capsule(cx + sgn * 3.0, cy - 10.0, lx, ly - 4.0, 1.4, 0.9, LEG)
        fx_front.dizzy_stars(cx, cy - 22.0, 8.5, 2.8, ph)
        return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))

    if d == "side":
        # Far legs
        for k, ox in enumerate((-7.5, -1.0, 5.5)):
            st = stride * (1.0 if k % 2 == 0 else -1.0)
            body.capsule(cx + ox, cy - 5, cx + ox + st * 0.7, cy, 1.5, 1.0, ("void", "night", "dusk"))
        # Low armored thorax & heavy domed mirror-back carapace
        body.shaded_dome(cx - 2.0, cy - 6.5, 12.5, 10.8, SHELL, bottom_cut=0.14)
        # Gleaming mirrored Prism panel along upper carapace dome
        body.shaded_ellipse(cx - 2.5, cy - 12.8, 8.2, 4.0, MIRROR, spec_col="cream")
        body.line(cx - 8, cy - 12, cx + 3, cy - 14, "cream", protect=True)
        body.line(cx - 9, cy - 7, cx + 8, cy - 7, "pine")
        # Head plate & prominent curved rhinoceros horn
        hx, hy = cx + 9.5, cy - 7.5
        body.shaded_ellipse(hx, hy, 5.2, 4.6, SHELL)
        horn_lift = -3.0 * u if ctx.is_tell else (2.0 if ctx.is_commit else 0.0)
        body.bezier_limb(
            (hx + 3.0, hy - 1.0),
            (hx + 9.0, hy - 5.0 + horn_lift),
            (hx + 11.5, hy - 10.5 + horn_lift),
            2.6, 0.8, HORN, tip_col="gold",
        )
        body.eye(hx + 1.5, hy - 1.5, "gold" if not ctx.is_tell else "coral", "cream", "void", 2, 2)
        # Near legs
        for k, ox in enumerate((-7.0, -0.5, 6.0)):
            st = -stride * (1.0 if k % 2 == 0 else -1.0)
            body.capsule(cx + ox, cy - 4.5, cx + ox + st, cy + 0.5, 1.7, 1.1, LEG)
    elif d == "front":
        # 6 stubby splayed beetle legs
        for sgn in (-1.0, 1.0):
            for k, dy in enumerate((-3.0, -1.0, 1.0)):
                st = math.sin(ph + k * 1.4) * 1.6 * sgn
                body.capsule(cx + sgn * 8.0, cy - 6.0 + dy, cx + sgn * 13.0, cy - 1.0 + dy + st, 1.6, 1.0, LEG)
        # Wide beetle carapace dome + gleaming sky/ice mirror crown
        body.shaded_dome(cx, cy - 6.5, 11.5, 11.5, SHELL, bottom_cut=0.14)
        body.shaded_ellipse(cx, cy - 13.8, 7.6, 3.8, MIRROR, spec_col="cream")
        body.line(cx - 4, cy - 15, cx + 4, cy - 13, "cream", protect=True)
        # Armoured head shield + central curving horn + bright eyes
        body.shaded_ellipse(cx, cy - 6.5, 7.2, 5.2, ("night", "pine", "teal"))
        body.bezier_limb((cx, cy - 8.5), (cx + math.sin(lph) * 0.8, cy - 15.0), (cx, cy - 20.0), 2.5, 0.8, HORN, tip_col="gold")
        body.eye(cx - 4.5, cy - 7.0, "gold", "cream", "void", 2, 2)
        body.eye(cx + 2.5, cy - 7.0, "gold", "cream", "void", 2, 2)
        # Mandible nubs
        body.rect(cx - 3, cy - 3, 2, 2, "apricot")
        body.rect(cx + 1, cy - 3, 2, 2, "apricot")
    else:
        # Back view: full mirrored split-wing carapace & soft gold rear rim
        for sgn in (-1.0, 1.0):
            for k, dy in enumerate((-2.5, -0.5, 1.5)):
                st = math.sin(ph + k * 1.4) * 1.5
                body.capsule(cx + sgn * 8.5, cy - 6.0 + dy, cx + sgn * 13.0, cy - 1.0 + dy + st, 1.6, 1.0, LEG)
        body.shaded_dome(cx, cy - 6.0, 11.8, 11.2, SHELL, bottom_cut=0.12)
        body.shaded_ellipse(cx, cy - 11.5, 8.6, 5.4, MIRROR, spec_col="cream")
        body.line(cx, cy - 16.5, cx, cy - 5.5, "pine")
        # Vulnerable golden rear belly crescent
        body.shaded_ellipse(cx, cy - 3.2, 6.2, 2.2, BELLY)

    if ctx.is_tell and u > 0.30:
        # Dirt spray & horn glint
        gx = cx + (15 if d == "side" else 0)
        gy = cy - (15 if d == "side" else 20)
        fx_front.star4(gx, gy, 3 if u > 0.7 else 2, "cream", "ice")
        for k in range(3):
            dx = cx - 10 - k * 2 if d == "side" else cx + (k - 1) * 7
            fx_back.rect(dx, ay - 2 - int(u * 4) - (k % 2) * 2, 2, 2, "mauve" if k % 2 == 0 else "apricot")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 6, cy - 10, 14, 10, -58, 52, 4.4, ("coral", "apricot", "cream"))
            fx_back.line(cx - 21, cy - 10, cx - 11, cy - 10, "ice", protect=True)
            fx_back.line(cx - 19, cy - 6, cx - 12, cy - 6, "gold", protect=True)
        else:
            fx_front.slash_arc(cx, cy - 9, 15, 10, -155, -25, 4.4, ("coral", "apricot", "cream"))

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="burrow_beetle", name="Burrow Beetle", out_dir=ART_ENEMIES,
    frame=(64, 52), anchor=(32, 42),
    body_radius=6.5, hit_radius=10.0, body_centre=(32, 32),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_burrow_beetle,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
