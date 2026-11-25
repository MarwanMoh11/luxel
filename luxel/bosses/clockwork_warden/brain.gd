class_name LxClockworkWardenBoss
extends LxBossBase
## Starfall Observatory Mini-Boss (Island 5, orrery_r6): Clockwork Warden (Bible §4.6).
## 2 phases on LxBossBase. Front brass shield & escapement armour reduce straight plain bolts
## outside punish windows (gold armour glint + reduced chip); curving shots through the central
## LxFields polarity well or flanking his rear astrolabe core deals 1.35x (1.65x under True Lens!).
## Island 5 rule: central switchable LxFields polarity well bends BOTH his star-beam fans and
## Wick's bolts; P2 cracks outer gear-rim corners, spawns escapement pillars, and adds Escapement Flip!

signal beam_bolt_fired(origin: Vector2, dir: Vector2, source: LxEnemyBrain)

class WardenWellField:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 64.0
	var strength: float = 480.0
	var is_push: bool = false
	var active: bool = true

	func is_field_active() -> bool:
		return active

	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active:
			return Vector2.ZERO
		var delta: Vector2 = pos - p
		var d2: float = delta.length_squared()
		if d2 >= radius * radius or d2 <= 0.0001:
			return Vector2.ZERO
		var dist: float = sqrt(d2)
		var u: float = clampf(1.0 - dist / radius, 0.0, 1.0)
		var falloff: float = (0.35 + 0.65 * u) * (1.0 - exp(-dist / 10.0))
		var mult: float = 1.20 if what in ["bolt", "beam"] else (0.90 if what == "lantern" else (0.0 if what == "wick" else 0.25))
		var dn: Vector2 = delta / dist
		if is_push:
			dn = -dn
		return dn * (strength * falloff * mult)


const FRONT_SHIELD_HALF: float = 1.02
const FAN_SPREAD: float = 0.56

var _well: WardenWellField = null
var _well_reg: bool = false
var _well_anim: float = 0.0
var _rail_spin: float = 1.0
var _lens_pause_t: float = 0.0
var _lens_highlight_t: float = 0.0
var _fan_dir: Vector2 = Vector2.RIGHT
var _fan_second_done: bool = false
var _slide_dir: Vector2 = Vector2.RIGHT
var _clank_sfx_cd: float = 0.0


func _init() -> void:
	super._init()
	kind = "clockwork_warden"
	boss_id = "clockwork_warden"
	boss_name_key = "MINIBOSS_5"
	island_id = 5
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island5_boss_p1"
	music_p2_cue = "island5_boss_p2"
	max_hp = 50.0
	hp = 50.0
	body_radius = 9.0
	move_speed = 38.0
	stagger_threshold = 10.5
	stagger_duration = 1.60
	punish_dmg_mult = 1.30
	post_recover_cd = 0.32
	shard_drop = 26
	death_duration = 2.0


func _exit_tree() -> void:
	_unregister_well()


