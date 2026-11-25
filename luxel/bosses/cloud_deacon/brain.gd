class_name LxCloudDeaconBoss
extends LxBossBase
## Island 4 Mini-Boss B (mausoleum_r5): The Cloud-Urn Deacon.
## Levitating rain-chapel monk shielded by 3 orbiting rain-urns tied to active weather!
## Spin WIND to blow the 3 urns wide and shatter them (1.85s stagger); spin SUN to evaporate
## his rain-shield (1.35x dmg + shrunk cloud-wig fanning comedy beat!). In Phase 2 he hijacks
## the weather back to RAIN every 12 s and floods the outer chapel corners.

const URN_COUNT: int = 3
const URN_STAGGER_S: float = 1.85
const URN_RESPAWN_S: float = 9.0
const P2_HIJACK_PERIOD: float = 12.0

var _weather: String = "rain"
var _urn_angle: float = 0.0
var _urn_radius: float = 22.0
var _urns: Array[Dictionary] = []  # [{intact: bool, flash_t: float, offset_a: float}]
var _urn_respawn_t: float = 0.0
var _hijack_t: float = P2_HIJACK_PERIOD
var _wheel_pos: Vector2 = Vector2.ZERO
var _wheel_cd: float = 0.0
var _has_room_wheel: bool = false
var _censer_dir: Vector2 = Vector2.RIGHT
var _squall_dir: Vector2 = Vector2.RIGHT
var _squall_field_t: float = 0.0
var _death_steam: Array[Dictionary] = []


