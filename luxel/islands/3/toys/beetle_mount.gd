class_name LxBeetleMount
extends LxToy
## Island 3 Sap-Horn Beetle toy (tame rideable mount OR wild lantern-lured beetle).
## - Tame (`tame: true`): mount with E (`wick.mount(self)`), ride safely across sap/water (`~`, `tide`),
##   nudge movable `dew_lens`es, press Dash while mounted to blow Sap-Horn (charge burst + halt nearby wild beetles!),
##   and its polished carapace reflects Prism shots into Blue light (`is_reflective() -> true`).
## - Wild (`tame: false`): walks toward Wick's thrown/hanging lantern lure within `lure_radius`, depresses
##   `pressure_plate`s & `scale`s (`is_weight_body() -> true`), and toggles `halted` (frozen on plates!) when
##   called by Sap-Horn (`on_sap_horn()` or `E` interact).
## Props: tame (bool, true), speed (float, 86.0), charge_speed (float, 165.0), lure_radius (float, 148.0),
## dir ("n"|"e"|"s"|"w"|[x,y]), halted (bool, false), require_sap_horn (bool, false), persist (bool).

const BODY_RADIUS: float = 8.0
const CHARGE_SECS: float = 0.42

var tame: bool = true
var move_speed: float = 86.0
var charge_speed: float = 165.0
var lure_radius: float = 148.0
var facing_dir: Vector2 = Vector2.RIGHT
var halted: bool = false
var require_sap_horn: bool = false

var origin_pos: Vector2 = Vector2.ZERO
var rider: LxWick = null
var _charge_t: float = 0.0
var _horn_ring_t: float = 0.0
var _reflect_flash_t: float = 0.0
var _leg_phase: float = 0.0
var _board_grace: float = 0.0


func _toy_setup() -> void:
	kind = "beetle_mount"
	size = Vector2(20.0, 16.0)
	radius = 12.0
	tame = bool(props.get("tame", true))
	move_speed = maxf(30.0, float(props.get("speed", 86.0 if tame else 56.0)))
	charge_speed = maxf(90.0, float(props.get("charge_speed", 165.0)))
	lure_radius = maxf(48.0, float(props.get("lure_radius", 148.0)))
	facing_dir = dir_vec("dir", Vector2.RIGHT)
	if facing_dir.length_squared() <= 0.001:
		facing_dir = Vector2.RIGHT
	halted = bool(props.get("halted", false))
	require_sap_horn = bool(props.get("require_sap_horn", false))
	origin_pos = pos
	rider = null
	_charge_t = 0.0
	_horn_ring_t = 0.0
	_reflect_flash_t = 0.0
	_leg_phase = 0.0
	_board_grace = 0.0
	queue_redraw()


func reset_toy() -> void:
	if rider != null and is_instance_valid(rider):
		rider.dismount(origin_pos)
	rider = null
	pos = origin_pos
	position = pos.round()
	halted = bool(props.get("halted", false))
	_charge_t = 0.0
	_horn_ring_t = 0.0
	queue_redraw()


func is_weight_body() -> bool:
	return active


func is_reflective() -> bool:
	# Mirrored carapace reflects yellow bolts into Blue Prism shots!
	return active and rider == null


func get_transform_color() -> String:
	return LxHit.COLOR_BLUE


func reflect_dir(in_dir: Vector2) -> Vector2:
	if in_dir.length_squared() <= 0.0001:
		return Vector2.ZERO
	var d: Vector2 = in_dir.normalized()
	var n: Vector2 = facing_dir.normalized()
	if d.dot(n) > 0.0:
		n = -n
	return d.bounce(n).normalized()


func is_platform_solid() -> bool:
	return active and tame


func get_platform_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_platform_solid() else Rect2()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxDewLens.SOURCE_DEW_RAY]:
		_reflect_flash_t = 0.22
		_emit_sfx("mirror_ping")
		queue_redraw()
		return true
	return false


func on_sap_horn(_origin: Vector2 = Vector2.ZERO) -> void:
	if not active:
		return
	_horn_ring_t = 0.45
	if not tame:
		halted = not halted
		set_powered(halted)
		emit_power(halted)
	elif rider != null:
		_charge_t = CHARGE_SECS
	else:
		halted = not halted
	queue_redraw()


func _can_use_horn() -> bool:
	return (not require_sap_horn) or LxRegionLoader.check_flag_static("sap_horn")


func interact(actor: Node = null) -> bool:
	if not active or _board_grace > 0.0 or not (actor is LxWick):
		return false
	var w: LxWick = actor as LxWick
	if not tame:
		if not _can_use_horn():
			_emit_sfx("denied")
			return false
		LxIsland3Rule.call_sap_horn(w.global_position, 220.0, region)
		return true
	if rider == w:
		return try_dismount(w)
	if w.is_mounted() or w.global_position.distance_to(pos) > 30.0:
		return false
	return w.mount(self)


func on_mounted(w: LxWick) -> void:
	rider = w
	halted = false
	_charge_t = 0.0
	w.global_position = pos
	w.last_pos = pos
	_emit_sfx("sap_horn_call")
	queue_redraw()


