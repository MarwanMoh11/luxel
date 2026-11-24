#!/usr/bin/env python3
"""Offline pixel-accurate preview renderer for E0-5 visual QA:
  - Panes Menu (320x180, exact rects from luxel/ui/panes_menu.gd)
  - Journal Quests / Moths / Bestiary / Toys (exact rects from luxel/ui/journal*.gd)
  - Wick House Hub Hall + 3 NPC Pictogram Bubbles (exact overworld.map + overworld.json + folk/*.png + bubble_icons.png)
Saves 3x-scaled crisp nearest-neighbour PNGs in .swarm/cache/e0_5_preview/ for visual review.
"""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / ".swarm" / "cache" / "e0_5_preview"
OUT.mkdir(parents=True, exist_ok=True)

HEX = {
    "void": "#0d0b1e", "night": "#211a3b", "dusk": "#3d2c5c", "plum": "#6a3d6f",
    "wine": "#a0466a", "coral": "#e2725b", "apricot": "#f5a96a", "gold": "#ffd98c",
    "cream": "#fff4dc", "pine": "#1d3d4c", "teal": "#2b6b68", "jade": "#4c9e78",
    "lime": "#a3cf7d", "deep": "#263873", "blue": "#3e6db0", "sky": "#78a9da",
    "ice": "#c7e5ef", "mauve": "#8a6e91", "stone": "#c2a7ae", "rose": "#ec9fa8",
}

def col(k: str) -> tuple[int, int, int, int]:
    h = HEX[k].lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)

CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-:x/.+="
FONT_IMG = Image.open(ROOT / "luxel/art/ui/font.png").convert("RGBA")
PANES_IMG = Image.open(ROOT / "luxel/art/ui/panes.png").convert("RGBA")
PANES_META = json.loads((ROOT / "luxel/art/ui/panes.json").read_text())
BUB_IMG = Image.open(ROOT / "luxel/art/ui/bubble_icons.png").convert("RGBA")
BUB_META = json.loads((ROOT / "luxel/art/ui/bubble_icons.json").read_text())
FOLK_PACK = json.loads((ROOT / "luxel/data/packs/folk.json").read_text())
FOLK_CAT = json.loads((ROOT / "luxel/world/folk/folk_catalog.json").read_text())
STRS = FOLK_PACK["strings"]


def draw_rect(img: Image.Image, x: int, y: int, w: int, h: int, color_key: str) -> None:
    if w <= 0 or h <= 0:
        return
    d = ImageDraw.Draw(img)
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=col(color_key))


def draw_panel(img: Image.Image, x: int, y: int, w: int, h: int, fill="dusk", bdr="mauve", outer="night") -> None:
    draw_rect(img, x, y, w, h, outer)
    draw_rect(img, x + 1, y + 1, w - 2, h - 2, bdr)
    draw_rect(img, x + 2, y + 2, w - 4, h - 4, fill)


def text_w(txt: str) -> int:
    return max(0, len(txt) * 4 - 1)


def draw_text(img: Image.Image, txt: str, x: int, y: int, color_key: str, align="left") -> None:
    if align == "center":
        x = int(round(x - text_w(txt) * 0.5))
    elif align == "right":
        x = x - text_w(txt)
    px = img.load()
    fpx = FONT_IMG.load()
    c_fill = col(color_key)
    c_out = col("night")
    w_im, h_im = img.size
    for i, ch in enumerate(txt):
        if ch == " ":
            continue
        idx = CHARS.find(ch)
        if idx < 0:
            continue
        ox = x + i * 4
        # outline
        for dy in range(5):
            for dx in range(3):
                if fpx[idx * 3 + dx, dy][3] > 128:
                    for ex, ey in [(-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)]:
                        tx, ty = ox + dx + ex, y + dy + ey
                        if 0 <= tx < w_im and 0 <= ty < h_im:
                            px[tx, ty] = c_out
        for dy in range(5):
            for dx in range(3):
                if fpx[idx * 3 + dx, dy][3] > 128:
                    tx, ty = ox + dx, y + dy
                    if 0 <= tx < w_im and 0 <= ty < h_im:
                        px[tx, ty] = c_fill


def draw_pane(img: Image.Image, pid: str, x: int, y: int, dim: bool = False) -> None:
    rx, ry, rw, rh = PANES_META["icons"][pid]["rect"]
    tile = PANES_IMG.crop((rx, ry, rx + rw, ry + rh))
    if dim:
        tpx = tile.load()
        dc = col("dusk")
        for yy in range(rh):
            for xx in range(rw):
                if tpx[xx, yy][3] > 0:
                    tpx[xx, yy] = dc if (xx + yy) % 2 == 0 else col("night")
    img.paste(tile, (x, y), tile)


