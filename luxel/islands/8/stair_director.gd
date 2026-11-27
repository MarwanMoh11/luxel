class_name LxStairDirector
extends RefCounted
## Island 8 Endless Stair (Dungeon C) Director:
## - Seeded 12-template room pool selector across 3 tiers (F1-4, F5-8, F9-12)
##   with anti-repeat memory so floors stay varied over two+ full climbs.
## - Full 18-boon draft catalog (6 Wick, 6 Lantern, 6 Toll including Legendary
##   boon_crowned_toll) wired to LxStairBoonRuntime for live visible play changes.
## - Express Lifts (`stair_lift_f4`, `stair_lift_f8`, `stair_lift_f12`) with
##   combat-death return to the last unlocked lift (never back to the start).
## - Iron Ascent score multiplier (`+0.15x` per sold setting, saved best).
## - Auto-clears `dungeon:stair` (`stair_boons`, `stair_floor`) on leaving Endless Stair.

const BoonRuntimeScript := preload("res://luxel/islands/8/stair/stair_boon_fx.gd")

signal floor_started(floor_num: int, template: Dictionary)
signal boon_drafted(boon_id: String, boon_meta: Dictionary)
signal lift_unlocked(floor_num: int, flag_name: String)
signal run_ended(score_info: Dictionary)

const SCOPE_STAIR: String = "dungeon:stair"
const VAR_FLOOR: String = "stair_floor"
const VAR_BOONS: String = "stair_boons"
const VAR_SEED: String = "stair_seed"
const VAR_LAYER: String = "stair_layer"
const LIFT_FLOORS: Array[int] = [4, 8, 12]
const MAX_FLOORS: int = 12

const LIFT_CHECKPOINTS: Dictionary = {
	4: {"region": "stair_r4", "pos": Vector2(224.0, 264.0)},
	8: {"region": "stair_r8", "pos": Vector2(240.0, 264.0)},
	12: {"region": "stair_r10", "pos": Vector2(256.0, 288.0)},
}

const REGION_FLOOR_MAP: Dictionary = {
	"stair_r1": 1,
	"stair_r2": 1,
	"stair_r3": 3,
	"stair_r4": 4,
	"stair_r5": 5,
	"stair_r6": 7,
	"stair_r7": 7,
	"stair_r8": 8,
	"stair_r9": 9,
	"stair_r10": 12,
}

const ROOM_TEMPLATES: Array[Dictionary] = [
	{"id": "t1_nave", "tier": 1, "kind": "combat", "pool_layer": "stair_a1", "enemies": 3},
	{"id": "t1_mirrors", "tier": 1, "kind": "prism", "pool_layer": "stair_a2", "enemies": 3},
	{"id": "t1_hooks", "tier": 1, "kind": "traversal", "pool_layer": "stair_a3", "enemies": 3},
	{"id": "t1_ledger", "tier": 1, "kind": "toll", "pool_layer": "stair_a4", "enemies": 3},
	{"id": "t2_tides", "tier": 2, "kind": "gravity", "pool_layer": "stair_b1", "enemies": 4},
	{"id": "t2_winds", "tier": 2, "kind": "shadow", "pool_layer": "stair_b2", "enemies": 4},
	{"id": "t2_shadows", "tier": 2, "kind": "echo", "pool_layer": "stair_b3", "enemies": 4},
	{"id": "t2_kiln", "tier": 2, "kind": "heat", "pool_layer": "stair_b4", "enemies": 3},
	{"id": "t3_eclipse", "tier": 3, "kind": "combat", "pool_layer": "stair_c1", "enemies": 5},
	{"id": "t3_chasm", "tier": 3, "kind": "wings", "pool_layer": "stair_c2", "enemies": 5},
	{"id": "t3_plinths", "tier": 3, "kind": "prism", "pool_layer": "stair_c3", "enemies": 5},
	{"id": "t3_crown", "tier": 3, "kind": "gauntlet", "pool_layer": "stair_c4", "enemies": 5},
]

