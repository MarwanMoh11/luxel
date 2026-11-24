class_name LxMasqueradeDancer
extends LxToy
## Island 7 Masquerade Guest: wears Wick's cloak & gilded mask, waltzes on closed path or rotor ring,
## casts an explicit Truth Shadow (`se_gold`, `nw_wrong`, `none`, `black_lantern`), supports 0.8s
## Cotillion blackout shuffle (`trigger_dim_swap`), and handles unmasking (`truth`/`liar`/`hollow`).
## Props: role ("truth"|"liar"|"hollow"), path (Array of [x,y]), speed (float, 38),
## shadow_mode ("se_gold"|"nw_wrong"|"none"|"black_lantern"), swap_group (String),
## reveal_flag (String), spawns_enemy (String), unmask_by_bolt (bool), rounds (int),
## rotor_center ([x,y]), rotor_radius (float), rotor_speed (float), persist (bool), target_id/target_ids.

enum State { WALTZING, DIM_SWAP, UNMASKED_TRUTH, UNMASKED_LIAR }

const DIM_SWAP_DUR: float = 0.8

var role: String = "liar"
var shadow_mode: String = "nw_wrong"
var swap_group: String = ""
var reveal_flag: String = ""
var spawns_enemy: String = ""
var unmask_by_bolt: bool = true
var speed: float = 38.0
var path_pts: Array[Vector2] = []
var rotor_center: Vector2 = Vector2.INF
var rotor_radius: float = 0.0
var rotor_speed: float = 0.7
var rounds_total: int = 1
var rounds_left: int = 1
var state: int = State.WALTZING

var _origin_pos: Vector2 = Vector2.ZERO
var _path_idx: int = 0
var _orbit_angle: float = 0.0
var _dim_t: float = 0.0
var _lens_boost_t: float = 0.0
var _reveal_t: float = 0.0
var _swap_target_pos: Vector2 = Vector2.ZERO
var _swap_pending: bool = false


func _toy_setup() -> void:
	kind = "masquerade_dancer"
	role = str(props.get("role", "liar")).strip_edges().to_lower()
	if role not in ["truth", "liar", "hollow"]:
		role = "liar"
	var def_sh: String = "se_gold" if role == "truth" else ("black_lantern" if role == "hollow" else "nw_wrong")
	shadow_mode = str(props.get("shadow_mode", def_sh)).strip_edges().to_lower()
	swap_group = str(props.get("swap_group", "")).strip_edges()
	reveal_flag = str(props.get("reveal_flag", "")).strip_edges()
	spawns_enemy = str(props.get("spawns_enemy", "")).strip_edges().to_lower()
	unmask_by_bolt = bool(props.get("unmask_by_bolt", true))
	speed = maxf(0.0, float(props.get("speed", 38.0)))
	rounds_total = maxi(1, int(props.get("rounds", 3 if role == "hollow" else 1)))
	rounds_left = rounds_total
	radius = maxf(11.0, radius)
	_origin_pos = pos

	path_pts.clear()
	var raw_p: Variant = props.get("path", [])
	if raw_p is Array:
		for pt_v: Variant in (raw_p as Array):
			path_pts.append(LxMapFormat.to_vec2(pt_v, pos))
	if props.has("rotor_center"):
		rotor_center = LxMapFormat.to_vec2(props.get("rotor_center"), Vector2.INF)
	else:
		rotor_center = Vector2.INF
	rotor_radius = maxf(0.0, float(props.get("rotor_radius", 0.0)))
	rotor_speed = float(props.get("rotor_speed", 0.7))
	if rotor_center.is_finite() and rotor_radius > 1.0:
		_orbit_angle = (pos - rotor_center).angle()
	_path_idx = 0
	_dim_t = 0.0
	_lens_boost_t = 0.0
	_reveal_t = 0.0
	_swap_pending = false
	if not reveal_flag.is_empty() and Lx.state != null and bool(Lx.state.story_flags.get(reveal_flag, false)):
		state = State.UNMASKED_TRUTH
		powered = true
	else:
		state = State.WALTZING
		powered = false
	queue_redraw()


