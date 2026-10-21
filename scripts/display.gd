extends Node
## Autoload "Display": a big, crisp window and a fullscreen with no black bars.
## Every scene draws in 320x180 game pixels, scaled up by a whole number so the pixels stay square.
## The game launches fullscreen (START_FULLSCREEN); leaving fullscreen gives a window at the largest whole
## multiple of 320x180 that fits the screen comfortably. Game pixels never get bigger than in that window, so
## a scene that calls fill_screen() shows more world in fullscreen instead of zooming in (on a Mac in a scaled
## display mode, the default on a MacBook Air, the window's scale is also the one that stays crisp).
## fill_screen() grows the viewport to cover the whole window at that scale, with no bars. With `centre`, every canvas is
## shifted by `margin`, so the 320x180 game screen (HUD, menus, screen effects) sits in the middle.
## F11 or Alt+Enter toggles fullscreen (on a Mac the green button and fn+F work too).

signal changed

const BASE := Vector2i(320, 180)
const WINDOW_ROOM := 0.9 # share of the free screen the launch window may take
const START_FULLSCREEN := true # desktop runs only: never headless, in the web build, Movie Maker or the editor's Game tab

var view_size := Vector2(BASE) ## the whole viewport, in game pixels
var margin := Vector2.ZERO ## where the 320x180 game screen starts inside it
var _filler: Node
var _centre := false
var _laid_out_for := Vector2i.ZERO # window size of the last layout
var _max_scale := 0 # the launch window's scale on desktop runs; 0 = no cap (headless, web, Movie Maker, editor)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if (OS.has_feature("web") or OS.has_feature("embedded_in_editor") or OS.has_feature("movie")
			or DisplayServer.get_name() == "headless"):
		return
	_max_scale = _window_scale()
	if get_window().mode == Window.MODE_WINDOWED:
		get_window().size = BASE * _max_scale
		get_window().move_to_center()
		if START_FULLSCREEN:
			get_window().mode = Window.MODE_FULLSCREEN


## Polled: the window's size_changed signal stays quiet when a resize keeps the 320x180 viewport.
func _process(_delta: float) -> void:
	if get_window().size != _laid_out_for:
		_layout()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.alt_pressed and key.keycode in [KEY_ENTER, KEY_KP_ENTER]):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() in [
		DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Fills the window edge to edge while `node` is in the tree (see the top). With `centre`, the scene's camera
## must anchor top-left (Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT) on the game screen's top-left: the view then
## starts `margin` px above and left of it.
func fill_screen(node: Node, centre: bool) -> void:
	_filler = node
	_centre = centre
	node.tree_exiting.connect(_unfill.bind(node), CONNECT_ONE_SHOT)
	_layout()


## The whole screen in game-screen coordinates, for anything that must cover all of it.
func screen_rect() -> Rect2:
	return Rect2(-margin, view_size)


func _unfill(node: Node) -> void:
	if _filler == node:
		_filler = null
		_layout()


func _layout() -> void:
	_laid_out_for = get_window().size
	_fit(_laid_out_for)


## Lays the game out for a window of `window` px (split out so a headless check can try any screen size).
func _fit(window: Vector2i) -> void:
	var size := BASE
	if _filler != null:
		var k := maxi(1, floori(minf(float(window.x) / BASE.x, float(window.y) / BASE.y)))
		if _max_scale > 0:
			k = mini(k, _max_scale)
		size = BASE + ((window / k - BASE) / 2 * 2).maxi(0) # even extra, so the margins are whole pixels
	var root := get_window()
	root.content_scale_size = size
	view_size = Vector2(size)
	margin = (view_size - Vector2(BASE)) / 2.0 if _centre and _filler != null else Vector2.ZERO
	root.global_canvas_transform = Transform2D(0.0, margin)
	changed.emit()


## The largest whole scale whose 320x180 window fits WINDOW_ROOM of the free screen.
func _window_scale() -> int:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var deco := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var room := Vector2(usable.size - deco) * WINDOW_ROOM
	return maxi(1, floori(minf(room.x / BASE.x, room.y / BASE.y)))
