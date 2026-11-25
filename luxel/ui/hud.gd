class_name LxHud
extends Node2D
## Gameplay HUD (320x180, Last Light palette): hearts (4..12), 3-lantern beacon gauge,
## unlocked move icons with dynamic input glyphs, ember meter, shard/key counters,
## boss health bar, and floating world cues.

const HEART_PIXELS: Array[Rect2] = [Rect2(1.0, 0.0, 1.0, 1.0), Rect2(3.0, 0.0, 1.0, 1.0), Rect2(0.0, 1.0, 5.0, 2.0), Rect2(1.0, 3.0, 3.0, 1.0), Rect2(2.0, 4.0, 1.0, 1.0)]
const HALF_HEART_PIXELS: Array[Rect2] = [Rect2(1.0, 0.0, 1.0, 1.0), Rect2(0.0, 1.0, 3.0, 2.0), Rect2(1.0, 3.0, 2.0, 1.0), Rect2(2.0, 4.0, 1.0, 1.0)]
const LANTERN_FRAME: Array[Rect2] = [Rect2(1.0, 0.0, 3.0, 1.0), Rect2(0.0, 1.0, 5.0, 1.0), Rect2(0.0, 2.0, 1.0, 4.0), Rect2(4.0, 2.0, 1.0, 4.0), Rect2(0.0, 6.0, 5.0, 1.0)]
const MOVE_COLORS: Dictionary = {"bolt": "gold", "dash": "coral", "throw": "apricot", "prism": "sky", "beam": "cream", "wings": "lime", "lens": "ice", "sunflare": "gold"}
const BEACON_CUES: Dictionary = {
	1: "CUE_BEACON_LIT", 2: "CUE_BEACON_LIT_2", 3: "CUE_BEACON_LIT_3", 4: "CUE_BEACON_LIT_4",
	5: "CUE_BEACON_LIT_5", 6: "CUE_BEACON_LIT_6", 7: "CUE_BEACON_LIT_7", 8: "CUE_BEACON_LIT_8",
}
const PHASE2_CUES: Dictionary = {
	1: "CUE_PHASE_2", 2: "CUE_PHASE_2_ISL2", 3: "CUE_PHASE_2_ISL3", 4: "CUE_PHASE_2_ISL4",
	5: "CUE_PHASE_2_ISL5", 6: "CUE_PHASE_2_ISL6", 7: "CUE_PHASE_2_ISL7", 8: "CUE_PHASE_2_ISL8",
}

var _cues: Array[Dictionary] = [] # {text, pos, is_world, color, t, dur}
var _notice_text: String = ""; var _notice_t: float = 0.0; var _notice_dur: float = 3.5

var _boss_active: bool = false; var _boss_name_key: String = ""; var _boss_phase: int = 1
var _boss_hp: float = 0.0; var _boss_max_hp: float = 1.0; var _boss_trail_hp: float = 0.0
var _boss_entries: Array[Dictionary] = [] # [{id, name_key, hp, max_hp, trail_hp, phase}]

var _ember_val: float = 0.0; var _ember_max: float = 100.0
var _blink_t: float = 0.0; var _hit_cue_cd: float = 0.0
var _last_shards: int = -1; var _shard_pop_t: float = 0.0; var _shard_idle_t: float = 5.0
var _moves_idle_t: float = 0.0; var _last_hearts: float = -1.0; var _heart_pop_t: float = 0.0
var _zip_cue_alpha: float = 0.0
var _challenge: Dictionary = {"active": false, "kind": "", "limit": 1.0, "rem": 0.0, "frac": 1.0, "state": 0}
var _banner_cooldowns: Dictionary = {} # banner_key -> last_shown_s
var _seen_boss_intros: Dictionary = {} # boss_id -> true
var ceremony: LxHudCeremony = LxHudCeremony.new()
var _bound: bool = false; var _bound_events: Object = null; var _bound_sold: Object = null
var _sim_tick_frame: int = -1

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS; bind_events()

func _exit_tree() -> void:
	if is_instance_valid(_bound_events):
		for p: Array in [[_bound_events.beacon_lit, _on_beacon_lit], [_bound_events.waystone_lit, _on_waystone_lit], [_bound_events.move_unlocked, _on_move_unlocked], [_bound_events.boss_phase_changed, _on_boss_phase], [_bound_events.boss_defeated, _on_boss_defeated], [_bound_events.ember_piece_collected, _on_ember_piece], [_bound_events.enemy_hit, _on_enemy_hit], [_bound_events.lantern_stolen, _on_lantern_stolen], [_bound_events.great_lamp_relit, _on_great_lamp_relit]]:
			if (p[0] as Signal).is_connected(p[1] as Callable): (p[0] as Signal).disconnect(p[1] as Callable)
	if is_instance_valid(_bound_sold) and (_bound_sold as LxSold).hud_visibility_changed.is_connected(_on_hud_visibility_changed):
		(_bound_sold as LxSold).hud_visibility_changed.disconnect(_on_hud_visibility_changed)
	_bound = false; _bound_events = null; _bound_sold = null

func bind_events() -> void:
	if _bound or Lx.events == null: return
	_bound = true; _bound_events = Lx.events; _bound_sold = LxSold.current()
	var pairs: Array = [
		[Lx.events.beacon_lit, _on_beacon_lit], [Lx.events.waystone_lit, _on_waystone_lit],
		[Lx.events.move_unlocked, _on_move_unlocked], [Lx.events.boss_phase_changed, _on_boss_phase],
		[Lx.events.boss_defeated, _on_boss_defeated], [Lx.events.ember_piece_collected, _on_ember_piece],
		[Lx.events.enemy_hit, _on_enemy_hit], [Lx.events.lantern_stolen, _on_lantern_stolen],
		[Lx.events.great_lamp_relit, _on_great_lamp_relit],
		[(_bound_sold as LxSold).hud_visibility_changed, _on_hud_visibility_changed],
	]
	for p: Array in pairs:
		var sig: Signal = p[0] as Signal
		var cb: Callable = p[1] as Callable
		if not sig.is_connected(cb): sig.connect(cb)

