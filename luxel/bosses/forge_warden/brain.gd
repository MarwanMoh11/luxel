class_name LxForgeWardenBoss
extends LxBossBase
## Ashen Kiln Mini-Boss #1 (Island 6, `kiln_r6`): Forge Warden (Bible §4.6).
## 2 phases on LxBossBase. Heavy furnace slag armour chips plain bolts outside punish windows
## with a molten-gold armour glint; Sunflare / Lance (`cracks_armour`) shatters his armour for
## 1.45x damage + heavy stagger!
## Preserves B6 upgrades: Forge Quake shockwave, P2 Molten Line-Fissure triggering room `slag_pourer`s
## & splashing molten slag boulders (cool with Blue bolts to block his follow-up fissure and reflect
## sparks back for a 1.1s mini-stagger!), plus P2 lava pit rim cracks & cooled basalt anvil pillars!

const FORGE_ARMOUR_MAX: float = 4.0
const ARMOUR_REFORM_DUR: float = 8.0
const FORGE_RING_START_R: float = 10.0
const FORGE_RING_MAX_R: float = 60.0
const FORGE_RING_BAND: float = 10.0
const FISSURE_RANGE: float = 112.0
const FISSURE_HALF_W: float = 10.0
const MAX_SLAG_BOULDERS: int = 2

# Compat fields referenced by miniboss_synergy.gd & failure_teaching_fx.gd
var armour_max: float = FORGE_ARMOUR_MAX
var armour_hp: float = FORGE_ARMOUR_MAX
var armour_intact: bool = true

var _armour_broken_t: float = 0.0
var _stomp_progress: float = 0.0
var _stomp_hit: bool = false
var _fissure_dir: Vector2 = Vector2.RIGHT
var _fissure_progress: float = 0.0
var _fissure_hit: bool = false
var _fissure_block_dist: float = FISSURE_RANGE
var _fissure_reflected: bool = false
var _reflect_fx_t: float = 0.0
var _reflect_fx_pos: Vector2 = Vector2.ZERO
var _rush_dir: Vector2 = Vector2.RIGHT
var _slag_boulders: Array[Dictionary] = []
var _clank_sfx_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "forge_warden"
	boss_id = "forge_warden"
	boss_name_key = "MINIBOSS_6"
	island_id = 6
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island6_boss_p1"
	music_p2_cue = "island6_boss_p2"
	max_hp = 78.0
	hp = 78.0
	body_radius = 9.0
	move_speed = 34.0
	stagger_threshold = 13.5
	stagger_duration = 1.60
	punish_dmg_mult = 1.30
	post_recover_cd = 0.28
	shard_drop = 22
	intro_duration = 0.60
	phase_shift_duration = 0.65
	death_duration = 2.0


