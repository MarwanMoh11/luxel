#!/usr/bin/env python3
"""Island 5 Boss: The Twin Moons — Sola (gold push) & Umbra (indigo pull) celestial spheres — 88x80, anchor [44, 62]."""
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

SOLA = ("wine", "coral", "apricot", "gold")
UMBRA = ("night", "deep", "blue", "sky")
BRASS = ("plum", "coral", "apricot", "gold")


def _draw_moon(
    body: PixelBuf, fx_front: PixelBuf, mx: float, my: float, r: float,
    is_sola: bool, d: str, eye_open: bool, angry: bool, dizzy: bool, ph: float,
) -> None:
    ramp = SOLA if is_sola else UMBRA
    spec = "cream" if is_sola else "ice"
    band_col = "cream" if is_sola else "ice"
    trim_col = "gold" if is_sola else "sky"

    # Outer engraved meridian ring + distinct silhouette crown (sun-ray spikes for Sola, crescent horns for Umbra!)
    body.ring(mx, my, r + 3.2, trim_col, 1.5)
    if is_sola:
        for k in range(4):
            a = ph + k * math.pi * 0.5
            p0 = (mx + math.cos(a) * (r + 2.5), my + math.sin(a) * (r + 2.5))
            p1 = (mx + math.cos(a) * (r + 6.5), my + math.sin(a) * (r + 6.5))
            body.line(p0[0], p0[1], p1[0], p1[1], "gold", protect=True)
            body.set(p1[0], p1[1], "cream", protect=True)
    else:
        # Twin crescent horn finials crowning Umbra
        body.shaded_poly([(mx - 5, my - r - 1), (mx - 8, my - r - 7), (mx - 1, my - r - 3)], ("deep", "blue", "sky", "ice"))
        body.shaded_poly([(mx + 5, my - r - 1), (mx + 8, my - r - 7), (mx + 1, my - r - 3)], ("deep", "blue", "sky", "ice"))
        for k in range(4):
            a = -ph + k * math.pi * 0.5
            body.rect(mx + math.cos(a) * (r + 3.5) - 1, my + math.sin(a) * (r + 3.5) - 1, 2, 2, band_col)

    # Sphere body
    body.shaded_ellipse(mx, my, r, r, ramp, spec_col=spec)

    # Etched equatorial meridian band
    body.line(mx - r + 2, my, mx + r - 2, my, "plum" if is_sola else "night")
    body.line(mx - r + 3, my - 1, mx + r - 3, my - 1, trim_col)

    if d != "back":
        ex_off = 3.0 if d == "side" else 0.0
        # Expressive crescent eye (arched fierce brow on tell/commit, X/squint on stagger!)
        if dizzy:
            body.line(mx + ex_off - 3, my - 4, mx + ex_off + 1, my, "cream", protect=True)
            body.line(mx + ex_off + 1, my - 4, mx + ex_off - 3, my, "cream", protect=True)
        else:
            ec = "cream" if (angry or not eye_open) else ("gold" if not is_sola else "cream")
            body.shaded_ellipse(mx + ex_off, my - 2.0, 4.2, 3.0 if eye_open else 1.5, ("void", "night", "deep"))
            body.eye(mx + ex_off, my - 2.0, ec, "cream", "void", 3, 2)
            # Crescent eyebrow rim
            brow_y = my - 5.5 + (1.2 if angry else 0.0)
            body.line(mx + ex_off - 4, brow_y, mx + ex_off + 4, brow_y - (1.0 if is_sola else -1.0), band_col, protect=True)
    else:
        # Back view: ornate sun-burst / crescent-eclipse crest etched on far side
        if is_sola:
            fx_front.star4(mx, my, 4, "cream", "gold")
        else:
            body.circle(mx, my, 4.5, "ice", protect=True)
            body.circle(mx + 2.0, my - 0.5, 4.0, "deep")


