#!/usr/bin/env python3
"""Luxel Epic VLM-grade region & dungeon contact-sheet renderer (uv + Pillow).

Usage:
  uv run --no-project --with pillow python tools/epic/render_region.py --region 2:lighthouse_r5 --out out.png [--scale 2] [--state tide=ebb] [--clean]
  uv run --no-project --with pillow python tools/epic/render_region.py --dungeon lighthouse --sheet --out sheet.png [--scale 1] [--clean]
  uv run --no-project --with pillow python tools/epic/render_region.py --island 2 --sheet --out isl2.png
"""
from __future__ import annotations

import argparse
from collections import deque
import json
import math
import os
from pathlib import Path
import sys
from typing import Any, Dict, List, Optional, Sequence, Set, Tuple

from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import room_lint as rl  # noqa: E402

REPO_ROOT = rl.REPO_ROOT

PAL: Dict[str, Tuple[int, int, int]] = {
    "void": (0x0D, 0x0B, 0x1E), "night": (0x21, 0x1A, 0x3B), "dusk": (0x3D, 0x2C, 0x5C),
    "plum": (0x6A, 0x3D, 0x6F), "wine": (0xA0, 0x46, 0x6A), "coral": (0xE2, 0x72, 0x5B),
    "apricot": (0xF5, 0xA9, 0x6A), "gold": (0xFF, 0xD9, 0x8C), "cream": (0xFF, 0xF4, 0xDC),
    "pine": (0x1D, 0x3D, 0x4C), "teal": (0x2B, 0x6B, 0x68), "jade": (0x4C, 0x9E, 0x78),
    "lime": (0xA3, 0xCF, 0x7D), "deep": (0x26, 0x38, 0x73), "blue": (0x3E, 0x6D, 0xB0),
    "sky": (0x78, 0xA9, 0xDA), "ice": (0xC7, 0xE5, 0xEF), "mauve": (0x8A, 0x6E, 0x91),
    "stone": (0xC2, 0xA7, 0xAE), "rose": (0xEC, 0x9F, 0xA8),
}

# Biome tile fallback colours (strictly from Last Light 20-colour palette)
BIOME_TILE_MAP: Dict[int, Dict[str, str]] = {
    1: {"ground": "teal", "path": "mauve", "wall": "dusk", "water": "blue", "pit": "void", "void": "void", "bridge": "apricot", "tide": "sky", "phantom": "plum", "glass": "ice", "mirror": "ice", "bramble": "pine", "cracked": "wine"},
    2: {"ground": "pine", "path": "wine", "wall": "deep", "water": "blue", "pit": "void", "void": "void", "bridge": "apricot", "tide": "sky", "phantom": "plum", "glass": "ice", "mirror": "ice", "bramble": "teal", "cracked": "mauve"},
    3: {"ground": "pine", "path": "dusk", "wall": "night", "water": "teal", "pit": "void", "void": "void", "bridge": "apricot", "tide": "sky", "phantom": "plum", "glass": "ice", "mirror": "ice", "bramble": "jade", "cracked": "plum"},
    4: {"ground": "teal", "path": "mauve", "wall": "pine", "water": "blue", "pit": "void", "void": "void", "bridge": "stone", "tide": "sky", "phantom": "plum", "glass": "ice", "mirror": "ice", "bramble": "jade", "cracked": "dusk"},
    5: {"ground": "deep", "path": "blue", "wall": "night", "water": "void", "pit": "void", "void": "void", "bridge": "mauve", "tide": "sky", "phantom": "plum", "glass": "ice", "mirror": "ice", "bramble": "teal", "cracked": "plum"},
    6: {"ground": "dusk", "path": "plum", "wall": "night", "water": "coral", "pit": "wine", "void": "void", "bridge": "stone", "tide": "apricot", "phantom": "plum", "glass": "ice", "mirror": "ice", "bramble": "wine", "cracked": "coral"},
    7: {"ground": "deep", "path": "blue", "wall": "night", "water": "void", "pit": "void", "void": "void", "bridge": "sky", "tide": "ice", "phantom": "plum", "glass": "ice", "mirror": "ice", "bramble": "teal", "cracked": "mauve"},
    8: {"ground": "night", "path": "plum", "wall": "void", "water": "void", "pit": "void", "void": "void", "bridge": "mauve", "tide": "dusk", "phantom": "plum", "glass": "ice", "mirror": "ice", "bramble": "wine", "cracked": "rose"},
}
DUNGEON_GROUND_OVERRIDE: Dict[int, Tuple[str, str]] = {
    1: ("dusk", "plum"), 2: ("deep", "wine"), 3: ("pine", "dusk"), 4: ("teal", "mauve"),
    5: ("deep", "blue"), 6: ("dusk", "plum"), 7: ("deep", "mauve"), 8: ("night", "plum"),
}

ENEMY_VARIANT_SHEET: Dict[str, str] = {
    "bell_warden": "bosses/bell_warden", "bellkeeper": "bosses/bellkeeper",
    "tide_captain": "bosses/tide_captain", "lighthouse_hermit": "bosses/lighthouse_hermit",
    "elder_sporecap": "bosses/elder_sporecap", "briar_matron": "bosses/briar_matron",
    "great_lily_hopper": "bosses/great_lily_hopper", "heron_abbess": "bosses/heron_abbess",
    "clockwork_warden": "bosses/clockwork_warden", "astronomer": "bosses/astronomer",
    "forge_warden": "bosses/forge_warden", "kilnmother": "bosses/kilnmother",
    "spire_warden": "bosses/spire_warden", "hollow_wick_boss": "bosses/hollow_wick_boss",
    "night_harbinger": "bosses/night_harbinger", "the_hush": "bosses/the_hush",
}

_SHEET_CACHE: Dict[str, Optional[Tuple[Dict[str, Any], Image.Image]]] = {}


