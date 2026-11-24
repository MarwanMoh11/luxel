"""Handcrafted Last Light pixel-art drawing kit & LxSpriteSheet atlas packer for theme scenery."""
from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[4]
LASTLIGHT_DIR = REPO_ROOT / "docs" / "art_concepts" / "lastlight"
if str(LASTLIGHT_DIR) not in sys.path:
    sys.path.insert(0, str(LASTLIGHT_DIR))

from core import PAL, RGBA, SHADE, LIGHT, dither, outline, rim_light  # noqa: E402
from ..kit import verify_image_palette  # noqa: E402

TRANSPARENT = (0, 0, 0, 0)
PROPS_OUT_DIR = REPO_ROOT / "luxel" / "art" / "props"


class PCanvas:
    """Strict 20-colour Last Light sprite canvas (alpha 0 or 255 only)."""

    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.im = Image.new("RGBA", (w, h), TRANSPARENT)
        self.px = self.im.load()

    def set(self, x: int, y: int, col: str | None) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = TRANSPARENT if col is None else RGBA[col]

    def get_alpha(self, x: int, y: int) -> int:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y][3]
        return 0

    def rect(self, x: int, y: int, w: int, h: int, col: str | None) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, col)

    def hline(self, x0: int, x1: int, y: int, col: str | None) -> None:
        for xx in range(min(x0, x1), max(x0, x1) + 1):
            self.set(xx, y, col)

    def vline(self, x: int, y0: int, y1: int, col: str | None) -> None:
        for yy in range(min(y0, y1), max(y0, y1) + 1):
            self.set(x, yy, col)

    def box(self, x: int, y: int, w: int, h: int, col: str) -> None:
        if w <= 0 or h <= 0:
            return
        self.hline(x, x + w - 1, y, col)
        self.hline(x, x + w - 1, y + h - 1, col)
        self.vline(x, y, y + h - 1, col)
        self.vline(x + w - 1, y, y + h - 1, col)

    def bevel(self, x: int, y: int, w: int, h: int, mid: str, hi: str, lo: str) -> None:
        if w <= 0 or h <= 0:
            return
        self.rect(x, y, w, h, mid)
        self.hline(x, x + w - 1, y, hi)
        self.vline(x, y, y + h - 1, hi)
        self.hline(x, x + w - 1, y + h - 1, lo)
        self.vline(x + w - 1, y + 1, y + h - 1, lo)

    def dither_rect(self, x: int, y: int, w: int, h: int, c0: str, c1: str, mix: float = 0.5) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c1 if dither(xx, yy, mix) else c0)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, col: str) -> None:
        if rx <= 0 or ry <= 0:
            return
        for yy in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for xx in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                if ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.set(xx, yy, col)

    def shaded_ellipse(self, cx: float, cy: float, rx: float, ry: float, dk: str, mid: str, hi: str) -> None:
        for yy in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for xx in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                dx = (xx + 0.5 - cx) / max(0.5, rx)
                dy = (yy + 0.5 - cy) / max(0.5, ry)
                if dx * dx + dy * dy <= 1.0:
                    if dx + dy < -0.45:
                        self.set(xx, yy, hi)
                    elif dx + dy > 0.55:
                        self.set(xx, yy, dk)
                    else:
                        self.set(xx, yy, mid)

    def line(self, x0: int, y0: int, x1: int, y1: int, col: str) -> None:
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        x, y = x0, y0
        while True:
            self.set(x, y, col)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def finalize(self, target_w: int, target_h: int, do_outline: bool = True, do_rim: bool = True, align_bottom: int = 1) -> Image.Image:
        im = self.im
        if do_rim:
            im = rim_light(im, world_x=300.0, top=True)
        if do_outline:
            im = outline(im)
        out = Image.new("RGBA", (target_w, target_h), TRANSPARENT)
        ox = (target_w - im.width) // 2
        oy = target_h - im.height - align_bottom
        out.alpha_composite(im, (max(0, ox), max(0, oy)))
        return out


