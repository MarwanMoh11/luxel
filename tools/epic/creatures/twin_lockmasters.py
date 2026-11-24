#!/usr/bin/env python3
"""Island 2 Dungeon B Boss: Twin Lockmasters — Brine (coral cleaver crab) & orbiting sea-glass hex shield — 88x80, anchor [44, 64]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

SHELL = ("void", "wine", "coral", "apricot")
PLATING = ("night", "plum", "wine", "coral")
BRASS = ("plum", "coral", "apricot", "gold")
CLEAVER = ("wine", "apricot", "gold", "cream")
GLASS = ("deep", "blue", "sky", "ice")


def _draw_cleaver(buf: PixelBuf, px: float, py: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    blade_ramp = CLEAVER if hot else BRASS
    # Massive curved brass-rimmed lockmaster cleaver claw
    pts = [
        (px - 2, py - 3), (px + 13, py - 11), (px + 20, py - 5),
        (px + 18, py + 4), (px + 9, py + 8), (px - 2, py + 4),
    ]
    tmp.shaded_poly(pts, blade_ramp)
    tmp.line(px + 12, py - 10, px + 19, py - 5, "cream")
    tmp.line(px + 19, py - 5, px + 17, py + 4, "cream" if hot else "gold")
    # Lock-notch cutout in cleaver edge
    tmp.circle(px + 12, py + 1, 2.2, "night")
    tmp.circle(px + 2, py + 1, 3.0, "coral")
    buf.composite(rotate_buf(tmp, px, py, ang_deg))


def _draw_hex_shield(fx: PixelBuf, sx: float, sy: float, ph: float, bright: bool) -> None:
    pts = []
    rad = 8.5 if bright else 7.2
    for i in range(6):
        a = ph * 0.6 + i * (math.tau / 6.0)
        pts.append((sx + math.cos(a) * rad, sy + math.sin(a) * rad))
    for i in range(6):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % 6]
        fx.line(x0, y0, x1, y1, "cream" if bright else "ice", protect=True)
    fx.circle(sx, sy, 3.0, "sky", protect=True)
    fx.set(sx, sy, "cream", protect=True)


def draw_twin_lockmasters(ctx: FrameCtx) -> Image.Image:
    w, h = 88, 80
    ax, ay = 44.0, 64.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    scuttle = math.sin(ph) * 2.2 if ctx.anim in ("routine", "phase2") else 0.0
    bob = abs(math.sin(ph)) * 1.5 if ctx.anim in ("routine", "phase2") else 0.0
    claw_ang = -12.0 + math.sin(lph) * 8.0
    lean = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -4.0 * u
        claw_ang = -68.0 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 6.5 * sm
        claw_ang = 56.0 * sm
        sx, sy = 1.10, 0.91
    elif ctx.is_recover:
        lean = 3.5
        claw_ang = 32.0
    elif ctx.is_stagger:
        lean = math.sin(ph * 2.2) * 3.5
        claw_ang = -40.0 + math.sin(ph * 2.2) * 18.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 4.0 - bob
    shadow.contact_shadow(ax, ay + 2.0, 19.0, 2.8, "night")

    # Articulated crab legs (3 pairs)
    for idx, off_y in enumerate((-3.0, 1.0, 5.0)):
        step = math.sin(ph + idx * 1.1) * 2.4
        if d != "side":
            for sgn in (-1.0, 1.0):
                lx0 = cx + sgn * (12.0 + idx * 1.2)
                ly0 = cy - 7.0 + off_y
                body.bezier_limb(
                    (lx0, ly0),
                    (lx0 + sgn * 8.5, ly0 - 2.0 + step * sgn),
                    (lx0 + sgn * 10.5, ay - 1.0 + step * 0.5 * sgn),
                    2.0, 1.0, PLATING, tip_col="gold",
                )
        else:
            lx0 = cx - 12.0 + idx * 9.5
            body.bezier_limb(
                (lx0, cy - 5.0),
                (lx0 - 2.5 + step * 0.7, cy + 1.5),
                (lx0 - 4.0 + step, ay - 0.5),
                2.0, 1.1, PLATING, tip_col="gold",
            )

    # Wide armored coral crab carapace with brass sluice-key crest
    body.shaded_ellipse(cx, cy - 13.0, 16.5 if d != "side" else 16.0, 11.2 if d != "side" else 10.5, SHELL)
    body.shaded_dome(cx, cy - 16.5, 15.5 if d != "side" else 15.0, 7.6, SHELL, bottom_cut=0.25)
    # Lock-tumbler shoulder pauldrons & central keyhole brass crest
    if d != "side":
        body.shaded_rect(cx - 17, cy - 22, 6, 7, BRASS)
        body.shaded_rect(cx + 11, cy - 22, 6, 7, BRASS)
        # Crown keyhole finial
        body.shaded_poly([(cx - 5, cy - 24), (cx + 5, cy - 24), (cx + 3, cy - 33), (cx - 3, cy - 33)], BRASS)
        body.circle(cx, cy - 29, 2.2, "void")
        body.line(cx, cy - 28, cx, cy - 25, "void")
        body.set(cx, cy - 33, "cream", protect=True)
    else:
        body.shaded_rect(cx - 10, cy - 22, 7, 7, BRASS)
        body.shaded_poly([(cx - 2, cy - 24), (cx + 6, cy - 24), (cx + 4, cy - 33), (cx - 1, cy - 33)], BRASS)
        body.circle(cx + 2, cy - 29, 2.0, "void")
        body.set(cx + 3, cy - 33, "cream", protect=True)

    # Face / eyes / back carapace vents
    if d == "front":
        body.ellipse(cx, cy - 12.0, 9.0, 4.2, "void")
        body.eye(cx - 5.0, cy - 13.0, "gold" if not p2 else "cream", "cream", "void", 2, 2)
        body.eye(cx + 3.0, cy - 13.0, "gold" if not p2 else "cream", "cream", "void", 2, 2)
        # Stern notched brow plates
        body.line(cx - 8, cy - 16, cx - 2, cy - 14, "gold")
        body.line(cx + 8, cy - 16, cx + 2, cy - 14, "gold")
        # Left pincer & giant right cleaver
        body.bezier_limb((cx - 14, cy - 13), (cx - 22, cy - 15 + scuttle), (cx - 20, cy - 8), 2.8, 2.0, SHELL, tip_col="gold")
        _draw_cleaver(body, cx + 12, cy - 14, claw_ang, hot=(p2 or ctx.is_tell or ctx.is_commit))
    elif d == "side":
        body.ellipse(cx + 6.0, cy - 13.0, 5.0, 4.0, "void")
        body.eye(cx + 7.5, cy - 14.0, "gold" if not p2 else "cream", "cream", "void", 2, 2)
        body.line(cx + 3, cy - 17, cx + 10, cy - 15, "gold")
        _draw_cleaver(body, cx + 8, cy - 11, claw_ang, hot=(p2 or ctx.is_tell or ctx.is_commit))
    else:
        # Back view: riveted brass lock-wheel bolted to carapace
        body.shaded_ellipse(cx, cy - 14.0, 8.5, 7.0, BRASS)
        body.circle(cx, cy - 14.0, 3.2, "night")
        body.line(cx - 7, cy - 14, cx + 7, cy - 14, "gold")
        body.line(cx, cy - 20, cx, cy - 8, "gold")
        _draw_cleaver(fx_back, cx + 13, cy - 13, claw_ang * 0.7, hot=p2)

    if p2:
        body.crack(cx - 8, cy - 18, cx + 6, cy - 8, "void", "sky", seed=17)

    # Orbiting hexagonal sea-glass shared shield!
    sh_ang = ph + (0.6 if d == "side" else 0.0)
    sh_x = cx + math.cos(sh_ang) * (18.0 if d != "side" else 15.0)
    sh_y = cy - 16.0 + math.sin(sh_ang) * 7.0
    if math.sin(sh_ang) >= 0.0:
        _draw_hex_shield(fx_front, sh_x, sh_y, ph, p2 or ctx.is_tell)
    else:
        _draw_hex_shield(fx_back, sh_x, sh_y, ph, p2 or ctx.is_tell)

    if ctx.is_tell and u > 0.35:
        fx_front.star4(cx + (18 if d == "side" else 16), cy - 18, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 10, cy - 12, 24, 15, -62, 68, 6.2, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx + 2, cy - 10, 25, 14, -20, 195, 6.0, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 33, 12.0, 3.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="twin_lockmasters", name="Twin Lockmasters", out_dir=ART_BOSSES,
    frame=(88, 80), anchor=(44, 64),
    body_radius=11.0, hit_radius=15.0, body_centre=(44, 48),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_twin_lockmasters,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
