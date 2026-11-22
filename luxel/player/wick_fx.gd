class_name LxWickFx
extends RefCounted
## Particle pools, sprite loading, and Last Light 20-colour rendering for LxWick and his 8-move kit.

const PAL_MAUVE: Color = Color("8a6e91")
const MAX_MOTES: int = 48
const DUST_INTERVAL: float = 0.22
const MOTE_INTERVAL: float = 0.18
const STREAK_DASH_INTERVAL: float = 0.036
const STREAK_WING_INTERVAL: float = 0.055

var afterimages: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var streaks: Array[Dictionary] = []
var sprite_sheet: LxSpriteSheet = null

var _last_clock_t: float = -1.0
var _dust_cd: float = 0.0
var _mote_cd: float = 0.0
var _streak_cd: float = 0.0
var _ripple_cd: float = 0.0
var _step_parity: int = 0
var _was_airborne: bool = false
var _prev_move_dir: Vector2 = Vector2.ZERO
var _skid_cd: float = 0.0
var _idle_t: float = 0.0

func clear() -> void:
	afterimages.clear()
	rings.clear()
	sparks.clear()
	motes.clear()
	streaks.clear()
	_last_clock_t = -1.0
	_dust_cd = 0.0
	_mote_cd = 0.0
	_streak_cd = 0.0
	_ripple_cd = 0.0
	_step_parity = 0
	_was_airborne = false
	_prev_move_dir = Vector2.ZERO
	_skid_cd = 0.0
	_idle_t = 0.0

func spawn_afterimage(at_pos: Vector2, col: Color, dir: Vector2 = Vector2.RIGHT, anim: String = "dash") -> void:
	afterimages.append({"pos": at_pos, "age": 0.0, "life": 0.20, "col": col, "dir": dir, "anim": anim})

func spawn_ring(at_pos: Vector2, r0: float, r1: float, life: float, col: Color, width: float = 1.0) -> void:
	rings.append({"pos": at_pos, "r0": r0, "r1": r1, "age": 0.0, "life": maxf(0.02, life), "col": col, "w": width})

func spawn_sparks(at_pos: Vector2, base_dir: Vector2, count: int, col: Color, min_spd: float, max_spd: float, life: float) -> void:
	var dn: Vector2 = base_dir.normalized() if base_dir.length_squared() > 0.0001 else Vector2.RIGHT
	for _i: int in range(count):
		sparks.append({
			"pos": at_pos,
			"vel": dn.rotated(randf_range(-0.65, 0.65)) * randf_range(min_spd, max_spd),
			"age": 0.0, "life": life, "col": col,
		})

func _spawn_mote(at_pos: Vector2, vel: Vector2, life: float, col: Color, size_px: float, shrink: bool, drag: float, fg: bool, alpha: float) -> void:
	if motes.size() + streaks.size() >= MAX_MOTES:
		if not motes.is_empty():
			motes.remove_at(0)
		elif not streaks.is_empty():
			streaks.remove_at(0)
	motes.append({
		"pos": at_pos, "vel": vel, "age": 0.0, "life": maxf(0.04, life),
		"col": col, "size": size_px, "shrink": shrink, "drag": drag, "fg": fg, "alpha": alpha,
	})

func _spawn_streak(p0: Vector2, p1: Vector2, life: float, col: Color, width: float = 1.0) -> void:
	if motes.size() + streaks.size() >= MAX_MOTES:
		if not streaks.is_empty():
			streaks.remove_at(0)
		elif not motes.is_empty():
			motes.remove_at(0)
	streaks.append({"p0": p0, "p1": p1, "age": 0.0, "life": maxf(0.04, life), "col": col, "w": width})

