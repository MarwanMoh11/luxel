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
	if Lx.state != null and not id.is_empty():
		if Lx.state.opened_doors.has(id) or Lx.state.broken_seals.has(id):
			opened = true
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active or opened:
		return
	if door_type == "ward_barrier":
		if _ward_requirements_met():
			_open(true)
	elif door_type == "combat_gate":
		if region != null and region.has_method("is_zone_cleared"):
			if bool(region.call("is_zone_cleared", zone_id)):
				_open(false)


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
	_emit_sfx("door_locked")
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
				return
		_open(bool(props.get("persistent", true)))
	elif _active_signals.size() >= required_count:
		_open(bool(props.get("persistent", true)))


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
	_emit_sfx("door_open")
	if persist:
		_emit_save("door_" + id)
	queue_redraw()
	return true


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
	var half: Vector2 = size * 0.5
	if door_type == "bridge_platform":
		if opened:
			draw_rect(Rect2(-half, size), PAL["night"])
			draw_rect(Rect2(-half + Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), PAL["wine"])
			draw_rect(Rect2(-half.x, -half.y, size.x, 2.0), PAL["gold"])
			draw_rect(Rect2(-half.x, half.y - 2.0, size.x, 2.0), PAL["gold"])
			var px: float = -half.x + 6.0
			while px < half.x - 2.0:
				draw_line(Vector2(px, -half.y + 2.0), Vector2(px, half.y - 2.0), PAL["plum"], 1.0)
				px += 6.0
		else:
			draw_rect(Rect2(-half.x, -half.y, 2.0, size.y), PAL["dusk"])
			draw_rect(Rect2(half.x - 2.0, -half.y, 2.0, size.y), PAL["dusk"])
		return
	if opened:
		draw_rect(Rect2(-half.x, -half.y, 3.0, size.y), PAL["dusk"])
		draw_rect(Rect2(half.x - 3.0, -half.y, 3.0, size.y), PAL["dusk"])
		return
	var fill_col: Color = PAL["plum"]
	var trim_col: Color = PAL["gold"]
	match door_type:
		"ward_barrier":
			fill_col = PAL["deep"]
			trim_col = PAL["ice"]
		"wick_key":
			fill_col = PAL["wine"]
			trim_col = PAL["gold"]
		"boss_key":
			fill_col = PAL["coral"]
			trim_col = PAL["cream"]
		"combat_gate":
			fill_col = PAL["dusk"]
			trim_col = PAL["coral"]
		"switch_door":
			fill_col = PAL["dusk"]
			trim_col = PAL["sky"]
	draw_rect(Rect2(-half, size), PAL["night"])
	draw_rect(Rect2(-half + Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), fill_col)
	draw_rect(Rect2(-half + Vector2(2.0, 2.0), Vector2(size.x - 4.0, 2.0)), trim_col)
	draw_circle(Vector2.ZERO, 3.0, trim_col)


static func _to_str_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for item: Variant in (v as Array):
			out.append(str(item))
	return out
