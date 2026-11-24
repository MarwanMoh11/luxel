#!/usr/bin/env python3
"""Island 6 Boss: The Engineer (towering brass boiler-bodied locomotive captain with smokestack hat, pressure-gauge belly, coal-shovel staff & red throttle arm) — 88x84, anchor [44, 68]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, RAMPS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

BOILER = ("void", "night", "dusk", "plum")
BRASS = ("plum", "coral", "apricot", "gold")
STEEL = ("night", "dusk", "mauve", "stone")
THROTTLE = ("plum", "wine", "coral", "apricot")


def _draw_shovel_staff(buf: PixelBuf, px: float, py: float, deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.capsule(px, py + 14, px, py - 18, 1.8, 1.5, RAMPS["wood"])
    pts = [(px - 6, py - 24), (px + 6, py - 24), (px + 8, py - 14), (px - 8, py - 14)]
    tmp.shaded_poly(pts, ("wine", "coral", "apricot", "gold") if hot else STEEL)
    if hot:
        tmp.ellipse(px, py - 19, 4.0, 2.5, "gold", protect=True)
        tmp.set(px, py - 20, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, deg))


def _draw_smokestack_hat(buf: PixelBuf, hx: float, hy: float, tilt: float, p2: bool, ph: float) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Wide riveted iron brim
    tmp.shaded_ellipse(hx, hy, 14.5, 3.6, STEEL)
    # Tall flared locomotive smokestack cylinder!
    tmp.shaded_poly([
        (hx - 8, hy), (hx - 7, hy - 14), (hx - 10, hy - 19),
        (hx + 10, hy - 19), (hx + 7, hy - 14), (hx + 8, hy),
    ], BOILER)
    # Brass rim bands
    tmp.line(hx - 9, hy - 18, hx + 9, hy - 18, "gold")
    tmp.line(hx - 7, hy - 12, hx + 7, hy - 12, "apricot")
    tmp.line(hx - 7, hy - 4, hx + 7, hy - 4, "gold")
    if p2:
        # Blazing overclocked smokestack flame!
        tmp.circle(hx, hy - 21 - math.sin(ph) * 1.5, 4.2, "coral", protect=True)
        tmp.circle(hx, hy - 21, 2.4, "gold", protect=True)
        tmp.set(hx, hy - 22, "cream", protect=True)
    buf.composite(rotate_buf(tmp, hx, hy, tilt))


def draw_engineer(ctx: FrameCtx) -> Image.Image:
    w, h = 104, 94
    ax, ay = 48.0, 76.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = abs(math.sin(ph)) * 1.4 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    crouch = 0.0
    hat_tilt = math.sin(lph) * 3.5
    staff_deg = 12.0 + math.sin(ph) * 5.0
    throttle_y = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 3.8 * u
        lean = -3.5 * u
        hat_tilt = -8.0 * u
        staff_deg = -28.0 * u
        throttle_y = -6.0 * u
        sx, sy = 1.08, 0.93
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 6.5 * sm
        crouch = 1.5 * sm
        hat_tilt = 10.0 * sm
        staff_deg = 58.0 * sm
        throttle_y = 6.0 * sm
        sx, sy = 1.11, 0.91
    elif ctx.is_recover:
        crouch = 3.5 + math.sin(ph) * 0.7
        hat_tilt = 7.0
        staff_deg = 26.0
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.0) * 3.2
        hat_tilt = 22.0 + math.sin(ph * 2.0) * 12.0
        crouch = 2.5
        staff_deg = -45.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 2.0, 20.0, 3.0, "night")

    # Massive locomotive drive-wheel boots / legs
    step = math.sin(ph) * 2.6 if ctx.anim in ("routine", "phase2") else 0.0
    if d == "side":
        body.shaded_ellipse(cx - 7 + step, ay - 4, 6.5, 4.5, BOILER)
        body.shaded_ellipse(cx + 7 - step, ay - 4, 6.5, 4.5, STEEL)
        body.line(cx - 7 + step, ay - 4, cx + 7 - step, ay - 4, "gold")  # drive piston rod!
    else:
        body.shaded_rect(cx - 13, ay - 9 + step * 0.5, 9, 9, BOILER)
        body.shaded_rect(cx + 4, ay - 9 - step * 0.5, 9, 9, BOILER)
        body.rect(cx - 12, ay - 4 + step * 0.5, 7, 2, "gold")
        body.rect(cx + 5, ay - 4 - step * 0.5, 7, 2, "gold")

    # Twin brass pressure-pipes rising behind shoulders!
    if d != "side":
        for sx_p in (-16, 16):
            body.shaded_rect(cx + sx_p - 2, cy - 42, 4, 16, BRASS)
            body.rect(cx + sx_p - 3, cy - 43, 6, 2, "gold")
    else:
        body.shaded_rect(cx - 14, cy - 42, 5, 16, BRASS)
        body.rect(cx - 15, cy - 43, 7, 2, "gold")

    # Towering cylindrical brass-banded BOILER BODY
    bw = 18.5 if d != "side" else 16.0
    body.shaded_ellipse(cx, cy - 22, bw, 17.5, BOILER)
    # Riveted brass boiler bands
    body.line(cx - bw + 3, cy - 30, cx + bw - 3, cy - 30, "gold")
    body.line(cx - bw + 2, cy - 12, cx + bw - 2, cy - 12, "apricot")

    # Glowing glass PRESSURE-GAUGE BELLY!
    if d == "front":
        body.circle(cx, cy - 21, 9.0, "plum", protect=True)
        body.circle(cx, cy - 21, 7.2, "apricot" if not p2 else "coral", protect=True)
        body.circle(cx, cy - 21, 5.4, "gold" if not p2 else "cream", protect=True)
        # Pressure dial needle
        n_ang = -0.8 + (1.8 if (p2 or ctx.is_tell) else math.sin(ph) * 0.4)
        body.line(cx, cy - 21, cx + math.cos(n_ang) * 5.0, cy - 21 + math.sin(n_ang) * 5.0, "void", protect=True)
        body.circle(cx, cy - 21, 1.5, "void", protect=True)
        # Furnace grate under gauge
        body.rect(cx - 6, cy - 11, 12, 4, "coral", protect=True)
        body.rect(cx - 4, cy - 10, 8, 2, "gold", protect=True)
    elif d == "side":
        body.shaded_ellipse(cx + 8, cy - 21, 5.2, 7.6, ("wine", "coral", "apricot", "gold"), spec_col="cream")
        body.line(cx + 8, cy - 21, cx + 11, cy - 24, "void", protect=True)
        body.shaded_rect(cx - 13, cy - 26, 7, 14, STEEL)  # rear coal bunker
    else:
        body.shaded_rect(cx - 12, cy - 30, 24, 18, STEEL)
        body.circle(cx - 5, cy - 21, 3.0, "coral", protect=True)
        body.circle(cx + 5, cy - 21, 3.0, "coral", protect=True)
        body.set(cx - 5, cy - 21, "gold", protect=True)
        body.set(cx + 5, cy - 21, "gold", protect=True)

    # Riveted brass shoulders
    if d != "side":
        body.shaded_ellipse(cx - 18, cy - 31, 6.2, 5.8, BRASS)
        body.shaded_ellipse(cx + 18, cy - 31, 6.2, 5.8, BRASS)
    else:
        body.shaded_ellipse(cx + 1, cy - 31, 6.8, 6.0, BRASS)

    # Captain's brass-goggled furnace head
    hx = cx + (4.0 if d == "side" else 0.0)
    hy = cy - 38.0
    body.shaded_ellipse(hx, hy, 10.5 if d != "side" else 9.0, 7.5, STEEL)
    if d == "front":
        # Glowing locomotive brass goggles + iron mustache visor
        body.eye(hx - 4.5, hy - 1.0, "gold" if not p2 else "cream", "cream", "void", 3, 2)
        body.eye(hx + 2.0, hy - 1.0, "gold" if not p2 else "cream", "cream", "void", 3, 2)
        body.shaded_poly([(hx - 7, hy + 2), (hx, hy + 5), (hx + 7, hy + 2), (hx, hy + 1)], BRASS)
    elif d == "side":
        body.eye(hx + 4.0, hy - 1.0, "gold" if not p2 else "cream", "cream", "void", 3, 2)
        body.shaded_rect(hx + 3, hy + 2, 6, 3, BRASS)

    # Towering SMOKESTACK TOP-HAT!
    _draw_smokestack_hat(body, hx, hy - 6.0, hat_tilt, p2, ph)

    # Left RED THROTTLE LEVER ARM + Right COAL-SHOVEL STAFF
    hot_w = p2 or ctx.is_tell or ctx.is_commit
    if d == "front":
        # Left throttle lever arm
        body.capsule(cx - 19, cy - 28, cx - 23, cy - 16 + throttle_y, 2.4, 2.0, THROTTLE)
        body.circle(cx - 24, cy - 15 + throttle_y, 3.2, "coral", protect=True)
        body.set(cx - 24, cy - 16 + throttle_y, "cream", protect=True)
        # Right shovel staff
        _draw_shovel_staff(body, cx + 22, cy - 20, staff_deg, hot_w)
    elif d == "side":
        _draw_shovel_staff(body, cx + 13, cy - 20, staff_deg, hot_w)
        # Red throttle grip tucked near chest
        body.circle(cx + 6, cy - 18 + throttle_y * 0.6, 3.0, "coral", protect=True)
    else:
        _draw_shovel_staff(body, cx + 21, cy - 20, -staff_deg * 0.6, hot_w)

    # Phase 2 overclocked fissures & aura
    if p2:
        body.crack(cx - 9, cy - 25, cx + 7, cy - 13, "void", "coral", seed=23)
        body.crack(cx + 8, cy - 26, cx + 12, cy - 15, "void", "gold", seed=31)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 23, cy - 24 + math.sin(a) * 12, "gold" if k % 2 == 0 else "coral", protect=True)
            fx_back.ring(cx, cy - 24, 24.0 + math.sin(ph) * 1.5, "apricot", 1.0, k * 90 + 12, k * 90 + 58, protect=True)

    # FX overlays
    if ctx.is_tell:
        # Both pressure pipes flare steam & gold glint!
        fx_front.circle(cx - (14 if d == "side" else 16), cy - 46 - u * 4.0, 2.4, "cream", protect=True)
        if d != "side":
            fx_front.circle(cx + 16, cy - 46 - u * 4.0, 2.4, "cream", protect=True)
        if u > 0.35:
            fx_front.star4(cx + (14 if d == "side" else 0), cy - 22, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 12, cy - 18, 24, 17, -75, 75, 6.5, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 12, 28, 14, 10, 170, 6.2, ("coral", "gold", "cream"))
    elif ctx.is_recover:
        fx_front.circle(cx - (14 if d == "side" else 16), cy - 45 - (ctx.fi % 3) * 2, 2.2, "stone", protect=True)
    elif ctx.is_stagger:
        fx_front.circle(cx, cy - 24 - (ctx.fi % 3) * 3, 3.0, "ice", protect=True)
        fx_front.dizzy_stars(hx, hy - 22, 13.0, 4.0, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="engineer", name="The Engineer", out_dir=ART_BOSSES,
    frame=(104, 94), anchor=(48, 76),
    body_radius=12.0, hit_radius=18.0, body_centre=(48, 52),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_engineer,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6")
