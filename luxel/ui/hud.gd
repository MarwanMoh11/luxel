class_name LxHud
extends Node2D
## Gameplay HUD (320x180, Last Light palette): hearts (4..12), 3-lantern beacon gauge,
## unlocked move icons with dynamic input glyphs, ember meter, shard/key counters,
## boss health bar, and floating world cues.

const HEART_PIXELS: Array[Rect2] = [Rect2(1.0, 0.0, 1.0, 1.0), Rect2(3.0, 0.0, 1.0, 1.0), Rect2(0.0, 1.0, 5.0, 2.0), Rect2(1.0, 3.0, 3.0, 1.0), Rect2(2.0, 4.0, 1.0, 1.0)]
const HALF_HEART_PIXELS: Array[Rect2] = [Rect2(1.0, 0.0, 1.0, 1.0), Rect2(0.0, 1.0, 3.0, 2.0), Rect2(1.0, 3.0, 2.0, 1.0), Rect2(2.0, 4.0, 1.0, 1.0)]
const LANTERN_FRAME: Array[Rect2] = [Rect2(1.0, 0.0, 3.0, 1.0), Rect2(0.0, 1.0, 5.0, 1.0), Rect2(0.0, 2.0, 1.0, 4.0), Rect2(4.0, 2.0, 1.0, 4.0), Rect2(0.0, 6.0, 5.0, 1.0)]
const MOVE_COLORS: Dictionary = {"bolt": "gold", "dash": "coral", "throw": "apricot", "prism": "sky", "beam": "cream", "wings": "lime", "lens": "ice", "sunflare": "gold"}

const BOSS_NAME_KEYS: Dictionary = {
	"bellkeeper": "BOSS_BELLKEEPER",
	"boss_bellkeeper": "BOSS_BELLKEEPER",
	"grand_bellkeeper": "BOSS_BELLKEEPER",
	"lighthouse_hermit": "BOSS_HERMIT",
	"boss_hermit": "BOSS_HERMIT",
	"hermit": "BOSS_HERMIT",
	"briar_matron": "BOSS_MATRON",
	"boss_matron": "BOSS_MATRON",
	"matron": "BOSS_MATRON",
	"heron_abbess": "BOSS_ABBESS",
	"boss_abbess": "BOSS_ABBESS",
	"abbess": "BOSS_ABBESS",
	"astronomer": "BOSS_ASTRONOMER",
	"boss_astronomer": "BOSS_ASTRONOMER",
	"the_astronomer": "BOSS_ASTRONOMER",
	"kilnmother": "BOSS_KILNMOTHER",
	"boss_kilnmother": "BOSS_KILNMOTHER",
	"the_kilnmother": "BOSS_KILNMOTHER",
	"hollow_wick": "BOSS_HOLLOW",
	"hollow_wick_boss": "BOSS_HOLLOW",
	"boss_hollow": "BOSS_HOLLOW",
	"hollow": "BOSS_HOLLOW",
	"the_hush": "BOSS_HUSH",
	"boss_hush": "BOSS_HUSH",
	"hush": "BOSS_HUSH",
}

var _cues: Array[Dictionary] = [] # {text, pos, is_world, color, t, dur}
var _notice_text: String = ""
var _notice_t: float = 0.0
var _notice_dur: float = 3.5

var _boss_active: bool = false
var _boss_name_key: String = ""
var _boss_hp: float = 0.0
var _boss_max_hp: float = 1.0
var _boss_trail_hp: float = 0.0
var _boss_phase: int = 1

var _ember_val: float = 0.0
var _ember_max: float = 100.0
var _blink_t: float = 0.0
var _hit_cue_cd: float = 0.0
var _last_shards: int = -1
var _shard_pop_t: float = 0.0
var _last_hearts: float = -1.0
var _heart_pop_t: float = 0.0
var _bound: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bind_events()


