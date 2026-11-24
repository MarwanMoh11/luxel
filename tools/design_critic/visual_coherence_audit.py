#!/usr/bin/env python3
"""Luxel Round 2 Symbolic Visual Coherence Auditor.

Python 3 stdlib only (optionally checks Pillow if invoked under `uv run --with pillow`
and degrades gracefully when PIL is absent).

Scans all 81 regions across `luxel/islands/1..8/*.map` + `*.json` and loads
`luxel/art/props/island{1..8}_scenery.json` for prop frame & anchor dimensions.

Checks:
  1. FLOATING_SCENERY       - terrestrial scenery on water/void/pit/tide/phantom, or
                              strictly aquatic scenery on dry land not adjacent to water
  2. WALL_CLIPPING_SCENERY  - sort/ground scenery anchored inside solid '#' walls
                              (allowing explicit wall-mounted props on south-facing wall lips)
  3. SCENERY_OVERLAP        - sort scenery within 12px of key interactables, inside a door rect,
                              within 14px of spawn, or directly blocking an exit rect
  4. MISPLACED_INTERACTABLE - non-bridge/non-door/non-portal/non-water interactables on
                              water/void/pit/tide/phantom or inside '#' walls
                              (distinguishing wall-embedded switch_eye vs floating-in-void)
  5. DOOR_FIT_AUDIT         - full door inventory + floating doors, wall-overlapping doors,
                              and gap-width mismatches
  6. GROUND_PNG_SYNC        - verifies luxel/art/islands/{isl}/{reg}_ground.png exists and
                              its PNG IHDR dimensions match width*tile_size x height*tile_size

CLI:
  python3 tools/design_critic/visual_coherence_audit.py audit_all [--json <path>] [--report <md_path>]
  python3 tools/design_critic/visual_coherence_audit.py audit_island <1..8>
  python3 tools/design_critic/visual_coherence_audit.py door_inventory
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
import math
import os
import struct
import sys
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple

try:
    from PIL import Image as _PILImage  # type: ignore
    HAS_PIL = True
except ImportError:
    _PILImage = None
    HAS_PIL = False

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

import design_critic as dc  # noqa: E402

# ---------------------------------------------------------------------------
# Prop & Interactable Classification Tables
# ---------------------------------------------------------------------------

WALKABLE_TILES: Set[str] = {"ground", "path", "bridge"}
HAZARD_OR_WATER_TILES: Set[str] = {"water", "void", "pit", "tide", "phantom"}
WATER_TILES: Set[str] = {"water", "tide"}
VOID_OR_PIT_TILES: Set[str] = {"void", "pit", "phantom"}
DRY_SOLID_OR_STONE_TILES: Set[str] = {"wall", "ground", "path", "bridge", "bramble", "cracked", "glass", "mirror"}

# Water-surface / shoreline props allowed on water/tide tiles
WATER_SURFACE_PROPS: Set[str] = {
    "buoy_bobbing",
    "floating_lantern_lily",
    "blooming_lotus",
    "giant_lotus_pad",
    "river_reeds",
    "cattail_reeds",
    "reflecting_star_basin",
    "tide_mirror_basin",
    # Water-native landmarks & vessels in Luxel scenery atlases
    "barnacle_piling",
    "fishing_sloop",
    "moored_skiff",
    "flooded_statue",
    "reflection_ripple_ring",
    "shipwreck_ribs",
}

# Floating arcane/void props allowed over void, pit, phantom, water, or tide
FLOATING_VOID_PROPS: Set[str] = {
    "floating_cathedral_shard",
    "floating_prism_totem",
    "shattered_mirror_shard",
}

AQUATIC_OR_FLOATING_PROPS: Set[str] = WATER_SURFACE_PROPS | FLOATING_VOID_PROPS

# Strictly aquatic props that should not sit on dry land unless adjacent to water
STRICT_AQUATIC_PROPS: Set[str] = {
    "buoy_bobbing",
    "floating_lantern_lily",
    "giant_lotus_pad",
    "fishing_sloop",
    "moored_skiff",
    "reflection_ripple_ring",
}

# Wall-mounted props allowed on a south-facing '#' wall lip directly above walkable ground
WALL_MOUNTED_PROPS: Set[str] = {
    "shattered_rose_window",
    "stained_glass_arch",
    "hanging_chimes",
    "spider_silk_banner",
    "tattered_sanctum_banner",
}

OVERHEAD_LAYERS: Set[str] = {"overhead", "over"}

# Interactables checked for SCENERY_OVERLAP (within 12px of sort scenery anchor)
OVERLAP_INTERACTABLE_KINDS: Set[str] = {
    "door",
    "ward_barrier",
    "locked_door",
    "boss_door",
    "boss_key",
    "combat_gate",
    "switch_door",
    "bridge_platform",
    "chest",
    "beacon",
    "waystone",
    "rest_shrine",
    "mirror",
    "blue_transformer",
    "transformer",
    "blue_portal",
    "portal",
    "switch_eye",
    "switch",
    "shrine",
    "great_lamp",
}

# Non-bridge / non-door / non-portal / non-water interactables checked for MISPLACED_INTERACTABLE
TERRESTRIAL_INTERACTABLE_KINDS: Set[str] = {
    "chest",
    "waystone",
    "rest_shrine",
    "beacon",
    "road_lamp",
    "brazier",
    "mirror",
    "blue_transformer",
    "transformer",
    "switch_eye",
    "switch",
    "shrine",
    "great_lamp",
    "wick_key",
    "keepers_flame",
    "lantern_pickup",
}

DOOR_KINDS: Set[str] = set(dc.DOOR_KINDS)


# ---------------------------------------------------------------------------
# Scenery Metadata & PNG IHDR Helpers
# ---------------------------------------------------------------------------

def load_scenery_catalog() -> Dict[str, Dict[str, Any]]:
    """Load luxel/art/props/island{1..8}_scenery.json prop frame & anchor info."""
    root = dc.repo_root()
    catalog: Dict[str, Dict[str, Any]] = {}
    for isl in range(1, 9):
        sheet_id = f"island{isl}_scenery"
        path = os.path.join(root, "luxel", "art", "props", f"{sheet_id}.json")
        if not os.path.exists(path):
            continue
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        props = data.get("props", {})
        if isinstance(props, dict):
            catalog[sheet_id] = props
    return catalog


def get_prop_meta(
    catalog: Dict[str, Dict[str, Any]],
    sheet: str,
    prop_name: str,
) -> Dict[str, Any]:
    sheet_key = sheet.replace(".json", "")
    if sheet_key in catalog and prop_name in catalog[sheet_key]:
        return catalog[sheet_key][prop_name]
    for props in catalog.values():
        if prop_name in props:
            return props[prop_name]
    return {}


def read_png_dimensions(png_path: str) -> Tuple[Optional[int], Optional[int], Optional[str]]:
    """Parse PNG width & height directly from the 24-byte IHDR header using stdlib."""
    try:
        with open(png_path, "rb") as f:
            header = f.read(24)
    except OSError as exc:
        return None, None, f"read error: {exc}"
    if len(header) < 24:
        return None, None, "file too short (<24 bytes)"
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        return None, None, "invalid PNG signature"
    if header[12:16] != b"IHDR":
        return None, None, f"missing IHDR chunk (got {header[12:16]!r})"
    w, h = struct.unpack(">II", header[16:24])
    if HAS_PIL and _PILImage is not None:
        try:
            with _PILImage.open(png_path) as im:
                if im.size != (w, h):
                    return w, h, f"PIL size {im.size} != IHDR {(w, h)}"
        except Exception as exc:
            return w, h, f"PIL verify error: {exc}"
    return int(w), int(h), None


# ---------------------------------------------------------------------------
# Grid & Door Geometry Helpers
# ---------------------------------------------------------------------------

def tile_at(region: Dict[str, Any], tx: int, ty: int) -> str:
    w, h = region["width"], region["height"]
    if tx < 0 or ty < 0 or tx >= w or ty >= h:
        return "oob"
    return region["grid"][ty][tx]


def raw_char_at(region: Dict[str, Any], tx: int, ty: int) -> str:
    rows = region.get("raw_rows", [])
    if ty < 0 or ty >= len(rows):
        return "?"
    row = rows[ty]
    if tx < 0 or tx >= len(row):
        return "?"
    return row[tx]


def pos_to_tile(region: Dict[str, Any], px: float, py: float) -> Tuple[int, int]:
    ts = max(1, int(region["tile_size"]))
    return int(math.floor(px / ts)), int(math.floor(py / ts))


def has_adjacent_tile(region: Dict[str, Any], tx: int, ty: int, target_types: Set[str], diag: bool = True) -> bool:
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            if not diag and dx != 0 and dy != 0:
                continue
            if tile_at(region, tx + dx, ty + dy) in target_types:
                return True
    return False


def resolve_door_info(it: Dict[str, Any], island_id: int, region_id: str) -> Dict[str, Any]:
    """Mirror luxel/world/interactables/door.gd setup() resolution exactly."""
    raw_kind = str(it.get("kind", "door")).strip().lower()
    props = it.get("props", {}) if isinstance(it.get("props"), dict) else {}
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

    raw_sz = props.get("size", [32, 16])
    if isinstance(raw_sz, list) and len(raw_sz) >= 2:
        sx, sy = int(round(float(raw_sz[0]))), int(round(float(raw_sz[1])))
    else:
        sx, sy = 32, 16

    if sx > sy:
        orient = "H"
    elif sy > sx:
        orient = "V"
    else:
        orient = "S"

    did = str(it.get("id", ""))
    is_light_bridge = did.startswith("bridge_of_light") or raw_type == "bridge_of_light"
    px, py = dc.interactable_pos(it)
    return {
        "island_id": island_id,
        "region_id": region_id,
        "id": did,
        "raw_kind": raw_kind,
        "raw_type": raw_type,
        "door_type": door_type,
        "is_light_bridge": is_light_bridge,
        "size": (sx, sy),
        "size_str": f"{sx}x{sy}",
        "orientation": orient,
        "pos": (px, py),
        "props": props,
    }


def _rect_tile_range(region: Dict[str, Any], x0: float, y0: float, x1: float, y1: float) -> Tuple[int, int, int, int]:
    ts = max(1, int(region["tile_size"]))
    eps = 0.01
    tx0 = int(math.floor((x0 + eps) / ts))
    ty0 = int(math.floor((y0 + eps) / ts))
    tx1 = int(math.floor((x1 - eps) / ts))
    ty1 = int(math.floor((y1 - eps) / ts))
    if tx1 < tx0:
        tx1 = tx0
    if ty1 < ty0:
        ty1 = ty0
    return tx0, ty0, tx1, ty1


def _is_frame_anchor_tile(tt: str) -> bool:
    """True when a tile forms a solid/impassable jamb or boundary that prevents walking around a door."""
    return tt not in WALKABLE_TILES


def _infer_square_orientation(region: Dict[str, Any], tx0: int, ty0: int, tx1: int, ty1: int) -> str:
    """For square (e.g. 16x16) doors, infer whether it blocks N-S ('H') or E-W ('V') passage."""
    h_jambs = (
        any(_is_frame_anchor_tile(tile_at(region, tx0 - 1, y)) for y in range(ty0, ty1 + 1))
        and any(_is_frame_anchor_tile(tile_at(region, tx1 + 1, y)) for y in range(ty0, ty1 + 1))
    )
    v_jambs = (
        any(_is_frame_anchor_tile(tile_at(region, x, ty0 - 1)) for x in range(tx0, tx1 + 1))
        and any(_is_frame_anchor_tile(tile_at(region, x, ty1 + 1)) for x in range(tx0, tx1 + 1))
    )
    if h_jambs and not v_jambs:
        return "H"
    if v_jambs and not h_jambs:
        return "V"
    # Fallback: check which perpendicular axis has walkable corridor
    ns_open = (
        any(tile_at(region, x, ty0 - 1) in WALKABLE_TILES for x in range(tx0, tx1 + 1))
        or any(tile_at(region, x, ty1 + 1) in WALKABLE_TILES for x in range(tx0, tx1 + 1))
    )
    ew_open = (
        any(tile_at(region, tx0 - 1, y) in WALKABLE_TILES for y in range(ty0, ty1 + 1))
        or any(tile_at(region, tx1 + 1, y) in WALKABLE_TILES for y in range(ty0, ty1 + 1))
    )
    if ns_open and not ew_open:
        return "H"
    if ew_open and not ns_open:
        return "V"
    return "H"


def _measure_opening_gap(
    region: Dict[str, Any],
    orient: str,
    tx_center: int,
    ty_center: int,
    tx0: int,
    ty0: int,
    tx1: int,
    ty1: int,
) -> Tuple[Optional[int], bool, bool]:
    """Measure contiguous non-wall opening width (in tiles) along door span axis.

    Returns (gap_tiles_or_None, bounded_neg, bounded_pos).
    """
    w, h = region["width"], region["height"]
    max_scan = 8
    if orient == "H":
        # Pick the row within [ty0..ty1] with the fewest wall tiles (the actual doorway row)
        best_y = ty_center
        best_non_wall = -1
        for y in range(ty0, ty1 + 1):
            cnt = sum(1 for x in range(tx0, tx1 + 1) if tile_at(region, x, y) != "wall")
            if cnt > best_non_wall:
                best_non_wall = cnt
                best_y = y
        if tile_at(region, tx_center, best_y) == "wall":
            # Try finding any non-wall tile inside [tx0..tx1]
            seed_x = next((x for x in range(tx0, tx1 + 1) if tile_at(region, x, best_y) != "wall"), None)
            if seed_x is None:
                return 0, True, True
        else:
            seed_x = tx_center
        lx = seed_x
        bounded_neg = False
        while lx > 0 and (seed_x - lx) < max_scan:
            if _is_frame_anchor_tile(tile_at(region, lx - 1, best_y)):
                bounded_neg = True
                break
            lx -= 1
        if lx == 0:
            bounded_neg = True
        rx = seed_x
        bounded_pos = False
        while rx < w - 1 and (rx - seed_x) < max_scan:
            if _is_frame_anchor_tile(tile_at(region, rx + 1, best_y)):
                bounded_pos = True
                break
            rx += 1
        if rx == w - 1:
            bounded_pos = True
        return (rx - lx + 1), bounded_neg, bounded_pos
    else:
        best_x = tx_center
        best_non_wall = -1
        for x in range(tx0, tx1 + 1):
            cnt = sum(1 for y in range(ty0, ty1 + 1) if tile_at(region, x, y) != "wall")
            if cnt > best_non_wall:
                best_non_wall = cnt
                best_x = x
        if tile_at(region, best_x, ty_center) == "wall":
            seed_y = next((y for y in range(ty0, ty1 + 1) if tile_at(region, best_x, y) != "wall"), None)
            if seed_y is None:
                return 0, True, True
        else:
            seed_y = ty_center
        uy = seed_y
        bounded_neg = False
        while uy > 0 and (seed_y - uy) < max_scan:
            if _is_frame_anchor_tile(tile_at(region, best_x, uy - 1)):
                bounded_neg = True
                break
            uy -= 1
        if uy == 0:
            bounded_neg = True
        dy = seed_y
        bounded_pos = False
        while dy < h - 1 and (dy - seed_y) < max_scan:
            if _is_frame_anchor_tile(tile_at(region, best_x, dy + 1)):
                bounded_pos = True
                break
            dy += 1
        if dy == h - 1:
            bounded_pos = True
        return (dy - uy + 1), bounded_neg, bounded_pos


# ---------------------------------------------------------------------------
# Region Audit Logic
# ---------------------------------------------------------------------------

def audit_region(
    region: Dict[str, Any],
    catalog: Dict[str, Dict[str, Any]],
) -> Dict[str, Any]:
    isl = int(region["island_id"])
    rid = str(region["id"])
    ts = int(region["tile_size"])
    w, h = int(region["width"]), int(region["height"])

    findings: List[Dict[str, Any]] = []
    doors: List[Dict[str, Any]] = []

    def add_finding(
        check: str,
        subtype: str,
        severity: str,
        subject: str,
        pos: Tuple[float, float],
        detail: str,
        extra: Optional[Dict[str, Any]] = None,
    ) -> None:
        item: Dict[str, Any] = {
            "island_id": isl,
            "region_id": rid,
            "check": check,
            "subtype": subtype,
            "severity": severity,
            "subject": subject,
            "pos": [round(pos[0], 1), round(pos[1], 1)],
            "detail": detail,
        }
        if extra:
            item.update(extra)
        findings.append(item)

    # Precompute interactable list and door rects for SCENERY_OVERLAP
    overlap_targets: List[Tuple[str, str, Tuple[float, float], Optional[Tuple[float, float, float, float]]]] = []
    for it in region["interactables"]:
        k = str(it.get("kind", "")).strip().lower()
        if k in OVERLAP_INTERACTABLE_KINDS:
            px, py = dc.interactable_pos(it)
            drect: Optional[Tuple[float, float, float, float]] = None
            if k in DOOR_KINDS:
                pr = it.get("props", {}) if isinstance(it.get("props"), dict) else {}
                raw_sz = pr.get("size", [32, 16])
                sx = float(raw_sz[0]) if isinstance(raw_sz, list) and len(raw_sz) >= 2 else 32.0
                sy = float(raw_sz[1]) if isinstance(raw_sz, list) and len(raw_sz) >= 2 else 16.0
                drect = (px - sx * 0.5, py - sy * 0.5, px + sx * 0.5, py + sy * 0.5)
            overlap_targets.append((str(it.get("id", k)), k, (px, py), drect))

    spawn_pos = tuple(region.get("spawn_vec", (0.0, 0.0)))
    exits = region.get("exits", [])

    # -----------------------------------------------------------------------
    # 1, 2, 3: Scenery Audits (FLOATING_SCENERY, WALL_CLIPPING_SCENERY, SCENERY_OVERLAP)
    # -----------------------------------------------------------------------
    for idx, sc in enumerate(region.get("scenery", [])):
        prop = str(sc.get("prop", "")).strip()
        sheet = str(sc.get("sheet", "")).strip()
        layer = str(sc.get("layer", "sort")).strip().lower()
        raw_pos = sc.get("pos", [0, 0])
        px = float(raw_pos[0]) if isinstance(raw_pos, list) and len(raw_pos) >= 2 else 0.0
        py = float(raw_pos[1]) if isinstance(raw_pos, list) and len(raw_pos) >= 2 else 0.0
        tx, ty = pos_to_tile(region, px, py)
        tt = tile_at(region, tx, ty)
        rch = raw_char_at(region, tx, ty)
        meta = get_prop_meta(catalog, sheet, prop)
        frame = meta.get("frame")
        anchor = meta.get("anchor")
        meta_extra: Dict[str, Any] = {
            "prop": prop,
            "sheet": sheet,
            "layer": layer,
            "tile": [tx, ty],
            "tile_type": tt,
            "raw_char": rch,
            "scenery_index": idx,
        }
        if frame:
            meta_extra["frame"] = frame
        if anchor:
            meta_extra["anchor"] = anchor

        # Check 1: FLOATING_SCENERY
        if layer not in OVERHEAD_LAYERS:
            if tt in HAZARD_OR_WATER_TILES or tt == "oob":
                allowed = False
                if tt in WATER_TILES and prop in AQUATIC_OR_FLOATING_PROPS:
                    allowed = True
                elif tt in VOID_OR_PIT_TILES and prop in FLOATING_VOID_PROPS:
                    allowed = True
                if not allowed:
                    add_finding(
                        "FLOATING_SCENERY",
                        "terrestrial_on_hazard",
                        "high",
                        prop,
                        (px, py),
                        f"{prop} (layer={layer}) anchored on {tt} ('{rch}') at tile ({tx},{ty})",
                        meta_extra,
                    )
            elif prop in STRICT_AQUATIC_PROPS and tt in DRY_SOLID_OR_STONE_TILES:
                if tt == "wall" or not has_adjacent_tile(region, tx, ty, WATER_TILES, diag=True):
                    add_finding(
                        "FLOATING_SCENERY",
                        "aquatic_on_dry_land",
                        "medium",
                        prop,
                        (px, py),
                        f"strictly aquatic {prop} on dry {tt} ('{rch}') at tile ({tx},{ty}) not adjacent to water",
                        meta_extra,
                    )

        # Check 2: WALL_CLIPPING_SCENERY
        if layer not in OVERHEAD_LAYERS and tt == "wall":
            south_tt = tile_at(region, tx, ty + 1)
            is_valid_wall_mount = prop in WALL_MOUNTED_PROPS and south_tt in WALKABLE_TILES
            if not is_valid_wall_mount:
                reason = (
                    f"wall-mounted {prop} on '#' wall but south tile ({tx},{ty+1}) is {south_tt}, not walkable"
                    if prop in WALL_MOUNTED_PROPS
                    else f"{prop} (layer={layer}) anchored inside '#' wall at tile ({tx},{ty}), south={south_tt}"
                )
                extra2 = dict(meta_extra)
                extra2["south_tile"] = south_tt
                add_finding(
                    "WALL_CLIPPING_SCENERY",
                    "wall_mount_bad_face" if prop in WALL_MOUNTED_PROPS else "prop_in_wall",
                    "high",
                    prop,
                    (px, py),
                    reason,
                    extra2,
                )

        # Check 3: SCENERY_OVERLAP (sort props only)
        if layer == "sort":
            # 3a: Within 12px of key interactables (or inside door rect)
            for it_id, it_kind, (ix, iy), drect in overlap_targets:
                dist = math.hypot(px - ix, py - iy)
                in_door_rect = (
                    drect is not None
                    and drect[0] <= px <= drect[2]
                    and drect[1] <= py <= drect[3]
                )
                if dist <= 12.0 or in_door_rect:
                    extra3 = dict(meta_extra)
                    extra3["target_id"] = it_id
                    extra3["target_kind"] = it_kind
                    extra3["distance_px"] = round(dist, 1)
                    add_finding(
                        "SCENERY_OVERLAP",
                        "overlap_interactable",
                        "high" if dist <= 8.0 or in_door_rect else "medium",
                        prop,
                        (px, py),
                        f"{prop} overlaps {it_kind} '{it_id}' (dist={dist:.1f}px"
                        + (", inside door rect" if in_door_rect else "")
                        + ")",
                        extra3,
                    )

            # 3b: Within 14px of spawn
            sdist = math.hypot(px - spawn_pos[0], py - spawn_pos[1])
            if sdist <= 14.0:
                extra3s = dict(meta_extra)
                extra3s["distance_px"] = round(sdist, 1)
                add_finding(
                    "SCENERY_OVERLAP",
                    "overlap_spawn",
                    "medium",
                    prop,
                    (px, py),
                    f"{prop} within {sdist:.1f}px of region spawn {list(spawn_pos)}",
                    extra3s,
                )

            # 3c: Directly blocking an exit rect
            for ex in exits:
                er = ex.get("rect", [])
                if not isinstance(er, list) or len(er) < 4:
                    continue
                ex0, ey0, ew, eh = float(er[0]), float(er[1]), float(er[2]), float(er[3])
                if ex0 <= px <= ex0 + ew and ey0 <= py <= ey0 + eh:
                    extra3e = dict(meta_extra)
                    extra3e["exit_id"] = str(ex.get("id", ""))
                    extra3e["exit_rect"] = er
                    add_finding(
                        "SCENERY_OVERLAP",
                        "blocking_exit",
                        "high",
                        prop,
                        (px, py),
                        f"{prop} anchored directly inside exit '{ex.get('id', '')}' rect {er}",
                        extra3e,
                    )

    # -----------------------------------------------------------------------
    # 4: MISPLACED_INTERACTABLE
    # -----------------------------------------------------------------------
    for it in region.get("interactables", []):
        k = str(it.get("kind", "")).strip().lower()
        it_id = str(it.get("id", k))
        if k not in TERRESTRIAL_INTERACTABLE_KINDS:
            continue
        px, py = dc.interactable_pos(it)
        tx, ty = pos_to_tile(region, px, py)
        tt = tile_at(region, tx, ty)
        rch = raw_char_at(region, tx, ty)
        extra4: Dict[str, Any] = {
            "id": it_id,
            "kind": k,
            "tile": [tx, ty],
            "tile_type": tt,
            "raw_char": rch,
        }
        if tt in HAZARD_OR_WATER_TILES or tt == "oob":
            subtype = "floating_in_void" if k in ("switch_eye", "switch") else f"on_{tt}"
            add_finding(
                "MISPLACED_INTERACTABLE",
                subtype,
                "high",
                f"{k}:{it_id}",
                (px, py),
                f"{k} '{it_id}' placed on {tt} ('{rch}') at tile ({tx},{ty})",
                extra4,
            )
        elif tt == "wall":
            if k in ("switch_eye", "switch"):
                has_open = has_adjacent_tile(region, tx, ty, WALKABLE_TILES | WATER_TILES | VOID_OR_PIT_TILES, diag=False)
                subtype = "wall_embedded_switch" if has_open else "wall_buried_switch"
                sev = "info" if has_open else "high"
                detail = (
                    f"switch_eye '{it_id}' wall-embedded on '#' face at ({tx},{ty}) (reachable by bolt)"
                    if has_open
                    else f"switch_eye '{it_id}' buried deep inside '#' wall at ({tx},{ty})"
                )
                add_finding("MISPLACED_INTERACTABLE", subtype, sev, f"{k}:{it_id}", (px, py), detail, extra4)
            else:
                add_finding(
                    "MISPLACED_INTERACTABLE",
                    "in_wall",
                    "high",
                    f"{k}:{it_id}",
                    (px, py),
                    f"{k} '{it_id}' placed inside solid '#' wall at tile ({tx},{ty})",
                    extra4,
                )

    # -----------------------------------------------------------------------
    # 5: DOOR_FIT_AUDIT
    # -----------------------------------------------------------------------
    for it in region.get("interactables", []):
        k = str(it.get("kind", "")).strip().lower()
        if k not in DOOR_KINDS:
            continue
        dinfo = resolve_door_info(it, isl, rid)
        px, py = dinfo["pos"]
        sx, sy = dinfo["size"]
        orient = dinfo["orientation"]
        tx_c, ty_c = pos_to_tile(region, px, py)
        tx0, ty0, tx1, ty1 = _rect_tile_range(region, px - sx * 0.5, py - sy * 0.5, px + sx * 0.5, py + sy * 0.5)
        eff_orient = _infer_square_orientation(region, tx0, ty0, tx1, ty1) if orient == "S" else orient

        covered_tiles = [tile_at(region, x, y) for y in range(ty0, ty1 + 1) for x in range(tx0, tx1 + 1)]
        wall_tiles = sum(1 for t in covered_tiles if t == "wall")
        hazard_tiles = sum(1 for t in covered_tiles if t in HAZARD_OR_WATER_TILES)
        center_tile = tile_at(region, tx_c, ty_c)

        is_bridge_exempt = (
            dinfo["door_type"] == "bridge_platform"
            or dinfo["is_light_bridge"]
            or (dinfo["door_type"] == "ward_barrier" and max(sx, sy) >= 48 and hazard_tiles > 0)
        )

        fit_flags: List[str] = []
        # 5a: Floating door check (walkable on BOTH perpendicular sides of the door's span)
        if not is_bridge_exempt:
            if eff_orient == "H":
                neg_anchored = any(_is_frame_anchor_tile(tile_at(region, tx0 - 1, y)) for y in range(ty0, ty1 + 1))
                pos_anchored = any(_is_frame_anchor_tile(tile_at(region, tx1 + 1, y)) for y in range(ty0, ty1 + 1))
            else:
                neg_anchored = any(_is_frame_anchor_tile(tile_at(region, x, ty0 - 1)) for x in range(tx0, tx1 + 1))
                pos_anchored = any(_is_frame_anchor_tile(tile_at(region, x, ty1 + 1)) for x in range(tx0, tx1 + 1))

            if not neg_anchored and not pos_anchored:
                fit_flags.append("FLOATING_DOOR")
                add_finding(
                    "DOOR_FIT_AUDIT",
                    "floating_door",
                    "high",
                    f"door:{dinfo['id']}",
                    (px, py),
                    f"{dinfo['door_type']} ({dinfo['raw_type']}) {dinfo['size_str']} {orient} sits in open floor "
                    f"(walkable on both ends outside tiles [{tx0}..{tx1},{ty0}..{ty1}])",
                    {
                        "door_id": dinfo["id"],
                        "door_type": dinfo["door_type"],
                        "raw_type": dinfo["raw_type"],
                        "size": dinfo["size_str"],
                        "orientation": orient,
                    },
                )

            # 5b: Wall overlap check
            total_cov = max(1, len(covered_tiles))
            wall_ratio = wall_tiles / float(total_cov)
            if center_tile == "wall" or wall_ratio > 0.5:
                fit_flags.append("WALL_OVERLAP")
                add_finding(
                    "DOOR_FIT_AUDIT",
                    "door_wall_overlap",
                    "high" if center_tile == "wall" else "medium",
                    f"door:{dinfo['id']}",
                    (px, py),
                    f"{dinfo['door_type']} ({dinfo['size_str']} {orient}) overlaps solid '#' wall "
                    f"(center={center_tile}, wall_tiles={wall_tiles}/{total_cov})",
                    {
                        "door_id": dinfo["id"],
                        "door_type": dinfo["door_type"],
                        "raw_type": dinfo["raw_type"],
                        "size": dinfo["size_str"],
                        "orientation": orient,
                        "center_tile": center_tile,
                        "wall_tiles": wall_tiles,
                        "covered_tiles": total_cov,
                    },
                )

            # 5c: Gap width mismatch check (skip if already floating in open floor)
            if "FLOATING_DOOR" not in fit_flags:
                gap_tiles, b_neg, b_pos = _measure_opening_gap(region, eff_orient, tx_c, ty_c, tx0, ty0, tx1, ty1)
                span_px = sx if eff_orient == "H" else sy
                if gap_tiles is not None and gap_tiles > 0 and b_neg and b_pos:
                    gap_px = gap_tiles * ts
                    if abs(gap_px - span_px) >= ts:
                        fit_flags.append("GAP_MISMATCH")
                        add_finding(
                            "DOOR_FIT_AUDIT",
                            "door_gap_mismatch",
                            "medium" if span_px > gap_px else "high",
                            f"door:{dinfo['id']}",
                            (px, py),
                            f"{dinfo['door_type']} ({dinfo['size_str']} {orient}) span={span_px}px vs opening gap={gap_px}px "
                            f"({'wider than gap' if span_px > gap_px else 'narrower than gap — bypassable!'})",
                            {
                                "door_id": dinfo["id"],
                                "door_type": dinfo["door_type"],
                                "raw_type": dinfo["raw_type"],
                                "size": dinfo["size_str"],
                                "orientation": orient,
                                "span_px": span_px,
                                "gap_px": gap_px,
                            },
                        )

        dinfo["fit_flags"] = fit_flags
        dinfo["center_tile"] = center_tile
        doors.append(dinfo)

    # -----------------------------------------------------------------------
    # 6: GROUND_PNG_SYNC
    # -----------------------------------------------------------------------
    png_path = os.path.join(dc.repo_root(), "luxel", "art", "islands", str(isl), f"{rid}_ground.png")
    expected_w = w * ts
    expected_h = h * ts
    png_ok = True
    png_size: Optional[Tuple[int, int]] = None
    if not os.path.exists(png_path):
        png_ok = False
        add_finding(
            "GROUND_PNG_SYNC",
            "missing_ground_png",
            "high",
            f"{rid}_ground.png",
            (0.0, 0.0),
            f"Missing painted ground PNG: {os.path.relpath(png_path, dc.repo_root())}",
            {"expected": [expected_w, expected_h]},
        )
    else:
        pw, ph, err = read_png_dimensions(png_path)
        if err is not None or pw is None or ph is None:
            png_ok = False
            add_finding(
                "GROUND_PNG_SYNC",
                "invalid_ground_png",
                "high",
                f"{rid}_ground.png",
                (0.0, 0.0),
                f"Corrupt or unreadable PNG ({err})",
                {"expected": [expected_w, expected_h]},
            )
        else:
            png_size = (pw, ph)
            if (pw, ph) != (expected_w, expected_h):
                png_ok = False
                add_finding(
                    "GROUND_PNG_SYNC",
                    "png_size_mismatch",
                    "high",
                    f"{rid}_ground.png",
                    (0.0, 0.0),
                    f"PNG dimensions {pw}x{ph} != map dimensions {expected_w}x{expected_h} ({w}x{h} tiles @ {ts}px)",
                    {"actual": [pw, ph], "expected": [expected_w, expected_h]},
                )

    return {
        "island_id": isl,
        "region_id": rid,
        "width": w,
        "height": h,
        "tile_size": ts,
        "scenery_count": len(region.get("scenery", [])),
        "interactable_count": len(region.get("interactables", [])),
        "door_count": len(doors),
        "png_ok": png_ok,
        "png_size": list(png_size) if png_size else None,
        "findings": findings,
        "doors": doors,
    }


def audit_islands(island_ids: Sequence[int]) -> Dict[str, Any]:
    catalog = load_scenery_catalog()
    regions_out: List[Dict[str, Any]] = []
    all_findings: List[Dict[str, Any]] = []
    all_doors: List[Dict[str, Any]] = []

    for isl in island_ids:
        for rid, mp, jp in dc.list_island_regions(isl):
            reg = dc.parse_region(mp, jp)
            res = audit_region(reg, catalog)
            regions_out.append(res)
            all_findings.extend(res["findings"])
            all_doors.extend(res["doors"])

    by_check = Counter(f["check"] for f in all_findings)
    by_subtype = Counter((f["check"], f["subtype"]) for f in all_findings)
    by_island = Counter(f["island_id"] for f in all_findings)
    by_severity = Counter(f["severity"] for f in all_findings)

    return {
        "pillow_available": HAS_PIL,
        "islands_scanned": list(island_ids),
        "regions_scanned": len(regions_out),
        "scenery_total": sum(r["scenery_count"] for r in regions_out),
        "interactables_total": sum(r["interactable_count"] for r in regions_out),
        "doors_total": len(all_doors),
        "findings_total": len(all_findings),
        "counts_by_check": {
            k: by_check.get(k, 0)
            for k in (
                "FLOATING_SCENERY",
                "WALL_CLIPPING_SCENERY",
                "SCENERY_OVERLAP",
                "MISPLACED_INTERACTABLE",
                "DOOR_FIT_AUDIT",
                "GROUND_PNG_SYNC",
            )
        },
        "counts_by_subtype": {f"{c}:{s}": cnt for (c, s), cnt in sorted(by_subtype.items())},
        "counts_by_severity": dict(by_severity),
        "counts_by_island": {str(i): by_island.get(i, 0) for i in island_ids},
        "regions": regions_out,
        "findings": all_findings,
        "doors": all_doors,
    }


# ---------------------------------------------------------------------------
# Formatting (Markdown Report & Console Summaries)
# ---------------------------------------------------------------------------

def render_markdown_report(summary: Dict[str, Any]) -> str:
    lines: List[str] = []
    lines.append("# Luxel Visual Coherence Audit Report")
    lines.append("")
    lines.append(
        f"- **Regions scanned:** {summary['regions_scanned']} "
        f"(Islands {', '.join(str(i) for i in summary['islands_scanned'])})"
    )
    lines.append(f"- **Scenery props scanned:** {summary['scenery_total']}")
    lines.append(f"- **Interactables scanned:** {summary['interactables_total']}")
    lines.append(f"- **Doors audited:** {summary['doors_total']}")
    lines.append(f"- **Total findings:** {summary['findings_total']}")
    lines.append(f"- **Pillow verification active:** {'yes' if summary['pillow_available'] else 'no (stdlib IHDR)'}")
    lines.append("")

    lines.append("## Summary by Check")
    lines.append("")
    lines.append("| Check | Findings |")
    lines.append("|---|---:|")
    for chk, cnt in summary["counts_by_check"].items():
        lines.append(f"| `{chk}` | {cnt} |")
    lines.append(f"| **TOTAL** | **{summary['findings_total']}** |")
    lines.append("")

    if summary["counts_by_subtype"]:
        lines.append("## Breakdown by Subtype")
        lines.append("")
        lines.append("| Check : Subtype | Count |")
        lines.append("|---|---:|")
        for key, cnt in summary["counts_by_subtype"].items():
            lines.append(f"| `{key}` | {cnt} |")
        lines.append("")

    lines.append("## Findings by Island")
    lines.append("")
    lines.append("| Island | Regions | FLOATING | WALL_CLIP | OVERLAP | MISPLACED | DOOR_FIT | PNG_SYNC | Total |")
    lines.append("|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for isl in summary["islands_scanned"]:
        regs = [r for r in summary["regions"] if r["island_id"] == isl]
        fs = [f for f in summary["findings"] if f["island_id"] == isl]
        c = Counter(f["check"] for f in fs)
        lines.append(
            f"| Island {isl} | {len(regs)} | {c['FLOATING_SCENERY']} | {c['WALL_CLIPPING_SCENERY']} | "
            f"{c['SCENERY_OVERLAP']} | {c['MISPLACED_INTERACTABLE']} | {c['DOOR_FIT_AUDIT']} | "
            f"{c['GROUND_PNG_SYNC']} | **{len(fs)}** |"
        )
    lines.append("")

    # Door inventory grouped table
    lines.append("## Door Inventory Summary (by Island / Type / Size / Orientation)")
    lines.append("")
    lines.append("| Island | Door Type | Raw Types | Size | Orient | Count | Flagged |")
    lines.append("|---:|---|---|---|---:|---:|---:|")
    grouped: Dict[Tuple[int, str, str, str], List[Dict[str, Any]]] = defaultdict(list)
    for d in summary["doors"]:
        grouped[(d["island_id"], d["door_type"], d["size_str"], d["orientation"])].append(d)
    for key in sorted(grouped.keys()):
        isl, dt, sz, ori = key
        items = grouped[key]
        raws = ",".join(sorted({x["raw_type"] for x in items}))
        flagged = sum(1 for x in items if x["fit_flags"])
        lines.append(f"| {isl} | `{dt}` | `{raws}` | `{sz}` | {ori} | {len(items)} | {flagged} |")
    lines.append("")

    # Detailed findings per check
    for chk in (
        "FLOATING_SCENERY",
        "WALL_CLIPPING_SCENERY",
        "SCENERY_OVERLAP",
        "MISPLACED_INTERACTABLE",
        "DOOR_FIT_AUDIT",
        "GROUND_PNG_SYNC",
    ):
        chk_items = [f for f in summary["findings"] if f["check"] == chk]
        lines.append(f"## {chk} ({len(chk_items)})")
        lines.append("")
        if not chk_items:
            lines.append("_No findings._")
            lines.append("")
            continue
        lines.append("| Island | Region | Severity | Subtype | Subject | Pos | Detail |")
        lines.append("|---:|---|---|---|---|---|---|")
        for f in chk_items:
            pos_str = f"({f['pos'][0]:.0f}, {f['pos'][1]:.0f})"
            detail_esc = f["detail"].replace("|", "\\|")
            lines.append(
                f"| {f['island_id']} | `{f['region_id']}` | {f['severity']} | `{f['subtype']}` | "
                f"`{f['subject']}` | {pos_str} | {detail_esc} |"
            )
        lines.append("")

    return "\n".join(lines)


def print_summary(summary: Dict[str, Any]) -> None:
    print(
        f"Visual Coherence Audit: regions={summary['regions_scanned']} "
        f"scenery={summary['scenery_total']} interactables={summary['interactables_total']} "
        f"doors={summary['doors_total']} total_findings={summary['findings_total']} "
        f"(PIL={'yes' if summary['pillow_available'] else 'no'})"
    )
    for chk, cnt in summary["counts_by_check"].items():
        print(f"  {chk:24s}: {cnt}")
    if summary["counts_by_subtype"]:
        print("Subtypes:")
        for key, cnt in summary["counts_by_subtype"].items():
            print(f"  {key:44s}: {cnt}")
    print("By Island:")
    for isl in summary["islands_scanned"]:
        fs = [f for f in summary["findings"] if f["island_id"] == isl]
        c = Counter(f["check"] for f in fs)
        print(
            f"  Island {isl}: total={len(fs):3d} "
            f"(FLOAT={c['FLOATING_SCENERY']}, WALL={c['WALL_CLIPPING_SCENERY']}, "
            f"OVLP={c['SCENERY_OVERLAP']}, MISP={c['MISPLACED_INTERACTABLE']}, "
            f"DOOR={c['DOOR_FIT_AUDIT']}, PNG={c['GROUND_PNG_SYNC']})"
        )


def print_door_inventory(summary: Dict[str, Any]) -> None:
    doors = summary["doors"]
    print(f"=== LUXEL DOOR INVENTORY ({len(doors)} doors across {summary['regions_scanned']} regions) ===")
    print(f"{'Isl':>3} | {'Region':<18} | {'Door ID':<28} | {'Type':<15} | {'Raw Type':<15} | {'Size':<6} | {'O':<1} | {'Pos':<12} | Flags")
    print("-" * 126)
    for d in doors:
        pos_s = f"{d['pos'][0]:.0f},{d['pos'][1]:.0f}"
        flags_s = ",".join(d["fit_flags"]) if d["fit_flags"] else "ok"
        print(
            f"{d['island_id']:>3} | {d['region_id']:<18} | {d['id']:<28} | {d['door_type']:<15} | "
            f"{d['raw_type']:<15} | {d['size_str']:<6} | {d['orientation']:<1} | {pos_s:<12} | {flags_s}"
        )

    print("\n=== GROUPED BY (ISLAND, DOOR_TYPE, SIZE, ORIENTATION) ===")
    grouped: Dict[Tuple[int, str, str, str], List[Dict[str, Any]]] = defaultdict(list)
    for d in doors:
        grouped[(d["island_id"], d["door_type"], d["size_str"], d["orientation"])].append(d)
    print(f"{'Isl':>3} | {'Door Type':<16} | {'Size':<6} | {'O':<1} | {'Count':>5} | {'Flagged':>7}")
    print("-" * 52)
    for (isl, dt, sz, ori), items in sorted(grouped.items()):
        flagged = sum(1 for x in items if x["fit_flags"])
        print(f"{isl:>3} | {dt:<16} | {sz:<6} | {ori:<1} | {len(items):>5} | {flagged:>7}")

    print("\n=== TOTALS BY DOOR_TYPE ===")
    by_type = Counter(d["door_type"] for d in doors)
    for dt, cnt in by_type.most_common():
        print(f"  {dt:<18s}: {cnt}")


# ---------------------------------------------------------------------------
# CLI Entry Point
# ---------------------------------------------------------------------------

def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Luxel Symbolic Visual Coherence Auditor")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_all = sub.add_parser("audit_all", help="Audit all 8 islands (81 regions)")
    p_all.add_argument("--json", dest="json_out", default="", help="Write full JSON output path")
    p_all.add_argument("--report", dest="report_out", default="", help="Write Markdown report path")

    p_isl = sub.add_parser("audit_island", help="Audit a single island (1..8)")
    p_isl.add_argument("island_id", type=int, choices=range(1, 9))
    p_isl.add_argument("--json", dest="json_out", default="", help="Write JSON output path")

    sub.add_parser("door_inventory", help="Print full door inventory across all 81 regions")

    args = parser.parse_args(argv)

    if args.cmd == "audit_all":
        summary = audit_islands(list(range(1, 9)))
        print_summary(summary)
        if args.json_out:
            os.makedirs(os.path.dirname(os.path.abspath(args.json_out)), exist_ok=True)
            with open(args.json_out, "w", encoding="utf-8") as f:
                json.dump(summary, f, indent=2)
            print(f"Wrote JSON: {args.json_out}")
        if args.report_out:
            os.makedirs(os.path.dirname(os.path.abspath(args.report_out)), exist_ok=True)
            md = render_markdown_report(summary)
            with open(args.report_out, "w", encoding="utf-8") as f:
                f.write(md)
            print(f"Wrote Markdown report: {args.report_out}")
        return 0

    if args.cmd == "audit_island":
        summary = audit_islands([args.island_id])
        print_summary(summary)
        if summary["findings"]:
            print(f"\nDetailed findings for Island {args.island_id}:")
            for f in summary["findings"]:
                print(
                    f"  [{f['check']}/{f['subtype']}] {f['region_id']} "
                    f"@({f['pos'][0]:.0f},{f['pos'][1]:.0f}) {f['subject']}: {f['detail']}"
                )
        if args.json_out:
            os.makedirs(os.path.dirname(os.path.abspath(args.json_out)), exist_ok=True)
            with open(args.json_out, "w", encoding="utf-8") as f:
                json.dump(summary, f, indent=2)
        return 0

    if args.cmd == "door_inventory":
        summary = audit_islands(list(range(1, 9)))
        print_door_inventory(summary)
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
