#!/usr/bin/env python3
"""Luxel Epic static room linter (Python 3 stdlib only, fast).

Usage:
  python3 tools/epic/room_lint.py --all [--strict] [--require-design] [--json [PATH]]
  python3 tools/epic/room_lint.py --island 2 --dungeon lighthouse
  python3 tools/epic/room_lint.py --region 2:lighthouse_r5 --fixtures tests/luxel/fixtures
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict, deque
import glob
import hashlib
import json
import math
import os
from pathlib import Path
import re
import struct
import sys
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple
import zlib

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TILE_SIZE = 16
MAX_PX_W = 2560
MAX_PX_H = 1440

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
    "M": "mirror",
    "D": "carpet",
    "S": "stairs",
    "H": "grate",
    "R": "rail",
    "F": "foliage",
    " ": "void",
}

KNOWN_TILE_TYPES: Set[str] = {
    "ground", "wall", "path", "water", "pit", "void", "bramble", "cracked",
    "tide", "phantom", "bridge", "glass", "mirror", "obsidian", "web",
    "floor", "sand", "grass", "stone", "spawn", "door", "shallow",
    "grate", "rail", "carpet", "stairs", "foliage",
}

WALKABLE_BASE: Set[str] = {
    "ground", "path", "bridge", "floor", "sand", "grass", "stone", "spawn",
    "door", "shallow", "carpet", "stairs",
}
HAZARD_TILES: Set[str] = {"pit", "void", "water", "tide", "phantom"}
SIGHT_BLOCKING: Set[str] = {"wall", "bramble", "cracked", "glass", "mirror"}

LAST_LIGHT_RGB: Set[Tuple[int, int, int]] = {
    (0x0D, 0x0B, 0x1E), (0x21, 0x1A, 0x3B), (0x3D, 0x2C, 0x5C), (0x6A, 0x3D, 0x6F),
    (0xA0, 0x46, 0x6A), (0xE2, 0x72, 0x5B), (0xF5, 0xA9, 0x6A), (0xFF, 0xD9, 0x8C),
    (0xFF, 0xF4, 0xDC), (0x1D, 0x3D, 0x4C), (0x2B, 0x6B, 0x68), (0x4C, 0x9E, 0x78),
    (0xA3, 0xCF, 0x7D), (0x26, 0x38, 0x73), (0x3E, 0x6D, 0xB0), (0x78, 0xA9, 0xDA),
    (0xC7, 0xE5, 0xEF), (0x8A, 0x6E, 0x91), (0xC2, 0xA7, 0xAE), (0xEC, 0x9F, 0xA8),
}

# Frozen CONTRACTS.md E0-2 / E0-3 / E0-5 kinds so new rooms pass lint before/after pack registration
CONTRACT_INTERACTABLES: Set[str] = {
    "push_block", "moving_platform", "conveyor", "spinner", "crumble_floor",
    "bounce_bloom", "gravity_well", "wind_zone", "spike_floor", "pull_ring",
    "carry_orb", "one_way_gate", "mover_wall", "vehicle_skiff", "vehicle_cart",
    "rotor", "tilt_group",
    "pressure_plate", "timed_brazier", "crystal_toggle", "toggle_block",
    "beam_emitter", "beam_sensor", "turret_eye", "bell", "tone_door",
    "light_plant", "shadow_gate", "scale", "floor_sigil", "sequence_orbs",
    "mimic_statue", "logic_gate", "lantern_hook", "echo_rose", "trial_gate",
    "lore_stone", "room_anchor", "light_sensor", "color_glass", "state_lever",
    "npc", "quest_item", "moth", "pane_pickup", "shop_npc", "hub_door",
}

FLYING_ENEMIES: Set[str] = {
    "owl", "phantom_owl", "moonshade_owl", "gull_thief", "echo_moth",
    "gloam", "astronomer", "bellows_imp", "the_hush",
}

WATER_OR_FLOATING_PROPS: Set[str] = {
    "buoy_bobbing", "floating_lantern_lily", "blooming_lotus", "giant_lotus_pad",
    "cattail_reeds", "river_reeds", "bridge_balustrade", "sea_glass_arch",
    "floating_cathedral_shard", "floating_prism_totem", "tide_mirror_basin",
    "hanging_spore_lantern", "hanging_pendulum", "hanging_chimes",
    "belfry_bell_hanging", "foundry_hook_crane",
}

GLOW_PROP_RADII: Dict[str, float] = {
    "candelabra_tall": 44.0, "stone_lantern_garden": 40.0, "bridge_balustrade": 34.0,
    "coastal_lantern_post": 42.0, "fresnel_pedestal": 46.0, "buoy_bobbing": 34.0,
    "hanging_spore_lantern": 42.0, "spore_brazier_stump": 44.0, "giant_glowshroom_cluster": 36.0,
    "floating_lantern_lily": 40.0, "heron_lantern_post": 42.0, "stained_floor_pool": 36.0,
    "starlight_lantern_post": 44.0, "observatory_brazier_stand": 48.0, "armillary_sphere": 38.0,
    "astro_floor_compass": 40.0, "celestial_globe": 40.0, "reflecting_star_basin": 40.0,
    "slag_crucible": 54.0, "hearth_brazier_tall": 48.0, "ember_grate_vent": 42.0,
    "cooled_magma_vent": 36.0, "crucible_floor_seal": 40.0, "smelter_chimney": 46.0,
    "lunar_lantern_post": 42.0, "silver_brazier_stand": 46.0, "floating_prism_totem": 44.0,
    "moon_crystal_cluster": 36.0, "moon_dial_floor": 44.0, "tide_mirror_basin": 40.0,
    "crystal_archway": 42.0, "dark_candelabra": 46.0, "eclipse_brazier": 50.0,
    "void_lantern_post": 42.0, "remix_kiln_crucible": 52.0, "eclipse_floor_seal": 40.0,
    "shattered_rose_window": 44.0,
    # E0-7 Epic theme light props (mirrors LxSceneryProp.GLOW_PROPS)
    "archive_lantern_sconce": 42.0, "briar_lantern_post": 42.0, "thorn_hedge_brazier": 46.0,
    "cave_lantern_post": 42.0, "cavern_brazier_bowl": 46.0, "glow_mineral_vein": 36.0,
    "spot_lantern_rig": 48.0, "carriage_wall_lamp": 42.0, "iron_stove_brazier": 48.0,
    "train_window_slag": 40.0, "train_window_sunset": 40.0, "cinder_brazier_cage": 46.0,
    "roof_signal_lantern": 42.0, "stair_lantern_candelabra": 46.0, "bellows_hearth_stand": 48.0,
    "ember_brazier_pillar": 48.0, "molten_slag_crucible": 54.0, "slag_chimney_vent": 46.0,
    "tempering_floor_seal": 40.0, "drifting_star_lantern": 44.0, "star_chime_crystal": 36.0,
    "brass_porthole_lamp": 40.0, "hanging_ship_lantern": 44.0, "hedgerow_lamp_urn": 40.0,
    "lily_pond_lantern": 40.0, "paper_lantern_post": 42.0, "shaft_lantern_cage": 44.0,
    "amber_lantern_post": 42.0, "brass_sundial_pedestal": 38.0, "hourglass_floor_dial": 40.0,
    "black_candelabra": 44.0, "dark_reflection_pool": 38.0, "eclipse_brazier_bowl": 48.0,
    "crystal_chandelier_arch": 48.0, "lunar_brazier_bowl": 46.0, "moon_glass_urn": 38.0,
    "reflection_floor_pool": 40.0, "silver_candelabra": 46.0, "colossus_lantern_post": 44.0,
    "furnace_vent_grate": 42.0, "molten_crucible_vat": 54.0, "acid_vent_sac": 38.0,
    "whale_lantern_jar": 44.0, "lock_lantern_post": 42.0, "loom_lantern_brazier": 46.0,
    "brass_lamp_sconce": 40.0, "hearth_fireplace": 52.0, "manor_candelabra": 46.0,
    "crystal_candelabra": 46.0, "moon_lantern_urn": 42.0, "gravity_floor_seal": 40.0,
    "meteor_crystal_cluster": 38.0, "vault_lantern_brazier": 46.0, "brass_star_globe": 40.0,
    "floating_prism_lens": 42.0, "planetarium_lantern": 44.0, "zodiac_floor_dial": 42.0,
    "rain_lantern_post": 42.0, "storm_brazier_bowl": 46.0, "pearl_lantern_post": 42.0,
    "sea_anemone_glow": 36.0, "toll_clerk_lantern": 42.0, "ant_lantern_post": 42.0,
    "glow_spore_cluster": 38.0, "bell_floor_seal": 40.0, "crypt_candelabra": 46.0,
    "toll_brazier": 48.0, "belfry_torch": 44.0, "cozy_stone_hearth": 52.0,
    "moth_lantern_tree": 48.0, "pane_stained_easel": 38.0, "warm_porch_lantern": 44.0,
}

INTERACTABLE_LIGHT_RADII: Dict[str, float] = {
    "road_lamp": 58.0, "lamp": 58.0, "brazier": 54.0, "timed_brazier": 54.0,
    "beacon": 72.0, "waystone": 64.0, "shrine": 64.0, "rest_shrine": 60.0,
    "great_lamp": 84.0, "great_belfry_brazier": 84.0, "lantern_pickup": 52.0,
    "blue_portal": 40.0, "portal": 40.0, "door": 34.0, "lantern_hook": 48.0,
}

DOOR_KINDS: Set[str] = {
    "door", "ward_barrier", "locked_door", "boss_door", "boss_key",
    "combat_gate", "switch_door", "bridge_platform", "tone_door", "shadow_gate",
}
VALID_DOOR_TYPES: Set[str] = {
    "switch_door", "ward_barrier", "wick_key", "key_door", "locked_door",
    "boss_key", "boss_door", "combat_gate", "bridge_platform", "shutter",
    "shortcut_door", "bridge_of_light",
}
SIGNAL_EMITTERS: Set[str] = {
    "switch_eye", "switch", "pressure_plate", "timed_brazier", "beam_sensor",
    "light_sensor", "floor_sigil", "sequence_orbs", "logic_gate", "crystal_toggle",
}
REQUIRED_DESIGN_KEYS: Tuple[str, ...] = (
    "idea", "kind", "beat", "teaches", "decisions", "expert_s", "reward", "why",
)
VALID_DESIGN_KINDS: Set[str] = {"puzzle", "combat", "traversal", "story", "reward", "setpiece", "boss"}
VALID_DESIGN_BEATS: Set[str] = {"ki", "sho", "ten", "ketsu"}
BEAT_LMIN_FLOOR: Dict[str, int] = {"ki": 3, "sho": 5, "ten": 8, "ketsu": 8}
VALID_SOLUTION_OPS: Set[str] = {
    "goto", "shoot", "beam", "throw", "recall", "zip", "dash", "glide", "lens",
    "sunflare", "interact", "push", "rotate", "carry", "throw_carried",
    "mount", "dismount", "ring", "stand_on", "wait_phase",
    "wait", "wait_until", "clear", "expect", "expect_exit",
}

ALLOWED_PROPS_COMMON: Set[str] = {
    "zone", "size", "radius", "active", "persist", "skin", "name_key", "prompt_key",
    "requires_moves", "requires_move", "requires_flags", "sets_flag", "flag_id",
    "target_id", "target_ids", "requires_signals", "required_signals", "signal_mode",
    "on", "period", "offset", "dir", "sfx", "sfx_on", "secret_id", "trial_id",
}
KIND_PROPS: Dict[str, Set[str]] = {
    "beacon": {"lit", "require_clear", "guard_zone", "index", "relit_zones"},
    "blue_portal": {"dest_pos", "pair_id", "pair_sync", "powered", "requires_blue", "starts_powered", "target_portal_id", "allows_skiff", "warps_bolts", "exit_dir"},
    "portal": {"dest_pos", "pair_id", "pair_sync", "powered", "requires_blue", "starts_powered", "target_portal_id", "allows_skiff", "warps_bolts", "exit_dir"},
    "bramble": {"burned", "from_map_tile"},
    "brazier": {"allow_interact", "lit", "lit_by_default", "light_by_lantern", "dawn_relight", "dusk_douse"},
    "chest": {"amount", "dungeon_id", "opened", "reward", "reward_kind"},
    "cracked_wall": {"broken", "from_map_tile", "war_breakable"},
    "cracked": {"broken", "from_map_tile", "war_breakable"},
    "door": {"clear_zone", "door_kind", "door_type", "dungeon_id", "key_id", "key_kind", "opened", "persistent", "required_beacons", "required_count", "required_flags", "requires_beacons", "seal_id", "starts_open"},
    "great_lamp": {"island_id", "lit", "requires_boss", "requires_flag"},
    "great_belfry_brazier": {"island_id", "lit", "requires_boss", "requires_flag"},
    "lantern_pickup": {"collected", "grants_moves"},
    "mirror": {"angle_deg", "angle_step_deg", "double_sided", "movable", "normal", "persist_pos", "rotatable", "transforms_to"},
    "blue_transformer": {"angle_deg", "angle_step_deg", "double_sided", "movable", "normal", "persist_pos", "rotatable", "transforms_to"},
    "transformer": {"angle_deg", "angle_step_deg", "double_sided", "movable", "normal", "persist_pos", "rotatable", "transforms_to"},
    "obsidian_seal": {"shattered"},
    "seal": {"shattered"},
    "phantom_platform": {"persist_grace", "revealed"},
    "phantom": {"persist_grace", "revealed"},
    "rest_shrine": set(),
    "road_lamp": {"lit"},
    "lamp": {"lit"},
    "shrine": {"claimed", "move_id", "unlocks_move"},
    "switch_eye": {"activated", "requires_blue", "requires_prism", "reset_time"},
    "switch": {"activated", "requires_blue", "requires_prism", "reset_time"},
    "tide_gate": {"low_ratio", "period", "phase_offset", "warn_time"},
    "tide": {"low_ratio", "period", "phase_offset", "warn_time"},
    "waystone": {"lit", "lit_by_default"},
    "web": {"burned"},
    "wick_key": {"collected", "dungeon_id", "key_kind", "requires_flag"},
    "keepers_flame": {"collected", "dungeon_id", "key_kind", "requires_flag"},
    "key": {"collected", "dungeon_id", "key_kind", "requires_flag"},
    # Epic toys (CONTRACTS.md + TOYS_PHYS.md + TOYS_LOGIC.md)
    "push_block": {"variant", "cooled"},
    "moving_platform": {"path", "speed", "loop", "pingpong", "needs_power", "mode"},
    "conveyor": {"speed", "flip_on_signal", "needs_var", "carry_mirrors", "speed_mult"},
    "spinner": {"length", "speed", "arms", "start_deg", "on_signal"},
    "crumble_floor": {"delay", "respawn"},
    "bounce_bloom": {"dist"},
    "gravity_well": {"strength", "pull", "push", "mode", "on_signal"},
    "wind_zone": {"strength", "on_signal"},
    "spike_floor": {"on_signal"},
    "pull_ring": {"axis", "dist", "target", "latch", "retract_speed"},
    "carry_orb": {"kind", "orb_kind"},
    "one_way_gate": {"flip_on_signal"},
    "mover_wall": {"path", "speed", "on_signal"},
    "vehicle_skiff": set(),
    "vehicle_cart": {"rail", "alt_rail", "speed", "loop", "auto"},
    "rotor": {"quarter_on_signal", "speed", "start_quarter"},
    "tilt_group": {"period", "axis", "strength", "angle", "targets"},
    "pressure_plate": {"by", "hold", "latch", "mode"},
    "timed_brazier": {"secs", "reset", "allow_interact"},
    "crystal_toggle": {"group", "phase", "cooldown"},
    "toggle_block": {"group", "phase", "start_phase"},
    "beam_emitter": {"color", "duty", "range", "max_bounces", "harms_wick", "damage", "needs_signal"},
    "beam_sensor": {"color", "hold", "latch", "pass_through"},
    "turret_eye": {"aim", "cadence", "tell_secs", "recover_secs", "bolt_speed", "damage", "color", "sight_range", "can_disable"},
    "bell": {"tone", "wave_radius", "speed", "cooldown", "relay", "echo_delay", "echo_enabled", "relay_any_tone"},
    "tone_door": {"tone", "hold_secs", "toggle"},
    "light_plant": {"grow", "secs", "decay", "bounce_dir", "bounce_dist"},
    "shadow_gate": {"threshold"},
    "scale": {"left", "right", "pan_radius", "mode", "need_weight"},
    "floor_sigil": {"cells", "cell_size", "start"},
    "sequence_orbs": {"order", "count", "spacing", "positions"},
    "mimic_statue": {"mirror", "range"},
    "logic_gate": {"op", "n", "inputs", "invert"},
    "lantern_hook": {"light_radius"},
    "echo_rose": {"secs", "loop"},
    "trial_gate": {"challenge", "once", "shoot_to_start"},
    "lore_stone": {"string_id", "icon", "duration", "style"},
    "room_anchor": {"auto", "activate_radius"},
    "light_sensor": {"need_secs", "decay_rate", "threshold", "hold"},
    "color_glass": {"color", "solid", "movable", "cycles_color"},
    "state_lever": {"scope", "var", "values", "index", "shootable", "style", "step_trigger", "prompt"},
    "npc": {"folk", "bubbles", "quest", "wander_radius", "require_flag"},
    "quest_item": {"id", "item_id"},
    "moth": {"id", "moth_id"},
    "pane_pickup": {"pane"},
    "shop_npc": {"folk", "wander_radius", "require_flag", "shop_mode"},
    "hub_door": {"to_region", "to_island", "door_role"},
}


def load_toy_meta() -> Dict[str, Dict[str, Any]]:
    """Load island toy metadata from docs/fullgame/epic/toys/meta_i*.json."""
    out: Dict[str, Dict[str, Any]] = {}
    toys_dir = REPO_ROOT / "docs" / "fullgame" / "epic" / "toys"
    if not toys_dir.is_dir():
        return out
    for mp in sorted(toys_dir.glob("meta_i*.json")):
        try:
            data = json.loads(mp.read_text(encoding="utf-8"))
        except Exception:
            continue
        if isinstance(data, dict):
            for k, v in data.items():
                if isinstance(v, dict):
                    out[str(k).strip().lower()] = v
    return out


def _scan_script_props(gd_path: Path, class_index: Dict[str, Path], depth: int = 0) -> Set[str]:
    """Extract props.get/has/[...] and dir_vec(...) keys from a GDScript file and its parent toy class."""
    found: Set[str] = set()
    if depth > 4 or not gd_path.exists():
        return found
    try:
        txt = gd_path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return found
    for pat in (
        r'\bprops\.get\(\s*"([a-zA-Z0-9_]+)"',
        r'\bprops\.has\(\s*"([a-zA-Z0-9_]+)"',
        r'\bprops\[\s*"([a-zA-Z0-9_]+)"\s*\]',
        r'\bdir_vec\(\s*"([a-zA-Z0-9_]+)"',
    ):
        for m in re.finditer(pat, txt):
            found.add(m.group(1))
    ext_m = re.search(r"^\s*extends\s+([A-Za-z0-9_]+)", txt, re.M)
    if ext_m:
        parent = ext_m.group(1)
        if parent not in ("LxToy", "LxInteractable", "Node2D", "Node", "RefCounted") and parent in class_index:
            found |= _scan_script_props(class_index[parent], class_index, depth + 1)
    return found


def load_engine_catalog() -> Dict[str, Any]:
    """Load built-in interactables, enemies, strings, islands, packs, toy meta, and code-scanned props."""
    inter_kinds: Set[str] = set(CONTRACT_INTERACTABLES)
    inter_scripts: Dict[str, Path] = {}
    enemy_kinds: Set[str] = set()
    strings: Set[str] = set()
    dungeons: Dict[str, Dict[str, Any]] = {}
    toy_meta: Dict[str, Dict[str, Any]] = load_toy_meta()

    # Build quick class_name -> Path index across luxel/world and luxel/islands/*/toys
    class_index: Dict[str, Path] = {}
    for base_d in [REPO_ROOT / "luxel" / "world", *(REPO_ROOT / "luxel" / "islands").glob("*/toys")]:
        if not base_d.is_dir():
            continue
        for gd in base_d.rglob("*.gd"):
            try:
                head = gd.read_text(encoding="utf-8", errors="ignore")[:400]
            except OSError:
                continue
            cm = re.search(r"^\s*class_name\s+([A-Za-z0-9_]+)", head, re.M)
            if cm:
                class_index[cm.group(1)] = gd

    if_path = REPO_ROOT / "luxel" / "world" / "interactables" / "interactable_factory.gd"
    if if_path.exists():
        txt = if_path.read_text(encoding="utf-8")
        for m in re.finditer(r'^\s*"([a-z0-9_]+)"\s*:\s*preload\(\s*"(res://[^"]+)"\s*\)', txt, re.M):
            k = m.group(1).lower()
            inter_kinds.add(k)
            inter_scripts[k] = REPO_ROOT / m.group(2).replace("res://", "")
        for m in re.finditer(r'^\s*"([a-z0-9_]+)"\s*:\s*preload', txt, re.M):
            inter_kinds.add(m.group(1).lower())

    ef_path = REPO_ROOT / "luxel" / "enemies" / "enemy_factory.gd"
    if ef_path.exists():
        txt = ef_path.read_text(encoding="utf-8")
        for m in re.finditer(r'^\s*"([a-z0-9_]+)"\s*(?:,|:)', txt, re.M):
            enemy_kinds.add(m.group(1).lower())
        for m in re.finditer(r'"([a-z0-9_]+)"\s*:', txt):
            if m.group(1) in ("parasol_toad", "toad_warden", "magpie", "magpie_snatcher", "hush_owl", "owl_sentinel", "moonshade", "belfry_warden", "grand_bellkeeper"):
                enemy_kinds.add(m.group(1))

    st_path = REPO_ROOT / "luxel" / "story" / "strings.gd"
    if st_path.exists():
        txt = st_path.read_text(encoding="utf-8")
        for m in re.finditer(r'^\s*"([A-Z0-9_]+)"\s*:', txt, re.M):
            strings.add(m.group(1))

    isl_path = REPO_ROOT / "luxel" / "data" / "islands.json"
    islands_data: Dict[int, Dict[str, Any]] = {}
    if isl_path.exists():
        raw = json.loads(isl_path.read_text(encoding="utf-8"))
        for item in raw.get("islands", []):
            iid = int(item.get("id", 0))
            islands_data[iid] = item
            did = str(item.get("dungeon_id", ""))
            if did:
                dungeons[did] = {"id": did, "island": iid, "regions": [], "built_in": True}

    pack_paths = sorted(glob.glob(str(REPO_ROOT / "luxel" / "data" / "packs" / "*.json")))
    pack_paths += sorted(glob.glob(str(REPO_ROOT / "luxel" / "hub" / "packs" / "*.json")))
    pack_paths += sorted(glob.glob(str(REPO_ROOT / "luxel" / "islands" / "*" / "packs" / "*.json")))
    for pp in pack_paths:
        try:
            pd = json.loads(Path(pp).read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(pd, dict):
            continue
        for k, v in (pd.get("interactables") or {}).items():
            kl = str(k).lower()
            inter_kinds.add(kl)
            sp = v if isinstance(v, str) else (v.get("script", "") if isinstance(v, dict) else "")
            if sp:
                inter_scripts[kl] = REPO_ROOT / str(sp).replace("res://", "")
        for k in (pd.get("enemies") or {}).keys():
            enemy_kinds.add(str(k).lower())
        for k in (pd.get("bosses") or {}).keys():
            enemy_kinds.add(str(k).lower())
        for k in (pd.get("strings") or {}).keys():
            strings.add(str(k))
        d_raw = pd.get("dungeons")
        d_items = d_raw if isinstance(d_raw, list) else (list(d_raw.values()) if isinstance(d_raw, dict) else [])
        for d in d_items:
            if isinstance(d, dict) and d.get("id"):
                dungeons[str(d["id"])] = d

    # Merge toy metadata kinds and scripts
    for tk, tmeta in toy_meta.items():
        inter_kinds.add(tk)
        sp = str(tmeta.get("script", "")).strip()
        if sp and tk not in inter_scripts:
            inter_scripts[tk] = REPO_ROOT / sp.replace("res://", "")

    # Auto-derive kind_props from hand defaults + code-scanned script props + toy_meta
    kind_props: Dict[str, Set[str]] = {k: set(v) for k, v in KIND_PROPS.items()}
    for k, gd_p in inter_scripts.items():
        scanned = _scan_script_props(gd_p, class_index)
        if scanned:
            kind_props.setdefault(k, set()).update(scanned)
    for tk, tmeta in toy_meta.items():
        mprops = tmeta.get("props")
        if isinstance(mprops, list):
            kind_props.setdefault(tk, set()).update(str(p) for p in mprops)

    return {
        "interactables": inter_kinds,
        "enemies": enemy_kinds,
        "strings": strings,
        "islands": islands_data,
        "dungeons": dungeons,
        "toy_meta": toy_meta,
        "kind_props": kind_props,
    }


def moves_for_island(isl_id: int, islands_data: Dict[int, Dict[str, Any]], include_island: bool = True) -> Set[str]:
    moves = {"bolt"}
    for i in range(1, isl_id + (1 if include_island else 0)):
        for mv in islands_data.get(i, {}).get("move_gained", []):
            moves.add(str(mv))
    return moves


def parse_map_file(path: Path) -> Dict[str, Any]:
    legend = dict(DEFAULT_LEGEND)
    tile_size = DEFAULT_TILE_SIZE
    raw_rows: List[str] = []
    in_map = False
    saw_marker = False
    unknown_chars: Set[str] = set()
    unknown_legend_types: Set[str] = set()

    text = path.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    for raw in text.split("\n"):
        if not in_map:
            trimmed = raw.strip()
            if not trimmed or trimmed.startswith("#"):
                continue
            if trimmed == "MAP":
                in_map = True
                saw_marker = True
                continue
            if trimmed.startswith("TILE_SIZE "):
                try:
                    tile_size = int(trimmed[10:].strip())
                except ValueError:
                    tile_size = 0
                continue
            if trimmed.startswith("LEGEND "):
                parts = trimmed[7:].strip().split()
                if len(parts) >= 2:
                    ch = parts[0][0]
                    tt = parts[1].strip().lower()
                    legend[ch] = tt
                    if tt not in KNOWN_TILE_TYPES:
                        unknown_legend_types.add(tt)
                continue
        else:
            s = raw.strip()
            if not s:
                continue
            if s in ("END", "ENDMAP"):
                break
            raw_rows.append(raw)

    if not saw_marker and not raw_rows:
        raw_rows = [ln for ln in text.split("\n") if ln.strip()]

    row_lengths = [len(r) for r in raw_rows]
    rectangular = len(set(row_lengths)) <= 1
    height = len(raw_rows)
    width = max(row_lengths, default=0)
    grid: List[List[str]] = []
    for r in raw_rows:
        row: List[str] = []
        for x in range(width):
            ch = r[x] if x < len(r) else "_"
            if ch not in legend:
                unknown_chars.add(ch)
                row.append("void")
            else:
                row.append(legend[ch])
        grid.append(row)

    return {
        "width": width,
        "height": height,
        "tile_size": tile_size,
        "legend": legend,
        "grid": grid,
        "raw_rows": raw_rows,
        "rectangular": rectangular,
        "row_lengths": row_lengths,
        "unknown_chars": sorted(unknown_chars),
        "unknown_legend_types": sorted(unknown_legend_types),
    }


def load_region(isl_id: int, reg_id: str, fixtures_dir: Optional[Path] = None) -> Dict[str, Any]:
    base = REPO_ROOT / "luxel" / "islands" / str(isl_id)
    mp = base / f"{reg_id}.map"
    jp = base / f"{reg_id}.json"
    m = parse_map_file(mp) if mp.exists() else {"width": 0, "height": 0, "tile_size": 16, "grid": [], "rectangular": False, "unknown_chars": [], "unknown_legend_types": []}
    j: Dict[str, Any] = {}
    json_error = ""
    if jp.exists():
        try:
            parsed = json.loads(jp.read_text(encoding="utf-8"))
            if isinstance(parsed, dict):
                j = parsed
            else:
                json_error = "root JSON is not an object"
        except Exception as exc:
            json_error = str(exc)
    else:
        json_error = "missing .json file"

    if fixtures_dir and fixtures_dir.is_dir() and not j.get("design"):
        for cand in (fixtures_dir / f"{isl_id}_{reg_id}.json", fixtures_dir / f"{reg_id}.json"):
            if cand.exists():
                try:
                    ov = json.loads(cand.read_text(encoding="utf-8"))
                    if isinstance(ov, dict) and "design" in ov:
                        j["design"] = ov["design"]
                except Exception:
                    pass
                break

    ts = int(j.get("tile_size", m["tile_size"]) or DEFAULT_TILE_SIZE)
    w, h = int(m["width"]), int(m["height"])
    return {
        "key": f"{isl_id}:{reg_id}",
        "island_id": isl_id,
        "id": reg_id,
        "map_path": str(mp),
        "json_path": str(jp),
        "json_error": json_error,
        "width": w,
        "height": h,
        "tile_size": ts,
        "pixel_width": w * ts,
        "pixel_height": h * ts,
        "grid": m["grid"],
        "rectangular": m["rectangular"],
        "row_lengths": m.get("row_lengths", []),
        "unknown_chars": m["unknown_chars"],
        "unknown_legend_types": m["unknown_legend_types"],
        "is_dungeon": bool(j.get("is_dungeon", reg_id != "overworld")),
        "spawn": j.get("spawn", [w * ts * 0.5, h * ts * 0.5]),
        "zones": j.get("zones", []) if isinstance(j.get("zones"), list) else [],
        "exits": j.get("exits", []) if isinstance(j.get("exits"), list) else [],
        "enemies": j.get("enemies", []) if isinstance(j.get("enemies"), list) else [],
        "interactables": j.get("interactables", []) if isinstance(j.get("interactables"), list) else [],
        "triggers": j.get("triggers", []) if isinstance(j.get("triggers"), list) else [],
        "scenery": j.get("scenery", []) if isinstance(j.get("scenery"), list) else [],
        "layers": j.get("layers", []) if isinstance(j.get("layers"), list) else [],
        "events": j.get("events", []) if isinstance(j.get("events"), list) else [],
        "design": j.get("design") if isinstance(j.get("design"), dict) else None,
        "raw": j,
    }


def _pt_in_rect(px: float, py: float, rect: Sequence[float]) -> bool:
    return rect[0] <= px <= rect[0] + rect[2] and rect[1] <= py <= rect[1] + rect[3]


def _dist_to_tile(px: float, py: float, tx: int, ty: int, ts: int) -> float:
    rx0, ry0 = tx * ts, ty * ts
    rx1, ry1 = rx0 + ts, ry0 + ts
    cx = min(max(px, rx0), rx1)
    cy = min(max(py, ry0), ry1)
    return math.hypot(px - cx, py - cy)


def _min_hazard_dist(reg: Dict[str, Any], px: float, py: float) -> float:
    ts, w, h, grid = reg["tile_size"], reg["width"], reg["height"], reg["grid"]
    if w <= 0 or h <= 0:
        return 0.0
    # Collect platforms covering hazards (bridge_platform starts_open, tide_gate, phantom_platform)
    supported: List[Tuple[float, float, float, float]] = []
    for it in reg["interactables"]:
        k = str(it.get("kind", "")).lower()
        p = it.get("pos", [0, 0])
        props = it.get("props") or {}
        if k in ("tide_gate", "tide"):
            sz = props.get("size", [32, 32])
            supported.append((p[0] - sz[0] * 0.5, p[1] - sz[1] * 0.5, sz[0], sz[1]))
    tx0 = max(0, int((px - 40) // ts))
    tx1 = min(w - 1, int((px + 40) // ts))
    ty0 = max(0, int((py - 40) // ts))
    ty1 = min(h - 1, int((py + 40) // ts))
    best = 9999.0
    for ty in range(ty0, ty1 + 1):
        for tx in range(tx0, tx1 + 1):
            if grid[ty][tx] not in HAZARD_TILES:
                continue
            cx, cy = (tx + 0.5) * ts, (ty + 0.5) * ts
            if any(_pt_in_rect(cx, cy, r) for r in supported):
                continue
            d = _dist_to_tile(px, py, tx, ty, ts)
            if d < best:
                best = d
    return best


def _tile_at(reg: Dict[str, Any], px: float, py: float) -> str:
    ts = reg["tile_size"]
    tx, ty = int(px // ts), int(py // ts)
    if 0 <= tx < reg["width"] and 0 <= ty < reg["height"]:
        return reg["grid"][ty][tx]
    return "void"


def _is_tile_walkable(tt: str, moves: Set[str]) -> bool:
    if tt in WALKABLE_BASE:
        return True
    if tt in ("bramble", "cracked", "web"):
        return "beam" in moves
    if tt == "phantom":
        return "lens" in moves
    if tt == "obsidian":
        return "sunflare" in moves
    return False


def _parse_dir_vec(val: Any) -> Tuple[float, float]:
    if isinstance(val, list) and len(val) >= 2:
        dx, dy = float(val[0]), float(val[1])
        ln = math.hypot(dx, dy)
        return (dx / ln, dy / ln) if ln > 1e-4 else (1.0, 0.0)
    s = str(val or "e").strip().lower()
    if s in ("n", "up", "north"):
        return (0.0, -1.0)
    if s in ("s", "down", "south"):
        return (0.0, 1.0)
    if s in ("w", "left", "west"):
        return (-1.0, 0.0)
    return (1.0, 0.0)


def flood_fill_region(
    reg: Dict[str, Any],
    starts: List[Tuple[float, float]],
    moves: Set[str],
    ignore_doors: bool = True,
    toy_meta: Optional[Dict[str, Dict[str, Any]]] = None,
) -> Set[Tuple[int, int]]:
    w, h, ts, grid = reg["width"], reg["height"], reg["tile_size"], reg["grid"]
    if w <= 0 or h <= 0:
        return set()
    toy_meta = toy_meta or {}
    bridge_tiles: Set[Tuple[int, int]] = set()
    blocked_tiles: Set[Tuple[int, int]] = set()
    portal_pos: Dict[str, Tuple[int, int]] = {}
    portal_edges: Dict[Tuple[int, int], List[Tuple[int, int]]] = defaultdict(list)

    def _mark_bridge_rect(cx: float, cy: float, rw: float, rh: float) -> None:
        rx0, ry0 = cx - rw * 0.5, cy - rh * 0.5
        for ty in range(max(0, int(ry0 // ts)), min(h, int((ry0 + rh - 0.1) // ts) + 1)):
            for tx in range(max(0, int(rx0 // ts)), min(w, int((rx0 + rw - 0.1) // ts) + 1)):
                bridge_tiles.add((tx, ty))

    star_pos_by_id: Dict[str, Tuple[float, float]] = {}
    for it in reg["interactables"]:
        k = str(it.get("kind", "")).lower()
        p = it.get("pos", [0, 0])
        props = it.get("props") or {}
        if k == "star_node" and it.get("id") and isinstance(p, list) and len(p) >= 2:
            star_pos_by_id[str(it["id"])] = (float(p[0]), float(p[1]))
        if k in ("blue_portal", "portal"):
            pid = str(it.get("id", ""))
            if pid:
                portal_pos[pid] = (int(p[0] // ts), int(p[1] // ts))
        elif k in DOOR_KINDS:
            dk = str(props.get("door_kind", props.get("door_type", k))).lower()
            sz = props.get("size", [32, 16])
            rx0, ry0 = p[0] - sz[0] * 0.5, p[1] - sz[1] * 0.5
            for ty in range(max(0, int(ry0 // ts)), min(h, int((ry0 + sz[1] - 0.1) // ts) + 1)):
                for tx in range(max(0, int(rx0 // ts)), min(w, int((rx0 + sz[0] - 0.1) // ts) + 1)):
                    if dk == "bridge_platform":
                        bridge_tiles.add((tx, ty))
                    elif not ignore_doors and not bool(props.get("opened", props.get("starts_open", False))):
                        blocked_tiles.add((tx, ty))
        elif k in ("tide_gate", "tide", "phantom_platform", "phantom", "moving_platform", "light_plant"):
            if k in ("phantom_platform", "phantom") and "lens" not in moves:
                continue
            sz = props.get("size", [32, 16])
            _mark_bridge_rect(float(p[0]), float(p[1]), float(sz[0]), float(sz[1]))
            path = props.get("path")
            if k == "moving_platform" and isinstance(path, list) and len(path) >= 2:
                pts = [(float(pt[0]), float(pt[1])) for pt in path if isinstance(pt, list) and len(pt) >= 2]
                for a, b in zip(pts, pts[1:]):
                    steps_n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) // 8))
                    for si in range(steps_n + 1):
                        u = si / steps_n
                        _mark_bridge_rect(a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, float(sz[0]), float(sz[1]))
        elif k == "tone_coffin":
            if not bool(props.get("solid_blocker", False)) or bool(props.get("platform_after_shatter", False)):
                dx, dy = _parse_dir_vec(props.get("dir", "e"))
                def_sz = [32, 16] if abs(dx) >= abs(dy) else [16, 32]
                sz = props.get("size", def_sz)
                sw, sh = float(sz[0]), float(sz[1])
                slide_px = float(props.get("slide_tiles", 2.0)) * ts
                steps_n = max(1, int(slide_px // 8))
                for si in range(steps_n + 1):
                    u = si / steps_n
                    _mark_bridge_rect(float(p[0]) + dx * slide_px * u, float(p[1]) + dy * slide_px * u, sw, sh)
        elif k == "falling_bell_platform":
            rad = float(props.get("radius_px", 52.0))
            _mark_bridge_rect(float(p[0]), float(p[1]), rad * 2.0, rad * 2.0)
        elif k == "clock_hand":
            length = float(props.get("length", 64.0))
            _mark_bridge_rect(float(p[0]), float(p[1]), length * 2.0, length * 2.0)
        elif toy_meta.get(k, {}).get("blocks") == "platform":
            sz = props.get("size", [32, 32] if k == "tide_raft" else [24, 24])
            _mark_bridge_rect(float(p[0]), float(p[1]), float(sz[0]), float(sz[1]))
        elif not ignore_doors and toy_meta.get(k, {}).get("blocks") == "solid":
            clear_ps = toy_meta.get(k, {}).get("clear_props", [])
            if not any(bool(props.get(cp, False)) for cp in clear_ps):
                sz = props.get("size", [16, 16])
                rx0, ry0 = float(p[0]) - float(sz[0]) * 0.5, float(p[1]) - float(sz[1]) * 0.5
                for ty in range(max(0, int(ry0 // ts)), min(h, int((ry0 + float(sz[1]) - 0.1) // ts) + 1)):
                    for tx in range(max(0, int(rx0 // ts)), min(w, int((rx0 + float(sz[0]) - 0.1) // ts) + 1)):
                        blocked_tiles.add((tx, ty))

    # Linked star_node constellations bridge gaps between linked nodes
    for it in reg["interactables"]:
        if str(it.get("kind", "")).lower() == "star_node":
            p = it.get("pos", [0, 0])
            props = it.get("props") or {}
            if props.get("lens_only") and "lens" not in moves:
                continue
            for lid in props.get("links", []) or []:
                lp = star_pos_by_id.get(str(lid))
                if lp:
                    dist = math.hypot(lp[0] - float(p[0]), lp[1] - float(p[1]))
                    steps_n = max(1, int(dist // 8))
                    for si in range(steps_n + 1):
                        u = si / steps_n
                        _mark_bridge_rect(float(p[0]) + (lp[0] - float(p[0])) * u, float(p[1]) + (lp[1] - float(p[1])) * u, 16.0, 16.0)

    for it in reg["interactables"]:
        k = str(it.get("kind", "")).lower()
        if k in ("blue_portal", "portal"):
            p = it.get("pos", [0, 0])
            props = it.get("props") or {}
            st = (int(p[0] // ts), int(p[1] // ts))
            tpid = str(props.get("target_portal_id", ""))
            if tpid and tpid in portal_pos:
                portal_edges[st].append(portal_pos[tpid])
            elif isinstance(props.get("dest_pos"), list) and len(props["dest_pos"]) >= 2:
                dp = props["dest_pos"]
                portal_edges[st].append((int(dp[0] // ts), int(dp[1] // ts)))

    # Traversal reach per CONTRACTS.md:
    # dash<=32px (2t), throw+zip<=108px (6t, clears rail, blocked by grate/wall), wings<=96px (6t, clears rail, blocked by grate/wall)
    modes_span: List[Tuple[int, bool, bool]] = []
    if "dash" in moves:
        modes_span.append((2, False, False))
    if "throw" in moves:
        modes_span.append((6, True, True))
    if "wings" in moves:
        modes_span.append((6, True, True))
    visited: Set[Tuple[int, int]] = set()
    q: deque[Tuple[int, int]] = deque()
    for sx, sy in starts:
        st = (max(0, min(w - 1, int(sx // ts))), max(0, min(h - 1, int(sy // ts))))
        if st not in visited:
            visited.add(st)
            q.append(st)

    dirs = ((-1, 0), (1, 0), (0, -1), (0, 1))
    while q:
        cx, cy = q.popleft()
        for dx, dy in dirs:
            nx, ny = cx + dx, cy + dy
            if not (0 <= nx < w and 0 <= ny < h):
                continue
            if (nx, ny) not in visited and (nx, ny) not in blocked_tiles and (
                (nx, ny) in bridge_tiles or _is_tile_walkable(grid[ny][nx], moves)
            ):
                visited.add((nx, ny))
                q.append((nx, ny))
                continue
            for max_span, allow_water, allow_rail in modes_span:
                for span in range(1, max_span + 1):
                    mx, my = cx + dx * span, cy + dy * span
                    if not (0 <= mx < w and 0 <= my < h) or (mx, my) in blocked_tiles:
                        break
                    mt = grid[my][mx]
                    mid_ok = (
                        mt in ("pit", "gap", "chasm", "void", "phantom")
                        or (allow_water and mt in ("water", "tide"))
                        or (allow_rail and mt == "rail")
                    )
                    if not mid_ok:
                        break
                    lx, ly = cx + dx * (span + 1), cy + dy * (span + 1)
                    if not (0 <= lx < w and 0 <= ly < h):
                        break
                    if (lx, ly) not in visited and (lx, ly) not in blocked_tiles and (
                        (lx, ly) in bridge_tiles or _is_tile_walkable(grid[ly][lx], moves)
                    ):
                        visited.add((lx, ly))
                        q.append((lx, ly))
                        break
        for dt in portal_edges.get((cx, cy), []):
            if 0 <= dt[0] < w and 0 <= dt[1] < h and dt not in visited:
                visited.add(dt)
                q.append(dt)
    return visited


def _tile_or_adj_reached(visited: Set[Tuple[int, int]], tx: int, ty: int, rad: int = 1) -> bool:
    for dy in range(-rad, rad + 1):
        for dx in range(-rad, rad + 1):
            if (tx + dx, ty + dy) in visited:
                return True
    return False


def _clear_ranged_reach(reg: Dict[str, Any], visited: Set[Tuple[int, int]], px: float, py: float, max_range: float = 140.0) -> bool:
    ts, w, h, grid = reg["tile_size"], reg["width"], reg["height"], reg["grid"]
    tx, ty = int(px // ts), int(py // ts)
    if _tile_or_adj_reached(visited, tx, ty, 1):
        return True
    r_tiles = int(math.ceil(max_range / ts))
    for vy in range(max(0, ty - r_tiles), min(h, ty + r_tiles + 1)):
        for vx in range(max(0, tx - r_tiles), min(w, tx + r_tiles + 1)):
            if (vx, vy) not in visited:
                continue
            sx, sy = (vx + 0.5) * ts, (vy + 0.5) * ts
            dist = math.hypot(px - sx, py - sy)
            if dist > max_range:
                continue
            steps = max(1, int(dist // 8))
            blocked = False
            for s in range(1, steps):
                u = s / steps
                tt = _tile_at(reg, sx + (px - sx) * u, sy + (py - sy) * u)
                if tt in SIGHT_BLOCKING:
                    blocked = True
                    break
            if not blocked:
                return True
    return False


def compute_symmetry(grid: List[List[str]]) -> Tuple[float, float, float]:
    h = len(grid)
    w = len(grid[0]) if h else 0
    if w < 3 or h < 3:
        return 0.0, 0.0, 0.0
    # Compare interior tiles only (exclude outer 1-tile wall ring)
    ih, iw = h - 2, w - 2
    if iw <= 0 or ih <= 0:
        return 0.0, 0.0, 0.0
    mh = mv = total = 0
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            total += 1
            if grid[y][x] == grid[y][w - 1 - x]:
                mh += 1
            if grid[y][x] == grid[h - 1 - y][x]:
                mv += 1
    sh = mh / total
    sv = mv / total
    return round(sh, 3), round(sv, 3), round(max(sh, sv), 3)


def check_png_palette_stdlib(png_path: Path) -> Tuple[bool, int]:
    """Verify an RGB/RGBA/Indexed PNG uses only the 20 Last Light opaque colours (stdlib only)."""
    data = png_path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return False, -1
    pos = 8
    w = h = bit_depth = color_type = 0
    plte: List[Tuple[int, int, int]] = []
    idat = bytearray()
    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            w, h, bit_depth, color_type = struct.unpack(">IIBB", chunk[:10])
        elif ctype == b"PLTE":
            for i in range(0, len(chunk), 3):
                plte.append((chunk[i], chunk[i + 1], chunk[i + 2]))
        elif ctype == b"IDAT":
            idat.extend(chunk)
        elif ctype == b"IEND":
            break
    if bit_depth != 8:
        return True, 0
    if color_type == 3:
        off = sum(1 for c in plte if c not in LAST_LIGHT_RGB)
        return off == 0, off
    bpp = 4 if color_type == 6 else (3 if color_type == 2 else 0)
    if bpp == 0:
        return True, 0
    raw = zlib.decompress(bytes(idat))
    stride = w * bpp
    prev = bytearray(stride)
    off_pixels = 0
    idx = 0
    for _ in range(h):
        flt = raw[idx]
        idx += 1
        row = bytearray(raw[idx:idx + stride])
        idx += stride
        if flt == 1:
            for i in range(bpp, stride):
                row[i] = (row[i] + row[i - bpp]) & 0xFF
        elif flt == 2:
            for i in range(stride):
                row[i] = (row[i] + prev[i]) & 0xFF
        elif flt == 3:
            for i in range(stride):
                a = row[i - bpp] if i >= bpp else 0
                row[i] = (row[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif flt == 4:
            for i in range(stride):
                a = row[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                row[i] = (row[i] + pr) & 0xFF
        prev = row
        for i in range(0, stride, bpp):
            if bpp == 4:
                a = row[i + 3]
                if a == 0:
                    continue
                if a != 255:
                    off_pixels += 1
                    continue
            if (row[i], row[i + 1], row[i + 2]) not in LAST_LIGHT_RGB:
                off_pixels += 1
    return off_pixels == 0, off_pixels


def infer_dungeon_id(reg: Dict[str, Any], catalog: Dict[str, Any]) -> str:
    reg_id = reg["id"]
    if reg_id.startswith("_") or bool(reg.get("json", {}).get("debug_only", False)):
        return ""
    isl_id = reg["island_id"]
    for did, dmeta in catalog["dungeons"].items():
        regs = dmeta.get("regions") or []
        if reg_id in regs and int(dmeta.get("island", isl_id)) == isl_id:
            return did
    if not reg["is_dungeon"] or reg_id == "overworld":
        return ""
    m = re.match(r"^([a-z0-9_]+?)_r\d+$", reg_id)
    if m:
        prefix = m.group(1)
        built = str(catalog["islands"].get(isl_id, {}).get("dungeon_id", ""))
        if built and (built == prefix or built.endswith("_" + prefix) or prefix in built):
            return built
        return f"island{isl_id}_{prefix}"
    return str(catalog["islands"].get(isl_id, {}).get("dungeon_id", f"island{isl_id}_dungeon"))


def lint_region(
    reg: Dict[str, Any],
    all_regions: Dict[str, Dict[str, Any]],
    incoming_spawns: Dict[str, List[Tuple[float, float]]],
    catalog: Dict[str, Any],
    require_design: bool = False,
) -> Dict[str, Any]:
    errors: List[Dict[str, Any]] = []
    warnings: List[Dict[str, Any]] = []

    def err(code: str, msg: str, **extra: Any) -> None:
        d = {"code": code, "msg": msg}
        d.update(extra)
        errors.append(d)

    def warn(code: str, msg: str, **extra: Any) -> None:
        d = {"code": code, "msg": msg}
        d.update(extra)
        warnings.append(d)

    if reg["json_error"]:
        err("JSON_ERROR", f"{reg['json_path']}: {reg['json_error']}")

    w, h, ts = reg["width"], reg["height"], reg["tile_size"]
    grid = reg["grid"]
    if w <= 0 or h <= 0 or ts <= 0:
        err("MAP_SIZE", f"invalid map size {w}x{h} tile_size={ts}")
        return {"key": reg["key"], "errors": errors, "warnings": warnings, "metrics": {}}
    if reg["pixel_width"] > MAX_PX_W or reg["pixel_height"] > MAX_PX_H:
        err("MAP_TOO_LARGE", f"pixel size {reg['pixel_width']}x{reg['pixel_height']} exceeds {MAX_PX_W}x{MAX_PX_H}")
    if not reg["rectangular"]:
        err("NON_RECTANGULAR", f"map rows have varying lengths: {sorted(set(reg['row_lengths']))}")
    if reg["unknown_chars"]:
        err("UNKNOWN_LEGEND_CHAR", f"unmapped tile chars: {reg['unknown_chars']}")
    if reg["unknown_legend_types"]:
        err("UNKNOWN_LEGEND_TYPE", f"unknown legend tile types: {reg['unknown_legend_types']}")

    # 3. Border sealed
    exits = reg["exits"]
    exit_rects = [ex.get("rect", [0, 0, 0, 0]) for ex in exits if isinstance(ex.get("rect"), list) and len(ex["rect"]) >= 4]
    unsealed: List[Tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            if x in (0, w - 1) or y in (0, h - 1):
                if grid[y][x] in WALKABLE_BASE:
                    cx, cy = (x + 0.5) * ts, (y + 0.5) * ts
                    if not any(_pt_in_rect(cx, cy, r) for r in exit_rects):
                        unsealed.append((x, y))
    if unsealed:
        err("BORDER_UNSEALED", f"{len(unsealed)} walkable border tile(s) outside exit rects, e.g. {unsealed[:4]}")

    # 4. Exits paired both ways & spawn safety
    sp = reg["spawn"]
    if not (isinstance(sp, list) and len(sp) >= 2):
        err("BAD_SPAWN", "missing or invalid spawn [x,y]")
        sp = [reg["pixel_width"] * 0.5, reg["pixel_height"] * 0.5]
    else:
        spx, spy = float(sp[0]), float(sp[1])
        if not (0 <= spx < reg["pixel_width"] and 0 <= spy < reg["pixel_height"]):
            err("SPAWN_OOB", f"spawn ({spx},{spy}) outside {reg['pixel_width']}x{reg['pixel_height']}")
        else:
            stt = _tile_at(reg, spx, spy)
            if stt not in WALKABLE_BASE:
                err("SPAWN_UNWALKABLE", f"spawn ({spx},{spy}) on '{stt}' tile")
            hd = _min_hazard_dist(reg, spx, spy)
            if hd < 24.0:
                warn("SPAWN_NEAR_HAZARD", f"spawn ({spx:.0f},{spy:.0f}) is {hd:.1f}px (<24px) from hazard")

    for ex in exits:
        eid = str(ex.get("id", "?"))
        to_reg = str(ex.get("to_region", ""))
        to_isl = int(ex.get("to_island", reg["island_id"]))
        if to_reg.startswith("island") and ":" in to_reg:
            p0, p1 = to_reg.split(":", 1)
            if p0[6:].isdigit():
                to_isl = int(p0[6:])
                to_reg = p1 or "overworld"
        tkey = f"{to_isl}:{to_reg}"
        if not to_reg:
            err("EXIT_NO_TARGET", f"exit '{eid}' missing to_region")
            continue
        if tkey in all_regions:
            target_r = all_regions[tkey]
            tsp = ex.get("to_spawn")
            if isinstance(tsp, list) and len(tsp) >= 2:
                txp, typ = float(tsp[0]), float(tsp[1])
                if not (0 <= txp < target_r["pixel_width"] and 0 <= typ < target_r["pixel_height"]):
                    err("EXIT_SPAWN_OOB", f"exit '{eid}' -> {tkey} to_spawn ({txp},{typ}) out of bounds")
                else:
                    ttt = _tile_at(target_r, txp, typ)
                    if ttt not in WALKABLE_BASE:
                        err("EXIT_SPAWN_UNWALKABLE", f"exit '{eid}' -> {tkey} to_spawn ({txp},{typ}) on '{ttt}'")
                    thd = _min_hazard_dist(target_r, txp, typ)
                    if thd < 24.0:
                        warn("EXIT_SPAWN_NEAR_HAZARD", f"exit '{eid}' -> {tkey} to_spawn ({txp:.0f},{typ:.0f}) {thd:.1f}px (<24px) from hazard")
            # Paired check (allow intentional one_way / shortcut exits)
            is_one_way = bool(ex.get("one_way", False)) or "shortcut" in eid or "return" in eid or to_isl != reg["island_id"]
            if not is_one_way:
                has_back = any(
                    str(bx.get("to_region", "")) == reg["id"] and int(bx.get("to_island", target_r["island_id"])) == reg["island_id"]
                    for bx in target_r["exits"]
                )
                if not has_back:
                    err("EXIT_UNPAIRED", f"exit '{eid}' -> {tkey} has no return exit back to {reg['key']}")
        elif not (to_isl != reg["island_id"] and not (REPO_ROOT / "luxel" / "islands" / str(to_isl) / f"{to_reg}.map").exists()):
            # Check on disk in case running single-region lint
            if not (REPO_ROOT / "luxel" / "islands" / str(to_isl) / f"{to_reg}.map").exists():
                err("EXIT_BROKEN_TARGET", f"exit '{eid}' targets missing region {tkey}")
        ldid = str(ex.get("locked_door_id", ""))
        if ldid and not any(str(it.get("id", "")) == ldid for it in reg["interactables"]):
            err("EXIT_MISSING_DOOR", f"exit '{eid}' references missing locked_door_id '{ldid}'")

    # 5. IDs unique + 6. Kinds known + 7. Props valid + 8. Strings exist
    seen_ids: Dict[str, str] = {}
    inter_by_id: Dict[str, Dict[str, Any]] = {}
    for bucket, items in (
        ("interactable", reg["interactables"]),
        ("enemy", reg["enemies"]),
        ("exit", reg["exits"]),
        ("trigger", reg["triggers"]),
        ("event", reg["events"]),
        ("layer", reg["layers"]),
    ):
        for item in items:
            if not isinstance(item, dict):
                continue
            iid = str(item.get("id", "")).strip()
            if not iid:
                if bucket in ("interactable", "exit", "trigger"):
                    err("MISSING_ID", f"{bucket} missing id")
                continue
            if iid in seen_ids:
                err("DUPLICATE_ID", f"duplicate id '{iid}' ({seen_ids[iid]} and {bucket})")
            else:
                seen_ids[iid] = bucket
            if bucket == "interactable":
                inter_by_id[iid] = item

    # Strings check helper
    known_strings = catalog["strings"]

    def check_str(sid: Any, where: str) -> None:
        s = str(sid or "").strip()
        if s and s not in known_strings:
            err("MISSING_STRING", f"{where}: unknown string id '{s}'")

    for z in reg["zones"]:
        check_str(z.get("name_key"), f"zone '{z.get('id', '?')}'")
    for tr in reg["triggers"]:
        check_str(tr.get("string_id"), f"trigger '{tr.get('id', '?')}'")

    # Collect event signal listeners & logic_gate inputs so switches feeding them aren't flagged unused
    event_signal_ids: Set[str] = set()
    for ev in reg["events"]:
        on_s = str(ev.get("on", ""))
        if on_s.startswith("signal:"):
            event_signal_ids.add(on_s[7:].strip())
        for act in ev.get("do", []) if isinstance(ev.get("do"), list) else []:
            if isinstance(act, dict) and "narrate" in act:
                nar = act["narrate"]
                check_str(nar.get("id") if isinstance(nar, dict) else nar, f"event '{ev.get('id', '?')}'")
            if isinstance(act, dict) and "wave" in act:
                ws = act["wave"] if isinstance(act["wave"], list) else [act["wave"]]
                for we in ws:
                    if isinstance(we, dict):
                        ek = str(we.get("kind", "")).lower()
                        if ek and ek not in catalog["enemies"]:
                            err("UNKNOWN_ENEMY_KIND", f"event wave enemy kind '{ek}' unknown")
            if isinstance(act, dict) and "spawn" in act and bool(ev.get("once", False)):
                sp_list = act["spawn"] if isinstance(act["spawn"], list) else [act["spawn"]]
                for sp in sp_list:
                    if isinstance(sp, dict):
                        sk = str(sp.get("kind", "")).lower()
                        if sk in ("pane_pickup", "wick_key", "keepers_flame", "chest", "moth"):
                            warn("ONCE_SPAWN_COLLECTIBLE", f"event '{ev.get('id', '?')}' has once=true and spawns collectible '{sk}' (lost on leave+re-enter if unclaimed; use once=false)")

    logic_inputs: Set[str] = set()
    for it in reg["interactables"]:
        if str(it.get("kind", "")).lower() == "logic_gate":
            for inp in (it.get("props") or {}).get("inputs", []) or []:
                logic_inputs.add(str(inp))

    # Validate interactables, props, doors, switches
    for it in reg["interactables"]:
        iid = str(it.get("id", "?"))
        k = str(it.get("kind", "")).strip().lower()
        props = it.get("props") if isinstance(it.get("props"), dict) else {}
        if k not in catalog["interactables"]:
            err("UNKNOWN_INTERACTABLE_KIND", f"interactable '{iid}' has unknown kind '{k}'")
        check_str(props.get("name_key"), f"interactable '{iid}'")
        check_str(props.get("prompt_key"), f"interactable '{iid}'")
        check_str(props.get("string_id"), f"interactable '{iid}'")

        allowed_p = catalog.get("kind_props", KIND_PROPS).get(k)
        if allowed_p is not None:
            unknown_p = sorted(pk for pk in props.keys() if pk not in allowed_p and pk not in ALLOWED_PROPS_COMMON)
            if unknown_p:
                warn("UNKNOWN_PROP", f"interactable '{iid}' ({k}) has unrecognized props: {unknown_p}")

        if k == "shrine" and not str(props.get("move_id", props.get("unlocks_move", ""))).strip():
            err("INVALID_PROP", f"shrine '{iid}' missing props.move_id")
        if k in DOOR_KINDS:
            dk = str(props.get("door_kind", props.get("door_type", k))).strip().lower()
            if k == "door" and dk not in VALID_DOOR_TYPES:
                err("INVALID_PROP", f"door '{iid}' has invalid door_kind '{dk}'")
            req_sigs = props.get("requires_signals", props.get("required_signals", []))
            if isinstance(req_sigs, list):
                for rs in req_sigs:
                    if str(rs) not in inter_by_id:
                        err("BROKEN_DOOR_SIGNAL", f"door '{iid}' requires missing signal source '{rs}'")
        if k in ("blue_portal", "portal"):
            tpid = str(props.get("target_portal_id", "")).strip()
            ip_p = it.get("pos", [0, 0])
            on_exit = isinstance(ip_p, list) and len(ip_p) >= 2 and any(_pt_in_rect(float(ip_p[0]), float(ip_p[1]), er) for er in exit_rects)
            if tpid and tpid not in inter_by_id:
                err("BROKEN_PORTAL_TARGET", f"portal '{iid}' target_portal_id '{tpid}' not found")
            elif not tpid and not props.get("dest_pos") and not on_exit and not props.get("requires_flags") and not props.get("sets_flag"):
                err("INVALID_PROP", f"portal '{iid}' needs target_portal_id or dest_pos")
        if k in SIGNAL_EMITTERS or k == "brazier":
            targets: List[str] = []
            if props.get("target_id"):
                targets.append(str(props["target_id"]))
            if isinstance(props.get("target_ids"), list):
                targets.extend(str(t) for t in props["target_ids"] if t)
            for tid in targets:
                if tid not in inter_by_id:
                    err("BROKEN_SWITCH_TARGET", f"{k} '{iid}' targets missing interactable '{tid}'")
            has_effect = bool(targets) or bool(props.get("sets_flag")) or (iid in event_signal_ids) or (iid in logic_inputs) or k in ("brazier", "crystal_toggle")
            if k in SIGNAL_EMITTERS and not has_effect:
                err("UNUSED_SWITCH", f"{k} '{iid}' controls nothing (no target_id, sets_flag, logic_gate, or event)")

    # 9. Enemies: known kind, on walkable tile, >= 96 px from entry spawns
    entry_points: List[Tuple[float, float]] = [(float(sp[0]), float(sp[1]))]
    entry_points.extend(incoming_spawns.get(reg["key"], []))
    for en in reg["enemies"]:
        eid = str(en.get("id", en.get("kind", "?")))
        ek = str(en.get("kind", "")).strip().lower()
        if ek not in catalog["enemies"]:
            err("UNKNOWN_ENEMY_KIND", f"enemy '{eid}' has unknown kind '{ek}'")
        ep = en.get("pos", [0, 0])
        if not (isinstance(ep, list) and len(ep) >= 2):
            err("BAD_ENEMY_POS", f"enemy '{eid}' invalid pos")
            continue
        ex, ey = float(ep[0]), float(ep[1])
        if not (0 <= ex < reg["pixel_width"] and 0 <= ey < reg["pixel_height"]):
            err("ENEMY_OOB", f"enemy '{eid}' ({ex},{ey}) out of bounds")
            continue
        ett = _tile_at(reg, ex, ey)
        if ek not in FLYING_ENEMIES and ett not in WALKABLE_BASE:
            err("ENEMY_UNWALKABLE", f"ground enemy '{eid}' ({ek}) at ({ex:.0f},{ey:.0f}) on '{ett}'")
        for spx, spy in entry_points:
            d = math.hypot(ex - spx, ey - spy)
            if d < 96.0:
                warn("ENEMY_TOO_CLOSE_TO_SPAWN", f"enemy '{eid}' ({ek}) is {d:.0f}px (<96px) from entry spawn ({spx:.0f},{spy:.0f})")
                break

    # 10 & 11. Walkable flood-fill from each entry + unreachable chests/switches/interactables
    isl_moves = moves_for_island(reg["island_id"], catalog["islands"], include_island=True)
    toy_meta = catalog.get("toy_meta") or {}
    reached = flood_fill_region(reg, entry_points, isl_moves, ignore_doors=True, toy_meta=toy_meta)
    for it in reg["interactables"]:
        iid = str(it.get("id", "?"))
        k = str(it.get("kind", "")).lower()
        ip = it.get("pos", [0, 0])
        if not (isinstance(ip, list) and len(ip) >= 2):
            continue
        ix, iy = float(ip[0]), float(ip[1])
        itx, ity = int(ix // ts), int(iy // ts)
        if k in ("chest", "wick_key", "keepers_flame", "key", "shrine", "beacon", "waystone", "great_lamp", "rest_shrine", "moth", "pane_pickup"):
            if not _tile_or_adj_reached(reached, itx, ity, 1):
                req_m = set(str(m) for m in ((it.get("props") or {}).get("requires_moves") or []) if m)
                if req_m and not req_m.issubset(isl_moves):
                    backtrack_reached = flood_fill_region(reg, entry_points, isl_moves | req_m, ignore_doors=True, toy_meta=toy_meta)
                    if not _tile_or_adj_reached(backtrack_reached, itx, ity, 1):
                        err("UNREACHABLE_INTERACTABLE", f"{k} '{iid}' at ({ix:.0f},{iy:.0f}) unreachable even with required moves {sorted(req_m)}")
                else:
                    err("UNREACHABLE_INTERACTABLE", f"{k} '{iid}' at ({ix:.0f},{iy:.0f}) unreachable with island {reg['island_id']} moves")
        elif k in ("switch_eye", "switch", "brazier", "timed_brazier"):
            if not _clear_ranged_reach(reg, reached, ix, iy, 220.0 if "beam" in isl_moves else 140.0):
                # Allow blue_transformer/mirror bank switches if a mirror is reachable
                has_mirror = any(str(m.get("kind", "")).lower() in ("mirror", "blue_transformer", "transformer") for m in reg["interactables"])
                if not has_mirror:
                    err("UNREACHABLE_SWITCH", f"{k} '{iid}' at ({ix:.0f},{iy:.0f}) unreachable by walk or shot")

    # 15. Design block & R1 L_min floors
    des = reg["design"]
    design_complete = False
    if des is None:
        if require_design:
            err("MISSING_DESIGN", "missing required design block")
        else:
            warn("MISSING_DESIGN", "missing design block (required for Epic rooms)")
    else:
        missing_k = [rk for rk in REQUIRED_DESIGN_KEYS if rk not in des or str(des.get(rk, "")).strip() == ""]
        if missing_k:
            (err if require_design else warn)("INCOMPLETE_DESIGN", f"design block missing keys: {missing_k}")
        else:
            design_complete = True
        dkind = str(des.get("kind", "")).lower()
        dbeat = str(des.get("beat", "")).lower()
        if dkind and dkind not in VALID_DESIGN_KINDS:
            err("INVALID_DESIGN_KIND", f"design.kind '{dkind}' not in {sorted(VALID_DESIGN_KINDS)}")
        if dbeat and dbeat not in VALID_DESIGN_BEATS:
            err("INVALID_DESIGN_BEAT", f"design.beat '{dbeat}' not in {sorted(VALID_DESIGN_BEATS)}")
        sol = des.get("solution")
        if dkind == "puzzle":
            if not isinstance(sol, list) or not sol:
                err("MISSING_SOLUTION", "puzzle room has empty/missing design.solution")
            else:
                action_ops = 0
                for idx, op in enumerate(sol):
                    if not isinstance(op, dict) or str(op.get("op", "")) not in VALID_SOLUTION_OPS:
                        err("INVALID_SOLUTION_OP", f"solution[{idx}] invalid op: {op}")
                    elif str(op.get("op", "")) not in ("expect", "expect_exit", "wait"):
                        action_ops += 1
                floor = BEAT_LMIN_FLOOR.get(dbeat, 3)
                eff_steps = max(action_ops, int(des.get("decisions", 0) or 0))
                if eff_steps < floor:
                    warn("BELOW_LMIN_FLOOR", f"puzzle beat '{dbeat}' has {eff_steps} steps (< R1 floor {floor})")
        exp_s = float(des.get("expert_s", 0) or 0)
        if exp_s > 0 and exp_s < 25.0 and dkind not in ("story", "reward"):
            warn("SHORT_DWELL_VETO", f"design.expert_s={exp_s:.1f}s (< 25s R1 non-connector dwell floor)")

    # 16. Area / empty ratio + 17. Symmetry + 18. Corridor detector
    walkable_tiles: List[Tuple[int, int]] = []
    feature_tiles = 0
    for y in range(h):
        for x in range(w):
            tt = grid[y][x]
            if tt in WALKABLE_BASE:
                walkable_tiles.append((x, y))
            elif tt != "wall" and tt != "void":
                feature_tiles += 1
    total_tiles = w * h
    walk_count = len(walkable_tiles)
    walk_ratio = walk_count / max(1, total_tiles)
    interior_tiles = max(1, (w - 2) * (h - 2))
    empty_ratio = walk_count / interior_tiles
    sh, sv, smax = compute_symmetry(grid)

    if reg["is_dungeon"]:
        if empty_ratio > 0.85 and feature_tiles == 0 and len(reg["interactables"]) <= 2:
            warn("EMPTY_BOX", f"high empty walkable ratio ({empty_ratio:.2f}) with minimal geometry/toys")
        if smax >= 0.88:
            warn("HIGH_SYMMETRY", f"symmetric layout (sym_h={sh}, sym_v={sv}, sym_max={smax})")
        puzzle_base = SIGNAL_EMITTERS | {
            "mirror", "blue_transformer", "transformer", "blue_portal", "portal",
            "tide_gate", "push_block", "bell", "moving_platform", "conveyor",
            "spinner", "crumble_floor", "bounce_bloom", "gravity_well", "wind_zone",
            "pull_ring", "carry_orb", "rotor", "tilt_group", "beam_emitter",
            "light_plant", "shadow_gate", "scale", "mimic_statue", "lantern_hook",
            "echo_rose", "trial_gate", "color_glass", "state_lever",
            "vehicle_skiff", "vehicle_cart", "tone_door", "toggle_block",
        }
        has_puzzle = any(
            str(it.get("kind", "")).lower() in puzzle_base
            or bool(toy_meta.get(str(it.get("kind", "")).lower(), {}).get("puzzle", False))
            for it in reg["interactables"]
        )
        has_reward = any(str(it.get("kind", "")).lower() in ("chest", "shrine", "wick_key", "keepers_flame", "moth", "pane_pickup", "great_lamp") for it in reg["interactables"])
        has_combat = len(reg["enemies"]) > 0 or any("wave" in act for ev in reg["events"] for act in (ev.get("do") or []) if isinstance(act, dict))
        has_story = len(reg["triggers"]) > 0 or any(str(it.get("kind", "")).lower() in ("npc", "lore_stone") for it in reg["interactables"])
        if not (has_puzzle or has_reward or has_combat or has_story) and len(exits) >= 2:
            warn("CORRIDOR_NO_IDEA", "connector room has no combat, puzzle, reward, or story hook")

    # 19. Prop over void / wall
    for sc in reg["scenery"]:
        if not isinstance(sc, dict):
            continue
        pkey = str(sc.get("prop", ""))
        layer = str(sc.get("layer", "sort")).lower()
        sp_p = sc.get("pos", [0, 0])
        if not (isinstance(sp_p, list) and len(sp_p) >= 2) or layer == "overhead":
            continue
        tt = _tile_at(reg, float(sp_p[0]), float(sp_p[1]))
        if tt in ("void", "pit") and pkey not in WATER_OR_FLOATING_PROPS:
            warn("PROP_OVER_VOID", f"scenery '{pkey}' at ({sp_p[0]},{sp_p[1]}) floats over '{tt}'")
        elif tt == "water" and pkey not in WATER_OR_FLOATING_PROPS:
            warn("PROP_OVER_WATER", f"scenery '{pkey}' at ({sp_p[0]},{sp_p[1]}) placed over water")
        elif tt == "wall" and layer == "ground":
            warn("PROP_ON_WALL", f"ground scenery '{pkey}' at ({sp_p[0]},{sp_p[1]}) overlaps wall")

    # 20. Light coverage (for dark rooms)
    is_dark = any(bool(z.get("dark", False)) for z in reg["zones"])
    pools: List[Tuple[float, float, float]] = []
    for it in reg["interactables"]:
        k = str(it.get("kind", "")).lower()
        r = INTERACTABLE_LIGHT_RADII.get(k, 0.0)
        if r > 0 and isinstance(it.get("pos"), list) and len(it["pos"]) >= 2:
            pools.append((float(it["pos"][0]), float(it["pos"][1]), r))
    for sc in reg["scenery"]:
        if isinstance(sc, dict):
            r = GLOW_PROP_RADII.get(str(sc.get("prop", "")), 0.0)
            p = sc.get("pos", [])
            if r > 0 and isinstance(p, list) and len(p) >= 2:
                pools.append((float(p[0]), float(p[1]) - 10.0, r))
    lit_tiles = 0
    if walk_count > 0 and pools:
        for tx, ty in walkable_tiles:
            cx, cy = (tx + 0.5) * ts, (ty + 0.5) * ts
            if any((cx - lx) ** 2 + (cy - ly) ** 2 <= lr * lr for lx, ly, lr in pools):
                lit_tiles += 1
    light_cov = lit_tiles / max(1, walk_count)
    if is_dark and walk_count > 0 and light_cov < 0.15:
        warn("LOW_LIGHT_COVERAGE", f"dark room has only {light_cov * 100:.1f}% walkable area covered by light pools (<15%)")

    # 23. Layer overlay palette check (if overlay PNGs exist)
    for lay in reg["layers"]:
        if not isinstance(lay, dict):
            continue
        ov = str(lay.get("overlay", "")).strip()
        if ov.endswith(".png"):
            ov_p = REPO_ROOT / ov.replace("res://", "")
            if ov_p.exists():
                ok_pal, off_n = check_png_palette_stdlib(ov_p)
                if not ok_pal:
                    err("LAYER_OFF_PALETTE", f"layer '{lay.get('id', '?')}' overlay {ov} has {off_n} off-palette/alpha pixels")

    # Tile hash for room variety check
    tile_sig = "\n".join("".join(t[0] for t in row) for row in grid)
    tile_hash = hashlib.sha256(tile_sig.encode("utf-8")).hexdigest()[:16]

    return {
        "key": reg["key"],
        "dungeon_id": infer_dungeon_id(reg, catalog),
        "errors": errors,
        "warnings": warnings,
        "metrics": {
            "width": w,
            "height": h,
            "walkable_tiles": walk_count,
            "walk_ratio": round(walk_ratio, 3),
            "empty_ratio": round(empty_ratio, 3),
            "sym_h": sh,
            "sym_v": sv,
            "sym_max": smax,
            "light_coverage": round(light_cov, 3),
            "design_complete": design_complete,
            "tile_hash": tile_hash,
            "enemies": len(reg["enemies"]),
            "interactables": len(reg["interactables"]),
        },
    }


def analyze_dungeons(
    regions: Dict[str, Dict[str, Any]],
    all_regions: Dict[str, Dict[str, Any]],
    catalog: Dict[str, Any],
) -> Dict[str, Any]:
    """Check key/lock counts, key ordering, cycles, shortcuts, and max backtrack per complete dungeon."""
    full_by_dungeon: Dict[str, Set[str]] = defaultdict(set)
    for reg in all_regions.values():
        did = infer_dungeon_id(reg, catalog)
        if did:
            full_by_dungeon[did].add(reg["key"])

    by_dungeon: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for reg in regions.values():
        did = infer_dungeon_id(reg, catalog)
        if did:
            by_dungeon[did].append(reg)

    out: Dict[str, Any] = {}
    for did, regs in sorted(by_dungeon.items()):
        # Only run dungeon-graph checks when every room of that dungeon is in the selection
        if {r["key"] for r in regs} != full_by_dungeon.get(did, set()):
            continue
        errors: List[Dict[str, Any]] = []
        warnings: List[Dict[str, Any]] = []
        reg_map = {r["id"]: r for r in regs}
        reg_ids = sorted(reg_map.keys())

        # Undirected graph for cycles, directed for backtrack
        undir_edges: Set[Tuple[str, str]] = set()
        adj: Dict[str, Set[str]] = {rid: set() for rid in reg_ids}
        shortcuts = 0
        wk_pickups = 0
        wk_locks = 0
        bk_pickups = 0
        bk_locks = 0

        for r in regs:
            rid = r["id"]
            for ex in r["exits"]:
                to_r = str(ex.get("to_region", ""))
                eid = str(ex.get("id", ""))
                if to_r in reg_map and to_r != rid:
                    adj[rid].add(to_r)
                    undir_edges.add((min(rid, to_r), max(rid, to_r)))
                    if "shortcut" in eid or "return" in eid:
                        shortcuts += 1
            for it in r["interactables"]:
                k = str(it.get("kind", "")).lower()
                props = it.get("props") or {}
                if k in ("wick_key", "key"):
                    kk = str(props.get("key_kind", "wick_key")).lower()
                    if kk == "keepers_flame":
                        bk_pickups += 1
                    else:
                        wk_pickups += 1
                elif k == "keepers_flame":
                    bk_pickups += 1
                elif k == "chest":
                    rk = str(props.get("reward_kind", props.get("reward", ""))).lower()
                    amt = int(props.get("amount", 1) or 1)
                    if rk == "wick_key":
                        wk_pickups += amt
                    elif rk == "keepers_flame":
                        bk_pickups += amt
                elif k in DOOR_KINDS:
                    dk = str(props.get("door_kind", props.get("door_type", k))).lower()
                    if dk in ("wick_key", "key_door", "locked_door"):
                        wk_locks += 1
                    elif dk in ("boss_key", "boss_door"):
                        bk_locks += 1

        if wk_locks > wk_pickups:
            errors.append({"code": "KEY_SHORTAGE", "msg": f"dungeon '{did}' has {wk_locks} wick_key locks but only {wk_pickups} keys"})
        if bk_locks > bk_pickups:
            errors.append({"code": "BOSS_KEY_SHORTAGE", "msg": f"dungeon '{did}' has {bk_locks} boss_key locks but only {bk_pickups} keepers_flame keys"})

        # Check dead key order (can all keys be gathered without passing through more key-locked exits than keys held?)
        entry = next((rid for rid in reg_ids if rid.endswith("_r1")), reg_ids[0])
        dmeta = catalog["dungeons"].get(did, {})
        if dmeta.get("entry") in reg_map:
            entry = str(dmeta["entry"])

        # Simulate room-graph key progression
        visited_r: Set[str] = {entry}
        owned_wk = 0
        opened_key_edges: Set[Tuple[str, str]] = set()
        collected_keys_ids: Set[str] = set()
        progressed = True
        while progressed:
            progressed = False
            for rid in list(visited_r):
                r = reg_map[rid]
                for it in r["interactables"]:
                    k = str(it.get("kind", "")).lower()
                    props = it.get("props") or {}
                    kid = f"{rid}:{it.get('id', '')}"
                    if kid in collected_keys_ids:
                        continue
                    if k in ("wick_key", "key") and str(props.get("key_kind", "wick_key")).lower() != "keepers_flame":
                        collected_keys_ids.add(kid)
                        owned_wk += 1
                        progressed = True
                    elif k == "chest" and str(props.get("reward_kind", props.get("reward", ""))).lower() == "wick_key":
                        collected_keys_ids.add(kid)
                        owned_wk += int(props.get("amount", 1) or 1)
                        progressed = True
            for rid in list(visited_r):
                r = reg_map[rid]
                inter_idx = {str(it.get("id", "")): it for it in r["interactables"]}
                for ex in r["exits"]:
                    to_r = str(ex.get("to_region", ""))
                    if to_r not in reg_map or to_r in visited_r:
                        continue
                    ldid = str(ex.get("locked_door_id", ""))
                    needs_wk = False
                    if ldid and ldid in inter_idx:
                        dprops = inter_idx[ldid].get("props") or {}
                        dk = str(dprops.get("door_kind", dprops.get("door_type", ""))).lower()
                        if dk in ("wick_key", "key_door", "locked_door"):
                            needs_wk = True
                    if not needs_wk:
                        visited_r.add(to_r)
                        progressed = True
                    elif owned_wk > len(opened_key_edges):
                        opened_key_edges.add((rid, ldid))
                        visited_r.add(to_r)
                        progressed = True

        unreachable_rooms = sorted(set(reg_ids) - visited_r)
        if unreachable_rooms:
            errors.append({"code": "DEAD_KEY_ORDER", "msg": f"dungeon '{did}' rooms unreachable from '{entry}' under key order: {unreachable_rooms}"})

        # Connected components & cycles: C = components, cycles = E - V + C
        seen_c: Set[str] = set()
        components = 0
        for rid in reg_ids:
            if rid in seen_c:
                continue
            components += 1
            dq = deque([rid])
            seen_c.add(rid)
            while dq:
                u = dq.popleft()
                for v in adj[u]:
                    if v not in seen_c:
                        seen_c.add(v)
                        dq.append(v)
        v_cnt = len(reg_ids)
        e_cnt = len(undir_edges)
        cycles = max(0, e_cnt - v_cnt + components)

        # Max backtrack (longest shortest-path distance from entry)
        dist = {entry: 0}
        dq2 = deque([entry])
        while dq2:
            u = dq2.popleft()
            for v in adj[u]:
                if v not in dist:
                    dist[v] = dist[u] + 1
                    dq2.append(v)
        max_backtrack = max(dist.values(), default=0)

        if v_cnt >= 5 and cycles < 2:
            warnings.append({"code": "LOW_DUNGEON_CYCLES", "msg": f"dungeon '{did}' has {cycles} cycle(s) (< 2 R1 floor; linear tube risk)"})
        if max_backtrack > 7:
            warnings.append({"code": "HIGH_BACKTRACK", "msg": f"dungeon '{did}' max backtrack is {max_backtrack} hops (> 7)"})

        out[did] = {
            "rooms": v_cnt,
            "edges": e_cnt,
            "cycles": cycles,
            "shortcuts": shortcuts,
            "max_backtrack": max_backtrack,
            "wick_keys": wk_pickups,
            "wick_key_locks": wk_locks,
            "boss_keys": bk_pickups,
            "boss_key_locks": bk_locks,
            "errors": errors,
            "warnings": warnings,
        }
    return out


def analyze_room_variety(regions: Dict[str, Dict[str, Any]], room_results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Detect exact duplicate layouts (tile hash) and near-duplicates (normalized edit/Hamming distance < 0.12)."""
    warnings: List[Dict[str, Any]] = []
    by_hash: Dict[str, List[str]] = defaultdict(list)
    for res in room_results:
        h = res.get("metrics", {}).get("tile_hash", "")
        if h:
            by_hash[h].append(res["key"])
    for h, keys in by_hash.items():
        if len(keys) > 1:
            warnings.append({"code": "DUPLICATE_LAYOUT", "msg": f"identical tile layout hash {h}: {keys}", "rooms": keys})

    # Near-duplicate check for same-dimension dungeon rooms
    by_dim: Dict[Tuple[int, int], List[Tuple[str, List[str]]]] = defaultdict(list)
    for r in regions.values():
        if r["is_dungeon"] and r["width"] > 0 and r["height"] > 0:
            flat = [r["grid"][y][x] for y in range(r["height"]) for x in range(r["width"])]
            by_dim[(r["width"], r["height"])].append((r["key"], flat))

    for dim, items in by_dim.items():
        n = len(items)
        for i in range(n):
            k1, g1 = items[i]
            for j in range(i + 1, n):
                k2, g2 = items[j]
                diff = sum(1 for a, b in zip(g1, g2) if a != b)
                norm = diff / max(1, len(g1))
                if 0.0 < norm < 0.12:
                    warnings.append({"code": "NEAR_DUPLICATE_LAYOUT", "msg": f"rooms {k1} and {k2} differ by only {norm * 100:.1f}% tiles", "rooms": [k1, k2], "distance": round(norm, 4)})
    return warnings


