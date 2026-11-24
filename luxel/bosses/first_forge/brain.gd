class_name LxFirstForgeBoss
extends LxBossBase
## Island 6 Superboss: THE FIRST FORGE (`superboss_first_forge`).
## Primordial four-armed obsidian-and-brass Anvil Deity that hammered all eight Great Lamps!
## Cycles 3 Forged Stances matching Wick's 3 Bolt Tempers (`gold`=SKIP, `apricot`=SCATTER, `coral`=LANCE);
## matching the active stance (or manual flank/Beam/Sunflare skill) doubles stagger & damage!
## P1 (100-65%): Stance cycling + World-Hammer Grid Slams + Shield-Wall / Ember-Swarm / Obsidian Anvil Drop.
## P2 (65-30%): MOLTEN GRID MUTATION — hammer strikes melt floor lanes into 5s lava channels + corner vents!
## P3 (<=30%): TEMPER OVERDRIVE — rotating Twin Crucible Beams + triple-stance finale!

enum Stance { SKIP_SHIELD, SCATTER_SWARM, LANCE_PLATE }

const SPIN_COMMIT_S: float = 0.92
const SPIN_RANGE: float = 128.0

var active_stance: int = Stance.SKIP_SHIELD
var _aim_dir: Vector2 = Vector2.LEFT
var _grid_axis_h: bool = true
var _spin_base_ang: float = 0.0
var _spin_hit: bool = false
var _stance_flash_t: float = 0.0
var _anvil_positions: Array[Vector2] = []


