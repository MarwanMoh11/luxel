class_name LxGulletLampreyBoss
extends LxBossBase
## Island 2 Set-Piece Boss: THE GULLET LAMPREY (`gullet_lamprey`, `leviathan_r4`).
## Segmented 6-part blind whale-belly lamprey coiled around the Leviathan's glowing Heart-Buoy.
## - 3 swallowed Ship-Lanterns surround the basin: lighting all 3 (lantern proximity, thrown lantern,
##   or bolts nearby) flashes the Heart-Buoy GOLD -> 2.4s belly-up stun + 1.55x punish!
## - 8s Whale Heartbeat current (`LxFields`) pulses circular flow (reversing in P2!).
## - Shooting the open glowing maw during Lamp-Snuff Lunge tell deals 1.5x & heavy stagger.
## - P2 (50%): uncoils into counter-orbit, floods outer rib pockets (reverted cleanly on retry!),
##   reverses heartbeat current, and unlocks Coil Sweep!

const HEARTBEAT_PERIOD_S: float = 8.0

var _aim_dir: Vector2 = Vector2.LEFT
var _lunge_dir: Vector2 = Vector2.LEFT
var _orbit_ang: float = 0.0
var _orbit_sign: float = 1.0
var _beat_t: float = 0.0
var _heart_flash_t: float = 0.0
var _lamps: Array[Dictionary] = [] # {pos, lit, lit_t}
var _beat_field: _BellyHeartbeatField = null


class _BellyHeartbeatField:
	extends RefCounted
	var active: bool = true
	var center: Vector2 = Vector2.ZERO
	var swirl_sign: float = 1.0
	var pulse_scale: float = 0.6
	func is_field_active() -> bool:
		return active
	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active:
			return Vector2.ZERO
		var rel: Vector2 = p - center
		var d: float = rel.length()
		if d < 10.0 or d > 165.0:
			return Vector2.ZERO
		var tang := Vector2(-rel.y, rel.x) / d * swirl_sign
		var mult: float = 0.90 if what in ["bolt", "lantern"] else (0.24 if what == "wick" else 0.30)
		return tang * (62.0 * pulse_scale * mult)


func _init() -> void:
	super._init()
	kind = "gullet_lamprey"
	boss_id = "gullet_lamprey"
	boss_name_key = "BOSS_LAMPREY"
	island_id = 2
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island2_boss_p1"
	music_p2_cue = "island2_boss_p2"
	max_hp = 66.0
	hp = 66.0
	body_radius = 11.0
	move_speed = 46.0
	stagger_threshold = 12.5
	stagger_duration = 2.00
	punish_dmg_mult = 1.38
	post_recover_cd = 0.30
	shard_drop = 22
	intro_duration = 0.70
	phase_shift_duration = 0.75
	death_duration = 2.2


