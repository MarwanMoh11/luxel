class_name LxBossPatterns
extends RefCounted
## Fair boss bullet & hazard pattern emitters + LxBossBolt object pool.
## Supports ring, gap_ring, fan, spiral, lane, sweep_wall, rain, orbit,
## chain_lightning, expanding_square, boomerang, and pillars.

const PAL: Dictionary = LxPalette.PAL
const POOL_SIZE: int = 96
const MAX_SPIRALS: int = 16
const MAX_LANES: int = 24
const MAX_LIGHTNINGS: int = 16
const MAX_PILLARS: int = 32
const MIN_GAP_PX: float = 28.0
const MIN_TELL_S: float = 0.45

var boss: LxEnemyBrain = null
var pool: Array[LxBossBolt] = []
var _spirals: Array[Dictionary] = []
var _lanes: Array[Dictionary] = []
var _lightnings: Array[Dictionary] = []
var _pillars: Array[Dictionary] = []
var _clock: float = 0.0


func _init(p_boss: LxEnemyBrain = null) -> void:
	boss = p_boss
	pool.resize(POOL_SIZE)
	for i: int in range(POOL_SIZE):
		pool[i] = LxBossBolt.new()


func clear() -> void:
	for b: LxBossBolt in pool:
		b.deactivate()
	_spirals.clear()
	_lanes.clear()
	_lightnings.clear()
	_pillars.clear()


func active_bolt_count() -> int:
	var n: int = 0
	for b: LxBossBolt in pool:
		if b.active:
			n += 1
	return n


func is_point_in_danger(p: Vector2) -> bool:
	for pl: Dictionary in _pillars:
		if p.distance_to(pl["pos"] as Vector2) <= float(pl["radius"]) + 4.0:
			return true
	for lt: Dictionary in _lightnings:
		var pts: Array = lt["pts"] as Array
		var hw: float = float(lt["half_w"]) + 4.0
		for k: int in range(pts.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, pts[k] as Vector2, pts[k + 1] as Vector2).distance_to(p) <= hw:
				return true
	return false


func freeze_bolts_in_radius(center: Vector2, rad: float, duration: float, tag: String = "hook") -> int:
	var count: int = 0
	for b: LxBossBolt in pool:
		if b.active and not b.reflected and b.pos.distance_to(center) <= rad + b.radius:
			b.freeze(duration, tag)
			count += 1
	return count


func clear_bolts_in_radius(center: Vector2, rad: float) -> int:
	var count: int = 0
	for b: LxBossBolt in pool:
		if b.active and not b.reflected and b.pos.distance_to(center) <= rad + b.radius:
			b.deactivate()
			count += 1
	return count


func _alloc_bolt(origin: Vector2, dir: Vector2, speed: float, cfg: Dictionary = {}) -> LxBossBolt:
	for b: LxBossBolt in pool:
		if not b.active:
			b.reset(origin, dir, speed, cfg)
			return b
	# Recycle oldest non-reflected bolt if pool is saturated
	var oldest: LxBossBolt = pool[0]
	for b: LxBossBolt in pool:
		if not b.reflected and b.age > oldest.age:
			oldest = b
	oldest.reset(origin, dir, speed, cfg)
	return oldest


# --- 12 Fair Pattern Emitters ------------------------------------------------

func emit_ring(origin: Vector2, count: int, speed: float, start_ang: float = 0.0, cfg: Dictionary = {}) -> void:
	var n: int = clampi(count, 3, 18)
	var step: float = TAU / float(n)
	for i: int in range(n):
		var d: Vector2 = Vector2.from_angle(start_ang + float(i) * step)
		_alloc_bolt(origin + d * 6.0, d, speed, cfg)


func emit_gap_ring(origin: Vector2, count: int, speed: float, gap_ang: float, gap_arc: float = 0.65, cfg: Dictionary = {}) -> void:
	var n: int = clampi(count, 4, 22)
	var safe_arc: float = maxf(0.45, gap_arc)
	var step: float = TAU / float(n)
	for i: int in range(n):
		var ang: float = wrapf(gap_ang + float(i) * step, -PI, PI)
		if absf(angle_difference(ang, gap_ang)) < safe_arc * 0.5:
			continue
		var d: Vector2 = Vector2.from_angle(ang)
		_alloc_bolt(origin + d * 6.0, d, speed, cfg)