func bind_events() -> void:
	if _bound or Lx.events == null:
		return
	_bound = true
	if not Lx.events.beacon_lit.is_connected(_on_beacon_lit):
		Lx.events.beacon_lit.connect(_on_beacon_lit)
	if not Lx.events.waystone_lit.is_connected(_on_waystone_lit):
		Lx.events.waystone_lit.connect(_on_waystone_lit)
	if not Lx.events.move_unlocked.is_connected(_on_move_unlocked):
		Lx.events.move_unlocked.connect(_on_move_unlocked)
	if not Lx.events.boss_phase_changed.is_connected(_on_boss_phase):
		Lx.events.boss_phase_changed.connect(_on_boss_phase)
	if not Lx.events.boss_defeated.is_connected(_on_boss_defeated):
		Lx.events.boss_defeated.connect(_on_boss_defeated)
	if not Lx.events.ember_piece_collected.is_connected(_on_ember_piece):
		Lx.events.ember_piece_collected.connect(_on_ember_piece)
	if not Lx.events.enemy_hit.is_connected(_on_enemy_hit):
		Lx.events.enemy_hit.connect(_on_enemy_hit)
	if not Lx.events.lantern_stolen.is_connected(_on_lantern_stolen):
		Lx.events.lantern_stolen.connect(_on_lantern_stolen)


func set_ember(current: float, maximum: float) -> void:
	_ember_max = maxf(1.0, maximum)
	_ember_val = clampf(current, 0.0, _ember_max)
	queue_redraw()


static func resolve_boss_name_key(boss_id_or_key: String) -> String:
	if LxStrings.has_id(boss_id_or_key):
		return boss_id_or_key
	var low: String = boss_id_or_key.to_lower().strip_edges()
	if BOSS_NAME_KEYS.has(low):
		return str(BOSS_NAME_KEYS[low])
	return boss_id_or_key


func show_boss(name_key: String, hp: float, max_hp: float, phase: int = 1) -> void:
	_boss_active = true
	_boss_name_key = resolve_boss_name_key(name_key)
	_boss_max_hp = maxf(1.0, max_hp)
	_boss_hp = clampf(hp, 0.0, _boss_max_hp)
	_boss_trail_hp = _boss_hp
	_boss_phase = maxi(1, phase)
	if _boss_name_key == "BOSS_HOLLOW" and Lx.state != null and not bool(Lx.state.story_flags.get("twist_hollow_shown", false)):
		Lx.state.story_flags["twist_hollow_shown"] = true
		if Lx.events != null:
			Lx.events.narration_requested.emit("TWIST_HOLLOW", "ice", 4.0)
	queue_redraw()


func update_boss(hp: float, max_hp: float, phase: int = -1) -> void:
	_boss_max_hp = maxf(1.0, max_hp)
	_boss_hp = clampf(hp, 0.0, _boss_max_hp)
	if phase > 0:
		_boss_phase = phase
	queue_redraw()


func hide_boss() -> void:
	_boss_active = false
	queue_redraw()


func show_notice(string_id: String, duration: float = 3.5) -> void:
	_notice_text = LxStrings.text(string_id)
	_notice_t = 0.0
	_notice_dur = maxf(duration, 1.0)
	queue_redraw()


func spawn_world_cue(
	string_id: String,
	world_pos: Vector2,
	color_name: String = "gold",
	duration: float = 1.4,
	args: Array = []
) -> void:
	var txt: String = LxStrings.fmt(string_id, args) if not args.is_empty() else LxStrings.text(string_id)
	_cues.append({
		"text": txt,
		"pos": world_pos,
		"is_world": true,
		"color": color_name,
		"t": 0.0,
		"dur": maxf(duration, 0.4),
	})
	queue_redraw()


func spawn_screen_cue(
	string_id: String,
	screen_pos: Vector2,
	color_name: String = "gold",
	duration: float = 1.4,
	args: Array = []
) -> void:
	var txt: String = LxStrings.fmt(string_id, args) if not args.is_empty() else LxStrings.text(string_id)
	var kept: Array[Dictionary] = []
	for c: Dictionary in _cues:
		if bool(c["is_world"]) or absf((c["pos"] as Vector2).y - screen_pos.y) > 14.0:
			kept.append(c)
	_cues = kept
	_cues.append({
		"text": txt,
		"pos": screen_pos,
		"is_world": false,
		"color": color_name,
		"t": 0.0,
		"dur": maxf(duration, 0.4),
	})
	queue_redraw()


func clear_cues() -> void:
	_cues.clear()
	_notice_text = ""
	queue_redraw()


func _on_beacon_lit(_island_id: int, _beacon_id: String) -> void:
	spawn_screen_cue("CUE_BEACON_LIT", Vector2(160.0, 34.0), "gold", 1.8)


