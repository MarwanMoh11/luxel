class_name LxMoveLens
extends LxMove
## True Lens (Island 5, active cooldown): press lx_lens (R / C / LB) for a 4.0 s expanding
## True Lens Pulse (radius 104 px, 1.2 s warning flicker, 6.0 s cooldown = 2.0 s downtime).
## Lantern Anchor Synergy: while unlocked and Wick's lantern is thrown/hanging (FLYING/HANGING),
## the lantern also registers a "lens_anchor" reveal circle (radius 78 px) for stepping-stones.

var pulse_left: float = 0.0
var pulse_duration: float = 4.0
var warn_time: float = 1.2
var pulse_origin: Vector2 = Vector2.ZERO
var pulse_radius: float = 104.0
var hung_radius: float = 78.0

var last_origin: Vector2 = Vector2.ZERO
var last_radius: float = 0.0
var anchor_active: bool = false
var anchor_origin: Vector2 = Vector2.ZERO
var anchor_radius: float = 0.0

var _world_ctx: Node = null
var _wave_t: float = 0.0
var _wave_dur: float = 0.36
var _warn_tick_cd: float = 0.0
var _vis_clock: float = 0.0
var _puzzle_sheet: LxSpriteSheet = null


func set_world_ctx(world_ctx: Node) -> void:
	_world_ctx = world_ctx


func can_use() -> bool:
	return unlocked and not locked and cooldown_left <= 0.0 and wick != null and not wick.dead and wick.has_lantern()


func is_pulse_active() -> bool:
	return unlocked and not locked and pulse_left > 0.0


func is_warning() -> bool:
	return unlocked and not locked and pulse_left > 0.0 and pulse_left <= warn_time


func get_pulse_ratio() -> float:
	if not unlocked or locked or pulse_left <= 0.0:
		return 0.0
	return clampf(pulse_left / maxf(pulse_duration, 0.01), 0.0, 1.0)


func is_anchor_active() -> bool:
	return unlocked and not locked and wick != null and not wick.dead and wick.has_lantern() \
		and wick.lantern != null and wick.lantern.is_lure_active()


func get_reveal_radius() -> float:
	if not unlocked or locked or wick == null or not wick.has_lantern():
		return 0.0
	var data: Dictionary = get_data()
	pulse_radius = float(data.get("pulse_radius", 104.0))
	hung_radius = float(data.get("hung_radius", 78.0))
	if is_pulse_active():
		return pulse_radius
	if is_anchor_active():
		return hung_radius
	return 0.0


func get_reveal_origin() -> Vector2:
	if wick == null:
		return Vector2.ZERO
	if is_pulse_active():
		return wick.global_position
	if is_anchor_active():
		return wick.lantern.pos
	return wick.global_position


func press() -> bool:
	if wick == null or wick.dead or not wick.has_lantern():
		return false
	if not can_use():
		wick.emit_sfx("denied", wick.global_position, false)
		return false
	var data: Dictionary = get_data()
	var base_dur: float = float(data.get("duration", 4.0))
	pulse_duration = maxf(0.5, Lx.state.get_effective_lens_duration() if Lx.state != null else base_dur)
	warn_time = clampf(float(data.get("warn_time", 1.2)), 0.2, pulse_duration)
	pulse_radius = float(data.get("pulse_radius", 104.0))
	hung_radius = float(data.get("hung_radius", 78.0))
	var cd: float = maxf(float(data.get("cooldown", 6.0)), pulse_duration + 2.0)

	pulse_left = pulse_duration
	cooldown_left = cd
	pulse_origin = wick.global_position
	last_origin = pulse_origin
	last_radius = pulse_radius
	_wave_t = _wave_dur
	_warn_tick_cd = 0.0

	wick.emit_sfx("lens_reveal", wick.global_position, false)
	if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("add_kick"):
		Lx.camera.call("add_kick", Vector2.UP, 1.4)
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", pulse_origin, pulse_radius, 72.0)
	wick.spawn_ring(wick.global_position, 4.0, pulse_radius, _wave_dur, LxWick.PAL_ICE, 1.8)
	wick.spawn_ring(wick.global_position, 2.0, pulse_radius * 0.72, 0.28, LxWick.PAL_SKY, 1.2)
	wick.spawn_sparks(wick.global_position, Vector2.UP, 10, LxWick.PAL_ICE, 30.0, 95.0, 0.28)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var bi: float = 0.90 if LxHudFx.flash_reduced() else 1.45
		LxDarknessLayer.active_instance.add_burst_light(wick.global_position, pulse_radius * 1.15, bi, 0.42)
	register_circle(_world_ctx)
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	_vis_clock += dt
	if _wave_t > 0.0:
		_wave_t = maxf(0.0, _wave_t - dt)
	if pulse_left > 0.0:
		var was_warn: bool = pulse_left <= warn_time
		pulse_left = maxf(0.0, pulse_left - dt)
		if pulse_left > 0.0 and pulse_left <= warn_time:
			_warn_tick_cd -= dt
			if not was_warn or _warn_tick_cd <= 0.0:
				_warn_tick_cd = 0.34
				if wick != null and not wick.dead:
					wick.emit_sfx("prop_chime", wick.global_position, false)
		elif pulse_left <= 0.0:
			_warn_tick_cd = 0.0
			if wick != null and not wick.dead:
				wick.emit_sfx("phantom_phase", wick.global_position, false)


