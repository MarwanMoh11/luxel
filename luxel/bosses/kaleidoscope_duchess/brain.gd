class_name LxKaleidoscopeDuchessBoss
extends LxBossBase
## Island 7 Mini-Boss: KALEIDOSCOPE DUCHESS (Mirror Spire Mini-Boss #2, spire_r13).
## Splits into 4 chromatic copies (Gold / Blue / Rose / Ice) around the prism rotunda —
## ONLY the true Duchess casts a crisp SE truth shadow; the 3 fake copies cast NW/absent shadows!
## P1 (100-50%): 4-copy swaps + Chromatic Convergence inward rays.
## P2 (<=50%): Chandelier projects a slow 4-arm chromatic laser carousel (0.38 rad/s,
## Dash-crossable & deflectable). Reflecting her Blue arm or hitting with Blue/Beam triggers
## the comedy beat: all 3 fake copies gasp & cover their eyes together + 1.7s stagger!

const FACET_COLORS: Array[String] = ["gold", "sky", "rose", "ice"]

var _aim_dir: Vector2 = Vector2.LEFT
var _decoys: Array[Dictionary] = []
var _real_slot: int = 0
var _carousel_ang: float = 0.0
var _carousel_active_t: float = 0.0
var _carousel_hit_cd: float = 0.0
var _gasp_t: float = 0.0
var _decoy_pop_t: float = 0.0
var _decoy_pop_pos: Vector2 = Vector2.ZERO


