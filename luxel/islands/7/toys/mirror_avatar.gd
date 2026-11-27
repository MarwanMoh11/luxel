class_name LxMirrorAvatar
extends LxToy
## Island 7 Living Reflection across `G` glass partitions:
## - Walks mirrored with Wick along `axis` ("x"|"y"|"both"), desyncing cleanly against walls.
## - Presses pressure plates & balance scales (`is_echo_active`), and pushes `push_block` & movable `LxMirror`s.
## - Mirrors Wick's bolts, beams, and throws (reflecting off Blue Transformers & damaging reflection-only bosses).
## - Supports opposite-world occupancy (`mirror_world: "opposite"` swaps Silver/Black on Moon Pool flips).
## Props: axis ("x"|"y"|"both"), pivot [x,y], fires_mirror_bolts (bool), mirror_world ("same"|"opposite"),
## vulnerable_boss_id (String), sync_reset_id (String), size [w,h], range (float), persist (bool).

enum State { SYNCED, DESYNCED_WALL, PHANTOM_DIM, SHATTERED }

const MIRROR_BOLT_SPEED: float = 310.0
const MIRROR_BOLT_RANGE: float = 156.0
const MIRROR_BEAM_RANGE: float = 200.0
const MIRROR_BOLT_DMG: float = 0.65
const MIRROR_BEAM_DMG: float = 2.2

var axis: String = "x"
var pivot: Vector2 = Vector2.INF
var fires_mirror_bolts: bool = true
var mirror_world: String = "same"
var vulnerable_boss_id: String = ""
var sync_reset_id: String = ""
var link_range: float = 360.0
var origin_pos: Vector2 = Vector2.ZERO
var state: int = State.SYNCED
var facing: Vector2 = Vector2.LEFT

var _last_wick_pos: Vector2 = Vector2.INF
var _last_shots: int = 0
var _last_beams: int = 0
var _wick_bound: LxWick = null
var _bolts: Array[Dictionary] = [] # [{pos, prev, dir, dist, color, prism, bounces, hit_ids}]
var _beam_segs: Array[Dictionary] = [] # [{start, end, color}]
var _beam_vis_t: float = 0.0
var _move_t: float = 0.0
var _step_sfx_cd: float = 0.0
var _blocked_t: float = 0.0
var _shot_flash_t: float = 0.0
var _resync_t: float = 0.0


func _toy_setup() -> void:
	kind = "mirror_avatar"
	axis = str(props.get("axis", props.get("mirror", "x"))).strip_edges().to_lower()
	if axis not in ["x", "y", "both"]:
		axis = "x"
	if props.has("pivot"):
		pivot = LxMapFormat.to_vec2(props.get("pivot"), Vector2.INF)
	else:
		pivot = Vector2.INF
	fires_mirror_bolts = bool(props.get("fires_mirror_bolts", true))
	mirror_world = str(props.get("mirror_world", "same")).strip_edges().to_lower()
	if mirror_world not in ["same", "opposite"]:
		mirror_world = "same"
	vulnerable_boss_id = str(props.get("vulnerable_boss_id", "")).strip_edges().to_lower()
	sync_reset_id = str(props.get("sync_reset_id", "")).strip_edges()
	if not props.has("size"):
		size = Vector2(14.0, 14.0)
	radius = maxf(size.x, size.y) * 0.5
	link_range = maxf(80.0, float(props.get("range", 360.0)))
	origin_pos = pos
	state = State.SYNCED
	facing = _mirror_vec(Vector2.RIGHT)
	_last_wick_pos = Vector2.INF
	_bolts.clear()
	_beam_segs.clear()
	_beam_vis_t = 0.0
	_move_t = 0.0
	_blocked_t = 0.0
	_shot_flash_t = 0.0
	_resync_t = 0.0
	_bind_wick()
	var wp_init: Vector2 = wick_pos()
	if wp_init.x > -9000.0:
		_last_wick_pos = wp_init
	queue_redraw()


