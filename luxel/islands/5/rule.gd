class_name LxI5Rule
extends RefCounted
## Island 5 (Starfall Observatory: THE ISLAND THAT TURNS) rule engine.
## Coordinates Lx.vars state (ow_dial, well_phase, sky_turn, orrery_ring, dream_best),
## honest extended curved-shot preview near gravity/polarity wells, constellation sync,
## transition audio/cues, and a compact Last Light diegetic astrolabe HUD badge.
## Never disturbs legacy Island 5 checks or regions without Island 5 rule toys.

const ISLAND_ID: int = 5
const DIAL_VARS: Array[String] = ["ow_dial", "sky_turn", "orrery_ring"]
const I5_TOY_KINDS: Array[String] = ["star_node", "star_bell", "meteor_orb", "polarity_well", "gravity_well"]

class RuleRuntime:
	extends LxInteractable
	var owner_rule: LxI5Rule = null
	var _preview_pts: PackedVector2Array = PackedVector2Array()
	var _preview_deg: float = 0.0
	var _preview_hit_wall: bool = false
	var _tangent_lock_well: Vector2 = Vector2.INF
	var _tangent_lock_r: float = 34.0
	var _prev_star_cap_snuffs: int = 0

	func _ready() -> void:
		super._ready()
		id = ""
		kind = "_i5_runtime"
		radius = 0.0
		z_index = 2

	func tick(dt: float) -> void:
		super.tick(dt)
		LxI5StarNode.sync_region_constellations(region, dt, false)
		_update_honest_preview()
		if owner_rule != null:
			owner_rule._sync_hud_badge(dt)
		queue_redraw()

	func _update_honest_preview() -> void:
		_preview_pts = PackedVector2Array()
		_preview_deg = 0.0
		_preview_hit_wall = false
		_tangent_lock_well = Vector2.INF
		if not LxFields.has_fields() or not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
			return
		var w: LxWick = Lx.player as LxWick
		if w.dead or not w.has_lantern() or w.is_grabbing() or w.is_carrying():
			return
		if w.lantern != null and not w.lantern.is_in_hand():
			return
		if w.facing.length_squared() <= 0.0001:
			return
		var aim: Vector2 = w.facing.normalized()
		var bolt_spd: float = float(Lx.get_move_data("bolt").get("speed", 330.0))
		var bolt_rng: float = float(Lx.get_move_data("bolt").get("range", 118.0))
		if w.temper == "lance":
			bolt_spd *= 0.68
			bolt_rng *= 1.35
		elif w.temper == "skip":
			bolt_spd *= 1.08
		elif w.temper == "scatter":
			bolt_rng *= 0.58
		var start_p: Vector2 = w.global_position + aim * 6.0
		var res: Dictionary = LxFields.sample_curve(start_p, aim, bolt_spd, "bolt", bolt_rng, 6.0, region)
		if bool(res.get("bent", false)):
			_preview_pts = res.get("points", PackedVector2Array()) as PackedVector2Array
			_preview_deg = float(res.get("curve_angle_deg", 0.0))
			_preview_hit_wall = bool(res.get("hit_wall", false))

		# Apogee Clasp honest tangent-capture preview (zero aim assist)
		if Lx.state != null and bool(Lx.state.story_flags.get("power_orbit_ring", false)):
			var throw_spd: float = float(Lx.get_move_data("throw").get("throw_speed", 360.0))
			var throw_rng: float = float(Lx.get_move_data("throw").get("throw_range", 108.0))
			var tres: Dictionary = LxFields.sample_curve(w.global_position, aim, throw_spd, "lantern", throw_rng, 6.0, region)
			var tpts: PackedVector2Array = tres.get("points", PackedVector2Array()) as PackedVector2Array
			for i: int in range(1, tpts.size()):
				var p_cur: Vector2 = tpts[i]
				var p_dir: Vector2 = (p_cur - tpts[i - 1]).normalized()
				var well: Object = LxFields.find_orbit_capture_well(p_cur, p_dir)
				if well != null:
					var wp: Variant = well.get("pos")
					var wr: Variant = well.get("orbit_r")
					if wp is Vector2:
						_tangent_lock_well = wp as Vector2
						_tangent_lock_r = float(wr) if (wr is float or wr is int) else 34.0
					break

	func _draw() -> void:
		var fr: bool = LxHudFx.flash_reduced()
		if _preview_pts.size() >= 2:
			var strong_curve: bool = _preview_deg >= 20.0
			var base_a: float = 0.72 if fr else 0.92
			for i: int in range(1, _preview_pts.size()):
				var pt: Vector2 = (_preview_pts[i] + Vector2(0.0, -5.0)).round()
				var frac: float = float(i) / float(_preview_pts.size())
				var is_end: bool = (i == _preview_pts.size() - 1)
				var col: Color = (PAL["gold"] if strong_curve else PAL["sky"]) as Color
				if is_end:
					col = (PAL["coral"] if _preview_hit_wall else (PAL["cream"] if strong_curve else PAL["ice"])) as Color
				elif i % 2 == 0:
					col = (PAL["cream"] if strong_curve else PAL["ice"]) as Color
				var a: float = base_a * (1.0 - frac * 0.42)
				if is_end:
					draw_rect(Rect2(pt - Vector2(2.0, 2.0), Vector2(5.0, 5.0)), Color(PAL["void"] as Color, a * 0.85))
					if _preview_hit_wall:
						draw_line(pt + Vector2(-1.0, -1.0), pt + Vector2(2.0, 2.0), Color(col, a), 1.0)
						draw_line(pt + Vector2(1.0, -1.0), pt + Vector2(-2.0, 2.0), Color(col, a), 1.0)
					else:
						draw_rect(Rect2(pt - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), Color(col, a))
				else:
					draw_rect(Rect2(pt - Vector2(1.0, 1.0), Vector2(4.0, 4.0)), Color(PAL["void"] as Color, a * 0.72))
					draw_rect(Rect2(pt, Vector2(2.0, 2.0)), Color(col, a))

		if _tangent_lock_well.is_finite():
			var c_orb := Color(PAL["gold"] as Color, 0.55 if fr else 0.78)
			draw_arc(_tangent_lock_well.round(), _tangent_lock_r, 0.0, TAU, 24, c_orb, 1.2)


