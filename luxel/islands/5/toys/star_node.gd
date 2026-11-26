class_name LxI5StarNode
extends LxToy
## Constellation star socket over void (Island 5).
## Shooting lights a solid walkable star platform; linked lit stars form 12px solid bridges,
## and any lit triangle of 3 stars (or 2 stars + thrown lantern via Starlight Sextant) becomes
## solid walkable ground in void via LxI5Constellation. Supports FIFO cap, pinned, lens_only, sky_turns.

enum StarState { UNLIT, LIT, WARN }

static var _order_counter: int = 0

var links: PackedStringArray = PackedStringArray()
var link_range: float = 84.0
var cap_group: String = ""
var max_lit: int = 0
var pinned: bool = false
var lens_only: bool = false
var sky_turns: PackedInt32Array = PackedInt32Array()
var turn_var: String = "sky_turn"
var turn_scope: String = ""

var lit: bool = false
var star_state: int = StarState.UNLIT
var lit_order: int = 0

var _init_lit: bool = false
var _revealed_t: float = 0.0
var _ignite_fx_t: float = 0.0
var _snuff_fx_t: float = 0.0
var _turn_visible: bool = true
var _vars_bound: LxWorldState = null


func _toy_setup() -> void:
	kind = "star_node"
	size = Vector2(24.0, 24.0)
	radius = 10.0
	link_range = maxf(24.0, float(props.get("link_range", 84.0)))
	links = PackedStringArray()
	var raw_links: Variant = props.get("links", [])
	if raw_links is Array:
		for lv: Variant in (raw_links as Array):
			var ls: String = str(lv).strip_edges()
			if not ls.is_empty():
				links.append(ls)
	cap_group = str(props.get("cap_group", "")).strip_edges()
	max_lit = maxi(0, int(props.get("max_lit", 0)))
	if max_lit > 0 and cap_group.is_empty():
		cap_group = "default"
	pinned = bool(props.get("pinned", false))
	lens_only = bool(props.get("lens_only", false))
	turn_var = str(props.get("turn_var", "sky_turn")).strip_edges()
	turn_scope = str(props.get("turn_scope", "")).strip_edges()
	if turn_scope.is_empty() and Lx.packs != null:
		var sv: Dictionary = Lx.packs.state_vars()
		if sv.has(turn_var) and sv[turn_var] is Dictionary:
			turn_scope = str((sv[turn_var] as Dictionary).get("scope", "")).strip_edges()
	sky_turns = PackedInt32Array()
	var raw_turns: Variant = props.get("sky_turns", [])
	if raw_turns is Array and not (raw_turns as Array).is_empty():
		for tv: Variant in (raw_turns as Array):
			sky_turns.append(posmod(int(tv), 360))
	_init_lit = bool(props.get("lit", props.get("on", false)))
	lit = _init_lit
	powered = lit
	if lit:
		_order_counter += 1
		lit_order = _order_counter
	_revealed_t = 0.0 if lens_only else 1.0
	_ignite_fx_t = 0.0
	_snuff_fx_t = 0.0
	_bind_vars()
	_refresh_turn_visibility()
	_refresh_star_state()
	z_index = LxPhysDraw.floor_z(region, -3)
	queue_redraw()
	LxI5Constellation.sync(region, 0.0, true)


func _exit_tree() -> void:
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = null


func _bind_vars() -> void:
	if Lx.vars == null or _vars_bound == Lx.vars:
		return
	_vars_bound = Lx.vars
	if not _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.connect(_on_var_changed)


func _on_var_changed(_scope: String, vname: String, _val: Variant) -> void:
	if sky_turns.is_empty():
		return
	if vname == turn_var or vname in ["sky_turn", "ow_dial", "orrery_ring"]:
		_refresh_turn_visibility()
		LxI5Constellation.sync(region, 0.0, true)
		queue_redraw()


func _refresh_turn_visibility() -> void:
	if sky_turns.is_empty():
		_turn_visible = true
		return
	var cur_deg: int = 0
	if Lx.vars != null:
		var v: Variant = Lx.vars.get_var(turn_scope, turn_var, 0) if not turn_scope.is_empty() else Lx.vars.resolve_var(turn_var, island_id, region_id, 0)
		cur_deg = posmod(int(roundf(float(v))), 360) if (v is int or v is float or str(v).is_valid_float()) else 0
	_turn_visible = sky_turns.has(cur_deg)
	if not _turn_visible and lit and not pinned:
		snuff(false)


