class_name LxToastmasterBoss
extends LxBossBase
## Island 4 Set-Piece Boss (party_r5): The Toastmaster Automaton.
## Dapper clockwork banquet butler armed with boomerang Silver Trays, Cork Volleys, and
## formal Etiquette Charges. Ringing the Banquet Bell or presenting an Echo Rose "guest"
## forces a compulsive 2.2 s formal bow exposing his golden nape wind-up key for 2.0x dmg!

const BOW_STAGGER_S: float = 2.20
const BOW_DMG_MULT: float = 2.00
const CHARGE_DIST: float = 72.0

var _charge_dir: Vector2 = Vector2.RIGHT
var _bowing: bool = false
var _bell_pos: Vector2 = Vector2.ZERO
var _bell_cd: float = 0.0
var _bell_ring_t: float = 0.0
var _has_room_bell: bool = false
var _echo_bow_cd: float = 0.0
var _death_springs: Array[Dictionary] = []


func _init() -> void:
	super._init()
	kind = "boss_toastmaster"
	boss_id = "boss_toastmaster"
	boss_name_key = "ISL4_BOSS_TOAST"
	island_id = 4
	is_miniboss = true
	reward_heart = "none"
	music_cue = "isl4_boss_minor_p1"
	music_p2_cue = "isl4_boss_minor_p2"
	max_hp = 72.0
	hp = 72.0
	body_radius = 10.0
	move_speed = 38.0
	stagger_threshold = 12.5
	stagger_duration = 1.85
	punish_dmg_mult = 1.45
	post_recover_cd = 0.50
	shard_drop = 50
	death_duration = 2.4


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.55])

	# Attack 1: Silver Tray — boomerang platter throw (twin trays in P2) + teacup splash
	register_attack("silver_tray", {
		"weight": 1.30, "tell": 0.60, "commit": 0.36, "recover": 1.18, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = d.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + d * 138.0), 10.0, last_tell_duration, 0.0, "ice", "gold")
			ground.warn_ring(tgt, 16.0, last_tell_duration + 0.08, 1.0, "gold", "cream")
			stage.play_sfx("toast_glass_clink", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_boomerang(pos, d, 102.0, 0.55, 0.50, {"color": "ice", "radius": 4.0, "source": "silver_tray", "damage": 0.5})
			if phase >= 2:
				patterns.emit_boomerang(pos, d.rotated(0.42), 96.0, 0.58, -0.50, {"color": "sky", "radius": 4.0, "source": "silver_tray", "damage": 0.5})
			stage.play_sfx("toast_tray_fling", pos),
	})

	# Attack 2: Cork Volley — celebratory 3-4 cork fan + corner champagne splashes
	register_attack("cork_volley", {
		"weight": 1.25, "tell": 0.62, "commit": 0.30, "recover": 1.18, "cooldown": 1.85,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = d.angle()
			ground.warn_sector(pos, d.angle() - 0.66, d.angle() + 0.66, 98.0, last_tell_duration, 0.0, "gold", "apricot")
			var drops: Array[Vector2] = [tgt, _nearest_corner(tgt)]
			patterns.emit_rain(ground, drops, last_tell_duration + 0.06, 16.0, 1.0, "apricot", "gold")
			stage.play_sfx("toast_glass_clink", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var cnt: int = 4 if phase >= 2 else 3
			patterns.emit_fan(pos, d, cnt, 1.15, 96.0 if phase >= 2 else 90.0, {"color": "gold", "source": "cork_volley", "damage": 0.5})
			stage.shake(0.12)
			stage.play_sfx("toast_cork_pop", pos),
	})

	# Attack 3: Etiquette Charge — crisp 72 px formal waiter sweep + trailing toast bolts
	register_attack("etiquette_charge", {
		"weight": 1.20, "tell": 0.62, "commit": 0.36, "recover": 1.25, "cooldown": 1.95,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_charge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _charge_dir.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + _charge_dir * CHARGE_DIST), 12.0, last_tell_duration, 0.0, "wine", "gold")
			ground.warn_ring(tgt, 16.0, last_tell_duration + 0.08, 1.0, "wine", "gold")
			stage.play_sfx("toast_bow_creak", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.14)
			stage.play_sfx("hollow_dash", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			move_boss(_charge_dir * (CHARGE_DIST / 0.36) * dt, false)
			check_contact_damage(12.5, _charge_dir, 0.5, "etiquette_charge")
			if elapsed >= 0.16 and elapsed - dt < 0.16:
				patterns.emit_fan(pos, -_charge_dir, 3, 0.90, 88.0, {"color": "rose", "source": "etiquette_trail", "damage": 0.5}),
	})

	# Attack 4 (Phase 2): Banquet Toast — Final Course! 4-table perimeter rain + cork gap ring
	register_attack("banquet_toast", {
		"phases": [2], "weight": 1.85, "tell": 0.66, "commit": 0.40, "recover": 1.25, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_banquet_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 16.0, 1.0, "coral", "gold")
			stage.play_sfx("toast_glass_clink", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() + 0.45
			patterns.emit_gap_ring(pos, 8, 88.0, gap_a, 1.40, {"color": "gold", "source": "banquet_toast", "damage": 0.5})
			stage.light_burst(pos, 88.0, 1.35, 0.32)
			stage.shake(0.18)
			stage.play_sfx("toast_cork_pop", pos),
	})


