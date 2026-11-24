class_name LxKilnmotherBoss
extends LxCinderGolemBrain
## Ashen Kiln Boss (Island 6): the Kilnmother, a towering furnace with heavy slag armour (4.5).
## 3 phases, HP 13.5. Sunflare cracks her armour and stuns her for huge damage.
## Hitting her glowing belly during BELLOWS_GUST inhale (TELL) interrupts & staggers her 0.9s!
## P2 adds a 4-Way Furnace Cross-Blast (tell >= 0.55s) alongside Bellows Gust & Molten Rings.

signal gust_emitted(origin: Vector2, dir: Vector2, gust_range: float, half_width: float, source: LxEnemyBrain)

enum KilnMove { MOLTEN_RING, BELLOWS_GUST, FURNACE_CROSS }
enum RingStage { RING_1, PAUSE, RING_2 }

const KILN_ARMOUR_MAX: float = 4.5
const KILN_RING_MAX_R: float = 80.0
const KILN_RING_BAND: float = 10.5
const KILN_TRIGGER_R: float = 128.0
const RING_PAUSE_P3: float = 0.46

const GUST_TELL_P1: float = 0.60
const GUST_TELL_P3: float = 0.54
const GUST_COMMIT_TIME: float = 0.36
const GUST_RANGE: float = 132.0
const GUST_HALF_W: float = 30.0
const GUST_DMG_R: float = 60.0
const GUST_PUSH_WICK: float = 275.0
const GUST_PUSH_LANTERN: float = 175.0
const GUST_RECOVER: float = 1.25
const BELLY_INTERRUPT_STAGGER: float = 0.90

const CROSS_TELL_P2: float = 0.58
const CROSS_TELL_P3: float = 0.55
const CROSS_COMMIT_TIME: float = 0.36
const CROSS_RANGE: float = 114.0
const CROSS_HALF_W: float = 12.0
const CROSS_RECOVER: float = 1.30
const ROAR_TIME: float = 0.70

var active_move: int = KilnMove.MOLTEN_RING
var ring_stage: int = RingStage.RING_1
var move_cycle: int = 0
var gust_dir: Vector2 = Vector2.RIGHT
var gust_hit: bool = false
var gust_announced: bool = false
var cross_base_ang: float = 0.0
var cross_progress: float = 0.0
var cross_hit: bool = false
var _roaring: bool = false
var _armor_forged_roar: bool = false


func _init() -> void:
	super._init()
	kind = "kilnmother"
	boss_id = "kilnmother"
	island_id = 6
	is_boss = true
	max_hp = 13.5
	hp = 13.5
	armour_max = KILN_ARMOUR_MAX
	armour_hp = KILN_ARMOUR_MAX
	body_radius = 9.5
	routine_speed = 26.0
	leash_radius = 160.0
	notice_radius = 140.0
	tell_time = 0.66
	recover_time = 1.45
	give_up_time = 1.1
	attack_damage = 1.5
	reach = KILN_TRIGGER_R
	lunge_reach = KILN_TRIGGER_R
	shard_drop = 36


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	is_boss = true
	boss_id = str(spec.get("boss_id", "kilnmother"))
	island_id = int(spec.get("island_id", 6))
	armour_max = maxf(1.0, float(spec.get("armour_hp", KILN_ARMOUR_MAX)))
	armour_hp = armour_max
	armour_intact = true
	active_move = KilnMove.MOLTEN_RING
	ring_stage = RingStage.RING_1
	move_cycle = 0
	gust_dir = Vector2.from_angle(facing)
	gust_hit = false
	gust_announced = false
	cross_base_ang = facing
	cross_progress = 0.0
	cross_hit = false
	_roaring = false
	_armor_forged_roar = false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	if _roaring:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	# Hitting her glowing exposed belly during BELLOWS_GUST inhale (TELL) interrupts & staggers her 0.9s!
	if state == State.TELL and active_move == KilnMove.BELLOWS_GUST:
		var dmg: float = float(h["damage"])
		var orig: Vector2 = h["origin"] as Vector2
		var rel: Vector2 = orig - pos
		if bool(h.get("cracks_armour", false)) and armour_intact:
			_crack_armour()
		hp -= dmg
		wary = true
		flash_t = 0.18
		if rel.length() > 0.01:
			knock = -rel.normalized() * 72.0
		active_move = KilnMove.MOLTEN_RING
		_boss_impact(0.22, 84.0, 88.0)
		_emit_sfx("kilnmother_belly_interrupt")
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
		if not _check_phase_transition_bool():
			_release_token()
			state = State.STAGGER
			state_timer = BELLY_INTERRUPT_STAGGER
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	var sunflare_crack: bool = bool(h.get("cracks_armour", false)) and armour_intact
	var res: int = super.take_hit(hit)
	if is_alive() and sunflare_crack:
		hp = maxf(0.0, hp - float(h.get("damage", 0.0)) * 0.25)
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
	if is_alive() and res != HitResult.GLANCED and res != HitResult.BLOCKED:
		_check_phase_transition()
	return res


