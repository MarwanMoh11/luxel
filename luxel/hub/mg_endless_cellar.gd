class_name LxMgEndlessCellar
extends LxHubTrialBase
## Daily-Seeded Endless Cellar (kind "mg_endless_cellar") in the subterranean stone vault:
## Generates deterministic daily waves from enemy kinds the player has defeated (bestiary:defeated:*),
## spawns them through region.spawn_enemy() under LxAttackDirector, and tracks daily & all-time best waves.

const FALLBACK_KINDS: PackedStringArray = ["warden", "snatcher", "owl"]
const SPAWN_SLOTS: Array = [
	[96.0, 96.0], [384.0, 96.0], [96.0, 240.0], [384.0, 240.0],
	[240.0, 88.0], [240.0, 256.0],
]

var current_wave: int = 0
var daily_code: int = 0
var daily_label: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pool: PackedStringArray = PackedStringArray()
var _wave_enemies: Array[LxEnemyBrain] = []
var _breather_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "mg_endless_cellar"
	mg_id = "endless_cellar"
	title_key = "HUB_MG_CELLAR"
	lower_is_better = false
	bronze_goal = 3.0
	silver_goal = 6.0
	gold_goal = 10.0
	trial_time_limit = 0.0
	var dinfo: Dictionary = LxHubState.get_daily_seed_info()
	daily_code = int(dinfo["code"])
	daily_label = str(dinfo["label"])
	queue_redraw()


func _build_defeated_pool() -> PackedStringArray:
	var out := PackedStringArray()
	if Lx.state != null:
		var known: PackedStringArray = LxEnemyFactory.known_kinds()
		if Lx.packs != null:
			for pk: String in Lx.packs.enemy_kinds():
				if not known.has(pk):
					known.append(pk)
		var boss_ids: PackedStringArray = Lx.packs.all_boss_ids() if Lx.packs != null else PackedStringArray()
		for k: String in known:
			if boss_ids.has(k) or k.contains("boss") or k in ["bellkeeper", "lighthouse_hermit", "briar_matron", "heron_abbess", "astronomer", "kilnmother", "hollow_wick_boss", "the_hush"]:
				continue
			if int(Lx.state.story_flags.get("bestiary:defeated:" + k, 0)) > 0:
				out.append(k)
	if out.is_empty():
		return FALLBACK_KINDS.duplicate()
	out.sort()
	return out


func get_active_pool() -> PackedStringArray:
	return _build_defeated_pool()


func _on_trial_start() -> void:
	var dinfo: Dictionary = LxHubState.get_daily_seed_info()
	daily_code = int(dinfo["code"])
	daily_label = str(dinfo["label"])
	_rng = RandomNumberGenerator.new()
	_rng.seed = daily_code
	_pool = _build_defeated_pool()
	current_wave = 0
	trial_score = 0.0
	_clear_wave_enemies()
	if region != null:
		region.lock_exits(true)
	if Lx.state != null:
		Lx.state.heal_full()
	_breather_t = 0.6
	trial_subtext = "DAY %d" % (daily_code % 10000)


func _on_trial_end() -> void:
	_clear_wave_enemies()
	if region != null:
		region.lock_exits(false)
	if Lx.state != null:
		Lx.state.heal_full()


func _on_trial_tick(dt: float) -> void:
	# Guard Wick death cleanly inside the Endless Cellar: end run & record reached wave
	if Lx.state != null and Lx.state.hearts <= 0.5:
		LxHubState.record_daily_cellar_wave(int(trial_score))
		stop_trial(true, trial_score)
		return
	if _breather_t > 0.0:
		_breather_t -= dt
		if _breather_t <= 0.0:
			_spawn_next_wave()
		return
	var alive: int = 0
	for i: int in range(_wave_enemies.size() - 1, -1, -1):
		var e: LxEnemyBrain = _wave_enemies[i]
		if not is_instance_valid(e):
			_wave_enemies.remove_at(i)
		elif e.is_alive():
			alive += 1
		else:
			if e.director != null:
				e.director.release_light(e)
				e.director.unregister(e)
			if is_instance_valid(region):
				region.get_enemies().erase(e)
			e.queue_free()
			_wave_enemies.remove_at(i)
	if alive == 0:
		_clear_wave_enemies()
		trial_score = float(current_wave)
		LxHubState.record_daily_cellar_wave(current_wave)
		if Lx.state != null:
			Lx.state.hearts = minf(float(Lx.state.max_hearts), Lx.state.hearts + 1.0)
		_emit_sfx("shrine_unlock")
		_breather_t = 1.8
		trial_subtext = "CLEAR W%d" % current_wave


func _spawn_next_wave() -> void:
	if region == null:
		return
	_clear_wave_enemies()
	current_wave += 1
	var count: int = clampi(2 + int(current_wave / 2), 2, 6)
	var wpos: Vector2 = region.get_wick_pos()
	var used_slots: Array[int] = []
	for i: int in range(count):
		var kind_pick: String = _pool[_rng.randi_range(0, _pool.size() - 1)]
		var s_idx: int = _pick_far_slot(wpos, used_slots)
		used_slots.append(s_idx)
		var sp_arr: Array = SPAWN_SLOTS[s_idx] as Array
		var brain: LxEnemyBrain = region.spawn_enemy({
			"id": "cellar_w%d_%d" % [current_wave, i],
			"kind": kind_pick,
			"pos": [float(sp_arr[0]), float(sp_arr[1])],
			"zone": "cellar_arena",
		})
		if brain != null:
			_wave_enemies.append(brain)
	trial_subtext = "W%d D%d" % [current_wave, daily_code % 10000]


func _pick_far_slot(wpos: Vector2, used: Array[int]) -> int:
	var best_i: int = 0
	var best_d: float = -1.0
	for i: int in range(SPAWN_SLOTS.size()):
		if used.has(i):
			continue
		var sp_a: Array = SPAWN_SLOTS[i] as Array
		var d: float = Vector2(float(sp_a[0]), float(sp_a[1])).distance_to(wpos)
		if d >= 64.0 and d > best_d:
			best_d = d
			best_i = i
	return best_i


func _exit_tree() -> void:
	_clear_wave_enemies()


func _clear_wave_enemies() -> void:
	for e: LxEnemyBrain in _wave_enemies:
		if is_instance_valid(e):
			if e.director != null:
				e.director.release_light(e)
				e.director.unregister(e)
			if is_instance_valid(region):
				region.get_enemies().erase(e)
			e.queue_free()
	_wave_enemies.clear()


func _get_hud_primary_text() -> String:
	return "WAVE %d  BEST %d" % [current_wave, LxHubState.get_daily_cellar_best()]


func _get_plinth_icon() -> String: return "skull"
func _get_plinth_accent() -> String: return "coral"
