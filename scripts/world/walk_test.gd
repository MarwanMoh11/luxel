extends Node2D
## Walk the island and try the sales on the map: 1 PARTICLES, 2 BRIGHTNESS, 3 ANIMATIONS, 4 SOUND toggle,
## 5 sells 5% more PIXELS (back to 100% after 30%), 0 buys everything back, H hides this bar.

const TOGGLES := {KEY_1: "particles", KEY_2: "brightness", KEY_3: "animations", KEY_4: "sound"}
const CREAM := Color("fff4dc")
const CORAL := Color("e2725b")
const NIGHT := Color("211a3b")

var levels := {}
var _hud := Node2D.new()

@onready var island: Island = $Island


func _ready() -> void:
	Display.fill_screen(self, false) # the camera's map limits keep the bigger view on the island
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_hud)
	_hud.draw.connect(_draw_hud)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if TOGGLES.has(key.keycode):
		var id: String = TOGGLES[key.keycode]
		levels[id] = 1 - int(levels.get(id, 0))
	elif key.keycode == KEY_5:
		levels["pixels"] = (int(levels.get("pixels", 0)) + 5) % 35
	elif key.keycode == KEY_0:
		levels = {}
	elif key.keycode == KEY_H:
		_hud.visible = not _hud.visible
		return
	else:
		return
	island.apply(levels)
	_hud.queue_redraw()


func _draw_hud() -> void:
	var x := 3.0
	var items: Array = [["1 PARTICLES", "particles"], ["2 BRIGHTNESS", "brightness"], ["3 ANIMATIONS", "animations"],
		["4 SOUND", "sound"], ["5 PIXELS %d" % (100 - int(levels.get("pixels", 0))), "pixels"], ["0 RESET", ""]]
	for item: Array in items:
		var sold := int(levels.get(item[1], 0)) > 0
		PixelFont.draw(_hud, item[0], Vector2(x, 3), CORAL if sold else CREAM, NIGHT)
		x += PixelFont.width(item[0]) + 8
