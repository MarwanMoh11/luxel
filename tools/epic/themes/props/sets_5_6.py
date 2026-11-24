"""Scenery prop atlases for Islands 5 & 6 themes:
theme_meteor_vault, theme_planetarium, theme_freefall, theme_ember_express (with scrolling window strips),
theme_ember_express_roof, theme_iron_colossus, theme_forge_deep.
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


def _crystal_cluster(f: int, dk: str = "deep", mid: str = "blue", hi: str = "sky", core: str = "ice") -> Image.Image:
    c = PCanvas(22, 26)
    sh = (0, 1, 0, 1)[f % 4]
    # Three angled crystal spires
    for cx, h, w in ((6, 13, 3), (11, 20, 4), (16, 15, 3)):
        top = 24 - h
        for y in range(top, 24):
            hw = min(w, (y - top) // 2 + 1)
            for x in range(cx - hw, cx + hw + 1):
                col = core if (x == cx - hw + 1 and (y + sh) % 3 == 0) else (hi if x < cx else (dk if x > cx + 1 else mid))
                c.set(x, y, col)
        c.set(cx, top, "cream" if (f % 2 == 0) else core)
    return c.finalize(24, 28)


def _star_globe(f: int) -> Image.Image:
    c = PCanvas(24, 30)
    c.bevel(6, 23, 12, 5, "plum", "apricot", "night")
    c.vline(12, 19, 23, "gold")
    # Brass meridian ring
    c.ellipse(12, 11, 9.5, 9.5, "apricot")
    c.ellipse(12, 11, 8.0, 8.0, "deep")
    c.shaded_ellipse(12, 11, 7.2, 7.2, "night", "deep", "blue")
    # Rotating star belt
    ox = (f % 4) * 2
    for sx, sy in ((8, 9), (12, 12), (15, 8), (10, 14)):
        px = 7 + ((sx - 7 + ox) % 10)
        c.set(px, sy, "cream" if (sx % 2 == 0) else "gold")
    c.line(4, 15, 20, 7, "gold")
    return c.finalize(26, 32)


def _floating_shard(f: int, dk: str = "deep", mid: str = "sky", hi: str = "ice") -> Image.Image:
    c = PCanvas(18, 28)
    dy = (0, -2, -1, 1)[f % 4]
    cy = 12 + dy
    for y in range(cy - 7, cy + 8):
        hw = max(1, 5 - abs(y - cy) // 2)
        for x in range(9 - hw, 9 + hw + 1):
            c.set(x, y, hi if x < 9 else (dk if x > 10 else mid))
    c.set(8, cy - 5, "cream")
    return c.finalize(20, 30)


def _scrolling_train_window(f: int, slag: bool = False) -> Image.Image:
    """Animated 4-frame scrolling landscape window strip for Ember Express walls!"""
    c = PCanvas(44, 16)
    c.bevel(0, 0, 44, 16, "dusk", "gold", "night")
    c.rect(2, 2, 40, 12, "plum" if not slag else "wine")
    shift = (f % 4) * 10
    for x in range(2, 42):
        wx = (x + shift) % 40
        # Horizon silhouette & speed streaks
        if not slag:
            c.set(x, 3, "gold")
            c.set(x, 4, "apricot")
            c.set(x, 5, "coral")
            c.set(x, 6, "coral" if (wx % 4 < 2) else "wine")
            # Passing ridge & telegraph poles
            ridge_h = 3 + int(2.2 * math.sin(wx * 0.25))
            for y in range(14 - ridge_h, 14):
                c.set(x, y, "dusk" if y < 12 else "night")
            if wx in (6, 7):
                c.vline(x, 2, 13, "night")
        else:
            c.set(x, 3, "apricot")
            c.set(x, 4, "coral")
            c.set(x, 5, "wine")
            for y in range(9, 14):
                c.set(x, y, "gold" if ((wx + y) % 7 < 2) else ("coral" if y > 11 else "plum"))
            if wx in (12, 13):
                c.vline(x, 2, 13, "void")
    # Center brass mullion bar
    c.vline(21, 1, 14, "apricot")
    c.vline(22, 1, 14, "night")
    return c.finalize(46, 18, do_rim=False)


def _train_booth() -> Image.Image:
    c = PCanvas(28, 18)
    c.bevel(1, 2, 26, 8, "wine", "rose", "plum")
    c.bevel(1, 9, 26, 6, "plum", "coral", "night")
    c.hline(2, 25, 3, "gold")
    c.bevel(1, 5, 3, 10, "apricot", "gold", "wine")
    c.bevel(24, 5, 3, 10, "apricot", "gold", "wine")
    return c.finalize(30, 20)


def _coupling() -> Image.Image:
    c = PCanvas(26, 16)
    c.bevel(1, 3, 7, 10, "dusk", "mauve", "night")
    c.bevel(18, 3, 7, 10, "dusk", "mauve", "night")
    c.bevel(7, 6, 12, 4, "plum", "apricot", "night")
    c.rect(11, 4, 4, 8, "gold")
    return c.finalize(28, 18)


def _smokestack(f: int) -> Image.Image:
    c = PCanvas(24, 34)
    c.bevel(6, 14, 12, 18, "night", "dusk", "void")
    c.bevel(4, 12, 16, 4, "dusk", "apricot", "night")
    c.hline(6, 17, 22, "coral")
    # Billowing ember smoke puffs trailing right
    ox = (f % 4) * 2
    c.shaded_ellipse(12 + ox // 2, 9, 5.0, 3.2, "dusk", "mauve", "stone")
    c.shaded_ellipse(16 + ox // 2, 5, 4.5, 2.8, "night", "dusk", "mauve")
    c.set(11 + (f % 3), 10, "coral")
    c.set(14 + (f % 2), 7, "gold")
    return c.finalize(26, 36)


def _piston(f: int) -> Image.Image:
    c = PCanvas(22, 34)
    # Heavy steel base housing
    c.bevel(3, 18, 16, 14, "night", "dusk", "void")
    c.hline(4, 17, 22, "coral")
    # Pumping brass rod & top cap
    dy = (0, 3, 5, 2)[f % 4]
    c.bevel(8, 6 + dy, 6, 14 - dy, "coral", "apricot", "plum")
    c.bevel(2, 2 + dy, 18, 6, "dusk", "stone", "night")
    c.hline(4, 17, 4 + dy, "gold")
    # Steam puff at bottom stroke
    if f in (2, 3):
        c.ellipse(3, 17, 2.2, 1.5, "ice")
        c.ellipse(19, 17, 2.2, 1.5, "stone")
    return c.finalize(24, 36)


def _anvil() -> Image.Image:
    c = PCanvas(28, 20)
    # Wooden anvil stump
    c.bevel(6, 12, 16, 7, "plum", "wine", "night")
    # Horned steel anvil top
    c.bevel(5, 4, 18, 6, "dusk", "stone", "night")
    c.line(1, 6, 6, 5, "stone")
    c.line(1, 7, 6, 8, "dusk")
    c.bevel(8, 10, 12, 3, "night", "mauve", "void")
    c.hline(6, 21, 5, "cream")
    return c.finalize(30, 22)


def _crucible(f: int) -> Image.Image:
    c = PCanvas(26, 26)
    c.bevel(4, 10, 18, 13, "night", "dusk", "void")
    c.shaded_ellipse(13, 10, 8.5, 3.8, "wine", "coral", "gold")
    c.ellipse(13, 10, 5.5, 2.2, "cream" if (f % 2 == 0) else "gold")
    draw_flame(c, 13, 7, f, tall=5)
    c.hline(5, 20, 17, "coral")
    return c.finalize(28, 28)


def build_sets_5_6() -> list[tuple[str, str, list[PropDef]]]:
    # 1. theme_meteor_vault (11 props)
    meteor_vault = [
        anim_prop("meteor_crystal_cluster", lambda f: _crystal_cluster(f, "deep", "blue", "sky", "ice"), 4, 300.0, role="landmark", placement="vault alcoves and ledges"),
        anim_prop("gravity_gyro_pillar", lambda f: draw_pillar(18, 34, "night", "deep", "sky", "gold", glow_band="ice", f=f), 4, 260.0, role="landmark", placement="around gravity wells"),
        static_prop("obsidian_vault_arch", draw_archway(46, 46, "void", "deep", "blue", "gold", "ice"), role="landmark", placement="vault room entrances"),
        static_prop("star_ore_crate", draw_urn(18, 20, "night", "deep", "blue", "gold"), role="cover", placement="treasury alcoves"),
        anim_prop("floating_meteor_shard", lambda f: _floating_shard(f, "deep", "blue", "gold"), 4, 280.0, role="ambient", placement="near starry pits"),
        anim_prop("vault_lantern_brazier", lambda f: draw_brazier(20, 26, "night", "deep", "sky", f, c_out="blue", c_mid="sky", c_hi="gold"), 4, 240.0, role="light", placement="safe platform corners"),
        anim_prop("brass_caliper_stand", _star_globe, 4, 340.0, role="decor", placement="vault side halls"),
        static_prop("cracked_meteor_boulder", draw_pillar(20, 20, "night", "deep", "mauve", "gold", broken=True), role="cover", placement="arena cover"),
        static_prop("celestial_safe_chest", draw_pillar(22, 18, "night", "deep", "blue", "gold"), role="decor", placement="treasury corners"),
        anim_prop("orbital_ring_totem", lambda f: draw_gear(26, 26, "deep", "apricot", "gold", f), 4, 280.0, role="landmark", placement="orbital switches"),
        anim_prop("gravity_floor_seal", lambda f: draw_floor_medallion(36, 36, "deep", "blue", "gold", "ice", f), 2, 480.0, layer="ground", role="landmark", placement="under gravity wells"),
    ]

    # 2. theme_planetarium (11 props)
    planetarium = [
        anim_prop("brass_star_globe", _star_globe, 4, 300.0, role="landmark", placement="dome study corners"),
        anim_prop("constellation_projector", lambda f: draw_brazier(22, 28, "deep", "apricot", "gold", f, c_out="blue", c_mid="sky", c_hi="ice"), 4, 260.0, role="light", placement="constellation focus"),
        static_prop("zodiac_pillar_stone", draw_pillar(16, 34, "night", "deep", "sky", "gold"), role="cover", placement="circular dome colonnade"),
        static_prop("dome_arch_rib", draw_archway(46, 46, "night", "deep", "sky", "gold", "cream"), role="landmark", placement="north dome entrance"),
        static_prop("star_chart_lectern", draw_pillar(18, 24, "deep", "blue", "apricot", "gold"), role="decor", placement="reading niches"),
        anim_prop("hanging_orrery_pendulum", lambda f: draw_gear(28, 28, "deep", "apricot", "gold", f), 4, 300.0, role="ambient", placement="overhead/wall mounts"),
        anim_prop("planetarium_lantern", lambda f: draw_lantern_post(18, 30, "deep", "blue", "gold", "sky", "ice", f), 4, 260.0, role="light", placement="walkway junctions"),
        anim_prop("brass_telescope_stand", _star_globe, 4, 420.0, role="landmark", placement="balcony overlooks"),
        static_prop("celestial_bench", draw_pillar(26, 14, "deep", "blue", "sky", "gold", broken=True), role="decor", placement="observation rings"),
        anim_prop("zodiac_floor_dial", lambda f: draw_floor_medallion(40, 40, "deep", "apricot", "gold", "cream", f), 2, 520.0, layer="ground", role="landmark", placement="planetarium center"),
        anim_prop("floating_prism_lens", lambda f: _floating_shard(f, "blue", "sky", "cream"), 4, 260.0, role="ambient", placement="starlight nodes"),
    ]

    # 3. theme_freefall (10 props)
    freefall = [
        static_prop("tilted_marble_column", draw_pillar(16, 30, "deep", "mauve", "stone", "cream", broken=True), role="cover", placement="shattered islands"),
        anim_prop("floating_debris_shard", lambda f: _floating_shard(f, "dusk", "mauve", "stone"), 4, 240.0, role="ambient", placement="rim edges"),
        static_prop("shattered_balustrade", draw_pillar(24, 16, "deep", "mauve", "stone", "ice", broken=True), role="cover", placement="platform lips"),
        anim_prop("drifting_star_lantern", lambda f: draw_lantern_post(18, 28, "deep", "mauve", "gold", "sky", "cream", f), 4, 220.0, role="light", placement="zip landing pads"),
        anim_prop("broken_orrery_ring", lambda f: draw_gear(28, 28, "dusk", "apricot", "gold", f), 4, 260.0, role="landmark", placement="central debris"),
        static_prop("tether_anchor_post", draw_pillar(14, 24, "deep", "blue", "gold", "cream"), role="decor", placement="zip anchor hints"),
        static_prop("cracked_dome_arch", draw_archway(44, 42, "deep", "mauve", "stone", "gold", "ice"), role="landmark", placement="major debris island"),
        anim_prop("wind_ribbon_banner", lambda f: draw_banner(18, 32, "stone", "deep", "blue", "sky", "gold", f), 4, 180.0, role="ambient", placement="windswept edges"),
        static_prop("fallen_telescope_tube", draw_pillar(26, 14, "plum", "apricot", "gold", "cream", broken=True), role="decor", placement="wrecked terrace"),
        anim_prop("star_chime_crystal", lambda f: _crystal_cluster(f, "blue", "sky", "ice", "cream"), 4, 260.0, role="ambient", placement="island corners"),
    ]

    # 4. theme_ember_express (13 props — includes animated scrolling window strips!)
    ember_express = [
        anim_prop("train_window_sunset", lambda f: _scrolling_train_window(f, False), 4, 160.0, layer="sort", role="ambient", placement="mounted along north carriage walls"),
        anim_prop("train_window_slag", lambda f: _scrolling_train_window(f, True), 4, 140.0, layer="sort", role="ambient", placement="mounted along north walls in kiln zones"),
        static_prop("plush_cabin_booth", _train_booth(), role="cover", placement="lining carriage sides"),
        static_prop("brass_luggage_rack", draw_pillar(22, 18, "plum", "apricot", "gold", "cream"), role="decor", placement="carriage corners"),
        anim_prop("iron_stove_brazier", _crucible, 4, 220.0, role="light", placement="car ends for warmth"),
        anim_prop("carriage_wall_lamp", lambda f: draw_lantern_post(16, 26, "plum", "apricot", "gold", "apricot", "gold", f), 4, 220.0, role="light", placement="between windows"),
        static_prop("brass_coupling_link", _coupling(), role="landmark", placement="between train cars"),
        static_prop("ticket_punch_desk", draw_pillar(20, 22, "night", "plum", "wine", "gold"), role="cover", placement="conductor car"),
        static_prop("coal_bucket_crate", draw_urn(16, 20, "void", "night", "dusk", "coral"), role="decor", placement="near stoves"),
        anim_prop("emergency_brake_wheel", lambda f: draw_gear(20, 20, "wine", "coral", "gold", f), 4, 300.0, role="landmark", placement="bulkhead exits"),
        anim_prop("conductor_bell_post", lambda f: draw_lantern_post(18, 28, "night", "plum", "gold", "coral", "gold", f, tall_hook=False), 4, 260.0, role="ambient", placement="carriage doors"),
        static_prop("hanging_strap_arch", draw_archway(44, 42, "night", "plum", "wine", "gold", "coral"), role="landmark", placement="car doorway bulkhead"),
        anim_prop("steam_pipe_column", _piston, 4, 260.0, role="cover", placement="engine car sides"),
    ]

    # 5. theme_ember_express_roof (11 props)
    ember_roof = [
        anim_prop("loco_smokestack", _smokestack, 4, 200.0, role="landmark", placement="locomotive roof centerline"),
        static_prop("roof_vent_cowling", draw_pillar(18, 18, "night", "dusk", "mauve", "coral"), role="cover", placement="spaced down carriage roofs"),
        anim_prop("brass_steam_whistle", lambda f: draw_pillar(14, 26, "plum", "apricot", "gold", "cream", glow_band="cream", f=f), 4, 240.0, role="landmark", placement="engine cab roof"),
        static_prop("iron_coupling_bridge", _coupling(), role="landmark", placement="car-to-car jumps"),
        static_prop("coal_tender_crate", draw_pillar(22, 18, "void", "night", "dusk", "coral", broken=True), role="cover", placement="tender car"),
        anim_prop("roof_signal_lantern", lambda f: draw_lantern_post(18, 28, "night", "dusk", "apricot", "coral", "gold", f), 4, 200.0, role="light", placement="car ends"),
        anim_prop("pantograph_spark_arc", lambda f: draw_archway(44, 40, "night", "dusk", "mauve", "gold", "cream", f, hanging_lamp=True), 4, 220.0, role="landmark", placement="mid-car frame"),
        static_prop("riveted_hatch_cover", draw_floor_medallion(24, 24, "night", "dusk", "apricot", "coral", 0), layer="ground", role="decor", placement="carriage roof access"),
        anim_prop("handbrake_wheel_post", lambda f: draw_gear(20, 20, "night", "dusk", "apricot", f), 4, 280.0, role="decor", placement="brake platforms"),
        anim_prop("cinder_brazier_cage", lambda f: draw_brazier(20, 24, "night", "dusk", "coral", f), 4, 200.0, role="light", placement="roof walkways"),
        anim_prop("wind_vane_fin", lambda f: draw_banner(16, 26, "mauve", "wine", "coral", "apricot", "gold", f), 4, 180.0, role="ambient", placement="roof eaves"),
    ]

    # 6. theme_iron_colossus (12 props)
    iron_colossus = [
        anim_prop("hydraulic_piston_pillar", _piston, 4, 240.0, role="landmark", placement="colossus ribs and leg halls"),
        anim_prop("giant_foundry_gear", lambda f: draw_gear(38, 38, "night", "plum", "apricot", f), 4, 260.0, role="landmark", placement="joint chambers"),
        anim_prop("brass_steam_pipe_arch", lambda f: draw_archway(46, 46, "void", "dusk", "mauve", "apricot", "coral", f, hanging_lamp=True), 4, 280.0, role="landmark", placement="belly furnace doors"),
        anim_prop("pressure_gauge_dial", lambda f: draw_gear(22, 22, "plum", "apricot", "gold", f), 4, 300.0, role="decor", placement="wall panels"),
        anim_prop("furnace_vent_grate", lambda f: draw_floor_medallion(28, 28, "night", "wine", "coral", "gold", f), 2, 340.0, layer="ground", role="light", placement="furnace deck floor"),
        static_prop("iron_chain_hoist", draw_pillar(16, 34, "void", "night", "dusk", "apricot"), role="cover", placement="hoist shafts"),
        static_prop("colossus_rib_buttress", draw_pillar(18, 36, "void", "dusk", "mauve", "coral"), role="cover", placement="hull side walls"),
        anim_prop("molten_crucible_vat", _crucible, 4, 220.0, role="light", placement="belly furnace"),
        static_prop("riveted_console_desk", draw_pillar(24, 18, "night", "dusk", "mauve", "gold"), role="cover", placement="head control deck"),
        anim_prop("colossus_lantern_post", lambda f: draw_lantern_post(18, 30, "void", "dusk", "coral", "coral", "gold", f), 4, 220.0, role="light", placement="catwalk corners"),
        anim_prop("steam_valve_wheel", lambda f: draw_gear(18, 18, "wine", "coral", "apricot", f), 4, 320.0, role="decor", placement="pipe walls"),
        static_prop("slag_ingot_stack", _anvil(), role="cover", placement="deck alcoves"),
    ]

    # 7. theme_forge_deep (12 props)
    forge_deep = [
        static_prop("great_forge_anvil", _anvil(), role="landmark", placement="tempering chambers"),
        anim_prop("molten_slag_crucible", _crucible, 4, 220.0, role="light", placement="flanking casting pits"),
        anim_prop("bellows_hearth_stand", lambda f: draw_brazier(22, 26, "night", "plum", "coral", f), 4, 200.0, role="light", placement="beside anvils"),
        static_prop("iron_weapon_rack", draw_pillar(20, 28, "night", "dusk", "mauve", "apricot"), role="decor", placement="armory walls"),
        anim_prop("ingot_mold_trough", lambda f: draw_floor_medallion(32, 22, "night", "wine", "coral", "gold", f), 2, 360.0, layer="ground", role="decor", placement="casting lanes"),
        anim_prop("foundry_crane_hook", lambda f: draw_archway(46, 46, "void", "night", "dusk", "coral", "gold", f, hanging_lamp=True), 2, 460.0, role="landmark", placement="kiln thresholds"),
        anim_prop("ember_brazier_pillar", lambda f: draw_brazier(20, 28, "void", "dusk", "apricot", f), 4, 200.0, role="light", placement="arena corners"),
        static_prop("basalt_forge_arch", draw_archway(46, 46, "void", "night", "plum", "apricot", "coral"), role="landmark", placement="boss entrance"),
        static_prop("quench_barrel_tub", draw_urn(18, 22, "night", "plum", "mauve", "sky"), role="cover", placement="next to anvils"),
        anim_prop("chained_slag_cauldron", _crucible, 4, 240.0, role="light", placement="molten overlook"),
        anim_prop("tempering_floor_seal", lambda f: draw_floor_medallion(38, 38, "night", "coral", "gold", "cream", f), 2, 440.0, layer="ground", role="landmark", placement="forge boss center"),
        anim_prop("slag_chimney_vent", _smokestack, 4, 220.0, role="landmark", placement="kiln perimeter walls"),
    ]

    return [
        ("theme_meteor_vault", "The Meteor Vault Scenery", meteor_vault),
        ("theme_planetarium", "The Planetarium Scenery", planetarium),
        ("theme_freefall", "Observatory Freefall Scenery", freefall),
        ("theme_ember_express", "The Ember Express (Interior) Scenery", ember_express),
        ("theme_ember_express_roof", "The Ember Express (Roof) Scenery", ember_roof),
        ("theme_iron_colossus", "The Iron Colossus Scenery", iron_colossus),
        ("theme_forge_deep", "The Deep Forge Scenery", forge_deep),
    ]
