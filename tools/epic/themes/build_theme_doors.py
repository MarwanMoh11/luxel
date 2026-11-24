#!/usr/bin/env python3
"""Build theme-skinned door atlases luxel/art/props/theme_<id>_doors.{png,json}
by importing luxel/art/tools/build_doors.py read-only (zero edits to build_doors.py).

Run:
  uv run --no-project --with pillow python tools/epic/themes/build_theme_doors.py
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

BUILD_DOORS_PATH = REPO_ROOT / "luxel" / "art" / "tools" / "build_doors.py"
OUT_DIR = REPO_ROOT / "luxel" / "art" / "props"


def _load_build_doors():
    spec = importlib.util.spec_from_file_location("lx_build_doors", BUILD_DOORS_PATH)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    sys.modules["lx_build_doors"] = mod
    spec.loader.exec_module(mod)
    return mod


def build_all_theme_doors() -> list[str]:
    bd = _load_build_doors()
    from tools.epic.themes.registry import get_spec, list_themes

    IslandTheme = bd.IslandTheme
    SPRITE_SPECS = bd.SPRITE_SPECS
    TRANSPARENT = bd.TRANSPARENT
    PAL = bd.PAL
    verify_palette = bd.verify_palette

    built_ids: list[str] = []
    seen_sheets: set[str] = set()

    for tid in list_themes():
        spec = get_spec(tid)
        door_id = spec.door_sheet
        if not door_id or door_id in seen_sheets:
            continue
        seen_sheets.add(door_id)

        # Construct a bespoke IslandTheme mapped directly from this theme's architectural materials!
        base_isl = max(1, min(8, spec.island))
        theme = IslandTheme(
            island_id=base_isl,
            name=spec.name,
            out="void",
            frame_dk=spec.wall_base if spec.wall_base != "void" else "night",
            frame_mid=spec.wall_face,
            frame_hi=spec.wall_cap[1],
            frame_rim=spec.wall_lip,
            panel_dk=spec.floor_seam,
            panel_mid=spec.wall_face,
            panel_hi=spec.wall_face_hi,
            trim_dk=spec.path_edge,
            trim_mid=spec.path_main,
            trim_hi=spec.path_trim,
            trim_core="cream" if spec.path_trim in ("gold", "ice", "rose") else spec.rim_hi,
            sig_dk=spec.wall_face,
            sig_mid=spec.floor_accent_a,
            sig_hi=spec.floor_accent_b,
            sig_core="cream",
            ward_dk=spec.water_deep,
            ward_mid=spec.water_mid,
            ward_hi=spec.water_hi,
            ward_core=spec.water_foam,
            deco_dk=spec.wall_cap[0],
            deco_mid=spec.floor_accent_a,
            deco_hi=spec.floor_accent_b,
            br_dk=spec.bridge_dark,
            br_mid=spec.bridge_main,
            br_hi=spec.bridge_hi,
            br_rim=spec.bridge_rail,
        )

        rendered = {}
        sheet_w = 0
        sheet_h = 0
        for sp in SPRITE_SPECS:
            frames = sp.draw_fn(theme)
            rendered[sp.key] = frames
            sheet_w = max(sheet_w, sp.w * len(frames))
            sheet_h += sp.h

        atlas = Image.new("RGBA", (sheet_w, sheet_h), TRANSPARENT)
        props_meta = {}
        y_cur = 0
        for sp in SPRITE_SPECS:
            frames = rendered[sp.key]
            rects = []
            for idx, fc in enumerate(frames):
                x_cur = idx * sp.w
                atlas.paste(fc.img, (x_cur, y_cur))
                rects.append([x_cur, y_cur, sp.w, sp.h])
            props_meta[sp.key] = {
                "frame": [sp.w, sp.h],
                "anchor": [sp.origin[0], sp.origin[1]],
                "origin": [sp.origin[0], sp.origin[1]],
                "frames": len(frames),
                "ms": list(sp.ms),
                "loop": True,
                "rects": rects,
            }
            y_cur += sp.h

        png_name = f"{door_id}.png"
        json_name = f"{door_id}.json"
        verify_palette(atlas, png_name)
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        atlas.save(OUT_DIR / png_name, format="PNG")
        meta = {
            "id": door_id,
            "name": f"{spec.name} Doors & Gates",
            "version": 1,
            "palette": PAL,
            "sheet": png_name,
            "image": png_name,
            "sheet_size": [sheet_w, sheet_h],
            "props": props_meta,
        }
        (OUT_DIR / json_name).write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
        built_ids.append(door_id)

    print(f"Built {len(built_ids)} theme door atlases into {OUT_DIR}")
    return built_ids


if __name__ == "__main__":
    build_all_theme_doors()