func _check_phase_transition_bool() -> bool:
	if phase < 2 and hp <= max_hp * 0.66 and hp > 0.001:
		_enter_phase(2)
		return true
	if phase < 3 and hp <= max_hp * 0.33 and hp > 0.001:
		_enter_phase(3)
		return true
	return false


func _check_phase_transition() -> void:
	_check_phase_transition_bool()


func _enter_phase(next_phase: int) -> void:
	phase = next_phase
	_roaring = true
	_armor_forged_roar = false
	active_move = KilnMove.MOLTEN_RING
	ring_stage = RingStage.RING_1
	stomp_progress = 0.0
	cross_progress = 0.0
	if phase == 2 and not armour_intact:
		armour_intact = true
		armour_hp = 2.0
		_armor_forged_roar = true
		_emit_sfx("shield_clang")
		var fred_f: bool = LxHudFx.flash_reduced()
		if Lx.player != null and is_instance_valid(Lx.player):
			if Lx.player.has_method("spawn_ring"):
				Lx.player.call("spawn_ring", pos, body_radius + 2.0, 44.0, 0.34, PAL["gold"] as Color, 1.5 if fred_f else 2.0)
				Lx.player.call("spawn_ring", pos, body_radius + 4.0, 32.0, 0.26, PAL["coral"] as Color, 1.2 if fred_f else 1.6)
			if Lx.player.has_method("spawn_sparks"):
				for fi: int in range(4):
					var fdir: Vector2 = Vector2.from_angle(PI * 0.25 + float(fi) * (PI * 0.5))
					Lx.player.call("spawn_sparks", pos, fdir, 3, (PAL["gold"] if fi % 2 == 0 else PAL["coral"]) as Color, 36.0, 92.0, 0.32)
	_release_token()
	state = State.NOTICE
	state_timer = ROAR_TIME
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.35)
	LxDamageFx.trigger_boss_phase_reset(self, next_phase)
	_emit_sfx("kilnmother_phase")


func _step_brain(dt: float) -> void:
	if state == State.NOTICE and _roaring:
		state_timer -= dt
		if state_timer <= 0.0:
			_roaring = false
			_armor_forged_roar = false
			state = State.POSITION
			cooldown = 0.35
		return
	super._step_brain(dt)


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if dist > KILN_TRIGGER_R:
		return false
	var chosen: int = KilnMove.MOLTEN_RING
	if phase >= 2:
		var slot_m: int = move_cycle % 3
		if _is_lantern_out() and dist <= GUST_RANGE and slot_m != 2:
			chosen = KilnMove.BELLOWS_GUST
		elif slot_m == 1:
			chosen = KilnMove.BELLOWS_GUST
		elif slot_m == 2:
			chosen = KilnMove.FURNACE_CROSS
		else:
			chosen = KilnMove.MOLTEN_RING if dist <= KILN_RING_MAX_R + 14.0 else KilnMove.FURNACE_CROSS
	else:
		var want_gust: bool = (_is_lantern_out() and dist <= GUST_RANGE) or (move_cycle % 2 == 1)
		if not want_gust and dist > KILN_RING_MAX_R + 14.0:
			want_gust = true
		chosen = KilnMove.BELLOWS_GUST if want_gust else KilnMove.MOLTEN_RING
	if not _claim_token():
		return false

	move_cycle += 1
	active_move = chosen
	state = State.TELL
	lunge_attack = false
	is_counter_attack = false
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01:
		facing = to_t.angle()

	if active_move == KilnMove.BELLOWS_GUST:
		gust_dir = to_t.normalized() if to_t.length() > 0.01 else Vector2.from_angle(facing)
		gust_hit = false
		gust_announced = false
		var base_g: float = GUST_TELL_P3 if phase >= 3 else GUST_TELL_P1
		last_tell_duration = _scaled_tell(base_g, false, attack_damage)
		_emit_sfx("kilnmother_bellows_inhale")
	elif active_move == KilnMove.FURNACE_CROSS:
		cross_base_ang = facing
		cross_progress = 0.0
		cross_hit = false
		var base_c: float = CROSS_TELL_P3 if phase >= 3 else CROSS_TELL_P2
		last_tell_duration = _scaled_tell(base_c, false, attack_damage)
		_emit_sfx("golem_stomp_tell")
	else:
		ring_stage = RingStage.RING_1
		stomp_progress = 0.0
		stomp_hit = false
		var base_r: float = 0.58 if phase >= 3 else tell_time
		last_tell_duration = _scaled_tell(base_r, false, attack_damage)
		_emit_sfx("golem_stomp_tell")

	state_timer = last_tell_duration
	_emit_attack_started()
	return true