func _on_waystone_lit(_island_id: int, _waystone_id: String) -> void:
	spawn_screen_cue("CUE_WAYSTONE_LIT", Vector2(160.0, 34.0), "sky", 1.6)


func _on_move_unlocked(move_id: String) -> void:
	var mdata: Dictionary = Lx.get_move_data(move_id)
	var name_key: String = str(mdata.get("name_key", "CUE_SHRINE_CLAIMED"))
	spawn_screen_cue(name_key, Vector2(160.0, 42.0), "gold", 2.2)


func _on_boss_phase(boss_id: String, phase: int) -> void:
	if not boss_id.is_empty():
		_boss_name_key = resolve_boss_name_key(boss_id)
	_boss_phase = maxi(1, phase)
	if phase >= 2:
		var p_cue: String = ("CUE_HUSH_P4" if phase >= 4 else "CUE_HUSH_P3") if (_boss_name_key == "BOSS_HUSH" and phase >= 3) else ("CUE_PHASE_3" if phase >= 3 else "CUE_PHASE_2")
		spawn_screen_cue(p_cue, Vector2(160.0, 44.0), "coral", 1.8)


func _on_boss_defeated(_boss_id: String, _island_id: int) -> void:
	hide_boss()


func _on_ember_piece(_total: int) -> void:
	spawn_screen_cue("CUE_EMBER_FOUND", Vector2(160.0, 34.0), "apricot", 1.8)


