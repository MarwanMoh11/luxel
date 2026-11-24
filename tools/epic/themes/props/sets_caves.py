"""Per-island subterranean cave scenery atlases: theme_cave_1 through theme_cave_8."""
from __future__ import annotations

from PIL import Image

from .draw_kit import (
    PCanvas,
    PropDef,
    anim_prop,
    draw_archway,
    draw_brazier,
    draw_floor_medallion,
    draw_lantern_post,
    draw_urn,
    static_prop,
)


_CAVE_PALETTES: list[tuple[int, str, str, str, str, str, str, str]] = [
    # (island, label, rock_dk, rock_mid, rock_hi, vein_mid, vein_hi, glow_hi)
    (1, "Bell Isle Grotto", "night", "dusk", "mauve", "apricot", "gold", "gold"),
    (2, "Tidewater Sea Cave", "night", "deep", "teal", "sky", "ice", "ice"),
    (3, "Thornwood Root Burrow", "night", "pine", "teal", "jade", "lime", "lime"),
    (4, "Mirefen Sunken Cistern", "deep", "pine", "teal", "sky", "ice", "ice"),
    (5, "Starfall Geode Cavern", "night", "deep", "blue", "sky", "gold", "ice"),
    (6, "Ashen Kiln Lava Tube", "void", "dusk", "plum", "coral", "apricot", "gold"),
    (7, "Moon Shoals Ice Grotto", "deep", "blue", "sky", "ice", "cream", "cream"),
    (8, "Long Night Obsidian Hollow", "void", "night", "plum", "wine", "rose", "gold"),
]


def _stalagmite(w: int, h: int, dk: str, mid: str, hi: str, vein: str, cluster: bool = False) -> Image.Image:
    c = PCanvas(w - 2, h - 2)
    cw, ch = c.w, c.h
    spires = [(cw // 2, ch - 2, cw // 3)] if not cluster else [(cw // 4 + 1, ch - 8, 4), (cw // 2, ch - 2, 5), (3 * cw // 4 - 1, ch - 6, 4)]
    for sx, sh, sw in spires:
        top = max(1, ch - sh)
        for y in range(top, ch):
            t = (y - top) / max(1.0, float(ch - top))
            hw = max(1, int(round(sw * t)))
            for x in range(sx - hw, sx + hw + 1):
                col = hi if x < sx else (dk if x > sx + 1 else mid)
                c.set(x, y, col)
        c.set(sx, top + 2, vein)
        c.set(sx - 1, top + 5, vein)
    return c.finalize(w, h)


def _mineral_vein(f: int, dk: str, mid: str, v_mid: str, v_hi: str) -> Image.Image:
    c = PCanvas(22, 24)
    c.shaded_ellipse(11, 16, 8.0, 6.0, dk, mid, v_mid)
    # Sparkling crystals / veins protruding
    for idx, (cx, cy, h) in enumerate(((6, 13, 6), (11, 10, 9), (16, 13, 7))):
        for y in range(cy - h, cy):
            c.set(cx, y, v_hi if ((y + f + idx) % 2 == 0) else v_mid)
            c.set(cx + 1, y + 1, v_mid)
        if (f + idx) % 2 == 0:
            c.set(cx, cy - h, "cream")
    return c.finalize(24, 26)


def _cave_shroom(f: int, cap_dk: str, cap_mid: str, cap_hi: str) -> Image.Image:
    c = PCanvas(18, 20)
    c.bevel(7, 10, 4, 8, "mauve", "stone", "dusk")
    c.shaded_ellipse(9, 8, 6.5, 4.0, cap_dk, cap_mid, cap_hi)
    if f % 2 == 0:
        c.set(7, 7, "cream")
        c.set(11, 8, cap_hi)
    else:
        c.set(9, 6, "cream")
    return c.finalize(20, 22)


def _boulder(dk: str, mid: str, hi: str, vein: str) -> Image.Image:
    c = PCanvas(22, 18)
    c.shaded_ellipse(11, 11, 8.5, 5.5, dk, mid, hi)
    c.line(7, 10, 14, 13, vein)
    c.set(8, 8, hi)
    return c.finalize(24, 20)


def _cairn(dk: str, mid: str, hi: str, accent: str) -> Image.Image:
    c = PCanvas(16, 22)
    c.shaded_ellipse(8, 17, 6.0, 2.8, dk, mid, hi)
    c.shaded_ellipse(8, 12, 4.5, 2.4, dk, mid, hi)
    c.shaded_ellipse(8, 8, 3.2, 2.0, dk, mid, hi)
    c.set(8, 5, accent)
    return c.finalize(18, 24)


def build_cave_sets() -> list[tuple[str, str, list[PropDef]]]:
    out: list[tuple[str, str, list[PropDef]]] = []
    for isl, label, r_dk, r_mid, r_hi, v_mid, v_hi, g_hi in _CAVE_PALETTES:
        props: list[PropDef] = [
            static_prop("stalagmite_tall", _stalagmite(18, 32, r_dk, r_mid, r_hi, v_hi, False), role="cover", placement="cavern flanks and choke points"),
            static_prop("stalagmite_cluster", _stalagmite(26, 26, r_dk, r_mid, r_hi, v_mid, True), role="cover", placement="alcoves and rock walls"),
            static_prop("cave_arch_rock", draw_archway(46, 44, r_dk, r_mid, r_hi, v_mid, v_hi), role="landmark", placement="cavern entrances"),
            anim_prop("glow_mineral_vein", lambda f, a=r_dk, b=r_mid, c=v_mid, d=v_hi: _mineral_vein(f, a, b, c, d), 4, 300.0, role="light", placement="along cave walls"),
            anim_prop("cave_lantern_post", lambda f, a=r_dk, b=r_mid, c=r_hi, d=v_mid, e=g_hi: draw_lantern_post(18, 28, a, b, c, d, e, f), 4, 260.0, role="light", placement="trail bends and exits"),
            anim_prop("cavern_brazier_bowl", lambda f, a=r_dk, b=r_mid, c=r_hi, d=v_mid, e=v_hi, g=g_hi: draw_brazier(20, 24, a, b, c, f, c_out=d, c_mid=e, c_hi=g), 4, 240.0, role="light", placement="shrine clearings"),
            static_prop("mossy_boulder_large", _boulder(r_dk, r_mid, r_hi, v_mid), role="cover", placement="open cave pockets"),
            static_prop("rock_cairn_marker", _cairn(r_dk, r_mid, r_hi, v_hi), role="decor", placement="forking cave trails"),
            anim_prop("dripping_pool_basin", lambda f, a=r_dk, b=v_mid, c=v_hi, d=g_hi: draw_floor_medallion(24, 20, a, b, c, d, f), 2, 420.0, layer="ground", role="ambient", placement="damp floor depressions"),
            anim_prop("subterranean_shroom", lambda f, a=r_mid, b=v_mid, c=v_hi: _cave_shroom(f, a, b, c), 4, 320.0, role="ambient", placement="rock bases and corners"),
        ]
        out.append((f"theme_cave_{isl}", f"{label} Cave Scenery", props))
    return out
