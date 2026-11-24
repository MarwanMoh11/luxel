#!/usr/bin/env python3
"""Stdlib BFS verifier for Luxel Epic island bible graphs (docs/fullgame/epic/bibles/islandN_graph.json).

Checks:
  1. JSON schema & referential integrity (all exit targets exist, valid beats/kinds/expert_s).
  2. Full state-space BFS over (room, keys, flags, moves) with adversarial key-spending order
     exploration to prove zero softlocks/deadlocks under any key order.
  3. Reachability with island-native moves vs full 8-island kit (backtrack secrets).
  4. Undirected cyclomatic number (E - V + C) globally and per dungeon (must be >= 2 for A/B/grand).
  5. Designer minutes (critical path + total) and R1 first-time calibrated minutes.

Usage:
  python3 tools/epic/bible_graph_check.py docs/fullgame/epic/bibles/island1_graph.json [--goal great_lamp_1]
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import defaultdict, deque
from pathlib import Path

ALL_GAME_MOVES = ("bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare")
DEFAULT_MULTS = {
    "default": 2.7,
    "puzzle": 3.2,
    "overworld": 2.8,
    "hub": 2.8,
    "story": 2.8,
    "reward": 2.7,
    "trial": 2.7,
    "secret": 2.7,
    "setpiece": 2.7,
    "boss": 2.6,
    "combat": 2.2,
    "traversal": 2.1,
}


def load_multipliers() -> dict[str, float]:
    mults = dict(DEFAULT_MULTS)
    cal_path = Path(__file__).resolve().parent / "calibration.json"
    if cal_path.exists():
        try:
            data = json.loads(cal_path.read_text(encoding="utf-8"))
            for k, v in data.get("r1_first_time_multipliers", {}).items():
                mults[str(k)] = float(v)
        except Exception:
            pass
    return mults


def parse_give(token: str) -> tuple[str, str]:
    if ":" in token:
        kind, val = token.split(":", 1)
        return kind.strip().lower(), val.strip()
    return "flag", token.strip()


def edge_passable(
    ex: dict,
    moves: frozenset[str],
    flags: frozenset[str],
    keys: frozenset[str],
    opened_consumables: frozenset[tuple[str, str]],
    src: str,
) -> tuple[bool, str | None]:
    for m in ex.get("needs_moves", []):
        if m not in moves:
            return False, None
    for f in ex.get("needs_flags", []):
        if f not in flags and f not in keys:
            return False, None
    lock = str(ex.get("lock", ""))
    if lock.startswith("consumable_key:"):
        key_pool = lock.split(":", 1)[1]
        edge_id = (src, str(ex["to"]))
        if edge_id in opened_consumables or (str(ex["to"]), src) in opened_consumables:
            return True, None
        return True, key_pool
    return True, None


def run_reachability_bfs(
    regions: dict[str, dict],
    start: str,
    extra_moves: set[str],
) -> tuple[set[str], set[str], set[str], set[str]]:
    """Monotonic fixed-point BFS collecting all reachable regions, moves, flags, and keys."""
    moves = set(extra_moves)
    flags: set[str] = set()
    keys: set[str] = set()
    visited: set[str] = set()

    changed = True
    while changed:
        changed = False
        q: deque[str] = deque([start])
        seen_pass: set[str] = {start}
        while q:
            cur = q.popleft()
            if cur not in visited:
                visited.add(cur)
                changed = True
            for g in regions[cur].get("gives", []):
                gk, gv = parse_give(str(g))
                if gk == "move" and gv not in moves:
                    moves.add(gv)
                    changed = True
                elif gk == "key":
                    if gv not in keys:
                        keys.add(gv)
                        changed = True
                    if gv not in flags:
                        flags.add(gv)
                        changed = True
                elif gk in ("flag", "item", "pane", "moth"):
                    if gv not in flags:
                        flags.add(gv)
                        changed = True
            for ex in regions[cur].get("exits", []):
                ok, _ = edge_passable(ex, frozenset(moves), frozenset(flags), frozenset(keys), frozenset(), cur)
                nxt = str(ex["to"])
                if ok and nxt not in seen_pass and nxt in regions:
                    seen_pass.add(nxt)
                    q.append(nxt)
    return visited, moves, flags, keys


def check_key_order_deadlocks(
    regions: dict[str, dict],
    start: str,
    goal_flag: str,
) -> tuple[int, list[str], int]:
    """Explore all reachable (room, collected_key_sources, opened_consumable_locks, flags, moves) states
    for consumable-key doors and verify every reachable state still has a path to goal_flag."""
    consumable_edges: list[tuple[str, str, str]] = []
    for rid, r in regions.items():
        for ex in r.get("exits", []):
            lock = str(ex.get("lock", ""))
            if lock.startswith("consumable_key:"):
                consumable_edges.append((rid, str(ex["to"]), lock.split(":", 1)[1]))

    # Fast exact state-space BFS over (room, key_balances, opened_edges, flags_subset)
    # Collects every move/flag/key reachable in the current connected component before branching on consumable locks.
    def expand_free(
        start_room: str,
        init_moves: frozenset[str],
        init_flags: frozenset[str],
        init_key_sources: frozenset[tuple[str, str]],
        opened: frozenset[tuple[str, str]],
    ) -> tuple[frozenset[str], frozenset[str], frozenset[str], frozenset[tuple[str, str]], list[tuple[str, str, str]]]:
        moves = set(init_moves)
        flags = set(init_flags)
        ks = set(init_key_sources)
        changed = True
        comp: set[str] = set()
        frontier_locks: list[tuple[str, str, str]] = []
        while changed:
            changed = False
            comp = {start_room}
            q: deque[str] = deque([start_room])
            frontier_locks = []
            seen_fl: set[tuple[str, str]] = set()
            while q:
                cur = q.popleft()
                for g in regions[cur].get("gives", []):
                    gk, gv = parse_give(str(g))
                    if gk == "move" and gv not in moves:
                        moves.add(gv)
                        changed = True
                    elif gk == "consumable_key":
                        src_tok = (cur, gv)
                        if src_tok not in ks:
                            ks.add(src_tok)
                            changed = True
                    elif gk in ("key", "flag", "item", "pane", "moth"):
                        if gv not in flags:
                            flags.add(gv)
                            changed = True
                for ex in regions[cur].get("exits", []):
                    nxt = str(ex["to"])
                    ok, pool = edge_passable(ex, frozenset(moves), frozenset(flags), frozenset(flags), opened, cur)
                    if not ok:
                        continue
                    if pool is not None:
                        ek = (cur, nxt)
                        if ek not in seen_fl:
                            seen_fl.add(ek)
                            frontier_locks.append((cur, nxt, pool))
                    elif nxt not in comp:
                        comp.add(nxt)
                        q.append(nxt)
        return frozenset(comp), frozenset(moves), frozenset(flags), frozenset(ks), frontier_locks

    # State = (opened_consumable_edges)
    # Wait: also test starting from every one-way trap check!
    init_comp, init_m, init_f, init_ks, init_fl = expand_free(start, frozenset(), frozenset(), frozenset(), frozenset())
    state_adj: dict[frozenset[tuple[str, str]], list[frozenset[tuple[str, str]]]] = {}
    state_flags: dict[frozenset[tuple[str, str]], frozenset[str]] = {}
    q_s: deque[frozenset[tuple[str, str]]] = deque([frozenset()])
    seen_s: set[frozenset[tuple[str, str]]] = {frozenset()}

    while q_s:
        opened = q_s.popleft()
        comp, mv, fl, ks, flist = expand_free(start, frozenset(), frozenset(), frozenset(), opened)
        state_flags[opened] = fl
        # Compute available keys per pool
        avail: dict[str, int] = defaultdict(int)
        for _, pool in ks:
            avail[pool] += 1
        for src, dst in opened:
            for ex in regions[src].get("exits", []):
                if str(ex["to"]) == dst and str(ex.get("lock", "")).startswith("consumable_key:"):
                    avail[str(ex["lock"]).split(":", 1)[1]] -= 1
                    break
        nxts: list[frozenset[tuple[str, str]]] = []
        for src, dst, pool in flist:
            if avail[pool] > 0:
                nxt_opened = opened | {(src, dst)}
                nxts.append(nxt_opened)
                if nxt_opened not in seen_s:
                    seen_s.add(nxt_opened)
                    q_s.append(nxt_opened)
        state_adj[opened] = nxts

    # Reverse BFS from all states that contain goal_flag
    winning = {s for s, fl in state_flags.items() if goal_flag in fl}
    rev: dict[frozenset[tuple[str, str]], list[frozenset[tuple[str, str]]]] = defaultdict(list)
    for s, nxts in state_adj.items():
        for n in nxts:
            rev[n].append(s)
    can_win = set(winning)
    rq: deque[frozenset[tuple[str, str]]] = deque(winning)
    while rq:
        cur = rq.popleft()
        for prev in rev[cur]:
            if prev not in can_win:
                can_win.add(prev)
                rq.append(prev)

    deadlocked = [s for s in seen_s if s not in can_win]
    issues: list[str] = []
    for ds in deadlocked[:5]:
        issues.append(f"key-order deadlock with opened={sorted(ds)}")

    # Also check one-way traps: from every reachable region, verify a path exists to goal or back to start
    # (in the final unlocked graph)
    final_vis, final_m, final_f, final_k = run_reachability_bfs(regions, start, set())
    adj_final: dict[str, list[str]] = defaultdict(list)
    rev_final: dict[str, list[str]] = defaultdict(list)
    for rid in final_vis:
        for ex in regions[rid].get("exits", []):
            ok, _ = edge_passable(ex, frozenset(final_m), frozenset(final_f), frozenset(final_k), frozenset(), rid)
            nxt = str(ex["to"])
            if ok and nxt in final_vis:
                adj_final[rid].append(nxt)
                rev_final[nxt].append(rid)
    can_return = {start}
    qret: deque[str] = deque([start])
    while qret:
        c = qret.popleft()
        for p in rev_final[c]:
            if p not in can_return:
                can_return.add(p)
                qret.append(p)
    trapped = sorted(final_vis - can_return)
    for t in trapped:
        issues.append(f"one-way trap: cannot return to {start} from {t}")

    return len(deadlocked) + len(trapped), issues, len(seen_s)


def compute_cycles(regions: dict[str, dict], subset: set[str] | None = None) -> tuple[int, int, int, int]:
    nodes = subset if subset is not None else set(regions.keys())
    edges: set[tuple[str, str]] = set()
    adj: dict[str, set[str]] = defaultdict(set)
    for rid in nodes:
        for ex in regions[rid].get("exits", []):
            nxt = str(ex["to"])
            if nxt in nodes and nxt != rid:
                a, b = (rid, nxt) if rid < nxt else (nxt, rid)
                edges.add((a, b))
                adj[rid].add(nxt)
                adj[nxt].add(rid)
    seen: set[str] = set()
    comps = 0
    for n in nodes:
        if n in seen:
            continue
        comps += 1
        dq: deque[str] = deque([n])
        seen.add(n)
        while dq:
            u = dq.popleft()
            for v in adj[u]:
                if v not in seen:
                    seen.add(v)
                    dq.append(v)
    v_cnt = len(nodes)
    e_cnt = len(edges)
    return e_cnt - v_cnt + comps, v_cnt, e_cnt, comps


def compute_critical_path_regions(
    regions: dict[str, dict],
    start: str,
    goal_flag: str,
) -> set[str]:
    """Identify the set of regions required to acquire goal_flag (backward dependency closure
    of required flags/moves + shortest connecting path from start)."""
    # Find providers for every flag/move/key
    providers: dict[str, list[str]] = defaultdict(list)
    for rid, r in regions.items():
        for g in r.get("gives", []):
            gk, gv = parse_give(str(g))
            providers[gv].append(rid)

    # First get all regions reachable with native moves
    vis_native, _, _, _ = run_reachability_bfs(regions, start, set())

    # Use explicit critical flag if authored, else derive minimal closure
    if any("critical" in r for r in regions.values()):
        return {rid for rid, r in regions.items() if r.get("critical", False)}

    # Derive via iterative necessity: find shortest-time path to each needed provider
    # Build prerequisite tree from goal_flag
    needed_regions: set[str] = {start}
    needed_tokens: deque[str] = deque([goal_flag])
    seen_toks: set[str] = {goal_flag}
    while needed_tokens:
        tok = needed_tokens.popleft()
        provs = [p for p in providers.get(tok, []) if p in vis_native]
        if not provs:
            continue
        # Pick cheapest provider
        prov = min(provs, key=lambda r: float(regions[r].get("expert_s", 45)))
        needed_regions.add(prov)
        # Find minimum-lock path from start to prov in vis_native
        parent: dict[str, tuple[str, dict] | None] = {start: None}
        q: deque[str] = deque([start])
        while q and prov not in parent:
            u = q.popleft()
            for ex in regions[u].get("exits", []):
                v = str(ex["to"])
                if v in vis_native and v not in parent:
                    parent[v] = (u, ex)
                    q.append(v)
        cur = prov
        while cur in parent and parent[cur] is not None:
            prev, ex = parent[cur]  # type: ignore[misc]
            needed_regions.add(prev)
            for req in list(ex.get("needs_moves", [])) + list(ex.get("needs_flags", [])):
                if req not in seen_toks:
                    seen_toks.add(req)
                    needed_tokens.append(req)
            cur = prev
    return needed_regions


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("graph_json", type=Path)
    ap.add_argument("--start", default="overworld")
    ap.add_argument("--goal", default="")
    args = ap.parse_args()

    raw = json.loads(args.graph_json.read_text(encoding="utf-8"))
    reg_list = raw.get("regions", [])
    if not reg_list:
        print("BIBLE GRAPH CHECK FAIL: empty regions list")
        return 1

    regions: dict[str, dict] = {}
    errors: list[str] = []
    for r in reg_list:
        rid = str(r.get("id", "")).strip()
        if not rid:
            errors.append("region missing id")
            continue
        if rid in regions:
            errors.append(f"duplicate region id: {rid}")
        regions[rid] = r
        if float(r.get("expert_s", 0)) <= 0:
            errors.append(f"{rid}: expert_s must be > 0")

    for rid, r in regions.items():
        for ex in r.get("exits", []):
            to_id = str(ex.get("to", ""))
            if to_id not in regions:
                errors.append(f"{rid}: exit to unknown region '{to_id}'")

    start = args.start if args.start in regions else reg_list[0]["id"]
    goal_flag = args.goal
    if not goal_flag:
        # Auto-detect great_lamp_N
        for r in reg_list:
            for g in r.get("gives", []):
                _, gv = parse_give(str(g))
                if gv.startswith("great_lamp_"):
                    goal_flag = gv
                    break
            if goal_flag:
                break
    if not goal_flag:
        goal_flag = "great_lamp_1"

    vis_native, moves_native, flags_native, keys_native = run_reachability_bfs(regions, start, set())
    vis_full, moves_full, flags_full, _ = run_reachability_bfs(regions, start, set(ALL_GAME_MOVES))

    unreach_full = sorted(set(regions.keys()) - vis_full)
    backtrack_only = sorted(vis_full - vis_native)
    if unreach_full:
        errors.append(f"unreachable regions even with full game kit: {unreach_full}")
    if goal_flag not in flags_native:
        errors.append(f"goal flag '{goal_flag}' not reachable with island-native moves")

    deadlock_cnt, dl_issues, states_checked = check_key_order_deadlocks(regions, start, goal_flag)
    if deadlock_cnt > 0:
        errors.extend(dl_issues)

    # Check mutually exclusive choice branches if present (e.g. manor_verdict_right vs manor_verdict_wrong)
    choice_groups: list[tuple[str, str]] = []
    if "manor_verdict_right" in flags_native and "manor_verdict_wrong" in flags_native:
        choice_groups.append(("manor_verdict_right", "manor_verdict_wrong"))
    for a_flag, b_flag in choice_groups:
        for drop_flag, keep_flag in ((b_flag, a_flag), (a_flag, b_flag)):
            mod = json.loads(json.dumps(regions))
            for r in mod.values():
                r["gives"] = [g for g in r.get("gives", []) if parse_give(str(g))[1] != drop_flag]
            v_ch, _, f_ch, _ = run_reachability_bfs(mod, start, set())
            if goal_flag not in f_ch or len(v_ch) != len(vis_native):
                errors.append(f"exclusive choice '{keep_flag}' only reaches {len(v_ch)}/{len(vis_native)} or misses {goal_flag}")

    # Cycles globally and per dungeon
    total_cyc, tv, te, tc = compute_cycles(regions)
    by_dungeon: dict[str, set[str]] = defaultdict(set)
    for rid, r in regions.items():
        by_dungeon[str(r.get("dungeon", "overworld"))].add(rid)

    dungeon_stats: dict[str, dict] = {}
    mults = load_multipliers()
    for dname, dset in sorted(by_dungeon.items()):
        cyc, dv, de, dc = compute_cycles(regions, dset)
        exp_s = sum(float(regions[x]["expert_s"]) for x in dset)
        ft_s = sum(float(regions[x]["expert_s"]) * mults.get(str(regions[x].get("kind", "default")), mults["default"]) for x in dset)
        dungeon_stats[dname] = {
            "rooms": dv,
            "edges": de,
            "components": dc,
            "cycles": cyc,
            "expert_min": exp_s / 60.0,
            "first_time_min": ft_s / 60.0,
        }
        # Major dungeons (not caves/setpiece/superboss/overworld) must have cycles >= 2
        if dname not in ("overworld", "caves", "superboss", "setpiece", "great_toll", "toll") and dv >= 8:
            if cyc < 2:
                errors.append(f"dungeon '{dname}' has only {cyc} cycle(s) (need >= 2)")

    crit_set = compute_critical_path_regions(regions, start, goal_flag)
    crit_exp_s = sum(float(regions[x]["expert_s"]) for x in crit_set)
    crit_ft_s = sum(float(regions[x]["expert_s"]) * mults.get(str(regions[x].get("kind", "default")), mults["default"]) for x in crit_set)
    tot_exp_s = sum(float(r["expert_s"]) for r in regions.values())
    tot_ft_s = sum(float(r["expert_s"]) * mults.get(str(r.get("kind", "default")), mults["default"]) for r in regions.values())
    med_s = statistics.median(float(r["expert_s"]) for r in regions.values())

    if crit_exp_s / 60.0 < 32.0:
        errors.append(f"critical path {crit_exp_s / 60.0:.1f} designer min < 32.0 floor")
    if tot_exp_s / 60.0 < 45.0:
        errors.append(f"total {tot_exp_s / 60.0:.1f} designer min < 45.0 floor")
    if not (55 <= len(regions) <= 60):
        errors.append(f"region count {len(regions)} outside 55-60 target")

    print(f"=== BIBLE GRAPH CHECK: {args.graph_json.name} ===")
    print(f"Regions: {len(regions)} | Reachable (native): {len(vis_native)}/{len(regions)} | Reachable (full kit): {len(vis_full)}/{len(regions)}")
    if backtrack_only:
        print(f"Backtrack-gated (later moves): {backtrack_only}")
    print(f"Goal '{goal_flag}': {'REACHABLE' if goal_flag in flags_native else 'UNREACHABLE'} | Native moves: {sorted(moves_native)}")
    print(f"Deadlocks (all key orders, {states_checked} states): {deadlock_cnt}")
    print(f"Global graph: V={tv} E={te} C={tc} cycles={total_cyc}")
    print("Per-dungeon breakdown:")
    for dname, st in dungeon_stats.items():
        print(
            f"  - {dname:12s}: {st['rooms']:2d} rooms | cycles={st['cycles']:2d} | "
            f"expert={st['expert_min']:5.1f}m | first_time={st['first_time_min']:5.1f}m"
        )
    print(
        f"Minutes: crit_path={crit_exp_s / 60.0:.1f}m expert ({crit_ft_s / 60.0:.1f}m first-time, {len(crit_set)} rooms) | "
        f"total={tot_exp_s / 60.0:.1f}m expert ({tot_ft_s / 60.0:.1f}m first-time) | median_room={med_s:.0f}s"
    )
    if errors:
        print("BIBLE GRAPH CHECK FAIL:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("BIBLE GRAPH CHECK PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
