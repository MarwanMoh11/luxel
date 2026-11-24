class_name LxSilverTideMimicBoss
extends LxBossBase
## Island 7 Mini-Boss: SILVER-TIDE MIMIC (Inverted Palace, palace_r5).
## Ornate silver chest on mercury crab-legs (NW shadow!) whose mercury maw copies Wick's
## exact last move! Bait with 1 Bolt -> punish 1.2s recovery with Throw/Beam; bait with Lens
## for a 1.2s comedy blush-stagger! P2 (<=50%) coats lid in Silver mirror armor (flip Black
## or Blue/Beam/Throw/Sunflare to crack!) + double-hop chomp + Quicksilver Spill puddles.

var _aim_dir: Vector2 = Vector2.LEFT
var _last_wick_move: String = "bolt"
var _copied_move: String = "bolt"
var _mirror_shell_hp: float = 0.0
var _shell_reform_t: float = 0.0
var _blush_t: float = 0.0
var _hop_stage: int = 0
var _wick_hooked: bool = false


func _init() -> void:
	super._init()
	kind = "silver_tide_mimic"
	boss_id = "silver_tide_mimic"
	boss_name_key = "ISL7_BOSS_MIMIC"
	island_id = 7
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island7_boss_p1"
	music_p2_cue = "island7_boss_p2"
	max_hp = 132.0
	hp = 132.0
	body_radius = 12.0
	move_speed = 38.0
	stagger_threshold = 22.0
	stagger_duration = 1.60
	post_recover_cd = 0.36
	shard_drop = 28


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Mimic Echo — copies Wick's exact last move!
	register_attack("mimic_echo", {
		"weight": 1.35, "tell": 0.56, "commit": 0.32, "recover": 1.20, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_copied_move = _last_wick_move
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			if _copied_move == "sunflare":
				ground.warn_ring(pos, 56.0, last_tell_duration, 1.0, "ice", "gold")
			elif _copied_move == "beam":
				ground.warn_lane(pos, pos + _aim_dir * 165.0, 11.0, last_tell_duration, 1.0, "sky", "cream")
			elif _copied_move != "lens":
				ground.warn_lane(pos, pos + _aim_dir * 135.0, 10.0, last_tell_duration, 0.0, "sky", "gold")
			stage.play_sfx("chest_creak", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_exec_mimic_echo(tgt),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			if _copied_move == "dash":
				move_boss(_aim_dir * 235.0 * dt, false)
				check_contact_damage(18.0, _aim_dir, 1.0, "mimic_dash"),
	})

	# Attack 2: Vaulting Chomp (P2 double-hop!) — lands with wide open jaw (1.5x dmg!)
	register_attack("vaulting_chomp", {
		"weight": 1.25, "tell": 0.48, "commit": 0.28, "recover": 1.25, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_hop_stage = 0
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, pos + _aim_dir * 76.0, 14.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("chest_creak", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("chest_open", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, el: float) -> void:
			if phase >= 2 and _hop_stage == 0 and el >= 0.15:
				_hop_stage = 1
				_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
				stage.play_sfx("mercury_splash", pos)
				patterns.emit_fan(pos, _aim_dir, 3, 0.65, 132.0, {"color": "sky", "source": "chomp_spray"})
			move_boss(_aim_dir * 210.0 * dt, false)
			check_contact_damage(20.0, _aim_dir, 1.0, "vaulting_chomp"),
	})

	# Attack 3: Silver Tide Wave (pressures all perimeter spots!)
	register_attack("silver_tide_wave", {
		"weight": 1.10, "tell": 0.52, "commit": 0.34, "recover": 1.15, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var drops: Array[Vector2] = _corner_targets(tgt, 2)
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "sky", "ice")
			stage.play_sfx("mercury_splash", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 128.0, _aim_dir.angle() + PI, 0.72, {"color": "ice", "source": "silver_tide", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("tide_wave", pos),
	})

	# Attack 4 (Phase 2): Quicksilver Spill — 4 lingering mercury puddles (crystallize in Black!)
	register_attack("quicksilver_spill", {
		"phases": [2], "weight": 1.45, "tell": 0.52, "commit": 0.35, "recover": 1.10, "cooldown": 2.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var spots: Array[Vector2] = _corner_targets(tgt, 4)
			var is_blk: bool = _is_black_world()
			for i: int in range(spots.size()):
				var sp: Vector2 = spots[i]
				ground.warn_ring(sp, 20.0, last_tell_duration + float(i) * 0.06, 1.0, "sky" if not is_blk else "rose", "ice", 0.0 if is_blk else 3.0)
			stage.play_sfx("mercury_splash", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 5, 0.80, 134.0, {"color": "sky", "source": "quicksilver_burst", "reflectable": true})
			stage.shake(0.16),
	})


func _exec_mimic_echo(tgt: Vector2) -> void:
	_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
	match _copied_move:
		"lens":
			# Comedy beat: baiting with Lens makes it flash a harmless radar ring & blush-stagger!
			_blush_t = 1.4
			stage.play_sfx("lens_reveal", pos)
			stagger_immunity_t = 0.0
			stagger_meter = stagger_threshold
			add_stagger(1.0)
		"dash":
			stage.play_sfx("hollow_dash", pos)
			patterns.emit_fan(pos, _aim_dir, 3, 0.35, 140.0, {"color": "ice", "source": "mimic_dash"})
		"throw":
			stage.play_sfx("lantern_throw", pos)
			patterns.emit_boomerang(pos, _aim_dir, 145.0, 0.65, 0.70, {"color": "sky", "source": "mimic_orb", "reflectable": true})
			if phase >= 2:
				patterns.emit_boomerang(pos, _aim_dir.rotated(0.35), 135.0, 0.65, -0.70, {"color": "ice", "source": "mimic_orb", "reflectable": true})
		"beam":
			stage.play_sfx("prism_beam", pos)
			patterns.emit_lane(pos, _aim_dir, 4 if phase >= 2 else 3, 175.0, 0.06, {"color": "ice", "source": "mimic_beam", "reflectable": true})
			stage.shake(0.16)
		"sunflare":
			stage.play_sfx("sunflare_burst", pos)
			patterns.emit_gap_ring(pos, 12, 120.0, _aim_dir.angle() + PI * 0.5, 0.72, {"color": "gold", "source": "mimic_flare"})
			stage.shake(0.18)
		_:
			stage.play_sfx("orrery_bolt", pos)
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 0.55, 148.0, {"color": "ice", "source": "mimic_bolt", "reflectable": true})


func _on_reset_encounter() -> void:
	_last_wick_move = "bolt"
	_copied_move = "bolt"
	_mirror_shell_hp = 0.0
	_shell_reform_t = 0.0
	_blush_t = 0.0
	_hop_stage = 0


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_blush_t = maxf(0.0, _blush_t - dt)
	_poll_wick_move()
	if phase >= 2 and _mirror_shell_hp <= 0.0 and not _is_black_world():
		_shell_reform_t -= dt
		if _shell_reform_t <= 0.0:
			_mirror_shell_hp = 4.5
			stage.play_sfx("shield_reform", pos)
	if _is_black_world() and _mirror_shell_hp > 0.0:
		_mirror_shell_hp = 0.0
		stage.play_sfx("glass_shatter", pos)


func _poll_wick_move() -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	if not _wick_hooked and Lx.player.has_signal("fired"):
		var cb := Callable(self, "_on_wick_fired")
		if not Lx.player.is_connected("fired", cb):
			Lx.player.connect("fired", cb)
		_wick_hooked = true
	if Lx.player.has_method("is_dashing") and bool(Lx.player.call("is_dashing")):
		_last_wick_move = "dash"
	var ml: Variant = Lx.player.get("move_lens")
	if ml is Object and (ml as Object).has_method("is_pulse_active") and bool((ml as Object).call("is_pulse_active")):
		_last_wick_move = "lens"


func _on_wick_fired(_dir: Vector2, fire_kind: String) -> void:
	if not fire_kind.is_empty():
		_last_wick_move = fire_kind


func _is_black_world() -> bool:
	if Lx.vars == null:
		return false
	return Lx.vars.eval("world_face==black", island_id, "")


func _has_active_shield() -> bool:
	return phase >= 2 and _mirror_shell_hp > 0.0 and not _is_black_world()


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if dmg >= max_hp * 0.25:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	if src in [LxHit.SOURCE_BOLT, LxHit.SOURCE_DASH, LxHit.SOURCE_THROW, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]:
		_last_wick_move = src
	var is_throw: bool = src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP]
	var breaks_shell: bool = hit.is_blue() or _is_black_world() or src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or is_throw or bool(h["cracks_armour"])

	# P2 Mirror-Shell Armor resists raw yellow bolts until cracked!
	if _has_active_shield():
		if breaks_shell:
			_mirror_shell_hp = 0.0
			_shell_reform_t = 7.5
			stage.play_sfx("glass_shatter", pos)
			return dmg * 1.15
		_mirror_shell_hp = maxf(0.0, _mirror_shell_hp - maxf(0.35, float(h["shield_wear"])))
		clank_t = 0.12
		stage.play_sfx("mirror_ping", pos)
		if _mirror_shell_hp <= 0.001:
			_shell_reform_t = 7.5
			stage.play_sfx("glass_shatter", pos)
		return dmg * 0.20

	# Wide-open jaw during RECOVER / STAGGER takes bonus damage (on top of LxBossBase 1.25x punish_dmg_mult)
	if boss_state == BossState.RECOVER or boss_state == BossState.STAGGER:
		if is_throw and boss_state == BossState.RECOVER:
			add_stagger(stagger_threshold)
		return dmg * 1.08
	# Closed heavy silver chest lid resists non-punish chips!
	if src == LxHit.SOURCE_BOLT and not hit.is_blue():
		return dmg * 0.22
	return dmg * 0.45


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_mirror_shell_hp = 0.0 if _is_black_world() else 4.5
		_shell_reform_t = 7.5
		# Arena change: two mercury corner pits (cleanly rolled back on reset_encounter!)
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 2), "pit")
		stage.darkness_pulse(0.55, 0.9)
		stage.shake(0.22)
		stage.play_sfx("glass_shatter", pos)


