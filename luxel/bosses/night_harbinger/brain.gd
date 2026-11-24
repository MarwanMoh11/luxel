class_name LxNightHarbingerBoss
extends LxMoonshadeBrain
## The Long Night mini-boss (Island 8, sanctum_r4): Night Harbinger, elite lunar Moonshade Warden.
## Upgraded (Bible §4.6): 2 phases, HP 15.0, lunar shield 2.4.
## Preserves blink-feint lunges + Twin Blink-Cross Slash (tells >= 0.50s, recovers >= 1.00s).
## P2 (<=50%) Eclipse-Brazier Twist: snuffs West Eclipse Brazier summoning a stationary
## Eclipse Mirror duplicating his delayed crescent arc; relighting the West Brazier (or
## striking the Eclipse Mirror) with Bolt/Beam/Throw/Sunflare shatters it for a 1.8s stagger!

const BLINK_TELL_P1: float = 0.56
const BLINK_TELL_P2: float = 0.50
const BLINK_DIST: float = 26.0
const MAIN_SLASH_TIME: float = 0.22
const ECHO_SLASH_TIME: float = 0.28
const BLINK_COMMIT_TIME: float = MAIN_SLASH_TIME + ECHO_SLASH_TIME
const MAIN_SLASH_R: float = 48.0
const MAIN_SLASH_ARC: float = 1.28
const ECHO_CRESCENT_RANGE: float = 78.0
const ECHO_CRESCENT_HALF_W: float = 14.0
const BLINK_RECOVER_P1: float = 1.15
const BLINK_RECOVER_P2: float = 1.00
const BLINK_CD_P1: float = 3.8
const BLINK_CD_P2: float = 2.7
const PHASE2_ROAR_TIME: float = 0.58
const MIRROR_STAGGER_TIME: float = 1.80
const MIRROR_RESPAWN_CD: float = 12.5
const MIRROR_ARC_RANGE: float = 84.0
const MIRROR_ARC_DELAY: float = 0.24
const MIRROR_ARC_DUR: float = 0.28

var blink_slash_attack: bool = false
var blink_cd: float = 1.6
var blink_elapsed: float = 0.0
var main_slash_dir: Vector2 = Vector2.RIGHT
var main_slash_hit: bool = false
var echo_pos: Vector2 = Vector2.ZERO
var echo_dir: Vector2 = Vector2.RIGHT
var echo_fired: bool = false
var echo_hit: bool = false
var swings_since_blink: int = 0
var _roaring: bool = false

# P2 Eclipse-Brazier & Stationary Eclipse Mirror state
var _west_brazier_pos: Vector2 = Vector2.ZERO
var _west_brazier_ref: Object = null
var _west_brazier_snuffed: bool = false
var _mirror_active: bool = false
var _mirror_pos: Vector2 = Vector2.ZERO
var _mirror_dir: Vector2 = Vector2.LEFT
var _mirror_firing: bool = false
var _mirror_fire_t: float = 0.0
var _mirror_hit: bool = false
var _mirror_respawn_t: float = 0.0
var _mirror_shatter_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "night_harbinger"
	boss_id = "night_harbinger"
	island_id = 8
	is_boss = true
	variant = VARIANT_WARDEN
	max_hp = 15.0
	hp = 15.0
	shield_max = 2.4
	shield_hp = 2.4
	shield_gone_duration = 4.6
	body_radius = 7.0
	routine_speed = 42.0
	leash_radius = 175.0
	notice_radius = 144.0
	reach = 40.0
	lunge_reach = 104.0
	swing_r = 32.0
	swing_arc = 1.28
	tell_time = 0.50
	lunge_tell_time = 0.54
	recover_time = 1.10
	give_up_time = 1.8
	shard_drop = 22