func age(dt: float) -> void:
	for arr: Array[Dictionary] in [afterimages, rings, streaks]:
		for i: int in range(arr.size() - 1, -1, -1):
			arr[i]["age"] = float(arr[i]["age"]) + dt
			if float(arr[i]["age"]) >= float(arr[i]["life"]):
				arr.remove_at(i)
	for i: int in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["age"] = float(s["age"]) + dt
		var vel: Vector2 = s["vel"] as Vector2
		s["pos"] = (s["pos"] as Vector2) + vel * dt
		s["vel"] = vel * pow(0.08, dt)
		if float(s["age"]) >= float(s["life"]):
			sparks.remove_at(i)
	for i: int in range(motes.size() - 1, -1, -1):
		var m: Dictionary = motes[i]
		m["age"] = float(m["age"]) + dt
		var vel: Vector2 = m["vel"] as Vector2
		m["pos"] = (m["pos"] as Vector2) + vel * dt
		m["vel"] = vel * pow(float(m["drag"]), dt)
		if float(m["age"]) >= float(m["life"]):
			motes.remove_at(i)

func try_load_sprite() -> void:
	if sprite_sheet != null:
		return
	sprite_sheet = LxSpriteSheet.load_sheet("res://luxel/art/wick/wick.json")


func _surface_at(world_pos: Vector2) -> String:
	if Lx.world == null or not is_instance_valid(Lx.world):
		return "stone"
	var tile: String = str(Lx.world.call("tile_at", world_pos)) if Lx.world.has_method("tile_at") else "floor"
	if tile == "water" or tile == "tide":
		return "water"
	if tile == "bridge":
		return "wood"
	var is_dung: bool = bool(Lx.world.get("is_dungeon"))
	var isl: int = int(Lx.world.get("current_island_id"))
	if isl == 6 and tile in ["floor", "path", "ground"]:
		return "ash"
	if (isl == 7 or isl == 8) and tile in ["floor", "path", "ground", "mirror", "glass"]:
		return "crystal"
	if not is_dung:
		if isl == 2 and tile == "path":
			return "wood"
		if tile == "floor" and isl in [1, 3, 4]:
			return "grass"
	return "stone"


func _dust_color_for(surf: String) -> Color:
	if surf == "grass":
		return LxPalette.color("lime") if randf() < 0.45 else LxPalette.color("jade")
	if surf == "wood":
		return LxWick.PAL_APRICOT if randf() < 0.45 else PAL_MAUVE
	if surf == "ash":
		return LxWick.PAL_CORAL if randf() < 0.35 else LxWick.PAL_STONE
	if surf == "crystal" or surf == "water":
		return LxWick.PAL_ICE if randf() < 0.45 else LxWick.PAL_SKY
	return LxWick.PAL_STONE if randf() < 0.55 else PAL_MAUVE

