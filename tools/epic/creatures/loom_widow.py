#!/usr/bin/env python3
"""Island 3 Boss B: The Loom Widow (gothic orb-weaver queen) — 88x80, anchor [44, 60]."""
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

VELVET = ("void", "night", "dusk", "plum")
LEG_ROSE = ("night", "plum", "wine", "rose")
FILIGREE = ("wine", "apricot", "gold", "cream")
FROST_WEB = ("deep", "blue", "sky", "ice")


def _draw_spider_leg(buf: PixelBuf, p0: tuple[float, float], knee: tuple[float, float], foot: tuple[float, float], hot: bool) -> None:
    ramp = ("plum", "wine", "coral", "rose") if hot else LEG_ROSE
    buf.bezier_limb(p0, knee, foot, 2.3, 0.9, ramp, tip_col="gold" if hot else "cream")
    buf.circle(knee[0], knee[1], 1.7, "gold" if not hot else "cream", protect=True)


def draw_loom_widow(ctx: FrameCtx) -> Image.Image:
    w, h = 88, 80
    ax, ay = 44.0, 60.0
    body = PixelBuf(w, h)
    fx_back = PixelBuf(w, h)
    fx_front = PixelBuf(w, h)
    shadow = PixelBuf(w, h)

    d = ctx.direction
    u, ph, lph = ctx.u, ctx.phase, ctx.lag_phase
    p2 = ctx.is_phase2

    hover = math.sin(ph) * 2.0 if ctx.anim in ("routine", "phase2") else 0.0
    rear = 0.0
    lunge = 0.0
    slump = 0.0
    sx, sy = 1.0, 1.0

    if ctx.is_tell:
        rear = 6.0 * u
        sx, sy = 0.95, 1.06
    elif ctx.is_commit:
        sm = math.sin(min(1.0, u * 1.6) * math.pi)
        lunge = 7.5 * sm
        rear = -3.0 * sm
        sx, sy = 1.08, 0.93
    elif ctx.is_recover:
        slump = 6.0 + math.sin(ph) * 0.8
    elif ctx.is_stagger:
        slump = 8.0
        hover = math.sin(ph * 2.0) * 1.8

    cx = ax + (lunge * 0.7 if d == "side" else 0.0)
    cy = ay - 14.0 + hover - rear + slump
    shadow.contact_shadow(ax, ay + 2.0, 22.0, 2.8, "night")

    # Subtle suspended golden silk anchor thread from above
    if not ctx.is_stagger:
        fx_back.line(cx, 5.0, cx, cy - 18.0, "ice" if p2 else "gold", protect=True)

    hot = p2 or ctx.is_commit
    # 6 long aristocratic arachnid legs
    if d == "side":
        leg_cfg = [
            ((-8.0, -2.0), (-22.0, -14.0), (-26.0, 11.0), 0.0),
            ((-1.0, 0.0), (-11.0, -15.0), (-12.0, 13.0), 1.8),
            ((6.0, 1.0), (16.0, -16.0 - rear * 1.1), (22.0 + lunge * 0.5, 10.0 - rear * 1.6), 3.4),
        ]
        for (ox, oy), (kx, ky), (fx_p, fy_p), off_p in leg_cfg:
            wob = math.sin(ph + off_p) * 2.5 if ctx.anim in ("routine", "phase2") else 0.0
            _draw_spider_leg(body, (cx + ox, cy + oy), (cx + kx, cy + ky + wob * 0.5), (cx + fx_p + wob, min(ay + 1.0, cy + fy_p)), hot)
        # Back-side silhouette legs
        _draw_spider_leg(body, (cx - 4.0, cy - 1.0), (cx - 17.0, cy - 10.0), (cx - 19.0, ay), False)
        _draw_spider_leg(body, (cx + 4.0, cy - 1.0), (cx + 12.0, cy - 11.0), (cx + 14.0, ay - 1.0), False)
    else:
        for sgn in (-1.0, 1.0):
            for idx, (ox, kx, ky, fx_p, fy_p) in enumerate([
                (8.0, 22.0, -16.0, 28.0, 8.0),
                (9.0, 26.0, -8.0, 31.0, 13.0),
                (6.0, 18.0, -12.0 - rear * 1.2, 20.0, 14.0 - rear * 1.5),
            ]):
                wob = math.sin(ph + idx * 1.3 + (0.0 if sgn > 0 else 1.5)) * 2.4 if ctx.anim in ("routine", "phase2") else 0.0
                _draw_spider_leg(
                    body,
                    (cx + sgn * ox, cy + 1.0),
                    (cx + sgn * kx, cy + ky + wob * 0.4),
                    (cx + sgn * fx_p, min(ay + 1.0, cy + fy_p + wob)),
                    hot and idx == 2,
                )

    # Grand gothic bulbous orb-weaver abdomen with golden loom-filigree
    ab_x = cx - (7.5 if d == "side" else 0.0)
    ab_y = cy - (11.0 if d != "side" else 8.5) + math.sin(lph) * 1.0
    ab_rx = 15.5 if d != "side" else 14.5
    ab_ry = 14.5 if d != "side" else 13.0
    body.shaded_ellipse(ab_x, ab_y, ab_rx, ab_ry, VELVET)

    # Golden filigree hourglass & rib cage ornament on abdomen
    body.ring(ab_x, ab_y, ab_rx * 0.68, "gold" if not p2 else "ice", 1.1, 200, 340, protect=True)
    body.line(ab_x, ab_y - ab_ry * 0.72, ab_x, ab_y + ab_ry * 0.62, "gold", protect=True)
    body.shaded_poly([
        (ab_x - 4.5, ab_y - 6.0), (ab_x + 4.5, ab_y - 6.0),
        (ab_x, ab_y + 1.0),
    ], FILIGREE)
    body.shaded_poly([
        (ab_x - 3.5, ab_y + 6.0), (ab_x + 3.5, ab_y + 6.0),
        (ab_x, ab_y + 0.5),
    ], FILIGREE)

    # Ornate golden spindle crown atop abdomen
    cr_y = ab_y - ab_ry + 1.0
    crown_pts = [
        (ab_x - 8.5, cr_y + 2.0), (ab_x - 6.5, cr_y - 6.0),
        (ab_x - 2.5, cr_y - 1.5), (ab_x, cr_y - 8.5),
        (ab_x + 2.5, cr_y - 1.5), (ab_x + 6.5, cr_y - 6.0),
        (ab_x + 8.5, cr_y + 2.0),
    ]
    body.shaded_poly(crown_pts, FILIGREE)
    body.circle(ab_x, cr_y - 8.0, 1.8, "cream" if not p2 else "ice", protect=True)

    # Cephalothorax head & 6 luminous ice eyes
    hx = cx + (8.0 if d == "side" else 0.0)
    hy = cy + (3.5 if d == "front" else (0.5 if d == "side" else 1.5))
    body.shaded_ellipse(hx, hy, 9.8 if d != "side" else 9.0, 7.6, VELVET)
    # Rose-plum royal collar ruff
    body.shaded_ellipse(hx - (2.0 if d == "side" else 0.0), hy - 3.5, 8.8, 3.2, LEG_ROSE)

    eye_col = "ice" if not ctx.is_commit else "cream"
    if d == "front":
        # 6 glowing icy eyes in an unmistakable gothic arachnid crown arc!
        for ex, ey, ew, eh in [
            (-5.5, -1.0, 2, 2), (-2.2, -3.0, 2, 2), (1.0, -3.0, 2, 2),
            (4.2, -1.0, 2, 2), (-3.5, 1.5, 2, 1), (2.2, 1.5, 2, 1),
        ]:
            body.eye(hx + ex, hy + ey, eye_col, "cream", "void", ew, eh)
        # Dual gilded spinneret fangs
        body.bezier_limb((hx - 4.0, hy + 4.5), (hx - 6.0, hy + 8.5), (hx - 2.5, hy + 10.5), 1.8, 0.7, FILIGREE)
        body.bezier_limb((hx + 4.0, hy + 4.5), (hx + 6.0, hy + 8.5), (hx + 2.5, hy + 10.5), 1.8, 0.7, FILIGREE)
    elif d == "side":
        for ex, ey, ew in [(2.0, -2.5, 2), (5.0, -1.2, 2), (3.5, 1.0, 2)]:
            body.eye(hx + ex, hy + ey, eye_col, "cream", "void", ew, 2)
        body.bezier_limb((hx + 4.0, hy + 3.5), (hx + 9.0, hy + 6.0), (hx + 7.5, hy + 9.5), 1.8, 0.7, FILIGREE)
    else:
        # Back view: glowing golden spinneret gland at tail base
        body.circle(ab_x, ab_y + 10.5, 3.4, "plum")
        body.circle(ab_x, ab_y + 10.5, 2.2, "gold" if not p2 else "ice", protect=True)
        body.set(ab_x, ab_y + 10.5, "cream", protect=True)

    if p2:
        body.crack(ab_x - 6.0, ab_y - 4.0, ab_x + 5.0, ab_y + 5.0, "void", "coral", seed=31)
        fx_back.ring(cx, cy - 4.0, 24.0, "sky", 1.1, 0, 360, protect=True)
        for k in range(6):
            a = ph + k * (math.tau / 6.0)
            fx_front.set(cx + math.cos(a) * 23.0, cy - 4.0 + math.sin(a) * 14.0, "ice" if k % 2 == 0 else "gold", protect=True)

    if ctx.is_tell and u > 0.32:
        fx_front.star4(hx + (6.0 if d == "side" else 0.0), hy - 5.0, 3 if u > 0.68 else 2, "cream", "ice")
        fx_front.ring(hx, hy, 12.0 + u * 6.0, "gold", 1.0, 0, 360, protect=True)
    elif ctx.is_commit and ctx.fi in (1, 2, 3):
        if d == "side":
            fx_front.slash_arc(hx + 4.0, hy + 2.0, 18.0, 14.0, -70, 70, 5.8, ("coral", "gold", "cream"))
        else:
            fx_front.slash_arc(hx, hy + 5.0, 24.0, 12.0, 10, 170, 5.8, ("coral", "gold", "cream"))
    elif ctx.is_stagger:
        fx_front.dizzy_stars(hx, hy - 14.0, 12.0, 3.8, ph)

    return finalize_frame(body, fx_front, fx_back, shadow, cool_rim=False, outline_col="night", sx=sx, sy=sy, anchor=(ax, ay))


SPEC = CreatureSpec(
    id="loom_widow", name="The Loom Widow", out_dir=ART_BOSSES,
    frame=(88, 80), anchor=(44, 60),
    body_radius=13.0, hit_radius=17.0, body_centre=(44, 42),
    anims=list(BOSS_ANIMS), cool_rim=False, biome_bg="night",
    draw_frame=draw_loom_widow,
)

if __name__ == "__main__":
    export_creature(SPEC, preview_dir=CACHE_DIR / "creatures_preview")