func _on_hud_visibility_changed(_flags: Dictionary) -> void: queue_redraw()

func set_ember(current: float, maximum: float) -> void:
	_ember_max = maxf(1.0, maximum); _ember_val = clampf(current, 0.0, _ember_max); queue_redraw()

static func resolve_boss_name_key(boss_id_or_key: String) -> String:
	return LxBossHud.resolve_name_key(boss_id_or_key)

func show_boss(name_key: String, hp: float, max_hp: float, phase: int = 1) -> void:
	var was_active: bool = _boss_active
	_boss_active = true
	_boss_name_key = resolve_boss_name_key(name_key)
	_boss_max_hp = maxf(1.0, max_hp)
	_boss_hp = clampf(hp, 0.0, _boss_max_hp)
	_boss_trail_hp = _boss_hp
	_boss_phase = maxi(1, phase)
	_boss_entries = [{"id": name_key, "name_key": _boss_name_key, "hp": _boss_hp, "max_hp": _boss_max_hp, "trail_hp": _boss_trail_hp, "phase": _boss_phase}]
	if not was_active and not _seen_boss_intros.has(name_key):
		_seen_boss_intros[name_key] = true
		ceremony.trigger_boss_intro(name_key, _boss_name_key, maxi(2, phase))
	_check_hollow_twist(_boss_name_key)
	queue_redraw()

func sync_bosses(live_bosses: Array) -> void:
	if live_bosses.is_empty():
		hide_boss(); return
	var was_active: bool = _boss_active
	var prev_trails: Dictionary = {}
	for pe: Dictionary in _boss_entries:
		var tk: String = str(pe.get("iid", pe.get("id", "")))
		prev_trails[tk] = float(pe.get("trail_hp", pe.get("hp", 0.0)))
	var next_list: Array[Dictionary] = []
	for item: Variant in live_bosses:
		if not is_instance_valid(item) or not (item is LxEnemyBrain): continue
		var b: LxEnemyBrain = item as LxEnemyBrain
		var bid: String = b.boss_id if not b.boss_id.is_empty() else b.kind
		var iid: String = str(b.get_instance_id())
		var nk: String = resolve_boss_name_key(bid)
		var mh: float = maxf(1.0, b.max_hp)
		var ch: float = clampf(b.hp, 0.0, mh)
		var tr: float = clampf(float(prev_trails.get(iid, prev_trails.get(bid, ch))), ch, mh)
		next_list.append({"id": bid, "iid": iid, "name_key": nk, "hp": ch, "max_hp": mh, "trail_hp": tr, "phase": maxi(1, b.phase)})
		_check_hollow_twist(nk)
		if next_list.size() >= 2: break
	if next_list.is_empty(): hide_boss(); return
	_boss_entries = next_list
	_boss_active = true
	var b0: Dictionary = _boss_entries[0]
	_boss_name_key = str(b0["name_key"]); _boss_hp = float(b0["hp"]); _boss_max_hp = float(b0["max_hp"])
	_boss_trail_hp = float(b0["trail_hp"]); _boss_phase = int(b0["phase"])
	var b0_id: String = str(b0["id"])
	if not was_active and not _seen_boss_intros.has(b0_id):
		_seen_boss_intros[b0_id] = true
		ceremony.trigger_boss_intro(b0_id, _boss_name_key, maxi(2, _boss_phase))
	queue_redraw()

func _check_hollow_twist(nk: String) -> void:
	if nk == "BOSS_HOLLOW" and Lx.state != null \
			and not bool(Lx.state.story_flags.get("twist_hollow_shown", false)) \
			and not bool(Lx.state.story_flags.get("trig_7_overworld_trig_twist_hollow_1", false)):
		Lx.state.story_flags["twist_hollow_shown"] = true
		if Lx.events != null: Lx.events.narration_requested.emit("TWIST_HOLLOW", "ice", 4.0)

func update_boss(hp: float, max_hp: float, phase: int = -1) -> void:
	_boss_max_hp = maxf(1.0, max_hp); _boss_hp = clampf(hp, 0.0, _boss_max_hp)
	if phase > 0: _boss_phase = phase
	if not _boss_entries.is_empty():
		_boss_entries[0]["hp"] = _boss_hp; _boss_entries[0]["max_hp"] = _boss_max_hp; _boss_entries[0]["phase"] = _boss_phase
	queue_redraw()

func hide_boss() -> void: _boss_active = false; _boss_entries.clear(); queue_redraw()
func show_challenge_timer(kind: String, time_limit: float) -> void:
	_challenge = {"active": true, "kind": kind, "limit": maxf(0.1, time_limit), "rem": time_limit, "frac": 1.0, "state": 0}; queue_redraw()
func update_challenge_timer(rem: float, frac: float, state: int) -> void:
	_challenge["active"] = true; _challenge["rem"] = rem; _challenge["frac"] = frac; _challenge["state"] = state; queue_redraw()
func hide_challenge_timer() -> void: _challenge["active"] = false; queue_redraw()

