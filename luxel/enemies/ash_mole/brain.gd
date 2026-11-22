class_name LxAshMoleBrain
extends LxSnatcherBrain
## Ash Mole (Island 6, Ashen Kiln).
## Burrows underground along ash perches; surfaces under a hung lantern after a 0.50s dirt tremor
## tell, then tries to drag it under during an 0.85s grab recovery.
## Untargetable while burrowed; vulnerable to BOTH bolts and heavy hits while surfaced!

const ASH_GRAB_TIME: float = 0.85
const ASH_TELL_TIME: float = 0.50
const ERUPT_DIST: float = 14.0

var surfaced: bool = false


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


func is_flying() -> bool:
	return false


func is_targetable() -> bool:
	return is_alive() and surfaced


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	if not surfaced:
		_emit_sfx("ash_mole_burrowed")
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var h: Dictionary = _read_hit(hit)
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var orig: Vector2 = h["origin"] as Vector2
	if is_heavy and state == State.STAGGER:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var is_opening: bool = sub_state == SubState.GRAB or sub_state == SubState.CARRY \
			or sub_state == SubState.BAFFLED or sub_state == SubState.STAGGER
	hp -= dmg
	flash_t = 0.14 if is_heavy else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (135.0 if is_heavy else 35.0)

	_drop_carried_lantern()
	_release_all_claims()

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	if is_heavy or sub_state == SubState.GRAB or sub_state == SubState.CARRY:
		sub_state = SubState.STAGGER
		state = State.STAGGER
		state_timer = 1.4 if str(h["source"]) == LxHit.SOURCE_SUNFLARE else STAGGER_TIME
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	_emit_enemy_hit(hit, HitResult.CHIPPED)
	return HitResult.CHIPPED


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["surfaced"] = surfaced
	return d


func _step_brain(dt: float) -> void:
	super._step_brain(dt)
	# Surfaced when erupting at the lantern, wrestling/grabbing, baffled, dragging, or staggered
	match sub_state:
		SubState.GRAB, SubState.BAFFLED, SubState.CARRY, SubState.STAGGER:
			surfaced = true
		SubState.RUN:
			surfaced = pos.distance_to(run_to) <= ERUPT_DIST
		_:
			surfaced = false


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
		var r: float = roundf(lerpf(body_radius + 8.5, body_radius + 2.5, prog))
		draw_arc(c, r, 0.0, TAU, 16, PAL["coral"] as Color, 1.5)
		draw_arc(c, maxf(2.0, r - 2.0), 0.0, TAU, 12, PAL["apricot"] as Color, 1.0)
	elif state == State.COMMIT:
		var br: float = roundf(body_radius + 4.5 + sin(anim_t * 22.0) * 1.0)
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