func _init() -> void:
	super._init()
	kind = "kaleidoscope_duchess"
	boss_id = "kaleidoscope_duchess"
	boss_name_key = "ISL7_BOSS_DUCHESS"
	island_id = 7
	is_miniboss = true
	reward_heart = "none"
	music_cue = "island7_boss_p1"
	music_p2_cue = "island7_boss_p2"
	max_hp = 88.0
	hp = 88.0
	body_radius = 10.5
	move_speed = 38.0
	stagger_threshold = 14.0
	stagger_duration = 1.70
	post_recover_cd = 0.30
	shard_drop = 34


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Chromatic Convergence — 4 rays aim inward from all 4 copies; SE-shadow copy glows cream!
	register_attack("chromatic_convergence", {
		"weight": 1.35, "tell": 0.56, "commit": 0.30, "recover": 1.25, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 160.0), 10.0, last_tell_duration, 1.0, "gold", "cream")
			for dc: Dictionary in _decoys:
				var dp: Vector2 = dc["pos"] as Vector2
				var dd: Vector2 = (tgt - dp).normalized() if tgt.distance_to(dp) > 0.1 else -_aim_dir
				dc["dir"] = dd
				ground.warn_lane(dp, clamp_to_arena(dp + dd * 115.0), 8.0, last_tell_duration, 0.0, str(dc["col"]), "ice")
			stage.play_sfx("prism_chime", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _aim_dir, 5 if phase >= 2 else 3, 0.62, 148.0, {"color": "ice", "source": "duchess_ray", "reflectable": true})
			for dc: Dictionary in _decoys:
				var dp: Vector2 = dc["pos"] as Vector2
				var dd: Vector2 = dc["dir"] as Vector2
				patterns.emit_fan(dp, dd, 1, 0.0, 128.0, {"color": str(dc["col"]), "source": "decoy_ray", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("beam_fire", pos),
	})

	# Attack 2: Facet Swap — clockwise shuffle of all 4 chromatic copies + darting shards!
	register_attack("facet_swap", {
		"weight": 1.20, "tell": 0.48, "commit": 0.24, "recover": 0.95, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			ground.warn_ring(pos, 26.0, last_tell_duration, 0.0, "ice", "gold")
			for dc: Dictionary in _decoys:
				ground.warn_ring(dc["pos"] as Vector2, 22.0, last_tell_duration, 0.0, str(dc["col"]), "cream")
			stage.play_sfx("prism_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_real_slot = (_real_slot + 1) % 4
			_place_four_facets()
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 124.0, d.angle() + PI * 0.4, 0.75, {"color": "sky", "source": "facet_ring", "reflectable": true})
			stage.play_sfx("mirror_ping", pos),
	})

	# Attack 3: Stained Rain — chromatic diamond rings covering Wick & perimeter corners (no safe spots!)
	register_attack("stained_rain", {
		"weight": 1.10, "tell": 0.52, "commit": 0.32, "recover": 1.15, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var spots: Array[Vector2] = _corner_rain(tgt, 4 if phase >= 2 else 3)
			patterns.emit_rain(ground, spots, last_tell_duration, 22.0, 1.0, "rose", "gold")
			stage.play_sfx("prism_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, d, 3, 0.55, 138.0, {"color": "rose", "source": "stained_shard", "reflectable": true})
			stage.shake(0.12)
			stage.play_sfx("glass_shatter", pos),
	})

	# Attack 4 (Phase 2): Prism Carousel — 4-arm chromatic laser spinning at 0.38 rad/s + reflectable Blue arm!
	register_attack("prism_carousel", {
		"phases": [2], "weight": 1.50, "tell": 0.56, "commit": 0.90, "recover": 1.25, "cooldown": 2.4,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var ctr: Vector2 = arena_rect.get_center()
			for k: int in range(4):
				var a: float = _carousel_ang + float(k) * (PI * 0.5)
				ground.warn_lane(ctr, clamp_to_arena(ctr + Vector2.from_angle(a) * 145.0), 8.0, last_tell_duration, 0.0, FACET_COLORS[k], "cream")
			stage.play_sfx("prism_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_carousel_active_t = 0.90
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.RIGHT
			patterns.emit_fan(pos, d, 5, 0.85, 136.0, {"color": "sky", "source": "carousel_blue", "reflectable": true})
			stage.shake(0.16)
			stage.play_sfx("beam_fire", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			_carousel_ang = wrapf(_carousel_ang + 0.38 * dt, -PI, PI)
			_tick_carousel_damage(dt),
	})


func _on_reset_encounter() -> void:
	_real_slot = 0
	_carousel_ang = 0.0
	_carousel_active_t = 0.0
	_carousel_hit_cd = 0.0
	_gasp_t = 0.0
	_decoy_pop_t = 0.0
	_place_four_facets()


func _place_four_facets() -> void:
	_decoys.clear()
	var ctr: Vector2 = arena_rect.get_center()
	var rx: float = minf(68.0, arena_rect.size.x * 0.30)
	var ry: float = minf(42.0, arena_rect.size.y * 0.30)
	var slots: Array[Vector2] = [
		clamp_to_arena(ctr + Vector2(0.0, -ry)),
		clamp_to_arena(ctr + Vector2(rx, 0.0)),
		clamp_to_arena(ctr + Vector2(0.0, ry)),
		clamp_to_arena(ctr + Vector2(-rx, 0.0)),
	]
	pos = slots[_real_slot]
	position = pos.round()
	for si: int in range(4):
		if si == _real_slot:
			continue
		_decoys.append({
			"pos": slots[si], "col": FACET_COLORS[si],
			"dir": Vector2.LEFT, "popped_t": 0.0,
		})


func _tick_carousel_damage(dt: float) -> void:
	_carousel_hit_cd = maxf(0.0, _carousel_hit_cd - dt)
	if not _has_player() or _carousel_hit_cd > 0.0:
		return
	# Dash cleanly crosses carousel arms!
	if Lx.player is LxWick and (Lx.player as LxWick).is_dashing():
		return
	var wp: Vector2 = _get_wick_pos()
	var ctr: Vector2 = arena_rect.get_center()
	for k: int in range(4):
		var d: Vector2 = Vector2.from_angle(_carousel_ang + float(k) * (PI * 0.5))
		var ep: Vector2 = ctr + d * 145.0
		if Geometry2D.get_closest_point_to_segment(wp, ctr, ep).distance_to(wp) <= 8.5:
			_carousel_hit_cd = 0.65
			emit_boss_damage(d.orthogonal(), 1.0, "prism_carousel", ctr, true)
			return


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_carousel_active_t = maxf(0.0, _carousel_active_t - dt)
	_gasp_t = maxf(0.0, _gasp_t - dt)
	_decoy_pop_t = maxf(0.0, _decoy_pop_t - dt)
	for dc: Dictionary in _decoys:
		dc["popped_t"] = maxf(0.0, float(dc["popped_t"]) - dt)
	# Player bolts striking a chromatic decoy pop it into narrow sparkles!
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		for dc: Dictionary in _decoys:
			if float(dc["popped_t"]) > 0.0:
				continue
			var dp: Vector2 = dc["pos"] as Vector2
			for bi: int in range(w.bolts.size() - 1, -1, -1):
				var bv: Variant = w.bolts[bi]
				if bv is Object and (bv.get("pos") as Vector2).distance_to(dp) <= 13.0:
					w.bolts.remove_at(bi)
					dc["popped_t"] = 2.4
					_decoy_pop_t = 0.45
					_decoy_pop_pos = dp
					stage.play_sfx("mirror_ping", dp)
					break


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	# Comedy beat: reflecting her Blue arm / hitting with Blue or Beam makes all 3 fakes gasp & cover their eyes!
	if hit.is_blue() or src == "reflected_bolt" or (phase >= 2 and src == LxHit.SOURCE_BEAM and _carousel_active_t > 0.0):
		_gasp_t = 1.8
		stage.play_sfx("glass_shatter", pos)
		add_stagger(stagger_threshold * 0.85)
		return dmg * 1.45
	if boss_state == BossState.STAGGER:
		return dmg * 1.40
	return dmg


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		var c: Vector2 = arena_rect.get_center()
		# Arena change: 2 diamond corner pits + 2 prism pillars (rolled back cleanly on reset!)
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 2), "pit")
		props.spawn_pillar(c + Vector2(-46.0, -24.0), 4.0, "duchess_prism_w")
		props.spawn_pillar(c + Vector2(46.0, 24.0), 4.0, "duchess_prism_e")
		stage.darkness_pulse(0.56, 1.0)
		stage.shake(0.22)
		stage.play_sfx("prism_chime", pos)
		stage.play_sfx("glass_shatter", pos)


func _on_death_start() -> void:
	_decoys.clear()
	stage.play_sfx("glass_shatter", pos)
	stage.play_sfx("prism_chime", pos)


func _corner_rain(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, corners.size())):
		out.append(clamp_to_arena(corners[i]))
	return out


