class_name LxGreatLilyHopperBoss
extends LxBossBase
## Drowned Conservatory Mini-Boss (Island 4, conservatory_r6): Great Lily Hopper (Bible §4.6).
## 2 phases on LxBossBase. Wet lily-carapace deflects plain bolts outside punish windows
## (water-glint + reduced chip); open crown blossom during RECOVER/STAGGER takes full+ damage.
## Island 4 rule: 4 perimeter thermal updraft plumes refresh Wings hover & enable 1.6x mid-air
## intercept staggers; P2 floods rim pads (stage.set_tiles water) + Twin-Ripple Hop!

const LEAP_AIR_TIME: float = 0.42
const LEAP_HEIGHT: float = 24.0
const UPDRAFT_R: float = 22.0
const SUBMERGE_DUR: float = 2.4

var hop_z: float = 0.0
var _leap_from: Vector2 = Vector2.ZERO
var _leap_to: Vector2 = Vector2.ZERO
var _leap_landed: bool = false
var _twin_stage: int = 0
var _spit_dir: Vector2 = Vector2.RIGHT
var _whip_dir: Vector2 = Vector2.RIGHT
var _updrafts: Array[Dictionary] = []        # [{pos, catch_cd, burst_t}]
var _submerged_pads: Array[Dictionary] = []  # [{pos, ttl, max_ttl}]
var _clank_sfx_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "great_lily_hopper"
	boss_id = "great_lily_hopper"
	boss_name_key = "MINIBOSS_4"
	island_id = 4
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island4_boss_p1"
	music_p2_cue = "island4_boss_p2"
	max_hp = 44.0
	hp = 44.0
	body_radius = 8.5
	move_speed = 44.0
	stagger_threshold = 10.5
	stagger_duration = 1.55
	punish_dmg_mult = 1.30
	post_recover_cd = 0.28
	shard_drop = 24
	death_duration = 2.0