func _configure_boss(_spec: Dictionary) -> void:
	if world_ctx != null and str(world_ctx.get("current_region_id")) == "orrery_r6":
		arena_rect = Rect2(160.0, 64.0, 208.0, 104.0)
	configure_phases([0.52])

	# Attack 1: Brass Beam Fan — curved 3-ray fan (P2: Reverse-Gear Double-Fan!)
	register_attack("brass_beam_fan", {
		"weight": 1.25, "tell": 0.54, "commit": 0.48, "recover": 1.15, "cooldown": 1.35,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_fan_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _fan_dir.angle()
			_fan_second_done = false
			for idx: int in [-1, 0, 1]:
				var rd: Vector2 = _fan_dir.rotated(float(idx) * 0.28)
				ground.warn_lane(pos, pos + rd * 148.0, 7.0, last_tell_duration, 0.0, "sky", "gold")
			stage.play_sfx("orrery_bell_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _fan_dir, 5 if phase >= 2 else 3, FAN_SPREAD, 128.0, {"color": "gold", "source": "brass_beam", "field_scale": 1.05})
			beam_bolt_fired.emit(pos, _fan_dir, self)
			stage.shake(0.14)
			stage.play_sfx("orrery_beam_bolt", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			if phase >= 2 and not _fan_second_done and el >= 0.26:
				_fan_second_done = true
				_rail_spin = -_rail_spin
				var rev_dir: Vector2 = _fan_dir.rotated(_rail_spin * 0.22)
				patterns.emit_fan(pos, rev_dir, 3, FAN_SPREAD, 124.0, {"color": "ice", "source": "brass_beam_rev", "field_scale": 1.10, "damage": 0.5})
				stage.play_sfx("orrery_beam_bolt", pos),
	})

	# Attack 2: Gear Ring Discharge — expanding curved gear-tooth shockwave + targeted star-spark
	register_attack("gear_ring_discharge", {
		"weight": 1.20, "tell": 0.54, "commit": 0.36, "recover": 1.02, "cooldown": 1.40,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 64.0, last_tell_duration, 0.0, "sky", "gold")
			ground.warn_ring(tgt, 22.0, last_tell_duration + 0.05, 0.5, "apricot", "gold")
			stage.play_sfx("orrery_bell_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 12 if phase >= 2 else 10, 118.0, gap_a + 0.40, 0.72, {"color": "gold", "source": "gear_ring", "field_scale": 0.90})
			stage.shake(0.18)
			stage.play_sfx("eclipse_wave", pos),
	})

	# Attack 3: Pendulum Rail Sweep — rail slide + aimed star-lance + perimeter rain pods
	register_attack("pendulum_rail_sweep", {
		"weight": 1.15, "tell": 0.52, "commit": 0.38, "recover": 1.00, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_slide_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _slide_dir.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + _slide_dir * 86.0), 10.0, last_tell_duration, 0.0, "apricot", "gold")
			var drops: Array[Vector2] = _build_star_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 21.0, 1.0, "sky", "gold")
			stage.play_sfx("orrery_bell_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_lane(pos, _slide_dir, 3, 152.0, 0.08, {"color": "ice", "source": "rail_lance", "field_scale": 1.0})
			stage.shake(0.14)
			stage.play_sfx("orrery_beam_bolt", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_slide_dir * 125.0 * dt, false)
			check_contact_damage(24.0, _slide_dir, 1.0, "rail_sweep"),
	})

	# Attack 4 (Phase 2): Escapement Flip — flips central polarity well & sweeps curved 5-ray fan!
	register_attack("escapement_flip", {
		"phases": [2], "weight": 1.65, "tell": 0.60, "commit": 0.42, "recover": 1.12, "cooldown": 1.55,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_flip_well()
			_fan_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _fan_dir.angle()
			ground.warn_ring(arena_rect.get_center(), 46.0, last_tell_duration, 0.0, "ice", "gold")
			ground.warn_sector(pos, _fan_dir.angle() - 0.85, _fan_dir.angle() + 0.85, 110.0, last_tell_duration, 0.0, "gold", "coral")
			stage.play_sfx("clockwork_chime", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _fan_dir, 5, 0.98, 128.0, {"color": "gold", "source": "escapement_fan", "field_scale": 1.25, "damage": 0.5})
			patterns.emit_orbit(pos, 3, 42.0, 2.0 * _rail_spin, 1.9, {"color": "ice", "source": "escapement_gear", "damage": 0.5})
			stage.shake(0.20)
			stage.play_sfx("eclipse_wave", pos),
	})


func _on_reset_encounter() -> void:
	_unregister_well()
	_rail_spin = 1.0
	_lens_pause_t = 0.0
	_lens_highlight_t = 0.0
	_well_anim = 0.0
	_clank_sfx_cd = 0.0


