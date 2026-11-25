class_name LxThreadKeeperBoss
extends LxBossBase
## Island 3 Mini-Boss B: The Thread-Keeper (The Weaver's Loom, loom_r6).
## Heartwood loom-mantis gliding on 3 horizontal warp-rails behind silk curtains.
## Shoot an active rail's west spool (or pierce with Throw/Beam) to ignite silk-fire along
## the rail, burning the curtain and dropping Thread-Keeper to center with smoking-boot stagger!
## P2 (<= 50% HP): freezes middle warp-rail ice-blue & strings cuttable frost-silk wire.

const RAIL_FRACS: Array[float] = [0.24, 0.50, 0.76]
const CLEAVE_SPEED: float = 212.0
const SPARK_SPEED: float = 240.0
const BURN_STAGGER_S: float = 1.55

var _active_rail: int = 1
var _curtain_up: bool = true
var _curtain_down_t: float = 0.0
var _mid_rail_frozen: bool = false
var _rail_fire_idx: int = -1
var _rail_fire_x: float = 0.0
var _cleave_dir: Vector2 = Vector2.LEFT
var _cleave_hit: bool = false
var _boot_smoke_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "thread_keeper"
	boss_id = "thread_keeper"
	boss_name_key = "ISL3_BOSS_KEEPER"
	island_id = 3
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 54.0
	hp = 54.0
	body_radius = 10.5
	move_speed = 44.0
	stagger_threshold = 10.0
	stagger_duration = 1.55
	post_recover_cd = 0.36
	intro_duration = 0.55
	phase_shift_duration = 0.65
	death_duration = 2.2
	shard_drop = 22


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Warp-Rail Needle Fan (3/5 reflectable silk needles + aimed lane)
	register_attack("warp_needle_fan", {
		"weight": 1.25, "tell": 0.54, "commit": 0.44, "recover": 1.10, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_pick_rail_near(tgt.y)
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			facing = aim_d.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 170.0), 9.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("tk_loom_clack", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var cnt: int = 5 if phase >= 2 else 3
			var spd: float = 124.0 if phase >= 2 else 112.0
			patterns.emit_fan(pos, aim_d, cnt, 0.88, spd, {
				"color": "ice" if phase >= 2 else "gold", "reflectable": true, "source": "silk_needle",
			})
			stage.shake(0.12)
			stage.play_sfx("tk_silk_needle", pos),
	})

	# Attack 2: Shuttle Cleave (high-speed horizontal warp-rail rush across arena)
	register_attack("shuttle_cleave", {
		"weight": 1.25, "tell": 0.52, "commit": 0.36, "recover": 1.30, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_pick_rail_near(tgt.y)
			var ry: float = _rail_y(_active_rail)
			var go_left: bool = pos.x >= tgt.x
			_cleave_dir = Vector2.LEFT if go_left else Vector2.RIGHT
			facing = _cleave_dir.angle()
			_cleave_hit = false
			var start_p := Vector2(pos.x, ry)
			var end_p: Vector2 = clamp_to_arena(start_p + _cleave_dir * 165.0)
			ground.warn_lane(start_p, end_p, 13.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("tk_loom_clack", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.15)
			stage.play_sfx("tk_shuttle_zip", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			var ry: float = _rail_y(_active_rail)
			var step_v := Vector2(_cleave_dir.x * CLEAVE_SPEED * dt, clampf(ry - pos.y, -90.0 * dt, 90.0 * dt))
			move_boss(step_v, false)
			if not _cleave_hit and pos.distance_to(tgt) <= 26.0:
				_cleave_hit = true
				emit_boss_damage(_cleave_dir, 1.0, "shuttle_cleave", pos, true),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			pass,
	})

	# Attack 3: Cross-Warp Snare (2 vertical silk tripwires + targeted loom-bobbin drops on Wick & corners)
	register_attack("cross_warp_snare", {
		"weight": 1.15, "tell": 0.58, "commit": 0.38, "recover": 1.12, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var x1: float = clampf(tgt.x, arena_rect.position.x + 18.0, arena_rect.end.x - 18.0)
			var x2: float = clampf(arena_rect.get_center().x + (arena_rect.get_center().x - x1) * 0.65, arena_rect.position.x + 18.0, arena_rect.end.x - 18.0)
			patterns.emit_chain_lightning([Vector2(x1, arena_rect.position.y + 8.0), Vector2(x1, arena_rect.end.y - 8.0)], last_tell_duration, 8.0, 0.28, 1.0)
			if phase >= 2:
				patterns.emit_chain_lightning([Vector2(x2, arena_rect.position.y + 8.0), Vector2(x2, arena_rect.end.y - 8.0)], last_tell_duration + 0.08, 8.0, 0.28, 1.0)
			var drops: Array[Vector2] = _perimeter_drops(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "coral", "gold")
			stage.play_sfx("tk_loom_clack", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			patterns.emit_fan(pos, aim_d, 3 if phase < 2 else 4, 0.62, 118.0, {"color": "apricot", "source": "warp_spark"})
			stage.shake(0.16)
			stage.play_sfx("tk_silk_needle", pos),
	})


func _on_reset_encounter() -> void:
	_active_rail = 1
	_curtain_up = true
	_curtain_down_t = 0.0
	_mid_rail_frozen = false
	_rail_fire_idx = -1
	_rail_fire_x = 0.0
	_boot_smoke_t = 0.0
	_spawn_rail_spools()


func _spawn_rail_spools() -> void:
	var sx: float = arena_rect.position.x + 18.0
	for i: int in range(3):
		var ry: float = _rail_y(i) + (-10.0 if i == 1 else 0.0)
		var rail_idx: int = i
		var sp: Dictionary = props.spawn_bell(Vector2(sx, ry), func(_p: Dictionary) -> void:
			_ignite_rail(rail_idx), "tk_spool_%d" % i)
		sp["solid"] = false


func _rail_y(idx: int) -> float:
	var f: float = RAIL_FRACS[clampi(idx, 0, RAIL_FRACS.size() - 1)]
	return arena_rect.position.y + arena_rect.size.y * f


func _pick_rail_near(wy: float) -> void:
	var best: int = 1
	var best_d: float = INF
	for i: int in range(3):
		var d: float = absf(_rail_y(i) - wy)
		if d < best_d:
			best_d = d
			best = i
	_active_rail = best


func _ignite_rail(rail_idx: int) -> void:
	if boss_state == BossState.DEATH:
		return
	if rail_idx == 1 and _mid_rail_frozen:
		stage.play_sfx("crystal_clank", Vector2(arena_rect.position.x + 18.0, _rail_y(1)))
		return
	_rail_fire_idx = rail_idx
	_rail_fire_x = arena_rect.position.x + 18.0
	stage.play_sfx("web_burn", Vector2(_rail_fire_x, _rail_y(rail_idx)))


func _perimeter_drops(tgt: Vector2) -> Array[Vector2]:
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


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	# Glide rhythmically along the active warp-rail while facing Wick
	var ry: float = _rail_y(_active_rail)
	var pref_x: float = clampf(arena_rect.get_center().x + 48.0 * _orbit_side, arena_rect.position.x + 42.0, arena_rect.end.x - 26.0)
	var goal := Vector2(pref_x, ry)
	var diff: Vector2 = goal - pos
	if diff.length() > 3.0:
		move_boss(diff.normalized() * minf(diff.length(), move_speed * dt), false)
	var _unused := target


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_boot_smoke_t = maxf(0.0, _boot_smoke_t - dt)
	if _curtain_down_t > 0.0:
		_curtain_down_t = maxf(0.0, _curtain_down_t - dt)
		if _curtain_down_t <= 0.0:
			_curtain_up = true
	if _rail_fire_idx >= 0:
		_rail_fire_x += SPARK_SPEED * dt
		var fire_pos := Vector2(_rail_fire_x, _rail_y(_rail_fire_idx))
		if fire_pos.distance_to(pos) <= body_radius + 14.0:
			_rail_fire_idx = -1
			_on_curtain_burned()
		elif _rail_fire_x >= arena_rect.end.x - 6.0:
			_rail_fire_idx = -1


func _on_curtain_burned() -> void:
	_curtain_up = false
	_curtain_down_t = 5.5
	_boot_smoke_t = 2.0
	stage.play_sfx("tk_wood_unspool", pos)
	if stagger_immunity_t > 0.0:
		add_stagger(4.0)
		return
	pos = clamp_to_arena(arena_rect.get_center())
	position = pos.round()
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	stagger_immunity_t = 5.5
	_set_boss_state(BossState.STAGGER, BURN_STAGGER_S)
	staggered.emit(BURN_STAGGER_S)
	stage.shake(0.22)
	LxDamageFx.boss_impact(pos, 0.18, 72.0, 76.0, 72.0, 1.36, 0.30)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_mid_rail_frozen = true
		_curtain_up = true
		# Small silk-loom floor pit cutouts on far corners (safe from orbit path; reverted on retry!)
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(17, 7, 1, 2), "pit")
		# Cuttable frozen middle-rail tension wire (shoot/recall to unfreeze + stagger!)
		var mid_y: float = _rail_y(1)
		tethers.add_tether("tk_frost_wire", Vector2(arena_rect.position.x + 22.0, mid_y), Vector2(arena_rect.end.x - 22.0, mid_y), {
			"hp": 1.6, "cuttable": true, "color": "ice",
			"on_cut": func(_t: Dictionary) -> void:
				_mid_rail_frozen = false
				_on_curtain_burned(),
		})
		stage.darkness_pulse(0.58, 0.95)
		stage.shake(0.22)
		stage.play_sfx("tk_wood_unspool", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	if bool(h["cracks_armour"]) or src == LxHit.SOURCE_BEAM:
		_curtain_up = false
		_curtain_down_t = maxf(_curtain_down_t, 4.0)
		return dmg * 1.25
	if src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_ZIP or src == LxHit.SOURCE_PRISM:
		_curtain_up = false
		_curtain_down_t = maxf(_curtain_down_t, 3.5)
		return dmg * 1.15
	if _curtain_up and not is_punishable():
		# Silk curtain dampens head-on bolts; flank or burn rail for full damage!
		var rel: Vector2 = (h["origin"] as Vector2) - pos
		if rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) < 1.15:
			clank_t = 0.08
			return dmg * 0.55
	return dmg


func _on_death_start() -> void:
	stage.play_sfx("tk_wood_unspool", pos)


func _has_active_shield() -> bool:
	return _curtain_up and not is_punishable()


func _shield_color() -> Color:
	return (PAL["ice"] if _mid_rail_frozen else PAL["cream"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var inv: Vector2 = -pos
	# Draw 3 horizontal warp-rails across arena
	for i: int in range(3):
		var ry: float = _rail_y(i)
		var a: Vector2 = Vector2(arena_rect.position.x + 14.0, ry) + inv
		var b: Vector2 = Vector2(arena_rect.end.x - 14.0, ry) + inv
		var is_act: bool = i == _active_rail
		var col: Color = PAL["ice"] as Color if (i == 1 and _mid_rail_frozen) else (PAL["gold"] as Color if is_act else PAL["dusk"] as Color)
		draw_line(a.round(), b.round(), Color(col, 0.72 if is_act else 0.35), 1.4 if is_act else 1.0)
	# Active silk-fire spark racing along rail!
	if _rail_fire_idx >= 0:
		var fp: Vector2 = (Vector2(_rail_fire_x, _rail_y(_rail_fire_idx)) + inv).round()
		draw_circle(fp, 5.5, PAL["coral"] as Color)
		draw_circle(fp, 3.2, PAL["gold"] as Color)
		draw_circle(fp, 1.5, PAL["cream"] as Color)
	# Smoking wooden boot puffs after curtain burn!
	if _boot_smoke_t > 0.0:
		var sp: Vector2 = (off + Vector2(6.0, 6.0 - fmod(anim_t * 14.0, 8.0))).round()
		draw_circle(sp, 2.2, Color(PAL["stone"] as Color, 0.75))
