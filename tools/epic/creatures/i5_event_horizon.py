#!/usr/bin/env python3
"""Island 5 Superboss: The Event Horizon (devouring black hole singularity -> P3 blinding White Hole!) — 92x88, anchor [46, 68]."""
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

VOID_DISK = ("void", "night", "plum", "wine")
PHOTON_GOLD = ("coral", "apricot", "gold", "cream")
WHITE_HOLE = ("sky", "ice", "gold", "cream")

HORIZON_ANIMS = list(BOSS_ANIMS) + [
    ("phase3", True, [115.0, 115.0, 115.0, 115.0, 115.0, 115.0]),
]


def draw_event_horizon(ctx: FrameCtx) -> Image.Image:
    w, h = 92, 88
    ax, ay = 46.0, 68.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2
    p3 = ctx.anim == "phase3"

    hover = math.sin(ph) * 2.0
    cx, cy = ax, ay - 30.0 + hover
    sx, sy = 1.0, 1.0
    core_r = 13.5

    if ctx.is_tell:
        # Gravitational contraction before polar jet / nova!
        core_r = 13.5 - 2.5 * u
        sx, sy = 0.94, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        core_r = 13.5 + 3.0 * sm
        sx, sy = 1.09, 0.92
    elif ctx.is_stagger:
        sx, sy = 1.0 + math.sin(ph * 2.0) * 0.08, 1.0 - math.sin(ph * 2.0) * 0.08

    shadow.contact_shadow(ax, ay + 2.0, 20.0, 2.8, "void")

    # ---- Outer Swirling Relativistic Accretion Disk (back half) ----
    disk_rx = 30.0 if d == "side" else 27.0
    disk_ry = 9.5 if d == "side" else 11.5
    outer_col = "gold" if p3 else ("rose" if p2 else "plum")
    mid_col = "cream" if p3 else ("coral" if p2 else "wine")

    # Back lensing halo (Einstein gravitational-lensed top/bottom arcs!)
    fx_back.ring(cx, cy, core_r + 8.5, "ice" if p3 else ("sky" if p2 else "dusk"), 1.6)
    fx_back.ring(cx, cy, core_r + 12.5, "gold" if p3 else "plum", 1.1)

    # Back accretion ellipse
    body.shaded_ellipse(cx, cy, disk_rx, disk_ry, WHITE_HOLE if p3 else VOID_DISK)
    fx_back.ring(cx, cy - 3.0, core_r + 4.5, "cream" if p3 else "gold", 1.5, 195, 345)

    # Orbiting gravitational lensing satellites (visual cue for curve trajectories!)
    for k in range(2):
        ang = ph + k * math.pi
        mx = cx + math.cos(ang) * (disk_rx - 2.0)
        my = cy + math.sin(ang) * (disk_ry + 4.0)
        if math.sin(ang) < 0.0:
            fx_back.circle(mx, my, 3.0, "gold" if p3 else "sky", protect=True)
            fx_back.set(mx, my, "cream", protect=True)

    # ---- Central Singularity Core (Pure Void Black Hole OR Blinding White Hole in P3!) ----
    if p3:
        # WHITE HOLE INVERSION: radiant blazing cream/ice singularity with outward rays!
        body.shaded_ellipse(cx, cy, core_r + 1.5, core_r + 1.5, WHITE_HOLE, spec_col="cream", protect=True)
        body.circle(cx, cy, core_r - 3.5, "cream", protect=True)
        for ri in range(8):
            ra = ph * 0.8 + ri * (math.pi * 0.25)
            p0 = (cx + math.cos(ra) * (core_r + 1.0), cy + math.sin(ra) * (core_r + 1.0))
            p1 = (cx + math.cos(ra) * (core_r + 11.0), cy + math.sin(ra) * (core_r + 11.0))
            fx_front.line(p0[0], p0[1], p1[0], p1[1], "gold" if ri % 2 == 0 else "ice", protect=True)
            fx_front.set(p1[0], p1[1], "cream", protect=True)
    else:
        # DEVOURING BLACK HOLE: pure void sphere ringed by razor-thin blazing gold/cream Photon Ring!
        body.circle(cx, cy, core_r + 2.2, "wine" if p2 else "plum")
        body.circle(cx, cy, core_r + 1.2, "gold", protect=True)
        body.circle(cx, cy, core_r, "void", protect=True)
        # Inner dark swirling event-horizon vortex spiral pixels
        for si in range(6):
            sa = -ph * 1.4 + si * (math.pi / 3.0)
            sr = core_r * 0.62
            body.set(cx + math.cos(sa) * sr, cy + math.sin(sa) * sr, "night", protect=True)
        # Blazing Doppler-boosted Photon Ring crescent (shifts by view direction!)
        if d == "side":
            fx_front.ring(cx, cy, core_r + 1.4, "cream", 2.0, -75, 75)
            fx_front.ring(cx, cy, core_r + 2.8, "apricot", 1.2, -95, 95)
        elif d == "back":
            # Back view: exposed bright golden periapsis weakspot crescent!
            fx_front.ring(cx, cy, core_r + 1.6, "cream", 2.0, 0, 360)
            fx_front.star4(cx, cy, 4, "gold", "apricot")
        else:
            fx_front.ring(cx, cy, core_r + 1.5, "cream", 1.8, 195, 345)
            fx_front.ring(cx, cy, core_r + 1.5, "gold", 1.4, 15, 165)
            # Subtle cosmic eye slit inside horizon during tell/commit
            if ctx.is_tell or ctx.is_commit or p2:
                body.line(cx - 5.0, cy, cx + 5.0, cy, "ice" if p2 else "gold", protect=True)
                body.set(cx, cy, "cream", protect=True)

    # ---- Front Half of Swirling Accretion Ribbon Crossing Over Singularity ----
    pts_front = []
    for i in range(13):
        t = i / 12.0
        a = t * math.pi
        px = cx + math.cos(a) * disk_rx
        py = cy + math.sin(a) * disk_ry * 0.72 + math.sin(ph + t * 5.0) * 1.1
        pts_front.append((px, py))
    for i in range(len(pts_front) - 1):
        fx_front.line(pts_front[i][0], pts_front[i][1], pts_front[i + 1][0], pts_front[i + 1][1], outer_col, protect=True)
        fx_front.line(pts_front[i][0], pts_front[i][1] - 1.0, pts_front[i + 1][0], pts_front[i + 1][1] - 1.0, mid_col, protect=True)
    # Front lensing satellite orbs
    for k in range(2):
        ang = ph + k * math.pi
        mx = cx + math.cos(ang) * (disk_rx - 2.0)
        my = cy + math.sin(ang) * (disk_ry + 4.0)
        if math.sin(ang) >= 0.0:
            fx_front.circle(mx, my, 3.2, "cream" if p3 else "gold", protect=True)
            fx_front.star4(mx, my, 2, "cream", "ice")

    # ---- Twin Polar Accretion Jets on Tell / Commit ----
    if ctx.is_tell and u > 0.25:
        jlen = 12.0 + u * 14.0
        fx_front.line(cx, cy - core_r, cx, max(4.0, cy - core_r - jlen), "ice", protect=True)
        fx_front.line(cx, cy + core_r, cx, min(h - 4.0, cy + core_r + jlen), "ice", protect=True)
        fx_front.star4(cx, max(6.0, cy - core_r - jlen * 0.8), 3, "cream", "gold")
        fx_front.ring(cx, cy, core_r + 10.0 - u * 5.0, "gold", 1.4)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        fx_front.line(cx, 4.0, cx, h - 6.0, "sky", protect=True)
        fx_front.line(cx - 1.0, 5.0, cx - 1.0, h - 7.0, "cream", protect=True)
        fx_front.line(cx + 1.0, 5.0, cx + 1.0, h - 7.0, "gold", protect=True)
        fx_front.ring(cx, cy, core_r + 4.0 + ctx.fi * 5.0, "gold", 1.8)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - core_r - 8.0, 13.0, 3.5, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="event_horizon", name="The Event Horizon", out_dir=ART_BOSSES,
    frame=(92, 88), anchor=(46, 68),
    body_radius=13.5, hit_radius=18.0, body_centre=(46, 38),
    anims=HORIZON_ANIMS, cool_rim=True, biome_bg="deep",
    draw_frame=draw_event_horizon,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
