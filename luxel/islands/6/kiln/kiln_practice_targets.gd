class_name LxKilnPracticeTargets
extends LxToy
## Tempering Sanctuary (`kiln_r18`) practice target plate.
## Responds to its tuned Bolt Temper ("skip" | "scatter" | "lance") with a warm forge chime
## and spark ring so players can test their loadout before challenging The Kilnmother.

var target_temper: String = "skip"
var _ring_t: float = 0.0
var _lit_once: bool = false


func _toy_setup() -> void:
	kind = "kiln_practice_targets"
	target_temper = str(props.get("temper", "skip")).strip_edges().to_lower()
	if target_temper not in ["skip", "scatter", "lance"]:
		target_temper = "skip"
	size = Vector2(16.0, 16.0)
	radius = 12.0
	_ring_t = 0.0
	_lit_once = false
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	var matched: bool = false
	if target_temper == "skip":
		var is_skip_t: bool = Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).temper == "skip"
		matched = is_skip_t or bool(hit.get_meta("wall_bounced", false)) or int(hit.get_meta("bounces", 0)) >= 1 or hit.source == LxHit.SOURCE_PRISM
	elif target_temper == "lance":
		var is_lance_t: bool = Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).temper == "lance"
		matched = is_lance_t or hit.pierce or hit.cracks_armour or hit.source in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]
	else:
		var is_scat_t: bool = Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).temper == "scatter"
		matched = is_scat_t or hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]
	_ring_t = 0.55 if matched else 0.25
	var sfx: String = "anvil_clang_" + target_temper if matched else "shield_clang"
	_emit_sfx(sfx)
	if matched and not _lit_once:
		_lit_once = true
		set_powered(true)
		emit_power(true)
		if Lx.events != null and LxStrings.has_id("ISL6_KILN_PRAC_HIT"):
			Lx.events.narration_requested.emit("ISL6_KILN_PRAC_HIT", "narration", 2.2)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _ring_t > 0.0:
		_ring_t = maxf(0.0, _ring_t - dt)
		queue_redraw()


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	_lit_once = powered
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 34.0 if _lit_once else 20.0, 0.56 if _lit_once else 0.30)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var col: Color = (PAL["gold"] if target_temper == "skip" else (PAL["apricot"] if target_temper == "scatter" else PAL["coral"])) as Color

	LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 5.0), 7.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -7.0, 14.0, 14.0), c_night, c_dusk, col if _lit_once else PAL["stone"] as Color, c_void)
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), c_void)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), c_cream if _ring_t > 0.0 else col)
	if _ring_t > 0.0:
		var u: float = 1.0 - clampf(_ring_t / 0.55, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(5.0 + u * 12.0), 0.0, TAU, 12, col, 1.0)
	_draw_signal_pulses()
