class_name LxObsidianSeal
extends LxInteractable
## Heavy obsidian barrier shattered only by Sunflare.

const RESONATE_RANGE: float = 84.0
const BLAST_RANGE: float = 76.0

var shattered: bool = false
var size: Vector2 = Vector2(32.0, 16.0)
var _resonate_t: float = 0.0
var _shatter_t: float = 0.0
var _ember_cd: float = 0.0
var _pulse_stage: int = 0
var _was_ready: bool = false
var _veins: Array[PackedVector2Array] = []


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "obsidian_seal"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	_rebuild_veins()
	shattered = bool(props.get("shattered", false))
	if Lx.state != null and Lx.state.broken_seals.has(id):
		shattered = true
	active = not shattered
	z_index = -4 if shattered else 0
	_resonate_t = 0.0
	_shatter_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _ember_cd > 0.0:
		_ember_cd = maxf(0.0, _ember_cd - dt)
	if _shatter_t > 0.0:
		_shatter_t = maxf(0.0, _shatter_t - dt)
		queue_redraw()
		return
	if _resonate_t > 0.0:
		_resonate_t = maxf(0.0, _resonate_t - dt)
		queue_redraw()
		return
	if active and not shattered:
		var rate: float = 1.2 if LxHudFx.flash_reduced() else 2.2
		var st: int = int(floorf(_clock * rate + absf(pos.x * 0.03))) % 4
		var sf: Vector2 = _player_sunflare_state()
		var near_now: bool = sf.x <= RESONATE_RANGE + 4.0
		var ready_now: bool = sf.y > 0.9 and sf.x <= RESONATE_RANGE
		if st != _pulse_stage or ready_now != _was_ready or near_now:
			_pulse_stage = st
			_was_ready = ready_now
			queue_redraw()


func _player_sunflare_state() -> Vector2:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return Vector2(9999.0, 0.0)
	var w_s: LxWick = Lx.player as LxWick
	var d_os: float = w_s.global_position.distance_to(pos)
	if w_s.move_sunflare == null or not w_s.move_sunflare.unlocked:
		return Vector2(d_os, 0.0)
	var charged: bool = w_s.ember >= w_s.move_sunflare.get_ember_max() - 0.001
	return Vector2(d_os, 1.0 if charged else 0.5)


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or shattered:
		return false
	if hit.source == "sunflare":
		shattered = true
		active = false
		z_index = -4
		_shatter_t = 0.42
		if Lx.state != null and not id.is_empty() and not Lx.state.broken_seals.has(id):
			Lx.state.broken_seals.append(id)
		if Lx.events != null:
			Lx.events.seal_broken.emit(island_id, id)
			Lx.events.shake_requested.emit(0.24)
			Lx.events.hitstop_requested.emit(0.055)
		_emit_gust(96.0, 92.0)
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.CRATER, pos, 16.0, 9.0)
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 15.0, 8.0)
		_emit_sfx("seal_shatter")
		_emit_save("seal_" + id)
		_notify_linked_targets(true)
		queue_redraw()
		return true
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "dash"]:
		_resonate_t = 0.22
		_emit_sfx("shield_clang")
		queue_redraw()
		# Prevent combat Ember-battery farming (D33): only grant resonance when room has no live foes and off cooldown
		var has_live_foe: bool = false
		if region != null and region.has_method("get_enemies"):
			for e: Variant in (region.call("get_enemies") as Array):
				if e is LxEnemyBrain and is_instance_valid(e) and (e as LxEnemyBrain).is_alive():
					has_live_foe = true
					break
		if not has_live_foe and _ember_cd <= 0.0:
			_ember_cd = 0.85
			return true
		return false
	return false


func get_light_pool() -> Vector4:
	if _shatter_t > 0.0:
		var u: float = clampf(_shatter_t / 0.42, 0.0, 1.0)
		return Vector4(pos.x, pos.y, 76.0 * u, (0.95 if LxHudFx.flash_reduced() else 1.50) * u)
	if shattered or not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 44.0 if _resonate_t > 0.0 else 38.0, 0.95 if _resonate_t > 0.0 else 0.68)


