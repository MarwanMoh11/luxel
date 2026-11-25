class_name LxCourtPedestal
extends LxToy
## Briar Court relic stand (`court_r1`): places Heartwood Acorn ("acorn") or Gilded Shuttle ("shuttle").
## Interacting (or bolting for crisp responsiveness) sets the relic onto the moss-carved stand,
## rings a solemn court gavel chime, and emits power to lower the Trial Pit gate.
## Props: relic ("acorn"|"shuttle"), persist (bool, true), target_id/target_ids.

var relic: String = "acorn"
var placed: bool = false
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "court_relic_pedestal"
	relic = str(props.get("relic", "acorn")).strip_edges().to_lower()
	if relic not in ["acorn", "shuttle"]:
		relic = "acorn"
	radius = maxf(14.0, radius)
	placed = bool(props.get("placed", false)) or powered
	powered = placed
	_pulse_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and placed:
		return
	placed = false
	_pulse_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func place_relic() -> bool:
	if not active or placed:
		return false
	placed = true
	_pulse_t = 0.42
	set_powered(true)
	emit_power(true)
	_emit_sfx("ba_court_gavel")
	_emit_gust(48.0, 34.0)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_ring(pos, 4.0, 20.0, 0.32, PAL["gold"] as Color, 1.5)
	queue_redraw()
	return true


func interact(_actor: Node = null) -> bool:
	return place_relic()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or placed:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW]:
		return place_relic()
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()


func get_interact_prompt() -> String:
	if not active or placed:
		return ""
	return "ISL3_PROMPT_ACORN" if relic == "acorn" else "ISL3_PROMPT_SHUTTLE_STAND"


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(7.0, 5.0), Vector2(14.0, 10.0)) if active else Rect2()


func get_light_pool() -> Vector4:
	if not active or not placed:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 44.0 if _pulse_t > 0.0 else 32.0, 0.72 if _pulse_t > 0.0 else 0.48)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["placed"] = placed
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("placed"):
		placed = bool(d["placed"])
		powered = placed
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 9.0, 3.0)
	# Carved stone courtroom plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -4.0, 16.0, 11.0), c_night, c_dusk, c_gold if placed else c_stone, c_void)
	draw_rect(Rect2(-6.0, -6.0, 12.0, 3.0), c_void)
	draw_rect(Rect2(-5.0, -5.0, 10.0, 2.0), c_apricot if placed else c_plum)

	if not placed:
		# Recessed socket outline showing which relic belongs here
		draw_rect(Rect2(-3.0, -4.0, 6.0, 4.0), c_night)
		draw_rect(Rect2(-2.0, -3.0, 4.0, 2.0), c_jade if relic == "acorn" else c_plum)
		return

	if relic == "acorn":
		# Heartwood Acorn glowing emerald & gold
		draw_rect(Rect2(-4.0, -12.0, 8.0, 7.0), c_void)
		draw_rect(Rect2(-3.0, -11.0, 6.0, 2.0), c_wine)
		draw_rect(Rect2(-3.0, -9.0, 6.0, 3.0), c_jade)
		draw_rect(Rect2(-2.0, -8.0, 4.0, 2.0), c_lime)
		draw_rect(Rect2(-1.0, -13.0, 2.0, 2.0), c_gold)
		draw_rect(Rect2(-1.0, -8.0, 2.0, 1.0), c_cream)
	else:
		# Gilded Shuttle glowing amber & cream
		draw_rect(Rect2(-5.0, -11.0, 10.0, 5.0), c_void)
		draw_rect(Rect2(-4.0, -10.0, 8.0, 3.0), c_apricot)
		draw_rect(Rect2(-3.0, -10.0, 6.0, 2.0), c_gold)
		draw_rect(Rect2(-1.0, -9.0, 2.0, 1.0), c_cream)
	if _pulse_t > 0.0 and not LxHudFx.flash_reduced():
		var u: float = 1.0 - clampf(_pulse_t / 0.42, 0.0, 1.0)
		draw_arc(Vector2(0.0, -6.0), roundf(lerpf(6.0, 16.0, u)), 0.0, TAU, 16, c_cream, 1.0)
	_draw_signal_pulses()
