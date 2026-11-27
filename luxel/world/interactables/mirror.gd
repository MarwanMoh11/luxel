class_name LxMirror
extends LxInteractable
## Blue Transformer-Deflector & Brass Mirror: reflects yellow Light Bolts into blue light
## along its physical surface normal, rotatable in 45° steps and push/pull movable.

const CHAIN_PREVIEW_RANGE: float = 210.0
const CLOSE_HINT_RANGE: float = 72.0

var normal: Vector2 = Vector2(0.707107, 0.707107)
var _init_normal: Vector2 = Vector2(0.707107, 0.707107)
var rotatable: bool = false
var movable: bool = false
var transforms_to: String = LxHit.COLOR_BLUE
var persist_pos: bool = false
var origin_pos: Vector2 = Vector2.ZERO
var angle_step_deg: float = 45.0
var double_sided: bool = true
var size: Vector2 = Vector2(16.0, 16.0)
var cue_spotlight: bool = false
var spotlight_radius: float = 34.0
var cue_curtain: bool = false
var floor_only: bool = false
var world_face: String = ""
var _flash_t: float = 0.0
var _turn_t: float = 0.0
var _pierce_t: float = 0.0
var _glint_stage: int = 0
var _aim_was_on: bool = false
var _has_rotated: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	var raw_kind: String = str(spec.get("kind", "mirror")).strip_edges().to_lower()
	var is_transformer_kind: bool = raw_kind in ["blue_transformer", "transformer"]
	kind = "blue_transformer" if is_transformer_kind else "mirror"
	origin_pos = pos
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	cue_spotlight = bool(props.get("cue_spotlight", props.get("spotlight", false)))
	spotlight_radius = maxf(18.0, float(props.get("spotlight_radius", 34.0)))
	cue_curtain = bool(props.get("cue_curtain", props.get("curtain", false)))
	floor_only = bool(props.get("floor_only", cue_spotlight and not bool(props.get("cue_mirror", false))))
	world_face = str(props.get("world_face", "")).strip_edges().to_lower()
	movable = bool(props.get("movable", is_transformer_kind)) and not floor_only and not cue_curtain
	rotatable = bool(props.get("rotatable", is_transformer_kind)) and not floor_only and not cue_curtain
	transforms_to = str(props.get("transforms_to", LxHit.COLOR_BLUE)).strip_edges().to_lower()
	if transforms_to.is_empty():
		transforms_to = LxHit.COLOR_BLUE
	persist_pos = bool(props.get("persist_pos", false)) # a wedged mirror must never outlive the room: re-entry resets it unless the room says otherwise
	angle_step_deg = float(props.get("angle_step_deg", 45.0))
	double_sided = bool(props.get("double_sided", true))
	if props.has("normal"):
		var n: Vector2 = _parse_vec2(props.get("normal"), normal)
		if n.length_squared() > 0.001:
			normal = n.normalized()
	elif props.has("angle_deg"):
		var rad: float = deg_to_rad(float(props.get("angle_deg", 45.0)))
		normal = Vector2(cos(rad), sin(rad)).normalized()
	_init_normal = normal
	_turn_t = 0.0
	_pierce_t = 0.0
	_has_rotated = false
	if floor_only:
		z_index = -5
	queue_redraw()


func reset_toy() -> void:
	if persist_pos:
		return
	normal = _init_normal
	move_to(origin_pos)
	_turn_t = 0.0
	_pierce_t = 0.0
	queue_redraw()


func rotate_by(deg: float) -> void:
	normal = normal.rotated(deg_to_rad(deg)).normalized()
	_turn_t = 0.18
	_has_rotated = true
	queue_redraw()


func _world_face_active() -> bool:
	if world_face.is_empty():
		return true
	if Lx.vars != null:
		return str(Lx.vars.resolve_var("world_face", island_id, region_id, "silver")).to_lower() == world_face
	return world_face == "silver"


