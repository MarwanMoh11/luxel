class_name LxGameState
extends Node
## Complete mutable run state for Luxel 1.0, serializable for atomic save/load.

const CURRENT_VERSION: int = 2
const RUN_LOG_PATH: String = "user://luxel1/runs.log"

var version: int = CURRENT_VERSION
var slot_id: String = "1"
var island_id: int = 1
var region_id: String = "overworld"
var room_id: String = ""
var spawn_pos: Vector2 = Vector2(572.0, 366.0)
var last_waystone_island: int = 1
var last_waystone_id: String = "ws_plaza"

var max_hearts: int = 4
var hearts: float = 4.0
var ember_pieces: int = 0
var shards: int = 0

var unlocked_moves: Dictionary = {}
var upgrades: Dictionary = {}
var lit_waystones: Array[String] = []
var lit_beacons: Array[String] = []
var claimed_shrines: Array[String] = []
var broken_seals: Array[String] = []
var relit_islands: Array[int] = []
var defeated_bosses: Array[String] = []
var collected_keys: Dictionary = {}
var opened_doors: Array[String] = []
var visited_regions: Array[String] = []
var interactable_states: Dictionary = {}
var story_flags: Dictionary = {}

var play_time_s: float = 0.0
var deaths: int = 0
var hits_taken: int = 0
var boss_retries: Dictionary = {}
var zone_times: Dictionary = {}


func reset_new_game(new_slot: String = "1") -> void:
	version = CURRENT_VERSION
	slot_id = new_slot
	island_id = 1
	region_id = "overworld"
	room_id = ""
	spawn_pos = Vector2(572.0, 366.0)
	last_waystone_island = 1
	last_waystone_id = "ws_plaza"

	max_hearts = int(Lx.get_decision("hearts_start", 4))
	hearts = float(max_hearts)
	ember_pieces = 0
	shards = 0

	unlocked_moves.clear()
	if Lx.data_moves.is_empty():
		Lx.load_all_data()
	var moves_dict: Dictionary = Lx.data_moves.get("moves", {}) as Dictionary
	for mid: String in moves_dict.keys():
		var mdata: Dictionary = moves_dict[mid] as Dictionary
		unlocked_moves[mid] = bool(mdata.get("start_unlocked", false))
	if not unlocked_moves.has("bolt"):
		unlocked_moves["bolt"] = true

	upgrades.clear()
	var upg_arr: Array = Lx.data_upgrades.get("upgrades", []) as Array
	for item: Variant in upg_arr:
		if item is Dictionary:
			upgrades[str((item as Dictionary).get("id", ""))] = 0

	lit_waystones = ["ws_plaza"]
	lit_beacons.clear()
	claimed_shrines.clear()
	broken_seals.clear()
	relit_islands.clear()
	defeated_bosses.clear()
	collected_keys.clear()
	opened_doors.clear()
	visited_regions = ["1:overworld"]
	interactable_states.clear()
	story_flags.clear()

	play_time_s = 0.0
	deaths = 0
	hits_taken = 0
	boss_retries.clear()
	zone_times.clear()


func has_move(move_id: String) -> bool:
	return bool(unlocked_moves.get(move_id, false))


func unlock_move(move_id: String) -> bool:
	if has_move(move_id):
		return false
	unlocked_moves[move_id] = true
	if Lx.events != null:
		Lx.events.move_unlocked.emit(move_id)
	return true


