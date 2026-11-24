class_name LxMimicStatue
extends LxToy
## Stone Wick effigy that moves mirrored with Wick (`mirror` / `axis`: "x" | "y" | "both").
## Blocked by walls, unsupported pits/water, and solids; rides moving platforms, pushes pressure plates
## and balance scales, and optionally pushes blocks (`can_push: true`) or gates on `world_face`.
## Props: mirror/axis ("x"|"y"|"both"), size [w,h], range (float), weight (float), can_push (bool),
## world_face (""|"silver"|"black"), shadow_mode ("se_gold"|"nw_wrong"|"none"), reset_on_signal (bool), persist (bool).

var mirror_mode: String = "x"
var origin_pos: Vector2 = Vector2.ZERO
var link_range: float = 280.0
var can_push: bool = false
var world_face: String = ""
var shadow_mode: String = "se_gold"
var reset_on_signal: bool = false
var _last_wick_pos: Vector2 = Vector2.INF
var _move_t: float = 0.0
var _blocked_t: float = 0.0
var _last_plat_id: int = -1
var _last_plat_pos: Vector2 = Vector2.ZERO


func _toy_setup() -> void:
	kind = "mimic_statue"
	mirror_mode = str(props.get("mirror", props.get("axis", "x"))).strip_edges().to_lower()
	if mirror_mode not in ["x", "y", "both"]:
		mirror_mode = "x"
	if not props.has("size"):
		size = Vector2(14.0, 14.0)
	radius = maxf(size.x, size.y) * 0.5
	origin_pos = pos
	link_range = maxf(64.0, float(props.get("range", 280.0)))
	can_push = bool(props.get("can_push", false))
	world_face = str(props.get("world_face", "")).strip_edges().to_lower()
	shadow_mode = str(props.get("shadow_mode", "se_gold")).strip_edges().to_lower()
	reset_on_signal = bool(props.get("reset_on_signal", false))
	_last_wick_pos = Vector2.INF
	_move_t = 0.0
	_blocked_t = 0.0
	_last_plat_id = -1
	_last_plat_pos = Vector2.ZERO
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	pos = origin_pos
	position = pos.round()
	_last_wick_pos = Vector2.INF
	_move_t = 0.0
	_blocked_t = 0.0
	_last_plat_id = -1
	queue_redraw()


func on_signal(from_id: String, is_on: bool) -> void:
	super.on_signal(from_id, is_on)
	if reset_on_signal and is_on:
		pos = origin_pos
		position = pos.round()
		_last_wick_pos = Vector2.INF
		_blocked_t = 0.0
		_move_t = 0.14
		queue_redraw()


func _world_face_active() -> bool:
	if world_face.is_empty():
		return true
	var cur: String = str(LxToyDraw.world_get_var("island:%d" % clampi(island_id, 1, 8), "world_face", "silver")).to_lower()
	if Lx.vars != null:
		cur = str(Lx.vars.resolve_var("world_face", island_id, region_id, cur)).to_lower()
	return cur == world_face


func is_solid() -> bool:
	return active and _world_face_active()


func blocks_sight() -> bool:
	return is_solid()


func is_weight_body() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _move_t > 0.0:
		_move_t = maxf(0.0, _move_t - dt)
		dirty = true
	if _blocked_t > 0.0:
		_blocked_t = maxf(0.0, _blocked_t - dt)
		dirty = true
	if not _world_face_active():
		_last_wick_pos = Vector2.INF
		if dirty:
			queue_redraw()
		return
	if _ride_moving_platform():
		dirty = true
	var wp: Vector2 = wick_pos()
	if wp.x < -9000.0:
		if dirty:
			queue_redraw()
		return
	if not _last_wick_pos.is_finite():
		_last_wick_pos = wp
		if dirty:
			queue_redraw()
		return
	var delta: Vector2 = wp - _last_wick_pos
	_last_wick_pos = wp
	if delta.length_squared() <= 0.0001 or delta.length() > 48.0:
		if dirty:
			queue_redraw()
		return
	if wp.distance_to(pos) > link_range:
		if dirty:
			queue_redraw()
		return
	var mdelta: Vector2 = _mirror_delta(delta)
	var target: Vector2 = pos + mdelta
	if can_push:
		_try_push_obstacles(mdelta)
	var resolved: Vector2 = _move_with_collision(target)
	if resolved.distance_squared_to(pos) > 0.0001:
		pos = resolved
		position = pos.round()
		_move_t = 0.14
		dirty = true
	elif mdelta.length() > 0.5:
		_blocked_t = 0.16
		dirty = true
	if dirty:
		queue_redraw()