func _configure_variant_defaults() -> void:
	variant = VARIANT_WARDEN
	body_radius = 7.0
	routine_speed = 42.0
	shield_max = 2.4
	tell_time = 0.50
	recover_time = 1.10


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	var forced: Dictionary = spec.duplicate()
	forced["variant"] = VARIANT_WARDEN
	super.setup(forced, p_director, p_world)
	max_hp = maxf(15.0, max_hp)
	hp = max_hp
	variant = VARIANT_WARDEN
	kind = "night_harbinger"
	is_boss = true
	boss_id = str(spec.get("boss_id", "night_harbinger"))
	island_id = int(spec.get("island_id", 8))
	blink_slash_attack = false
	blink_cd = 1.6
	blink_elapsed = 0.0
	main_slash_dir = Vector2.from_angle(facing)
	main_slash_hit = false
	echo_pos = pos
	echo_dir = Vector2.from_angle(facing)
	echo_fired = false
	echo_hit = false
	swings_since_blink = 0
	_roaring = false
	_west_brazier_ref = null
	_west_brazier_pos = _clamp_arena_pt(home + Vector2(-76.0, 0.0))
	_west_brazier_snuffed = false
	_mirror_active = false
	_mirror_pos = _clamp_arena_pt(home + Vector2(68.0, -18.0))
	_mirror_dir = Vector2.LEFT
	_mirror_firing = false
	_mirror_fire_t = 0.0
	_mirror_hit = false
	_mirror_respawn_t = 0.0
	_mirror_shatter_t = 0.0
	_find_west_brazier()


func _is_hit_invulnerable() -> bool:
	return _roaring


func take_hit(hit: LxHit) -> int:
	# Guarded LxSold hit_flash bonus: +40% lunar shield wear (Bible §1.2)
	if hit != null and _is_setting_sold("hit_flash") and shield_hp > 0.0 and shield_gone_t <= 0.0:
		shield_hp = maxf(0.0, shield_hp - hit.shield_wear * 0.40)
	return super.take_hit(hit)


func _on_damaged_alive(_hit: LxHit) -> bool:
	if phase < 2 and hp <= max_hp * 0.50 and hp > 0.001:
		phase = 2
		wary = false
		_roaring = true
		blink_slash_attack = false
		lunge_attack = false
		is_counter_attack = false
		blink_elapsed = 0.0
		if shield_gone_t > 0.0:
			shield_gone_t = 0.0
			shield_hp = shield_max * 0.55
		_release_token()
		state = State.NOTICE
		state_timer = PHASE2_ROAR_TIME
		blink_cd = 0.80
		_summon_eclipse_mirror()
		if Lx.events != null:
			Lx.events.boss_phase_changed.emit(boss_id, 2)
		_boss_impact(0.28, 96.0, 96.0)
		_emit_sfx("night_harbinger_phase2")
		return true
	return false


func _step_brain(dt: float) -> void:
	if _roaring and state != State.NOTICE:
		_roaring = false
	blink_cd = maxf(0.0, blink_cd - dt)
	_mirror_shatter_t = maxf(0.0, _mirror_shatter_t - dt)
	_tick_eclipse_mirror(dt)
	super._step_brain(dt)


func _on_stagger_end(target_pos: Vector2) -> void:
	blink_slash_attack = false
	super._on_stagger_end(target_pos)


func _step_notice(dt: float, target_pos: Vector2) -> void:
	var to_t: Vector2 = target_pos - pos
	if to_t.length() > 0.01:
		_turn_toward(to_t.angle(), TURN_PATROL * 1.5, dt)
	state_timer -= dt
	if state_timer <= 0.0:
		_roaring = false
		state = State.POSITION
		step_clock = 0.0
		cooldown = 0.35