const BOON_CATALOG: Array[Dictionary] = [
	# 6 Wick Boons
	{"id": "boon_twin_spark", "group": "WICK", "rarity": "common", "name_key": "ISL8_BOON_TWIN_SPARK", "desc_key": "ISL8_BOOND_TWIN_SPARK"},
	{"id": "boon_glass_edge", "group": "WICK", "rarity": "common", "name_key": "ISL8_BOON_GLASS_EDGE", "desc_key": "ISL8_BOOND_GLASS_EDGE"},
	{"id": "boon_ember_sip", "group": "WICK", "rarity": "common", "name_key": "ISL8_BOON_EMBER_SIP", "desc_key": "ISL8_BOOND_EMBER_SIP"},
	{"id": "boon_quick_step", "group": "WICK", "rarity": "common", "name_key": "ISL8_BOON_QUICK_STEP", "desc_key": "ISL8_BOOND_QUICK_STEP"},
	{"id": "boon_prism_arc", "group": "WICK", "rarity": "common", "name_key": "ISL8_BOON_PRISM_ARC", "desc_key": "ISL8_BOOND_PRISM_ARC"},
	{"id": "boon_last_breath", "group": "WICK", "rarity": "rare", "name_key": "ISL8_BOON_LAST_BREATH", "desc_key": "ISL8_BOOND_LAST_BREATH"},
	# 6 Lantern Boons
	{"id": "boon_long_throw", "group": "LANTERN", "rarity": "common", "name_key": "ISL8_BOON_LONG_THROW", "desc_key": "ISL8_BOOND_LONG_THROW"},
	{"id": "boon_magnet_catch", "group": "LANTERN", "rarity": "common", "name_key": "ISL8_BOON_MAGNET_CATCH", "desc_key": "ISL8_BOOND_MAGNET_CATCH"},
	{"id": "boon_wide_lens", "group": "LANTERN", "rarity": "common", "name_key": "ISL8_BOON_WIDE_LENS", "desc_key": "ISL8_BOOND_WIDE_LENS"},
	{"id": "boon_hot_hook", "group": "LANTERN", "rarity": "common", "name_key": "ISL8_BOON_HOT_HOOK", "desc_key": "ISL8_BOOND_HOT_HOOK"},
	{"id": "boon_sun_echo", "group": "LANTERN", "rarity": "rare", "name_key": "ISL8_BOON_SUN_ECHO", "desc_key": "ISL8_BOOND_SUN_ECHO"},
	{"id": "boon_zip_shield", "group": "LANTERN", "rarity": "rare", "name_key": "ISL8_BOON_ZIP_SHIELD", "desc_key": "ISL8_BOOND_ZIP_SHIELD"},
	# 6 Toll Boons
	{"id": "boon_heavy_ledger", "group": "TOLL", "rarity": "common", "name_key": "ISL8_BOON_HEAVY_LEDGER", "desc_key": "ISL8_BOOND_HEAVY_LEDGER"},
	{"id": "boon_borrow_heart", "group": "TOLL", "rarity": "common", "name_key": "ISL8_BOON_BORROW_HEART", "desc_key": "ISL8_BOOND_BORROW_HEART"},
	{"id": "boon_silent_blade", "group": "TOLL", "rarity": "common", "name_key": "ISL8_BOON_SILENT_BLADE", "desc_key": "ISL8_BOOND_SILENT_BLADE"},
	{"id": "boon_grey_crit", "group": "TOLL", "rarity": "common", "name_key": "ISL8_BOON_GREY_CRIT", "desc_key": "ISL8_BOOND_GREY_CRIT"},
	{"id": "boon_frame_blink", "group": "TOLL", "rarity": "rare", "name_key": "ISL8_BOON_FRAME_BLINK", "desc_key": "ISL8_BOOND_FRAME_BLINK"},
	{"id": "boon_crowned_toll", "group": "TOLL", "rarity": "legendary", "name_key": "ISL8_BOON_CROWNED_TOLL", "desc_key": "ISL8_BOOND_CROWNED_TOLL"},
]

var _rng := RandomNumberGenerator.new()
var _seed: int = 8080
var _floor: int = 0
var _boons: Array[String] = []
var _last_template_id: String = ""
var _in_stair: bool = false
var _last_breath_used: bool = false
var _run_deaths: int = 0
var _climb_count: int = 0
var _iron_ascent_active: bool = false
var _used_layers_this_climb: Array[String] = []
var _cur_climb_picks: Dictionary = {} # slot_key -> pool_layer
var _prev_climb_picks: Dictionary = {} # slot_key -> pool_layer from previous climb
var _pending_lift_return: bool = false
var _runtime: Node2D = null
var _death_bound: bool = false


