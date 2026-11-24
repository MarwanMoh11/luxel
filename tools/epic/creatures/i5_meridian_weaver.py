#!/usr/bin/env python3
"""Island 5 Mini-Boss: Meridian Weaver (tall brass drafting-compass spider with plum-glass lens) — 88x80, anchor [44, 64]."""
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

BRASS = ("plum", "coral", "apricot", "gold")
DARK_BRASS = ("night", "plum", "wine", "apricot")
STEEL = ("deep", "blue", "sky", "ice")
LENS_PLUM = ("void", "night", "dusk", "plum")
LENS_HOT = ("plum", "wine", "coral", "gold")


def _draw_caliper_leg(
    buf: PixelBuf,
    hip: tuple[float, float],
    knee: tuple[float, float],
    foot: tuple[float, float],
    ramp: tuple[str, ...],
    thick: float = 2.2,
) -> None:
    buf.capsule(hip[0], hip[1], knee[0], knee[1], thick, thick * 0.78, ramp)
    buf.capsule(knee[0], knee[1], foot[0], foot[1], thick * 0.78, 0.9, ramp)
    # Brass hinge rivet at knee + crisp ice steel drafting needle tip at foot
    buf.circle(knee[0], knee[1], 1.7, "gold")
    buf.set(knee[0], knee[1] - 0.5, "cream", protect=True)
    buf.line(foot[0], foot[1], foot[0], foot[1] + 2.5, "ice", protect=True)