func _on_reset_encounter() -> void:
	_bowing = false
	_bell_pos = arena_rect.get_center() + Vector2(-58.0, -28.0)
	_bell_cd = 0.0
	_bell_ring_t = 0.0
	_echo_bow_cd = 0.0
	_has_room_bell = _detect_room_bell()
	_death_springs.clear()


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		# Ornate tea-fountain pools & 2 banquet tables (rolled back cleanly on reset!)
		stage.set_tiles(world_ctx, Rect2i(8, 6, 1, 1), "water")
		stage.set_tiles(world_ctx, Rect2i(23, 6, 1, 1), "water")
		props.spawn_pillar(clamp_to_arena(c + Vector2(-46.0, 22.0)), 4.0, "banquet_table_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(46.0, -22.0)), 4.0, "banquet_table_e")
		stage.darkness_pulse(0.54, 0.90)
		stage.shake(0.20)
		stage.play_sfx("toast_cork_pop", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if boss_state != BossState.STAGGER:
		_bowing = false
	_bell_cd = maxf(0.0, _bell_cd - dt)
	_bell_ring_t = maxf(0.0, _bell_ring_t - dt)
	_echo_bow_cd = maxf(0.0, _echo_bow_cd - dt)

	# Check Echo Rose "honored guest" decoy -> triggers compulsive Etiquette Bow!
	if _echo_bow_cd <= 0.0 and boss_state != BossState.STAGGER and boss_state != BossState.DEATH:
		if _find_closer_echo_decoy(_get_real_wick_pos()) != null:
			_echo_bow_cd = 8.0
			_trigger_etiquette_bow()

	# Check Banquet Bell shots (both real room bell & fallback gazebo bell)
	_check_bell_ring()

	for sp: Dictionary in _death_springs:
		sp["pos"] = (sp["pos"] as Vector2) + (sp["vel"] as Vector2) * dt


func _check_bell_ring() -> void:
	if _bell_cd > 0.0 or boss_state == BossState.DEATH:
		return
	var bell_pts: Array[Vector2] = []
	if _has_room_bell and world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "bell":
				bell_pts.append((it_v as LxInteractable).pos)
	else:
		bell_pts.append(_bell_pos)
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.move_bolt == null or not (w.move_bolt.get("bolts") is Array):
		return
	for b_v: Variant in (w.move_bolt.get("bolts") as Array):
		if not (b_v is Dictionary) or not bool((b_v as Dictionary).get("active", true)):
			continue
		var bp: Vector2 = (b_v as Dictionary).get("pos", Vector2.INF) as Vector2
		for bell_p: Vector2 in bell_pts:
			if bp.is_finite() and bp.distance_to(bell_p) <= 13.0:
				(b_v as Dictionary)["active"] = false
				_bell_cd = 6.0
				_bell_ring_t = 0.55
				stage.play_sfx("toast_glass_clink", bell_p)
				_trigger_etiquette_bow()
				return


func _trigger_etiquette_bow() -> void:
	if boss_state in [BossState.DEATH, BossState.INTRO, BossState.PHASE_SHIFT]:
		return
	_bowing = true
	stagger_immunity_t = 0.0
	stagger_meter = 0.0
	_release_token()
	active_attack_id = ""
	_set_boss_state(BossState.STAGGER, BOW_STAGGER_S)
	staggered.emit(BOW_STAGGER_S)
	LxDamageFx.boss_impact(pos, 0.16, 72.0, 74.0, 72.0, 1.32, 0.30, "gold")
	stage.play_sfx("toast_bow_creak", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if _bowing and boss_state == BossState.STAGGER:
		return dmg * BOW_DMG_MULT
	if hit != null and (hit.source == LxHit.SOURCE_PRISM or hit.source == "reflected_bolt"):
		if not _bowing and stagger_immunity_t <= 0.0:
			_trigger_etiquette_bow()
		return dmg * 1.65
	if not is_punishable() and hit != null and hit.source == LxHit.SOURCE_BOLT:
		# Held Silver Platter slightly deflects frontal bolts (Beam & Throw punch through!)
		var h: Dictionary = _read_hit(hit)
		var to_hit: Vector2 = (h["origin"] as Vector2) - pos
		if to_hit.length_squared() > 1.0 and Vector2.from_angle(facing).dot(to_hit.normalized()) > 0.35:
			return dmg * 0.65
	return dmg


func _on_death_start() -> void:
	_death_springs.clear()
	for i: int in range(8):
		var a: float = (TAU * float(i)) / 8.0
		_death_springs.append({
			"pos": pos + Vector2(0.0, -14.0),
			"vel": Vector2(cos(a) * 28.0, -26.0 - float(i % 3) * 10.0),
		})
	stage.play_sfx("toast_bow_creak", pos)


func _detect_room_bell() -> bool:
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "bell":
				return true
	return false


func _nearest_corner(tgt: Vector2) -> Vector2:
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	return corners[0]


func _build_banquet_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	out.append(clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.45)))
	return out


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 2 else PAL["wine"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	# Fallback Banquet Bell when running in boss_lab
	if not _has_room_bell:
		var bp: Vector2 = (_bell_pos - pos).round()
		draw_circle(bp, 7.0, PAL["night"] as Color)
		draw_circle(bp, 5.5, (PAL["cream"] if _bell_ring_t > 0.0 else PAL["gold"]) as Color)
		draw_rect(Rect2(bp + Vector2(-4.0, 3.0), Vector2(8.0, 2.0)), PAL["apricot"] as Color)
		if _bell_ring_t > 0.0:
			draw_arc(bp, 11.0 + (0.55 - _bell_ring_t) * 24.0, 0.0, TAU, 16, PAL["gold"] as Color, 1.4)

	# Comedy indicator: exposed spinning wind-up key during compulsive formal bow!
	if _bowing and boss_state == BossState.STAGGER:
		var kp: Vector2 = (off + Vector2(0.0, -24.0)).round()
		var fred: bool = is_flash_reduced()
		var spin: float = roundf((sin(anim_t * 5.0) * 1.4) if fred else (sin(anim_t * 20.0) * 4.0))
		draw_circle(kp, 4.5, PAL["gold"] as Color)
		draw_line((kp + Vector2(-spin, -3.0)).round(), (kp + Vector2(spin, 3.0)).round(), PAL["cream"] as Color, 1.6)

	# Death wind-up springs & teacup steam
	for sp: Dictionary in _death_springs:
		var pp: Vector2 = ((sp["pos"] as Vector2) - pos).round()
		draw_arc(pp, 2.5, 0.0, TAU, 8, PAL["gold"] as Color, 1.2)
		draw_rect(Rect2(pp, Vector2.ONE), PAL["cream"] as Color)
