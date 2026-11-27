"""Islands 5 & 6 themes: orrery, meteor_vault, planetarium, freefall, starfall_geode, starfall_overworld, ember_express (interior+roof), iron_colossus, forge_deep."""
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
)


def _paint_star_water(buf: np.ndarray, ctx: dict[str, Any], seed: int) -> None:
    """Island 5 luminous teal-cyan starlit water: distinct hue from indigo stone & void pits."""
    mask = ctx["m_water"]
    if not np.any(mask):
        return
    xs, ys = ctx["xs"], ctx["ys"]
    lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
    bg = ctx["bg"]
    H, W = ctx["H"], ctx["W"]

    rip = fbm_grid(H, W, 18.0, seed=seed + 313, octaves=2, sx=0.85, sy=1.35)
    # Distinct pine -> teal -> sky starlit pool ramp (~88-104 luma)
    out = ramp_blend(("pine", "teal", "teal", "sky"), np.clip(rip * 0.85 + 0.08, 0.0, 0.99), bg)
    # Crisp horizontal shimmer dashes
    dash = (rip > 0.68) & ((ys % 4) == 1) & (bg < 0.55)
    out = np.where(dash, IX["sky"], out)
    # Reflected celestial stars on calm dark pockets
    sh = hash01_grid(xs, ys, seed + 317)
    out = np.where(sh > 0.994, IX["cream"], np.where(sh > 0.989, IX["gold"], out))
    # Luminous ice/sky shoreline foam rim
    shore = (
        ((lx < 2) & ctx["n_lt_land"])
        | ((ly < 2) & ctx["n_up_land"])
        | ((lx >= ts - 2) & ctx["n_rt_land"])
        | ((ly >= ts - 2) & ctx["n_dn_land"])
    )
    out = np.where(shore, np.where(bg < 0.62, IX["ice"], IX["sky"]), out)
    # Subtle dark bank shadow at very top pixel under land
    out = np.where(ctx["n_up_land"] & (ly == 0) & (bg < 0.55), IX["night"], out)
    buf[mask] = out[mask]


def _paint_observatory_inlaid_path(
    buf: np.ndarray,
    ctx: dict[str, Any],
    main_c: str,
    hi_c: str,
    seam_c: str,
    trim_c: str,
    seed: int,
) -> None:
    """Refined brass-inlaid ashlar observatory causeway (calm stone curbing, zero harsh dashed boxes)."""
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

    in_n = (~ctx["n_up_path"]) & (ly == 1)
    in_s = (~ctx["n_dn_path"]) & (ly == ts - 2)
    in_w = (~ctx["n_lt_path"]) & (lx == 1)
    in_e = (~ctx["n_rt_path"]) & (lx == ts - 2)
    is_inner = (in_n | in_s | in_w | in_e) & (~is_edge)
    is_corner = (in_n | in_s) & (in_w | in_e)

    # Dressed staggered ashlar slabs (16x8)
    row_id = ys // 8
    ox = np.where((row_id & 1) == 1, 8, 0)
    sx = (xs + ox) % 16
    sy = ys % 8
    slab_h = hash01_grid((xs + ox) // 16, row_id, seed)
    field = np.clip(nb * 0.36 + slab_h * 0.24 + 0.24, 0.08, 0.86)
    out = ramp_blend((seam_c, main_c, main_c, hi_c), field, bg)

    # Soft Bayer-dithered ashlar seams & quiet top catchlight
    seam = ((sx == 0) | (sy == 0)) & (bg < 0.44)
    out = np.where(seam, IX["night"], out)
    bev = (sy == 1) & (sx > 1) & (sx < 14) & (slab_h > 0.68) & (bg < 0.28)
    out = np.where(bev, IX[hi_c], out)

    # Refined recessed curbstone & delicate inlaid brass rivets (never loud 67% dashed neon border)
    coping = is_inner & (bg < 0.46)
    out = np.where(coping, IX[hi_c], out)
    brass_tick = is_inner & (is_corner | (((xs + ys) % 8) == 0))
    out = np.where(brass_tick, IX[trim_c], out)
    out = np.where(is_edge, np.where(bg < 0.76, IX["night"], IX[seam_c]), out)

    # Quiet brass inlay alignment stud along wide walkway interiors
    stud = (~is_edge) & (~is_inner) & (lx == 8) & (ly == 4) & (slab_h > 0.52)
    out = np.where(stud, IX[trim_c], out)
    buf[mask] = out[mask]


def _paint_observatory_balustrade_walls(buf: np.ndarray, ctx: dict[str, Any], mode: str) -> None:
    """Vaulted celestial-dome masonry walls for Planetarium & Freefall (replaces flat pinstripe balustrade)."""
    mask = ctx["m_wall"] | ctx["m_foliage"]
    if not np.any(mask):
        return
    s = self_spec = ctx.get("_spec")  # unused; read colors by mode below
    _ = s, self_spec
    xs, ys = ctx["xs"], ctx["ys"]
    lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
    bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]

    up_open = ~ctx["n_up_wall"]
    dn_open = ~ctx["n_dn_wall"]
    lt_open = ~ctx["n_lt_wall"]
    rt_open = ~ctx["n_rt_wall"]

    wall_d = chamfer_dist(ctx["m_wall"])
    edge_boost = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.36

    if mode == "planetarium":
        cap_ramp = ("void", "night", "deep")
        north_lip = IX["blue"]
        south_lip = IX["blue"]
        face_c = IX["night"]
        face_hi = IX["deep"]
        pil_sp = 32
        west_c = IX["blue"]
    else:
        # freefall weathered twilight-marble parapets
        cap_ramp = ("void", "night", "dusk")
        north_lip = IX["mauve"]
        south_lip = IX["dusk"]
        face_c = IX["night"]
        face_hi = IX["dusk"]
        pil_sp = 28
        west_c = IX["mauve"]

    # Smooth dressed masonry cap with depth shading toward wall interior
    out = ramp_blend(cap_ramp, np.clip(nb * 0.50 + edge_boost + 0.08, 0.0, 0.92), bg)
    row_id = ys // 8
    ox = np.where((row_id & 1) == 1, 8, 0)
    cap_seam = (((xs + ox) % 16 == 0) | (ys % 8 == 0)) & (bg < 0.42)
    out = np.where(cap_seam, IX["void"], out)

    # South-facing 6px sculpted architectural facade
    south = dn_open & (ly >= ts - 6)
    out = np.where(south & (ly == ts - 6), south_lip, out)
    out = np.where(south & (ly > ts - 6) & (ly < ts - 1), face_c, out)
    # Subtle horizontal molding course & ashlar joints on facade
    out = np.where(south & (ly == ts - 4) & ((xs % 8) < 6) & (bg < 0.55), face_hi, out)
    out = np.where(south & (ly == ts - 3) & ((xs % 16) == 0), IX["void"], out)
    out = np.where(south & (ly == ts - 1), IX["void"], out)

    # Crisp north cornice (calm stone edge + gilded capitals only at pilaster intervals)
    pil_cap = (xs % pil_sp) <= 1
    out = np.where(up_open & (ly == 0), np.where(pil_cap, IX["apricot"], north_lip), out)
    # Lit WNW west rim & shaded east rim
    west_rim = lt_open & (lx == 0) & (~(dn_open & (ly >= ts - 5)))
    out = np.where(west_rim & (bg < 0.55 + 0.35 * warm), west_c, out)
    out = np.where(west_rim & (warm < 0.25) & (bg < 0.45), COOL_IX[out], out)
    east_rim = rt_open & (lx == ts - 1) & (~(dn_open & (ly >= ts - 5)))
    out = np.where(east_rim, IX["void"], out)

    buf[mask] = out[mask]


def _paint_sconce_light_aprons(
    buf: np.ndarray,
    ctx: dict[str, Any],
    spacing: int,
    center_x: int,
    radius: float = 14.0,
) -> None:
    """Paint warm Last Light brass wall sconces & Bayer-dithered golden-apricot floor light aprons."""
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
    sx_mod = xs % spacing
    dx = np.minimum(np.abs(sx_mod - center_x), spacing - np.abs(sx_mod - center_x))

    # Avoid clipping a sconce fixture onto the extreme 2px edge of a floating pillar
    wall_ok = m_wall & dn_open & dn_walk & (~(lt_open & (lx < 2))) & (~(rt_open & (lx >= ts - 2)))

    # 1) Brass lantern sconce fixture mounted on south-facing wall face
    buf[wall_ok & (dx == 0) & (ly == ts - 5)] = IX["apricot"]
    buf[wall_ok & (dx == 0) & (ly == ts - 4)] = IX["cream"]
    buf[wall_ok & (dx == 0) & (ly == ts - 3)] = IX["gold"]
    buf[wall_ok & (dx == 0) & (ly == ts - 2)] = IX["apricot"]
    buf[wall_ok & (dx == 1) & (ly == ts - 4)] = IX["apricot"]
    buf[wall_ok & (dx == 1) & (ly == ts - 3) & (bg < 0.72)] = IX["apricot"]
    buf[wall_ok & (dx == 1) & (ly == ts - 5)] = IX["dusk"]
    # Subtle warm bounce halo on dark masonry flanking the sconce
    wall_halo = wall_ok & (dx >= 2) & (dx <= 5) & (ly >= ts - 5) & (ly <= ts - 2)
    buf[wall_halo & (dx <= 3) & (bg < 0.42)] = IX["plum"]
    buf[wall_halo & (dx >= 4) & (bg < 0.24)] = IX["dusk"]

    # 2) Soft Bayer-dithered golden-apricot-to-mauve light apron spilling onto walkable floor below
    up_lt_open = expand_neighbor_mask(ctx["grid"], -1, -1, {"wall"}, ts)
    up_rt_open = expand_neighbor_mask(ctx["grid"], -1, 1, {"wall"}, ts)
    floor_ok = (
        m_walk
        & ctx["n_up_wall"]
        & (~((~up_lt_open) & (lx < 2)))
        & (~((~up_rt_open) & (lx >= ts - 2)))
    )
    if not np.any(floor_ok):
        return

    dist = np.hypot(dx.astype(np.float32) * 0.74, (ly.astype(np.float32) + 0.6) * 1.05)
    in_pool = floor_ok & (dist < radius) & (ly >= 1)
    if not np.any(in_pool):
        return

    t = np.clip(1.0 - dist / float(radius), 0.0, 1.0)
    # Do not overwrite bright focal decor (cream/gold/ice/apricot already on floor)
    cur = buf
    is_bright = (cur == IX["cream"]) | (cur == IX["gold"]) | (cur == IX["ice"]) | (cur == IX["apricot"])
    paintable = in_pool & (~is_bright)

    # Outer warm violet-mauve wash (warms cold night/deep/blue without blowing out floor luma)
    outer_plum = paintable & (t < 0.44) & (t * 0.78 > bg) & ((cur == IX["night"]) | (cur == IX["deep"]) | (cur == IX["dusk"]))
    outer_mauve = paintable & (t >= 0.30) & (t * 0.68 > bg)
    mid_apricot = paintable & (dist < radius * 0.58) & ((1.0 - dist / (radius * 0.60)) * 0.56 > bg)
    core_gold = paintable & (dist < 4.2) & ((1.0 - dist / 4.6) * 0.48 > bg)

    buf[outer_plum] = IX["plum"]
    buf[outer_mauve] = IX["mauve"]
    buf[mid_apricot] = IX["apricot"]
    buf[core_gold] = IX["gold"]

    # Gentle contact glint right beneath sconce at ly==0 (keeps plinth grounded everywhere else)
    base_glint = floor_ok & (ly == 0) & (dx <= 2) & (bg < 0.52) & (~is_bright)
    buf[base_glint] = IX["apricot"]


