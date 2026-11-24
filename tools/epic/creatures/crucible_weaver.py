#!/usr/bin/env python3
"""Island 6 Great Kiln Mini-Boss #2: The Crucible Weaver (6-legged brass glassblower spider with molten apricot-gold glass-bulb abdomen, blowpipe fangs, and gleaming ice-sky mirror facets; stagger flips legs up like an overturned teacup!) — 92x82, anchor [46, 66]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame,
)

BRASS = ("night", "dusk", "apricot", "gold")
IRON = ("void", "night", "dusk", "mauve")
MOLTEN = ("wine", "coral", "apricot", "gold")
FROZEN = ("deep", "blue", "sky", "ice")


def draw_crucible_weaver(ctx: FrameCtx) -> Image.Image:
    w, h = 98, 86
    ax, ay = 49.0, 68.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2
    frozen = ctx.is_stagger

    bob = math.sin(ph * 2.0) * 1.4 if ctx.anim in ("routine", "phase2") else 0.0
    crouch = 0.0
    lean = 0.0
    bulb_scale = 1.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Inflates glowing glass-bulb abdomen before blowing mirror/thread!
        crouch = 3.0 * u
        bulb_scale = 1.0 + 0.22 * u
        sx, sy = 1.06, 0.95
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 5.0 * sm
        bulb_scale = 1.0 - 0.14 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        crouch = 3.2
    elif frozen:
        # Comedy overturned teacup! Legs lock straight up, frozen icy glass shell!
        crouch = 5.5
        sx, sy = 1.04, 0.94

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 18.0 - bob + crouch
    shadow.contact_shadow(ax, ay + 2.0, 21.0, 3.0, "night")

    leg_ramp = FROZEN if frozen else BRASS
    bulb_ramp = FROZEN if frozen else MOLTEN

    # 6 articulated brass spider legs (flip straight UP like an overturned teacup in stagger!)
    for side_s in (-1, 1):
        for li in range(3):
            phase_off = ph + li * 1.9 + (0.0 if side_s < 0 else math.pi)
            stride = math.sin(phase_off) * 3.0 if ctx.anim in ("routine", "phase2") else 0.0
            lift = max(0.0, math.cos(phase_off)) * 3.5 if ctx.anim in ("routine", "phase2") else 0.0
            base_x = cx + (side_s * (6 + li * 2) if d != "side" else (-6 + li * 6))
            base_y = cy + (-3 + li * 2)
            if frozen:
                # Overturned teacup: all 6 legs stiffly pointing upward!
                knee_x = base_x + side_s * (14 + li * 3)
                knee_y = base_y - 16 - li * 2
                foot_x = base_x + side_s * (19 + li * 2)
                foot_y = base_y - 28 + li * 2
            else:
                spread_x = (17 + li * 4) * side_s if d != "side" else (-18 + li * 16 + side_s * 6)
                knee_x = base_x + spread_x * 0.65 + stride * 0.5
                knee_y = base_y - 13.0 - lift * 0.5
                foot_x = base_x + spread_x + stride
                foot_y = ay - 1.0 - lift
            body.bezier_limb((base_x, base_y), (knee_x, knee_y), (foot_x, foot_y), 2.3, 1.1, leg_ramp, tip_col="ice" if frozen else "gold")
            # Knee brass rivet
            body.circle(knee_x, knee_y, 1.8, "ice" if frozen else "gold", protect=True)

    # Molten GLASS-BULB ABDOMEN (rear on side/front, huge glowing centerpiece on back!)
    ab_rx = 14.5 * bulb_scale
    ab_ry = 12.5 * bulb_scale
    if d == "side":
        ab_x, ab_y = cx - 10.0, cy - 8.0
    elif d == "back":
        ab_x, ab_y = cx, cy - 9.0
    else:
        ab_x, ab_y = cx, cy - 15.0

    body.shaded_ellipse(ab_x, ab_y, ab_rx, ab_ry, bulb_ramp, spec_col="cream")
    # Brass filigree cage bands hugging the blown glass bulb
    body.ring(ab_x, ab_y, ab_rx * 0.88, "dusk" if not frozen else "sky", 1.2, 15, 165)
    body.line(ab_x - ab_rx + 3, ab_y, ab_x + ab_rx - 3, ab_y, "gold" if not frozen else "ice")
    # Faceted mirror glint panel on bulb
    body.shaded_poly([
        (ab_x - 4, ab_y - 6), (ab_x + 4, ab_y - 6),
        (ab_x + 6, ab_y), (ab_x, ab_y + 4), (ab_x - 6, ab_y),
    ], FROZEN)
    body.set(ab_x - 2, ab_y - 4, "cream", protect=True)
    body.set(ab_x - 1, ab_y - 3, "cream", protect=True)

    # Brass thorax & head with BLOWPIPE FANGS
    hx = cx + (11.0 if d == "side" else 0.0)
    hy = cy + (2.0 if d == "front" else (-2.0 if d == "side" else 4.0))
    body.shaded_ellipse(hx, hy, 10.0 if d != "side" else 8.5, 8.0, IRON)
    body.line(hx - 7, hy - 4, hx + 7, hy - 4, "gold")

    if d == "front":
        # Four faceted spider-lens eyes!
        ec = "ice" if frozen else ("cream" if p2 else "sky")
        body.eye(hx - 4.5, hy - 2.0, ec, "cream", "void", 2, 2)
        body.eye(hx + 2.5, hy - 2.0, ec, "cream", "void", 2, 2)
        body.eye(hx - 2.0, hy - 4.5, "gold" if not frozen else "ice", "cream", "void", 2, 1)
        body.eye(hx + 1.0, hy - 4.5, "gold" if not frozen else "ice", "cream", "void", 2, 1)
        # Twin brass blowpipe fangs!
        body.capsule(hx - 4, hy + 4, hx - 6, hy + 11, 2.0, 1.2, BRASS)
        body.capsule(hx + 4, hy + 4, hx + 6, hy + 11, 2.0, 1.2, BRASS)
        if ctx.is_tell:
            # Inflating glowing glass mirror bubble between blowpipe fangs!
            br = 3.0 + 4.0 * u
            body.circle(hx, hy + 11, br, "sky", protect=True)
            body.circle(hx, hy + 11, br * 0.6, "ice", protect=True)
            body.set(hx - 1, hy + 10, "cream", protect=True)
    elif d == "side":
        ec = "ice" if frozen else ("cream" if p2 else "sky")
        body.eye(hx + 4.5, hy - 2.0, ec, "cream", "void", 2, 2)
        body.eye(hx + 2.5, hy - 4.5, "gold" if not frozen else "ice", "cream", "void", 2, 1)
        body.capsule(hx + 5, hy + 2, hx + 13, hy + 6, 2.0, 1.1, BRASS)
        if ctx.is_tell:
            br = 3.0 + 4.0 * u
            body.circle(hx + 15, hy + 7, br, "sky", protect=True)
            body.circle(hx + 15, hy + 7, br * 0.6, "ice", protect=True)
            body.set(hx + 14, hy + 6, "cream", protect=True)

    # Phase 2 molten glass loom aura
    if p2:
        body.crack(ab_x - 6, ab_y - 5, ab_x + 7, ab_y + 6, "void", "cream", seed=53)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 24, cy - 8 + math.sin(a) * 11, "sky" if k % 2 == 0 else "gold", protect=True)

    # FX overlays
    if ctx.is_tell and u > 0.35:
        fx_front.star4(hx + (14 if d == "side" else 0), hy + (7 if d == "side" else 11), 3 if u > 0.7 else 2, "cream", "sky")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(hx + 10, hy + 2, 20, 14, -70, 70, 5.2, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy + 4, 26, 13, 10, 170, 5.2, ("coral", "apricot", "cream"))
    elif frozen:
        # Frosted glassy clink sparkles + dizzy stars
        fx_front.star4(ab_x - 9, ab_y - 7, 2, "cream", "ice")
        fx_front.star4(ab_x + 10, ab_y - 3, 2, "cream", "sky")
        fx_front.dizzy_stars(cx, cy - 26, 12.0, 3.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=frozen, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="crucible_weaver", name="The Crucible Weaver", out_dir=ART_BOSSES,
    frame=(98, 86), anchor=(49, 68),
    body_radius=11.5, hit_radius=17.5, body_centre=(49, 48),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_crucible_weaver,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6b")
