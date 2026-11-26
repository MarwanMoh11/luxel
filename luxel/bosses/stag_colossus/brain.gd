class_name LxStagColossusBoss
extends LxBossBase
## Island 3 Mini-Boss A: The Stag Colossus (underroot_r6).
## Bus-sized stag beetle with an invulnerable-feeling mirrored carapace (reflects Prism!).
## Counterplay:
##  1. Timber Charge: bloom a light_plant wall (or bait into wall/pillar) to FLIP it onto its
##     back for a 1.7s open-belly punish (6 stubby legs pedaling in mid-air!).
##  2. Pincer Cleave: dash behind its wide 120-deg cleave + sap wave to punish flank.
##  3. Acorn Hail: weave through 5-7 telegraphed ground circles (pressures all 8 edges).
##  4. P2 Arena Change: shakes outer bark pillars down, exposing 2 corner Dew Lenses;
##     shooting a Dew Lens or banking Prism off its shell triggers Overheat Stagger!

const CHARGE_SPEED: float = 230.0
const FLIP_STAGGER_S: float = 1.45
const OVERHEAT_STAGGER_S: float = 1.50
const CLEAVE_R: float = 46.0
const FRONT_SHELL_HALF: float = 1.15

var _charge_dir: Vector2 = Vector2.LEFT
var _cleave_dir: Vector2 = Vector2.LEFT
var _flipped: bool = false
var _overheated_t: float = 0.0
var _dew_lenses: Array[Dictionary] = []
var _acorn_wave_done: bool = false