func _exit_tree() -> void:
	_unbind_wick()


func _bind_wick() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if _wick_bound == w:
		return
	_unbind_wick()
	_wick_bound = w
	_last_shots = w.shots_fired
	_last_beams = w.move_beam.beams_fired if w.move_beam != null else 0
	if not w.fired.is_connected(_on_wick_fired):
		w.fired.connect(_on_wick_fired)


func _unbind_wick() -> void:
	if _wick_bound != null and is_instance_valid(_wick_bound):
		if _wick_bound.fired.is_connected(_on_wick_fired):
			_wick_bound.fired.disconnect(_on_wick_fired)
	_wick_bound = null


func reset_toy() -> void:
	if persist:
		return
	resync()


func sync_wick_origin() -> void:
	_bind_wick()
	var wp: Vector2 = wick_pos()
	if wp.x > -9000.0:
		_last_wick_pos = wp


func resync() -> void:
	var target: Vector2 = origin_pos
	var wp: Vector2 = wick_pos()
	if pivot.is_finite() and wp.x > -9000.0:
		var rel: Vector2 = wp - pivot
		target = pivot + _mirror_vec(rel)
		target = _move_with_collision(target)
	pos = target
	position = pos.round()
	_last_wick_pos = wp if wp.x > -9000.0 else Vector2.INF
	state = State.SYNCED
	_blocked_t = 0.0
	_resync_t = 0.35
	_bolts.clear()
	_beam_segs.clear()
	_emit_sfx("mirror_ping")
	queue_redraw()


func on_signal(from_id: String, is_on: bool) -> void:
	super.on_signal(from_id, is_on)
	if is_on and (sync_reset_id.is_empty() or from_id == sync_reset_id):
		resync()


func get_avatar_world_face() -> String:
	var cur: String = "silver"
	if Lx.vars != null:
		cur = str(Lx.vars.resolve_var("world_face", island_id, region_id, "silver")).strip_edges().to_lower()
	if cur != "black":
		cur = "silver"
	if mirror_world == "opposite":
		return "black" if cur == "silver" else "silver"
	return cur


func is_in_world(face: String) -> bool:
	return get_avatar_world_face() == face.strip_edges().to_lower()


func is_solid() -> bool:
	return active and state != State.SHATTERED and state != State.PHANTOM_DIM


func blocks_sight() -> bool:
	return false


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


## Allows LxPressurePlate and LxScale to sense the mirror avatar cleanly with weight 1.0 (no double-count).
func is_echo_active() -> bool:
	return is_solid()


func get_echo_pos() -> Vector2:
	return pos


