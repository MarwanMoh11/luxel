class_name LxSilentBellBoss
extends LxBossBase
## Island 1 Superboss: The Silent Bell (superboss_silent, Midnight + great_lamp_1).
## 0 dB COMPLETE SILENCE: music and ALL boss SFX are muted during the entire fight!
## Read visual dust-ripples & stark hairline ice/cream floor cracks by eye.
## Throw your lantern INSIDE its open hollow mouth during recovery to force a silent shockwave
## (2.2s stagger + 3.5 bonus damage!).
## Only the killing blow BREAKS THE SILENCE with a colossal resonant D-minor Dawn chord!

const MOUTH_THROW_RADIUS: float = 28.0
const MOUTH_BONUS_DMG: float = 2.5
const MOUTH_STAGGER_S: float = 2.20
const PENDULUM_RADIUS: float = 60.0

var _mouth_open: bool = false
var _mouth_triggered_this_rec: bool = false
var _pend_dir: Vector2 = Vector2.LEFT
var _pend_hit: bool = false
var _dust_pulse_t: float = 0.0
var _silence_broken: bool = false


func _init() -> void:
	super._init()
	kind = "silent_bell"
	boss_id = "silent_bell"
	boss_name_key = "ISL1_BOSS_SILENT"
	island_id = 1
	is_miniboss = false
	reward_heart = "none"
	music_cue = ""
	music_p2_cue = ""
	max_hp = 92.0
	hp = 92.0
	body_radius = 13.0
	move_speed = 40.0
	stagger_threshold = 12.5
	stagger_duration = 2.10
	post_recover_cd = 0.28
	intro_duration = 0.65
	phase_shift_duration = 0.72
	death_duration = 2.4
	shard_drop = 150


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Cracked Silence Ring (hairline ice crack with 1 glowing dodge gap -> silent shards!)
	register_attack("cracked_silence_ring", {
		"weight": 1.35, "tell": 0.64, "commit": 0.32, "recover": 1.28, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			facing = aim_a
			ground.warn_ring(pos, 72.0, last_tell_duration, 0.0, "ice", "cream")
			ground.warn_lane(pos, clamp_to_arena(pos + Vector2.from_angle(aim_a) * 135.0), 8.0, last_tell_duration, 0.0, "cream", "ice"),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var aim_a: float = aim_d.angle()
			var cnt: int = 7 if phase >= 2 else 6
			patterns.emit_lane(pos, aim_d, 1, 80.0, 0.08, {"color": "cream", "source": "silence_ring"})
			patterns.emit_gap_ring(pos, cnt, 72.0 if phase >= 2 else 68.0, aim_a + PI * 0.36, 1.30, {"color": "ice", "source": "silence_ring"})
			_dust_pulse_t = 0.55
			stage.shake(0.14),
	})

	# Attack 2: Mute Curtain (dims Wick light 50% while stark cream floor lanes shine clearly!)
	register_attack("mute_curtain", {
		"weight": 1.25, "tell": 0.68, "commit": 0.36, "recover": 1.28, "cooldown": 2.1,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = aim_d.angle()
			var perp := Vector2(-aim_d.y, aim_d.x)
			stage.darkness_pulse(0.72, 1.8)
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 140.0), 9.0, last_tell_duration, 0.0, "cream", "ice")
			ground.warn_lane(pos, clamp_to_arena(pos + perp * 120.0), 8.0, last_tell_duration, 0.0, "ice", "cream")
			ground.warn_lane(pos, clamp_to_arena(pos - perp * 120.0), 8.0, last_tell_duration, 0.0, "ice", "cream"),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim_d, 3, 0.72, 74.0, {"color": "cream", "source": "mute_curtain"})
			_dust_pulse_t = 0.45
			stage.shake(0.14),
	})

	# Attack 3: Hollow Pendulum (floor shadow-clapper sweep -> opens hollow mouth in RECOVER for Lantern Throw!)
	register_attack("hollow_pendulum", {
		"weight": 1.35, "tell": 0.68, "commit": 0.34, "recover": 1.46, "cooldown": 1.85,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_pend_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _pend_dir.angle()
			_pend_hit = false
			ground.warn_sector(pos, facing - 1.00, facing + 1.00, PENDULUM_RADIUS * 0.80, last_tell_duration, 0.0, "mauve", "cream")
			ground.warn_lane(pos, clamp_to_arena(pos + _pend_dir * 130.0), 9.0, last_tell_duration, 0.0, "ice", "cream"),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_lane(pos, _pend_dir, 1, 80.0, 0.08, {"color": "cream", "source": "shadow_clapper"})
			patterns.emit_boomerang(pos, _pend_dir.rotated(-0.52), 70.0, 0.65, 0.45, {"color": "ice", "source": "shadow_clapper"})
			if phase >= 2:
				patterns.emit_boomerang(pos, _pend_dir.rotated(0.52), 70.0, 0.65, -0.45, {"color": "ice", "source": "shadow_clapper"})
			_dust_pulse_t = 0.50
			stage.shake(0.14),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _elapsed: float) -> void:
			move_boss(_pend_dir * 36.0 * dt, true)
			if not _pend_hit and pos.distance_to(tgt) <= PENDULUM_RADIUS * 0.72:
				var rel: Vector2 = tgt - pos
				if rel.length() < 1.0 or absf(angle_difference(facing, rel.angle())) <= 1.00:
					_pend_hit = true
					emit_boss_damage(_pend_dir, 1.0, "hollow_pendulum", pos, true),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			_mouth_open = true,
	})

	# Attack 4 (P2): Fracture Zones (stark bell floor cracks erupt + 2 silent orbiting shadow-clappers!)
	register_attack("fracture_zones", {
		"phases": [2], "weight": 2.75, "tell": 0.76, "commit": 0.30, "recover": 1.40, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var pts: Array[Vector2] = _build_fracture_targets(tgt).slice(1, 3)
			patterns.emit_pillars(pts, last_tell_duration + 0.14, 12.0, 0.32, 1.0, "ice"),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_orbit(pos, 2, 30.0, 1.15, 1.55, {"color": "mauve", "source": "orbit_clapper", "follow_boss": true})
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim_d, 3, 0.74, 74.0, {"color": "cream", "source": "fracture_shard"})
			_dust_pulse_t = 0.60
			stage.shake(0.16),
	})


