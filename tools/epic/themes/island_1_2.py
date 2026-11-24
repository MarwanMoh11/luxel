"""Islands 1 & 2 themes: undercroft, manor, great_toll_shaft, galleon, locks, leviathan_belly, seabed."""
from __future__ import annotations

from typing import Any

import numpy as np

from .base import ThemePainter, ThemeSpec
from .kit import IX, LIGHT_IX, SHADE_IX


class UndercroftPainter(ThemePainter):
    """Bell Isle catacombs: arched bone-niche recesses along south walls + bronze echo rings."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        dn_open = ~ctx["n_dn_wall"]
        xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
        # Arched crypt alcoves spaced every 32px along south-facing walls
        alcove = m_wall & dn_open & (ly >= ts - 5) & (ly <= ts - 2)
        ax = xs % 32
        in_arch = alcove & (ax >= 13) & (ax <= 18) & ~((ly == ts - 5) & ((ax == 13) | (ax == 18)))
        buf[in_arch] = IX["void"]
        # Tiny pale bone/urn glints inside crypt alcoves
        glint = alcove & (ly == ts - 3) & ((ax == 15) | (ax == 16))
        buf[glint] = IX["stone"]


class ManorPainter(ThemePainter):
    """Bellmaker's Manor: gilded framed wall portraits along wide south-facing wainscot walls."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        dn_open = ~ctx["n_dn_wall"]
        xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
        # Hanging portrait frames every 48px on south walls
        px_i = xs % 48
        frame = m_wall & dn_open & (px_i >= 20) & (px_i <= 27) & (ly >= ts - 6) & (ly <= ts - 2)
        border = frame & ((px_i == 20) | (px_i == 27) | (ly == ts - 6) | (ly == ts - 2))
        inner = frame & (~border)
        buf[inner] = IX["deep"]
        buf[border] = IX["gold"]
        # Tiny pale portrait face silhouette inside
        face = inner & (ly == ts - 4) & ((px_i == 23) | (px_i == 24))
        buf[face] = IX["apricot"]


