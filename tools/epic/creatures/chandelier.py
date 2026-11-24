#!/usr/bin/env python3
"""Island 1 Major Boss: The Chandelier (Manor r11) — 84x80, anchor [42, 62]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

IRON = ("void", "night", "dusk", "plum")
IRON_TRIM = ("night", "dusk", "wine", "mauve")
BRASS = ("plum", "coral", "apricot", "gold")
WAX = ("mauve", "stone", "gold", "cream")
FLAME = ("wine", "coral", "apricot", "gold")


def _draw_candle(buf: PixelBuf, fx: PixelBuf, cx: float, cy: float, h: float, lit: bool, sway: float, hot: bool, p2: bool) -> None:
    # Brass drip cup
    buf.shaded_ellipse(cx, cy + 1.0, 3.0, 1.5, BRASS)
    # Tallow wax stub
    buf.shaded_rect(cx - 1.5, cy - h, 3, int(round(h)) + 1, WAX)
    # Dripping wax bead
    buf.set(cx + 1.5, cy - h * 0.4, "cream")
    if lit:
        f_col = "coral" if (p2 or hot) else "apricot"
        fx.flame_wisp(cx, cy - h - 1.0, 2.3 if hot else 1.8, 5.5 if hot else 4.2, sway, (f_col, "gold", "cream"))
    else:
        # Snuffed smoke curl in stagger/blackout
        fx.set(cx + sway * 0.4, cy - h - 2.5, "mauve")
        fx.set(cx + sway * 0.7, cy - h - 4.5, "stone")


def _draw_arm(buf: PixelBuf, fx: PixelBuf, ox: float, oy: float, tx: float, ty: float, lit: bool, sway: float, hot: bool, p2: bool) -> None:
    mid_x = (ox + tx) * 0.5
    mid_y = max(oy, ty) + 5.0
    buf.bezier_limb((ox, oy), (mid_x, mid_y), (tx, ty), 2.1, 1.3, IRON, tip_col="mauve")
    # Hanging crystal prism drop under the scroll
    buf.line(mid_x, mid_y + 1.5, mid_x, mid_y + 4.5, "sky", protect=True)
    buf.set(mid_x, mid_y + 5.0, "ice", protect=True)
    _draw_candle(buf, fx, tx, ty - 1.0, 5.0, lit, sway, hot, p2)


def draw_chandelier(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 62.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.5
    sway_x = math.sin(ph) * 4.5
    tilt = math.sin(ph) * 6.5
    flame_lag = math.sin(lph) * 2.4
    drop_y = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = -4.5 * u
        tilt = -11.0 * u
        sway_x = -3.0 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        drop_y = 11.0 * sm
        tilt = 15.0 * sm
        sway_x = 6.0 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        # Crashed low on marble floor, core wide open!
        drop_y = 12.0
        tilt = 4.0
        sway_x = 0.0
    elif ctx.is_stagger:
        drop_y = 11.0
        tilt = 18.0 + math.sin(ph * 2.0) * 6.0
        sway_x = math.sin(ph * 2.0) * 2.0

    cx = ax + sway_x * (0.65 if d == "side" else 0.5)
    cy = ay - 18.5 + hover + drop_y
    sh_rx = 18.0 + drop_y * 0.35
    shadow.contact_shadow(ax, ay + 2.0, sh_rx, 2.8, "night")

    rig = PixelBuf(w, h)
    fx_rig = PixelBuf(w, h)

    # Overhead hanging wrought-iron crown & chain shackles
    chain_col = "coral" if (ctx.is_tell or p2) else "gold"
    if not ctx.is_stagger:
        rig.chain((cx - 7.0, cy - 20.0), (cx - 13.0, max(8.0, cy - 30.0)), 1.4, "apricot", chain_col, "night", 4)
        rig.chain((cx + 7.0, cy - 20.0), (cx + 13.0, max(8.0, cy - 30.0)), -1.4, "apricot", chain_col, "night", 4)
    else:
        # Snapped dangling brass chain ends
        rig.chain((cx - 8.0, cy - 18.0), (cx - 13.0, cy - 26.0), 2.5, "apricot", "coral", "night", 3)

    # Crown hub ring & wrought-iron ribcage
    rig.shaded_dome(cx, cy - 15.0, 9.0, 6.5, IRON_TRIM, bottom_cut=0.25)
    rig.ring(cx, cy - 21.0, 3.2, chain_col, 1.3)
    rig.shaded_ellipse(cx, cy - 3.0, 12.5 if d != "side" else 10.5, 11.5, IRON)

    # Glowing molten wax-skull core cradled inside wrought-iron ribs!
    core_open = ctx.is_recover or ctx.is_stagger or ctx.is_commit
    core_ramp = ("apricot", "gold", "cream") if core_open else ("wine", "coral", "apricot", "gold")
    rig.shaded_ellipse(cx + (2.0 if d == "side" else 0.0), cy - 3.5, 7.2 if d != "side" else 6.4, 7.6, core_ramp, spec_col="cream")
    if d == "front":
        # Grinning candle-wax skull face!
        rig.eye(cx - 3.5, cy - 5.2, "void", "cream" if core_open else "gold", "night", 3, 2)
        rig.eye(cx + 1.5, cy - 5.2, "void", "cream" if core_open else "gold", "night", 3, 2)
        # Jagged grinning wax teeth
        rig.line(cx - 4.0, cy - 0.5, cx + 4.0, cy - 0.5, "void", protect=True)
        for tx_o in (-3, -1, 1, 3):
            rig.set(cx + tx_o, cy - 0.5, "cream" if core_open else "gold", protect=True)
        # Wrought-iron cage bars framing core (spread wider when open!)
        bar_off = 8.5 if core_open else 5.2
        rig.bezier_limb((cx - 4.0, cy - 13.0), (cx - bar_off, cy - 3.0), (cx - 3.0, cy + 7.5), 1.4, 1.2, IRON)
        rig.bezier_limb((cx + 4.0, cy - 13.0), (cx + bar_off, cy - 3.0), (cx + 3.0, cy + 7.5), 1.4, 1.2, IRON)
    elif d == "side":
        rig.eye(cx + 4.2, cy - 5.2, "void", "cream" if core_open else "gold", "night", 2, 2)
        rig.line(cx + 2.0, cy - 0.5, cx + 6.5, cy - 1.2, "void", protect=True)
        rig.bezier_limb((cx - 1.0, cy - 13.0), (cx - 6.5, cy - 3.0), (cx - 1.0, cy + 7.5), 1.5, 1.2, IRON)
        rig.bezier_limb((cx + 2.0, cy - 13.0), (cx + (8.0 if core_open else 4.5), cy - 3.0), (cx + 2.0, cy + 7.5), 1.3, 1.1, IRON)
    else:
        # Back wrought-iron gothic spine & wax-glow seams
        rig.capsule(cx, cy - 13.0, cx, cy + 8.0, 2.2, 1.8, IRON_TRIM)
        rig.crack(cx - 4.0, cy - 8.0, cx + 3.0, cy + 3.0, "void", "gold" if core_open else "coral", seed=31)

    # Bottom heavy iron finial & molten wax drip
    rig.shaded_poly([(cx - 4.0, cy + 7.5), (cx + 4.0, cy + 7.5), (cx, cy + 15.0)], IRON_TRIM)
    rig.circle(cx, cy + 15.5, 2.0, "coral" if p2 else "gold", protect=True)

    # Six sweeping candle arms (distinct silhouette in front/back vs side!)
    lit = not ctx.is_stagger
    hot = ctx.is_tell or ctx.is_commit
    if d != "side":
        arms = [
            (-9.0, -5.0, -25.0, -9.0),
            (9.0, -5.0, 25.0, -9.0),
            (-7.0, -11.0, -18.0, -19.0),
            (7.0, -11.0, 18.0, -19.0),
            (-6.0, 1.0, -16.0, 1.0),
            (6.0, 1.0, 16.0, 1.0),
        ]
        for ox, oy, tx, ty in arms:
            _draw_arm(rig, fx_rig, cx + ox, cy + oy, cx + tx, cy + ty, lit, flame_lag, hot, p2)
    else:
        # Asymmetric sweeping side arms so side motion feels fierce & wide
        for ox, oy, tx, ty in [
            (-6.0, -7.0, -22.0, -13.0),
            (7.0, -5.0, 24.0, -8.0),
            (5.0, -12.0, 17.0, -20.0),
            (-4.0, 0.0, -15.0, -1.0),
        ]:
            _draw_arm(rig, fx_rig, cx + ox, cy + oy, cx + tx, cy + ty, lit, flame_lag, hot, p2)

    body.composite(rotate_buf(rig, cx, cy - 4.0, tilt))
    fx_front.composite(rotate_buf(fx_rig, cx, cy - 4.0, tilt))

    if p2:
        for k in range(4):
            a = ph + k * 1.57
            fx_front.star4(cx + math.cos(a) * 26.0, cy - 4.0 + math.sin(a) * 14.0, 1, "cream", "coral")

    if ctx.is_tell and u > 0.35:
        fx_front.star4(cx, cy - 22.0, 3 if u > 0.72 else 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx, cy + 4.0, 28, 13, 5, 175, 6.0, ("coral", "apricot", "cream"))
        for k in range(4):
            ang = 0.25 + k * 0.75
            fx_front.circle(cx + math.cos(ang) * 20.0, cy + 8.0 + math.sin(ang) * 6.0, 1.8, "apricot", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 20.0, 12.0, 3.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="chandelier", name="The Chandelier", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 62),
    body_radius=12.5, hit_radius=16.5, body_centre=(42, 38),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="wine",
    draw_frame=draw_chandelier,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
