class_name LxDoor
extends LxInteractable
## Multi-mode door / barrier rendered via bespoke per-island modular door atlases:
## - ward_barrier, wick_key, boss_key, combat_gate, switch_door, bridge_platform

const OPEN_DUR: float = 0.55
const KEY_FLASH_DUR: float = 0.16

var door_type: String = "switch_door"
var opened: bool = false
var size: Vector2 = Vector2(32.0, 16.0)
var dungeon_id: String = ""
var zone_id: String = ""
var required_beacons: int = 0
var required_beacon_ids: Array[String] = []
var required_flags: Array[String] = []
var required_signals: Array[String] = []
var required_count: int = 1
var _active_signals: Dictionary = {}
var _pulse_stage: int = 0
var _open_t: float = 0.0
var _rattle_t: float = 0.0
var _is_light_bridge: bool = false
var _door_sheet: LxSpriteSheet = null
var _door_sheet_key: String = ""

func setup(spec: Dictionary) -> void:
	super.setup(spec)
	var raw_kind: String = str(spec.get("kind", "door")).strip_edges().to_lower()
	var default_type: String = "switch_door"
	match raw_kind:
		"ward_barrier", "wick_key", "boss_key", "combat_gate", "switch_door", "bridge_platform":
			default_type = raw_kind
		"locked_door": default_type = "wick_key"
		"boss_door": default_type = "boss_key"
	var raw_type: String = str(props.get("door_type", props.get("door_kind", default_type))).strip_edges().to_lower()
	match raw_type:
		"key_door", "locked_door": door_type = "wick_key"
		"boss_door": door_type = "boss_key"
		"shutter": door_type = "switch_door"
		"shortcut_door", "bridge_of_light": door_type = "ward_barrier"
		_: door_type = raw_type
	var raw_key: String = str(props.get("key_kind", props.get("key_id", ""))).strip_edges().to_lower()
	if raw_key == "keepers_flame":
		door_type = "boss_key"
	elif raw_key == "wick_key" and door_type == "switch_door":
		door_type = "wick_key"
	kind = "door"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5 + 4.0
	dungeon_id = str(props.get("dungeon_id", "island_%d" % island_id))
	if dungeon_id.is_empty(): dungeon_id = "island_%d" % island_id
	zone_id = str(props.get("zone", props.get("clear_zone", "")))
	var raw_beacons: Variant = props.get("requires_beacons", props.get("required_beacons", 0))
	required_beacon_ids = []; required_beacons = 0
	if raw_beacons is Array:
		required_beacon_ids = _to_str_array(raw_beacons)
		required_beacons = required_beacon_ids.size()
	elif raw_beacons is int or raw_beacons is float:
		required_beacons = int(raw_beacons)
	required_flags = _to_str_array(props.get("requires_flags", props.get("required_flags", [])))
	required_signals = _to_str_array(props.get("requires_signals", props.get("required_signals", [])))
	required_count = maxi(1, int(props.get("required_count", maxi(1, required_signals.size()))))
	opened = bool(props.get("opened", props.get("starts_open", false)))
	_is_light_bridge = id.begins_with("bridge_of_light") or raw_type == "bridge_of_light"
	if Lx.state != null and not id.is_empty() and (Lx.state.opened_doors.has(id) or Lx.state.broken_seals.has(id)):
		opened = true
	_load_door_sheet()
	queue_redraw()

func _load_door_sheet() -> LxSpriteSheet:
	var th: String = ""
	if region != null and region.get("region_data") is Dictionary:
		th = str((region.get("region_data") as Dictionary).get("theme", "")).strip_edges().to_lower()
	if th == "ember_express_roof" or th == "ember_express_interior": th = "ember_express"
	elif th.begins_with("archive_"): th = "archive"
	elif th == "inverted_palace": th = "inverted_palace_silver"
	elif th == "wick_house_hub": th = "wick_house"
	var iid: int = clampi(island_id, 1, 8)
	var skey: String = "%s|%d" % [th, iid]
	if _door_sheet != null and _door_sheet_key == skey: return _door_sheet
	_door_sheet_key = skey; _door_sheet = null
	if not th.is_empty():
		var tpath: String = "res://luxel/art/props/theme_%s_doors.json" % th
		if ResourceLoader.exists(tpath) or FileAccess.file_exists(tpath):
			_door_sheet = LxSpriteSheet.load_sheet(tpath)
	if _door_sheet == null:
		_door_sheet = LxSpriteSheet.load_sheet("res://luxel/art/props/island%d_doors.json" % iid)
	if _door_sheet == null and iid != 1:
		_door_sheet = LxSpriteSheet.load_sheet("res://luxel/art/props/island1_doors.json")
	return _door_sheet