class LocksPainter(ThemePainter):
    """Smugglers' Locks: water-level tide marks along south quay walls."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        dn_open = ~ctx["n_dn_wall"]
        ly, ts = ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        damp = m_wall & dn_open & (ly >= ts - 3) & (ly < ts - 1) & (bg < 0.55)
        buf[damp] = IX["pine"]


SPECS_1_2: list[tuple[ThemeSpec, type[ThemePainter]]] = [
    (
        ThemeSpec(
            id="undercroft",
            name="The Undercroft",
            island=1,
            floor_style="flagstone_crypt",
            floor_ramp=("dusk", "mauve", "stone"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="pine",
            floor_accent_b="gold",
            path_style="carpet_runner",
            path_main="plum",
            path_hi="wine",
            path_edge="night",
            path_trim="gold",
            wall_style="masonry",
            wall_cap=("night", "dusk", "mauve"),
            wall_lip="stone",
            wall_face="dusk",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="rain_water",
            water_deep="night",
            water_mid="deep",
            water_hi="blue",
            water_foam="sky",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="stone",
            rim_mid="mauve",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="apricot",
            bridge_dark="dusk",
            seed=111,
            prop_sheet="theme_undercroft",
            door_sheet="theme_undercroft_doors",
            special_tiles=("S:stairs", "D:carpet"),
            default_decor=("circle", "cracks", "stain"),
            notes="Bell Isle catacombs beneath the chapel; damp flagstones, arched bone niches, bronze tone rings.",
        ),
        UndercroftPainter,
    ),
    (
        ThemeSpec(
            id="manor",
            name="The Bellmaker's Manor",
            island=1,
            floor_style="herringbone_parquet",
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
            wall_style="wainscot",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="apricot",
            wall_face="plum",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="rain_water",
            water_deep="night",
            water_mid="deep",
            water_hi="blue",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="gold",
            rim_mid="apricot",
            bridge_style="timber",
            bridge_main="wine",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="night",
            seed=121,
            prop_sheet="theme_manor",
            door_sheet="theme_manor_doors",
            special_tiles=("D:carpet", "S:stairs"),
            default_decor=("rug", "light_shaft", "window_strip"),
            notes="Stealth whodunit mansion: herringbone parquet, wine carpets, paneled wainscot & framed portraits.",
        ),
        ManorPainter,
    ),
    (
        ThemeSpec(
            id="great_toll_shaft",
            name="The Great Toll Shaft",
            island=1,
            floor_style="radial_shaft_deck",
            floor_ramp=("dusk", "mauve", "stone"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="apricot",
            floor_accent_b="gold",
            path_style="catwalk_grate",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="gold",
            wall_style="riveted_iron",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="gold",
            wall_face="dusk",
            wall_face_hi="apricot",
            wall_base="void",
            water_style="rain_water",
            water_deep="void",
            water_mid="night",
            water_hi="deep",
            water_foam="sky",
            pit_style="gear_chasm",
            void_style="shaft_drop",
            rim_hi="gold",
            rim_mid="apricot",
            bridge_style="iron_grate",
            bridge_main="dusk",
            bridge_hi="mauve",
            bridge_rail="gold",
            bridge_dark="night",
            seed=131,
            prop_sheet="theme_great_toll_shaft",
            door_sheet="theme_great_toll_shaft_doors",
            special_tiles=("H:grate",),
            default_decor=("circle", "grate", "cracks"),
            notes="Falling belfry set piece: radial bell-tower decking, bronze gear rings, rushing vertical drop.",
        ),
        ThemePainter,
    ),
    (
        ThemeSpec(
            id="galleon",
            name="The Drowned Galleon",
            island=2,
            floor_style="ship_planking",
            floor_ramp=("plum", "wine", "mauve"),
            floor_seam="night",
            floor_bevel="apricot",
            floor_accent_a="gold",
            floor_accent_b="stone",
            path_style="boardwalk",
            path_main="wine",
            path_hi="coral",
            path_edge="night",
            path_trim="gold",
            wall_style="ship_hull",
            wall_cap=("night", "plum", "wine"),
            wall_lip="apricot",
            wall_face="plum",
            wall_face_hi="coral",
            wall_base="void",
            water_style="canal_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="coral",
            bridge_style="timber",
            bridge_main="wine",
            bridge_hi="coral",
            bridge_rail="gold",
            bridge_dark="night",
            seed=211,
            prop_sheet="theme_galleon",
            door_sheet="theme_galleon_doors",
            special_tiles=("H:grate", "T:tide"),
            default_decor=("grate", "stain", "compass"),
            notes="Listing shipwreck: salt-bleached timber deck planks, oak ribs, brass portholes, sloshing bilge water.",
        ),
        ThemePainter,
    ),
    (
        ThemeSpec(
            id="locks",
            name="The Smugglers' Locks",
            island=2,
            floor_style="quay_masonry",
            floor_ramp=("deep", "blue", "mauve"),
            floor_seam="night",
            floor_bevel="sky",
            floor_accent_a="teal",
            floor_accent_b="apricot",
            path_style="boardwalk",
            path_main="plum",
            path_hi="wine",
            path_edge="night",
            path_trim="apricot",
            wall_style="masonry",
            wall_cap=("deep", "mauve", "stone"),
            wall_lip="ice",
            wall_face="deep",
            wall_face_hi="blue",
            wall_base="void",
            water_style="canal_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="ice",
            rim_mid="sky",
            bridge_style="timber",
            bridge_main="plum",
            bridge_hi="coral",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=221,
            prop_sheet="theme_locks",
            door_sheet="theme_locks_doors",
            special_tiles=("R:rail", "T:tide"),
            default_decor=("grate", "stain", "inlay"),
            notes="Canal locks and wharves: wet dressed harbor quays, timber lock decks, foaming canal channels.",
        ),
        LocksPainter,
    ),
    (
        ThemeSpec(
            id="leviathan_belly",
            name="The Leviathan's Belly",
            island=2,
            floor_style="organic_membrane",
            floor_ramp=("plum", "wine", "rose"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="coral",
            floor_accent_b="lime",
            path_style="sand_trail",
            path_main="stone",
            path_hi="cream",
            path_edge="plum",
            path_trim="rose",
            wall_style="organic_rib",
            wall_cap=("plum", "mauve", "stone"),
            wall_lip="cream",
            wall_face="wine",
            wall_face_hi="rose",
            wall_base="night",
            water_style="acid_digest",
            water_deep="pine",
            water_mid="teal",
            water_hi="jade",
            water_foam="lime",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="stone",
            rim_mid="rose",
            bridge_style="bone_span",
            bridge_main="stone",
            bridge_hi="cream",
            bridge_rail="rose",
            bridge_dark="plum",
            seed=231,
            prop_sheet="theme_leviathan_belly",
            door_sheet="theme_leviathan_belly_doors",
            special_tiles=(),
            default_decor=("stain", "cracks"),
            notes="Inside the Leviathan: ivory bone ribs, wine/rose membrane floor, bubbling jade/lime digestive pools.",
        ),
        ThemePainter,
    ),
    (
        ThemeSpec(
            id="seabed",
            name="Ebb Seabed",
            island=2,
            floor_style="tidal_seabed",
            floor_ramp=("pine", "teal", "jade", "stone"),
            floor_seam="deep",
            floor_bevel="ice",
            floor_accent_a="coral",
            floor_accent_b="rose",
            path_style="sand_trail",
            path_main="mauve",
            path_hi="stone",
            path_edge="pine",
            path_trim="ice",
            wall_style="cavern_rock",
            wall_cap=("deep", "pine", "teal"),
            wall_lip="sky",
            wall_face="deep",
            wall_face_hi="teal",
            wall_base="void",
            water_style="canal_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="ice",
            rim_mid="jade",
            bridge_style="timber",
            bridge_main="plum",
            bridge_hi="mauve",
            bridge_rail="sky",
            bridge_dark="night",
            seed=241,
            organic_edges=True,
            prop_sheet="theme_seabed",
            door_sheet="theme_seabed_doors",
            special_tiles=("T:tide",),
            default_decor=("stain", "circle"),
            notes="Exposed ocean floor at ebb tide: rippled wet sandbars, coral shelves, tidepools, barnacle reefs.",
        ),
        ThemePainter,
    ),
]
