class_name LxElderSporecapBoss
extends LxBossBase
## Hollow Oak Mini-Boss (Island 3, oak_r6): Elder Sporecap (Bible §4.6).
## 2 phases on LxBossBase. Closed fungal cap hardens outside punish windows (armour glint +
## reduced bolt chip); open golden gills during RECOVER/STAGGER take full+ damage.
## Island 3 rule: 2 Light-Plant bounce bulbs vault rings/cardinal lanes; Beam unearths the
## glowing mycelial burrow early for an instant cap-open stagger and slices P2 bramble-walls!

const RING_RADIUS: float = 82.0
const LANE_LEN: float = 136.0
const LANE_HALF_W: float = 11.0
const BURROW_SPEED: float = 118.0
const BULB_RADIUS: float = 16.0

var cap_open: bool = false
var burrowed: bool = false
var _burrow_goal: Vector2 = Vector2.ZERO
var _mycelial_trail: Array[Vector2] = []
var _trail_sample_t: float = 0.0
var _lane_ang: float = 0.0
var _lane_wave_done: bool = false
var _clank_sfx_cd: float = 0.0
var _bounce_bulbs: Array[Dictionary] = []  # [{pos, bloom, vault_cd}]
var _pillar_seq: int = 0


func _init() -> void:
	super._init()
	kind = "elder_sporecap"
	boss_id = "elder_sporecap"
	boss_name_key = "MINIBOSS_3"
	island_id = 3
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 37.0
	hp = 37.0
	body_radius = 8.5
	move_speed = 36.0
	stagger_threshold = 10.5
	stagger_duration = 1.55
	punish_dmg_mult = 1.30
	post_recover_cd = 0.30
	shard_drop = 22
	death_duration = 2.0


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.52])

	# Attack 1: Spore Ring Burst — expanding fungal shockwave + perimeter spore scatter
	register_attack("spore_ring_burst", {
		"weight": 1.25, "tell": 0.56, "commit": 0.38, "recover": 1.12, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			cap_open = false
			ground.warn_ring(pos, RING_RADIUS, last_tell_duration, 0.0, "lime", "gold")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.06, 1.0, "jade", "lime")
			stage.play_sfx("elder_sporecap_swell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			cap_open = true
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			var cnt: int = 12 if phase >= 2 else 10
			patterns.emit_gap_ring(pos, cnt, 118.0 if phase >= 2 else 106.0, gap_a + 0.45, 0.72, {"color": "lime", "source": "spore_ring"})
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 5 if phase >= 2 else 3, 0.78, 134.0, {"color": "gold", "source": "spore_fan"})
			stage.shake(0.18)
			stage.play_sfx("elder_sporecap_burst", pos),
	})

	# Attack 2: Mycelial Burrow — burrows along glowing trail (Beam pierces mound for stagger!)
	register_attack("mycelial_burrow", {
		"weight": 1.15, "tell": 0.62, "commit": 0.44, "recover": 1.15, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			cap_open = false
			burrowed = true
			_mycelial_trail.clear()
			_mycelial_trail.append(pos)
			_trail_sample_t = 0.0
			var to_w: Vector2 = tgt - pos
			var base_a: float = to_w.angle() if to_w.length() > 1.0 else facing
			var flank: Vector2 = tgt - Vector2.from_angle(base_a + (0.65 if _orbit_side > 0.0 else -0.65)) * 34.0
			_burrow_goal = clamp_to_arena(flank)
			ground.warn_ring(_burrow_goal, 28.0, last_tell_duration, 1.0, "lime", "coral")
			stage.play_sfx("sporecap_burrow", pos),
		"on_tell": func(_b: LxBossBase, _tgt: Vector2, dt: float, _prog: float) -> void:
			if not burrowed:
				return
			var step_v: Vector2 = (_burrow_goal - pos).limit_length(BURROW_SPEED * dt)
			move_boss(step_v, true)
			_trail_sample_t -= dt
			if _trail_sample_t <= 0.0:
				_trail_sample_t = 0.08
				_mycelial_trail.append(pos)
				if _mycelial_trail.size() > 14:
					_mycelial_trail.pop_front(),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			burrowed = false
			cap_open = true
			if phase >= 2 and _mycelial_trail.size() >= 3:
				var mid_pt: Vector2 = clamp_to_arena(_mycelial_trail[_mycelial_trail.size() / 2])
				if props.active_count() < 4 and mid_pt.distance_to(tgt) > 22.0:
					_pillar_seq += 1
					props.spawn_pillar(mid_pt, 3.5, "mycelial_wall_%d" % _pillar_seq)
			_mycelial_trail.clear()
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 5 if phase >= 2 else 3, 0.92, 132.0, {"color": "lime", "source": "burrow_eruption"})
			stage.shake(0.18)
			stage.play_sfx("elder_sporecap_burst", pos),
	})

	# Attack 3: Spore Mortar — telegraphed rain pods hitting Wick + corners + boomerang spore
	register_attack("spore_mortar", {
		"weight": 1.15, "tell": 0.56, "commit": 0.36, "recover": 0.98, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			cap_open = false
			var drops: Array[Vector2] = _build_mortar_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "lime", "gold")
			stage.play_sfx("elder_sporecap_swell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			cap_open = true
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_boomerang(pos, d.rotated(0.24), 138.0, 0.68, 0.65, {"color": "gold", "source": "spore_boomerang"})
			if phase >= 2:
				patterns.emit_boomerang(pos, d.rotated(-0.24), 138.0, 0.68, -0.65, {"color": "lime", "source": "spore_boomerang"})
			stage.shake(0.14)
			stage.play_sfx("elder_sporecap_burst", pos),
	})

	# Attack 4 (Phase 2): 4-Cardinal Spore Lanes — rotating cross-beam volley (vault with bulbs!)
	register_attack("cardinal_spore_lanes", {
		"phases": [2], "weight": 1.65, "tell": 0.60, "commit": 0.44, "recover": 1.20, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			cap_open = false
			_lane_wave_done = false
			_lane_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			for li: int in range(4):
				var ld: Vector2 = Vector2.from_angle(_lane_ang + float(li) * (PI * 0.5))
				ground.warn_lane(pos, pos + ld * LANE_LEN, LANE_HALF_W, last_tell_duration, 1.0, "jade", "lime")
			stage.play_sfx("elder_sporecap_swell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			cap_open = true
			for li: int in range(4):
				var ld: Vector2 = Vector2.from_angle(_lane_ang + float(li) * (PI * 0.5))
				patterns.emit_lane(pos, ld, 3, 146.0, 0.08, {"color": "lime", "source": "cardinal_spore"})
			stage.shake(0.20)
			stage.play_sfx("elder_sporecap_burst", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			if not _lane_wave_done and el >= 0.22:
				_lane_wave_done = true
				for li: int in range(4):
					var ld2: Vector2 = Vector2.from_angle(_lane_ang + PI * 0.25 + float(li) * (PI * 0.5))
					patterns.emit_lane(pos, ld2, 2, 134.0, 0.08, {"color": "gold", "source": "cardinal_spore"})
				stage.play_sfx("elder_sporecap_burst", pos),
	})


func _on_reset_encounter() -> void:
	cap_open = false
	burrowed = false
	_mycelial_trail.clear()
	_trail_sample_t = 0.0
	_lane_wave_done = false
	_clank_sfx_cd = 0.0
	_pillar_seq = 0
	_setup_bounce_bulbs()


func _setup_bounce_bulbs() -> void:
	_bounce_bulbs.clear()
	var c: Vector2 = arena_rect.get_center()
	var span_x: float = minf(68.0, arena_rect.size.x * 0.26)
	_bounce_bulbs.append({"pos": clamp_to_arena(c + Vector2(-span_x, 12.0)), "bloom": 0.45, "vault_cd": 0.0})
	_bounce_bulbs.append({"pos": clamp_to_arena(c + Vector2(span_x, -12.0)), "bloom": 0.45, "vault_cd": 0.0})


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		burrowed = false
		cap_open = false
		_mycelial_trail.clear()
		var c: Vector2 = arena_rect.get_center()
		_carve_safe_tile_near(c + Vector2(-92.0, -44.0), "pit")
		_carve_safe_tile_near(c + Vector2(92.0, 44.0), "pit")
		props.spawn_pillar(clamp_to_arena(c + Vector2(-46.0, -32.0)), 4.0, "elder_bramble_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(46.0, 32.0)), 4.0, "elder_bramble_e")
		for b_d: Dictionary in _bounce_bulbs:
			b_d["bloom"] = 1.0
		stage.darkness_pulse(0.60, 0.95)
		stage.shake(0.24)
		stage.play_sfx("elder_sporecap_phase2", pos)


func _on_attack_recover_start(_attack_id: String) -> void:
	burrowed = false
	cap_open = true


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	if boss_state == BossState.READY or boss_state == BossState.PHASE_SHIFT:
		cap_open = false
		burrowed = false
	elif boss_state == BossState.RECOVER or boss_state == BossState.STAGGER:
		cap_open = true
		burrowed = false
	_step_bounce_bulbs(dt)


func _step_bounce_bulbs(dt: float) -> void:
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var lan_p: Vector2 = _get_lantern_pos()
	var lan_r: float = 72.0 if _is_lantern_out() else 44.0
	for b_d: Dictionary in _bounce_bulbs:
		b_d["vault_cd"] = maxf(0.0, float(b_d["vault_cd"]) - dt)
		var bp: Vector2 = b_d["pos"] as Vector2
		if lan_p.distance_to(bp) <= lan_r:
			b_d["bloom"] = minf(1.0, float(b_d["bloom"]) + dt * 0.9)
		else:
			b_d["bloom"] = maxf(0.45 if phase >= 2 else 0.25, float(b_d["bloom"]) - dt * 0.14)
		if wick != null and not wick.dead and float(b_d["bloom"]) >= 0.70 and float(b_d["vault_cd"]) <= 0.0:
			if wick.global_position.distance_to(bp) <= BULB_RADIUS and (ground.is_point_in_danger(bp) or boss_state == BossState.COMMIT):
				b_d["vault_cd"] = 1.20
				var away: Vector2 = (bp - pos).normalized() if bp.distance_to(pos) > 1.0 else Vector2.UP
				if wick.has_method("push_external"):
					wick.push_external(away * 145.0, "light_plant_bounce")
				stage.light_burst(bp, 48.0, 1.15, 0.28)
				stage.play_sfx("elder_sporecap_swell", bp)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var pierce_like: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL] \
			or bool(h["pierce"]) or bool(h["cracks_armour"])
	# Beam / pierce unearths burrowed Elder Sporecap immediately for a cap-open stagger!
	if burrowed:
		if pierce_like:
			burrowed = false
			cap_open = true
			_mycelial_trail.clear()
			add_stagger(stagger_threshold)
			stage.light_burst(pos, 64.0, 1.35, 0.32)
			return dmg * 1.35
		clank_t = 0.10
		if _clank_sfx_cd <= 0.0:
			_clank_sfx_cd = 0.28
			stage.play_sfx("bramble_thorn_block", pos)
		return dmg * 0.22
	if boss_state == BossState.STAGGER:
		return dmg * 1.40
	if is_punishable():
		return dmg * (1.20 if pierce_like else 1.0)
	if pierce_like:
		return dmg * 1.15
	# Closed hardened fungal cap outside punish windows: reduced bolt chip + clear armour glint!
	clank_t = 0.10
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("bramble_thorn_block", pos)
	return dmg * 0.34


func _on_death_start() -> void:
	burrowed = false
	cap_open = true
	_mycelial_trail.clear()
	stage.revert_tiles(world_ctx)
	stage.play_sfx("elder_sporecap_phase2", pos)


func _build_mortar_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.55)))
	if phase >= 2:
		out.append(corners[2])
	return out


