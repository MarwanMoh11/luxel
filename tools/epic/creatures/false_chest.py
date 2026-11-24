#!/usr/bin/env python3
"""Island 7 Enemy: False Chest (Disguised Silver Moon-Shoals Chest Mimic with rose maw & NW shadow) — 58x50, anchor [29, 41]."""
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

SILVER_BOX = ("deep", "blue", "sky", "ice")
DARK_SILVER = ("void", "night", "deep", "blue")
GOLD_BAND = ("wine", "apricot", "gold", "cream")
MAW_ROSE = ("void", "plum", "wine", "rose")


def draw_false_chest(ctx: FrameCtx) -> Image.Image:
    w, h = 58, 50
    ax, ay = 29.0, 41.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hop = 0.0
    lid_open = 0.0
    tongue_out = 0.0
    legs_out = False
    sx, sy = 1.0, 1.0

    if ctx.anim == "routine":
        # Looks almost perfectly like a real silver chest (subtle breathing lid crack on frame 4)
        lid_open = 1.0 if ctx.fi == 4 else 0.0
    elif ctx.is_tell:
        legs_out = True
        lid_open = 2.0 + 7.0 * u
        hop = -1.5 * u
        sx, sy = 1.08, 0.90
    elif ctx.is_commit:
        legs_out = True
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        hop = 7.0 * sm
        lid_open = 11.0 * sm + 3.0
        tongue_out = sm
        sx, sy = 1.12, 0.92
    elif ctx.is_recover:
        # Wide open vulnerable rose maw!
        legs_out = True
        lid_open = 10.5 + math.sin(ph) * 1.2
        tongue_out = 0.85
        sx, sy = 1.03, 0.98
    elif ctx.is_stagger:
        # Flipped back lid-down, legs kicking!
        legs_out = True
        lid_open = 8.0
        hop = 1.5
        sx, sy = 1.10, 0.86

    cx = ax
    cy = ay - hop
    # Signature Island 7 tell: NW-shifted shadow on ground!
    shadow.contact_shadow(ax - 3.5, ay - 1.0, 13.0, 2.5, "night")

    # 4 crab-like silver clasp legs when roused
    if legs_out:
        kick = math.sin(ph * 2.0) * 2.5
        for lx_off, sgn in ((-10, -1), (-5, -1), (5, 1), (10, 1)):
            body.capsule(cx + lx_off * 0.7, cy - 3, cx + lx_off + sgn * 2, cy + 1 + kick * sgn * 0.4, 1.4, 1.0, DARK_SILVER)

    # Lower chest box
    bw = 11.0 if d != "side" else 10.0
    bh = 10.0
    body.shaded_rect(cx - bw, cy - bh - 2, bw * 2, bh, SILVER_BOX)
    # Iron/gold corner straps & rivets
    body.shaded_rect(cx - bw, cy - bh - 2, 3, bh, GOLD_BAND)
    body.shaded_rect(cx + bw - 3, cy - bh - 2, 3, bh, GOLD_BAND)
    body.line(cx - bw, cy - 3, cx + bw, cy - 3, "deep")

    # Open crimson-rose serrated maw & curled tongue (or hinged dark-silver backplate in back view!)
    mouth_top = cy - bh - 2 - lid_open
    if lid_open >= 2.0 and d == "back":
        body.shaded_rect(cx - bw + 1, mouth_top + 1, (bw - 1) * 2, lid_open + 2, DARK_SILVER)
        body.shaded_rect(cx - 7, mouth_top + 2, 3, lid_open, GOLD_BAND)
        body.shaded_rect(cx + 4, mouth_top + 2, 3, lid_open, GOLD_BAND)
    elif lid_open >= 2.0 and d != "back":
        body.shaded_rect(cx - bw + 2, mouth_top + 2, (bw - 2) * 2, lid_open + 1, MAW_ROSE)
        # Upper & lower cream fangs
        tooth_step = 4
        for tx in range(int(cx - bw + 3), int(cx + bw - 2), tooth_step):
            body.poly([(tx, mouth_top + 2), (tx + 2, mouth_top + 2), (tx + 1, mouth_top + 5)], "cream", protect=True)
            body.poly([(tx + 1, cy - bh - 1), (tx + 3, cy - bh - 1), (tx + 2, cy - bh - 4)], "ice", protect=True)
        # Whipping rose tongue
        if tongue_out > 0.2:
            t_sway = math.sin(lph) * 2.2
            tx_end = cx + (13.0 * tongue_out if d == "side" else t_sway)
            ty_end = cy - bh - 1 + (2.0 if d == "side" else 6.0 * tongue_out)
            body.bezier_limb((cx, cy - bh - 3), (cx + (6 if d == "side" else t_sway * 0.5), cy - bh - 5), (tx_end, ty_end), 2.0, 1.0, ("wine", "rose", "coral"), tip_col="rose")

    # Vaulted silver chest lid (hinged open upward)
    lid_y = mouth_top - 6.0
    body.shaded_dome(cx, lid_y + 6.0, bw + 1.0, 7.5, SILVER_BOX, bottom_cut=0.1)
    body.shaded_rect(cx - bw, lid_y + 1, 3, 5, GOLD_BAND)
    body.shaded_rect(cx + bw - 3, lid_y + 1, 3, 5, GOLD_BAND)
    # Center gold keyhole clasp (glints in routine!)
    if d == "front":
        body.shaded_rect(cx - 2.5, cy - bh - 4 - lid_open * 0.3, 5, 5, GOLD_BAND)
        body.set(cx, cy - bh - 2 - lid_open * 0.3, "void", protect=True)
    elif d == "side":
        body.shaded_rect(cx + bw - 3, cy - bh - 4 - lid_open * 0.3, 3.5, 5, GOLD_BAND)
    else:
        # Back hinges
        body.shaded_rect(cx - 7, cy - bh - 3, 3, 4, GOLD_BAND)
        body.shaded_rect(cx + 4, cy - bh - 3, 3, 4, GOLD_BAND)

    # Peeking coral predator eyes tucked under lid when awake
    if lid_open >= 2.0 and d != "back":
        if d == "front":
            body.eye(cx - 5.0, mouth_top + 4.5, "coral", "cream", "void", 2, 2)
            body.eye(cx + 3.0, mouth_top + 4.5, "coral", "cream", "void", 2, 2)
        else:
            body.eye(cx + 4.0, mouth_top + 4.5, "coral", "cream", "void", 2, 2)

    # FX overlays
    if ctx.anim == "routine" and ctx.fi in (4, 5):
        fx_front.star4(cx + 4, cy - bh - 3, 2, "cream", "gold")
    elif ctx.is_tell and u > 0.35:
        fx_front.star4(cx - bw + 2, mouth_top + 2, 2, "cream", "coral")
        fx_front.star4(cx + bw - 2, mouth_top + 2, 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (10 if d == "side" else 0), cy - bh - 2, 15, 11, -50, 50, 5.0, ("wine", "coral", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, lid_y - 4, 9.0, 2.4, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="false_chest", name="False Chest", out_dir=ART_ENEMIES,
    frame=(58, 50), anchor=(29, 41),
    body_radius=7.5, hit_radius=11.0, body_centre=(29, 29),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_false_chest,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
