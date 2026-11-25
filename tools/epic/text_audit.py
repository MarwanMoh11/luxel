#!/usr/bin/env python3
"""Luxel Epic player-facing text auditor.

Scans luxel/story/strings.gd, luxel/data/packs/*.json, luxel/islands/*/packs/*.json,
luxel/hub/packs/*.json, and player-facing fields in luxel/data/*.json.

Reports:
  - Every string (with --all): id, file, length, value
  - Duplicate IDs (collisions)
  - Lines exceeding 45 chars (raw and expanded %d/%s -> 999)
  - Characters outside the 3x5 pixel font charset
  - Exact duplicate values across IDs
  - Near-duplicate names (places, bosses, enemies, panes, items, quests)
  - Dev/process words, shorthand, exclamation spam, and style flags
"""
from __future__ import annotations

import argparse
import collections
import difflib
import glob
import json
import os
import re
import sys
from pathlib import Path

ALLOWED_CHARS = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-:x/.+= %")
MAX_LINE_LEN = 45

DEV_WORD_PATTERNS = [
    (r"\bISLAND\s+[1-8]\b", "ISLAND N reference"),
    (r"\bRULE\b", "process word RULE"),
    (r"\bDEBUG\b", "dev word DEBUG"),
    (r"\bTEST(?:ING|ED)?\b", "dev word TEST"),
    (r"\bSPEC\b", "dev word SPEC"),
    (r"\bLAYER\b", "dev word LAYER"),
    (r"\bTODO\b|\bTBD\b|\bWIP\b|\bFIXME\b", "placeholder marker"),
    (r"\bPLACEHOLDER\b", "placeholder marker"),
    (r"\bPACK\b|\bJSON\b|\bSCRIPT\b|\bNODE\b", "engine/pack word"),
    (r"\bFLAG\b|\bVAR\b|\bSTATE\b", "code word"),
    (r"\bR\d+\b", "room code shorthand (Rn)"),
    (r"\bI[1-8]\b", "island shorthand (In)"),
    (r"\bDMG\b|\bCD\b|\bDPS\b|\bRNG\b|\bNPC\b|\bHUD\b|\bUI\b|\bPX\b", "dev shorthand"),
    (r"\bDEMO\b", "dev word DEMO"),
    (r"\bSWARM\b|\bEPIC\b|\bWAVE\b|\bPHASE\s*\d", "process/meta word"),
    (r"\bTUTORIAL\b", "meta word TUTORIAL"),
]

AI_CLICHE_PATTERNS = [
    r"\bDELVE\b",
    r"\bTAPESTRY\b",
    r"\bTESTAMENT\b",
    r"\bBEACON OF HOPE\b",
    r"\bSHROUDED IN\b",
    r"\bWHISPERS OF\b",
    r"\bREALM OF\b",
    r"\bAWAITS YOUR\b",
    r"\bUNLOCK THE SECRETS\b",
    r"\bEMBRACE THE\b",
    r"\bFORGE YOUR\b",
    r"\bJOURNEY BEGINS\b",
    r"\bUNLEASH\b",
]

NAME_PREFIXES = (
    "BOSS_", "MINIBOSS_", "ENEMY_", "DNG_", "DUNGEON_", "REG_", "REGION_",
    "ZONE_", "PANE_", "MOTH_", "QUEST_", "FOLK_", "NPC_", "ITEM_", "UPG_",
    "WARE_", "MOVE_", "HUB_", "WS_",
)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def parse_strings_gd(path: Path, root: Path) -> list[dict]:
    rel = str(path.relative_to(root))
    text = path.read_text(encoding="utf-8")
    m_start = re.search(r"const\s+TABLE\s*:\s*Dictionary\s*=\s*\{", text)
    if not m_start:
        return []
    m_end = text.find("\n}\n", m_start.end())
    body = text[m_start.end():m_end if m_end >= 0 else len(text)]
    entries = []
    for m in re.finditer(r'^\s*"([^"]+)"\s*:\s*"((?:[^"\\]|\\.)*)"', body, re.M):
        sid = m.group(1)
        raw_val = m.group(2)
        val = raw_val.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")
        entries.append({"id": sid, "file": rel, "value": val, "source": "strings.gd"})
    return entries


