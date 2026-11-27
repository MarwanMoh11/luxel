class_name LxBriarMatronBoss
extends LxBossBase
## Hollow Oak Keeper Boss (Island 3, oak_r10): The Briar Matron (Bible §4.7).
## 3 phases (66%/33%) on LxBossBase. Woven silk-thorn carapace hardens outside punish windows
## (armour glint + reduced bolt chip); Beam pierces web barrier AND chain-burns P2 3-Lane Silk
## Web Snares for an instant stagger! P1: 2 Light-Plant bounce bulbs; P2: Growth Ring pit
## trenches + silk snares; P3: canopy darkness + Heartwood Sun-Bloom exposing Scuttle Ambush!

enum MatronMove { MELEE, SPORE_RING, WEB_SNARE, SCUTTLE_AMBUSH }

const SNARE_TELL: float = 0.54
const SNARE_COMMIT_TIME: float = 0.34
const SNARE_LANE_LEN: float = 112.0
const SNARE_HALF_W: float = 11.0
const SNARE_TTL: float = 5.5
const SNARE_SPREAD: float = 0.42
const WEB_SHIELD_MAX: float = 6.0
const WEB_REGEN_RATE: float = 0.45

# Compat fields referenced by tests/luxel/boss_qa_capture.gd
var active_move: int = MatronMove.MELEE
var snare_dir: Vector2 = Vector2.RIGHT
var snare_spawned: bool = false
var web_lanes: Array[Dictionary] = []
var _roaring: bool = false

var _web_shield: float = WEB_SHIELD_MAX
var _shield_down_t: float = 0.0
var _snare_tick_cd: float = 0.0
var _cleave_dir: Vector2 = Vector2.RIGHT
var _ambush_dir: Vector2 = Vector2.RIGHT
var _ambush_side: float = 1.0
var _ambush_flank_done: bool = false
var _ambush_ghost_pos: Vector2 = Vector2.ZERO
var _ambush_ghost_t: float = 0.0
var _sun_bloom_pos: Vector2 = Vector2.ZERO
var _sun_bloom_lit_t: float = 0.0
var _bounce_bulbs: Array[Dictionary] = []
var _clank_sfx_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "briar_matron"
	boss_id = "briar_matron"
	boss_name_key = "BOSS_MATRON"
	island_id = 3
	is_miniboss = false
	reward_heart = "full"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 72.0
	hp = 72.0
	body_radius = 9.5
	move_speed = 38.0
	stagger_threshold = 13.5
	stagger_duration = 1.70
	punish_dmg_mult = 1.32
	post_recover_cd = 0.36
	shard_drop = 40
	death_duration = 2.4


