class_name LxStairWardenBoss
extends LxBossBase
## Island 8 Endless Stair Boss (F4, F8, F12 — stair_r4, stair_r8, stair_r10): The Stair Warden.
## Evolves across 3 Tiers / Acts testing drafted Stair Boons:
##   Tier 1 (F4 Brass Halberdier): Halberd Cleave, Banister Lunge (crashes stone posts -> 1.8s stagger), Step-Shockwave.
##   Tier 2 (F8 Prism Lancer): Prism Lance beam (reflectable blue back-hit!), Star-Rift Dash, Spiral Volley.
##   Tier 3 (F12 Eclipse Sovereign): Outer treads crumble into pit void (rolled back on reset!), Sovereign Eclipse Sweep,
##     Star-Tread Drop + Crown Burst (Sunflare shatters crown!).
## When tier == 0 (default in boss_lab / boss_check), plays all 3 Acts seamlessly across Phases 1 -> 2 -> 3!

const CLEAVE_R: float = 48.0
const LUNGE_SPEED: float = 225.0

var tier: int = 0 # 0 = full 3-Act Ascension (P1->P2->P3); 1 = F4; 2 = F8; 3 = F12
var _cleave_dir: Vector2 = Vector2.LEFT
var _cleave_hit: bool = false
var _lunge_dir: Vector2 = Vector2.LEFT
var _lunge_hit: bool = false
var _lance_ang: float = 0.0
var _rift_dir: Vector2 = Vector2.RIGHT
var _rift_drop_t: float = 0.0
var _crown_intact: bool = false
var _crown_shatter_t: float = 0.0
var _panting_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "stair_warden"
	boss_id = "stair_warden"
	boss_name_key = "ISL8_BOSS_STAIR1"
	island_id = 8
	is_miniboss = false
	reward_heart = "none"
	music_cue = "island8_boss_p1"
	music_p2_cue = "island8_boss_p2"
	max_hp = 195.0
	hp = 195.0
	body_radius = 12.5
	move_speed = 44.0
	stagger_threshold = 20.0
	stagger_duration = 1.80
	post_stagger_immunity = 4.0
	punish_dmg_mult = 1.35
	post_recover_cd = 0.30
	intro_duration = 0.55
	phase_shift_duration = 0.65
	death_duration = 2.2
	shard_drop = 40


