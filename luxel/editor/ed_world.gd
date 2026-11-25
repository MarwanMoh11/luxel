extends Node
## Bridge between the editor and the running game: rebuilds the room from the edited data, keeps the painted
## ground fresh, and flips between frozen (edit) and live (play).

const Io := preload("res://luxel/editor/ed_io.gd")
const Room := preload("res://luxel/editor/ed_room.gd")
const ALL_MOVES: Array[String] = ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"]

const FLAT: Dictionary = {"foliage": "pine", "rail": "dusk", "grate": "dusk", "carpet": "wine", "stairs": "mauve"}

signal paint_started
signal paint_finished(ok: bool)

var main: LxMain = null
var loader: LxRegionLoader = null
var wick: LxWick = null
var patch: Node2D = null

var live_state: Dictionary = {}  # the play-through behind the editor
var _fresh_state: Dictionary = {}
var _paint_pid: int = -1
var _paint_key: String = ""
var _paint_record: String = ""
var _paint_wait: float = -1.0
var _paint_again: bool = false
var _paint_room: RefCounted = null
var _painted_map: Dictionary = {}  # room key -> map text the PNG on disk shows
var painted_any: bool = false
var painter_on: bool = true


func boot(m: LxMain) -> void:
	main = m
	loader = Lx.world as LxRegionLoader
	wick = Lx.player as LxWick
	Lx.save.setup(true)  # the editor only ever touches the debug save
	main.start_new_game(1, false)
	_grant_all()
	_fresh_state = Lx.state.to_dict().duplicate(true)
	_fresh_state["interactable_states"] = {}
	live_state = _fresh_state.duplicate(true)
	patch = Node2D.new()
	patch.name = "EdPatch"
	patch.z_index = -9
	patch.z_as_relative = false
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	loader.add_child(patch)
	patch.draw.connect(_draw_patch)
	Lx.events.region_entered.connect(func(_i: int, _r: String) -> void: fresh_ground.call_deferred())


func _grant_all() -> void:
	for mv: String in ALL_MOVES:
		Lx.state.unlock_move(mv)
	Lx.state.grant_lantern()
	Lx.state.max_hearts = 8
	Lx.state.heal_full()
	wick.call("sync_unlocks_from_state")


# ---- Edit mode ----