func _ride_moving_platform() -> bool:
	if region == null or not region.has_method("get_interactables"):
		return false
	for it_v: Variant in (region.call("get_interactables") as Array):
		if not (it_v is LxInteractable) or it_v == self:
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not is_instance_valid(it) or not it.active or not it.is_platform_solid():
			continue
		var prect: Rect2 = it.get_platform_rect()
		if prect.has_area() and prect.has_point(pos):
			var pid: int = it.get_instance_id()
			if pid == _last_plat_id:
				var pdelta: Vector2 = it.pos - _last_plat_pos
				_last_plat_pos = it.pos
				if pdelta.length_squared() > 0.0001:
					var nxt: Vector2 = _move_with_collision(pos + pdelta)
					if nxt.distance_squared_to(pos) > 0.0001:
						pos = nxt
						position = pos.round()
						return true
			else:
				_last_plat_id = pid
				_last_plat_pos = it.pos
			return false
	_last_plat_id = -1
	return false


func _try_push_obstacles(mdelta: Vector2) -> void:
	if region == null or not region.has_method("get_interactables") or mdelta.length_squared() <= 0.0001:
		return
	var probe: Rect2 = rect_at(pos + mdelta).grow(1.5)
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


func _mirror_delta(d: Vector2) -> Vector2:
	match mirror_mode:
		"y":
			return Vector2(d.x, -d.y)
		"both":
			return Vector2(-d.x, -d.y)
		_:
			return Vector2(-d.x, d.y)


func _move_with_collision(target: Vector2) -> Vector2:
	if region == null or not is_instance_valid(region):
		return target
	var r: float = maxf(5.0, minf(size.x, size.y) * 0.45)
	if region.has_method("collide"):
		var cur: Vector2 = pos
		var try_x: Vector2 = region.call("collide", Vector2(target.x, cur.y), r, false, false, id) as Vector2
		if not _hits_solid_rect(try_x):
			cur.x = try_x.x
		var try_y: Vector2 = region.call("collide", Vector2(cur.x, target.y), r, false, false, id) as Vector2
		if not _hits_solid_rect(try_y):
			cur.y = try_y.y
		return cur
	return target


func _hits_solid_rect(p: Vector2) -> bool:
	if region == null or not region.has_method("tile_at"):
		return false
	var tt: String = str(region.call("tile_at", p))
	if not LxMapFormat.is_solid_tile(tt, false, false):
		return false
	if tt in ["pit", "void", "water", "tide", "phantom"] and region.has_method("is_lethal_void_at"):
		return bool(region.call("is_lethal_void_at", p))
	return true


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["pos"] = [pos.x, pos.y]
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("pos"):
		pos = LxMapFormat.to_vec2(d["pos"], pos)
		position = pos.round()
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var dim_face: bool = not _world_face_active()
	var c_glow: Color = PAL["ice"] as Color if _move_t > 0.0 else (PAL["sky"] as Color)
	var trip: Array[Color] = LxToyDraw.skin_triplet(island_id, skin)
	if dim_face:
		draw_rect(Rect2(-5.0, -9.0, 10.0, 14.0), Color(PAL["sky"] as Color, 0.25), false, 1.0)
		return

	if shadow_mode == "nw_wrong":
		LxToyDraw.draw_contact_shadow(self, Vector2(-3.0, -3.0), 6.0, 2.5)
	elif shadow_mode != "none":
		LxToyDraw.draw_contact_shadow(self, Vector2(2.0, 5.0), 6.0, 2.5)
	# Beveled plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-6.0, 0.0, 12.0, 6.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["stone"] as Color, c_void)
	# Cloaked Wick stone statue silhouette (pointed hood + cape shoulders)
	draw_rect(Rect2(-3.0, -13.0, 6.0, 3.0), c_void)
	draw_rect(Rect2(-5.0, -10.0, 10.0, 11.0), c_void)
	draw_rect(Rect2(-2.0, -12.0, 4.0, 2.0), PAL["stone"] as Color)
	draw_rect(Rect2(-4.0, -9.0, 8.0, 9.0), PAL["dusk"] as Color)
	draw_rect(Rect2(-3.0, -9.0, 6.0, 8.0), PAL["mauve"] as Color)
	draw_rect(Rect2(-3.0, -10.0, 5.0, 2.0), PAL["stone"] as Color)
	draw_rect(Rect2(-4.0, -4.0, 1.0, 4.0), PAL["stone"] as Color)
	draw_rect(Rect2(3.0, -4.0, 1.0, 4.0), trip[0])
	# Recessed face + glowing eyes
	draw_rect(Rect2(-2.0, -7.0, 4.0, 3.0), PAL["night"] as Color)
	var eye_c: Color = (PAL["coral"] as Color) if _blocked_t > 0.0 else (PAL["cream"] as Color if _move_t > 0.0 else c_glow)
	draw_rect(Rect2(-2.0, -6.0, 1.0, 1.0), eye_c)
	draw_rect(Rect2(1.0, -6.0, 1.0, 1.0), eye_c)
	# Mirror axis rune on pedestal (vertical = X mirror, horizontal = Y mirror, cross = both)
	if mirror_mode == "x" or mirror_mode == "both":
		draw_rect(Rect2(0.0, 1.0, 1.0, 4.0), c_glow)
	if mirror_mode == "y" or mirror_mode == "both":
		draw_rect(Rect2(-2.0, 2.0, 5.0, 1.0), c_glow)
