class_name LxBrassShearKeeperBoss
extends LxBossBase
## Island 4 Mini-Boss A (hourglass_r5): The Brass Shear-Keeper.
## Blind topiary hedge-hound with oversized brass scissor jaws & back mainspring.
## Charges Wick, hung lanterns, or Echo Rose decoys. Baiting its Shear Charge into
## brass-thorn cages snips them open and jams its blades for 1.8 s (1.6x mainspring dmg)!

const CHARGE_DIST: float = 112.0
const CHARGE_SPEED: float = 285.0
const JAM_STAGGER_S: float = 1.80
const JAM_DMG_MULT: float = 1.60

var _charge_dir: Vector2 = Vector2.RIGHT
var _pounce_from: Vector2 = Vector2.ZERO
var _pounce_to: Vector2 = Vector2.ZERO
var _whirl_spin: float = 0.0
var _jammed: bool = false
var _thorn_cages: Array[Dictionary] = []   # [{id, pos, radius, intact}]
var _butterflies: Array[Dictionary] = []   # Death scene golden butterflies


func _init() -> void:
	super._init()
	kind = "boss_shear_keeper"
	boss_id = "boss_shear_keeper"
	boss_name_key = "ISL4_BOSS_SHEAR"
	island_id = 4
	is_miniboss = true
	reward_heart = "none"
	music_cue = "isl4_boss_minor_p1"
	music_p2_cue = "isl4_boss_minor_p2"
	max_hp = 64.0
	hp = 64.0
	body_radius = 11.0
	move_speed = 46.0
	stagger_threshold = 14.0
	stagger_duration = 1.65
	post_recover_cd = 0.28
	shard_drop = 45
	death_duration = 2.2


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.56])

	# Attack 1: Shear Charge — charges glowing decoy/Echo/Wick; snips brass-thorn cages & jams blades!
	register_attack("shear_charge", {
		"weight": 1.35, "tell": 0.55, "commit": 0.40, "recover": 1.15, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_pt: Vector2 = _pick_bright_target(tgt)
			_charge_dir = (aim_pt - pos).normalized() if aim_pt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _charge_dir.angle()
			var end_p: Vector2 = clamp_to_arena(pos + _charge_dir * CHARGE_DIST)
			ground.warn_lane(pos, end_p, 13.0, last_tell_duration, 0.0, "gold", "coral")
			stage.play_sfx("shear_clack", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.14)
			stage.play_sfx("shear_clack", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_charge_dir * (CHARGE_SPEED * (1.12 if phase >= 2 else 1.0)) * dt, false)
			check_contact_damage(17.0, _charge_dir, 1.0, "shear_charge")
			_check_snip_thorn_cages(),
	})

	# Attack 2: Clippings Fan — razor leaf volley + flanking thorn bolts
	register_attack("clippings_fan", {
		"weight": 1.15, "tell": 0.50, "commit": 0.28, "recover": 0.92, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = d.angle()
			ground.warn_sector(pos, d.angle() - 0.58, d.angle() + 0.58, 92.0, last_tell_duration, 0.0, "lime", "gold")
			stage.play_sfx("shear_clack", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var cnt: int = 7 if phase >= 2 else 5
			patterns.emit_fan(pos, d, cnt, 0.92, 150.0 if phase >= 2 else 136.0, {"color": "lime", "source": "clippings_fan"})
			if phase >= 2:
				patterns.emit_lane(pos, d, 2, 168.0, 0.11, {"color": "gold", "source": "clippings_lance"})
			stage.play_sfx("topiary_cleave", pos),
	})

	# Attack 3: Snap Pounce — leaps toward Wick + pressures nearest perimeter corner (anti-cheese!)
	register_attack("snap_pounce", {
		"weight": 1.10, "tell": 0.54, "commit": 0.34, "recover": 0.96, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_pounce_from = pos
			_pounce_to = clamp_to_arena(tgt)
			var drops: Array[Vector2] = [_pounce_to, _nearest_corner(tgt)]
			patterns.emit_rain(ground, drops, last_tell_duration, 24.0, 1.0, "gold", "coral")
			stage.play_sfx("warden_windup", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("shear_clack", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			var u: float = clampf(elapsed / 0.34, 0.0, 1.0)
			var desired: Vector2 = _pounce_from.lerp(_pounce_to, u)
			move_boss(desired - pos, true)
			check_contact_damage(16.0, (_pounce_to - _pounce_from).normalized(), 1.0, "snap_pounce")
			if u >= 0.95 and not _commit_hit_done:
				patterns.emit_gap_ring(pos, 8, 118.0, facing + PI * 0.4, 0.78, {"color": "gold", "source": "snap_shards"}),
	})

	# Attack 4 (Phase 2): Whirlwind Trim — sweeping scissor cyclone + leaf spiral
	register_attack("whirlwind_trim", {
		"phases": [2], "weight": 1.45, "tell": 0.60, "commit": 0.55, "recover": 1.25, "cooldown": 2.1,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_whirl_spin = facing
			ground.warn_ring(pos, 38.0, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_ring(clamp_to_arena(tgt), 20.0, last_tell_duration + 0.08, 1.0, "lime", "gold")
			stage.play_sfx("shear_whirl", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_spiral(pos, 4, 122.0, _whirl_spin, 0.46, 3, 0.17, {"color": "lime", "source": "whirlwind_trim"})
			stage.shake(0.18)
			stage.play_sfx("shear_whirl", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			facing = wrapf(facing + 14.0 * dt, -PI, PI)
			var to_w: Vector2 = tgt - pos
			if to_w.length() > 14.0:
				move_boss(to_w.normalized() * 34.0 * dt, false)
			check_contact_damage(32.0, to_w.normalized(), 1.0, "whirlwind_trim"),
	})


func _on_reset_encounter() -> void:
	_jammed = false
	_butterflies.clear()
	_thorn_cages.clear()
	var c: Vector2 = arena_rect.get_center()
	var offsets: Array[Vector2] = [
		Vector2(-68.0, -34.0),
		Vector2(68.0, -34.0),
		Vector2(0.0, 42.0),
	]
	for i: int in range(offsets.size()):
		var cp: Vector2 = clamp_to_arena(c + offsets[i])
		_thorn_cages.append({"id": "B%d" % (i + 1), "pos": cp, "radius": 13.0, "intact": true})


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if boss_state != BossState.STAGGER:
		_jammed = false
	for bf: Dictionary in _butterflies:
		bf["pos"] = (bf["pos"] as Vector2) + (bf["vel"] as Vector2) * dt
		bf["age"] = float(bf["age"]) + dt


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		# Fallen topiary hedge cross-lanes (rolled back cleanly on reset!)
		stage.set_tiles(world_ctx, Rect2i(4, 2, 1, 2), "wall")
		stage.set_tiles(world_ctx, Rect2i(15, 7, 1, 2), "wall")
		props.spawn_pillar(clamp_to_arena(c + Vector2(-44.0, 20.0)), 4.0, "hedge_lane_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(44.0, -20.0)), 4.0, "hedge_lane_e")
		stage.darkness_pulse(0.55, 0.90)
		stage.shake(0.22)
		stage.play_sfx("boss_roar", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if _jammed and boss_state == BossState.STAGGER:
		return dmg * JAM_DMG_MULT
	if hit != null and (hit.pierce or hit.cracks_armour):
		return dmg
	if not is_punishable():
		# Dense topiary hedge hide absorbs unfocused bolt spam; Beam pierces, recover/jam pays full!
		return dmg * 0.55
	return dmg


func _on_death_start() -> void:
	# Shears pop into golden butterflies fluttering upward!
	_butterflies.clear()
	for i: int in range(10):
		var a: float = (TAU * float(i)) / 10.0
		_butterflies.append({
			"pos": pos + Vector2.from_angle(a) * 6.0,
			"vel": Vector2(cos(a) * 24.0, -22.0 - float(i % 3) * 10.0),
			"age": 0.0,
		})


func _pick_bright_target(default_tgt: Vector2) -> Vector2:
	# Blind topiary hound prioritizes nearby hung lantern or Echo Rose glow!
	if _is_lantern_hung():
		var lp: Vector2 = _get_lantern_pos()
		if arena_rect.has_point(lp):
			return lp
	return default_tgt


func _check_snip_thorn_cages() -> void:
	# Check room bramble interactables first
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "bramble":
				var br: LxInteractable = it_v as LxInteractable
				if br.active and pos.distance_to(br.pos) <= body_radius + br.radius + 6.0:
					br.on_hit(LxHit.make(LxHit.SOURCE_BEAM, 5.0, _charge_dir, pos, 5.0, true, true, self, true))
					_trigger_blade_jam(br.pos)
					return
	# Check built-in arena brass-thorn cages (active in boss_lab / generic arenas)
	for cage: Dictionary in _thorn_cages:
		if not bool(cage["intact"]):
			continue
		var cp: Vector2 = cage["pos"] as Vector2
		if pos.distance_to(cp) <= body_radius + float(cage["radius"]) + 4.0:
			cage["intact"] = false
			_trigger_blade_jam(cp)
			return


func _trigger_blade_jam(at_p: Vector2) -> void:
	_jammed = true
	stagger_immunity_t = 0.0
	stagger_meter = 0.0
	_release_token()
	active_attack_id = ""
	_set_boss_state(BossState.STAGGER, JAM_STAGGER_S)
	staggered.emit(JAM_STAGGER_S)
	LxDamageFx.boss_impact(at_p, 0.16, 70.0, 74.0, 68.0, 1.32, 0.30, "gold")
	stage.play_sfx("shear_jam", at_p)


func _nearest_corner(tgt: Vector2) -> Vector2:
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	return corners[0]


func _body_color() -> Color:
	return (PAL["jade"] if phase >= 2 else PAL["pine"]) as Color


func _draw_boss_extra(_off: Vector2) -> void:
	# Draw intact brass-thorn cages in local space
	for cage: Dictionary in _thorn_cages:
		if not bool(cage["intact"]):
			continue
		var cp: Vector2 = ((cage["pos"] as Vector2) - pos).round()
		var r: float = float(cage["radius"])
		draw_circle(cp, r, Color(PAL["pine"] as Color, 0.45))
		draw_arc(cp, r, 0.0, TAU, 14, PAL["gold"] as Color, 1.6)
		draw_line(cp + Vector2(-r * 0.6, -r * 0.6), cp + Vector2(r * 0.6, r * 0.6), PAL["jade"] as Color, 1.6)
		draw_line(cp + Vector2(-r * 0.6, r * 0.6), cp + Vector2(r * 0.6, -r * 0.6), PAL["apricot"] as Color, 1.4)
		draw_circle(cp, 2.2, PAL["rose"] as Color)

	# Comedy beat: jammed blades make brass tail wag + mainspring glint!
	if _jammed and boss_state == BossState.STAGGER:
		var wag: float = sin(anim_t * 28.0) * 5.0
		var tail_p: Vector2 = (-Vector2.from_angle(facing) * 14.0 + Vector2(0.0, -4.0 + wag)).round()
		draw_circle(tail_p, 2.4, PAL["gold"] as Color)
		draw_circle(Vector2(0.0, -18.0), 3.0, PAL["cream"] as Color)

	# Death butterflies
	for bf: Dictionary in _butterflies:
		var bp: Vector2 = ((bf["pos"] as Vector2) - pos).round()
		var flap: float = 2.0 + absf(sin(anim_t * 18.0 + bp.x)) * 2.5
		draw_rect(Rect2(bp + Vector2(-flap, -1.0), Vector2(flap * 2.0, 2.0)), PAL["gold"] as Color)
		draw_rect(Rect2(bp, Vector2.ONE), PAL["cream"] as Color)