func shatter() -> void:
	state = State.SHATTERED
	_bolts.clear()
	_beam_segs.clear()
	_emit_sfx("shield_shatter")
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active or state == State.SHATTERED:
		return
	_bind_wick()
	var dirty: bool = false
	if _move_t > 0.0:
		_move_t = maxf(0.0, _move_t - dt); dirty = true
	if _step_sfx_cd > 0.0:
		_step_sfx_cd = maxf(0.0, _step_sfx_cd - dt)
	if _blocked_t > 0.0:
		_blocked_t = maxf(0.0, _blocked_t - dt); dirty = true
	if _shot_flash_t > 0.0:
		_shot_flash_t = maxf(0.0, _shot_flash_t - dt); dirty = true
	if _resync_t > 0.0:
		_resync_t = maxf(0.0, _resync_t - dt); dirty = true
	if _beam_vis_t > 0.0:
		_beam_vis_t = maxf(0.0, _beam_vis_t - dt); dirty = true
		if _beam_vis_t <= 0.0:
			_beam_segs.clear()

	# Poll Wick facing & fallback beam counter (for fire_instant_beam which doesn't emit fired)
	if _wick_bound != null and is_instance_valid(_wick_bound):
		if _wick_bound.facing.length_squared() > 0.01:
			facing = _mirror_vec(_wick_bound.facing).normalized()
		if _wick_bound.move_beam != null:
			var cur_b: int = _wick_bound.move_beam.beams_fired
			if cur_b > _last_beams:
				_last_beams = cur_b
				if fires_mirror_bolts:
					_fire_mirror_beam(facing)
					dirty = true
			elif cur_b < _last_beams:
				_last_beams = cur_b

	var wp: Vector2 = wick_pos()
	if wp.x > -9000.0:
		if not _last_wick_pos.is_finite():
			_last_wick_pos = wp
		else:
			var delta: Vector2 = wp - _last_wick_pos
			_last_wick_pos = wp
			if delta.length_squared() > 0.0001 and delta.length() <= 52.0 and wp.distance_to(pos) <= link_range:
				var mdelta: Vector2 = _mirror_vec(delta)
				_try_push_obstacles(mdelta)
				var resolved: Vector2 = _move_with_collision(pos + mdelta)
				if resolved.distance_squared_to(pos) > 0.0001:
					if _step_sfx_cd <= 0.0 and resolved.distance_to(pos) > 0.4:
						_step_sfx_cd = 0.34
						_emit_sfx("mirror_avatar_step")
					pos = resolved
					position = pos.round()
					_move_t = 0.14
					if _blocked_t <= 0.0:
						state = State.SYNCED
					dirty = true
				elif mdelta.length() > 0.35:
					_blocked_t = 0.26
					state = State.DESYNCED_WALL
					dirty = true

	if not _bolts.is_empty():
		_tick_mirror_bolts(dt)
		dirty = true
	if dirty:
		queue_redraw()


func _on_wick_fired(aim_dir: Vector2, fire_kind: String) -> void:
	if not active or not fires_mirror_bolts or state == State.SHATTERED or state == State.PHANTOM_DIM:
		return
	var wp: Vector2 = wick_pos()
	if wp.x > -9000.0 and wp.distance_to(pos) > link_range:
		return
	var mdir: Vector2 = _mirror_vec(aim_dir).normalized()
	if mdir.length_squared() <= 0.001:
		mdir = facing
	facing = mdir
	if fire_kind == "beam":
		_fire_mirror_beam(mdir)
	elif fire_kind == "bolt" or fire_kind == "throw":
		_spawn_mirror_bolt(pos + mdir * 7.0, mdir, fire_kind == "throw")
	queue_redraw()


func _spawn_mirror_bolt(from_p: Vector2, dir: Vector2, is_heavy_echo: bool = false) -> void:
	var c_init: String = LxHit.COLOR_BLUE if is_in_world("black") else LxHit.COLOR_YELLOW
	_bolts.append({
		"pos": from_p,
		"prev": from_p,
		"dir": dir.normalized(),
		"dist": 0.0,
		"color": c_init,
		"prism": c_init == LxHit.COLOR_BLUE,
		"heavy": is_heavy_echo,
		"bounces": 2,
		"hit_ids": [get_instance_id()],
	})
	_shot_flash_t = 0.16
	_emit_sfx("bolt_fire")


