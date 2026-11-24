class_name LxPhysRotor
extends LxToy
## Rotating floor platform section that turns 90° CW or CCW on signal / Star Bell / Lx.vars
## and smoothly rotates all riders (Wick, hung lantern, mirrors, blocks, orbs, Island 5 toys).

signal turn_finished(quarter_index: int)

const TURN_SPEED: float = PI * 1.1 # ~0.45s per 90° quarter turn
const RIDER_KINDS: Array[String] = [
	"push_block", "carry_orb", "mirror", "blue_transformer",
	"star_node", "star_bell", "meteor_orb", "gravity_well", "polarity_well",
	"switch_eye", "lantern_hook", "pressure_plate", "timed_brazier",
	"crystal_toggle", "beam_emitter",
]

var quarter_on_signal: bool = true
var continuous_speed: float = 0.0
var rotate_normals: bool = true
var linked_var: String = ""
var var_scope: String = ""
var angle: float = 0.0
var target_angle: float = 0.0
var quarter_index: int = 0

var _was_turning: bool = false
var _vars_bound: LxWorldState = null


func _toy_setup() -> void:
	kind = "rotor"
	size = _parse_size(props.get("size", [48.0, 48.0]), Vector2(48.0, 48.0))
	radius = maxf(size.x, size.y) * 0.5
	quarter_on_signal = bool(props.get("quarter_on_signal", true))
	continuous_speed = float(props.get("speed", 0.0))
	rotate_normals = bool(props.get("rotate_normals", true))
	linked_var = str(props.get("linked_var", props.get("var", ""))).strip_edges()
	var_scope = str(props.get("scope", "")).strip_edges()
	quarter_index = posmod(int(props.get("start_quarter", 0)), 4)
	if not linked_var.is_empty() and Lx.vars != null:
		var cur_v: Variant = _read_linked_var()
		if cur_v is int or cur_v is float or str(cur_v).is_valid_float():
			quarter_index = posmod(int(roundf(float(cur_v) / 90.0)), 4)
		_bind_vars()
	angle = float(quarter_index) * (PI * 0.5)
	target_angle = angle
	_was_turning = false
	z_index = LxPhysDraw.floor_z(region, -4)
	queue_redraw()


func _exit_tree() -> void:
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_world_var_changed):
		_vars_bound.var_changed.disconnect(_on_world_var_changed)
	_vars_bound = null


func _bind_vars() -> void:
	if Lx.vars == null or _vars_bound == Lx.vars:
		return
	_vars_bound = Lx.vars
	if not _vars_bound.var_changed.is_connected(_on_world_var_changed):
		_vars_bound.var_changed.connect(_on_world_var_changed)


func _read_linked_var() -> Variant:
	if Lx.vars == null or linked_var.is_empty():
		return null
	if not var_scope.is_empty():
		return Lx.vars.get_var(var_scope, linked_var, 0)
	return Lx.vars.resolve_var(linked_var, island_id, region_id, 0)


func _on_world_var_changed(scope: String, vname: String, val: Variant) -> void:
	if not active or linked_var.is_empty() or vname != linked_var:
		return
	if not var_scope.is_empty() and scope != var_scope:
		return
	var deg: float = float(val) if (val is int or val is float or str(val).is_valid_float()) else 0.0
	var next_q: int = posmod(int(roundf(deg / 90.0)), 4)
	if next_q != quarter_index:
		var diff: int = posmod(next_q - quarter_index, 4)
		var dir_s: int = -1 if diff == 3 else 1
		turn_to_quarter(next_q, dir_s)


func is_platform_solid() -> bool:
	return active


func get_platform_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if active else Rect2()


func is_turning() -> bool:
	return absf(target_angle - angle) > 0.001


func trigger_quarter_turn(dir_sign: int = 1) -> void:
	var sgn: int = -1 if dir_sign < 0 else 1
	quarter_index = posmod(quarter_index + sgn, 4)
	target_angle += float(sgn) * (PI * 0.5)
	_was_turning = true
	_emit_sfx("clockwork_chime")
	queue_redraw()


func turn_to_quarter(q: int, dir_sign: int = 1) -> void:
	var want_q: int = posmod(q, 4)
	if want_q == quarter_index and not is_turning():
		return
	var cw_steps: int = posmod(want_q - quarter_index, 4)
	var ccw_steps: int = posmod(quarter_index - want_q, 4)
	var delta_steps: int = 0
	if dir_sign < 0:
		delta_steps = -ccw_steps if ccw_steps > 0 else -4
	elif dir_sign > 0:
		delta_steps = cw_steps if cw_steps > 0 else 4
	else:
		delta_steps = cw_steps if cw_steps <= ccw_steps else -ccw_steps
	if cw_steps == 0:
		return
	quarter_index = want_q
	target_angle += float(delta_steps) * (PI * 0.5)
	_was_turning = true
	_emit_sfx("clockwork_chime")
	queue_redraw()


func set_quarter_immediate(q: int) -> void:
	quarter_index = posmod(q, 4)
	angle = float(quarter_index) * (PI * 0.5)
	target_angle = angle
	_was_turning = false
	queue_redraw()


