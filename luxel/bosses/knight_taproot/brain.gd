class_name LxKnightTaprootBoss
extends LxBossBase
## Island 3 Briar Court Joust #1: Sir Taproot (court_r2).
## Beetle-mounted forest lancer jousting across 3 horizontal tilt-lanes.
## Three Seedlight thorn-wall nodes sit along the center tilt line: shining Wick's lantern
## near a node blooms a living thorn-wall; baiting Sir Taproot's Lane Tilt Charge into a
## bloomed thorn-wall unhorses him for a 1.65 s stagger punish!
## P2 (<= 50% HP): Double Reversal boomerang charge + shattered tournament rail pits.

const LANE_FRACS: Array[float] = [0.24, 0.50, 0.76]
const CHARGE_SPEED: float = 182.0
const BLOOM_NEED_S: float = 0.24
const BLOOM_DECAY_S: float = 4.2
const UNHORSE_STAGGER_S: float = 1.65

var _lane_nodes: Array[Dictionary] = [] # {pos, charge, bloom_t}
var _active_lane: int = 1
var _charge_dir: Vector2 = Vector2.LEFT
var _charge_hit: bool = false
var _rev_flipped: bool = false


func _init() -> void:
	super._init()
	kind = "knight_taproot"
	boss_id = "knight_taproot"
	boss_name_key = "ISL3_BOSS_TAPROOT"
	island_id = 3
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 54.0
	hp = 54.0
	body_radius = 11.0
	move_speed = 44.0
	stagger_threshold = 10.0
	stagger_duration = 1.65
	post_recover_cd = 0.38
	intro_duration = 0.55
	phase_shift_duration = 0.65
	death_duration = 2.1
	shard_drop = 22


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Lane Tilt Charge (full-width tournament joust; bloom lane thorn-wall to unhorse!)
	register_attack("lane_tilt_charge", {
		"weight": 1.35, "tell": 0.55, "commit": 0.50, "recover": 1.25, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_active_lane = _lane_for_y(tgt.y)
			var ly: float = _lane_y(_active_lane)
			_charge_dir = Vector2.LEFT if pos.x >= tgt.x else Vector2.RIGHT
			facing = _charge_dir.angle()
			_charge_hit = false
			var a := Vector2(arena_rect.position.x + 12.0, ly)
			var b := Vector2(arena_rect.end.x - 12.0, ly)
			ground.warn_lane(a, b, 13.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("kt_court_horn", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.16)
			stage.play_sfx("kt_beetle_gallop", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			var ly: float = _lane_y(_active_lane)
			var step_v := Vector2(_charge_dir.x * CHARGE_SPEED * dt, clampf(ly - pos.y, -110.0 * dt, 110.0 * dt))
			move_boss(step_v, false)
			# Unhorse check against bloomed Seedlight thorn-wall in active lane!
			if _check_thorn_unhorse():
				return
			if not _charge_hit and pos.distance_to(tgt) <= 18.0:
				_charge_hit = true
				emit_boss_damage(_charge_dir, 1.0, "lane_tilt_charge", pos, true),
	})

	# Attack 2: Horn Toss (wide front sweep + flung earth-clods pressuring Wick & corners)
	register_attack("horn_toss", {
		"weight": 1.20, "tell": 0.54, "commit": 0.28, "recover": 1.12, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = aim_d.angle()
			_charge_hit = false
			ground.warn_sector(pos, facing - 1.00, facing + 1.00, 36.0, last_tell_duration, 0.0, "coral", "gold")
			patterns.emit_rain(ground, _corner_drops(tgt), last_tell_duration + 0.14, 20.0, 1.0, "coral", "apricot")
			stage.play_sfx("kt_court_horn", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim_d, 5 if phase >= 2 else 3, 0.80, 114.0, {"color": "lime", "source": "horn_clod"})
			stage.shake(0.16)
			stage.play_sfx("kt_lance_crack", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, _el: float) -> void:
			if not _charge_hit and pos.distance_to(tgt) <= 34.0:
				var rel: Vector2 = tgt - pos
				if rel.length() < 1.0 or absf(angle_difference(facing, rel.angle())) <= 1.05:
					_charge_hit = true
					emit_boss_damage(Vector2.from_angle(facing), 1.0, "horn_toss", pos, true),
	})

	# Attack 3: P2 Double Reversal (charges across, pivots mid-lane & fires boomerang lance!)
	register_attack("double_reversal", {
		"phases": [2], "weight": 2.60, "tell": 0.58, "commit": 0.56, "recover": 1.32, "cooldown": 1.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_active_lane = _lane_for_y(tgt.y)
			_charge_dir = Vector2.LEFT if pos.x >= tgt.x else Vector2.RIGHT
			facing = _charge_dir.angle()
			_charge_hit = false
			_rev_flipped = false
			var ly: float = _lane_y(_active_lane)
			ground.warn_lane(Vector2(arena_rect.position.x + 12.0, ly), Vector2(arena_rect.end.x - 12.0, ly), 13.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("kt_court_horn", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.18)
			stage.play_sfx("kt_beetle_gallop", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, el: float) -> void:
			if not _rev_flipped and el >= 0.28:
				_rev_flipped = true
				_charge_dir = -_charge_dir
				facing = _charge_dir.angle()
				_charge_hit = false
				var aim_t: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else _charge_dir
				patterns.emit_boomerang(pos, aim_t, 122.0, 0.65, 0.55, {"color": "gold", "source": "lance_boomerang"})
				patterns.emit_fan(pos, aim_t, 3, 0.60, 114.0, {"color": "coral", "source": "lance_splinter"})
				stage.play_sfx("kt_lance_crack", pos)
			move_boss(_charge_dir * CHARGE_SPEED * 0.88 * dt, false)
			if _check_thorn_unhorse():
				return
			if not _charge_hit and pos.distance_to(tgt) <= 18.0:
				_charge_hit = true
				emit_boss_damage(_charge_dir, 1.0, "double_reversal", pos, true),
	})


func _on_reset_encounter() -> void:
	_active_lane = 1
	_charge_hit = false
	_rev_flipped = false
	_lane_nodes.clear()
	var cx: float = arena_rect.get_center().x
	for i: int in range(3):
		_lane_nodes.append({"pos": Vector2(cx, _lane_y(i)), "charge": 0.0, "bloom_t": 0.0})


func _lane_y(idx: int) -> float:
	return arena_rect.position.y + arena_rect.size.y * LANE_FRACS[clampi(idx, 0, LANE_FRACS.size() - 1)]


func _lane_for_y(wy: float) -> int:
	var best: int = 1
	var best_d: float = INF
	for i: int in range(3):
		var d: float = absf(_lane_y(i) - wy)
		if d < best_d:
			best_d = d
			best = i
	return best


func _corner_drops(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	return out


func _check_thorn_unhorse() -> bool:
	if _active_lane < 0 or _active_lane >= _lane_nodes.size():
		return false
	var nd: Dictionary = _lane_nodes[_active_lane]
	if float(nd["bloom_t"]) <= 0.0:
		return false
	var np: Vector2 = nd["pos"] as Vector2
	if pos.distance_to(np) <= 20.0:
		nd["bloom_t"] = 0.0
		nd["charge"] = 0.0
		_release_token()
		active_attack_id = ""
		stagger_meter = 0.0
		_set_boss_state(BossState.STAGGER, UNHORSE_STAGGER_S)
		staggered.emit(UNHORSE_STAGGER_S)
		stage.shake(0.26)
		stage.play_sfx("kt_lance_crack", pos)
		LxDamageFx.boss_impact(pos, 0.20, 82.0, 84.0, 82.0, 1.40, 0.32)
		return true
	return false


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	# Seedlight rule: Wick's lantern (hand or hung) blooms the 3 lane thorn-wall seeds!
	var lan_p: Vector2 = _get_lantern_pos()
	var lan_r: float = 52.0 if _is_lantern_hung() else 42.0
	for nd: Dictionary in _lane_nodes:
		var np: Vector2 = nd["pos"] as Vector2
		if lan_p.distance_to(np) <= lan_r:
			nd["charge"] = minf(BLOOM_NEED_S, float(nd["charge"]) + dt)
			if float(nd["charge"]) >= BLOOM_NEED_S:
				nd["bloom_t"] = BLOOM_DECAY_S
		else:
			nd["charge"] = maxf(0.0, float(nd["charge"]) - dt * 0.6)
			if float(nd["bloom_t"]) > 0.0:
				nd["bloom_t"] = maxf(0.0, float(nd["bloom_t"]) - dt)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		# Shatter outer tournament rail corners into bramble pits (safe from orbit ring!) + cover pillars
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(17, 7, 1, 2), "pit")
		props.spawn_pillar(c + Vector2(-58.0, -28.0), 4.0, "kt_rail_w")
		props.spawn_pillar(c + Vector2(58.0, 28.0), 4.0, "kt_rail_e")
		stage.darkness_pulse(0.56, 0.90)
		stage.shake(0.22)
		stage.play_sfx("kt_court_horn", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	if bool(h["cracks_armour"]) or src == LxHit.SOURCE_BEAM:
		return dmg * 1.25
	if src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_DASH:
		return dmg * 1.15
	if not is_punishable():
		var rel: Vector2 = (h["origin"] as Vector2) - pos
		if rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) < 1.05:
			clank_t = 0.08
			return dmg * 0.58
	return dmg


func _on_death_start() -> void:
	# Record default verdict if none set yet (real court_r2 braziers overwrite with mercy/fire)
	if Lx.vars != null and str(Lx.vars.get_var("island:3", "court_v1", "none")) == "none":
		Lx.vars.set_var("island:3", "court_v1", "mercy")
	stage.play_sfx("kt_lance_crack", pos)


func _has_active_shield() -> bool:
	return not is_punishable()


func _shield_color() -> Color:
	return PAL["jade"] as Color


func _draw_boss_extra(_off: Vector2) -> void:
	var inv: Vector2 = -pos
	# Draw 3 tournament tilt-lanes & living Seedlight thorn-wall nodes
	for i: int in range(_lane_nodes.size()):
		var ly: float = _lane_y(i)
		var la: Vector2 = (Vector2(arena_rect.position.x + 12.0, ly) + inv).round()
		var lb: Vector2 = (Vector2(arena_rect.end.x - 12.0, ly) + inv).round()
		draw_line(la, lb, Color(PAL["jade"] as Color, 0.25 if i != _active_lane else 0.50), 1.0)
		var nd: Dictionary = _lane_nodes[i]
		var np: Vector2 = ((nd["pos"] as Vector2) + inv).round()
		var bloomed: bool = float(nd["bloom_t"]) > 0.0
		if bloomed:
			draw_rect(Rect2(np + Vector2(-7.0, -10.0), Vector2(14.0, 20.0)), PAL["pine"] as Color)
			draw_rect(Rect2(np + Vector2(-5.0, -8.0), Vector2(10.0, 16.0)), PAL["jade"] as Color)
			draw_rect(Rect2(np + Vector2(-3.0, -5.0), Vector2(6.0, 10.0)), PAL["lime"] as Color)
		else:
			draw_circle(np, 5.0, Color(PAL["pine"] as Color, 0.75))
			draw_circle(np, 2.2, PAL["gold"] as Color if float(nd["charge"]) > 0.02 else PAL["jade"] as Color)
