"""Islands 3 & 4 themes:
- hollow_oak (Thornwood Hollow flagship dungeon: warm living bark, sap light, root curves, shelf fungus)
- conservatory (Mirefen Gardens flagship dungeon: wet stained-glass glasshouse, sunlit limestone r15-r18, painted silhouettes)
- rain_mausoleum (wet mauve-slate flagstones vs deep rain canals, carved niches, darker sculpted walls)
- canopy_sprint (Island 3 canopy sprint trial: painted twilight boughs over forest depths, mossy oak-branch landings)
- wing_spire (Island 4 wing spire trial: varied architectural platforms over misty skylight chasm)
- mirefen_cave (Island 4 caves incl. cave_heron_roost: luminous wet limestone, curved cavern overhangs, distinct basins)
- thornwood_cave (Island 3 caves: warm root-burrow stone, curved root chasms, amber sap glow)
- thornwood_overworld, under_root, loom, briar_court (Island 3 bespoke painters)
- mirefen_overworld, hourglass_maze, garden_party (Island 4 bespoke painters).
"""
from __future__ import annotations

from typing import Any

import numpy as np

from .base import ThemePainter, ThemeSpec
from .kit import (
    COOL_IX,
    IX,
    LIGHT_IX,
    SHADE_IX,
    WALKABLE_TYPES,
    chamfer_dist,
    expand_neighbor_mask,
    fbm_grid,
    hash01_grid,
    ramp_blend,
    vnoise_grid,
)


def _wall_corner_overhang_mask(ctx: dict[str, Any], seed: int, reach: float = 7.0) -> np.ndarray:
    """Organic irregular wall silhouette creeping slightly into wall/floor borders to break flat rectangles."""
    H, W = ctx["H"], ctx["W"]
    m_wall = ctx["m_wall"]
    # Distance from wall mass into non-wall tiles
    dist_from_wall = chamfer_dist(~m_wall)
    noise = fbm_grid(H, W, 22.0, seed=seed, octaves=2)
    # Deeper reach at concave wall corners (where two orthogonal neighbors are walls)
    n_adj = (
        ctx["n_up_wall"].astype(np.int32)
        + ctx["n_dn_wall"].astype(np.int32)
        + ctx["n_lt_wall"].astype(np.int32)
        + ctx["n_rt_wall"].astype(np.int32)
    )
    corner_bonus = np.where(n_adj >= 2, reach * 0.65, 0.0)
    thresh = (noise - 0.36) * reach + corner_bonus
    return (~m_wall) & (dist_from_wall > 0.0) & (dist_from_wall <= thresh)