func is_revealed() -> bool:
	return (not lens_only) or _revealed_t > 0.0


func is_star_active() -> bool:
	return active and _turn_visible


func is_lit_and_active() -> bool:
	return is_star_active() and lit and is_revealed()


func is_platform_solid() -> bool:
	return is_lit_and_active()


func get_platform_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_platform_solid() else Rect2()


func on_light(light_radius: float, source: String) -> void:
	if not is_star_active() or light_radius <= 0.0:
		return
	if lens_only:
		var allow: bool = source == "lens" or source == "lens_anchor" or (
			source == "lantern_hung" and Lx.state != null and Lx.state.has_move("lens")
		)
		if allow:
			if _revealed_t <= 0.0:
				_emit_sfx("phantom_phase")
			_revealed_t = 0.28
			queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not is_star_active():
		return false
	if lens_only and _revealed_t <= 0.0:
		return false
	if hit.source not in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		return false
	if lit:
		return false
	ignite()
	return true


func interact(_actor: Node = null) -> bool:
	if not is_star_active():
		return false
	if lens_only and _revealed_t <= 0.0:
		return false
	if not lit:
		ignite()
		return true
	return false


func ignite() -> void:
	if not is_star_active():
		return
	var was_lit: bool = lit
	lit = true
	_order_counter += 1
	lit_order = _order_counter
	_ignite_fx_t = 0.34
	set_powered(true)
	if not was_lit:
		emit_power(true)
		_emit_sfx("star_ignite")
		_emit_gust(42.0, 28.0)
	_enforce_cap_group()
	_refresh_star_state()
	LxI5Constellation.sync(region, 0.0, true)
	queue_redraw()


func snuff(play_sfx: bool = true) -> void:
	if not lit:
		return
	lit = false
	star_state = StarState.UNLIT
	_snuff_fx_t = 0.28
	set_powered(false)
	emit_power(false)
	if play_sfx:
		_emit_sfx("star_snuff")
	_refresh_group_warnings()
	LxI5Constellation.sync(region, 0.0, true)
	queue_redraw()


func reset_toy() -> void:
	if persist and lit:
		return
	if _init_lit:
		ignite()
	else:
		snuff(false)


func _enforce_cap_group() -> void:
	if max_lit <= 0 or cap_group.is_empty() or region == null:
		return
	var group_lit: Array[LxI5StarNode] = _get_group_unpinned_lit()
	group_lit.sort_custom(func(a: LxI5StarNode, b: LxI5StarNode) -> bool: return a.lit_order < b.lit_order)
	while group_lit.size() > max_lit:
		var oldest: LxI5StarNode = group_lit.pop_front() as LxI5StarNode
		if oldest != null and oldest != self:
			oldest.snuff(true)
	_refresh_group_warnings()


func _refresh_group_warnings() -> void:
	if max_lit <= 0 or cap_group.is_empty() or region == null:
		return
	var group_lit: Array[LxI5StarNode] = _get_group_unpinned_lit()
	group_lit.sort_custom(func(a: LxI5StarNode, b: LxI5StarNode) -> bool: return a.lit_order < b.lit_order)
	var at_cap: bool = group_lit.size() >= max_lit
	for i: int in range(group_lit.size()):
		var nd: LxI5StarNode = group_lit[i]
		var want_st: int = StarState.WARN if (at_cap and i == 0) else StarState.LIT
		if nd.star_state != want_st:
			nd.star_state = want_st
			nd.queue_redraw()


func _get_group_unpinned_lit() -> Array[LxI5StarNode]:
	var out: Array[LxI5StarNode] = []
	for nd: LxI5StarNode in LxI5Constellation.collect_stars(region):
		if nd.lit and not nd.pinned and nd.cap_group == cap_group and nd.max_lit > 0:
			out.append(nd)
	return out


