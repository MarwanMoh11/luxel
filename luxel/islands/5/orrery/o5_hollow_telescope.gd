class_name LxO5HollowTelescope
extends LxToy
## Island 5 Grand Orrery (orrery_r15): Astronomer's East Telescope.
## Peering through reveals the wordless Hollow Wick vignette on Moon Shoals:
## a dark silhouette holding a cold blue lantern who turns toward the lens.

var inspected: bool = false
var _vista_t: float = 0.0
var _vista_dur: float = 4.2
var _prompt_key: String = "I5_OR_PROMPT_SCOPE"
var _flag_name: String = "o5_r15_telescope_seen"


func _toy_setup() -> void:
	kind = "o5_hollow_telescope"
	radius = 16.0
	_prompt_key = str(props.get("prompt_key", "I5_OR_PROMPT_SCOPE"))
	_flag_name = str(props.get("sets_flag", "o5_r15_telescope_seen"))
	inspected = Lx.state != null and bool(Lx.state.story_flags.get(_flag_name, false))
	_vista_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _vista_t > 0.0:
		_vista_t = maxf(0.0, _vista_t - dt)
		queue_redraw()


func can_interact(wick: Node) -> bool:
	return active and wick != null


func interact(_wick: Node = null) -> bool:
	if not active:
		return false
	inspected = true
	_vista_t = _vista_dur
	if Lx.state != null and not _flag_name.is_empty():
		Lx.state.story_flags[_flag_name] = true
	_emit_sfx("clockwork_chime")
	if Lx.events != null:
		if LxStrings.has_id("I5_LORE_HOLLOW_1"):
			Lx.events.narration_requested.emit("I5_LORE_HOLLOW_1", "narration", 3.6)
		elif LxStrings.has_id("I5_OR_HOLLOW_VISTA"):
			Lx.events.narration_requested.emit("I5_OR_HOLLOW_VISTA", "narration", 3.6)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return _prompt_key


func _draw() -> void:
	if not visible:
		return
	var pal: Dictionary = LxPalette.PAL
	var brass: Color = pal["apricot"] as Color
	var gold: Color = pal["gold"] as Color
	var night: Color = pal["night"] as Color
	var deep: Color = pal["deep"] as Color
	var sky: Color = pal["sky"] as Color
	var ice: Color = pal["ice"] as Color
	var cream: Color = pal["cream"] as Color
	var void_c: Color = pal["void"] as Color

	# Brass tripod base & angled telescope barrel aimed east toward Moon Shoals
	draw_line(Vector2(-6, 7), Vector2(0, -1), night, 2.0)
	draw_line(Vector2(6, 7), Vector2(0, -1), night, 2.0)
	draw_line(Vector2(0, 7), Vector2(0, -1), brass, 2.0)
	draw_line(Vector2(-8, -1), Vector2(10, -7), brass, 4.0)
	draw_line(Vector2(-7, -2), Vector2(9, -8), gold, 1.5)
	draw_circle(Vector2(10, -7), 3.0, sky if inspected else ice)
	draw_circle(Vector2(-8, -1), 2.0, night)
	# Subtle lens invite glint when uninspected
	if not inspected:
		var fr_gl: bool = LxHudFx.flash_reduced()
		var ga: float = 0.70 if fr_gl else (0.55 + 0.35 * sin(_clock * 3.0))
		draw_line(Vector2(8, -7), Vector2(12, -7), Color(cream, ga), 1.0)
		draw_line(Vector2(10, -9), Vector2(10, -5), Color(cream, ga), 1.0)

	# Eyepiece wordless vignette of Hollow Wick on Moon Shoals when peered through
	if _vista_t > 0.0:
		var fred: bool = LxHudFx.flash_reduced()
		var p: float = 1.0 - (_vista_t / _vista_dur)
		var va: float = clampf(minf(p * 5.0, (1.0 - p) * 4.0), 0.0, 1.0)
		var center := Vector2(0.0, -28.0)
		var r: float = 14.0
		draw_circle(center, r + 3.0, Color(void_c, va * 0.90))
		draw_circle(center, r + 2.0, Color(gold, va))
		draw_circle(center, r, Color(void_c, va))
		# Distant moonlit shoal horizon & cold blue water line
		draw_line(center + Vector2(-11, 5), center + Vector2(11, 5), Color(deep, va), 2.0)
		draw_line(center + Vector2(-9, 7), center + Vector2(9, 7), Color(sky, va), 1.0)
		# Dark Wick-shaped silhouette carrying a cold blue lantern
		var sil_x: float = roundf(lerpf(-5.0, 2.0, minf(p * 1.4, 1.0)))
		draw_rect(Rect2(center + Vector2(sil_x - 2.0, -4.0), Vector2(4.0, 8.0)), Color(night, va))
		draw_circle(center + Vector2(sil_x, -6.0), 2.5, Color(night, va))
		# Cold blue lantern glow (flickers gently)
		var lpos: Vector2 = (center + Vector2(sil_x + 4.0, -1.0)).round()
		var glow_r: float = 3.5 if fred else roundf(3.5 + sin(p * 18.0) * 0.6)
		draw_circle(lpos, glow_r, Color(sky, va))
		draw_circle(lpos, 1.5, Color(ice, va))
		# Second half of vignette: Hollow Wick turns toward the lens (twin ice eyes glint)
		if p >= 0.45:
			draw_rect(Rect2((center + Vector2(sil_x - 2.0, -7.0)).round(), Vector2(1.0, 1.0)), Color(cream, va))
			draw_rect(Rect2((center + Vector2(sil_x + 1.0, -7.0)).round(), Vector2(1.0, 1.0)), Color(cream, va))
