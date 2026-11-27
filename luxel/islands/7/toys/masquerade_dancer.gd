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
		Lx.events.sfx_requested.emit("masq_waltz_shuffle", Vector2.ZERO, false)
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
	var c_wine: Color = PAL["wine"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var fr: bool = LxHudFx.flash_reduced()

	if state == State.DIM_SWAP:
		# Graceful blackout silhouette during 0.8s Cotillion shuffle
		var a_dim: float = 0.68 if fr else (0.55 + 0.25 * absf(sin(_clock * 12.0)))
		var sh_cloak := PackedVector2Array([
			Vector2(-3.0, -11.0), Vector2(3.0, -11.0),
			Vector2(5.0, -5.0), Vector2(6.0, 3.0),
			Vector2(-6.0, 3.0), Vector2(-5.0, -5.0),
		])
		draw_colored_polygon(sh_cloak, Color(c_void, a_dim))
		draw_rect(Rect2(-3.0, -8.0, 6.0, 2.0), Color(c_plum, a_dim))
		return

	# Canonical Truth Shadow (SE gold = truth, NW wrong / none = liar, black_lantern = Hollow)
	# Preserve shadow_mode == "none" strictly so shadow puzzles stay 100% honest!
	if state == State.WALTZING:
		if shadow_mode != "none":
			_draw_ground_shadow(6.5, 2.5, Vector2(0.0, 4.0))
		LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 4.0), 6.0, 2.5, shadow_mode, _lens_boost_t > 0.0)
	elif state == State.UNMASKED_TRUTH:
		_draw_ground_shadow(6.5, 2.5, Vector2(0.0, 4.0))
		LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 4.0), 6.0, 2.5, "se_gold", true)

	if state == State.UNMASKED_LIAR:
		# Discarded cracked theatrical liar mask + snapped plume resting on floor
		_draw_ground_shadow(6.0, 2.5, Vector2(0.0, 3.0))
		draw_rect(Rect2(-5.0, -1.0, 10.0, 6.0), c_void)
		draw_rect(Rect2(-4.0, 0.0, 8.0, 4.0), c_rose)
		draw_rect(Rect2(-4.0, 0.0, 4.0, 1.0), c_cream)
		draw_rect(Rect2(-3.0, 1.0, 2.0, 1.0), c_void)
		draw_rect(Rect2(1.0, 1.0, 2.0, 1.0), c_void)
		draw_line(Vector2(-2.0, -1.0), Vector2(2.0, 4.0), c_coral, 1.0)
		# Snapped feather beside mask
		draw_rect(Rect2(4.0, -2.0, 3.0, 2.0), c_wine)
		draw_rect(Rect2(6.0, -2.0, 1.0, 1.0), c_rose)
		return

	var bob: float = 0.0 if (state != State.WALTZING or fr) else roundf(absf(sin(_clock * 4.2)) * -1.5)
	var sway: float = 0.0 if (state != State.WALTZING or fr) else roundf(sin(_clock * 3.0) * 1.0)
	var unmasked: bool = (state == State.UNMASKED_TRUTH)
	var cloak_dark: Color = c_apr if unmasked else c_night
	var cloak_mid: Color = c_gold if unmasked else c_dusk
	var cloak_hi: Color = c_cream if unmasked else c_plum
	var trim_c: Color = c_cream if unmasked else c_gold

	# Graceful flared cloaked masquerade figure with draped scalloped cape hem
	var cape_out := PackedVector2Array([
		Vector2(-3.0, -10.0 + bob), Vector2(3.0, -10.0 + bob),
		Vector2(6.0, -5.0 + bob), Vector2(7.0 + sway, 3.0 + bob),
		Vector2(2.0 + sway, 4.0 + bob), Vector2(-2.0 + sway, 4.0 + bob),
		Vector2(-7.0 + sway, 3.0 + bob), Vector2(-6.0, -5.0 + bob),
	])
	var cape_in := PackedVector2Array([
		Vector2(-2.0, -9.0 + bob), Vector2(2.0, -9.0 + bob),
		Vector2(5.0, -5.0 + bob), Vector2(6.0 + sway, 2.0 + bob),
		Vector2(2.0 + sway, 3.0 + bob), Vector2(-2.0 + sway, 3.0 + bob),
		Vector2(-6.0 + sway, 2.0 + bob), Vector2(-5.0, -5.0 + bob),
	])
	draw_colored_polygon(cape_out, c_void)
	draw_colored_polygon(cape_in, cloak_dark)
	# Draped inner cape center & sunlit left shoulder fold
	draw_rect(Rect2(-4.0, -7.0 + bob, 8.0, 9.0), cloak_mid)
	draw_rect(Rect2(-5.0, -5.0 + bob, 2.0, 6.0), cloak_hi)
	draw_rect(Rect2(-2.0, -7.0 + bob, 2.0, 9.0), cloak_hi)
	draw_rect(Rect2(2.0, -5.0 + bob, 2.0, 7.0), cloak_dark)
	# Draped gilded scalloped cape hem trim
	draw_rect(Rect2(-5.0 + sway, 2.0 + bob, 10.0, 1.0), trim_c)
	draw_rect(Rect2(-3.0 + sway, 3.0 + bob, 2.0, 1.0), trim_c)
	draw_rect(Rect2(1.0 + sway, 3.0 + bob, 2.0, 1.0), trim_c)

	# Sculpted hooded head & theatrical ruffled collar
	draw_rect(Rect2(-4.0, -14.0 + bob, 8.0, 6.0), c_void)
	draw_rect(Rect2(-3.0, -13.0 + bob, 6.0, 5.0), cloak_mid)
	draw_rect(Rect2(-3.0, -13.0 + bob, 3.0, 2.0), cloak_hi)
	draw_rect(Rect2(-4.0, -8.0 + bob, 8.0, 2.0), c_wine if not unmasked else c_apr)
	draw_rect(Rect2(-3.0, -8.0 + bob, 6.0, 1.0), trim_c)

	if state == State.WALTZING:
		# Winged feathered masquerade mask
		draw_rect(Rect2(-4.0, -11.0 + bob, 8.0, 3.0), c_void)
		draw_rect(Rect2(-4.0, -11.0 + bob, 8.0, 2.0), c_gold)
		draw_rect(Rect2(-3.0, -11.0 + bob, 4.0, 1.0), c_cream)
		draw_rect(Rect2(-2.0, -10.0 + bob, 1.0, 1.0), c_void)
		draw_rect(Rect2(1.0, -10.0 + bob, 1.0, 1.0), c_void)
		# Sweeping masquerade feather plume arching up-right from mask temple
		draw_rect(Rect2(2.0, -16.0 + bob, 4.0, 4.0), c_void)
		draw_rect(Rect2(3.0, -15.0 + bob, 2.0, 3.0), c_rose)
		draw_rect(Rect2(4.0, -16.0 + bob, 2.0, 2.0), c_cream)
		draw_rect(Rect2(2.0, -13.0 + bob, 1.0, 1.0), c_gold)
		# Held warm masquerade lantern on extended gloved hand
		draw_rect(Rect2(5.0, -7.0 + bob, 5.0, 6.0), c_void)
		draw_rect(Rect2(6.0, -6.0 + bob, 3.0, 4.0), c_gold)
		draw_rect(Rect2(7.0, -5.0 + bob, 1.0, 2.0), c_cream)
		draw_rect(Rect2(6.0, -7.0 + bob, 3.0, 1.0), c_apr)
	else:
		# Unmasked luminous true guest face
		draw_rect(Rect2(-3.0, -11.0 + bob, 6.0, 3.0), c_night)
		draw_rect(Rect2(-2.0, -10.0 + bob, 1.0, 1.0), c_cream)
		draw_rect(Rect2(1.0, -10.0 + bob, 1.0, 1.0), c_cream)
		draw_rect(Rect2(-2.0, -9.0 + bob, 1.0, 1.0), c_ice)
		draw_rect(Rect2(1.0, -9.0 + bob, 1.0, 1.0), c_ice)
		# Expressive unmasking flourish: golden/cream ribbon arcs, tossed mask glint & starlight sparkles
		if _reveal_t > 0.0:
			var u: float = 1.0 - clampf(_reveal_t / 0.55, 0.0, 1.0)
			var fa: float = (1.0 - u) * (0.55 if fr else 0.92)
			var r_out: float = roundf(lerpf(6.0, 22.0, u))
			var r_in: float = roundf(lerpf(4.0, 14.0, u))
			draw_arc(Vector2(0.0, -7.0), r_out, 0.0, TAU, 18, Color(c_gold, fa), 2.0)
			draw_arc(Vector2(0.0, -7.0), r_in, 0.0, TAU, 14, Color(c_cream, fa * 0.85), 1.0)
			# Tossed gilded mask spinning away up-right
			var mp := Vector2(roundf(6.0 + u * 10.0), roundf(-12.0 - sin(u * PI) * 8.0 + u * 6.0))
			draw_rect(Rect2(mp - Vector2(2.0, 1.0), Vector2(4.0, 2.0)), Color(c_gold, fa))
			draw_rect(Rect2(mp - Vector2(1.0, 1.0), Vector2(2.0, 1.0)), Color(c_cream, fa))
			# 4-point flourish sparkles
			for si: int in range(4):
				var sa: float = float(si) * (PI * 0.5) + (0.4 if fr else u * 2.2)
				var sp := Vector2(roundf(cos(sa) * r_in), roundf(-7.0 + sin(sa) * r_in))
				draw_rect(Rect2(sp, Vector2(1.0, 1.0)), Color(c_cream, fa))
	_draw_signal_pulses()
