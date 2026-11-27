class_name LxSpyglassChart
extends LxToy
## Boathouse Spyglass & Sea-Chart table.
## Tracks the 3 Sea-Glass Lens Shards (ebb / half / flood). Once all 3 are held
## (or quest q2_spyglass is done), repairs the spyglass, marks rune_chart_1..3,
## and sets story_flags["undertow_charted"] = true to open The Undertow Maw.

const SHARD_IDS: Array[String] = [
	"lens_shard_ebb",
	"lens_shard_half",
	"lens_shard_flood",
]

var charted: bool = false
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "spyglass_chart"
	size = Vector2(28.0, 18.0)
	radius = 20.0
	charted = _is_charted()
	powered = charted
	_pulse_t = 0.0
	queue_redraw()


func _count_shards() -> int:
	if Lx.state == null:
		return 0
	var n: int = 0
	for sid: String in SHARD_IDS:
		if bool(Lx.state.story_flags.get("quest:item:" + sid, false)) or bool(Lx.state.story_flags.get(sid, false)):
			n += 1
	return n


func _is_charted() -> bool:
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get("undertow_charted", false)) \
		or bool(Lx.state.story_flags.get("quest:q2_spyglass:done", false))


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_pulse_t = 0.65
	if charted or _count_shards() >= 3 or _is_charted():
		charted = true
		if Lx.state != null:
			Lx.state.story_flags["rune_chart_1"] = true
			Lx.state.story_flags["rune_chart_2"] = true
			Lx.state.story_flags["rune_chart_3"] = true
			Lx.state.story_flags["undertow_charted"] = true
		set_powered(true)
		emit_power(true)
		_emit_sfx("shrine_unlock")
		if Lx.events != null:
			if LxStrings.has_id("ISL2_CHART_DONE"):
				Lx.events.narration_requested.emit("ISL2_CHART_DONE", "title", 3.4)
			Lx.events.save_requested.emit("undertow_charted")
	else:
		_emit_sfx("ui_move")
		if Lx.events != null and LxStrings.has_id("ISL2_CHART_NEED"):
			Lx.events.narration_requested.emit("ISL2_CHART_NEED", "narration", 2.8)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "PROMPT_SPYGLASS" if active else ""


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-12.0, -7.0), Vector2(24.0, 14.0)) if is_solid() else Rect2()


func tick(dt: float) -> void:
	super.tick(dt)
	var now_c: bool = _is_charted()
	if now_c and not charted:
		charted = true
		powered = true
		queue_redraw()
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 44.0 if charted else 26.0, 0.72 if charted else 0.40)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var shards: int = 3 if charted else _count_shards()

	_draw_ground_shadow(13.0, 4.0, Vector2(0.0, 5.0))
	# Oak chart table
	draw_rect(Rect2(-13.0, -8.0, 26.0, 16.0), c_void)
	draw_rect(Rect2(-12.0, -7.0, 24.0, 14.0), PAL["wine"] as Color)
	draw_rect(Rect2(-11.0, -6.0, 22.0, 11.0), PAL["apricot"] as Color)
	# Sea-chart parchment
	draw_rect(Rect2(-9.0, -5.0, 18.0, 9.0), PAL["cream"] as Color if charted else PAL["stone"] as Color)
	draw_rect(Rect2(-7.0, -3.0, 14.0, 5.0), PAL["deep"] as Color)
	var fred: bool = LxHudFx.flash_reduced()
	# Maelstrom spiral mark on chart (+ 4-point compass star when charted for greyscale clarity)
	draw_arc(Vector2(2.0, -1.0), 3.0, 0.0, TAU, 10, c_ice if charted else PAL["sky"] as Color, 1.0)
	if charted:
		draw_rect(Rect2(2.0, -3.0, 1.0, 5.0), c_cream)
		draw_rect(Rect2(0.0, -1.0, 5.0, 1.0), c_cream)
	# 3 Lens-shard socket pips across the front rim (raised gems when slotted vs flat slots when missing)
	for i: int in range(3):
		var px: float = -6.0 + float(i * 6)
		var lit: bool = i < shards
		draw_rect(Rect2(px - 1.0, 3.0, 4.0, 3.0), c_void)
		if lit:
			draw_rect(Rect2(px, 3.0, 2.0, 2.0), c_cream if charted else c_gold)
		else:
			draw_rect(Rect2(px, 4.0, 2.0, 1.0), PAL["dusk"] as Color)
	# Brass spyglass tube resting diagonally on west corner
	draw_line(Vector2(-10.0, -8.0), Vector2(-3.0, -4.0), c_void, 4.0)
	draw_line(Vector2(-10.0, -8.0), Vector2(-3.0, -4.0), c_gold, 2.0)
	draw_rect(Rect2(-3.0, -5.0, 2.0, 2.0), c_cream if charted else PAL["sky"] as Color)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.65, 0.0, 1.0)
		var pc: Color = c_ice if charted else c_gold
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 24.0, u)), 0.0, TAU, 16, Color(pc, (1.0 - u) * (0.55 if fred else 0.90)), 1.0)
	_draw_signal_pulses()
