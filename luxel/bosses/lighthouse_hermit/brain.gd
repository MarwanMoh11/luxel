class_name LxLighthouseHermitBoss
extends LxBossBase
## Tidewater Harbor Grand Boss (Island 2, `lighthouse_r10`): Lighthouse Hermit (Bible §4.7).
## 3 phases (66%/33%) on LxBossBase. Armored brass-and-glass cupola shell chips plain bolts outside
## punish windows with a crystal armour glint; Prism-Split / Blue banks bypass shell (1.35x) and
## self-reflecting his Sweeping Lamp Beam off a room LxMirror triggers 1.5s stagger + 4.5s 1.5x crack!
## Preserves B2 upgrades: P2 Tower Tide (`tower_tide -> "high"`, outer pocket flood, drifting mirrors
## pinned by Ballast Clamp, Tide Ring Buoy Mines); P3 Storm Eclipse twilight dimming, Double-Sweep
## Counter-Spin, Whirlpool Shell-Pull (`LxFields`), and cracked-shell tiny crab leak-plugging beat!

const ArenaFx := preload("res://luxel/bosses/lighthouse_hermit/arena_fx.gd")

enum BossMove { NONE, LAMP_BEAM, TIDE_RING, WHIRLPOOL_PULL }
enum BeamStage { SWEEP_1, COUNTER_PAUSE, SWEEP_2 }

const SHIELD_MAX_HP: float = 5.0
const SHIELD_GONE_DUR: float = 5.2
const BEAM_RANGE: float = 142.0
const BEAM_HALF_W: float = 9.0
const BEAM_SWEEP_ARC_P1: float = 1.25
const BEAM_SWEEP_ARC_P3: float = 1.50
const BEAM_SWEEP_TIME: float = 0.68
const BEAM_REVERSE_PAUSE: float = 0.36
const BEAM_REVERSE_TIME: float = 0.52
const LAMP_CRACK_DURATION: float = 4.50
const LAMP_CRACK_MULT: float = 1.50
const TIDE_START_R: float = 10.0
const TIDE_MAX_R: float = 52.0
const TIDE_BAND: float = 9.0
const BEAM_BURN_RANGE: float = 48.0

# Compat fields referenced by tests/luxel/boss_qa_capture.gd
var active_move: int = BossMove.NONE
var _roaring: bool = false

var shield_max: float = SHIELD_MAX_HP
var shield_hp: float = SHIELD_MAX_HP
var shield_gone_t: float = 0.0
var lamp_cracked_t: float = 0.0

var _beam_stage: int = BeamStage.SWEEP_1
var _sweep_start_ang: float = 0.0
var _sweep_dir: float = 1.0
var _beam_angle: float = 0.0
var _beam_hit: bool = false
var _beam_hit_len: float = BEAM_RANGE
var _reflected_active: bool = false
var _reflect_origin: Vector2 = Vector2.ZERO
var _reflect_end: Vector2 = Vector2.ZERO
var _beam_light_t: float = 0.0
var _mirror_ping_t: float = 0.0
var _tide_progress: float = 0.0
var _tide_hit: bool = false
var _pull_hit: bool = false
var _aim_dir: Vector2 = Vector2.DOWN
var _clank_sfx_cd: float = 0.0
var _arena: ArenaFx = null


func _init() -> void:
	super._init()
	kind = "lighthouse_hermit"
	boss_id = "lighthouse_hermit"
	boss_name_key = "BOSS_HERMIT"
	island_id = 2
	is_miniboss = false
	reward_heart = "full"
	music_cue = "island2_boss_p1"
	music_p2_cue = "island2_boss_p2"
	max_hp = 136.0
	hp = 136.0
	body_radius = 9.0
	move_speed = 34.0
	stagger_threshold = 15.0
	stagger_duration = 1.50
	punish_dmg_mult = 1.30
	post_recover_cd = 0.36
	shard_drop = 38
	intro_duration = 0.65
	phase_shift_duration = 0.70
	death_duration = 2.4


func _exit_tree() -> void:
	if _arena != null:
		_arena.cleanup()