func tick(dt: float) -> void:
	super.tick(dt)
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt); queue_redraw()
	if _rattle_t > 0.0:
		_rattle_t = maxf(0.0, _rattle_t - dt); queue_redraw()
	if not active: return
	if opened:
		if _is_light_bridge: _advance_pulse(int(floorf(_clock * 5.0)) % 8)
		return
	match door_type:
		"ward_barrier":
			if _ward_requirements_met(): _open(true); return
			_advance_pulse(int(floorf(_clock * 5.5 + absf(pos.x * 0.02))) % 4)
		"combat_gate":
			if region != null and region.has_method("is_zone_cleared") and bool(region.call("is_zone_cleared", zone_id)):
				_open(false); return
			_advance_pulse(int(floorf(_clock * 3.2 + absf(pos.x * 0.03))) % 4)
		"boss_key": _advance_pulse(int(floorf(_clock * 6.25)) % 4)
		"switch_door": _advance_pulse(int(floorf(_clock * 2.4)) % 2)
		"wick_key":
			if _player_can_unlock_key_door(): _advance_pulse(int(floorf(_clock * 3.0 + absf(pos.x * 0.02))) % 4)

func _advance_pulse(stage: int) -> void:
	if stage != _pulse_stage: _pulse_stage = stage; queue_redraw()

func interact(_actor: Node = null) -> bool:
	if not active or opened: return false
	match door_type:
		"wick_key":
			if Lx.state != null and Lx.state.consume_key(dungeon_id, "wick_key"):
				return _open(true)
		"boss_key":
			if Lx.state != null and Lx.state.consume_key(dungeon_id, "keepers_flame"):
				return _open(true)
		"ward_barrier":
			if _ward_requirements_met(): return _open(true)
	_rattle_t = 0.22; _emit_sfx("door_locked"); queue_redraw()
	return false

func on_signal(from_id: String, powered: bool) -> void:
	if not active or (door_type != "switch_door" and door_type != "bridge_platform"): return
	if powered: _active_signals[from_id] = true
	else: _active_signals.erase(from_id)
	if opened: return
	if not required_signals.is_empty():
		for req: String in required_signals:
			if not bool(_active_signals.get(req, false)):
				if powered: _rattle_t = 0.10; queue_redraw()
				return
		_open(bool(props.get("persistent", true)))
	elif _active_signals.size() >= required_count:
		_open(bool(props.get("persistent", true)))
	elif powered:
		_rattle_t = 0.10; queue_redraw()

func _count_island_beacons() -> int:
	if Lx.state == null: return 0
	var got_isl: int = 0
	var p1: String = "isl%d_" % island_id; var p2: String = "%d:" % island_id
	var p3: String = "beacon_%d_" % island_id; var p4: String = "beacon_isl%d_" % island_id
	for b: String in Lx.state.lit_beacons:
		if b.begins_with(p1) or b.begins_with(p2) or b.begins_with(p3) or b.begins_with(p4) or (island_id == 1 and b in ["beacon_orchard", "beacon_observatory", "beacon_bridge"]):
			got_isl += 1
	return got_isl

func _ward_requirements_met() -> bool:
	if Lx.state == null: return false
	if not required_beacon_ids.is_empty():
		for bid: String in required_beacon_ids:
			if not Lx.state.lit_beacons.has(bid): return false
	elif required_beacons > 0 and _count_island_beacons() < required_beacons:
		return false
	for fl: String in required_flags:
		if region != null and region.has_method("is_flag_set"):
			if not bool(region.call("is_flag_set", fl)): return false
		elif not bool(Lx.state.story_flags.get(fl, false)) and not Lx.state.lit_beacons.has(fl):
			return false
	return true

func _open(persist: bool) -> bool:
	opened = true
	_open_t = OPEN_DUR
	if Lx.state != null:
		var flag_name: String = str(props.get("sets_flag", props.get("flag_id", "")))
		if not flag_name.is_empty():
			Lx.state.story_flags[flag_name] = true
		if persist and not id.is_empty():
			if not Lx.state.opened_doors.has(id):
				Lx.state.opened_doors.append(id)
			if door_type == "ward_barrier" and not Lx.state.broken_seals.has(id):
				Lx.state.broken_seals.append(id)
	var is_grand: bool = door_type == "boss_key" or door_type == "ward_barrier"
	if door_type == "ward_barrier" and Lx.events != null:
		Lx.events.seal_broken.emit(island_id, id)
	else:
		_emit_gust(maxf(size.x, size.y) + (38.0 if is_grand else 22.0), 68.0 if is_grand else 42.0)
	if is_grand:
		if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("trigger_hitstop"):
			Lx.player.call("trigger_hitstop", 0.075)
		elif Lx.hitstop != null:
			Lx.hitstop.trigger(0.075)
		if Lx.camera != null and is_instance_valid(Lx.camera):
			Lx.camera.add_kick(Vector2.UP, 3.0)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(pos, 96.0, 1.05 if LxHudFx.flash_reduced() else 1.55, 0.48)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.18 if is_grand else 0.14)
	_emit_sfx("bridge_rise" if (door_type == "bridge_platform" or _is_light_bridge) else "door_open")
	if (door_type == "ward_barrier" or door_type == "bridge_platform") and LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 16.0, 6.5)
	if persist:
		_emit_save("door_" + id)
	queue_redraw()
	return true

