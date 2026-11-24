#!/usr/bin/env python3
"""Island 6 Enemy: Piston Knight (heavy riveted vanguard with pneumatic lance & glowing rear coral exhaust valve) — 68x64, anchor [34, 54]."""
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

ARMOUR = ("void", "night", "dusk", "mauve", "stone")
DARK = ("void", "night", "dusk")
BRASS = ("plum", "coral", "apricot", "gold")


def _draw_piston_lance(buf: PixelBuf, px: float, py: float, ext: float, deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Heavy pneumatic cylinder housing
    tmp.shaded_rect(px - 4, py - 3, 10, 6, DARK)
    tmp.line(px - 2, py - 2, px + 4, py - 2, "gold")
    # Telescoping brass rod + pointed iron spearhead
    tip_x = px + 14.0 + ext
    tmp.capsule(px + 5, py, tip_x - 4, py, 1.8, 1.5, BRASS)
    pts = [(tip_x - 5, py - 3.5), (tip_x + 4, py), (tip_x - 5, py + 3.5)]
    tmp.shaded_poly(pts, ("coral", "apricot", "gold", "cream") if hot else ARMOUR)
    tmp.line(tip_x - 3, py - 1, tip_x + 3, py, "cream" if hot else "stone")
    buf.composite(rotate_buf(tmp, px, py, deg))


def draw_piston_knight(ctx: FrameCtx) -> Image.Image:
    w, h = 82, 68
    ax, ay = 36.0, 56.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = abs(math.sin(ph)) * 1.4 if ctx.anim == "routine" else 0.0
    lean = 0.0
    crouch = 0.0
    lance_ext = 0.0
    lance_deg = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -3.5 * u
        crouch = 2.5 * u
        lance_ext = -3.5 * u
        lance_deg = -10.0 * u
        sx, sy = 1.06, 0.94
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 6.5 * sm
        lance_ext = 9.0 * sm
        lance_deg = 0.0
        sx, sy = 1.12, 0.91
    elif ctx.is_recover:
        # Lance jammed into iron deck!
        lean = 4.0
        crouch = 3.5 + math.sin(ph) * 0.6
        lance_ext = 4.0
        lance_deg = 42.0
        sx, sy = 1.04, 0.95
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.0) * 2.5
        lance_deg = -35.0
        sx, sy = 0.94, 1.06

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 1.0, 13.5, 2.3, "night")

    # Heavy riveted greaves / boots
    step = math.sin(ph) * 2.4 if ctx.anim == "routine" else 0.0
    if d == "side":
        body.shaded_rect(cx - 7 + step, ay - 7, 5, 7, DARK)
        body.shaded_rect(cx + 2 - step, ay - 7, 6, 7, ARMOUR)
    else:
        body.shaded_rect(cx - 9, ay - 7 + step * 0.5, 6, 7, ARMOUR)
        body.shaded_rect(cx + 3, ay - 7 - step * 0.5, 6, 7, ARMOUR)

    # Rear glowing CORAL exhaust valve + boiler backpack (HUGE readable weakpoint in side & back!)
    valve_hot = ctx.is_tell or ctx.is_recover or ctx.is_stagger
    if d == "side":
        body.shaded_rect(cx - 13, cy - 25, 7, 13, DARK)
        body.shaded_rect(cx - 12, cy - 30, 4, 6, BRASS)  # smokestack
        body.circle(cx - 11.5, cy - 18.5, 3.5, "coral", protect=True)
        body.circle(cx - 11.5, cy - 18.5, 2.1, "gold" if valve_hot else "apricot", protect=True)
        if valve_hot:
            body.set(cx - 11.5, cy - 18.5, "cream", protect=True)
    elif d == "back":
        # Full broad back armor with unmistakable blazing center exhaust valve!
        body.shaded_ellipse(cx, cy - 17, 13.0, 12.5, ARMOUR)
        body.shaded_rect(cx - 7, cy - 26, 14, 15, DARK)
        body.shaded_rect(cx - 3, cy - 34, 6, 8, BRASS)
        body.circle(cx, cy - 18.5, 5.0, "wine", protect=True)
        body.circle(cx, cy - 18.5, 3.6, "coral", protect=True)
        body.circle(cx, cy - 18.5, 2.0, "gold" if valve_hot else "apricot", protect=True)
        body.set(cx, cy - 18.5, "cream", protect=True)

    # Broad riveted boiler-plate torso (front & side)
    if d != "back":
        body.shaded_ellipse(cx, cy - 17, 12.5 if d == "front" else 10.0, 12.0, ARMOUR)
        # Sloped locomotive cowcatcher chest/shield plate
        if d == "front":
            body.shaded_poly([(cx - 10, cy - 23), (cx + 10, cy - 23), (cx + 8, cy - 8), (cx - 8, cy - 8)], ARMOUR)
            for ry in (-20, -15, -11):
                body.line(cx - 7, cy + ry, cx + 7, cy + ry, "dusk")
                body.set(cx - 7, cy + ry, "gold")
                body.set(cx + 7, cy + ry, "gold")
        else:
            body.shaded_poly([(cx + 1, cy - 24), (cx + 10, cy - 21), (cx + 11, cy - 9), (cx + 2, cy - 8)], ARMOUR)
            body.line(cx + 6, cy - 22, cx + 7, cy - 10, "gold")

    # Heavy pauldron shoulders
    if d != "side":
        body.shaded_ellipse(cx - 12, cy - 23, 4.8, 5.2, BRASS)
        body.shaded_ellipse(cx + 12, cy - 23, 4.8, 5.2, BRASS)
    else:
        body.shaded_ellipse(cx - 1, cy - 23, 5.4, 5.2, BRASS)

    # Riveted furnace-visor helm
    hx = cx + (2.5 if d == "side" else 0.0)
    hy = cy - 29.0
    body.shaded_dome(hx, hy, 8.2 if d != "side" else 7.4, 8.2, ARMOUR, bottom_cut=0.18, spec_col="cream")
    body.rect(hx - 2, hy - 10, 4, 3, "gold")  # crest rivet
    if d == "front":
        body.rect(hx - 5, hy - 3, 10, 3, "void", protect=True)
        body.rect(hx - 4, hy - 2, 3, 1, "coral" if not ctx.is_stagger else "gold", protect=True)
        body.rect(hx + 1, hy - 2, 3, 1, "coral" if not ctx.is_stagger else "gold", protect=True)
        body.set(hx - 3, hy - 2, "cream", protect=True)
        body.set(hx + 2, hy - 2, "cream", protect=True)
    elif d == "side":
        body.rect(hx + 1, hy - 3, 6, 3, "void", protect=True)
        body.rect(hx + 3, hy - 2, 3, 1, "coral" if not ctx.is_stagger else "gold", protect=True)
        body.set(hx + 5, hy - 2, "cream", protect=True)

    # Pneumatic Lance
    if d == "side":
        _draw_piston_lance(body, cx + 2, cy - 15, lance_ext, lance_deg, ctx.is_tell or ctx.is_commit)
    elif d == "front":
        _draw_piston_lance(body, cx + 10, cy - 16, lance_ext * 0.5, 70.0 + lance_deg * 0.5, ctx.is_tell or ctx.is_commit)
    else:
        _draw_piston_lance(body, cx + 11, cy - 16, lance_ext * 0.4, -55.0, ctx.is_tell or ctx.is_commit)

    # Armor cracks on stagger
    if ctx.is_stagger:
        body.crack(cx - 5, cy - 21, cx + 4, cy - 12, "void", "coral", seed=7)
        fx_front.dizzy_stars(hx, hy - 12, 9.5, 3.0, ph)

    # Steam puffs from rear valve during tell/recover + thrust cone on commit
    if ctx.is_tell:
        puff_x = cx - 15 if d == "side" else cx
        puff_y = cy - 28 - u * 5.0
        fx_front.circle(puff_x, puff_y, 2.4, "stone", protect=True)
        fx_front.circle(puff_x + (1 if d == "side" else -3), puff_y - 3, 1.8, "cream", protect=True)
        if u > 0.45:
            fx_front.star4(cx + (14 if d == "side" else 10), cy - 16, 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 15, cy - 15, 13, 8, -45, 45, 5.2, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx + 2, cy - 10, 17, 10, 15, 165, 5.0, ("coral", "gold", "cream"))
    elif ctx.is_recover:
        puff_x = cx - 14 if d == "side" else cx
        fx_front.circle(puff_x, cy - 29 - (ctx.fi % 3) * 2, 2.0, "apricot", protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="piston_knight", name="Piston Knight", out_dir=ART_ENEMIES,
    frame=(82, 68), anchor=(36, 56),
    body_radius=7.5, hit_radius=12.0, body_centre=(36, 38),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_piston_knight,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6")
