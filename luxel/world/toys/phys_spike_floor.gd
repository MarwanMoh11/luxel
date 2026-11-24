class_name LxPhysSpikeFloor
extends LxToy
## Retractable floor spikes with clear visual telegraph before extending.
## States: DOWN -> TELEGRAPH (0.45s tips peek + glint) -> UP (hurts Wick on touch).
## Wings glide and dash i-frames pass over cleanly.

enum State { DOWN, TELEGRAPH, UP }

const TELEGRAPH_S: float = 0.45

var period: float = 2.6
var phase_offset: float = 0.0
var sig_mode: String = "" # "", "toggle", "extend", "retract"
var state: State = State.DOWN
var _sig_target_up: bool = false
var _tele_t: float = 0.0
var _hurt_cd: float = 0.0


func _toy_setup() -> void:
	kind = "spike_floor"
	size = _parse_size(props.get("size", [24.0, 24.0]), Vector2(24.0, 24.0))
	radius = maxf(size.x, size.y) * 0.5
	period = maxf(0.0, float(props.get("period", 2.6)))
	phase_offset = float(props.get("offset", 0.0))
	sig_mode = str(props.get("on_signal", "")).strip_edges().to_lower()
	_sig_target_up = bool(props.get("on", false))
	state = State.UP if (_sig_target_up and not sig_mode.is_empty()) else State.DOWN
	_tele_t = 0.0
	_hurt_cd = 0.0
	z_index = LxPhysDraw.floor_z(region, -4)
	queue_redraw()


func _on_power_changed(is_on: bool) -> void:
	if sig_mode.is_empty():
		sig_mode = "extend"
	match sig_mode:
		"retract":
			_sig_target_up = not is_on
		"toggle":
			_sig_target_up = not _sig_target_up
		_:
			_sig_target_up = is_on
	if _sig_target_up and state == State.DOWN:
		state = State.TELEGRAPH
		_tele_t = TELEGRAPH_S
		_emit_sfx("warden_alert")
	elif not _sig_target_up:
		state = State.DOWN
		_tele_t = 0.0
		_emit_sfx("shield_clang")
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	_hurt_cd = maxf(0.0, _hurt_cd - dt)
	var prev_st: State = state
	if sig_mode.is_empty() and period > 0.2:
		var t: float = fposmod(_clock + phase_offset, period)
		var up_dur: float = period * 0.42
		var down_dur: float = maxf(0.2, period - up_dur - TELEGRAPH_S)
		if t < down_dur:
			state = State.DOWN
		elif t < down_dur + TELEGRAPH_S:
			state = State.TELEGRAPH
		else:
			state = State.UP
		if state == State.TELEGRAPH and prev_st == State.DOWN:
			_emit_sfx("warden_alert")
		elif state == State.UP and prev_st != State.UP:
			_emit_sfx("shield_clang")
	elif state == State.TELEGRAPH:
		_tele_t -= dt
		if _tele_t <= 0.0:
			state = State.UP
			_emit_sfx("shield_clang")

	if state == State.UP and _hurt_cd <= 0.0 and Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead and not w.is_gliding() and not w.is_launched() and not w.is_mounted():
			var hit_r := Rect2(pos - size * 0.5, size).grow(-2.0)
			if hit_r.has_point(w.global_position):
				_hurt_cd = 0.55
				var kdir: Vector2 = (w.global_position - pos).normalized() if w.global_position.distance_to(pos) > 0.5 else Vector2.DOWN
				w.take_damage(1.0, pos, kdir, "spike_floor")
	if state != prev_st or state == State.TELEGRAPH:
		queue_redraw()


func _draw() -> void:
	var r := Rect2((-size * 0.5).round(), size.round())
	LxPhysDraw.draw_bevel_box(self, r, PAL["night"] as Color, PAL["dusk"] as Color, PAL["void"] as Color, PAL["void"] as Color)
	var cols: int = maxi(1, int(floor(size.x / 8.0)))
	var rows: int = maxi(1, int(floor(size.y / 8.0)))
	var sx: float = size.x / float(cols)
	var sy: float = size.y / float(rows)
	var warn_flash: bool = LxHudFx.flash_reduced() or fmod(_clock * 10.0, 1.0) < 0.5
	for ry: int in range(rows):
		for rx: int in range(cols):
			var c := Vector2(roundf(r.position.x + (float(rx) + 0.5) * sx), roundf(r.position.y + (float(ry) + 0.5) * sy))
			draw_rect(Rect2(c - Vector2(2.0, 1.0), Vector2(4.0, 3.0)), PAL["void"] as Color)
			if state == State.TELEGRAPH:
				draw_rect(Rect2(c - Vector2(1.0, 2.0), Vector2(2.0, 2.0)), PAL["coral"] as Color if warn_flash else PAL["apricot"] as Color)
				draw_rect(Rect2(c - Vector2(0.0, 2.0), Vector2.ONE), PAL["cream"] as Color)
			elif state == State.UP:
				var tri := PackedVector2Array([c + Vector2(-2.0, 1.0), c + Vector2(0.0, -5.0), c + Vector2(2.0, 1.0)])
				draw_colored_polygon(tri, PAL["stone"] as Color)
				draw_line(c + Vector2(0.0, -5.0), c + Vector2(2.0, 1.0), PAL["dusk"] as Color, 1.0)
				draw_rect(Rect2(c + Vector2(-1.0, -5.0), Vector2(2.0, 2.0)), PAL["coral"] as Color)
				draw_rect(Rect2(c + Vector2(0.0, -5.0), Vector2.ONE), PAL["cream"] as Color)
			else:
				draw_rect(Rect2(c - Vector2(1.0, 0.0), Vector2(2.0, 1.0)), PAL["dusk"] as Color)
