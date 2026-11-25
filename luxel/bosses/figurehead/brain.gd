class_name LxFigureheadBoss
extends LxBossBase
## Island 2 Dungeon A Boss: THE FIGUREHEAD (`figurehead`, `galleon_r12`).
## Carved gilded oak prow-moth that tears off the galleon bow on a giant iron anchor chain.
## 3 phases ([0.66, 0.33]):
## - P1: Bowsprit Dive, Anchor Chain Whip (cuttable/clampable anchor tether!), Splinter Fan.
## - P2 (66%): Steep 7s deck roll (`dungeon:galleon` `list` + LxFields) floods low edge tiles + Broadside Kegs.
## - P3 (33%): Bow edges splinter narrower (water tiles, cleanly reverted on retry!) + twin anchor flukes!
## Target TTK: 90-150s (calibrated ~105-130s via carved oak prow guard + tether clamp/punish windows).

const FRONT_OAK_HALF: float = 1.02

var _aim_dir: Vector2 = Vector2.LEFT
var _dive_dir: Vector2 = Vector2.LEFT
var _fluke_pos: Vector2 = Vector2.ZERO
var _fluke_clamped_t: float = 0.0
var _roll_t: float = 0.0
var _roll_side: String = "port"
var _roll_field: _FigureheadRollField = null


class _FigureheadRollField:
	extends RefCounted
	var active: bool = true
	var dir_x: float = -1.0
	var strength: float = 74.0
	func is_field_active() -> bool:
		return active
	func field_accel(_p: Vector2, what: String) -> Vector2:
		if what == "bolt" or what == "block":
			return Vector2(dir_x * strength, 0.0)
		return Vector2.ZERO


