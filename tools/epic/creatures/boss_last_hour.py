#!/usr/bin/env python3
"""Island 4 Superboss: The Last Hour (void/dusk winged sundial-wraith, counter-clockwise gold numeral halo, twin ice/coral clock-hand scythes) — 84x80, anchor [42, 66]."""
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

WRAITH = ("void", "void", "night", "dusk")
CLOAK = ("void", "night", "dusk", "plum")
GOLD = ("wine", "apricot", "gold", "cream")
MINUTE_BLADE = ("deep", "blue", "sky", "ice")
HOUR_BLADE = ("plum", "wine", "coral", "apricot")


def _draw_clock_scythe(buf: PixelBuf, px: float, py: float, ang_deg: float, ramp: tuple[str, ...], length: float, flip: bool = False) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    s = -1.0 if flip else 1.0
    # Ornate clock-hand shaft with spade-pointer counterweight
    tmp.capsule(px - s * 4.0, py, px + s * length, py, 1.3, 0.9, GOLD)
    tmp.circle(px - s * 4.0, py, 2.2, "gold", protect=True)
    # Sweeping crescent clock-hand scythe blade at tip
    tip_x = px + s * length
    pts = [
        (tip_x - s * 5.0, py - 1.0),
        (tip_x + s * 4.0, py - 6.5),
        (tip_x + s * 7.5, py - 1.5),
        (tip_x + s * 2.0, py + 7.5),
        (tip_x - s * 2.0, py + 2.5),
    ]
    tmp.shaded_poly(pts, ramp)
    tmp.line(tip_x + s * 3.0, py - 5.0, tip_x + s * 5.5, py - 1.0, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, ang_deg))


