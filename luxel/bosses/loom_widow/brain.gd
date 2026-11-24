class_name LxLoomWidowBoss
extends LxBossBase
## Island 3 Boss B: The Loom Widow (The Weaver's Loom, loom_r11).
## 6-spoke walkable glowing silk web radiating from a central brass spindle to 6 rim spools.
## Shoot her active spoke's rim spool (0.9 s ember burn warning -> spoke breaks -> regrows 7 s)
## to drop her onto the central spindle for a massive 1.75 s stagger punish!
## P2 (<= 66% HP): cuts outer rim gaps + blue frost-tension lock on 2 spools + cuttable rim tethers.
## P3 (<= 33% HP): faster web cycling, twilight shadow pulse & wider silk spirals.

const SPOKE_COUNT: int = 6
const SPOKE_WARN_S: float = 0.90
const SPOKE_REGROW_S: float = 7.0
const DROP_STAGGER_S: float = 1.75

var _spokes: Array[Dictionary] = [] # {angle, end_pos, state:"intact"|"burning"|"burned"|"frozen", timer}
var _perched_spoke: int = 0
var _spindle_pos: Vector2 = Vector2.ZERO
var _drop_target: Vector2 = Vector2.ZERO
var _dropping_now: bool = false
var _eye_blink_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "loom_widow"
	boss_id = "loom_widow"
	boss_name_key = "ISL3_BOSS_WIDOW"
	island_id = 3
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 72.0
	hp = 72.0
	body_radius = 12.5
	move_speed = 38.0
	stagger_threshold = 13.0
	stagger_duration = 1.75
	post_recover_cd = 0.54
	intro_duration = 0.70
	phase_shift_duration = 0.70
	death_duration = 2.4
	shard_drop = 36


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Silk Volley (3-spoke snare wave + rim-corner drops so perimeter is never safe)
	register_attack("silk_volley", {
		"weight": 1.25, "tell": 0.48, "commit": 0.42, "recover": 1.05, "cooldown": 1.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_hop_to_spoke_near(tgt)
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			facing = aim_d.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 170.0), 10.0, last_tell_duration, 0.0, "coral", "gold")
			patterns.emit_rain(ground, [clamp_to_arena(tgt)], last_tell_duration + 0.18, 19.0, 1.0, "coral", "gold")
			stage.play_sfx("lw_widow_plucks", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim_d, 3, 0.80, 92.0, {
				"color": "rose", "reflectable": true, "source": "silk_volley",
			})
			stage.shake(0.14)
			stage.play_sfx("lw_widow_plucks", pos),
	})

	# Attack 2: Spindle Drop (8 ice eyes blink -> ceiling drop slam onto Wick + radial gap ring)
	register_attack("spindle_drop", {
		"weight": 1.25, "tell": 0.72, "commit": 0.34, "recover": 1.32, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_eye_blink_t = last_tell_duration
			_drop_target = clamp_to_arena(tgt)
			_dropping_now = false
			ground.warn_ring(_drop_target, 26.0, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("lw_widow_plucks", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_dropping_now = true
			pos = _drop_target
			position = pos.round()
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 6, 82.0, gap_a, 1.30, {"color": "gold", "source": "spindle_ring"})
			stage.shake(0.22)
			stage.play_sfx("lw_widow_drop_thud", pos),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			_dropping_now = false,
	})

	# Attack 3: Web-Lash Spiral (rotating silk spiral + charged spoke lines)
	register_attack("web_lash_spiral", {
		"weight": 1.10, "tell": 0.66, "commit": 0.46, "recover": 1.25, "cooldown": 1.9,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var s_idx: int = _nearest_spoke_to(tgt)
			var opp: int = (s_idx + 3) % SPOKE_COUNT
			if s_idx < _spokes.size() and opp < _spokes.size():
				patterns.emit_chain_lightning([_spokes[s_idx]["end_pos"] as Vector2, _spindle_pos, _spokes[opp]["end_pos"] as Vector2], last_tell_duration + 0.14, 6.0, 0.20, 1.0)
			ground.warn_ring(pos, 24.0, last_tell_duration, 0.0, "gold", "cream")
			stage.play_sfx("lw_widow_plucks", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_spiral(pos, 4, 80.0, facing, 0.50, 2, 0.26, {"color": "apricot", "source": "web_spiral"})
			stage.shake(0.15)
			stage.play_sfx("lw_spoke_ignite", pos),
	})

	# Attack 4: P2+ Blue Tension Lock (freezes 2 rim spools fireproof + frost sweep wall + corner pillars)
	register_attack("blue_tension_lock", {
		"phases": [2, 3], "weight": 2.40, "tell": 0.68, "commit": 0.38, "recover": 1.28, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_freeze_two_spokes()
			patterns.emit_pillars([clamp_to_arena(tgt)], last_tell_duration + 0.16, 15.0, 0.24, 1.0, "sky")
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.DOWN
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 155.0), 9.0, last_tell_duration, 0.0, "sky", "ice")
			stage.play_sfx("lw_widow_plucks", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var from_top: bool = tgt.y >= c.y
			var origin := Vector2(c.x, arena_rect.position.y + 10.0 if from_top else arena_rect.end.y - 10.0)
			var mdir: Vector2 = Vector2.DOWN if from_top else Vector2.UP
			patterns.emit_sweep_wall(origin, mdir, arena_rect.size.x - 28.0, 5, 1, 3, 82.0, {"color": "ice", "source": "frost_silk"})
			stage.shake(0.18)
			stage.play_sfx("crystal_clank", pos),
	})


func _on_reset_encounter() -> void:
	_spindle_pos = arena_rect.get_center()
	_perched_spoke = 0
	_dropping_now = false
	_eye_blink_t = 0.0
	_build_web_spokes()


func _build_web_spokes() -> void:
	_spokes.clear()
	var rx: float = arena_rect.size.x * 0.43
	var ry: float = arena_rect.size.y * 0.41
	for i: int in range(SPOKE_COUNT):
		var ang: float = float(i) * (TAU / float(SPOKE_COUNT))
		var end_p: Vector2 = clamp_to_arena(_spindle_pos + Vector2(cos(ang) * rx, sin(ang) * ry))
		_spokes.append({"angle": ang, "end_pos": end_p, "state": "intact", "timer": 0.0})
		var idx: int = i
		var sp_p: Dictionary = props.spawn_bell(end_p, func(_p: Dictionary) -> void:
			_ignite_spoke(idx), "lw_spool_%d" % i)
		sp_p["solid"] = false


func _ignite_spoke(idx: int) -> void:
	if idx < 0 or idx >= _spokes.size() or boss_state == BossState.DEATH:
		return
	var sp: Dictionary = _spokes[idx]
	if str(sp["state"]) == "frozen":
		stage.play_sfx("crystal_clank", sp["end_pos"] as Vector2)
		return
	if str(sp["state"]) != "intact":
		return
	sp["state"] = "burning"
	sp["timer"] = SPOKE_WARN_S
	var end_p: Vector2 = sp["end_pos"] as Vector2
	ground.warn_lane(_spindle_pos, end_p, 8.0, SPOKE_WARN_S, 0.0, "coral", "gold")
	stage.play_sfx("lw_spoke_ignite", end_p)


func _freeze_two_spokes() -> void:
	if _spokes.is_empty():
		return
	for off_i: int in [1, 4]:
		var idx: int = (_perched_spoke + off_i) % _spokes.size()
		if str(_spokes[idx]["state"]) == "intact":
			_spokes[idx]["state"] = "frozen"
			_spokes[idx]["timer"] = 6.0


func _nearest_spoke_to(pt: Vector2) -> int:
	var best: int = 0
	var best_d: float = INF
	for i: int in range(_spokes.size()):
		var mid: Vector2 = _spindle_pos.lerp(_spokes[i]["end_pos"] as Vector2, 0.65)
		var d: float = mid.distance_squared_to(pt)
		if d < best_d:
			best_d = d
			best = i
	return best


func _hop_to_spoke_near(tgt: Vector2) -> void:
	var best: int = -1
	var best_d: float = INF
	for i: int in range(_spokes.size()):
		if str(_spokes[i]["state"]) == "burned":
			continue
		var perch: Vector2 = _spindle_pos.lerp(_spokes[i]["end_pos"] as Vector2, 0.56)
		var d: float = perch.distance_squared_to(tgt)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_perched_spoke = best


func _rim_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
	return out


func _step_boss_reposition(dt: float, _target: Vector2) -> void:
	var goal: Vector2 = _spindle_pos
	if _perched_spoke >= 0 and _perched_spoke < _spokes.size() and str(_spokes[_perched_spoke]["state"]) != "burned":
		goal = _spindle_pos.lerp(_spokes[_perched_spoke]["end_pos"] as Vector2, 0.54)
	var diff: Vector2 = goal - pos
	if diff.length() > 3.0:
		move_boss(diff.normalized() * minf(diff.length(), move_speed * dt), true)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_eye_blink_t = maxf(0.0, _eye_blink_t - dt)
	for i: int in range(_spokes.size()):
		var sp: Dictionary = _spokes[i]
		var st: String = str(sp["state"])
		if st == "burning":
			sp["timer"] = float(sp["timer"]) - dt
			if float(sp["timer"]) <= 0.0:
				sp["state"] = "burned"
				sp["timer"] = SPOKE_REGROW_S
				if i == _perched_spoke:
					_drop_onto_spindle()
		elif st == "burned" or st == "frozen":
			sp["timer"] = float(sp["timer"]) - dt
			if float(sp["timer"]) <= 0.0:
				sp["state"] = "intact"


func _drop_onto_spindle() -> void:
	_perched_spoke = -1
	pos = clamp_to_arena(_spindle_pos)
	position = pos.round()
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, DROP_STAGGER_S)
	staggered.emit(DROP_STAGGER_S)
	stage.shake(0.26)
	stage.play_sfx("lw_widow_drop_thud", pos)
	LxDamageFx.boss_impact(pos, 0.22, 86.0, 90.0, 86.0, 1.42, 0.34)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# P2 Arena Mutation: raise 2 frost-silk rim barricades + string 2 cuttable tension tethers!
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 2), "wall")
		stage.set_tiles(world_ctx, Rect2i(17, 7, 1, 2), "wall")
		if _spokes.size() >= 6:
			tethers.add_tether("lw_rim_n", _spokes[1]["end_pos"] as Vector2, _spokes[2]["end_pos"] as Vector2, {
				"hp": 1.8, "cuttable": true, "color": "gold",
				"on_cut": func(_t: Dictionary) -> void: _drop_onto_spindle(),
			})
			tethers.add_tether("lw_rim_s", _spokes[4]["end_pos"] as Vector2, _spokes[5]["end_pos"] as Vector2, {
				"hp": 1.8, "cuttable": true, "color": "gold",
				"on_cut": func(_t: Dictionary) -> void: _drop_onto_spindle(),
			})
		stage.darkness_pulse(0.64, 1.05)
		stage.shake(0.24)
		stage.play_sfx("lw_spoke_ignite", pos)
	elif new_phase == 3:
		stage.set_tiles(world_ctx, Rect2i(17, 1, 1, 2), "wall")
		stage.set_tiles(world_ctx, Rect2i(2, 7, 1, 2), "wall")
		stage.darkness_pulse(0.72, 1.15)
		stage.shake(0.28)
		stage.play_sfx("lw_widow_drop_thud", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	if bool(h["cracks_armour"]) or src == LxHit.SOURCE_BEAM:
		return dmg * 1.25
	if src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL:
		if _perched_spoke >= 0:
			_ignite_spoke(_perched_spoke)
		return dmg * 1.10
	if _perched_spoke >= 0 and not is_punishable():
		return dmg * 0.65
	return dmg


func _on_death_start() -> void:
	stage.light_burst(_spindle_pos, 118.0, 1.5, 0.55)
	stage.play_sfx("lw_silk_choir_die", pos)


func _draw_boss_extra(_off: Vector2) -> void:
	var inv: Vector2 = -pos
	var sp_local: Vector2 = (_spindle_pos + inv).round()
	# Central golden brass spindle
	draw_circle(sp_local, 10.0, Color(PAL["night"] as Color, 0.85))
	draw_arc(sp_local, 10.0, 0.0, TAU, 18, PAL["gold"] as Color, 1.5)
	draw_circle(sp_local, 3.0, PAL["apricot"] as Color)
	# 6 walkable silk spokes
	for i: int in range(_spokes.size()):
		var sp: Dictionary = _spokes[i]
		var st: String = str(sp["state"])
		if st == "burned":
			continue
		var ep: Vector2 = ((sp["end_pos"] as Vector2) + inv).round()
		var col: Color = PAL["gold"] as Color
		if st == "burning":
			col = PAL["coral"] as Color if (is_flash_reduced() or int(anim_t * 14.0) % 2 == 0) else PAL["cream"] as Color
		elif st == "frozen":
			col = PAL["ice"] as Color
		elif i != _perched_spoke:
			col = Color(PAL["stone"] as Color, 0.55)
		draw_line(sp_local, ep, col, 2.2 if (i == _perched_spoke or st == "burning") else 1.2)
	# Horror beat: 6 ice eyes blink open in a ring above during Spindle Drop tell!
	if _eye_blink_t > 0.0:
		for k: int in range(6):
			var ex: float = float(k - 2.5) * 6.0
			var ey: float = -body_radius - 14.0 - absf(float(k - 2.5)) * 1.4
			draw_rect(Rect2(Vector2(ex - 1.0, ey - 1.0).round(), Vector2(2.0, 2.0)), PAL["ice"] as Color)