func _configure_boss(_spec: Dictionary) -> void:
	if world_ctx != null and str(world_ctx.get("current_region_id")) == "conservatory_r6":
		arena_rect = Rect2(176.0, 64.0, 144.0, 108.0)
	configure_phases([0.52])

	# Attack 1: Lily Leap Slam — parabolic hop (air-interceptable!) + water shockwave ring
	register_attack("lily_leap_slam", {
		"weight": 1.25, "tell": 0.52, "commit": 0.50, "recover": 1.15, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			hop_z = 0.0
			_leap_from = pos
			_leap_to = clamp_to_arena(tgt)
			_leap_landed = false
			ground.warn_ring(_leap_to, 30.0, last_tell_duration + LEAP_AIR_TIME * 0.65, 1.0, "sky", "gold")
			stage.play_sfx("hopper_crouch", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_leap_from = pos
			_leap_landed = false
			stage.play_sfx("hopper_leap", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, el: float) -> void:
			if el < LEAP_AIR_TIME:
				var u: float = clampf(el / LEAP_AIR_TIME, 0.0, 1.0)
				hop_z = sin(u * PI) * LEAP_HEIGHT
				var desired: Vector2 = _leap_from.lerp(_leap_to, u)
				move_boss(desired - pos, true)
			elif not _leap_landed:
				_leap_landed = true
				hop_z = 0.0
				var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
				patterns.emit_gap_ring(pos, 12 if phase >= 2 else 10, 122.0 if phase >= 2 else 110.0, gap_a + 0.40, 0.72, {"color": "sky", "source": "lily_ring"})
				stage.shake(0.18)
				stage.play_sfx("hopper_land", pos)
				if phase >= 2:
					_trigger_submerging_rim_pads(),
	})

	# Attack 2: Petal Spit Fan — 3-arc (P2: 5-arc) blooming coral lily petals + side water drops
	register_attack("petal_spit_fan", {
		"weight": 1.20, "tell": 0.50, "commit": 0.30, "recover": 0.96, "cooldown": 1.30,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			hop_z = 0.0
			_spit_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _spit_dir.angle()
			ground.warn_sector(pos, _spit_dir.angle() - 0.65, _spit_dir.angle() + 0.65, 96.0, last_tell_duration, 0.0, "rose", "coral")
			var drops: Array[Vector2] = _build_splash_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 21.0, 1.0, "sky", "gold")
			stage.play_sfx("hopper_crouch", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _spit_dir, cnt, 0.85 if phase >= 2 else 0.58, 144.0, {"color": "coral", "source": "lily_petal"})
			stage.shake(0.12)
			stage.play_sfx("barnacle_fire", pos),
	})

	# Attack 3: Tongue Whip Sweep — long telegraphed water-lance pressuring all perimeter spots
	register_attack("tongue_whip_sweep", {
		"weight": 1.15, "tell": 0.52, "commit": 0.34, "recover": 1.00, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			hop_z = 0.0
			_whip_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _whip_dir.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + _whip_dir * 144.0), 9.0, last_tell_duration, 0.0, "coral", "rose")
			stage.play_sfx("hopper_crouch", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_lane(pos, _whip_dir, 4 if phase >= 2 else 3, 148.0, 0.08, {"color": "rose", "source": "tongue_whip", "damage": 0.5})
			patterns.emit_boomerang(pos, _whip_dir.rotated(0.28), 128.0, 0.65, 0.65, {"color": "sky", "source": "lily_splash", "damage": 0.5})
			stage.shake(0.14)
			stage.play_sfx("marsh_splash", pos),
	})

	# Attack 4 (Phase 2): Twin-Ripple Hop — consecutive double leap + expanding water square + rim submerge
	register_attack("twin_ripple_hop", {
		"phases": [2], "weight": 1.65, "tell": 0.56, "commit": 0.80, "recover": 1.20, "cooldown": 1.60,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			hop_z = 0.0
			_twin_stage = 0
			_leap_from = pos
			_leap_to = clamp_to_arena(pos.lerp(tgt, 0.65))
			ground.warn_ring(_leap_to, 26.0, last_tell_duration + 0.28, 1.0, "sky", "gold")
			stage.play_sfx("hopper_crouch", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_leap_from = pos
			_twin_stage = 0
			stage.play_sfx("hopper_leap", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, el: float) -> void:
			if el < 0.32:
				var u1: float = clampf(el / 0.32, 0.0, 1.0)
				hop_z = sin(u1 * PI) * 20.0
				move_boss(_leap_from.lerp(_leap_to, u1) - pos, true)
			elif _twin_stage == 0:
				_twin_stage = 1
				hop_z = 0.0
				_trigger_submerging_rim_pads()
				patterns.emit_expanding_square(pos, 3, 118.0, facing, 1, {"color": "sky", "source": "twin_ripple"})
				stage.shake(0.18)
				stage.play_sfx("hopper_land", pos)
				_leap_from = pos
				_leap_to = clamp_to_arena(tgt)
			elif el >= 0.44 and el < 0.76:
				if _twin_stage == 1:
					_twin_stage = 2
					stage.play_sfx("hopper_leap", pos)
				var u2: float = clampf((el - 0.44) / 0.32, 0.0, 1.0)
				hop_z = sin(u2 * PI) * 22.0
				move_boss(_leap_from.lerp(_leap_to, u2) - pos, true)
			elif el >= 0.76 and _twin_stage < 3:
				_twin_stage = 3
				hop_z = 0.0
				var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
				patterns.emit_gap_ring(pos, 12, 128.0, gap_a + 0.38, 0.70, {"color": "ice", "source": "twin_ripple"})
				stage.shake(0.20)
				stage.play_sfx("hopper_land", pos),
	})


func is_flying() -> bool:
	return boss_state == BossState.COMMIT and hop_z > 6.0


func _on_reset_encounter() -> void:
	hop_z = 0.0
	_leap_landed = false
	_twin_stage = 0
	_submerged_pads.clear()
	_clank_sfx_cd = 0.0
	_setup_perimeter_updrafts()


func _setup_perimeter_updrafts() -> void:
	_updrafts.clear()
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "updraft_vent":
				return
	var c: Vector2 = arena_rect.get_center()
	var sx: float = minf(84.0, arena_rect.size.x * 0.32)
	var sy: float = minf(48.0, arena_rect.size.y * 0.30)
	for off_v: Vector2 in [Vector2(-sx, -sy), Vector2(sx, -sy), Vector2(-sx, sy), Vector2(sx, sy)]:
		_updrafts.append({"pos": clamp_to_arena(c + off_v), "catch_cd": 0.0, "burst_t": 0.0})


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		hop_z = 0.0
		var c: Vector2 = arena_rect.get_center()
		# P2 Arena Mutation: Submerging rim pad tiles flood to water (rolled back on reset!)
		_carve_safe_tile_near(c + Vector2(-86.0, -42.0), "water")
		_carve_safe_tile_near(c + Vector2(86.0, -42.0), "water")
		_carve_safe_tile_near(c + Vector2(-86.0, 42.0), "water")
		_carve_safe_tile_near(c + Vector2(86.0, 42.0), "water")
		props.spawn_pillar(clamp_to_arena(c + Vector2(-52.0, 0.0)), 4.0, "lily_reed_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(52.0, 0.0)), 4.0, "lily_reed_e")
		_trigger_submerging_rim_pads()
		stage.darkness_pulse(0.56, 0.90)
		stage.shake(0.24)
		stage.play_sfx("great_hopper_phase2", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	if boss_state != BossState.COMMIT:
		hop_z = absf(sin(anim_t * 8.0)) * 3.5 if boss_state == BossState.READY else 0.0
	_step_updrafts_and_pads(dt)


func _trigger_submerging_rim_pads() -> void:
	_submerged_pads.clear()
	var c: Vector2 = arena_rect.get_center()
	for off_v: Vector2 in [Vector2(-68.0, -34.0), Vector2(68.0, -34.0), Vector2(-68.0, 34.0), Vector2(68.0, 34.0)]:
		_submerged_pads.append({"pos": clamp_to_arena(c + off_v), "ttl": SUBMERGE_DUR, "max_ttl": SUBMERGE_DUR})


func _step_updrafts_and_pads(dt: float) -> void:
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var gliding: bool = wick != null and not wick.dead and wick.is_gliding()
	for ud: Dictionary in _updrafts:
		ud["catch_cd"] = maxf(0.0, float(ud["catch_cd"]) - dt)
		ud["burst_t"] = maxf(0.0, float(ud["burst_t"]) - dt)
		if gliding and wick.move_wings != null and wick.global_position.distance_to(ud["pos"] as Vector2) <= UPDRAFT_R + 6.0:
			wick.move_wings.refresh_glide(1.25, 2.2)
			if float(ud["catch_cd"]) <= 0.0:
				ud["catch_cd"] = 0.45
				ud["burst_t"] = 0.30
				stage.play_sfx("heron_gust_fire", ud["pos"] as Vector2)
	for i: int in range(_submerged_pads.size() - 1, -1, -1):
		var sp: Dictionary = _submerged_pads[i]
		sp["ttl"] = float(sp["ttl"]) - dt
		if wick != null and not wick.dead and not gliding and wick.global_position.distance_to(sp["pos"] as Vector2) <= 15.0:
			if wick.has_method("push_external"):
				var away: Vector2 = (wick.global_position - (sp["pos"] as Vector2)).normalized()
				wick.push_external(away * 24.0, "submerged_pad")
		if float(sp["ttl"]) <= 0.0:
			_submerged_pads.remove_at(i)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var gliding: bool = wick != null and not wick.dead and wick.is_gliding()
	var heavy: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE] \
			or bool(h["pierce"]) or bool(h["cracks_armour"])

	# Mid-air intercept crash: gliding bolt or heavy throw/beam mid-leap triggers instant air-stagger!
	if is_flying() and (gliding or heavy):
		hop_z = 0.0
		add_stagger(stagger_threshold)
		stage.play_sfx("hopper_air_stagger", pos)
		return dmg * 1.55

	if boss_state == BossState.STAGGER:
		return dmg * 1.45
	if is_punishable():
		return dmg * (1.20 if (heavy or gliding) else 1.0)
	if heavy or gliding:
		return dmg * 1.15

	# Wet armored lily-pad shell outside punish windows: reduced bolt chip + clear water-glint!
	clank_t = 0.10
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("crab_shell_clank", pos)
	return dmg * 0.34


func _on_death_start() -> void:
	hop_z = 0.0
	_submerged_pads.clear()
	stage.revert_tiles(world_ctx)
	stage.play_sfx("great_hopper_phase2", pos)


func _build_splash_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
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


func _carve_safe_tile_near(world_pt: Vector2, tile_kind: String) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return
	var p: Vector2 = clamp_to_arena(world_pt)
	var tx: int = int(floorf(p.x / 16.0))
	var ty: int = int(floorf(p.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if str(world_ctx.call("tile_at", cp)) == "ground" and cp.distance_to(home) > 30.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), tile_kind)


func _visual_offset() -> Vector2:
	return Vector2(0.0, -hop_z)


func _body_color() -> Color:
	return (PAL["teal"] if phase >= 2 else PAL["jade"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Perimeter thermal updraft plumes (Wings hover + mid-air intercept support!)
	for ud: Dictionary in _updrafts:
		var up: Vector2 = ((ud["pos"] as Vector2) - pos).round()
		draw_arc(up, UPDRAFT_R, 0.0, TAU, 18, Color(PAL["sky"] as Color, 0.42), 1.0)
		draw_arc(up, UPDRAFT_R - 5.0, anim_t * 3.6, anim_t * 3.6 + PI * 1.1, 12, Color(PAL["ice"] as Color, 0.78), 1.2)
		draw_rect(Rect2(up + Vector2(-4.0, -4.0), Vector2(8.0, 8.0)), Color(PAL["night"] as Color, 0.70))
		draw_rect(Rect2(up + Vector2(-3.0, -1.0), Vector2(6.0, 2.0)), PAL["sky"] as Color)

	# Phase 2 Submerging Rim Pads
	for sp: Dictionary in _submerged_pads:
		var pp_s: Vector2 = ((sp["pos"] as Vector2) - pos).round()
		var frac_s: float = clampf(float(sp["ttl"]) / maxf(float(sp["max_ttl"]), 0.05), 0.0, 1.0)
		draw_circle(pp_s, 14.0, Color(PAL["blue"] as Color, 0.36 * frac_s))
		draw_arc(pp_s, 14.0, 0.0, TAU, 14, Color(PAL["sky"] as Color, 0.78 * frac_s), 1.4)

	# Airborne shadow when leaping
	if hop_z > 2.0:
		var sh_r: float = maxf(3.0, body_radius * clampf(1.0 - hop_z / 32.0, 0.35, 1.0))
		draw_circle(Vector2.ZERO, sh_r, Color(PAL["void"] as Color, 0.55))

	# Armour water-glint outside punish windows vs golden crown punish halo
	if clank_t > 0.0:
		draw_arc(c, body_radius + 4.5, facing - 1.1, facing + 1.1, 14, PAL["cream"] as Color, 2.2)
		draw_arc(c, body_radius + 6.5, facing - 0.8, facing + 0.8, 12, PAL["ice"] as Color, 1.2)
	elif is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 4.0, 0.0, TAU, 20, PAL["gold"] as Color, 1.6)
