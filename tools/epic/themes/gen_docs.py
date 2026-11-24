#!/usr/bin/env python3
"""Generate docs/fullgame/epic/THEMES.md directly from the live theme registry and prop atlases."""
from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.epic.themes import ALIASES, get_spec, list_themes
from tools.epic.themes.props.build_all import collect_all_sets

OUT_DOC = REPO_ROOT / "docs" / "fullgame" / "epic" / "THEMES.md"


def generate() -> Path:
    tids = list_themes()
    prop_sets = collect_all_sets()
    prop_map = {sid: (title, props) for sid, title, props in prop_sets}

    lines: list[str] = []
    lines.append("# Luxel Epic: Theme Painting, Dynamic Layers & Scenery Reference")
    lines.append("")
    lines.append("Owner: **E0-7 THEMES**. Strict 20-colour Last Light palette (`docs/ART_STYLE.md`, 0 off-palette, 0 semi-transparent pixels).")
    lines.append(f"Total registered themes: **{len(tids)}** (+ {len(ALIASES)} aliases) | Scenery atlases: **{len(prop_sets)}** ({sum(len(p) for _, _, p in prop_sets)} props) | Door atlases: **35**.")
    lines.append("")
    lines.append("## 1. How to paint a themed room")
    lines.append("")
    lines.append("```bash")
    lines.append("# CLI override (or omit --theme to read `\"theme\"` automatically from the sibling <region>.json)")
    lines.append("uv run --no-project --with pillow --with numpy python docs/fullgame/swarm/tools/maps/paint.py \\")
    lines.append("    luxel/islands/2/galleon_r1.map luxel/art/islands/2/galleon_r1_ground.png --theme galleon")
    lines.append("")
    lines.append("# List all available theme IDs")
    lines.append("uv run --no-project --with pillow --with numpy python docs/fullgame/swarm/tools/maps/paint.py --list-themes")
    lines.append("```")
    lines.append("")
    lines.append("Average paint speed: **~20–26 ms** per 24x14 room (384x224 px) — well under the 3 s budget.")
    lines.append("")
    lines.append("### Region JSON keys consumed by `paint.py`")
    lines.append("- `\"theme\": \"<theme_id>\"` — selects the Epic theme automatically when `--theme` is not passed on CLI.")
    lines.append("- `\"decor\": [ ... ]` — focal composition hints painted directly into the ground PNG (see section 3).")
    lines.append("- `\"layers\": [ ... ]` — dynamic layer overlays painted automatically to `<region>__<layer_id>.png` (see section 4).")
    lines.append("- `\"exits\": [{\"rect\": [x, y, w, h], ...}]` — doorway jamb pillars and threshold sills.")
    lines.append("")
    lines.append("### Aliases")
    for alias, target in sorted(ALIASES.items()):
        lines.append(f"- `{alias}` -> `{target}`")
    lines.append("")

    lines.append("## 2. Theme Catalogue (all 44 themes)")
    lines.append("")
    lines.append("Standard `.map` tile chars supported by every theme: `.` ground, `#` wall, `,` path, `~` water, `O` pit, `_` void, `+` bridge, `G` glass, `T` tide, `P` phantom (zero-ghost void), `B` bramble (clean ground underneath), `C` cracked (clean ground underneath).")
    lines.append("")
    lines.append("Optional architectural tile chars (built into `DEFAULT_LEGEND` in `paint.py`): `D` carpet/dais, `S` stairs, `H` grate/hearth, `R` rail/track, `M` mirror, `F` foliage wall.")
    lines.append("")
    lines.append("| Theme ID | Name | Isl | Floor / Wall / Water / Pit Language | Special Tiles | Prop Sheet | Door Sheet | Recommended Decor |")
    lines.append("|---|---|---:|---|---|---|---|---|")
    for tid in tids:
        s = get_spec(tid)
        lang = f"{s.floor_style} / {s.wall_style} / {s.water_style} / {s.pit_style}"
        st = ", ".join(s.special_tiles) if s.special_tiles else "standard"
        dec = ", ".join(s.default_decor) if s.default_decor else "circle, light_shaft"
        lines.append(f"| `{tid}` | {s.name} | {s.island} | {lang} | {st} | `{s.prop_sheet}` | `{s.door_sheet}` | {dec} |")
    lines.append("")

    lines.append("## 3. Focal Composition `decor` Hints (Region JSON)")
    lines.append("")
    lines.append("Add a `\"decor\"` array in `<region>.json` to paint asymmetric focal art directly onto walkable ground (never leaks onto void/water/walls unless `window_strip`):")
    lines.append("")
    lines.append("| `kind` | Parameters | Visual Effect |")
    lines.append("|---|---|---|")
    lines.append("| `rug` | `rect:[x,y,w,h]`, `style:\"ornate\"\\|\"hearth\"`, optional `color`,`trim`,`edge`,`hi` | Bordered diamond-medallion carpet or braided oval hearth rug |")
    lines.append("| `circle` | `pos:[x,y]`, `radius:r`, `style:\"ritual\"\\|\"astrolabe\"\\|\"clock\"\\|\"mosaic\"\\|\"spotlight\"\\|\"gear\"`, optional `color`,`secondary` | Concentric inlaid medallion or warm stage spotlight wash |")
    lines.append("| `compass` | `pos:[x,y]`, `radius:r`, optional `color`,`secondary` | 8-point inlaid brass/stone compass rose with center cream jewel |")
    lines.append("| `mural` | `pos:[x,y]`, `radius:r`, `style:\"sun\"\\|\"moon\"\\|\"constellation\"\\|\"crest\"` | Stylized geometric floor inlay medallion |")
    lines.append("| `cracks` | `pos:[x,y]`, `radius:r`, `glow:bool` | 5 jagged radiating floor fracture lines (optional molten/mineral glow) |")
    lines.append("| `stain` | `pos:[x,y]`, `radius:r`, `style:\"water\"\\|\"moss\"\\|\"ink\"\\|\"soot\"\\|\"acid\"\\|\"petal\"\\|\"sand\"` | Soft Bayer-dithered organic floor pool or scatter |")
    lines.append("| `light_shaft` | `pos:[x,y]`, `size:[w,h]`, `tint:\"warm\"\\|\"cool\"\\|\"rose\"\\|\"lime\"`, `shear:0.45` | Angled cathedral/window light beam stepping floor pixels lighter |")
    lines.append("| `grate` | `rect:[x,y,w,h]`, `glow:bool` | Recessed iron floor grating (optional fiery furnace glow beneath) |")
    lines.append("| `inlay` | `rect:[x,y,w,h]`, optional `color` | Crisp architectural border inlay framing a dais or arena |")
    lines.append("| `window_strip` | `y:py`, `x0:px`, `x1:px`, `style:\"sunset\"\\|\"slag\"\\|\"stars\"\\|\"rain\"` | Recessed glowing mullioned window strip along a north wall |")
    lines.append("")

    lines.append("## 4. Dynamic Layer Overlays (`<region>__<layer_id>.png`)")
    lines.append("")
    lines.append("When a region JSON contains `\"layers\"`, `paint.py` automatically writes `<region>__<id>.png` alongside `<region>_ground.png` (pass `--no-layers` to skip):")
    lines.append("")
    lines.append("```json")
    lines.append("\"layers\": [")
    lines.append("  {\"id\": \"tide_ebb\", \"when\": \"tide==ebb\", \"tiles\": [[14, 2, 6, 6, \"ground\"]], \"theme\": \"seabed\"},")
    lines.append("  {\"id\": \"midnight\", \"when\": \"clock==midnight\", \"tint\": \"midnight\"},")
    lines.append("  {\"id\": \"black_world\", \"when\": \"world==black\", \"theme\": \"inverted_palace_black\", \"full_frame\": true}")
    lines.append("]")
    lines.append("```")
    lines.append("- **Partial tile-patch layer** (`tiles` non-empty, `full_frame` false): paints ONLY the patched tiles + a 4px rim/AO margin at alpha=255; untouched pixels are alpha=0 so it composites cleanly over the base ground.")
    lines.append("- **Full-frame layer** (`tint:\"midnight\"`, `full_frame:true`, or empty `tiles` with `theme`): paints the entire room in the alternate palette or world theme.")
    lines.append("- Visual proof: `docs/fullgame/epic/themes_preview/_layers_proof.png`.")
    lines.append("")

    lines.append("## 5. Scenery Prop Atlases (`luxel/art/props/theme_<id>.{png,json}`)")
    lines.append("")
    lines.append("Use in region JSON `\"scenery\"`: `{\"sheet\": \"theme_undercroft\", \"prop\": \"crypt_coffin\", \"pos\": [96, 80], \"layer\": \"sort\"}`.")
    lines.append("Prop names follow `LxSceneryProp` (`luxel/world/scenery_prop.gd`) resonant/foliage naming hooks so bolt-graze ripples, chimes, and flake particles activate automatically.")
    lines.append("")
    for sid, (title, props) in prop_map.items():
        lines.append(f"### `{sid}` — {title} ({len(props)} props)")
        lines.append("")
        lines.append("| Prop Key | Size (px) | Anchor | Frames | Layer | Role | Placement |")
        lines.append("|---|---:|---|---:|---|---|---|")
        for p in props:
            fw, fh = p.frames[0].size
            lines.append(f"| `{p.key}` | {fw}x{fh} | [{p.anchor[0]}, {p.anchor[1]}] | {len(p.frames)} | `{p.layer}` | {p.role} | {p.placement} |")
        lines.append("")

    lines.append("## 6. Door Skins (`luxel/art/props/theme_<id>_doors.{png,json}`)")
    lines.append("")
    lines.append("Generated via `tools/epic/themes/build_theme_doors.py` (imports `luxel/art/tools/build_doors.py` read-only) for every primary theme and all 8 caves (35 door atlases total), matching the exact `island*_doors` sprite key contract (`wick_key_h/v`, `boss_key_h/v`, `switch_door_*`, `combat_gate_*`, `ward_barrier_*`, `opened_jamb_*`, `bridge_tile`).")
    lines.append("")

    lines.append("## 7. Adding a New Theme")
    lines.append("")
    lines.append("1. Define a `ThemeSpec` (and optional `ThemePainter` subclass overriding `paint_post` or any stage) in `tools/epic/themes/*.py` and register it in `tools/epic/themes/registry.py`.")
    lines.append("2. Add a 10–14 prop set in `tools/epic/themes/props/` and run `build_all.py` + `build_theme_doors.py`.")
    lines.append("3. Run `render_previews.py` to generate `docs/fullgame/epic/themes_preview/<id>.png` and inspect it visually with `read_file`.")
    lines.append("4. Run `docs/fullgame/swarm/tools/audits/palette.py` to verify 0 off-palette and 0 semi-transparent pixels.")
    lines.append("")

    OUT_DOC.parent.mkdir(parents=True, exist_ok=True)
    OUT_DOC.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT_DOC} ({len(lines)} lines)")
    return OUT_DOC


if __name__ == "__main__":
    generate()
