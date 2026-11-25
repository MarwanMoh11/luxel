"""Islands 5 & 6 themes: meteor_vault, planetarium, freefall, ember_express (interior+roof), iron_colossus, forge_deep."""
from __future__ import annotations

from typing import Any

import numpy as np

from .base import ThemePainter, ThemeSpec
from .kit import IX


class EmberExpressInteriorPainter(ThemePainter):
    """Ember Express interior: automatically paints glowing sunset/slag train windows along the north wall."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        dn_open = ~ctx["n_dn_wall"]
        xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
        # Carriage windows every 32px along south-facing carriage bulkhead walls
        seg = xs % 32
        win = m_wall & dn_open & (seg >= 7) & (seg <= 24) & (ly >= ts - 5) & (ly <= ts - 2)
        frame = win & ((seg == 7) | (seg == 24) | (ly == ts - 5) | (ly == ts - 2))
        pane = win & (~frame)
        # Sunset-slag gradient streaking past the train windows
        buf[pane & (ly == ts - 4)] = IX["gold"]
        buf[pane & (ly == ts - 3)] = IX["coral"]
        # Occasional passing telegraph pole silhouette
        pole = pane & ((xs % 96) == 14)
        buf[pole] = IX["night"]
        buf[frame] = IX["apricot"]


class EmberExpressRoofPainter(ThemePainter):
    """Ember Express roof: rivets & coupling seam markers at car edges."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        xs, ys = ctx["xs"], ctx["ys"]
        # Bright brass safety grab-rails along north/south carriage eaves
        n_eave = m_walk & ctx["n_up_abyss"] & (ctx["ly"] == 2) & ((xs % 8) < 6)
        s_eave = m_walk & ctx["n_dn_abyss"] & (ctx["ly"] == ctx["ts"] - 3) & ((xs % 8) < 6)
        buf[n_eave | s_eave] = IX["apricot"]


class IronColossusPainter(ThemePainter):
    """Iron Colossus: furnace-glow bulkhead vents, riveted structural rib spans & warm magma edge glow."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        m_walk = ctx["m_walk"]
        dn_open = ~ctx["n_dn_wall"]
        xs, ys, ly, ts = ctx["xs"], ctx["ys"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        # Glowing furnace slit vents every 40px along south bulkhead faces
        vx = xs % 40
        vent = m_wall & dn_open & (vx >= 16) & (vx <= 23) & (ly >= ts - 4) & (ly <= ts - 3)
        buf[vent & ((vx % 2) == 0)] = IX["coral"]
        buf[vent & ((vx % 2) == 1) & (ly == ts - 4)] = IX["gold"]
        # Subtle warm brass structural rib seams every 64px across walkable hull floors
        rib = m_walk & ctx["m_ground"] & ((xs % 64) == 0) & ((ys % 4) != 0)
        buf[rib] = IX["wine"]
        rib_riv = m_walk & ctx["m_ground"] & ((xs % 64) == 2) & ((ys % 16) == 8)
        buf[rib_riv] = IX["apricot"]
        # Warm furnace reflection along walkable lips bordering molten water
        near_lava = m_walk & (ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"])
        lip = near_lava & (
            (ctx["n_up_water"] & (ly < 3))
            | (ctx["n_dn_water"] & (ly >= ts - 3))
            | (ctx["n_lt_water"] & (ctx["lx"] < 3))
            | (ctx["n_rt_water"] & (ctx["lx"] >= ts - 3))
        ) & (bg < 0.45)
        buf[lip] = IX["coral"]


class ForgeDeepPainter(ThemePainter):
    """Deep Forge & Great Kiln: warm hearth wall vents & molten rim glow on basalt stonework."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        m_walk = ctx["m_walk"]
        dn_open = ~ctx["n_dn_wall"]
        xs, lx, ly, ts = ctx["xs"], ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        # Recessed kiln-hearth ember slits every 48px along south-facing masonry walls
        vx = xs % 48
        slit = m_wall & dn_open & (vx >= 20) & (vx <= 27) & (ly >= ts - 4) & (ly <= ts - 3)
        buf[slit] = IX["coral"]
        buf[slit & (vx >= 22) & (vx <= 25) & (ly == ts - 4)] = IX["gold"]
        # Subtle warm ember bounce along walkable flagstones adjacent to lava pits/rivers
        near_hot = m_walk & (
            ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
            | ctx["n_up_abyss"] | ctx["n_dn_abyss"] | ctx["n_lt_abyss"] | ctx["n_rt_abyss"]
        )
        edge_glow = near_hot & (
            ((ctx["n_up_water"] | ctx["n_up_abyss"]) & (ly == 2))
            | ((ctx["n_dn_water"] | ctx["n_dn_abyss"]) & (ly == ts - 3))
            | ((ctx["n_lt_water"] | ctx["n_lt_abyss"]) & (lx == 2))
            | ((ctx["n_rt_water"] | ctx["n_rt_abyss"]) & (lx == ts - 3))
        ) & (bg < 0.35)
        buf[edge_glow] = IX["apricot"]