func _configure_boss(_spec: Dictionary) -> void:
	if _arena == null:
		_arena = ArenaFx.new(self)
	if world_ctx != null and str(world_ctx.get("current_region_id")) == "lighthouse_r10":
		arena_rect = Rect2(144.0, 88.0, 176.0, 104.0)
	configure_phases([0.66, 0.33])

	# Attack 1: Sweeping Lamp Beam — reflects off LxMirrors into blue overcharge ray (+ P3 Counter-Spin!)
	register_attack("lamp_beam_sweep", {
		"weight": 1.30, "tell": 0.62, "commit": 0.68, "recover": 1.22, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = BossMove.LAMP_BEAM
			_beam_stage = BeamStage.SWEEP_1
			_reflected_active = false
			_beam_hit = false
			_beam_hit_len = BEAM_RANGE
			_sweep_dir = -_sweep_dir
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			var arc: float = BEAM_SWEEP_ARC_P3 if phase >= 3 else BEAM_SWEEP_ARC_P1
			_sweep_start_ang = wrapf(aim_a - _sweep_dir * (arc * 0.5), -PI, PI)
			_beam_angle = _sweep_start_ang
			facing = aim_a
			ground.warn_sector(pos, _sweep_start_ang, _sweep_start_ang + _sweep_dir * arc, BEAM_BURN_RANGE, last_tell_duration, 0.0, "gold", "coral")
			stage.play_sfx("hermit_beam_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_beam_stage = BeamStage.SWEEP_1
			_beam_angle = _sweep_start_ang
			_beam_hit = false
			_beam_hit_len = BEAM_RANGE
			_reflected_active = false
			_beam_light_t = 0.0
			if phase >= 3:
				state_timer = BEAM_SWEEP_TIME + BEAM_REVERSE_PAUSE + BEAM_REVERSE_TIME
			var aim_v: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim_v, 3, 0.82, 116.0, {"color": "gold", "source": "lamp_beam_bolt", "damage": 0.5})
			_boss_impact(0.16, 78.0, 72.0)
			stage.play_sfx("hermit_beam_sweep", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, el: float) -> void:
			_step_lamp_beam_commit(dt, el),
	})

	# Attack 2: Fresnel Prism Barrage — targeted lens-flare rain + perimeter pressure + prism lance
	register_attack("fresnel_prism_barrage", {
		"weight": 1.20, "tell": 0.58, "commit": 0.34, "recover": 1.12, "cooldown": 1.65,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = BossMove.NONE
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration, 22.0, 0.5, "gold", "coral")
			ground.warn_lane(pos, pos + _aim_dir * 54.0, 7.5, last_tell_duration, 0.0, "sky", "gold")
			stage.play_sfx("hermit_beam_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_lane(pos, _aim_dir, 3 if phase >= 2 else 2, 124.0, 0.10, {"color": "sky", "source": "fresnel_lance", "damage": 0.5})
			stage.shake(0.15)
			stage.play_sfx("hermit_tide_fire", pos),
	})

	# Attack 3: Lantern Shell Slam — surging shell lunge + gap ring of brine bolts
	register_attack("lantern_shell_slam", {
		"weight": 1.15, "tell": 0.56, "commit": 0.34, "recover": 1.18, "cooldown": 1.65,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = BossMove.NONE
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _aim_dir.angle()
			ground.warn_lane(pos, pos + _aim_dir * 52.0, 9.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("warden_swing", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 10, 110.0, gap_a, 0.92, {"color": "sky", "source": "shell_slam_ring", "damage": 0.5})
			stage.shake(0.16)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_aim_dir * 86.0 * dt, false)
			check_contact_damage(body_radius + 10.0, _aim_dir, 0.5, "shell_slam"),
	})

	# Attack 4 (P2/P3): Tide Ring + Interactive Buoy Mines
	register_attack("tide_ring_mines", {
		"phases": [2, 3], "weight": 1.75, "tell": 0.58, "commit": 0.34, "recover": 1.22, "cooldown": 1.65,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = BossMove.TIDE_RING
			_tide_progress = 0.0
			_tide_hit = false
			ground.warn_ring(pos, TIDE_MAX_R, last_tell_duration, 0.0, "sky", "coral")
			ground.warn_ring(tgt, 22.0, last_tell_duration + 0.06, 0.5, "coral", "gold")
			stage.play_sfx("hermit_tide_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_tide_progress = 0.0
			_tide_hit = false
			if _arena != null:
				_arena.spawn_tide_mines()
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 12, 116.0, gap_a, 0.90, {"color": "ice", "source": "tide_ring_spray", "damage": 0.5})
			_boss_impact(0.22, 96.0, 96.0)
			stage.play_sfx("hermit_tide_fire", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			_step_tide_ring_commit(el, 0.34),
	})

	# Attack 5 (P3): Whirlpool Shell-Pull — LxFields inward pull drawing Wick & buoy mines inward!
	register_attack("whirlpool_shell_pull", {
		"phases": [3], "weight": 2.05, "tell": 0.60, "commit": 0.52, "recover": 1.28, "cooldown": 1.70,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = BossMove.WHIRLPOOL_PULL
			_pull_hit = false
			ground.warn_ring(pos, 44.0, last_tell_duration, 0.0, "sky", "coral")
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration + 0.08, 20.0, 0.5, "sky", "gold")
			stage.play_sfx("hermit_tide_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_pull_hit = false
			if _arena != null:
				_arena.set_pull_active(true)
			patterns.emit_spiral(pos, 4, 108.0, facing, 0.42, 2, 0.24, {"color": "sky", "source": "whirlpool_spray", "damage": 0.5})
			_boss_impact(0.18, 92.0, 90.0)
			stage.play_sfx("bellows_inhale", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, _el: float) -> void:
			if not _pull_hit and _has_player() and _get_wick_pos().distance_to(pos) <= body_radius + 14.0:
				_pull_hit = true
				emit_boss_damage((_get_wick_pos() - pos).normalized(), 0.5, "shockwave", pos, true),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			if _arena != null:
				_arena.set_pull_active(false),
	})


func _on_reset_encounter() -> void:
	if _arena != null:
		_arena.cleanup()
	active_move = BossMove.NONE
	_roaring = false
	shield_max = SHIELD_MAX_HP
	shield_hp = SHIELD_MAX_HP
	shield_gone_t = 0.0
	lamp_cracked_t = 0.0
	_beam_stage = BeamStage.SWEEP_1
	_sweep_start_ang = facing
	_sweep_dir = 1.0
	_beam_angle = facing
	_beam_hit = false
	_beam_hit_len = BEAM_RANGE
	_reflected_active = false
	_mirror_ping_t = 0.0
	_tide_progress = 0.0
	_tide_hit = false
	_pull_hit = false
	_clank_sfx_cd = 0.0


func _enter_phase(next_phase: int) -> void:
	# Compat hook for tests/luxel/boss_qa_capture.gd
	phase = clampi(next_phase, 1, 3)
	if not phases_reached.has(phase):
		phases_reached.append(phase)
	_on_phase_enter(phase)


func _on_phase_enter(new_phase: int) -> void:
	_roaring = true
	active_move = BossMove.NONE
	_beam_stage = BeamStage.SWEEP_1
	_reflected_active = false
	_tide_progress = 0.0
	if _arena != null:
		_arena.set_pull_active(false)
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		if _arena != null:
			_arena.apply_p2_tower_tide()
		props.spawn_pillar(clamp_to_arena(c + Vector2(-72.0, -38.0)), 4.5, "hermit_buoy_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(72.0, -38.0)), 4.5, "hermit_buoy_e")
		stage.darkness_pulse(0.60, 0.95)
	elif new_phase == 3:
		if _arena != null:
			_arena.apply_p3_eclipse()
		stage.darkness_pulse(0.72, 1.05)
	stage.shake(0.28)
	stage.play_sfx("hermit_phase_roar", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if boss_state != BossState.PHASE_SHIFT:
		_roaring = false
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	lamp_cracked_t = maxf(0.0, lamp_cracked_t - dt)
	_mirror_ping_t = maxf(0.0, _mirror_ping_t - dt)
	if shield_gone_t > 0.0:
		shield_gone_t = maxf(0.0, shield_gone_t - dt)
		if shield_gone_t <= 0.0:
			shield_hp = shield_max
	var pulling: bool = (boss_state == BossState.COMMIT and active_attack_id == "whirlpool_shell_pull")
	if _arena != null:
		_arena.tick_mirrors_and_mines(dt, pulling, _on_tide_mine_hit)
		if not pulling:
			_arena.set_pull_active(false)


func _has_active_shield() -> bool:
	return shield_hp > 0.0 and shield_gone_t <= 0.0 and boss_state != BossState.STAGGER and boss_state != BossState.DEATH


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var is_blue_hit: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	var heavy: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE] \
			or bool(h["pierce"]) or bool(h["cracks_armour"])

	if boss_state == BossState.STAGGER or lamp_cracked_t > 0.0:
		return dmg * LAMP_CRACK_MULT
	if is_blue_hit:
		stage.play_sfx("hermit_prism_bank_hit", pos)
		if _has_active_shield():
			_wear_shield(float(h["shield_wear"]) * 1.2)
		return dmg * 1.35
	if is_punishable():
		return dmg * (1.20 if heavy else 1.0)
	if heavy:
		if _has_active_shield():
			_wear_shield(float(h["shield_wear"]))
		return dmg * 1.15

	# Cupola lamp-shell armour outside punish windows: reduced bolt chip + sea-glass armour glint!
	clank_t = 0.12
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("crystal_clank", pos)
	return dmg * (0.24 if _has_active_shield() else 0.32)


func _wear_shield(amt: float) -> void:
	shield_hp = maxf(0.0, shield_hp - maxf(0.0, amt))
	if shield_hp <= 0.001:
		shield_hp = 0.0
		shield_gone_t = SHIELD_GONE_DUR
		lamp_cracked_t = maxf(lamp_cracked_t, 2.5)
		stage.play_sfx("hermit_self_reflect_stagger", pos)
		add_stagger(stagger_threshold * 0.60)


func _on_tide_mine_hit() -> void:
	hp = maxf(0.5, hp - 3.5)
	lamp_cracked_t = maxf(lamp_cracked_t, LAMP_CRACK_DURATION)
	if _arena != null:
		_arena.set_pull_active(false)
	active_move = BossMove.NONE
	stagger_immunity_t = 0.0
	add_stagger(stagger_threshold)
	stage.play_sfx("hermit_self_reflect_stagger", pos)
	LxDamageFx.boss_impact(pos, 0.24, 88.0, 90.0, 92.0, 1.45, 0.36, "gold")


func _step_tide_ring_commit(el: float, dur: float) -> void:
	_tide_progress = clampf(el / maxf(dur, 0.05), 0.0, 1.0)
	var ring_r: float = lerpf(TIDE_START_R, TIDE_MAX_R, _tide_progress)
	if not _tide_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= TIDE_BAND:
			_tide_hit = true
			var push_d: Vector2 = wv.normalized() if wv.length() > 0.1 else Vector2.from_angle(facing)
			emit_boss_damage(push_d, 0.5, "shockwave", pos, true)
	if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= ring_r and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())


func _step_lamp_beam_commit(dt: float, el: float) -> void:
	var arc: float = BEAM_SWEEP_ARC_P3 if phase >= 3 else BEAM_SWEEP_ARC_P1
	var prog: float = 0.0
	if phase >= 3 and el >= BEAM_SWEEP_TIME:
		if el < BEAM_SWEEP_TIME + BEAM_REVERSE_PAUSE:
			if _beam_stage == BeamStage.SWEEP_1:
				_beam_stage = BeamStage.COUNTER_PAUSE
				_sweep_dir = -_sweep_dir
				_sweep_start_ang = _beam_angle
				_beam_hit = false
				_reflected_active = false
				stage.play_sfx("hermit_beam_tell", pos)
			return
		if _beam_stage != BeamStage.SWEEP_2:
			_beam_stage = BeamStage.SWEEP_2
			_beam_hit = false
			_boss_impact(0.16, 78.0, 72.0)
			stage.play_sfx("hermit_beam_sweep", pos)
		prog = clampf((el - BEAM_SWEEP_TIME - BEAM_REVERSE_PAUSE) / BEAM_REVERSE_TIME, 0.0, 1.0)
	else:
		prog = clampf(el / BEAM_SWEEP_TIME, 0.0, 1.0)

	_beam_angle = wrapf(_sweep_start_ang + _sweep_dir * arc * prog, -PI, PI)
	facing = _beam_angle
	var bdir: Vector2 = Vector2.from_angle(_beam_angle)
	_beam_hit_len = BEAM_RANGE
	_reflected_active = false
	var hit_mirror: LxMirror = _find_beam_mirror(bdir)
	if hit_mirror != null:
		_beam_hit_len = clampf((hit_mirror.pos - pos).dot(bdir), body_radius + 4.0, BEAM_RANGE)
		if _mirror_ping_t <= 0.0:
			_mirror_ping_t = 0.18
			hit_mirror.on_hit(LxHit.make(LxHit.SOURCE_BEAM, 0.0, bdir, pos))
		var rdir: Vector2 = hit_mirror.reflect_dir(bdir)
		if rdir.length_squared() > 0.01:
			_reflected_active = true
			_reflect_origin = hit_mirror.pos
			_reflect_end = hit_mirror.pos + rdir * BEAM_RANGE
			if Geometry2D.get_closest_point_to_segment(pos, _reflect_origin + rdir * 8.0, _reflect_end).distance_to(pos) <= body_radius + 7.5:
				_trigger_self_reflect_stagger()
				return
	var bend: Vector2 = pos + bdir * _beam_hit_len
	_beam_light_t -= dt
	if _beam_light_t <= 0.0:
		_beam_light_t = 0.14
		LxDamageFx.boss_impact(pos + bdir * minf(66.0, _beam_hit_len * 0.5), 0.0, 0.0, 0.0, 76.0, 1.38, 0.22)
	var burn_end: Vector2 = pos + bdir * minf(_beam_hit_len, BEAM_BURN_RANGE)
	if not _beam_hit and _has_player() and Geometry2D.get_closest_point_to_segment(_get_wick_pos(), pos, burn_end).distance_to(_get_wick_pos()) <= BEAM_HALF_W:
		_beam_hit = true
		emit_boss_damage(bdir, 0.5, "lamp_beam", pos, true)
	if _is_lantern_out() and Geometry2D.get_closest_point_to_segment(_get_lantern_pos(), pos, bend).distance_to(_get_lantern_pos()) <= BEAM_HALF_W + 2.0 and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())


