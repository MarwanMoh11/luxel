#!/usr/bin/env python3
"""Island 4 Mini-Boss B: The Cloud-Urn Deacon (levitating rain monk, 3 orbiting sky/ice urns, gold halo, swinging censer) — 84x80, anchor [42, 66]."""
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

ROBE = ("void", "night", "deep", "blue")
STOLE = ("night", "dusk", "plum", "wine")
CLOUD = ("blue", "sky", "ice", "cream")
URN = ("deep", "blue", "sky", "ice")
GOLD = ("wine", "apricot", "gold", "cream")


def _draw_urn(buf: PixelBuf, ux: float, uy: float, hot: bool = False) -> None:
    buf.shaded_ellipse(ux, uy, 4.4, 5.4, URN, spec_col="cream")
    buf.rect(ux - 3.0, uy - 5.5, 6, 2, "gold", protect=True)
    buf.line(ux - 2.0, uy - 5.5, ux + 2.0, uy - 5.5, "cream", protect=True)
    buf.line(ux - 3.0, uy + 1.0, ux + 3.0, uy + 1.0, "gold" if hot else "deep")
    if hot:
        buf.set(ux, uy - 1.0, "cream", protect=True)


def _draw_censer(buf: PixelBuf, hx: float, hy: float, swing_deg: float, hot: bool) -> None:
    rad = math.radians(swing_deg)
    cx = hx + math.sin(rad) * 14.0
    cy = hy + math.cos(rad) * 14.0
    buf.chain((hx, hy), (cx, cy - 2.0), 1.8, "apricot", "gold", "wine", links=5)
    buf.shaded_ellipse(cx, cy + 2.0, 4.2, 4.6, GOLD, spec_col="cream")
    buf.line(cx - 3.0, cy + 2.0, cx + 3.0, cy + 2.0, "sky" if not hot else "cream", protect=True)
    buf.set(cx, cy + 6.5, "ice" if not hot else "gold", protect=True)


