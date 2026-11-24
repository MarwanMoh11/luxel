"""Scenery prop atlases for Islands 1 & 2 themes:
theme_undercroft, theme_manor, theme_great_toll_shaft, theme_galleon, theme_locks,
theme_leviathan_belly, theme_seabed.
"""
from __future__ import annotations

import math
from PIL import Image

from .draw_kit import (
    PCanvas,
    PropDef,
    anim_prop,
    draw_archway,
    draw_banner,
    draw_brazier,
    draw_flame,
    draw_floor_medallion,
    draw_gear,
    draw_lantern_post,
    draw_pillar,
    draw_urn,
    static_prop,
)


def _coffin(opened: bool = False) -> Image.Image:
    c = PCanvas(18, 26)
    # Hexagonal stone coffin body
    c.bevel(3, 2, 12, 22, "dusk", "mauve", "night")
    c.bevel(2, 6, 14, 14, "dusk", "mauve", "night")
    if opened:
        c.rect(5, 5, 8, 16, "void")
        c.hline(6, 11, 8, "stone")
        c.hline(7, 10, 11, "mauve")
        c.hline(7, 10, 14, "mauve")
        # Lid leaned aside
        c.bevel(12, 4, 5, 20, "mauve", "stone", "dusk")
    else:
        # Carved lid cross & bronze rivets
        c.vline(8, 5, 19, "stone")
        c.vline(9, 5, 19, "mauve")
        c.hline(5, 12, 9, "stone")
        c.set(4, 4, "gold")
        c.set(13, 4, "gold")
        c.set(4, 21, "gold")
        c.set(13, 21, "gold")
    return c.finalize(20, 28)


def _pew() -> Image.Image:
    c = PCanvas(30, 16)
    # Wooden bench back & seat
    c.bevel(2, 2, 26, 7, "plum", "wine", "night")
    c.bevel(1, 8, 28, 5, "wine", "coral", "plum")
    c.bevel(2, 12, 4, 4, "dusk", "mauve", "night")
    c.bevel(24, 12, 4, 4, "dusk", "mauve", "night")
    for x in range(6, 25, 6):
        c.vline(x, 3, 7, "night")
    return c.finalize(32, 18)


def _candelabra(f: int, metal_dk: str = "dusk", metal_hi: str = "gold", flame_c: str = "gold") -> Image.Image:
    c = PCanvas(18, 28)
    cx = 9
    c.bevel(cx - 3, 24, 7, 3, metal_dk, metal_hi, "night")
    c.vline(cx, 9, 24, metal_hi)
    c.vline(cx - 1, 10, 24, metal_dk)
    # Three candle arms
    c.hline(3, 15, 12, metal_hi)
    for ax, ay in ((3, 8), (cx, 6), (15, 8)):
        c.vline(ax, ay + 1, 12, "cream")
        c.set(ax, ay, "stone")
        draw_flame(c, ax, ay - 2, (f + ax) % 4, c_out="coral", c_mid="apricot", c_hi=flame_c, tall=3)
    return c.finalize(20, 30)


def _bell_stand(f: int) -> Image.Image:
    c = PCanvas(22, 28)
    # Timber & bronze bell frame
    c.bevel(2, 23, 18, 4, "dusk", "mauve", "night")
    c.bevel(3, 3, 3, 21, "plum", "coral", "night")
    c.bevel(16, 3, 3, 21, "plum", "coral", "night")
    c.bevel(2, 2, 18, 3, "wine", "apricot", "night")
    sway = (-1, 0, 1, 0)[f % 4]
    bx = 11 + sway
    c.bevel(bx - 3, 7, 7, 8, "apricot", "gold", "coral")
    c.hline(bx - 4, bx + 4, 15, "gold")
    c.set(bx, 17, "cream" if (f % 2 == 0) else "gold")
    return c.finalize(24, 30)


