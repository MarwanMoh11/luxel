#!/usr/bin/env python3
"""Island 8 Enemy: Page Wraith (illuminated parchment folio disguised as floor rug) — 56x52, anchor [28, 42]."""
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

PAGE = ("mauve", "stone", "cream")
SHADOW_PAGE = ("dusk", "mauve", "stone")
BINDING = ("void", "night", "plum", "wine")


def draw_page_wraith(ctx: FrameCtx) -> Image.Image:
    w, h = 64, 60
    ax, ay = 32.0, 48.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    # Routine: low curled folio rug; Tell: snaps upright flaring wings; Commit: L-hop plunge!
    is_flat = ctx.anim == "routine" or ctx.is_recover
    curl = abs(math.sin(ph)) * 3.5 if ctx.anim == "routine" else 0.0
    hover = 0.0
    tilt = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = 6.5 * u
        tilt = -12.0 * u
        sx, sy = 0.92, 1.10
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        hover = 9.0 * sm
        tilt = 18.0 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        hover = 0.5
        sx, sy = 1.12, 0.88
    elif ctx.is_stagger:
        hover = 4.0
        tilt = math.sin(ph * 2.0) * 18.0

    cx = ax
    cy = ay - (6.0 if is_flat else 14.0) - hover
    shadow.contact_shadow(ax, ay + 1.0, 11.5 if is_flat else 9.0, 2.0, "night")

    page_buf = PixelBuf(w, h)
    if is_flat:
        # Flat ornate illuminated folio rug with 1 curling corner!
        page_buf.shaded_poly([
            (cx - 13, cy + 3), (cx - 11, cy - 5),
            (cx + 11, cy - 5 - curl), (cx + 13, cy + 3),
        ], PAGE)
        # Gold illuminated border & wine tassel bookmark
        page_buf.line(cx - 10, cy - 3, cx + 8, cy - 3 - curl * 0.6, "gold")
        page_buf.line(cx - 11, cy + 1, cx + 10, cy + 1, "gold")
        page_buf.rect(cx - 8, cy - 1, 6, 1, "plum")
        page_buf.rect(cx + 1, cy - 1, 5, 1, "plum")
        # Crimson wine bookmark ribbon poking out bottom
        page_buf.bezier_limb((cx, cy + 3), (cx + 3, cy + 7), (cx + 5, cy + 8), 1.5, 0.9, ("wine", "coral"))
        if d != "back" and curl > 1.2:
            # Tiny sneaky glowing ink eyes peeking beneath curled corner!
            page_buf.eye(cx + 4, cy - 3 - curl * 0.4, "gold", "cream", "void", 2, 2)
    else:
        # Upright flapping double-spread illuminated manuscript phantom!
        flap = math.sin(ph * 1.5) * 4.0 if not ctx.is_commit else -5.0
        # Back crimson-plum leather spine
        page_buf.shaded_rect(cx - 2, cy - 11, 4, 20, BINDING)
        if d == "side":
            # Side profile: folded V-folio lunging right with fluttering rear leaves
            page_buf.shaded_poly([
                (cx - 11, cy - 8 - flap * 0.5), (cx + 9, cy - 11),
                (cx + 12, cy + 7), (cx - 8, cy + 9),
            ], PAGE)
            page_buf.shaded_poly([
                (cx - 13, cy - 4), (cx - 4, cy - 7), (cx - 3, cy + 6), (cx - 11, cy + 8),
            ], SHADOW_PAGE)
            page_buf.line(cx - 4, cy - 6, cx + 8, cy - 7, "gold")
            page_buf.line(cx - 2, cy + 2, cx + 9, cy + 1, "gold")
            page_buf.eye(cx + 5, cy - 3, "gold" if not ctx.is_commit else "coral", "cream", "void", 2, 2)
        else:
            # Open double-page wings!
            page_buf.shaded_poly([
                (cx - 1, cy - 9), (cx - 14, cy - 12 - flap),
                (cx - 15, cy + 6 - flap * 0.3), (cx - 1, cy + 8),
            ], PAGE)
            page_buf.shaded_poly([
                (cx + 1, cy - 9), (cx + 14, cy - 12 - flap),
                (cx + 15, cy + 6 - flap * 0.3), (cx + 1, cy + 8),
            ], PAGE if d == "front" else BINDING)
            if d == "front":
                # Illuminated gold drop-cap & ink lines + fierce ink eyes
                page_buf.rect(cx - 11, cy - 7, 5, 5, "gold")
                page_buf.rect(cx - 10, cy - 6, 3, 3, "wine")
                for ly in (-5, -1, 3):
                    page_buf.line(cx + 4, cy + ly, cx + 11, cy + ly, "plum")
                page_buf.eye(cx - 6, cy - 1, "gold", "cream", "void", 2, 2)
                page_buf.eye(cx + 4, cy - 1, "gold", "cream", "void", 2, 2)
            else:
                # Leather back cover with brass corner clasps
                page_buf.shaded_rect(cx - 12, cy - 9, 24, 16, BINDING)
                for kx, ky in [(-12, -9), (9, -9), (-12, 4), (9, 4)]:
                    page_buf.rect(cx + kx, cy + ky, 3, 3, "gold")
        # Streaming wine bookmark tail
        tail_x = cx + math.sin(lph) * 4.0
        page_buf.bezier_limb((cx, cy + 7), (tail_x, cy + 12), (tail_x + 2, cy + 16), 1.8, 0.9, ("wine", "coral"), tip_col="gold")

    body.composite(rotate_buf(page_buf, cx, cy, tilt))

    if ctx.is_tell and u > 0.35:
        fx_front.star4(cx + (8 if d == "side" else 0), cy - 10, 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (6 if d == "side" else 0), cy, 17, 11, -60, 70, 4.6, ("gold", "apricot", "cream"))
        # Fluttering torn paper scraps!
        for k in range(3):
            fx_front.rect(cx - 10 + k * 8, cy + 6 - ctx.fi * 2, 3, 2, "cream" if k % 2 == 0 else "gold", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 13, 8.0, 2.4, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="page_wraith", name="Page Wraith", out_dir=ART_ENEMIES,
    frame=(64, 60), anchor=(32, 48),
    body_radius=6.0, hit_radius=10.0, body_centre=(32, 32),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_page_wraith,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
