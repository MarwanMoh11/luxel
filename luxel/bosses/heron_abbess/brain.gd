class_name LxHeronAbbessBoss
extends LxBossBase
## Drowned Conservatory Keeper Boss (Island 4, conservatory_r10): The Heron Abbess (Bible §4.7).
## 3 phases (66%/33%) on LxBossBase. Porcelain-feather mantle reduces ground bolt spam outside
## punish windows (armour glint + reduced chip); Beak-Stuck recovery, Wings-gliding shots, and
## P3 Gale-Leap 2x air-stagger intercepts reward aerial mastery!
## Island 4 rule: P2 Shattered Skylights create 4 corner thermal updraft columns that counter
## Wing Gust pushback and lift over P3 Clock-Chime Double Ripple shockwaves!

signal gust_emitted(origin: Vector2, dir: Vector2, gust_range: float, half_width: float, source: LxEnemyBrain)

enum BossMove { STAB, WING_GUST, SHOCKWAVE_RING, GALE_LEAP }

const GUST_TELL_P1: float = 0.56
const GUST_COMMIT_TIME: float = 0.38
const GUST_RANGE: float = 136.0
const GUST_HALF_W: float = 28.0
const GUST_DMG_R: float = 58.0
const GUST_PUSH_WICK: float = 240.0
const GUST_PUSH_LANTERN: float = 150.0
const RING_START_R: float = 10.0
const RING_MAX_R: float = 78.0
const LEAP_AIR_TIME: float = 0.36
const LEAP_HEIGHT: float = 24.0
const LEAP_RING_MAX_R: float = 74.0
const DOUBLE_RIPPLE_GAP: float = 0.35
const SKYLIGHT_UPDRAFT_R: float = 22.0
const ROAR_TIME: float = 0.65

# Compat fields referenced by tests/luxel/boss_qa_capture.gd & visuals.gd
var active_move: int = BossMove.STAB
var gust_dir: Vector2 = Vector2.RIGHT
var gust_hit: bool = false
var gust_announced: bool = false
var ring_progress: float = 0.0
var leap_stage: int = 0
var leap_from: Vector2 = Vector2.ZERO
var leap_to: Vector2 = Vector2.ZERO
var abbess_z: float = 0.0
var beak_stuck: bool = false
var _roaring: bool = false
var _skylights: Array[Dictionary] = []  # [{pos, shattered, catch_cd}]

var _stab_dir: Vector2 = Vector2.RIGHT
var _double_ripple_done: bool = false
var _clank_sfx_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "heron_abbess"
	boss_id = "heron_abbess"
	boss_name_key = "BOSS_ABBESS"
	island_id = 4
	is_miniboss = false
	reward_heart = "full"
	music_cue = "island4_boss_p1"
	music_p2_cue = "island4_boss_p2"
	max_hp = 136.0
	hp = 136.0
	body_radius = 9.0
	move_speed = 42.0
	intro_duration = 0.90
	stagger_threshold = 16.0
	stagger_duration = 1.60
	punish_dmg_mult = 1.25
	post_recover_cd = 0.34
	shard_drop = 42
	death_duration = 2.4


