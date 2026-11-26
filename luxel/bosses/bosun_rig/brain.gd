class_name LxBosunRigBoss
extends LxBossBase
## Island 2 Mini-Boss A: THE BOSUN'S RIG (`bosun_rig`, `galleon_r6`).
## Listing cargo well with overhead timber crane operated by an Anchor Drowned Bosun.
## 9s ship roll clock shifts `dungeon:galleon` `list` ("port"/"starboard"), applying roll LxFields.
## P2 (50%): crane brake snaps — bilge water floods low outer edge tiles (reverted cleanly on retry),
## swinging crane hook drops as shootable chandelier prop, 180-deg Boom Sweep unlocks, and whistle trills!
## Target TTK: 45-75s (calibrated ~58-68s via crane timber guard + clear punish/stagger openings).

const ROLL_PERIOD_S: float = 9.0
const FRONT_GUARD_HALF: float = 1.05

var _aim_dir: Vector2 = Vector2.LEFT
var _roll_t: float = 0.0
var _roll_side: String = "port" # "port" (-x) | "starboard" (+x)
var _boom_start_ang: float = 0.0
var _boom_sweep_hit: bool = false
var _whistle_trill_t: float = 0.0
var _roll_field: _BosunRollField = null


class _BosunRollField:
	extends RefCounted
	var active: bool = true
	var dir_x: float = -1.0
	var strength: float = 68.0
	func is_field_active() -> bool:
		return active
	func field_accel(_p: Vector2, what: String) -> Vector2:
		if what == "bolt" or what == "block":
			return Vector2(dir_x * strength, 0.0)
		return Vector2.ZERO


