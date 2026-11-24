#!/usr/bin/env python3
"""Island 2 Enemy: Net Caster (oilskin pier trawler with weighted lantern net) — 60x54, anchor [30, 44]."""
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

OILSKIN = ("void", "night", "dusk", "plum")
HAT_RAMP = ("night", "dusk", "plum", "mauve")
NET_ROPE = ("wine", "coral", "apricot", "gold")
WEIGHT = ("dusk", "mauve", "stone")


def _draw_net_bundle(buf: PixelBuf, cx: float, cy: float, ang_deg: float, open_amt: float) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    rad = 4.2 + open_amt * 5.0
    tmp.ring(cx, cy, rad, "apricot", 1.4)
    tmp.line(cx - rad + 1, cy, cx + rad - 1, cy, "coral")
    tmp.line(cx, cy - rad + 1, cx, cy + rad - 1, "coral")
    tmp.line(cx - rad * 0.65, cy - rad * 0.65, cx + rad * 0.65, cy + rad * 0.65, "gold")
    tmp.line(cx + rad * 0.65, cy - rad * 0.65, cx - rad * 0.65, cy + rad * 0.65, "gold")
    for k in range(4):
        a = k * (math.tau / 4.0) + 0.4
        wx = cx + math.cos(a) * (rad + 1.0)
        wy = cy + math.sin(a) * (rad + 1.0)
        tmp.circle(wx, wy, 1.5, "stone")
        tmp.set(wx, wy - 0.5, "cream")
    buf.composite(rotate_buf(tmp, cx, cy, ang_deg))


def draw_net_caster(ctx: FrameCtx) -> Image.Image:
    w, h = 72, 58
    ax, ay = 36.0, 47.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = abs(math.sin(ph)) * 1.8 if ctx.anim == "routine" else 0.0
    step = math.sin(ph) * 2.2 if ctx.anim == "routine" else 0.0
    lean = 0.0
    net_ox, net_oy, net_ang, net_open = 10.0, -14.0, math.sin(lph) * 14.0, 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -2.5 * u
        net_ox = -6.0 * u if d == "side" else 11.0
        net_oy = -24.0 - 4.0 * u
        net_ang = -u * 180.0
        net_open = 0.35 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 4.5 * sm
        net_ox = 16.0 * sm if d == "side" else 12.0 * sm
        net_oy = -14.0
        net_ang = 90.0 * sm
        net_open = 0.95 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        lean = 2.0
        net_ox, net_oy, net_open = 9.0, -8.0, 0.15
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.0) * 2.2
        net_ox, net_oy, net_open = 0.0, -17.0, 0.45

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob
    shadow.contact_shadow(ax, ay + 1.0, 9.0, 1.8, "night")

    # Sturdy sea boots
    if d == "side":
        body.shaded_ellipse(cx - 3.0 + step, ay - 1.5, 3.8, 2.2, ("void", "night", "dusk"))
        body.shaded_ellipse(cx + 3.5 - step, ay - 1.2, 4.0, 2.2, ("void", "night", "dusk"))
    else:
        body.shaded_ellipse(cx - 4.5, ay - 1.5 + step * 0.4, 3.2, 2.2, ("void", "night", "dusk"))
        body.shaded_ellipse(cx + 4.5, ay - 1.5 - step * 0.4, 3.2, 2.2, ("void", "night", "dusk"))

    # Flared oilskin slicker coat with rope sash
    coat_pts = [
        (cx - 6, cy - 19), (cx + 6, cy - 19),
        (cx + 9.5, cy - 3), (cx - 9.5, cy - 3),
    ]
    body.shaded_poly(coat_pts, OILSKIN)
    # Coiled apron rope belt
    body.line(cx - 7, cy - 11, cx + 7, cy - 11, "apricot")
    body.line(cx - 7, cy - 10, cx + 7, cy - 10, "coral")
    if d == "front":
        body.line(cx, cy - 18, cx, cy - 4, "void")
        body.set(cx + 1, cy - 15, "gold")
        body.set(cx + 1, cy - 12, "gold")

    # Deep shadowy face under sou'wester brim
    hx = cx + (2.0 if d == "side" else 0.0)
    hy = cy - 22.5
    body.shaded_ellipse(hx, hy, 5.2, 4.6, ("void", "night", "dusk"))
    if d == "front":
        body.eye(hx - 2.6, hy - 0.5, "lime", "cream", "void", 2, 2)
        body.eye(hx + 1.2, hy - 0.5, "lime", "cream", "void", 2, 2)
    elif d == "side":
        body.eye(hx + 2.2, hy - 0.5, "lime", "cream", "void", 2, 2)

    # Wide slanted nautical sou'wester rain-hat (iconic silhouette!)
    hat_y = hy - 3.5
    if d == "side":
        body.shaded_poly([
            (hx - 11, hat_y + 2), (hx - 5, hat_y - 6), (hx + 4, hat_y - 5),
            (hx + 9, hat_y + 1), (hx - 10, hat_y + 5),
        ], HAT_RAMP)
        body.line(hx - 10, hat_y + 2, hx + 8, hat_y + 1, "mauve")
    else:
        body.shaded_dome(hx, hat_y, 7.2, 5.8, HAT_RAMP, bottom_cut=0.20)
        body.shaded_ellipse(hx, hat_y + 1.2, 10.5, 2.8, HAT_RAMP)
        body.line(hx - 8, hat_y, hx + 8, hat_y, "mauve")
        if d == "back":
            # Long trailing rain-flap down the back of sou'wester
            body.shaded_poly([
                (hx - 7, hat_y + 2), (hx + 7, hat_y + 2), (hx + 8, hat_y + 10), (hx - 8, hat_y + 10),
            ], OILSKIN)

    # Arm + rope line + weighted cast net
    arm_p = (cx + (4.0 if d == "side" else 7.0), cy - 14.0)
    net_p = (cx + net_ox, cy + net_oy)
    body.bezier_limb(arm_p, ((arm_p[0] + net_p[0]) * 0.5, min(arm_p[1], net_p[1]) + 2.0), net_p, 1.4, 1.0, NET_ROPE)
    _draw_net_bundle(body, net_p[0], net_p[1], net_ang, net_open)

    if ctx.is_tell and u > 0.3:
        fx_front.ring(net_p[0], net_p[1], 7.0 + u * 3.0, "gold", 1.0, 0, 360, protect=True)
        fx_front.star4(net_p[0], net_p[1] - 4, 2, "cream", "lime")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 14, 16, 11, -55, 65, 4.5, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 12, 18, 10, 10, 170, 4.5, ("coral", "apricot", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 10, 8.5, 2.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="net_caster", name="Net Caster", out_dir=ART_ENEMIES,
    frame=(72, 58), anchor=(36, 47),
    body_radius=5.5, hit_radius=10.0, body_centre=(36, 33),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="dusk",
    draw_frame=draw_net_caster,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