func register_circle(world_ctx: Node) -> void:
	var ctx: Node = world_ctx if world_ctx != null else (_world_ctx if _world_ctx != null else Lx.world)
	_world_ctx = ctx
	if not unlocked or locked or wick == null or wick.dead or not wick.has_lantern():
		last_radius = 0.0
		anchor_active = false
		anchor_radius = 0.0
		return
	var data: Dictionary = get_data()
	pulse_radius = float(data.get("pulse_radius", 104.0))
	hung_radius = float(data.get("hung_radius", 78.0))

	if is_pulse_active():
		pulse_origin = wick.global_position
		last_origin = pulse_origin
		last_radius = pulse_radius
		_register_world_circle(ctx, pulse_origin, pulse_radius, "lens")
	else:
		last_radius = 0.0

	if is_anchor_active():
		anchor_active = true
		anchor_origin = wick.lantern.pos
		anchor_radius = hung_radius
		_register_world_circle(ctx, anchor_origin, anchor_radius, "lens_anchor")
	else:
		anchor_active = false
		anchor_radius = 0.0


func tick_lens(_dt: float, world_ctx: Node) -> void:
	var ctx: Node = world_ctx if world_ctx != null else (_world_ctx if _world_ctx != null else Lx.world)
	_world_ctx = ctx
	if not unlocked or locked or wick == null or wick.dead or not wick.has_lantern():
		last_radius = 0.0
		anchor_active = false
		anchor_radius = 0.0
		return

	var data: Dictionary = get_data()
	pulse_radius = float(data.get("pulse_radius", 104.0))
	hung_radius = float(data.get("hung_radius", 78.0))

	if is_pulse_active():
		pulse_origin = wick.global_position
		last_origin = pulse_origin
		last_radius = pulse_radius
		_apply_reveal_circle(ctx, pulse_origin, pulse_radius, "lens")
	else:
		last_radius = 0.0

	if is_anchor_active():
		anchor_active = true
		anchor_origin = wick.lantern.pos
		anchor_radius = hung_radius
		_apply_reveal_circle(ctx, anchor_origin, anchor_radius, "lens_anchor")
	else:
		anchor_active = false
		anchor_radius = 0.0


func _register_world_circle(ctx: Node, origin: Vector2, rad: float, source: String) -> void:
	if ctx == null or rad <= 0.0:
		return
	if ctx.has_method("register_lens_circle"):
		ctx.call("register_lens_circle", origin, rad)
	elif ctx.has_method("apply_light"):
		ctx.call("apply_light", origin, rad, source)


