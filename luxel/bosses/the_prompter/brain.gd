class_name LxThePrompterBoss
extends LxBossBase
## Island 7 Mini-Boss: THE PROMPTER (Doppel Theatre, theatre_r5).
## Velvet marionette conductor suspended by 2 cuttable overhead cords!
## In theatre_r5, Act II steals Dash & Wings so Wick Zips between corner hooks over crimson
## baton sweeps. Cutting BOTH cords drops The Prompter into the pit for a 2.2s crash-stagger
## (comedy beat: frantically flips sheet music upside-down squeaking violin notes!).
## P2 (<=50%): Orchestra pit dims to spotlights + twin crossing Scissor Finale where cords hang low.

var _aim_dir: Vector2 = Vector2.LEFT
var _sweep_ang: float = 0.0
var _cords_low: bool = false
var _pit_crash_t: float = 0.0
var _sheet_t: float = 0.0
var _cords_cut_count: int = 0


func _init() -> void:
	super._init()
	kind = "the_prompter"
	boss_id = "the_prompter"
	boss_name_key = "ISL7_BOSS_PROMPTER"
	island_id = 7
	is_miniboss = true
	reward_heart = "none"
	music_cue = "isl7_boss_minor_p1"
	music_p2_cue = "isl7_boss_minor_p2"
	max_hp = 82.0
	hp = 82.0
	body_radius = 11.0
	move_speed = 36.0
	stagger_threshold = 14.0
	stagger_duration = 2.20
	post_recover_cd = 0.30
	shard_drop = 30


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Crescendo Baton Sweep — crimson 90-deg baton sweep + sliding note fan
	register_attack("crescendo_baton_sweep", {
		"weight": 1.35, "tell": 0.56, "commit": 0.38, "recover": 1.20, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			_sweep_ang = _aim_dir.angle()
			ground.warn_sector(pos, _sweep_ang - 0.78, _sweep_ang + 0.78, 128.0, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("violin_screech", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 7 if phase >= 2 else 5
			patterns.emit_fan(pos, _aim_dir, cnt, 1.15, 142.0, {"color": "gold", "source": "baton_notes", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("timpani_hit", pos),
	})

	# Attack 2: Staccato Note Rain — 5 gold rings dropping on Wick & nearest perimeter corners
	register_attack("staccato_note_rain", {
		"weight": 1.20, "tell": 0.50, "commit": 0.32, "recover": 1.10, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_note_targets(tgt, 5)
			patterns.emit_rain(ground, drops, last_tell_duration, 21.0, 1.0, "gold", "coral")
			stage.play_sfx("violin_screech", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 3, 0.45, 134.0, {"color": "coral", "source": "staccato_spark", "reflectable": true})
			stage.shake(0.12)
			stage.play_sfx("timpani_hit", pos),
	})

	# Attack 3: Tempo Wave — expanding gap ring + baton boomerang (pressures all 8 perimeter spots!)
	register_attack("tempo_wave", {
		"weight": 1.10, "tell": 0.52, "commit": 0.34, "recover": 1.15, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_ring(pos, 38.0, last_tell_duration, 1.0, "wine", "gold")
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 135.0), 10.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("timpani_hit", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 126.0, _aim_dir.angle() + PI * 0.45, 0.72, {"color": "gold", "source": "tempo_ring", "reflectable": true})
			patterns.emit_boomerang(pos, _aim_dir, 146.0, 0.65, 0.65, {"color": "coral", "source": "baton_throw", "reflectable": true})
			stage.shake(0.15)
			stage.play_sfx("violin_screech", pos),
	})

	# Attack 4 (Phase 2): Scissor Finale — twin crossing crimson baton lanes; cords hang low!
	register_attack("scissor_finale", {
		"phases": [2], "weight": 1.50, "tell": 0.60, "commit": 0.40, "recover": 1.35, "cooldown": 2.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_cords_low = true
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var d1: Vector2 = _aim_dir.rotated(-0.34)
			var d2: Vector2 = _aim_dir.rotated(0.34)
			ground.warn_lane(pos, clamp_to_arena(pos + d1 * 170.0), 11.0, last_tell_duration, 1.0, "coral", "cream")
			ground.warn_lane(pos, clamp_to_arena(pos + d2 * 170.0), 11.0, last_tell_duration, 1.0, "coral", "cream")
			stage.play_sfx("violin_screech", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var d1: Vector2 = _aim_dir.rotated(-0.34)
			var d2: Vector2 = _aim_dir.rotated(0.34)
			patterns.emit_lane(pos, d1, 3, 178.0, 0.06, {"color": "coral", "source": "scissor_l", "reflectable": true})
			patterns.emit_lane(pos, d2, 3, 178.0, 0.06, {"color": "gold", "source": "scissor_r", "reflectable": true})
			stage.shake(0.20)
			stage.play_sfx("timpani_hit", pos),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			_cords_low = true,
	})


func _on_reset_encounter() -> void:
	_cords_low = false
	_pit_crash_t = 0.0
	_sheet_t = 0.0
	_cords_cut_count = 0
	_spawn_cords()


func _spawn_cords() -> void:
	tethers.clear()
	_cords_cut_count = 0
	var cord_hp: float = 2.2 if phase >= 2 else 1.8
	tethers.add_tether(
		"cord_l",
		func() -> Vector2: return pos + Vector2(-14.0, -38.0 if not _cords_low else -24.0),
		func() -> Vector2: return pos + Vector2(-8.0, -8.0),
		{"hp": cord_hp, "cuttable": true, "color": "rose", "on_cut": Callable(self, "_on_cord_cut")},
	)
	tethers.add_tether(
		"cord_r",
		func() -> Vector2: return pos + Vector2(14.0, -38.0 if not _cords_low else -24.0),
		func() -> Vector2: return pos + Vector2(8.0, -8.0),
		{"hp": cord_hp, "cuttable": true, "color": "gold", "on_cut": Callable(self, "_on_cord_cut")},
	)


func _on_cord_cut(_t: Dictionary) -> void:
	_cords_cut_count += 1
	stage.play_sfx("string_snap", pos)
	if tethers.active_count() <= 0:
		# Both cords snapped: drop conductor into the orchestra pit for 2.2s comedy stagger!
		_pit_crash_t = 2.2
		_sheet_t = 2.2
		_cords_low = false
		stage.shake(0.22)
		stage.play_sfx("violin_screech", pos)
		stagger_immunity_t = 0.0
		stagger_meter = stagger_threshold
		add_stagger(1.0)
	else:
		add_stagger(stagger_threshold * 0.45)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_pit_crash_t = maxf(0.0, _pit_crash_t - dt)
	_sheet_t = maxf(0.0, _sheet_t - dt)
	if boss_state == BossState.READY:
		_cords_low = false
		if tethers.active_count() == 0 and _pit_crash_t <= 0.0:
			_spawn_cords()
			stage.play_sfx("curtain_whoosh", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var cord_mult: float = 1.60 if _cords_low else 1.0
	# Beam / Throw / Sunflare slice overhead cords cleanly!
	if tethers.active_count() > 0:
		if src == LxHit.SOURCE_SUNFLARE:
			tethers.cut_tether("cord_l")
			tethers.cut_tether("cord_r")
		elif src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP]:
			var cid: String = "cord_l" if not bool(tethers.get_tether("cord_l").get("cut", true)) else "cord_r"
			var c_t: Dictionary = tethers.get_tether(cid)
			if not c_t.is_empty():
				c_t["hp"] = maxf(0.0, float(c_t["hp"]) - dmg * cord_mult)
				c_t["flash_t"] = 0.14
				if float(c_t["hp"]) <= 0.001:
					tethers.cut_tether(cid)
	if boss_state == BossState.STAGGER:
		return dmg * 1.50
	if tethers.active_count() >= 2 and src == LxHit.SOURCE_BOLT and not is_punishable():
		return dmg * 0.72
	return dmg * (1.20 if _cords_low else 1.0)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		# Pit dims to spotlight hooks + orchestra pit trenches + 2 music-stand pillars!
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 2), "pit")
		props.spawn_pillar(c + Vector2(-50.0, -24.0), 4.0, "prompter_stand_w")
		props.spawn_pillar(c + Vector2(50.0, 24.0), 4.0, "prompter_stand_e")
		_spawn_cords()
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.24)
		stage.play_sfx("timpani_hit", pos)


func _on_death_start() -> void:
	tethers.clear()
	stage.play_sfx("timpani_hit", pos)
	stage.play_sfx("mask_shatter", pos)


func _build_note_targets(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var cands: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
		arena_rect.get_center().lerp(tgt, 0.55),
	]
	cands.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, cands.size())):
		out.append(clamp_to_arena(cands[i]))
	return out