func _init() -> void:
	super._init()
	kind = "first_forge"
	boss_id = "first_forge"
	boss_name_key = "ISL6_BOSS_FIRST"
	island_id = 6
	is_miniboss = false
	reward_heart = "full"
	music_cue = "island6_boss_p1"
	music_p2_cue = "island6_boss_p2"
	max_hp = 215.0
	hp = 215.0
	body_radius = 13.5
	move_speed = 32.0
	stagger_threshold = 18.0
	stagger_duration = 2.25
	post_recover_cd = 0.40
	intro_duration = 0.60
	death_duration = 2.2
	shard_drop = 60


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.34])

	# Attack 1 (P1+P2+P3): World-Hammer Grid Slam (checker/lane cracks; P2+ melts lanes into molten channels!)
	register_attack("world_hammer_grid", {
		"weight": 1.25, "tell": 0.62, "commit": 0.32, "recover": 1.25, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_grid_axis_h = not _grid_axis_h
			var rects: Array[Rect2] = _build_grid_lanes(tgt)
			set_meta("_grid_rects", rects)
			for rr: Rect2 in rects:
				ground.warn_rect(rr, last_tell_duration, 1.0, "coral", "cream", 1.35 if phase >= 2 else 0.0)
			stage.play_sfx("anvil_clang_heavy", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else 0.0
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 114.0, gap_a, 0.78, {"color": "gold", "source": "forge_grid"})
			stage.play_sfx("magma_crack", pos)
			stage.shake(0.24),
	})

	# Attack 2 (P1+P2+P3): Stance-Wall Shield (SKIP stance — curved gold shields guard front; rear quench valve open!)
	register_attack("stance_wall_shield", {
		"weight": 1.25, "tell": 0.54, "commit": 0.36, "recover": 1.30, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_set_stance(Stance.SKIP_SHIELD)
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			var ang: float = _aim_dir.angle()
			ground.warn_sector(pos, ang - 0.72, ang + 0.72, 82.0, last_tell_duration, 1.0, "gold", "cream")
			stage.play_sfx("anvil_clang_skip", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var cnt: int = 5 if phase >= 2 else 3
			patterns.emit_fan(pos, _aim_dir, cnt, 1.05, 126.0, {"color": "gold", "source": "forge_shield_wave", "bounces": 1})
			stage.play_sfx("warden_swing", pos)
			stage.shake(0.18),
	})

	# Attack 3 (P1+P2+P3): Ember-Swarm Volley (SCATTER stance — orbiting sparks + perimeter rain!)
	register_attack("ember_swarm_volley", {
		"weight": 1.25, "tell": 0.54, "commit": 0.35, "recover": 1.25, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_set_stance(Stance.SCATTER_SWARM)
			var drops: Array[Vector2] = _build_perimeter_drops(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "apricot", "gold")
			stage.play_sfx("anvil_clang_scatter", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_orbit(pos, 4, 42.0, 2.3, 1.8, {"color": "apricot", "source": "forge_swarm"})
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.LEFT
			patterns.emit_fan(pos, d, 3, 0.72, 124.0, {"color": "coral", "source": "forge_swarm_shot"})
			stage.play_sfx("forge_gust", pos)
			stage.shake(0.16),
	})

	# Attack 4 (P1+P2+P3): Obsidian Anvil Drop (LANCE stance — levitates slag-anvil over Wick -> 38px slam!)
	register_attack("obsidian_anvil_drop", {
		"weight": 1.25, "tell": 0.60, "commit": 0.30, "recover": 1.40, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_set_stance(Stance.LANCE_PLATE)
			var drop_p: Vector2 = clamp_to_arena(tgt)
			set_meta("_anvil_drop_p", drop_p)
			ground.warn_ring(drop_p, 38.0, last_tell_duration, 1.0, "coral", "cream")
			stage.play_sfx("anvil_clang_lance", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var drop_p: Vector2 = get_meta("_anvil_drop_p", pos) as Vector2
			patterns.emit_ring(drop_p, 6, 118.0, 0.25, {"color": "coral", "source": "forge_anvil_ring"})
			stage.light_burst(drop_p, 76.0, 1.35, 0.28)
			stage.play_sfx("anvil_clang_heavy", drop_p)
			stage.shake(0.24),
	})

	# Attack 5 (P3): Crucible Spin (twin rotating molten slag streams + overdrive gap ring!)
	register_attack("crucible_spin", {
		"phases": [3],
		"weight": 2.10, "tell": 0.58, "commit": SPIN_COMMIT_S, "recover": 1.45, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_spin_base_ang = (tgt - pos).angle() + 0.55 if tgt.distance_to(pos) > 0.1 else 0.0
			_spin_hit = false
			for bi: int in range(2):
				var ba: float = _spin_base_ang + float(bi) * PI
				ground.warn_lane(pos, pos + Vector2.from_angle(ba) * SPIN_RANGE, 10.0, last_tell_duration, 0.0, "coral", "cream")
			stage.play_sfx("boss_kilnmother_roar", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_spiral(pos, 2, 118.0, _spin_base_ang, 0.34, 4, 0.18, {"color": "coral", "source": "forge_crucible_spin"})
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 0.1 else 0.0
			patterns.emit_gap_ring(pos, 10, 114.0, gap_a, 0.78, {"color": "gold", "source": "forge_spin_ring"})
			stage.play_sfx("beam_fire", pos)
			stage.shake(0.22),
	})


func _on_reset_encounter() -> void:
	active_stance = Stance.SKIP_SHIELD
	_grid_axis_h = true
	_spin_hit = false
	_stance_flash_t = 0.0
	_anvil_positions.clear()
	# Three Perimeter Temper Anvil markers (West=SKIP, North=SCATTER, East=LANCE)
	var c: Vector2 = arena_rect.get_center()
	var aw: Vector2 = clamp_to_arena(Vector2(arena_rect.position.x + 22.0, c.y))
	var an: Vector2 = clamp_to_arena(Vector2(c.x, arena_rect.position.y + 20.0))
	var ae: Vector2 = clamp_to_arena(Vector2(arena_rect.end.x - 22.0, c.y))
	_anvil_positions = [aw, an, ae]
	if not _room_has_temper_anvils():
		props.spawn_bell(aw, func(_p: Dictionary) -> void: _apply_temper_swap("skip", aw), "forge_anvil_skip")
		props.spawn_bell(an, func(_p: Dictionary) -> void: _apply_temper_swap("scatter", an), "forge_anvil_scatter")
		props.spawn_bell(ae, func(_p: Dictionary) -> void: _apply_temper_swap("lance", ae), "forge_anvil_lance")


func _room_has_temper_anvils() -> bool:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return false
	for it_v: Variant in (world_ctx.call("get_interactables") as Array):
		if it_v is LxInteractable and (it_v as LxInteractable).kind == "temper_anvil":
			return true
	return false


func _apply_temper_swap(mode: String, at_p: Vector2) -> void:
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).temper = mode
	if Lx.vars != null:
		Lx.vars.set_var("game", "wick_temper", mode)
	var cue: String = "anvil_clang_skip" if mode == "skip" else ("anvil_clang_scatter" if mode == "scatter" else "anvil_clang_lance")
	stage.play_sfx(cue, at_p)
	stage.light_burst(at_p, 48.0, 1.2, 0.24)


func _set_stance(next_s: int) -> void:
	if active_stance != next_s:
		active_stance = next_s
		_stance_flash_t = 0.45
		stage.play_sfx("forge_stance_shift", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	if _stance_flash_t > 0.0:
		_stance_flash_t = maxf(0.0, _stance_flash_t - dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var w_temper: String = duel.read_wick_temper().to_lower()
	var matched: bool = false
	match active_stance:
		Stance.SKIP_SHIELD:
			# Rear quench valve OR Skip temper / bounced prism shot triggers bonus crit + stagger!
			var fwd: Vector2 = Vector2.from_angle(facing)
			var from_dir: Vector2 = (hit.origin - pos).normalized() if hit.origin.distance_to(pos) > 0.1 else -hit.dir
			var from_back: bool = from_dir.dot(fwd) < -0.20
			matched = (w_temper == "skip") or hit.source == LxHit.SOURCE_PRISM_BOLT or from_back
		Stance.SCATTER_SWARM:
			matched = (w_temper == "scatter") or hit.source == LxHit.SOURCE_BEAM
		Stance.LANCE_PLATE:
			matched = (w_temper == "lance") or hit.cracks_armour or hit.pierce or hit.source == LxHit.SOURCE_SUNFLARE
	if matched:
		add_stagger(dmg * 0.65)
		return dmg * 1.35
	if is_punishable():
		return dmg
	# Mismatched frontal yellow shots still chip cleanly (0.82x — manual skill always wins!)
	if hit.source == LxHit.SOURCE_BOLT:
		return dmg * 0.82
	return dmg


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# MOLTEN GRID MUTATION: 4 obsidian casting pillars rise into the foundry floor (reverted on reset!)
		stage.set_tiles(world_ctx, Rect2i(4, 2, 1, 1), "wall")
		stage.set_tiles(world_ctx, Rect2i(15, 2, 1, 1), "wall")
		stage.set_tiles(world_ctx, Rect2i(4, 8, 1, 1), "wall")
		stage.set_tiles(world_ctx, Rect2i(15, 8, 1, 1), "wall")
		stage.play_sfx("anvil_clang_heavy", pos)
		stage.play_sfx("boss_kilnmother_roar", pos)
		stage.darkness_pulse(0.62, 0.95)
		stage.shake(0.28)
	elif new_phase == 3:
		stage.play_sfx("anvil_clang_heavy", pos)
		stage.light_burst(pos, 112.0, 1.5, 0.40)
		stage.shake(0.30)


func _on_death_start() -> void:
	# Four hammers strike a gentle D-minor blessing chord into Wick's lantern!
	stage.play_sfx("forge_bless_chord", pos)
	stage.play_sfx("great_lamp_bloom", pos)
	stage.light_burst(pos, 128.0, 1.6, 0.50)


func _build_grid_lanes(tgt: Vector2) -> Array[Rect2]:
	var r: Rect2 = arena_rect
	var out: Array[Rect2] = []
	if _grid_axis_h:
		var y1: float = clampf(tgt.y - 7.0, r.position.y + 8.0, r.end.y - 22.0)
		var y2: float = r.position.y + 12.0 if y1 > r.get_center().y else r.end.y - 26.0
		out.append(Rect2(r.position.x + 12.0, y1, r.size.x - 24.0, 14.0))
		out.append(Rect2(r.position.x + 12.0, y2, r.size.x - 24.0, 14.0))
	else:
		var x1: float = clampf(tgt.x - 8.0, r.position.x + 8.0, r.end.x - 24.0)
		var x2: float = r.position.x + 14.0 if x1 > r.get_center().x else r.end.x - 30.0
		out.append(Rect2(x1, r.position.y + 10.0, 16.0, r.size.y - 20.0))
		out.append(Rect2(x2, r.position.y + 10.0, 16.0, r.size.y - 20.0))
	return out


func _build_perimeter_drops(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-16.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	out.append(corners[1])
	return out


func _stance_color_key() -> String:
	match active_stance:
		Stance.SKIP_SHIELD: return "gold"
		Stance.SCATTER_SWARM: return "apricot"
		_: return "coral"


func _body_color() -> Color:
	return LxPalette.color(_stance_color_key(), "gold")


func _draw_boss_extra(off: Vector2) -> void:
	if boss_state == BossState.DEATH:
		return
	var sc: Color = LxPalette.color(_stance_color_key(), "gold")
	# Stance crest ring around the First Forge showing active Temper weakness (gold/apricot/coral!)
	var r: float = body_radius + 6.5 + (2.5 if _stance_flash_t > 0.0 else 0.0)
	draw_arc(off.round(), r, anim_t * 2.4, anim_t * 2.4 + PI * 1.35, 20, Color(sc, 0.78), 1.6)
	# Perimeter Temper Anvil badges (West=gold SKIP, North=apricot SCATTER, East=coral LANCE)
	var badge_cols: Array[String] = ["gold", "apricot", "coral"]
	for i: int in range(mini(_anvil_positions.size(), 3)):
		var ap: Vector2 = (_anvil_positions[i] - pos).round()
		var active_match: bool = (i == active_stance)
		draw_arc(ap, 11.0 if active_match else 9.0, 0.0, TAU, 16, Color(LxPalette.color(badge_cols[i], "gold"), 0.85 if active_match else 0.45), 1.6 if active_match else 1.1)
	# Twin rotating Crucible Spin beams during P3 commit
	if boss_state == BossState.COMMIT and active_attack_id == "crucible_spin":
		var cur_a: float = _spin_base_ang + (_commit_elapsed / SPIN_COMMIT_S) * PI * 1.15
		for bi: int in range(2):
			var bend: Vector2 = (off + Vector2.from_angle(cur_a + float(bi) * PI) * SPIN_RANGE).round()
			draw_line(off.round(), bend, PAL["wine"] as Color, 7.5)
			draw_line(off.round(), bend, PAL["coral"] as Color, 4.6)
			draw_line(off.round(), bend, PAL["gold"] as Color, 2.2)
			draw_line(off.round(), bend, PAL["cream"] as Color, 1.0)