func _on_enemy_hit(enemy: Object, _hit: Object, result: int) -> void:
	if _hit_cue_cd > 0.0 or enemy == null:
		return
	var wpos: Vector2 = (enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO
	if result == 0:
		_hit_cue_cd = 0.45
		var ek: String = str(enemy.get("kind"))
		var eats: bool = ek in ["snatcher", "gull_thief", "mire_snuffer"]
		spawn_world_cue("CUE_EATS_BOLTS" if eats else "CUE_BLOCKED", wpos, "apricot" if eats else "stone", 1.0)
	elif result == 2:
		_hit_cue_cd = 0.35
		spawn_world_cue("CUE_OPEN", wpos, "gold", 1.0)


func _on_lantern_stolen(_thief: Object, pos: Vector2) -> void:
	spawn_world_cue("CUE_LANTERN_STOLEN", pos, "coral", 1.6)


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_t += delta
	_hit_cue_cd = maxf(0.0, _hit_cue_cd - delta)
	_shard_pop_t = maxf(0.0, _shard_pop_t - delta)
	_heart_pop_t = maxf(0.0, _heart_pop_t - delta)
	if Lx.state != null:
		if _last_shards >= 0 and Lx.state.shards > _last_shards: _shard_pop_t = 0.28
		_last_shards = Lx.state.shards
		if _last_hearts >= 0.0 and not is_equal_approx(Lx.state.hearts, _last_hearts): _heart_pop_t = 0.24
		_last_hearts = Lx.state.hearts
	if _boss_active and _boss_trail_hp > _boss_hp:
		_boss_trail_hp = maxf(_boss_hp, _boss_trail_hp - _boss_max_hp * 0.45 * delta)
	if not _cues.is_empty():
		var kept: Array[Dictionary] = []
		for cue: Dictionary in _cues:
			cue["t"] = float(cue["t"]) + delta
			if float(cue["t"]) < float(cue["dur"]):
				kept.append(cue)
		_cues = kept
	if not _notice_text.is_empty():
		_notice_t += delta
		if _notice_t >= _notice_dur:
			_notice_text = ""
	_sync_player_ember()
	queue_redraw()


func _sync_player_ember() -> void:
	if Lx.state == null or not Lx.state.has_move("sunflare"):
		return
	_ember_max = maxf(1.0, Lx.state.get_effective_ember_max())
	if Lx.player != null and Lx.player.has_method("get_ember"):
		_ember_val = clampf(float(Lx.player.call("get_ember")), 0.0, _ember_max)


func _draw() -> void:
	if Lx.state == null:
		return
	_draw_hearts(Vector2(5.0, 5.0))
	if not _boss_active:
		_draw_beacon_gauge(160.0, 4.0)
	var keys_shown: bool = _draw_shards_and_keys(Vector2(315.0, 5.0))
	_draw_moves_tray(Vector2(5.0, 160.0))
	_draw_zip_cue(Vector2(5.0, 148.0))
	if Lx.world != null and not _boss_active:
		LxMinimap.draw_minimap(self, Vector2(263.0, 22.0 if keys_shown else 16.0), _blink_t)
	if Lx.state.has_move("sunflare"):
		_draw_ember_meter(Vector2(246.0, 166.0))
	if _boss_active:
		_draw_boss_bar()
	_draw_interact_prompt()
	_draw_cues(); _draw_notice()
	LxHudFx.draw_indicators(self, _blink_t, _boss_active, _boss_phase)


func _draw_hearts(origin: Vector2) -> void:
	var max_h: int = clampi(Lx.state.max_hearts, 4, 12)
	var cur_h: float = clampf(Lx.state.hearts, 0.0, float(max_h))
	var per_row: int = 6
	for i: int in range(max_h):
		var col: int = i % per_row
		var row: int = i / per_row
		var pos: Vector2 = origin + Vector2(float(col * 7), float(row * 7) - (1.0 if (_heart_pop_t > 0.0 and i == maxi(0, ceili(cur_h) - 1)) else 0.0))
		draw_rect(Rect2(pos - Vector2.ONE, Vector2(7.0, 7.0)), LxPalette.PAL["night"])
		for r: Rect2 in HEART_PIXELS:
			draw_rect(Rect2(pos + r.position, r.size), LxPalette.PAL["plum"])
		var fill_amt: float = cur_h - float(i)
		if fill_amt >= 0.75:
			for r: Rect2 in HEART_PIXELS:
				draw_rect(Rect2(pos + r.position, r.size), LxPalette.PAL["coral"])
			draw_rect(Rect2(pos + Vector2(1.0, 1.0), Vector2(1.0, 1.0)), LxPalette.PAL["rose"])
		elif fill_amt >= 0.25:
			for r: Rect2 in HALF_HEART_PIXELS:
				draw_rect(Rect2(pos + r.position, r.size), LxPalette.PAL["coral"])
	if cur_h > 0.0 and cur_h <= 1.0 and fmod(_blink_t, 0.6) < 0.35:
		var warn_y: float = origin.y + (15.0 if max_h > per_row else 8.0)
		LxPixelFont.draw_left(self, LxStrings.text("HUD_LAST_HEART"), Vector2(origin.x, warn_y), LxPalette.PAL["coral"], 1)


func _draw_beacon_gauge(cx: float, y: float) -> void:
	var lit_count: int = _count_island_beacons(Lx.state.island_id)
	var spacing: float = 11.0
	var start_x: float = roundf(cx - spacing)
	for i: int in range(3):
		var p: Vector2 = Vector2(start_x + float(i) * spacing - 2.0, y)
		var is_lit: bool = i < lit_count
		draw_rect(Rect2(p - Vector2.ONE, Vector2(7.0, 9.0)), LxPalette.PAL["night"])
		var glass_col: Color = LxPalette.PAL["gold"] if is_lit else LxPalette.PAL["dusk"]
		var frame_col: Color = LxPalette.PAL["apricot"] if is_lit else LxPalette.PAL["mauve"]
		draw_rect(Rect2(p + Vector2(1.0, 2.0), Vector2(3.0, 4.0)), glass_col)
		if is_lit:
			draw_rect(Rect2(p + Vector2(2.0, 3.0), Vector2(1.0, 2.0)), LxPalette.PAL["cream"])
		for r: Rect2 in LANTERN_FRAME:
			draw_rect(Rect2(p + r.position, r.size), frame_col)


func _draw_shards_and_keys(top_right: Vector2) -> bool:
	var shard_str: String = LxStrings.fmt("HUD_SHARDS_FMT", [Lx.state.shards])
	var tw: float = float(LxPixelFont.width(shard_str, 1))
	var icon_x: float = top_right.x - tw - 8.0
	var y: float = top_right.y - (1.0 if _shard_pop_t > 0.0 else 0.0)
	draw_rect(Rect2(icon_x, y - 1.0, 5.0, 7.0), LxPalette.PAL["night"])
	draw_rect(Rect2(icon_x + 2.0, y, 1.0, 5.0), LxPalette.PAL["cream"] if _shard_pop_t > 0.0 else LxPalette.PAL["gold"])
	draw_rect(Rect2(icon_x + 1.0, y + 1.0, 3.0, 3.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(icon_x + 2.0, y + 1.0, 1.0, 2.0), LxPalette.PAL["cream"])
	LxPixelFont.draw_right(self, shard_str, top_right.x, y, LxPalette.PAL["cream"] if _shard_pop_t > 0.0 else LxPalette.PAL["gold"], 1)
	if Lx.state.region_id != "overworld" or not Lx.state.room_id.is_empty():
		var dung_id: String = str(Lx.get_island_data(Lx.state.island_id).get("dungeon_id", ""))
		var keys: int = (Lx.state.get_key_count(dung_id, "wick_key") + Lx.state.get_key_count(dung_id, "keepers_flame")) if not dung_id.is_empty() else 0
		if keys > 0:
			LxPixelFont.draw_right(self, LxStrings.fmt("HUD_KEYS_FMT", [keys]), top_right.x, top_right.y + 9.0, LxPalette.PAL["apricot"], 1)
			return true
	return false


func _draw_moves_tray(origin: Vector2) -> void:
	if Lx.data_moves.is_empty():
		Lx.load_all_data()
	var order: Array = Lx.data_moves.get("order", []) as Array
	var unlocked: Array[String] = []
	for item: Variant in order:
		var mid: String = str(item)
		if Lx.state.has_move(mid):
			unlocked.append(mid)
	var step_x: float = 17.0
	var slot_x: float = origin.x
	var pulse_fast: bool = fmod(_blink_t, 0.44) < 0.22
	var lan_v: Variant = Lx.player.get("lantern") if Lx.player != null else null
	var lan_stolen: bool = lan_v is Object and int((lan_v as Object).get("state")) == 4
	var dash_v: Variant = Lx.player.get("move_dash") if Lx.player != null else null
	var dash_cd: float = float((dash_v as Object).get("cooldown_left")) if dash_v is Object else 0.0
	var ember_ready: bool = _ember_val >= _ember_max - 0.001
	for mid: String in unlocked:
		var mdata: Dictionary = Lx.get_move_data(mid)
		var is_passive: bool = bool(mdata.get("passive", false))
		var action_id: String = str(mdata.get("action", ""))
		var col_name: String = str(MOVE_COLORS.get(mid, "gold"))
		var bdr_col: String = col_name
		if mid == "dash" and dash_cd > 0.02: bdr_col = "dusk"
		elif mid == "sunflare" and ember_ready: bdr_col = "cream" if pulse_fast else "gold"
		elif mid == "throw" and lan_stolen: bdr_col = "coral" if pulse_fast else "wine"
		var box := Rect2(slot_x, origin.y, 13.0, 11.0)
		LxPixelFont.draw_panel(self, box, "night", bdr_col, "void")
		_draw_move_icon(mid, box.position + Vector2(3.0, 2.0), LxPalette.PAL["mauve"] if (mid == "dash" and dash_cd > 0.02) else LxPalette.color(col_name))
		if mid == "dash" and dash_cd > 0.02:
			var frac: float = clampf(1.0 - dash_cd / maxf(0.15, Lx.state.get_effective_dash_cooldown() + 0.17), 0.0, 1.0)
			draw_rect(Rect2(slot_x + 2.0, origin.y + 9.0, floorf(9.0 * frac), 1.0), LxPalette.PAL["coral"])
		if not is_passive and not action_id.is_empty() and Lx.input != null:
			var raw_glyph: String = Lx.input.get_glyph(action_id).to_upper().replace("SHIFT", "SHFT")
			var glyph: String = LxStrings.sanitize(raw_glyph, 4)
			LxPixelFont.draw_centered(self, glyph, slot_x + 6.5, origin.y + 12.0, LxPalette.PAL["stone"], 1)
		else:
			draw_rect(Rect2(slot_x + 5.0, origin.y + 13.0, 3.0, 2.0), LxPalette.color(col_name))
		slot_x += step_x


func _draw_zip_cue(origin: Vector2) -> void:
	if not Lx.state.has_move("throw") or Lx.player == null:
		return
	var lantern_obj: Variant = Lx.player.get("lantern")
	if lantern_obj == null or not (lantern_obj is Object):
		return
	if not (lantern_obj as Object).has_method("is_lure_active") or not bool((lantern_obj as Object).call("is_lure_active")):
		return
	var glyph: String = LxStrings.sanitize(Lx.input.get_glyph("lx_fire"), 6) if Lx.input != null else "-"
	var txt: String = LxStrings.fmt("HUD_ZIP_CUE", [glyph])
	var w: float = float(LxPixelFont.width(txt, 1)) + 8.0
	LxPixelFont.draw_panel(self, Rect2(origin, Vector2(w, 9.0)), "dusk", "gold", "night")
	LxPixelFont.draw_left(self, txt, origin + Vector2(4.0, 2.0), LxPalette.PAL["gold"], 1)


func _draw_move_icon(move_id: String, at: Vector2, col: Color) -> void:
	match move_id:
		"bolt":
			draw_rect(Rect2(at + Vector2(1.0, 2.0), Vector2(5.0, 2.0)), col)
			draw_rect(Rect2(at + Vector2(4.0, 1.0), Vector2(2.0, 4.0)), LxPalette.PAL["cream"])
		"dash":
			draw_rect(Rect2(at + Vector2(0.0, 2.0), Vector2(3.0, 1.0)), col)
			draw_rect(Rect2(at + Vector2(1.0, 4.0), Vector2(4.0, 1.0)), col)
			draw_rect(Rect2(at + Vector2(4.0, 1.0), Vector2(2.0, 5.0)), LxPalette.PAL["cream"])
		"throw":
			draw_rect(Rect2(at + Vector2(2.0, 1.0), Vector2(3.0, 5.0)), col)
			draw_rect(Rect2(at + Vector2(3.0, 2.0), Vector2(1.0, 3.0)), LxPalette.PAL["cream"])
		"prism":
			draw_rect(Rect2(at + Vector2(3.0, 1.0), Vector2(1.0, 5.0)), col)
			draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(3.0, 3.0)), col)
			draw_rect(Rect2(at + Vector2(3.0, 2.0), Vector2(1.0, 1.0)), LxPalette.PAL["cream"])
		"beam":
			draw_rect(Rect2(at + Vector2(0.0, 2.0), Vector2(7.0, 3.0)), col)
			draw_rect(Rect2(at + Vector2(0.0, 3.0), Vector2(7.0, 1.0)), LxPalette.PAL["gold"])
		"wings":
			draw_rect(Rect2(at + Vector2(0.0, 1.0), Vector2(3.0, 2.0)), col)
			draw_rect(Rect2(at + Vector2(4.0, 1.0), Vector2(3.0, 2.0)), col)
			draw_rect(Rect2(at + Vector2(2.0, 3.0), Vector2(3.0, 2.0)), LxPalette.PAL["cream"])
		"lens":
			draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2(5.0, 5.0)), col)
			draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(3.0, 3.0)), LxPalette.PAL["deep"])
			draw_rect(Rect2(at + Vector2(3.0, 3.0), Vector2(1.0, 1.0)), LxPalette.PAL["cream"])
		"sunflare":
			draw_rect(Rect2(at + Vector2(2.0, 1.0), Vector2(3.0, 5.0)), col)
			draw_rect(Rect2(at + Vector2(1.0, 2.0), Vector2(5.0, 3.0)), col)
			draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(3.0, 3.0)), LxPalette.PAL["cream"])
		_:
			draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(3.0, 3.0)), col)