def draw_meridian_weaver(ctx: FrameCtx) -> Image.Image:
    w, h = 88, 80
    ax, ay = 44.0, 64.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = math.sin(ph) * 2.2 if ctx.anim in ("routine", "phase2") else 0.0
    stride = math.sin(ph) * 5.0 if ctx.anim in ("routine", "phase2") else 0.0
    spread = 0.0
    drop = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        # Caliper legs open wide 90 deg, body lifts high
        spread = 9.0 * u
        drop = -5.0 * u
        sx, sy = 0.95, 1.07
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        spread = -6.0 * sm
        drop = 4.5 * sm
        sx, sy = 1.08, 0.92
    elif ctx.is_recover:
        drop = 5.5
        spread = 3.0
    elif ctx.is_stagger:
        # Comedic void-flail: legs windmill upward while body sinks onto bell!
        drop = 8.5 + math.sin(ph * 2.0) * 1.8
        spread = 6.0

    cx = ax + (4.0 * math.sin(min(1.0, u * 1.5) * math.pi) if (ctx.is_commit and d == "side") else 0.0)
    cy = ay - 22.0 + bob + drop
    shadow.contact_shadow(ax, ay + 2.0, 20.0, 2.6, "night")

    # Phase 2 orbiting ink-compass ring behind body
    if p2:
        fx_back.ring(cx, cy, 22.0, "plum", 1.2)
        for k in range(4):
            a = ph + k * math.pi * 0.5
            px = cx + math.cos(a) * 21.0
            py = cy + math.sin(a) * 14.0
            fx_back.rect(px - 1, py - 1, 2, 2, "ice" if k % 2 == 0 else "gold", protect=True)

    # ---- Six articulated brass caliper legs ----
    if d == "side":
        # Back 3 legs (darker brass)
        for li in range(3):
            ox = -8.0 + li * 8.0
            step = math.sin(ph + li * 2.1) * (4.5 if ctx.anim in ("routine", "phase2") else 0.0)
            if ctx.is_stagger:
                flail = math.sin(ph * 3.0 + li * 1.8) * 10.0
                _draw_caliper_leg(body, (cx + ox, cy + 4), (cx + ox - 6, cy - 8 + flail), (cx + ox - 13, cy - 16 + flail), DARK_BRASS, 1.8)
            else:
                kx = cx + ox * 1.35 + step * 0.5 - (spread * 0.4 if li == 0 else (-spread * 0.4 if li == 2 else 0.0))
                ky = cy + 6.0 - (3.0 if li == 1 else 0.0)
                fx_p = cx + ox * 1.9 + step + (spread * 0.7 if li == 2 else (-spread * 0.6 if li == 0 else 0.0))
                fy_p = ay - 2.0 - (5.0 if (ctx.is_tell and li == 2) else 0.0)
                _draw_caliper_leg(body, (cx + ox, cy + 4), (kx, ky), (fx_p, fy_p), DARK_BRASS, 1.9)
        # Front 3 primary caliper legs (bright brass)
        for li in range(3):
            ox = -6.0 + li * 8.0
            step = math.sin(ph + li * 2.1 + math.pi) * (5.5 if ctx.anim in ("routine", "phase2") else 0.0)
            if ctx.is_stagger:
                flail = math.cos(ph * 3.0 + li * 1.6) * 9.0
                _draw_caliper_leg(body, (cx + ox, cy + 5), (cx + ox + 10, cy - 6 + flail), (cx + ox + 17, cy - 14 + flail), BRASS, 2.2)
            else:
                kx = cx + ox * 1.55 + step * 0.5 + (spread * 0.6 if li == 2 else (-spread * 0.5 if li == 0 else 0.0))
                ky = cy + 3.0 - (5.0 if (ctx.is_tell and li == 2) else 0.0)
                fx_p = cx + ox * 2.15 + step + (spread * 0.8 if li == 2 else (-spread * 0.7 if li == 0 else 0.0))
                fy_p = ay - (7.0 if (ctx.is_tell and li == 2) else 0.0)
                _draw_caliper_leg(body, (cx + ox, cy + 5), (kx, ky), (fx_p, fy_p), BRASS, 2.3)
    else:
        # Front / Back: symmetric 3 pairs of tall arching brass drafting-compass legs!
        for sgn in (-1.0, 1.0):
            for tier, (hip_y, knee_dx, knee_dy, foot_dx, foot_dy, ramp) in enumerate([
                (2.0, 15.0, -7.0, 23.0, 22.0, DARK_BRASS),
                (5.0, 18.0, 0.0, 25.0, 26.0, BRASS),
                (7.0, 13.0, 9.0, 16.0, 28.0, BRASS),
            ]):
                step = math.sin(ph + tier * 1.9 + (0.0 if sgn > 0 else math.pi)) * (3.5 if ctx.anim in ("routine", "phase2") else 0.0)
                if ctx.is_stagger:
                    flail = math.sin(ph * 3.2 + tier * 1.7 + sgn) * 8.0
                    _draw_caliper_leg(
                        body,
                        (cx + sgn * 7.0, cy + hip_y),
                        (cx + sgn * (knee_dx + 3.0), cy - 8.0 + flail * 0.5),
                        (cx + sgn * (foot_dx + 1.0), cy - 17.0 + flail),
                        ramp, 2.1,
                    )
                else:
                    kx = cx + sgn * (knee_dx + spread * 0.55)
                    ky = cy + knee_dy + step * 0.5 - (3.5 if ctx.is_tell else 0.0)
                    fx_p = cx + sgn * (foot_dx + spread * 0.75)
                    fy_p = min(ay + 1.0, cy + foot_dy + step) - (4.0 if (ctx.is_tell and tier == 2) else 0.0)
                    _draw_caliper_leg(body, (cx + sgn * 7.0, cy + hip_y), (kx, ky), (fx_p, fy_p), ramp, 2.2)

    # ---- Central Brass Drafting Protractor Arc & Compass Hinge Crown ----
    # Protractor semi-ring framing upper thorax
    body.ring(cx, cy - 2.0, 14.5, "gold", 2.0, 195, 345)
    body.ring(cx, cy - 2.0, 12.2, "apricot", 1.0, 200, 340)
    # Tall brass drafting-compass hinge screw & finial on top!
    body.shaded_rect(cx - 3.5, cy - 21.0, 7.0, 9.0, BRASS)
    body.circle(cx, cy - 21.5, 4.2, "gold")
    body.circle(cx, cy - 21.5, 2.2, "night")
    body.set(cx - 0.5, cy - 22.0, "cream", protect=True)
    # Secondary-motion plumb line tassel hanging beneath thorax
    tassel_x = cx + math.sin(lph) * 4.0
    body.line(cx, cy + 10.0, tassel_x, cy + 19.0, "sky")
    body.shaded_poly([(tassel_x - 2.5, cy + 18.0), (tassel_x + 2.5, cy + 18.0), (tassel_x, cy + 23.0)], STEEL)

    # ---- Main Plum-Glass Celestial Housing Body ----
    body.shaded_ellipse(cx, cy, 11.5 if d != "side" else 12.5, 10.5, DARK_BRASS)
    body.ring(cx, cy, 10.2, "gold", 1.5)

    if d == "back":
        # Back view: brass astrolabe gear dial + glowing star-chart calibration core
        body.shaded_ellipse(cx, cy, 7.8, 7.4, LENS_PLUM)
        body.ring(cx, cy, 6.2, "sky", 1.2)
        for k in range(4):
            a = lph + k * math.pi * 0.5
            body.line(cx, cy, cx + math.cos(a) * 6.0, cy + math.sin(a) * 6.0, "gold")
        body.circle(cx, cy, 2.2, "cream" if p2 else "ice", protect=True)
    else:
        ex_off = 3.5 if d == "side" else 0.0
        # Glowing plum-glass body lens with golden meridian crosshair eye!
        body.shaded_ellipse(cx + ex_off, cy, 7.6, 7.6, LENS_HOT if (p2 or ctx.is_commit) else LENS_PLUM, spec_col="rose")
        body.ring(cx + ex_off, cy, 7.4, "gold", 1.2)
        # Crosshair reticle inside lens
        body.line(cx + ex_off - 6.0, cy, cx + ex_off + 6.0, cy, "apricot")
        body.line(cx + ex_off, cy - 6.0, cx + ex_off, cy + 6.0, "apricot")
        eye_col = "cream" if (ctx.is_tell or ctx.is_commit or p2) else "gold"
        body.eye(cx + ex_off - 1.5, cy - 1.5, eye_col, "cream", "void", 3, 3)

    if p2:
        body.crack(cx - 5, cy - 5, cx + 4, cy + 4, "void", "ice", seed=17)

    # ---- Telegraph / Commit / Stagger FX ----
    if ctx.is_tell and u > 0.30:
        fx_front.star4(cx + (6 if d == "side" else 0), cy - 21.5, 3 if u > 0.7 else 2, "cream", "gold")
        fx_front.ring(cx, cy, 16.0 - u * 4.0, "coral", 1.3)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 8, cy + 4, 21, 16, -65, 65, 5.5, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy + 6, 26, 14, 15, 165, 5.5, ("coral", "gold", "cream"))
            fx_front.slash_arc(cx, cy + 6, 22, 12, -165, -15, 4.0, ("sky", "ice", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 24.0, 11.0, 3.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="meridian_weaver", name="Meridian Weaver", out_dir=ART_BOSSES,
    frame=(88, 80), anchor=(44, 64),
    body_radius=11.0, hit_radius=15.5, body_centre=(44, 40),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_meridian_weaver,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
