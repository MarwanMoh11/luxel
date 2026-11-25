class_name LxGameState
extends Node
## Complete mutable run state for Luxel 1.0, serializable for atomic save/load.

const CURRENT_VERSION: int = 2
const RUN_LOG_PATH: String = "user://luxel1/runs.log"
const RUN_LOG_MAX_BYTES: int = 65536
const HEART_CAP_OVERFLOW_SHARDS: int = 120

var version: int = CURRENT_VERSION
var slot_id: String = "1"
var island_id: int = 1
var region_id: String = "overworld"
var room_id: String = ""
var spawn_pos: Vector2 = Vector2(708.0, 366.0)
var last_waystone_island: int = 1
var last_waystone_id: String = "ws_plaza"

var max_hearts: int = 4
var _hearts: float = 4.0
var _suppress_revive: bool = false
var spare_wick_ready: bool = false
var hearts: float:
	get: return _hearts
	set(v):
		if not _suppress_revive and v <= 0.0 and _hearts > 0.0 and spare_wick_ready and is_spare_wick_allowed():
			var rev_h: float = get_effective_spare_wick_hearts()
			if rev_h > 0.0:
				spare_wick_ready = false
				_hearts = minf(float(max_hearts), rev_h)
				if Lx.events != null:
					Lx.events.player_healed.emit(_hearts)
					Lx.events.sfx_requested.emit("heart_pickup", Vector2.ZERO, false)
					Lx.events.narration_requested.emit("CUE_HEART_GAINED", "title", 2.0)
				return
		_hearts = v

var ember_pieces: int = 0
var half_lanterns: int = 0
var shards: int = 0
var room_anchor_region: String = ""
var room_anchor_pos: Vector2 = Vector2(-1.0, -1.0)

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
var world_vars: Dictionary = {}

var play_time_s: float = 0.0
var deaths: int = 0
var hits_taken: int = 0
var boss_retries: Dictionary = {}
var zone_times: Dictionary = {}


func reset_new_game(new_slot: String = "1") -> void:
	_suppress_revive = true
	version = CURRENT_VERSION; slot_id = new_slot
	island_id = 1; region_id = "overworld"; room_id = ""
	spawn_pos = Vector2(708.0, 366.0)
	last_waystone_island = 1; last_waystone_id = "ws_plaza"

	max_hearts = int(Lx.get_decision("hearts_start", 4))
	_hearts = float(max_hearts); spare_wick_ready = false
	ember_pieces = 0; half_lanterns = 0; shards = 0
	room_anchor_region = ""; room_anchor_pos = Vector2(-1.0, -1.0)

	unlocked_moves.clear()
	if Lx.data_moves.is_empty(): Lx.load_all_data()
	var moves_dict: Dictionary = Lx.data_moves.get("moves", {}) as Dictionary
	for mid: String in moves_dict.keys():
		unlocked_moves[mid] = bool((moves_dict[mid] as Dictionary).get("start_unlocked", false))
	if not unlocked_moves.has("bolt"): unlocked_moves["bolt"] = true

	upgrades.clear()
	for item: Variant in (Lx.data_upgrades.get("upgrades", []) as Array):
		if item is Dictionary: upgrades[str((item as Dictionary).get("id", ""))] = 0

	lit_waystones = ["ws_plaza"]
	lit_beacons.clear(); claimed_shrines.clear(); broken_seals.clear()
	relit_islands.clear(); defeated_bosses.clear(); collected_keys.clear()
	opened_doors.clear(); visited_regions = ["1:overworld"]
	interactable_states.clear(); story_flags.clear(); world_vars.clear()
	story_flags["lantern_picked_up"] = false
	play_time_s = 0.0; deaths = 0; hits_taken = 0
	boss_retries.clear(); zone_times.clear()
	_suppress_revive = false


