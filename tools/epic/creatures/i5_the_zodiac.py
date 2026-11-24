#!/usr/bin/env python3
"""Island 5 Dungeon B Boss: The Zodiac (4 living star-wire constellations: Ram, Scales, Archer, Serpent) — 92x84, anchor [46, 66]."""
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

ASTRAL = ("void", "night", "deep", "blue")
STAR_GOLD = ("coral", "apricot", "gold", "cream")
STAR_ICE = ("deep", "blue", "sky", "ice")
BRASS = ("plum", "coral", "apricot", "gold")

ZODIAC_ANIMS = list(BOSS_ANIMS) + [
    ("phase3", True, [130.0, 130.0, 130.0, 130.0, 130.0, 130.0]),
    ("phase4", True, [120.0, 120.0, 120.0, 120.0, 120.0, 120.0]),
]


def _star_node(fx: PixelBuf, x: float, y: float, size: int = 2, col: str = "cream", halo: str = "gold") -> None:
    fx.star4(x, y, size, col, halo)


def _wire_chain(body: PixelBuf, fx: PixelBuf, pts: list[tuple[float, float]], wire_col: str = "gold", node_col: str = "cream", halo: str = "sky") -> None:
    for i in range(len(pts) - 1):
        body.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], wire_col, protect=True)
    for idx, (px, py) in enumerate(pts):
        _star_node(fx, px, py, 2 if idx % 2 == 0 else 1, node_col, halo)


def _draw_ram(body: PixelBuf, fx_back: PixelBuf, fx_front: PixelBuf, cx: float, cy: float, d: str, ph: float, lph: float, tell: bool, commit: bool, u: float) -> None:
    # Body 1: THE RAM — charging star-wire ram with huge spiral golden horns!
    lunge = (7.0 * math.sin(min(1.0, u * 1.5) * math.pi)) if commit else (-4.0 * u if tell else 0.0)
    hx = cx + (lunge if d == "side" else 0.0)
    hy = cy - 4.0 + math.sin(ph) * 2.0

    # Astral constellation cloak torso
    body.shaded_ellipse(hx - (6.0 if d == "side" else 0.0), hy + 7.0, 13.0, 9.5, ASTRAL, spec_col="sky")
    body.ring(hx - (6.0 if d == "side" else 0.0), hy + 7.0, 12.0, "gold", 1.2)
    # Charging star-wire head & monumental curling Ram horns
    if d == "side":
        head_x, head_y = hx + 11.0, hy - 2.0
        body.shaded_ellipse(head_x, head_y, 7.5, 6.2, STAR_ICE, spec_col="cream")
        # Thick sweeping spiral golden Ram horn
        horn = [
            (head_x - 2, head_y - 5), (head_x - 10, head_y - 16), (head_x + 2, head_y - 21),
            (head_x + 12, head_y - 14), (head_x + 6, head_y - 6),
        ]
        body.bezier_limb(horn[0], horn[1], horn[2], 3.4, 2.5, STAR_GOLD, protect=True)
        body.bezier_limb(horn[2], horn[3], horn[4], 2.5, 1.1, STAR_GOLD, tip_col="cream", protect=True)
        _wire_chain(body, fx_front, horn, "cream", "cream", "gold")
        # Star hooves kicking
        step = math.sin(ph) * 5.0
        body.capsule(hx + 4, hy + 12, hx + 10 + step, hy + 24, 2.2, 1.3, STAR_ICE)
        body.capsule(hx - 10, hy + 12, hx - 14 - step, hy + 24, 2.2, 1.3, STAR_ICE)
        _star_node(fx_front, hx + 10 + step, hy + 24, 2, "cream", "gold")
        body.eye(head_x + 3.0, head_y - 1.5, "gold", "cream", "void", 3, 2)
    else:
        body.shaded_ellipse(hx, hy - 2.0, 8.5, 7.5, STAR_ICE, spec_col="cream")
        for sgn in (-1.0, 1.0):
            hpts = [
                (hx + sgn * 5, hy - 7), (hx + sgn * 16, hy - 19), (hx + sgn * 24, hy - 11),
                (hx + sgn * 19, hy - 1), (hx + sgn * 13, hy - 4),
            ]
            body.bezier_limb(hpts[0], hpts[1], hpts[2], 3.4, 2.4, STAR_GOLD, protect=True)
            body.bezier_limb(hpts[2], hpts[3], hpts[4], 2.4, 1.1, STAR_GOLD, tip_col="cream", protect=True)
            _wire_chain(body, fx_front, hpts, "cream", "cream", "gold")
            step = math.sin(ph + (0.0 if sgn > 0 else math.pi)) * 3.0
            body.capsule(hx + sgn * 7, hy + 13, hx + sgn * 10, hy + 24 + step, 2.3, 1.3, STAR_ICE)
            _star_node(fx_front, hx + sgn * 10, hy + 24 + step, 2, "cream", "gold")
        if d == "front":
            body.eye(hx - 4.5, hy - 2.5, "gold", "cream", "void", 2, 2)
            body.eye(hx + 2.5, hy - 2.5, "gold", "cream", "void", 2, 2)
        else:
            _star_node(fx_front, hx, hy + 4, 4, "cream", "gold")
    fx_back.ring(hx, hy + 2, 24.0, "blue", 1.1)


