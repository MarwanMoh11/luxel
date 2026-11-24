#!/usr/bin/env python3
"""Build all Luxel Epic theme scenery atlases into luxel/art/props/theme_<id>.{png,json}.

Run:
  uv run --no-project --with pillow --with numpy python tools/epic/themes/props/build_all.py
"""
from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.epic.themes.props.draw_kit import PROPS_OUT_DIR, PropDef, pack_atlas
from tools.epic.themes.props.sets_1_2 import build_sets_1_2
from tools.epic.themes.props.sets_3_4 import build_sets_3_4
from tools.epic.themes.props.sets_5_6 import build_sets_5_6
from tools.epic.themes.props.sets_7_8 import build_sets_7_8
from tools.epic.themes.props.sets_caves import build_cave_sets


def collect_all_sets() -> list[tuple[str, str, list[PropDef]]]:
    return (
        build_sets_1_2()
        + build_sets_3_4()
        + build_sets_5_6()
        + build_sets_7_8()
        + build_cave_sets()
    )


def build_all() -> dict[str, tuple[str, list[PropDef], dict]]:
    results: dict[str, tuple[str, list[PropDef], dict]] = {}
    all_sets = collect_all_sets()
    total_props = 0
    for sheet_id, title, props in all_sets:
        meta = pack_atlas(sheet_id, title, props, PROPS_OUT_DIR)
        results[sheet_id] = (title, props, meta)
        total_props += len(props)
    print(f"Built {len(all_sets)} theme scenery atlases ({total_props} total props) into {PROPS_OUT_DIR}")
    return results


if __name__ == "__main__":
    build_all()
