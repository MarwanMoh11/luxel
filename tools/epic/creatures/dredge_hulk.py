#!/usr/bin/env python3
"""Island 2 Mini-Boss B: The Dredge Hulk (armored smuggling turret-barge with glowing brass rudder stern) — 96x84, anchor [48, 66]."""
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

HULL = ("void", "night", "deep", "plum")
IRON = ("night", "deep", "blue", "sky")
TURRET = ("night", "pine", "teal", "stone")
BRASS = ("plum", "coral", "apricot", "gold")
STERN_GLOW = ("wine", "coral", "apricot", "gold")
FOAM = ("blue", "sky", "ice", "cream")


def _draw_smokestack(buf: PixelBuf, fx: PixelBuf, sx: float, sy: float, ph: float, lph: float, hot: bool, p2: bool) -> None:
    buf.shaded_rect(sx - 4, sy - 14, 8, 14, HULL)
    buf.line(sx - 4, sy - 11, sx + 3, sy - 11, "gold" if hot else "stone")
    buf.line(sx - 4, sy - 6, sx + 3, sy - 6, "coral" if p2 else "plum")
    buf.shaded_rect(sx - 5, sy - 16, 10, 3, BRASS if (hot or p2) else IRON)
    # Panicked cream smoke rings drifting from stack (kept inside top margin!)
    puff_y = sy - 19.5 - (math.sin(lph) * 1.4 + 1.4)
    puff_x = sx - 2.0 + math.cos(lph) * 2.2
    fx.ring(puff_x, puff_y, 2.8 if hot else 2.2, "cream" if hot else "ice", 1.1, 0, 360, protect=True)
    if hot or p2:
        fx.ring(puff_x - 3.5, puff_y - 3.8, 1.9, "gold" if p2 else "cream", 1.0, 0, 360, protect=True)