func get_upgrade_rank(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func can_buy_upgrade(upgrade_id: String) -> bool:
	var u: Dictionary = Lx.get_upgrade_data(upgrade_id)
	if u.is_empty():
		return false
	var rank: int = get_upgrade_rank(upgrade_id)
	var max_rank: int = int(u.get("max_rank", 0))
	if rank >= max_rank:
		return false
	var costs: Array = u.get("costs", []) as Array
	if rank >= costs.size():
		return false
	return shards >= int(costs[rank])


func buy_upgrade(upgrade_id: String) -> bool:
	if not can_buy_upgrade(upgrade_id):
		return false
	var u: Dictionary = Lx.get_upgrade_data(upgrade_id)
	var rank: int = get_upgrade_rank(upgrade_id)
	var costs: Array = u.get("costs", []) as Array
	shards -= int(costs[rank])
	upgrades[upgrade_id] = rank + 1
	if Lx.events != null:
		Lx.events.upgrade_purchased.emit(upgrade_id, rank + 1)
	return true


func add_shards(amount: int) -> void:
	shards = maxi(0, shards + amount)
	if Lx.events != null:
		Lx.events.shard_collected.emit(amount)


func add_ember_piece() -> bool:
	ember_pieces += 1
	var per_heart: int = int(Lx.get_decision("ember_pieces_per_heart", 4))
	var max_cap: int = int(Lx.get_decision("hearts_max", 12))
	var gained_heart: bool = false
	if ember_pieces % per_heart == 0 and max_hearts < max_cap:
		max_hearts += 1
		hearts = float(max_hearts)
		gained_heart = true
	if Lx.events != null:
		Lx.events.ember_piece_collected.emit(ember_pieces)
		if gained_heart:
			Lx.events.narration_requested.emit("CUE_HEART_GAINED", "title", 3.0)
			Lx.events.sfx_requested.emit("heart_pickup", Vector2.ZERO, false)
	return gained_heart


func add_boss_heart() -> void:
	var max_cap: int = int(Lx.get_decision("hearts_max", 12))
	var gained: bool = max_hearts < max_cap
	if gained:
		max_hearts += 1
	hearts = float(max_hearts)
	if gained and Lx.events != null:
		Lx.events.narration_requested.emit("CUE_HEART_GAINED", "title", 3.0)
		Lx.events.sfx_requested.emit("heart_pickup", Vector2.ZERO, false)


func heal_full() -> void:
	hearts = float(max_hearts)
	if Lx.events != null:
		Lx.events.player_healed.emit(hearts)


func get_effective_bolt_damage() -> float:
	var base: float = float(Lx.get_move_data("bolt").get("damage", 0.35))
	return _upgrade_val("bolt_damage", base)


func get_effective_bolt_cooldown() -> float:
	var base: float = float(Lx.get_move_data("bolt").get("cooldown", 0.18))
	return _upgrade_val("bolt_rate", base)


func get_effective_throw_damage() -> float:
	var base: float = float(Lx.get_move_data("throw").get("throw_damage", 2.0))
	return _upgrade_val("throw_damage", base)


func get_effective_dash_cooldown() -> float:
	var base: float = float(Lx.get_move_data("dash").get("cooldown", 0.55))
	return _upgrade_val("dash_cooldown", base)


func get_effective_ember_max() -> float:
	var base: float = float(Lx.get_move_data("sunflare").get("ember_max", 100.0))
	return _upgrade_val("ember_meter", base)


func get_effective_prism_bounces() -> int:
	var base: int = int(Lx.get_move_data("prism").get("bounces", 1))
	return int(_upgrade_val("prism_bounce", float(base)))


func _upgrade_val(upgrade_id: String, base: float) -> float:
	var rank: int = get_upgrade_rank(upgrade_id)
	if rank <= 0:
		return base
	var u: Dictionary = Lx.get_upgrade_data(upgrade_id)
	var vals: Array = u.get("values", []) as Array
	var idx: int = mini(rank - 1, vals.size() - 1)
	if idx >= 0:
		return float(vals[idx])
	return base


func mark_region_visited(isl: int, reg: String) -> void:
	var key: String = "%d:%s" % [isl, reg]
	if not visited_regions.has(key):
		visited_regions.append(key)


func add_key(dungeon_id: String, key_kind: String = "wick_key", count: int = 1) -> void:
	var key: String = "%s:%s" % [dungeon_id, key_kind]
	collected_keys[key] = int(collected_keys.get(key, 0)) + count


func get_key_count(dungeon_id: String, key_kind: String = "wick_key") -> int:
	var key: String = "%s:%s" % [dungeon_id, key_kind]
	return int(collected_keys.get(key, 0))


func consume_key(dungeon_id: String, key_kind: String = "wick_key") -> bool:
	var cur: int = get_key_count(dungeon_id, key_kind)
	if cur <= 0:
		return false
	var key: String = "%s:%s" % [dungeon_id, key_kind]
	collected_keys[key] = cur - 1
	return true


func record_zone_time(zone_key: String, dt: float) -> void:
	zone_times[zone_key] = float(zone_times.get(zone_key, 0.0)) + dt


func append_run_log(line: String) -> void:
	var dir_path: String = RUN_LOG_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(RUN_LOG_PATH) else FileAccess.WRITE
	var f: FileAccess = FileAccess.open(RUN_LOG_PATH, mode)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s | slot=%s | isl=%d | reg=%s | t=%.1f | d=%d | h=%d | %s" % [
		Time.get_datetime_string_from_system(), slot_id, island_id, region_id,
		play_time_s, deaths, hits_taken, line
	])
	f.close()