func show_notice(string_id: String, duration: float = 3.5, force: bool = false) -> void:
	var is_region_banner: bool = string_id.begins_with("ZONE_") or string_id.begins_with("DUNGEON_") or string_id.begins_with("REGION_") or string_id.begins_with("HUB_")
	if is_region_banner and not force:
		var last_t: float = float(_banner_cooldowns.get(string_id, -999.0))
		if (_blink_t - last_t) < 60.0:
			return
		_banner_cooldowns[string_id] = _blink_t
	_notice_text = LxStrings.text(string_id); _notice_t = 0.0; _notice_dur = maxf(duration, 1.0); queue_redraw()
	if string_id.begins_with("ZONE_") and Lx.ui != null:
		var nar: Object = Lx.ui.get("narration") as Object
		if nar != null and is_instance_valid(nar) and nar.has_method("clear_overworld_caption"): nar.call("clear_overworld_caption")

func show_reward_ceremony(icon_id: String, title_id: String, accent_col: String = "gold", sub_icons: Array[String] = []) -> void:
	ceremony.trigger_reward(icon_id, title_id, accent_col, sub_icons); queue_redraw()

func show_previously_bar(icons: Array[String]) -> void:
	ceremony.trigger_previously(icons); queue_redraw()

func try_skip_ceremony(event: InputEvent) -> bool:
	if ceremony.try_skip(event):
		queue_redraw(); return true
	return false

func reset_session_banners() -> void:
	_banner_cooldowns.clear(); _seen_boss_intros.clear(); ceremony.reset()

func spawn_world_cue(string_id: String, world_pos: Vector2, color_name: String = "gold", duration: float = 1.4, args: Array = []) -> void:
	var txt: String = LxStrings.fmt(string_id, args) if not args.is_empty() else LxStrings.text(string_id)
	if _cues.size() >= 16: _cues.remove_at(0)
	_cues.append({"text": txt, "pos": world_pos, "is_world": true, "color": color_name, "t": 0.0, "dur": maxf(duration, 0.4)})
	queue_redraw()

func spawn_screen_cue(string_id: String, screen_pos: Vector2, color_name: String = "gold", duration: float = 1.4, args: Array = []) -> void:
	var txt: String = LxStrings.fmt(string_id, args) if not args.is_empty() else LxStrings.text(string_id)
	var kept: Array[Dictionary] = []
	for c: Dictionary in _cues:
		if bool(c["is_world"]) or absf((c["pos"] as Vector2).y - screen_pos.y) > 14.0: kept.append(c)
	_cues = kept
	if _cues.size() >= 16: _cues.remove_at(0)
	_cues.append({"text": txt, "pos": screen_pos, "is_world": false, "color": color_name, "t": 0.0, "dur": maxf(duration, 0.4)})
	queue_redraw()

func clear_cues() -> void: _cues.clear(); _notice_text = ""; _notice_t = 0.0; _challenge["active"] = false; _zip_cue_alpha = 0.0; queue_redraw()

func _on_beacon_lit(island_id: int, _beacon_id: String) -> void:
	var ck: String = str(BEACON_CUES.get(island_id, "CUE_BEACON_LIT"))
	spawn_screen_cue(ck, Vector2(160.0, 34.0), LxBiomePalette.key(island_id, "glow"), 1.8)

func _on_waystone_lit(island_id: int, _waystone_id: String) -> void:
	spawn_screen_cue("CUE_WAYSTONE_LIT", Vector2(160.0, 34.0), LxBiomePalette.key(island_id, "glow"), 1.6)

func _on_move_unlocked(move_id: String) -> void:
	if not _has_lantern(): return
	if move_id == "throw" and Lx.state != null and Lx.state.island_id == 1 and not Lx.state.has_move("dash"): return
	var name_key: String = str(Lx.get_move_data(move_id).get("name_key", "CUE_SHRINE_CLAIMED"))
	if LxHudFx.narration_has_title(): return
	ceremony.trigger_reward("move_" + move_id, name_key, str(MOVE_COLORS.get(move_id, "gold")), ["star"])

func _on_great_lamp_relit(island_id: int) -> void:
	ceremony.trigger_reward("crown", "MAP_DUNGEON_CLEAR", LxBiomePalette.key(island_id, "border"), ["isl_%d" % clampi(island_id, 1, 8), "lantern"])

func _on_boss_phase(boss_id: String, phase: int) -> void:
	if not boss_id.is_empty(): _boss_name_key = resolve_boss_name_key(boss_id)
	_boss_phase = maxi(1, phase)
	if phase >= 2:
		var isl_p: int = Lx.state.island_id if Lx.state != null else 1
		var p2_k: String = str(PHASE2_CUES.get(isl_p, "CUE_PHASE_2"))
		var p_cue: String = ("CUE_HUSH_P4" if phase >= 4 else "CUE_HUSH_P3") if (_boss_name_key == "BOSS_HUSH" and phase >= 3) else ("CUE_PHASE_3" if phase >= 3 else p2_k)
		spawn_screen_cue(p_cue, Vector2(160.0, 126.0), "coral", 1.8)
		if not _cues.is_empty(): _cues[_cues.size() - 1]["boss_callout"] = true

func _on_boss_defeated(boss_id: String, _island_id: int) -> void:
	if _boss_entries.size() > 1 and not boss_id.is_empty():
		var rem: Array[Dictionary] = []
		var removed_one: bool = false
		for be: Dictionary in _boss_entries:
			if not removed_one and str(be.get("id", "")) == boss_id: removed_one = true; continue
			rem.append(be)
		if not rem.is_empty():
			_boss_entries = rem; _boss_name_key = str(rem[0]["name_key"]); _boss_hp = float(rem[0]["hp"])
			_boss_max_hp = float(rem[0]["max_hp"]); _boss_trail_hp = float(rem[0]["trail_hp"]); _boss_phase = int(rem[0]["phase"])
			queue_redraw(); return
	hide_boss()
func _on_ember_piece(_total: int) -> void: spawn_screen_cue("CUE_EMBER_FOUND", Vector2(160.0, 34.0), "apricot", 1.8)

