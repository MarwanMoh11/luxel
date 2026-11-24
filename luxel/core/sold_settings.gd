class_name LxSold
extends RefCounted
## Island 8 (The Long Night) Sold-Settings Rule Engine ("THE LANTERN ASKS").
## Data-driven table (luxel/data/toll_settings.json): live apply/undo, reduced-effect
## versions, Toll Powers, boss/room hooks, save-slot persistence, 1-free Redemption,
## full restore at Dawn / Title / Slot switch. Never mutates Lx.save.settings or
## sells accessibility, pause, quit, rebinding, manual aim pip, or narration legibility.

signal setting_sold(setting_id: String, weight: int, total_weight: int)
signal setting_redeemed(setting_id: String, power_kept: bool)
signal setting_undone(setting_id: String)
signal all_restored(reason: String)
signal state_changed()
signal hud_visibility_changed(hud_flags: Dictionary)
signal display_pixels_changed(pct: float)
signal invoice_requested(boss_id: String, required_weight: int, context: Dictionary)
signal fx_pulse_requested(kind: String, payload: Dictionary)

const TABLE_PATH: String = "res://luxel/data/toll_settings.json"
const SCOPE_GAME: String = "game"
const MUSIC_TAPE_STOP_S: float = 0.45
const MUSIC_REDUCED_FADE_S: float = 0.80

const CORE_TABS: Array[String] = ["INTERFACE", "FEEL", "BEAUTY"]

static var _instance: LxSold = null
static var _table_cache: Dictionary = {}
static var _entries_by_id: Dictionary = {}
static var _unsellables: Dictionary = {}

var _sold_ids: Array[String] = []
var _redeemed_ids: Array[String] = []
var _redemption_used: bool = false
var _display_pixels_pct: float = 0.0
var _hush_finale_choice: String = ""
var _dawn_restored: bool = false
var _suspended_for_title: bool = false
var _last_slot_id: String = ""
var _last_flow: int = -1

# Smooth runtime audio fade state (never touches Lx.save.settings).
var _music_fade: float = 1.0 # 1.0 = full user vol, 0.0 = muted by music_off
var _music_pitch: float = 1.0
var _sfx_muted_by_toll: bool = false
var _cam_override_active: bool = false
var _invoice_count: int = 0


static func current() -> LxSold:
	if _instance == null:
		_instance = LxSold.new()
		_instance._ensure_table()
		_instance.sync_from_state()
	return _instance


static func reset_singleton() -> void:
	if _instance != null:
		_instance._restore_runtime_overrides(false)
		_instance = null
	_table_cache.clear()
	_entries_by_id.clear()
	_unsellables.clear()


static func load_table() -> Dictionary:
	if _table_cache.is_empty():
		var d: Dictionary = Lx.load_json(TABLE_PATH)
		_table_cache = d
		_entries_by_id.clear()
		_unsellables.clear()
		for u_v: Variant in (d.get("unsellables", []) as Array):
			_unsellables[str(u_v).strip_edges().to_lower()] = true
		for item: Variant in (d.get("settings", []) as Array):
			if item is Dictionary:
				var sid: String = str((item as Dictionary).get("id", "")).strip_edges().to_lower()
				if not sid.is_empty():
					_entries_by_id[sid] = (item as Dictionary).duplicate(true)
	return _table_cache


func _ensure_table() -> void:
	if _table_cache.is_empty():
		load_table()


func get_table() -> Dictionary:
	_ensure_table()
	return _table_cache.duplicate(true)


func get_tabs() -> Array[String]:
	_ensure_table()
	var out: Array[String] = []
	for t_v: Variant in (_table_cache.get("tabs", CORE_TABS) as Array):
		out.append(str(t_v))
	return out if not out.is_empty() else CORE_TABS.duplicate()


func get_setting(setting_id: String) -> Dictionary:
	_ensure_table()
	var key: String = setting_id.strip_edges().to_lower()
	if _entries_by_id.has(key):
		return (_entries_by_id[key] as Dictionary).duplicate(true)
	return {}


