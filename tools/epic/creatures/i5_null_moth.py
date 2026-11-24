#!/usr/bin/env python3
"""Island 5 Enemy: Null Moth (velvet-black event-horizon luna moth with ice crescent rims & rotating void halo) — 60x52, anchor [30, 42]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_ENEMIES, CACHE_DIR, ENEMY_ANIMS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame,
)

VELVET = ("void", "void", "night", "dusk")
PLUM_RIM = ("void", "night", "dusk", "plum")


def draw_null_moth(ctx: FrameCtx) -> Image.Image:
    w, h = 60, 52
    ax, ay = 30.0, 42.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    flap = math.sin(ph) * 4.5 if ctx.anim == "routine" else 0.0
    hover = math.cos(ph) * 2.0 if ctx.anim == "routine" else 0.0
    halo_active = not (ctx.is_recover or ctx.is_stagger)
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        flap = -5.5 * u
        hover = -1.8 * u
        sx, sy = 1.08, 0.94
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        flap = 7.0 * sm
        hover = -2.2 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        flap = 5.5
        hover = 3.2
        sx, sy = 0.92, 1.06
    elif ctx.is_stagger:
        flap = math.sin(ph * 2.0) * 3.0
        hover = 3.8

    cx = ax
    cy = ay - 17.0 + hover
    shadow.contact_shadow(ax, ay + 1.0, 9.5, 1.6, "night")

    # Rotating event-horizon void halo ring (drops in recover / shatters in stagger!)
    if halo_active:
        hr = 14.5 - (2.8 * u if ctx.is_tell else 0.0)
        fx_back.ring(cx, cy, hr, "dusk", 1.2)
        for k in range(6):
            ha = ph * 1.2 + k * (math.tau / 6.0)
            px = cx + math.cos(ha) * hr
            py = cy + math.sin(ha) * hr
            col = "ice" if k % 2 == 0 else "sky"
            (fx_front if math.sin(ha) >= 0.0 else fx_back).rect(px - 1, py - 1, 2, 2, col, protect=True)
    elif ctx.is_stagger:
        # Shattered halo fragments drifting outward
        for k in range(5):
            ha = ph * 0.8 + k * (math.tau / 5.0)
            px = cx + math.cos(ha) * (15.5 + (k % 2) * 2.0)
            py = cy + math.sin(ha) * 12.0
            fx_front.set(px, py, "ice" if k % 2 == 0 else "plum", protect=True)

    if d == "side":
        # Swept gliding dark moth profile facing right
        # Far wing peeking slightly above
        body.shaded_poly([
            (cx - 2, cy - 3), (cx - 13, cy - 11 + flap * 0.6), (cx - 11, cy - 2 + flap * 0.4), (cx - 1, cy + 1),
        ], VELVET)
        # Near sweeping luna wing with razor ice crescent rim + swallowtail
        wy_tip = cy - 9.0 + flap
        body.shaded_poly([
            (cx + 1, cy - 2), (cx - 12, wy_tip), (cx - 15, wy_tip + 6),
            (cx - 8, cy + 6 + flap * 0.4), (cx - 14, cy + 11 + math.sin(lph) * 2.0), (cx - 2, cy + 5),
        ], PLUM_RIM)
        body.line(cx - 11, wy_tip + 1, cx - 14, wy_tip + 6, "ice", protect=True)
        body.circle(cx - 6.5, cy + flap * 0.3, 2.2, "void")
        body.ring(cx - 6.5, cy + flap * 0.3, 2.4, "sky", 1.0)
        # Sleek dark thorax & head
        body.shaded_ellipse(cx + 2.0, cy + 1.0, 5.2, 3.6, VELVET)
        body.shaded_ellipse(cx + 6.5, cy - 2.0, 3.6, 3.4, PLUM_RIM)
        # Feathered ice antennae
        body.bezier_limb((cx + 7, cy - 4), (cx + 11, cy - 9), (cx + 13, cy - 11), 1.3, 0.6, ("blue", "sky", "ice"))
        body.eye(cx + 7.5, cy - 2.2, "ice" if not ctx.is_tell else "cream", "cream", "void", 2, 2)
    else:
        # Front and Back: symmetrical velvet luna wings with bright ice outer crescents & swallowtails!
        for sgn in (-1.0, 1.0):
            top_y = cy - 10.0 + flap
            mid_y = cy - 1.0 + flap * 0.5
            tail_y = cy + 12.0 + math.sin(lph + (0.4 if sgn > 0 else 0.0)) * 2.2
            # Upper forewing
            body.shaded_poly([
                (cx + sgn * 2, cy - 2),
                (cx + sgn * 15, top_y),
                (cx + sgn * 17, top_y + 7),
                (cx + sgn * 9, mid_y + 4),
                (cx + sgn * 2, cy + 3),
            ], PLUM_RIM)
            # Lower hindwing + swallowtail
            body.shaded_poly([
                (cx + sgn * 2, cy + 2),
                (cx + sgn * 11, mid_y + 5),
                (cx + sgn * 13, tail_y),
                (cx + sgn * 7, cy + 8),
                (cx + sgn * 2, cy + 6),
            ], VELVET)
            # Razor-bright ice crescent wing rim
            body.line(cx + sgn * 14, top_y + 1, cx + sgn * 16, top_y + 7, "ice", protect=True)
            body.set(cx + sgn * 12, tail_y - 1, "sky", protect=True)
            # Void eclipse-eye ring on each wing
            ewx = cx + sgn * 9.5
            ewy = cy - 2.5 + flap * 0.5
            body.circle(ewx, ewy, 2.4, "void")
            body.ring(ewx, ewy, 2.5, "ice" if d == "back" else "sky", 1.0)
            if d == "back":
                body.set(ewx, ewy, "cream", protect=True)

        # Central dark velvet body & head
        body.shaded_ellipse(cx, cy + 2.0, 3.8, 5.8, VELVET)
        body.shaded_ellipse(cx, cy - 4.0, 4.0, 3.6, PLUM_RIM)
        # Feathered silver-ice antennae
        for sgn in (-1.0, 1.0):
            body.bezier_limb(
                (cx + sgn * 2, cy - 7), (cx + sgn * 6, cy - 12), (cx + sgn * 9, cy - 13),
                1.3, 0.6, ("blue", "sky", "ice"),
            )
        if d == "front":
            body.eye(cx - 2.2, cy - 4.2, "ice" if not ctx.is_tell else "cream", "cream", "void", 2, 2)
            body.eye(cx + 1.0, cy - 4.2, "ice" if not ctx.is_tell else "cream", "cream", "void", 2, 2)
        else:
            # Back view: crescent silver mantle clasp between wings
            body.line(cx - 3, cy - 1, cx + 3, cy - 1, "ice", protect=True)
            body.set(cx, cy + 2, "plum", protect=True)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.32:
        fx_front.star4(cx + (9 if d == "side" else 0), cy - 3, 3 if u > 0.72 else 2, "cream", "ice")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 7, cy, 15, 11, -55, 55, 4.5, ("plum", "sky", "cream"))
        else:
            fx_front.slash_arc(cx, cy + 2, 16, 10, 20, 160, 4.5, ("plum", "sky", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 15.0, 8.5, 2.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="null_moth", name="Null Moth", out_dir=ART_ENEMIES,
    frame=(60, 52), anchor=(30, 42),
    body_radius=5.5, hit_radius=9.5, body_centre=(30, 25),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_null_moth,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
