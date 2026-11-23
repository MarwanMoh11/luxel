class_name LxDoor
extends LxInteractable
## Multi-mode door / barrier:
## - ward_barrier: opens when required flags and/or beacon count are satisfied
## - wick_key: consumes one dungeon wick_key on interact
## - boss_key: consumes one dungeon keepers_flame on interact
## - combat_gate: opens when zone/room enemies are cleared
## - switch_door: opens when linked switches/braziers signal powered
## - bridge_platform: retractable bridge over pits; solid platform when opened, never a wall blocker

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


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	var raw_kind: String = str(spec.get("kind", "door")).strip_edges().to_lower()
	var default_type: String = "switch_door"
	match raw_kind:
		"ward_barrier", "wick_key", "boss_key", "combat_gate", "switch_door", "bridge_platform":
			default_type = raw_kind
		"locked_door":
			default_type = "wick_key"
		"boss_door":
			default_type = "boss_key"
	var raw_type: String = str(props.get("door_type", props.get("door_kind", default_type))).strip_edges().to_lower()
	match raw_type:
		"key_door", "locked_door":
			door_type = "wick_key"
		"boss_door":
			door_type = "boss_key"
		"shutter":
			door_type = "switch_door"
		"shortcut_door", "bridge_of_light":
			door_type = "ward_barrier"
		_:
			door_type = raw_type
	var raw_key: String = str(props.get("key_kind", "")).strip_edges().to_lower()
	if raw_key.is_empty():
		raw_key = str(props.get("key_id", "")).strip_edges().to_lower()
	if raw_key == "keepers_flame":
		door_type = "boss_key"
	elif raw_key == "wick_key" and door_type == "switch_door":
		door_type = "wick_key"
	kind = "door"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5 + 4.0
	dungeon_id = str(props.get("dungeon_id", "island_%d" % island_id))
	if dungeon_id.is_empty():
		dungeon_id = "island_%d" % island_id
	zone_id = str(props.get("zone", props.get("clear_zone", "")))
	var raw_beacons: Variant = props.get("requires_beacons", props.get("required_beacons", 0))
	required_beacon_ids = []
	required_beacons = 0
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
	if Lx.state != null and not id.is_empty():
		if Lx.state.opened_doors.has(id) or Lx.state.broken_seals.has(id):
			opened = true
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt)
		queue_redraw()
	if _rattle_t > 0.0:
		_rattle_t = maxf(0.0, _rattle_t - dt)
		queue_redraw()
	if not active:
		return
	if opened:
		if _is_light_bridge:
			var st_b: int = int(floorf(_clock * 4.0)) % 8
			if st_b != _pulse_stage:
				_pulse_stage = st_b
				queue_redraw()
		return
	if door_type == "ward_barrier":
		if _ward_requirements_met():
			_open(true)
			return
		var st: int = int(floorf(_clock * 2.5 + absf(pos.x * 0.02))) % 4
		if st != _pulse_stage:
			_pulse_stage = st
			queue_redraw()
	elif door_type == "combat_gate":
		if region != null and region.has_method("is_zone_cleared"):
			if bool(region.call("is_zone_cleared", zone_id)):
				_open(false)
				return
		var st_c: int = int(floorf(_clock * 3.2 + absf(pos.x * 0.03))) % 4
		if st_c != _pulse_stage:
			_pulse_stage = st_c
			queue_redraw()
	elif door_type == "wick_key" or door_type == "boss_key":
		var st_k: int = int(floorf(_clock * 3.0 + absf(pos.x * 0.02))) % 4
		if st_k != _pulse_stage and _player_can_unlock_key_door():
			_pulse_stage = st_k
			queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or opened:
		return false
	match door_type:
		"wick_key":
			if Lx.state != null:
				var kflag: String = str(props.get("key_id", ""))
				if Lx.state.consume_key(dungeon_id, "wick_key") \
						or (not kflag.is_empty() and bool(Lx.state.story_flags.get(kflag, false))):
					return _open(true)
		"boss_key":
			if Lx.state != null:
				var bflag: String = str(props.get("key_id", ""))
				if Lx.state.consume_key(dungeon_id, "keepers_flame") \
						or (not bflag.is_empty() and bool(Lx.state.story_flags.get(bflag, false))):
					return _open(true)
		"ward_barrier":
			if _ward_requirements_met():
				return _open(true)
	_rattle_t = 0.22
	_emit_sfx("door_locked")
	queue_redraw()
	return false


