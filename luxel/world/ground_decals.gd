class_name LxGroundDecals
extends Node2D
## Persistent fading world-space ground combat & movement decals (z_index = -2):
## Sunflare scorch rings, boss impact craters, prism frost-stars, water splash ripples,
## and biome-tinted fading footsteps. Uses strictly the 20 Last Light palette colours.

const PAL: Dictionary = LxPalette.PAL
const MAX_DECALS: int = 44
const HALF_W: float = 188.0
const HALF_H: float = 118.0

enum Kind { FOOTSTEP, RIPPLE, SCORCH, CRATER, PRISM_STAR, BLOSSOM, SKID, BLOCK_TRACK, WALL_SCUFF }

static var active_instance: LxGroundDecals = null

var _island_id: int = 1
var _region: Node = null
var _cam_center: Vector2 = Vector2.ZERO
var _decals: Array[Dictionary] = []
var _step_cd: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO
var _step_alt: bool = false
var _step_seq: int = 0
var _was_airborne: bool = false
var _last_block_pos: Vector2 = Vector2.ZERO
var _last_block_id: int = 0
var _scrape_sfx_cd: float = 0.0
var _bound_events: LxEventBus = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -2
	active_instance = self
	_sync_events()


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null
	_set_events(_bound_events, false)
	_bound_events = null


func _sync_events() -> void:
	if Lx.events == null or not is_instance_valid(Lx.events) or _bound_events == Lx.events:
		return
	_set_events(_bound_events, false)
	_bound_events = Lx.events
	_set_events(_bound_events, true)


func _set_events(ev: LxEventBus, bind: bool) -> void:
	if ev == null or not is_instance_valid(ev):
		return
	var pairs: Array = [
		[&"enemy_killed", _on_enemy_killed],
		[&"boss_phase_changed", _on_boss_phase_changed],
		[&"boss_defeated", _on_boss_defeated],
		[&"seal_broken", _on_seal_broken],
		[&"beacon_lit", _on_beacon_lit],
		[&"player_healed", _on_player_healed],
	]
	for pair: Array in pairs:
		var sig: StringName = pair[0] as StringName
		var cb: Callable = pair[1] as Callable
		if bind and not ev.is_connected(sig, cb):
			ev.connect(sig, cb)
		elif not bind and ev.is_connected(sig, cb):
			ev.disconnect(sig, cb)


func configure(island_id: int, region_node: Node) -> void:
	active_instance = self
	if _bound_events != Lx.events:
		_sync_events()
	_island_id = clampi(island_id, 1, 8)
	_region = region_node
	_decals.clear()
	_step_cd = 0.0
	_was_airborne = false
	_last_block_id = 0
	_last_block_pos = Vector2.ZERO
	_scrape_sfx_cd = 0.0
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		_last_player_pos = (Lx.player as Node2D).global_position
	queue_redraw()


func add_decal(kind: int, pos: Vector2, radius: float = 10.0, life: float = 5.5) -> void:
	if _decals.size() >= MAX_DECALS:
		_decals.pop_front()
	_decals.append({
		"kind": kind,
		"pos": pos.round(),
		"r": radius,
		"age": 0.0,
		"life": life,
		"rot": fposmod(pos.x * 0.31 + pos.y * 0.17, TAU),
	})
	queue_redraw()


func add_dir_decal(kind: int, pos: Vector2, dir: Vector2, radius: float = 6.0, life: float = 2.4, blue: bool = false) -> void:
	if _decals.size() >= MAX_DECALS:
		_decals.pop_front()
	var dn: Vector2 = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	_decals.append({
		"kind": kind,
		"pos": pos.round(),
		"dir": dn,
		"r": radius,
		"age": 0.0,
		"life": life,
		"blue": blue,
		"rot": dn.angle(),
	})
	queue_redraw()


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if dt <= 0.0:
		return
	var dirty: bool = false
	for i: int in range(_decals.size() - 1, -1, -1):
		var d: Dictionary = _decals[i]
		d["age"] = float(d["age"]) + dt
		if float(d["age"]) >= float(d["life"]):
			_decals.remove_at(i)
		dirty = true
	_tick_player_steps(dt)
	if dirty or not _decals.is_empty():
		queue_redraw()


