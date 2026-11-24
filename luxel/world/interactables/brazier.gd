class_name LxBrazier
extends LxInteractable
## Dungeon/overworld brazier lit by thrown lantern, beam, or sunflare; opens linked gates.

var lit: bool = false
var _flicker_frame: int = 0
var _ignite_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "brazier"
	lit = bool(props.get("lit", props.get("lit_by_default", false)))
	_uses_prop_anim = false
	_ignite_t = 0.0
	_flicker_frame = _calc_flicker_frame()
	queue_redraw()


func tick(dt: float) -> void:
	_uses_prop_anim = false
	super.tick(dt)
	if _ignite_t > 0.0:
		_ignite_t = maxf(0.0, _ignite_t - dt)
		queue_redraw()
	if not lit:
		if Lx.player is Node2D and is_instance_valid(Lx.player) and (Lx.player as Node2D).global_position.distance_squared_to(pos) <= 4624.0:
			queue_redraw()
		return
	var frame: int = _calc_flicker_frame()
	if frame != _flicker_frame:
		_flicker_frame = frame
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or lit:
		return false
	if hit.source in ["throw", "recall", "zip", "beam", "sunflare"]:
		return _ignite()
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or lit or light_radius <= 0.0:
		return
	if source in ["thrown_lantern", "lantern_hung", "lantern_fly", "lantern_recall", "lantern", "beam", "sunflare"] \
			or source.begins_with("lantern"):
		_ignite()


func interact(_actor: Node = null) -> bool:
	if not active or lit or not bool(props.get("allow_interact", false)):
		return false
	return _ignite()


func _ignite() -> bool:
	lit = true
	_ignite_t = 0.32
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.08)
	_emit_gust(56.0, 44.0, Vector2(0.0, -12.0))
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.SCORCH, pos, 10.0, 6.0)
	_emit_sfx("brazier_lit")
	if region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	_emit_save("brazier_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not lit:
		return Vector4.ZERO
	var surge: float = (sin((1.0 - clampf(_ignite_t / 0.32, 0.0, 1.0)) * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)) if _ignite_t > 0.0 else 0.0
	return Vector4(pos.x, pos.y - 8.0, 64.0 + surge * 28.0, 1.15 + surge * 0.32)


func save_state() -> Dictionary:
	return {"active": active, "lit": lit}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	lit = bool(d.get("lit", lit))
	if lit:
		_notify_linked_targets(true)
	queue_redraw()


func _calc_flicker_frame() -> int:
	var rate: float = 4.0 if LxHudFx.flash_reduced() else 10.0
	return int(floorf(_clock * rate + absf(pos.x * 0.07 + pos.y * 0.05)))


func _draw() -> void:
	# Unified contact shadow under fluted stone brazier pedestal
	_draw_ground_shadow(7.0, 2.5, Vector2(2.0, 4.0))
	var key: String = "brazier_lit" if lit else "brazier_unlit"
	var frame_ov: int = (_flicker_frame % 4) if lit else 0
	_draw_puzzle_sprite(key, Vector2.ZERO, _clock, Color.WHITE, frame_ov)
	if lit:
		var phase: float = absf(pos.x * 0.019 + pos.y * 0.013)
		for i: int in range(2):
			var t: float = fmod(_clock * 0.68 + phase + float(i) * 0.5, 1.0)
			var ex: float = roundf(sin(_clock * 2.6 + float(i) * 3.1) * (2.0 + t * 2.5))
			var ey: float = roundf(-14.0 - t * 10.0)
			var ec: Color = (PAL["cream"] if t < 0.25 else (PAL["gold"] if t < 0.65 else PAL["apricot"])) as Color
			draw_rect(Rect2(ex, ey, 1.0, 1.0), ec)
		if _ignite_t > 0.0:
			var u: float = 1.0 - clampf(_ignite_t / 0.32, 0.0, 1.0)
			var rad: float = lerpf(4.0, 15.0, u)
			var sc: Color = (PAL["cream"] if u < 0.4 else PAL["gold"]) as Color
			for k: int in range(8):
				var a: float = (TAU * float(k)) / 8.0
				var pt := Vector2(roundf(cos(a) * rad), roundf(-10.0 + sin(a) * rad * 0.7 - u * 4.0))
				draw_rect(Rect2(pt, Vector2(2.0 if u < 0.35 else 1.0, 2.0 if u < 0.35 else 1.0)), sc)
	else:
		# Readable unlit copper/ochre bronze bowl rim + crisp 1px cream top-lip highlight
		draw_rect(Rect2(-6.0, -6.0, 12.0, 2.0), LxPalette.PAL["coral"] as Color)
		draw_rect(Rect2(-5.0, -4.0, 10.0, 1.0), LxPalette.PAL["wine"] as Color)
		draw_rect(Rect2(-6.0, -6.0, 9.0, 1.0), LxPalette.PAL["apricot"] as Color)
		draw_rect(Rect2(-5.0, -5.0, 4.0, 1.0), LxPalette.PAL["apricot"] as Color)
		draw_rect(Rect2(-5.0, -7.0, 10.0, 1.0), LxPalette.PAL["apricot"] as Color)
		draw_rect(Rect2(-4.0, -7.0, 8.0, 1.0), LxPalette.PAL["gold"] as Color)
		draw_rect(Rect2(-3.0, -7.0, 5.0, 1.0), LxPalette.PAL["cream"] as Color)
		# Subtle opaque pixel ember glint above cold coals when Wick approaches
		if Lx.player is Node2D and is_instance_valid(Lx.player):
			var d_b: float = (Lx.player as Node2D).global_position.distance_to(pos)
			if d_b <= 64.0 and (LxHudFx.flash_reduced() or int(floorf(_clock * 3.2)) % 2 == 0):
				draw_rect(Rect2(-1.0, -9.0, 3.0, 1.0), PAL["gold"] as Color)
				draw_rect(Rect2(0.0, -10.0, 1.0, 3.0), PAL["cream"] as Color)
	_draw_signal_pulses()