func list_settings(tab_filter: String = "", include_finale: bool = false) -> Array[Dictionary]:
	_ensure_table()
	var tf: String = tab_filter.strip_edges().to_upper()
	var out: Array[Dictionary] = []
	for item: Variant in (_table_cache.get("settings", []) as Array):
		if not (item is Dictionary):
			continue
		var d: Dictionary = item as Dictionary
		if bool(d.get("is_finale", false)) and not include_finale and tf != "FINALE":
			continue
		if not tf.is_empty() and str(d.get("tab", "")).to_upper() != tf:
			continue
		out.append(d.duplicate(true))
	return out


func is_unsellable(setting_id: String) -> bool:
	_ensure_table()
	var key: String = setting_id.strip_edges().to_lower()
	if key.is_empty():
		return true
	if _unsellables.has(key):
		return true
	return not _entries_by_id.has(key)


func is_dawn_restored() -> bool:
	if _dawn_restored:
		return true
	if Lx.state != null:
		if Lx.state.relit_islands.has(8) or bool(Lx.state.story_flags.get("island_8_relit", false)) or bool(Lx.state.story_flags.get("great_lamp_8", false)):
			return true
	return false


func is_sold(setting_id: String) -> bool:
	if _suspended_for_title or is_dawn_restored():
		return false
	return _sold_ids.has(setting_id.strip_edges().to_lower())


func is_redeemed(setting_id: String) -> bool:
	return _redeemed_ids.has(setting_id.strip_edges().to_lower())


func was_sold(setting_id: String) -> bool:
	var key: String = setting_id.strip_edges().to_lower()
	return _sold_ids.has(key) or _redeemed_ids.has(key)


func has_power(setting_id: String) -> bool:
	if _suspended_for_title:
		return false
	var key: String = setting_id.strip_edges().to_lower()
	return _sold_ids.has(key) or _redeemed_ids.has(key)


func get_sold_ids() -> PackedStringArray:
	if _suspended_for_title or is_dawn_restored():
		return PackedStringArray()
	return PackedStringArray(_sold_ids)


func get_active_and_redeemed_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for s: String in _sold_ids:
		if not out.has(s): out.append(s)
	for r: String in _redeemed_ids:
		if not out.has(r): out.append(r)
	return out


func get_redeemed_ids() -> PackedStringArray:
	return PackedStringArray(_redeemed_ids)


func get_dawn_receipts() -> PackedStringArray:
	if Lx.state != null and Lx.state.story_flags.get("dawn_restored_settings") is Array:
		var out := PackedStringArray()
		for v: Variant in (Lx.state.story_flags["dawn_restored_settings"] as Array):
			out.append(str(v))
		return out
	return get_active_and_redeemed_ids()


func get_sold_count() -> int:
	if _suspended_for_title or is_dawn_restored():
		return 0
	return _sold_ids.size()


func get_toll_weight() -> int:
	_ensure_table()
	if _suspended_for_title:
		return 0
	var total: int = 0
	for sid: String in get_active_and_redeemed_ids():
		var d: Dictionary = _entries_by_id.get(sid, {}) as Dictionary
		total += int(d.get("weight", 1))
	return total


func is_redemption_used() -> bool:
	return _redemption_used


func get_display_pixels_pct() -> float:
	if _suspended_for_title or is_dawn_restored():
		return 0.0
	return _display_pixels_pct


func get_hush_finale_choice() -> String:
	return _hush_finale_choice


func is_tab_sold(tab: String) -> bool:
	var t_up: String = tab.strip_edges().to_upper()
	for sid: String in _sold_ids:
		var d: Dictionary = _entries_by_id.get(sid, {}) as Dictionary
		if str(d.get("tab", "")).to_upper() == t_up:
			return true
	return false


func count_in_tab(tab: String) -> int:
	var t_up: String = tab.strip_edges().to_upper()
	var n: int = 0
	for sid: String in _sold_ids:
		var d: Dictionary = _entries_by_id.get(sid, {}) as Dictionary
		if str(d.get("tab", "")).to_upper() == t_up:
			n += 1
	return n


func can_sell(setting_id: String) -> bool:
	_ensure_table()
	var key: String = setting_id.strip_edges().to_lower()
	if is_unsellable(key):
		return false
	if is_dawn_restored():
		return false
	return not _sold_ids.has(key) and not _redeemed_ids.has(key)


func can_redeem(setting_id: String) -> bool:
	var key: String = setting_id.strip_edges().to_lower()
	if _redemption_used or is_dawn_restored():
		return false
	if key == "display_pixels":
		return false
	return _sold_ids.has(key)


