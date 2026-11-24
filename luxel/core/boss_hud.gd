class_name LxBossHud
extends RefCounted
## Boss health bar renderer and pack-driven metadata lookup (supports 1 or 2 simultaneous bosses).

const FALLBACK_NAME_KEYS: Dictionary = {
	"bellkeeper": "BOSS_BELLKEEPER", "boss_bellkeeper": "BOSS_BELLKEEPER", "grand_bellkeeper": "BOSS_BELLKEEPER",
	"lighthouse_hermit": "BOSS_HERMIT", "boss_hermit": "BOSS_HERMIT", "hermit": "BOSS_HERMIT",
	"briar_matron": "BOSS_MATRON", "boss_matron": "BOSS_MATRON", "matron": "BOSS_MATRON",
	"heron_abbess": "BOSS_ABBESS", "boss_abbess": "BOSS_ABBESS", "abbess": "BOSS_ABBESS",
	"astronomer": "BOSS_ASTRONOMER", "boss_astronomer": "BOSS_ASTRONOMER", "the_astronomer": "BOSS_ASTRONOMER",
	"kilnmother": "BOSS_KILNMOTHER", "boss_kilnmother": "BOSS_KILNMOTHER", "the_kilnmother": "BOSS_KILNMOTHER",
	"hollow_wick": "BOSS_HOLLOW", "hollow_wick_boss": "BOSS_HOLLOW", "boss_hollow": "BOSS_HOLLOW", "hollow": "BOSS_HOLLOW",
	"the_hush": "BOSS_HUSH", "boss_hush": "BOSS_HUSH", "hush": "BOSS_HUSH",
	"bell_warden": "MINIBOSS_1", "bell_warden_r5": "MINIBOSS_1",
	"tide_captain": "MINIBOSS_2", "boss_tide_captain": "MINIBOSS_2",
	"elder_sporecap": "MINIBOSS_3", "boss_elder_sporecap": "MINIBOSS_3",
	"great_lily_hopper": "MINIBOSS_4", "boss_great_lily_hopper": "MINIBOSS_4",
	"clockwork_warden": "MINIBOSS_5", "boss_clockwork_warden": "MINIBOSS_5",
	"forge_warden": "MINIBOSS_6", "boss_forge_warden": "MINIBOSS_6",
	"moonshade_warden": "MINIBOSS_7", "spire_warden": "MINIBOSS_7", "boss_moonshade_warden": "MINIBOSS_7",
	"night_harbinger": "MINIBOSS_8", "mini_night_harbinger": "MINIBOSS_8", "boss_night_harbinger": "MINIBOSS_8",
}


static func resolve_name_key(boss_id_or_key: String) -> String:
	if LxStrings.has_id(boss_id_or_key):
		return boss_id_or_key
	var low: String = boss_id_or_key.to_lower().strip_edges()
	if Lx.packs != null:
		var meta: Dictionary = Lx.packs.boss_meta(low)
		var mk: String = str(meta.get("name_key", ""))
		if not mk.is_empty():
			return mk
	return str(FALLBACK_NAME_KEYS[low]) if FALLBACK_NAME_KEYS.has(low) else boss_id_or_key


static func resolve_notches(boss_id: String, resolved_key: String) -> Array[float]:
	var out: Array[float] = []
	if Lx.packs != null:
		var meta: Dictionary = Lx.packs.boss_meta(boss_id)
		var ph: Variant = meta.get("phases", [])
		if ph is Array and not (ph as Array).is_empty():
			for v: Variant in (ph as Array):
				var f: float = clampf(float(v), 0.05, 0.95)
				if not out.has(f):
					out.append(f)
			out.sort()
			return out
	if resolved_key == "BOSS_HUSH":
		return [0.25, 0.5, 0.75]
	if resolved_key == "BOSS_BELLKEEPER":
		return [0.2, 0.5]
	if resolved_key in ["BOSS_HERMIT", "BOSS_MATRON", "BOSS_ABBESS", "BOSS_ASTRONOMER", "BOSS_KILNMOTHER", "BOSS_HOLLOW"]:
		return [0.33, 0.66]
	return [0.5]


static func draw_boss_bars(ci: CanvasItem, entries: Array[Dictionary], blink_t: float) -> void:
	var count: int = mini(entries.size(), 2)
	for i: int in range(count):
		_draw_one(ci, entries[i], i, count > 1, blink_t)


