#!/usr/bin/env python3
"""Luxel Visual Contact-Sheet Renderer (Pillow).

Runs via:
  uv run --no-project --with pillow python tools/design_critic/contact_sheet.py <island_id> <out.png>
  uv run --no-project --with pillow python tools/design_critic/contact_sheet.py --room <map> <json> <out.png>
"""

from __future__ import annotations

import argparse
import math
import os
import sys
from typing import Any, Dict, List, Optional, Sequence, Tuple

from PIL import Image, ImageDraw, ImageFont

# Allow sibling import of design_critic.py
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import design_critic as dc  # noqa: E402

# Last Light inspired colour grid fallback
TILE_COLORS: Dict[str, Tuple[int, int, int]] = {
    "ground": (39, 53, 62),
    "path": (96, 84, 92),
    "wall": (24, 19, 44),
    "water": (32, 62, 118),
    "pit": (13, 11, 30),
    "void": (10, 8, 22),
    "bramble": (42, 86, 68),
    "cracked": (118, 78, 96),
    "tide": (43, 107, 104),
    "phantom": (106, 61, 111),
    "bridge": (138, 102, 72),
    "glass": (120, 169, 218),
    "mirror": (140, 200, 235),
}

ROLE_COLORS: Dict[str, Tuple[int, int, int]] = {
    "Boss": (255, 40, 72),
    "Pressure": (255, 76, 76),
    "Shield/Tank": (255, 153, 51),
    "Disrupter": (184, 85, 255),
    "Trickster": (255, 102, 204),
}

OUTLINE_DARK = (13, 11, 30, 255)
BG_SHEET = (15, 13, 28, 255)
BG_HEADER = (24, 20, 44, 255)
BORDER_CARD = (62, 52, 92, 255)
BORDER_WARN = (226, 114, 91, 255)
TEXT_MAIN = (248, 240, 224, 255)
TEXT_MUTED = (182, 170, 196, 255)
TEXT_CYAN = (104, 236, 255, 255)
TEXT_GOLD = (255, 217, 140, 255)
TEXT_RED = (255, 104, 96, 255)
TEXT_GREEN = (136, 224, 148, 255)


def _load_font(size: int = 11) -> ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.ttf",
        "/System/Library/Fonts/Supplemental/Courier New.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def _ground_png_path(region: Dict[str, Any]) -> str:
    return os.path.join(
        dc.repo_root(),
        "luxel",
        "art",
        "islands",
        str(region["island_id"]),
        f"{region['id']}_ground.png",
    )


def _render_fallback_grid(region: Dict[str, Any]) -> Image.Image:
    ts = region["tile_size"]
    w = region["width"]
    h = region["height"]
    img = Image.new("RGBA", (max(1, w * ts), max(1, h * ts)), (13, 11, 30, 255))
    draw = ImageDraw.Draw(img)
    grid = region["grid"]
    for y in range(h):
        for x in range(w):
            col = TILE_COLORS.get(grid[y][x], (24, 19, 44))
            draw.rectangle([x * ts, y * ts, (x + 1) * ts - 1, (y + 1) * ts - 1], fill=col + (255,))
    return img


def _draw_dashed_line(
    draw: ImageDraw.ImageDraw,
    p0: Tuple[float, float],
    p1: Tuple[float, float],
    color: Tuple[int, int, int, int],
    width: int = 2,
    dash: float = 6.0,
    gap: float = 4.0,
) -> None:
    dx = p1[0] - p0[0]
    dy = p1[1] - p0[1]
    dist = math.hypot(dx, dy)
    if dist < 1.0:
        return
    ux, uy = dx / dist, dy / dist
    cur = 0.0
    while cur < dist:
        nxt = min(dist, cur + dash)
        draw.line(
            [
                (p0[0] + ux * cur, p0[1] + uy * cur),
                (p0[0] + ux * nxt, p0[1] + uy * nxt),
            ],
            fill=color,
            width=width,
        )
        cur += dash + gap


def _draw_star(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    r_outer: float,
    r_inner: float,
    fill: Tuple[int, int, int, int],
    outline: Tuple[int, int, int, int],
) -> None:
    pts: List[Tuple[float, float]] = []
    for i in range(10):
        ang = -math.pi / 2.0 + i * (math.pi / 5.0)
        r = r_outer if i % 2 == 0 else r_inner
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    draw.polygon(pts, fill=fill, outline=outline)


