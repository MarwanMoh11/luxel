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
	elif powered and not LxHudFx.flash_reduced():
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
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var red: bool = LxHudFx.flash_reduced()
	var shimmer: bool = red or int(floorf(_clock * 5.0)) % 2 == 0

	# Grounded circular shadow
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.5, 3.2)

	# Soft solar aura when illuminated or powered
	if powered or charge > 0.25:
		draw_circle(Vector2(0.0, -1.0), 10.0 if powered else 8.0, Color(c_gold, 0.22 if powered else 0.14))

	# Round stepped stone lotus photo-basin (distinct from square beam_sensor & logic_gate)
	draw_circle(Vector2(0.0, 0.0), 8.5, c_void)
	draw_circle(Vector2(0.0, 0.0), 7.5, c_night)
	draw_circle(Vector2(0.0, -1.0), 7.0, c_dusk)
	draw_arc(Vector2(0.0, -1.0), 6.5, PI * 1.1, PI * 1.9, 10, c_stone, 1.0)

	# 4 diagonal outer lotus petals (tucked behind cardinal petals)
	var diag_pts: Array[Vector2] = [
		Vector2(-5.0, -6.0), Vector2(5.0, -6.0),
		Vector2(5.0, 4.0), Vector2(-5.0, 4.0),
	]
	for di: int in range(4):
		var dlit: bool = powered or charge >= float(di + 1) * 0.25 - 0.12
		var dp: Vector2 = diag_pts[di]
		draw_rect(Rect2(dp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_void)
		draw_rect(Rect2(dp - Vector2.ONE, Vector2(2.0, 2.0)), c_apricot if dlit else c_mauve)
		draw_rect(Rect2(dp - Vector2.ONE, Vector2.ONE), c_gold if dlit else c_stone)

	# 4 sculpted cardinal lotus petals (brighten progressively into gold/cream)
	var card_rects: Array[Rect2] = [
		Rect2(-2.0, -9.0, 4.0, 5.0), # North petal
		Rect2(4.0, -3.0, 5.0, 4.0),  # East petal
		Rect2(-2.0, 3.0, 4.0, 5.0),  # South petal
		Rect2(-9.0, -3.0, 5.0, 4.0), # West petal
	]
	for ci: int in range(4):
		var clit: bool = powered or charge >= float(ci + 1) * 0.25 - 0.001
		var r: Rect2 = card_rects[ci]
		draw_rect(r.grow(1.0), c_void)
		draw_rect(r, c_apricot if clit else c_dusk)
		var inner_r := Rect2(r.position + Vector2.ONE, Vector2(maxf(1.0, r.size.x - 2.0), maxf(1.0, r.size.y - 2.0)))
		draw_rect(inner_r, c_gold if clit else c_mauve)
		var tip_p := Vector2(floorf(r.get_center().x), r.position.y if ci == 0 else (r.end.y - 1.0 if ci == 2 else floorf(r.get_center().y)))
		if ci == 1:
			tip_p = Vector2(r.end.x - 1.0, floorf(r.get_center().y))
		elif ci == 3:
			tip_p = Vector2(r.position.x, floorf(r.get_center().y))
		draw_rect(Rect2(tip_p, Vector2.ONE), c_cream if (powered or (clit and shimmer)) else c_stone)

	# Central photo-basin mirror well
	draw_circle(Vector2(0.0, -1.0), 4.2, c_void)
	draw_circle(Vector2(0.0, -1.0), 3.2, c_apricot if powered else (c_mauve if charge > 0.1 else c_night))
	draw_circle(Vector2(0.0, -1.0), 2.2, c_gold if powered else (c_glow if charge > 0.35 else c_dusk))
	draw_rect(Rect2(-1.0, -2.0, 2.0, 2.0), c_cream if powered else (c_gold if charge > 0.5 else c_stone))

	# Subtle solar rays radiating beyond the lotus rim when illuminated/powered
	if powered or charge >= 0.75:
		var r_ext: float = 11.0 if shimmer else 10.0
		for ri: int in range(8):
			var ang: float = float(ri) * (TAU / 8.0)
			var dir_v := Vector2(cos(ang), sin(ang))
			var p0: Vector2 = (Vector2(0.0, -1.0) + dir_v * 9.0).round()
			var p1: Vector2 = (Vector2(0.0, -1.0) + dir_v * r_ext).round()
			draw_line(p0, p1, c_cream if (ri % 2 == 0 and powered) else c_gold, 1.0, false)

	if charge > 0.02 and not powered:
		LxToyDraw.draw_bar(self, Vector2(-7.0, 9.0), 14.0, charge, c_gold)
	_draw_signal_pulses()
