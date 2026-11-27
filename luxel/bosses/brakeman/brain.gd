class_name LxBrakemanBoss
extends LxBossBase
## Island 6 Ember Express Mini-Boss: THE BRAKEMAN (`train_r5`).
## Wind-swept Brake-Van Roof showdown with 2 iron Brake Wheels: lure his Coupling Charge into
## a Brake Wheel (or shoot the wheel) to brake the roof gale 60% for 6s (`train_brake=="braked"`)
## and trigger his comedy cap-spin dizzy stagger!
## P2 (<=58%): Opens lethal outer roof-eave gaps + passing overhead Tunnel Gantry Duck-Sweep!

const CHARGE_SPEED: float = 240.0
const BRAKE_DURATION: float = 6.0
const ROOF_WIND_FULL: float = 18.0
const ROOF_WIND_BRAKED: float = 7.0

var _charge_dir: Vector2 = Vector2.LEFT
var _aim_dir: Vector2 = Vector2.LEFT
var _brake_t: float = 0.0
var _wheel_spin_t: float = 0.0
var _wheel_positions: Array[Vector2] = []
var _gantry_x: float = 0.0
var _gantry_hit: bool = false
var _cap_spin_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "brakeman"
	boss_id = "brakeman"
	boss_name_key = "ISL6_BOSS_BRAKE"
	island_id = 6
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island6_boss_p1"
	music_p2_cue = "island6_boss_p2"
	max_hp = 62.0
	hp = 62.0
	body_radius = 10.0
	move_speed = 42.0
	stagger_threshold = 12.0
	stagger_duration = 1.85
	post_recover_cd = 0.28
	intro_duration = 0.55
	death_duration = 1.8
	shard_drop = 22


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.58])

	# Attack 1: Coupling Charge (bait into Brake Wheel to spin wheel & stagger!)
	register_attack("coupling_charge", {
		"weight": 1.35, "tell": 0.56, "commit": 0.42, "recover": 1.20, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_charge_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var dest: Vector2 = clamp_to_arena(pos + _charge_dir * 136.0)
			ground.warn_lane(pos, dest, 12.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("steam_whistle", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.play_sfx("coupler_snap", pos)
			stage.shake(0.14),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_charge_dir * CHARGE_SPEED * dt, false)
			check_contact_damage(body_radius + 11.0, _charge_dir, 1.0, "brakeman_charge")
			for wp_b: Vector2 in _wheel_positions:
				if pos.distance_to(wp_b) <= 18.0:
					_trigger_brake_wheel_bonk(wp_b)
					break,
	})

	# Attack 2: Chain Flail Arc (160 deg heavy hook sweep + chain spark fan!)
	register_attack("chain_flail_arc", {
		"weight": 1.20, "tell": 0.50, "commit": 0.28, "recover": 1.10, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var ang: float = _aim_dir.angle()
			ground.warn_sector(pos, ang - 1.35, ang + 1.35, 48.0, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("furnace_draw", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 1.05, 126.0 if phase >= 2 else 118.0, {"color": "apricot", "source": "brakeman_chain"})
			stage.play_sfx("warden_swing", pos)
			stage.shake(0.16),
	})

	# Attack 3: Cinder Hook Lob (targets Wick + nearest corner — pressures all 8 perimeter spots!)
	register_attack("cinder_hook_lob", {
		"weight": 1.15, "tell": 0.54, "commit": 0.32, "recover": 1.05, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_lob_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 24.0, 1.0, "coral", "gold")
			stage.play_sfx("coupler_snap", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 5 if phase >= 2 else 3, 0.72, 138.0, {"color": "gold", "source": "brakeman_sparks"})
			stage.play_sfx("golem_stomp", pos)
			stage.shake(0.14),
	})

	# Attack 4 (P2): Tunnel Gantry Duck-Sweep (overhead horizontal beam stripe + sweeping spark wall!)
	register_attack("tunnel_duck_sweep", {
		"phases": [2],
		"weight": 1.55, "tell": 0.65, "commit": 0.36, "recover": 1.15, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var r: Rect2 = arena_rect
			var beam_y: float = clampf(tgt.y, r.position.y + 20.0, r.end.y - 20.0)
			ground.warn_lane(Vector2(r.position.x, beam_y), Vector2(r.end.x, beam_y), 16.0, last_tell_duration, 1.0, "plum", "gold")
			_gantry_x = r.end.x
			_gantry_hit = false
			stage.play_sfx("steam_whistle", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			patterns.emit_sweep_wall(Vector2(arena_rect.end.x - 10.0, c.y), Vector2.LEFT, arena_rect.size.y - 24.0, 8, 3, 3, 114.0, {"color": "coral", "source": "brakeman_gantry"})
			stage.play_sfx("forge_gust", pos)
			stage.shake(0.20),
	})


func _on_reset_encounter() -> void:
	_brake_t = 0.0
	_wheel_spin_t = 0.0
	_cap_spin_t = 0.0
	_wheel_positions.clear()
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:ember_express", "train_brake", "running")
	var c: Vector2 = arena_rect.get_center()
	var w1: Vector2 = clamp_to_arena(c + Vector2(-42.0, -34.0))
	var w2: Vector2 = clamp_to_arena(c + Vector2(36.0, 34.0))
	_wheel_positions = [w1, w2]
	props.spawn_bell(w1, func(_p: Dictionary) -> void: _activate_brake_wheel(w1), "brake_wheel_n")
	props.spawn_bell(w2, func(_p: Dictionary) -> void: _activate_brake_wheel(w2), "brake_wheel_s")


func _activate_brake_wheel(at_p: Vector2) -> void:
	_brake_t = BRAKE_DURATION
	_wheel_spin_t = 1.6
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:ember_express", "train_brake", "braked")
	stage.play_sfx("coupler_snap", at_p)
	stage.light_burst(at_p, 52.0, 1.2, 0.24)


func _trigger_brake_wheel_bonk(at_p: Vector2) -> void:
	_activate_brake_wheel(at_p)
	_cap_spin_t = stagger_duration
	stage.play_sfx("steam_whistle", pos)
	stage.shake(0.20)
	# Force dizzy comedy cap-spin stagger!
	stagger_immunity_t = 0.0
	add_stagger(stagger_threshold)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if _brake_t > 0.0:
		_brake_t = maxf(0.0, _brake_t - dt)
		if _brake_t <= 0.0 and Lx.vars != null:
			Lx.vars.set_var("dungeon:ember_express", "train_brake", "running")
	if _wheel_spin_t > 0.0:
		_wheel_spin_t = maxf(0.0, _wheel_spin_t - dt)
	if _cap_spin_t > 0.0:
		_cap_spin_t = maxf(0.0, _cap_spin_t - dt)

	# Roof westward gale (dims 60% when brake wheel spun; never shoves into outer pits!)
	if engaged and boss_state != BossState.DEATH and Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead and arena_rect.grow(-24.0).has_point(w.global_position):
			var spd: float = ROOF_WIND_BRAKED if _brake_t > 0.0 else (ROOF_WIND_FULL * (1.18 if phase >= 2 else 1.0))
			if w.has_method("push_external"):
				w.call("push_external", Vector2(-spd, 0.0), "roof_wind")


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null or is_punishable():
		return dmg
	# Heavy steel apron slightly resists direct frontal non-pierce yellow bolts (Skip banks & Lance cut clean!)
	var fwd: Vector2 = Vector2.from_angle(facing)
	var from_dir: Vector2 = (hit.origin - pos).normalized() if hit.origin.distance_to(pos) > 0.1 else -hit.dir
	var from_front: bool = from_dir.dot(fwd) > 0.35
	if from_front and hit.source == LxHit.SOURCE_BOLT and not hit.pierce and not hit.cracks_armour:
		clank_t = 0.10
		return dmg * 0.62
	return dmg


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# Open two outer corner roof-eave cutouts cleanly reverted on reset_encounter()!
		stage.set_tiles(world_ctx, Rect2i(2, 1, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(18, 9, 1, 1), "pit")
		stage.play_sfx("miniboss_forge_roar", pos)
		stage.shake(0.22)
		stage.darkness_pulse(0.55, 0.85)


func _on_death_start() -> void:
	_brake_t = 0.0
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:ember_express", "train_brake", "running")
	stage.play_sfx("steam_whistle", pos)


func _build_lob_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
	return out


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 2 else PAL["dusk"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var fred: bool = is_flash_reduced()
	# Wind streaks across roof (dimmed when braked!)
	if engaged and boss_state != BossState.DEATH and not fred:
		var wind_a: float = 0.14 if _brake_t > 0.0 else 0.34
		var c_off: Vector2 = -pos
		for wi: int in range(5):
			var wx: float = fmod(arena_rect.end.x - anim_t * (55.0 if _brake_t > 0.0 else 155.0) - float(wi) * 58.0, arena_rect.size.x)
			if wx < 0.0: wx += arena_rect.size.x
			var wy: float = arena_rect.position.y + 18.0 + float(wi) * (arena_rect.size.y - 36.0) * 0.25
			var p0: Vector2 = (Vector2(arena_rect.position.x + wx, wy) + c_off).round()
			draw_line(p0, p0 + Vector2(-14.0, 0.0), Color(PAL["stone"] as Color, wind_a), 1.0)
	# Spinning brake-wheel glow halos
	for wp_b: Vector2 in _wheel_positions:
		var lp: Vector2 = (wp_b - pos).round()
		var col: Color = PAL["gold"] as Color if _brake_t > 0.0 else PAL["apricot"] as Color
		var spin: float = anim_t * ((2.5 if fred else 10.0) if _brake_t > 0.0 else 1.5)
		draw_arc(lp, 10.5, spin, spin + PI * 1.4, 14, Color(PAL["void"] as Color, 0.72), 3.0)
		draw_arc(lp, 10.5, spin, spin + PI * 1.4, 14, Color(col, 0.72), 1.0)
	# Comedy cap-spin sparkle ring on stagger
	if _cap_spin_t > 0.0 and boss_state == BossState.STAGGER:
		var cp: Vector2 = (off + Vector2(0.0, -body_radius - 10.0)).round()
		var ca: float = anim_t * (3.0 if fred else 14.0)
		draw_arc(cp, 8.0, ca, ca + PI, 10, PAL["void"] as Color, 3.0)
		draw_arc(cp, 8.0, ca, ca + PI, 10, PAL["gold"] as Color, 1.0)