func sell(setting_id: String, opts: Dictionary = {}) -> bool:
	_ensure_table()
	var key: String = setting_id.strip_edges().to_lower()
	if not can_sell(key):
		return false
	var meta: Dictionary = _entries_by_id[key] as Dictionary
	_suspended_for_title = false
	_sold_ids.append(key)
	if key == "display_pixels":
		_display_pixels_pct = maxf(_display_pixels_pct, clampf(float(opts.get("pct", 0.35)), 0.05, 1.0))
	_write_to_state()
	_apply_live_effects(key, true)
	var w: int = int(meta.get("weight", 1))
	var tw: int = get_toll_weight()
	fx_pulse_requested.emit("mote_stream", {
		"setting_id": key,
		"source_pos": opts.get("source_pos", Vector2.ZERO),
		"count": 18,
		"reduced": LxHudFx.flash_reduced(),
	})
	setting_sold.emit(key, w, tw)
	_emit_hud_and_state()
	if Lx.events != null and bool(opts.get("save", true)):
		Lx.events.save_requested.emit("sold_" + key)
	return true


func redeem(setting_id: String) -> bool:
	_ensure_table()
	var key: String = setting_id.strip_edges().to_lower()
	if not can_redeem(key):
		return false
	_sold_ids.erase(key)
	if not _redeemed_ids.has(key):
		_redeemed_ids.append(key)
	_redemption_used = true
	_write_to_state()
	_apply_live_effects(key, false)
	fx_pulse_requested.emit("redeem_flash", {"setting_id": key, "reduced": LxHudFx.flash_reduced()})
	setting_redeemed.emit(key, true)
	_emit_hud_and_state()
	if Lx.events != null:
		Lx.events.save_requested.emit("redeemed_" + key)
	return true


func undo(setting_id: String) -> bool:
	_ensure_table()
	var key: String = setting_id.strip_edges().to_lower()
	var changed: bool = false
	if _sold_ids.has(key):
		_sold_ids.erase(key)
		changed = true
	if _redeemed_ids.has(key):
		_redeemed_ids.erase(key)
		changed = true
	if key == "display_pixels" and _display_pixels_pct > 0.0:
		_display_pixels_pct = 0.0
		changed = true
	if not changed:
		return false
	_write_to_state()
	_apply_live_effects(key, false)
	setting_undone.emit(key)
	if key == "display_pixels":
		display_pixels_changed.emit(0.0)
	_emit_hud_and_state()
	return true


func set_display_pixels(pct: float) -> void:
	_ensure_table()
	if is_dawn_restored():
		return
	var clamped: float = clampf(pct, 0.0, 1.0)
	if is_equal_approx(_display_pixels_pct, clamped):
		return
	_display_pixels_pct = clamped
	if clamped > 0.001:
		if not _sold_ids.has("display_pixels"):
			_sold_ids.append("display_pixels")
	else:
		_sold_ids.erase("display_pixels")
	_write_to_state()
	display_pixels_changed.emit(_display_pixels_pct)
	_emit_hud_and_state()


func apply_hush_finale_choice(choice: String) -> void:
	var c: String = choice.strip_edges().to_lower()
	if c != "display" and c != "keep":
		return
	_hush_finale_choice = c
	if c == "display":
		set_display_pixels(maxf(_display_pixels_pct, 0.25))
	else:
		set_display_pixels(0.0)
	_write_to_state()
	state_changed.emit()


func restore_all(reason: String = "dawn", keep_history: bool = true) -> void:
	_ensure_table()
	var r: String = reason.strip_edges().to_lower()
	if r == "title":
		_suspended_for_title = true
		_restore_runtime_overrides(true)
		all_restored.emit("title")
		_emit_hud_and_state()
		return
	if r == "dawn":
		var receipts: Array[String] = []
		for sid: String in get_active_and_redeemed_ids():
			receipts.append(sid)
		if Lx.state != null and keep_history:
			Lx.state.story_flags["dawn_restored_settings"] = receipts
			Lx.state.story_flags["dawn_restored_count"] = receipts.size()
		_dawn_restored = true
		_suspended_for_title = false
		_sold_ids.clear()
		_display_pixels_pct = 0.0
		_write_to_state()
		_restore_runtime_overrides(false)
		fx_pulse_requested.emit("dawn_restore", {"receipts": receipts, "reduced": LxHudFx.flash_reduced()})
		display_pixels_changed.emit(0.0)
		all_restored.emit("dawn")
		_emit_hud_and_state()
		return
	# "slot_switch" or "reset": clear runtime & in-memory state cleanly.
	_dawn_restored = false
	_suspended_for_title = false
	_sold_ids.clear()
	_redeemed_ids.clear()
	_redemption_used = false
	_display_pixels_pct = 0.0
	_hush_finale_choice = ""
	_invoice_count = 0
	if r == "reset":
		_write_to_state()
	_restore_runtime_overrides(false)
	display_pixels_changed.emit(0.0)
	all_restored.emit(r)
	_emit_hud_and_state()