func _body_color() -> Color:
	return PAL["wine"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# P2 Golden Stage Spotlights over the 4 corners
	if phase >= 2:
		var inset: Rect2 = arena_rect.grow(-28.0)
		for sp: Vector2 in [inset.position, Vector2(inset.end.x, inset.position.y), Vector2(inset.position.x, inset.end.y), inset.end]:
			var lp: Vector2 = (sp - pos).round()
			draw_circle(lp, 16.0, Color(PAL["gold"] as Color, 0.14))
			draw_arc(lp, 16.0, 0.0, TAU, 16, Color(PAL["gold"] as Color, 0.42), 1.0)

	# Comedy beat: frantically flipping upside-down sheet music while crashed in pit!
	if _sheet_t > 0.0 or boss_state == BossState.STAGGER:
		for si: int in range(3):
			var sa: float = anim_t * 3.8 + float(si) * (TAU / 3.0)
			var sp2: Vector2 = (c + Vector2(cos(sa) * 18.0, -14.0 + sin(sa * 1.4) * 5.0)).round()
			draw_rect(Rect2(sp2 - Vector2(4, 3), Vector2(8, 6)), PAL["cream"] as Color)
			draw_line(sp2 + Vector2(-3, -1), sp2 + Vector2(3, -1), PAL["void"] as Color, 1.0)
			draw_line(sp2 + Vector2(-3, 1), sp2 + Vector2(2, 1), PAL["wine"] as Color, 1.0)