func _configure_boss(_spec: Dictionary) -> void:
	if world_ctx != null and str(world_ctx.get("current_region_id")) == "conservatory_r10":
		arena_rect = Rect2(136.0, 88.0, 176.0, 80.0)
	configure_phases([0.68, 0.38])

	# Attack 1: Spear Stab — razor beak lunge leaving beak stuck in floor during RECOVER!
	register_attack("spear_stab", {
		"weight": 1.25, "tell": 0.54, "commit": 0.30, "recover": 1.25, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = BossMove.STAB
			beak_stuck = false
			_stab_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _stab_dir.angle()
			ground.warn_lane(pos, pos + _stab_dir * 48.0, 8.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("heron_stare", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_lane(pos, _stab_dir, 3, 112.0, 0.10, {"color": "ice", "source": "heron_spear", "damage": 0.5})
			stage.shake(0.16)
			stage.play_sfx("heron_stab", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			var next_p: Vector2 = pos + _stab_dir * 86.0 * dt
			var c_s: Vector2 = arena_rect.get_center()
			if next_p.distance_to(c_s) <= 34.0:
				move_boss(_stab_dir * 86.0 * dt, false)
			check_contact_damage(18.0, _stab_dir, 0.5, "heron_spear"),
	})

	# Attack 2: Wing Gust — broad gale corridor pushing Wick/lantern unless sheltered in a skylight!
	register_attack("wing_gust", {
		"weight": 1.20, "tell": GUST_TELL_P1, "commit": GUST_COMMIT_TIME, "recover": 1.15, "cooldown": 1.50,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = BossMove.WING_GUST
			beak_stuck = false
			gust_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = gust_dir.angle()
			gust_hit = false
			gust_announced = false
			ground.warn_lane(pos, pos + gust_dir * 48.0, 10.0, last_tell_duration, 0.0, "sky", "ice")
			if not arena_rect.grow(-11.0).has_point(tgt):
				ground.warn_ring(tgt, 20.0, last_tell_duration + 0.04, 1.0, "coral", "gold")
			stage.play_sfx("heron_gust_inhale", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			gust_announced = true
			gust_emitted.emit(pos, gust_dir, GUST_RANGE, GUST_HALF_W, self)
			if world_ctx != null and world_ctx.has_method("on_enemy_gust"):
				world_ctx.call("on_enemy_gust", self, pos, gust_dir, GUST_RANGE, GUST_HALF_W)
			patterns.emit_fan(pos, gust_dir, 5 if phase >= 3 else 3, 0.92, 108.0, {"color": "sky", "source": "wing_gust", "damage": 0.5})
			stage.shake(0.16)
			stage.play_sfx("heron_gust_fire", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			var end_p: Vector2 = pos + gust_dir * GUST_RANGE
			if _has_player():
				var wp: Vector2 = _get_wick_pos()
				if Geometry2D.get_closest_point_to_segment(wp, pos, end_p).distance_to(wp) <= GUST_HALF_W:
					var push_probe: Vector2 = wp + gust_dir * 24.0
					var safe_push: bool = world_ctx == null or not world_ctx.has_method("is_lethal_void_at") or not bool(world_ctx.call("is_lethal_void_at", push_probe))
					if safe_push and Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil") and not _in_active_skylight(wp):
						Lx.player.call("apply_recoil", gust_dir * 90.0 * dt)
					if not gust_hit and pos.distance_to(wp) <= 44.0:
						gust_hit = true
						emit_boss_damage(gust_dir, 0.5, "wing_gust", pos, true)
			if _is_lantern_out():
				var lp: Vector2 = _get_lantern_pos()
				if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= GUST_HALF_W + 4.0:
					_push_thrown_lantern(dt),
	})

	# Attack 3: Feather Barrage — aimed glass-feather volley + curving plume boomerangs
	register_attack("feather_barrage", {
		"weight": 1.15, "tell": 0.54, "commit": 0.36, "recover": 1.05, "cooldown": 1.50,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = BossMove.STAB
			beak_stuck = false
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			ground.warn_sector(pos, d.angle() - 0.55, d.angle() + 0.55, 42.0, last_tell_duration, 0.0, "sky", "gold")
			if not arena_rect.grow(-11.0).has_point(tgt):
				ground.warn_ring(tgt, 20.0, last_tell_duration + 0.04, 1.0, "sky", "gold")
			stage.play_sfx("heron_ring_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 5 if phase >= 3 else 3, 0.78, 108.0, {"color": "sky", "source": "feather_fan", "damage": 0.5})
			patterns.emit_boomerang(pos, d.rotated(0.32), 110.0, 0.68, 0.65, {"color": "ice", "source": "feather_plume", "damage": 0.5})
			if phase >= 3:
				patterns.emit_boomerang(pos, d.rotated(-0.32), 110.0, 0.68, -0.65, {"color": "gold", "source": "feather_plume", "damage": 0.5})
			stage.shake(0.14)
			stage.play_sfx("heron_ring_fire", pos),
	})

	# Attack 4 (P2/P3): Choir Shockwave — expanding conservatory wave + inner glass halo
	register_attack("choir_shockwave", {
		"phases": [2, 3], "weight": 1.65, "tell": 0.56, "commit": 0.38, "recover": 1.18, "cooldown": 1.60,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			active_move = BossMove.SHOCKWAVE_RING
			beak_stuck = false
			ring_progress = 0.0
			ground.warn_ring(pos, 28.0, last_tell_duration, 0.0, "sky", "coral")
			stage.play_sfx("heron_ring_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 9, 98.0, gap_a, 1.18, {"color": "sky", "source": "choir_ring", "damage": 0.5})
			patterns.emit_orbit(pos, 2, 28.0, 1.7, 1.25, {"color": "ice", "source": "glass_halo", "damage": 0.5})
			stage.shake(0.20)
			stage.play_sfx("heron_ring_fire", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			ring_progress = clampf(el / 0.38, 0.0, 1.0),
	})

	# Attack 5 (P3): Gale-Leap & Clock-Chime Double Ripple (air-intercept = 2x stagger!)
	register_attack("gale_leap", {
		"phases": [3], "weight": 3.40, "tell": 0.54, "commit": 0.78, "recover": 1.25, "cooldown": 1.10,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = BossMove.GALE_LEAP
			beak_stuck = false
			leap_stage = 0
			leap_from = pos
			var c_g: Vector2 = arena_rect.get_center()
			leap_to = c_g + (tgt - c_g).limit_length(24.0)
			_double_ripple_done = false
			ring_progress = 0.0
			ground.warn_ring(leap_to, 16.0, last_tell_duration + LEAP_AIR_TIME * 0.7, 0.5, "coral", "gold")
			stage.play_sfx("heron_gust_inhale", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			leap_from = pos
			leap_stage = 0
			state_timer = LEAP_AIR_TIME + DOUBLE_RIPPLE_GAP * get_tell_scale() + 0.07
			stage.play_sfx("heron_gust_fire", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, el: float) -> void:
			var gap_s: float = DOUBLE_RIPPLE_GAP * get_tell_scale()
			if el < LEAP_AIR_TIME:
				var u: float = clampf(el / LEAP_AIR_TIME, 0.0, 1.0)
				abbess_z = sin(u * PI) * LEAP_HEIGHT
				move_boss(leap_from.lerp(leap_to, u) - pos, true)
			elif leap_stage == 0:
				leap_stage = 1
				abbess_z = 0.0
				var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
				patterns.emit_gap_ring(pos, 9, 102.0, gap_a, 1.16, {"color": "sky", "source": "gale_ripple_1", "damage": 0.5})
				ground.warn_ring(pos, LEAP_RING_MAX_R, gap_s, 0.0, "gold", "coral")
				stage.shake(0.22)
				stage.play_sfx("heron_ring_fire", pos)
			else:
				ring_progress = clampf((el - LEAP_AIR_TIME) / maxf(gap_s, 0.05), 0.0, 1.0)
				if not _double_ripple_done and el >= LEAP_AIR_TIME + gap_s:
					_double_ripple_done = true
					var gap_b: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
					patterns.emit_gap_ring(pos, 10, 108.0, gap_b, 1.16, {"color": "gold", "source": "gale_ripple_2", "damage": 0.5})
					stage.shake(0.20)
					stage.play_sfx("clockwork_chime", pos)
					stage.play_sfx("heron_ring_fire", pos),
	})


func is_flying() -> bool:
	return active_move == BossMove.GALE_LEAP and boss_state == BossState.COMMIT and leap_stage == 0 and abbess_z > 5.0


func _on_reset_encounter() -> void:
	active_move = BossMove.STAB
	gust_dir = Vector2.from_angle(facing)
	gust_hit = false
	gust_announced = false
	ring_progress = 0.0
	leap_stage = 0
	leap_from = pos
	leap_to = pos
	abbess_z = 0.0
	beak_stuck = false
	_roaring = false
	_double_ripple_done = false
	_clank_sfx_cd = 0.0
	_skylights.clear()
	var c: Vector2 = arena_rect.get_center()
	var sx: float = minf(84.0, arena_rect.size.x * 0.32)
	var sy: float = minf(48.0, arena_rect.size.y * 0.30)
	for off_v: Vector2 in [Vector2(-sx, -sy), Vector2(sx, -sy), Vector2(-sx, sy), Vector2(sx, sy)]:
		_skylights.append({"pos": clamp_to_arena(c + off_v), "shattered": false, "catch_cd": 0.0})


func _enter_phase(next_phase: int) -> void:
	# Compat hook for tests/luxel/boss_qa_capture.gd
	phase = clampi(next_phase, 1, 3)
	if not phases_reached.has(phase):
		phases_reached.append(phase)
	_on_phase_enter(phase)


func _on_phase_enter(new_phase: int) -> void:
	_roaring = true
	beak_stuck = false
	abbess_z = 0.0
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		if not _skylights.is_empty():
			_skylights[0]["shattered"] = true
		_carve_safe_tile_near(Vector2(104.0, 72.0), "water")
		_carve_safe_tile_near(Vector2(344.0, 168.0), "water")
		props.spawn_pillar(clamp_to_arena(c + Vector2(-52.0, -16.0)), 4.5, "abbess_glass_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(52.0, -16.0)), 4.5, "abbess_glass_e")
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.24)
		stage.play_sfx("heron_abbess_phase", pos)
	elif new_phase == 3:
		for sk: Dictionary in _skylights:
			sk["shattered"] = true
		_carve_safe_tile_near(Vector2(104.0, 168.0), "water")
		_carve_safe_tile_near(Vector2(344.0, 88.0), "water")
		stage.darkness_pulse(0.70, 1.1)
		stage.shake(0.28)
		stage.play_sfx("heron_abbess_phase", pos)
		stage.play_sfx("clockwork_chime", pos)


func _on_attack_recover_start(attack_id: String) -> void:
	abbess_z = 0.0
	beak_stuck = (attack_id == "spear_stab")
	if beak_stuck:
		stage.play_sfx("heron_beak_stuck", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if boss_state != BossState.PHASE_SHIFT:
		_roaring = false
	if boss_state != BossState.RECOVER:
		beak_stuck = false
	if boss_state != BossState.COMMIT:
		abbess_z = 0.0
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	if phase >= 2:
		_step_skylights(dt)


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	var c: Vector2 = arena_rect.get_center()
	var desired: Vector2 = c + (target - c).limit_length(24.0).rotated(0.45 * _orbit_side)
	move_boss((desired - pos).limit_length(move_speed * dt), false)
	_face_point(target, 4.2, dt)


func _step_skylights(dt: float) -> void:
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var gliding: bool = wick != null and not wick.dead and wick.is_gliding()
	var bolts: Array = wick.bolts if wick != null else []
	for sk: Dictionary in _skylights:
		sk["catch_cd"] = maxf(0.0, float(sk["catch_cd"]) - dt)
		var sp: Vector2 = sk["pos"] as Vector2
		if not bool(sk["shattered"]):
			for bi: int in range(bolts.size() - 1, -1, -1):
				var b_v: Variant = bolts[bi]
				var bp: Vector2 = Vector2.INF
				var b_prev: Vector2 = Vector2.INF
				var b_dir: Vector2 = Vector2.UP
				if b_v is Object and is_instance_valid(b_v as Object):
					var bo: Object = b_v as Object
					var pos_v: Variant = bo.get("pos")
					if pos_v is Vector2:
						bp = pos_v as Vector2
					var prev_v: Variant = bo.get("prev_pos")
					if prev_v is Vector2:
						b_prev = prev_v as Vector2
					var dir_v: Variant = bo.get("dir")
					if dir_v is Vector2 and (dir_v as Vector2).length_squared() > 0.01:
						b_dir = (dir_v as Vector2).normalized()
				elif b_v is Dictionary and bool((b_v as Dictionary).get("active", true)):
					var bd: Dictionary = b_v as Dictionary
					var dp_v: Variant = bd.get("pos", Vector2.INF)
					if dp_v is Vector2:
						bp = dp_v as Vector2
				if not bp.is_finite():
					continue
				var hit_d: float = Geometry2D.get_closest_point_to_segment(sp, b_prev, bp).distance_to(sp) if b_prev.is_finite() else bp.distance_to(sp)
				if hit_d <= 15.0:
					sk["shattered"] = true
					if b_v is Dictionary:
						(b_v as Dictionary)["active"] = false
					else:
						bolts.remove_at(bi)
					if wick != null:
						wick.spawn_sparks(sp, -b_dir, 6, PAL["ice"] as Color, 32.0, 92.0, 0.22)
						wick.spawn_sparks(sp, b_dir, 4, PAL["cream"] as Color, 24.0, 74.0, 0.18)
						wick.spawn_ring(sp, 4.0, SKYLIGHT_UPDRAFT_R, 0.24, PAL["ice"] as Color, 1.4)
					stage.play_sfx("seal_break", sp)
					break
		elif gliding and wick.move_wings != null and wick.global_position.distance_to(sp) <= SKYLIGHT_UPDRAFT_R + 6.0:
			wick.move_wings.refresh_glide(1.25, 2.2)
			if float(sk["catch_cd"]) <= 0.0:
				sk["catch_cd"] = 0.45
				stage.play_sfx("heron_gust_fire", sp)


func _in_active_skylight(pt: Vector2) -> bool:
	if phase < 2:
		return false
	for sk: Dictionary in _skylights:
		if bool(sk["shattered"]) and pt.distance_to(sk["pos"] as Vector2) <= SKYLIGHT_UPDRAFT_R + 4.0:
			return true
	return false


func _push_thrown_lantern(dt: float) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var lan_v: Variant = Lx.player.get("lantern")
	if lan_v is Object and is_instance_valid(lan_v as Object):
		var lan: Object = lan_v as Object
		var st_v: Variant = lan.get("state")
		if st_v != null and (int(st_v) == 1 or int(st_v) == 2):
			var cur_v: Variant = lan.get("pos")
			if cur_v is Vector2:
				var pushed: Vector2 = (cur_v as Vector2) + gust_dir * GUST_PUSH_LANTERN * dt
				lan.set("pos", pushed)
				if lan is Node2D:
					(lan as Node2D).global_position = pushed.round()


func take_hit(hit: LxHit) -> int:
	if not engaged and boss_state != BossState.DEATH and hit != null:
		if world_ctx != null and str(world_ctx.get("current_region_id")) == "conservatory_r10":
			if _get_wick_pos().distance_to(pos) <= 92.0:
				engage()
	return super.take_hit(hit)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var gliding: bool = wick != null and not wick.dead and wick.is_gliding()
	var is_beam: bool = src == LxHit.SOURCE_BEAM or bool(h["pierce"]) or bool(h["cracks_armour"])
	var heavy: bool = is_beam or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE]

	# P3 Gale-Leap 2x air-stagger intercept!
	if is_flying() and (gliding or heavy):
		abbess_z = 0.0
		leap_stage = 0
		add_stagger(stagger_threshold)
		stage.play_sfx("hopper_air_stagger", pos)
		return dmg * 2.0

	if boss_state == BossState.STAGGER:
		return dmg * (1.55 if is_beam else 1.25)
	if beak_stuck:
		return dmg * (1.45 if is_beam else 1.15)
	if is_punishable():
		return dmg * (1.40 if is_beam else (1.15 if gliding else 1.0))
	if is_beam:
		return dmg * 1.45
	if heavy:
		return dmg * 0.55
	if gliding:
		return dmg * 1.15

	# Porcelain-feather mantle outside punish windows: reduced ground bolt chip + clear glint!
	clank_t = 0.12
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("crystal_clank", pos)
	return dmg * 0.30


func _on_death_start() -> void:
	abbess_z = 0.0
	beak_stuck = false
	stage.revert_tiles(world_ctx)
	stage.play_sfx("heron_abbess_phase", pos)


func _build_feather_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [tgt]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	if phase >= 2:
		out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.5)))
	if phase >= 3:
		out.append(corners[2])
	return out


func _carve_safe_tile_near(world_pt: Vector2, tile_kind: String) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return
	var tx: int = int(floorf(world_pt.x / 16.0))
	var ty: int = int(floorf(world_pt.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if str(world_ctx.call("tile_at", cp)) == "ground" and cp.distance_to(home) > 32.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), tile_kind)


func _visual_offset() -> Vector2:
	return Vector2(0.0, -abbess_z)


func _body_color() -> Color:
	return (PAL["ice"] if phase >= 3 else (PAL["sky"] if phase >= 2 else PAL["stone"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	LxHeronAbbessVisuals.draw_extra(self, off)
	var c: Vector2 = off.round()
	if clank_t > 0.0:
		draw_arc(c, body_radius + 5.0, facing - 1.1, facing + 1.1, 16, PAL["cream"] as Color, 2.2)
		draw_arc(c, body_radius + 7.0, facing - 0.85, facing + 0.85, 12, PAL["ice"] as Color, 1.2)
	elif beak_stuck:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 20, PAL["gold"] as Color, 1.8)
	elif is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 18, PAL["gold"] as Color, 1.4)