func _init() -> void:
	super._init()
	kind = "bosun_rig"
	boss_id = "bosun_rig"
	boss_name_key = "BOSS_BOSUN"
	island_id = 2
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island2_boss_p1"
	music_p2_cue = "island2_boss_p2"
	max_hp = 58.0
	hp = 58.0
	body_radius = 12.0
	move_speed = 34.0
	stagger_threshold = 11.0
	stagger_duration = 1.60
	punish_dmg_mult = 1.35
	post_recover_cd = 0.34
	shard_drop = 18
	intro_duration = 0.70
	phase_shift_duration = 0.75
	death_duration = 2.2


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.58])

	# Attack 1: Cargo Drop Slam (targets Wick + nearest perimeter corner/edge so no safe spot!)
	register_attack("cargo_drop_slam", {
		"weight": 1.25, "tell": 0.62, "commit": 0.26, "recover": 1.15, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _cargo_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 20.0, 0.5, "coral", "gold")
			stage.play_sfx("bosun_whistle", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 0.78, 122.0, {"color": "sky", "source": "bosun_cargo_spray", "field_scale": 0.85, "damage": 0.5})
			stage.shake(0.16)
			stage.play_sfx("anchor_slam", pos),
	})

	# Attack 2: Anchor Fluke Drag (84px+ sweeping lane + wake wave across deck)
	register_attack("anchor_fluke_drag", {
		"weight": 1.20, "tell": 0.56, "commit": 0.38, "recover": 1.20, "cooldown": 1.65,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, pos + _aim_dir * 136.0, 12.0, last_tell_duration, 0.5, "coral", "gold")
			stage.play_sfx("harbor_creak", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_lane(pos, _aim_dir, 4 if phase >= 2 else 3, 134.0, 0.09, {"color": "ice", "source": "bosun_fluke_wave", "field_scale": 0.75, "damage": 0.5})
			stage.shake(0.15)
			stage.play_sfx("anchor_clang", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_aim_dir * 96.0 * dt, false)
			check_contact_damage(body_radius + 11.0, _aim_dir, 0.5, "bosun_drag"),
	})

	# Attack 3: Bilge Swash Volley (pressures flanks & perimeter; obeys ship roll!)
	register_attack("bilge_swash_volley", {
		"weight": 1.10, "tell": 0.58, "commit": 0.34, "recover": 1.08, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_sector(pos, _aim_dir.angle() - 0.62, _aim_dir.angle() + 0.62, 118.0, last_tell_duration, 0.0, "sky", "gold")
			stage.play_sfx("tide_surge", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			patterns.emit_fan(pos, _aim_dir, 5 if phase >= 2 else 4, 0.96, 122.0, {"color": "sky", "source": "bosun_swash", "field_scale": 1.0, "damage": 0.5})
			if phase >= 2:
				patterns.emit_gap_ring(pos, 10, 98.0, _aim_dir.angle() + PI * 0.5, 0.90, {"color": "gold", "source": "bosun_ring", "field_scale": 0.6, "damage": 0.5})
			stage.shake(0.14)
			stage.play_sfx("tide_wave", pos),
	})

	# Attack 4 (P2): 180-degree Boom Sweep (snapped crane brake sweeps deck + bulkhead slam!)
	register_attack("boom_sweep_180", {
		"phases": [2], "weight": 1.45, "tell": 0.65, "commit": 0.55, "recover": 1.30, "cooldown": 1.85,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			_boom_start_ang = _aim_dir.angle()
			_boom_sweep_hit = false
			ground.warn_sector(pos, _boom_start_ang - 1.35, _boom_start_ang + 1.35, 96.0, last_tell_duration, 0.5, "coral", "gold")
			stage.play_sfx("bosun_whistle", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_gap_ring(pos, 10, 108.0, _boom_start_ang + PI, 0.92, {"color": "coral", "source": "bosun_boom_bolts", "field_scale": 0.8, "damage": 0.5})
			stage.shake(0.20)
			stage.play_sfx("anchor_clang", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, el: float) -> void:
			var roll_push: float = -1.0 if _roll_side == "port" else 1.0
			move_boss(Vector2(roll_push * 34.0, 0.0) * dt, false)
			if not _boom_sweep_hit and el >= 0.18 and pos.distance_to(tgt) <= 84.0:
				if absf(angle_difference(_boom_start_ang, (tgt - pos).angle())) <= 1.25:
					_boom_sweep_hit = true
					emit_boss_damage((tgt - pos).normalized(), 0.5, "bosun_boom", pos, true),
	})


func _on_reset_encounter() -> void:
	_roll_t = 0.0
	_roll_side = "port"
	_whistle_trill_t = 0.0
	if _roll_field != null:
		LxFields.remove(_roll_field)
		_roll_field = null


func _on_engage() -> void:
	if _roll_field == null:
		_roll_field = _BosunRollField.new()
	_roll_field.dir_x = -1.0 if _roll_side == "port" else 1.0
	_roll_field.strength = 54.0
	LxFields.add(_roll_field)
	stage.play_sfx("bosun_whistle", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	# 9s ship-roll clock (or player flipping Galleon `list` valve!)
	_roll_t += dt
	var period: float = 6.5 if phase >= 2 else ROLL_PERIOD_S
	if _roll_t >= period:
		_roll_t = 0.0
		_roll_side = "starboard" if _roll_side == "port" else "port"
		if Lx.vars != null:
			Lx.vars.set_var("dungeon:galleon", "list", _roll_side)
		if _roll_field != null:
			_roll_field.dir_x = -1.0 if _roll_side == "port" else 1.0
			_roll_field.strength = 84.0 if phase >= 2 else 54.0
		stage.play_sfx("harbor_creak", pos)
		if phase >= 2:
			_whistle_trill_t = 0.45
			stage.play_sfx("bosun_whistle", pos)
			# If Bosun is swinging mid-roll in P2, bulkhead slam staggers him!
			if boss_state == BossState.COMMIT and active_attack_id == "boom_sweep_180":
				add_stagger(stagger_threshold)
	_whistle_trill_t = maxf(0.0, _whistle_trill_t - dt)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		# P2 Arena Change: bilge water floods low outer edge tiles (reverted cleanly on reset!)
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 3), "water")
		stage.set_tiles(world_ctx, Rect2i(17, 6, 1, 3), "water")
		# Overhead crane hook prop — shooting it drops the hook to stagger the Bosun!
		props.spawn_chandelier(c + Vector2(0.0, -14.0), 2.0, "bosun_crane_hook")
		props.spawn_crate(c + Vector2(-54.0, 26.0), 3.0, "bosun_crate_w")
		stage.darkness_pulse(0.58, 0.9)
		stage.shake(0.24)
		stage.play_sfx("bosun_whistle", pos)


func _on_death_start() -> void:
	if _roll_field != null:
		LxFields.remove(_roll_field)
		_roll_field = null
	if Lx.state != null:
		Lx.state.story_flags["power_ballast_clamp"] = true
	stage.play_sfx("anchor_clang", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var is_blue: bool = hit.is_blue()
	if is_blue:
		return dmg * 1.45
	var rel: Vector2 = hit.origin - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < FRONT_GUARD_HALF
	# Timber crane gantry armor reduces non-punish frontal yellow bolts (rewards punish windows, flanks, & blue banks!)
	if not is_punishable() and from_front and hit.source == LxHit.SOURCE_BOLT and not hit.pierce and not hit.cracks_armour:
		clank_t = 0.10
		return dmg * 0.45
	if not from_front and (hit.source == LxHit.SOURCE_THROW or hit.source == LxHit.SOURCE_RECALL):
		return dmg * 1.5
	return dmg


func _cargo_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
		out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.45)))
	return out


func _body_color() -> Color:
	return PAL["teal"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	# Subtle deck-roll tide indicator arrow above Bosun when listing
	var dir_x: float = -1.0 if _roll_side == "port" else 1.0
	var ind: Vector2 = (off + Vector2(0.0, -body_radius - 12.0)).round()
	draw_line(ind + Vector2(-6.0 * dir_x, 0.0), ind + Vector2(6.0 * dir_x, 0.0), PAL["sky"] as Color, 1.4)
	draw_rect(Rect2(ind + Vector2(6.0 * dir_x, -1.0), Vector2(2.0, 2.0)), PAL["gold"] as Color, true)
	if _whistle_trill_t > 0.0 and not is_flash_reduced():
		draw_arc(off + Vector2(0.0, -14.0), 14.0 + (0.45 - _whistle_trill_t) * 26.0, 0.0, TAU, 16, PAL["gold"] as Color, 1.2)