def _paint_observatory_walls(buf: np.ndarray, ctx: dict[str, Any], mode: str) -> None:
    """Paint architectural observatory silhouettes onto walls (dome ribs, astrolabe arcs, arches, skylights)."""
    m_wall = ctx["m_wall"]
    if not np.any(m_wall):
        return
    dn_open = ~ctx["n_dn_wall"]
    xs, ys = ctx["xs"], ctx["ys"]
    lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
    bg = ctx["bg"]
    H, W = ctx["H"], ctx["W"]

    # Sweeping dome-rib arcs across deeper wall caps (breaks boxy wall slabs)
    cx, cy = W * 0.5, H * 0.5
    rad = np.hypot((xs - cx) * 0.85, (ys - cy) * 1.1)
    cap_interior = m_wall & (~(dn_open & (ly >= ts - 6)))
    dome_arc = cap_interior & (np.abs((rad % 28.0) - 14.0) < 0.85) & (bg < 0.55)

    if mode == "orrery":
        buf[dome_arc] = IX["deep"]
        # Vaulted brass dome ribs every 24px rising over cornice & south face
        rx = xs % 24
        rib = m_wall & ((rx == 0) | (rx == 1))
        buf[rib & cap_interior & (bg < 0.65)] = IX["deep"]
        buf[rib & dn_open & (ly >= ts - 6) & (ly < ts - 1)] = IX["dusk"]
        buf[m_wall & (rx == 0) & dn_open & (ly == ts - 6)] = IX["gold"]
        # Arched astrolabe wall niches between ribs on south-facing walls
        niche = m_wall & dn_open & (rx >= 9) & (rx <= 15) & (ly >= ts - 5) & (ly <= ts - 2)
        arch_cut = niche & ~((ly == ts - 5) & ((rx == 9) | (rx == 15)))
        buf[arch_cut] = IX["void"]
        # Gilded astrolabe arch lintel & tiny star-dial pip inside
        lintel = m_wall & dn_open & (ly == ts - 6) & (rx >= 10) & (rx <= 14)
        buf[lintel] = IX["apricot"]
        pip = m_wall & dn_open & (ly == ts - 3) & (rx == 12)
        buf[pip] = IX["sky"]

    elif mode == "meteor":
        buf[dome_arc] = IX["dusk"]
        # Heavy curved iron dome buttress ribs every 28px with brass rivet studs
        rx = xs % 28
        rib = m_wall & ((rx == 0) | (rx == 1))
        buf[rib & cap_interior & (bg < 0.65)] = IX["dusk"]
        buf[rib & dn_open & (ly >= ts - 6) & (ly < ts - 1)] = IX["deep"]
        buf[m_wall & (rx == 0) & dn_open & (ly == ts - 5)] = IX["apricot"]
        # Recessed vaulted crater-arch bays with subtle star-ore crystal glints
        bay = m_wall & dn_open & (rx >= 10) & (rx <= 18) & (ly >= ts - 5) & (ly <= ts - 2)
        arch_cut = bay & ~((ly == ts - 5) & ((rx == 10) | (rx == 18)))
        buf[arch_cut] = IX["void"]
        ore = m_wall & dn_open & (ly == ts - 3) & ((rx == 13) | (rx == 15))
        buf[ore & (rx == 13)] = IX["sky"]
        buf[ore & (rx == 15)] = IX["apricot"]

    elif mode == "planetarium":
        buf[dome_arc] = IX["deep"]
        # Fluted observatory dome pilasters every 32px
        rx = xs % 32
        rib = m_wall & ((rx == 0) | (rx == 1))
        buf[rib & cap_interior & (bg < 0.65)] = IX["deep"]
        buf[m_wall & (rx == 0) & dn_open & (ly >= ts - 5) & (ly < ts - 1)] = IX["blue"]
        buf[m_wall & (rx == 1) & dn_open & (ly >= ts - 5) & (ly < ts - 1)] = IX["deep"]
        buf[m_wall & (rx == 2) & dn_open & (ly >= ts - 5) & (ly < ts - 1)] = IX["void"]
        buf[m_wall & ((rx == 0) | (rx == 1)) & dn_open & (ly == ts - 6)] = IX["gold"]
        # Arched starry clerestory skylights recessed along south-facing walls
        sky_w = m_wall & dn_open & (rx >= 10) & (rx <= 22) & (ly >= ts - 5) & (ly <= ts - 2)
        arch = sky_w & ~((ly == ts - 5) & ((rx == 10) | (rx == 22)))
        buf[arch] = IX["void"]
        buf[arch & (ly <= ts - 4) & (bg < 0.65)] = IX["deep"]
        # Central skylight mullion & starlight panes
        mull = arch & (rx == 16)
        buf[mull] = IX["night"]
        star_l = arch & (ly == ts - 4) & ((rx == 13) | (rx == 19))
        buf[star_l] = IX["ice"]
        buf[arch & (ly == ts - 3) & ((rx == 12) | (rx == 20))] = IX["sky"]
        # Refined gilded arch keystone (restrained, never a harsh continuous yellow bar)
        buf[m_wall & dn_open & (ly == ts - 6) & (rx >= 13) & (rx <= 19)] = IX["apricot"]
        buf[m_wall & dn_open & (ly == ts - 6) & (rx == 16)] = IX["gold"]

    elif mode == "freefall":
        buf[dome_arc] = IX["dusk"]
        # Broken observatory skylight bays & weathered ruined dome pilasters every 28px
        rx = xs % 28
        rib = m_wall & ((rx == 0) | (rx == 1))
        buf[rib & cap_interior & (bg < 0.62)] = IX["dusk"]
        buf[m_wall & (rx == 0) & dn_open & (ly >= ts - 5) & (ly < ts - 1)] = IX["mauve"]
        buf[m_wall & (rx == 1) & dn_open & (ly >= ts - 5) & (ly < ts - 1)] = IX["dusk"]
        buf[m_wall & (rx == 0) & dn_open & (ly == ts - 6)] = IX["gold"]
        # Shattered skylight window gap with jagged ice glass shards
        gap = m_wall & dn_open & (rx >= 9) & (rx <= 19) & (ly >= ts - 5) & (ly <= ts - 2)
        buf[gap] = IX["void"]
        shard = gap & (((ly == ts - 5) & ((rx == 10) | (rx == 11) | (rx == 18))) | ((ly == ts - 4) & (rx == 10)))
        buf[shard] = IX["ice"]
        shard2 = gap & (ly == ts - 2) & ((rx == 13) | (rx == 16))
        buf[shard2] = IX["sky"]

    elif mode == "geode":
        buf[dome_arc] = IX["deep"]
        # Carved subterranean observatory crypt arches every 28px + quartz crystal veins
        rx = xs % 28
        arch = m_wall & dn_open & (rx >= 10) & (rx <= 18) & (ly >= ts - 5) & (ly <= ts - 2)
        arch_cut = arch & ~((ly == ts - 5) & ((rx == 10) | (rx == 18)))
        buf[arch_cut] = IX["void"]
        buf[m_wall & dn_open & (ly == ts - 6) & (rx >= 11) & (rx <= 17)] = IX["sky"]
        # Recessed sparkling star-quartz veins inside cavern walls
        vein = cap_interior & (np.abs(((xs + ys * 2) % 37) - 18) == 0) & (ctx["n_broad"] > 0.62) & (bg < 0.45)
        buf[vein] = IX["sky"]
        buf[vein & (ctx["n_fine"] > 0.72)] = IX["ice"]

    elif mode == "overworld":
        buf[dome_arc] = IX["deep"]
        # Observatory parapet niches & golden finials every 24px
        rx = xs % 24
        niche = m_wall & dn_open & (rx >= 9) & (rx <= 15) & (ly >= ts - 5) & (ly <= ts - 2)
        buf[niche & ~((ly == ts - 5) & ((rx == 9) | (rx == 15)))] = IX["void"]
        buf[m_wall & dn_open & (ly == ts - 6) & (rx == 12)] = IX["gold"]
        buf[m_wall & dn_open & (ly == ts - 3) & (rx == 12)] = IX["apricot"]


