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
var _cellar_overlay: Node2D = null


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
	_ensure_overlay()
	_breather_t = 0.6
	trial_subtext = "DAY %d" % (daily_code % 10000)


func _on_trial_end() -> void:
	_clear_wave_enemies()
	_clear_overlay()
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
	if _cellar_overlay != null and is_instance_valid(_cellar_overlay):
		_cellar_overlay.queue_redraw()
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
	var best_i: int = -1
	var best_d: float = -1.0
	var fallback_i: int = 0
	var fallback_d: float = -1.0
	for i: int in range(SPAWN_SLOTS.size()):
		if used.has(i):
			continue
		var sp_a: Array = SPAWN_SLOTS[i] as Array
		var d: float = Vector2(float(sp_a[0]), float(sp_a[1])).distance_to(wpos)
		if d > fallback_d:
			fallback_d = d
			fallback_i = i
		if d >= 64.0 and d > best_d:
			best_d = d
			best_i = i
	return best_i if best_i >= 0 else fallback_i


func _exit_tree() -> void:
	_clear_overlay()
	_clear_wave_enemies()
	super._exit_tree()


func _ensure_overlay() -> void:
	if region == null:
		return
	_clear_overlay()
	_cellar_overlay = Node2D.new()
	_cellar_overlay.name = "EndlessCellarOverlay"
	_cellar_overlay.z_index = 4
	_cellar_overlay.draw.connect(_draw_cellar_overlay)
	region.add_child(_cellar_overlay)


func _clear_overlay() -> void:
	if _cellar_overlay != null and is_instance_valid(_cellar_overlay):
		if _cellar_overlay.draw.is_connected(_draw_cellar_overlay):
			_cellar_overlay.draw.disconnect(_draw_cellar_overlay)
		_cellar_overlay.queue_free()
	_cellar_overlay = null


func _draw_cellar_overlay() -> void:
	if not trial_running or _cellar_overlay == null:
		return
	var fr: bool = LxHudFx.flash_reduced()
	var c_void: Color = LxPalette.PAL["void"]
	if _breather_t > 0.0:
		# Telegraphed spawn runes during wave breather (zero RNG mutation)
		var ring_r: float = 9.0 if fr else roundf(8.0 + sin(_clock * 8.0) * 2.0)
		var rune_c: Color = LxPalette.PAL["apricot"] if fr else LxPalette.PAL["coral"]
		for sp_v: Variant in SPAWN_SLOTS:
			var sp_a: Array = sp_v as Array
			var pt := Vector2(roundf(float(sp_a[0])), roundf(float(sp_a[1])))
			_cellar_overlay.draw_arc(pt, ring_r + 1.0, 0.0, TAU, 16, c_void, 2.0)
			_cellar_overlay.draw_arc(pt, ring_r, 0.0, TAU, 16, rune_c, 1.0)
			_cellar_overlay.draw_rect(Rect2(pt + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), c_void)
			_cellar_overlay.draw_rect(Rect2(pt + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), LxPalette.PAL["gold"] if not fr else rune_c)
	else:
		# Live remaining-enemy pip bar above the plinth
		var alive_n: int = 0
		for e: LxEnemyBrain in _wave_enemies:
			if is_instance_valid(e) and e.is_alive():
				alive_n += 1
		if alive_n > 0:
			var bw: float = float(alive_n * 5 + 3)
			var bx0: float = roundf(pos.x - bw * 0.5)
			var by0: float = roundf(pos.y - 29.0)
			_cellar_overlay.draw_rect(Rect2(bx0, by0, bw, 6.0), c_void)
			for ai: int in range(alive_n):
				_cellar_overlay.draw_rect(Rect2(bx0 + 2.0 + float(ai * 5), by0 + 2.0, 3.0, 2.0), LxPalette.PAL["coral"])
				_cellar_overlay.draw_rect(Rect2(bx0 + 2.0 + float(ai * 5), by0 + 2.0, 1.0, 1.0), LxPalette.PAL["cream"])


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