class RuleHudBadge:
	extends Node2D
	var dial_active: bool = false
	var dial_deg: int = 0
	var has_polarity: bool = false
	var polarity_push: bool = false
	var star_lit: int = 0
	var star_cap: int = 0
	var has_apogee: bool = false
	var has_sextant: bool = false
	var flash_t: float = 0.0
	var clock_t: float = 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = 12

	func _draw() -> void:
		if not visible or Lx.state == null:
			return
		var pal: Dictionary = LxPalette.PAL
		var fr: bool = LxHudFx.flash_reduced()
		var y0: float = 21.0 if Lx.state.max_hearts <= 6 else 28.0
		var x0: float = 5.0
		var box_w: float = 22.0
		if has_polarity:
			box_w += 14.0
		if star_cap > 0:
			box_w += 8.0 + float(mini(star_cap, 6)) * 5.0
		if has_apogee:
			box_w += 10.0
		if has_sextant:
			box_w += 10.0
		var box_h: float = 15.0

		var bg_c := Color(pal["void"] as Color, 0.78)
		var rim_c: Color = (pal["cream"] if flash_t > 0.05 else pal["gold"]) as Color
		draw_rect(Rect2(x0, y0, box_w, box_h), bg_c)
		draw_rect(Rect2(x0, y0, box_w, box_h), Color(rim_c, 0.75 if fr else 0.90), false, 1.0)

		var cx: float = x0 + 9.0
		var cy: float = y0 + 7.5
		# 1. Astrolabe quarter compass
		draw_circle(Vector2(cx, cy), 5.0, pal["night"] as Color)
		draw_arc(Vector2(cx, cy), 5.0, 0.0, TAU, 12, pal["apricot"] as Color if dial_active else pal["dusk"] as Color, 1.0)
		for qi: int in range(4):
			var qa: float = deg_to_rad(float(qi * 90) - 90.0)
			var qp: Vector2 = (Vector2(cx, cy) + Vector2.from_angle(qa) * 5.0).round()
			var hit_q: bool = dial_active and (qi * 90 == dial_deg)
			draw_rect(Rect2(qp, Vector2.ONE), pal["cream"] as Color if hit_q else pal["mauve"] as Color)
		var na: float = deg_to_rad(float(dial_deg) - 90.0)
		draw_line(Vector2(cx, cy), (Vector2(cx, cy) + Vector2.from_angle(na) * 4.0).round(), pal["cream"] as Color if dial_active else pal["sky"] as Color, 1.0)
		var cur_x: float = x0 + 18.0

		# 2. Polarity well glyph (PULL inward vs PUSH outward)
		if has_polarity:
			var pc := Vector2(cur_x + 5.0, cy)
			if polarity_push:
				draw_circle(pc, 3.0, pal["gold"] as Color)
				draw_rect(Rect2(pc - Vector2.ONE, Vector2(2.0, 2.0)), pal["cream"] as Color)
				draw_line(pc + Vector2(-5.0, 0.0), pc + Vector2(-3.0, 0.0), pal["coral"] as Color, 1.0)
				draw_line(pc + Vector2(3.0, 0.0), pc + Vector2(5.0, 0.0), pal["coral"] as Color, 1.0)
			else:
				draw_circle(pc, 3.5, pal["deep"] as Color)
				draw_arc(pc, 3.5, 0.0, TAU, 10, pal["sky"] as Color, 1.0)
				draw_rect(Rect2(pc - Vector2.ONE, Vector2(2.0, 2.0)), pal["void"] as Color)
				draw_rect(Rect2(pc, Vector2.ONE), pal["ice"] as Color)
			cur_x += 14.0

		# 3. Capped star_node diamond pips
		if star_cap > 0:
			var n_pips: int = mini(star_cap, 6)
			var at_cap: bool = star_lit >= star_cap
			for i: int in range(n_pips):
				var sx: float = cur_x + 3.0 + float(i) * 5.0
				var sy: float = cy
				var is_on: bool = i < star_lit
				var is_oldest_warn: bool = at_cap and i == 0
				var sc: Color = (pal["coral"] if is_oldest_warn else (pal["gold"] if is_on else pal["dusk"])) as Color
				draw_rect(Rect2(sx - 1.0, sy - 2.0, 2.0, 4.0), sc)
				draw_rect(Rect2(sx - 2.0, sy - 1.0, 4.0, 2.0), sc)
				if is_on and not is_oldest_warn:
					draw_rect(Rect2(sx - 1.0, sy - 1.0, 1.0, 1.0), pal["cream"] as Color)
			cur_x += 6.0 + float(n_pips) * 5.0

		# 4. Unlocked Dungeon Power pips (Apogee Clasp orbit ring / Starlight Sextant triangle)
		if has_apogee:
			var ac := Vector2(cur_x + 4.0, cy)
			draw_arc(ac, 3.5, 0.0, TAU, 10, pal["gold"] as Color, 1.0)
			var op: Vector2 = (ac + Vector2.from_angle(clock_t * (1.2 if fr else 2.6)) * 3.5).round()
			draw_rect(Rect2(op, Vector2.ONE), pal["cream"] as Color)
			cur_x += 10.0
		if has_sextant:
			var tc := Vector2(cur_x + 4.0, cy)
			draw_line(tc + Vector2(0.0, -3.0), tc + Vector2(3.0, 2.0), pal["ice"] as Color, 1.0)
			draw_line(tc + Vector2(3.0, 2.0), tc + Vector2(-3.0, 2.0), pal["ice"] as Color, 1.0)
			draw_line(tc + Vector2(-3.0, 2.0), tc + Vector2(0.0, -3.0), pal["ice"] as Color, 1.0)
			draw_rect(Rect2(tc + Vector2(0.0, -3.0), Vector2.ONE), pal["cream"] as Color)