static func _draw_one(ci: CanvasItem, b: Dictionary, idx: int, dual: bool, blink_t: float) -> void:
	var bar_w: float = 134.0 if dual else 160.0
	var bar_h: float = 7.0 if dual else 8.0
	var max_hp: float = maxf(1.0, float(b.get("max_hp", 1.0)))
	var hp: float = clampf(float(b.get("hp", 0.0)), 0.0, max_hp)
	var trail_hp: float = clampf(float(b.get("trail_hp", hp)), hp, max_hp)
	var phase: int = maxi(1, int(b.get("phase", 1)))
	var bid: String = str(b.get("id", ""))
	var raw_key: String = str(b.get("name_key", bid))
	var resolved_key: String = resolve_name_key(raw_key)
	var name_txt: String = LxStrings.text(resolved_key) if LxStrings.has_id(resolved_key) else LxStrings.sanitize(resolved_key)
	var hit_jolt: float = (1.0 if fmod(blink_t, 0.08) < 0.04 else -1.0) if (LxHudFx.shake_enabled() and not LxHudFx.flash_reduced() and (trail_hp - hp) > (max_hp * 0.015)) else 0.0
	var cx: float = (86.0 if idx == 0 else 234.0) if dual else 160.0
	var x: float = roundf(cx - bar_w * 0.5) + hit_jolt
	var y: float = 148.0
	var nw: float = float(LxPixelFont.width(name_txt, 1))
	var pill_bg := Color(LxPalette.PAL["void"] as Color, 0.72)
	ci.draw_rect(Rect2(roundf(cx - nw * 0.5 - 3.0), y - 10.0, nw + 6.0, 8.0), pill_bg)
	LxPixelFont.draw_centered(ci, name_txt, cx, y - 8.0, LxPalette.PAL["gold"], 1)
	if phase >= 2:
		var ptxt: String = LxStrings.text("HUD_BOSS_P4" if phase >= 4 else ("HUD_BOSS_P3" if phase == 3 else "HUD_BOSS_P2"))
		var pw: float = float(LxPixelFont.width(ptxt, 1))
		var pr: float = roundf(cx + bar_w * 0.5)
		ci.draw_rect(Rect2(pr - pw - 2.0, y - 10.0, pw + 4.0, 8.0), pill_bg)
		LxPixelFont.draw_right(ci, ptxt, pr, y - 8.0, LxPalette.PAL["coral"], 1)
	LxPixelFont.draw_panel(ci, Rect2(x, y, bar_w, bar_h), "night", "gold" if phase >= 2 else "mauve", "void")
	ci.draw_rect(Rect2(x - 1.0, y + 2.0, 2.0, 4.0), LxPalette.PAL["gold"])
	ci.draw_rect(Rect2(x + bar_w - 1.0, y + 2.0, 2.0, 4.0), LxPalette.PAL["gold"])
	if not dual:
		LxHudFx.draw_boss_biome_header(ci, Lx.state.island_id if Lx.state != null else 1, nw, x, y, bar_w, phase)
	var cur_frac: float = clampf(hp / max_hp, 0.0, 1.0)
	var trail_w: float = floorf((bar_w - 4.0) * clampf(trail_hp / max_hp, 0.0, 1.0))
	var cur_w: float = floorf((bar_w - 4.0) * cur_frac)
	if trail_w > 0.0:
		ci.draw_rect(Rect2(x + 2.0, y + 2.0, trail_w, bar_h - 4.0), LxPalette.PAL["apricot"])
		if trail_w > cur_w:
			ci.draw_rect(Rect2(x + 2.0 + cur_w, y + 2.0, minf(2.0, trail_w - cur_w), bar_h - 4.0), LxPalette.PAL["cream"])
	if cur_w > 0.0:
		ci.draw_rect(Rect2(x + 2.0, y + 2.0, cur_w, bar_h - 4.0), LxPalette.PAL["coral"])
		ci.draw_rect(Rect2(x + 2.0, y + 2.0, cur_w, 1.0), LxPalette.PAL["rose"])
	for frac: float in resolve_notches(bid, resolved_key):
		ci.draw_rect(Rect2(roundf(x + 2.0 + (bar_w - 4.0) * frac), y + 1.0, 1.0, bar_h - 2.0), LxPalette.PAL["gold"] if cur_frac > frac else LxPalette.PAL["dusk"])


# ---- Runtime boss HUD, pack music crossfade & boss-rush lifecycle helpers (extracted from LxMain) ----