func on_signal(from_id: String, powered: bool) -> void:
	if not active or (door_type != "switch_door" and door_type != "bridge_platform"):
		return
	if powered:
		_active_signals[from_id] = true
	else:
		_active_signals.erase(from_id)
	if opened:
		return
	if not required_signals.is_empty():
		for req: String in required_signals:
			if not bool(_active_signals.get(req, false)):
				if powered:
					_rattle_t = 0.10
					queue_redraw()
				return
		_open(bool(props.get("persistent", true)))
	elif _active_signals.size() >= required_count:
		_open(bool(props.get("persistent", true)))
	elif powered:
		_rattle_t = 0.10
		queue_redraw()


func _ward_requirements_met() -> bool:
	if Lx.state == null:
		return false
	if not required_beacon_ids.is_empty():
		for bid: String in required_beacon_ids:
			if not Lx.state.lit_beacons.has(bid):
				return false
	elif required_beacons > 0 and Lx.state.lit_beacons.size() < required_beacons:
		return false
	for fl: String in required_flags:
		if region != null and region.has_method("is_flag_set"):
			if not bool(region.call("is_flag_set", fl)):
				return false
		elif not bool(Lx.state.story_flags.get(fl, false)) and not Lx.state.lit_beacons.has(fl):
			return false
	return true


func _open(persist: bool) -> bool:
	opened = true
	_open_t = 0.38
	if Lx.state != null:
		var flag_name: String = str(props.get("sets_flag", props.get("flag_id", "")))
		if not flag_name.is_empty():
			Lx.state.story_flags[flag_name] = true
		if persist and not id.is_empty():
			if not Lx.state.opened_doors.has(id):
				Lx.state.opened_doors.append(id)
			if door_type == "ward_barrier" and not Lx.state.broken_seals.has(id):
				Lx.state.broken_seals.append(id)
	if door_type == "ward_barrier" and Lx.events != null:
		Lx.events.seal_broken.emit(island_id, id)
	else:
		_emit_gust(maxf(size.x, size.y) + 22.0, 42.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.14)
	_emit_sfx("bridge_rise" if (door_type == "bridge_platform" or _is_light_bridge) else "door_open")
	if (door_type == "ward_barrier" or door_type == "bridge_platform") and LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 16.0, 6.5)
	if persist:
		_emit_save("door_" + id)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if _is_light_bridge and opened:
		return Vector4(pos.x, pos.y, 68.0, 1.15)
	if door_type == "bridge_platform" and opened:
		return Vector4(pos.x, pos.y, 46.0, 0.72)
	if not opened and (door_type == "boss_key" or door_type == "ward_barrier"):
		return Vector4(pos.x, pos.y - 4.0, 44.0, 0.75)
	return Vector4.ZERO


func is_solid() -> bool:
	if door_type == "bridge_platform":
		return false
	return active and not opened


func is_solid_blocker() -> bool:
	return is_solid()


func is_platform_solid() -> bool:
	return active and door_type == "bridge_platform" and opened


func get_platform_rect() -> Rect2:
	if not is_platform_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func get_interact_prompt() -> String:
	if opened:
		return ""
	if door_type == "wick_key":
		return "PROMPT_UNLOCK_WICK_KEY"
	if door_type == "boss_key":
		return "PROMPT_UNLOCK_BOSS_KEY"
	return ""


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
	if not opened and door_type == "ward_barrier" and size.x <= 40.0 and size.y <= 24.0:
		if _draw_prop_sprite("ward_barrier", Vector2(rattle_dx, 0.0)):
			_draw_ward_pips(x0, y0, w)
			return
	_uses_prop_anim = false
	if door_type == "bridge_platform":
		_draw_bridge(x0, y0, w, h)
		if _open_t > 0.0:
			_draw_open_burst(w, h)
		return
	if opened:
		var horiz: bool = w >= h
		var j: float = minf(4.0, floorf((w if horiz else h) * 0.25))
		if _is_light_bridge:
			_draw_light_bridge_glow(x0, y0, w, h, horiz)
		_draw_pier(x0, y0, j if horiz else w, h if horiz else j, false)
		_draw_pier(x0 + w - j if horiz else x0, y0 if horiz else y0 + h - j, j if horiz else w, h if horiz else j, false)
		if _open_t > 0.0:
			_draw_open_burst(w, h)
		return
	match door_type:
		"combat_gate": _draw_combat_gate(x0, y0, w, h)
		"wick_key": _draw_key_door(x0, y0, w, h, false)
		"boss_key": _draw_key_door(x0, y0, w, h, true)
		"ward_barrier": _draw_ward_barrier(x0, y0, w, h)
		_: _draw_switch_door(x0, y0, w, h)