func _apply_reveal_circle(ctx: Node, origin: Vector2, rad: float, source: String) -> void:
	if rad <= 0.0:
		return
	_register_world_circle(ctx, origin, rad, source)

	var inters: Array = wick.world_get_interactables(ctx)
	for it_var: Variant in inters:
		if not (it_var is Object):
			continue
		var item: Object = it_var as Object
		if not is_instance_valid(item) or not item.has_method("on_light"):
			continue
		var ipos: Vector2 = wick.get_entity_pos(item)
		var irad: float = wick.get_entity_radius(item, 8.0)
		if ipos.distance_to(origin) <= rad + irad:
			item.call("on_light", rad, source)

	var enemies: Array = wick.world_get_enemies(ctx)
	for e_var: Variant in enemies:
		if not (e_var is Object):
			continue
		var enemy: Object = e_var as Object
		if not is_instance_valid(enemy) or not enemy.has_method("on_light"):
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		var epos: Vector2 = wick.get_entity_pos(enemy)
		var erad: float = wick.get_entity_radius(enemy, 8.0)
		if epos.distance_to(origin) <= rad + erad:
			var arity: int = wick.get_method_arity(enemy, "on_light")
			if arity >= 3:
				enemy.call("on_light", rad, origin, source)
			elif arity == 2:
				enemy.call("on_light", rad, source)
			else:
				enemy.call("on_light", rad)


func draw_fx(canvas: CanvasItem, off: Vector2) -> void:
	if not unlocked or locked:
		return
	var pulse_on: bool = is_pulse_active() and last_radius > 0.0
	var anch_on: bool = anchor_active and anchor_radius > 0.0
	if not pulse_on and not anch_on and _wave_t <= 0.0:
		return

	var flash_red: bool = LxHudFx.flash_reduced()
	var rot: float = _vis_clock * 0.35
	var flicker_coral: bool = flash_red or (int(floorf(_vis_clock * 14.0)) % 2 == 0)

	# 1. Expanding pixel-stepped starlight reveal wave on cast (zero smooth vector arcs)
	if _wave_t > 0.0:
		var wu: float = 1.0 - clampf(_wave_t / maxf(_wave_dur, 0.01), 0.0, 1.0)
		var wc: Vector2 = (pulse_origin + off).round() + Vector2(0.0, -5.0)
		var wr: float = lerpf(8.0, pulse_radius, wu)
		var wa: float = (1.0 - wu) * (0.55 if flash_red else 0.85)
		var wpips: int = clampi(int(roundf(wr * 0.55)), 16, 44)
		for wi: int in range(wpips):
			var wang: float = rot * 0.6 + (TAU * float(wi)) / float(wpips)
			var p_out: Vector2 = (wc + Vector2(cos(wang) * wr, sin(wang) * wr)).round()
			canvas.draw_rect(Rect2(p_out, Vector2(2.0 if wi % 2 == 0 else 1.0, 1.0)), Color(LxWick.PAL_ICE, wa))
			if wi % 2 == 0 and wr > 8.0:
				var p_in: Vector2 = (wc + Vector2(cos(wang + 0.08) * (wr - 4.0), sin(wang + 0.08) * (wr - 4.0))).round()
				canvas.draw_rect(Rect2(p_in, Vector2.ONE), Color(LxWick.PAL_SKY, wa * 0.65))

	# 2. Revealed raw "phantom" ('P') tiles across all active lens circles
	var circles: Array[Dictionary] = []
	if pulse_on:
		circles.append({"origin": last_origin, "radius": last_radius, "warn": is_warning()})
	if anch_on:
		var awarn: bool = wick != null and wick.lantern != null and wick.lantern.is_hanging() and wick.lantern.hang_timer <= 1.1
		circles.append({"origin": anchor_origin, "radius": anchor_radius, "warn": awarn})
	_draw_revealed_phantom_tiles(canvas, off, circles, flicker_coral, flash_red)

	# 3. Active Lens circle rings + hidden biome runes
	var isl_l: int = Lx.state.island_id if Lx.state != null else 1
	var b_glow: Color = LxBiomePalette.col(isl_l, "glow")
	var relit_l: bool = Lx.state != null and Lx.state.relit_islands.has(isl_l)
	var harm_l: bool = Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % isl_l, false))
	var rune_col: Color = LxWick.PAL_GOLD if (relit_l or harm_l) else b_glow
	for cinfo: Dictionary in circles:
		var orig: Vector2 = cinfo["origin"] as Vector2
		var rad: float = float(cinfo["radius"])
		var warn: bool = bool(cinfo["warn"])
		_draw_lens_ring(canvas, off, orig, rad, warn, flicker_coral, rot, flash_red, b_glow, rune_col)
		_draw_hidden_biome_runes(canvas, off, orig, rad, isl_l, rune_col, rot, flash_red)