def _draw_diamond(
    draw: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    r: float,
    fill: Tuple[int, int, int, int],
    outline: Tuple[int, int, int, int],
) -> None:
    pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
    draw.polygon(pts, fill=fill, outline=outline)


def _draw_arrow(
    draw: ImageDraw.ImageDraw,
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    color: Tuple[int, int, int, int],
    width: int = 2,
    head_len: float = 5.0,
) -> None:
    draw.line([(x0, y0), (x1, y1)], fill=color, width=width)
    ang = math.atan2(y1 - y0, x1 - x0)
    a1 = ang + math.radians(150.0)
    a2 = ang - math.radians(150.0)
    p1 = (x1 + math.cos(a1) * head_len, y1 + math.sin(a1) * head_len)
    p2 = (x1 + math.cos(a2) * head_len, y1 + math.sin(a2) * head_len)
    draw.polygon([(x1, y1), p1, p2], fill=color)


def render_room_card(
    region: Dict[str, Any],
    report: Dict[str, Any],
    target_width: int,
    font_title: ImageFont.ImageFont,
    font_small: ImageFont.ImageFont,
) -> Image.Image:
    png_path = _ground_png_path(region)
    if os.path.exists(png_path):
        base = Image.open(png_path).convert("RGBA")
    else:
        base = _render_fallback_grid(region)

    px_w = max(1, region["pixel_width"])
    px_h = max(1, region["pixel_height"])
    if base.size != (px_w, px_h):
        base = base.resize((px_w, px_h), Image.Resampling.NEAREST)

    scale = target_width / float(px_w)
    # Keep pixel art crisp when scaling up; use smooth scaling if shrinking large overworlds
    out_w = max(64, int(round(px_w * scale)))
    out_h = max(48, int(round(px_h * scale)))
    resample = Image.Resampling.NEAREST if scale >= 1.0 else Image.Resampling.BILINEAR
    canvas = base.resize((out_w, out_h), resample)

    overlay = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)

    ts = region["tile_size"]
    grid = region["grid"]
    w_tiles, h_tiles = region["width"], region["height"]

    # Highlight phantom and tide tiles subtly so puzzle geometry is unmistakable
    for ty in range(h_tiles):
        for tx in range(w_tiles):
            tt = grid[ty][tx]
            if tt == "phantom":
                x0, y0 = tx * ts * scale, ty * ts * scale
                x1, y1 = (tx + 1) * ts * scale - 1, (ty + 1) * ts * scale - 1
                odraw.rectangle([x0, y0, x1, y1], fill=(180, 96, 224, 75), outline=(224, 152, 255, 160))
            elif tt == "tide":
                x0, y0 = tx * ts * scale, ty * ts * scale
                x1, y1 = (tx + 1) * ts * scale - 1, (ty + 1) * ts * scale - 1
                odraw.rectangle([x0, y0, x1, y1], fill=(48, 210, 196, 65), outline=(96, 240, 220, 145))

    # Draw triggers (highlight stale triggers in red)
    stale_ids = {iss["id"] for iss in report["wiring"]["issues"] if iss["flag"] == "STALE_TRIGGER"}
    for trig in region["triggers"]:
        r = trig.get("rect", [])
        if isinstance(r, list) and len(r) >= 4:
            tid = str(trig.get("id", ""))
            x0, y0 = float(r[0]) * scale, float(r[1]) * scale
            x1, y1 = (float(r[0]) + float(r[2])) * scale, (float(r[1]) + float(r[3])) * scale
            if tid in stale_ids:
                odraw.rectangle([x0, y0, x1, y1], fill=(255, 64, 64, 55), outline=(255, 80, 80, 220), width=2)
            else:
                odraw.rectangle([x0, y0, x1, y1], outline=(194, 167, 174, 95), width=1)

    inters = region["interactables"]
    by_id = {str(it.get("id", "")): it for it in inters if str(it.get("id", ""))}

    def spt(pos: Tuple[float, float]) -> Tuple[float, float]:
        return (pos[0] * scale, pos[1] * scale)

    # First pass: doors, bridge_platforms, tide_gates, and signal / portal connector lines
    for it in inters:
        k = str(it.get("kind", "")).strip().lower()
        px, py = dc.interactable_pos(it)
        if k in dc.DOOR_KINDS:
            dtype = dc.get_door_type(it)
            sw, sh = dc.interactable_size(it, (32.0, 16.0))
            x0, y0 = (px - sw * 0.5) * scale, (py - sh * 0.5) * scale
            x1, y1 = (px + sw * 0.5) * scale, (py + sh * 0.5) * scale
            if dtype == "bridge_platform":
                odraw.rectangle([x0, y0, x1, y1], fill=(245, 169, 106, 70), outline=(255, 217, 140, 215), width=2)
            else:
                odraw.rectangle([x0, y0, x1, y1], fill=(106, 61, 111, 75), outline=(200, 170, 210, 195), width=1)
        elif k in dc.TIDE_KINDS:
            sw, sh = dc.interactable_size(it, (32.0, 32.0))
            x0, y0 = (px - sw * 0.5) * scale, (py - sh * 0.5) * scale
            x1, y1 = (px + sw * 0.5) * scale, (py + sh * 0.5) * scale
            odraw.rectangle([x0, y0, x1, y1], fill=(43, 170, 160, 75), outline=(120, 245, 225, 225), width=2)

    # Portal connector lines (avoid duplicates by sorting IDs)
    drawn_portal_pairs = set()
    for it in inters:
        k = str(it.get("kind", "")).strip().lower()
        if k not in dc.PORTAL_KINDS:
            continue
        pid = str(it.get("id", ""))
        tpid = str((it.get("props", {}) or {}).get("target_portal_id", "")).strip()
        if tpid and tpid in by_id:
            pair_key = (min(pid, tpid), max(pid, tpid))
            if pair_key not in drawn_portal_pairs:
                drawn_portal_pairs.add(pair_key)
                p0 = spt(dc.interactable_pos(it))
                p1 = spt(dc.interactable_pos(by_id[tpid]))
                _draw_dashed_line(odraw, p0, p1, (0, 240, 255, 235), width=2, dash=7.0, gap=4.0)

    # Switch -> target signal lines
    for it in inters:
        k = str(it.get("kind", "")).strip().lower()
        if k not in dc.SWITCH_KINDS:
            continue
        props = it.get("props", {}) or {}
        req_blue = bool(props.get("requires_prism", False)) or bool(props.get("requires_blue", False))
        line_col = (80, 235, 255, 215) if req_blue else (255, 217, 110, 215)
        targets: List[str] = []
        if props.get("target_id"):
            targets.append(str(props["target_id"]).strip())
        if isinstance(props.get("target_ids"), list):
            for t in props["target_ids"]:
                if t and str(t).strip() not in targets:
                    targets.append(str(t).strip())
        p0 = spt(dc.interactable_pos(it))
        for tid in targets:
            if tid in by_id:
                p1 = spt(dc.interactable_pos(by_id[tid]))
                _draw_dashed_line(odraw, p0, p1, line_col, width=2, dash=5.0, gap=3.0)

    canvas = Image.alpha_composite(canvas, overlay)
    draw = ImageDraw.Draw(canvas)

    # Marker sizing relative to scale (kept crisp even on shrunken overworlds)
    m_sz = max(5.0, min(9.5, 6.5 * max(0.75, min(1.4, scale))))

    # Second pass: foreground entity markers
    for it in inters:
        k = str(it.get("kind", "")).strip().lower()
        props = it.get("props", {}) or {}
        cx, cy = spt(dc.interactable_pos(it))

        if k in dc.MIRROR_KINDS:
            is_tf = k in ("blue_transformer", "transformer")
            fill_c = (48, 232, 255, 255) if is_tf else (72, 152, 255, 255)
            r = m_sz
            draw.rectangle([cx - r, cy - r, cx + r, cy + r], fill=fill_c, outline=OUTLINE_DARK, width=2)
            # Compute normal vector
            angle_deg = float(props.get("angle_deg", 45.0))
            if "normal" in props and isinstance(props["normal"], list) and len(props["normal"]) >= 2:
                nx, ny = float(props["normal"][0]), float(props["normal"][1])
                ln = math.hypot(nx, ny)
                nx, ny = (nx / ln, ny / ln) if ln > 1e-4 else (0.707, 0.707)
            else:
                rad = math.radians(angle_deg)
                nx, ny = math.cos(rad), math.sin(rad)
            # Reflection surface bar (tangent)
            tx_v, ty_v = -ny * (r * 0.85), nx * (r * 0.85)
            draw.line([(cx - tx_v, cy - ty_v), (cx + tx_v, cy + ty_v)], fill=(255, 255, 255, 255), width=2)
            # Reflection normal arrow
            arrow_len = r * 1.9
            _draw_arrow(draw, cx, cy, cx + nx * arrow_len, cy + ny * arrow_len, (215, 250, 255, 255), width=2, head_len=5.0)

        elif k in dc.PORTAL_KINDS:
            r = m_sz * 1.05
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(16, 48, 92, 230), outline=(0, 240, 255, 255), width=2)
            ri = max(2.5, r * 0.45)
            draw.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=(199, 245, 255, 255))

        elif k in dc.SWITCH_KINDS:
            req_blue = bool(props.get("requires_prism", False)) or bool(props.get("requires_blue", False))
            fill_c = (72, 238, 255, 255) if req_blue else (255, 217, 92, 255)
            _draw_diamond(draw, cx, cy, m_sz * 1.05, fill=fill_c, outline=OUTLINE_DARK)
            # Red X if unwired
            if not props.get("target_id") and not props.get("target_ids"):
                draw.line([(cx - 4, cy - 4), (cx + 4, cy + 4)], fill=(255, 48, 48, 255), width=2)
                draw.line([(cx + 4, cy - 4), (cx - 4, cy + 4)], fill=(255, 48, 48, 255), width=2)

        elif k == "chest":
            r = m_sz * 0.82
            draw.rectangle([cx - r, cy - r * 0.78, cx + r, cy + r * 0.78], fill=(255, 230, 70, 255), outline=OUTLINE_DARK, width=2)
            draw.rectangle([cx - 1.5, cy - 1.5, cx + 1.5, cy + 1.5], fill=(120, 74, 24, 255))

        elif k in ("beacon", "great_lamp", "great_belfry_brazier"):
            r_out = m_sz * (1.35 if k != "beacon" else 1.15)
            _draw_star(draw, cx, cy, r_out, r_out * 0.46, fill=(255, 174, 52, 255), outline=OUTLINE_DARK)

        elif k in ("waystone", "shrine", "rest_shrine"):
            r = m_sz * 0.7
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(224, 244, 252, 255), outline=OUTLINE_DARK, width=2)

    # Enemies (red / orange / purple dots by role)
    for e in region["enemies"]:
        ep = e.get("pos", [0.0, 0.0])
        if not isinstance(ep, (list, tuple)) or len(ep) < 2:
            continue
        ex, ey = float(ep[0]) * scale, float(ep[1]) * scale
        role = dc.enemy_role(str(e.get("kind", "")))
        col = ROLE_COLORS.get(role, (255, 76, 76))
        r = m_sz * (1.15 if role == "Boss" else 0.78)
        draw.ellipse([ex - r, ey - r, ex + r, ey + r], fill=col + (255,), outline=OUTLINE_DARK, width=2)
        if role == "Boss":
            draw.ellipse([ex - r - 2, ey - r - 2, ex + r + 2, ey + r + 2], outline=(255, 217, 120, 255), width=1)

    # Spawn marker (small green crosshair)
    spx, spy = spt(region["spawn"])
    draw.ellipse([spx - 3, spy - 3, spx + 3, spy + 3], fill=(120, 240, 140, 255), outline=OUTLINE_DARK, width=1)

    # Compose compact header strip above the rendered map
    has_flags = bool(report["flags"])
    sym_v = report["symmetry"]["sym_max"]
    pz = report["puzzle"]
    lmin_txt = ""
    if pz.get("applicable"):
        if not pz["puzzle_solvable"]:
            lmin_txt = "  L_min=UNSOLV"
        else:
            ac_tag = "" if pz["anti_cheese"] else " [CHEESE]"
            lmin_txt = f"  L_min={pz['min_steps']}{ac_tag}"

    line1 = f"{region['id']} ({region['width']}x{region['height']})  sym={sym_v:.2f}{lmin_txt}"
    flag_badges = " ".join(report["unique_flags"]) if has_flags else "CLEAN"
    if len(flag_badges) > max(32, out_w // 7):
        flag_badges = flag_badges[: max(28, out_w // 7 - 3)] + "..."

    header_h = 34
    card_w = out_w + 4
    card_h = header_h + out_h + 4
    card = Image.new("RGBA", (card_w, card_h), BG_HEADER)
    cdraw = ImageDraw.Draw(card)

    # Border & header
    bcol = BORDER_WARN if has_flags else BORDER_CARD
    cdraw.rectangle([0, 0, card_w - 1, card_h - 1], fill=BG_HEADER, outline=bcol, width=2)
    cdraw.text((8, 4), line1, font=font_title, fill=TEXT_MAIN)
    badge_col = TEXT_RED if has_flags else TEXT_GREEN
    cdraw.text((8, 19), flag_badges, font=font_small, fill=badge_col)
    card.paste(canvas, (2, header_h + 2))
    return card


def _draw_legend_strip(width: int, font_small: ImageFont.ImageFont) -> Image.Image:
    h = 30
    strip = Image.new("RGBA", (width, h), (20, 17, 38, 255))
    d = ImageDraw.Draw(strip)
    d.line([(0, h - 1), (width, h - 1)], fill=BORDER_CARD, width=1)

    items = [
        ("square", (48, 232, 255, 255), "Blue Transformer"),
        ("square", (72, 152, 255, 255), "Mirror"),
        ("ring", (0, 240, 255, 255), "Blue Portal"),
        ("diamond", (255, 217, 92, 255), "Switch"),
        ("diamond", (72, 238, 255, 255), "Blue Switch"),
        ("square", (255, 230, 70, 255), "Chest"),
        ("star", (255, 174, 52, 255), "Beacon"),
        ("dot", (255, 76, 76, 255), "Pressure"),
        ("dot", (255, 153, 51, 255), "Shield/Tank"),
        ("dot", (184, 85, 255, 255), "Disrupter"),
        ("dot", (255, 102, 204, 255), "Trickster"),
        ("dot", (255, 40, 72, 255), "Boss"),
    ]
    x = 12
    cy = h // 2
    for shape, col, label in items:
        if x + 110 > width:
            break
        if shape == "square":
            d.rectangle([x, cy - 5, x + 10, cy + 5], fill=col, outline=OUTLINE_DARK)
        elif shape == "ring":
            d.ellipse([x, cy - 5, x + 10, cy + 5], fill=(16, 48, 92, 255), outline=col, width=2)
        elif shape == "diamond":
            _draw_diamond(d, x + 5, cy, 5.5, fill=col, outline=OUTLINE_DARK)
        elif shape == "star":
            _draw_star(d, x + 5, cy, 6.5, 3.0, fill=col, outline=OUTLINE_DARK)
        elif shape == "dot":
            d.ellipse([x + 1, cy - 4, x + 9, cy + 4], fill=col, outline=OUTLINE_DARK)
        d.text((x + 15, cy - 6), label, font=font_small, fill=TEXT_MUTED)
        x += 15 + len(label) * 6 + 16
    return strip


def render_island_sheet(island_id: int, out_path: str) -> None:
    entries = dc.list_island_regions(island_id)
    if not entries:
        raise SystemExit(f"No regions found for island {island_id}")

    isl_report = dc.audit_island(island_id)
    reports_by_id = {rr["id"]: rr for rr in isl_report["rooms"]}
    regions_list = [dc.parse_region(mp, jp) for _, mp, jp in entries]

    font_banner = _load_font(15)
    font_title = _load_font(11)
    font_small = _load_font(10)

    pad = 14
    cols = 3
    cell_w = 460
    sheet_w = cols * (cell_w + 4) + (cols + 1) * pad

    ow_regions = [r for r in regions_list if not r["is_dungeon"]]
    dun_regions = [r for r in regions_list if r["is_dungeon"]]

    ow_cards = [
        render_room_card(r, reports_by_id[r["id"]], sheet_w - 2 * pad - 4, font_title, font_small)
        for r in ow_regions
    ]
    dun_cards = [
        render_room_card(r, reports_by_id[r["id"]], cell_w, font_title, font_small)
        for r in dun_regions
    ]

    banner_h = 46
    legend = _draw_legend_strip(sheet_w, font_small)

    # Calculate total height
    total_h = banner_h + legend.height + pad
    for c in ow_cards:
        total_h += c.height + pad

    row_heights: List[int] = []
    for i in range(0, len(dun_cards), cols):
        row = dun_cards[i : i + cols]
        rh = max(c.height for c in row)
        row_heights.append(rh)
        total_h += rh + pad

    sheet = Image.new("RGBA", (sheet_w, total_h), BG_SHEET)
    sdraw = ImageDraw.Draw(sheet)

    # Top banner
    dg = isl_report["topology"]["dungeon_graph"]
    zg = isl_report["topology"]["overworld_zone_graph"]
    tube_tag = "  [LINEAR_TUBE]" if isl_report["topology"]["linear_tube"] else ""
    banner_txt = (
        f"LUXEL DESIGN CRITIC — ISLAND {island_id}  |  "
        f"{isl_report['region_count']} regions  |  "
        f"Flags: {isl_report['total_flags']} (sev {isl_report['total_severity']})  |  "
        f"Dungeon cycles: {dg['cycles']}  OW zone cycles: {zg['cycles']}{tube_tag}"
    )
    sdraw.rectangle([0, 0, sheet_w, banner_h], fill=(22, 18, 42, 255))
    sdraw.text((14, 14), banner_txt, font=font_banner, fill=TEXT_GOLD)
    sheet.paste(legend, (0, banner_h))

    y_cur = banner_h + legend.height + pad
    for c in ow_cards:
        sheet.paste(c, (pad, y_cur))
        y_cur += c.height + pad

    for r_idx, i in enumerate(range(0, len(dun_cards), cols)):
        row = dun_cards[i : i + cols]
        for c_idx, card in enumerate(row):
            x_pos = pad + c_idx * (cell_w + 4 + pad)
            sheet.paste(card, (x_pos, y_cur))
        y_cur += row_heights[r_idx] + pad

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    sheet.convert("RGB").save(out_path, "PNG")
    print(f"Saved Island {island_id} contact sheet ({sheet.width}x{sheet.height}) to {out_path}")


def render_single_room_sheet(map_path: str, json_path: str, out_path: str) -> None:
    region = dc.parse_region(map_path, json_path)
    report = dc.audit_region_dict(region)

    font_title = _load_font(12)
    font_small = _load_font(10)

    target_w = max(560, min(1100, region["pixel_width"] * (2 if region["pixel_width"] <= 520 else 1)))
    card = render_room_card(region, report, target_w, font_title, font_small)
    pad = 12
    sheet_w = card.width + 2 * pad
    legend = _draw_legend_strip(sheet_w, font_small)
    sheet_h = legend.height + card.height + 2 * pad

    sheet = Image.new("RGBA", (sheet_w, sheet_h), BG_SHEET)
    sheet.paste(legend, (0, 0))
    sheet.paste(card, (pad, legend.height + pad))

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    sheet.convert("RGB").save(out_path, "PNG")
    print(f"Saved room contact sheet ({sheet.width}x{sheet.height}) to {out_path}")


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Luxel Visual Contact-Sheet Generator")
    parser.add_argument("--room", nargs=3, metavar=("MAP", "JSON", "OUT_PNG"), help="Render a single room")
    parser.add_argument("island_id", nargs="?", type=int, help="Island ID (1..8)")
    parser.add_argument("out_png", nargs="?", help="Output PNG path")

    args = parser.parse_args(argv)
    if args.room:
        render_single_room_sheet(args.room[0], args.room[1], args.room[2])
        return 0
    if args.island_id is not None and args.out_png:
        if not (1 <= args.island_id <= 8):
            raise SystemExit("island_id must be 1..8")
        render_island_sheet(args.island_id, args.out_png)
        return 0

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