func _try_start_attack(target_pos: Vector2, dist: float) -> bool:
	if blink_cd <= 0.0 and (phase >= 2 or swings_since_blink >= 1) and dist < 96.0 \
			and _claim_token():
		blink_slash_attack = true
		lunge_attack = false
		is_counter_attack = false
		feint_done = false
		feint_side = -feint_side
		state = State.TELL
		var base_t: float = BLINK_TELL_P2 if phase >= 2 else BLINK_TELL_P1
		last_tell_duration = _scaled_tell(base_t, false, attack_damage)
		state_timer = last_tell_duration
		echo_pos = pos
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.01:
			facing = to_t.angle()
		main_slash_dir = Vector2.from_angle(facing)
		echo_dir = main_slash_dir
		if _mirror_active and target_pos.distance_to(_mirror_pos) > 1.0:
			_mirror_dir = (target_pos - _mirror_pos).normalized()
		blink_elapsed = 0.0
		main_slash_hit = false
		echo_fired = false
		echo_hit = false
		swings_since_blink = 0
		_emit_attack_started()
		_emit_sfx("harbinger_wave_tell")
		return true
	blink_slash_attack = false
	return super._try_start_attack(target_pos, dist)


func _step_tell(dt: float, target_pos: Vector2) -> void:
	if _mirror_active and state_timer > 0.18 and target_pos.distance_to(_mirror_pos) > 1.0:
		_mirror_dir = (target_pos - _mirror_pos).normalized()
	if not blink_slash_attack:
		super._step_tell(dt, target_pos)
		return
	if not feint_done and state_timer <= last_tell_duration * 0.62:
		feint_done = true
		echo_pos = pos
		_do_lateral_feint(target_pos, BLINK_DIST)
	if state_timer > 0.18:
		var to_m: Vector2 = target_pos - pos
		if to_m.length() > 0.01:
			_turn_toward(to_m.angle(), 4.2, dt)
			main_slash_dir = Vector2.from_angle(facing)
		var to_e: Vector2 = target_pos - echo_pos
		if to_e.length() > 0.01:
			echo_dir = to_e.normalized()
	state_timer -= dt
	if state_timer <= 0.0:
		_enter_commit()


func _enter_commit() -> void:
	if _mirror_active:
		_mirror_firing = true
		_mirror_fire_t = 0.0
		_mirror_hit = false
	if blink_slash_attack:
		state = State.COMMIT
		state_timer = BLINK_COMMIT_TIME
		blink_elapsed = 0.0
		main_slash_hit = false
		echo_fired = false
		echo_hit = false
		main_slash_dir = Vector2.from_angle(facing)
		_boss_impact(0.16, 78.0, 82.0)
		_emit_sfx("warden_swing")
		return
	swings_since_blink += 1
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if not blink_slash_attack:
		super._step_commit(dt)
		return
	blink_elapsed += dt
	state_timer = maxf(0.0, state_timer - dt)
	if blink_elapsed <= MAIN_SLASH_TIME:
		_move_step(main_slash_dir * 155.0 * dt, false)
		if not main_slash_hit and _has_player():
			var wv: Vector2 = _get_wick_pos() - pos
			if wv.length() <= MAIN_SLASH_R and (wv.length() < 0.01 or absf(angle_difference(main_slash_dir.angle(), wv.angle())) <= MAIN_SLASH_ARC):
				main_slash_hit = true
				_emit_player_hit(main_slash_dir)
		if _is_lured() and _get_lantern_pos().distance_to(pos) <= MAIN_SLASH_R:
			if Lx.events != null:
				Lx.events.lantern_struck.emit(_get_lantern_pos())
	else:
		if not echo_fired:
			echo_fired = true
			LxDamageFx.boss_impact(echo_pos, 0.14, 72.0, 76.0, 68.0, 1.32, 0.28, "ice")
			_emit_sfx("harbinger_wave_fire")
		var e_prog: float = clampf((blink_elapsed - MAIN_SLASH_TIME) / ECHO_SLASH_TIME, 0.0, 1.0)
		var arc_pos: Vector2 = echo_pos + echo_dir * lerpf(8.0, ECHO_CRESCENT_RANGE, e_prog)
		if not echo_hit and _has_player():
			var wp: Vector2 = _get_wick_pos()
			if arc_pos.distance_to(wp) <= ECHO_CRESCENT_HALF_W:
				echo_hit = true
				_emit_player_hit(echo_dir)
		if _is_lured() and arc_pos.distance_to(_get_lantern_pos()) <= ECHO_CRESCENT_HALF_W + 2.0:
			if Lx.events != null:
				Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0:
		blink_slash_attack = false
		blink_elapsed = 0.0
		state = State.RECOVER
		state_timer = maxf(MIN_RECOVER_TIME, BLINK_RECOVER_P2 if phase >= 2 else BLINK_RECOVER_P1)
		last_recover_duration = state_timer
		blink_cd = BLINK_CD_P2 if phase >= 2 else BLINK_CD_P1