func _draw_frame(x0: float, y0: float, w: float, h: float, fill: Color) -> void:
	draw_rect(Rect2(x0, y0, w, h), PAL["void"])
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["night"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0), fill)


func _draw_bridge(x0: float, y0: float, w: float, h: float) -> void:
	var horiz: bool = w >= h
	if not opened:
		var aw: float = minf(5.0, (w if horiz else h) * 0.25)
		_draw_pier(x0, y0, aw if horiz else w, h if horiz else aw, true)
		_draw_pier(x0 + w - aw if horiz else x0, y0 if horiz else y0 + h - aw, aw if horiz else w, h if horiz else aw, true)
		return
	draw_rect(Rect2(x0, y0 + 1.0, w, h), PAL["void"])
	_draw_frame(x0, y0, w, h, PAL["plum"] as Color)
	var span: float = (w if horiz else h) - 4.0
	var p: float = 0.0
	var idx: int = 0
	while p < span:
		var seg: float = minf(5.0, span - p)
		var pc: Color = (PAL["wine"] if idx % 2 == 0 else PAL["plum"]) as Color
		if horiz:
			draw_rect(Rect2(x0 + 2.0 + p, y0 + 3.0, seg, h - 6.0), pc)
			draw_rect(Rect2(x0 + 2.0 + p, y0 + 3.0, seg, 1.0), PAL["mauve"])
			draw_rect(Rect2(x0 + 1.0 + p + seg, y0 + 3.0, 1.0, h - 6.0), PAL["night"])
		else:
			draw_rect(Rect2(x0 + 3.0, y0 + 2.0 + p, w - 6.0, seg), pc)
			draw_rect(Rect2(x0 + 3.0, y0 + 2.0 + p, 1.0, seg), PAL["mauve"])
			draw_rect(Rect2(x0 + 3.0, y0 + 1.0 + p + seg, w - 6.0, 1.0), PAL["night"])
		p += 5.0
		idx += 1
	if horiz:
		for ry: float in [y0 + 1.0, y0 + h - 3.0]:
			draw_rect(Rect2(x0, ry, w, 2.0), PAL["apricot"])
			draw_rect(Rect2(x0, ry, w, 1.0), PAL["gold"])
		var rx: float = x0 + 6.0
		while rx < x0 + w - 4.0:
			draw_rect(Rect2(rx, y0 + 2.0, 1.0, 1.0), PAL["night"])
			draw_rect(Rect2(rx, y0 + h - 2.0, 1.0, 1.0), PAL["night"])
			rx += 6.0
	else:
		for rx2: float in [x0 + 1.0, x0 + w - 3.0]:
			draw_rect(Rect2(rx2, y0, 2.0, h), PAL["apricot"])
			draw_rect(Rect2(rx2, y0, 1.0, h), PAL["gold"])
	for cp: Vector2 in [Vector2(x0, y0), Vector2(x0 + w - 3.0, y0), Vector2(x0, y0 + h - 3.0), Vector2(x0 + w - 3.0, y0 + h - 3.0)]:
		draw_rect(Rect2(cp, Vector2(3.0, 3.0)), PAL["night"])
		draw_rect(Rect2(cp + Vector2(1.0, 0.0), Vector2(1.0, 1.0)), PAL["gold"])
		draw_rect(Rect2(cp + Vector2(1.0, 1.0), Vector2(1.0, 1.0)), PAL["cream"])


