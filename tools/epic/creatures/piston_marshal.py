#!/usr/bin/env python3
"""Island 6 Iron Colossus Mini-Boss: The Piston Marshal (stocky riveted brass-and-dusk automaton with giant telescoping jackhammer right arm and glowing back steam-valve) — 92x84, anchor [46, 68]."""
from __future__ import annotations

import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from creature import (  # noqa: E402
    ART_BOSSES, BOSS_ANIMS, CACHE_DIR, RAMPS, CreatureSpec, FrameCtx, PixelBuf,
    export_creature, finalize_frame, rotate_buf,
)

HULL = ("void", "night", "dusk", "mauve")
PLATE = ("night", "dusk", "mauve", "stone")
BRASS = ("plum", "coral", "apricot", "gold")
STEAM = ("deep", "blue", "sky", "ice")


def _draw_jackhammer(buf: PixelBuf, px: float, py: float, deg: float, ext: float, hot: bool, rattle: float = 0.0) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    rx = px + rattle
    # Heavy hydraulic cylinder casing
    tmp.shaded_rect(rx - 5, py - 10, 10, 18, BRASS)
    tmp.line(rx - 4, py - 5, rx + 4, py - 5, "void")
    tmp.line(rx - 4, py + 2, rx + 4, py + 2, "gold")
    # Pressure coil gauge on side of cylinder
    tmp.rect(rx - 2, py - 3, 4, 4, "coral" if hot else "apricot", protect=True)
    tmp.set(rx - 1, py - 2, "cream" if hot else "gold", protect=True)
    # Telescoping steel piston rod + chisel ram head
    rod_len = 12.0 + ext
    tmp.shaded_rect(rx - 2.5, py + 8, 5, rod_len, PLATE)
    tip_y = py + 8 + rod_len
    tmp.shaded_poly([
        (rx - 6, tip_y - 2), (rx + 6, tip_y - 2),
        (rx + 4, tip_y + 5), (rx, tip_y + 9), (rx - 4, tip_y + 5),
    ], ("wine", "coral", "apricot", "gold") if hot else PLATE)
    if hot:
        tmp.line(rx - 2, tip_y + 3, rx + 2, tip_y + 3, "cream", protect=True)
    buf.composite(rotate_buf(tmp, px, py, deg))


