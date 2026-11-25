class_name LxPartyStartArch
extends LxToy
## Island 4 Garden Party (party_r1): Starting Arch.
## Launches the One-Dusk Heist (`party_phase = "heist"`, `dusk_hour = 1`), opens the north
## lobby gate, and chimes the opening dusk bell. Discovered stamps & shortcuts persist forever.

var started: bool = false
var _ring_t: float = 0.0


func _toy_setup() -> void:
	kind = "party_start_arch"
	radius = 18.0
	size = Vector2(36.0, 16.0)
	started = powered
	if Lx.vars != null:
		var pp: String = str(Lx.vars.get_var("dungeon:party", "party_phase", "scout"))
		if pp in ["heist", "escape", "done"]:
			started = true
			powered = true
	_ring_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	started = false
	_ring_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func get_interact_prompt() -> String:
	return "" if started else "ISL4_PT_PROMPT_ARCH"


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	return _begin_heist()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM]:
		return _begin_heist()
	return false


func _begin_heist() -> bool:
	started = true
	_ring_t = 0.55
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:party", "party_phase", "heist")
		Lx.vars.set_var("island:4", "dusk_hour", 1)
	if LxIsland4Rule.active_instance != null and is_instance_valid(LxIsland4Rule.active_instance):
		LxIsland4Rule.active_instance.set_hour(1, true, true)
	if Lx.events != null and LxStrings.has_id("ISL4_CUE_HEIST_START"):
		Lx.events.narration_requested.emit("ISL4_CUE_HEIST_START", "title", 2.8)
	_emit_sfx("sundial_skip")
	set_powered(true)
	emit_power(true)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _ring_t > 0.0:
		_ring_t = maxf(0.0, _ring_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 8.0, 44.0 if started else 28.0, 0.62 if started else 0.38)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_rose: Color = PAL["rose"] as Color

	LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 4.0), 16.0, 3.0)
	# Twin gilded clockwork lanterns flanking the heist threshold
	for sx: float in [-14.0, 10.0]:
		LxToyDraw.draw_bevel_box(self, Rect2(sx, -14.0, 4.0, 18.0), c_night, c_dusk, c_gold, c_void)
		draw_rect(Rect2(sx, -16.0, 4.0, 3.0), c_cream if started else c_rose)
	# Overhead chime bell bar
	draw_rect(Rect2(-14.0, -16.0, 28.0, 3.0), c_void)
	draw_rect(Rect2(-13.0, -15.0, 26.0, 1.0), c_gold)
	draw_circle(Vector2(0.0, -13.0), 3.0, c_cream if started else c_gold)
	if _ring_t > 0.0:
		var u: float = 1.0 - clampf(_ring_t / 0.55, 0.0, 1.0)
		draw_arc(Vector2(0.0, -12.0), roundf(lerpf(4.0, 22.0, u)), 0.0, TAU, 14, Color(c_gold, 1.0 - u), 1.4)
	_draw_signal_pulses()
