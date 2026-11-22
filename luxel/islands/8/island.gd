class_name LxIsland8
extends RefCounted
## Island 8 (The Long Night - Finale) progression beats, Night Remix gauntlets, and Bell Sanctum.

const ISLAND_ID: int = 8
const SEAL_ID: String = "sanctum_gate_seal"
const BOSS_ID: String = "the_hush"
const MINI_BOSS_KIND: String = "night_harbinger"

const REQUIRED_BEACONS: Array[String] = [
	"beacon_8_1",
	"beacon_8_2",
	"beacon_8_3",
]

const REGIONS: Array[String] = [
	"overworld",
	"sanctum_r1",
	"sanctum_r2",
	"sanctum_r3",
	"sanctum_r4",
	"sanctum_r5",
	"sanctum_r6",
]

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	if _events == null:
		return
	_attached = true
	_events.region_entered.connect(_on_region_entered)
	_events.beacon_lit.connect(_on_beacon_lit)
	_events.enemy_killed.connect(_on_enemy_killed)
	_events.boss_phase_changed.connect(_on_boss_phase_changed)
	_events.boss_defeated.connect(_on_boss_defeated)
	_events.great_lamp_relit.connect(_on_great_lamp_relit)


func detach() -> void:
	if not _attached or _events == null:
		_attached = false
		return
	if _events.region_entered.is_connected(_on_region_entered):
		_events.region_entered.disconnect(_on_region_entered)
	if _events.beacon_lit.is_connected(_on_beacon_lit):
		_events.beacon_lit.disconnect(_on_beacon_lit)
	if _events.enemy_killed.is_connected(_on_enemy_killed):
		_events.enemy_killed.disconnect(_on_enemy_killed)
	if _events.boss_phase_changed.is_connected(_on_boss_phase_changed):
		_events.boss_phase_changed.disconnect(_on_boss_phase_changed)
	if _events.boss_defeated.is_connected(_on_boss_defeated):
		_events.boss_defeated.disconnect(_on_boss_defeated)
	if _events.great_lamp_relit.is_connected(_on_great_lamp_relit):
		_events.great_lamp_relit.disconnect(_on_great_lamp_relit)
	_attached = false


func get_region_list() -> PackedStringArray:
	return PackedStringArray(REGIONS)


