#!/usr/bin/env python3
"""Island 3 Boss: Hundred Lamps (dark chitin segmented lantern centipede — tightly linked spine!) — 84x80, anchor [42, 62]."""
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

CHITIN = ("void", "night", "pine", "teal")
PLATE = ("night", "pine", "teal", "jade")
BRASS = ("plum", "coral", "apricot", "gold")
MANDIBLE = ("night", "plum", "wine", "coral")
LAMP_LIT = ("coral", "apricot", "gold", "cream")
LAMP_DIM = ("void", "night", "dusk", "plum")


def _draw_segment(buf: PixelBuf, fx: PixelBuf, x: float, y: float, r: float, lit: bool, leg_ph: float, side_view: bool, p2: bool) -> None:
    # Dark gothic insectoid skittering legs with warm coral claws
    if side_view:
        lx = math.sin(leg_ph) * 4.0
        buf.bezier_limb((x, y + r * 0.35), (x + lx * 0.5, y + r + 3.5), (x + lx, y + r + 7.0), 1.6, 0.7, CHITIN, tip_col="coral")
        buf.bezier_limb((x - 3, y + r * 0.35), (x - 3 - lx * 0.5, y + r + 3.0), (x - 3 - lx, y + r + 6.5), 1.4, 0.6, CHITIN, tip_col="wine")
    else:
        for sgn in (-1.0, 1.0):
            ly = math.sin(leg_ph + (0.0 if sgn > 0 else 1.5)) * 2.8
            buf.bezier_limb((x + sgn * r * 0.72, y + 1), (x + sgn * (r + 5.0), y + 2 + ly), (x + sgn * (r + 7.5), y + 7 + ly), 1.6, 0.7, CHITIN, tip_col="coral")

    # Armored gothic chitin carapace dome + ribbed segmentation groove
    buf.shaded_ellipse(x, y, r, r * 0.84, PLATE)
    buf.ring(x, y + 1, r * 0.88, "void", 1.0, 15, 165)
    # Brass lantern housing cradle mounted on dorsal back
    pod_r = max(2.6, r * 0.45)
    buf.circle(x, y - r * 0.38, pod_r + 1.4, "plum")
    buf.ring(x, y - r * 0.38, pod_r + 1.2, "gold" if lit else "mauve", 1.0)
    buf.shaded_ellipse(x, y - r * 0.38, pod_r, pod_r * 0.88, LAMP_LIT if lit else LAMP_DIM, protect=lit)
    if lit:
        buf.set(x - 0.5, y - r * 0.42, "cream", protect=True)
        fx.star4(x, y - r * 0.42, 2 if p2 else 1, "cream", "gold")


