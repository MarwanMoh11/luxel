class_name LxGroundDecals
extends Node2D
## Persistent fading world-space ground combat & movement decals (z_index = -2):
## Sunflare scorch rings, boss impact craters, prism frost-stars, water splash ripples,
## and biome-tinted fading footsteps. Uses strictly the 20 Last Light palette colours.

const PAL: Dictionary = LxPalette.PAL
const MAX_DECALS: int = 44
const HALF_W: float = 188.0
const HALF_H: float = 118.0

enum Kind { FOOTSTEP, RIPPLE, SCORCH, CRATER, PRISM_STAR, BLOSSOM }

static var active_instance: LxGroundDecals = null

var _island_id: int = 1
var _region: Node = null
var _cam_center: Vector2 = Vector2.ZERO
var _decals: Array[Dictionary] = []
var _step_cd: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO
var _step_alt: bool = false
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
			add_decal(Kind.FOOTSTEP, foot_p, 2.0, 2.6)
		_last_player_pos = w.global_position


func _on_enemy_killed(enemy: Object, kind: String, pos: Vector2, _opened_kill: bool) -> void:
	var boss_foe: bool = (enemy is LxEnemyBrain and (enemy as LxEnemyBrain).is_boss) or kind.contains("boss") or kind in ["bellkeeper", "lighthouse_hermit", "briar_matron", "heron_abbess", "astronomer", "kilnmother", "hollow_wick", "the_hush"]
	if boss_foe:
		add_decal(Kind.CRATER, pos, 22.0, 14.0)
		add_decal(Kind.SCORCH, pos, 18.0, 12.0)
	elif _island_id in [2, 5, 7]:
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
				draw_arc(p, rr, 0.0, TAU, 14, Color(PAL["ice"] as Color, a * 0.72), 1.0)
			Kind.SCORCH:
				draw_circle(p, r, Color(PAL["void"] as Color, a * 0.36))
				draw_arc(p, r * 0.85, 0.0, TAU, 16, Color(LxBiomePalette.col(_island_id, "mid"), a * 0.48), 1.0)
				if u < 0.35:
					draw_arc(p, r * 0.48, 0.0, TAU, 12, Color(LxBiomePalette.col(_island_id, "hi"), (1.0 - u / 0.35) * 0.68), 1.0)
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
