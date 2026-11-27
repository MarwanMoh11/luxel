class_name LxTollHoundBoss
extends LxBossBase
## Island 1 Mini-Boss: The Toll-Hound (Undercroft r5).
## Blindfolded bronze-collared hound-toad that tracks sound (ring waves, shots, thrown lantern),
## charging headlong into breakable tomb pillars to bonk & stagger!
## P1: Ear-Lock Charge, Collar Bark, Twin Snap.
## P2 (<= 50% HP): Cracks bronze collar, fractures arena corners, wakes 2 grave_hands,
## and upgrades Ear-Lock Charge into a chained double-charge!

const CHARGE_SPEED: float = 240.0
const CHARGE_HIT_R: float = 15.5
const BARK_RADIUS: float = 52.0
const SNAP_RADIUS: float = 32.0
const COLLAR_ARMOR_MULT: float = 0.72
const BONK_STAGGER_TIME: float = 2.20

var _charge_dir: Vector2 = Vector2.LEFT
var _charge_hit: bool = false
var _charge_leg: int = 0
var _snap_dir: Vector2 = Vector2.LEFT
var _snap_hit: bool = false
var _collar_cracked: bool = false
var _sound_lure_pos: Vector2 = Vector2.ZERO
var _sound_lure_t: float = 0.0
var _sniff_t: float = 0.0
var _dusk_slow_t: float = 0.0
var _death_ping_done: bool = false