func _on_death_start() -> void:
	stage.play_sfx("glass_shatter", pos)


func _corner_targets(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-20.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, corners.size())):
		out.append(clamp_to_arena(corners[i]))
	return out


func _body_color() -> Color:
	return PAL["sky"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# NW shadow tell
	draw_circle(Vector2(-10.0, -6.0), 10.0, Color(PAL["void"] as Color, 0.35))
	# P2 Mirror-Shell crystalline ring
	if _has_active_shield():
		draw_arc(c, body_radius + 5.0, 0.0, TAU, 20, PAL["ice"] as Color, 2.0)
	# Floating holographic Mimic Echo move icon above lid during TELL!
	if boss_state == BossState.TELL and active_attack_id == "mimic_echo":
		var ip: Vector2 = (c + Vector2(0.0, -body_radius - 18.0)).round()
		var ic: Color = (PAL["rose"] if _copied_move == "lens" else (PAL["gold"] if _copied_move == "sunflare" else PAL["ice"])) as Color
		draw_circle(ip, 6.0, Color(PAL["night"] as Color, 0.85))
		draw_arc(ip, 6.0, 0.0, TAU, 16, ic, 1.4)
		if _copied_move == "beam":
			draw_line(ip + Vector2(-4.0, 0.0), ip + Vector2(4.0, 0.0), PAL["cream"] as Color, 1.6)
		elif _copied_move == "dash":
			draw_line(ip + Vector2(-3.0, -2.0), ip + Vector2(3.0, 0.0), PAL["cream"] as Color, 1.4)
			draw_line(ip + Vector2(-3.0, 2.0), ip + Vector2(3.0, 0.0), PAL["cream"] as Color, 1.4)
		else:
			draw_circle(ip, 2.2, PAL["cream"] as Color)
	if _blush_t > 0.0:
		draw_circle(c + Vector2(-6.0, -4.0), 2.5, PAL["rose"] as Color)
		draw_circle(c + Vector2(6.0, -4.0), 2.5, PAL["rose"] as Color)
