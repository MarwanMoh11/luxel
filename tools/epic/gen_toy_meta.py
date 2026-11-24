#!/usr/bin/env python3
"""Generate island toy metadata JSON files (docs/fullgame/epic/toys/meta_i<N>.json).

Scans:
  - luxel/islands/<N>/packs/*.json (registered interactables -> script paths)
  - luxel/islands/<N>/toys/*.gd (props.get/has, is_solid, is_platform_solid, interaction hooks)
  - docs/fullgame/epic/toys/ISLAND<N>.md (documented props and solution hints)

Schema per island file docs/fullgame/epic/toys/meta_i<N>.json:
  {
    "<kind>": {
      "props": ["..."],
      "blocks": "solid|platform|none",
      "puzzle": true,
      "glyph": "AB",
      "reach": "...",
      "script": "res://...",
      "clear_props": ["..."]
    }
  }

Safe to re-run at any time as new island toy packs land.
Usage:
  python3 tools/epic/gen_toy_meta.py [--island N ...] [--check]
"""
from __future__ import annotations

import argparse
import glob
import json
from pathlib import Path
import re
import sys
from typing import Any, Dict, List, Optional, Sequence, Set, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
TOYS_DOCS_DIR = REPO_ROOT / "docs" / "fullgame" / "epic" / "toys"

# Preferred memorable 2-letter glyphs for readability on contact sheets
PREFERRED_GLYPHS: Dict[str, str] = {
    "tone_coffin": "TC",
    "lying_portrait": "LP",
    "falling_bell_platform": "FB",
    "clock_hand": "CH",
    "tide_raft": "TR",
    "mooring_post": "MP",
    "optic_well": "OW",
    "ballast_keg": "BK",
    "stump_shrink": "SS",
    "dew_lens": "DL",
    "dry_root_knot": "RK",
    "silk_loom_spool": "SL",
    "wood_pin_lamp": "WL",
    "beetle_mount": "BM",
    "sap_clock": "SC",
    "garden_sundial": "GS",
    "weather_wheel": "WW",
    "updraft_vent": "UV",
    "clock_gate": "CG",
    "polarity_well": "PW",
    "star_bell": "SB",
    "meteor_orb": "MO",
    "star_node": "SN",
    "temper_anvil": "TA",
    "car_coupler": "CC",
    "slag_pourer": "SP",
    "colossus_stride_cam": "CS",
    "moon_pool": "MN",
    "mirror_avatar": "MA",
    "mask_plinth": "MK",
    "masquerade_dancer": "MD",
    "toll_scale": "TS",
    "toll_gate": "TG",
    "toll_sensor": "TN",
    "memory_plinth": "MY",
    "stair_controller": "ST",
}

PROP_NOISE: Set[str] = {
    "bool", "int", "float", "str", "string", "array", "dict", "dictionary",
    "true", "false", "null", "none", "default", "def", "px", "secs", "deg",
    "n", "e", "s", "w", "x", "y", "l", "r", "for", "and", "or", "with", "to",
    "from", "on", "of", "the", "if", "when", "id", "ids",
}


def build_class_index() -> Dict[str, Path]:
    """Map GDScript class_name -> Path across luxel/ so extends chains can be followed."""
    idx: Dict[str, Path] = {}
    for gd in (REPO_ROOT / "luxel").rglob("*.gd"):
        try:
            head = gd.read_text(encoding="utf-8", errors="ignore")[:600]
        except OSError:
            continue
        m = re.search(r"^\s*class_name\s+([A-Za-z0-9_]+)", head, re.M)
        if m:
            idx[m.group(1)] = gd
    return idx