def _portrait(variant: int) -> Image.Image:
    c = PCanvas(20, 26)
    c.bevel(1, 1, 18, 24, "apricot", "gold", "wine")
    c.rect(3, 3, 14, 20, ("deep", "pine", "plum")[variant % 3])
    # Painted nobleman/bellmaker silhouette
    cloak = ("wine", "blue", "teal")[variant % 3]
    c.ellipse(10, 18, 5.0, 5.0, cloak)
    c.shaded_ellipse(10, 10, 3.0, 3.5, "coral", "apricot", "gold")
    # Eyes & hat/collar
    c.set(9, 10, "night")
    c.set(11, 10, "night")
    c.hline(7, 13, 14, "cream")
    if variant == 1:
        c.rect(7, 5, 6, 3, "night")  # top hat
    elif variant == 2:
        c.set(10, 6, "gold")  # crown pin
    return c.finalize(22, 28)


def _grandfather_clock(f: int) -> Image.Image:
    c = PCanvas(18, 36)
    c.bevel(2, 2, 14, 33, "plum", "coral", "night")
    c.bevel(1, 31, 16, 4, "wine", "apricot", "night")
    c.bevel(1, 1, 16, 4, "wine", "gold", "night")
    # Clock dial face
    c.shaded_ellipse(9, 10, 4.5, 4.5, "stone", "cream", "cream")
    c.set(9, 10, "night")
    c.line(9, 10, 9, 7, "night")
    hx = 9 + (2, 0, -2, 0)[f % 4]
    c.line(9, 10, hx, 10, "wine")
    # Glass pendulum window
    c.rect(5, 17, 8, 12, "night")
    px = 9 + (-2, 0, 2, 0)[f % 4]
    c.line(9, 17, px, 26, "apricot")
    c.ellipse(px, 26, 1.8, 1.8, "gold")
    return c.finalize(20, 38)


def _furniture_settee() -> Image.Image:
    c = PCanvas(30, 18)
    c.bevel(2, 2, 26, 9, "wine", "rose", "plum")
    c.bevel(1, 9, 28, 5, "coral", "apricot", "wine")
    c.bevel(1, 5, 4, 11, "plum", "gold", "night")
    c.bevel(25, 5, 4, 11, "plum", "gold", "night")
    c.hline(5, 24, 3, "gold")
    return c.finalize(32, 20)


def _fireplace(f: int) -> Image.Image:
    c = PCanvas(36, 30)
    # Stone hearth surround & mantle
    c.bevel(2, 4, 32, 24, "dusk", "mauve", "night")
    c.bevel(0, 2, 36, 4, "mauve", "stone", "dusk")
    c.hline(1, 34, 3, "gold")
    # Firebox
    c.rect(9, 12, 18, 15, "void")
    c.hline(8, 27, 27, "stone")
    # Logs + animated hearth fire
    c.rect(12, 23, 12, 3, "plum")
    draw_flame(c, 15, 22, f, tall=6)
    draw_flame(c, 20, 22, (f + 2) % 4, tall=7)
    return c.finalize(38, 32)


def _barrel(stacked: bool = False) -> Image.Image:
    c = PCanvas(18, 22 if not stacked else 28)
    def _one(ox: int, oy: int) -> None:
        c.shaded_ellipse(ox + 6, oy + 7, 5.2, 6.2, "plum", "wine", "coral")
        c.hline(ox + 2, ox + 10, oy + 4, "dusk")
        c.hline(ox + 2, ox + 10, oy + 10, "dusk")
        c.ellipse(ox + 6, oy + 2, 4.0, 1.6, "apricot")
    if stacked:
        _one(0, 12)
        _one(5, 12)
        _one(3, 2)
    else:
        _one(3, 6)
    return c.finalize(20, 24 if not stacked else 30)


def _crate(rope: bool = False) -> Image.Image:
    c = PCanvas(18, 18)
    c.bevel(1, 2, 16, 15, "wine", "coral", "plum")
    c.box(2, 3, 14, 13, "night")
    c.line(3, 4, 14, 14, "plum")
    c.line(14, 4, 3, 14, "plum")
    if rope:
        c.ellipse(9, 3, 4.5, 2.0, "apricot")
        c.ellipse(9, 3, 2.5, 1.0, "gold")
    return c.finalize(20, 20)