func start_run(seed_val: int = 0, start_floor: int = 1) -> void:
	if not _cur_climb_picks.is_empty():
		_prev_climb_picks = _cur_climb_picks.duplicate()
	_cur_climb_picks.clear()
	_used_layers_this_climb.clear()
	_climb_count += 1
	if Lx.state != null:
		Lx.state.story_flags["stair_climb_count"] = _climb_count
	if seed_val != 0:
		_seed = seed_val
	else:
		var prev_seed: int = _seed
		var raw_s: int = (int(Time.get_ticks_usec()) ^ (_climb_count * 2654435761)) & 0x7FFFFFFF
		if raw_s == 0 or raw_s == prev_seed:
			raw_s = ((prev_seed * 1103515245 + 12345 + _climb_count * 7919) & 0x7FFFFFFF)
		_seed = maxi(1, raw_s)
	_rng.seed = _seed
	_floor = clampi(start_floor, 1, MAX_FLOORS)
	_boons.clear()
	_last_template_id = ""
	_last_breath_used = false
	_run_deaths = 0
	_pending_lift_return = false
	_in_stair = true
	_write_vars()
	_ensure_runtime()


func start_new_climb(iron_ascent: bool = false, seed_val: int = 0) -> void:
	_iron_ascent_active = iron_ascent
	# Allow re-fighting Tier 1 & Tier 2 Stair Wardens on a fresh Iron Ascent climb
	if Lx.state != null:
		Lx.state.defeated_bosses.erase("stair_warden_f4")
		Lx.state.defeated_bosses.erase("stair_warden_f8")
		if iron_ascent:
			Lx.state.defeated_bosses.erase("stair_warden")
	start_run(seed_val, 1)


func is_iron_ascent() -> bool:
	return _iron_ascent_active


func get_climb_count() -> int:
	return _climb_count


func get_seed() -> int:
	return _seed


func get_floor() -> int:
	return _floor


func get_run_deaths() -> int:
	return _run_deaths


func get_boons() -> PackedStringArray:
	return PackedStringArray(_boons)


func has_boon(boon_id: String) -> bool:
	return _boons.has(boon_id.strip_edges().to_lower())


func is_in_stair() -> bool:
	return _in_stair


func is_last_breath_armed() -> bool:
	return has_boon("boon_last_breath") and not _last_breath_used


func get_boon_meta(boon_id: String) -> Dictionary:
	var key: String = boon_id.strip_edges().to_lower()
	for b: Dictionary in BOON_CATALOG:
		if str(b.get("id", "")) == key:
			return b.duplicate(true)
	return {}


func pick_floor_template(floor_num: int, pool_layers: Array = [], seed_override: int = 0) -> Dictionary:
	var explicit_seed: bool = seed_override != 0
	if explicit_seed:
		_seed = seed_override
		_rng.seed = _seed ^ (floor_num * 7919)
	else:
		_rng.seed = _seed ^ (floor_num * 7919) ^ (_climb_count * 104729)
	_floor = clampi(floor_num, 1, MAX_FLOORS)
	var tier: int = 1 if _floor <= 4 else (2 if _floor <= 8 else 3)
	var cands: Array[Dictionary] = []
	var slot_parts: PackedStringArray = PackedStringArray()
	if not pool_layers.is_empty():
		var allowed: Array[String] = []
		for pl: Variant in pool_layers:
			var pls: String = str(pl)
			allowed.append(pls)
			slot_parts.append(pls)
		for t: Dictionary in ROOM_TEMPLATES:
			if allowed.has(str(t.get("pool_layer", ""))):
				cands.append(t)
	if cands.is_empty():
		for t: Dictionary in ROOM_TEMPLATES:
			if int(t.get("tier", 1)) == tier:
				cands.append(t)
	if cands.is_empty():
		cands.append(ROOM_TEMPLATES[0])

	var slot_key: String = ",".join(slot_parts) if not slot_parts.is_empty() else "tier:%d" % tier
	var prev_layer: String = str(_prev_climb_picks.get(slot_key, ""))

	# 1) Avoid repeating exact same template twice in a row.
	var filtered: Array[Dictionary] = []
	for t: Dictionary in cands:
		if str(t.get("id", "")) != _last_template_id:
			filtered.append(t)
	if not filtered.is_empty():
		cands = filtered

	# 2) Across unseeded climbs, avoid layers already used this climb AND the
	#    previous climb's exact pick for this slot so 2 full climbs stay varied.
	if not explicit_seed:
		var fresh_climb: Array[Dictionary] = []
		for t: Dictionary in cands:
			var pl_s: String = str(t.get("pool_layer", ""))
			if not _used_layers_this_climb.has(pl_s):
				fresh_climb.append(t)
		if not fresh_climb.is_empty():
			cands = fresh_climb
		if not prev_layer.is_empty():
			var diff_prev: Array[Dictionary] = []
			for t: Dictionary in cands:
				if str(t.get("pool_layer", "")) != prev_layer:
					diff_prev.append(t)
			if not diff_prev.is_empty():
				cands = diff_prev

	var pick: Dictionary = cands[_rng.randi() % cands.size()].duplicate(true)
	if not pool_layers.is_empty() and not _has_template_for_layer(str(pick.get("pool_layer", "")), pool_layers):
		pick["pool_layer"] = str(pool_layers[_rng.randi() % pool_layers.size()])
	var chosen_layer: String = str(pick.get("pool_layer", ""))
	_last_template_id = str(pick.get("id", ""))
	if not chosen_layer.is_empty():
		if not _used_layers_this_climb.has(chosen_layer):
			_used_layers_this_climb.append(chosen_layer)
		_cur_climb_picks[slot_key] = chosen_layer
	_in_stair = true
	_write_vars()
	if Lx.vars != null and not chosen_layer.is_empty():
		Lx.vars.set_var(SCOPE_STAIR, VAR_LAYER, chosen_layer)
	floor_started.emit(_floor, pick)
	return pick