func on_signal(from_id: String, is_on: bool) -> void:
	super.on_signal(from_id, is_on)
	if quarter_on_signal and is_on:
		trigger_quarter_turn(1)


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var da: float = 0.0
	if quarter_on_signal or not linked_var.is_empty():
		if absf(target_angle - angle) > 0.0005:
			var prev_a: float = angle
			angle = move_toward(angle, target_angle, TURN_SPEED * dt)
			da = angle - prev_a
		elif _was_turning:
			_was_turning = false
			angle = target_angle
			turn_finished.emit(quarter_index)
	elif absf(continuous_speed) > 0.001:
		da = continuous_speed * dt
		angle = fposmod(angle + da, TAU)
		target_angle = angle
	if absf(da) > 0.00001:
		_rotate_riders(da)
		queue_redraw()


func _is_rider_on_deck(p: Vector2) -> bool:
	var rel: Vector2 = p - pos
	if rel.length_squared() <= radius * radius:
		return true
	return get_platform_rect().grow(2.0).has_point(p)


func _rotate_riders(da: float) -> void:
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead and not w.is_dashing() and not w.is_gliding() and not w.is_zipping() and not w.is_launched() and not w.is_mounted():
			if _is_rider_on_deck(w.global_position):
				var rot_p: Vector2 = pos + (w.global_position - pos).rotated(da)
				if region != null and region.has_method("collide"):
					rot_p = region.call("collide", rot_p, LxWick.BODY_RADIUS, true, true) as Vector2
				w.global_position = rot_p
				w.last_pos = rot_p
		if w.lantern != null and w.lantern.is_hanging() and _is_rider_on_deck(w.lantern.pos):
			w.lantern.pos = pos + (w.lantern.pos - pos).rotated(da)
			w.lantern.prev_pos = w.lantern.pos
			w.lantern.global_position = w.lantern.pos.round()
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in region.call("get_interactables") as Array:
			if it_v == self or not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not it.active or not _is_rider_on_deck(it.pos):
				continue
			if it.kind in RIDER_KINDS:
				var np: Vector2 = pos + (it.pos - pos).rotated(da)
				if it.has_method("move_to"):
					it.call("move_to", np)
				else:
					it.pos = np
					it.position = np.round()
				if rotate_normals and it.kind in ["mirror", "blue_transformer"]:
					var n_v: Variant = it.get("normal")
					if n_v is Vector2 and (n_v as Vector2).length_squared() > 0.001:
						it.set("normal", (n_v as Vector2).rotated(da).normalized())
						it.queue_redraw()
				if it.kind == "meteor_orb":
					var cp_v: Variant = it.get("cradle_pos")
					if cp_v is Vector2 and _is_rider_on_deck(cp_v as Vector2):
						it.set("cradle_pos", pos + ((cp_v as Vector2) - pos).rotated(da))


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["quarter_index"] = quarter_index
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("quarter_index"):
		quarter_index = posmod(int(d.get("quarter_index", 0)), 4)
		angle = float(quarter_index) * (PI * 0.5)
		target_angle = angle
	queue_redraw()


func _draw() -> void:
	var r: float = radius
	draw_circle(Vector2(0.0, 2.0), r + 1.0, Color(PAL["void"] as Color, 0.45))
	draw_circle(Vector2.ZERO, r, PAL["void"] as Color)
	draw_circle(Vector2.ZERO, r - 1.0, PAL["dusk"] as Color)
	draw_circle(Vector2.ZERO, maxf(6.0, r - 5.0), PAL["night"] as Color)
	draw_arc(Vector2.ZERO, r - 2.0, 0.0, TAU, 32, biome("hi"), 1.0)
	draw_arc(Vector2.ZERO, maxf(6.0, r - 5.0), 0.0, TAU, 24, PAL["plum"] as Color, 1.0)

	# 12 rotating brass gear teeth around perimeter (makes turning unmistakable in greyscale)
	for g: int in range(12):
		var ga: float = angle + float(g) * (TAU / 12.0)
		var tp: Vector2 = (Vector2.from_angle(ga) * (r - 1.5)).round()
		draw_rect(Rect2(tp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["apricot"] as Color if g % 3 == 0 else PAL["mauve"] as Color)

	# Rotating cross spokes & bright golden cardinal compass needle (0° marker)
	for i: int in range(4):
		var a: float = angle + float(i) * (PI * 0.5)
		var d_v := Vector2.from_angle(a)
		var tip: Vector2 = (d_v * (r - 4.0)).round()
		if i == 0:
			draw_line(Vector2.ZERO, tip, PAL["gold"] as Color, 2.0)
			LxPhysDraw.draw_chevron(self, (d_v * (r - 7.0)).round(), d_v, PAL["cream"] as Color, PAL["void"] as Color, 3.0)
		else:
			draw_line(Vector2.ZERO, tip, PAL["mauve"] as Color, 1.0)
			draw_rect(Rect2(tip - Vector2.ONE, Vector2(2.0, 2.0)), PAL["stone"] as Color)

	draw_circle(Vector2.ZERO, 5.5, PAL["void"] as Color)
	draw_circle(Vector2.ZERO, 4.0, PAL["night"] as Color)
	draw_circle(Vector2.ZERO, 2.5, PAL["cream"] as Color if is_turning() else biome("glow"))
