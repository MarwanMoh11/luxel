#!/usr/bin/env python3
"""Builds the Luxel website into publish/site/.

  uv run --no-project --with markdown --with pillow python website/build.py

Inputs: website/content/*.md (+ timeline.json, facts.json), publish/site-media/ (+ media.json),
website/templates, website/src (css, js, concatenated), website/assets, the shop tables in
scripts/game/shop/shop_data.gd, the run music plan audio/music/run.json, and publish/web (the web export, copied to
play/ for local testing). Every URL in the output is relative: the site lives at
https://marwanmoh11.github.io/luxel/.
"""
from __future__ import annotations

import ast
import hashlib
import html
import json
import re
import shutil
import shutil
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "website"
CONTENT = WEB / "content"
PLACEHOLDER = WEB / "placeholder"
MEDIA = ROOT / "publish/site-media"
OUT = ROOT / "publish/site"
PLAY = ROOT / "publish/web"
SITE_URL = "https://marwanmoh11.github.io/luxel/"
REPO = "https://github.com/MarwanMoh11/luxel"
RELEASES = REPO + "/releases/latest"
TRAILER_1080 = RELEASES + "/download/luxel_trailer_1080p.mp4"
SKIP_MEDIA = {"DONE", ".DS_Store", "media.json"}
SKIP_MEDIA_EXT = {".log", ".mbtree", ".mkv", ".tmp", ".py"}

# The bar shows the game's own tab names; each section's own `tab` shows as its value in the menu rows.
NAV = [
    ("GENERAL", ["about", "trailer", "play", "how-to-play"]),
    ("GAMEPLAY", ["shop", "motion", "finale"]),
    ("GRAPHICS", ["world", "art"]),
    ("AUDIO", ["sound"]),
    ("ADVANCED", ["journey", "inspirations", "process", "numbers", "credits", "presskit", "downloads",
                  "display-off"]),
]
# Sections whose `## parts` stay open as plain prose (the rest fold into menu rows).
OPEN_PARTS = {"about", "finale", "credits", "play", "trailer", "downloads", "display-off"}

esc = html.escape


def attr(s) -> str:
    return html.escape(str(s), quote=True)


# ---------------------------------------------------------------- content

def read_md(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    meta: dict = {}
    if text.startswith("---"):
        end = text.find("\n---", 3)
        head, text = text[3:end], text[end + 4:]
        for line in head.strip().splitlines():
            if ":" not in line or line.lstrip().startswith("#"):
                continue
            k, v = line.split(":", 1)
            v = v.strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1]
            if v.lower() in ("true", "yes"):
                v = True
            elif v.lower() in ("false", "no"):
                v = False
            meta[k.strip()] = v
    return meta, text.strip("\n")


def split_parts(body: str) -> tuple[str, list]:
    """The intro (before the first '## ') and the [(NAME, text)] parts."""
    intro, parts, cur = [], [], None
    for line in body.splitlines():
        m = re.match(r"^##\s+(.+?)\s*$", line)
        if m:
            cur = [m.group(1).strip(), []]
            parts.append(cur)
            continue
        (cur[1] if cur else intro).append(line)
    return "\n".join(intro).strip(), [(n, "\n".join(t).strip()) for n, t in parts]


MD = markdown.Markdown(extensions=["extra", "sane_lists", "smarty"], output_format="html")


def md(text: str, shift: int = 1) -> str:
    MD.reset()
    out = MD.convert(text)
    if shift:
        out = re.sub(r"<(/?)h([1-5])", lambda m: "<%sh%d" % (m.group(1), min(6, int(m.group(2)) + shift)), out)
    out = out.replace("<img ", '<img loading="lazy" decoding="async" ')
    out = re.sub(r'<a href="(https?://[^"]+)"', r'<a href="\1" rel="noopener" target="_blank"', out)
    out = out.replace("<table>", '<div class="table"><table>').replace("</table>", "</table></div>")
    return out


def load_content() -> tuple[list, dict, dict]:
    src = CONTENT if CONTENT.exists() and any(CONTENT.glob("*.md")) else PLACEHOLDER
    sections = []
    for p in sorted(src.glob("*.md")):
        if p.name.lower() == "readme.md":
            continue
        meta, body = read_md(p)
        meta.setdefault("id", re.sub(r"^\d+[-_]", "", p.stem))
        meta.setdefault("title", meta["id"].replace("-", " ").upper())
        meta.setdefault("tab", "GENERAL")
        meta["tab"] = str(meta["tab"]).upper()
        sections.append({"meta": meta, "body": body, "file": p.name})
    extra = {}
    for name in ("timeline.json", "facts.json"):
        for base in (CONTENT, PLACEHOLDER):
            if (base / name).exists():
                extra[name] = json.loads((base / name).read_text(encoding="utf-8"))
                break
    status = {"content": src.name, "content_done": (CONTENT / "DONE").exists(), "media_done": (MEDIA / "DONE").exists()}
    return sections, extra, status


# ---------------------------------------------------------------- media

