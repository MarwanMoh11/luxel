#!/usr/bin/env python3
"""Read back the hand edits made in the level editor (luxel/editor) and check nothing overwrote them.

  python3 tools/epic/edits.py              what changed in every edited room, notes, verdicts (also docs/level_edits/SUMMARY.md)
  python3 tools/epic/edits.py 1:belfry_r6  one room, with the changed part of the map drawn before/after
  python3 tools/epic/edits.py verify       rooms whose files no longer match the hand-edited version (exit 1 if any)
  python3 tools/epic/edits.py keep ROOM    accept the current files as the hand-edited version (after building on them)
  python3 tools/epic/edits.py done ID "reply"   answer a note; the editor shows it in green
"""
from __future__ import annotations

import collections
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

ROOT = Path(__file__).resolve().parents[2]
E = ROOT / "docs" / "level_edits"
LEGEND = {".": "ground", "#": "wall", ",": "path", "~": "water", "O": "pit", "_": "void", "B": "bramble", "C": "cracked",
          "T": "tide", "P": "phantom", "+": "bridge", "G": "glass", "M": "mirror", "D": "carpet", "S": "stairs",
          "H": "grate", "R": "rail", "F": "foliage", " ": "void"}


def rooms() -> List[str]:
    return sorted(p.name[:-8] for p in (E / "base").glob("*.map.txt")) if (E / "base").is_dir() else []


def key(fk: str) -> str:
    i, r = fk.split("_", 1)
    return f"{i}:{r}"


def live(fk: str, ext: str) -> Path:
    i, r = fk.split("_", 1)
    return ROOT / "luxel" / "islands" / i / f"{r}.{ext}"


def grid(text: str) -> List[List[str]]:
    lines = text.replace("\r\n", "\n").split("\n")
    legend, rows, on = dict(LEGEND), [], "MAP" not in [x.strip() for x in lines]
    for ln in lines:
        s = ln.strip()
        if not on:
            if s == "MAP":
                on = True
            elif s.startswith("LEGEND "):
                p = s[7:].split()
                legend[p[0]] = p[1].lower()
            continue
        if not s or s in ("END", "ENDMAP"):
            if rows:
                break
            continue
        rows.append(ln)
    w = max((len(r) for r in rows), default=0)
    return [[legend.get(c, "void") for c in r.ljust(w, "_")] for r in rows]


def pos(d: Dict[str, Any]) -> Any:
    return d.get("pos") or (d.get("rect") or [None, None])[:2]


def diff_props(a: Dict[str, Any], b: Dict[str, Any]) -> str:
    out = []
    for k in sorted(set(a) | set(b)):
        if k in ("pos", "id", "rect") or a.get(k) == b.get(k):
            continue
        if isinstance(a.get(k), dict) and isinstance(b.get(k), dict):
            out.append(diff_props(a[k], b[k]))
        else:
            out.append(f"{k}: {json.dumps(a.get(k))} -> {json.dumps(b.get(k))}")
    return "; ".join(x for x in out if x)


def by_id(a: List[Dict[str, Any]], b: List[Dict[str, Any]], what: str) -> List[str]:
    A, B, out = {x.get("id"): x for x in a}, {x.get("id"): x for x in b}, []
    for i, x in B.items():
        if i not in A:
            pr = {k: v for k, v in x.items() if k not in ("id", "kind", "pos")}
            out.append(f"ADDED {what} {x.get('kind')} `{i}` at {pos(x)} {json.dumps(pr)[:160]}")
            continue
        o = A[i]
        if pos(o) != pos(x):
            out.append(f"MOVED {x.get('kind')} `{i}` {pos(o)} -> {pos(x)}")
        d = diff_props(o, x)
        if d:
            out.append(f"SET {x.get('kind')} `{i}` {d}")
    out += [f"REMOVED {what} {o.get('kind')} `{i}` (was at {pos(o)})" for i, o in A.items() if i not in B]
    return out


