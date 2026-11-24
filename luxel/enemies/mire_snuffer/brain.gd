class_name LxMireSnufferBrain
extends LxSnatcherBrain
## Mire Snuffer (Island 4): hunts hung lanterns and snuffs them faster when unguarded
## (tell 0.42s, run 112 px/s, snuff/grab 0.65s). Unlike Magpie, bolts CAN damage and
## stagger it to reward intercepting it before it snuffs the light.

const SNUFF_TELL: float = 0.42
const SNUFF_RUN_SPEED: float = 112.0
const SNUFF_GRAB_UNGUARDED: float = 0.65
const SNUFF_GRAB_GUARDED: float = 0.85
const GUARD_CHECK_R: float = 60.0
const BOLT_STAGGER_TIME: float = 0.42
const SNUFF_CARRY_SPEED: float = 40.0
const PUFF_CD: float = 3.2
const PUFF_TELL: float = 0.44
const PUFF_COMMIT_TIME: float = 0.26
const PUFF_SPEED: float = 165.0
const PUFF_RANGE: float = 96.0
const PUFF_HIT_R: float = 20.0
const PUFF_RECOVER: float = 0.72

var snuff_fx_t: float = 0.0
var puff_cd: float = 1.6
var puff_attack: bool = false
var puff_dir: Vector2 = Vector2.RIGHT
var puff_hit: bool = false


func _init() -> void:
	super._init()
	kind = "mire_snuffer"
	island_id = 4
	max_hp = 1.75
	hp = 1.75
	body_radius = 4.5
	routine_speed = 46.0
	leash_radius = 160.0
	notice_radius = 176.0
	tell_time = SNUFF_TELL
	recover_time = SNUFF_GRAB_UNGUARDED
	run_speed = SNUFF_RUN_SPEED
	grab_time = SNUFF_GRAB_UNGUARDED
	carry_speed = SNUFF_CARRY_SPEED
	shard_drop = 3


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	var merged: Dictionary = spec.duplicate()
	if not merged.has("run_speed"):
		merged["run_speed"] = SNUFF_RUN_SPEED
	if not merged.has("grab_time"):
		merged["grab_time"] = SNUFF_GRAB_UNGUARDED
	if not merged.has("carry_speed"):
		merged["carry_speed"] = SNUFF_CARRY_SPEED
	super.setup(merged, p_director, p_world)
	snuff_fx_t = 0.0
	puff_cd = 1.6
	puff_attack = false
	puff_dir = Vector2.from_angle(facing)
	puff_hit = false


func wants_token() -> bool:
	if cooldown > 0.0:
		return false
	if sub_state != SubState.PERCH and sub_state != SubState.SHIFT:
		return false
	if _is_lantern_hung():
		return true
	return puff_cd <= 0.0 and _has_player() and _get_wick_pos().distance_to(home) <= leash_radius


func catch_lantern() -> bool:
	return false


func try_catch_lantern(_lantern_obj: Object = null) -> bool:
	return false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_bolt: bool = src == LxHit.SOURCE_BOLT or src == LxHit.SOURCE_PRISM
	var is_heavy: bool = bool(h["stagger"])
	var is_opening: bool = sub_state == SubState.TELL or sub_state == SubState.RUN \
			or sub_state == SubState.GRAB or sub_state == SubState.CARRY or sub_state == SubState.STAGGER

	# Unlike Magpie, bolts DO damage and stagger Mire Snuffer so players can intercept it!
	hp -= dmg
	flash_t = 0.14 if (is_heavy or is_bolt) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (KNOCK_SPEED if is_heavy else 88.0)

	puff_attack = false
	_drop_carried_lantern()
	_release_all_claims()

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	sub_state = SubState.STAGGER
	state = State.STAGGER
	state_timer = STAGGER_TIME if is_heavy else BOLT_STAGGER_TIME
	_emit_sfx("snuffer_intercept")
	_emit_enemy_hit(hit, HitResult.OPENED)
	return HitResult.OPENED


func _step_brain(dt: float) -> void:
	snuff_fx_t = maxf(0.0, snuff_fx_t - dt)
	puff_cd = maxf(0.0, puff_cd - dt)
	if puff_attack:
		_step_puff_attack(dt)
		return
	# When Wick does not have the lantern hung, threaten with a telegraphed dim-mist puff lunge on 3.2s CD.
	if not _is_lantern_hung() and (sub_state == SubState.PERCH or sub_state == SubState.SHIFT):
		if _try_start_puff():
			return
	# Snuff faster (0.65s) when the hung lantern is unguarded; slightly slower (0.85s) if Wick guards it.
	if sub_state == SubState.RUN:
		var unguarded: bool = not _has_player() or _get_wick_pos().distance_to(_get_lantern_pos()) > GUARD_CHECK_R
		grab_time = SNUFF_GRAB_UNGUARDED if unguarded else SNUFF_GRAB_GUARDED
	super._step_brain(dt)