class Media:
    """publish/site-media/media.json: a list of {id, file, kind, section, caption, story, poster, w, h, ...}."""

    def __init__(self) -> None:
        self.items: list[dict] = []
        f = MEDIA / "media.json"
        if f.exists():
            try:
                raw = json.loads(f.read_text(encoding="utf-8"))
                self.items = raw if isinstance(raw, list) else [dict(v, id=k) for k, v in raw.items() if isinstance(v, dict)]
            except json.JSONDecodeError as e:
                print("media.json unreadable:", e, file=sys.stderr)
        self.by_id = {str(it.get("id")): it for it in self.items}
        self.release_only = {it["file"] for it in self.items if it.get("release_only") and it.get("file")}
        self.used: set = set()

    def get(self, i: str) -> dict | None:
        it = self.by_id.get(i)
        if it and it.get("file") and (MEDIA / it["file"]).exists() and not it.get("release_only"):
            self.used.add(i)
            return it
        return None

    def many(self, *ids: str) -> list[dict]:
        return [it for it in (self.get(i) for i in ids) if it]

    def where(self, **kw) -> list[dict]:
        out = []
        for it in self.items:
            if all((it.get(k) in v if isinstance(v, (list, tuple, set)) else it.get(k) == v) for k, v in kw.items()):
                if self.get(str(it.get("id"))):
                    out.append(it)
        return out

    @staticmethod
    def url(path: str | None) -> str:
        return "media/" + path.lstrip("./") if path else ""