def _load_font(size: int) -> ImageFont.ImageFont:
    for p in (
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.ttf",
        "/System/Library/Fonts/Supplemental/Courier New.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    ):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def _load_sheet(json_path: Path) -> Optional[Tuple[Dict[str, Any], Image.Image]]:
    key = str(json_path)
    if key in _SHEET_CACHE:
        return _SHEET_CACHE[key]
    if not json_path.exists():
        _SHEET_CACHE[key] = None
        return None
    try:
        meta = json.loads(json_path.read_text(encoding="utf-8"))
        png_path = json_path.parent / str(meta.get("sheet", ""))
        if not png_path.exists():
            _SHEET_CACHE[key] = None
            return None
        img = Image.open(png_path).convert("RGBA")
        _SHEET_CACHE[key] = (meta, img)
        return _SHEET_CACHE[key]
    except Exception:
        _SHEET_CACHE[key] = None
        return None


def _crop_prop(sheet_path: Path, prop_key: str, flip_x: bool = False) -> Optional[Tuple[Image.Image, Tuple[int, int]]]:
    loaded = _load_sheet(sheet_path)
    if not loaded:
        return None
    meta, sheet_img = loaded
    pinfo = (meta.get("props") or {}).get(prop_key)
    if not isinstance(pinfo, dict):
        return None
    rects = pinfo.get("rects") or []
    if not rects:
        return None
    x, y, w, h = [int(v) for v in rects[0][:4]]
    crop = sheet_img.crop((x, y, x + w, y + h))
    anc = pinfo.get("anchor") or meta.get("anchor") or [w // 2, h // 2]
    ax, ay = int(anc[0]), int(anc[1])
    if flip_x:
        crop = crop.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        ax = w - ax
    return crop, (ax, ay)


def _crop_enemy(kind: str) -> Optional[Tuple[Image.Image, Tuple[int, int]]]:
    k = kind.strip().lower()
    cands = [
        REPO_ROOT / "luxel" / "art" / "enemies" / f"{k}.json",
        REPO_ROOT / "luxel" / "art" / "bosses" / f"{k}.json",
    ]
    if k in ENEMY_VARIANT_SHEET:
        cands.insert(0, REPO_ROOT / "luxel" / "art" / f"{ENEMY_VARIANT_SHEET[k]}.json")
    for p in cands:
        loaded = _load_sheet(p)
        if not loaded:
            continue
        meta, sheet_img = loaded
        anims = meta.get("animations") or {}
        anim = anims.get("idle") or anims.get("routine") or (next(iter(anims.values())) if anims else None)
        if not isinstance(anim, dict):
            continue
        dirs = anim.get("dirs") or {}
        dinfo = dirs.get("front") or dirs.get("side") or (next(iter(dirs.values())) if dirs else None)
        if not isinstance(dinfo, dict):
            continue
        rects = dinfo.get("rects") or []
        if not rects:
            continue
        x, y, w, h = [int(v) for v in rects[0][:4]]
        crop = sheet_img.crop((x, y, x + w, y + h))
        anc = anim.get("anchor") or meta.get("anchor") or [w // 2, h // 2]
        return crop, (int(anc[0]), int(anc[1]))
    return None


def eval_layer_cond(when: str, state_vars: Dict[str, str]) -> bool:
    expr = when.strip()
    if not expr:
        return True
    for or_part in expr.split(" || "):
        ok = True
        for raw_atom in or_part.split(" && "):
            atom = raw_atom.strip()
            if not atom:
                continue
            if atom.startswith("!flag:"):
                if state_vars.get(atom[6:].strip(), "") in ("1", "true", "True"):
                    ok = False
                    break
            elif atom.startswith("flag:"):
                if state_vars.get(atom[5:].strip(), "") not in ("1", "true", "True"):
                    ok = False
                    break
            else:
                matched = False
                for op in ("==", "!=", ">=", "<=", ">", "<"):
                    if op in atom:
                        lhs, rhs = [s.strip() for s in atom.split(op, 1)]
                        cur = state_vars.get(lhs, "")
                        if op == "==":
                            matched = (cur == rhs)
                        elif op == "!=":
                            matched = (cur != rhs)
                        else:
                            try:
                                a, b = float(cur or 0), float(rhs)
                                matched = (a >= b if op == ">=" else a <= b if op == "<=" else a > b if op == ">" else a < b)
                            except ValueError:
                                matched = False
                        break
                if not matched:
                    ok = False
                    break
        if ok:
            return True
    return False


def _paint_tile_rect(draw: ImageDraw.ImageDraw, x: int, y: int, ts: int, tt: str, isl_id: int, is_dungeon: bool) -> None:
    bmap = dict(BIOME_TILE_MAP.get(isl_id, BIOME_TILE_MAP[1]))
    if is_dungeon and isl_id in DUNGEON_GROUND_OVERRIDE:
        bmap["ground"], bmap["path"] = DUNGEON_GROUND_OVERRIDE[isl_id]
    cname = bmap.get(tt, "void")
    rgb = PAL[cname]
    x0, y0, x1, y1 = x * ts, y * ts, (x + 1) * ts - 1, (y + 1) * ts - 1
    draw.rectangle([x0, y0, x1, y1], fill=rgb + (255,))
    # Crisp 1px mortar / detail so unpainted rooms still read clearly to a VLM
    if tt == "wall":
        draw.line([(x0, y0), (x1, y0)], fill=PAL["mauve"] + (255,))
        draw.rectangle([x0, y1 - 3, x1, y1], fill=PAL["void"] + (255,))
    elif tt in ("ground", "path"):
        if (x + y) % 2 == 0:
            draw.point((x0 + 2, y0 + 2), fill=PAL["stone" if tt == "path" else "night"] + (255,))
    elif tt == "water":
        draw.line([(x0 + 2, y0 + 4), (x0 + 9, y0 + 4)], fill=PAL["sky"] + (255,))
        draw.line([(x0 + 6, y0 + 11), (x0 + 13, y0 + 11)], fill=PAL["deep"] + (255,))
    elif tt == "bridge":
        for bx in range(x0, x1 + 1, 4):
            draw.line([(bx, y0), (bx, y1)], fill=PAL["night"] + (255,))
    elif tt == "tide":
        draw.rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1], outline=PAL["ice"] + (255,))
    elif tt == "phantom":
        draw.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], outline=PAL["rose"] + (255,))


def _draw_dashed(draw: ImageDraw.ImageDraw, p0: Tuple[float, float], p1: Tuple[float, float], col: Tuple[int, int, int, int], width: int = 2, dash: float = 6.0, gap: float = 4.0) -> None:
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    dist = math.hypot(dx, dy)
    if dist < 1.0:
        return
    ux, uy = dx / dist, dy / dist
    t = 0.0
    while t < dist:
        t2 = min(dist, t + dash)
        draw.line([(p0[0] + ux * t, p0[1] + uy * t), (p0[0] + ux * t2, p0[1] + uy * t2)], fill=col, width=width)
        t += dash + gap


def _draw_arrow(draw: ImageDraw.ImageDraw, p0: Tuple[float, float], p1: Tuple[float, float], col: Tuple[int, int, int, int], width: int = 2, head: float = 6.0) -> None:
    draw.line([p0, p1], fill=col, width=width)
    ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
    a1, a2 = ang + 2.6, ang - 2.6
    draw.polygon([p1, (p1[0] + math.cos(a1) * head, p1[1] + math.sin(a1) * head), (p1[0] + math.cos(a2) * head, p1[1] + math.sin(a2) * head)], fill=col)