func _fire_mirror_beam(dir: Vector2) -> void:
	_beam_segs.clear()
	_beam_vis_t = 0.24
	_shot_flash_t = 0.20
	var cur: Vector2 = pos + dir * 7.0
	var cur_dir: Vector2 = dir.normalized()
	var col_name: String = LxHit.COLOR_BLUE if is_in_world("black") else LxHit.COLOR_YELLOW
	var bounces: int = 2
	var hit_ids: Dictionary = {get_instance_id(): true}
	var rem: float = MIRROR_BEAM_RANGE

	while rem > 4.0:
		var seg_start: Vector2 = cur
		var seg_end: Vector2 = cur
		var step: float = 4.0
		var bounced: bool = false
		while rem > 0.0:
			var s: float = minf(step, rem)
			var nxt: Vector2 = cur + cur_dir * s
			rem -= s
			if _blocks_shot_tile(nxt):
				seg_end = cur
				rem = 0.0
				break
			# Enemies
			if region != null and region.has_method("get_enemies"):
				for e_v: Variant in (region.call("get_enemies") as Array):
					if e_v is LxEnemyBrain and is_instance_valid(e_v):
						var e: LxEnemyBrain = e_v as LxEnemyBrain
						if e.is_alive() and not hit_ids.has(e.get_instance_id()):
							if Geometry2D.get_closest_point_to_segment(e.pos, cur, nxt).distance_to(e.pos) <= e.body_radius + 3.0:
								hit_ids[e.get_instance_id()] = true
								_apply_mirror_hit_to_enemy(e, LxHit.SOURCE_BEAM, MIRROR_BEAM_DMG, cur_dir, cur, col_name)
			# Interactables
			if region != null and region.has_method("get_interactables"):
				for it_v: Variant in (region.call("get_interactables") as Array):
					if not (it_v is LxInteractable) or it_v == self:
						continue
					var it: LxInteractable = it_v as LxInteractable
					if not is_instance_valid(it) or not it.active or hit_ids.has(it.get_instance_id()):
						continue
					if Geometry2D.get_closest_point_to_segment(it.pos, cur, nxt).distance_to(it.pos) > it.radius + 3.0:
						continue
					if it.is_reflective() and bounces > 0:
						var rdir: Vector2 = it.reflect_dir(cur_dir)
						if rdir.length_squared() > 0.01:
							hit_ids[it.get_instance_id()] = true
							bounces -= 1
							seg_end = it.pos
							_beam_segs.append({"start": seg_start, "end": seg_end, "color": col_name})
							col_name = str(it.call("get_transform_color")) if it.has_method("get_transform_color") else LxHit.COLOR_BLUE
							if col_name.is_empty():
								col_name = LxHit.COLOR_BLUE
							var ping: LxHit = LxHit.make(LxHit.SOURCE_BEAM, MIRROR_BEAM_DMG, cur_dir, it.pos, 1.0, false, true, self, false, col_name)
							it.on_hit(ping)
							cur_dir = rdir.normalized()
							cur = it.pos + cur_dir * (it.radius + 2.0)
							rem = MIRROR_BEAM_RANGE * 0.85
							bounced = true
							break
					if it.has_method("get_tint_color"):
						var tc: String = str(it.call("get_tint_color"))
						if not tc.is_empty():
							col_name = LxToyDraw.to_hit_color(tc)
							hit_ids[it.get_instance_id()] = true
							continue
					hit_ids[it.get_instance_id()] = true
					var ihit: LxHit = LxHit.make(LxHit.SOURCE_BEAM, MIRROR_BEAM_DMG, cur_dir, cur, 2.0, true, true, self, false, col_name)
					if it.has_method("receive_beam"):
						it.call("receive_beam", LxToyDraw.normalize_light_color(col_name), id)
					else:
						it.on_hit(ihit)
					if it.blocks_sight() and not (it.kind in ["bramble", "web", "cracked_wall"]):
						seg_end = cur
						rem = 0.0
						break
			if bounced or rem <= 0.0:
				break
			cur = nxt
			seg_end = cur
		if not bounced:
			_beam_segs.append({"start": seg_start, "end": seg_end, "color": col_name})
			break
	_emit_sfx("beam_fire")


