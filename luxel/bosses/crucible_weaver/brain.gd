class_name LxCrucibleWeaverBoss
extends LxBossBase
## Island 6 Great Kiln Mini-Boss #2: THE CRUCIBLE WEAVER (`kiln_r15`).
## 6-legged molten glass-blowing spider-automaton spinning LIVE rotatable mirrors (`blue_transformer`)
## onto the arena floor! Bank Blue light off her own spun mirrors to freeze her liquid-glass hull brittle
## for the comedy overturned-teacup stagger (`2.0s` + 1.55x shatter damage)!
## P2 (<=50%): Spins 2 mirrors at once + Furnace Loom Sweeping Molten Ribbon + corner lava vats!

const MAX_SPUN_MIRRORS: int = 3
const BRITTLE_DURATION: float = 2.0

var _aim_dir: Vector2 = Vector2.LEFT
var _sweep_base_ang: float = 0.0
var _sweep_hit: bool = false
var _brittle_t: float = 0.0
var _spun_mirrors: Array[Dictionary] = []
var _spawned_interactable_ids: Array[String] = []
var _mirror_seq: int = 0


func _init() -> void:
	super._init()
	kind = "crucible_weaver"
	boss_id = "crucible_weaver"
	boss_name_key = "ISL6_BOSS_WEAVER"
	island_id = 6
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island6_boss_p1"
	music_p2_cue = "island6_boss_p2"
	max_hp = 68.0
	hp = 68.0
	body_radius = 11.5
	move_speed = 44.0
	stagger_threshold = 13.0
	stagger_duration = BRITTLE_DURATION
	post_recover_cd = 0.28
	intro_duration = 0.55
	death_duration = 1.8
	shard_drop = 26


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.58])

	# Attack 1 (P1+P2): Spin-Blow Mirror (inflates glowing glass bubble -> drops live rotatable mirror + shard fan!)
	register_attack("spin_blow_mirror", {
		"weight": 1.35, "tell": 0.58, "commit": 0.35, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			var m_pos: Vector2 = _pick_mirror_spot(tgt)
			set_meta("_next_mirror_pos", m_pos)
			ground.warn_summon(m_pos, 16.0, last_tell_duration, "sky")
			stage.play_sfx("weaver_spin_mirror", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var m_pos: Vector2 = get_meta("_next_mirror_pos", _pick_mirror_spot(tgt)) as Vector2
			_spin_live_mirror(m_pos)
			if phase >= 2:
				_spin_live_mirror(_pick_mirror_spot(arena_rect.get_center() * 2.0 - m_pos))
			patterns.emit_fan(pos, _aim_dir, 4 if phase >= 2 else 3, 0.85, 118.0, {"color": "apricot", "source": "weaver_glass_shard"})
			stage.play_sfx("mirror_ping", m_pos)
			stage.shake(0.14),
	})

	# Attack 2 (P1+P2): Molten Glass Thread (3 sticky burning floor lines + airborne-safe linger!)
	register_attack("molten_glass_thread", {
		"weight": 1.25, "tell": 0.52, "commit": 0.32, "recover": 1.15, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			var base_a: float = _aim_dir.angle()
			set_meta("_thread_ang", base_a)
			for deg: float in [-26.0, 0.0, 26.0]:
				var d: Vector2 = Vector2.from_angle(base_a + deg_to_rad(deg))
				ground.warn_lane(pos, clamp_to_arena(pos + d * 136.0), 9.0, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("furnace_draw", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var base_a: float = float(get_meta("_thread_ang", 0.0))
			for deg: float in [-26.0, 0.0, 26.0]:
				var d: Vector2 = Vector2.from_angle(base_a + deg_to_rad(deg))
				var mid: Vector2 = clamp_to_arena(pos + d * 64.0)
				ground.add_hazard_circle(mid, 11.0, 1.35, 1.0, "coral", true)
			patterns.emit_fan(pos, Vector2.from_angle(base_a), 3, 0.90, 116.0, {"color": "gold", "source": "weaver_thread"})
			stage.play_sfx("magma_crack", pos)
			stage.shake(0.14),
	})

	# Attack 3 (P1+P2): Crucible Droplet Volley (pressures Wick + nearest arena corners!)
	register_attack("crucible_droplets", {
		"weight": 1.15, "tell": 0.50, "commit": 0.30, "recover": 1.10, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_droplet_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "coral", "gold")
			stage.play_sfx("weaver_spin_mirror", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else 0.0
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 108.0, gap_a, 0.86, {"color": "apricot", "source": "weaver_droplet"})
			stage.play_sfx("prism_bounce", pos),
	})

	# Attack 4 (P2): Furnace Loom Sweep (90 deg sweeping molten glass beam + twin mirror flash!)
	register_attack("furnace_loom_sweep", {
		"phases": [2],
		"weight": 2.35, "tell": 0.58, "commit": 0.45, "recover": 1.25, "cooldown": 1.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_sweep_base_ang = ((tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else facing) - 0.78
			_sweep_hit = false
			ground.warn_sector(pos, _sweep_base_ang, _sweep_base_ang + 1.56, 128.0, last_tell_duration, 0.0, "coral", "cream")
			stage.play_sfx("miniboss_forge_roar", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("beam_fire", pos)
			stage.shake(0.18),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			var u: float = clampf(el / 0.45, 0.0, 1.0)
			var ang: float = _sweep_base_ang + u * 1.56
			var bdir: Vector2 = Vector2.from_angle(ang)
			var bend: Vector2 = pos + bdir * 128.0
			if not _sweep_hit and _has_player():
				var wp: Vector2 = _get_wick_pos()
				if Geometry2D.get_closest_point_to_segment(wp, pos, bend).distance_to(wp) <= 12.0:
					_sweep_hit = true
					emit_boss_damage(bdir, 1.0, "weaver_loom_sweep", pos, true),
	})


func _on_reset_encounter() -> void:
	_brittle_t = 0.0
	_sweep_hit = false
	_clear_spun_mirrors()
	# Seed 1 starter rotatable mirror on the arena floor right away!
	var c: Vector2 = arena_rect.get_center()
	_spin_live_mirror(clamp_to_arena(c + Vector2(54.0, -34.0)))


func _spin_live_mirror(at_p: Vector2) -> void:
	# Cap at MAX_SPUN_MIRRORS (recycle oldest cleanly!)
	while _spun_mirrors.size() >= MAX_SPUN_MIRRORS:
		var old_m: Dictionary = _spun_mirrors.pop_front() as Dictionary
		var oid: String = str(old_m.get("interactable_id", ""))
		if not oid.is_empty() and world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("remove_interactable"):
			world_ctx.call("remove_interactable", oid)
		_spawned_interactable_ids.erase(oid)

	_mirror_seq += 1
	var iid: String = ""
	# In a real LxRegionLoader room, spawn an actual rotatable blue_transformer interactable!
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("spawn_interactable"):
		iid = "weaver_mirror_%d" % _mirror_seq
		var n_vec: Vector2 = (pos - at_p).normalized() if pos.distance_to(at_p) > 0.1 else Vector2.LEFT
		var iv: Variant = world_ctx.call("spawn_interactable", {
			"id": iid, "kind": "blue_transformer", "pos": [at_p.x, at_p.y],
			"props": {"rotatable": true, "movable": false, "normal": [n_vec.x, n_vec.y], "persist_pos": false},
		})
		if iv == null:
			iid = ""
		else:
			_spawned_interactable_ids.append(iid)

	_spun_mirrors.append({
		"pos": at_p, "angle": (pos - at_p).angle(), "flash_t": 0.25, "cd": 0.0, "interactable_id": iid,
	})
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_ring(at_p, 2.0, 14.0, 0.22, PAL["sky"] as Color, 1.3)


func _clear_spun_mirrors() -> void:
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("remove_interactable"):
		for iid: String in _spawned_interactable_ids:
			world_ctx.call("remove_interactable", iid)
	_spawned_interactable_ids.clear()
	_spun_mirrors.clear()


func _trigger_brittle_freeze() -> void:
	_brittle_t = BRITTLE_DURATION
	stage.play_sfx("weaver_glass_clink", pos)
	stage.play_sfx("magma_crack", pos)
	stage.shake(0.18)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_ring(pos, 5.0, 30.0, 0.30, PAL["ice"] as Color, 1.8)
	stagger_immunity_t = 0.0
	add_stagger(stagger_threshold)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if _brittle_t > 0.0:
		_brittle_t = maxf(0.0, _brittle_t - dt)
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for m: Dictionary in _spun_mirrors:
		m["flash_t"] = maxf(0.0, float(m["flash_t"]) - dt)
		m["cd"] = maxf(0.0, float(m["cd"]) - dt)
		# Even in generic LabWorld (without blue_transformer), shooting any spun mirror banks a Blue bounce into Weaver!
		if wick_node != null and str(m["interactable_id"]).is_empty() and float(m["cd"]) <= 0.0:
			var mp: Vector2 = m["pos"] as Vector2
			for bi: int in range(wick_node.bolts.size() - 1, -1, -1):
				var bv: Variant = wick_node.bolts[bi]
				if bv is Object and (bv.get("pos") as Vector2).distance_to(mp) <= 11.0:
					m["flash_t"] = 0.28
					m["cd"] = 0.75
					m["angle"] = float(m["angle"]) + PI * 0.25
					wick_node.bolts.remove_at(bi)
					stage.play_sfx("mirror_ping", mp)
					var bdir: Vector2 = (pos - mp).normalized() if pos.distance_to(mp) > 0.1 else Vector2.LEFT
					var b_hit := LxHit.make(LxHit.SOURCE_PRISM_BOLT, 1.4, bdir, mp, 1.0, false, false, wick_node, false, LxHit.COLOR_BLUE)
					take_hit(b_hit)
					break


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	# Blue light freezes her molten glass shell brittle (comedy overturned-teacup stagger)!
	if hit.is_blue() and _brittle_t <= 0.0:
		_trigger_brittle_freeze()
		return dmg * 1.45
	if _brittle_t > 0.0 or boss_state == BossState.STAGGER:
		return dmg * 1.55
	if is_punishable():
		return dmg
	# Liquid-glass hull resists uncooled yellow bolts slightly (never 0 — manual/bot play always wins!)
	if hit.source == LxHit.SOURCE_BOLT and not hit.pierce and not hit.cracks_armour:
		clank_t = 0.08
		return dmg * 0.76
	return dmg


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		stage.set_tiles(world_ctx, Rect2i(4, 2, 1, 1), "wall")
		stage.set_tiles(world_ctx, Rect2i(15, 8, 1, 1), "wall")
		stage.play_sfx("miniboss_forge_roar", pos)
		stage.shake(0.22)
		stage.darkness_pulse(0.54, 0.85)


func _on_death_start() -> void:
	_clear_spun_mirrors()
	stage.play_sfx("shield_shatter", pos)
	stage.light_burst(pos, 86.0, 1.35, 0.35)


func _pick_mirror_spot(near_p: Vector2) -> Vector2:
	var c: Vector2 = arena_rect.get_center()
	var mid: Vector2 = c.lerp(near_p, 0.45) + Vector2(cos(float(_mirror_seq) * 2.1) * 32.0, sin(float(_mirror_seq) * 2.1) * 24.0)
	return clamp_to_arena(mid)


func _build_droplet_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
	return out


func _body_color() -> Color:
	return (PAL["ice"] if _brittle_t > 0.0 else (PAL["gold"] if phase >= 2 else PAL["apricot"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var fred: bool = is_flash_reduced()
	# Draw LabWorld fallback glass mirrors (real rooms render their own LxMirror interactables!)
	for m: Dictionary in _spun_mirrors:
		if not str(m["interactable_id"]).is_empty():
			continue
		var mp: Vector2 = ((m["pos"] as Vector2) - pos).round()
		var fl: bool = float(m["flash_t"]) > 0.0 and not fred
		draw_circle(mp, 8.0, Color(PAL["sky"] as Color, 0.25 if not fl else 0.55))
		draw_arc(mp, 7.5, 0.0, TAU, 14, PAL["void"] as Color, 3.0)
		draw_arc(mp, 7.5, 0.0, TAU, 14, PAL["cream"] as Color if fl else PAL["ice"] as Color, 1.0)
		var nv: Vector2 = Vector2.from_angle(float(m["angle"])) * 6.0
		draw_line((mp - nv.orthogonal()).round(), (mp + nv.orthogonal()).round(), PAL["void"] as Color, 4.0)
		draw_line((mp - nv.orthogonal()).round(), (mp + nv.orthogonal()).round(), PAL["cream"] as Color, 2.0)
	# Sweeping molten loom beam during P2 commit
	if boss_state == BossState.COMMIT and active_attack_id == "furnace_loom_sweep":
		var u: float = clampf(_commit_elapsed / 0.45, 0.0, 1.0)
		var bend: Vector2 = (off + Vector2.from_angle(_sweep_base_ang + u * 1.56) * 128.0).round()
		draw_line(off.round(), bend, PAL["void"] as Color, 9.0)
		draw_line(off.round(), bend, PAL["wine"] as Color, 7.0)
		draw_line(off.round(), bend, PAL["coral"] as Color, 4.0)
		draw_line(off.round(), bend, PAL["gold"] as Color, 2.0)
		draw_line(off.round(), bend, PAL["cream"] as Color, 1.0)
	# Frosted brittle teacup halo
	if _brittle_t > 0.0:
		draw_arc(off.round(), body_radius + 5.0, 0.0, TAU, 20, PAL["void"] as Color, 4.0)
		draw_arc(off.round(), body_radius + 5.0, 0.0, TAU, 20, PAL["ice"] as Color, 2.0)
