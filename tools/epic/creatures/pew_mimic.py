#!/usr/bin/env python3
"""Island 1 Enemy: Pew Mimic (carved stone/mahogany chapel pew with brass hinges & velvet maw) — 64x52, anchor [32, 42]."""
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

PEW_WOOD = ("void", "night", "dusk", "plum")
STONE_TRIM = ("dusk", "mauve", "stone")
MAW = ("night", "wine", "rose")
BRASS = ("plum", "coral", "apricot", "gold")


def draw_pew_mimic(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 52
    ax, ay = 32.0, 42.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hop = 0.0
    lid_open = 0.0
    sx, sy = 1.0, 1.0
    breathe = math.sin(ph) * 0.6 if ctx.anim == "routine" else 0.0

    if ctx.is_tell:
        lid_open = 6.0 * u
        sx, sy = 1.0 + 0.07 * u, 1.0 - 0.07 * u
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        hop = 6.5 * sm
        lid_open = 11.5 * sm + 2.0
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        # Wide open velvet mouth — unmistakably vulnerable!
        lid_open = 9.5 + math.sin(ph) * 1.2
        sx, sy = 1.04, 0.96
    elif ctx.is_stagger:
        lid_open = 11.0
        hop = abs(math.sin(ph * 2.0)) * 1.5

    cx = ax
    cy = ay - hop
    pw = 16.5 if d != "side" else 12.5
    shadow.contact_shadow(ax, ay + 1.5, pw + 1.0 - hop * 0.25, 2.2, "night")

    # Carved pew base bench legs + lower box
    body.shaded_rect(cx - pw, cy - 11.0, pw * 2.0, 10.0, PEW_WOOD)
    # Carved gothic arches on front/side base
    body.rect(cx - pw + 1, cy - 2, 4, 2, "void")
    body.rect(cx + pw - 5, cy - 2, 4, 2, "void")
    if d != "side":
        for bx in (-10, 0, 10):
            body.shaded_rect(cx + bx - 2.5, cy - 9.0, 5.0, 6.0, STONE_TRIM)
    else:
        body.shaded_rect(cx - 7, cy - 9.0, 14.0, 6.0, STONE_TRIM)

    # Ornate pew armrest end-finials
    for sgn in (-1, 1):
        ex = cx + sgn * (pw - 1.5)
        body.shaded_rect(ex - 2.5, cy - 19.0, 5.0, 18.0, PEW_WOOD)
        body.shaded_dome(ex, cy - 19.5, 3.0, 3.5, BRASS, bottom_cut=0.2)

    # Velvet maw interior & teeth whenever lid opens
    if lid_open > 1.2 and d != "back":
        maw_h = lid_open + 3.0
        body.shaded_rect(cx - pw + 3.5, cy - 11.0 - lid_open, (pw - 3.5) * 2.0, maw_h, MAW)
        # Plush rose tongue flopping out during recover/stagger!
        if ctx.is_recover or ctx.is_stagger:
            tongue_bob = math.sin(lph) * 1.4
            body.shaded_ellipse(cx + (4 if d == "side" else 0), cy - 9.0 + tongue_bob, 6.0, 3.4, ("wine", "coral", "rose"), spec_col="cream")
        # Upper & lower cream stone fangs
        fang_xs = (-9, -3, 3, 9) if d != "side" else (-4, 1, 6)
        for fx_t in fang_xs:
            body.shaded_poly([(cx + fx_t - 1.4, cy - 11.0 - lid_open), (cx + fx_t + 1.4, cy - 11.0 - lid_open), (cx + fx_t, cy - 8.2 - lid_open)], ("stone", "cream"))
            body.shaded_poly([(cx + fx_t - 1.2, cy - 10.0), (cx + fx_t + 1.2, cy - 10.0), (cx + fx_t, cy - 12.6)], ("stone", "cream"))
        # Glowing interior mimic eyes peering from darkness!
        if ctx.is_tell or ctx.is_commit:
            eye_y = cy - 11.5 - lid_open * 0.45
            if d == "front":
                body.eye(cx - 5.5, eye_y, "gold", "cream", "void", 2, 2)
                body.eye(cx + 3.5, eye_y, "gold", "cream", "void", 2, 2)
            else:
                body.eye(cx + 3.5, eye_y, "gold", "cream", "void", 2, 2)

    # Hinged pew backrest / lid (tilts up when opening!)
    lid_y = cy - 19.0 - lid_open + breathe
    body.shaded_rect(cx - pw + 2.0, lid_y, (pw - 2.0) * 2.0, 8.5, PEW_WOOD)
    body.line(cx - pw + 3.0, lid_y + 1.5, cx + pw - 3.0, lid_y + 1.5, "mauve")
    # Telling brass hinges along the seam!
    hinge_xs = (-pw + 5.0, pw - 5.0) if d != "side" else (-pw + 4.0, pw - 4.0)
    for hx_p in hinge_xs:
        body.rect(cx + hx_p - 1.5, lid_y + 6.5, 3, 3, "apricot")
        body.set(cx + hx_p, lid_y + 7.0, "gold", protect=True)

    # Subtle telltale brass hinge glint in routine (every cycle peak!)
    if ctx.anim == "routine" and ctx.fi in (2, 3):
        fx_front.star4(cx + hinge_xs[1], lid_y + 7.5, 2, "cream", "gold")

    if d == "back":
        # Back wooden hinge wall fills open gap cleanly + bolted brass hinge bar
        if lid_open > 0.5:
            body.shaded_rect(cx - pw + 3.0, cy - 11.0 - lid_open, (pw - 3.0) * 2.0, lid_open + 1.5, ("void", "night", "dusk"))
        body.shaded_rect(cx - pw + 4.0, lid_y + 2.0, (pw - 4.0) * 2.0, 5.0, ("night", "dusk", "plum"))
        body.line(cx - pw + 3.0, cy - 11.0, cx + pw - 3.0, cy - 11.0, "gold")

    # Telegraph / commit / stagger FX
    if ctx.is_tell and u > 0.35:
        fx_front.star4(cx + (6 if d == "side" else 0), lid_y - 3, 3 if u > 0.72 else 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (4 if d == "side" else 0), cy - 12, 19, 12, -55, 55 if d == "side" else 235, 5.4, ("wine", "rose", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, lid_y - 5.0, 10.0, 2.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="pew_mimic", name="Pew Mimic", out_dir=ART_ENEMIES,
    frame=(64, 52), anchor=(32, 42),
    body_radius=7.5, hit_radius=12.0, body_centre=(32, 27),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_pew_mimic,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