func _on_enemy_hit(enemy: Object, _hit: Object, result: int) -> void:
	if _hit_cue_cd > 0.0 or enemy == null: return
	var wpos: Vector2 = (enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO
	if result == 0:
		_hit_cue_cd = 0.45
		var eats: bool = str(enemy.get("kind")) in ["snatcher", "gull_thief", "mire_snuffer"]
		spawn_world_cue("CUE_EATS_BOLTS" if eats else "CUE_BLOCKED", wpos, "apricot" if eats else "stone", 1.0)
	elif result == 2:
		_hit_cue_cd = 0.35
		spawn_world_cue("CUE_OPEN", wpos, "gold", 1.0)

func _on_lantern_stolen(_thief: Object, pos: Vector2) -> void:
	spawn_world_cue("CUE_LANTERN_STOLEN", pos, "coral", 1.6)


func tick_sim(delta: float) -> void:
	_sim_tick_frame = Engine.get_process_frames(); _tick_hud(delta)

func _process(delta: float) -> void:
	if _sim_tick_frame != Engine.get_process_frames(): _tick_hud(delta)

func _tick_hud(delta: float) -> void:
	if not visible: return
	_blink_t += delta
	_hit_cue_cd = maxf(0.0, _hit_cue_cd - delta)
	_shard_pop_t = maxf(0.0, _shard_pop_t - delta)
	_heart_pop_t = maxf(0.0, _heart_pop_t - delta)
	if Lx.state != null:
		if _last_shards >= 0 and Lx.state.shards != _last_shards:
			_shard_pop_t = 0.28 if Lx.state.shards > _last_shards else 0.0
			_shard_idle_t = 0.0
		else:
			_shard_idle_t += delta
		_last_shards = Lx.state.shards
		if _last_hearts >= 0.0 and not is_equal_approx(Lx.state.hearts, _last_hearts):
			_heart_pop_t = 0.24
			_moves_idle_t = 0.0
		_last_hearts = Lx.state.hearts
	_moves_idle_t = 0.0 if _boss_active else (_moves_idle_t + delta)
	ceremony.tick(delta, _boss_active)
	if _boss_active:
		if _boss_trail_hp > _boss_hp: _boss_trail_hp = maxf(_boss_hp, _boss_trail_hp - _boss_max_hp * 0.45 * delta)
		for be: Dictionary in _boss_entries:
			var b_hp: float = float(be["hp"]); var b_tr: float = float(be["trail_hp"])
			if b_tr > b_hp: be["trail_hp"] = maxf(b_hp, b_tr - float(be["max_hp"]) * 0.45 * delta)
	if not _cues.is_empty():
		var kept: Array[Dictionary] = []
		for cue: Dictionary in _cues:
			cue["t"] = float(cue["t"]) + delta
			if float(cue["t"]) < float(cue["dur"]): kept.append(cue)
		_cues = kept
	if not _notice_text.is_empty():
		_notice_t += delta
		if _notice_t >= _notice_dur: _notice_text = ""
	var want_zip: bool = not _boss_active and _has_lantern() and Lx.state != null and Lx.state.has_move("throw") and Lx.player != null
	if want_zip:
		var lo: Variant = Lx.player.get("lantern")
		want_zip = lo is Object and (lo as Object).has_method("is_lure_active") and bool((lo as Object).call("is_lure_active"))
	_zip_cue_alpha = clampf(_zip_cue_alpha + (delta * 7.5 if want_zip else -delta * 5.5), 0.0, 1.0)
	_sync_player_ember()
	LxHudFx.sync_reticle_visibility(self)
	queue_redraw()

func _sync_player_ember() -> void:
	if Lx.state == null or not Lx.state.has_move("sunflare"): return
	_ember_max = maxf(1.0, Lx.state.get_effective_ember_max())
	if Lx.player != null and Lx.player.has_method("get_ember"):
		_ember_val = clampf(float(Lx.player.call("get_ember")), 0.0, _ember_max)

func _draw() -> void:
	if Lx.state == null: return
	LxHudFx.sync_reticle_visibility(self)
	var vis: Dictionary = LxSold.current().get_hud_visibility()
	var show_hearts: bool = bool(vis.get("show_hearts", true))
	var show_minimap: bool = bool(vis.get("show_minimap", true))
	var show_ember: bool = bool(vis.get("show_ember", true))
	var notice_col: Color = _notice_color()
	var notice_r: Rect2 = _compute_notice_rect() if notice_col.a > 0.0 else Rect2()
	if show_hearts: _draw_hearts(Vector2(5.0, 5.0))
	LxHudOverlays.draw_temper_mark(self, Vector2(5.0, 5.0), clampi(Lx.state.max_hearts, 4, 12), show_hearts)
	var in_dng: bool = Lx.world != null and bool(Lx.world.get("is_dungeon"))
	var show_beacon: bool = not _boss_active and not in_dng and Lx.state.island_id > 0 and _notice_text.is_empty() and not LxHudFx.is_ceremony_active()
	if show_beacon: _draw_beacon_gauge(160.0, 4.0)
	if bool(_challenge.get("active", false)):
		LxHudOverlays.draw_challenge_timer(self, _challenge, _blink_t, 16.0 if (show_beacon or notice_r.has_area()) else 4.0)
	var keys_shown: bool = _draw_shards_and_keys(Vector2(315.0, 5.0))
	_draw_moves_tray(Vector2(5.0, 160.0))
	if not _boss_active: _draw_zip_cue(Vector2(5.0, 148.0))
	if show_minimap and Lx.world != null and not _boss_active:
		var mm_o := Vector2(263.0, 22.0 if keys_shown else 16.0)
		var mg: String = LxStrings.sanitize(Lx.input.get_glyph("lx_map"), 6) if Lx.input != null else "-"
		var mw: float = float(LxPixelFont.width(LxStrings.fmt("HUD_MAP_HINT", [mg if not mg.is_empty() else "-"]), 1))
		draw_rect(Rect2(mm_o.x + 50.0 - mw, mm_o.y + 30.0, mw + 4.0, 9.0), Color(LxPalette.PAL["void"] as Color, 0.72))
		LxMinimap.draw_minimap(self, mm_o, _blink_t)
	if show_ember and Lx.state.has_move("sunflare"): _draw_ember_meter(Vector2(246.0, 166.0))
	if _boss_active: _draw_boss_bar()
	var prompt_r: Rect2 = _draw_interact_prompt(notice_r)
	LxHudFx.draw_cues(self, _cues, prompt_r, notice_r)
	if notice_r.has_area(): _draw_notice(notice_r, notice_col)
	LxHudFx.draw_indicators(self, _blink_t, _boss_active, _boss_phase)
	ceremony.draw(self)

func _draw_hearts(origin: Vector2) -> void:
	var max_h: int = clampi(Lx.state.max_hearts, 4, 12); var cur_h: float = clampf(Lx.state.hearts, 0.0, float(max_h))
	for i: int in range(max_h):
		var pos: Vector2 = origin + Vector2(float((i % 6) * 7), float((i / 6) * 7) - (1.0 if (_heart_pop_t > 0.0 and i == maxi(0, ceili(cur_h) - 1)) else 0.0))
		draw_rect(Rect2(pos - Vector2.ONE, Vector2(7.0, 7.0)), LxPalette.PAL["night"])
		for r: Rect2 in HEART_PIXELS: draw_rect(Rect2(pos + r.position, r.size), LxPalette.PAL["plum"])
		var fill_amt: float = cur_h - float(i)
		if fill_amt >= 0.75:
			for r: Rect2 in HEART_PIXELS: draw_rect(Rect2(pos + r.position, r.size), LxPalette.PAL["coral"])
			draw_rect(Rect2(pos + Vector2(1.0, 1.0), Vector2(1.0, 1.0)), LxPalette.PAL["rose"])
		elif fill_amt >= 0.25:
			for r: Rect2 in HALF_HEART_PIXELS: draw_rect(Rect2(pos + r.position, r.size), LxPalette.PAL["coral"])
	LxHudOverlays.draw_heart_extras(self, origin, max_h, _blink_t)
	if cur_h > 0.0 and cur_h <= 1.0 and (LxHudFx.flash_reduced() or fmod(_blink_t, 0.6) < 0.35):
		var lh_x: float = origin.x + float(mini(max_h, 6)) * 7.0 + 3.0
		var has_top_extra: bool = Lx.state.half_lanterns > 0 or (Lx.state.get_upgrade_rank("spare_wick") > 0 and Lx.state.is_spare_wick_allowed())
		var lh_y: float = origin.y + (8.0 if has_top_extra else 0.0)
		LxPixelFont.draw_left(self, LxStrings.text("HUD_LAST_HEART"), Vector2(lh_x, lh_y), LxPalette.PAL["coral"], 1)


func _draw_beacon_gauge(cx: float, y: float) -> void:
	LxHudOverlays.draw_beacon_gauge(self, cx, y, Lx.state.island_id, _count_island_beacons(Lx.state.island_id), LANTERN_FRAME)

func _draw_shards_and_keys(top_right: Vector2) -> bool:
	var shard_str: String = LxStrings.fmt("HUD_SHARDS_FMT", [Lx.state.shards])
	var tw: float = float(LxPixelFont.width(shard_str, 1))
	var icon_x: float = top_right.x - tw - 8.0
	var y: float = top_right.y - (1.0 if _shard_pop_t > 0.0 else 0.0)
	var shard_dim: bool = _shard_idle_t > 4.0 and _shard_pop_t <= 0.0
	draw_rect(Rect2(icon_x - 2.0, y - 2.0, tw + 12.0, 9.0), Color(LxPalette.PAL["void"] as Color, 0.45 if shard_dim else 0.72))
	draw_rect(Rect2(icon_x, y - 1.0, 5.0, 7.0), LxPalette.PAL["night"])
	draw_rect(Rect2(icon_x + 2.0, y, 1.0, 5.0), LxPalette.PAL["cream"] if _shard_pop_t > 0.0 else (LxPalette.PAL["apricot"] if shard_dim else LxPalette.PAL["gold"]))
	draw_rect(Rect2(icon_x + 1.0, y + 1.0, 3.0, 3.0), LxPalette.PAL["apricot"] if shard_dim else LxPalette.PAL["gold"])
	draw_rect(Rect2(icon_x + 2.0, y + 1.0, 1.0, 2.0), LxPalette.PAL["stone"] if shard_dim else LxPalette.PAL["cream"])
	LxPixelFont.draw_right(self, shard_str, top_right.x, y, LxPalette.PAL["cream"] if _shard_pop_t > 0.0 else (LxPalette.PAL["stone"] if shard_dim else LxPalette.PAL["gold"]), 1)
	if Lx.state.region_id != "overworld" or not Lx.state.room_id.is_empty():
		var dung_id: String = Lx.packs.dungeon_of(Lx.state.island_id, Lx.state.region_id) if Lx.packs != null else ""
		if dung_id.is_empty(): dung_id = str(Lx.get_island_data(Lx.state.island_id).get("dungeon_id", ""))
		if not dung_id.is_empty():
			return LxHudOverlays.draw_dungeon_keys(self, top_right, Lx.state.get_key_count(dung_id, "wick_key"), Lx.state.get_key_count(dung_id, "keepers_flame"))
	return false


func _draw_moves_tray(origin: Vector2) -> void:
	if not _has_lantern(): return
	if Lx.data_moves.is_empty(): Lx.load_all_data()
	var order: Array = Lx.data_moves.get("order", []) as Array
	var unlocked: Array[String] = []
	for item: Variant in order:
		var mid: String = str(item)
		if Lx.state.has_move(mid): unlocked.append(mid)
	var step_x: float = 21.0
	var slot_x: float = origin.x
	var pulse_fast: bool = LxHudFx.flash_reduced() or fmod(_blink_t, 0.44) < 0.22
	var lan_v: Variant = Lx.player.get("lantern") if Lx.player != null else null
	var lan_stolen: bool = lan_v is Object and int((lan_v as Object).get("state")) == 4
	var dash_v: Variant = Lx.player.get("move_dash") if Lx.player != null else null
	var dash_cd: float = float((dash_v as Object).get("cooldown_left")) if dash_v is Object else 0.0
	var beam_v: Variant = Lx.player.get("move_beam") if Lx.player != null else null
	var beam_cd: float = float((beam_v as Object).get("cooldown_left")) if beam_v is Object else 0.0
	var lens_v: Variant = Lx.player.get("move_lens") if Lx.player != null else null
	var lens_active: bool = lens_v is Object and (lens_v as Object).has_method("is_pulse_active") and bool((lens_v as Object).call("is_pulse_active"))
	var lens_warn: bool = lens_v is Object and (lens_v as Object).has_method("is_warning") and bool((lens_v as Object).call("is_warning"))
	var lens_ratio: float = float((lens_v as Object).call("get_pulse_ratio")) if (lens_v is Object and (lens_v as Object).has_method("get_pulse_ratio")) else 0.0
	var lens_cd: float = float((lens_v as Object).get("cooldown_left")) if lens_v is Object else 0.0
	var wings_v: Variant = Lx.player.get("move_wings") if Lx.player != null else null
	var wings_gliding: bool = wings_v is Object and bool((wings_v as Object).get("gliding"))
	var wings_frac: float = clampf(float((wings_v as Object).get("glide_time_left")) / maxf(0.05, float((wings_v as Object).get("glide_duration"))), 0.0, 1.0) if wings_gliding else 0.0
	var ember_ready: bool = _ember_val >= _ember_max - 0.001
	if not unlocked.is_empty():
		draw_rect(Rect2(origin.x - 1.0, origin.y + 11.0, float(unlocked.size()) * step_x - 2.0, 7.0), Color(LxPalette.PAL["void"] as Color, 0.62))
	for mid: String in unlocked:
		var mdata: Dictionary = Lx.get_move_data(mid)
		var is_passive: bool = bool(mdata.get("passive", false))
		var action_id: String = str(mdata.get("action", ""))
		var col_name: String = str(MOVE_COLORS.get(mid, "gold"))
		var bdr_col: String = col_name
		var icon_col: Color = LxPalette.color(col_name)
		var is_locked: bool = Lx.player != null and Lx.player.has_method("is_move_locked") and bool(Lx.player.call("is_move_locked", mid))
		if is_locked:
			bdr_col = "wine"; icon_col = LxPalette.PAL["mauve"]
		elif (mid == "dash" and dash_cd > 0.02) or (mid == "beam" and beam_cd > 0.02):
			bdr_col = "dusk"; icon_col = LxPalette.PAL["mauve"]
		elif mid == "wings" and wings_gliding:
			bdr_col = "cream" if pulse_fast else "ice"; icon_col = LxPalette.PAL["ice"]
		elif mid == "lens":
			if lens_active:
				bdr_col = ("coral" if pulse_fast else "ice") if lens_warn else ("cream" if pulse_fast else "ice")
				icon_col = LxPalette.PAL["coral"] if (lens_warn and pulse_fast) else LxPalette.PAL["ice"]
			elif lens_cd > 0.02:
				bdr_col = "dusk"; icon_col = LxPalette.PAL["mauve"]
		elif mid == "sunflare" and ember_ready: bdr_col = "cream" if pulse_fast else "gold"
		elif mid == "throw" and lan_stolen: bdr_col = "coral" if pulse_fast else "wine"
		var box := Rect2(slot_x, origin.y, 13.0, 11.0)
		LxPixelFont.draw_panel(self, box, "night", bdr_col, "void")
		_draw_move_icon(mid, box.position + Vector2(3.0, 2.0), icon_col)
		if is_locked:
			LxHudOverlays.draw_locked_move_badge(self, box)
		elif mid == "dash" and dash_cd > 0.02:
			var frac: float = clampf(1.0 - dash_cd / maxf(0.15, Lx.state.get_effective_dash_cooldown() + 0.17), 0.0, 1.0)
			draw_rect(Rect2(slot_x + 2.0, origin.y + 9.0, floorf(9.0 * frac), 1.0), LxPalette.PAL["coral"])
		elif mid == "beam" and beam_cd > 0.02:
			var bfrac: float = clampf(1.0 - beam_cd / maxf(0.1, float(mdata.get("cooldown", 0.45))), 0.0, 1.0)
			draw_rect(Rect2(slot_x + 2.0, origin.y + 9.0, floorf(9.0 * bfrac), 1.0), LxPalette.PAL["gold"])
		elif mid == "wings" and wings_gliding:
			draw_rect(Rect2(slot_x + 2.0, origin.y + 9.0, maxf(1.0, floorf(9.0 * wings_frac)), 1.0), LxPalette.PAL["coral"] if wings_frac < 0.28 else LxPalette.PAL["ice"])
		elif mid == "lens":
			if lens_active:
				draw_rect(Rect2(slot_x + 2.0, origin.y + 9.0, maxf(1.0, floorf(9.0 * lens_ratio)), 1.0), LxPalette.PAL["coral"] if (lens_warn and pulse_fast) else LxPalette.PAL["ice"])
			elif lens_cd > 0.02:
				var lfrac: float = clampf(1.0 - lens_cd / maxf(0.1, float(mdata.get("cooldown", 6.0))), 0.0, 1.0)
				draw_rect(Rect2(slot_x + 2.0, origin.y + 9.0, floorf(9.0 * lfrac), 1.0), LxPalette.PAL["sky"])
		var g_col: Color = LxPalette.PAL["mauve"] if (is_locked or (_moves_idle_t > 5.0 and not _boss_active)) else LxPalette.PAL["stone"]
		if mid == "wings":
			var raw_dg: String = Lx.input.get_glyph("lx_dash").to_upper() if Lx.input != null else ""
			var dg: String = "SHF" if raw_dg == "SHIFT" else LxStrings.sanitize(raw_dg, 3)
			var wlbl: String = LxStrings.fmt("HUD_HOLD_SHORT_FMT", [dg]) if (not dg.is_empty() and LxStrings.has_id("HUD_HOLD_SHORT_FMT")) else LxStrings.text("OPT_MODE_HOLD")
			LxPixelFont.draw_centered(self, wlbl, slot_x + 6.5, origin.y + 12.0, LxPalette.PAL["ice"] if (wings_gliding and not is_locked) else g_col, 1)
		elif not is_passive and not action_id.is_empty() and Lx.input != null:
			var glyph: String = LxStrings.sanitize(Lx.input.get_glyph(action_id).to_upper(), 5)
			LxPixelFont.draw_centered(self, glyph, slot_x + 6.5, origin.y + 12.0, g_col, 1)
		elif mid == "prism":
			draw_rect(Rect2(slot_x + 3.0, origin.y + 13.0, 1.0, 2.0), LxPalette.PAL["sky"])
			draw_rect(Rect2(slot_x + 6.0, origin.y + 12.0, 1.0, 3.0), LxPalette.PAL["ice"])
			draw_rect(Rect2(slot_x + 9.0, origin.y + 13.0, 1.0, 2.0), LxPalette.PAL["sky"])
		else:
			draw_rect(Rect2(slot_x + 5.0, origin.y + 13.0, 3.0, 2.0), LxPalette.color(col_name))
		slot_x += step_x

func _draw_zip_cue(origin: Vector2) -> void:
	LxHudOverlays.draw_zip_cue(self, origin, _zip_cue_alpha)


func _draw_move_icon(move_id: String, at: Vector2, col: Color) -> void:
	LxHudOverlays.draw_move_icon(self, move_id, at, col)


func _draw_ember_meter(at: Vector2) -> void:
	LxHudOverlays.draw_ember_meter(self, at, _ember_val, _ember_max, _blink_t, not _boss_active)


func _draw_boss_bar() -> void:
	if _boss_entries.is_empty():
		LxBossHud.draw_boss_bars(self, [{"id": _boss_name_key, "name_key": _boss_name_key, "hp": _boss_hp, "max_hp": _boss_max_hp, "trail_hp": _boss_trail_hp, "phase": _boss_phase}], _blink_t)
	else:
		LxBossHud.draw_boss_bars(self, _boss_entries, _blink_t)


func _draw_interact_prompt(notice_rect: Rect2 = Rect2()) -> Rect2:
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D): return Rect2()
	var sf_v: Variant = Lx.player.get("move_sunflare")
	if is_instance_valid(sf_v) and sf_v is Object and float((sf_v as Object).get("flare_vis_t")) > 0.0: return Rect2()
	if LxHudFx.is_ceremony_active(): return Rect2()
	if Lx.player.has_method("is_grabbing") and bool(Lx.player.call("is_grabbing")):
		var gblk: Variant = Lx.player.get("grabbed_block")
		var gpos: Vector2 = (Lx.player as Node2D).global_position
		if is_instance_valid(gblk) and gblk is Object:
			var bpv: Variant = (gblk as Object).get("pos")
			if bpv is Vector2: gpos = bpv as Vector2
		var gtxt: String = LxStrings.text("HUD_PUSH_PULL")
		var gw: float = float(LxPixelFont.width(gtxt, 1)) + 8.0
		var grect: Rect2 = _place_prompt_rect(gpos, gw, 11.0, notice_rect)
		LxPixelFont.draw_panel(self, grect, "deep", "sky", "night")
		LxPixelFont.draw_centered(self, gtxt, grect.position.x + gw * 0.5, grect.position.y + 3.0, LxPalette.PAL["ice"], 1)
		return grect
	if Lx.world == null or not Lx.world.has_method("get_interactables"): return Rect2()
	var items_v: Variant = Lx.world.call("get_interactables")
	if not (items_v is Array): return Rect2()
	var ppos: Vector2 = (Lx.player as Node2D).global_position
	var best_pid: String = ""
	var best_pos: Vector2 = Vector2.ZERO
	var best_d2: float = INF
	for item: Variant in (items_v as Array):
		if not is_instance_valid(item) or not (item is Object): continue
		var obj: Object = item as Object
		if not _prop_bool(obj, "active") or _prop_bool(obj, "opened") or _prop_bool(obj, "collected") or _prop_bool(obj, "shattered"): continue
		if not obj.has_method("get_interact_prompt"): continue
		var pid: String = str(obj.call("get_interact_prompt"))
		if pid.is_empty(): continue
		var it_pos_v: Variant = obj.get("pos")
		var it_pos: Vector2 = (it_pos_v as Vector2) if it_pos_v is Vector2 else ((obj as Node2D).global_position if obj is Node2D else Vector2.ZERO)
		var it_rad: float = float(obj.get("radius")) if obj.get("radius") != null else 14.0
		var base_r: float = Lx.state.get_effective_pickup_radius() if (Lx.state != null and Lx.state.has_method("get_effective_pickup_radius")) else 24.0
		var reach: float = maxf(base_r, it_rad + 10.0)
		var d2: float = it_pos.distance_squared_to(ppos)
		if d2 <= reach * reach and d2 < best_d2:
			best_d2 = d2; best_pid = pid; best_pos = it_pos
	if best_pid.is_empty(): return Rect2()
	if _boss_active and best_pid == "PROMPT_TRANSFORMER": best_pid = "PROMPT_TURN_MIRROR"
	var label: String = LxStrings.text(best_pid) if LxStrings.has_id(best_pid) else LxStrings.sanitize(best_pid)
	if label.is_empty(): return Rect2()
	var glyph: String = "-"
	if Lx.input != null:
		var raw_g: String = LxStrings.sanitize(Lx.input.get_glyph("lx_interact"), 6)
		if not raw_g.is_empty(): glyph = raw_g
	var txt: String = LxStrings.fmt("HUD_KEY_PROMPT_FMT", [glyph, label])
	var w: float = float(LxPixelFont.width(txt, 1)) + 8.0
	var rect: Rect2 = _place_prompt_rect(best_pos, w, 11.0, notice_rect)
	var p_isl: int = Lx.state.island_id if Lx.state != null else 1
	LxPixelFont.draw_panel(self, rect, "dusk", LxBiomePalette.key(p_isl, "border"), "night")
	LxPixelFont.draw_centered(self, txt, rect.position.x + w * 0.5, rect.position.y + 3.0, LxPalette.PAL["cream"], 1)
	return rect

