#!/usr/bin/env python3
"""Island 3 Mini-Boss B: The Thread-Keeper (heartwood loom-mantis) — 68x68, anchor [34, 54]."""
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

CARAPACE = ("night", "dusk", "plum", "wine")
BODY_MAUVE = ("dusk", "plum", "mauve", "stone")
SILK = ("deep", "sky", "ice", "cream")
SHUTTLE = ("wine", "coral", "apricot", "gold")
CLOG = ("night", "plum", "wine", "apricot")


def _draw_shuttle_blade(buf: PixelBuf, sx: float, sy: float, ang_deg: float, hot: bool, flip: bool = False) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    s = -1.0 if flip else 1.0
    ramp = ("coral", "apricot", "gold", "cream") if hot else SHUTTLE
    # Curved weaver's shuttle scythe blade
    pts = [
        (sx, sy - 2.0),
        (sx + s * 10.0, sy - 5.0),
        (sx + s * 19.0, sy - 1.0),
        (sx + s * 12.0, sy + 4.0),
        (sx + s * 2.0, sy + 2.5),
    ]
    tmp.shaded_poly(pts, ramp)
    tmp.line(sx + s * 3.0, sy - 1.5, sx + s * 16.0, sy - 1.0, "cream" if hot else "gold", protect=True)
    # Brass bobbin eye in blade center
    tmp.circle(sx + s * 7.5, sy - 0.5, 2.0, "plum")
    tmp.set(sx + s * 7.5, sy - 0.5, "cream" if hot else "gold", protect=True)
    buf.composite(rotate_buf(tmp, sx, sy, ang_deg))


