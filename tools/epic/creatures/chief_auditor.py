#!/usr/bin/env python3
"""Island 8 Mini-Boss: The Chief Auditor (brass abacus-beetle with gavel limbs) — 84x80, anchor [42, 62]."""
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

CARAPACE = ("void", "night", "dusk", "plum")
SHELL_HI = ("night", "dusk", "plum", "wine")
BRASS = ("plum", "coral", "apricot", "gold")
INK = ("void", "night", "plum")


def _draw_gavel_limb(buf: PixelBuf, gx: float, gy: float, ang_deg: float, hot: bool, flip: bool = False) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    s = -1.0 if flip else 1.0
    # Jointed brass beetle foreleg ending in a heavy cylindrical audit-stamp gavel!
    tmp.capsule(gx, gy, gx + s * 9, gy - 4, 2.2, 1.8, BRASS)
    hx = gx + s * 11
    hy = gy - 5
    tmp.shaded_rect(hx - 4, hy - 6, 8, 12, BRASS)
    tmp.rect(hx - 4, hy - 6, 8, 2, "cream" if hot else "gold", protect=True)
    tmp.rect(hx - 4, hy + 4, 8, 2, "coral" if hot else "plum")
    buf.composite(rotate_buf(tmp, gx, gy, ang_deg))