func _step_tell(dt: float, target_pos: Vector2) -> void:
	if active_move == KilnMove.BELLOWS_GUST and state_timer > 0.22:
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.01:
			_turn_toward(to_t.angle(), 2.4, dt)
			gust_dir = Vector2.from_angle(facing)
	elif active_move == KilnMove.FURNACE_CROSS and state_timer > 0.22:
		var to_c: Vector2 = target_pos - pos
		if to_c.length() > 0.01:
			_turn_toward(to_c.angle(), 2.4, dt)
			cross_base_ang = facing
	state_timer -= dt
	if state_timer <= 0.0:
		_enter_commit()


func _enter_commit() -> void:
	if active_move == KilnMove.BELLOWS_GUST:
		state = State.COMMIT
		state_timer = GUST_COMMIT_TIME
		gust_hit = false
		gust_announced = false
		_boss_impact(0.20, 115.0, 110.0)
		_emit_sfx("kilnmother_bellows_gust")
		return
	if active_move == KilnMove.FURNACE_CROSS:
		state = State.COMMIT
		state_timer = CROSS_COMMIT_TIME
		cross_progress = 0.0
		cross_hit = false
		_boss_impact(0.22, 108.0, 104.0)
		_emit_sfx("kilnmother_bellows_gust")
		return
	ring_stage = RingStage.RING_1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if active_move == KilnMove.BELLOWS_GUST:
		_step_bellows_commit(dt)
		return
	if active_move == KilnMove.FURNACE_CROSS:
		_step_cross_commit(dt)
		return
	if ring_stage == RingStage.PAUSE:
		state_timer -= dt
		if state_timer <= 0.0:
			ring_stage = RingStage.RING_2
			state_timer = STOMP_COMMIT_TIME
			stomp_progress = 0.0
			stomp_hit = false
			_boss_impact(0.22, 98.0, 100.0)
			_emit_sfx("golem_stomp_shockwave")
		return

	state_timer = maxf(0.0, state_timer - dt)
	stomp_progress = 1.0 - clampf(state_timer / STOMP_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(STOMP_START_R, KILN_RING_MAX_R, stomp_progress)
	if not stomp_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= KILN_RING_BAND:
			stomp_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_shockwave_hit(push)
	if _is_lured() and _get_lantern_pos().distance_to(pos) <= ring_r:
		if Lx.events != null:
			Lx.events.lantern_struck.emit(_get_lantern_pos())

	if state_timer <= 0.0:
		if ring_stage == RingStage.RING_1 and phase >= 3:
			ring_stage = RingStage.PAUSE
			state_timer = _scaled_tell(RING_PAUSE_P3, false, attack_damage)
			stomp_progress = 0.0
			stomp_hit = false
			_emit_sfx("golem_stomp_tell")
		else:
			ring_stage = RingStage.RING_1
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, recover_time)
			last_recover_duration = state_timer


