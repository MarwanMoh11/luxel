#!/usr/bin/env python3
"""Runs one plain-language edit request from the level editor (luxel/editor/ed_magic.gd).

  python3 tools/epic/editor_magic.py <request_dir>

<request_dir> holds request.json plus room.png and area.png. The answer (a list of editor operations, never file writes) goes to
<request_dir>/result.json: {ok, data, conversation, engine, secs, error}. Engine: claude (Opus 5.5 high, no tools, images inline); if it
fails, agy (Gemini 4 Neon high, read-only plan mode). Set LUXEL_MAGIC_ENGINE=agy|claude to force one.
Measured 2026-11-25 on 1:manor_gardens: claude 6.5 s (pond to pit), 16 s (two lamps), 22 s (vague), 66 s (secret chest puzzle); agy over 200 s.
"""
from __future__ import annotations

import base64
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

TILES = ["ground", "path", "wall", "water", "pit", "void", "bridge", "phantom", "bramble", "cracked", "tide", "glass",
         "mirror", "carpet", "stairs", "grate", "rail", "foliage"]
SCHEMA: Dict[str, Any] = {
    "type": "object",
    "properties": {
        "say": {"type": "string"},
        "ops": {"type": "array", "items": {"type": "object", "properties": {
            "op": {"type": "string", "enum": ["tiles", "add", "move", "delete", "set", "wire", "unwire"]},
            "tile": {"type": "string", "enum": TILES},
            "rects": {"type": "array", "items": {"type": "array", "items": {"type": "integer"}}},
            "what": {"type": "string", "enum": ["object", "enemy", "scenery", "floor_art"]},
            "kind": {"type": "string"}, "variant": {"type": "string"}, "sheet": {"type": "string"},
            "id": {"type": "string"}, "to": {"type": "string"},
            "x": {"type": "number"}, "y": {"type": "number"}, "flip": {"type": "boolean"}, "props": {"type": "object"},
        }, "required": ["op"]}},
        "note_for_claude": {"type": "string"},
    },
    "required": ["say", "ops"],
}

RULES = """You are the hands of a game designer inside the level editor of Luxel. The designer boxed an area of a room and said what they
want in plain words. You answer with edits to that area. Look at both images first.

## The game
Luxel is a top-down pixel-art adventure in the spirit of classic Zelda: 16 px tiles, the player sees 20x11 tiles at once. Wick, a small moth,
carries a lantern that is also the weapon. Moves: bolt (shoots up to 7 tiles), dash (crosses a 2-tile gap), throw the lantern (up to 6 tiles; it
hangs there, lights things, and Wick can zip to it across gaps), beam (pierces, up to 13 tiles), glide (6 tiles), True Lens (briefly makes phantom
floor solid), Sunflare (burst of light). Enemies keep to a routine near where they stand and attack one at a time; they never chase.
Tiles: ground, path, carpet, stairs, bridge are walkable. wall, glass, mirror, grate, rail, foliage are solid (grate, rail and foliage don't block
sight). pit, water, tide and void can't be walked on; falling costs a heart. phantom is a floor that only holds under the True Lens. bramble burns
away, cracked breaks.

## Taste, always
- Every prop has a reason to stand where it does: it frames a door or path, builds a believable little scene against a wall, or tells a story.
  Never scatter things. Never perfect symmetry everywhere. Never a grid of identical things.
- Keep walking lanes at least 2 tiles wide, and keep fights, shooting lines and puzzle sightlines clear.
- Nothing floats over pits, water or void, or stands inside walls (except things made for it, like bridges, rafts, hooks).
- Fights: pair different roles and give the arena cover or a hazard that matters. Don't just add bodies.
- Puzzles: something seen early pays off later; wire every switch to something; no unwired switches.
- Teach by sight, never by text. Light leads the eye to where the player should go.
- Keep what makes the room work (its vision and intended way through are below) unless the request changes it.
- Only change tiles and things inside the boxed area. Keep every exit and important object reachable. Small, precise edits beat big rebuilds
  unless the request asks for a big change.

## Coordinates
Tile (x, y) counts from (0, 0) at the room's top left; the images carry these numbers. Object, enemy and scenery positions are in pixels:
the centre of tile (x, y) is (x*16+8, y*16+8). Use multiples of 8 for objects and enemies, 4 for scenery. A scenery position is where its
foot touches the floor (bottom centre). Floor art is painted flat on the floor, centred on its position.

## Your answer: JSON with
- say: one or two short plain sentences telling the designer what you did and why, no ids or jargon, no hype.
- ops, in order:
  - {"op":"tiles","tile":"wall","rects":[[x,y,w,h],...]} in tiles
  - {"op":"add","what":"object","kind":K,"x":px,"y":px,"id":"new1","props":{...}}: kind from the palette (doors also need "variant"); id is a
    temporary name you can wire to; props only to change a default. what "enemy" (kind), "scenery" (kind = prop name, plus "sheet", optional
    "flip"), "floor_art" (kind) work the same way
  - {"op":"move","id":REF,"x":px,"y":px}, {"op":"delete","id":REF}, {"op":"set","id":REF,"props":{...}} for things listed below (REF is their ref)
  - {"op":"wire","from"... } is written {"op":"wire","id":SOURCE_REF,"to":TARGET_REF}: the source (switch, plate, brazier, gate) drives the
    target (door, gate). "unwire" removes it.
- note_for_claude: leave it empty unless something the designer asked for can't be done with these ops (new art, new behaviour, story events, moving exits, resizing the
  room): say exactly what is missing, for the programmer. Do the best version with the ops you have anyway.
If the request is a question, answer it in "say" with an empty ops list."""


