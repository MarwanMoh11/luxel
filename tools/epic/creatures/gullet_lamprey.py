#!/usr/bin/env python3
"""Island 2 Set-Piece Boss: The Gullet Lamprey (blind abyssal whale-belly lamprey head & oil sacs) — 84x80, anchor [42, 62]."""
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

HIDE = ("void", "night", "dusk", "mauve")
BELLY = ("dusk", "plum", "mauve", "rose")
MAW = ("void", "wine", "coral", "rose")
OIL_SAC = ("pine", "teal", "jade", "lime")


def _draw_lamprey_maw(buf: PixelBuf, mx: float, my: float, rx: float, ry: float, flare: float) -> None:
    rrx = rx * (1.0 + flare * 0.25)
    rry = ry * (1.0 + flare * 0.25)
    buf.shaded_ellipse(mx, my, rrx + 2.2, rry + 2.2, MAW)
    buf.ellipse(mx, my, rrx, rry, "wine")
    buf.ellipse(mx, my, rrx * 0.56, rry * 0.56, "void")
    # Concentric rings of coral & cream rasping lamprey teeth!
    teeth_n = 10
    for i in range(teeth_n):
        a = i * (math.tau / teeth_n)
        tx = mx + math.cos(a) * (rrx * 0.84)
        ty = my + math.sin(a) * (rry * 0.84)
        buf.circle(tx, ty, 1.35, "coral", protect=True)
        buf.set(mx + math.cos(a) * (rrx * 0.65), my + math.sin(a) * (rry * 0.65), "cream", protect=True)
    # Inner glowing gullet tongue
    buf.circle(mx, my + 0.5, max(1.4, rrx * 0.24), "rose", protect=True)


