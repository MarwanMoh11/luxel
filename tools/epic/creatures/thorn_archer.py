#!/usr/bin/env python3
"""Island 3 Enemy: Thorn Archer (nocturnal hooded mantis-sniper with living leaf-bow) — 58x54, anchor [29, 44]."""
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

CLOAK = ("void", "night", "dusk", "plum")
BOW = ("pine", "teal", "jade", "lime")
MANTIS = ("night", "dusk", "plum", "mauve")


def _draw_leaf_bow(buf: PixelBuf, fx: PixelBuf, bx: float, by: float, draw_u: float, fired: bool, side_view: bool) -> None:
    pull = 4.5 * draw_u
    if side_view:
        # Curved living leaf-bow facing right
        buf.bezier_limb((bx + 2, by - 10), (bx + 9, by - 4), (bx + 8, by), 2.0, 1.4, BOW, tip_col="lime")
        buf.bezier_limb((bx + 2, by + 10), (bx + 9, by + 4), (bx + 8, by), 2.0, 1.4, BOW, tip_col="lime")
        # Bowstring pulled back during tell
        sx_s = bx + 2 - pull
        buf.line(bx + 2, by - 10, sx_s, by, "stone")
        buf.line(bx + 2, by + 10, sx_s, by, "stone")
        if not fired:
            # Splinter thorn-dart nocked
            buf.line(sx_s, by, bx + 13 - pull * 0.3, by, "coral" if draw_u > 0.3 else "apricot", protect=True)
            buf.set(bx + 13 - pull * 0.3, by, "cream", protect=True)
        if draw_u > 0.4:
            fx.star4(bx + 12, by, 3 if draw_u > 0.72 else 2, "cream", "coral")
    else:
        buf.bezier_limb((bx + 4, by - 9), (bx + 10, by - 2), (bx + 8, by + 8), 2.0, 1.3, BOW, tip_col="lime")
        buf.line(bx + 4, by - 9, bx + 8, by + 8, "stone")


def draw_thorn_archer(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 60
    ax, ay = 31.0, 50.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = abs(math.sin(ph)) * 1.5 if ctx.anim == "routine" else 0.0
    stride = math.sin(ph) * 3.0 if ctx.anim == "routine" else 0.0
    draw_u = 0.0
    lean = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        draw_u = u
        lean = -2.5 * u
        sx, sy = 0.96, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lean = 3.5 * sm
        sx, sy = 1.07, 0.94
    elif ctx.is_recover:
        lean = 1.2
        sx, sy = 1.02, 0.97
    elif ctx.is_stagger:
        lean = -3.0 + math.sin(ph * 2.0) * 1.8

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob
    shadow.contact_shadow(ax, ay + 1.0, 9.5, 1.8, "night")

    # Slender mantis legs
    if d == "side":
        body.capsule(cx - 2, cy - 8, cx - 5 - stride, cy, 1.6, 1.0, ("void", "night", "dusk"))
        body.capsule(cx + 2, cy - 8, cx + 5 + stride, cy, 1.7, 1.0, MANTIS)
    else:
        body.capsule(cx - 4, cy - 8, cx - 6, cy + stride * 0.3, 1.7, 1.0, MANTIS)
        body.capsule(cx + 4, cy - 8, cx + 6, cy - stride * 0.3, 1.7, 1.0, MANTIS)

    # Tattered dusk/plum forest cloak & slender mantis torso
    cloak_sway = math.sin(lph) * 2.2
    body.shaded_poly([
        (cx - 6, cy - 20), (cx + 6, cy - 20),
        (cx + 9 + cloak_sway * 0.4, cy - 6), (cx, cy - 8), (cx - 9 + cloak_sway * 0.4, cy - 6),
    ], CLOAK)
    # Leaf-collar mantle
    body.shaded_ellipse(cx, cy - 19.5, 7.8, 3.2, BOW)

    # Pointed mantis cowl hood & sweeping antennae
    hx = cx + (1.5 if d == "side" else 0.0)
    hy = cy - 25.0
    body.shaded_poly([
        (hx - 6, hy - 2), (hx - 2, hy - 7), (hx + 4, hy - 6), (hx + 6, hy - 1),
        (hx + 4, hy + 4), (hx - 4, hy + 4),
    ], CLOAK)
    body.bezier_limb((hx - 1, hy - 6), (hx - 6, hy - 10 + math.sin(lph)), (hx - 10, hy - 9 + math.sin(lph)), 1.2, 0.5, BOW, tip_col="lime")
    body.bezier_limb((hx + 2, hy - 6), (hx - 2, hy - 11 - math.sin(lph) * 0.5), (hx - 6, hy - 11), 1.1, 0.5, BOW, tip_col="lime")

    if d == "front":
        # Glowing lime mantis visor slit
        body.rect(hx - 5, hy - 2, 10, 3, "void", protect=True)
        body.line(hx - 4, hy - 1, hx + 4, hy - 1, "lime", protect=True)
        body.set(hx - 2, hy - 1, "cream", protect=True)
        body.set(hx + 2, hy - 1, "cream", protect=True)
        _draw_leaf_bow(body, fx_front, cx + 5, cy - 16, draw_u, ctx.is_commit, False)
    elif d == "side":
        # Thorn quiver strapped on back
        body.shaded_rect(cx - 8, cy - 24, 4, 10, ("night", "plum", "wine"))
        body.set(cx - 7, cy - 25, "coral")
        body.set(cx - 5, cy - 26, "lime")
        # Glowing lime side visor
        body.rect(hx + 1, hy - 2, 5, 3, "void", protect=True)
        body.line(hx + 2, hy - 1, hx + 5, hy - 1, "lime", protect=True)
        body.set(hx + 4, hy - 1, "cream", protect=True)
        _draw_leaf_bow(body, fx_front, cx + 6, cy - 17, draw_u, ctx.is_commit, True)
    else:
        # Back view: thorn quiver with coral/lime dart fletching & cloak tail
        body.shaded_poly([(cx - 4, cy - 25), (cx + 2, cy - 25), (cx + 4, cy - 12), (cx - 2, cy - 12)], ("night", "plum", "wine"))
        for qx in (-3, -1, 1):
            body.line(cx + qx, cy - 26, cx + qx - 1, cy - 29, "coral" if qx != -1 else "lime")
        _draw_leaf_bow(body, fx_front, cx + 4, cy - 16, draw_u, ctx.is_commit, False)

    if ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.line(cx + 13, cy - 17, cx + 25, cy - 17, "cream", protect=True)
            fx_front.line(cx + 15, cy - 18, cx + 24, cy - 18, "coral", protect=True)
            fx_front.slash_arc(cx + 11, cy - 17, 7, 11, -60, 60, 3.0, ("jade", "lime", "cream"))
        else:
            fx_front.slash_arc(cx + 4, cy - 15, 12, 9, -30, 140, 3.2, ("coral", "apricot", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 11.0, 8.0, 2.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="thorn_archer", name="Thorn Archer", out_dir=ART_ENEMIES,
    frame=(64, 60), anchor=(31, 50),
    body_radius=5.5, hit_radius=9.5, body_centre=(31, 34),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_thorn_archer,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
