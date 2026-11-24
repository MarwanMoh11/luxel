#!/usr/bin/env python3
"""Render 24x14 demo room test pages (2x nearest) for every Luxel Epic theme + contact sheets.

Outputs:
  docs/fullgame/epic/themes_preview/<id>.png      (768x468: 2x 384x224 room + crisp header)
  docs/fullgame/epic/themes_preview/_contact_sheet.png (all 43 themes)
  docs/fullgame/epic/themes_preview/_contact_sheet_{1..4}.png (high-res sheets for VLM review)
  docs/fullgame/epic/themes_preview/_layers_proof.png (dynamic layer overlay verification)

Run:
  uv run --no-project --with pillow --with numpy python tools/epic/themes/render_previews.py
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.epic.themes import get_spec, get_theme, list_themes, paint_layers
from tools.epic.themes.kit import PAL, RGBA, verify_image_palette

PREVIEW_DIR = REPO_ROOT / "docs" / "fullgame" / "epic" / "themes_preview"
PROPS_DIR = REPO_ROOT / "luxel" / "art" / "props"

LEGEND = {
    ".": "ground",
    "#": "wall",
    ",": "path",
    "~": "water",
    "O": "pit",
    "_": "void",
    "+": "bridge",
    "G": "glass",
    "T": "tide",
    "D": "carpet",
    "S": "stairs",
    "H": "grate",
    "R": "rail",
    "F": "foliage",
}


def _parse_rows(rows: list[str]) -> list[list[str]]:
    assert len(rows) == 14 and all(len(r) == 24 for r in rows), f"Expected 24x14, got {len(rows)}x{len(rows[0])}"
    return [[LEGEND.get(ch, "void") for ch in r] for r in rows]


# 5 asymmetric 24x14 architectural demo room templates (zero boring symmetry!)
TEMPLATES: dict[str, tuple[list[str], list[dict[str, Any]]]] = {
    "hall_pit": (
        [
            "#########,,#############",
            "#########,,#############",
            "##.....#.,,.......###.##",
            "##.....#.,,..........###",
            "##.....,,....OOOOO....##",
            ",,.....,,....OOOOO....##",
            ",,.....,,++++OOOOO....,,",
            "##......,....OOOOO....,,",
            "##..##..,....OOOOO....##",
            "##......,,,,..........##",
            "##...~~~...,,..##.....##",
            "##...~~~....,,,.......##",
            "###############,,#######",
            "###############,,#######",
        ],
        [
            {"rect": [144, 0, 32, 32]},
            {"rect": [0, 80, 32, 32]},
            {"rect": [352, 96, 32, 32]},
            {"rect": [240, 192, 32, 32]},
        ],
    ),
    "canal_water": (
        [
            "########,,##############",
            "########,,##############",
            "##......,,....~~~~~~..##",
            "##..##..,,....~~~~~~..##",
            "##......,,....~~~~~~..##",
            ",,.....,,,++++~~~~~~..##",
            ",,.....,,.....~~~~~~..,,",
            "##.....,,......~~~~...,,",
            "##.....,,.............##",
            "##..~~~,,..##.........##",
            "##..~~~,,,,...........##",
            "##..~~~~..,,,.........##",
            "############,,,#########",
            "############,,,#########",
        ],
        [
            {"rect": [128, 0, 32, 32]},
            {"rect": [0, 80, 32, 32]},
            {"rect": [352, 96, 32, 32]},
            {"rect": [192, 192, 48, 32]},
        ],
    ),
    "train_car": (
        [
            "________________________",
            "########################",
            "#......................#",
            "#..##......##......##..#",
            "#......................#",
            ",,,,,,,,,,,,,,,,,,,,,,,,",
            ",,,,,,,,,,,,,,,,,,,,,,,,",
            "#......................#",
            "#....##..........##....#",
            "#..H............H......#",
            "#......................#",
            "########################",
            "________________________",
            "________________________",
        ],
        [
            {"rect": [0, 80, 32, 32]},
            {"rect": [352, 80, 32, 32]},
        ],
    ),
    "train_roof": (
        [
            "________________________",
            "________________________",
            "__....................__",
            "__..##..........##....__",
            "__....................__",
            "__,,,,,,,,,,,,,,,,,,,,++",
            "__,,,,,,,,,,,,,,,,,,,,++",
            "__....................__",
            "__......##............__",
            "__..H..........H......__",
            "__....................__",
            "________________________",
            "________________________",
            "________________________",
        ],
        [
            {"rect": [352, 80, 32, 32]},
        ],
    ),
    "island_void": (
        [
            "________________________",
            "___########,,####_______",
            "__##.......,,...##______",
            "__#........,,....##_____",
            "__#..##....,,.....#_____",
            "__#........,,+++++##____",
            "__#........,,.....,,,___",
            "__##......,,,.....,,,___",
            "___##.....,,.....##_____",
            "____#...~~,,....##______",
            "____#...~~,,...##_______",
            "____#######,,###________",
            "___________,,___________",
            "________________________",
        ],
        [
            {"rect": [176, 16, 32, 32]},
            {"rect": [176, 176, 32, 32]},
        ],
    ),
    "cavern": (
        [
            "#########,,#############",
            "#####....,,....#########",
            "###......,,......#######",
            "##...#...,,........#####",
            "##.......,,..OOOO....###",
            ",,......,,,..OOOO.....##",
            ",,.....,,++++OOOO.....,,",
            "###....,,....OOOO.....,,",
            "####...,,............###",
            "###..~~~,,,.........####",
            "##...~~~~.,,...#....####",
            "###..~~~~..,,.....######",
            "############,,##########",
            "############,,##########",
        ],
        [
            {"rect": [144, 0, 32, 32]},
            {"rect": [0, 80, 32, 32]},
            {"rect": [352, 96, 32, 32]},
            {"rect": [192, 192, 32, 32]},
        ],
    ),
}


def _template_for(tid: str) -> str:
    if tid == "ember_express":
        return "train_car"
    if tid == "ember_express_roof":
        return "train_roof"
    if tid in ("freefall", "great_toll_shaft", "wick_house", "endless_stair"):
        return "island_void"
    if tid in ("galleon", "locks", "leviathan_belly", "seabed", "rain_mausoleum", "garden_party", "briar_court"):
        return "canal_water"
    if tid.startswith("cave_"):
        return "cavern"
    return "hall_pit"


def _decor_for(tid: str, tmpl: str) -> list[dict[str, Any]]:
    if tmpl == "train_car":
        return [
            {"kind": "rug", "rect": [40, 84, 304, 24], "style": "ornate"},
            {"kind": "grate", "rect": [64, 146, 20, 14], "glow": True},
            {"kind": "grate", "rect": [248, 146, 20, 14], "glow": True},
        ]
    if tmpl == "train_roof":
        return [
            {"kind": "grate", "rect": [80, 146, 24, 12], "glow": True},
            {"kind": "grate", "rect": [224, 146, 24, 12], "glow": True},
        ]
    if tmpl == "island_void":
        if tid == "wick_house":
            return [
                {"kind": "rug", "rect": [96, 76, 68, 44], "style": "hearth"},
                {"kind": "light_shaft", "pos": [150, 90], "size": [34, 56], "tint": "warm"},
            ]
        return [
            {"kind": "circle", "pos": [140, 108], "radius": 24, "style": "astrolabe"},
            {"kind": "cracks", "pos": [230, 86], "radius": 16, "glow": tid == "great_toll_shaft"},
        ]
    if tmpl == "cavern":
        glow = tid in ("cave_6", "cave_5", "cave_8")
        return [
            {"kind": "cracks", "pos": [112, 92], "radius": 18, "glow": glow},
            {"kind": "stain", "pos": [288, 128], "radius": 16, "style": "moss" if tid in ("cave_1", "cave_3", "cave_4") else "water"},
            {"kind": "light_shaft", "pos": [160, 74], "size": [26, 46], "tint": "cool" if tid in ("cave_2", "cave_5", "cave_7") else "warm"},
        ]
    if tmpl == "canal_water":
        style = "compass" if tid in ("galleon", "locks") else "circle"
        return [
            {"kind": style, "pos": [96, 104], "radius": 24},
            {"kind": "stain", "pos": [296, 152], "radius": 18, "style": "acid" if tid == "leviathan_belly" else ("petal" if tid in ("briar_court", "garden_party") else "water")},
            {"kind": "light_shaft", "pos": [196, 134], "size": [28, 48], "tint": "cool" if tid in ("rain_mausoleum", "locks") else "warm"},
        ]
    # hall_pit
    if tid in ("manor", "doppel_theatre", "toll_house") or tid.startswith("archive"):
        return [
            {"kind": "rug", "rect": [42, 48, 66, 44], "style": "ornate"},
            {"kind": "circle", "pos": [306, 146], "radius": 20, "style": "spotlight" if tid == "doppel_theatre" else "mosaic"},
            {"kind": "light_shaft", "pos": [168, 72], "size": [28, 52], "tint": "warm"},
        ]
    if tid in ("planetarium", "meteor_vault", "hourglass_maze"):
        return [
            {"kind": "compass", "pos": [84, 72], "radius": 24},
            {"kind": "circle", "pos": [304, 152], "radius": 20, "style": "astrolabe"},
            {"kind": "cracks", "pos": [210, 162], "radius": 14, "glow": tid == "meteor_vault"},
        ]
    if tid in ("forge_deep", "iron_colossus"):
        return [
            {"kind": "grate", "rect": [56, 56, 26, 18], "glow": True},
            {"kind": "circle", "pos": [304, 148], "radius": 22, "style": "gear"},
            {"kind": "cracks", "pos": [204, 162], "radius": 18, "glow": True},
        ]
    return [
        {"kind": "circle", "pos": [84, 76], "radius": 22, "style": "ritual"},
        {"kind": "light_shaft", "pos": [174, 84], "size": [30, 52], "tint": "cool" if "silver" in tid else "warm"},
        {"kind": "stain", "pos": [308, 156], "radius": 16, "style": "moss" if tid == "under_root" else "water"},
    ]


def _load_atlas(sheet_id: str) -> tuple[Image.Image, dict] | None:
    jp = PROPS_DIR / f"{sheet_id}.json"
    pp = PROPS_DIR / f"{sheet_id}.png"
    if not jp.exists() or not pp.exists():
        return None
    meta = json.loads(jp.read_text(encoding="utf-8"))
    im = Image.open(pp).convert("RGBA")
    return im, meta


def _is_walkable_px(grid: list[list[str]], x: int, y: int, ts: int = 16) -> bool:
    tx, ty = x // ts, y // ts
    if not (0 <= ty < len(grid) and 0 <= tx < len(grid[0])):
        return False
    return grid[ty][tx] in ("ground", "path", "carpet", "stairs", "grate")


def _composite_props(base_im: Image.Image, grid: list[list[str]], sheet_id: str, tmpl: str) -> Image.Image:
    loaded = _load_atlas(sheet_id)
    if loaded is None:
        return base_im
    atlas_im, meta = loaded
    props_dict: dict[str, dict] = meta.get("props", {})
    keys = list(props_dict.keys())
    if not keys:
        return base_im

    out = base_im.copy()

    # Candidate architectural anchor spots per template (all carefully on safe walkable ground!)
    if tmpl == "train_car":
        spots = [
            (74, 46), (168, 46), (264, 46),  # north wall windows / booths / lamps
            (54, 128), (144, 126), (222, 128), (316, 126),
            (324, 62), (110, 62),
        ]
    elif tmpl == "train_roof":
        spots = [
            (92, 62), (186, 56), (292, 62),
            (66, 134), (162, 134), (272, 134), (322, 134),
        ]
    elif tmpl == "island_void":
        spots = [
            (96, 62), (148, 60), (224, 66),
            (72, 118), (118, 134), (234, 128), (210, 160),
        ]
    elif tmpl == "canal_water":
        spots = [
            (56, 64), (188, 60), (88, 132),
            (194, 140), (278, 144), (324, 166), (242, 178), (56, 132),
        ]
    elif tmpl == "cavern":
        spots = [
            (86, 66), (196, 62), (288, 72),
            (68, 122), (186, 152), (276, 154), (318, 140),
        ]
    else:
        spots = [
            (60, 60), (196, 54), (282, 56),
            (56, 142), (186, 154), (314, 140), (272, 178), (104, 150),
        ]

    # Separate ground-layer medallions from upright sort-layer props
    placed_ground: list[tuple[str, int, int]] = []
    placed_sort: list[tuple[str, int, int]] = []

    # Pick up to len(spots) distinct props showcasing landmarks, lights, and decor
    idx = 0
    for sx, sy in spots:
        if idx >= len(keys):
            break
        k = keys[idx]
        idx += 1
        # Keep train_window_* mounted cleanly along the north carriage wall (y=36)
        if k.startswith("train_window_"):
            placed_sort.append((k, sx, 38))
            continue
        if not _is_walkable_px(grid, sx, sy):
            continue
        info = props_dict[k]
        fw, fh = info["frame"]
        # Skip huge archways if they would clip out of top edge
        if fh >= 44 and sy < 52:
            sy = 64
        if k.endswith(("_seal", "_dial", "_pool", "_hatch", "_crest", "_emblem", "_medallion", "_rug", "_floor", "_basin", "_trough", "_starfish")):
            placed_ground.append((k, sx, sy))
        else:
            placed_sort.append((k, sx, sy))

    def _stamp(k: str, x: int, y: int, shadow: bool) -> None:
        info = props_dict[k]
        rx, ry, rw, rh = info["rects"][0]
        ax, ay = info["anchor"]
        sprite = atlas_im.crop((rx, ry, rx + rw, ry + rh))
        if shadow:
            # Subtle Last Light pixel-dithered dark shadow ellipse under upright prop
            sh_rx = max(3, min(14, int(rw * 0.32)))
            sh_ry = max(2, min(4, int(rw * 0.10)))
            px = out.load()
            for yy in range(max(0, y - sh_ry), min(out.height, y + sh_ry + 1)):
                for xx in range(max(0, x - sh_rx + 1), min(out.width, x + sh_rx + 2)):
                    if ((xx - (x + 1)) / float(sh_rx)) ** 2 + ((yy - y) / float(sh_ry)) ** 2 <= 1.0:
                        if ((xx + yy) & 1) == 0:
                            px[xx, yy] = RGBA["night"]
        out.alpha_composite(sprite, (int(x - ax), int(y - ay)))

    for k, x, y in placed_ground:
        _stamp(k, x, y, shadow=False)
    for k, x, y in sorted(placed_sort, key=lambda t: t[2]):
        _stamp(k, x, y, shadow=not k.startswith("train_window_"))

    return out


def render_all() -> dict[str, float]:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    tids = list_themes()
    timings: dict[str, float] = {}
    cards: list[tuple[str, Image.Image]] = []

    for tid in tids:
        spec = get_spec(tid)
        tmpl_name = _template_for(tid)
        rows, exits = TEMPLATES[tmpl_name]
        grid = _parse_rows(rows)
        decor = _decor_for(tid, tmpl_name)
        meta = {"exits": exits, "decor": decor, "theme": tid}

        t0 = time.perf_counter()
        painter = get_theme(tid)
        ground_im = painter.paint(grid, ts=16, meta=meta)
        dt_ms = (time.perf_counter() - t0) * 1000.0
        timings[tid] = dt_ms

        comp_1x = _composite_props(ground_im, grid, spec.prop_sheet, tmpl_name)
        verify_image_palette(comp_1x, f"preview_1x:{tid}")

        # 2x nearest render with crisp header bar
        up = comp_1x.resize((comp_1x.width * 2, comp_1x.height * 2), Image.Resampling.NEAREST)
        bar_h = 22
        card = Image.new("RGBA", (up.width, up.height + bar_h), RGBA["void"])
        card.paste(up, (0, bar_h))
        draw = ImageDraw.Draw(card)
        draw.rectangle([0, 0, up.width - 1, bar_h - 1], fill=RGBA["night"])
        draw.line([(0, bar_h - 1), (up.width - 1, bar_h - 1)], fill=RGBA[spec.rim_hi])
        label = f" {tid}  |  {spec.name}  (Isl {spec.island})  [{dt_ms:.0f} ms]  sheet:{spec.prop_sheet}"
        draw.text((4, 5), label, fill=RGBA["cream"])
        card.save(PREVIEW_DIR / f"{tid}.png")
        cards.append((tid, card))

    # Build 4 crisp review contact sheets (11-12 themes per sheet, 3 columns, 1x room + label) AND one master sheet
    def _save_sheet(subset: list[tuple[str, Image.Image]], path: Path, cols: int = 3, scale_half: bool = True) -> None:
        if not subset:
            return
        sample = subset[0][1]
        cw = sample.width // 2 if scale_half else sample.width
        ch = sample.height // 2 if scale_half else sample.height
        pad = 6
        rows_n = (len(subset) + cols - 1) // cols
        sh = Image.new("RGBA", (pad + cols * (cw + pad), pad + rows_n * (ch + pad)), RGBA["void"])
        for idx, (tid, card) in enumerate(subset):
            r, c = divmod(idx, cols)
            thumb = card.resize((cw, ch), Image.Resampling.NEAREST) if scale_half else card
            sh.paste(thumb, (pad + c * (cw + pad), pad + r * (ch + pad)))
        sh.save(path)

    # Full-detail 2x-card sheets (3x4 = 12 per sheet -> 4 sheets covering all 43 themes!)
    chunk = 12
    for s_idx in range(0, len(cards), chunk):
        part = cards[s_idx : s_idx + chunk]
        _save_sheet(part, PREVIEW_DIR / f"_contact_sheet_{s_idx // chunk + 1}.png", cols=3, scale_half=True)

    # Master single contact sheet (all 43 themes, 6 columns)
    _save_sheet(cards, PREVIEW_DIR / "_contact_sheet.png", cols=6, scale_half=True)

    # Dynamic layers proof (base locks room + ebb seabed tile patch + midnight tint + black world flip)
    rows_l, exits_l = TEMPLATES["canal_water"]
    grid_l = _parse_rows(rows_l)
    meta_l = {
        "exits": exits_l,
        "decor": _decor_for("locks", "canal_water"),
        "layers": [
            {"id": "tide_ebb", "when": "tide==ebb", "tiles": [[14, 2, 6, 6, "ground"], [4, 9, 4, 3, "ground"]], "theme": "seabed"},
            {"id": "midnight", "when": "clock==midnight", "tint": "midnight"},
            {"id": "black_world", "when": "world==black", "theme": "inverted_palace_black"},
        ],
    }
    base_p = PREVIEW_DIR / "_tmp_layer_base_ground.png"
    base_im = get_theme("locks").paint(grid_l, ts=16, meta=meta_l)
    base_im.save(base_p)
    lpaths = paint_layers(grid_l, base_p, get_theme("locks"), meta_l, get_theme, ts=16)

    # Composite 4 panels side-by-side (base + 3 layers) into _layers_proof.png
    panels: list[tuple[str, Image.Image]] = [("BASE: locks", base_im)]
    for lp in lpaths:
        ov = Image.open(lp).convert("RGBA")
        comp = base_im.copy()
        comp.alpha_composite(ov)
        panels.append((f"LAYER: {lp.name}", comp))
    pw, ph = base_im.width, base_im.height
    proof = Image.new("RGBA", (pw * 2 + 12, (ph + 18) * 2 + 12), RGBA["void"])
    dr = ImageDraw.Draw(proof)
    for i, (lbl, pim) in enumerate(panels[:4]):
        rr, cc = divmod(i, 2)
        ox = 4 + cc * (pw + 4)
        oy = 4 + rr * (ph + 18 + 4)
        dr.rectangle([ox, oy, ox + pw - 1, oy + 17], fill=RGBA["night"])
        dr.text((ox + 4, oy + 4), lbl, fill=RGBA["gold"])
        proof.paste(pim, (ox, oy + 18))
    proof.save(PREVIEW_DIR / "_layers_proof.png")
    # Clean temporary layer files in preview dir
    base_p.unlink(missing_ok=True)
    for lp in lpaths:
        lp.unlink(missing_ok=True)

    max_ms = max(timings.values())
    avg_ms = sum(timings.values()) / len(timings)
    print(f"Rendered {len(tids)} theme previews + 5 contact sheets + layers proof into {PREVIEW_DIR}")
    print(f"Paint timing: avg={avg_ms:.1f} ms, max={max_ms:.1f} ms (budget < 3000 ms)")
    return timings


if __name__ == "__main__":
    render_all()
