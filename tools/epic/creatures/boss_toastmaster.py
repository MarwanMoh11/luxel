#!/usr/bin/env python3
"""Island 4 Set-Piece Boss: The Toastmaster Automaton (wine/cream tuxedo butler, gold monocle, teacup top hat, silver platter, nape wind-up key) — 84x80, anchor [42, 66]."""
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

TUX = ("void", "night", "plum", "wine")
SHIRT = ("mauve", "stone", "cream", "cream")
SILVER = ("deep", "blue", "sky", "ice")
GOLD = ("wine", "apricot", "gold", "cream")
PORCELAIN = ("dusk", "mauve", "stone", "cream")


def _draw_windup_key(buf: PixelBuf, kx: float, ky: float, spin_deg: float) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.rect(kx - 1.5, ky - 2.0, 7, 3, "apricot")
    tmp.ring(kx + 6.5, ky - 3.2, 3.0, "gold", 1.4, protect=True)
    tmp.ring(kx + 6.5, ky + 2.2, 3.0, "gold", 1.4, protect=True)
    tmp.set(kx + 6.5, ky - 0.5, "cream", protect=True)
    buf.composite(rotate_buf(tmp, kx, ky, spin_deg))


def _draw_platter(buf: PixelBuf, px: float, py: float, tilt_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.shaded_ellipse(px, py, 10.5, 3.4, SILVER, spec_col="cream")
    tmp.line(px - 8.5, py - 0.5, px + 8.5, py - 0.5, "cream", protect=True)
    # Cloche dome / teacup perched on platter
    tmp.shaded_dome(px, py - 1.5, 5.5, 5.2, SILVER if not hot else GOLD, bottom_cut=0.1, spec_col="cream")
    tmp.circle(px, py - 7.0, 1.5, "gold", protect=True)
    buf.composite(rotate_buf(tmp, px, py, tilt_deg))


def draw_boss_toastmaster(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 70.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    stride = math.sin(ph) * 2.5 if ctx.anim in ("routine", "phase2") else 0.0
    bob = abs(math.sin(ph)) * 1.5 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    bow_drop = 0.0
    tray_tilt = math.sin(lph) * 6.0
    key_spin = math.degrees(ph)
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -4.0 * u
        tray_tilt = -28.0 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lean = 7.5 * sm
        tray_tilt = 32.0 * sm
        sx, sy = 1.10, 0.92
    elif ctx.is_recover:
        lean = 2.5
        tray_tilt = 10.0
    elif ctx.is_stagger:
        # Signature comedy: deep compulsive 90-deg formal bow exposing nape wind-up key!
        lean = 6.0
        bow_drop = 8.5
        tray_tilt = 42.0
        key_spin = math.degrees(ph * 3.0)
        sx, sy = 1.06, 0.92

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob
    shadow.contact_shadow(ax, ay + 1.5, 13.0, 2.2, "night")

    # Crisp brass-jointed automaton legs
    if d == "side":
        body.capsule(cx - 3.0, cy - 12.0, cx - 4.0 + stride, ay - 2.0, 2.2, 1.8, TUX)
        body.capsule(cx + 3.0, cy - 12.0, cx + 4.0 - stride, ay - 2.0, 2.2, 1.8, TUX)
        body.rect(cx - 5.5 + stride, ay - 3.0, 5, 3, "night")
        body.rect(cx + 2.5 - stride, ay - 3.0, 5, 3, "night")
    else:
        body.capsule(cx - 4.5, cy - 12.0, cx - 5.5, ay - 2.0 + stride * 0.4, 2.4, 1.8, TUX)
        body.capsule(cx + 4.5, cy - 12.0, cx + 5.5, ay - 2.0 - stride * 0.4, 2.4, 1.8, TUX)
        body.rect(cx - 7.5, ay - 3.0 + stride * 0.4, 4, 3, "night")
        body.rect(cx + 3.5, ay - 3.0 - stride * 0.4, 4, 3, "night")

    # Sharp wine/cream tailcoat tuxedo torso with flared coattails!
    tx = cx
    ty = cy - 23.0 + bow_drop * 0.45
    tw = 10.0 if d != "side" else 8.5
    # Flared coattails
    sway = math.sin(lph) * 2.4
    body.shaded_poly([
        (tx - tw, ty + 4), (tx + tw, ty + 4),
        (tx + tw + 3 + sway * 0.3, ty + 16), (tx + 2, ty + 12),
        (tx - 2, ty + 12), (tx - tw - 3 + sway * 0.3, ty + 16),
    ], TUX)
    # Tailcoat torso + crisp cream waistcoat shirtfront
    body.shaded_poly([
        (tx - tw - 1, ty - 11), (tx + tw + 1, ty - 11),
        (tx + tw - 1, ty + 6), (tx - tw + 1, ty + 6),
    ], TUX)
    if d == "front":
        body.shaded_poly([(tx - 4.5, ty - 11), (tx + 4.5, ty - 11), (tx + 2.5, ty + 5), (tx - 2.5, ty + 5)], SHIRT)
        # Crimson rose bow-tie & brass waistcoat buttons
        body.poly([(tx - 4, ty - 11), (tx, ty - 9), (tx - 4, ty - 7)], "coral", protect=True)
        body.poly([(tx + 4, ty - 11), (tx, ty - 9), (tx + 4, ty - 7)], "coral", protect=True)
        body.rect(tx - 1, ty - 10, 2, 2, "gold", protect=True)
        body.set(tx, ty - 4, "gold", protect=True)
        body.set(tx, ty, "gold", protect=True)
        body.set(tx, ty + 3, "gold", protect=True)
    elif d == "side":
        body.shaded_poly([(tx + 2.0, ty - 11), (tx + 8.0, ty - 10), (tx + 6.5, ty + 5), (tx + 2.0, ty + 5)], SHIRT)
        body.rect(tx + 5.5, ty - 10, 3, 2, "coral", protect=True)
        body.set(tx + 5.0, ty - 3, "gold", protect=True)
        # Exposed golden nape wind-up key on his back!
        _draw_windup_key(body, tx - 9.0, ty - 8.0, key_spin)
    else:
        # Back view: HUGE gleaming golden wind-up key (the 2x weakpoint!)
        body.line(tx, ty - 10, tx, ty + 6, "gold")
        _draw_windup_key(body, tx + 2.0, ty - 8.0, key_spin)
        _draw_windup_key(body, tx - 2.0, ty - 8.0, 180.0 - key_spin)

    # Dapper Porcelain Automaton Head + Gold Monocle + Steaming Teacup Top Hat!
    hx = tx + (3.0 if d == "side" else 0.0)
    hy = ty - 17.5 + bow_drop * 0.55
    body.shaded_ellipse(hx, hy, 7.6 if d != "side" else 7.0, 7.2, PORCELAIN, spec_col="cream")
    if d == "front":
        # Left button eye + oversized glowing GOLD MONOCLE on right eye!
        body.eye(hx - 3.6, hy - 0.5, "night", "cream", "void", 2, 2)
        body.ring(hx + 3.0, hy - 0.5, 3.2, "gold", 1.3, protect=True)
        body.circle(hx + 3.0, hy - 0.5, 1.9, "coral" if p2 else "cream", protect=True)
        body.line(hx + 5.5, hy + 1.5, hx + 6.5, hy + 6.5, "gold")  # Monocle chain
        # Waxed gentleman moustache
        body.line(hx - 5.0, hy + 3.0, hx, hy + 2.5, "night")
        body.line(hx, hy + 2.5, hx + 5.0, hy + 3.0, "night")
    elif d == "side":
        body.ring(hx + 4.2, hy - 0.5, 3.0, "gold", 1.3, protect=True)
        body.circle(hx + 4.2, hy - 0.5, 1.7, "coral" if p2 else "cream", protect=True)
        body.line(hx + 4.5, hy + 3.0, hx + 8.5, hy + 2.5, "night")
    else:
        body.line(hx - 4.0, hy + 2.0, hx + 4.0, hy + 2.0, "gold")

    # Signature TEACUP & SAUCER TOP HAT!
    hat_y = hy - 7.0
    body.shaded_ellipse(hx, hat_y, 11.0, 2.8, PORCELAIN, spec_col="cream")  # Saucer brim
    body.line(hx - 9.0, hat_y, hx + 9.0, hat_y, "gold")
    body.shaded_poly([
        (hx - 7.0, hat_y - 9.5), (hx + 7.0, hat_y - 9.5),
        (hx + 5.5, hat_y - 0.5), (hx - 5.5, hat_y - 0.5),
    ], PORCELAIN)
    body.line(hx - 6.0, hat_y - 8.5, hx + 6.0, hat_y - 8.5, "gold", protect=True)
    body.line(hx - 5.5, hat_y - 3.5, hx + 5.5, hat_y - 3.5, "wine")
    # Teacup ear handle on right side
    body.ring(hx + 7.5, hat_y - 5.0, 2.6, "gold", 1.2, -90, 90)
    # Gentle steam curls from teacup hat (stronger in P2!)
    for sk in range(3 if p2 else 2):
        sy_off = max(4.0, hat_y - 10.5 - sk * 2.4 - math.sin(ph + sk) * 0.9)
        sx_off = hx - 2.0 + sk * 2.2 + math.sin(lph + sk * 1.5) * 1.8
        fx_front.circle(sx_off, sy_off, 1.3 if p2 else 1.0, "cream" if sk == 0 else "ice", protect=True)

    # White-gloved arms holding Silver Platter (and corked bottle)
    if d == "front":
        body.capsule(tx - 10.0, ty - 7.0, tx - 15.0, ty - 1.0, 2.2, 2.0, TUX)
        body.circle(tx - 15.5, ty - 0.5, 2.2, "cream")
        _draw_platter(body, tx - 17.5, ty - 4.0, -tray_tilt, p2 or ctx.is_tell)
        # Champagne cork bottle in right hand
        body.capsule(tx + 10.0, ty - 7.0, tx + 15.0, ty - 2.0, 2.2, 2.0, TUX)
        body.circle(tx + 15.5, ty - 1.5, 2.2, "cream")
        body.shaded_rect(tx + 14.0, ty - 11.0, 4, 9, ("pine", "teal", "jade", "lime"))
        body.rect(tx + 15.0, ty - 13.0, 2, 2, "gold", protect=True)
    elif d == "side":
        body.capsule(tx + 5.0, ty - 7.0, tx + 13.0, ty - 4.0, 2.2, 2.0, TUX)
        body.circle(tx + 14.0, ty - 3.5, 2.2, "cream")
        _draw_platter(body, tx + 17.0, ty - 6.5, tray_tilt, p2 or ctx.is_tell)
    else:
        body.capsule(tx - 10.0, ty - 7.0, tx - 15.0, ty - 1.0, 2.2, 2.0, TUX)
        body.capsule(tx + 10.0, ty - 7.0, tx + 15.0, ty - 1.0, 2.2, 2.0, TUX)
        _draw_platter(body, tx + 17.0, ty - 4.0, tray_tilt, p2 or ctx.is_tell)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.30:
        fx_front.star4(hx + (5 if d == "side" else 3), hy - 0.5, 4 if u > 0.72 else 3, "cream", "gold")
        fx_front.ring(tx + (14 if d == "side" else -16), ty - 5.0, 7.0 + u * 4.0, "ice", 1.1, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(tx + 11, ty - 6, 20, 14, -64, 64, 5.2, ("sky", "ice", "cream"))
        else:
            fx_front.slash_arc(tx, ty - 4, 24, 12, 10, 170, 5.2, ("apricot", "gold", "cream"))
        for k in range(3):
            fx_front.circle(tx + (14 if d == "side" else 14) + k * 3, ty - 14 - k * 2, 1.5, "gold" if k % 2 == 0 else "cream", protect=True)
    elif ctx.is_stagger:
        # Spinning golden wind-up sparkle above his bowed nape!
        fx_front.dizzy_stars(hx, hat_y - 12.0, 10.0, 3.0, ph)
        fx_front.star4(tx - (9 if d == "side" else 0), ty - 9.0, 3, "cream", "gold")

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="boss_toastmaster", name="The Toastmaster", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 70),
    body_radius=10.0, hit_radius=14.5, body_centre=(42, 46),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="wine",
    draw_frame=draw_boss_toastmaster,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