func is_cue_spotlight() -> bool:
	return active and cue_spotlight and _world_face_active()


func contains_spotlight(world_pos: Vector2) -> bool:
	return is_cue_spotlight() and world_pos.distance_to(pos) <= spotlight_radius


func _can_player_pierce_curtain() -> bool:
	if not cue_curtain:
		return false
	var has_cue: bool = Lx.state != null and bool(Lx.state.story_flags.get("item_cue_mirror", false))
	if not has_cue:
		return false
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return false
	var wpos: Vector2 = (Lx.player as Node2D).global_position
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if it_v is LxMirror and (it_v as LxMirror).contains_spotlight(wpos):
				return true
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		dirty = true
	if _turn_t > 0.0:
		_turn_t = maxf(0.0, _turn_t - dt)
		dirty = true
	if _pierce_t > 0.0:
		_pierce_t = maxf(0.0, _pierce_t - dt)
		dirty = true
	if active:
		var g_rate: float = 0.9 if LxHudFx.flash_reduced() else 1.6
		var st: int = int(floorf(_clock * g_rate + absf(pos.x * 0.03))) % 6
		if st != _glint_stage:
			_glint_stage = st
			dirty = true
		var aim_now: bool = _is_player_aiming_here() if not floor_only and not cue_curtain else false
		if aim_now or aim_now != _aim_was_on:
			_aim_was_on = aim_now
			dirty = true
	if dirty:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or not rotatable or not _world_face_active():
		return false
	normal = normal.rotated(deg_to_rad(angle_step_deg)).normalized()
	_turn_t = 0.18
	_has_rotated = true
	_emit_sfx("mirror_turn")
	queue_redraw()
	return true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or not _world_face_active():
		return false
	if floor_only:
		return false
	if cue_curtain:
		if _can_player_pierce_curtain() or hit.light_color == "cream":
			_pierce_t = 0.24
			_emit_sfx("mirror_ping")
			queue_redraw()
			return false
		_flash_t = 0.18
		_emit_sfx("prop_rustle")
		queue_redraw()
		return true
	if hit.source in ["bolt", "prism_bolt", "beam"]:
		_flash_t = 0.2
		_emit_gust(38.0, 28.0)
		_emit_sfx("mirror_ping")
		queue_redraw()
		return true
	return false


func is_floor_toy() -> bool:
	return floor_only


func is_solid() -> bool:
	return active and not floor_only and _world_face_active()


func blocks_sight() -> bool:
	if not active or floor_only or not _world_face_active():
		return false
	if cue_curtain:
		return not _can_player_pierce_curtain()
	return true


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func is_reflective() -> bool:
	return active and not floor_only and not cue_curtain and _world_face_active()


func is_movable() -> bool:
	return active and movable and _world_face_active()


func get_transform_color() -> String:
	return transforms_to


func get_push_rect_at(target_pos: Vector2) -> Rect2:
	var inset: Vector2 = Vector2(maxf(8.0, size.x - 2.0), maxf(8.0, size.y - 2.0))
	return Rect2(target_pos - inset * 0.5, inset)


func move_to(new_pos: Vector2) -> void:
	pos = new_pos
	position = new_pos.round()
	queue_redraw()


func get_interact_prompt() -> String:
	if not active or floor_only or cue_curtain or not _world_face_active():
		return ""
	if movable and rotatable:
		return "PROMPT_TRANSFORMER"
	if movable:
		return "PROMPT_PUSH_BLOCK"
	if rotatable:
		return "PROMPT_TURN_MIRROR"
	return ""