def unnamed(a: List[Dict[str, Any]], b: List[Dict[str, Any]], what: str, name: str) -> List[str]:
    """Scenery and floor art have no ids: match equal ones away, then pair leftovers of the same kind by distance."""
    enc = lambda x: json.dumps(x, sort_keys=True)
    ca, cb = collections.Counter(map(enc, a)), collections.Counter(map(enc, b))
    gone, new = [json.loads(x) for x in (ca - cb).elements()], [json.loads(x) for x in (cb - ca).elements()]
    out = []
    for n in new:
        same = [g for g in gone if g.get(name) == n.get(name) and None not in (pos(g) + pos(n))]
        if same:
            o = min(same, key=lambda g: sum((float(p) - float(q)) ** 2 for p, q in zip(pos(g), pos(n))))
            gone.remove(o)
            t = [f"{pos(o)} -> {pos(n)}"] if pos(o) != pos(n) else []
            t += [diff_props(o, n)] if diff_props(o, n) else []
            out.append(f"MOVED {what} {n.get(name)} {', '.join(t)}")
        else:
            out.append(f"ADDED {what} {n.get(name)} at {pos(n)}")
    return out + [f"REMOVED {what} {g.get(name)} (was at {pos(g)})" for g in gone]


def room_report(fk: str, draw: bool = False) -> Tuple[List[str], List[str]]:
    a, b = json.loads((E / "base" / f"{fk}.json").read_text()), json.loads(live(fk, "json").read_text())
    ga, gb = grid((E / "base" / f"{fk}.map.txt").read_text()), grid(live(fk, "map").read_text())
    out: List[str] = []
    cells = [(x, y) for y in range(min(len(ga), len(gb))) for x in range(min(len(ga[y]), len(gb[y]))) if ga[y][x] != gb[y][x]]
    if cells:
        c = collections.Counter(f"{ga[y][x]}->{gb[y][x]}" for x, y in cells)
        xs, ys = [x for x, _ in cells], [y for _, y in cells]
        x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
        out.append(f"TILES {len(cells)} changed in tiles ({x0},{y0})-({x1},{y1}): " + ", ".join(f"{k} x{v}" for k, v in c.most_common()))
        if draw:
            rev = {v: k for k, v in reversed(list(LEGEND.items()))}
            for label, g in (("before", ga), ("after", gb)):
                out.append(f"  {label}:")
                for y in range(max(0, y0 - 2), min(len(g), y1 + 3)):
                    out.append("    " + "".join(rev.get(t, "?") for t in g[y][max(0, x0 - 4):x1 + 5]))
    out += by_id(a.get("interactables", []), b.get("interactables", []), "object")
    out += by_id(a.get("enemies", []), b.get("enemies", []), "enemy")
    out += unnamed(a.get("scenery", []), b.get("scenery", []), "scenery", "prop")
    out += unnamed(a.get("decor", []), b.get("decor", []), "floor art", "kind")
    for k in sorted(set(a) | set(b)):
        if k not in ("interactables", "enemies", "scenery", "decor") and a.get(k) != b.get(k):
            out.append(f"OTHER {k} changed")
    warn: List[str] = []
    ids = {x.get("id") for x in b.get("interactables", []) + b.get("enemies", []) + b.get("exits", [])}
    old = {x.get("id") for x in a.get("interactables", []) + a.get("enemies", [])}
    for gone in sorted(x for x in old - ids if x):
        if f'"{gone}"' in json.dumps({k: v for k, v in b.items()}):
            warn.append(f"`{gone}` was removed but the room still mentions it (solution, events, layers or a door)")
    if out and isinstance(b.get("design"), dict) and b["design"].get("solution"):
        warn.append(f"re-check the recorded solution: room_check -- {key(fk)} (positions in it may be stale)")
    return out, warn


