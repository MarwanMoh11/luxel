#!/usr/bin/env python3
"""Luxel Neuro-Symbolic Level Design Critic (Python 3 stdlib only).

Parses Luxel .map + .json regions (exact LxMapFormat parity) and evaluates:
  1. Mirror symmetry score (sym_h, sym_v, sym_max) & SYMMETRIC_BOX flag
  2. Hidden-path / Phantom tile critic (winding_score & CENTERED_WAFFLE flag)
  3. Dead-stub & broken-wiring detector (unwired switches, dead mirrors/transformers,
     skippable tide gates, stale triggers, solid-placed / unreachable interactables)
  4. State-space optical puzzle solver (16x16 grid, 118 px bolt range refreshed per
     bounce up to 2 bounces, 45 deg double-sided reflection, movable transformers,
     latching switches -> doors/bridges, latching blue_portal warps, L_min, anti_cheese)
  5. Dormans cyclic topology check (room-exit graph & overworld zone graph, LINEAR_TUBE)
  6. Combat choreography critic (enemy role diversity & interior cover density)

CLI:
  python3 tools/design_critic/design_critic.py audit_all [--out docs/design_critic_report.md]
  python3 tools/design_critic/design_critic.py audit_island <1..8>
  python3 tools/design_critic/design_critic.py audit_room <map_path> <json_path>
"""

from __future__ import annotations

import argparse
from collections import Counter, deque
import glob
import heapq
import json
import math
import os
import sys
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple

# ---------------------------------------------------------------------------
# Constants matching luxel/world/map_format.gd & luxel/player/kit/*.gd
# ---------------------------------------------------------------------------

DEFAULT_TILE_SIZE = 16
BOLT_RANGE = 118.0
BOLT_MAX_BOUNCES = 2
BOLT_STEP_PX = 2.5

DEFAULT_LEGEND: Dict[str, str] = {
    ".": "ground",
    "#": "wall",
    ",": "path",
    "~": "water",
    "O": "pit",
    "_": "void",
    "B": "bramble",
    "C": "cracked",
    "T": "tide",
    "P": "phantom",
    "+": "bridge",
    "G": "glass",
    " ": "void",
}

WALKABLE_BASE_TILES: Set[str] = {"ground", "path", "bridge"}
SIGHT_BLOCKING_TILES: Set[str] = {"wall", "bramble", "cracked", "glass", "mirror"}
FEATURE_TILES: Set[str] = {
    "ground",
    "path",
    "phantom",
    "water",
    "pit",
    "wall",
    "bridge",
    "tide",
    "bramble",
    "cracked",
    "glass",
    "mirror",
}
COVER_TILES: Set[str] = {
    "wall",
    "pit",
    "water",
    "tide",
    "bramble",
    "cracked",
    "glass",
    "mirror",
}

MIRROR_KINDS: Set[str] = {"mirror", "blue_transformer", "transformer"}
SWITCH_KINDS: Set[str] = {"switch_eye", "switch"}
PORTAL_KINDS: Set[str] = {"blue_portal", "portal"}
DOOR_KINDS: Set[str] = {
    "door",
    "ward_barrier",
    "locked_door",
    "boss_door",
    "boss_key",
    "combat_gate",
    "switch_door",
    "bridge_platform",
}
TIDE_KINDS: Set[str] = {"tide_gate", "tide"}
KEY_INTERACTABLES: Set[str] = {
    "chest",
    "waystone",
    "beacon",
    "shrine",
    "rest_shrine",
    "blue_portal",
    "portal",
    "switch_eye",
    "switch",
    "great_lamp",
    "great_belfry_brazier",
    "wick_key",
    "keepers_flame",
    "key",
    "lantern_pickup",
}

# Canonical aliases matching luxel/enemies/enemy_factory.gd
ENEMY_ALIASES: Dict[str, str] = {
    "parasol_toad": "warden",
    "toad_warden": "warden",
    "magpie": "snatcher",
    "magpie_snatcher": "snatcher",
    "hush_owl": "owl",
    "owl_sentinel": "owl",
    "moonshade": "moonshade_warden",
    "belfry_warden": "bell_warden",
    "grand_bellkeeper": "bellkeeper",
}

# Role classification across all 37 Luxel enemy/boss kinds
ENEMY_ROLES: Dict[str, str] = {
    # Bosses (15)
    "bell_warden": "Boss",
    "bellkeeper": "Boss",
    "tide_captain": "Boss",
    "lighthouse_hermit": "Boss",
    "elder_sporecap": "Boss",
    "briar_matron": "Boss",
    "great_lily_hopper": "Boss",
    "heron_abbess": "Boss",
    "clockwork_warden": "Boss",
    "astronomer": "Boss",
    "forge_warden": "Boss",
    "kilnmother": "Boss",
    "hollow_wick_boss": "Boss",
    "night_harbinger": "Boss",
    "the_hush": "Boss",
    # Shield / Tank (armored or front-shielded)
    "warden": "Shield/Tank",
    "crab_warden": "Shield/Tank",
    "bramble_knight": "Shield/Tank",
    "barnacle_sentry": "Shield/Tank",
    "cinder_golem": "Shield/Tank",
    "moonshade_warden": "Shield/Tank",
    # Pressure (rushdown, leap, dive, relentless combatant)
    "lily_hopper": "Pressure",
    "heron_stalker": "Pressure",
    "owl": "Pressure",
    "moonshade_owl": "Pressure",
    "hollow_wick": "Pressure",
    # Disrupter (shockwaves, knockback gusts, rotating beams, light snuffing)
    "sporecap": "Disrupter",
    "bellows_imp": "Disrupter",
    "orrery_sentinel": "Disrupter",
    "mire_snuffer": "Disrupter",
    # Trickster (lantern snatchers, shadow ambushers, burrowers, mimics)
    "snatcher": "Trickster",
    "gull_thief": "Trickster",
    "ash_mole": "Trickster",
    "moonshade_snatcher": "Trickster",
    "gloam": "Trickster",
    "echo_moth": "Trickster",
    "phantom_owl": "Trickster",
}

SHIELDED_OR_BOSS_KINDS: Set[str] = {
    k for k, role in ENEMY_ROLES.items() if role in ("Boss", "Shield/Tank")
}

# Severity weights for ranking worst offenders
FLAG_WEIGHTS: Dict[str, int] = {
    "PUZZLE_UNSOLVABLE": 12,
    "UNREACHABLE_INTERACTABLE": 10,
    "INTERACTABLE_IN_SOLID": 9,
    "BROKEN_SWITCH_TARGET": 9,
    "UNWIRED_SWITCH": 8,
    "SKIPPABLE_TIDE_GATE": 7,
    "PUZZLE_CHEESABLE": 7,
    "DEAD_MIRROR": 6,
    "DEAD_TRANSFORMER": 6,
    "CENTERED_WAFFLE": 6,
    "STALE_TRIGGER": 5,
    "SYMMETRIC_BOX": 4,
    "EMPTY_BOX_COMBAT": 4,
    "HOMOGENOUS_SWARM": 3,
    "LINEAR_TUBE": 8,
}


# ---------------------------------------------------------------------------
# Repo path helpers
# ---------------------------------------------------------------------------

def repo_root() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, "..", ".."))


def island_dir(island_id: int) -> str:
    return os.path.join(repo_root(), "luxel", "islands", str(island_id))


def list_island_regions(island_id: int) -> List[Tuple[str, str, str]]:
    """Return sorted list of (region_id, map_path, json_path) for an island."""
    d = island_dir(island_id)
    if not os.path.isdir(d):
        return []
    out: List[Tuple[str, str, str]] = []
    for mp in sorted(glob.glob(os.path.join(d, "*.map"))):
        reg_id = os.path.basename(mp)[:-4]
        jp = os.path.join(d, reg_id + ".json")
        out.append((reg_id, mp, jp if os.path.exists(jp) else ""))
    # Put overworld first, then dungeon rooms sorted naturally
    def sort_key(item: Tuple[str, str, str]) -> Tuple[int, str, int]:
        rid = item[0]
        if rid == "overworld":
            return (0, "", 0)
        prefix = rid.rstrip("0123456789")
        num_str = rid[len(prefix):]
        num = int(num_str) if num_str.isdigit() else 999
        return (1, prefix, num)

    out.sort(key=sort_key)
    return out


# ---------------------------------------------------------------------------
# Map & Region Parsing (exact parity with luxel/world/map_format.gd)
# ---------------------------------------------------------------------------

def parse_map_text(text: str) -> Dict[str, Any]:
    legend: Dict[str, str] = dict(DEFAULT_LEGEND)
    tile_size: int = DEFAULT_TILE_SIZE
    raw_rows: List[str] = []
    in_map = False
    saw_map_marker = False

    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    for raw_line in lines:
        if not in_map:
            trimmed = raw_line.strip()
            if not trimmed or trimmed.startswith("#"):
                continue
            if trimmed == "MAP":
                in_map = True
                saw_map_marker = True
                continue
            if trimmed.startswith("TILE_SIZE "):
                try:
                    ts = int(trimmed[10:].strip())
                    if ts > 0:
                        tile_size = ts
                except ValueError:
                    pass
                continue
            if trimmed.startswith("LEGEND "):
                rest = trimmed[7:].strip()
                parts = [p for p in rest.split(" ") if p]
                if len(parts) >= 2:
                    ch = parts[0][:1]
                    ttype = parts[1].strip().lower()
                    if ch and ttype:
                        legend[ch] = ttype
                continue
        else:
            stripped = raw_line.strip()
            if not stripped:
                continue
            if stripped in ("END", "ENDMAP"):
                break
            raw_rows.append(raw_line)

    if not saw_map_marker and not raw_rows:
        for raw_line in lines:
            if raw_line.strip():
                raw_rows.append(raw_line)

    height = len(raw_rows)
    width = max((len(r) for r in raw_rows), default=0)

    grid: List[List[str]] = []
    for y in range(height):
        src = raw_rows[y]
        row: List[str] = []
        for x in range(width):
            ch = src[x] if x < len(src) else "_"
            row.append(legend.get(ch, "void"))
        grid.append(row)

    return {
        "width": width,
        "height": height,
        "tile_size": tile_size,
        "legend": legend,
        "grid": grid,
        "raw_rows": raw_rows,
    }


def parse_map(map_path: str) -> Dict[str, Any]:
    with open(map_path, "r", encoding="utf-8") as f:
        return parse_map_text(f.read())


def parse_region(map_path: str, json_path: str = "") -> Dict[str, Any]:
    m = parse_map(map_path)
    j: Dict[str, Any] = {}
    if json_path and os.path.exists(json_path):
        with open(json_path, "r", encoding="utf-8") as f:
            parsed = json.load(f)
            if isinstance(parsed, dict):
                j = parsed

    width = int(m["width"])
    height = int(m["height"])
    tile_size = int(j.get("tile_size", m["tile_size"]))
    if tile_size <= 0:
        tile_size = DEFAULT_TILE_SIZE
    px_w = width * tile_size
    px_h = height * tile_size

    out: Dict[str, Any] = dict(j)
    default_id = os.path.splitext(os.path.basename(map_path))[0]
    out["id"] = str(j.get("id", default_id))
    out["island_id"] = int(j.get("island_id", _infer_island_id(map_path)))
    out["tile_size"] = tile_size
    out["is_dungeon"] = bool(j.get("is_dungeon", False))
    out["width"] = width
    out["height"] = height
    out["pixel_width"] = px_w
    out["pixel_height"] = px_h
    out["legend"] = m["legend"]
    out["grid"] = m["grid"]
    out["raw_rows"] = m["raw_rows"]
    out["map_path"] = map_path
    out["json_path"] = json_path

    raw_spawn = j.get("spawn", [px_w * 0.5, px_h * 0.5])
    if isinstance(raw_spawn, (list, tuple)) and len(raw_spawn) >= 2:
        out["spawn"] = (float(raw_spawn[0]), float(raw_spawn[1]))
    else:
        out["spawn"] = (px_w * 0.5, px_h * 0.5)

    for key in ("zones", "exits", "enemies", "interactables", "triggers", "scenery"):
        val = j.get(key, [])
        out[key] = [x for x in val if isinstance(x, dict)] if isinstance(val, list) else []

    return out


def _infer_island_id(path: str) -> int:
    parent = os.path.basename(os.path.dirname(os.path.abspath(path)))
    return int(parent) if parent.isdigit() else 1


def tile_at_xy(region: Dict[str, Any], tx: int, ty: int) -> str:
    if tx < 0 or ty < 0 or tx >= region["width"] or ty >= region["height"]:
        return "void"
    return region["grid"][ty][tx]


def tile_at_px(region: Dict[str, Any], px: float, py: float) -> str:
    ts = region["tile_size"]
    tx = int(math.floor(px / ts))
    ty = int(math.floor(py / ts))
    return tile_at_xy(region, tx, ty)


def is_solid_tile(ttype: str, can_cross_pit: bool = False, can_cross_water: bool = False) -> bool:
    if ttype in WALKABLE_BASE_TILES:
        return False
    if ttype in ("pit", "phantom", "void"):
        return not can_cross_pit
    if ttype in ("water", "tide"):
        return not can_cross_water
    return True


def canonical_enemy_kind(raw_kind: str) -> str:
    k = str(raw_kind).strip().lower()
    return ENEMY_ALIASES.get(k, k)


def enemy_role(raw_kind: str) -> str:
    return ENEMY_ROLES.get(canonical_enemy_kind(raw_kind), "Pressure")


def get_door_type(it: Dict[str, Any]) -> str:
    raw_kind = str(it.get("kind", "door")).strip().lower()
    props = it.get("props", {}) or {}
    default_type = "switch_door"
    if raw_kind in ("ward_barrier", "wick_key", "boss_key", "combat_gate", "switch_door", "bridge_platform"):
        default_type = raw_kind
    elif raw_kind == "locked_door":
        default_type = "wick_key"
    elif raw_kind == "boss_door":
        default_type = "boss_key"
    raw_type = str(props.get("door_type", props.get("door_kind", default_type))).strip().lower()
    if raw_type in ("key_door", "locked_door"):
        door_type = "wick_key"
    elif raw_type == "boss_door":
        door_type = "boss_key"
    elif raw_type == "shutter":
        door_type = "switch_door"
    elif raw_type in ("shortcut_door", "bridge_of_light"):
        door_type = "ward_barrier"
    else:
        door_type = raw_type
    raw_key = str(props.get("key_kind", props.get("key_id", ""))).strip().lower()
    if raw_key == "keepers_flame":
        door_type = "boss_key"
    elif raw_key == "wick_key" and door_type == "switch_door":
        door_type = "wick_key"
    return door_type