func emit_fan(origin: Vector2, aim_dir: Vector2, count: int, spread_rad: float, speed: float, cfg: Dictionary = {}) -> void:
	var n: int = clampi(count, 1, 13)
	var base: Vector2 = aim_dir.normalized() if aim_dir.length_squared() > 0.0001 else Vector2.RIGHT
	if n == 1:
		_alloc_bolt(origin + base * 6.0, base, speed, cfg)
		return
	var mid: float = float(n - 1) * 0.5
	var step: float = spread_rad / float(n - 1)
	for i: int in range(n):
		var d: Vector2 = base.rotated((float(i) - mid) * step)
		_alloc_bolt(origin + d * 6.0, d, speed, cfg)


func emit_spiral(origin: Vector2, arms: int, speed: float, base_ang: float, spin_step: float, waves: int, interval: float, cfg: Dictionary = {}) -> void:
	if _spirals.size() >= MAX_SPIRALS:
		_spirals.remove_at(0)
	_spirals.append({
		"origin": origin, "follow_boss": bool(cfg.get("follow_boss", true)),
		"arms": clampi(arms, 2, 8), "speed": speed, "ang": base_ang,
		"spin": spin_step, "waves_left": clampi(waves, 1, 10),
		"interval": maxf(0.08, interval), "timer": 0.0, "cfg": cfg.duplicate(),
	})


func emit_lane(origin: Vector2, dir: Vector2, count: int, speed: float, stagger_s: float = 0.08, cfg: Dictionary = {}) -> void:
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	if _lanes.size() >= MAX_LANES:
		_lanes.remove_at(0)
	_lanes.append({
		"origin": origin, "dir": d, "left": clampi(count, 1, 10),
		"speed": speed, "stagger": maxf(0.04, stagger_s), "timer": 0.0, "cfg": cfg.duplicate(),
	})


func emit_sweep_wall(center: Vector2, move_dir: Vector2, span: float, count: int, gap_idx: int, gap_slots: int, speed: float, cfg: Dictionary = {}) -> void:
	var n: int = clampi(count, 5, 16)
	var mdir: Vector2 = move_dir.normalized() if move_dir.length_squared() > 0.0001 else Vector2.DOWN
	var perp := Vector2(-mdir.y, mdir.x)
	var g_slots: int = maxi(2, gap_slots) # Always wide enough for Wick to pass cleanly
	var g_start: int = clampi(gap_idx, 0, maxi(0, n - g_slots))
	var step: float = maxf(MIN_GAP_PX * 0.5, span / float(maxi(1, n - 1)))
	var half: float = step * float(n - 1) * 0.5
	for i: int in range(n):
		if i >= g_start and i < g_start + g_slots:
			continue
		var p: Vector2 = center + perp * (float(i) * step - half)
		_alloc_bolt(p, mdir, speed, cfg)


func emit_rain(ground: LxBossGround, targets: Array[Vector2], warn_s: float, impact_r: float, dmg: float = 1.0, fill_key: String = "coral", rim_key: String = "gold") -> void:
	if ground == null:
		return
	var delay: float = maxf(MIN_TELL_S, warn_s)
	for i: int in range(targets.size()):
		var pt: Vector2 = targets[i]
		ground.warn_ring(pt, maxf(12.0, impact_r), delay + float(i) * 0.08, dmg, fill_key, rim_key, 0.35)


