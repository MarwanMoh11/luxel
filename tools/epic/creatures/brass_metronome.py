#!/usr/bin/env python3
"""Island 1 Mini-Boss #2: The Brass Metronome (Belfry r16) — 80x78, anchor [40, 62]."""
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

CHASSIS = ("void", "night", "dusk", "plum")
BRONZE = ("dusk", "wine", "apricot", "gold")
BRASS_HI = ("wine", "coral", "apricot", "gold")
IVORY = ("mauve", "stone", "gold", "cream")
BLADE = ("dusk", "mauve", "stone", "cream")


def _draw_gear(buf: PixelBuf, gx: float, gy: float, rad: float, ang: float, hot: bool) -> None:
    ramp = BRASS_HI if hot else BRONZE
    buf.shaded_ellipse(gx, gy, rad, rad, ramp)
    for k in range(6):
        a = ang + k * (math.tau / 6.0)
        tx = gx + math.cos(a) * (rad + 1.8)
        ty = gy + math.sin(a) * (rad + 1.8)
        buf.rect(tx - 1, ty - 1, 2, 2, "gold" if hot else "apricot")
    buf.circle(gx, gy, max(1.5, rad * 0.42), "night")


def _draw_pendulum_halberd(buf: PixelBuf, px: float, py: float, deg: float, hot: bool, frozen: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    rod_col = ("blue", "sky", "ice", "cream") if frozen else (BRASS_HI if hot else BRONZE)
    # Inverted metronome rod rising high from bottom pivot
    tmp.capsule(px, py, px, py - 34.0, 1.8, 1.3, rod_col)
    # Sliding trapezoidal brass counterweight bob
    bob_pts = [(px - 5.5, py - 21.0), (px + 5.5, py - 21.0), (px + 4.0, py - 14.0), (px - 4.0, py - 14.0)]
    tmp.shaded_poly(bob_pts, ("sky", "ice", "cream") if frozen else ("coral", "apricot", "gold", "cream"))
    tmp.line(px - 3.5, py - 18.0, px + 3.5, py - 18.0, "cream", protect=True)
    # Halberd crescent blade crowning the pendulum tip!
    blade_pts = [
        (px, py - 38.0), (px + 9.5, py - 33.5), (px + 7.5, py - 26.5),
        (px, py - 29.0), (px - 7.5, py - 26.5), (px - 9.5, py - 33.5),
    ]
    tmp.shaded_poly(blade_pts, ("sky", "ice", "cream") if frozen else (BRASS_HI if hot else BLADE))
    tmp.line(px - 8.5, py - 33.0, px, py - 37.5, "cream", protect=True)
    tmp.line(px, py - 37.5, px + 8.5, py - 33.0, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, deg))


def _draw_cuckoo_bird(buf: PixelBuf, bx: float, by: float, ph: float, side_view: bool) -> None:
    # Coiled brass spring popping out of chest cage + tiny frantic golden bronze bird!
    for k in range(3):
        sx = bx + (k * 2.5 if side_view else math.sin(ph * 3.0 + k) * 1.5)
        sy = by + 2.0 - k * 1.2
        buf.ring(sx, sy, 1.8, "apricot", 1.0)
    ox = bx + (7.5 if side_view else 0.0)
    oy = by - 2.5 + math.sin(ph * 4.0) * 1.2
    buf.shaded_ellipse(ox, oy, 4.2, 3.2, ("apricot", "gold", "cream"), spec_col="cream")
    # Tiny fluttering wings & open singing beak!
    buf.line(ox - 4.0, oy - 1.5, ox - 7.0, oy - 4.0 + math.sin(ph * 6.0) * 2.0, "gold", protect=True)
    buf.line(ox + 4.0, oy - 1.5, ox + 7.0, oy - 4.0 - math.sin(ph * 6.0) * 2.0, "gold", protect=True)
    buf.shaded_poly([(ox + 3.0, oy - 1.5), (ox + 7.5, oy - 2.5), (ox + 3.5, oy + 0.5)], ("coral", "apricot", "gold"))
    buf.set(ox + 2.0, oy - 1.2, "void", protect=True)