def draw_hundred_lamps(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 62.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    lit_wave = int(u * 5.99) if ctx.anim in ("routine", "tell") else -1
    rear = 0.0
    lunge = 0.0
    jaw_open = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        rear = 9.0 * u
        jaw_open = 1.0 * u
        sx, sy = 0.96, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lunge = 8.0 * sm
        rear = -2.5 * sm
        jaw_open = 1.0 - 0.85 * sm
        sx, sy = 1.07, 0.94
    elif ctx.is_recover:
        rear = -3.0
    elif ctx.is_stagger:
        rear = -2.0 + math.sin(ph * 2.0) * 2.8

    shadow.contact_shadow(ax, ay + 2.0, 22.0, 2.8, "night")

    # Continuous tightly-linked 6-segment spine (head + 5 overlapping body segments -> ZERO gaps!)
    seg_specs: list[tuple[float, float, float]] = []
    if d == "side":
        # Head leads on right; each segment chains directly off the head's smooth rising S-arc!
        hx = ax + 14.0 + lunge * 0.7
        hy = ay - 23.0 - rear + math.sin(ph) * 1.6
        for idx in range(5, 0, -1):
            t = idx / 5.0
            # Continuous Bezier-like neck-to-tail interpolation so head NEVER detaches when rearing!
            sx_p = hx - idx * 7.6 + math.sin(t * math.pi) * (2.5 if ctx.is_tell else 0.0)
            sy_p = (hy + 12.0 * (t ** 0.72)) + math.sin(ph - idx * 0.9) * 3.0
            seg_specs.append((sx_p, sy_p, 8.6 - idx * 0.55))
    elif d == "front":
        # Coiled tight horseshoe arch behind the rearing head (every consecutive circle overlaps!)
        hx = ax
        hy = ay - 16.0 - rear * 0.6 + lunge * 0.35 + math.sin(ph) * 1.4
        coords = [(-17, -14, 6.4), (-14, -24, 7.2), (-5, -31, 7.8), (6, -31, 7.8), (15, -23, 7.2), (9, -15, 7.4)]
        for idx, (ox, oy, rad) in enumerate(coords):
            wob = math.sin(ph + idx * 1.0) * 1.8
            seg_specs.append((ax + ox + wob, ay + oy - rear * 0.35, rad))
    else:
        # Back view: continuous arched centipede carapace coil with overlapping segments & forked tail!
        coords = [(-17, -15, 6.6), (-14, -24, 7.5), (-5, -30, 8.2), (6, -30, 8.2), (14, -23, 7.5), (12, -13, 6.8), (0, -11, 7.2)]
        for idx, (ox, oy, rad) in enumerate(coords):
            wob = math.sin(ph + idx * 1.0) * 1.6
            seg_specs.append((ax + ox + wob, ay + oy - rear * 0.3, rad))
        hx, hy = ax, ay - 13.0

    # Tail pincers attached cleanly to tail segment
    if d == "side":
        tx, ty, _ = seg_specs[0]
        body.bezier_limb((tx - 3, ty), (tx - 9, ty - 4 + math.sin(lph) * 2.5), (tx - 12, ty - 8), 1.6, 0.7, MANDIBLE)
        body.bezier_limb((tx - 3, ty + 2), (tx - 9, ty + 4 + math.sin(lph) * 2.5), (tx - 12, ty + 7), 1.6, 0.7, MANDIBLE)

    for idx, (sx_p, sy_p, rad) in enumerate(seg_specs):
        seg_lit = p2 or ctx.is_commit or (ctx.is_tell and idx >= len(seg_specs) - 1 - int(u * (len(seg_specs) - 1))) or (idx == lit_wave % len(seg_specs))
        if ctx.is_recover:
            seg_lit = False
        _draw_segment(body, fx_front, sx_p, sy_p, rad, seg_lit, ph - idx * 0.85, d == "side", p2)

    if d != "back":
        # Heavy armored gothic centipede head + brass forehead lantern crest
        body.shaded_ellipse(hx, hy, 9.8, 9.0, PLATE)
        body.circle(hx + (3 if d == "side" else 0), hy - 5.2, 3.2, "plum")
        body.circle(hx + (3 if d == "side" else 0), hy - 5.2, 2.3, "gold" if not ctx.is_recover else "teal", protect=True)
        body.set(hx + (3 if d == "side" else 0), hy - 5.7, "cream", protect=True)
        lag_a = math.sin(lph) * 3.0
        if d == "side":
            # Curved antennae kept cleanly inside x <= 77, y >= 6
            body.bezier_limb((hx + 3, hy - 6), (hx + 8, hy - 14 + lag_a), (hx + 14, hy - 16 + lag_a), 1.4, 0.6, ("jade", "lime", "gold"))
            body.bezier_limb((hx - 1, hy - 7), (hx + 3, hy - 16 - lag_a * 0.4), (hx + 9, hy - 18 - lag_a * 0.6), 1.2, 0.5, ("teal", "jade", "lime"))
            # Curved crimson-gold mandibles
            body.bezier_limb((hx + 5, hy + 2), (hx + 12, hy + 4 + jaw_open * 3.5), (hx + 15, hy + 1 + jaw_open * 4.5), 2.1, 0.8, MANDIBLE, tip_col="gold")
            body.bezier_limb((hx + 5, hy - 1), (hx + 12, hy - 3 - jaw_open * 3.5), (hx + 15, hy - 1 - jaw_open * 3.5), 1.9, 0.7, MANDIBLE, tip_col="gold")
            body.eye(hx + 3.2, hy - 2.0, "gold", "cream", "void", 3, 2)
        else:
            for sgn in (-1.0, 1.0):
                body.bezier_limb((hx + sgn * 4, hy - 6), (hx + sgn * 11, hy - 15 + lag_a * sgn), (hx + sgn * 17, hy - 16 + lag_a * sgn), 1.4, 0.6, ("jade", "lime", "gold"))
                body.bezier_limb((hx + sgn * 6, hy + 3), (hx + sgn * (11 + jaw_open * 3.5), hy + 8), (hx + sgn * (6 + jaw_open * 4.5), hy + 12), 2.2, 0.8, MANDIBLE, tip_col="gold")
                body.eye(hx + sgn * 4.8 - 1.0, hy - 2.0, "gold", "cream", "void", 2, 2)
                body.eye(hx + sgn * 2.4 - 0.5, hy + 1.0, "coral", "gold", "void", 2, 1)
    else:
        body.bezier_limb((ax - 7, ay - 9), (ax - 15, ay - 6), (ax - 18, ay - 1), 2.0, 0.7, MANDIBLE, tip_col="gold")
        body.bezier_limb((ax + 7, ay - 9), (ax + 15, ay - 6), (ax + 18, ay - 1), 2.0, 0.7, MANDIBLE, tip_col="gold")

    if p2:
        body.crack(hx - 4, hy - 3, hx + 3, hy + 3, "void", "gold", seed=21)
        fx_back.ring(ax, ay - 22, 22.0, "gold", 1.1, 0, 360, protect=True)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(ax + math.cos(a) * 21, ay - 22 + math.sin(a) * 13, "gold" if k % 2 == 0 else "lime", protect=True)

    if ctx.is_tell and u > 0.35:
        fx_front.star4(hx + (6 if d == "side" else 0), hy - 8, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(hx + 1, hy, 15, 14, -72, 72, 5.8, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(hx, hy + 6, 20, 12, 10, 170, 5.5, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 14, 10.5, 3.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="hundred_lamps", name="Hundred Lamps", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 62),
    body_radius=12.0, hit_radius=16.0, body_centre=(42, 42),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_hundred_lamps,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