def interactable_pos(it: Dict[str, Any]) -> Tuple[float, float]:
    p = it.get("pos", [0.0, 0.0])
    if isinstance(p, (list, tuple)) and len(p) >= 2:
        return (float(p[0]), float(p[1]))
    return (0.0, 0.0)


def interactable_size(it: Dict[str, Any], default: Tuple[float, float]) -> Tuple[float, float]:
    props = it.get("props", {}) or {}
    s = props.get("size", default)
    if isinstance(s, (list, tuple)) and len(s) >= 2:
        return (max(4.0, float(s[0])), max(4.0, float(s[1])))
    return default


def rect_from_center(cx: float, cy: float, w: float, h: float) -> Tuple[float, float, float, float]:
    return (cx - w * 0.5, cy - h * 0.5, cx + w * 0.5, cy + h * 0.5)


def rect_contains(rect: Tuple[float, float, float, float], x: float, y: float) -> bool:
    return rect[0] <= x <= rect[2] and rect[1] <= y <= rect[3]


def rect_grow(rect: Tuple[float, float, float, float], amt: float) -> Tuple[float, float, float, float]:
    return (rect[0] - amt, rect[1] - amt, rect[2] + amt, rect[3] + amt)


def rect_intersects(a: Tuple[float, float, float, float], b: Tuple[float, float, float, float]) -> bool:
    return not (a[2] <= b[0] or a[0] >= b[2] or a[3] <= b[1] or a[1] >= b[3])


