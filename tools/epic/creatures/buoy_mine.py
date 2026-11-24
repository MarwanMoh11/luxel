#!/usr/bin/env python3
"""Island 2 Enemy: Buoy Mine (horned iron naval mine on bobbing chain) — 58x54, anchor [29, 43]."""
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

IRON = ("void", "night", "dusk", "mauve")
HOT_IRON = ("night", "wine", "coral", "apricot")
BAND = ("wine", "coral", "apricot", "gold")


def draw_buoy_mine(ctx: FrameCtx) -> Image.Image:
    w, h = 58, 54
    ax, ay = 29.0, 43.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    bob = math.sin(ph) * 2.2
    sway = math.sin(lph) * 2.0
    sx, sy = 1.0, 1.0
    hot = False

    if ctx.is_tell:
        hot = True
        pulse = 1.0 + 0.14 * abs(math.sin(u * math.pi * 4.0))
        bob = -2.0 * u
        sx, sy = pulse, 2.0 - pulse
    elif ctx.is_commit:
        hot = True
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        sx, sy = 1.18 * sm + 0.92 * (1.0 - sm), 1.18 * sm + 0.92 * (1.0 - sm)
        bob = -3.0 * sm
    elif ctx.is_recover:
        bob = 2.0 + math.sin(ph) * 0.8
        sx, sy = 1.04, 0.94
    elif ctx.is_stagger:
        sway = math.sin(ph * 2.0) * 4.0
        bob = 1.5

    cx = ax + sway * 0.5
    cy = ay - 15.0 + bob
    shadow.contact_shadow(ax, ay + 1.0, 10.0, 2.0, "night")

    # Anchor chain tethering mine to seabed / deck
    body.chain((ax, ay), (cx, cy + 9.0), sag=2.0 + sway * 0.4, link_col="mauve", hi_col="stone", dark_col="night", links=4)

    # 6 projecting iron contact horns around sphere
    horn_angles = [-150, -90, -30, 30, 90, 150] if d != "side" else [-135, -75, -15, 45, 105, 165]
    horn_ramp = HOT_IRON if hot else IRON
    for deg in horn_angles:
        rad = math.radians(deg + (sway * 2.0))
        x0, y0 = cx + math.cos(rad) * 7.5, cy + math.sin(rad) * 7.5
        x1, y1 = cx + math.cos(rad) * 14.0, cy + math.sin(rad) * 14.0
        body.capsule(x0, y0, x1, y1, 2.2, 1.2, horn_ramp)
        body.circle(x1, y1, 1.4, "gold" if hot else "stone", protect=hot)

    # Spherical riveted iron casing
    body.shaded_ellipse(cx, cy, 10.5, 10.2, HOT_IRON if hot else IRON, spec_col="cream" if hot else "stone")

    # Coral & gold hazard warning band around equator
    for bx in range(-9, 10):
        by_curve = math.sqrt(max(0.0, 1.0 - (bx / 10.5) ** 2))
        col_b = "gold" if (bx + (2 if d == "side" else 0)) % 4 == 0 else "coral"
        body.rect(cx + bx, cy - 1 + by_curve * 1.4, 1, 3, col_b, protect=hot)

    # Rivets on upper dome
    for rx in (-6, 0, 6):
        body.set(cx + rx, cy - 6, "stone")
        body.set(cx + rx, cy + 6, "night")

    # Front / Side glowing pressure-fuse viewport eye (back shows bolted hatch plate)
    if d == "front":
        body.circle(cx, cy - 1.5, 3.6, "void")
        body.circle(cx, cy - 1.5, 2.5, "coral" if hot else "apricot", protect=True)
        body.circle(cx - 0.5, cy - 2.0, 1.3, "cream" if hot else "gold", protect=True)
    elif d == "side":
        body.circle(cx + 4.5, cy - 1.5, 3.3, "void")
        body.circle(cx + 4.5, cy - 1.5, 2.2, "coral" if hot else "apricot", protect=True)
        body.set(cx + 4.0, cy - 2.0, "cream" if hot else "gold", protect=True)
    else:
        body.shaded_ellipse(cx, cy - 1.0, 4.2, 4.2, ("night", "dusk", "mauve"))
        body.line(cx - 3, cy - 1, cx + 3, cy - 1, "void")
        body.line(cx, cy - 4, cx, cy + 2, "void")

    # FX layers
    if ctx.is_tell:
        ring_r = max(4.0, 17.0 - u * 8.0)
        fx_front.ring(cx, cy, ring_r, "coral" if u > 0.55 else "gold", 1.2, 0, 360, protect=True)
        fx_front.star4(cx, cy - 14, 3 if u > 0.65 else 2, "cream", "coral")
    elif ctx.is_commit and ctx.fi in (0, 1, 2, 3):
        blast_r = 12.0 + ctx.fi * 3.5
        fx_front.ring(cx, cy, blast_r, "coral", 2.4, 0, 360, protect=True)
        fx_front.ring(cx, cy, blast_r - 2.5, "gold", 1.6, 0, 360, protect=True)
        for k in range(8):
            a = k * (math.tau / 8.0) + ctx.fi * 0.2
            fx_front.star4(cx + math.cos(a) * blast_r, cy + math.sin(a) * blast_r, 2, "cream", "gold")
    elif ctx.is_recover:
        # Steam puffs venting out top horn
        for k in range(2):
            py_s = cy - 14 - ((ctx.fi + k * 2) % 4) * 2.5
            fx_front.circle(cx + (k * 4 - 2), py_s, 1.8, "ice", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 15, 9.0, 2.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="buoy_mine", name="Buoy Mine", out_dir=ART_ENEMIES,
    frame=(58, 54), anchor=(29, 43),
    body_radius=6.5, hit_radius=10.5, body_centre=(29, 28),
    anims=list(ENEMY_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_buoy_mine,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