def extract_props_from_gd(gd_path: Path, class_index: Dict[str, Path], depth: int = 0) -> Set[str]:
    """Scan a GDScript file (and parent Lx* toy classes) for props.get/has/[...] keys."""
    props: Set[str] = set()
    if depth > 4 or not gd_path.exists():
        return props
    txt = gd_path.read_text(encoding="utf-8", errors="ignore")
    for pat in (
        r'\bprops\.get\(\s*"([a-zA-Z0-9_]+)"',
        r'\bprops\.has\(\s*"([a-zA-Z0-9_]+)"',
        r'\bprops\[\s*"([a-zA-Z0-9_]+)"\s*\]',
        r'\bdir_vec\(\s*"([a-zA-Z0-9_]+)"',
    ):
        for m in re.finditer(pat, txt):
            props.add(m.group(1))
    # Follow parent class if it is another concrete toy (stop before generic LxToy/LxInteractable)
    ext_m = re.search(r"^\s*extends\s+([A-Za-z0-9_]+)", txt, re.M)
    if ext_m:
        parent = ext_m.group(1)
        if parent not in ("LxToy", "LxInteractable", "Node2D", "Node", "RefCounted") and parent in class_index:
            props |= extract_props_from_gd(class_index[parent], class_index, depth + 1)
    return props


def _extract_func_body(txt: str, func_name: str) -> str:
    m = re.search(rf"^func\s+{re.escape(func_name)}\s*\([^)]*\).*?:\s*$", txt, re.M)
    if not m:
        return ""
    start = m.end()
    lines = txt[start:].splitlines()
    body: List[str] = []
    for ln in lines:
        if ln.strip() == "":
            body.append(ln)
            continue
        if not ln.startswith(("\t", " ")):
            break
        body.append(ln)
    return "\n".join(body)


def infer_blocks(gd_path: Path, class_index: Dict[str, Path], depth: int = 0) -> Tuple[str, List[str]]:
    """Infer blocks ('solid'|'platform'|'none') and clear_props from GDScript methods."""
    if depth > 4 or not gd_path.exists():
        return "none", []
    txt = gd_path.read_text(encoding="utf-8", errors="ignore")

    plat_body = _extract_func_body(txt, "is_platform_solid")
    solid_body = _extract_func_body(txt, "is_solid")

    has_platform = bool(plat_body) and not re.fullmatch(r"\s*return\s+false\s*", plat_body.strip())
    has_solid = bool(solid_body) and not re.fullmatch(r"\s*return\s+false\s*", solid_body.strip())

    clear_props: List[str] = []
    if solid_body:
        for cp in ("burned", "opened", "starts_open", "broken", "shattered", "uncoupled", "reclaimed"):
            if re.search(rf"\b{cp}\b", solid_body) or re.search(rf'"{cp}"', txt):
                if cp not in clear_props:
                    clear_props.append(cp)

    if has_platform and not has_solid:
        return "platform", clear_props
    if has_platform and has_solid:
        # Walkable platforms that only conditionally block (e.g. tone_coffin solid_blocker=false, star_node)
        if re.search(r"\bsolid_blocker\b", solid_body):
            return "platform", clear_props
        return "platform", clear_props
    if has_solid:
        return "solid", clear_props

    # Inherit from parent toy class if not overridden
    ext_m = re.search(r"^\s*extends\s+([A-Za-z0-9_]+)", txt, re.M)
    if ext_m:
        parent = ext_m.group(1)
        if parent not in ("LxToy", "LxInteractable", "Node2D", "Node", "RefCounted") and parent in class_index:
            return infer_blocks(class_index[parent], class_index, depth + 1)
    return "none", clear_props


