class_name Lx
extends RefCounted
## Static service registry for Luxel 1.0 (no new project.godot autoloads).

static var root: Node = null
static var state: LxGameState = null
static var save: LxSaveService = null
static var input: LxInputService = null
static var audio: LxAudioService = null
static var events: LxEventBus = null
static var hitstop: LxHitstop = null
static var camera: LxCameraRig = null
static var rng: LxRng = null
static var platform: LxPlatformService = null
static var debug: LxDebugArgs = null
static var packs: LxPackRegistry = null
static var vars: LxWorldState = null
static var panes: Object = null

static var world: Node = null
static var player: Node = null
static var companion: Node = null
static var ui: Node = null
static var director: RefCounted = null

static var data_islands: Dictionary = {}
static var data_moves: Dictionary = {}
static var data_upgrades: Dictionary = {}
static var data_economy: Dictionary = {}


static func reset() -> void:
	root = null
	state = null
	save = null
	input = null
	audio = null
	events = null
	hitstop = null
	camera = null
	rng = null
	platform = null
	debug = null
	packs = null
	vars = null
	panes = null
	world = null
	player = null
	companion = null
	ui = null
	director = null


static func ensure_packs() -> LxPackRegistry:
	if packs == null:
		packs = LxPackRegistry.new()
		packs.load_all()
	return packs


static func ensure_vars() -> LxWorldState:
	if vars == null:
		vars = LxWorldState.new()
	return vars


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Lx.load_json missing: " + path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed as Dictionary
	push_warning("Lx.load_json invalid JSON: " + path)
	return {}


static func load_all_data() -> void:
	data_islands = load_json("res://luxel/data/islands.json")
	data_moves = load_json("res://luxel/data/moves.json")
	data_upgrades = load_json("res://luxel/data/upgrades.json")
	data_economy = load_json("res://luxel/data/economy.json")


static func get_hard_mode_preset() -> Dictionary:
	if data_economy.is_empty():
		data_economy = load_json("res://luxel/data/economy.json")
	var hm: Variant = data_economy.get("hard_mode", {})
	return hm as Dictionary if hm is Dictionary else {}


static func get_island_data(island_id: int) -> Dictionary:
	if data_islands.is_empty():
		load_all_data()
	var arr: Variant = data_islands.get("islands", [])
	if arr is Array:
		for item: Variant in arr:
			if item is Dictionary and int((item as Dictionary).get("id", 0)) == island_id:
				return item as Dictionary
	return {}


static func get_move_data(move_id: String) -> Dictionary:
	if data_moves.is_empty():
		load_all_data()
	var moves: Variant = data_moves.get("moves", {})
	if moves is Dictionary and (moves as Dictionary).has(move_id):
		return (moves as Dictionary)[move_id] as Dictionary
	return {}


static func get_upgrade_data(upgrade_id: String) -> Dictionary:
	if data_upgrades.is_empty():
		load_all_data()
	var arr: Variant = data_upgrades.get("upgrades", [])
	if arr is Array:
		for item: Variant in arr:
			if item is Dictionary and str((item as Dictionary).get("id", "")) == upgrade_id:
				return item as Dictionary
	return {}


static func get_decision(key: String, default_val: Variant = null) -> Variant:
	if data_islands.is_empty():
		load_all_data()
	var dec: Variant = data_islands.get("decisions", {})
	if dec is Dictionary:
		return (dec as Dictionary).get(key, default_val)
	return default_val
