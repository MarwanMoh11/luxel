class_name LxLevMawSwallow
extends LxToy
## Leviathan Harbor-Mouth Jaws (`lev_maw_swallow`, `leviathan_r2`):
## Looms shut across the eastern breakwater mouth until the Chum Bell triggers `on_signal`.
## Opening reveals a warm amber gullet, plays `whale_groan_low`, and forwards power to
## unbar the jaw exit so Wick sails deliberately straight into the whale (`leviathan_r3`).

var state: String = "closed" # "closed" | "open"
var sets_flag: String = "lev_maw_open"
var _open_t: float = 0.0


func _toy_setup() -> void:
	kind = "lev_maw_swallow"
	z_index = -2
	size = _parse_size(props.get("size", [40.0, 64.0]), Vector2(40.0, 64.0))
	radius = 24.0
	sets_flag = str(props.get("sets_flag", "lev_maw_open")).strip_edges()
	if not props.has("persist"):
		persist = true
	var already: bool = powered or (not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false)))
	state = "open" if already else "closed"
	powered = already
	_open_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and state == "open":
		return
	state = "closed"
	powered = false
	_open_t = 0.0
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func on_signal(_from_id: String, is_on: bool) -> void:
	if not active or not is_on or state == "open":
		return
	state = "open"
	_open_t = 0.70
	if not sets_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag] = true
	set_powered(true)
	emit_power(true)
	_emit_sfx("whale_groan_low")
	_emit_sfx("tide_surge")
	_emit_gust(84.0, 64.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.24)
		if LxStrings.has_id("LEV_SWALLOW"):
			Lx.events.narration_requested.emit("LEV_SWALLOW", "narration", 3.2)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 110.0, 1.45, 0.45)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt)
		queue_redraw()
	elif int(floorf(_clock * 3.0)) != int(floorf((_clock - dt) * 3.0)):
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if state == "open":
		return Vector4(pos.x, pos.y, 92.0, 1.05)
	return Vector4(pos.x, pos.y, 38.0, 0.35)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["open"] = state == "open"
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("open", false)):
		state = "open"
		powered = true
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var hw: float = floorf(size.x * 0.5)
	var hh: float = floorf(size.y * 0.5)
	var jaw_gap: float = 20.0 if state == "open" else 3.0
	if state == "open" and _open_t > 0.0:
		jaw_gap = lerpf(3.0, 20.0, 1.0 - clampf(_open_t / 0.70, 0.0, 1.0))
	# Warm glowing amber gullet & inward suction motes when jaws part
	var red: bool = LxHudFx.flash_reduced()
	if state == "open":
		draw_rect(Rect2(-hw + 4.0, -jaw_gap, size.x - 8.0, jaw_gap * 2.0), PAL["wine"] as Color)
		draw_rect(Rect2(-hw + 8.0, -jaw_gap + 4.0, size.x - 16.0, maxf(4.0, jaw_gap * 2.0 - 8.0)), c_apricot)
		draw_rect(Rect2(-hw + 12.0, -jaw_gap + 8.0, size.x - 24.0, maxf(2.0, jaw_gap * 2.0 - 16.0)), c_gold)
		# Welcoming inward chevrons + warm inward current motes
		var shift: float = 0.0 if red else fmod(_clock * 18.0, 12.0)
		LxPhysDraw.draw_chevron(self, Vector2(-14.0 + shift, 0.0), Vector2.RIGHT, c_cream, c_void, 3.0)
		LxPhysDraw.draw_chevron(self, Vector2(-4.0 + shift * 0.5, 0.0), Vector2.RIGHT, c_gold, c_void, 2.5)
		for mi: int in range(4):
			var mu: float = fmod(_clock * 0.85 + float(mi) * 0.25, 1.0)
			var mx: float = roundf(lerpf(-hw - 16.0, 4.0, mu))
			var my: float = roundf((float(mi) - 1.5) * 8.0 * (1.0 - mu * 0.6))
			draw_rect(Rect2(mx, my, 2.0, 1.0), c_cream if mi % 2 == 0 else c_gold)
	elif not red:
		# Subtle rhythmic gill-mist puffs while jaws loom closed
		var pu: float = fmod(_clock * 0.55, 1.0)
		draw_arc(Vector2(-hw - 4.0 - pu * 10.0, 0.0), roundf(2.0 + pu * 6.0), 0.0, TAU, 10, Color(PAL["sky"] as Color, (1.0 - pu) * 0.55), 1.0)
	# Upper & lower colossal whale jaw silhouettes
	var top_y: float = -hh
	var top_h: float = maxf(8.0, hh - jaw_gap)
	var bot_y: float = jaw_gap
	var bot_h: float = maxf(8.0, hh - jaw_gap)
	LxPhysDraw.draw_bevel_box(self, Rect2(-hw, top_y, size.x, top_h), c_deep, PAL["blue"] as Color, c_void, c_void)
	LxPhysDraw.draw_bevel_box(self, Rect2(-hw, bot_y, size.x, bot_h), c_deep, c_dusk, c_void, c_void)
	# Baleen / ivory teeth along jaw lips
	var tx: float = -hw + 5.0
	while tx < hw - 5.0:
		draw_rect(Rect2(tx, top_y + top_h - 1.0, 3.0, 4.0), c_stone)
		draw_rect(Rect2(tx, bot_y - 3.0, 3.0, 4.0), c_stone)
		tx += 7.0
	# Whale eye gleaming on upper brow
	var eye_c: Color = c_cream if state == "open" else c_gold
	draw_rect(Rect2(-6.0, top_y + 4.0, 5.0, 4.0), c_void)
	draw_rect(Rect2(-5.0, top_y + 5.0, 3.0, 2.0), eye_c)
	_draw_signal_pulses()
