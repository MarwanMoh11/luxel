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


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: String = "") -> void:
	if state == State.DEAD:
		return
	if source == "lantern_hand" or source == "lantern_recall":
		return
	var in_light: bool = true
	if a is Vector2 and (b is float or b is int):
		in_light = pos.distance_to(a as Vector2) <= float(b) + body_radius
	elif (a is float or a is int) and b is Vector2:
		in_light = pos.distance_to(b as Vector2) <= float(a) + body_radius
	if in_light:
		_apply_reveal()


func _apply_reveal() -> void:
	var was_hidden: bool = not revealed
	reveal_t = maxf(reveal_t, REVEAL_GRACE)
	revealed = true
	if was_hidden:
		LxDamageFx.boss_impact(pos, 0.0, 38.0, 48.0, 44.0, 1.22, 0.24)
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
	if Lx.state == null or not Lx.state.has_move("lens"):
		return
	var ldata: Dictionary = Lx.get_move_data("lens")
	var pulse_r: float = float(ldata.get("pulse_radius", 104.0))
	var hung_r: float = float(ldata.get("hung_radius", 78.0))
	if _is_lantern_out():
		if pos.distance_to(_get_lantern_pos()) <= hung_r + body_radius:
			_apply_reveal()
			return
	if _has_player() and Lx.player != null and is_instance_valid(Lx.player):
		var ml: Variant = Lx.player.get("move_lens")
		if ml is Object and (ml as Object).has_method("is_pulse_active") and bool((ml as Object).call("is_pulse_active")):
			if pos.distance_to(_get_wick_pos()) <= pulse_r + body_radius:
				_apply_reveal()


func _body_color() -> Color:
	return PAL["sky"] as Color if revealed else PAL["deep"] as Color


func _draw() -> void:
	if state == State.DEAD:
		return
	if revealed:
		super._draw()
		return
	# Unrevealed: opaque 20-colour spectral shimmer wisps (no solid hitbox read)
	var off: Vector2 = _visual_offset()
	var c := Vector2(roundf(off.x), roundf(off.y))
	var spin: float = anim_t * 2.2
	for wi: int in range(4):
		var wa: float = spin + float(wi) * (PI * 0.5)
		var wr: float = roundf(body_radius * 0.85 + sin(anim_t * 5.0 + float(wi)) * 1.0)
		draw_arc(c, wr, wa, wa + 0.55, 5, (PAL["plum"] as Color) if (wi % 2 == 0) else (PAL["dusk"] as Color), 1.0)
		var wp := Vector2(roundf(c.x + cos(wa + 0.9) * (wr + 1.5)), roundf(c.y + sin(wa + 0.9) * (wr + 1.5)))
		draw_rect(Rect2(wp, Vector2(1.0, 1.0)), (PAL["stone"] as Color) if (wi % 2 == 0) else (PAL["mauve"] as Color), true)
	if state == State.TELL:
		var lt := Vector2(roundf(lock_target.x - pos.x), roundf(lock_target.y - pos.y))
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		var locked_owl: bool = state_timer <= LOCK_AIM_CUTOFF * _assist_tell_scale()
		var fred: bool = LxHudFx.flash_reduced()
		var ring_c: Color = (PAL["coral"] if locked_owl else PAL["sky"]) as Color
		var hi_c: Color = (PAL["cream"] if locked_owl else PAL["ice"]) as Color
		var delta: Vector2 = lt - c
		var dist: float = delta.length()
		if dist > 6.0:
			var dir: Vector2 = delta / dist
			var shift: float = 0.0 if fred else fmod(anim_t * 18.0, 7.0)
			var steps: int = mini(24, int(dist / 7.0))
			for di: int in range(steps):
				var d0: float = float(di) * 7.0 + shift
				if d0 >= dist - 4.0:
					break
				var p0 := Vector2(roundf(c.x + dir.x * d0), roundf(c.y + dir.y * d0))
				var p1 := Vector2(roundf(c.x + dir.x * minf(d0 + 3.0, dist - 3.0)), roundf(c.y + dir.y * minf(d0 + 3.0, dist - 3.0)))
				draw_line(p0, p1, ring_c if (di % 2 == 0) else hi_c, 1.2 if locked_owl else 1.0)
		# Readable dashed ground target ring matching dive hit radius
		var fill_a: float = lerpf(0.10, 0.22, prog)
		draw_circle(lt, DIVE_HIT_R, Color(ring_c, fill_a))
		var rot_d: float = 0.0 if fred else anim_t * 1.6
		for si: int in range(8):
			var a0: float = rot_d + float(si) * (TAU / 8.0)
			var a1: float = a0 + 0.44
			draw_arc(lt, DIVE_HIT_R + 1.0, a0, a1, 4, PAL["void"] as Color, 2.2)
			draw_arc(lt, DIVE_HIT_R, a0, a1, 4, ring_c if (si % 2 == 0 or locked_owl) else hi_c, 1.4)
		var in_r: float = roundf(lerpf(DIVE_HIT_R * 0.80, 4.0, prog))
		draw_arc(lt, in_r, 0.0, TAU, 16, hi_c, 1.2)
		for ci: int in range(4):
			var cd: Vector2 = Vector2.from_angle(float(ci) * (PI * 0.5))
			var t0: Vector2 = (lt + cd * (DIVE_HIT_R - 2.5)).round()
			var t1: Vector2 = (lt + cd * (DIVE_HIT_R + 2.0)).round()
			draw_line(t0, t1, PAL["void"] as Color, 2.2)
			draw_line(t0, t1, hi_c, 1.2)
		draw_rect(Rect2(lt, Vector2(1.0, 1.0)), PAL["cream"] as Color, true)
	elif state == State.COMMIT:
		for si: int in range(-1, 2, 2):
			var perp := Vector2(-dive_dir.y, dive_dir.x)
			var w0 := Vector2(roundf(c.x + perp.x * (float(si) * 3.0)), roundf(c.y + perp.y * (float(si) * 3.0)))
			var w1 := Vector2(roundf(w0.x - dive_dir.x * 11.0), roundf(w0.y - dive_dir.y * 11.0))
			draw_line(w0, w1, PAL["plum"] as Color, 1.0)
			draw_rect(Rect2(w1, Vector2(1.0, 1.0)), PAL["stone"] as Color, true)