func reset_toy() -> void:
	if persist and state == State.UNMASKED_TRUTH:
		return
	pos = _origin_pos
	position = pos.round()
	_path_idx = 0
	rounds_left = rounds_total
	state = State.WALTZING
	_dim_t = 0.0
	_swap_pending = false
	set_powered(false)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _lens_boost_t > 0.0:
		_lens_boost_t = maxf(0.0, _lens_boost_t - dt); dirty = true
	if _reveal_t > 0.0:
		_reveal_t = maxf(0.0, _reveal_t - dt); dirty = true

	if state == State.DIM_SWAP:
		_dim_t = maxf(0.0, _dim_t - dt)
		if _swap_pending and _dim_t <= DIM_SWAP_DUR * 0.5:
			_swap_pending = false
			pos = _swap_target_pos
			position = pos.round()
			if rotor_center.is_finite() and rotor_radius > 1.0:
				_orbit_angle = (pos - rotor_center).angle()
		if _dim_t <= 0.0:
			state = State.WALTZING
		dirty = true
	elif state == State.WALTZING:
		if rotor_center.is_finite() and rotor_radius > 1.0:
			_orbit_angle += rotor_speed * dt
			pos = rotor_center + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * rotor_radius
			position = pos.round()
			dirty = true
		elif path_pts.size() >= 2 and speed > 0.1:
			var target: Vector2 = path_pts[_path_idx % path_pts.size()]
			var step: float = speed * dt
			if pos.distance_to(target) <= step + 0.5:
				pos = target
				_path_idx = (_path_idx + 1) % path_pts.size()
			else:
				pos = pos.move_toward(target, step)
			position = pos.round()
			dirty = true
	if dirty:
		queue_redraw()


func interact(actor: Node = null) -> bool:
	if not active or state != State.WALTZING:
		return false
	return unmask(actor)


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or not unmask_by_bolt or state != State.WALTZING:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return unmask(hit.attacker as Node if hit.attacker is Node else null)
	return false


func on_light(light_radius: float, source: String) -> void:
	if active and light_radius > 0.0 and source in ["lens", "lens_anchor"]:
		_lens_boost_t = 1.6
		queue_redraw()


func unmask(_actor: Node = null) -> bool:
	if state != State.WALTZING:
		return false
	if role == "truth":
		state = State.UNMASKED_TRUTH
		_reveal_t = 0.55
		if not reveal_flag.is_empty() and Lx.state != null:
			Lx.state.story_flags[reveal_flag] = true
		set_powered(true)
		emit_power(true)
		_emit_sfx("mirror_ping")
		if region != null and region.has_method("notify"):
			region.call("notify", "unmask_truth:" + id, {"id": id, "role": role})
		queue_redraw()
		return true

	if role == "hollow":
		rounds_left = maxi(0, rounds_left - 1)
		_reveal_t = 0.48
		if rounds_left > 0:
			_emit_sfx("mask_shatter")
			if region != null and region.has_method("notify"):
				region.call("notify", "hollow_unmask_round", {"id": id, "rounds_left": rounds_left})
			if not swap_group.is_empty():
				trigger_dim_swap(region, swap_group, DIM_SWAP_DUR)
			queue_redraw()
			return true
		state = State.UNMASKED_TRUTH
		if not reveal_flag.is_empty() and Lx.state != null:
			Lx.state.story_flags[reveal_flag] = true
		set_powered(true)
		emit_power(true)
		_emit_sfx("mask_shatter")
		if region != null and region.has_method("notify"):
			region.call("notify", "unmask_hollow:" + id, {"id": id})
		queue_redraw()
		return true

	# Liar unmasked -> stays non-resetting, optionally spawns a brisk duel enemy
	state = State.UNMASKED_LIAR
	_reveal_t = 0.48
	_emit_sfx("shadow_whisper")
	if region != null and region.has_method("notify"):
		region.call("notify", "unmask_liar:" + id, {"id": id, "spawns_enemy": spawns_enemy})
	if not spawns_enemy.is_empty() and region != null and region.has_method("spawn_enemy"):
		region.call("spawn_enemy", {"id": id + "_exposed", "kind": spawns_enemy, "pos": [pos.x, pos.y]})
	queue_redraw()
	return true


func begin_dim_swap(new_pos: Vector2, new_path_idx: int, dur: float = DIM_SWAP_DUR) -> void:
	if state == State.UNMASKED_TRUTH or state == State.UNMASKED_LIAR:
		return
	state = State.DIM_SWAP
	_dim_t = maxf(0.15, dur)
	_swap_target_pos = new_pos
	_path_idx = new_path_idx
	_swap_pending = true
	queue_redraw()