func has_lantern() -> bool:
	if bool(story_flags.get("lantern_picked_up", false)) or island_id > 1 or region_id != "overworld":
		return true
	if not lit_beacons.is_empty() or not claimed_shrines.is_empty() \
			or not broken_seals.is_empty() or not relit_islands.is_empty() or not defeated_bosses.is_empty():
		return true
	for mid: String in ["dash", "throw", "prism", "beam", "wings", "lens", "sunflare"]:
		if bool(unlocked_moves.get(mid, false)): return true
	return false


func grant_lantern() -> bool:
	if bool(story_flags.get("lantern_picked_up", false)) and has_move("throw"): return false
	story_flags["lantern_picked_up"] = true
	unlocked_moves["bolt"] = true
	unlock_move("throw")
	return true


func has_move(move_id: String) -> bool: return bool(unlocked_moves.get(move_id, false))


func unlock_move(move_id: String) -> bool:
	if has_move(move_id): return false
	unlocked_moves[move_id] = true
	if Lx.events != null: Lx.events.move_unlocked.emit(move_id)
	return true


func get_highest_island() -> int:
	var best: int = clampi(island_id, 1, 8)
	for ri: int in relit_islands:
		best = maxi(best, mini(8, ri + 1))
	for vr: String in visited_regions:
		var idx: int = vr.find(":")
		if idx > 0:
			var n: int = int(vr.substr(0, idx))
			if n >= 1 and n <= 8: best = maxi(best, n)
	return best


func is_hard_mode() -> bool:
	return bool(story_flags.get("mode_hard", false)) or (Lx.save != null and bool(Lx.save.settings.get("hard_mode", false)))

func is_spare_wick_allowed() -> bool:
	return (not is_hard_mode()) or bool(Lx.get_hard_mode_preset().get("spare_wick_enabled", false))


func get_upgrade_rank(upgrade_id: String) -> int: return int(upgrades.get(upgrade_id, 0))


func get_next_rank_island(upgrade_id: String) -> int:
	var u: Dictionary = Lx.get_upgrade_data(upgrade_id)
	if u.is_empty(): return 1
	var req_isl: int = int(u.get("requires_island", 1))
	var ris: Variant = u.get("rank_islands", [])
	var r: int = get_upgrade_rank(upgrade_id)
	if ris is Array and not (ris as Array).is_empty():
		var arr: Array = ris as Array
		return maxi(req_isl, int(arr[mini(r, arr.size() - 1)]))
	return maxi(1, req_isl)


func is_upgrade_unlocked(upgrade_id: String) -> bool:
	var u: Dictionary = Lx.get_upgrade_data(upgrade_id)
	if u.is_empty(): return false
	var req: String = str(u.get("requires_move", ""))
	if not req.is_empty() and not has_move(req): return false
	var first_isl: int = int(u.get("requires_island", 1))
	var ris: Variant = u.get("rank_islands", [])
	if ris is Array and not (ris as Array).is_empty():
		first_isl = maxi(first_isl, int((ris as Array)[0]))
	return get_highest_island() >= first_isl


func is_next_rank_unlocked(upgrade_id: String) -> bool:
	return is_upgrade_unlocked(upgrade_id) and get_highest_island() >= get_next_rank_island(upgrade_id)


func can_buy_upgrade(upgrade_id: String) -> bool:
	var u: Dictionary = Lx.get_upgrade_data(upgrade_id)
	if u.is_empty() or not is_next_rank_unlocked(upgrade_id): return false
	var rank: int = get_upgrade_rank(upgrade_id)
	if rank >= int(u.get("max_rank", 0)): return false
	var costs: Array = u.get("costs", []) as Array
	return rank < costs.size() and shards >= int(costs[rank])


func buy_upgrade(upgrade_id: String) -> bool:
	if not can_buy_upgrade(upgrade_id): return false
	var u: Dictionary = Lx.get_upgrade_data(upgrade_id)
	var rank: int = get_upgrade_rank(upgrade_id)
	shards -= int((u.get("costs", []) as Array)[rank])
	upgrades[upgrade_id] = rank + 1
	if upgrade_id == "spare_wick": spare_wick_ready = true
	if Lx.events != null: Lx.events.upgrade_purchased.emit(upgrade_id, rank + 1)
	return true


