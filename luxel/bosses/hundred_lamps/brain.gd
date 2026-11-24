class_name LxHundredLampsBoss
extends LxBossBase
## Island 3 Boss A: Hundred Lamps (underroot_r11).
## 10-segment articulated centipede (LxBossSegments) using luxel/art/bosses/hundred_lamps.*.
## Core Island 3 Rule (Inverted Light Armor):
##  - Segments exposed to Wick's lantern ignite into thorny amber armor (reduced damage).
##  - ONLY DARK segments take full/bonus damage! Throw lantern behind the 4 shadow root-pillars
##    (or lure segments across the P2 sunken Shadow-Trench) to cast shadow onto its belly!
## Attacks (3+ per phase):
##  1. Rolling Lantern Wave: tail-to-head amber spark bursts; strike dark rings behind the wave!
##  2. Coil Constriction: closing ring + boomerang sparks with 1 clear dark dash-gap!
##  3. Tunnel Dive & Light-Eggs: burrows between wall grates laying 1-2 destructible Light-Eggs
##     that flood the arena with light until snuffed by Bolt/Beam (snuffing darkens & staggers!).

const SEG_COUNT: int = 10
const SEG_SPACING: float = 12.0
const EGG_LIGHT_R: float = 68.0
const EGG_HP: float = 1.0