func _tick_mirror_bolts(dt: float) -> void:
	var i: int = _bolts.size() - 1
	while i >= 0:
		var b: Dictionary = _bolts[i]
		var bp: Vector2 = b["pos"] as Vector2
		var bdir: Vector2 = b["dir"] as Vector2
		var step: float = MIRROR_BOLT_SPEED * dt
		var nxt: Vector2 = bp + bdir * step
		var dead: bool = false
		var bounced: bool = false
		var hit_ids: Array = b["hit_ids"] as Array
		var col_s: String = str(b["color"])
		var is_p: bool = bool(b["prism"])

		if region != null and is_instance_valid(region):
			if region.has_method("get_enemies"):
				for e_v: Variant in (region.call("get_enemies") as Array):
					if e_v is LxEnemyBrain and is_instance_valid(e_v):
						var e: LxEnemyBrain = e_v as LxEnemyBrain
						var eid: int = e.get_instance_id()
						if not e.is_alive() or hit_ids.has(eid):
							continue
						if Geometry2D.get_closest_point_to_segment(e.pos, bp, nxt).distance_to(e.pos) <= e.body_radius + 3.0:
							hit_ids.append(eid)
							var src_e: String = LxHit.SOURCE_PRISM if is_p else LxHit.SOURCE_BOLT
							var dmg_e: float = MIRROR_BOLT_DMG * (1.4 if bool(b["heavy"]) else 1.0)
							_apply_mirror_hit_to_enemy(e, src_e, dmg_e, bdir, bp, col_s)
							dead = true
							break
			if not dead and region.has_method("get_interactables"):
				for it_v: Variant in (region.call("get_interactables") as Array):
					if not (it_v is LxInteractable) or it_v == self:
						continue
					var it: LxInteractable = it_v as LxInteractable
					if not is_instance_valid(it) or not it.active:
						continue
					var iid: int = it.get_instance_id()
					if hit_ids.has(iid):
						continue
					if Geometry2D.get_closest_point_to_segment(it.pos, bp, nxt).distance_to(it.pos) > it.radius + 3.0:
						continue
					if it.is_reflective() and int(b["bounces"]) > 0:
						var rdir: Vector2 = it.reflect_dir(bdir)
						if rdir.length_squared() > 0.01:
							b["dir"] = rdir.normalized()
							b["bounces"] = int(b["bounces"]) - 1
							b["prism"] = true
							var tcol: String = str(it.call("get_transform_color")) if it.has_method("get_transform_color") else LxHit.COLOR_BLUE
							b["color"] = tcol if not tcol.is_empty() else LxHit.COLOR_BLUE
							b["dist"] = 0.0
							hit_ids.clear()
							hit_ids.append(iid)
							b["pos"] = it.pos + (b["dir"] as Vector2) * (it.radius + 2.0)
							var ping: LxHit = LxHit.make(LxHit.SOURCE_PRISM, MIRROR_BOLT_DMG, bdir, it.pos, 0.4, false, false, self, false, str(b["color"]))
							it.on_hit(ping)
							_emit_sfx("prism_bounce")
							bounced = true
							break
					if it.has_method("get_tint_color"):
						var tc: String = str(it.call("get_tint_color"))
						if not tc.is_empty():
							b["color"] = LxToyDraw.to_hit_color(tc)
							b["prism"] = (str(b["color"]) == LxHit.COLOR_BLUE)
							hit_ids.append(iid)
							continue
					hit_ids.append(iid)
					var src_i: String = LxHit.SOURCE_PRISM if is_p else LxHit.SOURCE_BOLT
					var ihit: LxHit = LxHit.make(src_i, MIRROR_BOLT_DMG, bdir, bp, 0.5, false, false, self, is_p, col_s)
					if it.on_hit(ihit):
						dead = true
						break
			if not dead and not bounced and _blocks_shot_tile(nxt):
				dead = true

		if not bounced:
			b["prev"] = bp
			b["pos"] = nxt
			b["dist"] = float(b["dist"]) + step
		if dead or float(b["dist"]) >= MIRROR_BOLT_RANGE:
			_bolts.remove_at(i)
		i -= 1