func to_dict() -> Dictionary:
	return {
		"version": version,
		"slot_id": slot_id,
		"island_id": island_id,
		"region_id": region_id,
		"room_id": room_id,
		"spawn_pos": [spawn_pos.x, spawn_pos.y],
		"last_waystone_island": last_waystone_island,
		"last_waystone_id": last_waystone_id,
		"max_hearts": max_hearts,
		"hearts": hearts,
		"ember_pieces": ember_pieces,
		"shards": shards,
		"unlocked_moves": unlocked_moves.duplicate(true),
		"upgrades": upgrades.duplicate(true),
		"lit_waystones": lit_waystones.duplicate(),
		"lit_beacons": lit_beacons.duplicate(),
		"claimed_shrines": claimed_shrines.duplicate(),
		"broken_seals": broken_seals.duplicate(),
		"relit_islands": relit_islands.duplicate(),
		"defeated_bosses": defeated_bosses.duplicate(),
		"collected_keys": collected_keys.duplicate(true),
		"opened_doors": opened_doors.duplicate(),
		"visited_regions": visited_regions.duplicate(),
		"interactable_states": interactable_states.duplicate(true),
		"story_flags": story_flags.duplicate(true),
		"play_time_s": play_time_s,
		"deaths": deaths,
		"hits_taken": hits_taken,
		"boss_retries": boss_retries.duplicate(true),
		"zone_times": zone_times.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	reset_new_game(str(d.get("slot_id", "1")))
	version = int(d.get("version", CURRENT_VERSION))
	island_id = int(d.get("island_id", 1))
	region_id = str(d.get("region_id", "overworld"))
	room_id = str(d.get("room_id", ""))
	var sp: Variant = d.get("spawn_pos", [572.0, 366.0])
	if sp is Array and (sp as Array).size() >= 2:
		spawn_pos = Vector2(float((sp as Array)[0]), float((sp as Array)[1]))
	last_waystone_island = int(d.get("last_waystone_island", 1))
	last_waystone_id = str(d.get("last_waystone_id", "ws_plaza"))
	max_hearts = clampi(int(d.get("max_hearts", 4)), 4, 12)
	hearts = clampf(float(d.get("hearts", float(max_hearts))), 0.0, float(max_hearts))
	ember_pieces = maxi(0, int(d.get("ember_pieces", 0)))
	shards = maxi(0, int(d.get("shards", 0)))

	var um: Variant = d.get("unlocked_moves", {})
	if um is Dictionary:
		for k: String in (um as Dictionary).keys():
			unlocked_moves[k] = bool((um as Dictionary)[k])
	var up: Variant = d.get("upgrades", {})
	if up is Dictionary:
		for k: String in (up as Dictionary).keys():
			upgrades[k] = int((up as Dictionary)[k])

	lit_waystones = _to_str_array(d.get("lit_waystones", ["ws_plaza"]))
	lit_beacons = _to_str_array(d.get("lit_beacons", []))
	claimed_shrines = _to_str_array(d.get("claimed_shrines", []))
	broken_seals = _to_str_array(d.get("broken_seals", []))
	relit_islands = _to_int_array(d.get("relit_islands", []))
	defeated_bosses = _to_str_array(d.get("defeated_bosses", []))
	opened_doors = _to_str_array(d.get("opened_doors", []))
	visited_regions = _to_str_array(d.get("visited_regions", ["1:overworld"]))

	var ck: Variant = d.get("collected_keys", {})
	if ck is Dictionary:
		collected_keys = (ck as Dictionary).duplicate(true)
	var is_d: Variant = d.get("interactable_states", {})
	if is_d is Dictionary:
		interactable_states = (is_d as Dictionary).duplicate(true)
	var sf: Variant = d.get("story_flags", {})
	if sf is Dictionary:
		story_flags = (sf as Dictionary).duplicate(true)
	var br: Variant = d.get("boss_retries", {})
	if br is Dictionary:
		boss_retries = (br as Dictionary).duplicate(true)
	var zt: Variant = d.get("zone_times", {})
	if zt is Dictionary:
		zone_times = (zt as Dictionary).duplicate(true)

	play_time_s = maxf(0.0, float(d.get("play_time_s", 0.0)))
	deaths = maxi(0, int(d.get("deaths", 0)))
	hits_taken = maxi(0, int(d.get("hits_taken", 0)))


static func _to_str_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for item: Variant in v:
			out.append(str(item))
	return out


static func _to_int_array(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for item: Variant in v:
			out.append(int(item))
	return out
