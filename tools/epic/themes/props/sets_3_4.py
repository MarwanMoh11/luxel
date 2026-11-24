"""Scenery prop atlases for Islands 3 & 4 themes:
theme_under_root, theme_loom, theme_briar_court, theme_hourglass_maze,
theme_rain_mausoleum, theme_garden_party.
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
    draw_floor_medallion,
    draw_lantern_post,
    draw_pillar,
    draw_urn,
    static_prop,
)


def _shroom(f: int, cap_dk: str = "teal", cap_mid: str = "jade", cap_hi: str = "lime") -> Image.Image:
    c = PCanvas(22, 24)
    c.bevel(8, 12, 6, 10, "mauve", "stone", "dusk")
    c.shaded_ellipse(11, 10, 8.5, 5.2, cap_dk, cap_mid, cap_hi)
    # Bioluminescent spots pulsing
    spot_c = "cream" if (f % 2 == 0) else cap_hi
    for sx, sy in ((7, 8), (11, 7), (15, 9)):
        c.set(sx, sy, spot_c)
    if f in (1, 2):
        c.set(6 + f, 15, cap_hi)
        c.set(15 - f, 16, "cream")
    return c.finalize(24, 26)


def _dew_lens(f: int) -> Image.Image:
    c = PCanvas(24, 22)
    c.shaded_ellipse(12, 13, 8.5, 7.0, "blue", "sky", "ice")
    c.ellipse(9, 10, 2.6, 2.0, "cream")
    if f % 2 == 1:
        c.set(15, 14, "ice")
        c.set(12, 7, "cream")
    return c.finalize(26, 24)


def _acorn() -> Image.Image:
    c = PCanvas(24, 26)
    c.shaded_ellipse(12, 16, 7.5, 8.0, "plum", "wine", "coral")
    c.shaded_ellipse(12, 9, 9.0, 4.5, "night", "plum", "apricot")
    for x in range(5, 19, 3):
        c.set(x, 8, "night")
    c.vline(12, 2, 5, "plum")
    return c.finalize(26, 28)


def _loom_frame(f: int) -> Image.Image:
    c = PCanvas(34, 34)
    c.bevel(2, 2, 4, 30, "plum", "coral", "night")
    c.bevel(28, 2, 4, 30, "plum", "coral", "night")
    c.bevel(1, 2, 32, 4, "wine", "apricot", "night")
    c.bevel(1, 26, 32, 4, "wine", "apricot", "night")
    # Vertical warp threads
    for x in range(8, 27, 3):
        c.vline(x, 6, 25, "gold" if (x % 6 == 2) else "stone")
    # Animated horizontal shuttle bar moving across
    sx = 8 + (f % 4) * 4
    c.rect(sx, 14, 7, 3, "cream")
    c.hline(6, 27, 15, "apricot")
    return c.finalize(36, 36)


def _spool() -> Image.Image:
    c = PCanvas(16, 20)
    c.bevel(2, 2, 12, 3, "wine", "apricot", "night")
    c.bevel(2, 15, 12, 3, "wine", "apricot", "night")
    c.bevel(4, 5, 8, 10, "coral", "gold", "wine")
    for y in range(6, 15, 2):
        c.hline(5, 10, y, "apricot")
    return c.finalize(18, 22)


def _hourglass(f: int) -> Image.Image:
    c = PCanvas(20, 32)
    c.bevel(2, 2, 16, 3, "apricot", "gold", "wine")
    c.bevel(2, 27, 16, 3, "apricot", "gold", "wine")
    c.vline(4, 5, 26, "gold")
    c.vline(15, 5, 26, "apricot")
    # Glass bulbs
    for y in range(6, 26):
        w = max(1, abs(y - 16) // 2 + 1)
        c.hline(10 - w, 10 + w, y, "ice" if (y % 3 == 0) else "sky")
    # Flowing golden sand levels
    top_sand = 11 + (f % 4)
    for y in range(top_sand, 16):
        w = max(1, (16 - y) // 2)
        c.hline(10 - w, 10 + w, y, "gold")
    # Falling stream
    c.vline(10, 16, 25, "cream" if (f % 2 == 0) else "gold")
    bot_sand = 25 - (f % 4)
    for y in range(bot_sand, 26):
        w = max(1, (y - 16) // 2)
        c.hline(10 - w, 10 + w, y, "apricot" if y > 23 else "gold")
    return c.finalize(22, 34)


def _sundial(f: int) -> Image.Image:
    c = PCanvas(22, 28)
    c.bevel(4, 22, 14, 4, "dusk", "mauve", "night")
    c.bevel(7, 11, 8, 12, "mauve", "stone", "dusk")
    c.shaded_ellipse(11, 10, 8.0, 3.5, "apricot", "gold", "cream")
    # Gnomon blade casting shifting shadow
    c.line(11, 10, 11, 3, "gold")
    c.line(11, 3, 15, 10, "apricot")
    sh_x = 8 + (f % 4) * 2
    c.line(11, 10, sh_x, 12, "dusk")
    return c.finalize(24, 30)


def _topiary(bird: bool = False) -> Image.Image:
    c = PCanvas(20, 30)
    c.bevel(4, 23, 12, 5, "mauve", "stone", "dusk")
    if bird:
        c.shaded_ellipse(10, 16, 6.0, 5.5, "pine", "teal", "jade")
        c.shaded_ellipse(13, 9, 3.8, 3.2, "teal", "jade", "lime")
        c.set(17, 9, "gold")
        c.set(14, 8, "cream")
    else:
        for y in range(4, 23):
            hw = int((y - 3) * 0.42) + 1
            for x in range(10 - hw, 10 + hw + 1):
                c.set(x, y, "lime" if x < 9 else ("pine" if x > 12 else "jade"))
        c.set(10, 3, "gold")
    return c.finalize(22, 32)


def _fountain(f: int) -> Image.Image:
    c = PCanvas(30, 28)
    c.shaded_ellipse(15, 20, 12.0, 5.5, "dusk", "mauve", "stone")
    c.shaded_ellipse(15, 19, 9.5, 4.0, "deep", "blue", "sky")
    c.bevel(12, 10, 6, 10, "mauve", "stone", "dusk")
    c.shaded_ellipse(15, 10, 6.0, 2.5, "mauve", "stone", "cream")
    # Animated water jets
    jet_h = 4 + (f % 2)
    c.vline(15, 10 - jet_h, 9, "ice")
    c.set(15, 9 - jet_h, "cream")
    c.line(15, 7, 10 - (f % 2), 18, "sky")
    c.line(15, 7, 20 + (f % 2), 18, "sky")
    return c.finalize(32, 30)


def _banquet_table() -> Image.Image:
    c = PCanvas(34, 18)
    c.bevel(2, 4, 30, 11, "stone", "cream", "mauve")
    c.hline(2, 31, 9, "rose")
    c.hline(2, 31, 10, "gold")
    # Goblets & cake
    c.rect(7, 2, 3, 3, "gold")
    c.rect(15, 1, 5, 4, "rose")
    c.set(17, 0, "cream")
    c.rect(24, 2, 3, 3, "ice")
    return c.finalize(36, 20)


def build_sets_3_4() -> list[tuple[str, str, list[PropDef]]]:
    # 1. theme_under_root (11 props)
    under_root = [
        anim_prop("ant_lantern_post", lambda f: draw_lantern_post(18, 30, "plum", "coral", "apricot", "apricot", "gold", f), 4, 240.0, role="light", placement="lining ant roads"),
        anim_prop("giant_dew_lens", _dew_lens, 4, 320.0, role="landmark", placement="mossy clearings"),
        static_prop("braided_root_arch", draw_archway(46, 46, "night", "plum", "coral", "jade", "lime"), role="landmark", placement="tunnel entrances"),
        static_prop("colossal_acorn_dome", _acorn(), role="cover", placement="root chambers"),
        anim_prop("moss_cap_shroom", _shroom, 4, 320.0, role="ambient", placement="damp loam corners"),
        anim_prop("glow_spore_cluster", lambda f: _shroom(f, "pine", "jade", "lime"), 4, 260.0, role="light", placement="dark crevices"),
        static_prop("fallen_bark_bench", draw_pillar(22, 14, "night", "plum", "coral", "apricot", broken=True), role="cover", placement="side clearings"),
        static_prop("amber_sap_urn", draw_urn(16, 22, "plum", "coral", "apricot", "gold"), role="decor", placement="ant road junctions"),
        anim_prop("fern_canopy_frond", lambda f: draw_banner(18, 30, "plum", "pine", "teal", "jade", "lime", f), 4, 340.0, role="ambient", placement="root alcoves"),
        static_prop("beetle_hitching_post", draw_pillar(14, 24, "night", "plum", "apricot", "gold"), role="decor", placement="beetle mounts"),
        static_prop("pebble_milestone", draw_pillar(16, 20, "dusk", "mauve", "stone", "lime", broken=True), role="decor", placement="path forks"),
    ]

    # 2. theme_loom (11 props)
    loom = [
        anim_prop("standing_oak_loom", _loom_frame, 4, 300.0, role="landmark", placement="weaving hall walls"),
        static_prop("wooden_thread_spool", _spool(), role="cover", placement="beside looms"),
        anim_prop("hanging_silk_banner", lambda f: draw_banner(18, 34, "apricot", "pine", "teal", "jade", "gold", f), 4, 320.0, role="ambient", placement="framing walkways"),
        static_prop("brass_shuttle_rack", draw_pillar(16, 28, "plum", "wine", "apricot", "gold"), role="decor", placement="tapestry edges"),
        static_prop("tension_peg_pillar", draw_pillar(14, 28, "night", "plum", "coral", "gold"), role="cover", placement="platform corners"),
        anim_prop("luminous_yarn_basket", lambda f: draw_urn(18, 22, "plum", "wine", "coral", "gold", "gold", f), 4, 340.0, role="light", placement="loom corners"),
        static_prop("tapestry_frame_stand", draw_archway(44, 44, "night", "plum", "wine", "gold", "teal"), role="landmark", placement="north wall"),
        anim_prop("loom_lantern_brazier", lambda f: draw_brazier(20, 26, "night", "plum", "apricot", f), 4, 240.0, role="light", placement="silk bridge heads"),
        anim_prop("spindle_totem", lambda f: draw_pillar(16, 32, "plum", "wine", "apricot", "gold", glow_band="gold", f=f), 4, 280.0, role="landmark", placement="thread anchors"),
        static_prop("dyed_bolt_of_cloth", _spool(), role="decor", placement="side alcoves"),
        anim_prop("woven_floor_medallion", lambda f: draw_floor_medallion(36, 36, "plum", "teal", "gold", "cream", f), 2, 500.0, layer="ground", role="landmark", placement="center of weaving rooms"),
    ]

    # 3. theme_briar_court (11 props)
    briar_court = [
        static_prop("rose_thorn_arch", draw_archway(46, 46, "night", "pine", "jade", "rose", "gold"), role="landmark", placement="court entrance"),
        anim_prop("heraldic_court_banner", lambda f: draw_banner(18, 34, "gold", "wine", "rose", "cream", "gold", f), 4, 300.0, role="ambient", placement="lining jousting lanes"),
        static_prop("stone_verdict_throne", draw_archway(32, 34, "night", "dusk", "stone", "gold", "rose"), role="landmark", placement="north trial dais"),
        static_prop("jousting_lance_rack", draw_pillar(16, 32, "pine", "mauve", "stone", "rose"), role="decor", placement="arena flanks"),
        anim_prop("briar_lantern_post", lambda f: draw_lantern_post(18, 30, "pine", "teal", "jade", "rose", "gold", f), 4, 260.0, role="light", placement="court corners"),
        anim_prop("clipped_rose_urn", lambda f: draw_urn(18, 26, "dusk", "mauve", "stone", "gold", "jade", f), 4, 360.0, role="ambient", placement="dais steps"),
        anim_prop("trial_bell_stand", lambda f: draw_lantern_post(20, 30, "pine", "mauve", "gold", "apricot", "gold", f, tall_hook=False), 4, 320.0, role="landmark", placement="verdict bell spots"),
        static_prop("mossy_shield_plinth", draw_pillar(16, 26, "pine", "mauve", "stone", "gold"), role="cover", placement="court perimeter"),
        anim_prop("thorn_hedge_brazier", lambda f: draw_brazier(20, 26, "pine", "dusk", "mauve", f, c_out="wine", c_mid="rose", c_hi="gold"), 4, 240.0, role="light", placement="trial arena braziers"),
        static_prop("court_bench_stone", draw_pillar(26, 14, "dusk", "mauve", "stone", "jade", broken=True), role="decor", placement="spectator galleries"),
        static_prop("petal_drift_floor", draw_floor_medallion(24, 20, "pine", "wine", "rose", "cream", 0), layer="ground", role="decor", placement="scattered court corners"),
    ]

    # 4. theme_hourglass_maze (11 props)
    hourglass_maze = [
        anim_prop("tall_hourglass_pillar", _hourglass, 4, 320.0, role="landmark", placement="maze intersections"),
        anim_prop("brass_sundial_pedestal", _sundial, 4, 420.0, role="landmark", placement="sunlit courtyards"),
        static_prop("clipped_topiary_cone", _topiary(False), role="cover", placement="hedge alcoves"),
        static_prop("topiary_bird_statue", _topiary(True), role="landmark", placement="garden focal points"),
        anim_prop("sand_chute_urn", lambda f: draw_urn(18, 24, "dusk", "apricot", "gold", "cream", None, f), 4, 300.0, role="decor", placement="maze corners"),
        anim_prop("garden_clock_arch", lambda f: draw_archway(46, 46, "pine", "mauve", "stone", "gold", "apricot", f, hanging_lamp=True), 4, 380.0, role="landmark", placement="timed gates"),
        anim_prop("amber_lantern_post", lambda f: draw_lantern_post(18, 30, "pine", "mauve", "stone", "apricot", "gold", f), 4, 260.0, role="light", placement="path turns"),
        static_prop("stone_hedge_bench", draw_pillar(26, 14, "dusk", "mauve", "stone", "gold", broken=True), role="decor", placement="resting alcoves"),
        anim_prop("echo_rose_trellis", lambda f: draw_urn(18, 26, "pine", "teal", "jade", "rose", "jade", f), 4, 340.0, role="ambient", placement="beside echo roses"),
        anim_prop("hourglass_floor_dial", lambda f: draw_floor_medallion(36, 36, "dusk", "apricot", "gold", "cream", f), 2, 480.0, layer="ground", role="landmark", placement="central plaza"),
        static_prop("mossy_garden_obelisk", draw_pillar(16, 34, "pine", "mauve", "stone", "gold"), role="cover", placement="maze landmarks"),
    ]

    # 5. theme_rain_mausoleum (11 props)
    def _gargoyle(f: int) -> Image.Image:
        c = PCanvas(20, 24)
        c.bevel(4, 14, 12, 9, "deep", "teal", "night")
        c.shaded_ellipse(10, 10, 5.5, 4.5, "deep", "mauve", "stone")
        c.set(8, 9, "ice")
        c.set(12, 9, "ice")
        # Dripping rain spout
        for y in range(13 + (f % 2), 23, 3):
            c.set(10, y, "ice")
        return c.finalize(22, 26)

    rain_mausoleum = [
        anim_prop("weeping_stone_urn", _gargoyle, 4, 260.0, role="ambient", placement="along damp walls"),
        anim_prop("weather_vane_spire", lambda f: draw_pillar(18, 36, "deep", "teal", "sky", "ice", glow_band="ice", f=f), 4, 300.0, role="landmark", placement="weather wheel rooms"),
        static_prop("carved_sarcophagus", draw_pillar(24, 16, "deep", "mauve", "stone", "ice"), role="cover", placement="tomb nave"),
        anim_prop("bronze_drain_gargoyle", _gargoyle, 4, 240.0, role="decor", placement="pool edges"),
        anim_prop("rain_lantern_post", lambda f: draw_lantern_post(18, 30, "deep", "teal", "sky", "sky", "ice", f), 4, 260.0, role="light", placement="walkway corners"),
        static_prop("mausoleum_arch_gate", draw_archway(46, 46, "night", "deep", "teal", "ice", "sky"), role="landmark", placement="tomb portals"),
        static_prop("wet_moss_pillar", draw_pillar(16, 34, "deep", "pine", "teal", "ice"), role="cover", placement="flooded halls"),
        anim_prop("chime_rain_rod", lambda f: draw_banner(16, 30, "ice", "deep", "blue", "sky", "ice", f), 4, 300.0, role="ambient", placement="rain courts"),
        static_prop("flood_gauge_marker", draw_pillar(14, 26, "deep", "mauve", "stone", "sky"), role="decor", placement="beside water"),
        anim_prop("storm_brazier_bowl", lambda f: draw_brazier(20, 26, "deep", "teal", "sky", f, c_out="blue", c_mid="sky", c_hi="ice"), 4, 240.0, role="light", placement="sanctuary altars"),
        static_prop("slate_memorial_plinth", draw_pillar(18, 22, "deep", "teal", "mauve", "ice", broken=True), role="decor", placement="crypt niches"),
    ]

    # 6. theme_garden_party (11 props)
    garden_party = [
        static_prop("banquet_table_cloth", _banquet_table(), role="cover", placement="courtyard heist tables"),
        anim_prop("festive_bunting_arch", lambda f: draw_archway(46, 44, "pine", "stone", "cream", "rose", "gold", f, hanging_lamp=True), 4, 320.0, role="landmark", placement="party promenade"),
        anim_prop("paper_lantern_post", lambda f: draw_lantern_post(18, 32, "pine", "wine", "rose", "rose", "gold", f), 4, 260.0, role="light", placement="terrace corners"),
        anim_prop("marble_koi_fountain", _fountain, 4, 240.0, role="landmark", placement="central garden plaza"),
        anim_prop("rose_flower_urn", lambda f: draw_urn(18, 26, "mauve", "stone", "cream", "gold", "jade", f), 4, 360.0, role="ambient", placement="balustrade corners"),
        static_prop("garden_gazebo_pillar", draw_pillar(16, 34, "mauve", "stone", "cream", "gold"), role="cover", placement="terrace colonnade"),
        static_prop("tea_service_stand", draw_urn(16, 22, "mauve", "stone", "cream", "rose"), role="decor", placement="beside banquet tables"),
        anim_prop("hedgerow_lamp_urn", lambda f: draw_brazier(20, 24, "mauve", "stone", "cream", f, c_out="rose", c_mid="apricot", c_hi="gold"), 4, 260.0, role="light", placement="hedge openings"),
        static_prop("masked_statue_plinth", _topiary(True), role="landmark", placement="courtyard alcoves"),
        anim_prop("music_box_pedestal", lambda f: draw_pillar(18, 26, "plum", "rose", "gold", "cream", glow_band="gold", f=f), 4, 280.0, role="landmark", placement="bandstand terrace"),
        anim_prop("lily_pond_lantern", lambda f: draw_floor_medallion(20, 20, "pine", "jade", "rose", "gold", f), 2, 420.0, layer="ground", role="light", placement="pond rims"),
    ]

    return [
        ("theme_under_root", "The Under-Root Scenery", under_root),
        ("theme_loom", "The Weaver's Loom Scenery", loom),
        ("theme_briar_court", "The Briar Court Scenery", briar_court),
        ("theme_hourglass_maze", "The Hourglass Maze Scenery", hourglass_maze),
        ("theme_rain_mausoleum", "The Rain Mausoleum Scenery", rain_mausoleum),
        ("theme_garden_party", "The Garden Party Scenery", garden_party),
    ]