func roll_boon_draft(count: int = 3, include_legendary: bool = false, seed_override: int = 0) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	var s: int = seed_override if seed_override != 0 else (_seed ^ (_floor * 104729 + _boons.size() * 31 + 17))
	rng.seed = s
	var pool: Array[Dictionary] = []
	for b: Dictionary in BOON_CATALOG:
		var bid: String = str(b.get("id", ""))
		if _boons.has(bid):
			continue
		if str(b.get("rarity", "common")) == "legendary" and not include_legendary:
			continue
		pool.append(b.duplicate(true))
	var out: Array[Dictionary] = []
	var want: int = clampi(count, 1, pool.size())
	for _i: int in range(want):
		var idx: int = rng.randi() % pool.size()
		out.append(pool[idx])
		pool.remove_at(idx)
	return out


func grant_boon(boon_id: String) -> bool:
	var key: String = boon_id.strip_edges().to_lower()
	var meta: Dictionary = get_boon_meta(key)
	if meta.is_empty() or _boons.has(key):
		return false
	_boons.append(key)
	_apply_boon_immediate(key)
	_write_vars()
	_ensure_runtime()
	if _runtime != null and is_instance_valid(_runtime) and _runtime.has_method("on_boon_granted"):
		_runtime.call("on_boon_granted", key, meta)
	boon_drafted.emit(key, meta)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("boon_draft", Vector2.ZERO, false)
	return true


func complete_floor(floor_num: int = -1) -> Dictionary:
	var f: int = floor_num if floor_num > 0 else maxi(1, _floor)
	_floor = clampi(f, 1, MAX_FLOORS)
	_pending_lift_return = false
	if LIFT_FLOORS.has(_floor):
		unlock_lift(_floor)
	var score_info: Dictionary = compute_score(_floor, LxSold.current().get_sold_count(), _run_deaths)
	_save_best_score(score_info)
	_write_vars()
	return score_info


func unlock_lift(floor_num: int) -> bool:
	if not LIFT_FLOORS.has(floor_num):
		return false
	var flag: String = "stair_lift_f%d" % floor_num
	if Lx.state != null:
		Lx.state.story_flags[flag] = true
	lift_unlocked.emit(floor_num, flag)
	return true


func is_lift_unlocked(floor_num: int) -> bool:
	if not LIFT_FLOORS.has(floor_num) or Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get("stair_lift_f%d" % floor_num, false))


func get_unlocked_lifts() -> Array[int]:
	var out: Array[int] = []
	for f: int in LIFT_FLOORS:
		if is_lift_unlocked(f):
			out.append(f)
	return out


func get_last_lift_floor(for_floor: int = -1) -> int:
	var f: int = for_floor if for_floor > 0 else maxi(1, _floor)
	if f >= 9 and is_lift_unlocked(8):
		return 8
	if f >= 5 and is_lift_unlocked(4):
		return 4
	if f >= 12 and is_lift_unlocked(12):
		return 12
	return 0


func get_last_lift_checkpoint(for_floor: int = -1) -> Dictionary:
	var lf: int = get_last_lift_floor(for_floor)
	if lf <= 0 or not LIFT_CHECKPOINTS.has(lf):
		return {}
	var base: Dictionary = (LIFT_CHECKPOINTS[lf] as Dictionary).duplicate()
	base["floor"] = lf
	return base