func get_ware_data(ware_id: String) -> Dictionary:
	if Lx.data_upgrades.is_empty(): Lx.load_all_data()
	for item: Variant in (Lx.data_upgrades.get("wares", []) as Array):
		if item is Dictionary and str((item as Dictionary).get("id", "")) == ware_id:
			return item as Dictionary
	return {}


func get_ware_rank(ware_id: String) -> int:
	return maxi(0, int(story_flags.get("ware:" + ware_id, 0)))


func get_ware_next_island(ware_id: String) -> int:
	var w: Dictionary = get_ware_data(ware_id)
	if w.is_empty(): return 1
	var ris: Variant = w.get("rank_islands", [])
	var r: int = get_ware_rank(ware_id)
	if ris is Array and not (ris as Array).is_empty():
		var arr: Array = ris as Array
		return maxi(1, int(arr[mini(r, arr.size() - 1)]))
	return maxi(1, int(w.get("requires_island", 1)))


func get_ware_cost(ware_id: String) -> int:
	var w: Dictionary = get_ware_data(ware_id)
	if w.is_empty(): return 0
	if bool(w.get("repeatable", false)): return int(w.get("cost", 0))
	var costs: Array = w.get("costs", []) as Array
	var r: int = get_ware_rank(ware_id)
	return int(costs[r]) if r < costs.size() else 0


static func _panes_svc() -> Object:
	if Lx.panes != null:
		return Lx.panes
	var sc: Variant = load("res://luxel/player/panes/panes.gd")
	if sc is GDScript and (sc as GDScript).has_method("current"):
		return (sc as GDScript).call("current") as Object
	return null


func can_buy_ware(ware_id: String) -> String:
	var w: Dictionary = get_ware_data(ware_id)
	if w.is_empty(): return "SHOP_MAXED"
	var req_u: String = str(w.get("requires_upgrade", ""))
	if not req_u.is_empty() and get_upgrade_rank(req_u) <= 0: return "SHOP_WARE_NEED_WICK"
	var rep: bool = bool(w.get("repeatable", false))
	if not rep and get_ware_rank(ware_id) >= int(w.get("max_rank", 1)): return "SHOP_MAXED"
	if get_highest_island() < get_ware_next_island(ware_id): return "SHOP_NEED_ISL_FMT"
	var eff: String = str(w.get("effect", ""))
	var p: Object = _panes_svc()
	if eff == "lead" and p != null and int(p.call("get_max_lead")) >= 10: return "SHOP_WARE_CAP"
	if eff == "slot" and p != null and int(p.call("get_slots")) >= 5: return "SHOP_WARE_CAP"
	if eff == "pane" and _pick_unowned_pane().is_empty(): return "SHOP_WARE_NONE"
	if eff == "rearm_wick" and not is_spare_wick_allowed(): return "SHOP_HARD_NO_WICK"
	if eff == "rearm_wick" and spare_wick_ready: return "SHOP_WARE_ARMED"
	return "SHOP_NO_SHARDS" if shards < get_ware_cost(ware_id) else ""


func buy_ware(ware_id: String) -> bool:
	if not can_buy_ware(ware_id).is_empty(): return false
	var w: Dictionary = get_ware_data(ware_id)
	var cost: int = get_ware_cost(ware_id)
	var ok: bool = false
	var p: Object = _panes_svc()
	match str(w.get("effect", "")):
		"lead": ok = p != null and bool(p.call("add_lead", 1))
		"slot": ok = p != null and bool(p.call("add_slot"))
		"pane":
			var pid: String = _pick_unowned_pane()
			ok = p != null and (not pid.is_empty()) and bool(p.call("grant_pane", pid))
		"rearm_wick": ok = rearm_spare_wick()
	if not ok: return false
	shards -= cost
	if not bool(w.get("repeatable", false)):
		story_flags["ware:" + ware_id] = get_ware_rank(ware_id) + 1
	if Lx.events != null: Lx.events.upgrade_purchased.emit(ware_id, get_ware_rank(ware_id))
	return true