def draw_thread_keeper(ctx: FrameCtx) -> Image.Image:
    w, h = 72, 74
    ax, ay = 36.0, 60.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = math.sin(ph) * 1.6 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    crouch = 0.0
    blade_ang = math.sin(ph) * 8.0
    cloak_sway = math.sin(lph) * 3.5
    hop_y = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 2.5 * u
        blade_ang = -46.0 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lean = 5.5 * sm
        blade_ang = 44.0 * sm - 12.0 * (1.0 - sm)
        sx, sy = 1.08, 0.93
    elif ctx.is_recover:
        crouch = 3.5 + math.sin(ph) * 0.7
        blade_ang = 26.0
    elif ctx.is_stagger:
        # Comedy beat: hops wildly shaking a smoking wooden boot!
        hop_y = abs(math.sin(ph * 2.0)) * 5.0
        lean = math.sin(ph * 2.0) * 3.0
        blade_ang = 32.0 + math.sin(ph * 2.0) * 14.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay + bob + crouch - hop_y
    shadow.contact_shadow(ax, ay + 2.0, 13.0 if not ctx.is_stagger else 10.0, 2.2, "night")

    # Billowing woven silk cloak behind mantis torso
    cloak_w = 13.0 if d != "side" else 9.0
    cloak_x = cx - (5.0 if d == "side" else 0.0)
    cloak_pts = [
        (cloak_x - cloak_w * 0.5, cy - 28.0),
        (cloak_x + cloak_w * 0.5, cy - 28.0),
        (cloak_x + cloak_w + cloak_sway * 0.6, cy - 5.0),
        (cloak_x + cloak_sway * 0.3, cy - 2.0),
        (cloak_x - cloak_w + cloak_sway * 0.6, cy - 5.0),
    ]
    body.shaded_poly(cloak_pts, SILK if not p2 else ("blue", "sky", "ice", "cream"))
    body.line(cloak_x - cloak_w * 0.6 + cloak_sway * 0.4, cy - 7.0, cloak_x + cloak_w * 0.6 + cloak_sway * 0.4, cy - 7.0, "gold")

    # Articulated wooden mantis legs & woven clogs
    step_l = math.sin(ph) * 2.6 if ctx.anim in ("routine", "phase2") else 0.0
    step_r = -step_l
    if ctx.is_stagger:
        # One leg raised high shaking smoking clog!
        body.bezier_limb((cx - 3.0, cy - 11.0), (cx - 6.0, cy - 4.0), (cx - 4.0, ay - 1.5), 2.0, 1.3, CARAPACE)
        body.shaded_ellipse(cx - 4.0, ay - 1.0, 4.2, 2.5, CLOG)
        kick_y = cy - 9.0 - math.sin(ph * 2.0) * 3.0
        body.bezier_limb((cx + 3.0, cy - 11.0), (cx + 10.0, cy - 11.0), (cx + 13.0, kick_y), 2.0, 1.3, CARAPACE)
        body.shaded_ellipse(cx + 14.0, kick_y, 4.4, 2.6, CLOG)
        # Smoke wisps curling off the toasted boot
        fx_front.flame_wisp(cx + 16.0, kick_y - 3.0, 2.2, 6.0, ph, ("coral", "apricot", "cream"))
    elif d == "side":
        body.bezier_limb((cx - 2.0, cy - 12.0), (cx - 7.0, cy - 5.0), (cx - 5.0 + step_l, ay - 1.5), 2.1, 1.3, CARAPACE)
        body.bezier_limb((cx + 2.0, cy - 12.0), (cx + 7.0, cy - 5.0), (cx + 5.0 + step_r, ay - 1.5), 2.1, 1.3, CARAPACE)
        body.shaded_ellipse(cx - 5.0 + step_l, ay - 1.0, 4.4, 2.4, CLOG)
        body.shaded_ellipse(cx + 6.0 + step_r, ay - 1.0, 4.6, 2.4, CLOG)
    else:
        body.bezier_limb((cx - 4.0, cy - 12.0), (cx - 9.0, cy - 5.0), (cx - 7.5, ay - 1.5 + step_l * 0.4), 2.1, 1.3, CARAPACE)
        body.bezier_limb((cx + 4.0, cy - 12.0), (cx + 9.0, cy - 5.0), (cx + 7.5, ay - 1.5 + step_r * 0.4), 2.1, 1.3, CARAPACE)
        body.shaded_ellipse(cx - 7.5, ay - 1.0 + step_l * 0.4, 4.2, 2.4, CLOG)
        body.shaded_ellipse(cx + 7.5, ay - 1.0 + step_r * 0.4, 4.2, 2.4, CLOG)

    # Tall sculpted heartwood mantis abdomen + slender upright thorax
    body.shaded_ellipse(cx - (3.5 if d == "side" else 0.0), cy - 14.0, 7.5 if d != "side" else 8.2, 7.0, CARAPACE)
    body.shaded_ellipse(cx + (1.5 if d == "side" else 0.0), cy - 23.0, 6.2 if d != "side" else 5.4, 8.8, BODY_MAUVE)
    # Brass loom-harness ribs on chest
    body.line(cx - 5.0, cy - 25.0, cx + 5.0, cy - 25.0, "gold")
    body.line(cx - 4.0, cy - 20.0, cx + 4.0, cy - 20.0, "apricot")
    body.circle(cx + (3.0 if d == "side" else 0.0), cy - 22.5, 2.2, "gold", protect=True)

    # Triangular mantis head + tall golden bobbin-crown & silk antennae
    hx = cx + (3.5 if d == "side" else 0.0)
    hy = cy - 35.0
    head_pts = [
        (hx - 6.5, hy - 3.5), (hx + 6.5, hy - 3.5),
        (hx + 3.8, hy + 4.5), (hx - 3.8, hy + 4.5),
    ]
    body.shaded_poly(head_pts, CARAPACE)
    # Bobbin crown on top of head
    body.shaded_rect(hx - 4.0, hy - 9.5, 8, 6, SHUTTLE)
    body.line(hx - 5.0, hy - 9.5, hx + 5.0, hy - 9.5, "gold")
    body.line(hx - 5.0, hy - 4.0, hx + 5.0, hy - 4.0, "gold")
    body.line(hx - 3.0, hy - 7.0, hx + 3.0, hy - 7.0, "ice" if p2 else "cream", protect=True)
    # Graceful curved silk antennae (kept strictly inside y >= 4)
    ant_w = math.sin(lph) * 2.2
    body.bezier_limb((hx - 2.0, hy - 8.5), (hx - 7.0, hy - 14.0 + ant_w), (hx - 11.0, hy - 12.0 + ant_w), 1.1, 0.5, ("gold", "cream"))
    body.bezier_limb((hx + 2.0, hy - 8.5), (hx + 7.0, hy - 14.0 - ant_w), (hx + 11.0, hy - 12.0 - ant_w), 1.1, 0.5, ("gold", "cream"))

    if d == "front":
        body.eye(hx - 4.8, hy - 1.5, "gold" if not p2 else "ice", "cream", "void", 3, 2)
        body.eye(hx + 2.2, hy - 1.5, "gold" if not p2 else "ice", "cream", "void", 3, 2)
    elif d == "side":
        body.eye(hx + 2.5, hy - 1.5, "gold" if not p2 else "ice", "cream", "void", 3, 2)
    else:
        # Back silk ribbon sash knot
        body.shaded_ellipse(cx, cy - 23.0, 5.0, 3.2, SHUTTLE)
        body.bezier_limb((cx - 2.0, cy - 22.0), (cx - 6.0 + cloak_sway * 0.5, cy - 13.0), (cx - 4.0 + cloak_sway, cy - 5.0), 1.6, 0.9, SILK)
        body.bezier_limb((cx + 2.0, cy - 22.0), (cx + 6.0 + cloak_sway * 0.5, cy - 13.0), (cx + 4.0 + cloak_sway, cy - 5.0), 1.6, 0.9, SILK)

    # Dual brass shuttle-blade forearms (poised angled shears in front view)
    hot = p2 or ctx.is_tell or ctx.is_commit
    if d == "front":
        _draw_shuttle_blade(body, cx - 7.0, cy - 23.0, -blade_ang - 28.0, hot, flip=True)
        _draw_shuttle_blade(body, cx + 7.0, cy - 23.0, blade_ang + 28.0, hot, flip=False)
    elif d == "side":
        _draw_shuttle_blade(body, cx + 5.0, cy - 24.0, blade_ang, hot, flip=False)
    else:
        _draw_shuttle_blade(body, cx - 7.0, cy - 24.0, -blade_ang - 30.0, hot, flip=True)
        _draw_shuttle_blade(body, cx + 7.0, cy - 24.0, blade_ang + 30.0, hot, flip=False)

    if p2:
        body.crack(cx - 3.0, cy - 24.0, cx + 2.0, cy - 15.0, "void", "ice", seed=17)
        fx_back.ring(cx, cy - 24.0, 17.0, "sky", 1.0, 0, 360, protect=True)
        for k in range(3):
            a = ph + k * 2.094
            fx_front.set(cx + math.cos(a) * 17.0, cy - 24.0 + math.sin(a) * 9.0, "ice" if k % 2 == 0 else "gold", protect=True)

    if ctx.is_tell and u > 0.35:
        gx = hx + (9.0 if d == "side" else 0.0)
        fx_front.star4(gx, hy - 5.0, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8.0, cy - 22.0, 19.0, 14.0, -72, 72, 5.5, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 16.0, 22.0, 11.0, 12, 168, 5.2, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 11.0, 9.5, 3.0, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="thread_keeper", name="The Thread-Keeper", out_dir=ART_BOSSES,
    frame=(72, 74), anchor=(36, 60),
    body_radius=10.5, hit_radius=14.0, body_centre=(36, 38),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_thread_keeper,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
