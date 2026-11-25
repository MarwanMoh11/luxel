class_name LxKnightSpindleBoss
extends LxBossBase
## Island 3 Briar Court Joust #2: Dame Spindle (court_r3).
## Silk-swinging duelist tethered to 4 corner anchor spools.
## Reads `court_v1` verdict from Lx.vars ("island:3"):
##   - "mercy": blooms 2 living bounce-cap cover pillars shielding Spiral Lance Rain.
##   - "fire": clears open sun-lit kill-zone (+18% punish damage bonus & sharper tempo).
## Shooting her glowing corner spool or slicing her live silk tether unhorses her mid-swing (1.60 s stagger)!

const UNHORSE_STAGGER_S: float = 1.60

var _spools: Array[Vector2] = []
var _active_spool: int = 0
var _verdict_v1: String = "none"
var _swing_center: Vector2 = Vector2.ZERO
var _swing_ang: float = 0.0
var _swing_radius: float = 72.0
var _swing_dir: float = 1.0
var _swing_hit: bool = false
var _tether_active: bool = false


func _init() -> void:
	super._init()
	kind = "knight_spindle"
	boss_id = "knight_spindle"
	boss_name_key = "ISL3_BOSS_SPINDLE"
	island_id = 3
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 48.0
	hp = 48.0
	body_radius = 9.5
	move_speed = 48.0
	stagger_threshold = 10.0
	stagger_duration = 1.60
	post_recover_cd = 0.38
	intro_duration = 0.55
	phase_shift_duration = 0.65
	death_duration = 2.1
	shard_drop = 24


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Pendulum Joust (anchors to glowing corner spool -> sweeps curved pendulum arc across Wick!)
	register_attack("pendulum_joust", {
		"weight": 1.35, "tell": 0.52, "commit": 0.48, "recover": 1.20, "cooldown": 1.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_active_spool = _pick_spool_for(tgt)
			_swing_center = _spools[_active_spool] if _active_spool < _spools.size() else arena_rect.get_center()
			var rel: Vector2 = pos - _swing_center
			_swing_radius = clampf(rel.length(), 44.0, 118.0)
			_swing_ang = rel.angle()
			var tgt_ang: float = (tgt - _swing_center).angle()
			_swing_dir = 1.0 if angle_difference(_swing_ang, tgt_ang) >= 0.0 else -1.0
			_swing_hit = false
			_attach_swing_tether()
			ground.warn_lane(pos, clamp_to_arena(tgt), 12.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("ks_spindle_ring", _swing_center),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.14)
			stage.play_sfx("ks_tether_whip", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			if not _tether_active:
				return
			var omega: float = 2.6 if phase >= 2 else 2.25
			_swing_ang += _swing_dir * omega * dt
			var goal: Vector2 = clamp_to_arena(_swing_center + Vector2.from_angle(_swing_ang) * _swing_radius)
			var delta: Vector2 = goal - pos
			if delta.length() > 0.5:
				facing = delta.angle()
				move_boss(delta, true)
			if not _swing_hit and pos.distance_to(tgt) <= 18.0:
				_swing_hit = true
				emit_boss_damage(Vector2.from_angle(facing), 1.0, "pendulum_joust", pos, true),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			_detach_swing_tether(),
	})

	# Attack 2: Spiral Lance Rain (needle drops on Wick & corners + 4-arm silk spiral)
	register_attack("spiral_lance_rain", {
		"weight": 1.25, "tell": 0.56, "commit": 0.38, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_rain(ground, _lance_targets(tgt), last_tell_duration + 0.12, 22.0, 1.0, "coral", "ice")
			ground.warn_ring(pos, 22.0, last_tell_duration, 0.0, "ice", "gold")
			stage.play_sfx("ks_spindle_ring", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_spiral(pos, 4, 108.0 if phase >= 2 else 98.0, aim_a, 0.44, 2, 0.20, {
				"color": "ice", "reflectable": true, "source": "spiral_lance",
			})
			stage.shake(0.15)
			stage.play_sfx("ks_tether_whip", pos),
	})

	# Attack 3: P2 Twin-Spool Feint (cross-arena silk lightning between opposing spools + needle thrust fan!)
	register_attack("twin_spool_feint", {
		"phases": [2], "weight": 2.80, "tell": 0.58, "commit": 0.46, "recover": 1.25, "cooldown": 1.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			if _spools.size() >= 4:
				var s0: int = _pick_spool_for(tgt)
				var s2: int = (s0 + 2) % 4
				patterns.emit_chain_lightning([_spools[s0], _spools[s2]], last_tell_duration + 0.08, 8.0, 0.24, 1.0)
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			facing = aim_d.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + aim_d * 175.0), 10.0, last_tell_duration, 0.0, "sky", "gold")
			stage.play_sfx("ks_spindle_ring", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim_d, 5, 0.78, 120.0, {"color": "gold", "source": "twin_feint"})
			stage.shake(0.18)
			stage.play_sfx("ks_tether_whip", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			var to_t: Vector2 = tgt - pos
			if to_t.length() > 26.0:
				move_boss(to_t.normalized() * 112.0 * dt, true),
	})


func _on_reset_encounter() -> void:
	_tether_active = false
	_swing_hit = false
	_verdict_v1 = str(Lx.vars.get_var("island:3", "court_v1", "none")) if Lx.vars != null else "none"
	punish_dmg_mult = 1.45 if _verdict_v1 == "fire" else 1.35
	move_speed = 60.0 if _verdict_v1 == "fire" else 52.0
	_build_corner_spools()
	_apply_verdict_v1_terrain()


func _build_corner_spools() -> void:
	_spools.clear()
	var inset: Rect2 = arena_rect.grow(-18.0)
	_spools = [
		inset.position,
		Vector2(inset.end.x, inset.position.y),
		inset.end,
		Vector2(inset.position.x, inset.end.y),
	]
	for i: int in range(_spools.size()):
		var idx: int = i
		var sp_p: Dictionary = props.spawn_bell(_spools[i], func(_p: Dictionary) -> void:
			_on_spool_shot(idx), "ks_spool_%d" % i)
		sp_p["solid"] = false


func _apply_verdict_v1_terrain() -> void:
	if _verdict_v1 == "mercy":
		var c: Vector2 = arena_rect.get_center()
		props.spawn_pillar(c + Vector2(-46.0, 0.0), 6.0, "ks_mercy_cap_w")
		props.spawn_pillar(c + Vector2(46.0, 0.0), 6.0, "ks_mercy_cap_e")


func _pick_spool_for(tgt: Vector2) -> int:
	var best: int = 0
	var best_d: float = INF
	for i: int in range(_spools.size()):
		var d: float = _spools[i].distance_squared_to(tgt)
		if d < best_d:
			best_d = d
			best = i
	return best


func _attach_swing_tether() -> void:
	_detach_swing_tether()
	_tether_active = true
	var anchor_p: Vector2 = _swing_center
	tethers.add_tether("ks_pendulum_line", anchor_p, func() -> Vector2: return pos, {
		"hp": 1.2, "cuttable": true, "color": "gold", "max_length": _swing_radius + 8.0,
		"on_cut": func(_t: Dictionary) -> void: _unhorse_spindle(),
	})


func _detach_swing_tether() -> void:
	_tether_active = false
	tethers.clear()


func _on_spool_shot(idx: int) -> void:
	if boss_state == BossState.DEATH:
		return
	if _tether_active and idx == _active_spool:
		_unhorse_spindle()
	else:
		stage.play_sfx("ks_spindle_ring", _spools[idx])


func _unhorse_spindle() -> void:
	_detach_swing_tether()
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, UNHORSE_STAGGER_S)
	staggered.emit(UNHORSE_STAGGER_S)
	stage.shake(0.24)
	stage.play_sfx("ks_unhorse_thud", pos)
	LxDamageFx.boss_impact(pos, 0.20, 78.0, 82.0, 78.0, 1.38, 0.32)