func rearm_spare_wick() -> bool:
	if get_upgrade_rank("spare_wick") <= 0 or spare_wick_ready or not is_spare_wick_allowed(): return false
	spare_wick_ready = true; return true


func add_shards(amount: int) -> void:
	shards = maxi(0, shards + amount)
	if Lx.events != null: Lx.events.shard_collected.emit(amount)


func _pick_unowned_pane() -> String:
	var p: Object = _panes_svc()
	if p == null: return ""
	var all_p: Dictionary = LxFolkData.panes()
	var fallback: String = ""
	var keys: Array = all_p.keys(); keys.sort()
	for kv: Variant in keys:
		var pid: String = str(kv)
		if bool(p.call("has_pane", pid)): continue
		if int((all_p[kv] as Dictionary).get("island", 0)) == island_id: return pid
		if fallback.is_empty(): fallback = pid
	return fallback


func _grant_heart_or_overflow() -> bool:
	var max_cap: int = int(Lx.get_decision("hearts_max", 12))
	if max_hearts < max_cap:
		max_hearts += 1; _hearts = float(max_hearts)
		if Lx.events != null:
			Lx.events.narration_requested.emit("CUE_HEART_GAINED", "title", 3.0)
			Lx.events.sfx_requested.emit("heart_pickup", Vector2.ZERO, false)
		return true
	heal_full()
	var p: Object = _panes_svc()
	var overflow_done: bool = p != null and bool(p.call("add_lead", 1))
	if not overflow_done and p != null:
		var pid: String = _pick_unowned_pane()
		overflow_done = (not pid.is_empty()) and bool(p.call("grant_pane", pid))
	if not overflow_done:
		add_shards(int(Lx.get_decision("heart_overflow_shards", HEART_CAP_OVERFLOW_SHARDS)))
	if Lx.events != null: Lx.events.sfx_requested.emit("shard_pickup", Vector2.ZERO, false)
	return false


func add_ember_piece() -> bool:
	ember_pieces += 1
	var per_heart: int = maxi(1, int(Lx.get_decision("ember_pieces_per_heart", 8)))
	var gained: bool = _grant_heart_or_overflow() if (ember_pieces % per_heart == 0) else false
	if Lx.events != null: Lx.events.ember_piece_collected.emit(ember_pieces)
	return gained


func add_boss_heart() -> void:
	if max_hearts < int(Lx.get_decision("boss_heart_full_below", 5)):
		_grant_heart_or_overflow(); return
	var pieces: int = maxi(1, int(Lx.get_decision("boss_heart_pieces", 3)))
	var per_heart: int = maxi(1, int(Lx.get_decision("half_lanterns_per_heart", 8)))
	half_lanterns += pieces
	var completed: bool = false
	while half_lanterns >= per_heart:
		half_lanterns -= per_heart; _grant_heart_or_overflow(); completed = true
	if not completed and Lx.events != null:
		var cue: String = "CUE_HALF_LANTERN" if LxStrings.has_id("CUE_HALF_LANTERN") else "CUE_EMBER_FOUND"
		Lx.events.narration_requested.emit(cue, "title", 2.6)
		Lx.events.sfx_requested.emit("ember_pickup", Vector2.ZERO, false)


func add_half_lantern() -> bool:
	half_lanterns += 1
	var per_heart: int = maxi(1, int(Lx.get_decision("half_lanterns_per_heart", 8)))
	if half_lanterns >= per_heart:
		half_lanterns -= per_heart; _grant_heart_or_overflow(); return true
	if Lx.events != null:
		var cue: String = "CUE_HALF_LANTERN" if LxStrings.has_id("CUE_HALF_LANTERN") else "CUE_EMBER_FOUND"
		Lx.events.narration_requested.emit(cue, "title", 2.6)
		Lx.events.sfx_requested.emit("ember_pickup", Vector2.ZERO, false)
	return false