var _slither_dir: Vector2 = Vector2.LEFT
var _coil_ang: float = 0.0
var _wave_idx: int = 9
var _wave_step_t: float = 0.0
var _light_eggs: Array[Dictionary] = []
var _trench_rect: Rect2 = Rect2()
var _dive_target: Vector2 = Vector2.ZERO
var _dive_erupted: bool = false
var _last_light_pos: Vector2 = Vector2(-9999.0, -9999.0)
var _last_light_r: float = 0.0
var _shadow_darken_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "hundred_lamps"
	boss_id = "hundred_lamps"
	boss_name_key = "ISL3_BOSS_CENTIPEDE"
	island_id = 3
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island3_boss_p1"
	music_p2_cue = "island3_boss_p2"
	max_hp = 74.0
	hp = 74.0
	body_radius = 11.5
	move_speed = 44.0
	stagger_threshold = 13.0
	stagger_duration = 1.65
	post_stagger_immunity = 3.8
	punish_dmg_mult = 1.40
	post_recover_cd = 0.30
	shard_drop = 32
	death_duration = 2.3


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Rolling Lantern Wave (tell 0.52s, commit 1.15s, recover 1.05s)
	register_attack("rolling_lantern_wave", {
		"weight": 1.30, "tell": 0.52, "commit": 1.15, "recover": 1.05, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_slither_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			_wave_idx = segments.segments.size() - 1
			_wave_step_t = 0.0
			var end_p: Vector2 = clamp_to_arena(pos + _slither_dir * 134.0)
			ground.warn_lane(pos, end_p, 11.0, last_tell_duration, 0.0, "gold", "coral")
			stage.play_sfx("centipede_chime_step", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _slither_dir
			patterns.emit_fan(pos, aim, 5 if phase >= 2 else 3, 0.62, 148.0 if phase >= 3 else 134.0, {"color": "gold", "source": "centipede_wave"})
			stage.play_sfx("centipede_wave", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			var spd: float = 168.0 if phase >= 2 else 142.0
			var prev_p: Vector2 = pos
			move_boss(_slither_dir * spd * dt, true)
			if pos.distance_to(prev_p) < spd * dt * 0.35:
				_slither_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else -_slither_dir
			check_contact_damage(16.0, _slither_dir, 1.0, "centipede_wave")
			# Sequential amber spark burst rolling tail -> head; segments behind blink DARK!
			_wave_step_t -= dt
			if _wave_step_t <= 0.0 and _wave_idx >= 0 and _wave_idx < segments.segments.size():
				_wave_step_t = 0.11
				var seg: Dictionary = segments.segments[_wave_idx]
				seg["lit"] = true
				seg["lit_t"] = 0.85
				seg["armoured"] = true
				if _wave_idx + 1 < segments.segments.size():
					segments.segments[_wave_idx + 1]["lit"] = false
					segments.segments[_wave_idx + 1]["armoured"] = false
				if _wave_idx % 2 == 0:
					var sp: Vector2 = seg["pos"] as Vector2
					var to_t: Vector2 = (tgt - sp).normalized() if tgt.distance_to(sp) > 1.0 else _slither_dir
					patterns.emit_lane(sp, to_t, 1, 138.0, 0.05, {"color": "apricot", "source": "centipede_spark"})
				_wave_idx -= 1,
	})

	# Attack 2: Coil Constriction (tell 0.62s, commit 0.70s, recover 1.25s)
	register_attack("coil_constriction", {
		"weight": 1.20, "tell": 0.62, "commit": 0.70, "recover": 1.25, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_coil_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else facing
			ground.warn_ring(pos, 54.0, last_tell_duration, 0.0, "coral", "gold")
			var p_pts: Array[Vector2] = [clamp_to_arena(tgt), clamp_to_arena(tgt + Vector2(26.0, 0.0))]
			patterns.emit_pillars(p_pts, last_tell_duration + 0.08, 20.0, 0.45, 1.0, "coral")
			stage.play_sfx("centipede_chime_step", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(_coil_ang)
			var cnt: int = 14 if phase >= 3 else (12 if phase >= 2 else 10)
			patterns.emit_gap_ring(pos, cnt, 132.0 if phase >= 2 else 118.0, aim.angle() + 0.55, 0.68, {"color": "coral", "source": "centipede_coil"})
			patterns.emit_boomerang(pos, aim, 148.0, 0.65, 0.52, {"color": "gold", "source": "centipede_coil"})
			if phase >= 2:
				patterns.emit_orbit(pos, 4, 40.0, 2.3, 1.9, {"color": "gold", "source": "centipede_orbit"})
			stage.shake(0.16)
			stage.play_sfx("centipede_wave", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			var ang: float = _coil_ang + elapsed * 3.8
			var orbit_step: Vector2 = Vector2.from_angle(ang + PI * 0.5) * 90.0 * dt
			move_boss(orbit_step, true),
	})

	# Attack 3: Tunnel Dive & Light-Eggs (tell 0.55s, commit 0.90s, recover 1.15s)
	register_attack("tunnel_dive_eggs", {
		"weight": 1.15, "tell": 0.55, "commit": 0.90, "recover": 1.15, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_dive_erupted = false
			var inset: Rect2 = arena_rect.grow(-24.0)
			var c: Vector2 = arena_rect.get_center()
			_dive_target = clamp_to_arena(c + (tgt - c).limit_length(54.0))
			ground.warn_ring(_dive_target, 28.0, last_tell_duration + 0.25, 1.0, "coral", "gold", 0.35)
			var rain_pts: Array[Vector2] = [clamp_to_arena(tgt), inset.position, Vector2(inset.end.x, inset.end.y)]
			patterns.emit_rain(ground, rain_pts, last_tell_duration, 20.0, 1.0, "gold", "coral")
			stage.play_sfx("centipede_burrow", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.14)
			stage.play_sfx("centipede_burrow", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, elapsed: float) -> void:
			var to_d: Vector2 = _dive_target - pos
			if to_d.length() > 4.0:
				move_boss(to_d.normalized() * 195.0 * dt, true)
			if not _dive_erupted and elapsed >= 0.32:
				_dive_erupted = true
				_spawn_light_eggs(2 if phase >= 2 else 1)
				var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
				patterns.emit_fan(pos, aim, 5 if phase >= 3 else 3, 0.72, 136.0, {"color": "apricot", "source": "centipede_erupt"})
				stage.light_burst(pos, 86.0, 1.35, 0.32),
	})


func _on_reset_encounter() -> void:
	_light_eggs.clear()
	_trench_rect = Rect2()
	_shadow_darken_t = 0.0
	_last_light_pos = Vector2(-9999.0, -9999.0)
	_last_light_r = 0.0
	segments.setup_follow_chain(SEG_COUNT, SEG_SPACING, 6.5, 8.0, home, PI)
	for s: Dictionary in segments.segments:
		s["color"] = "plum" if int(s["index"]) > 0 else "dusk"
		s["glow"] = "gold"
		s["lit"] = false
		s["armoured"] = false
	# 4 thick shadow root-pillars for throwing lantern behind to cast shadow!
	var c: Vector2 = arena_rect.get_center()
	props.spawn_pillar(c + Vector2(-68.0, -32.0), 18.0, "hl_pillar_nw")
	props.spawn_pillar(c + Vector2(68.0, -32.0), 18.0, "hl_pillar_ne")
	props.spawn_pillar(c + Vector2(-68.0, 32.0), 18.0, "hl_pillar_sw")
	props.spawn_pillar(c + Vector2(68.0, 32.0), 18.0, "hl_pillar_se")


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# P2 Arena Change: crack center floor into a sunken Shadow-Trench darkening crossing segments!
		_trench_rect = Rect2(c + Vector2(-52.0, -14.0), Vector2(104.0, 28.0))
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 1), "pit")
		stage.darkness_pulse(0.68, 1.1)
		stage.shake(0.22)
		stage.play_sfx("centipede_burrow", pos)
	elif new_phase == 3:
		_spawn_light_eggs(2)
		stage.darkness_pulse(0.75, 1.2)
		stage.shake(0.26)
		stage.play_sfx("centipede_wave", pos)


func on_light(a: Variant, b: Variant = Vector2.ZERO, _source: Variant = "") -> void:
	if boss_state == BossState.DEATH:
		return
	var orig: Vector2 = pos
	var rad: float = 0.0
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2; rad = float(b)
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2 and (b as Vector2) != Vector2.ZERO:
			orig = b as Vector2
	if rad <= 0.0:
		return
	_last_light_pos = orig
	_last_light_r = rad


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_shadow_darken_t = maxf(0.0, _shadow_darken_t - dt)
	_tick_light_eggs(dt)
	_update_segment_lighting()


func _update_segment_lighting() -> void:
	var pillar_pts: Array[Vector2] = props.get_positions("pillar")
	for s: Dictionary in segments.segments:
		if not bool(s["alive"]):
			continue
		var sp: Vector2 = s["pos"] as Vector2
		# Center Shadow-Trench (P2+) or egg-snuff shadow blast darkens segments unconditionally!
		if _shadow_darken_t > 0.0 or (_trench_rect.has_area() and _trench_rect.has_point(sp)):
			s["lit"] = false
			s["armoured"] = false
			continue
		var lit_now: bool = float(s["lit_t"]) > 0.0
		# Check lantern light (blocked by any shadow pillar -> pillar shadow-casting!)
		if not lit_now and _last_light_r > 0.0 and sp.distance_to(_last_light_pos) <= _last_light_r + float(s["radius"]):
			if not _blocked_by_pillar(_last_light_pos, sp, pillar_pts):
				lit_now = true
		# Check active glowing Light-Eggs
		if not lit_now:
			for egg: Dictionary in _light_eggs:
				if sp.distance_to(egg["pos"] as Vector2) <= EGG_LIGHT_R:
					lit_now = true
					break
		s["lit"] = lit_now
		s["armoured"] = lit_now


func _blocked_by_pillar(light_p: Vector2, seg_p: Vector2, pillar_pts: Array[Vector2]) -> bool:
	for pp: Vector2 in pillar_pts:
		if light_p.distance_to(pp) < 6.0 or seg_p.distance_to(pp) < 6.0:
			continue
		if Geometry2D.get_closest_point_to_segment(pp, light_p, seg_p).distance_to(pp) <= 13.0:
			return true
	return false


func _spawn_light_eggs(count: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	var spots: Array[Vector2] = [c + Vector2(-44.0, -34.0), c + Vector2(44.0, 34.0)]
	for i: int in range(mini(count, spots.size())):
		if _light_eggs.size() >= 2:
			_light_eggs.pop_front()
		_light_eggs.append({"pos": clamp_to_arena(spots[i]), "hp": EGG_HP, "ttl": 9.0, "flash": 0.0})


func _tick_light_eggs(dt: float) -> void:
	if _light_eggs.is_empty():
		return
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var beam_on: bool = wick_node != null and wick_node.move_beam != null and wick_node.move_beam.beam_vis_t > 0.0
	for i: int in range(_light_eggs.size() - 1, -1, -1):
		var egg: Dictionary = _light_eggs[i]
		egg["ttl"] = float(egg["ttl"]) - dt
		egg["flash"] = maxf(0.0, float(egg["flash"]) - dt)
		var ep: Vector2 = egg["pos"] as Vector2
		var snuffed: bool = false
		if wick_node != null:
			for bi: int in range(wick_node.bolts.size() - 1, -1, -1):
				var bv: Variant = wick_node.bolts[bi]
				if bv is Object and (bv.get("pos") as Vector2).distance_to(ep) <= 12.0:
					if not bool(bv.get("is_pierce")):
						wick_node.bolts.remove_at(bi)
					snuffed = true
					break
			if not snuffed and beam_on:
				if Geometry2D.get_closest_point_to_segment(ep, wick_node.move_beam.beam_start, wick_node.move_beam.beam_end).distance_to(ep) <= 13.0:
					snuffed = true
		if snuffed:
			_shadow_darken_t = 2.6
			segments.extinguish_all()
			add_stagger(3.8)
			stage.play_sfx("egg_snuff", ep)
			_light_eggs.remove_at(i)
		elif float(egg["ttl"]) <= 0.0:
			_light_eggs.remove_at(i)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var seg_i: int = segments.find_segment_at(hit.origin + hit.dir * 10.0, 14.0)
	if seg_i < 0:
		seg_i = 0
	var seg_lit: bool = seg_i < segments.segments.size() and bool(segments.segments[seg_i]["lit"])
	# Dark segments take FULL bonus damage; lit segments have thorny amber armor (0.58x chip)
	if boss_state == BossState.STAGGER or boss_state == BossState.RECOVER:
		return dmg * (1.35 if not seg_lit else 0.90)
	if not seg_lit:
		return dmg * 1.28
	if hit.pierce or hit.cracks_armour:
		return dmg * 0.95
	clank_t = 0.09
	return dmg * 0.62


func _on_death_start() -> void:
	_light_eggs.clear()
	segments.extinguish_all()
	stage.shake(0.28)
	stage.darkness_pulse(0.75, 1.4)
	stage.play_sfx("centipede_chime_step", pos)


func _body_color() -> Color:
	return PAL["plum"] as Color


func _draw_boss_extra(_off: Vector2) -> void:
	# Draw P2 sunken Shadow-Trench across arena center
	if _trench_rect.has_area():
		var rl := Rect2((_trench_rect.position - pos).round(), _trench_rect.size.round())
		draw_rect(rl, Color(PAL["void"] as Color, 0.58), true)
		draw_rect(rl, PAL["dusk"] as Color, false, 1.5)
	# Draw active glowing Light-Eggs (shoot to snuff!)
	for egg: Dictionary in _light_eggs:
		var ep: Vector2 = ((egg["pos"] as Vector2) - pos).round()
		draw_circle(ep, EGG_LIGHT_R * 0.42, Color(PAL["gold"] as Color, 0.14))
		draw_circle(ep, 7.0, PAL["night"] as Color)
		draw_circle(ep, 5.5, PAL["gold"] as Color)
		draw_circle(ep + Vector2(-1.5, -1.5), 2.5, PAL["cream"] as Color)