func _on_reset_encounter() -> void:
	_mouth_open = false
	_mouth_triggered_this_rec = false
	_pend_hit = false
	_dust_pulse_t = 0.0
	_silence_broken = false


func _on_engage() -> void:
	_enforce_total_silence()


func _enforce_total_silence() -> void:
	if _silence_broken:
		return
	if Lx.audio != null and is_instance_valid(Lx.audio):
		Lx.audio.silence_music(0.1)


func _build_fracture_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-20.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(clamp_to_arena(tgt.lerp(arena_rect.get_center(), 0.50)))
	return out


func add_stagger(amount: float) -> bool:
	# Override silently so ZERO SFX plays during the Silent Bell fight!
	if boss_state in [BossState.DEATH, BossState.INTRO, BossState.PHASE_SHIFT, BossState.STAGGER]:
		return false
	if stagger_immunity_t > 0.0:
		return false
	stagger_meter += maxf(0.0, amount)
	if stagger_meter >= stagger_threshold:
		stagger_meter = 0.0
		_release_token()
		active_attack_id = ""
		_set_boss_state(BossState.STAGGER, stagger_duration)
		staggered.emit(stagger_duration)
		stage.light_burst(pos, 84.0, 1.35, 0.32)
		stage.shake(0.18)
		return true
	return false


