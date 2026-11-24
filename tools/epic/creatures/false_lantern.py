#!/usr/bin/env python3
"""Island 3 Enemy: False Lantern (light-stealing flytrap lantern mimic) — 54x56, anchor [27, 46]."""
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

CAGE = ("void", "night", "dusk", "wine")
POST = ("void", "night", "plum", "wine")
MAW = ("plum", "wine", "coral", "rose")
LURE = ("teal", "jade", "lime", "cream")


def draw_false_lantern(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 64
    ax, ay = 32.0, 54.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    # Disguised rigid lantern posture in routine; splits open into flytrap maw on tell/commit/recover/stagger!
    open_jaw = 0.0
    hop = 0.0
    lunge = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        open_jaw = u
        sx, sy = 0.94, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        open_jaw = 1.0 - 0.65 * sm
        lunge = 6.5 * sm
        hop = 3.5 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        open_jaw = 0.85
        sx, sy = 1.06, 0.94
    elif ctx.is_stagger:
        open_jaw = 1.0
        lunge = math.sin(ph * 2.0) * 2.0

    cx = ax + (lunge if d == "side" else 0.0)
    cy = ay - hop
    shadow.contact_shadow(ax, ay + 1.0, 9.5, 1.8, "night")

    # Root-tendril legs (tucked like a wooden post base during routine, splayed when active!)
    if ctx.anim == "routine":
        body.shaded_rect(cx - 3.0, cy - 11.0, 6.0, 11.0, POST)
        body.shaded_rect(cx - 6.0, cy - 3.0, 12.0, 3.0, POST)
    else:
        for sgn in (-1.0, 1.0):
            leg_w = math.sin(ph + sgn) * 2.0
            body.bezier_limb((cx + sgn * 3, cy - 10), (cx + sgn * 8, cy - 5 + leg_w), (cx + sgn * 10, cy), 1.8, 0.9, POST, tip_col="wine")
        body.shaded_rect(cx - 2.5, cy - 12.0, 5.0, 7.0, POST)

    # Lantern cage lower & upper jaws (split vertically as flytrap mouth!)
    jaw_sep = open_jaw * 5.2
    ly = cy - 22.0

    # Hooked iron top bail & finial
    body.ring(cx, ly - 11.5 - jaw_sep * 0.5, 3.2, "dusk", 1.3)
    body.shaded_dome(cx, ly - 6.0 - jaw_sep * 0.5, 9.5, 6.0, CAGE, bottom_cut=0.18)

    # Lower cage plinth
    body.shaded_rect(cx - 8.5, ly + 4.0 + jaw_sep * 0.4, 17.0, 4.5, CAGE)

    if open_jaw < 0.15:
        # Routine: eerie disguised lantern cage with off-beat pale lime lure glow
        body.shaded_rect(cx - 7.5, ly - 6.0, 15.0, 11.0, CAGE)
        lure_bright = math.sin(ph) > -0.2
        body.shaded_ellipse(cx, ly - 0.5, 4.4, 4.8, LURE if lure_bright else ("pine", "teal", "jade"), protect=True)
        if lure_bright:
            body.set(cx, ly - 1.5, "cream", protect=True)
        # Cage bars
        for bx in (-6, -2, 2, 6):
            body.line(cx + bx, ly - 6, cx + bx, ly + 5, "night")
        # Subtle peeking slit eye when facing player
        if d != "back":
            ex = cx + (2.5 if d == "side" else 0.0)
            body.set(ex, ly - 8.0, "coral", protect=True)
    else:
        # Unmasked: gaping crimson/coral flytrap maw inside split cage!
        body.shaded_ellipse(cx + (2.0 if d == "side" else 0.0), ly - 0.5, 8.6, 5.5 + jaw_sep * 0.7, MAW)
        body.ellipse(cx + (2.5 if d == "side" else 0.0), ly, 6.2, 3.5 + jaw_sep * 0.5, "void", protect=True)
        # Dangling pale lime angler-lure tongue inside throat
        lx_t = cx + (4.5 if d == "side" else 0.0) + math.sin(lph) * 1.5
        body.bezier_limb((cx, ly - 5.0 - jaw_sep * 0.3), (lx_t, ly - 1.0), (lx_t + (2 if d == "side" else 0), ly + 1.5), 1.3, 0.7, LURE, tip_col="cream", protect=True)
        # Jagged ivory thorn-teeth along upper & lower rims
        for tx in (-6, -2, 2, 6):
            tx_p = cx + tx + (2 if d == "side" else 0)
            body.poly([(tx_p - 1, ly - 4 - jaw_sep * 0.4), (tx_p + 1, ly - 4 - jaw_sep * 0.4), (tx_p, ly - 1 - jaw_sep * 0.2)], "cream", protect=True)
            body.poly([(tx_p - 1, ly + 4 + jaw_sep * 0.3), (tx_p + 1, ly + 4 + jaw_sep * 0.3), (tx_p, ly + 1 + jaw_sep * 0.1)], "cream", protect=True)
        if d == "front":
            body.eye(cx - 4.0, ly - 7.5 - jaw_sep * 0.4, "lime", "cream", "void", 2, 2)
            body.eye(cx + 2.0, ly - 7.5 - jaw_sep * 0.4, "lime", "cream", "void", 2, 2)
        elif d == "side":
            body.eye(cx + 3.0, ly - 7.5 - jaw_sep * 0.4, "lime", "cream", "void", 2, 2)

    if ctx.is_tell and u > 0.30:
        fx_front.star4(cx + (7 if d == "side" else 0), ly, 3 if u > 0.7 else 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, ly, 13, 12, -70, 70, 5.0, ("wine", "coral", "cream"))
        else:
            fx_front.slash_arc(cx, ly + 2, 16, 11, 10, 170, 4.8, ("wine", "coral", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, ly - 15.0, 8.5, 2.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="false_lantern", name="False Lantern", out_dir=ART_ENEMIES,
    frame=(64, 64), anchor=(32, 54),
    body_radius=6.0, hit_radius=9.5, body_centre=(32, 34),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_false_lantern,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