func _tick_player_steps(dt: float) -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if _scrape_sfx_cd > 0.0:
		_scrape_sfx_cd = maxf(0.0, _scrape_sfx_cd - dt)
	var airborne: bool = w.is_dashing() or w.is_gliding() or w.is_zipping()
	if _was_airborne and not airborne and not w.dead:
		var ldir: Vector2 = w.velocity.normalized() if w.velocity.length_squared() > 16.0 else (w.facing.normalized() if w.facing.length_squared() > 0.0001 else Vector2.RIGHT)
		add_dir_decal(Kind.SKID, w.global_position + Vector2(0.0, 4.0), ldir, 6.0, 2.4, false)
	_was_airborne = airborne
	if w.is_grabbing() and not w.dead:
		var blk: Object = w.grabbed_block
		var bid: int = blk.get_instance_id()
		var bpos: Vector2 = w.get_entity_pos(blk)
		if _last_block_id != bid:
			_last_block_id = bid
			_last_block_pos = bpos
		else:
			var bdelta: Vector2 = bpos - _last_block_pos
			if bdelta.length_squared() >= 49.0:
				var bdir: Vector2 = bdelta.normalized()
				var is_crys: bool = str(blk.get("kind")) == "mirror" or blk.has_method("is_reflective")
				add_dir_decal(Kind.BLOCK_TRACK, bpos + Vector2(0.0, 4.0), bdir, 10.0, 4.2, is_crys)
				w.spawn_sparks(bpos + Vector2(0.0, 4.0), -bdir, 1, PAL["stone"] as Color, 12.0, 26.0, 0.16)
				w.spawn_sparks(bpos + Vector2(0.0, 4.0), -bdir, 1, (PAL["ice"] if is_crys else PAL["stone"]) as Color, 10.0, 24.0, 0.15)
				if _scrape_sfx_cd <= 0.0 and Lx.audio != null:
					_scrape_sfx_cd = 0.26
					Lx.audio.play_sfx("footstep_stone", bpos, true)
				_last_block_pos = bpos
	else:
		_last_block_id = 0
	if w.dead or w.is_gliding() or w.is_zipping():
		_last_player_pos = w.global_position
		return
	_step_cd = maxf(0.0, _step_cd - dt)
	var moved: float = w.global_position.distance_to(_last_player_pos)
	if moved >= 10.0 and _step_cd <= 0.0:
		_step_cd = 0.14 if w.is_dashing() else 0.22
		var dir: Vector2 = (w.global_position - _last_player_pos).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x) * (2.2 if _step_alt else -2.2)
		_step_alt = not _step_alt
		var foot_p: Vector2 = w.global_position + Vector2(0.0, 5.0) + side
		var ttype: String = ""
		if _region != null and _region.has_method("tile_at"):
			ttype = str(_region.call("tile_at", foot_p))
		if ttype in ["tide", "water"]:
			add_decal(Kind.RIPPLE, foot_p, 8.0, 0.85)
		elif w.is_dashing():
			add_decal(Kind.SCORCH, foot_p, 6.5, 2.2)
		else:
			_step_seq += 1
			var saved_isl: bool = Lx.state != null and (Lx.state.relit_islands.has(_island_id) or bool(Lx.state.story_flags.get("disc_all_%d" % _island_id, false)))
			if saved_isl and (_step_seq % 4 == 0):
				add_decal(Kind.BLOSSOM, foot_p, 4.5, 1.8)
			else:
				add_decal(Kind.FOOTSTEP, foot_p, 2.0, 2.6)
		_last_player_pos = w.global_position


func _on_enemy_killed(enemy: Object, kind: String, pos: Vector2, opened_kill: bool) -> void:
	var boss_foe: bool = (enemy is LxEnemyBrain and (enemy as LxEnemyBrain).is_boss) or kind.contains("boss") or kind in ["bellkeeper", "lighthouse_hermit", "briar_matron", "heron_abbess", "astronomer", "kilnmother", "hollow_wick", "the_hush"]
	if boss_foe:
		add_decal(Kind.CRATER, pos, 22.0, 14.0)
		add_decal(Kind.SCORCH, pos, 18.0, 12.0)
	elif opened_kill:
		add_decal(Kind.BLOSSOM, pos, 11.0, 7.5)
		add_decal(Kind.PRISM_STAR, pos, 9.5, 6.5)
	elif _island_id in [2, 4]:
		add_decal(Kind.RIPPLE, pos, 10.0, 4.5)
	elif _island_id == 3:
		add_decal(Kind.BLOSSOM, pos, 9.5, 6.5)
	elif _island_id in [5, 7]:
		add_decal(Kind.PRISM_STAR, pos, 9.0, 7.0)
	else:
		add_decal(Kind.SCORCH, pos, 9.5, 6.5)


func _on_boss_phase_changed(_boss_id: String, _phase: int) -> void:
	if _region != null and _region.has_method("get_enemies"):
		var enemies_v: Variant = _region.call("get_enemies")
		if enemies_v is Array:
			for e_v: Variant in (enemies_v as Array):
				if e_v is LxEnemyBrain and is_instance_valid(e_v) and (e_v as LxEnemyBrain).is_boss:
					add_decal(Kind.CRATER, (e_v as LxEnemyBrain).pos, 20.0, 14.0)
					break


