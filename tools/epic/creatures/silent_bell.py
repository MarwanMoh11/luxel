#!/usr/bin/env python3
"""Island 1 Superboss: The Silent Bell (superboss_silent) — 84x80, anchor [42, 62]."""
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

OBSIDIAN = ("void", "night", "dusk", "mauve")
BELL_RIM = ("night", "dusk", "mauve", "stone")
MUTE_ICE = ("deep", "blue", "sky", "ice")
DAWN_CRACK = ("coral", "apricot", "gold", "cream")


def _draw_orbit_shard(buf: PixelBuf, sx: float, sy: float, p2: bool) -> None:
    pts = [(sx, sy - 4.0), (sx + 3.2, sy), (sx, sy + 4.5), (sx - 3.2, sy)]
    buf.shaded_poly(pts, OBSIDIAN)
    buf.set(sx, sy - 2.0, "ice" if not p2 else "coral", protect=True)


def draw_silent_bell(ctx: FrameCtx) -> Image.Image:
    w, h = 84, 84
    ax, ay = 42.0, 66.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.8
    tilt = math.sin(lph) * 3.5
    clapper_off = math.sin(ph) * 4.0
    mouth_open = False
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        hover = -3.5 * u
        tilt = -7.0 * u
        clapper_off = -6.0 * u
        sx, sy = 0.95, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.5) * math.pi)
        hover = 4.5 * sm
        tilt = 11.0 * sm
        clapper_off = 9.0 * sm
        sx, sy = 1.11, 0.91
    elif ctx.is_recover:
        # Tilts up exposing its hollow dark mouth — throw lantern INSIDE!
        hover = -1.5
        tilt = -20.0 if d == "side" else 0.0
        mouth_open = True
    elif ctx.is_stagger:
        # Lantern trapped inside: shivering with radiant gold-white cracks!
        hover = math.sin(ph * 3.0) * 1.8
        tilt = math.sin(ph * 3.0) * 9.0
        sx, sy = 1.04, 0.97

    cx = ax
    cy = ay - 22.0 + hover
    # Silent floor perspective dust-ripple ellipse (clean flat oval beneath levitating bell!)
    shadow.contact_shadow(ax, ay + 2.0, 17.5, 2.8, "void")
    rip_rx = 16.0 + (u * 8.0 if ctx.is_commit else abs(math.sin(ph)) * 3.0)
    rip_ry = 4.2 + (u * 1.8 if ctx.is_commit else abs(math.sin(ph)) * 0.8)
    rip_col = "gold" if ctx.is_stagger else "ice"
    for k in range(28):
        a0 = k * (math.tau / 28.0)
        a1 = (k + 0.65) * (math.tau / 28.0)
        fx_back.line(ax + math.cos(a0) * rip_rx, ay + 2.0 + math.sin(a0) * rip_ry,
                     ax + math.cos(a1) * rip_rx, ay + 2.0 + math.sin(a1) * rip_ry, rip_col, protect=True)

    bell = PixelBuf(w, h)

    # Ornate gothic headstock yoke & silence-crown loop at top
    bell.ring(cx, cy - 23.0, 4.2, "mauve", 1.5)
    bell.shaded_rect(cx - 7.5, cy - 21.0, 15, 4, BELL_RIM)

    # Monumental levitating flared obsidian-bronze cathedral bell silhouette!
    dome_rx = 13.5 if d != "side" else 12.5
    bell.shaded_dome(cx, cy - 6.0, dome_rx, 15.0, OBSIDIAN, bottom_cut=0.10)
    skirt_pts = [
        (cx - dome_rx, cy - 7.0), (cx + dome_rx, cy - 7.0),
        (cx + dome_rx + 5.5, cy + 9.0), (cx - dome_rx - 5.5, cy + 9.0),
    ]
    bell.shaded_poly(skirt_pts, OBSIDIAN)
    # Flared bronze lip rim
    lip_ry = 6.2 if mouth_open else 4.2
    bell.shaded_ellipse(cx, cy + 9.5, dome_rx + 5.5, lip_ry, BELL_RIM)

    # Hollow dark mouth interior (opens wide during recover to invite thrown lantern!)
    mouth_col = "gold" if ctx.is_stagger else "void"
    bell.ellipse(cx, cy + 10.5, dome_rx + 2.0, lip_ry - 1.2, mouth_col)
    if mouth_open:
        # Stark pale-ice inviting target ring inside open mouth!
        bell.ring(cx, cy + 10.5, 7.5, "ice", 1.2, 0, 360, protect=True)
        bell.circle(cx, cy + 10.5, 2.2, "cream", protect=True)
    elif ctx.is_stagger:
        # Brilliant trapped lantern core shining out from inside the bell!
        bell.circle(cx, cy + 10.5, 6.5, "gold", protect=True)
        bell.circle(cx, cy + 10.5, 3.5, "cream", protect=True)

    # Ghostly floating pale-ice shadow clapper suspended below mouth
    if not mouth_open and not ctx.is_stagger:
        cl_x = cx + clapper_off
        cl_y = cy + 14.5
        bell.line(cx, cy + 9.0, cl_x, cl_y, "mauve")
        bell.shaded_ellipse(cl_x, cl_y, 3.6, 3.6, MUTE_ICE, spec_col="cream")

    # Gothic raised sound-bow moldings & eerie carved rune bands
    bell.line(cx - dome_rx + 1.0, cy - 11.0, cx + dome_rx - 1.0, cy - 11.0, "mauve")
    bell.line(cx - dome_rx - 2.0, cy + 2.5, cx + dome_rx + 2.0, cy + 2.5, "mauve")

    # Signature jagged hairline cracks across the obsidian bell!
    crack_glow = "cream" if ctx.is_stagger else ("coral" if p2 else ("cream" if ctx.is_tell else "ice"))
    if d == "front":
        bell.crack(cx - 2.0, cy - 17.0, cx + 5.0, cy + 4.0, "void", crack_glow, seed=71)
        bell.crack(cx - 9.0, cy - 5.0, cx - 2.0, cy + 6.0, "void", "gold" if ctx.is_stagger else "sky", seed=73)
        # Hollow gothic blindfold/eye slits etched into bronze brow
        eye_c = "cream" if (ctx.is_tell or ctx.is_stagger) else ("coral" if p2 else "ice")
        bell.line(cx - 7.0, cy - 8.5, cx - 3.0, cy - 7.5, eye_c, protect=True)
        bell.line(cx + 3.0, cy - 7.5, cx + 7.0, cy - 8.5, eye_c, protect=True)
    elif d == "side":
        bell.crack(cx + 2.0, cy - 16.0, cx + 8.0, cy + 5.0, "void", crack_glow, seed=79)
        eye_c = "cream" if (ctx.is_tell or ctx.is_stagger) else ("coral" if p2 else "ice")
        bell.line(cx + 4.0, cy - 8.0, cx + 8.5, cy - 7.5, eye_c, protect=True)
    else:
        bell.crack(cx, cy - 17.0, cx - 3.0, cy + 6.0, "void", crack_glow, seed=83)
        for rx_o in (-6, 0, 6):
            bell.rect(cx + rx_o - 1, cy - 4, 2, 4, "dusk")
            bell.set(cx + rx_o, cy - 3, "ice" if not ctx.is_stagger else "gold", protect=True)

    body.composite(rotate_buf(bell, cx, cy - 4.0, tilt))

    # P2 levitating fractured obsidian rim shards orbiting silently
    if p2:
        for k in range(3):
            a = ph + k * (math.tau / 3.0)
            _draw_orbit_shard(fx_front if math.sin(a) >= 0 else fx_back, cx + math.cos(a) * 24.0, cy + math.sin(a) * 11.0, True)

    if ctx.is_tell and u > 0.30:
        # Pure visual stark hairline flash + expanding dust cross (read by eye!)
        fx_front.star4(cx, cy - 8.0, 3 if u > 0.72 else 2, "cream", "ice")
        fx_front.ring(cx, cy, 20.0 + u * 6.0, "ice", 1.2, 20, 320, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        # Stark silent ice-white shockwave arc with clear readable gap!
        fx_front.slash_arc(cx, cy + 2.0, 27, 17, -140, 140, 5.2, ("mauve", "ice", "cream"))
    elif ctx.is_stagger:
        # Forced to ring! Golden-white rays bursting silently out of the cracked bronze
        fx_front.ring(cx, cy - 2.0, 21.0 + math.sin(ph * 2.0) * 2.0, "gold", 1.5, 0, 360, protect=True)
        fx_front.dizzy_stars(cx, cy - 26.0, 11.5, 3.6, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=True, outline_col="void", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="silent_bell", name="The Silent Bell", out_dir=ART_BOSSES,
    frame=(84, 84), anchor=(42, 66),
    body_radius=13.0, hit_radius=17.0, body_centre=(42, 42),
    anims=list(BOSS_ANIMS), cool_rim=True, biome_bg="void",
    draw_frame=draw_silent_bell,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