func get_light_pool() -> Vector4:
	if not active or not _world_face_active():
		return Vector4.ZERO
	if cue_spotlight:
		var has_cue: bool = Lx.state != null and bool(Lx.state.story_flags.get("item_cue_mirror", false))
		return Vector4(pos.x, pos.y, spotlight_radius * (1.25 if has_cue else 0.9), 0.72 if has_cue else 0.42)
	if cue_curtain:
		return Vector4.ZERO
	var lit: bool = _flash_t > 0.0
	if transforms_to == LxHit.COLOR_BLUE:
		return Vector4(pos.x, pos.y - 4.0, 34.0 if lit else 28.0, 0.68 if lit else 0.50)
	return Vector4(pos.x, pos.y - 4.0, 30.0 if lit else 24.0, 0.62 if lit else 0.44)


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
	var out: Dictionary = {"active": active, "normal": [normal.x, normal.y]}
	if persist_pos:
		out["pos"] = [pos.x, pos.y]
	return out


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if d.has("normal"):
		var n: Vector2 = _parse_vec2(d.get("normal"), normal)
		if n.length_squared() > 0.001:
			normal = n.normalized()
	if persist_pos and d.has("pos"):
		move_to(_parse_vec2(d.get("pos"), pos))
	queue_redraw()


func _draw() -> void:
	var face_ok: bool = _world_face_active()
	if cue_spotlight:
		_draw_cue_spotlight(face_ok)
		if floor_only:
			return
	if cue_curtain:
		_draw_cue_curtain(face_ok)
		return
	if not face_ok:
		draw_rect(Rect2((-size * 0.5).round(), size.round()), Color(PAL["sky"] as Color, 0.25), false, 1.0)
		return
	var lit: bool = _flash_t > 0.0
	var is_blue_t: bool = transforms_to == LxHit.COLOR_BLUE
	# Unified contact shadow under the octagonal turntable base
	_draw_ground_shadow(8.0, 3.0, Vector2(2.0, 7.0))
	# Turntable base (push-grips vs fixed anchor bolts) + carved optical floor chevron inlay
	_draw_puzzle_sprite("mirror_base_push" if movable else "mirror_base_fixed")
	var aim_hit: bool = _is_player_aiming_here()
	if not movable or not _has_rotated:
		_draw_floor_chevron(lit or _turn_t > 0.0 or aim_hit, 1.0 if not movable else 0.76)
	# Warm octagonal brass pedestal base rim under Blue Transformers so they separate from blue masonry floors
	if kind == "blue_transformer":
		var rim_g: Color = PAL["gold"] as Color
		var rim_c: Color = PAL["cream"] as Color
		var oct := PackedVector2Array([
			Vector2(-4.0, -2.0), Vector2(4.0, -2.0),
			Vector2(8.0, 1.0), Vector2(8.0, 4.0),
			Vector2(4.0, 7.0), Vector2(-4.0, 7.0),
			Vector2(-8.0, 4.0), Vector2(-8.0, 1.0),
			Vector2(-4.0, -2.0),
		])
		draw_rect(Rect2(Vector2(-4.0, 8.0), Vector2(8.0, 1.0)), PAL["void"] as Color)
		draw_polyline(oct, rim_g, 1.0, false)
		draw_rect(Rect2(Vector2(-3.0, 6.0), Vector2(6.0, 1.0)), rim_c if (lit or _glint_stage == 0) else rim_g)
		draw_rect(Rect2(Vector2(-1.0, 7.0), Vector2(2.0, 1.0)), rim_c)
		draw_rect(Rect2(Vector2(-8.0, 2.0), Vector2(1.0, 2.0)), rim_c)
		draw_rect(Rect2(Vector2(7.0, 2.0), Vector2(1.0, 2.0)), rim_c)
		draw_rect(Rect2(Vector2(-2.0, -2.0), Vector2(4.0, 1.0)), rim_c)
	elif is_blue_t:
		draw_rect(Rect2(Vector2(-5.0, 5.0), Vector2(10.0, 1.0)), PAL["gold"] as Color)
		draw_rect(Rect2(Vector2(-1.0, 5.0), Vector2(2.0, 1.0)), PAL["cream"] as Color)
		draw_rect(Rect2(Vector2(-3.0, 6.0), Vector2(6.0, 1.0)), (PAL["cream"] if (lit or _glint_stage == 0) else PAL["gold"]) as Color)
	var ang_deg: float = fposmod(rad_to_deg(normal.angle()), 180.0)
	var snap_idx: int = int(roundf(ang_deg / 45.0)) % 4
	var ang_names: Array[String] = ["0", "45", "90", "135"]
	var prefix: String = "mirror_blue_" if is_blue_t else "mirror_brass_"
	_draw_puzzle_sprite(prefix + ang_names[snap_idx])
	# Subtle specular gleam pulse on crystal face
	if not lit and _glint_stage <= 1:
		var gpos := Vector2(-2.0 if _glint_stage == 0 else 1.0, -6.0 if _glint_stage == 0 else -4.0)
		draw_rect(Rect2(gpos, Vector2.ONE), PAL["cream"] as Color)
	# Crisp 1px dotted reflection aim-preview line + Island 2 PRISM SPLIT flanking preview rays
	var sight_a: Vector2 = (normal * 8.0).round()
	var sight_b: Vector2 = (normal * 10.0).round()
	draw_rect(Rect2(sight_a, Vector2.ONE), (PAL["ice"] if (_turn_t > 0.0 or lit or aim_hit) else PAL["sky"]) as Color)
	draw_rect(Rect2(sight_b, Vector2.ONE), (PAL["cream"] if (_turn_t > 0.0 or lit or aim_hit) else PAL["ice"]) as Color)
	if aim_hit and Lx.player != null and is_instance_valid(Lx.player):
		_draw_aim_preview(is_blue_t)
	if _turn_t > 0.0:
		var tc: Color = (PAL["ice"] if is_blue_t else PAL["gold"]) as Color
		for cp: Vector2 in [Vector2(-9.0, -2.0), Vector2(8.0, -2.0), Vector2(0.0, -11.0), Vector2(0.0, 7.0)]:
			draw_rect(Rect2(cp, Vector2.ONE), tc)
	if lit:
		_draw_puzzle_sprite("mirror_blue_flash" if is_blue_t else "mirror_brass_flash")