func _find_beam_mirror(bdir: Vector2) -> LxMirror:
	var best: LxMirror = null
	var best_proj: float = BEAM_RANGE
	for ctx: Node in [world_ctx, Lx.world]:
		if ctx == null or not is_instance_valid(ctx):
			continue
		var inters_v: Variant = ctx.call("get_interactables") if ctx.has_method("get_interactables") else ctx.get("interactables")
		if not (inters_v is Array):
			continue
		for it_v: Variant in (inters_v as Array):
			if not (it_v is LxMirror) or not is_instance_valid(it_v as LxMirror):
				continue
			var m: LxMirror = it_v as LxMirror
			if not m.is_reflective():
				continue
			var rel: Vector2 = m.pos - pos
			var proj: float = rel.dot(bdir)
			if proj <= body_radius + 2.0 or proj >= best_proj:
				continue
			if (rel - bdir * proj).length() <= maxf(m.size.x, m.size.y) * 0.62:
				best_proj = proj
				best = m
	return best


func _trigger_self_reflect_stagger() -> void:
	active_move = BossMove.NONE
	_beam_stage = BeamStage.SWEEP_1
	_reflected_active = false
	lamp_cracked_t = LAMP_CRACK_DURATION
	shield_hp = 0.0
	shield_gone_t = SHIELD_GONE_DUR
	stagger_immunity_t = 0.0
	add_stagger(stagger_threshold)
	LxDamageFx.boss_impact(pos, 0.28, 98.0, 102.0, 96.0, 1.50, 0.42, "ice")
	stage.play_sfx("hermit_self_reflect_stagger", pos)


