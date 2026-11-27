class_name LxAshMoleBrain
extends LxSnatcherBrain
## Ash Mole (Island 6, Ashen Kiln).
## Burrows underground along ash perches; surfaces under a hung lantern after a 0.50s dirt tremor
## tell, then tries to drag it under during an 0.85s grab recovery.
## Untargetable while burrowed; vulnerable to BOTH bolts and heavy hits while surfaced!

const ASH_GRAB_TIME: float = 0.85
const ASH_TELL_TIME: float = 0.50
const ERUPT_DIST: float = 14.0
const AMBUSH_CD: float = 3.2
const AMBUSH_COMMIT_TIME: float = 0.30
const AMBUSH_BURROW_SPEED: float = 240.0
const AMBUSH_HIT_R: float = 16.0
const AMBUSH_RECOVER: float = 0.78

var surfaced: bool = false
var _was_surfaced: bool = false
var ambush_cd: float = 1.6
var ambush_attack: bool = false
var ambush_target: Vector2 = Vector2.ZERO
var ambush_hit: bool = false


func _init() -> void:
	super._init()
	kind = "ash_mole"
	max_hp = 1.75
	hp = 1.75
	body_radius = 4.5
	routine_speed = 42.0
	leash_radius = 156.0
	notice_radius = 160.0
	tell_time = ASH_TELL_TIME
	recover_time = ASH_GRAB_TIME
	grab_time = ASH_GRAB_TIME
	run_speed = 112.0
	carry_speed = 34.0
	shard_drop = 3


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	grab_time = maxf(MIN_RECOVER_TIME, float(spec.get("grab_time", ASH_GRAB_TIME)))
	recover_time = grab_time
	surfaced = false
	_was_surfaced = false
	ambush_cd = 1.6
	ambush_attack = false
	ambush_target = home
	ambush_hit = false


func is_flying() -> bool:
	return false


func is_targetable() -> bool:
	return is_alive() and surfaced


func try_catch_lantern(lantern_obj: Object = null) -> bool:
	if not surfaced:
		return false
	return super.try_catch_lantern(lantern_obj)


func wants_token() -> bool:
	if cooldown > 0.0:
		return false
	if sub_state != SubState.PERCH and sub_state != SubState.SHIFT:
		return false
	if _is_lantern_hung():
		return true
	return ambush_cd <= 0.0 and _has_player() and _get_wick_pos().distance_to(home) <= leash_radius


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var cracks: bool = bool(h["cracks_armour"])
	# Sunflare unearths Ash Mole even while burrowed!
	var sunflare_unearth: bool = false
	if not surfaced:
		if src == LxHit.SOURCE_SUNFLARE or cracks:
			surfaced = true
			_was_surfaced = true
			ambush_attack = false
			sunflare_unearth = true
			LxDamageFx.boss_impact(pos, 0.14, 58.0, 68.0, 52.0, 1.25, 0.28)
			_emit_sfx("ash_mole_unearth")
		else:
			_emit_sfx("ash_mole_burrowed")
			_emit_enemy_hit(hit, HitResult.GLANCED)
			return HitResult.GLANCED

	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"]) or sunflare_unearth
	var orig: Vector2 = h["origin"] as Vector2
	if is_heavy and state == State.STAGGER and not sunflare_unearth:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var is_opening: bool = sunflare_unearth or sub_state == SubState.GRAB or sub_state == SubState.CARRY \
			or sub_state == SubState.BAFFLED or sub_state == SubState.STAGGER
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (135.0 if is_heavy else 35.0)

	ambush_attack = false
	_drop_carried_lantern()
	_release_all_claims()

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if is_heavy or sub_state == SubState.GRAB or sub_state == SubState.CARRY:
		sub_state = SubState.STAGGER
		state = State.STAGGER
		state_timer = 1.4 if (src == LxHit.SOURCE_SUNFLARE or sunflare_unearth) else STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["surfaced"] = surfaced
	return d


func _step_brain(dt: float) -> void:
	ambush_cd = maxf(0.0, ambush_cd - dt)
	if ambush_attack:
		_step_ambush(dt)
		if surfaced and not _was_surfaced:
			LxDamageFx.boss_impact(pos, 0.06, 40.0, 52.0, 34.0, 1.15, 0.22)
		_was_surfaced = surfaced
		return
	if not _is_lantern_hung() and (sub_state == SubState.PERCH or sub_state == SubState.SHIFT):
		if _try_start_ambush():
			_was_surfaced = surfaced
			return
	super._step_brain(dt)
	# Surfaced when erupting at the lantern, wrestling/grabbing, baffled, dragging, or staggered
	match sub_state:
		SubState.GRAB, SubState.BAFFLED, SubState.CARRY, SubState.STAGGER:
			surfaced = true
		SubState.RUN:
			surfaced = pos.distance_to(run_to) <= ERUPT_DIST
		_:
			surfaced = false
	if surfaced and not _was_surfaced:
		LxDamageFx.boss_impact(pos, 0.06, 40.0, 52.0, 34.0, 1.15, 0.22)
	_was_surfaced = surfaced