func heal_full() -> void:
	if is_hard_mode() and _hearts > 0.0:
		var cap_h: float = maxf(3.0, ceilf(float(max_hearts) * clampf(float(Lx.get_hard_mode_preset().get("heal_cap_ratio", 0.75)), 0.25, 1.0) * 2.0) * 0.5)
		_hearts = maxf(_hearts, minf(float(max_hearts), cap_h))
	else: _hearts = float(max_hearts)
	if get_upgrade_rank("spare_wick") > 0 and is_spare_wick_allowed(): spare_wick_ready = true
	if Lx.events != null: Lx.events.player_healed.emit(_hearts)


func get_effective_bolt_damage() -> float: return _upgrade_val("bolt_damage", float(Lx.get_move_data("bolt").get("damage", 0.35)))
func get_effective_bolt_cooldown() -> float: return _upgrade_val("bolt_rate", float(Lx.get_move_data("bolt").get("cooldown", 0.18)))
func get_effective_throw_damage() -> float: return _upgrade_val("throw_damage", float(Lx.get_move_data("throw").get("throw_damage", 2.0)))
func get_effective_throw_hang() -> float: return _upgrade_val("throw_hang", float(Lx.get_move_data("throw").get("hang_time", 4.5)))
func get_effective_zip_radius() -> float: return _upgrade_val("zip_bomb", float(Lx.get_move_data("throw").get("zip_burst_radius", 24.0)))
func get_effective_zip_damage() -> float: return _upgrade_field("zip_bomb", "dmg_values", float(Lx.get_move_data("throw").get("zip_damage", 1.75)))
func get_effective_dash_cooldown() -> float: return _upgrade_val("dash_cooldown", float(Lx.get_move_data("dash").get("cooldown", 0.55)))
func get_effective_dash_charges() -> int: return maxi(1, roundi(_upgrade_val("dash_charges", 1.0)))
func get_effective_ember_max() -> float: return _upgrade_val("ember_meter", float(Lx.get_move_data("sunflare").get("ember_max", 100.0)))
func get_effective_prism_bounces() -> int: return int(_upgrade_val("prism_bounce", float(int(Lx.get_move_data("prism").get("bounces", 1)))))
func get_effective_prism_damage_mult() -> float: return _upgrade_field("prism_bounce", "mult_values", float(Lx.get_move_data("prism").get("damage_mult", 1.30)))
func get_effective_beam_charge() -> float: return _upgrade_val("beam_charge", float(Lx.get_move_data("beam").get("charge_time", 0.6)))
func get_effective_beam_width() -> float: return _upgrade_val("beam_width", float(Lx.get_move_data("beam").get("width", 6.0)))
func get_effective_beam_damage() -> float: return _upgrade_field("beam_width", "dmg_values", float(Lx.get_move_data("beam").get("damage", 2.5)))
func get_effective_wings_glide() -> float: return _upgrade_val("wings_glide", float(Lx.get_move_data("wings").get("glide_max_px", 96.0)))
func get_effective_lens_duration() -> float: return _upgrade_val("lens_duration", float(Lx.get_move_data("lens").get("duration", 4.0)))
func get_effective_lens_radius() -> float: return _upgrade_val("lens_radius", float(Lx.get_move_data("lens").get("pulse_radius", 104.0)))
func get_effective_lens_hung_radius() -> float: return _upgrade_field("lens_radius", "hung_values", float(Lx.get_move_data("lens").get("hung_radius", 78.0)))
func get_effective_pickup_scale() -> float: return _upgrade_val("pickup_radius", 1.0)
func get_effective_pickup_radius() -> float: return 24.0 * get_effective_pickup_scale()
func get_effective_lure_radius() -> float: return float(Lx.get_move_data("throw").get("lure_radius", 135.0)) * get_effective_pickup_scale()
func get_effective_spare_wick_hearts() -> float: return _upgrade_val("spare_wick", 0.0)