var _events: LxEventBus = null
var _state: LxGameState = null
var _vars: LxWorldState = null
var _attached: bool = false
var _runtime: RuleRuntime = null
var _hud_badge: RuleHudBadge = null
var _region_id: String = ""
var _last_cap_warn_t: float = 0.0


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	_vars = Lx.vars
	_attached = true
	if _vars != null and not _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.connect(_on_var_changed)


func detach() -> void:
	if _vars != null and _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.disconnect(_on_var_changed)
	_vars = null
	_teardown_hud_badge()
	_runtime = null
	_attached = false


func on_region_loaded(region_id: String) -> void:
	_region_id = region_id
	_runtime = null
	_teardown_hud_badge()
	var reg: LxRegionLoader = Lx.world as LxRegionLoader if (Lx.world is LxRegionLoader and is_instance_valid(Lx.world)) else null
	if reg == null or reg.current_island_id != ISLAND_ID:
		return
	var is_legacy: bool = LxLegacy.is_legacy_region(ISLAND_ID, region_id)
	var has_i5: bool = _region_has_i5_toys(reg)
	if is_legacy and not has_i5:
		return

	# Attach lightweight world-space runtime ticked automatically by LxRegionLoader.tick()
	var rt := RuleRuntime.new()
	rt.owner_rule = self
	rt.region = reg
	rt.island_id = ISLAND_ID
	rt.region_id = region_id
	var parent_n: Node = reg.get("_floor_interactables_root") as Node if reg.get("_floor_interactables_root") is Node else reg
	parent_n.add_child(rt)
	var ilist: Variant = reg.get("_interactables")
	if ilist is Array:
		(ilist as Array).append(rt)
	_runtime = rt

	# Attach compact diegetic astrolabe badge to Lx.ui if UI is present
	if has_i5 and Lx.ui != null and is_instance_valid(Lx.ui):
		var badge := RuleHudBadge.new()
		badge.name = "I5AstrolabeHud"
		Lx.ui.add_child(badge)
		_hud_badge = badge
		_sync_hud_badge(0.0)


