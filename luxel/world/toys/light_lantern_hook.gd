class_name LxLanternHook
extends LxToy
## Wrought-iron lantern hook: hang Wick's lantern here as a permanent fixed light until recalled or taken.
## Props: light_radius (float, default 84.0), persist (bool), target_id/target_ids.

var light_radius: float = 84.0
var hooked: bool = false
var _hook_cd: float = 0.0
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "lantern_hook"
	light_radius = maxf(36.0, float(props.get("light_radius", 84.0)))
	radius = maxf(12.0, radius)
	hooked = powered
	_hook_cd = 0.0
	_pulse_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if hooked:
		unhook(true)


func tick(dt: float) -> void:
	super.tick(dt)
	if _hook_cd > 0.0:
		_hook_cd = maxf(0.0, _hook_cd - dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()
	if not active:
		return
	var lan: LxLantern = _get_wick_lantern()
	if hooked:
		if lan != null:
			# If Wick recalled, caught, or had the lantern stolen, release hook cleanly
			if lan.state != LxLantern.State.HANGING:
				unhook(false)
			else:
				# Pin lantern indefinitely on the hook without timer expiry
				lan.pos = pos
				lan.prev_pos = pos
				lan.global_position = pos.round()
				lan.hang_timer = lan.hang_max
				lan.vel = Vector2.ZERO
	elif lan != null and _hook_cd <= 0.0:
		# Catch a thrown or hanging lantern placed directly onto the hook
		if (lan.state == LxLantern.State.FLYING or lan.state == LxLantern.State.HANGING) and lan.pos.distance_to(pos) <= 14.0:
			hook_lantern(lan)


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or hooked or _hook_cd > 0.0:
		return false
	if hit.source == LxHit.SOURCE_THROW:
		var lan: LxLantern = _get_wick_lantern()
		if lan != null:
			hook_lantern(lan)
			return true
	return false


func interact(_actor: Node = null) -> bool:
	if not active or _hook_cd > 0.0:
		return false
	var lan: LxLantern = _get_wick_lantern()
	if hooked:
		unhook(true)
		return true
	if lan != null and lan.is_in_hand():
		hook_lantern(lan)
		return true
	if lan == null:
		# Standalone / headless fallback without Wick lantern
		hooked = true
		_pulse_t = 0.35
		set_powered(true)
		emit_power(true)
		_emit_sfx("lantern_land")
		queue_redraw()
		return true
	return false


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "PROMPT_TAKE_LANTERN" if hooked else "PROMPT_HANG_LANTERN"


func hook_lantern(lan: LxLantern) -> void:
	hooked = true
	_hook_cd = 0.25
	_pulse_t = 0.35
	if lan != null:
		lan.state = LxLantern.State.HANGING
		lan.pos = pos
		lan.prev_pos = pos
		lan.global_position = pos.round()
		lan.vel = Vector2.ZERO
		lan.hang_timer = lan.hang_max
		lan.queue_redraw()
	set_powered(true)
	emit_power(true)
	_emit_sfx("lantern_land")
	_emit_gust(42.0, 26.0)
	queue_redraw()


func unhook(return_to_wick: bool) -> void:
	hooked = false
	_hook_cd = 0.30
	if return_to_wick and Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if w.lantern != null and is_instance_valid(w.lantern):
			w.lantern.catch_by_wick(w)
	set_powered(false)
	emit_power(false)
	queue_redraw()


func _get_wick_lantern() -> LxLantern:
	if Lx.player != null and is_instance_valid(Lx.player):
		var lv: Variant = Lx.player.get("lantern")
		if lv is LxLantern and is_instance_valid(lv):
			return lv as LxLantern
	return null


func get_light_pool() -> Vector4:
	if not active or not hooked:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, light_radius, 1.05)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var trip: Array[Color] = LxToyDraw.skin_triplet(island_id, skin)

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 6.0, 2.0)
	# Stone base + wrought-iron shepherd's post
	LxToyDraw.draw_bevel_box(self, Rect2(-5.0, 1.0, 10.0, 5.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["stone"] as Color, c_void)
	draw_rect(Rect2(-4.0, -14.0, 3.0, 16.0), c_void)
	draw_rect(Rect2(-3.0, -13.0, 1.0, 14.0), PAL["stone"] as Color)
	# Curved top hook arm
	draw_rect(Rect2(-3.0, -15.0, 8.0, 3.0), c_void)
	draw_rect(Rect2(-2.0, -14.0, 6.0, 1.0), c_glow if hooked else trip[2])
	draw_rect(Rect2(3.0, -13.0, 2.0, 3.0), c_void)
	draw_rect(Rect2(3.0, -13.0, 1.0, 2.0), PAL["gold"] as Color)

	if hooked:
		# Sculpted hanging brass lantern + warm aura
		draw_circle(Vector2(3.0, -7.0), 9.0, Color(c_glow, 0.16))
		draw_rect(Rect2(-1.0, -11.0, 8.0, 9.0), c_void)
		draw_rect(Rect2(0.0, -10.0, 6.0, 1.0), PAL["dusk"] as Color)
		draw_rect(Rect2(0.0, -9.0, 6.0, 6.0), PAL["apricot"] as Color)
		draw_rect(Rect2(1.0, -8.0, 4.0, 4.0), PAL["gold"] as Color)
		draw_rect(Rect2(2.0, -7.0, 2.0, 2.0), PAL["cream"] as Color)
		draw_rect(Rect2(0.0, -3.0, 6.0, 1.0), PAL["dusk"] as Color)
		if _pulse_t > 0.0:
			var u: float = 1.0 - clampf(_pulse_t / 0.35, 0.0, 1.0)
			draw_arc(Vector2(3.0, -7.0), roundf(lerpf(4.0, 14.0, u)), 0.0, TAU, 14, PAL["cream"] as Color, 1.0)
	else:
		# Subtle invite glint on empty hook
		draw_rect(Rect2(3.0, -10.0, 1.0, 1.0), PAL["cream"] as Color)
	_draw_signal_pulses()