func warp_to_lift(floor_num: int, seed_val: int = 0) -> bool:
	if not is_lift_unlocked(floor_num):
		return false
	_pending_lift_return = false
	if _boons.is_empty():
		start_run(seed_val if seed_val != 0 else _seed, floor_num)
	else:
		_floor = clampi(floor_num, 1, MAX_FLOORS)
		_in_stair = true
		_write_vars()
		_ensure_runtime()
	return true


func compute_score(floors_cleared: int, sold_count: int, deaths: int = 0) -> Dictionary:
	var base_pts: int = maxi(0, floors_cleared) * 100 + _boons.size() * 25
	var mult: float = 1.0 + 0.15 * float(maxi(0, sold_count))
	var penalty: int = maxi(0, deaths) * 50
	var total: int = maxi(0, roundi(float(base_pts) * mult) - penalty)
	return {
		"floors": floors_cleared,
		"sold_count": sold_count,
		"multiplier": mult,
		"boons": _boons.size(),
		"deaths": deaths,
		"score": total,
		"seed": _seed,
	}


func get_best_score() -> int:
	return int(Lx.state.story_flags.get("stair_best_score", 0)) if Lx.state != null else 0


func get_best_floor() -> int:
	return int(Lx.state.story_flags.get("stair_best_floor", 0)) if Lx.state != null else 0


func modify_stair_stat(stat_name: String, base_val: float, ctx: Dictionary = {}) -> float:
	if _boons.is_empty():
		return base_val
	var val: float = base_val
	var sold: LxSold = LxSold.current()
	match stat_name:
		"bolt_damage", "all_damage":
			if has_boon("boon_glass_edge"):
				val *= 1.30
			if has_boon("boon_heavy_ledger"):
				val *= (1.0 + 0.06 * float(sold.get_toll_weight()))
			if has_boon("boon_silent_blade") and sold.is_sold("sound_off"):
				val *= 1.25
			if has_boon("boon_grey_crit") and sold.is_sold("palette_4") and bool(ctx.get("opened", false)):
				val *= 1.35
			if has_boon("boon_crowned_toll"):
				val *= 1.25
		"move_speed":
			if has_boon("boon_quick_step"):
				val *= 1.15
			if has_boon("boon_crowned_toll"):
				val *= 1.25
		"ember_rate":
			if has_boon("boon_ember_sip"):
				val *= 1.25
		"throw_range":
			if has_boon("boon_long_throw"):
				val *= 1.30
		"lens_radius":
			if has_boon("boon_wide_lens"):
				val *= 1.35
		"dash_cooldown":
			if has_boon("boon_frame_blink") and sold.is_sold("fps_step"):
				val *= 0.80
	return val


func try_consume_last_breath() -> bool:
	if not has_boon("boon_last_breath") or _last_breath_used:
		return false
	_last_breath_used = true
	if _runtime != null and is_instance_valid(_runtime) and _runtime.has_method("on_last_breath_triggered"):
		_runtime.call("on_last_breath_triggered")
	return true


func on_region_changed(island_id: int, region_id: String) -> void:
	var stair_reg: bool = is_stair_region(island_id, region_id)
	if stair_reg:
		_in_stair = true
		_bind_death_event()
		var mapped_floor: int = int(REGION_FLOOR_MAP.get(region_id, 0))
		if _floor <= 0:
			start_run(0, maxi(1, mapped_floor))
		elif mapped_floor > _floor:
			_floor = mapped_floor
			_write_vars()
		_ensure_runtime()
		if _pending_lift_return:
			_pending_lift_return = false
			_handle_post_death_lift_return(region_id)
	elif _in_stair or not _boons.is_empty():
		clear_run_state()


func clear_run_state() -> void:
	if _floor > 0:
		var info: Dictionary = compute_score(_floor, LxSold.current().get_sold_count(), _run_deaths)
		_save_best_score(info)
		run_ended.emit(info)
	if not _cur_climb_picks.is_empty():
		_prev_climb_picks = _cur_climb_picks.duplicate()
	_in_stair = false
	_iron_ascent_active = false
	_pending_lift_return = false
	_floor = 0
	_boons.clear()
	_used_layers_this_climb.clear()
	_cur_climb_picks.clear()
	_last_template_id = ""
	_last_breath_used = false
	_unbind_death_event()
	_unmount_runtime()
	if Lx.vars != null:
		Lx.vars.set_var(SCOPE_STAIR, VAR_FLOOR, 0)
		Lx.vars.set_var(SCOPE_STAIR, VAR_BOONS, [])
		Lx.vars.clear_scope(SCOPE_STAIR)


