#!/usr/bin/env python3
"""Island 1 Enemy: Portrait Eye (gilt manor portrait frame with blinking watchful eye) — 58x58, anchor [29, 48]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_ENEMIES, CACHE_DIR, ENEMY_ANIMS, RAMPS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame,
)

GILT = ("plum", "coral", "apricot", "gold")
CANVAS = ("void", "night", "wine")
PLINTH = ("night", "dusk", "mauve", "stone")


def draw_portrait_eye(ctx: FrameCtx) -> Image.Image:
    w, h = 58, 58
    ax, ay = 29.0, 48.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    hover = math.sin(ph) * 1.4 if ctx.anim == "routine" else 0.0
    tilt_x = math.sin(ph) * 1.2 if ctx.anim == "routine" else 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = -2.2 * u
        sx, sy = 1.0 + 0.06 * u, 1.0 - 0.05 * u
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        hover = -1.5 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        hover = 1.8
    elif ctx.is_stagger:
        tilt_x = math.sin(ph * 2.5) * 2.4
        hover = 2.4

    cx = ax + tilt_x
    cy = ay - 2.0 + hover
    shadow.contact_shadow(ax, ay + 1.5, 11.5, 2.0, "night")

    # Carved manor pedestal plinth at base
    body.shaded_rect(cx - 9.0, ay - 6.0, 18.0, 6.0, PLINTH)
    body.rect(cx - 10.5, ay - 2.5, 21.0, 2.5, "dusk")
    body.line(cx - 8.5, ay - 5.5, cx + 8.5, ay - 5.5, "stone")

    # Ornate gilt portrait frame dimensions
    fw = 11.5 if d != "side" else 8.5
    fh = 15.0
    fy = cy - 22.0

    # Top gilt crest finial & hanging tassels
    body.shaded_dome(cx, fy - fh - 1.5, 5.2, 4.2, GILT, bottom_cut=0.25, spec_col="cream")
    body.set(cx, fy - fh - 5.2, "cream", protect=True)
    tassel_lag = math.sin(lph) * 1.8
    fx_back.line(cx - fw + 1, fy + fh - 2, cx - fw - 1 + tassel_lag, fy + fh + 5, "wine")
    fx_back.line(cx + fw - 1, fy + fh - 2, cx + fw + 1 + tassel_lag, fy + fh + 5, "wine")

    # Outer gilt frame
    body.shaded_rect(cx - fw, fy - fh, fw * 2.0, fh * 2.0, GILT)
    # Corner gilded bosses
    for sx_c in (-1, 1):
        for sy_c in (-1, 1):
            body.circle(cx + sx_c * (fw - 0.5), fy + sy_c * (fh - 0.5), 2.3, "gold")
            body.set(cx + sx_c * (fw - 1.0), fy + sy_c * (fh - 1.0), "cream", protect=True)

    if d == "back":
        # Wooden easel backing + brass hanging wire + wax seal
        body.shaded_rect(cx - fw + 3, fy - fh + 3, (fw - 3) * 2.0, (fh - 3) * 2.0, RAMPS["wood"])
        body.line(cx - fw + 4, fy - 7, cx, fy - 11, "gold")
        body.line(cx + fw - 4, fy - 7, cx, fy - 11, "gold")
        body.circle(cx, fy + 2, 3.0, "wine")
        body.set(cx - 1, fy + 1, "coral", protect=True)
    else:
        # Dark crimson velvet canvas inside frame
        cw = fw - 3.2
        ch = fh - 3.2
        body.shaded_rect(cx - cw, fy - ch, cw * 2.0, ch * 2.0, CANVAS)
        # Tiny parted velvet drapes in upper corners of portrait
        body.shaded_poly([(cx - cw, fy - ch), (cx - cw + 5, fy - ch), (cx - cw, fy - ch + 7)], ("night", "wine", "coral"))
        body.shaded_poly([(cx + cw, fy - ch), (cx + cw - 5, fy - ch), (cx + cw, fy - ch + 7)], ("night", "wine", "coral"))

        # Giant watchful eye inside portrait
        ex = cx + (1.6 if d == "side" else 0.0)
        ey = fy + 1.0
        erx = 7.2 if d == "front" else 4.6
        ery = 5.4
        if ctx.is_recover:
            # Heavy lidded blink
            body.shaded_ellipse(ex, ey, erx, 2.2, ("plum", "wine", "mauve"))
            body.line(ex - erx + 1, ey + 0.5, ex + erx - 1, ey + 0.5, "void", protect=True)
        else:
            # Sclera almond
            sclera_col = "cream" if not ctx.is_stagger else "stone"
            body.ellipse(ex, ey, erx, ery, sclera_col, protect=True)
            body.ring(ex, ey, erx, "night", 1.0)
            # Pupil tracking / flaring
            look_dx = math.sin(ph) * (2.2 if d == "front" else 1.2)
            if ctx.is_tell or ctx.is_commit:
                look_dx = 1.5 if d == "side" else 0.0
            iris_col = "coral" if (ctx.is_tell or ctx.is_commit) else ("ice" if ctx.is_stagger else "gold")
            iris_r = 3.4 if not ctx.is_commit else 4.0
            body.circle(ex + look_dx, ey, iris_r, iris_col, protect=True)
            body.circle(ex + look_dx, ey, 1.8, "void", protect=True)
            body.set(ex + look_dx - 1.2, ey - 1.2, "cream", protect=True)
            # Upper eyelid shadow
            body.rect(ex - erx, ey - ery - 1, erx * 2, 2.2, "wine")

        if ctx.is_stagger:
            # Cracked glass across canvas!
            body.crack(cx - cw + 1, fy - ch + 2, cx + cw - 2, fy + ch - 2, "void", "ice", seed=17)
            body.crack(cx + cw - 2, fy - ch + 3, cx - 2, fy + 4, "void", "cream", seed=23)

    # Telegraph / commit / stagger FX
    if ctx.is_tell and u > 0.30:
        gx = cx + (3.0 if d == "side" else 0.0)
        fx_front.ring(gx, fy + 1.0, 10.5 - u * 5.0, "coral" if u > 0.6 else "gold", 1.2, protect=True)
        if u > 0.65:
            fx_front.star4(gx, fy + 1.0, 3, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        gx = cx + (4.0 if d == "side" else 0.0)
        fx_front.ring(gx, fy + 1.0, 5.5 + ctx.fi * 3.0, "coral", 1.8, protect=True)
        fx_front.star4(gx, fy + 1.0, 3, "cream", "gold")
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, fy - fh - 6.0, 8.5, 2.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="portrait_eye", name="Portrait Eye", out_dir=ART_ENEMIES,
    frame=(58, 58), anchor=(29, 48),
    body_radius=7.0, hit_radius=11.0, body_centre=(29, 26),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="wine",
    draw_frame=draw_portrait_eye,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