func sync_from_state() -> void:
	_ensure_table()
	_sold_ids.clear()
	_redeemed_ids.clear()
	_redemption_used = false
	_display_pixels_pct = 0.0
	_hush_finale_choice = ""
	_dawn_restored = false
	_suspended_for_title = false
	if Lx.state != null:
		_last_slot_id = Lx.state.slot_id
		if Lx.state.relit_islands.has(8) or bool(Lx.state.story_flags.get("island_8_relit", false)) or bool(Lx.state.story_flags.get("great_lamp_8", false)):
			_dawn_restored = true
	if Lx.vars != null:
		var raw_sold: Variant = Lx.vars.get_var(SCOPE_GAME, "sold_settings", [])
		if raw_sold is Array:
			for v: Variant in (raw_sold as Array):
				var sid: String = str(v).strip_edges().to_lower()
				if not is_unsellable(sid) and not _sold_ids.has(sid):
					_sold_ids.append(sid)
		var raw_red: Variant = Lx.vars.get_var(SCOPE_GAME, "redeemed_settings", [])
		if raw_red is Array:
			for v: Variant in (raw_red as Array):
				var sid: String = str(v).strip_edges().to_lower()
				if not is_unsellable(sid) and not _redeemed_ids.has(sid):
					_redeemed_ids.append(sid)
		_redemption_used = bool(Lx.vars.get_var(SCOPE_GAME, "redemption_used", false))
		_display_pixels_pct = clampf(float(Lx.vars.get_var(SCOPE_GAME, "display_pixels_pct", 0.0)), 0.0, 1.0)
		_hush_finale_choice = str(Lx.vars.get_var(SCOPE_GAME, "hush_finale_choice", ""))
		# Also pick up any explicit sold_<id> bool set directly in world_vars.
		for sid: String in _entries_by_id.keys():
			if bool(Lx.vars.get_var(SCOPE_GAME, "sold_" + sid, false)) and not _sold_ids.has(sid) and not _redeemed_ids.has(sid):
				_sold_ids.append(sid)
	if _dawn_restored:
		_sold_ids.clear()
		_display_pixels_pct = 0.0
	_apply_all_live_effects()
	_emit_hud_and_state()


func tick_runtime(dt: float) -> void:
	# Watch for Title transition or save-slot switch automatically.
	if Lx.root != null and is_instance_valid(Lx.root):
		var fl_v: Variant = Lx.root.get("flow")
		if fl_v is int:
			var fl: int = int(fl_v)
			if fl != _last_flow:
				var prev_fl: int = _last_flow
				_last_flow = fl
				if fl == 0: # LxMain.Flow.TITLE
					if not _suspended_for_title:
						restore_all("title", true)
				elif prev_fl == 0 and _suspended_for_title:
					_suspended_for_title = false
					sync_from_state()
	if Lx.state != null and Lx.state.slot_id != _last_slot_id:
		_last_slot_id = Lx.state.slot_id
		restore_all("slot_switch", false)
		sync_from_state()
	elif Lx.vars != null and (not _sold_ids.is_empty() or not _redeemed_ids.is_empty()) and Lx.vars.get_var(SCOPE_GAME, "sold_settings", null) == null:
		sync_from_state()
	if not _dawn_restored and is_dawn_restored():
		restore_all("dawn", true)
	_step_audio_overrides(dt)


