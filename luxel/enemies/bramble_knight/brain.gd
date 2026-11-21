class_name LxBrambleKnightBrain
extends LxWardenBrain
## Bramble Knight (Island 3): heavy gate guard with a 3.0-HP thorn shield that blocks
## normal bolts AND thrown lantern from front, answers with a 0.32s thorn burst counter,
## and is pierced & guard-broken straight through by Beam (pierce=true).

const THORN_BLOCK_HALF: float = 1.18
const THORN_COUNTER_TELL: float = 0.32
const THORN_COUNTER_R: float = 48.0
const THORN_BURST_R: float = 38.0
const THORN_BURST_TIME: float = 0.22
const GUARD_BREAK_STAGGER: float = 0.90

var thorn_burst_active: bool = false
var thorn_burst_hit: bool = false


func _init() -> void:
	kind = "bramble_knight"
	island_id = 3
	max_hp = 5.0
	hp = 5.0
	shield_max = 3.0
	shield_hp = 3.0
	shield_gone_duration = 5.0
	body_radius = 6.5
	routine_speed = 32.0
	leash_radius = 152.0
	notice_radius = 126.0
	reach = 36.0
	lunge_reach = 88.0
	swing_r = 28.0
	tell_time = 0.50
	lunge_tell_time = 0.58
	recover_time = 1.20
	give_up_time = 2.0
	shard_drop = 5


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	thorn_burst_active = false
	thorn_burst_hit = false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])
	var wear: float = float(h["shield_wear"])
	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < THORN_BLOCK_HALF

	# Beam (pierce=true) or Sunflare pierces straight through thorn shield and breaks guard!
	if (pierce or cracks) and _has_active_shield():
		shield_hp = 0.0
		shield_gone_t = shield_gone_duration
		wary = true
		thorn_burst_active = false
		lunge_attack = false
		is_counter_attack = false
		_release_token()
		shield_broken.emit(self, pos)
		_emit_sfx("bramble_guard_break")
		hp -= dmg
		flash_t = 0.18
		if rel.length() > 0.01:
			knock = -rel.normalized() * 120.0
		if hp <= 0.001:
			opened_kill = true
			_die(hit)
			return HitResult.KILLED
		state = State.STAGGER
		state_timer = GUARD_BREAK_STAGGER
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	# Front thorn shield blocks normal bolts AND thrown lantern from front.
	if _has_active_shield() and not pierce and not cracks and from_front \
			and (src == LxHit.SOURCE_BOLT or src == LxHit.SOURCE_PRISM or src == LxHit.SOURCE_THROW):
		clank_t = 0.18
		wary = true
		var eff_wear: float = wear * (0.75 if src == LxHit.SOURCE_THROW else 0.50)
		if _wear_shield(eff_wear):
			_emit_enemy_hit(hit, HitResult.OPENED)
			return HitResult.OPENED
		_emit_sfx("bramble_thorn_block")
		# Close-range hit on thorn shield triggers a thorn burst counter if token is available.
		if _has_player() and pos.distance_to(_get_wick_pos()) < THORN_COUNTER_R \
				and state != State.TELL and state != State.COMMIT \
				and _is_on_screen() and _claim_token(true):
			_begin_thorn_counter()
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	return super.take_hit(hit)


func _begin_thorn_counter() -> void:
	state = State.TELL
	is_counter_attack = true
	thorn_burst_active = true
	thorn_burst_hit = false
	lunge_attack = false
	last_tell_duration = _scaled_tell(THORN_COUNTER_TELL, true, attack_damage)
	state_timer = last_tell_duration
	_emit_attack_started()
	_emit_sfx("bramble_thorn_tell")


func _enter_commit() -> void:
	if thorn_burst_active:
		state = State.COMMIT
		state_timer = THORN_BURST_TIME
		thorn_burst_hit = false
		_emit_sfx("bramble_thorn_burst")
		return
	super._enter_commit()


func _step_commit(dt: float) -> void:
	if not thorn_burst_active:
		super._step_commit(dt)
		return
	if not thorn_burst_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if wv.length() <= THORN_BURST_R:
			thorn_burst_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else Vector2.from_angle(facing)
			_emit_player_hit(push)
	state_timer -= dt
	if state_timer <= 0.0:
		thorn_burst_active = false
		is_counter_attack = false
		_release_token()
		state = State.POSITION
		cooldown = COUNTER_COOLDOWN
		last_recover_duration = COUNTER_COOLDOWN


func _on_stagger_end(target_pos: Vector2) -> void:
	var tw: Vector2 = _get_wick_pos() - pos
	if _has_player() and tw.length() < THORN_COUNTER_R and _is_on_screen() and _claim_token(true):
		if tw.length() > 0.01:
			facing = tw.angle()
		_begin_thorn_counter()
	else:
		_release_token()
		state = State.POSITION
		var to_t: Vector2 = target_pos - pos
		if to_t.length() > 0.01:
			facing = to_t.angle()


func _body_color() -> Color:
	return PAL["pine"] as Color


func _shield_color() -> Color:
	return PAL["lime"] as Color


func _draw_extra(off: Vector2) -> void:
	# Horned bramble helmet silhouette.
	draw_line(off + Vector2(-4.0, -body_radius), off + Vector2(-6.5, -body_radius - 5.0), PAL["jade"] as Color, 1.8)
	draw_line(off + Vector2(4.0, -body_radius), off + Vector2(6.5, -body_radius - 5.0), PAL["jade"] as Color, 1.8)
	# Spiky thorn tines along active front shield.
	if _has_active_shield():
		for i: int in range(-2, 3):
			var a: float = facing + float(i) * 0.42
			var p0: Vector2 = off + Vector2.from_angle(a) * (body_radius + 2.0)
			var p1: Vector2 = off + Vector2.from_angle(a) * (body_radius + 6.5)
			draw_line(p0, p1, (PAL["cream"] as Color) if clank_t > 0.0 else (PAL["lime"] as Color), 1.5)
	if thorn_burst_active and state == State.TELL:
		var prog: float = 1.0 - clampf(state_timer / maxf(last_tell_duration, 0.05), 0.0, 1.0)
		draw_arc(off, lerpf(THORN_BURST_R, body_radius + 4.0, prog), 0.0, TAU, 20, PAL["gold"] as Color, 1.5)
	elif thorn_burst_active and state == State.COMMIT:
		draw_arc(off, THORN_BURST_R, 0.0, TAU, 20, PAL["coral"] as Color, 2.5)
		for k: int in range(8):
			var ka: float = float(k) * (TAU / 8.0)
			draw_line(off + Vector2.from_angle(ka) * body_radius, off + Vector2.from_angle(ka) * THORN_BURST_R, PAL["lime"] as Color, 1.5)