func _step_cross_commit(dt: float) -> void:
	state_timer = maxf(0.0, state_timer - dt)
	cross_progress = 1.0 - clampf(state_timer / CROSS_COMMIT_TIME, 0.0, 1.0)
	var cur_len: float = lerpf(14.0, CROSS_RANGE, cross_progress)
	if not cross_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		for ci: int in range(4):
			var cdir: Vector2 = Vector2.from_angle(cross_base_ang + float(ci) * (PI * 0.5))
			if Geometry2D.get_closest_point_to_segment(wp, pos, pos + cdir * cur_len).distance_to(wp) <= CROSS_HALF_W:
				cross_hit = true
				_emit_player_hit(cdir, attack_damage)
				break
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		for ci: int in range(4):
			var cdir_l: Vector2 = Vector2.from_angle(cross_base_ang + float(ci) * (PI * 0.5))
			if Geometry2D.get_closest_point_to_segment(lp, pos, pos + cdir_l * cur_len).distance_to(lp) <= CROSS_HALF_W + 3.0:
				if Lx.events != null:
					Lx.events.lantern_struck.emit(lp)
				break
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, CROSS_RECOVER)
		last_recover_duration = state_timer


func _step_bellows_commit(dt: float) -> void:
	if not gust_announced:
		gust_announced = true
		gust_emitted.emit(pos, gust_dir, GUST_RANGE, GUST_HALF_W, self)
		if world_ctx != null and world_ctx.has_method("on_enemy_gust"):
			world_ctx.call("on_enemy_gust", self, pos, gust_dir, GUST_RANGE, GUST_HALF_W)
	var end_p: Vector2 = pos + gust_dir * GUST_RANGE
	if _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, pos, end_p).distance_to(wp) <= GUST_HALF_W:
			if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil"):
				Lx.player.call("apply_recoil", gust_dir * GUST_PUSH_WICK * dt)
			if not gust_hit and pos.distance_to(wp) <= GUST_DMG_R:
				gust_hit = true
				_emit_player_hit(gust_dir, 1.0)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= GUST_HALF_W + 6.0:
			_push_thrown_lantern(dt)
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, GUST_RECOVER)
		last_recover_duration = state_timer


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


func _body_color() -> Color:
	if armour_intact:
		return (PAL["dusk"] as Color) if phase >= 3 else (PAL["stone"] as Color)
	return (PAL["gold"] as Color) if phase >= 3 else (PAL["coral"] as Color)


