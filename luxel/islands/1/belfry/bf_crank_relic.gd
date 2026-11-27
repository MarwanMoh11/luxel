class_name LxBfCrankRelic
extends LxToy
## Island 1 Grand Belfry interactive clockwork relic / crank / mainspring pedestal.
## Used for `belfry_gear_1` (r8), `belfry_gear_2` (r10), `belfry_mainspring_key` (r15),
## and `belfry_spire_crank` (r16, unlocks after `metronome_defeated`).
## Re-entry safe: persists collection in `Lx.state.story_flags[flag_id]` and respects `requires_flag`.
## Props: flag_id (String), requires_flag (String), relic_kind ("gear"|"mainspring"|"crank"|"rope"),
## prompt_key (String), narrate_key (String), sfx (String), target_id/target_ids, persist (bool).

var flag_id: String = ""
var requires_flag: String = ""
var relic_kind: String = "gear"
var prompt_key: String = "ISL1_BF_PROMPT_CRANK"
var narrate_key: String = ""
var sfx_id: String = "key_drop"
var collected: bool = false
var _claim_t: float = 0.0


func _toy_setup() -> void:
	kind = "bf_crank_relic"
	flag_id = str(props.get("flag_id", "")).strip_edges()
	requires_flag = str(props.get("requires_flag", "")).strip_edges()
	relic_kind = str(props.get("relic_kind", "gear")).strip_edges().to_lower()
	prompt_key = str(props.get("prompt_key", "ISL1_BF_PROMPT_CRANK")).strip_edges()
	narrate_key = str(props.get("narrate_key", "")).strip_edges()
	sfx_id = str(props.get("sfx", "key_drop")).strip_edges()
	radius = 20.0
	persist = true
	collected = _is_flag_done()
	powered = collected
	_claim_t = 0.0
	_sync_visibility()
	if collected:
		_notify_linked_targets(true)
	queue_redraw()


func _is_flag_done() -> bool:
	if flag_id.is_empty() or Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get(flag_id, false))


func _is_req_met() -> bool:
	if requires_flag.is_empty():
		return true
	if region != null and region.has_method("is_flag_set"):
		return bool(region.call("is_flag_set", requires_flag))
	return Lx.state != null and bool(Lx.state.story_flags.get(requires_flag, false))


func _sync_visibility() -> void:
	visible = active and _is_req_met()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var prev_vis: bool = visible
	_sync_visibility()
	var dirty: bool = visible != prev_vis
	if _claim_t > 0.0:
		_claim_t = maxf(0.0, _claim_t - dt)
		dirty = true
	if dirty or (visible and not collected and not LxHudFx.flash_reduced()):
		queue_redraw()


func reset_toy() -> void:
	if persist and collected:
		return
	collected = _is_flag_done()
	powered = collected
	_sync_visibility()
	queue_redraw()


func can_interact(actor_pos: Vector2) -> bool:
	if not active or collected or not _is_req_met():
		return false
	return actor_pos.distance_to(pos) <= radius + 8.0


func get_interact_prompt() -> String:
	if not active or collected or not _is_req_met():
		return ""
	return prompt_key if LxStrings.has_id(prompt_key) else "PROMPT_INTERACT"


func interact(_actor: Node = null) -> bool:
	if not active or collected or not _is_req_met():
		return false
	collected = true
	_claim_t = 0.55
	if not flag_id.is_empty() and Lx.state != null:
		Lx.state.story_flags[flag_id] = true
	set_powered(true)
	emit_power(true)
	_emit_sfx(sfx_id)
	_emit_gust(56.0, 48.0)
	_emit_shake(0.14)
	if Lx.events != null:
		if not narrate_key.is_empty() and LxStrings.has_id(narrate_key):
			Lx.events.narration_requested.emit(narrate_key, "title", 3.2)
	if region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	_emit_save("bf_relic_" + id)
	queue_redraw()
	return true


func _emit_shake(amp: float) -> void:
	if Lx.events != null:
		Lx.events.shake_requested.emit(amp * (0.45 if LxHudFx.flash_reduced() else 1.0))