func _tick_emitters(wick: LxWick, clock_t: float, lan_in_hand: bool, hand_pos: Vector2, glide_lift: float) -> void:
	if _last_clock_t < 0.0 or clock_t < _last_clock_t:
		_last_clock_t = clock_t
		_dust_cd = 0.06
		_mote_cd = 0.08
		_streak_cd = 0.0
		return
	var step_dt: float = clampf(clock_t - _last_clock_t, 0.0, 0.1)
	_last_clock_t = clock_t
	if step_dt <= 0.0 or wick.dead:
		return

	var dashing: bool = wick.is_dashing()
	var gliding: bool = wick.is_gliding()
	var zipping: bool = wick.is_zipping()
	var airborne: bool = dashing or gliding or zipping
	if _was_airborne and not airborne:
		var surf_l: String = _surface_at(wick.global_position)
		var lcol: Color = _dust_color_for(surf_l)
		for side: float in [-1.0, 1.0]:
			_spawn_mote(wick.global_position + Vector2(side * 3.0, 0.0), Vector2(side * 16.0, -7.0), 0.24, lcol, 2.0, true, 0.16, false, 0.80)
		if surf_l == "water" and Lx.world != null and is_instance_valid(Lx.world):
			var wfx_l: Variant = Lx.world.get("_water_fx")
			if wfx_l is Object and is_instance_valid(wfx_l) and (wfx_l as Object).has_method("spawn_ripple"):
				(wfx_l as Object).call("spawn_ripple", wick.global_position + Vector2(0.0, 1.0), "ice")
		else:
			spawn_ring(wick.global_position + Vector2(0.0, 1.0), 2.0, 8.5, 0.17, lcol, 1.0)
		wick.emit_sfx("footstep_" + surf_l, wick.global_position, false)
	_was_airborne = airborne

	# Surface-aware footstep dust puffs, sharp-turn skid dust, & biome-matched footsteps (grass / wood / stone)
	_skid_cd = maxf(0.0, _skid_cd - step_dt)
	if wick.velocity.length() > 24.0 and not dashing and not gliding and not zipping:
		_idle_t = 0.0
		var mdir: Vector2 = wick.velocity.normalized()
		if _prev_move_dir.length_squared() > 0.5 and _prev_move_dir.dot(mdir) < -0.35 and _skid_cd <= 0.0:
			_skid_cd = 0.24
			var s_skid: String = _surface_at(wick.global_position)
			var c_skid: Color = _dust_color_for(s_skid)
			for sk: int in range(2):
				var sk_vel: Vector2 = _prev_move_dir * randf_range(12.0, 22.0) + Vector2(randf_range(-5.0, 5.0), randf_range(-10.0, -4.0))
				_spawn_mote(wick.global_position + Vector2(randf_range(-2.0, 2.0), 0.0), sk_vel, 0.26, c_skid, 2.0, true, 0.16, false, 0.78)
		_prev_move_dir = mdir
		_dust_cd -= step_dt
		if _dust_cd <= 0.0:
			_dust_cd = DUST_INTERVAL
			var foot: Vector2 = wick.global_position - mdir * 2.0 + Vector2(randf_range(-2.5, 2.5), randf_range(-0.5, 1.0))
			var dvel: Vector2 = Vector2(-mdir.x * randf_range(4.0, 9.0) + randf_range(-3.0, 3.0), randf_range(-11.0, -6.0))
			var surf: String = _surface_at(wick.global_position)
			var dcol: Color = _dust_color_for(surf)
			_spawn_mote(foot, dvel, randf_range(0.26, 0.36), dcol, float(randi_range(2, 3)), true, 0.18, false, 0.72)
			_step_parity = (_step_parity + 1) & 1
			if _step_parity == 1:
				if surf == "water" and Lx.world != null and is_instance_valid(Lx.world):
					var wfx_s: Variant = Lx.world.get("_water_fx")
					if wfx_s is Object and is_instance_valid(wfx_s) and (wfx_s as Object).has_method("spawn_ripple"):
						(wfx_s as Object).call("spawn_ripple", wick.global_position + Vector2(0.0, 1.0), "ice", 10.0)
				wick.emit_sfx("footstep_" + surf, wick.global_position, false)
	else:
		_prev_move_dir = Vector2.ZERO
		_dust_cd = minf(_dust_cd, 0.06)
		if not dashing and not gliding and not zipping:
			_idle_t += step_dt
			if lan_in_hand and _idle_t > 1.4 and fmod(_idle_t, 1.35) < step_dt:
				_spawn_mote(wick.global_position + hand_pos + Vector2(randf_range(-2.0, 2.0), -2.0), Vector2(randf_range(-3.0, 3.0), -11.0), 0.48, LxWick.PAL_CREAM, 1.0, false, 0.50, true, 0.88)

	# Lantern candlelight ember motes (gold/cream, 1x1 rising around hand_pos; warm coral urgency at <= 1 heart)
	if lan_in_hand:
		var low_hp: bool = wick.get_hearts() > 0.0 and wick.get_hearts() <= 1.0
		_mote_cd -= step_dt
		if _mote_cd <= 0.0:
			_mote_cd = MOTE_INTERVAL * (0.78 if low_hp else 1.0)
			var origin: Vector2 = wick.global_position + hand_pos + Vector2(randf_range(-2.5, 2.5), randf_range(-2.0, 1.0))
			var mvel: Vector2 = Vector2(randf_range(-5.0, 5.0), randf_range(-16.0, -9.0))
			var mcol: Color = (LxWick.PAL_CORAL if randf() < 0.65 else LxWick.PAL_APRICOT) if low_hp else (LxWick.PAL_CREAM if randf() < 0.40 else LxWick.PAL_GOLD)
			_spawn_mote(origin, mvel, randf_range(0.38, 0.54), mcol, 1.0, false, 0.45, true, 0.92)
	else:
		_mote_cd = minf(_mote_cd, 0.08)

	# Dash (coral/gold), Wings (ice/sky), Zip (gold/apricot) motion streaks + feather/ember trail
	if dashing or gliding or zipping:
		_streak_cd -= step_dt
		if _streak_cd <= 0.0:
			var mdir: Vector2 = wick.velocity.normalized() if wick.velocity.length_squared() > 1.0 else (
				wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
			)
			var perp: Vector2 = Vector2(-mdir.y, mdir.x)
			var c_a: Color = LxWick.PAL_GOLD if zipping else (LxWick.PAL_ICE if gliding else LxWick.PAL_CORAL)
			var c_b: Color = LxWick.PAL_APRICOT if zipping else (LxWick.PAL_SKY if gliding else LxWick.PAL_GOLD)
			var pick_a: bool = randf() < 0.52
			var sc: Color = c_a if pick_a else c_b
			var tc: Color = c_b if pick_a else c_a
			_streak_cd = STREAK_WING_INTERVAL if (gliding and not zipping) else STREAK_DASH_INTERVAL
			var spread: float = 6.0 if (gliding and not zipping) else 4.5
			var c: Vector2 = wick.global_position + Vector2(0.0, -6.0 + glide_lift) + perp * randf_range(-spread, spread)
			var slen: float = randf_range(7.0, 12.0) if (gliding and not zipping) else randf_range(9.0, 16.0)
			_spawn_streak(c - mdir * slen, c, 0.20 if (gliding and not zipping) else 0.14, sc, 1.0)
			var tvel: Vector2 = -mdir * randf_range(7.0, 16.0 if (gliding and not zipping) else 26.0) + perp * randf_range(-10.0, 10.0) + Vector2(0.0, randf_range(2.0, 7.0) if (gliding and not zipping) else -4.5)
			_spawn_mote(c, tvel, 0.30 if (gliding and not zipping) else 0.21, tc, 2.0 if (gliding and not zipping) else 1.0, gliding and not zipping, 0.32 if (gliding and not zipping) else 0.19, true, 0.88)
		_ripple_cd -= step_dt
		if _ripple_cd <= 0.0 and Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("tile_at"):
			var under_tile: String = str(Lx.world.call("tile_at", wick.global_position))
			if under_tile == "water" or under_tile == "tide":
				_ripple_cd = 0.14
				var rcol: Color = LxWick.PAL_ICE if randf() < 0.42 else LxWick.PAL_SKY
				spawn_ring(wick.global_position + Vector2(0.0, 2.0), 2.0, 10.0, 0.34, rcol, 1.0)
				var wfx: Variant = Lx.world.get("_water_fx")
				if wfx is Object and is_instance_valid(wfx) and (wfx as Object).has_method("spawn_ripple"):
					(wfx as Object).call("spawn_ripple", wick.global_position + Vector2(0.0, 2.0), "ice")
				_step_parity = (_step_parity + 1) & 1
				if _step_parity == 0:
					wick.emit_sfx("footstep_water", wick.global_position, false)
				_spawn_mote(wick.global_position + Vector2(randf_range(-3.0, 3.0), 1.0), Vector2(randf_range(-14.0, 14.0), randf_range(-12.0, -5.0)), 0.24, LxWick.PAL_ICE, 1.0, false, 0.22, false, 0.85)
	else:
		_streak_cd = 0.0
		_ripple_cd = 0.0

