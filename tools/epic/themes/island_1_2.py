"""Islands 0, 1 & 2 themes: undercroft, manor, great_toll_shaft, bell_outer, wick_cellar, lighthouse, galleon, locks, leviathan_belly, seabed."""
from __future__ import annotations

from typing import Any

import numpy as np

from .base import ThemePainter, ThemeSpec
from .kit import IX, LIGHT_IX, SHADE_IX, chamfer_dist, fbm_grid, hash01_grid, ramp_blend


class UndercroftPainter(ThemePainter):
    """Bell Isle catacombs: calm luminous flagstones (luma ~76-84), arched bone niches & crisp blue water."""

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

        sh, sw = 10, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 59)

        # Calm mid-tone catacomb slate: dusk -> plum -> mauve (~76-84 luma), clearly above dark walls (~44) & void (~14)
        slab_f = np.clip(nb * 0.46 + slab_h * 0.34 + warm * 0.08 + 0.14, 0.0, 0.96)
        out = ramp_blend(s.floor_ramp, slab_f, bg)

        # Soft Bayer-dithered mortar seams (never a harsh black brick grid)
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.56)
        out = np.where(is_seam, IX["night"], out)
        # Gentle top-left catchlight on worn flagstones
        is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & (slab_h > 0.68) & (bg < 0.36)
        out = np.where(is_bev, IX["stone"], out)
        # Damp moss veins near water/cool corners + sparse bronze echo flecks
        damp = (nb < 0.28) & (nf < 0.10) & (~is_seam)
        out = np.where(damp, IX["pine"], out)
        out = np.where((sx == 8) & (sy == 5) & (slab_h > 0.91), IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys, lx, ly, ts = ctx["xs"], ctx["ys"], ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb = ctx["bg"], ctx["n_broad"]

        is_edge = (
            ((~ctx["n_up_path"]) & (ly == 0))
            | ((~ctx["n_dn_path"]) & (ly == ts - 1))
            | ((~ctx["n_lt_path"]) & (lx == 0))
            | ((~ctx["n_rt_path"]) & (lx == ts - 1))
        )
        is_inner = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )
        main, hi, edge, trim = IX[s.path_main], IX[s.path_hi], IX[s.path_edge], IX[s.path_trim]
        dk = SHADE_IX[main]
        out = np.full(buf.shape, main, dtype=np.uint8)
        out = np.where((nb > 0.54) & (bg < 0.42), hi, out)
        out = np.where((((xs + ys) % 8) == 0) & (bg < 0.32), dk, out)
        out = np.where(is_inner & (((xs + ys) % 3) != 0), trim, out)
        out = np.where(is_edge, edge, out)
        buf[mask] = out[mask]

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
    """Bellmaker's Manor: calm satin-wood parquet (zero visual static!), velvet runners & gilded portraits."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        warm = ctx["warm"]

        # Calm 16x16 alternating satin-wood parquet panels (low-contrast dusk/plum/wine, luma ~74-82)
        bx = xs // 16
        by = ys // 16
        horiz = ((bx + by) & 1) == 0
        pl_i = np.where(horiz, ys % 8, xs % 8)
        pl_id = np.where(horiz, ys // 8, xs // 8)
        bh = hash01_grid(bx, by * 7 + pl_id, s.seed + 71)
        tile_tone = np.where(horiz, 0.08, -0.05)
        field = np.clip(nb * 0.44 + bh * 0.24 + warm * 0.10 + tile_tone + 0.14, 0.0, 0.88)
        out = ramp_blend(s.floor_ramp, field, bg)

        # Soft dithered panel joints (never stark black-and-apricot TV static)
        panel_edge = ((xs % 16 == 0) | (ys % 16 == 0)) & (bg < 0.52)
        plank_seam = (pl_i == 0) & (bg < 0.34)
        out = np.where(panel_edge | plank_seam, IX["dusk"], out)
        out = np.where((xs % 16 == 0) & (ys % 16 == 0), IX["night"], out)

        # Quiet satin sheen on select boards + sparse subtle gilded marquetry pins
        sheen = (pl_i == 1) & (~panel_edge) & (bh > 0.78) & (bg < 0.22)
        out = np.where(sheen, IX["mauve"], out)
        pin = (xs % 16 == 8) & (ys % 16 == 8) & (bh > 0.88)
        out = np.where(pin, IX["apricot"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys, lx, ly, ts = ctx["xs"], ctx["ys"], ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb = ctx["bg"], ctx["n_broad"]

        is_edge = (
            ((~ctx["n_up_path"]) & (ly == 0))
            | ((~ctx["n_dn_path"]) & (ly == ts - 1))
            | ((~ctx["n_lt_path"]) & (lx == 0))
            | ((~ctx["n_rt_path"]) & (lx == ts - 1))
        )
        is_inner = (
            ((~ctx["n_up_path"]) & (ly == 1))
            | ((~ctx["n_dn_path"]) & (ly == ts - 2))
            | ((~ctx["n_lt_path"]) & (lx == 1))
            | ((~ctx["n_rt_path"]) & (lx == ts - 2))
        )
        main, hi, edge, trim = IX[s.path_main], IX[s.path_hi], IX[s.path_edge], IX[s.path_trim]
        dk = SHADE_IX[main]
        # Refined velvet wine runner: calm plush weave + crisp warm trim border (no noisy per-tile diamonds)
        out = np.full(buf.shape, main, dtype=np.uint8)
        out = np.where((nb > 0.62) & (bg < 0.34), hi, out)
        out = np.where((((xs + ys) % 8) == 0) & (bg < 0.32), dk, out)
        out = np.where(is_inner & (((xs + ys) % 4) != 0), trim, out)
        out = np.where(is_edge, edge, out)
        buf[mask] = out[mask]

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


class BellOuterPainter(ThemePainter):
    """Island 1 outer zones: organic meadow + domain-warped worn paths that break rigid '+' crosshairs in paint."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]
        rid = str(ctx.get("meta", {}).get("id", "")).lower()

        if "graveyard" in rid:
            ramp = ("pine", "teal", "jade")
            field = np.clip(nb * 0.68 + warm * 0.14 + 0.08, 0.0, 0.94)
        elif "manor" in rid:
            ramp = ("pine", "teal", "jade", "lime")
            field = np.clip(nb * 0.64 + warm * 0.16 + 0.10, 0.0, 0.92)
        elif "forecourt" in rid:
            ramp = ("pine", "teal", "jade")
            field = np.clip(nb * 0.66 + warm * 0.18 + 0.10, 0.0, 0.95)
        else:
            ramp = ("pine", "teal", "jade", "lime")
            field = np.clip(nb * 0.64 + warm * 0.20 + 0.12, 0.0, 0.96)

        out = ramp_blend(ramp, field, bg)
        # Subtle grass tuft strokes & sparse clover/petals (calm, organic meadow)
        tuft = (nf < 0.014) & (nb > 0.35)
        out = np.where(tuft, LIGHT_IX[out], out)
        shade_t = (nf > 0.986) & (nb < 0.65)
        out = np.where(shade_t, SHADE_IX[out], out)
        if "manor" in rid:
            # Asymmetric drifting estate rose petals in NW quadrant
            petal = (nf > 0.996) & (xs < ctx["W"] * 0.62) & (ys < ctx["H"] * 0.58)
            out = np.where(petal, IX["rose"], out)
        elif "yard" in rid:
            blossom = (nf > 0.9965) & (nb > 0.58)
            out = np.where(blossom, IX["gold"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        s = self.spec
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]
        rid = str(ctx.get("meta", {}).get("id", "")).lower()

        # Paint meadow grass underneath path first so encroaching grass & moss blends seamlessly!
        grass_buf = buf.copy()
        saved_m = ctx["m_ground"]
        ctx["m_ground"] = mask
        self.paint_floor(grass_buf, ctx)
        ctx["m_ground"] = saved_m

        # Asymmetric domain-warped distance inward from non-path tiles breaks straight '+' edges organically!
        dist_in = chamfer_dist(mask)
        # Per-zone seed shift + low-frequency meander warp so left/right & top/bottom NEVER mirror
        z_off = sum(ord(ch) for ch in rid) % 97
        warp_lo = fbm_grid(H, W, 44.0, seed=s.seed + 301 + z_off, octaves=2)
        warp_hi = fbm_grid(H, W, 18.0, seed=s.seed + 317 + z_off, octaves=2)
        # Asymmetric lateral bias shifts apparent trail centerline off-axis
        asym_bias = (warp_lo - 0.5) * 9.5 + (warp_hi - 0.5) * 4.5
        # Keep doorway approaches (near map border or exits) firmer; meander more in the open interior
        border_d = np.minimum(np.minimum(xs, W - 1 - xs), np.minimum(ys, H - 1 - ys)).astype(np.float32)
        interior_w = np.clip((border_d - 22.0) / 36.0, 0.15, 1.0)
        eff_dist = dist_in + asym_bias * interior_w

        # Weathered irregular cobble / stepping-stone pattern
        row_id = ys // 7
        ox = np.where((row_id & 1) == 1, 5, 0) + (warp_hi * 4.0).astype(np.int32)
        cx = (xs + ox) % 10
        cy = ys % 7
        st_h = hash01_grid((xs + ox) // 10, row_id, s.seed + 331 + z_off)

        if "graveyard" in rid:
            stone_ramp = ("dusk", "mauve", "stone")
            stone_f = np.clip(nb * 0.45 + st_h * 0.35 + 0.08, 0.0, 0.85)
        elif "forecourt" in rid:
            stone_ramp = ("dusk", "mauve", "stone")
            stone_f = np.clip(nb * 0.42 + st_h * 0.36 + warm * 0.14 + 0.12, 0.0, 0.92)
        else:
            stone_ramp = ("plum", "mauve", "stone")
            stone_f = np.clip(nb * 0.44 + st_h * 0.36 + warm * 0.12 + 0.12, 0.0, 0.92)

        cobble = ramp_blend(stone_ramp, stone_f, bg)
        # Irregular worn cobble joints (broken by moss/earth, never ruler-straight grids)
        joint = ((cx == 0) | (cy == 0)) & (bg < 0.58)
        cobble = np.where(joint, IX["dusk"] if "graveyard" not in rid else IX["night"], cobble)
        # Moss creeping between outer cobbles
        moss_joint = joint & (eff_dist < 8.5) & (warp_hi < 0.58)
        cobble = np.where(moss_joint, IX["pine"], cobble)

        # Grass encroachment along path rim (eff_dist < 3.6 -> grass; 3.6..6.8 -> mossy dithered stepping stones)
        is_grass = eff_dist < 3.4
        is_step_zone = (eff_dist >= 3.4) & (eff_dist < 7.2)
        step_stone = (cx >= 2) & (cx <= 7) & (cy >= 1) & (cy <= 5) & (st_h > 0.38)
        # Organic wear patches inside wider plazas (moss islands break up big square path blocks!)
        moss_patch = (dist_in > 9.0) & (warp_lo < 0.32) & (warp_hi < 0.52) & (bg < 0.72)

        out = np.where(is_grass, grass_buf, cobble)
        out = np.where(is_step_zone & (~step_stone) & (bg < 0.70), grass_buf, out)
        out = np.where(moss_patch, np.where(bg < 0.45, IX["teal"], IX["pine"]), out)

        # Subtle zone-specific focal details on paths
        if "manor" in rid:
            petal = (~is_grass) & (nf > 0.994) & (warp_lo > 0.45)
            out = np.where(petal, IX["rose"], out)
        elif "forecourt" in rid:
            # Asymmetric weathered bronze bell-court inlay rings offset slightly west of center
            rcx, rcy = W * 0.48, H * 0.52
            rad = np.hypot(xs - rcx, ys - rcy)
            ring = (~is_grass) & ((np.abs(rad - 34.0) < 0.9) | (np.abs(rad - 58.0) < 0.8)) & (warp_hi > 0.30)
            out = np.where(ring, IX["apricot"], out)

        buf[mask] = out[mask]

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Drape organic creeping moss/ivy asymmetrically over outer stone perimeter walls
        m_wall = ctx["m_wall"]
        if not np.any(m_wall):
            return
        H, W = ctx["H"], ctx["W"]
        bg = ctx["bg"]
        rid = str(ctx.get("meta", {}).get("id", "")).lower()
        z_off = sum(ord(ch) for ch in rid) % 73
        ivy_n = fbm_grid(H, W, 22.0, seed=self.spec.seed + 409 + z_off, octaves=2)
        dn_open = ~ctx["n_dn_wall"]
        ly, ts = ctx["ly"], ctx["ts"]
        cap_ivy = m_wall & (~(dn_open & (ly >= ts - 5))) & (ivy_n > 0.62) & (bg < 0.65)
        buf[cap_ivy] = np.where(ivy_n > 0.74, IX["jade"], IX["teal"])[cap_ivy]
        lip_ivy = m_wall & dn_open & (ly >= ts - 6) & (ly <= ts - 4) & (ivy_n > 0.68)
        buf[lip_ivy] = IX["pine"]


class WickCellarPainter(ThemePainter):
    """Wick House warmed stone-and-timber cellar (harmonizes with hub, breaks '+' crosshair in paint)."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]

        sh, sw = 10, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 61)
        # Warm cellar hearth-lit radial gradient (offset slightly NW for asymmetric warmth)
        dist_c = np.hypot((xs - W * 0.44) / max(1.0, W * 0.55), (ys - H * 0.46) / max(1.0, H * 0.55))
        glow = np.clip(1.0 - dist_c, 0.0, 1.0) * 0.24
        field = np.clip(nb * 0.44 + slab_h * 0.30 + warm * 0.08 + glow + 0.14, 0.0, 0.94)
        out = ramp_blend(s.floor_ramp, field, bg)
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.50)
        out = np.where(is_seam, IX["night"], out)
        out = np.where((sy == 1) & (sx > 1) & (sx < sw - 2) & (slab_h > 0.70) & (bg < 0.32), IX["stone"], out)
        # Subtle warm timber dust/barrel stain flecks
        out = np.where((nf < 0.012) & (nb > 0.55), IX["wine"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        # Blend cellar path softly into warm hearthstone so the map's '+' path feels organic, not a rigid crosshair
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb = ctx["bg"], ctx["n_broad"]

        base_buf = buf.copy()
        saved_m = ctx["m_ground"]
        ctx["m_ground"] = mask
        self.paint_floor(base_buf, ctx)
        ctx["m_ground"] = saved_m

        dist_in = chamfer_dist(mask)
        warp = fbm_grid(H, W, 28.0, seed=self.spec.seed + 271, octaves=2)
        eff = dist_in + (warp - 0.5) * 8.0

        # Warm hearth-plank / wine-stone stepping blocks
        row_id = ys // 8
        ox = np.where((row_id & 1) == 1, 8, 0)
        sx = (xs + ox) % 16
        sy = ys % 8
        sh = hash01_grid((xs + ox) // 16, row_id, self.spec.seed + 277)
        p_out = ramp_blend(("plum", "wine", "mauve"), np.clip(nb * 0.48 + sh * 0.32 + 0.12, 0.0, 0.90), bg)
        p_out = np.where(((sx == 0) | (sy == 0)) & (bg < 0.45), IX["dusk"], p_out)

        out = np.where(eff < 3.6, base_buf, np.where((eff < 6.4) & (bg < 0.48), base_buf, p_out))
        buf[mask] = out[mask]


class LighthousePainter(ThemePainter):
    """Island 2 Lighthouse Tower (r1-r18): ONE unified identity — wet coastal slate + brass + warm lamp light."""

    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        H, W = ctx["H"], ctx["W"]
        xs, ys = ctx["xs"], ctx["ys"]
        bg, nb, nf, warm = ctx["bg"], ctx["n_broad"], ctx["n_fine"], ctx["warm"]

        # Dressed wet coastal slate slabs (16x10 running bond), mean walkable luma ~74-82
        sh, sw = 10, 16
        row_id = ys // sh
        ox = np.where((row_id & 1) == 1, sw // 2, 0)
        sx = (xs + ox) % sw
        sy = ys % sh
        slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 59)

        # Subtle warm central lamp wash radiates gently from room focus
        dist_c = np.hypot((xs - W * 0.5) / max(1.0, W * 0.48), (ys - H * 0.5) / max(1.0, H * 0.52))
        lamp_wash = np.clip(1.0 - dist_c, 0.0, 1.0) * 0.22
        field = np.clip(nb * 0.44 + slab_h * 0.30 + warm * 0.08 + lamp_wash + 0.14, 0.0, 0.92)
        out = ramp_blend(s.floor_ramp, field, bg)

        # Quiet dithered wet-slate mortar seams
        is_seam = ((sx == 0) | (sy == 0)) & (bg < 0.50)
        out = np.where(is_seam, IX["night"], out)
        # Cool sea-spray sheen on damp slate edges next to water (distinct from bright blue water itself)
        wet_edge = ctx["n_dn_water"] | ctx["n_up_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
        out = np.where(wet_edge & (nf < 0.14) & (~is_seam), IX["teal"], out)
        # Crisp bevel catchlight on select dry flagstones
        out = np.where((sy == 1) & (sx > 1) & (sx < sw - 2) & (slab_h > 0.72) & (bg < 0.34), IX["stone"], out)

        # Subtle inlaid lighthouse brass compass/lens floor strips & corner studs
        cx, cy = W * 0.5, H * 0.5
        rad = np.hypot(xs - cx, ys - cy)
        brass_ring = (np.abs(rad - 44.0) < 0.75) & (((xs + ys) % 3) != 0) & (nb > 0.35)
        out = np.where(brass_ring, IX["apricot"], out)
        stud = (sx == 8) & (sy == 5) & (slab_h > 0.90)
        out = np.where(stud, IX["gold"], out)
        buf[mask] = out[mask]

    def paint_paths(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_path"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys, lx, ly, ts = ctx["xs"], ctx["ys"], ctx["lx"], ctx["ly"], ctx["ts"]
        bg, nb = ctx["bg"], ctx["n_broad"]

        is_edge = (
            ((~ctx["n_up_path"]) & (ly == 0))
            | ((~ctx["n_dn_path"]) & (ly == ts - 1))
            | ((~ctx["n_lt_path"]) & (lx == 0))
            | ((~ctx["n_rt_path"]) & (lx == ts - 1))
        )
        # Warm brass-riveted lighthouse gangway planks (distinct warm contrast against cool wet slate)
        main, hi, edge, trim = IX[s.path_main], IX[s.path_hi], IX[s.path_edge], IX[s.path_trim]
        dk = SHADE_IX[main]
        out = np.full(buf.shape, main, dtype=np.uint8)
        out = np.where((nb > 0.54) & (bg < 0.42), hi, out)
        out = np.where((ly % 6 == 0) & (bg < 0.52), dk, out)
        # Brass edge rivets along gangway curbing
        rivet = (
            (((~ctx["n_up_path"]) & (ly == 1)) | ((~ctx["n_dn_path"]) & (ly == ts - 2)))
            & (xs % 8 == 4)
        ) | (
            (((~ctx["n_lt_path"]) & (lx == 1)) | ((~ctx["n_rt_path"]) & (lx == ts - 2)))
            & (ys % 8 == 4)
        )
        out = np.where(rivet, trim, out)
        out = np.where(is_edge & (bg < 0.78), edge, out)
        buf[mask] = out[mask]

    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # Brass lighthouse wall-sconces along south-facing masonry walls + subtle warm light apron on floor below
        m_wall = ctx["m_wall"]
        dn_open = ~ctx["n_dn_wall"]
        xs, ys, ly, ts = ctx["xs"], ctx["ys"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]

        sx_w = xs % 48
        # Wall sconce bracket & warm lantern glass
        sconce = m_wall & dn_open & (sx_w >= 22) & (sx_w <= 25) & (ly >= ts - 5) & (ly <= ts - 2)
        buf[sconce] = IX["apricot"]
        core_l = m_wall & dn_open & ((sx_w == 23) | (sx_w == 24)) & ((ly == ts - 4) | (ly == ts - 3))
        buf[core_l] = IX["gold"]
        # Iron vertical tower rib straps on walls every 48px
        strap = m_wall & (sx_w == 0) & (bg < 0.65)
        buf[strap] = IX["void"]

        # Warm lamp-light splash onto walkable slate tiles directly south of wall sconces
        walk_s = ctx["m_walk"] & ctx["n_up_wall"] & (ly < 8)
        dx_s = np.abs(sx_w - 23.5)
        fall = np.clip(1.0 - np.hypot(dx_s / 11.0, ly / 8.0), 0.0, 1.0)
        splash = walk_s & (fall * 0.65 > bg)
        buf[splash] = LIGHT_IX[buf[splash]]


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
    """The Drowned Galleon: luminous lifted oak planks (luma ~76-86) clearly separated from darker ship hull walls."""

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
            # Lower Hold: lifted warm damp oak planking (plum -> mauve, luma ~78-84, clearly brighter than ~42 walls!)
            ph = 8
            pr = ys // ph
            py = ys % ph
            butt_off = (pr * 17) % 36
            px_b = (xs + butt_off) % 36
            plank_h = hash01_grid((xs + butt_off) // 36, pr, s.seed + 83)
            field = np.clip(nb * 0.48 + plank_h * 0.26 + warm * 0.12 + 0.08, 0.0, 0.86)
            out = ramp_blend(("plum", "mauve"), field, bg)
            # Soft dithered caulk seams (dusk, never murky black stripes)
            is_hseam = (py == 0) & (bg < 0.46)
            is_vseam = (px_b == 0) & (py > 0) & (bg < 0.40)
            out = np.where(is_hseam | is_vseam, IX["dusk"], out)
            # Subtle damp teal seepage near bilge water edges
            wet_edge = ctx["n_dn_water"] | ctx["n_up_water"] | ctx["n_lt_water"] | ctx["n_rt_water"]
            out = np.where(wet_edge & (nf < 0.14) & (py > 0), IX["teal"], out)
            # Quiet weathered edge sheen & brass deck pin
            out = np.where((py == 1) & (plank_h > 0.84) & (bg < 0.28), IX["stone"], out)
            out = np.where((px_b == 18) & (py == 4) & (plank_h > 0.90), IX["apricot"], out)
        elif is_cabin:
            # Captain's Cabin / Boathouse: warm varnished mahogany decking (plum -> wine -> mauve, luma ~82-88)
            ph = 7
            pr = ys // ph
            py = ys % ph
            butt_off = (pr * 19) % 40
            px_b = (xs + butt_off) % 40
            plank_h = hash01_grid((xs + butt_off) // 40, pr, s.seed + 97)
            field = np.clip(nb * 0.48 + plank_h * 0.26 + warm * 0.16 + 0.10, 0.0, 0.88)
            out = ramp_blend(("plum", "wine", "mauve"), field, bg)
            is_hseam = (py == 0) & (bg < 0.48)
            is_vseam = (px_b == 0) & (py > 0) & (bg < 0.40)
            out = np.where(is_hseam | is_vseam, IX["dusk"], out)
            out = np.where((py == 1) & (plank_h > 0.82) & (bg < 0.26), IX["apricot"], out)
            stud = (px_b == 20) & (py == 3) & (plank_h > 0.92)
            out = np.where(stud, IX["gold"], out)
        else:
            # Upper Weather / Gun / Keel / Prow Deck: salt-weathered oak timber (plum -> mauve -> stone, luma ~80-86)
            ph = 8
            pr = ys // ph
            py = ys % ph
            butt_off = (pr * 15) % 32
            px_b = (xs + butt_off) % 32
            plank_h = hash01_grid((xs + butt_off) // 32, pr, s.seed + 109)
            field = np.clip(nb * 0.46 + plank_h * 0.26 + warm * 0.10 + 0.08, 0.0, 0.82)
            out = ramp_blend(("plum", "mauve", "stone"), field, bg)
            is_hseam = (py == 0) & (bg < 0.46)
            is_vseam = (px_b == 0) & (py > 0) & (bg < 0.38)
            out = np.where(is_hseam | is_vseam, IX["dusk"], out)
            # Subtle transverse ship deck-rib timber line every 48px
            rib = (xs % 48 == 0) & (bg < 0.44)
            out = np.where(rib, IX["night"], out)
            out = np.where((py == 1) & (plank_h > 0.78) & (bg < 0.28), IX["stone"], out)
            salt = (nb > 0.82) & (nf > 0.93) & (bg < 0.30) & (py > 0)
            out = np.where(salt, IX["ice"], out)

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

        # Warm oak gangway runner with wide 8px cross-planks and quiet bevels
        out = np.full(buf.shape, main, dtype=np.uint8)
        out = np.where((nb > 0.56) & (bg < 0.38), hi, out)
        out = np.where((ly % 8 == 0) & (bg < 0.52), dk, out)
        out = np.where(is_edge & (bg < 0.74), edge, out)
        buf[mask] = out[mask]


SPECS_1_2: list[tuple[ThemeSpec, type[ThemePainter]]] = [
    (
        ThemeSpec(
            id="undercroft",
            name="The Undercroft",
            island=1,
            floor_style="flagstone_crypt",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="pine",
            floor_accent_b="apricot",
            path_style="carpet_runner",
            path_main="plum",
            path_hi="wine",
            path_edge="night",
            path_trim="gold",
            wall_style="masonry",
            wall_cap=("void", "night", "dusk"),
            wall_lip="mauve",
            wall_face="dusk",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="rain_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
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
            notes="Bell Isle catacombs beneath the chapel; calm luminous flagstones, arched bone niches, bronze tone rings.",
        ),
        UndercroftPainter,
    ),
    (
        ThemeSpec(
            id="manor",
            name="The Bellmaker's Manor",
            island=1,
            floor_style="herringbone_parquet",
            floor_ramp=("dusk", "plum", "wine"),
            floor_seam="dusk",
            floor_bevel="mauve",
            floor_accent_a="apricot",
            floor_accent_b="gold",
            path_style="carpet_runner",
            path_main="wine",
            path_hi="rose",
            path_edge="night",
            path_trim="apricot",
            wall_style="wainscot",
            wall_cap=("void", "night", "dusk"),
            wall_lip="apricot",
            wall_face="dusk",
            wall_face_hi="plum",
            wall_base="void",
            water_style="rain_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
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
            notes="Stealth whodunit mansion: calm satin-wood parquet, velvet wine carpets, paneled wainscot & framed portraits.",
        ),
        ManorPainter,
    ),
    (
        ThemeSpec(
            id="bell_outer",
            name="Bell Isle Outer Grounds",
            island=1,
            floor_style="cave_floor",
            floor_ramp=("pine", "teal", "jade", "lime"),
            floor_seam="pine",
            floor_bevel="lime",
            floor_accent_a="jade",
            floor_accent_b="gold",
            path_style="sand_trail",
            path_main="mauve",
            path_hi="stone",
            path_edge="pine",
            path_trim="apricot",
            wall_style="masonry",
            wall_cap=("dusk", "mauve", "stone"),
            wall_lip="stone",
            wall_face="dusk",
            wall_face_hi="mauve",
            wall_base="night",
            water_style="koi_pond",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="starry_cosmos",
            rim_hi="stone",
            rim_mid="mauve",
            bridge_style="timber",
            bridge_main="wine",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="night",
            seed=141,
            organic_edges=True,
            prop_sheet="island1_scenery",
            door_sheet="island1_doors",
            special_tiles=(),
            default_decor=("stain",),
            notes="Bell Isle outer districts: twilight meadow grass with domain-warped mossy stone paths breaking rigid grids.",
        ),
        BellOuterPainter,
    ),
    (
        ThemeSpec(
            id="wick_cellar",
            name="Wick House Cellar",
            island=1,
            floor_style="flagstone_crypt",
            floor_ramp=("dusk", "plum", "mauve"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="wine",
            floor_accent_b="apricot",
            path_style="sand_trail",
            path_main="plum",
            path_hi="wine",
            path_edge="dusk",
            path_trim="apricot",
            wall_style="masonry",
            wall_cap=("void", "night", "dusk"),
            wall_lip="apricot",
            wall_face="dusk",
            wall_face_hi="plum",
            wall_base="void",
            water_style="rain_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="mauve",
            bridge_style="timber",
            bridge_main="wine",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="night",
            seed=151,
            prop_sheet="theme_wick_house",
            door_sheet="theme_wick_house_doors",
            special_tiles=(),
            default_decor=("stain", "cracks"),
            notes="Warmed stone-and-timber cellar beneath Wick House; cozy hearthlit flagstones & soft organic cobble wear.",
        ),
        WickCellarPainter,
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
            id="lighthouse",
            name="The Tidewater Lighthouse",
            island=2,
            floor_style="quay_masonry",
            floor_ramp=("dusk", "mauve", "stone"),
            floor_seam="night",
            floor_bevel="stone",
            floor_accent_a="teal",
            floor_accent_b="gold",
            path_style="boardwalk",
            path_main="plum",
            path_hi="wine",
            path_edge="night",
            path_trim="apricot",
            wall_style="masonry",
            wall_cap=("void", "night", "dusk"),
            wall_lip="apricot",
            wall_face="dusk",
            wall_face_hi="mauve",
            wall_base="void",
            water_style="canal_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="shaft_drop",
            void_style="shaft_drop",
            rim_hi="gold",
            rim_mid="sky",
            bridge_style="timber",
            bridge_main="wine",
            bridge_hi="apricot",
            bridge_rail="gold",
            bridge_dark="night",
            seed=201,
            prop_sheet="island2_scenery",
            door_sheet="island2_doors",
            special_tiles=("T:tide", "G:glass"),
            default_decor=("circle", "stain"),
            notes="Unified Tidewater Lighthouse Tower: luminous wet coastal slate, warm brass lamp sconces, crisp blue tidewater.",
        ),
        LighthousePainter,
    ),
    (
        ThemeSpec(
            id="galleon",
            name="The Drowned Galleon",
            island=2,
            floor_style="ship_planking",
            floor_ramp=("plum", "mauve", "stone"),
            floor_seam="dusk",
            floor_bevel="stone",
            floor_accent_a="wine",
            floor_accent_b="teal",
            path_style="boardwalk",
            path_main="wine",
            path_hi="coral",
            path_edge="night",
            path_trim="apricot",
            wall_style="ship_hull",
            wall_cap=("void", "night", "dusk"),
            wall_lip="apricot",
            wall_face="night",
            wall_face_hi="dusk",
            wall_base="void",
            water_style="canal_water",
            water_deep="deep",
            water_mid="blue",
            water_hi="sky",
            water_foam="ice",
            pit_style="crypt_abyss",
            void_style="crypt_abyss",
            rim_hi="apricot",
            rim_mid="gold",
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
            notes="Listing shipwreck: luminous weathered oak & mahogany decks clearly separated from darker ship hull walls & bilge water.",
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
