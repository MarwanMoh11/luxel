class_name LxPhantomOwlBrain
extends LxOwlBrain
## Phantom Owl Sentinel (Island 5, Starfall Observatory).
## Invisible & untargetable outside lantern/Lens light; briefly solidifies during COMMIT/RECOVER.
## Once revealed, obeys full Owl sightline lock (with LURE), stoop dive, and grounded recovery.

const HAND_LENS_FALLBACK: float = 68.0
const HUNG_LENS_FALLBACK: float = 118.0
const REVEAL_GRACE: float = 0.35

var revealed: bool = false
var reveal_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "phantom_owl"
	max_hp = 2.5
	hp = 2.5
	body_radius = 7.0
	routine_speed = 76.0
	leash_radius = DEFAULT_LEASH
	notice_radius = 126.0
	tell_time = LOCK_TIME
	recover_time = RECOVER_DEFAULT
	shard_drop = 4
	attack_damage = 1.0


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	revealed = bool(spec.get("start_revealed", false))
	reveal_t = REVEAL_GRACE if revealed else 0.0


func on_light(a: Variant, b: Variant = Vector2.ZERO, _source: String = "") -> void:
	if state == State.DEAD:
		return
	var in_light: bool = true
	if a is Vector2 and (b is float or b is int):
		in_light = pos.distance_to(a as Vector2) <= float(b) + body_radius
	elif (a is float or a is int) and b is Vector2:
		in_light = pos.distance_to(b as Vector2) <= float(a) + body_radius
	if in_light:
		var was_hidden: bool = not revealed
		reveal_t = maxf(reveal_t, REVEAL_GRACE)
		revealed = true
		if was_hidden:
			_emit_sfx("phantom_reveal")


func is_targetable() -> bool:
	if not revealed:
		return false
	return super.is_targetable()


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	if not revealed:
		_emit_sfx("phantom_miss")
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	return super.take_hit(hit)


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["revealed"] = revealed
	return d


func _step_brain(dt: float) -> void:
	reveal_t = maxf(0.0, reveal_t - dt)
	_check_lens_reveal()
	super._step_brain(dt)
	# Brief reveal during COMMIT / RECOVER / STAGGER so non-Lens encounters still read & punish dives
	if state == State.COMMIT or state == State.RECOVER or state == State.STAGGER:
		reveal_t = maxf(reveal_t, 0.16)
	revealed = reveal_t > 0.0


func _check_lens_reveal() -> void:
	var has_lens: bool = Lx.state != null and Lx.state.has_move("lens")
	if not has_lens:
		return
	var ldata: Dictionary = Lx.get_move_data("lens")
	var hand_r: float = float(ldata.get("hand_radius", HAND_LENS_FALLBACK))
	var hung_r: float = float(ldata.get("hung_radius", HUNG_LENS_FALLBACK))
	if _is_lantern_out():
		if pos.distance_to(_get_lantern_pos()) <= hung_r + body_radius:
			reveal_t = maxf(reveal_t, REVEAL_GRACE)
			return
	if _has_player() and pos.distance_to(_get_wick_pos()) <= hand_r + body_radius:
		reveal_t = maxf(reveal_t, REVEAL_GRACE)


func _body_color() -> Color:
	return PAL["sky"] as Color if revealed else PAL["deep"] as Color


func _draw() -> void:
	if state == State.DEAD:
		return
	if revealed:
		super._draw()
		return
	# Unrevealed: faint spectral shimmer only (no solid hitbox read)
	var off: Vector2 = _visual_offset()
	var pulse: float = 0.5 + 0.5 * sin(anim_t * 5.0)
	var ghost_col := Color(PAL["sky"] as Color, 0.22 + pulse * 0.10)
	draw_arc(off, body_radius * 0.9, 0.0, TAU, 14, ghost_col, 1.0)
	if state == State.TELL:
		var local_t: Vector2 = lock_target - pos
		var lock_col := Color(PAL["ice"] as Color, 0.35)
		draw_line(off, local_t, lock_col, 1.0)
		draw_arc(local_t, 3.0, 0.0, TAU, 10, lock_col, 1.0)


func _draw_extra(off: Vector2) -> void:
	super._draw_extra(off)
	if revealed:
		draw_arc(off, body_radius + 2.5, 0.0, TAU, 16, PAL["ice"] as Color, 1.0)
