"""Base ThemeSpec and ThemePainter for Luxel Epic.

Every theme defines its own architectural floor, wall, path, water, pit, void,
bridge, glass, rim, and decor language in the strict 20-colour Last Light palette.
Subclasses can override any stage (paint_floor, paint_walls, paint_paths,
paint_water, paint_pit, paint_void, paint_bridge, paint_post) for bespoke set pieces.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any

import numpy as np
from PIL import Image

from .kit import (
    ABYSS_TYPES,
    COOL_IX,
    IX,
    LAND_TYPES,
    LIGHT_IX,
    NAMES,
    OPEN_TYPES,
    SHADE_IX,
    TAU,
    WALKABLE_TYPES,
    bayer_grid,
    buf_to_image,
    chamfer_dist,
    expand_neighbor_mask,
    expand_tile_mask,
    fbm_grid,
    hash01_grid,
    ramp_blend,
    verify_image_palette,
    vnoise_grid,
)


@dataclass(frozen=True)
class ThemeSpec:
    id: str
    name: str
    island: int
    # Floor architectural style & ramp (mid-dark to luminous mid-tone, NEVER murky void)
    floor_style: str
    floor_ramp: tuple[str, ...]
    floor_seam: str
    floor_bevel: str
    floor_accent_a: str
    floor_accent_b: str
    # Path / runner / walkway style & colors
    path_style: str
    path_main: str
    path_hi: str
    path_edge: str
    path_trim: str
    # Wall 3/4 style & colors (cap ramp, top cornice lip, south face, recessed plinth base)
    wall_style: str
    wall_cap: tuple[str, str, str]
    wall_lip: str
    wall_face: str
    wall_face_hi: str
    wall_base: str
    # Water style & ramp
    water_style: str
    water_deep: str
    water_mid: str
    water_hi: str
    water_foam: str
    # Pit & void style & abyss coping rim
    pit_style: str
    void_style: str
    rim_hi: str
    rim_mid: str
    # Bridge & glass
    bridge_style: str
    bridge_main: str
    bridge_hi: str
    bridge_rail: str
    bridge_dark: str
    glass_main: str = "sky"
    glass_hi: str = "ice"
    glass_frame: str = "gold"
    # Optional special features
    seed: int = 101
    organic_edges: bool = False
    wall_ao_depth: int = 4
    prop_sheet: str = ""
    door_sheet: str = ""
    special_tiles: tuple[str, ...] = ()
    default_decor: tuple[str, ...] = ()
    notes: str = ""


class ThemePainter:
    """Vectorized Last Light theme painter (~0.08–0.20s per 24x14 room)."""

    def __init__(self, spec: ThemeSpec) -> None:
        self.spec = spec

    # ------------------------------------------------------------------ main entry
    def paint(
        self,
        grid: list[list[str]],
        ts: int = 16,
        meta: dict[str, Any] | None = None,
        organic_override: bool | None = None,
    ) -> Image.Image:
        buf, _ = self.paint_buffer(grid, ts=ts, meta=meta, organic_override=organic_override)
        im = buf_to_image(buf)
        verify_image_palette(im, f"theme:{self.spec.id}")
        return im

    def paint_buffer(
        self,
        grid: list[list[str]],
        ts: int = 16,
        meta: dict[str, Any] | None = None,
        organic_override: bool | None = None,
    ) -> tuple[np.ndarray, dict[str, np.ndarray]]:
        meta = meta or {}
        h_t = len(grid)
        w_t = len(grid[0]) if h_t else 0
        H, W = h_t * ts, w_t * ts

        # Normalize B (bramble) and C (cracked) to clean ground underneath (ZERO-GHOST RULE)
        norm_grid: list[list[str]] = [
            ["ground" if ch in ("bramble", "cracked") else ch for ch in row]
            for row in grid
        ]

        s = self.spec
        bg = bayer_grid(H, W)
        xs = np.broadcast_to(np.arange(W, dtype=np.int32)[None, :], (H, W))
        ys = np.broadcast_to(np.arange(H, dtype=np.int32)[:, None], (H, W))
        lx = xs % ts
        ly = ys % ts
        tx = xs // ts
        ty = ys // ts

        warm = np.clip(1.0 - xs.astype(np.float32) / float(max(1, W)), 0.0, 1.0)
        n_broad = fbm_grid(H, W, 38.0, seed=s.seed + 7, octaves=3)
        n_med = vnoise_grid(H, W, 16.0, seed=s.seed + 19)
        n_fine = hash01_grid(xs, ys, s.seed + 31)
        tile_h = hash01_grid(tx, ty, s.seed + 43)

        # Masks
        m_ground = expand_tile_mask(norm_grid, {"ground"}, ts)
        m_path = expand_tile_mask(norm_grid, {"path"}, ts)
        m_wall = expand_tile_mask(norm_grid, {"wall"}, ts)
        m_water = expand_tile_mask(norm_grid, {"water"}, ts)
        m_pit = expand_tile_mask(norm_grid, {"pit"}, ts)
        m_void = expand_tile_mask(norm_grid, {"void"}, ts)
        m_phantom = expand_tile_mask(norm_grid, {"phantom"}, ts)
        m_tide = expand_tile_mask(norm_grid, {"tide"}, ts)
        m_bridge = expand_tile_mask(norm_grid, {"bridge"}, ts)
        m_glass = expand_tile_mask(norm_grid, {"glass", "mirror"}, ts)
        m_carpet = expand_tile_mask(norm_grid, {"carpet", "dais"}, ts)
        m_stairs = expand_tile_mask(norm_grid, {"stairs"}, ts)
        m_grate = expand_tile_mask(norm_grid, {"grate", "hearth"}, ts)
        m_rail = expand_tile_mask(norm_grid, {"rail"}, ts)
        m_foliage = expand_tile_mask(norm_grid, {"foliage"}, ts)

        # Neighbor masks
        n_up_wall = expand_neighbor_mask(norm_grid, -1, 0, {"wall"}, ts)
        n_dn_wall = expand_neighbor_mask(norm_grid, 1, 0, {"wall"}, ts)
        n_lt_wall = expand_neighbor_mask(norm_grid, 0, -1, {"wall"}, ts)
        n_rt_wall = expand_neighbor_mask(norm_grid, 0, 1, {"wall"}, ts)
        n_nw_wall = expand_neighbor_mask(norm_grid, -1, -1, {"wall"}, ts)

        n_up_abyss = expand_neighbor_mask(norm_grid, -1, 0, ABYSS_TYPES, ts)
        n_dn_abyss = expand_neighbor_mask(norm_grid, 1, 0, ABYSS_TYPES, ts)
        n_lt_abyss = expand_neighbor_mask(norm_grid, 0, -1, ABYSS_TYPES, ts)
        n_rt_abyss = expand_neighbor_mask(norm_grid, 0, 1, ABYSS_TYPES, ts)

        n_up_land = expand_neighbor_mask(norm_grid, -1, 0, LAND_TYPES, ts)
        n_dn_land = expand_neighbor_mask(norm_grid, 1, 0, LAND_TYPES, ts)
        n_lt_land = expand_neighbor_mask(norm_grid, 0, -1, LAND_TYPES, ts)
        n_rt_land = expand_neighbor_mask(norm_grid, 0, 1, LAND_TYPES, ts)

        n_up_water = expand_neighbor_mask(norm_grid, -1, 0, {"water", "tide"}, ts)
        n_dn_water = expand_neighbor_mask(norm_grid, 1, 0, {"water", "tide"}, ts)
        n_lt_water = expand_neighbor_mask(norm_grid, 0, -1, {"water", "tide"}, ts)
        n_rt_water = expand_neighbor_mask(norm_grid, 0, 1, {"water", "tide"}, ts)

        n_up_path = expand_neighbor_mask(norm_grid, -1, 0, {"path"}, ts)
        n_dn_path = expand_neighbor_mask(norm_grid, 1, 0, {"path"}, ts)
        n_lt_path = expand_neighbor_mask(norm_grid, 0, -1, {"path"}, ts)
        n_rt_path = expand_neighbor_mask(norm_grid, 0, 1, {"path"}, ts)

        n_up_bridge = expand_neighbor_mask(norm_grid, -1, 0, {"bridge"}, ts)
        n_dn_bridge = expand_neighbor_mask(norm_grid, 1, 0, {"bridge"}, ts)
        n_lt_bridge = expand_neighbor_mask(norm_grid, 0, -1, {"bridge"}, ts)
        n_rt_bridge = expand_neighbor_mask(norm_grid, 0, 1, {"bridge"}, ts)

        m_walk = m_ground | m_path | m_carpet | m_stairs | m_grate | m_rail

        ctx: dict[str, Any] = {
            "grid": norm_grid,
            "H": H,
            "W": W,
            "h_t": h_t,
            "w_t": w_t,
            "ts": ts,
            "bg": bg,
            "xs": xs,
            "ys": ys,
            "lx": lx,
            "ly": ly,
            "tx": tx,
            "ty": ty,
            "warm": warm,
            "n_broad": n_broad,
            "n_med": n_med,
            "n_fine": n_fine,
            "tile_h": tile_h,
            "m_ground": m_ground,
            "m_path": m_path,
            "m_wall": m_wall,
            "m_water": m_water,
            "m_pit": m_pit,
            "m_void": m_void,
            "m_phantom": m_phantom,
            "m_tide": m_tide,
            "m_bridge": m_bridge,
            "m_glass": m_glass,
            "m_carpet": m_carpet,
            "m_stairs": m_stairs,
            "m_grate": m_grate,
            "m_rail": m_rail,
            "m_foliage": m_foliage,
            "m_walk": m_walk,
            "n_up_wall": n_up_wall,
            "n_dn_wall": n_dn_wall,
            "n_lt_wall": n_lt_wall,
            "n_rt_wall": n_rt_wall,
            "n_nw_wall": n_nw_wall,
            "n_up_abyss": n_up_abyss,
            "n_dn_abyss": n_dn_abyss,
            "n_lt_abyss": n_lt_abyss,
            "n_rt_abyss": n_rt_abyss,
            "n_up_land": n_up_land,
            "n_dn_land": n_dn_land,
            "n_lt_land": n_lt_land,
            "n_rt_land": n_rt_land,
            "n_up_water": n_up_water,
            "n_dn_water": n_dn_water,
            "n_lt_water": n_lt_water,
            "n_rt_water": n_rt_water,
            "n_up_path": n_up_path,
            "n_dn_path": n_dn_path,
            "n_lt_path": n_lt_path,
            "n_rt_path": n_rt_path,
            "n_up_bridge": n_up_bridge,
            "n_dn_bridge": n_dn_bridge,
            "n_lt_bridge": n_lt_bridge,
            "n_rt_bridge": n_rt_bridge,
            "meta": meta,
            "organic": s.organic_edges if organic_override is None else organic_override,
        }

        buf = np.full((H, W), IX["void"], dtype=np.uint8)

        # 1. Void & Pit & Phantom
        self.paint_void(buf, ctx)
        self.paint_pit(buf, ctx)
        self.paint_phantom(buf, ctx)

        # 2. Water & Tide
        self.paint_water(buf, ctx)
        self.paint_tide(buf, ctx)

        # 3. Walkable ground, paths, special floor tiles
        self.paint_floor(buf, ctx)
        self.paint_paths(buf, ctx)
        self.paint_special_floors(buf, ctx)

        # 4. Bridges & Glass
        self.paint_bridge(buf, ctx)
        self.paint_glass(buf, ctx)

        # 5. Architectural abyss rims on walkable pixels bordering pit/void/phantom
        self.paint_abyss_rims(buf, ctx)

        # 6. 3/4 Walls & Foliage walls
        self.paint_walls(buf, ctx)

        # 7. Focal composition decor hints from JSON
        decor_list = meta.get("decor", [])
        if isinstance(decor_list, list) and decor_list:
            self.paint_decor(buf, ctx, decor_list)

        # 8. Wall AO drop shadows cast onto walkable floor & paths (south & east of walls)
        self.paint_wall_ao(buf, ctx)

        # 9. Exit framing jambs & threshold sills
        exits = meta.get("exits", [])
        if isinstance(exits, list) and exits:
            self.paint_exits(buf, ctx, exits)

        # 10. Theme-specific post pass (asymmetric details, ambient gleams, window strips)
        self.paint_post(buf, ctx)

        return buf, ctx

    # ------------------------------------------------------------------ FLOOR
    def paint_floor(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_ground"]
        if not np.any(mask):
            return
        s = self.spec
        style = s.floor_style
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nm = ctx["n_med"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        H, W = ctx["H"], ctx["W"]

        # Broad organic tonal base from ramp (keeps floors luminous and rich)
        field = np.clip(nb * 0.72 + nm * 0.18 + warm * 0.10, 0.0, 0.999)
        base = ramp_blend(s.floor_ramp, field, bg)
        seam = IX[s.floor_seam]
        bevel = IX[s.floor_bevel]
        acc_a = IX[s.floor_accent_a]
        acc_b = IX[s.floor_accent_b]

        if style in ("flagstone_crypt", "quay_masonry", "rain_slate", "forge_anvil_hall", "heraldic_court", "ledger_stone"):
            # Running-bond architectural slabs (16x8 or 16x12)
            sh = 12 if style in ("quay_masonry", "forge_anvil_hall") else 8
            sw = 16
            row_id = ys // sh
            ox = np.where((row_id & 1) == 1, sw // 2, 0)
            sx = (xs + ox) % sw
            sy = ys % sh
            slab_h = hash01_grid((xs + ox) // sw, row_id, s.seed + 59)
            # Per-slab slight value shift
            slab_f = np.clip(nb * 0.55 + slab_h * 0.40 + warm * 0.08, 0.0, 0.999)
            out = ramp_blend(s.floor_ramp, slab_f, bg)
            is_seam = (sx == 0) | (sy == 0)
            is_bev = (sy == 1) & (sx > 1) & (sx < sw - 2) & ((slab_h > 0.42) | (bg < 0.30))
            out = np.where(is_bev, bevel, out)
            out = np.where(is_seam, seam, out)

            if style == "flagstone_crypt":
                # Damp moss/seepage veins in mortar + occasional carved floor cross/drain
                damp = (nb < 0.32) & (nf < 0.12)
                out = np.where(damp, acc_a, out)
                out = np.where((sx == 8) & (sy == 4) & (slab_h > 0.86), acc_b, out)
            elif style == "quay_masonry":
                # Wet salt-moss seams near water + iron tie rings
                wet_edge = (ctx["n_dn_water"] | ctx["n_up_water"] | ctx["n_lt_water"] | ctx["n_rt_water"])
                out = np.where(wet_edge & (nf < 0.14), acc_a, out)
                out = np.where((sx == 4) & (sy == 5) & (slab_h > 0.88), acc_b, out)
            elif style == "rain_slate":
                # Diagonal rain-sheen reflections & recessed bronze gutter lines every 48px
                sheen = (((xs + ys * 2) % 23) < 2) & (nb > 0.58) & (bg < 0.45)
                out = np.where(sheen, acc_a, out)
                gutter = (xs % 64 == 31) | (xs % 64 == 32)
                out = np.where(gutter & (ys % 4 != 0), acc_b, out)
                out = np.where(gutter & (ys % 4 == 0), seam, out)
            elif style == "forge_anvil_hall":
                # Heat-cracked mortar glowing deep wine/coral in hot pockets
                hot = (nb > 0.66) & is_seam & (bg < 0.55)
                out = np.where(hot, acc_a, out)
                out = np.where((nb > 0.78) & (sx == 0) & (sy == 0), acc_b, out)
            elif style == "heraldic_court":
                # Moss tucked in mortar joints + sparse fallen rose petals
                moss = is_seam & (nb < 0.48) & (bg < 0.60)
                out = np.where(moss, acc_a, out)
                petals = (nf > 0.992) & (nb > 0.40)
                out = np.where(petals, acc_b, out)
            elif style == "ledger_stone":
                # Ruled gold/mauve vertical ledger columns + crisp margin double-lines
                col_rule = (xs % 32 == 0) & ((ys % 2) == 0)
                out = np.where(col_rule, acc_a, out)
                margin = (xs == 48) | (xs == 50) | (xs == W - 49)
                out = np.where(margin, acc_b, out)

        elif style in ("herringbone_parquet", "archive_parquet", "cottage_hearth"):
            # Warm interior wood planking / herringbone parquet
            if style == "herringbone_parquet":
                # Calm 16x16 alternating vertical/horizontal satin-wood parquet blocks
                bx = xs // 16
                by = ys // 16
                horiz = ((bx + by) & 1) == 0
                pl_i = np.where(horiz, ys % 8, xs % 8)
                pl_id = np.where(horiz, ys // 8, xs // 8)
                bh = hash01_grid(bx, by * 7 + pl_id, s.seed + 71)
                out = ramp_blend(s.floor_ramp, np.clip(nb * 0.45 + bh * 0.30 + warm * 0.10, 0.0, 0.82), bg)
                is_seam = ((pl_i == 0) & (bg < 0.46)) | (((xs % 16 == 0) | (ys % 16 == 0)) & (bg < 0.55))
                out = np.where(is_seam, seam, out)
                out = np.where((pl_i == 1) & (bh > 0.72) & (bg < 0.30), bevel, out)
                out = np.where((xs % 16 == 8) & (ys % 16 == 8) & (bh > 0.90), acc_a, out)
            elif style == "cottage_hearth":
                # Cozy wide honey-oak cottage planks with calm, low-contrast seams (lets rugs/NPCs pop!)
                ph = 8
                pr = ys // ph
                py = ys % ph
                butt_off = (pr * 19) % 40
                px_b = (xs + butt_off) % 40
                plank_h = hash01_grid((xs + butt_off) // 40, pr, s.seed + 77)
                # Compress tonal range so planks stay in calm warm mid-tone plum/wine without harsh striping
                pf = np.clip(nb * 0.42 + plank_h * 0.24 + warm * 0.10, 0.05, 0.68)
                out = ramp_blend(s.floor_ramp, pf, bg)
                # Soft Bayer-dithered seams one shade darker (never heavy black horizontal stripes)
                is_hseam = (py == 0) & (bg < 0.44)
                is_vseam = (px_b == 0) & (py > 0) & (bg < 0.40)
                out = np.where(is_hseam | is_vseam, SHADE_IX[out], out)
                # Restrained warm bevel glint only on select sunlit boards
                out = np.where((py == 1) & (px_b > 2) & (px_b < 37) & (plank_h > 0.80) & (bg < 0.24), IX["coral"], out)
                # Tiny muted wood peg near plank butt joints
                peg = (px_b == 3) & (py == 4) & (plank_h > 0.55)
                out = np.where(peg, IX["dusk"], out)
            else:
                # archive_parquet: long horizontal planks with staggered butt joints & pegs
                ph = 6
                pr = ys // ph
                py = ys % ph
                butt_off = (pr * 19) % 32
                px_b = (xs + butt_off) % 32
                plank_h = hash01_grid((xs + butt_off) // 32, pr, s.seed + 77)
                out = ramp_blend(s.floor_ramp, np.clip(nb * 0.45 + plank_h * 0.45 + warm * 0.12, 0.0, 0.999), bg)
                out = np.where((py == 0) | (px_b == 0), seam, out)
                out = np.where((py == 1) & (px_b > 1) & (plank_h > 0.45), bevel, out)
                peg = (px_b == 2) & (py == ph // 2) & (plank_h > 0.40)
                out = np.where(peg, acc_a, out)
                trim_m = ((ys % 48 == 24) & ((xs % 4) < 2))
                out = np.where(trim_m, acc_b, out)

        elif style in ("ship_planking", "theatre_stage", "radial_shaft_deck"):
            # Caulked deck / stage / shaft planks
            ph = 4 if style == "ship_planking" else 5
            pr = ys // ph
            py = ys % ph
            butt_off = (pr * 13) % 28
            px_b = (xs + butt_off) % 28
            plank_h = hash01_grid((xs + butt_off) // 28, pr, s.seed + 83)
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.50 + plank_h * 0.42 + warm * 0.10, 0.0, 0.999), bg)
            out = np.where(py == 0, seam, out)
            out = np.where((px_b == 0) & (py > 0), seam, out)
            out = np.where((py == 1) & (plank_h > 0.50), bevel, out)
            if style == "ship_planking":
                # Caulked treenails + bleached salt-spray washes + brass floor hatch rings
                nail = ((px_b == 2) | (px_b == 26)) & (py == 2)
                out = np.where(nail, acc_a, out)
                salt = (nb > 0.72) & (bg < 0.42) & (py > 0)
                out = np.where(salt, acc_b, out)
            elif style == "theatre_stage":
                # Brass footlight strip markers & warm spotlight wash in center
                cx, cy = W * 0.5, H * 0.52
                dist_c = np.hypot((xs - cx) / max(1.0, W * 0.28), (ys - cy) / max(1.0, H * 0.34))
                spot = (dist_c < 1.0) & (bg < (1.0 - dist_c) * 0.65) & (py > 0)
                out = np.where(spot, LIGHT_IX[out], out)
                out = np.where((px_b == 14) & (py == 2) & (plank_h > 0.80), acc_a, out)
            else:
                # radial_shaft_deck: iron ring ribs radiating from room center
                cx, cy = W * 0.5, H * 0.5
                rad = np.hypot(xs - cx, (ys - cy) * 1.15)
                ring = (np.abs((rad % 36.0) - 18.0) < 1.1)
                out = np.where(ring, acc_a, out)
                rivet = ring & (((xs + ys) % 6) == 0)
                out = np.where(rivet, acc_b, out)

        elif style == "organic_membrane":
            # Leviathan belly: curving ivory rib-arches gently emerging under biological wine/rose tissue
            cx = W * 0.5
            warp = (nb - 0.5) * 8.0
            rib_wave = 0.5 + 0.5 * np.sin((ys.astype(np.float32) + np.abs(xs - cx) * 0.28 + warp) * 0.20)
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.60 + rib_wave * 0.26 + 0.06, 0.0, 0.999), bg)
            # Softly buried pale bone rib crests peeking through in organic patches
            rib_ridge = (rib_wave > 0.91) & (nb > 0.44) & (bg < 0.72)
            out = np.where(rib_ridge, bevel, out)
            rib_edge = (rib_wave > 0.84) & (rib_wave <= 0.91) & (nb > 0.40) & (bg < 0.48)
            out = np.where(rib_edge, acc_a, out)
            # Soft low-contrast biological membrane creases (plum, never harsh black worms)
            vein = (np.abs(nm - 0.5) < 0.016) & (bg < 0.55)
            out = np.where(vein, IX["plum"], out)
            out = np.where((nf > 0.995) & (nb > 0.55), acc_b, out)

        elif style == "tidal_seabed":
            # Calm painterly wet ocean sandbars & shoals with soft Bayer-dithered ripples
            warp = (nb - 0.5) * 16.0
            ripple = 0.5 + 0.5 * np.sin((ys.astype(np.float32) * 0.36 + xs.astype(np.float32) * 0.12 + warp) * 0.75)
            sand_f = np.clip(nb * 0.62 + ripple * 0.24 + warm * 0.10, 0.0, 0.999)
            out = ramp_blend(s.floor_ramp, sand_f, bg)
            # Subtle wet specular catchlights only on rare sunlit ripple crests
            crest = (ripple > 0.92) & (nb > 0.58) & (bg < 0.36)
            out = np.where(crest, bevel, out)
            # Tiny sparse coral pebbles & sea-glass flecks
            out = np.where((nf < 0.008) & (nb < 0.45), acc_a, out)
            out = np.where((nf > 0.995) & (nb > 0.55), acc_b, out)

        elif style == "packed_loam_roots":
            # Under-Root tiny world: calm rich warm loam crossed by gentle woody root tendrils
            root_n = fbm_grid(H, W, 32.0, seed=s.seed + 91, octaves=2, sx=0.60, sy=1.30)
            ridge = np.maximum(0.0, 1.0 - np.abs(root_n * 2.0 - 1.0) * 4.2)
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.60 + nm * 0.22 + warm * 0.08, 0.0, 0.999), bg)
            # Subtle dark-bark root ridges (low contrast so amber ant-paths & bright dew-lenses pop!)
            out = np.where((ridge > 0.62) & (bg < 0.72), acc_a, out)
            out = np.where((ridge > 0.84) & (bg < 0.55), bevel, out)
            out = np.where((ridge > 0.48) & (ridge <= 0.62) & (bg < 0.55), seam, out)
            # Sparse mossy & spore flecks near edges
            out = np.where((nf < 0.010) & (nb > 0.58), acc_b, out)

        elif style == "woven_tapestry":
            # Weaver's Loom: taut cross-hatched warp & weft threads over oak loom frame
            wx_t = xs % 8
            wy_t = ys % 8
            over_warp = (((xs // 8) + (ys // 8)) & 1) == 0
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.55 + warm * 0.20 + 0.15, 0.0, 0.999), bg)
            # Warp threads (vertical) vs weft threads (horizontal)
            warp_hi = over_warp & (wx_t == 2)
            weft_hi = (~over_warp) & (wy_t == 2)
            out = np.where(warp_hi | weft_hi, bevel, out)
            out = np.where((wx_t == 0) | (wy_t == 0), seam, out)
            # Luminous silk gold/coral guide threads every 32px
            silk = (xs % 32 == 16) | (ys % 32 == 16)
            out = np.where(silk & (((xs + ys) % 3) != 0), acc_a, out)
            out = np.where((xs % 32 == 16) & (ys % 32 == 16), acc_b, out)

        elif style == "sand_labyrinth":
            # Hourglass Maze: sweeping organic golden sand dunes lapping over irregular buried flagstones (ZERO waffle!)
            row_id = ys // 12
            ox = np.where((row_id & 1) == 1, 10, 0)
            sx = (xs + ox) % 20
            sy = ys % 12
            slab_h = hash01_grid((xs + ox) // 20, row_id, s.seed + 97)
            # Sweeping wind-rippled golden hourglass sand
            ripple = 0.5 + 0.5 * np.sin((xs.astype(np.float32) * 0.18 + ys.astype(np.float32) * 0.44 + nb * 9.0))
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.55 + ripple * 0.28 + warm * 0.14, 0.0, 0.999), bg)
            # Exposed sandstone flagstones only where sand drifts thin out (organic asymmetry!)
            exposed = (nb < 0.48) & (slab_h < 0.68)
            out = np.where(exposed, np.where((nb < 0.36) | (bg < 0.65), acc_a, out), out)
            out = np.where(exposed & ((sx == 0) | (sy == 0)), seam, out)
            out = np.where(exposed & (sy == 1) & (sx > 1) & (sx < 18) & (slab_h < 0.42), bevel, out)
            # Rare golden sand sparkles on sunlit crests
            out = np.where((~exposed) & (ripple > 0.85) & (nf > 0.992), acc_b, out)

        elif style in ("checkered_terrace", "ballroom_diamond", "palace_silver", "palace_black"):
            # Formal marble / mirror / diamond geometric flooring
            if style == "ballroom_diamond":
                u = (xs + ys) // 16
                v = (xs - ys) // 16
                chk = ((u + v) & 1) == 0
                edge = ((xs + ys) % 16 == 0) | ((xs - ys) % 16 == 0)
            else:
                sz = 16
                chk = (((xs // sz) + (ys // sz)) & 1) == 0
                edge = (xs % sz == 0) | (ys % sz == 0)
            f_hi = np.clip(nb * 0.45 + 0.50 + warm * 0.08, 0.0, 0.999)
            f_lo = np.clip(nb * 0.45 + 0.14 + warm * 0.08, 0.0, 0.999)
            out = np.where(chk, ramp_blend(s.floor_ramp, f_hi, bg), ramp_blend(s.floor_ramp, f_lo, bg))
            out = np.where(edge, seam, out)
            if style == "checkered_terrace":
                # Subtle garden moss creeping into select outer seams + petal flecks
                out = np.where(edge & (nb < 0.42), acc_a, out)
                out = np.where((nf > 0.994), acc_b, out)
            elif style in ("palace_silver", "palace_black"):
                # Crisp diagonal mirror sheen streaks across polished tiles
                diag_s = ((xs - ys) % 29)
                streak = (diag_s == 0) & (nb > 0.42) & (bg < 0.65)
                streak2 = (diag_s == 1) & (nb > 0.62) & (bg < 0.45)
                out = np.where(streak, bevel, out)
                out = np.where(streak2, acc_a, out)
                if style == "palace_black":
                    # Eerie inverted rose/ice filigree hairline corners
                    corner = ((xs % 16 == 2) & (ys % 16 == 2)) | ((xs % 16 == 14) & (ys % 16 == 14))
                    out = np.where(corner, acc_b, out)
            else:
                # ballroom_diamond: gilded corner dots + specular marble sheen
                dot = ((xs + ys) % 16 == 8) & ((xs - ys) % 16 == 0)
                out = np.where(dot, acc_a, out)
                out = np.where(chk & (((xs - ys) % 32) == 3) & (bg < 0.45), bevel, out)

        elif style == "meteor_basalt":
            # Faceted polygonal asteroid stone with glowing mineral crystal veins
            # Approximate Voronoi-like facets via offset grid + noise warp
            wx = xs.astype(np.float32) + (nb - 0.5) * 10.0
            wy = ys.astype(np.float32) + (nm - 0.5) * 10.0
            fx = (wx % 18.0)
            fy = (wy % 14.0)
            fh = hash01_grid(np.floor(wx / 18.0).astype(np.int64), np.floor(wy / 14.0).astype(np.int64), s.seed + 109)
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.50 + fh * 0.42, 0.0, 0.999), bg)
            crack = (fx < 1.2) | (fy < 1.2)
            out = np.where(crack, seam, out)
            # Glowing gold & ice mineral veins running along select fracture seams
            vein = crack & (nb > 0.60) & (bg < 0.65)
            out = np.where(vein, acc_a, out)
            out = np.where(crack & (nb < 0.28) & (bg < 0.55), acc_b, out)
            out = np.where((fx > 1.2) & (fx < 2.4) & (fy > 1.2) & (fh > 0.55), bevel, out)

        elif style == "star_dome":
            # Planetarium: smooth polished indigo dome stone + fine celestial grid & star nodes
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.65 + warm * 0.12 + 0.15, 0.0, 0.999), bg)
            # Subtle 32x32 celestial meridian grid
            grid_line = ((xs % 32 == 0) & (ys % 2 == 0)) | ((ys % 32 == 0) & (xs % 2 == 0))
            out = np.where(grid_line, seam, out)
            # Star intersection nodes
            node = (xs % 32 == 0) & (ys % 32 == 0)
            node_arm = ((np.abs((xs % 32) - 0) <= 1) & (ys % 32 == 0)) | ((xs % 32 == 0) & (np.abs((ys % 32) - 0) <= 1))
            out = np.where(node_arm, acc_a, out)
            out = np.where(node, acc_b, out)
            # Concentric celestial dome arc centered in room
            cx, cy = W * 0.5, H * 0.5
            rad = np.hypot(xs - cx, (ys - cy) * 1.1)
            arc = (np.abs(rad - 54.0) < 0.8) | (np.abs(rad - 92.0) < 0.8)
            out = np.where(arc & (((xs + ys) % 3) != 0), acc_a, out)

        elif style == "shattered_debris":
            # Freefall floating debris islands: fractured marble & slate with cracked seams
            sx = xs % 16
            sy = ys % 12
            row_id = ys // 12
            ox = np.where((row_id & 1) == 1, 7, 0)
            cx_s = (xs + ox) % 16
            sh = hash01_grid((xs + ox) // 16, row_id, s.seed + 127)
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.55 + sh * 0.35 + warm * 0.12, 0.0, 0.999), bg)
            out = np.where((cx_s == 0) | (sy == 0), seam, out)
            out = np.where((sy == 1) & (cx_s > 1) & (sh > 0.40), bevel, out)
            # Diagonal fracture crack lines
            frac_n = np.abs(fbm_grid(H, W, 24.0, seed=s.seed + 131, octaves=2) - 0.5)
            out = np.where(frac_n < 0.018, seam, out)
            out = np.where((frac_n >= 0.018) & (frac_n < 0.028) & (bg < 0.55), acc_a, out)

        elif style == "train_carpet_deck":
            # Ember Express interior: mahogany booth wood + brass rail edge + warm floor vents
            pr = ys // 5
            py = ys % 5
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.45 + warm * 0.18 + 0.25, 0.0, 0.999), bg)
            out = np.where((py == 0) | ((xs + pr * 11) % 24 == 0), seam, out)
            out = np.where((py == 1) & (nb > 0.42), bevel, out)
            # Brass luggage-rail strips running horizontally along top & bottom cabin edges
            rail_y = (ys % 32 == 15) | (ys % 32 == 16)
            out = np.where(rail_y & (xs % 8 != 0), acc_a, out)
            out = np.where(rail_y & (xs % 8 == 0), acc_b, out)

        elif style in ("train_roof_plate", "colossus_hull"):
            # Riveted steel deck plates + ribbed corrugation / gear seams
            pw = 24 if style == "colossus_hull" else 16
            ph = 16
            px_i = xs % pw
            py_i = ys % ph
            phash = hash01_grid(xs // pw, ys // ph, s.seed + 139)
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.48 + phash * 0.40 + warm * 0.10, 0.0, 0.999), bg)
            if style == "train_roof_plate":
                # Corrugated roof ridges every 4px horizontally
                out = np.where((ys % 4 == 0), seam, out)
                out = np.where((ys % 4 == 1) & (bg < 0.55), bevel, out)
                out = np.where((px_i == 0), seam, out)
                # Rivet pairs along plate seams
                riv = ((px_i == 2) | (px_i == pw - 2)) & ((ys % 8 == 3))
                out = np.where(riv, acc_a, out)
            else:
                # Heavy iron colossus plates with corner rivets & recessed brass gear vents
                out = np.where((px_i == 0) | (py_i == 0), seam, out)
                out = np.where(((px_i == 1) | (py_i == 1)) & (phash > 0.35), bevel, out)
                riv = ((px_i == 2) | (px_i == pw - 3)) & ((py_i == 2) | (py_i == ph - 3))
                out = np.where(riv, acc_a, out)
                # Diagonal tread hatch in select plates
                tread = (phash > 0.72) & (((xs + ys) % 4) == 0) & (px_i > 3) & (px_i < pw - 3) & (py_i > 3) & (py_i < ph - 3)
                out = np.where(tread, acc_b, out)

        elif style == "stepped_stair":
            # Endless Stair: repeating directional stone stair treads & risers (8px deep steps)
            step_y = ys % 8
            step_x = (xs + (ys // 8) * 16) % 32
            sh = hash01_grid(xs // 16, ys // 8, s.seed + 149)
            out = ramp_blend(s.floor_ramp, np.clip(nb * 0.45 + sh * 0.35 + warm * 0.15, 0.0, 0.999), bg)
            # Crisp lit top nosing edge on each step + dark riser shadow below
            out = np.where(step_y == 0, bevel, out)
            out = np.where(step_y == 6, seam, out)
            out = np.where(step_y == 7, SHADE_IX[out], out)
            out = np.where((step_x == 0) & (step_y < 6), seam, out)
            # Subtle brass stair-rod accent along riser crease
            out = np.where((step_y == 5) & ((xs % 6) < 4) & (nb > 0.45), acc_a, out)

        elif style == "cave_floor":
            # Calm painterly subterranean cavern stone: smooth Bayer-dithered rock strata + sparse fractures
            warp_n = fbm_grid(H, W, 34.0, seed=s.seed + 163, octaves=3)
            strata = np.clip(nb * 0.58 + warp_n * 0.34 + warm * 0.06, 0.0, 0.999)
            out = ramp_blend(s.floor_ramp, strata, bg)
            # Sparse natural bedrock fracture crevices (calm, never busy camo contours)
            crack = (np.abs(warp_n - 0.46) < 0.012) & (nb < 0.55)
            out = np.where(crack, seam, out)
            out = np.where((np.abs(warp_n - 0.475) < 0.010) & (nb > 0.52) & (bg < 0.45), bevel, out)
            # Subtle scattered mineral/moss flecks
            out = np.where((nf < 0.008) & (warp_n > 0.56), acc_a, out)
            out = np.where((nf > 0.995) & (nb > 0.48), acc_b, out)

        else:
            # Fallback dressed stone
            out = base

        buf[mask] = out[mask]

    # ------------------------------------------------------------------ PATHS
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
        nf = ctx["n_fine"]

        edge_n = (~ctx["n_up_path"]) & (ly == 0)
        edge_s = (~ctx["n_dn_path"]) & (ly == ts - 1)
        edge_w = (~ctx["n_lt_path"]) & (lx == 0)
        edge_e = (~ctx["n_rt_path"]) & (lx == ts - 1)
        is_edge = edge_n | edge_s | edge_w | edge_e

        in_n = (~ctx["n_up_path"]) & (ly == 1)
        in_s = (~ctx["n_dn_path"]) & (ly == ts - 2)
        in_w = (~ctx["n_lt_path"]) & (lx == 1)
        in_e = (~ctx["n_rt_path"]) & (lx == ts - 2)
        is_inner = in_n | in_s | in_w | in_e

        main = IX[s.path_main]
        hi = IX[s.path_hi]
        edge = IX[s.path_edge]
        trim = IX[s.path_trim]
        dk = SHADE_IX[main]

        out = np.full(buf.shape, main, dtype=np.uint8)
        style = s.path_style

        if style == "carpet_runner":
            # Ornate bordered rug runner (manor, train interior, theatre, archive, toll_house)
            weave = (((xs + ys) % 6) == 0) & (bg < 0.45)
            out = np.where((nb > 0.56) & (bg < 0.42), hi, out)
            out = np.where(weave, dk, out)
            # Diamond medallion repeat along center
            dm = (np.abs((xs % 16) - 8) + np.abs((ys % 16) - 8)) == 4
            out = np.where(dm, trim, out)
            out = np.where(is_inner, trim, out)
            out = np.where(is_edge, edge, out)

        elif style == "catwalk_grate":
            # Industrial metal grate catwalk (train roof, colossus, great_toll_shaft, forge)
            slot = ((xs % 4 == 0) | (ys % 4 == 0))
            out = np.where(slot, dk, out)
            out = np.where((xs % 4 == 1) & (ys % 4 == 1) & (bg < 0.60), hi, out)
            out = np.where(is_inner, trim, out)
            out = np.where(is_edge, edge, out)

        elif style == "boardwalk":
            # Timber planks (galleon, locks, wick_house, under_root)
            out = np.where((ly % 6 == 0) & (bg < 0.58), dk, out)
            out = np.where((ly % 6 == 1) & (nb > 0.52) & (bg < 0.42), hi, out)
            out = np.where((lx % 12 == 0) & (ly % 6 == 3) & (bg < 0.55), trim, out)
            out = np.where(is_edge & (bg < 0.78), edge, out)

        elif style == "inlaid_strip":
            # Ceremonial / astral / marble inlaid walkway (planetarium, meteor_vault, palace, masquerade, briar_court)
            out = np.where((nb > 0.55) & (bg < 0.45), hi, out)
            seam = (ys % 8 == 0) | (((xs + np.where(((ys // 8) & 1) == 1, 8, 0)) % 16) == 0)
            out = np.where(seam, dk, out)
            out = np.where(is_inner & (((xs + ys) % 3) != 0), trim, out)
            out = np.where(is_edge, edge, out)

        elif style == "sand_trail":
            # Organic cobbled / worn trail (seabed, under_root, hourglass_maze, caves)
            out = np.where((nb > 0.52) & (bg < 0.55), hi, out)
            out = np.where((nf < 0.04), trim, out)
            out = np.where((nf > 0.96), dk, out)
            # Soft organic edge curbing
            out = np.where(is_edge & (((xs + ys) % 4) != 0), edge, out)

        else:
            # Dressed flagstone path
            seam = (ly % 8 == 0) | (((lx + np.where(((ly // 8) & 1) == 1, 8, 0)) % 16) == 0)
            out = np.where((nb > 0.54) & (bg < 0.42), hi, out)
            out = np.where(seam, dk, out)
            out = np.where(is_inner & ((xs + ys) % 4 == 0), trim, out)
            out = np.where(is_edge & ((xs + ys) % 5 != 0), edge, out)

        buf[mask] = out[mask]

    # ------------------------------------------------------------------ SPECIAL FLOOR TILES
    def paint_special_floors(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]

        # D: carpet / dais
        if np.any(ctx["m_carpet"]):
            m = ctx["m_carpet"]
            lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
            out = np.full(buf.shape, IX[s.path_main], dtype=np.uint8)
            out = np.where(((xs + ys) % 8 == 0) & (bg < 0.4), IX[s.path_hi], out)
            border = (lx == 0) | (lx == ts - 1) | (ly == 0) | (ly == ts - 1)
            out = np.where(border, IX[s.path_trim], out)
            buf[m] = out[m]

        # S: stairs
        if np.any(ctx["m_stairs"]):
            m = ctx["m_stairs"]
            step_y = ys % 4
            out = np.full(buf.shape, IX[s.floor_ramp[min(2, len(s.floor_ramp) - 1)]], dtype=np.uint8)
            out = np.where(step_y == 0, IX[s.floor_bevel], out)
            out = np.where(step_y == 3, IX[s.floor_seam], out)
            buf[m] = out[m]

        # H: grate / hearth
        if np.any(ctx["m_grate"]):
            m = ctx["m_grate"]
            lx, ly = ctx["lx"], ctx["ly"]
            bar = (lx % 4 == 0) | (ly % 4 == 0)
            out = np.where(bar, IX[s.wall_face], IX[s.floor_accent_a])
            out = np.where((lx % 4 == 2) & (ly % 4 == 2) & (bg < 0.65), IX[s.floor_accent_b], out)
            buf[m] = out[m]

        # R: rail / track
        if np.any(ctx["m_rail"]):
            m = ctx["m_rail"]
            lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
            # Sleepers + twin steel rails
            sleeper = (xs % 6 < 2)
            rail_bar = (ly == 3) | (ly == 4) | (ly == ts - 5) | (ly == ts - 4)
            out = np.where(sleeper, IX[s.wall_base], IX[s.floor_ramp[0]])
            out = np.where(rail_bar, IX[s.wall_lip], out)
            out = np.where((ly == 3) | (ly == ts - 5), IX["cream"], out)
            buf[m] = out[m]

    # ------------------------------------------------------------------ WALLS (3/4 DEPTH!)
    def paint_walls(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_wall"] | ctx["m_foliage"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly = ctx["lx"], ctx["ly"]
        ts = ctx["ts"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        nf = ctx["n_fine"]
        warm = ctx["warm"]
        tile_h = ctx["tile_h"]

        up_open = ~ctx["n_up_wall"]
        dn_open = ~ctx["n_dn_wall"]
        lt_open = ~ctx["n_lt_wall"]
        rt_open = ~ctx["n_rt_wall"]

        cap_0, cap_1, cap_2 = IX[s.wall_cap[0]], IX[s.wall_cap[1]], IX[s.wall_cap[2]]
        lip = IX[s.wall_lip]
        face = IX[s.wall_face]
        face_hi = IX[s.wall_face_hi]
        base = IX[s.wall_base]

        # Default cap body
        out = np.where((nb > 0.54) & (bg < 0.50), cap_2, np.where(nf > 0.10, cap_1, cap_0))
        style = s.wall_style

        if style == "masonry":
            # Dressed stone courses on cap + crisp 6px south-facing wall face
            cap_seam = (ly % 8 == 0) | (((lx + np.where(((ly // 8) & 1) == 1, 4, 0)) % 8) == 0)
            out = np.where(cap_seam, SHADE_IX[cap_0], out)
            south = dn_open & (ly >= ts - 6)
            out = np.where(south & (ly == ts - 6), lip, out)
            out = np.where(south & (ly > ts - 6) & (ly < ts - 1), face, out)
            # Highlighted alternating ashlar bricks on south face
            course = np.where(ly >= ts - 3, 4, 0)
            brick_j = ((xs + course) % 8 == 0) & (ly > ts - 6)
            brick_hi = ((xs + course) % 8 == 1) & (ly == ts - 5)
            out = np.where(south & (ly == ts - 3), base, out)
            out = np.where(south & brick_hi, face_hi, out)
            out = np.where(south & brick_j, base, out)
            out = np.where(south & (ly == ts - 1), base, out)

        elif style == "wainscot":
            # Manor / Archive / Theatre / Toll House: molded wood paneling + wallpaper/trim cap
            out = np.where((lx % 8 == 0), SHADE_IX[cap_0], out)
            south = dn_open & (ly >= ts - 7)
            out = np.where(south & (ly == ts - 7), lip, out)
            out = np.where(south & (ly > ts - 7) & (ly < ts - 1), face, out)
            # Recessed panel rectangles every 12px
            pan_x = xs % 12
            pan_in = south & (ly >= ts - 5) & (ly <= ts - 2) & (pan_x >= 2) & (pan_x <= 9)
            out = np.where(pan_in & ((ly == ts - 5) | (pan_x == 2)), face_hi, out)
            out = np.where(pan_in & ((ly == ts - 2) | (pan_x == 9)), base, out)
            out = np.where(south & (ly == ts - 1), base, out)

        elif style == "bookshelf":
            # Archive: top oak cornice + colorful leather-bound book spines on south face!
            out = np.where((ly % 4 == 0), SHADE_IX[cap_0], out)
            south = dn_open & (ly >= ts - 7)
            out = np.where(south & (ly == ts - 7), lip, out)
            # Two shelves of vertical book spines (ly = ts-6..ts-4 and ts-3..ts-2)
            spine_h = hash01_grid(xs // 2, ys // 3, s.seed + 211)
            spine_c = np.where(
                spine_h < 0.25, IX["wine"],
                np.where(spine_h < 0.48, IX["teal"],
                np.where(spine_h < 0.68, IX["blue"],
                np.where(spine_h < 0.85, IX["apricot"], IX["mauve"])))
            )
            out = np.where(south & (ly > ts - 7) & (ly < ts - 1), spine_c, out)
            out = np.where(south & ((xs % 2 == 1) & (ly > ts - 7)), SHADE_IX[out], out)
            out = np.where(south & ((ly == ts - 4) | (ly == ts - 1)), base, out)
            out = np.where(south & (xs % 16 == 0) & (ly > ts - 7), face_hi, out)

        elif style == "velvet_curtain":
            # Doppel Theatre: pleated vertical drapery folds with gold tassel valance
            fold = np.sin(xs.astype(np.float32) * 0.9)
            out = np.where(fold > 0.35, cap_2, np.where(fold < -0.35, cap_0, cap_1))
            south = dn_open & (ly >= ts - 7)
            out = np.where(south & (ly == ts - 7), lip, out)
            out = np.where(south & (ly > ts - 7) & (ly < ts - 1), np.where(fold > 0.2, face_hi, np.where(fold < -0.3, base, face)), out)
            # Gold scalloped fringe at hem
            out = np.where(south & (ly == ts - 2) & ((xs % 4) < 2), lip, out)
            out = np.where(south & (ly == ts - 1), base, out)

        elif style == "riveted_iron":
            # Ember Express / Colossus / Forge: bolted iron bulkhead plates + brass trim
            out = np.where((lx % 16 == 0) | (ly % 8 == 0), base, out)
            riv_top = ((lx == 2) | (lx == 13)) & ((ly == 2) | (ly == 6))
            out = np.where(riv_top, lip, out)
            south = dn_open & (ly >= ts - 6)
            out = np.where(south & (ly == ts - 6), lip, out)
            out = np.where(south & (ly > ts - 6) & (ly < ts - 1), face, out)
            out = np.where(south & (xs % 12 == 0), base, out)
            out = np.where(south & (ly == ts - 4) & ((xs % 12 == 2) | (xs % 12 == 10)), face_hi, out)
            out = np.where(south & (ly == ts - 1), base, out)

        elif style == "ship_hull":
            # Galleon: curved oak timber strakes + iron-banded ribs + brass portholes
            out = np.where(ly % 4 == 0, base, out)
            out = np.where(xs % 16 == 0, face_hi, out)
            south = dn_open & (ly >= ts - 6)
            out = np.where(south & (ly == ts - 6), lip, out)
            out = np.where(south & (ly > ts - 6) & (ly < ts - 1), face, out)
            out = np.where(south & (ly == ts - 3), base, out)
            # Brass porthole every 32px
            port = south & (xs % 32 >= 14) & (xs % 32 <= 17) & (ly >= ts - 5) & (ly <= ts - 2)
            out = np.where(port, IX["apricot"], out)
            out = np.where(south & (xs % 32 >= 15) & (xs % 32 <= 16) & (ly >= ts - 4) & (ly <= ts - 3), IX["sky"], out)
            out = np.where(south & (ly == ts - 1), base, out)

        elif style == "hedge_topiary":
            # Briar Court / Hourglass Maze / Garden Party: sculpted leafy hedge + stone plinth base
            leaf_n = vnoise_grid(ctx["H"], ctx["W"], 6.0, seed=s.seed + 223)
            out = np.where((leaf_n > 0.62) & (bg < 0.65), cap_2, np.where(leaf_n < 0.30, cap_0, cap_1))
            # Occasional rose/gold blossom buds on hedge top
            out = np.where((nf > 0.985) & (~dn_open | (ly < ts - 5)), lip, out)
            south = dn_open & (ly >= ts - 6)
            out = np.where(south & (ly == ts - 6), cap_2, out)
            out = np.where(south & (ly > ts - 6) & (ly < ts - 2), np.where(leaf_n > 0.5, face_hi, face), out)
            out = np.where(south & (ly == ts - 2), IX["mauve"], out)  # clipped stone curb
            out = np.where(south & (ly == ts - 1), base, out)

        elif style == "organic_rib":
            # Leviathan belly: sculpted organic cartilage & spaced curving ivory ribs (NOT candy stripes!)
            org_n = fbm_grid(ctx["H"], ctx["W"], 22.0, seed=s.seed + 227, octaves=2)
            out = ramp_blend(s.wall_cap, np.clip(org_n * 0.75 + nb * 0.25, 0.0, 0.999), bg)
            # Curved spaced bone rib arches every 28px along walls
            rib_x = (xs + (org_n * 6.0).astype(np.int32)) % 28
            rib = (rib_x >= 11) & (rib_x <= 15)
            out = np.where(rib & (rib_x <= 13), cap_2, np.where(rib, cap_1, out))
            south = dn_open & (ly >= ts - 6)
            out = np.where(south & (ly == ts - 6), lip, out)
            out = np.where(south & (ly > ts - 6) & (ly < ts - 1), np.where(rib, face_hi, face), out)
            out = np.where(south & (ly == ts - 1), base, out)

        elif style == "root_bark":
            # Under-Root: lush mossy root-canopy cap + gnarled dark timber/root south face!
            canopy_n = fbm_grid(ctx["H"], ctx["W"], 18.0, seed=s.seed + 229, octaves=2)
            out = ramp_blend(s.wall_cap, np.clip(canopy_n * 0.75 + warm * 0.20, 0.0, 0.999), bg)
            # Subtle mossy leaf highlights on top
            out = np.where((nf > 0.985) & (~dn_open | (ly < ts - 6)), lip, out)
            south = dn_open & (ly >= ts - 7)
            # Draped hanging moss lip over gnarled bark face
            moss_lip = ts - 7 + np.where(canopy_n > 0.55, 1, 0)
            out = np.where(south & (ly <= moss_lip), cap_2, out)
            bark_v = ((xs + (canopy_n * 5.0).astype(np.int32)) % 9)
            out = np.where(south & (ly > moss_lip) & (ly < ts - 1), np.where(bark_v == 0, base, np.where(bark_v == 2, face_hi, face)), out)
            out = np.where(south & (ly == ts - 1), base, out)

        elif style == "marble_balustrade":
            # Inverted Palace / Masquerade / Planetarium: fluted columns & gilded cornice
            flute = (xs % 4 == 0)
            out = np.where(flute, cap_0, out)
            out = np.where((xs % 4 == 1) & (nb > 0.35), cap_2, out)
            south = dn_open & (ly >= ts - 6)
            out = np.where(south & (ly == ts - 6), lip, out)
            out = np.where(south & (ly > ts - 6) & (ly < ts - 1), np.where((xs % 4 == 1), face_hi, face), out)
            out = np.where(south & (xs % 16 == 0) & (ly > ts - 6), lip, out)
            out = np.where(south & (ly == ts - 1), base, out)

        elif style == "cavern_rock":
            # Calm terraced subterranean cavern rock (smooth chamfer depth falloff, ZERO square steps or camo blobs!)
            rock_n = fbm_grid(ctx["H"], ctx["W"], 28.0, seed=s.seed + 233, octaves=2)
            wall_d = chamfer_dist(ctx["m_wall"])
            # Smoothly brighter rock ledges near open cavern rooms, smoothly deeper dark rock further inside wall mass
            edge_boost = np.clip(1.0 - wall_d / 18.0, 0.0, 1.0) * 0.42 - 0.14
            out = ramp_blend(s.wall_cap, np.clip(rock_n * 0.65 + edge_boost + 0.14, 0.0, 0.999), bg)
            south = dn_open & (ly >= ts - 7)
            lip_y = ts - 7 + np.where(rock_n > 0.52, 0, 1)
            out = np.where(south & (ly == lip_y), lip, out)
            # Sculpted vertical strata facets on south cliff face
            facet = ((xs + (ly // 2) * 3 + (rock_n * 4.0).astype(np.int32)) % 9)
            out = np.where(
                south & (ly > lip_y) & (ly < ts - 1),
                np.where(facet == 0, base, np.where((facet == 1) & (ly < ts - 3), face_hi, face)),
                out,
            )
            out = np.where(south & (ly == ts - 1), base, out)

        else:
            # Generic sculpted wall
            south = dn_open & (ly >= ts - 6)
            out = np.where(south & (ly == ts - 6), lip, out)
            out = np.where(south & (ly > ts - 6) & (ly < ts - 1), face, out)
            out = np.where(south & (ly == ts - 1), base, out)

        # Crisp top edge highlight (north) and lit west rim (WNW Last Light sun!)
        out = np.where(up_open & (ly == 0), lip, out)
        west_rim = lt_open & (lx == 0) & (~(dn_open & (ly >= ts - 5)))
        out = np.where(west_rim & (bg < 0.45 + 0.45 * warm), LIGHT_IX[out], out)
        # Cool moonlight rim on far east edge
        out = np.where(west_rim & (warm < 0.25), COOL_IX[out], out)
        # Subtle shadow line on east wall border
        east_rim = rt_open & (lx == ts - 1) & (~(dn_open & (ly >= ts - 5)))
        out = np.where(east_rim, base, out)

        buf[mask] = out[mask]

    # ------------------------------------------------------------------ WATER
    def paint_water(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_water"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        H, W = ctx["H"], ctx["W"]

        deep = IX[s.water_deep]
        mid = IX[s.water_mid]
        hi = IX[s.water_hi]
        foam = IX[s.water_foam]

        shore = (
            (lx < 2) & ctx["n_lt_land"]
            | (ly < 2) & ctx["n_up_land"]
            | (lx >= ts - 2) & ctx["n_rt_land"]
            | (ly >= ts - 2) & ctx["n_dn_land"]
        )

        if s.water_style == "magma_river":
            # Flowing molten slag plates with bright gold/cream fracture veins
            m1 = fbm_grid(H, W, 20.0, seed=s.seed + 301, octaves=2, sx=0.85, sy=0.65)
            r1 = np.maximum(0.0, 1.0 - np.abs(m1 * 2.0 - 1.0) * 1.75)
            heat = r1 * r1
            out = np.where(heat > 0.72, IX["cream"], np.where(heat > 0.48, foam, np.where(heat > 0.28, hi, np.where(heat > 0.14, mid, deep))))
            out = np.where(shore, IX["night"], out)
        elif s.water_style == "acid_digest":
            # Bubbling teal/jade digestive acid pools with organically jittered bubble rings
            rip = fbm_grid(H, W, 16.0, seed=s.seed + 307, octaves=2)
            out = ramp_blend((s.water_deep, s.water_mid, s.water_hi), rip, bg)
            # Jittered per-cell organic bubble rings (never grid-aligned polka dots!)
            cx_id, cy_id = xs // 18, ys // 18
            bh = hash01_grid(cx_id, cy_id, s.seed + 311)
            jx = (hash01_grid(cx_id, cy_id, s.seed + 312) * 8.0 + 5.0)
            jy = (hash01_grid(cx_id, cy_id, s.seed + 314) * 8.0 + 5.0)
            brad = 1.8 + hash01_grid(cx_id, cy_id, s.seed + 315) * 1.8
            br = np.hypot((xs % 18) - jx, (ys % 18) - jy)
            bub = (bh > 0.62) & (np.abs(br - brad) < 0.65) & (~shore)
            out = np.where(bub, foam, out)
            out = np.where(shore & (bg < 0.68), foam, out)
        elif s.water_style == "moon_mirror":
            # Still starry-mirror moon pools reflecting constellations & ripples
            rip = fbm_grid(H, W, 22.0, seed=s.seed + 313, octaves=2)
            out = np.where(rip > 0.66, hi, np.where(rip < 0.36, deep, mid))
            star = hash01_grid(xs, ys, s.seed + 317) > 0.992
            out = np.where(star, foam, out)
            out = np.where(shore, np.where(bg < 0.70, foam, hi), out)
        elif s.water_style == "koi_pond":
            # Garden pond with lily pads & rose lotus blossoms
            rip = fbm_grid(H, W, 16.0, seed=s.seed + 319, octaves=2, sx=0.8, sy=1.4)
            out = np.where(rip > 0.65, hi, np.where(rip < 0.35, deep, mid))
            out = np.where(shore & (bg < 0.60), foam, out)
            cx_l, cy_l = (xs % 10) - 5, (ys % 10) - 5
            lh = hash01_grid(xs // 10, ys // 10, s.seed + 323)
            pad = (lh > 0.80) & ((cx_l * cx_l + cy_l * cy_l) <= 10) & (~shore)
            out = np.where(pad, np.where(cy_l < 0, IX["lime"], IX["jade"]), out)
            out = np.where(pad & (cx_l == 0) & (cy_l == 0) & (lh > 0.88), IX["rose"], out)
        else:
            # Canal / rain / bilge / tidepool / subterranean water
            rip = fbm_grid(H, W, 14.0, seed=s.seed + 331, octaves=2, sx=0.75, sy=1.6)
            out = np.where((rip > 0.66) & (bg < 0.68), hi, np.where(rip < 0.34, deep, mid))
            # Crisp specular wave dashes
            dash = (rip > 0.74) & (ys % 4 == 1) & (bg < 0.55)
            out = np.where(dash, foam, out)
            if s.water_style == "rain_water":
                # Jittered concentric raindrop rings (organic, never grid-aligned!)
                cx_id, cy_id = xs // 22, ys // 22
                rh = hash01_grid(cx_id, cy_id, s.seed + 337)
                jx = hash01_grid(cx_id, cy_id, s.seed + 338) * 10.0 + 6.0
                jy = hash01_grid(cx_id, cy_id, s.seed + 339) * 10.0 + 6.0
                rrad = 2.6 + hash01_grid(cx_id, cy_id, s.seed + 340) * 2.2
                rr = np.hypot((xs % 22) - jx, ((ys % 22) - jy) * 1.3)
                out = np.where((rh > 0.62) & (np.abs(rr - rrad) < 0.60) & (~shore), foam, out)
            out = np.where(shore, np.where(bg < 0.62, foam, hi), out)
            # Top recessed stone bank lip when north neighbor is land
            bank_n = ctx["n_up_land"] & (ly < 2)
            out = np.where(bank_n & (ly == 0), IX[s.wall_base], out)

        buf[mask] = out[mask]

    # ------------------------------------------------------------------ TIDE
    def paint_tide(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_tide"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]
        nb = ctx["n_broad"]
        out = np.where((nb > 0.56) & (bg < 0.55), IX["ice"], IX["sky"])
        out = np.where(ly % 4 == 0, IX["blue"], out)
        out = np.where((lx == 0) | (lx == ts - 1), IX["deep"], out)
        buf[mask] = out[mask]

    # ------------------------------------------------------------------ PIT & VOID & PHANTOM
    def paint_void(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_void"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        bg = ctx["bg"]
        H, W = ctx["H"], ctx["W"]
        out = np.full((H, W), IX["void"], dtype=np.uint8)
        style = s.void_style

        if style == "starry_cosmos":
            neb = fbm_grid(H, W, 56.0, seed=s.seed + 401, octaves=2)
            out = np.where((neb > 0.62) & (bg < 0.50), IX["deep"], np.where((neb > 0.48) & (bg < 0.55), IX["night"], out))
            h1 = hash01_grid(xs, ys, s.seed + 409)
            out = np.where(h1 > 0.996, IX["ice"], np.where(h1 > 0.992, IX["sky"], np.where(h1 > 0.989, IX["gold"], out)))
        elif style == "sky_freefall":
            # Streaking sunset-to-cosmos wind lines & tumbling star dust!
            neb = fbm_grid(H, W, 42.0, seed=s.seed + 413, octaves=2, sx=1.8, sy=0.35)
            out = np.where((neb > 0.58) & (bg < 0.50), IX["dusk"], np.where((neb > 0.42) & (bg < 0.55), IX["deep"], out))
            streak = (hash01_grid(xs // 1, ys // 14, s.seed + 419) > 0.975) & ((ys % 14) < 9)
            out = np.where(streak, IX["sky"], out)
            out = np.where((hash01_grid(xs, ys, s.seed + 421) > 0.996), IX["cream"], out)
        elif style == "train_rush":
            # Horizontal speeding sunset-volcanic horizon blur outside the Ember Express!
            band = fbm_grid(H, W, 28.0, seed=s.seed + 431, octaves=2, sx=0.18, sy=2.4)
            out = np.where(band > 0.66, IX["wine"], np.where(band > 0.48, IX["plum"], np.where(band > 0.32, IX["dusk"], IX["night"])))
            # Fast horizontal speed-streaks (sparks & ties whipping past)
            sp = (hash01_grid(xs // 18, ys, s.seed + 433) > 0.972) & ((xs % 18) < 11)
            out = np.where(sp, IX["coral"], out)
            sp2 = (hash01_grid(xs // 10, ys, s.seed + 439) > 0.992) & ((xs % 10) < 5)
            out = np.where(sp2, IX["gold"], out)
        elif style == "shaft_drop":
            # Vertical rushing tower-shaft darkness with dim stone ribs & vertical wind lines
            rib = (xs % 24 == 0) | (xs % 24 == 1)
            out = np.where(rib & (bg < 0.45), IX["night"], out)
            wline = (hash01_grid(xs, ys // 16, s.seed + 443) > 0.982) & ((ys % 16) < 10)
            out = np.where(wline, IX["dusk"], out)
        elif style == "sunset_void":
            # Wick House cozy silky Bayer-dithered sunset-to-starry sky (zero vertical stripe seams!)
            sky_n = fbm_grid(H, W, 64.0, seed=s.seed + 447, octaves=2)
            grad = np.clip((1.0 - xs.astype(np.float32) / float(max(1, W))) * 0.88 + (sky_n - 0.5) * 0.22, 0.0, 0.999)
            out = ramp_blend(("void", "night", "dusk", "plum", "wine"), grad, bg)
            h1 = hash01_grid(xs, ys, s.seed + 449)
            out = np.where(h1 > 0.996, np.where(grad > 0.5, IX["gold"], IX["ice"]), out)
        elif style == "mirror_void":
            # Moon-glass void with faint vertical silver reflections
            ref = fbm_grid(H, W, 24.0, seed=s.seed + 457, octaves=2, sx=2.0, sy=0.4)
            out = np.where((ref > 0.65) & (bg < 0.45), IX["deep"], np.where((ref > 0.50) & (bg < 0.45), IX["night"], out))
            out = np.where(hash01_grid(xs, ys, s.seed + 461) > 0.996, IX["ice"], out)
        else:
            # Deep architectural abyss with subtle dust motes
            h1 = hash01_grid(xs, ys, s.seed + 463)
            out = np.where(h1 > 0.9965, IX["night"], out)

        # Crisp 6px cliff/wall drop-face at top edge of void where north tile is walkable land
        drop_n = ctx["n_up_land"] & (ctx["ly"] < 6)
        ly = ctx["ly"]
        out = np.where(drop_n & (ly == 0), IX[s.wall_cap[1]], out)
        out = np.where(drop_n & (ly > 0) & (ly < 4), np.where(((xs + (ly // 2) * 4) % 8 == 0), IX["void"], IX[s.wall_face]), out)
        out = np.where(drop_n & (ly == 4), IX[s.wall_base], out)
        out = np.where(drop_n & (ly == 5), IX["void"], out)

        buf[mask] = out[mask]

    def paint_pit(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_pit"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly = ctx["lx"], ctx["ly"]
        bg = ctx["bg"]
        H, W = ctx["H"], ctx["W"]

        if s.pit_style == "lava_pit":
            m1 = fbm_grid(H, W, 18.0, seed=s.seed + 503, octaves=2, sx=0.8, sy=0.7)
            out = np.where(m1 > 0.68, IX["gold"], np.where(m1 > 0.52, IX["apricot"], np.where(m1 > 0.36, IX["coral"], IX["wine"])))
        elif s.pit_style == "gear_chasm":
            # Recessed dark shaft with giant dimly-lit brass gear teeth peeking out of the depths!
            out = np.full((H, W), IX["void"], dtype=np.uint8)
            gx, gy = (xs % 48) - 24, (ys % 48) - 24
            r = np.hypot(gx, gy)
            ang = np.arctan2(gy, gx)
            teeth = (r >= 13.0) & (r <= 17.0) & (np.sin(ang * 10.0) > 0.15)
            rim_g = (r >= 9.0) & (r < 13.0)
            spoke = (r < 9.0) & ((np.abs(gx) < 2) | (np.abs(gy) < 2))
            gear = teeth | rim_g | spoke
            out = np.where(gear, np.where(bg < 0.60, IX["dusk"], IX["night"]), out)
            out = np.where(gear & (gy < -5) & (bg < 0.40), IX["plum"], out)
        elif s.pit_style == "star_chasm":
            out = np.full((H, W), IX["void"], dtype=np.uint8)
            h1 = hash01_grid(xs, ys, s.seed + 509)
            out = np.where(h1 > 0.995, IX["sky"], np.where(h1 > 0.990, IX["deep"], out))
        elif s.pit_style == "loom_void":
            # Deep void crossed by faint dim vertical warp threads far below
            out = np.full((H, W), IX["void"], dtype=np.uint8)
            thread = (xs % 10 == 4) & (ys % 2 == 0)
            out = np.where(thread, IX["night"], out)
            out = np.where((xs % 30 == 4) & (ys % 3 == 0), IX["dusk"], out)
        elif s.pit_style == "shaft_drop":
            out = np.full((H, W), IX["void"], dtype=np.uint8)
            wline = (hash01_grid(xs, ys // 12, s.seed + 521) > 0.975) & ((ys % 12) < 7)
            out = np.where(wline, IX["night"], out)
        else:
            out = np.full((H, W), IX["void"], dtype=np.uint8)
            h1 = hash01_grid(xs, ys, s.seed + 523)
            out = np.where(h1 > 0.996, IX["night"], out)

        # Crisp 5px recessed drop-wall along top edge of pit where north is walkable land
        drop_n = ctx["n_up_land"] & (ly < 5)
        out = np.where(drop_n & (ly == 0), IX[s.wall_cap[1]], out)
        out = np.where(drop_n & (ly > 0) & (ly < 4), np.where(((xs + (ly // 2) * 4) % 8 == 0), IX["void"], IX[s.wall_face]), out)
        out = np.where(drop_n & (ly == 4), IX["void"], out)
        # Left edge slight shadow bevel
        drop_w = ctx["n_lt_land"] & (lx < 2) & (~drop_n)
        out = np.where(drop_w, IX["night"], out)

        buf[mask] = out[mask]

    def paint_phantom(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        # ZERO-GHOST RULE: phantom renders as deep dark chasm, NEVER cyan dashes!
        mask = ctx["m_phantom"]
        if not np.any(mask):
            return
        xs, ys = ctx["xs"], ctx["ys"]
        ly = ctx["ly"]
        s = self.spec
        out = np.where(hash01_grid(xs, ys, s.seed + 541) > 0.995, IX["deep"], IX["void"]).astype(np.uint8)
        drop_n = ctx["n_up_land"] & (ly < 5)
        out = np.where(drop_n & (ly == 0), IX[s.wall_cap[1]], out)
        out = np.where(drop_n & (ly > 0) & (ly < 4), IX[s.wall_face], out)
        out = np.where(drop_n & (ly == 4), IX["void"], out)
        buf[mask] = out[mask]

    # ------------------------------------------------------------------ BRIDGE & GLASS
    def paint_bridge(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_bridge"]
        if not np.any(mask):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        bg = ctx["bg"]

        rail_n = (ly == 0) & (~ctx["n_up_bridge"]) & (~ctx["n_up_land"])
        rail_s = (ly == ts - 1) & (~ctx["n_dn_bridge"]) & (~ctx["n_dn_land"])
        rail_w = (lx == 0) & (~ctx["n_lt_bridge"]) & (~ctx["n_lt_land"])
        rail_e = (lx == ts - 1) & (~ctx["n_rt_bridge"]) & (~ctx["n_rt_land"])
        rail = rail_n | rail_s | rail_w | rail_e

        in_n = (ly == 1) & (~ctx["n_up_bridge"]) & (~ctx["n_up_land"])
        in_s = (ly == ts - 2) & (~ctx["n_dn_bridge"]) & (~ctx["n_dn_land"])

        main = IX[s.bridge_main]
        hi = IX[s.bridge_hi]
        rail_c = IX[s.bridge_rail]
        dk = IX[s.bridge_dark]

        if s.bridge_style == "iron_grate":
            out = np.where((lx % 4 == 0) | (ly % 4 == 0), dk, main)
            out = np.where((lx % 4 == 1) & (ly % 4 == 1), hi, out)
        elif s.bridge_style == "stone_arch":
            out = np.where((lx % 8 == 0) | (ly % 8 == 0), dk, main)
            out = np.where((lx % 8 == 1) & (ly % 8 == 1), hi, out)
        elif s.bridge_style == "silk_span":
            out = np.where((ys % 3 == 0), hi, main)
            out = np.where((xs % 8 == 0), dk, out)
        elif s.bridge_style == "bone_span":
            # Curved rib bridge
            out = np.where((lx % 4 == 0), dk, np.where((lx % 4 == 1), hi, main))
        else:
            # Timber planks
            out = np.where(lx % 4 == 0, dk, np.where(((lx // 4) % 2 == 0) & (bg < 0.55), hi, main))

        out = np.where(in_n | in_s, dk, out)
        out = np.where(rail, np.where(((xs + ys) % 4 != 0), rail_c, dk), out)
        buf[mask] = out[mask]

    def paint_glass(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        mask = ctx["m_glass"]
        if not np.any(mask):
            return
        s = self.spec
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]
        frame = (lx == 0) | (lx == ts - 1) | (ly == 0) | (ly == ts - 1)
        gleam = ((lx + ly) % 7 == 0)
        out = np.where((lx + ly) < ts, IX[s.glass_hi], IX[s.glass_main])
        out = np.where(gleam, IX["cream"], out)
        out = np.where(frame, IX[s.glass_frame], out)
        buf[mask] = out[mask]

    # ------------------------------------------------------------------ ABYSS RIMS
    def paint_abyss_rims(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        """Crisp 1px luminous coping edge along every walkable pixel bordering pit/void/phantom."""
        walk = ctx["m_walk"]
        if not np.any(walk):
            return
        s = self.spec
        xs, ys = ctx["xs"], ctx["ys"]
        lx, ly, ts = ctx["lx"], ctx["ly"], ctx["ts"]

        on_s = walk & ctx["n_dn_abyss"] & (ly == ts - 1)
        on_w = walk & ctx["n_lt_abyss"] & (lx == 0)
        on_n = walk & ctx["n_up_abyss"] & (ly == 0)
        on_e = walk & ctx["n_rt_abyss"] & (lx == ts - 1)

        hi = IX[s.rim_hi]
        mid = IX[s.rim_mid]

        buf[on_s] = np.where((xs % 8 == 0), mid, hi)[on_s]
        buf[on_w] = np.where((ys % 8 == 0), mid, hi)[on_w]
        buf[on_n] = np.where(((xs + 2) % 4 == 0), mid, hi)[on_n]
        buf[on_e] = np.where(((ys + 2) % 4 == 0), mid, hi)[on_e]

    # ------------------------------------------------------------------ WALL AO
    def paint_wall_ao(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        walk = ctx["m_walk"]
        if not np.any(walk):
            return
        ly, lx = ctx["ly"], ctx["lx"]
        bg = ctx["bg"]
        d = max(2, self.spec.wall_ao_depth)

        sh_n = walk & ctx["n_up_wall"] & (ly < d) & ((ly == 0) | ((1.0 - ly.astype(np.float32) / (d + 0.5)) > bg))
        sh_w = walk & ctx["n_lt_wall"] & (lx < d) & ((lx == 0) | ((1.0 - lx.astype(np.float32) / (d + 0.5)) > bg))
        sh_nw = walk & (~ctx["n_up_wall"]) & (~ctx["n_lt_wall"]) & ctx["n_nw_wall"] & (lx < 3) & (ly < 3) & (bg < 0.5)
        sh = sh_n | sh_w | sh_nw
        buf[sh] = SHADE_IX[buf[sh]]

    # ------------------------------------------------------------------ EXIT FRAMING
    def paint_exits(self, buf: np.ndarray, ctx: dict[str, Any], exits: list[dict[str, Any]]) -> None:
        H, W, ts = ctx["H"], ctx["W"], ctx["ts"]
        grid = ctx["grid"]
        s = self.spec
        hi = IX[s.wall_lip]
        mid = IX[s.wall_cap[1]]
        dk = IX[s.wall_base]

        def set_if(wx: int, wy: int, ci: int, allowed: set[str]) -> None:
            if 0 <= wx < W and 0 <= wy < H and grid[wy // ts][wx // ts] in allowed:
                buf[wy, wx] = ci

        jamb_t = WALKABLE_TYPES | {"wall"}
        for ex in exits:
            if not isinstance(ex, dict):
                continue
            rect = ex.get("rect")
            if not (isinstance(rect, list) and len(rect) >= 4):
                continue
            rx, ry, rw, rh = int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])
            if rw <= 0 or rh <= 0:
                continue
            cx, cy = rx + rw // 2, ry + rh // 2
            if not (0 <= cx < W and 0 <= cy < H):
                continue
            if grid[cy // ts][cx // ts] in OPEN_TYPES:
                continue
            if rw >= rh:
                top_exit = cy < (H // 2)
                sill_y = (ry + rh - 3) if top_exit else (ry + 1)
                for sx in range(rx, rx + rw):
                    set_if(sx, sill_y, dk, WALKABLE_TYPES)
                    set_if(sx, sill_y + 1, mid if (sx % 6 != 0) else dk, WALKABLE_TYPES)
                    sh_y = sill_y + (2 if top_exit else -1)
                    if 0 <= sx < W and 0 <= sh_y < H and grid[sh_y // ts][sx // ts] in WALKABLE_TYPES:
                        buf[sh_y, sx] = SHADE_IX[buf[sh_y, sx]]
                jamb_h = min(rh, 12)
                jy0 = (ry + rh - jamb_h) if top_exit else ry
                for jx0 in (rx - 4, rx + rw):
                    for dy in range(jamb_h):
                        for dx in range(4):
                            c = IX["void"] if (dx in (0, 3) and dy == jamb_h - 1) else (
                                hi if dy == 0 else (dk if (dy >= jamb_h - 2 or dx == 3) else mid)
                            )
                            set_if(jx0 + dx, jy0 + dy, c, jamb_t)
            else:
                left_exit = cx < (W // 2)
                sill_x = (rx + rw - 3) if left_exit else (rx + 1)
                for sy in range(ry, ry + rh):
                    set_if(sill_x, sy, dk, WALKABLE_TYPES)
                    set_if(sill_x + 1, sy, mid if (sy % 6 != 0) else dk, WALKABLE_TYPES)
                    sh_x = sill_x + (2 if left_exit else -1)
                    if 0 <= sh_x < W and 0 <= sy < H and grid[sy // ts][sh_x // ts] in WALKABLE_TYPES:
                        buf[sy, sh_x] = SHADE_IX[buf[sy, sh_x]]
                jamb_w = min(rw, 12)
                jx0 = (rx + rw - jamb_w) if left_exit else rx
                for jy0 in (ry - 4, ry + rh):
                    for dy in range(4):
                        for dx in range(jamb_w):
                            c = hi if dy == 0 else (dk if dy == 3 else mid)
                            set_if(jx0 + dx, jy0 + dy, c, jamb_t)

    # ------------------------------------------------------------------ FOCAL DECOR HINTS
    def paint_decor(self, buf: np.ndarray, ctx: dict[str, Any], decor_list: list[dict[str, Any]]) -> None:
        """Paint focal composition hints directly onto walkable ground/walls:
        rug, mural, circle, compass, cracks, stain, light_shaft, grate, inlay, window_strip, threshold.
        """
        H, W = ctx["H"], ctx["W"]
        walk = ctx["m_walk"]
        bg = ctx["bg"]
        s = self.spec

        for item in decor_list:
            if not isinstance(item, dict):
                continue
            kind = str(item.get("kind", "")).strip().lower()
            if kind == "rug":
                rect = item.get("rect")
                if not (isinstance(rect, list) and len(rect) >= 4):
                    continue
                x0, y0, rw, rh = [int(v) for v in rect[:4]]
                x1, y1 = min(W, x0 + rw), min(H, y0 + rh)
                x0, y0 = max(0, x0), max(0, y0)
                if x1 <= x0 or y1 <= y0:
                    continue
                c_main = IX.get(str(item.get("color", "")), IX[s.path_main])
                c_trim = IX.get(str(item.get("trim", "")), IX[s.path_trim])
                c_edge = IX.get(str(item.get("edge", "")), IX[s.path_edge])
                c_hi = IX.get(str(item.get("hi", "")), IX[s.path_hi])
                style = str(item.get("style", "ornate")).lower()
                for y in range(y0, y1):
                    for x in range(x0, x1):
                        if not walk[y, x]:
                            continue
                        if style == "hearth":
                            # Cozy braided concentric oval rug (no rectangular box border!)
                            cx_r, cy_r = (x0 + x1) * 0.5, (y0 + y1) * 0.5
                            e = math.hypot((x - cx_r) / max(1.0, rw * 0.48), (y - cy_r) / max(1.0, rh * 0.48))
                            if e <= 1.0:
                                if e > 0.92:
                                    buf[y, x] = c_edge
                                else:
                                    band = int(e * 6.0) % 3
                                    buf[y, x] = (c_hi, c_main, c_trim)[band]
                            continue
                        dx = min(x - x0, x1 - 1 - x)
                        dy = min(y - y0, y1 - 1 - y)
                        d = min(dx, dy)
                        if d == 0:
                            # Fringe on left/right ends
                            if dx == 0 and (y % 2 == 0):
                                buf[y, x] = c_trim
                            else:
                                buf[y, x] = c_edge
                        elif d == 2:
                            buf[y, x] = c_trim if ((x + y) % 3 != 0) else c_hi
                        else:
                            cx_r, cy_r = (x0 + x1) // 2, (y0 + y1) // 2
                            md = abs(x - cx_r) + abs(y - cy_r)
                            if md in (5, 6, 11):
                                buf[y, x] = c_trim
                            elif md < 5:
                                buf[y, x] = c_hi if (x + y) % 2 == 0 else c_main
                            else:
                                buf[y, x] = c_hi if ((x + y) % 6 == 0) else c_main

            elif kind in ("circle", "compass", "mural"):
                pos = item.get("pos")
                if not (isinstance(pos, list) and len(pos) >= 2):
                    continue
                cx, cy = int(pos[0]), int(pos[1])
                rad = int(item.get("radius", 24 if kind == "compass" else 22))
                c_pri = IX.get(str(item.get("color", "")), IX[s.floor_accent_b])
                c_sec = IX.get(str(item.get("secondary", "")), IX[s.floor_accent_a])
                c_dk = IX[s.floor_seam]
                style = str(item.get("style", kind)).lower()
                y0, y1 = max(0, cy - rad - 2), min(H, cy + rad + 3)
                x0, x1 = max(0, cx - rad - 2), min(W, cx + rad + 3)
                for y in range(y0, y1):
                    for x in range(x0, x1):
                        if not walk[y, x]:
                            continue
                        dx, dy = x - cx, y - cy
                        d = math.hypot(dx, dy)
                        if d > rad + 1.5:
                            continue
                        ang = math.atan2(dy, dx)
                        if kind == "compass" or style in ("compass", "astrolabe", "clock"):
                            if abs(d - rad) < 0.85 or abs(d - rad * 0.62) < 0.75:
                                buf[y, x] = c_pri if ((dx + dy) < 0 or abs(math.sin(ang * 4.0)) < 0.25) else c_sec
                            elif abs(d - (rad + 1.1)) < 0.65:
                                buf[y, x] = c_dk
                            elif d < rad - 1:
                                # 8-point compass rose rays
                                if (abs(dx) <= 1 or abs(dy) <= 1) and d > 3:
                                    buf[y, x] = c_pri if (abs(dx) == 0 or abs(dy) == 0) else c_dk
                                elif abs(abs(dx) - abs(dy)) <= 0.7 and d < rad * 0.60 and d > 4:
                                    buf[y, x] = c_sec
                                elif d <= 3.2:
                                    buf[y, x] = IX["cream"] if d < 1.6 else c_pri
                        elif style == "spotlight":
                            t = max(0.0, 1.0 - d / max(1.0, float(rad)))
                            if t > bg[y, x] * 1.15:
                                buf[y, x] = LIGHT_IX[buf[y, x]]
                                if t > 0.65 and (t - 0.5) > bg[y, x]:
                                    buf[y, x] = LIGHT_IX[buf[y, x]]
                        else:
                            # Ritual / mosaic / mural concentric medallion
                            if abs(d - rad) < 0.9 or abs(d - rad * 0.55) < 0.8:
                                buf[y, x] = c_pri
                            elif abs(d - (rad + 1.1)) < 0.6:
                                buf[y, x] = c_dk
                            elif d < rad * 0.55:
                                # Star / petal motif inside medallion
                                k = 6 if style in ("sun", "constellation", "gear") else 4
                                wave = math.cos(ang * k) * rad * 0.22 + rad * 0.28
                                if abs(d - wave) < 0.9:
                                    buf[y, x] = c_sec
                                elif d < 3.0:
                                    buf[y, x] = c_pri

            elif kind == "cracks":
                pos = item.get("pos")
                if not (isinstance(pos, list) and len(pos) >= 2):
                    continue
                cx, cy = int(pos[0]), int(pos[1])
                rad = int(item.get("radius", 18))
                glow = bool(item.get("glow", False))
                c_line = IX[s.floor_accent_a] if glow else IX[s.floor_seam]
                c_core = IX["gold"] if glow else IX[s.floor_bevel]
                # 5 jagged radiating crack branches
                for b_idx in range(5):
                    ang = (b_idx * 1.28) + ((cx * 7 + cy * 13) % 10) * 0.1
                    px_f, py_f = float(cx), float(cy)
                    for step in range(rad):
                        px_f += math.cos(ang)
                        py_f += math.sin(ang)
                        if step % 4 == 2:
                            ang += 0.35 if ((b_idx + step) & 1) else -0.35
                        ix, iy = int(round(px_f)), int(round(py_f))
                        if 0 <= ix < W and 0 <= iy < H and walk[iy, ix]:
                            buf[iy, ix] = c_core if (glow and step < rad // 2) else c_line
                            if not glow and 0 <= iy + 1 < H and walk[iy + 1, ix]:
                                buf[iy + 1, ix] = c_core

            elif kind == "stain":
                pos = item.get("pos")
                if not (isinstance(pos, list) and len(pos) >= 2):
                    continue
                cx, cy = int(pos[0]), int(pos[1])
                rad = int(item.get("radius", 16))
                style = str(item.get("style", "water")).lower()
                tint_map = {
                    "water": ("deep", "blue"),
                    "moss": ("pine", "jade"),
                    "ink": ("void", "night"),
                    "soot": ("night", "dusk"),
                    "acid": ("teal", "lime"),
                    "petal": ("wine", "rose"),
                    "sand": ("apricot", "gold"),
                }
                c_a, c_b = tint_map.get(style, (s.floor_seam, s.floor_accent_a))
                y0, y1 = max(0, cy - rad), min(H, cy + rad + 1)
                x0, x1 = max(0, cx - rad), min(W, cx + rad + 1)
                for y in range(y0, y1):
                    for x in range(x0, x1):
                        if not walk[y, x]:
                            continue
                        d = math.hypot((x - cx) / max(1.0, rad * 1.15), (y - cy) / max(1.0, rad * 0.85))
                        if d < 1.0:
                            t = (1.0 - d) * 0.85
                            if t > bg[y, x]:
                                buf[y, x] = IX[c_b if (d < 0.45 and t > 0.55) else c_a]

            elif kind == "light_shaft":
                pos = item.get("pos")
                if not (isinstance(pos, list) and len(pos) >= 2):
                    continue
                cx, cy = int(pos[0]), int(pos[1])
                sz = item.get("size", [28, 44])
                sw, sh = int(sz[0]), int(sz[1])
                tint = str(item.get("tint", "warm")).lower()
                shear = float(item.get("shear", 0.45))
                y0, y1 = max(0, cy - sh // 2), min(H, cy + sh // 2)
                for y in range(y0, y1):
                    dy = (y - cy) / max(1.0, sh * 0.5)
                    x_shift = int((y - y0) * shear)
                    x0 = max(0, cx - sw // 2 + x_shift)
                    x1 = min(W, cx + sw // 2 + x_shift)
                    for x in range(x0, x1):
                        if not walk[y, x]:
                            continue
                        dx = abs((x - (cx + x_shift)) / max(1.0, sw * 0.5))
                        fall = max(0.0, (1.0 - dx) * (1.0 - abs(dy) * 0.55))
                        if fall * 0.80 > bg[y, x]:
                            if tint == "cool":
                                buf[y, x] = COOL_IX[buf[y, x]]
                            elif tint == "rose" and fall > 0.55:
                                buf[y, x] = IX["rose"] if bg[y, x] < 0.45 else LIGHT_IX[buf[y, x]]
                            elif tint == "lime" and fall > 0.55:
                                buf[y, x] = IX["lime"] if bg[y, x] < 0.45 else LIGHT_IX[buf[y, x]]
                            else:
                                buf[y, x] = LIGHT_IX[buf[y, x]]
                                if fall > 0.72 and (fall - 0.55) > bg[y, x]:
                                    buf[y, x] = IX["gold"]

            elif kind == "grate":
                rect = item.get("rect")
                if not (isinstance(rect, list) and len(rect) >= 4):
                    continue
                x0, y0, rw, rh = [int(v) for v in rect[:4]]
                glow = bool(item.get("glow", False))
                c_bar = IX[s.wall_face]
                c_rim = IX[s.wall_lip]
                c_in = IX["coral"] if glow else IX["void"]
                c_core = IX["gold"] if glow else IX["night"]
                for y in range(max(0, y0), min(H, y0 + rh)):
                    for x in range(max(0, x0), min(W, x0 + rw)):
                        if not walk[y, x]:
                            continue
                        if x in (x0, x0 + rw - 1) or y in (y0, y0 + rh - 1):
                            buf[y, x] = c_rim if (y == y0 or x == x0) else c_bar
                        elif (x - x0) % 4 == 0 or (y - y0) % 4 == 0:
                            buf[y, x] = c_bar
                        else:
                            buf[y, x] = c_core if (glow and ((x + y) % 3 == 0)) else c_in

            elif kind == "inlay":
                rect = item.get("rect")
                if not (isinstance(rect, list) and len(rect) >= 4):
                    continue
                x0, y0, rw, rh = [int(v) for v in rect[:4]]
                c_hi = IX.get(str(item.get("color", "")), IX[s.floor_accent_b])
                c_dk = IX[s.floor_seam]
                for y in range(max(0, y0), min(H, y0 + rh)):
                    for x in range(max(0, x0), min(W, x0 + rw)):
                        if not walk[y, x]:
                            continue
                        if x in (x0, x0 + rw - 1) or y in (y0, y0 + rh - 1):
                            buf[y, x] = c_hi
                        elif x in (x0 + 1, x0 + rw - 2) or y in (y0 + 1, y0 + rh - 2):
                            buf[y, x] = c_dk

            elif kind == "window_strip":
                # Glowing recessed architectural window strip along a north wall (train / manor / archive)
                wy = int(item.get("y", 10))
                x0 = int(item.get("x0", 24))
                x1 = int(item.get("x1", W - 24))
                w_style = str(item.get("style", "sunset")).lower()
                for x in range(max(0, x0), min(W, x1)):
                    seg = (x - x0) % 32
                    if seg < 4 or seg >= 28:
                        continue  # pillar mullion
                    for dy in range(5):
                        yy = wy + dy
                        if not (0 <= yy < H):
                            continue
                        if dy == 0 or dy == 4 or seg in (4, 27):
                            buf[yy, x] = IX["gold"] if dy == 0 else IX["night"]
                        else:
                            if w_style == "slag":
                                buf[yy, x] = IX["apricot"] if dy == 1 else (IX["coral"] if dy == 2 else IX["wine"])
                            elif w_style == "stars":
                                buf[yy, x] = IX["ice"] if ((x * 7 + dy * 13) % 17 == 0) else (IX["deep"] if dy < 3 else IX["night"])
                            elif w_style == "rain":
                                buf[yy, x] = IX["ice"] if ((x + dy) % 5 == 0) else IX["blue"]
                            else:
                                buf[yy, x] = IX["gold"] if dy == 1 else (IX["apricot"] if dy == 2 else IX["coral"])

    # ------------------------------------------------------------------ HOOK FOR SUBCLASSES
    def paint_post(self, buf: np.ndarray, ctx: dict[str, Any]) -> None:
        """Override in subclasses for bespoke theme flourishes."""
        return