func _carve_safe_tile_near(world_pt: Vector2, tile_kind: String) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return
	var p: Vector2 = clamp_to_arena(world_pt)
	var ts: float = 16.0
	var tx: int = int(floorf(p.x / ts))
	var ty: int = int(floorf(p.y / ts))
	var center_p := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
	if str(world_ctx.call("tile_at", center_p)) == "ground" and center_p.distance_to(home) > 28.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), tile_kind)


func _body_color() -> Color:
	if burrowed:
		return PAL["dusk"] as Color
	if cap_open:
		return PAL["gold"] as Color
	return (PAL["wine"] if phase >= 2 else PAL["plum"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Light-Plant Bounce Bulbs (Island 3 rule)
	for b_d: Dictionary in _bounce_bulbs:
		var bp: Vector2 = ((b_d["pos"] as Vector2) - pos).round()
		var bl: float = float(b_d["bloom"])
		var ready: bool = bl >= 0.70
		draw_circle(bp, 6.0 + bl * 3.0, Color(PAL["pine"] as Color, 0.72))
		draw_arc(bp, 7.0 + bl * 4.0, 0.0, TAU, 14, (PAL["lime"] if ready else PAL["jade"]) as Color, 1.4 if ready else 1.0)
		draw_circle(bp, 2.2 + bl * 1.4, (PAL["gold"] if ready else PAL["lime"]) as Color)

	if burrowed:
		for ti: int in range(_mycelial_trail.size()):
			var tp: Vector2 = (_mycelial_trail[ti] - pos + off).round()
			var col_t: Color = (PAL["lime"] if ti % 2 == 0 else PAL["jade"]) as Color
			draw_circle(tp, 2.2 if ti == _mycelial_trail.size() - 1 else 1.5, col_t)
			if ti > 0:
				draw_line((_mycelial_trail[ti - 1] - pos + off).round(), tp, PAL["jade"] as Color, 1.4)
		draw_arc(c + Vector2(0.0, 2.0), body_radius + 2.0, PI, TAU, 14, PAL["pine"] as Color, 2.8)
		draw_arc(c + Vector2(0.0, 1.0), body_radius + 0.8, PI, TAU, 12, PAL["lime"] as Color, 1.4)
		return

	# Armour glint when closed cap deflects plain bolts outside punish windows
	if clank_t > 0.0:
		var ga: float = facing
		draw_arc(c + Vector2(0.0, -3.0), body_radius + 4.5, ga - 1.1, ga + 1.1, 14, PAL["cream"] as Color, 2.2)
		draw_arc(c + Vector2(0.0, -3.0), body_radius + 6.5, ga - 0.8, ga + 0.8, 12, PAL["gold"] as Color, 1.2)
	elif not is_punishable() and boss_state != BossState.DEATH and boss_state != BossState.IDLE:
		draw_arc(c + Vector2(0.0, -3.0), body_radius + 3.0, PI + 0.35, TAU - 0.35, 14, Color(PAL["apricot"] as Color, 0.42), 1.1)

	# Open golden gill punish halo
	if cap_open and is_punishable():
		var vr: float = body_radius + 4.5 + (0.0 if is_flash_reduced() else 0.8 * sin(anim_t * 14.0))
		draw_arc(c, vr + 1.4, 0.0, TAU, 24, PAL["apricot"] as Color, 1.2)
		draw_arc(c, vr, 0.0, TAU, 24, PAL["gold"] as Color, 1.8)
		for vi: int in range(4):
			var vd: Vector2 = Vector2.from_angle(anim_t * 1.6 + float(vi) * (PI * 0.5))
			draw_circle((c + vd * (vr + 1.5)).round(), 1.1, PAL["cream"] as Color)