func _draw_aim_preview(is_blue_t: bool) -> void:
	var fv: Variant = Lx.player.get("facing")
	if not (fv is Vector2) or (fv as Vector2).length_squared() <= 0.01:
		return
	var in_dir: Vector2 = (fv as Vector2).normalized()
	var rdir: Vector2 = reflect_dir(in_dir)
	if rdir.length_squared() <= 0.01:
		return
	var reduced: bool = LxHudFx.flash_reduced()
	var p_dist: float = (Lx.player as Node2D).global_position.distance_to(pos) if Lx.player is Node2D else 999.0
	var close_hint: bool = p_dist <= CLOSE_HINT_RANGE
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	# Incoming yellow aim pips (gold -> ice transformation cue before firing)
	var in_max: float = minf(32.0, maxf(8.0, p_dist - 6.0))
	var in_d: float = 8.0
	var in_idx: int = 0
	while in_d <= in_max:
		var ip: Vector2 = (-in_dir * in_d).round()
		draw_rect(Rect2(ip, Vector2.ONE), c_gold if in_idx % 2 == 0 else c_apricot)
		in_d += 6.0
		in_idx += 1
	if close_hint and is_blue_t:
		draw_rect(Rect2((-in_dir * 7.0).round(), Vector2.ONE), c_gold)
		draw_rect(Rect2((rdir * 7.0).round(), Vector2.ONE), c_ice)
	var max_preview: float = 84.0
	var chain_mirror: LxMirror = _find_preview_chain_target(rdir, CHAIN_PREVIEW_RANGE)
	if chain_mirror != null:
		max_preview = minf(CHAIN_PREVIEW_RANGE, pos.distance_to(chain_mirror.pos))
	var step_d: float = 6.0
	var dist_p: float = 8.0
	var idx_p: int = 0
	while dist_p <= max_preview:
		var pp: Vector2 = (rdir * dist_p).round()
		var pcol: Color
		if is_blue_t:
			pcol = (c_cream if (idx_p == 0 and close_hint and not reduced) else (c_ice if idx_p % 2 == 0 else c_sky))
		else:
			pcol = (c_cream if (idx_p == 0 and not reduced) else (c_gold if idx_p % 2 == 0 else c_apricot))
		draw_rect(Rect2(pp, Vector2.ONE), pcol)
		dist_p += step_d
		idx_p += 1
	if Lx.state != null and Lx.state.has_move("prism"):
		for split_deg: float in [-18.0, 18.0]:
			var sdir: Vector2 = rdir.rotated(deg_to_rad(split_deg))
			var sdist: float = 10.0
			var sidx: int = 0
			while sdist <= 52.0:
				var sp: Vector2 = (sdir * sdist).round()
				var scol: Color = (c_sky if sidx % 2 == 0 else c_ice) if is_blue_t else (c_apricot if sidx % 2 == 0 else c_gold)
				draw_rect(Rect2(sp, Vector2.ONE), scol)
				sdist += step_d
				sidx += 1
	if chain_mirror != null:
		var rel_m: Vector2 = (chain_mirror.pos - pos).round()
		draw_rect(Rect2(rel_m + Vector2(-1.0, -4.0), Vector2.ONE), c_ice)
		draw_rect(Rect2(rel_m + Vector2(1.0, -4.0), Vector2.ONE), c_sky if reduced else c_cream)
		var rdir2: Vector2 = chain_mirror.reflect_dir(rdir)
		if rdir2.length_squared() > 0.01:
			var chain_blue: bool = is_blue_t or chain_mirror.transforms_to == LxHit.COLOR_BLUE
			for pi2: int in range(1, 11):
				var pp2: Vector2 = (rel_m + rdir2 * (8.0 + float(pi2) * 6.0)).round()
				var c2: Color = (c_ice if pi2 % 2 == 1 else c_sky) if chain_blue else (c_gold if pi2 % 2 == 1 else c_apricot)
				draw_rect(Rect2(pp2, Vector2.ONE), c2)