def parse_pack_json(path: Path, root: Path) -> list[dict]:
    rel = str(path.relative_to(root))
    data = json.loads(path.read_text(encoding="utf-8"))
    strings = data.get("strings", {})
    if not isinstance(strings, dict):
        return []
    entries = []
    for sid, val in strings.items():
        if isinstance(val, str):
            entries.append({"id": sid, "file": rel, "value": val, "source": "pack"})
    return entries


def parse_data_json(path: Path, root: Path) -> list[dict]:
    rel = str(path.relative_to(root))
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = []
    if path.name == "islands.json":
        for isl in data.get("islands", []):
            iid = isl.get("id", "?")
            if isinstance(isl.get("name"), str):
                entries.append({"id": f"DATA_ISLAND_{iid}_NAME", "file": rel, "value": isl["name"], "source": "data"})
            if isinstance(isl.get("dungeon_name"), str):
                entries.append({"id": f"DATA_ISLAND_{iid}_DUNGEON", "file": rel, "value": isl["dungeon_name"], "source": "data"})
    elif path.name == "toll_settings.json":
        for idx, tab in enumerate(data.get("tabs", [])):
            if isinstance(tab, str):
                entries.append({"id": f"DATA_TOLL_TAB_{idx}", "file": rel, "value": tab, "source": "data"})
    return entries


def expand_placeholders(val: str, fill: str = "999") -> str:
    return re.sub(r"%[ds]", fill, val)


def check_charset_and_len(val: str, max_len: int = MAX_LINE_LEN) -> tuple[list[str], list[tuple[int, str]]]:
    bad_chars = []
    over_lines = []
    expanded = expand_placeholders(val, "999")
    for line in expanded.split("\n"):
        if len(line) > max_len:
            over_lines.append((len(line), line))
        for ch in line:
            if ch not in ALLOWED_CHARS and ch not in bad_chars:
                bad_chars.append(ch)
    return bad_chars, over_lines