func get_hud_visibility() -> Dictionary:
	return {
		"show_hearts": not is_sold("hud_hearts"),
		"show_minimap": not is_sold("minimap_hud"),
		"show_ember": not is_sold("ember_hud"),
		"show_cursor_ring": not is_sold("cursor_ring"),
		"show_dash_trail": not is_sold("dash_trail"),
		"show_hit_flash": not is_sold("hit_flash"),
		"show_camera_shake": not is_sold("camera_shake"),
		# Sacred Unsellables — ALWAYS true:
		"show_cursor_pip": true,
		"show_pause": true,
		"show_quit": true,
		"show_narration": true,
		"show_boss_name": true,
		"allow_accessibility": true,
		"allow_rebind": true,
	}


func is_wick_silent() -> bool:
	return has_power("sound_off")


func get_enemy_notice_mult() -> float:
	return 0.70 if has_power("sound_off") else 1.0


func modify_stat(stat_name: String, base_val: float, ctx: Dictionary = {}) -> float:
	var val: float = base_val
	match stat_name:
		"bolt_damage":
			if has_power("hud_hearts"):
				var hp: float = float(ctx.get("hearts", Lx.state.hearts if Lx.state != null else 4.0))
				if hp <= 2.0:
					val *= 1.15
			if has_power("fps_step") and bool(ctx.get("post_dash", false)):
				val *= 1.60
			if has_power("hit_flash") and bool(ctx.get("opened", false)):
				val *= 1.20
			if has_power("display_pixels") and _display_pixels_pct > 0.0:
				val *= 1.25
		"bolt_cooldown":
			if has_power("cursor_ring"):
				val *= 0.85
		"move_speed":
			if has_power("minimap_hud"):
				val *= 1.12
		"ember_rate":
			if has_power("ember_hud"):
				val *= 1.20
		"dash_iframes":
			if has_power("dash_trail"):
				val += 0.035
		"opened_damage":
			if has_power("hit_flash"):
				val *= 1.20
		"lens_duration":
			if has_power("camera_shake"):
				val += 1.2
		"wings_glide":
			if has_power("world_anims"):
				val *= 1.15
		"beam_damage", "sunflare_damage":
			if has_power("palette_4"):
				val *= 1.18
			if has_power("display_pixels") and _display_pixels_pct > 0.0:
				val *= 1.25
		"perfect_dodge":
			if has_power("music_off"):
				val *= 1.25
		"enemy_notice":
			if has_power("sound_off"):
				val *= 0.70
		"post_dash_bolt_damage":
			if has_power("fps_step"):
				val *= 1.60
		"all_damage":
			if has_power("display_pixels") and _display_pixels_pct > 0.0:
				val *= 1.25
	return val


func eval_check(expr: String) -> bool:
	var trimmed: String = expr.strip_edges()
	if trimmed.is_empty():
		return true
	if trimmed.find("||") >= 0:
		for p: String in trimmed.split("||", false):
			if eval_check(p):
				return true
		return false
	if trimmed.find("&&") >= 0:
		for p: String in trimmed.split("&&", false):
			if not eval_check(p):
				return false
		return true
	if trimmed.begins_with("!"):
		return not eval_check(trimmed.substr(1))
	if trimmed.begins_with("sold:"):
		return is_sold(trimmed.substr(5))
	if trimmed.begins_with("was_sold:"):
		return was_sold(trimmed.substr(9))
	if trimmed.begins_with("power:"):
		return has_power(trimmed.substr(6))
	if trimmed.begins_with("redeemed:"):
		return is_redeemed(trimmed.substr(9))
	if trimmed.begins_with("sold_tab:"):
		return is_tab_sold(trimmed.substr(9))
	if trimmed.begins_with("sold_count"):
		return _cmp_num(float(get_sold_count()), trimmed.substr(10))
	if trimmed.begins_with("toll_weight"):
		return _cmp_num(float(get_toll_weight()), trimmed.substr(11))
	if trimmed.begins_with("display_pixels"):
		return _cmp_num(_display_pixels_pct, trimmed.substr(14))
	return is_sold(trimmed)


func get_tollmaster_hooks() -> Dictionary:
	return {
		"toll_weight": get_toll_weight(),
		"sold_count": get_sold_count(),
		"sold_ids": get_sold_ids(),
		"invoice_count": _invoice_count,
		"unsold_count": get_unsold_core_ids().size(),
		"tab_sold": {
			"INTERFACE": is_tab_sold("INTERFACE"),
			"FEEL": is_tab_sold("FEEL"),
			"BEAUTY": is_tab_sold("BEAUTY"),
		},
	}


