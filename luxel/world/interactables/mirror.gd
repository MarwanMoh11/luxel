class_name LxMirror
extends LxInteractable
## Brass mirror reflecting Prism bolts off its surface normal.

var normal: Vector2 = Vector2(0.707107, 0.707107)
var rotatable: bool = false
var angle_step_deg: float = 45.0
var double_sided: bool = true
var size: Vector2 = Vector2(16.0, 16.0)
var _flash_t: float = 0.0
var _turn_t: float = 0.0
var _glint_stage: int = 0
var _aim_was_on: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "mirror"
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	rotatable = bool(props.get("rotatable", false))
	angle_step_deg = float(props.get("angle_step_deg", 45.0))
	double_sided = bool(props.get("double_sided", true))
	if props.has("normal"):
		var n: Vector2 = _parse_vec2(props.get("normal"), normal)
		if n.length_squared() > 0.001:
			normal = n.normalized()
	elif props.has("angle_deg"):
		var rad: float = deg_to_rad(float(props.get("angle_deg", 45.0)))
		normal = Vector2(cos(rad), sin(rad)).normalized()
	_turn_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		dirty = true
	if _turn_t > 0.0:
		_turn_t = maxf(0.0, _turn_t - dt)
		dirty = true
	if active:
		var st: int = int(floorf(_clock * 1.6 + absf(pos.x * 0.03))) % 6
		if st != _glint_stage:
			_glint_stage = st
			dirty = true
		var aim_now: bool = _is_player_aiming_here()
		if aim_now or aim_now != _aim_was_on:
			_aim_was_on = aim_now
			dirty = true
	if dirty:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not rotatable:
		return false
	normal = normal.rotated(deg_to_rad(angle_step_deg)).normalized()
	_turn_t = 0.18
	_emit_sfx("mirror_turn")
	queue_redraw()
	return true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam"]:
		_flash_t = 0.2
		_emit_gust(38.0, 28.0)
		_emit_sfx("mirror_ping")
		queue_redraw()
		return true
	return false


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func is_reflective() -> bool:
	return active


func get_interact_prompt() -> String:
	return "PROMPT_TURN_MIRROR" if (active and rotatable) else ""


func get_light_pool() -> Vector4:
	if _flash_t > 0.0:
		return Vector4(pos.x, pos.y, 52.0, 0.72 if LxHudFx.flash_reduced() else 1.1)
	return Vector4.ZERO


func reflect_dir(in_dir: Vector2) -> Vector2:
	if in_dir.length_squared() <= 0.0001:
		return Vector2.ZERO
	var d: Vector2 = in_dir.normalized()
	var n: Vector2 = normal.normalized()
	if d.dot(n) > 0.0:
		if not double_sided:
			return Vector2.ZERO
		n = -n
	return d.bounce(n).normalized()