func _on_boss_defeated(_boss_id: String, _isl: int) -> void:
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		var wp: Vector2 = (Lx.player as Node2D).global_position
		add_decal(Kind.PRISM_STAR, wp, 18.0, 12.0)
		add_decal(Kind.BLOSSOM, wp, 16.0, 10.0)


func _on_seal_broken(_isl: int, _seal_id: String) -> void:
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		add_decal(Kind.SCORCH, (Lx.player as Node2D).global_position, 24.0, 9.0)


func _on_beacon_lit(_isl: int, _bid: String) -> void:
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		var p: Vector2 = (Lx.player as Node2D).global_position
		add_decal(Kind.PRISM_STAR, p, 14.0, 7.5)
		add_decal(Kind.BLOSSOM, p, 16.0, 9.0)


func _on_player_healed(_amount: float) -> void:
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		add_decal(Kind.BLOSSOM, (Lx.player as Node2D).global_position + Vector2(0.0, 4.0), 11.0, 4.5)


func _step_color() -> Color:
	match _island_id:
		2:
			return PAL["sky"] as Color
		3:
			return PAL["jade"] as Color
		4:
			return PAL["teal"] as Color
		5:
			return PAL["blue"] as Color
		6:
			return PAL["coral"] as Color
		7:
			return PAL["ice"] as Color
		8:
			return PAL["plum"] as Color
		_:
			return PAL["mauve"] as Color


