class_name LxPhysMoverWall
extends LxToy
## Solid sliding masonry/iron wall along `path` at `speed`, controlled by `on_signal` (or auto pingpong).
## Pushes Wick cleanly ahead of its face and safely ejects if crushed — never traps Wick!

var path: Array[Vector2] = []
var speed: float = 48.0
var sig_mode: String = "move" # "move" (powered -> end, unpowered -> start), "toggle", "auto"
var _path_t: float = 0.0
var _dir_sign: int = 1
var _target_end: bool = false


func _toy_setup() -> void:
	kind = "mover_wall"
	size = _parse_size(props.get("size", [24.0, 24.0]), Vector2(24.0, 24.0))
	radius = maxf(size.x, size.y) * 0.5
	path = LxPhysDraw.parse_path(props.get("path", []), pos)
	speed = maxf(10.0, float(props.get("speed", 48.0)))
	sig_mode = str(props.get("on_signal", "move")).strip_edges().to_lower()
	_path_t = 0.0
	_dir_sign = 1
	_target_end = powered
	if not path.is_empty():
		pos = path[0]
		position = pos.round()
	queue_redraw()


func _on_power_changed(is_on: bool) -> void:
	if sig_mode == "toggle":
		if is_on:
			_target_end = not _target_end
	else:
		_target_end = is_on
	_emit_sfx("golem_stomp")
	queue_redraw()


func is_solid() -> bool:
	return active


func blocks_sight() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if active else Rect2()


func _total_len() -> float:
	var total: float = 0.0
	for i: int in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total


func _pos_at_dist(d_px: float) -> Vector2:
	if path.size() < 2:
		return pos
	var rem: float = clampf(d_px, 0.0, _total_len())
	for i: int in range(path.size() - 1):
		var slen: float = path[i].distance_to(path[i + 1])
		if rem <= slen or i == path.size() - 2:
			return path[i].lerp(path[i + 1], clampf(rem / maxf(0.01, slen), 0.0, 1.0))
		rem -= slen
	return path[path.size() - 1]


func tick(dt: float) -> void:
	super.tick(dt)
	if not active or path.size() < 2:
		return
	var total: float = _total_len()
	if total <= 0.5:
		return
	var old_pos: Vector2 = pos
	var cur_d: float = _path_t * total
	if sig_mode == "auto":
		cur_d += float(_dir_sign) * speed * dt
		if cur_d >= total:
			cur_d = total
			_dir_sign = -1
		elif cur_d <= 0.0:
			cur_d = 0.0
			_dir_sign = 1
	else:
		var goal_d: float = total if _target_end else 0.0
		cur_d = move_toward(cur_d, goal_d, speed * dt)
	_path_t = clampf(cur_d / total, 0.0, 1.0)
	pos = _pos_at_dist(cur_d)
	position = pos.round()
	var delta: Vector2 = pos - old_pos
	if delta.length_squared() > 0.00001:
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			LxPhysDraw.safe_eject_wick(Lx.player as Node2D, get_solid_rect(), region, id, delta)
		queue_redraw()


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["path_t"] = _path_t
		d["target_end"] = _target_end
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("path_t"):
		_path_t = clampf(float(d.get("path_t", 0.0)), 0.0, 1.0)
		_target_end = bool(d.get("target_end", false))
		pos = _pos_at_dist(_path_t * _total_len())
		position = pos.round()
	queue_redraw()


func _draw() -> void:
	LxPhysDraw.draw_track_line(self, pos, path, PAL["night"] as Color, PAL["dusk"] as Color, biome("mid"))
	var r := Rect2((-size * 0.5).round(), size.round())
	LxPhysDraw.draw_shadow_rect(self, r, Vector2(2.0, 3.0), 0.48)
	LxPhysDraw.draw_bevel_box(self, r, PAL["dusk"] as Color, PAL["mauve"] as Color, PAL["night"] as Color, PAL["void"] as Color, biome("hi"))
	# Recessed iron masonry bands + signal jewel
	draw_rect(Rect2(r.position.x + 3.0, r.position.y + 4.0, r.size.x - 6.0, 2.0), PAL["night"] as Color)
	draw_rect(Rect2(r.position.x + 3.0, r.end.y - 6.0, r.size.x - 6.0, 2.0), PAL["night"] as Color)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), biome("glow") if _target_end else PAL["plum"] as Color)