func _try_start_ambush() -> bool:
	if ambush_cd > 0.0 or cooldown > 0.0 or not _has_player() or not _is_on_screen():
		return false
	var wp: Vector2 = _get_wick_pos()
	if pos.distance_to(wp) > notice_radius or wp.distance_to(home) > leash_radius:
		return false
	if not _claim_token():
		return false
	ambush_attack = true
	ambush_hit = false
	ambush_target = _clamp_point(wp)
	surfaced = false
	sub_state = SubState.TELL
	state = State.TELL
	is_counter_attack = false
	last_tell_duration = _scaled_tell(ASH_TELL_TIME, false, attack_damage)
	state_timer = last_tell_duration
	_emit_attack_started()
	_emit_sfx("ash_mole_tremor")
	return true


func _step_ambush(dt: float) -> void:
	if sub_state == SubState.TELL:
		state = State.TELL
		surfaced = false
		if state_timer > 0.22 * _assist_tell_scale() and _has_player():
			ambush_target = _clamp_point(_get_wick_pos())
		var to_t: Vector2 = ambush_target - pos
		if to_t.length() > 2.0:
			facing = to_t.angle()
			_move_step(to_t.limit_length(routine_speed * 0.85 * dt), false)
		state_timer -= dt
		if state_timer <= 0.0:
			sub_state = SubState.RUN
			state = State.COMMIT
			state_timer = AMBUSH_COMMIT_TIME
			ambush_hit = false
			_emit_sfx("ash_mole_erupt")
	elif sub_state == SubState.RUN:
		state = State.COMMIT
		var to_t: Vector2 = ambush_target - pos
		if to_t.length() > 2.0:
			facing = to_t.angle()
			_move_step(to_t.limit_length(AMBUSH_BURROW_SPEED * dt), false)
		if pos.distance_to(ambush_target) <= ERUPT_DIST or state_timer <= AMBUSH_COMMIT_TIME * 0.55:
			surfaced = true
		if surfaced and not ambush_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= AMBUSH_HIT_R:
			ambush_hit = true
			var hdir: Vector2 = (_get_wick_pos() - pos).normalized() if _get_wick_pos().distance_to(pos) > 0.01 else Vector2.from_angle(facing)
			_emit_player_hit(hdir)
		state_timer -= dt
		if state_timer <= 0.0:
			ambush_attack = false
			ambush_cd = AMBUSH_CD
			surfaced = true
			_release_all_claims()
			sub_state = SubState.BAFFLED
			state = State.RECOVER
			state_timer = maxf(MIN_RECOVER_TIME, AMBUSH_RECOVER)
			last_recover_duration = state_timer
			cooldown = AGAIN_CD
	else:
		ambush_attack = false


func _walk_to(dest: Vector2, spd: float, dt: float) -> bool:
	var d: Vector2 = dest - pos
	if d.length() <= 1.5:
		return true
	facing = d.angle()
	_move_step(d.limit_length(spd * dt), false)
	return pos.distance_to(dest) <= 1.5


func _body_color() -> Color:
	return PAL["plum"] as Color if surfaced else PAL["stone"] as Color


