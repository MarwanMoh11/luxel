class_name LxSwitchEye
extends LxInteractable
## Eye switch activated by bolt, prism_bolt, beam, or lantern throw to open linked doors/bridges.

var activated: bool = false
var requires_prism: bool = false
var reset_time: float = 0.0
var _reset_left: float = 0.0
var _pulse_stage: int = 0
var _reject_t: float = 0.0
var _act_t: float = 0.0
var _gaze_off: Vector2i = Vector2i.ZERO


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "switch_eye"
	requires_prism = bool(props.get("requires_prism", false)) or bool(props.get("requires_blue", false))
	reset_time = maxf(0.0, float(props.get("reset_time", 0.0)))
	activated = bool(props.get("activated", false))
	var sf: String = str(props.get("sets_flag", "")).strip_edges()
	if not sf.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(sf, false)):
		activated = true
	_reject_t = 0.0
	_act_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var changed: bool = false
	if _reject_t > 0.0:
		_reject_t = maxf(0.0, _reject_t - dt)
		changed = true
	if _act_t > 0.0:
		_act_t = maxf(0.0, _act_t - dt)
		changed = true
	if activated and reset_time > 0.0:
		_reset_left -= dt
		changed = true
		if _reset_left <= 0.0:
			activated = false
			_notify_linked_targets(false)
	if active:
		var rate: float = 3.0 if activated else 1.8
		var st: int = int(floorf(_clock * rate + absf(pos.x * 0.03))) % 4
		if st != _pulse_stage:
			_pulse_stage = st
			changed = true
		if not activated:
			var g: Vector2i = _compute_gaze()
			if g != _gaze_off:
				_gaze_off = g
				changed = true
	if changed:
		queue_redraw()


func _compute_gaze() -> Vector2i:
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return Vector2i.ZERO
	var d: Vector2 = (Lx.player as Node2D).global_position - pos
	if d.length_squared() > 12544.0 or d.length_squared() < 16.0:
		return Vector2i.ZERO
	return Vector2i(1 if d.x > 14.0 else (-1 if d.x < -14.0 else 0), 1 if d.y > 18.0 else (-1 if d.y < -18.0 else 0))


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	var is_blue_hit: bool = (hit.has_method("is_blue") and hit.is_blue()) or hit.source == LxHit.SOURCE_PRISM
	if requires_prism and not is_blue_hit:
		if hit.source in ["bolt", "beam", "throw", "recall"]:
			_reject_t = 0.30
			_emit_sfx("mirror_ping")
			queue_redraw()
		return true
	if hit.source not in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return false
	var was_active: bool = activated
	activated = true
	if reset_time > 0.0:
		_reset_left = reset_time
	var sf: String = str(props.get("sets_flag", "")).strip_edges()
	if not sf.is_empty() and Lx.state != null:
		Lx.state.story_flags[sf] = true
	if not was_active:
		_act_t = 0.34
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.06)
		_emit_gust(54.0, 38.0)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 10.0, 5.0)
		_emit_sfx("switch_eye")
		_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not activated:
		return Vector4.ZERO
	var surge: float = (sin((1.0 - clampf(_act_t / 0.34, 0.0, 1.0)) * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)) if _act_t > 0.0 else 0.0
	return Vector4(pos.x, pos.y - 4.0, 42.0 + surge * 24.0, 0.9 + surge * 0.35)


func save_state() -> Dictionary:
	return {"active": active, "activated": activated}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	activated = bool(d.get("activated", activated))
	if activated:
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	# Unified contact shadow under sculpted stone eye-plinth
	_draw_ground_shadow(8.0, 3.0, Vector2(2.0, 6.0))
	var key: String = ("eye_blue_lit" if activated else "eye_blue_dormant") if requires_prism else ("eye_gold_lit" if activated else "eye_gold_dormant")
	var frame_ov: int = (_pulse_stage % 2) if activated else 0
	_draw_puzzle_sprite(key, Vector2.ZERO, _clock, Color.WHITE, frame_ov)
	if activated:
		if reset_time > 0.0 and _reset_left > 0.0:
			var frac: float = clampf(_reset_left / reset_time, 0.0, 1.0)
			var bar_w: float = roundf(10.0 * frac)
			var b_core: Color = (PAL["ice"] if requires_prism else PAL["gold"]) as Color
			draw_rect(Rect2(-5.0, 6.0, 10.0, 2.0), PAL["void"] as Color)
			if bar_w >= 1.0:
				draw_rect(Rect2(-5.0, 6.0, bar_w, 1.0), b_core if frac > 0.35 else (PAL["coral"] as Color))
	else:
		# Crisp 2x2 pixel pupil tracking Wick's direction inside the recessed eye socket (centered at (0, -4))
		var gx: float = float(_gaze_off.x) * 2.0
		var gy: float = float(_gaze_off.y)
		var glint_c: Color = (PAL["coral"] if _reject_t > 0.0 else (PAL["ice"] if requires_prism else PAL["gold"])) as Color
		draw_rect(Rect2(-1.0 + gx, -5.0 + gy, 2.0, 2.0), PAL["void"] as Color)
		draw_rect(Rect2(-1.0 + gx, -5.0 + gy, 1.0, 1.0), glint_c)
		if _reject_t > 0.0:
			for sp: Vector2 in [Vector2(-7.0, -4.0), Vector2(6.0, -4.0), Vector2(0.0, -9.0), Vector2(0.0, 1.0)]:
				draw_rect(Rect2(sp, Vector2.ONE), PAL["coral"] as Color)
	if _act_t > 0.0:
		var ap: float = 1.0 - clampf(_act_t / 0.34, 0.0, 1.0)
		var rad: float = lerpf(5.0, 16.0, ap)
		var c_ac: Color = (PAL["cream"] if ap < 0.4 else (PAL["sky"] if requires_prism else PAL["gold"])) as Color
		for k: int in range(8):
			var a: float = (TAU * float(k)) / 8.0
			var pt := Vector2(roundf(cos(a) * rad), roundf(-4.0 + sin(a) * rad))
			draw_rect(Rect2(pt, Vector2(2.0 if ap < 0.35 else 1.0, 2.0 if ap < 0.35 else 1.0)), c_ac)
	_draw_signal_pulses()