func _try_start_puff() -> bool:
	if puff_cd > 0.0 or cooldown > 0.0 or not _has_player() or not _is_on_screen():
		return false
	var wp: Vector2 = _get_wick_pos()
	if pos.distance_to(wp) > PUFF_RANGE or wp.distance_to(home) > leash_radius:
		return false
	if not _claim_token():
		return false
	puff_attack = true
	puff_hit = false
	var to_w: Vector2 = wp - pos
	puff_dir = to_w.normalized() if to_w.length() > 0.01 else Vector2.from_angle(facing)
	facing = puff_dir.angle()
	sub_state = SubState.TELL
	state = State.TELL
	is_counter_attack = false
	last_tell_duration = _scaled_tell(PUFF_TELL, false, attack_damage)
	state_timer = last_tell_duration
	_emit_attack_started()
	_emit_sfx("snuffer_puff_tell")
	return true


func _step_puff_attack(dt: float) -> void:
	if sub_state == SubState.TELL:
		state = State.TELL
		if state_timer > 0.16 * _assist_tell_scale() and _has_player():
			var to_w: Vector2 = _get_wick_pos() - pos
			if to_w.length() > 0.01:
				_turn_toward(to_w.angle(), 4.2, dt)
				puff_dir = Vector2.from_angle(facing)
		state_timer -= dt
		if state_timer <= 0.0:
			sub_state = SubState.RUN
			state = State.COMMIT
			state_timer = PUFF_COMMIT_TIME
			puff_hit = false
			snuff_fx_t = 0.35
			_emit_sfx("snuffer_snuff")
	elif sub_state == SubState.RUN:
		state = State.COMMIT
		_move_step(puff_dir * PUFF_SPEED * dt, false)
		var puff_center: Vector2 = pos + puff_dir * 8.0
		if not puff_hit and _has_player() and puff_center.distance_to(_get_wick_pos()) <= PUFF_HIT_R:
			puff_hit = true
			_emit_player_hit(puff_dir)
		state_timer -= dt
		if state_timer <= 0.0:
			puff_attack = false
			puff_cd = PUFF_CD
			_release_all_claims()
			sub_state = SubState.BAFFLED
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, PUFF_RECOVER)
			last_recover_duration = state_timer
			cooldown = AGAIN_CD
	else:
		puff_attack = false


func _take_lantern() -> void:
	var lan_p: Vector2 = _get_lantern_pos()
	var unguarded: bool = not _has_player() or _get_wick_pos().distance_to(lan_p) > GUARD_CHECK_R
	if unguarded:
		# Unguarded hung lantern gets snuffed outright, forcing recall & retreat.
		snuff_fx_t = 0.45
		carrying_lantern = false
		_release_all_claims()
		if Lx.events != null:
			Lx.events.lantern_struck.emit(lan_p)
		_emit_sfx("snuffer_snuff")
		cooldown = AGAIN_CD * 1.4
		_go_to(_far_perch(), SubState.SHY, State.POSITION)
		return
	super._take_lantern()


func _body_color() -> Color:
	return PAL["teal"] as Color


