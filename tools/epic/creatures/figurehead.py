#!/usr/bin/env python3
"""Island 2 Boss: The Figurehead (carved gilded oak prow moth-figurehead & anchor chain) — 84x80, anchor [42, 63]."""
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

OAK_PEEL = ("void", "dusk", "plum", "wine")
GILDED_OAK = ("plum", "wine", "apricot", "gold")
GOLD_TRIM = ("wine", "apricot", "gold", "cream")
SALT_CRUST = ("blue", "sky", "ice", "cream")
IRON = ("night", "deep", "blue", "sky")


def _draw_anchor(buf: PixelBuf, cx: float, cy: float, ang_deg: float, hot: bool) -> None:
    tmp = PixelBuf(buf.w, buf.h)
    ramp = ("blue", "sky", "ice", "cream") if hot else IRON
    tmp.ring(cx, cy - 11, 2.6, "gold", 1.2)
    tmp.capsule(cx, cy - 8, cx, cy + 7, 1.9, 2.1, ramp)
    tmp.capsule(cx - 6, cy - 4.5, cx + 6, cy - 4.5, 1.4, 1.4, GOLD_TRIM)
    tmp.bezier_limb((cx - 10, cy + 2), (cx - 5.5, cy + 9.5), (cx, cy + 8), 1.5, 2.1, ramp, tip_col="ice" if hot else "sky")
    tmp.bezier_limb((cx + 10, cy + 2), (cx + 5.5, cy + 9.5), (cx, cy + 8), 1.5, 2.1, ramp, tip_col="ice" if hot else "sky")
    buf.composite(rotate_buf(tmp, cx, cy, ang_deg))


def _draw_carved_moth_wing(buf: PixelBuf, ox: float, oy: float, sgn: float, lift: float, wide: float, p2: bool) -> None:
    # Sculpted gilded-oak moth forewing sweeping like prow scrollwork
    fore_pts = [
        (ox, oy - 3),
        (ox + sgn * (19 * wide), oy - 16 - lift),
        (ox + sgn * (25 * wide), oy - 8 - lift * 0.6),
        (ox + sgn * (20 * wide), oy + 3 - lift * 0.2),
        (ox, oy + 4),
    ]
    buf.shaded_poly(fore_pts, GILDED_OAK)
    # Peeling oak hindwing scrolled under forewing
    hind_pts = [
        (ox, oy + 2),
        (ox + sgn * (17 * wide), oy + 4 - lift * 0.15),
        (ox + sgn * (13 * wide), oy + 14),
        (ox + sgn * (5 * wide), oy + 12),
        (ox, oy + 7),
    ]
    buf.shaded_poly(hind_pts, OAK_PEEL)
    # Carved gold leading-edge filigree rib & moth eyespot
    buf.line(ox, oy - 3, ox + sgn * (19 * wide), oy - 16 - lift, "gold")
    buf.line(ox + sgn * (19 * wide), oy - 16 - lift, ox + sgn * (24 * wide), oy - 8 - lift * 0.6, "cream")
    ex = ox + sgn * (13.0 * wide)
    ey = oy - 6.0 - lift * 0.5
    buf.circle(ex, ey, 3.6 * wide, "dusk")
    buf.circle(ex, ey, 2.4 * wide, "gold", protect=True)
    buf.set(ex, ey - 0.5, "cream", protect=True)
    # Ice salt-crust clinging to wingtip edges
    buf.set(ox + sgn * (22 * wide), oy - 6 - lift * 0.5, "ice", protect=True)
    buf.set(ox + sgn * (16 * wide), oy + 6, "ice", protect=True)
    if p2:
        buf.crack(ox + sgn * 4, oy - 2, ox + sgn * (17 * wide), oy - 9 - lift * 0.5, "void", "ice", seed=13)