func _exit_tree() -> void:
	_unregister_field()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Peristaltic Ring (expanding rose waves + staggered gap ring)
	register_attack("peristaltic_ring", {
		"weight": 1.25, "tell": 0.60, "commit": 0.36, "recover": 1.10, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 52.0, last_tell_duration, 0.0, "rose", "coral")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.06, 1.0, "rose", "gold")
			stage.play_sfx("gastric_surge", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 14 if phase >= 2 else 11, 118.0, gap_a + 0.45, 0.72, {"color": "rose", "source": "lamprey_peristalsis", "field_scale": 0.85})
			patterns.emit_fan(pos, Vector2.from_angle(gap_a), 3, 0.45, 138.0, {"color": "lime", "source": "lamprey_oil", "field_scale": 0.8})
			stage.shake(0.16)
			stage.play_sfx("gastric_surge", pos),
	})

	# Attack 2: Lamp-Snuff Lunge (lunges at nearest lit ship-lantern or Wick — shoot open maw for 1.5x!)
	register_attack("lamp_snuff_lunge", {
		"weight": 1.25, "tell": 0.55, "commit": 0.34, "recover": 1.15, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var snuff_tgt: Vector2 = _pick_lit_lamp_or(tgt)
			_lunge_dir = (snuff_tgt - pos).normalized() if snuff_tgt.distance_to(pos) > 2.0 else Vector2.from_angle(facing)
			ground.warn_lane(pos, clamp_to_arena(pos + _lunge_dir * 136.0), 12.0, last_tell_duration, 1.0, "coral", "rose")
			stage.play_sfx("lamprey_hiss", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _lunge_dir, 5 if phase >= 2 else 3, 0.65, 148.0, {"color": "coral", "source": "lamprey_maw_spit", "field_scale": 0.75})
			stage.shake(0.16)
			stage.play_sfx("lamprey_hiss", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_lunge_dir * 142.0 * dt, true)
			check_contact_damage(body_radius + 10.0, _lunge_dir, 1.0, "lamprey_lunge")
			for lm: Dictionary in _lamps:
				if bool(lm["lit"]) and pos.distance_to(lm["pos"] as Vector2) <= 22.0:
					lm["lit"] = false
					lm["lit_t"] = 0.0,
	})

	# Attack 3: Gastric Surge (perimeter rain + trailing oil-sac puddles so zero safe spots!)
	register_attack("gastric_surge", {
		"weight": 1.15, "tell": 0.56, "commit": 0.32, "recover": 1.05, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration, 24.0, 1.0, "rose", "lime")
			stage.play_sfx("whale_groan_low", arena_rect.get_center()),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_lane(pos, _aim_dir, 4 if phase >= 2 else 3, 146.0, 0.08, {"color": "lime", "source": "lamprey_gastric", "field_scale": 0.9})
			stage.shake(0.14)
			stage.play_sfx("gastric_surge", pos),
	})

	# Attack 4 (P2): Coil Sweep (coral segment sweep + spiral oil barrage!)
	register_attack("coil_sweep", {
		"phases": [2], "weight": 1.60, "tell": 0.64, "commit": 0.48, "recover": 1.30, "cooldown": 1.65,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			ground.warn_sector(pos, _aim_dir.angle() - 1.25, _aim_dir.angle() + 1.25, 96.0, last_tell_duration, 1.0, "coral", "lime")
			stage.play_sfx("lamprey_hiss", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_spiral(pos, 4, 124.0, _aim_dir.angle(), 0.42, 3, 0.14, {"color": "rose", "source": "lamprey_coil", "field_scale": 0.85})
			stage.shake(0.20)
			stage.play_sfx("gastric_surge", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			_orbit_ang = wrapf(_orbit_ang + 2.4 * _orbit_sign * dt, -PI, PI)
			var c: Vector2 = arena_rect.get_center()
			var des: Vector2 = clamp_to_arena(c + Vector2.from_angle(_orbit_ang) * 56.0)
			move_boss((des - pos).limit_length(156.0 * dt), true)
			check_contact_damage(body_radius + 10.0, _aim_dir, 1.0, "lamprey_coil_body"),
	})


func _on_reset_encounter() -> void:
	_unregister_field()
	_orbit_ang = 0.0
	_orbit_sign = 1.0
	_beat_t = 0.0
	_heart_flash_t = 0.0
	_init_ship_lamps()
	_init_lamprey_segments()


func _init_lamprey_segments() -> void:
	segments.setup_follow_chain(6, 13.0, 6.5, 5.5, home, PI)
	for i: int in range(segments.segments.size()):
		segments.segments[i]["color"] = "mauve" if i % 2 == 1 else "dusk"
		segments.segments[i]["glow"] = "lime"


func _init_ship_lamps() -> void:
	var c: Vector2 = arena_rect.get_center()
	var rx: float = minf(arena_rect.size.x * 0.34, 86.0)
	var ry: float = minf(arena_rect.size.y * 0.34, 48.0)
	_lamps = [
		{"pos": clamp_to_arena(c + Vector2(-rx, -ry * 0.65)), "lit": false, "lit_t": 0.0},
		{"pos": clamp_to_arena(c + Vector2(rx, -ry * 0.65)), "lit": false, "lit_t": 0.0},
		{"pos": clamp_to_arena(c + Vector2(0.0, ry)), "lit": false, "lit_t": 0.0},
	]


func _on_engage() -> void:
	_init_ship_lamps()
	if _beat_field == null:
		_beat_field = _BellyHeartbeatField.new()
	_beat_field.center = arena_rect.get_center()
	_beat_field.swirl_sign = _orbit_sign
	_beat_field.active = true
	LxFields.add(_beat_field)
	stage.play_sfx("whale_groan_low", arena_rect.get_center())


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_orbit_sign = -_orbit_sign
		if _beat_field != null:
			_beat_field.swirl_sign = _orbit_sign
		var ts: float = 16.0
		var tx_w: int = int(floorf((arena_rect.position.x + 8.0) / ts))
		var tx_e: int = int(floorf((arena_rect.end.x - 20.0) / ts))
		var ty_n: int = int(floorf((arena_rect.position.y + 8.0) / ts))
		stage.set_tiles(world_ctx, Rect2i(tx_w, ty_n, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(tx_e, ty_n, 1, 2), "water")
		stage.darkness_pulse(0.60, 0.95)
		stage.shake(0.22)
		stage.play_sfx("whale_groan_low", arena_rect.get_center())


func _on_death_start() -> void:
	_unregister_field()
	if Lx.state != null:
		Lx.state.story_flags["lev_parasite_dead"] = true
	stage.play_sfx("heart_buoy_chime", arena_rect.get_center())
	stage.play_sfx("whale_groan_low", arena_rect.get_center())


func _unregister_field() -> void:
	if _beat_field != null:
		_beat_field.active = false
		LxFields.remove(_beat_field)
		_beat_field = null


func on_light(a: Variant, b: Variant = Vector2.ZERO, _source: Variant = "") -> void:
	if boss_state == BossState.DEATH:
		return
	var orig: Vector2 = pos
	var rad: float = 0.0
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2; rad = float(b)
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2 and (b as Vector2) != Vector2.ZERO: orig = b as Vector2
	if rad <= 0.0:
		return
	segments.apply_light(orig, rad, 5.0, false)
	_try_light_lamps(orig, rad * 0.72)


func _try_light_lamps(orig: Vector2, rad: float) -> void:
	var newly: int = 0
	for lm: Dictionary in _lamps:
		if not bool(lm["lit"]) and (lm["pos"] as Vector2).distance_to(orig) <= rad:
			lm["lit"] = true
			lm["lit_t"] = 14.0
			newly += 1
			stage.play_sfx("heart_buoy_chime", lm["pos"] as Vector2)
	if newly > 0:
		var all_on: bool = true
		for lm2: Dictionary in _lamps:
			if not bool(lm2["lit"]):
				all_on = false
				break
		if all_on:
			_trigger_heart_buoy_stun()


func _trigger_heart_buoy_stun() -> void:
	_heart_flash_t = 0.65
	for lm: Dictionary in _lamps:
		lm["lit"] = false
		lm["lit_t"] = 0.0
	stage.light_burst(arena_rect.get_center(), 110.0, 1.5, 0.45)
	stage.shake(0.22)
	stage.play_sfx("heart_buoy_chime", arena_rect.get_center())
	stage.play_sfx("whale_groan_low", arena_rect.get_center())
	add_stagger(stagger_threshold)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_heart_flash_t = maxf(0.0, _heart_flash_t - dt)
	_beat_t += dt
	if _beat_t >= HEARTBEAT_PERIOD_S:
		_beat_t = 0.0
		if phase >= 2:
			_orbit_sign = -_orbit_sign
			if _beat_field != null:
				_beat_field.swirl_sign = _orbit_sign
		stage.play_sfx("whale_groan_low", arena_rect.get_center())
	if _beat_field != null:
		_beat_field.pulse_scale = 0.55 + 0.45 * absf(sin(_beat_t * PI / 4.0))
	for lm: Dictionary in _lamps:
		if bool(lm["lit"]):
			lm["lit_t"] = maxf(0.0, float(lm["lit_t"]) - dt)
			if float(lm["lit_t"]) <= 0.0:
				lm["lit"] = false
	if _is_lantern_out():
		_try_light_lamps(_get_lantern_pos(), 36.0)


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	var c: Vector2 = arena_rect.get_center()
	_orbit_ang = wrapf(_orbit_ang + (1.25 if phase >= 2 else 0.72) * _orbit_sign * dt, -PI, PI)
	var orbit_r: float = 52.0 if phase >= 2 else 36.0
	var des: Vector2 = clamp_to_arena(c + Vector2.from_angle(_orbit_ang) * orbit_r)
	move_boss((des - pos).limit_length(move_speed * dt), true)
	_face_point(target, 3.6, dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	# Shooting glowing open maw during Lamp-Snuff Lunge tell deals 1.5x + heavy stagger!
	if boss_state == BossState.TELL and active_attack_id == "lamp_snuff_lunge":
		add_stagger(2.5)
		return dmg * 1.50
	if hit.is_blue() or hit.source == LxHit.SOURCE_BEAM or hit.cracks_armour:
		return dmg * 1.35
	# Tough blubber dampens off-window body bolts slightly so Heart-Buoy/maw openings shine
	if not is_punishable() and hit.source == LxHit.SOURCE_BOLT and not hit.pierce:
		return dmg * 0.55
	return dmg


func _pick_lit_lamp_or(fallback: Vector2) -> Vector2:
	for lm: Dictionary in _lamps:
		if bool(lm["lit"]):
			return lm["pos"] as Vector2
	return fallback


func _perimeter_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
		out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.5)))
	return out


func _body_color() -> Color:
	return PAL["mauve"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	# 1. Whale's glowing Heart-Buoy at arena center
	var hc: Vector2 = (arena_rect.get_center() - pos + off).round()
	var pulse: float = 1.0 + sin(_beat_t * TAU / 4.0) * 0.16
	draw_circle(hc, 11.0 * pulse, Color(PAL["gold" if _heart_flash_t > 0.0 else "rose"] as Color, 0.35))
	draw_arc(hc, 9.0 * pulse, 0.0, TAU, 16, PAL["cream" if _heart_flash_t > 0.0 else "gold"] as Color, 1.5)
	draw_circle(hc, 4.0, PAL["cream"] as Color)
	# 2. The 3 Swallowed Ship-Lanterns
	for lm: Dictionary in _lamps:
		var lp: Vector2 = ((lm["pos"] as Vector2) - pos + off).round()
		var is_lit: bool = bool(lm["lit"])
		draw_circle(lp, 6.5, PAL["night"] as Color)
		draw_circle(lp, 4.5, PAL["gold" if is_lit else "dusk"] as Color)
		if is_lit:
			draw_arc(lp, 9.5, 0.0, TAU, 12, PAL["cream"] as Color, 1.2)
			draw_line(lp, hc, Color(PAL["gold"] as Color, 0.55), 1.2)
	if _heart_flash_t > 0.0 and not is_flash_reduced():
		var u: float = 1.0 - clampf(_heart_flash_t / 0.65, 0.0, 1.0)
		draw_arc(hc, lerpf(12.0, 92.0, u), 0.0, TAU, 24, PAL["gold"] as Color, 2.2)
