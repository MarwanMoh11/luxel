class_name LxPhysCarryOrb
extends LxToy
## Liftable, droppable, throwable orb with 4 kinds:
## - light: emits a real light pool and calls on_light() on nearby interactables
## - stone: heavy weight orb for plates/scales
## - seed: living seed orb for Thornwood growth sockets
## - key: luminous key orb for sockets / linked doors.

const ORB_RADIUS: float = 6.0

var orb_kind: String = "light"
var origin_pos: Vector2 = Vector2.ZERO
var carrier: LxWick = null
var vel: Vector2 = Vector2.ZERO
var airborne: bool = false
var _air_t: float = 0.0


func _toy_setup() -> void:
	kind = "carry_orb"
	orb_kind = str(props.get("kind", props.get("orb_kind", "light"))).strip_edges().to_lower()
	if orb_kind not in ["light", "stone", "seed", "key"]:
		orb_kind = "light"
	radius = 10.0
	origin_pos = pos
	carrier = null
	vel = Vector2.ZERO
	airborne = false
	_air_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	if carrier != null and is_instance_valid(carrier):
		carrier.drop_carried()
	carrier = null
	vel = Vector2.ZERO
	airborne = false
	_air_t = 0.0
	z_index = 0
	pos = origin_pos
	position = origin_pos.round()
	queue_redraw()


func interact(actor: Node = null) -> bool:
	if not active or carrier != null or not (actor is LxWick):
		return false
	return (actor as LxWick).carry(self)


func on_carried(w: LxWick) -> void:
	carrier = w
	vel = Vector2.ZERO
	airborne = false
	z_index = 3
	queue_redraw()


func set_carry_pos(p: Vector2) -> void:
	pos = p
	position = p.round()
	queue_redraw()


func on_dropped(drop_pos: Vector2) -> void:
	carrier = null
	vel = Vector2.ZERO
	airborne = false
	z_index = 0
	pos = _safe_land_pos(drop_pos)
	position = pos.round()
	queue_redraw()


func on_thrown(from_pos: Vector2, dir: Vector2, speed: float) -> void:
	carrier = null
	pos = from_pos
	position = pos.round()
	vel = dir.normalized() * maxf(60.0, speed)
	airborne = true
	_air_t = 0.42
	z_index = 2
	queue_redraw()


func push_orb(delta: Vector2) -> void:
	if carrier != null or airborne or not delta.is_finite():
		return
	var nxt: Vector2 = pos + delta
	if region != null and region.has_method("collide"):
		nxt = region.call("collide", nxt, ORB_RADIUS, false, false, id) as Vector2
	pos = nxt
	position = pos.round()
	queue_redraw()


func _safe_land_pos(p: Vector2) -> Vector2:
	if region == null:
		return p
	var c: Vector2 = region.call("collide", p, ORB_RADIUS, false, false, id) as Vector2 if region.has_method("collide") else p
	if region.has_method("is_lethal_void_at") and bool(region.call("is_lethal_void_at", c)):
		_emit_sfx("phantom_phase")
		return origin_pos
	return c


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if airborne:
		_air_t -= dt
		if LxFields.has_fields():
			var fa: Vector2 = LxFields.accel_at(pos, "block")
			if fa.length_squared() > 0.01:
				vel += fa * dt
		var nxt: Vector2 = pos + vel * dt
		var hit_wall: bool = _flight_blocked(pos, nxt)
		if hit_wall or _air_t <= 0.0:
			airborne = false
			vel = Vector2.ZERO
			z_index = 0
			pos = _safe_land_pos(pos if hit_wall else nxt)
			position = pos.round()
			_emit_sfx("lantern_land")
		else:
			pos = nxt
			position = pos.round()
		queue_redraw()
	elif carrier == null and LxFields.has_fields():
		var fa2: Vector2 = LxFields.accel_at(pos, "block")
		if fa2.length_squared() > 4.0:
			push_orb(fa2 * dt * 0.12)

	# Light orb radiates real illumination to nearby on_light interactables!
	if orb_kind == "light" and region != null and region.has_method("apply_light"):
		region.call("apply_light", pos, 44.0, "carry_orb")
	if (orb_kind == "light" or orb_kind == "key") and not LxHudFx.flash_reduced():
		queue_redraw()


func _flight_blocked(from_p: Vector2, to_p: Vector2) -> bool:
	if region == null or not is_instance_valid(region):
		return false
	if region.has_method("tile_at") and LxMapFormat.blocks_sight_tile(str(region.call("tile_at", to_p))):
		return true
	if region.has_method("clear_view") and not bool(region.call("clear_view", from_p, to_p)):
		return true
	if region.has_method("get_interactables"):
		var mid: Vector2 = from_p.lerp(to_p, 0.5)
		for it_v: Variant in (region.call("get_interactables") as Array):
			if not is_instance_valid(it_v) or it_v == self or not (it_v is Object):
				continue
			var it: Object = it_v as Object
			if it.get("active") is bool and not bool(it.get("active")):
				continue
			var blocked: bool = false
			var brect: Rect2 = Rect2()
			if it is LxPhysOneWayGate:
				blocked = (it as LxPhysOneWayGate).blocks_lantern(from_p, to_p)
				brect = (it as LxPhysOneWayGate).get_lantern_block_rect()
			elif it.has_method("blocks_lantern") and bool(it.call("blocks_lantern")):
				blocked = true
				brect = (it.call("get_lantern_block_rect") as Rect2) if it.has_method("get_lantern_block_rect") else (
					(it.call("get_solid_rect") as Rect2) if it.has_method("get_solid_rect") else Rect2()
				)
			elif it.has_method("is_solid") and bool(it.call("is_solid")) and it.has_method("get_solid_rect"):
				var ik: String = str(it.get("kind"))
				if ik in ["door", "gate", "one_way_gate", "grate", "toggle_block", "mover_wall"]:
					blocked = true
					brect = it.call("get_solid_rect") as Rect2
			if blocked and brect.has_area():
				var grown: Rect2 = brect.grow(1.5)
				if grown.has_point(to_p) or grown.has_point(mid):
					return true
	return false


