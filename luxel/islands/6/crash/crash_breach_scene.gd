class_name LxCrashBreachScene
extends LxToy
## Wordless 1.5s breach spectacle in `crash_r4` (The Obsidian Breach).
## Dynamically slams the brass Ember Express locomotive prow into the Great Kiln's
## Obsidian Dam on arrival, shattering obsidian debris in an expanding golden shockwave,
## setting `crash_done` permanently, and showering apricot embers from the smoking stack.

var sets_flag: String = "crash_done"
var _anim_t: float = 0.0
var _slammed: bool = false
var _slam_flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "crash_breach_scene"
	z_index = 1
	size = Vector2(68.0, 36.0)
	radius = 20.0
	sets_flag = str(props.get("sets_flag", "crash_done")).strip_edges()
	var already: bool = not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false))
	_slammed = already
	_anim_t = 1.5 if already else 0.0
	_slam_flash_t = 0.0
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
	if _slam_flash_t > 0.0:
		_slam_flash_t = maxf(0.0, _slam_flash_t - dt)
	if not _slammed:
		_anim_t += dt
		if _anim_t >= 0.45:
			_slammed = true
			_slam_flash_t = 0.85
			if not sets_flag.is_empty() and Lx.state != null:
				Lx.state.story_flags[sets_flag] = true
				Lx.state.story_flags["dungeon_done:iron_collision"] = true
			_emit_sfx("magma_crack")
			_emit_sfx("steam_whistle")
			if Lx.events != null:
				Lx.events.shake_requested.emit(0.12 if LxHudFx.flash_reduced() else 0.28)
				if LxStrings.has_id("ISL6_CRASH_BREACH"):
					Lx.events.narration_requested.emit("ISL6_CRASH_BREACH", "title", 3.2)
				Lx.events.save_requested.emit("crash_done")
			if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
				LxDarknessLayer.active_instance.add_burst_light(pos, 112.0, 1.35, 0.45)
			set_powered(true)
			emit_power(true)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 76.0 if _slam_flash_t > 0.0 else 64.0, 0.95 if _slam_flash_t > 0.0 else 0.72)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var fred: bool = LxHudFx.flash_reduced()

	# Locomotive prow slide-in before 0.45s impact slam
	var slide_y: float = 0.0 if _slammed else roundf(lerpf(36.0, 0.0, clampf(_anim_t / 0.45, 0.0, 1.0)))
	var split_x: float = 4.0 if _slammed else 0.0

	LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 12.0 + slide_y * 0.4), 32.0, 7.0)
	# Shattered Obsidian Dam slabs splitting outward on breach
	LxToyDraw.draw_bevel_box(self, Rect2(-34.0 - split_x, -14.0, 14.0, 24.0), c_void, c_night, c_dusk, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(20.0 + split_x, -14.0, 14.0, 24.0), c_void, c_night, c_dusk, c_void)
	if _slammed:
		# Glowing fractured magma veins inside cracked dam edges
		draw_rect(Rect2(-24.0 - split_x, -10.0, 2.0, 16.0), c_coral)
		draw_rect(Rect2(22.0 + split_x, -10.0, 2.0, 16.0), c_coral)

	# Smoking brass Ember Express locomotive boiler nose wedged into the breach
	LxToyDraw.draw_bevel_box(self, Rect2(-21.0, -13.0 + slide_y, 42.0, 24.0), c_night, c_wine, c_apr, c_void)
	# Brass smokestack funnel at crown
	draw_rect(Rect2(-5.0, -18.0 + slide_y, 10.0, 6.0), c_void)
	draw_rect(Rect2(-4.0, -17.0 + slide_y, 8.0, 5.0), c_dusk)
	draw_rect(Rect2(-5.0, -18.0 + slide_y, 10.0, 2.0), c_gold)
	# Brass cowcatcher grate bars at front
	for bx: float in [-15.0, -8.0, 0.0, 8.0, 15.0]:
		draw_rect(Rect2(bx - 1.0, 7.0 + slide_y, 2.0, 7.0), c_gold)
	draw_rect(Rect2(-17.0, 12.0 + slide_y, 34.0, 2.0), c_apr)
	# Blazing cyclops headlamp + warm beam
	draw_circle(Vector2(0.0, -2.0 + slide_y), 6.5, c_void)
	draw_circle(Vector2(0.0, -2.0 + slide_y), 5.0, c_gold)
	draw_circle(Vector2(0.0, -2.0 + slide_y), 2.8, c_cream)

	# Expanding golden impact shockwave + flying obsidian shards during breach slam
	if _slam_flash_t > 0.0:
		var u: float = 1.0 - clampf(_slam_flash_t / 0.85, 0.0, 1.0)
		var sa: float = (1.0 - u) * (0.45 if fred else 0.85)
		draw_arc(Vector2(0.0, -2.0), roundf(lerpf(10.0, 62.0, u)), 0.0, TAU, 22, Color(c_gold, sa), 2.2)
		draw_arc(Vector2(0.0, -2.0), roundf(lerpf(6.0, 44.0, u)), 0.0, TAU, 18, Color(c_cream, sa * 0.85), 1.4)
		for si: int in range(6):
			var ang: float = float(si) * (TAU / 6.0) + 0.35
			var sp: Vector2 = Vector2(cos(ang), sin(ang)) * lerpf(12.0, 46.0, u)
			draw_rect(Rect2(sp.round() - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(c_dusk if si % 2 == 0 else c_coral, sa))

	# Billowing steam & rising apricot cinder embers from smokestack
	if not fred:
		for k: int in range(8):
			var ex: float = -18.0 + float(k) * 5.2 + sin(_clock * 2.4 + float(k)) * 2.5
			var ey: float = -14.0 - fposmod(_clock * 15.0 + float(k) * 4.5, 22.0)
			draw_rect(Rect2(roundf(ex), roundf(ey), 2.0, 2.0), c_cream if k == 3 else (c_apr if k % 2 == 0 else c_coral))
	_draw_signal_pulses()
