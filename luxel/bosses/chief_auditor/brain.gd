class_name LxChiefAuditorBoss
extends LxBossBase
## Island 8 Mini-Boss: The Chief Auditor (The Toll House, toll_r5).
## Brass abacus-beetle that AUDITS repetition: using the same move family twice in a row
## triggers a golden AUDIT STAMP reducing that move's damage to 0.50x for 4s (5s in P2),
## while rotating to a different move deals 1.35x + bonus stagger!
## P1 (100-50%): Audit Stamp Ring, Abacus Bead Volley, Ledger Charge.
## P2 (<=50%): Carapace cracks open revealing spinning brass abacus ribs, bouncing beads,
## 2 red-ink slow strips, and corner ink-well pits (rolled back cleanly on retry).

const STAMP_RING_R: float = 54.0
const CHARGE_SPEED: float = 230.0
const INK_STRIP_SIZE: Vector2 = Vector2(72.0, 18.0)

var _charge_dir: Vector2 = Vector2.LEFT
var _charge_hit: bool = false
var _last_move_family: String = ""
var _audited_family: String = ""
var _audit_timer: float = 0.0
var _scribble_t: float = 0.0
var _ink_strips: Array[Rect2] = []


func _init() -> void:
	super._init()
	kind = "chief_auditor"
	boss_id = "chief_auditor"
	boss_name_key = "ISL8_BOSS_AUDITOR"
	island_id = 8
	is_miniboss = true
	reward_heart = "half"
	music_cue = "isl8_boss_minor_p1"
	music_p2_cue = "isl8_boss_minor_p2"
	max_hp = 108.0
	hp = 108.0
	body_radius = 12.0
	move_speed = 40.0
	stagger_threshold = 18.0
	stagger_duration = 1.80
	post_stagger_immunity = 3.8
	punish_dmg_mult = 1.35
	post_recover_cd = 0.30
	intro_duration = 0.60
	phase_shift_duration = 0.68
	death_duration = 2.2
	shard_drop = 28


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Audit Stamp Ring (tell 0.56s, commit 0.24s, recover 1.15s)
	register_attack("audit_stamp_ring", {
		"weight": 1.25, "tell": 0.56, "commit": 0.24, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, STAMP_RING_R, last_tell_duration, 1.0, "gold", "coral", 0.25)
			var rain_pts: Array[Vector2] = [clamp_to_arena(tgt)]
			if phase >= 2:
				rain_pts.append(clamp_to_arena(tgt + Vector2(30.0, 0.0)))
			patterns.emit_rain(ground, rain_pts, last_tell_duration + 0.05, 22.0, 1.0, "coral", "gold")
			stage.play_sfx("auditor_ding", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			var cnt: int = 10 if phase >= 2 else 8
			patterns.emit_gap_ring(pos, cnt, 134.0 if phase >= 2 else 118.0, aim_a + 0.50, 0.68, {"color": "gold", "source": "audit_bead"})
			if not _last_move_family.is_empty():
				_stamp_audit(_last_move_family)
			stage.shake(0.18)
			stage.play_sfx("bell_slam", pos),
	})

	# Attack 2: Abacus Bead Volley (tell 0.52s, commit 0.34s, recover 1.05s)
	register_attack("abacus_bead_volley", {
		"weight": 1.25, "tell": 0.52, "commit": 0.34, "recover": 1.05, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = aim.angle()
			var perp := Vector2(-aim.y, aim.x)
			for off_i: int in range(-1, 2):
				var o: Vector2 = pos + perp * (float(off_i) * 14.0)
				ground.warn_lane(o, clamp_to_arena(o + aim * 155.0), 6.0, last_tell_duration, 0.0, "gold", "coral")
			stage.play_sfx("auditor_ding", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var perp := Vector2(-aim.y, aim.x)
			var spd: float = 152.0 if phase >= 2 else 136.0
			for off_i: int in range(-1, 2):
				var o: Vector2 = pos + perp * (float(off_i) * 14.0)
				patterns.emit_lane(o, aim, 3 if phase >= 2 else 2, spd, 0.08, {"color": "coral" if off_i == 0 else "gold", "source": "abacus_bead"})
			if phase >= 2:
				# Rebounding brass beads in P2!
				patterns.emit_boomerang(pos, aim.rotated(0.32), 146.0, 0.65, 0.45, {"color": "apricot", "source": "abacus_rebound"})
				patterns.emit_boomerang(pos, aim.rotated(-0.32), 146.0, 0.65, -0.45, {"color": "apricot", "source": "abacus_rebound"})
			stage.shake(0.14)
			stage.play_sfx("orrery_bolt", pos),
	})

	# Attack 3: Ledger Charge (tell 0.58s, commit 0.42s, recover 1.30s)
	register_attack("ledger_charge", {
		"weight": 1.20, "tell": 0.58, "commit": 0.42, "recover": 1.30, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_charge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _charge_dir.angle()
			_charge_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + _charge_dir * (CHARGE_SPEED * 0.44)), 14.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("warden_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.16)
			stage.play_sfx("hollow_dash", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			move_boss(_charge_dir * CHARGE_SPEED * dt, false)
			if not _charge_hit and check_contact_damage(20.0, _charge_dir, 1.0, "ledger_charge"):
				_charge_hit = true
			if phase >= 2 and int(elapsed * 20.0) % 4 == 0 and elapsed < 0.36:
				var perp := Vector2(-_charge_dir.y, _charge_dir.x)
				patterns.emit_fan(pos, perp, 1, 0.0, 108.0, {"color": "gold", "source": "abacus_spark"})
				patterns.emit_fan(pos, -perp, 1, 0.0, 108.0, {"color": "gold", "source": "abacus_spark"}),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			if not _charge_hit and _scribble_t <= 0.0:
				_scribble_t = 0.85,
	})


func _on_reset_encounter() -> void:
	_last_move_family = ""
	_audited_family = ""
	_audit_timer = 0.0
	_scribble_t = 0.0
	_charge_hit = false
	_ink_strips.clear()


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		# P2 Arena Change: 2 red-ink slow strips + 2 small corner ink pits (auto-rollback!)
		_ink_strips = [
			Rect2(c + Vector2(-78.0, -34.0), INK_STRIP_SIZE),
			Rect2(c + Vector2(6.0, 16.0), INK_STRIP_SIZE),
		]
		var cx_t: int = int(c.x / 16.0)
		var cy_t: int = int(c.y / 16.0)
		stage.set_tiles(world_ctx, Rect2i(maxi(2, cx_t - 5), maxi(2, cy_t - 3), 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(cx_t + 4, cy_t + 2, 1, 1), "pit")
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.24)
		stage.play_sfx("shield_shatter", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_scribble_t = maxf(0.0, _scribble_t - dt)
	if _audit_timer > 0.0:
		_audit_timer = maxf(0.0, _audit_timer - dt)
		if _audit_timer <= 0.0:
			_audited_family = ""
	# Apply gentle red-ink slow strips in P2 (movement drag only, never unwarned damage!)
	if not _ink_strips.is_empty() and Lx.player != null and is_instance_valid(Lx.player):
		var wp: Vector2 = _get_real_wick_pos()
		var gv: Variant = Lx.player.get("gliding")
		var gliding: bool = gv is bool and (gv as bool)
		if not gliding:
			var mw: Variant = Lx.player.get("move_wings")
			if mw is Object and is_instance_valid(mw):
				var mg: Variant = (mw as Object).get("gliding")
				gliding = mg is bool and (mg as bool)
		if not gliding and Lx.player.has_method("push_external"):
			for strip: Rect2 in _ink_strips:
				if strip.has_point(wp):
					var vel_v: Variant = Lx.player.get("vel")
					if vel_v is Vector2 and (vel_v as Vector2).length() > 4.0:
						Lx.player.call("push_external", -(vel_v as Vector2) * 0.36, "red_ink")
					break


func _stamp_audit(family: String) -> void:
	if family.is_empty():
		return
	_audited_family = family
	_audit_timer = 5.0 if phase >= 2 else 4.0
	stage.play_sfx("auditor_ding", pos)


func _hit_family(src: String) -> String:
	if src == LxHit.SOURCE_BOLT or src == LxHit.SOURCE_PRISM:
		return "bolt"
	if src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_ZIP:
		return "throw"
	if src == LxHit.SOURCE_BEAM:
		return "beam"
	if src == LxHit.SOURCE_DASH:
		return "dash"
	return "other"


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var fam: String = _hit_family(src)
	var rel: Vector2 = (h["origin"] as Vector2) - pos
	var from_rear: bool = rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) > 1.85

	# Rear brass hinge bonus (especially after Ledger Charge!)
	if from_rear and (fam == "throw" or boss_state == BossState.RECOVER):
		add_stagger(4.5)
		dmg *= 1.35

	# Audit repetition rule: repeating the same move family twice stamps it AUDITED!
	var mult: float = 1.0
	if fam != "other":
		if fam == _audited_family and _audit_timer > 0.0 and not is_punishable():
			clank_t = 0.12
			mult = 0.55
		elif fam == _last_move_family and _audited_family.is_empty() and not is_punishable():
			_stamp_audit(fam)
			mult = 0.85
		elif fam != _audited_family and not _audited_family.is_empty():
			# Rotating kit away from audited move earns a juicy bonus & extra stagger!
			mult = 1.35
			add_stagger(1.8)
		_last_move_family = fam
	return dmg * mult


func _on_death_start() -> void:
	_audited_family = ""
	_audit_timer = 0.0
	_ink_strips.clear()
	stage.shake(0.24)
	stage.play_sfx("auditor_ding", pos)


func _body_color() -> Color:
	return (PAL["plum"] if phase == 1 else PAL["coral"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# P2 Red-Ink slow strips
	for strip: Rect2 in _ink_strips:
		var rl := Rect2((strip.position - pos).round(), strip.size.round())
		draw_rect(rl.grow(1.0), Color(PAL["void"] as Color, 0.72), false, 1.0)
		draw_rect(rl, Color(PAL["wine"] as Color, 0.45), true)
		draw_rect(rl, PAL["coral"] as Color, false, 1.0)
	# Active AUDIT STAMP wax seal orbiting boss!
	if not _audited_family.is_empty() and _audit_timer > 0.0:
		var seal_p: Vector2 = (c + Vector2(0.0, -body_radius - 16.0)).round()
		draw_arc(seal_p, 6.0, 0.0, TAU, 14, PAL["void"] as Color, 4.0)
		draw_circle(seal_p, 6.0, PAL["coral"] as Color)
		draw_arc(seal_p, 6.0, 0.0, TAU, 14, PAL["gold"] as Color, 2.0)
		draw_line(seal_p + Vector2(-2.5, -2.5), seal_p + Vector2(2.5, 2.5), PAL["cream"] as Color, 1.0)
		draw_line(seal_p + Vector2(2.5, -2.5), seal_p + Vector2(-2.5, 2.5), PAL["cream"] as Color, 1.0)
	# Comedy beat: furiously scribbling tiny minus sign on miss!
	if _scribble_t > 0.0 and boss_state == BossState.RECOVER:
		var mp: Vector2 = (c + Vector2(14.0, -body_radius - 12.0)).round()
		draw_rect(Rect2(mp - Vector2.ONE, Vector2(8.0, 4.0)), PAL["void"] as Color)
		draw_rect(Rect2(mp, Vector2(6.0, 2.0)), PAL["coral"] as Color)
