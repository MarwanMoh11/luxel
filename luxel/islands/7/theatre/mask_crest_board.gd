class_name LxTheatreMaskCrestBoard
extends LxToy
## Five Golden Move-Masks arch crest in `theatre_r1` (The Velvet Foyer).
## Visually tracks Acts I-V (`act1_done`, `act2_done`, `act3_done`, `act4_done`, `theatre_cleared`).
## Cleared act masks blaze gold/cream; uncleared acts smolder crimson behind velvet bars.

const ACT_FLAGS: Array[String] = [
	"act1_done",
	"act2_done",
	"act3_done",
	"act4_done",
	"theatre_cleared",
]
const ACT_SHAPES: Array[int] = [0, 2, 1, 5, 3]

var _flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "theatre_mask_crests"
	size = Vector2(96.0, 20.0)
	radius = 24.0
	_flash_t = 0.0
	z_index = -1
	queue_redraw()


func _done_count() -> int:
	if Lx.state == null:
		return 0
	var n: int = 0
	for f: String in ACT_FLAGS:
		if bool(Lx.state.story_flags.get(f, false)):
			n += 1
	return n


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_flash_t = 0.55
	_emit_sfx("prop_chime")
	if Lx.events != null and LxStrings.has_id("ISL7_TH_CRESTS_LINE"):
		Lx.events.narration_requested.emit("ISL7_TH_CRESTS_LINE", "narration", 2.8)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL7_TH_PROMPT_CRESTS" if active else ""


func tick(dt: float) -> void:
	super.tick(dt)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var cnt: int = _done_count()
	return Vector4(pos.x, pos.y - 2.0, 44.0 + float(cnt) * 6.0, 0.55 + float(cnt) * 0.08)


func _draw() -> void:
	if not active:
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_plum: Color = PAL["plum"] as Color
	# Ornate velvet marquee crossbar holding 5 Act Masks
	LxToyDraw.draw_bevel_box(self, Rect2(-46.0, -9.0, 92.0, 18.0), c_night, c_wine, c_gold, c_void)
	draw_rect(Rect2(-44.0, -7.0, 88.0, 14.0), c_night)
	var fr: bool = LxHudFx.flash_reduced()
	for i: int in range(ACT_FLAGS.size()):
		var mx: float = -34.0 + float(i) * 17.0
		var done: bool = Lx.state != null and bool(Lx.state.story_flags.get(ACT_FLAGS[i], false))
		var pulse: bool = (not fr) and (_flash_t > 0.0 or (done and int(floorf(_clock * 2.0 + float(i))) % 3 == 0))
		draw_rect(Rect2(mx - 6.0, -6.0, 12.0, 12.0), c_void)
		draw_rect(Rect2(mx - 5.0, -5.0, 10.0, 10.0), c_gold if done else c_plum)
		draw_rect(Rect2(mx - 4.0, -4.0, 8.0, 8.0), c_cream if (done and pulse) else (c_gold if done else c_wine))
		LxToyDraw.draw_shape_glyph(self, Vector2(mx, 0.0), ACT_SHAPES[i], done, c_wine if done else c_coral, c_cream if done else c_gold)
		if done:
			# Greyscale-distinct raised crown notch above cleared acts
			draw_rect(Rect2(mx - 2.0, -7.0, 4.0, 1.0), c_cream)
		else:
			draw_rect(Rect2(mx - 2.0, -5.0, 1.0, 10.0), c_void)
			draw_rect(Rect2(mx + 2.0, -5.0, 1.0, 10.0), c_void)
