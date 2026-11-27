"""Islands 7 & 8 + Hub themes:
- Island 7 (Moon Shoals & Mirror Spire): moon_shoals_overworld, mirror_spire,
  inverted_palace_silver, inverted_palace_black, doppel_theatre, masquerade, moon_shoals_cave
- Island 8 & Hub: toll_house, archive (base + 8 island memory variants), endless_stair,
  bell_sanctum, wick_house.
"""
from __future__ import annotations

import math
from typing import Any

import numpy as np

from .base import ThemePainter, ThemeSpec
from .kit import (
    COOL_IX,
    IX,
    LIGHT_IX,
    SHADE_IX,
    chamfer_dist,
    fbm_grid,
    hash01_grid,
    ramp_blend,
    vnoise_grid,
)


# ------------------------------------------------------------------ ISLAND 7 HELPERS
def _paint_plush_rug_decor(
    painter: ThemePainter,
    buf: np.ndarray,
    ctx: dict[str, Any],
    decor_list: list[dict[str, Any]],
    default_main: str,
    default_hi: str,
    default_trim: str,
    default_edge: str,
) -> None:
    """Delegate non-rug decor to base painter, but render rugs as calm plush velvet
    (subtle Bayer pile, woven gilded border, quiet central diamond — ZERO diagonal zebra stripes)."""
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
                        # Subtle plush Bayer velvet pile (NO diagonal scratch lines!)
                        v = nb[y, x]
                        if v > 0.62 and bg[y, x] < 0.28:
                            buf[y, x] = c_hi
                        elif v < 0.36 and bg[y, x] < 0.36:
                            buf[y, x] = c_dk
                        else:
                            buf[y, x] = c_main


