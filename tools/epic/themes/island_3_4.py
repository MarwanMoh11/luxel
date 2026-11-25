"""Islands 3 & 4 themes:
- hollow_oak (Thornwood Hollow flagship dungeon: warm living bark, sap light, root curves, shelf fungus)
- conservatory (Mirefen Gardens flagship dungeon: wet stained-glass glasshouse, sunlit limestone r15-r18, painted silhouettes)
- rain_mausoleum (wet mauve-slate flagstones vs deep rain canals, carved niches, darker sculpted walls)
- canopy_sprint (Island 3 canopy sprint trial: painted twilight boughs over forest depths, mossy oak-branch landings)
- wing_spire (Island 4 wing spire trial: varied architectural platforms over misty skylight chasm)
- mirefen_cave (Island 4 caves incl. cave_heron_roost: luminous wet limestone, curved cavern overhangs, distinct basins)
- thornwood_cave (Island 3 caves: warm root-burrow stone, curved root chasms, amber sap glow)
- under_root, loom, briar_court, hourglass_maze, garden_party.
"""
from __future__ import annotations

from typing import Any

import numpy as np

from .base import ThemePainter, ThemeSpec
from .kit import (
    IX,
    LIGHT_IX,
    SHADE_IX,
    chamfer_dist,
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
            # Warm sunlit conservatory limestone (calm mid-bright ~95-110 luma, NOT blinding orange desert sand!)
            slab_f = np.clip(nb * 0.45 + slab_h * 0.35 + warm * 0.14, 0.0, 0.999)
            out = ramp_blend(("dusk", "plum", "mauve", "mauve"), slab_f, bg)
            is_seam = (sx == 0) | (sy == 0)
            is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & ((slab_h > 0.48) | (bg < 0.30))
            out = np.where(is_bev, IX["stone"], out)
            out = np.where(is_seam & (bg < 0.72), IX["dusk"], out)
            # Soft warm sunlit conservatory glass rays drifting diagonally across limestone
            ray = (xs - ys * 0.55) % 68.0
            in_ray = (ray >= 12.0) & (ray <= 26.0) & (nb > 0.38)
            out = np.where(in_ray & (~is_seam) & (bg < 0.34), IX["stone"], out)
            out = np.where(in_ray & (~is_seam) & (nb > 0.58) & (bg < 0.22), IX["gold"], out)
            # Occasional delicate rose stained-glass floor reflection
            pane_tint = (xs - ys * 0.55) % 96.0
            out = np.where((pane_tint >= 52.0) & (pane_tint <= 64.0) & (~is_seam) & (bg < 0.20), IX["rose"], out)
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

        # Dark wrought-iron & damp glasshouse masonry wall cap (clearly darker than walkable floor!)
        out = ramp_blend(("void", "night", "pine"), np.clip(nb * 0.70 + 0.15, 0.0, 0.999), bg)
        # Iron conservatory roof-frame glazing mullions on wall cap (24x16 skylight bays)
        rib_x = xs % 24
        rib_y = ys % 16
        in_pane = (rib_x >= 3) & (rib_x <= 20) & (rib_y >= 2) & (rib_y <= 12)
        pane_h = hash01_grid(xs // 24, ys // 16, s.seed + 241)
        # Most roof panes show dim twilight glass; ~25% are broken panes (deep void with shard glint)!
        broken = pane_h < 0.26
        glass_c = np.where(
            broken,
            IX["void"],
            np.where(pane_h > 0.78, IX["teal"], np.where(pane_h > 0.52, IX["deep"], IX["night"])),
        )
        out = np.where(in_pane, glass_c, out)
        # Diagonal glass catchlight on intact cap panes
        gleam = in_pane & (~broken) & (((rib_x + rib_y) % 9) == 0) & (bg < 0.55)
        out = np.where(gleam, IX["blue"], out)
        # Jagged glass shard highlight on broken pane rim
        shard = in_pane & broken & ((rib_x == 4) | (rib_y == 3)) & (((xs + ys) % 5) == 0)
        out = np.where(shard, IX["sky"], out)
        # Wrought-iron roof mullions & crossbars
        mullion = (rib_x == 0) | (rib_x == 1) | (rib_x == 23) | (rib_y == 0) | (rib_y == 1)
        out = np.where(mullion, IX["night"], out)
        out = np.where((rib_x == 2) & (rib_y > 1), IX["dusk"], out)

        # South-facing glasshouse wall with arched stained-glass lancets & broken panes (interior walls only)
        south = dn_open & (ly >= ts - 7) & (ctx["ty"] < ctx["h_t"] - 1)
        out = np.where(south & (ly == ts - 7), IX["stone"], out)  # carved limestone cornice
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1), IX["dusk"], out)
        # Stained-glass lancet windows every 24px (width 10px: rib_x 7..16)
        win_h = hash01_grid(xs // 24, ys // ts, s.seed + 263)
        win_broken = win_h < 0.24
        in_arch = (
            south
            & (ly >= ts - 6)
            & (ly <= ts - 2)
            & (rib_x >= 7)
            & (rib_x <= 16)
            & ~((ly == ts - 6) & ((rib_x == 7) | (rib_x == 16)))
        )
        # Stained glass jewel color per lancet (rose / gold / sky / jade)
        st_col = np.where(
            win_broken,
            IX["void"],
            np.where(
                win_h < 0.44,
                IX["sky"],
                np.where(win_h < 0.64, IX["rose"], np.where(win_h < 0.82, IX["gold"], IX["jade"])),
            ),
        )
        out = np.where(in_arch, st_col, out)
        # Lead muntin bar splitting each lancet vertically + dark mullion frame
        out = np.where(in_arch & (rib_x == 12), IX["night"], out)
        # Jagged shard highlight inside broken lancets
        out = np.where(in_arch & win_broken & (ly == ts - 5) & ((rib_x == 9) | (rib_x == 14)), IX["ice"], out)
        # Lower stone plinth
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        # Crisp WNW sunlit edge highlight on wall caps
        out = np.where(up_open & (ly == 0), IX["sky"], out)
        west_rim = lt_open & (lx == 0) & (~(dn_open & (ly >= ts - 6)))
        out = np.where(west_rim & (bg < 0.55 + 0.35 * warm), IX["mauve"], out)
        east_rim = rt_open & (lx == ts - 1) & (~(dn_open & (ly >= ts - 6)))
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


class BriarCourtPainter(ThemePainter):
    """Briar Court: darker sculpted thorn-hedge walls with hanging rose vines for crisp wall-vs-floor pop."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        m_walk = ctx["m_walk"]
        over = _wall_corner_overhang_mask(ctx, self.spec.seed + 613, reach=5.0) & m_walk
        if np.any(over):
            vn = vnoise_grid(ctx["H"], ctx["W"], 9.0, seed=self.spec.seed + 617)
            buf[over] = np.where(vn > 0.62, IX["teal"], IX["pine"])[over]
            bud = over & (hash01_grid(ctx["xs"], ctx["ys"], self.spec.seed + 619) > 0.96)
            buf[bud] = IX["rose"]


class LoomPainter(ThemePainter):
    """Weaver's Loom: taut luminous horizontal shuttle threads crossing floor seams."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        dn_open = ~ctx["n_dn_wall"]
        xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
        # Brass thread-guide eyelets along south loom beams
        peg = m_wall & dn_open & (ly == ts - 4) & ((xs % 16) == 8)
        buf[peg] = IX["gold"]


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
            id="under_root",
            name="The Under-Root",
            island=3,
            floor_style="packed_loam_roots",
            floor_ramp=("dusk", "plum", "wine"),
            floor_seam="night",
            floor_bevel="coral",
            floor_accent_a="night",
            floor_accent_b="lime",
            path_style="sand_trail",
            path_main="apricot",
            path_hi="gold",
            path_edge="plum",
            path_trim="cream",
            wall_style="root_bark",
            wall_cap=("pine", "teal", "jade"),
            wall_lip="lime",
            wall_face="plum",
            wall_face_hi="coral",
            wall_base="night",
            water_style="moon_mirror",
            water_deep="blue",
            water_mid="sky",
            water_hi="ice",
            water_foam="cream",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="lime",
            rim_mid="jade",
            bridge_style="timber",
            bridge_main="coral",
            bridge_hi="apricot",
            bridge_rail="lime",
            bridge_dark="plum",
            seed=311,
            prop_sheet="theme_under_root",
            door_sheet="theme_under_root_doors",
            special_tiles=("F:foliage",),
            default_decor=("stain", "light_shaft"),
            notes="Tiny world under giant roots: sweeping woody root ridges, amber ant roads, giant sky/ice dew pools.",
        ),
        ThemePainter,
    ),
    (
        ThemeSpec(
            id="loom",
            name="The Weaver's Loom",
            island=3,
            floor_style="woven_tapestry",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="gold",
            floor_accent_b="cream",
            path_style="carpet_runner",
            path_main="teal",
            path_hi="jade",
            path_edge="night",
            path_trim="gold",
            wall_style="wainscot",
            wall_cap=("night", "plum", "wine"),
            wall_lip="gold",
            wall_face="plum",
            wall_face_hi="coral",
            wall_base="void",
            water_style="rain_water",
            water_deep="night",
            water_mid="pine",
            water_hi="teal",
            water_foam="lime",
            pit_style="loom_void",
            void_style="crypt_abyss",
            rim_hi="gold",
            rim_mid="apricot",
            bridge_style="silk_span",
            bridge_main="apricot",
            bridge_hi="gold",
            bridge_rail="cream",
            bridge_dark="wine",
            seed=321,
            prop_sheet="theme_loom",
            door_sheet="theme_loom_doors",
            special_tiles=("D:carpet",),
            default_decor=("rug", "inlay", "circle"),
            notes="Giant living loom: warp-and-weft woven walkways, luminous gold guide threads, deep threaded void.",
        ),
        LoomPainter,
    ),
    (
        ThemeSpec(
            id="briar_court",
            name="The Briar Court",
            island=3,
            floor_style="heraldic_court",
            floor_ramp=("pine", "teal", "jade"),
            floor_seam="night",
            floor_bevel="lime",
            floor_accent_a="pine",
            floor_accent_b="rose",
            path_style="inlaid_strip",
            path_main="mauve",
            path_hi="stone",
            path_edge="pine",
            path_trim="gold",
            wall_style="hedge_topiary",
            wall_cap=("night", "pine", "teal"),
            wall_lip="rose",
            wall_face="night",
            wall_face_hi="pine",
            wall_base="void",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="teal",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="lime",
            rim_mid="gold",
            bridge_style="stone_arch",
            bridge_main="stone",
            bridge_hi="cream",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=331,
            prop_sheet="theme_briar_court",
            door_sheet="theme_briar_court_doors",
            special_tiles=("F:foliage",),
            default_decor=("circle", "inlay", "stain"),
            notes="Forest trial arena: darker rose-thorn topiary walls, mossy court flagstones, gilded jousting lanes.",
        ),
        BriarCourtPainter,
    ),
    (
        ThemeSpec(
            id="hourglass_maze",
            name="The Hourglass Maze",
            island=4,
            floor_style="sand_labyrinth",
            floor_ramp=("plum", "coral", "apricot", "gold"),
            floor_seam="dusk",
            floor_bevel="cream",
            floor_accent_a="mauve",
            floor_accent_b="cream",
            path_style="inlaid_strip",
            path_main="stone",
            path_hi="cream",
            path_edge="dusk",
            path_trim="gold",
            wall_style="hedge_topiary",
            wall_cap=("pine", "teal", "jade"),
            wall_lip="gold",
            wall_face="pine",
            wall_face_hi="teal",
            wall_base="night",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="teal",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="gold",
            rim_mid="stone",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=411,
            prop_sheet="theme_hourglass_maze",
            door_sheet="theme_hourglass_maze_doors",
            special_tiles=("F:foliage",),
            default_decor=("compass", "circle", "light_shaft"),
            notes="Time-loop labyrinth: sunlit golden hourglass sand, sunken flagstone steps, clipped topiary hedges.",
        ),
        ThemePainter,
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
            floor_ramp=("teal", "mauve", "stone"),
            floor_seam="pine",
            floor_bevel="cream",
            floor_accent_a="jade",
            floor_accent_b="rose",
            path_style="carpet_runner",
            path_main="wine",
            path_hi="rose",
            path_edge="dusk",
            path_trim="gold",
            wall_style="hedge_topiary",
            wall_cap=("pine", "teal", "jade"),
            wall_lip="rose",
            wall_face="teal",
            wall_face_hi="lime",
            wall_base="night",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="stone",
            rim_mid="gold",
            bridge_style="stone_arch",
            bridge_main="stone",
            bridge_hi="cream",
            bridge_rail="rose",
            bridge_dark="mauve",
            seed=431,
            prop_sheet="theme_garden_party",
            door_sheet="theme_garden_party_doors",
            special_tiles=("D:carpet", "F:foliage"),
            default_decor=("rug", "light_shaft", "circle"),
            notes="Twilight heist courtyard: checkered stone-and-moss terrace, festive rose carpets, koi lily ponds.",
        ),
        ThemePainter,
    ),
]