func on_dismounted(w: LxWick) -> void:
	if rider == w:
		rider = null
	_charge_t = 0.0
	_board_grace = 0.22
	queue_redraw()


func try_dismount(w: LxWick) -> bool:
	var exit_p: Vector2 = _find_safe_exit()
	if not exit_p.is_finite():
		_emit_sfx("denied")
		return false
	w.dismount(exit_p)
	return true


func _find_safe_exit() -> Vector2:
	if region == null:
		return pos + Vector2(0.0, -16.0)
	var side := Vector2(-facing_dir.y, facing_dir.x)
	var cands: Array[Vector2] = [
		pos + side * 16.0, pos - side * 16.0,
		pos - facing_dir * 16.0, pos + facing_dir * 16.0,
		pos + side * 24.0, pos - side * 24.0,
	]
	for c: Vector2 in cands:
		if LxPhysDraw.is_tile_safe_land(region, c):
			return c
	return Vector2.INF


func on_wick_dash(w: LxWick) -> bool:
	if rider != w or not _can_use_horn():
		return false
	# Blow Sap-Horn while riding: boosts forward across sap AND commands nearby wild beetles!
	_charge_t = CHARGE_SECS
	_horn_ring_t = 0.45
	LxIsland3Rule.call_sap_horn(pos, 220.0, region)
	return true


func tick_mounted(dt: float, w: LxWick, _world_ctx: Node) -> void:
	if rider != w:
		return
	var mv: Vector2 = w.get_move_input()
	var spd: float = charge_speed if _charge_t > 0.0 else move_speed
	var move_v: Vector2 = Vector2.ZERO
	if _charge_t > 0.0:
		_charge_t = maxf(0.0, _charge_t - dt)
		if mv.length_squared() > 0.04:
			facing_dir = facing_dir.lerp(mv.normalized(), minf(1.0, dt * 6.0)).normalized()
		move_v = facing_dir * spd
	elif mv.length_squared() > 0.04:
		facing_dir = mv.normalized()
		move_v = facing_dir * spd
	if move_v.length_squared() > 1.0:
		_step_beetle(move_v * dt)
		_nudge_dew_lenses(facing_dir * (spd * dt * 1.15))
		_leg_phase += dt * 14.0
	w.global_position = pos
	w.last_pos = pos
	w.velocity = move_v
	w.facing = facing_dir


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _board_grace > 0.0:
		_board_grace = maxf(0.0, _board_grace - dt)
	if _horn_ring_t > 0.0:
		_horn_ring_t = maxf(0.0, _horn_ring_t - dt)
		dirty = true
	if _reflect_flash_t > 0.0:
		_reflect_flash_t = maxf(0.0, _reflect_flash_t - dt)
		dirty = true
	if rider != null and not is_instance_valid(rider):
		rider = null
	if not tame and not halted and rider == null:
		if _tick_wild_lure(dt):
			dirty = true
	if dirty or rider != null:
		queue_redraw()


func _tick_wild_lure(dt: float) -> bool:
	if region == null or not region.has_method("is_lantern_out"):
		return false
	if not bool(region.call("is_lantern_out")):
		return false
	var lpos: Vector2 = region.call("get_lantern_pos") as Vector2 if region.has_method("get_lantern_pos") else Vector2(-9999.0, -9999.0)
	var delta: Vector2 = lpos - pos
	var d: float = delta.length()
	if d <= 12.0 or d > lure_radius:
		return false
	facing_dir = delta / d
	_step_beetle(facing_dir * (move_speed * dt))
	_leg_phase += dt * 10.0
	return true


func _step_beetle(delta: Vector2) -> void:
	var nxt: Vector2 = pos + delta
	if region != null and region.has_method("collide"):
		# Beetles cross sap/water (`can_cross_water = true`) but stop at pits & walls!
		nxt = region.call("collide", nxt, BODY_RADIUS, false, true, id) as Vector2
	pos = nxt
	position = pos.round()


func _nudge_dew_lenses(delta: Vector2) -> void:
	if region == null or not region.has_method("get_interactables"):
		return
	for it_v: Variant in (region.call("get_interactables") as Array):
		if it_v is LxDewLens:
			var dl: LxDewLens = it_v as LxDewLens
			if dl.active and dl.is_movable() and dl.pos.distance_to(pos) <= 18.0:
				dl.nudge(delta)


