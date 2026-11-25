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
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color

	# Solid inlaid carved stone threshold sill (zero translucent wash)
	LxPhysDraw.draw_shadow_rect(self, r, Vector2(0.0, 1.0), 0.36)
	LxPhysDraw.draw_bevel_box(self, r, c_night, c_dusk, c_void, c_void)
	# Engraved directional pass arrow on sill
	LxPhysDraw.draw_chevron(self, -d * 3.0, d, c_cream if _allow_pass else c_gold, c_void, 3.0)
	# Twin carved stone-and-iron hinge bollards + hinged brass turnstile wings
	var bar_c: Color = c_cream if _allow_pass else c_gold
	var bar_sh: Color = c_gold if _allow_pass else c_apr
	if horiz_pass:
		for py: float in [r.position.y - 1.0, r.end.y - 5.0]:
			LxPhysDraw.draw_bevel_box(self, Rect2(-4.0, py, 8.0, 6.0), c_dusk, c_stone, c_night, c_void)
			draw_rect(Rect2(-2.0, py + 1.0, 4.0, 2.0), c_apr)
			draw_rect(Rect2(-1.0, py + 1.0, 2.0, 1.0), c_cream if _allow_pass else c_gold)
		var swing_x: float = d.x * (7.0 if _allow_pass else 2.0)
		var top_hinge := Vector2(0.0, r.position.y + 4.0)
		var bot_hinge := Vector2(0.0, r.end.y - 4.0)
		var top_tip := Vector2(swing_x, -2.0 if _allow_pass else -1.0)
		var bot_tip := Vector2(swing_x, 2.0 if _allow_pass else 1.0)
		draw_line(top_hinge, top_tip, c_void, 4.0)
		draw_line(bot_hinge, bot_tip, c_void, 4.0)
		draw_line(top_hinge, top_tip, bar_sh, 2.0)
		draw_line(bot_hinge, bot_tip, bar_sh, 2.0)
		draw_line(top_hinge + Vector2(0.0, -1.0), top_tip + Vector2(0.0, -1.0), bar_c, 1.0)
		draw_line(bot_hinge + Vector2(0.0, -1.0), bot_tip + Vector2(0.0, -1.0), bar_c, 1.0)
		# Pointed catch tooth at meeting point
		draw_rect(Rect2(roundf(swing_x) - 1.0, -1.0, 2.0, 2.0), c_cream if _allow_pass else c_mauve)
	else:
		for px: float in [r.position.x - 1.0, r.end.x - 5.0]:
			LxPhysDraw.draw_bevel_box(self, Rect2(px, -4.0, 6.0, 8.0), c_dusk, c_stone, c_night, c_void)
			draw_rect(Rect2(px + 1.0, -2.0, 4.0, 2.0), c_apr)
			draw_rect(Rect2(px + 2.0, -2.0, 2.0, 1.0), c_cream if _allow_pass else c_gold)
		var swing_y: float = d.y * (7.0 if _allow_pass else 2.0)
		var l_hinge := Vector2(r.position.x + 4.0, 0.0)
		var r_hinge := Vector2(r.end.x - 4.0, 0.0)
		var l_tip := Vector2(-2.0 if _allow_pass else -1.0, swing_y)
		var r_tip := Vector2(2.0 if _allow_pass else 1.0, swing_y)
		draw_line(l_hinge, l_tip, c_void, 4.0)
		draw_line(r_hinge, r_tip, c_void, 4.0)
		draw_line(l_hinge, l_tip, bar_sh, 2.0)
		draw_line(r_hinge, r_tip, bar_sh, 2.0)
		draw_line(l_hinge + Vector2(0.0, -1.0), l_tip + Vector2(0.0, -1.0), bar_c, 1.0)
		draw_line(r_hinge + Vector2(0.0, -1.0), r_tip + Vector2(0.0, -1.0), bar_c, 1.0)
		draw_rect(Rect2(-1.0, roundf(swing_y) - 1.0, 2.0, 2.0), c_cream if _allow_pass else c_mauve)
