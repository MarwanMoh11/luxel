class_name LxPhantomPlatform
extends LxInteractable
## Hidden bridge/platform that turns solid and visible when illuminated with Lens unlocked.

var revealed: bool = false
var persist_grace: float = 0.25
var size: Vector2 = Vector2(32.0, 16.0)
var _reveal_left: float = 0.0
var _reveal_fx_t: float = 0.0
var _shimmer_stage: int = 0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "phantom_platform"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	persist_grace = maxf(0.05, float(props.get("persist_grace", 0.25)))
	revealed = bool(props.get("revealed", false))
	queue_redraw()


func on_light(light_radius: float, source: String) -> void:
	if not active or light_radius <= 0.0:
		return
	var allow: bool = source == "lens" or (
		(source == "lantern_hung" or source == "lens_anchor")
		and Lx.state != null and Lx.state.has_move("lens")
	)
	if not allow:
		return
	var was: bool = revealed
	revealed = true
	_reveal_left = persist_grace
	if not was:
		_reveal_fx_t = 0.24
		_emit_gust(48.0, 34.0)
		_emit_sfx("phantom_phase")
		queue_redraw()


func _is_reveal_warning() -> bool:
	if not revealed:
		return false
	if _reveal_left > 0.0 and _reveal_left < 0.14:
		return true
	if Lx.player == null or not is_instance_valid(Lx.player):
		return false
	var ml: Variant = Lx.player.get("move_lens")
	var lan: Variant = Lx.player.get("lantern")
	var pulse_active: bool = ml is Object and (ml as Object).has_method("is_pulse_active") and bool((ml as Object).call("is_pulse_active"))
	var pulse_warn: bool = ml is Object and (ml as Object).has_method("is_warning") and bool((ml as Object).call("is_warning"))
	var anchor_in_range: bool = false
	var anchor_warn: bool = false
	if lan is Object and (lan as Object).has_method("is_lure_active") and bool((lan as Object).call("is_lure_active")) \
			and Lx.state != null and Lx.state.has_move("lens"):
		var lpos_v: Variant = (lan as Object).get("pos")
		var hung_r: float = float(Lx.get_move_data("lens").get("hung_radius", 78.0))
		if lpos_v is Vector2 and (lpos_v as Vector2).distance_to(pos) <= hung_r + radius:
			anchor_in_range = true
			if (lan as Object).has_method("is_hanging") and bool((lan as Object).call("is_hanging")):
				anchor_warn = float((lan as Object).get("hang_timer")) <= 1.1
	if pulse_active and not pulse_warn:
		return false
	if anchor_in_range and not anchor_warn:
		return false
	return pulse_warn or anchor_warn


func tick(dt: float) -> void:
	super.tick(dt)
	var changed: bool = false
	if _reveal_fx_t > 0.0:
		_reveal_fx_t = maxf(0.0, _reveal_fx_t - dt)
		changed = true
	if revealed and _reveal_left > 0.0:
		var was_warn: bool = _reveal_left < 0.14
		_reveal_left -= dt
		if _reveal_left <= 0.0:
			revealed = false
			changed = true
		elif _reveal_left < 0.14 or was_warn:
			changed = true
	if revealed and _is_reveal_warning():
		changed = true
	if active:
		var rate: float = 3.0 if revealed else 1.5
		var st: int = int(floorf(_clock * rate + absf(pos.x * 0.02 + pos.y * 0.03))) % 4
		if st != _shimmer_stage:
			_shimmer_stage = st
			changed = true
	if changed:
		queue_redraw()


func is_platform_solid() -> bool:
	return active and revealed


func get_platform_rect() -> Rect2:
	if not is_platform_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func get_light_pool() -> Vector4:
	if not revealed:
		return Vector4.ZERO
	var surge: float = (sin((1.0 - clampf(_reveal_fx_t / 0.24, 0.0, 1.0)) * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)) if _reveal_fx_t > 0.0 else 0.0
	return Vector4(pos.x, pos.y, 32.0 + surge * 24.0, 0.55 + surge * 0.35)


func save_state() -> Dictionary:
	return {"active": active, "revealed": revealed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	revealed = bool(d.get("revealed", revealed))
	if revealed:
		_reveal_left = persist_grace
	queue_redraw()


func _draw() -> void:
	# Flat floor pad — no drop shadow.
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	if revealed:
		var warn: bool = _is_reveal_warning()
		if warn:
			var wf: int = 0 if LxHudFx.flash_reduced() else (int(floorf(_clock / 0.14)) % 2)
			_draw_puzzle_tiled("phantom_warn", size, Vector2.ZERO, _clock, Color.WHITE, wf)
		else:
			_draw_puzzle_tiled("phantom_solid", size, Vector2.ZERO, _clock, Color.WHITE, _shimmer_stage % 2)
		if _reveal_fx_t > 0.0:
			var sc: Color = (PAL["cream"] if _reveal_fx_t > 0.12 else PAL["ice"]) as Color
			draw_rect(Rect2(x0, y0, 2.0, 1.0), sc)
			draw_rect(Rect2(x0 + w - 2.0, y0, 2.0, 1.0), sc)
			draw_rect(Rect2(x0, y0 + h - 1.0, 2.0, 1.0), sc)
			draw_rect(Rect2(x0 + w - 2.0, y0 + h - 1.0, 2.0, 1.0), sc)
		return
	# Subtle 4-corner star-dust glints on transparent background (no opaque boxes or alpha washes)
	_draw_puzzle_tiled("phantom_hint", size)
	var near_player: bool = Lx.player != null and is_instance_valid(Lx.player) and Lx.player is Node2D and (Lx.player as Node2D).global_position.distance_squared_to(pos) < 3025.0
	if near_player:
		var corners: Array[Vector2] = [
			Vector2(x0 + 1.0, y0 + 1.0), Vector2(x0 + w - 2.0, y0 + 1.0),
			Vector2(x0 + 1.0, y0 + h - 2.0), Vector2(x0 + w - 2.0, y0 + h - 2.0),
		]
		draw_rect(Rect2(corners[_shimmer_stage % 4], Vector2.ONE), PAL["sky"] as Color)