func get_interact_prompt() -> String:
	return "PROMPT_CARRY_ORB" if (active and carrier == null and not airborne) else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if orb_kind == "light":
		return Vector4(pos.x, pos.y, 52.0, 0.88)
	if orb_kind == "key":
		return Vector4(pos.x, pos.y, 28.0, 0.50)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["pos"] = [pos.x, pos.y]
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("pos"):
		pos = _parse_vec2(d.get("pos"), origin_pos)
		position = pos.round()
	queue_redraw()


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var hovers: bool = (orb_kind == "light" or orb_kind == "key") and carrier == null and not airborne
	var bob: float = 0.0 if (red or not hovers) else roundf(sin(_clock * 3.2) * 1.0)
	var lift: float = (-4.0 if airborne else (-1.0 if hovers else 0.0)) + bob
	var c_out: Color = PAL["void"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_mid: Color = c_gold
	var c_hi: Color = c_cream
	var c_sh: Color = c_apricot
	var band_sh: Color = c_wine
	var band_hi: Color = c_gold
	match orb_kind:
		"stone":
			c_mid = PAL["stone"] as Color
			c_hi = c_cream
			c_sh = PAL["dusk"] as Color
			band_sh = PAL["night"] as Color
			band_hi = c_apricot
		"seed":
			c_mid = PAL["jade"] as Color
			c_hi = PAL["lime"] as Color
			c_sh = PAL["pine"] as Color
			band_sh = PAL["pine"] as Color
			band_hi = c_gold
		"key":
			c_mid = PAL["sky"] as Color
			c_hi = PAL["ice"] as Color
			c_sh = PAL["deep"] as Color
			band_sh = c_wine
			band_hi = c_gold

	# Grounded elliptical shadow (shrinks slightly when lifted/airborne)
	if carrier == null:
		var srx: float = 5.0 if airborne else 6.8
		var sry: float = 2.2 if airborne else 3.0
		_draw_ground_shadow(srx, sry, Vector2(1.0, 5.0))

	var c := Vector2(0.0, roundf(lift))
	# Soft hover/active radiance aura
	if orb_kind == "light" or orb_kind == "key" or carrier != null:
		var aura_c: Color = c_gold if orb_kind == "light" else (PAL["ice"] as Color if orb_kind == "key" else c_hi)
		draw_circle(c, 9.0, Color(aura_c, 0.16 if red else 0.22))

	# Shaded pixel-crisp sphere
	draw_circle(c, 6.8, c_out)
	draw_circle(c, 5.8, c_sh)
	draw_circle(c + Vector2(-0.5, -0.5), 4.8, c_mid)
	draw_circle(c + Vector2(-1.0, -1.5), 3.0, c_hi if orb_kind == "light" else c_mid)

	# Equatorial brass filigree band with clasp medallion
	draw_rect(Rect2(c.x - 6.0, c.y, 12.0, 2.0), c_out)
	draw_rect(Rect2(c.x - 5.0, c.y, 10.0, 1.0), band_sh)
	draw_rect(Rect2(c.x - 4.0, c.y, 8.0, 1.0), band_hi)
	draw_rect(Rect2(c.x - 2.0, c.y - 1.0, 4.0, 3.0), c_out)
	draw_rect(Rect2(c.x - 1.0, c.y, 2.0, 1.0), c_cream if orb_kind == "light" else c_gold)

	# Crisp top-left specular crescent
	draw_rect(Rect2(c + Vector2(-3.0, -4.0), Vector2(3.0, 1.0)), c_hi)
	draw_rect(Rect2(c + Vector2(-4.0, -3.0), Vector2(2.0, 1.0)), c_hi)
	draw_rect(Rect2(c + Vector2(-4.0, -2.0), Vector2(1.0, 1.0)), c_hi)
	draw_rect(Rect2(c + Vector2(-3.0, -3.0), Vector2(1.0, 1.0)), c_cream)

	# Kind-specific crown crest & gentle hover shimmer pips
	if orb_kind == "key":
		draw_rect(Rect2(c + Vector2(-1.0, 1.0), Vector2(2.0, 3.0)), c_gold)
		draw_rect(Rect2(c + Vector2(-1.0, 1.0), Vector2(1.0, 1.0)), c_cream)
	elif orb_kind == "seed":
		draw_rect(Rect2(c + Vector2(-1.0, -8.0), Vector2(3.0, 3.0)), c_out)
		draw_rect(Rect2(c + Vector2(0.0, -7.0), Vector2(2.0, 1.0)), PAL["lime"] as Color)
		draw_rect(Rect2(c + Vector2(-2.0, -7.0), Vector2(2.0, 1.0)), PAL["jade"] as Color)
	elif orb_kind == "light" or carrier != null:
		var ang_base: float = 0.78 if red else (_clock * 1.8)
		for si: int in range(3):
			var a: float = ang_base + float(si) * (TAU / 3.0)
			var sp: Vector2 = (c + Vector2(cos(a) * 8.2, sin(a) * 6.2)).round()
			draw_rect(Rect2(sp, Vector2.ONE), c_cream if si == 0 else c_gold)