func _configure_boss(spec: Dictionary) -> void:
	tier = _resolve_tier(spec)
	if tier == 1:
		boss_name_key = "ISL8_BOSS_STAIR1"
		max_hp = 128.0
		configure_phases([0.50])
	elif tier == 2:
		boss_name_key = "ISL8_BOSS_STAIR1"
		max_hp = 168.0
		configure_phases([0.50])
	elif tier == 3:
		boss_name_key = "ISL8_BOSS_STAIR3"
		max_hp = 195.0
		configure_phases([0.66, 0.33])
	else:
		# Full 3-Act Ascension (F4 Halberdier -> F8 Prism Lancer -> F12 Eclipse Sovereign)
		boss_name_key = "ISL8_BOSS_STAIR1"
		max_hp = 195.0
		configure_phases([0.66, 0.33])
	hp = max_hp

	# Shared Act I / All-Tier: Halberd Cleave (tell 0.52s, commit 0.26s, recover 1.15s)
	register_attack("halberd_cleave", {
		"weight": 1.05, "tell": 0.52, "commit": 0.26, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_cleave_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _cleave_dir.angle()
			_cleave_hit = false
			var tc: String = _act_color()
			ground.warn_sector(pos, facing - 1.25, facing + 1.25, CLEAVE_R, last_tell_duration, 0.0, "coral", tc)
			ground.warn_lane(pos, clamp_to_arena(pos + _cleave_dir * 145.0), 9.0, last_tell_duration, 0.0, tc, "cream")
			stage.play_sfx("warden_swing", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _cleave_dir, 5 if _current_act() >= 2 else 3, 0.85, 138.0 + float(_current_act()) * 8.0, {"color": _act_color(), "source": "halberd_wave"})
			stage.shake(0.18)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_cleave_dir * 110.0 * dt, false)
			if not _cleave_hit and pos.distance_to(tgt) <= CLEAVE_R:
				var rel: Vector2 = tgt - pos
				if rel.length() < 1.0 or absf(angle_difference(facing, rel.angle())) <= 1.28:
					_cleave_hit = true
					emit_boss_damage(_cleave_dir, 1.0, "halberd_cleave", pos, true),
	})

	# Act I (F4 Halberdier): Banister Lunge + Step-Shockwave
	if tier == 0 or tier == 1:
		var act1_phases: Array = [1] if tier == 0 else []
		register_attack("banister_lunge", {
			"phases": act1_phases, "weight": 1.45, "tell": 0.56, "commit": 0.40, "recover": 1.20, "cooldown": 1.3,
			"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
				_lunge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
				facing = _lunge_dir.angle()
				_lunge_hit = false
				ground.warn_lane(pos, clamp_to_arena(pos + _lunge_dir * 120.0), 12.0, last_tell_duration, 0.0, "coral", "gold")
				patterns.emit_rain(ground, [clamp_to_arena(tgt)], last_tell_duration + 0.06, 20.0, 1.0, "gold", "coral")
				stage.play_sfx("bell_slam", pos),
			"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
				stage.shake(0.16)
				stage.play_sfx("warden_swing", pos),
			"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
				move_boss(_lunge_dir * LUNGE_SPEED * dt, false)
				if not _lunge_hit and pos.distance_to(tgt) <= 22.0:
					_lunge_hit = true
					emit_boss_damage(_lunge_dir, 1.0, "banister_lunge", pos, true)
				# Crashing into a stone banister pillar shatters it -> 1.8s stagger!
				for p: Dictionary in props.props:
					if str(p["state"]) == "idle" and str(p["kind"]) == "pillar" and pos.distance_to(p["pos"] as Vector2) <= 20.0:
						props._damage_prop(p, 99.0)
						stage.play_sfx("stone_break", pos)
						add_stagger(stagger_threshold)
						break,
		})
		register_attack("step_shockwave", {
			"phases": act1_phases, "weight": 1.35, "tell": 0.54, "commit": 0.34, "recover": 1.15, "cooldown": 1.4,
			"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
				ground.warn_ring(pos, 68.0, last_tell_duration, 1.0, "gold", "coral")
				patterns.emit_rain(ground, [clamp_to_arena(tgt), clamp_to_arena(tgt.lerp(arena_rect.get_center(), 0.4))], last_tell_duration + 0.05, 20.0, 1.0, "apricot", "gold")
				stage.play_sfx("bell_slam", pos),
			"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
				var aa: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
				patterns.emit_gap_ring(pos, 10, 126.0, aa + 0.55, 0.78, {"color": "gold", "source": "step_shockwave"})
				stage.shake(0.22)
				stage.play_sfx("stone_break", pos),
		})

	# Act II (F8 Prism Lancer): Prism Lance + Star-Rift Dash
	if tier == 0 or tier == 2 or tier == 3:
		var act2_phases: Array = [2] if tier == 0 else ([1, 2] if tier == 2 else [1])
		register_attack("prism_lance", {
			"phases": act2_phases, "weight": 1.45, "tell": 0.56, "commit": 0.42, "recover": 1.25, "cooldown": 1.5,
			"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
				_lance_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
				facing = _lance_ang
				var d1: Vector2 = Vector2.from_angle(_lance_ang)
				ground.warn_lane(pos, clamp_to_arena(pos + d1 * 170.0), 8.5, last_tell_duration, 0.0, "sky", "cream")
				stage.play_sfx("beam_charge", pos),
			"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
				var d1: Vector2 = Vector2.from_angle(_lance_ang)
				patterns.emit_chain_lightning([pos, clamp_to_arena(pos + d1 * 165.0)], 0.45, 8.0, 0.26, 0.5)
				patterns.emit_lane(pos, d1, 3, 142.0, 0.08, {"color": "sky", "source": "prism_lance", "reflectable": true})
				stage.shake(0.18)
				stage.play_sfx("beam_fire", pos),
		})
		register_attack("star_rift_dash", {
			"phases": act2_phases, "weight": 1.40, "tell": 0.52, "commit": 0.38, "recover": 1.20, "cooldown": 1.6,
			"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
				_rift_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
				facing = _rift_dir.angle()
				_rift_drop_t = 0.0
				ground.warn_lane(pos, clamp_to_arena(pos + _rift_dir * 110.0), 10.0, last_tell_duration, 0.0, "sky", "coral")
				stage.play_sfx("hollow_dash", pos),
			"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
				var aa: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
				patterns.emit_spiral(pos, 3, 118.0, aa, 0.40, 1, 0.14, {"color": "sky", "source": "spiral_volley"})
				stage.shake(0.15)
				stage.play_sfx("zip_streak", pos),
			"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
				move_boss(_rift_dir * 195.0 * dt, true)
				_rift_drop_t -= dt
				if _rift_drop_t <= 0.0:
					_rift_drop_t = 0.18
					ground.add_hazard_circle(pos, 11.5, 1.6, 0.5, "sky", true),
		})

	# Act III (F12 Eclipse Sovereign): Sovereign Eclipse Sweep + Crown Burst
	if tier == 0 or tier == 3:
		var act3_phases: Array = [3] if tier == 0 else [2, 3]
		register_attack("sovereign_eclipse_sweep", {
			"phases": act3_phases, "weight": 1.50, "tell": 0.62, "commit": 0.40, "recover": 1.35, "cooldown": 1.5,
			"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
				var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
				facing = aim.angle()
				ground.warn_sector(pos, facing - 1.25, facing + 1.25, 54.0, last_tell_duration, 0.5, "rose", "cream")
				patterns.emit_rain(ground, [clamp_to_arena(tgt)], last_tell_duration + 0.06, 20.0, 0.5, "rose", "gold")
				stage.play_sfx("beam_charge", pos),
			"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
				var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
				patterns.emit_fan(pos, aim, 5, 0.96, 136.0, {"color": "rose", "source": "eclipse_sweep"})
				patterns.emit_orbit(pos, 3, 40.0, 2.0, 1.8, {"color": "gold", "source": "orbit_tread"})
				stage.shake(0.22)
				stage.play_sfx("beam_fire", pos),
		})
		register_attack("crown_burst", {
			"phases": act3_phases, "weight": 1.35, "tell": 0.62, "commit": 0.40, "recover": 1.35, "cooldown": 2.2,
			"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
				var c: Vector2 = arena_rect.get_center()
				var s1: Vector2 = clamp_to_arena(c + (tgt - c).limit_length(48.0))
				var s2: Vector2 = clamp_to_arena(c - (s1 - c))
				ground.warn_safe_inversion(arena_rect, [s1, s2], 36.0, last_tell_duration + 0.14, 0.24, 0.5, "gold", "rose")
				stage.play_sfx("stair_tread_drop", pos),
			"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
				patterns.emit_expanding_square(pos, 3, 108.0, anim_t, 1, {"color": "cream", "source": "crown_burst"})
				stage.light_burst(pos, 96.0, 1.45, 0.35)
				stage.shake(0.22)
				stage.play_sfx("sunflare_burst", pos),
		})


