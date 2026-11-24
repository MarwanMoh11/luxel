#!/usr/bin/env python3
"""Island 6 Superboss: The First Forge (monumental floating four-armed obsidian-and-brass Anvil Deity with blazing furnace-eye crown, 3 stance-colored crest gems gold/apricot/coral, twin forge hammers & shield tongs) — 108x98, anchor [54, 78]."""
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

OBSIDIAN = ("void", "night", "dusk", "plum")
BRASS = ("plum", "coral", "apricot", "gold")
STEEL = ("night", "dusk", "mauve", "stone")


def _draw_hammer(buf: PixelBuf, px: float, py: float, deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    tmp.capsule(px, py + 12, px, py - 14, 1.8, 1.6, STEEL)
    # Massive horned forge hammer head
    tmp.shaded_rect(px - 8, py - 21, 16, 9, ("wine", "coral", "apricot", "gold") if hot else OBSIDIAN)
    tmp.line(px - 7, py - 20, px + 7, py - 20, "gold")
    tmp.line(px - 7, py - 13, px + 7, py - 13, "apricot" if hot else "stone")
    if hot:
        tmp.rect(px - 3, py - 18, 6, 3, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, deg))


def _draw_tongs(buf: PixelBuf, px: float, py: float, deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Curved anvil shield-tongs
    tmp.bezier_limb((px, py + 6), (px - 7, py - 4), (px - 3, py - 14), 2.2, 1.3, BRASS)
    tmp.bezier_limb((px, py + 6), (px + 7, py - 4), (px + 3, py - 14), 2.2, 1.3, BRASS)
    if hot:
        tmp.circle(px, py - 7, 2.5, "gold", protect=True)
        tmp.set(px, py - 7, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, deg))


