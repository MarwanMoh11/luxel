class_name LxTurretEye
extends LxToy
## Fixed or aiming turret eye with clear TELL -> COMMIT -> RECOVER cycle.
## Its bolts obey LxFields, can be blocked by walls/solids, tinted by LxColorGlass, and reflected by mirrors/blue_transformers.
## Props: dir ("n"|"e"|"s"|"w"|[x,y]), aim (bool), cadence (float), tell_secs (float), recover_secs (float),
## bolt_speed (float), damage (float), color (String), sight_range (float), can_disable (bool).

enum Phase { IDLE, TELL, COMMIT, RECOVER }

var aim_mode: bool = false
var fire_dir: Vector2 = Vector2.RIGHT
var cadence: float = 2.2
var tell_secs: float = 0.55
var recover_secs: float = 0.65
var bolt_speed: float = 135.0
var bolt_damage: float = 1.0
var bolt_color: String = "coral"
var sight_range: float = 168.0
var can_disable: bool = true

var phase: int = Phase.IDLE
var bolts: Array[Dictionary] = [] # [{pos, prev, vel, color, reflected, age, bounces, hit_ids}]
var _timer: float = 0.8
var _stun_t: float = 0.0
var _enabled_by_signal: bool = true


func _toy_setup() -> void:
	kind = "turret_eye"
	aim_mode = bool(props.get("aim", not props.has("dir")))
	fire_dir = dir_vec("dir", Vector2.RIGHT)
	if fire_dir.length_squared() <= 0.001:
		fire_dir = Vector2.RIGHT
	cadence = maxf(0.8, float(props.get("cadence", 2.2)))
	tell_secs = maxf(0.35, float(props.get("tell_secs", 0.55)))
	recover_secs = maxf(0.40, float(props.get("recover_secs", 0.65)))
	bolt_speed = maxf(60.0, float(props.get("bolt_speed", 135.0)))
	bolt_damage = maxf(0.5, float(props.get("damage", 1.0)))
	bolt_color = str(props.get("color", "coral")).strip_edges().to_lower()
	sight_range = maxf(48.0, float(props.get("sight_range", 168.0)))
	can_disable = bool(props.get("can_disable", true))
	radius = maxf(10.0, radius)
	phase = Phase.IDLE
	_timer = cadence * 0.45
	_stun_t = 0.0
	_enabled_by_signal = not bool(props.get("needs_signal", false))
	bolts.clear()
	queue_redraw()


func reset_toy() -> void:
	phase = Phase.IDLE
	_timer = cadence * 0.45
	_stun_t = 0.0
	bolts.clear()
	queue_redraw()


func on_signal(_from_id: String, is_on: bool) -> void:
	if bool(props.get("needs_signal", false)):
		_enabled_by_signal = is_on
	elif bool(props.get("disable_on_signal", false)):
		_enabled_by_signal = not is_on
	if not _enabled_by_signal:
		phase = Phase.IDLE
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if can_disable and hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		_stun_t = 2.4
		phase = Phase.RECOVER
		_timer = recover_secs
		_emit_sfx("crystal_clank")
		queue_redraw()
		return true
	return false


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(7.0, 7.0), Vector2(14.0, 14.0)) if is_solid() else Rect2()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		bolts.clear()
		return
	_tick_bolts(dt)
	if _stun_t > 0.0:
		_stun_t = maxf(0.0, _stun_t - dt)
		queue_redraw()
		return
	if not _enabled_by_signal:
		return
	match phase:
		Phase.IDLE:
			if aim_mode:
				_track_wick()
			_timer -= dt
			if _timer <= 0.0 and _has_target_in_range():
				phase = Phase.TELL
				_timer = tell_secs * LxToyDraw.assist_tell_scale()
				_emit_sfx("orrery_bell_tell")
				queue_redraw()
		Phase.TELL:
			if aim_mode and _timer > tell_secs * 0.35:
				_track_wick()
			_timer -= dt
			queue_redraw()
			if _timer <= 0.0:
				phase = Phase.COMMIT
				_fire_bolt()
				_timer = 0.14
		Phase.COMMIT:
			_timer -= dt
			if _timer <= 0.0:
				phase = Phase.RECOVER
				_timer = recover_secs
				queue_redraw()
		Phase.RECOVER:
			_timer -= dt
			if _timer <= 0.0:
				phase = Phase.IDLE
				_timer = maxf(0.25, cadence - tell_secs - recover_secs)
				queue_redraw()


func _has_target_in_range() -> bool:
	if not aim_mode:
		return true
	var wp: Vector2 = wick_pos()
	if wp.distance_to(pos) > sight_range:
		return false
	if region != null and region.has_method("clear_view"):
		return bool(region.call("clear_view", pos + fire_dir * 9.0, wp))
	return true


func _track_wick() -> void:
	var wp: Vector2 = wick_pos()
	var d: Vector2 = wp - pos
	if d.length_squared() > 4.0 and d.length() <= sight_range + 32.0:
		fire_dir = d.normalized()
		queue_redraw()


func _fire_bolt() -> void:
	var bdir: Vector2 = fire_dir.normalized()
	bolts.append({
		"pos": pos + bdir * 9.0,
		"prev": pos + bdir * 9.0,
		"vel": bdir * bolt_speed,
		"color": bolt_color,
		"reflected": false,
		"age": 0.0,
		"bounces": 2,
		"hit_ids": [get_instance_id()],
	})
	_emit_sfx("orrery_bolt")
	queue_redraw()