def _paint_moon_mirror_water(
    buf: np.ndarray,
    ctx: dict[str, Any],
    ramp: tuple[str, ...],
    foam_col: str,
    star_col: str,
    seed: int,
    bank_col: str = "night",
    shore_width: float = 3.2,
    cliff_skirt: bool = False,
) -> None:
    """Luminous starry moon-mirror water with smooth horizontal wave ripples,
    soft shoreline foam halo, twinkling constellation reflections, and optional cliff skirts."""
    mask = ctx["m_water"]
    if not np.any(mask):
        return
    H, W = ctx["H"], ctx["W"]
    xs, ys = ctx["xs"], ctx["ys"]
    ly, ts = ctx["ly"], ctx["ts"]
    bg = ctx["bg"]

    # Smooth stretched horizontal moonlit wave ripples
    rip1 = fbm_grid(H, W, 24.0, seed=seed + 301, octaves=2, sx=0.55, sy=1.75)
    rip2 = vnoise_grid(H, W, 12.0, seed=seed + 311)
    wave = 0.5 + 0.5 * np.sin(ys.astype(np.float32) * 0.42 + rip1 * 6.0)
    w_dist = chamfer_dist(mask)
    # Slightly brighter luminous shallow halo near shoals/shores
    shallow = np.clip(1.0 - w_dist / 16.0, 0.0, 1.0) * 0.22
    field = np.clip(rip1 * 0.52 + wave * 0.22 + rip2 * 0.14 + shallow, 0.0, 0.999)
    out = ramp_blend(ramp, field, bg)

    # Crisp horizontal moonlit specular wave dashes
    dash = (wave > 0.86) & (rip1 > 0.52) & (ys % 4 == 1) & (bg < 0.42)
    out = np.where(dash, IX[foam_col], out)

    # Reflected constellation stars (sparse, twinkling, never noisy)
    sh = hash01_grid(xs, ys, seed + 317)
    out = np.where((sh > 0.9945) & (w_dist > 3.0), IX[star_col], out)
    out = np.where((sh > 0.9985) & (w_dist > 5.0), IX["cream"], out)

    # Soft organic shoreline foam halo
    foam_band = (w_dist <= shore_width) & ((w_dist <= 1.2) | ((1.0 - w_dist / (shore_width + 0.5)) > bg * 1.15))
    out = np.where(foam_band, IX[foam_col], out)

    # Recessed north bank lip / hanging cliff skirt where north neighbor is land/wall
    if cliff_skirt:
        up_land = ctx["n_up_land"]
        skirt = up_land & (ly < 6)
        # Sculpted dark moon-slate cliff skirt dropping into the water
        stone_j = ((xs + (ly // 2) * 5) % 10) == 0
        out = np.where(skirt & (ly == 0), IX["dusk"], out)
        out = np.where(skirt & (ly >= 1) & (ly <= 3), np.where(stone_j, IX["void"], IX["deep"]), out)
        out = np.where(skirt & (ly == 4), IX["night"], out)
        out = np.where(skirt & (ly == 5), np.where(bg < 0.72, IX[foam_col], IX[ramp[-1]]), out)
    else:
        bank_n = ctx["n_up_land"] & (ly < 2)
        out = np.where(bank_n & (ly == 0), IX[bank_col], out)
        out = np.where(bank_n & (ly == 1) & (bg < 0.65), IX[foam_col], out)

    buf[mask] = out[mask]


def _paint_silver_arch_bridge(
    buf: np.ndarray,
    ctx: dict[str, Any],
    deck_ramp: tuple[str, ...],
    rail_col: str,
    stud_col: str,
    seam_col: str,
    west_stud_col: str | None = None,
) -> None:
    """Refined arched silver-stone causeway bridge (clean dressed pavers + sculpted parapet rails;
    ZERO checkerboard!)."""
    mask = ctx["m_bridge"]
    if not np.any(mask):
        return
    xs, ys = ctx["xs"], ctx["ys"]
    lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
    bg = ctx["bg"]
    nb = ctx["n_broad"]
    warm = ctx["warm"]

    # Determine bridge orientation via neighbors
    horiz = ctx["n_lt_bridge"] | ctx["n_rt_bridge"] | ((~ctx["n_up_bridge"]) & (~ctx["n_dn_bridge"]))
    paver_pos = np.where(horiz, xs, ys)
    cross_pos = np.where(horiz, ly, lx)

    # Smooth arched stone deck (slightly brighter along bridge crown)
    crown = 1.0 - np.abs(cross_pos.astype(np.float32) - (ts - 1) * 0.5) / max(1.0, ts * 0.55)
    field = np.clip(nb * 0.35 + crown * 0.45 + 0.14, 0.0, 0.999)
    out = ramp_blend(deck_ramp, field, bg)

    # Clean dressed stone transverse paver joints every 8px + staggered center joint
    t_seam = (paver_pos % 8 == 0) & (cross_pos >= 2) & (cross_pos <= ts - 3)
    c_seam = (cross_pos == ts // 2) & (((paver_pos // 8) & 1) == 0)
    out = np.where((t_seam | c_seam) & (bg < 0.72), IX[seam_col], out)
    # Subtle bevel along lit paver edge
    out = np.where((paver_pos % 8 == 1) & (cross_pos >= 3) & (cross_pos <= ts - 4) & (bg < 0.35), LIGHT_IX[out], out)

    # Parapet railings on exposed bridge sides
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
    # Sculpted baluster posts / glowing lantern studs every 16px along railings
    post = rail & ((paver_pos % 16) <= 1)
    if west_stud_col is not None:
        stud_ix = np.where(warm > 0.50, IX[west_stud_col], IX[stud_col])
        out = np.where(post, stud_ix, out)
    else:
        out = np.where(post, IX[stud_col], out)
    out = np.where(rail & ((paver_pos % 16) == 8), IX[seam_col], out)

    buf[mask] = out[mask]


def _paint_sconce_aprons(
    buf: np.ndarray,
    ctx: dict[str, Any],
    spacing: int = 24,
    phase: int = 0,
    reach_y: int = 7,
    reach_x: int = 8,
    col_hi: str = "gold",
    col_mid: str = "apricot",
    strength: float = 0.44,
) -> None:
    """Cast soft warm Bayer-dithered wall-sconce light aprons onto walkable floor tiles
    directly beneath interior south-facing walls."""
    m_walk = ctx["m_walk"]
    if not np.any(m_walk):
        return
    xs, ly = ctx["xs"], ctx["ly"]
    bg = ctx["bg"]
    # Distance to nearest sconce center along X
    dx = np.abs(((xs - phase + spacing // 2) % spacing) - spacing // 2).astype(np.float32)
    dy = ly.astype(np.float32)
    fall = np.clip(1.0 - np.hypot(dx / float(reach_x), dy / float(reach_y)), 0.0, 1.0)
    zone = m_walk & ctx["n_up_wall"] & (ly < reach_y) & (fall > 0.0)
    mid_m = zone & ((fall * strength) > bg)
    hi_m = zone & (ly <= 3) & ((fall * (strength * 0.65)) > bg)
    buf[mid_m] = IX[col_mid]
    buf[hi_m] = IX[col_hi]


def _paint_colonnade_walls(
    buf: np.ndarray,
    ctx: dict[str, Any],
    cap_ramp: tuple[str, ...],
    lip_col: str,
    face_col: str,
    pilaster_col: str,
    base_col: str,
    arch_bg: str,
    arch_mid: str,
    arch_hi: str,
    seed: int,
    bay_w: int = 24,
    sconce_col: str | None = "gold",
    cap_bias: float = 0.0,
) -> None:
    """Sculpted dark 3/4 colonnade walls with arched moon-glass alcoves/lancets,
    fluted pilasters, crisp cornice lip, and subtle sconce flames (clearly darker than floor!)."""
    mask = ctx["m_wall"] | ctx["m_foliage"]
    if not np.any(mask):
        return
    H, W = ctx["H"], ctx["W"]
    xs, ys = ctx["xs"], ctx["ys"]
    lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
    bg = ctx["bg"]
    nb = ctx["n_broad"]
    warm = ctx["warm"]

    up_open = ~ctx["n_up_wall"]
    dn_open = ~ctx["n_dn_wall"]
    lt_open = ~ctx["n_lt_wall"]
    rt_open = ~ctx["n_rt_wall"]

    # Calm sculpted dark masonry cap (NO high-contrast vertical zebra stripes!)
    cap_n = fbm_grid(H, W, 24.0, seed=seed + 201, octaves=2)
    wall_d = chamfer_dist(ctx["m_wall"])
    edge_lift = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.24
    cap_f = np.clip(cap_n * 0.62 + edge_lift + cap_bias, 0.0, 0.999)
    out = ramp_blend(cap_ramp, cap_f, bg)

    # Subtle architectural ashlar coursing on wall cap
    cap_seam = ((ly % 8 == 0) | (((lx + np.where(((ly // 8) & 1) == 1, 8, 0)) % 16) == 0)) & (bg < 0.42)
    out = np.where(cap_seam, SHADE_IX[out], out)

    # 7px sculpted south-facing colonnade face (skip bottom viewport border row)
    south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
    bay_x = xs % bay_w
    center_x = bay_w // 2
    dist_c = np.abs(bay_x - center_x)

    # Top cornice lip
    out = np.where(south & (ly == ts - 7), IX[lip_col], out)
    # Main dark masonry face
    out = np.where(south & (ly > ts - 7) & (ly < ts - 1), IX[face_col], out)

    # Projecting pilasters at bay_x in (0, 1, 2) and (bay_w - 1)
    pilaster = south & (ly > ts - 7) & (ly < ts - 1) & ((bay_x <= 2) | (bay_x == bay_w - 1))
    out = np.where(pilaster, IX[pilaster_col], out)
    out = np.where(south & (ly > ts - 7) & (ly < ts - 1) & (bay_x == 0), IX[base_col], out)
    out = np.where(south & (ly == ts - 6) & (bay_x == 1), IX[lip_col], out)

    # Arched lancet window / recessed mirror alcove centered in each bay
    # Arch spans ly = ts-5 .. ts-2, narrower at crown (ly == ts-5)
    in_arch = south & (
        ((ly == ts - 5) & (dist_c <= 2))
        | ((ly >= ts - 4) & (ly <= ts - 2) & (dist_c <= 3))
    )
    arch_frame = south & (
        ((ly == ts - 6) & (dist_c <= 2))
        | ((ly == ts - 5) & (dist_c == 3))
        | ((ly >= ts - 4) & (ly <= ts - 2) & (dist_c == 4))
    )
    out = np.where(arch_frame, IX[base_col], out)
    out = np.where(in_arch, IX[arch_bg], out)
    out = np.where(in_arch & (ly >= ts - 4) & (dist_c <= 2), IX[arch_mid], out)
    out = np.where(in_arch & (ly == ts - 4) & (dist_c <= 1), IX[arch_hi], out)
    # Vertical mullion glint inside lancet
    out = np.where(in_arch & (dist_c == 0) & (ly >= ts - 4) & (ly <= ts - 2), IX[arch_hi], out)

    # Optional tiny wall sconce jewel mounted on pilaster
    if sconce_col is not None:
        out = np.where(south & (bay_x == 1) & (ly == ts - 4), IX[sconce_col], out)
        out = np.where(south & (bay_x == 1) & (ly == ts - 3), IX["apricot"] if sconce_col == "gold" else IX[arch_hi], out)

    # Plinth shadow base
    out = np.where(south & (ly == ts - 1), IX[base_col], out)

    # Crisp north cap edge & directional WNW rim light / east shadow (skip top map border)
    out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), IX[lip_col], out)
    west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~(dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 6)))
    out = np.where(west_rim & (bg < 0.45 + 0.35 * warm), LIGHT_IX[out], out)
    out = np.where(west_rim & (warm < 0.25), COOL_IX[out], out)
    east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~(dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 6)))
    out = np.where(east_rim, IX[base_col], out)

    buf[mask] = out[mask]


# ------------------------------------------------------------------ ISLAND 7 PAINTERS
class MoonShoalsOverworldPainter(ThemePainter):
    """Island 7 Overworld — Moon Shoals:
    Luminous moonlit silver-blue shoal stone terraces (warm golden lantern-lit piers in west
    fading into moonlit blue-silver east), clearly darker sculpted moon-slate cliff/balustrade walls,
    hanging cliff skirts over reflective starry-moonlit water, and refined arched silver-stone bridges."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nm = ctx["n_med"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        s = self.spec

        # Calm dressed moon-shoal stone terraces (16x10 staggered slabs)
        sh, sw = 10, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 53)

        # Warm golden-lit west shoals transitioning to cool moonlit silver-blue east shoals (~88-95 luma)
        field = np.clip(nb * 0.48 + slab_h * 0.26 + nm * 0.14 + 0.02, 0.0, 0.999)
        cool_stone = ramp_blend(("deep", "deep", "blue", "mauve"), field, bg)
        warm_stone = ramp_blend(("dusk", "dusk", "plum", "mauve"), field, bg)
        out = np.where(warm > (0.46 + (nb - 0.5) * 0.24 + (bg - 0.5) * 0.18), warm_stone, cool_stone)

        # Subtle dressed terrace joints (soft Bayer-dithered, never noisy!)
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.58)
        out = np.where(is_seam, IX["deep"], out)
        # Delicate lit bevel on select slabs
        is_bev = (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.72) & (bg < 0.30)
        out = np.where(is_bev, np.where(warm > 0.52, IX["stone"], IX["sky"]), out)

        # Subtle moonlit shoal-edge frost near water
        near_water = ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
        out = np.where(near_water & (nb > 0.54) & (bg < 0.24), IX["sky"], out)
        # Rare tiny silver/gold shoal glint flecks
        out = np.where((nf > 0.996) & (nb > 0.50), np.where(warm > 0.55, IX["gold"], IX["ice"]), out)

        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]

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

        # Lantern-lit moon-stone promenade (warm plum/mauve west -> cool blue/mauve east, ~95 luma)
        pf = np.clip(nb * 0.45 + 0.24, 0.0, 0.999)
        p_warm = ramp_blend(("dusk", "plum", "mauve", "stone"), pf, bg)
        p_cool = ramp_blend(("deep", "blue", "mauve", "sky"), pf, bg)
        out = np.where(warm > (0.48 + (bg - 0.5) * 0.16), p_warm, p_cool)

        # Dressed flagstone promenade pavers
        row_id = ys // 8
        ox = np.where((row_id & 1) == 1, 8, 0)
        seam = ((ys % 8 == 0) | (((xs + ox) % 16) == 0)) & (bg < 0.62)
        out = np.where(seam, IX["deep"], out)
        # Subtle lantern-lit curb studs along promenade border
        stud_c = np.where(warm > 0.48, IX["gold"], IX["ice"])
        out = np.where(in_edge & (((xs + ys) % 8) == 0), stud_c, out)
        out = np.where(is_edge & (bg < 0.78), IX["night"], out)

        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_colonnade_walls(
            buf,
            ctx,
            cap_ramp=("void", "night", "deep", "dusk"),
            lip_col="sky",
            face_col="deep",
            pilaster_col="dusk",
            base_col="void",
            arch_bg="night",
            arch_mid="deep",
            arch_hi="blue",
            seed=self.spec.seed,
            bay_w=24,
            sconce_col="gold",
            cap_bias=-0.02,
        )

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_moon_mirror_water(
            buf,
            ctx,
            ramp=("deep", "blue", "blue", "sky"),
            foam_col="ice",
            star_col="ice",
            seed=self.spec.seed,
            bank_col="night",
            shore_width=3.6,
            cliff_skirt=True,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_silver_arch_bridge(
            buf,
            ctx,
            deck_ramp=("blue", "mauve", "mauve", "stone"),
            rail_col="ice",
            stud_col="ice",
            seam_col="deep",
            west_stud_col="gold",
        )

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Crisp luminous shoreline coping on walkable shoal tiles bordering water
        walk = ctx["m_walk"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        warm = ctx["warm"]

        rim_s = walk & ctx["n_dn_water"] & (ly == ts - 1)
        rim_n = walk & ctx["n_up_water"] & (ly == 0)
        rim_w = walk & ctx["n_lt_water"] & (lx == 0)
        rim_e = walk & ctx["n_rt_water"] & (lx == ts - 1)
        rim = rim_s | rim_n | rim_w | rim_e
        buf[rim] = np.where(((xs + ys) % 6 == 0), IX["ice"], IX["sky"])[rim]

        # Warm golden lantern-lit piers wash on western half near north walls & plazas
        _paint_sconce_aprons(buf, ctx, spacing=24, phase=1, reach_y=6, reach_x=7, col_hi="gold", col_mid="apricot", strength=0.38)
        # Subtle warm golden beacon haze on western pier paths
        west_pier = ctx["m_path"] & (warm > 0.58) & (ctx["n_broad"] > 0.62) & (bg < 0.16)
        buf[west_pier] = IX["gold"]


class MirrorSpirePainter(ThemePainter):
    """The Mirror Spire (spire_r1..r11, r14, r15):
    Calm silver-indigo mirror-cut flagstones (~88-94 luma) with quiet silver/gold geometric
    mirror-frames, clearly darker cathedral-mirror colonnade walls (~42-48 luma) with arched
    moon-glass lancet windows & warm candle-sconce floor aprons, and luminous starry mirror pools."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]
        s = self.spec

        # Precision 16x12 mirror-cut cathedral flagstones (~88-94 luma)
        sh, sw = 12, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 61)

        field = np.clip(nb * 0.44 + slab_h * 0.30 + warm * 0.08 + 0.12, 0.0, 0.999)
        out = ramp_blend(("deep", "deep", "blue", "mauve"), field, bg)

        # Crisp quiet mirror-cut mortar seams
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.72)
        out = np.where(is_seam, IX["deep"], out)
        # Delicate silver-sky bevel along top edge of select lit slabs
        is_bev = (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.65) & (bg < 0.34)
        out = np.where(is_bev, IX["sky"], out)

        # Quiet inlaid 48x36 architectural mirror-frame corner brackets (subtle geometric elegance)
        fx, fy = xs % 48, ys % 36
        corner_h = ((fy == 2) | (fy == 34)) & ((fx >= 2) & (fx <= 6) | (fx >= 42) & (fx <= 46))
        corner_v = ((fx == 2) | (fx == 46)) & ((fy >= 2) & (fy <= 6) | (fy >= 30) & (fy <= 34))
        out = np.where((corner_h | corner_v) & (bg < 0.56), IX["sky"], out)
        # Tiny gilded jewel pin at frame corner vertex
        vertex = ((fx == 2) | (fx == 46)) & ((fy == 2) | (fy == 34))
        out = np.where(vertex, IX["gold"], out)

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

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )

        # Ceremonial moon-glass cathedral nave runner (~94 luma)
        out = ramp_blend(("dusk", "blue", "mauve"), np.clip(nb * 0.45 + 0.28, 0.0, 0.999), bg)
        seam = ((ys % 8 == 0) | (((xs + np.where(((ys // 8) & 1) == 1, 8, 0)) % 16) == 0)) & (bg < 0.55)
        out = np.where(seam, IX["deep"], out)
        # Quiet inlaid silver/gold cathedral trim border
        out = np.where(in_edge & (((xs + ys) % 4) != 0), IX["sky"], out)
        out = np.where(in_edge & (((xs + ys) % 8) == 0), IX["gold"], out)
        out = np.where(is_edge, IX["night"], out)

        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_colonnade_walls(
            buf,
            ctx,
            cap_ramp=("void", "night", "deep"),
            lip_col="ice",
            face_col="night",
            pilaster_col="deep",
            base_col="void",
            arch_bg="deep",
            arch_mid="blue",
            arch_hi="sky",
            seed=self.spec.seed,
            bay_w=24,
            sconce_col="gold",
            cap_bias=0.04,
        )

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_moon_mirror_water(
            buf,
            ctx,
            ramp=("deep", "blue", "blue", "sky"),
            foam_col="ice",
            star_col="ice",
            seed=self.spec.seed,
            bank_col="night",
            shore_width=2.8,
        )

    def paint_pit(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_pit"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly = ctx["lx"], ctx["ly"]
        bg = ctx["bg"]
        s = self.spec

        # Deep luminous starry mirror-chasm with vertical silver-indigo cathedral reflections
        ref = fbm_grid(H, W, 24.0, seed=s.seed + 509, octaves=2, sx=2.2, sy=0.38)
        out = np.full((H, W), IX["void"], dtype=np.uint8)
        out = np.where((ref > 0.62) & (bg < 0.55), IX["deep"], np.where((ref > 0.44) & (bg < 0.50), IX["night"], out))
        sh = hash01_grid(xs, ys, s.seed + 517)
        out = np.where(sh > 0.9965, IX["ice"], np.where(sh > 0.992, IX["sky"], out))

        # Sculpted 5px recessed cathedral drop-wall along north land edge
        drop_n = ctx["n_up_land"] & (ly < 5)
        out = np.where(drop_n & (ly == 0), IX["blue"], out)
        out = np.where(drop_n & (ly > 0) & (ly < 4), np.where(((xs + (ly // 2) * 4) % 8 == 0), IX["void"], IX["deep"]), out)
        out = np.where(drop_n & (ly == 4), IX["void"], out)
        out = np.where(ctx["n_lt_land"] & (lx < 2) & (~drop_n), IX["night"], out)

        buf[mask] = out[mask]

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_silver_arch_bridge(
            buf,
            ctx,
            deck_ramp=("blue", "mauve", "mauve"),
            rail_col="ice",
            stud_col="gold",
            seam_col="deep",
        )

    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        _paint_plush_rug_decor(self, buf, ctx, decor_list, "dusk", "mauve", "gold", "night")

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Warm candle-sconce floor light aprons beneath colonnade piers
        _paint_sconce_aprons(buf, ctx, spacing=24, phase=1, reach_y=7, reach_x=8, col_hi="gold", col_mid="apricot", strength=0.40)


class InvertedPalaceSilverPainter(ThemePainter):
    """Inverted Palace (Silver World):
    Refined moonlit alabaster-blue/mauve-stone palace tiles (~98-104 luma — clearly brighter &
    silver-cool vs Black World's ~72, calm enough for effortless combat readability; ZERO diagonal
    scratch streaks!), clearly darker royal moon-slate marble colonnades (~46-52 luma) with arched
    mirror-alcoves & warm candelabra light aprons, and luminous reflective moon-mirror pools."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]
        s = self.spec

        # Soft-contrast 16x16 silver-alabaster parquet tiles (~98-104 luma, NO harsh white glare!)
        sz = 16
        tx_p, ty_p = xs // sz, ys // sz
        px_i, py_i = xs % sz, ys % sz
        chk = ((tx_p + ty_p) & 1) == 0
        th = hash01_grid(tx_p, ty_p, s.seed + 71)

        f_hi = np.clip(nb * 0.42 + th * 0.24 + warm * 0.08 + 0.04, 0.0, 0.999)
        f_lo = np.clip(nb * 0.42 + th * 0.24 + warm * 0.08 + 0.02, 0.0, 0.999)
        tile_hi = ramp_blend(("blue", "mauve", "mauve", "stone"), f_hi, bg)
        tile_lo = ramp_blend(("deep", "deep", "blue", "mauve"), f_lo, bg)
        out = np.where(chk, tile_hi, tile_lo)

        # Quiet Bayer-softened parquet grout seams
        seam = ((px_i == 0) | (py_i == 0)) & (bg < 0.70)
        out = np.where(seam, IX["deep"], out)

        # Subtle inset silver parquet corner glint (replaces loud diagonal white scratch streaks!)
        glint = chk & (th > 0.48) & (((px_i == 2) & (py_i >= 2) & (py_i <= 4)) | ((py_i == 2) & (px_i >= 2) & (px_i <= 4))) & (bg < 0.50)
        out = np.where(glint, IX["ice"], out)
        # Quiet silver-framed 32x32 courtyard inlay intersections with subtle gold center stud
        inter = (xs % 32 == 0) & (ys % 32 == 0)
        out = np.where(inter, IX["gold"], out)

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

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )

        # Refined silver-marble gallery runner (~102 luma)
        out = ramp_blend(("deep", "blue", "mauve", "stone"), np.clip(nb * 0.45 + 0.34, 0.0, 0.999), bg)
        seam = ((ys % 8 == 0) | (((xs + np.where(((ys // 8) & 1) == 1, 8, 0)) % 16) == 0)) & (bg < 0.58)
        out = np.where(seam, IX["deep"], out)
        out = np.where(in_edge & (((xs + ys) % 4) != 0), IX["ice"], out)
        out = np.where(in_edge & (((xs + ys) % 8) == 0), IX["gold"], out)
        out = np.where(is_edge, IX["deep"], out)

        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_colonnade_walls(
            buf,
            ctx,
            cap_ramp=("void", "night", "deep", "dusk"),
            lip_col="ice",
            face_col="deep",
            pilaster_col="blue",
            base_col="night",
            arch_bg="night",
            arch_mid="blue",
            arch_hi="sky",
            seed=self.spec.seed,
            bay_w=24,
            sconce_col="gold",
            cap_bias=0.10,
        )

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_moon_mirror_water(
            buf,
            ctx,
            ramp=("deep", "blue", "blue", "sky"),
            foam_col="ice",
            star_col="cream",
            seed=self.spec.seed,
            bank_col="deep",
            shore_width=2.8,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_silver_arch_bridge(
            buf,
            ctx,
            deck_ramp=("blue", "mauve", "stone"),
            rail_col="ice",
            stud_col="gold",
            seam_col="deep",
        )

    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        _paint_plush_rug_decor(self, buf, ctx, decor_list, "mauve", "stone", "gold", "deep")

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Subtle warm gold/apricot candelabra light aprons beneath north marble pilasters
        _paint_sconce_aprons(buf, ctx, spacing=24, phase=1, reach_y=7, reach_x=7, col_hi="gold", col_mid="apricot", strength=0.38)


class InvertedPalaceBlackPainter(ThemePainter):
    """Inverted Palace (Black World — spire_r16, spire_r17, and ALL *_black_world overlays!):
    Rich luminous obsidian-plum mirror flagstones (~70-75 luma — dramatically darker & moody-rose
    vs Silver World's ~101, ZERO diagonal scratch streaks!), deep obsidian-void pilasters (~30-35 luma)
    with carved rose-trimmed arched mirror frames & subtle rose/ice star-slit glints."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]
        s = self.spec

        # Rich obsidian-plum mirror flagstones (~70-75 luma)
        sz = 16
        tx_p, ty_p = xs // sz, ys // sz
        px_i, py_i = xs % sz, ys % sz
        chk = ((tx_p + ty_p) & 1) == 0
        th = hash01_grid(tx_p, ty_p, s.seed + 79)

        f_hi = np.clip(nb * 0.42 + th * 0.26 + warm * 0.08 + 0.18, 0.0, 0.999)
        f_lo = np.clip(nb * 0.42 + th * 0.26 + warm * 0.08 + 0.08, 0.0, 0.999)
        tile_hi = ramp_blend(("dusk", "plum", "plum", "wine"), f_hi, bg)
        tile_lo = ramp_blend(("dusk", "dusk", "plum", "plum"), f_lo, bg)
        out = np.where(chk, tile_hi, tile_lo)

        # Crisp dark obsidian tile seams
        seam = ((px_i == 0) | (py_i == 0)) & (bg < 0.72)
        out = np.where(seam, IX["night"], out)

        # Quiet inlaid rose/sky mirror-border corner L-brackets (replaces diagonal scratch streaks!)
        fx, fy = xs % 32, ys % 32
        br_h = ((fy == 2) | (fy == 30)) & ((fx >= 2) & (fx <= 4) | (fx >= 28) & (fx <= 30))
        br_v = ((fx == 2) | (fx == 30)) & ((fy >= 2) & (fy <= 4) | (fy >= 28) & (fy <= 30))
        out = np.where((br_h | br_v) & (bg < 0.56), IX["rose"], out)
        # Subtle sky/ice inverted starlight pinprick at 32x32 intersections
        inter = (xs % 32 == 0) & (ys % 32 == 0)
        out = np.where(inter, IX["ice"], out)
        # Rare soft sky hairline edge on select dark mirror tiles
        out = np.where((~chk) & (py_i == 1) & (px_i >= 4) & (px_i <= 11) & (th > 0.78) & (bg < 0.30), IX["sky"], out)

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

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )

        # Moody obsidian-plum gallery path with crisp rose trim (~76 luma)
        out = ramp_blend(("dusk", "plum", "wine"), np.clip(nb * 0.45 + 0.28, 0.0, 0.999), bg)
        seam = ((ys % 8 == 0) | (((xs + np.where(((ys // 8) & 1) == 1, 8, 0)) % 16) == 0)) & (bg < 0.62)
        out = np.where(seam, IX["night"], out)
        out = np.where(in_edge & (((xs + ys) % 4) != 0), IX["rose"], out)
        out = np.where(in_edge & (((xs + ys) % 8) == 0), IX["ice"], out)
        out = np.where(is_edge, IX["void"], out)

        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_colonnade_walls(
            buf,
            ctx,
            cap_ramp=("void", "void", "night", "dusk"),
            lip_col="rose",
            face_col="night",
            pilaster_col="dusk",
            base_col="void",
            arch_bg="void",
            arch_mid="dusk",
            arch_hi="rose",
            seed=self.spec.seed,
            bay_w=24,
            sconce_col="ice",
            cap_bias=-0.04,
        )

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_moon_mirror_water(
            buf,
            ctx,
            ramp=("void", "night", "dusk", "plum"),
            foam_col="rose",
            star_col="ice",
            seed=self.spec.seed,
            bank_col="void",
            shore_width=2.6,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_silver_arch_bridge(
            buf,
            ctx,
            deck_ramp=("dusk", "plum", "wine"),
            rail_col="rose",
            stud_col="ice",
            seam_col="void",
        )

    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        _paint_plush_rug_decor(self, buf, ctx, decor_list, "dusk", "plum", "rose", "void")

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Subtle cool-rose starlight floor glints directly beneath obsidian wall pilasters
        _paint_sconce_aprons(buf, ctx, spacing=24, phase=1, reach_y=5, reach_x=6, col_hi="rose", col_mid="plum", strength=0.34)


class TheatrePainter(ThemePainter):
    """Doppel Theatre (theatre_r1..r12, velvet_promenade, spire_r12):
    Calm satin candlelit mahogany stage planks (~82-86 luma), sumptuous pleated dark-velvet
    theater drapery walls (~38-45 luma) with gilded valance & candlelit box-seat niches, plush
    velvet aisle runners & rugs (ZERO diagonal scratch hatching!), and glowing brass footlights."""

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

        # Calm 8px wide satin candlelit mahogany stage planks (~82-85 luma)
        ph = 8
        pr = ys // ph
        py = ys % ph
        butt_off = (pr * 17) % 36
        px_b = (xs + butt_off) % 36
        plank_h = hash01_grid((xs + butt_off) // 36, pr, s.seed + 83)

        pf = np.clip(nb * 0.40 + plank_h * 0.24 + warm * 0.08 + 0.04, 0.0, 0.999)
        out = ramp_blend(("dusk", "plum", "plum", "wine"), pf, bg)

        # Soft Bayer-dithered plank seams (NO harsh black horizontal stripes!)
        h_seam = (py == 0) & (bg < 0.48)
        v_seam = (px_b == 0) & (py > 0) & (bg < 0.44)
        out = np.where(h_seam | v_seam, SHADE_IX[out], out)

        # Restrained satin bevel glint on select lit boards
        out = np.where((py == 1) & (px_b > 2) & (px_b < 33) & (plank_h > 0.78) & (bg < 0.26), IX["coral"], out)
        # Subtle muted wood peg near plank butt joints (calm, never bright yellow dots!)
        out = np.where((px_b == 3) & (py == 4) & (plank_h > 0.72), IX["dusk"], out)

        # Gentle warm stage-spotlight pool centered on the stage
        cx, cy = W * 0.5, H * 0.52
        dist_c = np.hypot((xs - cx) / max(1.0, W * 0.30), (ys - cy) / max(1.0, H * 0.34))
        spot = (dist_c < 1.0) & (py > 0) & (bg < (1.0 - dist_c) * 0.32)
        out = np.where(spot, LIGHT_IX[out], out)

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

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )

        # Plush velvet aisle runner (smooth Bayer pile in plum/wine — ZERO diagonal hatching!)
        out = ramp_blend(("plum", "wine", "wine"), np.clip(nb * 0.55 + 0.16, 0.0, 0.999), bg)
        # Understated woven gold diamond medallions spaced cleanly every 24px
        dm = (np.abs((xs % 24) - 12) + np.abs((ys % 24) - 12)) == 4
        out = np.where(dm & (bg < 0.72), IX["gold"], out)
        # Refined gilded border + dark velvet edge piping
        out = np.where(in_edge & (((xs + ys) % 4) != 0), IX["gold"], out)
        out = np.where(in_edge & (((xs + ys) % 4) == 0), IX["apricot"], out)
        out = np.where(is_edge, IX["night"], out)

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

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Sumptuous dark-velvet pleated drapery cap (~38-44 luma — smooth wide folds, NO zebra stripes!)
        fold_wave = 0.5 + 0.5 * np.sin(xs.astype(np.float32) * 0.52 + nb * 1.4)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_lift = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.16
        cap_f = np.clip(fold_wave * 0.62 + nb * 0.16 + edge_lift, 0.0, 0.999)
        out = ramp_blend(("void", "night", "night", "dusk"), cap_f, bg)

        # 7px sculpted south theater curtain / gilded box-seat face (skip bottom viewport border row)
        south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
        out = np.where(south & (ly == ts - 7), IX["gold"], out)  # gilded valance bar
        # Smooth shaded velvet drapery on south face
        face_velvet = ramp_blend(("night", "dusk", "plum", "wine"), np.clip(fold_wave * 0.68 + 0.10, 0.0, 0.999), bg)
        out = np.where(south & (ly > ts - 7) & (ly < ts - 1), face_velvet, out)

        # Arched gilded box-seat niches every 32px with warm candle glow
        bx = xs % 32
        dist_b = np.abs(bx - 16)
        in_box = south & (
            ((ly == ts - 5) & (dist_b <= 3))
            | ((ly >= ts - 4) & (ly <= ts - 2) & (dist_b <= 4))
        )
        box_frame = south & (
            ((ly == ts - 6) & (dist_b <= 3))
            | ((ly == ts - 5) & (dist_b == 4))
            | ((ly >= ts - 4) & (ly <= ts - 2) & (dist_b == 5))
        )
        out = np.where(box_frame, IX["gold"], out)
        out = np.where(in_box, IX["night"], out)
        # Warm candlelight inside box seat
        out = np.where(in_box & (ly >= ts - 4) & (ly <= ts - 3) & (dist_b <= 2), IX["wine"], out)
        out = np.where(in_box & (ly == ts - 4) & (dist_b <= 1), IX["coral"], out)
        out = np.where(in_box & (ly == ts - 4) & (dist_b == 0), IX["gold"], out)

        # Delicate scalloped gold fringe at curtain hem (outside box niches)
        out = np.where(south & (~in_box) & (ly == ts - 2) & ((xs % 6) < 2), IX["apricot"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        # Crisp gilded north edge & directional rim lighting (skip outer viewport edges)
        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), IX["gold"], out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~south)
        out = np.where(west_rim & (bg < 0.45 + 0.35 * warm), LIGHT_IX[out], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~south)
        out = np.where(east_rim, IX["void"], out)

        buf[mask] = out[mask]

    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        _paint_plush_rug_decor(self, buf, ctx, decor_list, "wine", "plum", "gold", "night")

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]

        # 1. Warm candlelight aprons beneath interior box-seat niches
        _paint_sconce_aprons(buf, ctx, spacing=32, phase=16, reach_y=7, reach_x=9, col_hi="gold", col_mid="apricot", strength=0.38)

        # 2. Glowing brass footlights along south stage edges casting soft warm light aprons onto stage boards
        s_edge = m_walk & ctx["n_dn_abyss"] & (ly >= ts - 3) & (ly <= ts - 2)
        lamp = s_edge & ((xs % 24) >= 10) & ((xs % 24) <= 13)
        buf[lamp] = IX["gold"]
        core = s_edge & ((xs % 24) >= 11) & ((xs % 24) <= 12) & (ly == ts - 3)
        buf[core] = IX["cream"]

        # Soft warm Bayer-dithered footlight apron radiating northward onto the stage planks
        dx_f = np.abs(((xs + 0) % 24) - 11.5).astype(np.float32)
        dy_f = ((ts - 3) - ly).astype(np.float32)
        apron_zone = m_walk & ctx["n_dn_abyss"] & (ly >= ts - 11) & (ly < ts - 3)
        fall = np.clip(1.0 - np.hypot(dx_f / 9.0, dy_f / 8.0), 0.0, 1.0)
        buf[apron_zone & ((fall * 0.44) > bg)] = IX["apricot"]
        buf[apron_zone & (dy_f <= 3.0) & ((fall * 0.34) > bg)] = IX["gold"]


class MasqueradePainter(ThemePainter):
    """The Masquerade (masq_r1..r4, glass_terrace, spire_r13):
    Refined moonlit ballroom diamond-parquet (~94-100 luma — down from blinding 144!),
    warm golden chandelier light pools, clearly darker royal ballroom colonnades (~46-52 luma)
    with arched tall windows & gilded cornices, and smooth plush ballroom runners."""

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

        # Refined 16px rotated ballroom diamond-parquet (~94-100 luma)
        u = (xs + ys) // 16
        v = (xs - ys) // 16
        chk = ((u + v) & 1) == 0
        dh = hash01_grid(u, v, s.seed + 91)

        f_hi = np.clip(nb * 0.40 + dh * 0.24 + warm * 0.08 + 0.14, 0.0, 0.999)
        f_lo = np.clip(nb * 0.40 + dh * 0.24 + warm * 0.08 + 0.08, 0.0, 0.999)
        d_hi = ramp_blend(("blue", "mauve", "mauve", "stone"), f_hi, bg)
        d_lo = ramp_blend(("deep", "dusk", "blue", "mauve"), f_lo, bg)
        out = np.where(chk, d_hi, d_lo)

        # Soft Bayer-dithered diamond grout (calm, zero visual buzz!)
        edge = (((xs + ys) % 16 == 0) | ((xs - ys) % 16 == 0)) & (bg < 0.56)
        out = np.where(edge, IX["deep"], out)

        # Delicate gilded vertex studs at alternate diamond corners
        stud = ((xs + ys) % 32 == 0) & ((xs - ys) % 32 == 0)
        out = np.where(stud, IX["gold"], out)

        # Warm golden chandelier light pools across ballroom floor
        cx, cy = W * 0.5, H * 0.50
        d1 = np.hypot((xs - cx) / max(1.0, W * 0.22), (ys - cy) / max(1.0, H * 0.28))
        d2 = np.hypot((xs - W * 0.25) / max(1.0, W * 0.16), (ys - cy) / max(1.0, H * 0.24))
        d3 = np.hypot((xs - W * 0.75) / max(1.0, W * 0.16), (ys - cy) / max(1.0, H * 0.24))
        pool = np.maximum(np.maximum(1.0 - d1, (1.0 - d2) * 0.72), (1.0 - d3) * 0.72)
        in_pool = (pool > 0.0) & (~edge)
        out = np.where(in_pool & ((pool * 0.24) > bg), IX["stone"], out)
        out = np.where(in_pool & (pool > 0.55) & (((pool - 0.50) * 0.34) > bg), IX["gold"], out)

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

        in_edge = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )

        # Royal mauve/plum ballroom runner with gilded border
        out = ramp_blend(("plum", "mauve", "mauve"), np.clip(nb * 0.45 + 0.26, 0.0, 0.999), bg)
        seam = ((ys % 8 == 0) | (((xs + np.where(((ys // 8) & 1) == 1, 8, 0)) % 16) == 0)) & (bg < 0.50)
        out = np.where(seam, IX["dusk"], out)
        out = np.where(in_edge & (((xs + ys) % 4) != 0), IX["gold"], out)
        out = np.where(is_edge, IX["deep"], out)

        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_colonnade_walls(
            buf,
            ctx,
            cap_ramp=("void", "night", "dusk", "deep"),
            lip_col="gold",
            face_col="night",
            pilaster_col="dusk",
            base_col="void",
            arch_bg="deep",
            arch_mid="blue",
            arch_hi="sky",
            seed=self.spec.seed,
            bay_w=24,
            sconce_col="gold",
            cap_bias=0.16,
        )

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_moon_mirror_water(
            buf,
            ctx,
            ramp=("deep", "blue", "blue", "sky"),
            foam_col="ice",
            star_col="ice",
            seed=self.spec.seed,
            bank_col="night",
            shore_width=2.8,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_silver_arch_bridge(
            buf,
            ctx,
            deck_ramp=("mauve", "mauve", "stone"),
            rail_col="gold",
            stud_col="cream",
            seam_col="dusk",
        )

    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        _paint_plush_rug_decor(self, buf, ctx, decor_list, "plum", "mauve", "gold", "night")

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Warm candle-sconce light washes onto ballroom floor beneath colonnade pilasters
        _paint_sconce_aprons(buf, ctx, spacing=24, phase=1, reach_y=7, reach_x=8, col_hi="gold", col_mid="apricot", strength=0.40)


class MoonShoalsCavePainter(ThemePainter):
    """Island 7 Caves (cave_echo_vault, cave_glass_crypt, cave_mirror_tide,
    cave_phase_trial, cave_twin_grotto):
    Calm subterranean moon-crystal grotto stone (~75-81 luma — down from blinding 156!),
    dark crystal-veined cavern walls (~35-41 luma) with glowing sky/ice quartz seams & warm
    cavern lantern pools, organic rock overhangs, and reflective sapphire/ice mirror-tide pools."""

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

        # Calm painterly moon-crystal grotto bedrock (~76-80 luma)
        warp_n = fbm_grid(H, W, 32.0, seed=s.seed + 163, octaves=3)
        strata = np.clip(nb * 0.46 + warp_n * 0.32 + warm * 0.05 - 0.04, 0.0, 0.999)
        out = ramp_blend(("deep", "deep", "blue", "mauve"), strata, bg)

        # Gentle bedrock fracture lines (low-contrast, calm floor)
        crack = (np.abs(warp_n - 0.48) < 0.011) & (nb < 0.56) & (bg < 0.72)
        out = np.where(crack, IX["night"], out)
        # Subtle pale quartz-crystal dust flecks along mineral strata
        out = np.where((np.abs(warp_n - 0.50) < 0.010) & (nb > 0.58) & (bg < 0.28), IX["sky"], out)
        out = np.where((nf > 0.996) & (warp_n > 0.56), IX["ice"], out)

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

        # Worn subterranean stone causeway (~80 luma)
        out = ramp_blend(("deep", "dusk", "blue", "mauve"), np.clip(nb * 0.45 + 0.26, 0.0, 0.999), bg)
        seam = ((ys % 8 == 0) | (((xs + np.where(((ys // 8) & 1) == 1, 8, 0)) % 16) == 0)) & (bg < 0.55)
        out = np.where(seam, IX["deep"], out)
        out = np.where(is_edge & (bg < 0.75), IX["night"], out)

        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        warm = ctx["warm"]
        s = self.spec

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        # Terraced dark cavern rock (~36-40 luma) with smooth chamfer depth falloff
        rock_n = fbm_grid(H, W, 26.0, seed=s.seed + 233, octaves=2)
        wall_d = chamfer_dist(ctx["m_wall"])
        edge_boost = np.clip(1.0 - wall_d / 18.0, 0.0, 1.0) * 0.42 - 0.06
        out = ramp_blend(("void", "night", "deep"), np.clip(rock_n * 0.62 + edge_boost + 0.14, 0.0, 0.999), bg)

        # Glowing sky/ice moon-quartz crystal veins embedded near cavern wall rims (skip outer borders)
        interior_wall = (ctx["ty"] < ctx["h_t"] - 1) & (ctx["ty"] > 0) & (ctx["tx"] > 0) & (ctx["tx"] < ctx["w_t"] - 1)
        vein_n = fbm_grid(H, W, 22.0, seed=s.seed + 241, octaves=2, sx=1.25, sy=0.75)
        vein = interior_wall & (np.abs(vein_n - 0.50) < 0.012) & (wall_d < 9.0)
        out = np.where(vein & (bg < 0.60), IX["sky"], out)
        out = np.where(interior_wall & (np.abs(vein_n - 0.50) < 0.004) & (wall_d < 7.0) & (bg < 0.45), IX["ice"], out)

        # 7px faceted south cavern cliff face (skip bottom viewport border row)
        south = dn_open & (ctx["ty"] < ctx["h_t"] - 1) & (ly >= ts - 7)
        lip_y = ts - 7 + np.where(rock_n > 0.52, 0, 1)
        out = np.where(south & (ly == lip_y), IX["sky"], out)
        facet = (xs + (ly // 2) * 3 + (rock_n * 4.0).astype(np.int32)) % 9
        face_c = np.where(
            facet == 0,
            IX["void"],
            np.where((facet == 1) & (ly < ts - 3), IX["blue"], IX["deep"]),
        )
        out = np.where(south & (ly > lip_y) & (ly < ts - 1), face_c, out)
        # Crystal seam glinting on south cliff face
        out = np.where(south & (ly > lip_y) & (ly < ts - 2) & (np.abs(vein_n - 0.50) < 0.016), IX["ice"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)

        # Directional cavern rim highlights (skip outer viewport edges)
        out = np.where(up_open & (ctx["ty"] > 0) & (ly == 0), IX["blue"], out)
        west_rim = lt_open & (ctx["tx"] > 0) & (lx == 0) & (~south)
        out = np.where(west_rim & (bg < 0.45 + 0.35 * warm), LIGHT_IX[out], out)
        east_rim = rt_open & (ctx["tx"] < ctx["w_t"] - 1) & (lx == ts - 1) & (~south)
        out = np.where(east_rim, IX["void"], out)

        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_moon_mirror_water(
            buf,
            ctx,
            ramp=("deep", "blue", "blue", "sky"),
            foam_col="ice",
            star_col="ice",
            seed=self.spec.seed,
            bank_col="void",
            shore_width=3.0,
        )

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_silver_arch_bridge(
            buf,
            ctx,
            deck_ramp=("dusk", "blue", "mauve"),
            rail_col="sky",
            stud_col="ice",
            seam_col="night",
        )

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        H, W = ctx["H"], ctx["W"]
        m_wall = ctx["m_wall"]
        bg = ctx["bg"]
        s = self.spec

        # 1. Organic curved cavern rock overhangs at concave corners (breaks boxy rectangles!)
        dist_w = chamfer_dist(~m_wall)
        ov_n = fbm_grid(H, W, 20.0, seed=s.seed + 601, octaves=2)
        n_adj = (
            ctx["n_up_wall"].astype(np.int32)
            + ctx["n_dn_wall"].astype(np.int32)
            + ctx["n_lt_wall"].astype(np.int32)
            + ctx["n_rt_wall"].astype(np.int32)
        )
        reach = np.where(n_adj >= 2, 5.5, 2.0)
        over = (~m_wall) & (ctx["m_walk"] | ctx["m_water"]) & (dist_w > 0.0) & (dist_w <= (ov_n - 0.32) * reach + np.where(n_adj >= 2, 2.2, 0.0))
        if np.any(over):
            buf[over] = np.where(dist_w <= 2.0, IX["night"], IX["deep"])[over]
            buf[over & (ov_n > 0.72) & (bg < 0.45)] = IX["sky"]

        # 2. Warm cavern lantern light aprons beneath interior south-facing walls
        _paint_sconce_aprons(buf, ctx, spacing=40, phase=20, reach_y=7, reach_x=8, col_hi="gold", col_mid="apricot", strength=0.34)


class ArchiveMemoryPainter(ThemePainter):
    """Archive of Lost Lamps: base library + optional island 1..8 memory-echo inlaid border strip."""

    def __init__(self, spec: ThemeSpec, echo_hi: str = "gold", echo_mid: str = "apricot") -> None:
        super().__init__(spec)
        self.echo_hi = echo_hi
        self.echo_mid = echo_mid

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Subtle memory-colored glowing rune inlay running 3px inside room perimeter walls
        m_walk = ctx["m_walk"]
        xs, ys = ctx["xs"], ctx["ys"]
        ly, ts = ctx["ly"], ctx["ts"]
        inlay_n = m_walk & ctx["n_up_wall"] & (ly == 5) & ((xs % 4) < 3)
        buf[inlay_n] = IX[self.echo_mid]
        buf[inlay_n & ((xs % 16) == 0)] = IX[self.echo_hi]


class WickHousePainter(ThemePainter):
    """Wick House Hub: warm golden hearth-glow wash radiating softly near the north-center wall."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        H, W = ctx["H"], ctx["W"]
        xs, ys, bg = ctx["xs"], ctx["ys"], ctx["bg"]
        cx, cy = W * 0.5, 42.0
        d = np.hypot((xs - cx) / 52.0, (ys - cy) / 34.0)
        glow = m_walk & (d < 1.0) & (((1.0 - d) * 0.42) > bg)
        buf[glow] = IX["gold"]


class TollHousePainter(ThemePainter):
    """The Toll House: gilded ledger counting-house brass trim, pit rim studs, and warm hearthpools."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        # Brass-ruled ledger border running along north wall bases with gold corner rivets
        rule_n = m_walk & ctx["n_up_wall"] & (ly == 5) & ((xs % 4) < 3)
        buf[rule_n] = IX["apricot"]
        buf[rule_n & ((xs % 16) == 0)] = IX["gold"]
        # Brass guardrail studs along south/north pit rims for crisp figure-ground contrast
        pit_s = m_walk & ctx["n_dn_abyss"] & (ly == ts - 3) & ((xs % 8) < 2)
        buf[pit_s] = IX["gold"]
        pit_n = m_walk & ctx["n_up_abyss"] & (ly == 2) & ((xs % 8) < 2)
        buf[pit_n] = IX["apricot"]
        # Subtle ledger column brass ticks on every 4th tile intersection
        tick = m_walk & (lx == 0) & (ly == 0) & (((xs // ts) % 3) == 0) & (((ys // ts) % 2) == 0)
        buf[tick] = IX["gold"]


class EndlessStairPainter(ThemePainter):
    """The Endless Stair: brass stair-rod highlights on treads and subtle starry rim shimmer."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
        # Brass stair-rod glints at tread risers
        rod = m_walk & (ly == 1) & ((xs % 12) == 2)
        buf[rod] = IX["gold"]
        # Rose-gold starlight coping along abyss drop-offs
        edge_s = m_walk & ctx["n_dn_abyss"] & (ly == ts - 2) & ((xs % 6) < 2)
        buf[edge_s] = IX["rose"]


class BellSanctumPainter(ThemePainter):
    """The Bell Sanctum: luminous obsidian-violet cathedral flagstones with gilded nave inlays."""

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
        # Ornate gilded nave border strip beneath north cathedral walls
        inlay_n = m_walk & ctx["n_up_wall"] & (ly == 5) & ((xs % 6) < 4)
        buf[inlay_n] = IX["rose"]
        buf[inlay_n & ((xs % 12) == 0)] = IX["gold"]
        # Gilded lip studs along cathedral chasm rims so void edges pop clearly
        rim_s = m_walk & ctx["n_dn_abyss"] & (ly == ts - 2) & ((xs % 8) < 3)
        buf[rim_s] = IX["gold"]
        rim_n = m_walk & ctx["n_up_abyss"] & (ly == 2) & ((xs % 8) < 3)
        buf[rim_n] = IX["rose"]


SPECS_7_8: list[tuple[ThemeSpec, type[ThemePainter]]] = [
    (
        ThemeSpec(
            id="moon_shoals_overworld",
            name="Moon Shoals (Overworld)",
            island=7,
            floor_style="moon_shoals",
            floor_ramp=("deep", "blue", "mauve"),
            floor_seam="deep",
            floor_bevel="sky",
            floor_accent_a="gold",
            floor_accent_b="ice",
            path_style="inlaid_strip",
            path_main="mauve",
            path_hi="stone",
            path_edge="night",
            path_trim="gold",
            wall_style="marble_balustrade",
            wall_cap=("void", "night", "deep"),
            wall_lip="sky",
            wall_face="deep",
            wall_face_hi="blue",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="mirror_void",
            rim_hi="ice",
            rim_mid="sky",
            bridge_style="stone_arch",
            bridge_main="blue",
            bridge_hi="mauve",
            bridge_rail="ice",
            bridge_dark="deep",
            glass_main="sky",
            glass_hi="ice",
            glass_frame="gold",
            seed=701,
            prop_sheet="island7_scenery",
            door_sheet="island7_doors",
            special_tiles=("G:glass", "D:carpet"),
            default_decor=("circle", "light_shaft"),
            notes="Moon Shoals Overworld: luminous moonlit silver-blue stone terraces, warm golden western piers, dark sculpted moon-slate cliffs over starry moonlit water.",
        ),
        MoonShoalsOverworldPainter,
    ),
    (
        ThemeSpec(
            id="mirror_spire",
            name="The Mirror Spire",
            island=7,
            floor_style="mirror_spire",
            floor_ramp=("deep", "blue", "mauve"),
            floor_seam="deep",
            floor_bevel="sky",
            floor_accent_a="sky",
            floor_accent_b="gold",
            path_style="inlaid_strip",
            path_main="blue",
            path_hi="mauve",
            path_edge="night",
            path_trim="gold",
            wall_style="marble_balustrade",
            wall_cap=("void", "night", "deep"),
            wall_lip="ice",
            wall_face="night",
            wall_face_hi="blue",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="mirror_void",
            rim_hi="ice",
            rim_mid="gold",
            bridge_style="stone_arch",
            bridge_main="blue",
            bridge_hi="mauve",
            bridge_rail="ice",
            bridge_dark="deep",
            glass_main="sky",
            glass_hi="ice",
            glass_frame="gold",
            seed=707,
            prop_sheet="island7_scenery",
            door_sheet="island7_doors",
            special_tiles=("G:glass", "D:carpet"),
            default_decor=("circle", "light_shaft"),
            notes="Flagship Mirror Spire: silver-indigo mirror-cut flagstones, dark cathedral-mirror colonnades with moon-glass lancets & warm sconce aprons, starry mirror pools.",
        ),
        MirrorSpirePainter,
    ),
    (
        ThemeSpec(
            id="inverted_palace_silver",
            name="Inverted Palace (Silver World)",
            island=7,
            floor_style="palace_silver",
            floor_ramp=("deep", "blue", "mauve", "stone"),
            floor_seam="deep",
            floor_bevel="ice",
            floor_accent_a="sky",
            floor_accent_b="gold",
            path_style="inlaid_strip",
            path_main="blue",
            path_hi="mauve",
            path_edge="deep",
            path_trim="ice",
            wall_style="marble_balustrade",
            wall_cap=("void", "night", "deep"),
            wall_lip="ice",
            wall_face="deep",
            wall_face_hi="blue",
            wall_base="night",
            water_style="moon_mirror",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="mirror_void",
            rim_hi="cream",
            rim_mid="ice",
            bridge_style="stone_arch",
            bridge_main="blue",
            bridge_hi="mauve",
            bridge_rail="ice",
            bridge_dark="deep",
            glass_main="sky",
            glass_hi="ice",
            glass_frame="gold",
            seed=711,
            prop_sheet="theme_inverted_palace_silver",
            door_sheet="theme_inverted_palace_silver_doors",
            special_tiles=("G:glass", "D:carpet"),
            default_decor=("circle", "light_shaft"),
            notes="Moon Shoals Silver World: refined moonlit alabaster-blue/mauve parquet, dark royal moon-slate colonnades with arched mirror-alcoves & warm candelabra aprons.",
        ),
        InvertedPalaceSilverPainter,
    ),
    (
        ThemeSpec(
            id="inverted_palace_black",
            name="Inverted Palace (Black World)",
            island=7,
            floor_style="palace_black",
            floor_ramp=("dusk", "plum", "wine"),
            floor_seam="night",
            floor_bevel="rose",
            floor_accent_a="sky",
            floor_accent_b="ice",
            path_style="inlaid_strip",
            path_main="dusk",
            path_hi="plum",
            path_edge="void",
            path_trim="rose",
            wall_style="marble_balustrade",
            wall_cap=("void", "night", "dusk"),
            wall_lip="rose",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="void",
            water_mid="night",
            water_hi="dusk",
            water_foam="rose",
            pit_style="star_chasm",
            void_style="mirror_void",
            rim_hi="rose",
            rim_mid="ice",
            bridge_style="stone_arch",
            bridge_main="dusk",
            bridge_hi="plum",
            bridge_rail="rose",
            bridge_dark="void",
            glass_main="plum",
            glass_hi="rose",
            glass_frame="ice",
            seed=719,
            prop_sheet="theme_inverted_palace_black",
            door_sheet="theme_inverted_palace_black_doors",
            special_tiles=("G:glass", "D:carpet"),
            default_decor=("circle", "cracks"),
            notes="Moon Shoals Black World: rich obsidian-plum mirror flagstones with rose-gold/ice inlaid corners, deep obsidian-void pilasters with rose-trimmed arched mirror frames.",
        ),
        InvertedPalaceBlackPainter,
    ),
    (
        ThemeSpec(
            id="doppel_theatre",
            name="The Doppel Theatre",
            island=7,
            floor_style="theatre_stage",
            floor_ramp=("dusk", "plum", "wine"),
            floor_seam="night",
            floor_bevel="coral",
            floor_accent_a="gold",
            floor_accent_b="apricot",
            path_style="carpet_runner",
            path_main="wine",
            path_hi="plum",
            path_edge="night",
            path_trim="gold",
            wall_style="velvet_curtain",
            wall_cap=("void", "night", "plum"),
            wall_lip="gold",
            wall_face="dusk",
            wall_face_hi="plum",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="void",
            water_mid="night",
            water_hi="deep",
            water_foam="sky",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="gold",
            rim_mid="apricot",
            bridge_style="timber",
            bridge_main="plum",
            bridge_hi="wine",
            bridge_rail="gold",
            bridge_dark="night",
            seed=721,
            prop_sheet="theme_doppel_theatre",
            door_sheet="theme_doppel_theatre_doors",
            special_tiles=("D:carpet",),
            default_decor=("circle", "rug", "light_shaft"),
            notes="Five-act gothic stage: satin mahogany floorboards, plush velvet runners, pleated dark-velvet drapery with gilded candlelit box-seats, glowing brass footlight aprons.",
        ),
        TheatrePainter,
    ),
    (
        ThemeSpec(
            id="masquerade",
            name="The Masquerade",
            island=7,
            floor_style="ballroom_diamond",
            floor_ramp=("deep", "blue", "mauve", "stone"),
            floor_seam="deep",
            floor_bevel="stone",
            floor_accent_a="gold",
            floor_accent_b="rose",
            path_style="inlaid_strip",
            path_main="plum",
            path_hi="mauve",
            path_edge="deep",
            path_trim="gold",
            wall_style="marble_balustrade",
            wall_cap=("void", "night", "dusk"),
            wall_lip="gold",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="mirror_void",
            rim_hi="ice",
            rim_mid="gold",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=731,
            prop_sheet="theme_masquerade",
            door_sheet="theme_masquerade_doors",
            special_tiles=("G:glass", "D:carpet"),
            default_decor=("circle", "light_shaft", "rug"),
            notes="Grand mirrored ballroom: calm moonlit diamond-parquet with warm chandelier pools, dark royal colonnades with arched tall windows & candle-sconce light washes.",
        ),
        MasqueradePainter,
    ),
    (
        ThemeSpec(
            id="moon_shoals_cave",
            name="Moon Shoals Grotto",
            island=7,
            floor_style="cave_floor",
            floor_ramp=("deep", "blue", "mauve"),
            floor_seam="night",
            floor_bevel="sky",
            floor_accent_a="sky",
            floor_accent_b="ice",
            path_style="sand_trail",
            path_main="dusk",
            path_hi="blue",
            path_edge="night",
            path_trim="sky",
            wall_style="cavern_rock",
            wall_cap=("void", "night", "deep"),
            wall_lip="sky",
            wall_face="deep",
            wall_face_hi="blue",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="mirror_void",
            rim_hi="ice",
            rim_mid="sky",
            bridge_style="stone_arch",
            bridge_main="dusk",
            bridge_hi="blue",
            bridge_rail="sky",
            bridge_dark="night",
            seed=741,
            prop_sheet="theme_cave_7",
            door_sheet="theme_cave_7_doors",
            special_tiles=("G:glass",),
            default_decor=("circle", "cracks"),
            notes="Subterranean moon-crystal grottoes: calm deep/blue/mauve cavern stone, dark crystal-veined walls with glowing quartz seams, organic overhangs & reflective sapphire pools.",
        ),
        MoonShoalsCavePainter,
    ),
    (
        ThemeSpec(
            id="toll_house",
            name="The Toll House",
            island=8,
            floor_style="ledger_stone",
            floor_ramp=("dusk", "plum", "mauve", "stone"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="apricot",
            floor_accent_b="gold",
            path_style="carpet_runner",
            path_main="wine",
            path_hi="rose",
            path_edge="night",
            path_trim="gold",
            wall_style="wainscot",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="gold",
            wall_face="plum",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="void",
            water_mid="night",
            water_hi="dusk",
            water_foam="rose",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="gold",
            rim_mid="apricot",
            bridge_style="stone_arch",
            bridge_main="plum",
            bridge_hi="mauve",
            bridge_rail="gold",
            bridge_dark="night",
            seed=811,
            prop_sheet="theme_toll_house",
            door_sheet="theme_toll_house_doors",
            special_tiles=("D:carpet",),
            default_decor=("inlay", "rug", "circle"),
            notes="The settings menu as architecture: gilded ledger-ruled stone floor, plum wainscot, crimson-gold runner.",
        ),
        TollHousePainter,
    ),
    (
        ThemeSpec(
            id="endless_stair",
            name="The Endless Stair",
            island=8,
            floor_style="stepped_stair",
            floor_ramp=("dusk", "plum", "mauve", "stone"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="gold",
            floor_accent_b="rose",
            path_style="carpet_runner",
            path_main="wine",
            path_hi="rose",
            path_edge="night",
            path_trim="gold",
            wall_style="masonry",
            wall_cap=("night", "dusk", "mauve"),
            wall_lip="rose",
            wall_face="dusk",
            wall_face_hi="plum",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="void",
            water_mid="night",
            water_hi="deep",
            water_foam="sky",
            pit_style="star_chasm",
            void_style="starry_cosmos",
            rim_hi="rose",
            rim_mid="gold",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=831,
            prop_sheet="theme_endless_stair",
            door_sheet="theme_endless_stair_doors",
            special_tiles=("S:stairs", "D:carpet"),
            default_decor=("circle", "inlay"),
            notes="Twelve-floor spiral ascent: stepped masonry treads with brass stair rods over bottomless star-void.",
        ),
        EndlessStairPainter,
    ),
    (
        ThemeSpec(
            id="bell_sanctum",
            name="The Bell Sanctum",
            island=8,
            floor_style="flagstone_crypt",
            floor_ramp=("dusk", "plum", "mauve", "stone"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="rose",
            floor_accent_b="gold",
            path_style="carpet_runner",
            path_main="wine",
            path_hi="rose",
            path_edge="night",
            path_trim="gold",
            wall_style="masonry",
            wall_cap=("night", "dusk", "plum"),
            wall_lip="gold",
            wall_face="dusk",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="void",
            water_mid="night",
            water_hi="deep",
            water_foam="rose",
            pit_style="star_chasm",
            void_style="starry_cosmos",
            rim_hi="gold",
            rim_mid="rose",
            bridge_style="stone_arch",
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="gold",
            bridge_dark="dusk",
            seed=841,
            prop_sheet="island8_scenery",
            door_sheet="island8_doors",
            special_tiles=("D:carpet",),
            default_decor=("circle", "rug", "inlay"),
            notes="Luminous obsidian-violet cathedral sanctum with gilded nave inlays, crimson choir carpets, and starry abyss chasms.",
        ),
        BellSanctumPainter,
    ),
    (
        ThemeSpec(
            id="wick_house",
            name="The Wick House (Hub)",
            island=1,
            floor_style="cottage_hearth",
            floor_ramp=("plum", "wine", "coral"),
            floor_seam="night",
            floor_bevel="apricot",
            floor_accent_a="gold",
            floor_accent_b="cream",
            path_style="boardwalk",
            path_main="mauve",
            path_hi="stone",
            path_edge="plum",
            path_trim="gold",
            wall_style="wainscot",
            wall_cap=("plum", "mauve", "stone"),
            wall_lip="gold",
            wall_face="wine",
            wall_face_hi="apricot",
            wall_base="night",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="sunset_void",
            rim_hi="gold",
            rim_mid="apricot",
            bridge_style="timber",
            bridge_main="coral",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="plum",
            seed=901,
            prop_sheet="theme_wick_house",
            door_sheet="theme_wick_house_doors",
            special_tiles=("D:carpet", "H:hearth"),
            default_decor=("rug", "light_shaft", "window_strip"),
            notes="Cozy lamplit cottage hub on a rock between islands: honey-wood planks, braided hearth rug, warm sunset void.",
        ),
        WickHousePainter,
    ),
]


# ------------------------------------------------------------------ ARCHIVE + 8 MEMORY VARIANTS
_ARCHIVE_MEMORIES: list[tuple[int, str, tuple[str, ...], str, str, str, str]] = [
    # (island, label, floor_ramp, path_main, path_trim, echo_mid, echo_hi)
    (1, "Bell Isle Memory", ("dusk", "mauve", "stone"), "plum", "gold", "jade", "gold"),
    (2, "Tidewater Memory", ("deep", "blue", "mauve"), "deep", "ice", "sky", "ice"),
    (3, "Thornwood Memory", ("pine", "teal", "mauve"), "pine", "lime", "jade", "lime"),
    (4, "Mirefen Memory", ("pine", "teal", "stone"), "teal", "rose", "sky", "rose"),
    (5, "Starfall Memory", ("deep", "blue", "dusk"), "deep", "gold", "blue", "gold"),
    (6, "Ashen Kiln Memory", ("dusk", "plum", "wine"), "wine", "apricot", "coral", "gold"),
    (7, "Moon Shoals Memory", ("deep", "blue", "sky"), "blue", "ice", "sky", "cream"),
    (8, "Long Night Memory", ("dusk", "plum", "mauve"), "plum", "rose", "wine", "rose"),
]


def build_archive_painters() -> list[tuple[ThemeSpec, ThemePainter]]:
    out: list[tuple[ThemeSpec, ThemePainter]] = []
    # Base archive
    base_spec = ThemeSpec(
        id="archive",
        name="The Archive of Lost Lamps",
        island=8,
        floor_style="archive_parquet",
        floor_ramp=("dusk", "plum", "mauve"),
        floor_seam="night",
        floor_bevel="stone",
        floor_accent_a="apricot",
        floor_accent_b="gold",
        path_style="carpet_runner",
        path_main="wine",
        path_hi="rose",
        path_edge="night",
        path_trim="gold",
        wall_style="bookshelf",
        wall_cap=("night", "plum", "wine"),
        wall_lip="gold",
        wall_face="plum",
        wall_face_hi="apricot",
        wall_base="void",
        water_style="moon_mirror",
        water_deep="void",
        water_mid="night",
        water_hi="deep",
        water_foam="sky",
        pit_style="star_chasm",
        void_style="crypt_abyss",
        rim_hi="gold",
        rim_mid="mauve",
        bridge_style="timber",
        bridge_main="plum",
        bridge_hi="apricot",
        bridge_rail="gold",
        bridge_dark="night",
        seed=820,
        prop_sheet="theme_archive",
        door_sheet="theme_archive_doors",
        special_tiles=("D:carpet",),
        default_decor=("rug", "circle", "light_shaft"),
        notes="Archive of Lost Lamps main hall: leather-bound bookshelf walls, scholarly wood flooring, warm reading light.",
    )
    out.append((base_spec, ArchiveMemoryPainter(base_spec, "gold", "apricot")))

    for isl, label, framp, pmain, ptrim, emid, ehi in _ARCHIVE_MEMORIES:
        mspec = ThemeSpec(
            id=f"archive_{isl}",
            name=f"Archive: {label}",
            island=8,
            floor_style="archive_parquet",
            floor_ramp=framp,
            floor_seam="night",
            floor_bevel="stone" if isl != 7 else "ice",
            floor_accent_a=emid,
            floor_accent_b=ehi,
            path_style="carpet_runner",
            path_main=pmain,
            path_hi=emid,
            path_edge="night",
            path_trim=ptrim,
            wall_style="bookshelf",
            wall_cap=("night", "dusk", "plum"),
            wall_lip=ehi,
            wall_face="plum",
            wall_face_hi=emid,
            wall_base="void",
            water_style="magma_river" if isl == 6 else ("koi_pond" if isl == 4 else "moon_mirror"),
            water_deep="wine" if isl == 6 else "deep",
            water_mid="coral" if isl == 6 else "blue",
            water_hi="apricot" if isl == 6 else emid,
            water_foam="gold" if isl == 6 else ehi,
            pit_style="lava_pit" if isl == 6 else "star_chasm",
            void_style="starry_cosmos" if isl in (5, 7, 8) else "crypt_abyss",
            rim_hi=ehi,
            rim_mid=emid,
            bridge_style="iron_grate" if isl == 6 else "timber",
            bridge_main=pmain,
            bridge_hi=emid,
            bridge_rail=ehi,
            bridge_dark="night",
            seed=820 + isl,
            prop_sheet="theme_archive",
            door_sheet="theme_archive_doors",
            special_tiles=("D:carpet",),
            default_decor=("rug", "circle", "light_shaft"),
            notes=f"Archive memory wing echoing Island {isl} ({label}): bookshelf walls + {emid}/{ehi} memory inlay.",
        )
        out.append((mspec, ArchiveMemoryPainter(mspec, ehi, emid)))
    return out