func _lance_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var sorted_sp: Array[Vector2] = _spools.duplicate()
	sorted_sp.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	if sorted_sp.size() >= 1:
		out.append(clamp_to_arena(sorted_sp[0]))
	if phase >= 2 and sorted_sp.size() >= 2:
		out.append(clamp_to_arena(sorted_sp[1]))
	return out


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_detach_swing_tether()
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(17, 7, 1, 2), "pit")
		stage.darkness_pulse(0.60, 0.95)
		stage.shake(0.22)
		stage.play_sfx("ks_spindle_ring", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	if bool(h["cracks_armour"]) or src == LxHit.SOURCE_BEAM:
		if _tether_active:
			_unhorse_spindle()
		return dmg * 1.25
	if _tether_active and not is_punishable():
		# Silk cloak glances light bolts mid-swing; burn spool or cut tether to unhorse!
		clank_t = 0.08
		return dmg * 0.52
	return dmg


func _on_death_start() -> void:
	_detach_swing_tether()
	if Lx.vars != null and str(Lx.vars.get_var("island:3", "court_v2", "none")) == "none":
		Lx.vars.set_var("island:3", "court_v2", "fire")
	stage.play_sfx("ks_unhorse_thud", pos)


func _has_active_shield() -> bool:
	return _tether_active and not is_punishable()


func _shield_color() -> Color:
	return PAL["ice"] as Color


func _draw_boss_extra(_off: Vector2) -> void:
	var inv: Vector2 = -pos
	# Highlight active anchor spool glow so Wick reads which corner to bolt!
	if _active_spool >= 0 and _active_spool < _spools.size():
		var sp: Vector2 = (_spools[_active_spool] + inv).round()
		var r: float = 8.0 + sin(anim_t * 7.0) * 1.5
		draw_arc(sp, r, 0.0, TAU, 16, PAL["gold"] as Color if _tether_active else Color(PAL["ice"] as Color, 0.45), 1.5)
	if _verdict_v1 == "fire":
		# Subtle warm verdict seal on center floor
		var cp: Vector2 = (arena_rect.get_center() + inv).round()
		draw_arc(cp, 26.0, 0.0, TAU, 24, Color(PAL["apricot"] as Color, 0.30), 1.0)
