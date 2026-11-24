#!/usr/bin/env python3
"""Island 4 Mini-Boss: The Brass Shear-Keeper (topiary hedge-hound with gold scissor jaws) — 84x80, anchor [42, 64]."""
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

HEDGE = ("night", "pine", "teal", "jade")
HEDGE_HI = ("pine", "teal", "jade", "lime")
BRASS = ("plum", "coral", "apricot", "gold")
GOLD_BLADE = ("wine", "apricot", "gold", "cream")
ROSE = ("plum", "wine", "rose", "cream")


def _draw_scissor_jaws(buf: PixelBuf, jx: float, jy: float, open_deg: float, jammed: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ang = open_deg + (6.0 if jammed else 0.0)
    # Upper & lower massive brass scissor blades snapping from the hound's muzzle
    for sgn in (-1.0, 1.0):
        b = PixelBuf(buf.w, buf.h)
        pts = [
            (jx - 2, jy - sgn * 1.2),
            (jx + 13, jy - sgn * 3.5),
            (jx + 16.5, jy - sgn * 0.4),
            (jx + 11.5, jy + sgn * 2.0),
            (jx - 2, jy + sgn * 2.0),
        ]
        b.shaded_poly(pts, GOLD_BLADE)
        b.line(jx + 2, jy - sgn * 0.8, jx + 15, jy - sgn * 0.4, "cream", protect=True)
        # Rivet notch
        b.set(jx + 7, jy + sgn * 0.4, "plum")
        tmp.composite(rotate_buf(b, jx, jy, sgn * ang))
    # Central brass pivot bolt
    tmp.circle(jx, jy, 2.4, "plum")
    tmp.circle(jx, jy, 1.5, "gold", protect=True)
    tmp.set(jx - 0.5, jy - 0.5, "cream", protect=True)
    buf.composite(tmp)


def _draw_mainspring(buf: PixelBuf, mx: float, my: float, spin_deg: float, exposed: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Clockwork wind-up key & glowing coil mounted on the hound's shoulder spine
    tmp.shaded_ellipse(mx, my + 2.5, 5.5, 3.2, BRASS)
    tmp.capsule(mx, my + 1.0, mx, my - 9.0, 1.8, 1.6, BRASS)
    tmp.ring(mx - 4.2, my - 10.5, 3.4, "cream" if exposed else "gold", 1.6, protect=True)
    tmp.ring(mx + 4.2, my - 10.5, 3.4, "cream" if exposed else "gold", 1.6, protect=True)
    buf.composite(rotate_buf(tmp, mx, my + 2.0, spin_deg))


def draw_boss_shear_keeper(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 64.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    prowl = math.sin(ph) * 2.2 if ctx.anim in ("routine", "phase2") else 0.0
    bob = abs(math.sin(ph)) * 1.8 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    jaw_open = 14.0 + math.sin(ph) * 4.0
    tail_wag = math.sin(lph * 2.0) * 5.0
    key_spin = math.sin(ph) * 14.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Crouches low, scissor jaws open wide with gold glint!
        lean = -5.5 * u
        jaw_open = 18.0 + 28.0 * u
        bob = -3.0 * u
        sx, sy = 1.0 + 0.08 * u, 1.0 - 0.10 * u
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lean = 5.5 * sm
        jaw_open = 40.0 * (1.0 - sm) + 3.0
        sx, sy = 1.11, 0.91
    elif ctx.is_recover:
        lean = 2.5
        jaw_open = 5.0
    elif ctx.is_stagger:
        # Jammed blades! Frantic wagging brass tail & rattling exposed mainspring!
        lean = 1.0 + math.sin(ph * 2.0) * 1.8
        jaw_open = 24.0
        tail_wag = math.sin(ph * 4.0) * 9.0
        key_spin = math.sin(ph * 3.0) * 26.0
        sx, sy = 0.96, 1.04

    cx = ax + ((-7.5 + lean) if d == "side" else 0.0)
    cy = ay - bob
    shadow.contact_shadow(ax, ay + 2.0, 21.0 if d == "side" else 16.5, 2.8, "night")

    # Curly brass clockwork spring tail (wagging frantically when jammed!)
    if d == "side":
        tx0, ty0 = cx - 18.0, cy - 17.0
        body.bezier_limb(
            (tx0, ty0), (tx0 - 6.0, ty0 - 7.0 + tail_wag * 0.4),
            (tx0 - 3.0 + tail_wag * 0.5, ty0 - 14.0),
            2.2, 1.2, BRASS, tip_col="gold",
        )
        body.circle(tx0 - 3.0 + tail_wag * 0.5, ty0 - 14.0, 2.0, "cream" if ctx.is_stagger else "gold", protect=True)
    elif d == "back":
        body.bezier_limb(
            (cx, cy - 16.0), (cx + tail_wag * 0.5, cy - 23.0),
            (cx + tail_wag, cy - 29.0),
            2.4, 1.2, BRASS, tip_col="gold",
        )

    # Sturdy brass-shod topiary hound legs (quadruped stance!)
    if d == "side":
        for lx, off_s, ramp in [
            (cx - 13.0, prowl, ("void", "night", "pine")),
            (cx + 9.0, -prowl, ("void", "night", "pine")),
            (cx - 9.0, -prowl, HEDGE),
            (cx + 12.0, prowl, HEDGE),
        ]:
            body.capsule(lx, cy - 13.0, lx + off_s, ay - 2.0, 3.2, 2.4, ramp)
            body.shaded_rect(lx + off_s - 3.0, ay - 4.0, 6.5, 4.0, BRASS)
    else:
        for sgn in (-1.0, 1.0):
            st = prowl * 0.6 * sgn
            body.capsule(cx + sgn * 10.5, cy - 13.0, cx + sgn * 11.5, ay - 2.0 + st, 3.4, 2.6, HEDGE)
            body.shaded_rect(cx + sgn * 11.5 - 3.2, ay - 4.0 + st, 6.4, 4.0, BRASS)

    # Heavy sculpted hedge-hound torso with tufted foliage outline & brass harness straps
    if d == "side":
        body.shaded_ellipse(cx - 2.0, cy - 19.0, 17.5, 11.5, HEDGE)
        # Tufted leaf-spikes breaking the topiary back
        for tx, ty in [(-16, -24), (-9, -29), (2, -30), (-15, -13), (8, -11)]:
            body.poly([(cx + tx, cy + ty), (cx + tx - 3, cy + ty - 3), (cx + tx + 3, cy + ty - 1)], "jade")
        # Brass rib harness + blooming thorn roses (more in Phase 2)
        body.capsule(cx - 4.0, cy - 29.0, cx - 5.0, cy - 9.0, 1.6, 1.6, BRASS)
        body.capsule(cx + 6.0, cy - 28.0, cx + 5.0, cy - 10.0, 1.6, 1.6, BRASS)
        for rx, ry in [(-10, -21), (1, -18), (-3, -24)]:
            body.circle(cx + rx, cy + ry, 2.0, "rose" if p2 else "wine", protect=True)
            if p2:
                body.set(cx + rx, cy + ry, "cream", protect=True)
    else:
        body.shaded_ellipse(cx, cy - 19.0, 15.5, 12.0, HEDGE)
        for tx, ty in [(-15, -22), (15, -22), (-14, -13), (14, -13)]:
            body.poly([(cx + tx, cy + ty), (cx + tx + (3 if tx > 0 else -3), cy + ty - 3), (cx + tx, cy + ty + 2)], "jade")
        body.rect(cx - 14, cy - 20, 28, 3, "apricot")
        body.rect(cx - 14, cy - 19, 28, 1, "gold")

    # Exposed brass wind-up mainspring on spine!
    _draw_mainspring(body, cx - (3.0 if d == "side" else 0.0), cy - 30.0, key_spin, ctx.is_stagger or p2)

    # Blindfolded / brass-visor hound head + massive scissor jaws!
    hx = cx + (13.0 if d == "side" else 0.0)
    hy = cy - 25.0 + (2.0 if ctx.is_tell else 0.0)
    body.shaded_ellipse(hx, hy, 8.8 if d != "side" else 8.2, 7.6, HEDGE_HI)
    # Pointed topiary hound ears
    if d == "side":
        body.shaded_poly([(hx - 5, hy - 5), (hx - 9, hy - 14), (hx - 1, hy - 7)], HEDGE)
        body.shaded_poly([(hx - 1, hy - 5), (hx - 3, hy - 13), (hx + 3, hy - 6)], HEDGE_HI)
        # Brass blind-visor plate with glowing cream eye-slit
        body.shaded_rect(hx - 1, hy - 4, 8, 5, BRASS)
        body.line(hx + 1, hy - 2, hx + 6, hy - 2, "void", protect=True)
        body.rect(hx + 2, hy - 2, 3, 1, "cream", protect=True)
        _draw_scissor_jaws(body, hx + 6.5, hy + 2.0, jaw_open, ctx.is_stagger)
    elif d == "front":
        for sgn in (-1.0, 1.0):
            body.shaded_poly([(hx + sgn * 4, hy - 5), (hx + sgn * 9, hy - 14), (hx + sgn * 8, hy - 3)], HEDGE)
        body.shaded_rect(hx - 8, hy - 4, 16, 5, BRASS)
        body.rect(hx - 6, hy - 2, 12, 2, "void", protect=True)
        body.rect(hx - 4, hy - 2, 3, 1, "cream", protect=True)
        body.rect(hx + 1, hy - 2, 3, 1, "cream", protect=True)
        # Front-facing crossed scissor jaws snapping under muzzle!
        spread = 3.0 + jaw_open * 0.22
        body.shaded_poly([(hx - 2, hy + 2), (hx - 8 - spread * 0.5, hy + 14), (hx - 3, hy + 12)], GOLD_BLADE)
        body.shaded_poly([(hx + 2, hy + 2), (hx + 8 + spread * 0.5, hy + 14), (hx + 3, hy + 12)], GOLD_BLADE)
        body.circle(hx, hy + 4.0, 2.2, "gold", protect=True)
        body.set(hx, hy + 4.0, "cream", protect=True)
    else:
        for sgn in (-1.0, 1.0):
            body.shaded_poly([(hx + sgn * 4, hy - 5), (hx + sgn * 9, hy - 14), (hx + sgn * 8, hy - 3)], HEDGE)
        body.circle(hx - 4, hy - 1, 1.8, "rose", protect=True)
        body.circle(hx + 4, hy - 1, 1.8, "rose", protect=True)

    # Phase 2 / Tell / Commit / Stagger FX
    if p2:
        body.crack(cx - 8, cy - 22, cx + 4, cy - 14, "void", "gold", seed=7)
        for k in range(3):
            a = ph + k * 2.09
            fx_front.rect(cx + math.cos(a) * 18, cy - 20 + math.sin(a) * 10, 2, 2, "lime" if k % 2 == 0 else "gold", protect=True)

    if ctx.is_tell and u > 0.30:
        gx = hx + (17 if d == "side" else 0)
        gy = hy + (1 if d == "side" else 10)
        fx_front.star4(gx, gy, 4 if u > 0.72 else 3, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(hx + 5, hy + 2, 13, 12, -62, 62, 4.8, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(hx, hy + 7, 21, 11, 15, 165, 5.4, ("coral", "gold", "cream"))
        for k in range(4):
            fx_front.rect(cx + 8 + k * 3, cy - 26 + k * 5, 2, 2, "lime" if k % 2 == 0 else "gold", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 14.0, 10.0, 3.2, ph)
        fx_front.star4(cx - (3 if d == "side" else 0), cy - 41, 3, "cream", "gold")

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="boss_shear_keeper", name="The Brass Shear-Keeper", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 64),
    body_radius=12.0, hit_radius=16.5, body_centre=(42, 43),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_boss_shear_keeper,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