def _draw_light_pool(overlay: Image.Image, cx: float, cy: float, radius: float, rgb: Tuple[int, int, int], alpha_max: int = 58) -> None:
    d = ImageDraw.Draw(overlay)
    for frac, a in ((1.0, alpha_max // 3), (0.65, alpha_max // 2), (0.35, alpha_max)):
        r = radius * frac
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgb + (a,))


def _paste_centered(base: Image.Image, sprite: Image.Image, x: float, y: float, anchor: Tuple[int, int]) -> None:
    px = int(round(x - anchor[0]))
    py = int(round(y - anchor[1]))
    base.alpha_composite(sprite, (px, py)) if (px >= 0 and py >= 0 and px + sprite.width <= base.width and py + sprite.height <= base.height) else base.paste(sprite, (px, py), sprite)


def _snap_mirror_angle(props: Dict[str, Any]) -> int:
    ang = float(props.get("angle_deg", 45.0))
    if isinstance(props.get("normal"), list) and len(props["normal"]) >= 2:
        nx, ny = float(props["normal"][0]), float(props["normal"][1])
        ang = math.degrees(math.atan2(ny, nx))
    a = int(round((ang % 180.0) / 45.0) * 45) % 180
    return a if a in (0, 45, 90, 135) else 45


def _draw_tiled_sprite(base: Image.Image, spr: Image.Image, cx: float, cy: float, w: float, h: float) -> None:
    x0 = int(round(cx - w * 0.5))
    y0 = int(round(cy - h * 0.5))
    tw, th = max(1, spr.width), max(1, spr.height)
    yy = y0
    while yy < y0 + h - 0.5:
        sh = int(min(th, y0 + h - yy))
        xx = x0
        while xx < x0 + w - 0.5:
            sw = int(min(tw, x0 + w - xx))
            tile = spr if (sw == tw and sh == th) else spr.crop((0, 0, sw, sh))
            base.paste(tile, (xx, yy), tile)
            xx += sw
        yy += sh


def _interactable_sprite(it: Dict[str, Any], isl_id: int) -> Optional[Tuple[Image.Image, Tuple[int, int]]]:
    k = str(it.get("kind", "")).lower()
    props = it.get("props") or {}
    puz = REPO_ROOT / "luxel" / "art" / "props" / "puzzle_interactables.json"
    iprop = REPO_ROOT / "luxel" / "art" / "props" / f"island{isl_id}_props.json"
    idoor = REPO_ROOT / "luxel" / "art" / "props" / f"island{isl_id}_doors.json"

    if k in ("mirror", "blue_transformer", "transformer"):
        a = _snap_mirror_angle(props)
        is_blue = k != "mirror" or str(props.get("transforms_to", "blue")).lower() == "blue"
        key = f"mirror_{'blue' if is_blue else 'brass'}_{a}"
        return _crop_prop(puz, key) or _crop_prop(puz, "mirror_base_push")
    if k in ("blue_portal", "portal"):
        return _crop_prop(puz, "portal_active" if props.get("starts_powered") else "portal_dormant")
    if k in ("switch_eye", "switch"):
        return _crop_prop(puz, "eye_blue_dormant" if (props.get("requires_blue") or props.get("requires_prism")) else "eye_gold_dormant")
    if k in ("brazier", "timed_brazier"):
        return _crop_prop(puz, "brazier_lit" if (props.get("lit") or props.get("lit_by_default")) else "brazier_unlit")
    if k == "chest":
        return _crop_prop(iprop, "chest")
    if k == "shrine":
        return _crop_prop(iprop, "shrine")
    if k == "waystone":
        return _crop_prop(iprop, "waystone") or _crop_prop(iprop, "waystone_dormant")
    if k == "beacon":
        return _crop_prop(iprop, "beacon_unlit") or _crop_prop(iprop, "beacon")
    if k in ("road_lamp", "lamp"):
        return _crop_prop(iprop, "road_lamp")
    if k in ("great_lamp", "great_belfry_brazier"):
        return _crop_prop(iprop, "great_lamp_unlit") or _crop_prop(iprop, "great_lamp")
    if k == "rest_shrine":
        return _crop_prop(iprop, "rest_shrine")
    if k == "bramble":
        return _crop_prop(puz, "bramble_tile")
    if k in ("cracked_wall", "cracked"):
        return _crop_prop(puz, "cracked_slate")
    if k == "web":
        return _crop_prop(puz, "web_tile")
    if k in ("obsidian_seal", "seal"):
        return _crop_prop(puz, "obsidian_tile")
    if k in ("tide_gate", "tide"):
        return _crop_prop(puz, "tide_open")
    if k in ("phantom_platform", "phantom"):
        return _crop_prop(puz, "phantom_solid")
    if k in rl.DOOR_KINDS:
        dk = str(props.get("door_kind", props.get("door_type", k))).lower()
        sz = props.get("size", [32, 16])
        horiz = float(sz[0]) >= float(sz[1])
        if dk == "bridge_platform":
            return _crop_prop(idoor, "bridge_tile")
        if dk in ("boss_key", "boss_door"):
            return _crop_prop(idoor, "boss_key_h" if horiz else "wick_key_v")
        if dk in ("wick_key", "key_door", "locked_door"):
            return _crop_prop(idoor, "wick_key_h" if horiz else "wick_key_v")
        if dk == "combat_gate":
            return _crop_prop(idoor, "combat_gate_h" if horiz else "combat_gate_sq")
        if dk == "ward_barrier":
            return _crop_prop(idoor, "ward_barrier_h")
        return _crop_prop(idoor, "switch_door_h" if horiz else "switch_door_v_mid")
    return None


def _draw_interactable_glyph(draw: ImageDraw.ImageDraw, it: Dict[str, Any]) -> None:
    k = str(it.get("kind", "")).lower()
    px, py = float(it["pos"][0]), float(it["pos"][1])
    props = it.get("props") or {}
    sz = props.get("size", [16, 16])
    w, h = float(sz[0]), float(sz[1])
    x0, y0, x1, y1 = px - w * 0.5, py - h * 0.5, px + w * 0.5, py + h * 0.5

    if k in rl.DOOR_KINDS:
        dk = str(props.get("door_kind", props.get("door_type", k))).lower()
        col = PAL["apricot"] if dk == "bridge_platform" else (PAL["rose"] if dk in ("boss_key", "boss_door") else (PAL["gold"] if dk in ("wick_key", "locked_door") else (PAL["coral"] if dk == "combat_gate" else PAL["sky"])))
        draw.rectangle([x0, y0, x1, y1], fill=col + (150,), outline=PAL["cream"] + (255,), width=1)
    elif k in ("mirror", "blue_transformer", "transformer"):
        draw.rectangle([px - 6, py - 6, px + 6, py + 6], fill=PAL["sky"] + (230,), outline=PAL["void"] + (255,))
        ang = math.radians(float(props.get("angle_deg", 45.0)))
        if isinstance(props.get("normal"), list) and len(props["normal"]) >= 2:
            nx, ny = float(props["normal"][0]), float(props["normal"][1])
            ln = max(1e-4, math.hypot(nx, ny))
            nx, ny = nx / ln, ny / ln
        else:
            nx, ny = math.cos(ang), math.sin(ang)
        draw.line([(px - ny * 5, py + nx * 5), (px + ny * 5, py - nx * 5)], fill=PAL["cream"] + (255,), width=2)
        _draw_arrow(draw, (px, py), (px + nx * 12, py + ny * 12), PAL["ice"] + (255,), width=1, head=4.0)
    elif k in ("switch_eye", "switch"):
        col = PAL["ice"] if (props.get("requires_blue") or props.get("requires_prism")) else PAL["gold"]
        draw.polygon([(px, py - 6), (px + 6, py), (px, py + 6), (px - 6, py)], fill=col + (240,), outline=PAL["void"] + (255,))
    elif k in ("blue_portal", "portal"):
        draw.ellipse([px - 7, py - 7, px + 7, py + 7], fill=PAL["deep"] + (210,), outline=PAL["ice"] + (255,), width=2)
    elif k in ("tide_gate", "tide", "phantom_platform", "phantom", "moving_platform", "conveyor", "wind_zone", "crumble_floor", "spike_floor"):
        col = PAL["teal"] if "tide" in k else (PAL["plum"] if "phantom" in k else (PAL["coral"] if "spike" in k else PAL["sky"]))
        draw.rectangle([x0, y0, x1, y1], fill=col + (115,), outline=PAL["ice"] + (220,), width=1)
        path = props.get("path")
        if isinstance(path, list) and len(path) >= 2:
            pts = [(float(pt[0]), float(pt[1])) for pt in path if isinstance(pt, list) and len(pt) >= 2]
            for a, b in zip(pts, pts[1:]):
                _draw_arrow(draw, a, b, PAL["gold"] + (210,), width=1, head=4.0)
    elif k in ("bramble", "cracked_wall", "cracked", "web", "obsidian_seal", "seal"):
        col = PAL["jade"] if k == "bramble" else (PAL["stone"] if k == "web" else (PAL["wine"] if "obsidian" in k else PAL["coral"]))
        draw.rectangle([x0, y0, x1, y1], fill=col + (185,), outline=PAL["void"] + (255,), width=1)
    elif k in ("chest", "wick_key", "keepers_flame", "key", "pane_pickup", "moth"):
        col = PAL["gold"] if k in ("chest", "wick_key", "key") else (PAL["rose"] if k == "keepers_flame" else PAL["lime"])
        draw.rectangle([px - 5, py - 5, px + 5, py + 5], fill=col + (240,), outline=PAL["void"] + (255,))
    elif k in ("gravity_well", "bell"):
        r = float(props.get("radius", 36.0))
        draw.ellipse([px - r, py - r, px + r, py + r], outline=PAL["sky" if k == "gravity_well" else "gold"] + (160,), width=1)
        draw.ellipse([px - 5, py - 5, px + 5, py + 5], fill=PAL["ice" if k == "gravity_well" else "gold"] + (240,), outline=PAL["void"] + (255,))
    elif k in ("push_block", "pressure_plate", "toggle_block", "crystal_toggle", "logic_gate"):
        draw.rectangle([px - 6, py - 6, px + 6, py + 6], fill=PAL["mauve"] + (220,), outline=PAL["cream"] + (255,))
    else:
        draw.ellipse([px - 5, py - 5, px + 5, py + 5], fill=PAL["apricot"] + (230,), outline=PAL["void"] + (255,))


def render_region_image(
    reg: Dict[str, Any],
    scale: int = 2,
    state_vars: Optional[Dict[str, str]] = None,
    clean: bool = False,
) -> Image.Image:
    state_vars = state_vars or {}
    isl_id = reg["island_id"]
    w, h, ts = reg["width"], reg["height"], reg["tile_size"]
    px_w, px_h = max(16, reg["pixel_width"]), max(16, reg["pixel_height"])
    grid = [row[:] for row in reg["grid"]]

    # 1. Base ground PNG or biome-coloured fallback
    ground_png = REPO_ROOT / "luxel" / "art" / "islands" / str(isl_id) / f"{reg['id']}_ground.png"
    if ground_png.exists():
        base = Image.open(ground_png).convert("RGBA")
        if base.size != (px_w, px_h):
            base = base.resize((px_w, px_h), Image.Resampling.NEAREST)
    else:
        base = Image.new("RGBA", (px_w, px_h), PAL["void"] + (255,))
        bdraw = ImageDraw.Draw(base)
        for ty in range(h):
            for tx in range(w):
                _paint_tile_rect(bdraw, tx, ty, ts, grid[ty][tx], isl_id, reg["is_dungeon"])

    # 2. Apply active layers matching --state
    disabled_ids: Set[str] = set()
    enabled_ids: Set[str] = set()
    active_layer_names: List[str] = []
    for lay in reg.get("layers", []):
        if not isinstance(lay, dict):
            continue
        if eval_layer_cond(str(lay.get("when", "")), state_vars):
            active_layer_names.append(str(lay.get("id", "layer")))
            bdraw = ImageDraw.Draw(base)
            for trect in lay.get("tiles", []) if isinstance(lay.get("tiles"), list) else []:
                if isinstance(trect, list) and len(trect) >= 5:
                    rx, ry, rw, rh, tt = int(trect[0]), int(trect[1]), int(trect[2]), int(trect[3]), str(trect[4]).lower()
                    for ty in range(max(0, ry), min(h, ry + rh)):
                        for tx in range(max(0, rx), min(w, rx + rw)):
                            grid[ty][tx] = tt
                            _paint_tile_rect(bdraw, tx, ty, ts, tt, isl_id, reg["is_dungeon"])
            ov = str(lay.get("overlay", "")).strip()
            if ov.endswith(".png"):
                ov_p = REPO_ROOT / ov.replace("res://", "")
                if ov_p.exists():
                    ov_img = Image.open(ov_p).convert("RGBA")
                    if ov_img.size != (px_w, px_h):
                        ov_img = ov_img.resize((px_w, px_h), Image.Resampling.NEAREST)
                    base.alpha_composite(ov_img)
            for eid in lay.get("disable", []) or []:
                disabled_ids.add(str(eid))
            for eid in lay.get("enable", []) or []:
                enabled_ids.add(str(eid))
    disabled_ids -= enabled_ids

    inters = [it for it in reg["interactables"] if str(it.get("id", "")) not in disabled_ids]
    enemies = [en for en in reg["enemies"] if str(en.get("id", "")) not in disabled_ids]
    exits = [ex for ex in reg["exits"] if str(ex.get("id", "")) not in disabled_ids]

    # 3. Light pools layer
    light_ov = Image.new("RGBA", (px_w, px_h), (0, 0, 0, 0))
    for it in inters:
        k = str(it.get("kind", "")).lower()
        r = rl.INTERACTABLE_LIGHT_RADII.get(k, 0.0)
        if r > 0 and isinstance(it.get("pos"), list) and len(it["pos"]) >= 2:
            col = PAL["ice"] if k in ("blue_portal", "portal") else PAL["gold"]
            _draw_light_pool(light_ov, float(it["pos"][0]), float(it["pos"][1]), r, col, 48)
    for sc in reg["scenery"]:
        if isinstance(sc, dict):
            r = rl.GLOW_PROP_RADII.get(str(sc.get("prop", "")), 0.0)
            p = sc.get("pos", [])
            if r > 0 and isinstance(p, list) and len(p) >= 2:
                _draw_light_pool(light_ov, float(p[0]), float(p[1]) - 8.0, r, PAL["apricot"], 42)
    base = Image.alpha_composite(base, light_ov)

    # 4. Ground scenery
    sc_ground, sc_sort, sc_over = [], [], []
    for sc in reg["scenery"]:
        if not isinstance(sc, dict):
            continue
        lay_n = str(sc.get("layer", "sort")).lower()
        (sc_ground if lay_n == "ground" else (sc_over if lay_n == "overhead" else sc_sort)).append(sc)

    def _draw_scenery_item(sc: Dict[str, Any]) -> None:
        sn = str(sc.get("sheet", "")).strip()
        pk = str(sc.get("prop", "")).strip()
        p = sc.get("pos", [])
        if not sn or not pk or not isinstance(p, list) or len(p) < 2:
            return
        sp = REPO_ROOT / "luxel" / "art" / "props" / (sn if sn.endswith(".json") else f"{sn}.json")
        res = _crop_prop(sp, pk, flip_x=bool(sc.get("flip_x", False)))
        if res:
            _paste_centered(base, res[0], float(p[0]), float(p[1]), res[1])

    for sc in sc_ground:
        _draw_scenery_item(sc)

    # 5. Subtle mechanical tile borders (phantom, tide)
    if not clean:
        tov = Image.new("RGBA", (px_w, px_h), (0, 0, 0, 0))
        tdraw = ImageDraw.Draw(tov)
        for ty in range(h):
            for tx in range(w):
                tt = grid[ty][tx]
                if tt == "phantom":
                    tdraw.rectangle([tx * ts, ty * ts, (tx + 1) * ts - 1, (ty + 1) * ts - 1], fill=PAL["plum"] + (65,), outline=PAL["rose"] + (165,))
                elif tt == "tide":
                    tdraw.rectangle([tx * ts, ty * ts, (tx + 1) * ts - 1, (ty + 1) * ts - 1], fill=PAL["teal"] + (55,), outline=PAL["ice"] + (155,))
        base = Image.alpha_composite(base, tov)

    # 6. Y-sorted scenery + interactables + enemies
    sort_items: List[Tuple[float, str, Dict[str, Any]]] = []
    for sc in sc_sort:
        p = sc.get("pos", [0, 0])
        sort_items.append((float(p[1]) if len(p) >= 2 else 0.0, "scenery", sc))
    for it in inters:
        p = it.get("pos", [0, 0])
        sort_items.append((float(p[1]) if len(p) >= 2 else 0.0, "inter", it))
    for en in enemies:
        p = en.get("pos", [0, 0])
        sort_items.append((float(p[1]) if len(p) >= 2 else 0.0, "enemy", en))
    sort_items.sort(key=lambda t: t[0])

    # Signal & portal wiring lines beneath foreground icons (non-clean)
    if not clean:
        wov = Image.new("RGBA", (px_w, px_h), (0, 0, 0, 0))
        wdraw = ImageDraw.Draw(wov)
        by_id = {str(it.get("id", "")): it for it in inters if it.get("id")}
        drawn_portals: Set[Tuple[str, str]] = set()
        for it in inters:
            k = str(it.get("kind", "")).lower()
            props = it.get("props") or {}
            p0 = (float(it["pos"][0]), float(it["pos"][1]))
            if k in ("blue_portal", "portal"):
                tpid = str(props.get("target_portal_id", ""))
                pid = str(it.get("id", ""))
                if tpid in by_id:
                    pair = (min(pid, tpid), max(pid, tpid))
                    if pair not in drawn_portals:
                        drawn_portals.add(pair)
                        p1 = (float(by_id[tpid]["pos"][0]), float(by_id[tpid]["pos"][1]))
                        _draw_dashed(wdraw, p0, p1, PAL["ice"] + (210,), width=1, dash=4.0, gap=3.0)
            targets = []
            if props.get("target_id"):
                targets.append(str(props["target_id"]))
            if isinstance(props.get("target_ids"), list):
                targets.extend(str(t) for t in props["target_ids"])
            for tid in targets:
                if tid in by_id:
                    p1 = (float(by_id[tid]["pos"][0]), float(by_id[tid]["pos"][1]))
                    col = PAL["sky"] + (200,) if (props.get("requires_blue") or props.get("requires_prism")) else PAL["gold"] + (200,)
                    _draw_dashed(wdraw, p0, p1, col, width=1, dash=4.0, gap=2.0)
        base = Image.alpha_composite(base, wov)

    for _, kind_tag, obj in sort_items:
        if kind_tag == "scenery":
            _draw_scenery_item(obj)
        elif kind_tag == "inter":
            ik = str(obj.get("kind", "")).lower()
            props = obj.get("props") or {}
            px, py = float(obj["pos"][0]), float(obj["pos"][1])
            spr = _interactable_sprite(obj, isl_id)
            tiled_kinds = rl.DOOR_KINDS | {"bramble", "cracked_wall", "cracked", "web", "obsidian_seal", "seal", "tide_gate", "tide", "phantom_platform", "phantom"}
            if spr:
                if ik in tiled_kinds and isinstance(props.get("size"), list) and len(props["size"]) >= 2:
                    sw, sh = float(props["size"][0]), float(props["size"][1])
                    _draw_tiled_sprite(base, spr[0], px, py, sw, sh)
                    if not clean and ik in rl.DOOR_KINDS:
                        dk = str(props.get("door_kind", props.get("door_type", ik))).lower()
                        oc = PAL["apricot"] if dk == "bridge_platform" else PAL["gold"]
                        ImageDraw.Draw(base).rectangle([px - sw * 0.5, py - sh * 0.5, px + sw * 0.5 - 1, py + sh * 0.5 - 1], outline=oc + (210,))
                else:
                    _paste_centered(base, spr[0], px, py, spr[1])
                if ik in ("mirror", "blue_transformer", "transformer") and not clean:
                    idraw = ImageDraw.Draw(base)
                    ang = math.radians(float(props.get("angle_deg", 45.0)))
                    nx, ny = math.cos(ang), math.sin(ang)
                    _draw_arrow(idraw, (px, py), (px + nx * 13, py + ny * 13), PAL["ice"] + (255,), width=1, head=4.0)
            else:
                iov = Image.new("RGBA", (px_w, px_h), (0, 0, 0, 0))
                _draw_interactable_glyph(ImageDraw.Draw(iov), obj)
                base = Image.alpha_composite(base, iov)
        elif kind_tag == "enemy":
            ex, ey = float(obj["pos"][0]), float(obj["pos"][1])
            espr = _crop_enemy(str(obj.get("kind", "")))
            if espr:
                _paste_centered(base, espr[0], ex, ey, espr[1])
            else:
                edraw = ImageDraw.Draw(base)
                edraw.ellipse([ex - 6, ey - 6, ex + 6, ey + 6], fill=PAL["coral"] + (240,), outline=PAL["cream"] + (255,))

    for sc in sc_over:
        _draw_scenery_item(sc)

    # 7. Exits & Spawn (1x highlight)
    if not clean:
        eov = Image.new("RGBA", (px_w, px_h), (0, 0, 0, 0))
        edraw = ImageDraw.Draw(eov)
        for ex in exits:
            r = ex.get("rect", [])
            if isinstance(r, list) and len(r) >= 4:
                locked = bool(ex.get("locked_door_id")) or bool(ex.get("requires_flags"))
                col = PAL["coral"] if locked else PAL["lime"]
                edraw.rectangle([r[0], r[1], r[0] + r[2] - 1, r[1] + r[3] - 1], fill=col + (70,), outline=col + (220,), width=1)
        sp = reg["spawn"]
        if isinstance(sp, list) and len(sp) >= 2:
            sx, sy = float(sp[0]), float(sp[1])
            edraw.ellipse([sx - 4, sy - 4, sx + 4, sy + 4], fill=PAL["lime"] + (190,), outline=PAL["void"] + (255,))
            edraw.line([(sx - 6, sy), (sx + 6, sy)], fill=PAL["cream"] + (255,))
            edraw.line([(sx, sy - 6), (sx, sy + 6)], fill=PAL["cream"] + (255,))
        base = Image.alpha_composite(base, eov)

    # 8. Scale up crisply (1x - 3x)
    scale = max(1, min(3, scale))
    out_w, out_h = px_w * scale, px_h * scale
    scaled = base.resize((out_w, out_h), Image.Resampling.NEAREST)
    if clean:
        return scaled.convert("RGB")

    # 9. Draw razor-sharp labels + header AFTER upscaling (VLM-friendly)
    font_hdr = _load_font(12 if scale >= 2 else 10)
    font_lbl = _load_font(10 if scale >= 2 else 9)
    hdr_h = 26 if scale >= 2 else 20
    canvas = Image.new("RGBA", (out_w, out_h + hdr_h), PAL["void"] + (255,))
    canvas.paste(scaled, (0, hdr_h))
    draw = ImageDraw.Draw(canvas)

    # Header bar
    draw.rectangle([0, 0, out_w - 1, hdr_h - 1], fill=PAL["night"] + (255,))
    draw.line([(0, hdr_h - 1), (out_w, hdr_h - 1)], fill=PAL["dusk"] + (255,))
    des = reg.get("design") or {}
    meta_bits = [f"{reg['key']} ({w}x{h})"]
    if des.get("kind"):
        meta_bits.append(f"{des['kind']}/{des.get('beat', '-')}")
    meta_bits.append(f"en={len(enemies)} int={len(inters)}")
    if active_layer_names:
        meta_bits.append("layers=" + ",".join(active_layer_names))
    if des.get("idea"):
        meta_bits.append(str(des["idea"]))
    hdr_txt = " | ".join(meta_bits)
    max_chars = max(24, (out_w - 16) // (7 if scale >= 2 else 6))
    if len(hdr_txt) > max_chars:
        hdr_txt = hdr_txt[: max_chars - 3] + "..."
    draw.text((6, 5 if scale >= 2 else 4), hdr_txt, font=font_hdr, fill=PAL["gold"] + (255,))

    # Collision-avoided pill labels for interactables, enemies, exits, spawn
    placed_boxes: List[Tuple[int, int, int, int]] = []

    def draw_pill(cx: float, cy: float, text: str, fg: Tuple[int, int, int], bg: Tuple[int, int, int]) -> None:
        if not text:
            return
        bb = draw.textbbox((0, 0), text, font=font_lbl)
        tw, th = bb[2] - bb[0], bb[3] - bb[1]
        pw, ph = tw + 6, th + 3
        x0 = max(2, min(out_w - pw - 2, int(round(cx - pw * 0.5))))
        y0 = max(hdr_h + 2, min(out_h + hdr_h - ph - 2, int(round(cy - ph - 6))))
        for _ in range(4):
            overlap = any(not (x0 + pw < bx0 or x0 > bx1 or y0 + ph < by0 or y0 > by1) for bx0, by0, bx1, by1 in placed_boxes)
            if not overlap:
                break
            y0 = max(hdr_h + 2, min(out_h + hdr_h - ph - 2, y0 + ph + 2))
        placed_boxes.append((x0, y0, x0 + pw, y0 + ph))
        draw.rectangle([x0, y0, x0 + pw, y0 + ph], fill=bg + (220,), outline=fg + (200,))
        draw.text((x0 + 3, y0 + 1), text, font=font_lbl, fill=fg + (255,))

    for it in inters:
        iid = str(it.get("id", ""))
        k = str(it.get("kind", "")).lower()
        if k == "road_lamp":
            continue
        draw_pill(float(it["pos"][0]) * scale, hdr_h + float(it["pos"][1]) * scale, iid, PAL["cream"], PAL["night"])
    for en in enemies:
        lbl = f"{en.get('kind', '?')}"
        draw_pill(float(en["pos"][0]) * scale, hdr_h + float(en["pos"][1]) * scale, lbl, PAL["coral"], PAL["void"])
    for ex in exits:
        r = ex.get("rect", [])
        if isinstance(r, list) and len(r) >= 4:
            cx = (float(r[0]) + float(r[2]) * 0.5) * scale
            cy = hdr_h + (float(r[1]) + float(r[3]) * 0.5) * scale
            tag = "->" + str(ex.get("to_region", "?"))
            if ex.get("locked_door_id"):
                tag += " [LOCK]"
            draw_pill(cx, cy, tag, PAL["lime"] if not ex.get("locked_door_id") else PAL["apricot"], PAL["void"])
    sp = reg["spawn"]
    if isinstance(sp, list) and len(sp) >= 2:
        draw_pill(float(sp[0]) * scale, hdr_h + float(sp[1]) * scale + 14, "SPAWN", PAL["lime"], PAL["void"])

    return canvas.convert("RGB")


def _infer_exit_dir(reg: Dict[str, Any], ex: Dict[str, Any]) -> Tuple[int, int]:
    eid = str(ex.get("id", "")).lower()
    if "east" in eid or "_e" in eid:
        return (1, 0)
    if "west" in eid or "_w" in eid:
        return (-1, 0)
    if "north" in eid or "_n" in eid:
        return (0, -1)
    if "south" in eid or "_s" in eid:
        return (0, 1)
    r = ex.get("rect", [0, 0, 0, 0])
    if isinstance(r, list) and len(r) >= 4:
        cx, cy = float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.5
        pw, ph = max(1.0, float(reg["pixel_width"])), max(1.0, float(reg["pixel_height"]))
        nx, ny = cx / pw - 0.5, cy / ph - 0.5
        if abs(nx) >= abs(ny):
            return (1, 0) if nx >= 0 else (-1, 0)
        return (0, 1) if ny >= 0 else (0, -1)
    return (1, 0)


def render_dungeon_sheet(
    regs: List[Dict[str, Any]],
    title: str,
    scale: int = 1,
    state_vars: Optional[Dict[str, str]] = None,
    clean: bool = False,
) -> Image.Image:
    """Arrange rooms in a 2D topological graph layout based on directional exits, with edge arrows."""
    reg_by_id = {r["id"]: r for r in regs}
    ids = sorted(reg_by_id.keys())
    entry = next((rid for rid in ids if rid.endswith("_r1")), ids[0])

    # Place rooms on integer graph grid (gx, gy) using BFS + exit cardinal directions
    coords: Dict[str, Tuple[int, int]] = {entry: (0, 0)}
    occupied: Set[Tuple[int, int]] = {(0, 0)}
    q: deque[str] = deque([entry])

    def claim_nearest(want: Tuple[int, int]) -> Tuple[int, int]:
        if want not in occupied:
            occupied.add(want)
            return want
        for rad in range(1, 12):
            for dy in range(-rad, rad + 1):
                for dx in range(-rad, rad + 1):
                    c = (want[0] + dx, want[1] + dy)
                    if c not in occupied:
                        occupied.add(c)
                        return c
        occupied.add(want)
        return want

    while q:
        u = q.popleft()
        ux, uy = coords[u]
        for ex in reg_by_id[u]["exits"]:
            v = str(ex.get("to_region", ""))
            if v in reg_by_id and v not in coords:
                dx, dy = _infer_exit_dir(reg_by_id[u], ex)
                coords[v] = claim_nearest((ux + dx, uy + dy))
                q.append(v)
    # Place any disconnected rooms
    for rid in ids:
        if rid not in coords:
            coords[rid] = claim_nearest((0, len(coords)))

    # Normalize coordinates to >= 0
    min_x = min(c[0] for c in coords.values())
    min_y = min(c[1] for c in coords.values())
    coords = {k: (v[0] - min_x, v[1] - min_y) for k, v in coords.items()}

    # Render cards at consistent scale
    cards: Dict[str, Image.Image] = {}
    for rid in ids:
        cards[rid] = render_region_image(reg_by_id[rid], scale=scale, state_vars=state_vars, clean=clean)

    max_gx = max(c[0] for c in coords.values())
    max_gy = max(c[1] for c in coords.values())
    col_w = [max((cards[rid].width for rid, c in coords.items() if c[0] == gx), default=320) for gx in range(max_gx + 1)]
    row_h = [max((cards[rid].height for rid, c in coords.items() if c[1] == gy), default=220) for gy in range(max_gy + 1)]

    gap_x, gap_y = 44, 40
    banner_h = 44
    pad = 24
    col_x = [pad]
    for cw in col_w[:-1]:
        col_x.append(col_x[-1] + cw + gap_x)
    row_y = [banner_h + pad]
    for rh in row_h[:-1]:
        row_y.append(row_y[-1] + rh + gap_y)

    sheet_w = col_x[-1] + col_w[-1] + pad
    sheet_h = row_y[-1] + row_h[-1] + pad
    sheet = Image.new("RGBA", (sheet_w, sheet_h), PAL["void"] + (255,))
    sdraw = ImageDraw.Draw(sheet)

    # Top banner
    font_b = _load_font(15)
    font_s = _load_font(11)
    sdraw.rectangle([0, 0, sheet_w - 1, banner_h - 1], fill=PAL["night"] + (255,))
    sdraw.line([(0, banner_h - 1), (sheet_w, banner_h - 1)], fill=PAL["plum"] + (255,), width=2)
    sdraw.text((14, 8), f"LUXEL GRAPH SHEET: {title}  ({len(ids)} rooms, scale={scale}x)", font=font_b, fill=PAL["gold"] + (255,))
    sdraw.text((14, 26), "Edges: GOLD=open  CORAL=locked/gated  ICE-DASHED=shortcut/return", font=font_s, fill=PAL["stone"] + (255,))

    # Compute card rects and paste cards
    rects: Dict[str, Tuple[int, int, int, int]] = {}
    for rid in ids:
        gx, gy = coords[rid]
        c_img = cards[rid]
        x0 = col_x[gx] + (col_w[gx] - c_img.width) // 2
        y0 = row_y[gy] + (row_h[gy] - c_img.height) // 2
        rects[rid] = (x0, y0, x0 + c_img.width, y0 + c_img.height)
        sdraw.rectangle([x0 - 2, y0 - 2, x0 + c_img.width + 1, y0 + c_img.height + 1], outline=PAL["mauve"] + (255,), width=2)
        sheet.paste(c_img.convert("RGBA"), (x0, y0))

    # Draw directed graph edges routed cleanly in gutters so arrows never cut across room artwork
    drawn_undir: Set[Tuple[str, str]] = set()
    gutter_slot = 0
    for u in ids:
        ugx, ugy = coords[u]
        ux0, uy0, ux1, uy1 = rects[u]
        ucx, ucy = (ux0 + ux1) * 0.5, (uy0 + uy1) * 0.5
        for ex in reg_by_id[u]["exits"]:
            v = str(ex.get("to_region", ""))
            if v not in rects or v == u:
                continue
            eid = str(ex.get("id", "")).lower()
            is_short = "shortcut" in eid or "return" in eid
            is_locked = bool(ex.get("locked_door_id")) or bool(ex.get("requires_flags"))
            key_u = (min(u, v), max(u, v))
            if not is_short and not is_locked and key_u in drawn_undir:
                continue
            drawn_undir.add(key_u)
            vgx, vgy = coords[v]
            vx0, vy0, vx1, vy1 = rects[v]
            vcx, vcy = (vx0 + vx1) * 0.5, (vy0 + vy1) * 0.5
            col = PAL["ice"] if is_short else (PAL["coral"] if is_locked else PAL["gold"])
            adj_cardinal = (abs(ugx - vgx) + abs(ugy - vgy) == 1)

            if adj_cardinal:
                if vgx > ugx:
                    pts = [(ux1 + 2, ucy + (6 if is_short else 0)), (vx0 - 2, vcy + (6 if is_short else 0))]
                elif vgx < ugx:
                    pts = [(ux0 - 2, ucy + (6 if is_short else 0)), (vx1 + 2, vcy + (6 if is_short else 0))]
                elif vgy > ugy:
                    pts = [(ucx + (6 if is_short else 0), uy1 + 2), (vcx + (6 if is_short else 0), vy0 - 2)]
                else:
                    pts = [(ucx + (6 if is_short else 0), uy0 - 2), (vcx + (6 if is_short else 0), vy1 + 2)]
            else:
                # Route through horizontal gutter lane between rows so we never cut over intermediate rooms
                gutter_slot += 1
                lane_off = ((gutter_slot % 5) - 2) * 5
                gy_mid = min(ugy, vgy)
                gutter_y = row_y[gy_mid] + row_h[gy_mid] + gap_y // 2 + lane_off
                sy = uy1 + 2 if gutter_y >= ucy else uy0 - 2
                ey = vy0 - 2 if gutter_y <= vcy else vy1 + 2
                sx = ucx + lane_off
                ex_p = vcx + lane_off
                pts = [(sx, sy), (sx, gutter_y), (ex_p, gutter_y), (ex_p, ey)]

            for a, b in zip(pts[:-1], pts[1:]):
                if is_short:
                    _draw_dashed(sdraw, a, b, col + (235,), width=2, dash=7.0, gap=4.0)
                else:
                    sdraw.line([a, b], fill=col + (240,), width=3 if is_locked else 2)
            p_prev, p_last = pts[-2], pts[-1]
            _draw_arrow(sdraw, (p_prev[0] + (p_last[0] - p_prev[0]) * 0.7, p_prev[1] + (p_last[1] - p_prev[1]) * 0.7), p_last, col + (255,), width=2, head=8.0)

    return sheet.convert("RGB")


def parse_states(raw_states: Sequence[str]) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for s in raw_states:
        for part in s.split(","):
            if "=" in part:
                k, v = part.split("=", 1)
                out[k.strip()] = v.strip()
    return out


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Luxel Epic region & dungeon graph renderer (uv + Pillow)")
    ap.add_argument("--region", type=str, default="", help="Single region (e.g. 2:lighthouse_r5 or lighthouse_r5)")
    ap.add_argument("--island", type=int, default=0, help="Island ID (1..8)")
    ap.add_argument("--dungeon", type=str, default="", help="Dungeon ID (e.g. lighthouse, belfry)")
    ap.add_argument("--sheet", action="store_true", help="Render whole dungeon/island contact sheet in graph layout")
    ap.add_argument("--scale", type=int, default=2, choices=[1, 2, 3], help="Pixel scale (1-3)")
    ap.add_argument("--state", action="append", default=[], help="World state overrides (e.g. --state tide=ebb)")
    ap.add_argument("--clean", action="store_true", help="Clean render without labels or tactical overlays")
    ap.add_argument("--fixtures", type=str, default="", help="Optional fixture overlay dir for design headers")
    ap.add_argument("--out", type=str, required=True, help="Output PNG path")
    args = ap.parse_args(argv)

    catalog = rl.load_engine_catalog()
    all_regions = rl.discover_all_regions(Path(args.fixtures) if args.fixtures else None)
    state_vars = parse_states(args.state)
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    if args.sheet or args.dungeon:
        chosen: List[Dict[str, Any]] = []
        title = ""
        if args.dungeon:
            dlow = args.dungeon.lower()
            title = args.dungeon
            for r in sorted(all_regions.values(), key=lambda x: x["key"]):
                did = rl.infer_dungeon_id(r, catalog).lower()
                if (did == dlow or r["id"].startswith(dlow + "_")) and (args.island == 0 or r["island_id"] == args.island):
                    chosen.append(r)
        elif args.island > 0:
            title = f"island_{args.island}"
            chosen = [r for r in sorted(all_regions.values(), key=lambda x: x["key"]) if r["island_id"] == args.island and r["is_dungeon"]]
        if not chosen:
            raise SystemExit(f"No matching dungeon rooms found for dungeon='{args.dungeon}' island={args.island}")
        img = render_dungeon_sheet(chosen, title=title, scale=args.scale, state_vars=state_vars, clean=args.clean)
        img.save(out_path, "PNG")
        print(f"RENDER SHEET OK: {out_path} ({img.width}x{img.height}, rooms={len(chosen)})")
        return 0

    # Single region
    target = None
    if args.region:
        if args.region in all_regions:
            target = all_regions[args.region]
        else:
            for r in all_regions.values():
                if r["id"] == args.region and (args.island == 0 or r["island_id"] == args.island):
                    target = r
                    break
    if target is None:
        raise SystemExit(f"Region not found: {args.region}")
    img = render_region_image(target, scale=args.scale, state_vars=state_vars, clean=args.clean)
    img.save(out_path, "PNG")
    print(f"RENDER REGION OK: {out_path} ({img.width}x{img.height}, scale={args.scale}x)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
