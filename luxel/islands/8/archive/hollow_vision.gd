class_name LxArchiveHollowVision
extends LxToy
## Wordless crystal-spine vision in archive_r9 (Memory VII - Moon Shoals).
## When powered (Black scale + Silver light sensor both satisfied), plays a 3.0 s
## wordless tableau inside the crystal glass spine showing Hollow Wick turning away
## from a golden Toll Scale as its lantern dims to pitch black, then displays ISL8_LORE_MEM7.

const VISION_DUR: float = 3.0

var played: bool = false
var _vision_t: float = 0.0


func _toy_setup() -> void:
	kind = "archive_hollow_vision"
	radius = 20.0
	z_index = 4
	played = Lx.state != null and bool(Lx.state.story_flags.get("mem_7_lit", false))
	_vision_t = 0.0
	queue_redraw()


func on_signal(_from_id: String, is_on: bool) -> void:
	if not is_on:
		return
	if not played:
		played = true
		_vision_t = VISION_DUR
		set_powered(true)
		_emit_sfx("lens_reveal")
		_emit_sfx("toll_weigh")
		if Lx.events != null and LxStrings.has_id("ISL8_LORE_MEM7"):
			Lx.events.narration_requested.emit("ISL8_LORE_MEM7", "ominous", 3.6)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.add_burst_light(pos, 110.0, 0.9 if LxHudFx.flash_reduced() else 1.35, 0.7)
		_notify_linked_targets(true)
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _vision_t > 0.0:
		_vision_t = maxf(0.0, _vision_t - dt)
		queue_redraw()
	elif played:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if _vision_t > 0.0:
		return Vector4(pos.x, pos.y, 76.0, 1.10)
	if played:
		return Vector4(pos.x, pos.y, 44.0, 0.60)
	return Vector4(pos.x, pos.y, 24.0, 0.30)


func save_state() -> Dictionary:
	return {"played": played}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	played = bool(d.get("played", played)) or (Lx.state != null and bool(Lx.state.story_flags.get("mem_7_lit", false)))
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var c_void: Color = PAL["void"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var fred: bool = LxHudFx.flash_reduced()

	# Crystal mirror plaque embedded in the glass spine
	draw_rect(Rect2(-12.0, -24.0, 24.0, 48.0), Color(c_void, 0.72))
	draw_rect(Rect2(-11.0, -23.0, 22.0, 46.0), c_ice if played else c_sky, false, 1.0)

	if _vision_t > 0.0:
		var u: float = 1.0 - clampf(_vision_t / VISION_DUR, 0.0, 1.0)
		# Golden Toll Scale at top center of the crystal vision
		draw_rect(Rect2(-7.0, -16.0, 14.0, 2.0), c_gold)
		draw_rect(Rect2(-1.0, -18.0, 2.0, 10.0), c_gold)
		draw_rect(Rect2(-8.0, -13.0, 4.0, 2.0), c_cream)
		draw_rect(Rect2(4.0, -13.0, 4.0, 2.0), c_cream)
		# Hollow Wick silhouette turning away rightward as its lantern dims to black
		var hx: float = roundf(lerpf(-2.0, 6.0, u))
		draw_rect(Rect2(hx - 3.0, -2.0, 6.0, 10.0), c_void)
		draw_rect(Rect2(hx - 2.0, -1.0, 4.0, 8.0), c_plum)
		# Dimming lantern held by Hollow Wick
		var lan_col: Color = c_gold if u < 0.35 else (c_plum if u < 0.70 else c_void)
		draw_rect(Rect2(hx + 3.0, 1.0, 3.0, 4.0), c_void)
		draw_rect(Rect2(hx + 4.0, 2.0, 1.0, 2.0), lan_col)
		if not fred:
			draw_arc(Vector2(0.0, -14.0), roundf(lerpf(6.0, 20.0, u)), 0.0, TAU, 16, Color(c_gold, 1.0 - u), 1.0)
	elif played:
		# Quiet afterimage: golden scale above an empty dark lantern silhouette
		draw_rect(Rect2(-6.0, -14.0, 12.0, 1.0), c_gold)
		draw_rect(Rect2(-1.0, -15.0, 2.0, 7.0), c_gold)
		draw_rect(Rect2(-3.0, 2.0, 6.0, 8.0), c_void)
		draw_rect(Rect2(-2.0, 3.0, 4.0, 6.0), c_ice, false, 1.0)
	else:
		# Dormant glass prism chevrons
		draw_rect(Rect2(-2.0, -6.0, 4.0, 12.0), Color(c_sky, 0.35))
		draw_rect(Rect2(-1.0, -2.0, 2.0, 4.0), c_ice)
