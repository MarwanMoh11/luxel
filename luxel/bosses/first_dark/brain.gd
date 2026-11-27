class_name LxFirstDarkBoss
extends LxBossBase
## Island 8 Superboss (80 Moths — superboss_first_dark): THE FIRST DARK.
## Primordial obsidian eclipse-oculus inside 3 counter-rotating astrolabe rings!
## Core Twist: ERASES FLOOR TILES into temporary lethal void (cleanly restored after 7.5s
## and on reset_encounter!). Pulse True Lens to read memory-tiles (+1.35x clarity dmg),
## rip free stolen golden Moth-Sparks (+20 Ember & 1.5x core exposure), and in P3 witness
## all 80 rescued Moths form a golden safety halo around the rim!

const MOTH_RING_COUNT: int = 80
const ERASE_RESTORE_S: float = 6.5

var _erased_patches: Array[Dictionary] = [] # {tiles: Array[Vector2i], orig: Array[String], ttl: float}
var _moth_sparks: Array[Dictionary] = [] # {pos: Vector2, angle: float, rad: float, alive: bool}
var _lens_memory_t: float = 0.0
var _core_open_t: float = 0.0
var _sparks_ripped: int = 0
var _corona_ang: float = 0.0
var _p3_halo_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "first_dark"
	boss_id = "first_dark"
	boss_name_key = "ISL8_BOSS_FIRST_DARK"
	island_id = 8
	is_miniboss = false
	reward_heart = "full"
	music_cue = "superboss_b"
	music_p2_cue = "superboss_b"
	max_hp = 275.0
	hp = 275.0
	body_radius = 14.0
	move_speed = 32.0
	stagger_threshold = 24.0
	stagger_duration = 2.00
	post_stagger_immunity = 4.2
	punish_dmg_mult = 1.40
	post_recover_cd = 0.30
	intro_duration = 0.70
	phase_shift_duration = 0.80
	death_duration = 2.4
	shard_drop = 80


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.60, 0.28]) # P1 Quadrants -> P2 Radial Slices + 3 Moth-Sparks -> P3 80-Moth Safety Halo!

	# Attack 1: Tile Erasure Wave (0.75s chalk-crack tell -> erases outer-quadrant floor patches temporarily!)
	register_attack("tile_erasure_wave", {
		"weight": 1.35, "tell": 0.75, "commit": 0.34, "recover": 1.25, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var rects: Array[Rect2i] = _pick_erasure_rects(tgt)
			for tr: Rect2i in rects:
				var wr := Rect2(float(tr.position.x) * 16.0, float(tr.position.y) * 16.0, float(tr.size.x) * 16.0, float(tr.size.y) * 16.0)
				var captured_tr: Rect2i = tr
				ground.warn_rect(wr, last_tell_duration, 0.5, "plum", "cream", 0.0, func(_d: Dictionary) -> void:
					_apply_temp_erasure(captured_tr, ERASE_RESTORE_S))
			# Also pressure Wick's current spot with an aimed eclipse ring
			ground.warn_ring(clamp_to_arena(tgt), 19.0, last_tell_duration + 0.06, 0.5, "wine", "gold")
			stage.play_sfx("tile_erase", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aa: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 114.0, aa + 0.60, 0.85, {"color": "ice", "source": "erasure_wave"})
			stage.shake(0.22)
			stage.play_sfx("tile_erase", pos),
	})

	# Attack 2: Primordial Corona (rotating black-gold spokes + aimed corona fan)
	register_attack("primordial_corona", {
		"weight": 1.25, "tell": 0.58, "commit": 0.42, "recover": 1.25, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_corona_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			facing = _corona_ang
			var spokes: int = 4 if phase == 1 else 6
			for k: int in range(spokes):
				var dv: Vector2 = Vector2.from_angle(_corona_ang + float(k) * (TAU / float(spokes)))
				ground.warn_lane(pos, clamp_to_arena(pos + dv * 170.0), 8.0, last_tell_duration, 0.0, "gold", "cream")
			stage.play_sfx("beam_charge", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d1: Vector2 = Vector2.from_angle(_corona_ang)
			patterns.emit_chain_lightning([clamp_to_arena(pos - d1 * 165.0), pos, clamp_to_arena(pos + d1 * 165.0)], 0.48, 8.0, 0.28, 0.5)
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else d1
			patterns.emit_fan(pos, aim, 3 if phase < 3 else 5, 0.72, 132.0, {"color": "gold", "source": "corona_flare"})
			patterns.emit_spiral(pos, 3, 112.0, _corona_ang, 0.36, 1 if phase == 1 else 2, 0.16, {"color": "coral", "source": "corona_spoke"})
			stage.shake(0.20)
			stage.play_sfx("beam_fire", pos),
	})

	# Attack 3: Spark Snatch (pulls hung lantern inward, launches boomerangs & spawns rippable Moth-Spark!)
	register_attack("spark_snatch", {
		"weight": 1.20, "tell": 0.54, "commit": 0.38, "recover": 1.30, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 48.0, last_tell_duration, 0.0, "gold", "ice")
			patterns.emit_rain(ground, [clamp_to_arena(tgt)], last_tell_duration + 0.04, 19.0, 0.5, "plum", "gold")
			stage.play_sfx("hush_pulse", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			patterns.emit_boomerang(pos, aim.rotated(0.36), 134.0, 0.64, 0.85, {"color": "gold", "source": "snatch_arc"})
			patterns.emit_boomerang(pos, aim.rotated(-0.36), 134.0, 0.64, -0.85, {"color": "ice", "source": "snatch_arc"})
			_pull_hung_lantern()
			if _live_spark_count() < (3 if phase >= 2 else 1):
				_spawn_moth_spark(aim.angle() + 0.7, 46.0)
			stage.shake(0.15)
			stage.play_sfx("moth_spark_rip", pos),
	})

	# Attack 4 (P2 & P3): Abyssal Eclipse (shrinking safe-zone inversion + expanding obsidian square!)
	register_attack("abyssal_eclipse", {
		"phases": [2, 3], "weight": 1.25, "tell": 0.64, "commit": 0.42, "recover": 1.40, "cooldown": 2.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var s1: Vector2 = clamp_to_arena(c + (tgt - c).limit_length(48.0))
			var s2: Vector2 = clamp_to_arena(c - (s1 - c))
			ground.warn_safe_inversion(arena_rect, [s1, s2], 38.0, last_tell_duration + 0.14, 0.24, 0.5, "gold", "plum")
			stage.play_sfx("bell_toll_heavy", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_expanding_square(pos, 3, 106.0, anim_t, 1, {"color": "cream" if phase >= 3 else "gold", "source": "abyssal_eclipse"})
			stage.light_burst(pos, 108.0, 1.5, 0.38)
			stage.shake(0.22)
			stage.play_sfx("sunflare_burst", pos),
	})


func _on_reset_encounter() -> void:
	_restore_all_temp_erasures()
	_moth_sparks.clear()
	_lens_memory_t = 0.0
	_core_open_t = 0.0
	_sparks_ripped = 0
	_corona_ang = 0.0
	_p3_halo_t = 0.0
	pos = arena_rect.get_center()
	position = pos.round()


func _on_engage() -> void:
	pos = arena_rect.get_center()
	position = pos.round()


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: Variant = "") -> void:
	if boss_state == BossState.DEATH:
		return
	var src: String = str(source)
	if b is String and src.is_empty():
		src = str(b)
	if src == "lens":
		if _lens_memory_t <= 0.05:
			stage.play_sfx("lens_reveal", pos)
		_lens_memory_t = maxf(_lens_memory_t, 3.2)


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# Spawn 3 orbiting Moth-Sparks to rip free for Ember + 1.5x core exposure!
		_moth_sparks.clear()
		for k: int in range(3):
			_spawn_moth_spark(float(k) * (TAU / 3.0), 48.0)
		stage.darkness_pulse(0.70, 1.1)
		stage.shake(0.26)
		stage.play_sfx("tile_erase", c)
	elif new_phase == 3:
		# 80 rescued Moths dive inward forming a radiant golden safety halo!
		_p3_halo_t = 1.0
		_restore_all_temp_erasures()
		stage.light_burst(c, 132.0, 1.65, 0.55)
		stage.shake(0.30)
		stage.play_sfx("great_lamp_bloom", c)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_lens_memory_t = maxf(0.0, _lens_memory_t - dt)
	_core_open_t = maxf(0.0, _core_open_t - dt)
	if phase >= 3:
		_p3_halo_t = minf(1.0, _p3_halo_t + dt * 1.4)
	_tick_temp_erasures(dt)
	_tick_moth_sparks(dt)


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	var c: Vector2 = arena_rect.get_center()
	var drift: Vector2 = c + Vector2(cos(anim_t * 0.8) * 18.0, sin(anim_t * 1.1) * 12.0)
	move_boss((drift - pos).limit_length(move_speed * dt), true)
	_face_point(target, 3.6, dt)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var mult: float = 1.0
	if _core_open_t > 0.0:
		mult *= 1.45
	if _lens_memory_t > 0.0:
		mult *= 1.30
	if src == LxHit.SOURCE_SUNFLARE:
		mult *= 1.55 if _sparks_ripped > 0 else 1.25
		add_stagger(5.0)
	elif src == LxHit.SOURCE_RECALL or src == LxHit.SOURCE_ZIP:
		if _rip_nearest_spark(h["origin"] as Vector2, 999.0):
			mult *= 1.35
	return dmg * mult


func _on_death_start() -> void:
	_restore_all_temp_erasures()
	_moth_sparks.clear()
	stage.light_burst(pos, 148.0, 1.75, 0.65)
	stage.shake(0.32)
	stage.play_sfx("great_lamp_bloom", pos)


func _pick_erasure_rects(tgt: Vector2) -> Array[Rect2i]:
	var c: Vector2 = arena_rect.get_center()
	var cx_t: int = int(c.x / 16.0)
	var cy_t: int = int(c.y / 16.0)
	var w_t: int = int(tgt.x / 16.0)
	var h_t: int = int(tgt.y / 16.0)
	var cands: Array[Rect2i] = [
		Rect2i(maxi(2, cx_t - 6), maxi(2, cy_t - 3), 1, 1),
		Rect2i(cx_t + 5, maxi(2, cy_t - 3), 1, 1),
		Rect2i(maxi(2, cx_t - 6), cy_t + 3, 1, 1),
		Rect2i(cx_t + 5, cy_t + 3, 1, 1),
	]
	var out: Array[Rect2i] = []
	for r: Rect2i in cands:
		# Keep boss center & main orbit ring cleanly navigable; carve outer-quadrant void wells!
		if r.grow(1).has_point(Vector2i(cx_t, cy_t)):
			continue
		if out.size() < (2 if phase < 3 else 3):
			if out.is_empty() or r.position.distance_to(Vector2i(w_t, h_t)) <= 10.0 or phase >= 2:
				out.append(r)
	if out.is_empty():
		out.append(cands[0])
	return out


func _apply_temp_erasure(rect: Rect2i, dur: float) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return
	var gv: Variant = world_ctx.get("grid")
	if not (gv is Array):
		return
	var g: Array = gv as Array
	var gh: int = g.size()
	var gw: int = (g[0] as PackedStringArray).size() if gh > 0 else 0
	var tiles: Array[Vector2i] = []
	var origs: Array[String] = []
	for ty: int in range(maxi(2, rect.position.y), mini(gh - 2, rect.end.y)):
		var row: PackedStringArray = g[ty] as PackedStringArray
		for tx: int in range(maxi(2, rect.position.x), mini(gw - 2, rect.end.x)):
			if row[tx] in ["ground", "path", "bridge"]:
				tiles.append(Vector2i(tx, ty))
				origs.append(row[tx])
	if tiles.is_empty():
		return
	stage.set_tiles(world_ctx, rect, "pit")
	_erased_patches.append({"tiles": tiles, "orig": origs, "ttl": dur})


func _tick_temp_erasures(dt: float) -> void:
	for i: int in range(_erased_patches.size() - 1, -1, -1):
		var patch: Dictionary = _erased_patches[i]
		patch["ttl"] = float(patch["ttl"]) - dt
		if float(patch["ttl"]) <= 0.0:
			_restore_patch(patch)
			_erased_patches.remove_at(i)


func _restore_patch(patch: Dictionary) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return
	var tiles: Array = patch["tiles"] as Array
	var origs: Array = patch["orig"] as Array
	for k: int in range(tiles.size()):
		var tp: Vector2i = tiles[k] as Vector2i
		var ot: String = str(origs[k])
		if world_ctx.has_method("set_tiles"):
			world_ctx.call("set_tiles", Rect2i(tp.x, tp.y, 1, 1), ot)
		else:
			var gv: Variant = world_ctx.get("grid")
			if gv is Array and tp.y >= 0 and tp.y < (gv as Array).size():
				var row: PackedStringArray = (gv as Array)[tp.y] as PackedStringArray
				if tp.x >= 0 and tp.x < row.size():
					row[tp.x] = ot
					(gv as Array)[tp.y] = row
	if world_ctx is CanvasItem:
		(world_ctx as CanvasItem).queue_redraw()


func _restore_all_temp_erasures() -> void:
	for patch: Dictionary in _erased_patches:
		_restore_patch(patch)
	_erased_patches.clear()


func _spawn_moth_spark(ang: float, rad: float) -> void:
	_moth_sparks.append({"pos": pos + Vector2.from_angle(ang) * rad, "angle": ang, "rad": rad, "alive": true})


func _live_spark_count() -> int:
	var n: int = 0
	for s: Dictionary in _moth_sparks:
		if bool(s["alive"]): n += 1
	return n


func _tick_moth_sparks(dt: float) -> void:
	var wick_n: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for s: Dictionary in _moth_sparks:
		if not bool(s["alive"]): continue
		s["angle"] = wrapf(float(s["angle"]) + 1.45 * dt, -PI, PI)
		var sp: Vector2 = pos + Vector2.from_angle(float(s["angle"])) * float(s["rad"])
		s["pos"] = sp
		if wick_n != null:
			# Rip free if Wick's bolt, recalling lantern, or body grazes it!
			if wick_n.global_position.distance_to(sp) <= 18.0:
				_consume_spark(s, wick_n); continue
			if wick_n.lantern != null and wick_n.lantern.pos.distance_to(sp) <= 18.0:
				_consume_spark(s, wick_n); continue
			for bi: int in range(wick_n.bolts.size() - 1, -1, -1):
				var bv: Variant = wick_n.bolts[bi]
				if bv is Object and (bv.get("pos") as Vector2).distance_to(sp) <= 12.0:
					_consume_spark(s, wick_n); break


func _rip_nearest_spark(from_p: Vector2, max_r: float) -> bool:
	var wick_n: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for s: Dictionary in _moth_sparks:
		if bool(s["alive"]) and (s["pos"] as Vector2).distance_to(from_p) <= max_r:
			_consume_spark(s, wick_n)
			return true
	return false


func _consume_spark(s: Dictionary, wick_n: LxWick) -> void:
	s["alive"] = false
	_sparks_ripped += 1
	_core_open_t = 4.5
	if wick_n != null:
		wick_n.ember = minf(100.0, wick_n.ember + 20.0)
	stage.play_sfx("moth_spark_rip", s["pos"] as Vector2)
	stage.light_burst(s["pos"] as Vector2, 54.0, 1.35, 0.28)


func _pull_hung_lantern() -> void:
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if w.lantern != null and w.lantern.is_hanging():
			w.lantern.pos = w.lantern.pos.move_toward(pos, 26.0)


func _body_color() -> Color:
	return (PAL["cream"] if _core_open_t > 0.0 else (PAL["wine"] if phase >= 3 else PAL["void"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = is_flash_reduced()
	# True Lens golden memory-tile overlay over erased patches!
	if _lens_memory_t > 0.0:
		for patch: Dictionary in _erased_patches:
			for tv: Variant in (patch["tiles"] as Array):
				var tp: Vector2i = tv as Vector2i
				var loc: Vector2 = (Vector2(float(tp.x) * 16.0, float(tp.y) * 16.0) - pos + off).round()
				draw_rect(Rect2(loc, Vector2(16.0, 16.0)), Color(PAL["gold"] as Color, 0.25), true)
				draw_rect(Rect2(loc, Vector2(16.0, 16.0)), PAL["void"] as Color, false, 3.0)
				draw_rect(Rect2(loc, Vector2(16.0, 16.0)), PAL["ice"] as Color, false, 1.0)
	# Orbiting rippable golden Moth-Sparks!
	for s: Dictionary in _moth_sparks:
		if not bool(s["alive"]): continue
		var sp: Vector2 = ((s["pos"] as Vector2) - pos + off).round()
		draw_arc(sp, 6.0, 0.0, TAU, 12, PAL["void"] as Color, 3.0)
		draw_arc(sp, 6.0, 0.0, TAU, 12, PAL["gold"] as Color, 1.0)
		draw_rect(Rect2(sp - Vector2(2.0, 1.0), Vector2(4.0, 2.0)), PAL["cream"] as Color)
	# Core exposed golden eclipse fracture ring
	if _core_open_t > 0.0:
		draw_arc(c, 22.0, 0.0, TAU, 24, PAL["void"] as Color, 4.0)
		draw_arc(c, 22.0, 0.0, TAU, 24, PAL["gold"] as Color, 2.0)
	# 80 Rescued Moths orbiting the arena rim (diving closer into golden safety halo in P3!)
	if arena_rect.has_area() and boss_state != BossState.DEATH:
		var ac: Vector2 = (arena_rect.get_center() - pos + off).round()
		var rx: float = lerpf(arena_rect.size.x * 0.48, arena_rect.size.x * 0.40, _p3_halo_t)
		var ry: float = lerpf(arena_rect.size.y * 0.48, arena_rect.size.y * 0.40, _p3_halo_t)
		var spd: float = 0.22 if fred else (0.55 if phase >= 3 else 0.30)
		for mi: int in range(MOTH_RING_COUNT):
			var ma: float = anim_t * spd + float(mi) * (TAU / float(MOTH_RING_COUNT))
			var wob: float = 0.0 if fred else sin(anim_t * 3.0 + float(mi)) * 2.0
			var mp: Vector2 = (ac + Vector2(cos(ma) * (rx + wob), sin(ma) * (ry + wob))).round()
			var mc: Color = (PAL["cream"] if (mi % 4 == 0 or phase >= 3) else PAL["gold"]) as Color
			draw_rect(Rect2(mp, Vector2(2.0, 1.0)), mc)
