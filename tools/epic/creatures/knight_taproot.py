#!/usr/bin/env python3
"""Island 3 Briar Court Joust 1: Sir Taproot (beetle-mounted forest lancer) — 72x64, anchor [36, 50]."""
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

BEETLE = ("night", "pine", "teal", "jade")
SHELL_HI = ("pine", "teal", "jade", "lime")
ARMOR = ("void", "night", "dusk", "plum")
LANCE = ("plum", "wine", "apricot", "gold")
PLUME = ("wine", "coral", "apricot", "gold")


def _draw_lance(buf: PixelBuf, x: float, y: float, ang_deg: float, hot: bool, side_view: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ramp = ("coral", "apricot", "gold", "cream") if hot else LANCE
    length = 22.0 if side_view else 18.0
    pts = [
        (x - 3.0, y - 3.2),
        (x + length, y),
        (x - 3.0, y + 3.2),
    ]
    tmp.shaded_poly(pts, ramp)
    tmp.line(x - 1.0, y - 0.8, x + length - 2.0, y, "cream" if hot else "gold", protect=True)
    # Brass tournament handguard bell
    tmp.shaded_ellipse(x - 1.5, y, 2.8, 4.6, LANCE)
    buf.composite(rotate_buf(tmp, x, y, ang_deg))


def draw_knight_taproot(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 68
    ax, ay = 42.0, 54.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    gallop = abs(math.sin(ph)) * 2.2 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    rear_y = 0.0
    lance_ang = -6.0 + math.sin(ph) * 4.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -4.0 * u
        lance_ang = 0.0
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 7.0 * sm
        lance_ang = 2.0
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        lance_ang = -32.0
        lean = 2.0
    elif ctx.is_stagger:
        rear_y = 4.0 + math.sin(ph * 2.0) * 2.0
        lance_ang = -52.0
        lean = -3.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - gallop - rear_y * 0.4
    shadow.contact_shadow(ax, ay + 2.0, 18.0 if d == "side" else 14.0, 2.6, "night")

    # Armored rhinoceros beetle mount legs
    for idx in range(3):
        st = math.sin(ph + idx * 2.1) * 2.8 if ctx.anim in ("routine", "phase2") else 0.0
        if d == "side":
            lx = cx - 10.0 + idx * 9.0
            body.bezier_limb((lx, cy - 6.0), (lx + st * 0.4, cy - 2.0), (lx + st, ay), 2.1, 1.0, BEETLE, tip_col="gold")
        else:
            for sgn in (-1.0, 1.0):
                lx = cx + sgn * (9.0 + idx * 1.6)
                ly_off = -5.0 + idx * 2.0
                body.bezier_limb((lx, cy + ly_off - 4.0), (lx + sgn * 4.0, cy + ly_off), (lx + sgn * 5.0, min(ay + 1.0, cy + ly_off + 5.0 + st * 0.4)), 1.8, 0.9, BEETLE)

    # Heavy dome-shelled beetle steed body
    if d == "side":
        body.shaded_dome(cx - 2.0, cy - 10.0, 16.5, 11.5, BEETLE, bottom_cut=0.12, spec_col="lime")
        body.line(cx - 12.0, cy - 11.0, cx + 10.0, cy - 11.0, "gold")
        # Beetle horned head & upturned brass battle-horn
        bhx, bhy = cx + 13.0, cy - 9.0
        body.shaded_ellipse(bhx, bhy, 6.2, 5.4, SHELL_HI)
        body.bezier_limb((bhx + 3.0, bhy - 1.0), (bhx + 9.0, bhy - 5.0), (bhx + 11.0, bhy - 11.0), 2.2, 0.8, LANCE, tip_col="cream")
        body.eye(bhx + 1.5, bhy - 1.5, "gold" if not p2 else "coral", "cream", "void", 2, 2)
    else:
        body.shaded_dome(cx, cy - 10.0, 13.5, 11.0, BEETLE, bottom_cut=0.12, spec_col="lime")
        body.line(cx, cy - 20.0, cx, cy - 6.0, "night")
        body.line(cx - 10.0, cy - 10.0, cx + 10.0, cy - 10.0, "gold")
        if d == "front":
            # Front beetle head + proud central horn
            body.shaded_ellipse(cx, cy - 6.5, 7.5, 5.2, SHELL_HI)
            body.bezier_limb((cx, cy - 7.5), (cx, cy - 13.0), (cx, cy - 17.5), 2.3, 0.9, LANCE, tip_col="cream")
            body.eye(cx - 4.5, cy - 7.0, "gold" if not p2 else "coral", "cream", "void", 2, 2)
            body.eye(cx + 2.8, cy - 7.0, "gold" if not p2 else "coral", "cream", "void", 2, 2)

    # Knight rider in saddle: acorn-barbute helm, plumed crest, briar pauldron
    kx = cx - (2.0 if d == "side" else 0.0)
    ky = cy - 24.0
    # Flowing heraldic cape / saddle pennant (lagged secondary motion)
    fl = math.sin(lph) * 3.0
    if d == "side":
        body.shaded_poly([
            (kx - 4.0, ky - 1.0), (kx - 16.0, ky - 4.0 + fl),
            (kx - 18.0, ky + 4.0 + fl), (kx - 5.0, ky + 6.0),
        ], PLUME)
    else:
        body.shaded_poly([
            (kx - 7.0, ky - 2.0), (kx + 7.0, ky - 2.0),
            (kx + 9.0 + fl * 0.4, ky + 8.0), (kx - 9.0 + fl * 0.4, ky + 8.0),
        ], PLUME)

    # Knight armored torso + gold tournament baldric
    body.shaded_ellipse(kx, ky + 2.0, 7.2, 7.0, ARMOR)
    body.line(kx - 5.0, ky - 1.0, kx + 5.0, ky + 5.0, "gold")
    # Acorn-dome knight helmet
    hx, hy = kx + (1.5 if d == "side" else 0.0), ky - 7.5
    body.shaded_dome(hx, hy + 1.0, 6.6, 6.8, ARMOR, bottom_cut=0.15)
    body.shaded_ellipse(hx, hy - 4.5, 7.2, 2.6, LANCE)
    # Flowing coral-gold knight plume (kept strictly inside y >= 4)
    body.bezier_limb((hx, hy - 6.0), (hx - (7.0 if d == "side" else 4.0), hy - 11.0 + fl * 0.5), (hx - (13.0 if d == "side" else 8.0), hy - 7.0 + fl), 2.4, 0.9, PLUME, tip_col="cream")

    if d == "front":
        body.rect(hx - 4.0, hy - 1.0, 8, 2, "void", protect=True)
        body.set(hx - 2.0, hy - 0.5, "gold" if not p2 else "coral", protect=True)
        body.set(hx + 2.0, hy - 0.5, "gold" if not p2 else "coral", protect=True)
    elif d == "side":
        body.rect(hx + 1.0, hy - 1.0, 5, 2, "void", protect=True)
        body.set(hx + 4.0, hy - 0.5, "gold" if not p2 else "coral", protect=True)

    # Tournament jousting lance
    hot = p2 or ctx.is_tell or ctx.is_commit
    if d == "side":
        _draw_lance(body, kx + 5.0, ky + 1.0, lance_ang, hot, True)
    elif d == "front":
        _draw_lance(body, kx + 7.5, ky + 1.0, -72.0 + lance_ang * 0.4, hot, False)
        # Round kite shield on left arm
        body.shaded_ellipse(kx - 8.5, ky + 2.5, 4.5, 5.8, SHELL_HI)
        body.circle(kx - 8.5, ky + 2.5, 1.8, "gold", protect=True)
    else:
        _draw_lance(body, kx + 8.0, ky + 1.0, -76.0, hot, False)

    if p2:
        body.crack(cx - 5.0, cy - 14.0, cx + 4.0, cy - 8.0, "void", "gold", seed=41)
        fx_back.ring(cx, cy - 14.0, 21.0, "apricot", 1.0, 0, 360, protect=True)

    if ctx.is_tell and u > 0.35:
        gx = cx + (20.0 if d == "side" else 8.0)
        gy = ky + (0.0 if d == "side" else -12.0)
        fx_front.star4(gx, gy, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 15.0, cy - 14.0, 16.0, 11.0, -55, 55, 5.2, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 6.0, 20.0, 10.0, 15, 165, 5.0, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 8.0, 9.5, 3.0, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="knight_taproot", name="Sir Taproot", out_dir=ART_BOSSES,
    frame=(84, 68), anchor=(42, 54),
    body_radius=11.0, hit_radius=15.0, body_centre=(42, 36),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_knight_taproot,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