func is_solid() -> bool:
	return active and not shattered


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func save_state() -> Dictionary:
	return {"active": active, "shattered": shattered}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	shattered = bool(d.get("shattered", shattered))
	if Lx.state != null and Lx.state.broken_seals.has(id):
		shattered = true
	active = not shattered
	z_index = -4 if shattered else 0
	queue_redraw()


func _draw() -> void:
	if shattered:
		_draw_puzzle_tiled("obsidian_shattered", size)
		if _shatter_t > 0.0:
			var el: float = 0.42 - _shatter_t
			if el < 0.18:
				var stage_u: float = clampf(el / 0.18, 0.0, 1.0)
				var tint_c: Color = Color(PAL["cream"] as Color, 0.88) if stage_u < 0.34 else (Color(PAL["gold"] as Color, 0.65) if stage_u < 0.68 else Color(PAL["coral"] as Color, 0.38))
				_draw_puzzle_tiled("obsidian_tile", size, Vector2(0.0, roundf(stage_u * 2.0)), _clock, tint_c, 2)
			_draw_shatter_burst()
		_draw_signal_pulses()
		return
	if not active:
		_draw_signal_pulses()
		return
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var jx: float = (1.0 if int(floorf(_resonate_t * 36.0)) % 2 == 0 else -1.0) if (_resonate_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	var x0: float = floorf(-w * 0.5) + jx
	var y0: float = floorf(-h * 0.5)
	var sf: Vector2 = _player_sunflare_state()
	var d_os: float = sf.x
	var unlocked: bool = sf.y > 0.1
	var charged: bool = sf.y > 0.9
	var flare: bool = charged and d_os <= RESONATE_RANGE
	_draw_ground_shadow(w * 0.45, 2.5, Vector2(2.0, floorf(h * 0.5)))
	_draw_ember_veins(w, h, flare, d_os <= BLAST_RANGE)
	var frame_ov: int = 2 if _resonate_t > 0.0 else _pulse_stage
	_draw_puzzle_tiled("obsidian_tile", size, Vector2(jx, 0.0), _clock, Color.WHITE, frame_ov)
	if _resonate_t > 0.0:
		draw_rect(Rect2(x0, y0, 3.0, 1.0), PAL["gold"] as Color)
		draw_rect(Rect2(x0 + w - 3.0, y0, 3.0, 1.0), PAL["gold"] as Color)
		draw_rect(Rect2(x0, y0 + h - 1.0, 3.0, 1.0), PAL["gold"] as Color)
		draw_rect(Rect2(x0 + w - 3.0, y0 + h - 1.0, 3.0, 1.0), PAL["gold"] as Color)
	# Sympathetic solar crackle sparks when Wick carries Sunflare nearby
	if unlocked and d_os <= RESONATE_RANGE:
		var sp_mul: float = 0.6 if LxHudFx.flash_reduced() else 1.0
		for si: int in range(3 if charged else 2):
			var su: float = fposmod(_clock * (0.95 if charged else 0.65) * sp_mul + float(si) * 0.33, 1.0)
			var sx: float = roundf(sin(_clock * 2.8 * sp_mul + float(si) * 2.4) * (w * 0.32))
			var sy: float = roundf(-2.0 - su * 14.0)
			var sc: Color = (PAL["cream"] if (charged and su < 0.4 and not LxHudFx.flash_reduced()) else (PAL["gold"] if charged else PAL["coral"])) as Color
			draw_rect(Rect2(sx, sy, 1.0, 1.0), sc)


func _rebuild_veins() -> void:
	var hw: float = floorf(roundf(size.x) * 0.5)
	var hh: float = floorf(roundf(size.y) * 0.5)
	_veins = [
		PackedVector2Array([Vector2(-hw, 1.0), Vector2(-hw - 3.0, 2.0), Vector2(-hw - 6.0, 1.0), Vector2(-hw - 10.0, 3.0)]),
		PackedVector2Array([Vector2(-hw + 3.0, -hh), Vector2(-hw + 1.0, -hh - 3.0), Vector2(-hw - 2.0, -hh - 5.0), Vector2(-hw - 5.0, -hh - 8.0)]),
		PackedVector2Array([Vector2(hw - 3.0, -hh), Vector2(hw - 1.0, -hh - 3.0), Vector2(hw + 2.0, -hh - 5.0), Vector2(hw + 5.0, -hh - 8.0)]),
		PackedVector2Array([Vector2(hw, 1.0), Vector2(hw + 3.0, 2.0), Vector2(hw + 6.0, 1.0), Vector2(hw + 10.0, 3.0)]),
		PackedVector2Array([Vector2(hw - 4.0, hh), Vector2(hw - 2.0, hh + 3.0), Vector2(hw + 1.0, hh + 5.0), Vector2(hw + 4.0, hh + 8.0)]),
		PackedVector2Array([Vector2(-hw + 4.0, hh), Vector2(-hw + 2.0, hh + 3.0), Vector2(-hw - 1.0, hh + 5.0), Vector2(-hw - 4.0, hh + 8.0)]),
	]


func _draw_ember_veins(_w: float, _h: float, flare: bool, in_blast: bool) -> void:
	if _veins.is_empty():
		_rebuild_veins()
	var reduced: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color
	var c_in: Color = (PAL["cream"] if (flare and not reduced) else (PAL["gold"] if flare else PAL["coral"])) as Color
	var c_mid: Color = (PAL["gold"] if flare else (PAL["coral"] if _pulse_stage % 2 == 0 else PAL["wine"])) as Color
	var c_tip: Color = (PAL["apricot"] if flare else PAL["wine"]) as Color
	var sh_off := Vector2(0.0, 1.0)
	for vi: int in range(_veins.size()):
		var pts: PackedVector2Array = _veins[vi]
		for pi: int in range(pts.size() - 1):
			var p0: Vector2 = pts[pi]
			var p1: Vector2 = pts[pi + 1]
			draw_line(p0 + sh_off, p1 + sh_off, c_void, 1.0, false)
			var vc: Color = c_in if pi == 0 else (c_mid if pi == 1 else c_tip)
			if flare and pi == 1 and in_blast and not reduced and (_pulse_stage + vi) % 2 == 0:
				vc = PAL["cream"] as Color
			draw_line(p0, p1, vc, 1.0, false)
	if not flare:
		return
	var base_a: float = _clock * (0.9 if reduced else 1.8)
	var c_arc_g: Color = PAL["gold"] as Color
	var c_arc_c: Color = PAL["cream"] as Color
	var center_off := Vector2(0.0, 2.0)
	for half_i: int in range(2):
		var a0: float = base_a + float(half_i) * PI
		for step_i: int in range(-2, 3):
			var ang: float = a0 + float(step_i) * 0.26
			var ap: Vector2 = (center_off + Vector2(cos(ang) * 16.0, sin(ang) * 16.0)).round()
			var bright: bool = (step_i == 0) or (in_blast and absi(step_i) == 1 and not reduced)
			draw_rect(Rect2(ap, Vector2.ONE), c_arc_c if bright else c_arc_g)


func _draw_shatter_burst() -> void:
	var u: float = 1.0 - clampf(_shatter_t / 0.42, 0.0, 1.0)
	var spread: float = maxf(size.x, size.y) * 0.52
	for i: int in range(10):
		var a: float = (TAU * float(i)) / 10.0 + 0.15
		var d: float = lerpf(3.0, spread + 16.0, u)
		var px: float = roundf(cos(a) * d)
		var py: float = roundf(sin(a) * d + u * u * 8.0 - u * 5.0)
		var sz: float = 3.0 if (u < 0.35 and i % 2 == 0) else (2.0 if u < 0.7 else 1.0)
		var c: Color = (PAL["gold"] if i % 3 == 0 else (PAL["coral"] if i % 3 == 1 else PAL["dusk"])) as Color
		draw_rect(Rect2(px, py, sz, sz), c)