func _on_engage() -> void:
	_ensure_well()
	props.spawn_bell(arena_rect.get_center(), func(_p: Dictionary) -> void: _flip_well(), "warden_well_bell")


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_rail_spin = -_rail_spin
		_flip_well()
		var c: Vector2 = arena_rect.get_center()
		_carve_safe_tile_near(c + Vector2(-88.0, -44.0), "pit")
		_carve_safe_tile_near(c + Vector2(88.0, 44.0), "pit")
		props.spawn_pillar(clamp_to_arena(c + Vector2(-54.0, 24.0)), 4.0, "warden_gear_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(54.0, -24.0)), 4.0, "warden_gear_e")
		stage.darkness_pulse(0.60, 0.95)
		stage.shake(0.24)
		stage.play_sfx("clockwork_warden_phase2", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	_lens_pause_t = maxf(0.0, _lens_pause_t - dt)
	_lens_highlight_t = maxf(0.0, _lens_highlight_t - dt)
	_well_anim = fposmod(_well_anim + dt * (0.45 if is_flash_reduced() else 1.0), 1.0)
	if _well != null:
		_well.pos = arena_rect.get_center()


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	if _lens_pause_t > 0.0:
		return
	super._step_boss_reposition(dt, target)


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: String = "") -> void:
	var orig: Vector2 = Vector2.ZERO
	var rad: float = 0.0
	var src: String = source
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2
		rad = float(b)
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2:
			orig = b as Vector2
		elif b is String and src.is_empty():
			src = str(b)
	if boss_state == BossState.DEATH or src != "lens" or rad <= 0.0:
		return
	if orig == Vector2.ZERO or pos.distance_to(orig) <= rad + body_radius:
		_lens_pause_t = maxf(_lens_pause_t, 1.55)
		_lens_highlight_t = maxf(_lens_highlight_t, 2.8)
		patterns.freeze_bolts_in_radius(pos, 96.0, 1.2, "lens")
		stage.play_sfx("lens_reveal", pos)


func take_hit(hit: LxHit) -> int:
	if not engaged and boss_state != BossState.DEATH and hit != null:
		if world_ctx != null and str(world_ctx.get("current_region_id")) == "orrery_r6":
			if _get_wick_pos().distance_to(pos) <= 92.0:
				engage()
	return super.take_hit(hit)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var curve_deg: float = float(hit.get("curve_angle_deg")) if hit.get("curve_angle_deg") != null else 0.0
	var is_curved: bool = curve_deg >= 15.0
	var heavy: bool = src in [LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE] \
			or bool(h["pierce"]) or bool(h["cracks_armour"])

	var rel: Vector2 = orig - pos
	var front_hit: bool = rel.length() > 0.1 and absf(angle_difference(facing, rel.angle())) < FRONT_SHIELD_HALF
	var rear_hit: bool = rel.length() > 0.1 and absf(angle_difference(facing, rel.angle())) > 2.0
	var lens_mult: float = 1.35 if _lens_highlight_t > 0.0 else 1.0

	if boss_state == BossState.STAGGER:
		return dmg * (1.75 if heavy else 1.45) * lens_mult
	if is_curved or rear_hit:
		return dmg * 1.35 * lens_mult
	if is_punishable():
		return dmg * (1.65 if heavy else 1.0) * lens_mult
	if heavy:
		return dmg * 1.55

	# Front brass shield & spinning gear carapace outside punish windows: reduced chip + gold glint!
	clank_t = 0.12
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28
		stage.play_sfx("crystal_clank", pos)
	return dmg * (0.28 if front_hit else 0.36)


func _on_death_start() -> void:
	_unregister_well()
	stage.revert_tiles(world_ctx)
	stage.play_sfx("clockwork_warden_phase2", pos)


func _ensure_well() -> void:
	if _well == null:
		_well = WardenWellField.new()
	_well.pos = arena_rect.get_center()
	_well.active = true
	if not _well_reg:
		LxFields.add(_well)
		_well_reg = true


func _unregister_well() -> void:
	if _well != null:
		_well.active = false
		if _well_reg:
			LxFields.remove(_well)
			_well_reg = false


func _flip_well() -> void:
	_ensure_well()
	_well.is_push = not _well.is_push
	stage.light_burst(_well.pos, 64.0, 1.25, 0.30)
	stage.play_sfx("clockwork_chime", _well.pos)


func _build_star_targets(tgt: Vector2) -> Array[Vector2]:
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
		out.append(corners[2])
	return out


func _carve_safe_tile_near(world_pt: Vector2, tile_kind: String) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("tile_at"):
		return
	var p: Vector2 = clamp_to_arena(world_pt)
	var tx: int = int(floorf(p.x / 16.0))
	var ty: int = int(floorf(p.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if str(world_ctx.call("tile_at", cp)) == "ground" and cp.distance_to(home) > 30.0:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), tile_kind)


func _body_color() -> Color:
	return (PAL["plum"] if phase >= 2 else PAL["deep"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Central LxFields polarity well indicator
	if _well != null and _well.active:
		var wc: Vector2 = (_well.pos - pos).round()
		var wcol: Color = (PAL["gold"] if _well.is_push else PAL["sky"]) as Color
		var r_wave: float = lerpf(12.0, _well.radius * 0.72, _well_anim) if _well.is_push else lerpf(_well.radius * 0.72, 12.0, _well_anim)
		draw_arc(wc, _well.radius * 0.72, 0.0, TAU, 24, Color(wcol, 0.25), 1.0)
		draw_arc(wc, r_wave, 0.0, TAU, 20, Color(wcol, 0.65), 1.4)
		draw_circle(wc, 4.0, wcol)

	# Front brass shield arc + armour glint
	var fwd: Vector2 = Vector2.from_angle(facing)
	var shield_col: Color = (PAL["cream"] if clank_t > 0.0 else PAL["gold"]) as Color
	draw_arc(c, body_radius + 3.5, facing - FRONT_SHIELD_HALF * 0.85, facing + FRONT_SHIELD_HALF * 0.85, 14, shield_col, 2.2 if clank_t > 0.0 else 1.6)
	# Rear astrolabe weak core (pulses bright gold/ice under True Lens!)
	var rear_p: Vector2 = (c - fwd * (body_radius + 1.5)).round()
	draw_circle(rear_p, 3.2 if _lens_highlight_t > 0.0 else 2.2, (PAL["cream"] if _lens_highlight_t > 0.0 else PAL["coral"]) as Color)
	if _lens_highlight_t > 0.0:
		draw_arc(rear_p, 6.0, 0.0, TAU, 12, PAL["ice"] as Color, 1.4)

	if clank_t > 0.0:
		draw_arc(c, body_radius + 6.0, facing - 1.0, facing + 1.0, 14, PAL["cream"] as Color, 2.0)
	elif is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 20, PAL["gold"] as Color, 1.6)
