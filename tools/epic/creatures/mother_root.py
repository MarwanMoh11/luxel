#!/usr/bin/env python3
"""Island 3 Superboss: The Mother Root (colossal world-tree heart) — 112x96, anchor [56, 80]."""
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

ROOT_DARK = ("void", "night", "dusk", "plum")
BARK_RIB = ("night", "plum", "wine", "apricot")
CANOPY = ("night", "pine", "teal", "jade")
CANOPY_HI = ("pine", "teal", "jade", "lime")
HEART = ("jade", "lime", "gold", "cream")
SAP_GOLD = ("wine", "coral", "apricot", "gold")


def draw_mother_root(ctx: FrameCtx) -> Image.Image:
    w, h = 112, 96
    ax, ay = 56.0, 80.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    pulse = math.sin(ph) * 1.8 if ctx.anim in ("routine", "phase2") else 0.0
    rib_open = 0.0
    root_lift = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        rib_open = 4.5 * u
        root_lift = 7.0 * u
        sx, sy = 0.96, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        rib_open = 5.5 * sm
        root_lift = -3.0 * sm
        sx, sy = 1.07, 0.94
    elif ctx.is_recover:
        rib_open = 5.0
    elif ctx.is_stagger:
        rib_open = 6.5
        pulse = math.sin(ph * 2.0) * 2.6

    cx = ax
    cy = ay - 4.0 + pulse * 0.4
    shadow.contact_shadow(ax, ay + 2.0, 38.0, 4.2, "night")

    # Sweeping colossal buttress roots (kept cleanly inside x in 9..103, y <= 84)
    root_wob = math.sin(lph) * 2.2
    if d == "side":
        body.bezier_limb((cx - 8.0, cy - 16.0), (cx - 26.0, cy - 10.0), (cx - 38.0, ay - 2.0 + root_wob), 6.5, 2.2, ROOT_DARK, tip_col="apricot")
        body.bezier_limb((cx + 8.0, cy - 18.0), (cx + 26.0, cy - 16.0 - root_lift), (cx + 40.0, cy - 2.0 - root_lift * 1.4), 6.0, 2.0, ROOT_DARK, tip_col="gold")
        body.bezier_limb((cx + 2.0, cy - 10.0), (cx + 18.0, cy - 3.0), (cx + 28.0, ay), 4.5, 1.8, BARK_RIB)
    else:
        for sgn in (-1.0, 1.0):
            # Outer sweeping cathedral roots
            body.bezier_limb(
                (cx + sgn * 14.0, cy - 22.0),
                (cx + sgn * 32.0, cy - 16.0 - root_lift),
                (cx + sgn * 43.0, cy - 1.0 - root_lift * 1.3 + root_wob * sgn),
                6.2, 2.1, ROOT_DARK, tip_col="gold" if p2 else "apricot",
            )
            # Lower anchoring root claws
            body.bezier_limb(
                (cx + sgn * 10.0, cy - 12.0),
                (cx + sgn * 22.0, cy - 3.0),
                (cx + sgn * 30.0, ay),
                4.8, 1.8, BARK_RIB,
            )

    # Massive cathedral-arch trunk core
    tr_rx = 22.0 if d != "side" else 19.0
    body.shaded_dome(cx, cy - 14.0, tr_rx, 32.0, ROOT_DARK, bottom_cut=0.10)
    # Sculpted golden-bark cathedral ribs framing the central chest hollow
    if d == "side":
        body.bezier_limb((cx + 6.0, cy - 42.0), (cx + 16.0 + rib_open * 0.5, cy - 26.0), (cx + 10.0, cy - 6.0), 3.2, 2.4, BARK_RIB)
        body.bezier_limb((cx - 4.0, cy - 40.0), (cx - 12.0, cy - 24.0), (cx - 10.0, cy - 5.0), 3.4, 2.6, BARK_RIB)
    else:
        for sgn in (-1.0, 1.0):
            body.bezier_limb(
                (cx + sgn * 8.0, cy - 44.0),
                (cx + sgn * (17.0 + rib_open * 0.6), cy - 26.0),
                (cx + sgn * 12.0, cy - 6.0),
                3.6, 2.6, BARK_RIB,
            )

    # Radiant pulsing Heartwood Seed inside chest hollow (front & side)
    if d != "back":
        hx = cx + (7.0 if d == "side" else 0.0)
        hy = cy - 24.0
        # Dark hollow cavity behind heart
        body.ellipse(hx, hy, 9.5 + rib_open * 0.4, 12.5, "void")
        # Pulsing emerald-gold crystal heart
        hrx = 6.2 + (1.2 if ctx.is_tell or ctx.is_commit else 0.0) + math.sin(ph) * 0.6
        hry = 9.0 + math.sin(ph) * 0.6
        body.shaded_ellipse(hx, hy, hrx, hry, HEART, protect=True)
        body.ellipse(hx - 1.0, hy - 2.0, hrx * 0.42, hry * 0.45, "cream", protect=True)
        # Tiny shrink-fissure archway at base of trunk
        body.shaded_dome(cx + (4.0 if d == "side" else 0.0), cy - 3.0, 5.0, 6.2, ("void", "night", "pine"), bottom_cut=0.05)
        body.circle(cx + (4.0 if d == "side" else 0.0), cy - 5.0, 2.0, "lime" if p2 else "jade", protect=True)
    else:
        # Back view: golden sap spine & ancient moss plates
        body.bezier_limb((cx, cy - 46.0), (cx + math.sin(lph) * 1.5, cy - 26.0), (cx, cy - 5.0), 3.6, 2.8, SAP_GOLD)
        body.shaded_ellipse(cx - 10.0, cy - 22.0, 6.5, 9.0, CANOPY)
        body.shaded_ellipse(cx + 10.0, cy - 22.0, 6.5, 9.0, CANOPY)

    # Towering ancient canopy boughs & luminous crown blossoms (y >= 6)
    can_y = cy - 48.0
    body.shaded_ellipse(cx, can_y, 26.0 if d != "side" else 21.0, 12.0, CANOPY)
    body.shaded_ellipse(cx - 16.0, can_y + 4.0, 14.0, 9.0, CANOPY_HI)
    body.shaded_ellipse(cx + 16.0, can_y + 4.0, 14.0, 9.0, CANOPY_HI)
    body.shaded_ellipse(cx, can_y - 6.0, 15.0, 7.5, CANOPY_HI)
    # Ancient gnarled face eyes peering beneath canopy brow
    if d == "front":
        body.eye(cx - 9.0, cy - 40.0, "gold" if not p2 else "lime", "cream", "void", 3, 2)
        body.eye(cx + 6.5, cy - 40.0, "gold" if not p2 else "lime", "cream", "void", 3, 2)
    elif d == "side":
        body.eye(cx + 7.5, cy - 40.0, "gold" if not p2 else "lime", "cream", "void", 3, 2)

    # Hanging golden lantern-fruit pods under canopy boughs
    for ox in (-22.0, 0.0, 22.0) if d != "side" else (-14.0, 14.0):
        fy = can_y + 11.0 + math.sin(lph + ox) * 1.5
        body.line(cx + ox, can_y + 4.0, cx + ox, fy, "gold")
        body.circle(cx + ox, fy + 1.5, 2.4, "apricot" if not p2 else "gold", protect=True)
        body.set(cx + ox, fy + 1.0, "cream", protect=True)

    if p2:
        body.crack(cx - 12.0, cy - 30.0, cx - 5.0, cy - 12.0, "void", "gold", seed=61)
        body.crack(cx + 12.0, cy - 30.0, cx + 6.0, cy - 12.0, "void", "lime", seed=67)
        fx_back.ring(cx, cy - 26.0, 32.0, "lime", 1.1, 0, 360, protect=True)
        for k in range(6):
            a = ph + k * (math.tau / 6.0)
            fx_front.set(cx + math.cos(a) * 32.0, cy - 26.0 + math.sin(a) * 18.0, "gold" if k % 2 == 0 else "lime", protect=True)

    if ctx.is_tell and u > 0.30:
        fx_front.star4(cx + (7.0 if d == "side" else 0.0), cy - 24.0, 4 if u > 0.68 else 3, "cream", "lime")
        fx_front.ring(cx + (7.0 if d == "side" else 0.0), cy - 24.0, 12.0 + u * 8.0, "gold", 1.2, 0, 360, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 14.0, cy - 22.0, 24.0, 18.0, -70, 70, 6.5, ("lime", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 12.0, 34.0, 15.0, 10, 170, 6.5, ("lime", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, can_y - 10.0, 16.0, 4.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="mother_root", name="The Mother Root", out_dir=ART_BOSSES,
    frame=(112, 96), anchor=(56, 80),
    body_radius=16.0, hit_radius=21.0, body_centre=(56, 48),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_mother_root,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