def ruler_map(rows: List[str], area: List[int]) -> str:
    w = len(rows[0]) if rows else 0
    tens = "    " + "".join(str((x // 10) % 10) if x % 10 == 0 else " " for x in range(w))
    ones = "    " + "".join(str(x % 10) for x in range(w))
    return "\n".join([tens, ones] + [f"{y:3d} {r}" + ("  <" if area[1] <= y < area[1] + area[3] else "") for y, r in enumerate(rows)])


def short(v: Any) -> str:
    return json.dumps(v, separators=(",", ":"), ensure_ascii=False)


def room_block(r: Dict[str, Any]) -> str:
    a = r["area"]
    L = [f"# Room: {r['title']} ({r['subtitle']}), {r['size'][0]}x{r['size'][1]} tiles. Moves the player owns here: {', '.join(r['moves'])}."]
    L.append(f"Boxed area: tiles x {a[0]}..{a[0] + a[2] - 1}, y {a[1]}..{a[1] + a[3] - 1} (pixels {a[0] * 16}..{(a[0] + a[2]) * 16}, "
             f"{a[1] * 16}..{(a[1] + a[3]) * 16})." + (" That is the whole room." if r.get("whole") else ""))
    L.append("\n## Map (rows marked < cross the area)\nLegend: " + ", ".join(f"{k}={v}" for k, v in r["legend"].items()))
    L.append(ruler_map(r["rows"], a))
    L.append("\n## Things in the area (mark = the number tag on the close-up)")
    for t in r["things"]:
        if t["in"]:
            L.append(f"- mark {t['mark']} ref `{t['ref']}` {t['what']} {t['kind']} \"{t['name']}\" at {short(t['pos'])} {short(t.get('props', {}))}")
    if not any(t["in"] for t in r["things"]):
        L.append("- nothing yet")
    out = [f"`{t['ref']}` {t['kind']} {short(t['pos'])}" for t in r["things"] if not t["in"] and t["what"] in ("object", "enemy")]
    L.append("\n## Elsewhere in the room (only for wires and context; not yours to change)\n" + ("; ".join(out) or "nothing"))
    L.append("\n## Wires: " + ("; ".join(f"{x[0]} -> {x[1]}" for x in r["wires"]) or "none"))
    L.append("## Exits (tiles x,y,w,h): " + "; ".join(f"to {e['to']} {short(e['tiles'])}" for e in r["exits"]))
    L.append(f"## The player enters around {short(r['spawn'])}; Wick stands at {short(r['wick'])}.")
    v = r["vision"]
    L.append("\n## What this room is meant to be\n" + "\n".join(x for x in [
        v.get("promise", ""), ("The player should realise: " + v["aha"]) if v.get("aha") else "", ("Teaches: " + v["teaches"]) if v.get("teaches") else "",
        ("Type: " + v["shape"]) if v.get("shape") else "", ("Island rule: " + v["rule"]) if v.get("rule") else "",
        ("Intended way through: " + " > ".join(v["steps"])) if v.get("steps") else ""] if x))
    return "\n".join(L)


def palette_block(p: Dict[str, Any]) -> str:
    L = ["# Palette (only these exist)", "## Objects: kind (variant) \"name\": what it does | default props | tunable"]
    for o in p["objects"]:
        k = o["kind"] + (f" (variant {o['variant']})" if o.get("variant") else "")
        L.append(f"- {k} \"{o['name']}\": {o['blurb']} | {short(o['props'])} | {short(o['tune']) if o.get('tune') else ''}")
    L.append("## Enemies: " + "; ".join(f"{e['kind']} \"{e['name']}\" ({e['blurb']})" for e in p["enemies"]))
    if p.get("bosses"):
        L.append("## Bosses (only if asked for one): " + ", ".join(p["bosses"]))
    L.append("## Scenery: sheet: prop (width x height px)")
    for s in p["scenery"]:
        L.append(f"- {s['sheet']} ({s['set']}): " + ", ".join(f"{q['prop']} {q['w']}x{q['h']}" for q in s["props"]))
    L.append("## Floor art: " + ", ".join(p["floor_art"]))
    return "\n".join(L)


HURRY = ("The designer is waiting: pick one clear idea, decide quickly and answer at once. At most 14 ops unless they ask for a big change, "
         "no long planning.")


def build_prompt(r: Dict[str, Any], fresh: bool) -> str:
    """The words that go with the two images. Fresh requests carry the palette; follow-ups only what moved on."""
    parts: List[str] = []
    if fresh:
        parts += [palette_block(r["palette"]), room_block(r)]
    elif r.get("problems"):
        pass
    else:
        parts.append("This is the room as it is now" + (", with your last edit in it." if r.get("applied") else ". Your last edit is not in it."))
        parts.append(room_block(r))
    if r.get("problems"):
        parts.append("# Your last edit had problems, so it was not applied. Send the whole corrected list of ops for the same wish.\n"
                     + "\n".join("- " + x for x in r["problems"]))
    else:
        parts.append("# The designer says\n" + r["ask"])
    parts.append(HURRY)
    return "\n\n".join(parts)


def parse_json(text: str) -> Optional[Dict[str, Any]]:
    text = text.strip()
    i, j = text.find("{"), text.rfind("}")
    if i < 0 or j <= i:
        return None
    try:
        v = json.loads(text[i:j + 1])
        return v if isinstance(v, dict) else None
    except ValueError:
        return None


CHILD: Optional[subprocess.Popen] = None


def run(cmd: List[str], cwd: Path, timeout: int, feed: Optional[str] = None) -> Tuple[int, str, str]:
    global CHILD
    env = dict(os.environ)
    home = env.get("HOME", "")
    env["PATH"] = f"/opt/homebrew/bin:{home}/.local/bin:/usr/local/bin:" + env.get("PATH", "/usr/bin:/bin")
    for k in ("CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT"):
        env.pop(k, None)
    CHILD = subprocess.Popen(cmd, cwd=cwd, env=env, stdin=subprocess.DEVNULL if feed is None else subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             text=True, start_new_session=True)
    try:
        out, err = CHILD.communicate(feed, timeout=timeout)
        return CHILD.returncode, out, err
    except subprocess.TimeoutExpired:
        stop()
        return 124, "", "timed out"


def stop(*_: Any) -> None:
    if CHILD is not None and CHILD.poll() is None:
        try:
            os.killpg(CHILD.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def find(name: str) -> str:
    home = os.environ.get("HOME", "")
    for p in (f"/opt/homebrew/bin/{name}", f"{home}/.local/bin/{name}", f"/usr/local/bin/{name}"):
        if os.path.exists(p):
            return p
    return shutil.which(name) or ""


IMAGES = "The first image is the close-up of the boxed area with tile numbers and number tags, the second is the whole room with the area outlined in gold."


def ask_claude(prompt: str, d: Path, conv: str) -> Dict[str, Any]:
    """Opus with both images inline and no tools: one round trip. 6-20 s for small wishes, about a minute for a whole puzzle."""
    exe = find("claude")
    if not exe:
        return {"ok": False, "error": "claude is not installed"}
    content: List[Dict[str, Any]] = []
    for name in ("area.png", "room.png"):
        if (d / name).exists():
            content.append({"type": "image", "source": {"type": "base64", "media_type": "image/png",
                                                         "data": base64.b64encode((d / name).read_bytes()).decode()}})
    content.append({"type": "text", "text": (IMAGES + "\n\n" if content else "") + prompt})
    cmd = [exe, "-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose", "--model", "claude-opus-5-5",
           "--effort", "high", "--system-prompt", RULES, "--tools", "", "--setting-sources", "", "--json-schema", json.dumps(SCHEMA)]
    if conv:
        cmd += ["--resume", conv]
    msg = json.dumps({"type": "user", "message": {"role": "user", "content": content}}) + "\n"
    code, out, err = run(cmd, d, 180, msg)
    for line in reversed(out.splitlines()):
        env = parse_json(line)
        if env is None or env.get("type") != "result":
            continue
        data = env.get("structured_output") or parse_json(str(env.get("result", "")))
        if isinstance(data, dict) and "ops" in data:
            return {"ok": True, "data": data, "conversation": str(env.get("session_id", "")), "engine": "claude"}
        return {"ok": False, "error": "claude answered without edits: " + str(env.get("result", env.get("subtype", "")))[:300]}
    return {"ok": False, "error": f"claude gave no answer (exit {code}): {(err or out).strip()[-300:]}"}


def ask_agy(prompt: str, d: Path, conv: str) -> Dict[str, Any]:
    """Backup. Gemini 4 Neon high reads the images through its file tool; minutes rather than seconds on a hard wish."""
    exe = find("agy")
    if not exe:
        return {"ok": False, "error": "agy is not installed"}
    full = ("" if conv else RULES + "\n\n") + f"Read {d / 'area.png'}, then {d / 'room.png'}. {IMAGES}\n\n{prompt}"
    cmd = [exe, "-p", full, "--model", "gemini-4-neon-high", "--mode", "plan", "--dangerously-skip-permissions",
           "--output-format", "json", "--json-schema", json.dumps(SCHEMA), "--add-dir", str(d)]
    if conv:
        cmd += ["--conversation", conv]
    code, out, err = run(cmd, d, 300)
    env = parse_json(out)
    if env is None:
        return {"ok": False, "error": f"agy gave no answer (exit {code}): {(err or out).strip()[-300:]}"}
    data = env.get("structured_output") or parse_json(str(env.get("response", "")))
    if not isinstance(data, dict) or "ops" not in data:
        return {"ok": False, "error": "agy answered without edits: " + str(env.get("response", env.get("error", "")))[:300]}
    return {"ok": True, "data": data, "conversation": str(env.get("conversation_id", "")), "engine": "agy"}


def main() -> int:
    d = Path(sys.argv[1]).resolve()
    signal.signal(signal.SIGTERM, lambda *_: (stop(), sys.exit(143)))
    r = json.loads((d / "request.json").read_text(encoding="utf-8"))
    conv, engine = str(r.get("conversation", "")), str(r.get("engine", ""))
    t0 = time.time()
    force = os.environ.get("LUXEL_MAGIC_ENGINE", "")
    order = [force] if force else ([engine] if conv and engine else ["claude", "agy"])
    res: Dict[str, Any] = {"ok": False, "error": "no engine"}
    errors: List[str] = []
    for e in order + ([x for x in ("claude", "agy") if x not in order] if not force else []):
        same = bool(conv) and e == (engine or e)
        prompt = build_prompt(r, not same)
        (d / f"prompt_{e}.txt").write_text(prompt, encoding="utf-8")
        res = (ask_agy if e == "agy" else ask_claude)(prompt, d, conv if same else "")
        if res["ok"]:
            break
        errors.append(str(res["error"]))
    res["secs"] = round(time.time() - t0, 1)
    if not res["ok"]:
        res["error"] = " / ".join(errors)
    tmp = d / "result.tmp"
    tmp.write_text(json.dumps(res, ensure_ascii=False), encoding="utf-8")
    tmp.rename(d / "result.json")
    return 0 if res["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