func _init() -> void:
	super._init()
	kind = "boss_cloud_deacon"
	boss_id = "boss_cloud_deacon"
	boss_name_key = "ISL4_BOSS_DEACON"
	island_id = 4
	is_miniboss = true
	reward_heart = "none"
	music_cue = "isl4_boss_minor_p1"
	music_p2_cue = "isl4_boss_minor_p2"
	max_hp = 56.0
	hp = 56.0
	body_radius = 10.5
	move_speed = 42.0
	stagger_threshold = 13.0
	stagger_duration = 1.65
	post_recover_cd = 0.30
	shard_drop = 45
	death_duration = 2.2


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.56])

	# Attack 1: Downpour Barrage — 5 telegraphed raindrop puddle circles (pressures corners + Wick)
	register_attack("downpour_barrage", {
		"weight": 1.25, "tell": 0.56, "commit": 0.45, "recover": 1.05, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_downpour_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "sky", "gold")
			stage.play_sfx("deacon_rain_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 5 if phase >= 2 else 3, 0.72, 134.0, {"color": "sky", "source": "downpour_drops"})
			stage.shake(0.14)
			stage.play_sfx("marsh_splash", pos),
	})

	# Attack 2: Censer Swing — 68 px chained censer sweep + curved rain fan
	register_attack("censer_swing", {
		"weight": 1.20, "tell": 0.50, "commit": 0.32, "recover": 1.10, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_censer_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _censer_dir.angle()
			ground.warn_sector(pos, _censer_dir.angle() - 0.92, _censer_dir.angle() + 0.92, 68.0, last_tell_duration, 0.0, "gold", "coral")
			ground.warn_lane(pos, clamp_to_arena(pos + _censer_dir * 136.0), 9.0, last_tell_duration, 0.0, "sky", "ice")
			stage.play_sfx("warden_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 7 if phase >= 2 else 5
			patterns.emit_fan(pos, _censer_dir, cnt, 1.05, 142.0 if phase >= 2 else 130.0, {"color": "gold", "source": "censer_swing"})
			stage.shake(0.15)
			stage.play_sfx("deacon_censer_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_censer_dir * 76.0 * dt, true)
			check_contact_damage(26.0, _censer_dir, 1.0, "censer_swing"),
	})

	# Attack 3: Urn Carousel — spins orbiting urn bolts outward + targeted rain lance
	register_attack("urn_carousel", {
		"weight": 1.15, "tell": 0.54, "commit": 0.38, "recover": 0.95, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			ground.warn_ring(pos, 46.0, last_tell_duration, 0.0, "sky", "cream")
			ground.warn_lane(pos, clamp_to_arena(pos + d * 150.0), 8.0, last_tell_duration, 0.0, "sky", "gold")
			stage.play_sfx("deacon_rain_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var orb_r: float = 52.0 if _weather == "wind" else 36.0
			patterns.emit_orbit(pos, 4 if phase >= 2 else 3, orb_r, 2.4, 2.2, {"color": "sky", "source": "urn_orbit"})
			patterns.emit_lane(pos, d, 3 if phase >= 2 else 2, 152.0, 0.10, {"color": "ice", "source": "urn_lance"})
			stage.play_sfx("deacon_censer_swing", pos),
	})

	# Attack 4 (Phase 2): Squall Line — sweeping gale wall with clean 2-slot dodge gap + gust push
	register_attack("squall_line", {
		"phases": [2], "weight": 1.65, "tell": 0.60, "commit": 0.38, "recover": 1.15, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_squall_dir = Vector2.LEFT if tgt.x < arena_rect.get_center().x else Vector2.RIGHT
			var c: Vector2 = arena_rect.get_center()
			var start_x: float = arena_rect.end.x - 10.0 if _squall_dir.x < 0.0 else arena_rect.position.x + 10.0
			var end_x: float = arena_rect.position.x + 10.0 if _squall_dir.x < 0.0 else arena_rect.end.x - 10.0
			ground.warn_lane(Vector2(start_x, c.y), Vector2(end_x, c.y), arena_rect.size.y * 0.34, last_tell_duration, 0.0, "sky", "ice")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.04, 1.0, "sky", "gold")
			stage.play_sfx("deacon_squall", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var sx: float = arena_rect.end.x - 10.0 if _squall_dir.x < 0.0 else arena_rect.position.x + 10.0
			var gap_idx: int = 3 if int(anim_t * 10.0) % 2 == 0 else 5
			patterns.emit_sweep_wall(Vector2(sx, c.y), _squall_dir, arena_rect.size.y - 20.0, 10, gap_idx, 2, 128.0, {"color": "ice", "source": "squall_line"})
			_squall_field_t = 0.38
			stage.shake(0.18)
			stage.play_sfx("deacon_squall", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, _el: float) -> void:
			if Lx.player is LxWick and is_instance_valid(Lx.player) and Lx.player.has_method("push_external"):
				(Lx.player as LxWick).push_external(_squall_dir * 62.0, "deacon_squall"),
	})


func _on_reset_encounter() -> void:
	_weather = _read_weather()
	_urn_angle = 0.0
	_urn_radius = _target_urn_radius()
	_urn_respawn_t = 0.0
	_hijack_t = P2_HIJACK_PERIOD
	_wheel_pos = arena_rect.get_center() + Vector2(0.0, 26.0)
	_wheel_cd = 0.0
	_has_room_wheel = _detect_room_wheel()
	_squall_field_t = 0.0
	_death_steam.clear()
	_reset_urns()


func _reset_urns() -> void:
	_urns.clear()
	for i: int in range(URN_COUNT):
		_urns.append({"intact": true, "flash_t": 0.0, "offset_a": float(i) * (TAU / float(URN_COUNT))})


func on_weather_changed(new_weather: String, _wind_dir: Vector2) -> void:
	var w: String = new_weather.strip_edges().to_lower()
	if w in ["sun", "rain", "wind"]:
		_weather = w
		if w == "sun":
			stage.play_sfx("deacon_steam_hiss", pos)


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		# Flood outer chapel moat corners (cleanly rolled back on reset_encounter!)
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 2), "water")
		props.spawn_pillar(clamp_to_arena(c + Vector2(-50.0, -24.0)), 4.0, "chapel_pillar_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(50.0, -24.0)), 4.0, "chapel_pillar_e")
		_hijack_weather_to_rain()
		_hijack_t = P2_HIJACK_PERIOD
		stage.darkness_pulse(0.58, 0.95)
		stage.shake(0.22)
		stage.play_sfx("boss_roar", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_wheel_cd = maxf(0.0, _wheel_cd - dt)
	_squall_field_t = maxf(0.0, _squall_field_t - dt)
	var live_w: String = _read_weather()
	if not live_w.is_empty():
		_weather = live_w

	var spin_spd: float = 2.6 if _weather == "wind" else (2.0 if phase >= 2 else 1.5)
	_urn_angle = wrapf(_urn_angle + spin_spd * dt, -PI, PI)
	_urn_radius = move_toward(_urn_radius, _target_urn_radius(), 58.0 * dt)
	for u_d: Dictionary in _urns:
		u_d["flash_t"] = maxf(0.0, float(u_d["flash_t"]) - dt)

	if _intact_urn_count() == 0:
		_urn_respawn_t -= dt
		if _urn_respawn_t <= 0.0 and boss_state != BossState.STAGGER:
			_reset_urns()
			stage.play_sfx("deacon_rain_chime", pos)

	# Phase 2: hijacks weather back to RAIN every 12 s
	if phase >= 2 and boss_state != BossState.DEATH:
		_hijack_t -= dt
		if _hijack_t <= 0.0:
			_hijack_t = P2_HIJACK_PERIOD
			if _weather != "rain":
				_hijack_weather_to_rain()

	_check_player_bolt_interactions()

	for st: Dictionary in _death_steam:
		st["pos"] = (st["pos"] as Vector2) + (st["vel"] as Vector2) * dt


func _check_player_bolt_interactions() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.move_bolt == null or not (w.move_bolt.get("bolts") is Array):
		return
	for b_v: Variant in (w.move_bolt.get("bolts") as Array):
		if not (b_v is Dictionary):
			continue
		var bd: Dictionary = b_v as Dictionary
		if not bool(bd.get("active", true)):
			continue
		var bp: Vector2 = bd.get("pos", Vector2.INF) as Vector2
		if not bp.is_finite():
			continue
		# Fallback arena weather wheel (for boss_lab when no room weather_wheel exists)
		if not _has_room_wheel and _wheel_cd <= 0.0 and bp.distance_to(_wheel_pos) <= 13.0:
			_wheel_cd = 0.55
			_cycle_local_weather()
			bd["active"] = false
			continue
		# Shooting blown-wide urns in WIND (or directly) shatters them!
		var urn_hit_r: float = 11.0 if _weather == "wind" else 7.5
		for u_d: Dictionary in _urns:
			if not bool(u_d["intact"]):
				continue
			var up: Vector2 = _urn_world_pos(u_d)
			if bp.distance_to(up) <= urn_hit_r:
				u_d["intact"] = false
				u_d["flash_t"] = 0.25
				bd["active"] = false
				stage.play_sfx("deacon_urn_break", up)
				if _intact_urn_count() == 0:
					_urn_respawn_t = URN_RESPAWN_S
					_trigger_urn_shatter_stagger()
				break


func _trigger_urn_shatter_stagger() -> void:
	stagger_immunity_t = 0.0
	stagger_meter = 0.0
	_release_token()
	active_attack_id = ""
	_set_boss_state(BossState.STAGGER, URN_STAGGER_S)
	staggered.emit(URN_STAGGER_S)
	LxDamageFx.boss_impact(pos, 0.18, 82.0, 84.0, 82.0, 1.38, 0.34, "ice")
	stage.play_sfx("warden_shield_break", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if boss_state == BossState.STAGGER:
		return dmg * 1.50
	if _weather == "sun":
		# SUN evaporates rain-shield completely!
		return dmg * (1.45 if (hit != null and hit.source == LxHit.SOURCE_BEAM) else 1.25)
	if _weather == "rain" and _intact_urn_count() > 0 and not is_punishable() and hit != null and hit.source == LxHit.SOURCE_BOLT:
		# Rain-urn shield softens unfocused bolt spam while urns orbit tightly (Beam pierces!)
		return dmg * 0.68
	return dmg


func _on_death_start() -> void:
	_death_steam.clear()
	for i: int in range(8):
		var a: float = (TAU * float(i)) / 8.0
		_death_steam.append({
			"pos": pos + Vector2.from_angle(a) * 8.0,
			"vel": Vector2(cos(a) * 16.0, -24.0 - float(i % 3) * 8.0),
		})
	stage.play_sfx("deacon_rain_chime", pos)


func _hijack_weather_to_rain() -> void:
	_weather = "rain"
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:rain_mausoleum", "weather", "rain")
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is Object and is_instance_valid(it_v) and (it_v as Object).has_method("set_weather"):
				(it_v as Object).call("set_weather", "rain", true)
	stage.play_sfx("weather_shift_rain", pos)


func _cycle_local_weather() -> void:
	var order: Array[String] = ["sun", "rain", "wind"]
	var idx: int = order.find(_weather)
	_weather = order[(idx + 1) % order.size()]
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:rain_mausoleum", "weather", _weather)
	if _weather == "sun":
		stage.play_sfx("deacon_steam_hiss", pos)
	else:
		stage.play_sfx("weather_shift_" + _weather, _wheel_pos)


func _read_weather() -> String:
	if Lx.vars != null:
		var reg_id: String = str(world_ctx.get("current_region_id")) if (world_ctx != null and is_instance_valid(world_ctx) and world_ctx.get("current_region_id") != null) else ""
		var wv: Variant = Lx.vars.resolve_var("weather", island_id, reg_id, "")
		var ws: String = str(wv).strip_edges().to_lower()
		if ws not in ["sun", "rain", "wind"]:
			ws = str(Lx.vars.get_var("dungeon:rain_mausoleum", "weather", "")).strip_edges().to_lower()
		if ws in ["sun", "rain", "wind"]:
			return ws
	return _weather


func _detect_room_wheel() -> bool:
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "weather_wheel":
				return true
	return false


func _target_urn_radius() -> float:
	if _weather == "wind":
		return 42.0
	if _weather == "sun":
		return 18.0
	return 22.0


func _intact_urn_count() -> int:
	var n: int = 0
	for u_d: Dictionary in _urns:
		if bool(u_d["intact"]):
			n += 1
	return n


func _urn_world_pos(u_d: Dictionary) -> Vector2:
	var a: float = _urn_angle + float(u_d["offset_a"])
	return pos + Vector2(cos(a) * _urn_radius, sin(a) * (_urn_radius * 0.58))


func _build_downpour_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.5)))
	if phase >= 2:
		out.append(corners[2])
	return out


func _body_color() -> Color:
	return (PAL["blue"] if phase >= 2 else PAL["deep"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	# Fallback arena weather wheel indicator when running in generic boss_lab
	if not _has_room_wheel:
		var wp: Vector2 = (_wheel_pos - pos).round()
		var wc: Color = (PAL["gold"] if _weather == "sun" else (PAL["ice"] if _weather == "wind" else PAL["sky"])) as Color
		draw_circle(wp, 10.0, Color(PAL["night"] as Color, 0.82))
		draw_arc(wp, 10.0, 0.0, TAU, 16, wc, 1.5)
		draw_circle(wp, 3.0, wc)

	# Rain-shield shimmer when in RAIN with intact urns
	if _weather == "rain" and _intact_urn_count() > 0 and boss_state != BossState.DEATH:
		var sa: float = 0.25 if is_flash_reduced() else 0.42
		draw_arc(off + Vector2(0.0, -14.0), 18.0, 0.0, TAU, 20, Color(PAL["sky"] as Color, sa), 1.6)

	# Orbiting Porcelain Rain-Urns (wide in WIND, tight in RAIN!)
	if boss_state != BossState.DEATH:
		for u_d: Dictionary in _urns:
			if not bool(u_d["intact"]):
				continue
			var up: Vector2 = (_urn_world_pos(u_d) - pos + Vector2(0.0, -12.0)).round()
			draw_circle(up, 5.0, PAL["night"] as Color)
			draw_circle(up, 4.0, (PAL["cream"] if float(u_d["flash_t"]) > 0.0 else PAL["sky"]) as Color)
			draw_rect(Rect2(up + Vector2(-3.0, -5.0), Vector2(6.0, 2.0)), PAL["gold"] as Color)
			if _weather == "wind":
				draw_arc(up, 7.0, 0.0, TAU, 12, PAL["ice"] as Color, 1.0)

	# Comedy beat in SUN: fanning steam puffs!
	if _weather == "sun" and boss_state != BossState.DEATH:
		var fan_x: float = sin(anim_t * 18.0) * 6.0
		draw_line(off + Vector2(10.0, -16.0), off + Vector2(14.0 + fan_x, -26.0), PAL["cream"] as Color, 1.4)

	# Death steam puffs
	for st: Dictionary in _death_steam:
		var sp: Vector2 = ((st["pos"] as Vector2) - pos).round()
		draw_circle(sp, 3.2, Color(PAL["ice"] as Color, 0.65))
		draw_circle(sp, 1.5, PAL["cream"] as Color)