func _draw_pier(x: float, y: float, w: float, h: float, mooring: bool) -> void:
	draw_rect(Rect2(x, y, w, h), PAL["void"])
	draw_rect(Rect2(x + 1.0, y + 1.0, maxf(1.0, w - 2.0), maxf(1.0, h - 2.0)), PAL["night"])
	draw_rect(Rect2(x + 1.0, y + 1.0, maxf(1.0, w - 2.0), maxf(1.0, h - 3.0)), PAL["dusk"])
	draw_rect(Rect2(x + 1.0, y + 1.0, maxf(1.0, w - 2.0), 1.0), PAL["stone"])
	draw_rect(Rect2(x + 1.0, y + 1.0, 1.0, maxf(1.0, h - 3.0)), PAL["mauve"])
	if mooring:
		draw_rect(Rect2(floorf(x + w * 0.5) - 1.0, floorf(y + h * 0.5) - 1.0, 2.0, 2.0), PAL["night"])


func _draw_combat_gate(x0: float, y0: float, w: float, h: float) -> void:
	draw_rect(Rect2(x0, y0, w, h), PAL["void"])
	_draw_pier(x0, y0, 3.0, h, false)
	_draw_pier(x0 + w - 3.0, y0, 3.0, h, false)
	var bx: float = x0 + 5.0
	while bx <= x0 + w - 5.0:
		draw_rect(Rect2(bx, y0 + 1.0, 2.0, h - 2.0), PAL["night"])
		draw_rect(Rect2(bx, y0 + 1.0, 1.0, h - 3.0), PAL["dusk"])
		draw_rect(Rect2(bx, y0 + h - 3.0, 1.0, 1.0), PAL["stone"])
		bx += 4.0
	var cx: float = floorf(x0 + w * 0.5)
	var cy: float = floorf(y0 + h * 0.5) - 2.0
	draw_rect(Rect2(x0 + 2.0, cy, w - 4.0, 4.0), PAL["night"])
	draw_rect(Rect2(x0 + 2.0, cy, w - 4.0, 1.0), PAL["dusk"])
	draw_rect(Rect2(cx - 3.0, cy - 1.0, 6.0, 6.0), PAL["void"])
	draw_rect(Rect2(cx - 2.0, cy, 4.0, 4.0), PAL["coral"] if _rattle_t > 0.0 else PAL["wine"])
	draw_rect(Rect2(cx - 1.0, cy + 1.0, 2.0, 2.0), PAL["cream"] if _rattle_t > 0.0 else (PAL["apricot"] if _pulse_stage == 0 else PAL["coral"]))
	draw_rect(Rect2(cx - 1.0, cy + 1.0, 1.0, 1.0), PAL["cream"] if (_rattle_t > 0.0 or _pulse_stage == 0) else PAL["apricot"])