func get_light_pool() -> Vector4:
	if not active: return Vector4.ZERO
	if _is_light_bridge and opened: return Vector4(pos.x, pos.y, 68.0, 1.15)
	if door_type == "bridge_platform" and opened: return Vector4(pos.x, pos.y, 46.0, 0.72)
	if not opened and door_type == "wick_key": return Vector4(pos.x, pos.y - 2.0, 34.0, 0.68 if _player_can_unlock_key_door() else 0.48)
	if not opened and (door_type == "boss_key" or door_type == "ward_barrier"): return Vector4(pos.x, pos.y - 4.0, 44.0, 0.75)
	return Vector4.ZERO

func is_solid() -> bool: return false if door_type == "bridge_platform" else (active and not opened)
func is_solid_blocker() -> bool: return is_solid()
func is_platform_solid() -> bool: return active and door_type == "bridge_platform" and opened
func get_platform_rect() -> Rect2: return Rect2(pos - size * 0.5, size) if is_platform_solid() else Rect2()
func get_solid_rect() -> Rect2: return Rect2(pos - size * 0.5, size) if is_solid() else Rect2()

func get_interact_prompt() -> String:
	if opened: return ""
	if door_type == "wick_key": return "PROMPT_UNLOCK_WICK_KEY" if _has_unlock_key() else ("PROMPT_DOOR_NEED_KEY" if LxStrings.has_id("PROMPT_DOOR_NEED_KEY") else "")
	if door_type == "boss_key": return "PROMPT_UNLOCK_BOSS_KEY" if _has_unlock_key() else ("PROMPT_DOOR_NEED_FLAME" if LxStrings.has_id("PROMPT_DOOR_NEED_FLAME") else "")
	return ""

func _has_unlock_key() -> bool:
	if Lx.state == null: return false
	return Lx.state.get_key_count(dungeon_id, "keepers_flame" if door_type == "boss_key" else "wick_key") > 0

func save_state() -> Dictionary:
	return {"active": active, "opened": opened, "signals": _active_signals.duplicate()}

func load_state(d: Dictionary) -> void:
	super.load_state(d)
	opened = bool(d.get("opened", opened))
	var sigs: Variant = d.get("signals", {})
	if sigs is Dictionary:
		_active_signals = (sigs as Dictionary).duplicate()
	if Lx.state != null and (Lx.state.opened_doors.has(id) or Lx.state.broken_seals.has(id)):
		opened = true
	queue_redraw()