func get_upgrade_totals() -> Vector2i:
	var owned: int = 0; var total: int = 0
	if Lx.data_upgrades.is_empty(): Lx.load_all_data()
	for item: Variant in (Lx.data_upgrades.get("upgrades", []) as Array):
		if item is Dictionary:
			var ud: Dictionary = item as Dictionary
			var mr: int = int(ud.get("max_rank", 0))
			total += mr; owned += mini(get_upgrade_rank(str(ud.get("id", ""))), mr)
	return Vector2i(owned, total)


func get_harmony_count() -> int:
	var count: int = 0
	for isl: int in range(1, 9):
		if bool(story_flags.get("disc_all_%d" % isl, false)): count += 1
	return count


func get_completion_pct(relit_override: int = -1, embers_override: int = -1) -> int:
	var relit_n: int = clampi(relit_override if relit_override >= 0 else relit_islands.size(), 0, 8)
	var ember_n: int = clampi(embers_override if embers_override >= 0 else ember_pieces, 0, 52)
	var moves_n: int = 0
	for mid: String in ["dash", "throw", "prism", "beam", "wings", "lens", "sunflare"]:
		if has_move(mid): moves_n += 1
	var upg_t: Vector2i = get_upgrade_totals()
	var base_score: float = (float(relit_n) / 8.0) * 40.0 + (float(moves_n) / 7.0) * 14.0 \
		+ (float(ember_n) / 52.0) * 16.0 + (float(get_harmony_count()) / 8.0) * 16.0 \
		+ (float(upg_t.x) / float(maxi(1, upg_t.y))) * 14.0
	var extra_pts: float = 0.0; var extra_max: float = 0.0
	if Lx.packs != null:
		var side_total: int = 0; var side_done: int = 0
		for d: Dictionary in Lx.packs.all_dungeons():
			if bool(d.get("builtin", false)) or bool(d.get("debug_only", false)): continue
			side_total += 1
			if bool(story_flags.get(str(d.get("done_flag", "dungeon_done:" + str(d.get("id", "")))), false)) or bool(story_flags.get("dungeon_done:" + str(d.get("id", "")), false)): side_done += 1
		if side_total > 0: extra_max += 12.0; extra_pts += (float(side_done) / float(side_total)) * 12.0
		var moths_d: Dictionary = Lx.packs.moths()
		if not moths_d.is_empty():
			var mdone: int = 0
			for mk: Variant in moths_d.keys():
				if bool(story_flags.get("moth:" + str(mk), false)) or bool(story_flags.get("moth_found:" + str(mk), false)): mdone += 1
			extra_max += 6.0; extra_pts += (float(mdone) / float(moths_d.size())) * 6.0
		var panes_d: Dictionary = Lx.packs.panes()
		if not panes_d.is_empty() and Lx.panes != null and Lx.panes.has_method("owned_ids"):
			var owned: PackedStringArray = Lx.panes.call("owned_ids") as PackedStringArray
			extra_max += 6.0; extra_pts += clampf(float(owned.size()) / float(panes_d.size()), 0.0, 1.0) * 6.0
	var tot: float = base_score + extra_pts; var mx: float = 100.0 + extra_max
	if tot >= mx - 0.0001: return 100
	return clampi(mini(99, roundi((tot / mx) * 100.0)), 0, 99)


func _upgrade_val(upgrade_id: String, base: float) -> float: return _upgrade_field(upgrade_id, "values", base)


func _upgrade_field(upgrade_id: String, field: String, base: float) -> float:
	var rank: int = get_upgrade_rank(upgrade_id)
	if rank <= 0: return base
	var vals: Array = Lx.get_upgrade_data(upgrade_id).get(field, []) as Array
	var idx: int = mini(rank - 1, vals.size() - 1)
	return float(vals[idx]) if idx >= 0 else base


func mark_region_visited(isl: int, reg: String) -> void:
	var key: String = "%d:%s" % [isl, reg]
	if not visited_regions.has(key): visited_regions.append(key)