func _draw_ember_meter(at: Vector2) -> void:
	var bar_w: float = 68.0
	var bar_h: float = 8.0
	var frac: float = clampf(_ember_val / maxf(1.0, _ember_max), 0.0, 1.0)
	var ready: bool = frac >= 0.999
	var border_col: String = "cream" if (ready and fmod(_blink_t, 0.5) < 0.25) else "mauve"
	LxPixelFont.draw_panel(self, Rect2(at, Vector2(bar_w, bar_h)), "night", border_col, "void")
	var inner_w: float = floorf((bar_w - 4.0) * frac)
	if inner_w > 0.0:
		var fill_c: Color = LxPalette.PAL["gold"] if ready else (LxPalette.PAL["apricot"] if frac >= 0.5 else LxPalette.PAL["coral"])
		draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(inner_w, bar_h - 4.0)), fill_c)
		if ready:
			draw_rect(Rect2(at + Vector2(2.0, 2.0), Vector2(inner_w, 1.0)), LxPalette.PAL["cream"])
	var label_id: String = "HUD_EMBER_READY" if ready else "HUD_EMBER"
	var label_col: Color = LxPalette.PAL["gold"] if ready else LxPalette.PAL["stone"]
	LxPixelFont.draw_right(self, LxStrings.text(label_id), at.x + bar_w, at.y - 7.0, label_col, 1)


