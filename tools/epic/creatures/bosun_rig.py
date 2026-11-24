#!/usr/bin/env python3
"""Island 2 Mini-Boss A: The Bosun's Rig (timber crane-gantry anchor-drowned bosun) — 84x80, anchor [42, 64]."""
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

HUSK = ("void", "night", "pine", "teal")
KELP = ("night", "pine", "teal", "jade")
GANTRY = ("void", "night", "plum", "wine")
BRASS = ("plum", "coral", "apricot", "gold")
IRON = ("night", "deep", "blue", "sky")
HOT_IRON = ("wine", "coral", "apricot", "gold")


def _draw_crane_hook(buf: PixelBuf, cx: float, cy: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ramp = HOT_IRON if hot else IRON
    # Pulley block
    tmp.shaded_rect(cx - 4, cy - 8, 8, 6, BRASS)
    tmp.circle(cx, cy - 5, 1.8, "void")
    tmp.set(cx, cy - 5, "cream", protect=True)
    # Heavy iron cargo hook / anchor claw
    tmp.bezier_limb((cx, cy - 2), (cx + 7, cy + 4), (cx + 2, cy + 10), 2.3, 1.6, ramp, tip_col="cream" if hot else "ice")
    tmp.bezier_limb((cx + 2, cy + 10), (cx - 5, cy + 9), (cx - 6, cy + 4), 1.8, 1.0, ramp, tip_col="cream" if hot else "ice")
    buf.composite(rotate_buf(tmp, cx, cy, ang_deg))


def draw_bosun_rig(ctx: FrameCtx) -> Image.Image:
    w, h = 92, 84
    ax, ay = 46.0, 67.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = abs(math.sin(ph)) * 1.6 if ctx.anim in ("routine", "phase2") else 0.0
    step = math.sin(ph) * 2.8 if ctx.anim in ("routine", "phase2") else 0.0
    lag_sw = math.sin(lph) * 4.5
    boom_ang = math.sin(lph) * 6.0
    hook_ox = 22.0 + lag_sw * 0.4
    hook_oy = -20.0
    hook_ang = lag_sw * 3.0
    lean = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -3.5 * u
        boom_ang = -22.0 * u
        hook_ox = (16.0 - 10.0 * u) if d == "side" else 22.0
        hook_oy = -34.0 - 5.0 * u
        hook_ang = -45.0 * u
        sx, sy = 0.95, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 6.0 * sm
        boom_ang = 26.0 * sm
        hook_ox = 25.0 * sm if d == "side" else (-18.0 + 38.0 * u)
        hook_oy = -10.0 + 4.0 * sm
        hook_ang = 72.0 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        lean = 4.0
        boom_ang = 14.0
        hook_ox, hook_oy, hook_ang = 19.0, -7.0, 38.0
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.0) * 3.0
        boom_ang = -16.0 + math.sin(ph * 2.0) * 8.0
        hook_ox, hook_oy, hook_ang = 16.0, -14.0, 54.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob
    shadow.contact_shadow(ax, ay + 2.0, 18.0, 2.6, "night")

    # Timber crane gantry jib bolted to shoulders (iconic silhouette!)
    gantry = PixelBuf(w, h)
    if d == "side":
        # Vertical crane mast behind shoulders + forward angled jib boom
        gantry.capsule(cx - 11, cy - 16, cx - 11, cy - 46, 3.2, 2.8, GANTRY)
        gantry.capsule(cx - 12, cy - 44, cx + 19, cy - 49, 2.8, 2.2, GANTRY)
        gantry.line(cx - 9, cy - 28, cx + 8, cy - 45, "wine")
        gantry.circle(cx + 18, cy - 48, 3.5, "gold")
        gantry.circle(cx + 18, cy - 48, 1.6, "night")
        # Counterweight iron block at rear
        gantry.shaded_rect(cx - 21, cy - 46, 8, 9, IRON)
        gantry.line(cx - 20, cy - 45, cx - 14, cy - 45, "sky")
    else:
        # Twin shoulder timber A-frame + overhead crossbeam gantry!
        gantry.capsule(cx - 17, cy - 20, cx - 15, cy - 47, 3.0, 2.6, GANTRY)
        gantry.capsule(cx + 17, cy - 20, cx + 15, cy - 47, 3.0, 2.6, GANTRY)
        gantry.capsule(cx - 21, cy - 47, cx + 23, cy - 47, 2.8, 2.8, GANTRY)
        gantry.line(cx - 16, cy - 34, cx + 16, cy - 46, "wine")
        gantry.circle(cx + 21, cy - 47, 3.4, "gold")
        gantry.circle(cx + 21, cy - 47, 1.5, "night")
        # Rear counterweight barrel on left beam
        gantry.shaded_rect(cx - 24, cy - 46, 7, 8, IRON)

    if p2:
        gantry.crack(cx - 14, cy - 46, cx + 4, cy - 47, "void", "coral", seed=7)
    body.composite(rotate_buf(gantry, cx, cy - 28, boom_ang * 0.55))

    # Heavy braced sea boots
    if d == "side":
        body.shaded_ellipse(cx - 7.0 + step, ay - 2.0, 6.2, 3.4, ("void", "night", "pine"))
        body.shaded_ellipse(cx + 7.0 - step, ay - 1.5, 6.6, 3.5, ("void", "night", "pine"))
    else:
        body.shaded_ellipse(cx - 9.5, ay - 2.0 + step * 0.4, 5.4, 3.4, ("void", "night", "pine"))
        body.shaded_ellipse(cx + 9.5, ay - 2.0 - step * 0.4, 5.4, 3.4, ("void", "night", "pine"))

    # Massive brine-husk naval coat torso + rope harness
    body.shaded_ellipse(cx, cy - 17.0, 15.5 if d != "side" else 13.5, 14.5, HUSK)
    body.shaded_dome(cx, cy - 23.0, 15.0 if d != "side" else 13.0, 8.2, KELP, bottom_cut=0.25)
    # Crossed leather & brass crane harness straps
    body.line(cx - 11, cy - 27, cx + 11, cy - 9, "apricot")
    body.line(cx + 11, cy - 27, cx - 11, cy - 9, "apricot")
    body.shaded_rect(cx - 3, cy - 19, 6, 5, BRASS)

    # Bosun head + naval bicorne hat
    hx = cx + (4.5 if d == "side" else 0.0)
    hy = cy - 31.0
    body.shaded_ellipse(hx, hy, 8.0, 6.8, HUSK)
    # Iconic naval bicorne hat with gold trim!
    hat_y = hy - 5.5
    body.shaded_poly([
        (hx - 13, hat_y + 2), (hx - 6, hat_y - 6), (hx, hat_y - 8),
        (hx + 6, hat_y - 6), (hx + 13, hat_y + 2), (hx, hat_y + 4),
    ], ("void", "night", "dusk", "plum"))
    body.line(hx - 11, hat_y + 1, hx, hat_y - 6, "gold")
    body.line(hx + 11, hat_y + 1, hx, hat_y - 6, "gold")
    body.circle(hx, hat_y - 2, 2.0, "gold", protect=True)

    if d == "front":
        body.ellipse(hx, hy + 1.0, 5.4, 3.6, "void")
        body.eye(hx - 3.6, hy - 0.5, "sky" if not p2 else "coral", "cream", "void", 2, 2)
        body.eye(hx + 1.6, hy - 0.5, "sky" if not p2 else "coral", "cream", "void", 2, 2)
        # Gleaming gold bosun's whistle on chest lanyard!
        body.line(hx - 2, hy + 5, cx, cy - 21, "gold")
        body.line(hx + 2, hy + 5, cx, cy - 21, "gold")
        body.shaded_ellipse(cx, cy - 21, 3.2, 2.0, BRASS)
        body.set(cx + 1, cy - 21, "cream", protect=True)
    elif d == "side":
        body.ellipse(hx + 3.0, hy + 1.0, 3.8, 3.4, "void")
        body.eye(hx + 3.2, hy - 0.5, "sky" if not p2 else "coral", "cream", "void", 2, 2)
        # Bosun whistle held at lip/chest
        body.capsule(hx + 5, hy + 3, hx + 11, hy + 4, 1.4, 1.0, BRASS)
        body.set(hx + 10, hy + 3, "cream", protect=True)
    else:
        # Back view: heavy iron winch drum strapped to spine
        body.shaded_ellipse(cx, cy - 18.0, 7.5, 6.0, IRON)
        body.line(cx - 5, cy - 18, cx + 5, cy - 18, "gold")

    # Crane chain + swinging heavy cargo hook!
    pulley_p = (cx + (18.0 if d == "side" else 20.0), cy - 45.0)
    hook_p = (cx + hook_ox, cy + hook_oy)
    body.chain(pulley_p, hook_p, sag=3.5 + lag_sw * 0.3, link_col="blue", hi_col="sky", dark_col="night", links=5)
    _draw_crane_hook(body, hook_p[0], hook_p[1], hook_ang, hot=(p2 or ctx.is_tell or ctx.is_commit))

    if p2:
        body.crack(cx - 6, cy - 22, cx + 5, cy - 10, "void", "coral", seed=19)
        for k in range(4):
            a = ph + k * (math.tau / 4.0)
            fx_front.star4(cx + math.cos(a) * 23, cy - 24 + math.sin(a) * 14, 1, "cream", "gold")

    if ctx.is_tell and u > 0.3:
        fx_front.star4(hook_p[0], hook_p[1] - 4, 3 if u > 0.7 else 2, "cream", "gold")
        fx_front.ring(hx + (9 if d == "side" else 0), hy + 3, 4.0 + u * 4.5, "gold", 1.0, 0, 360, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 14, 24, 16, -65, 72, 6.2, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 12, 26, 14, -15, 195, 6.0, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 14, 11.0, 3.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="bosun_rig", name="The Bosun's Rig", out_dir=ART_BOSSES,
    frame=(92, 84), anchor=(46, 67),
    body_radius=12.0, hit_radius=16.0, body_centre=(46, 45),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="pine",
    draw_frame=draw_bosun_rig,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