def _capstan(f: int) -> Image.Image:
    c = PCanvas(24, 24)
    c.bevel(4, 16, 16, 6, "dusk", "mauve", "night")
    c.bevel(7, 6, 10, 12, "wine", "apricot", "plum")
    c.shaded_ellipse(12, 6, 5.5, 2.5, "coral", "apricot", "gold")
    # Turning spokes
    dx = (-4, -1, 4, 1)[f % 4]
    c.line(12 - dx, 6, 12 + dx, 6, "gold")
    c.hline(7, 16, 11, "apricot")
    c.hline(7, 16, 14, "coral")
    return c.finalize(26, 26)


def _anchor() -> Image.Image:
    c = PCanvas(20, 24)
    c.ellipse(10, 4, 2.5, 2.5, "mauve")
    c.set(10, 4, None)
    c.vline(10, 6, 20, "mauve")
    c.vline(9, 6, 19, "stone")
    c.hline(5, 15, 9, "stone")
    # Flukes
    c.line(4, 15, 10, 21, "dusk")
    c.line(16, 15, 10, 21, "dusk")
    c.line(4, 14, 10, 20, "stone")
    c.line(16, 14, 10, 20, "mauve")
    c.set(3, 14, "ice")
    c.set(17, 14, "ice")
    return c.finalize(22, 26)


def _net_rack(f: int) -> Image.Image:
    c = PCanvas(26, 22)
    c.bevel(2, 2, 3, 19, "plum", "coral", "night")
    c.bevel(21, 2, 3, 19, "plum", "coral", "night")
    c.hline(2, 23, 3, "apricot")
    sway = (0, 1, 0, -1)[f % 4]
    for y in range(4, 18):
        for x in range(5, 21):
            if ((x + y + sway) % 4 == 0) or ((x - y + sway) % 4 == 0):
                c.set(x, y, "stone" if y < 11 else "mauve")
    return c.finalize(28, 24)


def _rib_arch() -> Image.Image:
    c = PCanvas(44, 42)
    for side in (-1, 1):
        for t in range(34):
            u = t / 33.0
            x = int(22 + side * (17 * math.cos(u * math.pi * 0.55) + 2))
            y = int(40 - 35 * math.sin(u * math.pi * 0.65))
            c.ellipse(x, y, 2.8, 2.2, "stone" if u > 0.35 else "mauve")
            c.set(x - 1, y - 1, "cream")
    return c.finalize(46, 44)


def _coral_fan(f: int) -> Image.Image:
    c = PCanvas(22, 22)
    cx = 11
    sw = (-1, 0, 1, 0)[f % 4]
    for ang_d in (-55, -28, 0, 28, 55):
        a = math.radians(ang_d - 90)
        for d in range(2, 14):
            x = int(round(cx + math.cos(a) * d + (sw if d > 8 else 0)))
            y = int(round(20 + math.sin(a) * d))
            c.set(x, y, "rose" if d > 9 else ("coral" if d > 5 else "wine"))
            if d % 4 == 0:
                c.set(x + 1, y, "apricot")
    return c.finalize(24, 24)