func emit_orbit(center: Vector2, count: int, target_r: float, omega: float, duration: float, cfg: Dictionary = {}) -> void:
	var n: int = clampi(count, 2, 10)
	var step: float = TAU / float(n)
	for i: int in range(n):
		var ang: float = float(i) * step
		var c: Dictionary = cfg.duplicate()
		c["mode"] = "orbit"
		c["orbit_center"] = center
		c["orbit_follow_boss"] = bool(cfg.get("follow_boss", true))
		c["orbit_radius"] = maxf(16.0, float(cfg.get("start_radius", 18.0)))
		c["orbit_target_radius"] = maxf(24.0, target_r)
		c["orbit_angle"] = ang
		c["orbit_omega"] = omega
		c["max_age"] = maxf(0.8, duration)
		var d: Vector2 = Vector2.from_angle(ang)
		_alloc_bolt(center + d * float(c["orbit_radius"]), d, 120.0, c)


func emit_chain_lightning(points: Array[Vector2], warn_s: float, half_w: float = 8.0, active_s: float = 0.24, dmg: float = 1.0) -> void:
	if points.size() < 2:
		return
	var scale: float = _assist_scale()
	if _lightnings.size() >= MAX_LIGHTNINGS:
		_lightnings.remove_at(0)
	_lightnings.append({
		"pts": points.duplicate(),
		"warn_dur": maxf(MIN_TELL_S, warn_s) * scale,
		"active_dur": maxf(0.14, active_s),
		"half_w": maxf(5.0, half_w),
		"damage": maxf(0.5, dmg),
		"elapsed": 0.0,
		"hit": false,
		"fired": false,
	})


func emit_expanding_square(origin: Vector2, per_side: int, speed: float, rot_ang: float = 0.0, gap_side: int = -1, cfg: Dictionary = {}) -> void:
	var n: int = clampi(per_side, 2, 6)
	var corners: Array[Vector2] = [
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0),
	]
	for side: int in range(4):
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		for k: int in range(n):
			if side == gap_side and k == n / 2:
				continue
			var u: float = float(k) / float(n)
			var local_v: Vector2 = a.lerp(b, u)
			var rot_v: Vector2 = local_v.rotated(rot_ang)
			var dist_scale: float = rot_v.length()
			_alloc_bolt(origin + rot_v.normalized() * 6.0, rot_v.normalized(), speed * clampf(dist_scale, 0.72, 1.35), cfg)


func emit_boomerang(origin: Vector2, dir: Vector2, speed: float, return_s: float = 0.70, curve_rate: float = 0.65, cfg: Dictionary = {}) -> void:
	var c: Dictionary = cfg.duplicate()
	c["mode"] = "boomerang"
	c["return_time"] = maxf(0.30, return_s)
	c["curve_rate"] = curve_rate
	c["max_age"] = maxf(2.4, return_s * 2.8)
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	_alloc_bolt(origin + d * 6.0, d, speed, c)


func emit_pillars(points: Array[Vector2], warn_s: float, radius: float = 14.0, linger_s: float = 0.55, dmg: float = 1.0, color_key: String = "gold") -> void:
	var scale: float = _assist_scale()
	var w_dur: float = maxf(MIN_TELL_S, warn_s) * scale
	for i: int in range(points.size()):
		if _pillars.size() >= MAX_PILLARS:
			_pillars.remove_at(0)
		_pillars.append({
			"pos": points[i],
			"radius": maxf(10.0, radius),
			"warn_dur": w_dur + float(i) * 0.06,
			"linger_dur": maxf(0.20, linger_s),
			"elapsed": 0.0,
			"damage": maxf(0.5, dmg),
			"color": color_key,
			"hit": false,
			"erupted": false,
		})


# --- Simulation & Collision --------------------------------------------------

func tick(dt: float, world_ctx: Node, props: LxBossProps = null) -> void:
	_clock += dt
	var bpos: Vector2 = boss.pos if (boss != null and is_instance_valid(boss)) else Vector2.ZERO
	_tick_spirals(dt, bpos)
	_tick_lanes(dt)
	_tick_lightnings(dt)
	_tick_pillars(dt)
	_tick_bolts(dt, world_ctx, bpos, props)


