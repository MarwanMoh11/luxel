#!/usr/bin/env python3
"""Island 7 Mini-Boss: The Prompter (Velvet marionette conductor with comedy/tragedy split mask, gold baton, and twin rose-gold cords) — 84x88, anchor [42, 74]."""
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

VELVET = ("night", "plum", "wine", "coral")
GOLD_BATON = ("wine", "apricot", "gold", "cream")
MASK_LIGHT = ("stone", "gold", "cream")
MASK_DARK = ("void", "night", "plum", "wine")
WOOD_BAR = ("night", "plum", "wine", "apricot")


def draw_the_prompter(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 88
    ax, ay = 42.0, 74.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.2
    sway = math.sin(lph) * 2.5
    baton_ang = -35.0 + math.sin(ph) * 22.0
    left_raise = math.cos(ph) * 4.0
    cords_cut = ctx.is_stagger
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = -3.0 * u
        baton_ang = -80.0 - 25.0 * u
        left_raise = -8.0 * u
        sx, sy = 0.94, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.45) * math.pi)
        hover = -1.5 * sm
        baton_ang = -85.0 + 175.0 * min(1.0, u * 1.35)
        left_raise = 6.0 * sm
        sx, sy = 1.08, 0.94
    elif ctx.is_recover:
        hover = 3.5
        baton_ang = 52.0
        left_raise = 4.0
    elif ctx.is_stagger:
        # Crashed into orchestra pit with slumped torso & flying sheet music!
        hover = 9.5
        baton_ang = 75.0
        left_raise = 9.0
        sx, sy = 1.10, 0.88

    cx = ax + sway * 0.4
    cy = ay - 8.0 + hover

    # Spotlight glow pool beneath conductor + crisp SE shadow
    shadow.contact_shadow(ax + 2.0, ay + 2.0, 16.0, 3.4, "night")
    if p2:
        fx_back.ring(ax, ay + 1.0, 19.0, "gold", 1.2)

    # Overhead marionette wooden crossbar & twin glowing rose-gold cords (THE signature silhouette!)
    bar_y = 9.0 + (2.0 if ctx.is_recover else 0.0)
    if not cords_cut:
        fx_back.shaded_rect(cx - 18, bar_y - 2, 36, 3.5, WOOD_BAR)
        fx_back.shaded_rect(cx - 2.5, bar_y - 4.5, 5, 7, GOLD_BATON)
        cord_col = "coral" if (ctx.is_tell or p2) else "rose"
        fx_back.line(cx - 13, bar_y + 1, cx - 10, cy - 30, cord_col, protect=True)
        fx_back.line(cx + 13, bar_y + 1, cx + 10, cy - 30, cord_col, protect=True)
        fx_back.set(cx - 13, bar_y + 1, "cream", protect=True)
        fx_back.set(cx + 13, bar_y + 1, "cream", protect=True)
        if p2:
            fx_back.line(cx - 6, bar_y + 1, cx - 4, cy - 38, "gold", protect=True)
            fx_back.line(cx + 6, bar_y + 1, cx + 4, cy - 38, "gold", protect=True)
    else:
        # Snapped dangling cord stubs
        fx_back.line(cx - 13, bar_y + 1, cx - 15, bar_y + 12, "rose", protect=True)
        fx_back.line(cx + 13, bar_y + 1, cx + 15, bar_y + 10, "rose", protect=True)

    # Flaring swallowtail velvet conductor coat (long dramatic twin tails!)
    tw = 14.0 if d != "side" else 11.0
    body.shaded_poly([
        (cx - 7, cy - 30), (cx + 7, cy - 30),
        (cx + tw, cy - 10), (cx + tw + 3, cy + 4),
        (cx + 4, cy - 3), (cx, cy - 9),
        (cx - 4, cy - 3), (cx - tw - 3, cy + 4),
        (cx - tw, cy - 10),
    ], VELVET)
    # Gold piping lapels & music-staff waistcoat
    if d != "back":
        body.shaded_poly([
            (cx - 4, cy - 29), (cx + 4, cy - 29),
            (cx + 5, cy - 13), (cx, cy - 9), (cx - 5, cy - 13),
        ], ("void", "night", "dusk"))
        body.line(cx - 5, cy - 28, cx - 1, cy - 14, "gold", protect=True)
        body.line(cx + 5, cy - 28, cx + 1, cy - 14, "gold", protect=True)
        body.set(cx, cy - 23, "cream", protect=True)
        body.set(cx, cy - 18, "gold", protect=True)
    else:
        body.line(cx, cy - 28, cx, cy - 10, "gold", protect=True)
        body.line(cx - 7, cy - 20, cx + 7, cy - 20, "apricot", protect=True)

    # Ornate high scalloped collar
    body.shaded_poly([
        (cx - 11, cy - 31), (cx - 8, cy - 37), (cx, cy - 32),
        (cx + 8, cy - 37), (cx + 11, cy - 31), (cx, cy - 27),
    ], GOLD_BATON)

    # Jointed puppet shoulders & white-gloved conducting arms + long gleaming gold baton!
    sh_y = cy - 28.0
    b_rad = math.radians(baton_ang)
    if d != "side":
        # Left gesturing arm (holds sheet-music scroll / rose cue)
        lx = cx - 18.0
        ly = sh_y + 2.0 + left_raise
        body.bezier_limb((cx - 8, sh_y), (cx - 14, sh_y + 4), (lx, ly), 2.4, 1.5, VELVET, tip_col="cream")
        body.circle(lx, ly, 2.3, "cream", protect=True)
        # Right baton arm
        rx = cx + 17.0
        ry = sh_y + math.sin(b_rad) * 7.0
        body.bezier_limb((cx + 8, sh_y), (cx + 14, sh_y + 2), (rx, ry), 2.4, 1.5, VELVET, tip_col="cream")
        body.circle(rx, ry, 2.3, "cream", protect=True)
        # Long Conductor's Baton
        bx = rx + math.cos(b_rad) * 20.0
        by = ry + math.sin(b_rad) * 20.0
        fx_front.line(rx, ry, bx, by, "gold", protect=True)
        fx_front.line(rx, ry - 1, bx, by - 1, "cream", protect=True)
        fx_front.star4(bx, by, 2 if not ctx.is_tell else 3, "cream", "coral" if p2 else "gold")
    else:
        rx = cx + 14.0
        ry = sh_y + math.sin(b_rad) * 6.0
        body.bezier_limb((cx + 2, sh_y), (cx + 9, sh_y + 3), (rx, ry), 2.5, 1.5, VELVET, tip_col="cream")
        body.circle(rx, ry, 2.4, "cream", protect=True)
        bx = rx + math.cos(b_rad) * 22.0
        by = ry + math.sin(b_rad) * 22.0
        fx_front.line(rx, ry, bx, by, "gold", protect=True)
        fx_front.line(rx, ry - 1, bx, by - 1, "cream", protect=True)
        fx_front.star4(bx, by, 2 if not ctx.is_tell else 3, "cream", "coral" if p2 else "gold")

    # Comedy / Tragedy Split Porcelain Mask Head!
    hx = cx + (1.5 if d == "side" else 0.0)
    hy = cy - 41.0
    if d == "front":
        # Left half Comedy (cream/gold smile), Right half Tragedy (wine/plum weep)
        body.shaded_ellipse(hx, hy, 8.2, 8.8, MASK_LIGHT, spec_col="cream")
        body.shaded_poly([
            (hx, hy - 8.5), (hx + 7.8, hy - 4), (hx + 8.0, hy + 4),
            (hx + 4.0, hy + 8.5), (hx, hy + 8.8),
        ], MASK_DARK)
        body.line(hx, hy - 8, hx, hy + 8, "gold", protect=True)
        # Split expressive eyes & comedy/tragedy mouth
        body.eye(hx - 3.6, hy - 1.5, "gold", "cream", "void", 2, 2)
        body.eye(hx + 3.2, hy - 1.5, "coral", "cream", "void", 2, 2)
        body.line(hx - 5.0, hy + 2.5, hx - 1.5, hy + 4.0, "void", protect=True)  # smile
        body.line(hx + 1.5, hy + 4.5, hx + 5.0, hy + 2.8, "rose", protect=True)  # frown
    elif d == "side":
        body.shaded_ellipse(hx, hy, 7.6, 8.6, MASK_LIGHT if not p2 else MASK_DARK, spec_col="cream")
        body.eye(hx + 3.5, hy - 1.5, "coral", "cream", "void", 2, 2)
        body.line(hx + 1.0, hy + 3.5, hx + 6.0, hy + 2.5, "gold", protect=True)
    else:
        body.shaded_ellipse(hx, hy, 8.0, 8.5, MASK_DARK)
        body.line(hx - 4, hy - 2, hx + 4, hy - 2, "gold", protect=True)
        body.line(hx, hy - 6, hx, hy + 6, "rose", protect=True)

    # Tall velvet maestro hat / twin horn-crest
    body.shaded_poly([
        (hx - 8, hy - 6), (hx - 6, hy - 14), (hx, hy - 11),
        (hx + 6, hy - 14), (hx + 8, hy - 6),
    ], VELVET)
    body.line(hx - 7, hy - 6, hx + 7, hy - 6, "gold", protect=True)

    # Tell / Commit / Stagger FX
    if ctx.is_tell and u > 0.2:
        fx_front.ring(cx, cy - 22, 6.0 + (1.0 - u) * 10.0, "coral", 1.4)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 16, cy - 24, 24, 18, -75, 75, 5.5, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx + 4, cy - 22, 28, 16, -40, 200, 5.5, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        # Comedy beat: upside-down flying sheet music pages around crashed conductor!
        fx_front.shaded_rect(cx - 22, cy - 24, 8, 6, ("stone", "cream"))
        fx_front.line(cx - 21, cy - 22, cx - 15, cy - 22, "void")
        fx_front.shaded_rect(cx + 15, cy - 28, 8, 6, ("stone", "cream"))
        fx_front.line(cx + 16, cy - 26, cx + 22, cy - 26, "void")
        fx_front.dizzy_stars(hx, hy - 13, 10.0, 2.8, ph)
    elif p2:
        fx_front.star4(cx - 18, cy - 16, 2, "cream", "gold")
        fx_front.star4(cx + 18, cy - 16, 2, "cream", "coral")

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="the_prompter", name="The Prompter", out_dir=ART_BOSSES,
    frame=(84, 88), anchor=(42, 74),
    body_radius=11.0, hit_radius=15.0, body_centre=(42, 46),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="night",
    draw_frame=draw_the_prompter,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