func _body_color() -> Color:
	return PAL["ice"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Real Duchess ALWAYS casts a crisp warm SE truth shadow!
	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 6.0), 11.0, 3.5, "se_gold", true)

	# 3 Chromatic Copies (casting NW lie shadows!)
	for dc: Dictionary in _decoys:
		if float(dc["popped_t"]) > 0.0:
			continue
		var lp: Vector2 = ((dc["pos"] as Vector2) - pos).round()
		var col: Color = LxPalette.color(str(dc["col"]), "ice")
		LxIsland7Rule.draw_truth_shadow(self, lp + Vector2(0.0, 6.0), 9.0, 3.0, "nw_wrong", false)
		# Chromatic diamond-wing moth silhouette
		draw_colored_polygon(PackedVector2Array([lp + Vector2(0, -16), lp + Vector2(14, -8), lp + Vector2(0, 2), lp + Vector2(-14, -8)]), Color(col, 0.58))
		draw_arc(lp + Vector2(0, -8), 7.5, 0.0, TAU, 14, col, 1.4)
		# Comedy beat: fake copies gasp & cover their eyes together!
		if _gasp_t > 0.0:
			draw_circle(lp + Vector2(-3.0, -10.0), 2.2, PAL["cream"] as Color)
			draw_circle(lp + Vector2(3.0, -10.0), 2.2, PAL["cream"] as Color)
			draw_circle(lp + Vector2(0.0, -5.0), 2.0, PAL["void"] as Color)

	if _decoy_pop_t > 0.0:
		var pp: Vector2 = (_decoy_pop_pos - pos).round()
		draw_arc(pp, 14.0 * (1.0 - _decoy_pop_t / 0.45) + 4.0, 0.0, TAU, 14, PAL["cream"] as Color, 1.2)

	# P2 Overhead Prism Chandelier 4-arm chromatic laser carousel!
	if _carousel_active_t > 0.0:
		var ctr: Vector2 = (arena_rect.get_center() - pos).round()
		draw_circle(ctr, 6.0, PAL["cream"] as Color)
		for k: int in range(4):
			var d: Vector2 = Vector2.from_angle(_carousel_ang + float(k) * (PI * 0.5))
			var ep: Vector2 = (ctr + d * 145.0).round()
			var lc: Color = LxPalette.color(FACET_COLORS[k], "ice")
			draw_line(ctr, ep, lc, 4.0)
			draw_line(ctr, ep, PAL["cream"] as Color, 1.4)
	if boss_state == BossState.TELL and active_attack_id == "chromatic_convergence":
		draw_arc(c, body_radius + 7.0, 0.0, TAU, 18, PAL["cream"] as Color, 1.6)
