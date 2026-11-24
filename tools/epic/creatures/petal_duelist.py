#!/usr/bin/env python3
"""Island 4 Enemy: Petal Duelist (rose glass-moth fencer with needle rapier) — 64x58, anchor [32, 48]."""
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

CLOAK = ("night", "dusk", "plum", "wine")
PETAL = ("plum", "wine", "rose", "cream")
BLADE = ("deep", "sky", "ice", "cream")
GOLD = ("wine", "apricot", "gold", "cream")


def _draw_rapier(buf: PixelBuf, px: float, py: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Rose-cup bell guard + slender needle blade
    tmp.shaded_ellipse(px, py, 3.2, 4.0, PETAL)
    tmp.circle(px, py, 1.4, "gold", protect=True)
    tmp.line(px - 4.0, py, px - 1.0, py, "gold")
    bcol = "cream" if hot else "ice"
    tmp.line(px + 2.0, py, px + 18.0, py, "sky", protect=True)
    tmp.line(px + 2.0, py - 1.0, px + 17.0, py - 1.0, bcol, protect=True)
    tmp.set(px + 19.0, py, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, ang_deg))


def draw_petal_duelist(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 58
    ax, ay = 32.0, 50.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    # Light rhythmic fencing bounce
    hop = abs(math.sin(ph)) * 1.8 if ctx.anim == "routine" else 0.0
    sway = math.sin(lph) * 2.4
    lean = 0.0
    rap_ang = -12.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -4.2 * u
        rap_ang = -36.0 * u - 10.0
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.65) * math.pi)
        lean = 5.5 * sm
        rap_ang = 4.0 * sm
        sx, sy = 1.10, 0.91
    elif ctx.is_recover:
        lean = 3.2
        rap_ang = 28.0
    elif ctx.is_stagger:
        lean = -3.2 + math.sin(ph * 2.0) * 1.8
        rap_ang = -52.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - hop
    shadow.contact_shadow(ax, ay + 1.5, 9.0, 1.6, "night")

    # Slender fencing boots in lunging stance
    step = math.sin(ph) * 2.5 if ctx.anim == "routine" else 0.0
    if d == "side":
        body.capsule(cx - 2.0, cy - 9, cx - 5.5 + step, ay - 1, 1.7, 1.2, CLOAK)
        body.capsule(cx + 2.5, cy - 9, cx + 6.5 - step, ay - 1, 1.7, 1.2, CLOAK)
    else:
        body.capsule(cx - 3.5, cy - 9, cx - 4.0, ay - 1 + step * 0.4, 1.7, 1.2, CLOAK)
        body.capsule(cx + 3.5, cy - 9, cx + 4.0, ay - 1 - step * 0.4, 1.7, 1.2, CLOAK)

    # Moth-wing petal cape trailing behind (secondary motion!)
    if d == "side":
        body.shaded_poly([
            (cx - 2, cy - 23), (cx - 15 - sway * 0.7, cy - 13),
            (cx - 13 - sway * 0.5, cy - 6), (cx - 4, cy - 9),
        ], PETAL)
        body.line(cx - 5, cy - 19, cx - 12 - sway * 0.5, cy - 11, "cream")
    elif d == "back":
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (cx, cy - 24), (cx + sgn * (12 + abs(sway) * 0.3), cy - 17),
                (cx + sgn * 10, cy - 6), (cx + sgn * 2, cy - 9),
            ], PETAL)
            body.circle(cx + sgn * 6.5, cy - 14.0, 1.8, "cream", protect=True)
    else:
        for sgn in (-1.0, 1.0):
            body.shaded_poly([
                (cx + sgn * 3, cy - 23), (cx + sgn * 11, cy - 14),
                (cx + sgn * 8, cy - 7), (cx + sgn * 3, cy - 10),
            ], CLOAK)

    # Fitted wine/plum fencing doublet + scalloped rose-petal ruff collar
    body.shaded_poly([
        (cx - 5.5, cy - 23), (cx + 5.5, cy - 23),
        (cx + 4.5, cy - 10), (cx - 4.5, cy - 10),
    ], CLOAK)
    body.line(cx, cy - 22, cx, cy - 11, "gold")
    # Rose-petal ruff collar
    for k in (-3, -1, 1, 3):
        body.shaded_ellipse(cx + k * 2.2, cy - 23.0, 2.8, 2.2, PETAL)

    # Glass-moth masked head + feathered twin moth antennae
    hx = cx + (1.5 if d == "side" else 0.0)
    hy = cy - 30.5
    body.shaded_ellipse(hx, hy, 5.5, 5.2, ("dusk", "mauve", "rose", "cream"))
    # Feathered rose-gold antennae with lag sway
    for sgn in (-1.0, 1.0):
        ax0 = hx + (sgn * 1.5 if d == "side" else sgn * 3.0)
        ax1 = ax0 + (sgn * 4.0 if d != "side" else -4.0) + sway * 0.5
        body.bezier_limb((ax0, hy - 4.5), (ax0 + sway * 0.25, hy - 9.5), (ax1, hy - 10.5), 1.6, 0.7, PETAL, tip_col="gold")

    if d == "front":
        # Porcelain fencing half-mask & keen amber eyes
        body.shaded_ellipse(hx, hy + 0.5, 4.6, 2.4, ("mauve", "stone", "cream"))
        body.eye(hx - 2.5, hy - 0.5, "gold", "cream", "void", 2, 2)
        body.eye(hx + 1.0, hy - 0.5, "gold", "cream", "void", 2, 2)
        _draw_rapier(body, cx + 7.5, cy - 16.0, rap_ang - 16.0, ctx.is_tell or ctx.is_commit)
    elif d == "side":
        body.shaded_ellipse(hx + 2.0, hy + 0.5, 3.2, 2.4, ("mauve", "stone", "cream"))
        body.eye(hx + 2.2, hy - 0.5, "gold", "cream", "void", 2, 2)
        _draw_rapier(body, cx + 6.5, cy - 16.5, rap_ang, ctx.is_tell or ctx.is_commit)
    else:
        _draw_rapier(body, cx + 7.5, cy - 16.0, rap_ang - 32.0, ctx.is_tell or ctx.is_commit)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.30:
        gx = cx + (17 if d == "side" else 14)
        fx_front.star4(gx, cy - 19, 3 if u > 0.72 else 2, "cream", "rose")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        # Rose-echo ribbon smear + bright rapier thrust
        if d == "side":
            fx_front.slash_arc(cx + 9, cy - 16, 17, 9, -45, 45, 4.8, ("wine", "rose", "cream"))
            fx_back.line(cx - 12, cy - 18, cx + 4, cy - 18, "rose", protect=True)
            fx_back.line(cx - 10, cy - 12, cx + 2, cy - 12, "wine", protect=True)
        else:
            fx_front.slash_arc(cx + 3, cy - 14, 17, 10, -25, 140, 4.5, ("wine", "rose", "cream"))
        for k in range(3):
            fx_front.rect(cx - 8 + k * 7, cy - 22 + k * 5, 2, 2, "rose" if k % 2 == 0 else "cream", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 11.0, 8.0, 2.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="petal_duelist", name="Petal Duelist", out_dir=ART_ENEMIES,
    frame=(64, 58), anchor=(32, 50),
    body_radius=5.5, hit_radius=10.0, body_centre=(32, 33),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_petal_duelist,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
