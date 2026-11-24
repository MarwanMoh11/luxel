#!/usr/bin/env python3
"""Island 6 Enemy: Slag Slime (molten lava core under cracked basalt crust; hardens into square slag block on stagger!) — 56x50, anchor [28, 40]."""
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

BASALT = ("void", "night", "dusk", "mauve")
LAVA = ("plum", "wine", "coral", "apricot", "gold")


def draw_slag_slime(ctx: FrameCtx) -> Image.Image:
    w, h = 60, 54
    ax, ay = 30.0, 44.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    if ctx.is_stagger:
        wob = math.sin(ph * 2.0) * 1.4
        cx, cy = ax + wob, ay
        shadow.contact_shadow(ax, ay + 1.0, 12.0, 2.0, "night")
        body.shaded_rect(cx - 11, cy - 18, 22, 19, ("night", "dusk", "mauve", "stone"))
        body.shaded_rect(cx - 9, cy - 16, 18, 15, BASALT)
        body.crack(cx - 7, cy - 14, cx + 6, cy - 5, "void", "wine", seed=11)
        body.crack(cx + 5, cy - 14, cx - 4, cy - 4, "void", "coral", seed=17)
        if d != "back":
            ex = cx + (3 if d == "side" else 0)
            body.rect(ex - 4, cy - 10, 3, 2, "void", protect=True)
            body.set(ex - 3, cy - 10, "apricot", protect=True)
            if d == "front":
                body.rect(ex + 2, cy - 10, 3, 2, "void", protect=True)
                body.set(ex + 3, cy - 10, "apricot", protect=True)
        st_y = cy - 22 - (ctx.fi % 3) * 2
        fx_front.circle(cx - 4, st_y, 2.0, "stone", protect=True)
        fx_front.circle(cx + 5, st_y - 2, 1.5, "ice", protect=True)
        fx_front.dizzy_stars(cx, cy - 26, 8.5, 2.8, ph)
        return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=1.0, sy=1.0, anchor=(ax, ay))

    hop = max(0.0, math.sin(ph)) * 3.5 if ctx.anim == "routine" else 0.0
    swell = 0.0
    sx, sy = 1.0, 1.0
    cap_lift = math.sin(lph) * 1.4

    if ctx.anim == "routine":
        sx = 1.0 - 0.07 * math.sin(ph)
        sy = 1.0 + 0.09 * math.sin(ph)
    elif ctx.is_tell:
        swell = 3.0 * u
        cap_lift = -2.8 * u
        sx, sy = 1.13, 0.88
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        hop = 5.5 * sm
        cap_lift = -5.0 * sm
        sx, sy = 0.90, 1.16
    elif ctx.is_recover:
        sx, sy = 1.12, 0.86
        cap_lift = 1.2

    cx = ax
    cy = ay - hop
    shadow.contact_shadow(ax, ay + 1.0, 13.0 + swell * 0.4, 2.2, "night")

    # Deep volcanic wine/coral magma skirt + glowing molten apricot/gold belly!
    body.shaded_ellipse(cx, cy - 3.5, 13.5 + swell, 5.2, ("night", "wine", "coral", "apricot"))
    body.shaded_dome(cx, cy - 5.5, 12.2 + swell * 0.65, 13.0, LAVA, bottom_cut=0.30, spec_col="cream")
    # Glowing hot inner lava vein & drip beads
    body.ellipse(cx - 2.0, cy - 7.5, 5.0, 2.6, "gold", protect=True)
    body.ellipse(cx - 2.5, cy - 8.2, 2.2, 1.2, "cream", protect=True)
    body.line(cx - 9, cy - 2, cx + 9, cy - 2, "wine")

    drop_off = math.sin(lph) * 2.2
    body.circle(cx - 12.0, cy - 2.0 + drop_off * 0.3, 2.2, "coral")
    body.circle(cx + 11.5, cy - 2.5 - drop_off * 0.3, 2.0, "apricot")

    # Cracked jagged basalt crust helmet with glowing magma drips
    cap_y = cy - 14.0 + cap_lift
    body.shaded_poly([
        (cx - 12, cap_y + 4), (cx - 10, cap_y - 4), (cx - 4, cap_y - 8),
        (cx + 3, cap_y - 9), (cx + 10, cap_y - 4), (cx + 12, cap_y + 3),
        (cx + 7, cap_y + 6), (cx + 1, cap_y + 3), (cx - 5, cap_y + 6),
    ], BASALT)
    body.crack(cx - 6, cap_y - 4, cx + 1, cap_y + 3, "coral", "gold", seed=3)
    body.crack(cx + 5, cap_y - 5, cx + 2, cap_y + 2, "coral", "cream", seed=9)
    body.shaded_ellipse(cx - 10, cy - 8 + cap_lift * 0.4, 3.6, 2.8, BASALT)
    body.shaded_ellipse(cx + 10, cy - 8 - cap_lift * 0.4, 3.4, 2.8, BASALT)

    if d == "front":
        body.eye(cx - 4.5, cy - 7.5, "cream", "cream", "void", 2, 2)
        body.eye(cx + 2.5, cy - 7.5, "cream", "cream", "void", 2, 2)
        body.rect(cx - 3, cy - 4, 6, 2, "wine", protect=True)
    elif d == "side":
        body.eye(cx + 4.5, cy - 8.0, "cream", "cream", "void", 2, 2)
        body.shaded_ellipse(cx - 8, cy - 11 + cap_lift * 0.5, 4.5, 4.0, BASALT)
    else:
        body.shaded_poly([(cx - 6, cap_y - 2), (cx, cap_y - 10), (cx + 6, cap_y - 2)], BASALT)
        body.ellipse(cx, cap_y - 4, 3.0, 1.8, "gold", protect=True)
        body.set(cx, cap_y - 4, "cream", protect=True)

    if ctx.is_tell:
        fx_front.circle(cx - 5, cap_y - 7 - u * 3.5, 2.0, "gold", protect=True)
        fx_front.circle(cx + 4, cap_y - 9 - u * 4.5, 1.6, "cream", protect=True)
        if u > 0.5:
            fx_front.star4(cx, cap_y - 8, 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.slash_arc(cx + (5 if d == "side" else 0), cy - 11, 15, 12, -155, -20, 5.2, ("coral", "gold", "cream"))
        fx_front.circle(cx - 10, cy - 21, 2.0, "apricot", protect=True)
        fx_front.circle(cx + 11, cy - 19, 1.8, "gold", protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="slag_slime", name="Slag Slime", out_dir=ART_ENEMIES,
    frame=(60, 54), anchor=(30, 44),
    body_radius=7.5, hit_radius=11.0, body_centre=(30, 32),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_slag_slime,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
