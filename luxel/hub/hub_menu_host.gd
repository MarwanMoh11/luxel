class_name LxHubMenuHost
extends CanvasLayer
## Modal overlay host for Wick House menus (Rematch Mirror, Music Box, Moth Ceremony,
## Lead Smith Shop, Flame Tailor). Pauses simulation while open and consumes input cleanly.

static var active: LxHubMenuHost = null

var _scrim: Node2D = null
var _rematch: LxHubMenuRematch = null
var _music: LxHubMenuMusic = null
var _services: LxHubMenuServices = null
var _active_panel: Node2D = null
var _paused_tree: bool = false


static func ensure() -> LxHubMenuHost:
	if active != null and is_instance_valid(active):
		return active
	var parent_n: Node = Lx.root if (Lx.root != null and is_instance_valid(Lx.root)) else null
	if parent_n == null and Lx.world != null and is_instance_valid(Lx.world):
		parent_n = Lx.world
	if parent_n == null:
		return null
	var existing: Node = parent_n.get_node_or_null("LxHubMenuHost")
	if existing is LxHubMenuHost:
		active = existing as LxHubMenuHost
		return active
	var inst := LxHubMenuHost.new()
	inst.name = "LxHubMenuHost"
	parent_n.add_child(inst)
	active = inst
	return inst


static func is_any_open() -> bool:
	return active != null and is_instance_valid(active) and active._active_panel != null and active._active_panel.visible


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scrim = Node2D.new()
	_scrim.name = "HubScrim"
	_scrim.visible = false
	_scrim.draw.connect(_draw_scrim)
	add_child(_scrim)
	_rematch = LxHubMenuRematch.new()
	_rematch.name = "RematchMenu"
	_rematch.closed.connect(close_all)
	add_child(_rematch)
	_music = LxHubMenuMusic.new()
	_music.name = "MusicMenu"
	_music.closed.connect(close_all)
	add_child(_music)
	_services = LxHubMenuServices.new()
	_services.name = "ServicesMenu"
	_services.closed.connect(close_all)
	add_child(_services)


func _exit_tree() -> void:
	if _paused_tree and get_tree() != null:
		get_tree().paused = false
		_paused_tree = false
	if active == self:
		active = null


func open_rematch() -> void:
	_open_panel(_rematch)
	_rematch.open()


func open_music_box() -> void:
	_open_panel(_music)
	_music.open()


func open_moth_ceremony() -> void:
	_open_panel(_services)
	_services.open_mode(LxHubMenuServices.Mode.MOTH_CEREMONY)


func open_lead_shop() -> void:
	_open_panel(_services)
	_services.open_mode(LxHubMenuServices.Mode.LEAD_SHOP)


func open_tailor() -> void:
	_open_panel(_services)
	_services.open_mode(LxHubMenuServices.Mode.TAILOR)


func get_active_panel() -> Node2D:
	return _active_panel


func _open_panel(panel: Node2D) -> void:
	close_all()
	_active_panel = panel
	if _scrim != null:
		_scrim.visible = true
		_scrim.queue_redraw()
	if get_tree() != null and not get_tree().paused:
		get_tree().paused = true
		_paused_tree = true
	if Lx.audio != null:
		Lx.audio.play_sfx("menu_open", Vector2.ZERO, false, true)


func close_all() -> void:
	for p: Node2D in [_rematch, _music, _services]:
		if p != null and is_instance_valid(p) and p.has_method("close"):
			p.call("close")
	_active_panel = null
	if _scrim != null and is_instance_valid(_scrim):
		_scrim.visible = false
	if _paused_tree and get_tree() != null:
		get_tree().paused = false
		_paused_tree = false


func _input(event: InputEvent) -> void:
	if _active_panel == null or not _active_panel.visible:
		return
	if _active_panel.has_method("handle_menu_input"):
		if bool(_active_panel.call("handle_menu_input", event)):
			get_viewport().set_input_as_handled()


func _draw_scrim() -> void:
	if _scrim != null and _scrim.visible:
		_scrim.draw_rect(Rect2(0.0, 0.0, 320.0, 180.0), Color(LxPalette.PAL["void"] as Color, 0.72))