def draw_piston_marshal(ctx: FrameCtx) -> Image.Image:
    w, h = 120, 102
    ax, ay = 52.0, 74.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    bob = abs(math.sin(ph)) * 1.5 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    crouch = 0.0
    arm_deg = -18.0 + math.sin(ph) * 6.0
    arm_ext = 2.0 + math.sin(ph) * 1.5
    helm_jitter = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        crouch = 4.2 * u
        lean = -4.0 * u
        arm_deg = -68.0 * u if d == "side" else -40.0 * u
        arm_ext = -2.0 * u
        sx, sy = 1.09, 0.91
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        lean = 7.5 * sm
        crouch = 1.8 * sm
        arm_deg = -84.0 if d == "side" else 16.0 * sm
        arm_ext = 11.0 * sm
        sx, sy = 1.12, 0.90
    elif ctx.is_recover:
        # Jackhammer jammed into deck — comedy sideways dakka-dakka rattle!
        crouch = 4.5
        arm_deg = -6.0 if d == "side" else 4.0
        arm_ext = 6.0 + (2.0 if ctx.fi % 2 == 0 else -1.5)
        helm_jitter = 2.8 if ctx.fi % 2 == 0 else -2.8
    elif ctx.is_stagger:
        crouch = 3.2
        lean = math.sin(ph * 2.0) * 3.0
        helm_jitter = math.sin(ph * 3.0) * 3.5
        arm_deg = 28.0
        arm_ext = 0.0

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - bob + crouch
    shadow.contact_shadow(ax, ay + 2.0, 18.0, 2.8, "night")

    # Heavy cleated hydraulic boots
    step = math.sin(ph) * 2.4 if ctx.anim in ("routine", "phase2") else 0.0
    if d == "side":
        body.shaded_rect(cx - 10 + step, ay - 10, 9, 10, HULL)
        body.shaded_rect(cx + 2 - step, ay - 10, 9, 10, PLATE)
        body.rect(cx - 10 + step, ay - 2, 9, 2, "gold")
        body.rect(cx + 2 - step, ay - 2, 9, 2, "gold")
    else:
        body.shaded_rect(cx - 13, ay - 10 + step * 0.5, 9, 10, HULL)
        body.shaded_rect(cx + 4, ay - 10 - step * 0.5, 9, 10, HULL)
        body.rect(cx - 13, ay - 2 + step * 0.5, 9, 2, "gold")
        body.rect(cx + 4, ay - 2 - step * 0.5, 9, 2, "gold")

    # Back glowing steam-valve boiler (weak spot when quenched with Blue!)
    valve_col = "ice" if ctx.is_stagger else ("cream" if (ctx.is_tell or p2) else "coral")
    if d == "side":
        body.shaded_rect(cx - 17, cy - 33, 9, 18, BRASS)
        body.circle(cx - 16, cy - 24, 3.2, valve_col, protect=True)
        body.set(cx - 16, cy - 24, "cream" if not ctx.is_stagger else "sky", protect=True)
        # Rear exhaust chimney
        body.shaded_rect(cx - 15, cy - 41, 4, 8, PLATE)
    elif d == "back":
        body.shaded_rect(cx - 11, cy - 34, 22, 20, BRASS)
        body.circle(cx, cy - 24, 6.2, "void", protect=True)
        body.circle(cx, cy - 24, 4.6, valve_col, protect=True)
        body.circle(cx, cy - 24, 2.2, "gold" if not ctx.is_stagger else "cream", protect=True)
        # Twin rear steam stacks
        body.shaded_rect(cx - 12, cy - 42, 4, 9, PLATE)
        body.shaded_rect(cx + 8, cy - 42, 4, 9, PLATE)

    # Stocky riveted boiler torso
    bw = 16.0 if d != "side" else 13.5
    body.shaded_ellipse(cx, cy - 22, bw, 14.5, PLATE)
    # Diagonal brass bandolier & riveted belly plate
    body.shaded_rect(cx - bw + 3, cy - 28, (bw - 3) * 2, 13, HULL)
    body.line(cx - bw + 4, cy - 28, cx + bw - 4, cy - 28, "gold")
    body.line(cx - bw + 4, cy - 16, cx + bw - 4, cy - 16, "apricot")
    if d == "front":
        # Chest pressure cylinder core
        body.rect(cx - 6, cy - 26, 12, 8, "void", protect=True)
        body.rect(cx - 5, cy - 25, 10, 6, "coral" if not ctx.is_stagger else "blue", protect=True)
        body.rect(cx - 3, cy - 24, 6, 4, "gold" if not ctx.is_stagger else "ice", protect=True)
        body.rect(cx - 1, cy - 23, 2, 2, "cream", protect=True)
        # Shoulder exhaust vents visible behind
        body.shaded_rect(cx - 13, cy - 41, 4, 8, BRASS)
        body.shaded_rect(cx + 9, cy - 41, 4, 8, BRASS)

    # Riveted brass pauldrons
    if d != "side":
        body.shaded_ellipse(cx - 17, cy - 30, 6.2, 5.5, BRASS)
        body.shaded_ellipse(cx + 17, cy - 30, 6.2, 5.5, BRASS)
    else:
        body.shaded_ellipse(cx + 3, cy - 30, 6.5, 5.5, BRASS)

    # Heavy flat-topped riveted Marshal helmet (vibrates sideways in recover/stagger!)
    hx = cx + helm_jitter + (3.0 if d == "side" else 0.0)
    hy = cy - 37.0
    body.shaded_rect(hx - 9, hy - 7, 18, 13, PLATE)
    body.shaded_poly([(hx - 10, hy - 6), (hx - 6, hy - 11), (hx + 6, hy - 11), (hx + 10, hy - 6)], BRASS)
    body.line(hx - 9, hy - 6, hx + 9, hy - 6, "gold")
    if d == "front":
        body.rect(hx - 7, hy - 2, 14, 3, "void", protect=True)
        eye_c = "ice" if ctx.is_stagger else ("cream" if p2 else "gold")
        body.eye(hx - 4.5, hy - 1, eye_c, "cream", "void", 3, 2)
        body.eye(hx + 2.0, hy - 1, eye_c, "cream", "void", 3, 2)
    elif d == "side":
        body.rect(hx + 1, hy - 2, 8, 3, "void", protect=True)
        eye_c = "ice" if ctx.is_stagger else ("cream" if p2 else "gold")
        body.eye(hx + 4.5, hy - 1, eye_c, "cream", "void", 3, 2)

    # Left bracing fist + Giant telescoping JACKHAMMER right arm
    hot_w = p2 or ctx.is_tell or ctx.is_commit
    rattle_v = (1.6 if ctx.fi % 2 == 0 else -1.6) if ctx.is_recover else 0.0
    if d == "front":
        body.capsule(cx - 17, cy - 26, cx - 21, cy - 14, 3.2, 3.0, HULL)
        body.shaded_ellipse(cx - 21, cy - 12, 4.2, 3.8, BRASS)
        _draw_jackhammer(body, cx + 20, cy - 20, arm_deg, arm_ext, hot_w, rattle_v)
    elif d == "side":
        _draw_jackhammer(body, cx + 10, cy - 22, arm_deg, arm_ext, hot_w, rattle_v)
    else:
        body.capsule(cx - 17, cy - 26, cx - 20, cy - 14, 3.0, 2.8, HULL)
        _draw_jackhammer(body, cx + 20, cy - 20, -arm_deg * 0.5, arm_ext * 0.6, hot_w, rattle_v)

    # Phase 2 glowing fissures & overheated vents
    if p2:
        body.crack(cx - 7, cy - 26, cx + 6, cy - 16, "void", "coral", seed=17)
        for k in range(4):
            a = ph + k * 1.57
            fx_front.set(cx + math.cos(a) * 22, cy - 22 + math.sin(a) * 11, "gold" if k % 2 == 0 else "coral", protect=True)

    # FX overlays
    if ctx.is_tell:
        # Steam hiss jets from back/shoulder vents + hydraulic glint
        fx_front.circle(cx - (15 if d == "side" else 11), cy - 43 - u * 4.0, 2.3, "cream", protect=True)
        if d != "side":
            fx_front.circle(cx + 11, cy - 43 - u * 4.0, 2.3, "cream", protect=True)
        if u > 0.35:
            fx_front.star4(cx + (18 if d == "side" else 20), cy - 16, 3 if u > 0.7 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 16, cy - 18, 22, 13, -55, 55, 5.8, ("coral", "apricot", "cream"))
        else:
            fx_front.slash_arc(cx + 4, cy - 10, 26, 13, 10, 170, 5.5, ("coral", "gold", "cream"))
    elif ctx.is_recover:
        # Comedy vibration lines around rattling helmet & jammed floor sparks!
        fx_front.line(hx - 13, hy - 4, hx - 11, hy - 1, "gold", protect=True)
        fx_front.line(hx + 11, hy - 4, hx + 13, hy - 1, "gold", protect=True)
        fx_front.set(cx + (14 if d == "side" else 20), ay - 2, "cream", protect=True)
    elif ctx.is_stagger:
        # Quenched frost steam & dizzy stars!
        fx_front.circle(cx, cy - 26 - (ctx.fi % 3) * 3, 2.8, "ice", protect=True)
        fx_front.dizzy_stars(hx, hy - 13, 12.0, 3.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="piston_marshal", name="The Piston Marshal", out_dir=ART_BOSSES,
    frame=(120, 102), anchor=(52, 74),
    body_radius=11.0, hit_radius=17.0, body_centre=(52, 52),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_piston_marshal,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview_i6b")
