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
	# Burrowed underground: ash mound + dirt tremor during TELL
	var off: Vector2 = _visual_offset()
	draw_circle(off + Vector2(0.0, 2.0), body_radius * 1.15, PAL["dusk"] as Color)
	draw_circle(off, body_radius * 0.85, PAL["stone"] as Color)
	if state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var r: float = lerpf(body_radius + 8.0, body_radius + 2.0, prog)
		draw_arc(off, r, 0.0, TAU, 16, PAL["coral"] as Color, 1.5)
		draw_arc(off, r * 0.6, 0.0, TAU, 12, PAL["apricot"] as Color, 1.0)
	elif state == State.COMMIT:
		draw_arc(off, body_radius + 5.0, 0.0, TAU, 14, PAL["apricot"] as Color, 2.0)


func _draw_extra(off: Vector2) -> void:
	super._draw_extra(off)
	if surfaced and _sprite_sheet == null:
		# Digging claws
		draw_line(off + Vector2(-3.0, 2.0), off + Vector2(-5.0, 5.0), PAL["gold"] as Color, 1.5)
		draw_line(off + Vector2(3.0, 2.0), off + Vector2(5.0, 5.0), PAL["gold"] as Color, 1.5)