def _paint_hollow_oak_pit_roots(buf: np.ndarray, ctx: dict[str, Any], seed: int) -> None:
    """Paint deep inner-trunk ribs and hanging roots across pit/void so chasms read as hollow tree depths."""
    abyss = ctx["m_pit"] | ctx["m_void"] | ctx["m_phantom"]
    if not np.any(abyss):
        return
    H, W = ctx["H"], ctx["W"]
    xs, ys = ctx["xs"], ctx["ys"]
    ly = ctx["ly"]
    bg = ctx["bg"]
    nb = fbm_grid(H, W, 32.0, seed=seed + 501, octaves=2, sx=0.7, sy=1.3)

    # Curving dim trunk-wall ribs receding into the hollow abyss
    rib_wave = np.sin(xs.astype(np.float32) * 0.14 + nb * 5.0)
    deep_rib = abyss & (rib_wave > 0.72) & (bg < 0.48)
    buf[deep_rib] = IX["night"]
    rib_hi = abyss & (rib_wave > 0.88) & (nb > 0.56) & (bg < 0.32)
    buf[rib_hi] = IX["dusk"]

    # Hanging roots draping down from north land edges into pits/voids
    dist_n = chamfer_dist(~ctx["n_up_land"])
    # Compute distance below any land tile into abyss
    land = ctx["m_walk"] | ctx["m_wall"]
    abyss_d = chamfer_dist(~land)
    vine_n = fbm_grid(H, W, 14.0, seed=seed + 517, octaves=2, sx=1.8, sy=0.5)
    hang = abyss & (abyss_d <= 12.0) & (vine_n > 0.56 + abyss_d * 0.025)
    # Only hang downward (prefer pixels where a land tile is above within 16px)
    up_has_land = np.zeros_like(land)
    for dy in range(1, 14):
        up_has_land[dy:, :] |= land[:-dy, :]
    hang = hang & up_has_land
    buf[hang] = np.where((xs % 3 == 0), IX["pine"], IX["dusk"])[hang]
    buf[hang & (vine_n > 0.72)] = IX["teal"]

    # Subtle glowing golden sap-spores drifting in hollow trunk depths
    spore = abyss & (~hang) & (hash01_grid(xs, ys, seed + 529) > 0.9972)
    buf[spore] = IX["gold"]

    # Preserve crisp drop-wall face directly beneath north land
    drop_n = abyss & ctx["n_up_land"] & (ly < 5)
    buf[drop_n & (ly == 0)] = IX["plum"]
    buf[drop_n & (ly > 0) & (ly < 4)] = np.where(((xs + (ly // 2) * 4) % 7 == 0), IX["void"], IX["dusk"])[
        drop_n & (ly > 0) & (ly < 4)
    ]
    buf[drop_n & (ly == 4)] = IX["void"]


class HollowOakPainter(ThemePainter):
    """Hollow Oak (r1..r10 + r2b..r9c): warm living bark, sap light, root curves, shelf fungus."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nm = ctx["n_med"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Warm heartwood concentric growth rings + flowing living-root grain
        cx, cy = W * 0.44, H * 0.52
        rad = np.hypot((xs - cx) * 0.82, (ys - cy) * 1.18)
        ring_f = 0.5 + 0.5 * np.sin(rad * 0.20 + nb * 7.5)
        field = np.clip(nb * 0.48 + ring_f * 0.34 + nm * 0.10 + warm * 0.12, 0.0, 0.999)
        # Warm living heartwood ramp: dusk(55) -> plum(80) -> wine(101) -> mauve(122)
        out = ramp_blend(("dusk", "plum", "plum", "wine"), field, bg)

        # Gentle curved heartwood grain grooves (low-contrast, calm floor)
        groove = (ring_f < 0.08) & (bg < 0.55)
        out = np.where(groove, IX["night"], out)

        # Subtle warm sunlit wood-grain catchlight on ring crests
        crest = (ring_f > 0.91) & (nb > 0.50) & (bg < 0.42)
        out = np.where(crest, IX["mauve"], out)

        # Glowing amber sap-veins threading gently through select heartwood curves
        sap_n = fbm_grid(H, W, 30.0, seed=s.seed + 71, octaves=2, sx=0.75, sy=1.25)
        sap_vein = (np.abs(sap_n - 0.50) < 0.014) & (nb > 0.42)
        out = np.where(sap_vein & (bg < 0.65), IX["coral"], out)
        out = np.where(sap_vein & (nb > 0.62) & (bg < 0.38), IX["apricot"], out)
        # Rare tiny amber sap-bead gleams along veins
        out = np.where(sap_vein & (nf > 0.96), IX["gold"], out)

        # Subtle damp moss creeping within a few pixels of water or walls
        near_w = ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
        out = np.where(near_w & (nb < 0.46) & (bg < 0.48), IX["teal"], out)
        out = np.where((nf < 0.008) & (nb > 0.62), IX["jade"], out)

        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]

        edge_n = (~ctx["n_up_path"]) & (ly == 0)
        edge_s = (~ctx["n_dn_path"]) & (ly == ts - 1)
        edge_w = (~ctx["n_lt_path"]) & (lx == 0)
        edge_e = (~ctx["n_rt_path"]) & (lx == ts - 1)
        is_edge = edge_n | edge_s | edge_w | edge_e

        # Warm heartwood boardwalk / woven-bark walkway (calm, cohesive with living bark)
        out = ramp_blend(("dusk", "plum", "wine"), np.clip(nb * 0.50 + 0.36, 0.0, 0.999), bg)
        # Wide calm 8px bark-plank seams
        out = np.where((ly % 8 == 0) & (bg < 0.58), IX["night"], out)
        out = np.where((ly % 8 == 1) & (nb > 0.55) & (bg < 0.34), IX["mauve"], out)
        # Warm amber sap-studs near walkway edges
        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )
        out = np.where(in_edge & (((xs + ys) % 6) == 0), IX["apricot"], out)
        out = np.where(is_edge & (bg < 0.78), IX["night"], out)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Deep gnarled living-bark cap (clearly darker than walkable floor: void/night/dusk)
        bark_n = fbm_grid(H, W, 18.0, seed=s.seed + 201, octaves=2, sx=1.5, sy=0.55)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_lift = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.35
        out = ramp_blend(("void", "night", "dusk"), np.clip(bark_n * 0.72 + edge_lift, 0.0, 0.999), bg)
        # Organic mossy cap patches along living bark rim
        moss_cap = (wall_d < 8.0) & (nb > 0.56) & (bg < 0.62)
        out = np.where(moss_cap, IX["pine"], out)
        out = np.where((wall_d < 4.0) & (nb > 0.66) & (bg < 0.50), IX["teal"], out)

        # Deep furrowed 7px south-facing bark wall
        south = dn_open & (ly >= ts - 7)
        lip_y = ts - 7 + np.where(bark_n > 0.54, 0, 1)
        out = np.where(south & (ly == lip_y), np.where(nb > 0.52, IX["jade"], IX["plum"]), out)
        furrow = (xs + (bark_n * 6.0).astype(np.int32)) % 8
        face_c = np.where(
            furrow == 0,
            IX["void"],
            np.where(furrow == 1, IX["night"], np.where((furrow == 3) & (ly < ts - 2), IX["wine"], IX["dusk"])),
        )
        out = np.where(south & (ly > lip_y) & (ly < ts - 1), face_c, out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        # Warm sunlit WNW bark rim & dark east shadow
        out = np.where(up_open & (ly == 0), np.where(nb > 0.55, IX["teal"], IX["plum"]), out)
        west_rim = lt_open & (lx == 0) & (~(dn_open & (ly >= ts - 5)))
        out = np.where(west_rim & (bg < 0.55 + 0.35 * warm), IX["plum"], out)
        east_rim = rt_open & (lx == ts - 1) & (~(dn_open & (ly >= ts - 5)))
        out = np.where(east_rim, IX["void"], out)

        buf[mask] = out[mask]

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        H, W, ts = ctx["H"], ctx["W"], ctx["ts"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly = ctx["lx"], ctx["ly"]
        bg = ctx["bg"]
        m_wall = ctx["m_wall"]
        dn_open = ~ctx["n_dn_wall"]
        s = self.spec

        # 1. Hollow-trunk pit/void ribs & hanging roots
        _paint_hollow_oak_pit_roots(buf, ctx, s.seed)

        # 2. Organic root-curves & mossy bark buttresses overlapping straight wall edges
        over = _wall_corner_overhang_mask(ctx, s.seed + 601, reach=6.5) & (ctx["m_walk"] | ctx["m_water"])
        if np.any(over):
            # Buttress root body with lit WNW bark edge
            root_n = vnoise_grid(H, W, 10.0, seed=s.seed + 607)
            dist_w = chamfer_dist(~m_wall)
            r_col = np.where(
                dist_w <= 2.0,
                IX["night"],
                np.where(root_n > 0.58, IX["plum"], np.where(root_n > 0.34, IX["dusk"], IX["pine"])),
            )
            buf[over] = r_col[over]
            # Soft cast shadow 1px beyond buttress root
            sh_ring = (~m_wall) & (~over) & ctx["m_walk"] & (dist_w <= 7.5) & (root_n > 0.52) & (bg < 0.35)
            buf[sh_ring] = SHADE_IX[buf[sh_ring]]

        # 3. Terraced glowing shelf-fungus brackets clinging to interior south-facing bark walls (skip map bottom row)
        interior_south = m_wall & dn_open & (ctx["ty"] < ctx["h_t"] - 1)
        bx_id = xs // 24
        by_id = ys // ts
        bh = hash01_grid(bx_id, by_id, s.seed + 631)
        fx = (xs % 24) - 12
        fy = ly - (ts - 4)
        # Organic half-oval shelf fungus cap (width ~9px, height ~3px) on selected wall segments
        has_fungus = interior_south & (bh > 0.56)
        cap = has_fungus & ((fx * fx) / 20.0 + (fy * fy) / 4.5 <= 1.0) & (fy <= 1)
        cap_top = cap & (fy <= -1)
        cap_mid = cap & (fy == 0)
        cap_bot = cap & (fy == 1)
        buf[cap_top] = IX["gold"]
        buf[cap_mid] = IX["apricot"]
        buf[cap_bot] = IX["coral"]
        # Shadow directly underneath bracket
        under_f = has_fungus & (ly == ts - 2) & (np.abs(fx) <= 4)
        buf[under_f] = IX["void"]

        # 4. Warm sap-light hollows nestled in interior bark faces (opposite segments from shelf fungus)
        sap_seg = interior_south & (bh < 0.24) & (np.abs(fx) <= 2) & (ly >= ts - 5) & (ly <= ts - 2)
        buf[sap_seg] = IX["coral"]
        sap_core = interior_south & (bh < 0.24) & (np.abs(fx) <= 1) & (ly >= ts - 4) & (ly <= ts - 3)
        buf[sap_core] = IX["gold"]

        # 5. Subtle mossy root coping overhanging water basins (softens square pools like oak_r4b!)
        m_water = ctx["m_water"]
        if np.any(m_water):
            w_dist = chamfer_dist(m_water)
            wn = fbm_grid(H, W, 16.0, seed=s.seed + 653, octaves=2)
            # Curving corner root bank creeping 1-4px over rectangular water edges
            n_w_land = (
                ctx["n_up_land"].astype(np.int32)
                + ctx["n_dn_land"].astype(np.int32)
                + ctx["n_lt_land"].astype(np.int32)
                + ctx["n_rt_land"].astype(np.int32)
            )
            corner_bank = m_water & (n_w_land >= 2) & (w_dist <= 3.5 + wn * 3.0)
            buf[corner_bank] = np.where(w_dist <= 2.0, IX["dusk"], IX["pine"])[corner_bank]
            # Gentle golden sap-drop ripples in forest water
            sap_glint = m_water & (~corner_bank) & (wn > 0.72) & (hash01_grid(xs, ys, s.seed + 661) > 0.988)
            buf[sap_glint] = IX["apricot"]


class ConservatoryPainter(ThemePainter):
    """Mirefen Glass Conservatory (r1..r18):
    - r1..r14: wet stained-glass glasshouse flagstones (luminous mauve/dusk/stone vs sapphire basins)
    - r15..r18: warm sunlit conservatory limestone (replaces orange desert sand)
    - ALL 18/18 rooms: painted wall silhouettes (rafters, arched iron ribs, stained & broken panes,
      climbing vines, projecting pilasters overlapping the straight rectangle edges).
    """

    def _is_sunlit_wing(self, ctx: dict[str, Any]) -> bool:
        rid = str(ctx.get("meta", {}).get("id", "")).lower()
        return rid in ("conservatory_r15", "conservatory_r16", "conservatory_r17", "conservatory_r18")

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec
        sunlit = self._is_sunlit_wing(ctx)

        # 16x10 dressed glasshouse limestone flagstones
        sh, sw = 10, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 61)

        if sunlit:
            # Warm sunlit conservatory limestone (calm ~94-104 luma, NOT blinding orange desert sand!)
            slab_f = np.clip(nb * 0.44 + slab_h * 0.34 + warm * 0.12, 0.0, 0.999)
            out = ramp_blend(("dusk", "dusk", "plum", "mauve"), slab_f, bg)
            is_seam = (sx == 0) | (sy == 0)
            is_bev = (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.60) & (bg < 0.28)
            out = np.where(is_bev, IX["stone"], out)
            out = np.where(is_seam & (bg < 0.72), IX["night"], out)
            # Soft warm sunlit conservatory glass rays drifting diagonally across limestone
            ray = (xs - ys * 0.55) % 68.0
            in_ray = (ray >= 12.0) & (ray <= 25.0) & (nb > 0.42)
            out = np.where(in_ray & (~is_seam) & (bg < 0.28), IX["stone"], out)
            out = np.where(in_ray & (~is_seam) & (nb > 0.62) & (bg < 0.16), IX["apricot"], out)
            # Occasional delicate rose stained-glass floor reflection
            pane_tint = (xs - ys * 0.55) % 96.0
            out = np.where((pane_tint >= 52.0) & (pane_tint <= 64.0) & (~is_seam) & (bg < 0.16), IX["rose"], out)
        else:
            # Wet stained-glass glasshouse flagstones (target walk_lum ~76-84)
            slab_f = np.clip(nb * 0.48 + slab_h * 0.36 + warm * 0.10, 0.0, 0.999)
            out = ramp_blend(("dusk", "dusk", "plum", "mauve"), slab_f, bg)
            is_seam = (sx == 0) | (sy == 0)
            is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & ((slab_h > 0.52) | (bg < 0.24))
            out = np.where(is_bev, IX["stone"], out)
            out = np.where(is_seam & (bg < 0.78), IX["night"], out)
            # Subtle wet conservatory skylight reflections (diagonal stained-glass pools!)
            diag = (xs - ys * 0.6) % 72.0
            pool_a = (diag >= 10.0) & (diag <= 22.0) & (nb > 0.48) & (~is_seam)
            pool_b = (diag >= 42.0) & (diag <= 52.0) & (nb > 0.52) & (~is_seam)
            out = np.where(pool_a & (bg < 0.24), IX["sky"], out)
            out = np.where(pool_b & (bg < 0.20), IX["rose"], out)
            # Wet moss tucked softly into seams near water
            near_w = ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
            out = np.where(near_w & is_seam & (bg < 0.65), IX["teal"], out)
            out = np.where(near_w & (nf < 0.04), IX["jade"], out)

        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        sunlit = self._is_sunlit_wing(ctx)

        edge_n = (~ctx["n_up_path"]) & (ly == 0)
        edge_s = (~ctx["n_dn_path"]) & (ly == ts - 1)
        edge_w = (~ctx["n_lt_path"]) & (lx == 0)
        edge_e = (~ctx["n_rt_path"]) & (lx == ts - 1)
        is_edge = edge_n | edge_s | edge_w | edge_e

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )

        main = IX["mauve"] if sunlit else IX["plum"]
        hi = IX["stone"] if sunlit else IX["mauve"]
        edge_c = IX["dusk"]
        trim_c = IX["gold"] if sunlit else IX["apricot"]

        out = np.full(buf.shape, main, dtype=np.uint8)
        out = np.where((nb > 0.54) & (bg < 0.42), hi, out)
        seam = (ly % 8 == 0) | (((lx + np.where(((ly // 8) & 1) == 1, 8, 0)) % 16) == 0)
        out = np.where(seam & (bg < 0.68), SHADE_IX[main], out)
        out = np.where(in_edge & (((xs + ys) % 4) != 0), trim_c, out)
        out = np.where(is_edge, edge_c, out)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Deep wrought-iron & damp glasshouse masonry wall cap (target wall avg ~40-48 for crisp pop!)
        out = ramp_blend(("void", "void", "night", "pine"), np.clip(nb * 0.58 + 0.08, 0.0, 0.999), bg)
        # Iron conservatory roof-frame glazing mullions on wall cap (24x16 skylight bays)
        rib_x = xs % 24
        rib_y = ys % 16
        in_pane = (rib_x >= 3) & (rib_x <= 20) & (rib_y >= 2) & (rib_y <= 12)
        pane_h = hash01_grid(xs // 24, ys // 16, s.seed + 241)
        # Most roof panes show dim twilight glass; ~28% are broken panes (deep void with shard glint)
        broken = pane_h < 0.28
        glass_c = np.where(
            broken,
            IX["void"],
            np.where(pane_h > 0.80, IX["pine"], np.where(pane_h > 0.52, IX["deep"], IX["night"])),
        )
        out = np.where(in_pane, glass_c, out)
        # Subtle twilight diagonal glass catchlight on intact cap panes
        gleam = in_pane & (~broken) & (((rib_x + rib_y) % 11) == 0) & (bg < 0.36)
        out = np.where(gleam, IX["blue"], out)
        # Jagged glass shard highlight on broken pane rim
        shard = in_pane & broken & ((rib_x == 4) | (rib_y == 3)) & (((xs + ys) % 6) == 0)
        out = np.where(shard, IX["sky"], out)
        # Dark wrought-iron roof mullions & crossbars
        mullion = (rib_x == 0) | (rib_x == 1) | (rib_x == 23) | (rib_y == 0) | (rib_y == 1)
        out = np.where(mullion, IX["void"], out)
        out = np.where((rib_x == 2) & (rib_y > 1) & (bg < 0.55), IX["night"], out)

        # South-facing glasshouse wall with arched stained-glass lancets & broken panes (interior walls only)
        south = dn_open & (ly >= ts - 7) & (ctx["ty"] < ctx["h_t"] - 1)
        out = np.where(south & (ly == ts - 7), IX["mauve"], out)  # refined twilight cornice
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1), IX["night"], out)
        # Subtle iron pilaster vertical seam between lancets
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1) & ((rib_x == 1) | (rib_x == 2)), IX["dusk"], out)
        # Stained-glass lancet windows every 24px (width 8px: rib_x 8..15)
        win_h = hash01_grid(xs // 24, ys // ts, s.seed + 263)
        win_broken = win_h < 0.26
        in_arch = (
            south
            & (ly >= ts - 6)
            & (ly <= ts - 2)
            & (rib_x >= 8)
            & (rib_x <= 15)
            & ~((ly == ts - 6) & ((rib_x == 8) | (rib_x == 15)))
        )
        # Jewel-toned stained glass per lancet (muted twilight depth with bright center glint)
        st_col = np.where(
            win_broken,
            IX["void"],
            np.where(
                win_h < 0.44,
                IX["blue"],
                np.where(win_h < 0.64, IX["wine"], np.where(win_h < 0.82, IX["apricot"], IX["teal"])),
            ),
        )
        st_hi = np.where(
            win_h < 0.44,
            IX["sky"],
            np.where(win_h < 0.64, IX["rose"], np.where(win_h < 0.82, IX["gold"], IX["jade"])),
        )
        out = np.where(in_arch, st_col, out)
        out = np.where(in_arch & (~win_broken) & (ly == ts - 4) & ((rib_x == 10) | (rib_x == 13)), st_hi, out)
        # Lead muntin bar splitting each lancet vertically
        out = np.where(in_arch & (rib_x == 12), IX["void"], out)
        # Jagged shard highlight inside broken lancets
        out = np.where(in_arch & win_broken & (ly == ts - 5) & ((rib_x == 9) | (rib_x == 14)), IX["sky"], out)
        # Lower stone plinth
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        # Crisp WNW sunlit edge highlight on wall caps (calm twilight blue/mauve, not blinding sky)
        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), IX["blue"], out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(west_rim & (bg < 0.48 + 0.30 * warm), IX["dusk"], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(east_rim, IX["void"], out)

        buf[mask] = out[mask]

    def paint_void(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        self._paint_conservatory_chasm(buf, ctx, ctx["m_void"])

    def paint_pit(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        self._paint_conservatory_chasm(buf, ctx, ctx["m_pit"])

    def _paint_conservatory_chasm(self, buf: np.ndarray, ctx: dict[str, Any], mask: np.ndarray) -> None:
        """Broken skylight chasm: twilight mist + wrought-iron glasshouse rafters & arched dome ribs."""
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        ly = ctx["ly"]
        bg = ctx["bg"]
        s = self.spec

        # Deep twilight sky with soft mist wisps
        mist = fbm_grid(H, W, 44.0, seed=s.seed + 411, octaves=2, sx=0.8, sy=1.2)
        out = np.where((mist > 0.62) & (bg < 0.45), IX["deep"], np.where((mist > 0.46) & (bg < 0.50), IX["night"], IX["void"]))

        # Diagonal wrought-iron conservatory rafters & skylight truss grid receding in the chasm
        rafter_a = np.abs(((xs + ys) % 44) - 22) <= 1
        rafter_b = np.abs(((xs - ys) % 44) - 22) <= 1
        cross_rib = (ys % 32 == 16)
        truss = rafter_a | rafter_b | cross_rib
        out = np.where(truss & (bg < 0.78), IX["night"], out)
        # Clearer wrought-iron skylight rib catchlights tying floating islands together
        joint = rafter_a & rafter_b
        out = np.where(joint, IX["mauve"], out)
        out = np.where((rafter_a | rafter_b) & (bg < 0.35), IX["dusk"], out)
        out = np.where(cross_rib & (bg < 0.45), IX["deep"], out)

        # Tiny twilight stars / drifting conservatory pollen
        st = hash01_grid(xs, ys, s.seed + 433)
        out = np.where(st > 0.9965, IX["sky"], np.where(st > 0.994, IX["gold"], out))

        # Crisp 5px recessed conservatory stone ledge along north edge
        drop_n = ctx["n_up_land"] & (ly < 5)
        out = np.where(drop_n & (ly == 0), IX["mauve"], out)
        out = np.where(drop_n & (ly > 0) & (ly < 4), np.where(((xs + (ly // 2) * 4) % 8 == 0), IX["void"], IX["dusk"]), out)
        out = np.where(drop_n & (ly == 4), IX["void"], out)

        buf[mask] = out[mask]

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        """Break ALL 18/18 flat rectangular boxes with painted pilasters, iron rafters, and climbing vines!"""
        H, W, ts = ctx["H"], ctx["W"], ctx["ts"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly = ctx["lx"], ctx["ly"]
        bg = ctx["bg"]
        m_wall = ctx["m_wall"]
        m_walk = ctx["m_walk"]
        s = self.spec

        # 1. Projecting stone-and-iron pilasters every 48px overlapping north, west, and east wall edges
        #    (steps 4-5px off the straight tile boundary onto the wall-floor border!)
        n_pil = m_walk & ctx["n_up_wall"] & (ly < 5) & ((xs % 48 >= 20) & (xs % 48 <= 27))
        n_pil_hi = n_pil & ((xs % 48 == 20) | (ly == 0))
        n_pil_dk = n_pil & ((xs % 48 == 27) | (ly == 4))
        buf[n_pil] = IX["dusk"]
        buf[n_pil_hi] = IX["mauve"]
        buf[n_pil_dk] = IX["night"]
        # Shadow cast below each pilaster
        n_pil_sh = m_walk & ctx["n_up_wall"] & (ly >= 5) & (ly <= 7) & ((xs % 48 >= 21) & (xs % 48 <= 28)) & (bg < 0.55)
        buf[n_pil_sh] = SHADE_IX[buf[n_pil_sh]]

        # West & East wall projecting pilasters (every 48px vertically)
        w_pil = m_walk & ctx["n_lt_wall"] & (lx < 4) & ((ys % 48 >= 20) & (ys % 48 <= 27))
        buf[w_pil] = np.where(ly % 48 == 20, IX["stone"], np.where(lx == 3, IX["night"], IX["dusk"]))[w_pil]
        e_pil = m_walk & ctx["n_rt_wall"] & (lx >= ts - 4) & ((ys % 48 >= 20) & (ys % 48 <= 27))
        buf[e_pil] = np.where(lx == ts - 4, IX["mauve"], np.where(ys % 48 == 27, IX["night"], IX["dusk"]))[e_pil]

        # 2. Curved iron conservatory corner-ribs / arched vault brackets overlapping inner room corners
        dist_w = chamfer_dist(~m_wall)
        n_adj = (
            ctx["n_up_wall"].astype(np.int32)
            + ctx["n_dn_wall"].astype(np.int32)
            + ctx["n_lt_wall"].astype(np.int32)
            + ctx["n_rt_wall"].astype(np.int32)
        )
        # Concave corner iron arch gusset (breaks square corners into vaulted conservatory bays!)
        corner_rib = (~m_wall) & (n_adj >= 2) & (dist_w > 0.0) & (dist_w <= 6.2)
        buf[corner_rib] = np.where(dist_w <= 2.2, IX["night"], np.where(dist_w <= 4.2, IX["dusk"], IX["mauve"]))[corner_rib]
        # Rivet highlight on corner arch
        buf[corner_rib & (dist_w > 4.2) & (dist_w <= 5.2)] = IX["stone"]

        # 3. Climbing glasshouse vines draping unevenly over wall lips & pilasters (organic silhouette!)
        vine_n = fbm_grid(H, W, 16.0, seed=s.seed + 701, octaves=2)
        vine_over = _wall_corner_overhang_mask(ctx, s.seed + 719, reach=7.5) & (m_walk | ctx["m_water"])
        # Also let vines trail down onto south wall faces & just past the wall lip
        wall_vine = (
            (m_wall & (~ctx["n_dn_wall"]) & (ly >= ts - 7) & (vine_n > 0.59))
            | (vine_over & (vine_n > 0.44))
        )
        if np.any(wall_vine):
            leaf_c = np.where(vine_n > 0.72, IX["lime"], np.where(vine_n > 0.60, IX["jade"], np.where(vine_n > 0.50, IX["teal"], IX["pine"])))
            buf[wall_vine] = leaf_c[wall_vine]
            # Tiny conservatory rosebuds tucked in lush vines
            bud = wall_vine & (hash01_grid(xs, ys, s.seed + 733) > 0.965)
            buf[bud] = IX["rose"]

        # 4. Subtle overhead iron skylight rafter shadow bands across rooms (adds glasshouse depth!)
        rafter_sh = m_walk & (np.abs(((xs - ys * 0.5) % 80.0) - 40.0) < 1.2) & (bg < 0.28)
        buf[rafter_sh] = SHADE_IX[buf[rafter_sh]]

        # 5. Subtle warm conservatory lantern sconce light aprons beneath north pilasters
        _paint_sconce_aprons_3_4(buf, ctx, spacing=48, phase=24, radius=11.0, strength=0.38, draw_fixture=True)


class RainMausoleumPainter(ThemePainter):
    """Rain Mausoleum: readable wet mauve-slate flagstones vs vivid blue canals,
    clearly darker crypt walls with carved arched niches, projecting pilasters, and rain streaks.
    """

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]
        s = self.spec

        # Running-bond 16x10 wet cool-mauve mausoleum flagstones (mean luma ~78, distinct from blue canals!)
        sh, sw = 10, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 59)

        slab_f = np.clip(nb * 0.48 + slab_h * 0.36 + warm * 0.08, 0.0, 0.999)
        out = ramp_blend(("dusk", "dusk", "plum", "mauve"), slab_f, bg)
        is_seam = (sx == 0) | (sy == 0)
        is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & ((slab_h > 0.50) | (bg < 0.24))
        out = np.where(is_bev, IX["stone"], out)
        out = np.where(is_seam & (bg < 0.78), IX["night"], out)

        # Subtle wet rain-sheen catchlights on damp flagstones
        sheen = (((xs + ys * 2) % 29) < 2) & (nb > 0.62) & (bg < 0.35) & (~is_seam)
        out = np.where(sheen, IX["sky"], out)

        # Recessed bronze storm-drain gutter strip every 64px
        gutter = (xs % 64 == 31) | (xs % 64 == 32)
        out = np.where(gutter & (ys % 4 != 0), IX["dusk"], out)
        out = np.where(gutter & (ys % 4 == 2), IX["apricot"], out)
        out = np.where(gutter & (ys % 4 == 0), IX["night"], out)

        # Crisp stone canal coping edge where flagstones meet rain canals!
        near_w = (
            (ctx["n_up_water"] & (ctx["ly"] < 2))
            | (ctx["n_dn_water"] & (ctx["ly"] >= ctx["ts"] - 2))
            | (ctx["n_lt_water"] & (ctx["lx"] < 2))
            | (ctx["n_rt_water"] & (ctx["lx"] >= ctx["ts"] - 2))
        )
        out = np.where(near_w, IX["stone"], out)
        out = np.where(near_w & (((xs + ys) % 6) == 0), IX["dusk"], out)

        buf[mask] = out[mask]

    def paint_pit(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        super().paint_pit(buf, ctx)
        mask = ctx["m_pit"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        # Dim sunken crypt vault arches receding into the dark rain chasm
        arch = mask & ((xs % 32 == 15) | (xs % 32 == 16)) & (ys % 2 == 0) & (bg < 0.55)
        buf[arch] = IX["night"]
        rib = mask & (ys % 24 == 12) & (bg < 0.40)
        buf[rib] = IX["deep"]

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        m_walk = ctx["m_walk"]
        dn_open = ~ctx["n_dn_wall"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        s = self.spec

        # 1. Carved arched mausoleum niches every 32px along interior south-facing crypt walls
        interior_south = m_wall & dn_open & (ctx["ty"] < ctx["h_t"] - 1)
        ax = xs % 32
        niche_zone = interior_south & (ly >= ts - 6) & (ly <= ts - 2)
        in_niche = niche_zone & (ax >= 12) & (ax <= 19) & ~((ly == ts - 6) & ((ax == 12) | (ax == 19)))
        # Carved arch frame outline
        niche_rim = (
            niche_zone
            & (
                ((ax == 11) | (ax == 20)) & (ly >= ts - 5)
                | ((ly == ts - 6) & (ax >= 13) & (ax <= 18))
            )
        )
        buf[niche_rim] = IX["mauve"]
        buf[in_niche] = IX["void"]
        # Carved pale stone memorial urn / weeping bust silhouette inside each niche
        urn_body = in_niche & (ly >= ts - 4) & (ly <= ts - 2) & ((ax == 15) | (ax == 16))
        urn_lip = in_niche & (ly == ts - 4) & ((ax == 14) | (ax == 17))
        buf[urn_body] = IX["stone"]
        buf[urn_lip] = IX["mauve"]

        # 2. Vertical rain-streak gloss lines running down south stone faces (between niches)
        streak = interior_south & (~in_niche) & (ly >= ts - 5) & (ly < ts - 1) & ((xs % 11) == 3)
        buf[streak] = IX["sky"]

        # 3. Projecting carved stone pilasters & chamfered corner buttresses breaking 12/12 flat boxes
        n_pil = m_walk & ctx["n_up_wall"] & (ly < 4) & ((xs % 32 >= 0) & (xs % 32 <= 5))
        buf[n_pil] = np.where(ly == 0, IX["sky"], np.where((xs % 32 == 5) | (ly == 3), IX["void"], IX["dusk"]))[n_pil]
        w_pil = m_walk & ctx["n_lt_wall"] & (lx < 4) & ((ys % 40 >= 16) & (ys % 40 <= 22))
        buf[w_pil] = np.where(ys % 40 == 16, IX["sky"], np.where(lx == 3, IX["void"], IX["dusk"]))[w_pil]
        e_pil = m_walk & ctx["n_rt_wall"] & (lx >= ts - 4) & ((ys % 40 >= 16) & (ys % 40 <= 22))
        buf[e_pil] = np.where(lx == ts - 4, IX["mauve"], np.where(ys % 40 == 22, IX["void"], IX["dusk"]))[e_pil]

        # Corner chamfer buttresses
        dist_w = chamfer_dist(~m_wall)
        n_adj = (
            ctx["n_up_wall"].astype(np.int32)
            + ctx["n_dn_wall"].astype(np.int32)
            + ctx["n_lt_wall"].astype(np.int32)
            + ctx["n_rt_wall"].astype(np.int32)
        )
        c_but = m_walk & (n_adj >= 2) & (dist_w > 0.0) & (dist_w <= 5.2)
        buf[c_but] = np.where(dist_w <= 2.2, IX["night"], np.where(dist_w <= 4.0, IX["dusk"], IX["mauve"]))[c_but]

        # Subtle wet moss creeping down select damp crypt corners
        moss_n = fbm_grid(ctx["H"], ctx["W"], 18.0, seed=s.seed + 777, octaves=2)
        c_moss = c_but & (moss_n > 0.62) & (bg < 0.60)
        buf[c_moss] = IX["teal"]


class CanopySprintPainter(ThemePainter):
    """Island 3 trial_canopy_sprint: twilight forest canopy boughs below + warm mossy oak landings."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]
        s = self.spec

        # Warm living oak-branch deck planking (calm ~78 luma, NOT grey stone sewer bricks!)
        ph = 8
        pr = ys // ph
        py = ys % ph
        butt = (xs + pr * 15) % 32
        phash = hash01_grid((xs + pr * 15) // 32, pr, s.seed + 73)
        field = np.clip(nb * 0.45 + phash * 0.32 + warm * 0.12, 0.0, 0.999)
        out = ramp_blend(("dusk", "plum", "plum", "wine"), field, bg)
        out = np.where((py == 0) & (bg < 0.56), IX["night"], out)
        out = np.where((butt == 0) & (py > 0) & (bg < 0.44), IX["night"], out)
        out = np.where((py == 1) & (phash > 0.68) & (bg < 0.32), IX["mauve"], out)

        # Mossy canopy fringe bordering the platform edges over the abyss
        abyss = ctx["m_pit"] | ctx["m_void"] | ctx["m_phantom"]
        d_edge = chamfer_dist(~abyss)
        moss_rim = (d_edge <= 5.5) & (nb > 0.34 + d_edge * 0.06)
        out = np.where(moss_rim, np.where(d_edge <= 2.5, IX["jade"], IX["teal"]), out)
        out = np.where(moss_rim & (d_edge <= 1.8) & (bg < 0.45), IX["lime"], out)
        buf[mask] = out[mask]

    def _paint_canopy_boughs(self, buf: np.ndarray, ctx: dict[str, Any], mask: np.ndarray) -> None:
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        ly = ctx["ly"]
        bg = ctx["bg"]
        s = self.spec

        # Deep twilight forest canopy depths
        can_n = fbm_grid(H, W, 34.0, seed=s.seed + 401, octaves=3)
        leaf_n = vnoise_grid(H, W, 11.0, seed=s.seed + 419)
        out = np.full((H, W), IX["void"], dtype=np.uint8)

        # Layered distant tree-crown foliage clusters in the abyss below
        crown1 = (can_n > 0.46) & (leaf_n > 0.34)
        crown2 = (can_n > 0.58) & (leaf_n > 0.42)
        crown3 = (can_n > 0.68) & (leaf_n > 0.52) & (bg < 0.65)
        out = np.where(crown1, IX["night"], out)
        out = np.where(crown2, IX["pine"], out)
        out = np.where(crown3, IX["teal"], out)
        # Moonlit leaf rim accents on the highest lower-canopy crowns
        out = np.where((can_n > 0.74) & (leaf_n > 0.62) & (bg < 0.45), IX["jade"], out)

        # Sweeping diagonal ancient oak boughs crossing beneath the sprint islands!
        warp = (can_n - 0.5) * 14.0
        bough1 = np.abs((ys - xs * 0.34 + warp) % 68.0 - 34.0) < 4.5
        bough2 = np.abs((ys + xs * 0.28 - warp * 0.8) % 82.0 - 41.0) < 3.5
        bough = bough1 | bough2
        out = np.where(bough, IX["dusk"], out)
        # Lit upper bark edge on boughs (WNW light)
        bough_hi = (
            (np.abs((ys - xs * 0.34 + warp) % 68.0 - 30.5) < 1.3)
            | (np.abs((ys + xs * 0.28 - warp * 0.8) % 82.0 - 38.2) < 1.1)
        )
        out = np.where(bough_hi, IX["plum"], out)
        # Moss clumps perched atop the deep boughs
        out = np.where(bough_hi & (leaf_n > 0.58), IX["teal"], out)

        # Drifting warm canopy fireflies
        ff = hash01_grid(xs, ys, s.seed + 443)
        out = np.where(ff > 0.9968, IX["gold"], np.where(ff > 0.9948, IX["lime"], out))

        # Bark drop-lip directly beneath platform islands
        drop_n = ctx["n_up_land"] & (ly < 5)
        out = np.where(drop_n & (ly == 0), IX["plum"], out)
        out = np.where(drop_n & (ly > 0) & (ly < 4), IX["dusk"], out)
        out = np.where(drop_n & (ly == 4), IX["night"], out)

        buf[mask] = out[mask]

    def paint_void(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        self._paint_canopy_boughs(buf, ctx, ctx["m_void"])

    def paint_pit(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        self._paint_canopy_boughs(buf, ctx, ctx["m_pit"])


class WingSpirePainter(ThemePainter):
    """Island 4 trial_wing_spire: misty dusk skylight void + 4 visually varied architectural platforms."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]
        s = self.spec

        # Partition room into 5 distinct architectural zones (West entry + NW, NE, SW, SE floating pads!)
        mid_x, mid_y = W * 0.52, H * 0.50
        west_entry = xs < W * 0.24
        nw = (~west_entry) & (xs < mid_x) & (ys < mid_y)
        ne = (~west_entry) & (xs >= mid_x) & (ys < mid_y)
        sw = (~west_entry) & (xs < mid_x) & (ys >= mid_y)
        se = (~west_entry) & (xs >= mid_x) & (ys >= mid_y)

        # Base conservatory terrace flagstones (West entry, calm ~80 luma so 4 ornate pads shine!)
        sh, sw_b = 10, 16
        ox = np.where(((ys // sh) & 1) == 1, 8, 0)
        sx, sy = (xs + ox) % sw_b, ys % sh
        slab_h = hash01_grid((xs + ox) // sw_b, ys // sh, s.seed + 51)
        out = ramp_blend(("dusk", "dusk", "plum", "mauve"), np.clip(nb * 0.45 + slab_h * 0.35 + warm * 0.10, 0.0, 0.999), bg)
        out = np.where((sx == 0) | (sy == 0), IX["night"], out)
        out = np.where((sy == 1) & (slab_h > 0.52), IX["stone"], out)

        # NW pad: warm sunlit limestone octagon with brass diamond inlay
        nw_f = ramp_blend(("plum", "mauve", "stone"), np.clip(nb * 0.45 + slab_h * 0.35 + 0.15, 0.0, 0.999), bg)
        nw_f = np.where((xs % 12 == 0) | (ys % 12 == 0), IX["dusk"], nw_f)
        nw_f = np.where(((xs + ys) % 24 == 0) & (bg < 0.55), IX["gold"], nw_f)
        out = np.where(nw, nw_f, out)

        # NE pad: glazed conservatory skylight deck (iron-mullioned blue/sky glass panes!)
        gx, gy = xs % 16, ys % 16
        ne_f = np.where((gx + gy) < 16, IX["sky"], IX["blue"])
        ne_f = np.where(((gx + gy) % 7 == 0) & (bg < 0.60), IX["ice"], ne_f)
        ne_f = np.where((gx == 0) | (gy == 0) | (gx == 15) | (gy == 15), IX["dusk"], ne_f)
        ne_f = np.where((gx == 1) | (gy == 1), IX["stone"], ne_f)
        out = np.where(ne, ne_f, out)

        # SW pad: rose-wine mosaic wind-altar terrace (diagonal diamond tiling)
        u, v = (xs + ys) // 12, (xs - ys) // 12
        chk = ((u + v) & 1) == 0
        sw_f = np.where(chk, IX["mauve"], IX["wine"])
        sw_f = np.where(((xs + ys) % 12 == 0) | ((xs - ys) % 12 == 0), IX["dusk"], sw_f)
        sw_f = np.where(((xs + ys) % 12 == 6) & ((xs - ys) % 12 == 0), IX["gold"], sw_f)
        out = np.where(sw, sw_f, out)

        # SE pad: overgrown mossy balustrade terrace (teal/jade stone + creeping vines + rose petals)
        se_f = ramp_blend(("dusk", "teal", "mauve"), np.clip(nb * 0.55 + slab_h * 0.35, 0.0, 0.999), bg)
        se_f = np.where((sx == 0) | (sy == 0), IX["pine"], se_f)
        se_f = np.where((nb > 0.62) & (bg < 0.55), IX["jade"], se_f)
        se_f = np.where(hash01_grid(xs, ys, s.seed + 89) > 0.985, IX["rose"], se_f)
        out = np.where(se, se_f, out)

        buf[mask] = out[mask]

    def _paint_spire_sky(self, buf: np.ndarray, ctx: dict[str, Any], mask: np.ndarray) -> None:
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        ly = ctx["ly"]
        bg = ctx["bg"]
        s = self.spec

        # Misty dusk spire clouds + conservatory dome trusses receding far below
        cloud = fbm_grid(H, W, 52.0, seed=s.seed + 411, octaves=3, sx=0.65, sy=1.45)
        out = ramp_blend(("void", "night", "deep"), np.clip(cloud * 0.85, 0.0, 0.999), bg)
        # Faint cloud rim highlights
        out = np.where((cloud > 0.72) & (bg < 0.40), IX["dusk"], out)
        # Radial glasshouse spire ribs spanning the abyss
        cx, cy = W * 0.52, H * 0.50
        rad = np.hypot(xs - cx, (ys - cy) * 1.15)
        ring = (np.abs(rad - 68.0) < 1.2) | (np.abs(rad - 118.0) < 1.2)
        spoke = (np.abs((xs - cx) - (ys - cy)) < 1.3) | (np.abs((xs - cx) + (ys - cy)) < 1.3)
        out = np.where((ring | spoke) & (bg < 0.65), IX["night"], out)
        out = np.where((ring & spoke), IX["dusk"], out)
        # Twilight stars & wind wisps
        st = hash01_grid(xs, ys, s.seed + 431)
        out = np.where(st > 0.996, IX["ice"], np.where(st > 0.993, IX["gold"], out))

        # Crisp drop edge below floating pads
        drop_n = ctx["n_up_land"] & (ly < 5)
        out = np.where(drop_n & (ly == 0), IX["stone"], out)
        out = np.where(drop_n & (ly > 0) & (ly < 4), IX["dusk"], out)
        out = np.where(drop_n & (ly == 4), IX["void"], out)
        buf[mask] = out[mask]

    def paint_void(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        self._paint_spire_sky(buf, ctx, ctx["m_void"])

    def paint_pit(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        self._paint_spire_sky(buf, ctx, ctx["m_pit"])

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        """Chamfer outer platform corners visually so the 4 pads don't read as identical 5x5 boxes."""
        m_walk = ctx["m_walk"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        abyss = ctx["m_pit"] | ctx["m_void"] | ctx["m_phantom"]
        if not np.any(abyss):
            return
        # Convex platform corners touching abyss on two adjacent sides get sculpted dark corner bevels
        c_nw = m_walk & ctx["n_up_abyss"] & ctx["n_lt_abyss"] & (lx + ly < 7)
        c_ne = m_walk & ctx["n_up_abyss"] & ctx["n_rt_abyss"] & ((ts - 1 - lx) + ly < 7)
        c_sw = m_walk & ctx["n_dn_abyss"] & ctx["n_lt_abyss"] & (lx + (ts - 1 - ly) < 7)
        c_se = m_walk & ctx["n_dn_abyss"] & ctx["n_rt_abyss"] & ((ts - 1 - lx) + (ts - 1 - ly) < 7)
        corners = c_nw | c_ne | c_sw | c_se
        # Bevel trim along the 45-degree chamfer line
        chamfer_edge = (
            (m_walk & ctx["n_up_abyss"] & ctx["n_lt_abyss"] & (lx + ly == 7))
            | (m_walk & ctx["n_up_abyss"] & ctx["n_rt_abyss"] & ((ts - 1 - lx) + ly == 7))
            | (m_walk & ctx["n_dn_abyss"] & ctx["n_lt_abyss"] & (lx + (ts - 1 - ly) == 7))
            | (m_walk & ctx["n_dn_abyss"] & ctx["n_rt_abyss"] & ((ts - 1 - lx) + (ts - 1 - ly) == 7))
        )
        buf[corners] = IX["night"]
        buf[chamfer_edge] = IX["gold"]


class MirefenCavePainter(ThemePainter):
    """Island 4 caves (cave_heron_roost, cave_echo_cellar, cave_rain_cistern, cave_sundial_well):
    luminous wet marsh-limestone flagstones, darker organic curved cavern walls, rich blue water with lilies,
    and per-room architectural flourishes.
    """

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Luminous wet marsh-limestone flagstones (walk_lum ~76-82)
        sh, sw = 10, 16
        ox = np.where(((ys // sh) & 1) == 1, 8, 0)
        sx, sy = (xs + ox) % sw, ys % sh
        slab_h = hash01_grid((xs + ox) // sw, ys // sh, s.seed + 67)
        out = ramp_blend(("dusk", "dusk", "plum", "mauve"), np.clip(nb * 0.48 + slab_h * 0.36 + warm * 0.10, 0.0, 0.999), bg)
        is_seam = (sx == 0) | (sy == 0)
        out = np.where((sy == 1) & (sx > 1) & (sx < sw - 2) & (slab_h > 0.46), IX["stone"], out)
        out = np.where(is_seam & (bg < 0.72), IX["night"], out)

        # Wet shoreline moss & crisp stone rim against cistern water
        near_w = ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
        out = np.where(near_w & (nb > 0.46) & (bg < 0.48), IX["teal"], out)
        out = np.where(near_w & (nf < 0.04), IX["jade"], out)
        buf[mask] = out[mask]

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        m_wall = ctx["m_wall"]
        m_walk = ctx["m_walk"]
        s = self.spec
        rid = str(ctx.get("meta", {}).get("id", "")).lower()

        # Organic curved cavern rock overhangs breaking flat rectangular room edges
        over = _wall_corner_overhang_mask(ctx, s.seed + 809, reach=7.2) & (m_walk | ctx["m_water"])
        if np.any(over):
            dist_w = chamfer_dist(~m_wall)
            vn = vnoise_grid(H, W, 10.0, seed=s.seed + 811)
            buf[over] = np.where(dist_w <= 2.5, IX["night"], np.where(vn > 0.56, IX["teal"], IX["pine"]))[over]
            buf[over & (vn > 0.70) & (dist_w > 2.5)] = IX["jade"]

        # Floating lily pads & reeds along water margins (especially lush in cave_heron_roost!)
        m_water = ctx["m_water"]
        if np.any(m_water):
            cx_l, cy_l = (xs % 12) - 6, (ys % 12) - 6
            lh = hash01_grid(xs // 12, ys // 12, s.seed + 823)
            thresh = 0.80 if "heron" in rid else 0.88
            pad = m_water & (lh > thresh) & ((cx_l * cx_l + cy_l * cy_l) <= 11)
            buf[pad] = np.where(cy_l < 0, IX["lime"], IX["jade"])[pad]
            buf[pad & (cx_l == 0) & (cy_l == 0) & (lh > thresh + 0.10)] = IX["rose"]

        # Per-cave distinct focal floor detail
        if "sundial" in rid:
            # Sunlit skylight wash & bronze ring around central well
            cx, cy = W * 0.5, H * 0.5
            r = np.hypot(xs - cx, ys - cy)
            ring = m_walk & ((np.abs(r - 44.0) < 1.2) | (np.abs(r - 60.0) < 1.0))
            buf[ring] = IX["gold"]
        elif "echo" in rid:
            # Subtle stepped cellar masonry arch bands
            band = m_walk & (xs % 48 == 24) & (bg < 0.45)
            buf[band] = IX["stone"]


class ThornwoodCavePainter(ThemePainter):
    """Island 3 caves (cave_amber_well, cave_burrow_den, cave_root_cellar, cave_sap_vault):
    warm readable burrow stone, darker curving root-cavern walls, and root-draped chasms.
    """

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Warm earthy burrow limestone/loam (walk_lum ~74-82, clearly brighter than dark root walls!)
        warp_n = fbm_grid(H, W, 30.0, seed=s.seed + 163, octaves=3)
        strata = np.clip(nb * 0.52 + warp_n * 0.36 + warm * 0.10, 0.0, 0.999)
        out = ramp_blend(("dusk", "plum", "mauve"), strata, bg)
        crack = (np.abs(warp_n - 0.46) < 0.014) & (nb < 0.58)
        out = np.where(crack, IX["night"], out)
        # Glowing amber sap-mineral veins in select cracks
        out = np.where(crack & (nb > 0.42) & (bg < 0.50), IX["apricot"], out)
        out = np.where((nf < 0.008) & (warp_n > 0.54), IX["jade"], out)
        out = np.where((nf > 0.994) & (nb > 0.50), IX["gold"], out)
        buf[mask] = out[mask]

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        H, W = ctx["H"], ctx["W"]
        m_wall = ctx["m_wall"]
        m_walk = ctx["m_walk"]
        s = self.spec
        rid = str(ctx.get("meta", {}).get("id", "")).lower()

        # Root-draped abyss depths (fixes stark black rectangles in cave_root_cellar & cave_amber_well!)
        _paint_hollow_oak_pit_roots(buf, ctx, s.seed + 37)

        # Warm amber glow rising softly from the well pit in cave_amber_well (Bayer-dithered, never blobby)
        if "amber" in rid:
            abyss = ctx["m_pit"] | ctx["m_void"]
            if np.any(abyss):
                ad = chamfer_dist(abyss)
                gn = fbm_grid(H, W, 24.0, seed=s.seed + 901, octaves=2)
                glow = abyss & (ad > 5.0) & (gn > 0.48) & (ctx["bg"] < (gn - 0.35) * 0.85)
                buf[glow] = IX["dusk"]
                mid_g = abyss & (ad > 9.0) & (gn > 0.56) & (ctx["bg"] < (gn - 0.44) * 0.75)
                buf[mid_g] = IX["wine"]
                core = abyss & (ad > 14.0) & (gn > 0.68) & (ctx["bg"] < 0.32)
                buf[core] = IX["coral"]

        # Organic curving root-cavern wall overhangs breaking straight corners
        over = _wall_corner_overhang_mask(ctx, s.seed + 919, reach=7.0) & m_walk
        if np.any(over):
            dist_w = chamfer_dist(~m_wall)
            vn = vnoise_grid(H, W, 10.0, seed=s.seed + 923)
            buf[over] = np.where(dist_w <= 2.5, IX["night"], np.where(vn > 0.54, IX["pine"], IX["dusk"]))[over]


# ------------------------------------------------------------------ SHARED ISLAND 3 & 4 HELPERS
def _paint_sconce_aprons_3_4(
    buf: np.ndarray,
    ctx: dict[str, Any],
    spacing: int = 32,
    phase: int = 16,
    radius: float = 12.0,
    strength: float = 0.44,
    col_core: str = "gold",
    col_mid: str = "apricot",
    draw_fixture: bool = True,
) -> None:
    """Paint warm Last Light wall sconces / lantern pockets and Bayer-dithered golden-apricot
    floor light aprons directly beneath interior south-facing walls."""
    m_wall = ctx["m_wall"]
    m_walk = ctx["m_walk"]
    if not (np.any(m_wall) and np.any(m_walk)):
        return
    xs, lx, ly, ts = ctx["xs"], ctx["lx"], ctx["ly"], ctx["ts"]
    bg = ctx["bg"]
    dn_open = ~ctx["n_dn_wall"]
    lt_open = ~ctx["n_lt_wall"]
    rt_open = ~ctx["n_rt_wall"]

    dn_walk = expand_neighbor_mask(ctx["grid"], 1, 0, WALKABLE_TYPES, ts)
    sx_mod = (xs - phase) % spacing
    dx = np.minimum(sx_mod, spacing - sx_mod)

    if draw_fixture:
        wall_ok = (
            m_wall
            & dn_open
            & dn_walk
            & (ctx["ty"] < ctx["h_t"] - 1)
            & (~(lt_open & (lx < 2)))
            & (~(rt_open & (lx >= ts - 2)))
        )
        buf[wall_ok & (dx == 0) & (ly == ts - 5)] = IX["apricot"]
        buf[wall_ok & (dx == 0) & (ly == ts - 4)] = IX["cream"]
        buf[wall_ok & (dx == 0) & (ly == ts - 3)] = IX[col_core]
        buf[wall_ok & (dx == 0) & (ly == ts - 2)] = IX[col_mid]
        buf[wall_ok & (dx == 1) & (ly == ts - 4)] = IX[col_mid]
        buf[wall_ok & (dx == 1) & (ly == ts - 3) & (bg < 0.72)] = IX[col_mid]
        buf[wall_ok & (dx == 1) & (ly == ts - 5)] = IX["dusk"]
        wall_halo = wall_ok & (dx >= 2) & (dx <= 4) & (ly >= ts - 5) & (ly <= ts - 2)
        buf[wall_halo & (dx <= 3) & (bg < 0.36)] = IX["plum"]

    up_lt_wall = expand_neighbor_mask(ctx["grid"], -1, -1, {"wall"}, ts)
    up_rt_wall = expand_neighbor_mask(ctx["grid"], -1, 1, {"wall"}, ts)
    floor_ok = (
        m_walk
        & ctx["n_up_wall"]
        & (~((~up_lt_wall) & (lx < 2)))
        & (~((~up_rt_wall) & (lx >= ts - 2)))
    )
    if not np.any(floor_ok):
        return

    dist = np.hypot(dx.astype(np.float32) * 0.78, (ly.astype(np.float32) + 0.6) * 1.08)
    in_pool = floor_ok & (dist < radius) & (ly >= 1)
    if not np.any(in_pool):
        return

    t = np.clip(1.0 - dist / float(radius), 0.0, 1.0)
    cur = buf
    is_bright = (cur == IX["cream"]) | (cur == IX["gold"]) | (cur == IX["ice"]) | (cur == IX["apricot"])
    paintable = in_pool & (~is_bright)

    outer_plum = paintable & (t < 0.45) & (t * 0.72 > bg) & ((cur == IX["night"]) | (cur == IX["deep"]) | (cur == IX["pine"]) | (cur == IX["dusk"]))
    outer_mauve = paintable & (t >= 0.32) & (t * (strength * 1.35) > bg)
    mid_apricot = paintable & (dist < radius * 0.56) & ((1.0 - dist / (radius * 0.58)) * (strength * 1.15) > bg)
    core_gold = paintable & (dist < 4.0) & ((1.0 - dist / 4.4) * strength > bg)

    buf[outer_plum] = IX["plum"]
    buf[outer_mauve] = IX["mauve"]
    buf[mid_apricot] = IX[col_mid]
    buf[core_gold] = IX[col_core]


def _paint_plush_rug_decor_3_4(
    painter: ThemePainter,
    buf: np.ndarray,
    ctx: dict[str, Any],
    decor_list: list[dict[str, Any]],
    default_main: str,
    default_hi: str,
    default_trim: str,
    default_edge: str,
) -> None:
    """Delegate non-rug decor to base painter, but render rugs as sumptuous plush Bayer velvet /
    woven silk tapestry (ZERO noisy diagonal barcode hatching)."""
    other: list[dict[str, Any]] = []
    rugs: list[dict[str, Any]] = []
    for item in decor_list:
        if isinstance(item, dict) and str(item.get("kind", "")).strip().lower() == "rug":
            rugs.append(item)
        else:
            other.append(item)
    if other:
        ThemePainter.paint_decor(painter, buf, ctx, other)
    if not rugs:
        return

    H, W = ctx["H"], ctx["W"]
    walk = ctx["m_walk"]
    bg = ctx["bg"]
    nb = ctx["n_broad"]

    for item in rugs:
        rect = item.get("rect")
        if not (isinstance(rect, list) and len(rect) >= 4):
            continue
        x0, y0, rw, rh = [int(v) for v in rect[:4]]
        x1, y1 = min(W, x0 + rw), min(H, y0 + rh)
        x0, y0 = max(0, x0), max(0, y0)
        if x1 <= x0 or y1 <= y0:
            continue
        c_main = IX.get(str(item.get("color", "")), IX[default_main])
        c_hi = IX.get(str(item.get("hi", "")), IX[default_hi])
        c_trim = IX.get(str(item.get("trim", "")), IX[default_trim])
        c_edge = IX.get(str(item.get("edge", "")), IX[default_edge])
        c_dk = SHADE_IX[c_main]
        cx_r, cy_r = (x0 + x1) // 2, (y0 + y1) // 2

        for y in range(y0, y1):
            for x in range(x0, x1):
                if not walk[y, x]:
                    continue
                dx = min(x - x0, x1 - 1 - x)
                dy = min(y - y0, y1 - 1 - y)
                d = min(dx, dy)
                if d == 0:
                    if dx == 0 and (y % 2 == 0):
                        buf[y, x] = c_trim
                    else:
                        buf[y, x] = c_edge
                elif d == 1:
                    buf[y, x] = c_dk
                elif d == 2:
                    buf[y, x] = c_trim if ((x + y) % 4 != 0) else c_hi
                else:
                    md = abs(x - cx_r) + abs(y - cy_r)
                    if md in (6, 12):
                        buf[y, x] = c_trim
                    elif md == 5 or md == 11:
                        buf[y, x] = c_dk
                    elif md < 5:
                        buf[y, x] = c_hi if (nb[y, x] > 0.45 and bg[y, x] < 0.55) else c_main
                    else:
                        v = nb[y, x]
                        if v > 0.64 and bg[y, x] < 0.24:
                            buf[y, x] = c_hi
                        elif v < 0.38 and bg[y, x] < 0.36:
                            buf[y, x] = c_dk
                        else:
                            buf[y, x] = c_main


def _paint_forest_or_marsh_water(
    buf: np.ndarray,
    ctx: dict[str, Any],
    ramp: tuple[str, ...],
    foam_col: str,
    glint_col: str,
    seed: int,
    cliff_skirt: bool = True,
    lily_thresh: float = 0.86,
    rain_rings: bool = False,
) -> None:
    """Luminous forest-pond / rain-rippled marsh water (~100-112 luma) with soft shoreline foam,
    floating lily pads, optional rain rings, and hanging mossy cliff skirts beneath north land."""
    mask = ctx["m_water"]
    if not np.any(mask):
        return
    H, W = ctx["H"], ctx["W"]
    xs, ys = ctx["xs"], ctx["ys"]
    ly = ctx["ly"]
    bg = ctx["bg"]

    rip1 = fbm_grid(H, W, 24.0, seed=seed + 301, octaves=2, sx=0.60, sy=1.65)
    rip2 = vnoise_grid(H, W, 12.0, seed=seed + 311)
    wave = 0.5 + 0.5 * np.sin(ys.astype(np.float32) * 0.40 + rip1 * 5.8)
    w_dist = chamfer_dist(mask)
    shallow = np.clip(1.0 - w_dist / 14.0, 0.0, 1.0) * 0.20
    field = np.clip(rip1 * 0.50 + wave * 0.22 + rip2 * 0.14 + shallow, 0.0, 0.999)
    out = ramp_blend(ramp, field, bg)

    # Soft horizontal shimmer dashes
    dash = (wave > 0.86) & (rip1 > 0.50) & (ys % 4 == 1) & (bg < 0.38)
    out = np.where(dash, IX[foam_col], out)

    # Optional concentric raindrop ripples (Mirefen marsh pools)
    if rain_rings:
        rx = (xs % 28) - 14
        ry = (ys % 24) - 12
        rh = hash01_grid(xs // 28, ys // 24, seed + 331)
        rr = np.hypot(rx.astype(np.float32), ry.astype(np.float32) * 1.35)
        ring = (rh > 0.58) & (w_dist > 4.0) & (np.abs(rr - (3.5 + (rh - 0.58) * 9.0)) < 0.75) & (bg < 0.55)
        out = np.where(ring, IX["ice"], out)

    # Floating lily pads & occasional rose lotus buds
    if lily_thresh < 0.99:
        cx_l, cy_l = (xs % 14) - 7, (ys % 14) - 7
        lh = hash01_grid(xs // 14, ys // 14, seed + 347)
        pad = (lh > lily_thresh) & (w_dist > 3.5) & ((cx_l * cx_l + cy_l * cy_l) <= 10)
        out = np.where(pad, np.where(cy_l < 0, IX["jade"], IX["teal"]), out)
        out = np.where(pad & (cx_l == 0) & (cy_l == 0) & (lh > lily_thresh + 0.08), IX["rose"], out)

    # Sparse twilight sparkle glints
    sh = hash01_grid(xs, ys, seed + 353)
    out = np.where((sh > 0.9955) & (w_dist > 3.0), IX[glint_col], out)

    # Organic shoreline foam halo
    foam_band = (w_dist <= 3.2) & ((w_dist <= 1.2) | ((1.0 - w_dist / 3.6) > bg * 1.15))
    out = np.where(foam_band, IX[foam_col], out)

    # 6px sculpted hanging mossy-stone cliff skirt dropping beneath north land tiles
    if cliff_skirt:
        up_land = ctx["n_up_land"]
        skirt = up_land & (ly < 6)
        stone_j = ((xs + (ly // 2) * 5) % 10) == 0
        out = np.where(skirt & (ly == 0), IX["pine"], out)
        out = np.where(skirt & (ly >= 1) & (ly <= 3), np.where(stone_j, IX["void"], IX["dusk"]), out)
        out = np.where(skirt & (ly == 2) & (rip2 > 0.62), IX["pine"], out)
        out = np.where(skirt & (ly == 4), IX["night"], out)
        out = np.where(skirt & (ly == 5), np.where(bg < 0.72, IX[foam_col], IX[ramp[-1]]), out)
    else:
        bank_n = ctx["n_up_land"] & (ly < 2)
        out = np.where(bank_n & (ly == 0), IX["night"], out)
        out = np.where(bank_n & (ly == 1) & (bg < 0.65), IX[foam_col], out)

    buf[mask] = out[mask]


def _paint_crafted_bridge(
    buf: np.ndarray,
    ctx: dict[str, Any],
    mode: str,
    deck_ramp: tuple[str, ...],
    rail_col: str,
    stud_col: str,
    seam_col: str,
    west_stud_col: str | None = None,
) -> None:
    """Weathered twilight timber footbridge or arched dressed-stone bridge (ZERO loud coral stripes or checkerboards)."""
    mask = ctx["m_bridge"]
    if not np.any(mask):
        return
    xs, ys = ctx["xs"], ctx["ys"]
    lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
    bg = ctx["bg"]
    nb = ctx["n_broad"]
    warm = ctx["warm"]

    horiz = ctx["n_lt_bridge"] | ctx["n_rt_bridge"] | ((~ctx["n_up_bridge"]) & (~ctx["n_dn_bridge"]))
    along = np.where(horiz, xs, ys)
    cross = np.where(horiz, ly, lx)

    crown = 1.0 - np.abs(cross.astype(np.float32) - (ts - 1) * 0.5) / max(1.0, ts * 0.55)
    field = np.clip(nb * 0.34 + crown * 0.44 + 0.14, 0.0, 0.999)
    out = ramp_blend(deck_ramp, field, bg)

    if mode == "timber":
        # Transverse weathered timber planks every 4px
        plank_seam = (along % 4 == 0) & (cross >= 2) & (cross <= ts - 3)
        out = np.where(plank_seam & (bg < 0.72), IX[seam_col], out)
        out = np.where((along % 4 == 1) & (cross >= 3) & (cross <= ts - 4) & (bg < 0.25), LIGHT_IX[out], out)
    else:
        # Dressed stone transverse paver joints every 8px + staggered center joint
        t_seam = (along % 8 == 0) & (cross >= 2) & (cross <= ts - 3)
        c_seam = (cross == ts // 2) & (((along // 8) & 1) == 0)
        out = np.where((t_seam | c_seam) & (bg < 0.72), IX[seam_col], out)
        out = np.where((along % 8 == 1) & (cross >= 3) & (cross <= ts - 4) & (bg < 0.30), LIGHT_IX[out], out)

    rail_n = (ly == 0) & (~ctx["n_up_bridge"]) & (~ctx["n_up_land"])
    rail_s = (ly == ts - 1) & (~ctx["n_dn_bridge"]) & (~ctx["n_dn_land"])
    rail_w = (lx == 0) & (~ctx["n_lt_bridge"]) & (~ctx["n_lt_land"])
    rail_e = (lx == ts - 1) & (~ctx["n_rt_bridge"]) & (~ctx["n_rt_land"])
    rail = rail_n | rail_s | rail_w | rail_e

    in_n = (ly == 1) & (~ctx["n_up_bridge"]) & (~ctx["n_up_land"])
    in_s = (ly == ts - 2) & (~ctx["n_dn_bridge"]) & (~ctx["n_dn_land"])
    in_w = (lx == 1) & (~ctx["n_lt_bridge"]) & (~ctx["n_lt_land"])
    in_e = (lx == ts - 2) & (~ctx["n_rt_bridge"]) & (~ctx["n_rt_land"])
    inner_sh = in_n | in_s | in_w | in_e

    out = np.where(inner_sh, IX[seam_col], out)
    out = np.where(rail, IX[rail_col], out)
    post = rail & ((along % 16) <= 1)
    if west_stud_col is not None:
        stud_ix = np.where(warm > 0.50, IX[west_stud_col], IX[stud_col])
        out = np.where(post, stud_ix, out)
    else:
        out = np.where(post, IX[stud_col], out)
    out = np.where(rail & ((along % 16) == 8), IX[seam_col], out)
    buf[mask] = out[mask]


# ------------------------------------------------------------------ ISLAND 3 BESPOKE PAINTERS
class BriarCourtPainter(ThemePainter):
    """Briar Court: deep sculpted thorny hedge & rose-stone walls (~38-46 luma) with warm golden
    rose-lantern sconce aprons so mossy courtyard flagstones (~78-86) and gilded stone lanes pop cleanly."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Running-bond 16x10 twilight mossy courtyard flagstones (calm ~78-84 luma)
        sh, sw = 10, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 59)

        field = np.clip(nb * 0.46 + slab_h * 0.34 + warm * 0.08 + 0.04, 0.0, 0.999)
        out = ramp_blend(("pine", "dusk", "teal", "teal", "jade"), field, bg)

        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.72)
        out = np.where(is_seam, IX["night"], out)
        # Quiet lit top bevel on select court flagstones
        is_bev = (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.64) & (bg < 0.32)
        out = np.where(is_bev, IX["jade"], out)
        # Subtle warm twilight moss-stone transition near center court
        warm_slab = (slab_h > 0.72) & (~is_seam) & (bg < 0.28)
        out = np.where(warm_slab, IX["mauve"], out)
        # Rare fallen briar rose petals
        out = np.where((nf > 0.9965) & (~is_seam), IX["rose"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb = ctx["bg"], ctx["n_broad"]

        edge_n = (~ctx["n_up_path"]) & (ly == 0)
        edge_s = (~ctx["n_dn_path"]) & (ly == ts - 1)
        edge_w = (~ctx["n_lt_path"]) & (lx == 0)
        edge_e = (~ctx["n_rt_path"]) & (lx == ts - 1)
        is_edge = edge_n | edge_s | edge_w | edge_e

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        ) & (~is_edge)

        row_id = ys // 8
        ox = np.where((row_id & 1) == 1, 8, 0)
        slab_h = hash01_grid((xs + ox) // 16, row_id, self.spec.seed + 71)
        out = ramp_blend(("dusk", "plum", "mauve", "mauve"), np.clip(nb * 0.40 + slab_h * 0.26 + 0.20, 0.0, 0.92), bg)
        seam = (((xs + ox) % 16 == 0) | (ys % 8 == 0)) & (bg < 0.56)
        out = np.where(seam, IX["night"], out)
        out = np.where(in_edge & (bg < 0.45), IX["stone"], out)
        out = np.where(in_edge & (((xs + ys) % 8) == 0), IX["apricot"], out)
        out = np.where(is_edge, IX["night"], out)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Deep tangled thorny briar-hedge cap (wall avg ~38-45)
        leaf_n = fbm_grid(H, W, 14.0, seed=s.seed + 211, octaves=2)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_lift = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.30
        out = ramp_blend(("night", "pine", "pine", "teal"), np.clip(leaf_n * 0.56 + edge_lift * 0.65, 0.0, 0.88), bg)
        # Organic dark shadowed leaf crevices for tactile hedge depth
        out = np.where((leaf_n < 0.34) & (bg < 0.55), IX["night"], out)
        # Subtle lit thorn-crown leaves near WNW outer edge & rare tiny rosebuds nestled near hedge rim
        out = np.where((wall_d < 4.5) & (leaf_n > 0.64) & (bg < 0.50), IX["teal"], out)
        bud = (wall_d < 9.0) & (leaf_n > 0.54) & (hash01_grid(xs, ys, s.seed + 223) > 0.985)
        out = np.where(bud, IX["rose"], out)

        # 7px sculpted south-facing briar-stone retaining wall
        south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
        out = np.where(south & (ly == ts - 7), np.where(leaf_n > 0.50, IX["teal"], IX["mauve"]), out)
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1), IX["night"], out)
        # Carved dark stone block joints + trailing thorny vine tendrils
        block_j = ((xs + (ly // 2) * 4) % 12 == 0)
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1) & (~block_j) & (leaf_n > 0.44), IX["dusk"], out)
        vine = south & (ly >= ts - 6) & (ly <= ts - 2) & (leaf_n > 0.60) & ((xs % 7) <= 1)
        out = np.where(vine, IX["pine"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        # Crisp WNW lit edge & shaded east edge
        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), IX["teal"], out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(west_rim & (bg < 0.52 + 0.30 * warm), IX["teal"], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(east_rim, IX["void"], out)
        buf[mask] = out[mask]

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        over = _wall_corner_overhang_mask(ctx, self.spec.seed + 613, reach=5.0) & m_walk
        if np.any(over):
            vn = vnoise_grid(ctx["H"], ctx["W"], 9.0, seed=self.spec.seed + 617)
            buf[over] = np.where(vn > 0.68, IX["teal"], np.where(vn > 0.36, IX["pine"], IX["night"]))[over]
            bud = over & (hash01_grid(ctx["xs"], ctx["ys"], self.spec.seed + 619) > 0.965)
            buf[bud] = IX["rose"]
        # Warm golden rose-lantern sconce fixtures & soft golden floor aprons
        _paint_sconce_aprons_3_4(buf, ctx, spacing=48, phase=24, radius=13.0, strength=0.45, draw_fixture=True)


class LoomPainter(ThemePainter):
    """Weaver's Loom: dark carved timber-and-tapestry-frame walls (~34-42) with warm brass
    thread-lantern sconce floor aprons, calm twilight-plum woven floorboards (~74-82) with refined
    golden warp-thread accent paths, and plush woven rugs (ZERO wireframe grid clutter!)."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]
        s = self.spec

        # Calm horizontal twilight-plum woven loom floorboards (8px plank courses, ~74-80 luma)
        ph = 8
        pr = ys // ph
        py = ys % ph
        ox = (pr * 13) % 32
        plank_h = hash01_grid((xs + ox) // 32, pr, s.seed + 63)
        butt = (xs + ox) % 32

        field = np.clip(nb * 0.42 + plank_h * 0.28 + warm * 0.10 + 0.06, 0.0, 0.999)
        out = ramp_blend(("dusk", "plum", "plum", "mauve"), field, bg)

        # Quiet soft timber plank seams (no noisy full-room checkerboard/wireframe!)
        out = np.where((py == 0) & (bg < 0.56), IX["night"], out)
        out = np.where((butt == 0) & (py > 0) & (bg < 0.42), IX["night"], out)
        # Subtle warm sunlit bevel on select floorboards
        out = np.where((py == 1) & (plank_h > 0.72) & (bg < 0.24), IX["mauve"], out)

        # Refined sparse golden warp-thread accent inlay lines every 32px (calm silk stitch, never busy grid!)
        warp_row = (ys % 32 == 16)
        warp_stitch = warp_row & ((xs % 16) >= 4) & ((xs % 16) <= 7) & (bg < 0.52)
        out = np.where(warp_stitch, IX["apricot"], out)
        out = np.where(warp_row & ((xs % 32) == 6) & (nb > 0.48), IX["gold"], out)

        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb = ctx["bg"], ctx["n_broad"]

        edge_n = (~ctx["n_up_path"]) & (ly == 0)
        edge_s = (~ctx["n_dn_path"]) & (ly == ts - 1)
        edge_w = (~ctx["n_lt_path"]) & (lx == 0)
        edge_e = (~ctx["n_rt_path"]) & (lx == ts - 1)
        is_edge = edge_n | edge_s | edge_w | edge_e

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        ) & (~is_edge)

        # Plush woven emerald-teal silk-tapestry warp-thread runner (~80-86 luma)
        field = np.clip(nb * 0.48 + 0.24, 0.0, 0.94)
        out = ramp_blend(("pine", "teal", "teal", "jade"), field, bg)
        # Subtle fine horizontal woven weft texture
        weft = (ys % 4 == 0) & (bg < 0.34)
        out = np.where(weft, IX["pine"], out)
        # Delicate golden warp-thread center diamond stitch (calm spacing every 16px)
        cx_t, cy_t = np.abs(lx - 8), np.abs(ly - 8)
        diamond = ((cx_t + cy_t) == 3) & (bg < 0.65)
        out = np.where(diamond, IX["apricot"], out)
        out = np.where((lx == 8) & (ly == 8), IX["gold"], out)
        # Refined gilded selvedge border
        out = np.where(in_edge & (((xs + ys) % 4) != 0), IX["apricot"], out)
        out = np.where(in_edge & (((xs + ys) % 8) == 0), IX["gold"], out)
        out = np.where(is_edge, IX["night"], out)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Dark carved oak-beam & loom-frame cap (wall avg ~36-42)
        wood_n = fbm_grid(H, W, 22.0, seed=s.seed + 205, octaves=2, sx=0.65, sy=1.45)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_lift = np.clip(1.0 - wall_d / 16.0, 0.0, 1.0) * 0.28
        out = ramp_blend(("night", "night", "dusk", "dusk"), np.clip(wood_n * 0.65 + edge_lift + 0.14, 0.0, 0.96), bg)
        # Calm carved oak beam joints on cap
        beam_j = (ys % 8 == 0) & (bg < 0.62)
        out = np.where(beam_j, IX["void"], out)

        # 7px sculpted south-facing carved timber-and-tapestry wall (interior walls)
        south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
        bay_x = xs % 24
        out = np.where(south & (ly == ts - 7), IX["plum"], out)  # carved timber cornice
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1), IX["night"], out)
        # Carved dark timber frame pilasters between tapestry bays
        pil = south & (ly > ts - 7) & (ly < ts - 1) & ((bay_x <= 2) | (bay_x == 23))
        out = np.where(pil, IX["dusk"], out)
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1) & (bay_x == 0), IX["void"], out)
        # Recessed dark woven tapestry panel inside each bay (bay_x 5..18)
        in_tap = south & (ly >= ts - 6) & (ly <= ts - 2) & (bay_x >= 5) & (bay_x <= 18)
        out = np.where(in_tap, IX["void"], out)
        # Subtle vertical warp threads inside recessed tapestry bay
        warp = in_tap & ((bay_x % 3) == 0) & (ly >= ts - 5)
        out = np.where(warp, IX["dusk"], out)
        out = np.where(in_tap & (bay_x == 12) & (ly == ts - 4), IX["apricot"], out)
        # Brass thread-guide eyelet pegs on lower loom rail
        peg = south & (ly == ts - 2) & ((bay_x == 8) | (bay_x == 16))
        out = np.where(peg, IX["apricot"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        # Crisp WNW sunlit edge & dark east edge
        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), IX["plum"], out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(west_rim & (bg < 0.55 + 0.30 * warm), IX["plum"], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(east_rim, IX["void"], out)
        buf[mask] = out[mask]

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_crafted_bridge(
            buf,
            ctx,
            mode="timber",
            deck_ramp=("dusk", "plum", "wine", "apricot"),
            rail_col="apricot",
            stud_col="gold",
            seam_col="night",
        )

    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        _paint_plush_rug_decor_3_4(self, buf, ctx, decor_list, "teal", "jade", "apricot", "night")

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Warm brass thread-lantern sconces every 2nd pilaster (spacing=48) & golden floor aprons
        _paint_sconce_aprons_3_4(buf, ctx, spacing=48, phase=1, radius=13.0, strength=0.46, draw_fixture=True)


class UnderRootPainter(ThemePainter):
    """The Under-Root: rich dark knotted-root earth walls (~36-44) with glowing amber-sap lantern
    pockets & floor aprons, calm twilight loam/moss-veined stone floor (~72-80), and organically
    feathered stepped root-stone paths (ZERO bright flat orange rectangles!)."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nm = ctx["n_med"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Calm twilight loam & curving subterranean root-stone floor (~72-80 luma)
        cx, cy = W * 0.48, H * 0.50
        rad = np.hypot((xs - cx) * 0.85, (ys - cy) * 1.15)
        root_wave = 0.5 + 0.5 * np.sin(rad * 0.16 + nb * 6.2)
        field = np.clip(nb * 0.46 + root_wave * 0.28 + nm * 0.14 + warm * 0.08, 0.0, 0.999)
        out = ramp_blend(("dusk", "plum", "plum", "mauve"), field, bg)

        # Gentle low-contrast earthy root grooves
        groove = (root_wave < 0.09) & (bg < 0.48)
        out = np.where(groove, IX["night"], out)
        # Subtle moss veins creeping near walls & water
        near_w = ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
        near_wall = ctx["n_up_wall"] | ctx["n_dn_wall"] | ctx["n_lt_wall"] | ctx["n_rt_wall"]
        out = np.where((near_w | near_wall) & (nb < 0.46) & (bg < 0.46), IX["pine"], out)
        out = np.where(near_w & (nb > 0.54) & (bg < 0.42), IX["teal"], out)
        out = np.where((nf < 0.006) & (nb > 0.58), IX["jade"], out)
        # Rare tiny amber sap-mineral specks
        out = np.where((nf > 0.9965) & (nb > 0.52), IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        s = self.spec

        # Organically feathered stepped root-stone & warm packed-earth trails (~78-86 luma; NO orange slabs!)
        p_dist = chamfer_dist(mask)
        edge_n = fbm_grid(H, W, 14.0, seed=s.seed + 131, octaves=2)
        # Outer 2.5px feather smoothly into twilight loam
        feather = (p_dist <= 2.6) & ((p_dist / 2.8 + (edge_n - 0.5) * 0.55) < bg)

        # Rounded stepping root-stone pavers inside the path
        sh, sw = 10, 14
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 137)

        field = np.clip(nb * 0.38 + slab_h * 0.34 + 0.16, 0.0, 0.94)
        paver = ramp_blend(("dusk", "plum", "wine", "mauve"), field, bg)
        # Soft dark joints around stepping stones
        joint = ((sx == 0) | (sy == 0) | ((sx == 1) & (sy == 1)) | ((sx == sw - 1) & (sy == sh - 1))) & (bg < 0.62)
        paver = np.where(joint, IX["night"], paver)
        # Subtle warm amber-pebble catchlights on select stepped stones
        peb = (sy == 1) & (sx >= 3) & (sx <= sw - 4) & (slab_h > 0.76) & (bg < 0.28)
        paver = np.where(peb, IX["apricot"], paver)

        # Feathered outer edge melts into twilight loam
        loam = ramp_blend(("dusk", "plum"), np.clip(nb * 0.70, 0.0, 0.99), bg)
        out = np.where(feather, loam, paver)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Rich dark knotted-root earth wall cap (wall avg ~37-43)
        root_n = fbm_grid(H, W, 16.0, seed=s.seed + 221, octaves=2, sx=1.35, sy=0.70)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_lift = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.28
        out = ramp_blend(("night", "night", "pine", "dusk"), np.clip(root_n * 0.65 + edge_lift + 0.14, 0.0, 0.96), bg)
        # Intertwined dark root ridges along cap
        ridge = (np.abs(root_n - 0.54) < 0.06) & (bg < 0.62)
        out = np.where(ridge, IX["dusk"], out)
        crevice = (root_n < 0.30) & (bg < 0.55)
        out = np.where(crevice, IX["void"], out)
        moss_rim = (wall_d < 5.0) & (nb > 0.60) & (bg < 0.48)
        out = np.where(moss_rim, IX["teal"], out)

        # 7px knotted-root earth south facade
        south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
        lip_y = ts - 7 + np.where(root_n > 0.52, 0, 1)
        out = np.where(south & (ly == lip_y), np.where(nb > 0.50, IX["teal"], IX["plum"]), out)
        furrow = (xs + (root_n * 7.0).astype(np.int32)) % 8
        face_c = np.where(
            furrow == 0,
            IX["void"],
            np.where(furrow <= 2, IX["night"], np.where((furrow == 4) & (ly < ts - 2), IX["pine"], IX["dusk"])),
        )
        out = np.where(south & (ly > lip_y) & (ly < ts - 1), face_c, out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        # Crisp WNW sunlit edge & dark east shadow
        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), np.where(nb > 0.50, IX["teal"], IX["plum"]), out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(west_rim & (bg < 0.48 + 0.30 * warm), IX["dusk"], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(east_rim, IX["void"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_forest_or_marsh_water(
            buf,
            ctx,
            ramp=("deep", "blue", "blue", "sky"),
            foam_col="ice",
            glint_col="ice",
            seed=self.spec.seed,
            cliff_skirt=False,
            lily_thresh=0.92,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_crafted_bridge(
            buf,
            ctx,
            mode="timber",
            deck_ramp=("dusk", "plum", "wine", "mauve"),
            rail_col="jade",
            stud_col="apricot",
            seam_col="night",
        )

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_hollow_oak_pit_roots(buf, ctx, self.spec.seed + 41)
        over = _wall_corner_overhang_mask(ctx, self.spec.seed + 621, reach=6.0) & (ctx["m_walk"] | ctx["m_water"])
        if np.any(over):
            dist_w = chamfer_dist(~ctx["m_wall"])
            vn = vnoise_grid(ctx["H"], ctx["W"], 10.0, seed=self.spec.seed + 627)
            buf[over] = np.where(dist_w <= 2.2, IX["night"], np.where(vn > 0.56, IX["pine"], IX["dusk"]))[over]
        # Glowing amber-sap lantern pockets & warm floor light aprons
        _paint_sconce_aprons_3_4(buf, ctx, spacing=48, phase=24, radius=13.0, strength=0.45, draw_fixture=True)


class ThornwoodOverworldPainter(ThemePainter):
    """Island 3 Overworld & woodland groves (overworld, ow_camp, ow_shift_*):
    Lush twilight moss-and-meadow woodland terraces (~72-80, warm amber-lit west fading to cool
    emerald-teal east), dark thorny canopy/cliff walls (~38-46) with hanging cliff skirts,
    luminous forest-pond water, warm amber lantern-lit paths & weathered timber footbridges."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nm = ctx["n_med"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Lush twilight moss-and-meadow woodland terraces (west warm amber-plum/moss -> east cool emerald-teal)
        turf_n = fbm_grid(H, W, 28.0, seed=s.seed + 79, octaves=3)
        field = np.clip(nb * 0.46 + turf_n * 0.34 + nm * 0.14 + 0.04, 0.0, 0.999)
        west_meadow = ramp_blend(("dusk", "plum", "teal", "mauve"), field, bg)
        east_meadow = ramp_blend(("pine", "dusk", "teal", "jade"), field, bg)
        use_west = warm > (0.46 + (nb - 0.5) * 0.24 + (bg - 0.5) * 0.18)
        out = np.where(use_west, west_meadow, east_meadow)

        # Gentle organic woodland moss-tuft & terrace contours (calm, low-frequency detail)
        tuft = (turf_n > 0.68) & (nm > 0.58) & (bg < 0.35)
        out = np.where(tuft, np.where(use_west, IX["teal"], IX["jade"]), out)
        shade_dip = (turf_n < 0.28) & (bg < 0.42)
        out = np.where(shade_dip, IX["pine"], out)

        # Rare warm golden fallen leaves in west / cool moonlit dew specks in east
        out = np.where((nf > 0.9965) & (nb > 0.48), np.where(warm > 0.50, IX["apricot"], IX["lime"]), out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        s = self.spec

        # Warm amber lantern-lit woodland footpaths & forest-stone stepping lanes (~80-86 luma)
        p_dist = chamfer_dist(mask)
        edge_n = fbm_grid(H, W, 14.0, seed=s.seed + 109, octaves=2)
        feather = (p_dist <= 2.2) & ((p_dist / 2.4 + (edge_n - 0.5) * 0.5) < bg)

        sh, sw = 8, 14
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 113)
        field = np.clip(nb * 0.40 + slab_h * 0.28 + 0.18, 0.0, 0.94)
        p_warm = ramp_blend(("dusk", "plum", "wine", "mauve"), field, bg)
        p_cool = ramp_blend(("dusk", "plum", "mauve", "stone"), np.clip(field - 0.08, 0.0, 0.92), bg)
        paver = np.where(warm > (0.45 + (bg - 0.5) * 0.18), p_warm, p_cool)

        seam = (((xs + ox) % sw == 0) | (ys % sh == 0)) & (bg < 0.50)
        paver = np.where(seam, IX["night"], paver)

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )
        stud_c = np.where(warm > 0.45, IX["apricot"], IX["jade"])
        paver = np.where(in_edge & (((xs + ys) % 8) == 0), stud_c, paver)

        edge_loam = ramp_blend(("pine", "dusk"), np.clip(nb * 0.75, 0.0, 0.99), bg)
        out = np.where(feather, edge_loam, paver)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Dark thorny forest canopy & mossy cliff walls (wall avg ~38-45)
        can_n = fbm_grid(H, W, 16.0, seed=s.seed + 231, octaves=2)
        leaf_n = vnoise_grid(H, W, 8.0, seed=s.seed + 237)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_lift = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.28
        out = ramp_blend(("night", "pine", "pine", "teal"), np.clip(can_n * 0.56 + edge_lift * 0.60, 0.0, 0.88), bg)
        out = np.where((can_n < 0.34) & (bg < 0.55), IX["night"], out)
        # Layered dark leaf crowns on canopy cap
        out = np.where((can_n > 0.60) & (leaf_n > 0.54) & (wall_d < 9.0) & (bg < 0.55), IX["teal"], out)
        # Rare tiny twilight blossom flecks near canopy rim
        blos = (wall_d < 9.0) & (can_n > 0.55) & (hash01_grid(xs, ys, s.seed + 243) > 0.990)
        out = np.where(blos, np.where(warm > 0.50, IX["apricot"], IX["rose"]), out)

        # 7px mossy cliff / gnarled trunk south facade
        south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
        lip_y = ts - 7 + np.where(can_n > 0.52, 0, 1)
        out = np.where(south & (ly == lip_y), np.where(can_n > 0.48, IX["teal"], IX["plum"]), out)
        cliff_j = ((xs + (ly // 2) * 5) % 9 == 0)
        out = np.where(south & (ly > lip_y) & (ly < ts - 1), np.where(cliff_j, IX["void"], IX["night"]), out)
        out = np.where(south & (ly > lip_y) & (ly < ts - 2) & (~cliff_j) & (leaf_n > 0.54), IX["dusk"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), np.where(warm > 0.50, IX["plum"], IX["teal"]), out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(west_rim & (bg < 0.46 + 0.30 * warm), IX["pine"], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(east_rim, IX["void"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_forest_or_marsh_water(
            buf,
            ctx,
            ramp=("deep", "pine", "blue", "teal", "sky"),
            foam_col="ice",
            glint_col="gold",
            seed=self.spec.seed,
            cliff_skirt=True,
            lily_thresh=0.85,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_crafted_bridge(
            buf,
            ctx,
            mode="timber",
            deck_ramp=("dusk", "plum", "wine", "mauve"),
            rail_col="apricot",
            stud_col="gold",
            seam_col="night",
        )

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Soft mossy shoreline edge where land meets forest ponds
        walk = ctx["m_walk"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        rim = (
            (walk & ctx["n_dn_water"] & (ly == ts - 1))
            | (walk & ctx["n_up_water"] & (ly == 0))
            | (walk & ctx["n_lt_water"] & (lx == 0))
            | (walk & ctx["n_rt_water"] & (lx == ts - 1))
        )
        buf[rim] = IX["teal"]
        # Organic canopy corner overhangs & warm lantern aprons along north cliff bases
        over = _wall_corner_overhang_mask(ctx, self.spec.seed + 641, reach=5.0) & walk
        if np.any(over):
            vn = vnoise_grid(ctx["H"], ctx["W"], 9.0, seed=self.spec.seed + 647)
            buf[over] = np.where(vn > 0.62, IX["pine"], IX["night"])[over]
        _paint_sconce_aprons_3_4(buf, ctx, spacing=36, phase=18, radius=11.0, strength=0.38, draw_fixture=True)


# ------------------------------------------------------------------ ISLAND 4 BESPOKE PAINTERS
class HourglassMazePainter(ThemePainter):
    """The Hourglass Maze: calm golden-twilight sandstone & sifted-amber sand (~84-94, ZERO 150+ glare!),
    clearly darker carved brass-and-sandstone monument walls (~38-46) with warm hourglass sconce aprons,
    and refined twilight-ashlar causeways (~90-98, ZERO blinding cream highways!)."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nm = ctx["n_med"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Wind-sifted golden-twilight sandstone & amber sand (~84-92 luma!)
        rip_n = fbm_grid(H, W, 32.0, seed=s.seed + 83, octaves=2, sx=0.75, sy=1.35)
        wave = 0.5 + 0.5 * np.sin(ys.astype(np.float32) * 0.28 + xs.astype(np.float32) * 0.08 + rip_n * 5.2)
        field = np.clip(nb * 0.42 + wave * 0.26 + warm * 0.14 + 0.04, 0.0, 0.999)
        sand = ramp_blend(("dusk", "plum", "wine", "coral"), field, bg)

        # Delicate golden-hour sunlit sand-ripple crest flecks (sparse, calm!)
        crest = (wave > 0.88) & (nb > 0.52) & (bg < 0.26)
        sand = np.where(crest, IX["apricot"], sand)
        # Soft twilight ripple trough shadow
        trough = (wave < 0.14) & (bg < 0.34)
        sand = np.where(trough, IX["dusk"], sand)

        # Sunken dressed twilight-sandstone flagstones emerging where sand thins (nb < 0.40)
        sh, sw = 10, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 89)
        stone = ramp_blend(("dusk", "plum", "mauve"), np.clip(slab_h * 0.55 + nb * 0.35, 0.0, 0.95), bg)
        stone = np.where(((sx == 0) | (sy == 0)) & (bg < 0.65), IX["night"], stone)
        use_stone = (nb < 0.38) & ((0.40 - nb) * 2.6 > bg)

        out = np.where(use_stone, stone, sand)
        # Rare tiny quartz/brass sand sparkles
        out = np.where((nf > 0.9965) & (nb > 0.50), IX["gold"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb = ctx["bg"], ctx["n_broad"]

        edge_n = (~ctx["n_up_path"]) & (ly == 0)
        edge_s = (~ctx["n_dn_path"]) & (ly == ts - 1)
        edge_w = (~ctx["n_lt_path"]) & (lx == 0)
        edge_e = (~ctx["n_rt_path"]) & (lx == ts - 1)
        is_edge = edge_n | edge_s | edge_w | edge_e

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        ) & (~is_edge)

        # Refined twilight-ashlar causeway (~90-98 luma; ZERO blinding cream highway!)
        row_id = ys // 8
        ox = np.where((row_id & 1) == 1, 8, 0)
        sx = (xs + ox) % 16
        sy = ys % 8
        slab_h = hash01_grid((xs + ox) // 16, row_id, self.spec.seed + 97)
        field = np.clip(nb * 0.34 + slab_h * 0.28 + 0.22, 0.08, 0.82)
        out = ramp_blend(("dusk", "plum", "mauve", "stone"), field, bg)

        seam = ((sx == 0) | (sy == 0)) & (bg < 0.54)
        out = np.where(seam, IX["night"], out)
        bev = (sy == 1) & (sx > 2) & (sx < 14) & (slab_h > 0.68) & (bg < 0.28)
        out = np.where(bev, IX["stone"], out)
        # Subtle inlaid brass curbstone rivets
        out = np.where(in_edge & (bg < 0.42), IX["mauve"], out)
        out = np.where(in_edge & (((xs + ys) % 8) == 0), IX["apricot"], out)
        out = np.where(is_edge, IX["night"], out)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Dark carved brass-and-sandstone monument walls (wall avg ~38-45)
        cap_n = fbm_grid(H, W, 20.0, seed=s.seed + 251, octaves=2)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_lift = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.26
        out = ramp_blend(("night", "night", "dusk", "dusk"), np.clip(cap_n * 0.66 + edge_lift + 0.16, 0.0, 0.96), bg)
        # Subtle dressed stone coursing on monument cap + sparse dark hedge moss near rims
        row_id = ys // 8
        ox = np.where((row_id & 1) == 1, 8, 0)
        out = np.where((((xs + ox) % 16 == 0) | (ys % 8 == 0)) & (bg < 0.56), IX["void"], out)
        out = np.where((wall_d < 4.5) & (nb > 0.62) & (bg < 0.45), IX["pine"], out)

        # 7px sculpted south-facing carved monument wall with recessed brass hourglass alcoves
        south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
        bay_x = xs % 24
        out = np.where(south & (ly == ts - 7), IX["mauve"], out)
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1), IX["night"], out)
        # Projecting carved stone pilasters at bay boundaries
        pil = south & (ly > ts - 7) & (ly < ts - 1) & ((bay_x <= 2) | (bay_x == 23))
        out = np.where(pil, IX["dusk"], out)
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1) & (bay_x == 0), IX["void"], out)
        # Recessed hourglass-motif alcove centered at bay_x == 12
        alcove = south & (ly >= ts - 6) & (ly <= ts - 2) & (bay_x >= 9) & (bay_x <= 15)
        out = np.where(alcove, IX["void"], out)
        # Tiny hourglass silhouette inside alcove (top/bottom wide, pinched center waist)
        hg_bulb = alcove & (((ly == ts - 5) | (ly == ts - 3)) & (bay_x >= 11) & (bay_x <= 13))
        hg_waist = alcove & (ly == ts - 4) & (bay_x == 12)
        out = np.where(hg_bulb, IX["plum"], out)
        out = np.where(hg_waist, IX["apricot"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        # Crisp WNW sunlit edge & dark east shadow
        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), IX["plum"], out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(west_rim & (bg < 0.48 + 0.30 * warm), IX["dusk"], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(east_rim, IX["void"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_forest_or_marsh_water(
            buf,
            ctx,
            ramp=("deep", "blue", "blue", "sky"),
            foam_col="ice",
            glint_col="gold",
            seed=self.spec.seed,
            cliff_skirt=False,
            lily_thresh=0.90,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_crafted_bridge(
            buf,
            ctx,
            mode="stone",
            deck_ramp=("dusk", "plum", "mauve", "stone"),
            rail_col="apricot",
            stud_col="gold",
            seam_col="night",
        )

    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        _paint_plush_rug_decor_3_4(self, buf, ctx, decor_list, "wine", "coral", "apricot", "night")

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Warm hourglass sconce fixtures every 2nd pilaster (spacing=48) & golden floor aprons
        _paint_sconce_aprons_3_4(buf, ctx, spacing=48, phase=1, radius=13.0, strength=0.44, draw_fixture=True)


class GardenPartyPainter(ThemePainter):
    """The Garden Party: calm moonlit twilight courtyard flagstones (~78-86), clearly darker
    manicured topiary-hedge & balustrade walls (~38-46) with warm golden lantern-string sconce glows,
    and plush crimson-wine velvet banquet runners & rugs (ZERO noisy barcode crosshatch!)."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Calm moonlit twilight courtyard checkered flagstones (16x12 slabs, ~78-85 luma)
        sh, sw = 12, 16
        tx_s = xs // sw
        ty_s = ys // sh
        sx = xs % sw
        sy = ys % sh
        chk = ((tx_s + ty_s) & 1) == 0
        slab_h = hash01_grid(tx_s, ty_s, s.seed + 67)

        field = np.clip(nb * 0.42 + slab_h * 0.28 + warm * 0.08 + 0.06, 0.0, 0.999)
        tile_a = ramp_blend(("dusk", "plum", "mauve"), field, bg)
        tile_b = ramp_blend(("dusk", "dusk", "plum", "mauve"), field, bg)
        out = np.where(chk, tile_a, tile_b)

        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.72)
        out = np.where(is_seam, IX["night"], out)
        # Delicate moonlit bevel on select light tiles
        is_bev = chk & (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.62) & (bg < 0.28)
        out = np.where(is_bev, np.where(warm > 0.50, IX["stone"], IX["sky"]), out)
        # Subtle garden moss in seams near koi ponds + occasional fallen rose petals
        near_w = ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
        out = np.where(near_w & is_seam & (bg < 0.55), IX["teal"], out)
        out = np.where((nf > 0.9965) & (~is_seam), IX["rose"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb = ctx["bg"], ctx["n_broad"]

        edge_n = (~ctx["n_up_path"]) & (ly == 0)
        edge_s = (~ctx["n_dn_path"]) & (ly == ts - 1)
        edge_w = (~ctx["n_lt_path"]) & (lx == 0)
        edge_e = (~ctx["n_rt_path"]) & (lx == ts - 1)
        is_edge = edge_n | edge_s | edge_w | edge_e

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        ) & (~is_edge)

        # Plush crimson-wine velvet banquet runner (calm Bayer velvet pile, ZERO noisy stripes!)
        field = np.clip(nb * 0.54 + 0.22, 0.0, 0.92)
        out = ramp_blend(("dusk", "plum", "wine", "wine"), field, bg)
        # Soft center velvet sheen & delicate woven filigree border
        sheen = (nb > 0.64) & (bg < 0.22)
        out = np.where(sheen, IX["rose"], out)
        out = np.where(in_edge & (((xs + ys) % 4) != 0), IX["rose"], out)
        out = np.where(in_edge & (((xs + ys) % 8) == 0), IX["gold"], out)
        out = np.where(is_edge, IX["night"], out)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Dark manicured topiary-hedge & stone balustrade cap (wall avg ~38-45)
        leaf_n = fbm_grid(H, W, 12.0, seed=s.seed + 261, octaves=2)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_lift = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.28
        out = ramp_blend(("night", "pine", "pine", "teal"), np.clip(leaf_n * 0.56 + edge_lift * 0.60, 0.0, 0.88), bg)
        out = np.where((leaf_n < 0.34) & (bg < 0.55), IX["night"], out)
        # Subtle clipped topiary highlight flecks & rare rose blooms nestled near hedge rim
        out = np.where((wall_d < 4.5) & (leaf_n > 0.64) & (bg < 0.48), IX["teal"], out)
        out = np.where((wall_d < 9.0) & (leaf_n > 0.56) & (hash01_grid(xs, ys, s.seed + 271) > 0.986), IX["rose"], out)

        # 7px sculpted south-facing garden balustrade & manicured topiary wall
        south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
        out = np.where(south & (ly == ts - 7), IX["mauve"], out)  # carved balustrade rail
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1), IX["night"], out)
        # Baluster columns every 8px along south facade
        bal = south & (ly >= ts - 6) & (ly <= ts - 2) & ((xs % 8 == 3) | (xs % 8 == 4))
        out = np.where(bal, IX["dusk"], out)
        # Subtle lantern-string festoon wire & tiny glowing warm bulbs between posts (every 24px)
        bx = xs % 24
        festoon = south & (ly == ts - 6) & ((bx == 6) | (bx == 18))
        out = np.where(festoon, IX["apricot"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), IX["teal"], out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(west_rim & (bg < 0.48 + 0.30 * warm), IX["pine"], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(east_rim, IX["void"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_forest_or_marsh_water(
            buf,
            ctx,
            ramp=("deep", "blue", "blue", "sky"),
            foam_col="ice",
            glint_col="gold",
            seed=self.spec.seed,
            cliff_skirt=False,
            lily_thresh=0.84,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_crafted_bridge(
            buf,
            ctx,
            mode="stone",
            deck_ramp=("dusk", "plum", "mauve", "stone"),
            rail_col="rose",
            stud_col="gold",
            seam_col="night",
        )

    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        _paint_plush_rug_decor_3_4(self, buf, ctx, decor_list, "wine", "rose", "gold", "night")

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Warm golden festive lantern-string sconces & soft golden floor aprons
        _paint_sconce_aprons_3_4(buf, ctx, spacing=36, phase=18, radius=13.0, strength=0.45, draw_fixture=True)


class MirefenOverworldPainter(ThemePainter):
    """Island 4 Overworld — Mirefen Gardens:
    Rain-slicked twilight marsh terraces (~74-82, warm lantern-west fading to cool moonlit-rain east),
    dark weeping-willow & mossy-stone retaining walls (~38-46) with hanging cliff skirts,
    luminous rain-rippled marsh pools (~102-112), and warm lantern-lit stone bridges."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nm = ctx["n_med"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Rain-slicked twilight marsh terraces (16x10 damp flagstones + marsh moss, ~74-82 luma)
        sh, sw = 10, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 57)

        field = np.clip(nb * 0.46 + slab_h * 0.28 + nm * 0.14 + 0.04, 0.0, 0.999)
        west_marsh = ramp_blend(("dusk", "plum", "plum", "mauve"), field, bg)
        east_marsh = ramp_blend(("deep", "dusk", "teal", "mauve"), field, bg)
        use_west = warm > (0.46 + (nb - 0.5) * 0.24 + (bg - 0.5) * 0.18)
        out = np.where(use_west, west_marsh, east_marsh)

        # Quiet damp terrace mortar seams
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.52)
        out = np.where(is_seam, IX["night"], out)
        # Subtle rain-slicked diagonal sheen flecks
        sheen = (((xs + ys * 2) % 31) < 2) & (nb > 0.62) & (bg < 0.24) & (~is_seam)
        out = np.where(sheen, np.where(use_west, IX["stone"], IX["sky"]), out)
        # Damp moss creeping near water margins
        near_w = ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
        out = np.where(near_w & (nb > 0.48) & (bg < 0.36), IX["teal"], out)
        out = np.where((nf > 0.9965) & (nb > 0.50), np.where(warm > 0.52, IX["apricot"], IX["ice"]), out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]

        edge_n = (~ctx["n_up_path"]) & (ly == 0)
        edge_s = (~ctx["n_dn_path"]) & (ly == ts - 1)
        edge_w = (~ctx["n_lt_path"]) & (lx == 0)
        edge_e = (~ctx["n_rt_path"]) & (lx == ts - 1)
        is_edge = edge_n | edge_s | edge_w | edge_e

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        ) & (~is_edge)

        # Warm lantern-lit wet-stone marsh causeways (~86-94 luma so paths read cleanly over marsh floor!)
        pf = np.clip(nb * 0.36 + 0.34, 0.0, 0.94)
        p_warm = ramp_blend(("plum", "mauve", "mauve", "stone"), pf, bg)
        p_cool = ramp_blend(("dusk", "mauve", "mauve", "sky"), np.clip(pf - 0.04, 0.0, 0.92), bg)
        out = np.where(warm > (0.48 + (bg - 0.5) * 0.18), p_warm, p_cool)

        row_id = ys // 8
        ox = np.where((row_id & 1) == 1, 8, 0)
        seam = ((ys % 8 == 0) | (((xs + ox) % 16) == 0)) & (bg < 0.58)
        out = np.where(seam, IX["night"], out)
        stud_c = np.where(warm > 0.48, IX["gold"], IX["ice"])
        out = np.where(in_edge & (((xs + ys) % 8) == 0), stud_c, out)
        out = np.where(is_edge & (bg < 0.78), IX["night"], out)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Dark weeping-willow canopy & mossy retaining-stone walls (wall avg ~38-45)
        willow_n = fbm_grid(H, W, 16.0, seed=s.seed + 281, octaves=2, sx=1.75, sy=0.55)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_lift = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.28
        out = ramp_blend(("night", "pine", "pine", "teal"), np.clip(willow_n * 0.56 + edge_lift * 0.55, 0.0, 0.86), bg)
        out = np.where((willow_n < 0.34) & (bg < 0.55), IX["night"], out)
        # Subtle drooping willow frond tips along WNW rim
        out = np.where((wall_d < 4.5) & (willow_n > 0.64) & (bg < 0.46), IX["teal"], out)

        # 7px mossy retaining-stone south facade draped with weeping willow tendrils
        south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
        out = np.where(south & (ly == ts - 7), np.where(willow_n > 0.50, IX["teal"], IX["mauve"]), out)
        block_j = ((xs + (ly // 2) * 5) % 10 == 0)
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1), np.where(block_j, IX["void"], IX["night"]), out)
        out = np.where(south & (ly > ts - 7) & (ly < ts - 2) & (~block_j) & (nb > 0.54), IX["dusk"], out)
        # Trailing willow vines hanging down south retaining wall
        frond = south & (ly >= ts - 6) & (ly <= ts - 2) & (willow_n > 0.62) & ((xs % 5) == 0)
        out = np.where(frond, IX["pine"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), IX["teal"], out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(west_rim & (bg < 0.46 + 0.30 * warm), IX["dusk"], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(east_rim, IX["void"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_forest_or_marsh_water(
            buf,
            ctx,
            ramp=("deep", "blue", "blue", "sky"),
            foam_col="ice",
            glint_col="ice",
            seed=self.spec.seed,
            cliff_skirt=True,
            lily_thresh=0.84,
            rain_rings=True,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_crafted_bridge(
            buf,
            ctx,
            mode="stone",
            deck_ramp=("dusk", "plum", "mauve", "stone"),
            rail_col="stone",
            stud_col="ice",
            seam_col="night",
            west_stud_col="gold",
        )

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        walk = ctx["m_walk"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        xs, ys = ctx["xs"], ctx["ys"]
        rim = (
            (walk & ctx["n_dn_water"] & (ly == ts - 1))
            | (walk & ctx["n_up_water"] & (ly == 0))
            | (walk & ctx["n_lt_water"] & (lx == 0))
            | (walk & ctx["n_rt_water"] & (lx == ts - 1))
        )
        buf[rim] = np.where(((xs + ys) % 6 == 0), IX["stone"], IX["mauve"])[rim]
        _paint_sconce_aprons_3_4(buf, ctx, spacing=32, phase=16, radius=11.0, strength=0.40, draw_fixture=True)


SPECS_3_4: list[tuple[ThemeSpec, type[ThemePainter]]] = [
    (
        ThemeSpec(
            id="hollow_oak",
            name="The Hollow Oak",
            island=3,
            floor_style="packed_loam_roots",
            floor_ramp=("dusk", "plum", "wine"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="coral",
            floor_accent_b="gold",
            path_style="boardwalk",
            path_main="wine",
            path_hi="mauve",
            path_edge="dusk",
            path_trim="apricot",
            wall_style="root_bark",
            wall_cap=("void", "night", "dusk"),
            wall_lip="jade",
            wall_face="dusk",
            wall_face_hi="wine",
            wall_base="void",
            water_style="canal_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="teal",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="coral",
            bridge_style="timber",
            bridge_main="coral",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=301,
            prop_sheet="island3_scenery",
            door_sheet="island3_doors",
            special_tiles=("F:foliage",),
            default_decor=("stain", "light_shaft"),
            notes="Hollow Oak flagship dungeon: warm living bark heartwood, amber sap light, root curves, glowing shelf fungus.",
        ),
        HollowOakPainter,
    ),
    (
        ThemeSpec(
            id="conservatory",
            name="The Drowned Conservatory",
            island=4,
            floor_style="rain_slate",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="sky",
            floor_accent_b="rose",
            path_style="inlaid_strip",
            path_main="mauve",
            path_hi="stone",
            path_edge="dusk",
            path_trim="gold",
            wall_style="masonry",
            wall_cap=("void", "night", "pine"),
            wall_lip="stone",
            wall_face="dusk",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="ice",
            rim_mid="sky",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="gold",
            bridge_dark="night",
            seed=401,
            prop_sheet="island4_scenery",
            door_sheet="island4_doors",
            special_tiles=("G:glass",),
            default_decor=("light_shaft", "circle", "stain"),
            notes="Mirefen Glass Conservatory: wet stained-glass glasshouse, sunlit limestone upper solarium, painted iron rafters, broken panes, vines, pilasters.",
        ),
        ConservatoryPainter,
    ),
    (
        ThemeSpec(
            id="canopy_sprint",
            name="Canopy Bough Sprint",
            island=3,
            floor_style="ship_planking",
            floor_ramp=("dusk", "plum", "wine", "mauve"),
            floor_seam="night",
            floor_bevel="coral",
            floor_accent_a="jade",
            floor_accent_b="gold",
            path_style="boardwalk",
            path_main="wine",
            path_hi="coral",
            path_edge="dusk",
            path_trim="gold",
            wall_style="root_bark",
            wall_cap=("void", "night", "pine"),
            wall_lip="lime",
            wall_face="pine",
            wall_face_hi="teal",
            wall_base="void",
            water_style="canal_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="teal",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="lime",
            rim_mid="jade",
            bridge_style="timber",
            bridge_main="coral",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=341,
            prop_sheet="island3_scenery",
            door_sheet="island3_doors",
            default_decor=("circle", "light_shaft"),
            notes="High treetop canopy sprint: curving twilight oak boughs and leaf crowns below, mossy heartwood landings.",
        ),
        CanopySprintPainter,
    ),
    (
        ThemeSpec(
            id="wing_spire",
            name="Conservatory Wing Spire",
            island=4,
            floor_style="checkered_terrace",
            floor_ramp=("dusk", "mauve", "stone"),
            floor_seam="night",
            floor_bevel="cream",
            floor_accent_a="sky",
            floor_accent_b="gold",
            path_style="inlaid_strip",
            path_main="mauve",
            path_hi="stone",
            path_edge="dusk",
            path_trim="gold",
            wall_style="masonry",
            wall_cap=("void", "night", "pine"),
            wall_lip="ice",
            wall_face="pine",
            wall_face_hi="teal",
            wall_base="void",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="gold",
            rim_mid="ice",
            bridge_style="stone_arch",
            bridge_main="stone",
            bridge_hi="cream",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=441,
            prop_sheet="island4_scenery",
            door_sheet="island4_doors",
            default_decor=("circle", "light_shaft"),
            notes="Conservatory wind-spire trial: misty dusk skylight void with 4 distinct architectural landing pads.",
        ),
        WingSpirePainter,
    ),
    (
        ThemeSpec(
            id="mirefen_cave",
            name="Mirefen Sunken Grotto",
            island=4,
            floor_style="rain_slate",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="teal",
            floor_accent_b="gold",
            path_style="flagstone",
            path_main="mauve",
            path_hi="stone",
            path_edge="dusk",
            path_trim="ice",
            wall_style="cavern_rock",
            wall_cap=("void", "night", "pine"),
            wall_lip="sky",
            wall_face="night",
            wall_face_hi="teal",
            wall_base="void",
            water_style="rain_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="ice",
            rim_mid="sky",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="ice",
            bridge_dark="night",
            seed=451,
            prop_sheet="island4_scenery",
            door_sheet="island4_doors",
            default_decor=("stain", "circle"),
            notes="Flooded Mirefen grottoes and Heron Roost: wet mauve-limestone ledges, darker curved rock overhangs, distinct sapphire basins.",
        ),
        MirefenCavePainter,
    ),
    (
        ThemeSpec(
            id="thornwood_cave",
            name="Thornwood Root Cavern",
            island=3,
            floor_style="cave_floor",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="coral",
            floor_accent_a="jade",
            floor_accent_b="gold",
            path_style="sand_trail",
            path_main="wine",
            path_hi="coral",
            path_edge="dusk",
            path_trim="apricot",
            wall_style="cavern_rock",
            wall_cap=("void", "night", "pine"),
            wall_lip="jade",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="canal_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="teal",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="jade",
            bridge_style="timber",
            bridge_main="coral",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=351,
            prop_sheet="theme_cave_3",
            door_sheet="theme_cave_3_doors",
            default_decor=("stain", "light_shaft"),
            notes="Thornwood root caves: warm readable burrow stone, darker curving root-cavern walls, root-framed amber chasms.",
        ),
        ThornwoodCavePainter,
    ),
    (
        ThemeSpec(
            id="thornwood_overworld",
            name="Thornwood Woodland",
            island=3,
            floor_style="packed_loam_roots",
            floor_ramp=("pine", "dusk", "teal", "jade"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="teal",
            floor_accent_b="apricot",
            path_style="flagstone",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="root_bark",
            wall_cap=("void", "night", "pine"),
            wall_lip="teal",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="teal",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="teal",
            bridge_style="timber",
            bridge_main="plum",
            bridge_hi="wine",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=305,
            prop_sheet="island3_scenery",
            door_sheet="island3_doors",
            special_tiles=("F:foliage",),
            default_decor=("stain", "light_shaft"),
            notes="Thornwood overworld & woodland groves: lush twilight moss terraces (warm west -> cool emerald east), dark thorny canopy cliffs, forest ponds, timber footbridges.",
        ),
        ThornwoodOverworldPainter,
    ),
    (
        ThemeSpec(
            id="mirefen_overworld",
            name="Mirefen Gardens",
            island=4,
            floor_style="rain_slate",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="teal",
            floor_accent_b="sky",
            path_style="flagstone",
            path_main="mauve",
            path_hi="stone",
            path_edge="night",
            path_trim="gold",
            wall_style="masonry",
            wall_cap=("void", "night", "pine"),
            wall_lip="teal",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="rain_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="ice",
            rim_mid="sky",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="stone",
            bridge_dark="night",
            seed=405,
            prop_sheet="island4_scenery",
            door_sheet="island4_doors",
            special_tiles=("F:foliage",),
            default_decor=("stain", "light_shaft"),
            notes="Mirefen overworld: rain-slicked twilight marsh terraces (warm lantern west -> cool moonlit east), dark weeping-willow retaining walls, rain-rippled marsh pools, lantern stone bridges.",
        ),
        MirefenOverworldPainter,
    ),
    (
        ThemeSpec(
            id="under_root",
            name="The Under-Root",
            island=3,
            floor_style="packed_loam_roots",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="teal",
            floor_accent_b="apricot",
            path_style="flagstone",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="root_bark",
            wall_cap=("void", "night", "pine"),
            wall_lip="teal",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="rain_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="teal",
            bridge_style="timber",
            bridge_main="plum",
            bridge_hi="wine",
            bridge_rail="jade",
            bridge_dark="night",
            seed=311,
            prop_sheet="theme_under_root",
            door_sheet="theme_under_root_doors",
            special_tiles=("F:foliage",),
            default_decor=("stain", "light_shaft"),
            notes="Tiny world under giant roots: dark knotted-root walls with amber-sap lantern pockets, calm twilight loam floor, organically feathered stepped root-stone paths.",
        ),
        UnderRootPainter,
    ),
    (
        ThemeSpec(
            id="loom",
            name="The Weaver's Loom",
            island=3,
            floor_style="woven_tapestry",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="apricot",
            floor_accent_b="gold",
            path_style="carpet_runner",
            path_main="teal",
            path_hi="jade",
            path_edge="night",
            path_trim="apricot",
            wall_style="wainscot",
            wall_cap=("void", "night", "dusk"),
            wall_lip="plum",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="rain_water",
            water_deep="night",
            water_mid="pine",
            water_hi="teal",
            water_foam="ice",
            pit_style="loom_void",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="mauve",
            bridge_style="silk_span",
            bridge_main="plum",
            bridge_hi="wine",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=321,
            prop_sheet="theme_loom",
            door_sheet="theme_loom_doors",
            special_tiles=("D:carpet",),
            default_decor=("rug", "circle"),
            notes="Giant living loom: dark carved timber-and-tapestry walls with brass thread-lantern sconces, calm twilight-plum floorboards, refined golden warp-thread accent paths.",
        ),
        LoomPainter,
    ),
    (
        ThemeSpec(
            id="briar_court",
            name="The Briar Court",
            island=3,
            floor_style="heraldic_court",
            floor_ramp=("pine", "dusk", "teal", "jade"),
            floor_seam="night",
            floor_bevel="jade",
            floor_accent_a="pine",
            floor_accent_b="rose",
            path_style="inlaid_strip",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="hedge_topiary",
            wall_cap=("void", "night", "pine"),
            wall_lip="teal",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="teal",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="jade",
            rim_mid="apricot",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=331,
            prop_sheet="theme_briar_court",
            door_sheet="theme_briar_court_doors",
            special_tiles=("F:foliage",),
            default_decor=("circle", "stain"),
            notes="Forest trial arena: dark sculpted rose-thorn briar walls with golden lantern sconces, calm mossy court flagstones, gilded twilight stone lanes.",
        ),
        BriarCourtPainter,
    ),
    (
        ThemeSpec(
            id="hourglass_maze",
            name="The Hourglass Maze",
            island=4,
            floor_style="sand_labyrinth",
            floor_ramp=("dusk", "plum", "wine", "coral"),
            floor_seam="night",
            floor_bevel="apricot",
            floor_accent_a="mauve",
            floor_accent_b="apricot",
            path_style="inlaid_strip",
            path_main="mauve",
            path_hi="stone",
            path_edge="night",
            path_trim="apricot",
            wall_style="masonry",
            wall_cap=("void", "night", "dusk"),
            wall_lip="mauve",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="mauve",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=411,
            prop_sheet="theme_hourglass_maze",
            door_sheet="theme_hourglass_maze_doors",
            special_tiles=("F:foliage",),
            default_decor=("compass", "circle", "light_shaft"),
            notes="Time-loop labyrinth: calm golden-twilight sandstone & sifted-amber sand, dark brass-and-sandstone monument walls with hourglass sconces, refined twilight-ashlar causeways.",
        ),
        HourglassMazePainter,
    ),
    (
        ThemeSpec(
            id="rain_mausoleum",
            name="The Rain Mausoleum",
            island=4,
            floor_style="rain_slate",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="sky",
            floor_accent_b="apricot",
            path_style="flagstone",
            path_main="mauve",
            path_hi="stone",
            path_edge="dusk",
            path_trim="ice",
            wall_style="masonry",
            wall_cap=("void", "night", "dusk"),
            wall_lip="sky",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="rain_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="ice",
            rim_mid="sky",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="ice",
            bridge_dark="night",
            seed=421,
            prop_sheet="theme_rain_mausoleum",
            door_sheet="theme_rain_mausoleum_doors",
            special_tiles=("H:grate",),
            default_decor=("grate", "stain", "circle"),
            notes="Weather-wheel crypt: readable wet mauve-slate flagstones vs deep sapphire canals, darker carved-niche walls.",
        ),
        RainMausoleumPainter,
    ),
    (
        ThemeSpec(
            id="garden_party",
            name="The Garden Party",
            island=4,
            floor_style="checkered_terrace",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="teal",
            floor_accent_b="rose",
            path_style="carpet_runner",
            path_main="wine",
            path_hi="rose",
            path_edge="night",
            path_trim="gold",
            wall_style="hedge_topiary",
            wall_cap=("void", "night", "pine"),
            wall_lip="mauve",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="stone",
            rim_mid="apricot",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="rose",
            bridge_dark="night",
            seed=431,
            prop_sheet="theme_garden_party",
            door_sheet="theme_garden_party_doors",
            special_tiles=("D:carpet", "F:foliage"),
            default_decor=("rug", "light_shaft", "circle"),
            notes="Twilight heist courtyard: calm moonlit flagstones, dark manicured topiary & balustrade walls with lantern-string glows, plush crimson-wine velvet banquet runners.",
        ),
        GardenPartyPainter,
    ),
]