func _refresh_star_state() -> void:
	if not lit:
		star_state = StarState.UNLIT
	elif max_lit > 0 and not cap_group.is_empty() and not pinned:
		_refresh_group_warnings()
	else:
		star_state = StarState.LIT


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _ignite_fx_t > 0.0:
		_ignite_fx_t = maxf(0.0, _ignite_fx_t - dt)
		dirty = true
	if _snuff_fx_t > 0.0:
		_snuff_fx_t = maxf(0.0, _snuff_fx_t - dt)
		dirty = true
	if lens_only and _revealed_t > 0.0:
		_revealed_t = maxf(0.0, _revealed_t - dt)
		if _revealed_t <= 0.0:
			dirty = true
			if lit and not pinned:
				snuff(true)
			else:
				LxI5Constellation.sync(region, dt, true)
	if lit or _ignite_fx_t > 0.0 or star_state == StarState.WARN:
		dirty = true
	LxI5Constellation.tick_sync(region, self, dt)
	if dirty:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not is_lit_and_active():
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 44.0 + _ignite_fx_t * 36.0, 0.72)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist or pinned:
		d["lit"] = lit
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if (persist or pinned) and d.has("lit"):
		lit = bool(d["lit"])
		powered = lit
		if lit:
			_order_counter += 1
			lit_order = _order_counter
		_refresh_star_state()
		LxI5Constellation.sync(region, 0.0, true)
	queue_redraw()