def base_px(it: dict) -> int:
    """The width of the art's own pixel grid (a 4x upscale of 320x180 snaps to multiples of 320)."""
    w = it.get("w") or 0
    s = it.get("pixel_scale") or it.get("native_scale") or 1
    if it.get("kind") == "video" and w >= 640 and not it.get("pixel_scale") and not it.get("native_scale"):
        return 0
    return int(w // s) if w and s else 0


def first_sentence(s: str) -> str:
    m = re.match(r"(.+?[.!?])(\s|$)", s or "")
    return m.group(1) if m else (s or "")


# ---------------------------------------------------------------- media blocks

def img(it: dict, cls: str = "pix zoomable", eager: bool = False) -> str:
    b = base_px(it)
    return '<img class="%s" src="%s" alt="%s" width="%s" height="%s"%s%s>' % (
        cls, attr(Media.url(it["file"])), attr(it.get("caption") or ""), it.get("w") or "", it.get("h") or "",
        "" if eager else ' loading="lazy" decoding="async"', ' data-base="%d"' % b if b else "")


def vid(it: dict, loop: bool = True) -> str:
    b = base_px(it)
    poster = ' poster="%s"' % attr(Media.url(it["poster"])) if it.get("poster") else ""
    return ('<video class="pix" preload="none" playsinline muted loop data-autoplay-inview%s width="%s" height="%s" '
            'aria-label="%s"%s><source src="%s" type="video/mp4"></video>') % (
        poster, it.get("w") or "", it.get("h") or "", attr(it.get("caption") or ""), ' data-base="%d"' % b if b else "",
        attr(Media.url(it["file"])))


def figure(it: dict, cls: str = "card", caption: str | None = None) -> str:
    body = vid(it) if it.get("kind") == "video" else img(it)
    c = it.get("caption") if caption is None else caption
    return '<figure class="%s">%s%s</figure>' % (cls, body, '<figcaption>%s</figcaption>' % esc(c) if c else "")


def grid(items: list[dict], cls: str = "grid") -> str:
    return '<div class="%s">%s</div>' % (cls, "".join(figure(it) for it in items)) if items else ""


def strip(items: list[dict]) -> str:
    """A storyboard strip: small frames in a row that scrolls sideways."""
    if not items:
        return ""
    return '<div class="strip">%s</div>' % "".join(
        '<figure class="frame-s">%s<figcaption class="px">%s</figcaption></figure>' % (
            img(it), esc(re.sub(r"[.:].*$", "", it.get("caption") or "").upper()[:28])) for it in items)


def track(it: dict, title: str | None = None, note: str | None = None, pick: bool = False) -> str:
    return ('<div class="track%s" data-track><button class="btn small pbtn" type="button" aria-label="Play %s">▶</button>'
            '<div><div class="tt px">%s</div><div class="td">%s</div></div><div class="bars" aria-hidden="true">%s</div>'
            '<div class="prog" aria-hidden="true"><b></b></div><audio preload="none" src="%s"></audio></div>') % (
        " pick" if pick else "", attr(title or it.get("caption") or ""), esc((title or it.get("caption") or "").upper()),
        esc(note if note is not None else first_sentence(it.get("story") or "")), "<i></i>" * 6, attr(Media.url(it["file"])))


def lux_heading(text: str, tag: str = "h2", hid: str = "") -> str:
    return '<%s class="lux"%s data-lux>%s</%s>' % (tag, ' id="%s"' % hid if hid else "", esc(text.upper()), tag)


def btn(label: str, href: str, cls: str = "", extra: str = "") -> str:
    return '<a class="btn %s" href="%s"%s>%s</a>' % (cls, attr(href), extra, esc(label))


# ---------------------------------------------------------------- shop data (the mock menu)

def gd_literal(src: str, name: str):
    m = re.search(r"const " + name + r"\s*(?::\s*[\w\[\]]+)?\s*:?=\s*", src)
    i = m.end()
    opener = src[i]
    closer = {"{": "}", "[": "]"}[opener]
    depth, j, in_str = 0, i, False
    while j < len(src):
        c = src[j]
        if in_str:
            if c == "\\":
                j += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "#":
            nl = src.find("\n", j)
            src = src[:j] + src[nl:]
            continue
        elif c == opener:
            depth += 1
        elif c == closer:
            depth -= 1
            if depth == 0:
                break
        j += 1
    text = src[i:j + 1]
    text = re.sub(r"\btrue\b", "True", re.sub(r"\bfalse\b", "False", text))
    return ast.literal_eval(text)


def shop_data() -> dict:
    src = (ROOT / "scripts/game/shop/shop_data.gd").read_text(encoding="utf-8")
    tabs = gd_literal(src, "TABS")
    rows = gd_literal(src, "ROWS")
    finale = gd_literal(src, "FINALE_ORDER")
    names = {"damage": "DAMAGE", "fire": "FIRE RATE", "speed": "SPEED", "range": "RANGE"}

    def label(power: dict) -> str:
        parts = []
        for k, v in power.items():
            if k == "hearts":
                parts.append("+%d HEART%s" % (v, "" if v == 1 else "S"))
            elif k == "shots":
                parts.append("+%d SHOT%s" % (v, "" if v == 1 else "S"))
            elif k == "pierce":
                parts.append("+%d PIERCE" % v)
            else:
                parts.append("+%d%% %s" % (round(v * 100), names[k]))
        return " ".join(parts)

    for r in rows.values():
        for s in r["steps"]:
            s["label"] = label(s["power"])
            del s["power"]
    rows["pixels"]["steps"] = [{"value": "99%", "label": "+3% DAMAGE +2% FIRE RATE", "quip": "-1% PIXELS."}]
    return {"tabs": tabs, "rows": rows, "finale": finale}


#@WIDGETS@
# ---------------------------------------------------------------- build


# ---------------------------------------------------------------- widgets per section
# Each returns [(anchor, html)]: anchor None = right after the intro, else just before the part of that name.

CAST_LINES = {
    "cast_hero": ("WICK", "THE HERO", "A lamplighter moth with the last lantern. You only move; the lantern aims and fires by itself."),
    "cast_snuffer": ("SNUFFER", "FROM 0:04", "Soot under a candle-snuffer hood. Walks straight at you in packs. Mow it down."),
    "cast_owl": ("HUSH OWL", "FROM 0:40", "Circles, hoots, then dives through where you stood. Step aside, then shoot."),
    "cast_magpie": ("MAGPIE", "FROM 1:10", "Steals a star and runs. It never attacks. Catch it for a free level-up."),
    "cast_toad": ("PARASOL TOAD", "FROM 1:30", "Its lace parasol blocks every shot from the front. Circle round it."),
    "cast_sporecap": ("SPORECAP", "FROM 2:15", "A night toadstool that roots and puffs rings of spores. Find the gap."),
    "cast_gloam": ("GLOAM", "FROM 3:00", "A hare cut out of the starry void. Outside the light only its eyes show."),
}


def w_trailer(m: Media) -> list:
    it = m.get("trailer")
    if not it:
        return [(None, '<p class="px stone">TRAILER: COMING SOON.</p>')]
    poster = m.get("trailer_poster")
    p = Media.url(poster["file"]) if poster else Media.url(it.get("poster"))
    return [(None, (
        '<div class="player frame" data-player><video class="pix" preload="none" playsinline poster="%s" width="1280" height="720" '
        'aria-label="The Luxel gameplay trailer, 80 seconds"><source src="%s" type="video/mp4"></video>'
        '<button class="big-play" type="button" aria-label="Play the trailer"><span class="btn primary">▶ PLAY TRAILER</span></button>'
        '<div class="controls"><button type="button" data-act="play">PLAY</button>'
        '<div class="seek" role="slider" tabindex="0" aria-label="Seek" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0"><div class="fill"></div><div class="knob"></div></div>'
        '<span class="time px">0:00 / 1:20</span><button type="button" data-act="mute">SOUND: ON</button>'
        '<button type="button" data-act="full">FULL</button></div></div>'
        '<p class="play-note"><a class="btn small ghost" href="%s" rel="noopener">1080P DOWNLOAD (44 MB)</a>'
        '<span class="stone">720p here, 9 MB. Sound on: the music is half of it.</span></p>') % (attr(p), attr(Media.url(it["file"])), TRAILER_1080))]


def w_play(m: Media) -> list:
    poster = m.get("shot_title")
    im = '<img class="poster pix" src="%s" alt="" loading="lazy">' % attr(Media.url(poster["file"])) if poster else ""
    return [(None, (
        '<div class="play-box frame" data-play>%s<div class="cover">'
        '<button class="btn primary" type="button" data-load-game>▶ CLICK TO PLAY HERE</button>'
        '<span class="px stone outlined">NEEDS A KEYBOARD. SOUND ON.</span></div></div>'
        '<div class="play-note"><span class="keys"><span class="key">ARROWS</span><span class="key">WASD</span></span><span>move</span>'
        '<span class="keys"><span class="key">SPACE</span></span><span>pick in menus</span>'
        '<span class="keys"><span class="key">ESC</span></span><span>pause</span>'
        '<a class="btn small ghost" href="play/" target="_blank" rel="noopener">OPEN IN A FULL WINDOW</a>'
        '<a class="btn small ghost" href="%s" rel="noopener">DOWNLOAD</a></div>') % (im, RELEASES))]


def w_shop(m: Media) -> list:
    menu = ('<div class="shop panel" data-shop tabindex="0" aria-label="The settings shop. Arrow keys or click to browse; Space sells.">'
            '<noscript><p class="px stone">TURN ON JAVASCRIPT TO BROWSE THE MENU.</p></noscript></div>'
            '<p class="hint px stone">CLICK THE MENU, THEN ARROWS AND SPACE. NOTHING HERE IS REALLY SOLD. FOR THAT, TRY SETTINGS AT THE BOTTOM RIGHT.</p>')
    return [(None, menu), ("WHICH SALE LIGHTS WHICH WEAPON", grid(m.many("shot_sale_tag", "shot_levelup", "shot_language"), "grid small"))]


def w_about(m: Media) -> list:
    return [(None, grid(m.many("loop_early"), "grid one-up"))]


def w_motion(m: Media) -> list:
    return [(None, grid(m.many("loop_levelup", "loop_language", "loop_forms", "loop_intro"), "grid two-up"))]


def w_finale(m: Media) -> list:
    one = lambda *ids: grid(m.many(*ids), "grid one-up")
    out = [(None, strip(m.many("shot_too_many", "shot_confirm", "shot_self_sale", "shot_colours_sold", "shot_blast", "shot_relight",
                               "shot_cannot_alone", "shot_pixels_menu", "shot_pixels_melt", "shot_display_off", "shot_ending_burst")))]
    beats = [("1. THE SWELL", ("loop_swell",)), ("4. THE MENU SELLS THE GAME", ("loop_selfsales",)), ("5. THE BLAST", ("loop_blast", "c_p8_blast")),
             ("6. THE RELIGHT", ("loop_relight", "c_p8_relight")), ("7. THE REST OF THE DARK", ("c_p8b_overwhelm",)), ("9. PIXELS", ("loop_pixels",)),
             ("11. THE ENDING", ("c_end_smother", "c_end_heap", "c_end_startled", "c_end_burst", "c_end_display_on"))]
    for name, ids in beats:
        out.append((name, one(*ids) if len(ids) <= 2 else grid(m.many(*ids), "grid small")))
    px = m.get("snd_finale_pixels")
    if px:
        out.append(("10. DISPLAY: OFF", '<div class="tracks">%s</div>' % track(px, "THE PIXELS SALE", "One lantern note per pixel sold, then the AUTO-SELL.")))
    end = m.get("loop_ending")
    if end:
        out.append(("WHY IT ENDS THIS WAY", one("loop_ending")))
    return out


def w_world(m: Media) -> list:
    cards = []
    for i in ("cast_hero", "cast_snuffer", "cast_owl", "cast_magpie", "cast_toad", "cast_sporecap", "cast_gloam"):
        it = m.get(i)
        if not it:
            continue
        name, role, line = CAST_LINES[i]
        ms = it.get("frame_ms")
        ms = ms if isinstance(ms, list) else [ms or 100] * int(it.get("frames") or 1)
        cards.append('<figure class="who panel dark"><canvas class="pix" data-sheet="%s" data-fw="%s" data-fh="%s" data-frames="%s" data-ms="%s" '
                     'role="img" aria-label="%s, animated"></canvas><figcaption><span class="nm px px2">%s</span><span class="role px">%s</span>'
                     '<p>%s</p></figcaption></figure>' % (
                         attr(Media.url(it["file"])), it.get("frame_w"), it.get("frame_h"), it.get("frames"), attr(",".join("%g" % x for x in ms)),
                         attr(it.get("caption") or name), esc(name), esc(role), esc(line)))
    out = [(None, '<div class="cast">%s</div>' % "".join(cards))]
    forms = m.many("c_new_forms", "c_power_ladder", "c_fireflies", "c_toll", "c_lantern_tiers", "c_last_light")
    out.append(("THE LANTERN", grid(forms, "grid small")))
    mp = m.get("map_map")
    if mp:
        out.append(("THE ISLAND", (
            '<div class="island frame" data-island tabindex="0" aria-label="The whole island map. Drag or use the arrow keys to look around.">'
            '<img src="%s" alt="%s" width="%s" height="%s" draggable="false">'
            '<span class="hint px stone outlined">DRAG TO LOOK AROUND</span>'
            '<span class="zoom"><button class="btn small" type="button" data-z="-1" aria-label="Zoom out">-</button>'
            '<button class="btn small" type="button" data-z="1" aria-label="Zoom in">+</button></span></div>') % (
            attr(Media.url(mp["file"])), attr(mp.get("caption")), mp.get("w"), mp.get("h"))))
        out.append(("THE ISLAND", grid(m.many("c_zone_grove", "c_zone_tower", "c_zone_glasshouse", "c_screen_spawn",
                                               "c_screen_bridge", "c_screen_falls", "c_screen_moonpool"), "grid small")))
    out.append(("THE DARK", grid(m.many("mechanic_snuffer", "mechanic_owl", "mechanic_magpie", "mechanic_toad", "mechanic_sporecap",
                                         "mechanic_gloam"), "grid small")))
    return out


def w_art(m: Media) -> list:
    pal = '<div class="swatches" data-swatches></div><p class="hint px stone">CLICK A COLOUR TO COPY ITS HEX.</p>'
    out = [("THE PALETTE", pal)]
    full, broke = m.get("c_trade_full"), m.get("c_trade_pixels") or m.get("c_trade_colour")
    if full and broke:
        out.append(("BEAUTIFUL, THEN BROKEN", (
            '<div class="ba frame" data-ba data-base="%d" tabindex="0" role="slider" aria-label="Before and after: drag to compare" aria-valuemin="0" aria-valuemax="100" aria-valuenow="50">'
            '%s<div class="after">%s</div><div class="handle"></div><span class="lbl l px outlined">ALL SETTINGS: HIGH</span>'
            '<span class="lbl r px outlined coral">SOLD</span></div>') % (base_px(full) or 320, img(full, "pix", False).replace(' data-base', ' data-nb'), img(broke, "pix", False).replace(' data-base', ' data-nb'))))
    out.append(("BEAUTIFUL, THEN BROKEN", grid(m.many("c_trade_colour", "c_trade_resolution", "c_trade_brightness", "c_trade_fov",
                                                     "c_trade_pixels"), "grid small")))
    out.append(("THE HOP RULE", grid(m.many("c_wick_turnaround", "c_wick_hop"), "grid two-up")))
    out.append(("THE HOP RULE", grid(m.many("turnaround_snuffer", "turnaround_owl", "turnaround_magpie", "turnaround_toad", "turnaround_sporecap", "turnaround_gloam"), "grid small")))
    out.append(("THE TITLE", grid(m.many("loop_title", "shot_ending_luxel"), "grid two-up")))
    return out


def w_sound(m: Media, arc: dict | None) -> list:
    main = [(m.get("snd_title"), "THE TITLE", None), (m.get("music_run_journey"), "THE RUN", None),
            (m.get("snd_ending"), "THE ENDING THEME", None)]
    out = [(None, '<div class="tracks">%s</div>' % "".join(track(it, t, n) for it, t, n in main if it))]
    st = m.many("snd_levelup_stings", "snd_music_sold")
    if st:
        out.append(("THE SETTINGS ARE PART OF THE SCORE", '<div class="tracks">%s</div>' % "".join(track(it) for it in st)))
    fx = m.many("snd_death")
    if fx:
        out.append(("SOUND EFFECTS", '<div class="tracks">%s</div>' % "".join(track(it, "WICK FELL", "The death sting.") for it in fx)))
    sh = m.get("snd_shards")
    if sh:
        out.append(("THE SHARDS SING", '<div class="tracks">%s</div>' % track(sh)))
    return out


def w_journey(m: Media, timeline: list | None) -> list:
    if not timeline:
        return []
    stops = []
    for e in timeline:
        stops.append('<li class="stop" data-tag="%s"><span class="lamp" aria-hidden="true"></span><span class="when px">%s</span>'
                     '<h3>%s</h3><div class="body">%s</div></li>' % (
                         attr(e.get("tag", "")), esc((e.get("tag") or "").upper()), esc(e.get("title", "")), esc(e.get("text", ""))))
    return [(None, '<ol class="path" data-path>%s</ol>' % "".join(stops))]


def w_numbers(facts: list | None) -> list:
    if not facts:
        return []
    cells = "".join('<div class="stat"><span class="v px px2" data-count="%s">%s</span><span class="k px">%s</span></div>' % (
        attr(f["value"]), esc(f["value"]), esc(f["label"])) for f in facts)
    return [(None, '<div class="stats">%s</div>' % cells)]


def w_downloads() -> list:
    return [(None, (
        '<div class="dl">%s%s%s%s</div>') % (
        btn("▶ PLAY IN BROWSER", "#play", "primary"), btn("DOWNLOAD THE GAME", RELEASES, "", ' rel="noopener"'),
        btn("TRAILER 1080P", TRAILER_1080, "ghost", ' rel="noopener"'), btn("SOURCE", REPO, "ghost", ' rel="noopener"')))]


def w_display_off() -> list:
    return [(None, (
        '<div class="pixels-panel panel" data-pixels><div class="m-head"><span class="px px2 gold outlined">ADVANCED</span>'
        '<span class="px stone">THE LAST SETTING</span></div><hr class="rule">'
        '<div class="pixels-row px on"><span class="cursor-tri" aria-hidden="true"></span><span>PIXELS</span>'
        '<span class="fill-bar"><b></b></span><span class="val">100%</span></div>'
        '<p class="px stone" data-pq>EACH PRESS SELLS 1% OF YOUR SCREEN. YOU CAN BUY IT BACK.</p>'
        '<p class="pix-actions"><button class="btn primary" type="button" data-sell-pixel>SELL 1%</button></p></div>'))]


# ---------------------------------------------------------------- page parts

def render_header(tabs: list) -> str:
    tab_html, mob = [], []
    for t in tabs:
        rows = "".join('<li><a href="#%s"><span class="cursor-tri" aria-hidden="true"></span><span>%s</span><span class="v">%s</span></a></li>'
                       % (attr(s["id"]), esc(s["title"].upper()), esc(s["value"])) for s in t["sections"])
        tab_html.append(
            '<li class="tab" data-tab="%s"><a href="#%s"><span>%s</span> <span class="badge" aria-label="%d sections">%d</span></a>'
            '<div class="drop panel"><div class="head px"><span class="gold">%s</span><span class="stone">%d</span></div>'
            '<ul class="rows">%s</ul></div></li>'
            % (attr(t["name"]), attr(t["sections"][0]["id"]), esc(t["name"]), len(t["sections"]), min(9, len(t["sections"])),
               esc(t["name"]), len(t["sections"]), rows))
        mob.append('<div class="mtab"><div class="mtab-h px"><span class="gold">%s</span><span class="badge">%d</span></div><ul class="rows">%s</ul></div>'
                   % (esc(t["name"]), min(9, len(t["sections"])), rows))
    return ('<header class="bar" id="bar"><div class="bar-in">'
            '<a class="brand" href="#top" aria-label="Luxel, back to the top"><canvas id="brand-canvas" class="pix" width="96" height="26" aria-hidden="true"></canvas></a>'
            '<nav aria-label="Sections"><ul class="tabs">%s</ul></nav>'
            '<div class="bar-right"><a class="btn small primary" href="#play">PLAY</a>'
            '<button class="btn small menu-btn" type="button" aria-expanded="false" aria-controls="mobile-menu">MENU</button></div>'
            '</div><nav id="mobile-menu" class="panel" aria-label="Sections">%s</nav></header>') % ("".join(tab_html), "".join(mob))


def render_hero(hero: dict) -> str:
    lines = hero.get("tagline") or ["THE LANTERN WILL TAKE ANYTHING THAT GLOWS.", "YOUR SCREEN GLOWS."]
    tag = "".join('<span class="t px">%s</span>' % esc(l) for l in lines)
    return ('<section class="hero" id="top" aria-label="Luxel">'
            '<canvas id="hero-canvas" class="pix" aria-hidden="true"></canvas>'
            '<h1>LUXEL</h1>'
            '<div class="hero-ui"><p class="tagline" data-type>%s</p>'
            '<div class="hero-buttons">%s%s%s%s</div>'
            '<p class="hero-meta px">%s</p>'
            '<a class="scroll-hint px" href="#about" aria-label="Scroll down">▼</a></div></section>') % (
        tag, btn("▶ PLAY IN BROWSER", "#play", "primary"), btn("WATCH TRAILER", "#trailer"),
        btn("DOWNLOAD", RELEASES, "ghost", ' rel="noopener"'), btn("SOURCE", REPO, "ghost", ' rel="noopener"'),
        esc(hero.get("meta", "A GAME JAM ENTRY BY MARWAN. THEME: TRADE-OFF.")))


def render_section(s: dict, widgets: list) -> str:
    meta = s["meta"]
    intro, parts = split_parts(s["body"])
    open_parts = meta["id"] in OPEN_PARTS or len(parts) <= 1
    names = {n for n, _ in parts}
    top = "".join(h for a, h in widgets if (a is None or a not in names) and h)
    out = ['<div class="prose">%s</div>' % md(intro) if intro else "", '<div class="widget">%s</div>' % top if top else ""]
    rows = []
    for i, (name, text) in enumerate(parts):
        before = "".join(h for a, h in widgets if a == name and h)
        body = md(text)
        if open_parts:
            rows.append('<div class="part">%s<div class="prose"><h3>%s</h3>%s</div></div>' % (
                '<div class="widget">%s</div>' % before if before else "", esc(name), body))
        else:
            rows.append('%s<details class="row"%s><summary><span class="cursor-tri" aria-hidden="true"></span><span class="px">%s</span>'
                        '<span class="px pm" aria-hidden="true"></span></summary><div class="prose">%s</div></details>' % (
                            '<div class="widget">%s</div>' % before if before else "", " open" if i == 0 else "", esc(name), body))
    out.append('<div class="parts%s">%s</div>' % ("" if open_parts else " folded", "".join(rows)) if rows else "")
    inner = "".join(out)
    if meta["id"] == "about" and top:
        inner = '<div class="split"><div>%s%s</div>%s</div>' % (out[0], out[2], out[1])
    if meta.get("spoiler"):
        teaser = meta.get("teaser") or "This part spoils the ending."
        inner = ('<details class="spoiler"><summary><div class="sp panel dark"><p class="px coral">SPOILERS</p>'
                 '<p class="teaser">%s</p><span class="btn">SHOW THE ENDING</span></div></summary>%s</details>' % (esc(teaser), inner))
    kicker = meta.get("kicker", "")
    return ('<section class="section" id="%s" data-tab="%s" aria-labelledby="h-%s"><div class="wrap">'
            '<header class="sec-head"><p class="kicker px"><span class="n">%s</span><span>%s</span></p>%s</header>%s</div></section>') % (
        attr(meta["id"]), attr(s["nav"]), attr(meta["id"]), esc(s["value"]), esc(str(kicker).upper()),
        lux_heading(meta["title"], hid="h-" + meta["id"]), inner)


def render_footer() -> str:
    return ('<footer class="foot"><div class="wrap"><div class="links">%s%s%s%s</div>'
            '<p class="px">LUXEL. A GAME JAM ENTRY BY MARWAN. THEME: TRADE-OFF.</p>'
            '<p>© 2026 Marwan. All rights reserved.</p></div></footer>') % (
        btn("PLAY", "#play", "small primary"), btn("DOWNLOAD", RELEASES, "small ghost", ' rel="noopener"'),
        btn("SOURCE", REPO, "small ghost", ' rel="noopener"'), btn("BACK TO THE TOP", "#top", "small ghost"))


# ---------------------------------------------------------------- build

def copy_tree(src: Path, dst: Path, skip=lambda p: False) -> int:
    n = 0
    for p in src.rglob("*"):
        if p.is_dir() or skip(p):
            continue
        q = dst / p.relative_to(src)
        q.parent.mkdir(parents=True, exist_ok=True)
        if not q.exists() or q.stat().st_mtime < p.stat().st_mtime or q.stat().st_size != p.stat().st_size:
            shutil.copy2(p, q)
        n += 1
    return n


def make_icons(out: Path) -> None:
    """The favicon: one luxel (a gold 4 px lamp, lit top-left, shaded bottom-right) on the night."""
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 6 6" shape-rendering="crispEdges">'
           '<rect width="6" height="6" fill="#0d0b1e"/><rect x="1" y="1" width="4" height="4" fill="#ffd98c"/>'
           '<rect x="2" y="4" width="3" height="1" fill="#f5a96a"/><rect x="4" y="2" width="1" height="3" fill="#f5a96a"/>'
           '<rect x="1" y="1" width="3" height="1" fill="#fff4dc"/><rect x="1" y="1" width="1" height="3" fill="#fff4dc"/></svg>')
    (out / "favicon.svg").write_text(svg)
    try:
        from PIL import Image
    except ImportError:
        return
    base = Image.new("RGB", (6, 6), "#0d0b1e")
    px = base.load()
    for x in range(1, 5):
        for y in range(1, 5):
            px[x, y] = (255, 217, 140)
    for x in range(2, 5):
        px[x, 4] = (245, 169, 106)
    for y in range(2, 5):
        px[4, y] = (245, 169, 106)
    for x in range(1, 4):
        px[x, 1] = (255, 244, 220)
    for y in range(1, 4):
        px[1, y] = (255, 244, 220)
    base.resize((32, 32), Image.NEAREST).save(out / "favicon-32.png")
    base.resize((180, 180), Image.NEAREST).save(out / "favicon-180.png")


