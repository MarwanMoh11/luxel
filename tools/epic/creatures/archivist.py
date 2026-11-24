#!/usr/bin/env python3
"""Island 8 Boss: The Archivist (hooded moth-owl librarian, 8 biome ribbons, floating open brass folio) — 104x98, anchor [52, 80]."""
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

ROBE = ("void", "night", "dusk", "plum")
MANTLE = ("night", "dusk", "plum", "mauve")
BRASS = ("plum", "coral", "apricot", "gold")
PARCHMENT = ("mauve", "stone", "gold", "cream")
RIBBON_COLS = ("gold", "sky", "jade", "lime", "blue", "coral", "ice", "rose")


def _draw_open_tome(buf: PixelBuf, tx: float, ty: float, tilt: float, open_w: float, glow_col: str, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    # Brass cover plates angled into V-spine
    hw = open_w
    tmp.shaded_poly([
        (tx, ty + 4), (tx - hw - 2, ty + 1), (tx - hw - 1, ty - 10), (tx, ty - 7),
    ], BRASS)
    tmp.shaded_poly([
        (tx, ty + 4), (tx + hw + 2, ty + 1), (tx + hw + 1, ty - 10), (tx, ty - 7),
    ], BRASS)
    # Illuminated parchment pages
    tmp.shaded_poly([
        (tx - 1, ty + 2), (tx - hw, ty - 1), (tx - hw + 1, ty - 9), (tx - 1, ty - 6),
    ], PARCHMENT)
    tmp.shaded_poly([
        (tx + 1, ty + 2), (tx + hw, ty - 1), (tx + hw - 1, ty - 9), (tx + 1, ty - 6),
    ], PARCHMENT)
    # Center brass spine & glowing chapter sigils
    tmp.line(tx, ty - 7, tx, ty + 4, "gold", protect=True)
    tmp.line(tx - hw + 3, ty - 5, tx - 3, ty - 3, glow_col, protect=True)
    tmp.line(tx + 3, ty - 3, tx + hw - 3, ty - 5, "cream" if hot else glow_col, protect=True)
    if hot:
        tmp.star4(tx, ty - 12, 3, "cream", glow_col)
    buf.composite(rotate_buf(tmp, tx, ty, tilt))


def _draw_ribbons(buf: PixelBuf, cx: float, cy: float, d: str, lph: float, spread: float) -> None:
    # 8 biome-coloured trailing bookmark ribbons
    for i, col in enumerate(RIBBON_COLS):
        side = -1.0 if i < 4 else 1.0
        idx = i if i < 4 else i - 4
        if d == "side":
            base_x = cx - 6.0 - idx * 1.4
            base_y = cy - 16.0 + (idx - 1.5) * 4.2 + (2.0 if i >= 4 else -2.0)
            wave = math.sin(lph + i * 0.85) * (4.0 + spread * 2.5)
            p1 = (base_x - 10.0 - spread * 4.0, base_y + wave * 0.5)
            p2 = (base_x - 20.0 - spread * 6.0, base_y + 7.0 + wave)
        else:
            ang = (-2.45 + idx * 0.30) if side < 0 else (-0.69 - idx * 0.30)
            base_x = cx + side * (11.0 + idx * 1.8)
            base_y = cy - 18.0 + idx * 3.5
            wave = math.sin(lph + i * 0.9) * (3.2 + spread * 2.0)
            p1 = (base_x + math.cos(ang) * (10.0 + spread * 3.0), base_y + 4.0 + wave * 0.6)
            p2 = (base_x + side * (17.0 + idx * 1.5 + spread * 4.0), base_y + 13.0 + wave)
        buf.line(base_x, base_y, p1[0], p1[1], col, protect=True)
        buf.line(p1[0], p1[1], p2[0], p2[1], col, protect=True)
        buf.rect(p2[0] - 1, p2[1] - 1, 2, 2, "cream" if i % 3 == 0 else col, protect=True)


def draw_archivist(ctx: FrameCtx) -> Image.Image:
    w, h = 104, 98
    ax, ay = 52.0, 80.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.4 if ctx.anim in ("routine", "phase2") else 0.0
    lean = 0.0
    tome_lift = math.sin(lph) * 1.8
    tome_tilt = math.sin(lph) * 5.0
    rib_spread = 0.25 if not p2 else 0.65
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = 3.2 * u
        tome_lift = 7.0 * u
        tome_tilt = -12.0 * u
        rib_spread = 0.4 + 0.9 * u
        sx, sy = 0.95, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.4) * math.pi)
        lean = 5.5 * sm
        tome_lift = 3.5 * sm
        tome_tilt = 16.0 * sm
        rib_spread = 1.2 * sm
        sx, sy = 1.08, 0.94
    elif ctx.is_recover:
        hover = -2.0
        tome_lift = -3.0
        tome_tilt = 8.0
    elif ctx.is_stagger:
        hover = -3.5
        tome_lift = -5.0
        tome_tilt = 24.0 + math.sin(ph * 2.0) * 10.0
        lean = math.sin(ph * 2.0) * 2.5

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - 12.0 - hover
    shadow.contact_shadow(ax, ay + 2.0, 17.0, 2.8, "night")

    # Trailing 8 biome ribbons behind body
    _draw_ribbons(fx_back, cx, cy, d, lph, rib_spread)

    # Flowing scholar moth-robe
    sway = math.sin(lph) * 2.5
    robe_w = 15.0 if d != "side" else 11.5
    body.shaded_poly([
        (cx - robe_w * 0.72, cy - 28), (cx + robe_w * 0.72, cy - 28),
        (cx + robe_w + sway * 0.4, cy + 5), (cx + robe_w * 0.55 + sway, cy + 11),
        (cx + sway * 0.5, cy + 7), (cx - robe_w * 0.55 + sway, cy + 11),
        (cx - robe_w + sway * 0.4, cy + 5),
    ], ROBE)

    # Broad moth-wing shoulder mantle (wide dramatic silhouette!)
    wing_w = 24.0 if d != "side" else 14.0
    wing_flap = math.sin(ph) * 2.4 + (3.0 if ctx.is_tell else (-2.5 if ctx.is_commit else 0.0))
    if d != "side":
        body.shaded_poly([
            (cx - 10, cy - 29), (cx - wing_w, cy - 24 - wing_flap),
            (cx - wing_w + 3, cy - 11 - wing_flap * 0.4), (cx - 12, cy - 13),
        ], MANTLE)
        body.shaded_poly([
            (cx + 10, cy - 29), (cx + wing_w, cy - 24 - wing_flap),
            (cx + wing_w - 3, cy - 11 - wing_flap * 0.4), (cx + 12, cy - 13),
        ], MANTLE)
        # Brass-trimmed moth eye-spots on wing mantle
        body.ring(cx - wing_w + 7, cy - 18 - wing_flap * 0.6, 3.0, "gold", 1.2)
        body.circle(cx - wing_w + 7, cy - 18 - wing_flap * 0.6, 1.4, "sky" if p2 else "apricot", protect=True)
        body.ring(cx + wing_w - 7, cy - 18 - wing_flap * 0.6, 3.0, "gold", 1.2)
        body.circle(cx + wing_w - 7, cy - 18 - wing_flap * 0.6, 1.4, "rose" if p2 else "apricot", protect=True)
    else:
        body.shaded_poly([
            (cx - 4, cy - 29), (cx - 18, cy - 23 - wing_flap),
            (cx - 16, cy - 9 - wing_flap * 0.4), (cx + 5, cy - 14),
        ], MANTLE)
        body.ring(cx - 11, cy - 17 - wing_flap * 0.5, 3.0, "gold", 1.2)
        body.circle(cx - 11, cy - 17 - wing_flap * 0.5, 1.4, "sky" if p2 else "apricot", protect=True)

    # Gold scholarly stole / back 8-island emblem
    if d == "front":
        body.line(cx - 5, cy - 27, cx - 7, cy + 4, "gold")
        body.line(cx + 5, cy - 27, cx + 7, cy + 4, "gold")
    elif d == "back":
        body.ring(cx, cy - 16, 6.0, "gold", 1.3)
        for k in range(8):
            a = k * (math.tau / 8.0)
            body.rect(cx + math.cos(a) * 5.0 - 0.5, cy - 16 + math.sin(a) * 5.0 - 0.5, 2, 2, RIBBON_COLS[k], protect=True)

    # Hooded Moth-Owl Head with sweeping feathered ear-tufts & spectacles!
    hx = cx + (3.5 if d == "side" else 0.0)
    hy = cy - 35.0
    body.shaded_dome(hx, hy + 2.0, 10.5 if d != "side" else 9.0, 10.5, ROBE, bottom_cut=0.1)
    # Tall twin moth-owl ear tufts
    tuft_sw = math.sin(lph) * 1.6
    body.bezier_limb((hx - 6, hy - 6), (hx - 12, hy - 14 + tuft_sw), (hx - 16, hy - 18 + tuft_sw), 2.4, 0.8, BRASS, "cream")
    body.bezier_limb((hx + 6, hy - 6), (hx + 12, hy - 14 - tuft_sw), (hx + 16, hy - 18 - tuft_sw), 2.4, 0.8, BRASS, "cream")
    # Hood rim
    body.line(hx - 8, hy + 4, hx + 8, hy + 4, "gold")

    if d == "front":
        body.shaded_ellipse(hx, hy + 0.5, 7.6, 5.8, ("void", "void", "night", "dusk"))
        # Luminous crescent librarian spectacles + glowing owl eyes
        body.ring(hx - 3.6, hy + 0.2, 2.7, "gold", 1.1, protect=True)
        body.ring(hx + 3.6, hy + 0.2, 2.7, "gold", 1.1, protect=True)
        body.line(hx - 1.0, hy + 0.2, hx + 1.0, hy + 0.2, "gold", protect=True)
        eye_c = "ice" if p2 else "gold"
        body.eye(hx - 3.6, hy + 0.2, eye_c, "cream", "void", 2, 2)
        body.eye(hx + 3.6, hy + 0.2, eye_c, "cream", "void", 2, 2)
    elif d == "side":
        body.shaded_ellipse(hx + 2.5, hy + 0.5, 5.5, 5.5, ("void", "void", "night", "dusk"))
        body.ring(hx + 4.0, hy + 0.2, 2.7, "gold", 1.1, protect=True)
        body.eye(hx + 4.4, hy + 0.2, "ice" if p2 else "gold", "cream", "void", 2, 2)
    else:
        body.line(hx, hy - 8, hx, hy + 4, "gold")

    # Floating Illuminated Brass Open Folio Tome!
    hot = p2 or ctx.is_tell or ctx.is_commit
    glow_col = "sky" if p2 else ("coral" if ctx.is_commit else "gold")
    if d == "front":
        _draw_open_tome(body, cx, cy - 11.0 - tome_lift, tome_tilt, 12.5, glow_col, hot)
    elif d == "side":
        _draw_open_tome(body, cx + 15.0, cy - 15.0 - tome_lift, tome_tilt, 10.5, glow_col, hot)
    else:
        # Tome peeks brightly behind scholar on back view
        _draw_open_tome(fx_back, cx, cy - 16.0 - tome_lift, -tome_tilt, 12.0, glow_col, hot)

    if p2:
        # Orbiting Chapter Seals (3 biome colours)
        for k in range(3):
            a = ph + k * (math.tau / 3.0)
            sx_p = cx + math.cos(a) * 26.0
            sy_p = cy - 18.0 + math.sin(a) * 11.0
            fx_front.ring(sx_p, sy_p, 2.8, ("gold", "jade", "sky")[k], 1.1, protect=True)
            fx_front.set(sx_p, sy_p, "cream", protect=True)

    if ctx.is_tell and u > 0.25:
        tx = cx + (15.0 if d == "side" else 0.0)
        ty = cy - 18.0 - tome_lift
        fx_front.ring(tx, ty, 19.0 - u * 6.0, "gold", 1.3, protect=True)
        fx_front.star4(tx, ty - 6, 3 if u > 0.65 else 2, "cream", "sky" if p2 else "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 16, cy - 16, 22, 16, -70, 70, 5.5, ("sky" if p2 else "coral", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 14, 28, 15, 10, 170, 5.5, ("sky" if p2 else "coral", "gold", "cream"))
        # Flying illuminated pages!
        for k in range(4):
            pa = -0.6 + k * 0.42
            px_p = cx + math.cos(pa) * (17 + ctx.fi * 3.5)
            py_p = cy - 18 + math.sin(pa) * 12
            fx_front.rect(px_p - 2, py_p - 1, 4, 3, "cream", protect=True)
            fx_front.rect(px_p - 1, py_p, 2, 1, "gold", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 14, 12.0, 3.5, ph)
        fx_front.rect(cx - 18, cy - 28 + math.sin(ph) * 4, 4, 3, "cream", protect=True)
        fx_front.rect(cx + 15, cy - 24 - math.sin(ph) * 4, 4, 3, "stone", protect=True)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="archivist", name="The Archivist", out_dir=ART_BOSSES,
    frame=(104, 98), anchor=(52, 80),
    body_radius=13.0, hit_radius=17.0, body_centre=(52, 50),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="dusk",
    draw_frame=draw_archivist,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