func draw(wick: LxWick, walk_phase: float, clock_t: float) -> void:
	var off: Vector2 = -wick.global_position
	var flash_red: bool = Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))
	var alpha: float = 0.40 if (wick.mercy_t > 0.0 and not flash_red and (int(wick.mercy_t * 14.0) % 2 == 0)) else 1.0
	var glide_lift: float = -3.0 if wick.is_gliding() else 0.0
	var hop_y: float = -roundf(absf(sin(walk_phase)) * 2.0)
	var base: Vector2 = (-wick.facing * clampf(wick.recoil_vis * 1.5, 0.0, 1.5)).round() + Vector2(0.0, hop_y + glide_lift)
	var lan_in_hand: bool = wick.lantern == null or wick.lantern.is_in_hand()
	var hand_pos: Vector2 = (base + wick.facing * 6.0 + Vector2(0.0, -6.0)).round()

	_tick_emitters(wick, clock_t, lan_in_hand, hand_pos, glide_lift)
	if wick.move_lens != null:
		wick.move_lens.draw_fx(wick, off)
	if wick.move_sunflare != null:
		wick.move_sunflare.draw_fx(wick, off)

	var air_lift: float = absf(hop_y) + absf(glide_lift) + (2.5 if wick.is_zipping() else 0.0)
	_draw_shadow(wick, air_lift)
	if wick.is_gliding() and wick.move_wings != null and wick.move_wings.glide_duration > 0.05:
		var gfrac: float = clampf(wick.move_wings.glide_time_left / wick.move_wings.glide_duration, 0.0, 1.0)
		var gcol: Color = LxWick.PAL_CORAL if gfrac < 0.28 else (LxWick.PAL_GOLD if gfrac < 0.55 else LxWick.PAL_ICE)
		wick.draw_arc(Vector2(0.0, 1.0), 9.0, PI * 0.15, PI * 0.15 + PI * 0.70 * gfrac, 12, gcol, 1.5, false)
	_draw_motes(wick, off, false)

	for a: Dictionary in afterimages:
		var t: float = 1.0 - clampf(float(a["age"]) / float(a["life"]), 0.0, 1.0)
		var apos: Vector2 = ((a["pos"] as Vector2) + off).round()
		var acol: Color = Color(a["col"] as Color, t * 0.52)
		if sprite_sheet == null or not sprite_sheet.draw_actor(wick, apos, str(a.get("anim", "dash")), a.get("dir", wick.facing) as Vector2, clock_t, acol):
			wick.draw_rect(Rect2(apos + Vector2(-4.0, -10.0), Vector2(8.0, 10.0)), acol)
	for st: Dictionary in streaks:
		var t: float = clampf(float(st["age"]) / float(st["life"]), 0.0, 1.0)
		var p0: Vector2 = (st["p0"] as Vector2) + off
		var p1: Vector2 = (st["p1"] as Vector2) + off
		wick.draw_line(p0.lerp(p1, t * 0.65).round(), p1.round(), Color(st["col"] as Color, (1.0 - t) * 0.85), float(st["w"]))
	for r: Dictionary in rings:
		var t: float = clampf(float(r["age"]) / float(r["life"]), 0.0, 1.0)
		wick.draw_arc(((r["pos"] as Vector2) + off).round(), lerpf(float(r["r0"]), float(r["r1"]), t), 0.0, TAU, 20, Color(r["col"] as Color, 1.0 - t), float(r["w"]))

	if lan_in_hand:
		var low_hp: bool = wick.get_hearts() > 0.0 and wick.get_hearts() <= 1.0
		var beat: float = sin(clock_t * (9.5 if (low_hp and not flash_red) else 7.0))
		var pulse: float = (0.86 + 0.14 * beat) if low_hp else (0.92 + 0.08 * beat)
		wick.draw_circle(hand_pos, 13.0 * pulse, Color(LxWick.PAL_CORAL if low_hp else LxWick.PAL_GOLD, 0.13 if low_hp else 0.10))
		wick.draw_circle(hand_pos, 6.5 * pulse, Color(LxWick.PAL_APRICOT, 0.17 if low_hp else 0.15))

	var hit_white: bool = wick.hurt_flash > 0.55 and not flash_red
	var mod: Color = Color(LxWick.PAL_CREAM, alpha) if hit_white else Color(1.0, 1.0, 1.0, alpha)
	var anim_name: String = "idle"
	if wick.is_zipping():
		anim_name = "zip"
	elif wick.is_dashing() or wick.is_gliding():
		anim_name = "dash"
	elif wick.throw_anim_t > 0.0:
		anim_name = "throw"
	elif wick.shoot_anim_t > 0.0:
		anim_name = "shoot"
	elif wick.velocity.length() > 10.0:
		anim_name = "walk"
	var drew_sprite: bool = sprite_sheet != null and sprite_sheet.draw_actor(wick, base, anim_name, wick.facing, clock_t, mod)
	if not drew_sprite:
		_draw_fallback_moth(wick, base, hit_white, alpha, lan_in_hand, hand_pos)

	_draw_motes(wick, off, true)
	if wick.move_dash != null and wick.move_dash.counter_t > 0.0:
		var ca: float = clock_t * 7.5
		for ci: int in range(2):
			var cp: Vector2 = (hand_pos + Vector2(cos(ca + float(ci) * PI) * 5.0, sin(ca + float(ci) * PI) * 4.0)).round()
			wick.draw_rect(Rect2(cp, Vector2.ONE), LxWick.PAL_CREAM if ci == 0 else LxWick.PAL_ICE)
	if wick.move_sunflare != null and wick.move_sunflare.unlocked and wick.get_ember_ratio() >= 0.999:
		for si: int in range(2):
			var sa: float = clock_t * 3.4 + float(si) * PI
			var sp: Vector2 = (Vector2(0.0, -7.0) + Vector2(cos(sa) * 9.0, sin(sa) * 5.0)).round()
			wick.draw_rect(Rect2(sp, Vector2.ONE), LxWick.PAL_CREAM if si == 0 else LxWick.PAL_GOLD)
	if wick.move_beam != null:
		wick.move_beam.draw_fx(wick, off, hand_pos)
	for s: Dictionary in sparks:
		wick.draw_rect(Rect2(((s["pos"] as Vector2) + off).round(), Vector2(1.0, 1.0)), s["col"] as Color)
	_draw_bolts(wick, off)

	var pip: Vector2 = (wick.facing * 12.0 + Vector2(0.0, -6.0)).round()
	wick.draw_rect(Rect2(pip - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), LxWick.PAL_VOID)
	if lan_in_hand:
		wick.draw_rect(Rect2(pip - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxWick.PAL_GOLD)
		wick.draw_rect(Rect2(pip - Vector2(1.0, 1.0), Vector2(1.0, 1.0)), LxWick.PAL_CREAM)
	else:
		var lan_stolen: bool = wick.lantern != null and wick.lantern.state == LxLantern.State.CARRIED
		wick.draw_rect(Rect2(pip - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxWick.PAL_CORAL if lan_stolen else LxWick.PAL_APRICOT)
		wick.draw_rect(Rect2(pip, Vector2.ONE), LxWick.PAL_VOID)
	if wick.muzzle_t > 0.0:
		_draw_muzzle_star(wick, hand_pos, flash_red)

func _draw_shadow(wick: LxWick, air_lift: float) -> void:
	var sc: float = clampf(1.0 - air_lift * 0.09, 0.55, 1.0)
	var col: Color = Color(LxWick.PAL_VOID, 0.42 * lerpf(1.0, 0.72, clampf(air_lift / 5.0, 0.0, 1.0)))
	var widths: Array[float] = [6.0, 10.0, 10.0, 6.0]
	for idx: int in range(4):
		var row_y: float = float(idx - 1)
		var w: float = maxf(2.0, roundf(widths[idx] * sc))
		var x: float = roundf(1.0 + row_y * 0.7 - w * 0.5)
		wick.draw_rect(Rect2(Vector2(x, row_y), Vector2(w, 1.0)), col)

func _draw_motes(wick: LxWick, off: Vector2, foreground: bool) -> void:
	for m: Dictionary in motes:
		if bool(m["fg"]) != foreground:
			continue
		var t: float = clampf(float(m["age"]) / float(m["life"]), 0.0, 1.0)
		var base_sz: float = float(m["size"])
		var sz: float = maxf(1.0, roundf(lerpf(base_sz, 1.0, t))) if bool(m["shrink"]) else base_sz
		var p: Vector2 = ((m["pos"] as Vector2) + off).round() - Vector2(floorf(sz * 0.5), floorf(sz * 0.5))
		wick.draw_rect(Rect2(p, Vector2(sz, sz)), Color(m["col"] as Color, (1.0 - t) * float(m["alpha"])))

func _draw_bolts(wick: LxWick, off: Vector2) -> void:
	for b_var: Variant in wick.bolts:
		var b: LxMoveBolt.Bolt = b_var as LxMoveBolt.Bolt
		if b == null:
			continue
		var bdir: Vector2 = b.dir.normalized() if b.dir.length_squared() > 0.0001 else Vector2.RIGHT
		var bp: Vector2 = (b.pos + off).round()
		var c_body: Color = LxWick.PAL_ICE if b.is_prism else (LxWick.PAL_CREAM if b.is_counter else LxWick.PAL_GOLD)
		var c_tail: Color = LxWick.PAL_SKY if b.is_prism else (LxWick.PAL_GOLD if b.is_counter else LxWick.PAL_APRICOT)
		var mid_end: Vector2 = (bp - bdir * (6.0 if (b.is_counter or b.bounce_count >= 2) else 5.0)).round()
		var tail_end: Vector2 = (bp - bdir * (12.0 if (b.is_counter or b.bounce_count >= 2) else 9.0)).round()
		wick.draw_line(tail_end, mid_end, Color(c_tail, 0.85), 1.0)
		wick.draw_rect(Rect2(tail_end, Vector2(1.0, 1.0)), c_tail)
		wick.draw_line(mid_end, bp, c_body, 2.0)
		wick.draw_line((bp - bdir * 2.0).round(), bp, LxWick.PAL_CREAM, 1.0)
		wick.draw_rect(Rect2(bp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxWick.PAL_CREAM)
		if b.is_prism:
			var arm: float = 4.0 if b.bounce_count >= 2 else 3.0
			wick.draw_line(bp + Vector2(-arm, 0.0), bp + Vector2(arm, 0.0), LxWick.PAL_ICE, 1.0)
			wick.draw_line(bp + Vector2(0.0, -arm), bp + Vector2(0.0, arm), LxWick.PAL_ICE, 1.0)
			if b.bounce_count >= 2:
				wick.draw_rect(Rect2(bp + Vector2(-2.0, -2.0), Vector2.ONE), LxWick.PAL_CREAM)
				wick.draw_rect(Rect2(bp + Vector2(2.0, 2.0), Vector2.ONE), LxWick.PAL_CREAM)
		elif b.is_counter:
			wick.draw_line(bp + Vector2(-3.0, 0.0), bp + Vector2(3.0, 0.0), LxWick.PAL_GOLD, 1.0)
			wick.draw_line(bp + Vector2(0.0, -3.0), bp + Vector2(0.0, 3.0), LxWick.PAL_GOLD, 1.0)

func _draw_muzzle_star(wick: LxWick, hand_pos: Vector2, flash_red: bool) -> void:
	var aim: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
	var perp: Vector2 = Vector2(-aim.y, aim.x)
	var mt: float = clampf(wick.muzzle_t / 0.065, 0.0, 1.0)
	var sc: float = 0.75 if flash_red else 1.0
	var fwd: float = roundf(lerpf(3.0, 7.0, mt) * sc)
	var bck: float = roundf(lerpf(2.0, 4.0, mt) * sc)
	var side: float = roundf(lerpf(2.0, 5.0, mt) * sc)
	wick.draw_line((hand_pos - aim * bck).round(), (hand_pos + aim * fwd).round(), LxWick.PAL_GOLD, 1.0)
	wick.draw_line((hand_pos - perp * side).round(), (hand_pos + perp * side).round(), LxWick.PAL_GOLD, 1.0)
	wick.draw_line((hand_pos - aim * roundf(bck * 0.5)).round(), (hand_pos + aim * roundf(fwd * 0.65)).round(), LxWick.PAL_CREAM, 1.0)
	wick.draw_line((hand_pos - perp * roundf(side * 0.6)).round(), (hand_pos + perp * roundf(side * 0.6)).round(), LxWick.PAL_CREAM, 1.0)
	wick.draw_rect(Rect2(hand_pos - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxWick.PAL_CREAM)

func _draw_fallback_moth(wick: LxWick, base: Vector2, hit_white: bool, alpha: float, lan_in_hand: bool, hand_pos: Vector2) -> void:
	var c_out := Color(LxWick.PAL_NIGHT, alpha)
	var c_cloak := Color(
		LxWick.PAL_CREAM if hit_white else (
			LxWick.PAL_ICE if wick.is_dashing() else (
				LxWick.PAL_SKY if wick.is_gliding() else (
					LxWick.PAL_GOLD if wick.is_zipping() else LxWick.PAL_DUSK
				)
			)
		), alpha
	)
	var c_wing := Color(LxWick.PAL_CREAM if hit_white else (LxWick.PAL_ICE if wick.is_gliding() else LxWick.PAL_PLUM), alpha)
	var wing_w: float = 14.0 if wick.is_gliding() else 10.0
	wick.draw_rect(Rect2(base + Vector2(-wing_w * 0.5, -10.0), Vector2(wing_w, 6.0)), c_out)
	wick.draw_rect(Rect2(base + Vector2(-wing_w * 0.5 + 1.0, -9.0), Vector2(wing_w - 2.0, 4.0)), c_wing)
	wick.draw_rect(Rect2(base + Vector2(-4.0, -11.0), Vector2(8.0, 10.0)), c_out)
	wick.draw_rect(Rect2(base + Vector2(-3.0, -10.0), Vector2(6.0, 8.0)), c_cloak)
	wick.draw_rect(Rect2(base + Vector2(-3.0, -15.0), Vector2(6.0, 5.0)), c_out)
	wick.draw_rect(Rect2(base + Vector2(-2.0, -14.0), Vector2(4.0, 3.0)), Color(LxWick.PAL_CREAM, alpha))
	wick.draw_rect(Rect2(base + Vector2(-2.0, -17.0), Vector2(1.0, 2.0)), Color(LxWick.PAL_GOLD, alpha))
	wick.draw_rect(Rect2(base + Vector2(1.0, -17.0), Vector2(1.0, 2.0)), Color(LxWick.PAL_GOLD, alpha))
	if lan_in_hand:
		wick.draw_rect(Rect2(hand_pos + Vector2(-2.0, -2.0), Vector2(4.0, 5.0)), c_out)
		wick.draw_rect(Rect2(hand_pos + Vector2(-1.0, -1.0), Vector2(2.0, 3.0)), Color(LxWick.PAL_GOLD, alpha))
		wick.draw_rect(Rect2(hand_pos + Vector2(-1.0, 0.0), Vector2(2.0, 1.0)), Color(LxWick.PAL_CREAM, alpha))


static func collide_with_corner_slide(ctx: Node, from_p: Vector2, to_p: Vector2, rad: float, cross_pit: bool, cross_water: bool) -> Vector2:
	var res: Vector2 = ctx.call("collide", to_p, rad, cross_pit, cross_water) as Vector2
	var delta: Vector2 = to_p - from_p
	var dist: float = delta.length()
	if dist < 0.25:
		return res
	var mdir: Vector2 = delta / dist
	if absf(mdir.x) < 0.92 and absf(mdir.y) < 0.92:
		return res
	if (res - from_p).dot(mdir) >= dist * 0.45:
		return res
	var perp := Vector2(-mdir.y, mdir.x)
	var step_p: float = maxf(dist, 2.0)
	var probe_fwd: Vector2 = from_p + mdir * step_p
	var plus_ok: bool = ((ctx.call("collide", probe_fwd + perp * 5.0, rad, cross_pit, cross_water) as Vector2) - (from_p + perp * 5.0)).dot(mdir) > step_p * 0.65
	var minus_ok: bool = ((ctx.call("collide", probe_fwd - perp * 5.0, rad, cross_pit, cross_water) as Vector2) - (from_p - perp * 5.0)).dot(mdir) > step_p * 0.65
	if plus_ok != minus_ok:
		var nudge: Vector2 = perp * (1.0 if plus_ok else -1.0) * minf(dist * 0.85, 2.2)
		return ctx.call("collide", from_p + nudge, rad, cross_pit, cross_water) as Vector2
	return res