class OrreryPainter(ThemePainter):
    """Grand Clockwork Orrery (unified for orrery_r1..r16): luminous twilight slate, brass arcs & warm sconce glow."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        sw, sh = 16, 12
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 59)

        # Harmonious twilight flagstones (~76-81 luma; reduced blue/plum checkerboard, warm-west -> cool-east)
        field = np.clip(nb * 0.46 + slab_h * 0.16 + 0.22, 0.12, 0.84)
        west_out = ramp_blend(("dusk", "plum", "plum", "mauve"), field, bg)
        east_out = ramp_blend(("deep", "dusk", "blue", "mauve"), np.clip(field * 0.96, 0.10, 0.80), bg)
        out = np.where(warm * 0.76 + (nb - 0.5) * 0.24 > bg, west_out, east_out)

        # Soft Bayer-dithered mortar seams (calm, never harsh dark grid)
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.42)
        out = np.where(is_seam, IX["night"], out)
        # Gentle top-left sunlit catchlight on select dressed stones
        is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & (slab_h > 0.70) & (bg < 0.30)
        out = np.where(is_bev, IX["mauve"], out)
        # Quiet room-centered brass astrolabe meridian arc inlaid into walkable stonework
        cx, cy = W * 0.5, H * 0.5
        rad = np.hypot(xs - cx, (ys - cy) * 1.08)
        arc = (np.abs(rad - 58.0) < 0.65) | (np.abs(rad - 98.0) < 0.65)
        out = np.where(arc & (((xs + ys) % 4) < 2) & (~is_seam) & (bg < 0.72), IX["apricot"], out)
        # Ultra-sparse gilded brass pin at select intersections
        pin = (sx == 8) & (sy == 6) & (slab_h > 0.94) & (nf > 0.5)
        out = np.where(pin, IX["gold"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_inlaid_path(buf, ctx, "plum", "mauve", "dusk", "apricot", self.spec.seed + 601)

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "orrery")
        _paint_sconce_light_aprons(buf, ctx, spacing=48, center_x=24, radius=13.5)


class MeteorVaultPainter(ThemePainter):
    """Meteor Vault: calm volcanic-indigo basalt slabs, dark iron-dome walls & warm brass sconces."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]

        # Large calm dressed asteroid-basalt slabs (20x14 staggered ashlar)
        sw, sh = 20, 14
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 109)

        # Calibrated mid-tone asteroid basalt (~76-81 luma, smooth cohesive figure-ground)
        field = np.clip(nb * 0.46 + slab_h * 0.18 + warm * 0.08 + 0.28, 0.16, 0.92)
        out = ramp_blend(s.floor_ramp, field, bg)
        # Soft Bayer-dithered seams (NEVER bright gold/ice confetti cracks!)
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.46)
        out = np.where(is_seam, IX["night"], out)
        # Quiet top-left catchlight on weathered basalt faces
        is_bev = (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.72) & (bg < 0.28)
        out = np.where(is_bev, IX["mauve"], out)
        # Very subtle embedded star-ore glints tucked strictly near rare block corners (<0.25%)
        glint_a = (sx == 2) & (sy == 2) & (slab_h > 0.93) & (nb > 0.52)
        glint_b = (sx == sw - 3) & (sy == sh - 3) & (slab_h < 0.07) & (nb < 0.48)
        out = np.where(glint_a, IX["gold"], out)
        out = np.where(glint_b, IX["ice"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_inlaid_path(buf, ctx, "plum", "mauve", "dusk", "apricot", self.spec.seed + 611)

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        super().paint_walls(buf, ctx)
        # Calm bright rivet polka-dots on dark iron roof caps so south cornices & sconces lead the eye
        m_wall = ctx["m_wall"]
        dn_open = ~ctx["n_dn_wall"]
        cap_in = m_wall & (~(dn_open & (ctx["ly"] >= ctx["ts"] - 6))) & (~((~ctx["n_up_wall"]) & (ctx["ly"] == 0)))
        dot = cap_in & (buf == IX[self.spec.wall_lip])
        buf[dot] = IX["dusk"]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "meteor")
        _paint_sconce_light_aprons(buf, ctx, spacing=56, center_x=28, radius=14.0)


class PlanetariumPainter(ThemePainter):
    """Planetarium: satin sapphire-indigo dome stonework, vaulted skylight pilasters & warm brass sconce halos."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        # Subtle warm-west twilight plum-indigo to cool-east satin sapphire (~77-82 luma)
        slab_h = hash01_grid(xs // 16, ys // 16, s.seed + 117)
        field = np.clip(nb * 0.36 + slab_h * 0.14 + 0.16, 0.08, 0.64)
        east_out = ramp_blend(("deep", "blue", "sky"), np.clip(field * 0.80, 0.06, 0.48), bg)
        west_out = ramp_blend(("deep", "dusk", "plum", "blue"), np.clip(field * 1.15, 0.12, 0.88), bg)
        out = np.where(warm * 0.48 + (nb - 0.5) * 0.20 > bg, west_out, east_out)

        # Fine calm 32x32 celestial meridian grid (Bayer-dithered night/deep)
        grid_line = (((xs % 32 == 0) & (ys % 2 == 0)) | ((ys % 32 == 0) & (xs % 2 == 0))) & (bg < 0.52)
        out = np.where(grid_line, IX["night"], out)
        # Restrained brass meridian intersection pips (no glaring white cream dot grid!)
        node = (xs % 32 == 0) & (ys % 32 == 0)
        major = (xs % 64 == 0) & (ys % 64 == 0)
        node_arm = (
            (((xs % 32 == 1) | (xs % 32 == 31)) & (ys % 32 == 0))
            | ((xs % 32 == 0) & ((ys % 32 == 1) | (ys % 32 == 31)))
        )
        out = np.where(node_arm & (bg < 0.55), IX["mauve"], out)
        out = np.where(node, IX["apricot"], out)
        out = np.where(major, IX["gold"], out)
        # Soft concentric gilded celestial dome arcs centered in room
        cx, cy = W * 0.5, H * 0.5
        rad = np.hypot(xs - cx, (ys - cy) * 1.1)
        arc = (np.abs(rad - 54.0) < 0.65) | (np.abs(rad - 92.0) < 0.65)
        out = np.where(arc & (((xs + ys) % 4) < 2) & (bg < 0.75), IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_inlaid_path(buf, ctx, "deep", "blue", "night", "apricot", self.spec.seed + 621)

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_balustrade_walls(buf, ctx, "planetarium")

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "planetarium")
        _paint_sconce_light_aprons(buf, ctx, spacing=64, center_x=32, radius=14.5)


class FreefallPainter(ThemePainter):
    """Observatory Freefall: twilight-lavender shattered masonry, weathered dome parapets & warm sconce glow."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        sy = ys % 12
        row_id = ys // 12
        ox = np.where((row_id & 1) == 1, 7, 0)
        cx_s = (xs + ox) % 16
        sh = hash01_grid((xs + ox) // 16, row_id, s.seed + 127)

        # Calibrated windswept twilight masonry (~77-82 luma; cohesive warm-west to cool-east)
        field = np.clip(nb * 0.44 + sh * 0.18 + 0.22, 0.12, 0.82)
        west_out = ramp_blend(("dusk", "plum", "mauve"), field, bg)
        east_out = ramp_blend(("deep", "dusk", "blue", "mauve"), field, bg)
        out = np.where(warm * 0.70 + (nb - 0.5) * 0.25 > bg, west_out, east_out)

        is_seam = ((cx_s == 0) | (sy == 0)) & (bg < 0.46)
        out = np.where(is_seam, IX["night"], out)
        out = np.where((sy == 1) & (cx_s > 1) & (sh > 0.68) & (bg < 0.30), IX["sky"], out)
        # Crisp restrained stone fracture cracks (no loud golden spaghetti loops!)
        frac_n = np.abs(fbm_grid(H, W, 30.0, seed=s.seed + 131, octaves=2) - 0.5)
        out = np.where((frac_n < 0.011) & (nb > 0.38), IX["night"], out)
        out = np.where((frac_n >= 0.011) & (frac_n < 0.016) & (nb > 0.58) & (bg < 0.30), IX["mauve"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_inlaid_path(buf, ctx, "plum", "mauve", "dusk", "apricot", self.spec.seed + 631)

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_balustrade_walls(buf, ctx, "freefall")

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "freefall")
        _paint_sconce_light_aprons(buf, ctx, spacing=56, center_x=28, radius=13.5)


class StarfallGeodePainter(ThemePainter):
    """Starfall Geode Caverns: calm twilight cavern stone, hand-dressed stepping flagstones & warm crypt lanterns."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        warp_n = fbm_grid(H, W, 32.0, seed=s.seed + 163, octaves=3)
        # Calm luminous twilight cavern stone (~75-80 luma, clearly below teal water ~102)
        strata = np.clip(nb * 0.42 + warp_n * 0.28 + warm * 0.06 + 0.24, 0.14, 0.84)
        out = ramp_blend(("deep", "dusk", "plum", "blue"), strata, bg)
        # Calm natural bedrock crevices
        crack = (np.abs(warp_n - 0.46) < 0.011) & (nb < 0.56)
        out = np.where(crack, IX["night"], out)
        out = np.where((np.abs(warp_n - 0.474) < 0.009) & (nb > 0.54) & (bg < 0.30), IX["sky"], out)
        # Sparse quartz & star-brass mineral flecks
        out = np.where((nf < 0.004) & (warp_n > 0.58), IX["gold"], out)
        out = np.where((nf > 0.997) & (nb > 0.50), IX["ice"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        """Hand-dressed star-slate cavern stepping-flagstones with organic feathered edges (replaces sand_trail confetti!)."""
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        # Paint underlying cavern stone first so organic edges blend seamlessly without rectangular cutouts
        warp_n = fbm_grid(H, W, 32.0, seed=s.seed + 163, octaves=3)
        strata = np.clip(nb * 0.42 + warp_n * 0.28 + warm * 0.06 + 0.24, 0.14, 0.84)
        cavern_bg = ramp_blend(("deep", "dusk", "plum", "blue"), strata, bg)

        # Soft organic distance from non-path border so flagstones settle naturally into cavern bedrock
        d_edge = np.full((H, W), 8.0, dtype=np.float32)
        d_edge = np.where(~ctx["n_up_path"], np.minimum(d_edge, ly.astype(np.float32)), d_edge)
        d_edge = np.where(~ctx["n_dn_path"], np.minimum(d_edge, (ts - 1 - ly).astype(np.float32)), d_edge)
        d_edge = np.where(~ctx["n_lt_path"], np.minimum(d_edge, lx.astype(np.float32)), d_edge)
        d_edge = np.where(~ctx["n_rt_path"], np.minimum(d_edge, (ts - 1 - lx).astype(np.float32)), d_edge)
        feather = (d_edge + (nb - 0.5) * 3.0) / 3.2
        in_flag = feather > (bg * 0.85 + 0.12)

        # Dressed staggered star-slate stepping stones (14x10)
        sw, sh = 14, 10
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 641)

        sf = np.clip(nb * 0.34 + slab_h * 0.24 + 0.20, 0.10, 0.82)
        flag = ramp_blend(("dusk", "plum", "blue", "mauve"), sf, bg)
        # Soft recessed stepping-stone seams
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.52)
        flag = np.where(is_seam, IX["night"], flag)
        # Subtle WNW catchlight on top bevel of dressed flagstones
        is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & (slab_h > 0.64) & (bg < 0.30)
        flag = np.where(is_bev, IX["mauve"], flag)
        # Delicate inlaid brass/sky stepping-stone trim along outer stepping curb (sparse, calm)
        curb = (d_edge >= 1.0) & (d_edge <= 2.0) & in_flag & (~is_seam)
        flag = np.where(curb & (((xs + ys) % 7) == 0), IX["apricot"], flag)
        flag = np.where(curb & (((xs + ys) % 11) == 3) & (bg < 0.45), IX["sky"], flag)
        # Ultra-sparse brass center guide stud on occasional flagstones
        stud = (sx == sw // 2) & (sy == sh // 2) & (slab_h > 0.88) & (d_edge > 2.0)
        flag = np.where(stud, IX["apricot"], flag)

        out = np.where(in_flag, flag, cavern_bg)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "geode")
        _paint_sconce_light_aprons(buf, ctx, spacing=56, center_x=14, radius=14.0)


class StarfallOverworldPainter(ThemePainter):
    """Starfall Observatory Overworld: luminous twilight archipelago, brass-trimmed causeways, calm bridges & cliff skirts."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]

        # Warm west (dusk/plum/mauve) transitioning to cool east (deep/blue/sky) at ~74-80 luma
        sw, sh = 16, 12
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 77)

        field = np.clip(nb * 0.44 + slab_h * 0.20 + 0.18, 0.06, 0.82)
        west_out = ramp_blend(("dusk", "plum", "blue", "mauve"), field, bg)
        east_out = ramp_blend(("deep", "deep", "blue", "sky"), np.clip(field * 0.82, 0.04, 0.72), bg)
        # Smooth Bayer blend between warm west and moonlit east
        out = np.where(warm + (nb - 0.5) * 0.28 > bg, west_out, east_out)
        # Soft weathered terrace paving joints
        seam = ((sx == 0) | (sy == 0)) & (bg < 0.42) & (nb > 0.30)
        out = np.where(seam, IX["night"], out)
        # Gentle twilight star-moss flecks near cool outer terraces
        moss = (nb < 0.26) & (nf < 0.03) & (~seam)
        out = np.where(moss, IX["teal"], out)
        # Sparse catchlights on western flagstones
        glint = (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.78) & (bg < 0.26)
        out = np.where(glint, np.where(warm > 0.45, IX["mauve"], IX["sky"]), out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_inlaid_path(buf, ctx, "plum", "mauve", "dusk", "apricot", self.spec.seed + 651)

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        """Refined weathered twilight-timber & gilded brass observatory bridges (replaces loud coral stripes!)."""
        mask = ctx["m_bridge"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb = ctx["bg"], ctx["n_broad"]

        open_n = (~ctx["n_up_bridge"]) & (~ctx["n_up_land"])
        open_s = (~ctx["n_dn_bridge"]) & (~ctx["n_dn_land"])
        open_w = (~ctx["n_lt_bridge"]) & (~ctx["n_lt_land"])
        open_e = (~ctx["n_rt_bridge"]) & (~ctx["n_rt_land"])

        rail_n = (ly == 0) & open_n
        rail_s = (ly == ts - 1) & open_s
        rail_w = (lx == 0) & open_w
        rail_e = (lx == ts - 1) & open_e
        rail = rail_n | rail_s | rail_w | rail_e

        in_n = (ly == 1) & open_n
        in_s = (ly == ts - 2) & open_s
        in_w = (lx == 1) & open_w
        in_e = (lx == ts - 2) & open_e
        stringer = in_n | in_s | in_w | in_e

        # Orient plank slats perpendicular to bridge span (vertical bridge -> horizontal planks)
        is_vert = (open_w | open_e) & (~(open_n | open_s))
        p_coord = np.where(is_vert, ys, xs)
        p_along = np.where(is_vert, xs, ys)
        plank_id = p_coord // 5
        plank_pos = p_coord % 5
        ph = hash01_grid(plank_id, p_along // 16, self.spec.seed + 661)

        # Calm weathered mahogany/plum timber deck (dusk -> plum -> wine, soft subtle mauve catchlight)
        out = ramp_blend(("dusk", "plum", "plum", "wine"), np.clip(nb * 0.42 + ph * 0.28 + 0.14, 0.06, 0.84), bg)
        out = np.where((plank_pos == 0) & (bg < 0.72), IX["night"], out)
        out = np.where((plank_pos == 1) & (ph > 0.68) & (bg < 0.28), IX["mauve"], out)
        # Subtle iron/brass deck nails near stringers
        nail = (plank_pos == 2) & ((ly == 2) | (ly == ts - 3) | (lx == 2) | (lx == ts - 3)) & (ph > 0.45)
        out = np.where(nail, IX["dusk"], out)

        # Recessed dark timber stringer & refined gilded brass side balustrade
        out = np.where(stringer, IX["night"], out)
        post = ((xs + ys) % 8 == 0)
        out = np.where(rail, np.where(post, IX["gold"], np.where(((xs + ys) % 2) == 0, IX["apricot"], IX["dusk"])), out)
        # Subtle warm catchlight next to gilded bridge posts
        post_glow = (~rail) & (~stringer) & (
            ((ly == 2) & open_n & (xs % 8 == 0))
            | ((ly == ts - 3) & open_s & (xs % 8 == 0))
            | ((lx == 2) & open_w & (ys % 8 == 0))
            | ((lx == ts - 3) & open_e & (ys % 8 == 0))
        )
        out = np.where(post_glow, IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "overworld")
        _paint_sconce_light_aprons(buf, ctx, spacing=48, center_x=12, radius=11.0)

        # Warm observatory corner beacon catchlights on outer terrace promontories
        m_walk = ctx["m_walk"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        c_nw = m_walk & ctx["n_up_abyss"] & ctx["n_lt_abyss"] & (lx < 6) & (ly < 6)
        c_ne = m_walk & ctx["n_up_abyss"] & ctx["n_rt_abyss"] & (lx >= ts - 6) & (ly < 6)
        c_sw = m_walk & ctx["n_dn_abyss"] & ctx["n_lt_abyss"] & (lx < 6) & (ly >= ts - 6)
        c_se = m_walk & ctx["n_dn_abyss"] & ctx["n_rt_abyss"] & (lx >= ts - 6) & (ly >= ts - 6)
        d_c = np.full(buf.shape, 99.0, dtype=np.float32)
        d_c = np.where(c_nw, np.hypot(lx - 1.5, ly - 1.5), d_c)
        d_c = np.where(c_ne, np.hypot((ts - 2.5) - lx, ly - 1.5), d_c)
        d_c = np.where(c_sw, np.hypot(lx - 1.5, (ts - 2.5) - ly), d_c)
        d_c = np.where(c_se, np.hypot((ts - 2.5) - lx, (ts - 2.5) - ly), d_c)
        # Subtle warm brass corner stud + soft Bayer apricot glow
        buf[(d_c < 1.3)] = IX["gold"]
        buf[(d_c >= 1.3) & (d_c < 3.6) & ((1.0 - d_c / 4.0) * 0.55 > bg)] = IX["apricot"]
        buf[(d_c >= 3.6) & (d_c < 5.4) & ((1.0 - d_c / 5.6) * 0.45 > bg)] = IX["mauve"]

        # Refined 8px stratified twilight cliff skirt hanging below southern island rims into starry void
        m_void = ctx["m_void"]
        n_up_land = ctx["n_up_land"]
        xs = ctx["xs"]
        warm = ctx["warm"]
        cliff = m_void & n_up_land & (ly < 8)
        if np.any(cliff):
            c0 = cliff & (ly == 0)
            buf[c0] = np.where(warm[c0] > bg[c0], IX["mauve"], IX["blue"])
            c1 = cliff & (ly == 1)
            buf[c1] = np.where((xs[c1] % 8) == 0, IX["night"], np.where(warm[c1] > bg[c1], IX["plum"], IX["deep"]))
            c2 = cliff & (ly == 2)
            buf[c2] = np.where(((xs[c2] + 4) % 8) == 0, IX["night"], IX["deep"])
            c3 = cliff & (ly == 3)
            buf[c3] = np.where(((xs[c3] % 6) == 0) | (bg[c3] < 0.55), IX["dusk"], IX["deep"])
            c4 = cliff & (ly == 4)
            buf[c4] = np.where((xs[c4] % 5) == 0, IX["night"], IX["dusk"])
            c5 = cliff & (ly == 5)
            buf[c5] = np.where(bg[c5] < 0.62, IX["night"], IX["dusk"])
            c6 = cliff & (ly == 6) & (bg < 0.52)
            buf[c6] = IX["night"]
            c7 = cliff & (ly == 7) & (bg < 0.24)
            buf[c7] = IX["night"]


# ------------------------------------------------------------------ ISLAND 6 HELPERS


def _i6_paint_forge_aprons(
    buf: np.ndarray,
    ctx: dict[str, Any],
    spacing: int,
    center_x: int,
    radius: float = 13.5,
    style: str = "lantern",
) -> None:
    """Paint warm Ashen Kiln wall lanterns or recessed furnace vents with Bayer-dithered floor light aprons."""
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
    sx_mod = xs % spacing
    dx = np.minimum(np.abs(sx_mod - center_x), spacing - np.abs(sx_mod - center_x))

    # Avoid clipping a fixture onto the extreme 2px edge of a 1-tile floating pillar
    wall_ok = m_wall & dn_open & dn_walk & (~(lt_open & (lx < 2))) & (~(rt_open & (lx >= ts - 2)))

    if style == "furnace":
        # Recessed dark-iron foundry furnace slit vent with glowing coral/apricot/gold louvers
        vent = wall_ok & (dx <= 3) & (ly >= ts - 5) & (ly <= ts - 2)
        buf[vent] = IX["void"]
        buf[wall_ok & (dx <= 2) & (ly == ts - 4)] = IX["coral"]
        buf[wall_ok & (dx <= 1) & (ly == ts - 4)] = IX["gold"]
        buf[wall_ok & (dx <= 2) & (ly == ts - 3) & ((xs % 2) == 0)] = IX["apricot"]
        buf[wall_ok & (dx <= 2) & (ly == ts - 3) & ((xs % 2) == 1)] = IX["coral"]
        buf[wall_ok & (dx == 3) & (ly >= ts - 5) & (ly <= ts - 2)] = IX["dusk"]
        buf[wall_ok & (dx <= 3) & (ly == ts - 5)] = IX["plum"]
        # Subtle warm bounce halo on surrounding dark foundry wall
        halo = wall_ok & (dx >= 4) & (dx <= 6) & (ly >= ts - 5) & (ly <= ts - 2)
        buf[halo & (dx <= 5) & (bg < 0.36)] = IX["wine"]
        buf[halo & (dx == 6) & (bg < 0.22)] = IX["plum"]
    else:
        # Warm forged-brass lantern sconce mounted on south-facing wall face
        buf[wall_ok & (dx == 0) & (ly == ts - 5)] = IX["apricot"]
        buf[wall_ok & (dx == 0) & (ly == ts - 4)] = IX["cream"]
        buf[wall_ok & (dx == 0) & (ly == ts - 3)] = IX["gold"]
        buf[wall_ok & (dx == 0) & (ly == ts - 2)] = IX["coral"]
        buf[wall_ok & (dx == 1) & (ly == ts - 4)] = IX["apricot"]
        buf[wall_ok & (dx == 1) & (ly == ts - 3) & (bg < 0.68)] = IX["coral"]
        buf[wall_ok & (dx == 1) & (ly == ts - 5)] = IX["dusk"]
        halo = wall_ok & (dx >= 2) & (dx <= 5) & (ly >= ts - 5) & (ly <= ts - 2)
        buf[halo & (dx <= 3) & (bg < 0.38)] = IX["wine"]
        buf[halo & (dx >= 4) & (bg < 0.22)] = IX["plum"]

    # Soft Bayer-dithered ember/lantern light apron spilling onto walkable floor below
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

    dist = np.hypot(dx.astype(np.float32) * 0.72, (ly.astype(np.float32) + 0.5) * 1.05)
    in_pool = floor_ok & (dist < radius) & (ly >= 1)
    if not np.any(in_pool):
        return

    t = np.clip(1.0 - dist / float(radius), 0.0, 1.0)
    cur = buf
    is_bright = (cur == IX["cream"]) | (cur == IX["gold"]) | (cur == IX["ice"]) | (cur == IX["apricot"])
    paintable = in_pool & (~is_bright)

    if style == "furnace":
        outer_wine = paintable & (t >= 0.22) & (t * 0.62 > bg) & ((cur == IX["night"]) | (cur == IX["dusk"]) | (cur == IX["deep"]) | (cur == IX["plum"]))
        mid_coral = paintable & (dist < radius * 0.56) & ((1.0 - dist / (radius * 0.58)) * 0.50 > bg)
        core_apricot = paintable & (dist < 4.6) & ((1.0 - dist / 4.8) * 0.46 > bg)
        buf[outer_wine] = IX["wine"]
        buf[mid_coral] = IX["coral"]
        buf[core_apricot] = IX["apricot"]
        base_glint = floor_ok & (ly == 0) & (dx <= 2) & (bg < 0.52) & (~is_bright)
        buf[base_glint] = IX["coral"]
    else:
        outer_wine = paintable & (t >= 0.24) & (t * 0.60 > bg) & ((cur == IX["night"]) | (cur == IX["dusk"]) | (cur == IX["deep"]) | (cur == IX["plum"]))
        mid_apricot = paintable & (dist < radius * 0.54) & ((1.0 - dist / (radius * 0.56)) * 0.52 > bg)
        core_gold = paintable & (dist < 4.0) & ((1.0 - dist / 4.4) * 0.44 > bg)
        buf[outer_wine] = IX["wine"]
        buf[mid_apricot] = IX["apricot"]
        buf[core_gold] = IX["gold"]
        base_glint = floor_ok & (ly == 0) & (dx <= 2) & (bg < 0.50) & (~is_bright)
        buf[base_glint] = IX["apricot"]


def _i6_paint_iron_catwalk_path(
    buf: np.ndarray,
    ctx: dict[str, Any],
    main_c: str,
    hi_c: str,
    dk_c: str,
    trim_c: str,
    seed: int,
) -> None:
    """Calm riveted foundry iron catwalk / ashlar causeway (replaces loud bright grate/dashed borders)."""
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

    in_n = (~ctx["n_up_path"]) & (ly == 1)
    in_s = (~ctx["n_dn_path"]) & (ly == ts - 2)
    in_w = (~ctx["n_lt_path"]) & (lx == 1)
    in_e = (~ctx["n_rt_path"]) & (lx == ts - 2)
    is_inner = (in_n | in_s | in_w | in_e) & (~is_edge)
    is_corner = (in_n | in_s) & (in_w | in_e)

    # Staggered riveted foundry steel deck plates (16x8)
    row_id = ys // 8
    ox = np.where((row_id & 1) == 1, 8, 0)
    sx = (xs + ox) % 16
    sy = ys % 8
    plate_h = hash01_grid((xs + ox) // 16, row_id, seed)
    field = np.clip(nb * 0.34 + plate_h * 0.24 + 0.32, 0.14, 0.90)
    out = ramp_blend((dk_c, main_c, main_c, hi_c), field, bg)

    # Recessed industrial grating slots in center of plates (subtle, never jarring)
    slot = (~is_edge) & (~is_inner) & (sx >= 3) & (sx <= 13) & ((sy == 3) | (sy == 5)) & ((sx % 3) == 0) & (bg < 0.72)
    out = np.where(slot, IX["night"], out)
    # Soft Bayer-dithered plate seams
    seam = ((sx == 0) | (sy == 0)) & (bg < 0.52)
    out = np.where(seam, IX["night"], out)
    # Quiet top-left catchlight on select plates
    bev = (sy == 1) & (sx > 1) & (sx < 14) & (plate_h > 0.68) & (bg < 0.26)
    out = np.where(bev, IX[hi_c], out)

    # Refined curb rail & spaced brass rivets along outer edges
    out = np.where(is_inner & (bg < 0.44), IX[hi_c], out)
    riv = is_inner & (is_corner | (((xs + ys) % 8) == 0))
    out = np.where(riv, IX[trim_c], out)
    out = np.where(is_edge, np.where(bg < 0.78, IX["night"], IX[dk_c]), out)
    buf[mask] = out[mask]


def _i6_paint_iron_bridge(
    buf: np.ndarray,
    ctx: dict[str, Any],
    deck_ramp: tuple[str, ...],
    rail_c: str,
    seed: int,
) -> None:
    """Refined riveted iron-slag foundry bridge with spaced brass handrail stanchions."""
    mask = ctx["m_bridge"]
    if not np.any(mask):
        return
    xs, ys = ctx["xs"], ctx["ys"]
    lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
    bg, nb = ctx["bg"], ctx["n_broad"]

    open_n = (~ctx["n_up_bridge"]) & (~ctx["n_up_land"])
    open_s = (~ctx["n_dn_bridge"]) & (~ctx["n_dn_land"])
    open_w = (~ctx["n_lt_bridge"]) & (~ctx["n_lt_land"])
    open_e = (~ctx["n_rt_bridge"]) & (~ctx["n_rt_land"])

    rail = (
        ((ly == 0) & open_n)
        | ((ly == ts - 1) & open_s)
        | ((lx == 0) & open_w)
        | ((lx == ts - 1) & open_e)
    )
    stringer = (
        ((ly == 1) & open_n)
        | ((ly == ts - 2) & open_s)
        | ((lx == 1) & open_w)
        | ((lx == ts - 2) & open_e)
    )

    is_vert = (open_w | open_e) & (~(open_n | open_s))
    p_coord = np.where(is_vert, ys, xs)
    p_along = np.where(is_vert, xs, ys)
    slat_id = p_coord // 5
    slat_pos = p_coord % 5
    sh = hash01_grid(slat_id, p_along // 16, seed)

    out = ramp_blend(deck_ramp, np.clip(nb * 0.40 + sh * 0.26 + 0.16, 0.08, 0.82), bg)
    out = np.where((slat_pos == 0) & (bg < 0.74), IX["night"], out)
    # Recessed cross-grate vents on deck slats
    vent = (~rail) & (~stringer) & (slat_pos == 2) & ((p_along % 4) == 0) & (bg < 0.58)
    out = np.where(vent, IX["night"], out)
    # Subtle warm highlight along sunlit slat edge
    out = np.where((slat_pos == 1) & (sh > 0.66) & (bg < 0.28), IX["mauve"], out)
    # Dark riveted iron stringer & spaced brass stanchion railing
    out = np.where(stringer, IX["night"], out)
    post = ((xs + ys) % 8) == 0
    out = np.where(
        rail,
        np.where(post, IX["gold"], np.where(((xs + ys) % 2) == 0, IX[rail_c], IX["dusk"])),
        out,
    )
    buf[mask] = out[mask]


def _i6_paint_plush_rug_decor(
    painter: ThemePainter,
    buf: np.ndarray,
    ctx: dict[str, Any],
    decor_list: list[dict[str, Any]],
    default_main: str,
    default_hi: str,
    default_trim: str,
    default_edge: str,
) -> None:
    """Render Ember Express rugs as sumptuous calm crimson-wine velvet (zero diagonal zebra hatching)."""
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
                    buf[y, x] = c_trim if ((x + y) % 4 != 0) else c_dk
                else:
                    md = abs(x - cx_r) + abs(y - cy_r)
                    if md in (6, 12):
                        buf[y, x] = c_trim
                    elif md in (5, 11):
                        buf[y, x] = c_dk
                    elif md < 5:
                        buf[y, x] = c_hi if (nb[y, x] > 0.50 and bg[y, x] < 0.42) else c_main
                    else:
                        v = nb[y, x]
                        if v > 0.66 and bg[y, x] < 0.24:
                            buf[y, x] = c_hi
                        elif v < 0.40 and bg[y, x] < 0.44:
                            buf[y, x] = c_dk
                        else:
                            buf[y, x] = c_main


def _i6_paint_dark_iron_walls(buf: np.ndarray, ctx: dict[str, Any], mode: str) -> None:
    """Sculpted dark Last Light Ashen Kiln walls (~34-44 luma) with bespoke industrial & volcanic architecture."""
    mask = ctx["m_wall"] | ctx["m_foliage"]
    if not np.any(mask):
        return
    xs, ys = ctx["xs"], ctx["ys"]
    lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
    bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]
    H, W = ctx["H"], ctx["W"]

    up_open = ~ctx["n_up_wall"]
    dn_open = ~ctx["n_dn_wall"]
    lt_open = ~ctx["n_lt_wall"]
    rt_open = ~ctx["n_rt_wall"]

    wall_d = chamfer_dist(ctx["m_wall"])
    edge_boost = np.clip(1.0 - wall_d / 14.0, 0.0, 1.0) * 0.36

    if mode == "carriage":
        # Dark paneled walnut & brass Ember Express cabin bulkheads (~38-42 luma)
        cap_field = np.clip(nb * 0.40 + edge_boost * 0.85 + 0.12, 0.04, 0.86)
        out = ramp_blend(("void", "night", "dusk"), cap_field, bg)
        # Subtle dark roof-panel strakes
        out = np.where(((lx % 16 == 0) | (ly % 8 == 0)) & (bg < 0.62), IX["void"], out)
        # South-facing 6px mahogany wainscot bulkhead
        south = dn_open & (ly >= ts - 6)
        out = np.where(south & (ly == ts - 6), IX["dusk"], out)
        out = np.where(south & (ly == ts - 6) & ((xs % 32) == 0), IX["apricot"], out)
        out = np.where(south & (ly > ts - 6) & (ly < ts - 1), IX["night"], out)
        # Molded wainscot recessed vertical frames
        px_m = xs % 16
        out = np.where(south & (ly >= ts - 5) & (ly <= ts - 2) & ((px_m == 0) | (px_m == 15)), IX["dusk"], out)
        out = np.where(south & (ly == ts - 2) & (px_m >= 2) & (px_m <= 13), IX["dusk"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)
        north_lip = np.where((xs % 32) == 0, IX["apricot"], IX["dusk"])
        west_c = IX["plum"]

    elif mode == "train_roof":
        # Dark riveted locomotive roof bulkheads & raised vent cowlings (~36-40 luma)
        cap_field = np.clip(nb * 0.44 + edge_boost + 0.16, 0.06, 0.90)
        out = ramp_blend(("void", "night", "dusk"), cap_field, bg)
        out = np.where(((lx % 16 == 0) | (ly % 8 == 0)) & (bg < 0.56), IX["void"], out)
        # Subtle muted rivets near outer bulkhead edges only
        cap_in = (~(dn_open & (ly >= ts - 6))) & (~(up_open & (ly == 0)))
        riv = cap_in & (wall_d < 8.0) & ((lx == 2) | (lx == 13)) & (ly == 3)
        out = np.where(riv, IX["plum"], out)
        south = dn_open & (ly >= ts - 6)
        out = np.where(south & (ly == ts - 6), IX["plum"], out)
        out = np.where(south & (ly == ts - 6) & ((xs % 16) == 0), IX["coral"], out)
        out = np.where(south & (ly > ts - 6) & (ly < ts - 1), IX["night"], out)
        out = np.where(south & (xs % 12 == 0) & (ly > ts - 6), IX["void"], out)
        out = np.where(south & (ly == ts - 4) & ((xs % 12 == 2) | (xs % 12 == 10)), IX["dusk"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)
        north_lip = np.where((xs % 16) == 0, IX["apricot"], IX["plum"])
        west_c = IX["plum"]

    elif mode == "colossus":
        # Monumental dark riveted iron hull walls + recessed brass pressure gauges (~37-41 luma)
        cap_field = np.clip(nb * 0.44 + edge_boost + 0.14, 0.06, 0.90)
        out = ramp_blend(("void", "night", "dusk"), cap_field, bg)
        # Heavy 24x12 welded hull armor seams on cap
        seam = ((xs % 24 == 0) | (ys % 12 == 0)) & (bg < 0.55)
        out = np.where(seam, IX["void"], out)
        cap_in = (~(dn_open & (ly >= ts - 6))) & (~(up_open & (ly == 0)))
        # Subtle structural hull bolts along 24px ribs (dark plum/dusk, NO bright polka dots!)
        bolt = cap_in & ((xs % 24 == 2) | (xs % 24 == 22)) & ((ys % 12) == 6) & (wall_d < 10.0)
        out = np.where(bolt, IX["plum"], out)
        # South-facing 6px riveted iron hull bulkhead
        south = dn_open & (ly >= ts - 6)
        out = np.where(south & (ly == ts - 6), IX["plum"], out)
        out = np.where(south & (ly == ts - 6) & ((xs % 22) <= 1), IX["apricot"], out)
        out = np.where(south & (ly > ts - 6) & (ly < ts - 1), IX["night"], out)
        # Heavy vertical buttress ribs every 22px
        rx = xs % 22
        out = np.where(south & (rx == 0) & (ly > ts - 6), IX["dusk"], out)
        out = np.where(south & (rx == 1) & (ly > ts - 6), IX["void"], out)
        # Recessed brass pressure-gauge dials centered between furnace vents (rx in 9..13)
        gauge_ok = south & (~(lt_open & (lx < 2))) & (~(rt_open & (lx >= ts - 2)))
        g_ring = gauge_ok & (rx >= 9) & (rx <= 13) & (ly >= ts - 5) & (ly <= ts - 2)
        g_inner = gauge_ok & (rx >= 10) & (rx <= 12) & (ly >= ts - 4) & (ly <= ts - 3)
        out = np.where(g_ring & (~g_inner), IX["plum"], out)
        out = np.where(g_ring & (ly == ts - 5) & (rx == 11), IX["apricot"], out)
        out = np.where(g_inner, IX["void"], out)
        out = np.where(gauge_ok & (rx == 11) & (ly == ts - 4), IX["coral"], out)
        out = np.where(gauge_ok & (rx == 12) & (ly == ts - 3), IX["apricot"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)
        north_lip = np.where((xs % 22) == 0, IX["apricot"], IX["dusk"])
        west_c = IX["plum"]

    elif mode == "forge_deep":
        # Dark iron-riveted volcanic foundry masonry (~36-41 luma)
        cap_field = np.clip(nb * 0.46 + edge_boost + 0.22, 0.08, 0.94)
        out = ramp_blend(("void", "night", "dusk"), cap_field, bg)
        row_id = ys // 8
        ox = np.where((row_id & 1) == 1, 8, 0)
        cap_seam = (((xs + ox) % 16 == 0) | (ys % 8 == 0)) & (bg < 0.44)
        out = np.where(cap_seam, IX["void"], out)
        # Heavy dark iron banding straps every 32px
        strap = (xs % 32 == 0) & (bg < 0.65)
        out = np.where(strap, IX["dusk"], out)
        # South-facing 6px ashlar foundry facade
        south = dn_open & (ly >= ts - 6)
        out = np.where(south & (ly == ts - 6), IX["plum"], out)
        out = np.where(south & (ly == ts - 6) & ((xs % 24) <= 1), IX["coral"], out)
        out = np.where(south & (ly > ts - 6) & (ly < ts - 1), IX["night"], out)
        # Ashlar mortar courses & subtle weathered brick bevel
        course = np.where(ly >= ts - 3, 4, 0)
        out = np.where(south & (ly == ts - 4) & (((xs + course) % 8) < 6) & (bg < 0.56), IX["dusk"], out)
        out = np.where(south & (((xs + course) % 8) == 0) & (ly > ts - 6), IX["void"], out)
        out = np.where(south & (ly == ts - 3), IX["void"], out)
        # Vertical iron reinforcement rib every 48px
        out = np.where(south & (xs % 48 == 0) & (ly > ts - 6) & (ly < ts - 1), IX["plum"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)
        north_lip = np.where((xs % 24) == 0, IX["coral"], IX["plum"])
        west_c = IX["plum"]

    elif mode == "cavern":
        # Dark fractured volcanic basalt cavern walls with glowing coral/apricot ember seams (~35-39 luma)
        rock_n = fbm_grid(H, W, 24.0, seed=606 + 233, octaves=2)
        cap_field = np.clip(rock_n * 0.50 + edge_boost + 0.12, 0.06, 0.90)
        out = ramp_blend(("void", "night", "dusk"), cap_field, bg)
        # Fractured dark basalt strata cracks & subtle glowing ember seams inside wall mass
        cap_in = (~(dn_open & (ly >= ts - 7))) & (~(up_open & (ly == 0)))
        ember_vein = cap_in & (np.abs(((xs + ys * 2 + (rock_n * 6.0).astype(np.int32)) % 39) - 19) == 0) & (nb > 0.58) & (bg < 0.48)
        out = np.where(ember_vein, IX["coral"], out)
        out = np.where(ember_vein & (nf > 0.68), IX["apricot"], out)
        # Organic volcanic basalt south cliff face
        south = dn_open & (ly >= ts - 7)
        lip_y = ts - 7 + np.where(rock_n > 0.52, 0, 1)
        out = np.where(south & (ly == lip_y), np.where(rock_n > 0.66, IX["wine"], IX["plum"]), out)
        facet = ((xs + (ly // 2) * 3 + (rock_n * 4.0).astype(np.int32)) % 9)
        out = np.where(
            south & (ly > lip_y) & (ly < ts - 1),
            np.where(facet == 0, IX["void"], np.where((facet == 1) & (ly < ts - 3), IX["dusk"], IX["night"])),
            out,
        )
        # Glowing ember hairline peeking out of select cliff fissures
        cliff_ember = south & (ly == ts - 3) & (facet == 0) & (nb > 0.64) & (bg < 0.55)
        out = np.where(cliff_ember, IX["coral"], out)
        out = np.where(south & (ly == ts - 1), IX["void"], out)
        north_lip = np.where(rock_n > 0.68, IX["wine"], IX["dusk"])
        west_c = IX["plum"]

    else:
        # "overworld": Dark stratified volcanic basalt caldera cliffs (~39-44 luma)
        rock_n = fbm_grid(H, W, 26.0, seed=601 + 233, octaves=2)
        cap_field = np.clip(rock_n * 0.48 + edge_boost + 0.14, 0.04, 0.92)
        west_cap = ramp_blend(("void", "night", "dusk", "plum"), np.clip(cap_field * 0.88, 0.04, 0.84), bg)
        east_cap = ramp_blend(("void", "night", "deep", "dusk"), np.clip(cap_field * 0.86, 0.04, 0.82), bg)
        out = np.where(warm + (nb - 0.5) * 0.24 > bg, west_cap, east_cap)
        # Stratified basalt ridge joints on cap
        cap_in = (~(dn_open & (ly >= ts - 7))) & (~(up_open & (ly == 0)))
        ridge_j = cap_in & (np.abs(rock_n - 0.50) < 0.014) & (bg < 0.60)
        out = np.where(ridge_j, IX["void"], out)
        # Subtle glowing caldera fissure inside dark cliffs
        fiss = cap_in & (np.abs(((xs + ys * 2) % 43) - 21) == 0) & (nb > 0.68) & (bg < 0.42)
        out = np.where(fiss, IX["coral"], out)
        # South-facing columnar basalt cliff facade
        south = dn_open & (ly >= ts - 7)
        lip_y = ts - 7 + np.where(rock_n > 0.50, 0, 1)
        out = np.where(south & (ly == lip_y), np.where(warm > bg, IX["wine"], IX["plum"]), out)
        col_f = ((xs + (ly // 2) * 2 + (rock_n * 3.0).astype(np.int32)) % 8)
        out = np.where(
            south & (ly > lip_y) & (ly < ts - 1),
            np.where(col_f == 0, IX["void"], np.where((col_f == 1) & (ly < ts - 3), IX["dusk"], IX["night"])),
            out,
        )
        out = np.where(south & (ly == ts - 1), IX["void"], out)
        north_lip = np.where(warm > bg, IX["plum"], IX["dusk"])
        west_c = IX["wine"]

    # Crisp north cornice, sunlit WNW west rim & shaded east rim
    out = np.where(up_open & (ly == 0), north_lip, out)
    west_rim = lt_open & (lx == 0) & (~(dn_open & (ly >= ts - 5)))
    out = np.where(west_rim & (bg < 0.52 + 0.35 * warm), west_c, out)
    out = np.where(west_rim & (warm < 0.25) & (bg < 0.45), COOL_IX[out], out)
    east_rim = rt_open & (lx == ts - 1) & (~(dn_open & (ly >= ts - 5)))
    out = np.where(east_rim, IX["void"], out)

    buf[mask] = out[mask]


# ------------------------------------------------------------------ ISLAND 6 PAINTERS


class EmberExpressInteriorPainter(ThemePainter):
    """Ember Express interior: satin twilight-mahogany planks, plush crimson velvet runners, walnut-brass cabin walls & warm carriage lamps."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]

        # Wide calm satin twilight-mahogany carriage floorboards (7px boards, staggered 32px butt joints; ~78-82 luma)
        ph = 7
        pr = ys // ph
        py = ys % ph
        butt_off = (pr * 17) % 32
        px_b = (xs + butt_off) % 32
        plank_h = hash01_grid((xs + butt_off) // 32, pr, s.seed + 77)

        pf = np.clip(nb * 0.34 + plank_h * 0.20 + warm * 0.10 + 0.04, 0.04, 0.70)
        out = ramp_blend(("dusk", "plum", "plum", "wine"), pf, bg)
        # Soft Bayer-dithered plank seams (one shade darker, ZERO harsh black horizontal stripes!)
        is_hseam = (py == 0) & (bg < 0.44)
        is_vseam = (px_b == 0) & (py > 0) & (bg < 0.40)
        out = np.where(is_hseam | is_vseam, SHADE_IX[out], out)
        # Restrained warm sunlit wood-grain catchlight on select mahogany boards
        out = np.where((py == 1) & (px_b > 2) & (px_b < 29) & (plank_h > 0.80) & (bg < 0.22), IX["coral"], out)
        # Tiny muted brass/oak treenail peg near butt joints
        peg = (px_b == 3) & (py == 3) & (plank_h > 0.62)
        out = np.where(peg, IX["dusk"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        """Sumptuous plush crimson-wine velvet carriage aisle runner (replaces noisy cross-hatched carpet)."""
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

        in1_n = (~ctx["n_up_path"]) & (ly == 1)
        in1_s = (~ctx["n_dn_path"]) & (ly == ts - 2)
        in1_w = (~ctx["n_lt_path"]) & (lx == 1)
        in1_e = (~ctx["n_rt_path"]) & (lx == ts - 2)
        is_in1 = (in1_n | in1_s | in1_w | in1_e) & (~is_edge)

        in2_n = (~ctx["n_up_path"]) & (ly == 2)
        in2_s = (~ctx["n_dn_path"]) & (ly == ts - 3)
        in2_w = (~ctx["n_lt_path"]) & (lx == 2)
        in2_e = (~ctx["n_rt_path"]) & (lx == ts - 3)
        is_in2 = (in2_n | in2_s | in2_w | in2_e) & (~is_edge) & (~is_in1)

        # Plush crimson-wine velvet pile (calm Bayer depth shading, zero zebra stripes)
        out = np.full(buf.shape, IX["wine"], dtype=np.uint8)
        out = np.where((nb < 0.46) & (bg < 0.48), IX["plum"], out)
        out = np.where((nb > 0.70) & (bg < 0.22), IX["coral"], out)
        # Quiet woven diamond medallion repeat along runner centerline
        dm = (np.abs((xs % 24) - 12) + np.abs((ys % 24) - 12)) == 5
        dm_in = (np.abs((xs % 24) - 12) + np.abs((ys % 24) - 12)) == 4
        out = np.where(dm & (~is_edge) & (~is_in1) & (~is_in2) & (bg < 0.72), IX["apricot"], out)
        out = np.where(dm_in & (~is_edge) & (~is_in1) & (~is_in2), IX["plum"], out)
        # Woven gilded inner border & dark velvet binding
        out = np.where(is_in2 & (((xs + ys) % 4) != 0), IX["apricot"], out)
        out = np.where(is_in1, IX["plum"], out)
        out = np.where(is_edge, IX["night"], out)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_dark_iron_walls(buf, ctx, "carriage")

    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        _i6_paint_plush_rug_decor(self, buf, ctx, decor_list, "wine", "coral", "apricot", "night")

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_wall = ctx["m_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]
        xs, lx, ly, ts = ctx["xs"], ctx["lx"], ctx["ly"], ctx["ts"]

        # Refined sunset/slag carriage windows every 32px along south-facing cabin bulkheads
        seg = xs % 32
        win_ok = m_wall & dn_open & (~(lt_open & (lx < 2))) & (~(rt_open & (lx >= ts - 2)))
        win = win_ok & (seg >= 10) & (seg <= 21) & (ly >= ts - 5) & (ly <= ts - 2)
        frame = win & ((seg == 10) | (seg == 21) | (ly == ts - 5) | (ly == ts - 2))
        pane = win & (~frame)
        buf[pane & (ly == ts - 4)] = IX["coral"]
        buf[pane & (ly == ts - 4) & (seg >= 14) & (seg <= 17)] = IX["apricot"]
        buf[pane & (ly == ts - 3)] = IX["wine"]
        # Passing dark telegraph pole silhouette
        pole = pane & ((xs % 96) == 16)
        buf[pole] = IX["night"]
        buf[frame] = IX["dusk"]
        buf[frame & (ly == ts - 5) & (seg >= 12) & (seg <= 19)] = IX["plum"]

        # Warm golden carriage-lamp sconces mounted on dark walnut mullions between windows
        _i6_paint_forge_aprons(buf, ctx, spacing=64, center_x=0, radius=13.0, style="lantern")


class EmberExpressRoofPainter(ThemePainter):
    """Ember Express roof: weathered dark riveted roof iron, calm catwalks, ember sparks & warm signal lanterns."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]

        # Weathered dark riveted carriage roof steel plates (16x16; ~73-77 luma)
        pw, ph = 16, 16
        px_i = xs % pw
        py_i = ys % ph
        phash = hash01_grid(xs // pw, ys // ph, s.seed + 139)

        field = np.clip(nb * 0.40 + phash * 0.24 + warm * 0.12 + 0.14, 0.08, 0.80)
        out = ramp_blend(("dusk", "dusk", "plum", "plum", "mauve"), field, bg)
        # Subtle Bayer-dithered roof corrugation ribs every 8px & plate seams (never noisy 4px stripes!)
        rib = ((ys % 8 == 0) & (bg < 0.46)) | ((px_i == 0) & (bg < 0.56))
        out = np.where(rib, IX["night"], out)
        # Quiet sunlit bevel on select roof ribs
        bev = (ys % 8 == 1) & (px_i > 1) & (px_i < pw - 1) & (phash > 0.64) & (bg < 0.26)
        out = np.where(bev, IX["mauve"], out)
        # Restrained rivets along plate seams
        riv = ((px_i == 2) | (px_i == pw - 2)) & (py_i == 4)
        out = np.where(riv, np.where(phash > 0.65, IX["apricot"], IX["dusk"]), out)
        # Sparse windswept ember sparks drifting across speeding carriage roof
        spark = (nf > 0.9965) & (nb > 0.45)
        out = np.where(spark, np.where(nf > 0.9985, IX["apricot"], IX["coral"]), out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_iron_catwalk_path(buf, ctx, "plum", "mauve", "dusk", "apricot", self.spec.seed + 617)

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_dark_iron_walls(buf, ctx, "train_roof")

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_iron_bridge(buf, ctx, ("dusk", "plum", "wine"), "apricot", self.spec.seed + 623)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
        # Refined brass safety grab-rails along north/south carriage eaves (spaced stanchions, not loud bar)
        n_eave = m_walk & ctx["n_up_abyss"] & (ly == 2)
        s_eave = m_walk & ctx["n_dn_abyss"] & (ly == ts - 3)
        eave = n_eave | s_eave
        buf[eave & ((xs % 8) < 5)] = IX["dusk"]
        buf[eave & ((xs % 8) == 0)] = IX["apricot"]
        buf[eave & ((xs % 8) == 2)] = IX["plum"]
        # Warm roof signal lantern sconces & floor aprons
        _i6_paint_forge_aprons(buf, ctx, spacing=48, center_x=24, radius=12.5, style="lantern")


class IronColossusPainter(ThemePainter):
    """Iron Colossus: oiled-iron twilight hull decks, monumental dark riveted walls with brass gauges & furnace aprons."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]

        # Heavy oiled-iron twilight deck plates (24x16 staggered hull plating; ~75-80 luma)
        pw, ph = 24, 16
        row_id = ys // ph
        ox = np.where((row_id & 1) == 1, pw // 2, 0)
        px_i = (xs + ox) % pw
        py_i = ys % ph
        phash = hash01_grid((xs + ox) // pw, row_id, s.seed + 139)

        field = np.clip(nb * 0.42 + phash * 0.22 + 0.26, 0.12, 0.88)
        west_out = ramp_blend(("dusk", "plum", "plum", "mauve"), field, bg)
        east_out = ramp_blend(("dusk", "plum", "plum", "mauve"), np.clip(field * 0.90, 0.10, 0.82), bg)
        out = np.where(warm * 0.72 + (nb - 0.5) * 0.24 > bg, west_out, east_out)

        # Soft Bayer-dithered armor plate seams
        seam = ((px_i == 0) | (py_i == 0)) & (bg < 0.50)
        out = np.where(seam, IX["night"], out)
        # Quiet top-left sunlit catchlight on select hull plates
        bev = (py_i == 1) & (px_i > 2) & (px_i < pw - 2) & (phash > 0.68) & (bg < 0.28)
        out = np.where(bev, IX["mauve"], out)
        # Restrained corner bolts (dark dusk by default, occasional brass rivet)
        riv = ((px_i == 2) | (px_i == pw - 3)) & ((py_i == 2) | (py_i == ph - 3))
        out = np.where(riv, np.where(phash > 0.80, IX["apricot"], IX["dusk"]), out)
        # Subtle recessed structural iron rib beams every 64px
        rib = ((xs % 64) == 0) & ((ys % 4) != 0) & (bg < 0.65)
        out = np.where(rib, IX["night"], out)
        rib_b = ((xs % 64) == 2) & ((ys % 16) == 8) & (phash > 0.42)
        out = np.where(rib_b, IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_iron_catwalk_path(buf, ctx, "plum", "wine", "dusk", "apricot", self.spec.seed + 629)

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_dark_iron_walls(buf, ctx, "colossus")

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_iron_bridge(buf, ctx, ("dusk", "plum", "wine"), "apricot", self.spec.seed + 631)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        # Recessed furnace vents & warm ember floor aprons every 44px (between pressure gauges!)
        _i6_paint_forge_aprons(buf, ctx, spacing=44, center_x=0, radius=13.5, style="furnace")
        # Subtle warm furnace bounce along walkable lips bordering molten slag channels
        near_lava = m_walk & (ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"])
        lip = near_lava & (
            (ctx["n_up_water"] & (ly < 3))
            | (ctx["n_dn_water"] & (ly >= ts - 3))
            | (ctx["n_lt_water"] & (lx < 3))
            | (ctx["n_rt_water"] & (lx >= ts - 3))
        ) & (bg < 0.40)
        buf[lip] = IX["coral"]


class ForgeDeepPainter(ThemePainter):
    """Deep Forge & Great Kiln: calm twilight slag-ashlar floors, dark iron-riveted foundry masonry & warm furnace aprons."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]

        # Dressed volcanic slag-ashlar flagstones (16x12 staggered running bond; ~75-80 luma)
        sw, sh = 16, 12
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 59)

        field = np.clip(nb * 0.42 + slab_h * 0.20 + 0.30, 0.14, 0.92)
        west_out = ramp_blend(("dusk", "plum", "plum", "wine"), field, bg)
        east_out = ramp_blend(("dusk", "plum", "plum", "mauve"), np.clip(field * 0.92, 0.12, 0.88), bg)
        out = np.where(warm * 0.68 + (nb - 0.5) * 0.26 > bg, west_out, east_out)

        # Soft Bayer-dithered mortar seams
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.46)
        out = np.where(is_seam, IX["night"], out)
        # Quiet sunlit top catchlight on select flagstones
        is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & (slab_h > 0.72) & (bg < 0.28)
        out = np.where(is_bev, IX["mauve"], out)
        # Subtle glowing volcanic mortar seams only in sparse hot foundry pockets
        hot_seam = is_seam & (nb > 0.74) & (bg < 0.34)
        out = np.where(hot_seam, IX["coral"], out)
        out = np.where((nb > 0.84) & (sx == 0) & (sy == 0), IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_iron_catwalk_path(buf, ctx, "plum", "mauve", "dusk", "apricot", self.spec.seed + 641)

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_dark_iron_walls(buf, ctx, "forge_deep")

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_iron_bridge(buf, ctx, ("dusk", "plum", "mauve"), "apricot", self.spec.seed + 643)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        # Recessed kiln-hearth furnace vents + warm ember floor aprons every 48px
        _i6_paint_forge_aprons(buf, ctx, spacing=48, center_x=24, radius=13.5, style="furnace")
        # Subtle molten ember rim bounce along walkable flagstones adjacent to magma/lava pits
        near_hot = m_walk & (
            ctx["n_up_water"] | ctx["n_dn_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
            | ctx["n_up_abyss"] | ctx["n_dn_abyss"] | ctx["n_lt_abyss"] | ctx["n_rt_abyss"]
        )
        edge_glow = near_hot & (
            ((ctx["n_up_water"] | ctx["n_up_abyss"]) & (ly == 2))
            | ((ctx["n_dn_water"] | ctx["n_dn_abyss"]) & (ly == ts - 3))
            | ((ctx["n_lt_water"] | ctx["n_lt_abyss"]) & (lx == 2))
            | ((ctx["n_rt_water"] | ctx["n_rt_abyss"]) & (lx == ts - 3))
        ) & (bg < 0.34)
        buf[edge_glow] = IX["coral"]


class KilnCavernPainter(ThemePainter):
    """Kiln Cavern lava tubes: deep volcanic slag-basalt floors, feathered stepping flagstones, ember-seamed dark basalt walls & lantern aprons."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        warp_n = fbm_grid(H, W, 30.0, seed=s.seed + 163, octaves=3)
        # Deep volcanic slag-basalt bedrock (~75-80 luma, letting magma & glowing toys pop!)
        strata = np.clip(nb * 0.42 + warp_n * 0.28 + warm * 0.08 + 0.28, 0.14, 0.90)
        out = ramp_blend(("dusk", "plum", "plum", "mauve"), strata, bg)
        # Calm natural basalt cooling crevices + subtle glowing ember seam in select hot cracks
        crack = (np.abs(warp_n - 0.46) < 0.012) & (nb < 0.62)
        out = np.where(crack, IX["night"], out)
        ember_crack = (np.abs(warp_n - 0.465) < 0.008) & (nb > 0.64) & (bg < 0.42)
        out = np.where(ember_crack, IX["coral"], out)
        out = np.where((np.abs(warp_n - 0.476) < 0.009) & (nb > 0.54) & (bg < 0.26), IX["mauve"], out)
        # Sparse volcanic obsidian & cinder flecks
        out = np.where((nf < 0.004) & (warp_n > 0.58), IX["apricot"], out)
        out = np.where((nf > 0.997) & (nb > 0.52), IX["coral"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        """Organically feathered volcanic slag stepping-flagstones (replaces noisy sand_trail confetti!)."""
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        # Underlying basalt bedrock for seamless feathered edges
        warp_n = fbm_grid(H, W, 30.0, seed=s.seed + 163, octaves=3)
        strata = np.clip(nb * 0.42 + warp_n * 0.28 + warm * 0.08 + 0.28, 0.14, 0.90)
        cavern_bg = ramp_blend(("dusk", "plum", "plum", "mauve"), strata, bg)

        d_edge = np.full((H, W), 8.0, dtype=np.float32)
        d_edge = np.where(~ctx["n_up_path"], np.minimum(d_edge, ly.astype(np.float32)), d_edge)
        d_edge = np.where(~ctx["n_dn_path"], np.minimum(d_edge, (ts - 1 - ly).astype(np.float32)), d_edge)
        d_edge = np.where(~ctx["n_lt_path"], np.minimum(d_edge, lx.astype(np.float32)), d_edge)
        d_edge = np.where(~ctx["n_rt_path"], np.minimum(d_edge, (ts - 1 - lx).astype(np.float32)), d_edge)
        feather = (d_edge + (nb - 0.5) * 3.0) / 3.2
        in_flag = feather > (bg * 0.84 + 0.12)

        # Hand-dressed staggered volcanic slag flagstones (14x10)
        sw, sh = 14, 10
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 651)

        sf = np.clip(nb * 0.34 + slab_h * 0.24 + 0.24, 0.10, 0.84)
        flag = ramp_blend(("dusk", "plum", "plum", "mauve"), sf, bg)
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.52)
        flag = np.where(is_seam, IX["night"], flag)
        is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & (slab_h > 0.66) & (bg < 0.28)
        flag = np.where(is_bev, IX["mauve"], flag)
        # Subtle warm ember curb markers on outer flagstones
        curb = (d_edge >= 1.0) & (d_edge <= 2.0) & in_flag & (~is_seam)
        flag = np.where(curb & (((xs + ys) % 8) == 0), IX["apricot"], flag)
        flag = np.where(curb & (((xs + ys) % 11) == 3) & (bg < 0.42), IX["coral"], flag)
        stud = (sx == sw // 2) & (sy == sh // 2) & (slab_h > 0.88) & (d_edge > 2.0)
        flag = np.where(stud, IX["apricot"], flag)

        out = np.where(in_flag, flag, cavern_bg)
        buf[mask] = out[mask]

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_dark_iron_walls(buf, ctx, "cavern")

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_iron_bridge(buf, ctx, ("dusk", "plum", "wine"), "apricot", self.spec.seed + 653)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        m_walk = ctx["m_walk"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        # Warm forge-lantern wall sconces & floor aprons
        _i6_paint_forge_aprons(buf, ctx, spacing=52, center_x=26, radius=13.5, style="lantern")
        # Gentle molten glow bounce on basalt rims next to lava pits
        near_hot = m_walk & (ctx["n_up_abyss"] | ctx["n_dn_abyss"] | ctx["n_lt_abyss"] | ctx["n_rt_abyss"])
        edge_glow = near_hot & (
            (ctx["n_up_abyss"] & (ly == 2))
            | (ctx["n_dn_abyss"] & (ly == ts - 3))
            | (ctx["n_lt_abyss"] & (lx == 2))
            | (ctx["n_rt_abyss"] & (lx == ts - 3))
        ) & (bg < 0.34)
        buf[edge_glow] = IX["coral"]


class AshenKilnOverworldPainter(ThemePainter):
    """Ashen Kiln Overworld: Last Light volcanic-basalt caldera terraces, dark basalt cliffs, iron-riveted slag bridges & forge beacons."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]

        # Dramatic Last Light volcanic-basalt caldera terraces: warm ember-sunset west -> cool twilight-plum east (~74-81 luma)
        sw, sh = 16, 12
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 77)

        field = np.clip(nb * 0.42 + slab_h * 0.20 + 0.30, 0.14, 0.92)
        west_out = ramp_blend(("dusk", "plum", "plum", "wine"), field, bg)
        east_out = ramp_blend(("dusk", "plum", "plum", "mauve"), np.clip(field * 0.88, 0.12, 0.86), bg)
        out = np.where(warm + (nb - 0.5) * 0.26 > bg, west_out, east_out)

        # Soft weathered terrace joints
        seam = ((sx == 0) | (sy == 0)) & (bg < 0.44) & (nb > 0.28)
        out = np.where(seam, IX["night"], out)
        # Subtle glowing cinder cracks on select volcanic basalt seams
        ember_vein = (nb > 0.74) & (((xs + ys * 2) % 21) == 0) & (bg < 0.36)
        out = np.where(ember_vein, IX["coral"], out)
        # Quiet sunlit terrace catchlights (warm west, cool twilight east)
        glint = (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.76) & (bg < 0.26)
        out = np.where(glint, np.where(warm > 0.48, IX["mauve"], IX["sky"]), out)
        # Rare warm ash cinder flecks
        out = np.where((nf > 0.997) & (nb > 0.55) & (~seam), IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_iron_catwalk_path(buf, ctx, "plum", "mauve", "dusk", "apricot", self.spec.seed + 661)

    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_dark_iron_walls(buf, ctx, "overworld")

    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _i6_paint_iron_bridge(buf, ctx, ("dusk", "plum", "wine"), "apricot", self.spec.seed + 667)

    def paint_special_floors(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        super().paint_special_floors(buf, ctx)
        # Refine overworld rail tracks: weathered timber sleepers + burnished steel rails (no glaring solid cream stripes)
        if np.any(ctx["m_rail"]):
            m = ctx["m_rail"]
            xs, ly, ts = ctx["xs"], ctx["ly"], ctx["ts"]
            bg = ctx["bg"]
            sleeper = (xs % 6) < 2
            rail_bar = (ly == 3) | (ly == 4) | (ly == ts - 5) | (ly == ts - 4)
            out = np.where(sleeper, IX["night"], IX["dusk"])
            out = np.where(sleeper & ((xs % 6) == 0) & (bg < 0.45), IX["plum"], out)
            out = np.where(rail_bar, IX["mauve"], out)
            out = np.where(((ly == 3) | (ly == ts - 5)) & (bg < 0.52), IX["apricot"], out)
            buf[m] = out[m]

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Warm forge-beacon sconces along caldera walls
        _i6_paint_forge_aprons(buf, ctx, spacing=48, center_x=24, radius=11.5, style="lantern")

        # Warm forge-beacon corner catchlights on outer caldera promontories
        m_walk = ctx["m_walk"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        c_nw = m_walk & ctx["n_up_abyss"] & ctx["n_lt_abyss"] & (lx < 6) & (ly < 6)
        c_ne = m_walk & ctx["n_up_abyss"] & ctx["n_rt_abyss"] & (lx >= ts - 6) & (ly < 6)
        c_sw = m_walk & ctx["n_dn_abyss"] & ctx["n_lt_abyss"] & (lx < 6) & (ly >= ts - 6)
        c_se = m_walk & ctx["n_dn_abyss"] & ctx["n_rt_abyss"] & (lx >= ts - 6) & (ly >= ts - 6)
        d_c = np.full(buf.shape, 99.0, dtype=np.float32)
        d_c = np.where(c_nw, np.hypot(lx - 1.5, ly - 1.5), d_c)
        d_c = np.where(c_ne, np.hypot((ts - 2.5) - lx, ly - 1.5), d_c)
        d_c = np.where(c_sw, np.hypot(lx - 1.5, (ts - 2.5) - ly), d_c)
        d_c = np.where(c_se, np.hypot((ts - 2.5) - lx, (ts - 2.5) - ly), d_c)
        buf[(d_c < 1.3)] = IX["gold"]
        buf[(d_c >= 1.3) & (d_c < 3.6) & ((1.0 - d_c / 4.0) * 0.54 > bg)] = IX["apricot"]
        buf[(d_c >= 3.6) & (d_c < 5.4) & ((1.0 - d_c / 5.6) * 0.44 > bg)] = IX["coral"]

        # Refined 8px stratified volcanic basalt cliff skirt hanging below southern island rims into starry void
        m_void = ctx["m_void"]
        n_up_land = ctx["n_up_land"]
        xs = ctx["xs"]
        warm = ctx["warm"]
        cliff = m_void & n_up_land & (ly < 8)
        if np.any(cliff):
            c0 = cliff & (ly == 0)
            buf[c0] = np.where(warm[c0] > bg[c0], IX["wine"], IX["plum"])
            c1 = cliff & (ly == 1)
            buf[c1] = np.where((xs[c1] % 7) == 0, IX["void"], np.where(warm[c1] > bg[c1], IX["plum"], IX["dusk"]))
            c2 = cliff & (ly == 2)
            buf[c2] = np.where(((xs[c2] + 3) % 7) == 0, IX["void"], IX["dusk"])
            c3 = cliff & (ly == 3)
            buf[c3] = np.where(((xs[c3] % 6) == 0) | (bg[c3] < 0.55), IX["night"], IX["dusk"])
            c4 = cliff & (ly == 4)
            buf[c4] = np.where((xs[c4] % 5) == 0, IX["void"], IX["night"])
            c5 = cliff & (ly == 5)
            buf[c5] = np.where(bg[c5] < 0.62, IX["void"], IX["night"])
            c6 = cliff & (ly == 6) & (bg < 0.48)
            buf[c6] = IX["night"]
            c7 = cliff & (ly == 7) & (bg < 0.22)
            buf[c7] = IX["night"]


SPECS_5_6: list[tuple[ThemeSpec, type[ThemePainter]]] = [
    (
        ThemeSpec(
            id="orrery",
            name="The Grand Orrery",
            island=5,
            floor_style="orrery_slate",
            floor_ramp=("deep", "dusk", "plum", "blue", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="mauve",
            floor_accent_b="apricot",
            path_style="inlaid_strip",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="masonry",
            wall_cap=("void", "night", "deep"),
            wall_lip="apricot",
            wall_face="night",
            wall_face_hi="deep",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="pine",
            water_mid="teal",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="starry_cosmos",
            rim_hi="gold",
            rim_mid="sky",
            bridge_style="stone_arch",
            bridge_main="plum",
            bridge_hi="mauve",
            bridge_rail="gold",
            bridge_dark="night",
            seed=505,
            prop_sheet="island5_scenery",
            door_sheet="island5_doors",
            special_tiles=("G:glass",),
            default_decor=("circle", "compass"),
            notes="Unified Grand Clockwork Orrery: luminous twilight-slate flagstones, refined brass causeways & warm sconce dome walls.",
        ),
        OrreryPainter,
    ),
    (
        ThemeSpec(
            id="meteor_vault",
            name="The Meteor Vault",
            island=5,
            floor_style="meteor_basalt",
            floor_ramp=("deep", "dusk", "plum", "blue"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="mauve",
            floor_accent_b="apricot",
            path_style="inlaid_strip",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="riveted_iron",
            wall_cap=("void", "night", "dusk"),
            wall_lip="apricot",
            wall_face="night",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="pine",
            water_mid="teal",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="starry_cosmos",
            rim_hi="ice",
            rim_mid="apricot",
            bridge_style="iron_grate",
            bridge_main="dusk",
            bridge_hi="mauve",
            bridge_rail="gold",
            bridge_dark="night",
            seed=511,
            prop_sheet="theme_meteor_vault",
            door_sheet="theme_meteor_vault_doors",
            special_tiles=(),
            default_decor=("cracks", "circle", "compass"),
            notes="Cosmic asteroid treasury: calm dressed basalt slabs, brass-inlaid ashlar paths & warm sconce iron-dome walls.",
        ),
        MeteorVaultPainter,
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
            floor_accent_a="mauve",
            floor_accent_b="apricot",
            path_style="inlaid_strip",
            path_main="deep",
            path_hi="blue",
            path_edge="night",
            path_trim="apricot",
            wall_style="marble_balustrade",
            wall_cap=("void", "night", "deep"),
            wall_lip="gold",
            wall_face="night",
            wall_face_hi="blue",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="pine",
            water_mid="teal",
            water_hi="sky",
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
            notes="Grand star-chart dome: twilight-sapphire stone, vaulted skylight pilaster walls & warm brass sconce pools.",
        ),
        PlanetariumPainter,
    ),
    (
        ThemeSpec(
            id="freefall",
            name="Observatory Freefall",
            island=5,
            floor_style="shattered_debris",
            floor_ramp=("deep", "dusk", "blue", "mauve"),
            floor_seam="night",
            floor_bevel="sky",
            floor_accent_a="mauve",
            floor_accent_b="apricot",
            path_style="inlaid_strip",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="marble_balustrade",
            wall_cap=("void", "night", "dusk"),
            wall_lip="mauve",
            wall_face="night",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="pine",
            water_mid="teal",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="sky_freefall",
            rim_hi="ice",
            rim_mid="gold",
            bridge_style="stone_arch",
            bridge_main="plum",
            bridge_hi="mauve",
            bridge_rail="gold",
            bridge_dark="deep",
            seed=531,
            prop_sheet="theme_freefall",
            door_sheet="theme_freefall_doors",
            special_tiles=(),
            default_decor=("cracks", "circle"),
            notes="Mid-air observatory collapse: twilight-lavender fractured masonry & broken-skylight dome parapets over rushing star wind.",
        ),
        FreefallPainter,
    ),
    (
        ThemeSpec(
            id="starfall_geode",
            name="Starfall Geode Cavern",
            island=5,
            floor_style="cave_floor",
            floor_ramp=("deep", "dusk", "blue", "mauve"),
            floor_seam="night",
            floor_bevel="sky",
            floor_accent_a="mauve",
            floor_accent_b="apricot",
            path_style="inlaid_strip",
            path_main="dusk",
            path_hi="blue",
            path_edge="night",
            path_trim="apricot",
            wall_style="cavern_rock",
            wall_cap=("void", "night", "deep"),
            wall_lip="sky",
            wall_face="night",
            wall_face_hi="blue",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="pine",
            water_mid="teal",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="starry_cosmos",
            rim_hi="ice",
            rim_mid="gold",
            bridge_style="stone_arch",
            bridge_main="plum",
            bridge_hi="mauve",
            bridge_rail="gold",
            bridge_dark="night",
            seed=541,
            prop_sheet="theme_cave_5",
            door_sheet="theme_cave_5_doors",
            special_tiles=(),
            default_decor=("cracks", "light_shaft"),
            notes="Starfall geode hollows: calm twilight cavern stone, hand-dressed stepping flagstones, crypt arches & warm sconce glow.",
        ),
        StarfallGeodePainter,
    ),
    (
        ThemeSpec(
            id="starfall_overworld",
            name="Starfall Observatory Overworld",
            island=5,
            floor_style="orrery_slate",
            floor_ramp=("deep", "dusk", "plum", "blue", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="mauve",
            floor_accent_b="apricot",
            path_style="inlaid_strip",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="masonry",
            wall_cap=("void", "night", "deep"),
            wall_lip="gold",
            wall_face="night",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="moon_mirror",
            water_deep="pine",
            water_mid="teal",
            water_hi="sky",
            water_foam="ice",
            pit_style="star_chasm",
            void_style="starry_cosmos",
            rim_hi="sky",
            rim_mid="gold",
            bridge_style="timber",
            bridge_main="plum",
            bridge_hi="wine",
            bridge_rail="gold",
            bridge_dark="night",
            seed=501,
            organic_edges=True,
            prop_sheet="island5_scenery",
            door_sheet="island5_doors",
            special_tiles=(),
            default_decor=("circle", "compass"),
            notes="Starfall Observatory archipelago: luminous twilight terraces, brass-trimmed causeways, calm timber-brass bridges & cliff skirts.",
        ),
        StarfallOverworldPainter,
    ),
    (
        ThemeSpec(
            id="ember_express",
            name="The Ember Express (Interior)",
            island=6,
            floor_style="train_carpet_deck",
            floor_ramp=("dusk", "plum", "wine"),
            floor_seam="night",
            floor_bevel="coral",
            floor_accent_a="wine",
            floor_accent_b="apricot",
            path_style="carpet_runner",
            path_main="wine",
            path_hi="coral",
            path_edge="night",
            path_trim="apricot",
            wall_style="riveted_iron",
            wall_cap=("void", "night", "dusk"),
            wall_lip="apricot",
            wall_face="night",
            wall_face_hi="plum",
            wall_base="void",
            water_style="magma_river",
            water_deep="wine",
            water_mid="coral",
            water_hi="apricot",
            water_foam="gold",
            pit_style="lava_pit",
            void_style="train_rush",
            rim_hi="apricot",
            rim_mid="plum",
            bridge_style="iron_grate",
            bridge_main="plum",
            bridge_hi="mauve",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=611,
            prop_sheet="theme_ember_express",
            door_sheet="theme_ember_express_doors",
            special_tiles=("D:carpet", "H:grate", "R:rail"),
            default_decor=("rug", "grate", "window_strip"),
            notes="Moving foundry train interior: satin twilight-mahogany floorboards, plush crimson-wine velvet runners, dark walnut-brass cabin walls & carriage lamps.",
        ),
        EmberExpressInteriorPainter,
    ),
    (
        ThemeSpec(
            id="ember_express_roof",
            name="The Ember Express (Roof)",
            island=6,
            floor_style="train_roof_plate",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="coral",
            floor_accent_b="apricot",
            path_style="catwalk_grate",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="riveted_iron",
            wall_cap=("void", "night", "dusk"),
            wall_lip="apricot",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="magma_river",
            water_deep="wine",
            water_mid="coral",
            water_hi="apricot",
            water_foam="gold",
            pit_style="lava_pit",
            void_style="train_rush",
            rim_hi="apricot",
            rim_mid="plum",
            bridge_style="iron_grate",
            bridge_main="plum",
            bridge_hi="wine",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=617,
            prop_sheet="theme_ember_express_roof",
            door_sheet="theme_ember_express_doors",
            special_tiles=("H:grate", "R:rail"),
            default_decor=("grate", "cracks"),
            notes="Speeding carriage rooftops: weathered dark riveted iron roofs, calm catwalks, ember sparks & warm signal lantern aprons.",
        ),
        EmberExpressRoofPainter,
    ),
    (
        ThemeSpec(
            id="iron_colossus",
            name="The Iron Colossus",
            island=6,
            floor_style="colossus_hull",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="wine",
            floor_accent_b="apricot",
            path_style="catwalk_grate",
            path_main="plum",
            path_hi="wine",
            path_edge="night",
            path_trim="apricot",
            wall_style="riveted_iron",
            wall_cap=("void", "night", "dusk"),
            wall_lip="apricot",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="magma_river",
            water_deep="wine",
            water_mid="coral",
            water_hi="apricot",
            water_foam="gold",
            pit_style="gear_chasm",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="plum",
            bridge_style="iron_grate",
            bridge_main="plum",
            bridge_hi="wine",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=621,
            prop_sheet="theme_iron_colossus",
            door_sheet="theme_iron_colossus_doors",
            special_tiles=("H:grate", "R:rail"),
            default_decor=("grate", "circle", "cracks"),
            notes="Inside the walking giant: oiled-iron twilight deck plating, monumental dark riveted hull walls with brass pressure gauges & furnace aprons.",
        ),
        IronColossusPainter,
    ),
    (
        ThemeSpec(
            id="forge_deep",
            name="The Deep Forge",
            island=6,
            floor_style="forge_anvil_hall",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="coral",
            floor_accent_b="apricot",
            path_style="catwalk_grate",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="masonry",
            wall_cap=("void", "night", "dusk"),
            wall_lip="coral",
            wall_face="night",
            wall_face_hi="dusk",
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
            bridge_main="plum",
            bridge_hi="mauve",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=631,
            prop_sheet="theme_forge_deep",
            door_sheet="theme_forge_deep_doors",
            special_tiles=("H:grate",),
            default_decor=("grate", "cracks", "circle"),
            notes="First Forge & deep Great Kiln: calm twilight slag-ashlar flagstones, dark iron-riveted foundry masonry & warm furnace sconce aprons.",
        ),
        ForgeDeepPainter,
    ),
    (
        ThemeSpec(
            id="ashen_kiln",
            name="Ashen Kiln Overworld",
            island=6,
            floor_style="cave_floor",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="coral",
            floor_accent_b="apricot",
            path_style="flagstone",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="cavern_rock",
            wall_cap=("void", "night", "dusk"),
            wall_lip="apricot",
            wall_face="night",
            wall_face_hi="dusk",
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
            bridge_main="plum",
            bridge_hi="wine",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=601,
            organic_edges=True,
            prop_sheet="island6_scenery",
            door_sheet="island6_doors",
            special_tiles=("H:grate", "R:rail"),
            default_decor=("cracks", "grate"),
            notes="Ashen Kiln volcanic caldera archipelago: Last Light volcanic-basalt terraces, dark stratified cliffs, cliff skirts, forge beacons & iron bridges.",
        ),
        AshenKilnOverworldPainter,
    ),
    (
        ThemeSpec(
            id="kiln_cavern",
            name="Ashen Kiln Lava Tube",
            island=6,
            floor_style="cave_floor",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="coral",
            floor_accent_b="apricot",
            path_style="flagstone",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="cavern_rock",
            wall_cap=("void", "night", "dusk"),
            wall_lip="coral",
            wall_face="night",
            wall_face_hi="dusk",
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
            bridge_main="plum",
            bridge_hi="wine",
            bridge_rail="apricot",
            bridge_dark="night",
            seed=606,
            prop_sheet="theme_cave_6",
            door_sheet="theme_cave_6_doors",
            special_tiles=(),
            default_decor=("cracks", "stain", "light_shaft"),
            notes="Ashen Kiln lava-tube caverns: deep volcanic slag-basalt bedrock, feathered stepping flagstones, ember-seamed dark basalt walls & lantern aprons.",
        ),
        KilnCavernPainter,
    ),
]
