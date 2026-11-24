"""Scenery prop atlases for Islands 7 & 8 + Hub themes:
theme_inverted_palace_silver, theme_inverted_palace_black, theme_doppel_theatre,
theme_masquerade, theme_toll_house, theme_archive, theme_endless_stair, theme_wick_house.
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
    draw_lantern_post,
    draw_mirror,
    draw_pillar,
    draw_urn,
    static_prop,
)


def _bookshelf(wide: bool = False) -> Image.Image:
    w = 34 if wide else 22
    c = PCanvas(w, 34)
    c.bevel(0, 1, w, 32, "plum", "coral", "night")
    c.hline(1, w - 2, 2, "gold")
    colors = ("wine", "teal", "blue", "apricot", "mauve", "rose", "jade")
    for sy in (5, 13, 21):
        c.rect(2, sy, w - 4, 6, "night")
        for x in range(3, w - 3, 2):
            col = colors[(x * 3 + sy) % len(colors)]
            bh = 5 if (x % 4 == 1) else 6
            c.rect(x, sy + (6 - bh), 2, bh, col)
            c.set(x + 1, sy + (6 - bh), "night")
        c.hline(2, w - 3, sy + 6, "apricot")
    return c.finalize(w + 2, 36)


def _ledger_desk() -> Image.Image:
    c = PCanvas(32, 22)
    c.bevel(1, 5, 30, 15, "dusk", "mauve", "night")
    c.bevel(0, 4, 32, 4, "plum", "gold", "night")
    # Open white ledger book + brass inkwell
    c.bevel(7, 2, 12, 6, "stone", "cream", "mauve")
    c.vline(13, 2, 7, "dusk")
    c.rect(22, 2, 3, 4, "gold")
    c.set(23, 1, "cream")
    return c.finalize(34, 24)


def _balance_scale(f: int) -> Image.Image:
    c = PCanvas(24, 28)
    c.bevel(7, 23, 10, 4, "dusk", "gold", "night")
    c.vline(12, 6, 23, "gold")
    tilt = (-1, 0, 1, 0)[f % 4]
    c.line(4, 9 + tilt, 20, 9 - tilt, "apricot")
    # Left & right pans
    c.line(4, 9 + tilt, 4, 16 + tilt, "stone")
    c.shaded_ellipse(4, 17 + tilt, 3.2, 1.6, "apricot", "gold", "cream")
    c.line(20, 9 - tilt, 20, 16 - tilt, "stone")
    c.shaded_ellipse(20, 17 - tilt, 3.2, 1.6, "apricot", "gold", "cream")
    return c.finalize(26, 30)


def _stage_curtain(f: int) -> Image.Image:
    c = PCanvas(22, 40)
    c.bevel(0, 0, 22, 4, "apricot", "gold", "wine")
    sw = (0, 1, 0, -1)[f % 4]
    for y in range(4, 38):
        dx = sw if y > 20 else 0
        for x in range(1, 21):
            fold = ((x + dx) % 5)
            col = "rose" if fold == 1 else ("plum" if fold == 4 else "wine")
            c.set(x, y, col)
    c.hline(1, 20, 37, "gold")
    # Tied gold tassel mid-height
    c.hline(1, 20, 22, "gold")
    c.rect(9, 21, 4, 3, "cream")
    return c.finalize(24, 42)


def _footlights(f: int) -> Image.Image:
    c = PCanvas(30, 10)
    for lx in (4, 14, 24):
        c.bevel(lx - 2, 3, 6, 6, "plum", "apricot", "night")
        c.rect(lx - 1, 2, 4, 3, "cream" if ((f + lx) % 2 == 0) else "gold")
    return c.finalize(32, 12)


def _moth_tree(f: int) -> Image.Image:
    c = PCanvas(30, 38)
    # Cozy warm lamp-tree holding rescued glowing moths
    c.bevel(12, 20, 6, 16, "plum", "coral", "night")
    c.shaded_ellipse(15, 13, 11.0, 9.0, "pine", "teal", "jade")
    # Glowing moth lanterns perched in branches
    for idx, (mx, my) in enumerate(((8, 12), (15, 7), (21, 13), (12, 16), (18, 10))):
        dy = (0, -1, 0, 1)[(f + idx) % 4]
        c.set(mx, my + dy, "cream" if ((f + idx) % 2 == 0) else "gold")
        c.set(mx - 1, my + dy, "apricot")
        c.set(mx + 1, my + dy, "apricot")
    return c.finalize(32, 40)


def _cozy_hearth(f: int) -> Image.Image:
    c = PCanvas(38, 32)
    c.bevel(2, 4, 34, 26, "mauve", "stone", "dusk")
    c.bevel(0, 2, 38, 4, "wine", "apricot", "plum")
    c.hline(1, 36, 3, "gold")
    c.rect(9, 12, 20, 16, "void")
    c.rect(12, 24, 14, 3, "plum")
    draw_flame(c, 16, 22, f, tall=7)
    draw_flame(c, 22, 22, (f + 2) % 4, tall=6)
    # Mantle ornaments (mini lantern + teapot)
    c.rect(6, 0, 3, 3, "gold")
    c.rect(28, 0, 4, 3, "sky")
    return c.finalize(40, 34)


def _memory_jar(f: int) -> Image.Image:
    c = PCanvas(18, 24)
    c.bevel(4, 16, 10, 6, "dusk", "mauve", "night")
    c.bevel(5, 4, 8, 12, "blue", "ice", "deep")
    c.hline(5, 12, 3, "gold")
    dy = (0, -1, 0, 1)[f % 4]
    c.ellipse(9, 10 + dy, 2.0, 2.0, "gold")
    c.set(9, 10 + dy, "cream")
    return c.finalize(20, 26)


def _straw_dummy() -> Image.Image:
    c = PCanvas(20, 28)
    c.vline(10, 12, 26, "plum")
    c.bevel(6, 24, 8, 3, "plum", "coral", "night")
    c.hline(3, 17, 13, "coral")
    c.bevel(6, 10, 8, 10, "apricot", "gold", "coral")
    c.shaded_ellipse(10, 6, 3.6, 3.6, "coral", "apricot", "gold")
    c.set(9, 6, "night")
    c.set(11, 6, "night")
    return c.finalize(22, 30)


def _phonograph(f: int) -> Image.Image:
    c = PCanvas(20, 24)
    c.bevel(3, 13, 14, 9, "plum", "coral", "night")
    c.hline(4, 15, 13, "gold")
    # Brass horn with music note sparkle
    c.line(10, 13, 14, 7, "apricot")
    c.shaded_ellipse(15, 6, 4.2, 3.5, "coral", "apricot", "gold")
    if f in (0, 2):
        c.set(17, 2 - (f // 2), "cream")
    return c.finalize(22, 26)


def build_sets_7_8() -> list[tuple[str, str, list[PropDef]]]:
    # 1. theme_inverted_palace_silver (11 props)
    pal_silver = [
        anim_prop("tall_silver_mirror", lambda f: draw_mirror(24, 36, "blue", "sky", "cream", "deep", "sky", "ice", f), 4, 300.0, role="landmark", placement="mirror puzzle walls"),
        static_prop("alabaster_fluted_pillar", draw_pillar(16, 36, "blue", "sky", "ice", "cream"), role="cover", placement="palace colonnades"),
        anim_prop("crystal_chandelier_arch", lambda f: draw_archway(46, 46, "deep", "sky", "ice", "cream", "sky", f, hanging_lamp=True), 4, 320.0, role="landmark", placement="palace portals"),
        anim_prop("silver_candelabra", lambda f: draw_brazier(20, 28, "blue", "sky", "ice", f, c_out="blue", c_mid="sky", c_hi="ice"), 4, 240.0, role="light", placement="corridors"),
        static_prop("moon_glass_urn", draw_urn(16, 24, "deep", "blue", "ice", "cream"), role="decor", placement="alcove plinths"),
        static_prop("velvet_palace_bench", draw_pillar(26, 14, "deep", "blue", "ice", "cream", broken=True), role="decor", placement="galleries"),
        anim_prop("floating_mirror_shard", lambda f: draw_mirror(16, 26, "blue", "ice", "cream", "deep", "sky", "cream", f), 4, 260.0, role="ambient", placement="near moon pools"),
        anim_prop("silver_bell_pedestal", lambda f: draw_pillar(16, 28, "blue", "sky", "ice", "cream", glow_band="cream", f=f), 4, 280.0, role="landmark", placement="world-flip rooms"),
        anim_prop("lunar_brazier_bowl", lambda f: draw_brazier(20, 26, "deep", "sky", "ice", f, c_out="sky", c_mid="ice", c_hi="cream"), 4, 240.0, role="light", placement="hall corners"),
        anim_prop("reflection_floor_pool", lambda f: draw_floor_medallion(36, 36, "deep", "sky", "ice", "cream", f), 2, 460.0, layer="ground", role="landmark", placement="center of silver rooms"),
        static_prop("gilded_statue_bust", draw_urn(18, 26, "blue", "stone", "cream", "gold"), role="decor", placement="wall pedestals"),
    ]

    # 2. theme_inverted_palace_black (11 props)
    pal_black = [
        anim_prop("obsidian_tall_mirror", lambda f: draw_mirror(24, 36, "void", "dusk", "rose", "void", "night", "rose", f), 4, 300.0, role="landmark", placement="black-world mirror walls"),
        static_prop("dark_inverted_pillar", draw_pillar(16, 36, "void", "night", "dusk", "rose"), role="cover", placement="obsidian colonnades"),
        anim_prop("rose_thorn_glass_arch", lambda f: draw_archway(46, 46, "void", "night", "plum", "rose", "ice", f, hanging_lamp=True), 4, 320.0, role="landmark", placement="black-world gates"),
        anim_prop("black_candelabra", lambda f: draw_brazier(20, 28, "void", "dusk", "plum", f, c_out="wine", c_mid="rose", c_hi="ice"), 4, 240.0, role="light", placement="dark halls"),
        static_prop("shadow_glass_urn", draw_urn(16, 24, "void", "night", "plum", "rose"), role="decor", placement="plinth corners"),
        static_prop("obsidian_palace_bench", draw_pillar(26, 14, "void", "night", "plum", "rose", broken=True), role="decor", placement="shadow galleries"),
        anim_prop("void_mirror_shard", lambda f: draw_mirror(16, 26, "void", "plum", "rose", "void", "dusk", "ice", f), 4, 260.0, role="ambient", placement="rift edges"),
        anim_prop("dusk_bell_pedestal", lambda f: draw_pillar(16, 28, "void", "dusk", "plum", "rose", glow_band="ice", f=f), 4, 280.0, role="landmark", placement="flip anchors"),
        anim_prop("eclipse_brazier_bowl", lambda f: draw_brazier(20, 26, "void", "dusk", "rose", f, c_out="plum", c_mid="rose", c_hi="cream"), 4, 240.0, role="light", placement="black-world altars"),
        anim_prop("dark_reflection_pool", lambda f: draw_floor_medallion(36, 36, "void", "plum", "rose", "ice", f), 2, 460.0, layer="ground", role="landmark", placement="center of black rooms"),
        static_prop("veiled_statue_bust", draw_urn(18, 26, "void", "dusk", "mauve", "rose"), role="decor", placement="wall pedestals"),
    ]

    # 3. theme_doppel_theatre (12 props)
    theatre = [
        anim_prop("velvet_stage_curtain", _stage_curtain, 4, 340.0, role="landmark", placement="framing left & right stage wings"),
        static_prop("proscenium_mask_arch", draw_archway(46, 46, "night", "wine", "rose", "gold", "cream"), role="landmark", placement="north stage backdrop"),
        anim_prop("brass_footlight_row", _footlights, 4, 260.0, role="light", placement="south stage apron edge"),
        anim_prop("dressing_vanity_mirror", lambda f: draw_mirror(22, 32, "plum", "apricot", "gold", "deep", "sky", "cream", f), 4, 300.0, role="landmark", placement="backstage dressing rooms"),
        anim_prop("puppet_crossbar_stand", lambda f: draw_banner(18, 32, "apricot", "plum", "wine", "rose", "gold", f), 4, 280.0, role="ambient", placement="puppet act stages"),
        static_prop("theatre_box_seat", draw_pillar(24, 18, "night", "wine", "rose", "gold"), role="cover", placement="side balconies"),
        static_prop("stage_prop_trunk", draw_pillar(22, 16, "plum", "wine", "apricot", "gold"), role="cover", placement="backstage wings"),
        static_prop("cardboard_moon_flat", draw_urn(20, 28, "deep", "blue", "sky", "gold"), role="decor", placement="stage scenery flats"),
        anim_prop("spot_lantern_rig", lambda f: draw_lantern_post(18, 32, "night", "dusk", "gold", "apricot", "cream", f), 4, 240.0, role="light", placement="stage wing corners"),
        static_prop("playbill_easel_stand", draw_pillar(18, 26, "plum", "stone", "cream", "wine"), role="decor", placement="theatre lobby"),
        anim_prop("tattered_act_banner", lambda f: draw_banner(18, 34, "gold", "night", "wine", "rose", "gold", f), 4, 300.0, role="ambient", placement="act transitions"),
        static_prop("trapdoor_stage_hatch", draw_floor_medallion(26, 22, "night", "plum", "apricot", "wine", 0), layer="ground", role="decor", placement="mid-stage"),
    ]

    # 4. theme_masquerade (11 props)
    masquerade = [
        anim_prop("masquerade_mirror_tall", lambda f: draw_mirror(24, 36, "mauve", "gold", "cream", "deep", "sky", "ice", f), 4, 300.0, role="landmark", placement="ballroom walls"),
        anim_prop("champagne_fountain", lambda f: draw_urn(20, 28, "mauve", "stone", "cream", "gold", "gold", f), 4, 280.0, role="landmark", placement="banquet center"),
        static_prop("gilded_ballroom_pillar", draw_pillar(16, 36, "deep", "mauve", "stone", "gold"), role="cover", placement="ballroom colonnade"),
        anim_prop("crystal_candelabra", lambda f: draw_brazier(20, 28, "mauve", "gold", "cream", f, c_out="apricot", c_mid="gold", c_hi="cream"), 4, 240.0, role="light", placement="dance floor corners"),
        static_prop("domino_mask_pedestal", draw_pillar(16, 26, "deep", "stone", "cream", "rose"), role="landmark", placement="clue pedestals"),
        static_prop("velvet_rosette_arch", draw_archway(46, 46, "deep", "mauve", "stone", "gold", "rose"), role="landmark", placement="grand ballroom entry"),
        static_prop("string_music_stand", draw_pillar(16, 24, "plum", "apricot", "gold", "cream"), role="decor", placement="orchestra corner"),
        anim_prop("moon_lantern_urn", lambda f: draw_lantern_post(18, 30, "mauve", "stone", "gold", "sky", "ice", f), 4, 260.0, role="light", placement="terrace openings"),
        anim_prop("ballroom_curtain_drape", _stage_curtain, 4, 360.0, role="ambient", placement="framing mirrors"),
        anim_prop("silver_chime_mobile", lambda f: draw_banner(16, 30, "gold", "blue", "sky", "ice", "cream", f), 4, 300.0, role="ambient", placement="balcony arches"),
        anim_prop("gilded_floor_crest", lambda f: draw_floor_medallion(40, 40, "deep", "stone", "gold", "cream", f), 2, 480.0, layer="ground", role="landmark", placement="ballroom center"),
    ]

    # 5. theme_toll_house (11 props)
    toll_house = [
        static_prop("ledger_counter_desk", _ledger_desk(), role="cover", placement="toll clerk halls"),
        static_prop("stacked_ledger_tower", _bookshelf(False), role="cover", placement="beside counters"),
        anim_prop("brass_balance_scale", _balance_scale, 4, 320.0, role="landmark", placement="payment altars"),
        static_prop("iron_teller_grille", draw_pillar(24, 26, "void", "dusk", "mauve", "gold"), role="cover", placement="teller booths"),
        anim_prop("toll_clerk_lantern", lambda f: draw_lantern_post(18, 30, "void", "dusk", "gold", "apricot", "gold", f), 4, 260.0, role="light", placement="ledger aisles"),
        static_prop("inkwell_lectern_stand", draw_pillar(16, 26, "night", "dusk", "stone", "gold"), role="decor", placement="entry checkpoints"),
        static_prop("wax_seal_pedestal", draw_urn(16, 22, "night", "dusk", "rose", "gold"), role="decor", placement="toll rooms"),
        static_prop("toll_gate_arch", draw_archway(46, 46, "void", "night", "dusk", "gold", "rose"), role="landmark", placement="setting-sale toll gates"),
        static_prop("filing_cabinet_tall", draw_pillar(18, 32, "void", "dusk", "mauve", "gold"), role="cover", placement="audit offices"),
        anim_prop("hanging_receipt_banner", lambda f: draw_banner(16, 32, "gold", "mauve", "stone", "cream", "wine", f), 4, 340.0, role="ambient", placement="flanking toll gates"),
        anim_prop("stamp_floor_emblem", lambda f: draw_floor_medallion(36, 36, "night", "wine", "gold", "rose", f), 2, 480.0, layer="ground", role="landmark", placement="toll hall center"),
    ]

    # 6. theme_archive (12 props)
    archive = [
        static_prop("tall_bookshelf_unit", _bookshelf(False), role="cover", placement="lining library stacks"),
        static_prop("wide_library_bookcase", _bookshelf(True), role="cover", placement="north walls and aisles"),
        static_prop("rolling_library_ladder", draw_pillar(14, 36, "plum", "coral", "apricot", "gold"), role="decor", placement="leaning on bookcases"),
        anim_prop("memory_glass_jar_stand", _memory_jar, 4, 280.0, role="light", placement="island memory pedestals"),
        static_prop("scholar_reading_desk", _ledger_desk(), role="cover", placement="study bays"),
        anim_prop("archive_lantern_sconce", lambda f: draw_lantern_post(18, 30, "plum", "apricot", "gold", "apricot", "cream", f), 4, 260.0, role="light", placement="between stacks"),
        static_prop("scroll_cubby_rack", _bookshelf(False), role="decor", placement="scroll alcoves"),
        static_prop("index_card_cabinet", draw_pillar(18, 26, "night", "plum", "mauve", "gold"), role="cover", placement="catalog foyer"),
        static_prop("archive_arch_portal", draw_archway(46, 46, "night", "plum", "mauve", "gold", "sky"), role="landmark", placement="memory wing entrances"),
        anim_prop("memory_orb_pedestal", _memory_jar, 4, 260.0, role="landmark", placement="wing focal points"),
        anim_prop("hanging_archive_banner", lambda f: draw_banner(18, 34, "gold", "night", "plum", "wine", "gold", f), 4, 340.0, role="ambient", placement="high gallery walls"),
        anim_prop("compass_rug_medallion", lambda f: draw_floor_medallion(38, 38, "plum", "wine", "gold", "cream", f), 2, 520.0, layer="ground", role="landmark", placement="central reading rotunda"),
    ]

    # 7. theme_endless_stair (10 props)
    endless_stair = [
        static_prop("spiral_newel_pillar", draw_pillar(16, 36, "night", "dusk", "mauve", "gold"), role="cover", placement="stair turns and landings"),
        anim_prop("floating_stair_shard", lambda f: draw_mirror(16, 24, "dusk", "mauve", "rose", "night", "plum", "gold", f), 4, 280.0, role="ambient", placement="void ledges"),
        anim_prop("ascension_boon_plinth", lambda f: draw_pillar(18, 28, "night", "plum", "rose", "gold", glow_band="gold", f=f), 4, 260.0, role="landmark", placement="boon selection landings"),
        static_prop("stone_balustrade_rail", draw_pillar(26, 14, "night", "dusk", "mauve", "stone", broken=True), role="cover", placement="landing rims"),
        anim_prop("stair_lantern_candelabra", lambda f: draw_brazier(20, 28, "night", "dusk", "rose", f, c_out="wine", c_mid="rose", c_hi="gold"), 4, 240.0, role="light", placement="landing corners"),
        static_prop("arch_landing_gate", draw_archway(46, 46, "void", "dusk", "mauve", "rose", "gold"), role="landmark", placement="floor-to-floor stairs"),
        anim_prop("tattered_climb_banner", lambda f: draw_banner(18, 34, "rose", "void", "dusk", "plum", "gold", f), 4, 300.0, role="ambient", placement="warden floors"),
        anim_prop("hourglass_milestone", _memory_jar, 4, 300.0, role="landmark", placement="every 4th floor"),
        static_prop("cracked_step_rubble", draw_pillar(18, 16, "night", "dusk", "mauve", "stone", broken=True), role="decor", placement="weathered landings"),
        anim_prop("void_chime_post", lambda f: draw_lantern_post(18, 30, "night", "dusk", "rose", "rose", "gold", f), 4, 260.0, role="light", placement="stair heads"),
    ]

    # 8. theme_wick_house (13 props)
    wick_house = [
        anim_prop("cozy_stone_hearth", _cozy_hearth, 4, 220.0, role="light", placement="north wall cottage centerpiece"),
        static_prop("wooden_workbench", _ledger_desk(), role="landmark", placement="pane workshop alcove"),
        anim_prop("moth_lantern_tree", _moth_tree, 4, 300.0, role="landmark", placement="courtyard moth sanctuary"),
        anim_prop("boss_rematch_mirror", lambda f: draw_mirror(24, 36, "plum", "apricot", "gold", "deep", "blue", "ice", f), 4, 300.0, role="landmark", placement="boss rematch room"),
        anim_prop("pane_stained_easel", lambda f: draw_mirror(20, 28, "plum", "coral", "gold", "teal", "rose", "gold", f), 4, 360.0, role="landmark", placement="pane crafting nook"),
        anim_prop("music_box_phonograph", _phonograph, 4, 280.0, role="landmark", placement="music box corner"),
        static_prop("training_straw_dummy", _straw_dummy(), role="landmark", placement="outdoor shooting yard"),
        static_prop("wooden_bookshelf_home", _bookshelf(False), role="cover", placement="journal & bestiary wall"),
        static_prop("cottage_dining_table", draw_pillar(28, 16, "plum", "coral", "apricot", "cream"), role="cover", placement="cottage common room"),
        anim_prop("warm_porch_lantern", lambda f: draw_lantern_post(18, 30, "plum", "coral", "gold", "apricot", "cream", f), 4, 240.0, role="light", placement="porch and cliff rim"),
        static_prop("potted_herb_urn", draw_urn(16, 24, "plum", "coral", "apricot", "gold", "jade", 0), role="decor", placement="doorstep and window sills"),
        static_prop("braided_hearth_rug", draw_floor_medallion(42, 30, "plum", "wine", "apricot", "gold", 0), layer="ground", role="decor", placement="in front of fireplace"),
        static_prop("wooden_cot_bed", draw_pillar(24, 18, "plum", "wine", "rose", "cream"), role="decor", placement="sleeping loft corner"),
    ]

    return [
        ("theme_inverted_palace_silver", "Inverted Palace (Silver) Scenery", pal_silver),
        ("theme_inverted_palace_black", "Inverted Palace (Black) Scenery", pal_black),
        ("theme_doppel_theatre", "The Doppel Theatre Scenery", theatre),
        ("theme_masquerade", "The Masquerade Scenery", masquerade),
        ("theme_toll_house", "The Toll House Scenery", toll_house),
        ("theme_archive", "The Archive of Lost Lamps Scenery", archive),
        ("theme_endless_stair", "The Endless Stair Scenery", endless_stair),
        ("theme_wick_house", "The Wick House Hub Scenery", wick_house),
    ]
