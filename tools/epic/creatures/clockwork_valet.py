#!/usr/bin/env python3
"""Island 1 Mini-Boss: The Clockwork Valet (Manor r5) — 76x76, anchor [38, 60]."""
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

COAT = ("void", "night", "dusk", "plum")
LAPEL = ("night", "dusk", "plum", "mauve")
BRASS = ("plum", "coral", "apricot", "gold")
GOLD_KEY = ("wine", "apricot", "gold", "cream")
SILVER = ("dusk", "mauve", "stone", "cream")
LENS = ("deep", "blue", "sky", "ice")


def _draw_winding_key(buf: PixelBuf, kx: float, ky: float, spin_deg: float, side_view: bool, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ramp = ("apricot", "gold", "cream") if hot else GOLD_KEY
    if side_view:
        # Stem jutting cleanly out the back (left of spine in right-facing side view)
        tmp.capsule(kx, ky, kx - 10.0, ky - 1.0, 1.5, 1.5, ramp)
        # Ornate T-bow handle
        bow_h = 5.5 + 1.5 * abs(math.cos(math.radians(spin_deg)))
        tmp.shaded_ellipse(kx - 12.5, ky - 1.0 - bow_h * 0.55, 2.8, 3.0, ramp, spec_col="cream")
        tmp.shaded_ellipse(kx - 12.5, ky - 1.0 + bow_h * 0.55, 2.8, 3.0, ramp, spec_col="cream")
        tmp.circle(kx - 12.5, ky - 1.0 - bow_h * 0.55, 1.1, "night")
        tmp.circle(kx - 12.5, ky - 1.0 + bow_h * 0.55, 1.1, "night")
    else:
        # Back view: full ornate brass double-loop clockwork key!
        tmp.circle(kx, ky, 3.2, "night")
        tmp.circle(kx, ky, 2.0, "gold", protect=True)
        tmp.capsule(kx - 9.0, ky, kx + 9.0, ky, 1.6, 1.6, ramp)
        tmp.shaded_ellipse(kx - 8.5, ky, 4.2, 5.2, ramp, spec_col="cream")
        tmp.shaded_ellipse(kx + 8.5, ky, 4.2, 5.2, ramp, spec_col="cream")
        tmp.circle(kx - 8.5, ky, 2.0, "night")
        tmp.circle(kx + 8.5, ky, 2.0, "night")
    buf.composite(rotate_buf(tmp, kx, ky, spin_deg if not side_view else 0.0))


def _draw_silver_tray(buf: PixelBuf, tx: float, ty: float, ang_deg: float, hot: bool, scale_x: float = 1.0) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ramp = ("sky", "ice", "cream") if hot else SILVER
    rx = max(2.2, 6.2 * scale_x)
    ry = 9.2
    tmp.shaded_ellipse(tx, ty, rx, ry, ramp, spec_col="cream")
    tmp.ring(tx, ty, min(rx, ry) * 0.72, "gold" if hot else "mauve", 1.0)
    tmp.line(tx - rx * 0.45, ty - ry * 0.55, tx + rx * 0.35, ty - ry * 0.35, "cream", protect=True)
    buf.composite(rotate_buf(tmp, tx, ty, ang_deg))


def _draw_feather_duster(buf: PixelBuf, dx: float, dy: float, ang_deg: float) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.capsule(dx, dy, dx + 8.0, dy - 7.0, 1.0, 1.1, BRASS)
    for ox, oy, col in [(9.0, -9.0, "coral"), (11.0, -7.5, "rose"), (8.0, -11.0, "cream"), (10.5, -10.5, "gold")]:
        tmp.circle(dx + ox, dy + oy, 2.3, col, protect=True)
    buf.composite(rotate_buf(tmp, dx, dy, ang_deg))


def draw_clockwork_valet(ctx: FrameCtx) -> Image.Image:
    w, h = 80, 82
    ax, ay = 40.0, 68.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = abs(math.sin(ph)) * 1.4 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    bow = 0.0
    tray_ang = math.sin(ph) * 5.0
    tray_push = 0.0
    key_spin = math.degrees(ph) * 0.5
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        lean = -3.2 * u
        tray_ang = -26.0 * u
        tray_push = -2.5 * u
        sx, sy = 0.96, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lean = 7.5 * sm
        tray_ang = 44.0 * sm
        tray_push = 8.5 * sm
        sx, sy = 1.09, 0.93
    elif ctx.is_recover:
        # Formal polite bow exposing the gold winding key!
        bow = 7.5
        lean = 4.5
        tray_ang = 30.0
        key_spin = math.degrees(ph) * 1.2
    elif ctx.is_stagger:
        bow = 5.0 + math.sin(ph * 2.0) * 1.8
        lean = math.sin(ph * 2.0) * 2.5
        key_spin = math.degrees(ph) * 3.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob + bow * 0.35
    shadow.contact_shadow(ax, ay + 1.5, 13.5, 2.2, "night")

    # Slender mechanical brass-jointed legs & polished spats
    stride = math.sin(ph) * 3.0 if ctx.anim in ("routine", "phase2") else 0.0
    if d == "side":
        body.capsule(cx - 2.0, cy - 15.0, cx - 3.5 + stride, ay - 2.0, 2.0, 1.6, COAT)
        body.capsule(cx + 2.5, cy - 15.0, cx + 4.0 - stride, ay - 1.5, 2.0, 1.6, COAT)
        body.shaded_ellipse(cx - 2.5 + stride, ay - 1.2, 3.8, 2.0, SILVER)
        body.shaded_ellipse(cx + 5.0 - stride, ay - 1.0, 3.8, 2.0, SILVER)
    else:
        body.capsule(cx - 4.5, cy - 15.0, cx - 5.0, ay - 2.0 + stride * 0.4, 2.0, 1.6, COAT)
        body.capsule(cx + 4.5, cy - 15.0, cx + 5.0, ay - 2.0 - stride * 0.4, 2.0, 1.6, COAT)
        body.shaded_ellipse(cx - 5.2, ay - 1.2 + stride * 0.4, 3.2, 2.0, SILVER)
        body.shaded_ellipse(cx + 5.2, ay - 1.2 - stride * 0.4, 3.2, 2.0, SILVER)

    # Flowing swallowtail plum tailcoat hems (lagging secondary motion)
    tail_sway = math.sin(lph) * 2.5
    if d == "side":
        tail_pts = [
            (cx - 3.0, cy - 22.0), (cx - 12.0 + tail_sway, cy - 7.0),
            (cx - 7.0 + tail_sway, cy - 4.0), (cx + 1.0, cy - 14.0),
        ]
        body.shaded_poly(tail_pts, COAT)
    else:
        for sgn in (-1.0, 1.0):
            tpts = [
                (cx + sgn * 3.0, cy - 19.0), (cx + sgn * 10.5 + tail_sway * 0.5, cy - 5.0),
                (cx + sgn * 5.0 + tail_sway * 0.4, cy - 4.0), (cx + sgn * 1.5, cy - 14.0),
            ]
            body.shaded_poly(tpts, COAT)

    # Tailored slender hourglass torso + crisp waistcoat
    torso_w = 8.2 if d != "side" else 6.8
    body.shaded_poly([
        (cx - torso_w, cy - 35.0), (cx + torso_w, cy - 35.0),
        (cx + torso_w * 0.72, cy - 16.0), (cx - torso_w * 0.72, cy - 16.0),
    ], COAT)
    # Shoulder epaulettes in gilded brass
    body.shaded_ellipse(cx - torso_w * 0.9, cy - 33.5, 3.2, 2.4, BRASS)
    body.shaded_ellipse(cx + torso_w * 0.9, cy - 33.5, 3.2, 2.4, BRASS)

    if d == "front":
        # Ivory cravat & brass waistcoat buttons
        body.shaded_poly([(cx - 3.5, cy - 35.0), (cx + 3.5, cy - 35.0), (cx, cy - 25.0)], SILVER)
        for by in (-29.0, -25.0, -21.0):
            body.set(cx, cy + by, "gold", protect=True)
        body.line(cx - 5.5, cy - 34.0, cx - 2.0, cy - 24.0, "mauve")
        body.line(cx + 5.5, cy - 34.0, cx + 2.0, cy - 24.0, "mauve")
    elif d == "side":
        body.shaded_poly([(cx + 2.0, cy - 34.0), (cx + 6.5, cy - 33.0), (cx + 5.0, cy - 23.0), (cx + 1.5, cy - 24.0)], LAPEL)
        body.line(cx + 5.5, cy - 33.0, cx + 4.5, cy - 22.0, "gold")
        # HUGE gleaming gold winding key behind spine!
        _draw_winding_key(body, cx - 5.0, cy - 26.0, key_spin, True, hot=(ctx.is_recover or ctx.is_stagger or p2))
    else:
        # Back brass gearbox plate + iconic winding key!
        body.shaded_rect(cx - 5.0, cy - 31.0, 10, 10, BRASS)
        _draw_winding_key(body, cx, cy - 26.0, key_spin, False, hot=(ctx.is_recover or ctx.is_stagger or p2))

    # Crisp clockwork head + tall velvet-plum butler top-hat / brass crown rim
    hx = cx + (3.2 if d == "side" else 0.0) + (bow * 0.45 if d == "side" else 0.0)
    hy = cy - 42.5 + bow * 0.55
    body.shaded_ellipse(hx, hy, 6.2 if d != "side" else 5.8, 6.4, BRASS, spec_col="cream")
    # Neat plum top-hat with gold hatband
    body.shaded_ellipse(hx, hy - 5.5, 9.2, 2.2, COAT)
    body.shaded_rect(hx - 5.5, hy - 14.5, 11, 9, COAT)
    body.line(hx - 5.5, hy - 7.0, hx + 5.5, hy - 7.0, "gold", protect=True)
    body.line(hx - 4.5, hy - 13.5, hx + 3.5, hy - 13.5, "mauve")

    # Iconic spotlight monocle lens & moustache ticks
    mono_hot = ctx.is_tell or ctx.is_commit or p2
    if d == "front":
        body.eye(hx - 3.2, hy - 0.8, "gold", "cream", "void", 2, 2)
        # Oversized spotlight monocle on right eye
        body.circle(hx + 2.8, hy - 0.8, 3.3, "gold")
        body.circle(hx + 2.8, hy - 0.8, 2.2, "cream" if mono_hot else "ice", protect=True)
        body.set(hx + 2.2, hy - 1.4, "cream", protect=True)
        # Prim brass moustache
        body.line(hx - 4.0, hy + 2.8, hx + 4.0, hy + 2.8, "night")
        body.set(hx - 4.5, hy + 2.2, "gold")
        body.set(hx + 4.5, hy + 2.2, "gold")
    elif d == "side":
        body.circle(hx + 4.0, hy - 1.0, 3.2, "gold")
        body.circle(hx + 4.0, hy - 1.0, 2.1, "cream" if mono_hot else "ice", protect=True)
        body.line(hx + 2.5, hy + 2.6, hx + 6.5, hy + 2.0, "gold")
        if mono_hot and not ctx.is_stagger:
            # Crisp monocle spotlight beam rays (hollow optical gleam, not a solid wedge)
            bc = "gold" if p2 else "ice"
            fx_front.line(hx + 6.5, hy - 1.5, hx + 20.0, hy - 7.5, bc, protect=True)
            fx_front.line(hx + 6.5, hy - 0.5, hx + 20.0, hy + 5.5, bc, protect=True)
            fx_front.line(hx + 7.0, hy - 1.0, hx + 18.0, hy - 1.0, "cream", protect=True)
            fx_front.set(hx + 21.0, hy - 4.0, "cream", protect=True)
            fx_front.set(hx + 21.0, hy + 2.5, "cream", protect=True)
    else:
        body.line(hx - 3.5, hy - 1.5, hx + 3.5, hy - 1.5, "gold")

    # Twin silver serving trays (or frantic feather duster during stagger!)
    hot_tray = ctx.is_tell or ctx.is_commit or p2
    if ctx.is_stagger:
        # Comedy beat: furiously dusting scorch marks with a tiny feather duster!
        duster_ang = math.sin(ph * 3.0) * 32.0
        _draw_feather_duster(body, cx + (7.0 if d == "side" else 8.0), cy - 23.0, duster_ang)
        if d != "side":
            _draw_silver_tray(body, cx - 12.0, cy - 20.0, -35.0, False, 0.72)
    else:
        if d == "front":
            _draw_silver_tray(body, cx - 11.5 - tray_push * 0.3, cy - 25.0, -tray_ang - 12.0, hot_tray, 0.85)
            _draw_silver_tray(body, cx + 11.5 + tray_push * 0.3, cy - 25.0, tray_ang + 12.0, hot_tray, 0.85)
        elif d == "side":
            # Back tray slightly behind torso, front tray held forward like a buckler
            _draw_silver_tray(fx_back, cx + 7.0 + tray_push * 0.4, cy - 27.0, tray_ang - 14.0, hot_tray, 0.55)
            _draw_silver_tray(body, cx + 11.0 + tray_push, cy - 24.0, tray_ang, hot_tray, 0.65)
        else:
            _draw_silver_tray(body, cx - 12.0, cy - 25.0, -10.0, hot_tray, 0.65)
            _draw_silver_tray(body, cx + 12.0, cy - 25.0, 10.0, hot_tray, 0.65)

    if p2:
        body.crack(cx - 3, cy - 30, cx + 4, cy - 21, "void", "coral", seed=23)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 18, cy - 26 + math.sin(a) * 12, "ice" if k % 2 == 0 else "gold", protect=True)

    if ctx.is_tell and u > 0.35:
        gx = hx + (9 if d == "side" else 3)
        fx_front.star4(gx, hy - 2, 3 if u > 0.72 else 2, "cream", "ice")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy - 22, 18, 15, -62, 62, 5.2, ("sky", "ice", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 18, 22, 12, 10, 170, 5.0, ("gold", "ice", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 16, 10.0, 3.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="clockwork_valet", name="The Clockwork Valet", out_dir=ART_BOSSES,
    frame=(80, 82), anchor=(40, 68),
    body_radius=10.5, hit_radius=14.0, body_centre=(40, 44),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_clockwork_valet,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