func _draw_boss_bar() -> void:
	var bar_w: float = 160.0
	var bar_h: float = 8.0
	var hit_jolt: float = (1.0 if fmod(_blink_t, 0.08) < 0.04 else -1.0) if (_boss_trail_hp - _boss_hp) > (_boss_max_hp * 0.015) else 0.0
	var x: float = roundf(160.0 - bar_w * 0.5) + hit_jolt
	var y: float = 14.0
	var resolved_key: String = resolve_boss_name_key(_boss_name_key)
	var name_txt: String = LxStrings.text(resolved_key) if LxStrings.has_id(resolved_key) else LxStrings.sanitize(resolved_key)
	LxPixelFont.draw_centered(self, name_txt, 160.0, 5.0, LxPalette.PAL["gold"], 1)
	if _boss_phase >= 2:
		var pkey: String = "HUD_BOSS_P4" if _boss_phase >= 4 else ("HUD_BOSS_P3" if _boss_phase == 3 else "HUD_BOSS_P2")
		LxPixelFont.draw_right(self, LxStrings.text(pkey), roundf(160.0 + bar_w * 0.5), 5.0, LxPalette.PAL["coral"], 1)
	LxPixelFont.draw_panel(self, Rect2(x, y, bar_w, bar_h), "night", "gold" if _boss_phase >= 2 else "mauve", "void")
	draw_rect(Rect2(x - 1.0, y + 2.0, 2.0, 4.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + bar_w - 1.0, y + 2.0, 2.0, 4.0), LxPalette.PAL["gold"])
	var cur_frac: float = clampf(_boss_hp / maxf(1.0, _boss_max_hp), 0.0, 1.0)
	var trail_w: float = floorf((bar_w - 4.0) * clampf(_boss_trail_hp / maxf(1.0, _boss_max_hp), 0.0, 1.0))
	var cur_w: float = floorf((bar_w - 4.0) * cur_frac)
	if trail_w > 0.0:
		draw_rect(Rect2(x + 2.0, y + 2.0, trail_w, bar_h - 4.0), LxPalette.PAL["apricot"])
		if trail_w > cur_w:
			draw_rect(Rect2(x + 2.0 + cur_w, y + 2.0, minf(2.0, trail_w - cur_w), bar_h - 4.0), LxPalette.PAL["cream"])
	if cur_w > 0.0:
		draw_rect(Rect2(x + 2.0, y + 2.0, cur_w, bar_h - 4.0), LxPalette.PAL["coral"])
		draw_rect(Rect2(x + 2.0, y + 2.0, cur_w, 1.0), LxPalette.PAL["rose"])
	var notches: Array = [0.25, 0.5, 0.75] if resolved_key == "BOSS_HUSH" else ([0.2, 0.5] if resolved_key == "BOSS_BELLKEEPER" else ([0.33, 0.66] if resolved_key in ["BOSS_HERMIT", "BOSS_MATRON", "BOSS_ABBESS", "BOSS_ASTRONOMER", "BOSS_KILNMOTHER", "BOSS_HOLLOW"] else [0.5]))
	for frac: float in notches:
		draw_rect(Rect2(roundf(x + 2.0 + (bar_w - 4.0) * frac), y + 1.0, 1.0, bar_h - 2.0), LxPalette.PAL["gold"] if cur_frac > frac else LxPalette.PAL["dusk"])