def draw_figurehead(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 63.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.0
    lag_wave = math.sin(lph) * 3.0
    wing_lift = math.sin(ph) * 3.5
    wing_wide = 0.92 + 0.08 * math.cos(ph)
    prow_tilt = 0.0
    anc_ox, anc_oy, anc_ang = 17.0, -12.0, 20.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = -2.5 * u
        prow_tilt = -9.0 * u
        wing_lift = 7.0 * u
        wing_wide = 0.85
        anc_ox = (14.0 - 20.0 * u) if d == "side" else (17.0 + 3.0 * u)
        anc_oy = -22.0 - 5.0 * u
        anc_ang = -46.0 * u
        sx, sy = 0.96, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        prow_tilt = 13.0 * sm
        wing_lift = -6.0 * sm
        wing_wide = 1.05
        anc_ox = 22.0 * sm if d == "side" else (-15.0 + 31.0 * u)
        anc_oy = -8.0 + 5.0 * sm
        anc_ang = 76.0 * sm
        sx, sy = 1.08, 0.93
    elif ctx.is_recover:
        hover = 3.5
        prow_tilt = 9.0
        wing_lift = -4.0
        anc_ox, anc_oy, anc_ang = 14.0, -4.0, 38.0
    elif ctx.is_stagger:
        prow_tilt = -12.0 + math.sin(ph * 2.0) * 5.0
        wing_lift = math.sin(ph * 2.0) * 5.0
        anc_ox, anc_oy, anc_ang = 13.0, -5.0, 58.0

    cx = ax - (2.0 if d == "side" else 0.0)
    cy = ay - 5.0 + hover
    shadow.contact_shadow(ax, ay + 2.0, 15.0, 2.2, "night")

    prow = PixelBuf(w, h)

    # Sweeping carved gilded-oak moth wings (THE iconic prow-moth silhouette!)
    if d != "side":
        _draw_carved_moth_wing(prow, cx - 5, cy - 22, -1.0, wing_lift, wing_wide, p2)
        _draw_carved_moth_wing(prow, cx + 5, cy - 22, 1.0, wing_lift, wing_wide, p2)
    else:
        _draw_carved_moth_wing(fx_back, cx - 3, cy - 24, -1.0, wing_lift + 3.0, 0.88, p2)
        _draw_carved_moth_wing(prow, cx - 2, cy - 21, -1.0, wing_lift, 1.02, p2)

    # Torn wooden galleon prow hull & tapered carved moth abdomen keel
    if d == "side":
        hull_pts = [
            (cx - 8, cy - 24), (cx + 9, cy - 24), (cx + 16, cy - 13),
            (cx + 11, cy - 1), (cx - 1, cy + 5), (cx - 11, cy - 5),
        ]
    else:
        hull_pts = [
            (cx - 10, cy - 24), (cx + 10, cy - 24), (cx + 13, cy - 11),
            (cx + 7, cy + 1), (cx, cy + 6), (cx - 7, cy + 1), (cx - 13, cy - 11),
        ]
    prow.shaded_poly(hull_pts, OAK_PEEL)
    # Peeling gold leaf chevrons & clinker hull ribs
    for ry in (-19, -14, -9, -4):
        prow.line(cx - 9, cy + ry, cx + 9, cy + ry, "void")
    prow.shaded_poly([(cx - 7, cy - 23), (cx + 7, cy - 23), (cx, cy - 11)], GOLD_TRIM)
    # Ice salt-crust encrusted around broken keel timber
    prow.circle(cx - 6, cy - 4, 2.2, "ice")
    prow.circle(cx + 5, cy - 3, 2.0, "sky")
    prow.set(cx + 5, cy - 4, "cream")

    # Carved gilded-oak moth head + feathery gilded antennae crown!
    hx = cx + (5.5 if d == "side" else 0.0)
    hy = cy - 31.5
    prow.shaded_ellipse(hx, hy, 7.6 if d != "side" else 6.8, 7.2, GILDED_OAK, spec_col="cream")
    # Feathery gilded moth antennae curving high like figurehead crests
    ant_lag = math.sin(lph) * 2.2
    if d != "side":
        prow.bezier_limb((hx - 3, hy - 6), (hx - 11, hy - 14 + ant_lag), (hx - 17, hy - 11 + ant_lag), 2.1, 0.8, GOLD_TRIM, tip_col="cream")
        prow.bezier_limb((hx + 3, hy - 6), (hx + 11, hy - 14 - ant_lag), (hx + 17, hy - 11 - ant_lag), 2.1, 0.8, GOLD_TRIM, tip_col="cream")
        # Feather barbs on antennae
        for bx_o in (-8, -12, 8, 12):
            prow.set(hx + bx_o, hy - 15 + (ant_lag if bx_o < 0 else -ant_lag), "gold", protect=True)
    else:
        prow.bezier_limb((hx + 1, hy - 6), (hx + 8, hy - 15 + ant_lag), (hx + 15, hy - 13 + ant_lag), 2.0, 0.8, GOLD_TRIM, tip_col="cream")
        prow.bezier_limb((hx - 2, hy - 6), (hx + 2, hy - 16 - ant_lag), (hx + 8, hy - 16 - ant_lag), 1.6, 0.7, GILDED_OAK, tip_col="gold")

    # Fixed eerie painted cream eyes & serene unmoving wooden smile!
    if d == "front":
        prow.eye(hx - 4.0, hy - 1.5, "cream", "cream", "void", 2, 2)
        prow.eye(hx + 2.0, hy - 1.5, "cream", "cream", "void", 2, 2)
        # Serene painted wooden smile (never changes!)
        prow.line(hx - 3, hy + 2.5, hx, hy + 4.0, "void", protect=True)
        prow.line(hx, hy + 4.0, hx + 3, hy + 2.5, "void", protect=True)
        prow.set(hx - 2, hy + 2.5, "cream", protect=True)
        prow.set(hx + 2, hy + 2.5, "cream", protect=True)
    elif d == "side":
        prow.eye(hx + 3.0, hy - 1.5, "cream", "cream", "void", 2, 2)
        prow.line(hx + 1, hy + 3.0, hx + 5, hy + 2.0, "void", protect=True)
    else:
        # Carved wooden crest ridge down back of head
        prow.line(hx, hy - 6, hx, hy + 5, "gold")
        prow.set(hx, hy - 3, "ice", protect=True)

    if p2:
        prow.crack(cx - 5, cy - 20, cx + 4, cy - 5, "void", "ice", seed=13)
        prow.crack(cx + 5, cy - 17, cx - 2, cy - 4, "void", "gold", seed=17)

    body.composite(rotate_buf(prow, cx, cy - 16, prow_tilt))

    # Iron anchor chain & fluke tethered to torn prow
    hand_p = (cx + (6.0 if d == "side" else 8.0), cy - 14.0)
    anc_p = (cx + anc_ox, cy + anc_oy)
    body.chain(hand_p, anc_p, sag=5.0 + lag_wave * 0.45, link_col="blue", hi_col="ice", dark_col="night", links=6)
    _draw_anchor(body, anc_p[0], anc_p[1], anc_ang, hot=(p2 or ctx.is_tell or ctx.is_commit))

    if p2:
        for k in range(5):
            a = ph + k * (math.tau / 5.0)
            fx_front.star4(cx + math.cos(a) * 23, cy - 19 + math.sin(a) * 14, 1, "cream", "gold")
        fx_back.ring(cx, cy - 19, 23.0, "gold", 1.1, 0, 360, protect=True)
    if ctx.is_tell and u > 0.3:
        fx_front.star4(anc_p[0], anc_p[1] - 4, 3 if u > 0.7 else 2, "cream", "gold")
        fx_front.ring(hx, hy - 1, 4.5 + u * 3.5, "gold", 1.0, 0, 360, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 6, cy - 12, 23, 16, -65, 76, 6.2, ("apricot", "gold", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 10, 25, 14, -20, 190, 6.0, ("apricot", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 15, 11.5, 3.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="figurehead", name="The Figurehead", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 63),
    body_radius=12.0, hit_radius=16.0, body_centre=(42, 40),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="deep",
    draw_frame=draw_figurehead,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