func _find_west_brazier() -> void:
	_west_brazier_ref = null
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return
	var best_x: float = INF
	for it_v: Variant in (world_ctx.call("get_interactables") as Array):
		if it_v is Object and str((it_v as Object).get("kind")) == "brazier":
			var bp: Vector2 = (it_v as Object).get("pos") as Vector2
			if bp.x < best_x:
				best_x = bp.x
				_west_brazier_ref = it_v as Object
				_west_brazier_pos = bp


func _summon_eclipse_mirror() -> void:
	_west_brazier_snuffed = true
	if _west_brazier_ref != null and is_instance_valid(_west_brazier_ref):
		_west_brazier_ref.set("lit", false)
		if _west_brazier_ref is CanvasItem:
			(_west_brazier_ref as CanvasItem).queue_redraw()
	_mirror_active = true
	_mirror_firing = false
	_mirror_fire_t = 0.0
	_mirror_hit = false
	_mirror_pos = _clamp_arena_pt(home + Vector2(68.0, -18.0))
	if _has_player() and _get_wick_pos().distance_to(_mirror_pos) > 1.0:
		_mirror_dir = (_get_wick_pos() - _mirror_pos).normalized()


func _shatter_eclipse_mirror() -> void:
	if not _mirror_active:
		return
	_mirror_active = false
	_mirror_firing = false
	_west_brazier_snuffed = false
	_mirror_respawn_t = MIRROR_RESPAWN_CD
	_mirror_shatter_t = 0.65
	if _west_brazier_ref != null and is_instance_valid(_west_brazier_ref):
		_west_brazier_ref.set("lit", true)
		if _west_brazier_ref is CanvasItem:
			(_west_brazier_ref as CanvasItem).queue_redraw()
	LxDamageFx.boss_impact(_mirror_pos, 0.18, 86.0, 90.0, 88.0, 1.44, 0.34, "gold")
	_emit_sfx("eclipse_mirror_shatter")
	if hp > 2.0:
		hp -= 1.5
	if state != State.DEAD and not _roaring:
		_release_token()
		blink_slash_attack = false
		lunge_attack = false
		state = State.STAGGER
		state_timer = MIRROR_STAGGER_TIME


