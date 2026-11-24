#!/usr/bin/env python3
"""Island 1 Boss: The Sexton (mole-toad grave digger) — 84x80, anchor [42, 60]."""
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

CASSOCK = ("void", "night", "dusk", "plum")
MANTLE = ("night", "dusk", "plum", "wine")
TOAD = ("night", "pine", "teal", "jade")
TOAD_BELLY = ("pine", "teal", "jade")
BRASS = ("plum", "coral", "apricot", "gold")
SPADE = ("dusk", "mauve", "stone", "cream")


def _draw_shovel_back(buf: PixelBuf, ax: float, ay: float, tilt: float, lit: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.capsule(ax - 11, ay - 34, ax + 10, ay - 9, 1.4, 1.4, RAMPS["wood"])
    pts = [(ax - 17, ay - 41), (ax - 9, ay - 43), (ax - 7, ay - 33), (ax - 14, ay - 31)]
    tmp.shaded_poly(pts, SPADE)
    tmp.line(ax - 16, ay - 40, ax - 10, ay - 42, "cream")
    lx, ly = ax + 10, ay - 12
    tmp.rect(lx - 2, ly - 3, 5, 6, "plum")
    tmp.rect(lx - 1, ly - 2, 3, 4, "gold" if lit else "apricot", protect=True)
    tmp.set(lx, ly - 1, "cream", protect=True)
    buf.composite(rotate_buf(tmp, ax, ay - 22, tilt))


def _draw_claw(buf: PixelBuf, cx: float, cy: float, ang_deg: float, hot: bool, flip: bool = False) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    s = -1.0 if flip else 1.0
    tmp.shaded_ellipse(cx, cy, 4.6, 3.8, BRASS)
    ramp = ("coral", "apricot", "gold", "cream") if hot else SPADE
    for dy, ln in [(-3.0, 9.0), (0.0, 11.2), (3.0, 8.5)]:
        p0 = (cx + s * 2.5, cy + dy)
        p1 = (cx + s * (2.5 + ln * 0.6), cy + dy - 1.5)
        p2 = (cx + s * (2.5 + ln), cy + dy + 2.0)
        tmp.bezier_limb(p0, p1, p2, 2.0, 0.7, ramp, tip_col="cream" if hot else "stone")
    buf.composite(rotate_buf(tmp, cx, cy, ang_deg))


def _draw_bell_hat(buf: PixelBuf, hx: float, hy: float, tilt: float, p2: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.ring(hx, hy - 14.0, 2.8, "gold", 1.3)
    tmp.shaded_dome(hx, hy - 3.5, 11.2, 10.6, BRASS, bottom_cut=0.18, spec_col="cream")
    tmp.shaded_ellipse(hx, hy - 1.0, 14.5, 3.6, BRASS)
    tmp.ellipse(hx, hy + 0.5, 11.5, 1.8, "plum")
    tmp.line(hx - 10, hy - 4, hx + 10, hy - 4, "gold", protect=True)
    tmp.line(hx - 8, hy - 5, hx + 8, hy - 5, "cream", protect=True)
    # Cast bronze bell crack / gothic rivet marks
    tmp.set(hx - 6, hy - 7, "plum")
    tmp.set(hx + 5, hy - 7, "plum")
    if p2:
        tmp.crack(hx - 5, hy - 10, hx + 3, hy - 2, "void", "coral", seed=11)
    buf.composite(rotate_buf(tmp, hx, hy, tilt))


def draw_sexton(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 62.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = math.sin(ph) * 1.5 if ctx.anim in ("routine", "phase2") else 0.0
    crouch = 0.0
    lean = 0.0
    claw_raise = 0.0
    hat_tilt = math.sin(lph) * 4.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 4.2 * u
        claw_raise = -32.0 * u - 12.0 * math.sin(u * math.pi)
        hat_tilt = -8.0 * u
        sx, sy = 1.0 + 0.09 * u, 1.0 - 0.08 * u
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lean = 6.5 * sm
        crouch = 2.8 * sm
        claw_raise = 36.0 * sm - 10.0 * (1.0 - sm)
        hat_tilt = 10.0 * sm
        sx, sy = 1.0 + 0.11 * sm, 1.0 - 0.09 * sm
    elif ctx.is_recover:
        crouch = 3.8 + math.sin(ph) * 0.9
        claw_raise = 15.0
        hat_tilt = 8.0
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.0) * 2.8
        hat_tilt = 20.0 + math.sin(ph) * 9.0
        crouch = 2.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay + bob + crouch
    shadow.contact_shadow(ax, ay + 2.0, 17.0, 2.5, "night")

    if d != "back":
        _draw_shovel_back(body, cx + (-3.0 if d == "side" else 0.0), cy - 2.0, hat_tilt * 0.45, True)

    # Squat sturdy dirt-dusted toad feet
    step_l = math.sin(ph) * 2.4 if ctx.anim in ("routine", "phase2") else 0.0
    step_r = -step_l
    if d == "side":
        body.shaded_ellipse(cx - 7.0 + step_l, ay - 1.5, 6.0, 3.6, TOAD)
        body.shaded_ellipse(cx + 6.0 + step_r, ay - 1.0, 6.4, 3.8, TOAD)
    else:
        body.shaded_ellipse(cx - 10.0, ay - 1.5 + step_l * 0.5, 5.8, 3.6, TOAD)
        body.shaded_ellipse(cx + 10.0, ay - 1.5 + step_r * 0.5, 5.8, 3.6, TOAD)

    # Heavy hunched gothic gravedigger cassock with vertical cloth folds & mud-dusted hem
    body.shaded_ellipse(cx, cy - 15.0, 17.5 if d != "side" else 16.0, 15.5, CASSOCK)
    for px_f in (-8, -2, 4, 10):
        body.line(cx + px_f, cy - 21, cx + px_f + (1 if px_f > 0 else -1), cy - 4, "void")
    # Mud-crusted tattered hem
    for k in range(-3, 4):
        body.rect(cx + k * 4.5 - 1, cy - 4.0 + (k % 2), 3, 2, "mauve" if k % 2 == 0 else "dusk")
        body.rect(cx + k * 4.5 - 1, cy - 2.5 + (k % 2), 3, 2, "void")
    # Heavy stitched shoulder mantle & brass trim
    body.shaded_dome(cx, cy - 21.0, 16.5 if d != "side" else 15.0, 9.5, MANTLE, bottom_cut=0.25)
    body.line(cx - 13, cy - 19, cx + 13, cy - 19, "gold")

    # Gothic warty mole-toad head with drooping brow ridges & wide scowling maw
    hx = cx + (5.0 if d == "side" else 0.0)
    hy = cy - 28.0
    body.shaded_ellipse(hx, hy, 12.2 if d != "side" else 10.8, 8.6, TOAD)
    # Toad wart ridges on cheeks/temples
    body.circle(hx - 9, hy - 1, 2.2, "pine")
    body.circle(hx + 8, hy - 1, 2.2, "pine")
    body.set(hx - 9, hy - 2, "teal")
    body.set(hx + 8, hy - 2, "teal")

    if d == "front":
        body.shaded_ellipse(hx, hy + 3.2, 11.2, 4.4, TOAD_BELLY)
        # Wide downturned toad frown + tiny ivory fang notches
        body.line(hx - 7, hy + 4, hx - 5, hy + 2, "void", protect=True)
        body.line(hx - 5, hy + 2, hx + 5, hy + 2, "void", protect=True)
        body.line(hx + 5, hy + 2, hx + 7, hy + 4, "void", protect=True)
        body.set(hx - 4, hy + 3, "stone", protect=True)
        body.set(hx + 4, hy + 3, "stone", protect=True)
        # Heavy hooded toad brows over fierce lantern eyes
        body.shaded_ellipse(hx - 4.5, hy - 4.0, 3.6, 1.8, TOAD)
        body.shaded_ellipse(hx + 4.5, hy - 4.0, 3.6, 1.8, TOAD)
        body.eye(hx - 6, hy - 2.2, "gold" if not p2 else "coral", "cream", "void", 3, 2)
        body.eye(hx + 3, hy - 2.2, "gold" if not p2 else "coral", "cream", "void", 3, 2)
        # Brass sanctuary bell pendant on chest
        body.shaded_dome(cx, cy - 14.0, 4.6, 4.4, BRASS, bottom_cut=0.35, spec_col="cream")
        body.circle(cx, cy - 10.2, 1.5, "gold", protect=True)
    elif d == "side":
        body.shaded_ellipse(hx + 4.5, hy + 2.5, 7.2, 4.0, TOAD_BELLY)
        body.line(hx + 2, hy + 3, hx + 10, hy + 3, "void", protect=True)
        body.set(hx + 7, hy + 4, "stone", protect=True)
        body.shaded_ellipse(hx + 4.0, hy - 4.0, 3.4, 1.8, TOAD)
        body.eye(hx + 3.5, hy - 2.2, "gold" if not p2 else "coral", "cream", "void", 3, 2)
        body.shaded_dome(cx + 8, cy - 14.0, 3.8, 3.8, BRASS, bottom_cut=0.35)
    else:
        _draw_shovel_back(body, cx, cy - 2.0, hat_tilt * 0.4, True)

    _draw_bell_hat(body, hx, hy - 6.8, hat_tilt, p2)

    hot_claws = p2 or ctx.is_tell or ctx.is_commit
    if d == "front":
        _draw_claw(body, cx - 15.0, cy - 14.0 + claw_raise * 0.35, -claw_raise - 12, hot_claws, flip=True)
        _draw_claw(body, cx + 15.0, cy - 14.0 + claw_raise * 0.35, claw_raise + 12, hot_claws, flip=False)
    elif d == "side":
        _draw_claw(body, cx + 10.0, cy - 13.0 + claw_raise * 0.32, claw_raise, hot_claws, flip=False)
    else:
        _draw_claw(body, cx - 15.0, cy - 15.0 + claw_raise * 0.3, -claw_raise - 20, hot_claws, flip=True)
        _draw_claw(body, cx + 15.0, cy - 15.0 + claw_raise * 0.3, claw_raise + 20, hot_claws, flip=False)

    if p2:
        body.crack(cx - 7, cy - 17, cx + 4, cy - 9, "void", "coral", seed=5)
        body.crack(cx + 6, cy - 18, cx + 11, cy - 10, "void", "gold", seed=9)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 19, cy - 18 + math.sin(a) * 10, "gold" if k % 2 == 0 else "coral", protect=True)
            fx_back.ring(cx, cy - 20, 21.0 + math.sin(ph) * 1.5, "apricot", 1.0, k * 90 + 10, k * 90 + 62, protect=True)

    if ctx.is_tell and u > 0.35:
        glint_x = hx + (10 if d == "side" else 0)
        fx_front.star4(glint_x, hy - 18, 3 if u > 0.72 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 7, cy - 10, 21, 15, -70, 68, 6.2, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 6, 25, 12, 15, 165, 5.8, ("coral", "gold", "cream"))
        for k in range(4):
            ang = -0.3 + k * 0.45
            fx_front.rect(cx + math.cos(ang) * (15 + ctx.fi * 2.5), cy - 3 - abs(math.sin(ang)) * 9, 2, 2, "stone" if k % 2 == 0 else "gold", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 19, 11.5, 3.8, ph)
        fx_front.ring(hx, hy - 14, 14.5 + math.sin(ph) * 1.8, "gold", 1.0, -35, 35, protect=True)
        fx_front.ring(hx, hy - 14, 14.5 + math.sin(ph) * 1.8, "gold", 1.0, 145, 215, protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="sexton", name="The Sexton", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 62),
    body_radius=12.0, hit_radius=16.0, body_centre=(42, 42),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_sexton,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