class AshenKilnOverworldPainter(ThemePainter):
    """Ashen Kiln Overworld: luminous volcanic ash-basalt caldera, starry cosmos & cliff overhangs."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_void = ctx["m_void"]
        n_up_land = ctx["n_up_land"]
        xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        # Volcanic terraced cliff skirt hanging below southern island rims into starry void
        cliff = m_void & n_up_land & (ly < 6)
        buf[cliff & (ly == 0)] = IX["mauve"]
        buf[cliff & (ly == 1)] = IX["plum"]
        buf[cliff & (ly == 2)] = np.where((xs % 4 == 0) | (bg[cliff & (ly == 2)] < 0.5), IX["dusk"], IX["plum"])
        buf[cliff & (ly == 3)] = IX["dusk"]
        buf[cliff & (ly == 4)] = np.where(bg[cliff & (ly == 4)] < 0.65, IX["night"], IX["dusk"])
        buf[cliff & (ly == 5) & (bg < 0.55)] = IX["night"]
        # Subtle glowing cinder cracks on open volcanic ash terraces
        m_ground = ctx["m_ground"]
        nb = ctx["n_broad"]
        ember_vein = m_ground & (nb > 0.76) & (((xs + ctx["ys"] * 2) % 19) == 0) & (bg < 0.45)
        buf[ember_vein] = IX["coral"]


SPECS_5_6: list[tuple[ThemeSpec, type[ThemePainter]]] = [
    (
        ThemeSpec(
            id="meteor_vault",
            name="The Meteor Vault",
            island=5,
            floor_style="meteor_basalt",
            floor_ramp=("deep", "blue", "dusk", "mauve"),
            floor_seam="night",
            floor_bevel="sky",
            floor_accent_a="gold",
            floor_accent_b="ice",
            path_style="inlaid_strip",
            path_main="dusk",
            path_hi="mauve",
            path_edge="night",
            path_trim="gold",
            wall_style="riveted_iron",
            wall_cap=("night", "deep", "blue"),
            wall_lip="sky",
            wall_face="deep",
            wall_face_hi="sky",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="void",
            water_mid="night",
            water_hi="deep",
            water_foam="sky",
            pit_style="star_chasm",
            void_style="starry_cosmos",
            rim_hi="ice",
            rim_mid="gold",
            bridge_style="iron_grate",
            bridge_main="deep",
            bridge_hi="sky",
            bridge_rail="gold",
            bridge_dark="night",
            seed=511,
            prop_sheet="theme_meteor_vault",
            door_sheet="theme_meteor_vault_doors",
            special_tiles=(),
            default_decor=("cracks", "circle", "compass"),
            notes="Cosmic asteroid treasury: faceted basalt slabs with gold & ice mineral veins over starry gravity wells.",
        ),
        ThemePainter,
    ),
    (
        ThemeSpec(
            id="planetarium",
            name="The Planetarium",
            island=5,
            floor_style="star_dome",
            floor_ramp=("deep", "blue", "sky"),
            floor_seam="night",
            floor_bevel="ice",
            floor_accent_a="apricot",
            floor_accent_b="cream",
            path_style="inlaid_strip",
            path_main="deep",
            path_hi="blue",
            path_edge="night",
            path_trim="gold",
            wall_style="marble_balustrade",
            wall_cap=("night", "deep", "blue"),
            wall_lip="gold",
            wall_face="deep",
            wall_face_hi="sky",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="void",
            water_mid="night",
            water_hi="blue",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="starry_cosmos",
            rim_hi="gold",
            rim_mid="sky",
            bridge_style="stone_arch",
            bridge_main="blue",
            bridge_hi="sky",
            bridge_rail="gold",
            bridge_dark="deep",
            seed=521,
            prop_sheet="theme_planetarium",
            door_sheet="theme_planetarium_doors",
            special_tiles=("G:glass",),
            default_decor=("compass", "circle", "light_shaft"),
            notes="Dark star-chart dome: polished indigo stone with gilded meridian grids, star nodes & orbital arcs.",
        ),
        ThemePainter,
    ),
    (
        ThemeSpec(
            id="freefall",
            name="Observatory Freefall",
            island=5,
            floor_style="shattered_debris",
            floor_ramp=("blue", "mauve", "stone"),
            floor_seam="deep",
            floor_bevel="ice",
            floor_accent_a="gold",
            floor_accent_b="cream",
            path_style="inlaid_strip",
            path_main="stone",
            path_hi="cream",
            path_edge="dusk",
            path_trim="gold",
            wall_style="marble_balustrade",
            wall_cap=("deep", "mauve", "stone"),
            wall_lip="cream",
            wall_face="dusk",
            wall_face_hi="sky",
            wall_base="night",
            water_style="moon_mirror",
            water_deep="night",
            water_mid="deep",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="sky_freefall",
            rim_hi="cream",
            rim_mid="ice",
            bridge_style="stone_arch",
            bridge_main="stone",
            bridge_hi="ice",
            bridge_rail="gold",
            bridge_dark="deep",
            seed=531,
            prop_sheet="theme_freefall",
            door_sheet="theme_freefall_doors",
            special_tiles=(),
            default_decor=("cracks", "circle"),
            notes="Mid-air observatory collapse: fractured marble-slate debris suspended in streaking sunset/star wind.",
        ),
        ThemePainter,
    ),
    (
        ThemeSpec(
            id="ember_express",
            name="The Ember Express (Interior)",
            island=6,
            floor_style="train_carpet_deck",
            floor_ramp=("plum", "wine", "coral"),
            floor_seam="night",
            floor_bevel="apricot",
            floor_accent_a="gold",
            floor_accent_b="cream",
            path_style="carpet_runner",
            path_main="wine",
            path_hi="rose",
            path_edge="night",
            path_trim="gold",
            wall_style="riveted_iron",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="gold",
            wall_face="dusk",
            wall_face_hi="coral",
            wall_base="void",
            water_style="magma_river",
            water_deep="wine",
            water_mid="coral",
            water_hi="apricot",
            water_foam="gold",
            pit_style="lava_pit",
            void_style="train_rush",
            rim_hi="gold",
            rim_mid="apricot",
            bridge_style="iron_grate",
            bridge_main="mauve",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=611,
            prop_sheet="theme_ember_express",
            door_sheet="theme_ember_express_doors",
            special_tiles=("D:carpet", "H:grate", "R:rail"),
            default_decor=("rug", "grate", "window_strip"),
            notes="Moving foundry train interior: mahogany booths, plush wine aisle runner, glowing carriage windows, streaking sunset void.",
        ),
        EmberExpressInteriorPainter,
    ),
    (
        ThemeSpec(
            id="ember_express_roof",
            name="The Ember Express (Roof)",
            island=6,
            floor_style="train_roof_plate",
            floor_ramp=("plum", "mauve", "stone"),
            floor_seam="dusk",
            floor_bevel="apricot",
            floor_accent_a="gold",
            floor_accent_b="apricot",
            path_style="catwalk_grate",
            path_main="wine",
            path_hi="apricot",
            path_edge="dusk",
            path_trim="gold",
            wall_style="riveted_iron",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="coral",
            wall_face="night",
            wall_face_hi="apricot",
            wall_base="void",
            water_style="magma_river",
            water_deep="wine",
            water_mid="coral",
            water_hi="apricot",
            water_foam="gold",
            pit_style="lava_pit",
            void_style="train_rush",
            rim_hi="gold",
            rim_mid="apricot",
            bridge_style="iron_grate",
            bridge_main="mauve",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=617,
            prop_sheet="theme_ember_express_roof",
            door_sheet="theme_ember_express_doors",
            special_tiles=("H:grate", "R:rail"),
            default_decor=("grate", "inlay"),
            notes="Speeding carriage rooftops: luminous sunset-lit riveted steel roofs, brass grab-rails, warm grate catwalks, rushing ember blur.",
        ),
        EmberExpressRoofPainter,
    ),
    (
        ThemeSpec(
            id="iron_colossus",
            name="The Iron Colossus",
            island=6,
            floor_style="colossus_hull",
            floor_ramp=("plum", "mauve", "stone"),
            floor_seam="dusk",
            floor_bevel="stone",
            floor_accent_a="apricot",
            floor_accent_b="coral",
            path_style="catwalk_grate",
            path_main="wine",
            path_hi="coral",
            path_edge="dusk",
            path_trim="gold",
            wall_style="riveted_iron",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="apricot",
            wall_face="dusk",
            wall_face_hi="coral",
            wall_base="void",
            water_style="magma_river",
            water_deep="wine",
            water_mid="coral",
            water_hi="apricot",
            water_foam="gold",
            pit_style="gear_chasm",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="coral",
            bridge_style="iron_grate",
            bridge_main="mauve",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=621,
            prop_sheet="theme_iron_colossus",
            door_sheet="theme_iron_colossus_doors",
            special_tiles=("H:grate", "R:rail"),
            default_decor=("grate", "circle", "cracks"),
            notes="Inside the walking giant: burnished riveted foundry hull decks, glowing furnace wall slits, giant gear-chasm shafts.",
        ),
        IronColossusPainter,
    ),
    (
        ThemeSpec(
            id="forge_deep",
            name="The Deep Forge",
            island=6,
            floor_style="forge_anvil_hall",
            floor_ramp=("plum", "mauve", "stone"),
            floor_seam="dusk",
            floor_bevel="stone",
            floor_accent_a="coral",
            floor_accent_b="gold",
            path_style="catwalk_grate",
            path_main="mauve",
            path_hi="stone",
            path_edge="dusk",
            path_trim="apricot",
            wall_style="masonry",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="coral",
            wall_face="dusk",
            wall_face_hi="wine",
            wall_base="void",
            water_style="magma_river",
            water_deep="wine",
            water_mid="coral",
            water_hi="apricot",
            water_foam="gold",
            pit_style="lava_pit",
            void_style="crypt_abyss",
            rim_hi="gold",
            rim_mid="coral",
            bridge_style="iron_grate",
            bridge_main="mauve",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=631,
            prop_sheet="theme_forge_deep",
            door_sheet="theme_forge_deep_doors",
            special_tiles=("H:grate",),
            default_decor=("grate", "cracks", "circle"),
            notes="First Forge & deep Great Kiln: luminous ash-basalt anvil slabs with molten heat-veins and magma rivers.",
        ),
        ForgeDeepPainter,
    ),
    (
        ThemeSpec(
            id="ashen_kiln",
            name="Ashen Kiln Overworld",
            island=6,
            floor_style="cave_floor",
            floor_ramp=("plum", "mauve", "stone"),
            floor_seam="dusk",
            floor_bevel="stone",
            floor_accent_a="coral",
            floor_accent_b="apricot",
            path_style="flagstone",
            path_main="mauve",
            path_hi="stone",
            path_edge="dusk",
            path_trim="apricot",
            wall_style="cavern_rock",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="apricot",
            wall_face="dusk",
            wall_face_hi="wine",
            wall_base="void",
            water_style="magma_river",
            water_deep="wine",
            water_mid="coral",
            water_hi="apricot",
            water_foam="gold",
            pit_style="lava_pit",
            void_style="starry_cosmos",
            rim_hi="apricot",
            rim_mid="coral",
            bridge_style="iron_grate",
            bridge_main="mauve",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=601,
            organic_edges=True,
            prop_sheet="island6_scenery",
            door_sheet="island6_doors",
            special_tiles=("H:grate", "R:rail"),
            default_decor=("cracks", "grate"),
            notes="Ashen Kiln volcanic caldera archipelago: luminous ash-basalt terraces, slag spits, rail cuttings & magma delta.",
        ),
        AshenKilnOverworldPainter,
    ),
    (
        ThemeSpec(
            id="kiln_cavern",
            name="Ashen Kiln Lava Tube (Luminous)",
            island=6,
            floor_style="cave_floor",
            floor_ramp=("plum", "mauve", "stone"),
            floor_seam="dusk",
            floor_bevel="stone",
            floor_accent_a="coral",
            floor_accent_b="gold",
            path_style="sand_trail",
            path_main="mauve",
            path_hi="stone",
            path_edge="dusk",
            path_trim="apricot",
            wall_style="cavern_rock",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="coral",
            wall_face="dusk",
            wall_face_hi="wine",
            wall_base="void",
            water_style="magma_river",
            water_deep="wine",
            water_mid="coral",
            water_hi="apricot",
            water_foam="gold",
            pit_style="lava_pit",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="coral",
            bridge_style="iron_grate",
            bridge_main="mauve",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=606,
            prop_sheet="theme_cave_6",
            door_sheet="theme_cave_6_doors",
            special_tiles=(),
            default_decor=("cracks", "stain"),
            notes="Luminous Ashen Kiln lava-tube caverns: warm ash-basalt bedrock with glowing slag fissures and magma pools.",
        ),
        ForgeDeepPainter,
    ),
]
