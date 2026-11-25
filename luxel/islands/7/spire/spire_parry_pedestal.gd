class_name LxSpireParryPedestal
extends LxToy
## Island 7 Mirror Spire r16 Mirror-Parry Practice Pedestal:
## Teaches Hollow Wick Phase 3's Stolen Lantern Clash safely before the boss door!
## Interact to launch a slow telegraphed Dark Lantern orb; shoot or Zip-intercept it
## mid-flight to trigger a celebratory golden clash ring and set `spire_r16_parry_done`.
## Props: sets_flag (String, default "spire_r16_parry_done"), target_id/target_ids.

var sets_flag: String = "spire_r16_parry_done"
var orb_active: bool = false
var orb_pos: Vector2 = Vector2.ZERO
var orb_vel: Vector2 = Vector2.ZERO
var orb_t: float = 0.0
var _clash_t: float = 0.0
var _clash_pos: Vector2 = Vector2.ZERO


func _toy_setup() -> void:
	kind = "spire_parry_pedestal"
	sets_flag = str(props.get("sets_flag", "spire_r16_parry_done")).strip_edges()
	radius = 16.0
	size = Vector2(18.0, 16.0)
	orb_active = false
	orb_t = 0.0
	_clash_t = 0.0
	powered = not sets_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false))
	queue_redraw()


func reset_toy() -> void:
	orb_active = false
	orb_t = 0.0
	_clash_t = 0.0
	queue_redraw()


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-7.0, -4.0), Vector2(14.0, 9.0)) if active else Rect2()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_launch_practice_orb()
	return true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		if orb_active:
			_complete_clash()
			return true
		_launch_practice_orb()
		return true
	return false


func _launch_practice_orb() -> void:
	orb_active = true
	orb_pos = pos + Vector2(0.0, -10.0)
	orb_vel = Vector2(46.0, 0.0)
	orb_t = 2.6
	_emit_sfx("mirror_ping")
	queue_redraw()


func _complete_clash() -> void:
	orb_active = false
	orb_t = 0.0
	_clash_t = 0.75
	_clash_pos = orb_pos
	if not sets_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag] = true
	set_powered(true)
	emit_power(true)
	_emit_sfx("spire_parry_clang")
	if Lx.events != null and LxStrings.has_id("ISL7_SP_PARRY_OK"):
		Lx.events.narration_requested.emit("ISL7_SP_PARRY_OK", "gold", 2.4)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_ring(_clash_pos, 4.0, 28.0, 0.34, PAL["gold"] as Color, 1.5)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _clash_t > 0.0:
		_clash_t = maxf(0.0, _clash_t - dt); dirty = true
	if orb_active:
		orb_t = maxf(0.0, orb_t - dt)
		orb_pos += orb_vel * dt
		if orb_pos.x > pos.x + 52.0 or orb_pos.x < pos.x - 52.0:
			orb_vel.x = -orb_vel.x
		# Check Wick bolts, lantern, or Zip-dash intercepting the floating dark lantern!
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if w.global_position.distance_to(orb_pos) <= 18.0 and (w.is_dashing() or w.zipping):
				_complete_clash()
			else:
				for bi: int in range(w.bolts.size() - 1, -1, -1):
					var bv: Variant = w.bolts[bi]
					if bv is Object and (bv.get("pos") as Vector2).distance_to(orb_pos) <= 14.0:
						w.bolts.remove_at(bi)
						_complete_clash()
						break
		if orb_t <= 0.0:
			orb_active = false
		dirty = true
	if dirty:
		queue_redraw()


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "ISL7_SP_PROMPT_PARRY" if LxStrings.has_id("ISL7_SP_PROMPT_PARRY") else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 36.0 if powered else 26.0, 0.56 if powered else 0.36)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_coral: Color = PAL["coral"] as Color

	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 5.0), 8.0, 2.5, "se_gold", false)
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -3.0, 16.0, 8.0), c_night, c_plum, c_gold if powered else c_ice, c_void)
	draw_rect(Rect2(-2.0, -10.0, 4.0, 7.0), c_void)
	draw_rect(Rect2(-1.0, -9.0, 2.0, 5.0), c_gold if powered else c_ice)
	if orb_active:
		var op: Vector2 = (orb_pos - pos).round()
		draw_circle(op, 6.0, c_void)
		draw_arc(op, 6.0, 0.0, TAU, 16, c_coral, 1.5)
		draw_circle(op, 2.5, c_rose)
		draw_rect(Rect2(op - Vector2.ONE, Vector2(2.0, 2.0)), c_cream)
	if _clash_t > 0.0:
		var cp: Vector2 = (_clash_pos - pos).round()
		var u: float = 1.0 - clampf(_clash_t / 0.75, 0.0, 1.0)
		draw_arc(cp, roundf(lerpf(4.0, 22.0, u)), 0.0, TAU, 16, Color(c_cream, 1.0 - u), 1.5)
	_draw_signal_pulses()