func _init() -> void:
	super._init()
	kind = "stag_colossus"
	boss_id = "stag_colossus"
	boss_name_key = "ISL3_BOSS_STAG"
	island_id = 3
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 71.0
	hp = 71.0
	body_radius = 12.5
	move_speed = 38.0
	stagger_threshold = 28.0
	stagger_duration = FLIP_STAGGER_S
	post_stagger_immunity = 8.5
	punish_dmg_mult = 1.15
	post_recover_cd = 0.36
	shard_drop = 18
	death_duration = 2.2


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Timber Charge (tell 0.58s, commit 0.55s @ 230 px/s, recover 1.15s)
	register_attack("timber_charge", {
		"weight": 1.35, "tell": 0.58, "commit": 0.55, "recover": 1.15, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_charge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var end_p: Vector2 = clamp_to_arena(pos + _charge_dir * 136.0)
			ground.warn_lane(pos, end_p, 13.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("stag_horn_scrape", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.16)
			stage.play_sfx("stag_charge", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			var prev_p: Vector2 = pos
			var step: Vector2 = _charge_dir * CHARGE_SPEED * dt
			move_boss(step, false)
			check_contact_damage(19.0, _charge_dir, 1.0, "stag_charge")
			var hit_edge: bool = pos.distance_to(prev_p) < step.length() * 0.32 and elapsed > 0.22
			var hit_plant: bool = _hit_grown_plant_wall()
			if hit_plant or (hit_edge and stagger_immunity_t <= 0.0):
				_trigger_flip_stagger()
				return
			if phase >= 2 and int(elapsed * 5.0) != int((elapsed - dt) * 5.0):
				ground.add_hazard_circle(pos, 10.0, 1.1, 0.5, "apricot"),
	})

	# Attack 2: Pincer Cleave (tell 0.56s, commit 0.28s, recover 1.15s)
	register_attack("pincer_cleave", {
		"weight": 1.20, "tell": 0.56, "commit": 0.28, "recover": 1.15, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_cleave_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var ang: float = _cleave_dir.angle()
			ground.warn_sector(pos, ang - 1.00, ang + 1.00, CLEAVE_R, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_lane(pos, pos + _cleave_dir * 138.0, 9.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("stag_horn_scrape", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _cleave_dir
			patterns.emit_fan(pos, aim, 3, 0.62, 118.0 if phase >= 2 else 110.0, {"color": "apricot", "source": "stag_cleave", "damage": 0.5})
			stage.shake(0.14)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, _el: float) -> void:
			if not _commit_hit_done and _has_player():
				var rel: Vector2 = tgt - pos
				if rel.length() <= CLEAVE_R and absf(angle_difference(_cleave_dir.angle(), rel.angle())) <= 1.00:
					_commit_hit_done = true
					emit_boss_damage(rel.normalized(), 0.5, "stag_cleave", pos, true),
	})

	# Attack 3: Acorn Hail (tell 0.68s, commit 0.68s, recover 1.25s — pressures corners & edges!)
	register_attack("acorn_hail", {
		"weight": 1.15, "tell": 0.68, "commit": 0.68, "recover": 1.25, "cooldown": 1.9,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_acorn_wave_done = false
			var drops: Array[Vector2] = _build_acorn_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 19.0, 0.5, "coral", "gold")
			stage.play_sfx("golem_stomp", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			patterns.emit_gap_ring(pos, 8, 102.0, aim.angle() + 0.55, 0.92, {"color": "gold", "source": "stag_acorn", "damage": 0.5})
			stage.shake(0.18),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, _dt: float, elapsed: float) -> void:
			if phase >= 2 and not _acorn_wave_done and elapsed >= 0.34:
				_acorn_wave_done = true
				var aim2: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.RIGHT
				patterns.emit_lane(pos, aim2, 1, 126.0, 0.10, {"color": "coral", "source": "stag_acorn", "damage": 0.5}),
	})

	# Attack 4 (P2): Mirror Prism Flare (reflects sun-shards across arena)
	register_attack("mirror_flare", {
		"phases": [2], "weight": 1.20, "tell": 0.60, "commit": 0.44, "recover": 1.20, "cooldown": 1.9,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			ground.warn_ring(pos, 46.0, last_tell_duration, 0.0, "ice", "gold")
			ground.warn_lane(pos, clamp_to_arena(pos + aim * 140.0), 9.0, last_tell_duration, 0.0, "sky", "ice")
			stage.light_burst(pos, 96.0, 1.35, 0.40)
			stage.play_sfx("prism_chain", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			patterns.emit_gap_ring(pos, 9, 106.0, aim.angle() + 0.60, 0.92, {"color": "ice", "source": "stag_mirror", "damage": 0.5})
			patterns.emit_boomerang(pos, aim, 114.0, 0.65, 0.44, {"color": "sky", "source": "stag_mirror", "damage": 0.5})
			stage.shake(0.16),
	})


## Living mirrored carapace reflects player Prism shots when upright!
func is_reflective() -> bool:
	return is_alive() and not _flipped and boss_state != BossState.STAGGER and boss_state != BossState.DEATH


func _has_active_shield() -> bool:
	return is_reflective() and boss_state != BossState.RECOVER


func reflect_dir(in_dir: Vector2) -> Vector2:
	var n: Vector2 = Vector2.from_angle(facing)
	if in_dir.dot(n) > 0.0:
		n = -n
	return in_dir.normalized().bounce(n).normalized()


func _on_reset_encounter() -> void:
	_flipped = false
	_overheated_t = 0.0
	_dew_lenses.clear()
	var c: Vector2 = arena_rect.get_center()
	# P1 outer bark pillars (shaken down on Phase 2 transition!)
	props.spawn_pillar(c + Vector2(-92.0, -40.0), 4.0, "stag_pillar_nw")
	props.spawn_pillar(c + Vector2(92.0, 40.0), 4.0, "stag_pillar_se")


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# Shake down outer bark pillars & crack corner vents, revealing 2 corner Dew Lenses!
		props.clear()
		stage.set_tiles(world_ctx, Rect2i(2, 2, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(17, 7, 1, 1), "pit")
		var inset: Rect2 = arena_rect.grow(-26.0)
		_dew_lenses = [
			{"pos": inset.position, "cd": 0.0, "flash": 0.0},
			{"pos": Vector2(inset.end.x, inset.position.y), "cd": 0.0, "flash": 0.0},
		]
		stage.shake(0.24)
		stage.darkness_pulse(0.56, 0.95)
		stage.play_sfx("stag_overheat", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_overheated_t = maxf(0.0, _overheated_t - dt)
	if boss_state != BossState.STAGGER:
		_flipped = false
	_tick_dew_lenses(dt)


func _tick_dew_lenses(dt: float) -> void:
	if _dew_lenses.is_empty():
		return
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for dl: Dictionary in _dew_lenses:
		dl["cd"] = maxf(0.0, float(dl["cd"]) - dt)
		dl["flash"] = maxf(0.0, float(dl["flash"]) - dt)
		if wick_node == null or float(dl["cd"]) > 0.0:
			continue
		var dp: Vector2 = dl["pos"] as Vector2
		for bi: int in range(wick_node.bolts.size() - 1, -1, -1):
			var bv: Variant = wick_node.bolts[bi]
			if bv is Object and (bv.get("pos") as Vector2).distance_to(dp) <= 13.0:
				wick_node.bolts.remove_at(bi)
				dl["cd"] = 4.0
				dl["flash"] = 0.55
				# Focused dew ray blasts the Stag Colossus -> Overheat Stagger!
				_trigger_overheat_stagger()
				break


func _trigger_flip_stagger() -> void:
	_flipped = true
	stagger_duration = FLIP_STAGGER_S
	stagger_immunity_t = 0.0
	add_stagger(stagger_threshold)
	stage.shake(0.20)
	stage.play_sfx("stag_flip_thud", pos)


func _trigger_overheat_stagger() -> void:
	_overheated_t = 2.6
	_flipped = true
	stagger_duration = OVERHEAT_STAGGER_S
	stagger_immunity_t = 0.0
	hp = maxf(1.0, hp - 2.5)
	add_stagger(stagger_threshold)
	stage.light_burst(pos, 84.0, 1.45, 0.35)
	stage.play_sfx("stag_overheat", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	if _flipped or boss_state == BossState.STAGGER:
		return dmg * 0.95
	if hit.source == LxHit.SOURCE_PRISM or hit.source == LxHit.SOURCE_BEAM or hit.source == "dew_ray":
		return dmg * 1.15
	if boss_state == BossState.RECOVER:
		return dmg * 0.44
	var rel: Vector2 = hit.origin - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < FRONT_SHELL_HALF + 0.20
	if from_front:
		clank_t = 0.12
		stage.play_sfx("burrow_beetle_clank", pos)
		return dmg * 0.14
	return dmg * 0.28


func _build_acorn_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var c: Vector2 = arena_rect.get_center()
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	out.append(clamp_to_arena(tgt.lerp(c, 0.55)))
	out.append(clamp_to_arena(c + (c - tgt).limit_length(52.0)))
	if phase >= 2:
		out.append(corners[2])
		out.append(corners[3])
	return out


func _hit_grown_plant_wall() -> bool:
	var ctx: Node = world_ctx if world_ctx != null else Lx.world
	if ctx == null or not is_instance_valid(ctx) or not ctx.has_method("get_interactables"):
		return false
	for it_v: Variant in (ctx.call("get_interactables") as Array):
		if it_v is Object and is_instance_valid(it_v as Object):
			var it: Object = it_v as Object
			if str(it.get("kind")) == "light_plant" and it.has_method("is_solid") and bool(it.call("is_solid")):
				var ip: Vector2 = it.get("pos") as Vector2 if it.get("pos") is Vector2 else Vector2.ZERO
				if ip.distance_to(pos) <= body_radius + 14.0:
					return true
	return false


func _on_death_start() -> void:
	_flipped = true
	stage.shake(0.28)
	stage.light_burst(pos, 110.0, 1.5, 0.55)
	stage.play_sfx("stag_overheat", pos)


func _body_color() -> Color:
	return PAL["jade"] as Color if phase >= 2 else PAL["teal"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	# Draw P2 corner Dew Lens overheat prisms
	for dl: Dictionary in _dew_lenses:
		var lp: Vector2 = ((dl["pos"] as Vector2) - pos).round()
		var fl: float = float(dl["flash"])
		draw_circle(lp, 9.0, PAL["night"] as Color)
		draw_circle(lp, 7.2, PAL["cream"] as Color if fl > 0.0 else PAL["sky"] as Color)
		draw_circle(lp + Vector2(-2.0, -2.0), 3.0, PAL["ice"] as Color)
		if fl > 0.0:
			draw_line(lp, off.round(), PAL["gold"] as Color, 3.0)
			draw_line(lp, off.round(), PAL["cream"] as Color, 1.4)
	if _overheated_t > 0.0:
		draw_arc(off.round(), body_radius + 5.0, 0.0, TAU, 20, PAL["coral"] as Color, 1.6)
