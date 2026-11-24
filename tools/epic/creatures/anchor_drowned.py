#!/usr/bin/env python3
"""Island 2 Enemy: Anchor Drowned (heavy kelp-coated mariner dragging iron anchor) — 66x60, anchor [33, 49]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_ENEMIES, CACHE_DIR, ENEMY_ANIMS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

KELP_COAT = ("void", "pine", "deep", "teal")
KELP_FROND = ("night", "pine", "teal", "jade")
ANCHOR_IRON = ("night", "dusk", "mauve", "stone")
HOT_ANCHOR = ("dusk", "blue", "sky", "ice")


def _draw_heavy_anchor(buf: PixelBuf, cx: float, cy: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ramp = HOT_ANCHOR if hot else ANCHOR_IRON
    tmp.ring(cx, cy - 11, 2.6, "gold", 1.2)
    tmp.capsule(cx, cy - 8, cx, cy + 7, 2.1, 2.3, ramp)
    tmp.capsule(cx - 5.5, cy - 4.5, cx + 5.5, cy - 4.5, 1.4, 1.4, ramp)
    tmp.bezier_limb((cx - 9.5, cy + 2), (cx - 5, cy + 9), (cx, cy + 7.5), 1.6, 2.2, ramp, tip_col="ice" if hot else "stone")
    tmp.bezier_limb((cx + 9.5, cy + 2), (cx + 5, cy + 9), (cx, cy + 7.5), 1.6, 2.2, ramp, tip_col="ice" if hot else "stone")
    buf.composite(rotate_buf(tmp, cx, cy, ang_deg))


def draw_anchor_drowned(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 66
    ax, ay = 42.0, 54.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    trudge = abs(math.sin(ph)) * 1.4 if ctx.anim == "routine" else 0.0
    step = math.sin(ph) * 2.4 if ctx.anim == "routine" else 0.0
    lag_k = math.sin(lph) * 2.5
    lean = 0.0
    anc_ox, anc_oy, anc_ang = 12.0, -10.0, 22.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -3.0 * u
        anc_ox = 6.0 - 12.0 * u if d == "side" else 11.0
        anc_oy = -22.0 - 9.0 * u
        anc_ang = -52.0 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 5.5 * sm
        anc_ox = 17.0 * sm if d == "side" else 13.0
        anc_oy = -5.0 + 4.0 * sm
        anc_ang = 68.0 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        # Bent forward hauling planted anchor — wide open back!
        lean = 4.5
        anc_ox, anc_oy, anc_ang = (15.0 if d == "side" else 10.0), -2.0, 82.0
        sx, sy = 1.04, 0.95
    elif ctx.is_stagger:
        lean = -3.5 + math.sin(ph * 2.0) * 2.0
        anc_ox, anc_oy, anc_ang = 12.0, -6.0, 40.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - trudge
    shadow.contact_shadow(ax, ay + 1.5, 13.0, 2.2, "night")

    # Heavy waterlogged boots
    if d == "side":
        body.shaded_ellipse(cx - 4.5 + step, ay - 1.5, 4.8, 2.6, ("void", "night", "pine"))
        body.shaded_ellipse(cx + 5.0 - step, ay - 1.2, 5.0, 2.6, ("void", "night", "pine"))
    else:
        body.shaded_ellipse(cx - 6.0, ay - 1.5 + step * 0.4, 4.2, 2.5, ("void", "night", "pine"))
        body.shaded_ellipse(cx + 6.0, ay - 1.5 - step * 0.4, 4.2, 2.5, ("void", "night", "pine"))

    # Broad hunched brine-soaked greatcoat torso
    body.shaded_ellipse(cx, cy - 14.0, 11.5 if d != "side" else 10.0, 12.0, KELP_COAT)
    body.shaded_dome(cx, cy - 19.0, 12.2 if d != "side" else 10.8, 7.2, KELP_FROND, bottom_cut=0.25)

    # Trailing kelp ribbons with secondary lag motion
    for k, ox in enumerate((-8.0, 0.0, 8.0)):
        body.bezier_limb(
            (cx + ox, cy - 15),
            (cx + ox + lag_k * 0.5, cy - 8),
            (cx + ox + lag_k, cy - 2),
            1.8, 0.7, KELP_FROND,
        )

    # Barnacled sailor hood & glowing sky eyes
    hx = cx + (3.5 if d == "side" else 0.0)
    hy = cy - 26.0
    body.shaded_dome(hx, hy + 1.5, 7.4, 7.8, KELP_COAT, bottom_cut=0.22)
    body.circle(hx - 4.5, hy - 3.5, 1.8, "stone")
    body.set(hx - 4.5, hy - 3.5, "night")

    if d == "front":
        body.ellipse(hx, hy + 0.5, 4.6, 3.6, "void")
        body.eye(hx - 2.8, hy - 0.5, "sky", "cream", "void", 2, 2)
        body.eye(hx + 1.0, hy - 0.5, "sky", "cream", "void", 2, 2)
    elif d == "side":
        body.ellipse(hx + 2.5, hy + 0.5, 3.4, 3.4, "void")
        body.eye(hx + 2.5, hy - 0.5, "sky", "cream", "void", 2, 2)
    else:
        # Glowing cracked brass back-plate showing rear flank vulnerability!
        body.shaded_ellipse(cx, cy - 15.0, 4.5, 5.5, ("plum", "apricot", "gold"))
        body.set(cx, cy - 16.0, "cream", protect=True)

    # Chain from shoulder to giant iron anchor
    sh_p = (cx + (4.0 if d == "side" else 8.5), cy - 19.0)
    anc_p = (cx + anc_ox, cy + anc_oy)
    body.chain(sh_p, anc_p, sag=3.5 + lag_k * 0.3, link_col="mauve", hi_col="stone", dark_col="night", links=4)
    _draw_heavy_anchor(body, anc_p[0], anc_p[1], anc_ang, hot=(ctx.is_tell or ctx.is_commit))

    if ctx.is_tell and u > 0.35:
        fx_front.star4(anc_p[0], anc_p[1] - 5, 3 if u > 0.7 else 2, "cream", "sky")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 10, 19, 13, -70, 70, 5.4, ("blue", "sky", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 4, 21, 10, 15, 165, 5.2, ("blue", "sky", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 10, 9.5, 3.0, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="anchor_drowned", name="Anchor Drowned", out_dir=ART_ENEMIES,
    frame=(84, 66), anchor=(42, 54),
    body_radius=7.5, hit_radius=12.0, body_centre=(42, 38),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="pine",
    draw_frame=draw_anchor_drowned,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