def _draw_scales(body: PixelBuf, fx_back: PixelBuf, fx_front: PixelBuf, cx: float, cy: float, d: str, ph: float, lph: float) -> None:
    # Body 2: THE SCALES — celestial balance beam with glowing twin pans & fulcrum heart!
    tilt = math.sin(ph) * 6.5
    # Central ornate fulcrum pillar & glowing astral heart
    body.shaded_rect(cx - 3.5, cy - 22.0, 7.0, 44.0, BRASS)
    body.shaded_ellipse(cx, cy - 2.0, 9.0, 9.0, ASTRAL)
    body.ring(cx, cy - 2.0, 8.5, "gold", 1.5)
    _star_node(fx_front, cx, cy - 2.0, 4, "cream", "gold")
    # Star finial atop fulcrum
    _star_node(fx_front, cx, cy - 24.0, 3, "cream", "ice")

    # Tilting cross-beam & hanging twin glowing pans!
    span = 16.0 if d == "side" else 25.0
    lx, ly = cx - span, cy - 14.0 + tilt
    rx, ry = cx + span, cy - 14.0 - tilt
    body.capsule(lx, ly, rx, ry, 2.4, 2.4, STAR_GOLD)
    for px, py, col in [(lx, ly, "gold"), (rx, ry, "ice")]:
        pan_y = py + 18.0
        body.line(px, py, px - 6, pan_y, col, protect=True)
        body.line(px, py, px + 6, pan_y, col, protect=True)
        body.shaded_ellipse(px, pan_y + 2.0, 8.5, 3.8, STAR_GOLD if col == "gold" else STAR_ICE)
        _star_node(fx_front, px, pan_y - 2.0, 2, "cream", col)
    fx_back.ring(cx, cy - 2.0, 25.0, "gold", 1.2)
    if d != "back":
        body.eye(cx - 4.0, cy - 15.0, "cream", "cream", "void", 2, 2)
        body.eye(cx + 2.0, cy - 15.0, "cream", "cream", "void", 2, 2)


def _draw_archer(body: PixelBuf, fx_back: PixelBuf, fx_front: PixelBuf, cx: float, cy: float, d: str, ph: float, lph: float) -> None:
    # Body 3: THE ARCHER — hooded astral marksman drawing a crescent starlight bow!
    hover = math.sin(ph) * 2.5
    hy = cy - 4.0 + hover
    # Flowing starlight cloak & hooded celestial head
    body.shaded_poly([(cx - 12, hy + 22), (cx - 8, hy - 10), (cx + 8, hy - 10), (cx + 12, hy + 22)], ASTRAL)
    body.shaded_ellipse(cx, hy - 13.0, 8.0, 8.0, STAR_ICE, spec_col="cream")
    body.ring(cx, hy - 13.0, 9.5, "gold", 1.2)
    # Huge luminous crescent bow & drawn starlight arrow!
    bx = cx + (13.0 if d == "side" else 15.0)
    bow_pts = [
        (bx - 6, hy - 22), (bx + 8, hy - 11), (bx + 11, hy), (bx + 8, hy + 11), (bx - 6, hy + 22),
    ]
    body.bezier_limb(bow_pts[0], bow_pts[1], bow_pts[2], 2.6, 2.2, STAR_GOLD, protect=True)
    body.bezier_limb(bow_pts[2], bow_pts[3], bow_pts[4], 2.2, 2.6, STAR_GOLD, protect=True)
    _wire_chain(body, fx_front, bow_pts, "cream", "cream", "gold")
    # Drawn bowstring + blazing star-arrow
    pull = 6.0 + math.sin(ph) * 2.5
    body.line(bow_pts[0][0], bow_pts[0][1], bx - pull, hy, "ice", protect=True)
    body.line(bow_pts[4][0], bow_pts[4][1], bx - pull, hy, "ice", protect=True)
    body.line(bx - pull, hy, bx + 15.0, hy, "cream", protect=True)
    _star_node(fx_front, bx + 15.0, hy, 3, "cream", "sky")
    if d != "back":
        ex = cx + (3.0 if d == "side" else 0.0)
        body.eye(ex - 2.0, hy - 13.0, "gold", "cream", "void", 3, 2)
    fx_back.ring(cx, hy, 22.0, "sky", 1.2)