func save_state() -> Dictionary:
	return {"active": active, "normal": [normal.x, normal.y]}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if d.has("normal"):
		var n: Vector2 = _parse_vec2(d.get("normal"), normal)
		if n.length_squared() > 0.001:
			normal = n.normalized()
	queue_redraw()


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var lit: bool = _flash_t > 0.0
	draw_rect(Rect2(x0 + 1.0, y0 + 2.0, w - 1.0, h - 1.0), PAL["void"])
	if rotatable:
		var cx: float = floorf(x0 + w * 0.5)
		var cy: float = floorf(y0 + h * 0.5)
		var teeth: Array[Vector2] = [
			Vector2(cx - 1.0, y0 - 1.0), Vector2(cx - 1.0, y0 + h),
			Vector2(x0 - 1.0, cy - 1.0), Vector2(x0 + w, cy - 1.0),
			Vector2(x0, y0), Vector2(x0 + w - 2.0, y0),
			Vector2(x0, y0 + h - 2.0), Vector2(x0 + w - 2.0, y0 + h - 2.0),
		]
		for tp: Vector2 in teeth:
			draw_rect(Rect2(tp, Vector2(2.0, 2.0)), PAL["night"])
			draw_rect(Rect2(tp, Vector2(1.0, 1.0)), PAL["gold"])
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["night"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0), PAL["dusk"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 1.0), PAL["stone"])
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, 1.0, h - 4.0), PAL["mauve"])
	draw_rect(Rect2(x0 + 3.0, y0 + 3.0, w - 6.0, h - 6.0), PAL["apricot"] if lit else PAL["night"])
	draw_rect(Rect2(x0 + 4.0, y0 + 4.0, maxf(2.0, w - 8.0), maxf(2.0, h - 8.0)), PAL["dusk"])
	var b_hi: Color = LxBiomePalette.col(island_id, "hi")
	var b_gl: Color = LxBiomePalette.col(island_id, "glow")
	var rivets: Array[Vector2] = [
		Vector2(x0 + 2.0, y0 + 2.0), Vector2(x0 + w - 4.0, y0 + 2.0),
		Vector2(x0 + 2.0, y0 + h - 4.0), Vector2(x0 + w - 4.0, y0 + h - 4.0),
	]
	for rv: Vector2 in rivets:
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), b_hi)
		draw_rect(Rect2(rv, Vector2(1.0, 1.0)), b_gl)
	var span: float = floorf(minf(w, h) * 0.44)
	var tang: Vector2 = Vector2(-normal.y, normal.x) * span
	var p1: Vector2 = (-tang).round()
	var p2: Vector2 = tang.round()
	var back: Vector2 = (-normal * 1.5).round()
	var front: Vector2 = (normal * 1.0).round()
	draw_line(p1 + back, p2 + back, PAL["void"], 4.0)
	draw_line(p1 + back, p2 + back, b_hi, 2.0)
	draw_line(p1, p2, PAL["apricot"] if lit else PAL["deep"], 4.0)
	draw_line(p1, p2, PAL["gold"] if lit else PAL["blue"], 3.0)
	draw_line(p1 + front, p2 + front, PAL["cream"] if lit else PAL["sky"], 2.0)
	var gl_a: Vector2 = (-tang * 0.45 + front).round()
	var gl_b: Vector2 = (tang * 0.35 + front).round()
	draw_line(gl_a, gl_b, PAL["cream"] if lit else PAL["ice"], 1.0)
	draw_rect(Rect2(gl_a, Vector2(1.0, 1.0)), PAL["cream"])
	var fin_tip: Vector2 = (normal * 5.0).round()
	draw_line(front, fin_tip, PAL["night"], 3.0)
	draw_line(front, fin_tip, b_hi, 1.0)
	draw_rect(Rect2(fin_tip, Vector2(1.0, 1.0)), PAL["cream"] if lit else b_gl)
	# Subtle optical sightline tick so players read the reflection angle at a glance.
	var aim_hit: bool = _is_player_aiming_here()
	var sight_a: Vector2 = (normal * 8.0).round()
	var sight_b: Vector2 = (normal * 10.0).round()
	draw_rect(Rect2(sight_a, Vector2.ONE), b_gl if (_turn_t > 0.0 or lit or aim_hit) else PAL["sky"])
	draw_rect(Rect2(sight_b, Vector2.ONE), PAL["cream"] if (_turn_t > 0.0 or lit or aim_hit) else PAL["ice"])
	if aim_hit and Lx.player != null and is_instance_valid(Lx.player):
		var fv: Variant = Lx.player.get("facing")
		if fv is Vector2 and (fv as Vector2).length_squared() > 0.01:
			var rdir: Vector2 = reflect_dir(fv as Vector2)
			if rdir.length_squared() > 0.01:
				for pi: int in range(1, 5):
					var pp: Vector2 = (rdir * (6.0 + float(pi) * 4.5)).round()
					var pcol: Color = (PAL["cream"] if pi == 1 else (b_gl if pi == 4 else PAL["gold"])) as Color
					draw_rect(Rect2(pp, Vector2.ONE), pcol)
	if not lit and _glint_stage <= 1:
		var gpos: Vector2 = (tang * (-0.35 if _glint_stage == 0 else 0.25) + front).round()
		draw_rect(Rect2(gpos, Vector2.ONE), PAL["cream"])
	if _turn_t > 0.0:
		draw_arc(Vector2.ZERO, roundf(minf(w, h) * 0.52), 0.0, TAU, 16, LxBiomePalette.col(island_id, "glow"), 1.0, false)
	if lit:
		var fp: float = 1.0 - clampf(_flash_t / 0.2, 0.0, 1.0)
		var m_gl: Color = LxBiomePalette.col(island_id, "glow")
		draw_arc(Vector2.ZERO, roundf(lerpf(4.0, 14.0, fp)), 0.0, TAU, 14, PAL["cream"] if fp < 0.45 else m_gl, 1.0, false)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["cream"])
		draw_rect(Rect2(0.0, -2.0, 1.0, 5.0), m_gl)
		draw_rect(Rect2(-2.0, 0.0, 5.0, 1.0), m_gl)


func _is_player_aiming_here() -> bool:
	if not active or Lx.state == null or not Lx.state.has_move("prism"):
		return false
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return false
	var ppos: Vector2 = (Lx.player as Node2D).global_position
	var to_m: Vector2 = pos - ppos
	var d2: float = to_m.length_squared()
	if d2 < 16.0 or d2 > 19600.0:
		return false
	var fv: Variant = Lx.player.get("facing")
	if not (fv is Vector2) or (fv as Vector2).length_squared() <= 0.01:
		return false
	var fdir: Vector2 = (fv as Vector2).normalized()
	var proj: float = to_m.dot(fdir)
	if proj <= 0.0:
		return false
	var perp: float = (to_m - fdir * proj).length()
	return perp <= maxf(size.x, size.y) * 0.65
