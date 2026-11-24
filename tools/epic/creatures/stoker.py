#!/usr/bin/env python3
"""Island 6 Enemy: Stoker (soot-hooded furnace salamander-automaton with glowing coal shovel) — 64x58, anchor [32, 48]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_ENEMIES, CACHE_DIR, ENEMY_ANIMS, RAMPS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

HOOD = ("void", "night", "dusk", "plum")
APRON = ("night", "plum", "wine", "coral")
SKIN = ("night", "dusk", "mauve", "stone")
IRON = ("void", "night", "dusk", "mauve")
BRASS = ("plum", "coral", "apricot", "gold")


def _draw_shovel(buf: PixelBuf, px: float, py: float, deg: float, hot: bool, scoop_coals: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Long wooden/iron handle
    tmp.capsule(px - 8, py + 2, px + 9, py - 8, 1.3, 1.2, RAMPS["wood"])
    tmp.circle(px - 8, py + 2, 1.8, "apricot")
    # Wide flat iron shovel blade
    blade = [
        (px + 7, py - 11), (px + 15, py - 14),
        (px + 17, py - 8), (px + 10, py - 5),
    ]
    tmp.shaded_poly(blade, ("wine", "coral", "apricot", "gold") if hot else IRON)
    tmp.line(px + 14, py - 13, px + 16, py - 9, "gold" if hot else "stone")
    if scoop_coals:
        tmp.circle(px + 12, py - 11, 2.5, "coral", protect=True)
        tmp.circle(px + 11, py - 12, 1.6, "gold", protect=True)
        tmp.set(px + 11, py - 12, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, deg))


def draw_stoker(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 58
    ax, ay = 32.0, 48.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hop = abs(math.sin(ph)) * 1.8 if ctx.anim == "routine" else 0.0
    lean = 0.0
    crouch = 0.0
    shov_deg = -14.0 + math.sin(ph) * 6.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 3.2 * u
        lean = -3.0 * u
        shov_deg = 28.0 * u + 12.0
        sx, sy = 1.06, 0.94
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lean = 5.5 * sm
        crouch = 1.0 * sm
        shov_deg = -62.0 * sm + 10.0 * (1.0 - sm)
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        crouch = 2.8 + math.sin(ph) * 0.7
        shov_deg = 32.0
        sx, sy = 0.96, 1.04
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.0) * 2.2
        shov_deg = -45.0 + math.sin(ph) * 18.0
        sx, sy = 0.94, 1.06

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - hop + crouch
    shadow.contact_shadow(ax, ay + 1.0, 11.0, 2.0, "night")

    # Curved salamander tail behind (lag-phase wag!)
    tail_sway = math.sin(lph) * 3.5
    if d == "side":
        body.bezier_limb((cx - 7, cy - 6), (cx - 14, cy - 5 + tail_sway * 0.5), (cx - 17, cy - 11 + tail_sway), 2.4, 0.9, APRON, tip_col="gold")
    elif d == "back":
        body.bezier_limb((cx, cy - 5), (cx + tail_sway, cy - 2), (cx + tail_sway * 1.5, cy - 8), 2.5, 0.9, APRON, tip_col="gold")
    else:
        body.bezier_limb((cx + 7, cy - 6), (cx + 12, cy - 4 + tail_sway * 0.4), (cx + 14, cy - 9 + tail_sway * 0.7), 2.0, 0.8, APRON, tip_col="coral")

    # Sturdy iron-toed boots
    step = math.sin(ph) * 2.2 if ctx.anim == "routine" else 0.0
    if d == "side":
        body.shaded_ellipse(cx - 4 + step, ay - 1.5, 3.8, 2.5, IRON)
        body.shaded_ellipse(cx + 4 - step, ay - 1.2, 4.0, 2.5, IRON)
    else:
        body.shaded_ellipse(cx - 5.5, ay - 1.5 + step * 0.5, 3.6, 2.4, IRON)
        body.shaded_ellipse(cx + 5.5, ay - 1.5 - step * 0.5, 3.6, 2.4, IRON)

    # Shovel behind in back view
    if d == "back":
        _draw_shovel(body, cx + 6, cy - 12, shov_deg - 15.0, ctx.is_tell or ctx.is_commit, ctx.is_tell)

    # Hunched soot-cloak torso + riveted leather forge apron
    body.shaded_ellipse(cx, cy - 12, 9.8 if d != "side" else 8.8, 10.5, HOOD)
    if d != "back":
        aw = 7.0 if d == "front" else 5.2
        ax_off = 3.0 if d == "side" else 0.0
        body.shaded_rect(cx + ax_off - aw * 0.5, cy - 17, aw, 12, APRON)
        # Glowing brass furnace buckle
        body.rect(cx + ax_off - 2, cy - 11, 4, 3, "gold", protect=True)
        body.set(cx + ax_off, cy - 10, "cream", protect=True)
        # Apron shoulder straps
        body.line(cx + ax_off - aw * 0.35, cy - 19, cx + ax_off - aw * 0.35, cy - 15, "apricot")
        if d == "front":
            body.line(cx + aw * 0.35, cy - 19, cx + aw * 0.35, cy - 15, "apricot")
    else:
        # Coal hopper pack on back
        body.shaded_rect(cx - 6, cy - 20, 12, 10, IRON)
        body.circle(cx - 2, cy - 20, 2.2, "coral", protect=True)
        body.circle(cx + 2, cy - 21, 2.0, "gold", protect=True)
        body.set(cx + 2, cy - 21, "cream", protect=True)

    # Pointed soot-cowl hood + glowing salamander eyes
    hx = cx + (2.5 if d == "side" else 0.0)
    hy = cy - 22.5
    cowl_tip = (hx - 5 + math.sin(lph) * 2.0, hy - 10) if d == "side" else (hx + math.sin(lph) * 2.2, hy - 11)
    body.shaded_poly([
        (hx - 9, hy + 2), (hx - 8, hy - 5), cowl_tip,
        (hx + 7, hy - 5), (hx + 9, hy + 2),
    ], HOOD)
    body.shaded_ellipse(hx, hy - 1, 7.6 if d != "side" else 6.8, 5.6, HOOD)

    if d == "front":
        body.ellipse(hx, hy + 0.5, 5.6, 3.4, "void", protect=True)
        body.eye(hx - 3.0, hy - 0.5, "gold" if not ctx.is_stagger else "coral", "cream", "void", 2, 2)
        body.eye(hx + 1.5, hy - 0.5, "gold" if not ctx.is_stagger else "coral", "cream", "void", 2, 2)
    elif d == "side":
        body.ellipse(hx + 3.2, hy + 0.5, 3.6, 3.2, "void", protect=True)
        body.eye(hx + 3.0, hy - 0.5, "gold" if not ctx.is_stagger else "coral", "cream", "void", 2, 2)
    else:
        body.line(hx - 5, hy - 2, hx + 5, hy - 2, "plum")

    # Shovel held front/side
    if d != "back":
        spx = cx + (4.0 if d == "side" else 5.5)
        spy = cy - 11.0
        _draw_shovel(body, spx, spy, shov_deg, ctx.is_tell or ctx.is_commit, ctx.is_tell)
        # Gloved gripping hand
        body.shaded_ellipse(spx - 1, spy + 1, 2.6, 2.2, BRASS)

    # FX overlays
    if ctx.is_tell:
        fx_front.circle(cx + (10 if d == "side" else 7), cy - 15 - u * 4.0, 2.0, "gold", protect=True)
        if u > 0.45:
            fx_front.star4(cx + (11 if d == "side" else 8), cy - 19, 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 14, 15, 11, -65, 55, 5.0, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx + 2, cy - 12, 16, 10, -140, -20, 4.8, ("coral", "gold", "cream"))
        for k in range(3):
            ex = cx + (13 + k * 3 if d == "side" else -6 + k * 7)
            ey = cy - 16 - (k % 2) * 4
            fx_front.circle(ex, ey, 1.8, "gold" if k == 1 else "coral", protect=True)
    elif ctx.is_recover:
        fx_front.circle(hx + 2, hy - 9 - (ctx.fi % 2) * 2, 1.8, "mauve", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 12, 8.5, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="stoker", name="Stoker", out_dir=ART_ENEMIES,
    frame=(64, 58), anchor=(32, 48),
    body_radius=6.0, hit_radius=10.5, body_centre=(32, 34),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_stoker,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6")