func _tick_spirals(dt: float, bpos: Vector2) -> void:
	for i: int in range(_spirals.size() - 1, -1, -1):
		var s: Dictionary = _spirals[i]
		s["timer"] = float(s["timer"]) - dt
		if float(s["timer"]) <= 0.0:
			var orig: Vector2 = bpos if bool(s["follow_boss"]) else (s["origin"] as Vector2)
			emit_ring(orig, int(s["arms"]), float(s["speed"]), float(s["ang"]), s["cfg"] as Dictionary)
			s["ang"] = wrapf(float(s["ang"]) + float(s["spin"]), -PI, PI)
			s["waves_left"] = int(s["waves_left"]) - 1
			s["timer"] = float(s["interval"])
			if int(s["waves_left"]) <= 0:
				_spirals.remove_at(i)


func _tick_lanes(dt: float) -> void:
	for i: int in range(_lanes.size() - 1, -1, -1):
		var l: Dictionary = _lanes[i]
		l["timer"] = float(l["timer"]) - dt
		if float(l["timer"]) <= 0.0:
			var d: Vector2 = l["dir"] as Vector2
			_alloc_bolt((l["origin"] as Vector2) + d * 6.0, d, float(l["speed"]), l["cfg"] as Dictionary)
			l["left"] = int(l["left"]) - 1
			l["timer"] = float(l["stagger"])
			if int(l["left"]) <= 0:
				_lanes.remove_at(i)


func _tick_lightnings(dt: float) -> void:
	var wp: Vector2 = _wick_pos()
	var has_p: bool = _has_wick()
	for i: int in range(_lightnings.size() - 1, -1, -1):
		var lt: Dictionary = _lightnings[i]
		lt["elapsed"] = float(lt["elapsed"]) + dt
		var el: float = float(lt["elapsed"])
		var wd: float = float(lt["warn_dur"])
		var ad: float = float(lt["active_dur"])
		if el >= wd:
			if not bool(lt["fired"]):
				lt["fired"] = true
				if boss != null and is_instance_valid(boss):
					LxDamageFx.boss_impact((lt["pts"] as Array)[0] as Vector2, 0.14, 58.0, 62.0, 66.0, 1.32, 0.25)
			if not bool(lt["hit"]) and has_p:
				var pts: Array = lt["pts"] as Array
				var hw: float = float(lt["half_w"])
				for k: int in range(pts.size() - 1):
					var a: Vector2 = pts[k] as Vector2
					var b: Vector2 = pts[k + 1] as Vector2
					if Geometry2D.get_closest_point_to_segment(wp, a, b).distance_to(wp) <= hw:
						lt["hit"] = true
						var kdir: Vector2 = (b - a).normalized() if a.distance_to(b) > 0.1 else Vector2.RIGHT
						_damage_wick(kdir, float(lt["damage"]), "chain_lightning", a.lerp(b, 0.5), true)
						break
		if el >= wd + ad:
			_lightnings.remove_at(i)


func _tick_pillars(dt: float) -> void:
	var wp: Vector2 = _wick_pos()
	var has_p: bool = _has_wick()
	for i: int in range(_pillars.size() - 1, -1, -1):
		var pl: Dictionary = _pillars[i]
		pl["elapsed"] = float(pl["elapsed"]) + dt
		var el: float = float(pl["elapsed"])
		var wd: float = float(pl["warn_dur"])
		var ld: float = float(pl["linger_dur"])
		var pp: Vector2 = pl["pos"] as Vector2
		var pr: float = float(pl["radius"])
		if el >= wd:
			if not bool(pl["erupted"]):
				pl["erupted"] = true
				LxDamageFx.boss_impact(pp, 0.14, 62.0, 66.0, 72.0, 1.35, 0.28)
			if not bool(pl["hit"]) and has_p and wp.distance_to(pp) <= pr:
				pl["hit"] = true
				var push: Vector2 = (wp - pp).normalized() if wp.distance_to(pp) > 0.1 else Vector2.DOWN
				_damage_wick(push, float(pl["damage"]), "pillar", pp, true)
		if el >= wd + ld:
			_pillars.remove_at(i)


