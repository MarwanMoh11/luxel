class_name LxTollClapperRig
extends LxToy
## Island 1 Set Piece (`toll_r1`): The Great Bell Clapper Rigging & wordless Hollow Wick cameo.
## Interact (`E`) to fit the Stolen Clapper into the Great Bell:
## - Emits a golden chime wave, reveals Hollow Wick's dark silhouette on the upper rafters firing
##   one violet bolt to sever the master rope, sets `hollow_cameo_1`, shakes the shaft, and opens
##   the linked drop door to `toll_r2`.
## - Instant-retry safe: if `hollow_cameo_1` is already set, skips the cameo and stays open.
## Props: target_id/target_ids, flag_id (default "hollow_cameo_1"), persist (bool).

enum Stage { READY, CAMEO, SEVERED }

const CAMEO_DUR: float = 1.15

var stage: int = Stage.READY
var flag_id: String = "hollow_cameo_1"
var _cameo_t: float = 0.0
var _bolt_fired: bool = false


func _toy_setup() -> void:
	kind = "toll_clapper_rig"
	flag_id = str(props.get("flag_id", "hollow_cameo_1")).strip_edges()
	radius = 28.0
	persist = true
	var already: bool = not flag_id.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(flag_id, false))
	stage = Stage.SEVERED if already else Stage.READY
	powered = already
	_cameo_t = 0.0
	_bolt_fired = already
	if already:
		_notify_linked_targets(true)
	queue_redraw()


func reset_toy() -> void:
	if persist and stage == Stage.SEVERED:
		return
	stage = Stage.READY
	_cameo_t = 0.0
	_bolt_fired = false
	set_powered(false)
	_notify_linked_targets(false)
	queue_redraw()


func can_interact(actor_pos: Vector2) -> bool:
	return active and stage == Stage.READY and actor_pos.distance_to(pos) <= radius + 10.0


func get_interact_prompt() -> String:
	if not active or stage != Stage.READY:
		return ""
	return "ISL1_TOLL_PROMPT_FIT" if LxStrings.has_id("ISL1_TOLL_PROMPT_FIT") else "PROMPT_INTERACT"


func interact(_actor: Node = null) -> bool:
	if not active or stage != Stage.READY:
		return false
	stage = Stage.CAMEO
	_cameo_t = 0.0
	_bolt_fired = false
	_emit_sfx("bell_toll_heavy")
	_emit_gust(72.0, 60.0)
	_emit_shake(0.16)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if stage == Stage.CAMEO:
		_cameo_t += dt
		if not _bolt_fired and _cameo_t >= 0.45:
			_bolt_fired = true
			_emit_sfx("shield_shatter")
			_emit_shake(0.28)
			if Lx.events != null and LxStrings.has_id("ISL1_TOLL_CUT"):
				Lx.events.narration_requested.emit("ISL1_TOLL_CUT", "title", 2.8)
		if _cameo_t >= CAMEO_DUR:
			_finish_sever()
		queue_redraw()


func _emit_shake(amp: float) -> void:
	if Lx.events != null:
		Lx.events.shake_requested.emit(amp * (0.45 if LxHudFx.flash_reduced() else 1.0))


func _finish_sever() -> void:
	stage = Stage.SEVERED
	if not flag_id.is_empty() and Lx.state != null:
		Lx.state.story_flags[flag_id] = true
	set_powered(true)
	emit_power(true)
	if region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	_emit_save("toll_rig_" + id)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 64.0 if stage == Stage.READY else 76.0, 0.95)


func save_state() -> Dictionary:
	return {"active": active, "severed": stage == Stage.SEVERED}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	var sev: bool = bool(d.get("severed", false)) or (not flag_id.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(flag_id, false)))
	stage = Stage.SEVERED if sev else Stage.READY
	powered = sev
	if sev:
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color

	# Overhead master cable & giant Great Bell cradle
	if stage != Stage.SEVERED:
		draw_line(Vector2(0.0, -56.0), Vector2(0.0, -18.0), c_void, 4.0)
		draw_line(Vector2(0.0, -56.0), Vector2(0.0, -18.0), c_apricot, 2.0)
	else:
		# Snapped cable stubs
		draw_line(Vector2(0.0, -56.0), Vector2(-3.0, -38.0), c_coral, 2.0)
		draw_line(Vector2(0.0, -24.0), Vector2(4.0, -18.0), c_apricot, 2.0)

	var red: bool = LxHudFx.flash_reduced()
	# Great Bell bronze dome
	var drop_y: float = 0.0 if stage == Stage.READY else (roundf(clampf((_cameo_t - 0.45) / 0.70, 0.0, 1.0) * 6.0) if stage == Stage.CAMEO else 6.0)
	_draw_ground_shadow(22.0, 8.0, Vector2(0.0, 14.0))
	draw_circle(Vector2(0.0, drop_y), 21.0, c_void)
	draw_circle(Vector2(0.0, drop_y), 19.0, c_dusk)
	draw_arc(Vector2(0.0, drop_y), 17.0, 0.0, TAU, 24, c_gold if stage != Stage.READY else c_apricot, 2.0)
	draw_arc(Vector2(0.0, drop_y), 10.0, 0.0, TAU, 18, c_night, 1.0)
	# Clapper socket: hollow dark ring when READY vs filled bright stud once fitted
	draw_circle(Vector2(0.0, drop_y), 5.0, c_night)
	if stage == Stage.READY:
		draw_circle(Vector2(0.0, drop_y), 3.0, c_void)
		draw_arc(Vector2(0.0, drop_y), 4.0, 0.0, TAU, 12, c_coral, 1.0)
	else:
		draw_circle(Vector2(0.0, drop_y), 4.0, c_gold)
		draw_circle(Vector2(0.0, drop_y), 2.0, c_cream)

	# Wordless Hollow Wick silhouette on upper rafters during cameo
	if stage == Stage.CAMEO:
		var u: float = clampf(_cameo_t / CAMEO_DUR, 0.0, 1.0)
		var alpha: float = sin(u * PI)
		var hpos := Vector2(46.0, -54.0)
		# Dark cloaked moth silhouette + black-glass unlit lantern
		draw_circle(hpos, 7.0, Color(c_void, alpha))
		draw_circle(hpos + Vector2(0.0, -4.0), 4.0, Color(c_plum, alpha))
		draw_rect(Rect2(hpos + Vector2(-9.0, -2.0), Vector2(4.0, 5.0)), Color(c_night, alpha))
		draw_rect(Rect2(hpos + Vector2(-8.0, -1.0), Vector2(2.0, 3.0)), Color(c_wine, alpha))
		# Violet bolt slicing the master cable at t=0.45s
		if _cameo_t >= 0.35 and _cameo_t <= 0.78:
			var bu: float = clampf((_cameo_t - 0.35) / 0.22, 0.0, 1.0)
			var bpt: Vector2 = hpos.lerp(Vector2(0.0, -34.0), bu).round()
			draw_line(hpos, bpt, Color(c_plum, 0.62 if red else 0.90), 2.0 if red else 3.0)
			draw_line(hpos, bpt, Color(c_coral, 0.68 if red else 0.95), 1.0)
			if bu >= 0.9:
				var ru: float = clampf((_cameo_t - 0.55) / 0.23, 0.0, 1.0)
				var r_col := Color(c_coral, (1.0 - ru) * (0.55 if red else 0.90))
				draw_arc(Vector2(0.0, -34.0), roundf(4.0 + ru * (14.0 if red else 20.0)), 0.0, TAU, 14, r_col, 1.0 if red else 2.0)
	_draw_signal_pulses()