func _tick_bolts(dt: float) -> void:
	if bolts.is_empty():
		return
	var inters: Array = region.call("get_interactables") as Array if (region != null and region.has_method("get_interactables")) else []
	var i: int = bolts.size() - 1
	while i >= 0:
		var b: Dictionary = bolts[i]
		b["age"] = float(b["age"]) + dt
		var bp: Vector2 = b["pos"] as Vector2
		var bvel: Vector2 = b["vel"] as Vector2
		# Obey E0-2 LxFields (gravity wells, wind)
		var accel: Vector2 = LxToyDraw.sample_fields_accel(bp, "bolt")
		if accel.length_squared() > 0.0001:
			bvel += accel * dt
			var spd: float = clampf(bvel.length(), 45.0, bolt_speed * 2.2)
			bvel = bvel.normalized() * spd
		var nxt: Vector2 = bp + bvel * dt
		var bdir: Vector2 = bvel.normalized() if bvel.length_squared() > 0.01 else Vector2.RIGHT
		var dead: bool = float(b["age"]) > 3.5

		# 1. Wall check
		if not dead and region != null and region.has_method("tile_at"):
			if LxMapFormat.blocks_sight_tile(str(region.call("tile_at", nxt))):
				_emit_sfx("bolt_wall")
				dead = true

		# 2. Interactable reflection, tinting, blocking, or switch hits (if reflected)
		if not dead:
			var hit_ids: Array = b["hit_ids"] as Array
			for it_v: Variant in inters:
				if not (it_v is LxInteractable):
					continue
				var it: LxInteractable = it_v as LxInteractable
				if not is_instance_valid(it) or not it.active:
					continue
				var iid: int = it.get_instance_id()
				if hit_ids.has(iid):
					continue
				var hit_it: bool = (it.is_solid() and it.get_solid_rect().grow(2.0).has_point(nxt)) \
					or (Geometry2D.get_closest_point_to_segment(it.pos, bp, nxt).distance_to(it.pos) <= maxf(6.0, it.radius))
				if not hit_it:
					continue
				# Reflect off mirrors / blue_transformers
				if it.is_reflective() and int(b["bounces"]) > 0:
					var rdir: Vector2 = it.reflect_dir(bdir)
					if rdir.length_squared() > 0.001:
						b["vel"] = rdir * bvel.length()
						b["bounces"] = int(b["bounces"]) - 1
						b["reflected"] = true
						if it.has_method("get_transform_color"):
							var tc: String = str(it.call("get_transform_color")).strip_edges()
							if not tc.is_empty():
								b["color"] = LxToyDraw.normalize_light_color(tc)
						hit_ids.clear()
						hit_ids.append(iid)
						nxt = it.pos + rdir * (maxf(it.radius, 8.0) + 2.0)
						_emit_sfx("prism_bounce")
						break
				# Tint through color_glass
				if it.has_method("get_tint_color"):
					b["color"] = LxToyDraw.normalize_light_color(str(it.call("get_tint_color")))
					hit_ids.append(iid)
					continue
				# Reflected bolts can activate switches/sensors or stun turrets
				if bool(b["reflected"]):
					var hcol: String = LxToyDraw.to_hit_color(str(b["color"]))
					var src: String = LxHit.SOURCE_PRISM if hcol == LxHit.COLOR_BLUE else LxHit.SOURCE_BOLT
					var thit: LxHit = LxHit.make(src, 1.0, bdir, bp, 0.5, false, false, self, false, hcol)
					if it.on_hit(thit):
						dead = true
						break
				# Solid blocker stops bolt
				if it.is_solid():
					_emit_sfx("bolt_wall")
					dead = true
					break

		# 3. Wick hit (only unreflected bolts)
		if not dead and not bool(b["reflected"]) and Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if not w.dead and Geometry2D.get_closest_point_to_segment(w.global_position, bp, nxt).distance_to(w.global_position) <= 6.5:
				w.take_damage(bolt_damage, bp, bdir, "turret_eye")
				dead = true

		b["prev"] = bp
		b["pos"] = nxt
		b["vel"] = bvel
		if dead:
			bolts.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var trip: Array[Color] = LxToyDraw.color_triplet(bolt_color)
	var red: bool = LxHudFx.flash_reduced()

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 7.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -7.0, 14.0, 14.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["stone"] as Color, c_void)

	# Eye socket + shutter state
	var is_stun: bool = _stun_t > 0.0
	var socket_c: Color = PAL["night"] as Color if (is_stun or phase == Phase.RECOVER) else trip[0]
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), c_void)
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), socket_c)
	if not is_stun:
		var po: Vector2 = (fire_dir * 2.0).round()
		var p_col: Color = PAL["cream"] as Color if phase == Phase.TELL or phase == Phase.COMMIT else trip[2]
		draw_rect(Rect2(po.x - 1.0, po.y - 1.0, 3.0, 3.0), trip[1])
		draw_rect(Rect2(po.x, po.y, 1.0, 1.0), p_col)

	# Clear dotted aim telegraph during TELL
	if phase == Phase.TELL:
		var t_col: Color = PAL["cream"] as Color if (red or int(floorf(_clock * 14.0)) % 2 == 0) else trip[1]
		for k: int in range(1, 7):
			var tp: Vector2 = (fire_dir * (8.0 + float(k) * 6.0)).round()
			draw_rect(Rect2(tp, Vector2.ONE), t_col)

	# Active turret bolts
	for b: Dictionary in bolts:
		var bp: Vector2 = ((b["pos"] as Vector2) - pos).round()
		var bt: Array[Color] = LxToyDraw.color_triplet(str(b["color"]))
		draw_rect(Rect2(bp - Vector2(2.0, 2.0), Vector2(5.0, 5.0)), c_void)
		draw_rect(Rect2(bp - Vector2.ONE, Vector2(3.0, 3.0)), bt[1])
		draw_rect(Rect2(bp, Vector2.ONE), PAL["cream"] as Color)