func _tick_eclipse_mirror(dt: float) -> void:
	if state == State.DEAD or phase < 2:
		return
	if not _mirror_active:
		if _mirror_respawn_t > 0.0:
			_mirror_respawn_t -= dt
			if _mirror_respawn_t <= 0.0 and state != State.STAGGER and not _roaring:
				_summon_eclipse_mirror()
		return
	# Check if actual room West Brazier was relit by Wick!
	if _west_brazier_ref != null and is_instance_valid(_west_brazier_ref) and bool(_west_brazier_ref.get("lit")):
		_shatter_eclipse_mirror()
		return
	# Also allow Wick's Bolt, Beam, Throw, or Sunflare to relight virtual West Brazier OR shatter Mirror directly!
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		var targets: Array[Vector2] = [_west_brazier_pos, _mirror_pos]
		for tp: Vector2 in targets:
			for bi: int in range(w.bolts.size() - 1, -1, -1):
				var bv: Variant = w.bolts[bi]
				if bv is Object and (bv.get("pos") as Vector2).distance_to(tp) <= 14.0:
					w.bolts.remove_at(bi)
					_shatter_eclipse_mirror()
					return
			if w.move_beam != null and w.move_beam.beam_vis_t > 0.0:
				if Geometry2D.get_closest_point_to_segment(tp, w.move_beam.beam_start, w.move_beam.beam_end).distance_to(tp) <= 14.0:
					_shatter_eclipse_mirror()
					return
			if w.lantern != null and w.lantern.is_out() and w.lantern.pos.distance_to(tp) <= 18.0:
				_shatter_eclipse_mirror()
				return
	# Step delayed crescent arc fired by Eclipse Mirror after Harbinger commits!
	if _mirror_firing:
		_mirror_fire_t += dt
		if _mirror_fire_t >= MIRROR_ARC_DELAY:
			var prog: float = clampf((_mirror_fire_t - MIRROR_ARC_DELAY) / MIRROR_ARC_DUR, 0.0, 1.0)
			var arc_p: Vector2 = _mirror_pos + _mirror_dir * lerpf(8.0, MIRROR_ARC_RANGE, prog)
			if not _mirror_hit and _has_player() and arc_p.distance_to(_get_wick_pos()) <= 13.0:
				_mirror_hit = true
				_emit_player_hit(_mirror_dir)
			if prog >= 1.0:
				_mirror_firing = false


func _clamp_arena_pt(pt: Vector2) -> Vector2:
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_bounds"):
		var b: Rect2 = (world_ctx.call("get_bounds") as Rect2).grow(-24.0)
		if b.has_area():
			return Vector2(clampf(pt.x, b.position.x, b.end.x), clampf(pt.y, b.position.y, b.end.y))
	return pt


static func _is_setting_sold(setting_id: String) -> bool:
	if ResourceLoader.exists("res://luxel/core/sold_settings.gd"):
		var sc: Variant = ResourceLoader.load("res://luxel/core/sold_settings.gd")
		if sc is GDScript and (sc as GDScript).has_method("current"):
			var inst: Variant = (sc as GDScript).call("current")
			if inst is Object and (inst as Object).has_method("is_sold"):
				return bool((inst as Object).call("is_sold", setting_id))
	if Lx.vars != null:
		return bool(Lx.vars.get_var("island:8", "sold_" + setting_id, Lx.vars.get_var("game", "sold_" + setting_id, false)))
	return false


func _swing_tell_base() -> float:
	return 0.50 if phase >= 2 else tell_time


func _lunge_tell_base() -> float:
	return 0.50 if phase >= 2 else lunge_tell_time


func _post_recover_cooldown() -> float:
	return 0.68 if phase >= 2 else 0.88


func _body_color() -> Color:
	return (PAL["plum"] as Color) if phase >= 2 else (PAL["deep"] as Color)


func _shield_color() -> Color:
	return PAL["ice"] as Color


