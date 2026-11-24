#!/usr/bin/env python3
"""Island 8 Mini-Boss: The Rose-Window Seraph (6-winged stained-glass cathedral rose-window frame) — 104x96, anchor [52, 78]."""
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

LEAD = ("void", "night", "dusk", "mauve")
GOLD_GLASS = ("wine", "apricot", "gold", "cream")
SKY_GLASS = ("deep", "blue", "sky", "ice")
ROSE_GLASS = ("plum", "wine", "rose", "cream")
VEIL = ("dusk", "mauve", "stone", "cream")


def _draw_wing_pair(buf: PixelBuf, cx: float, cy: float, side: float, tier: int, angle_off: float, ramp: tuple[str, ...], d: str) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Gothic pointed lancet stained-glass wing framed in dark lead came
    base_y = cy - 22.0 + tier * 7.5
    base_x = cx + (side * 8.0 if d != "side" else -4.0)
    span = (26.0 - tier * 3.0) if d != "side" else (22.0 - tier * 2.5)
    sgn = side if d != "side" else -1.0
    tip_x = base_x + sgn * span
    tip_y = base_y - (10.0 - tier * 7.5)
    # Outer lead frame
    pts = [
        (base_x, base_y - 3.5),
        (base_x + sgn * span * 0.55, (base_y + tip_y) * 0.5 - 4.5),
        (tip_x, tip_y),
        (base_x + sgn * span * 0.62, (base_y + tip_y) * 0.5 + 3.5),
        (base_x, base_y + 3.5),
    ]
    tmp.shaded_poly(pts, ramp)
    # Crisp gothic lead-came ribs inside wing
    mid_x = (base_x + tip_x) * 0.5
    mid_y = (base_y + tip_y) * 0.5
    tmp.line(base_x, base_y, tip_x, tip_y, "night")
    tmp.line(mid_x - sgn * 2, mid_y - 3, mid_x + sgn * 2, mid_y + 3, "night")
    tmp.circle(base_x + sgn * span * 0.72, tip_y + (base_y - tip_y) * 0.28, 1.5, "cream", protect=True)
    deg = angle_off * (side if d != "side" else -1.0)
    buf.composite(rotate_buf(tmp, base_x, base_y, deg))


def _draw_rose_halo(buf: PixelBuf, hx: float, hy: float, spin: float, d: str, p2: bool, cracked: bool) -> None:
    rx = 16.0 if d != "side" else 9.0
    ry = 16.0
    # Outer dark lead wheel
    buf.shaded_ellipse(hx, hy, rx, ry, LEAD)
    # 12 alternating stained-glass petals (gold / sky / rose)
    petal_cols = ("gold", "sky", "rose")
    for k in range(12):
        a = spin + k * (math.tau / 12.0)
        col = petal_cols[k % 3]
        px_p = hx + math.cos(a) * (rx * 0.68)
        py_p = hy + math.sin(a) * (ry * 0.68)
        buf.circle(px_p, py_p, 2.7 if d != "side" else 2.1, col, protect=True)
        # Lead spoke
        buf.line(hx, hy, hx + math.cos(a) * rx, hy + math.sin(a) * ry, "night")
    # Inner golden lead ring
    buf.ring(hx, hy, rx * 0.45 if d != "side" else 6.0, "gold" if not p2 else "cream", 1.3, protect=True)
    if cracked:
        buf.crack(hx - 8, hy - 10, hx + 8, hy + 8, "void", "cream", seed=17)