func freeze() -> void:
	main.set_physics_process(false)
	main.set_process_unhandled_input(false)
	main.flow = LxMain.Flow.PAUSE  # so losing focus doesn't open the pause card
	Lx.ui.process_mode = Node.PROCESS_MODE_DISABLED
	Lx.ui.set("visible", false)
	main._darkness_layer.visible = false
	Lx.audio.set_paused(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	wick.velocity = Vector2.ZERO


func rebuild(room: RefCounted, wick_pos: Vector2) -> void:
	room.call("write_draft")
	Lx.state.from_dict(_fresh_state.duplicate(true))
	loader.discard_loaded()
	loader.load_region_from_paths(Room.draft_map(), Room.draft_json(), main._director as LxAttackDirector, int(room.get("island")), str(room.get("region")))
	fresh_ground()
	place_wick(wick_pos)


func place_wick(p: Vector2) -> void:
	wick.global_position = p.round()
	wick.last_pos = wick.global_position
	if wick.lantern != null:
		wick.lantern.reset_to_hand(wick.global_position)
	wick.queue_redraw()


func fresh_ground() -> void:
	## The imported textures lag behind repaints made in this session: show the PNGs themselves.
	if loader == null or loader.current_region_id.is_empty():
		return
	var dir: String = "res://luxel/art/islands/%d/" % loader.current_island_id
	var sp: Sprite2D = loader._ground_sprite
	if sp != null and is_instance_valid(sp):
		var tex: Texture2D = _png(dir + loader.current_region_id + "_ground.png")
		if tex != null:
			sp.texture = tex
			RenderingServer.canvas_item_clear(sp.get_canvas_item())
			sp.queue_redraw()
	if loader._layers != null:
		for lid: String in loader._layers._overlay_sprites.keys():
			var os_v: Variant = loader._layers._overlay_sprites[lid]
			if os_v is Sprite2D and is_instance_valid(os_v):
				var t2: Texture2D = _png(dir + "%s__%s.png" % [loader.current_region_id, lid])
				if t2 != null:
					(os_v as Sprite2D).texture = t2
	patch.queue_redraw()


static func _png(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return ImageTexture.create_from_image(img)


func ground_tex() -> Texture2D:
	return loader._ground_sprite.texture if loader._ground_sprite != null and is_instance_valid(loader._ground_sprite) else null


# ---- Freshly painted tiles, until the painter has redrawn the room ----

var _shown: RefCounted = null
var _old_room: RefCounted = null


func track_tiles(room: RefCounted) -> void:
	_shown = room
	var base: String = painted_map(room)
	_old_room = Room.new()
	_old_room.set("island", room.get("island"))
	_old_room.call("_parse", base, "{\"a\": 1}")
	_index_sources()
	patch.queue_redraw()


func _record_path(room: RefCounted) -> String:
	return "%s/painted/%s.map" % [Io.work_dir, room.call("file_key")]


func painted_map(room: RefCounted) -> String:
	## The .map the room's PNG shows: the disk file, unless an earlier session quit before the painter finished.
	var k: String = room.call("key")
	if not _painted_map.has(k):
		var rec: String = _record_path(room)
		var png: String = "res://luxel/art/islands/%d/%s_ground.png" % [room.get("island"), room.get("region")]
		var use_rec: bool = FileAccess.file_exists(rec) and FileAccess.get_modified_time(rec) >= FileAccess.get_modified_time(png)
		_painted_map[k] = Io.read(rec) if use_rec else str(room.call("disk_map"))
	return str(_painted_map[k])


func _index_sources() -> void:
	## For each tile type, one painted example in this room to copy while the painter works.
	var src: Dictionary = {"tex": ground_tex()}
	if src["tex"] != null:
		var ts: int = int(_old_room.get("ts"))
		var w: int = int(_old_room.get("width"))
		var h: int = int(_old_room.get("height"))
		for y: int in range(h):
			for x: int in range(w):
				var t: String = _old_room.call("tile", x, y)
				var inner: bool = true
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					inner = inner and str(_old_room.call("tile", x + o.x, y + o.y)) == t
				if not src.has(t) or (inner and not src.has(t + "!")):
					src[t] = Rect2(x * ts, y * ts, ts, ts)
					if inner:
						src[t + "!"] = true
	loader.set_meta("ed_tile_src", src)


func has_unpainted() -> bool:
	if _shown == null or _old_room == null:
		return false
	return _shown.get("rows") != _old_room.get("rows")


func _draw_patch() -> void:
	if _shown == null or _old_room == null or main.is_physics_processing():
		return
	var src: Dictionary = loader.get_meta("ed_tile_src", {}) as Dictionary
	var ts: int = int(_shown.get("ts"))
	for y: int in range(int(_shown.get("height"))):
		for x: int in range(int(_shown.get("width"))):
			var t: String = _shown.call("tile", x, y)
			if t == str(_old_room.call("tile", x, y)):
				continue
			if src.has(t) and src.get("tex") != null:
				patch.draw_texture_rect_region(src["tex"] as Texture2D, Rect2(x * ts, y * ts, ts, ts), src[t] as Rect2)
			elif FLAT.has(t):
				patch.draw_rect(Rect2(x * ts, y * ts, ts, ts), LxInteractable.PAL[str(FLAT[t])] as Color)
			else:
				LxRegionLoader.GreyboxDraw.draw_tile(patch, x, y, float(ts), t)


# ---- Background painter ----

func request_paint(room: RefCounted, delay: float = 0.6) -> void:
	if not painter_on:
		return
	_paint_room = room
	_paint_wait = delay


func is_painting() -> bool: return _paint_pid > 0 or _paint_wait >= 0.0


func _process(dt: float) -> void:
	if main != null and not main.is_physics_processing():
		Lx.audio.tick(dt, false)
	if _paint_pid > 0 and not OS.is_process_running(_paint_pid):
		var ok: bool = OS.get_process_exit_code(_paint_pid) == 0
		_paint_pid = -1
		painted_any = true
		if ok:
			_painted_map[_paint_key] = Io.read(_base_copy() + ".new")
			Io.write(_paint_record, str(_painted_map[_paint_key]))
		if _shown != null and str(_shown.call("key")) == _paint_key:
			fresh_ground()
			if ok:
				track_tiles(_shown)
		paint_finished.emit(ok)
	if _paint_wait >= 0.0:
		_paint_wait -= dt
		if _paint_wait < 0.0:
			if _paint_pid > 0:
				_paint_wait = 0.3
			else:
				_start_paint()


func paint_before_quit() -> void:
	## The painter outlives the editor; whatever is still waiting starts now.
	if _paint_wait >= 0.0 and _paint_pid <= 0:
		_start_paint()
	elif _paint_wait >= 0.0 and _paint_room != null:
		Io.write(_record_path(_paint_room), painted_map(_paint_room))


func _base_copy() -> String:
	return Io.work_dir + "/paint_base.map"


func _start_paint() -> void:
	var uv: String = find_uv()
	if uv.is_empty() or _paint_room == null:
		paint_finished.emit(false)
		return
	_paint_key = str(_paint_room.call("key"))
	_paint_record = _record_path(_paint_room)
	Io.write(_base_copy(), painted_map(_paint_room))
	Io.write(_paint_record, painted_map(_paint_room))
	Io.write(_base_copy() + ".new", str(_paint_room.call("disk_map")))
	var root: String = ProjectSettings.globalize_path("res://")
	_paint_pid = OS.create_process(uv, ["run", "--no-project", "--with", "pillow", "--with", "numpy", "python", root + "tools/epic/editor_paint.py", _paint_key, "--base", ProjectSettings.globalize_path(_base_copy())])
	Io.write(Io.work_dir + "/needs_import", "1")
	paint_started.emit()


static func find_uv() -> String:
	var home: String = OS.get_environment("HOME")
	for p: String in ["/opt/homebrew/bin/uv", home + "/.local/bin/uv", home + "/.cargo/bin/uv", "/usr/local/bin/uv"]:
		if FileAccess.file_exists(p):
			return p
	return ""


# ---- Play mode ----

func go_live(room: RefCounted, at: Vector2) -> void:
	Lx.state.from_dict(live_state.duplicate(true))
	_forget_room(room)
	_grant_all()
	loader.discard_loaded()
	Lx.ui.process_mode = Node.PROCESS_MODE_ALWAYS
	Lx.ui.set("visible", true)
	main._darkness_layer.visible = true
	main.set_physics_process(true)
	main.set_process_unhandled_input(true)
	main.flow = LxMain.Flow.PLAY
	main.load_island_region(int(room.get("island")), str(room.get("region")), at)
	main._sync_ui_flow()
	Lx.audio.set_paused(false)
	patch.queue_redraw()


func leave_live() -> void:
	loader.save_interactables_to_state()
	live_state = Lx.state.to_dict().duplicate(true)
	if wick.has_method("dismount") and bool(wick.call("is_mounted")):
		wick.call("dismount", wick.global_position)


func _forget_room(room: RefCounted) -> void:
	## A test always starts with this room untouched: nothing opened, lit, beaten or flagged in it.
	var prefix_a: String = "%d:%s:" % [room.get("island"), room.get("region")]
	for k: String in Lx.state.interactable_states.keys():
		if k.begins_with(prefix_a):
			Lx.state.interactable_states.erase(k)
	var words: Dictionary = {}
	_collect_words(room.get("json"), words)
	for k: String in Lx.state.story_flags.keys():
		if words.has("set:" + k):
			Lx.state.story_flags.erase(k)
	for lst: Array[String] in [Lx.state.lit_beacons, Lx.state.claimed_shrines, Lx.state.broken_seals, Lx.state.defeated_bosses, Lx.state.opened_doors]:
		for i: int in range(lst.size() - 1, -1, -1):
			if words.has("id:" + lst[i]) or words.has("kind:" + lst[i]):
				lst.remove_at(i)


static func _collect_words(v: Variant, out: Dictionary) -> void:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			var x: Variant = (v as Dictionary)[k]
			if x is String:
				if str(k) in ["sets_flag", "set_flag", "flag_id"]:
					out["set:" + str(x)] = true
				elif str(k) == "id":
					out["id:" + str(x)] = true
				elif str(k) == "kind":
					out["kind:" + str(x)] = true
			else:
				_collect_words(x, out)
	elif v is Array:
		for x2: Variant in (v as Array):
			_collect_words(x2, out)
