#!/usr/bin/env python3
"""Generate the 32 12x12 stained-glass pane icons in the strict 20-colour Last Light palette.

Outputs:
  luxel/art/ui/panes.png   (96x48 sprite sheet, 8 columns x 4 rows of 12x12 icons)
  luxel/art/ui/panes.json  (metadata & rects compatible with LxSpriteSheet + LxPanesMenu)

Run via:
  uv run --no-project --with pillow python tools/epic/pane_icons.py
"""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "luxel" / "art" / "ui"

HEX = {
    "void": "#0d0b1e", "night": "#211a3b", "dusk": "#3d2c5c", "plum": "#6a3d6f",
    "wine": "#a0466a", "coral": "#e2725b", "apricot": "#f5a96a", "gold": "#ffd98c",
    "cream": "#fff4dc", "pine": "#1d3d4c", "teal": "#2b6b68", "jade": "#4c9e78",
    "lime": "#a3cf7d", "deep": "#263873", "blue": "#3e6db0", "sky": "#78a9da",
    "ice": "#c7e5ef", "mauve": "#8a6e91", "stone": "#c2a7ae", "rose": "#ec9fa8",
}

def _rgba(name: str) -> tuple[int, int, int, int]:
    h = HEX[name].lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)

PAL = {k: _rgba(k) for k in HEX}
TRANS = (0, 0, 0, 0)
VALID_RGBA = set(PAL.values()) | {TRANS}

# Island glass ramps: (dark_glass, mid_glass, hi_glass, core_glint)
ISLAND_RAMPS = {
    1: ("wine", "coral", "gold", "cream"),      # Bell Isle: warm brass & amber
    2: ("deep", "blue", "sky", "ice"),          # Tidewater: sea glass & foam
    3: ("pine", "teal", "jade", "lime"),        # Thornwood: living emerald
    4: ("teal", "sky", "rose", "cream"),        # Mirefen: dusk glass & petal
    5: ("deep", "blue", "gold", "cream"),       # Starfall: indigo & starlight
    6: ("wine", "coral", "apricot", "gold"),    # Ashen Kiln: ember & molten brass
    7: ("dusk", "blue", "ice", "cream"),        # Moon Shoals: silver mirror
    8: ("night", "plum", "rose", "gold"),       # Long Night: eclipse & dawn
}

