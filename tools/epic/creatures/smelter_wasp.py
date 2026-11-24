#!/usr/bin/env python3
"""Island 6 Enemy: Smelter Wasp (aerial brass-thorax furnace wasp with glowing apricot crucible abdomen & ice-glass wings) — 60x58, anchor [30, 48]."""
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

BRASS = ("plum", "coral", "apricot", "gold")
IRON = ("void", "night", "dusk", "mauve")
GLASS = ("blue", "sky", "ice", "cream")
LAVA = ("wine", "coral", "apricot", "gold", "cream")


def _draw_wing(buf: PixelBuf, px: float, py: float, deg: float, flip: bool = False) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    s = -1.0 if flip else 1.0
    pts = [
        (px, py), (px + s * 6, py - 8), (px + s * 14, py - 6),
        (px + s * 11, py - 1), (px + s * 4, py + 1),
    ]
    tmp.shaded_poly(pts, GLASS)
    tmp.line(px + s * 2, py - 2, px + s * 11, py - 5, "cream")
    buf.composite(rotate_buf(tmp, px, py, deg))


def draw_smelter_wasp(ctx: FrameCtx) -> Image.Image:
    w, h = 60, 58
    ax, ay = 30.0, 48.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    # High hover above ground shadow (aerial silhouette!)
    hover = 12.0 + math.sin(ph) * 2.6
    wing_flap = math.sin(ph * 3.0) * 22.0
    lean = 0.0
    sx, sy = 1.0, 1.0
    bulb_hot = False

    if ctx.is_tell:
        hover = 15.0 + u * 3.5
        wing_flap = math.sin(ph * 4.0) * 28.0
        bulb_hot = True
        sx, sy = 0.94, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        hover = 14.0 - sm * 6.0
        lean = 4.5 * sm
        bulb_hot = True
        sx, sy = 1.10, 0.90
    elif ctx.is_recover:
        # Hovers low and vulnerable!
        hover = 4.5 + math.sin(ph) * 1.0
        wing_flap = -18.0 + math.sin(ph) * 6.0
        sx, sy = 1.08, 0.92
    elif ctx.is_stagger:
        hover = 3.5
        lean = math.sin(ph * 2.0) * 3.0
        wing_flap = 35.0
        sx, sy = 1.08, 0.90

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - hover
    shadow.contact_shadow(ax, ay + 1.0, 8.5 - hover * 0.14, 1.8, "night")

    # Far glass wings (behind body)
    if d == "side":
        _draw_wing(fx_back, cx - 1, cy - 11, -18 + wing_flap * 0.7, flip=True)
    else:
        _draw_wing(fx_back, cx - 4, cy - 11, wing_flap, flip=True)
        _draw_wing(fx_back, cx + 4, cy - 11, -wing_flap, flip=False)

    # Bulbous glowing molten crucible abdomen hanging low
    ab_x = cx - 7.5 if d == "side" else cx
    ab_y = cy - 4.5 + math.sin(lph) * 1.2
    body.shaded_ellipse(ab_x, ab_y, 6.2 if d == "side" else 5.8, 6.8, LAVA, spec_col="cream")
    # Iron crucible hoops around molten abdomen
    body.line(ab_x - 5, ab_y - 2, ab_x + 5, ab_y - 2, "night")
    body.line(ab_x - 4, ab_y + 2, ab_x + 4, ab_y + 2, "night")
    body.ellipse(ab_x, ab_y + 1.0, 3.2, 2.2, "cream" if bulb_hot else "gold", protect=True)
    # Stinger dropper tip
    body.shaded_poly([(ab_x - 2, ab_y + 6), (ab_x, ab_y + 10), (ab_x + 2, ab_y + 6)], IRON)

    # Riveted brass thorax
    tx = cx + (2.0 if d == "side" else 0.0)
    ty = cy - 10.5
    body.shaded_ellipse(tx, ty, 5.8, 5.2, BRASS, spec_col="cream")
    body.line(tx - 3, ty, tx + 3, ty, "plum")

    # Head & glowing compound eyes
    hx = cx + (8.0 if d == "side" else 0.0)
    hy = cy - 13.5
    body.shaded_ellipse(hx, hy, 4.6, 4.2, IRON)
    if d == "front":
        body.eye(hx - 2.6, hy - 0.5, "gold" if not ctx.is_stagger else "coral", "cream", "void", 2, 2)
        body.eye(hx + 1.2, hy - 0.5, "gold" if not ctx.is_stagger else "coral", "cream", "void", 2, 2)
        body.line(hx - 2, hy - 4, hx - 5, hy - 8, "gold")
        body.line(hx + 2, hy - 4, hx + 5, hy - 8, "gold")
    elif d == "side":
        body.eye(hx + 2.2, hy - 0.5, "gold" if not ctx.is_stagger else "coral", "cream", "void", 2, 2)
        body.line(hx + 2, hy - 4, hx + 6, hy - 8, "gold")
    else:
        body.line(hx - 2, hy - 4, hx - 5, hy - 8, "apricot")
        body.line(hx + 2, hy - 4, hx + 5, hy - 8, "apricot")

    # Near glass wing in side view
    if d == "side":
        _draw_wing(fx_front, cx + 1, cy - 12, -10 - wing_flap * 0.85, flip=True)

    # FX
    if ctx.is_tell:
        fx_front.circle(ab_x, ab_y + 10, 2.2 + u * 1.4, "gold", protect=True)
        fx_front.set(ab_x, ab_y + 10, "cream", protect=True)
        if u > 0.45:
            fx_front.star4(ab_x, ab_y + 10, 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        drop_y = ab_y + 10 + ctx.fi * 3.5
        fx_front.circle(ab_x, drop_y, 3.0, "coral", protect=True)
        fx_front.circle(ab_x, drop_y, 1.6, "cream", protect=True)
        fx_front.slash_arc(cx, cy - 4, 14, 9, 25, 155, 4.0, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 9, 8.5, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="smelter_wasp", name="Smelter Wasp", out_dir=ART_ENEMIES,
    frame=(60, 58), anchor=(30, 48),
    body_radius=5.0, hit_radius=9.5, body_centre=(30, 30),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_smelter_wasp,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6")
