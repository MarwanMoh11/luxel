class_name LxOwRelitFx
extends Node2D
## Ambient Dawn Chorus visual overlay mounted on Island 1's new outdoor districts
## once `great_lamp_1` / `island_1_relit` is lit (dims politely when Town Bell is at Midnight).

const PAL: Dictionary = LxPalette.PAL
const MOTE_COUNT: int = 24

var _clock: float = 0.0
var _bounds: Rect2 = Rect2(0.0, 0.0, 768.0, 512.0)


func setup(bounds: Rect2) -> void:
	_bounds = bounds
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(dt: float) -> void:
	if Lx.state == null or not (Lx.state.relit_islands.has(1) or bool(Lx.state.story_flags.get("great_lamp_1", false))):
		if visible:
			visible = false
		return
	visible = true
	_clock += dt
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var is_mid: bool = str(LxToyDraw.world_get_var("island:1", "bell_hour", "evening")).to_lower() == "midnight"
	if is_mid:
		return
	var reduced: bool = LxHudFx.flash_reduced()
	var w: float = maxf(320.0, _bounds.size.x)
	var h: float = maxf(180.0, _bounds.size.y)
	# Warm dawn rim wash along upper horizon
	draw_rect(Rect2(0.0, 0.0, w, 28.0), Color(PAL["apricot"] as Color, 0.08 if reduced else 0.14))
	draw_rect(Rect2(0.0, 0.0, w, 12.0), Color(PAL["gold"] as Color, 0.06 if reduced else 0.12))
	# Drifting dawn petals & gold chime motes
	var t: float = 0.0 if reduced else _clock
	for i: int in range(MOTE_COUNT):
		var seed_x: float = fmod(float(i) * 97.3 + t * (9.0 + float(i % 4) * 3.0), w)
		var seed_y: float = fmod(float(i) * 61.7 + sin(t * 1.1 + float(i)) * 8.0 + t * 4.5, h)
		var px: float = roundf(seed_x)
		var py: float = roundf(seed_y)
		var col: Color = (PAL["gold"] if i % 3 == 0 else (PAL["apricot"] if i % 3 == 1 else PAL["cream"])) as Color
		draw_rect(Rect2(px, py, 2.0 if i % 4 == 0 else 1.0, 1.0), Color(col, 0.72))