def discover_all_regions(fixtures_dir: Optional[Path] = None) -> Dict[str, Dict[str, Any]]:
    regions: Dict[str, Dict[str, Any]] = {}
    islands_root = REPO_ROOT / "luxel" / "islands"
    if not islands_root.is_dir():
        return regions
    for child in sorted(islands_root.iterdir()):
        if child.is_dir() and child.name.isdigit():
            isl_id = int(child.name)
            for mp in sorted(child.glob("*.map")):
                reg_id = mp.stem
                r = load_region(isl_id, reg_id, fixtures_dir)
                regions[r["key"]] = r
    return regions


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Luxel Epic static room linter (stdlib only)")
    ap.add_argument("--all", action="store_true", help="Lint all islands and regions")
    ap.add_argument("--island", type=int, action="append", default=[], help="Island ID(s) to lint")
    ap.add_argument("--dungeon", type=str, action="append", default=[], help="Dungeon ID(s) to lint")
    ap.add_argument("--region", type=str, action="append", default=[], help="Region ID(s) (e.g. 2:lighthouse_r2 or lighthouse_r2)")
    ap.add_argument("--fixtures", type=str, default="", help="Optional fixture overlay directory for design blocks")
    ap.add_argument("--require-design", action="store_true", help="Treat missing/incomplete design blocks as errors")
    ap.add_argument("--strict", action="store_true", help="Treat warnings (including R1 floors/vetoes) as errors")
    ap.add_argument("--json", nargs="?", const="-", default=None, help="Output JSON report (stdout or file path)")
    ap.add_argument("--out", type=str, default="", help="Write JSON report to file path")
    args = ap.parse_args(argv)

    if not (args.all or args.island or args.dungeon or args.region):
        args.all = True

    fixtures_dir = Path(args.fixtures) if args.fixtures else None
    catalog = load_engine_catalog()
    all_regions = discover_all_regions(fixtures_dir)

    # Build incoming spawns map from all regions so cross-room spawn distance checks are exact
    incoming_spawns: Dict[str, List[Tuple[float, float]]] = defaultdict(list)
    for r in all_regions.values():
        for ex in r["exits"]:
            to_reg = str(ex.get("to_region", ""))
            to_isl = int(ex.get("to_island", r["island_id"]))
            if to_reg.startswith("island") and ":" in to_reg:
                p0, p1 = to_reg.split(":", 1)
                if p0[6:].isdigit():
                    to_isl = int(p0[6:])
                    to_reg = p1 or "overworld"
            tsp = ex.get("to_spawn")
            if to_reg and isinstance(tsp, list) and len(tsp) >= 2:
                incoming_spawns[f"{to_isl}:{to_reg}"].append((float(tsp[0]), float(tsp[1])))

    # Filter target regions
    selected_keys: List[str] = []
    if args.all:
        selected_keys = sorted(
            k for k, r in all_regions.items()
            if not (r["id"].startswith("_") or bool(r.get("json", {}).get("debug_only", False)))
        )
    else:
        want_isls = set(args.island)
        want_duns = {d.lower() for d in args.dungeon}
        want_regs = set(args.region)
        for k, r in sorted(all_regions.items()):
            did = infer_dungeon_id(r, catalog).lower()
            match = False
            if want_isls and r["island_id"] in want_isls and not want_duns and not want_regs:
                match = True
            if want_duns and (did in want_duns or any(r["id"].startswith(d + "_") for d in want_duns)):
                if not want_isls or r["island_id"] in want_isls:
                    match = True
            if want_regs and (k in want_regs or r["id"] in want_regs):
                if not want_isls or r["island_id"] in want_isls:
                    match = True
            if match:
                selected_keys.append(k)

    selected_regions = {k: all_regions[k] for k in selected_keys}
    room_results = [
        lint_region(all_regions[k], all_regions, incoming_spawns, catalog, require_design=args.require_design)
        for k in selected_keys
    ]
    dungeon_results = analyze_dungeons(selected_regions, all_regions, catalog)
    variety_warnings = analyze_room_variety(selected_regions, room_results)

    total_errors = sum(len(r["errors"]) for r in room_results) + sum(len(d["errors"]) for d in dungeon_results.values())
    total_warnings = (
        sum(len(r["warnings"]) for r in room_results)
        + sum(len(d["warnings"]) for d in dungeon_results.values())
        + len(variety_warnings)
    )
    err_counts = Counter(e["code"] for r in room_results for e in r["errors"])
    for d in dungeon_results.values():
        for e in d["errors"]:
            err_counts[e["code"]] += 1
    warn_counts = Counter(w["code"] for r in room_results for w in r["warnings"])
    for d in dungeon_results.values():
        for w in d["warnings"]:
            warn_counts[w["code"]] += 1
    for w in variety_warnings:
        warn_counts[w["code"]] += 1

    report = {
        "rooms_checked": len(room_results),
        "dungeons_checked": len(dungeon_results),
        "total_errors": total_errors,
        "total_warnings": total_warnings,
        "error_counts": dict(err_counts.most_common()),
        "warning_counts": dict(warn_counts.most_common()),
        "variety_warnings": variety_warnings,
        "dungeons": dungeon_results,
        "rooms": room_results,
    }

    json_dest = args.out or (args.json if args.json and args.json != "-" else "")
    if json_dest:
        out_p = Path(json_dest)
        out_p.parent.mkdir(parents=True, exist_ok=True)
        out_p.write_text(json.dumps(report, indent=2), encoding="utf-8")
    if args.json == "-":
        print(json.dumps(report, indent=2))
    else:
        status = "PASS" if (total_errors == 0 and (not args.strict or total_warnings == 0)) else "FAIL"
        print(f"ROOM LINT {status}: rooms={len(room_results)} dungeons={len(dungeon_results)} errors={total_errors} warnings={total_warnings}")
        if err_counts:
            print("  Errors:   " + ", ".join(f"{k}={v}" for k, v in err_counts.most_common()))
        if warn_counts:
            print("  Warnings: " + ", ".join(f"{k}={v}" for k, v in warn_counts.most_common()))
        shown = 0
        for r in room_results:
            for e in r["errors"]:
                if shown < 30:
                    print(f"  [ERR]  {r['key']} {e['code']}: {e['msg']}")
                    shown += 1
        for did, d in dungeon_results.items():
            for e in d["errors"]:
                print(f"  [ERR]  dungeon:{did} {e['code']}: {e['msg']}")
        if args.strict:
            wshown = 0
            for r in room_results:
                for w in r["warnings"]:
                    if wshown < 20:
                        print(f"  [WARN] {r['key']} {w['code']}: {w['msg']}")
                        wshown += 1

    if total_errors > 0 or (args.strict and total_warnings > 0):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
