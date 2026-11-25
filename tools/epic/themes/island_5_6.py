"""Islands 5 & 6 themes: orrery, meteor_vault, planetarium, freefall, starfall_geode, starfall_overworld, ember_express (interior+roof), iron_colossus, forge_deep."""
from __future__ import annotations

from typing import Any

import numpy as np

from .base import ThemePainter, ThemeSpec
from .kit import IX, SHADE_IX, fbm_grid, hash01_grid, ramp_blend


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
        buf[lintel] = IX["gold"]
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
        buf[ore & (rx == 13)] = IX["ice"]
        buf[ore & (rx == 15)] = IX["gold"]

    elif mode == "planetarium":
        buf[dome_arc] = IX["deep"]
        # Meridian dome ribs every 32px
        rx = xs % 32
        rib = m_wall & ((rx == 0) | (rx == 1))
        buf[rib & cap_interior & (bg < 0.70)] = IX["deep"]
        buf[rib & dn_open & (ly >= ts - 6) & (ly < ts - 1)] = IX["blue"]
        buf[m_wall & (rx == 0) & dn_open & (ly == ts - 6)] = IX["gold"]
        # Arched starry clerestory skylights recessed along south-facing walls
        sky_w = m_wall & dn_open & (rx >= 10) & (rx <= 22) & (ly >= ts - 5) & (ly <= ts - 2)
        arch = sky_w & ~((ly == ts - 5) & ((rx == 10) | (rx == 22)))
        buf[arch] = IX["deep"]
        # Central skylight mullion & starlight panes
        mull = arch & (rx == 16)
        buf[mull] = IX["night"]
        star_l = arch & (ly == ts - 4) & ((rx == 13) | (rx == 19))
        buf[star_l] = IX["ice"]
        buf[arch & (ly == ts - 3) & ((rx == 12) | (rx == 20))] = IX["sky"]
        # Gilded arch crown
        buf[m_wall & dn_open & (ly == ts - 6) & (rx >= 12) & (rx <= 20)] = IX["gold"]

    elif mode == "freefall":
        buf[dome_arc] = IX["dusk"]
        # Broken observatory skylight bays & jagged ruined dome ribs every 28px
        rx = xs % 28
        rib = m_wall & ((rx == 0) | (rx == 1))
        buf[rib & cap_interior & (bg < 0.65)] = IX["dusk"]
        buf[rib & dn_open & (ly >= ts - 6) & (ly < ts - 1)] = IX["mauve"]
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
    """Grand Clockwork Orrery (unified for orrery_r1..r16): luminous twilight slate, brass arcs & dome ribs."""

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

        # Luminous twilight slate-indigo flagstones (~74-82 luma)
        field = np.clip(nb * 0.44 + slab_h * 0.28 + warm * 0.08 + 0.16, 0.06, 0.86)
        out = ramp_blend(s.floor_ramp, field, bg)
        # Soft Bayer-dithered mortar seams (calm, never harsh dark grid)
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.46)
        out = np.where(is_seam, IX["night"], out)
        # Gentle top-left sunlit catchlight on select dressed stones
        is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & (slab_h > 0.70) & (bg < 0.34)
        out = np.where(is_bev, IX["mauve"], out)
        # Quiet room-centered brass astrolabe meridian arc inlaid into walkable stonework
        cx, cy = W * 0.5, H * 0.5
        rad = np.hypot(xs - cx, (ys - cy) * 1.08)
        arc = (np.abs(rad - 58.0) < 0.65) | (np.abs(rad - 98.0) < 0.65)
        out = np.where(arc & (((xs + ys) % 4) < 2) & (~is_seam), IX["apricot"], out)
        # Ultra-sparse gilded brass pin at select intersections
        pin = (sx == 8) & (sy == 6) & (slab_h > 0.94) & (nf > 0.5)
        out = np.where(pin, IX["gold"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "orrery")


class MeteorVaultPainter(ThemePainter):
    """Meteor Vault: calm volcanic-indigo basalt slabs (zero noisy crack static!), dark iron-dome walls."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]

        # Large calm dressed asteroid-basalt slabs (20x14 staggered ashlar)
        sw, sh = 20, 14
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 109)

        # Calibrated mid-tone asteroid basalt (~72-80 luma, clean figure-ground clarity!)
        field = np.clip(nb * 0.44 + slab_h * 0.30 + warm * 0.08 + 0.24, 0.12, 0.92)
        out = ramp_blend(s.floor_ramp, field, bg)
        # Soft Bayer-dithered seams (NEVER bright gold/ice confetti cracks!)
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.50)
        out = np.where(is_seam, IX["night"], out)
        # Quiet top-left catchlight on weathered basalt faces
        is_bev = (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.72) & (bg < 0.30)
        out = np.where(is_bev, IX["mauve"], out)
        # Very subtle embedded star-ore glints tucked strictly near rare block corners (<0.25%)
        glint_a = (sx == 2) & (sy == 2) & (slab_h > 0.92) & (nb > 0.52)
        glint_b = (sx == sw - 3) & (sy == sh - 3) & (slab_h < 0.08) & (nb < 0.48)
        out = np.where(glint_a, IX["gold"], out)
        out = np.where(glint_b, IX["ice"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "meteor")


class PlanetariumPainter(ThemePainter):
    """Planetarium: smooth satin sapphire-indigo star dome (~80 luma), dark arched skylight dome walls."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        # Smooth satin sapphire-indigo dome stone (~78-86 luma; calmer than old 108 glare)
        field = np.clip(nb * 0.42 + warm * 0.10 + 0.18, 0.06, 0.62)
        out = ramp_blend(s.floor_ramp, field, bg)
        # Fine 32x32 meridian grid (dashed deep/night so floor stays calm)
        grid_line = (((xs % 32 == 0) & (ys % 2 == 0)) | ((ys % 32 == 0) & (xs % 2 == 0))) & (bg < 0.70)
        out = np.where(grid_line, IX["deep"], out)
        # Star intersection crosses
        node = (xs % 32 == 0) & (ys % 32 == 0)
        node_arm = ((np.abs((xs % 32) - 0) <= 1) & (ys % 32 == 0)) | ((xs % 32 == 0) & (np.abs((ys % 32) - 0) <= 1))
        out = np.where(node_arm, IX["apricot"], out)
        out = np.where(node, IX["cream"], out)
        # Concentric gilded celestial dome arcs centered in room
        cx, cy = W * 0.5, H * 0.5
        rad = np.hypot(xs - cx, (ys - cy) * 1.1)
        arc = (np.abs(rad - 54.0) < 0.75) | (np.abs(rad - 92.0) < 0.75)
        out = np.where(arc & (((xs + ys) % 3) != 0), IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "planetarium")


class FreefallPainter(ThemePainter):
    """Observatory Freefall: twilight-lavender shattered masonry (~84 luma) & broken-skylight dark parapets."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, warm = ctx["bg"], ctx["n_broad"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        sx = xs % 16
        sy = ys % 12
        row_id = ys // 12
        ox = np.where((row_id & 1) == 1, 7, 0)
        cx_s = (xs + ox) % 16
        sh = hash01_grid((xs + ox) // 16, row_id, s.seed + 127)

        # Calibrated windswept twilight marble (~80-88 luma; calmer than old 138 glare)
        field = np.clip(nb * 0.42 + sh * 0.24 + warm * 0.08 + 0.14, 0.06, 0.72)
        out = ramp_blend(s.floor_ramp, field, bg)
        is_seam = ((cx_s == 0) | (sy == 0)) & (bg < 0.56)
        out = np.where(is_seam, IX["deep"], out)
        out = np.where((sy == 1) & (cx_s > 1) & (sh > 0.58) & (bg < 0.40), IX["ice"], out)
        # Subtle organic fracture cracks across floating marble fragments
        frac_n = np.abs(fbm_grid(H, W, 26.0, seed=s.seed + 131, octaves=2) - 0.5)
        out = np.where(frac_n < 0.015, IX["night"], out)
        out = np.where((frac_n >= 0.015) & (frac_n < 0.023) & (bg < 0.40), IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "freefall")


class StarfallGeodePainter(ThemePainter):
    """Starfall Geode Caverns: calm twilight cavern stone (~76 luma), carved crypt arches & teal star water."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        warp_n = fbm_grid(H, W, 32.0, seed=s.seed + 163, octaves=3)
        strata = np.clip(nb * 0.46 + warp_n * 0.30 + warm * 0.06 + 0.16, 0.08, 0.80)
        out = ramp_blend(s.floor_ramp, strata, bg)
        # Calm natural bedrock crevices
        crack = (np.abs(warp_n - 0.46) < 0.012) & (nb < 0.56)
        out = np.where(crack, IX["night"], out)
        out = np.where((np.abs(warp_n - 0.475) < 0.010) & (nb > 0.54) & (bg < 0.38), IX["sky"], out)
        # Sparse quartz & star-brass mineral flecks
        out = np.where((nf < 0.005) & (warp_n > 0.58), IX["gold"], out)
        out = np.where((nf > 0.996) & (nb > 0.50), IX["ice"], out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "geode")


class StarfallOverworldPainter(ThemePainter):
    """Starfall Observatory Overworld: luminous twilight archipelago (~76 luma), dark parapets & cliff skirts."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]

        # Warm twilight observatory terrace pavers (~72-80 luma, lifting legacy 56.8)
        sw, sh = 16, 12
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 77)

        field = np.clip(nb * 0.42 + slab_h * 0.24 + warm * 0.14 + 0.14, 0.06, 0.84)
        out = ramp_blend(s.floor_ramp, field, bg)
        # Soft weathered terrace paving joints
        seam = ((sx == 0) | (sy == 0)) & (bg < 0.40) & (nb > 0.32)
        out = np.where(seam, IX["night"], out)
        # Gentle twilight grass/star-moss flecks near cool outer terraces
        moss = (nb < 0.28) & (nf < 0.04) & (~seam)
        out = np.where(moss, IX["teal"], out)
        # Sparse warm sunset catchlights on western flagstones
        glint = (sy == 1) & (sx > 2) & (sx < sw - 2) & (slab_h > 0.76) & (bg < 0.26)
        out = np.where(glint, np.where(warm > 0.45, IX["mauve"], IX["sky"]), out)
        buf[mask] = out[mask]

    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_star_water(buf, ctx, self.spec.seed)

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        _paint_observatory_walls(buf, ctx, "overworld")
        # Sculpted terraced twilight cliff skirt hanging below southern island rims into starry void
        m_void = ctx["m_void"]
        n_up_land = ctx["n_up_land"]
        xs, ly = ctx["xs"], ctx["ly"]
        bg = ctx["bg"]
        cliff = m_void & n_up_land & (ly < 6)
        buf[cliff & (ly == 0)] = IX["blue"]
        buf[cliff & (ly == 1)] = IX["deep"]
        c2 = cliff & (ly == 2)
        buf[c2] = np.where(((xs[c2] % 4) == 0) | (bg[c2] < 0.50), IX["dusk"], IX["deep"])
        buf[cliff & (ly == 3)] = IX["dusk"]
        c4 = cliff & (ly == 4)
        buf[c4] = np.where(bg[c4] < 0.65, IX["night"], IX["dusk"])
        buf[cliff & (ly == 5) & (bg < 0.55)] = IX["night"]


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
        c2 = cliff & (ly == 2)
        buf[c2] = np.where(((xs[c2] % 4) == 0) | (bg[c2] < 0.5), IX["dusk"], IX["plum"])
        buf[cliff & (ly == 3)] = IX["dusk"]
        c4 = cliff & (ly == 4)
        buf[c4] = np.where(bg[c4] < 0.65, IX["night"], IX["dusk"])
        buf[cliff & (ly == 5) & (bg < 0.55)] = IX["night"]
        # Subtle glowing cinder cracks on open volcanic ash terraces
        m_ground = ctx["m_ground"]
        nb = ctx["n_broad"]
        ember_vein = m_ground & (nb > 0.76) & (((xs + ctx["ys"] * 2) % 19) == 0) & (bg < 0.45)
        buf[ember_vein] = IX["coral"]


SPECS_5_6: list[tuple[ThemeSpec, type[ThemePainter]]] = [
    (
        ThemeSpec(
            id="orrery",
            name="The Grand Orrery",
            island=5,
            floor_style="orrery_slate",
            floor_ramp=("deep", "dusk", "blue", "mauve"),
            floor_seam="night",
            floor_bevel="mauve",
            floor_accent_a="apricot",
            floor_accent_b="gold",
            path_style="inlaid_strip",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="gold",
            wall_style="masonry",
            wall_cap=("void", "night", "deep"),
            wall_lip="sky",
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
            default_decor=("circle", "compass", "inlay"),
            notes="Unified Grand Clockwork Orrery: luminous twilight-slate flagstones, subtle brass astrolabe arcs & vaulted dome walls.",
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
            floor_accent_a="gold",
            floor_accent_b="ice",
            path_style="inlaid_strip",
            path_main="plum",
            path_hi="mauve",
            path_edge="night",
            path_trim="apricot",
            wall_style="riveted_iron",
            wall_cap=("void", "night", "dusk"),
            wall_lip="sky",
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
            notes="Cosmic asteroid treasury: calm dressed basalt slabs with sparse mineral glints & dark vaulted iron-dome walls.",
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
            floor_accent_a="apricot",
            floor_accent_b="cream",
            path_style="inlaid_strip",
            path_main="blue",
            path_hi="sky",
            path_edge="night",
            path_trim="gold",
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
            notes="Grand star-chart dome: satin sapphire-indigo stone with gilded meridian grids & dark clerestory skylight dome walls.",
        ),
        PlanetariumPainter,
    ),
    (
        ThemeSpec(
            id="freefall",
            name="Observatory Freefall",
            island=5,
            floor_style="shattered_debris",
            floor_ramp=("dusk", "blue", "mauve", "stone"),
            floor_seam="deep",
            floor_bevel="ice",
            floor_accent_a="apricot",
            floor_accent_b="gold",
            path_style="inlaid_strip",
            path_main="mauve",
            path_hi="stone",
            path_edge="dusk",
            path_trim="gold",
            wall_style="marble_balustrade",
            wall_cap=("void", "night", "dusk"),
            wall_lip="ice",
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
            bridge_main="mauve",
            bridge_hi="stone",
            bridge_rail="gold",
            bridge_dark="deep",
            seed=531,
            prop_sheet="theme_freefall",
            door_sheet="theme_freefall_doors",
            special_tiles=(),
            default_decor=("cracks", "circle"),
            notes="Mid-air observatory collapse: twilight-lavender fractured masonry & broken-skylight dark parapets over rushing star wind.",
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
            floor_accent_a="gold",
            floor_accent_b="ice",
            path_style="sand_trail",
            path_main="plum",
            path_hi="mauve",
            path_edge="deep",
            path_trim="gold",
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
            default_decor=("cracks", "circle"),
            notes="Starfall geode hollows: calm twilight cavern stone, carved observatory crypt arches & luminous teal-cyan star water.",
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
            floor_accent_a="apricot",
            floor_accent_b="gold",
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
            bridge_main="wine",
            bridge_hi="coral",
            bridge_rail="gold",
            bridge_dark="night",
            seed=501,
            organic_edges=True,
            prop_sheet="island5_scenery",
            door_sheet="island5_doors",
            special_tiles=(),
            default_decor=("circle", "compass"),
            notes="Starfall Observatory archipelago: luminous twilight terraces, warm brass-trimmed causeways, dark parapets & cliff skirts.",
        ),
        StarfallOverworldPainter,
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
            floor_ramp=("wine", "mauve", "stone"),
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