func _place_prompt_rect(world_pos: Vector2, w: float, h: float, notice_rect: Rect2) -> Rect2:
	var anchor_sp: Vector2 = _world_to_screen(world_pos)
	var player_sp: Vector2 = _world_to_screen((Lx.player as Node2D).global_position) if (Lx.player != null and is_instance_valid(Lx.player) and Lx.player is Node2D) else anchor_sp
	var sp: Vector2 = anchor_sp + Vector2(0.0, -24.0)
	var half_w: float = w * 0.5
	var cx: float = clampf(sp.x, 8.0 + half_w, 312.0 - half_w)
	var raw_y: float = sp.y - h * 0.5
	var py: float = clampf(raw_y, 18.0, 146.0 - h)
	var rect := Rect2(roundf(cx - half_w), roundf(py), w, h)
	var hits_notice: bool = notice_rect.has_area() and rect.intersects(notice_rect.grow(2.0))
	var hits_player: bool = rect.intersects(Rect2(player_sp - Vector2(10.0, 16.0), Vector2(20.0, 20.0)))
	if raw_y < 32.0 or anchor_sp.y < 54.0 or hits_notice or hits_player:
		py = clampf(maxf(anchor_sp.y + 18.0, player_sp.y + 12.0), 18.0, 146.0 - h)
		rect = Rect2(roundf(cx - half_w), roundf(py), w, h)
		if notice_rect.has_area() and rect.position.x < notice_rect.end.x + 2.0 and rect.end.x > notice_rect.position.x - 2.0:
			py = clampf(maxf(py, notice_rect.end.y + 3.0), 18.0, 146.0 - h)
			rect = Rect2(roundf(cx - half_w), roundf(py), w, h)
	return rect

