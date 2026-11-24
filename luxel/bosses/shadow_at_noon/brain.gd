class_name LxShadowAtNoonBoss
extends LxBossBase
## Island 7 Superboss: YOUR SHADOW AT NOON (Zenith Sundial, superboss_noon, post-great_lamp_7).
## Your own peeled shadow on the sunlit marble Zenith Sundial!
## P1 (100-66%): 1.5s Lag Replay of Wick's own moves via `duel.tick_echo_recorder` + Noon Flare Sweep.
## P2 (66-33%): 3-Hour Sundial splits into 3 shadows at 120 deg — hanging your lantern (or Throw/Sunflare)
##              merges 2 shadows into 1 vulnerable solid!
## P3 (<=33%): Zenith Zero-Shadow (0-deg overhead sun shrinks boss to tiny resistant dot) —
##             THROW lantern sideways (or hit with Throw/Beam/Dash/Sunflare) to cast a long horizontal
##             shadow body you can punish for 1.55x damage!

var _aim_dir: Vector2 = Vector2.LEFT
var _echo_pos: Vector2 = Vector2.ZERO
var _echo_dir: Vector2 = Vector2.RIGHT
var _echo_was_dash: bool = false
var _tri_shadows: Array[Dictionary] = []
var _merged_t: float = 0.0
var _stretched_t: float = 0.0
var _stretch_dir: Vector2 = Vector2.RIGHT
var _reunite_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "shadow_at_noon"
	boss_id = "shadow_at_noon"
	boss_name_key = "ISL7_BOSS_NOON"
	island_id = 7
	is_miniboss = false
	reward_heart = "none"
	music_cue = "island7_boss_p1"
	music_p2_cue = "island7_boss_p2"
	max_hp = 136.0
	hp = 136.0
	body_radius = 9.5
	move_speed = 46.0
	stagger_threshold = 18.0
	stagger_duration = 1.80
	post_recover_cd = 0.30
	shard_drop = 60


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Lag Echo — replays Wick's 1.5s-old position & move after a 0.46s glowing outline!
	register_attack("lag_echo", {
		"weight": 1.40, "tell": 0.46, "commit": 0.30, "recover": 1.10, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var snap: Dictionary = duel.get_echo_snapshot(1.5)
			_echo_pos = clamp_to_arena(snap.get("pos", pos) as Vector2) if not snap.is_empty() else pos
			_echo_was_dash = bool(snap.get("dashing", false))
			_echo_dir = (tgt - _echo_pos).normalized() if tgt.distance_to(_echo_pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_ring(_echo_pos, 20.0, last_tell_duration, 0.0, "gold", "cream")
			ground.warn_lane(_echo_pos, clamp_to_arena(_echo_pos + _echo_dir * 130.0), 10.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("shadow_whisper", _echo_pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_echo_dir = (tgt - _echo_pos).normalized() if tgt.distance_to(_echo_pos) > 0.1 else _echo_dir
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(_echo_pos, _echo_dir, cnt, 0.56, 152.0, {"color": "gold", "source": "lag_echo_bolt", "reflectable": true})
			if _echo_was_dash:
				patterns.emit_boomerang(pos, _echo_dir, 148.0, 0.60, 0.60, {"color": "coral", "source": "lag_echo_dash", "reflectable": true})
			stage.shake(0.12)
			stage.play_sfx("hollow_dash", _echo_pos),
	})

	# Attack 2: Noon Flare Sweep — 180-deg sweeping solar sun-blade + corner rays
	register_attack("noon_flare_sweep", {
		"weight": 1.25, "tell": 0.56, "commit": 0.36, "recover": 1.20, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var a: float = _aim_dir.angle()
			ground.warn_sector(pos, a - 1.50, a + 1.50, 96.0, last_tell_duration, 1.0, "gold", "coral")
			stage.play_sfx("sun_hum", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _aim_dir, 7 if phase >= 2 else 5, 1.65, 138.0, {"color": "coral", "source": "noon_blade", "reflectable": true})
			stage.light_burst(pos, 84.0, 1.40, 0.28)
			stage.shake(0.18)
			stage.play_sfx("sunflare_burst", pos),
	})

	# Attack 3: Sundial Gnomon — radial shadow pillars on Wick & nearest perimeter corners (no safe spots!)
	register_attack("sundial_gnomon", {
		"weight": 1.15, "tell": 0.52, "commit": 0.32, "recover": 1.15, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var spots: Array[Vector2] = _sundial_targets(tgt, 4 if phase >= 2 else 3)
			patterns.emit_rain(ground, spots, last_tell_duration, 22.0, 1.0, "coral", "gold")
			stage.play_sfx("sun_hum", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_gap_ring(pos, 10, 126.0, d.angle() + PI * 0.45, 0.72, {"color": "gold", "source": "gnomon_ring", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("shadow_whisper", pos),
	})

	# Attack 4 (Phase 2+): Tri-Shadow Pincer — 3 shadows at 120 deg fire converging lanes; hang lantern to merge!
	register_attack("tri_shadow_pincer", {
		"phases": [2, 3], "weight": 1.40, "tell": 0.58, "commit": 0.30, "recover": 1.25, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_place_tri_shadows(tgt)
			for ts: Dictionary in _tri_shadows:
				var sp: Vector2 = ts["pos"] as Vector2
				var sd: Vector2 = (tgt - sp).normalized() if tgt.distance_to(sp) > 0.1 else Vector2.LEFT
				ts["dir"] = sd
				ground.warn_lane(sp, clamp_to_arena(sp + sd * 135.0), 9.0, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("shadow_whisper", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			for ts: Dictionary in _tri_shadows:
				var sp: Vector2 = ts["pos"] as Vector2
				var sd: Vector2 = ts["dir"] as Vector2
				patterns.emit_fan(sp, sd, 3 if _merged_t <= 0.0 else 1, 0.42, 144.0, {"color": "coral", "source": "tri_pincer", "reflectable": true})
			stage.shake(0.16)
			stage.play_sfx("hollow_dash", pos),
	})

	# Attack 5 (Phase 3): Eclipse Implosion — 62px solar ring + gap burst; throw sideways to stretch shadow!
	register_attack("eclipse_implosion", {
		"phases": [3], "weight": 1.55, "tell": 0.60, "commit": 0.30, "recover": 1.35, "cooldown": 2.1,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_ring(pos, 64.0, last_tell_duration, 1.0, "gold", "cream")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("sun_hum", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_gap_ring(pos, 12, 134.0, _aim_dir.angle(), 0.72, {"color": "gold", "source": "eclipse_ring", "reflectable": true})
			patterns.emit_fan(pos, _aim_dir, 5, 0.75, 148.0, {"color": "coral", "source": "eclipse_sparks", "reflectable": true})
			stage.light_burst(pos, 96.0, 1.48, 0.34)
			stage.shake(0.22)
			stage.play_sfx("sunflare_burst", pos),
	})


func _on_reset_encounter() -> void:
	_echo_pos = home
	_echo_dir = Vector2.LEFT
	_echo_was_dash = false
	_tri_shadows.clear()
	_merged_t = 0.0
	_stretched_t = 0.0
	_stretch_dir = Vector2.RIGHT
	_reunite_t = 0.0


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	duel.tick_echo_recorder(dt)
	_merged_t = maxf(0.0, _merged_t - dt)
	_stretched_t = maxf(0.0, _stretched_t - dt)
	_reunite_t = maxf(0.0, _reunite_t - dt)

	# Lantern interaction: hanging/thrown lantern casts an angled shadow!
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		var away: Vector2 = pos - lp
		if away.length() > 4.0:
			_stretch_dir = away.normalized()
		if phase == 2 and _merged_t <= 0.0 and pos.distance_to(lp) <= 130.0:
			_merged_t = 4.5
			_tri_shadows.clear()
			stage.play_sfx("great_lamp_bloom", lp)
			add_stagger(stagger_threshold * 0.70)
		elif phase >= 3:
			_stretched_t = maxf(_stretched_t, 0.40)


func _is_zero_shadow_dot() -> bool:
	return phase >= 3 and _stretched_t <= 0.0 and not is_punishable()


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_cast_move: bool = src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_SUNFLARE, LxHit.SOURCE_BEAM, LxHit.SOURCE_DASH] or hit.is_blue()

	if phase == 2 and is_cast_move and _merged_t <= 0.0:
		_merged_t = 4.5
		_tri_shadows.clear()
		add_stagger(stagger_threshold * 0.65)
		return dmg * 1.45

	if phase >= 3:
		if is_cast_move:
			_stretched_t = 4.2
			if pos.distance_to(orig) > 2.0:
				_stretch_dir = (pos - orig).normalized()
			return dmg * 1.55
		if _stretched_t > 0.0 or is_punishable():
			return dmg * 1.40
		# Zenith 0-deg dot resists unstretched raw yellow bolts!
		clank_t = 0.10
		return dmg * 0.42

	if _merged_t > 0.0 or boss_state == BossState.STAGGER:
		return dmg * 1.45
	return dmg


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		_place_tri_shadows(_get_wick_pos())
		# Sundial trenches + 2 marble gnomon pillars (cleanly rolled back on reset!)
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 2), "pit")
		props.spawn_pillar(c + Vector2(-48.0, -24.0), 4.0, "sundial_gnomon_w")
		props.spawn_pillar(c + Vector2(48.0, 24.0), 4.0, "sundial_gnomon_e")
		stage.light_burst(c, 92.0, 1.38, 0.35)
		stage.shake(0.24)
		stage.play_sfx("sun_hum", pos)
	elif new_phase == 3:
		_tri_shadows.clear()
		_stretched_t = 0.0
		stage.light_burst(c, 118.0, 1.50, 0.45)
		stage.shake(0.26)
		stage.play_sfx("sunflare_burst", pos)


func _place_tri_shadows(tgt: Vector2) -> void:
	_tri_shadows.clear()
	var ctr: Vector2 = arena_rect.get_center()
	var base_a: float = (pos - ctr).angle() if pos.distance_to(ctr) > 4.0 else 0.0
	for k: int in range(3):
		var sp: Vector2 = clamp_to_arena(ctr + Vector2.from_angle(base_a + float(k) * (TAU / 3.0)) * 56.0)
		_tri_shadows.append({"pos": sp, "dir": (tgt - sp).normalized()})


func _on_death_start() -> void:
	_tri_shadows.clear()
	_reunite_t = 2.0
	stage.play_sfx("shadow_reunite", pos)


func _sundial_targets(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, corners.size())):
		out.append(clamp_to_arena(corners[i]))
	return out


func _body_color() -> Color:
	return PAL["void"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Zenith Sundial ring under boss
	draw_arc(c + Vector2(0.0, 4.0), 15.0, 0.0, TAU, 20, Color(PAL["gold"] as Color, 0.48), 1.2)

	# P1/All: Glowing gold 1.5s Lag Echo outline!
	if boss_state == BossState.TELL and active_attack_id == "lag_echo":
		var ep: Vector2 = (_echo_pos - pos).round()
		draw_circle(ep, 10.0, Color(PAL["void"] as Color, 0.55))
		draw_arc(ep, 11.0, 0.0, TAU, 16, PAL["gold"] as Color, 1.6)
		draw_arc(ep, 7.0, 0.0, TAU, 12, PAL["cream"] as Color, 1.0)

	# P2: 3-Hour Sundial split shadows at 120 deg!
	if phase == 2 and _merged_t <= 0.0:
		for ts: Dictionary in _tri_shadows:
			var lp: Vector2 = ((ts["pos"] as Vector2) - pos).round()
			draw_circle(lp, 9.0, Color(PAL["void"] as Color, 0.65))
			draw_arc(lp, 9.5, 0.0, TAU, 14, PAL["coral"] as Color, 1.3)

	# P3: Zenith Zero-Shadow dot vs Sideways-Stretched vulnerable shadow body!
	if phase >= 3:
		if _stretched_t > 0.0:
			var tip: Vector2 = (c + _stretch_dir * 38.0).round()
			draw_line(c, tip, PAL["void"] as Color, 11.0)
			draw_line(c, tip, PAL["gold"] as Color, 2.0)
			draw_circle(tip, 6.0, PAL["void"] as Color)
			draw_arc(tip, 6.5, 0.0, TAU, 12, PAL["cream"] as Color, 1.2)
		elif _is_zero_shadow_dot():
			draw_circle(c, 5.0, PAL["void"] as Color)
			draw_arc(c, 7.5, 0.0, TAU, 14, PAL["cream"] as Color, 1.6)