# 8x8 inner motifs centered inside the 12x12 leaded stained-glass frame (pixels 2..9).
# Characters: '.' bg glass, '1' dark, '2' mid, '3' hi, '4' core, 'k' lead line, 'g' gold, 'c' cream, 'r' coral, 'i' ice, 'l' lime
PANES = [
    # Island 1: Bell Isle
    ("bell_clapper", 1, "dungeon", 2, [
        "...44...",
        "..3443..",
        "..3333..",
        ".334433.",
        ".222222.",
        "44444444",
        "...kk...",
        "...44...",
    ]),
    ("vesper_chime", 1, "trial", 1, [
        ".4..4..4",
        "4.3333.4",
        "..3443..",
        ".334433.",
        "..3333..",
        "4..44..4",
        ".4....4.",
        "...44...",
    ]),
    ("toll_echo", 1, "quest", 2, [
        "..4444..",
        ".4....4.",
        "4..33..4",
        "4.3443.4",
        "4.3443.4",
        "4..33..4",
        ".4....4.",
        "..4444..",
    ]),
    ("belfry_weight", 1, "secret", 3, [
        "...44...",
        "..k44k..",
        "..k22k..",
        ".k3333k.",
        ".k3443k.",
        "k233332k",
        "k222222k",
        ".kkkkkk.",
    ]),
    # Island 2: Tidewater Harbor
    ("rip_tide", 2, "dungeon", 2, [
        "..4444..",
        ".43..34.",
        "43.44.3.",
        "3.4..4.3",
        "3.4..4.3",
        ".3.44.34",
        ".43..34.",
        "..4444..",
    ]),
    ("sea_glass", 2, "trial", 1, [
        "4.......",
        ".4......",
        "..43....",
        "...34...",
        "....43..",
        "...34...",
        "..43....",
        "44......",
    ]),
    ("harbor_wake", 2, "quest", 2, [
        "........",
        ".3443...",
        "34..43..",
        "..34434.",
        ".34..434",
        "343343..",
        ".3..344.",
        "........",
    ]),
    ("anchor_lead", 2, "secret", 3, [
        "...44...",
        "..4kk4..",
        "...44...",
        ".334433.",
        "...44...",
        "4..44..4",
        "43.44.34",
        ".444444.",
    ]),
    # Island 3: Thornwood Hollow
    ("ember_seed", 3, "dungeon", 2, [
        "...4....",
        "..343...",
        ".34c43..",
        ".3rcr3..",
        ".23r32..",
        "..232...",
        "...2....",
        "..3.3...",
    ]),
    ("briar_thorn", 3, "trial", 1, [
        "4..33..4",
        ".4.33.4.",
        "..3443..",
        "334cc433",
        "334cc433",
        "..3443..",
        ".4.33.4.",
        "4..33..4",
    ]),
    ("vine_snare", 3, "quest", 2, [
        ".44..44.",
        "4.3443.4",
        "4.3..3.4",
        ".3.44.3.",
        ".3.44.3.",
        "4.3..3.4",
        "4.3443.4",
        ".44..44.",
    ]),
    ("canopy_dew", 3, "secret", 3, [
        "...4....",
        "..343...",
        ".34443..",
        ".34c43..",
        "3344433.",
        "3334333.",
        ".23332..",
        "..222...",
    ]),
    # Island 4: Mirefen Gardens
    ("hourglass_sand", 4, "dungeon", 2, [
        ".444444.",
        "..3gg3..",
        "...33...",
        "...44...",
        "...33...",
        "..3gg3..",
        ".3gggg3.",
        ".444444.",
    ]),
    ("petal_mirror", 4, "trial", 1, [
        "...44...",
        "..4334..",
        ".434434.",
        "434cc434",
        "434cc434",
        ".434434.",
        "..4334..",
        "...44...",
    ]),
    ("dusk_dew", 4, "quest", 2, [
        "..4444..",
        ".422224.",
        "42244224",
        "42244444",
        "42222224",
        "42222224",
        ".422224.",
        "..4444..",
    ]),
    ("rain_prism", 4, "secret", 3, [
        ".4...4..",
        "34..34..",
        "3...3..4",
        "...4..34",
        "..34..3.",
        ".43.....",
        "34...4..",
        "3...34..",
    ]),
    # Island 5: Starfall Observatory
    ("orbit_shard", 5, "dungeon", 2, [
        "....44..",
        "..33..4.",
        ".3..44.3",
        "3..44443",
        "3..44443",
        ".3..44.3",
        "4.33....",
        "44......",
    ]),
    ("comet_tail", 5, "trial", 1, [
        ".....444",
        "....44c4",
        "...34444",
        "..33443.",
        ".2333...",
        "223.....",
        "2.......",
        "........",
    ]),
    ("zenith_lens", 5, "quest", 2, [
        "...4....",
        "...4....",
        "..343...",
        "444c4444",
        "..343...",
        "...4....",
        "...4....",
        "...3....",
    ]),
    ("null_well", 5, "secret", 3, [
        "..3333..",
        ".34kk43.",
        "34k..k43",
        "3k.kk.k3",
        "3k.kk.k3",
        "34k..k43",
        ".34kk43.",
        "..3333..",
    ]),
    # Island 6: Ashen Kiln
    ("cinder_blast", 6, "dungeon", 2, [
        "4..4...4",
        ".3.43.3.",
        "..3443..",
        "434cc434",
        "..3443..",
        ".3.43.3.",
        "4..3...4",
        "........",
    ]),
    ("slag_coat", 6, "trial", 2, [
        ".444444.",
        "43333334",
        "43444434",
        "43433434",
        ".433334.",
        "..4334..",
        "...44...",
        "........",
    ]),
    ("bellows_vent", 6, "quest", 1, [
        "4.......",
        "43......",
        "4343....",
        "434c43..",
        "434c43..",
        "4343....",
        "43......",
        "4.......",
    ]),
    ("anvil_strike", 6, "secret", 3, [
        "........",
        "44444444",
        ".344443.",
        "..3333..",
        "..2332..",
        ".333333.",
        "44444444",
        "........",
    ]),
    # Island 7: Moon Shoals
    ("silver_twin", 7, "dungeon", 3, [
        "........",
        "..4..4..",
        ".43..34.",
        "43444434",
        "43444434",
        ".43..34.",
        "..4..4..",
        "........",
    ]),
    ("moon_phase", 7, "trial", 1, [
        "..444...",
        ".4432...",
        "4432....",
        "443.....",
        "443.....",
        "4432....",
        ".4432...",
        "..444...",
    ]),
    ("glass_step", 7, "quest", 2, [
        "....44..",
        "...434..",
        "..434...",
        ".434..3.",
        "434..34.",
        ".4..34..",
        "...34...",
        "..34....",
    ]),
    ("mirror_ward", 7, "secret", 2, [
        "..4444..",
        ".43ii34.",
        "43i44i34",
        "43i44i34",
        "43i44i34",
        "43i44i34",
        ".43ii34.",
        "..4444..",
    ]),
    # Island 8: The Long Night
    ("toll_wick", 8, "dungeon", 1, [
        "...4....",
        "..4g4...",
        ".4gcg4..",
        ".4ggg4..",
        "..343...",
        "...k....",
        "..343...",
        "..333...",
    ]),
    ("hush_glass", 8, "trial", 2, [
        "..3333..",
        ".3kkkk3.",
        "3kk44kk3",
        "3k4..4k3",
        "3k4..4k3",
        "3kk44kk3",
        ".3kkkk3.",
        "..3333..",
    ]),
    ("dawn_spark", 8, "quest", 3, [
        "...4....",
        "4..g..4.",
        ".g.c.g..",
        "4gc4cg4.",
        ".g.c.g..",
        "4..g..4.",
        "...4....",
        "........",
    ]),
    ("last_glass", 8, "secret", 3, [
        "4..44..4",
        ".433334.",
        "..3kk3..",
        "43kcck34",
        "43kcck34",
        "..3kk3..",
        ".433334.",
        "4..44..4",
    ]),
]