func get_main_path_waypoints() -> Array[Dictionary]:
	return [
		{
			"id": "wp_isl8_beacon_1",
			"region": "overworld",
			"zone": "gauntlet_tide",
			"pos": [152.0, 776.0],
			"action": "light_beacon",
			"target": "beacon_8_1",
			"grants_flag": "beacon_8_1",
			"requires_moves": ["bolt", "dash", "throw", "prism"],
			"requires_flags": [],
		},
		{
			"id": "wp_isl8_beacon_2",
			"region": "overworld",
			"zone": "gauntlet_mire",
			"pos": [152.0, 520.0],
			"action": "light_beacon",
			"target": "beacon_8_2",
			"grants_flag": "beacon_8_2",
			"requires_moves": ["beam", "wings"],
			"requires_flags": [],
		},
		{
			"id": "wp_isl8_beacon_3",
			"region": "overworld",
			"zone": "gauntlet_kiln",
			"pos": [136.0, 296.0],
			"action": "light_beacon",
			"target": "beacon_8_3",
			"grants_flag": "beacon_8_3",
			"requires_moves": ["lens", "sunflare"],
			"requires_flags": [],
		},
		{
			"id": "wp_enter_sanctum",
			"region": "overworld",
			"zone": "dark_hub",
			"pos": [336.0, 64.0],
			"action": "enter_exit",
			"target": "exit_to_sanctum",
			"to_region": "sanctum_r1",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"],
			"requires_flags": ["beacon_8_1", "beacon_8_2", "beacon_8_3"],
		},
		{
			"id": "wp_sanctum_r2_flame",
			"region": "sanctum_r2",
			"zone": "sanctum_r2",
			"pos": [40.0, 88.0],
			"action": "collect_key",
			"target": "wick_key_8_1",
			"grants_flag": "wick_key_8_1",
			"requires_moves": ["prism", "beam"],
			"requires_flags": [],
		},
		{
			"id": "wp_sanctum_r3_flight",
			"region": "sanctum_r3",
			"zone": "sanctum_r3",
			"pos": [160.0, 48.0],
			"action": "clear_room",
			"target": "door_sanctum_r3_north",
			"requires_moves": ["wings", "lens"],
			"requires_flags": ["wick_key_8_1"],
		},
		{
			"id": "wp_sanctum_miniboss",
			"region": "sanctum_r4",
			"zone": "sanctum_r4",
			"pos": [224.0, 128.0],
			"action": "defeat_miniboss",
			"target": "mini_night_harbinger",
			"grants_flag": "keepers_flame_8",
			"requires_moves": ["dash", "throw", "sunflare"],
			"requires_flags": [],
		},
		{
			"id": "wp_sanctum_r5_choir",
			"region": "sanctum_r5",
			"zone": "sanctum_r5",
			"pos": [160.0, 24.0],
			"action": "unlock_door",
			"target": "door_boss_8",
			"requires_moves": ["sunflare"],
			"requires_flags": ["keepers_flame_8"],
		},
		{
			"id": "wp_sanctum_boss",
			"region": "sanctum_r6",
			"zone": "sanctum_r6",
			"pos": [240.0, 152.0],
			"action": "defeat_boss",
			"target": "boss_the_hush",
			"grants_flag": "boss_the_hush_defeated",
			"requires_moves": ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"],
			"requires_flags": ["keepers_flame_8"],
		},
		{
			"id": "wp_great_lamp_8",
			"region": "sanctum_r6",
			"zone": "sanctum_r6",
			"pos": [240.0, 64.0],
			"action": "light_great_lamp",
			"target": "great_lamp_8",
			"grants_flag": "great_lamp_8",
			"requires_moves": ["sunflare"],
			"requires_flags": ["boss_the_hush_defeated"],
		},
	]


func are_all_beacons_lit() -> bool:
	var st: LxGameState = _get_state()
	if st == null:
		return false
	for bid: String in REQUIRED_BEACONS:
		if not st.lit_beacons.has(bid) and not bool(st.story_flags.get(bid, false)):
			return false
	return true