def draw_gullet_lamprey(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 62.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    sway = math.sin(ph) * 2.6
    lag_s = math.sin(lph) * 3.5
    flare = 0.25 + 0.15 * math.sin(ph)
    tilt = math.sin(ph) * 5.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        flare = 0.85 * u + 0.25
        tilt = -12.0 * u
        sx, sy = 0.93, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        flare = 1.15 * sm
        tilt = 14.0 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        flare = 0.55
        tilt = 8.0
    elif ctx.is_stagger:
        flare = 0.15
        tilt = 18.0 + math.sin(ph * 2.2) * 8.0

    cx = ax
    cy = ay - 10.0 + math.sin(ph) * 1.8
    shadow.contact_shadow(ax, ay + 2.0, 17.0, 3.0, "night")

    head = PixelBuf(w, h)

    # Dorsal translucent sensory fin & ribbed eel neck
    if d == "side":
        # Trailing muscular neck curving back to left
        head.bezier_limb((cx - 19, cy + 4 + lag_s * 0.4), (cx - 10, cy - 8), (cx + 2, cy - 11), 8.5, 10.5, HIDE)
        # Dorsal jagged gill fin
        fin_pts = [
            (cx - 16, cy - 3), (cx - 12, cy - 19 + lag_s * 0.3), (cx - 4, cy - 23),
            (cx + 5, cy - 20), (cx + 8, cy - 12), (cx - 12, cy - 6),
        ]
        head.shaded_poly(fin_pts, BELLY)
        head.line(cx - 12, cy - 19 + lag_s * 0.3, cx - 4, cy - 23, "rose")
        # Blind ribbed head hood (no eyes — sensory gills!)
        head.shaded_ellipse(cx + 5, cy - 10, 13.0, 11.5, HIDE)
        for gy in (-14, -10, -6):
            head.line(cx - 4, cy + gy, cx + 2, cy + gy + 1, "wine")
        # Glowing LIME stolen oil sacs pulsing along flank!
        for ox, oy, r in ((-11, -7, 3.6), (-4, -15, 4.2), (1, -2, 3.2)):
            sac_r = r + (0.6 if (p2 or ctx.is_tell) else 0.0)
            head.shaded_ellipse(cx + ox, cy + oy, sac_r, sac_r * 0.85, OIL_SAC, spec_col="cream")
            head.set(cx + ox - 1, cy + oy - 1, "cream", protect=True)
        # Wide flaring lamprey suction maw at front right
        _draw_lamprey_maw(head, cx + 16, cy - 9, 6.0, 9.5, flare)

    elif d == "front":
        # Coiled blind body shoulder behind the gaping circular maw
        head.shaded_ellipse(cx + sway * 0.4, cy - 10, 15.5, 14.0, HIDE)
        # Flaring gill frills left & right
        for sgn in (-1.0, 1.0):
            frill = [
                (cx + sgn * 10, cy - 18), (cx + sgn * 22, cy - 15 + lag_s * 0.4 * sgn),
                (cx + sgn * 21, cy - 5), (cx + sgn * 11, cy - 2),
            ]
            head.shaded_poly(frill, BELLY)
            head.line(cx + sgn * 12, cy - 17, cx + sgn * 22, cy - 15 + lag_s * 0.4 * sgn, "rose")
            # Bulbous glowing lime stolen-oil sacs flanking neck!
            head.shaded_ellipse(cx + sgn * 15, cy - 10, 4.4, 3.8, OIL_SAC, spec_col="cream")
            head.set(cx + sgn * 14.5, cy - 11, "cream", protect=True)
        # Top sensory crest sac
        head.shaded_ellipse(cx, cy - 22, 4.8, 3.4, OIL_SAC, spec_col="cream")
        # Iconic circular lamprey tooth-ring maw dead center!
        if ctx.is_stagger:
            # Belly-up pale vulnerable underbelly
            head.shaded_ellipse(cx, cy - 9, 12.0, 10.0, BELLY, spec_col="cream")
            head.line(cx - 7, cy - 10, cx + 7, cy - 10, "wine")
        else:
            _draw_lamprey_maw(head, cx, cy - 10, 9.5, 9.5, flare)

    else:
        # Back view: thick ribbed purple-mauve nape, dorsal crest, & glowing oil sacs
        head.shaded_ellipse(cx, cy - 11, 15.0, 13.5, HIDE)
        head.shaded_poly([(cx - 4, cy - 26), (cx + 4, cy - 26), (cx + 6, cy - 3), (cx - 6, cy - 3)], BELLY)
        head.line(cx, cy - 25, cx, cy - 4, "rose")
        for sgn in (-1.0, 1.0):
            head.shaded_ellipse(cx + sgn * 13, cy - 12, 4.6, 4.0, OIL_SAC, spec_col="cream")
            head.shaded_ellipse(cx + sgn * 10, cy - 3, 3.5, 3.0, OIL_SAC, spec_col="cream")

    if p2:
        head.crack(cx - 7, cy - 16, cx + 6, cy - 5, "void", "lime", seed=41)

    body.composite(rotate_buf(head, cx, cy - 10, tilt))

    # Bioluminescent oil-mote aura & attack FX
    if p2:
        for k in range(4):
            a = ph * 1.5 + k * (math.tau / 4.0)
            fx_front.star4(cx + math.cos(a) * 22, cy - 12 + math.sin(a) * 14, 1, "cream", "lime")
    if ctx.is_tell and u > 0.35:
        mx = cx + (17 if d == "side" else 0)
        fx_front.ring(mx, cy - 10, 6.0 + u * 5.0, "rose", 1.2, 0, 360, protect=True)
        fx_front.star4(mx, cy - 10, 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 12, cy - 10, 20, 15, -60, 65, 6.0, ("rose", "coral", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 10, 22, 16, -25, 205, 5.8, ("rose", "coral", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 29, 12.0, 3.4, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="gullet_lamprey", name="The Gullet Lamprey", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 62),
    body_radius=11.0, hit_radius=15.0, body_centre=(42, 48),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_gullet_lamprey,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
