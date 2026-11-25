class_name LxPhysOneWayGate
extends LxToy
## One-way mechanical turnstile gate: Wick may cross freely in `dir`, but cannot return against `-dir`.
## Never traps Wick inside the bar span.

var gate_dir: Vector2 = Vector2.RIGHT
var _swing_t: float = 0.0
var _allow_pass: bool = false


func _toy_setup() -> void:
	kind = "one_way_gate"
	gate_dir = dir_vec("dir", Vector2.RIGHT)
	var default_sz: Vector2 = Vector2(12.0, 28.0) if absf(gate_dir.x) >= absf(gate_dir.y) else Vector2(28.0, 12.0)
	size = _parse_size(props.get("size", default_sz), default_sz)
	radius = maxf(size.x, size.y) * 0.5
	_swing_t = 0.0
	_allow_pass = false
	queue_redraw()


func _effective_dir() -> Vector2:
	return -gate_dir if (bool(props.get("flip_on_signal", false)) and powered) else gate_dir


func is_solid() -> bool:
	return active and not _allow_pass


func blocks_sight() -> bool:
	return false


func blocks_lantern(from_p: Vector2 = Vector2.INF, to_p: Vector2 = Vector2.INF) -> bool:
	if not active:
		return false
	if from_p.is_finite() and to_p.is_finite():
		var delta: Vector2 = to_p - from_p
		if delta.length_squared() > 0.0001 and delta.dot(_effective_dir()) > 0.0:
			return false
	return true


func get_lantern_block_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if active else Rect2()


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_solid() else Rect2()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var d: Vector2 = _effective_dir()
	var prev_allow: bool = _allow_pass
	if is_instance_valid(Lx.player) and Lx.player is LxWick:
		var w: LxWick = Lx.player as LxWick
		var rel: Vector2 = w.global_position - pos
		var along: float = rel.dot(d)
		var perp_d: float = absf(rel.dot(Vector2(-d.y, d.x)))
		var half_span: float = (size.y if absf(d.x) >= absf(d.y) else size.x) * 0.5 + 5.0
		var half_thick: float = (size.x if absf(d.x) >= absf(d.y) else size.y) * 0.5 + 8.0
		# Open when Wick approaches from entry side (along <= 2) or is mid-crossing forward
		if perp_d <= half_span and along >= -half_thick and along <= 4.0:
			_allow_pass = true
			if not prev_allow and absf(along) <= half_thick * 0.7:
				_swing_t = 0.25
				_emit_sfx("harbor_creak")
		elif along > 4.0 and perp_d <= half_span and along <= half_thick * 0.9:
			# Already crossed onto exit side: latch shut behind Wick and gently eject clear
			_allow_pass = false
			LxPhysDraw.safe_eject_wick(w, Rect2(pos - size * 0.5, size), region, id, d)
		else:
			_allow_pass = false
	if _swing_t > 0.0:
		_swing_t = maxf(0.0, _swing_t - dt)
		queue_redraw()
	elif prev_allow != _allow_pass:
		queue_redraw()


func _draw() -> void:
	var r := Rect2((-size * 0.5).round(), size.round())
	var d: Vector2 = _effective_dir()
	var horiz_pass: bool = absf(d.x) >= absf(d.y)
	# Floor threshold strip + clear directional chevron
	draw_rect(r, Color(PAL["night"] as Color, 0.55))
	LxPhysDraw.draw_chevron(self, -d * 3.0, d, PAL["cream"] as Color if _allow_pass else PAL["gold"] as Color, PAL["void"] as Color, 3.5)
	# Two anchor gate posts on the sides
	if horiz_pass:
		for py: float in [r.position.y, r.end.y - 4.0]:
			LxPhysDraw.draw_bevel_box(self, Rect2(-3.0, py, 6.0, 4.0), PAL["dusk"] as Color, PAL["stone"] as Color, PAL["night"] as Color)
		# Swinging gate bars (swung forward when open)
		var swing_x: float = d.x * (6.0 if _allow_pass else 0.0)
		draw_line(Vector2(0.0, r.position.y + 4.0), Vector2(swing_x, 0.0), PAL["gold"] as Color, 2.0)
		draw_line(Vector2(0.0, r.end.y - 4.0), Vector2(swing_x, 0.0), PAL["gold"] as Color, 2.0)
	else:
		for px: float in [r.position.x, r.end.x - 4.0]:
			LxPhysDraw.draw_bevel_box(self, Rect2(px, -3.0, 4.0, 6.0), PAL["dusk"] as Color, PAL["stone"] as Color, PAL["night"] as Color)
		var swing_y: float = d.y * (6.0 if _allow_pass else 0.0)
		draw_line(Vector2(r.position.x + 4.0, 0.0), Vector2(0.0, swing_y), PAL["gold"] as Color, 2.0)
		draw_line(Vector2(r.end.x - 4.0, 0.0), Vector2(0.0, swing_y), PAL["gold"] as Color, 2.0)