func add_key(dungeon_id: String, key_kind: String = "wick_key", count: int = 1) -> void:
	var key: String = "%s:%s" % [dungeon_id, key_kind]
	collected_keys[key] = int(collected_keys.get(key, 0)) + count

func get_key_count(dungeon_id: String, key_kind: String = "wick_key") -> int:
	return int(collected_keys.get("%s:%s" % [dungeon_id, key_kind], 0))

func consume_key(dungeon_id: String, key_kind: String = "wick_key") -> bool:
	var cur: int = get_key_count(dungeon_id, key_kind)
	if cur <= 0: return false
	collected_keys["%s:%s" % [dungeon_id, key_kind]] = cur - 1
	return true

func record_zone_time(zone_key: String, dt: float) -> void:
	zone_times[zone_key] = float(zone_times.get(zone_key, 0.0)) + dt


func append_run_log(line: String) -> void:
	var tag: String = line.strip_edges().to_lower()
	if tag in ["void", "void_death", "void_fall"]:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUN_LOG_PATH.get_base_dir()))
	var entry: String = "%s | slot=%s | isl=%d | reg=%s | t=%.1f | d=%d | h=%d | %s\n" % [
		Time.get_datetime_string_from_system(), slot_id, island_id, region_id, play_time_s, deaths, hits_taken, line
	]
	if FileAccess.file_exists(RUN_LOG_PATH):
		var fr: FileAccess = FileAccess.open(RUN_LOG_PATH, FileAccess.READ)
		if fr != null:
			var sz: int = fr.get_length()
			if sz + entry.length() > RUN_LOG_MAX_BYTES:
				var keep: int = mini(sz, RUN_LOG_MAX_BYTES / 2)
				fr.seek(maxi(0, sz - keep))
				var tail: String = fr.get_as_text()
				fr.close()
				var nl: int = tail.find("\n")
				if nl >= 0 and nl + 1 < tail.length():
					tail = tail.substr(nl + 1)
				var fw: FileAccess = FileAccess.open(RUN_LOG_PATH, FileAccess.WRITE)
				if fw != null:
					fw.store_string(tail + entry)
					fw.close()
				return
			fr.close()
	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(RUN_LOG_PATH) else FileAccess.WRITE
	var f: FileAccess = FileAccess.open(RUN_LOG_PATH, mode)
	if f == null: return
	f.seek_end()
	f.store_string(entry)
	f.close()