func _draw_interact_prompt() -> void:
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return
	if Lx.world == null or not Lx.world.has_method("get_interactables"):
		return
	var items_v: Variant = Lx.world.call("get_interactables")
	if not (items_v is Array):
		return
	var ppos: Vector2 = (Lx.player as Node2D).global_position
	var best_pid: String = ""
	var best_pos: Vector2 = Vector2.ZERO
	var best_d2: float = INF
	for item: Variant in (items_v as Array):
		if item == null or not (item is Object) or not is_instance_valid(item):
			continue
		var obj: Object = item as Object
		if not _prop_bool(obj, "active"):
			continue
		if _prop_bool(obj, "opened") or _prop_bool(obj, "collected") or _prop_bool(obj, "shattered"):
			continue
		if not obj.has_method("get_interact_prompt"):
			continue
		var pid: String = str(obj.call("get_interact_prompt"))
		if pid.is_empty():
			continue
		var it_pos_v: Variant = obj.get("pos")
		var it_pos: Vector2 = (it_pos_v as Vector2) if it_pos_v is Vector2 else ((obj as Node2D).global_position if obj is Node2D else Vector2.ZERO)
		var it_rad: float = float(obj.get("radius")) if obj.get("radius") != null else 14.0
		var reach: float = maxf(24.0, it_rad + 10.0)
		var d2: float = it_pos.distance_squared_to(ppos)
		if d2 <= reach * reach and d2 < best_d2:
			best_d2 = d2
			best_pid = pid
			best_pos = it_pos
	if best_pid.is_empty():
		return
	var label: String = LxStrings.text(best_pid) if LxStrings.has_id(best_pid) else LxStrings.sanitize(best_pid)
	if label.is_empty():
		return
	var glyph: String = "-"
	if Lx.input != null:
		var raw_g: String = LxStrings.sanitize(Lx.input.get_glyph("lx_interact"), 6)
		if not raw_g.is_empty():
			glyph = raw_g
	var txt: String = LxStrings.fmt("HUD_KEY_PROMPT_FMT", [glyph, label])
	var w: float = float(LxPixelFont.width(txt, 1)) + 8.0
	var h: float = 11.0
	var sp: Vector2 = _world_to_screen(best_pos) + Vector2(0.0, -24.0)
	var half_w: float = w * 0.5
	var cx: float = clampf(sp.x, 8.0 + half_w, 312.0 - half_w)
	var py: float = clampf(sp.y - h * 0.5, 18.0, 146.0 - h)
	var rect := Rect2(roundf(cx - half_w), roundf(py), w, h)
	LxPixelFont.draw_panel(self, rect, "dusk", "gold", "night")
	LxPixelFont.draw_centered(self, txt, rect.position.x + w * 0.5, rect.position.y + 3.0, LxPalette.PAL["cream"], 1)