def draw_twin_moons(ctx: FrameCtx) -> Image.Image:
    w, h = 88, 80
    ax, ay = 44.0, 62.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.2
    orbit_a = ph if ctx.anim in ("routine", "phase2") else (ph * 0.4)
    sep = 16.5 if not ctx.is_stagger else 21.0
    if ctx.is_tell:
        sep = 16.5 + 4.5 * u
    elif ctx.is_commit:
        sep = 18.5 - 7.5 * math.sin(min(1.0, u * 1.6) * math.pi)

    cx, cy = ax, ay - 26.0 + hover
    sx, sy = 1.0, 1.0
    if ctx.is_tell:
        sx, sy = 1.05, 0.96
    elif ctx.is_commit:
        sx, sy = 1.08, 0.92

    # Position Sola & Umbra around shared orbital hub
    if d == "side":
        sola_p = (cx + sep * 0.72, cy - 4.0 + math.sin(orbit_a) * 4.0)
        umbra_p = (cx - sep * 0.72, cy + 4.0 - math.sin(orbit_a) * 4.0)
    else:
        sola_p = (cx - sep * 0.78, cy - 3.5 + math.sin(orbit_a) * 3.5)
        umbra_p = (cx + sep * 0.78, cy + 3.5 - math.sin(orbit_a) * 3.5)

    # Swap colors cleanly in Phase 2 to visually telegraph polarity swap!
    sola_is_gold = not p2
    shadow.contact_shadow(sola_p[0], ay + 1.0, 11.0, 2.0, "night")
    shadow.contact_shadow(umbra_p[0], ay + 1.0, 11.0, 2.0, "night")

    # Central syzygy gravity tether / chord between the moons
    chord_col = "gold" if (ctx.is_tell or ctx.is_commit or p2) else "sky"
    fx_back.line(sola_p[0], sola_p[1], umbra_p[0], umbra_p[1], chord_col, protect=True)
    if p2 or ctx.is_commit:
        fx_back.line(sola_p[0], sola_p[1] - 1, umbra_p[0], umbra_p[1] - 1, "cream", protect=True)
        fx_back.star4(cx, cy, 4 if ctx.is_commit else 3, "cream", "gold")

    # Gravity field rings around each moon
    fx_back.ring(sola_p[0], sola_p[1], 16.5, "apricot" if sola_is_gold else "blue", 1.0)
    fx_back.ring(umbra_p[0], umbra_p[1], 16.5, "blue" if sola_is_gold else "apricot", 1.0)

    # Draw Umbra then Sola (both crisp and distinct!)
    angry = ctx.is_tell or ctx.is_commit
    _draw_moon(body, fx_front, umbra_p[0], umbra_p[1], 10.5, not sola_is_gold, d, not ctx.is_recover, angry, ctx.is_stagger, lph)
    _draw_moon(body, fx_front, sola_p[0], sola_p[1], 11.0, sola_is_gold, d, not ctx.is_recover, angry, ctx.is_stagger, ph)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.30:
        fx_front.ring(sola_p[0], sola_p[1], 14.0 + u * 3.0, "gold", 1.2)
        fx_front.ring(umbra_p[0], umbra_p[1], 17.0 - u * 4.0, "ice", 1.2)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.ring(cx, cy, 12.0 + ctx.fi * 5.0, "gold", 1.8)
        fx_front.ring(cx, cy, 9.0 + ctx.fi * 4.0, "ice", 1.2)
        fx_front.star4(cx, cy, 5, "cream", "gold")
    elif ctx.is_stagger:
        # Clashing cymbal BONG sparks between the two moons + dizzy stars!
        fx_front.star4(cx, cy, 4, "cream", "gold")
        fx_front.dizzy_stars(sola_p[0], sola_p[1] - 15.0, 8.5, 2.5, ph)
        fx_front.dizzy_stars(umbra_p[0], umbra_p[1] - 15.0, 8.5, 2.5, -ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="twin_moons", name="The Twin Moons", out_dir=ART_BOSSES,
    frame=(88, 80), anchor=(44, 62),
    body_radius=12.0, hit_radius=16.5, body_centre=(44, 38),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_twin_moons,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