def wishes() -> Dict[str, List[str]]:
    """Plain-language requests per room (the AI brush), and whether the result was kept."""
    out: Dict[str, List[List[Any]]] = collections.defaultdict(list)
    if (E / "log.jsonl").exists():
        for ln in (E / "log.jsonl").read_text().splitlines():
            try:
                d = json.loads(ln)
            except ValueError:
                continue
            if d.get("op") == "magic":
                out[d["room"]].append([d, True])
            elif d.get("op") == "undo" and d.get("undid") == "magic" and out[d["room"]]:
                for w in reversed(out[d["room"]]):
                    if w[1]:
                        w[1] = False
                        break
    return {k: [f"WISH {'kept' if ok else 'UNDONE'}: \"{d['ask']}\" in tiles {d.get('area')} -> {d.get('say', '')}" for d, ok in v] for k, v in out.items()}


def summary(only: str = "") -> int:
    notes = json.loads((E / "notes.json").read_text()) if (E / "notes.json").exists() else []
    verdicts = json.loads((E / "verdicts.json").read_text()) if (E / "verdicts.json").exists() else {}
    checks = json.loads((E / "checks.json").read_text()) if (E / "checks.json").exists() else {}
    asked = wishes()
    keys = sorted(set(asked) | {key(f) for f in rooms()} | {n["room"] for n in notes} | set(verdicts) | set(checks))
    if only:
        keys = [k for k in keys if k == only] or [only]
    L: List[str] = []
    for k in keys:
        fk = k.replace(":", "_", 1)
        v = verdicts.get(k, {}).get("verdict", "")
        L.append(f"## {k}" + {"love": "  [LOVE IT: keep as is]", "fix": "  [NEEDS WORK]"}.get(v, ""))
        if (E / "base" / f"{fk}.json").exists():
            ch, warn = room_report(fk, bool(only))
            L += [f"- {c}" if not c.startswith("  ") else c for c in (ch or ["no changes left (undone or reset)"])]
            L += [f"- CHECK: {w}" for w in warn]
        L += [f"- {w}" for w in asked.get(k, [])]
        for q, a in sorted(checks.get(k, {}).items(), key=lambda x: x[1]):
            L.append(f"- VISION {'MET' if a == 'yes' else 'NOT MET'}: {q}")
        for n in notes:
            if n["room"] == k:
                at = f" about `{n['target']}`" if n.get("target") else ""
                L.append(f"- NOTE {n['id']} ({n['status']}) at {n['pos']}{at}: {n['text']}" + (f"  / reply: {n['reply']}" if n.get("reply") else ""))
        L.append("")
    print("\n".join(L) if L else "No hand edits yet.")
    if not only and E.is_dir():
        (E / "SUMMARY.md").write_text("# Hand edits (generated by tools/epic/edits.py)\n\n" + "\n".join(L))
    return 0


def verify() -> int:
    bad = 0
    for fk in rooms():
        for ext, name in (("map", f"{fk}.map.txt"), ("json", f"{fk}.json")):
            mine, now = (E / "edited" / name).read_text(), live(fk, ext).read_text()
            same = json.loads(mine) == json.loads(now) if ext == "json" else mine == now
            if not same:
                bad += 1
                print(f"CHANGED SINCE HIS EDIT: {key(fk)} .{ext}")
    print(f"EDITS VERIFY {'PASS' if not bad else 'DIFFERS'} rooms={len(rooms())} files_changed={bad}")
    return 1 if bad else 0


def main() -> int:
    a = sys.argv[1:]
    if a[:1] == ["verify"]:
        return verify()
    if a[:1] == ["keep"] and len(a) == 2:
        fk = a[1].replace(":", "_", 1)
        (E / "edited" / f"{fk}.map.txt").write_text(live(fk, "map").read_text())
        (E / "edited" / f"{fk}.json").write_text(live(fk, "json").read_text())
        print(f"kept {a[1]}")
        return 0
    if a[:1] == ["done"] and len(a) == 3:
        notes = json.loads((E / "notes.json").read_text())
        for n in notes:
            if n["id"] == int(a[1]):
                n["status"], n["reply"] = "done", a[2]
        (E / "notes.json").write_text(json.dumps(notes, indent=2, ensure_ascii=False) + "\n")
        print(f"note {a[1]} answered")
        return 0
    return summary(a[0] if a else "")


if __name__ == "__main__":
    sys.exit(main())