def draw_boss_cloud_deacon(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 80
    ax, ay = 42.0, 70.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = 4.0 + math.sin(ph) * 2.0
    lean = 0.0
    censer_deg = math.sin(lph) * 16.0
    urn_r_x = 18.0
    urn_r_y = 6.5
    cloud_scale = 1.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = 5.0 + u * 1.5
        lean = -4.0 * u
        censer_deg = -58.0 * u - 10.0
        urn_r_x = 18.0 + 5.5 * u
        sx, sy = 0.94, 1.05
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.55) * math.pi)
        hover = 5.0 - 2.0 * sm
        lean = 6.5 * sm
        censer_deg = -40.0 + 115.0 * sm
        urn_r_x = 23.0
        sx, sy = 1.09, 0.93
    elif ctx.is_recover:
        hover = 2.0 + math.sin(ph) * 0.8
        lean = 2.0
        censer_deg = 22.0 + math.sin(ph * 2.0) * 12.0
        cloud_scale = 0.72  # Comedy beat: shrunk cloud wig while fanning!
    elif ctx.is_stagger:
        hover = 1.5
        lean = math.sin(ph * 2.0) * 3.0
        censer_deg = -34.0 + math.sin(ph * 2.0) * 20.0
        cloud_scale = 0.65

    cx = ax + (lean if d == "side" else 0.0)
    cy = ay - hover
    shadow.contact_shadow(ax, ay + 1.5, 13.5, 2.2, "night")

    # Back orbiting rain-urns (behind body when sin(ang) < 0)
    urn_base = ph * (1.5 if p2 else 1.0)
    urn_coords = []
    for k in range(3):
        ang = urn_base + k * (math.tau / 3.0)
        ux = cx + math.cos(ang) * urn_r_x
        uy = cy - 22.0 + math.sin(ang) * urn_r_y
        urn_coords.append((math.sin(ang), ux, uy))
    for depth, ux, uy in urn_coords:
        if depth < 0.0:
            _draw_urn(body, ux, uy, hot=p2 or ctx.is_tell)

    # Golden monastic nimbus halo behind hood
    hx = cx + (2.5 if d == "side" else 0.0)
    hy = cy - 40.0
    halo_r = 12.0 if not p2 else 13.5
    fx_back.ring(hx, hy - 2.0, halo_r, "gold" if not p2 else "cream", 1.5, protect=True)
    fx_back.ring(hx, hy - 2.0, halo_r - 2.2, "apricot" if not p2 else "sky", 1.0, protect=True)
    for sp in range(8):
        sa = sp * (math.tau / 8.0) + (ph * 0.25 if p2 else 0.0)
        fx_back.line(
            hx + math.cos(sa) * (halo_r - 1), hy - 2.0 + math.sin(sa) * (halo_r - 1),
            hx + math.cos(sa) * (halo_r + 3.0), hy - 2.0 + math.sin(sa) * (halo_r + 3.0),
            "gold", protect=True,
        )

    # Levitating deep/blue liturgical deacon robe with tattered rain-tassel hem
    robe_w = 13.0 if d != "side" else 11.0
    sway = math.sin(lph) * 2.8
    body.shaded_poly([
        (cx - robe_w * 0.62, cy - 34), (cx + robe_w * 0.62, cy - 34),
        (cx + robe_w + sway * 0.3, cy - 4), (cx + robe_w * 0.45, cy - 7),
        (cx, cy - 2), (cx - robe_w * 0.45, cy - 7), (cx - robe_w + sway * 0.3, cy - 4),
    ], ROBE)
    # Gold liturgical stole down the center (or clasped cape on back)
    if d != "side":
        body.rect(cx - 2.5, cy - 31, 5, 24, "gold")
        body.line(cx, cy - 30, cx, cy - 8, "cream", protect=True)
        body.rect(cx - 3.5, cy - 9, 7, 2, "apricot")
    else:
        body.line(cx + 4.0, cy - 31, cx + 6.0 + sway * 0.2, cy - 6, "gold")
        body.line(cx - 4.0, cy - 30, cx - 7.0 + sway * 0.3, cy - 6, "void")
    # Hooded cowl mantle
    body.shaded_dome(cx, cy - 30.0, 13.0 if d != "side" else 10.5, 8.5, STOLE, bottom_cut=0.22)
    body.line(cx - 10, cy - 28, cx + 10, cy - 28, "gold")

    # Rain-cloud cowl & puffy cumulus wig crest!
    cw = 11.0 * cloud_scale
    ch = 6.2 * cloud_scale
    body.shaded_dome(hx, hy - 1.5, cw, ch + 3.5, CLOUD, bottom_cut=0.12, spec_col="cream")
    body.shaded_ellipse(hx - 5.5 * cloud_scale, hy - 4.5, 4.8 * cloud_scale, 4.2 * cloud_scale, CLOUD)
    body.shaded_ellipse(hx + 5.0 * cloud_scale, hy - 4.0, 4.6 * cloud_scale, 4.0 * cloud_scale, CLOUD)
    body.shaded_ellipse(hx, hy - 8.2 * cloud_scale, 5.2 * cloud_scale, 4.2 * cloud_scale, CLOUD, spec_col="cream")

    # Deep hood shadow & glowing eye-slits
    if d == "front":
        body.shaded_ellipse(hx, hy + 2.0, 6.2, 5.2, ("void", "void", "night"))
        body.eye(hx - 3.2, hy + 1.5, "gold" if not p2 else "ice", "cream", "void", 2, 2)
        body.eye(hx + 1.5, hy + 1.5, "gold" if not p2 else "ice", "cream", "void", 2, 2)
    elif d == "side":
        body.shaded_ellipse(hx + 2.8, hy + 2.0, 4.5, 5.0, ("void", "void", "night"))
        body.eye(hx + 4.2, hy + 1.5, "gold" if not p2 else "ice", "cream", "void", 2, 2)
    else:
        body.shaded_dome(hx, hy + 3.5, 7.2, 6.5, ROBE, bottom_cut=0.1)
        body.line(hx, hy - 2.0, hx, hy + 7.0, "gold")

    # Sleeves & swinging brass rain-censer
    if d == "front":
        body.shaded_ellipse(cx - 12.0, cy - 21.0, 4.0, 6.5, ROBE)
        body.shaded_ellipse(cx + 12.0, cy - 21.0, 4.0, 6.5, ROBE)
        _draw_censer(body, cx + 13.0, cy - 18.0, censer_deg, p2 or ctx.is_tell)
    elif d == "side":
        body.shaded_ellipse(cx + 7.0, cy - 22.0, 4.2, 5.5, ROBE)
        _draw_censer(body, cx + 10.0, cy - 20.0, censer_deg, p2 or ctx.is_tell)
    else:
        body.shaded_ellipse(cx - 12.0, cy - 22.0, 4.0, 6.0, ROBE)
        body.shaded_ellipse(cx + 12.0, cy - 22.0, 4.0, 6.0, ROBE)

    # Front orbiting rain-urns (in front of body when sin(ang) >= 0)
    for depth, ux, uy in urn_coords:
        if depth >= 0.0:
            _draw_urn(body, ux, uy, hot=p2 or ctx.is_tell)

    if p2:
        body.crack(cx - 4, cy - 24, cx + 4, cy - 12, "void", "sky", seed=23)
        for k in range(4):
            a = ph * 1.4 + k * 1.57
            fx_front.set(cx + math.cos(a) * 19.0, cy - 22.0 + math.sin(a) * 11.0, "ice" if k % 2 == 0 else "sky", protect=True)

    if ctx.is_tell and u > 0.30:
        fx_front.ring(cx, cy - 24.0, 15.0 + u * 5.0, "sky", 1.2, protect=True)
        fx_front.star4(hx + (9 if d == "side" else 0), hy - 11.0, 3 if u > 0.72 else 2, "cream", "gold")
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(cx + 10, cy - 18, 20, 15, -62, 62, 5.4, ("blue", "sky", "cream"))
        else:
            fx_front.slash_arc(cx, cy - 16, 24, 12, 12, 168, 5.4, ("blue", "sky", "cream"))
        for k in range(5):
            rx = cx - 12 + k * 6
            fx_front.line(rx, cy - 36 + (k % 2) * 5, rx - 1, cy - 31 + (k % 2) * 5, "ice", protect=True)
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 14.0, 10.0, 3.0, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="boss_cloud_deacon", name="The Cloud-Urn Deacon", out_dir=ART_BOSSES,
    frame=(84, 80), anchor=(42, 70),
    body_radius=10.5, hit_radius=15.0, body_centre=(42, 44),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="deep",
    draw_frame=draw_boss_cloud_deacon,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