func get_interact_prompt() -> String:
	if not active:
		return ""
	if not tame:
		return "PROMPT_HALT_BEETLE"
	return "PROMPT_LEAVE_BEETLE" if rider != null else "PROMPT_RIDE_BEETLE"


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["pos"] = [pos.x, pos.y]
		d["halted"] = halted
		d["dir"] = [facing_dir.x, facing_dir.y]
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist:
		if d.has("pos"):
			pos = _parse_vec2(d["pos"], origin_pos)
			position = pos.round()
		halted = bool(d.get("halted", halted))
		if d.has("dir"):
			var fd: Vector2 = _parse_vec2(d["dir"], facing_dir)
			if fd.length_squared() > 0.001:
				facing_dir = fd.normalized()
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_teal: Color = PAL["teal"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var f: Vector2 = facing_dir.normalized() if facing_dir.length_squared() > 0.001 else Vector2.RIGHT
	var perp := Vector2(-f.y, f.x)
	var red: bool = LxHudFx.flash_reduced()

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 10.0, 4.0)
	# 6 articulated beetle legs striding gently along facing axis
	var step_o: float = 0.0 if red else (1.0 if int(floorf(_leg_phase)) % 2 == 0 else -1.0)
	for i: int in range(3):
		var along: float = -5.0 + float(i) * 4.5 + (step_o if i % 2 == 0 else -step_o) * 0.6
		var base_l: Vector2 = (f * along + perp * 5.0).round()
		var tip_l: Vector2 = (f * (along + 1.0) + perp * 8.0).round()
		var base_r: Vector2 = (f * along - perp * 5.0).round()
		var tip_r: Vector2 = (f * (along - 1.0) - perp * 8.0).round()
		draw_line(base_l, tip_l, c_void, 2.0)
		draw_line(base_r, tip_r, c_void, 2.0)
		draw_rect(Rect2(tip_l, Vector2.ONE), c_apricot if tame else c_gold)
		draw_rect(Rect2(tip_r, Vector2.ONE), c_apricot if tame else c_gold)

	# Curved serrated stag-horn mandibles projecting ahead of head
	var h_root: Vector2 = (f * 6.0).round()
	var h_mid_l: Vector2 = (f * 10.0 + perp * 4.0).round()
	var h_mid_r: Vector2 = (f * 10.0 - perp * 4.0).round()
	var h_tip_l: Vector2 = (f * 13.0 + perp * 2.0).round()
	var h_tip_r: Vector2 = (f * 13.0 - perp * 2.0).round()
	draw_line(h_root, h_mid_l, c_void, 3.0)
	draw_line(h_mid_l, h_tip_l, c_void, 3.0)
	draw_line(h_root, h_mid_r, c_void, 3.0)
	draw_line(h_mid_r, h_tip_r, c_void, 3.0)
	var horn_c: Color = c_gold if tame else c_apricot
	draw_line(h_root, h_mid_l, horn_c, 1.5)
	draw_line(h_mid_l, h_tip_l, c_cream if _horn_ring_t > 0.0 else horn_c, 1.5)
	draw_line(h_root, h_mid_r, horn_c, 1.5)
	draw_line(h_mid_r, h_tip_r, c_cream if _horn_ring_t > 0.0 else horn_c, 1.5)

	# Rounded domed iridescent carapace (abdomen + pronotum head shield)
	var body_dark: Color = c_pine if tame else c_plum
	var body_mid: Color = c_teal if tame else c_wine
	var body_hi: Color = c_jade if tame else c_apricot
	var body_rim: Color = c_lime if tame else c_gold
	var rear: Vector2 = (-f * 2.0).round()
	var head: Vector2 = (f * 5.0).round()
	draw_circle(rear, 8.0, c_void)
	draw_circle(head, 5.0, c_void)
	draw_circle(rear, 7.0, body_dark)
	draw_circle(head, 4.0, body_dark)
	draw_circle((rear + Vector2(-0.5, -0.5)).round(), 6.0, body_mid)
	draw_circle((head + Vector2(-0.5, -0.5)).round(), 3.0, body_hi)
	# Wing-case elytra dorsal seam + mirrored Prism sheen crest
	var sheen_c: Color = c_cream if _reflect_flash_t > 0.0 else (c_ice if tame else c_gold)
	draw_circle((rear + Vector2(-1.0, -1.5)).round(), 4.0, c_sky if tame else body_hi)
	draw_rect(Rect2((rear + Vector2(-2.0, -3.0)).round(), Vector2(4.0, 2.0)), sheen_c)
	draw_line((rear - f * 5.0).round(), (rear + f * 4.0).round(), c_night, 1.0)
	draw_rect(Rect2((rear - f * 2.0 + Vector2(-1.0, -2.0)).round(), Vector2(2.0, 1.0)), body_rim)
	# Bright beetle eyes on head sides
	draw_rect(Rect2((head + f * 1.5 + perp * 2.5).round(), Vector2(1.0, 1.0)), c_cream)
	draw_rect(Rect2((head + f * 1.5 - perp * 2.5).round(), Vector2(1.0, 1.0)), c_cream)

	# Halted horn-lock emblem (readable in greyscale!)
	if halted:
		LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -10.0), 3, true, c_gold, c_cream)
	elif rider != null:
		draw_rect(Rect2(-2.0, -2.0, 4.0, 3.0), c_jade)
		draw_rect(Rect2(-1.0, -2.0, 2.0, 1.0), c_cream)
	if _horn_ring_t > 0.0:
		var u: float = 1.0 - clampf(_horn_ring_t / 0.45, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 18.0, u)), 0.0, TAU, 16, c_gold if u > 0.4 else c_cream, 1.0)
	_draw_signal_pulses()