func _draw_extra(off: Vector2) -> void:
	if not blink_slash_attack:
		super._draw_extra(off)
	if _sprite_sheet == null:
		draw_arc(off + Vector2(0.0, -body_radius - 2.0), 5.5, 0.25, PI - 0.25, 12, PAL["ice"] as Color, 1.8)
	var c: Vector2 = off.round()
	# Sold sound_off crisp cream tell rim ring!
	if state == State.TELL and _is_setting_sold("sound_off"):
		draw_arc(c, body_radius + 7.0, 0.0, TAU, 20, PAL["cream"] as Color, 1.2)
	# P2 Snuffed West Eclipse Brazier + Stationary Eclipse Mirror visuals!
	if phase >= 2 and state != State.DEAD:
		var bp: Vector2 = (_west_brazier_pos - pos + off).round()
		draw_circle(bp, 7.0, PAL["night"] as Color)
		draw_arc(bp, 7.5, 0.0, TAU, 16, (PAL["plum"] if _west_brazier_snuffed else PAL["gold"]) as Color, 1.4)
		if not _west_brazier_snuffed:
			draw_circle(bp, 3.5, PAL["gold"] as Color)
			draw_rect(Rect2(bp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
		else:
			draw_arc(bp, 10.5, anim_t * 2.0, anim_t * 2.0 + PI, 10, PAL["coral"] as Color, 1.0)
	if _mirror_active and state != State.DEAD:
		var mp: Vector2 = (_mirror_pos - pos + off).round()
		draw_circle(mp, 8.0, PAL["void"] as Color)
		draw_arc(mp, 9.0, 0.0, TAU, 18, PAL["ice"] as Color, 1.6)
		_draw_eclipse_diamond(mp, 4.0, PAL["sky"] as Color, PAL["cream"] as Color)
		if state == State.TELL:
			draw_line(mp, (mp + _mirror_dir * MIRROR_ARC_RANGE).round(), PAL["sky"] as Color, 1.2)
		elif _mirror_firing and _mirror_fire_t >= MIRROR_ARC_DELAY:
			var mprog: float = clampf((_mirror_fire_t - MIRROR_ARC_DELAY) / MIRROR_ARC_DUR, 0.0, 1.0)
			var mac: Vector2 = (mp + _mirror_dir * lerpf(8.0, MIRROR_ARC_RANGE, mprog)).round()
			var ma_m: float = _mirror_dir.angle()
			draw_arc(mac, 13.0, ma_m - 1.0, ma_m + 1.0, 12, PAL["sky"] as Color, 2.8)
			draw_arc(mac, 11.0, ma_m - 0.85, ma_m + 0.85, 10, PAL["cream"] as Color, 1.2)
	if _mirror_shatter_t > 0.0:
		var mp2: Vector2 = (_mirror_pos - pos + off).round()
		var su: float = 1.0 - clampf(_mirror_shatter_t / 0.65, 0.0, 1.0)
		draw_arc(mp2, lerpf(10.0, 40.0, su), 0.0, TAU, 20, Color(PAL["gold"] as Color, 1.0 - su), 1.8)

	if blink_slash_attack and state == State.TELL:
		var ep: Vector2 = (echo_pos - pos + off).round()
		var hot: bool = state_timer <= 0.18
		var ma: float = main_slash_dir.angle()
		draw_arc(c, MAIN_SLASH_R, ma - MAIN_SLASH_ARC * 0.75, ma + MAIN_SLASH_ARC * 0.75, 14, (PAL["coral"] if hot else PAL["gold"]) as Color, 1.6 if hot else 1.2)
		draw_line(c, (c + main_slash_dir * MAIN_SLASH_R).round(), (PAL["cream"] if hot else PAL["coral"]) as Color, 1.2)
		if feint_done:
			draw_line(ep, c, PAL["blue"] as Color, 1.2)
			draw_arc(ep, body_radius + 1.0, 0.0, TAU, 14, PAL["sky"] as Color, 1.4)
			draw_circle(ep, body_radius * 0.65, PAL["deep"] as Color)
			_draw_eclipse_diamond(ep, 3.5, PAL["ice"] as Color, PAL["cream"] as Color)
			var e_end: Vector2 = (ep + echo_dir * ECHO_CRESCENT_RANGE).round()
			draw_line(ep, e_end, (PAL["cream"] if hot else PAL["sky"]) as Color, 1.4 if hot else 1.1)
			var ea: float = echo_dir.angle()
			draw_arc((ep + echo_dir * 26.0).round(), 12.0, ea - 0.9, ea + 0.9, 10, PAL["ice"] as Color, 1.4)
	elif blink_slash_attack and state == State.COMMIT:
		var ep2: Vector2 = (echo_pos - pos + off).round()
		if blink_elapsed <= MAIN_SLASH_TIME:
			var prog1: float = clampf(blink_elapsed / MAIN_SLASH_TIME, 0.0, 1.0)
			var ma: float = main_slash_dir.angle()
			var a0: float = ma - MAIN_SLASH_ARC * 0.85
			var a1: float = lerpf(a0 + 0.35, ma + MAIN_SLASH_ARC * 0.85, prog1)
			draw_arc(c, MAIN_SLASH_R, a0, a1, 16, PAL["coral"] as Color, 3.0)
			draw_arc(c, MAIN_SLASH_R - 2.5, a0, a1, 14, PAL["gold"] as Color, 1.8)
			draw_arc(c, MAIN_SLASH_R - 4.0, a0 + 0.1, a1, 12, PAL["cream"] as Color, 1.0)
			draw_arc(ep2, body_radius + 3.0, 0.0, TAU, 14, PAL["ice"] as Color, 1.6)
			draw_line(ep2, (ep2 + echo_dir * ECHO_CRESCENT_RANGE).round(), PAL["sky"] as Color, 1.2)
		else:
			var e_prog: float = clampf((blink_elapsed - MAIN_SLASH_TIME) / ECHO_SLASH_TIME, 0.0, 1.0)
			var arc_c: Vector2 = (ep2 + echo_dir * lerpf(8.0, ECHO_CRESCENT_RANGE, e_prog)).round()
			var ea: float = echo_dir.angle()
			draw_line(ep2, arc_c, PAL["deep"] as Color, 2.0)
			draw_arc(arc_c, 15.0, ea - 1.15, ea + 1.15, 14, PAL["sky"] as Color, 3.2)
			draw_arc(arc_c, 13.5, ea - 1.05, ea + 1.05, 12, PAL["ice"] as Color, 2.0)
			draw_arc(arc_c, 12.0, ea - 0.90, ea + 0.90, 10, PAL["cream"] as Color, 1.2)
			_draw_eclipse_diamond(arc_c + echo_dir * 12.0, 3.0, PAL["gold"] as Color, PAL["cream"] as Color)
	elif _roaring:
		var rp: float = 1.0 - clampf(state_timer / PHASE2_ROAR_TIME, 0.0, 1.0)
		var r1: float = body_radius + 11.0 + rp * 18.0
		var r2: float = maxf(6.0, r1 - 6.5)
		draw_arc(c, r1, 0.0, TAU, 32, PAL["coral"] as Color, 2.4)
		draw_arc(c, r2, 0.0, TAU, 28, PAL["gold"] as Color, 2.0)
		draw_arc(c, maxf(4.0, r2 - 2.0), 0.0, TAU, 24, PAL["ice"] as Color, 1.1)
		for ri: int in range(4):
			var rd: Vector2 = Vector2.from_angle(float(ri) * (TAU * 0.25))
			draw_line((c + rd * (r1 - 3.5)).round(), (c + rd * (r1 + 4.5)).round(), PAL["gold"] as Color, 1.6)
			draw_line((c + rd * (r1 - 1.5)).round(), (c + rd * (r1 + 2.5)).round(), PAL["ice"] as Color, 1.0)


func _draw_eclipse_diamond(pt: Vector2, rad: float, outer: Color, inner: Color) -> void:
	var p: Vector2 = pt.round()
	var t: Vector2 = p + Vector2(0.0, -rad)
	var r: Vector2 = p + Vector2(rad, 0.0)
	var d: Vector2 = p + Vector2(0.0, rad)
	var l: Vector2 = p + Vector2(-rad, 0.0)
	draw_line(t, r, outer, 1.2)
	draw_line(r, d, outer, 1.2)
	draw_line(d, l, outer, 1.2)
	draw_line(l, t, outer, 1.2)
	draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), inner, true)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.12, 1.44, 0.40)
