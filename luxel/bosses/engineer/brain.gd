class_name LxEngineerBoss
extends LxBossBase
## Island 6 Ember Express Boss: THE ENGINEER (`train_r11`).
## 3-phase Locomotive Cab showdown -> Half-Lantern #1 (`reward_heart = "half"`).
## P1 (100-66%): Mahogany cab — Coal-Shovel Spread, Brake-Lurch (slides deck), Whistle Steam Lanes.
## P2 (66-33%): ROOF BLOWS OFF! Outer eaves open + Parallel Armored Rail-Drone patrols north track!
## P3 (<=33%): OVERCLOCKED BOILER — Twin Boiler Pressure Chains (`tethers`) shield hull until snapped
## for a massive Boiler Vent Stagger + Overpressure Blast!

const LURCH_PUSH_SPEED: float = 128.0
const DRONE_DISABLE_SECS: float = 6.0

var _aim_dir: Vector2 = Vector2.LEFT
var _drone_active: bool = false
var _drone_x: float = 0.0
var _drone_dir: float = 1.0
var _drone_disabled_t: float = 0.0
var _boiler_chains_spawned: bool = false
var _vent_stagger_flash: float = 0.0


func _init() -> void:
	super._init()
	kind = "engineer"
	boss_id = "engineer"
	boss_name_key = "ISL6_BOSS_ENG"
	island_id = 6
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island6_boss_p1"
	music_p2_cue = "island6_boss_p2"
	max_hp = 152.0
	hp = 152.0
	body_radius = 12.0
	move_speed = 36.0
	stagger_threshold = 16.0
	stagger_duration = 1.95
	post_recover_cd = 0.30
	intro_duration = 0.55
	death_duration = 2.0
	shard_drop = 34


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1 (P1+P2+P3): Coal-Shovel Spread (5-coal fan + lingering 2.4s ember puddles)
	register_attack("coal_shovel_spread", {
		"weight": 1.25, "tell": 0.52, "commit": 0.30, "recover": 1.15, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var ang: float = _aim_dir.angle()
			ground.warn_sector(pos, ang - 0.78, ang + 0.78, 74.0, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.06, 1.0, "coral", "gold")
			stage.play_sfx("furnace_draw", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 7 if phase >= 2 else 5
			patterns.emit_fan(pos, _aim_dir, cnt, 1.30, 142.0 if phase >= 2 else 128.0, {"color": "coral", "source": "engineer_coal"})
			for deg: float in [-24.0, 0.0, 24.0]:
				var pd_p: Vector2 = clamp_to_arena(pos + _aim_dir.rotated(deg_to_rad(deg)) * 62.0)
				ground.add_hazard_circle(pd_p, 15.0, 2.4, 1.0, "coral", true)
			stage.play_sfx("warden_swing", pos)
			stage.shake(0.16),
	})

	# Attack 2 (P1+P2+P3): Brake-Lurch (pulls red brake bar -> floor lurches forward + sweeping ember wall!)
	register_attack("brake_lurch", {
		"weight": 1.15, "tell": 0.62, "commit": 0.48, "recover": 1.20, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var r: Rect2 = arena_rect
			ground.warn_lane(Vector2(r.end.x - 10.0, r.get_center().y), Vector2(r.position.x + 10.0, r.get_center().y), 18.0, last_tell_duration, 0.0, "apricot", "gold")
			stage.play_sfx("steam_whistle", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			patterns.emit_sweep_wall(Vector2(arena_rect.end.x - 8.0, c.y), Vector2.LEFT, arena_rect.size.y - 24.0, 9, 3, 3, 128.0, {"color": "gold", "source": "engineer_lurch"})
			stage.play_sfx("coupler_snap", pos)
			stage.shake(0.20),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, _el: float) -> void:
			if Lx.player is LxWick and is_instance_valid(Lx.player):
				var w: LxWick = Lx.player as LxWick
				if not w.dead and w.global_position.x > arena_rect.position.x + 22.0 and w.has_method("push_external"):
					w.call("push_external", Vector2(-LURCH_PUSH_SPEED, 0.0), "brake_lurch"),
	})

	# Attack 3 (P1+P2+P3): Whistle Steam Lanes (3 parallel horizontal high-pressure steam pipes!)
	register_attack("whistle_steam_lanes", {
		"weight": 1.20, "tell": 0.55, "commit": 0.34, "recover": 1.20, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var r: Rect2 = arena_rect
			var ys: Array[float] = _pick_steam_lane_ys(tgt)
			for ly: float in ys:
				ground.warn_lane(Vector2(r.position.x, ly), Vector2(r.end.x, ly), 11.0, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("steam_whistle", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			patterns.emit_fan(pos, d, 3, 0.45, 136.0, {"color": "apricot", "source": "engineer_steam"})
			stage.play_sfx("forge_gust", pos)
			stage.shake(0.16),
	})

	# Attack 4 (P2+P3): Parallel Rail-Drone Barrage (north track turret fires flanking bolts + boss gap ring!)
	register_attack("rail_drone_barrage", {
		"phases": [2, 3],
		"weight": 1.65, "tell": 0.50, "commit": 0.30, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var dp: Vector2 = _drone_pos()
			var d_aim: Vector2 = (tgt - dp).normalized() if tgt.distance_to(dp) > 0.1 else Vector2.DOWN
			ground.warn_lane(dp, dp + d_aim * 150.0, 9.0, last_tell_duration, 0.0, "apricot", "cream")
			stage.play_sfx("coupler_snap", dp),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var dp: Vector2 = _drone_pos()
			if _drone_disabled_t <= 0.0:
				var d_aim: Vector2 = (tgt - dp).normalized() if tgt.distance_to(dp) > 0.1 else Vector2.DOWN
				patterns.emit_fan(dp, d_aim, 3, 0.58, 144.0, {"color": "gold", "source": "rail_drone"})
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else PI
			patterns.emit_gap_ring(pos, 10, 114.0, gap_a, 0.72, {"color": "coral", "source": "engineer_ring"})
			stage.play_sfx("golem_stomp", pos),
	})

	# Attack 5 (P3): Boiler Overpressure (68px expanding steam ring + corner cinder rain!)
	register_attack("boiler_overpressure", {
		"phases": [3],
		"weight": 1.90, "tell": 0.64, "commit": 0.34, "recover": 1.30, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 68.0, last_tell_duration, 1.0, "coral", "cream")
			var drops: Array[Vector2] = _build_overpressure_drops(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration + 0.08, 22.0, 1.0, "apricot", "gold")
			stage.play_sfx("boss_kilnmother_roar", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else 0.0
			patterns.emit_gap_ring(pos, 12, 122.0, gap_a, 0.68, {"color": "gold", "source": "engineer_overpressure"})
			stage.light_burst(pos, 96.0, 1.4, 0.32)
			stage.play_sfx("golem_stomp", pos)
			stage.shake(0.24),
	})


func _on_reset_encounter() -> void:
	_drone_active = false
	_drone_x = arena_rect.get_center().x
	_drone_dir = 1.0
	_drone_disabled_t = 0.0
	_boiler_chains_spawned = false
	_vent_stagger_flash = 0.0


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# ROOF BLOWS OFF! Frame-freeze hitstop + outer eave cutouts + north Rail-Drone!
		if Lx.hitstop != null and Lx.hitstop.has_method("trigger"):
			Lx.hitstop.call("trigger", 0.12)
		stage.set_tiles(world_ctx, Rect2i(3, 1, 2, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(15, 1, 2, 1), "pit")
		_drone_active = true
		_drone_x = arena_rect.get_center().x
		_drone_disabled_t = 0.0
		stage.play_sfx("boss_kilnmother_roar", pos)
		stage.darkness_pulse(0.62, 0.95)
		stage.shake(0.24)
	elif new_phase == 3:
		# OVERCLOCKED BOILER: Twin cuttable Boiler Pressure Chains flanking the cab!
		_spawn_boiler_chains()
		stage.play_sfx("boss_kilnmother_roar", pos)
		stage.light_burst(pos, 100.0, 1.45, 0.36)
		stage.shake(0.26)


func _spawn_boiler_chains() -> void:
	if _boiler_chains_spawned:
		return
	_boiler_chains_spawned = true
	var r: Rect2 = arena_rect
	var anchor_w := Vector2(r.position.x + 12.0, r.get_center().y - 12.0)
	var anchor_e := Vector2(r.end.x - 12.0, r.get_center().y - 12.0)
	var self_pos: Callable = func() -> Vector2: return pos
	var on_chain_cut: Callable = func(_t: Dictionary) -> void:
		_vent_stagger_flash = 1.8
		stage.play_sfx("shield_shatter", pos)
		stage.shake(0.22)
		stagger_immunity_t = 0.0
		add_stagger(stagger_threshold)
	tethers.add_tether("boiler_chain_w", anchor_w, self_pos, {"hp": 1.8, "cuttable": true, "color": "gold", "on_cut": on_chain_cut})
	tethers.add_tether("boiler_chain_e", anchor_e, self_pos, {"hp": 1.8, "cuttable": true, "color": "gold", "on_cut": on_chain_cut})


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if _vent_stagger_flash > 0.0:
		_vent_stagger_flash = maxf(0.0, _vent_stagger_flash - dt)
	if _drone_active:
		if _drone_disabled_t > 0.0:
			_drone_disabled_t = maxf(0.0, _drone_disabled_t - dt)
		else:
			_drone_x += _drone_dir * 66.0 * dt
			if _drone_x <= arena_rect.position.x + 26.0:
				_drone_x = arena_rect.position.x + 26.0
				_drone_dir = 1.0
			elif _drone_x >= arena_rect.end.x - 26.0:
				_drone_x = arena_rect.end.x - 26.0
				_drone_dir = -1.0
			_check_player_hits_drone()


func _check_player_hits_drone() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	var dp: Vector2 = _drone_pos()
	for bi: int in range(w.bolts.size() - 1, -1, -1):
		var bv: Variant = w.bolts[bi]
		if bv is Object:
			var bp: Vector2 = bv.get("pos") as Vector2
			if bp.distance_to(dp) <= 12.0:
				var cracks: bool = bool(bv.get("cracks_armour")) or bool(bv.get("is_pierce"))
				if cracks:
					_drone_disabled_t = DRONE_DISABLE_SECS
					stage.play_sfx("shield_shatter", dp)
					w.spawn_ring(dp, 3.0, 18.0, 0.24, PAL["gold"] as Color, 1.5)
				else:
					_drone_disabled_t = 2.5
					stage.play_sfx("shield_clang", dp)
				w.bolts.remove_at(bi)
				break


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	# P3 Overclocked Boiler: while BOTH pressure chains remain uncut, hull takes reduced damage (never 0!)
	if phase >= 3 and tethers.active_count() >= 2 and not is_punishable():
		if not hit.cracks_armour and hit.source != LxHit.SOURCE_SUNFLARE:
			clank_t = 0.10
			return dmg * 0.62
	return dmg


func _on_death_start() -> void:
	_drone_active = false
	stage.play_sfx("steam_whistle", pos)


func _drone_pos() -> Vector2:
	return Vector2(_drone_x, arena_rect.position.y + 12.0)


func _pick_steam_lane_ys(tgt: Vector2) -> Array[float]:
	var r: Rect2 = arena_rect
	var y_tgt: float = clampf(tgt.y, r.position.y + 8.0, r.end.y - 8.0)
	var y_top: float = r.position.y + 16.0
	var y_bot: float = r.end.y - 16.0
	var out: Array[float] = [y_tgt]
	for cand: float in [y_top, r.get_center().y, y_bot]:
		var far: bool = true
		for ex: float in out:
			if absf(cand - ex) < 34.0:
				far = false
				break
		if far and out.size() < 3:
			out.append(cand)
	return out


func _build_overpressure_drops(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	return out


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 3 else (PAL["apricot"] if phase == 2 else PAL["plum"])) as Color


func _draw_boss_extra(_off: Vector2) -> void:
	# Draw Parallel Armored Rail-Drone on north rail in P2+
	if _drone_active and boss_state != BossState.DEATH:
		var dp: Vector2 = (_drone_pos() - pos).round()
		var rail_y: float = arena_rect.position.y + 12.0 - pos.y
		draw_line(Vector2(arena_rect.position.x - pos.x, rail_y), Vector2(arena_rect.end.x - pos.x, rail_y), PAL["dusk"] as Color, 2.0)
		var d_col: Color = PAL["mauve"] as Color if _drone_disabled_t > 0.0 else PAL["coral"] as Color
		draw_rect(Rect2(dp + Vector2(-9.0, -5.0), Vector2(18.0, 10.0)), PAL["void"] as Color, true)
		draw_rect(Rect2(dp + Vector2(-8.0, -4.0), Vector2(16.0, 8.0)), d_col, true)
		draw_rect(Rect2(dp + Vector2(-3.0, -2.0), Vector2(6.0, 4.0)), PAL["ice"] as Color if _drone_disabled_t > 0.0 else PAL["gold"] as Color, true)
	# Overclocked boiler glow ring when both chains are still attached in P3
	if phase >= 3 and tethers.active_count() >= 2 and boss_state != BossState.DEATH:
		draw_arc(Vector2.ZERO, body_radius + 4.5, 0.0, TAU, 20, PAL["coral"] as Color, 2.0)