func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var rattle_dx: float = (1.0 if int(floorf(_rattle_t * 36.0)) % 2 == 0 else -1.0) if (_rattle_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	var x0: float = floorf(-w * 0.5) + rattle_dx
	var y0: float = floorf(-h * 0.5)
	var sheet: LxSpriteSheet = _load_door_sheet()
	_uses_prop_anim = false
	if door_type == "bridge_platform":
		_draw_bridge(sheet, x0, y0, w, h)
		if _open_t > 0.0:
			_draw_open_burst(w, h)
		return
	if opened:
		_draw_opened_state(sheet, x0, y0, w, h)
		if _open_t > 0.0:
			_draw_parting_leaves(sheet, x0, y0, w, h)
			_draw_open_burst(w, h)
		return
	_draw_door_shadow(x0, y0, w, h, door_type == "boss_key")
	match door_type:
		"boss_key": _draw_boss_key(sheet, x0, y0, w, h, rattle_dx)
		"wick_key": _draw_wick_key(sheet, x0, y0, w, h, rattle_dx)
		"combat_gate": _draw_combat_gate(sheet, x0, y0, w, h, rattle_dx)
		"ward_barrier": _draw_ward_barrier(sheet, x0, y0, w, h, rattle_dx)
		_: _draw_switch_door(sheet, x0, y0, w, h, rattle_dx)

func _draw_sheet_prop(sheet: LxSpriteSheet, key: String, offset: Vector2, animated: bool = false) -> bool:
	if sheet != null and sheet.draw_prop(self, offset, key, _clock, Color.WHITE, -1):
		if animated:
			_uses_prop_anim = true
		return true
	return false

func _draw_door_shadow(x0: float, y0: float, w: float, h: float, is_boss: bool) -> void:
	var pad_x: float = -1.0 if is_boss else 1.0
	draw_rect(Rect2(x0 + pad_x, y0 + h, maxf(2.0, w - pad_x * 2.0), 2.0), PAL["void"] as Color)
	if h > w:
		draw_rect(Rect2(x0 + w, y0 + 2.0, 1.0, maxf(2.0, h - 1.0)), PAL["void"] as Color)

func _draw_bridge(sheet: LxSpriteSheet, x0: float, y0: float, w: float, h: float) -> void:
	var horiz: bool = w >= h
	if not opened:
		if sheet != null:
			_draw_bridge_caps(sheet, x0, y0, w, h, horiz)
		else:
			var aw: float = minf(5.0, w)
			_draw_fallback_box(x0, y0, aw, h, PAL["dusk"] as Color)
			_draw_fallback_box(x0 + w - aw, y0, aw, h, PAL["dusk"] as Color)
		return
	var ext_u: float = clampf((OPEN_DUR - _open_t) / 0.28, 0.0, 1.0) if _open_t > 0.0 else 1.0
	var cols: int = maxi(1, int(roundf(w / 16.0)))
	var rows: int = maxi(1, int(roundf(h / 16.0)))
	if ext_u < 1.0:
		var ew: float = maxf(6.0, roundf(w * ext_u)) if horiz else w
		var eh: float = h if horiz else maxf(6.0, roundf(h * ext_u))
		draw_rect(Rect2(x0, y0 + eh, ew, 2.0), PAL["void"] as Color)
		for ry: int in range(rows):
			var cy: float = minf(y0 + float(ry) * 16.0 + 8.0, y0 + h - 8.0)
			for rx: int in range(cols):
				var cx: float = minf(x0 + float(rx) * 16.0 + 8.0, x0 + w - 8.0)
				var frac_p: float = (float(rx) + 0.5) / float(cols) if horiz else (float(ry) + 0.5) / float(rows)
				if frac_p <= ext_u + 0.08:
					if sheet != null: _draw_sheet_prop(sheet, "bridge_tile", Vector2(cx, cy))
					else: _draw_fallback_box(cx - 8.0, cy - 8.0, 16.0, 16.0, LxBiomePalette.col(island_id, "mid"))
		if sheet != null: _draw_bridge_caps(sheet, x0, y0, w, h, horiz)
		return
	draw_rect(Rect2(x0, y0 + h, w, 2.0), PAL["void"] as Color)
	if sheet != null:
		for ry: int in range(rows):
			var cy: float = minf(y0 + float(ry) * 16.0 + 8.0, y0 + h - 8.0)
			for rx: int in range(cols):
				_draw_sheet_prop(sheet, "bridge_tile", Vector2(minf(x0 + float(rx) * 16.0 + 8.0, x0 + w - 8.0), cy))
		_draw_bridge_caps(sheet, x0, y0, w, h, horiz)
	else:
		_draw_fallback_box(x0, y0, w, h, LxBiomePalette.col(island_id, "mid"))

func _draw_bridge_caps(sheet: LxSpriteSheet, x0: float, y0: float, w: float, h: float, horiz: bool) -> void:
	if horiz:
		for ry: int in range(maxi(1, int(roundf(h / 16.0)))):
			var cy: float = minf(y0 + float(ry) * 16.0 + 8.0, y0 + h - 8.0)
			_draw_sheet_prop(sheet, "bridge_cap_h", Vector2(x0 + 4.0, cy))
			_draw_sheet_prop(sheet, "bridge_cap_h", Vector2(x0 + w - 4.0, cy))
	else:
		for rx: int in range(maxi(1, int(roundf(w / 16.0)))):
			var cx: float = minf(x0 + float(rx) * 16.0 + 8.0, x0 + w - 8.0)
			_draw_sheet_prop(sheet, "bridge_cap_v", Vector2(cx, y0 + 4.0))
			_draw_sheet_prop(sheet, "bridge_cap_v", Vector2(cx, y0 + h - 4.0))

func _draw_opened_state(sheet: LxSpriteSheet, x0: float, y0: float, w: float, h: float) -> void:
	var horiz: bool = w >= h
	if _is_light_bridge:
		if sheet != null:
			if horiz:
				for i: int in range(maxi(1, int(roundf(w / 32.0)))):
					_draw_sheet_prop(sheet, "light_bridge_h", Vector2(minf(x0 + float(i) * 32.0 + 16.0, x0 + w - 16.0), 0.0), true)
			else:
				for j: int in range(maxi(1, int(roundf(h / 16.0)))):
					_draw_sheet_prop(sheet, "light_bridge_v", Vector2(0.0, minf(y0 + float(j) * 16.0 + 8.0, y0 + h - 8.0)), true)
		else:
			_draw_fallback_box(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0, LxBiomePalette.col(island_id, "glow"))
	if sheet != null:
		if horiz:
			_draw_sheet_prop(sheet, "opened_jamb_h", Vector2.ZERO)
		else:
			_draw_sheet_prop(sheet, "opened_jamb_v_top", Vector2(0.0, y0 + 4.0))
			_draw_sheet_prop(sheet, "opened_jamb_v_bot", Vector2(0.0, y0 + h - 4.0))
	else:
		var jb: float = minf(4.0, floorf((w if horiz else h) * 0.25))
		_draw_fallback_box(x0, y0, jb if horiz else w, h if horiz else jb, PAL["dusk"] as Color)
		_draw_fallback_box(x0 + w - jb if horiz else x0, y0 if horiz else y0 + h - jb, jb if horiz else w, h if horiz else jb, PAL["dusk"] as Color)

func _draw_boss_key(sheet: LxSpriteSheet, x0: float, y0: float, w: float, h: float, rattle_dx: float) -> void:
	var drawn: bool = _draw_sheet_prop(sheet, "boss_key_h", Vector2(rattle_dx, 0.0), true) if w >= h else _draw_sheet_prop(sheet, "wick_key_v", Vector2(rattle_dx, 0.0))
	if not drawn:
		_draw_fallback_box(x0, y0, w, h, PAL["plum"] as Color)
	var ready_b: bool = _player_can_unlock_key_door()
	var cx: float = rattle_dx
	draw_rect(Rect2(cx - 3.0, -3.0, 6.0, 6.0), PAL["void"] as Color)
	if ready_b:
		var hot: bool = LxHudFx.flash_reduced() or (_pulse_stage % 2 == 0)
		draw_rect(Rect2(cx - 2.0, -2.0, 4.0, 4.0), PAL["coral"] as Color)
		draw_rect(Rect2(cx - 1.0, -3.0 if hot else -2.0, 2.0, 4.0 if hot else 3.0), PAL["gold"] as Color)
		draw_rect(Rect2(cx - 1.0, -1.0, 2.0, 2.0), PAL["cream"] as Color)
	else:
		draw_rect(Rect2(cx - 2.0, -2.0, 4.0, 4.0), PAL["plum"] as Color)
		draw_rect(Rect2(cx - 1.0, -1.0, 2.0, 2.0), PAL["night"] as Color)
	_draw_key_feedback(rattle_dx, 0.0, true)

func _draw_wick_key(sheet: LxSpriteSheet, x0: float, y0: float, w: float, h: float, rattle_dx: float) -> void:
	var drawn: bool = false
	if w >= h:
		drawn = _draw_sheet_prop(sheet, "wick_key_h", Vector2(rattle_dx, 0.0))
	elif h >= 40.0:
		drawn = _draw_sheet_prop(sheet, "wick_key_v", Vector2(rattle_dx, 0.0))
	else:
		drawn = _draw_vertical_modular(sheet, "switch_door_v_cap", "switch_door_v_mid", "switch_door_v_seal", y0, h, rattle_dx, false)
	if not drawn:
		_draw_fallback_box(x0, y0, w, h, PAL["wine"] as Color)
	_draw_key_feedback(rattle_dx, 0.0, false)

func _draw_key_feedback(cx: float, cy: float, is_boss: bool) -> void:
	if _rattle_t > 0.0:
		var rcol: Color = PAL["coral"] as Color if int(floorf(_rattle_t * 30.0)) % 2 == 0 else PAL["cream"] as Color
		draw_rect(Rect2(cx - 2.0, cy - 2.0, 4.0, 1.0), rcol)
		draw_rect(Rect2(cx - 2.0, cy + 2.0, 4.0, 1.0), rcol)
		return
	if not _player_can_unlock_key_door() or not (LxHudFx.flash_reduced() or (_pulse_stage % 2 == 0)):
		return
	var off: float = 5.0 if is_boss else 4.0
	draw_rect(Rect2(cx - off - 1.0, cy - 2.0, 1.0, 3.0), PAL["cream"] as Color)
	draw_rect(Rect2(cx - off - 2.0, cy - 1.0, 3.0, 1.0), PAL["gold"] as Color)
	draw_rect(Rect2(cx + off, cy - 2.0, 1.0, 3.0), PAL["cream"] as Color)
	draw_rect(Rect2(cx + off - 1.0, cy - 1.0, 3.0, 1.0), PAL["gold"] as Color)

func _draw_switch_door(sheet: LxSpriteSheet, x0: float, y0: float, w: float, h: float, rattle_dx: float) -> void:
	var drawn: bool = false
	if w > h:
		drawn = _draw_sheet_prop(sheet, "switch_door_h", Vector2(rattle_dx, 0.0), true)
	elif w <= 20.0 and h <= 20.0:
		drawn = _draw_sheet_prop(sheet, "switch_door_v_seal", Vector2(rattle_dx, 0.0), true)
	else:
		drawn = _draw_vertical_modular(sheet, "switch_door_v_cap", "switch_door_v_mid", "switch_door_v_seal", y0, h, rattle_dx, true)
	if not drawn:
		_draw_fallback_box(x0, y0, w, h, PAL["dusk"] as Color)
	var need: int = maxi(required_count, required_signals.size())
	if need > 1:
		_draw_pip_strip(x0, y0, w, h, _active_signals.size(), need, 1.0)

func _draw_combat_gate(sheet: LxSpriteSheet, x0: float, y0: float, w: float, h: float, rattle_dx: float) -> void:
	var drawn: bool = false
	if w > h:
		drawn = _draw_sheet_prop(sheet, "combat_gate_h", Vector2(rattle_dx, 0.0), true)
	elif w <= 20.0 and h <= 20.0:
		drawn = _draw_sheet_prop(sheet, "combat_gate_sq", Vector2(rattle_dx, 0.0), true)
	else:
		drawn = _draw_vertical_modular(sheet, "combat_gate_v_cap", "combat_gate_v_mid", "", y0, h, rattle_dx, true)
		if drawn:
			var pulse: bool = _rattle_t > 0.0 or (_pulse_stage % 2 == 0)
			draw_rect(Rect2(rattle_dx - 3.0, -3.0, 6.0, 6.0), PAL["void"] as Color)
			draw_rect(Rect2(rattle_dx - 2.0, -2.0, 4.0, 4.0), PAL["coral"] as Color if _rattle_t > 0.0 else LxBiomePalette.col(island_id, "mid"))
			draw_rect(Rect2(rattle_dx - 1.0, -1.0, 2.0, 2.0), PAL["cream"] as Color if pulse else LxBiomePalette.col(island_id, "glow"))
	if not drawn:
		_draw_fallback_box(x0, y0, w, h, PAL["night"] as Color)

func _draw_ward_barrier(sheet: LxSpriteSheet, x0: float, y0: float, w: float, h: float, rattle_dx: float) -> void:
	var drawn: bool = _draw_sheet_prop(sheet, "ward_barrier_h", Vector2(rattle_dx, 0.0), true) if w >= h else _draw_vertical_modular(sheet, "ward_barrier_v_cap", "ward_barrier_v_mid", "", y0, h, rattle_dx, true)
	if not drawn:
		_draw_fallback_box(x0, y0, w, h, LxBiomePalette.col(island_id, "dark"))
	_draw_ward_pips(x0, y0, w, h)

func _draw_vertical_modular(sheet: LxSpriteSheet, cap_key: String, mid_key: String, seal_key: String, y0: float, h: float, rattle_dx: float, animated: bool) -> bool:
	if sheet == null:
		return false
	var inner_h: float = maxf(0.0, h - 16.0)
	var mid_count: int = maxi(1, int(ceilf(inner_h / 16.0)))
	var ok: bool = false
	for i: int in range(mid_count):
		var cy: float = 0.0 if inner_h <= 16.0 else minf(y0 + 16.0 + float(i) * 16.0, y0 + h - 16.0)
		ok = _draw_sheet_prop(sheet, mid_key, Vector2(rattle_dx, cy), animated) or ok
	if not seal_key.is_empty():
		ok = _draw_sheet_prop(sheet, seal_key, Vector2(rattle_dx, 0.0), animated) or ok
	ok = _draw_sheet_prop(sheet, cap_key, Vector2(rattle_dx, y0 + 4.0)) or ok
	ok = _draw_sheet_prop(sheet, cap_key, Vector2(rattle_dx, y0 + h - 4.0)) or ok
	return ok

func _draw_pip_strip(x0: float, y0: float, w: float, h: float, got: int, need: int, y_off: float) -> void:
	var horiz: bool = w >= h
	var cx: float = floorf(x0 + w * 0.5)
	var cy: float = floorf(y0 + h * 0.5)
	var span_p: float = float(need - 1) * 5.0
	for pi: int in range(need):
		var lit_p: bool = pi < got
		var px: float = roundf(cx - span_p * 0.5 + float(pi) * 5.0) - 1.0 if horiz else cx - 1.0
		var py: float = y0 + y_off if horiz else roundf(cy - span_p * 0.5 + float(pi) * 5.0) - 1.0
		draw_rect(Rect2(px, py, 3.0, 3.0), PAL["void"] as Color)
		draw_rect(Rect2(px + 1.0, py + 1.0, 1.0, 1.0), PAL["cream"] as Color if lit_p else PAL["deep"] as Color)
		if lit_p:
			draw_rect(Rect2(px, py, 3.0, 1.0), PAL["gold"] as Color)

func _draw_ward_pips(x0: float, y0: float, w: float, h: float) -> void:
	var need: int = required_beacon_ids.size() if not required_beacon_ids.is_empty() else required_beacons
	if need <= 1 or Lx.state == null: return
	var got: int = 0
	if not required_beacon_ids.is_empty():
		for bid: String in required_beacon_ids:
			if Lx.state.lit_beacons.has(bid): got += 1
	else: got = mini(need, _count_island_beacons())
	_draw_pip_strip(x0, y0, w, h, got, need, -3.0)
	if got > 0 and got < need:
		var cx: float = floorf(x0 + w * 0.5); var cy: float = floorf(y0 + h * 0.5)
		var fc: Color = PAL["cream"] as Color if (LxHudFx.flash_reduced() or _pulse_stage % 2 == 0) else LxBiomePalette.col(island_id, "glow")
		if w >= h:
			draw_line(Vector2(cx - 2.0, y0 + 5.0), Vector2(cx - 5.0 - float(got) * 2.0, y0 + 8.0), fc, 1.0)
			if got >= 2:
				draw_line(Vector2(cx + 2.0, y0 + 5.0), Vector2(cx + 6.0, y0 + 3.0), fc, 1.0)
				draw_line(Vector2(cx + 6.0, y0 + 3.0), Vector2(cx + 9.0, y0 + 7.0), PAL["gold"] as Color, 1.0)
		else:
			draw_line(Vector2(cx - 3.0, cy - 4.0), Vector2(cx + 3.0, cy - 8.0 - float(got) * 2.0), fc, 1.0)
			if got >= 2: draw_line(Vector2(cx + 3.0, cy + 4.0), Vector2(cx - 3.0, cy + 9.0), PAL["gold"] as Color, 1.0)

func _player_can_unlock_key_door() -> bool:
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D): return false
	if (Lx.player as Node2D).global_position.distance_squared_to(pos) > 2704.0: return false
	return _has_unlock_key()

