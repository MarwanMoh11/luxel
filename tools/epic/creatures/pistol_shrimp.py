#!/usr/bin/env python3
"""Island 2 Enemy: Pistol Shrimp (recoil sniper with giant snapping claw) — 60x52, anchor [30, 41]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_ENEMIES, CACHE_DIR, ENEMY_ANIMS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

SHELL = ("plum", "wine", "coral", "rose")
TAIL = ("night", "wine", "coral", "apricot")
CLAW = ("wine", "coral", "apricot", "gold")
HOT_CLAW = ("coral", "apricot", "gold", "cream")


def _draw_pistol_claw(buf: PixelBuf, cx: float, cy: float, ang_deg: float, open_gap: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ramp = HOT_CLAW if hot else CLAW
    # Oversized bulbous snapping chamber
    tmp.shaded_ellipse(cx, cy, 8.2, 5.8, ramp, spec_col="cream")
    # Fixed lower barrel jaw
    tmp.shaded_poly([
        (cx + 3, cy + 1), (cx + 13, cy + 2), (cx + 11, cy + 5), (cx + 2, cy + 5),
    ], ramp)
    # Hinged upper plunger hammer (cocks wide open in TELL, slams shut in COMMIT!)
    hy = -open_gap * 5.0
    tmp.shaded_poly([
        (cx + 2, cy - 4), (cx + 12, cy - 4 + hy), (cx + 10, cy - 1 + hy), (cx + 3, cy - 1),
    ], ("apricot", "gold", "cream") if hot else ramp)
    # Brass pressure seam
    tmp.line(cx - 4, cy - 1, cx + 4, cy - 1, "wine")
    tmp.set(cx + 2, cy - 2, "cream", protect=True)
    buf.composite(rotate_buf(tmp, cx, cy, ang_deg))


def draw_pistol_shrimp(ctx: FrameCtx) -> Image.Image:
    w, h = 76, 54
    ax, ay = 38.0, 42.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase

    scuttle = abs(math.sin(ph)) * 1.5 if ctx.anim == "routine" else 0.0
    feel = math.sin(lph) * 3.0
    recoil_x = 0.0
    claw_gap = 0.25 + 0.15 * abs(math.sin(ph))
    claw_ang = math.sin(ph) * 6.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        claw_gap = 0.3 + 0.85 * u
        claw_ang = -14.0 * u
        recoil_x = 2.0 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        # Giant recoil kick backward!
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        claw_gap = 0.0
        claw_ang = 12.0 * sm
        recoil_x = -8.5 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        claw_gap = 0.1
        recoil_x = -3.0 * (1.0 - u)
        sx, sy = 1.04, 0.95
    elif ctx.is_stagger:
        claw_gap = 0.6
        claw_ang = 26.0 + math.sin(ph * 2.0) * 10.0
        recoil_x = -2.5

    cx = ax + (recoil_x if d == "side" else 0.0)
    cy = ay - 8.0 - scuttle
    shadow.contact_shadow(ax, ay + 1.0, 11.0, 2.0, "night")

    # Walking shrimp legs
    for k in range(-2, 3):
        lx = cx + k * 3.2
        lshift = math.sin(ph + k * 1.2) * 1.8 if ctx.anim == "routine" else 0.0
        body.line(lx, cy + 4, lx + lshift, ay, "wine")
        body.set(lx + lshift, ay, "coral")

    if d == "side":
        # Curled segmented prawn tail fan on left
        body.shaded_ellipse(cx - 10, cy + 1, 5.2, 4.4, TAIL)
        body.shaded_ellipse(cx - 15, cy + 4, 4.2, 3.6, TAIL)
        body.shaded_poly([(cx - 18, cy + 3), (cx - 22, cy + 1), (cx - 21, cy + 8), (cx - 16, cy + 7)], ("coral", "apricot", "gold"))
        # Main arched shrimp carapace
        body.shaded_ellipse(cx - 2, cy - 1, 8.8, 6.4, SHELL, spec_col="cream")
        body.line(cx - 5, cy - 6, cx - 5, cy + 4, "wine")
        body.line(cx - 1, cy - 6, cx - 1, cy + 4, "wine")
        # Long sweeping antennae
        body.bezier_limb((cx + 5, cy - 5), (cx + 12, cy - 12 + feel), (cx + 18, cy - 11 + feel), 1.2, 0.6, ("rose", "cream"))
        body.bezier_limb((cx + 4, cy - 4), (cx - 4, cy - 13 - feel), (cx - 12, cy - 12 - feel), 1.1, 0.5, ("coral", "rose"))
        # Stalked eyes
        body.eye(cx + 5.5, cy - 4.0, "ice", "cream", "void", 2, 2)
        # Signature colossal snapping pistol claw!
        _draw_pistol_claw(body, cx + 8.0, cy - 0.5, claw_ang, claw_gap, hot=(ctx.is_tell or ctx.is_commit))
    elif d == "front":
        body.shaded_ellipse(cx, cy - 1, 8.2, 6.8, SHELL, spec_col="cream")
        body.bezier_limb((cx - 4, cy - 6), (cx - 11, cy - 14 + feel), (cx - 16, cy - 12 + feel), 1.1, 0.5, ("rose", "cream"))
        body.bezier_limb((cx + 4, cy - 6), (cx + 11, cy - 14 - feel), (cx + 16, cy - 12 - feel), 1.1, 0.5, ("rose", "cream"))
        # Small left pincer
        body.shaded_ellipse(cx - 9.0, cy + 1.0, 3.4, 2.8, SHELL)
        # Stalked eyes
        body.eye(cx - 4.0, cy - 4.5, "ice", "cream", "void", 2, 2)
        body.eye(cx + 2.0, cy - 4.5, "ice", "cream", "void", 2, 2)
        # Colossal right pistol claw dominating silhouette
        _draw_pistol_claw(body, cx + 7.5, cy + 0.5, claw_ang - 12, claw_gap, hot=(ctx.is_tell or ctx.is_commit))
    else:
        # Back view: segmented arched tail plates + big claw jutting right
        body.shaded_ellipse(cx, cy - 2, 8.2, 6.6, SHELL)
        for sy_o in (-3, 0, 3):
            body.line(cx - 6, cy + sy_o, cx + 6, cy + sy_o, "wine")
        body.shaded_poly([(cx - 6, cy + 5), (cx + 6, cy + 5), (cx + 9, cy + 10), (cx - 9, cy + 10)], ("coral", "apricot", "gold"))
        body.bezier_limb((cx - 4, cy - 7), (cx - 11, cy - 14 + feel), (cx - 16, cy - 12 + feel), 1.1, 0.5, ("rose", "cream"))
        body.bezier_limb((cx + 4, cy - 7), (cx + 11, cy - 14 - feel), (cx + 16, cy - 12 - feel), 1.1, 0.5, ("rose", "cream"))
        _draw_pistol_claw(body, cx + 8.5, cy - 1.0, claw_ang, claw_gap, hot=(ctx.is_tell or ctx.is_commit))

    # Cavitation bubble FX!
    muzzle_x = cx + (19.0 if d == "side" else 14.0)
    muzzle_y = cy - 1.0
    if ctx.is_tell and u > 0.2:
        br = max(2.2, 8.5 - u * 5.8)
        fx_front.ring(muzzle_x, muzzle_y, br, "coral" if u > 0.65 else "ice", 1.2, 0, 360, protect=True)
        fx_front.star4(muzzle_x, muzzle_y, 2 if u > 0.65 else 1, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (0, 1, 2):
        fx_front.slash_arc(muzzle_x - 3, muzzle_y, 12 + ctx.fi * 2, 8 + ctx.fi, -48, 48, 4.4, ("coral", "gold", "cream"))
        fx_front.star4(muzzle_x + 3, muzzle_y, 3, "cream", "gold")
    elif ctx.is_recover:
        fx_front.circle(muzzle_x - 2, muzzle_y - 4 - (ctx.fi % 3) * 2.5, 1.6, "ice", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(cx, cy - 13, 9.0, 2.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="pistol_shrimp", name="Pistol Shrimp", out_dir=ART_ENEMIES,
    frame=(76, 54), anchor=(38, 42),
    body_radius=5.5, hit_radius=10.0, body_centre=(38, 31),
    anims=list(ENEMY_ANIMS), cool_rim=False, biome_bg="deep",
    draw_frame=draw_pistol_shrimp,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