func _resolve_tier(spec: Dictionary) -> int:
	var t_arg: int = int(spec.get("tier", 0))
	if t_arg >= 1 and t_arg <= 3:
		return t_arg
	if Lx.vars != null:
		var fl: int = int(Lx.vars.get_var("dungeon:stair", "stair_floor", 0))
		if fl >= 1 and fl <= 4:
			return 1
		if fl >= 5 and fl <= 8:
			return 2
		if fl >= 9:
			return 3
	return 0


func _current_act() -> int:
	if tier >= 1 and tier <= 3:
		return tier
	return clampi(phase, 1, 3)


func _on_reset_encounter() -> void:
	_cleave_hit = false
	_lunge_hit = false
	_rift_drop_t = 0.0
	_crown_intact = (_current_act() >= 3)
	_crown_shatter_t = 0.0
	_panting_t = 0.0
	boss_name_key = "ISL8_BOSS_STAIR3" if _current_act() >= 3 else "ISL8_BOSS_STAIR1"
	if _current_act() == 1:
		_spawn_banisters()


func _spawn_banisters() -> void:
	var c: Vector2 = arena_rect.get_center()
	for idx: int in range(4):
		var sx: float = -54.0 if (idx % 2 == 0) else 54.0
		var sy: float = -34.0 if idx < 2 else 34.0
		props.spawn_pillar(clamp_to_arena(c + Vector2(sx, sy)), 4.0, "banister_%d" % idx)


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		_panting_t = 0.65
		if tier == 0:
			props.clear()
			props.spawn_pillar(clamp_to_arena(c + Vector2(-56.0, 0.0)), 6.0, "prism_post_w")
			props.spawn_pillar(clamp_to_arena(c + Vector2(56.0, 0.0)), 6.0, "prism_post_e")
		if tier == 3:
			_drop_outer_treads()
		stage.darkness_pulse(0.60, 1.0)
		stage.shake(0.24)
		stage.play_sfx("beam_ready", pos)
	elif new_phase == 3:
		boss_name_key = "ISL8_BOSS_STAIR3"
		_crown_intact = true
		_drop_outer_treads()
		stage.darkness_pulse(0.72, 1.2)
		stage.shake(0.28)
		stage.play_sfx("stair_tread_drop", pos)


