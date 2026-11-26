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
	elif hooked and not LxHudFx.flash_reduced():
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
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var red: bool = LxHudFx.flash_reduced()
	var tw: int = 0 if red else int(floorf(_clock * 5.0)) % 2

	# Grounded contact shadow
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 2.8)

	# Bevelled 3/4 stone plinth base + brass collar shoe
	draw_rect(Rect2(-7.0, 0.0, 14.0, 7.0), c_void)
	draw_rect(Rect2(-6.0, 4.0, 12.0, 2.0), c_night)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 3.0), c_dusk)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 1.0), c_stone)
	draw_rect(Rect2(-6.0, 2.0, 1.0, 2.0), c_mauve)
	draw_rect(Rect2(-6.0, -1.0, 6.0, 3.0), c_void)
	draw_rect(Rect2(-5.0, 0.0, 4.0, 1.0), c_apricot)
	draw_rect(Rect2(-5.0, 0.0, 2.0, 1.0), c_gold)

	# Chunky wrought-iron / brass shepherd's vertical post with brass bands
	draw_rect(Rect2(-6.0, -15.0, 5.0, 15.0), c_void)
	draw_rect(Rect2(-5.0, -14.0, 3.0, 14.0), c_dusk)
	draw_rect(Rect2(-5.0, -14.0, 1.0, 14.0), c_stone)
	draw_rect(Rect2(-3.0, -14.0, 1.0, 14.0), c_night)
	# Brass ferrule bands on post
	draw_rect(Rect2(-5.0, -6.0, 3.0, 1.0), c_apricot)
	draw_rect(Rect2(-5.0, -6.0, 1.0, 1.0), c_gold)
	draw_rect(Rect2(-5.0, -12.0, 3.0, 1.0), c_apricot)
	draw_rect(Rect2(-5.0, -12.0, 1.0, 1.0), c_gold)

	# Decorative wrought-iron scroll bracket under the overhanging arm
	draw_rect(Rect2(-2.0, -12.0, 4.0, 4.0), c_void)
	draw_rect(Rect2(-1.0, -11.0, 2.0, 1.0), c_mauve)
	draw_rect(Rect2(-2.0, -10.0, 2.0, 1.0), c_gold if hooked else c_stone)
	draw_rect(Rect2(0.0, -12.0, 2.0, 1.0), c_gold if hooked else c_apricot)

	# Curved overhanging shepherd's crook arm + brass hook tip
	draw_rect(Rect2(-5.0, -17.0, 10.0, 4.0), c_void)
	draw_rect(Rect2(-4.0, -16.0, 8.0, 2.0), c_dusk)
	draw_rect(Rect2(-4.0, -16.0, 7.0, 1.0), c_gold if hooked else c_stone)
	draw_rect(Rect2(-3.0, -16.0, 3.0, 1.0), c_cream if hooked else c_gold)
	draw_rect(Rect2(3.0, -15.0, 4.0, 5.0), c_void)
	draw_rect(Rect2(4.0, -14.0, 2.0, 3.0), c_apricot)
	draw_rect(Rect2(4.0, -14.0, 1.0, 2.0), c_gold)
	# Up-curled hook tip
	draw_rect(Rect2(2.0, -12.0, 3.0, 2.0), c_void)
	draw_rect(Rect2(3.0, -11.0, 2.0, 1.0), c_gold)

	if hooked:
		var lc := Vector2(4.0, -6.0)
		# Soft layered warm aura + dithered glow pips
		draw_circle(lc, 11.0, Color(c_glow, 0.16))
		draw_circle(lc, 7.0, Color(c_gold, 0.24))
		var pip_pts: Array[Vector2] = [
			Vector2(-4.0, -8.0), Vector2(12.0, -7.0), Vector2(4.0, -15.0),
			Vector2(10.0, -2.0), Vector2(-2.0, -2.0), Vector2(11.0, -11.0),
		]
		for i: int in range(pip_pts.size()):
			var bright: bool = red or ((i + tw) % 2 == 0)
			var pp: Vector2 = pip_pts[i] + Vector2(0.0, -1.0 if (not red and bright) else 0.0)
			draw_rect(Rect2(pp, Vector2.ONE), c_cream if bright else c_gold)
		# Sculpted hanging brass & amber glass lantern silhouette
		draw_rect(Rect2(3.0, -11.0, 2.0, 2.0), c_gold) # bail ring
		draw_rect(Rect2(1.0, -10.0, 6.0, 2.0), c_void)
		draw_rect(Rect2(2.0, -9.0, 4.0, 1.0), c_gold) # dome cap
		draw_rect(Rect2(0.0, -9.0, 8.0, 9.0), c_void)
		draw_rect(Rect2(1.0, -8.0, 6.0, 1.0), c_wine)
		draw_rect(Rect2(1.0, -8.0, 5.0, 1.0), c_apricot)
		draw_rect(Rect2(1.0, -7.0, 6.0, 5.0), c_apricot)
		draw_rect(Rect2(2.0, -7.0, 4.0, 4.0), c_gold)
		draw_rect(Rect2(3.0, -6.0, 2.0, 3.0), c_cream)
		# Vertical brass lantern cage ribs
		draw_rect(Rect2(1.0, -7.0, 1.0, 5.0), c_wine)
		draw_rect(Rect2(6.0, -7.0, 1.0, 5.0), c_wine)
		# Flared brass lantern base
		draw_rect(Rect2(1.0, -2.0, 6.0, 1.0), c_apricot)
		draw_rect(Rect2(2.0, -2.0, 4.0, 1.0), c_gold)
		if _pulse_t > 0.0:
			var u: float = 1.0 - clampf(_pulse_t / 0.35, 0.0, 1.0)
			draw_arc(lc, roundf(lerpf(4.0, 14.0, u)), 0.0, TAU, 14, c_cream, 1.0)
	else:
		# Subtle inviting brass ring & glint on empty shepherd's crook
		draw_rect(Rect2(3.0, -10.0, 3.0, 3.0), c_void)
		draw_rect(Rect2(4.0, -9.0, 1.0, 1.0), c_cream if (red or tw == 0) else c_gold)
	_draw_signal_pulses()