def draw_brass_metronome(ctx: FrameCtx) -> Image.Image:
    w, h = 92, 84
    ax, ay = 46.0, 68.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    # Crisp rigid L-R-L metronome tick!
    pend_deg = math.sin(ph) * 44.0
    gear_ang = ph
    slide_x = math.sin(ph) * 2.2 if ctx.anim in ("routine", "phase2") else 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Locked high at apex with coral-gold glint!
        pend_deg = -54.0 * u - 10.0
        sx, sy = 0.96, 1.05
    elif ctx.is_commit:
        # Lightning sweeping pendulum shear across full arc!
        pend_deg = -58.0 + 116.0 * min(1.0, u * 1.35)
        slide_x = 5.0 * math.sin(u * math.pi)
        sx, sy = 1.08, 0.94
    elif ctx.is_recover:
        pend_deg = 12.0 + math.sin(ph) * 4.0
    elif ctx.is_stagger:
        # Dusk-frozen wide open at apex -> cuckoo core popped out!
        pend_deg = 56.0
        gear_ang = 0.0

    cx = ax + (slide_x if d == "side" else slide_x * 0.5)
    cy = ay
    shadow.contact_shadow(ax, ay + 2.0, 18.0, 2.6, "night")

    # Flanking P2 floor escapement gears (or rail treads)
    if p2:
        _draw_gear(fx_back, cx - 15.0, cy - 7.0, 6.2, gear_ang, hot=True)
        _draw_gear(fx_back, cx + 15.0, cy - 7.0, 6.2, -gear_ang, hot=True)
    # Heavy brass rail-runner plinth base
    body.shaded_rect(cx - 14.0, cy - 6.0, 28, 6, BRONZE)
    body.line(cx - 13.0, cy - 5.0, cx + 13.0, cy - 5.0, "gold")
    body.circle(cx - 10.0, cy - 2.0, 2.2, "night")
    body.circle(cx + 10.0, cy - 2.0, 2.2, "night")

    # Iconic sharp A-frame triangular bronze metronome obelisk chassis!
    top_w = 5.5 if d != "side" else 4.8
    bot_w = 14.5 if d != "side" else 12.0
    pyr_pts = [
        (cx - top_w, cy - 44.0), (cx + top_w, cy - 44.0),
        (cx + bot_w, cy - 6.0), (cx - bot_w, cy - 6.0),
    ]
    body.shaded_poly(pyr_pts, BRONZE)
    # Recessed dark inner casing
    in_pts = [
        (cx - top_w + 2.0, cy - 41.0), (cx + top_w - 2.0, cy - 41.0),
        (cx + bot_w - 3.5, cy - 8.5), (cx - bot_w + 3.5, cy - 8.5),
    ]
    body.shaded_poly(in_pts, CHASSIS)
    # Spire finial cap
    body.shaded_poly([(cx - 6.0, cy - 44.0), (cx + 6.0, cy - 44.0), (cx, cy - 51.0)], BRASS_HI)
    body.set(cx, cy - 50.0, "cream", protect=True)

    if d == "front":
        # Ivory tempo graduation ruler strip
        body.shaded_rect(cx - 2.5, cy - 39.0, 5, 29, IVORY)
        for ty in range(-37, -11, 4):
            body.line(cx - 2.0, cy + ty, cx + 2.0, cy + ty, "night")
        # Twin glowing knight visor slits near crown
        eye_c = "ice" if ctx.is_stagger else ("coral" if (p2 or ctx.is_tell) else "gold")
        body.eye(cx - 3.0, cy - 41.5, eye_c, "cream", "void", 2, 1)
        body.eye(cx + 1.5, cy - 41.5, eye_c, "cream", "void", 2, 1)
        # Chest cuckoo cage door (flung open during stagger/recover!)
        if ctx.is_stagger or ctx.is_recover:
            body.rect(cx - 5.5, cy - 28.0, 11, 10, "void")
            body.rect(cx - 8.5, cy - 28.0, 3, 10, "gold")
            body.rect(cx + 5.5, cy - 28.0, 3, 10, "gold")
            if ctx.is_stagger:
                _draw_cuckoo_bird(body, cx, cy - 22.0, ph, False)
            else:
                body.circle(cx, cy - 23.0, 3.0, "gold", protect=True)
                body.set(cx, cy - 23.5, "cream", protect=True)
        else:
            body.shaded_rect(cx - 5.0, cy - 28.0, 10, 9, BRONZE)
            body.line(cx, cy - 28.0, cx, cy - 19.0, "void")
            body.set(cx - 1.5, cy - 23.5, "gold", protect=True)
            body.set(cx + 1.5, cy - 23.5, "gold", protect=True)
    elif d == "side":
        _draw_gear(body, cx - 2.0, cy - 20.0, 5.5, gear_ang, hot=p2)
        eye_c = "ice" if ctx.is_stagger else ("coral" if (p2 or ctx.is_tell) else "gold")
        body.eye(cx + 3.0, cy - 41.0, eye_c, "cream", "void", 2, 1)
        if ctx.is_stagger:
            body.rect(cx + 3.0, cy - 27.0, 5, 9, "void")
            _draw_cuckoo_bird(body, cx + 5.0, cy - 22.0, ph, True)
    else:
        # Back view: exposed interlocking brass clockwork & mainspring coils
        _draw_gear(body, cx - 4.0, cy - 28.0, 5.2, gear_ang, hot=p2)
        _draw_gear(body, cx + 4.5, cy - 19.0, 6.0, -gear_ang * 1.2, hot=p2)
        body.ring(cx, cy - 36.0, 3.0, "gold", 1.2)

    # Giant swinging inverted pendulum halberd!
    hot_pend = ctx.is_tell or ctx.is_commit or p2
    if d == "back":
        _draw_pendulum_halberd(fx_back, cx, cy - 11.0, pend_deg, hot_pend, ctx.is_stagger)
    else:
        _draw_pendulum_halberd(body, cx + (3.0 if d == "side" else 0.0), cy - 11.0, pend_deg, hot_pend, ctx.is_stagger)

    if ctx.is_stagger:
        # Dusk frost crystals on frozen pendulum!
        fx_front.ring(cx, cy - 24.0, 18.0, "ice", 1.3, 0, 360, protect=True)
        fx_front.dizzy_stars(cx, cy - 52.0, 10.5, 3.4, ph)
    elif ctx.is_tell and u > 0.35:
        rad = math.radians(pend_deg - 90.0)
        tx = cx + math.cos(rad) * 34.0
        ty = cy - 11.0 + math.sin(rad) * 34.0
        fx_front.star4(tx, ty, 3 if u > 0.7 else 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx, cy - 14.0, 29, 25, -148, -32, 6.0, ("coral", "gold", "cream"))

    if p2:
        body.crack(cx - 5, cy - 25, cx + 4, cy - 13, "void", "coral", seed=41)
        for k in range(4):
            a = lph + k * 1.57
            fx_front.set(cx + math.cos(a) * 20.0, cy - 24.0 + math.sin(a) * 14.0, "gold" if k % 2 == 0 else "coral", protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="brass_metronome", name="The Brass Metronome", out_dir=ART_BOSSES,
    frame=(92, 84), anchor=(46, 68),
    body_radius=11.0, hit_radius=15.0, body_centre=(46, 44),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_brass_metronome,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
