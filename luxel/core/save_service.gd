class_name LxSaveService
extends Node
## Atomic save/load with backup fallback and forward version migration (SWARM_SPEC 3.7).
## Stores exclusively in user://luxel1/ (debug runs use debug_*.json).

const SAVE_DIR: String = "user://luxel1"
const CURRENT_VERSION: int = 2
const SLOT_COUNT: int = 3

var debug_mode: bool = false
var settings: Dictionary = {}
var last_load_used_backup: bool = false
var last_notice_key: String = ""


func _init() -> void:
	settings = default_settings()


func setup(is_debug: bool) -> void:
	debug_mode = is_debug
	_ensure_dir()
	load_settings()


func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func slot_path(slot_num: int) -> String:
	var n: int = clampi(slot_num, 1, SLOT_COUNT)
	if debug_mode:
		return "%s/debug_slot_%d.json" % [SAVE_DIR, n]
	return "%s/slot_%d.json" % [SAVE_DIR, n]


func settings_path() -> String:
	if debug_mode:
		return "%s/debug_settings.json" % SAVE_DIR
	return "%s/settings.json" % SAVE_DIR


func slot_exists(slot_num: int) -> bool:
	var p: String = slot_path(slot_num)
	return FileAccess.file_exists(p) or FileAccess.file_exists(p + ".bak")


func slot_summary(slot_num: int) -> Dictionary:
	var d: Dictionary = load_slot_dict(slot_num)
	if d.is_empty():
		return {"empty": true, "slot": slot_num}
	return {
		"empty": false,
		"slot": slot_num,
		"island_id": int(d.get("island_id", 1)),
		"hearts": int(d.get("max_hearts", 4)),
		"play_time_s": float(d.get("play_time_s", 0.0)),
		"relit_count": (d.get("relit_islands", []) as Array).size(),
	}


func save_slot(slot_num: int, state: LxGameState) -> bool:
	if state == null:
		return false
	state.slot_id = str(clampi(slot_num, 1, SLOT_COUNT))
	state.version = CURRENT_VERSION
	return _write_atomic_json(slot_path(slot_num), state.to_dict())


func load_slot(slot_num: int, state: LxGameState) -> bool:
	var d: Dictionary = load_slot_dict(slot_num)
	if d.is_empty():
		return false
	state.from_dict(d)
	return true


func load_slot_dict(slot_num: int) -> Dictionary:
	last_load_used_backup = false
	last_notice_key = ""
	var p: String = slot_path(slot_num)
	var d: Dictionary = _read_json_dict(p)
	if not d.is_empty() and _is_valid_save_dict(d):
		return migrate(d)
	var bak: String = p + ".bak"
	var db: Dictionary = _read_json_dict(bak)
	if not db.is_empty() and _is_valid_save_dict(db):
		last_load_used_backup = true
		last_notice_key = "NOTICE_SAVE_BACKUP"
		return migrate(db)
	return {}


func delete_slot(slot_num: int) -> void:
	var p: String = slot_path(slot_num)
	for suffix: String in ["", ".bak", ".tmp"]:
		var full: String = ProjectSettings.globalize_path(p + suffix)
		if FileAccess.file_exists(p + suffix):
			DirAccess.remove_absolute(full)


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var ver: int = int(out.get("version", 1))
	if ver < 2:
		if not out.has("visited_regions"):
			out["visited_regions"] = ["%d:%s" % [int(out.get("island_id", 1)), str(out.get("region_id", "overworld"))]]
		if not out.has("collected_keys"):
			out["collected_keys"] = {}
		if not out.has("opened_doors"):
			out["opened_doors"] = []
		if not out.has("boss_retries"):
			out["boss_retries"] = {}
		if not out.has("zone_times"):
			out["zone_times"] = {}
		if not out.has("upgrades"):
			out["upgrades"] = {}
		if not out.has("interactable_states"):
			out["interactable_states"] = {}
		if not out.has("story_flags"):
			out["story_flags"] = {}
		out["version"] = 2
	return out


static func _is_valid_save_dict(d: Dictionary) -> bool:
	return d.has("version") and d.has("island_id")


static func default_settings() -> Dictionary:
	return {
		"version": 1,
		"master_vol": 1.0,
		"music_vol": 0.85,
		"sfx_vol": 0.9,
		"ambience_vol": 0.65,
		"mute_unfocus": true,
		"fullscreen": false,
		"window_scale": 3,
		"screen_shake": 100,
		"flash_reduction": false,
		"cursor_size": 1,
		"cursor_color": "gold",
		"bindings": {},
		"hold_mode": {"lx_fire": "hold", "lx_beam": "hold", "lx_wings": "hold"},
		"assist_damage_mult": 1.0,
		"assist_tell_scale": 1.0,
		"assist_game_speed": 1.0,
	}


func load_settings() -> Dictionary:
	var base: Dictionary = default_settings()
	var p: String = settings_path()
	var d: Dictionary = _read_json_dict(p)
	if d.is_empty():
		d = _read_json_dict(p + ".bak")
	for k: String in d.keys():
		if base.has(k):
			base[k] = d[k]
	# Clamp Assist options strictly to valid ranges; aim assist never exists.
	base["assist_damage_mult"] = clampf(float(base.get("assist_damage_mult", 1.0)), 0.0, 1.0)
	base["assist_tell_scale"] = clampf(float(base.get("assist_tell_scale", 1.0)), 1.0, 1.5)
	base["assist_game_speed"] = clampf(float(base.get("assist_game_speed", 1.0)), 0.7, 1.0)
	base["screen_shake"] = clampi(int(base.get("screen_shake", 100)), 0, 100)
	settings = base
	return settings


func save_settings() -> bool:
	return _write_atomic_json(settings_path(), settings)


func _write_atomic_json(user_path: String, data: Dictionary) -> bool:
	_ensure_dir()
	var abs_target: String = ProjectSettings.globalize_path(user_path)
	var abs_tmp: String = abs_target + ".tmp"
	var abs_bak: String = abs_target + ".bak"
	var json_text: String = JSON.stringify(data, "  ") + "\n"
	var f: FileAccess = FileAccess.open(abs_tmp, FileAccess.WRITE)
	if f == null:
		push_warning("LxSaveService: failed to open tmp " + abs_tmp)
		return false
	f.store_string(json_text)
	f.flush()
	f.close()
	if FileAccess.file_exists(abs_target):
		var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(abs_target)
		var fb: FileAccess = FileAccess.open(abs_bak, FileAccess.WRITE)
		if fb != null:
			fb.store_buffer(old_bytes)
			fb.flush()
			fb.close()
	var err: Error = DirAccess.rename_absolute(abs_tmp, abs_target)
	if err != OK:
		push_warning("LxSaveService: rename failed " + str(err))
		return false
	return true


func _read_json_dict(user_path: String) -> Dictionary:
	if not FileAccess.file_exists(user_path):
		return {}
	var txt: String = FileAccess.get_file_as_string(user_path)
	if txt.strip_edges().is_empty():
		return {}
	var parser := JSON.new()
	if parser.parse(txt) != OK:
		return {}
	if parser.data is Dictionary:
		return parser.data as Dictionary
	return {}