func to_dict() -> Dictionary:
	return {
		"version": version, "slot_id": slot_id, "island_id": island_id, "region_id": region_id,
		"room_id": room_id, "spawn_pos": [spawn_pos.x, spawn_pos.y],
		"room_anchor_region": room_anchor_region, "room_anchor_pos": [room_anchor_pos.x, room_anchor_pos.y],
		"last_waystone_island": last_waystone_island, "last_waystone_id": last_waystone_id,
		"max_hearts": max_hearts, "hearts": _hearts, "spare_wick_ready": spare_wick_ready,
		"ember_pieces": ember_pieces, "half_lanterns": half_lanterns, "shards": shards,
		"unlocked_moves": unlocked_moves.duplicate(true), "upgrades": upgrades.duplicate(true),
		"lit_waystones": lit_waystones.duplicate(), "lit_beacons": lit_beacons.duplicate(),
		"claimed_shrines": claimed_shrines.duplicate(), "broken_seals": broken_seals.duplicate(),
		"relit_islands": relit_islands.duplicate(), "defeated_bosses": defeated_bosses.duplicate(),
		"collected_keys": collected_keys.duplicate(true), "opened_doors": opened_doors.duplicate(),
		"visited_regions": visited_regions.duplicate(), "interactable_states": interactable_states.duplicate(true),
		"story_flags": story_flags.duplicate(true), "world_vars": world_vars.duplicate(true),
		"play_time_s": play_time_s, "deaths": deaths, "hits_taken": hits_taken,
		"boss_retries": boss_retries.duplicate(true), "zone_times": zone_times.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	reset_new_game(str(d.get("slot_id", "1")))
	_suppress_revive = true
	version = int(d.get("version", CURRENT_VERSION))
	island_id = int(d.get("island_id", 1)); region_id = str(d.get("region_id", "overworld"))
	room_id = str(d.get("room_id", ""))
	var sp: Variant = d.get("spawn_pos", [708.0, 366.0])
	if sp is Array and (sp as Array).size() >= 2: spawn_pos = Vector2(float((sp as Array)[0]), float((sp as Array)[1]))
	room_anchor_region = str(d.get("room_anchor_region", ""))
	var ra: Variant = d.get("room_anchor_pos", [-1.0, -1.0])
	if ra is Array and (ra as Array).size() >= 2: room_anchor_pos = Vector2(float((ra as Array)[0]), float((ra as Array)[1]))
	last_waystone_island = int(d.get("last_waystone_island", 1)); last_waystone_id = str(d.get("last_waystone_id", "ws_plaza"))
	max_hearts = clampi(int(d.get("max_hearts", 4)), 4, 12)
	var raw_hearts: float = float(d.get("hearts", float(max_hearts)))
	_hearts = float(max_hearts) if raw_hearts <= 0.0 else minf(raw_hearts, float(max_hearts))
	ember_pieces = maxi(0, int(d.get("ember_pieces", 0)))
	half_lanterns = maxi(0, int(d.get("half_lanterns", 0)))
	shards = maxi(0, int(d.get("shards", 0)))

	var um: Variant = d.get("unlocked_moves", {})
	if um is Dictionary:
		for k: String in (um as Dictionary).keys(): unlocked_moves[k] = bool((um as Dictionary)[k])
	var up: Variant = d.get("upgrades", {})
	if up is Dictionary:
		for k: String in (up as Dictionary).keys(): upgrades[k] = int((up as Dictionary)[k])
	spare_wick_ready = bool(d.get("spare_wick_ready", get_upgrade_rank("spare_wick") > 0))

	lit_waystones = _to_unique_str_array(d.get("lit_waystones", ["ws_plaza"]))
	lit_beacons = _to_str_array(d.get("lit_beacons", []))
	claimed_shrines = _to_str_array(d.get("claimed_shrines", []))
	broken_seals = _to_str_array(d.get("broken_seals", []))
	relit_islands = _to_int_array(d.get("relit_islands", []))
	defeated_bosses = _to_str_array(d.get("defeated_bosses", []))
	opened_doors = _to_str_array(d.get("opened_doors", []))
	visited_regions = _to_str_array(d.get("visited_regions", ["1:overworld"]))

	var ck: Variant = d.get("collected_keys", {})
	if ck is Dictionary: collected_keys = (ck as Dictionary).duplicate(true)
	var is_d: Variant = d.get("interactable_states", {})
	if is_d is Dictionary: interactable_states = (is_d as Dictionary).duplicate(true)
	var sf: Variant = d.get("story_flags", {})
	if sf is Dictionary: story_flags = (sf as Dictionary).duplicate(true)
	var wv: Variant = d.get("world_vars", {})
	world_vars = (wv as Dictionary).duplicate(true) if wv is Dictionary else {}
	var br: Variant = d.get("boss_retries", {})
	if br is Dictionary: boss_retries = (br as Dictionary).duplicate(true)
	var zt: Variant = d.get("zone_times", {})
	if zt is Dictionary: zone_times = (zt as Dictionary).duplicate(true)

	play_time_s = maxf(0.0, float(d.get("play_time_s", 0.0)))
	deaths = maxi(0, int(d.get("deaths", 0)))
	hits_taken = maxi(0, int(d.get("hits_taken", 0)))
	_suppress_revive = false


static func _to_str_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for item: Variant in v: out.append(str(item))
	return out
static func _to_unique_str_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for item: Variant in v:
			var s: String = str(item)
			if not s.is_empty() and not out.has(s): out.append(s)
	return out
static func _to_int_array(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for item: Variant in v: out.append(int(item))
	return out