func _notice_color() -> Color:
	if _notice_text.is_empty(): return Color(0.0, 0.0, 0.0, 0.0)
	var p: float = minf(_notice_t / 0.18, (_notice_dur - _notice_t) / 0.30)
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	return LxPalette.fade_step(maxf(p, 0.52) if _notice_t < 0.2 else p, LxBiomePalette.key(isl, "border"))

func _compute_notice_rect() -> Rect2:
	var w: float = float(LxPixelFont.width(_notice_text, 1)) + 24.0
	return Rect2(roundf(160.0 - w * 0.5), 4.0, w, 9.0)

func _draw_notice(rect: Rect2, col: Color) -> void:
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var ny: float = rect.position.y
	LxPixelFont.draw_panel(self, rect, "night", LxBiomePalette.key(isl, "border"), "void")
	LxHudFx.draw_biome_crest(self, isl, Vector2(rect.position.x + 6.0, ny + 4.0), col, LxPalette.PAL["cream"] as Color)
	LxHudFx.draw_biome_crest(self, isl, Vector2(rect.end.x - 7.0, ny + 4.0), col, LxPalette.PAL["cream"] as Color)
	LxPixelFont.draw_centered(self, _notice_text, 160.0, ny + 2.0, col, 1, Color(0.0, 0.0, 0.0, 0.0))


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return world_pos - Lx.camera.global_position + Vector2(160.0, 90.0) if Lx.camera != null else world_pos

func _count_island_beacons(island_id: int) -> int:
	var p1: String = "isl%d_" % island_id; var p2: String = "%d:" % island_id
	var p3: String = "beacon_%d_" % island_id; var p4: String = "beacon_isl%d_" % island_id
	var count: int = 0
	for bid: String in Lx.state.lit_beacons:
		if bid.begins_with(p1) or bid.begins_with(p2) or bid.begins_with(p3) or bid.begins_with(p4) or (island_id == 1 and bid in ["beacon_orchard", "beacon_observatory", "beacon_bridge"]):
			count += 1
	return mini(count, 3)

static func _has_lantern() -> bool:
	if Lx.state == null: return true
	if Lx.state.has_method("has_lantern"): return bool(Lx.state.call("has_lantern"))
	if bool(Lx.state.story_flags.get("lantern_picked_up", false)): return true
	if Lx.world != null and Lx.world.has_method("find_interactable"): return Lx.world.call("find_interactable", "lantern_pickup_1") == null
	return true

static func _prop_bool(obj: Object, prop: String) -> bool:
	var v: Variant = obj.get(prop)
	return v is bool and bool(v)