def infer_reach(kind: str, blocks: str, gd_path: Path, md_hint: str) -> str:
    txt = gd_path.read_text(encoding="utf-8", errors="ignore") if gd_path.exists() else ""
    tags: List[str] = []
    if blocks == "solid":
        tags.append("blocks_walk")
    elif blocks == "platform":
        tags.append("walkable_platform")

    if "dew_ray" in txt or "dew_ray" in md_hint:
        tags.append("dew_ray")
    if re.search(r'"beam"', txt) or "beam" in md_hint.lower():
        if "on_hit" in txt:
            tags.append("beam")
    if re.search(r'"sunflare"', txt) and "on_hit" in txt:
        tags.append("sunflare")
    if "func on_hit(" in txt:
        tags.append("shoot")
    if "func interact(" in txt:
        tags.append("interact")
    if "func on_ring(" in txt:
        tags.append("ring")
    if "func on_light(" in txt or "lens_only" in txt:
        tags.append("light")
    if "refresh_glide" in txt or "updraft" in kind:
        tags.append("wings_refresh")
    if "mount(" in txt or "mount" in kind:
        tags.append("mount")
    if "world_set_var" in txt or "Lx.vars.set_var" in txt or "set_var(" in txt:
        tags.append("sets_var")
    if "LxFields" in txt or "accel_at" in txt:
        tags.append("field")

    # Deduplicate preserving order
    seen: Set[str] = set()
    clean: List[str] = []
    for t in tags:
        if t not in seen:
            seen.add(t)
            clean.append(t)
    return "|".join(clean) if clean else "interact"


def parse_island_md(md_path: Path) -> Dict[str, Dict[str, Any]]:
    """Parse toy table rows from docs/fullgame/epic/toys/ISLAND<N>.md."""
    out: Dict[str, Dict[str, Any]] = {}
    if not md_path.exists():
        return out
    txt = md_path.read_text(encoding="utf-8", errors="ignore")
    for line in txt.splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        m_kind = re.match(r"^`([a-z0-9_]+)`$", cells[0])
        if not m_kind:
            continue
        kind = m_kind.group(1)
        # Find props cell (usually cell 1 or cell 2)
        props_cell = cells[2] if len(cells) >= 4 and (".gd" in cells[1] or "Lx" in cells[1]) else cells[1]
        hint_cell = cells[-1]
        md_props: Set[str] = set()
        for tok in re.findall(r"`([^`]+)`", props_cell):
            # Tokens can be `prop_name`, `prop_name: "a|b"`, `prop_a/prop_b`, `prop_name: [x,y]`
            for part in tok.split("/"):
                part = part.strip()
                m_key = re.match(r"^([a-z][a-z0-9_]{1,32})(?:\s*[:=\(]|$)", part)
                if m_key:
                    pk = m_key.group(1)
                    if pk not in PROP_NOISE:
                        md_props.add(pk)
        out[kind] = {"md_props": md_props, "hint": hint_cell}
    return out


def choose_glyph(kind: str, used: Set[str]) -> str:
    if kind in PREFERRED_GLYPHS and PREFERRED_GLYPHS[kind] not in used:
        g = PREFERRED_GLYPHS[kind]
        used.add(g)
        return g
    parts = [p for p in kind.split("_") if p]
    cands: List[str] = []
    if len(parts) >= 2:
        cands.append((parts[0][0] + parts[-1][0]).upper())
        cands.append((parts[0][0] + parts[1][0]).upper())
    if parts:
        w0 = parts[0]
        for ch in w0[1:]:
            cands.append((w0[0] + ch).upper())
    flat = kind.replace("_", "").upper()
    for a in flat:
        for b in flat:
            cands.append(a + b)
    for c in cands:
        if len(c) == 2 and c.isalnum() and c not in used:
            used.add(c)
            return c
    return kind[:2].upper()