func _on_region_entered(island_id: int, region_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if region_id == "overworld":
		if st != null and not bool(st.story_flags.get("isl8_arrived", false)):
			st.story_flags["isl8_arrived"] = true
			_emit_narration("ISL8_ARRIVAL", "ominous", 4.5)
		if _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id == "sanctum_r6":
		if st != null and not st.defeated_bosses.has(BOSS_ID):
			_emit_narration("BOSS_HUSH", "title", 4.0)
			if _events != null:
				_events.music_mode_requested.emit("island8_boss_p1")
		elif st != null and st.relit_islands.has(ISLAND_ID) and _events != null:
			_events.music_mode_requested.emit("explore")
	elif region_id.begins_with("sanctum_"):
		if region_id == "sanctum_r1" and st != null and not bool(st.story_flags.get("isl8_sanctum_entered", false)):
			st.story_flags["isl8_sanctum_entered"] = true
			_emit_narration("DUNGEON_8_NAME", "title", 3.5)
		if _events != null:
			var mb_live: bool = region_id == "sanctum_r4" and st != null and not st.defeated_bosses.has(MINI_BOSS_KIND)
			_events.music_mode_requested.emit("island8_boss_p1" if mb_live else "island8_dungeon")


func _on_beacon_lit(island_id: int, beacon_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.lit_beacons.has(beacon_id):
			st.lit_beacons.append(beacon_id)
		st.story_flags[beacon_id] = true
	_emit_narration("CUE_BEACON_LIT", "title", 2.5)
	if are_all_beacons_lit():
		_trigger_seal_shatter()


func _trigger_seal_shatter() -> void:
	var st: LxGameState = _get_state()
	if st != null:
		if st.broken_seals.has(SEAL_ID):
			return
		st.broken_seals.append(SEAL_ID)
		st.story_flags["seal_broken_8"] = true
	if _events != null:
		_events.seal_broken.emit(ISLAND_ID, SEAL_ID)
		_events.sfx_requested.emit("seal_break", Vector2.ZERO, false)
		_events.shake_requested.emit(0.30)
		_emit_narration("CUE_SEAL_SHATTER", "title", 3.5)
		_emit_narration("DUNGEON_8_NAME", "narration", 3.0)
		_events.save_requested.emit("seal_broken_8")


func _on_enemy_killed(enemy: Object, kind: String, _pos: Vector2, _opened_kill: bool) -> void:
	var st: LxGameState = _get_state()
	if st == null or st.island_id != ISLAND_ID:
		return
	var eid: String = str(enemy.get("enemy_id")) if enemy != null else ""
	if kind == MINI_BOSS_KIND or eid == "mini_night_harbinger":
		if not st.defeated_bosses.has(MINI_BOSS_KIND):
			st.defeated_bosses.append(MINI_BOSS_KIND)
		st.story_flags["defeated_" + MINI_BOSS_KIND] = true
		st.story_flags[MINI_BOSS_KIND + "_defeated"] = true
		if _events != null:
			_events.sfx_requested.emit("key_drop", Vector2.ZERO, false)
			_events.music_mode_requested.emit("island8_dungeon")
			_emit_narration("CUE_BOSS_KEY_FOUND", "title", 3.0)
			_events.save_requested.emit("night_harbinger_defeated")


func _on_boss_phase_changed(boss_id: String, phase: int) -> void:
	if boss_id != BOSS_ID and boss_id != MINI_BOSS_KIND:
		return
	if phase >= 2 and _events != null:
		_events.music_mode_requested.emit("island8_boss_p2")
		_events.shake_requested.emit(0.28 if boss_id == MINI_BOSS_KIND else 0.36)
		var cue: String = "CUE_PHASE_2" if boss_id == MINI_BOSS_KIND else ("CUE_HUSH_P4" if phase >= 4 else ("CUE_HUSH_P3" if phase == 3 else "CUE_PHASE_2"))
		_emit_narration(cue, "warning", 3.2)


func _on_boss_defeated(boss_id: String, island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if boss_id == MINI_BOSS_KIND:
		if st != null:
			if not st.defeated_bosses.has(MINI_BOSS_KIND):
				st.defeated_bosses.append(MINI_BOSS_KIND)
			st.story_flags["defeated_" + MINI_BOSS_KIND] = true
			st.story_flags[MINI_BOSS_KIND + "_defeated"] = true
		return
	if boss_id != BOSS_ID:
		return
	if st != null:
		if not st.defeated_bosses.has(BOSS_ID):
			st.defeated_bosses.append(BOSS_ID)
		st.story_flags["boss_the_hush_defeated"] = true
	if _events != null:
		_events.sfx_requested.emit("boss_victory", Vector2.ZERO, false)
		_events.prompt_requested.emit("PROMPT_IGNITE", "lx_interact", 5.0)
		_events.save_requested.emit("boss_the_hush_defeated")


func _on_great_lamp_relit(island_id: int) -> void:
	if island_id != ISLAND_ID:
		return
	var st: LxGameState = _get_state()
	if st != null:
		if not st.relit_islands.has(ISLAND_ID):
			st.relit_islands.append(ISLAND_ID)
		st.story_flags["great_lamp_8"] = true
		st.story_flags["island_8_relit"] = true
	if _events != null:
		_events.sfx_requested.emit("lamp_relit", Vector2.ZERO, false)
		_emit_narration("ISL8_RELIGHT", "title", 4.0)
		_emit_narration("ISL8_BRIDGE", "narration", 4.5)
		_events.save_requested.emit("great_lamp_8")


func _emit_narration(string_id: String, style: String, duration: float) -> void:
	if _events != null and LxStrings.has_id(string_id):
		_events.narration_requested.emit(string_id, style, duration)


func _get_state() -> LxGameState:
	return _state if _state != null else Lx.state