func _configure_boss(_spec: Dictionary) -> void:
	if world_ctx != null and str(world_ctx.get("current_region_id")) == "oak_r10":
		arena_rect = Rect2(88.0, 56.0, 304.0, 168.0)
	configure_phases([0.66, 0.33])

	# Attack 1: Thorn Cleave Lunge — charging mandibles + wide sector sweep + bramble bolt fan
	register_attack("thorn_cleave_lunge", {
		"weight": 1.25, "tell": 0.52, "commit": 0.34, "recover": 1.05, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = MatronMove.MELEE
			_cleave_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _cleave_dir.angle()
			var lunge_end: Vector2 = clamp_to_arena(pos + _cleave_dir * 62.0)
			ground.warn_lane(pos, lunge_end, 11.0, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_sector(lunge_end, _cleave_dir.angle() - 0.95, _cleave_dir.angle() + 0.95, 44.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("warden_alert", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _cleave_dir, 5 if phase >= 3 else 3, 0.88, 114.0, {"color": "coral", "source": "thorn_cleave", "damage": 0.5})
			stage.shake(0.16)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_cleave_dir * 105.0 * dt, false)
			check_contact_damage(22.0, _cleave_dir, 1.0, "thorn_cleave"),
	})

	# Attack 2: Spore Ring Wave — expanding toxic ring + outer spore pods
	register_attack("spore_ring_wave", {
		"weight": 1.20, "tell": 0.60, "commit": 0.36, "recover": 1.18, "cooldown": 1.60,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = MatronMove.SPORE_RING
			ground.warn_ring(pos, 78.0, last_tell_duration, 0.0, "lime", "coral")
			ground.warn_ring(tgt, 22.0, last_tell_duration + 0.06, 0.5, "jade", "lime")
			stage.play_sfx("briar_spore_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			var cnt: int = 12 if phase >= 3 else 10
			patterns.emit_gap_ring(pos, cnt, 110.0 if phase >= 2 else 100.0, gap_a, 0.94, {"color": "lime", "source": "matron_spore", "damage": 0.5})
			stage.shake(0.20)
			stage.play_sfx("briar_spore_burst", pos),
	})

	# Attack 3: Briar Volley — corner-pressuring thorn rain + curving thorny boomerangs
	register_attack("briar_volley", {
		"weight": 1.15, "tell": 0.56, "commit": 0.36, "recover": 1.05, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = MatronMove.MELEE
			var drops: Array[Vector2] = _build_volley_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 20.0, 0.5, "coral", "gold")
			stage.play_sfx("briar_spore_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_boomerang(pos, d.rotated(0.30), 124.0, 0.65, 0.65, {"color": "coral", "source": "briar_thorn", "damage": 0.5})
			if phase >= 2:
				patterns.emit_boomerang(pos, d.rotated(-0.30), 124.0, 0.65, -0.65, {"color": "lime", "source": "briar_thorn", "damage": 0.5})
			stage.shake(0.14)
			stage.play_sfx("briar_web_cast", pos),
	})

	# Attack 4 (P2/P3): 3-Lane Silk Web Snares — lingering sticky lanes (Beam chain-burns for stagger!)
	register_attack("web_snare_lanes", {
		"phases": [2, 3], "weight": 1.55, "tell": SNARE_TELL, "commit": SNARE_COMMIT_TIME, "recover": 1.18, "cooldown": 2.1,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = MatronMove.WEB_SNARE
			snare_spawned = false
			snare_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = snare_dir.angle()
			for idx: int in [-1, 0, 1]:
				var ld: Vector2 = snare_dir.rotated(float(idx) * SNARE_SPREAD)
				ground.warn_lane(pos + ld * (body_radius + 2.0), pos + ld * SNARE_LANE_LEN, SNARE_HALF_W, last_tell_duration, 0.0, "jade", "lime")
			stage.play_sfx("briar_spore_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			snare_spawned = true
			web_lanes.clear()
			for idx: int in [-1, 0, 1]:
				var ld: Vector2 = snare_dir.rotated(float(idx) * SNARE_SPREAD)
				web_lanes.append({"origin": pos + ld * (body_radius + 2.0), "dir": ld, "length": SNARE_LANE_LEN, "ttl": 4.0})
				patterns.emit_lane(pos, ld, 2, 118.0, 0.12, {"color": "ice", "source": "silk_shot"})
			stage.shake(0.16)
			stage.play_sfx("briar_web_cast", pos),
	})

	# Attack 5 (P3): Scuttle Ambush — fast flank skitter + cross-web lunge slash
	register_attack("scuttle_ambush", {
		"phases": [3], "weight": 1.75, "tell": 0.56, "commit": 0.34, "recover": 1.22, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			active_move = MatronMove.SCUTTLE_AMBUSH
			_ambush_flank_done = false
			_ambush_side = -_ambush_side
			_ambush_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _ambush_dir.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + _ambush_dir * 76.0), 11.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("briar_ambush_tell", pos),
		"on_tell": func(_b: LxBossBase, tgt: Vector2, _dt: float, prog: float) -> void:
			if not _ambush_flank_done and prog >= 0.45:
				_ambush_flank_done = true
				_ambush_ghost_pos = pos
				_ambush_ghost_t = 0.34
				var perp: Vector2 = _ambush_dir.rotated(PI * 0.5 * _ambush_side)
				move_boss(perp * 22.0, false)
				_ambush_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else _ambush_dir
				facing = _ambush_dir.angle()
				ground.warn_lane(pos, clamp_to_arena(pos + _ambush_dir * 76.0), 11.0, maxf(0.25, state_timer), 0.0, "coral", "cream")
				stage.play_sfx("briar_scuttle", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _ambush_dir, 5, 1.05, 126.0, {"color": "coral", "source": "scuttle_slash"})
			stage.shake(0.18)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_ambush_dir * 135.0 * dt, false)
			check_contact_damage(22.0, _ambush_dir, 1.0, "scuttle_slash"),
	})


func _on_reset_encounter() -> void:
	active_move = MatronMove.MELEE
	snare_dir = Vector2.from_angle(facing)
	snare_spawned = false
	web_lanes.clear()
	_roaring = false
	_web_shield = WEB_SHIELD_MAX
	_shield_down_t = 0.0
	_snare_tick_cd = 0.0
	_ambush_ghost_t = 0.0
	_sun_bloom_pos = arena_rect.get_center()
	_sun_bloom_lit_t = 0.0
	_clank_sfx_cd = 0.0
	_bounce_bulbs.clear()
	var c: Vector2 = arena_rect.get_center()
	var sx: float = minf(76.0, arena_rect.size.x * 0.28)
	_bounce_bulbs.append({"pos": clamp_to_arena(c + Vector2(-sx, 20.0)), "bloom": 0.5, "vault_cd": 0.0})
	_bounce_bulbs.append({"pos": clamp_to_arena(c + Vector2(sx, 20.0)), "bloom": 0.5, "vault_cd": 0.0})


func _enter_phase(next_phase: int) -> void:
	# Compat hook for tests/luxel/boss_qa_capture.gd
	phase = clampi(next_phase, 1, 3)
	if not phases_reached.has(phase):
		phases_reached.append(phase)
	_on_phase_enter(phase)


func _on_phase_enter(new_phase: int) -> void:
	_roaring = true
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# P2 Arena Mutation: Growth Ring pit trenches + briar cover pillars
		_carve_safe_tile_near(c + Vector2(-118.0, -64.0), "pit")
		_carve_safe_tile_near(c + Vector2(118.0, -64.0), "pit")
		_carve_safe_tile_near(c + Vector2(-118.0, 64.0), "pit")
		_carve_safe_tile_near(c + Vector2(118.0, 64.0), "pit")
		props.spawn_pillar(clamp_to_arena(c + Vector2(-56.0, -24.0)), 4.5, "matron_briar_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(56.0, -24.0)), 4.5, "matron_briar_e")
		stage.darkness_pulse(0.66, 1.05)
		stage.shake(0.24)
		stage.play_sfx("briar_matron_phase", pos)
	elif new_phase == 3:
		# P3 Arena Mutation: canopy darkness + Heartwood Sun-Bloom at center!
		_web_shield = WEB_SHIELD_MAX * 0.75
		_shield_down_t = 0.0
		_sun_bloom_pos = c
		_carve_safe_tile_near(c + Vector2(-104.0, 68.0), "pit")
		_carve_safe_tile_near(c + Vector2(104.0, 68.0), "pit")
		stage.darkness_pulse(0.78, 1.25)
		stage.shake(0.28)
		stage.play_sfx("briar_matron_phase", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if boss_state != BossState.PHASE_SHIFT:
		_roaring = false
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	_ambush_ghost_t = maxf(0.0, _ambush_ghost_t - dt)
	_snare_tick_cd = maxf(0.0, _snare_tick_cd - dt)
	_sun_bloom_lit_t = maxf(0.0, _sun_bloom_lit_t - dt)

	if _shield_down_t > 0.0:
		_shield_down_t = maxf(0.0, _shield_down_t - dt)
		if _shield_down_t <= 0.0:
			_web_shield = WEB_SHIELD_MAX * 0.75
	elif _web_shield < WEB_SHIELD_MAX and not _is_matron_in_light():
		# Hiding in darkness regens silk-thorn carapace (Bible §4.7!)
		_web_shield = minf(WEB_SHIELD_MAX, _web_shield + WEB_REGEN_RATE * dt)

	# P3 Heartwood Sun-Bloom activates when lantern/Wick lights the center
	if phase >= 3:
		var lan_p: Vector2 = _get_lantern_pos()
		if lan_p.distance_to(_sun_bloom_pos) <= 58.0 or _get_wick_pos().distance_to(_sun_bloom_pos) <= 32.0:
			_sun_bloom_lit_t = maxf(_sun_bloom_lit_t, 2.2)

	_step_web_lanes(dt)
	_step_bounce_bulbs(dt)


func _step_web_lanes(dt: float) -> void:
	var wp: Vector2 = _get_wick_pos()
	var snared: bool = false
	for i: int in range(web_lanes.size() - 1, -1, -1):
		var lane: Dictionary = web_lanes[i]
		var ttl: float = float(lane["ttl"]) - dt
		if ttl <= 0.0:
			web_lanes.remove_at(i)
			continue
		lane["ttl"] = ttl
		if _has_player() and not snared:
			var lo: Vector2 = lane["origin"] as Vector2
			var ld: Vector2 = lane["dir"] as Vector2
			var llen: float = float(lane["length"])
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(wp, lo, lo + ld * llen)
			if closest.distance_to(wp) <= SNARE_HALF_W:
				snared = true
				if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil"):
					var pull_v: Vector2 = (closest - wp).normalized() if closest.distance_to(wp) > 0.5 else -ld
					var probe: Vector2 = wp + pull_v * 14.0
					if world_ctx == null or not world_ctx.has_method("is_lethal_void_at") or not bool(world_ctx.call("is_lethal_void_at", probe)):
						Lx.player.call("apply_recoil", pull_v * 24.0 * dt)


func _step_bounce_bulbs(dt: float) -> void:
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var lan_p: Vector2 = _get_lantern_pos()
	for b_d: Dictionary in _bounce_bulbs:
		b_d["vault_cd"] = maxf(0.0, float(b_d["vault_cd"]) - dt)
		var bp: Vector2 = b_d["pos"] as Vector2
		if lan_p.distance_to(bp) <= 68.0:
			b_d["bloom"] = minf(1.0, float(b_d["bloom"]) + dt * 0.9)
		else:
			b_d["bloom"] = maxf(0.40, float(b_d["bloom"]) - dt * 0.12)
		if wick != null and not wick.dead and float(b_d["bloom"]) >= 0.70 and float(b_d["vault_cd"]) <= 0.0:
			if wick.global_position.distance_to(bp) <= 16.0 and boss_state == BossState.COMMIT:
				b_d["vault_cd"] = 1.25
				var away: Vector2 = (bp - pos).normalized() if bp.distance_to(pos) > 1.0 else Vector2.UP
				if wick.has_method("push_external"):
					wick.push_external(away * 140.0, "light_plant_bounce")
				stage.light_burst(bp, 48.0, 1.15, 0.25)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var is_beam: bool = src == LxHit.SOURCE_BEAM or bool(h["pierce"]) or bool(h["cracks_armour"])
	var heavy: bool = is_beam or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE]

	# Beam hitting Briar Matron while Silk Web Snares exist triggers 3-lane chain-burn stagger!
	if is_beam and not web_lanes.is_empty():
		_trigger_web_chain_burn()
		return dmg * 1.35

	var sun_bonus: float = 1.25 if (phase >= 3 and _sun_bloom_lit_t > 0.0) else 1.0
	if boss_state == BossState.STAGGER:
		return dmg * (1.85 if heavy else 1.45) * sun_bonus
	if is_punishable():
		return dmg * (1.75 if heavy else 1.0) * sun_bonus
	if heavy:
		if _web_shield > 0.0:
			_wear_web_shield(dmg * 1.4)
		return dmg * 1.65 * sun_bonus

	# Outside punish windows: woven silk-thorn carapace reduces plain bolt spam + clear armour glint!
	if _web_shield > 0.0:
		_wear_web_shield(dmg * 0.55)
	clank_t = 0.12
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("bramble_thorn_block", pos)
	return dmg * (0.30 if _web_shield > 0.0 else 0.42) * sun_bonus


func _wear_web_shield(amt: float) -> void:
	_web_shield = maxf(0.0, _web_shield - amt)
	if _web_shield <= 0.001 and _shield_down_t <= 0.0:
		_shield_down_t = 5.5
		add_stagger(stagger_threshold * 0.65)
		stage.play_sfx("bramble_guard_break", pos)


func _trigger_web_chain_burn() -> void:
	for lane: Dictionary in web_lanes:
		var lo: Vector2 = lane["origin"] as Vector2
		var ld: Vector2 = lane["dir"] as Vector2
		var llen: float = float(lane["length"])
		stage.light_burst(lo + ld * (llen * 0.5), 58.0, 1.35, 0.34)
	web_lanes.clear()
	_web_shield = 0.0
	_shield_down_t = 5.5
	add_stagger(stagger_threshold)
	stage.shake(0.22)
	stage.play_sfx("briar_web_burn", pos)


func _on_death_start() -> void:
	web_lanes.clear()
	stage.revert_tiles(world_ctx)
	stage.play_sfx("briar_matron_phase", pos)


func _is_matron_in_light() -> bool:
	if _sun_bloom_lit_t > 0.0:
		return true
	return _get_lantern_pos().distance_to(pos) <= 84.0


func _build_volley_targets(tgt: Vector2) -> Array[Vector2]:
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
	var p: Vector2 = clamp_to_arena(world_pt)
	var tx: int = int(floorf(p.x / 16.0))
	var ty: int = int(floorf(p.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if str(world_ctx.call("tile_at", cp)) == "ground" and cp.distance_to(home) > 32.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), tile_kind)


func _body_color() -> Color:
	return (PAL["wine"] if phase >= 3 else (PAL["dusk"] if phase >= 2 else PAL["pine"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = is_flash_reduced()
	# Bounce bulbs
	for b_d: Dictionary in _bounce_bulbs:
		var bp: Vector2 = ((b_d["pos"] as Vector2) - pos).round()
		var bl: float = float(b_d["bloom"])
		var r_bulb: float = 7.0 + bl * 3.5
		draw_arc(bp, r_bulb, 0.0, TAU, 16, PAL["void"] as Color, 3.0)
		draw_circle(bp, 6.0 + bl * 2.5, Color(PAL["pine"] as Color, 0.72))
		draw_arc(bp, r_bulb, 0.0, TAU, 16, (PAL["lime"] if bl >= 0.70 else PAL["jade"]) as Color, 1.0)
		draw_circle(bp, 3.2, PAL["void"] as Color)
		draw_circle(bp, 2.5, (PAL["gold"] if bl >= 0.70 else PAL["lime"]) as Color)

	# P3 Heartwood Sun-Bloom bulb at center
	if phase >= 3:
		var sb: Vector2 = (_sun_bloom_pos - pos).round()
		var lit: bool = _sun_bloom_lit_t > 0.0
		var sb_r: float = 18.0 if lit else 11.0
		var petal_spin: float = anim_t * (0.45 if fred else (1.35 if lit else 0.75))
		var petal_r: float = (11.5 if lit else 7.2) + (0.0 if fred else sin(anim_t * (5.0 if lit else 2.8)) * 0.8)
		draw_arc(sb, sb_r, 0.0, TAU, 20, PAL["void"] as Color, 3.0)
		draw_arc(sb, sb_r, 0.0, TAU, 20, (PAL["gold"] if lit else PAL["dusk"]) as Color, 2.0 if lit else 1.0)
		for pi: int in range(6):
			var pa: float = petal_spin + float(pi) * (TAU / 6.0)
			var pd: Vector2 = Vector2.from_angle(pa)
			var p_in: Vector2 = (sb + pd * 3.5).round()
			var p_out: Vector2 = (sb + pd * petal_r).round()
			draw_line(p_in, p_out, PAL["void"] as Color, 3.0 if lit else 2.0)
			draw_line(p_in, p_out, (PAL["gold"] if lit else PAL["apricot"]) as Color, 2.0 if lit else 1.0)
			draw_circle(p_out, 1.9 if lit else 1.4, PAL["void"] as Color)
			draw_circle(p_out, 1.2 if lit else 0.9, (PAL["cream"] if lit else PAL["gold"]) as Color)
		draw_circle(sb, 5.5 if lit else 4.0, PAL["void"] as Color)
		draw_circle(sb, 4.5 if lit else 3.0, (PAL["cream"] if lit else PAL["apricot"]) as Color)

	# Active 3-Lane Silk Web Snares
	for lane: Dictionary in web_lanes:
		var lo: Vector2 = ((lane["origin"] as Vector2) - pos + off).round()
		var ld: Vector2 = lane["dir"] as Vector2
		var llen: float = float(lane["length"])
		var lp := Vector2(-ld.y, ld.x)
		var le: Vector2 = (lo + ld * llen).round()
		var side_off: Vector2 = lp * (SNARE_HALF_W * 0.6)
		var s0_a: Vector2 = (lo + side_off).round()
		var s0_b: Vector2 = (le + side_off).round()
		var s1_a: Vector2 = (lo - side_off).round()
		var s1_b: Vector2 = (le - side_off).round()
		draw_line(lo, le, PAL["void"] as Color, 4.0)
		draw_line(s0_a, s0_b, PAL["void"] as Color, 2.0)
		draw_line(s1_a, s1_b, PAL["void"] as Color, 2.0)
		draw_line(lo, le, PAL["stone"] as Color, 2.0)
		draw_line(s0_a, s0_b, PAL["ice"] as Color, 1.0)
		draw_line(s1_a, s1_b, PAL["ice"] as Color, 1.0)
		for wi: int in range(1, 6):
			var mid: Vector2 = lo.lerp(le, float(wi) / 6.0)
			var ra: Vector2 = (mid - lp * (SNARE_HALF_W * 0.65)).round()
			var rb: Vector2 = (mid + lp * (SNARE_HALF_W * 0.65)).round()
			draw_line(ra, rb, PAL["void"] as Color, 2.0)
			draw_line(ra, rb, PAL["cream"] as Color, 1.0)

	# Scuttle ambush silk afterimage
	if _ambush_ghost_t > 0.0:
		var gp: Vector2 = (_ambush_ghost_pos - pos + off).round()
		draw_line(gp, c, PAL["ice"] as Color, 1.0)
		draw_arc(gp, body_radius, 0.0, TAU, 12, PAL["stone"] as Color, 1.0)

	# Silk-thorn front web shield + armour glint
	var fwd: Vector2 = Vector2.from_angle(facing)
	var side := Vector2(-fwd.y, fwd.x)
	if _web_shield > 0.0 and boss_state != BossState.DEATH:
		var w_mid: Vector2 = off + fwd * (body_radius + 4.5)
		var w_col: Color = (PAL["cream"] if clank_t > 0.0 else PAL["ice"]) as Color
		draw_line((w_mid - side * 10.0).round(), (w_mid + side * 10.0).round(), PAL["stone"] as Color, 2.0)
		draw_line((w_mid - side * 8.0 - fwd * 2.5).round(), (w_mid + side * 8.0 + fwd * 2.5).round(), w_col, 1.0)
		draw_line((w_mid + side * 8.0 - fwd * 2.5).round(), (w_mid - side * 8.0 + fwd * 2.5).round(), w_col, 1.0)
	if clank_t > 0.0:
		draw_arc(c, body_radius + 5.0, facing - 1.15, facing + 1.15, 16, PAL["cream"] as Color, 2.0)
		draw_arc(c, body_radius + 7.0, facing - 0.85, facing + 0.85, 12, PAL["ice"] as Color, 1.0)
	elif is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 20, PAL["gold"] as Color, 2.0)
