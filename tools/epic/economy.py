#!/usr/bin/env python3
"""Luxel Epic economy, progression, hearts, DPS & TTK analyzer (Python 3 stdlib only).

Reads all region JSONs, enemy/boss brains & factory data, packs (quests, moths,
panes, bosses), hub minigames/sinks, scripted island trials, upgrades.json,
islands.json, moves.json, optional economy.json, and boss_specs.

Computes per-island (critical vs optional) income, sinks, purchases per island
for Critical-Path / Normal / Completionist players, purchase cadence (target
8-10 min), dead-currency windows (target <= 20 min), hearts curve (max 12,
target reached around Island 7 by Normal), kit DPS, regular enemy TTK (target
1.5-4.0 s), and boss TTK (target 45-75 s mini / 90-150 s major).

Usage:
  python3 tools/epic/economy.py --summary [--json PATH] [--markdown]
  python3 tools/epic/economy.py --island N
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
import math
from pathlib import Path
import re
import statistics
import subprocess
import sys
from typing import Any, Dict, List, Optional, Set, Tuple

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import playtime as pt  # noqa: E402
import room_lint as rl  # noqa: E402

REPO_ROOT = rl.REPO_ROOT

# Scripted island trial & discovery shard/lead bonuses (extracted from luxel/islands/* & luxel/world/*)
SCRIPTED_ISLAND_REWARDS: Dict[int, List[Dict[str, Any]]] = {
    1: [
        {"id": "ow_carillon_trial", "shards": 60, "critical": False},
        {"id": "ow_chime_relay", "shards": 45, "critical": False},
        {"id": "ow_foundry_trial", "shards": 30, "critical": False},
    ],
    4: [
        {"id": "c4_canopy_plinth", "shards": 60, "critical": False},
        {"id": "isl4_trial_medal", "shards": 75, "critical": False},
    ],
    5: [
        {"id": "i5_overworld_telescope", "shards": 150, "lead": 1, "critical": False},
    ],
    6: [
        {"id": "kiln_casting_clamps", "shards": 70, "critical": False},
    ],
}

# Biome discoveries (luxel/world/biome_discoveries.gd + bell_chimes.gd):
# Each island has ~5 chime/discovery notes (2 shards each + 10 harmony bonus) + 1 lens secret (15 shards)
DISCOVERY_PER_ISLAND_SHARDS: int = 26

ALIASES: Dict[str, str] = {
    "parasol_toad": "warden", "toad_warden": "warden",
    "magpie": "snatcher", "magpie_snatcher": "snatcher",
    "hush_owl": "owl", "owl_sentinel": "owl",
    "moonshade": "moonshade_warden",
    "belfry_warden": "bell_warden", "grand_bellkeeper": "bellkeeper",
}

LEGACY_GRAND_BOSSES: Dict[str, int] = {
    "bellkeeper": 1, "lighthouse_hermit": 2, "briar_matron": 3, "heron_abbess": 4,
    "astronomer": 5, "kilnmother": 6, "hollow_wick_boss": 7, "the_hush": 8,
}
LEGACY_MINI_BOSSES: Dict[str, int] = {
    "bell_warden": 1, "tide_captain": 2, "elder_sporecap": 3, "great_lily_hopper": 4,
    "clockwork_warden": 5, "forge_warden": 6, "spire_warden": 7, "night_harbinger": 8,
}

# boss_check ISLAND_UPGRADES baseline (from tests/luxel/brain_check_specs.gd)
BOSS_CHECK_ISLAND_BOLT_RANK: Dict[int, int] = {
    1: 0, 2: 1, 3: 1, 4: 2, 5: 2, 6: 3, 7: 3, 8: 4,
}


def load_json_safe(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    try:
        d = json.loads(path.read_text(encoding="utf-8"))
        return d if isinstance(d, dict) else {}
    except Exception:
        return {}


def load_playtime_by_island() -> Dict[int, Dict[str, float]]:
    """Run playtime.py --summary --json - to get exact modelled playtime per island."""
    out: Dict[int, Dict[str, float]] = {}
    try:
        raw = subprocess.check_output(
            [sys.executable, str(SCRIPT_DIR / "playtime.py"), "--summary", "--json", "-"],
            cwd=str(REPO_ROOT),
            stderr=subprocess.DEVNULL,
            text=True,
        )
        data = json.loads(raw)
        for ic in data.get("islands", []):
            isl = int(ic["island"])
            out[isl] = {
                "rooms": int(ic["rooms"]),
                "crit_exp_min": float(ic["crit_exp_min"]),
                "opt_exp_min": float(ic["opt_exp_min"]),
                "tot_exp_min": float(ic["expert_min"]),
                "crit_first_min": float(ic["crit_first_min"]),
                "opt_first_min": float(ic["opt_first_min"]),
                "tot_first_min": float(ic["first_min"]),
            }
    except Exception:
        for isl in range(1, 9):
            out[isl] = {
                "rooms": 55, "crit_exp_min": 44.0, "opt_exp_min": 18.0, "tot_exp_min": 62.0,
                "crit_first_min": 115.0, "opt_first_min": 50.0, "tot_first_min": 165.0,
            }
        out[0] = {
            "rooms": 8, "crit_exp_min": 0.0, "opt_exp_min": 15.0, "tot_exp_min": 15.0,
            "crit_first_min": 0.0, "opt_first_min": 42.0, "tot_first_min": 42.0,
        }
    return out


def load_all_packs() -> Dict[str, Any]:
    """Load enemies, bosses, quests, moths, moth_tiers, panes, aliases from all pack JSONs."""
    packs: Dict[str, Any] = {
        "enemies": {}, "bosses": {}, "quests": {}, "moths": {},
        "moth_tiers": [], "panes": {}, "aliases": dict(ALIASES),
    }
    paths: List[Path] = []
    for g in ("luxel/data/packs/*.json", "luxel/world/folk/folk_catalog.json", "luxel/islands/*/packs/*.json"):
        paths.extend(sorted(REPO_ROOT.glob(g)))
    seen: Set[Path] = set()
    for p in paths:
        rp = p.resolve()
        if rp in seen:
            continue
        seen.add(rp)
        d = load_json_safe(p)
        if not d:
            continue
        m_isl = re.search(r"islands/(\d+)/packs/", str(p))
        folder_isl = int(m_isl.group(1)) if m_isl else None
        for k, v in (d.get("enemy_aliases") or {}).items():
            packs["aliases"][str(k).lower()] = str(v).lower()
        for k, v in (d.get("enemies") or {}).items():
            if isinstance(v, dict):
                kl = str(k).lower()
                ed = v.get("data") if isinstance(v.get("data"), dict) else v
                entry = dict(ed)
                entry.setdefault("island", folder_isl if folder_isl is not None else v.get("island", 1))
                entry["script"] = str(v.get("script", ""))
                packs["enemies"][kl] = entry
        for k, v in (d.get("bosses") or {}).items():
            if isinstance(v, dict):
                kl = str(k).lower()
                entry = dict(v)
                if "island" not in entry or entry["island"] is None:
                    entry["island"] = folder_isl if folder_isl is not None else 1
                packs["bosses"][kl] = entry
        q_raw = d.get("quests")
        if isinstance(q_raw, list):
            for q in q_raw:
                if isinstance(q, dict) and q.get("id"):
                    qe = dict(q)
                    if "island" not in qe and folder_isl is not None:
                        qe["island"] = folder_isl
                    packs["quests"][str(q["id"])] = qe
        elif isinstance(q_raw, dict):
            for k, q in q_raw.items():
                if isinstance(q, dict):
                    qe = dict(q)
                    qe.setdefault("id", str(k))
                    if "island" not in qe and folder_isl is not None:
                        qe["island"] = folder_isl
                    packs["quests"][str(qe["id"])] = qe
        m_raw = d.get("moths")
        if isinstance(m_raw, list):
            for m in m_raw:
                if isinstance(m, dict) and m.get("id"):
                    packs["moths"][str(m["id"])] = dict(m)
        elif isinstance(m_raw, dict):
            for k, m in m_raw.items():
                if isinstance(m, dict):
                    me = dict(m)
                    me.setdefault("id", str(k))
                    packs["moths"][str(k)] = me
        if isinstance(d.get("moth_tiers"), list) and not packs["moth_tiers"]:
            packs["moth_tiers"] = list(d["moth_tiers"])
        for k, v in (d.get("panes") or {}).items():
            if isinstance(v, dict):
                packs["panes"][str(k)] = dict(v)
    return packs


def load_brain_init_stats() -> Dict[str, Dict[str, Any]]:
    """Extract actual max_hp, shard_drop, shield_hp, reward_heart from brain.gd files & enemy_factory.gd."""
    stats: Dict[str, Dict[str, Any]] = {}
    # 1. enemy_factory.gd defaults
    ef = REPO_ROOT / "luxel" / "enemies" / "enemy_factory.gd"
    if ef.exists():
        txt = ef.read_text(encoding="utf-8")
        pat = re.compile(
            r'_make_data\(\s*"([a-z0-9_]+)"\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,'
            r'\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)'
            r'(?:\s*,\s*([0-9.]+))?(?:\s*,\s*([0-9]+))?(?:\s*,\s*([0-9.]+))?(?:\s*,\s*(true|false))?'
        )
        for m in pat.finditer(txt):
            stats[m.group(1)] = {
                "max_hp": float(m.group(2)),
                "shield_hp": float(m.group(9) or 0.0),
                "shard_drop": int(m.group(10) or 3),
                "is_boss": (m.group(12) == "true"),
                "reward_heart": "",
            }
    # 2. Override with actual brain.gd values (since brains set max_hp & shard_drop directly in _init/_configure)
    for folder, is_boss_dir in (("luxel/enemies", False), ("luxel/bosses", True)):
        for bp in sorted((REPO_ROOT / folder).glob("*/brain.gd")):
            kind = bp.parent.name.lower()
            txt = bp.read_text(encoding="utf-8")
            m_hp = re.findall(r'\bmax_hp\s*=\s*([0-9]+(?:\.[0-9]+)?)', txt)
            m_sd = re.findall(r'\bshard_drop\s*=\s*([0-9]+)', txt)
            m_sh = re.findall(r'\bshield_(?:max|hp)\s*=\s*([0-9]+(?:\.[0-9]+)?)', txt)
            m_rh = re.findall(r'\breward_heart\s*=\s*"([a-z_]+)"', txt)
            cur = stats.setdefault(kind, {
                "max_hp": 12.0 if is_boss_dir else 3.0,
                "shield_hp": 0.0,
                "shard_drop": 18 if is_boss_dir else 3,
                "is_boss": is_boss_dir,
                "reward_heart": "",
            })
            if m_hp:
                # For multi-assignment brains like bellkeeper, take base max_hp (first literal)
                cur["max_hp"] = float(m_hp[0])
            if m_sd:
                cur["shard_drop"] = int(m_sd[0])
            if m_sh:
                cur["shield_hp"] = float(m_sh[0])
            if m_rh:
                cur["reward_heart"] = m_rh[0]
            if is_boss_dir:
                cur["is_boss"] = True
    return stats


def parse_hub_state() -> Dict[str, Any]:
    """Parse hub_state.gd for lead prices, flame catalog, minigame rewards, rematch rewards."""
    p = REPO_ROOT / "luxel" / "hub" / "hub_state.gd"
    lead_prices = [60, 100, 150, 220]
    flame_prices = [45, 55, 75, 85, 90, 95, 120]
    mg_shards = 40 + 40 + 35 + 35 + 35 + 45  # 230 bronze shards
    mg_lead = 4  # shooting silver, juggle gold, dash gold bonus, cellar silver
    mg_embers = 1  # cellar gold bonus
    mg_moths = 4  # skiff gold, juggle silver, choir silver, cellar gold
    mg_panes = 4  # shooting gold, skiff gold, dash gold, choir gold
    mg_free_flames = {"apricot", "sky", "cream", "rose", "lime"}
    if p.exists():
        txt = p.read_text(encoding="utf-8")
        ml = re.search(r'LEAD_PRICES[^=]*=\s*\[([^\]]+)\]', txt)
        if ml:
            lead_prices = [int(x.strip()) for x in ml.group(1).split(",") if x.strip().isdigit()]
        fl_items = re.findall(r'"id":\s*"([a-z_]+)"[^}]*"price":\s*(\d+)', txt)
        if fl_items:
            flame_prices = [int(pr) for fid, pr in fl_items if int(pr) > 0]
            paid_flames = [int(pr) for fid, pr in fl_items if int(pr) > 0 and fid not in mg_free_flames]
        else:
            paid_flames = [75, 120]
    else:
        paid_flames = [75, 120]
    return {
        "lead_prices": lead_prices,
        "flame_prices_all": flame_prices,
        "flame_prices_paid_only": paid_flames,
        "minigame_shards": mg_shards,
        "minigame_lead": mg_lead,
        "minigame_embers": mg_embers,
        "minigame_moths": mg_moths,
        "minigame_panes": mg_panes,
        # Rematch: 1st no-hit gives 1 ember; bronze=30, gold=60 per boss; 3 golds -> +1 lead.
        # Normal player tries ~3 rematches (bronze), completionist clears ~16 rematches (gold + 1 nohit).
        "rematch_normal_shards": 90,
        "rematch_comp_shards": 16 * 90,
        "rematch_comp_embers": 1,
        "rematch_comp_lead": 1,
    }


def load_boss_specs() -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    for p in sorted((REPO_ROOT / "tests" / "luxel" / "boss_specs").glob("*.json")):
        d = load_json_safe(p)
        if d:
            bid = str(d.get("id", p.stem)).lower()
            out[bid] = d
            out[p.stem.lower()] = d
    return out


def get_band_mults(economy_cfg: Dict[str, Any], island: int, kind: str, is_boss: bool, is_mini: bool, is_super: bool) -> Tuple[float, float]:
    """Mirror LxEnemyFactory data-driven per-island HP and shard drop multipliers."""
    if not economy_cfg:
        return 1.0, 1.0
    k_ov = (economy_cfg.get("kind_overrides") or {}).get(kind, {})
    if is_boss:
        bands = economy_cfg.get("boss_bands") or {}
        b = bands.get(str(island), bands.get("default", {}))
        if is_super:
            hp_m = float(b.get("super_hp_mult", b.get("hp_mult", 1.0)))
        elif is_mini:
            hp_m = float(b.get("mini_hp_mult", b.get("hp_mult", 1.0)))
        else:
            hp_m = float(b.get("major_hp_mult", b.get("hp_mult", 1.0)))
        sh_m = float(b.get("shard_mult", 1.0))
    else:
        bands = economy_cfg.get("enemy_bands") or {}
        b = bands.get(str(island), bands.get("default", {}))
        hp_m = float(b.get("hp_mult", 1.0))
        sh_m = float(b.get("shard_mult", 1.0))
    hp_m *= float(k_ov.get("hp_mult", 1.0))
    sh_m *= float(k_ov.get("shard_mult", 1.0))
    return hp_m, sh_m


def canonical_kind(raw: str, aliases: Dict[str, str]) -> str:
    k = str(raw or "").strip().lower()
    return aliases.get(k, k)


def collect_world_economy() -> Dict[str, Any]:
    bibles = pt.load_bible_targets(pt.R1_MULTIPLIERS)
    packs = load_all_packs()
    brain_stats = load_brain_init_stats()
    economy_cfg = load_json_safe(REPO_ROOT / "luxel" / "data" / "economy.json")
    islands_cfg = load_json_safe(REPO_ROOT / "luxel" / "data" / "islands.json")
    moves_cfg = load_json_safe(REPO_ROOT / "luxel" / "data" / "moves.json")
    upgrades_cfg = load_json_safe(REPO_ROOT / "luxel" / "data" / "upgrades.json")
    hub_cfg = parse_hub_state()
    boss_specs = load_boss_specs()
    boss_ttks = pt.load_boss_check_ttks()
    playtime_isl = load_playtime_by_island()

    aliases = packs["aliases"]
    mini_set = pt._load_mini_boss_set()

    # Map moves -> unlock island
    move_unlock_isl: Dict[str, int] = {"bolt": 0}
    for isl_d in islands_cfg.get("islands", []):
        iid = int(isl_d.get("id", 1))
        for mv in isl_d.get("move_gained", []):
            move_unlock_isl[str(mv).lower()] = iid

    # Per-island income buckets: critical vs optional
    def blank_bucket() -> Dict[str, Any]:
        return {
            "rooms": 0,
            "chest_shards": 0, "enemy_shards": 0, "boss_shards": 0,
            "event_shards": 0, "quest_shards": 0, "trial_shards": 0,
            "discovery_shards": 0, "hub_shards": 0,
            "ember_pieces": 0, "half_lanterns": 0, "full_hearts": 0,
            "lead": 0, "slots": 0, "panes": 0, "moths": 0,
            "enemy_count": 0, "boss_count": 0,
        }

    income: Dict[int, Dict[str, Dict[str, Any]]] = {
        i: {"critical": blank_bucket(), "optional": blank_bucket()} for i in range(0, 9)
    }

    seen_bosses: Set[str] = set()
    regular_enemy_samples: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
    boss_records: List[Dict[str, Any]] = []
    double_heart_bosses: List[str] = []

    for isl in range(0, 9):
        isl_dir = REPO_ROOT / "luxel" / "islands" / str(isl)
        if not isl_dir.exists():
            continue
        for jp in sorted(isl_dir.glob("*.json")):
            reg_id = jp.stem
            if reg_id.startswith("_") or "demo" in reg_id or "test" in reg_id:
                continue
            reg = load_json_safe(jp)
            if not reg or bool(reg.get("debug_only", False)):
                continue
            is_crit = pt._is_region_critical(isl, reg_id, bibles)
            bkt = income[isl]["critical" if is_crit else "optional"]
            bkt["rooms"] += 1

            # Interactables: chests, panes, moths
            for it in reg.get("interactables") or []:
                if not isinstance(it, dict):
                    continue
                ik = str(it.get("kind", "")).lower()
                props = it.get("props") if isinstance(it.get("props"), dict) else {}
                if ik == "chest":
                    rew = str(props.get("reward", "shards")).lower()
                    if rew == "ember_piece" or rew == "ember":
                        bkt["ember_pieces"] += 1
                    elif rew == "shards":
                        amt = int(props.get("amount", 20))
                        bkt["chest_shards"] += max(0, amt)
                    elif rew == "lead":
                        bkt["lead"] += int(props.get("amount", 1))
                    elif rew == "pane":
                        bkt["panes"] += 1
                elif ik == "pane_pickup":
                    bkt["panes"] += 1
                elif ik == "moth":
                    bkt["moths"] += 1

            # Events: give_reward + wave enemies
            wave_enemies: List[Dict[str, Any]] = []
            for ev in reg.get("events") or []:
                if not isinstance(ev, dict):
                    continue
                for act in ev.get("do") or []:
                    if not isinstance(act, dict):
                        continue
                    if "give_reward" in act and isinstance(act["give_reward"], dict):
                        gr = act["give_reward"]
                        rk = str(gr.get("kind", "shards")).lower()
                        amt = int(gr.get("amount", 20 if rk == "shards" else 1))
                        if rk == "shards":
                            bkt["event_shards"] += max(0, amt)
                        elif rk in ("ember_piece", "ember"):
                            bkt["ember_pieces"] += max(1, amt)
                        elif rk == "lead":
                            bkt["lead"] += max(1, amt)
                        elif rk == "pane":
                            bkt["panes"] += 1
                    if "wave" in act and isinstance(act["wave"], list):
                        for we in act["wave"]:
                            if isinstance(we, dict):
                                wave_enemies.append(we)
                    if "spawn_enemy" in act and isinstance(act["spawn_enemy"], dict):
                        wave_enemies.append(act["spawn_enemy"])

            # Enemies + wave enemies
            all_e = list(reg.get("enemies") or []) + wave_enemies
            for e in all_e:
                if not isinstance(e, dict):
                    continue
                kind = canonical_kind(e.get("kind", ""), aliases)
                if not kind:
                    continue
                pack_ed = packs["enemies"].get(kind, {})
                bmeta = packs["bosses"].get(kind, {})
                bstat = brain_stats.get(kind, {})

                is_legacy_boss = kind in LEGACY_GRAND_BOSSES or kind in LEGACY_MINI_BOSSES
                is_boss = (
                    (bool(bmeta) or is_legacy_boss or bool(bstat.get("is_boss", False)) or bool(pack_ed.get("is_boss", False)))
                    and kind not in pt.NON_BOSS_ENCOUNTER_KINDS
                )
                is_super = kind in pt.SUPERBOSS_IDS or reg_id.startswith(("superboss_", "sb_", "vault_last_hour", "cave_undertow_maw"))
                is_mini = (
                    not is_super
                    and (kind in mini_set or kind in LEGACY_MINI_BOSSES or bool(bmeta.get("mini", False)))
                )

                base_hp = float(e.get("max_hp", bstat.get("max_hp", pack_ed.get("max_hp", 12.0 if is_boss else 3.0))))
                base_hp *= float(e.get("hp_scale", 1.0))
                base_sd = int(e.get("shard_drop", bstat.get("shard_drop", pack_ed.get("shard_drop", 18 if is_boss else 3))))
                base_sh = float(bstat.get("shield_hp", pack_ed.get("shield_hp", 0.0)))

                hp_m, sh_m = get_band_mults(economy_cfg, isl, kind, is_boss, is_mini, is_super)
                eff_hp = round(base_hp * hp_m, 2)
                eff_sd = max(1, int(round(base_sd * sh_m))) if base_sd > 0 else 0

                if is_boss:
                    bkt["boss_count"] += 1
                    bkt["boss_shards"] += eff_sd
                    boss_key = str(e.get("boss_id", kind)).lower()
                    if boss_key not in seen_bosses:
                        seen_bosses.add(boss_key)
                        # Determine heart reward (pack boss_hud vs boss_base)
                        pack_h = str(bmeta.get("heart", "")).lower()
                        if not pack_h and kind in LEGACY_GRAND_BOSSES:
                            pack_h = "full"
                        elif not pack_h and kind in LEGACY_MINI_BOSSES:
                            pack_h = "none"
                        brain_h = str(bstat.get("reward_heart", "")).lower()
                        # In runtime: boss_hud grants pack_h; boss_base grants brain_h if not "none".
                        # Track effective single grant and flag any double-granting boss!
                        eff_h = pack_h if pack_h in ("full", "half") else (brain_h if brain_h in ("full", "half") else "none")
                        if pack_h in ("full", "half") and brain_h in ("full", "half"):
                            double_heart_bosses.append(boss_key)
                        if eff_h == "full":
                            bkt["full_hearts"] += 1
                        elif eff_h == "half":
                            bkt["half_lanterns"] += 1

                        tier = "superboss" if is_super else ("mini" if is_mini else "boss")
                        spec = boss_specs.get(boss_key) or boss_specs.get("boss_" + boss_key) or {}
                        ttk_info = boss_ttks.get(boss_key) or boss_ttks.get("boss_" + boss_key) or {}
                        boss_records.append({
                            "id": boss_key,
                            "island": isl,
                            "region": reg_id,
                            "critical": is_crit,
                            "tier": tier,
                            "base_hp": base_hp,
                            "eff_hp": eff_hp,
                            "hp_mult": hp_m,
                            "shard_drop": eff_sd,
                            "heart": eff_h,
                            "spec_bolts": spec.get("hp_bolts_expected"),
                            "measured_ttk": float(ttk_info.get("bot_ttk", 0.0)),
                            "ttk_source": str(ttk_info.get("source", "model")),
                        })
                else:
                    bkt["enemy_count"] += 1
                    bkt["enemy_shards"] += eff_sd
                    regular_enemy_samples[isl].append({
                        "kind": kind,
                        "region": reg_id,
                        "critical": is_crit,
                        "base_hp": base_hp,
                        "eff_hp": eff_hp,
                        "shield_hp": base_sh,
                        "shard_drop": eff_sd,
                    })

        # Add overworld discoveries/chimes + scripted trials for islands 1..8
        if isl >= 1:
            income[isl]["optional"]["discovery_shards"] += DISCOVERY_PER_ISLAND_SHARDS
            for tr in SCRIPTED_ISLAND_REWARDS.get(isl, []):
                tbkt = income[isl]["critical" if tr.get("critical") else "optional"]
                tbkt["trial_shards"] += int(tr.get("shards", 0))
                tbkt["lead"] += int(tr.get("lead", 0))

    # Add pack quests (optional, placed on their island)
    for qid, q in packs["quests"].items():
        qisl = int(q.get("island", 0))
        qisl = max(0, min(8, qisl))
        rew = q.get("reward") if isinstance(q.get("reward"), dict) else {}
        rk = str(rew.get("kind", "")).lower()
        amt = int(rew.get("amount", 1))
        qbkt = income[qisl]["optional"]
        if rk == "shards":
            qbkt["quest_shards"] += max(0, amt)
        elif rk in ("ember_piece", "ember"):
            qbkt["ember_pieces"] += max(1, amt)
        elif rk == "lead":
            qbkt["lead"] += max(1, amt)
        elif rk == "slot":
            qbkt["slots"] += max(1, amt)
        elif rk == "pane":
            qbkt["panes"] += 1

    # Add Hub minigames + rematch income to island 0 optional
    income[0]["optional"]["hub_shards"] += hub_cfg["minigame_shards"] + hub_cfg["rematch_comp_shards"]
    income[0]["optional"]["lead"] += hub_cfg["minigame_lead"] + hub_cfg["rematch_comp_lead"]
    income[0]["optional"]["ember_pieces"] += hub_cfg["minigame_embers"] + hub_cfg["rematch_comp_embers"]
    income[0]["optional"]["panes"] += hub_cfg["minigame_panes"]
    income[0]["optional"]["moths"] += hub_cfg["minigame_moths"]

    # Tally totals helper
    def total_shards(b: Dict[str, Any]) -> int:
        return (
            b["chest_shards"] + b["enemy_shards"] + b["boss_shards"]
            + b["event_shards"] + b["quest_shards"] + b["trial_shards"]
            + b["discovery_shards"] + b["hub_shards"]
        )

    for isl in range(0, 9):
        for side in ("critical", "optional"):
            income[isl][side]["total_shards"] = total_shards(income[isl][side])

    # Build catalog of ALL shard sinks (Rest Shop upgrades + shop wares + hub lead + hub flames)
    sinks: List[Dict[str, Any]] = []
    # 1. Rest shop upgrades
    for u in upgrades_cfg.get("upgrades", []):
        uid = str(u.get("id", ""))
        req_m = str(u.get("requires_move", "")).lower()
        req_isl = int(u.get("requires_island", 0))
        u_isl = max(1, move_unlock_isl.get(req_m, 1) if req_m else 1, req_isl)
        costs = [int(c) for c in u.get("costs", [])]
        vals = list(u.get("values", []))
        rank_isls = [int(x) for x in u.get("rank_islands", [])]
        for r_i, c in enumerate(costs):
            ri = max(u_isl, rank_isls[r_i] if r_i < len(rank_isls) else u_isl)
            sinks.append({
                "id": f"{uid}:r{r_i+1}",
                "group": uid,
                "kind": "upgrade",
                "rank": r_i + 1,
                "unlock_island": ri,
                "cost": c,
                "value": vals[r_i] if r_i < len(vals) else None,
                "priority": _upgrade_priority(uid, r_i + 1),
            })

    # 2. Rest Shop / NPC Wares (from upgrades.json "wares" or economy.json "shop_wares")
    wares = list(upgrades_cfg.get("wares", [])) or list(economy_cfg.get("shop_wares", []))
    for w in wares:
        if bool(w.get("repeatable", False)):
            continue
        wid = str(w.get("id", ""))
        w_isl = max(1, int(w.get("requires_island", 1)))
        ris = [int(x) for x in w.get("rank_islands", [])]
        costs = [int(c) for c in (w.get("costs") or [w.get("cost", 0)])]
        for r_i, c in enumerate(costs):
            if c <= 0:
                continue
            ri = ris[r_i] if r_i < len(ris) else (w_isl + r_i if bool(w.get("stagger_islands", False)) else w_isl)
            sinks.append({
                "id": f"ware:{wid}:r{r_i+1}",
                "group": wid,
                "kind": "ware",
                "ware_type": str(w.get("effect", "ware")),
                "rank": r_i + 1,
                "unlock_island": min(8, max(1, ri)),
                "cost": c,
                "priority": 34 + r_i * 12,
            })

    # 3. Hub Lead Forge (available from Island 1 once hub unlocked)
    for idx, lp in enumerate(hub_cfg["lead_prices"]):
        sinks.append({
            "id": f"hub_lead:{idx+1}",
            "group": "hub_lead",
            "kind": "hub_lead",
            "rank": idx + 1,
            "unlock_island": min(8, 1 + idx * 2),
            "cost": lp,
            "priority": 35 + idx * 8,
        })

    # 4. Hub Flame Tailor (non-free cosmetics; players may buy all or only paid ones)
    for idx, fp in enumerate(hub_cfg["flame_prices_all"]):
        sinks.append({
            "id": f"hub_flame:{idx+1}",
            "group": "hub_flame",
            "kind": "hub_flame",
            "rank": idx + 1,
            "unlock_island": min(8, 1 + idx),
            "cost": fp,
            "priority": 80 + idx,
        })

    # Hearts rules
    decisions = islands_cfg.get("decisions", {})
    hearts_start = int(decisions.get("hearts_start", 4))
    hearts_max = int(decisions.get("hearts_max", 12))
    embers_per_heart = int(decisions.get("ember_pieces_per_heart", 4))
    halfs_per_heart = int(decisions.get("half_lanterns_per_heart", 2))
    boss_full_below = int(decisions.get("boss_heart_full_below", 99))
    boss_pieces = int(decisions.get("boss_heart_pieces", 2))
    moth_tiers = packs["moth_tiers"]

    # Simulate 3 player profiles across Islands 1..8
    profiles: Dict[str, Any] = {}
    for pname, opt_frac, hub_frac, include_cosmetics in (
        ("critical", 0.0, 0.0, False),
        ("normal", 0.50, 0.35, True),
        ("completionist", 1.0, 1.0, True),
    ):
        profiles[pname] = simulate_profile(
            pname, opt_frac, hub_frac, include_cosmetics,
            income, sinks, playtime_isl, moth_tiers, hub_cfg,
            hearts_start, hearts_max, embers_per_heart, halfs_per_heart,
            boss_full_below, boss_pieces,
            moves_cfg, upgrades_cfg,
        )

    # Regular enemy TTK & Boss TTK at Normal player's expected kit per island
    normal_isl_kits = {r["island"]: r["kit"] for r in profiles["normal"]["by_island"]}
    enemy_ttk_by_island = compute_enemy_ttk_table(regular_enemy_samples, normal_isl_kits)
    boss_ttk_table = compute_boss_ttk_table(
        boss_records, normal_isl_kits, moves_cfg, upgrades_cfg, economy_cfg
    )

    return {
        "decisions": {
            "hearts_start": hearts_start,
            "hearts_max": hearts_max,
            "ember_pieces_per_heart": embers_per_heart,
            "half_lanterns_per_heart": halfs_per_heart,
            "has_economy_json": bool(economy_cfg),
        },
        "playtime_by_island": playtime_isl,
        "income_by_island": income,
        "sink_totals": {
            "upgrade_count": len(upgrades_cfg.get("upgrades", [])),
            "upgrade_ranks": sum(int(u.get("max_rank", 0)) for u in upgrades_cfg.get("upgrades", [])),
            "upgrades_shards": sum(s["cost"] for s in sinks if s["kind"] == "upgrade"),
            "wares_ranks": sum(1 for s in sinks if s["kind"] == "ware"),
            "wares_shards": sum(s["cost"] for s in sinks if s["kind"] == "ware"),
            "hub_lead_shards": sum(s["cost"] for s in sinks if s["kind"] == "hub_lead"),
            "hub_flame_shards": sum(s["cost"] for s in sinks if s["kind"] == "hub_flame"),
            "all_sinks_shards": sum(s["cost"] for s in sinks),
        },
        "profiles": profiles,
        "enemy_ttk_by_island": enemy_ttk_by_island,
        "boss_ttk": boss_ttk_table,
        "double_heart_bosses": sorted(set(double_heart_bosses)),
    }


def _upgrade_priority(uid: StringLike, rank: int) -> int:
    order = {
        "bolt_damage": 10, "bolt_rate": 12, "spare_wick": 15, "dash_cooldown": 18,
        "dash_charges": 19, "throw_damage": 20, "throw_hang": 24, "zip_bomb": 25,
        "prism_bounce": 26, "beam_charge": 28, "beam_width": 30,
        "wings_glide": 32, "lens_duration": 34, "lens_radius": 36,
        "ember_meter": 38, "pickup_radius": 40,
    }
    return order.get(str(uid), 50) + (rank - 1) * 14


StringLike = Any


def kit_stats_from_ranks(
    ranks: Dict[str, int],
    island: int,
    moves_cfg: Dict[str, Any],
    upgrades_cfg: Dict[str, Any],
) -> Dict[str, float]:
    moves = moves_cfg.get("moves", {})
    upg_map = {str(u["id"]): u for u in upgrades_cfg.get("upgrades", [])}

    def eff(uid: str, move_id: str, field: str, default: float, vkey: str = "values") -> float:
        base = float((moves.get(move_id) or {}).get(field, default))
        r = ranks.get(uid, 0)
        if r <= 0 or uid not in upg_map:
            return base
        vals = upg_map[uid].get(vkey) or []
        return float(vals[min(r - 1, len(vals) - 1)]) if vals else base

    bolt_dmg = eff("bolt_damage", "bolt", "damage", 0.35)
    bolt_cd = eff("bolt_rate", "bolt", "cooldown", 0.18)
    throw_dmg = eff("throw_damage", "throw", "throw_damage", 2.0)
    zip_dmg = eff("zip_bomb", "throw", "zip_damage", 1.75, "dmg_values")
    beam_cd = eff("beam_charge", "beam", "charge_time", 0.6) + float((moves.get("beam") or {}).get("cooldown", 0.45))
    beam_dmg = eff("beam_width", "beam", "damage", 2.5, "dmg_values")
    ember_max = eff("ember_meter", "sunflare", "ember_max", 100.0)

    bolt_sustained_dps = bolt_dmg / max(0.05, bolt_cd)
    # Realistic sustained combat DPS (blending ~65% bolt uptime + throw/recall weaves from Isl 1,
    # beam bursts from Isl 3, sunflare bursts from Isl 6)
    weave_bonus = 0.0
    if island >= 1:
        weave_bonus += (throw_dmg * 0.65 + zip_dmg * 0.35) / 5.5
    if island >= 3:
        weave_bonus += beam_dmg / max(3.5, beam_cd + 3.2)
    if island >= 6:
        weave_bonus += 3.0 / max(8.0, (ember_max / 8.0))
    combat_dps = bolt_sustained_dps * 0.72 + weave_bonus

    return {
        "bolt_dmg": round(bolt_dmg, 3),
        "bolt_cd": round(bolt_cd, 3),
        "throw_dmg": round(throw_dmg, 2),
        "bolt_dps": round(bolt_sustained_dps, 2),
        "combat_dps": round(combat_dps, 2),
    }


def simulate_profile(
    name: str,
    opt_frac: float,
    hub_frac: float,
    include_cosmetics: bool,
    income: Dict[int, Dict[str, Dict[str, Any]]],
    sinks: List[Dict[str, Any]],
    playtime_isl: Dict[int, Dict[str, float]],
    moth_tiers: List[Dict[str, Any]],
    hub_cfg: Dict[str, Any],
    hearts_start: int,
    hearts_max: int,
    embers_per_heart: int,
    halfs_per_heart: int,
    boss_full_below: int,
    boss_pieces: int,
    moves_cfg: Dict[str, Any],
    upgrades_cfg: Dict[str, Any],
) -> Dict[str, Any]:
    bought: Set[str] = set()
    ranks: Dict[str, int] = defaultdict(int)
    shards_wallet = 0
    cum_shards_earned = 0
    cum_shards_spent = 0

    max_hearts = hearts_start
    embers_total = 0
    embers_rem = 0
    half_rem = 0
    heart_overflows = 0
    hit_max_hearts_island: Optional[int] = None

    moths_total = 0.0
    claimed_moth_tiers: Set[int] = set()

    # Hub optional share distributed smoothly across Islands 2..7
    hub_opt = income[0]["optional"]
    hub_shards_pool = int(round((hub_cfg["minigame_shards"] + (hub_cfg["rematch_comp_shards"] if hub_frac >= 0.99 else hub_cfg["rematch_normal_shards"])) * hub_frac))
    hub_embers_pool = int(round(hub_opt["ember_pieces"] * hub_frac))
    hub_moths_pool = hub_opt["moths"] * hub_frac

    by_island: List[Dict[str, Any]] = []
    max_dead_shard_min = 0.0
    cur_dead_shard_min = 0.0
    total_purchases = 0
    total_first_min = 0.0
    total_exp_min = 0.0

    for isl in range(1, 9):
        crit = income[isl]["critical"]
        opt = income[isl]["optional"]

        # Playtime on this island for this profile
        pt_i = playtime_isl.get(isl, {"crit_first_min": 100.0, "opt_first_min": 40.0, "crit_exp_min": 40.0, "opt_exp_min": 16.0})
        hub_pt_first = (playtime_isl.get(0, {}).get("opt_first_min", 42.0) * hub_frac / 6.0) if 2 <= isl <= 7 else 0.0
        hub_pt_exp = (playtime_isl.get(0, {}).get("opt_exp_min", 15.0) * hub_frac / 6.0) if 2 <= isl <= 7 else 0.0
        isl_first_min = pt_i["crit_first_min"] + pt_i["opt_first_min"] * opt_frac + hub_pt_first
        isl_exp_min = pt_i["crit_exp_min"] + pt_i["opt_exp_min"] * opt_frac + hub_pt_exp
        total_first_min += isl_first_min
        total_exp_min += isl_exp_min

        # Shards earned on this island
        hub_s_slice = int(round(hub_shards_pool / 6.0)) if 2 <= isl <= 7 else 0
        earned_s = crit["total_shards"] + int(round(opt["total_shards"] * opt_frac)) + hub_s_slice

        # Moths & moth tier rewards
        hub_m_slice = (hub_moths_pool / 6.0) if 2 <= isl <= 7 else 0.0
        moths_total += crit["moths"] + opt["moths"] * opt_frac + hub_m_slice
        tier_embers = 0
        tier_shards = 0
        for mt in moth_tiers:
            need = int(mt.get("count", 999))
            if moths_total >= need and need not in claimed_moth_tiers:
                claimed_moth_tiers.add(need)
                rk = str(mt.get("reward", "")).lower()
                if rk == "ember_piece":
                    tier_embers += 1
                elif rk == "shards":
                    tier_shards += int(mt.get("amount", 0))
        earned_s += tier_shards

        # Hearts earned on this island
        hub_e_slice = 1 if (hub_embers_pool > 0 and isl in (4, 6) and hub_frac >= 0.5) else 0
        e_gain = crit["ember_pieces"] + int(round(opt["ember_pieces"] * opt_frac)) + tier_embers + hub_e_slice
        # Mini-bosses in optional side dungeons: normal player beats ~opt_frac of optional half-lanterns
        h_gain = crit["half_lanterns"] + int(round(opt["half_lanterns"] * opt_frac))
        # Full hearts: critical grand bosses + optional superbosses (only completionist beats superbosses before Isl 8)
        sb_frac = 1.0 if opt_frac >= 0.99 else (0.25 if (opt_frac >= 0.45 and isl >= 6) else 0.0)
        f_gain = crit["full_hearts"] + int(round(opt["full_hearts"] * sb_frac))

        embers_total += e_gain
        embers_rem += e_gain
        while embers_rem >= embers_per_heart:
            embers_rem -= embers_per_heart
            if max_hearts < hearts_max:
                max_hearts += 1
                if max_hearts >= hearts_max and hit_max_hearts_island is None:
                    hit_max_hearts_island = isl
            else:
                heart_overflows += 1

        half_rem += h_gain
        while half_rem >= halfs_per_heart:
            half_rem -= halfs_per_heart
            if max_hearts < hearts_max:
                max_hearts += 1
                if max_hearts >= hearts_max and hit_max_hearts_island is None:
                    hit_max_hearts_island = isl
            else:
                heart_overflows += 1

        for _ in range(f_gain):
            if max_hearts < boss_full_below:
                if max_hearts < hearts_max:
                    max_hearts += 1
                    if max_hearts >= hearts_max and hit_max_hearts_island is None:
                        hit_max_hearts_island = isl
                else:
                    heart_overflows += 1
            else:
                half_rem += boss_pieces

        while half_rem >= halfs_per_heart:
            half_rem -= halfs_per_heart
            if max_hearts < hearts_max:
                max_hearts += 1
                if max_hearts >= hearts_max and hit_max_hearts_island is None:
                    hit_max_hearts_island = isl
            else:
                heart_overflows += 1

        # Greedy purchasing among unlocked sinks on this island
        shards_wallet += earned_s
        cum_shards_earned += earned_s

        bought_this_isl: List[str] = []
        spent_this_isl = 0
        while True:
            avail = [
                s for s in sinks
                if s["id"] not in bought
                and s["unlock_island"] <= isl
                and (include_cosmetics or s["kind"] != "hub_flame")
                and (s["kind"] != "upgrade" or ranks[s["group"]] == s["rank"] - 1)
                and (s["kind"] != "ware" or ranks["ware:" + s["group"]] == s["rank"] - 1)
                and (s["kind"] != "hub_lead" or ranks["hub_lead"] == s["rank"] - 1)
                and s["cost"] <= shards_wallet
            ]
            if not avail:
                break
            avail.sort(key=lambda s: (s["priority"], s["cost"]))
            pick = avail[0]
            shards_wallet -= pick["cost"]
            spent_this_isl += pick["cost"]
            cum_shards_spent += pick["cost"]
            bought.add(pick["id"])
            if pick["kind"] == "upgrade":
                ranks[pick["group"]] = pick["rank"]
            elif pick["kind"] == "ware":
                ranks["ware:" + pick["group"]] = pick["rank"]
            elif pick["kind"] == "hub_lead":
                ranks["hub_lead"] = pick["rank"]
            bought_this_isl.append(pick["id"])

        n_bought = len(bought_this_isl)
        total_purchases += n_bought
        # Cadence metrics (using realistic player playtime: blend of expert and first-time; report both!)
        # For purchase cadence target "every 8-10 minutes of play", compute using expert & mid-pace (~1.5x expert) & first-time
        min_per_buy_exp = round(isl_exp_min / n_bought, 1) if n_bought > 0 else round(isl_exp_min, 1)
        min_per_buy_first = round(isl_first_min / n_bought, 1) if n_bought > 0 else round(isl_first_min, 1)

        # Dead shard currency check: if 0 unlocked unbought sinks remain at end of island, shards are dead!
        remaining_unlocked = [
            s for s in sinks
            if s["id"] not in bought and s["unlock_island"] <= isl and (include_cosmetics or s["kind"] != "hub_flame")
        ]
        if n_bought == 0 and not remaining_unlocked:
            cur_dead_shard_min += isl_exp_min
        elif not remaining_unlocked and shards_wallet > 0:
            # Exhausted shop partway through this island
            frac_dead = min(1.0, shards_wallet / max(1.0, float(earned_s)))
            cur_dead_shard_min = isl_exp_min * frac_dead
        else:
            cur_dead_shard_min = 0.0
        max_dead_shard_min = max(max_dead_shard_min, cur_dead_shard_min)

        kit = kit_stats_from_ranks(ranks, isl, moves_cfg, upgrades_cfg)
        by_island.append({
            "island": isl,
            "exp_min": round(isl_exp_min, 1),
            "first_min": round(isl_first_min, 1),
            "shards_earned": earned_s,
            "cum_shards_earned": cum_shards_earned,
            "shards_spent": spent_this_isl,
            "cum_shards_spent": cum_shards_spent,
            "wallet_end": shards_wallet,
            "purchases": n_bought,
            "cum_purchases": total_purchases,
            "min_per_buy_exp": min_per_buy_exp,
            "min_per_buy_first": min_per_buy_first,
            "unlocked_remaining": len(remaining_unlocked),
            "dead_shard_min": round(cur_dead_shard_min, 1),
            "hearts": max_hearts,
            "embers_gain": e_gain,
            "halfs_gain": h_gain,
            "full_gain": f_gain,
            "heart_overflows": heart_overflows,
            "kit": kit,
            "bought_sample": bought_this_isl[:6],
        })

    return {
        "name": name,
        "total_exp_min": round(total_exp_min, 1),
        "total_first_min": round(total_first_min, 1),
        "total_shards_earned": cum_shards_earned,
        "total_shards_spent": cum_shards_spent,
        "final_wallet": shards_wallet,
        "total_purchases": total_purchases,
        "avg_min_per_buy_exp": round(total_exp_min / max(1, total_purchases), 1),
        "avg_min_per_buy_first": round(total_first_min / max(1, total_purchases), 1),
        "max_dead_shard_min": round(max_dead_shard_min, 1),
        "final_hearts": max_hearts,
        "hit_max_hearts_island": hit_max_hearts_island,
        "total_heart_overflows": heart_overflows,
        "by_island": by_island,
    }


def compute_enemy_ttk_table(
    samples_by_isl: Dict[int, List[Dict[str, Any]]],
    kits_by_isl: Dict[int, Dict[str, float]],
) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for isl in range(1, 9):
        items = samples_by_isl.get(isl, [])
        kit = kits_by_isl.get(isl, {"bolt_dps": 2.0, "combat_dps": 1.8})
        dps = max(0.5, float(kit["combat_dps"]))
        ttks: List[float] = []
        hps: List[float] = []
        by_kind: Dict[str, List[float]] = defaultdict(list)
        for it in items:
            hp = float(it["eff_hp"])
            sh = float(it["shield_hp"])
            # Realistic TTK = 0.45s opening/aim + shield break time (if shielded, 0.55s lure/throw) + hp / combat_dps
            ttk = 0.45 + (0.55 if sh > 0.0 else 0.0) + (hp / dps)
            ttks.append(ttk)
            hps.append(hp)
            by_kind[it["kind"]].append(ttk)
        if not ttks:
            continue
        in_band = sum(1 for t in ttks if 1.5 <= t <= 4.0)
        too_fast = sum(1 for t in ttks if t < 1.5)
        too_slow = sum(1 for t in ttks if t > 4.0)
        outliers = sorted(
            [(k, round(statistics.median(v), 2)) for k, v in by_kind.items() if statistics.median(v) < 1.5 or statistics.median(v) > 4.0],
            key=lambda x: x[1],
        )
        rows.append({
            "island": isl,
            "spawns": len(ttks),
            "unique_kinds": len(by_kind),
            "combat_dps": round(dps, 2),
            "hp_min": round(min(hps), 2),
            "hp_med": round(statistics.median(hps), 2),
            "hp_max": round(max(hps), 2),
            "ttk_min": round(min(ttks), 2),
            "ttk_med": round(statistics.median(ttks), 2),
            "ttk_max": round(max(ttks), 2),
            "pct_in_1_5_4_0": round(100.0 * in_band / len(ttks), 1),
            "too_fast": too_fast,
            "too_slow": too_slow,
            "outliers": outliers[:6],
        })
    return rows


def compute_boss_ttk_table(
    boss_records: List[Dict[str, Any]],
    kits_by_isl: Dict[int, Dict[str, float]],
    moves_cfg: Dict[str, Any],
    upgrades_cfg: Dict[str, Any],
    economy_cfg: Dict[str, Any],
) -> Dict[str, Any]:
    # Old baseline bolt damage per boss_check ISLAND_UPGRADES (0.35, 0.44, 0.54, 0.64, 0.74)
    old_bolt_table = [0.35, 0.44, 0.54, 0.64, 0.74]
    upg_bolt = next((u for u in upgrades_cfg.get("upgrades", []) if u.get("id") == "bolt_damage"), {})
    new_bolt_vals = [float((moves_cfg.get("moves") or {}).get("bolt", {}).get("damage", 0.35))] + [float(v) for v in (upg_bolt.get("values") or [])]

    rows: List[Dict[str, Any]] = []
    mini_in, mini_tot = 0, 0
    boss_in, boss_tot = 0, 0
    bolt_spec_fails: List[str] = []

    for b in sorted(boss_records, key=lambda x: (x["island"], x["tier"], x["id"])):
        isl = max(1, min(8, int(b["island"])))
        kit = kits_by_isl.get(isl, {"bolt_dmg": 0.44, "bolt_dps": 2.5, "combat_dps": 2.2})
        bc_rank = BOSS_CHECK_ISLAND_BOLT_RANK.get(isl, 0)
        old_bdmg = old_bolt_table[min(bc_rank, len(old_bolt_table) - 1)]
        new_bdmg = new_bolt_vals[min(bc_rank, len(new_bolt_vals) - 1)]
        # Estimate TTK: if we have a real measured bot_ttk, scale by hp_mult * (old_bdmg / new_bdmg)
        # (since boss fights are uptime-gated by punish windows, TTK scales smoothly with HP / bolt_dmg)
        meas = float(b["measured_ttk"])
        if meas > 0.0:
            est_ttk = meas * float(b["hp_mult"]) * (old_bdmg / max(0.05, new_bdmg))
        else:
            # Fallback model: ~28% damage uptime on bosses
            est_ttk = float(b["eff_hp"]) / max(0.35, float(kit["combat_dps"]) * 0.30)

        tier = b["tier"]
        lo, hi = (45.0, 75.0) if tier == "mini" else ((90.0, 150.0) if tier == "boss" else (110.0, 210.0))
        ok = lo <= est_ttk <= hi
        if tier == "mini":
            mini_tot += 1
            if ok:
                mini_in += 1
        elif tier == "boss":
            boss_tot += 1
            if ok:
                boss_in += 1

        # Check boss_specs hp_bolts_expected compatibility
        actual_bolts = float(b["eff_hp"]) / max(0.01, new_bdmg)
        sp_bolts = b["spec_bolts"]
        bolts_ok = True
        if isinstance(sp_bolts, list) and len(sp_bolts) >= 2:
            bolts_ok = float(sp_bolts[0]) <= actual_bolts <= float(sp_bolts[1])
        elif isinstance(sp_bolts, (int, float)) and float(sp_bolts) > 0:
            bolts_ok = float(sp_bolts) * 0.5 <= actual_bolts <= float(sp_bolts) * 2.0
        if not bolts_ok:
            bolt_spec_fails.append(f"{b['id']}(isl{isl}: {actual_bolts:.0f} vs {sp_bolts})")

        rows.append({
            "id": b["id"],
            "island": isl,
            "tier": tier,
            "base_hp": b["base_hp"],
            "eff_hp": b["eff_hp"],
            "hp_mult": b["hp_mult"],
            "shard_drop": b["shard_drop"],
            "heart": b["heart"],
            "est_ttk_s": round(est_ttk, 1),
            "target_band": [lo, hi],
            "in_band": ok,
            "actual_bolts": round(actual_bolts, 1),
            "spec_bolts": sp_bolts,
            "bolts_ok": bolts_ok,
        })

    mini_ttks = [r["est_ttk_s"] for r in rows if r["tier"] == "mini"]
    boss_ttks = [r["est_ttk_s"] for r in rows if r["tier"] == "boss"]
    return {
        "total_bosses": len(rows),
        "mini_count": mini_tot,
        "mini_in_45_75": mini_in,
        "mini_med_ttk": round(statistics.median(mini_ttks), 1) if mini_ttks else 0.0,
        "boss_count": boss_tot,
        "boss_in_90_150": boss_in,
        "boss_med_ttk": round(statistics.median(boss_ttks), 1) if boss_ttks else 0.0,
        "bolt_spec_fails": bolt_spec_fails,
        "rows": rows,
    }


def print_summary(rep: Dict[str, Any]) -> None:
    dec = rep["decisions"]
    st = rep["sink_totals"]
    print("=== LUXEL EPIC ECONOMY AUDIT ===")
    print(
        f"Rules: hearts {dec['hearts_start']}..{dec['hearts_max']} "
        f"| embers/heart={dec['ember_pieces_per_heart']} "
        f"| half_lanterns/heart={dec['half_lanterns_per_heart']} "
        f"| economy.json={'YES' if dec['has_economy_json'] else 'NO'}"
    )
    print(
        f"Sinks: {st['upgrade_count']} upgrades ({st['upgrade_ranks']} ranks) = {st['upgrades_shards']} sh "
        f"| wares ({st['wares_ranks']}) = {st['wares_shards']} sh "
        f"| hub lead = {st['hub_lead_shards']} sh | hub flames = {st['hub_flame_shards']} sh "
        f"| TOTAL = {st['all_sinks_shards']} sh"
    )
    if rep["double_heart_bosses"]:
        print(f"WARN double-heart-grant bosses ({len(rep['double_heart_bosses'])}): {', '.join(rep['double_heart_bosses'][:10])}")

    print("\n--- 1. PER-ISLAND INCOME (Critical vs Optional) ---")
    print(f"{'Isl':>3} {'Rooms':>7} {'CritSh':>7} {'OptSh':>7} {'TotSh':>7} {'Chst':>6} {'Enm':>5} {'Bos':>5} {'Q/T/D':>6} {'Emb':>4} {'Hlf':>4} {'Ful':>4} {'Ld':>3} {'Pn':>3} {'Mt':>3}")
    inc = rep["income_by_island"]
    tot_c = tot_o = tot_e = tot_h = tot_f = tot_l = tot_p = tot_m = 0
    for isl in range(0, 9):
        c, o = inc[isl]["critical"], inc[isl]["optional"]
        cs, os_ = c["total_shards"], o["total_shards"]
        tot_c += cs; tot_o += os_
        emb = c["ember_pieces"] + o["ember_pieces"]; tot_e += emb
        hlf = c["half_lanterns"] + o["half_lanterns"]; tot_h += hlf
        ful = c["full_hearts"] + o["full_hearts"]; tot_f += ful
        ld = c["lead"] + o["lead"]; tot_l += ld
        pn = c["panes"] + o["panes"]; tot_p += pn
        mt = c["moths"] + o["moths"]; tot_m += mt
        qtd = c["quest_shards"] + o["quest_shards"] + c["trial_shards"] + o["trial_shards"] + o["discovery_shards"] + o["event_shards"] + c["event_shards"] + o["hub_shards"]
        lbl = "HUB" if isl == 0 else f"I{isl}"
        print(
            f"{lbl:>3} {c['rooms']:3d}+{o['rooms']:<3d} {cs:7d} {os_:7d} {cs+os_:7d} "
            f"{c['chest_shards']+o['chest_shards']:6d} {c['enemy_shards']+o['enemy_shards']:5d} "
            f"{c['boss_shards']+o['boss_shards']:5d} {qtd:6d} {emb:4d} {hlf:4d} {ful:4d} {ld:3d} {pn:3d} {mt:3d}"
        )
    print(f"{'ALL':>3} {'':>7} {tot_c:7d} {tot_o:7d} {tot_c+tot_o:7d} {'':>6} {'':>5} {'':>5} {'':>6} {tot_e:4d} {tot_h:4d} {tot_f:4d} {tot_l:3d} {tot_p:3d} {tot_m:3d}")

    print("\n--- 2. PLAYER PROFILES (Shards, Purchase Cadence, Dead Currency, Hearts Curve) ---")
    for pname in ("critical", "normal", "completionist"):
        pr = rep["profiles"][pname]
        print(
            f"\n[{pname.upper()}] earned={pr['total_shards_earned']} spent={pr['total_shards_spent']} "
            f"left={pr['final_wallet']} buys={pr['total_purchases']} "
            f"avg_cadence={pr['avg_min_per_buy_exp']}m(exp)/{pr['avg_min_per_buy_first']}m(1st) "
            f"max_dead={pr['max_dead_shard_min']}m | hearts={pr['final_hearts']}/12 "
            f"(cap@I{pr['hit_max_hearts_island'] or '-'}, ovf={pr['total_heart_overflows']})"
        )
        print(f"  {'Isl':>3} {'ExpM':>5} {'Earn':>6} {'Spent':>6} {'Left':>6} {'Buys':>4} {'m/Buy':>6} {'DeadM':>6} {'Hrt':>4} {'Ovf':>3} {'BoltDPS':>7} {'CmbDPS':>6}")
        for r in pr["by_island"]:
            k = r["kit"]
            print(
                f"  I{r['island']:<2d} {r['exp_min']:5.1f} {r['shards_earned']:6d} {r['shards_spent']:6d} "
                f"{r['wallet_end']:6d} {r['purchases']:4d} {r['min_per_buy_exp']:5.1f}m {r['dead_shard_min']:5.1f}m "
                f"{r['hearts']:4d} {r['heart_overflows']:3d} {k['bolt_dps']:7.2f} {k['combat_dps']:6.2f}"
            )

    print("\n--- 3. REGULAR ENEMY HP & TTK (Target: 1.5-4.0 s at Normal Expected Kit) ---")
    print(f"  {'Isl':>3} {'Spwns':>5} {'Knds':>4} {'CmbDPS':>6} {'HP(min/med/max)':>18} {'TTK(min/med/max)':>18} {'%InBand':>7} {'Fast':>4} {'Slow':>4} Outliers")
    for r in rep["enemy_ttk_by_island"]:
        outs = ", ".join(f"{k}:{t}s" for k, t in r["outliers"][:4])
        print(
            f"  I{r['island']:<2d} {r['spawns']:5d} {r['unique_kinds']:4d} {r['combat_dps']:6.2f} "
            f"{r['hp_min']:5.1f}/{r['hp_med']:5.1f}/{r['hp_max']:5.1f}  "
            f"{r['ttk_min']:5.2f}/{r['ttk_med']:5.2f}/{r['ttk_max']:5.2f}s  "
            f"{r['pct_in_1_5_4_0']:6.1f}% {r['too_fast']:4d} {r['too_slow']:4d} {outs}"
        )

    bt = rep["boss_ttk"]
    print("\n--- 4. BOSS TTK & HP_BOLTS CHECK (Target: Mini 45-75s, Major 90-150s) ---")
    print(
        f"  Bosses={bt['total_bosses']} | Mini in 45-75s: {bt['mini_in_45_75']}/{bt['mini_count']} (med {bt['mini_med_ttk']}s) "
        f"| Major in 90-150s: {bt['boss_in_90_150']}/{bt['boss_count']} (med {bt['boss_med_ttk']}s) "
        f"| hp_bolts_spec fails: {len(bt['bolt_spec_fails'])}"
    )
    if bt["bolt_spec_fails"]:
        print("  Spec bolt fails:", ", ".join(bt["bolt_spec_fails"][:12]))
    # Per-island boss summary
    by_i: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
    for br in bt["rows"]:
        by_i[br["island"]].append(br)
    for isl in range(1, 9):
        brs = by_i.get(isl, [])
        minis = [r["est_ttk_s"] for r in brs if r["tier"] == "mini"]
        majs = [r["est_ttk_s"] for r in brs if r["tier"] == "boss"]
        m_str = f"{min(minis):.0f}-{max(minis):.0f}s (med {statistics.median(minis):.0f}s)" if minis else "-"
        b_str = f"{min(majs):.0f}-{max(majs):.0f}s (med {statistics.median(majs):.0f}s)" if majs else "-"
        print(f"  I{isl}: minis({len(minis)})={m_str:24s} | majors({len(majs)})={b_str}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Luxel Epic economy analyzer")
    ap.add_argument("--summary", action="store_true", help="Print full economy summary")
    ap.add_argument("--island", type=int, default=0, help="Filter boss/enemy detail to one island")
    ap.add_argument("--json", type=str, default="", help="Write JSON report to PATH (or - for stdout)")
    args = ap.parse_args()

    rep = collect_world_economy()
    if args.json == "-":
        print(json.dumps(rep, indent=2))
        return 0
    if args.json:
        out_p = Path(args.json)
        out_p.parent.mkdir(parents=True, exist_ok=True)
        out_p.write_text(json.dumps(rep, indent=2), encoding="utf-8")

    if args.island > 0:
        isl = args.island
        print(f"=== ISLAND {isl} DETAIL ===")
        print("Income:", json.dumps(rep["income_by_island"][isl], indent=2))
        for br in rep["boss_ttk"]["rows"]:
            if br["island"] == isl:
                print(f"  BOSS {br['id']:22s} [{br['tier']:9s}] hp={br['eff_hp']:5.1f} (x{br['hp_mult']:.2f}) ttk={br['est_ttk_s']:5.1f}s bolts={br['actual_bolts']:5.1f} spec={br['spec_bolts']} heart={br['heart']}")
        return 0

    print_summary(rep)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