func _drop_outer_treads() -> void:
	var c: Vector2 = arena_rect.get_center()
	var cx_t: int = int(c.x / 16.0)
	var cy_t: int = int(c.y / 16.0)
	stage.set_tiles(world_ctx, Rect2i(maxi(2, cx_t - 6), maxi(2, cy_t - 3), 1, 1), "pit")
	stage.set_tiles(world_ctx, Rect2i(cx_t + 5, maxi(2, cy_t - 3), 1, 1), "pit")
	stage.set_tiles(world_ctx, Rect2i(maxi(2, cx_t - 6), cy_t + 3, 1, 1), "pit")
	stage.set_tiles(world_ctx, Rect2i(cx_t + 5, cy_t + 3, 1, 1), "pit")


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_crown_shatter_t = maxf(0.0, _crown_shatter_t - dt)
	_panting_t = maxf(0.0, _panting_t - dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var from_back: bool = rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) > 1.85
	var act: int = _current_act()
	if act == 2 and (hit.is_blue() or src == LxHit.SOURCE_PRISM or from_back):
		add_stagger(2.5)
		return dmg * 1.40
	if act >= 3 and _crown_intact and (src == LxHit.SOURCE_SUNFLARE or bool(h["cracks_armour"])):
		_crown_intact = false
		_crown_shatter_t = 2.4
		stage.play_sfx("shield_shatter", pos)
		add_stagger(stagger_threshold)
		return dmg * 1.50
	return dmg


func _on_death_start() -> void:
	stage.light_burst(pos, 112.0, 1.5, 0.45)
	stage.shake(0.24)
	stage.play_sfx("stone_break", pos)


func _act_color() -> String:
	var a: int = _current_act()
	return "gold" if a == 1 else ("sky" if a == 2 else "rose")


func _body_color() -> Color:
	return LxPalette.color(_act_color(), "gold")


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var act: int = _current_act()
	var trim_c: Color = LxPalette.color(_act_color(), "gold")
	if act >= 2 and boss_state != BossState.DEATH:
		# Orbiting Prism / Sovereign Crown ring around Stair Warden
		var r_halo: float = 19.0 if act == 2 else 23.0
		draw_arc(c + Vector2(0.0, -14.0), r_halo, anim_t * 1.4, anim_t * 1.4 + TAU * 0.72, 20, trim_c, 1.4)
		if act >= 3 and _crown_intact:
			for k: int in range(6):
				var ca: float = -anim_t * 1.6 + float(k) * (TAU / 6.0)
				var pt: Vector2 = (c + Vector2(0.0, -14.0) + Vector2.from_angle(ca) * (r_halo + 2.0)).round()
				draw_rect(Rect2(pt - Vector2.ONE, Vector2(2.0, 2.0)), PAL["cream"] as Color)
	if _crown_shatter_t > 0.0:
		var u: float = 1.0 - clampf(_crown_shatter_t / 2.4, 0.0, 1.0)
		draw_arc(c, lerpf(16.0, 56.0, u), 0.0, TAU, 20, Color(PAL["cream"] as Color, 1.0 - u), 1.8)
