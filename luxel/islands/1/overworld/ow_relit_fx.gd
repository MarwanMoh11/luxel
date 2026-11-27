class_name LxOwRelitFx
extends Node2D
## Ambient Dawn Chorus visual overlay mounted on Island 1's new outdoor districts
## once `great_lamp_1` / `island_1_relit` is lit (dims politely when Town Bell is at Midnight).

const PAL: Dictionary = LxPalette.PAL
const MOTE_COUNT: int = 24

var _clock: float = 0.0
var _bounds: Rect2 = Rect2(0.0, 0.0, 768.0, 512.0)
var _was_mid: bool = false
var _was_reduced: bool = false
var _drawn_once: bool = false


func _ready() -> void:
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(bounds: Rect2) -> void:
	_bounds = bounds
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drawn_once = false


func _is_midnight() -> bool:
	var bh_v: Variant = Lx.vars.get_var("island:1", "bell_hour", "evening") if Lx.vars != null else LxToyDraw.world_get_var("island:1", "bell_hour", "evening")
	return str(bh_v).strip_edges().to_lower() == "midnight"


func _process(dt: float) -> void:
	if Lx.state == null or not (Lx.state.relit_islands.has(1) or bool(Lx.state.story_flags.get("great_lamp_1", false))):
		if visible:
			visible = false
		return
	var became_vis: bool = not visible
	visible = true
	var is_mid: bool = _is_midnight()
	var reduced: bool = LxHudFx.flash_reduced()
	var state_changed: bool = became_vis or not _drawn_once or is_mid != _was_mid or reduced != _was_reduced
	_was_mid = is_mid
	_was_reduced = reduced
	if not is_mid and not reduced:
		_clock += dt
		queue_redraw()
		_drawn_once = true
	elif state_changed:
		queue_redraw()
		_drawn_once = true


func _draw() -> void:
	if not visible or _is_midnight():
		return
	var reduced: bool = LxHudFx.flash_reduced()
	var w: float = roundf(maxf(320.0, _bounds.size.x))
	var h: float = roundf(maxf(180.0, _bounds.size.y))
	# Warm dawn rim wash along upper horizon
	draw_rect(Rect2(0.0, 0.0, w, 28.0), Color(PAL["apricot"] as Color, 0.08 if reduced else 0.14))
	draw_rect(Rect2(0.0, 0.0, w, 12.0), Color(PAL["gold"] as Color, 0.06 if reduced else 0.12))
	# Drifting dawn petals & gold chime motes
	var t: float = 0.0 if reduced else _clock
	var mote_a: float = 0.48 if reduced else 0.72
	for i: int in range(MOTE_COUNT):
		var seed_x: float = fmod(float(i) * 97.3 + t * (9.0 + float(i % 4) * 3.0), w)
		var seed_y: float = fmod(float(i) * 61.7 + sin(t * 1.1 + float(i)) * 8.0 + t * 4.5, h)
		var px: float = roundf(seed_x)
		var py: float = roundf(seed_y)
		var col: Color = (PAL["gold"] if i % 3 == 0 else (PAL["apricot"] if i % 3 == 1 else PAL["cream"])) as Color
		draw_rect(Rect2(px, py, 2.0 if i % 4 == 0 else 1.0, 1.0), Color(col, mote_a))