func _draw_extra(off: Vector2) -> void:
	if _sprite_sheet == null:
		# Hooded candle-snuffer bell cone silhouette (distinct from Magpie bird).
		var pts := PackedVector2Array([
			off + Vector2(0.0, -body_radius - 6.0),
			off + Vector2(-body_radius - 2.0, -1.0),
			off + Vector2(body_radius + 2.0, -1.0),
		])
		draw_colored_polygon(pts, PAL["pine"] as Color)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), PAL["night"] as Color, 1.0)
		draw_circle(off + Vector2(-1.5, -2.0), 1.0, PAL["lime"] as Color)
		draw_circle(off + Vector2(1.5, -2.0), 1.0, PAL["lime"] as Color)
	var c := Vector2(roundf(off.x), roundf(off.y))
	if puff_attack and state == State.TELL:
		var prog_p: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var p_len: float = PUFF_SPEED * PUFF_COMMIT_TIME
		var p_end: Vector2 = (c + puff_dir * p_len).round()
		var p_side: Vector2 = Vector2(-puff_dir.y, puff_dir.x)
		var p_col: Color = (PAL["coral"] if state_timer <= 0.16 * _assist_tell_scale() else PAL["lime"]) as Color
		draw_line(c, p_end, p_col, 1.4)
		draw_line((c + p_side * 10.0).round(), (p_end + p_side * 14.0).round(), PAL["plum"] as Color, 1.0)
		draw_line((c - p_side * 10.0).round(), (p_end - p_side * 14.0).round(), PAL["plum"] as Color, 1.0)
		draw_arc(p_end, lerpf(12.0, PUFF_HIT_R * 0.75, prog_p), 0.0, TAU, 14, p_col, 1.2)
	elif puff_attack and state == State.COMMIT:
		var cloud_c: Vector2 = (c + puff_dir * 8.0).round()
		draw_arc(cloud_c, PUFF_HIT_R, 0.0, TAU, 16, PAL["dusk"] as Color, 2.4)
		draw_arc(cloud_c, PUFF_HIT_R - 3.0, 0.0, TAU, 14, PAL["plum"] as Color, 1.8)
		draw_arc(cloud_c, PUFF_HIT_R - 6.0, 0.0, TAU, 12, PAL["lime"] as Color, 1.2)
	if sub_state == SubState.GRAB:
		var spin: float = anim_t * 6.5
		var vr: float = roundf(body_radius + 5.5 + (0.0 if LxHudFx.flash_reduced() else sin(anim_t * 16.0) * 1.0))
		for vi: int in range(3):
			var a0: float = spin + float(vi) * (TAU / 3.0)
			draw_arc(c, vr + 1.5, a0, a0 + 1.15, 8, PAL["night"] as Color, 2.2)
			draw_arc(c, vr, a0 + 0.15, a0 + 1.25, 8, PAL["dusk"] as Color, 1.6)
			draw_arc(c, maxf(2.0, vr - 2.0), a0 + 0.40, a0 + 1.15, 6, PAL["plum"] as Color, 1.1)
		for wi: int in range(4):
			var wt: float = fmod(anim_t * 2.0 + float(wi) * 0.25, 1.0)
			var wr: float = lerpf(body_radius + 11.0, body_radius + 1.5, wt)
			var wa: float = spin * 0.8 + float(wi) * (PI * 0.5) + wt * 1.8
			var wp := Vector2(roundf(c.x + cos(wa) * wr), roundf(c.y + sin(wa) * wr))
			draw_rect(Rect2(wp, Vector2(1.0, 1.0)), PAL["lime"] as Color, true)
			draw_rect(Rect2(roundf(c.x + cos(wa - 0.22) * (wr + 1.5)), roundf(c.y + sin(wa - 0.22) * (wr + 1.5)), 1.0, 1.0), PAL["teal"] as Color, true)
	elif snuff_fx_t > 0.0:
		var sp: float = 1.0 - clampf(snuff_fx_t / 0.45, 0.0, 1.0)
		var sr: float = roundf(body_radius + 4.0 + sp * 9.5)
		draw_arc(c, sr + 1.5, 0.0, TAU, 16, PAL["dusk"] as Color, 2.0)
		draw_arc(c, sr, 0.0, TAU, 16, PAL["plum"] as Color, 1.4)
		draw_arc(c, maxf(2.0, sr - 2.5), 0.0, TAU, 12, PAL["stone"] as Color, 1.0)
		for pi: int in range(6):
			var pa: float = float(pi) * (TAU / 6.0) + sp * 0.45
			var pp := Vector2(roundf(c.x + cos(pa) * sr), roundf(c.y + sin(pa) * sr - sp * 3.0))
			var pc: Color = (PAL["dusk"] as Color) if (pi % 3 == 0) else ((PAL["plum"] as Color) if (pi % 3 == 1) else (PAL["stone"] as Color))
			draw_circle(pp, 2.0 if sp < 0.55 else 1.2, pc)
	elif carrying_lantern:
		var sway: float = roundf(sin(anim_t * 9.5) * 1.5)
		var lx: float = c.x + sway
		var ly: float = c.y + 5.0
		draw_rect(Rect2(lx - 3.0, ly - 4.0, 7.0, 2.0), PAL["night"] as Color, true)
		draw_rect(Rect2(lx - 3.0, ly - 2.0, 7.0, 6.0), PAL["void"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly - 1.0, 5.0, 4.0), PAL["gold"] as Color, true)
		var flick: float = 0.0 if (LxHudFx.flash_reduced() or int(anim_t * 10.0) % 2 == 0) else 1.0
		draw_rect(Rect2(lx, ly + flick, 1.0, 1.0), PAL["cream"] as Color, true)
		draw_rect(Rect2(lx - 1.0, ly - 2.0, 1.0, 5.0), PAL["night"] as Color, true)
		draw_rect(Rect2(lx + 1.0, ly - 2.0, 1.0, 5.0), PAL["night"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly + 3.0, 5.0, 1.0), PAL["apricot"] as Color, true)
		var back: Vector2 = -Vector2.from_angle(facing)
		draw_rect(Rect2(roundf(lx + back.x * 5.0), roundf(ly + back.y * 5.0 - 1.0), 1.0, 1.0), PAL["mauve"] as Color, true)
