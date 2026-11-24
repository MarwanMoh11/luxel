#!/usr/bin/env python3
"""Island 2 Superboss: The Undertow (abyssal maelstrom kraken-vortex with 4 swirl-arms & sea-glass fangs) — 96x88, anchor [48, 68]."""
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

ABYSS = ("void", "night", "deep", "blue")
SWIRL = ("deep", "blue", "sky", "ice")
FANG = ("apricot", "gold", "cream")
P2_VORTEX = ("night", "wine", "coral", "gold")


def draw_undertow(ctx: FrameCtx) -> Image.Image:
    w, h = 96, 88
    ax, ay = 48.0, 68.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    spin = ph * (1.2 if p2 else 0.85)
    hover = math.sin(ph) * 2.0
    arm_reach = 26.0
    eye_scale = 1.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        arm_reach = 21.0 - 4.0 * u
        eye_scale = 1.0 + 0.35 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        arm_reach = 26.0 + 7.0 * sm
        eye_scale = 1.25
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        arm_reach = 22.0
        eye_scale = 0.82
    elif ctx.is_stagger:
        arm_reach = 19.0
        eye_scale = 0.70

    cx = ax
    cy = ay - 22.0 + hover
    shadow.contact_shadow(ax, ay + 3.0, 26.0, 4.4, "void")

    # Concentric outer abyssal vortex rings on fx_back
    fx_back.ring(cx, cy + 4, 29.0, "deep", 2.0, 0, 360, protect=True)
    fx_back.ring(cx, cy + 4, 24.0, "coral" if p2 else "blue", 1.5, 0, 360, protect=True)
    fx_back.ring(cx, cy + 4, 19.0, "sky" if not p2 else "gold", 1.1, 0, 360, protect=True)

    vortex = PixelBuf(w, h)

    # 4 swirling abyssal kraken-vortex arms spiraling out from the maelstrom core!
    arm_ramp = P2_VORTEX if (p2 and ctx.is_commit) else SWIRL
    for k in range(4):
        base_a = spin + k * (math.tau / 4.0)
        if d == "side":
            base_a += 0.35
        x_scale = 0.86 if d == "side" else 1.0
        p0 = (cx + math.cos(base_a) * 9.5 * x_scale, cy + math.sin(base_a) * 8.5)
        p1 = (cx + math.cos(base_a + 0.52) * (arm_reach * 0.84) * x_scale, cy + math.sin(base_a + 0.52) * (arm_reach * 0.66))
        p2_pt = (cx + math.cos(base_a + 1.02) * (arm_reach + 3.5) * x_scale, cy + math.sin(base_a + 1.02) * ((arm_reach + 3.5) * 0.78))
        vortex.bezier_limb(p0, p1, p2_pt, 5.4, 1.8, arm_ramp, tip_col="cream" if (p2 or ctx.is_commit) else "ice")
        # Brass suction-ring barnacle band on each swirl arm
        vortex.circle(p1[0], p1[1], 2.4, "gold", protect=True)
        vortex.set(p1[0], p1[1], "cream", protect=True)

    # Deep abyssal maelstrom body funnel
    vortex.shaded_ellipse(cx, cy, 17.5 if d != "side" else 15.0, 16.0, ABYSS)
    vortex.shaded_ellipse(cx, cy - 1, 13.0 if d != "side" else 11.5, 11.5, SWIRL)
    vortex.ellipse(cx, cy, 9.5 * eye_scale, 8.5 * eye_scale, "void")

    # Sea-glass gold/cream fangs ringing the abyssal maw!
    fang_n = 8
    for i in range(fang_n):
        fa = -spin * 0.5 + i * (math.tau / fang_n)
        fx_i = cx + math.cos(fa) * (11.5 if d != "side" else 9.8)
        fy_i = cy + math.sin(fa) * 10.5
        tx_i = cx + math.cos(fa) * 6.5
        ty_i = cy + math.sin(fa) * 6.0
        vortex.capsule(fx_i, fy_i, tx_i, ty_i, 1.5, 0.7, FANG)

    if d != "back":
        # Piercing sea-glass maelstrom eye!
        ex = cx + (3.5 if d == "side" else 0.0)
        ey = cy - 0.5
        vortex.circle(ex, ey, 5.2 * eye_scale, "coral" if (p2 or ctx.is_tell) else "gold", protect=True)
        vortex.circle(ex, ey, 3.4 * eye_scale, "cream", protect=True)
        # Vertical slit abyssal pupil
        vortex.shaded_rect(ex - 1.0, ey - 3.5 * eye_scale, 2, int(round(7.0 * eye_scale)), ("void", "void"))
        vortex.set(ex - 1.5, ey - 2.0, "cream", protect=True)
    else:
        # Back view: swirling abyssal shell crest & brass tide-compass crown
        vortex.shaded_ellipse(cx, cy - 2, 10.5, 9.0, ABYSS)
        vortex.ring(cx, cy - 2, 6.5, "gold", 1.4, 0, 360, protect=True)
        vortex.circle(cx, cy - 2, 2.5, "ice", protect=True)

    if p2:
        vortex.crack(cx - 10, cy - 8, cx + 8, cy + 7, "void", "coral", seed=53)
        vortex.crack(cx + 9, cy - 9, cx - 7, cy + 6, "void", "ice", seed=59)

    body.composite(rotate_buf(vortex, cx, cy, math.sin(lph) * 5.0))

    # Maelstrom spray motes & attack telegraphs
    for k in range(5):
        a = -ph * 1.4 + k * (math.tau / 5.0)
        fx_front.star4(cx + math.cos(a) * 27, cy + math.sin(a) * 20, 1, "cream", "ice" if not p2 else "gold")
    if ctx.is_tell and u > 0.30:
        fx_front.ring(cx, cy, 12.0 + (1.0 - u) * 14.0, "coral" if p2 else "gold", 1.3, 0, 360, protect=True)
        fx_front.star4(cx, cy, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx, cy, 28, 22, -40, 210, 6.4, ("blue", "sky", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 26, 15.0, 4.0, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="undertow", name="The Undertow", out_dir=ART_BOSSES,
    frame=(96, 88), anchor=(48, 68),
    body_radius=14.0, hit_radius=18.0, body_centre=(48, 46),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="void",
    draw_frame=draw_undertow,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