func _draw() -> void:
	if not is_star_active():
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var c_blue: Color = PAL["blue"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var fr: bool = LxHudFx.flash_reduced()

	if lens_only and _revealed_t <= 0.0:
		var shimmer: float = 0.30 if fr else (0.20 + 0.16 * sin(_clock * 3.5 + pos.x * 0.05))
		var ci := Color(c_ice, shimmer)
		draw_rect(Rect2(-2.0, -6.0, 4.0, 1.0), ci)
		draw_rect(Rect2(-2.0, 5.0, 4.0, 1.0), ci)
		draw_rect(Rect2(-6.0, -2.0, 1.0, 4.0), ci)
		draw_rect(Rect2(5.0, -2.0, 1.0, 4.0), ci)
		return

	if not lit:
		# Crisp carved octagonal celestial floor socket (unmistakable even on dark void!)
		var oct_out := _oct_poly(10.0, 4.0)
		var oct_rim := _oct_poly(9.0, 4.0)
		var oct_in := _oct_poly(7.0, 3.0)
		draw_colored_polygon(oct_out, c_void)
		draw_colored_polygon(oct_rim, c_deep)
		draw_colored_polygon(oct_in, c_night)

		# Sunlit celestial inlaid bevel along upper/left octagon edges + deep lower shadow
		var rim_hi: Color = c_ice if lens_only else c_sky
		var rim_mid: Color = c_sky if lens_only else c_blue
		draw_rect(Rect2(-4.0, -9.0, 8.0, 1.0), rim_hi)
		draw_rect(Rect2(-9.0, -4.0, 1.0, 8.0), rim_hi)
		draw_rect(Rect2(-4.0, 8.0, 8.0, 1.0), rim_mid)
		draw_rect(Rect2(8.0, -4.0, 1.0, 8.0), rim_mid)
		# Crisp diagonal chamfer inlays so the octagon silhouette pops
		for ch: Vector2 in [
			Vector2(-7.0, -7.0), Vector2(-6.0, -8.0), Vector2(-8.0, -6.0),
			Vector2(6.0, -7.0), Vector2(5.0, -8.0), Vector2(7.0, -6.0),
			Vector2(-7.0, 6.0), Vector2(-6.0, 7.0), Vector2(-8.0, 5.0),
			Vector2(6.0, 6.0), Vector2(5.0, 7.0), Vector2(7.0, 5.0),
		]:
			draw_rect(Rect2(ch, Vector2(1.0, 1.0)), rim_hi if (ch.y < 0.0 and ch.x < 0.0) else rim_mid)
		# Sunken inner octagon border
		draw_polyline(_oct_poly(7.0, 3.0, true), c_dusk, 1.0)

		# Dim carved 4-point star etching recessed inside the socket well
		draw_line(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), rim_mid, 1.0)
		draw_line(Vector2(0.0, -5.0), Vector2(0.0, 5.0), rim_mid, 1.0)
		draw_line(Vector2(-3.0, -3.0), Vector2(3.0, 3.0), c_deep, 1.0)
		draw_line(Vector2(-3.0, 3.0), Vector2(3.0, -3.0), c_deep, 1.0)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), c_void)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), rim_hi)
		# Tiny cardinal socket alignment ticks
		for tk: Vector2 in [Vector2(-6.0, 0.0), Vector2(5.0, 0.0), Vector2(0.0, -6.0), Vector2(0.0, 5.0)]:
			draw_rect(Rect2(tk, Vector2(1.0, 1.0)), rim_hi)

		if pinned:
			_draw_pin_rivets(c_stone)
		if _snuff_fx_t > 0.0:
			var su: float = 1.0 - clampf(_snuff_fx_t / 0.28, 0.0, 1.0)
			draw_arc(Vector2.ZERO, roundf(lerpf(10.0, 3.0, su)), 0.0, TAU, 12, Color(c_stone, 1.0 - su), 1.0)
		return

	# LIT (or WARN) radiant octagonal starlight platform
	var is_warn: bool = (star_state == StarState.WARN)
	var blink: bool = fr or (int(floorf(_clock * 8.0)) % 2 == 0)
	var rim_c: Color = c_coral if (is_warn and blink) else (c_ice if lens_only else c_gold)
	var fill_c: Color = c_wine if (is_warn and blink) else c_deep
	var arm_c: Color = c_apr if is_warn else (c_ice if lens_only else c_gold)
	var diag_c: Color = c_coral if is_warn else (c_sky if lens_only else c_apr)
	var core_c: Color = c_coral if (is_warn and blink) else c_cream

	draw_colored_polygon(_oct_poly(11.0, 4.0), c_void)
	draw_colored_polygon(_oct_poly(10.0, 4.0), rim_c)
	draw_colored_polygon(_oct_poly(8.0, 3.0), fill_c)
	draw_colored_polygon(_oct_poly(6.0, 2.0), c_night)

	# Radiant 8-point starlight burst
	draw_line(Vector2(-5.0, -5.0), Vector2(5.0, 5.0), diag_c, 1.0)
	draw_line(Vector2(-5.0, 5.0), Vector2(5.0, -5.0), diag_c, 1.0)
	draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), arm_c, 2.0)
	draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), arm_c, 2.0)
	draw_line(Vector2(-7.0, 0.0), Vector2(7.0, 0.0), core_c, 1.0)
	draw_line(Vector2(0.0, -7.0), Vector2(0.0, 7.0), core_c, 1.0)
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), arm_c)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), core_c)
	# Cardinal starlight tip glints
	for tip: Vector2 in [Vector2(-9.0, 0.0), Vector2(8.0, 0.0), Vector2(0.0, -9.0), Vector2(0.0, 8.0)]:
		draw_rect(Rect2(tip, Vector2(1.0, 1.0)), c_cream)

	if is_warn:
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), c_void)
		var w_off: float = 0.0 if fr else _clock * 2.0
		for wi: int in range(8):
			var wa: float = w_off + float(wi) * (TAU / 8.0)
			draw_arc(Vector2.ZERO, 12.0, wa, wa + 0.35, 3, rim_c, 1.2)
	if pinned:
		_draw_pin_rivets(c_cream)
	if _ignite_fx_t > 0.0:
		var iu: float = 1.0 - clampf(_ignite_fx_t / 0.34, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 18.0, iu)), 0.0, TAU, 16, Color(c_cream, (1.0 - iu) * 0.9), 1.5)
	_draw_signal_pulses()


static func _oct_poly(r: float, c: float, close: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array([
		Vector2(-c, -r), Vector2(c, -r),
		Vector2(r, -c), Vector2(r, c),
		Vector2(c, r), Vector2(-c, r),
		Vector2(-r, c), Vector2(-r, -c),
	])
	if close:
		pts.append(pts[0])
	return pts


func _draw_pin_rivets(col: Color) -> void:
	for cp: Vector2 in [Vector2(-7.0, -7.0), Vector2(5.0, -7.0), Vector2(-7.0, 5.0), Vector2(5.0, 5.0)]:
		draw_rect(Rect2(cp - Vector2.ONE, Vector2(3.0, 3.0)), PAL["void"] as Color)
		draw_rect(Rect2(cp, Vector2(1.0, 1.0)), col)


static func sync_region_constellations(reg: Node, dt: float = 0.0, force: bool = false) -> void:
	LxI5Constellation.sync(reg, dt, force)
