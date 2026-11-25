class_name LxPhysPushBlock
extends LxToy
## Pushable physics block with 4 variants:
## - stone: classic grid-snapped Zelda grab/push-pull
## - ice: shoving, shooting, or wind sends it sliding until blocked
## - crate: light wooden crate that slides with tilt_group, conveyors, and wind
## - slag: starts molten (hot coral, damages on contact) until cooled by blue light or signal into pushable stone.

const ICE_SLIDE_SPEED: float = 165.0
const CRATE_MAX_SPEED: float = 110.0

var variant: String = "stone"
var origin_pos: Vector2 = Vector2.ZERO
var cooled: bool = true
var slide_vel: Vector2 = Vector2.ZERO
var _ext_vel: Vector2 = Vector2.ZERO
var _flash_t: float = 0.0
var _hurt_cd: float = 0.0


func _toy_setup() -> void:
	kind = "push_block"
	variant = str(props.get("variant", "stone")).strip_edges().to_lower()
	if variant not in ["stone", "ice", "crate", "slag"]:
		variant = "stone"
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	origin_pos = pos
	cooled = (variant != "slag") or bool(props.get("cooled", false))
	slide_vel = Vector2.ZERO
	_ext_vel = Vector2.ZERO
	_flash_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	slide_vel = Vector2.ZERO
	_ext_vel = Vector2.ZERO
	_flash_t = 0.0
	cooled = (variant != "slag") or bool(props.get("cooled", false))
	move_to(origin_pos)


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if active else Rect2()


func is_movable() -> bool:
	if not active:
		return false
	if variant == "slag" and not cooled:
		return false
	return slide_vel.length_squared() < 4.0


func get_push_rect_at(target_pos: Vector2) -> Rect2:
	var inset := Vector2(maxf(8.0, size.x - 2.0), maxf(8.0, size.y - 2.0))
	return Rect2(target_pos - inset * 0.5, inset)


func move_to(new_pos: Vector2) -> void:
	pos = new_pos
	position = new_pos.round()
	queue_redraw()


func start_ice_slide(dir: Vector2) -> bool:
	if variant != "ice" or not active or dir.length_squared() <= 0.01:
		return false
	var axis: Vector2 = Vector2(signf(dir.x), 0.0) if absf(dir.x) >= absf(dir.y) else Vector2(0.0, signf(dir.y))
	slide_vel = axis * ICE_SLIDE_SPEED
	_emit_sfx("footstep_crystal")
	return true


func push_block_external(v: Vector2) -> void:
	if not active or not v.is_finite():
		return
	if variant == "slag" and not cooled:
		return
	_ext_vel += v


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if variant == "slag" and not cooled:
		if hit.is_blue() or hit.source == LxHit.SOURCE_BEAM:
			_cool_slag()
			return true
		_flash_t = 0.16
		_emit_sfx("shield_clang")
		queue_redraw()
		return true
	if variant == "ice" and hit.dir.length_squared() > 0.01:
		start_ice_slide(hit.dir)
		_flash_t = 0.14
		queue_redraw()
		return true
	if variant == "crate" and hit.is_heavy() and hit.dir.length_squared() > 0.01:
		slide_vel = hit.dir.normalized() * 88.0
		_flash_t = 0.12
		_emit_sfx("footstep_wood")
		queue_redraw()
		return true
	return false


func _on_power_changed(is_on: bool) -> void:
	if variant == "slag" and is_on and not cooled:
		_cool_slag()


func _cool_slag() -> void:
	cooled = true
	_flash_t = 0.30
	_emit_sfx("slag_cool")
	if Lx.player is LxWick:
		(Lx.player as LxWick).spawn_ring(pos, 3.0, 14.0, 0.22, PAL["ice"] as Color, 1.2)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		dirty = true
	if _hurt_cd > 0.0:
		_hurt_cd = maxf(0.0, _hurt_cd - dt)

	# Molten slag hurts on close contact & pulses ember warmth
	if variant == "slag" and not cooled and active:
		if _hurt_cd <= 0.0 and Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if not w.dead and get_solid_rect().grow(3.5).has_point(w.global_position):
				_hurt_cd = 0.6
				w.take_damage(1.0, pos, (w.global_position - pos).normalized(), "slag")
		dirty = true

	# Sample spatial fields for ice and crate
	if active and (variant == "ice" or variant == "crate") and LxFields.has_fields():
		var fa: Vector2 = LxFields.accel_at(pos, "block")
		if fa.length_squared() > 4.0:
			slide_vel = (slide_vel + fa * dt).limit_length(ICE_SLIDE_SPEED if variant == "ice" else CRATE_MAX_SPEED)

	var total_v: Vector2 = slide_vel + _ext_vel
	_ext_vel = Vector2.ZERO
	if total_v.length_squared() > 1.0:
		var step: Vector2 = total_v * dt
		var nxt: Vector2 = pos + step
		var ok: bool = true
		if region != null and region.has_method("can_place_rect"):
			ok = bool(region.call("can_place_rect", get_push_rect_at(nxt), id))
		if ok:
			move_to(nxt)
			if Lx.player is LxWick and is_instance_valid(Lx.player):
				LxPhysDraw.safe_eject_wick(Lx.player as Node2D, get_solid_rect(), region, id, total_v)
		else:
			if variant == "ice" and slide_vel.length() > 24.0:
				_emit_sfx("bolt_wall")
			slide_vel = Vector2.ZERO
		if variant != "ice":
			slide_vel = slide_vel.move_toward(Vector2.ZERO, 240.0 * dt)
		dirty = true

	if dirty:
		queue_redraw()