func get_runtime() -> Node2D:
	return _runtime


func get_hud_badge() -> Node2D:
	return _hud_badge


func get_active_dial_info(region_id: String = "") -> Dictionary:
	var rid: String = region_id if not region_id.is_empty() else _region_id
	var dng: String = Lx.packs.dungeon_of(ISLAND_ID, rid) if Lx.packs != null else ""
	var scope: String = "island:5"
	var vname: String = "ow_dial"
	if dng == "planetarium" or rid.begins_with("planet_"):
		scope = "dungeon:planetarium"
		vname = "sky_turn"
	elif dng == "orrery" or rid.begins_with("orrery_"):
		scope = "dungeon:orrery"
		vname = "orrery_ring"
	var val_v: Variant = Lx.vars.get_var(scope, vname, 0) if Lx.vars != null else 0
	var deg: int = posmod(int(roundf(float(val_v))), 360) if (val_v is int or val_v is float or str(val_v).is_valid_float()) else 0
	return {"scope": scope, "var_name": vname, "deg": deg}


func get_well_phase() -> String:
	if Lx.vars == null:
		return "pull"
	var v: Variant = Lx.vars.get_var("dungeon:meteor_vault", "well_phase", "pull")
	return "push" if str(v).strip_edges().to_lower() == "push" else "pull"


func set_well_phase(phase: String) -> void:
	if Lx.vars == null:
		return
	var norm: String = "push" if phase.strip_edges().to_lower() == "push" else "pull"
	Lx.vars.set_var("dungeon:meteor_vault", "well_phase", norm)


func has_apogee_clasp() -> bool:
	var st: LxGameState = _state if _state != null else Lx.state
	return st != null and bool(st.story_flags.get("power_orbit_ring", false))


func has_sextant() -> bool:
	var st: LxGameState = _state if _state != null else Lx.state
	return st != null and bool(st.story_flags.get("power_sextant", false))