func _perimeter_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [tgt]
	var inset: Rect2 = arena_rect.grow(-14.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	if phase >= 2:
		out.append(corners[2])
	return out


func _on_death_start() -> void:
	if _arena != null:
		_arena.cleanup()
	stage.revert_tiles(world_ctx)
	LxDamageFx.boss_impact(pos, 0.24, 96.0, 88.0, 128.0, 1.55, 0.55, "gold")
	stage.play_sfx("hermit_phase_roar", pos)


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 3 else (PAL["blue"] if phase == 2 else PAL["teal"])) as Color


func _shield_color() -> Color:
	return PAL["gold"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var lc: Vector2 = off.round()
	if _arena != null:
		_arena.draw_extras(self, off)
	if lamp_cracked_t > 0.0:
		draw_arc(lc, body_radius + 4.5, 0.0, TAU, 20, PAL["sky"] as Color, 1.8)
		draw_arc(lc, body_radius + 2.5, 0.0, TAU, 16, PAL["ice"] as Color, 1.1)
	if active_attack_id == "whirlpool_shell_pull" and boss_state in [BossState.TELL, BossState.COMMIT]:
		var pulling_now: bool = boss_state == BossState.COMMIT
		var r_pull: float = 52.0 if pulling_now else lerpf(64.0, 22.0, 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0))
		draw_arc(lc, r_pull, anim_t * 3.0, anim_t * 3.0 + PI * 1.5, 24, PAL["coral" if pulling_now else "sky"] as Color, 2.0)
		draw_arc(lc, r_pull * 0.62, -anim_t * 4.0, -anim_t * 4.0 + PI * 1.4, 18, PAL["cream" if pulling_now else "ice"] as Color, 1.4)
	elif active_attack_id == "lamp_beam_sweep" and boss_state == BossState.TELL:
		var arc: float = BEAM_SWEEP_ARC_P3 if phase >= 3 else BEAM_SWEEP_ARC_P1
		_draw_sweep_mirror_glints(_sweep_start_ang + _sweep_dir * (arc * 0.5), arc * 0.5 + 0.14, 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0))
	elif active_attack_id == "lamp_beam_sweep" and boss_state == BossState.COMMIT and _beam_stage != BeamStage.COUNTER_PAUSE:
		var b_dir: Vector2 = Vector2.from_angle(_beam_angle)
		var b_end: Vector2 = (off + b_dir * _beam_hit_len).round()
		draw_line(lc, b_end, PAL["apricot"] as Color, 6.8)
		draw_line(lc, b_end, PAL["gold"] as Color, 3.8)
		draw_line(lc, b_end, PAL["cream"] as Color, 1.6)
		if _reflected_active:
			var r0: Vector2 = (_reflect_origin - pos + off).round()
			var r1: Vector2 = (_reflect_end - pos + off).round()
			draw_line(r0, r1, PAL["blue"] as Color, 5.0)
			draw_line(r0, r1, PAL["sky"] as Color, 3.0)
			draw_line(r0, r1, PAL["cream"] as Color, 1.2)
	elif active_attack_id == "tide_ring_mines" and boss_state == BossState.COMMIT:
		var ring_r: float = lerpf(TIDE_START_R, TIDE_MAX_R, _tide_progress)
		draw_arc(lc, ring_r + 2.4, 0.0, TAU, 36, PAL["blue"] as Color, 2.4)
		draw_arc(lc, ring_r, 0.0, TAU, 36, PAL["sky"] as Color, 3.4)
		draw_arc(lc, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["cream"] as Color, 1.4)
	# Cupola armour glint outside punish windows vs golden punish halo
	if clank_t > 0.0:
		draw_arc(lc, body_radius + 5.0, facing - 1.1, facing + 1.1, 16, PAL["cream"] as Color, 2.2)
		draw_arc(lc, body_radius + 7.0, facing - 0.85, facing + 0.85, 12, PAL["ice"] as Color, 1.2)
	elif is_punishable() and boss_state != BossState.DEATH:
		draw_arc(lc, body_radius + 4.5, 0.0, TAU, 20, PAL["gold"] as Color, 1.6)


