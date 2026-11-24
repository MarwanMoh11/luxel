#!/usr/bin/env python3
"""Island 4 Boss B: The Drowned Choir (porcelain Conductor Organ Bust, fluted brass pipes, weeping rain-tears, 5-note halo) — 84x80, anchor [42, 66]."""
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

PORCELAIN = ("dusk", "mauve", "stone", "ice")
BRASS = ("wine", "apricot", "gold", "cream")
ORGAN_DARK = ("void", "night", "deep", "blue")
WATER = ("deep", "blue", "sky", "ice")
NOTE_COLS = ("gold", "sky", "rose", "lime", "cream")


def draw_boss_drowned_choir(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 66.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    float_y = math.sin(ph) * 1.8
    mouth_open = 1.5 + abs(math.sin(ph)) * 1.4
    sx, sy = 1.0, 1.0
    pipe_pulse = 0.0

    if ctx.is_tell:
        float_y = -2.2 * u
        mouth_open = 2.0 + 4.0 * u
        pipe_pulse = u * 3.0
        sx, sy = 0.95, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        float_y = -1.5 * sm
        mouth_open = 6.2
        pipe_pulse = 4.0 * sm
        sx, sy = 1.08, 0.94
    elif ctx.is_recover:
        float_y = 2.2
        mouth_open = 0.5
    elif ctx.is_stagger:
        float_y = 2.8 + math.sin(ph * 2.0) * 1.4
        mouth_open = 0.5
        sx, sy = 1.04, 0.95

    cx = ax
    cy = ay - 2.0 + float_y
    shadow.contact_shadow(ax, ay + 1.5, 16.5, 2.5, "night")

    # Fluted Cathedral Organ Pipes rising fan-like behind the porcelain bust!
    pipe_specs = [(-16, 24), (-11, 31), (-6, 36), (0, 39), (6, 36), (11, 31), (16, 24)]
    if d == "side":
        pipe_specs = [(-11, 31), (-6, 36), (-1, 39), (4, 34), (9, 27)]
    for idx, (px_off, p_h) in enumerate(pipe_specs):
        ph_cur = p_h + (pipe_pulse * 0.65 if idx % 2 == 0 else 0.0)
        x0 = cx + px_off - 2.0
        y0 = cy - 12.0 - ph_cur
        body.shaded_rect(x0, y0, 4, ph_cur, BRASS)
        # Beveled organ flue notch
        body.rect(x0 + 1, y0 + 5, 2, 3, "night")
        if p2 or ctx.is_tell or ctx.is_commit:
            body.set(x0 + 1, y0 + 6, NOTE_COLS[idx % 5], protect=True)
        # Pipe crown cap
        body.line(x0, y0, x0 + 3, y0, "cream", protect=True)

    # Carved submerged marble pedestal base & weeping water rim
    body.shaded_poly([
        (cx - 17, cy - 2), (cx - 14, cy - 13), (cx + 14, cy - 13), (cx + 17, cy - 2),
    ], ORGAN_DARK)
    body.rect(cx - 15, cy - 13, 30, 3, "gold")
    body.line(cx - 14, cy - 13, cx + 14, cy - 13, "cream")
    # Flat elliptical rippling water basin around plinth
    fx_back.ellipse(cx, cy - 1.0, 21.0, 4.4, "sky", protect=True)
    fx_back.ellipse(cx, cy - 1.0, 18.5, 3.2, "blue", protect=True)
    fx_back.ellipse(cx, cy - 1.5, 14.0, 2.0, "deep", protect=True)

    # Porcelain bust shoulders & stained-glass choir chest resonator
    sh_w = 15.0 if d != "side" else 12.0
    body.shaded_dome(cx, cy - 12.0, sh_w, 15.0, PORCELAIN, bottom_cut=0.05, spec_col="cream")
    # Stained-glass chest aperture glowing with D-minor resonance
    ax_c = cx + (3.5 if d == "side" else 0.0)
    if d != "back":
        body.shaded_ellipse(ax_c, cy - 18.0, 5.2 if d == "front" else 3.6, 5.0, WATER, spec_col="cream")
        body.ring(ax_c, cy - 18.0, 5.4 if d == "front" else 3.8, "gold", 1.1, protect=True)
        body.line(ax_c, cy - 22.0, ax_c, cy - 14.0, "gold")
        body.line(ax_c - 3.0, cy - 18.0, ax_c + 3.0, cy - 18.0, "gold")

    # Sculpted Classical Porcelain Head with acoustic crown & weeping tears
    hx = cx + (2.5 if d == "side" else 0.0)
    hy = cy - 33.0
    head_rx = 10.5 if d != "side" else 9.5
    body.shaded_ellipse(hx, hy, head_rx, 11.8, PORCELAIN, spec_col="cream")
    # Cracked porcelain veil & acoustic laurel crown
    body.shaded_dome(hx, hy - 6.0, head_rx + 1.5, 6.0, BRASS, bottom_cut=0.25, spec_col="cream")
    body.circle(hx, hy - 13.0, 2.2, "ice" if not p2 else "rose", protect=True)

    if d == "front":
        # Haunting eyes (peacefully shut in recover/stagger, glowing hollow sky/cream when singing!)
        if ctx.is_recover or ctx.is_stagger:
            body.line(hx - 6, hy - 2, hx - 2, hy - 1, "night")
            body.line(hx + 2, hy - 1, hx + 6, hy - 2, "night")
        else:
            body.eye(hx - 5.2, hy - 2.5, "sky" if not p2 else "gold", "cream", "void", 3, 2)
            body.eye(hx + 2.4, hy - 2.5, "sky" if not p2 else "gold", "cream", "void", 3, 2)
        # Weeping sky/ice tear-streaks down porcelain cheeks
        body.line(hx - 4.5, hy, hx - 5.0, hy + 7.0, "sky")
        body.line(hx + 4.5, hy, hx + 5.0, hy + 7.0, "sky")
        body.set(hx - 5.0, hy + 8.0, "ice", protect=True)
        body.set(hx + 5.0, hy + 8.0, "ice", protect=True)
        # Singing oval porcelain mouth glowing with voice chord
        body.ellipse(hx, hy + 5.0, 3.6, mouth_open * 0.72, "void", protect=True)
        if mouth_open > 2.2:
            body.ring(hx, hy + 5.0, 4.2, "gold" if not p2 else "rose", 1.1, protect=True)
            body.ellipse(hx, hy + 5.0, 2.0, mouth_open * 0.40, "ice" if not p2 else "cream", protect=True)
    elif d == "side":
        if ctx.is_recover or ctx.is_stagger:
            body.line(hx + 2, hy - 2, hx + 6, hy - 1, "night")
        else:
            body.eye(hx + 3.5, hy - 2.5, "sky" if not p2 else "gold", "cream", "void", 3, 2)
        body.line(hx + 4.0, hy, hx + 4.5, hy + 7.0, "sky")
        body.ellipse(hx + 7.0, hy + 4.5, 2.5, mouth_open * 0.65, "void", protect=True)
        if mouth_open > 2.2:
            body.ring(hx + 7.0, hy + 4.5, 3.2, "gold", 1.0, protect=True)
    else:
        # Back of bust: carved clef medallion & cracked porcelain seam
        body.shaded_ellipse(hx, hy + 1.0, 5.5, 6.5, ORGAN_DARK)
        body.ring(hx, hy + 1.0, 5.5, "gold", 1.1)
        body.line(hx, hy - 4.0, hx, hy + 6.0, "ice")

    # Porcelain hairline fracture (glows rose/ice in Phase 2+)
    body.crack(hx - 6, hy - 8, hx - 2, hy + 3, "night", "ice" if not p2 else "rose", seed=31)

    # 5 Floating Choir Voice Gem-Orbs arcing overhead (I..V in gold/sky/rose/lime/cream!)
    for vi in range(5):
        a = -math.pi * 0.85 + vi * (math.pi * 0.70 / 4.0)
        ox = cx + math.cos(a) * 23.0
        oy = hy - 4.0 + math.sin(a) * 16.0 + math.sin(lph + vi * 1.1) * 1.6
        r_gem = 2.6 if (ctx.is_tell or ctx.is_commit or p2) else 2.0
        fx_front.circle(ox, oy, r_gem + 0.9, "night", protect=True)
        fx_front.circle(ox, oy, r_gem, NOTE_COLS[vi], protect=True)
        fx_front.set(ox - 0.5, oy - 0.5, "cream", protect=True)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.28:
        fx_front.ring(hx + (5 if d == "side" else 0), hy + 4.0, 8.0 + u * 8.0, "gold", 1.2, protect=True)
        fx_front.star4(hx + (8 if d == "side" else 0), hy + 4.0, 3 if u > 0.72 else 2, "cream", "ice")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        rad = 10.0 + ctx.fi * 5.5
        fx_front.ring(hx + (6 if d == "side" else 0), hy + 3.0, rad, "sky", 1.8, protect=True)
        fx_front.ring(hx + (6 if d == "side" else 0), hy + 3.0, rad - 3.0, "cream", 1.1, protect=True)
        for k in range(5):
            sa = ph + k * (math.tau / 5.0)
            fx_front.rect(cx + math.cos(sa) * 22, hy + math.sin(sa) * 13, 2, 2, NOTE_COLS[k], protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 16.0, 11.0, 3.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="boss_drowned_choir", name="The Drowned Choir", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 66),
    body_radius=12.0, hit_radius=16.5, body_centre=(42, 38),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_boss_drowned_choir,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
