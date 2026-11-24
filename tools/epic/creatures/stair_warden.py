#!/usr/bin/env python3
"""Island 8 Boss: The Stair Warden (armoured cathedral halberdier -> prism lancer -> eclipse sovereign) — 104x100, anchor [52, 82]."""
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

ARMOUR = ("night", "dusk", "mauve", "stone")
SURCOAT = ("void", "night", "deep", "blue")
SOVEREIGN = ("void", "night", "plum", "wine")
BRASS = ("plum", "coral", "apricot", "gold")
PRISM = ("deep", "blue", "sky", "ice")


def _draw_halberd_lance(buf: PixelBuf, px: float, py: float, deg: float, p2: bool, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Long gothic cathedral polearm haft
    tmp.capsule(px, py + 20, px, py - 24, 1.4, 1.4, BRASS)
    # Halberd crescent axe-blade + tall prism lance spearhead
    blade_ramp = PRISM if p2 else BRASS
    tmp.shaded_poly([
        (px - 2, py - 23), (px, py - 35), (px + 2, py - 23),
    ], blade_ramp)
    tmp.shaded_poly([
        (px + 1, py - 25), (px + 11, py - 22), (px + 9, py - 12), (px + 1, py - 15),
    ], blade_ramp)
    # Rear counterweight spike
    tmp.shaded_poly([
        (px - 1, py - 21), (px - 7, py - 19), (px - 1, py - 16),
    ], BRASS)
    if p2 or hot:
        tmp.line(px, py - 35, px, py - 22, "cream", protect=True)
        tmp.line(px + 9, py - 21, px + 8, py - 13, "ice" if p2 else "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, deg))


def _draw_kite_buckler(buf: PixelBuf, bx: float, by: float, tilt: float, p2: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.shaded_poly([
        (bx - 7, by - 10), (bx + 7, by - 10),
        (bx + 6, by + 2), (bx, by + 11), (bx - 6, by + 2),
    ], ARMOUR)
    tmp.line(bx - 6, by - 9, bx + 6, by - 9, "rose" if p2 else "gold")
    tmp.line(bx, by - 8, bx, by + 9, "sky" if p2 else "gold", protect=True)
    tmp.circle(bx, by - 2, 2.2, "cream" if p2 else "gold", protect=True)
    buf.composite(rotate_buf(tmp, bx, by, tilt))


def draw_stair_warden(ctx: FrameCtx) -> Image.Image:
    w, h = 112, 112
    ax, ay = 56.0, 94.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    stride = math.sin(ph) * 2.5 if ctx.anim in ("routine", "phase2") else 0.0
    bob = abs(math.sin(ph)) * 1.8 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    lance_deg = 12.0 + math.sin(lph) * 4.0
    shield_deg = -6.0 + math.sin(lph) * 3.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        bob = 1.0
        lean = -5.0 * u
        lance_deg = -46.0 * u if d == "side" else (-28.0 * u)
        shield_deg = -18.0 * u
        sx, sy = 0.94, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        lean = 5.0 * sm
        lance_deg = 56.0 * sm if d == "side" else (42.0 * sm)
        shield_deg = 16.0 * sm
        sx, sy = 1.08, 0.93
    elif ctx.is_recover:
        bob = -2.2
        lance_deg = 32.0
        lean = 2.0
    elif ctx.is_stagger:
        bob = -5.0
        lance_deg = -14.0
        lean = math.sin(ph * 2.0) * 2.2

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 10.0 - bob
    shadow.contact_shadow(ax, ay + 2.0, 16.0, 2.8, "night")

    # Sovereign Eclipse Halo behind helm in phase2
    if p2:
        fx_back.ring(cx, cy - 35.0, 15.0, "rose", 1.5, protect=True)
        fx_back.ring(cx, cy - 35.0, 12.0, "sky", 1.1, protect=True)
        for k in range(6):
            a = ph + k * (math.tau / 6.0)
            fx_back.rect(cx + math.cos(a) * 16.0 - 1, cy - 35.0 + math.sin(a) * 16.0 - 1, 2, 2, "cream", protect=True)

    # Billowing cathedral knight cloak (behind)
    cloak_sw = math.sin(lph) * 3.2
    cloak_ramp = SOVEREIGN if p2 else SURCOAT
    if d == "side":
        body.shaded_poly([
            (cx - 5, cy - 28), (cx - 17 + cloak_sw * 0.4, cy - 6),
            (cx - 14 + cloak_sw, cy + 7), (cx - 2, cy + 2),
        ], cloak_ramp)
    else:
        body.shaded_poly([
            (cx - 14, cy - 27), (cx + 14, cy - 27),
            (cx + 17 + cloak_sw * 0.5, cy + 5), (cx + 8 + cloak_sw, cy + 9),
            (cx - 8 + cloak_sw, cy + 9), (cx - 17 + cloak_sw * 0.5, cy + 5),
        ], cloak_ramp)

    # Sculpted gothic armoured greaves & flared sabatons
    leg_l = stride if d == "side" else -stride * 0.6
    leg_r = -stride if d == "side" else stride * 0.6
    body.shaded_poly([
        (cx - 8, cy - 5 + leg_l), (cx - 2, cy - 5 + leg_l),
        (cx - 3, cy + 7 + leg_l), (cx - 9, cy + 7 + leg_l),
    ], ARMOUR)
    body.shaded_poly([
        (cx + 2, cy - 5 + leg_r), (cx + 8, cy - 5 + leg_r),
        (cx + 9, cy + 7 + leg_r), (cx + 3, cy + 7 + leg_r),
    ], ARMOUR)
    # Knee poleyns & gilded sabaton tips
    body.rect(cx - 8, cy - 1 + leg_l, 5, 2, "sky" if p2 else "gold")
    body.rect(cx + 3, cy - 1 + leg_r, 5, 2, "sky" if p2 else "gold")
    body.shaded_poly([(cx - 10, cy + 7 + leg_l), (cx - 2, cy + 7 + leg_l), (cx - 2, cy + 10 + leg_l), (cx - 11, cy + 10 + leg_l)], BRASS if not p2 else PRISM)
    body.shaded_poly([(cx + 2, cy + 7 + leg_r), (cx + 10, cy + 7 + leg_r), (cx + 11, cy + 10 + leg_r), (cx + 2, cy + 10 + leg_r)], BRASS if not p2 else PRISM)

    # Broad Gothic Cuirass & Tabard
    cw = 13.0 if d != "side" else 9.5
    body.shaded_poly([
        (cx - cw, cy - 27), (cx + cw, cy - 27),
        (cx + cw * 0.78, cy - 4), (cx - cw * 0.78, cy - 4),
    ], ARMOUR)
    # Tabard with spiral-stair gold chevron trim
    body.shaded_rect(cx - 5, cy - 23, 10, 21, cloak_ramp)
    trim_c = "rose" if p2 else "gold"
    body.line(cx - 5, cy - 18, cx + 5, cy - 14, trim_c)
    body.line(cx - 5, cy - 12, cx + 5, cy - 8, trim_c)
    body.line(cx - 5, cy - 6, cx + 5, cy - 2, "sky" if p2 else trim_c)

    # Towering Cathedral Pauldrons
    if d != "side":
        body.shaded_dome(cx - 14, cy - 23, 7.0, 6.5, ARMOUR, bottom_cut=0.2)
        body.shaded_dome(cx + 14, cy - 23, 7.0, 6.5, ARMOUR, bottom_cut=0.2)
        body.line(cx - 19, cy - 24, cx - 9, cy - 24, trim_c)
        body.line(cx + 9, cy - 24, cx + 19, cy - 24, trim_c)
    else:
        body.shaded_dome(cx + 2, cy - 23, 7.5, 6.5, ARMOUR, bottom_cut=0.2)
        body.line(cx - 3, cy - 24, cx + 8, cy - 24, trim_c)

    # Spire-Crest Greathelm
    hx = cx + (2.5 if d == "side" else 0.0)
    hy = cy - 35.0
    body.shaded_dome(hx, hy + 2.0, 8.2 if d != "side" else 7.8, 9.5, ARMOUR, bottom_cut=0.05)
    # Stepped cathedral spiral-spire helm crest!
    body.shaded_poly([
        (hx - 4, hy - 6), (hx - 2, hy - 15), (hx, hy - 20), (hx + 2, hy - 15), (hx + 4, hy - 6),
    ], BRASS if not p2 else PRISM)
    body.rect(hx - 1, hy - 20, 2, 3, "cream", protect=True)

    if d == "front":
        body.rect(hx - 6, hy - 2, 12, 3, "void", protect=True)
        body.line(hx - 4, hy - 1, hx + 4, hy - 1, "ice" if p2 else "gold", protect=True)
        body.rect(hx - 1, hy - 1, 2, 1, "cream", protect=True)
    elif d == "side":
        body.rect(hx + 1, hy - 2, 7, 3, "void", protect=True)
        body.line(hx + 2, hy - 1, hx + 7, hy - 1, "ice" if p2 else "gold", protect=True)
    else:
        body.line(hx, hy - 7, hx, hy + 4, trim_c)

    # Halberd-Lance & Buckler layered cleanly by facing
    hot = p2 or ctx.is_tell or ctx.is_commit
    if d == "front":
        _draw_kite_buckler(body, cx - 16.0, cy - 11.0, shield_deg, p2)
        _draw_halberd_lance(body, cx + 17.0, cy - 14.0, lance_deg, p2, hot)
    elif d == "side":
        _draw_kite_buckler(fx_back, cx - 8.0, cy - 13.0, -shield_deg, p2)
        _draw_halberd_lance(body, cx + 12.0, cy - 14.0, lance_deg, p2, hot)
    else:
        _draw_halberd_lance(body, cx - 17.0, cy - 14.0, -lance_deg, p2, hot)
        _draw_kite_buckler(body, cx + 16.0, cy - 11.0, -shield_deg, p2)

    if ctx.is_tell and u > 0.25:
        tip_x = cx + (18.0 if d == "side" else 17.0)
        tip_y = cy - 36.0
        fx_front.star4(tip_x, tip_y, 3 if u > 0.65 else 2, "cream", "ice" if p2 else "gold")
        fx_front.ring(cx, cy - 16, 24.0 - u * 6.0, "sky" if p2 else "gold", 1.2, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        cols = ("sky", "ice", "cream") if p2 else ("coral", "gold", "cream")
        if d == "side":
            fx_front.slash_arc(cx + 10, cy - 16, 22, 17, -78, 74, 5.8, cols)
        else:
            fx_front.slash_arc(cx, cy - 12, 28, 15, 5, 175, 5.8, cols)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 18, 12.0, 3.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=p2, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="stair_warden", name="The Stair Warden", out_dir=ART_BOSSES,
    frame=(112, 112), anchor=(56, 94),
    body_radius=12.5, hit_radius=16.5, body_centre=(56, 62),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="night",
    draw_frame=draw_stair_warden,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