func _trigger_lantern_inside_mouth() -> void:
	_mouth_triggered_this_rec = true
	_mouth_open = false
	hp = maxf(0.5, hp - MOUTH_BONUS_DMG)
	flash_t = 0.22
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, MOUTH_STAGGER_S)
	staggered.emit(MOUTH_STAGGER_S)
	# Silent blinding white shockwave!
	stage.light_burst(pos, 136.0, 1.65, 0.48)
	stage.shake(0.26)
	_dust_pulse_t = 0.85
	_check_phase_thresholds()


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_enforce_total_silence()
	_dust_pulse_t = maxf(0.0, _dust_pulse_t - dt)
	move_speed = 46.0 if phase >= 2 else 40.0

	if boss_state == BossState.RECOVER:
		_mouth_open = true
		# Check if Wick threw/hung the lantern INSIDE the mute bell's open mouth!
		if not _mouth_triggered_this_rec and _is_lantern_out():
			if _get_lantern_pos().distance_to(pos) <= MOUTH_THROW_RADIUS:
				_trigger_lantern_inside_mouth()
	else:
		_mouth_open = false
		_mouth_triggered_this_rec = false


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# Outer rim corners crumble silently into lethal void leaving a bell-shaped sanctum island!
		var tl_tx: int = maxi(1, int(arena_rect.position.x / 16.0))
		var tl_ty: int = maxi(1, int(arena_rect.position.y / 16.0))
		var br_tx: int = maxi(tl_tx + 5, int(arena_rect.end.x / 16.0) - 1)
		var br_ty: int = maxi(tl_ty + 4, int(arena_rect.end.y / 16.0) - 1)
		var wp: Vector2 = _get_wick_pos() if _has_player() else Vector2(-9999.0, -9999.0)
		for pt: Vector2i in [Vector2i(tl_tx, tl_ty), Vector2i(br_tx, tl_ty), Vector2i(tl_tx, br_ty), Vector2i(br_tx, br_ty)]:
			if wp.distance_to(Vector2((float(pt.x) + 0.5) * 16.0, (float(pt.y) + 0.5) * 16.0)) >= 24.0:
				stage.set_tiles(world_ctx, Rect2i(pt.x, pt.y, 1, 1), "pit")
		stage.darkness_pulse(0.74, 1.2)
		stage.shake(0.24)
		# Intentionally ZERO SFX!


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	if _mouth_open and not _mouth_triggered_this_rec and (src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_ZIP):
		_trigger_lantern_inside_mouth()
		return dmg * 1.4
	return dmg


func _on_death_start() -> void:
	# BREAK THE SILENCE! Colossal resonant D-minor Dawn chord on the killing blow!
	_silence_broken = true
	stage.light_burst(pos, 180.0, 1.8, 0.85)
	stage.shake(0.32)
	stage.play_sfx("great_lamp_bloom", pos)
	stage.play_sfx("bell_toll_heavy", pos)


func _body_color() -> Color:
	return (PAL["mauve"] if phase >= 2 else PAL["dusk"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = is_flash_reduced()
	# Visual silent dust-ripple wave (reads entirely by eye!)
	if _dust_pulse_t > 0.0:
		var u: float = 1.0 - clampf(_dust_pulse_t / 0.60, 0.0, 1.0)
		var rx: float = lerpf(18.0, 88.0, u)
		var da: float = (1.0 - u) * (0.55 if fred else 0.85)
		draw_arc(c, rx, 0.0, TAU, 32, Color(PAL["void"] as Color, da * 0.85), 4.0)
		draw_arc(c, rx, 0.0, TAU, 32, Color(PAL["ice"] as Color, da), 2.0)
	# Open mouth target indicator inviting Wick to throw the lantern INSIDE!
	if _mouth_open and not _mouth_triggered_this_rec and boss_state != BossState.DEATH:
		var pulse: float = 0.0 if fred else sin(anim_t * 10.0) * 1.5
		draw_arc(c + Vector2(0.0, 6.0), 15.0 + pulse, 0.0, TAU, 20, PAL["void"] as Color, 4.0)
		draw_arc(c + Vector2(0.0, 6.0), 15.0 + pulse, 0.0, TAU, 20, PAL["ice"] as Color, 2.0)
		draw_arc(c + Vector2(0.0, 6.0), 8.0, 0.0, TAU, 14, PAL["void"] as Color, 3.0)
		draw_arc(c + Vector2(0.0, 6.0), 8.0, 0.0, TAU, 14, PAL["cream"] as Color, 1.0)
	# Forced-to-ring golden fracture aura during STAGGER!
	if boss_state == BossState.STAGGER:
		draw_arc(c, body_radius + 8.0, 0.0, TAU, 24, PAL["void"] as Color, 4.0)
		draw_arc(c, body_radius + 8.0, 0.0, TAU, 24, PAL["gold"] as Color, 2.0)
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 18, PAL["void"] as Color, 3.0)
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 18, PAL["cream"] as Color, 1.0)