assert len(PANES) == 32, f"Expected 32 panes, got {len(PANES)}"


def draw_pane_icon(island_id: int, motif: list[str]) -> Image.Image:
    img = Image.new("RGBA", (12, 12), TRANS)
    px = img.load()
    c1, c2, c3, c4 = ISLAND_RAMPS[island_id]
    cmap = {
        "1": PAL[c1], "2": PAL[c2], "3": PAL[c3], "4": PAL[c4],
        "k": PAL["night"], "g": PAL["gold"], "c": PAL["cream"],
        "r": PAL["coral"], "i": PAL["ice"], "l": PAL["lime"],
    }
    # Outer beveled stained-glass frame (chamfered corners)
    for y in range(12):
        for x in range(12):
            if (x in (0, 11)) and (y in (0, 11)):
                continue
            if x in (0, 11) or y in (0, 11):
                px[x, y] = PAL["void"]
            elif x in (1, 10) or y in (1, 10):
                # Brass/lead bevel: brighter top-left, darker bottom-right
                if x == 1 or y == 1:
                    px[x, y] = PAL[c3] if (x + y) % 3 == 0 else PAL["mauve"]
                else:
                    px[x, y] = PAL["dusk"]
            else:
                # Diagonal leaded stained glass tint gradient
                d = (x - 2) + (y - 2)
                if d <= 3:
                    px[x, y] = PAL[c2]
                elif d <= 10:
                    px[x, y] = PAL[c1]
                else:
                    px[x, y] = PAL["night"]
    # Corner glass catchlight
    px[2, 2] = PAL[c3]
    px[3, 2] = PAL[c2]
    px[2, 3] = PAL[c2]

    # Paint 8x8 central motif
    for my in range(8):
        row = motif[my]
        for mx in range(8):
            ch = row[mx]
            if ch != ".":
                px[2 + mx, 2 + my] = cmap[ch]

    # Subtle lead corner rivets on inner frame
    px[1, 1] = PAL["gold"]
    px[10, 1] = PAL["gold"]
    px[1, 10] = PAL["dusk"]
    px[10, 10] = PAL["night"]
    return img


def verify_palette(img: Image.Image) -> None:
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c not in VALID_RGBA:
                raise ValueError(f"Off-palette or semi-transparent pixel at ({x},{y}): {c}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cols, rows = 8, 4
    sheet = Image.new("RGBA", (cols * 12, rows * 12), TRANS)
    icons_meta: dict[str, dict] = {}
    props_meta: dict[str, dict] = {}

    for idx, (pid, isl, src, lead, motif) in enumerate(PANES):
        icon = draw_pane_icon(isl, motif)
        cx = (idx % cols) * 12
        cy = (idx // cols) * 12
        sheet.paste(icon, (cx, cy))
        icons_meta[pid] = {
            "index": idx,
            "island": isl,
            "source": src,
            "lead": lead,
            "rect": [cx, cy, 12, 12],
        }
        props_meta[pid] = {
            "rects": [[cx, cy, 12, 12]],
            "ms": [200],
            "loop": False,
            "anchor": [6, 6],
        }

    verify_palette(sheet)
    png_path = OUT_DIR / "panes.png"
    json_path = OUT_DIR / "panes.json"
    sheet.save(png_path)
    meta = {
        "sheet": "panes.png",
        "icon_size": [12, 12],
        "grid": [cols, rows],
        "count": len(PANES),
        "anchor": [6, 6],
        "icons": icons_meta,
        "props": props_meta,
    }
    json_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {png_path} ({sheet.size[0]}x{sheet.size[1]}) and {json_path} ({len(PANES)} panes, palette OK)")


if __name__ == "__main__":
    main()