func get_interact_prompt() -> String:
	return "PROMPT_PUSH_BLOCK" if is_movable() else ""


func get_light_pool() -> Vector4:
	if variant == "slag" and not cooled and active:
		return Vector4(pos.x, pos.y, 34.0, 0.65)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["pos"] = [pos.x, pos.y]
		d["cooled"] = cooled
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist:
		if d.has("pos"):
			move_to(_parse_vec2(d.get("pos"), origin_pos))
		if d.has("cooled"):
			cooled = bool(d.get("cooled", cooled))
	queue_redraw()


func _draw() -> void:
	var r := Rect2((-size * 0.5).round(), size.round())
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_cream: Color = PAL["cream"] as Color
	LxPhysDraw.draw_shadow_rect(self, r, Vector2(1.0, 3.0), 0.44)
	var base_c: Color = PAL["mauve"] as Color
	var hi_c: Color = PAL["stone"] as Color
	var sh_c: Color = PAL["dusk"] as Color
	var front_c: Color = c_night
	var riv_c: Color = biome("hi")
	match variant:
		"ice":
			base_c = PAL["sky"] as Color
			hi_c = c_cream
			sh_c = PAL["blue"] as Color
			front_c = PAL["deep"] as Color
			riv_c = PAL["ice"] as Color
		"crate":
			base_c = PAL["apricot"] as Color
			hi_c = PAL["gold"] as Color
			sh_c = PAL["wine"] as Color
			front_c = PAL["wine"] as Color
			riv_c = c_cream
		"slag":
			if not cooled:
				var hot: bool = LxHudFx.flash_reduced() or fmod(_clock * 4.0, 1.0) < 0.5
				base_c = PAL["coral"] as Color
				hi_c = PAL["gold"] as Color if hot else PAL["apricot"] as Color
				sh_c = PAL["wine"] as Color
				front_c = PAL["plum"] as Color
				riv_c = c_cream
			else:
				base_c = PAL["dusk"] as Color
				hi_c = PAL["mauve"] as Color
				sh_c = c_night
				front_c = c_void
				riv_c = PAL["stone"] as Color
	if _flash_t > 0.0:
		hi_c = c_cream

	# 2.5D top-down block: raised top plateau + shaded front face so it reads as a heavy pushable object
	var face_h: float = minf(5.0, maxf(3.0, floorf(r.size.y * 0.30)))
	var top_r := Rect2(r.position.x, r.position.y - 2.0, r.size.x, r.size.y - face_h + 2.0)
	var front_r := Rect2(r.position.x, top_r.end.y - 1.0, r.size.x, face_h + 1.0)
	LxPhysDraw.draw_bevel_box(self, front_r, front_c, sh_c, c_void, c_void)
	LxPhysDraw.draw_bevel_box(self, top_r, base_c, hi_c, sh_c, c_void, riv_c)
	# Recessed push-grip notches on left & right flanks
	var mid_y: float = roundf(top_r.get_center().y)
	draw_rect(Rect2(top_r.position.x + 1.0, mid_y - 2.0, 1.0, 4.0), c_void)
	draw_rect(Rect2(top_r.end.x - 2.0, mid_y - 2.0, 1.0, 4.0), c_void)

	# Crisp carved top emblem per variant
	var cx: float = floorf(top_r.get_center().x)
	var cy: float = floorf(top_r.get_center().y)
	match variant:
		"stone":
			draw_rect(Rect2(cx - 3.0, cy - 2.0, 6.0, 5.0), c_void)
			draw_rect(Rect2(cx - 2.0, cy - 1.0, 4.0, 3.0), sh_c)
			draw_rect(Rect2(cx - 1.0, cy, 2.0, 1.0), biome("glow"))
			draw_rect(Rect2(cx - 2.0, front_r.position.y + 2.0, 4.0, 1.0), sh_c)
		"ice":
			draw_line(top_r.position + Vector2(3.0, 2.0), top_r.end - Vector2(4.0, 3.0), PAL["ice"] as Color, 1.0)
			draw_rect(Rect2(top_r.position + Vector2(3.0, 2.0), Vector2(3.0, 1.0)), c_cream)
			draw_rect(Rect2(top_r.end - Vector2(5.0, 3.0), Vector2(2.0, 1.0)), c_cream)
		"crate":
			draw_line(top_r.position + Vector2(2.0, 2.0), top_r.end - Vector2(3.0, 2.0), sh_c, 1.0)
			draw_line(Vector2(top_r.end.x - 3.0, top_r.position.y + 2.0), Vector2(top_r.position.x + 2.0, top_r.end.y - 2.0), sh_c, 1.0)
		"slag":
			var crack_c: Color = PAL["gold"] as Color if not cooled else c_night
			draw_line(Vector2(cx - 4.0, cy - 1.0), Vector2(cx, cy + 1.0), crack_c, 1.0)
			draw_line(Vector2(cx, cy + 1.0), Vector2(cx + 4.0, cy - 2.0), crack_c, 1.0)
			if not cooled:
				draw_rect(Rect2(cx - 1.0, cy, 2.0, 1.0), c_cream)
