#!/usr/bin/env python3
"""Island 8 Mini-Boss: The Indexer (mahogany card-catalogue locomotive head on brass casters) — 80x72, anchor [40, 56]."""
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

WALNUT = ("void", "night", "plum", "wine")
WOOD_HI = ("night", "plum", "wine", "coral")
BRASS = ("plum", "coral", "apricot", "gold")
CARD = ("mauve", "stone", "cream")


def draw_indexer(ctx: FrameCtx) -> Image.Image:
    w, h = 88, 76
    ax, ay = 44.0, 58.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    rattle = math.sin(ph * 3.0) * 1.4 if ctx.anim in ("routine", "phase2") else 0.0
    jaw_open = 0.0
    lean = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        rattle = math.sin(u * math.pi * 6.0) * 2.2
        jaw_open = 6.0 * u
        sx, sy = 0.94, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 6.0 * sm
        jaw_open = 7.5 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        jaw_open = 2.0
    elif ctx.is_stagger:
        rattle = math.sin(ph * 2.0) * 2.8
        jaw_open = 5.0
        sx, sy = 1.06, 0.94

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 16.0 + rattle * 0.5
    shadow.contact_shadow(ax, ay + 2.0, 19.0, 2.6, "night")

    # Gleaming brass rail casters underneath!
    wheel_rot = ph * 2.0
    caster_xs = (-13, 0, 13) if d == "side" else (-12, 12)
    for wx in caster_xs:
        body.shaded_ellipse(cx + wx, ay - 3.5, 4.5, 4.5, BRASS, spec_col="cream")
        body.circle(cx + wx, ay - 3.5, 2.0, "void")
        body.set(cx + wx + math.cos(wheel_rot) * 2.0, ay - 3.5 + math.sin(wheel_rot) * 2.0, "cream", protect=True)

    # Heavy mahogany card-catalogue cabinet chassis with brass edge rails
    bw = 32 if d != "side" else 34
    bh = 26
    body.shaded_rect(cx - bw * 0.5, cy - bh * 0.5, bw, bh, WALNUT)
    # Ornate beveled walnut cornice top & brass side trim
    body.shaded_rect(cx - bw * 0.5 - 2, cy - bh * 0.5 - 3, bw + 4, 5, WOOD_HI)
    body.line(cx - bw * 0.5 - 1, cy - bh * 0.5 - 2, cx + bw * 0.5 + 1, cy - bh * 0.5 - 2, "gold")
    body.rect(cx - bw * 0.5, cy + bh * 0.5 - 3, bw, 3, "apricot")
    # Brass rail cowcatcher bumper at bottom
    if d == "side":
        body.shaded_poly([
            (cx + bw * 0.5, cy + 4), (cx + bw * 0.5 + 9, cy + 12),
            (cx + bw * 0.5, cy + 12),
        ], BRASS)
    elif d == "front":
        body.shaded_poly([
            (cx - 14, cy + 10), (cx + 14, cy + 10),
            (cx + 17, cy + 14), (cx - 17, cy + 14),
        ], BRASS)

    # Top brass library bell-whistle & overflowing cream index-card plume!
    body.shaded_dome(cx, cy - bh * 0.5 - 5, 5.5, 5.0, BRASS, bottom_cut=0.4, spec_col="cream")
    card_sway = math.sin(lph) * 2.5
    for ci, dx_c in enumerate((-10, -4, 4, 10)):
        cy_top = cy - bh * 0.5 - 6 - (2 if ci % 2 == 0 else 0) - jaw_open * 0.35
        body.shaded_rect(cx + dx_c - 2 + card_sway * 0.3, cy_top - 5, 5, 6, CARD)
        body.line(cx + dx_c - 1 + card_sway * 0.3, cy_top - 3, cx + dx_c + 1 + card_sway * 0.3, cy_top - 3, "coral" if p2 else "wine")

    # Faceplate / drawers per direction!
    if d == "front":
        # 2x2 armored brass catalogue faceplate with glowing coral eyes in top label slots!
        for row_y in (-7, 3):
            for col_x in (-11, 2):
                body.shaded_rect(cx + col_x, cy + row_y, 10, 7, ("night", "dusk", "plum"))
                body.rect(cx + col_x + 1, cy + row_y + 1, 8, 5, "gold" if row_y < 0 else "apricot")
                if row_y < 0:
                    body.rect(cx + col_x + 2, cy + row_y + 2, 6, 3, "void", protect=True)
                    body.eye(cx + col_x + 4, cy + row_y + 2.5, "coral" if (p2 or ctx.is_tell) else "gold", "cream", "void", 2, 2)
                else:
                    # Brass drawer pull handle
                    body.rect(cx + col_x + 3, cy + row_y + 3, 4, 2, "cream" if ctx.is_commit else "void", protect=True)
        # Protruding snapping lower REJECT drawer jaw!
        if jaw_open > 0.5:
            body.shaded_rect(cx - 10, cy + 5, 20, 6 + jaw_open * 0.6, CARD)
            body.rect(cx - 8, cy + 7, 16, 2, "coral", protect=True)
    elif d == "side":
        # Side profile: brass nameplate faceplate on right + protruding snapping drawer jaw + side brass rivets
        for ry in (-6, 3):
            body.shaded_rect(cx - 12, cy + ry, 18, 6, ("night", "dusk", "plum"))
            body.rect(cx - 10, cy + ry + 2, 14, 2, "gold")
        # Front eye slot on right face
        body.rect(cx + 8, cy - 8, 7, 6, "gold")
        body.rect(cx + 10, cy - 7, 5, 4, "void", protect=True)
        body.eye(cx + 11.5, cy - 6, "coral" if (p2 or ctx.is_tell) else "gold", "cream", "void", 2, 2)
        # Sliding open index drawer jaw on right!
        if jaw_open > 0.5:
            body.shaded_rect(cx + 14, cy + 1, 5 + jaw_open, 7, CARD)
            body.rect(cx + 15 + jaw_open * 0.5, cy + 2, 3, 5, "coral", protect=True)
    else:
        # Back: glowing golden rear coupling socket (connects to trailing drawers!)
        body.shaded_rect(cx - 11, cy - 8, 22, 16, ("night", "dusk", "plum"))
        body.shaded_rect(cx - 7, cy - 5, 14, 10, ("coral", "apricot", "gold", "cream"))
        body.rect(cx - 4, cy - 2, 8, 4, "cream", protect=True)

    if p2:
        body.crack(cx - 9, cy - 10, cx + 6, cy + 5, "void", "coral", seed=41)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.rect(cx + math.cos(a) * 22, cy - 6 + math.sin(a) * 11, 3, 2, "cream" if k % 2 == 0 else "coral", protect=True)

    if ctx.is_tell and u > 0.30:
        fx_front.ring(cx, cy, 22.0 - u * 6.0, "coral", 1.3, protect=True)
        fx_front.star4(cx + (14 if d == "side" else 0), cy - 10, 3 if u > 0.7 else 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (12 if d == "side" else 0), cy, 22, 14, -65, 65, 5.5, ("coral", "gold", "cream"))
        # Spraying alphabetized cream index cards!
        for k in range(4):
            fx_front.rect(cx + (12 if d == "side" else -10 + k * 7) + ctx.fi * (3 if d == "side" else 0),
                          cy - 8 + k * 5, 4, 3, "cream", protect=True)
            fx_front.set(cx + (13 if d == "side" else -9 + k * 7) + ctx.fi * (3 if d == "side" else 0),
                         cy - 7 + k * 5, "coral", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 22, 11.0, 3.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="indexer", name="The Indexer", out_dir=ART_BOSSES,
    frame=(88, 76), anchor=(44, 58),
    body_radius=12.0, hit_radius=15.5, body_centre=(44, 42),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_indexer,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
