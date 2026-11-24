#!/usr/bin/env python3
"""Island 6 Mini-Boss: The Brakeman (iron-clad railway conductor with oversized peaked brass cap, furnace chest grate, whistle & heavy coupling-chain flail) — 84x80, anchor [42, 64]."""
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

COAT = ("void", "night", "dusk", "plum")
APRON = ("night", "dusk", "mauve", "stone")
BRASS = ("plum", "coral", "apricot", "gold")
EMBER = ("wine", "coral", "apricot", "gold")


def _draw_conductor_cap(buf: PixelBuf, hx: float, hy: float, tilt: float, spin: bool, p2: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Wide shiny dark visor brim
    tmp.shaded_ellipse(hx + 2, hy + 1, 13.5, 3.6, ("void", "night", "dusk", "mauve"))
    # Tall peaked brass railway conductor crown
    tmp.shaded_poly([
        (hx - 10, hy), (hx - 12, hy - 9), (hx, hy - 12),
        (hx + 12, hy - 9), (hx + 10, hy),
    ], BRASS)
    tmp.line(hx - 10, hy - 2, hx + 10, hy - 2, "void")
    # Glowing brass rail-wheel emblem badge on front
    tmp.circle(hx + (3 if not spin else 0), hy - 6, 3.0, "night", protect=True)
    tmp.circle(hx + (3 if not spin else 0), hy - 6, 2.0, "gold" if not p2 else "coral", protect=True)
    tmp.set(hx + (3 if not spin else 0), hy - 6, "cream", protect=True)
    buf.composite(rotate_buf(tmp, hx, hy, tilt))


def _draw_chain_hook(buf: PixelBuf, p0: tuple[float, float], p1: tuple[float, float], hot: bool) -> None:
    buf.chain(p0, p1, 3.5, "coral" if hot else "mauve", "gold" if hot else "stone", "void", links=5)
    # Heavy coupling jaw-hook at end of chain
    hx, hy = p1
    ramp = EMBER if hot else APRON
    buf.shaded_ellipse(hx, hy, 5.2, 4.4, ramp)
    buf.shaded_poly([(hx + 2, hy - 5), (hx + 9, hy - 2), (hx + 5, hy + 1)], ramp)
    buf.shaded_poly([(hx + 2, hy + 5), (hx + 9, hy + 2), (hx + 5, hy - 1)], ramp)
    if hot:
        buf.set(hx + 5, hy, "cream", protect=True)


def draw_brakeman(ctx: FrameCtx) -> Image.Image:
    w, h = 98, 86
    ax, ay = 44.0, 68.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = abs(math.sin(ph)) * 1.6 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    crouch = 0.0
    cap_tilt = math.sin(lph) * 4.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 4.2 * u
        lean = -4.5 * u
        cap_tilt = -12.0 * u
        sx, sy = 1.08, 0.92
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 8.0 * sm
        crouch = 2.0 * sm
        cap_tilt = 14.0 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        crouch = 3.5 + math.sin(ph) * 0.8
        cap_tilt = 9.0
    elif ctx.is_stagger:
        # COMEDY BEAT: brass conductor cap spinning wildly on his nose!
        lean = math.sin(ph * 2.0) * 3.0
        cap_tilt = math.sin(ph * 2.0) * 38.0
        crouch = 2.5

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 2.0, 18.0, 2.8, "night")

    # Heavy iron-shod railway boots
    step = math.sin(ph) * 3.0 if ctx.anim in ("routine", "phase2") else 0.0
    if d == "side":
        body.shaded_rect(cx - 9 + step, ay - 8, 7, 8, COAT)
        body.shaded_rect(cx + 3 - step, ay - 8, 8, 8, APRON)
    else:
        body.shaded_rect(cx - 12, ay - 8 + step * 0.5, 8, 8, APRON)
        body.shaded_rect(cx + 4, ay - 8 - step * 0.5, 8, 8, APRON)

    # Wind-swept heavy railway greatcoat tails (lag phase!)
    tail_w = math.sin(lph) * 4.5 + (5.0 if p2 else 0.0)
    if d == "side":
        body.shaded_poly([
            (cx - 11, cy - 16), (cx - 19 - tail_w * 0.4, cy - 4),
            (cx - 9, cy - 3), (cx - 4, cy - 14),
        ], COAT)

    # Broad hunched iron-clad torso + heavy riveted steel apron
    body.shaded_ellipse(cx, cy - 20, 17.0 if d != "side" else 14.5, 16.0, COAT)
    if d != "back":
        aw = 15.0 if d == "front" else 10.0
        a_off = 4.0 if d == "side" else 0.0
        body.shaded_rect(cx + a_off - aw * 0.5, cy - 28, aw, 19, APRON)
        # Glowing furnace chest grate behind steel apron!
        gx = cx + a_off
        body.rect(gx - 5, cy - 25, 10, 8, "void", protect=True)
        body.rect(gx - 4, cy - 24, 8, 6, "coral" if not p2 else "gold", protect=True)
        body.rect(gx - 2, cy - 23, 4, 4, "gold" if not p2 else "cream", protect=True)
        for bar_x in (-2, 1):
            body.line(gx + bar_x, cy - 25, gx + bar_x, cy - 17, "night")
        # Brass coat buttons
        for by in (-14, -10):
            body.set(gx - 4, cy + by, "gold")
            body.set(gx + 3, cy + by, "gold")
    else:
        # Back brass brake-key harness & glowing coal vent
        body.shaded_rect(cx - 9, cy - 28, 18, 16, COAT)
        body.line(cx - 10, cy - 26, cx + 10, cy - 12, "apricot")
        body.line(cx + 10, cy - 26, cx - 10, cy - 12, "apricot")
        body.circle(cx, cy - 19, 3.2, "coral", protect=True)
        body.set(cx, cy - 19, "gold", protect=True)

    # Heavy riveted pauldrons
    if d != "side":
        body.shaded_ellipse(cx - 16, cy - 28, 6.0, 5.5, BRASS)
        body.shaded_ellipse(cx + 16, cy - 28, 6.0, 5.5, BRASS)
    else:
        body.shaded_ellipse(cx - 2, cy - 28, 6.8, 5.8, BRASS)

    # Hunched soot-bearded head + glowing coal eyes
    hx = cx + (5.0 if d == "side" else 0.0)
    hy = cy - 34.0
    body.shaded_ellipse(hx, hy, 9.5 if d != "side" else 8.5, 7.5, COAT)
    if d == "front":
        body.eye(hx - 4.0, hy - 1.0, "gold" if not p2 else "cream", "cream", "void", 3, 2)
        body.eye(hx + 2.0, hy - 1.0, "gold" if not p2 else "cream", "cream", "void", 3, 2)
        # Brass railway whistle clenched in mouth
        body.rect(hx + 2, hy + 2, 5, 2, "gold", protect=True)
    elif d == "side":
        body.eye(hx + 3.5, hy - 1.0, "gold" if not p2 else "cream", "cream", "void", 3, 2)
        body.rect(hx + 6, hy + 2, 5, 2, "gold", protect=True)

    # Oversized peaked brass conductor cap (drops onto nose during stagger comedy beat!)
    cap_y = hy - (2.0 if ctx.is_stagger else 6.5)
    _draw_conductor_cap(body, hx, cap_y, cap_tilt, ctx.is_stagger, p2)

    # Heavy coupling-chain flail arm!
    hot_chain = p2 or ctx.is_tell or ctx.is_commit
    if d == "side":
        sh_p = (cx + 4, cy - 22)
        if ctx.is_tell:
            end_p = (cx - 14, cy - 38 - u * 6)
        elif ctx.is_commit:
            end_p = (cx + 24, cy - 16 + math.sin(u * math.pi) * 6)
        elif ctx.is_recover:
            end_p = (cx + 18, ay - 5)
        else:
            end_p = (cx + 17 + math.sin(lph) * 4, cy - 12 + math.cos(lph) * 4)
        _draw_chain_hook(body, sh_p, end_p, hot_chain)
    else:
        sh_p = (cx + 16, cy - 22)
        if ctx.is_tell:
            end_p = (cx + 22, cy - 42)
        elif ctx.is_commit:
            end_p = (cx - 18, cy - 12)
        elif ctx.is_recover:
            end_p = (cx + 20, ay - 5)
        else:
            end_p = (cx + 22, cy - 9 + math.sin(lph) * 3)
        _draw_chain_hook(body, sh_p, end_p, hot_chain)

    # P2 furnace fissures & sparks
    if p2:
        body.crack(cx - 7, cy - 22, cx + 6, cy - 11, "void", "coral", seed=19)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 20, cy - 22 + math.sin(a) * 11, "gold" if k % 2 == 0 else "coral", protect=True)

    # FX overlays
    if ctx.is_tell:
        # Heel sparks on iron roof!
        fx_front.star4(cx - (6 if d == "side" else 10), ay - 2, 2, "cream", "gold")
        if u > 0.4:
            fx_front.star4(hx + (10 if d == "side" else 5), hy + 1, 3 if u > 0.72 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 11, cy - 18, 22, 16, -75, 70, 6.2, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 12, 26, 13, 15, 165, 6.0, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        # Jammed whistle puff + dizzy stars!
        fx_front.circle(hx + (12 if d == "side" else 8), hy + 1, 2.4, "stone", protect=True)
        fx_front.dizzy_stars(hx, hy - 14, 12.0, 3.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="brakeman", name="The Brakeman", out_dir=ART_BOSSES,
    frame=(98, 86), anchor=(44, 68),
    body_radius=11.0, hit_radius=16.0, body_centre=(44, 46),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="plum",
    draw_frame=draw_brakeman,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6")