func _draw_floor_chevron(bright: bool, alpha: float) -> void:
	var n: Vector2 = normal.normalized()
	if n.length_squared() <= 0.001:
		return
	var c: Vector2 = (n * (15.0 if not movable else 12.0)).round()
	var sh_c := Color(PAL["void"] as Color, alpha)
	var gl_c := Color((PAL["cream"] if bright else PAL["gold"]) as Color, alpha)
	var ap_c := Color(PAL["cream"] as Color, alpha)
	var idx: int = int(roundf(fposmod(rad_to_deg(n.angle()), 360.0) / 45.0)) % 8
	var pts: Array[Vector2] = []
	var apex: Vector2 = c
	var half_i: int = idx >> 1
	if idx % 2 == 0:
		var card_dirs: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)]
		var fwd: Vector2 = card_dirs[half_i]
		var perp := Vector2(-fwd.y, fwd.x)
		apex = c + fwd
		pts = [c, c + perp, c - perp, c - fwd + perp * 2.0, c - fwd - perp * 2.0]
	else:
		var diag_dirs: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0)]
		var diag: Vector2 = diag_dirs[half_i]
		apex = c + diag
		pts = [
			c,
			apex + Vector2(-diag.x, 0.0), apex + Vector2(-diag.x * 2.0, 0.0),
			apex + Vector2(0.0, -diag.y), apex + Vector2(0.0, -diag.y * 2.0),
		]
	if not movable:
		for d_pip: float in [9.0, 12.0]:
			var pip: Vector2 = (n * d_pip).round()
			draw_rect(Rect2(pip + Vector2(0.0, 1.0), Vector2.ONE), sh_c)
			draw_rect(Rect2(pip, Vector2.ONE), gl_c)
	for p: Vector2 in pts:
		draw_rect(Rect2(p + Vector2(0.0, 1.0), Vector2.ONE), sh_c)
	draw_rect(Rect2(apex + Vector2(0.0, 1.0), Vector2.ONE), sh_c)
	for p: Vector2 in pts:
		draw_rect(Rect2(p, Vector2.ONE), gl_c)
	draw_rect(Rect2(apex, Vector2.ONE), ap_c)


