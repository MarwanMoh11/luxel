#!/usr/bin/env python3
"""Island 3 Mini-Boss: The Stag Colossus (bus-sized mirror-carapace stag beetle) — 84x76, anchor [42, 58]."""
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

SHELL = ("night", "pine", "teal", "jade")
MIRROR = ("blue", "sky", "ice", "cream")
ANTLER = ("night", "plum", "wine", "apricot")
BELLY = ("coral", "apricot", "gold", "cream")
LEG = ("void", "night", "dusk", "plum")


def draw_stag_colossus(ctx: FrameCtx) -> Image.Image:
    w, h = 96, 82
    ax, ay = 48.0, 64.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = abs(math.sin(ph)) * 1.8 if ctx.anim in ("routine", "phase2") else 0.0
    stride = math.sin(ph) * 3.5 if ctx.anim in ("routine", "phase2") else 0.0
    lunge = 0.0
    crouch = 0.0
    pincer_open = 0.25 + 0.15 * math.sin(ph)
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 4.2 * u
        lunge = -5.5 * u
        pincer_open = 0.25 + 0.75 * u
        sx, sy = 1.09, 0.91
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        lunge = 8.5 * sm
        crouch = 1.8 * sm
        pincer_open = 1.0 - 0.9 * sm
        sx, sy = 1.12, 0.89
    elif ctx.is_recover:
        lunge = 3.0 * (1.0 - u)
        crouch = 3.5
        pincer_open = 0.15
    elif ctx.is_stagger:
        crouch = 1.0

    cx = ax + (lunge if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 2.0, 22.0, 3.0, "night")

    # Signature comedy beat: FLIPPED ON BACK during stagger, 6 stubby legs pedaling wildly in mid-air!
    if ctx.is_stagger:
        wob = math.sin(ph * 2.0) * 2.2
        # Rounded mirrored carapace resting on the floor
        body.shaded_ellipse(cx + wob, cy - 8.5, 20.0, 10.5, SHELL)
        body.shaded_ellipse(cx + wob, cy - 4.0, 14.0, 4.2, MIRROR)
        # Wide vulnerable glowing golden belly exposed upward!
        body.shaded_ellipse(cx + wob, cy - 13.5, 17.5, 8.2, BELLY, spec_col="cream")
        for ry in (-16, -13, -10):
            body.line(cx - 12 + wob, cy + ry, cx + 12 + wob, cy + ry, "coral")
        # 6 stubby legs pedaling frantically in mid-air!
        for sgn in (-1.0, 1.0):
            for k in range(3):
                pedal = math.sin(ph * 3.0 + k * 1.8 + (0.0 if sgn > 0 else 1.5)) * 4.5
                bx = cx + wob + sgn * (5.0 + k * 4.8)
                body.bezier_limb(
                    (bx, cy - 17.0),
                    (bx + sgn * 3.5, cy - 23.0 + pedal),
                    (bx + sgn * 6.5, cy - 27.0 + pedal),
                    2.6, 1.3, LEG, tip_col="apricot",
                )
        # Upside-down flailing pincers
        body.bezier_limb((cx + wob + 14, cy - 13), (cx + wob + 21, cy - 18), (cx + wob + 19, cy - 24), 2.5, 1.0, ANTLER, tip_col="gold")
        fx_front.dizzy_stars(cx + wob, cy - 33.0, 12.0, 3.5, ph)
        return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))

    if d == "side":
        # Far 3 chunky beetle legs
        for k, ox in enumerate((-13.0, -3.0, 7.0)):
            st = stride * (1.0 if k % 2 == 0 else -1.0)
            body.capsule(cx + ox, cy - 7, cx + ox + st * 0.7, cy, 2.8, 1.7, ("void", "night", "dusk"))
        # Massive domed shell + gleaming sky/ice mirror back panel
        body.shaded_dome(cx - 4.0, cy - 9.0, 20.5, 18.0, SHELL, bottom_cut=0.14)
        body.shaded_ellipse(cx - 5.0, cy - 19.5, 13.8, 6.8, MIRROR, spec_col="cream")
        body.line(cx - 14, cy - 19, cx + 4, cy - 21, "cream", protect=True)
        body.line(cx - 18, cy - 10, cx + 11, cy - 10, "pine")
        # Gold underside rim hint
        body.line(cx - 16, cy - 7, cx + 8, cy - 7, "gold")
        # Heavy horned head plate + colossal curved stag antlers/mandibles!
        hx, hy = cx + 14.0, cy - 12.0
        body.shaded_ellipse(hx, hy, 8.2, 7.6, SHELL)
        # Upper pronged stag antler horn
        body.bezier_limb(
            (hx + 3, hy - 5), (hx + 11, hy - 14 - pincer_open * 3), (hx + 18, hy - 19 - pincer_open * 4),
            3.2, 1.0, ANTLER, tip_col="gold",
        )
        body.bezier_limb(
            (hx + 9, hy - 12), (hx + 14, hy - 10), (hx + 17, hy - 13),
            1.8, 0.7, ANTLER, tip_col="apricot",
        )
        # Lower snapping mandible pincer
        body.bezier_limb(
            (hx + 4, hy + 2), (hx + 12, hy + 4 + pincer_open * 4), (hx + 18, hy - 1 + pincer_open * 5),
            2.6, 0.9, ANTLER, tip_col="gold",
        )
        body.eye(hx + 2.5, hy - 2.5, "coral" if p2 else "gold", "cream", "void", 3, 2)
        # Near 3 chunky legs
        for k, ox in enumerate((-12.0, -2.0, 8.0)):
            st = -stride * (1.0 if k % 2 == 0 else -1.0)
            body.capsule(cx + ox, cy - 6.5, cx + ox + st, cy + 1.0, 3.0, 1.8, LEG)
    elif d == "front":
        # 6 massive wide-stance legs
        for sgn in (-1.0, 1.0):
            for k, dy in enumerate((-4.0, -1.0, 2.0)):
                st = math.sin(ph + k * 1.4) * 2.0 * sgn
                body.capsule(cx + sgn * 13.0, cy - 9.0 + dy, cx + sgn * 22.0, cy - 1.0 + dy + st, 2.8, 1.6, LEG)
        # Towering armored carapace dome + gleaming mirror shield crown
        body.shaded_dome(cx, cy - 10.0, 19.5, 19.0, SHELL, bottom_cut=0.14)
        body.shaded_ellipse(cx, cy - 22.0, 13.0, 6.4, MIRROR, spec_col="cream")
        body.line(cx - 7, cy - 24, cx + 7, cy - 21, "cream", protect=True)
        # Head brow & twin colossal stag pincer-antlers!
        body.shaded_ellipse(cx, cy - 11.0, 12.2, 8.4, ("night", "pine", "teal"))
        for sgn in (-1.0, 1.0):
            spread = pincer_open * 5.0
            body.bezier_limb(
                (cx + sgn * 6, cy - 15),
                (cx + sgn * (15 + spread), cy - 24),
                (cx + sgn * (10 + spread * 0.6), cy - 34),
                3.2, 1.0, ANTLER, tip_col="gold",
            )
            # Inner antler tine
            body.bezier_limb(
                (cx + sgn * (12 + spread * 0.7), cy - 22),
                (cx + sgn * (8 + spread * 0.4), cy - 25),
                (cx + sgn * (6 + spread * 0.3), cy - 27),
                1.8, 0.7, ANTLER, tip_col="apricot",
            )
        body.eye(cx - 6.8, cy - 11.5, "coral" if p2 else "gold", "cream", "void", 3, 2)
        body.eye(cx + 3.8, cy - 11.5, "coral" if p2 else "gold", "cream", "void", 3, 2)
        body.shaded_ellipse(cx, cy - 5.2, 7.5, 2.6, BELLY)
    else:
        # Back view: colossal mirrored elytra split down the middle + golden tail rim
        for sgn in (-1.0, 1.0):
            for k, dy in enumerate((-3.5, -0.5, 2.5)):
                st = math.sin(ph + k * 1.4) * 1.8
                body.capsule(cx + sgn * 13.0, cy - 9.0 + dy, cx + sgn * 22.0, cy - 1.0 + dy + st, 2.8, 1.6, LEG)
        body.shaded_dome(cx, cy - 9.5, 20.0, 18.5, SHELL, bottom_cut=0.14)
        body.shaded_ellipse(cx, cy - 19.0, 14.8, 9.0, MIRROR, spec_col="cream")
        body.line(cx, cy - 27.5, cx, cy - 9.0, "pine")
        # Antler tips peeking above carapace
        for sgn in (-1.0, 1.0):
            body.bezier_limb((cx + sgn * 9, cy - 26), (cx + sgn * 14, cy - 32), (cx + sgn * 11, cy - 36), 2.4, 0.9, ANTLER, tip_col="gold")
        body.shaded_ellipse(cx, cy - 4.8, 10.5, 3.0, BELLY)

    if p2:
        # Heated cracked seam glow on carapace (overheat mechanic!)
        body.crack(cx - 8, cy - 18, cx + 4, cy - 11, "void", "coral", seed=17)
        body.crack(cx + 5, cy - 19, cx + 10, cy - 12, "void", "gold", seed=31)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 23, cy - 18 + math.sin(a) * 12, "gold" if k % 2 == 0 else "ice", protect=True)

    if ctx.is_tell and u > 0.30:
        gx = cx + (18 if d == "side" else 0)
        gy = cy - (20 if d == "side" else 30)
        fx_front.star4(gx, gy, 3 if u > 0.72 else 2, "cream", "ice")
        for k in range(4):
            fx_back.rect(cx - 16 + k * 8, ay - 2 - int(u * 5), 2, 2, "apricot" if k % 2 == 0 else "stone")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 10, cy - 13, 18, 15, -68, 68, 5.6, ("coral", "gold", "cream"))
            fx_back.line(cx - 28, cy - 18, cx - 14, cy - 18, "ice", protect=True)
            fx_back.line(cx - 26, cy - 12, cx - 15, cy - 12, "gold", protect=True)
        else:
            fx_front.slash_arc(cx, cy - 13, 24, 14, -155, -25, 5.8, ("coral", "gold", "cream"))

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="stag_colossus", name="The Stag Colossus", out_dir=ART_BOSSES,
    frame=(96, 82), anchor=(48, 64),
    body_radius=13.0, hit_radius=17.0, body_centre=(48, 46),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="pine",
    draw_frame=draw_stag_colossus,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