func _draw_key_door(x0: float, y0: float, w: float, h: float, is_boss: bool) -> void:
	_draw_frame(x0, y0, w, h, PAL["plum"] as Color)
	var cx: float = floorf(x0 + w * 0.5)
	var cy: float = floorf(y0 + h * 0.5)
	var pad: float = 4.0 if is_boss else 3.0
	var lw: float = maxf(2.0, cx - x0 - pad - 1.0)
	var rw: float = maxf(2.0, x0 + w - cx - pad - 1.0)
	draw_rect(Rect2(x0 + pad, y0 + 3.0, lw, h - 6.0), PAL["wine"])
	draw_rect(Rect2(cx + 1.0, y0 + 3.0, rw, h - 6.0), PAL["wine"])
	draw_rect(Rect2(cx - 1.0, y0 + 1.0, 2.0, h - 2.0), PAL["void"] if is_boss else PAL["night"])
	var ready_glint: bool = _rattle_t <= 0.0 and _player_can_unlock_key_door() and (LxHudFx.flash_reduced() or (_pulse_stage % 2 == 0))
	if is_boss:
		draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 1.0), PAL["cream"] if ready_glint else PAL["gold"])
		draw_rect(Rect2(x0 + 2.0, y0 + h - 3.0, w - 4.0, 1.0), PAL["gold"] if ready_glint else PAL["apricot"])
		for bx: float in [x0 + 6.0, x0 + w - 9.0]:
			draw_rect(Rect2(bx, cy - 2.0, 3.0, 4.0), PAL["gold"] if ready_glint else PAL["apricot"])
			draw_rect(Rect2(bx, cy - 2.0, 2.0, 1.0), PAL["cream"])
			draw_rect(Rect2(bx + 1.0, cy + 2.0, 1.0, 1.0), PAL["gold"])
		LxHudFx.draw_biome_crest(self, island_id, Vector2(x0 + 7.0, y0 + 2.0), LxBiomePalette.col(island_id, "glow"), PAL["cream"] as Color)
		LxHudFx.draw_biome_crest(self, island_id, Vector2(x0 + w - 8.0, y0 + 2.0), LxBiomePalette.col(island_id, "glow"), PAL["cream"] as Color)
		draw_rect(Rect2(cx - 4.0, cy - 4.0, 8.0, 8.0), PAL["void"])
		draw_rect(Rect2(cx - 3.0, cy - 3.0, 6.0, 6.0), PAL["coral"] if _rattle_t > 0.0 else (PAL["cream"] if ready_glint else PAL["gold"]))
		draw_rect(Rect2(cx - 2.0, cy - 2.0, 4.0, 4.0), PAL["cream"] if _rattle_t > 0.0 else (PAL["gold"] if ready_glint else PAL["coral"]))
		draw_rect(Rect2(cx - 1.0, cy - 2.0, 2.0, 4.0), PAL["cream"])
	else:
		draw_rect(Rect2(x0 + 3.0, y0 + 3.0, lw, 1.0), PAL["rose"])
		draw_rect(Rect2(cx + 1.0, y0 + 3.0, rw, 1.0), PAL["rose"])
		draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 2.0), PAL["gold"] if ready_glint else PAL["apricot"])
		draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 1.0), PAL["cream"] if ready_glint else PAL["gold"])
		draw_rect(Rect2(x0 + 2.0, y0 + h - 4.0, w - 4.0, 2.0), PAL["apricot"])
		draw_rect(Rect2(cx - 3.0, cy - 3.0, 6.0, 7.0), PAL["void"])
		draw_rect(Rect2(cx - 2.0, cy - 2.0, 4.0, 5.0), PAL["coral"] if _rattle_t > 0.0 else (PAL["gold"] if ready_glint else PAL["apricot"]))
		draw_rect(Rect2(cx - 2.0, cy - 2.0, 4.0, 1.0), PAL["cream"] if ready_glint else PAL["gold"])
		draw_rect(Rect2(cx - 1.0, cy - 1.0, 2.0, 2.0), PAL["cream"])
		draw_rect(Rect2(cx - 1.0, cy + 1.0, 2.0, 2.0), PAL["gold"])


func _draw_switch_door(x0: float, y0: float, w: float, h: float) -> void:
	_draw_frame(x0, y0, w, h, PAL["dusk"] as Color)
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 1.0), PAL["stone"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, 1.0, h - 4.0), PAL["mauve"])
	var cx: float = floorf(x0 + w * 0.5)
	var cy: float = floorf(y0 + h * 0.5)
	var sd_lo: Color = LxBiomePalette.col(island_id, "dark")
	var sd_mid: Color = LxBiomePalette.col(island_id, "mid")
	var sd_hi: Color = LxBiomePalette.col(island_id, "hi")
	var sd_gl: Color = LxBiomePalette.col(island_id, "glow")
	draw_rect(Rect2(x0 + 3.0, cy - 1.0, w - 6.0, 3.0), sd_lo)
	draw_rect(Rect2(x0 + 4.0, cy, w - 8.0, 1.0), sd_mid)
	draw_rect(Rect2(x0 + 4.0, cy, 2.0, 1.0), sd_hi)
	draw_rect(Rect2(x0 + w - 6.0, cy, 2.0, 1.0), sd_hi)
	draw_rect(Rect2(cx - 4.0, cy - 3.0, 8.0, 7.0), PAL["void"])
	draw_rect(Rect2(cx - 3.0, cy - 2.0, 6.0, 5.0), sd_lo)
	draw_rect(Rect2(cx - 2.0, cy - 1.0, 4.0, 3.0), sd_mid)
	draw_rect(Rect2(cx - 1.0, cy - 1.0, 2.0, 2.0), sd_hi)
	draw_rect(Rect2(cx - 1.0, cy - 1.0, 1.0, 1.0), sd_gl)
	var need: int = maxi(required_count, required_signals.size())
	if need > 1:
		var got: int = _active_signals.size()
		var span_p: float = float(need - 1) * 5.0
		for pi: int in range(need):
			var px: float = roundf(cx - span_p * 0.5 + float(pi) * 5.0) - 1.0
			var lit_p: bool = pi < got
			draw_rect(Rect2(px, y0 + 2.0, 3.0, 3.0), PAL["void"])
			draw_rect(Rect2(px + 1.0, y0 + 3.0, 1.0, 1.0), PAL["cream"] if lit_p else PAL["deep"])
			if lit_p:
				draw_rect(Rect2(px, y0 + 2.0, 3.0, 1.0), PAL["gold"])


