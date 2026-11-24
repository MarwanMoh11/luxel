#!/usr/bin/env python3
"""Island 8 Enemy: Toll Clerk (brass-visored ledger-warden with scale-shield & desk bell) — 62x54, anchor [31, 44]."""
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

COAT = ("void", "night", "dusk", "plum")
LAPEL = ("night", "plum", "wine", "mauve")
BRASS = ("plum", "coral", "apricot", "gold")
PARCH = ("mauve", "stone", "cream")


def _draw_scale_shield(buf: PixelBuf, sx_p: float, sy_p: float, tilt: float, glowing: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Tall iron-bound brass ledger shield with embossed balance beam
    tmp.shaded_rect(sx_p - 6, sy_p - 12, 12, 22, ("night", "dusk", "plum", "mauve"))
    tmp.rect(sx_p - 6, sy_p - 12, 12, 2, "gold")
    tmp.rect(sx_p - 6, sy_p + 8, 12, 2, "apricot")
    tmp.rect(sx_p - 6, sy_p - 10, 2, 18, "gold")
    tmp.rect(sx_p + 4, sy_p - 10, 2, 18, "coral")
    # Embossed scale glyph in center
    col = "cream" if glowing else "gold"
    tmp.line(sx_p - 3, sy_p - 5, sx_p + 3, sy_p - 5, col, protect=True)
    tmp.line(sx_p, sy_p - 7, sx_p, sy_p + 3, col, protect=True)
    tmp.rect(sx_p - 4, sy_p - 2, 3, 2, "apricot", protect=True)
    tmp.rect(sx_p + 1, sy_p - 2, 3, 2, "apricot", protect=True)
    buf.composite(rotate_buf(tmp, sx_p, sy_p, tilt))


def _draw_desk_bell(buf: PixelBuf, bx: float, by: float, hot: bool) -> None:
    buf.shaded_dome(bx, by + 1, 4.5, 4.2, BRASS, bottom_cut=0.45, spec_col="cream")
    buf.rect(bx - 5, by + 2, 10, 2, "plum")
    buf.rect(bx - 1, by - 4, 2, 2, "cream" if hot else "gold", protect=True)


def draw_toll_clerk(ctx: FrameCtx) -> Image.Image:
    w, h = 66, 58
    ax, ay = 33.0, 47.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hop = abs(math.sin(ph)) * 1.8 if ctx.anim == "routine" else 0.0
    lean = 0.0
    shield_tilt = math.sin(lph) * 4.0
    bell_raise = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -2.8 * u
        shield_tilt = -14.0 * u
        bell_raise = -7.0 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lean = 5.5 * sm
        shield_tilt = 22.0 * sm
        bell_raise = 3.0 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        lean = 2.5
        shield_tilt = 14.0
        bell_raise = 2.0
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.0) * 2.5
        shield_tilt = -28.0 + math.sin(ph) * 8.0
        sx, sy = 1.06, 0.94

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - hop
    shadow.contact_shadow(ax, ay + 1.0, 11.5, 2.0, "night")

    # Sturdy brass-buckled boots
    step = math.sin(ph) * 2.5 if ctx.anim == "routine" else 0.0
    if d == "side":
        body.shaded_ellipse(cx - 4 + step, ay - 1.5, 4.2, 2.5, ("void", "night", "dusk"))
        body.shaded_ellipse(cx + 4 - step, ay - 1.0, 4.4, 2.6, ("void", "night", "dusk"))
    else:
        body.shaded_ellipse(cx - 5.5, ay - 1.5 + step * 0.4, 3.8, 2.4, ("void", "night", "dusk"))
        body.shaded_ellipse(cx + 5.5, ay - 1.5 - step * 0.4, 3.8, 2.4, ("void", "night", "dusk"))

    # Tailored plum-velvet clerk coat with brass buttons & stiff collar
    body.shaded_ellipse(cx, cy - 11.5, 10.2 if d != "side" else 8.8, 11.0, COAT)
    body.shaded_dome(cx, cy - 17.5, 10.6 if d != "side" else 9.0, 5.8, LAPEL, bottom_cut=0.25)
    body.line(cx - 8, cy - 15, cx + 8, cy - 15, "gold")
    if d == "front":
        for by_i in (-13, -9, -5):
            body.rect(cx - 1, cy + by_i, 2, 2, "gold", protect=True)
    elif d == "back":
        # Coattail vent & hanging ledger satchel on back
        body.line(cx, cy - 11, cx, cy - 2, "void")
        body.shaded_rect(cx - 5, cy - 14, 10, 8, ("night", "plum", "wine"))
        body.rect(cx - 4, cy - 13, 8, 2, "gold")

    # Brass-visored ledger helmet with balance-beam crest
    hx = cx + (2.0 if d == "side" else 0.0)
    hy = cy - 24.5
    body.shaded_dome(hx, hy + 2.0, 8.2 if d != "side" else 7.6, 8.5, BRASS, bottom_cut=0.18, spec_col="cream")
    # Balance-beam crest atop visor
    beam_t = math.sin(lph) * 2.0
    body.line(hx, hy - 7, hx, hy - 11, "gold")
    body.line(hx - 7, hy - 10 + beam_t * 0.4, hx + 7, hy - 10 - beam_t * 0.4, "gold")
    body.rect(hx - 8, hy - 9 + beam_t * 0.4, 3, 2, "apricot")
    body.rect(hx + 5, hy - 9 - beam_t * 0.4, 3, 2, "apricot")

    # Dark visor slit & glowing gold eyes
    if d == "front":
        body.rect(hx - 6, hy - 2, 12, 4, "void", protect=True)
        body.eye(hx - 4, hy - 1, "gold" if not ctx.is_commit else "coral", "cream", "void", 2, 2)
        body.eye(hx + 2, hy - 1, "gold" if not ctx.is_commit else "coral", "cream", "void", 2, 2)
    elif d == "side":
        body.rect(hx + 1, hy - 2, 6, 4, "void", protect=True)
        body.eye(hx + 3, hy - 1, "gold" if not ctx.is_commit else "coral", "cream", "void", 2, 2)
    else:
        body.rect(hx - 5, hy - 2, 10, 3, "plum")
        body.line(hx - 4, hy, hx + 4, hy, "apricot")

    # Desk bell + Scale Shield placement per direction
    hot = ctx.is_tell or ctx.is_commit
    if d == "front":
        _draw_desk_bell(body, cx - 12.0, cy - 13.0 + bell_raise, hot)
        _draw_scale_shield(body, cx + 11.0, cy - 12.0, shield_tilt, hot)
    elif d == "side":
        _draw_desk_bell(fx_back, cx - 6.0, cy - 15.0 + bell_raise, hot)
        _draw_scale_shield(body, cx + 10.5, cy - 12.0, shield_tilt, hot)
    else:
        _draw_scale_shield(body, cx - 11.0, cy - 12.0, -shield_tilt, hot)
        _draw_desk_bell(body, cx + 12.0, cy - 13.0 + bell_raise, hot)

    # Tell / commit / stagger FX
    if ctx.is_tell and u > 0.30:
        bx_fx = cx + (-12.0 if d == "front" else (12.0 if d == "back" else -6.0))
        by_fx = cy - 16.0 + bell_raise
        fx_front.ring(bx_fx, by_fx, 7.0 - u * 3.0, "gold", 1.2, protect=True)
        if u > 0.60:
            fx_front.star4(bx_fx, by_fx - 3, 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 12, 17, 13, -65, 65, 5.2, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 8, 19, 10, 15, 165, 4.8, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 12, 8.5, 2.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="toll_clerk", name="Toll Clerk", out_dir=ART_ENEMIES,
    frame=(66, 58), anchor=(33, 47),
    body_radius=7.0, hit_radius=11.0, body_centre=(33, 30),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_toll_clerk,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