func _on_var_changed(_scope: String, vname: String, _val: Variant) -> void:
	if Lx.state == null or Lx.state.island_id != ISLAND_ID:
		return
	if _hud_badge != null and is_instance_valid(_hud_badge):
		_hud_badge.flash_t = 0.35
		_sync_hud_badge(0.0)
	if LxLegacy.is_legacy_region(ISLAND_ID, _region_id):
		return
	if _events != null:
		if vname in DIAL_VARS and LxStrings.has_id("I5_CUE_DIAL_TURN"):
			_events.narration_requested.emit("I5_CUE_DIAL_TURN", "narration", 1.8)
		elif vname == "well_phase" and LxStrings.has_id("I5_CUE_WELL_FLIP"):
			_events.narration_requested.emit("I5_CUE_WELL_FLIP", "narration", 1.6)


func _region_has_i5_toys(reg: LxRegionLoader) -> bool:
	for it: LxInteractable in reg.get_interactables():
		if it != null and it.kind in I5_TOY_KINDS:
			return true
	for en: LxEnemyBrain in reg.get_enemies():
		if en != null and en.kind in ["twin_moons", "the_counterweight", "event_horizon", "clockwork_warden", "astronomer", "the_zodiac", "apogee_hound"]:
			return true
	return false


func _teardown_hud_badge() -> void:
	if _hud_badge != null and is_instance_valid(_hud_badge):
		_hud_badge.queue_free()
	_hud_badge = null


func _sync_hud_badge(dt: float) -> void:
	if _hud_badge == null or not is_instance_valid(_hud_badge):
		return
	_hud_badge.clock_t += dt
	_hud_badge.flash_t = maxf(0.0, _hud_badge.flash_t - dt)
	_last_cap_warn_t = maxf(0.0, _last_cap_warn_t - dt)
	var reg: LxRegionLoader = Lx.world as LxRegionLoader if (Lx.world is LxRegionLoader and is_instance_valid(Lx.world)) else null
	if reg == null or reg.current_island_id != ISLAND_ID:
		_hud_badge.visible = false
		return

	var has_bell: bool = false
	var has_pol: bool = false
	var any_push: bool = false
	var max_cap: int = 0
	var cur_lit: int = 0
	var dial_vname: String = ""
	var dial_scope: String = ""

	for it: LxInteractable in reg.get_interactables():
		if it == null or not it.active:
			continue
		if it is LxI5StarBell:
			has_bell = true
			dial_vname = (it as LxI5StarBell).var_name
			dial_scope = (it as LxI5StarBell).var_scope
		elif it is LxI5PolarityWell:
			has_pol = true
			if (it as LxI5PolarityWell).is_push:
				any_push = true
		elif it is LxI5StarNode:
			var sn: LxI5StarNode = it as LxI5StarNode
			if sn.max_lit > 0:
				max_cap = maxi(max_cap, sn.max_lit)
				if sn.lit and not sn.pinned:
					cur_lit += 1

	var dial_deg: int = 0
	if has_bell and Lx.vars != null and not dial_vname.is_empty():
		var dv: Variant = Lx.vars.get_var(dial_scope, dial_vname, 0)
		dial_deg = posmod(int(roundf(float(dv))), 360) if (dv is int or dv is float or str(dv).is_valid_float()) else 0
	else:
		dial_deg = int(get_active_dial_info(_region_id).get("deg", 0))

	if max_cap > 0 and cur_lit >= max_cap and _last_cap_warn_t <= 0.0 and _hud_badge.star_lit < max_cap:
		_last_cap_warn_t = 3.0
		if _events != null and not LxLegacy.is_legacy_region(ISLAND_ID, _region_id) and LxStrings.has_id("I5_CUE_STAR_CAP"):
			_events.narration_requested.emit("I5_CUE_STAR_CAP", "narration", 1.8)

	_hud_badge.visible = true
	_hud_badge.dial_active = has_bell or dial_deg != 0
	_hud_badge.dial_deg = dial_deg
	_hud_badge.has_polarity = has_pol
	_hud_badge.polarity_push = any_push
	_hud_badge.star_lit = cur_lit
	_hud_badge.star_cap = max_cap
	_hud_badge.has_apogee = has_apogee_clasp()
	_hud_badge.has_sextant = has_sextant()
	_hud_badge.queue_redraw()