func _draw_lens_ring(
	canvas: CanvasItem,
	off: Vector2,
	origin: Vector2,
	rad: float,
	warn: bool,
	flicker_coral: bool,
	rot: float,
	flash_red: bool,
	b_glow: Color,
	tick_col: Color
) -> void:
	var center: Vector2 = (origin + off).round() + Vector2(0.0, -5.0)
	var outer_c: Color = LxWick.PAL_CORAL if (warn and flicker_coral) else LxWick.PAL_ICE
	var inner_c: Color = LxWick.PAL_ICE if (warn and flicker_coral) else LxWick.PAL_SKY
	var outer_a: float = 0.70 if warn else 0.42
	var inner_a: float = 0.42 if warn else 0.24
	# Pixel-stepped starlight dust rim (zero smooth vector draw_arc circles)
	var pips: int = clampi(int(roundf(rad * 0.42)), 16, 40)
	for i: int in range(pips):
		if i % 3 == 2:
			continue
		var shim: float = 1.0 if flash_red else (0.76 + 0.24 * sin(rot * 3.5 + float(i) * 0.9))
		var a: float = rot * 0.5 + (TAU * float(i)) / float(pips)
		var pp: Vector2 = (center + Vector2(cos(a) * rad, sin(a) * rad)).round()
		var sz := Vector2(2.0, 1.0) if (i % 4 == 0) else Vector2.ONE
		canvas.draw_rect(Rect2(pp, sz), Color(outer_c, outer_a * shim))
		if i % 4 == 0:
			var ip: Vector2 = (center + Vector2(cos(a - 0.08) * (rad - 3.0), sin(a - 0.08) * (rad - 3.0))).round()
			canvas.draw_rect(Rect2(ip, Vector2.ONE), Color(inner_c, inner_a * shim))
	# 4 delicate cardinal starlight glints instead of CAD tick lines
	for j: int in range(4):
		var pang: float = rot * 0.4 + float(j) * (PI * 0.5)
		var sp: Vector2 = (center + Vector2(cos(pang) * rad, sin(pang) * rad)).round()
		var tw: float = 0.78 if flash_red else (0.62 + 0.30 * sin(rot * 4.5 + float(j) * 1.57))
		var pcol: Color = (LxWick.PAL_CORAL if flicker_coral else LxWick.PAL_CREAM) if warn else (LxWick.PAL_CREAM if (j % 2 == 0) else b_glow)
		canvas.draw_rect(Rect2(sp + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(tick_col if not warn else outer_c, tw * 0.65))
		canvas.draw_rect(Rect2(sp + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(tick_col if not warn else outer_c, tw * 0.65))
		canvas.draw_rect(Rect2(sp, Vector2.ONE), Color(pcol, tw))


func _draw_revealed_phantom_tiles(
	canvas: CanvasItem,
	off: Vector2,
	circles: Array[Dictionary],
	flicker_coral: bool,
	flash_red: bool
) -> void:
	var ctx: Node = _world_ctx if (_world_ctx != null and is_instance_valid(_world_ctx)) else Lx.world
	if ctx == null or not is_instance_valid(ctx) or circles.is_empty():
		return
	var grid_v: Variant = ctx.get("grid")
	if not (grid_v is Array):
		return
	var g: Array = grid_v as Array
	var h: int = g.size()
	if h <= 0:
		return
	var w: int = int(ctx.get("width")) if ctx.get("width") != null else 0
	var ts_v: Variant = ctx.get("tile_size")
	var ts: float = float(ts_v) if (ts_v is int or ts_v is float) and float(ts_v) > 0.0 else float(LxMapFormat.DEFAULT_TILE_SIZE)
	if w <= 0 or ts <= 0.0:
		return

	# Map Vector2i -> bool (true if ONLY covered by warning circles, false if safely supported)
	var tiles: Dictionary = {}
	for cinfo: Dictionary in circles:
		var orig: Vector2 = cinfo["origin"] as Vector2
		var rad: float = float(cinfo["radius"])
		var warn: bool = bool(cinfo["warn"])
		var r2: float = rad * rad
		var tx0: int = maxi(0, int(floor((orig.x - rad) / ts)))
		var tx1: int = mini(w - 1, int(floor((orig.x + rad) / ts)))
		var ty0: int = maxi(0, int(floor((orig.y - rad) / ts)))
		var ty1: int = mini(h - 1, int(floor((orig.y + rad) / ts)))
		for ty: int in range(ty0, ty1 + 1):
			var row: PackedStringArray = g[ty] as PackedStringArray
			if row.size() <= tx1:
				continue
			for tx: int in range(tx0, tx1 + 1):
				if row[tx] != "phantom":
					continue
				var tc := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
				if tc.distance_squared_to(orig) > r2:
					continue
				var key := Vector2i(tx, ty)
				if not tiles.has(key):
					tiles[key] = warn
				elif not warn:
					tiles[key] = false

	var alpha_sc: float = 0.80 if flash_red else 1.0
	if _puzzle_sheet == null:
		_puzzle_sheet = LxSpriteSheet.load_sheet("res://luxel/art/props/puzzle_interactables.json")
	var psheet: LxSpriteSheet = _puzzle_sheet
	var shimmer_f: int = int(floorf(_vis_clock * 2.4)) % 2
	for key_v: Variant in tiles.keys():
		var tk: Vector2i = key_v as Vector2i
		var is_warn_tile: bool = bool(tiles[tk])
		var tl: Vector2 = (Vector2(float(tk.x) * ts, float(tk.y) * ts) + off).round()
		var mc: Vector2 = (tl + Vector2(ts * 0.5, ts * 0.5)).round()
		var use_coral: bool = is_warn_tile and flicker_coral
		# Render revealed phantom floor as carved starlight-stone masonry (no wireframe boxes/diamonds!)
		var prop_k: String = "phantom_warn" if is_warn_tile else "phantom_solid"
		if psheet != null and psheet.draw_prop(canvas, mc, prop_k, _vis_clock, Color(1.0, 1.0, 1.0, 0.92 * alpha_sc), 1 if use_coral else shimmer_f):
			continue
		var body_c := Color(LxPalette.PAL["plum"] as Color if use_coral else (LxPalette.PAL["deep"] as Color), 0.72 * alpha_sc)
		var slab_c := Color(LxPalette.PAL["wine"] as Color if use_coral else (LxPalette.PAL["blue"] as Color), 0.78 * alpha_sc)
		var bevel_c := Color(LxWick.PAL_CORAL if use_coral else LxWick.PAL_SKY, 0.82 * alpha_sc)
		var glint_c := Color(LxWick.PAL_CREAM if not use_coral else LxWick.PAL_GOLD, 0.88 * alpha_sc)
		canvas.draw_rect(Rect2(tl + Vector2(1.0, 1.0), Vector2(ts - 2.0, ts - 2.0)), body_c)
		canvas.draw_rect(Rect2(tl + Vector2(2.0, 2.0), Vector2(ts - 4.0, ts - 5.0)), slab_c)
		# Chiseled bevelled stone top/left edge & recessed bottom mortar
		canvas.draw_rect(Rect2(tl + Vector2(2.0, 1.0), Vector2(ts - 5.0, 1.0)), bevel_c)
		canvas.draw_rect(Rect2(tl + Vector2(1.0, 2.0), Vector2(1.0, ts - 5.0)), bevel_c)
		canvas.draw_rect(Rect2(tl + Vector2(2.0, ts - 2.0), Vector2(ts - 4.0, 1.0)), Color(LxWick.PAL_VOID, 0.65 * alpha_sc))
		# Carved miniature 4-point astral inlay in stone center
		canvas.draw_rect(Rect2(mc + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), bevel_c)
		canvas.draw_rect(Rect2(mc + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), bevel_c)
		canvas.draw_rect(Rect2(mc, Vector2.ONE), glint_c)


func _draw_hidden_biome_runes(
	canvas: CanvasItem,
	off: Vector2,
	origin: Vector2,
	rad: float,
	isl: int,
	b_glow: Color,
	rot: float,
	flash_red: bool
) -> void:
	# Reveals delicate biome-unique astral runes anchored in world space inside the True Lens circle
	const STEP: float = 56.0
	var r_lim: float = rad - 6.0
	if r_lim <= 10.0:
		return
	var gx0: int = int(floor((origin.x - r_lim) / STEP))
	var gx1: int = int(ceil((origin.x + r_lim) / STEP))
	var gy0: int = int(floor((origin.y - r_lim) / STEP))
	var gy1: int = int(ceil((origin.y + r_lim) / STEP))
	for gy: int in range(gy0, gy1 + 1):
		for gx: int in range(gx0, gx1 + 1):
			var h: int = absi((gx * 73856093) ^ (gy * 19349663) ^ (isl * 83492791))
			if (h & 7) >= 3:
				continue
			var wp := Vector2(
				(float(gx) + 0.5) * STEP + float(((h >> 3) & 31) - 16),
				(float(gy) + 0.5) * STEP + float(((h >> 8) & 31) - 16)
			)
			var dist: float = wp.distance_to(origin)
			if dist >= r_lim:
				continue
			var reveal: float = clampf(1.0 - dist / r_lim, 0.0, 1.0)
			var tw: float = 0.72 if flash_red else (0.58 + 0.30 * sin(rot * 4.5 + float(h & 15)))
			var a: float = clampf(reveal * 0.42 * tw, 0.0, 0.48)
			if a < 0.04:
				continue
			var p: Vector2 = (wp + off).round()
			var c_main := Color(b_glow, a)
			var c_hi := Color(LxWick.PAL_ICE, a * 0.9)
			match isl:
				1: # Bell-arch glyph
					canvas.draw_arc(p, 3.0, PI, TAU, 6, c_main, 1.0)
					canvas.draw_rect(Rect2(p + Vector2(-0.5, 1.0), Vector2(1.0, 1.0)), c_hi)
				2: # Tide wave-chevron
					canvas.draw_line(p + Vector2(-3.0, 1.0), p + Vector2(0.0, -2.0), c_hi, 1.0)
					canvas.draw_line(p + Vector2(0.0, -2.0), p + Vector2(3.0, 1.0), c_main, 1.0)
				3: # Heartwood leaf-sprig
					canvas.draw_line(p + Vector2(-3.0, -1.0), p + Vector2(0.0, 2.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(3.0, -1.0), p + Vector2(0.0, 2.0), c_main, 1.0)
					canvas.draw_rect(Rect2(p + Vector2(-0.5, -2.0), Vector2(1.0, 1.0)), c_hi)
				4: # Stained-glass diamond
					canvas.draw_line(p + Vector2(0.0, -3.0), p + Vector2(3.0, 0.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(3.0, 0.0), p + Vector2(0.0, 3.0), c_hi, 1.0)
					canvas.draw_line(p + Vector2(0.0, 3.0), p + Vector2(-3.0, 0.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(-3.0, 0.0), p + Vector2(0.0, -3.0), c_hi, 1.0)
				5: # Astral 4-point star
					canvas.draw_line(p + Vector2(-3.0, 0.0), p + Vector2(3.0, 0.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(0.0, -3.0), p + Vector2(0.0, 3.0), c_hi, 1.0)
				6: # Forge ember chevron
					canvas.draw_line(p + Vector2(-3.0, 2.0), p + Vector2(0.0, -2.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(0.0, -2.0), p + Vector2(3.0, 2.0), c_main, 1.0)
					canvas.draw_rect(Rect2(p, Vector2(1.0, 1.0)), Color(LxWick.PAL_CREAM, a))
				7: # Silver lunar crescent
					canvas.draw_arc(p, 3.0, -PI * 0.45, PI * 0.45, 6, c_hi, 1.0)
					canvas.draw_rect(Rect2(p + Vector2(-2.0, 0.0), Vector2(1.0, 1.0)), c_main)
				_: # Dawn sunburst
					canvas.draw_line(p + Vector2(-3.0, 0.0), p + Vector2(3.0, 0.0), c_main, 1.0)
					canvas.draw_line(p + Vector2(0.0, -3.0), p + Vector2(0.0, 3.0), c_main, 1.0)
					canvas.draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(LxWick.PAL_CREAM, a))


func reset() -> void:
	super.reset()
	pulse_left = 0.0
	last_radius = 0.0
	anchor_active = false
	anchor_radius = 0.0
	_wave_t = 0.0
	_warn_tick_cd = 0.0
	_vis_clock = 0.0