func _draw_ward_barrier(x0: float, y0: float, w: float, h: float) -> void:
	var wa: Color = LxBiomePalette.col(island_id, "ward_a")
	var wb: Color = LxBiomePalette.col(island_id, "ward_b")
	var whi: Color = LxBiomePalette.col(island_id, "ward_hi")
	_draw_frame(x0, y0, w, h, LxBiomePalette.col(island_id, "dark"))
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 1.0), wb)
	draw_rect(Rect2(x0 + 2.0, y0 + h - 3.0, w - 4.0, 1.0), wa)
	var rx: float = x0 + 5.0
	var cy: float = floorf(y0 + h * 0.5)
	var idx: int = 0
	while rx < x0 + w - 5.0:
		var lit_r: bool = (idx + _pulse_stage) % 2 == 0
		draw_line(Vector2(rx, y0 + 2.0), Vector2(rx + 2.0, cy), wa, 1.0)
		draw_line(Vector2(rx + 2.0, cy), Vector2(rx, y0 + h - 3.0), wb, 1.0)
		draw_rect(Rect2(rx + 1.0, y0 + 4.0, 1.0, maxf(1.0, h - 8.0)), whi if lit_r else wb)
		if lit_r:
			draw_rect(Rect2(rx + 1.0, cy, 1.0, 1.0), PAL["cream"])
		rx += 5.0
		idx += 1
	_draw_pier(x0, y0, 4.0, h, false)
	_draw_pier(x0 + w - 4.0, y0, 4.0, h, false)
	var cx_w: float = floorf(x0 + w * 0.5)
	LxHudFx.draw_biome_crest(self, island_id, Vector2(cx_w, cy), whi, PAL["cream"] as Color)
	_draw_ward_pips(x0, y0, w)


func _player_can_unlock_key_door() -> bool:
	if Lx.state == null or Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return false
	if (Lx.player as Node2D).global_position.distance_squared_to(pos) > 2704.0:
		return false
	var kflag: String = str(props.get("key_id", ""))
	if not kflag.is_empty() and bool(Lx.state.story_flags.get(kflag, false)):
		return true
	var kk: String = "keepers_flame" if door_type == "boss_key" else "wick_key"
	return Lx.state.get_key_count(dungeon_id, kk) > 0


func _draw_ward_pips(x0: float, y0: float, w: float) -> void:
	var need: int = required_beacon_ids.size() if not required_beacon_ids.is_empty() else required_beacons
	if need <= 1 or Lx.state == null:
		return
	var got: int = 0
	if not required_beacon_ids.is_empty():
		for bid: String in required_beacon_ids:
			if Lx.state.lit_beacons.has(bid):
				got += 1
	else:
		got = mini(need, Lx.state.lit_beacons.size())
	var cx: float = floorf(x0 + w * 0.5)
	var span_p: float = float(need - 1) * 5.0
	for pi: int in range(need):
		var px: float = roundf(cx - span_p * 0.5 + float(pi) * 5.0) - 1.0
		var lit_p: bool = pi < got
		draw_rect(Rect2(px, y0 - 2.0, 3.0, 3.0), PAL["void"])
		draw_rect(Rect2(px + 1.0, y0 - 1.0, 1.0, 1.0), PAL["cream"] if lit_p else PAL["deep"])
		if lit_p:
			draw_rect(Rect2(px, y0 - 2.0, 3.0, 1.0), PAL["gold"])
	# Progressive ward-fracture cracks widening across the barrier as 1/3 -> 2/3 beacons ignite!
	if got > 0 and got < need:
		var fc: Color = PAL["cream"] as Color if (LxHudFx.flash_reduced() or _pulse_stage % 2 == 0) else LxBiomePalette.col(island_id, "glow")
		var cy_f: float = y0 + 5.0
		draw_line(Vector2(cx - 2.0, cy_f), Vector2(cx - 5.0 - float(got) * 2.0, cy_f + 3.0), fc, 1.0)
		if got >= 2:
			draw_line(Vector2(cx + 2.0, cy_f), Vector2(cx + 6.0, cy_f - 2.0), fc, 1.0)
			draw_line(Vector2(cx + 6.0, cy_f - 2.0), Vector2(cx + 9.0, cy_f + 2.0), PAL["gold"] as Color, 1.0)