def draw_boss_last_hour(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 71.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    # Note: time runs BACKWARDS — halo & clock hands rotate counter-clockwise (-ph)!
    hover = 4.5 + math.sin(-ph) * 2.0
    lean = 0.0
    wing_spread = 1.0 + math.sin(-lph) * 0.08
    scythe_a = -22.0
    halo_rot = -ph * (1.4 if p2 else 0.7)
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = 5.5 + u * 1.4
        lean = -4.5 * u
        wing_spread = 1.14 + 0.08 * u
        scythe_a = -56.0 * u - 14.0
        halo_rot = -u * math.tau * 0.75
        sx, sy = 0.94, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        hover = 6.0 - 2.0 * sm
        lean = 7.5 * sm
        wing_spread = 1.24
        scythe_a = -42.0 + 104.0 * sm
        halo_rot = -u * math.tau * 1.2
        sx, sy = 1.11, 0.91
    elif ctx.is_recover:
        hover = 2.5
        wing_spread = 0.65
        scythe_a = 28.0
    elif ctx.is_stagger:
        hover = 2.0
        lean = math.sin(ph * 2.0) * 3.0
        wing_spread = 0.75
        scythe_a = -48.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - hover
    shadow.contact_shadow(ax, ay + 1.5, 14.5, 2.2, "night")

    # Grand Counter-Clockwise GOLD NUMERAL CLOCK HALO behind the wraith!
    hx = cx + (2.0 if d == "side" else 0.0)
    hy = cy - 40.0
    hr = 17.5 if not p2 else 19.0
    fx_back.ring(cx, cy - 34.0, hr, "gold" if not p2 else "coral", 1.4, protect=True)
    fx_back.ring(cx, cy - 34.0, hr - 3.0, "dusk" if not p2 else "ice", 1.0, protect=True)
    # 12 glowing clock numeral ticks rotating counter-clockwise
    for ni in range(12):
        na = halo_rot + ni * (math.tau / 12.0)
        is_card = (ni % 3 == 0)
        r0 = hr - (4.5 if is_card else 2.6)
        r1 = hr + (2.0 if is_card else 0.5)
        col_n = "cream" if is_card else ("ice" if p2 else "gold")
        fx_back.line(
            cx + math.cos(na) * r0, cy - 34.0 + math.sin(na) * r0,
            cx + math.cos(na) * r1, cy - 34.0 + math.sin(na) * r1,
            col_n, protect=True,
        )

    # Translucent Moth-Glass Sundial Wings spanning wide (backlit in back view!)
    wx_span = (22.0 if d != "side" else 16.0) * wing_spread
    if d != "side":
        for sgn in (-1.0, 1.0):
            # Upper stained-glass moth wing
            body.shaded_poly([
                (cx + sgn * 4, cy - 34),
                (cx + sgn * (wx_span + 2), cy - 46),
                (cx + sgn * (wx_span + 4), cy - 30),
                (cx + sgn * 10, cy - 23),
            ], MINUTE_BLADE if not p2 else HOUR_BLADE)
            # Lower swallowtail glass wing
            body.shaded_poly([
                (cx + sgn * 5, cy - 24),
                (cx + sgn * (wx_span * 0.85), cy - 21),
                (cx + sgn * (wx_span * 0.65), cy - 10),
                (cx + sgn * 4, cy - 16),
            ], CLOAK)
            body.line(cx + sgn * 7, cy - 34, cx + sgn * (wx_span), cy - 42, "cream", protect=True)
            body.circle(cx + sgn * (wx_span * 0.68), cy - 34, 2.4, "gold", protect=True)
    else:
        # Swept-back side wings
        body.shaded_poly([
            (cx - 2, cy - 34), (cx - wx_span - 4, cy - 46),
            (cx - wx_span - 2, cy - 26), (cx - 4, cy - 20),
        ], MINUTE_BLADE if not p2 else HOUR_BLADE)
        body.line(cx - 4, cy - 34, cx - wx_span - 1, cy - 42, "cream", protect=True)
        body.circle(cx - wx_span * 0.65, cy - 34, 2.4, "gold", protect=True)

    # Tall Floating Void/Dusk Sundial-Wraith Mantle with Hourglass Sash
    sway = math.sin(-lph) * 3.0
    mw = 10.5 if d != "side" else 9.0
    body.shaded_poly([
        (cx - mw * 0.65, cy - 36), (cx + mw * 0.65, cy - 36),
        (cx + mw + sway * 0.3, cy - 5), (cx + mw * 0.4, cy - 9),
        (cx, cy - 1), (cx - mw * 0.4, cy - 9), (cx - mw + sway * 0.3, cy - 5),
    ], CLOAK)
    # Inverted glowing hourglass sigil on chest
    if d != "side":
        body.shaded_poly([(cx - 4, cy - 31), (cx + 4, cy - 31), (cx, cy - 23)], GOLD)
        body.shaded_poly([(cx, cy - 23), (cx - 4, cy - 15), (cx + 4, cy - 15)], MINUTE_BLADE)
        body.line(cx, cy - 29, cx, cy - 17, "cream", protect=True)
    else:
        body.line(cx + 4, cy - 32, cx + 6, cy - 12, "gold")

    # Sculpted Nocturnal Clock-Face Mask & Crown Finial
    body.shaded_ellipse(hx, hy, 7.2 if d != "side" else 6.6, 8.2, WRAITH)
    body.ring(hx, hy, 7.6 if d != "side" else 6.8, "gold", 1.2, protect=True)
    # Tall sundial gnomon crest spire
    body.shaded_poly([(hx - 3.5, hy - 7.5), (hx, hy - 14.0), (hx + 3.5, hy - 7.5)], GOLD)
    body.set(hx, hy - 13.0, "cream", protect=True)
    if d == "front":
        body.eye(hx - 3.2, hy - 1.0, "coral" if p2 else "ice", "cream", "void", 2, 2)
        body.eye(hx + 1.4, hy - 1.0, "gold" if p2 else "cream", "cream", "void", 2, 2)
        # Tiny clock hands forming brow/nose sigil
        body.line(hx, hy + 2.5, hx - 2.5, hy + 5.0, "gold", protect=True)
        body.line(hx, hy + 2.5, hx + 3.0, hy + 1.0, "ice", protect=True)
    elif d == "side":
        body.eye(hx + 2.8, hy - 1.0, "coral" if p2 else "ice", "cream", "void", 2, 2)
        body.line(hx + 4.0, hy + 2.0, hx + 6.5, hy + 1.0, "gold", protect=True)
    else:
        body.circle(hx, hy, 3.2, "gold")
        body.set(hx, hy, "cream", protect=True)

    # Twin Giant Clock-Hand Scythes (Ice Minute-Hand + Coral Hour-Hand!)
    if d == "front":
        _draw_clock_scythe(body, cx - 12.0, cy - 23.0, -scythe_a - 24.0, MINUTE_BLADE, 15.0, flip=True)
        _draw_clock_scythe(body, cx + 12.0, cy - 23.0, scythe_a + 24.0, HOUR_BLADE, 14.0, flip=False)
    elif d == "side":
        _draw_clock_scythe(body, cx + 8.0, cy - 23.0, scythe_a, HOUR_BLADE if not p2 else MINUTE_BLADE, 16.0, flip=False)
    else:
        _draw_clock_scythe(body, cx - 12.0, cy - 24.0, -scythe_a - 36.0, MINUTE_BLADE, 14.0, flip=True)
        _draw_clock_scythe(body, cx + 12.0, cy - 24.0, scythe_a + 36.0, HOUR_BLADE, 14.0, flip=False)

    # Phase 2 / Tell / Commit / Stagger Reverse-Time FX
    if p2:
        for k in range(6):
            a = -ph * 1.6 + k * (math.tau / 6.0)
            fx_front.set(cx + math.cos(a) * 23.0, cy - 30.0 + math.sin(a) * 16.0, "coral" if k % 2 == 0 else "ice", protect=True)

    if ctx.is_tell and u > 0.25:
        # Inward converging reverse-time gold rays!
        r_in = 22.0 - u * 11.0
        for k in range(6):
            ra = -ph + k * (math.tau / 6.0)
            fx_front.line(
                cx + math.cos(ra) * (r_in + 5.0), cy - 30.0 + math.sin(ra) * (r_in + 5.0),
                cx + math.cos(ra) * r_in, cy - 30.0 + math.sin(ra) * r_in,
                "gold" if k % 2 == 0 else "ice", protect=True,
            )
        fx_front.star4(hx, hy - 15.0, 4 if u > 0.72 else 3, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 9, cy - 22, 22, 16, -72, 72, 5.8, ("coral", "gold", "cream"))
            fx_front.slash_arc(cx + 11, cy - 22, 17, 13, -58, 58, 3.2, ("blue", "ice", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 20, 26, 14, 10, 170, 5.8, ("coral", "gold", "cream"))
            fx_front.slash_arc(cx, cy - 22, 21, 11, 18, 162, 3.0, ("blue", "ice", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 18.0, 11.5, 3.2, -ph)
        fx_front.ring(cx, cy - 34.0, 18.0, "ice", 1.1, -30, 30, protect=True)
        fx_front.ring(cx, cy - 34.0, 18.0, "coral", 1.1, 150, 210, protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="boss_last_hour", name="The Last Hour", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 71),
    body_radius=11.0, hit_radius=15.5, body_centre=(42, 45),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="void",
    draw_frame=draw_boss_last_hour,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