func get_hush_hooks() -> Dictionary:
	return {
		"finale_choice": _hush_finale_choice,
		"display_pixels_pct": get_display_pixels_pct(),
		"sold_count": get_sold_count(),
		"toll_weight": get_toll_weight(),
		"last_clarity_mult": 1.25 if (has_power("display_pixels") and _display_pixels_pct > 0.0) else 1.0,
		"can_sell_display": not is_dawn_restored(),
		"is_dawn_restored": is_dawn_restored(),
		"dawn_receipts": get_dawn_receipts(),
	}


func request_boss_invoice(boss_id: String, required_weight: int = 1, context: Dictionary = {}) -> void:
	_invoice_count += 1
	var ctx: Dictionary = context.duplicate(true)
	ctx["invoice_index"] = _invoice_count
	invoice_requested.emit(boss_id, maxi(1, required_weight), ctx)


func get_unsold_core_ids(tab_filter: String = "") -> Array[String]:
	var out: Array[String] = []
	for d: Dictionary in list_settings(tab_filter, false):
		var sid: String = str(d.get("id", ""))
		if can_sell(sid):
			out.append(sid)
	return out


func _write_to_state() -> void:
	if Lx.vars != null:
		Lx.vars.set_var(SCOPE_GAME, "sold_settings", _sold_ids.duplicate())
		Lx.vars.set_var(SCOPE_GAME, "redeemed_settings", _redeemed_ids.duplicate())
		Lx.vars.set_var(SCOPE_GAME, "sold_count", get_sold_count())
		Lx.vars.set_var(SCOPE_GAME, "toll_weight", get_toll_weight())
		Lx.vars.set_var(SCOPE_GAME, "redemption_used", _redemption_used)
		Lx.vars.set_var(SCOPE_GAME, "display_pixels_pct", _display_pixels_pct)
		Lx.vars.set_var(SCOPE_GAME, "hush_finale_choice", _hush_finale_choice)
		for sid: String in _entries_by_id.keys():
			Lx.vars.set_var(SCOPE_GAME, "sold_" + sid, is_sold(sid))
	if Lx.state != null:
		var tw: int = get_toll_weight()
		Lx.state.story_flags["sold_any"] = not _sold_ids.is_empty() or not _redeemed_ids.is_empty()
		Lx.state.story_flags["redemption_used"] = _redemption_used
		for n: int in [1, 2, 3, 4, 5, 6]:
			Lx.state.story_flags["toll_weight_%d" % n] = tw >= n
		for sid: String in _entries_by_id.keys():
			Lx.state.story_flags["sold_" + sid] = is_sold(sid)
			Lx.state.story_flags["power_" + sid] = has_power(sid)


func _apply_all_live_effects() -> void:
	_apply_camera_shake_override()
	_apply_sfx_override()
	if is_sold("music_off"):
		_music_fade = 0.0
		_music_pitch = 1.0
	else:
		_music_fade = 1.0
		_music_pitch = 1.0
	_apply_music_bus_gain()


func _apply_live_effects(setting_id: String, now_sold: bool) -> void:
	match setting_id:
		"camera_shake":
			_apply_camera_shake_override()
		"sound_off":
			_apply_sfx_override()
		"music_off":
			if not now_sold:
				_music_fade = 1.0
				_music_pitch = 1.0
				_apply_music_bus_gain()
		_:
			pass


func _apply_camera_shake_override() -> void:
	if Lx.camera == null or not is_instance_valid(Lx.camera):
		return
	if is_sold("camera_shake"):
		Lx.camera.shake_scale = 0.0
		_cam_override_active = true
	elif _cam_override_active:
		_cam_override_active = false
		var user_shake: float = float(Lx.save.settings.get("screen_shake", 100)) / 100.0 if Lx.save != null else 1.0
		Lx.camera.shake_scale = clampf(user_shake, 0.0, 1.0)