def draw_rose_seraph(ctx: FrameCtx) -> Image.Image:
    w, h = 104, 96
    ax, ay = 52.0, 78.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.8 if ctx.anim in ("routine", "phase2") else 0.0
    wing_flap = math.sin(lph) * 7.5
    halo_spin = ph * (0.5 if p2 else 0.25)
    lean = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = 3.5 * u
        wing_flap = -22.0 * u
        halo_spin += u * 1.4
        sx, sy = 0.93, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.4) * math.pi)
        lean = 5.5 * sm
        wing_flap = 26.0 * sm
        halo_spin += sm * 2.2
        sx, sy = 1.11, 0.91
    elif ctx.is_recover:
        hover = -2.2
        wing_flap = 10.0
    elif ctx.is_stagger:
        hover = -4.5
        wing_flap = 22.0 + math.sin(ph * 2.0) * 8.0
        lean = math.sin(ph * 2.0) * 2.8

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 14.0 - hover
    shadow.contact_shadow(ax, ay + 2.0, 15.0, 2.5, "night")

    # 3 pairs of stained-glass lancet wings (gold, sky, rose)
    wing_ramps = (GOLD_GLASS, SKY_GLASS, ROSE_GLASS)
    if d != "side":
        for tier in range(3):
            _draw_wing_pair(body, cx, cy, -1.0, tier, wing_flap + tier * 3.0, wing_ramps[tier], d)
            _draw_wing_pair(body, cx, cy, 1.0, tier, wing_flap + tier * 3.0, wing_ramps[tier], d)
    else:
        for tier in range(3):
            _draw_wing_pair(fx_back, cx + 4.0, cy - 1.5, -1.0, tier, wing_flap * 0.7 + tier * 3.0, wing_ramps[tier], d)
            _draw_wing_pair(body, cx, cy, -1.0, tier, wing_flap + tier * 4.0, wing_ramps[tier], d)

    # Iconic Gothic Rose-Window Halo behind veiled torso
    _draw_rose_halo(body, cx + (-2.0 if d == "side" else 0.0), cy - 28.0, halo_spin, d, p2, ctx.is_stagger)

    # Slender leaded cathedral-glass vestment & hanging stained sash
    sway = math.sin(lph) * 2.4
    vest_ramp = ("void", "night", "dusk", "plum") if d == "back" else VEIL
    body.shaded_poly([
        (cx - 7, cy - 22), (cx + 7, cy - 22),
        (cx + 10 + sway * 0.4, cy + 4), (cx + sway, cy + 12),
        (cx - 10 + sway * 0.4, cy + 4),
    ], vest_ramp)
    if d == "back":
        # Back view: dark plum velvet backing with gilded cathedral spire seam
        body.line(cx, cy - 21, cx + sway * 0.5, cy + 10, "gold")
        body.line(cx - 5, cy - 12, cx + 5, cy - 12, "gold")
        body.circle(cx, cy - 12, 2.2, "rose" if p2 else "gold", protect=True)
    else:
        # Front/Side view: glowing leaded stained diamond chest pane
        body.shaded_poly([
            (cx, cy - 20), (cx + 5, cy - 12), (cx, cy - 3), (cx - 5, cy - 12),
        ], ROSE_GLASS if p2 else SKY_GLASS)
        body.line(cx, cy - 20, cx, cy - 3, "night")
        body.line(cx - 5, cy - 12, cx + 5, cy - 12, "night")

    # Serene Veiled Seraph Core inside the Rose Window
    hx = cx + (3.0 if d == "side" else 0.0)
    hy = cy - 28.0
    body.shaded_ellipse(hx, hy, 6.2 if d != "side" else 5.5, 7.2, VEIL)
    if d == "front":
        # Single luminous vertical diamond glass eye
        body.shaded_poly([(hx, hy - 3.2), (hx + 3.2, hy), (hx, hy + 3.2), (hx - 3.2, hy)], GOLD_GLASS)
        body.rect(hx - 1, hy - 1, 2, 2, "cream", protect=True)
        body.set(hx, hy, "void", protect=True)
    elif d == "side":
        body.shaded_poly([(hx + 2.5, hy - 3.0), (hx + 5.2, hy), (hx + 2.5, hy + 3.0), (hx + 0.5, hy)], GOLD_GLASS)
        body.rect(hx + 2.5, hy - 1, 2, 2, "cream", protect=True)
    else:
        body.line(hx, hy - 6, hx, hy + 6, "night")
        body.line(hx - 5, hy, hx + 5, hy, "night")

    if p2:
        # Orbiting tri-colour stained-glass diamonds
        for k in range(3):
            a = ph * 1.4 + k * (math.tau / 3.0)
            dx = cx + math.cos(a) * 26.0
            dy = cy - 20.0 + math.sin(a) * 12.0
            col = ("gold", "sky", "rose")[k]
            fx_front.star4(dx, dy, 2, "cream", col)

    if ctx.is_tell and u > 0.25:
        fx_front.ring(cx, cy - 24, 24.0 - u * 7.0, "rose" if p2 else "gold", 1.3, protect=True)
        fx_front.ring(cx, cy - 24, 18.0 - u * 4.0, "sky", 1.0, protect=True)
        fx_front.star4(hx + (5 if d == "side" else 0), hy, 3 if u > 0.65 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 9, cy - 18, 22, 18, -75, 75, 5.8, ("rose", "gold", "cream"))
            fx_front.slash_arc(cx + 11, cy - 16, 17, 13, -65, 65, 4.2, ("sky", "ice", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 16, 30, 16, 0, 180, 5.5, ("rose", "gold", "cream"))
            fx_front.slash_arc(cx, cy - 20, 26, 14, 180, 360, 4.0, ("sky", "ice", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 14, 12.0, 3.5, ph)
        # Falling glass shards
        for k in range(4):
            sx_p = cx + (-16 + k * 11)
            sy_p = cy - 6 + ((k * 5 + ctx.fi * 3) % 14)
            fx_front.rect(sx_p, sy_p, 2, 3, ("gold", "sky", "rose", "cream")[k], protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="rose_seraph", name="Rose-Window Seraph", out_dir=ART_BOSSES,
    frame=(104, 96), anchor=(52, 78),
    body_radius=12.0, hit_radius=16.0, body_centre=(52, 46),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="night",
    draw_frame=draw_rose_seraph,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
