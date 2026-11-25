class_name LxTrialGate
extends LxToy
## Challenge Trial Gate: starts a timed/combat/puzzle challenge via `region.room_script` if present.
## Resets cleanly on failure so player can retry immediately (no softlock); unlocks on success.
## Props: challenge (String or Dictionary), once (bool), shoot_to_start (bool), size [w,h], persist, target_id/target_ids.

signal trial_started(challenge_spec: Variant)
signal trial_finished(passed: bool)

enum State { READY, ACTIVE, SOLVED }

var challenge_spec: Variant = ""
var state: int = State.READY
var once: bool = true
var _flash_t: float = 0.0
var _watched_challenge: Object = null


func _toy_setup() -> void:
	kind = "trial_gate"
	if not props.has("size"):
		size = Vector2(24.0, 18.0)
	radius = maxf(size.x, size.y) * 0.5 + 4.0
	challenge_spec = props.get("challenge", "trial")
	once = bool(props.get("once", true))
	state = State.SOLVED if powered else State.READY
	_flash_t = 0.0
	_watched_challenge = null
	queue_redraw()


func reset_toy() -> void:
	if persist and state == State.SOLVED:
		return
	state = State.READY
	_flash_t = 0.0
	_watched_challenge = null
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()
	if state == State.ACTIVE and _watched_challenge != null:
		if not is_instance_valid(_watched_challenge):
			_watched_challenge = null
			on_challenge_result(false)
		else:
			var cst: Variant = _watched_challenge.get("state")
			if cst is int:
				var ci: int = int(cst)
				if ci == LxChallenge.State.WON:
					on_challenge_result(true)
				elif ci == LxChallenge.State.FAILED or ci == LxChallenge.State.IDLE:
					on_challenge_result(false)


func interact(_actor: Node = null) -> bool:
	return _try_start()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or not bool(props.get("shoot_to_start", false)):
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "sunflare"]:
		return _try_start()
	return false


func get_interact_prompt() -> String:
	if not active or state == State.ACTIVE or (state == State.SOLVED and once):
		return ""
	return "PROMPT_START_TRIAL"


func _try_start() -> bool:
	if not active or state == State.ACTIVE:
		return false
	if state == State.SOLVED and once:
		return false
	state = State.ACTIVE
	_flash_t = 0.40
	_emit_sfx("boss_awaken")
	_emit_gust(72.0, 48.0)
	var started_via_script: bool = false
	_watched_challenge = null
	if region != null and is_instance_valid(region):
		var scr: Variant = region.get("room_script")
		if is_instance_valid(scr) and scr is Object:
			var so: Object = scr as Object
			if so.has_method("start_challenge"):
				so.call("start_challenge", challenge_spec, self)
				started_via_script = true
		if not started_via_script and region.has_method("notify"):
			region.call("notify", "trial_start:" + id, {"challenge": challenge_spec, "gate": self})
		var scr2: Variant = region.get("room_script")
		if is_instance_valid(scr2) and scr2 is Object:
			var ch_v: Variant = (scr2 as Object).get("active_challenge")
			if is_instance_valid(ch_v) and ch_v is Object:
				_watched_challenge = ch_v as Object
	trial_started.emit(challenge_spec)
	queue_redraw()
	return true


## Callback for E0-4's LxRoomScript / LxChallenge when the trial ends.
func on_challenge_result(passed: bool) -> void:
	_watched_challenge = null
	if state != State.ACTIVE:
		return
	if passed:
		state = State.SOLVED
		_flash_t = 0.50
		set_powered(true)
		emit_power(true)
		_emit_sfx("shrine_claimed")
	else:
		state = State.READY
		_flash_t = 0.30
		_emit_sfx("denied")
	trial_finished.emit(passed)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if state == State.SOLVED:
		return Vector4(pos.x, pos.y - 6.0, 52.0, 0.85)
	if state == State.ACTIVE:
		return Vector4(pos.x, pos.y - 6.0, 60.0, 1.0)
	return Vector4(pos.x, pos.y - 6.0, 34.0, 0.50)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["solved"] = state == State.SOLVED
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("solved", false)):
		state = State.SOLVED
		powered = true
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var trip: Array[Color] = LxToyDraw.skin_triplet(island_id, skin)
	var accent: Color = (PAL["gold"] as Color) if state == State.SOLVED else ((PAL["coral"] as Color) if state == State.ACTIVE else trip[2])
	var hi: Color = PAL["cream"] as Color if state != State.READY else accent

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 12.0, 3.0)
	# Twin trial obelisk pillars + arch lintel
	LxToyDraw.draw_bevel_box(self, Rect2(-12.0, -14.0, 6.0, 21.0), PAL["night"] as Color, PAL["dusk"] as Color, trip[1], c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(6.0, -14.0, 6.0, 21.0), PAL["night"] as Color, PAL["dusk"] as Color, trip[1], c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-13.0, -17.0, 26.0, 5.0), PAL["night"] as Color, trip[0], accent, c_void)
	# Flame braziers atop pillars
	for sx: float in [-9.0, 9.0]:
		draw_rect(Rect2(sx - 2.0, -20.0, 4.0, 3.0), accent)
		draw_rect(Rect2(sx - 1.0, -21.0, 2.0, 2.0), hi)
	# Center crest: hourglass/diamond READY, pulsing star ACTIVE, filled crown SOLVED
	var shape_i: int = 5 if state == State.SOLVED else (1 if state == State.ACTIVE else 2)
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -6.0), shape_i, state != State.READY, accent, hi)
	if _flash_t > 0.0:
		var u: float = 1.0 - clampf(_flash_t / 0.40, 0.0, 1.0)
		draw_arc(Vector2(0.0, -6.0), roundf(lerpf(5.0, 18.0, u)), 0.0, TAU, 16, hi, 1.0)
	_draw_signal_pulses()