func _find_preview_chain_target(rdir: Vector2, max_range: float) -> LxMirror:
	if region == null or not region.has_method("get_interactables"):
		return null
	var best: LxMirror = null
	var best_proj: float = max_range
	for it_v: Variant in region.call("get_interactables") as Array:
		if not (it_v is LxMirror):
			continue
		var m: LxMirror = it_v as LxMirror
		if m == self or not m.is_reflective():
			continue
		var rel: Vector2 = m.pos - pos
		var proj: float = rel.dot(rdir)
		if proj <= 8.0 or proj >= best_proj:
			continue
		var perp: float = (rel - rdir * proj).length()
		if perp <= maxf(m.size.x, m.size.y) * 0.55:
			if not region.has_method("clear_view") or bool(region.call("clear_view", pos + rdir * 9.0, m.pos - rdir * 9.0)):
				best_proj = proj
				best = m
	return best


func _is_player_aiming_here() -> bool:
	if not active:
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


func _draw_cue_spotlight(face_ok: bool) -> void:
	if not face_ok:
		return
	var has_cue: bool = Lx.state != null and bool(Lx.state.story_flags.get("item_cue_mirror", false))
	var wick_in: bool = Lx.player is Node2D and is_instance_valid(Lx.player) and contains_spotlight((Lx.player as Node2D).global_position)
	var r: float = roundf(spotlight_radius)
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var fill_a: float = 0.22 if (has_cue and wick_in) else (0.14 if has_cue else 0.08)
	draw_circle(Vector2.ZERO, r, Color(c_gold if has_cue else c_apricot, fill_a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(c_cream if (has_cue and wick_in) else c_gold, 0.85 if has_cue else 0.45), 2.0 if wick_in else 1.0)
	draw_arc(Vector2.ZERO, maxf(6.0, r - 5.0), 0.0, TAU, 18, Color(c_apricot, 0.40), 1.0)
	# Crisp 4-point stage mark at center (greyscale-distinct Cue-Mirror emblem)
	draw_rect(Rect2(-1.0, -3.0, 2.0, 6.0), c_cream if wick_in else c_gold)
	draw_rect(Rect2(-3.0, -1.0, 6.0, 2.0), c_cream if wick_in else c_gold)


func _draw_cue_curtain(face_ok: bool) -> void:
	if not face_ok:
		return
	var r := Rect2((-size * 0.5).round(), size.round())
	var piercing: bool = _can_player_pierce_curtain()
	var c_void: Color = PAL["void"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	draw_rect(r.grow(1.0), c_void)
	draw_rect(r, c_plum if piercing else c_wine)
	# Vertical pleated velvet folds
	var x: float = r.position.x + 2.0
	var fold_i: int = 0
	while x < r.end.x - 1.0:
		var fc: Color = (c_gold if (piercing and fold_i % 2 == 0) else (c_coral if fold_i % 2 == 0 else c_void))
		draw_rect(Rect2(x, r.position.y + 1.0, 1.0, maxf(1.0, r.size.y - 2.0)), fc)
		x += 3.0
		fold_i += 1
	# Top gilded curtain rod & tassels
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2.0), c_cream if (_pierce_t > 0.0 or piercing) else c_gold)
	if _flash_t > 0.0:
		draw_rect(r, c_coral, false, 1.0)
	elif _pierce_t > 0.0:
		draw_rect(r, c_cream, false, 2.0)
