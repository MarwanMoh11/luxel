class_name LxCrashBreachScene
extends LxToy
## Wordless 1.5s breach spectacle in `crash_r4` (The Obsidian Breach).
## Renders the wrecked brass Ember Express cowcatcher wedged into the shattered Great Kiln
## Obsidian Dam, showering apricot cinders and setting `crash_done` permanently on entry.

var sets_flag: String = "crash_done"
var _anim_t: float = 0.0
var _slammed: bool = false


func _toy_setup() -> void:
	kind = "crash_breach_scene"
	z_index = 1
	size = Vector2(68.0, 36.0)
	radius = 20.0
	sets_flag = str(props.get("sets_flag", "crash_done")).strip_edges()
	var already: bool = not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false))
	_slammed = already
	_anim_t = 1.5 if already else 0.0
	if already:
		set_powered(true)
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if not _slammed:
		_anim_t += dt
		if _anim_t >= 0.45:
			_slammed = true
			if not sets_flag.is_empty() and Lx.state != null:
				Lx.state.story_flags[sets_flag] = true
				Lx.state.story_flags["dungeon_done:iron_collision"] = true
			_emit_sfx("magma_crack")
			_emit_sfx("steam_whistle")
			if Lx.events != null:
				Lx.events.shake_requested.emit(0.10 if LxHudFx.flash_reduced() else 0.24)
				if LxStrings.has_id("ISL6_CRASH_BREACH"):
					Lx.events.narration_requested.emit("ISL6_CRASH_BREACH", "title", 3.2)
				Lx.events.save_requested.emit("crash_done")
			if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
				LxDarknessLayer.active_instance.add_burst_light(pos, 96.0, 1.25, 0.38)
			set_powered(true)
			emit_power(true)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 64.0, 0.72)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 12.0), 30.0, 7.0)
	# Shattered Obsidian Dam slabs left & right
	LxToyDraw.draw_bevel_box(self, Rect2(-34.0, -14.0, 14.0, 24.0), c_void, c_night, c_dusk, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(20.0, -14.0, 14.0, 24.0), c_void, c_night, c_dusk, c_void)
	# Smoking brass Ember Express locomotive boiler nose wedged in center
	LxToyDraw.draw_bevel_box(self, Rect2(-20.0, -12.0, 40.0, 22.0), c_night, c_wine, c_apr, c_void)
	# Brass cowcatcher grate bars at front
	for bx: float in [-14.0, -7.0, 0.0, 7.0, 14.0]:
		draw_rect(Rect2(bx - 1.0, 6.0, 2.0, 7.0), c_gold)
	draw_rect(Rect2(-16.0, 11.0, 32.0, 2.0), c_apr)
	# Blazing headlight cyclops eye
	draw_circle(Vector2(0.0, -2.0), 6.0, c_void)
	draw_circle(Vector2(0.0, -2.0), 4.5, c_gold)
	draw_circle(Vector2(0.0, -2.0), 2.5, c_cream)
	# Rising apricot cinder embers (flash-reduced safe)
	if not LxHudFx.flash_reduced():
		for k: int in range(6):
			var ex: float = -18.0 + float(k) * 7.2 + sin(_clock * 2.2 + float(k)) * 2.0
			var ey: float = -10.0 - fposmod(_clock * 14.0 + float(k) * 5.0, 18.0)
			draw_rect(Rect2(roundf(ex), roundf(ey), 2.0, 2.0), c_apr if k % 2 == 0 else c_coral)
	_draw_signal_pulses()
