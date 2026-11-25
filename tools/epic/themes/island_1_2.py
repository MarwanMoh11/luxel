"""Islands 1 & 2 themes: undercroft, manor, great_toll_shaft, galleon, locks, leviathan_belly, seabed."""
from __future__ import annotations

from typing import Any

import numpy as np

from .base import ThemePainter, ThemeSpec
from .kit import IX, LIGHT_IX, SHADE_IX, hash01_grid, ramp_blend


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


class GalleonPainter(ThemePainter):
    """The Drowned Galleon: calm, low-contrast ship timber distinct across hold, deck, and cabin."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        meta = ctx.get("meta", {})
        rid = str(meta.get("id", "")).lower()

        is_cabin = rid in ("galleon_r10",) or ("cabin" in rid) or ("boathouse" in rid)
        is_hold = rid in (
            "galleon_r1",
            "galleon_r2",
            "galleon_r3",
            "galleon_r4",
            "galleon_r5",
            "galleon_r6",
        )

        if is_hold:
            # Lower Hold: deep damp oak planking (wide 8px planks, quiet seams, damp bilge seepage)
            ph = 8
            pr = ys // ph
            py = ys % ph
            butt_off = (pr * 17) % 36
            px_b = (xs + butt_off) % 36
            plank_h = hash01_grid((xs + butt_off) // 36, pr, s.seed + 83)
            field = np.clip(nb * 0.55 + plank_h * 0.25 + warm * 0.12, 0.0, 0.85)
            out = ramp_blend(("dusk", "plum"), field, bg)
            # Soft dithered caulk seams (never harsh black zebra stripes)
            is_hseam = (py == 0) & (bg < 0.48)
            is_vseam = (px_b == 0) & (py > 0) & (bg < 0.42)
            out = np.where(is_hseam | is_vseam, IX["night"], out)
            # Subtle damp pine seepage near water edges
            wet_edge = ctx["n_dn_water"] | ctx["n_up_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
            out = np.where(wet_edge & (nf < 0.16) & (py > 0), IX["pine"], out)
            # Ultra-restrained plank catchlight
            out = np.where((py == 1) & (plank_h > 0.86) & (bg < 0.30), IX["mauve"], out)
        elif is_cabin:
            # Captain's Cabin / Chartroom: warm dark mahogany decking (6px planks, subtle wine warmth)
            ph = 6
            pr = ys // ph
            py = ys % ph
            butt_off = (pr * 19) % 40
            px_b = (xs + butt_off) % 40
            plank_h = hash01_grid((xs + butt_off) // 40, pr, s.seed + 97)
            field = np.clip(nb * 0.48 + plank_h * 0.24 + warm * 0.16, 0.0, 0.78)
            out = ramp_blend(("dusk", "plum", "wine"), field, bg)
            is_hseam = (py == 0) & (bg < 0.52)
            is_vseam = (px_b == 0) & (py > 0) & (bg < 0.44)
            out = np.where(is_hseam | is_vseam, IX["night"], out)
            # Quiet polished mahogany highlight & rare tiny brass floor stud
            out = np.where((py == 1) & (plank_h > 0.82) & (bg < 0.28), IX["wine"], out)
            stud = (px_b == 20) & (py == 3) & (plank_h > 0.93)
            out = np.where(stud, IX["apricot"], out)
        else:
            # Upper Weather / Gun / Keel / Prow Deck: salt-weathered wide timber + subtle deck ribs
            ph = 8
            pr = ys // ph
            py = ys % ph
            butt_off = (pr * 15) % 32
            px_b = (xs + butt_off) % 32
            plank_h = hash01_grid((xs + butt_off) // 32, pr, s.seed + 109)
            field = np.clip(nb * 0.52 + plank_h * 0.26 + warm * 0.10, 0.0, 0.84)
            out = ramp_blend(("dusk", "plum", "mauve"), field, bg)
            is_hseam = (py == 0) & (bg < 0.50)
            is_vseam = (px_b == 0) & (py > 0) & (bg < 0.40)
            out = np.where(is_hseam | is_vseam, IX["night"], out)
            # Subtle transverse ship deck-rib timber line every 48px
            rib = (xs % 48 == 0) & (bg < 0.48)
            out = np.where(rib, IX["night"], out)
            # Quiet weathered edge sheen & sparse salt mist
            out = np.where((py == 1) & (plank_h > 0.80) & (bg < 0.30), IX["mauve"], out)
            salt = (nb > 0.82) & (nf > 0.92) & (bg < 0.32) & (py > 0)
            out = np.where(salt, IX["stone"], out)

        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly = ctx["lx"], ctx["ly"]
        ts = ctx["ts"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]

        edge_n = (~ctx["n_up_path"]) & (ly == 0)
        edge_s = (~ctx["n_dn_path"]) & (ly == ts - 1)
        edge_w = (~ctx["n_lt_path"]) & (lx == 0)
        edge_e = (~ctx["n_rt_path"]) & (lx == ts - 1)
        is_edge = edge_n | edge_s | edge_w | edge_e

        main = IX[s.path_main]
        hi = IX[s.path_hi]
        edge = IX[s.path_edge]
        dk = SHADE_IX[main]

        # Calm oak deck runner with wide 8px cross-planks and quiet bevels
        out = np.full(buf.shape, main, dtype=np.uint8)
        out = np.where((nb > 0.58) & (bg < 0.36), hi, out)
        out = np.where((ly % 8 == 0) & (bg < 0.55), dk, out)
        out = np.where(is_edge & (bg < 0.72), edge, out)
        buf[mask] = out[mask]


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
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="wine",
            floor_accent_b="pine",
            path_style="boardwalk",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="wine",
            wall_style="ship_hull",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="mauve",
            wall_face="dusk",
            wall_face_hi="plum",
            wall_base="void",
            water_style="canal_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="mauve",
            rim_mid="plum",
            bridge_style="timber",
            bridge_main="wine",
            bridge_hi="coral",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=211,
            prop_sheet="theme_galleon",
            door_sheet="theme_galleon_doors",
            special_tiles=("H:grate", "T:tide"),
            default_decor=("grate", "stain", "compass"),
            notes="Listing shipwreck: calm low-contrast oak hold, weathered deck, and dark mahogany cabin planks, oak ribs, brass portholes, sloshing bilge water.",
        ),
        GalleonPainter,
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