static func get_live_bosses(region_loader: Node, limit: int = 2) -> Array[LxEnemyBrain]:
	var live: Array[LxEnemyBrain] = []
	if region_loader != null and region_loader.has_method("get_enemies"):
		for e: LxEnemyBrain in region_loader.call("get_enemies"):
			if e != null and is_instance_valid(e) and e.is_alive() and e.visible and (e.is_boss or not e.boss_id.is_empty()):
				live.append(e)
				if live.size() >= limit:
					break
	return live


static func region_has_live_boss(region_loader: Node) -> bool:
	return not get_live_bosses(region_loader, 1).is_empty()


static func sync_live_bosses(region_loader: Node, tracked_bosses: Array[Object], hud: Node) -> void:
	var live: Array[LxEnemyBrain] = get_live_bosses(region_loader, 2)
	if not live.is_empty() and hud != null:
		for b: LxEnemyBrain in live:
			if not tracked_bosses.has(b):
				LxDamageFx.trigger_boss_awaken(b)
				_crossfade_boss_music(b)
		tracked_bosses.clear()
		for b: LxEnemyBrain in live:
			tracked_bosses.append(b)
		if hud.has_method("sync_bosses"):
			hud.call("sync_bosses", live)
		else:
			var b0: LxEnemyBrain = live[0]
			hud.call("show_boss", b0.boss_id if not b0.boss_id.is_empty() else b0.kind, b0.hp, b0.max_hp, b0.phase)
	elif live.is_empty() and not tracked_bosses.is_empty():
		tracked_bosses.clear()
		if hud != null:
			hud.call("hide_boss")


static func _crossfade_boss_music(b: LxEnemyBrain) -> void:
	if Lx.packs == null or Lx.audio == null or b == null:
		return
	var bid: String = b.boss_id if not b.boss_id.is_empty() else b.kind
	var bm: Dictionary = Lx.packs.boss_meta(bid)
	var bm1: String = str(bm.get("music", "")).strip_edges()
	var bm2: String = str(bm.get("music_p2", "")).strip_edges()
	if bm1.is_empty():
		return
	var want: String = bm2 if (b.phase >= 2 and not bm2.is_empty()) else bm1
	if Lx.audio.current_track_group != want and (want != bm1 or Lx.audio.current_track_group != bm2):
		Lx.audio.play_cue(want)


static func handle_boss_phase_changed(boss_id: String, phase: int) -> void:
	if phase < 2 or Lx.packs == null or Lx.audio == null:
		return
	var bm: Dictionary = Lx.packs.boss_meta(boss_id)
	var m2: String = str(bm.get("music_p2", "")).strip_edges()
	if not m2.is_empty() and Lx.audio.current_track_group != m2:
		Lx.audio.play_cue(m2)


static func handle_boss_defeated(boss_id: String, isl: int, region_loader: Node) -> void:
	var bmeta: Dictionary = Lx.packs.boss_meta(boss_id) if Lx.packs != null else {}
	var canon: String = str(bmeta.get("id", boss_id))
	if not Lx.state.defeated_bosses.has(canon):
		Lx.state.defeated_bosses.append(canon)
	var bflag: String = str(bmeta.get("flag", ""))
	if not bflag.is_empty():
		Lx.state.story_flags[bflag] = true
	var dng: String = str(bmeta.get("dungeon", ""))
	if not dng.is_empty() and not bool(bmeta.get("mini", false)):
		Lx.state.story_flags["dungeon_done:" + dng] = true
		var dm: Dictionary = Lx.packs.dungeon(dng) if Lx.packs != null else {}
		var df: String = str(dm.get("done_flag", ""))
		if not df.is_empty():
			Lx.state.story_flags[df] = true
	var heart_kind: String = str(bmeta.get("heart", ""))
	if heart_kind.is_empty():
		var is_major_fb: bool = str(Lx.get_island_data(isl).get("boss", "")) == boss_id or boss_id == "hollow_wick_boss"
		heart_kind = "full" if is_major_fb else "none"
	if heart_kind != "none" and not bool(Lx.state.story_flags.get("boss_heart_" + canon, false)):
		Lx.state.story_flags["boss_heart_" + canon] = true
		if heart_kind == "half":
			Lx.state.add_half_lantern()
		else:
			Lx.state.add_boss_heart()
	var is_major: bool = not bool(bmeta.get("mini", false)) if not bmeta.is_empty() else (heart_kind != "none")
	var still_fighting: bool = region_has_live_boss(region_loader)
	if is_major and not still_fighting and Lx.audio != null and Lx.audio._is_boss_cue(Lx.audio.current_track_group):
		Lx.audio.silence_music(0.85)
	if is_major and not still_fighting and Lx.audio != null:
		Lx.audio.play_stinger("stinger_lamp")