func get_light_pool() -> Vector4:
	if not active or not _is_req_met():
		return Vector4.ZERO
	if collected:
		return Vector4(pos.x, pos.y - 2.0, 28.0, 0.38)
	return Vector4(pos.x, pos.y - 4.0, 46.0, 0.72 if LxHudFx.flash_reduced() else 0.85)


func save_state() -> Dictionary:
	return {"active": active, "collected": collected}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	collected = bool(d.get("collected", collected)) or _is_flag_done()
	powered = collected
	_sync_visibility()
	if collected:
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	if not active or not _is_req_met():
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_ice: Color = PAL["ice"] as Color

	var red: bool = LxHudFx.flash_reduced()
	_draw_ground_shadow(9.0, 4.0, Vector2(0.0, 6.0))
	# Fluted clockwork brass pedestal
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -3.0, 16.0, 10.0), c_night, c_dusk, c_mauve, c_void)
	draw_rect(Rect2(-6.0, -4.0, 12.0, 2.0), c_apricot if not collected else c_mauve)

	if not collected:
		var bob: float = 0.0 if red else roundf(sin(_clock * 3.4) * 1.6)
		var ry: float = -10.0 + bob
		if relic_kind == "mainspring":
			draw_circle(Vector2(0.0, ry), 7.0, c_void)
			draw_arc(Vector2(0.0, ry), 6.0, 0.0, TAU, 16, c_gold, 2.0)
			draw_arc(Vector2(0.0, ry), 3.0, 0.4, TAU - 0.6, 12, c_ice, 1.0)
			draw_rect(Rect2(-1.0, ry - 1.0, 2.0, 2.0), c_cream)
		elif relic_kind == "crank":
			draw_rect(Rect2(-7.0, ry - 5.0, 14.0, 5.0), c_void)
			draw_rect(Rect2(3.0, ry - 8.0, 5.0, 6.0), c_void)
			draw_rect(Rect2(-2.0, ry - 5.0, 4.0, 10.0), c_void)
			draw_rect(Rect2(-1.0, ry - 4.0, 2.0, 8.0), c_apricot)
			draw_rect(Rect2(-6.0, ry - 4.0, 12.0, 3.0), c_gold)
			draw_rect(Rect2(4.0, ry - 7.0, 3.0, 4.0), c_cream)
		elif relic_kind == "rope":
			draw_rect(Rect2(-5.0, ry - 4.0, 10.0, 8.0), c_void)
			draw_rect(Rect2(-4.0, ry - 3.0, 8.0, 6.0), c_apricot)
			draw_line(Vector2(-3.0, ry - 1.0), Vector2(3.0, ry - 1.0), c_gold, 1.0)
			draw_line(Vector2(-3.0, ry + 1.0), Vector2(3.0, ry + 1.0), c_cream, 1.0)
		else:
			# Brass gear crank
			draw_circle(Vector2(0.0, ry), 6.0, c_void)
			draw_circle(Vector2(0.0, ry), 5.0, c_apricot)
			for i: int in range(6):
				var a: float = (TAU * float(i)) / 6.0 + (0.0 if red else _clock * 0.8)
				var tp := Vector2(roundf(cos(a) * 6.0), roundf(ry + sin(a) * 6.0))
				draw_rect(Rect2(tp - Vector2.ONE, Vector2(2.0, 2.0)), c_gold)
			draw_circle(Vector2(0.0, ry), 2.0, c_cream)
	else:
		# Engaged recessed socket with void backing & cream lock stud (greyscale-legible)
		draw_rect(Rect2(-4.0, -4.0, 8.0, 4.0), c_void)
		draw_rect(Rect2(-3.0, -3.0, 6.0, 2.0), c_gold)
		draw_rect(Rect2(-1.0, -3.0, 2.0, 1.0), c_cream)
		if _claim_t > 0.0:
			var u: float = 1.0 - clampf(_claim_t / 0.55, 0.0, 1.0)
			var r_col := Color(c_gold, (1.0 - u) * (0.55 if red else 0.90))
			draw_arc(Vector2(0.0, -6.0), roundf(6.0 + u * (18.0 if red else 24.0)), 0.0, TAU, 18, r_col, 1.0 if red else 2.0)
	_draw_signal_pulses()