def draw_bicon(img: Image.Image, iid: str, x: int, y: int) -> None:
    rx, ry, rw, rh = BUB_META["icons"].get(iid, BUB_META["icons"]["question"])
    tile = BUB_IMG.crop((rx, ry, rx + rw, ry + rh))
    img.paste(tile, (x, y), tile)


def save_3x(img: Image.Image, name: str) -> None:
    img.resize((img.width * 3, img.height * 3), Image.NEAREST).save(OUT / name)


def render_panes_menu() -> None:
    im = Image.new("RGBA", (320, 180), col("void"))
    draw_panel(im, 14, 8, 292, 164, "dusk", "gold", "night")
    for rx, ry in [(17, 11), (301, 11), (17, 167), (301, 167)]:
        draw_rect(im, rx, ry, 2, 2, "apricot")
        draw_rect(im, rx, ry, 1, 1, "gold")
    draw_rect(im, 22, 22, 276, 1, "night")
    for dx in range(26, 294, 6):
        draw_rect(im, dx, 22, 3, 1, "apricot" if dx % 12 == 0 else "dusk")
    draw_rect(im, 159, 21, 3, 3, "gold")
    draw_rect(im, 160, 22, 1, 1, "cream")
    draw_text(im, STRS["PANES_TITLE"], 24, 14, "gold")
    draw_text(im, "LEAD 6/8", 146, 14, "cream")
    for li in range(8):
        lx = 192 + li * 5
        draw_rect(im, lx, 14, 4, 5, "void")
        draw_rect(im, lx + 1, 15, 2, 3, "gold" if li < 6 else "night")
    draw_text(im, "12/32", 298, 14, "apricot", "right")

    eq = ["bell_clapper", "rip_tide", "orbit_shard"]
    for si in range(5):
        sx, sy = 76 + si * 35, 29
        locked = si >= 4
        filled = si < len(eq)
        draw_rect(im, sx + 11, sy - 4, 6, 1, "gold" if filled else "dusk")
        draw_rect(im, sx + 10, sy - 3, 1, 1, "night" if locked else "apricot")
        draw_rect(im, sx + 17, sy - 3, 1, 1, "night" if locked else "apricot")
        draw_rect(im, sx + 6, sy - 2, 16, 2, "dusk" if locked else "apricot")
        draw_panel(im, sx, sy, 28, 20, "void" if locked else ("plum" if filled else "night"), "night" if locked else ("gold" if filled else "mauve"), "void")
        if locked:
            draw_rect(im, sx + 12, sy + 8, 4, 4, "dusk")
            draw_rect(im, sx + 13, sy + 6, 2, 2, "mauve")
        elif filled:
            draw_pane(im, eq[si], sx + 4, sy + 4, False)
            cost = FOLK_PACK["panes"][eq[si]]["lead"]
            for ci in range(cost):
                draw_rect(im, sx + 20, sy + 4 + ci * 4, 3, 3, "gold")

    for fi in range(9):
        fx = 22 if fi == 0 else 50 + (fi - 1) * 18
        fw = 26 if fi == 0 else 16
        draw_panel(im, fx, 54, fw, 11, "plum" if fi == 0 else "night", "gold" if fi == 0 else "dusk", "void")
        draw_text(im, "ALL" if fi == 0 else str(fi), fx + fw // 2, 57, "gold" if fi == 0 else "cream", "center")

    owned = {"bell_clapper", "vesper_chime", "toll_echo", "belfry_weight", "rip_tide", "sea_glass", "ember_seed", "hourglass_sand", "orbit_shard", "cinder_blast", "silver_twin", "toll_wick"}
    pids = list(FOLK_PACK["panes"].keys())[:16]
    for i, pid in enumerate(pids):
        c, r = i % 8, i // 8
        tx, ty = 30 + c * 33, 74 + r * 26
        is_sel = i == 0
        is_own = pid in owned
        is_eq = pid in eq
        bdr = "gold" if is_sel else ("lime" if is_eq else ("mauve" if is_own else "night"))
        fill = "plum" if is_sel else ("dusk" if is_eq else ("night" if is_own else "void"))
        draw_panel(im, tx, ty, 28, 22, fill, bdr, "void")
        draw_pane(im, pid, tx + 3, ty + 5, not is_own)
        for ci in range(FOLK_PACK["panes"][pid]["lead"]):
            draw_rect(im, tx + 22, ty + 4 + ci * 4, 2, 2, "gold" if is_own else "dusk")
        if is_eq:
            draw_rect(im, tx + 22, ty + 16, 3, 3, "lime")
            draw_rect(im, tx + 23, ty + 17, 1, 1, "cream")

    draw_rect(im, 293, 73, 5, 50, "night")
    draw_rect(im, 294, 74, 3, 48, "void")
    draw_rect(im, 294, 74, 3, 24, "gold")
    draw_rect(im, 294, 74, 3, 1, "cream")
    draw_panel(im, 22, 126, 276, 28, "night", "mauve", "void")
    draw_pane(im, "bell_clapper", 28, 134, False)
    draw_text(im, STRS["PANE_BELL_CLAPPER_NAME"], 45, 131, "gold")
    draw_text(im, "LEAD 2  ISL 1", 292, 131, "apricot", "right")
    draw_text(im, STRS["PANE_BELL_CLAPPER_DESC"], 45, 142, "cream")
    draw_text(im, STRS["PANES_HINT_EDIT"], 22, 160, "stone")
    draw_panel(im, 242, 157, 56, 11, "night", "mauve", "void")
    draw_text(im, "CLOSE", 270, 160, "cream", "center")
    save_3x(im, "01_panes_menu.png")


def render_journal_pages() -> None:
    tabs = [("QUESTS", "book"), ("MOTHS", "moth"), ("FOES", "skull"), ("TOYS", "gear")]
    for page_idx in range(4):
        im = Image.new("RGBA", (320, 180), col("void"))
        draw_panel(im, 14, 8, 292, 164, "dusk", "gold", "night")
        draw_text(im, "JOURNAL", 24, 14, "gold")
        draw_text(im, "42%", 296, 14, "cream", "right")
        for ti, (lbl, ic) in enumerate(tabs):
            tx = 22 + ti * 70
            act = ti == page_idx
            draw_panel(im, tx, 24, 66, 15, "plum" if act else "night", "gold" if act else "dusk", "void")
            draw_bicon(im, ic, tx + 4, 27)
            draw_text(im, lbl, tx + 16, 29, "gold" if act else "stone")
        draw_panel(im, 22, 42, 276, 110, "void", "dusk", "night")

        if page_idx == 0:
            for vi, q in enumerate(FOLK_PACK["quests"][:5]):
                ry = 44 + vi * 20
                done = vi == 0
                draw_panel(im, 24, ry, 272, 18, "plum" if vi == 1 else "night", "gold" if vi == 1 else ("lime" if done else "dusk"), "void")
                draw_bicon(im, q["icon"], 28, ry + 4)
                draw_bicon(im, f"isl_{q['island']}", 40, ry + 4)
                icons = ["check", "heart", "lantern"] if done else q["steps"][0]["icons"]
                for si, ic in enumerate(icons[:6]):
                    draw_bicon(im, ic, 58 + si * 12, ry + 4)
                draw_bicon(im, "pane", 244, ry + 4)
                draw_text(im, "DONE" if done else ("OPEN" if vi == 1 else "NEW"), 290, ry + 6, "lime" if done else ("gold" if vi == 1 else "stone"), "right")
        elif page_idx == 1:
            draw_bicon(im, "moth", 26, 45)
            draw_text(im, "LOST MOTHS: 43/80", 38, 47, "gold")
            counts = [10, 7, 5, 5, 4, 4, 4, 4]
            bdr_keys = ["gold", "sky", "lime", "ice", "gold", "coral", "ice", "rose"]
            for isl in range(1, 9):
                c, r = (isl - 1) % 2, (isl - 1) // 2
                bx, by = 24 + c * 136, 58 + r * 18
                cnt = counts[isl - 1]
                draw_panel(im, bx, by, 132, 16, "night", "lime" if cnt == 10 else bdr_keys[isl - 1], "void")
                draw_bicon(im, f"isl_{isl}", bx + 3, by + 3)
                for p in range(10):
                    px = bx + 16 + p * 8
                    draw_rect(im, px, by + 5, 6, 6, "void")
                    draw_rect(im, px + 1, by + 6, 4, 4, bdr_keys[isl - 1] if p < cnt else "dusk")
                    if p < cnt:
                        draw_rect(im, px + 2, by + 7, 2, 2, "cream")
                draw_text(im, f"{cnt}/10", bx + 128, by + 5, "lime" if cnt == 10 else "stone", "right")
            draw_panel(im, 24, 132, 272, 16, "night", "gold", "void")
            draw_text(im, "TIERS:", 28, 137, "apricot")
            for i, req in enumerate([5, 10, 20, 35, 50, 65, 80]):
                tx = 72 + i * 31
                hit = 43 >= req
                draw_panel(im, tx, 135, 27, 10, "plum" if req <= 10 else ("dusk" if hit else "void"), "lime" if req <= 10 else ("gold" if hit else "night"), "void")
                draw_text(im, str(req), tx + 13, 137, "cream" if hit else "mauve", "center")
        elif page_idx == 2:
            kinds = ["warden", "snatcher", "owl", "barnacle_sentry", "gull_thief", "crab_warden", "sporecap", "bramble_knight", "gloam"]
            for vi, k in enumerate(kinds):
                c, r = vi % 3, vi // 3
                cx, cy = 24 + c * 90, 44 + r * 34
                seen = vi < 6
                draw_panel(im, cx, cy, 87, 31, "plum" if vi == 0 else "night", "gold" if vi == 0 else ("mauve" if seen else "dusk"), "void")
                draw_rect(im, cx + 4, cy + 4, 22, 23, "void")
                ej = ROOT / f"luxel/art/enemies/{k}.json"
                if ej.exists():
                    ed = json.loads(ej.read_text())
                    es = Image.open(ROOT / f"luxel/art/enemies/{ed['sheet']}").convert("RGBA")
                    an = ed["animations"].get("idle", ed["animations"].get("routine"))
                    dr = an["dirs"].get("front", list(an["dirs"].values())[0])
                    rx, ry, rw, rh = dr["rects"][0]
                    spr = es.crop((rx, ry, rx + rw, ry + rh))
                    sc = min(20.0 / rw, 21.0 / rh)
                    spr = spr.resize((max(1, int(rw * sc)), max(1, int(rh * sc))), Image.NEAREST)
                    im.paste(spr, (cx + 15 - spr.width // 2, cy + 15 - spr.height // 2), spr)
                draw_bicon(im, FOLK_CAT["bestiary_weakness"].get(k, "weak_bolt"), cx + 74, cy + 4)
                lbl = k.upper().replace("_", " ")[:11] if seen else "UNSEEN"
                draw_text(im, lbl, cx + 29, cy + 5, "cream" if seen else "mauve")
                draw_text(im, f"S:{3 if seen else 0} D:{2 if seen else 0}", cx + 29, cy + 17, "gold" if seen else "stone")
        else:
            for vi, t in enumerate(FOLK_CAT["toys_catalog"][:12]):
                c, r = vi % 4, vi // 4
                cx, cy = 24 + c * 68, 44 + r * 34
                draw_panel(im, cx, cy, 65, 31, "plum" if vi == 0 else "night", "gold" if vi == 0 else "sky", "void")
                draw_bicon(im, t["icon"], cx + 28, cy + 5)
                draw_text(im, STRS[t["name_key"]], cx + 32, cy + 19, "cream", "center")

        draw_text(im, STRS["JOURNAL_HINT"], 22, 160, "stone")
        draw_panel(im, 242, 158, 56, 10, "night", "mauve", "void")
        draw_text(im, "CLOSE", 270, 160, "cream", "center")
        save_3x(im, f"0{page_idx+2}_journal_{tabs[page_idx][0].lower()}.png")


def draw_bubble(im: Image.Image, cx: int, cy: int, icons: list[str], accent: str = "gold", pages: int = 1) -> None:
    n = len(icons)
    strip_w = n * 9 + max(0, n - 1) * 2
    extra_r = 7 if pages > 1 else 0
    bw = strip_w + 10 + extra_r
    bh = 9 + 8 + (3 if pages > 1 else 0)
    bx, by = cx - bw // 2, cy - bh - 6
    draw_rect(im, bx + 1, by + 1, bw, bh, "void")
    draw_panel(im, bx, by, bw, bh, "night", accent, "void")
    draw_rect(im, bx + 2, by + 2, bw - 4, 1, "dusk")
    draw_rect(im, cx - 2, by + bh, 4, 2, accent)
    draw_rect(im, cx - 1, by + bh, 2, 2, "night")
    for i, ic in enumerate(icons):
        draw_bicon(im, ic, bx + 5 + i * 11, by + 4)
    if pages > 1:
        draw_rect(im, bx + bw - 6, by + 7, 3, 1, "cream")
        draw_rect(im, bx + bw - 5, by + 8, 1, 1, "cream")
        for p in range(pages):
            draw_rect(im, cx - (pages * 3) // 2 + p * 3, by + bh - 4, 2, 1, "gold" if p == 0 else "dusk")


def render_hub_and_bubbles() -> None:
    # Render Wick House Hall crop (320x180 centered at 256, 148)
    raw = (ROOT / "luxel/islands/0/overworld.map").read_text().splitlines()
    rows = []
    in_m = False
    for ln in raw:
        s = ln.strip()
        if s == "MAP": in_m = True; continue
        if s == "END": break
        if in_m and s: rows.append(ln)
    im = Image.new("RGBA", (320, 180), col("void"))
    ox, oy = 160 - 256, 90 - 152
    tcol = {"~": "deep", "#": "dusk", ".": "night", ",": "plum", "+": "apricot"}
    for ty, r in enumerate(rows):
        for tx, ch in enumerate(r):
            sx, sy = ox + tx * 16, oy + ty * 16
            if -16 <= sx < 320 and -16 <= sy < 180:
                draw_rect(im, sx, sy, 16, 16, tcol.get(ch, "void"))
                if ch == "#":
                    draw_rect(im, sx, sy, 16, 3, "mauve")
                elif ch == ",":
                    draw_rect(im, sx + 1, sy + 1, 14, 14, "dusk")
                    draw_rect(im, sx + 2, sy + 2, 12, 1, "mauve")
    # Hub stations
    # Moth lantern (256, 76)
    mx, my = ox + 256, oy + 76
    draw_rect(im, mx - 6, my - 22, 12, 19, "night")
    draw_rect(im, mx - 5, my - 21, 10, 17, "gold")
    draw_rect(im, mx - 3, my - 19, 6, 13, "cream")
    draw_bicon(im, "moth", mx - 4, my - 17)
    # Gallery door (152, 92) & Rematch mirror (360, 92)
    for dx, ic, hi, mid in [(152, "move_bolt", "gold", "coral"), (360, "crown", "ice", "blue")]:
        x, y = ox + dx, oy + 92
        draw_rect(im, x - 10, y - 24, 20, 26, "void")
        draw_rect(im, x - 9, y - 23, 18, 24, mid)
        draw_rect(im, x - 7, y - 21, 14, 22, "night")
        draw_rect(im, x - 8, y - 23, 16, 2, hi)
        draw_bicon(im, ic, x - 4, y - 16)
    # Pane workshop (126, 152) & Training dummy (374, 174)
    wx, wy = ox + 126, oy + 152
    draw_rect(im, wx - 11, wy - 10, 22, 12, "night")
    draw_rect(im, wx - 10, wy - 9, 20, 10, "dusk")
    draw_rect(im, wx - 10, wy - 9, 20, 3, "apricot")
    draw_bicon(im, "pane", wx - 4, wy - 6)
    tx, ty = ox + 374, oy + 174
    draw_rect(im, tx - 5, ty - 13, 10, 8, "stone")
    draw_rect(im, tx - 9, ty - 11, 18, 2, "apricot")
    draw_rect(im, tx - 2, ty - 11, 4, 4, "coral")
    draw_rect(im, tx - 3, ty - 19, 6, 4, "dusk")
    # Damage pips above dummy
    draw_rect(im, tx - 13, ty - 34, 26, 4, "void")
    for p in range(8):
        draw_rect(im, tx - 12 + p * 3, ty - 33, 2, 2, "gold")

    # 3 Lamp-folk NPCs with open pictogram bubbles
    npcs = [
        ("candle_grandma", 198, 156, ["home", "lantern", "heart"], "gold", 2),
        ("moth_kid", 258, 164, ["moth", "light_on", "arrow_n", "happy"], "apricot", 1),
        ("ferry_beetle", 318, 158, ["toy_skiff", "wave", "pane"], "sky", 2),
    ]
    for fid, nx, ny, bicons, acc, pgs in npcs:
        spr = Image.open(ROOT / f"luxel/art/folk/{fid}.png").convert("RGBA").crop((0, 0, 16, 20))
        sx, sy = ox + nx, oy + ny
        im.paste(spr, (sx - 8, sy - 18), spr)
        draw_bubble(im, sx, sy - 20, bicons, acc, pgs)

    save_3x(im, "06_hub_and_bubbles.png")


if __name__ == "__main__":
    render_panes_menu()
    render_journal_pages()
    render_hub_and_bubbles()
    print(f"Saved 6 preview renders to {OUT}")
