class_name LxCrashThrottleHook
extends LxToy
## Bridge toy in `crash_r3` (Locomotive Roof Duel):
## Connects room Master Throttle `pull_ring` signals to `hollow_ram_phantom.on_throttle_lock()`
## and displays a twin-throttle locomotive pressure gauge.

var ring_ids: PackedStringArray = PackedStringArray()
var _locked_map: Dictionary = {}
var _flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "crash_throttle_hook"
	size = Vector2(28.0, 14.0)
	radius = 14.0
	ring_ids = PackedStringArray()
	var raw: Variant = props.get("ring_ids", ["pull_crash_r3_1", "pull_crash_r3_2"])
	if raw is Array:
		for item: Variant in (raw as Array):
			var s: String = str(item).strip_edges()
			if not s.is_empty():
				ring_ids.append(s)
	_locked_map.clear()
	_flash_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and powered:
		return
	_locked_map.clear()
	_flash_t = 0.0
	set_powered(false)
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func on_signal(from_id: String, is_on: bool) -> void:
	super.on_signal(from_id, is_on)
	if not active or not is_on or from_id.is_empty():
		return
	if bool(_locked_map.get(from_id, false)):
		return
	_locked_map[from_id] = true
	_flash_t = 0.45
	_emit_sfx("steam_whistle")
	if Lx.events != null and LxStrings.has_id("ISL6_CRASH_LOCK"):
		Lx.events.narration_requested.emit("ISL6_CRASH_LOCK", "narration", 2.4)
	# Forward throttle lock to live Iron Phantom boss for instant stagger + bonus damage
	if region != null and region.has_method("get_enemies"):
		for e_v: Variant in (region.call("get_enemies") as Array):
			if e_v is Object and is_instance_valid(e_v as Object) and (e_v as Object).has_method("on_throttle_lock"):
				(e_v as Object).call("on_throttle_lock", pos, from_id)
	var need: int = maxi(1, ring_ids.size())
	if _locked_map.size() >= need:
		set_powered(true)
		emit_power(true)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var n: int = _locked_map.size()
	return Vector4(pos.x, pos.y, 44.0 if n > 0 else 28.0, 0.72 if n > 0 else 0.40)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_cream: Color = PAL["cream"] as Color

	LxToyDraw.draw_bevel_box(self, Rect2(-14.0, -7.0, 28.0, 14.0), c_night, c_dusk, c_gold if powered else PAL["stone"] as Color, c_void)
	var cnt: int = maxi(2, ring_ids.size())
	for i: int in range(cnt):
		var rid: String = ring_ids[i] if i < ring_ids.size() else ""
		var on: bool = bool(_locked_map.get(rid, false)) or powered
		var rx: float = -8.0 + float(i) * 12.0
		draw_rect(Rect2(rx, -3.0, 6.0, 6.0), c_void)
		draw_rect(Rect2(rx + 1.0, -2.0, 4.0, 4.0), c_gold if on else c_coral)
		if on:
			draw_rect(Rect2(rx + 2.0, -1.0, 2.0, 2.0), c_cream)
	if _flash_t > 0.0:
		var u: float = 1.0 - clampf(_flash_t / 0.45, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(6.0 + u * 24.0), 0.0, TAU, 16, c_gold, 1.4)
		draw_arc(Vector2.ZERO, roundf(4.0 + u * 15.0), 0.0, TAU, 14, c_cream, 1.0)
	# Live locomotive exhaust surge plumes when throttles lock
	var n_on: int = _locked_map.size()
	if n_on > 0 and not LxHudFx.flash_reduced():
		for si: int in range(n_on * 3):
			var sx: float = -12.0 - fposmod(_clock * 48.0 + float(si * 13), 26.0)
			var sy: float = -4.0 + float(si % 3) * 4.0
			draw_rect(Rect2(roundf(sx), roundf(sy), 4.0, 2.0), c_gold if si % 2 == 0 else PAL["apricot"] as Color)
	_draw_signal_pulses()