func _draw_fallback_box(x0: float, y0: float, w: float, h: float, fill: Color) -> void:
	draw_rect(Rect2(x0, y0, w, h), PAL["void"] as Color)
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, maxf(1.0, w - 2.0), maxf(1.0, h - 2.0)), PAL["night"] as Color)
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, maxf(1.0, w - 4.0), maxf(1.0, h - 4.0)), fill)

func _closed_leaf_key(w: float, h: float) -> String:
	match door_type:
		"boss_key": return "boss_key_h" if w >= h else "wick_key_v"
		"wick_key": return "wick_key_h" if w >= h else ("wick_key_v" if h >= 40.0 else "")
		"combat_gate": return "combat_gate_h" if w > h else ("combat_gate_sq" if (w <= 20.0 and h <= 20.0) else "")
		"ward_barrier": return "ward_barrier_h" if w >= h else ""
		_: return "switch_door_h" if w > h else ("switch_door_v_seal" if (w <= 20.0 and h <= 20.0) else "")

func _draw_parting_leaves(sheet: LxSpriteSheet, x0: float, y0: float, w: float, h: float) -> void:
	var el: float = OPEN_DUR - _open_t
	var horiz: bool = w >= h
	var start_d: float = 0.06 if door_type == "wick_key" else 0.0
	var p: float = clampf((el - start_d) / maxf(0.05, OPEN_DUR - start_d), 0.0, 1.0)
	var ease_p: float = 1.0 - pow(1.0 - p, 2.2)
	var col_gl: Color = LxBiomePalette.col(island_id, "glow")
	var cream: Color = PAL["cream"] as Color
	var key: String = _closed_leaf_key(w, h)
	var drew_tex: bool = false
	if sheet != null and sheet.tex != null and not key.is_empty() and sheet.props.has(key):
		var pinfo: Dictionary = sheet.props[key] as Dictionary
		var rects: Array = pinfo.get("rects", []) as Array
		if not rects.is_empty():
			var src: Rect2 = LxSpriteSheet._to_rect2(rects[0])
			var anc: Vector2 = LxSpriteSheet._to_vec2(pinfo.get("anchor", null), sheet.default_anchor)
			var ox: float = roundf(-anc.x); var oy: float = roundf(-anc.y)
			if horiz:
				var hw: float = floorf(src.size.x * 0.5); var slide: float = roundf(lerpf(0.0, hw * 0.94, ease_p)); var vw: float = maxf(0.0, hw - slide)
				if vw >= 1.0:
					draw_texture_rect_region(sheet.tex, Rect2(ox, oy, vw, src.size.y), Rect2(src.position.x + slide, src.position.y, vw, src.size.y))
					draw_texture_rect_region(sheet.tex, Rect2(ox + hw + slide, oy, vw, src.size.y), Rect2(src.position.x + hw, src.position.y, vw, src.size.y))
			else:
				var hh: float = floorf(src.size.y * 0.5); var slide_v: float = roundf(lerpf(0.0, hh * 0.94, ease_p)); var vh: float = maxf(0.0, hh - slide_v)
				if vh >= 1.0:
					draw_texture_rect_region(sheet.tex, Rect2(ox, oy, src.size.x, vh), Rect2(src.position.x, src.position.y + slide_v, src.size.x, vh))
					draw_texture_rect_region(sheet.tex, Rect2(ox, oy + hh + slide_v, src.size.x, vh), Rect2(src.position.x, src.position.y + hh, src.size.x, vh))
			drew_tex = true
	if not drew_tex:
		var fill_c: Color = PAL["plum"] as Color if door_type == "boss_key" else (PAL["wine"] as Color if door_type == "wick_key" else PAL["dusk"] as Color)
		if horiz:
			var hw2: float = floorf(w * 0.5); var vw2: float = maxf(0.0, hw2 - roundf(lerpf(0.0, hw2 * 0.92, ease_p)))
			if vw2 >= 2.0: _draw_fallback_box(x0, y0, vw2, h, fill_c); _draw_fallback_box(x0 + w - vw2, y0, vw2, h, fill_c)
		else:
			var hh2: float = floorf(h * 0.5); var vh2: float = maxf(0.0, hh2 - roundf(lerpf(0.0, hh2 * 0.92, ease_p)))
			if vh2 >= 2.0: _draw_fallback_box(x0, y0, w, vh2, fill_c); _draw_fallback_box(x0, y0 + h - vh2, w, vh2, fill_c)
	# Glowing seam crack between parting leaves
	if p < 0.78:
		var sa: float = clampf(1.0 - p / 0.78, 0.0, 1.0)
		var cw: float = maxf(1.0, roundf(lerpf(2.0, 5.0, minf(p * 2.5, 1.0)) * sa))
		if horiz:
			draw_rect(Rect2(-floorf(cw * 0.5) - 1.0, y0, cw + 2.0, h), Color(col_gl, sa * 0.70))
			draw_rect(Rect2(-floorf(cw * 0.5), y0, cw, h), Color(cream, sa))
		else:
			draw_rect(Rect2(x0, -floorf(cw * 0.5) - 1.0, w, cw + 2.0), Color(col_gl, sa * 0.70))
			draw_rect(Rect2(x0, -floorf(cw * 0.5), w, cw), Color(cream, sa))
	# 0.16s golden keyhole flash on wick_key unlock
	if door_type == "wick_key" and el < KEY_FLASH_DUR:
		var kf: float = 1.0 - clampf(el / KEY_FLASH_DUR, 0.0, 1.0)
		var arm: float = roundf(lerpf(3.0, 8.0, kf))
		draw_line(Vector2(-arm, 0.0), Vector2(arm, 0.0), Color(PAL["gold"] as Color, kf), 1.0)
		draw_line(Vector2(0.0, -arm), Vector2(0.0, arm), Color(PAL["gold"] as Color, kf), 1.0)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color(cream, kf))

