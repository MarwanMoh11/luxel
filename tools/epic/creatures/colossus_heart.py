#!/usr/bin/env python3
"""Island 6 Iron Colossus Boss: The Colossus Heart (suspended clockwork furnace-heart ringed by 4 brass pistons, glowing coral-gold glass aorta tubes, heavy iron tether chain) — 96x92, anchor [48, 72]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, RAMPS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame,
)

IRON = ("void", "night", "dusk", "mauve")
BRASS = ("plum", "coral", "apricot", "gold")
GLASS = ("wine", "coral", "apricot", "gold")
ICE_CORE = ("deep", "blue", "sky", "ice")


def draw_colossus_heart(ctx: FrameCtx) -> Image.Image:
    w, h = 104, 100
    ax, ay = 52.0, 78.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    # Heartbeat lub-dub pulse
    beat = math.pow(max(0.0, math.sin(ph)), 3.0)
    hover = math.sin(ph) * 2.2
    swing_x = 0.0
    sx, sy = 1.0 + beat * 0.05, 1.0 - beat * 0.04
    cage_open = p2 or ctx.is_stagger or ctx.is_recover

    if ctx.is_tell:
        # Contracts tight with cream-gold lub-dub anticipation
        sx, sy = 1.0 - 0.12 * u, 1.0 + 0.10 * u
        swing_x = -4.0 * u if d == "side" else 0.0
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.4) * math.pi)
        sx, sy = 1.0 + 0.14 * sm, 1.0 - 0.10 * sm
        swing_x = 8.0 * sm if d == "side" else math.sin(u * math.pi * 2.0) * 6.0
    elif ctx.is_recover:
        sx, sy = 1.03, 0.96
    elif ctx.is_stagger:
        # Bonked into frozen slime — tilted off-axis with icy frost cracks!
        swing_x = math.sin(ph * 2.0) * 4.5
        sx, sy = 0.94, 1.06

    cx = ax + swing_x
    cy = ay - 30.0 - hover
    shadow.contact_shadow(ax + swing_x * 0.5, ay + 2.0, 20.0, 3.2, "night")

    # Overhead heavy brass suspension chain links rising to crown shackle
    body.chain((ax, 10.0), (cx, cy - 23.0), sag=2.0 if not p2 else 4.0, link_col="stone", hi_col="gold", dark_col="night", links=5)
    body.shaded_rect(cx - 7, cy - 27, 14, 6, BRASS)

    # Twin curved glowing glass AORTA TUBES arching from top valves to lower chamber
    tube_ramp = ICE_CORE if ctx.is_stagger else GLASS
    if d != "side":
        body.bezier_limb((cx - 8, cy - 20), (cx - 26, cy - 16), (cx - 18, cy + 8), 3.6, 2.8, tube_ramp)
        body.bezier_limb((cx + 8, cy - 20), (cx + 26, cy - 16), (cx + 18, cy + 8), 3.6, 2.8, tube_ramp)
    else:
        body.bezier_limb((cx - 4, cy - 20), (cx - 22, cy - 12), (cx - 12, cy + 10), 3.8, 2.8, tube_ramp)
        body.bezier_limb((cx + 6, cy - 20), (cx + 22, cy - 10), (cx + 12, cy + 10), 3.4, 2.6, tube_ramp)

    # 4 Brass radial piston valves ringing the furnace-heart!
    piston_ext = 3.5 if ctx.is_commit else (1.5 * beat)
    for k in range(4):
        ang = (math.pi * 0.25) + k * (math.pi * 0.5)
        px0 = cx + math.cos(ang) * 14.0
        py0 = cy + math.sin(ang) * 14.0
        px1 = cx + math.cos(ang) * (22.0 + piston_ext)
        py1 = cy + math.sin(ang) * (22.0 + piston_ext)
        body.capsule(px0, py0, px1, py1, 3.2, 2.6, BRASS)
        body.circle(px1, py1, 3.0, "gold" if not ctx.is_stagger else "ice", protect=True)
        body.set(px1, py1, "cream", protect=True)

    # Outer ribbed foundry heart vessel (tapered organic-mechanical silhouette)
    rx = 18.0 if d != "side" else 15.5
    body.shaded_poly([
        (cx - rx, cy - 10), (cx - rx + 4, cy - 20), (cx + rx - 4, cy - 20), (cx + rx, cy - 10),
        (cx + rx - 3, cy + 8), (cx, cy + 22), (cx - rx + 3, cy + 8),
    ], IRON)
    # Brass ribcage bands
    body.line(cx - rx + 2, cy - 11, cx + rx - 2, cy - 11, "gold")
    body.line(cx - rx + 3, cy + 4, cx + rx - 3, cy + 4, "apricot")

    # Central glowing EMBER LANTERN CORE (exposed wide when cage opens in P2/recover/stagger!)
    if d != "back":
        core_r = 9.5 if cage_open else 7.5
        core_x = cx + (3.5 if d == "side" else 0.0)
        body.circle(core_x, cy - 2, core_r + 1.5, "void", protect=True)
        body.circle(core_x, cy - 2, core_r, "sky" if ctx.is_stagger else "coral", protect=True)
        body.circle(core_x, cy - 2, core_r * 0.72, "ice" if ctx.is_stagger else "apricot", protect=True)
        body.circle(core_x, cy - 2, core_r * 0.45, "cream" if (ctx.is_tell or p2 or beat > 0.5) else "gold", protect=True)
        if not cage_open:
            # P1 iron rib bars guarding core
            for bx in (-4, 0, 4):
                body.line(core_x + bx, cy - 11, core_x + bx, cy + 7, "dusk")
                body.line(core_x + bx - 1, cy - 11, core_x + bx - 1, cy + 7, "night")
        else:
            # Open rib-valves revealing the trapped lantern filament inside!
            body.line(core_x, cy - 7, core_x, cy + 3, "cream", protect=True)
            body.line(core_x - 3, cy - 2, core_x + 3, cy - 2, "cream", protect=True)
    else:
        # Back view: heavy iron spine manifold + dual steam exhausts
        body.shaded_rect(cx - 10, cy - 14, 20, 22, IRON)
        body.circle(cx - 5, cy - 4, 3.0, "coral", protect=True)
        body.circle(cx + 5, cy - 4, 3.0, "coral", protect=True)
        body.set(cx - 5, cy - 4, "gold", protect=True)
        body.set(cx + 5, cy - 4, "gold", protect=True)

    # Lower molten drip nozzle
    body.shaded_poly([(cx - 5, cy + 17), (cx + 5, cy + 17), (cx + 2, cy + 25), (cx - 2, cy + 25)], BRASS)
    body.circle(cx, cy + 25, 2.0, "gold" if not ctx.is_stagger else "ice", protect=True)

    # Phase 2 pendulum flare & glowing fissures
    if p2:
        body.crack(cx - 10, cy - 12, cx + 8, cy + 12, "void", "gold", seed=41)
        for k in range(4):
            a = ph + k * 1.57
            fx_back.ring(cx, cy, 27.0 + math.sin(ph) * 2.0, "coral", 1.2, k * 90 + 14, k * 90 + 62, protect=True)

    # FX overlays
    if ctx.is_tell:
        fx_front.ring(cx, cy - 2, 26.0 - 12.0 * u, "gold", 1.4, protect=True)
        if u > 0.4:
            fx_front.star4(cx, cy - 2, 3 if u > 0.72 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.ring(cx, cy - 2, 18.0 + ctx.fi * 4.0, "coral", 2.0, protect=True)
        fx_front.ring(cx, cy - 2, 14.0 + ctx.fi * 4.0, "cream", 1.2, protect=True)
    elif ctx.is_stagger:
        # Frosted slime-bonk burst & dizzy stars!
        fx_front.star4(cx - 12, cy - 6, 2, "cream", "ice")
        fx_front.star4(cx + 12, cy + 4, 2, "cream", "sky")
        fx_front.dizzy_stars(cx, cy - 26, 13.0, 4.0, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="colossus_heart", name="The Colossus Heart", out_dir=ART_BOSSES,
    frame=(104, 100), anchor=(52, 78),
    body_radius=13.0, hit_radius=19.0, body_centre=(52, 48),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_colossus_heart,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6b")