static func trigger_dim_swap(region_node: Node, group_name: String, dur: float = DIM_SWAP_DUR) -> int:
	if region_node == null or not is_instance_valid(region_node) or not region_node.has_method("get_interactables"):
		return 0
	var members: Array[LxMasqueradeDancer] = []
	for it_v: Variant in (region_node.call("get_interactables") as Array):
		if it_v is LxMasqueradeDancer:
			var d: LxMasqueradeDancer = it_v as LxMasqueradeDancer
			if d.active and d.swap_group == group_name and d.state == State.WALTZING:
				members.append(d)
	var n: int = members.size()
	if n < 2:
		return 0
	var positions: Array[Vector2] = []
	var indices: Array[int] = []
	for d: LxMasqueradeDancer in members:
		positions.append(d.pos)
		indices.append(d._path_idx)
	# Guaranteed non-identity permutation (shift by 1..n-1)
	var shift: int = 1
	if Lx.rng != null and n > 2:
		shift = Lx.rng.randi_range(1, n - 1)
	for i: int in range(n):
		var src_i: int = (i + shift) % n
		members[i].begin_dim_swap(positions[src_i], indices[src_i], dur)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("cotillion_dim", Vector2.ZERO, false)
	return n


func get_interact_prompt() -> String:
	if not active or state != State.WALTZING:
		return ""
	return "ISL7_PROMPT_UNMASK" if LxStrings.has_id("ISL7_PROMPT_UNMASK") else ""


func get_light_pool() -> Vector4:
	if not active or state == State.DIM_SWAP or state == State.UNMASKED_LIAR:
		return Vector4.ZERO
	if state == State.UNMASKED_TRUTH:
		return Vector4(pos.x, pos.y - 4.0, 46.0, 0.76)
	return Vector4(pos.x, pos.y - 4.0, 26.0, 0.36)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_ice: Color = PAL["ice"] as Color

	if state == State.DIM_SWAP:
		# Blackout silhouette flicker during 0.8s Cotillion shuffle
		draw_rect(Rect2(-4.0, -10.0, 8.0, 11.0), Color(c_void, 0.72))
		draw_rect(Rect2(-2.0, -7.0, 4.0, 2.0), Color(c_plum, 0.65))
		return

	# Canonical Truth Shadow (SE gold = truth, NW wrong / none = liar, black_lantern = Hollow)
	if state == State.WALTZING:
		LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 4.0), 6.0, 2.5, shadow_mode, _lens_boost_t > 0.0)
	elif state == State.UNMASKED_TRUTH:
		LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 4.0), 6.0, 2.5, "se_gold", true)

	var bob: float = 0.0 if (state != State.WALTZING or LxHudFx.flash_reduced()) else roundf(absf(sin(_clock * 4.2)) * -1.5)
	if state == State.UNMASKED_LIAR:
		# Discarded cracked liar mask on floor
		draw_rect(Rect2(-4.0, 0.0, 8.0, 5.0), c_void)
		draw_rect(Rect2(-3.0, 1.0, 6.0, 3.0), c_rose)
		draw_line(Vector2(-2.0, 0.0), Vector2(2.0, 4.0), c_coral, 1.0)
		return

	# Cloaked Masquerade Wick twin
	var body_c: Color = c_gold if state == State.UNMASKED_TRUTH else c_dusk
	var hi_c: Color = c_cream if state == State.UNMASKED_TRUTH else c_plum
	draw_rect(Rect2(-3.0, -13.0 + bob, 6.0, 3.0), c_void)
	draw_rect(Rect2(-5.0, -10.0 + bob, 10.0, 12.0), c_void)
	draw_rect(Rect2(-2.0, -12.0 + bob, 4.0, 2.0), hi_c)
	draw_rect(Rect2(-4.0, -9.0 + bob, 8.0, 10.0), c_night)
	draw_rect(Rect2(-3.0, -9.0 + bob, 6.0, 9.0), body_c)
	# Gilded ballroom mask (removed when UNMASKED_TRUTH!)
	if state == State.WALTZING:
		draw_rect(Rect2(-3.0, -7.0 + bob, 6.0, 3.0), c_gold)
		draw_rect(Rect2(-2.0, -6.0 + bob, 1.0, 1.0), c_void)
		draw_rect(Rect2(1.0, -6.0 + bob, 1.0, 1.0), c_void)
		# Held gold masquerade lantern
		draw_rect(Rect2(5.0, -5.0 + bob, 3.0, 3.0), c_gold)
		draw_rect(Rect2(6.0, -4.0 + bob, 1.0, 1.0), c_cream)
	else:
		draw_rect(Rect2(-2.0, -7.0 + bob, 4.0, 3.0), c_void)
		draw_rect(Rect2(-2.0, -6.0 + bob, 1.0, 1.0), c_ice)
		draw_rect(Rect2(1.0, -6.0 + bob, 1.0, 1.0), c_ice)
		if _reveal_t > 0.0:
			draw_arc(Vector2(0.0, -5.0), roundf(lerpf(6.0, 20.0, 1.0 - _reveal_t / 0.55)), 0.0, TAU, 16, c_gold, 1.2)
	_draw_signal_pulses()