func _init() -> void:
	super._init()
	kind = "toll_hound"
	boss_id = "toll_hound"
	boss_name_key = "ISL1_BOSS_HOUND"
	island_id = 1
	is_miniboss = true
	reward_heart = "none"
	music_cue = "isl1_boss_minor_p1"
	music_p2_cue = "isl1_boss_minor_p2"
	max_hp = 36.0
	hp = 36.0
	body_radius = 11.0
	move_speed = 42.0
	stagger_threshold = 9.0
	stagger_duration = 1.65
	post_recover_cd = 0.34
	intro_duration = 0.55
	phase_shift_duration = 0.65
	death_duration = 2.2
	shard_drop = 18


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.58])

	# Attack 1: Ear-Lock Charge (sound-guided rocket charge; bonks pillars for 2.2s stagger!)
	register_attack("ear_lock_charge", {
		"weight": 1.35, "tell": 0.58, "commit": 0.44, "recover": 1.20, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var lock_p: Vector2 = _pick_sound_target(tgt)
			_charge_dir = (lock_p - pos).normalized() if lock_p.distance_to(pos) > 2.0 else Vector2.from_angle(facing)
			facing = _charge_dir.angle()
			_charge_hit = false
			_charge_leg = 0
			ground.warn_lane(pos, clamp_to_arena(pos + _charge_dir * 136.0), 14.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("warden_lunge_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_charge_hit = false
			_charge_leg = 0
			stage.shake(0.14)
			stage.play_sfx("hollow_dash", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, elapsed: float) -> void:
			_step_charge_commit(tgt, dt, elapsed),
	})

	# Attack 2: Collar Bark (52px shockwave + gap-ring sonic bolts pressuring all corners!)
	register_attack("collar_bark", {
		"weight": 1.15, "tell": 0.52, "commit": 0.28, "recover": 1.15, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			ground.warn_ring(pos, BARK_RADIUS, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("bell_slam_windup", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			var cnt: int = 8 if phase >= 2 else 7
			patterns.emit_gap_ring(pos, cnt, 102.0 if phase >= 2 else 92.0, aim_a + PI * 0.35, 0.84, {"color": "coral", "source": "collar_bark"})
			stage.shake(0.18)
			stage.play_sfx("toll_hound_bark", pos),
	})

	# Attack 3: Twin Snap (close cone lunge + 3-bolt coral fang volley covering long range)
	register_attack("twin_snap", {
		"weight": 1.10, "tell": 0.50, "commit": 0.26, "recover": 1.10, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_snap_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _snap_dir.angle()
			_snap_hit = false
			ground.warn_sector(pos, facing - 0.72, facing + 0.72, SNAP_RADIUS, last_tell_duration, 0.0, "coral", "apricot")
			ground.warn_lane(pos, clamp_to_arena(pos + _snap_dir * 124.0), 9.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("warden_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 3
			patterns.emit_fan(pos, _snap_dir, cnt, 0.54, 114.0 if phase >= 2 else 102.0, {"color": "apricot", "source": "hound_snap"})
			stage.shake(0.12)
			stage.play_sfx("pew_chomp", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _elapsed: float) -> void:
			move_boss(_snap_dir * 72.0 * dt, false)
			if not _snap_hit and pos.distance_to(tgt) <= SNAP_RADIUS:
				var rel: Vector2 = tgt - pos
				if rel.length() < 1.0 or absf(angle_difference(facing, rel.angle())) <= 0.75:
					_snap_hit = true
					emit_boss_damage(_snap_dir, 1.0, "twin_snap", pos, true),
	})


func _on_reset_encounter() -> void:
	_collar_cracked = false
	_sound_lure_pos = Vector2.ZERO
	_sound_lure_t = 0.0
	_sniff_t = 0.0
	_dusk_slow_t = 0.0
	_death_ping_done = false
	_spawn_crypt_pillars_and_bells()


func _spawn_crypt_pillars_and_bells() -> void:
	var c: Vector2 = arena_rect.get_center()
	var ox: float = minf(68.0, arena_rect.size.x * 0.25)
	var oy: float = minf(34.0, arena_rect.size.y * 0.24)
	props.spawn_pillar(c + Vector2(-ox, -oy), 5.0, "crypt_pillar_nw")
	props.spawn_pillar(c + Vector2(ox, -oy), 5.0, "crypt_pillar_ne")
	props.spawn_pillar(c + Vector2(-ox, oy), 5.0, "crypt_pillar_sw")
	props.spawn_pillar(c + Vector2(ox, oy), 5.0, "crypt_pillar_se")

	# If arena has no LxBell interactables (e.g. boss_lab), add perimeter resonance bells!
	var has_room_bell: bool = false
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if is_instance_valid(it_v) and it_v is Object and str((it_v as Object).get("kind")) == "bell":
				has_room_bell = true
				break
	if not has_room_bell:
		var dawn_p: Vector2 = Vector2(arena_rect.position.x + 22.0, c.y)
		var war_p: Vector2 = Vector2(c.x, arena_rect.position.y + 18.0)
		props.spawn_bell(dawn_p, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring("dawn", (pos - bp).normalized())
			stage.play_sfx("bell_toll", bp), "hound_lab_bell_dawn")
		props.spawn_bell(war_p, func(p: Dictionary) -> void:
			var bp: Vector2 = p["pos"] as Vector2
			on_ring("war", (pos - bp).normalized())
			stage.play_sfx("bell_slam", bp), "hound_lab_bell_war")


func _pick_sound_target(wick_p: Vector2) -> Vector2:
	if _sound_lure_t > 0.0:
		return _sound_lure_pos
	if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= 180.0:
		return _get_lantern_pos()
	return wick_p


func _step_charge_commit(tgt: Vector2, dt: float, elapsed: float) -> void:
	# P2 ends charge with a crisp telegraphed sonic dust shock-fan (never unwarned pivot!)
	if phase >= 2 and _charge_leg == 0 and elapsed >= 0.34:
		_charge_leg = 1
		var aim_f: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 2.0 else _charge_dir
		patterns.emit_fan(pos, aim_f, 3, 0.65, 98.0, {"color": "gold", "source": "hound_dust"})
		stage.play_sfx("toll_hound_bark", pos)

	var step_v: Vector2 = _charge_dir * CHARGE_SPEED * dt
	move_boss(step_v, false)

	# Check pillar crash -> BONK STAGGER (2.2s) & collar armor crack!
	for p: Dictionary in props.props:
		if str(p["kind"]) != "pillar" or str(p["state"]) != "idle":
			continue
		var pp: Vector2 = p["pos"] as Vector2
		if pos.distance_to(pp) <= body_radius + float(p["radius"]) + 4.0:
			props._damage_prop(p, 99.0)
			_trigger_pillar_bonk(pp)
			return

	if not _charge_hit and pos.distance_to(tgt) <= CHARGE_HIT_R:
		_charge_hit = true
		emit_boss_damage(_charge_dir, 1.0, "ear_lock_charge", pos, true)


func _trigger_pillar_bonk(at_p: Vector2) -> void:
	_collar_cracked = true
	_sound_lure_t = 0.0
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, BONK_STAGGER_TIME)
	staggered.emit(BONK_STAGGER_TIME)
	stage.shake(0.26)
	stage.play_sfx("toll_hound_bonk", at_p)
	LxDamageFx.boss_impact(at_p, 0.20, 82.0, 86.0, 82.0, 1.42, 0.34)


func on_ring(tone: String, dir: Vector2) -> void:
	if boss_state == BossState.DEATH:
		return
	var t: String = tone.strip_edges().to_lower()
	# Ring waves hijack the blind Hound's hearing toward the bell!
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	_sound_lure_pos = clamp_to_arena(pos - d * 110.0)
	_sound_lure_t = 2.8
	if t == "war":
		_collar_cracked = true
		add_stagger(4.5)
		stage.play_sfx("stone_break", pos)
	elif t == "dusk":
		_dusk_slow_t = 2.0
		add_stagger(2.5)
		stage.play_sfx("clockwork_chime", pos)
	else:
		stage.play_sfx("warden_alert", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_sound_lure_t = maxf(0.0, _sound_lure_t - dt)
	_dusk_slow_t = maxf(0.0, _dusk_slow_t - dt)
	move_speed = 24.0 if _dusk_slow_t > 0.0 else (50.0 if phase >= 2 else 44.0)
	# Comedy beat: sniffs decoy thrown lantern wagging tail briefly before charging it!
	if boss_state == BossState.READY and _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if lp.distance_to(pos) <= 140.0 and _sniff_t <= 0.0:
			_sniff_t = 0.60
			_sound_lure_pos = lp
			_sound_lure_t = 2.2
	_sniff_t = maxf(0.0, _sniff_t - dt)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_collar_cracked = true
		var c: Vector2 = arena_rect.get_center()
		# Crack two outer corner floor tiles (cleanly reverted on retry!)
		var tl_tx: int = maxi(2, int(arena_rect.position.x / 16.0) + 1)
		var tl_ty: int = maxi(1, int(arena_rect.position.y / 16.0) + 1)
		var br_tx: int = maxi(tl_tx + 4, int(arena_rect.end.x / 16.0) - 2)
		var br_ty: int = maxi(tl_ty + 3, int(arena_rect.end.y / 16.0) - 2)
		stage.set_tiles(world_ctx, Rect2i(tl_tx, tl_ty, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(br_tx, br_ty, 1, 1), "pit")
		adds.queue_wave([
			{"kind": "grave_hand", "pos": c + Vector2(-58.0, 26.0)},
			{"kind": "grave_hand", "pos": c + Vector2(58.0, -26.0)},
		], 0.72, 2)
		stage.darkness_pulse(0.58, 0.9)
		stage.shake(0.24)
		stage.play_sfx("bell_warden_phase2", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	if bool(h["cracks_armour"]) or str(h["source"]) == LxHit.SOURCE_THROW or str(h["source"]) == LxHit.SOURCE_ZIP:
		_collar_cracked = true
	if not _collar_cracked and not is_punishable() and str(h["source"]) == LxHit.SOURCE_BOLT:
		return dmg * COLLAR_ARMOR_MULT
	return dmg


func _on_death_start() -> void:
	if not _death_ping_done:
		_death_ping_done = true
		stage.play_sfx("clockwork_chime", pos)
		stage.shake(0.20)


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 2 else PAL["plum"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Sound-lock ear indicator when lured by bell or decoy lantern!
	if _sound_lure_t > 0.0 and boss_state != BossState.DEATH:
		var lp: Vector2 = (_sound_lure_pos - pos).round()
		draw_arc(lp, 8.0 + (0.0 if is_flash_reduced() else sin(anim_t * 10.0) * 1.5), 0.0, TAU, 12, PAL["gold"] as Color, 1.0)
		if _sniff_t > 0.0:
			# Little gold "?" / sniff spark above snout
			draw_rect(Rect2(c + Vector2(-1.0, -body_radius - 14.0), Vector2(3.0, 3.0)), PAL["gold"] as Color)
	if _dusk_slow_t > 0.0:
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 16, PAL["ice"] as Color, 2.0)
	if not _collar_cracked and boss_state != BossState.STAGGER and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 2.5, facing - 0.9, facing + 0.9, 12, PAL["gold"] as Color, 2.0)