def _draw_serpent(body: PixelBuf, fx_back: PixelBuf, fx_front: PixelBuf, cx: float, cy: float, d: str, ph: float, lph: float) -> None:
    # Body 4: THE SERPENT — luminous S-curve Ouroboros star-wyrm with fanged star-crown!
    pts: list[tuple[float, float]] = []
    for i in range(7):
        t = i / 6.0
        sx_p = cx + math.sin(t * math.pi * 2.0 + ph) * (17.0 if d != "side" else 15.0)
        sy_p = cy + 20.0 - t * 42.0
        pts.append((sx_p, sy_p))
    # Star-wire S-body segments
    for i in range(len(pts) - 1):
        r0 = 4.2 + (i / 6.0) * 3.0
        body.capsule(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], r0, r0 + 0.5, ASTRAL if i % 2 == 0 else STAR_ICE)
    _wire_chain(body, fx_front, pts, "gold", "cream", "ice")
    # Fanged Serpent Crown Head at top vertex!
    hx, hy = pts[-1]
    body.shaded_ellipse(hx, hy, 8.8, 7.2, STAR_GOLD, spec_col="cream")
    body.shaded_poly([(hx - 7, hy - 4), (hx - 12, hy - 13), (hx - 2, hy - 6)], STAR_ICE)
    body.shaded_poly([(hx + 7, hy - 4), (hx + 12, hy - 13), (hx + 2, hy - 6)], STAR_ICE)
    if d != "back":
        body.eye(hx - 4.0, hy - 1.5, "coral", "cream", "void", 2, 2)
        body.eye(hx + 2.0, hy - 1.5, "coral", "cream", "void", 2, 2)
    fx_back.ring(cx, cy, 24.0, "coral", 1.2)


def draw_the_zodiac(ctx: FrameCtx) -> Image.Image:
    w, h = 92, 84
    ax, ay = 46.0, 66.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    cx, cy = ax, ay - 28.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sx, sy = 1.08, 0.93

    shadow.contact_shadow(ax, ay + 2.0, 21.0, 2.8, "night")

    # Distinct celestial star-wire silhouette per Zodiac body!
    if ctx.anim == "phase2":
        _draw_scales(body, fx_back, fx_front, cx, cy, d, ph, lph)
    elif ctx.anim == "phase3":
        _draw_archer(body, fx_back, fx_front, cx, cy, d, ph, lph)
    elif ctx.anim == "phase4":
        _draw_serpent(body, fx_back, fx_front, cx, cy, d, ph, lph)
    else:
        # Ram silhouette for routine + dynamic combat anims (with zodiac star-halo!)
        _draw_ram(body, fx_back, fx_front, cx, cy, d, ph, lph, ctx.is_tell, ctx.is_commit, u)

    # Outer zodiac constellation halo markers
    for k in range(4):
        a = lph * 0.5 + k * math.pi * 0.5
        fx_back.set(cx + math.cos(a) * 28.0, cy + math.sin(a) * 22.0, "gold" if k % 2 == 0 else "ice", protect=True)

    if ctx.is_tell and u > 0.25:
        fx_front.ring(cx, cy, 25.0 - u * 7.0, "gold", 1.5)
        _star_node(fx_front, cx, cy - 24.0, 4 if u > 0.65 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (6 if d == "side" else 0), cy, 24, 18, -75, 75, 5.8, ("sky", "gold", "cream"))
        fx_front.ring(cx, cy, 14.0 + ctx.fi * 5.0, "cream", 1.4)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 26.0, 12.0, 3.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="the_zodiac", name="The Zodiac", out_dir=ART_BOSSES,
    frame=(92, 84), anchor=(46, 66),
    body_radius=12.0, hit_radius=17.0, body_centre=(46, 38),
    anims=ZODIAC_ANIMS, cool_rim=True, biome_bg="deep",
    draw_frame=draw_the_zodiac,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