func _draw_light_bridge_glow(x0: float, y0: float, w: float, h: float, horiz: bool) -> void:
	var c_edge: Color = LxBiomePalette.col(island_id, "hi")
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var c_core: Color = LxBiomePalette.col(island_id, "core")
	if horiz:
		draw_rect(Rect2(x0 + 3.0, y0 + 2.0, maxf(2.0, w - 6.0), 1.0), c_edge)
		draw_rect(Rect2(x0 + 3.0, y0 + h - 3.0, maxf(2.0, w - 6.0), 1.0), c_edge)
		var sx: float = x0 + 5.0
		var idx: int = 0
		while sx < x0 + w - 5.0:
			var hi: bool = (idx + _pulse_stage) % 3 == 0
			draw_rect(Rect2(sx, y0 + 3.0, 2.0, maxf(1.0, h - 6.0)), c_glow if hi else c_edge)
			sx += 4.0
			idx += 1
	else:
		draw_rect(Rect2(x0 + 2.0, y0 + 3.0, 1.0, maxf(2.0, h - 6.0)), c_edge)
		draw_rect(Rect2(x0 + w - 3.0, y0 + 3.0, 1.0, maxf(2.0, h - 6.0)), c_edge)
		var sy: float = y0 + 5.0
		var idx2: int = 0
		while sy < y0 + h - 5.0:
			var hi2: bool = (idx2 + _pulse_stage) % 3 == 0
			draw_rect(Rect2(x0 + 3.0, sy, maxf(1.0, w - 6.0), 2.0), c_glow if hi2 else c_edge)
			sy += 4.0
			idx2 += 1
	var step_count: int = 4
	for i: int in range(step_count):
		var frac: float = fmod(float(i) / float(step_count) + float(_pulse_stage) * 0.125, 1.0)
		var mx: float = roundf(x0 + 4.0 + frac * maxf(4.0, w - 8.0)) if horiz else roundf(x0 + w * 0.5 + sin(_clock * 2.5 + float(i)) * maxf(2.0, w * 0.25))
		var my: float = roundf(y0 + h * 0.5 + sin(_clock * 2.5 + float(i)) * maxf(2.0, h * 0.25)) if horiz else roundf(y0 + 4.0 + frac * maxf(4.0, h - 8.0))
		draw_rect(Rect2(mx - 1.0, my - 1.0, 2.0, 2.0), c_core if (i + _pulse_stage) % 2 == 0 else c_glow)


func _draw_open_burst(w: float, h: float) -> void:
	var p: float = 1.0 - clampf(_open_t / 0.38, 0.0, 1.0)
	var col: Color = LxBiomePalette.col(island_id, "glow")
	var hi: Color = LxBiomePalette.col(island_id, "core")
	var rad: float = roundf(4.0 + p * maxf(w, h) * 0.55)
	draw_arc(Vector2.ZERO, rad, 0.0, TAU, 16, col if p > 0.35 else hi, 1.0)
	for i: int in range(6):
		var a: float = float(i) * TAU / 6.0 + 0.35
		var d: float = roundf(3.0 + p * (maxf(w, h) * 0.45 + 6.0))
		var pt := Vector2(roundf(cos(a) * d), roundf(sin(a) * d * 0.7))
		draw_rect(Rect2(pt, Vector2(2.0 if p < 0.45 else 1.0, 2.0 if p < 0.45 else 1.0)), hi if i % 2 == 0 else col)


static func _to_str_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for item: Variant in (v as Array):
			out.append(str(item))
	return out
