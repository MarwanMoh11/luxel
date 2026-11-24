#!/usr/bin/env python3
"""Island 7 Mini-Boss: Silver-Tide Mimic (Ornate Silver Treasury Chest on mercury crab-legs with rose maw & move-copy crown) — 84x76, anchor [42, 62]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame,
)

SILVER_ARMOR = ("deep", "blue", "sky", "ice")
SILVER_BRIGHT = ("blue", "sky", "ice", "cream")
MERCURY = ("night", "deep", "sky", "ice")
GOLD_TRIM = ("wine", "apricot", "gold", "cream")
MAW_ROSE = ("void", "plum", "wine", "rose")


def draw_silver_tide_mimic(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 76
    ax, ay = 42.0, 62.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hop = abs(math.sin(ph)) * 2.0 if ctx.anim in ("routine", "phase2") else 0.0
    lid_open = 3.0 + math.sin(ph) * 1.2
    tongue = 0.35
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hop = -2.0 * u
        lid_open = 5.0 + 9.0 * u
        tongue = 0.5 + 0.3 * u
        sx, sy = 1.06, 0.92
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        hop = 9.0 * sm
        lid_open = 15.0 * sm + 4.0
        tongue = 1.0 * sm + 0.3
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        # Wide open jaw (1.5x punish window!)
        lid_open = 14.0 + math.sin(ph) * 1.5
        tongue = 0.95
        hop = 0.0
    elif ctx.is_stagger:
        lid_open = 12.0
        tongue = 1.0
        hop = 1.5
        sx, sy = 1.10, 0.86

    cx = ax
    cy = ay - 4.0 - hop
    # NW-shifted shadow + liquid quicksilver puddle beneath crab-legs
    shadow.contact_shadow(ax - 4.0, ay + 1.0, 22.0, 4.2, "night")
    fx_back.ellipse(ax, ay + 1.0, 19.0 + math.sin(ph) * 1.5, 3.6, "deep")
    fx_back.ellipse(ax - 2.0, ay + 0.5, 13.0, 2.0, "sky")

    # 4 articulated mercury crab-legs (2 per side)
    stride = math.sin(ph * 2.0) * 3.0
    leg_specs = [
        (-16, -24, -1.0, stride), (-9, -15, -1.0, -stride),
        (9, 15, 1.0, stride), (16, 24, 1.0, -stride),
    ]
    for lx0, lx1, sgn, st in leg_specs:
        body.bezier_limb(
            (cx + lx0 * 0.8, cy - 5),
            (cx + lx1, cy - 9 + st * 0.4),
            (cx + lx1 + sgn * 2, cy + 5 + st * 0.5),
            2.4, 1.1, MERCURY, tip_col="ice",
        )

    # Heavy ornate silver-ice chest body
    bw = 18.0 if d != "side" else 16.0
    bh = 14.0
    body.shaded_rect(cx - bw, cy - bh - 3, bw * 2, bh, SILVER_ARMOR)
    # Ornate gilded corner straps & moon crest bands
    for bx in (cx - bw, cx - bw + 6, cx + bw - 9, cx + bw - 3):
        body.shaded_rect(bx, cy - bh - 3, 3, bh, GOLD_TRIM)
    body.line(cx - bw, cy - 5, cx + bw, cy - 5, "void")
    # P2 crystalline mirror-plates bolted onto chest walls
    if p2:
        body.shaded_poly([(cx - bw - 2, cy - bh), (cx - bw + 4, cy - bh - 4), (cx - bw + 4, cy - 4), (cx - bw - 2, cy - 6)], SILVER_BRIGHT)
        body.shaded_poly([(cx + bw + 2, cy - bh), (cx + bw - 4, cy - bh - 4), (cx + bw - 4, cy - 4), (cx + bw + 2, cy - 6)], SILVER_BRIGHT)

    # Serrated rose-wine maw + whipping mercury-rose tongue (or solid hinged backplate in back view!)
    mouth_top = cy - bh - 3 - lid_open
    if d == "back":
        body.shaded_rect(cx - bw + 1, mouth_top + 1, (bw - 1) * 2, lid_open + 3, MERCURY)
        body.shaded_rect(cx - 10, mouth_top + 2, 4, lid_open + 1, GOLD_TRIM)
        body.shaded_rect(cx + 6, mouth_top + 2, 4, lid_open + 1, GOLD_TRIM)
    else:
        body.shaded_rect(cx - bw + 2, mouth_top + 2, (bw - 2) * 2, lid_open + 2, MAW_ROSE)
        for tx in range(int(cx - bw + 4), int(cx + bw - 3), 5):
            body.poly([(tx, mouth_top + 2), (tx + 3, mouth_top + 2), (tx + 1.5, mouth_top + 6.5)], "cream", protect=True)
            body.poly([(tx + 1, cy - bh - 2), (tx + 4, cy - bh - 2), (tx + 2.5, cy - bh - 6.5)], "ice", protect=True)
        # Whipping tongue
        t_sw = math.sin(lph) * 3.0
        tx_e = cx + ((18.0 * tongue) if d == "side" else t_sw * 1.4)
        ty_e = cy - bh - 1 + (2.0 if d == "side" else 8.0 * tongue)
        body.bezier_limb((cx, cy - bh - 4), (cx + (9 * tongue if d == "side" else t_sw), cy - bh - 7), (tx_e, ty_e), 2.8, 1.3, ("wine", "rose", "coral"), tip_col="rose")

    # Vaulted palace treasury lid + golden crown clasp
    lid_y = mouth_top - 8.0
    body.shaded_dome(cx, lid_y + 8.0, bw + 1.5, 11.0, SILVER_BRIGHT if p2 else SILVER_ARMOR, bottom_cut=0.1)
    body.shaded_rect(cx - bw + 1, lid_y + 1, 3.5, 7, GOLD_TRIM)
    body.shaded_rect(cx + bw - 4.5, lid_y + 1, 3.5, 7, GOLD_TRIM)
    # Crown filigree atop lid
    body.shaded_poly([
        (cx - 7, lid_y + 1), (cx - 5, lid_y - 5), (cx - 2, lid_y - 1),
        (cx, lid_y - 6), (cx + 2, lid_y - 1), (cx + 5, lid_y - 5), (cx + 7, lid_y + 1),
    ], GOLD_TRIM)
    # Center lock clasp
    if d == "front":
        body.shaded_rect(cx - 3.5, cy - bh - 5, 7, 7, GOLD_TRIM)
        body.circle(cx, cy - bh - 1.5, 1.6, "void", protect=True)
    elif d == "side":
        body.shaded_rect(cx + bw - 4, cy - bh - 5, 4, 7, GOLD_TRIM)
    else:
        body.shaded_rect(cx - 10, cy - bh - 4, 4, 5, GOLD_TRIM)
        body.shaded_rect(cx + 6, cy - bh - 4, 4, 5, GOLD_TRIM)

    # Gleaming predator eyes under lid
    if d == "front":
        body.eye(cx - 7.5, mouth_top + 6.0, "coral", "cream", "void", 3, 2)
        body.eye(cx + 4.5, mouth_top + 6.0, "coral", "cream", "void", 3, 2)
    elif d == "side":
        body.eye(cx + 6.5, mouth_top + 6.0, "coral", "cream", "void", 3, 2)

    # Floating holographic mimic-sigil projection above crown during tell / phase2
    if ctx.is_tell:
        sy_i = max(8.0, lid_y - 10.0)
        fx_front.ring(cx, sy_i, 5.5 + (1.0 - u) * 3.0, "ice", 1.3)
        fx_front.star4(cx, sy_i, 3, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (14 if d == "side" else 0), cy - bh - 3, 22, 14, -55, 55, 6.0, ("sky", "ice", "cream"))
        fx_front.slash_arc(cx + (14 if d == "side" else 0), cy - bh - 3, 18, 11, -35, 35, 3.5, ("wine", "rose", "cream"))
    elif ctx.is_stagger:
        body.crack(cx - 8, cy - bh, cx + 6, cy - 6, "void", "ice", seed=41)
        fx_front.dizzy_stars(cx, max(10.0, lid_y - 8.0), 11.0, 3.0, ph)
    elif p2:
        fx_front.star4(cx - bw, cy - bh - 2, 2, "cream", "ice")
        fx_front.star4(cx + bw, cy - bh - 2, 2, "cream", "sky")

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="silver_tide_mimic", name="Silver-Tide Mimic", out_dir=ART_BOSSES,
    frame=(84, 76), anchor=(42, 62),
    body_radius=12.0, hit_radius=16.0, body_centre=(42, 42),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_silver_tide_mimic,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