def arc_data() -> dict | None:
    f = ROOT / "audio/music/run.json"
    if not f.exists():
        return None
    plan = json.loads(f.read_text(encoding="utf-8"))
    order = [{"id": k, "bars": ph.get("bars", 1), "part": ph.get("part", ""), "file": ph.get("file", ""),
              "hold": bool(ph.get("exit")), "due": (ph.get("exit") or {}).get("due")} for k, ph in plan.get("phrases", {}).items()]
    seen: set = set()
    order = [o for o in order if not (o["file"] in seen or seen.add(o["file"]))]  # engine2 replays engine
    return {"bpm": plan.get("bpm"), "bar": plan.get("bar"), "phrases": order, "all": len(plan.get("phrases", {}))}


def main() -> None:
    sections, extra, status = load_content()
    media = Media()
    hero: dict = {}
    page = []
    for s in sections:
        if s["meta"]["id"] == "hero":
            intro, parts = split_parts(s["body"])
            sub = dict(parts)
            if sub.get("TAGLINE"):
                hero["tagline"] = [l.strip() for l in sub["TAGLINE"].splitlines() if l.strip()]
            hero["hook"] = sub.get("HOOK", "")
            hero["sub"] = sub
            continue
        page.append(s)
    ids = [s["meta"]["id"] for s in page]
    sub = hero.get("sub", {})
    about_body = sub.get("PITCH", "")
    for k in ("THEME", "AT A GLANCE"):
        if sub.get(k):
            about_body += "\n\n## %s\n\n%s" % ("THE THEME" if k == "THEME" else k, sub[k])
    builtin_top = [
        {"meta": {"id": "about", "tab": "START", "title": "THE GAME", "kicker": "SELL A SETTING. GET POWER."}, "body": about_body},
        {"meta": {"id": "trailer", "tab": "TRAILER", "title": "TRAILER", "kicker": "80 SECONDS. SOUND ON."}, "body": ""},
        {"meta": {"id": "play", "tab": "PLAY", "title": "PLAY IT HERE", "kicker": "RIGHT IN THE BROWSER"},
         "body": "A run takes about six and a half minutes, and the ending one more. The first run teaches itself: you only move, the lantern does the rest."},
    ]
    motion = {"meta": {"id": "motion", "tab": "LOOPS", "title": "IN MOTION", "kicker": "THE RUN, FOUR MOMENTS"}, "body": ""}
    tail = [
        {"meta": {"id": "downloads", "tab": "DOWNLOADS", "title": "DOWNLOADS", "kicker": "TAKE IT WITH YOU"},
         "body": "The desktop builds and the full-quality trailer are on the GitHub release page. The source is on GitHub too, to read."},
        {"meta": {"id": "display-off", "tab": "DISPLAY", "title": "DISPLAY: OFF", "kicker": "THE LAST SETTING"},
         "body": "The game ends when you sell the screen. So does this page."},
    ]
    page = [b for b in builtin_top if b["meta"]["id"] not in ids] + page
    i = next((n for n, s in enumerate(page) if s["meta"]["id"] == "shop"), None)
    if i is not None:
        page.insert(i + 1, motion)
    page += tail
    nav_of = {sid: name for name, sids in NAV for sid in sids}
    order = {name: n for n, (name, _) in enumerate(NAV)}
    tabs: list[dict] = [{"name": name, "sections": []} for name, _ in NAV]
    for s in page:
        s["id"] = s["meta"]["id"]
        s["title"] = s["meta"]["title"]
        s["nav"] = nav_of.get(s["id"], "ADVANCED")
        s["value"] = str(s["meta"].get("tab", "")).upper()
        tabs[order[s["nav"]]]["sections"].append(s)
    tabs = [t for t in tabs if t["sections"]]
    arc = arc_data()
    W = {
        "trailer": lambda: w_trailer(media), "play": lambda: w_play(media), "shop": lambda: w_shop(media),
        "motion": lambda: w_motion(media), "about": lambda: w_about(media), "finale": lambda: w_finale(media), "world": lambda: w_world(media),
        "art": lambda: w_art(media), "sound": lambda: w_sound(media, arc), "journey": lambda: w_journey(media, extra.get("timeline.json")),
        "numbers": lambda: w_numbers(extra.get("facts.json")),
        "downloads": w_downloads, "display-off": w_display_off,
    }
    html_sections = [render_section(s, W.get(s["id"], lambda: [])()) for s in page]

    data = {"shop": shop_data(), "arc": None, "links": {"play": "play/", "releases": RELEASES, "repo": REPO}, "status": status}
    OUT.mkdir(parents=True, exist_ok=True)
    assets = OUT / "assets"
    assets.mkdir(exist_ok=True)
    js = "\n;\n".join(p.read_text(encoding="utf-8") for p in sorted((WEB / "src/js").glob("*.js")))
    css = "\n".join(p.read_text(encoding="utf-8") for p in sorted((WEB / "src/css").glob("*.css")))
    (assets / "site.js").write_text(js, encoding="utf-8")
    (assets / "site.css").write_text(css, encoding="utf-8")
    copy_tree(WEB / "assets", assets)
    make_icons(assets)
    og = media.get("og")
    og_url = SITE_URL + Media.url(og["file"]) if og else SITE_URL + "media/shots/og.png"
    desc = re.sub(r"\s+", " ", hero.get("hook") or "A survivor game where the upgrade shop is the game's own Settings menu. Sell a setting, get power.")
    tpl = (WEB / "templates/index.html").read_text(encoding="utf-8")
    mp = media.get("map_map")
    rep = {
        "{{DESCRIPTION}}": attr(desc),
        "{{SITE_URL}}": SITE_URL,
        "{{OG_IMAGE}}": attr(og_url),
        "{{V_CSS}}": hashlib.md5(css.encode()).hexdigest()[:8],
        "{{V_JS}}": hashlib.md5(js.encode()).hexdigest()[:8],
        "{{HEADER}}": render_header(tabs),
        "{{HERO}}": render_hero(hero).replace('id="hero-canvas"', 'id="hero-canvas" data-map="%s"' % attr(
            Media.url(mp["file"]) if mp else "assets/img/island.png")),
        "{{SECTIONS}}": "\n".join(html_sections),
        "{{FOOTER}}": render_footer(),
        "{{SELL_PANEL}}": '<div id="sell" role="dialog" aria-modal="true" aria-label="Sell this website\'s settings"></div>',
        "{{DATA}}": json.dumps(data, ensure_ascii=True, separators=(",", ":")).replace("</", "<\\/"),
    }
    for k, v in rep.items():
        tpl = tpl.replace(k, v)
    (OUT / "index.html").write_text(tpl, encoding="utf-8")
    nm = 0
    if (OUT / "media").exists():
        shutil.rmtree(OUT / "media")
    if MEDIA.exists():  # ship only what the page references, never the release-only files
        refs = {r for r in re.findall(r'media/([A-Za-z0-9_./-]+\.[A-Za-z0-9]+)', tpl) if r not in media.release_only}
        for rel in sorted(refs):
            src = MEDIA / rel
            if src.is_file():
                (OUT / "media" / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, OUT / "media" / rel)
                nm += 1
    if PLAY.exists() and any(PLAY.iterdir()):
        copy_tree(PLAY, OUT / "play")
    (OUT / ".nojekyll").write_text("")
    unused = sorted(i for i in media.by_id if i not in media.used)
    print("built %s: %d sections in %d tabs, %d media files copied, content=%s, index.html %d KB" % (
        OUT.relative_to(ROOT), len(page), len(tabs), nm, status["content"], len(tpl) // 1024))
    print("media not shown on the page:", ", ".join(unused) or "none")
    if not status["content_done"]:
        print("pending: website/content/DONE not there yet")
    if not status["media_done"]:
        print("pending: publish/site-media/DONE not there yet")


if __name__ == "__main__":
    main()