func _apply_sfx_override() -> void:
	var sfx_idx: int = AudioServer.get_bus_index(LxAudioService.BUS_SFX)
	if sfx_idx < 0:
		return
	if is_sold("sound_off"):
		AudioServer.set_bus_mute(sfx_idx, true)
		_sfx_muted_by_toll = true
	elif _sfx_muted_by_toll:
		_sfx_muted_by_toll = false
		var user_vol: float = float(Lx.save.settings.get("sfx_vol", 0.9)) if Lx.save != null else 0.9
		AudioServer.set_bus_mute(sfx_idx, user_vol <= 0.001)
		if Lx.audio != null and Lx.save != null:
			Lx.audio.apply_settings(Lx.save.settings)
			if is_sold("music_off"):
				_apply_music_bus_gain()


func _step_audio_overrides(dt: float) -> void:
	var target: float = 0.0 if is_sold("music_off") else 1.0
	if is_equal_approx(_music_fade, target) and is_equal_approx(_music_pitch, 1.0):
		return
	var reduced: bool = LxHudFx.flash_reduced()
	var dur: float = MUSIC_REDUCED_FADE_S if reduced else MUSIC_TAPE_STOP_S
	var rate: float = 1.0 / maxf(0.05, dur)
	if target < _music_fade:
		_music_fade = maxf(0.0, _music_fade - dt * rate)
		_music_pitch = 1.0 if reduced else lerpf(0.68, 1.0, _music_fade)
	else:
		_music_fade = minf(1.0, _music_fade + dt * 2.5)
		_music_pitch = 1.0
	_apply_music_bus_gain()


func _apply_music_bus_gain() -> void:
	var idx: int = AudioServer.get_bus_index(LxAudioService.BUS_MUSIC)
	if idx < 0:
		return
	var user_vol: float = float(Lx.save.settings.get("music_vol", 0.85)) if Lx.save != null else 0.85
	var eff: float = clampf(user_vol * _music_fade, 0.0, 1.0)
	if eff <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(eff))
	if Lx.audio != null and is_instance_valid(Lx.audio):
		var ep: Variant = Lx.audio.get("_explore_player")
		if ep is AudioStreamPlayer and is_instance_valid(ep):
			(ep as AudioStreamPlayer).pitch_scale = _music_pitch
		var cp: Variant = Lx.audio.get("_combat_player")
		if cp is AudioStreamPlayer and is_instance_valid(cp):
			(cp as AudioStreamPlayer).pitch_scale = _music_pitch


func _restore_runtime_overrides(_for_title: bool) -> void:
	_music_fade = 1.0
	_music_pitch = 1.0
	_sfx_muted_by_toll = false
	_cam_override_active = false
	if Lx.audio != null and is_instance_valid(Lx.audio) and Lx.save != null:
		Lx.audio.apply_settings(Lx.save.settings)
		var ep: Variant = Lx.audio.get("_explore_player")
		if ep is AudioStreamPlayer and is_instance_valid(ep):
			(ep as AudioStreamPlayer).pitch_scale = 1.0
		var cp: Variant = Lx.audio.get("_combat_player")
		if cp is AudioStreamPlayer and is_instance_valid(cp):
			(cp as AudioStreamPlayer).pitch_scale = 1.0
	else:
		var m_idx: int = AudioServer.get_bus_index(LxAudioService.BUS_MUSIC)
		if m_idx >= 0: AudioServer.set_bus_mute(m_idx, false)
		var s_idx: int = AudioServer.get_bus_index(LxAudioService.BUS_SFX)
		if s_idx >= 0: AudioServer.set_bus_mute(s_idx, false)
	if Lx.camera != null and is_instance_valid(Lx.camera):
		var user_shake: float = float(Lx.save.settings.get("screen_shake", 100)) / 100.0 if Lx.save != null else 1.0
		Lx.camera.shake_scale = clampf(user_shake, 0.0, 1.0)


func _emit_hud_and_state() -> void:
	hud_visibility_changed.emit(get_hud_visibility())
	state_changed.emit()


static func _cmp_num(lhs: float, rhs_expr: String) -> bool:
	var s: String = rhs_expr.strip_edges()
	for op: String in [">=", "<=", "==", "!=", ">", "<"]:
		if s.begins_with(op):
			var n: float = float(s.substr(op.length()).strip_edges())
			match op:
				">=": return lhs >= n - 0.0001
				"<=": return lhs <= n + 0.0001
				"==": return is_equal_approx(lhs, n)
				"!=": return not is_equal_approx(lhs, n)
				">": return lhs > n
				"<": return lhs < n
	return lhs > 0.0
