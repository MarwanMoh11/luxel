class_name LxLightSensor
extends LxToy
## Cumulative light collector: charges while illuminated (`need_secs`) and triggers linked targets when full.
## Props: need_secs (float, default 1.2), decay_rate (float, default 0.6), threshold (float, default 0.35),
## hold (bool, default false = latches once full), persist (bool), target_id/target_ids.

var need_secs: float = 1.2
var decay_rate: float = 0.6
var threshold: float = 0.35
var hold_mode: bool = false

var charge: float = 0.0
var _direct_lit: bool = false


func _toy_setup() -> void:
	kind = "light_sensor"
	need_secs = maxf(0.15, float(props.get("need_secs", 1.2)))
	decay_rate = maxf(0.0, float(props.get("decay_rate", 0.6)))
	threshold = clampf(float(props.get("threshold", 0.35)), 0.05, 1.0)
	hold_mode = bool(props.get("hold", false))
	radius = maxf(10.0, radius)
	charge = 1.0 if powered else 0.0
	_direct_lit = false
	queue_redraw()


func reset_toy() -> void:
	if persist and powered:
		return
	charge = 0.0
	_direct_lit = false
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func on_light(light_radius: float, _source: String) -> void:
	if active and light_radius > 0.0:
		_direct_lit = true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "sunflare"]:
		charge = minf(1.0, charge + (0.45 if hit.source in ["beam", "sunflare"] else 0.22))
		_direct_lit = true
		_sync_power()
		queue_redraw()
		return true
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var sampled: float = LxToyDraw.sample_light_at(region, pos, self)
	var lit_now: bool = _direct_lit or sampled >= threshold
	_direct_lit = false
	var prev_c: float = charge
	if lit_now:
		charge = minf(1.0, charge + dt / need_secs)
	elif (not powered or hold_mode) and charge > 0.0:
		charge = maxf(0.0, charge - (dt * decay_rate) / need_secs)
	if not is_equal_approx(prev_c, charge):
		_sync_power()
		queue_redraw()


func _sync_power() -> void:
	if charge >= 0.999 and not powered:
		set_powered(true)
		emit_power(true)
		_emit_sfx("switch_eye")
		_emit_gust(48.0, 32.0)
	elif hold_mode and charge < 0.05 and powered:
		set_powered(false)
		emit_power(false)


func get_light_pool() -> Vector4:
	if not active or charge < 0.25:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 2.0, 24.0 + charge * 26.0, 0.35 + charge * 0.50)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["charge"] = charge
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("charge"):
		charge = clampf(float(d["charge"]), 0.0, 1.0)
		if charge >= 0.999:
			powered = true
			_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var c_cream: Color = PAL["cream"] as Color
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 7.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -7.0, 14.0, 14.0), PAL["night"] as Color, PAL["dusk"] as Color, c_glow if powered else PAL["stone"] as Color, c_void)

	# 4-petal radial light collector that fills segment-by-segment as charge rises
	var petals: Array[Vector2] = [Vector2(0.0, -4.0), Vector2(4.0, 0.0), Vector2(0.0, 4.0), Vector2(-4.0, 0.0)]
	for i: int in range(4):
		var lit_p: bool = charge >= float(i + 1) * 0.25 - 0.001
		var pt: Vector2 = petals[i]
		draw_rect(Rect2(pt.x - 1.0, pt.y - 1.0, 3.0, 3.0), c_void)
		draw_rect(Rect2(pt.x, pt.y, 1.0, 1.0), c_cream if powered else (c_glow if lit_p else PAL["night"] as Color))

	LxToyDraw.draw_shape_glyph(self, Vector2.ZERO, 0, powered, c_glow if powered else PAL["mauve"] as Color, c_cream)
	if charge > 0.02 and not powered:
		LxToyDraw.draw_bar(self, Vector2(-7.0, 8.0), 14.0, charge, c_glow)
	_draw_signal_pulses()