def discover_island_toys(isl_id: int) -> Dict[str, Path]:
    """Return kind -> Path(.gd) for an island from its packs/*.json and toys/*.gd."""
    toys: Dict[str, Path] = {}
    isl_dir = REPO_ROOT / "luxel" / "islands" / str(isl_id)
    if not isl_dir.is_dir():
        return toys
    packs_dir = isl_dir / "packs"
    if packs_dir.is_dir():
        for pj in sorted(packs_dir.glob("*.json")):
            try:
                data = json.loads(pj.read_text(encoding="utf-8"))
            except Exception:
                continue
            if not isinstance(data, dict):
                continue
            inters = data.get("interactables")
            if not isinstance(inters, dict):
                continue
            for k, v in inters.items():
                spath = v if isinstance(v, str) else (v.get("script", "") if isinstance(v, dict) else "")
                if not spath:
                    continue
                rel = spath.replace("res://", "")
                p = REPO_ROOT / rel
                toys[str(k).strip().lower()] = p
    # Also pick up any toys/*.gd not yet registered in a pack JSON
    toys_dir = isl_dir / "toys"
    if toys_dir.is_dir():
        registered_paths = {p.resolve() for p in toys.values() if p.exists()}
        for gd in sorted(toys_dir.glob("*.gd")):
            if gd.resolve() in registered_paths:
                continue
            stem = gd.stem.lower()
            # Skip helper scripts that don't extend LxToy/LxInteractable at top level
            head = gd.read_text(encoding="utf-8", errors="ignore")[:500]
            if not re.search(r"^extends\s+(LxToy|LxInteractable|LxPhys|LxLogic)", head, re.M):
                continue
            kind_m = re.search(r'\bkind\s*=\s*"([a-z0-9_]+)"', head)
            k = kind_m.group(1) if kind_m else re.sub(r"^isl\d+_", "", stem)
            if k.startswith("_"):
                continue
            if k not in toys:
                toys[k] = gd
    return toys


def generate_island_meta(isl_id: int, class_index: Dict[str, Path], used_glyphs: Set[str]) -> Optional[Dict[str, Any]]:
    toys = discover_island_toys(isl_id)
    if not toys:
        return None
    md_info = parse_island_md(TOYS_DOCS_DIR / f"ISLAND{isl_id}.md")
    meta: Dict[str, Any] = {}
    for kind in sorted(toys.keys()):
        gd_path = toys[kind]
        code_props = extract_props_from_gd(gd_path, class_index)
        md_entry = md_info.get(kind, {})
        all_props = sorted(code_props | set(md_entry.get("md_props", set())))
        blocks, clear_props = infer_blocks(gd_path, class_index)
        glyph = choose_glyph(kind, used_glyphs)
        reach = infer_reach(kind, blocks, gd_path, str(md_entry.get("hint", "")))
        rel_script = "res://" + gd_path.relative_to(REPO_ROOT).as_posix() if gd_path.exists() else ""
        entry: Dict[str, Any] = {
            "props": all_props,
            "blocks": blocks,
            "puzzle": True,
            "glyph": glyph,
            "reach": reach,
        }
        if clear_props:
            entry["clear_props"] = clear_props
        if rel_script:
            entry["script"] = rel_script
        meta[kind] = entry
    return meta


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Generate docs/fullgame/epic/toys/meta_i<N>.json from island toy packs and docs")
    ap.add_argument("--island", type=int, action="append", default=[], help="Generate only for island N (default: all 1..8 with toys)")
    ap.add_argument("--check", action="store_true", help="Exit non-zero if any generated file differs from disk")
    args = ap.parse_args(argv)

    islands = sorted(set(args.island)) if args.island else list(range(1, 9))
    class_index = build_class_index()
    used_glyphs: Set[str] = set()
    TOYS_DOCS_DIR.mkdir(parents=True, exist_ok=True)

    written = 0
    total_kinds = 0
    stale: List[str] = []
    for isl in islands:
        meta = generate_island_meta(isl, class_index, used_glyphs)
        if not meta:
            continue
        out_path = TOYS_DOCS_DIR / f"meta_i{isl}.json"
        rendered = json.dumps(meta, indent=2) + "\n"
        if args.check:
            cur = out_path.read_text(encoding="utf-8") if out_path.exists() else ""
            if cur != rendered:
                stale.append(str(out_path))
        else:
            out_path.write_text(rendered, encoding="utf-8")
        written += 1
        total_kinds += len(meta)
        print(f"meta_i{isl}.json: {len(meta)} kinds -> " + ", ".join(f"{k}[{v['glyph']}:{v['blocks']}]" for k, v in meta.items()))

    if args.check and stale:
        print(f"TOY META CHECK FAIL: stale files: {stale}", file=sys.stderr)
        return 1
    print(f"TOY META PASS: islands={written} kinds={total_kinds}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