func _apply_mirror_hit_to_enemy(e: LxEnemyBrain, src: String, dmg: float, dir: Vector2, origin: Vector2, col_s: String) -> void:
	var is_ref_boss: bool = (not vulnerable_boss_id.is_empty()) and (e.boss_id.to_lower() == vulnerable_boss_id or e.kind.to_lower() == vulnerable_boss_id)
	var use_src: String = LxHit.SOURCE_PRISM if is_ref_boss else src
	var use_col: String = LxHit.COLOR_BLUE if is_ref_boss else col_s
	var hit: LxHit = LxHit.make(use_src, dmg, dir, origin, 0.8, is_ref_boss, false, self, is_ref_boss, use_col)
	e.take_hit(hit)


func _try_push_obstacles(mdelta: Vector2) -> void:
	if region == null or not region.has_method("get_interactables") or mdelta.length_squared() <= 0.0001:
		return
	var probe: Rect2 = rect_at(pos + mdelta).grow(2.0)
	for it_v: Variant in (region.call("get_interactables") as Array):
		if not (it_v is LxInteractable) or it_v == self:
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not is_instance_valid(it) or not it.active or not it.is_solid():
			continue
		if not (it.has_method("is_movable") and bool(it.call("is_movable"))):
			continue
		if not it.get_solid_rect().intersects(probe):
			continue
		if it.kind == "push_block" and str(it.get("variant")) == "ice" and it.has_method("start_ice_slide"):
			it.call("start_ice_slide", mdelta)
			continue
		if it.has_method("get_push_rect_at") and it.has_method("move_to"):
			var dest: Vector2 = it.pos + mdelta
			var prect: Rect2 = it.call("get_push_rect_at", dest) as Rect2
			if not region.has_method("can_place_rect") or bool(region.call("can_place_rect", prect, it.id)):
				it.call("move_to", dest)


func _mirror_vec(v: Vector2) -> Vector2:
	match axis:
		"y": return Vector2(v.x, -v.y)
		"both": return Vector2(-v.x, -v.y)
		_: return Vector2(-v.x, v.y)


func _move_with_collision(target: Vector2) -> Vector2:
	if region == null or not is_instance_valid(region):
		return target
	var r: float = maxf(4.5, minf(size.x, size.y) * 0.42)
	if region.has_method("collide"):
		var cur: Vector2 = pos
		var try_x: Vector2 = region.call("collide", Vector2(target.x, cur.y), r, false, false, id) as Vector2
		if not _is_blocked_tile(try_x):
			cur.x = try_x.x
		var try_y: Vector2 = region.call("collide", Vector2(cur.x, target.y), r, false, false, id) as Vector2
		if not _is_blocked_tile(try_y):
			cur.y = try_y.y
		return cur
	return target


func _is_blocked_tile(p: Vector2) -> bool:
	if region == null or not region.has_method("tile_at"):
		return false
	var tt: String = str(region.call("tile_at", p))
	if tt == "glass" or tt == "mirror":
		return true
	if not LxMapFormat.is_solid_tile(tt, false, false):
		return false
	if tt in ["pit", "void", "water", "tide", "phantom"] and region.has_method("is_lethal_void_at"):
		return bool(region.call("is_lethal_void_at", p))
	return true


func _blocks_shot_tile(p: Vector2) -> bool:
	if region == null or not region.has_method("tile_at"):
		return false
	var tt: String = str(region.call("tile_at", p))
	return tt == "glass" or tt == "mirror" or LxMapFormat.blocks_sight_tile(tt)


func get_light_pool() -> Vector4:
	if not is_solid():
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 40.0 if _shot_flash_t > 0.0 else 30.0, 0.72 if _shot_flash_t > 0.0 else 0.48)


func _draw() -> void:
	LxIsland7RuleFx.draw_mirror_avatar(
		self, pos, state, is_in_world("black"), facing, pivot, link_range,
		wick_pos(), _blocked_t, _shot_flash_t, _resync_t, _bolts, _beam_segs, _beam_vis_t
	)