func _draw() -> void:
	var step_col: Color = _step_color()
	for d: Dictionary in _decals:
		var p: Vector2 = d["pos"] as Vector2
		if absf(p.x - _cam_center.x) > HALF_W or absf(p.y - _cam_center.y) > HALF_H:
			continue
		var u: float = clampf(float(d["age"]) / maxf(float(d["life"]), 0.01), 0.0, 1.0)
		var a: float = clampf(1.0 - u, 0.0, 1.0)
		var r: float = float(d["r"])
		match int(d["kind"]):
			Kind.FOOTSTEP:
				draw_rect(Rect2(p - Vector2.ONE, Vector2(2.0, 2.0)), Color(step_col, a * 0.42))
				if u < 0.42:
					var glint_col: Color = LxBiomePalette.col(_island_id, "hi")
					draw_rect(Rect2(p - Vector2.ONE, Vector2(1.0, 1.0)), Color(glint_col, (1.0 - u / 0.42) * 0.55))
			Kind.RIPPLE:
				var rr: float = roundf(lerpf(2.0, r + 5.0, u))
				_draw_pixel_oval(p, rr, maxf(1.0, roundf(rr * 0.6)), Color(PAL["ice"] as Color, a * 0.72), false)
			Kind.SCORCH:
				var sx: float = maxf(2.0, roundf(r))
				var sy: float = maxf(2.0, roundf(r * 0.62))
				_draw_pixel_oval(p, sx, sy, Color(PAL["void"] as Color, a * 0.36), true)
				_draw_pixel_oval(p, maxf(2.0, roundf(r * 0.85)), maxf(1.0, roundf(r * 0.52)), Color(LxBiomePalette.col(_island_id, "mid"), a * 0.52), false)
				if u < 0.35:
					var fr_s: float = 0.68 if LxHudFx.flash_reduced() else 1.0
					_draw_pixel_oval(p, maxf(1.0, roundf(r * 0.48)), maxf(1.0, roundf(r * 0.30)), Color(LxBiomePalette.col(_island_id, "hi"), (1.0 - u / 0.35) * 0.68 * fr_s), false)
			Kind.SKID:
				var sdir: Vector2 = d.get("dir", Vector2.RIGHT) as Vector2
				var sperp := Vector2(-sdir.y, sdir.x)
				var slen: int = maxi(3, int(roundf(r)))
				for pr: float in [-1.0, 1.0]:
					for k: int in range(slen):
						var t_k: float = float(k) / float(slen)
						var sp_k: Vector2 = (p - sdir * float(k) + sperp * (pr * (2.0 - t_k * 0.6))).round()
						var sc_k: Color = (PAL["stone"] as Color) if (u < 0.32 and k <= 1) else ((PAL["dusk"] as Color) if k % 2 == 0 else step_col)
						draw_rect(Rect2(sp_k, Vector2(1.0, 1.0)), Color(sc_k, a * (0.72 - t_k * 0.28)))
			Kind.BLOCK_TRACK:
				var bdir: Vector2 = d.get("dir", Vector2.RIGHT) as Vector2
				var bperp := Vector2(-bdir.y, bdir.x)
				var is_blue_b: bool = bool(d.get("blue", false))
				var half_n: int = maxi(3, int(roundf(r * 0.5)))
				for tr: float in [-1.0, 1.0]:
					for k: int in range(-half_n, half_n + 1):
						var tp: Vector2 = (p + bdir * float(k) + bperp * (tr * 4.0)).round()
						var tc: Color = (PAL["night"] as Color) if absi(k) < half_n - 1 else (PAL["dusk"] as Color)
						draw_rect(Rect2(tp, Vector2(1.0, 1.0)), Color(tc, a * 0.64))
				var grit_c: Color = (PAL["ice"] if is_blue_b else PAL["stone"]) as Color
				for g: int in range(4):
					var gs: float = -1.0 if (g % 2 == 0) else 1.0
					var goff: float = float(g - 1) * 2.5 - 1.0
					var gp: Vector2 = (p + bdir * goff + bperp * (gs * 5.2)).round()
					draw_rect(Rect2(gp, Vector2(1.0, 1.0)), Color(grit_c, a * 0.58))
			Kind.WALL_SCUFF:
				var wdir: Vector2 = d.get("dir", Vector2.RIGHT) as Vector2
				var is_blue_w: bool = bool(d.get("blue", false))
				var fr_w: float = 0.72 if LxHudFx.flash_reduced() else 1.0
				var c_core: Color = ((PAL["cream"] if u < 0.25 else (PAL["ice"] if u < 0.60 else PAL["deep"])) if is_blue_w else (PAL["cream"] if u < 0.25 else (PAL["gold"] if u < 0.60 else PAL["dusk"]))) as Color
				var c_rim: Color = ((PAL["ice"] if u < 0.25 else (PAL["deep"] if u < 0.60 else PAL["night"])) if is_blue_w else (PAL["gold"] if u < 0.25 else (PAL["dusk"] if u < 0.60 else PAL["night"]))) as Color
				var wc: Vector2 = (p + wdir * 1.0).round()
				draw_rect(Rect2(wc + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(c_rim, a * 0.80 * fr_w))
				draw_rect(Rect2(wc + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(c_rim, a * 0.80 * fr_w))
				draw_rect(Rect2(wc, Vector2(1.0, 1.0)), Color(c_core, a * 0.95 * fr_w))
			Kind.CRATER:
				draw_circle(p, r * 0.78, Color(PAL["void"] as Color, a * 0.46))
				draw_arc(p, r, 0.0, TAU, 18, Color(LxBiomePalette.col(_island_id, "dark"), a * 0.72), 1.4)
				var rot: float = float(d["rot"])
				for k: int in range(6):
					var ang: float = rot + float(k) * (TAU / 6.0)
					var v: Vector2 = Vector2.from_angle(ang)
					draw_line((p + v * (r * 0.35)).round(), (p + v * (r * 1.18)).round(), Color(LxBiomePalette.col(_island_id, "mid"), a * 0.55), 1.0)
			Kind.PRISM_STAR:
				var col_s: Color = LxBiomePalette.col(_island_id, "glow")
				draw_arc(p, r * 0.85, 0.0, TAU, 16, Color(col_s, a * 0.52), 1.0)
				for k: int in range(4):
					var ang: float = float(k) * (PI * 0.25)
					var v: Vector2 = Vector2.from_angle(ang) * r
					draw_line((p - v).round(), (p + v).round(), Color(PAL["cream"] as Color, a * 0.55), 1.0)
			Kind.BLOSSOM:
				var col_b: Color = LxBiomePalette.col(_island_id, "hi")
				var col_c: Color = LxBiomePalette.col(_island_id, "glow")
				var rot_b: float = float(d["rot"])
				for k: int in range(6):
					var ang: float = rot_b + float(k) * (TAU / 6.0)
					var pt: Vector2 = (p + Vector2.from_angle(ang) * (r * (0.45 + 0.55 * minf(1.0, u * 3.0)))).round()
					draw_rect(Rect2(pt - Vector2.ONE, Vector2(2.0, 2.0)), Color(col_b if k % 2 == 0 else col_c, a * 0.62))
				draw_arc(p, roundf(r * 0.55), 0.0, TAU, 12, Color(PAL["cream"] as Color, a * 0.35), 1.0)


func _draw_pixel_oval(center: Vector2, rx: float, ry: float, col: Color, filled: bool = false) -> void:
	var c: Vector2 = center.round()
	if filled:
		var iry: int = maxi(1, int(ceilf(ry)))
		for iy: int in range(-iry, iry + 1):
			var ny: float = float(iy) / maxf(ry, 1.0)
			if ny * ny > 1.0:
				continue
			var hw: float = floorf(rx * sqrt(maxf(0.0, 1.0 - ny * ny)))
			draw_rect(Rect2(c.x - hw, c.y + float(iy), hw * 2.0 + 1.0, 1.0), col)
	else:
		var steps: int = clampi(int(roundf(rx * 2.2)), 8, 24)
		for k: int in range(steps):
			var ang: float = (TAU * float(k)) / float(steps)
			draw_rect(Rect2(roundf(c.x + cos(ang) * rx), roundf(c.y + sin(ang) * ry), 1.0, 1.0), col)