def draw_first_forge(ctx: FrameCtx) -> Image.Image:
    w, h = 128, 120
    ax, ay = 64.0, 96.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.6 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    ham_deg = 12.0 + math.sin(ph) * 8.0
    tong_deg = -10.0 - math.sin(lph) * 8.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover += 4.0 * u
        ham_deg = -42.0 * u
        tong_deg = 32.0 * u
        sx, sy = 0.94, 1.08
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        hover -= 5.0 * sm
        lean = 5.0 * sm
        ham_deg = 62.0 * sm
        tong_deg = -45.0 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        hover -= 4.0
        ham_deg = 30.0
    elif ctx.is_stagger:
        hover -= 6.0
        lean = math.sin(ph * 2.0) * 3.5
        ham_deg = -55.0
        tong_deg = 50.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 16.0 - hover
    shadow.contact_shadow(ax, ay + 2.0, 24.0, 3.4, "night")

    # Floating obsidian ANVIL PEDESTAL base (horned anvil silhouette hovering over lava embers!)
    aw = 20.0 if d != "side" else 16.0
    body.shaded_poly([
        (cx - aw - 4, cy - 8), (cx + aw + 4, cy - 8),
        (cx + aw - 2, cy - 1), (cx + 10, cy + 5), (cx + 14, cy + 12),
        (cx - 14, cy + 12), (cx - 10, cy + 5), (cx - aw + 2, cy - 1),
    ], OBSIDIAN)
    body.line(cx - aw - 2, cy - 8, cx + aw + 2, cy - 8, "gold")
    # Glowing molten underside ember core
    body.ellipse(cx, cy + 12, 9.0, 2.8, "coral" if not ctx.is_stagger else "sky", protect=True)
    body.ellipse(cx, cy + 12, 5.0, 1.5, "gold" if not ctx.is_stagger else "ice", protect=True)

    # Towering obsidian-and-brass Foundry Torso
    tw = 17.0 if d != "side" else 14.0
    body.shaded_poly([
        (cx - tw, cy - 34), (cx + tw, cy - 34),
        (cx + tw - 4, cy - 8), (cx - tw + 4, cy - 8),
    ], OBSIDIAN)
    body.line(cx - tw + 1, cy - 34, cx + tw - 1, cy - 34, "gold")
    body.line(cx - tw + 3, cy - 20, cx + tw - 3, cy - 20, "apricot")

    # Blazing furnace-heart chest crucible & rear quench valve
    if d != "back":
        fx_c = cx + (4.0 if d == "side" else 0.0)
        body.shaded_poly([(fx_c - 8, cy - 29), (fx_c + 8, cy - 29), (fx_c + 5, cy - 13), (fx_c - 5, cy - 13)], BRASS)
        body.rect(fx_c - 5, cy - 26, 10, 10, "void", protect=True)
        body.rect(fx_c - 4, cy - 25, 8, 8, "coral" if not ctx.is_stagger else "sky", protect=True)
        body.rect(fx_c - 2, cy - 23, 4, 5, "gold" if not ctx.is_stagger else "ice", protect=True)
        body.set(fx_c, cy - 21, "cream", protect=True)
    else:
        # Rear quench valve (Skip-bank weak spot!)
        body.shaded_rect(cx - 10, cy - 30, 20, 18, STEEL)
        body.circle(cx, cy - 21, 5.5, "void", protect=True)
        body.circle(cx, cy - 21, 4.0, "gold" if not ctx.is_stagger else "ice", protect=True)
        body.circle(cx, cy - 21, 2.0, "cream", protect=True)

    # Monumental ANVIL-CROWN HEAD with blazing furnace eye & 3 STANCE CREST GEMS (gold / apricot / coral)!
    hx = cx + (3.0 if d == "side" else 0.0)
    hy = cy - 42.0
    body.shaded_poly([
        (hx - 14, hy - 8), (hx + 14, hy - 8),
        (hx + 9, hy + 6), (hx - 9, hy + 6),
    ], OBSIDIAN)
    # 3 floating brass crest prongs carrying the 3 Temper Gems (SKIP=gold, SCATTER=apricot, LANCE=coral)!
    gem_specs = [(-10, -14, "gold"), (0, -17, "apricot"), (10, -14, "coral")]
    if d == "side":
        gem_specs = [(-5, -14, "gold"), (2, -17, "apricot"), (9, -14, "coral")]
    for gx_o, gy_o, gcol in gem_specs:
        body.line(hx + gx_o * 0.6, hy - 8, hx + gx_o, hy + gy_o + 2, "gold")
        body.circle(hx + gx_o, hy + gy_o, 2.6, "void", protect=True)
        body.circle(hx + gx_o, hy + gy_o, 1.8, "ice" if ctx.is_stagger else gcol, protect=True)
        body.set(hx + gx_o, hy + gy_o - 1, "cream", protect=True)

    # Single blazing primordial furnace-eye crown!
    if d == "front":
        body.rect(hx - 7, hy - 3, 14, 5, "void", protect=True)
        body.eye(hx, hy - 1, "cream" if (p2 or ctx.is_tell) else "gold", "cream", "void", 4, 3)
    elif d == "side":
        body.rect(hx + 2, hy - 3, 7, 5, "void", protect=True)
        body.eye(hx + 5.5, hy - 1, "cream" if (p2 or ctx.is_tell) else "gold", "cream", "void", 3, 3)

    # FOUR FLOATING ARMS: Upper twin Forge Hammers + Lower twin Shield Tongs!
    hot_w = p2 or ctx.is_tell or ctx.is_commit
    if d != "side":
        # Upper shoulders + twin Forge Hammers
        body.shaded_ellipse(cx - 23, cy - 36, 5.5, 5.0, BRASS)
        body.shaded_ellipse(cx + 23, cy - 36, 5.5, 5.0, BRASS)
        _draw_hammer(body, cx - 29, cy - 30, -ham_deg, hot_w)
        _draw_hammer(body, cx + 29, cy - 30, ham_deg, hot_w)
        # Lower floating forearms + twin curved Shield Tongs
        body.shaded_ellipse(cx - 22, cy - 16, 4.5, 4.0, STEEL)
        body.shaded_ellipse(cx + 22, cy - 16, 4.5, 4.0, STEEL)
        _draw_tongs(body, cx - 28, cy - 12, -tong_deg, hot_w)
        _draw_tongs(body, cx + 28, cy - 12, tong_deg, hot_w)
    else:
        # Side profile: front hammer + rear counter-hammer + forward shield tongs!
        body.shaded_ellipse(cx + 12, cy - 35, 5.5, 5.0, BRASS)
        _draw_hammer(body, cx + 19, cy - 28, ham_deg, hot_w)
        _draw_hammer(body, cx - 18, cy - 32, -ham_deg * 0.6, hot_w)
        _draw_tongs(body, cx + 16, cy - 12, tong_deg, hot_w)

    # Phase 2/3 molten casting aura & fissures
    if p2:
        body.crack(cx - 10, cy - 32, cx + 9, cy - 12, "void", "gold", seed=67)
        body.crack(cx - 14, cy - 6, cx + 12, cy + 4, "void", "coral", seed=73)
        for k in range(6):
            a = ph + k * (math.pi / 3.0)
            fx_back.ring(cx, cy - 20, 32.0 + math.sin(ph) * 2.0, "gold" if k % 2 == 0 else "coral", 1.2, k * 60 + 8, k * 60 + 44, protect=True)

    # FX overlays
    if ctx.is_tell:
        fx_front.ring(cx, cy - 22, 30.0 - 14.0 * u, "gold", 1.5, protect=True)
        if u > 0.35:
            fx_front.star4(hx, hy - 17, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 16, cy - 20, 26, 18, -75, 75, 6.5, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 14, 34, 16, 5, 175, 6.5, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.star4(cx, cy - 22, 3, "cream", "ice")
        fx_front.dizzy_stars(hx, hy - 20, 15.0, 4.2, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="first_forge", name="The First Forge", out_dir=ART_BOSSES,
    frame=(128, 120), anchor=(64, 96),
    body_radius=13.5, hit_radius=20.0, body_centre=(64, 62),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_first_forge,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6b")