# ------------------------------------------------------------------ Reusable Architectural Primitives
def draw_flame(c: PCanvas, cx: int, cy: int, f: int, c_out: str = "coral", c_mid: str = "apricot", c_hi: str = "gold", c_core: str = "cream", tall: int = 5) -> None:
    """Animated 4-frame pixel flame."""
    sway = (-1, 0, 1, 0)[f % 4]
    h = tall + (0, 1, 0, -1)[f % 4]
    c.ellipse(cx, cy, 2.3, 1.8, c_out)
    c.ellipse(cx + sway * 0.4, cy - 1.2, 1.6, max(1.4, h * 0.45), c_mid)
    c.set(cx + sway, cy - h + 1, c_hi)
    c.set(cx, cy - 1, c_hi)
    c.set(cx, cy, c_core)
    if f % 2 == 0:
        c.set(cx + sway, cy - h, c_core if tall >= 5 else c_hi)


def draw_archway(
    w: int, h: int, dk: str, mid: str, hi: str, trim: str, accent: str | None = None, f: int = 0, hanging_lamp: bool = False
) -> Image.Image:
    c = PCanvas(w - 2, h - 2)
    cw, ch = c.w, c.h
    pw = max(6, cw // 5)
    # Left and right piers with masonry courses
    for px0 in (0, cw - pw):
        c.bevel(px0, 8, pw, ch - 8, mid, hi, dk)
        c.bevel(px0, ch - 4, pw, 4, dk, mid, "night")
        for y in range(12, ch - 4, 5):
            c.hline(px0 + 1, px0 + pw - 2, y, dk)
            c.set(px0 + 2, y + 1, hi)
    # Curved arch crown
    cx = cw // 2
    arch_r = (cw - 2 * pw) // 2 + 2
    for y in range(2, 14):
        for x in range(1, cw - 1):
            d = math.hypot(x - cx, (y - 12) * 1.15)
            if arch_r - 3 <= d <= arch_r + 4 and y <= 13:
                c.set(x, y, hi if y < 6 else (dk if d < arch_r else mid))
    # Cornice bar & keystone
    c.hline(2, cw - 3, 2, hi)
    c.hline(1, cw - 2, 3, trim)
    c.bevel(cx - 3, 0, 6, 7, trim, "cream" if trim in ("gold", "ice") else hi, dk)
    if accent:
        c.rect(cx - 1, 2, 2, 3, accent)
    if hanging_lamp:
        sway = (-1, 0, 1, 0)[f % 4]
        c.vline(cx, 7, 11, dk)
        c.rect(cx - 2 + sway, 11, 5, 5, trim)
        c.rect(cx - 1 + sway, 12, 3, 3, "cream" if (f % 2 == 0) else "gold")
    return c.finalize(w, h)


def draw_pillar(w: int, h: int, dk: str, mid: str, hi: str, trim: str, broken: bool = False, glow_band: str | None = None, f: int = 0) -> Image.Image:
    c = PCanvas(w - 2, h - 2)
    cw, ch = c.w, c.h
    sx = 2
    sw = cw - 4
    # Base plinth
    c.bevel(0, ch - 6, cw, 6, mid, hi, dk)
    c.hline(1, cw - 2, ch - 5, trim)
    # Fluted shaft
    top_y = 9 if broken else 5
    c.bevel(sx, top_y, sw, ch - 6 - top_y, mid, hi, dk)
    for x in range(sx + 2, sx + sw - 1, 3):
        c.vline(x, top_y + 1, ch - 7, dk)
        if x + 1 < sx + sw - 1:
            c.vline(x + 1, top_y + 1, ch - 7, hi)
    if broken:
        # Jagged sheared top
        for dx in range(sw):
            cut = int(abs(math.sin(dx * 0.9)) * 4)
            c.vline(sx + dx, top_y, top_y + cut, None)
            c.set(sx + dx, top_y + cut + 1, hi)
    else:
        # Capital
        c.bevel(0, 0, cw, 6, trim, hi, dk)
        c.hline(1, cw - 2, 1, "cream" if trim in ("gold", "ice", "stone") else hi)
    if glow_band:
        gy = ch // 2
        gc = "cream" if (f % 2 == 0) else glow_band
        c.hline(sx + 1, sx + sw - 2, gy, glow_band)
        c.set(cw // 2, gy, gc)
    return c.finalize(w, h)


def draw_lantern_post(
    w: int, h: int, post_dk: str, post_mid: str, post_hi: str, glow_mid: str, glow_hi: str, f: int = 0, tall_hook: bool = True
) -> Image.Image:
    c = PCanvas(w - 2, h - 2)
    cw, ch = c.w, c.h
    px = cw // 2 - 2 if tall_hook else cw // 2
    # Foot base
    c.bevel(px - 3, ch - 5, 7, 5, post_mid, post_hi, post_dk)
    # Pole
    c.vline(px - 1, 4, ch - 5, post_hi)
    c.vline(px, 4, ch - 5, post_mid)
    c.vline(px + 1, 5, ch - 5, post_dk)
    if tall_hook:
        c.hline(px - 1, px + 5, 3, post_hi)
        c.hline(px, px + 5, 4, post_dk)
        lx = px + 5
        ly = 6 + (0, 0, 1, 0)[f % 4]
        c.vline(lx, 4, ly, post_dk)
    else:
        lx = px
        ly = 4
    # Lantern cage
    c.bevel(lx - 3, ly, 7, 8, post_mid, post_hi, post_dk)
    c.rect(lx - 2, ly + 1, 5, 6, glow_mid)
    c.rect(lx - 1, ly + 2, 3, 4, glow_hi)
    if f in (0, 2):
        c.set(lx, ly + 3, "cream")
    else:
        c.set(lx + (1 if f == 1 else -1), ly + 3, "cream")
    # Cap finial
    c.hline(lx - 2, lx + 2, ly - 1, post_hi)
    c.set(lx, ly - 2, glow_hi)
    return c.finalize(w, h)


def draw_brazier(
    w: int, h: int, bowl_dk: str, bowl_mid: str, bowl_hi: str, f: int = 0, c_out: str = "coral", c_mid: str = "apricot", c_hi: str = "gold"
) -> Image.Image:
    c = PCanvas(w - 2, h - 2)
    cw, ch = c.w, c.h
    cx = cw // 2
    # Tripod legs
    c.line(cx - 4, ch - 1, cx - 2, ch - 9, bowl_dk)
    c.line(cx + 4, ch - 1, cx + 2, ch - 9, bowl_dk)
    c.vline(cx, ch - 8, ch - 2, bowl_mid)
    # Bowl basin
    c.shaded_ellipse(cx, ch - 10, 6.0, 3.2, bowl_dk, bowl_mid, bowl_hi)
    c.hline(cx - 5, cx + 5, ch - 12, bowl_hi)
    c.rect(cx - 4, ch - 11, 9, 2, c_out)
    draw_flame(c, cx, ch - 13, f, c_out=c_out, c_mid=c_mid, c_hi=c_hi, tall=6)
    return c.finalize(w, h)


def draw_banner(w: int, h: int, pole_c: str, cloth_dk: str, cloth_mid: str, cloth_hi: str, emblem: str, f: int = 0) -> Image.Image:
    c = PCanvas(w - 2, h - 2)
    cw, ch = c.w, c.h
    cx = cw // 2
    # Pole & crossbar
    c.bevel(cx - 2, ch - 4, 5, 4, pole_c, "stone", "night")
    c.vline(cx, 2, ch - 4, pole_c)
    c.hline(2, cw - 3, 3, "gold")
    c.set(2, 3, "cream")
    c.set(cw - 3, 3, "cream")
    # Rippling cloth body
    sway = (0, 1, 0, -1)[f % 4]
    for y in range(4, ch - 6):
        dx = sway if y > ch // 2 else 0
        x0 = max(2, 3 + dx)
        x1 = min(cw - 3, cw - 4 + dx)
        for x in range(x0, x1 + 1):
            if y >= ch - 9 and abs(x - (cx + dx)) <= (y - (ch - 10)):
                continue  # swallowtail notch
            col = cloth_hi if x == x0 else (cloth_dk if x == x1 else cloth_mid)
            c.set(x, y, col)
    # Center emblem diamond
    ey = 10
    c.rect(cx - 1, ey - 1, 3, 3, emblem)
    c.set(cx, ey - 2, emblem)
    c.set(cx, ey + 2, emblem)
    c.set(cx, ey, "cream")
    return c.finalize(w, h)


def draw_gear(w: int, h: int, dk: str, mid: str, hi: str, f: int = 0) -> Image.Image:
    c = PCanvas(w - 2, h - 2)
    cx, cy = c.w / 2.0, c.h / 2.0
    r_out = min(c.w, c.h) * 0.44
    r_in = r_out * 0.68
    r_hub = r_out * 0.28
    rot = (f % 4) * (math.pi / 16.0)
    for y in range(c.h):
        for x in range(c.w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            ang = math.atan2(dy, dx) + rot
            tooth = math.sin(ang * 8.0) > 0.10
            on_rim = (r_in <= r <= r_out) or (r_out < r <= r_out + 2.6 and tooth)
            on_spoke = r < r_in and (abs(math.sin(ang * 2.0)) < 0.20)
            on_hub = r <= r_hub
            if on_rim or on_spoke or on_hub:
                col = hi if (dx + dy < -r_out * 0.25) else (dk if (dx + dy > r_out * 0.35) else mid)
                c.set(x, y, col)
            if r < r_hub * 0.45:
                c.set(x, y, "night")
    return c.finalize(w, h)


def draw_urn(w: int, h: int, dk: str, mid: str, hi: str, trim: str, plant_c: str | None = None, f: int = 0) -> Image.Image:
    c = PCanvas(w - 2, h - 2)
    cw, ch = c.w, c.h
    cx = cw // 2
    # Foot
    c.bevel(cx - 3, ch - 4, 7, 4, dk, mid, "night")
    # Belly
    c.shaded_ellipse(cx, ch - 9, 5.2, 5.0, dk, mid, hi)
    c.hline(cx - 4, cx + 4, ch - 9, trim)
    # Neck & rim
    c.bevel(cx - 3, ch - 15, 7, 3, mid, hi, dk)
    c.hline(cx - 4, cx + 4, ch - 16, hi)
    if plant_c:
        sway = (-1, 0, 1, 0)[f % 4]
        c.ellipse(cx + sway, ch - 19, 3.6, 2.8, plant_c)
        c.set(cx - 1 + sway, ch - 21, LIGHT[plant_c])
        c.set(cx + 1 + sway, ch - 19, "rose" if plant_c == "jade" else "cream")
    return c.finalize(w, h)


def draw_mirror(w: int, h: int, frame_dk: str, frame_mid: str, frame_hi: str, glass_dk: str, glass_mid: str, glass_hi: str, f: int = 0) -> Image.Image:
    c = PCanvas(w - 2, h - 2)
    cw, ch = c.w, c.h
    cx = cw // 2
    # Stand base
    c.bevel(2, ch - 4, cw - 4, 4, frame_mid, frame_hi, frame_dk)
    # Ornate arched frame
    c.bevel(3, 3, cw - 6, ch - 7, frame_mid, frame_hi, frame_dk)
    c.rect(5, 5, cw - 10, ch - 11, glass_mid)
    # Animated diagonal shimmer sweep across mirror glass
    sweep = (f % 4) * 4
    for y in range(5, ch - 6):
        for x in range(5, cw - 5):
            if (x + y - sweep) % 14 in (0, 1):
                c.set(x, y, glass_hi)
            elif (x + y - sweep) % 14 == 2:
                c.set(x, y, "cream")
            elif y > ch - 10:
                c.set(x, y, glass_dk)
    # Crown crest
    c.rect(cx - 2, 1, 5, 3, frame_hi)
    c.set(cx, 0, "cream")
    return c.finalize(w, h)


def draw_floor_medallion(w: int, h: int, dk: str, mid: str, hi: str, core_c: str, f: int = 0) -> Image.Image:
    c = PCanvas(w, h)
    cx, cy = w / 2.0, h / 2.0
    rx, ry = w * 0.45, h * 0.45
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = math.hypot(dx, dy)
            if 0.86 <= d <= 1.0:
                c.set(x, y, hi if (dx + dy < 0) else mid)
            elif 0.55 <= d <= 0.65:
                c.set(x, y, mid if ((x + y + f) % 2 == 0) else dk)
            elif d < 0.86 and (abs(dx) < 0.11 or abs(dy) < 0.11):
                c.set(x, y, hi if (f % 2 == 0 or d < 0.45) else mid)
            elif d < 0.22:
                c.set(x, y, core_c if (f % 2 == 0) else hi)
    return c.im


@dataclass
class PropDef:
    key: str
    frames: list[Image.Image]
    anchor: tuple[int, int]
    ms: list[float]
    layer: str = "sort"  # ground | sort | overhead
    role: str = "landmark"
    placement: str = "near walls or room corners"


def static_prop(key: str, im: Image.Image, anchor: tuple[int, int] | None = None, layer: str = "sort", role: str = "decor", placement: str = "along walls") -> PropDef:
    anc = anchor or (im.width // 2, im.height - 2 if layer == "sort" else im.height // 2)
    return PropDef(key=key, frames=[im], anchor=anc, ms=[1000.0], layer=layer, role=role, placement=placement)


def anim_prop(
    key: str,
    draw_fn: Callable[[int], Image.Image],
    n_frames: int = 4,
    frame_ms: float = 280.0,
    anchor: tuple[int, int] | None = None,
    layer: str = "sort",
    role: str = "ambient",
    placement: str = "focal corners or paths",
) -> PropDef:
    frames = [draw_fn(i) for i in range(n_frames)]
    w, h = frames[0].size
    anc = anchor or (w // 2, h - 2 if layer == "sort" else h // 2)
    return PropDef(key=key, frames=frames, anchor=anc, ms=[frame_ms] * n_frames, layer=layer, role=role, placement=placement)


def pack_atlas(sheet_id: str, title: str, props: list[PropDef], out_dir: Path = PROPS_OUT_DIR) -> dict:
    """Pack PropDefs into `<sheet_id>.png` + `<sheet_id>.json` in exact LxSpriteSheet format."""
    sheet_w = max(p.frames[0].width * len(p.frames) for p in props)
    sheet_h = sum(p.frames[0].height for p in props)
    atlas = Image.new("RGBA", (sheet_w, sheet_h), TRANSPARENT)

    props_meta: dict[str, dict] = {}
    y_cur = 0
    for p in props:
        fw, fh = p.frames[0].size
        rects: list[list[int]] = []
        for idx, fim in enumerate(p.frames):
            assert fim.size == (fw, fh), f"{sheet_id}.{p.key} frame {idx} mismatch {fim.size} vs {(fw, fh)}"
            x_cur = idx * fw
            atlas.alpha_composite(fim, (x_cur, y_cur))
            rects.append([x_cur, y_cur, fw, fh])
        props_meta[p.key] = {
            "frame": [fw, fh],
            "anchor": [p.anchor[0], p.anchor[1]],
            "frames": len(p.frames),
            "ms": list(p.ms),
            "loop": True,
            "rects": rects,
        }
        y_cur += fh

    verify_image_palette(atlas, f"atlas:{sheet_id}")
    out_dir.mkdir(parents=True, exist_ok=True)
    png_name = f"{sheet_id}.png"
    json_name = f"{sheet_id}.json"
    atlas.save(out_dir / png_name, format="PNG")

    meta = {
        "id": sheet_id,
        "name": title,
        "version": 1,
        "palette": PAL,
        "sheet": png_name,
        "sheet_size": [sheet_w, sheet_h],
        "props": props_meta,
    }
    (out_dir / json_name).write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    return meta