func _draw() -> void:
	if state == State.DEAD:
		return
	if surfaced:
		super._draw()
		return
	var off: Vector2 = _visual_offset()
	var c := Vector2(roundf(off.x), roundf(off.y))
	draw_circle(c + Vector2(0.0, 2.0), body_radius * 1.15, PAL["dusk"] as Color)
	draw_circle(c, body_radius * 0.85, PAL["stone"] as Color)
	var hot: bool = state == State.TELL or state == State.COMMIT
	for i: int in range(4):
		var ca: float = facing + float(i) * (PI * 0.5) + sin(anim_t * 7.0 + float(i)) * 0.18
		var cd: Vector2 = Vector2.from_angle(ca)
		var perp := Vector2(-cd.y, cd.x)
		var cr_len: float = (body_radius + 5.5) if hot else (body_radius + 2.5)
		var mid := Vector2(roundf(c.x + cd.x * (cr_len * 0.55) + perp.x * 1.4), roundf(c.y + cd.y * (cr_len * 0.55) + perp.y * 1.4))
		var tip := Vector2(roundf(c.x + cd.x * cr_len), roundf(c.y + cd.y * cr_len))
		draw_line(c, mid, PAL["coral"] as Color, 1.4 if hot else 1.0)
		draw_line(mid, tip, (PAL["apricot"] as Color) if hot else (PAL["wine"] as Color), 1.0)
		draw_rect(Rect2(roundf(c.x + cd.x * (body_radius + 1.5)), roundf(c.y + cd.y * (body_radius + 1.5) + 2.0), 1.0, 1.0), PAL["night"] as Color, true)
	for ci: int in range(3):
		var cp: float = fmod(anim_t * (2.6 if hot else 1.5) + float(ci) * 0.33, 1.0)
		var cx: float = roundf(c.x + sin(float(ci) * 2.3 + anim_t * 5.0) * (body_radius * 0.85))
		var cy: float = roundf(c.y - cp * (9.0 if hot else 6.0))
		var cc: Color = (PAL["gold"] as Color) if ci == 0 else ((PAL["apricot"] as Color) if ci == 1 else (PAL["coral"] as Color))
		draw_rect(Rect2(cx, cy, 1.0, 1.0), cc, true)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var locked_a: bool = state_timer <= 0.22 * _assist_tell_scale()
		var fred: bool = LxHudFx.flash_reduced()
		var tc: Vector2 = ((ambush_target - pos) if ambush_attack else c).round()
		if ambush_attack:
			draw_line(c, tc, PAL["wine"] as Color, 1.0)
			draw_circle(tc, AMBUSH_HIT_R, Color(PAL["coral"] as Color, lerpf(0.10, 0.20, prog)))
			var pulse_hi: bool = fred or (int(floorf(anim_t * 14.0)) % 2 == 0)
			var dash_c: Color = (PAL["gold"] if (locked_a and pulse_hi) else PAL["coral"]) as Color
			var spin_d: float = 0.0 if fred else anim_t * 1.4
			for di: int in range(10):
				var a0: float = spin_d + float(di) * (TAU / 10.0)
				var a1: float = a0 + 0.38
				draw_arc(tc, AMBUSH_HIT_R + 1.0, a0, a1, 4, PAL["void"] as Color, 2.2)
				draw_arc(tc, AMBUSH_HIT_R, a0, a1, 4, dash_c, 1.4)
		var r: float = roundf(lerpf(AMBUSH_HIT_R - 1.5 if ambush_attack else body_radius + 10.0, body_radius + 2.5, prog))
		draw_arc(tc, r, 0.0, TAU, 16, PAL["coral"] as Color, 1.5)
		draw_arc(tc, maxf(2.0, r - 2.0), 0.0, TAU, 12, (PAL["cream"] if locked_a else PAL["apricot"]) as Color, 1.0)
	elif state == State.COMMIT:
		var br: float = roundf(body_radius + 4.5 + (0.0 if LxHudFx.flash_reduced() else sin(anim_t * 22.0) * 1.0))
		draw_arc(c, br, 0.0, TAU, 14, PAL["apricot"] as Color, 1.8)
		draw_arc(c, maxf(2.0, br - 2.0), 0.0, TAU, 12, PAL["gold"] as Color, 1.0)


func _draw_extra(off: Vector2) -> void:
	super._draw_extra(off)
	if surfaced and _sprite_sheet == null:
		# Digging claws
		draw_line(off + Vector2(-3.0, 2.0), off + Vector2(-5.0, 5.0), PAL["gold"] as Color, 1.5)
		draw_line(off + Vector2(3.0, 2.0), off + Vector2(5.0, 5.0), PAL["gold"] as Color, 1.5)
	if surfaced and (state == State.TELL or state == State.COMMIT):
		var c := Vector2(roundf(off.x), roundf(off.y))
		var is_c: bool = state == State.COMMIT
		var sr: float = (body_radius + 8.0) if is_c else (body_radius + 5.5)
		for si: int in range(-1, 2, 2):
			var sa: float = facing + float(si) * 0.45
			draw_arc(c, sr + 1.5, sa - 0.55, sa + 0.55, 8, PAL["coral"] as Color, 2.0 if is_c else 1.4)
			draw_arc(c, sr, sa - 0.45, sa + 0.45, 8, PAL["apricot"] as Color, 1.4 if is_c else 1.0)
			if is_c:
				draw_arc(c, sr - 1.5, sa - 0.30, sa + 0.30, 6, PAL["gold"] as Color, 1.0)
				var td: Vector2 = Vector2.from_angle(sa + float(si) * 0.40)
				draw_rect(Rect2(roundf(c.x + td.x * sr), roundf(c.y + td.y * sr), 1.0, 1.0), PAL["cream"] as Color, true)
		for ei: int in range(5):
			var ep: float = fmod(anim_t * 3.2 + float(ei) * 0.21, 1.0)
			var ea: float = facing + (float(ei) - 2.0) * 0.55
			var er: float = body_radius + 2.0 + ep * 9.0
			var ec: Color = (PAL["cream"] as Color) if ei == 0 else ((PAL["gold"] as Color) if (ei % 2 == 1) else (PAL["coral"] as Color))
			draw_rect(Rect2(roundf(c.x + cos(ea) * er), roundf(c.y + sin(ea) * er - ep * 3.0), 1.0, 1.0), ec, true)