func _tick_bolts(dt: float, world_ctx: Node, bpos: Vector2, props: LxBossProps) -> void:
	var wp: Vector2 = _wick_pos()
	var has_p: bool = _has_wick()
	var wick_node: LxWick = Lx.player as LxWick if (is_instance_valid(Lx.player) and Lx.player is LxWick) else null
	var wick_dashing: bool = wick_node != null and wick_node.is_dashing()
	var wick_beam_active: bool = wick_node != null and wick_node.move_beam != null and wick_node.move_beam.beam_vis_t > 0.0
	var wick_lens_active: bool = wick_node != null and wick_node.move_lens != null and wick_node.move_lens.is_pulse_active()
	var bounds: Rect2 = Rect2()
	if boss != null and boss.has_method("get_arena_rect"):
		bounds = boss.call("get_arena_rect") as Rect2
	elif world_ctx != null and world_ctx.has_method("get_bounds"):
		bounds = world_ctx.call("get_bounds") as Rect2

	for b: LxBossBolt in pool:
		if not b.active:
			continue
		b.step_motion(dt, world_ctx, bpos)
		if not b.active:
			continue

		if bounds.has_area() and not bounds.grow(20.0).has_point(b.pos):
			b.deactivate()
			continue

		# Wall / mirror check
		if not b.pierces_walls and world_ctx != null and is_instance_valid(world_ctx):
			if b.reflectable and world_ctx.has_method("get_mirror_hit"):
				var mh: Dictionary = world_ctx.call("get_mirror_hit", b.prev_pos, b.pos) as Dictionary
				if bool(mh.get("hit", false)):
					var n: Vector2 = (mh.get("normal", -b.dir) as Vector2).normalized()
					b.pos = (mh.get("pos", b.pos) as Vector2) + n * 2.0
					b.reflect(b.dir.bounce(n), 1.25)
					continue
			if world_ctx.has_method("tile_at") and str(world_ctx.call("tile_at", b.pos)) == "wall":
				b.deactivate()
				continue

		# Solid arena props block boss bolts (real tactical cover!)
		if props != null and b.blockable and props.hit_by_bolt(b):
			b.deactivate()
			continue

		# Reflected bolts damage boss back!
		if b.reflected:
			if boss != null and is_instance_valid(boss) and boss.is_alive():
				if Geometry2D.get_closest_point_to_segment(boss.pos, b.prev_pos, b.pos).distance_to(boss.pos) <= boss.body_radius + b.radius + 1.5:
					var hit := LxHit.make(LxHit.SOURCE_PRISM, 1.5, b.dir, b.prev_pos, 1.0, true, true, wick_node, false, LxHit.COLOR_BLUE)
					boss.take_hit(hit)
					b.deactivate()
			continue

		# Player Beam reflects nearby reflectable boss bolts
		if wick_beam_active and b.reflectable:
			if Geometry2D.get_closest_point_to_segment(b.pos, wick_node.move_beam.beam_start, wick_node.move_beam.beam_end).distance_to(b.pos) <= b.radius + 8.0:
				var back_dir: Vector2 = (bpos - b.pos).normalized() if bpos.distance_to(b.pos) > 1.0 else -b.dir
				b.reflect(back_dir, 1.45)
				continue

		# True Lens slows/freezes marked lens-freeze bolts if tagged
		if wick_lens_active and b.freeze_hook_tag == "lens":
			if b.pos.distance_to(wick_node.move_lens.pulse_origin) <= wick_node.move_lens.pulse_radius:
				b.freeze(0.25, "lens")

		# Player hit check (respects dash i-frames -> perfect dodge!)
		if has_p and Geometry2D.get_closest_point_to_segment(wp, b.prev_pos, b.pos).distance_to(wp) <= b.radius + 4.0:
			if wick_dashing and wick_node.move_dash != null and wick_node.move_dash.has_iframes():
				wick_node.move_dash.on_perfect_dodge()
				if b.reflectable and wick_node.move_dash.counter_t > 0.0:
					var rdir: Vector2 = (bpos - b.pos).normalized() if bpos.distance_to(b.pos) > 1.0 else -b.dir
					b.reflect(rdir, 1.35)
				continue
			_damage_wick(b.dir, b.damage, b.source_kind, b.pos, b.telegraphed)
			b.deactivate()