def point_seg_dist(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> Tuple[float, float, float]:
    """Return (dist, closest_x, closest_y) from P to segment AB."""
    dx = bx - ax
    dy = by - ay
    l2 = dx * dx + dy * dy
    if l2 <= 1e-9:
        return (math.hypot(px - ax, py - ay), ax, ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
    cx = ax + dx * t
    cy = ay + dy * t
    return (math.hypot(px - cx, py - cy), cx, cy)


def is_puzzle_room(region: Dict[str, Any]) -> bool:
    """True if region contains puzzle mechanics (mirrors, transformers, portals, switches, phantom, tide)."""
    for row in region["grid"]:
        for t in row:
            if t in ("phantom", "tide", "glass", "mirror"):
                return True
    for it in region["interactables"]:
        k = str(it.get("kind", "")).strip().lower()
        if k in MIRROR_KINDS or k in SWITCH_KINDS or k in PORTAL_KINDS or k in TIDE_KINDS or k in ("phantom_platform", "phantom"):
            return True
        if k == "brazier":
            props = it.get("props", {}) or {}
            if props.get("target_id") or props.get("target_ids"):
                return True
    return False


# ---------------------------------------------------------------------------
# (a) Symmetry Score
# ---------------------------------------------------------------------------

def compute_symmetry(region: Dict[str, Any]) -> Dict[str, Any]:
    grid = region["grid"]
    w = region["width"]
    h = region["height"]
    if w == 0 or h == 0:
        return {"sym_h": 0.0, "sym_v": 0.0, "sym_max": 0.0, "flag": False}

    # Bounding box of non-void feature tiles
    min_x, max_x = w, -1
    min_y, max_y = h, -1
    for y in range(h):
        for x in range(w):
            if grid[y][x] in FEATURE_TILES:
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
                if y < min_y:
                    min_y = y
                if y > max_y:
                    max_y = y

    if max_x < min_x or max_y < min_y:
        return {"sym_h": 0.0, "sym_v": 0.0, "sym_max": 0.0, "flag": False}

    h_matches = 0
    h_total = 0
    v_matches = 0
    v_total = 0
    for y in range(min_y, max_y + 1):
        my = min_y + max_y - y
        row = grid[y]
        mrow = grid[my]
        for x in range(min_x, max_x + 1):
            mx = min_x + max_x - x
            t = row[x]
            th = row[mx]
            if t in FEATURE_TILES or th in FEATURE_TILES:
                h_total += 1
                if t == th:
                    h_matches += 1
            tv = mrow[x]
            if t in FEATURE_TILES or tv in FEATURE_TILES:
                v_total += 1
                if t == tv:
                    v_matches += 1

    sym_h = h_matches / h_total if h_total > 0 else 0.0
    sym_v = v_matches / v_total if v_total > 0 else 0.0
    sym_max = max(sym_h, sym_v)

    overworld_or_puzzle = (not region["is_dungeon"]) or is_puzzle_room(region)
    flagged = overworld_or_puzzle and sym_max > 0.72
    return {
        "sym_h": round(sym_h, 3),
        "sym_v": round(sym_v, 3),
        "sym_max": round(sym_max, 3),
        "flag": flagged,
    }


# ---------------------------------------------------------------------------
# (b) Hidden-Path / Phantom Critic
# ---------------------------------------------------------------------------

def audit_phantom(region: Dict[str, Any]) -> Dict[str, Any]:
    grid = region["grid"]
    w = region["width"]
    h = region["height"]
    p_tiles: List[Tuple[int, int]] = []
    p_set: Set[Tuple[int, int]] = set()
    for y in range(h):
        for x in range(w):
            if grid[y][x] == "phantom":
                p_tiles.append((x, y))
                p_set.add((x, y))

    if not p_tiles:
        return {
            "has_phantom": False,
            "count": 0,
            "winding_score": None,
            "center_offset": None,
            "has_3x3_block": False,
            "centered_waffle": False,
            "reason": "",
        }

    # Check for chunky solid >= 3x3 blocks (exact 3x3 solid OR dense >= 7/9 3x3 waffle)
    has_solid_3x3 = False
    has_dense_3x3 = False
    for y in range(h - 2):
        for x in range(w - 2):
            cnt = 0
            for dy in range(3):
                for dx in range(3):
                    if (x + dx, y + dy) in p_set:
                        cnt += 1
            if cnt == 9:
                has_solid_3x3 = True
                has_dense_3x3 = True
            elif cnt >= 7:
                has_dense_3x3 = True

    # Cluster phantom tiles with Chebyshev distance <= 2 so "P.P" / "PP.P" waffles group together
    unvisited = set(p_set)
    clusters: List[List[Tuple[int, int]]] = []
    while unvisited:
        start = next(iter(unvisited))
        q = deque([start])
        unvisited.remove(start)
        comp: List[Tuple[int, int]] = []
        while q:
            cx, cy = q.popleft()
            comp.append((cx, cy))
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    nxt = (cx + dx, cy + dy)
                    if nxt in unvisited:
                        unvisited.remove(nxt)
                        q.append(nxt)
        clusters.append(comp)

    # Evaluate winding score & center alignment per cluster (take worst/average weighted by size)
    winding_scores: List[Tuple[int, float, float, bool]] = []
    for comp in clusters:
        xs = [c[0] for c in comp]
        ys = [c[1] for c in comp]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)
        span_x = max_x - min_x + 1
        span_y = max_y - min_y + 1

        # Determine crossing direction: which opposite edges touch walkable floor
        horiz_touch = 0
        vert_touch = 0
        for cx, cy in comp:
            if cx == min_x and tile_at_xy(region, cx - 1, cy) in WALKABLE_BASE_TILES:
                horiz_touch += 1
            if cx == max_x and tile_at_xy(region, cx + 1, cy) in WALKABLE_BASE_TILES:
                horiz_touch += 1
            if cy == min_y and tile_at_xy(region, cx, cy - 1) in WALKABLE_BASE_TILES:
                vert_touch += 1
            if cy == max_y and tile_at_xy(region, cx, cy + 1) in WALKABLE_BASE_TILES:
                vert_touch += 1

        # Pick crossing axis (horizontal = spans left-to-right, slices by x)
        if horiz_touch > vert_touch:
            horiz = True
        elif vert_touch > horiz_touch:
            horiz = False
        else:
            horiz = span_x >= span_y

        slices: Dict[int, List[int]] = {}
        for cx, cy in comp:
            key = cx if horiz else cy
            val = cy if horiz else cx
            slices.setdefault(key, []).append(val)

        ordered_keys = sorted(slices.keys())
        centroids = [sum(slices[k]) / len(slices[k]) for k in ordered_keys]
        thicknesses = [len(slices[k]) for k in ordered_keys]
        avg_thick = sum(thicknesses) / len(thicknesses) if thicknesses else 1.0

        total_bend = sum(abs(centroids[i + 1] - centroids[i]) for i in range(len(centroids) - 1))
        perp_range = (max(centroids) - min(centroids)) if centroids else 0.0
        primary_span = max(1, len(ordered_keys))

        # Winding score in [0, 1]
        raw_wind = 0.6 * min(1.0, perp_range / 3.0) + 0.4 * min(1.0, total_bend / max(3.0, float(primary_span)))
        # Straight fat slabs (>= 3 thick with near-zero bend) have 0 winding
        if avg_thick >= 2.8 and perp_range < 0.75:
            raw_wind *= 0.25

        # Measure offset from room's middle axis (or zone's middle axis on overworld)
        ref_cx = (w - 1) * 0.5
        ref_cy = (h - 1) * 0.5
        ref_hw = max(1.0, w * 0.5)
        ref_hh = max(1.0, h * 0.5)
        mean_x = sum(xs) / len(xs)
        mean_y = sum(ys) / len(ys)
        if not region["is_dungeon"] and region["zones"]:
            ts = region["tile_size"]
            mx_px = (mean_x + 0.5) * ts
            my_px = (mean_y + 0.5) * ts
            for z in region["zones"]:
                zr = z.get("rect", [])
                if isinstance(zr, list) and len(zr) >= 4:
                    zx, zy, zw, zh = float(zr[0]), float(zr[1]), float(zr[2]), float(zr[3])
                    if zx <= mx_px <= zx + zw and zy <= my_px <= zy + zh and zw > 0 and zh > 0:
                        ref_cx = (zx + zw * 0.5) / ts - 0.5
                        ref_cy = (zy + zh * 0.5) / ts - 0.5
                        ref_hw = max(1.0, (zw / ts) * 0.5)
                        ref_hh = max(1.0, (zh / ts) * 0.5)
                        break

        if horiz:
            c_off = abs(mean_y - ref_cy) / ref_hh
        else:
            c_off = abs(mean_x - ref_cx) / ref_hw

        is_chunky_waffle = (span_x >= 3 and span_y >= 3 and len(comp) >= 6 and raw_wind < 0.25)
        winding_scores.append((len(comp), raw_wind, c_off, is_chunky_waffle))

    total_p = sum(item[0] for item in winding_scores)
    avg_winding = sum(item[0] * item[1] for item in winding_scores) / max(1, total_p)
    min_center_offset = min(item[2] for item in winding_scores)
    any_chunky_waffle = any(item[3] for item in winding_scores)

    reasons: List[str] = []
    if has_solid_3x3:
        reasons.append("solid >=3x3 phantom block")
    elif has_dense_3x3 or any_chunky_waffle:
        reasons.append("chunky >=3x3 waffle slab")
    if min_center_offset <= 0.24 and avg_winding < 0.25:
        reasons.append(f"centered on middle axis (offset={min_center_offset:.2f}, winding={avg_winding:.2f})")

    centered_waffle = bool(reasons)
    return {
        "has_phantom": True,
        "count": len(p_tiles),
        "winding_score": round(avg_winding, 3),
        "center_offset": round(min_center_offset, 3),
        "has_3x3_block": has_solid_3x3 or has_dense_3x3,
        "centered_waffle": centered_waffle,
        "reason": "; ".join(reasons),
    }


# ---------------------------------------------------------------------------
# (c) Dead-Stub, Broken-Wiring, Skippable Tide Gate, Stale Triggers & Reachability
# ---------------------------------------------------------------------------

def _build_reachability(region: Dict[str, Any]) -> Dict[str, Any]:
    """Tile-level BFS from spawn & exits noting doors/bridges/portals/dash/wings/lens/beam."""
    w = region["width"]
    h = region["height"]
    ts = region["tile_size"]
    grid = region["grid"]

    # Collect platform rects (tide_gate, bridge_platform, phantom_platform) and portal links
    bridge_tiles: Set[Tuple[int, int]] = set()
    tide_gate_tiles: Set[Tuple[int, int]] = set()
    phantom_plat_tiles: Set[Tuple[int, int]] = set()
    door_tiles: Set[Tuple[int, int]] = set()
    portals_by_id: Dict[str, Tuple[int, int]] = {}
    portal_pairs: List[Tuple[Tuple[int, int], Tuple[int, int]]] = []

    for it in region["interactables"]:
        k = str(it.get("kind", "")).strip().lower()
        px, py = interactable_pos(it)
        if k in PORTAL_KINDS:
            pid = str(it.get("id", ""))
            if pid:
                portals_by_id[pid] = (int(math.floor(px / ts)), int(math.floor(py / ts)))
        elif k in TIDE_KINDS:
            sw, sh = interactable_size(it, (32.0, 32.0))
            _mark_rect_tiles(tide_gate_tiles, px, py, sw, sh, ts, w, h)
        elif k in ("phantom_platform", "phantom"):
            sw, sh = interactable_size(it, (32.0, 16.0))
            _mark_rect_tiles(phantom_plat_tiles, px, py, sw, sh, ts, w, h)
        elif k in DOOR_KINDS:
            dtype = get_door_type(it)
            sw, sh = interactable_size(it, (32.0, 16.0))
            if dtype == "bridge_platform":
                _mark_rect_tiles(bridge_tiles, px, py, sw, sh, ts, w, h)
            else:
                _mark_rect_tiles(door_tiles, px, py, sw, sh, ts, w, h)

    for it in region["interactables"]:
        k = str(it.get("kind", "")).strip().lower()
        if k in PORTAL_KINDS:
            pid = str(it.get("id", ""))
            props = it.get("props", {}) or {}
            tpid = str(props.get("target_portal_id", "")).strip()
            if pid in portals_by_id and tpid in portals_by_id:
                portal_pairs.append((portals_by_id[pid], portals_by_id[tpid]))
            elif pid in portals_by_id and "dest_pos" in props:
                dp = props["dest_pos"]
                if isinstance(dp, list) and len(dp) >= 2:
                    portal_pairs.append((portals_by_id[pid], (int(math.floor(float(dp[0]) / ts)), int(math.floor(float(dp[1]) / ts)))))

    portal_adj: Dict[Tuple[int, int], List[Tuple[int, int]]] = {}
    for a, b in portal_pairs:
        portal_adj.setdefault(a, []).append(b)
        portal_adj.setdefault(b, []).append(a)

    def tile_traversable(tx: int, ty: int) -> Tuple[bool, str]:
        if tx < 0 or ty < 0 or tx >= w or ty >= h:
            return (False, "")
        tt = grid[ty][tx]
        if tt in WALKABLE_BASE_TILES:
            return (True, "doors" if (tx, ty) in door_tiles else "")
        if (tx, ty) in bridge_tiles:
            return (True, "bridges")
        if (tx, ty) in tide_gate_tiles:
            return (True, "tide")
        if tt == "phantom" or (tx, ty) in phantom_plat_tiles:
            return (True, "lens")
        if tt in ("bramble", "cracked"):
            return (True, "beam")
        return (False, "")

    def seed_tile(px: float, py: float) -> Optional[Tuple[int, int]]:
        tx = max(0, min(w - 1, int(math.floor(px / ts))))
        ty = max(0, min(h - 1, int(math.floor(py / ts))))
        ok, _ = tile_traversable(tx, ty)
        if ok:
            return (tx, ty)
        # Try nearby walkable tile within 2 tiles
        for r in (1, 2):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    ok2, _ = tile_traversable(tx + dx, ty + dy)
                    if ok2:
                        return (tx + dx, ty + dy)
        return None

    seeds: List[Tuple[int, int]] = []
    sp = seed_tile(region["spawn"][0], region["spawn"][1])
    if sp is not None:
        seeds.append(sp)
    for ex in region["exits"]:
        er = ex.get("rect", [])
        if isinstance(er, list) and len(er) >= 4:
            ecx = float(er[0]) + float(er[2]) * 0.5
            ecy = float(er[1]) + float(er[3]) * 0.5
            es = seed_tile(ecx, ecy)
            if es is not None and es not in seeds:
                seeds.append(es)

    reached: Set[Tuple[int, int]] = set(seeds)
    caps_used: Set[str] = set()
    q: deque[Tuple[int, int]] = deque(seeds)

    while q:
        cx, cy = q.popleft()
        # 4-neighbor walk (with doors/bridges/tide/lens/beam)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if (nx, ny) in reached:
                continue
            ok, cap = tile_traversable(nx, ny)
            if ok:
                reached.add((nx, ny))
                if cap:
                    caps_used.add(cap)
                q.append((nx, ny))
            else:
                # Dash/Wings jump across up to 4 tiles of pit/water/void/tide/phantom
                if 0 <= nx < w and 0 <= ny < h and grid[ny][nx] in ("pit", "water", "void", "tide", "phantom"):
                    for step in range(2, 6):
                        jx = cx + dx * step
                        jy = cy + dy * step
                        if jx < 0 or jy < 0 or jx >= w or jy >= h:
                            break
                        jt = grid[jy][jx]
                        if jt in ("wall", "glass", "mirror"):
                            break
                        jok, jcap = tile_traversable(jx, jy)
                        if jok:
                            if (jx, jy) not in reached:
                                reached.add((jx, jy))
                                caps_used.add("dash" if step <= 3 else "wings")
                                if jcap:
                                    caps_used.add(jcap)
                                q.append((jx, jy))
                            break
                        if jt not in ("pit", "water", "void", "tide", "phantom"):
                            break

        # Portal warps
        if (cx, cy) in portal_adj:
            for dest in portal_adj[(cx, cy)]:
                if dest not in reached:
                    reached.add(dest)
                    caps_used.add("portals")
                    q.append(dest)

    return {"reached": reached, "caps_used": sorted(caps_used), "seeds": seeds}


def _mark_rect_tiles(
    target: Set[Tuple[int, int]],
    cx: float,
    cy: float,
    sw: float,
    sh: float,
    ts: int,
    w: int,
    h: int,
) -> None:
    x0 = max(0, int(math.floor((cx - sw * 0.5 + 0.5) / ts)))
    x1 = min(w - 1, int(math.floor((cx + sw * 0.5 - 0.5) / ts)))
    y0 = max(0, int(math.floor((cy - sh * 0.5 + 0.5) / ts)))
    y1 = min(h - 1, int(math.floor((cy + sh * 0.5 - 0.5) / ts)))
    for ty in range(y0, y1 + 1):
        for tx in range(x0, x1 + 1):
            target.add((tx, ty))


def _clear_sight(region: Dict[str, Any], ax: float, ay: float, bx: float, by: float) -> bool:
    dist = math.hypot(bx - ax, by - ay)
    if dist <= 1.0:
        return True
    steps = max(1, int(math.ceil(dist / 4.0)))
    for i in range(1, steps):
        u = i / steps
        px = ax + (bx - ax) * u
        py = ay + (by - ay) * u
        if tile_at_px(region, px, py) in SIGHT_BLOCKING_TILES:
            return False
    return True


def _check_skippable_tide_gate(region: Dict[str, Any], it: Dict[str, Any]) -> Tuple[bool, str]:
    """Check if walkable non-tide tiles connect both sides of the tide channel within 2 tiles."""
    w = region["width"]
    h = region["height"]
    ts = region["tile_size"]
    grid = region["grid"]
    px, py = interactable_pos(it)
    sw, sh = interactable_size(it, (32.0, 32.0))

    tx0 = max(0, int(math.floor((px - sw * 0.5 + 0.5) / ts)))
    tx1 = min(w - 1, int(math.floor((px + sw * 0.5 - 0.5) / ts)))
    ty0 = max(0, int(math.floor((py - sh * 0.5 + 0.5) / ts)))
    ty1 = min(h - 1, int(math.floor((py + sh * 0.5 - 0.5) / ts)))

    # Collect walkable approach tiles on the 4 immediate outer edges of the tide gate
    west = [(tx0 - 1, y) for y in range(ty0, ty1 + 1) if tx0 - 1 >= 0 and grid[y][tx0 - 1] in WALKABLE_BASE_TILES]
    east = [(tx1 + 1, y) for y in range(ty0, ty1 + 1) if tx1 + 1 < w and grid[y][tx1 + 1] in WALKABLE_BASE_TILES]
    north = [(x, ty0 - 1) for x in range(tx0, tx1 + 1) if ty0 - 1 >= 0 and grid[ty0 - 1][x] in WALKABLE_BASE_TILES]
    south = [(x, ty1 + 1) for x in range(tx0, tx1 + 1) if ty1 + 1 < h and grid[ty1 + 1][x] in WALKABLE_BASE_TILES]

    # Decide crossing pair (west<->east or north<->south)
    pairs: List[Tuple[str, List[Tuple[int, int]], List[Tuple[int, int]]]] = []
    if west and east:
        pairs.append(("W-E", west, east))
    if north and south:
        pairs.append(("N-S", north, south))
    if not pairs:
        return (False, "")

    # Check if the tide gate footprint itself contains walkable non-tide tiles or bypass within 2 tiles
    win_x0 = max(0, tx0 - 2)
    win_x1 = min(w - 1, tx1 + 2)
    win_y0 = max(0, ty0 - 2)
    win_y1 = min(h - 1, ty1 + 2)

    for axis_name, side_a, side_b in pairs:
        target_set = set(side_b)
        vis = set(side_a)
        q = deque(side_a)
        bypass_found = False
        via_inside = False
        while q:
            cx, cy = q.popleft()
            if (cx, cy) in target_set:
                bypass_found = True
                break
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = cx + dx, cy + dy
                if nx < win_x0 or nx > win_x1 or ny < win_y0 or ny > win_y1:
                    continue
                if (nx, ny) in vis:
                    continue
                if grid[ny][nx] in WALKABLE_BASE_TILES:
                    if tx0 <= nx <= tx1 and ty0 <= ny <= ty1:
                        via_inside = True
                    vis.add((nx, ny))
                    q.append((nx, ny))
        if bypass_found:
            detail = (
                f"{axis_name} walkable non-tide tiles run right through tide_gate"
                if via_inside
                else f"{axis_name} walkable bypass within 2 tiles"
            )
            return (True, detail)

    return (False, "")


def audit_wiring_and_placement(region: Dict[str, Any]) -> Dict[str, Any]:
    issues: List[Dict[str, str]] = []
    ts = region["tile_size"]
    w = region["width"]
    h = region["height"]
    px_w = region["pixel_width"]
    px_h = region["pixel_height"]
    inters = region["interactables"]
    by_id = {str(it.get("id", "")): it for it in inters if str(it.get("id", ""))}

    # Track which switch IDs are referenced by doors/bridges via requires_signals
    referenced_signals: Set[str] = set()
    for it in inters:
        props = it.get("props", {}) or {}
        for key in ("requires_signals", "required_signals"):
            vals = props.get(key, [])
            if isinstance(vals, list):
                for s in vals:
                    if s:
                        referenced_signals.add(str(s))

    # 1. Switch wiring
    blue_switches = 0
    for it in inters:
        k = str(it.get("kind", "")).strip().lower()
        if k not in SWITCH_KINDS:
            continue
        iid = str(it.get("id", k))
        props = it.get("props", {}) or {}
        if bool(props.get("requires_prism", False)) or bool(props.get("requires_blue", False)):
            blue_switches += 1
        targets: List[str] = []
        t1 = str(props.get("target_id", "")).strip()
        if t1:
            targets.append(t1)
        tlist = props.get("target_ids", [])
        if isinstance(tlist, list):
            for t in tlist:
                ts_str = str(t).strip()
                if ts_str and ts_str not in targets:
                    targets.append(ts_str)
        if not targets:
            issues.append({
                "flag": "UNWIRED_SWITCH",
                "id": iid,
                "detail": f"switch_eye '{iid}' has no target_id or target_ids",
            })
        else:
            for tid in targets:
                if tid not in by_id:
                    issues.append({
                        "flag": "BROKEN_SWITCH_TARGET",
                        "id": iid,
                        "detail": f"switch_eye '{iid}' targets missing interactable '{tid}'",
                    })

    # 2. Dead mirrors / blue_transformers
    mirrors = [it for it in inters if str(it.get("kind", "")).strip().lower() in MIRROR_KINDS]
    blue_portals = [it for it in inters if str(it.get("kind", "")).strip().lower() in PORTAL_KINDS]
    shielded_or_boss = 0
    for e in region["enemies"]:
        ek = canonical_enemy_kind(str(e.get("kind", "")))
        ep = e.get("props", {}) or {}
        sh = float(e.get("shield_hp", ep.get("shield_hp", 0.0)) or 0.0)
        if sh > 0.0 or ek in SHIELDED_OR_BOSS_KINDS:
            shielded_or_boss += 1

    if mirrors and blue_switches == 0 and len(blue_portals) == 0 and shielded_or_boss == 0:
        for m in mirrors:
            mk = str(m.get("kind", "mirror")).strip().lower()
            mid = str(m.get("id", mk))
            flag = "DEAD_TRANSFORMER" if mk in ("blue_transformer", "transformer") else "DEAD_MIRROR"
            issues.append({
                "flag": flag,
                "id": mid,
                "detail": f"{mk} '{mid}' in room with 0 blue switches, 0 blue portals, and 0 shielded enemies/bosses",
            })

    # 3. Skippable tide gates
    for it in inters:
        k = str(it.get("kind", "")).strip().lower()
        if k in TIDE_KINDS:
            skippable, detail = _check_skippable_tide_gate(region, it)
            if skippable:
                iid = str(it.get("id", k))
                issues.append({
                    "flag": "SKIPPABLE_TIDE_GATE",
                    "id": iid,
                    "detail": f"tide_gate '{iid}': {detail}",
                })

    # 4. Stale triggers
    for trig in region["triggers"]:
        tid = str(trig.get("id", "trigger"))
        r = trig.get("rect", [])
        if not isinstance(r, list) or len(r) < 4:
            issues.append({"flag": "STALE_TRIGGER", "id": tid, "detail": f"trigger '{tid}' has invalid rect"})
            continue
        rx, ry, rw, rh = float(r[0]), float(r[1]), float(r[2]), float(r[3])
        if rw <= 0 or rh <= 0:
            issues.append({"flag": "STALE_TRIGGER", "id": tid, "detail": f"trigger '{tid}' has zero/negative area"})
            continue
        out_of_bounds = rx < 0 or ry < 0 or (rx + rw) > px_w or (ry + rh) > px_h
        tx0 = int(math.floor(rx / ts))
        tx1 = int(math.floor((rx + rw - 0.01) / ts))
        ty0 = int(math.floor(ry / ts))
        ty1 = int(math.floor((ry + rh - 0.01) / ts))
        bad_tiles = 0
        total_tiles = 0
        for ty in range(ty0, ty1 + 1):
            for tx in range(tx0, tx1 + 1):
                total_tiles += 1
                if tx < 0 or ty < 0 or tx >= w or ty >= h:
                    bad_tiles += 1
                else:
                    tt = region["grid"][ty][tx]
                    if tt in ("water", "void", "wall"):
                        bad_tiles += 1
        bad_ratio = bad_tiles / max(1, total_tiles)
        if out_of_bounds or bad_ratio > 0.5:
            reason = "outside map bounds" if out_of_bounds else f"{bad_ratio * 100:.0f}% on water/void/wall"
            issues.append({
                "flag": "STALE_TRIGGER",
                "id": tid,
                "detail": f"trigger '{tid}' ({reason})",
            })

    # 5. Solid-placed & unreachable interactables
    reach = _build_reachability(region)
    reached: Set[Tuple[int, int]] = reach["reached"]

    for it in inters:
        k = str(it.get("kind", "")).strip().lower()
        if k not in KEY_INTERACTABLES:
            continue
        iid = str(it.get("id", k))
        px, py = interactable_pos(it)
        tx = int(math.floor(px / ts))
        ty = int(math.floor(py / ts))
        tt = tile_at_xy(region, tx, ty)

        if tt in ("wall", "void"):
            issues.append({
                "flag": "INTERACTABLE_IN_SOLID",
                "id": iid,
                "detail": f"{k} '{iid}' at ({int(px)},{int(py)}) sits on {tt} tile ({tx},{ty})",
            })
            continue

        # Reachability check
        if k in SWITCH_KINDS:
            # Reachable if adjacent tile reached OR clear LOS within 118 px from a reached tile
            # (or if a mirror exists in the room and is within bounce reach)
            is_reach = any((tx + dx, ty + dy) in reached for dy in (-1, 0, 1) for dx in (-1, 0, 1))
            if not is_reach:
                for rx, ry in reached:
                    rpx = (rx + 0.5) * ts
                    rpy = (ry + 0.5) * ts
                    if math.hypot(rpx - px, rpy - py) <= BOLT_RANGE + 14.0:
                        if _clear_sight(region, rpx, rpy, px, py):
                            is_reach = True
                            break
            if not is_reach and mirrors:
                # Could be reached via mirror bounce; let solver verify exact solvability, check coarse bounce
                for m in mirrors:
                    mx, my = interactable_pos(m)
                    if math.hypot(mx - px, my - py) <= BOLT_RANGE + 18.0:
                        is_reach = True
                        break
        else:
            # Walk-to interactable: its tile or an adjacent tile (within ~1 tile / 24px interact reach)
            is_reach = (tx, ty) in reached or any(
                (tx + dx, ty + dy) in reached
                for dy in (-1, 0, 1)
                for dx in (-1, 0, 1)
                if abs(dx) + abs(dy) <= 1
            )

        if not is_reach:
            issues.append({
                "flag": "UNREACHABLE_INTERACTABLE",
                "id": iid,
                "detail": f"{k} '{iid}' at ({int(px)},{int(py)}) is unreachable from spawn/exits",
            })

    return {
        "issues": issues,
        "reach_caps_used": reach["caps_used"],
        "reached_tile_count": len(reached),
    }


# ---------------------------------------------------------------------------
# (d) State-Space Optical Puzzle Solver (Blue Transformer / Mirror / Switch / Portal)
# ---------------------------------------------------------------------------

def _angle_to_normal(deg: float) -> Tuple[float, float]:
    rad = math.radians(deg)
    return (math.cos(rad), math.sin(rad))


def _reflect_vec(dx: float, dy: float, nx: float, ny: float, double_sided: bool = True) -> Optional[Tuple[float, float]]:
    dot = dx * nx + dy * ny
    if dot > 0.0:
        if not double_sided:
            return None
        nx, ny = -nx, -ny
        dot = -dot
    rx = dx - 2.0 * dot * nx
    ry = dy - 2.0 * dot * ny
    ln = math.hypot(rx, ry)
    if ln <= 1e-6:
        return None
    return (rx / ln, ry / ln)


def _ray_exit_rect(ox: float, oy: float, dx: float, dy: float, rect: Tuple[float, float, float, float]) -> float:
    t_max = float("inf")
    if abs(dx) > 1e-4:
        tx = (rect[2] - ox) / dx if dx > 0 else (rect[0] - ox) / dx
        if tx >= 0.0:
            t_max = min(t_max, tx)
    if abs(dy) > 1e-4:
        ty = (rect[3] - oy) / dy if dy > 0 else (rect[1] - oy) / dy
        if ty >= 0.0:
            t_max = min(t_max, ty)
    return 2.0 if math.isinf(t_max) else t_max


def _ray_enter_rect_normal(ax: float, ay: float, bx: float, by: float, rect: Tuple[float, float, float, float]) -> Tuple[float, float, float, float]:
    """Return (hit_x, hit_y, nx, ny) matching prism.gd _ray_enter_rect."""
    dx = bx - ax
    dy = by - ay
    t_min = 0.0
    t_max = 1.0
    hnx, hny = 0.0, 0.0

    if abs(dx) > 1e-4:
        inv_x = 1.0 / dx
        tx1 = (rect[0] - ax) * inv_x
        tx2 = (rect[2] - ax) * inv_x
        nx = -1.0 if dx > 0 else 1.0
        if tx1 > tx2:
            tx1, tx2 = tx2, tx1
        if tx1 > t_min:
            t_min = tx1
            hnx, hny = nx, 0.0
        t_max = min(t_max, tx2)

    if abs(dy) > 1e-4:
        inv_y = 1.0 / dy
        ty1 = (rect[1] - ay) * inv_y
        ty2 = (rect[3] - ay) * inv_y
        ny = -1.0 if dy > 0 else 1.0
        if ty1 > ty2:
            ty1, ty2 = ty2, ty1
        if ty1 > t_min:
            t_min = ty1
            hnx, hny = 0.0, ny
        t_max = min(t_max, ty2)

    if hnx == 0.0 and hny == 0.0:
        cx = (rect[0] + rect[2]) * 0.5
        cy = (rect[1] + rect[3]) * 0.5
        rx = ax - cx
        ry = ay - cy
        if abs(rx) >= abs(ry):
            hnx = (1.0 if rx > 0 else -1.0) if abs(rx) > 0.01 else (-1.0 if dx > 0 else 1.0)
            hny = 0.0
        else:
            hnx = 0.0
            hny = (1.0 if ry > 0 else -1.0) if abs(ry) > 0.01 else (-1.0 if dy > 0 else 1.0)
        return (ax, ay, hnx, hny)

    u = max(0.0, min(1.0, t_min))
    return (ax + dx * u, ay + dy * u, hnx, hny)


class OpticalPuzzleSolver:
    """Exact Luxel state-space solver for Blue Transformer / Mirror / Switch / Portal rooms."""

    def __init__(self, region: Dict[str, Any]) -> None:
        self.region = region
        self.ts = region["tile_size"]
        self.w = region["width"]
        self.h = region["height"]
        self.grid = region["grid"]

        self.mirrors: List[Dict[str, Any]] = []
        self.switches: List[Dict[str, Any]] = []
        self.portals: List[Dict[str, Any]] = []
        self.doors: List[Dict[str, Any]] = []
        self.braziers: List[Dict[str, Any]] = []
        self.solid_static_rects: List[Tuple[str, Tuple[float, float, float, float]]] = []
        self.tide_rects: List[Tuple[float, float, float, float]] = []

        self._parse_entities()

    def _parse_entities(self) -> None:
        for it in self.region["interactables"]:
            k = str(it.get("kind", "")).strip().lower()
            iid = str(it.get("id", k))
            px, py = interactable_pos(it)
            props = it.get("props", {}) or {}

            if k in MIRROR_KINDS:
                is_tf = k in ("blue_transformer", "transformer")
                sw, sh = interactable_size(it, (16.0, 16.0))
                angle_deg = float(props.get("angle_deg", 45.0))
                if "normal" in props and isinstance(props["normal"], list) and len(props["normal"]) >= 2:
                    nx, ny = float(props["normal"][0]), float(props["normal"][1])
                    if abs(nx) + abs(ny) > 1e-4:
                        angle_deg = math.degrees(math.atan2(ny, nx))
                self.mirrors.append({
                    "id": iid,
                    "kind": "blue_transformer" if is_tf else "mirror",
                    "origin": (px, py),
                    "size": (sw, sh),
                    "radius": max(sw, sh) * 0.5,
                    "angle_deg": angle_deg % 360.0,
                    "angle_step": float(props.get("angle_step_deg", 45.0)),
                    "movable": bool(props.get("movable", is_tf)),
                    "rotatable": bool(props.get("rotatable", is_tf)),
                    "double_sided": bool(props.get("double_sided", True)),
                    "transforms_to": str(props.get("transforms_to", "blue")).strip().lower() or "blue",
                })
            elif k in SWITCH_KINDS:
                req_blue = bool(props.get("requires_prism", False)) or bool(props.get("requires_blue", False))
                targets: List[str] = []
                if props.get("target_id"):
                    targets.append(str(props["target_id"]).strip())
                if isinstance(props.get("target_ids"), list):
                    for t in props["target_ids"]:
                        ts_s = str(t).strip()
                        if ts_s and ts_s not in targets:
                            targets.append(ts_s)
                self.switches.append({
                    "id": iid,
                    "pos": (px, py),
                    "radius": float(it.get("radius", props.get("radius", 14.0))),
                    "requires_blue": req_blue,
                    "targets": targets,
                    "starts_active": bool(props.get("activated", False)),
                })
            elif k in PORTAL_KINDS:
                self.portals.append({
                    "id": iid,
                    "pos": (px, py),
                    "radius": max(10.0, float(it.get("radius", props.get("radius", 11.0)))),
                    "requires_blue": bool(props.get("requires_blue", True)),
                    "pair_sync": bool(props.get("pair_sync", True)),
                    "target_portal_id": str(props.get("target_portal_id", "")).strip(),
                    "dest_pos": tuple(float(v) for v in props["dest_pos"][:2]) if isinstance(props.get("dest_pos"), list) and len(props["dest_pos"]) >= 2 else None,
                    "starts_powered": bool(props.get("starts_powered", props.get("powered", False))),
                })
            elif k in DOOR_KINDS:
                dtype = get_door_type(it)
                sw, sh = interactable_size(it, (32.0, 16.0))
                req_sigs = [str(s) for s in (props.get("requires_signals", props.get("required_signals", [])) or []) if s]
                req_cnt = max(1, int(props.get("required_count", max(1, len(req_sigs)))))
                starts_open = bool(props.get("opened", props.get("starts_open", False)))
                # Non-switch doors (e.g. key doors in the middle of a room like lighthouse_r7)
                # are unlocked during normal dungeon play before solving the room puzzle
                if dtype not in ("switch_door", "bridge_platform"):
                    starts_open = True
                self.doors.append({
                    "id": iid,
                    "door_type": dtype,
                    "pos": (px, py),
                    "size": (sw, sh),
                    "rect": rect_from_center(px, py, sw, sh),
                    "requires_signals": req_sigs,
                    "required_count": req_cnt,
                    "starts_open": starts_open,
                })
            elif k == "brazier":
                targets = []
                if props.get("target_id"):
                    targets.append(str(props["target_id"]).strip())
                if isinstance(props.get("target_ids"), list):
                    for t in props["target_ids"]:
                        ts_s = str(t).strip()
                        if ts_s and ts_s not in targets:
                            targets.append(ts_s)
                if targets:
                    self.braziers.append({"id": iid, "pos": (px, py), "targets": targets})
            elif k in TIDE_KINDS:
                sw, sh = interactable_size(it, (32.0, 32.0))
                self.tide_rects.append(rect_from_center(px, py, sw, sh))
            elif k in ("cracked_wall", "cracked", "bramble", "obsidian_seal", "seal"):
                # Destructible walls (like cracked_spire_r2) can be cleared by the player
                pass

        # Map portal pairing indices
        pid_to_idx = {p["id"]: i for i, p in enumerate(self.portals)}
        for p in self.portals:
            p["pair_idx"] = pid_to_idx.get(p["target_portal_id"], -1)

    def is_applicable(self) -> bool:
        has_blue_target = any(s["requires_blue"] for s in self.switches) or bool(self.portals)
        has_mirror_puzzle = bool(self.mirrors) and (bool(self.switches) or bool(self.portals))
        return has_blue_target or has_mirror_puzzle

    def _tile_supported(self, px: float, py: float, doors_mask: int) -> bool:
        for di, d in enumerate(self.doors):
            if d["door_type"] == "bridge_platform" and ((doors_mask >> di) & 1):
                if rect_contains(d["rect"], px, py):
                    return True
        for tr in self.tide_rects:
            if rect_contains(tr, px, py):
                return True
        return False

    def _can_place_rect(
        self,
        cx: float,
        cy: float,
        sw: float,
        sh: float,
        ignore_mirror_idx: int,
        mirror_positions: Sequence[Tuple[float, float]],
        doors_mask: int,
    ) -> bool:
        iw = max(8.0, sw - 2.0)
        ih = max(8.0, sh - 2.0)
        rect = rect_from_center(cx, cy, iw, ih)
        if rect[0] < 0 or rect[1] < 0 or rect[2] > self.w * self.ts or rect[3] > self.h * self.ts:
            return False
        eps = 0.25
        x0, x1 = rect[0] + eps, rect[2] - eps
        y0, y1 = rect[1] + eps, rect[3] - eps
        xm, ym = (x0 + x1) * 0.5, (y0 + y1) * 0.5
        for sx, sy in (
            (x0, y0), (xm, y0), (x1, y0),
            (x0, ym), (xm, ym), (x1, ym),
            (x0, y1), (xm, y1), (x1, y1),
        ):
            tt = tile_at_px(self.region, sx, sy)
            if is_solid_tile(tt, False, False) and not self._tile_supported(sx, sy, doors_mask):
                return False
        # Solid closed doors & other mirrors
        for di, d in enumerate(self.doors):
            if d["door_type"] != "bridge_platform" and not ((doors_mask >> di) & 1):
                if rect_intersects(rect, d["rect"]):
                    return False
        for mi, m in enumerate(self.mirrors):
            if mi == ignore_mirror_idx:
                continue
            mx, my = mirror_positions[mi]
            mrect = rect_from_center(mx, my, m["size"][0], m["size"][1])
            if rect_intersects(rect, mrect):
                return False
        return True

    def _is_walkable_tile(
        self,
        tx: int,
        ty: int,
        doors_mask: int,
        mirror_positions: Sequence[Tuple[float, float]],
    ) -> bool:
        if tx < 0 or ty < 0 or tx >= self.w or ty >= self.h:
            return False
        cx = (tx + 0.5) * self.ts
        cy = (ty + 0.5) * self.ts
        tt = self.grid[ty][tx]
        if tt not in WALKABLE_BASE_TILES:
            if not self._tile_supported(cx, cy, doors_mask):
                if tt not in ("bramble", "cracked", "phantom"):
                    return False
        # Closed doors block walking
        for di, d in enumerate(self.doors):
            if d["door_type"] != "bridge_platform" and not ((doors_mask >> di) & 1):
                if rect_contains(d["rect"], cx, cy):
                    return False
        # Mirrors occupy their tile
        for mi, m in enumerate(self.mirrors):
            mx, my = mirror_positions[mi]
            mrect = rect_from_center(mx, my, m["size"][0] - 2.0, m["size"][1] - 2.0)
            if rect_contains(mrect, cx, cy):
                return False
        return True

    def _reachable_tiles(
        self,
        doors_mask: int,
        portals_mask: int,
        mirror_positions: Sequence[Tuple[float, float]],
    ) -> Tuple[Set[Tuple[int, int]], Set[Tuple[int, int]]]:
        """Return (reached_no_warp, reached_with_warp) tile sets from spawn."""
        spx, spy = self.region["spawn"]
        stx = max(0, min(self.w - 1, int(math.floor(spx / self.ts))))
        sty = max(0, min(self.h - 1, int(math.floor(spy / self.ts))))
        seeds: List[Tuple[int, int]] = []
        if self._is_walkable_tile(stx, sty, doors_mask, mirror_positions):
            seeds.append((stx, sty))
        else:
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if self._is_walkable_tile(stx + dx, sty + dy, doors_mask, mirror_positions):
                        seeds.append((stx + dx, sty + dy))
                        break

        def bfs(start_tiles: Iterable[Tuple[int, int]], allow_warps: bool) -> Set[Tuple[int, int]]:
            vis: Set[Tuple[int, int]] = set(start_tiles)
            q: deque[Tuple[int, int]] = deque(start_tiles)
            portal_tiles: Dict[Tuple[int, int], List[Tuple[int, int]]] = {}
            if allow_warps:
                for pi, p in enumerate(self.portals):
                    if not ((portals_mask >> pi) & 1):
                        continue
                    ptx = int(math.floor(p["pos"][0] / self.ts))
                    pty = int(math.floor(p["pos"][1] / self.ts))
                    dest_pos = None
                    if p["pair_idx"] >= 0:
                        dest_pos = self.portals[p["pair_idx"]]["pos"]
                    elif p["dest_pos"] is not None:
                        dest_pos = p["dest_pos"]
                    if dest_pos is not None:
                        dtx = int(math.floor(dest_pos[0] / self.ts))
                        dty = int(math.floor(dest_pos[1] / self.ts))
                        portal_tiles.setdefault((ptx, pty), []).append((dtx, dty))
            while q:
                cx, cy = q.popleft()
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if (nx, ny) not in vis and self._is_walkable_tile(nx, ny, doors_mask, mirror_positions):
                        vis.add((nx, ny))
                        q.append((nx, ny))
                if allow_warps and (cx, cy) in portal_tiles:
                    for dest in portal_tiles[(cx, cy)]:
                        if dest not in vis:
                            vis.add(dest)
                            q.append(dest)
            return vis

        no_warp = bfs(seeds, False)
        with_warp = bfs(no_warp, True) if portals_mask else no_warp
        return (no_warp, with_warp)

    def _simulate_bolt(
        self,
        shooter_x: float,
        shooter_y: float,
        aim_dx: float,
        aim_dy: float,
        mirror_positions: Sequence[Tuple[float, float]],
        mirror_angles: Sequence[float],
        doors_mask: int,
        skip_mirrors: Set[int],
    ) -> Optional[Tuple[str, int, int, bool, Tuple[int, ...]]]:
        """Simulate one Light Bolt from (shooter_x, shooter_y) along (aim_dx, aim_dy).

        Returns (hit_kind, idx, bounces_used, is_blue, bounced_mirror_indices) if it activates
        a switch_eye or blue_portal, else None.
        """
        ln = math.hypot(aim_dx, aim_dy)
        if ln <= 1e-6:
            return None
        dx, dy = aim_dx / ln, aim_dy / ln
        px = shooter_x + dx * 6.0
        py = shooter_y + dy * 6.0
        dist = 0.0
        max_range = BOLT_RANGE
        bounces_left = BOLT_MAX_BOUNCES
        bounce_count = 0
        is_blue = False
        hit_ids: Set[str] = set()
        bounced_mirrors: List[int] = []

        # Precompute active mirror rects & normals
        m_info: List[Tuple[int, str, float, float, float, Tuple[float, float, float, float], float, float, bool, str]] = []
        for mi, m in enumerate(self.mirrors):
            if mi in skip_mirrors:
                continue
            mx, my = mirror_positions[mi]
            nx, ny = _angle_to_normal(mirror_angles[mi])
            mrect = rect_from_center(mx, my, m["size"][0], m["size"][1])
            m_info.append((mi, m["id"], mx, my, m["radius"], mrect, nx, ny, m["double_sided"], m["transforms_to"]))

        max_steps = int(((BOLT_MAX_BOUNCES + 1) * BOLT_RANGE) / BOLT_STEP_PX) + 12
        for _ in range(max_steps):
            nxp = px + dx * BOLT_STEP_PX
            nyp = py + dy * BOLT_STEP_PX
            reflected = False

            # 1. Mirrors / Transformers
            if bounces_left > 0:
                best_m = None
                best_d = float("inf")
                for item in m_info:
                    mi, mid, mx, my, mrad, mrect, mnx, mny, dside, tcol = item
                    if mid in hit_ids:
                        continue
                    d_seg, cpx, cpy = point_seg_dist(mx, my, px, py, nxp, nyp)
                    grown = rect_grow(mrect, 1.5)
                    mid_x, mid_y = (px + nxp) * 0.5, (py + nyp) * 0.5
                    if d_seg <= mrad + 2.0 or rect_contains(grown, nxp, nyp) or rect_contains(grown, mid_x, mid_y):
                        d_from_p = math.hypot(mx - px, my - py)
                        if d_from_p < best_d:
                            best_d = d_from_p
                            best_m = (item, cpx, cpy)

                if best_m is not None:
                    item, cpx, cpy = best_m
                    mi, mid, mx, my, mrad, mrect, mnx, mny, dside, tcol = item
                    rvec = _reflect_vec(dx, dy, mnx, mny, dside)
                    if rvec is None:
                        return None
                    # Compute mirror plane hit point (matching prism.gd _mirror_plane_hit)
                    denom = dx * mnx + dy * mny
                    rpos_x, rpos_y = cpx, cpy
                    if abs(denom) > 1e-4:
                        t_pl = ((mx - px) * mnx + (my - py) * mny) / denom
                        if t_pl >= 0.0:
                            plx = px + dx * t_pl
                            ply = py + dy * t_pl
                            if rect_contains(rect_grow(mrect, 2.5), plx, ply):
                                rpos_x, rpos_y = plx, ply
                    rdx, rdy = rvec
                    grown_exit = rect_grow(mrect, 0.5)
                    if rect_contains(grown_exit, rpos_x, rpos_y):
                        t_ex = _ray_exit_rect(rpos_x, rpos_y, rdx, rdy, grown_exit)
                        px = rpos_x + rdx * (t_ex + 1.5)
                        py = rpos_y + rdy * (t_ex + 1.5)
                    else:
                        px = rpos_x + rdx * 2.0
                        py = rpos_y + rdy * 2.0
                    dx, dy = rdx, rdy
                    bounces_left -= 1
                    bounce_count += 1
                    is_blue = (tcol == "blue")
                    dist = 0.0
                    max_range = BOLT_RANGE
                    hit_ids = {mid}
                    bounced_mirrors.append(mi)
                    reflected = True
                    continue

            # 2. Switches & Portals
            for si, sw in enumerate(self.switches):
                if sw["id"] in hit_ids:
                    continue
                sx, sy = sw["pos"]
                d_seg, _, _ = point_seg_dist(sx, sy, px, py, nxp, nyp)
                if d_seg <= sw["radius"] + 2.0:
                    if sw["requires_blue"] and not is_blue:
                        return None
                    return ("switch", si, bounce_count, is_blue, tuple(bounced_mirrors))

            for pi, po in enumerate(self.portals):
                if po["id"] in hit_ids:
                    continue
                pox, poy = po["pos"]
                d_seg, _, _ = point_seg_dist(pox, poy, px, py, nxp, nyp)
                if d_seg <= po["radius"] + 2.0:
                    if po["requires_blue"] and not is_blue:
                        return None
                    return ("portal", pi, bounce_count, is_blue, tuple(bounced_mirrors))

            # Closed solid doors block shots
            for di, d in enumerate(self.doors):
                if d["door_type"] != "bridge_platform" and not ((doors_mask >> di) & 1):
                    if rect_contains(d["rect"], nxp, nyp):
                        return None

            # 3. World glass / mirror tile reflection
            tt = tile_at_px(self.region, nxp, nyp)
            if tt in ("glass", "mirror") and bounces_left > 0:
                tx = int(math.floor(nxp / self.ts))
                ty = int(math.floor(nyp / self.ts))
                trect = (tx * self.ts, ty * self.ts, (tx + 1) * self.ts, (ty + 1) * self.ts)
                hx, hy, gnx, gny = _ray_enter_rect_normal(px, py, nxp, nyp, trect)
                rvec = _reflect_vec(dx, dy, gnx, gny, True)
                if rvec is None:
                    return None
                rdx, rdy = rvec
                ex, ey = hx + rdx * 2.0, hy + rdy * 2.0
                if rect_contains(rect_grow(trect, 0.5), ex, ey):
                    ex, ey = hx + gnx * 2.0, hy + gny * 2.0
                px, py = ex, ey
                dx, dy = rdx, rdy
                bounces_left -= 1
                bounce_count += 1
                is_blue = True
                dist = 0.0
                max_range = BOLT_RANGE
                hit_ids = set()
                reflected = True
                continue

            # 4. Wall or max range
            if not reflected:
                if tt in SIGHT_BLOCKING_TILES:
                    return None
                dist += BOLT_STEP_PX
                if dist >= max_range:
                    return None
                px, py = nxp, nyp

        return None

    def _find_best_shot(
        self,
        target_kind: str,
        target_idx: int,
        reached_no_warp: Set[Tuple[int, int]],
        reached_with_warp: Set[Tuple[int, int]],
        mirror_positions: Sequence[Tuple[float, float]],
        mirror_angles: Sequence[float],
        doors_mask: int,
        skip_mirrors: Set[int],
        allow_direct_yellow: bool = True,
    ) -> Optional[Tuple[int, int, bool, Tuple[int, ...]]]:
        """Find minimum (bounces, warp_needed, is_blue, mirrors_used) shot hitting target."""
        if target_kind == "switch":
            tpos = self.switches[target_idx]["pos"]
            req_blue = self.switches[target_idx]["requires_blue"]
        else:
            tpos = self.portals[target_idx]["pos"]
            req_blue = self.portals[target_idx]["requires_blue"]

        tx_f, ty_f = tpos
        best: Optional[Tuple[int, int, bool, Tuple[int, ...]]] = None

        def try_shot(sx: float, sy: float, adx: float, ady: float, tile_xy: Tuple[int, int]) -> None:
            nonlocal best
            warp_cost = 0 if tile_xy in reached_no_warp else 1
            res = self._simulate_bolt(
                sx, sy, adx, ady,
                mirror_positions, mirror_angles, doors_mask, skip_mirrors,
            )
            if res is None:
                return
            hk, hi, b_cnt, is_bl, m_used = res
            if hk != target_kind or hi != target_idx:
                return
            if not allow_direct_yellow and b_cnt == 0:
                return
            cand = (b_cnt, warp_cost, is_bl, m_used)
            if best is None or (cand[0] + cand[1], cand[0]) < (best[0] + best[1], best[0]):
                best = cand

        # 0-bounce direct shot (only if target doesn't require blue)
        if allow_direct_yellow and not req_blue:
            for rtx, rty in reached_with_warp:
                sx = (rtx + 0.5) * self.ts
                sy = (rty + 0.5) * self.ts
                if math.hypot(tx_f - sx, ty_f - sy) <= BOLT_RANGE + 20.0:
                    try_shot(sx, sy, tx_f - sx, ty_f - sy, (rtx, rty))
                    if best is not None and best[0] == 0 and best[1] == 0:
                        return best

        # 1-bounce shot via each active mirror M1 (exact reverse reflection)
        active_mirrors = [i for i in range(len(self.mirrors)) if i not in skip_mirrors]
        for m1 in active_mirrors:
            m1x, m1y = mirror_positions[m1]
            d_m1_t = math.hypot(tx_f - m1x, ty_f - m1y)
            if d_m1_t > BOLT_RANGE + 24.0 or d_m1_t < 1.0:
                continue
            out_dx = (tx_f - m1x) / d_m1_t
            out_dy = (ty_f - m1y) / d_m1_t
            nx1, ny1 = _angle_to_normal(mirror_angles[m1])
            # By optical reversibility, incoming dir to reflect to out_dir is reflect(-out_dir, n) reversed
            rev = _reflect_vec(-out_dx, -out_dy, nx1, ny1, self.mirrors[m1]["double_sided"])
            if rev is None:
                continue
            in_dx, in_dy = -rev[0], -rev[1]
            # Sample candidate shooter positions along m1 - in_dir * t
            for dist_t in range(14, int(BOLT_RANGE) + 12, 8):
                sx = m1x - in_dx * dist_t
                sy = m1y - in_dy * dist_t
                st = (int(math.floor(sx / self.ts)), int(math.floor(sy / self.ts)))
                if st in reached_with_warp:
                    # Try exact point on ray AND tile center
                    try_shot(sx, sy, in_dx, in_dy, st)
                    tcx, tcy = (st[0] + 0.5) * self.ts, (st[1] + 0.5) * self.ts
                    try_shot(tcx, tcy, m1x - tcx, m1y - tcy, st)
                    if best is not None and best[0] <= 1 and best[1] == 0:
                        break

        if best is not None and best[0] <= 1 and best[1] == 0:
            return best

        # 2-bounce shot via (M1 -> M2 -> T)
        for m2 in active_mirrors:
            m2x, m2y = mirror_positions[m2]
            d_m2_t = math.hypot(tx_f - m2x, ty_f - m2y)
            if d_m2_t > BOLT_RANGE + 24.0 or d_m2_t < 1.0:
                continue
            out2_dx = (tx_f - m2x) / d_m2_t
            out2_dy = (ty_f - m2y) / d_m2_t
            nx2, ny2 = _angle_to_normal(mirror_angles[m2])
            for m1 in active_mirrors:
                if m1 == m2:
                    continue
                m1x, m1y = mirror_positions[m1]
                d_m1_m2 = math.hypot(m2x - m1x, m2y - m1y)
                if d_m1_m2 > BOLT_RANGE + 20.0 or d_m1_m2 < 8.0:
                    continue
                leg_dx = (m2x - m1x) / d_m1_m2
                leg_dy = (m2y - m1y) / d_m1_m2
                # Check if leg bouncing off M2 points toward T
                ref2 = _reflect_vec(leg_dx, leg_dy, nx2, ny2, self.mirrors[m2]["double_sided"])
                if ref2 is None:
                    continue
                if ref2[0] * out2_dx + ref2[1] * out2_dy < 0.88:
                    continue
                nx1, ny1 = _angle_to_normal(mirror_angles[m1])
                rev1 = _reflect_vec(-leg_dx, -leg_dy, nx1, ny1, self.mirrors[m1]["double_sided"])
                if rev1 is None:
                    continue
                in0_dx, in0_dy = -rev1[0], -rev1[1]
                for dist_t in range(14, int(BOLT_RANGE) + 12, 10):
                    sx = m1x - in0_dx * dist_t
                    sy = m1y - in0_dy * dist_t
                    st = (int(math.floor(sx / self.ts)), int(math.floor(sy / self.ts)))
                    if st in reached_with_warp:
                        try_shot(sx, sy, in0_dx, in0_dy, st)
                        if best is not None and best[0] <= 2 and best[1] == 0:
                            break

        return best

    def _compute_push_candidates(
        self,
        mi: int,
        doors_mask: int,
        mirror_positions: Sequence[Tuple[float, float]],
        reached: Set[Tuple[int, int]],
    ) -> Dict[Tuple[float, float], int]:
        """BFS over 16px cardinal push/pull grid positions for movable mirror mi.

        Returns map of { (px, py) -> min_push_segments } filtered to optically relevant spots.
        """
        m = self.mirrors[mi]
        ox, oy = mirror_positions[mi]
        sw, sh = m["size"]
        # Check if Wick can currently reach an adjacent side of the mirror to grab it
        mtx = int(math.floor(ox / self.ts))
        mty = int(math.floor(oy / self.ts))
        if not any((mtx + dx, mty + dy) in reached for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            return {(ox, oy): 0}

        # Bounding radius around puzzle entities so overworld BFS stays fast and focused
        interest_pts = [s["pos"] for s in self.switches] + [p["pos"] for p in self.portals] + [
            mirror_positions[j] for j in range(len(self.mirrors))
        ]
        min_x = min(p[0] for p in interest_pts) - BOLT_RANGE - 32.0
        max_x = max(p[0] for p in interest_pts) + BOLT_RANGE + 32.0
        min_y = min(p[1] for p in interest_pts) - BOLT_RANGE - 32.0
        max_y = max(p[1] for p in interest_pts) + BOLT_RANGE + 32.0

        # Dijkstra on (pos_x, pos_y, last_dir_idx) counting directional push segments
        # Start with dir=-1 (0 pushes)
        best_pos_cost: Dict[Tuple[float, float], int] = {(ox, oy): 0}
        dist_state: Dict[Tuple[float, float, int], int] = {(ox, oy, -1): 0}
        pq: List[Tuple[int, float, float, int]] = [(0, ox, oy, -1)]
        dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))

        while pq:
            cost, cx, cy, last_d = heapq.heappop(pq)
            if cost > dist_state.get((cx, cy, last_d), 999):
                continue
            if cost >= 5:
                continue
            for di_idx, (ddx, ddy) in enumerate(dirs):
                nx = cx + ddx * self.ts
                ny = cy + ddy * self.ts
                if nx < min_x or nx > max_x or ny < min_y or ny > max_y:
                    continue
                if not self._can_place_rect(nx, ny, sw, sh, mi, mirror_positions, doors_mask):
                    continue
                # Check Wick can stand on either pushing or pulling side along this axis
                push_side = (int(math.floor((cx - ddx * self.ts) / self.ts)), int(math.floor((cy - ddy * self.ts) / self.ts)))
                pull_side = (int(math.floor((nx + ddx * self.ts) / self.ts)), int(math.floor((ny + ddy * self.ts) / self.ts)))
                push_ok = self._is_walkable_tile(push_side[0], push_side[1], doors_mask, mirror_positions)
                pull_ok = self._is_walkable_tile(pull_side[0], pull_side[1], doors_mask, mirror_positions)
                if not (push_ok or pull_ok):
                    continue
                ncost = cost if last_d == di_idx else cost + 1
                st_key = (nx, ny, di_idx)
                if ncost < dist_state.get(st_key, 999):
                    dist_state[st_key] = ncost
                    if ncost < best_pos_cost.get((nx, ny), 999):
                        best_pos_cost[(nx, ny)] = ncost
                    heapq.heappush(pq, (ncost, nx, ny, di_idx))

        # Filter to optically useful positions: aligned with a switch/portal/other mirror
        # on a 45-degree cardinal/diagonal ray within BOLT_RANGE (+20px), plus origin
        targets = [s["pos"] for s in self.switches] + [p["pos"] for p in self.portals]
        useful: Dict[Tuple[float, float], int] = {(ox, oy): 0}
        for (px, py), pcost in best_pos_cost.items():
            for tx_t, ty_t in targets:
                dx = abs(tx_t - px)
                dy = abs(ty_t - py)
                dist_t = math.hypot(dx, dy)
                if dist_t <= BOLT_RANGE + 18.0:
                    # Cardinal or 45-deg aligned within 12px tolerance
                    if dx <= 12.0 or dy <= 12.0 or abs(dx - dy) <= 14.0:
                        useful[(px, py)] = pcost
                        break
        # Cap candidate set cleanly for speed (keep lowest-push closest to targets)
        if len(useful) > 18:
            ranked = sorted(
                useful.items(),
                key=lambda kv: (kv[1], min(math.hypot(kv[0][0] - t[0], kv[0][1] - t[1]) for t in targets)),
            )
            useful = dict(ranked[:18])
            useful[(ox, oy)] = 0
        return useful

    def _update_doors_mask(self, sw_mask: int, br_mask: int, doors_mask: int) -> int:
        active_sigs: Set[str] = set()
        for si, sw in enumerate(self.switches):
            if (sw_mask >> si) & 1:
                active_sigs.add(sw["id"])
        for bi, br in enumerate(self.braziers):
            if (br_mask >> bi) & 1:
                active_sigs.add(br["id"])

        # Also map target_id signals explicitly
        targeted_by: Dict[str, Set[str]] = {}
        for si, sw in enumerate(self.switches):
            if (sw_mask >> si) & 1:
                for tid in sw["targets"]:
                    targeted_by.setdefault(tid, set()).add(sw["id"])
        for bi, br in enumerate(self.braziers):
            if (br_mask >> bi) & 1:
                for tid in br["targets"]:
                    targeted_by.setdefault(tid, set()).add(br["id"])

        new_mask = doors_mask
        for di, d in enumerate(self.doors):
            if (new_mask >> di) & 1:
                continue
            if d["door_type"] not in ("switch_door", "bridge_platform"):
                continue
            sigs = targeted_by.get(d["id"], set())
            if d["requires_signals"]:
                if all(req in sigs or req in active_sigs for req in d["requires_signals"]):
                    new_mask |= (1 << di)
            elif len(sigs) >= d["required_count"]:
                new_mask |= (1 << di)
        return new_mask

    def _run_search(
        self,
        skip_mirrors: Optional[Set[int]] = None,
        allow_move: bool = True,
        allow_rotate: bool = True,
        allow_direct_yellow: bool = True,
    ) -> Dict[str, Any]:
        skip_set: Set[int] = set(skip_mirrors or ())
        n_m = len(self.mirrors)
        n_sw = len(self.switches)
        n_po = len(self.portals)

        init_sw = 0
        for si, sw in enumerate(self.switches):
            if sw["starts_active"]:
                init_sw |= (1 << si)
        init_po = 0
        for pi, po in enumerate(self.portals):
            if po["starts_powered"]:
                init_po |= (1 << pi)
        init_doors = 0
        for di, d in enumerate(self.doors):
            if d["starts_open"]:
                init_doors |= (1 << di)

        goal_sw = (1 << n_sw) - 1
        goal_po = (1 << n_po) - 1

        init_pos = tuple(m["origin"] for m in self.mirrors)
        init_rot = tuple(0 for _ in range(n_m))  # number of 45-deg taps (0..3 mod 4)
        init_br = 0
        init_doors = self._update_doors_mask(init_sw, init_br, init_doors)

        # State: (pos_tuple, rot_tuple, sw_mask, po_mask, doors_mask, br_mask)
        # Cost breakdown: (total_steps, pushes, rotations, bounces, warps, direct_yellow_used, mirrors_used_mask)
        start_state = (init_pos, init_rot, init_sw, init_po, init_doors, init_br)
        best_cost: Dict[Any, int] = {start_state: 0}
        pq: List[Tuple[int, int, int, int, int, int, int, Any]] = [
            (0, 0, 0, 0, 0, 0, 0, start_state)
        ]

        # Precompute whether warping through a portal reaches a disconnected region (worth +1 warp at end)
        expansions = 0
        max_expansions = 1200

        while pq and expansions < max_expansions:
            total, pushes, rots, bounces, warps, direct_y, used_m_mask, state = heapq.heappop(pq)
            if total > best_cost.get(state, 9999):
                continue
            expansions += 1
            pos_t, rot_t, sw_m, po_m, d_m, br_m = state

            # Check goal
            if sw_m == goal_sw and po_m == goal_po:
                # If portals exist and warping opens new area (like islet chest), include 1 warp step
                final_warps = warps
                if n_po > 0 and final_warps == 0:
                    nw, ww = self._reachable_tiles(d_m, po_m, pos_t)
                    if len(ww) > len(nw):
                        final_warps += 1
                return {
                    "solvable": True,
                    "min_steps": total + (final_warps - warps),
                    "pushes": pushes,
                    "rotations": rots,
                    "bounces": bounces,
                    "warps": final_warps,
                    "direct_yellow_used": bool(direct_y),
                    "used_mirrors_mask": used_m_mask,
                }

            angles_t = tuple(
                (self.mirrors[i]["angle_deg"] + rot_t[i] * self.mirrors[i]["angle_step"]) % 360.0
                for i in range(n_m)
            )
            reached_nw, reached_ww = self._reachable_tiles(d_m, po_m, pos_t)

            # 0. Light any reachable braziers for free
            if self.braziers:
                new_br = br_m
                for bi, br in enumerate(self.braziers):
                    if (new_br >> bi) & 1:
                        continue
                    btx = int(math.floor(br["pos"][0] / self.ts))
                    bty = int(math.floor(br["pos"][1] / self.ts))
                    if any((btx + dx, bty + dy) in reached_ww for dy in (-1, 0, 1) for dx in (-1, 0, 1)):
                        new_br |= (1 << bi)
                if new_br != br_m:
                    nd_m = self._update_doors_mask(sw_m, new_br, d_m)
                    ns = (pos_t, rot_t, sw_m, po_m, nd_m, new_br)
                    if total < best_cost.get(ns, 9999):
                        best_cost[ns] = total
                        heapq.heappush(pq, (total, pushes, rots, bounces, warps, direct_y, used_m_mask, ns))
                    continue

            # 1. Try shooting any unactivated switch or unpowered portal
            for si in range(n_sw):
                if (sw_m >> si) & 1:
                    continue
                shot = self._find_best_shot(
                    "switch", si, reached_nw, reached_ww, pos_t, angles_t, d_m, skip_set, allow_direct_yellow
                )
                if shot is not None:
                    b_cnt, w_cost, _is_bl, m_used = shot
                    nsw = sw_m | (1 << si)
                    nd_m = self._update_doors_mask(nsw, br_m, d_m)
                    ns = (pos_t, rot_t, nsw, po_m, nd_m, br_m)
                    ncost = total + b_cnt + w_cost
                    n_used = used_m_mask
                    for mu in m_used:
                        n_used |= (1 << mu)
                    if ncost < best_cost.get(ns, 9999):
                        best_cost[ns] = ncost
                        heapq.heappush(
                            pq,
                            (ncost, pushes, rots, bounces + b_cnt, warps + w_cost, direct_y or (1 if b_cnt == 0 else 0), n_used, ns),
                        )

            for pi in range(n_po):
                if (po_m >> pi) & 1:
                    continue
                shot = self._find_best_shot(
                    "portal", pi, reached_nw, reached_ww, pos_t, angles_t, d_m, skip_set, allow_direct_yellow
                )
                if shot is not None:
                    b_cnt, w_cost, _is_bl, m_used = shot
                    npo = po_m | (1 << pi)
                    pobj = self.portals[pi]
                    if pobj["pair_sync"] and pobj["pair_idx"] >= 0:
                        npo |= (1 << pobj["pair_idx"])
                    ns = (pos_t, rot_t, sw_m, npo, d_m, br_m)
                    ncost = total + b_cnt + w_cost
                    n_used = used_m_mask
                    for mu in m_used:
                        n_used |= (1 << mu)
                    if ncost < best_cost.get(ns, 9999):
                        best_cost[ns] = ncost
                        heapq.heappush(
                            pq,
                            (ncost, pushes, rots, bounces + b_cnt, warps + w_cost, direct_y or (1 if b_cnt == 0 else 0), n_used, ns),
                        )

            # 2. Rotate any reachable rotatable mirror (1..3 steps of 45 deg; mod 180 since double-sided)
            if allow_rotate:
                for mi, m in enumerate(self.mirrors):
                    if mi in skip_set or not m["rotatable"]:
                        continue
                    mx, my = pos_t[mi]
                    mtx, mty = int(math.floor(mx / self.ts)), int(math.floor(my / self.ts))
                    if not any((mtx + dx, mty + dy) in reached_ww for dy in (-1, 0, 1) for dx in (-1, 0, 1)):
                        continue
                    w_cost = 0 if any((mtx + dx, mty + dy) in reached_nw for dy in (-1, 0, 1) for dx in (-1, 0, 1)) else 1
                    period = 4 if m["double_sided"] else 8
                    cur_r = rot_t[mi]
                    for step_r in range(1, period):
                        new_r = (cur_r + step_r) % period
                        nrot = rot_t[:mi] + (new_r,) + rot_t[mi + 1:]
                        ns = (pos_t, nrot, sw_m, po_m, d_m, br_m)
                        ncost = total + step_r + w_cost
                        if ncost < best_cost.get(ns, 9999):
                            best_cost[ns] = ncost
                            heapq.heappush(pq, (ncost, pushes, rots + step_r, bounces, warps + w_cost, direct_y, used_m_mask, ns))

            # 3. Push/pull any reachable movable transformer
            if allow_move:
                for mi, m in enumerate(self.mirrors):
                    if mi in skip_set or not m["movable"]:
                        continue
                    cands = self._compute_push_candidates(mi, d_m, pos_t, reached_ww)
                    for new_pos, p_segs in cands.items():
                        if new_pos == pos_t[mi] or p_segs <= 0:
                            continue
                        npos = pos_t[:mi] + (new_pos,) + pos_t[mi + 1:]
                        ns = (npos, rot_t, sw_m, po_m, d_m, br_m)
                        ncost = total + p_segs
                        if ncost < best_cost.get(ns, 9999):
                            best_cost[ns] = ncost
                            heapq.heappush(pq, (ncost, pushes + p_segs, rots, bounces, warps, direct_y, used_m_mask, ns))

        return {
            "solvable": False,
            "min_steps": None,
            "pushes": 0,
            "rotations": 0,
            "bounces": 0,
            "warps": 0,
            "direct_yellow_used": False,
            "used_mirrors_mask": 0,
        }

    def solve(self) -> Dict[str, Any]:
        if not self.is_applicable():
            return {"applicable": False}

        res = self._run_search()
        solvable = bool(res["solvable"])
        anti_cheese = True
        cheese_reasons: List[str] = []

        if solvable:
            # Cheese check 1: Direct yellow shot solves a switch/portal in a mirror/blue room
            if res["direct_yellow_used"]:
                anti_cheese = False
                cheese_reasons.append("direct yellow shot activates a puzzle switch/portal without bouncing")

            # Cheese check 2: Skipping any movable/rotatable transformer still solves the room
            interactive_mirrors = [
                i for i, m in enumerate(self.mirrors) if m["movable"] or m["rotatable"]
            ]
            if interactive_mirrors:
                # Can we solve WITHOUT using any interactive mirror at all?
                skip_res = self._run_search(skip_mirrors=set(interactive_mirrors))
                if skip_res["solvable"]:
                    anti_cheese = False
                    cheese_reasons.append("puzzle solvable while completely skipping movable/rotatable transformer(s)")
                else:
                    # Check if a movable/rotatable transformer can be left untouched (0 pushes & 0 rotations)
                    untouched = self._run_search(allow_move=False, allow_rotate=False)
                    if untouched["solvable"]:
                        anti_cheese = False
                        cheese_reasons.append("movable/rotatable transformer needs 0 pushes & 0 rotations (pre-aligned)")

        return {
            "applicable": True,
            "puzzle_solvable": solvable,
            "min_steps": res["min_steps"],
            "breakdown": {
                "pushes": res["pushes"],
                "rotations": res["rotations"],
                "bounces": res["bounces"],
                "warps": res["warps"],
            },
            "anti_cheese": anti_cheese,
            "cheese_reason": "; ".join(cheese_reasons),
            "mirror_count": len(self.mirrors),
            "switch_count": len(self.switches),
            "portal_count": len(self.portals),
        }


