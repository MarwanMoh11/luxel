class_name LxMasqCotillionRing
extends LxToy
## Island 7 Masquerade r3 Midnight Cotillion Chandelier & Ring Director:
## Renders 3 nested inlaid waltz rings, a grand sweeping chandelier light cone,
## runs the periodic 9s chandelier dim shuffle (trigger_dim_swap), and plays
## Hollow Wick's telegraphed riposte shockwave on each unmask round!
## Props: swap_group (String, default "cotillion"), hollow_id (String), shuffle_secs (float, 9.0),
## radii (Array of floats, default [44, 76, 108]).

var swap_group: String = "cotillion"
var hollow_id: String = "dancer_r3_hollow"
var shuffle_secs: float = 9.0
var radii: Array[float] = [44.0, 76.0, 108.0]

var _shuffle_t: float = 9.0
var _dim_flash_t: float = 0.0
var _sweep_ang: float = 0.0
var _riposte_t: float = 0.0
var _riposte_origin: Vector2 = Vector2.ZERO
var _riposte_hit_done: bool = false
var _last_rounds_left: int = 3
var _solved: bool = false


func _toy_setup() -> void:
	kind = "masq_cotillion_ring"
	swap_group = str(props.get("swap_group", "cotillion")).strip_edges()
	hollow_id = str(props.get("hollow_id", "dancer_r3_hollow")).strip_edges()
	shuffle_secs = maxf(4.0, float(props.get("shuffle_secs", 9.0)))
	radii.clear()
	var raw_r: Variant = props.get("radii", [44.0, 76.0, 108.0])
	if raw_r is Array:
		for rv: Variant in (raw_r as Array):
			radii.append(maxf(20.0, float(rv)))
	if radii.is_empty():
		radii = [44.0, 76.0, 108.0]
	radius = radii[radii.size() - 1]
	z_index = -5
	_shuffle_t = shuffle_secs
	_dim_flash_t = 0.0
	_sweep_ang = 0.0
	_riposte_t = 0.0
	_riposte_hit_done = false
	_last_rounds_left = 3
	_solved = false
	queue_redraw()


func reset_toy() -> void:
	_shuffle_t = shuffle_secs
	_dim_flash_t = 0.0
	_riposte_t = 0.0
	_riposte_hit_done = false
	_last_rounds_left = 3
	_solved = false
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	_sweep_ang = wrapf(_sweep_ang + 0.55 * dt, -PI, PI)
	if _dim_flash_t > 0.0:
		_dim_flash_t = maxf(0.0, _dim_flash_t - dt)

	# Track Hollow Wick dancer unmask rounds for telegraphed riposte!
	if region != null and region.has_method("find_interactable"):
		var hv: Variant = region.call("find_interactable", hollow_id)
		if hv is LxMasqueradeDancer:
			var hd: LxMasqueradeDancer = hv as LxMasqueradeDancer
			_solved = hd.powered
			if hd.rounds_left < _last_rounds_left:
				_last_rounds_left = hd.rounds_left
				_dim_flash_t = 0.85
				_shuffle_t = shuffle_secs
				if not _solved:
					_riposte_origin = hd.pos
					_riposte_t = 0.65
					_riposte_hit_done = false
					if Lx.events != null:
						Lx.events.shake_requested.emit(0.18)

	# Periodic 9s chandelier dim & shuffle while Cotillion is unsolved
	if not _solved:
		_shuffle_t -= dt
		if _shuffle_t <= 0.0:
			_shuffle_t = shuffle_secs
			_dim_flash_t = 0.80
			LxMasqueradeDancer.trigger_dim_swap(region, swap_group, 0.80)
			if Lx.events != null and LxStrings.has_id("ISL7_MASQ_R3_SHUFFLE"):
				Lx.events.narration_requested.emit("ISL7_MASQ_R3_SHUFFLE", "narration", 1.8)

	# Telegraphed Hollow Wick riposte wave (0.65s tell -> radial burst, dash-crossable!)
	if _riposte_t > 0.0:
		_riposte_t = maxf(0.0, _riposte_t - dt)
		if _riposte_t <= 0.08 and not _riposte_hit_done:
			_riposte_hit_done = true
			_emit_sfx("shadow_whisper")
			if Lx.player is LxWick and is_instance_valid(Lx.player):
				var w: LxWick = Lx.player as LxWick
				w.spawn_ring(_riposte_origin, 6.0, 42.0, 0.28, PAL["rose"] as Color, 1.5)
				if not w.is_dashing() and w.global_position.distance_to(_riposte_origin) <= 32.0:
					w.take_damage(1.0, _riposte_origin, (w.global_position - _riposte_origin).normalized(), "hollow_riposte")
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if _dim_flash_t > 0.15:
		return Vector4(pos.x, pos.y, 44.0, 0.25)
	return Vector4(pos.x, pos.y, 118.0, 0.72)


func _draw() -> void:
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_void: Color = PAL["void"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var fred: bool = LxHudFx.flash_reduced()

	# Three nested Cotillion waltz rings
	for i: int in range(radii.size()):
		var rr: float = radii[i]
		var intact: bool = _solved or i < _last_rounds_left
		var col: Color = (c_gold if i == 0 else (c_ice if i == 1 else c_plum)) if intact else c_wine
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 36, Color(col, 0.52 if intact else 0.24), 1.5)
		if intact:
			var ang: float = _sweep_ang * (1.0 if i % 2 == 0 else -1.0)
			var mk: Vector2 = Vector2(cos(ang), sin(ang)) * rr
			draw_rect(Rect2(mk.round() - Vector2.ONE, Vector2(3.0, 3.0)), c_cream)

	# Central chandelier crest + sweeping light ray
	draw_circle(Vector2.ZERO, 9.0, c_void)
	draw_circle(Vector2.ZERO, 7.0, c_wine if _dim_flash_t > 0.15 else c_gold)
	draw_circle(Vector2.ZERO, 3.0, c_plum if _dim_flash_t > 0.15 else c_cream)
	if _dim_flash_t <= 0.15 and not fred:
		var cone_end: Vector2 = Vector2(cos(_sweep_ang), sin(_sweep_ang)) * radii[radii.size() - 1]
		draw_line(Vector2.ZERO, cone_end, Color(c_cream, 0.20), 6.0)

	# Telegraphed Hollow Wick riposte tell circle
	if _riposte_t > 0.0:
		var ro: Vector2 = (_riposte_origin - pos).round()
		var u: float = 1.0 - clampf(_riposte_t / 0.65, 0.0, 1.0)
		draw_arc(ro, 32.0, 0.0, TAU, 24, Color(c_rose, 0.85), 1.5)
		draw_arc(ro, roundf(lerpf(6.0, 32.0, u)), 0.0, TAU, 20, Color(c_cream, 0.78), 1.2)