func _draw_cues() -> void:
	for cue: Dictionary in _cues:
		var t: float = float(cue["t"])
		var dur: float = float(cue["dur"])
		var fade_p: float = minf(t / 0.15, (dur - t) / 0.35)
		var col: Color = LxPalette.fade_step(fade_p, str(cue["color"]))
		if col.a <= 0.0:
			continue
		var screen_pos: Vector2 = cue["pos"] as Vector2
		if bool(cue["is_world"]):
			screen_pos = _world_to_screen(screen_pos)
		screen_pos.y -= floorf(t * 14.0)
		screen_pos.x = clampf(screen_pos.x, 24.0, 296.0)
		screen_pos.y = clampf(screen_pos.y, 16.0, 168.0)
		LxPixelFont.draw_centered(self, str(cue["text"]), screen_pos.x, screen_pos.y, col, 1)


func _draw_notice() -> void:
	if _notice_text.is_empty():
		return
	var p: float = minf(_notice_t / 0.18, (_notice_dur - _notice_t) / 0.30)
	var col: Color = LxPalette.fade_step(maxf(p, 0.52) if _notice_t < 0.2 else p, "gold")
	if col.a <= 0.0:
		return
	var w: float = float(LxPixelFont.width(_notice_text, 1)) + 12.0
	var ny: float = 26.0 if _boss_active else 18.0
	var rect := Rect2(roundf(160.0 - w * 0.5), ny, w, 11.0)
	LxPixelFont.draw_panel(self, rect, "night", "gold", "void")
	LxPixelFont.draw_centered(self, _notice_text, 160.0, ny + 3.0, col, 1)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	if Lx.camera != null:
		return world_pos - Lx.camera.global_position + Vector2(160.0, 90.0)
	return world_pos


func _count_island_beacons(island_id: int) -> int:
	var p1: String = "isl%d_" % island_id
	var p2: String = "%d:" % island_id
	var p3: String = "beacon_%d_" % island_id
	var p4: String = "beacon_isl%d_" % island_id
	var count: int = 0
	for bid: String in Lx.state.lit_beacons:
		if bid.begins_with(p1) or bid.begins_with(p2) or bid.begins_with(p3) or bid.begins_with(p4) or (island_id == 1 and bid in ["beacon_orchard", "beacon_observatory", "beacon_bridge"]):
			count += 1
	return mini(count, 3)


static func _prop_bool(obj: Object, prop: String) -> bool:
	var v: Variant = obj.get(prop)
	return v is bool and bool(v)