def build_sets_1_2() -> list[tuple[str, str, list[PropDef]]]:
    # 1. theme_undercroft (12 props)
    undercroft = [
        static_prop("crypt_coffin", _coffin(False), role="obstacle", placement="flanking nave aisles or alcoves"),
        static_prop("open_sarcophagus", _coffin(True), role="landmark", placement="crypt focal niches"),
        static_prop("chapel_pew", _pew(), role="cover", placement="rows along chapel halls"),
        static_prop("crypt_urn", draw_urn(16, 22, "night", "dusk", "mauve", "gold"), role="decor", placement="wall plinths and corners"),
        static_prop("bone_ossuary_arch", draw_archway(46, 48, "night", "dusk", "mauve", "stone", "gold"), role="landmark", placement="north entrance or boss threshold"),
        anim_prop("bronze_bell_stand", _bell_stand, 4, 340.0, role="landmark", placement="echo relay corners"),
        anim_prop("crypt_candelabra", lambda f: _candelabra(f), 4, 240.0, role="light", placement="flanking exits and altars"),
        static_prop("stone_crypt_pillar", draw_pillar(16, 36, "night", "dusk", "mauve", "stone"), role="cover", placement="nave colonnades"),
        anim_prop("tattered_crypt_banner", lambda f: draw_banner(16, 32, "mauve", "night", "plum", "wine", "gold", f), 4, 320.0, role="decor", placement="beside arches"),
        anim_prop("toll_brazier", lambda f: draw_brazier(20, 26, "night", "dusk", "mauve", f), 4, 220.0, role="light", placement="room entry and corners"),
        anim_prop("bell_floor_seal", lambda f: draw_floor_medallion(36, 36, "dusk", "apricot", "gold", "cream", f), 2, 500.0, layer="ground", role="landmark", placement="center of echo rooms"),
        static_prop("mossy_headstone", draw_pillar(16, 22, "night", "dusk", "mauve", "jade", broken=True), role="decor", placement="graveyard crypt edges"),
    ]

    # 2. theme_manor (12 props)
    def _table() -> Image.Image:
        c = PCanvas(30, 18)
        c.bevel(1, 2, 28, 10, "wine", "coral", "plum")
        c.rect(5, 4, 20, 6, "cream")
        c.rect(7, 5, 16, 4, "rose")
        c.vline(3, 12, 17, "night")
        c.vline(26, 12, 17, "night")
        return c.finalize(32, 20)

    def _trolley() -> Image.Image:
        c = PCanvas(20, 18)
        c.bevel(2, 4, 16, 8, "apricot", "gold", "wine")
        c.rect(5, 2, 4, 3, "ice")
        c.rect(11, 2, 3, 3, "cream")
        c.ellipse(5, 14, 2.0, 2.0, "dusk")
        c.ellipse(15, 14, 2.0, 2.0, "dusk")
        return c.finalize(22, 20)

    manor = [
        static_prop("gilded_portrait_a", _portrait(0), role="landmark", placement="north parlor walls (clue portrait A)"),
        static_prop("gilded_portrait_b", _portrait(1), role="landmark", placement="north parlor walls (clue portrait B)"),
        static_prop("gilded_portrait_c", _portrait(2), role="landmark", placement="north parlor walls (clue portrait C)"),
        static_prop("velvet_settee", _furniture_settee(), role="cover", placement="parlor seating areas"),
        anim_prop("tall_grandfather_clock", _grandfather_clock, 4, 300.0, role="landmark", placement="foyer and study walls"),
        anim_prop("brass_lamp_sconce", lambda f: draw_lantern_post(18, 30, "plum", "apricot", "gold", "apricot", "gold", f), 4, 240.0, role="light", placement="corridors and doors"),
        static_prop("mahogany_table", _table(), role="cover", placement="dining hall center"),
        static_prop("tea_trolley", _trolley(), role="decor", placement="parlor side walls"),
        anim_prop("wall_curtain_drape", lambda f: draw_banner(18, 34, "gold", "plum", "wine", "rose", "gold", f), 4, 360.0, role="decor", placement="flanking windows"),
        static_prop("bellmaker_pedestal", draw_pillar(18, 28, "night", "plum", "mauve", "gold"), role="landmark", placement="display alcove"),
        anim_prop("hearth_fireplace", _fireplace, 4, 220.0, role="light", placement="north wall centerpiece"),
        anim_prop("manor_candelabra", lambda f: _candelabra(f, "plum", "gold", "cream"), 4, 240.0, role="light", placement="ballroom corners"),
    ]

    # 3. theme_great_toll_shaft (10 props)
    def _winch() -> Image.Image:
        c = PCanvas(22, 24)
        c.bevel(2, 16, 18, 6, "night", "dusk", "void")
        c.bevel(4, 6, 14, 11, "dusk", "mauve", "night")
        for x in range(6, 17, 2):
            c.vline(x, 7, 15, "apricot" if x % 4 == 0 else "coral")
        return c.finalize(24, 26)

    def _chime_rack(f: int) -> Image.Image:
        c = PCanvas(22, 28)
        c.bevel(2, 2, 3, 24, "dusk", "mauve", "night")
        c.hline(2, 20, 3, "gold")
        sw = (-1, 0, 1, 0)[f % 4]
        for idx, (rx, rl) in enumerate(((7, 12), (11, 16), (15, 10))):
            c.rect(rx + (sw if idx == 1 else 0), 5, 2, rl, "gold" if idx % 2 == 0 else "apricot")
        return c.finalize(24, 30)

    shaft = [
        anim_prop("giant_clock_gear", lambda f: draw_gear(38, 38, "plum", "apricot", "gold", f), 4, 260.0, role="landmark", placement="shaft ledges and wall edges"),
        anim_prop("small_bronze_gear", lambda f: draw_gear(22, 22, "dusk", "coral", "apricot", f), 4, 200.0, role="decor", placement="interlocking next to large gears"),
        anim_prop("hanging_pendulum_weight", lambda f: _grandfather_clock(f), 4, 260.0, role="landmark", placement="tower shaft walls"),
        static_prop("iron_chain_winch", _winch(), role="decor", placement="platform edges"),
        static_prop("belfry_beam_brace", draw_archway(44, 42, "night", "dusk", "mauve", "apricot", "gold"), role="landmark", placement="shaft threshold"),
        static_prop("cracked_bell_shard", draw_pillar(16, 22, "coral", "apricot", "gold", "cream", broken=True), role="decor", placement="shattered ledges"),
        anim_prop("shaft_lantern_cage", lambda f: draw_lantern_post(18, 30, "night", "dusk", "apricot", "coral", "gold", f), 4, 220.0, role="light", placement="safe landings"),
        static_prop("counterweight_block", draw_pillar(16, 26, "night", "dusk", "mauve", "gold"), role="cover", placement="gear shafts"),
        anim_prop("wind_chime_rack", _chime_rack, 4, 260.0, role="ambient", placement="windy platform rims"),
        anim_prop("iron_pulley_wheel", lambda f: draw_gear(24, 24, "night", "dusk", "stone", f), 4, 240.0, role="decor", placement="catwalk corners"),
    ]

    # 4. theme_galleon (12 props)
    def _helm() -> Image.Image:
        c = PCanvas(24, 26)
        c.bevel(9, 14, 6, 11, "plum", "wine", "night")
        for a in range(0, 360, 45):
            r = math.radians(a)
            c.line(12, 10, int(12 + math.cos(r) * 9), int(10 + math.sin(r) * 9), "apricot")
        c.shaded_ellipse(12, 10, 6.5, 6.5, "plum", "wine", "coral")
        c.ellipse(12, 10, 4.0, 4.0, None)
        c.ellipse(12, 10, 2.0, 2.0, "gold")
        return c.finalize(26, 28)

    def _cannon() -> Image.Image:
        c = PCanvas(26, 18)
        c.bevel(3, 10, 18, 6, "plum", "wine", "night")
        c.bevel(2, 4, 21, 7, "night", "mauve", "void")
        c.hline(3, 21, 5, "stone")
        c.ellipse(7, 15, 2.2, 2.2, "dusk")
        c.ellipse(17, 15, 2.2, 2.2, "dusk")
        return c.finalize(28, 20)

    galleon = [
        static_prop("oak_ship_barrel", _barrel(False), role="cover", placement="deck sides and holds"),
        static_prop("rope_coil_crate", _crate(True), role="cover", placement="cargo bays"),
        anim_prop("brass_capstan", _capstan, 4, 320.0, role="landmark", placement="foredeck center"),
        static_prop("ship_helm_wheel", _helm(), role="landmark", placement="quarterdeck stern"),
        anim_prop("tangled_cargo_net", _net_rack, 4, 340.0, role="decor", placement="along hull bulkheads"),
        anim_prop("brass_porthole_lamp", lambda f: draw_lantern_post(18, 28, "plum", "apricot", "gold", "sky", "ice", f), 4, 260.0, role="light", placement="bulkhead doors"),
        static_prop("mast_stump_pillar", draw_pillar(18, 34, "night", "plum", "coral", "apricot", broken=True), role="cover", placement="centerline deck"),
        static_prop("broken_cannon", _cannon(), role="cover", placement="gunports"),
        anim_prop("hanging_ship_lantern", lambda f: draw_lantern_post(18, 30, "night", "dusk", "apricot", "apricot", "gold", f), 4, 240.0, role="light", placement="gangways"),
        static_prop("barnacle_anchor", _anchor(), role="landmark", placement="bow and breaches"),
        static_prop("bilge_grate_hatch", draw_floor_medallion(28, 24, "night", "plum", "apricot", "deep", 0), layer="ground", role="decor", placement="center deck"),
        anim_prop("tattered_sail_banner", lambda f: draw_banner(18, 34, "wine", "mauve", "stone", "cream", "blue", f), 4, 300.0, role="ambient", placement="mast and railings"),
    ]

    # 5. theme_locks (11 props)
    def _bollard() -> Image.Image:
        c = PCanvas(14, 18)
        c.bevel(2, 12, 10, 5, "deep", "mauve", "night")
        c.bevel(4, 4, 6, 9, "night", "stone", "void")
        c.hline(3, 10, 4, "ice")
        return c.finalize(16, 20)

    def _sluice_wheel(f: int) -> Image.Image:
        c = PCanvas(20, 26)
        c.bevel(7, 12, 6, 13, "deep", "blue", "night")
        g = draw_gear(18, 18, "plum", "coral", "apricot", f)
        c.im.alpha_composite(g, (1, 0))
        return c.finalize(22, 28)

    def _buoy(f: int) -> Image.Image:
        c = PCanvas(18, 24)
        dy = (0, 1, 0, -1)[f % 4]
        c.shaded_ellipse(9, 16 + dy, 5.5, 4.0, "wine", "coral", "apricot")
        c.vline(9, 4 + dy, 13 + dy, "stone")
        c.rect(7, 5 + dy, 5, 4, "ice" if (f % 2 == 0) else "sky")
        return c.finalize(20, 26)

    locks = [
        static_prop("iron_mooring_bollard", _bollard(), role="decor", placement="quay canal edges"),
        anim_prop("sluice_wheel_post", _sluice_wheel, 4, 300.0, role="landmark", placement="beside canal locks"),
        static_prop("canal_cargo_crate", _crate(False), role="cover", placement="loading wharves"),
        static_prop("smuggler_barrel_stack", _barrel(True), role="cover", placement="wharf alcoves"),
        anim_prop("harbor_crane_arm", lambda f: draw_archway(44, 44, "night", "deep", "mauve", "apricot", "ice", f, hanging_lamp=True), 2, 480.0, role="landmark", placement="lock gates"),
        anim_prop("lock_lantern_post", lambda f: draw_lantern_post(18, 32, "deep", "blue", "sky", "sky", "ice", f), 4, 260.0, role="light", placement="canal walkways"),
        static_prop("coil_of_hawser", _crate(True), role="decor", placement="near bollards"),
        anim_prop("hanging_fishing_net", _net_rack, 4, 340.0, role="ambient", placement="wharf railings"),
        static_prop("tide_gauge_pillar", draw_pillar(16, 32, "deep", "blue", "sky", "ice"), role="landmark", placement="waterline walls"),
        static_prop("mooring_ring_floor", draw_floor_medallion(20, 20, "deep", "mauve", "ice", "sky", 0), layer="ground", role="decor", placement="quay edges"),
        anim_prop("canal_buoy_marker", _buoy, 4, 360.0, role="ambient", placement="canal water edges"),
    ]

    # 6. theme_leviathan_belly (10 props)
    def _acid_sac(f: int) -> Image.Image:
        c = PCanvas(20, 22)
        pulse = (0, 1, 0, 0)[f % 4]
        c.shaded_ellipse(10, 14, 6.5 + pulse * 0.5, 5.5, "pine", "teal", "jade")
        c.ellipse(10, 11, 3.5, 2.5, "lime")
        if f in (1, 2):
            c.set(10, 5 - f, "lime")
            c.set(12, 7 - f, "cream")
        return c.finalize(22, 24)

    def _barnacle_mound() -> Image.Image:
        c = PCanvas(22, 16)
        c.shaded_ellipse(11, 11, 8.0, 4.5, "plum", "mauve", "stone")
        for bx, by in ((6, 9), (11, 7), (15, 10)):
            c.ellipse(bx, by, 2.2, 2.0, "cream")
            c.set(bx, by, "night")
        return c.finalize(24, 18)

    belly = [
        static_prop("ivory_rib_arch", _rib_arch(), role="landmark", placement="framing fleshy passages"),
        static_prop("curled_rib_pillar", draw_pillar(16, 32, "plum", "mauve", "stone", "cream", broken=True), role="cover", placement="along membrane walls"),
        static_prop("barnacle_cluster", _barnacle_mound(), role="decor", placement="edges of acid pools"),
        anim_prop("acid_vent_sac", _acid_sac, 4, 280.0, role="ambient", placement="near digestive water"),
        static_prop("swallowed_ship_crate", _crate(True), role="cover", placement="half-sunk debris piles"),
        static_prop("swallowed_anchor", _anchor(), role="landmark", placement="stuck in belly floor"),
        anim_prop("digestive_spore_bulb", _acid_sac, 4, 320.0, role="light", placement="safe island edges"),
        static_prop("tendon_bridge_post", draw_pillar(14, 24, "wine", "rose", "stone", "cream"), role="decor", placement="bridge approaches"),
        anim_prop("whale_lantern_jar", lambda f: draw_lantern_post(18, 26, "plum", "wine", "rose", "jade", "lime", f, tall_hook=False), 4, 260.0, role="light", placement="swallowed wreck sites"),
        static_prop("cartilage_mound", _barnacle_mound(), role="decor", placement="wall corners"),
    ]

    # 7. theme_seabed (11 props)
    def _clam(f: int) -> Image.Image:
        c = PCanvas(22, 18)
        c.shaded_ellipse(11, 13, 8.0, 4.0, "plum", "mauve", "stone")
        c.shaded_ellipse(11, 9 - (f % 2), 7.5, 3.8, "mauve", "stone", "ice")
        c.ellipse(11, 11, 2.0, 1.6, "cream" if (f % 2 == 1) else "sky")
        return c.finalize(24, 20)

    def _kelp(f: int) -> Image.Image:
        c = PCanvas(18, 28)
        sw = (-1, 0, 1, 0)[f % 4]
        for bx in (5, 9, 13):
            for y in range(4, 26):
                dx = int(round(math.sin(y * 0.4 + bx) * 1.3)) + (sw if y < 14 else 0)
                c.set(bx + dx, y, "lime" if y < 10 else ("jade" if y < 18 else "teal"))
        return c.finalize(20, 30)

    seabed = [
        anim_prop("coral_fan_cluster", _coral_fan, 4, 360.0, role="ambient", placement="reef ledges and pool banks"),
        anim_prop("giant_clam_shell", _clam, 2, 650.0, role="landmark", placement="tidal sandbars"),
        static_prop("barnacle_boulder", _barnacle_mound(), role="cover", placement="seabed outcrops"),
        anim_prop("kelp_frond_reed", _kelp, 4, 300.0, role="ambient", placement="shallow water rims"),
        static_prop("sunken_amphora_urn", draw_urn(16, 22, "deep", "teal", "stone", "coral"), role="decor", placement="sunken ruins"),
        static_prop("shipwreck_rib_beam", draw_pillar(16, 28, "night", "plum", "mauve", "teal", broken=True), role="decor", placement="wrecked hull spots"),
        anim_prop("sea_anemone_glow", _coral_fan, 4, 260.0, role="light", placement="tidepool rocks"),
        static_prop("tidepool_starfish", draw_floor_medallion(18, 18, "wine", "coral", "rose", "apricot", 0), layer="ground", role="decor", placement="wet sandbars"),
        anim_prop("sunken_bell_relic", _bell_stand, 4, 420.0, role="landmark", placement="ebb shrine corners"),
        static_prop("sand_ripple_stone", draw_pillar(16, 20, "deep", "pine", "teal", "ice", broken=True), role="cover", placement="ebb cave walls"),
        anim_prop("pearl_lantern_post", lambda f: draw_lantern_post(18, 28, "deep", "teal", "sky", "sky", "ice", f), 4, 280.0, role="light", placement="ebb trail markers"),
    ]

    return [
        ("theme_undercroft", "The Undercroft Scenery", undercroft),
        ("theme_manor", "The Bellmaker's Manor Scenery", manor),
        ("theme_great_toll_shaft", "The Great Toll Shaft Scenery", shaft),
        ("theme_galleon", "The Drowned Galleon Scenery", galleon),
        ("theme_locks", "The Smugglers' Locks Scenery", locks),
        ("theme_leviathan_belly", "The Leviathan's Belly Scenery", belly),
        ("theme_seabed", "Ebb Seabed Scenery", seabed),
    ]
