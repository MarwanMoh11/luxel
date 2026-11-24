#!/usr/bin/env python3
"""Island 3 Briar Court Final Judge: The Briar Arbiter — 84x80, anchor [42, 64]."""
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

ROBES = ("void", "night", "dusk", "wine")
TRIM = ("plum", "wine", "coral", "apricot")
ANTLER = ("night", "pine", "jade", "lime")
BRASS = ("wine", "apricot", "gold", "cream")
OAK = ("night", "plum", "wine", "coral")


def _draw_gavel(buf: PixelBuf, gx: float, gy: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.capsule(gx, gy + 10.0, gx, gy - 14.0, 1.8, 1.5, OAK)
    ramp = ("coral", "apricot", "gold", "cream") if hot else BRASS
    tmp.shaded_rect(gx - 9.0, gy - 20.0, 18, 9, ramp)
    tmp.line(gx - 9.0, gy - 16.0, gx + 9.0, gy - 16.0, "cream" if hot else "gold", protect=True)
    tmp.rect(gx - 9.0, gy - 20.0, 3, 9, "plum")
    tmp.rect(gx + 6.0, gy - 20.0, 3, 9, "plum")
    buf.composite(rotate_buf(tmp, gx, gy, ang_deg))


def _draw_scale_pan(buf: PixelBuf, px: float, py: float, lit: bool) -> None:
    # Twin fine brass chains holding a shallow justice pan
    buf.line(px, py - 9.0, px - 5.0, py, "gold")
    buf.line(px, py - 9.0, px + 5.0, py, "gold")
    buf.shaded_ellipse(px, py + 1.0, 6.2, 2.5, BRASS)
    if lit:
        buf.circle(px, py - 1.5, 2.2, "gold", protect=True)
        buf.set(px, py - 2.0, "cream", protect=True)


def draw_briar_arbiter(ctx: FrameCtx) -> Image.Image:
    w, h = 88, 86
    ax, ay = 44.0, 70.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = math.sin(ph) * 1.4 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    kneel = 0.0
    gavel_ang = -10.0 + math.sin(ph) * 5.0
    scale_tilt = math.sin(lph) * 2.8
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        gavel_ang = -52.0 * u
        scale_tilt = -5.5 * u
        sx, sy = 0.96, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lean = 5.5 * sm
        gavel_ang = 56.0 * sm - 10.0 * (1.0 - sm)
        scale_tilt = 6.5 * sm
        sx, sy = 1.08, 0.93
    elif ctx.is_recover:
        kneel = 3.0
        gavel_ang = 32.0
    elif ctx.is_stagger:
        kneel = 7.0
        gavel_ang = 48.0
        scale_tilt = 7.0 + math.sin(ph * 2.0) * 3.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay + bob + kneel
    shadow.contact_shadow(ax, ay + 2.0, 18.0, 2.8, "night")

    # Tall imposing courtroom magistrate robes
    robe_w = 16.0 if d != "side" else 13.0
    body.shaded_poly([
        (cx - robe_w * 0.65, cy - 33.0), (cx + robe_w * 0.65, cy - 33.0),
        (cx + robe_w, cy - 2.0), (cx - robe_w, cy - 2.0),
    ], ROBES)
    # Central stole with golden thorn-scale embroidery
    if d != "back":
        sx_st = cx + (5.0 if d == "side" else 0.0)
        body.shaded_rect(sx_st - 3.5, cy - 31.0, 7, 28, TRIM)
        body.line(sx_st, cy - 29.0, sx_st, cy - 5.0, "gold")
        for k in range(3):
            body.rect(sx_st - 2.0, cy - 24.0 + k * 7.0, 4, 2, "gold")

    # Broad armored mantle shoulders
    body.shaded_dome(cx, cy - 28.0, 17.5 if d != "side" else 13.5, 9.5, ROBES, bottom_cut=0.28)
    body.line(cx - 14.0, cy - 26.0, cx + 14.0, cy - 26.0, "gold")

    # Solemn hooded wooden mask head + living emerald stag-antlers
    hx = cx + (3.0 if d == "side" else 0.0)
    hy = cy - 39.0
    body.shaded_ellipse(hx, hy, 8.6 if d != "side" else 7.8, 8.2, ROBES)
    if d != "back":
        # Pale carved wooden judge mask
        mx = hx + (2.5 if d == "side" else 0.0)
        body.shaded_ellipse(mx, hy + 0.5, 5.8 if d != "side" else 4.6, 6.2, ("dusk", "mauve", "stone", "cream"))
        if d == "front":
            body.eye(mx - 3.2, hy - 1.2, "lime" if not p2 else "gold", "cream", "void", 2, 2)
            body.eye(mx + 1.4, hy - 1.2, "lime" if not p2 else "gold", "cream", "void", 2, 2)
            body.line(mx - 2.5, hy + 3.5, mx + 2.5, hy + 3.5, "void", protect=True)
        else:
            body.eye(mx + 1.5, hy - 1.2, "lime" if not p2 else "gold", "cream", "void", 2, 2)

    # Grand branching living antlers (kept cleanly inside y >= 5, x in 10..74)
    if d == "side":
        body.bezier_limb((hx - 1.0, hy - 6.0), (hx - 6.0, hy - 16.0), (hx + 2.0, hy - 20.0), 2.4, 1.0, ANTLER, tip_col="lime")
        body.bezier_limb((hx - 4.0, hy - 13.0), (hx - 12.0, hy - 16.0), (hx - 14.0, hy - 12.0), 1.8, 0.8, ANTLER, tip_col="lime")
        # Hanging justice scale suspended forward off antler tine
        _draw_scale_pan(body, hx + 12.0, hy - 8.0 + scale_tilt, p2 or ctx.is_tell)
    else:
        for sgn in (-1.0, 1.0):
            body.bezier_limb((hx + sgn * 4.0, hy - 6.0), (hx + sgn * 14.0, hy - 14.0), (hx + sgn * 22.0, hy - 18.0), 2.4, 1.0, ANTLER, tip_col="lime")
            body.bezier_limb((hx + sgn * 11.0, hy - 12.0), (hx + sgn * 13.0, hy - 19.0), (hx + sgn * 10.0, hy - 21.0), 1.7, 0.8, ANTLER, tip_col="lime")
            # Twin Justice Scale Pans hanging from left & right antlers!
            pan_y = hy - 7.0 + (scale_tilt if sgn > 0 else -scale_tilt)
            _draw_scale_pan(body, hx + sgn * 20.0, pan_y, p2 or ctx.is_tell)

    # Massive oak-and-brass courtroom gavel
    hot = p2 or ctx.is_tell or ctx.is_commit
    if d == "side":
        _draw_gavel(body, cx + 11.0, cy - 22.0, gavel_ang, hot)
    elif d == "front":
        _draw_gavel(body, cx + 14.0, cy - 21.0, gavel_ang * 0.7 + 16.0, hot)
    else:
        _draw_gavel(body, cx + 14.0, cy - 22.0, -24.0, hot)

    if p2:
        body.crack(cx - 5.0, cy - 22.0, cx + 5.0, cy - 11.0, "void", "gold", seed=53)
        fx_back.ring(cx, cy - 24.0, 23.0, "gold", 1.1, 0, 360, protect=True)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 23.0, cy - 24.0 + math.sin(a) * 12.0, "gold" if k % 2 == 0 else "lime", protect=True)

    if ctx.is_tell and u > 0.35:
        fx_front.star4(cx + (12.0 if d == "side" else 14.0), cy - 36.0, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 12.0, cy - 16.0, 19.0, 16.0, -68, 68, 6.0, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 8.0, 26.0, 12.0, 10, 170, 5.8, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 15.0, 12.0, 3.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="briar_arbiter", name="The Briar Arbiter", out_dir=ART_BOSSES,
    frame=(88, 86), anchor=(44, 70),
    body_radius=12.5, hit_radius=16.5, body_centre=(44, 48),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_briar_arbiter,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