func _draw_open_burst(w: float, h: float) -> void:
	var el: float = OPEN_DUR - _open_t
	var p: float = 1.0 - clampf(_open_t / OPEN_DUR, 0.0, 1.0)
	var is_grand: bool = door_type == "boss_key" or door_type == "ward_barrier" or door_type == "wick_key"
	var col: Color = LxBiomePalette.col(island_id, "glow")
	var hi: Color = PAL["cream"] as Color if is_grand else LxBiomePalette.col(island_id, "core")
	var fade: float = clampf(1.0 - p, 0.0, 1.0)
	if is_grand and el < 0.45:
		var sp_t: float = clampf(el / 0.45, 0.0, 1.0)
		var sp_f: float = fade * (0.68 if LxHudFx.flash_reduced() else 1.0)
		var y_top: float = roundf(-h * 0.15)
		var grow: float = minf(1.0, sp_t * 2.4)
		var y_out: float = roundf(h * 0.5 + lerpf(26.0, 34.0, grow))
		var y_in: float = roundf(h * 0.5 + lerpf(18.0, 27.0, grow))
		var hw_t: float = maxf(8.0, w * 0.40)
		var hw_b: float = maxf(20.0, w * 0.96 + sp_t * 10.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-hw_t, y_top), Vector2(hw_t, y_top), Vector2(hw_b, y_out), Vector2(-hw_b, y_out)]), Color(PAL["gold"] as Color, sp_f * 0.62))
		draw_colored_polygon(PackedVector2Array([Vector2(-hw_t * 0.62, y_top), Vector2(hw_t * 0.62, y_top), Vector2(hw_b * 0.60, y_in), Vector2(-hw_b * 0.60, y_in)]), Color(PAL["cream"] as Color, sp_f * 0.84))
		draw_line(Vector2(-hw_t, y_top), Vector2(-hw_b, y_out), Color(PAL["cream"] as Color, sp_f * 0.88), 1.0)
		draw_line(Vector2(hw_t, y_top), Vector2(hw_b, y_out), Color(PAL["cream"] as Color, sp_f * 0.88), 1.0)
	draw_arc(Vector2.ZERO, roundf(4.0 + p * maxf(w, h) * (0.72 if is_grand else 0.55)), 0.0, TAU, 18, Color(col if p > 0.35 else hi, fade), 2.0 if (is_grand and p < 0.35) else 1.0)
	var mote_n: int = 16 if is_grand else 6
	for i: int in range(mote_n):
		var a: float = float(i) * TAU / float(mote_n) + 0.25 + (p * 0.35 if is_grand else 0.0)
		var d: float = roundf(4.0 + p * (maxf(w, h) * (0.68 if is_grand else 0.45) + float(i % 3) * 4.5 + 7.0))
		var sy_bias: float = ((7.0 + p * 13.0) if (i % 2 == 0) else (p * 4.0)) if is_grand else 0.0
		var pt := Vector2(roundf(cos(a) * d), roundf(sin(a) * d * 0.65 + sy_bias))
		var sz: float = 2.0 if (is_grand and el < 0.45) else (2.0 if (p < 0.45 and i % 2 == 0) else 1.0)
		var mc: Color = ((PAL["cream"] if i % 2 == 0 else PAL["gold"]) as Color) if is_grand else (hi if i % 2 == 0 else col)
		draw_rect(Rect2(pt, Vector2(sz, sz)), Color(mc, fade))
		if is_grand and sz >= 2.0 and i % 3 == 0:
			draw_rect(Rect2(pt + Vector2(0.0, -1.0), Vector2.ONE), Color(PAL["cream"] as Color, fade))

static func _to_str_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for item: Variant in (v as Array):
			out.append(str(item))
	return out