func _draw_sweep_mirror_glints(mid_a: float, half_arc: float, prog: float) -> void:
	var rad_d: float = 7.5 + (0.0 if is_flash_reduced() else 1.5 * sin(anim_t * 18.0))
	var col_d: Color = (PAL["ice"] if prog > 0.50 else PAL["sky"]) as Color
	for ctx: Node in [world_ctx, Lx.world]:
		if ctx == null or not is_instance_valid(ctx):
			continue
		var inters_v: Variant = ctx.call("get_interactables") if ctx.has_method("get_interactables") else ctx.get("interactables")
		if not (inters_v is Array):
			continue
		for it_v: Variant in (inters_v as Array):
			if not (it_v is LxMirror) or not is_instance_valid(it_v as LxMirror):
				continue
			var m: LxMirror = it_v as LxMirror
			var rel: Vector2 = m.pos - pos
			if not m.is_reflective() or rel.length() <= body_radius + 2.0 or rel.length() > BEAM_RANGE + 8.0 or absf(angle_difference(mid_a, rel.angle())) > half_arc:
				continue
			var mp: Vector2 = rel.round()
			var pts := PackedVector2Array([mp + Vector2(0.0, -rad_d), mp + Vector2(rad_d, 0.0), mp + Vector2(0.0, rad_d), mp + Vector2(-rad_d, 0.0), mp + Vector2(0.0, -rad_d)])
			draw_polyline(pts, PAL["void"] as Color, 2.6)
			draw_polyline(pts, col_d, 1.5)
			draw_circle(mp, 2.2, PAL["cream"] as Color)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	var rip: String = "ice" if active_move in [BossMove.TIDE_RING, BossMove.WHIRLPOOL_PULL] else ""
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.15, 1.48, 0.40, rip)
