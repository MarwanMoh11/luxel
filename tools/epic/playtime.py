#!/usr/bin/env python3
"""Luxel Epic playtime model (Python 3 stdlib only), calibrated on Marwan's 42 rooms.

Usage:
  python3 tools/epic/playtime.py [--island N] [--dungeon ID] [--by room|dungeon|island|game|all]
  python3 tools/epic/playtime.py --fit-report [--json PATH] [--fixtures tests/luxel/fixtures]
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
import math
from pathlib import Path
import re
import sys
from typing import Any, Dict, List, Optional, Sequence, Tuple

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

# Fallback enemy stats (parsed dynamically from enemy_factory.gd + packs)
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
    # Merge pack enemy data if present
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


def enemy_ttk_weight(kind: str, stats: Dict[str, Dict[str, Any]]) -> Tuple[float, bool]:
    """Model expert time-to-kill seconds for one enemy/boss from HP, shield, tell/recover."""
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
        # Boss model: expert burst DPS ~1.85/s (throw+bolts+beam) + shield break + phases + retry overhead
        phases = int(st.get("phases", 2 if hp >= 12.0 else 1))
        retry_factor = 1.0 + (0.20 if hp >= 18.0 else 0.05)
        ttk = (2.0 + hp / 1.85 + sh * 0.65 + (phases - 1) * 1.8) * retry_factor
        return ttk, True
    # Regular enemy: approach/read (0.7s) + HP/DPS (1.85/s) + shield break (0.6s/pt)
    ttk = 0.7 + hp / 1.85 + sh * 0.6 + (0.45 if k in ("gloam", "phantom_owl", "ash_mole", "snatcher", "gull_thief") else 0.0)
    return ttk, False


def infer_room_kind(reg: Dict[str, Any], enemy_stats: Dict[str, Dict[str, Any]]) -> str:
    if reg.get("design") and reg["design"].get("kind"):
        return str(reg["design"]["kind"]).lower()
    if not reg["is_dungeon"] or reg["id"] == "overworld":
        return "overworld"
    has_boss = any(enemy_ttk_weight(str(e.get("kind", "")), enemy_stats)[1] for e in reg["enemies"])
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
    """Compute interpretable playtime feature vector for a region."""
    w, h = reg["width"], reg["height"]
    grid = reg["grid"]
    walk_tiles = sum(1 for y in range(h) for x in range(w) if grid[y][x] in rl.WALKABLE_BASE)
    hazard_tiles = sum(1 for y in range(h) for x in range(w) if grid[y][x] in rl.HAZARD_TILES)
    is_ow = 1.0 if (not reg["is_dungeon"] or reg["id"] == "overworld") else 0.0

    # Area walked proxy: sqrt(walk_tiles) * traversal factor (overworlds loop across multiple zones)
    area_walk = math.sqrt(max(1, walk_tiles)) * (1.0 + 0.25 * min(6, len(reg["zones"])) if is_ow else 0.65)
    # Hazard crossing overhead (pits/water/phantom/tide require dashes, wings, lens)
    hazard_frac = hazard_tiles / max(1, w * h)

    enemy_ttk = 0.0
    boss_ttk = 0.0
    for e in reg["enemies"]:
        ttk, is_b = enemy_ttk_weight(str(e.get("kind", "")), enemy_stats)
        if is_b:
            boss_ttk += ttk
        else:
            enemy_ttk += ttk
    # Include event wave enemies
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

    # Puzzle decisions: prefer authored design.decisions + solution ops; otherwise infer from interactables
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

    # Reading / ceremony / NPC / shrine / beacon / trigger interactions
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

    # Travel / hub revisiting (rooms with >= 3 exits are revisited as hubs)
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
    # Priors keep each physical feature meaningful even with 41 samples
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
    # Enforce sensible minimum physical floors on core combat/puzzle terms so Epic scaling stays truthful
    floors = [1.0, 0.25, 0.75, 0.75, 2.0, 0.6, 0.5]
    return [max(w[i], floors[i]) for i in range(p)]


def predict_expert_s(feat: Dict[str, float], weights: List[float], reg: Dict[str, Any]) -> float:
    model_s = sum(feat[name] * weights[i] for i, name in enumerate(FEATURE_NAMES))
    # If room has a verified/authored design.expert_s and solution, blend conservatively (don't let wild claims inflate)
    return max(4.0, model_s)


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
            "dungeons": dungeons,
            "region_to_dun": region_to_dun,
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
    # Prefix match against bible dungeon names
    if b_isl:
        for bdn in b_isl["dungeons"].keys():
            if row["region"].startswith(bdn + "_") or dn.endswith("_" + bdn):
                return bdn
    return dn


def build_bible_comparison(room_rows: List[Dict[str, Any]], bibles: Dict[int, Dict[str, Any]]) -> Dict[str, Any]:
    rows_by_isl_dun: Dict[Tuple[int, str], List[Dict[str, Any]]] = defaultdict(list)
    for r in room_rows:
        isl = int(r["island"])
        if isl <= 0:
            continue
        bdn = _map_region_to_bible_dungeon(r, bibles.get(isl))
        rows_by_isl_dun[(isl, bdn)].append(r)

    dun_comp: List[Dict[str, Any]] = []
    isl_comp: List[Dict[str, Any]] = []
    tot_built_rms = 0
    tot_target_rms = 0
    tot_mod_exp = 0.0
    tot_mod_first = 0.0
    tot_tgt_exp = 0.0
    tot_tgt_first = 0.0

    for isl in sorted(bibles.keys()):
        bi = bibles[isl]
        i_built = 0
        i_mod_exp_s = 0.0
        i_mod_first_s = 0.0
        duns_done = 0
        duns_total = len(bi["dungeons"])
        seen_duns = set()
        for dn, bd in sorted(bi["dungeons"].items()):
            seen_duns.add(dn)
            matched = rows_by_isl_dun.get((isl, dn), [])
            b_cnt = len(matched)
            m_exp_s = sum(float(x["expert_s"]) for x in matched)
            m_first_s = sum(float(x["first_s"]) for x in matched)
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
                "pct_of_target": pct, "status": status,
            })
            i_built += b_cnt
            i_mod_exp_s += m_exp_s
            i_mod_first_s += m_first_s
        # Include any extra on-disk dungeons not in bible
        for (k_isl, k_dn), matched in sorted(rows_by_isl_dun.items()):
            if k_isl == isl and k_dn not in seen_duns:
                m_exp_s = sum(float(x["expert_s"]) for x in matched)
                m_first_s = sum(float(x["first_s"]) for x in matched)
                i_built += len(matched)
                i_mod_exp_s += m_exp_s
                i_mod_first_s += m_first_s
                dun_comp.append({
                    "island": isl, "dungeon": k_dn,
                    "built_rooms": len(matched), "target_rooms": 0,
                    "model_exp_min": round(m_exp_s / 60.0, 1), "target_exp_min": 0.0,
                    "delta_exp_min": round(m_exp_s / 60.0, 1),
                    "model_first_min": round(m_first_s / 60.0, 1), "target_first_min": 0.0,
                    "pct_of_target": 100.0, "status": "EXTRA",
                })
        i_mod_exp_m = round(i_mod_exp_s / 60.0, 1)
        i_mod_first_m = round(i_mod_first_s / 60.0, 1)
        isl_comp.append({
            "island": isl, "name": bi["name"],
            "built_rooms": i_built, "target_rooms": bi["target_rooms"],
            "dungeons_done": duns_done, "dungeons_total": duns_total,
            "model_exp_min": i_mod_exp_m, "target_exp_min": bi["target_exp_min"],
            "model_first_min": i_mod_first_m, "target_first_min": bi["target_first_min"],
            "pct_of_target": round(i_mod_exp_m / max(0.1, bi["target_exp_min"]) * 100.0, 1),
        })
        tot_built_rms += i_built
        tot_target_rms += bi["target_rooms"]
        tot_mod_exp += i_mod_exp_s / 60.0
        tot_mod_first += i_mod_first_s / 60.0
        tot_tgt_exp += bi["target_exp_min"]
        tot_tgt_first += bi["target_first_min"]

    return {
        "totals": {
            "built_rooms": tot_built_rms, "target_rooms": tot_target_rms,
            "rooms_pct": round(tot_built_rms / max(1, tot_target_rms) * 100.0, 1),
            "model_exp_min": round(tot_mod_exp, 1), "target_exp_min": round(tot_tgt_exp, 1),
            "model_first_min": round(tot_mod_first, 1), "target_first_min": round(tot_tgt_first, 1),
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
    all_regions = {
        k: r for k, r in rl.discover_all_regions(Path(args.fixtures) if args.fixtures else None).items()
        if not (r["id"].startswith("_") or bool(r.get("json", {}).get("debug_only", False)))
    }

    # Extract features for all regions
    feats_by_key: Dict[str, Dict[str, float]] = {k: extract_features(r, enemy_stats) for k, r in all_regions.items()}

    # Calibrate on complete non-outlier rooms, then evaluate honestly on ALL sets
    fit_X: List[List[float]] = []
    fit_y: List[float] = []
    for k, sec in sorted(zt.items()):
        if k in partial_rooms or k in outlier_rooms or k not in feats_by_key:
            continue
        fit_X.append([feats_by_key[k][fn] for fn in FEATURE_NAMES])
        fit_y.append(float(sec))

    weights = fit_weights_nnls(fit_X, fit_y, ridge=3.5)

    # Evaluate honest fit errors across 3 cohorts: 40 clean complete rooms, 41 all complete rooms (incl. 9-death r5), 42 all rooms
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

    # Predict across all selected regions
    want_isls = set(args.island)
    want_duns = {d.lower() for d in args.dungeon}
    room_rows: List[Dict[str, Any]] = []
    for k in sorted(all_regions.keys()):
        r = all_regions[k]
        did = rl.infer_dungeon_id(r, catalog)
        if want_isls and r["island_id"] not in want_isls:
            continue
        if want_duns and did.lower() not in want_duns:
            continue
        rkind = infer_room_kind(r, enemy_stats)
        exp_s = predict_expert_s(feats_by_key[k], weights, r)
        m = float(mults.get(rkind, mults["default"]))
        first_s = exp_s * m
        room_rows.append({
            "key": k,
            "island": r["island_id"],
            "region": r["id"],
            "dungeon": did or "(overworld)",
            "kind": rkind,
            "expert_s": round(exp_s, 1),
            "mult": m,
            "first_s": round(first_s, 1),
            "measured_s": round(zt[k], 1) if k in zt else None,
        })

    # Aggregate dungeon, island, game tables
    by_dungeon: Dict[Tuple[int, str], Dict[str, Any]] = {}
    by_island: Dict[int, Dict[str, Any]] = {}
    for row in room_rows:
        dk = (row["island"], row["dungeon"])
        d_agg = by_dungeon.setdefault(dk, {"island": row["island"], "dungeon": row["dungeon"], "rooms": 0, "expert_s": 0.0, "first_s": 0.0, "measured_s": 0.0, "measured_n": 0})
        d_agg["rooms"] += 1
        d_agg["expert_s"] += row["expert_s"]
        d_agg["first_s"] += row["first_s"]
        if row["measured_s"] is not None and row["key"] not in partial_rooms:
            d_agg["measured_s"] += row["measured_s"]
            d_agg["measured_n"] += 1

        i_agg = by_island.setdefault(row["island"], {"island": row["island"], "rooms": 0, "expert_s": 0.0, "first_s": 0.0, "measured_s": 0.0, "measured_n": 0})
        i_agg["rooms"] += 1
        i_agg["expert_s"] += row["expert_s"]
        i_agg["first_s"] += row["first_s"]
        if row["measured_s"] is not None and row["key"] not in partial_rooms:
            i_agg["measured_s"] += row["measured_s"]
            i_agg["measured_n"] += 1

    total_exp_s = sum(r["expert_s"] for r in room_rows)
    total_first_s = sum(r["first_s"] for r in room_rows)

    payload = {
        "note": "Modelled minutes calibrated on Marwan's slot_1.json (not measured beyond his 41 complete rooms).",
        "weights": {fn: round(weights[i], 3) for i, fn in enumerate(FEATURE_NAMES)},
        "multipliers": mults,
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
            "effective_multiplier": round(total_first_s / max(1.0, total_exp_s), 2),
        },
        "islands": [
            {
                "island": v["island"],
                "rooms": v["rooms"],
                "expert_min": round(v["expert_s"] / 60.0, 1),
                "first_min": round(v["first_s"] / 60.0, 1),
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
                "measured_min": round(v["measured_s"] / 60.0, 1) if v["measured_n"] == v["rooms"] else None,
            }
            for _, v in sorted(by_dungeon.items())
        ],
        "rooms": room_rows,
    }

    bibles_comp: Optional[Dict[str, Any]] = None
    if args.bibles or args.summary:
        bibles = load_bible_targets(mults)
        if want_isls:
            bibles = {k: v for k, v in bibles.items() if k in want_isls}
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
        print(f"LUXEL EPIC PLAYTIME SUMMARY (modelled, R2={fit_clean['r2']} MAE={fit_clean['mae_s']}s | eff mult {g['effective_multiplier']:.2f}x)")
        print(f"  Built:  {bt['built_rooms']}/{bt['target_rooms']} rooms ({bt['rooms_pct']:.1f}%) | Exp {bt['model_exp_min']:.1f}m / {bt['target_exp_min']:.1f}m ({bt['model_exp_min']/60:.2f}h / {bt['target_exp_min']/60:.2f}h) | 1st {bt['model_first_min']:.1f}m / {bt['target_first_min']:.1f}m ({bt['model_first_min']/60:.2f}h / {bt['target_first_min']/60:.2f}h)")
        print(f"  {'Isl':>3s} {'Name':20s} {'Rooms':>9s} {'Dungs':>6s} {'ModelExp':>9s} {'TgtExp':>8s} {'Model1st':>9s} {'Tgt1st':>8s} {'%Tgt':>6s}")
        for ic in bibles_comp["islands"]:
            print(f"  {ic['island']:3d} {ic['name'][:20]:20s} {ic['built_rooms']:4d}/{ic['target_rooms']:<4d} {ic['dungeons_done']:2d}/{ic['dungeons_total']:<3d} {ic['model_exp_min']:8.1f}m {ic['target_exp_min']:7.1f}m {ic['model_first_min']:8.1f}m {ic['target_first_min']:7.1f}m {ic['pct_of_target']:5.1f}%")
        print(f"  {'TOT':>3s} {'ALL 8 ISLANDS':20s} {bt['built_rooms']:4d}/{bt['target_rooms']:<4d} {'-':>6s} {bt['model_exp_min']:8.1f}m {bt['target_exp_min']:7.1f}m {bt['model_first_min']:8.1f}m {bt['target_first_min']:7.1f}m {bt['pct_of_target']:5.1f}%")
        if not args.bibles:
            return 0

    if args.bibles and bibles_comp is not None:
        bt = bibles_comp["totals"]
        print("\nLUXEL PLAYTIME vs BIBLE TARGETS (per dungeon, modelled vs bible expert/1st-time)")
        print(f"{'Isl':>3s} {'Dungeon':16s} {'Rooms':>8s} {'ModExp':>7s} {'TgtExp':>7s} {'Delta':>7s} {'Mod1st':>7s} {'Tgt1st':>7s} {'%':>6s} {'Status':8s}")
        for d in bibles_comp["dungeons"]:
            print(f"{d['island']:3d} {d['dungeon'][:16]:16s} {d['built_rooms']:3d}/{d['target_rooms']:<4d} {d['model_exp_min']:6.1f}m {d['target_exp_min']:6.1f}m {d['delta_exp_min']:+6.1f}m {d['model_first_min']:6.1f}m {d['target_first_min']:6.1f}m {d['pct_of_target']:5.1f}% {d['status']:8s}")
        print(f"TOTAL: {bt['built_rooms']}/{bt['target_rooms']} rooms ({bt['rooms_pct']:.1f}%) | modelled exp {bt['model_exp_min']:.1f}m vs bible {bt['target_exp_min']:.1f}m ({bt['pct_of_target']:.1f}%) | 1st-time {bt['model_first_min']:.1f}m ({bt['model_first_min']/60:.2f}h) vs {bt['target_first_min']:.1f}m ({bt['target_first_min']/60:.2f}h)")
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
        print(f"{'Room':22s} {'Kind':10s} {'Exp(s)':>7s} {'Mult':>5s} {'1st(s)':>7s} {'Meas(s)':>8s}")
        for r in room_rows:
            ms = f"{r['measured_s']:7.1f}" if r["measured_s"] is not None else "      -"
            print(f"{r['key']:22s} {r['kind']:10s} {r['expert_s']:7.1f} {r['mult']:5.1f} {r['first_s']:7.1f} {ms}")

    if args.by in ("dungeon", "all"):
        print("\n--- Per Dungeon / Block (modelled minutes) ---")
        print(f"{'Isl':>3s} {'Block':18s} {'Rms':>4s} {'Expert':>8s} {'First':>8s} {'Measured':>9s}")
        for d in payload["dungeons"]:
            ms = f"{d['measured_min']:8.1f}m" if d["measured_min"] is not None else "        -"
            print(f"{d['island']:3d} {d['dungeon']:18s} {d['rooms']:4d} {d['expert_min']:7.1f}m {d['first_min']:7.1f}m {ms}")

    if args.by in ("island", "all"):
        print("\n--- Per Island (modelled minutes) ---")
        print(f"{'Island':>6s} {'Rms':>4s} {'Expert':>8s} {'First':>8s} {'Measured':>9s}")
        for isl in payload["islands"]:
            ms = f"{isl['measured_min']:8.1f}m" if isl["measured_min"] is not None else "        -"
            print(f"{isl['island']:6d} {isl['rooms']:4d} {isl['expert_min']:7.1f}m {isl['first_min']:7.1f}m {ms}")

    g = payload["game"]
    print(f"\nGAME TOTAL ({g['rooms']} rooms): modelled expert = {g['modelled_expert_min']:.1f} min ({g['modelled_expert_min']/60:.2f} h) | modelled first-time = {g['modelled_first_time_min']:.1f} min ({g['modelled_first_time_min']/60:.2f} h) | eff mult = {g['effective_multiplier']:.2f}x")
    return 0


if __name__ == "__main__":
    sys.exit(main())
