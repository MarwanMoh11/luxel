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


func _fill(key: String, rects: Array) -> void:
	var c: Color = PAL[key] as Color
	for r: Variant in rects:
		draw_rect(r as Rect2, c)


func _draw() -> void:
	_fill("void", [
		Rect2(-9.0, 2.0, 18.0, 2.0), Rect2(-7.0, 1.0, 14.0, 4.0), Rect2(-5.0, 0.0, 10.0, 5.0),
		Rect2(-8.0, -2.0, 16.0, 5.0), Rect2(-6.0, -6.0, 12.0, 5.0),
	])
	_fill("night", [Rect2(-7.0, -1.0, 14.0, 3.0), Rect2(-5.0, -5.0, 10.0, 4.0)])
	_fill("dusk", [Rect2(-7.0, -1.0, 12.0, 2.0), Rect2(-5.0, -5.0, 8.0, 3.0)])
	_fill("mauve", [Rect2(-7.0, -1.0, 8.0, 1.0), Rect2(-5.0, -5.0, 3.0, 3.0), Rect2(0.0, -4.0, 1.0, 2.0)])
	_fill("stone", [Rect2(-7.0, -1.0, 4.0, 1.0), Rect2(-5.0, -5.0, 2.0, 1.0)])
	draw_rect(Rect2(-1.0, -4.0, 1.0, 2.0), PAL["night"] as Color)
	_fill("void", [Rect2(-6.0, -7.0, 12.0, 2.0), Rect2(-7.0, -9.0, 14.0, 3.0), Rect2(-8.0, -12.0, 16.0, 4.0)])
	_fill("plum", [Rect2(-6.0, -9.0, 12.0, 2.0), Rect2(-7.0, -11.0, 14.0, 2.0)])
	_fill("night", [Rect2(-5.0, -7.0, 10.0, 2.0), Rect2(3.0, -9.0, 3.0, 2.0), Rect2(4.0, -11.0, 3.0, 2.0)])
	_fill("wine", [Rect2(-6.0, -9.0, 4.0, 1.0), Rect2(-7.0, -11.0, 11.0, 1.0)])
	draw_rect(Rect2(-6.0, -11.0, 12.0, 1.0), PAL["void"] as Color)
	_fill("gold", [Rect2(-7.0, -10.0, 1.0, 1.0), Rect2(-3.0, -10.0, 1.0, 1.0)])
	_fill("apricot", [Rect2(2.0, -10.0, 1.0, 1.0), Rect2(6.0, -10.0, 1.0, 1.0)])
	if lit:
		_draw_flame()
	else:
		draw_rect(Rect2(-5.0, -12.0, 10.0, 2.0), PAL["night"] as Color)
		draw_rect(Rect2(-4.0, -13.0, 8.0, 2.0), PAL["dusk"] as Color)
		draw_rect(Rect2(-2.0, -13.0, 4.0, 1.0), PAL["plum"] as Color)
		_fill("wine", [Rect2(-3.0, -12.0, 2.0, 1.0), Rect2(1.0, -12.0, 2.0, 1.0)])
	_draw_signal_pulses()


func _draw_flame() -> void:
	var st: int = _flicker_frame % 4
	var sway: float = -1.0 if st == 0 else (1.0 if st == 2 else 0.0)
	var tall: float = 1.0 if (st == 1 or st == 3) else 0.0
	var lh: float = 2.0 if (st == 0 or st == 3) else 1.0
	var rh: float = 2.0 if (st == 1 or st == 2) else 1.0
	var c_dark: String = LxBiomePalette.key(island_id, "dark")
	var c_mid: String = LxBiomePalette.key(island_id, "mid")
	var c_hi: String = LxBiomePalette.key(island_id, "hi")
	var c_glow: String = LxBiomePalette.key(island_id, "glow")
	var c_core: String = LxBiomePalette.key(island_id, "core")
	draw_rect(Rect2(-5.0, -12.0, 10.0, 2.0), PAL[c_dark] as Color)
	_fill(c_mid, [
		Rect2(-5.0, -14.0, 10.0, 3.0), Rect2(-4.0, -16.0, 8.0, 2.0),
		Rect2(-2.0 + sway, -19.0 - tall, 4.0, 3.0 + tall), Rect2(-1.0 + sway, -20.0 - tall, 2.0, 1.0),
		Rect2(-5.0, -15.0 - lh, 2.0, 1.0 + lh), Rect2(3.0, -15.0 - rh, 2.0, 1.0 + rh),
	])
	_fill(c_hi, [
		Rect2(-4.0, -14.0, 8.0, 2.0), Rect2(-3.0, -16.0, 6.0, 2.0),
		Rect2(-1.0 + sway, -18.0 - tall, 2.0, 2.0 + tall),
		Rect2(-4.0, -14.0 - lh, 1.0, lh), Rect2(3.0, -14.0 - rh, 1.0, rh),
	])
	_fill(c_glow, [Rect2(-3.0, -14.0, 6.0, 2.0), Rect2(-2.0, -16.0, 4.0, 2.0), Rect2(-1.0 + sway, -17.0, 2.0, 1.0)])
	_fill(c_core, [Rect2(-1.0, -14.0, 2.0, 2.0), Rect2(0.0 if sway > 0.0 else -1.0, -15.0, 1.0, 1.0)])
	var c_cream: Color = PAL[c_core] as Color
	var c_gold: Color = PAL[c_glow] as Color
	var c_apr: Color = PAL[c_hi] as Color
	var phase: float = absf(pos.x * 0.019 + pos.y * 0.013)
	for i: int in range(2):
		var t: float = fmod(_clock * 0.68 + phase + float(i) * 0.5, 1.0)
		var ex: float = roundf(sin(_clock * 2.6 + float(i) * 3.1) * (2.0 + t * 2.5))
		var ey: float = roundf(-19.0 - t * 11.0)
		draw_rect(Rect2(ex, ey, 1.0, 1.0), c_cream if t < 0.25 else (c_gold if t < 0.65 else c_apr))
	if _ignite_t > 0.0:
		var u: float = 1.0 - clampf(_ignite_t / 0.32, 0.0, 1.0)
		draw_arc(Vector2(0.0, -14.0), roundf(lerpf(4.0, 18.0, u)), 0.0, TAU, 16, c_cream if u < 0.4 else c_gold, 2.0 if u < 0.35 else 1.0, false)
