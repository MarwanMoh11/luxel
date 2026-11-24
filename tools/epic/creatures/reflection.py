#!/usr/bin/env python3
"""Island 7 Enemy: Reflection (Mirrored Trickster moth-double with inverted silver cloak & shard lantern) — 60x54, anchor [30, 44]."""
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

MIRROR_CLOAK = ("deep", "blue", "sky", "ice")
DARK_SIDE = ("void", "night", "deep", "blue")
SILVER_BRIGHT = ("blue", "sky", "ice", "cream")
PORCELAIN = ("mauve", "stone", "ice", "cream")


def draw_reflection(ctx: FrameCtx) -> Image.Image:
    w, h = 72, 66
    ax, ay = 34.0, 53.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = math.sin(ph) * 2.0
    sway = math.sin(lph) * 2.8
    lean = 0.0
    lan_reach = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -2.5 * u
        lan_reach = -3.0 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 4.0 * sm
        lan_reach = 8.5 * sm
        sx, sy = 1.08, 0.94
    elif ctx.is_recover:
        lean = 2.0 * (1.0 - u)
        hover = 2.0
    elif ctx.is_stagger:
        lean = -3.0 + math.sin(ph * 2.0) * 1.8
        hover = 2.5

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 3.0 + hover
    # Eerie inverted NW-shifted ground shadow cue
    shadow.contact_shadow(ax - 2.0, ay + 1.0, 8.5, 1.6, "night")

    # Twin optical shimmer ribbons trailing behind cloak (secondary motion)
    if d == "side":
        fx_back.bezier_limb((cx - 3, cy - 19), (cx - 12, cy - 11 + sway), (cx - 17, cy - 3 + sway * 1.2), 2.1, 0.8, MIRROR_CLOAK, tip_col="ice")
        fx_back.bezier_limb((cx - 2, cy - 13), (cx - 10, cy - 6 - sway * 0.7), (cx - 14, cy + 1 - sway), 1.6, 0.7, DARK_SIDE, tip_col="sky")
    else:
        fx_back.bezier_limb((cx - 7, cy - 14), (cx - 13, cy - 6 + sway), (cx - 15, cy + 1 + sway), 1.8, 0.7, MIRROR_CLOAK, tip_col="ice")
        fx_back.bezier_limb((cx + 7, cy - 14), (cx + 13, cy - 6 - sway), (cx + 15, cy + 1 - sway), 1.8, 0.7, DARK_SIDE, tip_col="sky")

    # Narrow faceted mirror-diamond cloak (clearly taller/slenderer than Glass Knight)
    cloak_pts = [
        (cx, cy - 23), (cx + (7 if d != "side" else 6), cy - 15),
        (cx + (9 if d != "side" else 7), cy - 3), (cx, cy + 1),
        (cx - (9 if d != "side" else 7), cy - 3), (cx - (7 if d != "side" else 6), cy - 15),
    ]
    body.shaded_poly(cloak_pts, MIRROR_CLOAK)
    # Split inverted mirror seam: left half bright silver, right half deep obsidian-blue
    if d == "front":
        body.shaded_poly([(cx, cy - 22), (cx + 7, cy - 14), (cx + 8, cy - 3), (cx, cy)], DARK_SIDE)
        body.line(cx, cy - 22, cx, cy, "cream", protect=True)
    elif d == "back":
        body.shaded_poly([(cx - 7, cy - 14), (cx, cy - 22), (cx, cy), (cx - 8, cy - 3)], DARK_SIDE)
        body.line(cx, cy - 22, cx, cy, "ice", protect=True)
        body.shaded_poly([(cx, cy - 16), (cx + 4, cy - 12), (cx, cy - 8), (cx - 4, cy - 12)], SILVER_BRIGHT)
    else:
        body.line(cx + 1, cy - 21, cx + 2, cy - 1, "ice", protect=True)
        body.line(cx - 2, cy - 18, cx - 3, cy - 2, "deep")

    # Pointed lunar cowl & split porcelain crescent mask
    hx = cx + (1.5 if d == "side" else 0.0)
    hy = cy - 28.0
    body.shaded_poly([(hx, hy - 8), (hx + 6, hy - 1), (hx + 5, hy + 5), (hx, hy + 7), (hx - 5, hy + 5), (hx - 6, hy - 1)], PORCELAIN)
    # Delicate swept silver moth-antennae
    ant_w = math.sin(lph) * 1.6
    if d != "side":
        body.bezier_limb((hx - 2, hy - 6), (hx - 7, hy - 12 + ant_w), (hx - 11, hy - 10 + ant_w), 1.2, 0.6, SILVER_BRIGHT, tip_col="cream")
        body.bezier_limb((hx + 2, hy - 6), (hx + 7, hy - 12 - ant_w), (hx + 11, hy - 10 - ant_w), 1.2, 0.6, DARK_SIDE, tip_col="sky")
    else:
        body.bezier_limb((hx, hy - 6), (hx - 5, hy - 13 + ant_w), (hx - 10, hy - 11 + ant_w), 1.2, 0.6, SILVER_BRIGHT, tip_col="cream")

    if d == "front":
        body.shaded_poly([(hx, hy - 6), (hx + 5, hy - 1), (hx + 4, hy + 5), (hx, hy + 6)], DARK_SIDE)
        body.line(hx, hy - 6, hx, hy + 6, "cream", protect=True)
        body.eye(hx - 3.0, hy + 0.5, "ice", "cream", "void", 2, 2)
        body.eye(hx + 1.5, hy + 0.5, "sky", "ice", "void", 2, 2)
    elif d == "side":
        body.eye(hx + 2.5, hy + 0.5, "ice", "cream", "void", 2, 2)
        body.line(hx + 1, hy - 5, hx + 4, hy + 4, "cream", protect=True)
    else:
        body.line(hx, hy - 7, hx, hy + 5, "night")

    # Floating mirrored prism-lantern held at side
    lx = cx + ((11.0 + lan_reach) if d == "side" else (11.0 if d == "front" else -10.0))
    ly = cy - 13.0 + math.cos(lph) * 1.4
    body.shaded_poly([(lx, ly - 5), (lx + 3.5, ly), (lx, ly + 5), (lx - 3.5, ly)], SILVER_BRIGHT)
    body.circle(lx, ly, 1.5, "cream", protect=True)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.25:
        fx_front.ring(lx, ly, 4.0 + (1.0 - u) * 5.0, "ice", 1.2)
        fx_front.star4(lx, ly, 3 if u > 0.65 else 2, "cream", "sky")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        dir_x = 1.0 if d == "side" else 0.0
        fx_front.line(lx, ly, lx + 12.0 * (1.0 if d == "side" else 0.0), ly + (0.0 if d == "side" else 10.0), "cream", protect=True)
        fx_front.star4(lx + 7.0 * dir_x, ly, 3, "cream", "ice")
        fx_front.ring(lx + 4.0 * dir_x, ly, 5.5, "sky", 1.2)
    elif ctx.is_stagger:
        body.crack(cx - 4, cy - 18, cx + 4, cy - 7, "void", "ice", seed=17)
        fx_front.dizzy_stars(hx, hy - 10, 7.5, 2.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="reflection", name="Reflection", out_dir=ART_ENEMIES,
    frame=(72, 66), anchor=(34, 53),
    body_radius=6.0, hit_radius=9.5, body_centre=(34, 37),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_reflection,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