func _draw_extra(off: Vector2) -> void:
	super._draw_extra(off)
	if revealed:
		var c := Vector2(roundf(off.x), roundf(off.y))
		var rot: float = anim_t * 1.4
		var pulse: float = 0.5 + 0.5 * sin(anim_t * 6.0)
		var tick_len: float = roundf(2.0 + pulse * 2.5)
		draw_arc(c, body_radius + 2.5, 0.0, TAU, 16, PAL["sky"] as Color, 1.0)
		for qi: int in range(4):
			var qa: float = rot + float(qi) * (PI * 0.5)
			draw_arc(c, body_radius + 4.5, qa, qa + 0.85, 6, PAL["deep"] as Color, 1.2)
			draw_arc(c, body_radius + 3.0, qa + 0.15, qa + 0.65, 5, PAL["ice"] as Color, 1.0)
			var ca: float = float(qi) * (PI * 0.5)
			var cd: Vector2 = Vector2.from_angle(ca)
			var t0 := Vector2(roundf(c.x + cd.x * (body_radius + 3.0)), roundf(c.y + cd.y * (body_radius + 3.0)))
			var t1 := Vector2(roundf(c.x + cd.x * (body_radius + 3.0 + tick_len)), roundf(c.y + cd.y * (body_radius + 3.0 + tick_len)))
			draw_line(t0, t1, PAL["sky"] as Color, 1.0)
			draw_rect(Rect2(t1, Vector2(1.0, 1.0)), (PAL["cream"] as Color) if (qi % 2 == 0) else (PAL["ice"] as Color), true)
		for fi: int in range(-1, 2, 2):
			var fx: float = roundf(c.x + float(fi) * (body_radius + 3.5))
			var fy: float = roundf(c.y + sin(anim_t * 4.5 + float(fi)) * 2.0)
			draw_line(Vector2(fx, fy), Vector2(fx + float(fi) * 2.0, fy + 2.0), PAL["mauve"] as Color, 1.0)
			draw_rect(Rect2(fx + float(fi) * 2.0, fy + 2.0, 1.0, 1.0), PAL["stone"] as Color, true)
