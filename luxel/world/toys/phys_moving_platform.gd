class_name LxPhysMovingPlatform
extends LxToy
## Moving mechanical platform over pit/water/void.
## Counts as platform support (is_platform_solid) and carries Wick, hung lantern,
## push_blocks, and carry_orbs smoothly along its path.

var path: Array[Vector2] = []
var speed: float = 42.0
var is_loop: bool = false
var needs_power: bool = false
var _seg_idx: int = 0
var _seg_t: float = 0.0
var _dir_sign: int = 1
var _last_delta: Vector2 = Vector2.ZERO


func _toy_setup() -> void:
	kind = "moving_platform"
	size = _parse_size(props.get("size", [32.0, 24.0]), Vector2(32.0, 24.0))
	radius = maxf(size.x, size.y) * 0.5
	path = LxPhysDraw.parse_path(props.get("path", []), pos)
	speed = maxf(8.0, float(props.get("speed", 42.0)))
	var mode_s: String = str(props.get("mode", "")).strip_edges().to_lower()
	is_loop = bool(props.get("loop", mode_s == "loop"))
	if bool(props.get("pingpong", mode_s == "pingpong")):
		is_loop = false
	needs_power = bool(props.get("needs_power", false))
	_seg_idx = 0
	_seg_t = 0.0
	_dir_sign = 1
	_last_delta = Vector2.ZERO
	if not path.is_empty():
		pos = path[0]
		position = pos.round()
	z_index = LxPhysDraw.floor_z(region, -4)
	queue_redraw()


func is_platform_solid() -> bool:
	return active


func get_platform_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if active else Rect2()


func _is_moving_active() -> bool:
	if not active or path.size() < 2:
		return false
	return powered if needs_power else true


func tick(dt: float) -> void:
	super.tick(dt)
	_last_delta = Vector2.ZERO
	if not _is_moving_active():
		return
	var old_pos: Vector2 = pos
	var old_rect := Rect2(old_pos - size * 0.5, size)
	var step_px: float = speed * dt
	var guard: int = 0
	while step_px > 0.0001 and guard < 8:
		guard += 1
		var next_idx: int = (_seg_idx + _dir_sign)
		if is_loop:
			next_idx = posmod(next_idx, path.size())
		else:
			if next_idx < 0 or next_idx >= path.size():
				_dir_sign = -_dir_sign
				next_idx = clampi(_seg_idx + _dir_sign, 0, path.size() - 1)
		var a: Vector2 = path[_seg_idx]
		var b: Vector2 = path[next_idx]
		var seg_len: float = a.distance_to(b)
		if seg_len <= 0.01:
			_seg_idx = next_idx
			_seg_t = 0.0
			continue
		var rem_px: float = (1.0 - _seg_t) * seg_len
		if step_px < rem_px:
			_seg_t += step_px / seg_len
			pos = a.lerp(b, _seg_t)
			step_px = 0.0
		else:
			step_px -= rem_px
			_seg_idx = next_idx
			_seg_t = 0.0
			pos = b
	position = pos.round()
	_last_delta = pos - old_pos
	if _last_delta.length_squared() > 0.00001:
		_carry_riders(old_rect, _last_delta)
	queue_redraw()


func _carry_riders(old_rect: Rect2, delta: Vector2) -> void:
	# 1. Carry Wick
	if is_instance_valid(Lx.player) and Lx.player is LxWick:
		var w: LxWick = Lx.player as LxWick
		if not w.dead and not w.is_dashing() and not w.is_gliding() and not w.is_zipping() and not w.is_launched() and not w.is_mounted():
			if old_rect.grow(1.5).has_point(w.global_position):
				var target_w: Vector2 = w.global_position + delta
				if region != null and region.has_method("collide"):
					target_w = region.call("collide", target_w, LxWick.BODY_RADIUS, true, true) as Vector2
				w.global_position = target_w
				w.last_pos = target_w
		# 2. Carry hanging lantern
		if w.lantern != null and w.lantern.is_hanging() and old_rect.grow(2.0).has_point(w.lantern.pos):
			w.lantern.pos += delta
			w.lantern.prev_pos = w.lantern.pos
			w.lantern.global_position = w.lantern.pos.round()

	# 3. Carry push_blocks and carry_orbs resting on deck
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in region.call("get_interactables") as Array:
			if it_v == self or not is_instance_valid(it_v) or not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not it.active:
				continue
			if it.kind in ["push_block", "carry_orb", "mirror", "blue_transformer"]:
				if old_rect.has_point(it.pos):
					if it.has_method("move_to"):
						it.call("move_to", it.pos + delta)
					else:
						it.pos += delta
						it.position = it.pos.round()


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["seg_idx"] = _seg_idx
		d["seg_t"] = _seg_t
		d["dir_sign"] = _dir_sign
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("seg_idx"):
		_seg_idx = clampi(int(d.get("seg_idx", 0)), 0, maxi(0, path.size() - 1))
		_seg_t = clampf(float(d.get("seg_t", 0.0)), 0.0, 1.0)
		_dir_sign = -1 if int(d.get("dir_sign", 1)) < 0 else 1
		if path.size() >= 2:
			var next_idx: int = _seg_idx + _dir_sign
			if is_loop:
				next_idx = posmod(next_idx, path.size())
			else:
				next_idx = clampi(next_idx, 0, path.size() - 1)
			pos = path[_seg_idx].lerp(path[next_idx], _seg_t)
			position = pos.round()
		elif path.size() == 1:
			pos = path[0]
			position = pos.round()
	queue_redraw()


func _draw() -> void:
	LxPhysDraw.draw_track_line(self, pos, path, PAL["dusk"] as Color, PAL["night"] as Color, biome("hi") if _is_moving_active() else PAL["mauve"] as Color, is_loop)
	var r := Rect2((-size * 0.5).round(), size.round())
	LxPhysDraw.draw_shadow_rect(self, r, Vector2(0.0, 3.0), 0.42)
	var lit: bool = _is_moving_active()
	LxPhysDraw.draw_bevel_box(self, r, PAL["dusk"] as Color, biome("hi") if lit else PAL["stone"] as Color, PAL["night"] as Color, PAL["void"] as Color, biome("glow") if lit else PAL["mauve"] as Color)
	# Deck planks + glowing center core
	var inner := Rect2(r.position + Vector2(3.0, 3.0), r.size - Vector2(6.0, 6.0))
	draw_rect(inner, PAL["night"] as Color)
	var px: float = inner.position.x + 4.0
	while px < inner.end.x - 1.0:
		draw_line(Vector2(px, inner.position.y), Vector2(px, inner.end.y - 1.0), PAL["dusk"] as Color, 1.0)
		px += 6.0
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), biome("glow") if lit else PAL["plum"] as Color)
	if lit:
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["cream"] as Color)