func _configure_boss(_spec: Dictionary) -> void:
	if world_ctx != null and str(world_ctx.get("current_region_id")) == "kiln_r6":
		arena_rect = Rect2(224.0, 96.0, 176.0, 64.0)
	configure_phases([0.50])

	# Attack 1: Forge Quake Slam — expanding molten shockwave ring + cinder gap ring + slag splash
	register_attack("forge_quake_slam", {
		"weight": 1.25, "tell": 0.60, "commit": 0.34, "recover": 1.25, "cooldown": 1.50,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_stomp_progress = 0.0
			_stomp_hit = false
			ground.warn_ring(pos, FORGE_RING_MAX_R, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_ring(tgt, 24.0, last_tell_duration + 0.06, 0.5, "apricot", "coral")
			stage.play_sfx("golem_stomp_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_stomp_progress = 0.0
			_stomp_hit = false
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 12 if phase >= 2 else 10, 120.0, gap_a, 0.85, {"color": "coral", "source": "forge_quake", "damage": 0.5})
			_splash_slag_boulder(pos + Vector2.from_angle(gap_a + 0.75) * 48.0)
			_boss_impact(0.20, 88.0, 90.0)
			stage.play_sfx("golem_stomp_shockwave", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			_step_quake_commit(el, 0.34),
	})

	# Attack 2: Anvil Cinder Barrage — targeted molten drops across Wick & corners + forge bolt lane
	register_attack("anvil_cinder_barrage", {
		"weight": 1.20, "tell": 0.56, "commit": 0.32, "recover": 1.10, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_rush_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _rush_dir.angle()
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration, 24.0, 0.5, "coral", "gold")
			ground.warn_lane(pos, pos + _rush_dir * 58.0, 8.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("golem_stomp_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_lane(pos, _rush_dir, 4 if phase >= 2 else 3, 148.0, 0.08, {"color": "gold", "source": "anvil_cinder", "damage": 0.5})
			stage.shake(0.16)
			stage.play_sfx("golem_stomp_shockwave", pos),
	})

	# Attack 3: Furnace Hammer Rush — advancing hammer lunge + molten spark fan
	register_attack("furnace_hammer_rush", {
		"weight": 1.15, "tell": 0.54, "commit": 0.36, "recover": 1.15, "cooldown": 1.50,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_rush_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _rush_dir.angle()
			ground.warn_lane(pos, pos + _rush_dir * 60.0, 10.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("warden_swing", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _rush_dir, 5 if phase >= 2 else 3, 0.72, 138.0, {"color": "apricot", "source": "hammer_sparks", "damage": 0.5})
			stage.shake(0.16)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_rush_dir * 104.0 * dt, false)
			check_contact_damage(body_radius + 11.0, _rush_dir, 0.5, "hammer_rush"),
	})

	# Attack 4 (P2): Molten Line-Fissure — blazing lava lane (cooled slag boulder blocks & reflects for stagger!)
	register_attack("molten_line_fissure", {
		"phases": [2], "weight": 2.00, "tell": 0.56, "commit": 0.38, "recover": 1.35, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_fissure_progress = 0.0
			_fissure_hit = false
			_fissure_reflected = false
			_fissure_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _fissure_dir.angle()
			ground.warn_lane(pos, pos + _fissure_dir * 64.0, FISSURE_HALF_W, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("golem_stomp_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_fissure_progress = 0.0
			_fissure_hit = false
			_fissure_reflected = false
			_fissure_dir = Vector2.from_angle(facing)
			_fissure_block_dist = _compute_fissure_block_dist(_fissure_dir)
			_boss_impact(0.22, 98.0, 102.0)
			stage.play_sfx("golem_stomp_shockwave", pos)
			_trigger_room_slag_pourers()
			_splash_slag_boulder(pos + _fissure_dir.rotated(0.55) * 52.0)
			patterns.emit_fan(pos, _fissure_dir, 3, 0.42, 146.0, {"color": "coral", "source": "fissure_cinder", "damage": 0.5}),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			_step_fissure_commit(el, 0.38),
	})


func _on_reset_encounter() -> void:
	armour_max = FORGE_ARMOUR_MAX
	armour_hp = FORGE_ARMOUR_MAX
	armour_intact = true
	_armour_broken_t = 0.0
	_stomp_progress = 0.0
	_stomp_hit = false
	_fissure_progress = 0.0
	_fissure_hit = false
	_fissure_block_dist = FISSURE_RANGE
	_fissure_reflected = false
	_reflect_fx_t = 0.0
	_slag_boulders.clear()
	_clank_sfx_cd = 0.0


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		armour_intact = true
		armour_hp = maxf(armour_hp, 3.0)
		_armour_broken_t = 0.0
		_trigger_room_slag_pourers()
		_splash_slag_boulder(pos + Vector2.from_angle(facing + 0.65) * 48.0)
		# P2 Arena Mutation: crack outer basalt rim into lava pockets + drop basalt anvil cover pillars!
		var c: Vector2 = arena_rect.get_center()
		_carve_safe_pit_near(c + Vector2(-72.0, -56.0))
		_carve_safe_pit_near(c + Vector2(56.0, -56.0))
		props.spawn_pillar(clamp_to_arena(c + Vector2(-72.0, 20.0)), 4.5, "forge_anvil_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(72.0, -20.0)), 4.5, "forge_anvil_e")
		stage.darkness_pulse(0.60, 0.95)
		_boss_impact(0.28, 98.0, 96.0)
		stage.play_sfx("forge_warden_phase2", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	_reflect_fx_t = maxf(0.0, _reflect_fx_t - dt)
	if not armour_intact:
		_armour_broken_t = maxf(0.0, _armour_broken_t - dt)
		if _armour_broken_t <= 0.0:
			armour_intact = true
			armour_hp = armour_max * 0.75
			stage.play_sfx("golem_armour_clank", pos)
	_tick_slag_boulders(dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var cracks: bool = bool(h["cracks_armour"]) or src == LxHit.SOURCE_SUNFLARE
	var heavy: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_PRISM] or bool(h["pierce"])

	# Sunflare / Lance cracks heavy slag armour immediately for 1.45x + stagger!
	if cracks and armour_intact:
		_crack_armour()
		add_stagger(stagger_threshold * 0.75)
		return dmg * 1.45

	if boss_state == BossState.STAGGER:
		return dmg * 1.50
	if is_punishable():
		if (heavy or cracks) and armour_intact:
			_wear_armour(float(h["shield_wear"]))
		return dmg * (1.20 if (not armour_intact or heavy or cracks) else 1.0)
	if heavy or cracks:
		if armour_intact:
			_wear_armour(float(h["shield_wear"]))
		return dmg * 1.15

	# Heavy forge slag armour outside punish windows: reduced bolt chip + clear molten-gold glint!
	clank_t = 0.12
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("golem_armour_clank", pos)
	if armour_intact:
		_wear_armour(0.12)
	return dmg * (0.24 if armour_intact else 0.34)


func _wear_armour(amt: float) -> void:
	armour_hp = maxf(0.0, armour_hp - maxf(0.0, amt))
	if armour_hp <= 0.001:
		_crack_armour()


func _crack_armour() -> void:
	armour_hp = 0.0
	armour_intact = false
	_armour_broken_t = ARMOUR_REFORM_DUR
	stage.play_sfx("golem_armour_crack", pos)
	_boss_impact(0.20, 82.0, 84.0)


func _step_quake_commit(el: float, dur: float) -> void:
	_stomp_progress = clampf(el / maxf(dur, 0.05), 0.0, 1.0)
	var ring_r: float = lerpf(FORGE_RING_START_R, FORGE_RING_MAX_R, _stomp_progress)
	if not _stomp_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= FORGE_RING_BAND:
			_stomp_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.1 else Vector2.from_angle(facing)
			emit_boss_damage(push, 0.5, "shockwave", pos, true)
	if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= ring_r and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())


func _step_fissure_commit(el: float, dur: float) -> void:
	_fissure_progress = clampf(el / maxf(dur, 0.05), 0.0, 1.0)
	var raw_len: float = lerpf(12.0, FISSURE_RANGE, _fissure_progress)
	var cur_len: float = minf(raw_len, _fissure_block_dist)
	var fend: Vector2 = pos + _fissure_dir * cur_len
	# Cooled slag boulder blocks follow-up fissure & reflects sparks for stagger!
	if not _fissure_reflected and _fissure_block_dist < FISSURE_RANGE - 1.0 and raw_len >= _fissure_block_dist:
		_fissure_reflected = true
		_reflect_fx_t = 0.38
		_reflect_fx_pos = pos + _fissure_dir * _fissure_block_dist
		stage.play_sfx("magma_crack", _reflect_fx_pos)
		stage.play_sfx("shield_shatter", pos)
		stagger_immunity_t = 0.0
		add_stagger(stagger_threshold)
		return
	if not _fissure_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, pos, fend).distance_to(wp) <= FISSURE_HALF_W:
			_fissure_hit = true
			emit_boss_damage(_fissure_dir, 0.5, "molten_fissure", pos, true)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if Geometry2D.get_closest_point_to_segment(lp, pos, fend).distance_to(lp) <= FISSURE_HALF_W + 2.0 and Lx.events != null:
			Lx.events.lantern_struck.emit(lp)


func _trigger_room_slag_pourers() -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return
	for it_v: Variant in (world_ctx.call("get_interactables") as Array):
		if it_v is LxInteractable and (it_v as LxInteractable).kind == "slag_pourer" and (it_v as Object).has_method("trigger_pour"):
			(it_v as Object).call("trigger_pour")


func _splash_slag_boulder(at_p: Vector2) -> void:
	var p: Vector2 = clamp_to_arena(at_p)
	while _slag_boulders.size() >= MAX_SLAG_BOULDERS:
		_slag_boulders.pop_front()
	_slag_boulders.append({"pos": p, "cooled": false, "ttl": 16.0})


func _tick_slag_boulders(dt: float) -> void:
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for i: int in range(_slag_boulders.size() - 1, -1, -1):
		var sb: Dictionary = _slag_boulders[i]
		sb["ttl"] = float(sb["ttl"]) - dt
		if float(sb["ttl"]) <= 0.0:
			_slag_boulders.remove_at(i)
			continue
		if not bool(sb["cooled"]) and wick_node != null:
			var bp_s: Vector2 = sb["pos"] as Vector2
			for bi: int in range(wick_node.bolts.size() - 1, -1, -1):
				var bv: Variant = wick_node.bolts[bi]
				if bv is Object and (bv.get("pos") as Vector2).distance_to(bp_s) <= 10.0:
					if str(bv.get("light_color")).to_lower() == LxHit.COLOR_BLUE:
						sb["cooled"] = true
						sb["ttl"] = 14.0
						stage.play_sfx("magma_crack", bp_s)
						wick_node.bolts.remove_at(bi)
						break


func _compute_fissure_block_dist(dir: Vector2) -> float:
	var best: float = FISSURE_RANGE
	var candidates: Array[Vector2] = []
	for sb: Dictionary in _slag_boulders:
		if bool(sb["cooled"]):
			candidates.append(sb["pos"] as Vector2)
	if world_ctx != null and is_instance_valid(world_ctx):
		if world_ctx.has_method("get_interactables"):
			for it_v: Variant in (world_ctx.call("get_interactables") as Array):
				if it_v is LxInteractable and (it_v as LxInteractable).kind == "push_block" and bool((it_v as Object).get("cooled")):
					candidates.append((it_v as LxInteractable).pos)
		if world_ctx.has_method("get_enemies"):
			for ev: Variant in (world_ctx.call("get_enemies") as Array):
				if ev is LxEnemyBrain and ev != self and (ev as LxEnemyBrain).is_alive() and (ev as Object).has_method("is_frozen_block") and bool((ev as Object).call("is_frozen_block")):
					candidates.append((ev as LxEnemyBrain).pos)
	for cp: Vector2 in candidates:
		var rel: Vector2 = cp - pos
		var proj: float = rel.dot(dir)
		if proj > 14.0 and proj < best and (rel - dir * proj).length() <= FISSURE_HALF_W + 4.0:
			best = proj
	return best


func _carve_safe_pit_near(world_pt: Vector2) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return
	var tx: int = int(floorf(world_pt.x / 16.0))
	var ty: int = int(floorf(world_pt.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if cp.x > 136.0 and str(world_ctx.call("tile_at", cp)) == "ground" and cp.distance_to(home) > 44.0 and cp.distance_to(_get_wick_pos()) > 28.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), "pit")


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
	_slag_boulders.clear()
	stage.revert_tiles(world_ctx)
	stage.play_sfx("forge_warden_phase2", pos)


func _body_color() -> Color:
	if armour_intact:
		return (PAL["mauve"] if phase >= 2 else PAL["stone"]) as Color
	return (PAL["apricot"] if phase >= 2 else PAL["coral"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	if armour_intact:
		LxDamageFx.draw_armour_plates(self, off, body_radius + 3.0, 1.8, armour_hp, armour_max)
	if boss_state == BossState.COMMIT and active_attack_id == "forge_quake_slam":
		var ring_r: float = lerpf(FORGE_RING_START_R, FORGE_RING_MAX_R, _stomp_progress)
		draw_arc(c, ring_r + 2.6, 0.0, TAU, 36, PAL["wine"] as Color, 2.4)
		draw_arc(c, ring_r, 0.0, TAU, 36, PAL["coral"] as Color, 3.6)
		draw_arc(c, maxf(2.0, ring_r - 2.0), 0.0, TAU, 28, PAL["apricot"] as Color, 1.8)
		draw_arc(c, maxf(2.0, ring_r - 3.6), 0.0, TAU, 24, PAL["gold"] as Color, 1.1)
	elif boss_state == BossState.COMMIT and active_attack_id == "molten_line_fissure":
		var cur_len: float = minf(lerpf(12.0, FISSURE_RANGE, _fissure_progress), _fissure_block_dist)
		var fend2: Vector2 = (c + _fissure_dir * cur_len).round()
		draw_line(c, fend2, PAL["wine"] as Color, 10.0)
		draw_line(c, fend2, PAL["coral"] as Color, 6.8)
		draw_line(c, fend2, PAL["apricot"] as Color, 4.0)
		draw_line(c, fend2, PAL["gold"] as Color, 2.2)
		draw_line(c, fend2, PAL["cream"] as Color, 1.0)
	# Draw splashed molten/cooled slag boulders & reflected spark arc!
	for sb: Dictionary in _slag_boulders:
		var sp: Vector2 = ((sb["pos"] as Vector2) - pos + off).round()
		var cool: bool = bool(sb["cooled"])
		draw_circle(sp, 8.5, PAL["night"] as Color)
		draw_circle(sp, 7.0, (PAL["mauve"] if cool else PAL["coral"]) as Color)
		draw_arc(sp, 7.5, 0.0, TAU, 14, (PAL["ice"] if cool else PAL["gold"]) as Color, 1.3)
	if _reflect_fx_t > 0.0:
		var rp_l: Vector2 = (_reflect_fx_pos - pos + off).round()
		draw_line(rp_l, c, PAL["ice"] as Color, 2.4)
		draw_line(rp_l, c, PAL["cream"] as Color, 1.0)
	# Heavy slag armour glint outside punish windows vs golden punish halo
	if clank_t > 0.0:
		draw_arc(c, body_radius + 5.5, facing - 1.15, facing + 1.15, 16, PAL["cream"] as Color, 2.2)
		draw_arc(c, body_radius + 7.5, facing - 0.85, facing + 0.85, 12, PAL["gold"] as Color, 1.3)
	elif is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 4.5, 0.0, TAU, 20, PAL["gold"] as Color, 1.6)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.15, 1.48, 0.42)