static func is_stair_region(island_id: int, region_id: String) -> bool:
	if island_id != 8:
		return false
	if region_id == "stair_landing":
		return false
	if region_id.begins_with("stair_") or region_id == "endless_stair" or region_id == "_proof_i8_2":
		return true
	if Lx.packs != null:
		return Lx.packs.dungeon_of(island_id, region_id) == "endless_stair"
	return false


func _bind_death_event() -> void:
	if _death_bound or Lx.events == null:
		return
	if not Lx.events.player_died.is_connected(_on_player_died):
		Lx.events.player_died.connect(_on_player_died)
	_death_bound = true


func _unbind_death_event() -> void:
	if not _death_bound:
		return
	if Lx.events != null and Lx.events.player_died.is_connected(_on_player_died):
		Lx.events.player_died.disconnect(_on_player_died)
	_death_bound = false


func _on_player_died() -> void:
	if not _in_stair:
		return
	_run_deaths += 1
	# Never wipe boons or reset back to stair_r1 start; mark lift checkpoint return.
	_pending_lift_return = true
	_write_vars()


func _handle_post_death_lift_return(reloaded_region: String) -> void:
	var cp: Dictionary = get_last_lift_checkpoint(_floor)
	if cp.is_empty():
		return
	var target_reg: String = str(cp.get("region", ""))
	if target_reg.is_empty() or target_reg == reloaded_region:
		return
	# Skip cross-region warp when running single-room synthetic room_check isolation.
	if Lx.input != null and Lx.input.get("_use_synthetic") == true:
		return
	if Lx.root != null and is_instance_valid(Lx.root) and Lx.root.has_method("load_island_region"):
		_floor = int(cp.get("floor", _floor))
		_write_vars()
		var pos_v: Vector2 = cp.get("pos", Vector2(-1.0, -1.0)) as Vector2
		Lx.root.call_deferred("load_island_region", 8, target_reg, pos_v)
		if Lx.events != null and LxStrings.has_id("ISL8_STAIR_LIFT_RETURN"):
			Lx.events.narration_requested.emit("ISL8_STAIR_LIFT_RETURN", "title", 2.4)


func _ensure_runtime() -> void:
	var host: Node = Lx.root if (Lx.root != null and is_instance_valid(Lx.root)) else (Lx.world if (Lx.world != null and is_instance_valid(Lx.world)) else null)
	if host == null:
		return
	if _runtime == null or not is_instance_valid(_runtime):
		_runtime = BoonRuntimeScript.new() as Node2D
		_runtime.name = "LxStairBoonRuntime"
		host.add_child(_runtime)
	if _runtime.has_method("bind_director"):
		_runtime.call("bind_director", self)


func _unmount_runtime() -> void:
	if _runtime != null and is_instance_valid(_runtime):
		_runtime.queue_free()
	_runtime = null


func _apply_boon_immediate(boon_id: String) -> void:
	if boon_id == "boon_borrow_heart" and Lx.state != null:
		Lx.state.hearts = minf(float(Lx.state.max_hearts), Lx.state.hearts + 1.0)
		if Lx.events != null:
			Lx.events.player_healed.emit(Lx.state.hearts)


func _save_best_score(info: Dictionary) -> void:
	if Lx.state == null:
		return
	var sc: int = int(info.get("score", 0))
	if sc > int(Lx.state.story_flags.get("stair_best_score", 0)):
		Lx.state.story_flags["stair_best_score"] = sc
	var fl: int = int(info.get("floors", 0))
	if fl > int(Lx.state.story_flags.get("stair_best_floor", 0)):
		Lx.state.story_flags["stair_best_floor"] = fl


func _write_vars() -> void:
	if Lx.vars != null:
		Lx.vars.set_var(SCOPE_STAIR, VAR_FLOOR, _floor)
		Lx.vars.set_var(SCOPE_STAIR, VAR_BOONS, _boons.duplicate())
		Lx.vars.set_var(SCOPE_STAIR, VAR_SEED, _seed)


static func _has_template_for_layer(layer_name: String, pool_layers: Array) -> bool:
	for pl: Variant in pool_layers:
		if str(pl) == layer_name:
			return true
	return false