func _init() -> void:
	super._init()
	kind = "figurehead"
	boss_id = "figurehead"
	boss_name_key = "BOSS_FIGURE"
	island_id = 2
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island2_boss_p1"
	music_p2_cue = "island2_boss_p2"
	max_hp = 98.0
	hp = 98.0
	body_radius = 12.0
	move_speed = 38.0
	stagger_threshold = 13.0
	stagger_duration = 1.80
	punish_dmg_mult = 1.45
	post_recover_cd = 0.36
	shard_drop = 32
	intro_duration = 0.80
	phase_shift_duration = 0.80
	death_duration = 2.4


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Bowsprit Dive (high-speed prow lunge + splinter burst when beak jams in planks!)
	register_attack("bowsprit_dive", {
		"weight": 1.25, "tell": 0.58, "commit": 0.34, "recover": 1.25, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_dive_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, pos + _dive_dir * 124.0, 11.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("figurehead_creak", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _dive_dir, 3, 0.72, 114.0, {"color": "apricot", "source": "figurehead_splinter", "field_scale": 0.6})
			stage.shake(0.16)
			stage.play_sfx("wood_splinter", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_dive_dir * 108.0 * dt, true)
			check_contact_damage(body_radius + 9.0, _dive_dir, 1.0, "figurehead_dive"),
	})

	# Attack 2: Anchor Chain Whip (wide sweeping arc + Ballast Clamp fluke self-stagger!)
	register_attack("anchor_chain_whip", {
		"weight": 1.25, "tell": 0.62, "commit": 0.40, "recover": 1.25, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_sector(pos, _aim_dir.angle() - 1.05, _aim_dir.angle() + 1.05, 92.0, last_tell_duration, 0.0, "sky", "gold")
			ground.warn_ring(_fluke_pos, 20.0, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("chain_whip", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			# Ballast Clamp payoff: if lantern is hanging on her anchor fluke, her yank slams HER nose-first!
			if _fluke_clamped_t > 0.0:
				_fluke_clamped_t = 0.0
				add_stagger(stagger_threshold)
				stage.shake(0.24)
				stage.play_sfx("wood_splinter", pos)
				return
			patterns.emit_gap_ring(pos, 8, 94.0, _aim_dir.angle() + PI * 0.55, 1.08, {"color": "ice", "source": "figurehead_chain_ring", "field_scale": 0.5})
			patterns.emit_fan(pos, _aim_dir, 3, 0.78, 110.0, {"color": "gold", "source": "figurehead_whip", "field_scale": 0.6})
			stage.shake(0.18)
			stage.play_sfx("anchor_clang", pos),
	})

	# Attack 3: Splinter Fan (pressures Wick + nearest corners so no perimeter safe spot!)
	register_attack("splinter_fan", {
		"weight": 1.15, "tell": 0.60, "commit": 0.36, "recover": 1.15, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			for ang_o: float in [-0.36, 0.0, 0.36]:
				var d: Vector2 = _aim_dir.rotated(ang_o)
				ground.warn_lane(pos, pos + d * 136.0, 8.0, last_tell_duration, 0.0, "apricot", "gold")
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration, 21.0, 1.0, "coral", "gold")
			stage.play_sfx("figurehead_creak", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 0.92, 132.0, {"color": "gold", "source": "figurehead_fan", "field_scale": 0.8})
			stage.shake(0.15)
			stage.play_sfx("wood_splinter", pos),
	})

	# Attack 4 (P2 & P3): Broadside Kegs (rolling explosive barrels across tilted deck!)
	register_attack("broadside_kegs", {
		"phases": [2, 3], "weight": 1.35, "tell": 0.65, "commit": 0.45, "recover": 1.25, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _perimeter_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 23.0, 1.0, "coral", "gold")
			stage.play_sfx("harbor_creak", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_lane(pos, _aim_dir, 3, 120.0, 0.12, {"color": "coral", "source": "figurehead_kegs", "field_scale": 0.9})
			if phase >= 3:
				patterns.emit_expanding_square(pos, 2, 86.0, anim_t, 1, {"color": "apricot", "source": "figurehead_sq", "field_scale": 0.5})
			stage.shake(0.20)
			stage.play_sfx("mine_blast", pos),
	})


func _on_reset_encounter() -> void:
	_roll_t = 0.0
	_roll_side = "port"
	_fluke_clamped_t = 0.0
	_fluke_pos = home + Vector2(-42.0, 18.0)
	if _roll_field != null:
		LxFields.remove(_roll_field)
		_roll_field = null


func _on_engage() -> void:
	_fluke_pos = clamp_to_arena(arena_rect.get_center() + Vector2(-46.0, 12.0))
	if _roll_field == null:
		_roll_field = _FigureheadRollField.new()
	_roll_field.dir_x = -1.0
	_roll_field.strength = 48.0
	LxFields.add(_roll_field)
	tethers.add_tether("prow_anchor_1", func() -> Vector2: return pos, func() -> Vector2: return _fluke_pos, {
		"max_length": 124.0, "hp": 3.5, "cuttable": true, "color": "sky",
		"on_cut": func(_t: Dictionary) -> void: add_stagger(6.0),
	})
	stage.play_sfx("figurehead_creak", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_fluke_clamped_t = maxf(0.0, _fluke_clamped_t - dt)
	# Ballast Clamp: hanging Wick's lantern near the sliding anchor fluke pins it!
	if _is_lantern_out() and _get_lantern_pos().distance_to(_fluke_pos) <= 26.0:
		_fluke_clamped_t = 1.6
	elif _fluke_clamped_t <= 0.0:
		# Anchor fluke slides with ship roll!
		var roll_dx: float = (-26.0 if _roll_side == "port" else 26.0) * (1.35 if phase >= 2 else 0.8)
		_fluke_pos = clamp_to_arena(_fluke_pos + Vector2(roll_dx * dt, sin(anim_t * 1.6) * 14.0 * dt))

	_roll_t += dt
	var period: float = 6.0 if phase >= 3 else (7.0 if phase >= 2 else 9.0)
	if _roll_t >= period:
		_roll_t = 0.0
		_roll_side = "starboard" if _roll_side == "port" else "port"
		if Lx.vars != null:
			Lx.vars.set_var("dungeon:galleon", "list", _roll_side)
		if _roll_field != null:
			_roll_field.dir_x = -1.0 if _roll_side == "port" else 1.0
			_roll_field.strength = 92.0 if phase >= 3 else (72.0 if phase >= 2 else 48.0)
		stage.play_sfx("figurehead_creak", pos)


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# P2 Arena Change: steep 7s roll floods two diagonal bow corners (reverted on retry!)
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(17, 7, 1, 2), "water")
		props.spawn_crate(c + Vector2(-50.0, -24.0), 2.5, "fig_keg_1")
		props.spawn_crate(c + Vector2(50.0, 24.0), 2.5, "fig_keg_2")
		stage.darkness_pulse(0.60, 1.0)
		stage.shake(0.22)
		stage.play_sfx("wood_splinter", pos)
	elif new_phase == 3:
		# P3 Arena Change: remaining bow corners splinter into water + twin anchor fluke tether!
		stage.set_tiles(world_ctx, Rect2i(2, 7, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(17, 1, 1, 2), "water")
		props.spawn_chandelier(c, 2.5, "fig_mast_yard")
		tethers.add_tether("prow_anchor_2", func() -> Vector2: return pos, c + Vector2(54.0, -18.0), {
			"max_length": 132.0, "hp": 3.0, "cuttable": true, "color": "gold",
			"on_cut": func(_t: Dictionary) -> void: add_stagger(7.5),
		})
		stage.darkness_pulse(0.68, 1.1)
		stage.shake(0.26)
		stage.play_sfx("chain_whip", pos)


func _on_death_start() -> void:
	if _roll_field != null:
		LxFields.remove(_roll_field)
		_roll_field = null
	if Lx.state != null:
		Lx.state.story_flags["galleon_done"] = true
	stage.play_sfx("wood_splinter", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	if hit.is_blue():
		return dmg * 1.40
	var rel: Vector2 = hit.origin - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < FRONT_OAK_HALF
	# Carved gilded oak hull reduces non-punish frontal chip bolts (encourages flanking, blue banks & Ballast Clamp staggers!)
	if not is_punishable() and from_front and hit.source == LxHit.SOURCE_BOLT and not hit.pierce and not hit.cracks_armour:
		clank_t = 0.10
		return dmg * 0.40
	return dmg


func _perimeter_targets(tgt: Vector2) -> Array[Vector2]:
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
	if phase >= 3:
		out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.55)))
	return out


func _body_color() -> Color:
	return PAL["gold"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	# Draw sliding iron anchor fluke & Ballast Clamp golden ring when pinned!
	var fp: Vector2 = (_fluke_pos - pos + off).round()
	draw_circle(fp, 5.0, PAL["night"] as Color)
	draw_circle(fp, 3.2, PAL["gold" if _fluke_clamped_t > 0.0 else "sky"] as Color)
	if _fluke_clamped_t > 0.0:
		draw_arc(fp, 9.0, 0.0, TAU, 14, PAL["gold"] as Color, 1.5)