def normalize_name(s: str) -> str:
    s = s.upper().strip()
    s = re.sub(r"^(THE|A|AN)\s+", "", s)
    s = re.sub(r"[^A-Z0-9 ]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def is_name_entry(entry: dict) -> bool:
    sid = entry["id"]
    val = entry["value"]
    if len(val) > 32 or "\n" in val or val.endswith(".") or "%d" in val or "%s" in val:
        return False
    if any(sid.startswith(p) for p in NAME_PREFIXES):
        if any(sid.endswith(suf) for suf in ("_DESC", "_CAPTION", "_HINT", "_LINE", "_LORE", "_SIGN", "_STEP", "_SUB", "_SUBTITLE", "_PROMPT", "_QUOTE", "_BLURB", "_NOTE", "_SAY", "_TALK", "_INTRO")):
            return False
        return True
    if sid.endswith("_NAME") or sid.endswith("_TITLE"):
        return True
    return False


def collect_all(root: Path) -> list[dict]:
    entries: list[dict] = []
    sgd = root / "luxel" / "story" / "strings.gd"
    if sgd.exists():
        entries.extend(parse_strings_gd(sgd, root))
    pack_paths = sorted(
        glob.glob(str(root / "luxel" / "data" / "packs" / "*.json"))
        + glob.glob(str(root / "luxel" / "hub" / "packs" / "*.json"))
        + glob.glob(str(root / "luxel" / "islands" / "*" / "packs" / "*.json"))
    )
    for pp in pack_paths:
        entries.extend(parse_pack_json(Path(pp), root))
    for dp in sorted(glob.glob(str(root / "luxel" / "data" / "*.json"))):
        entries.extend(parse_data_json(Path(dp), root))
    return entries


def audit(entries: list[dict], max_len: int = MAX_LINE_LEN) -> dict:
    id_seen: dict[str, list[str]] = collections.defaultdict(list)
    val_seen: dict[str, list[tuple[str, str]]] = collections.defaultdict(list)
    over_limit = []
    bad_charset = []
    dev_words = []
    style_flags = []
    ai_cliches = []

    for e in entries:
        sid = e["id"]
        val = e["value"]
        f = e["file"]
        id_seen[sid].append(f)
        if e["source"] != "data":
            val_seen[val].append((sid, f))

        bchars, olines = check_charset_and_len(val, max_len)
        e["len"] = max((len(l) for l in val.split("\n")), default=0)
        e["expanded_len"] = max((len(l) for l in expand_placeholders(val, "999").split("\n")), default=0)
        if olines:
            over_limit.append({"id": sid, "file": f, "value": val, "lines": olines})
        if bchars:
            bad_charset.append({"id": sid, "file": f, "value": val, "chars": bchars})

        # Dev/process words
        for pat, label in DEV_WORD_PATTERNS:
            if re.search(pat, val):
                dev_words.append({"id": sid, "file": f, "value": val, "reason": label})
                break

        # AI cliches
        for pat in AI_CLICHE_PATTERNS:
            if re.search(pat, val):
                ai_cliches.append({"id": sid, "file": f, "value": val, "pattern": pat})
                break

        # Style flags
        reasons = []
        if "!!" in val or val.count("!") >= 2:
            reasons.append("exclamation_spam")
        if "—" in val or "–" in val or "--" in val:
            reasons.append("dash_style")
        if val != val.strip():
            reasons.append("edge_whitespace")
        if "  " in val and not any(k in sid for k in ("HINT", "STATS", "META", "CREDITS", "SLOT")):
            reasons.append("double_space")
        if reasons:
            style_flags.append({"id": sid, "file": f, "value": val, "reasons": reasons})

    id_collisions = {k: v for k, v in id_seen.items() if len(v) > 1}
    exact_duplicates = {
        v: items for v, items in val_seen.items()
        if len(items) > 1 and len(v) >= 6
    }

    # Near-duplicate names
    name_entries = [e for e in entries if is_name_entry(e) and e["source"] != "data"]
    norm_groups: dict[str, list[dict]] = collections.defaultdict(list)
    for e in name_entries:
        norm_groups[normalize_name(e["value"])].append(e)

    near_dupes = []
    norm_keys = sorted(k for k in norm_groups if len(k) >= 4)
    # Exact normalized match with different surface form or different IDs
    for nk, grp in norm_groups.items():
        if len(grp) > 1:
            surfaces = sorted(set(g["value"] for g in grp))
            if len(surfaces) > 1:
                near_dupes.append({
                    "kind": "same_normalized",
                    "a": (grp[0]["id"], grp[0]["file"], grp[0]["value"]),
                    "b": (grp[1]["id"], grp[1]["file"], grp[1]["value"]),
                    "ratio": 1.0,
                })
    # Pairwise fuzzy match across distinct normalized names
    for i in range(len(norm_keys)):
        a_k = norm_keys[i]
        a_e = norm_groups[a_k][0]
        for j in range(i + 1, len(norm_keys)):
            b_k = norm_keys[j]
            if abs(len(a_k) - len(b_k)) > 4:
                continue
            r = difflib.SequenceMatcher(None, a_k, b_k).ratio()
            if r >= 0.84:
                b_e = norm_groups[b_k][0]
                near_dupes.append({
                    "kind": "fuzzy_name",
                    "a": (a_e["id"], a_e["file"], a_e["value"]),
                    "b": (b_e["id"], b_e["file"], b_e["value"]),
                    "ratio": round(r, 3),
                })

    return {
        "total": len(entries),
        "id_collisions": id_collisions,
        "over_limit": over_limit,
        "bad_charset": bad_charset,
        "exact_duplicates": exact_duplicates,
        "near_duplicate_names": near_dupes,
        "dev_words": dev_words,
        "ai_cliches": ai_cliches,
        "style_flags": style_flags,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Audit all player-facing strings in luxel/.")
    ap.add_argument("--max-len", type=int, default=MAX_LINE_LEN, help="Max characters per line (default 45)")
    ap.add_argument("--all", action="store_true", help="List every string with id, file, length, value")
    ap.add_argument("--json", type=str, default="", help="Write full audit report JSON to path")
    ap.add_argument("--strict", action="store_true", help="Exit 1 if charset, length, or collision errors exist")
    args = ap.parse_args()

    root = repo_root()
    entries = collect_all(root)
    res = audit(entries, max_len=args.max_len)

    if args.all:
        for e in entries:
            print(f"{e['id']}\t{e['file']}\t{e['len']}/{e['expanded_len']}\t{e['value']!r}")

    print(f"=== LUXEL TEXT AUDIT (total={res['total']} strings, max_len={args.max_len}) ===")
    print(f"ID collisions:        {len(res['id_collisions'])}")
    print(f"Over length limit:    {len(res['over_limit'])}")
    print(f"Bad 3x5 charset:      {len(res['bad_charset'])}")
    print(f"Exact duplicate vals: {len(res['exact_duplicates'])}")
    print(f"Near-duplicate names: {len(res['near_duplicate_names'])}")
    print(f"Dev/process words:    {len(res['dev_words'])}")
    print(f"AI cliche patterns:   {len(res['ai_cliches'])}")
    print(f"Style flags:          {len(res['style_flags'])}")

    if res["id_collisions"]:
        print("\n-- ID COLLISIONS --")
        for k, files in res["id_collisions"].items():
            print(f"  {k}: {files}")

    if res["over_limit"]:
        print("\n-- OVER LIMIT --")
        for item in res["over_limit"]:
            print(f"  {item['id']} ({item['file']}): {item['lines']}")

    if res["bad_charset"]:
        print("\n-- BAD CHARSET --")
        for item in res["bad_charset"]:
            print(f"  {item['id']} ({item['file']}): chars={item['chars']} in {item['value']!r}")

    if res["exact_duplicates"]:
        print("\n-- EXACT DUPLICATES (len >= 6) --")
        for val, items in sorted(res["exact_duplicates"].items(), key=lambda kv: -len(kv[1])):
            ids = ", ".join(f"{sid}@{Path(f).name}" for sid, f in items)
            print(f"  [{len(items)}x] {val!r} -> {ids}")

    if res["near_duplicate_names"]:
        print("\n-- NEAR-DUPLICATE NAMES --")
        for nd in res["near_duplicate_names"]:
            a_id, a_f, a_v = nd["a"]
            b_id, b_f, b_v = nd["b"]
            print(f"  ({nd['ratio']}) {a_v!r} [{a_id}@{Path(a_f).name}]  <->  {b_v!r} [{b_id}@{Path(b_f).name}]")

    if res["dev_words"]:
        print("\n-- DEV/PROCESS WORDS --")
        for item in res["dev_words"]:
            print(f"  {item['id']} ({Path(item['file']).name}) [{item['reason']}]: {item['value']!r}")

    if res["ai_cliches"]:
        print("\n-- AI CLICHES --")
        for item in res["ai_cliches"]:
            print(f"  {item['id']} ({Path(item['file']).name}): {item['value']!r}")

    if res["style_flags"]:
        print("\n-- STYLE FLAGS --")
        for item in res["style_flags"]:
            print(f"  {item['id']} ({Path(item['file']).name}) {item['reasons']}: {item['value']!r}")

    if args.json:
        out_path = Path(args.json)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {"summary": res, "entries": entries}
        out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"\nWrote JSON audit to {args.json}")

    if args.strict and (res["id_collisions"] or res["over_limit"] or res["bad_charset"]):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