def draw_chief_auditor(ctx: FrameCtx) -> Image.Image:
    w, h = 96, 100
    ax, ay = 48.0, 68.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = abs(math.sin(ph)) * 1.8 if ctx.anim in ("routine", "phase2") else 0.0
    crouch = 0.0
    lean = 0.0
    gavel_ang = math.sin(lph) * 6.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 3.5 * u
        gavel_ang = -36.0 * u - 10.0 * math.sin(u * math.pi)
        sx, sy = 1.0 + 0.08 * u, 1.0 - 0.07 * u
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lean = 6.0 * sm
        crouch = 2.5 * sm
        gavel_ang = 38.0 * sm - 8.0 * (1.0 - sm)
        sx, sy = 1.0 + 0.11 * sm, 1.0 - 0.09 * sm
    elif ctx.is_recover:
        crouch = 3.2
        gavel_ang = 18.0
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.0) * 3.0
        gavel_ang = -24.0 + math.sin(ph) * 10.0
        crouch = 1.8

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 2.0, 21.0, 3.0, "night")

    # 6 scuttling brass beetle legs along underside
    leg_step = math.sin(ph * 2.0) * 2.8 if ctx.anim in ("routine", "phase2") else 0.0
    if d == "side":
        for i, lx_off in enumerate((-13, -4, 6)):
            st = leg_step if i % 2 == 0 else -leg_step
            body.bezier_limb((cx + lx_off, cy - 8), (cx + lx_off - 2 + st, cy - 2), (cx + lx_off - 4 + st, ay), 2.0, 1.0, BRASS)
    else:
        for i, ly_off in enumerate((-10, -4)):
            st = leg_step if i % 2 == 0 else -leg_step
            body.bezier_limb((cx - 14, cy + ly_off), (cx - 20, cy + ly_off + 3 + st * 0.5), (cx - 22, ay - 1 + st * 0.4), 2.0, 1.0, BRASS)
            body.bezier_limb((cx + 14, cy + ly_off), (cx + 20, cy + ly_off + 3 - st * 0.5), (cx + 22, ay - 1 - st * 0.4), 2.0, 1.0, BRASS)

    # Wide domed mahogany/dusk beetle carapace (in P2 wing-covers crack open revealing spinning gold abacus core!)
    rx = 20.0 if d != "side" else 19.0
    ry = 16.5
    body.shaded_dome(cx, cy - 11.0, rx, ry, CARAPACE, bottom_cut=0.14)
    body.shaded_ellipse(cx, cy - 10.0, rx - 1.5, 5.2, SHELL_HI)

    if p2:
        # Opened carapace rift exposing incandescent brass abacus core!
        body.shaded_ellipse(cx, cy - 20.0, 9.0 if d != "side" else 7.5, 8.5, ("coral", "apricot", "gold", "cream"))
        body.crack(cx - 11, cy - 21, cx - 2, cy - 12, "void", "coral", seed=17)
        body.crack(cx + 11, cy - 21, cx + 3, cy - 12, "void", "gold", seed=23)

    # 4 iconic horizontal gold ABACUS RODS with sliding coral/cream beads across carapace!
    for ri, ry_off in enumerate((-23, -19, -15, -11)):
        half_w = 11.0 if ri == 0 else (15.0 if ri < 3 else 13.0)
        if d == "side":
            half_w *= 0.85
        body.line(cx - half_w, cy + ry_off, cx + half_w, cy + ry_off, "gold")
        # Sliding beads (animate with phase!)
        slide = math.sin(ph + ri * 1.4) * 3.5
        for bi in (-1, 0, 1):
            bx = cx + bi * (half_w * 0.52) + slide * (0.6 if bi == 0 else 0.3)
            bcol = "cream" if (ri + bi) % 2 == 0 else "coral"
            body.circle(bx, cy + ry_off, 2.2, bcol, protect=True)
            body.set(bx - 0.5, cy + ry_off - 0.5, "cream" if bcol == "coral" else "gold", protect=True)

    # Brass bezel rim around lower carapace
    body.line(cx - rx + 2, cy - 8, cx + rx - 2, cy - 8, "gold")

    # Beetle head + spectacles + perched feather quill behind horn!
    hx = cx + (13.0 if d == "side" else 0.0)
    hy = cy - 12.0 if d == "side" else cy - 10.0
    if d != "back":
        body.shaded_ellipse(hx, hy, 9.5 if d == "front" else 8.0, 6.8, ("void", "night", "dusk", "plum"))
        # Curved brass beetle horns
        if d == "front":
            body.bezier_limb((hx - 5, hy - 5), (hx - 9, hy - 12), (hx - 6, hy - 15), 2.0, 0.8, BRASS)
            body.bezier_limb((hx + 5, hy - 5), (hx + 9, hy - 12), (hx + 6, hy - 15), 2.0, 0.8, BRASS)
            # Round brass spectacles + piercing eyes
            body.ring(hx - 4.0, hy - 1.0, 3.2, "gold", 1.1, protect=True)
            body.ring(hx + 4.0, hy - 1.0, 3.2, "gold", 1.1, protect=True)
            body.line(hx - 1, hy - 1, hx + 1, hy - 1, "gold", protect=True)
            body.eye(hx - 4.8, hy - 1.8, "gold" if not p2 else "coral", "cream", "void", 2, 2)
            body.eye(hx + 3.2, hy - 1.8, "gold" if not p2 else "coral", "cream", "void", 2, 2)
            # Tiny tucked white-gold quill pen over right temple
            body.bezier_limb((hx + 7, hy - 5), (hx + 12, hy - 13), (hx + 16, hy - 18), 1.4, 2.2, ("stone", "cream"), tip_col="cream")
        else:
            body.bezier_limb((hx + 3, hy - 5), (hx + 9, hy - 12), (hx + 11, hy - 14), 2.0, 0.8, BRASS)
            body.ring(hx + 4.0, hy - 1.0, 3.2, "gold", 1.1, protect=True)
            body.eye(hx + 3.8, hy - 1.8, "gold" if not p2 else "coral", "cream", "void", 2, 2)
            body.bezier_limb((hx - 1, hy - 6), (hx - 6, hy - 15), (hx - 10, hy - 20), 1.4, 2.2, ("stone", "cream"), tip_col="cream")
    else:
        # Rear brass hinge plate (vulnerable weak hinge!)
        body.shaded_rect(cx - 7, cy - 11, 14, 7, BRASS)
        body.rect(cx - 5, cy - 9, 10, 3, "coral" if p2 else "apricot", protect=True)

    # Heavy audit-stamp gavel forelimbs!
    hot = p2 or ctx.is_tell or ctx.is_commit
    if d == "front":
        _draw_gavel_limb(body, cx - 17.0, cy - 11.0, -gavel_ang - 12, hot, flip=True)
        _draw_gavel_limb(body, cx + 17.0, cy - 11.0, gavel_ang + 12, hot, flip=False)
    elif d == "side":
        _draw_gavel_limb(body, cx + 9.0, cy - 10.0, gavel_ang, hot, flip=False)
    else:
        _draw_gavel_limb(body, cx - 17.0, cy - 12.0, -gavel_ang - 18, hot, flip=True)
        _draw_gavel_limb(body, cx + 17.0, cy - 12.0, gavel_ang + 18, hot, flip=False)

    if p2:
        for k in range(4):
            a = ph + k * 1.57
            fx_front.circle(cx + math.cos(a) * 23, cy - 17 + math.sin(a) * 10, 1.5, "gold" if k % 2 == 0 else "coral", protect=True)

    if ctx.is_tell and u > 0.30:
        gx = cx + (16 if d == "side" else 0)
        fx_front.star4(gx, cy - 30, 3 if u > 0.70 else 2, "cream", "gold")
        fx_front.ring(cx, cy - 12, 24.0 - u * 6.0, "gold", 1.2, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 12, cy - 10, 22, 16, -70, 70, 6.0, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 5, 27, 13, 12, 168, 5.8, ("coral", "gold", "cream"))
        fx_front.ring(cx, cy - 4, 16.0 + ctx.fi * 4.5, "gold", 1.6, protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 32, 12.0, 3.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="chief_auditor", name="The Chief Auditor", out_dir=ART_BOSSES,
    frame=(96, 100), anchor=(48, 68),
    body_radius=12.0, hit_radius=16.0, body_centre=(48, 48),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_chief_auditor,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
