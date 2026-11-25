#!/usr/bin/env python3
"""Luxel Epic playtime model (Python 3 stdlib only), calibrated on Marwan's 42 rooms.

Features:
- Keeps the linear NNLS calibration fit on Marwan's 42 recorded 1.0 rooms unchanged.
- Prices Epic bosses, mini-bosses, and superbosses from boss_check TTKs
  (docs/fullgame/epic/reports/*.md + tests/luxel/boss_specs/*.json) instead of raw HP/DPS:
    expert     = 1.15 * bot_ttk + exp_retries * 0.60 * (1.15 * bot_ttk)
                 (minis 0.3, bosses 0.6, superbosses 1.5 retries at 60% of a run)
    first_time = ft_pace * bot_ttk + ft_retries * 0.60 * (ft_pace * bot_ttk)
                 (higher first-time pace & retries: minis 1.8, bosses 3.0, superbosses 5.5)
- Counts overworld quests, trials, moths, and minigames from design blocks, room
  interactables/challenges, and overworld pack quest tables.
- Splits `--summary` into Critical Path vs Optional (caves, trials, superbosses, hub,
  and optional overworld quests/trials/moths/minigames).

Usage:
  python3 tools/epic/playtime.py [--island N] [--dungeon ID] [--by room|dungeon|island|game|all]
  python3 tools/epic/playtime.py --summary | --bibles | --fit-report [--json PATH]
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
import math
from pathlib import Path
import re
import sys
from typing import Any, Dict, List, Optional, Sequence, Set, Tuple

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import room_lint as rl  # noqa: E402

REPO_ROOT = rl.REPO_ROOT
CALIBRATION_PATH = SCRIPT_DIR / "calibration.json"

# R1 per-kind first-time multipliers (docs/fullgame/epic/research/R1_SOTA_DESIGN.md §1.2-1.3)
R1_MULTIPLIERS: Dict[str, float] = {
    "default": 2.7,
    "puzzle": 3.2,
    "overworld": 2.8,
    "story": 2.8,
    "reward": 2.7,
    "setpiece": 2.7,
    "boss": 2.6,
    "combat": 2.2,
    "traversal": 2.1,
}

SUPERBOSS_IDS: Set[str] = {
    "silent_bell", "undertow", "mother_root", "boss_last_hour",
    "event_horizon", "first_forge", "shadow_at_noon", "first_dark",
}

BOSS_RETRY_PARAMS: Dict[str, Dict[str, float]] = {
    # expert = 1.15 * bot_ttk + exp_retries * (0.60 * 1.15 * bot_ttk)
    "mini": {"exp_pace": 1.15, "exp_retries": 0.3, "ft_pace": 1.45, "ft_retries": 1.8},
    "boss": {"exp_pace": 1.15, "exp_retries": 0.6, "ft_pace": 1.45, "ft_retries": 3.0},
    "superboss": {"exp_pace": 1.15, "exp_retries": 1.5, "ft_pace": 1.50, "ft_retries": 5.5},
}

# Regular encounter enemies that share names with boss families (never priced as boss_check arenas)
NON_BOSS_ENCOUNTER_KINDS: Set[str] = {"moonshade_warden", "hollow_wick"}

DEFAULT_ENEMY_STATS: Dict[str, Dict[str, Any]] = {}


def load_enemy_stats() -> Dict[str, Dict[str, Any]]:
    """Parse max_hp, shield_hp, tell_time, recover_time, is_boss from enemy_factory.gd and packs."""
    stats: Dict[str, Dict[str, Any]] = {}
    ef = REPO_ROOT / "luxel" / "enemies" / "enemy_factory.gd"
    if ef.exists():
        txt = ef.read_text(encoding="utf-8")
        pat = re.compile(
            r'_make_data\(\s*"([a-z0-9_]+)"\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,'
            r'\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)'
            r'(?:\s*,\s*([0-9.]+))?(?:\s*,\s*([0-9]+))?(?:\s*,\s*([0-9.]+))?(?:\s*,\s*(true|false))?'
        )
        for m in pat.finditer(txt):
            kind = m.group(1)
            stats[kind] = {
                "max_hp": float(m.group(2)),
                "tell_time": float(m.group(7)),
                "recover_time": float(m.group(8)),
                "shield_hp": float(m.group(9) or 0.0),
                "is_boss": (m.group(12) == "true"),
            }
    for pat_glob in ("luxel/data/packs/*.json", "luxel/islands/*/packs/*.json"):
        for pp in sorted(REPO_ROOT.glob(pat_glob)):
            try:
                pd = json.loads(pp.read_text(encoding="utf-8"))
            except Exception:
                continue
            if not isinstance(pd, dict):
                continue
            bosses_meta = pd.get("bosses") or {}
            for k, v in (pd.get("enemies") or {}).items():
                if isinstance(v, dict):
                    ed = v.get("data") if isinstance(v.get("data"), dict) else v
                    stats[str(k).lower()] = {
                        "max_hp": float(ed.get("max_hp", 4.0)),
                        "tell_time": float(ed.get("tell_time", 0.5)),
                        "recover_time": float(ed.get("recover_time", 1.0)),
                        "shield_hp": float(ed.get("shield_hp", 0.0)),
                        "is_boss": bool(ed.get("is_boss", str(k).lower() in bosses_meta)),
                        "phases": len((bosses_meta.get(str(k).lower()) or {}).get("phases", [0.5])) + 1,
                    }
    return stats


def _load_mini_boss_set() -> Set[str]:
    """Collect mini-boss IDs from islands.json and pack dungeon definitions."""
    minis: Set[str] = set()
    isl_p = REPO_ROOT / "luxel" / "data" / "islands.json"
    if isl_p.exists():
        try:
            d = json.loads(isl_p.read_text(encoding="utf-8"))
            for item in d.get("islands", []):
                if isinstance(item, dict) and item.get("mini_boss"):
                    minis.add(str(item["mini_boss"]).strip().lower())
        except Exception:
            pass
    for pp in sorted(REPO_ROOT.glob("luxel/islands/*/packs/*.json")):
        try:
            pd = json.loads(pp.read_text(encoding="utf-8"))
        except Exception:
            continue
        ds = pd.get("dungeons", [])
        if isinstance(ds, dict):
            ds = list(ds.values())
        if isinstance(ds, list):
            for dm in ds:
                if isinstance(dm, dict) and dm.get("mini_boss"):
                    minis.add(str(dm["mini_boss"]).strip().lower())
    return minis


def load_boss_check_ttks() -> Dict[str, Dict[str, Any]]:
    """Load boss_check TTKs from tests/luxel/boss_specs/*.json and docs/fullgame/epic/reports/*.md."""
    table: Dict[str, Dict[str, Any]] = {}
    mini_set = _load_mini_boss_set()

    specs_dir = REPO_ROOT / "tests" / "luxel" / "boss_specs"
    if specs_dir.is_dir():
        for sp in sorted(specs_dir.glob("*.json")):
            bid = sp.stem.lower()
            if bid.startswith("demo_"):
                continue
            try:
                d = json.loads(sp.read_text(encoding="utf-8"))
            except Exception:
                continue
            if not isinstance(d, dict):
                continue
            ttk_raw = d.get("ttk")
            ttk_lo, ttk_hi = 60.0, 90.0
            if isinstance(ttk_raw, list) and len(ttk_raw) >= 2:
                ttk_lo, ttk_hi = float(ttk_raw[0]), float(ttk_raw[1])
            elif isinstance(ttk_raw, (int, float)):
                ttk_lo = ttk_hi = float(ttk_raw)
            ttk_mid = 0.5 * (ttk_lo + ttk_hi)

            # Determine tier: superboss > mini > boss
            if bid in SUPERBOSS_IDS:
                tier = "superboss"
            elif d.get("mini") is True:
                tier = "mini"
            elif d.get("mini") is False:
                tier = "boss"
            elif bid in mini_set or (ttk_lo <= 55.0 and ttk_hi <= 95.0 and bid != "bellkeeper"):
                tier = "mini"
            else:
                tier = "boss"

            table[bid] = {
                "boss_id": bid,
                "tier": tier,
                "spec_ttk_lo": ttk_lo,
                "spec_ttk_hi": ttk_hi,
                "spec_ttk_mid": round(ttk_mid, 2),
                "measured_ttk": None,
                "measured_source": "",
                "measured_tag": "",
                "bot_ttk": round(ttk_mid, 2),
                "source": "spec",
            }

    # Overlay measured non-legacy boss_check TTKs from docs/fullgame/epic/reports/*.md
    reports_dir = REPO_ROOT / "docs" / "fullgame" / "epic" / "reports"
    pat = re.compile(r"([a-z0-9_]+)\[([^\]]+)\]\(ttk=([0-9.]+)s")
    if reports_dir.is_dir():
        for rp in sorted(reports_dir.glob("*.md")):
            try:
                txt = rp.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for m in pat.finditer(txt):
                bid = m.group(1).strip().lower()
                tag = m.group(2).strip().lower()
                ttk_s = float(m.group(3))
                if "legacy" in tag:
                    continue
                if bid not in table:
                    tier = "superboss" if bid in SUPERBOSS_IDS else ("mini" if (bid in mini_set or ttk_s < 75.0) else "boss")
                    table[bid] = {
                        "boss_id": bid, "tier": tier,
                        "spec_ttk_lo": ttk_s, "spec_ttk_hi": ttk_s, "spec_ttk_mid": ttk_s,
                        "measured_ttk": None, "measured_source": "", "measured_tag": "",
                        "bot_ttk": ttk_s, "source": "report",
                    }
                cur_tag = str(table[bid].get("measured_tag", ""))
                # Prefer [region] over [arena] over unset
                prefer_new = (
                    table[bid]["measured_ttk"] is None
                    or ("region" in tag and "region" not in cur_tag)
                    or (rp.name.startswith("LB") and not str(table[bid]["measured_source"]).startswith("LB"))
                )
                if prefer_new:
                    table[bid]["measured_ttk"] = round(ttk_s, 2)
                    table[bid]["measured_source"] = rp.name
                    table[bid]["measured_tag"] = tag
                    table[bid]["bot_ttk"] = round(ttk_s, 2)
                    table[bid]["source"] = f"report:{rp.name}"

    return table


def score_boss_encounter(
    kind: str,
    reg_id: str,
    enemy_spec: Dict[str, Any],
    boss_ttks: Dict[str, Dict[str, Any]],
) -> Optional[Dict[str, Any]]:
    """Compute (expert_s, first_s, tier, bot_ttk, source) for a boss/mini-boss/superboss enemy."""
    k = kind.strip().lower()
    if k in NON_BOSS_ENCOUNTER_KINDS:
        return None
    alias_map = {
        "belfry_warden": "bell_warden",
        "grand_bellkeeper": "bellkeeper",
    }
    k = alias_map.get(k, k)
    entry = boss_ttks.get(k)
    if entry is None:
        return None

    tier = str(entry["tier"])
    if reg_id.startswith(("superboss_", "sb_", "vault_last_hour", "cave_undertow_maw")):
        tier = "superboss"

    bot_ttk = float(entry["bot_ttk"])
    # Multi-encounter stair_warden (stair_r4 Act I, stair_r8 Act II, stair_r10 Act III)
    if k == "stair_warden":
        st_tier = int(enemy_spec.get("tier", 0) or 0)
        if st_tier == 1 or reg_id == "stair_r4":
            bot_ttk *= 0.55
            tier = "mini"
        elif st_tier == 2 or reg_id == "stair_r8":
            bot_ttk *= 0.72
            tier = "mini"
        else:
            tier = "boss"

    p = BOSS_RETRY_PARAMS[tier]
    exp_run = p["exp_pace"] * bot_ttk
    exp_s = exp_run + p["exp_retries"] * 0.60 * exp_run
    ft_run = p["ft_pace"] * bot_ttk
    ft_s = ft_run + p["ft_retries"] * 0.60 * ft_run
    return {
        "boss_id": k,
        "tier": tier,
        "bot_ttk": round(bot_ttk, 2),
        "expert_s": exp_s,
        "first_s": ft_s,
        "source": str(entry["source"]),
    }


def enemy_ttk_weight(kind: str, stats: Dict[str, Dict[str, Any]]) -> Tuple[float, bool]:
    """Baseline 1.0 enemy/boss weight used ONLY for Marwan's 42-room calibration fit."""
    aliases = {
        "parasol_toad": "warden", "toad_warden": "warden", "magpie": "snatcher",
        "magpie_snatcher": "snatcher", "hush_owl": "owl", "owl_sentinel": "owl",
        "moonshade": "moonshade_warden", "belfry_warden": "bell_warden", "grand_bellkeeper": "bellkeeper",
    }
    k = aliases.get(kind.lower(), kind.lower())
    st = stats.get(k, {"max_hp": 3.0, "shield_hp": 0.0, "tell_time": 0.5, "recover_time": 1.0, "is_boss": False})
    hp = float(st["max_hp"])
    sh = float(st["shield_hp"])
    is_boss = bool(st["is_boss"])
    if is_boss:
        phases = int(st.get("phases", 2 if hp >= 12.0 else 1))
        retry_factor = 1.0 + (0.20 if hp >= 18.0 else 0.05)
        ttk = (2.0 + hp / 1.85 + sh * 0.65 + (phases - 1) * 1.8) * retry_factor
        return ttk, True
    ttk = 0.7 + hp / 1.85 + sh * 0.6 + (0.45 if k in ("gloam", "phantom_owl", "ash_mole", "snatcher", "gull_thief") else 0.0)
    return ttk, False


def infer_room_kind(reg: Dict[str, Any], enemy_stats: Dict[str, Dict[str, Any]], boss_ttks: Optional[Dict[str, Dict[str, Any]]] = None) -> str:
    if reg.get("design") and reg["design"].get("kind"):
        return str(reg["design"]["kind"]).lower()
    if not reg["is_dungeon"] or reg["id"] == "overworld":
        return "overworld"
    has_boss = False
    for e in reg["enemies"]:
        ek = str(e.get("kind", "")).lower()
        if boss_ttks is not None and score_boss_encounter(ek, reg["id"], e, boss_ttks) is not None:
            has_boss = True
            break
        if enemy_ttk_weight(ek, enemy_stats)[1]:
            has_boss = True
            break
    if has_boss:
        return "boss"
    inters = reg["interactables"]
    puzzle_n = sum(
        1 for it in inters
        if str(it.get("kind", "")).lower() in (
            "switch_eye", "switch", "mirror", "blue_transformer", "transformer",
            "blue_portal", "portal", "tide_gate", "tide", "brazier", "timed_brazier",
            "pressure_plate", "push_block", "beam_emitter", "beam_sensor", "bell",
            "logic_gate", "sequence_orbs", "floor_sigil", "echo_rose", "scale", "state_lever",
        )
    )
    if puzzle_n >= 2 or any(str(it.get("kind", "")).lower() in ("mirror", "blue_transformer", "tide_gate", "blue_portal") for it in inters):
        return "puzzle"
    if len(reg["enemies"]) >= 1:
        return "combat"
    if any(str(it.get("kind", "")).lower() in ("shrine", "chest", "great_lamp", "rest_shrine") for it in inters):
        return "reward"
    return "traversal"


def extract_features(reg: Dict[str, Any], enemy_stats: Dict[str, Dict[str, Any]]) -> Dict[str, float]:
    """Compute interpretable playtime feature vector for a region (kept identical for Marwan's 42-room fit)."""
    w, h = reg["width"], reg["height"]
    grid = reg["grid"]
    walk_tiles = sum(1 for y in range(h) for x in range(w) if grid[y][x] in rl.WALKABLE_BASE)
    hazard_tiles = sum(1 for y in range(h) for x in range(w) if grid[y][x] in rl.HAZARD_TILES)
    is_ow = 1.0 if (not reg["is_dungeon"] or reg["id"] == "overworld") else 0.0

    area_walk = math.sqrt(max(1, walk_tiles)) * (1.0 + 0.25 * min(6, len(reg["zones"])) if is_ow else 0.65)
    hazard_frac = hazard_tiles / max(1, w * h)

    enemy_ttk = 0.0
    boss_ttk = 0.0
    for e in reg["enemies"]:
        ttk, is_b = enemy_ttk_weight(str(e.get("kind", "")), enemy_stats)
        if is_b:
            boss_ttk += ttk
        else:
            enemy_ttk += ttk
    for ev in reg["events"]:
        for act in ev.get("do", []) if isinstance(ev.get("do"), list) else []:
            if isinstance(act, dict) and "wave" in act:
                ws = act["wave"] if isinstance(act["wave"], list) else [act["wave"]]
                for we in ws:
                    if isinstance(we, dict):
                        ttk, is_b = enemy_ttk_weight(str(we.get("kind", "")), enemy_stats)
                        if is_b:
                            boss_ttk += ttk
                        else:
                            enemy_ttk += ttk

    des = reg.get("design")
    if isinstance(des, dict) and (des.get("decisions") or des.get("solution")):
        dec = float(des.get("decisions", 0) or 0)
        sol = des.get("solution") if isinstance(des.get("solution"), list) else []
        sol_ops = sum(1 for op in sol if isinstance(op, dict) and str(op.get("op", "")) not in ("expect", "expect_exit", "wait"))
        puzzle_units = max(dec, sol_ops * 0.65)
    else:
        puzzle_units = 0.0
        for it in reg["interactables"]:
            k = str(it.get("kind", "")).lower()
            if k in ("mirror", "blue_transformer", "transformer"):
                props = it.get("props") or {}
                puzzle_units += 2.2 if props.get("movable", k != "mirror") else 1.2
            elif k in ("switch_eye", "switch", "pressure_plate", "timed_brazier", "beam_sensor", "light_sensor", "sequence_orbs", "floor_sigil"):
                puzzle_units += 1.0
            elif k in ("blue_portal", "portal", "tide_gate", "tide", "push_block", "echo_rose", "scale", "state_lever", "bell"):
                puzzle_units += 1.3
            elif k in ("bramble", "cracked_wall", "cracked", "web", "obsidian_seal", "seal"):
                puzzle_units += 0.6
            elif k in ("brazier", "phantom_platform", "phantom"):
                puzzle_units += 0.7
            elif k in rl.DOOR_KINDS:
                dk = str((it.get("props") or {}).get("door_kind", "")).lower()
                if dk in ("bridge_platform", "switch_door", "shutter"):
                    puzzle_units += 0.5

    reading_units = 0.0
    reading_units += len(reg["triggers"]) * 0.8
    for it in reg["interactables"]:
        k = str(it.get("kind", "")).lower()
        if k in ("shrine", "beacon", "great_lamp", "great_belfry_brazier", "lantern_pickup"):
            reading_units += 1.8
        elif k in ("npc", "lore_stone", "waystone", "rest_shrine", "shop_npc"):
            reading_units += 1.2
        elif k in ("chest", "wick_key", "keepers_flame", "key", "moth", "pane_pickup"):
            reading_units += 0.7

    exits_n = len(reg["exits"])
    travel_units = max(1.0, float(exits_n) * (1.2 if is_ow else 0.75)) + hazard_frac * 3.0

    return {
        "bias": 1.0,
        "area_walk": area_walk,
        "enemy_ttk": enemy_ttk,
        "boss_ttk": boss_ttk,
        "puzzle_units": puzzle_units,
        "reading_units": reading_units,
        "travel_units": travel_units,
    }


FEATURE_NAMES: Tuple[str, ...] = (
    "bias", "area_walk", "enemy_ttk", "boss_ttk", "puzzle_units", "reading_units", "travel_units",
)


def _solve_linear_system(A: List[List[float]], b: List[float]) -> List[float]:
    n = len(b)
    M = [row[:] + [b[i]] for i, row in enumerate(A)]
    for col in range(n):
        piv = max(range(col, n), key=lambda r: abs(M[r][col]))
        M[col], M[piv] = M[piv], M[col]
        if abs(M[col][col]) < 1e-12:
            continue
        inv = 1.0 / M[col][col]
        for j in range(col, n + 1):
            M[col][j] *= inv
        for r in range(n):
            if r != col:
                f = M[r][col]
                for j in range(col, n + 1):
                    M[r][j] -= f * M[col][j]
    return [M[i][n] for i in range(n)]


def fit_weights_nnls(X: List[List[float]], y: List[float], ridge: float = 2.0) -> List[float]:
    """Fit non-negative ridge-regularized linear weights via active-set normal equations."""
    p = len(X[0])
    prior = [2.0, 0.75, 1.0, 1.0, 2.8, 1.8, 1.5]
    active = [True] * p
    w = prior[:]
    for _ in range(12):
        idx = [j for j in range(p) if active[j]]
        if not idx:
            break
        k = len(idx)
        AtA = [[0.0] * k for _ in range(k)]
        Aty = [0.0] * k
        for xi, yi in zip(X, y):
            for a, ja in enumerate(idx):
                Aty[a] += xi[ja] * yi
                for b_i, jb in enumerate(idx):
                    AtA[a][b_i] += xi[ja] * xi[jb]
        for a, ja in enumerate(idx):
            AtA[a][a] += ridge
            Aty[a] += ridge * prior[ja]
        sol = _solve_linear_system(AtA, Aty)
        w = [0.0] * p
        neg_found = False
        for a, ja in enumerate(idx):
            if sol[a] < 0.0:
                active[ja] = False
                neg_found = True
            else:
                w[ja] = sol[a]
        if not neg_found:
            break
    floors = [1.0, 0.25, 0.75, 0.75, 2.0, 0.6, 0.5]
    return [max(w[i], floors[i]) for i in range(p)]


def predict_expert_s(feat: Dict[str, float], weights: List[float], reg: Dict[str, Any]) -> float:
    """Baseline 1.0 calibrated predictor (used for Marwan's 42-room fit evaluation)."""
    model_s = sum(feat[name] * weights[i] for i, name in enumerate(FEATURE_NAMES))
    return max(4.0, model_s)


def load_pack_quests() -> Dict[int, List[Dict[str, Any]]]:
    """Load quest definitions per island from hub & overworld packs."""
    by_isl: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
    seen: Set[str] = set()
    for pp in sorted(REPO_ROOT.glob("luxel/islands/*/packs/*.json")):
        m = re.search(r"islands/(\d+)/packs/", pp.as_posix())
        if not m:
            continue
        isl = int(m.group(1))
        try:
            pd = json.loads(pp.read_text(encoding="utf-8"))
        except Exception:
            continue
        qs = pd.get("quests")
        if isinstance(qs, list):
            for q in qs:
                if isinstance(q, dict):
                    qid = str(q.get("id", "")).strip()
                    if qid and qid not in seen:
                        seen.add(qid)
                        by_isl[int(q.get("island", isl))].append(q)
    return by_isl


def _collect_room_bosses(reg: Dict[str, Any], boss_ttks: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
    found: List[Dict[str, Any]] = []
    for e in reg["enemies"]:
        res = score_boss_encounter(str(e.get("kind", "")), reg["id"], e, boss_ttks)
        if res is not None:
            found.append(res)
    for ev in reg["events"]:
        for act in ev.get("do", []) if isinstance(ev.get("do"), list) else []:
            if isinstance(act, dict) and "wave" in act:
                ws = act["wave"] if isinstance(act["wave"], list) else [act["wave"]]
                for we in ws:
                    if isinstance(we, dict):
                        res = score_boss_encounter(str(we.get("kind", "")), reg["id"], we, boss_ttks)
                        if res is not None:
                            found.append(res)
    return found


def extract_room_overworld_activities(
    reg: Dict[str, Any],
    is_overworld_zone: bool,
    pack_quests_for_room: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    """Count quests, trials, moths, and minigames from design blocks + room interactables/events."""
    des = reg.get("design") if isinstance(reg.get("design"), dict) else {}
    idea = str(des.get("idea", "")).lower()
    rew = str(des.get("reward", "")).lower()
    teaches = str(des.get("teaches", "")).lower()
    dkind = str(des.get("kind", "")).lower()
    rid = str(reg["id"]).lower()
    blob = " ".join((idea, rew, teaches))

    # 1. Moths: explicit design.moths, interactables (moth/ow_hide_moth), or moth_<i>_<n> tokens in design.reward
    moth_ids: Set[str] = set()
    if isinstance(des.get("moths"), list):
        for mv in des["moths"]:
            moth_ids.add(str(mv).lower())
    elif isinstance(des.get("moths"), int):
        for i in range(int(des["moths"])):
            moth_ids.add(f"des_moth_{i}")
    inter_moths = 0
    for it in reg["interactables"]:
        k = str(it.get("kind", "")).lower()
        if k in ("moth", "ow_hide_moth"):
            inter_moths += 1
            props = it.get("props") or {}
            mid = str(props.get("moth_id", props.get("id", it.get("id", f"m{inter_moths}")))).lower()
            moth_ids.add(mid)
    for tok in re.findall(r"\bmoth_\d+_\d+\b", rew):
        if len(moth_ids) < inter_moths + 1:
            moth_ids.add(tok)
    moths_n = max(inter_moths, len(moth_ids))

    # 2. Trials: explicit design.trials, trial_gate/*_trial interactables, challenge events, or trial_* room/reward
    trials_n = 0
    challenge_max_t = 0.0
    for ev in reg["events"]:
        for act in ev.get("do", []) if isinstance(ev.get("do"), list) else []:
            if isinstance(act, dict) and isinstance(act.get("challenge"), dict):
                challenge_max_t = max(challenge_max_t, float(act["challenge"].get("time", 35.0) or 35.0))
    if isinstance(des.get("trials"), list):
        trials_n = len(des["trials"])
    elif isinstance(des.get("trials"), int):
        trials_n = int(des["trials"])
    else:
        tg_n = sum(1 for it in reg["interactables"] if str(it.get("kind", "")).lower() in ("trial_gate",) or str(it.get("kind", "")).lower().endswith("_trial"))
        has_trial_event = challenge_max_t > 0.0
        has_trial_design = (dkind == "trial") or bool(re.search(r"\b(trial_medal|stride_trial|foundry_trial|carillon_trial|hush_trial|phase_trial|relay_trial)\b", rew)) or rid.startswith("trial_")
        trials_n = max(tg_n, 1 if (has_trial_event or has_trial_design) else 0)

    # 3. Minigames: explicit design.minigames or overworld minigame design cues (distinct from generic trials)
    minigames_n = 0
    if isinstance(des.get("minigames"), list):
        minigames_n = len(des["minigames"])
    elif isinstance(des.get("minigames"), int):
        minigames_n = int(des["minigames"])
    elif is_overworld_zone or rid.startswith(("cave_", "trial_")):
        mg_hits: Set[str] = set()
        for kw, tag in (
            ("minigame", "minigame"),
            ("carillon", "carillon"),
            ("regatta", "regatta"),
            ("hide-and-seek", "hide_seek"),
            ("hide_and_seek", "hide_seek"),
            ("shooting range", "range"),
            ("target range", "range"),
            ("chime relay", "relay"),
            ("trial_relay", "relay"),
            ("constellation sprint", "sprint"),
            ("canopy sprint", "sprint"),
            ("moth scales", "scales"),
        ):
            if kw in blob or kw.replace(" ", "_") in rid:
                mg_hits.add(tag)
        for it in reg["interactables"]:
            k = str(it.get("kind", "")).lower()
            if k in ("ow_chime_relay", "ow_hide_moth", "i7_trial_target"):
                mg_hits.add(k)
        # Avoid double-counting a trial that is ALREADY the room's sole minigame
        minigames_n = max(0, len(mg_hits) - (1 if (trials_n > 0 and len(mg_hits) == 1 and not is_overworld_zone) else 0))

    # 4. Quests: explicit design.quests + pack quests attributed to this host room
    quests_n = 0
    quest_steps = 0
    if pack_quests_for_room:
        quests_n += len(pack_quests_for_room)
        for q in pack_quests_for_room:
            steps = q.get("steps")
            quest_steps += len(steps) if isinstance(steps, list) and len(steps) > 0 else 2
    if isinstance(des.get("quests"), list):
        extra_q = len(des["quests"])
        if extra_q > quests_n:
            quest_steps += (extra_q - quests_n) * 2
            quests_n = extra_q
    elif isinstance(des.get("quests"), int):
        extra_q = int(des["quests"])
        if extra_q > quests_n:
            quest_steps += (extra_q - quests_n) * 2
            quests_n = extra_q

    # Compute optional activity seconds (never double-counted into base calibrated features)
    # Overworld moths take ~18s expert to find/catch; dungeon/cave moths take ~8s extra on top of room puzzle
    moth_exp_s = moths_n * (18.0 if is_overworld_zone else 8.0)
    moth_ft_s = moth_exp_s * R1_MULTIPLIERS["overworld"]

    # Timed/no-hit/race trials: active trial time + ~0.4 expert retry / ~1.5 first-time retry
    trial_base = max(35.0, challenge_max_t * 0.75) if challenge_max_t > 0.0 else 38.0
    # In dedicated trial_* rooms, the base feature model already covers ~20s of layout; add only the delta
    trial_per_exp = max(18.0, trial_base - (15.0 if rid.startswith("trial_") else 0.0))
    trial_exp_s = trials_n * trial_per_exp
    trial_ft_s = trial_exp_s * R1_MULTIPLIERS["setpiece"]

    mg_exp_s = minigames_n * 42.0
    mg_ft_s = mg_exp_s * R1_MULTIPLIERS["setpiece"]

    # Overworld multi-step quests: 35s intro/turn-in + 25s per step expert (2.8x first-time)
    quest_exp_s = quests_n * 35.0 + quest_steps * 25.0
    quest_ft_s = quest_exp_s * R1_MULTIPLIERS["overworld"]

    return {
        "quests": quests_n,
        "trials": trials_n,
        "moths": moths_n,
        "minigames": minigames_n,
        "activity_exp_s": moth_exp_s + trial_exp_s + mg_exp_s + quest_exp_s,
        "activity_first_s": moth_ft_s + trial_ft_s + mg_ft_s + quest_ft_s,
    }


def predict_epic_room(
    reg: Dict[str, Any],
    feat: Dict[str, float],
    weights: List[float],
    rkind: str,
    mults: Dict[str, float],
    boss_ttks: Dict[str, Dict[str, Any]],
    is_overworld_zone: bool,
    pack_quests_for_room: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    """Compute Epic expert & first-time seconds using boss_check TTKs and overworld activities."""
    m = float(mults.get(rkind, mults["default"]))
    bosses = _collect_room_bosses(reg, boss_ttks)
    if bosses:
        non_boss_s = sum(feat[fn] * weights[i] for i, fn in enumerate(FEATURE_NAMES) if fn != "boss_ttk")
        non_boss_s = max(4.0, non_boss_s)
        boss_exp_s = sum(b["expert_s"] for b in bosses)
        boss_ft_s = sum(b["first_s"] for b in bosses)
        base_exp_s = non_boss_s + boss_exp_s
        base_ft_s = non_boss_s * m + boss_ft_s
    else:
        base_exp_s = predict_expert_s(feat, weights, reg)
        base_ft_s = base_exp_s * m
        boss_exp_s = 0.0
        boss_ft_s = 0.0

    acts = extract_room_overworld_activities(reg, is_overworld_zone, pack_quests_for_room)
    return {
        "base_exp_s": base_exp_s,
        "base_first_s": base_ft_s,
        "boss_exp_s": boss_exp_s,
        "boss_first_s": boss_ft_s,
        "bosses": bosses,
        "activities": acts,
        "total_exp_s": base_exp_s + acts["activity_exp_s"],
        "total_first_s": base_ft_s + acts["activity_first_s"],
    }


def compute_fit_stats(actuals: List[float], preds: List[float]) -> Dict[str, float]:
    n = len(actuals)
    if n == 0:
        return {"n": 0, "mae_s": 0.0, "rmse_s": 0.0, "mape_pct": 0.0, "r2": 0.0, "actual_sum_s": 0.0, "pred_sum_s": 0.0}
    abs_err = [abs(p - a) for a, p in zip(actuals, preds)]
    sq_err = [(p - a) ** 2 for a, p in zip(actuals, preds)]
    pct_err = [abs(p - a) / max(1.0, a) * 100.0 for a, p in zip(actuals, preds)]
    mean_a = sum(actuals) / n
    ss_tot = sum((a - mean_a) ** 2 for a in actuals)
    ss_res = sum(sq_err)
    r2 = 1.0 - (ss_res / ss_tot) if ss_tot > 1e-6 else 0.0
    return {
        "n": n,
        "mae_s": round(sum(abs_err) / n, 2),
        "rmse_s": round(math.sqrt(sum(sq_err) / n), 2),
        "mape_pct": round(sum(pct_err) / n, 1),
        "r2": round(r2, 3),
        "actual_sum_s": round(sum(actuals), 1),
        "pred_sum_s": round(sum(preds), 1),
        "sum_error_pct": round((sum(preds) - sum(actuals)) / max(1.0, sum(actuals)) * 100.0, 1),
    }


def load_bible_targets(mults: Dict[str, float]) -> Dict[int, Dict[str, Any]]:
    """Parse docs/fullgame/epic/bibles/island<N>_graph.json into per-island and per-dungeon targets."""
    bibles_dir = REPO_ROOT / "docs" / "fullgame" / "epic" / "bibles"
    out: Dict[int, Dict[str, Any]] = {}
    if not bibles_dir.is_dir():
        return out
    for gp in sorted(bibles_dir.glob("island*_graph.json")):
        m_isl = re.search(r"island(\d+)_graph\.json$", gp.name)
        if not m_isl:
            continue
        isl_id = int(m_isl.group(1))
        try:
            data = json.loads(gp.read_text(encoding="utf-8"))
        except Exception:
            continue
        dungeons: Dict[str, Dict[str, Any]] = {}
        region_to_dun: Dict[str, str] = {}
        region_critical: Dict[str, bool] = {}
        tot_exp_s = 0.0
        tot_first_s = 0.0
        crit_exp_s = 0.0
        crit_first_s = 0.0
        regs = data.get("regions") or []
        for r in regs:
            if not isinstance(r, dict):
                continue
            rid = str(r.get("id", ""))
            dn = str(r.get("dungeon", "overworld")).strip().lower() or "overworld"
            rk = str(r.get("kind", "default")).strip().lower()
            exp_s = float(r.get("expert_s", 0.0) or 0.0)
            fm = float(mults.get(rk, mults.get("default", 2.7)))
            first_s = exp_s * fm
            is_crit = bool(r.get("critical", True))
            if rid:
                region_to_dun[rid] = dn
                region_critical[rid] = is_crit
            d = dungeons.setdefault(dn, {
                "dungeon": dn, "target_rooms": 0, "region_ids": [],
                "target_exp_s": 0.0, "target_first_s": 0.0,
                "crit_exp_s": 0.0, "crit_first_s": 0.0,
            })
            d["target_rooms"] += 1
            if rid:
                d["region_ids"].append(rid)
            d["target_exp_s"] += exp_s
            d["target_first_s"] += first_s
            tot_exp_s += exp_s
            tot_first_s += first_s
            if is_crit:
                d["crit_exp_s"] += exp_s
                d["crit_first_s"] += first_s
                crit_exp_s += exp_s
                crit_first_s += first_s
        out[isl_id] = {
            "island": isl_id,
            "name": str(data.get("name", f"ISLAND {isl_id}")),
            "target_rooms": len(regs),
            "target_exp_min": round(tot_exp_s / 60.0, 1),
            "target_first_min": round(tot_first_s / 60.0, 1),
            "crit_exp_min": round(crit_exp_s / 60.0, 1),
            "crit_first_min": round(crit_first_s / 60.0, 1),
            "opt_exp_min": round((tot_exp_s - crit_exp_s) / 60.0, 1),
            "opt_first_min": round((tot_first_s - crit_first_s) / 60.0, 1),
            "dungeons": dungeons,
            "region_to_dun": region_to_dun,
            "region_critical": region_critical,
        }
    return out


def _map_region_to_bible_dungeon(row: Dict[str, Any], b_isl: Optional[Dict[str, Any]]) -> str:
    if b_isl and row["region"] in b_isl["region_to_dun"]:
        return b_isl["region_to_dun"][row["region"]]
    dn = str(row["dungeon"]).lower()
    if dn in ("(overworld)", "overworld", ""):
        return "overworld"
    aliases = {
        "oak": "hollow_oak", "kiln": "great_kiln", "sanctum": "bell_sanctum",
        "toll": "great_toll", "mirror_spire": "spire",
    }
    dn = aliases.get(dn, dn)
    if b_isl and dn in b_isl["dungeons"]:
        return dn
    if b_isl:
        for bdn in b_isl["dungeons"].keys():
            if row["region"].startswith(bdn + "_") or dn.endswith("_" + bdn):
                return bdn
    return dn


def _is_region_critical(isl_id: int, reg_id: str, bibles: Dict[int, Dict[str, Any]]) -> bool:
    if isl_id == 0:
        return False
    b_isl = bibles.get(isl_id)
    if b_isl and reg_id in b_isl["region_critical"]:
        return bool(b_isl["region_critical"][reg_id])
    if reg_id.startswith(("cave_", "trial_", "superboss_", "sb_", "vault_", "dream_")) or reg_id == "ow_boathouse":
        return False
    return True


def build_bible_comparison(room_rows: List[Dict[str, Any]], bibles: Dict[int, Dict[str, Any]]) -> Dict[str, Any]:
    rows_by_isl_dun: Dict[Tuple[int, str], List[Dict[str, Any]]] = defaultdict(list)
    hub_rows: List[Dict[str, Any]] = []
    for r in room_rows:
        isl = int(r["island"])
        if isl <= 0:
            hub_rows.append(r)
            continue
        bdn = _map_region_to_bible_dungeon(r, bibles.get(isl))
        rows_by_isl_dun[(isl, bdn)].append(r)

    dun_comp: List[Dict[str, Any]] = []
    isl_comp: List[Dict[str, Any]] = []
    tot_built_rms = 0
    tot_target_rms = 0
    tot_mod_exp = 0.0
    tot_mod_first = 0.0
    tot_crit_exp = 0.0
    tot_crit_first = 0.0
    tot_opt_exp = 0.0
    tot_opt_first = 0.0
    tot_tgt_exp = 0.0
    tot_tgt_first = 0.0
    tot_tgt_crit_exp = 0.0
    tot_tgt_crit_first = 0.0

    for isl in sorted(bibles.keys()):
        bi = bibles[isl]
        i_built = 0
        i_mod_exp_s = 0.0
        i_mod_first_s = 0.0
        i_crit_exp_s = 0.0
        i_crit_first_s = 0.0
        i_opt_exp_s = 0.0
        i_opt_first_s = 0.0
        duns_done = 0
        duns_total = len(bi["dungeons"])
        seen_duns: Set[str] = set()
        for dn, bd in sorted(bi["dungeons"].items()):
            seen_duns.add(dn)
            matched = rows_by_isl_dun.get((isl, dn), [])
            b_cnt = len(matched)
            m_exp_s = sum(float(x["expert_s"]) for x in matched)
            m_first_s = sum(float(x["first_s"]) for x in matched)
            c_exp_s = sum(float(x["crit_exp_s"]) for x in matched)
            c_first_s = sum(float(x["crit_first_s"]) for x in matched)
            o_exp_s = sum(float(x["opt_exp_s"]) for x in matched)
            o_first_s = sum(float(x["opt_first_s"]) for x in matched)
            t_exp_m = round(bd["target_exp_s"] / 60.0, 1)
            t_first_m = round(bd["target_first_s"] / 60.0, 1)
            m_exp_m = round(m_exp_s / 60.0, 1)
            m_first_m = round(m_first_s / 60.0, 1)
            pct = round(m_exp_s / max(1.0, bd["target_exp_s"]) * 100.0, 1)
            t_rms = int(bd["target_rooms"])
            status = "DONE" if b_cnt >= t_rms and pct >= 80.0 else ("PARTIAL" if b_cnt > 0 else "UNBUILT")
            if b_cnt >= t_rms:
                duns_done += 1
            dun_comp.append({
                "island": isl, "dungeon": dn,
                "built_rooms": b_cnt, "target_rooms": t_rms,
                "model_exp_min": m_exp_m, "target_exp_min": t_exp_m,
                "delta_exp_min": round(m_exp_m - t_exp_m, 1),
                "model_first_min": m_first_m, "target_first_min": t_first_m,
                "crit_exp_min": round(c_exp_s / 60.0, 1),
                "opt_exp_min": round(o_exp_s / 60.0, 1),
                "pct_of_target": pct, "status": status,
            })
            i_built += b_cnt
            i_mod_exp_s += m_exp_s
            i_mod_first_s += m_first_s
            i_crit_exp_s += c_exp_s
            i_crit_first_s += c_first_s
            i_opt_exp_s += o_exp_s
            i_opt_first_s += o_first_s
        for (k_isl, k_dn), matched in sorted(rows_by_isl_dun.items()):
            if k_isl == isl and k_dn not in seen_duns:
                m_exp_s = sum(float(x["expert_s"]) for x in matched)
                m_first_s = sum(float(x["first_s"]) for x in matched)
                c_exp_s = sum(float(x["crit_exp_s"]) for x in matched)
                c_first_s = sum(float(x["crit_first_s"]) for x in matched)
                o_exp_s = sum(float(x["opt_exp_s"]) for x in matched)
                o_first_s = sum(float(x["opt_first_s"]) for x in matched)
                i_built += len(matched)
                i_mod_exp_s += m_exp_s
                i_mod_first_s += m_first_s
                i_crit_exp_s += c_exp_s
                i_crit_first_s += c_first_s
                i_opt_exp_s += o_exp_s
                i_opt_first_s += o_first_s
                dun_comp.append({
                    "island": isl, "dungeon": k_dn,
                    "built_rooms": len(matched), "target_rooms": 0,
                    "model_exp_min": round(m_exp_s / 60.0, 1), "target_exp_min": 0.0,
                    "delta_exp_min": round(m_exp_s / 60.0, 1),
                    "model_first_min": round(m_first_s / 60.0, 1), "target_first_min": 0.0,
                    "crit_exp_min": round(c_exp_s / 60.0, 1),
                    "opt_exp_min": round(o_exp_s / 60.0, 1),
                    "pct_of_target": 100.0, "status": "EXTRA",
                })
        i_mod_exp_m = round(i_mod_exp_s / 60.0, 1)
        i_mod_first_m = round(i_mod_first_s / 60.0, 1)
        i_crit_exp_m = round(i_crit_exp_s / 60.0, 1)
        i_crit_first_m = round(i_crit_first_s / 60.0, 1)
        i_opt_exp_m = round(i_opt_exp_s / 60.0, 1)
        i_opt_first_m = round(i_opt_first_s / 60.0, 1)
        isl_comp.append({
            "island": isl, "name": bi["name"],
            "built_rooms": i_built, "target_rooms": bi["target_rooms"],
            "dungeons_done": duns_done, "dungeons_total": duns_total,
            "model_exp_min": i_mod_exp_m, "target_exp_min": bi["target_exp_min"],
            "model_first_min": i_mod_first_m, "target_first_min": bi["target_first_min"],
            "crit_exp_min": i_crit_exp_m, "crit_first_min": i_crit_first_m,
            "opt_exp_min": i_opt_exp_m, "opt_first_min": i_opt_first_m,
            "target_crit_exp_min": bi["crit_exp_min"], "target_crit_first_min": bi["crit_first_min"],
            "pct_of_target": round(i_mod_exp_m / max(0.1, bi["target_exp_min"]) * 100.0, 1),
        })
        tot_built_rms += i_built
        tot_target_rms += bi["target_rooms"]
        tot_mod_exp += i_mod_exp_s / 60.0
        tot_mod_first += i_mod_first_s / 60.0
        tot_crit_exp += i_crit_exp_s / 60.0
        tot_crit_first += i_crit_first_s / 60.0
        tot_opt_exp += i_opt_exp_s / 60.0
        tot_opt_first += i_opt_first_s / 60.0
        tot_tgt_exp += bi["target_exp_min"]
        tot_tgt_first += bi["target_first_min"]
        tot_tgt_crit_exp += bi["crit_exp_min"]
        tot_tgt_crit_first += bi["crit_first_min"]

    hub_exp_m = round(sum(float(r["expert_s"]) for r in hub_rows) / 60.0, 1)
    hub_first_m = round(sum(float(r["first_s"]) for r in hub_rows) / 60.0, 1)

    return {
        "totals": {
            "built_rooms": tot_built_rms, "target_rooms": tot_target_rms,
            "rooms_pct": round(tot_built_rms / max(1, tot_target_rms) * 100.0, 1),
            "model_exp_min": round(tot_mod_exp, 1), "target_exp_min": round(tot_tgt_exp, 1),
            "model_first_min": round(tot_mod_first, 1), "target_first_min": round(tot_tgt_first, 1),
            "crit_exp_min": round(tot_crit_exp, 1), "crit_first_min": round(tot_crit_first, 1),
            "opt_exp_min": round(tot_opt_exp, 1), "opt_first_min": round(tot_opt_first, 1),
            "target_crit_exp_min": round(tot_tgt_crit_exp, 1), "target_crit_first_min": round(tot_tgt_crit_first, 1),
            "hub_rooms": len(hub_rows), "hub_exp_min": hub_exp_m, "hub_first_min": hub_first_m,
            "pct_of_target": round(tot_mod_exp / max(0.1, tot_tgt_exp) * 100.0, 1),
        },
        "islands": isl_comp,
        "dungeons": dun_comp,
    }


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Luxel Epic calibrated playtime model (stdlib only)")
    ap.add_argument("--island", type=int, action="append", default=[], help="Filter by island ID(s)")
    ap.add_argument("--dungeon", type=str, action="append", default=[], help="Filter by dungeon ID(s)")
    ap.add_argument("--by", choices=["room", "dungeon", "island", "game", "all"], default="all", help="Table granularity")
    ap.add_argument("--fixtures", type=str, default="", help="Optional fixture overlay dir")
    ap.add_argument("--fit-report", action="store_true", help="Print detailed calibration residuals")
    ap.add_argument("--bibles", action="store_true", help="Compare modelled minutes vs each island bible target per dungeon")
    ap.add_argument("--summary", action="store_true", help="Print a one-screen executive summary for the lead")
    ap.add_argument("--json", type=str, default="", help="Write JSON output to path (or '-' for stdout)")
    args = ap.parse_args(argv)

    cal = json.loads(CALIBRATION_PATH.read_text(encoding="utf-8"))
    mults: Dict[str, float] = dict(R1_MULTIPLIERS)
    mults.update(cal.get("r1_first_time_multipliers", {}))
    zt: Dict[str, float] = cal.get("zone_times_s", {})
    partial_rooms = set(cal.get("totals", {}).get("partial_rooms", []))
    outlier_rooms = set(cal.get("totals", {}).get("outlier_rooms", []))

    catalog = rl.load_engine_catalog()
    enemy_stats = load_enemy_stats()
    boss_ttks = load_boss_check_ttks()
    pack_quests = load_pack_quests()
    bibles_all = load_bible_targets(mults)
    all_regions = {
        k: r for k, r in rl.discover_all_regions(Path(args.fixtures) if args.fixtures else None).items()
        if not (r["id"].startswith("_") or bool(r.get("json", {}).get("debug_only", False)))
    }

    # 1. Extract baseline 1.0 features & fit NNLS weights on Marwan's 42 rooms (unchanged!)
    feats_by_key: Dict[str, Dict[str, float]] = {k: extract_features(r, enemy_stats) for k, r in all_regions.items()}
    fit_X: List[List[float]] = []
    fit_y: List[float] = []
    for k, sec in sorted(zt.items()):
        if k in partial_rooms or k in outlier_rooms or k not in feats_by_key:
            continue
        fit_X.append([feats_by_key[k][fn] for fn in FEATURE_NAMES])
        fit_y.append(float(sec))

    weights = fit_weights_nnls(fit_X, fit_y, ridge=3.5)

    eval_clean_a, eval_clean_p = [], []
    eval_comp_a, eval_comp_p = [], []
    eval_all_a, eval_all_p = [], []
    residuals: List[Dict[str, Any]] = []
    for k, actual in sorted(zt.items()):
        if k not in all_regions:
            continue
        pred = predict_expert_s(feats_by_key[k], weights, all_regions[k])
        eval_all_a.append(actual)
        eval_all_p.append(pred)
        if k not in partial_rooms:
            eval_comp_a.append(actual)
            eval_comp_p.append(pred)
            if k not in outlier_rooms:
                eval_clean_a.append(actual)
                eval_clean_p.append(pred)
        residuals.append({
            "room": k,
            "actual_s": round(actual, 2),
            "pred_s": round(pred, 2),
            "err_s": round(pred - actual, 2),
            "tag": "partial" if k in partial_rooms else ("outlier_9deaths" if k in outlier_rooms else "complete"),
        })

    fit_clean = compute_fit_stats(eval_clean_a, eval_clean_p)
    fit_complete = compute_fit_stats(eval_comp_a, eval_comp_p)
    fit_all = compute_fit_stats(eval_all_a, eval_all_p)

    # 2. Predict Epic playtime across all selected regions
    want_isls = set(args.island)
    want_duns = {d.lower() for d in args.dungeon}
    room_rows: List[Dict[str, Any]] = []
    tot_activities = {"quests": 0, "trials": 0, "moths": 0, "minigames": 0}
    boss_counts = {"mini": 0, "boss": 0, "superboss": 0, "measured": 0, "spec": 0}

    for k in sorted(all_regions.keys()):
        r = all_regions[k]
        did = rl.infer_dungeon_id(r, catalog)
        if want_isls and r["island_id"] not in want_isls:
            continue
        if want_duns and did.lower() not in want_duns:
            continue
        rkind = infer_room_kind(r, enemy_stats, boss_ttks)
        is_ow_zone = (not r["is_dungeon"]) or (did in ("", "(overworld)", "overworld"))
        host_quests = pack_quests.get(r["island_id"], []) if r["id"] == "overworld" else None
        ep = predict_epic_room(r, feats_by_key[k], weights, rkind, mults, boss_ttks, is_ow_zone, host_quests)

        is_crit = _is_region_critical(r["island_id"], r["id"], bibles_all)
        acts = ep["activities"]
        for ak in tot_activities:
            tot_activities[ak] += int(acts[ak])
        for b in ep["bosses"]:
            boss_counts[b["tier"]] += 1
            if str(b["source"]).startswith("report:"):
                boss_counts["measured"] += 1
            else:
                boss_counts["spec"] += 1

        if is_crit:
            crit_exp_s = ep["base_exp_s"]
            crit_first_s = ep["base_first_s"]
            opt_exp_s = acts["activity_exp_s"]
            opt_first_s = acts["activity_first_s"]
        else:
            crit_exp_s = 0.0
            crit_first_s = 0.0
            opt_exp_s = ep["total_exp_s"]
            opt_first_s = ep["total_first_s"]

        exp_s = ep["total_exp_s"]
        first_s = ep["total_first_s"]
        eff_m = round(first_s / max(1.0, exp_s), 2)
        room_rows.append({
            "key": k,
            "island": r["island_id"],
            "region": r["id"],
            "dungeon": did or "(overworld)",
            "kind": rkind,
            "critical": is_crit,
            "expert_s": round(exp_s, 1),
            "mult": eff_m,
            "first_s": round(first_s, 1),
            "crit_exp_s": round(crit_exp_s, 1),
            "crit_first_s": round(crit_first_s, 1),
            "opt_exp_s": round(opt_exp_s, 1),
            "opt_first_s": round(opt_first_s, 1),
            "boss_exp_s": round(ep["boss_exp_s"], 1),
            "boss_first_s": round(ep["boss_first_s"], 1),
            "activities": {ak: acts[ak] for ak in ("quests", "trials", "moths", "minigames")},
            "measured_s": round(zt[k], 1) if k in zt else None,
        })

    # 3. Aggregate dungeon, island, game tables
    by_dungeon: Dict[Tuple[int, str], Dict[str, Any]] = {}
    by_island: Dict[int, Dict[str, Any]] = {}
    for row in room_rows:
        dk = (row["island"], row["dungeon"])
        d_agg = by_dungeon.setdefault(dk, {
            "island": row["island"], "dungeon": row["dungeon"], "rooms": 0,
            "expert_s": 0.0, "first_s": 0.0, "crit_exp_s": 0.0, "crit_first_s": 0.0,
            "opt_exp_s": 0.0, "opt_first_s": 0.0, "measured_s": 0.0, "measured_n": 0,
        })
        d_agg["rooms"] += 1
        d_agg["expert_s"] += row["expert_s"]
        d_agg["first_s"] += row["first_s"]
        d_agg["crit_exp_s"] += row["crit_exp_s"]
        d_agg["crit_first_s"] += row["crit_first_s"]
        d_agg["opt_exp_s"] += row["opt_exp_s"]
        d_agg["opt_first_s"] += row["opt_first_s"]
        if row["measured_s"] is not None and row["key"] not in partial_rooms:
            d_agg["measured_s"] += row["measured_s"]
            d_agg["measured_n"] += 1

        i_agg = by_island.setdefault(row["island"], {
            "island": row["island"], "rooms": 0,
            "expert_s": 0.0, "first_s": 0.0, "crit_exp_s": 0.0, "crit_first_s": 0.0,
            "opt_exp_s": 0.0, "opt_first_s": 0.0, "measured_s": 0.0, "measured_n": 0,
        })
        i_agg["rooms"] += 1
        i_agg["expert_s"] += row["expert_s"]
        i_agg["first_s"] += row["first_s"]
        i_agg["crit_exp_s"] += row["crit_exp_s"]
        i_agg["crit_first_s"] += row["crit_first_s"]
        i_agg["opt_exp_s"] += row["opt_exp_s"]
        i_agg["opt_first_s"] += row["opt_first_s"]
        if row["measured_s"] is not None and row["key"] not in partial_rooms:
            i_agg["measured_s"] += row["measured_s"]
            i_agg["measured_n"] += 1

    total_exp_s = sum(r["expert_s"] for r in room_rows)
    total_first_s = sum(r["first_s"] for r in room_rows)
    total_crit_exp_s = sum(r["crit_exp_s"] for r in room_rows)
    total_crit_first_s = sum(r["crit_first_s"] for r in room_rows)
    total_opt_exp_s = sum(r["opt_exp_s"] for r in room_rows)
    total_opt_first_s = sum(r["opt_first_s"] for r in room_rows)

    payload: Dict[str, Any] = {
        "note": "Modelled minutes: non-boss base calibrated on Marwan's 42 rooms (fit unchanged); bosses from boss_check TTKs + retry curves; overworld quests/trials/moths/minigames from design blocks & packs.",
        "weights": {fn: round(weights[i], 3) for i, fn in enumerate(FEATURE_NAMES)},
        "multipliers": mults,
        "boss_retry_params": BOSS_RETRY_PARAMS,
        "boss_ttk_coverage": boss_counts,
        "overworld_activities": tot_activities,
        "calibration_fit": {
            "complete_40_no_outlier": fit_clean,
            "complete_41_all": fit_complete,
            "all_42_with_partial_isl5": fit_all,
        },
        "residuals": residuals,
        "game": {
            "rooms": len(room_rows),
            "modelled_expert_min": round(total_exp_s / 60.0, 1),
            "modelled_first_time_min": round(total_first_s / 60.0, 1),
            "critical_expert_min": round(total_crit_exp_s / 60.0, 1),
            "critical_first_time_min": round(total_crit_first_s / 60.0, 1),
            "optional_expert_min": round(total_opt_exp_s / 60.0, 1),
            "optional_first_time_min": round(total_opt_first_s / 60.0, 1),
            "effective_multiplier": round(total_first_s / max(1.0, total_exp_s), 2),
        },
        "islands": [
            {
                "island": v["island"],
                "rooms": v["rooms"],
                "expert_min": round(v["expert_s"] / 60.0, 1),
                "first_min": round(v["first_s"] / 60.0, 1),
                "crit_exp_min": round(v["crit_exp_s"] / 60.0, 1),
                "crit_first_min": round(v["crit_first_s"] / 60.0, 1),
                "opt_exp_min": round(v["opt_exp_s"] / 60.0, 1),
                "opt_first_min": round(v["opt_first_s"] / 60.0, 1),
                "measured_min": round(v["measured_s"] / 60.0, 1) if v["measured_n"] == v["rooms"] else None,
            }
            for _, v in sorted(by_island.items())
        ],
        "dungeons": [
            {
                "island": v["island"],
                "dungeon": v["dungeon"],
                "rooms": v["rooms"],
                "expert_min": round(v["expert_s"] / 60.0, 1),
                "first_min": round(v["first_s"] / 60.0, 1),
                "crit_exp_min": round(v["crit_exp_s"] / 60.0, 1),
                "opt_exp_min": round(v["opt_exp_s"] / 60.0, 1),
                "measured_min": round(v["measured_s"] / 60.0, 1) if v["measured_n"] == v["rooms"] else None,
            }
            for _, v in sorted(by_dungeon.items())
        ],
        "rooms": room_rows,
    }

    bibles_comp: Optional[Dict[str, Any]] = None
    if args.bibles or args.summary:
        bibles = {k: v for k, v in bibles_all.items() if (not want_isls or k in want_isls)}
        bibles_comp = build_bible_comparison(room_rows, bibles)
        if want_duns:
            bibles_comp["dungeons"] = [d for d in bibles_comp["dungeons"] if d["dungeon"].lower() in want_duns]
        payload["bibles"] = bibles_comp

    if args.json == "-":
        print(json.dumps(payload, indent=2))
        return 0
    if args.json:
        out_p = Path(args.json)
        out_p.parent.mkdir(parents=True, exist_ok=True)
        out_p.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    if args.summary and bibles_comp is not None:
        bt = bibles_comp["totals"]
        g = payload["game"]
        bc = boss_counts
        ac = tot_activities
        print(
            f"LUXEL EPIC PLAYTIME SUMMARY (modelled, R2={fit_clean['r2']} MAE={fit_clean['mae_s']}s | "
            f"eff mult {g['effective_multiplier']:.2f}x | bosses={bc['mini']}m/{bc['boss']}b/{bc['superboss']}sb "
            f"[{bc['measured']} measured, {bc['spec']} spec] | OW: {ac['quests']}q/{ac['trials']}tr/{ac['moths']}m/{ac['minigames']}mg)"
        )
        print(
            f"  Critical Path: Exp {g['critical_expert_min']:.1f}m ({g['critical_expert_min']/60:.2f}h) / bible {bt['target_crit_exp_min']:.1f}m "
            f"| 1st {g['critical_first_time_min']:.1f}m ({g['critical_first_time_min']/60:.2f}h) / bible {bt['target_crit_first_min']:.1f}m"
        )
        print(
            f"  Optional:      Exp {g['optional_expert_min']:.1f}m ({g['optional_expert_min']/60:.2f}h) "
            f"| 1st {g['optional_first_time_min']:.1f}m ({g['optional_first_time_min']/60:.2f}h) "
            f"[caves/trials/superbosses/quests/moths/minigames + hub {bt['hub_exp_min']:.1f}m/{bt['hub_first_min']:.1f}m]"
        )
        print(
            f"  Total (100%):  {bt['built_rooms']}/{bt['target_rooms']} isl rooms ({bt['rooms_pct']:.1f}%) + {bt['hub_rooms']} hub | "
            f"Exp {g['modelled_expert_min']:.1f}m ({g['modelled_expert_min']/60:.2f}h) vs {bt['target_exp_min']:.1f}m | "
            f"1st {g['modelled_first_time_min']:.1f}m ({g['modelled_first_time_min']/60:.2f}h) vs {bt['target_first_min']:.1f}m"
        )
        print(f"  {'Isl':>3s} {'Name':18s} {'Rooms':>7s} {'CritExp':>8s} {'OptExp':>7s} {'TotExp':>7s} {'Crit1st':>8s} {'Opt1st':>7s} {'Tot1st':>7s} {'Tgt1st':>7s} {'%Tgt':>6s}")
        for ic in bibles_comp["islands"]:
            print(
                f"  {ic['island']:3d} {ic['name'][:18]:18s} {ic['built_rooms']:3d}/{ic['target_rooms']:<3d} "
                f"{ic['crit_exp_min']:7.1f}m {ic['opt_exp_min']:6.1f}m {ic['model_exp_min']:6.1f}m "
                f"{ic['crit_first_min']:7.1f}m {ic['opt_first_min']:6.1f}m {ic['model_first_min']:6.1f}m "
                f"{ic['target_first_min']:6.1f}m {ic['pct_of_target']:5.1f}%"
            )
        print(
            f"  {'ISL':>3s} {'ALL 8 ISLANDS':18s} {bt['built_rooms']:3d}/{bt['target_rooms']:<3d} "
            f"{bt['crit_exp_min']:7.1f}m {bt['opt_exp_min']:6.1f}m {bt['model_exp_min']:6.1f}m "
            f"{bt['crit_first_min']:7.1f}m {bt['opt_first_min']:6.1f}m {bt['model_first_min']:6.1f}m "
            f"{bt['target_first_min']:6.1f}m {bt['pct_of_target']:5.1f}%"
        )
        if bt["hub_rooms"] > 0:
            print(
                f"  {'HUB':>3s} {'Wick House Hub':18s} {bt['hub_rooms']:3d}/-   "
                f"{0.0:7.1f}m {bt['hub_exp_min']:6.1f}m {bt['hub_exp_min']:6.1f}m "
                f"{0.0:7.1f}m {bt['hub_first_min']:6.1f}m {bt['hub_first_min']:6.1f}m {'-':>7s} {'-':>6s}"
            )
            print(
                f"  {'TOT':>3s} {'ALL 8 ISL + HUB':18s} {g['rooms']:3d}/-   "
                f"{g['critical_expert_min']:7.1f}m {g['optional_expert_min']:6.1f}m {g['modelled_expert_min']:6.1f}m "
                f"{g['critical_first_time_min']:7.1f}m {g['optional_first_time_min']:6.1f}m {g['modelled_first_time_min']:6.1f}m {'-':>7s} {'-':>6s}"
            )
        if not args.bibles:
            return 0

    if args.bibles and bibles_comp is not None:
        bt = bibles_comp["totals"]
        print("\nLUXEL PLAYTIME vs BIBLE TARGETS (per dungeon, modelled vs bible expert/1st-time)")
        print(f"{'Isl':>3s} {'Dungeon':16s} {'Rooms':>8s} {'ModExp':>7s} {'TgtExp':>7s} {'Delta':>7s} {'Mod1st':>7s} {'Tgt1st':>7s} {'%':>6s} {'Status':8s}")
        for d in bibles_comp["dungeons"]:
            print(f"{d['island']:3d} {d['dungeon'][:16]:16s} {d['built_rooms']:3d}/{d['target_rooms']:<4d} {d['model_exp_min']:6.1f}m {d['target_exp_min']:6.1f}m {d['delta_exp_min']:+6.1f}m {d['model_first_min']:6.1f}m {d['target_first_min']:6.1f}m {d['pct_of_target']:5.1f}% {d['status']:8s}")
        print(f"TOTAL (Islands 1-8): {bt['built_rooms']}/{bt['target_rooms']} rooms ({bt['rooms_pct']:.1f}%) | modelled exp {bt['model_exp_min']:.1f}m vs bible {bt['target_exp_min']:.1f}m ({bt['pct_of_target']:.1f}%) | 1st-time {bt['model_first_min']:.1f}m ({bt['model_first_min']/60:.2f}h) vs {bt['target_first_min']:.1f}m ({bt['target_first_min']/60:.2f}h)")
        return 0

    print("LUXEL PLAYTIME MODEL (modelled, calibrated on Marwan's 41 complete rooms; 5:overworld partial)")
    print("Weights: " + ", ".join(f"{k}={v}" for k, v in payload["weights"].items()))
    print(f"Fit (40 complete rooms, excl 9-death r5): MAE={fit_clean['mae_s']}s  RMSE={fit_clean['rmse_s']}s  MAPE={fit_clean['mape_pct']}%  R2={fit_clean['r2']}  sum={fit_clean['pred_sum_s']}s vs {fit_clean['actual_sum_s']}s ({fit_clean['sum_error_pct']:+.1f}%)")
    print(f"Fit (41 all complete rooms):              MAE={fit_complete['mae_s']}s  RMSE={fit_complete['rmse_s']}s  MAPE={fit_complete['mape_pct']}%  R2={fit_complete['r2']}  sum={fit_complete['pred_sum_s']}s vs {fit_complete['actual_sum_s']}s ({fit_complete['sum_error_pct']:+.1f}%)")
    if args.fit_report:
        print("\n--- Largest Calibration Residuals ---")
        for res in sorted(residuals, key=lambda x: abs(x["err_s"]), reverse=True)[:10]:
            print(f"  {res['room']:22s} actual={res['actual_s']:6.1f}s  pred={res['pred_s']:6.1f}s  err={res['err_s']:+6.1f}s  [{res['tag']}]")

    if args.by in ("room", "all") and (args.by == "room" or len(room_rows) <= 25):
        print("\n--- Per Room (modelled) ---")
        print(f"{'Room':22s} {'Kind':10s} {'Crit':>4s} {'Exp(s)':>7s} {'Mult':>5s} {'1st(s)':>7s} {'Meas(s)':>8s}")
        for r in room_rows:
            ms = f"{r['measured_s']:7.1f}" if r["measured_s"] is not None else "      -"
            print(f"{r['key']:22s} {r['kind']:10s} {'Y' if r['critical'] else 'N':>4s} {r['expert_s']:7.1f} {r['mult']:5.2f} {r['first_s']:7.1f} {ms}")

    if args.by in ("dungeon", "all"):
        print("\n--- Per Dungeon / Block (modelled minutes) ---")
        print(f"{'Isl':>3s} {'Block':18s} {'Rms':>4s} {'Expert':>8s} {'First':>8s} {'Measured':>9s}")
        for d in payload["dungeons"]:
            ms = f"{d['measured_min']:8.1f}m" if d["measured_min"] is not None else "        -"
            print(f"{d['island']:3d} {d['dungeon']:18s} {d['rooms']:4d} {d['expert_min']:7.1f}m {d['first_min']:7.1f}m {ms}")

    if args.by in ("island", "all"):
        print("\n--- Per Island (modelled minutes) ---")
        print(f"{'Island':>6s} {'Rms':>4s} {'CritExp':>8s} {'OptExp':>8s} {'TotExp':>8s} {'Tot1st':>8s}")
        for isl in payload["islands"]:
            print(f"{isl['island']:6d} {isl['rooms']:4d} {isl['crit_exp_min']:7.1f}m {isl['opt_exp_min']:7.1f}m {isl['expert_min']:7.1f}m {isl['first_min']:7.1f}m")

    g = payload["game"]
    print(
        f"\nGAME TOTAL ({g['rooms']} rooms): Critical = {g['critical_expert_min']:.1f}m exp / {g['critical_first_time_min']:.1f}m 1st "
        f"({g['critical_first_time_min']/60:.2f}h) | Optional = {g['optional_expert_min']:.1f}m exp / {g['optional_first_time_min']:.1f}m 1st "
        f"({g['optional_first_time_min']/60:.2f}h) | Total = {g['modelled_expert_min']:.1f}m ({g['modelled_expert_min']/60:.2f}h) exp / "
        f"{g['modelled_first_time_min']:.1f}m ({g['modelled_first_time_min']/60:.2f}h) 1st | eff mult = {g['effective_multiplier']:.2f}x"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