def draw_dredge_hulk(ctx: FrameCtx) -> Image.Image:
    w, h = 96, 84
    ax, ay = 48.0, 66.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = math.sin(ph) * 1.6
    tilt = math.sin(ph) * 2.5
    turret_recoil = 0.0
    rudder_sway = math.sin(lph) * 12.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        bob = 1.2 * u
        tilt = -6.0 * u
        turret_recoil = -3.5 * u
        sx, sy = 0.96, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        tilt = 8.0 * sm
        turret_recoil = 5.0 * sm
        sx, sy = 1.09, 0.93
    elif ctx.is_recover:
        bob = 2.0
        tilt = 5.0
        rudder_sway = 18.0
    elif ctx.is_stagger:
        tilt = math.sin(ph * 2.0) * 9.0
        rudder_sway = math.sin(ph * 2.5) * 24.0

    cx = ax
    cy = ay - 6.0 + bob
    shadow.contact_shadow(ax, ay + 2.0, 24.0, 3.8, "night")

    # Flat nautical waterline foam & wake ripples right under barge keel
    wake_w = 24.0 + math.sin(ph) * 1.8
    fx_back.ellipse(ax, ay + 1.0, wake_w, 4.8, "deep")
    fx_back.line(ax - wake_w + 2, ay + 1.0, ax + wake_w - 2, ay + 1.0, "sky" if p2 else "blue", protect=True)
    fx_front.line(ax - wake_w + 5, ay + 3.0, ax + wake_w - 5, ay + 3.0, "ice" if p2 else "sky", protect=True)
    fx_front.line(ax - 12.0, ay + 4.0, ax + 12.0, ay + 4.0, "cream", protect=True)

    barge = PixelBuf(w, h)

    if d == "side":
        # Glowing brass RUDDER STERN on the left (clear weakpoint silhouette!)
        rud_x = cx - 23.0
        rud_y = cy - 6.0
        barge.shaded_rect(rud_x - 7, rud_y - 9, 9, 17, STERN_GLOW)
        barge.line(rud_x - 6, rud_y - 7, rud_x - 6, rud_y + 6, "cream")
        barge.circle(rud_x - 3, rud_y - 2, 3.4, "gold", protect=True)
        barge.set(rud_x - 3, rud_y - 2, "cream", protect=True)
        # Spinning brass propeller hub below rudder
        prop_h = 4.0 + abs(math.cos(ph * 2.0)) * 3.0
        barge.capsule(rud_x - 5, rud_y + 6 - prop_h * 0.5, rud_x - 5, rud_y + 6 + prop_h * 0.5, 1.4, 1.4, BRASS)

        # Heavy riveted iron barge hull facing right with prow ram
        hull_pts = [
            (cx - 21, cy - 12), (cx + 15, cy - 12), (cx + 28, cy - 4),
            (cx + 22, cy + 7), (cx - 19, cy + 7), (cx - 23, cy - 2),
        ]
        barge.shaded_poly(hull_pts, HULL)
        # Armored bow ram prow plate
        ram_pts = [(cx + 14, cy - 11), (cx + 29, cy - 4), (cx + 23, cy + 6), (cx + 12, cy + 6)]
        barge.shaded_poly(ram_pts, IRON)
        barge.line(cx + 15, cy - 10, cx + 28, cy - 4, "ice")
        # Rivet deck belt
        barge.line(cx - 19, cy - 3, cx + 22, cy - 3, "plum")
        for rx in (-15, -7, 1, 9, 17):
            barge.set(cx + rx, cy - 5, "stone")

        # Deckhouse casemate + twin side cannon turret
        barge.shaded_rect(cx - 14, cy - 24, 24, 13, TURRET)
        barge.shaded_dome(cx - 2, cy - 23, 12.0, 5.5, TURRET, bottom_cut=0.25)
        # Forward viewport eyes
        barge.shaded_rect(cx + 3, cy - 21, 7, 4, ("void", "night"))
        barge.eye(cx + 7.5, cy - 19.0, "coral" if p2 else "gold", "cream", "void", 2, 2)
        # Heavy side cannon barrel pointing right
        barge.capsule(cx + 3 + turret_recoil, cy - 13, cx + 19 + turret_recoil, cy - 13, 3.0, 2.3, IRON)
        barge.circle(cx + 19 + turret_recoil, cy - 13, 2.6, "gold" if ctx.is_tell else "void")
        if ctx.is_tell:
            barge.set(cx + 19 + turret_recoil, cy - 13, "cream", protect=True)

        # Smokestack aft of deckhouse
        _draw_smokestack(barge, fx_front, cx - 12, cy - 22, ph, lph, ctx.is_tell or ctx.is_commit, p2)

    elif d == "front":
        # Wide armored barge bow with central ram spike & flanking turrets
        hull_pts = [
            (cx - 22, cy - 10), (cx + 22, cy - 10), (cx + 25, cy + 1),
            (cx + 17, cy + 8), (cx - 17, cy + 8), (cx - 25, cy + 1),
        ]
        barge.shaded_poly(hull_pts, HULL)
        # Heavy central prow iron shield + beak spike
        barge.shaded_poly([(cx - 11, cy - 11), (cx + 11, cy - 11), (cx + 8, cy + 7), (cx, cy + 11), (cx - 8, cy + 7)], IRON)
        barge.line(cx, cy - 10, cx, cy + 10, "ice")
        # Casemate turret bridge
        barge.shaded_rect(cx - 15, cy - 24, 30, 14, TURRET)
        barge.shaded_dome(cx, cy - 23, 15.0, 6.0, TURRET, bottom_cut=0.25)
        # Glowing furnace-slit eyes
        barge.shaded_rect(cx - 9, cy - 20, 18, 5, ("void", "night"))
        barge.eye(cx - 5.0, cy - 18.0, "coral" if p2 else "gold", "cream", "void", 2, 2)
        barge.eye(cx + 3.0, cy - 18.0, "coral" if p2 else "gold", "cream", "void", 2, 2)
        # Twin flanking broadside barrels
        for sgn in (-1.0, 1.0):
            bx = cx + sgn * 18.0
            barge.shaded_ellipse(bx, cy - 14.0, 4.8, 4.2, IRON)
            barge.circle(bx, cy - 14.0, 2.2, "gold" if ctx.is_tell else "void")
            if ctx.is_tell:
                barge.set(bx, cy - 14.0, "cream", protect=True)
        # Smokestack behind bridge
        _draw_smokestack(barge, fx_front, cx - 8, cy - 26, ph, lph, ctx.is_tell or ctx.is_commit, p2)

    else:
        # Back view: HUGE glowing Brass Rudder Stern weakpoint dead center!
        hull_pts = [
            (cx - 22, cy - 10), (cx + 22, cy - 10), (cx + 24, cy + 2),
            (cx + 16, cy + 8), (cx - 16, cy + 8), (cx - 24, cy + 2),
        ]
        barge.shaded_poly(hull_pts, HULL)
        barge.shaded_rect(cx - 14, cy - 24, 28, 14, TURRET)
        barge.shaded_dome(cx, cy - 23, 14.0, 5.5, TURRET, bottom_cut=0.25)
        # Glowing brass stern reactor / rudder plate (unmistakable weakpoint!)
        barge.shaded_rect(cx - 11, cy - 13, 22, 17, STERN_GLOW)
        barge.shaded_ellipse(cx, cy - 5, 7.5, 6.0, BRASS, spec_col="cream")
        barge.circle(cx, cy - 5, 3.5, "cream", protect=True)
        # Pivoting brass rudder fin below
        rx_off = math.sin(math.radians(rudder_sway)) * 5.0
        barge.capsule(cx, cy + 2, cx + rx_off, cy + 12, 3.0, 2.2, BRASS)
        barge.line(cx, cy + 3, cx + rx_off, cy + 11, "cream")
        _draw_smokestack(barge, fx_front, cx + 8, cy - 26, ph, lph, ctx.is_tell or ctx.is_commit, p2)

    if p2:
        barge.crack(cx - 10, cy - 8, cx + 6, cy + 3, "void", "coral", seed=23)
        barge.crack(cx - 4, cy - 19, cx + 8, cy - 13, "void", "gold", seed=31)

    body.composite(rotate_buf(barge, cx, cy - 8, tilt))

    # P2 sluice-vent foam jets & attack FX
    if p2:
        for k in range(4):
            a = ph * 1.4 + k * (math.tau / 4.0)
            fx_front.star4(cx + math.cos(a) * 26, cy - 8 + math.sin(a) * 12, 1, "cream", "sky")
    if ctx.is_tell and u > 0.35:
        gx = cx + (20 if d == "side" else 0)
        fx_front.star4(gx, cy - 14, 3 if u > 0.72 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 12, cy - 10, 22, 13, -55, 55, 5.8, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 6, 26, 12, -15, 195, 5.5, ("sky", "ice", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 34, 13.0, 3.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="dredge_hulk", name="The Dredge Hulk", out_dir=ART_BOSSES,
    frame=(96, 84), anchor=(48, 66),
    body_radius=13.0, hit_radius=17.0, body_centre=(48, 52),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_dredge_hulk,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