func _draw_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var belly_exposed: bool = active_move == KilnMove.BELLOWS_GUST and state == State.TELL
	if _sprite_sheet == null:
		# Kiln chimney crown + glowing furnace belly
		draw_rect(Rect2(off + Vector2(-4.0, -body_radius - 5.0), Vector2(8.0, 5.0)), PAL["night"] as Color, true)
		draw_rect(Rect2(off + Vector2(-2.5, -body_radius - 4.0), Vector2(5.0, 3.0)), PAL["apricot"] as Color, true)
		draw_circle(off + Vector2(0.0, 1.0), 4.8 if belly_exposed else 4.2, PAL["night"] as Color)
		draw_circle(off + Vector2(0.0, 1.0), 3.4 if belly_exposed else 2.8, (PAL["cream"] as Color) if (belly_exposed or not armour_intact) else (PAL["coral"] as Color))
	if armour_intact:
		LxDamageFx.draw_armour_plates(self, off, body_radius + 3.5, 2.0, armour_hp, armour_max)
	if belly_exposed:
		# Blazing belly target reticle during inhale TELL (shoot to interrupt & stagger!)
		var br: float = 5.5 + (0.0 if LxHudFx.flash_reduced() else 1.2 * sin(anim_t * 22.0))
		var side: Vector2 = Vector2(-gust_dir.y, gust_dir.x)
		var g_prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var dmg_pt: Vector2 = off + gust_dir * GUST_DMG_R
		var end_pt: Vector2 = off + gust_dir * GUST_RANGE
		LxBossTelegraphFx.draw_ground_danger_lane(self, dmg_pt, end_pt, GUST_HALF_W, g_prog, anim_t, "apricot", "gold")
		LxBossTelegraphFx.draw_ground_danger_lane(self, off, dmg_pt, GUST_HALF_W, g_prog, anim_t, "coral", "gold")
		draw_arc(c + Vector2(0.0, 1.0), br, 0.0, TAU, 16, PAL["gold"] as Color, 1.8)
		draw_circle(c + Vector2(0.0, 1.0), 2.5, PAL["cream"] as Color)
		var pull_d: float = lerpf(46.0, 12.0, g_prog)
		draw_line((off + gust_dir * pull_d - side * 14.0).round(), (off + gust_dir * (pull_d - 6.0)).round(), PAL["apricot"] as Color, 1.3)
		draw_line((off + gust_dir * pull_d + side * 14.0).round(), (off + gust_dir * (pull_d - 6.0)).round(), PAL["apricot"] as Color, 1.3)
		if state_timer <= 0.35:
			var g_urg: float = 1.0 - clampf(state_timer / 0.35, 0.0, 1.0)
			LxBossTelegraphFx.draw_ground_danger_ring(self, off + gust_dir * (GUST_DMG_R * 0.72), 15.0, g_urg, anim_t, "coral", "gold")
	elif active_move == KilnMove.BELLOWS_GUST and state == State.COMMIT:
		var side2: Vector2 = Vector2(-gust_dir.y, gust_dir.x)
		var g_len: float = GUST_RANGE * 0.88
		for idx: int in range(-1, 2):
			var s_off: Vector2 = side2 * float(idx) * (GUST_HALF_W * 0.48)
			var l_end: float = g_len if idx == 0 else g_len * 0.86
			var p0: Vector2 = (off + s_off).round()
			var p1: Vector2 = (off + s_off + gust_dir * l_end).round()
			draw_line(p0, p1, PAL["wine"] as Color, 7.2 if idx == 0 else 5.2)
			draw_line(p0, p1, PAL["coral"] as Color, 5.2 if idx == 0 else 3.6)
			draw_line(p0, p1, PAL["apricot"] as Color, 3.4 if idx == 0 else 2.2)
			draw_line(p0, p1, PAL["gold"] as Color, 2.0 if idx == 0 else 1.2)
			if idx == 0:
				draw_line(p0, p1, PAL["cream"] as Color, 1.1)
		for ei: int in range(6):
			var et: float = fposmod(anim_t * 4.0 + float(ei) * 0.167, 1.0)
			var lat: float = sin(anim_t * 15.0 + float(ei) * 2.2) * (GUST_HALF_W * 0.78)
			var ep: Vector2 = (off + gust_dir * lerpf(10.0, g_len, et) + side2 * lat).round()
			draw_line(ep, (ep - gust_dir * 5.0).round(), PAL["coral"] as Color, 1.5)
			draw_circle(ep, 1.6, PAL["gold"] as Color)
			draw_circle(ep, 0.8, PAL["cream"] as Color)
	elif active_move == KilnMove.FURNACE_CROSS and state == State.TELL:
		var hot_c: bool = state_timer <= 0.22
		var c_urg: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		for ci: int in range(4):
			var cdir: Vector2 = Vector2.from_angle(cross_base_ang + float(ci) * (PI * 0.5))
			LxBossTelegraphFx.draw_ground_danger_lane(self, c, c + cdir * CROSS_RANGE, CROSS_HALF_W, c_urg, anim_t, "coral", "gold")
		draw_circle(c, 3.0 if hot_c else 2.2, (PAL["cream"] if hot_c else PAL["gold"]) as Color)
	elif active_move == KilnMove.FURNACE_CROSS and state == State.COMMIT:
		var cur_len: float = lerpf(14.0, CROSS_RANGE, cross_progress)
		for ci: int in range(4):
			var cdir: Vector2 = Vector2.from_angle(cross_base_ang + float(ci) * (PI * 0.5))
			var cend: Vector2 = (c + cdir * cur_len).round()
			draw_line(c, cend, PAL["wine"] as Color, 9.0)
			draw_line(c, cend, PAL["coral"] as Color, 6.0)
			draw_line(c, cend, PAL["apricot"] as Color, 3.6)
			draw_line(c, cend, PAL["gold"] as Color, 2.0)
			draw_line(c, cend, PAL["cream"] as Color, 1.0)
			draw_circle(cend, 2.4, PAL["gold"] as Color)
			draw_circle(cend, 1.2, PAL["cream"] as Color)
	elif active_move == KilnMove.MOLTEN_RING and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_danger_ring(self, off, KILN_RING_MAX_R, prog, anim_t, "coral", "gold")
		draw_arc(off, lerpf(KILN_RING_MAX_R, STOMP_START_R + 6.0, prog), 0.0, TAU, 28, (PAL["cream"] if state_timer <= 0.14 else PAL["apricot"]) as Color, 1.6)
	elif active_move == KilnMove.MOLTEN_RING and state == State.COMMIT:
		if ring_stage == RingStage.PAUSE:
			var p_urg: float = 1.0 - clampf(state_timer / maxf(RING_PAUSE_P3, 0.05), 0.0, 1.0)
			LxBossTelegraphFx.draw_ground_danger_ring(self, off, KILN_RING_MAX_R, p_urg, anim_t, "coral", "gold")
			var pr: float = KILN_RING_MAX_R * 0.5 + (0.0 if LxHudFx.flash_reduced() else 2.0 * sin(anim_t * 18.0))
			var hot_k: bool = state_timer <= 0.14
			draw_arc(off, pr + 2.0, 0.0, TAU, 24, (PAL["apricot"] if hot_k else PAL["coral"]) as Color, 2.0)
			draw_arc(off, pr, 0.0, TAU, 24, (PAL["cream"] if hot_k else PAL["gold"]) as Color, 2.4 if hot_k else 2.2)
			for ki: int in range(4):
				var kd: Vector2 = Vector2.from_angle(float(ki) * (TAU * 0.25))
				draw_line((off + kd * (pr - 3.0)).round(), (off + kd * (pr + 4.0)).round(), PAL["cream"] as Color, 1.2)
		else:
			var ring_r: float = lerpf(STOMP_START_R, KILN_RING_MAX_R, stomp_progress)
			draw_arc(off, ring_r + 2.8, 0.0, TAU, 36, PAL["wine"] as Color, 2.5)
			draw_arc(off, ring_r, 0.0, TAU, 36, PAL["coral"] as Color, 3.8)
			draw_arc(off, maxf(2.0, ring_r - 2.0), 0.0, TAU, 28, PAL["apricot"] as Color, 2.0)
			draw_arc(off, maxf(2.0, ring_r - 3.6), 0.0, TAU, 24, PAL["gold"] as Color, 1.2)
			for si: int in range(8):
				var sa: float = anim_t * 1.9 + float(si) * (TAU / 8.0)
				var sd: Vector2 = Vector2.from_angle(sa)
				var st: Vector2 = Vector2(-sd.y, sd.x)
				var base_c: Vector2 = off + sd * maxf(2.0, ring_r - 1.0)
				var tip: Vector2 = (off + sd * (ring_r + 6.5)).round()
				draw_line((base_c - st * 3.0).round(), tip, PAL["coral"] as Color, 1.6)
				draw_line((base_c + st * 3.0).round(), tip, PAL["coral"] as Color, 1.6)
				draw_line(base_c.round(), tip, PAL["gold"] as Color, 1.2)
				draw_circle(tip, 1.1, PAL["apricot"] as Color)
	elif _roaring:
		var fred_r: bool = LxHudFx.flash_reduced()
		var rp: float = 1.0 - clampf(state_timer / ROAR_TIME, 0.0, 1.0)
		var rr: float = body_radius + 11.0 + rp * 18.0
		draw_arc(off, rr + 2.5, 0.0, TAU, 28, PAL["coral"] as Color, 2.2)
		draw_arc(off, rr, 0.0, TAU, 28, PAL["gold"] as Color, 2.4)
		if _armor_forged_roar:
			var snap_r: float = lerpf(body_radius + 16.0, body_radius + 3.5, clampf(rp * 1.45, 0.0, 1.0))
			for fi: int in range(4):
				var fa: float = PI * 0.25 + float(fi) * (PI * 0.5)
				var fcol: Color = (PAL["gold"] if (fred_r or int(anim_t * 14.0) % 2 == 0) else PAL["coral"]) as Color
				draw_arc(off, snap_r + 1.4, fa - 0.42, fa + 0.42, 6, PAL["coral"] as Color, 1.8)
				draw_arc(off, snap_r, fa - 0.38, fa + 0.38, 6, fcol, 2.0)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.18, 1.54, 0.44)
