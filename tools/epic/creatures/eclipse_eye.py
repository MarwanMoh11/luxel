#!/usr/bin/env python3
"""Island 8 Enemy: Eclipse Eye (floating leaded stained-glass oculus turret) — 54x52, anchor [27, 42]."""
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

LEAD = ("void", "night", "dusk", "plum")
STAIN = ("night", "wine", "coral", "apricot")
BRASS = ("plum", "coral", "apricot", "gold")


def draw_eclipse_eye(ctx: FrameCtx) -> Image.Image:
    w, h = 54, 52
    ax, ay = 27.0, 42.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = math.sin(ph) * 2.0 if ctx.anim == "routine" else 0.0
    sx, sy = 1.0, 1.0
    if ctx.is_tell:
        hover = -1.5 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        sx, sy = 1.12 * sm + (1.0 - sm), 0.90 * sm + (1.0 - sm)
    elif ctx.is_stagger:
        hover = 3.0
        sx, sy = 1.06, 0.94

    cx = ax
    cy = ay - 17.0 - hover
    shadow.contact_shadow(ax, ay + 1.0, 8.0, 1.6, "night")

    # 4 gothic brass tracery prongs orbiting the stained-glass frame
    prong_off = math.sin(lph) * 1.4
    for px_s, py_s in [(-12, -8), (12, -8), (-12, 8), (12, 8)]:
        p_x = cx + px_s * (0.75 if d == "side" else 1.0)
        p_y = cy + py_s + (prong_off if px_s < 0 else -prong_off)
        body.line(cx, cy, p_x, p_y, "gold")
        body.circle(p_x, p_y, 2.0, "apricot")
        body.set(p_x, p_y - 1, "cream", protect=True)

    # Outer pointed almond leaded-glass gothic frame
    rx = 12.5 if d != "side" else 9.5
    ry = 11.5
    body.shaded_poly([
        (cx - rx - 2, cy), (cx - rx * 0.55, cy - ry * 0.85),
        (cx, cy - ry - 2), (cx + rx * 0.55, cy - ry * 0.85),
        (cx + rx + 2, cy), (cx + rx * 0.55, cy + ry * 0.85),
        (cx, cy + ry + 2), (cx - rx * 0.55, cy + ry * 0.85),
    ], LEAD)
    body.ring(cx, cy, 10.5 if d != "side" else 8.2, "gold", 1.3)

    # Stained-glass mosaic panes & Eclipse Iris
    if d == "front":
        body.shaded_ellipse(cx, cy, 9.2, 8.2, STAIN, spec_col="gold")
        # Leaded stained-glass radial ribs
        for ang_d in (0, 60, 120, 180, 240, 300):
            ra = math.radians(ang_d)
            body.line(cx + math.cos(ra) * 5.0, cy + math.sin(ra) * 4.5,
                      cx + math.cos(ra) * 9.0, cy + math.sin(ra) * 8.0, "night")
        # Glowing corona ring & dark eclipse pupil
        pupil_r = 3.2 if not ctx.is_tell else max(1.6, 3.2 - u * 1.5)
        body.circle(cx, cy, 5.2, "gold", protect=True)
        body.circle(cx, cy, 4.4, "cream" if (ctx.is_tell or ctx.is_commit) else "apricot", protect=True)
        body.circle(cx + math.sin(ph) * 0.8, cy, pupil_r, "void", protect=True)
        body.set(cx - 2.0, cy - 2.0, "cream", protect=True)
    elif d == "side":
        # Side profile: thick brass bezel backing + bulging coral-gold glass lens facing right
        body.shaded_ellipse(cx - 2.0, cy, 6.2, 8.8, ("void", "night", "plum", "wine"))
        body.shaded_ellipse(cx + 4.5, cy, 5.2, 7.2, ("coral", "apricot", "gold", "cream"))
        body.ellipse(cx + 6.2, cy, 2.0, 4.2, "void", protect=True)
        body.set(cx + 4.0, cy - 3.0, "cream", protect=True)
    else:
        # Back: dark leaded-glass rear filigree with central brass keyhole hinge
        body.shaded_ellipse(cx, cy, 9.2, 8.2, ("void", "night", "dusk", "plum"))
        body.line(cx - 8, cy, cx + 8, cy, "gold")
        body.line(cx, cy - 7, cx, cy + 7, "gold")
        body.circle(cx, cy, 3.0, "apricot")
        body.circle(cx, cy, 1.5, "void")

    if ctx.is_tell and u > 0.25:
        ex = cx + (8 if d == "side" else 0)
        fx_front.ring(ex, cy, 12.0 - u * 6.5, "coral", 1.4, protect=True)
        if u > 0.55:
            fx_front.star4(ex, cy, 3 if u > 0.8 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        ex = cx + (7 if d == "side" else 0)
        if d == "side":
            fx_front.rect(ex, cy - 3, 18, 6, "coral", protect=True)
            fx_front.rect(ex, cy - 2, 18, 4, "gold", protect=True)
            fx_front.rect(ex, cy - 1, 18, 2, "cream", protect=True)
        else:
            fx_front.ring(cx, cy, 10.0 + ctx.fi * 2.5, "coral", 1.8, protect=True)
            fx_front.ring(cx, cy, 7.0 + ctx.fi * 2.0, "cream", 1.2, protect=True)
    elif ctx.is_stagger:
        body.crack(cx - 6, cy - 5, cx + 5, cy + 5, "void", "cream", seed=13)
        fx_front.dizzy_stars(cx, cy - 12, 8.0, 2.4, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="eclipse_eye", name="Eclipse Eye", out_dir=ART_ENEMIES,
    frame=(54, 52), anchor=(27, 42),
    body_radius=7.0, hit_radius=10.5, body_centre=(27, 25),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_eclipse_eye,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