# ---------------------------------------------------------------------------
# (e) Dormans Cyclic Topology Check (per island)
# ---------------------------------------------------------------------------

def audit_island_topology(island_id: int, regions: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
    # 1. Room-exit graph (full + dungeon-only)
    all_nodes = sorted(regions.keys())
    dungeon_nodes = sorted(rid for rid, r in regions.items() if r["is_dungeon"])

    directed_edges: List[Tuple[str, str]] = []
    undirected_all: Set[Tuple[str, str]] = set()
    undirected_dungeon: Set[Tuple[str, str]] = set()

    for rid, reg in regions.items():
        for ex in reg["exits"]:
            to_isl = ex.get("to_island")
            if to_isl is not None and int(to_isl) != island_id:
                continue
            target = str(ex.get("to_region", "")).strip()
            if not target or target not in regions or target == rid:
                continue
            directed_edges.append((rid, target))
            edge = (min(rid, target), max(rid, target))
            undirected_all.add(edge)
            if reg["is_dungeon"] and regions[target]["is_dungeon"]:
                undirected_dungeon.add(edge)

    def graph_cycles(nodes: List[str], edges: Set[Tuple[str, str]]) -> Tuple[int, int, int, int]:
        v = len(nodes)
        e = len(edges)
        if v == 0:
            return (0, 0, 0, 0)
        adj: Dict[str, List[str]] = {n: [] for n in nodes}
        for a, b in edges:
            if a in adj and b in adj:
                adj[a].append(b)
                adj[b].append(a)
        vis: Set[str] = set()
        comps = 0
        for n in nodes:
            if n in vis:
                continue
            comps += 1
            q = deque([n])
            vis.add(n)
            while q:
                cur = q.popleft()
                for nxt in adj[cur]:
                    if nxt not in vis:
                        vis.add(nxt)
                        q.append(nxt)
        cycles = e - v + comps
        return (v, e, comps, cycles)

    all_v, all_e, all_c, all_cycles = graph_cycles(all_nodes, undirected_all)
    dun_v, dun_e, dun_c, dun_cycles = graph_cycles(dungeon_nodes, undirected_dungeon)
    linear_tube = (dun_v >= 3 and dun_cycles == 0)

    # 2. Overworld zone-connectivity graph
    z_v, z_e, z_c, z_cycles = (0, 0, 0, 0)
    ow = regions.get("overworld")
    zone_edges: Set[Tuple[str, str]] = set()
    if ow and ow["zones"]:
        zones = ow["zones"]
        zone_ids = [str(z.get("id", f"z{i}")) for i, z in enumerate(zones)]
        z_rects: List[Tuple[str, float, float, float, float]] = []
        for i, z in enumerate(zones):
            zr = z.get("rect", [])
            if isinstance(zr, list) and len(zr) >= 4:
                z_rects.append((zone_ids[i], float(zr[0]), float(zr[1]), float(zr[0]) + float(zr[2]), float(zr[1]) + float(zr[3])))

        ts = ow["tile_size"]
        w, h = ow["width"], ow["height"]
        grid = ow["grid"]

        # Map each traversable tile to its zone(s)
        tile_zones: Dict[Tuple[int, int], List[str]] = {}
        extra_walk: Set[Tuple[int, int]] = set()
        for it in ow["interactables"]:
            k = str(it.get("kind", "")).strip().lower()
            px, py = interactable_pos(it)
            if k in TIDE_KINDS:
                sw, sh = interactable_size(it, (32.0, 32.0))
                _mark_rect_tiles(extra_walk, px, py, sw, sh, ts, w, h)
            elif k in DOOR_KINDS and get_door_type(it) == "bridge_platform":
                sw, sh = interactable_size(it, (32.0, 16.0))
                _mark_rect_tiles(extra_walk, px, py, sw, sh, ts, w, h)
            elif k in ("phantom_platform", "phantom"):
                sw, sh = interactable_size(it, (32.0, 16.0))
                _mark_rect_tiles(extra_walk, px, py, sw, sh, ts, w, h)

        def zones_at_px(x: float, y: float) -> List[str]:
            return [zid for zid, x0, y0, x1, y1 in z_rects if x0 <= x <= x1 and y0 <= y <= y1]

        for y in range(h):
            for x in range(w):
                tt = grid[y][x]
                if tt in WALKABLE_BASE_TILES or tt in ("phantom", "bramble", "cracked") or (x, y) in extra_walk:
                    zs = zones_at_px((x + 0.5) * ts, (y + 0.5) * ts)
                    if zs:
                        tile_zones[(x, y)] = zs

        for (x, y), zs in tile_zones.items():
            # Overlapping zones on same walkable tile
            for i in range(len(zs)):
                for j in range(i + 1, len(zs)):
                    zone_edges.add((min(zs[i], zs[j]), max(zs[i], zs[j])))
            for dx, dy in ((1, 0), (0, 1)):
                nzs = tile_zones.get((x + dx, y + dy))
                if nzs:
                    for za in zs:
                        for zb in nzs:
                            if za != zb:
                                zone_edges.add((min(za, zb), max(za, zb)))

        # Portal warps between zones
        by_id = {str(it.get("id", "")): it for it in ow["interactables"] if str(it.get("id", ""))}
        for it in ow["interactables"]:
            if str(it.get("kind", "")).strip().lower() in PORTAL_KINDS:
                p1 = interactable_pos(it)
                tpid = str((it.get("props", {}) or {}).get("target_portal_id", "")).strip()
                if tpid in by_id:
                    p2 = interactable_pos(by_id[tpid])
                    for za in zones_at_px(p1[0], p1[1]):
                        for zb in zones_at_px(p2[0], p2[1]):
                            if za != zb:
                                zone_edges.add((min(za, zb), max(za, zb)))

        z_v, z_e, z_c, z_cycles = graph_cycles(sorted(set(zone_ids)), zone_edges)

    return {
        "island_id": island_id,
        "room_graph": {"V": all_v, "E": all_e, "C": all_c, "cycles": all_cycles},
        "dungeon_graph": {"V": dun_v, "E": dun_e, "C": dun_c, "cycles": dun_cycles},
        "overworld_zone_graph": {"V": z_v, "E": z_e, "C": z_c, "cycles": z_cycles},
        "linear_tube": linear_tube,
    }


# ---------------------------------------------------------------------------
# (f) Combat Choreography Critic
# ---------------------------------------------------------------------------

def audit_combat(region: Dict[str, Any]) -> Dict[str, Any]:
    enemies = region["enemies"]
    count = len(enemies)
    roles: List[str] = [enemy_role(str(e.get("kind", ""))) for e in enemies]
    role_counts = Counter(roles)
    unique_roles = len(role_counts)

    if count < 2:
        return {
            "is_combat_room": False,
            "enemy_count": count,
            "roles": dict(role_counts),
            "unique_roles": unique_roles,
            "cover_density": None,
            "empty_box_combat": False,
            "homogenous_swarm": False,
        }

    # Compute playable bounding box (all walkable tiles) inset by 1 tile on each side
    w, h, ts = region["width"], region["height"], region["tile_size"]
    grid = region["grid"]
    min_x, max_x = w, -1
    min_y, max_y = h, -1
    for y in range(h):
        for x in range(w):
            if grid[y][x] in WALKABLE_BASE_TILES or grid[y][x] in ("phantom", "tide"):
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
                if y < min_y:
                    min_y = y
                if y > max_y:
                    max_y = y

    mirror_tiles: Set[Tuple[int, int]] = set()
    for it in region["interactables"]:
        if str(it.get("kind", "")).strip().lower() in MIRROR_KINDS:
            px, py = interactable_pos(it)
            mirror_tiles.add((int(math.floor(px / ts)), int(math.floor(py / ts))))

    ix0, ix1 = min_x + 1, max_x - 1
    iy0, iy1 = min_y + 1, max_y - 1
    interior_area = 0
    cover_count = 0
    if ix1 >= ix0 and iy1 >= iy0:
        for y in range(iy0, iy1 + 1):
            for x in range(ix0, ix1 + 1):
                tt = grid[y][x]
                if tt == "void":
                    continue
                interior_area += 1
                if tt in COVER_TILES or (x, y) in mirror_tiles:
                    cover_count += 1

    cover_density = cover_count / max(1, interior_area)
    homogenous = unique_roles < 2
    empty_box = (interior_area >= 20 and cover_density < 0.04)

    return {
        "is_combat_room": True,
        "enemy_count": count,
        "roles": dict(role_counts),
        "unique_roles": unique_roles,
        "cover_density": round(cover_density, 3),
        "empty_box_combat": empty_box,
        "homogenous_swarm": homogenous,
    }


# ---------------------------------------------------------------------------
# Full Region & Island Audit Orchestration
# ---------------------------------------------------------------------------

def audit_region_dict(region: Dict[str, Any]) -> Dict[str, Any]:
    sym = compute_symmetry(region)
    phantom = audit_phantom(region)
    wiring = audit_wiring_and_placement(region)
    puzzle = OpticalPuzzleSolver(region).solve()
    combat = audit_combat(region)

    flags: List[str] = []
    details: List[str] = []

    if sym["flag"]:
        flags.append("SYMMETRIC_BOX")
        details.append(f"SYMMETRIC_BOX (sym_max={sym['sym_max']:.2f}, h={sym['sym_h']:.2f}, v={sym['sym_v']:.2f})")

    if phantom["centered_waffle"]:
        flags.append("CENTERED_WAFFLE")
        details.append(f"CENTERED_WAFFLE ({phantom['reason']})")

    for iss in wiring["issues"]:
        flags.append(iss["flag"])
        details.append(f"{iss['flag']}: {iss['detail']}")

    if puzzle.get("applicable"):
        if not puzzle["puzzle_solvable"]:
            flags.append("PUZZLE_UNSOLVABLE")
            details.append("PUZZLE_UNSOLVABLE (state-space solver found no valid 118px/2-bounce solution)")
        elif not puzzle["anti_cheese"]:
            flags.append("PUZZLE_CHEESABLE")
            details.append(f"PUZZLE_CHEESABLE ({puzzle['cheese_reason']})")

    if combat["empty_box_combat"]:
        flags.append("EMPTY_BOX_COMBAT")
        details.append(f"EMPTY_BOX_COMBAT (enemies={combat['enemy_count']}, cover={combat['cover_density']:.3f})")
    if combat["homogenous_swarm"]:
        flags.append("HOMOGENOUS_SWARM")
        details.append(f"HOMOGENOUS_SWARM (enemies={combat['enemy_count']}, roles={combat['roles']})")

    severity = sum(FLAG_WEIGHTS.get(f, 3) for f in flags)

    return {
        "island_id": region["island_id"],
        "id": region["id"],
        "is_dungeon": region["is_dungeon"],
        "width": region["width"],
        "height": region["height"],
        "map_path": region["map_path"],
        "json_path": region["json_path"],
        "symmetry": sym,
        "phantom": phantom,
        "wiring": wiring,
        "puzzle": puzzle,
        "combat": combat,
        "flags": flags,
        "unique_flags": sorted(set(flags)),
        "details": details,
        "severity": severity,
    }


def audit_room_files(map_path: str, json_path: str = "") -> Dict[str, Any]:
    region = parse_region(map_path, json_path)
    return audit_region_dict(region)


def audit_island(island_id: int) -> Dict[str, Any]:
    entries = list_island_regions(island_id)
    regions_map: Dict[str, Dict[str, Any]] = {}
    room_reports: List[Dict[str, Any]] = []

    for rid, mp, jp in entries:
        reg = parse_region(mp, jp)
        regions_map[rid] = reg
        room_reports.append(audit_region_dict(reg))

    topo = audit_island_topology(island_id, regions_map)
    island_flags: List[str] = []
    if topo["linear_tube"]:
        island_flags.append("LINEAR_TUBE")

    flag_counts: Counter[str] = Counter(island_flags)
    for rr in room_reports:
        flag_counts.update(rr["flags"])

    total_severity = sum(rr["severity"] for rr in room_reports) + sum(
        FLAG_WEIGHTS.get(f, 3) for f in island_flags
    )

    return {
        "island_id": island_id,
        "region_count": len(room_reports),
        "topology": topo,
        "island_flags": island_flags,
        "flag_counts": dict(flag_counts),
        "total_flags": sum(flag_counts.values()),
        "total_severity": total_severity,
        "rooms": room_reports,
    }


def audit_all_islands() -> Dict[str, Any]:
    islands = [audit_island(i) for i in range(1, 9)]
    global_flags: Counter[str] = Counter()
    total_regions = 0
    for isl in islands:
        total_regions += isl["region_count"]
        global_flags.update(isl["flag_counts"])

    return {
        "total_regions": total_regions,
        "global_flag_counts": dict(global_flags),
        "total_flags": sum(global_flags.values()),
        "islands": islands,
    }


# ---------------------------------------------------------------------------
# Markdown Report Formatting
# ---------------------------------------------------------------------------

def render_markdown_report(summary: Dict[str, Any]) -> str:
    lines: List[str] = []
    lines.append("# Luxel Neuro-Symbolic Level Design Critic Report")
    lines.append("")
    lines.append(
        f"Audited **{summary['total_regions']} regions** across **Islands 1–8**. "
        f"Total flagged issues: **{summary['total_flags']}**."
    )
    lines.append("")

    # Global Flag Summary Table
    lines.append("## Global Issue Breakdown")
    lines.append("")
    lines.append("| Flag | Count | Severity Weight | Description |")
    lines.append("| :--- | ---: | ---: | :--- |")
    flag_desc = {
        "SYMMETRIC_BOX": "Overworld or puzzle room with mirror symmetry `sym_max > 0.72`",
        "CENTERED_WAFFLE": "Phantom (`P`) tiles form chunky `>=3x3` slabs or sit dead-center with low winding",
        "UNWIRED_SWITCH": "`switch_eye` with no `target_id` and no `target_ids`",
        "BROKEN_SWITCH_TARGET": "`switch_eye` targeting a non-existent interactable ID",
        "DEAD_MIRROR": "`mirror` in a room with 0 blue switches, 0 blue portals, and 0 shielded enemies/bosses",
        "DEAD_TRANSFORMER": "`blue_transformer` in a room with 0 blue targets/shielded foes",
        "SKIPPABLE_TIDE_GATE": "`tide_gate` bypassed by walkable non-tide tiles within 2 tiles",
        "STALE_TRIGGER": "Trigger rect mostly on `water`/`void`/`wall` or outside map bounds",
        "INTERACTABLE_IN_SOLID": "Key interactable placed on a `wall` or `void` tile",
        "UNREACHABLE_INTERACTABLE": "Key interactable unreachable from spawn/exits even with unlocks",
        "PUZZLE_UNSOLVABLE": "Optical puzzle has no valid 118px / 2-bounce state-space solution",
        "PUZZLE_CHEESABLE": "Optical puzzle solvable via direct yellow shot or skipping movable/rotatable transformer",
        "LINEAR_TUBE": "Island dungeon room-exit graph has 0 Dormans cycles (`E - V + C = 0`)",
        "EMPTY_BOX_COMBAT": "Combat room (`>=2` enemies) with interior cover density `< 4%`",
        "HOMOGENOUS_SWARM": "Combat room (`>=2` enemies) with `< 2` unique enemy roles",
    }
    for flag, cnt in sorted(summary["global_flag_counts"].items(), key=lambda kv: (-kv[1], kv[0])):
        lines.append(f"| `{flag}` | {cnt} | {FLAG_WEIGHTS.get(flag, 3)} | {flag_desc.get(flag, '')} |")
    lines.append("")

    # Island Scorecard Table (ranked worst to cleanest)
    lines.append("## Island Scorecard (Ranked Worst to Cleanest)")
    lines.append("")
    lines.append(
        "| Rank | Island | Regions | Total Flags | Severity | Dungeon Cycles (`E-V+C`) | OW Zone Cycles | Top Flags |"
    )
    lines.append("| ---: | :---: | ---: | ---: | ---: | :---: | :---: | :--- |")
    ranked_islands = sorted(summary["islands"], key=lambda x: (-x["total_severity"], -x["total_flags"], x["island_id"]))
    for rank, isl in enumerate(ranked_islands, 1):
        dg = isl["topology"]["dungeon_graph"]
        zg = isl["topology"]["overworld_zone_graph"]
        dun_str = f"{dg['cycles']} (`{dg['E']}-{dg['V']}+{dg['C']}`)"
        if isl["topology"]["linear_tube"]:
            dun_str += " **LINEAR_TUBE**"
        z_str = f"{zg['cycles']} (`{zg['E']}-{zg['V']}+{zg['C']}`)"
        top_f = ", ".join(
            f"`{k}`×{v}" for k, v in sorted(isl["flag_counts"].items(), key=lambda kv: (-kv[1], kv[0]))[:4]
        ) or "—"
        lines.append(
            f"| {rank} | **Island {isl['island_id']}** | {isl['region_count']} | {isl['total_flags']} | "
            f"{isl['total_severity']} | {dun_str} | {z_str} | {top_f} |"
        )
    lines.append("")

    # Optical Puzzle Solver Summary Table
    lines.append("## Optical Puzzle Solver Scorecard")
    lines.append("")
    lines.append("| Island | Room | Solvable | `L_min` (push+rot+bnc+warp) | Anti-Cheese | Notes |")
    lines.append("| :---: | :--- | :---: | :---: | :---: | :--- |")
    for isl in summary["islands"]:
        for rr in isl["rooms"]:
            pz = rr["puzzle"]
            if not pz.get("applicable"):
                continue
            sol = "PASS" if pz["puzzle_solvable"] else "**FAIL**"
            bd = pz["breakdown"]
            lmin = (
                f"{pz['min_steps']} ({bd['pushes']}+{bd['rotations']}+{bd['bounces']}+{bd['warps']})"
                if pz["min_steps"] is not None
                else "—"
            )
            ac = "PASS" if pz["anti_cheese"] else "**CHEESE**"
            notes = pz["cheese_reason"] or f"{pz['mirror_count']}m / {pz['switch_count']}sw / {pz['portal_count']}po"
            lines.append(f"| {isl['island_id']} | `{rr['id']}` | {sol} | {lmin} | {ac} | {notes} |")
    lines.append("")

    # Worst Offenders Overall (Top 20 rooms)
    all_rooms = [rr for isl in summary["islands"] for rr in isl["rooms"] if rr["flags"]]
    all_rooms.sort(key=lambda r: (-r["severity"], -len(r["flags"]), r["island_id"], r["id"]))
    lines.append("## Top 20 Worst Offender Rooms")
    lines.append("")
    lines.append("| Rank | Island | Room | Severity | `sym_max` | Flags |")
    lines.append("| ---: | :---: | :--- | ---: | ---: | :--- |")
    for rank, rr in enumerate(all_rooms[:20], 1):
        fl_str = ", ".join(f"`{f}`" for f in rr["unique_flags"])
        lines.append(
            f"| {rank} | {rr['island_id']} | `{rr['id']}` | {rr['severity']} | {rr['symmetry']['sym_max']:.2f} | {fl_str} |"
        )
    lines.append("")

    # Per-Island Room-by-Room Breakdown
    lines.append("## Island-by-Island Room Audit")
    lines.append("")
    for isl in summary["islands"]:
        iid = isl["island_id"]
        dg = isl["topology"]["dungeon_graph"]
        rg = isl["topology"]["room_graph"]
        zg = isl["topology"]["overworld_zone_graph"]
        lines.append(f"### Island {iid} ({isl['region_count']} regions, {isl['total_flags']} flags, severity {isl['total_severity']})")
        lines.append("")
        topo_note = (
            f"- **Topology**: Room graph `V={rg['V']}, E={rg['E']}, C={rg['C']} -> cycles={rg['cycles']}`; "
            f"Dungeon `V={dg['V']}, E={dg['E']}, C={dg['C']} -> cycles={dg['cycles']}`; "
            f"Overworld zones `V={zg['V']}, E={zg['E']}, C={zg['C']} -> cycles={zg['cycles']}`"
        )
        if isl["topology"]["linear_tube"]:
            topo_note += " — **`LINEAR_TUBE`**"
        lines.append(topo_note)
        lines.append("")
        lines.append("| Room | Size | `sym_max` | Phantom `wind` | Puzzle `L_min` | Combat (`n`/roles/cover) | Flags & Diagnostics |")
        lines.append("| :--- | :---: | ---: | :---: | :---: | :---: | :--- |")

        # Sort rooms: flagged worst first, then clean rooms
        ordered_rooms = sorted(isl["rooms"], key=lambda r: (-r["severity"], r["is_dungeon"], r["id"]))
        for rr in ordered_rooms:
            sz = f"{rr['width']}×{rr['height']}"
            sym_s = f"{rr['symmetry']['sym_max']:.2f}"
            ph = rr["phantom"]
            ph_s = f"{ph['winding_score']:.2f} ({ph['count']}P)" if ph["has_phantom"] else "—"
            pz = rr["puzzle"]
            if pz.get("applicable"):
                pz_s = f"{pz['min_steps']}" if pz["puzzle_solvable"] else "UNSOLV"
                if pz["puzzle_solvable"] and not pz["anti_cheese"]:
                    pz_s += " (cheese)"
            else:
                pz_s = "—"
            cb = rr["combat"]
            if cb["is_combat_room"]:
                cb_s = f"{cb['enemy_count']} / {cb['unique_roles']}r / {cb['cover_density'] * 100:.1f}%"
            elif cb["enemy_count"] == 1:
                cb_s = "1 (solo)"
            else:
                cb_s = "—"
            diag = "; ".join(rr["details"]) if rr["details"] else "clean"
            lines.append(f"| `{rr['id']}` | {sz} | {sym_s} | {ph_s} | {pz_s} | {cb_s} | {diag} |")
        lines.append("")

    return "\n".join(lines) + "\n"


def print_room_summary(rr: Dict[str, Any]) -> None:
    print(f"=== Island {rr['island_id']} / {rr['id']} ({rr['width']}x{rr['height']}) ===")
    sym = rr["symmetry"]
    print(f"  Symmetry : sym_h={sym['sym_h']:.3f} sym_v={sym['sym_v']:.3f} sym_max={sym['sym_max']:.3f} flag={sym['flag']}")
    ph = rr["phantom"]
    if ph["has_phantom"]:
        print(
            f"  Phantom  : count={ph['count']} winding={ph['winding_score']:.3f} "
            f"center_offset={ph['center_offset']:.3f} waffle={ph['centered_waffle']} ({ph['reason']})"
        )
    pz = rr["puzzle"]
    if pz.get("applicable"):
        print(
            f"  Puzzle   : solvable={pz['puzzle_solvable']} L_min={pz['min_steps']} "
            f"breakdown={pz['breakdown']} anti_cheese={pz['anti_cheese']} ({pz['cheese_reason']})"
        )
    cb = rr["combat"]
    if cb["enemy_count"] > 0:
        print(
            f"  Combat   : enemies={cb['enemy_count']} roles={cb['roles']} "
            f"unique_roles={cb['unique_roles']} cover={cb['cover_density']}"
        )
    print(f"  Flags    : {rr['unique_flags'] or ['CLEAN']} (severity={rr['severity']})")
    for d in rr["details"]:
        print(f"    - {d}")


def print_island_summary(isl: Dict[str, Any]) -> None:
    dg = isl["topology"]["dungeon_graph"]
    zg = isl["topology"]["overworld_zone_graph"]
    print(
        f"=== Island {isl['island_id']} ({isl['region_count']} regions) | "
        f"Flags: {isl['total_flags']} | Severity: {isl['total_severity']} | "
        f"Dungeon cycles: {dg['cycles']} | OW zone cycles: {zg['cycles']} ==="
    )
    if isl["island_flags"]:
        print(f"  Island Flags: {isl['island_flags']}")
    print(f"  Flag Counts : {dict(sorted(isl['flag_counts'].items(), key=lambda kv: (-kv[1], kv[0])))}")
    for rr in sorted(isl["rooms"], key=lambda r: (-r["severity"], r["id"])):
        if rr["flags"] or rr["puzzle"].get("applicable"):
            fl = ", ".join(rr["unique_flags"]) if rr["unique_flags"] else "CLEAN"
            pz = rr["puzzle"]
            pz_str = f" | L_min={pz['min_steps']} ac={pz['anti_cheese']}" if pz.get("applicable") else ""
            print(f"  [{rr['severity']:2d}] {rr['id']:16s} sym={rr['symmetry']['sym_max']:.2f}{pz_str} :: {fl}")


# ---------------------------------------------------------------------------
# CLI Entrypoint
# ---------------------------------------------------------------------------

def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Luxel Neuro-Symbolic Level Design Critic")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_all = sub.add_parser("audit_all", help="Audit all 8 islands and optionally write Markdown report")
    p_all.add_argument("--out", default="", help="Output Markdown report path")

    p_isl = sub.add_parser("audit_island", help="Audit a single island (1..8)")
    p_isl.add_argument("island_id", type=int, choices=range(1, 9))

    p_room = sub.add_parser("audit_room", help="Audit a single .map + .json room")
    p_room.add_argument("map_path")
    p_room.add_argument("json_path")

    args = parser.parse_args(argv)

    if args.cmd == "audit_all":
        summary = audit_all_islands()
        md = render_markdown_report(summary)
        if args.out:
            out_path = args.out
            if not os.path.isabs(out_path):
                out_path = os.path.join(repo_root(), out_path)
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(md)
            print(f"Wrote design critic report to {out_path}")
        print(
            f"Audited {summary['total_regions']} regions across Islands 1-8 | "
            f"Total flags: {summary['total_flags']}"
        )
        for isl in summary["islands"]:
            dg = isl["topology"]["dungeon_graph"]
            zg = isl["topology"]["overworld_zone_graph"]
            tube = " LINEAR_TUBE" if isl["topology"]["linear_tube"] else ""
            print(
                f"  Island {isl['island_id']}: {isl['region_count']:2d} regions | "
                f"{isl['total_flags']:2d} flags | sev {isl['total_severity']:3d} | "
                f"dun_cyc={dg['cycles']} ow_cyc={zg['cycles']}{tube}"
            )
        return 0

    if args.cmd == "audit_island":
        isl = audit_island(args.island_id)
        print_island_summary(isl)
        return 0

    if args.cmd == "audit_room":
        rr = audit_room_files(args.map_path, args.json_path)
        print_room_summary(rr)
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