func draw_patterns(ci: CanvasItem, origin_world: Vector2) -> void:
	var off: Vector2 = -origin_world
	var fred: bool = LxHudFx.flash_reduced()

	# Chain lightning telegraphs and active bolts
	for lt: Dictionary in _lightnings:
		var pts: Array = lt["pts"] as Array
		var el: float = float(lt["elapsed"])
		var wd: float = float(lt["warn_dur"])
		var hw: float = float(lt["half_w"])
		for k: int in range(pts.size() - 1):
			var a: Vector2 = (pts[k] as Vector2) + off
			var b: Vector2 = (pts[k + 1] as Vector2) + off
			if el < wd:
				LxBossTelegraphFx.draw_ground_danger_lane(ci, a, b, hw, clampf(el / maxf(wd, 0.05), 0.0, 1.0), _clock, "sky", "gold")
			else:
				ci.draw_line(a.round(), b.round(), PAL["void"] as Color, 6.4)
				ci.draw_line(a.round(), b.round(), PAL["blue"] as Color, 4.6 if fred else 5.0)
				ci.draw_line(a.round(), b.round(), PAL["ice"] as Color, 2.2 if fred else 2.6)
				ci.draw_line(a.round(), b.round(), Color(PAL["cream"] as Color, 0.72 if fred else 1.0), 1.0 if fred else 1.2)

	# Erupting pillars
	for pl: Dictionary in _pillars:
		var pp: Vector2 = (pl["pos"] as Vector2) + off
		var pr: float = float(pl["radius"])
		var el: float = float(pl["elapsed"])
		var wd: float = float(pl["warn_dur"])
		var col_k: String = str(pl["color"])
		if el < wd:
			LxBossTelegraphFx.draw_ground_danger_ring(ci, pp, pr, clampf(el / maxf(wd, 0.05), 0.0, 1.0), _clock, col_k, "coral")
		else:
			var frac: float = 1.0 - clampf((el - wd) / maxf(float(pl["linger_dur"]), 0.05), 0.0, 1.0)
			var h: float = roundf(lerpf(10.0, 44.0, frac))
			var col_m: Color = LxPalette.color(col_k, "gold")
			var pr_r := Rect2((pp + Vector2(-pr * 0.55, -h)).round(), Vector2(roundf(pr * 1.1), h))
			ci.draw_circle(pp.round(), pr, Color(col_m, 0.42 * frac))
			ci.draw_rect(pr_r.grow(1.0), PAL["void"] as Color)
			ci.draw_rect(pr_r, col_m)
			ci.draw_rect(Rect2((pp + Vector2(-pr * 0.25, -h)).round(), Vector2(maxf(2.0, roundf(pr * (0.35 if fred else 0.5))), h)), Color(PAL["cream"] as Color, 0.78 if fred else 1.0))

	# Active pooled bolts
	for b: LxBossBolt in pool:
		if b.active:
			b.draw_bolt(ci, off, _clock, fred)


func _assist_scale() -> float:
	if boss != null and boss.has_method("get_tell_scale"):
		return float(boss.call("get_tell_scale"))
	if Lx.save != null and Lx.save.settings.has("assist_tell_scale"):
		return clampf(float(Lx.save.settings["assist_tell_scale"]), 1.0, 1.5)
	return 1.0


func _has_wick() -> bool:
	return boss != null and boss.has_method("_has_player") and bool(boss.call("_has_player"))


func _wick_pos() -> Vector2:
	if boss != null and boss.has_method("_get_wick_pos"):
		return boss.call("_get_wick_pos") as Vector2
	if is_instance_valid(Lx.player) and Lx.player is Node2D:
		return (Lx.player as Node2D).global_position
	return Vector2(-9999.0, -9999.0)


func _damage_wick(hit_dir: Vector2, dmg: float, src: String, from_pos: Vector2, telegraphed: bool) -> void:
	if boss != null and boss.has_method("emit_boss_damage"):
		boss.call("emit_boss_damage", hit_dir, dmg, src, from_pos, telegraphed)
	elif boss != null and boss.has_method("_emit_player_hit"):
		boss.call("_emit_player_hit", hit_dir, dmg)
