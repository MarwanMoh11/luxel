class_name LxI5StarNode
extends LxToy
## Constellation star socket over void (Island 5).
## Shooting lights a solid walkable star platform; linked lit stars form 12px solid bridges,
## and any lit triangle of 3 stars (or 2 stars + thrown lantern via Starlight Sextant) becomes
## solid walkable ground in void. Supports FIFO cap (`cap_group`/`max_lit`), `pinned`, `lens_only`,
## and `sky_turns` filtering.

enum StarState { UNLIT, LIT, WARN }

class StarSupportCell:
	extends LxInteractable
	var cell_rect: Rect2 = Rect2()

	func _ready() -> void:
		super._ready()
		id = ""
		kind = "_star_support"
		radius = 0.0
		visible = false

	func is_platform_solid() -> bool:
		return active and cell_rect.has_area()

	func get_platform_rect() -> Rect2:
		return cell_rect if is_platform_solid() else Rect2()


class ConstellationCanvas:
	extends Node2D
	var unlit_edges: Array[PackedVector2Array] = []
	var lit_edges: Array[PackedVector2Array] = []
	var sextant_edges: Array[PackedVector2Array] = []
	var lit_triangles: Array[PackedVector2Array] = []
	var lantern_vertex: Vector2 = Vector2.INF
	var anim_t: float = 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		z_index = -5

	func _draw() -> void:
		var pal: Dictionary = LxInteractable.PAL
		var fr: bool = LxHudFx.flash_reduced()
		var shim: float = 0.85 if fr else (0.78 + 0.22 * sin(anim_t * 3.2))

		# 1. Subtle etched chalk link hints between unlit/linked sockets
		for e: PackedVector2Array in unlit_edges:
			_draw_dashed(e[0], e[1], Color(pal["sky"] as Color, 0.26), 4.0, 5.0)

		# 2. Lit constellation triangles (solid walkable star-glass floor in void)
		for tri: PackedVector2Array in lit_triangles:
			draw_colored_polygon(tri, Color(pal["deep"] as Color, 0.72))
			draw_colored_polygon(tri, Color(pal["gold"] as Color, 0.22 * shim))
			for k: int in range(3):
				var a: Vector2 = tri[k]
				var b: Vector2 = tri[(k + 1) % 3]
				draw_line(a, b, Color(pal["gold"] as Color, 0.85), 2.0)
				draw_line(a, b, Color(pal["cream"] as Color, 0.75 * shim), 1.0)
			var cen: Vector2 = ((tri[0] + tri[1] + tri[2]) / 3.0).round()
			draw_line(cen + Vector2(-3.0, 0.0), cen + Vector2(3.0, 0.0), Color(pal["cream"] as Color, 0.68), 1.0)
			draw_line(cen + Vector2(0.0, -3.0), cen + Vector2(0.0, 3.0), Color(pal["cream"] as Color, 0.68), 1.0)
			draw_rect(Rect2(cen - Vector2.ONE, Vector2(2.0, 2.0)), pal["gold"] as Color)

		# 3. Solid 12px star bridges between lit neighbors
		for e: PackedVector2Array in lit_edges:
			_draw_star_bridge(e[0], e[1], pal, false, shim)

		# 4. Starlight Sextant live bridges to thrown lantern
		for e: PackedVector2Array in sextant_edges:
			_draw_star_bridge(e[0], e[1], pal, true, shim)

		if lantern_vertex.is_finite():
			var lp: Vector2 = lantern_vertex.round()
			draw_arc(lp, 9.0, 0.0, TAU, 16, Color(pal["cream"] as Color, 0.85), 1.2)
			draw_line(lp + Vector2(-5.0, 0.0), lp + Vector2(5.0, 0.0), pal["gold"] as Color, 1.0)
			draw_line(lp + Vector2(0.0, -5.0), lp + Vector2(0.0, 5.0), pal["gold"] as Color, 1.0)

	func _draw_star_bridge(a: Vector2, b: Vector2, pal: Dictionary, is_sextant: bool, shim: float) -> void:
		var d: Vector2 = b - a
		var dist: float = d.length()
		if dist < 2.0:
			return
		var dn: Vector2 = d / dist
		var perp := Vector2(-dn.y, dn.x)
		var hw: float = 5.5
		var quad := PackedVector2Array([a + perp * hw, b + perp * hw, b - perp * hw, a - perp * hw])
		draw_colored_polygon(quad, Color(pal["night"] as Color, 0.86))
		var inner_hw: float = 4.0
		var inner := PackedVector2Array([a + perp * inner_hw, b + perp * inner_hw, b - perp * inner_hw, a - perp * inner_hw])
		draw_colored_polygon(inner, Color((pal["sky"] if is_sextant else pal["deep"]) as Color, 0.62))
		var rim_c: Color = (pal["ice"] if is_sextant else pal["gold"]) as Color
		draw_line(a + perp * hw, b + perp * hw, rim_c, 1.0)
		draw_line(a - perp * hw, b - perp * hw, rim_c, 1.0)
		draw_line(a, b, Color(pal["cream"] as Color, 0.72 * shim), 1.0)
		var step: float = 10.0
		var cur: float = 6.0
		while cur < dist - 4.0:
			var sp: Vector2 = (a + dn * cur).round()
			draw_rect(Rect2(sp - Vector2.ONE, Vector2(2.0, 2.0)), pal["cream"] as Color if is_sextant else pal["gold"] as Color)
			cur += step

	func _draw_dashed(a: Vector2, b: Vector2, col: Color, dash: float, gap: float) -> void:
		var d: Vector2 = b - a
		var dist: float = d.length()
		if dist < 2.0:
			return
		var dn: Vector2 = d / dist
		var cur: float = 0.0
		while cur < dist:
			var seg_end: float = minf(cur + dash, dist)
			draw_line((a + dn * cur).round(), (a + dn * seg_end).round(), col, 1.0)
			cur += dash + gap


static var _order_counter: int = 0
static var _region_cache: Dictionary = {} # region_id(int) -> {cells, canvas, sig, tick_frame}

var links: PackedStringArray = PackedStringArray()
var link_range: float = 84.0
var cap_group: String = ""
var max_lit: int = 0
var pinned: bool = false
var lens_only: bool = false
var sky_turns: PackedInt32Array = PackedInt32Array()
var turn_var: String = "sky_turn"

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
	sync_region_constellations(region, 0.0, true)


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
		sync_region_constellations(region, 0.0, true)
		queue_redraw()


func _refresh_turn_visibility() -> void:
	if sky_turns.is_empty():
		_turn_visible = true
		return
	var cur_deg: int = 0
	if Lx.vars != null:
		var v: Variant = Lx.vars.resolve_var(turn_var, island_id, region_id, 0)
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
	if not is_platform_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


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
	sync_region_constellations(region, 0.0, true)
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
	sync_region_constellations(region, 0.0, true)
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
	for nd: LxI5StarNode in _collect_region_stars(region):
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
				sync_region_constellations(region, dt, true)
	if lit or _ignite_fx_t > 0.0 or star_state == StarState.WARN:
		dirty = true
	sync_region_constellations(region, dt, false)
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
		sync_region_constellations(region, 0.0, true)
	queue_redraw()


func _draw() -> void:
	if not is_star_active():
		return
	var fr: bool = LxHudFx.flash_reduced()
	if lens_only and _revealed_t <= 0.0:
		var shimmer: float = 0.28 if fr else (0.18 + 0.16 * sin(_clock * 3.5 + pos.x * 0.05))
		var ci := Color(PAL["ice"] as Color, shimmer)
		draw_rect(Rect2(-1.0, -5.0, 2.0, 1.0), ci)
		draw_rect(Rect2(-1.0, 4.0, 2.0, 1.0), ci)
		draw_rect(Rect2(-5.0, -1.0, 1.0, 2.0), ci)
		draw_rect(Rect2(4.0, -1.0, 1.0, 2.0), ci)
		return

	if not lit:
		# UNLIT: dark recessed octagonal chalk socket with hollow cross
		draw_rect(Rect2(-8.0, -8.0, 16.0, 16.0), Color(PAL["void"] as Color, 0.75))
		draw_rect(Rect2(-7.0, -7.0, 14.0, 14.0), PAL["night"] as Color)
		draw_rect(Rect2(-7.0, -7.0, 14.0, 14.0), PAL["blue"] as Color if lens_only else PAL["dusk"] as Color, false, 1.0)
		var cross_c: Color = (PAL["ice"] if lens_only else PAL["mauve"]) as Color
		draw_line(Vector2(-4.0, 0.0), Vector2(4.0, 0.0), cross_c, 1.0)
		draw_line(Vector2(0.0, -4.0), Vector2(0.0, 4.0), cross_c, 1.0)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["void"] as Color)
		if pinned:
			_draw_pin_rivets(PAL["mauve"] as Color)
		if _snuff_fx_t > 0.0:
			var su: float = 1.0 - clampf(_snuff_fx_t / 0.28, 0.0, 1.0)
			draw_arc(Vector2.ZERO, lerpf(10.0, 3.0, su), 0.0, TAU, 12, Color(PAL["stone"] as Color, 1.0 - su), 1.0)
		return

	# LIT or WARN: solid 16x16 walkable golden star platform (distinct silhouette in greyscale)
	var is_warn: bool = (star_state == StarState.WARN)
	var blink: bool = fr or (int(floorf(_clock * 8.0)) % 2 == 0)
	var rim_c: Color = (PAL["coral"] if (is_warn and blink) else (PAL["ice"] if lens_only else PAL["gold"])) as Color
	var fill_c: Color = (PAL["wine"] if (is_warn and blink) else PAL["deep"]) as Color
	var arm_c: Color = (PAL["apricot"] if is_warn else (PAL["ice"] if lens_only else PAL["gold"])) as Color
	var core_c: Color = (PAL["coral"] if (is_warn and blink) else PAL["cream"]) as Color

	draw_rect(Rect2(-9.0, -9.0, 18.0, 18.0), PAL["void"] as Color)
	draw_rect(Rect2(-8.0, -8.0, 16.0, 16.0), fill_c)
	draw_rect(Rect2(-8.0, -8.0, 16.0, 16.0), rim_c, false, 1.0)
	# Crisp 8-point star mosaic
	draw_line(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), arm_c, 2.0)
	draw_line(Vector2(0.0, -6.0), Vector2(0.0, 6.0), arm_c, 2.0)
	draw_line(Vector2(-4.0, -4.0), Vector2(4.0, 4.0), rim_c, 1.0)
	draw_line(Vector2(-4.0, 4.0), Vector2(4.0, -4.0), rim_c, 1.0)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), core_c)
	if is_warn:
		# Greyscale-distinct hollow center + outer dashed warning ring
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["void"] as Color)
		for wi: int in range(8):
			var wa: float = _clock * 2.0 + float(wi) * (TAU / 8.0)
			draw_arc(Vector2.ZERO, 11.0, wa, wa + 0.35, 3, rim_c, 1.0)
	if pinned:
		_draw_pin_rivets(PAL["cream"] as Color)
	if _ignite_fx_t > 0.0:
		var iu: float = 1.0 - clampf(_ignite_fx_t / 0.34, 0.0, 1.0)
		draw_arc(Vector2.ZERO, lerpf(6.0, 18.0, iu), 0.0, TAU, 16, Color(PAL["cream"] as Color, (1.0 - iu) * 0.9), 1.5)
	_draw_signal_pulses()


func _draw_pin_rivets(col: Color) -> void:
	for cp: Vector2 in [Vector2(-7.0, -7.0), Vector2(6.0, -7.0), Vector2(-7.0, 6.0), Vector2(6.0, 6.0)]:
		draw_rect(Rect2(cp, Vector2(2.0, 2.0)), col)


# ---- Static Region Constellation Bridge & Lit Triangle Manager ----

static func _collect_region_stars(reg: Node) -> Array[LxI5StarNode]:
	var out: Array[LxI5StarNode] = []
	if reg == null or not is_instance_valid(reg) or not reg.has_method("get_interactables"):
		return out
	for it_v: Variant in (reg.call("get_interactables") as Array):
		if it_v is LxI5StarNode and is_instance_valid(it_v as Object):
			out.append(it_v as LxI5StarNode)
	return out


static func _has_sextant_lantern() -> Vector2:
	if Lx.state == null or not bool(Lx.state.story_flags.get("power_sextant", false)):
		return Vector2.INF
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return Vector2.INF
	var w: LxWick = Lx.player as LxWick
	if w.dead or w.lantern == null or not is_instance_valid(w.lantern):
		return Vector2.INF
	if w.lantern.is_lure_active():
		return w.lantern.pos
	return Vector2.INF


static func _stars_can_link(a: LxI5StarNode, b: LxI5StarNode) -> bool:
	if a == b:
		return false
	var has_explicit: bool = (not a.links.is_empty()) or (not b.links.is_empty())
	if a.links.has(b.id) or b.links.has(a.id):
		return true
	if has_explicit:
		return false
	return a.pos.distance_to(b.pos) <= minf(a.link_range, b.link_range)


static func sync_region_constellations(reg: Node, dt: float = 0.0, force: bool = false) -> void:
	if reg == null or not is_instance_valid(reg):
		return
	var rid: int = reg.get_instance_id()
	var frame_id: int = Engine.get_physics_frames()
	var entry: Dictionary = _region_cache.get(rid, {}) as Dictionary
	if entry.is_empty() or not is_instance_valid(entry.get("canvas", null)):
		entry = _init_region_cache(reg, rid)
	var canvas: ConstellationCanvas = entry["canvas"] as ConstellationCanvas
	canvas.anim_t += dt
	if not force and int(entry.get("frame", -1)) == frame_id and dt > 0.0:
		return
	entry["frame"] = frame_id

	var stars: Array[LxI5StarNode] = _collect_region_stars(reg)
	var lan_v: Vector2 = _has_sextant_lantern()

	# Fast signature check so we only recompute void support cells when vertices/lit states change
	var sig_parts := PackedStringArray()
	for s: LxI5StarNode in stars:
		sig_parts.append("%s:%d:%d:%d" % [s.id, 1 if s.is_lit_and_active() else 0, int(roundf(s.pos.x)), int(roundf(s.pos.y))])
	if lan_v.is_finite():
		sig_parts.append("L:%d:%d" % [int(roundf(lan_v.x * 0.5)), int(roundf(lan_v.y * 0.5))])
	var sig: String = "|".join(sig_parts)
	if not force and str(entry.get("sig", "")) == sig:
		if not canvas.lit_edges.is_empty() or not canvas.lit_triangles.is_empty() or not canvas.sextant_edges.is_empty():
			canvas.queue_redraw()
		return
	entry["sig"] = sig

	# Build vertex graph (lit stars + optional Sextant lantern vertex)
	var lit_stars: Array[LxI5StarNode] = []
	var unlit_edges: Array[PackedVector2Array] = []
	for i: int in range(stars.size()):
		var sa: LxI5StarNode = stars[i]
		if sa.is_lit_and_active():
			lit_stars.append(sa)
		for j: int in range(i + 1, stars.size()):
			var sb: LxI5StarNode = stars[j]
			if sa.is_star_active() and sb.is_star_active() and sa.is_revealed() and sb.is_revealed():
				if _stars_can_link(sa, sb) and not (sa.is_lit_and_active() and sb.is_lit_and_active()):
					unlit_edges.append(PackedVector2Array([sa.pos, sb.pos]))

	var n_lit: int = lit_stars.size()
	var adj: Dictionary = {} # "i:j" -> true
	var lit_edges: Array[PackedVector2Array] = []
	for i: int in range(n_lit):
		for j: int in range(i + 1, n_lit):
			if _stars_can_link(lit_stars[i], lit_stars[j]):
				adj["%d:%d" % [i, j]] = true
				lit_edges.append(PackedVector2Array([lit_stars[i].pos, lit_stars[j].pos]))

	var sextant_edges: Array[PackedVector2Array] = []
	var lan_linked: Array[int] = []
	if lan_v.is_finite():
		for i: int in range(n_lit):
			var sr: float = maxf(84.0, lit_stars[i].link_range)
			if lit_stars[i].pos.distance_to(lan_v) <= sr:
				lan_linked.append(i)
				sextant_edges.append(PackedVector2Array([lit_stars[i].pos, lan_v]))

	var lit_tris: Array[PackedVector2Array] = []
	for i: int in range(n_lit):
		for j: int in range(i + 1, n_lit):
			if not adj.has("%d:%d" % [i, j]):
				continue
			for k: int in range(j + 1, n_lit):
				if adj.has("%d:%d" % [i, k]) and adj.has("%d:%d" % [j, k]):
					lit_tris.append(PackedVector2Array([lit_stars[i].pos, lit_stars[j].pos, lit_stars[k].pos]))

	# Sextant lantern also completes lit triangles with any 2 linked lit stars it connects to
	for ai: int in range(lan_linked.size()):
		for bi: int in range(ai + 1, lan_linked.size()):
			var i0: int = lan_linked[ai]
			var i1: int = lan_linked[bi]
			var p0: Vector2 = lit_stars[i0].pos
			var p1: Vector2 = lit_stars[i1].pos
			var area2: float = absf((p1.x - p0.x) * (lan_v.y - p0.y) - (p1.y - p0.y) * (lan_v.x - p0.x))
			if area2 > 128.0 and (adj.has("%d:%d" % [i0, i1]) or p0.distance_to(p1) <= 168.0):
				lit_tris.append(PackedVector2Array([p0, p1, lan_v]))

	canvas.unlit_edges = unlit_edges
	canvas.lit_edges = lit_edges
	canvas.sextant_edges = sextant_edges
	canvas.lit_triangles = lit_tris
	canvas.lantern_vertex = lan_v if not sextant_edges.is_empty() else Vector2.INF
	canvas.queue_redraw()

	_update_support_cells(reg, entry, lit_edges, sextant_edges, lit_tris, lan_v if not sextant_edges.is_empty() else Vector2.INF)


static func _init_region_cache(reg: Node, rid: int) -> Dictionary:
	var canvas := ConstellationCanvas.new()
	canvas.name = "I5ConstellationCanvas"
	var parent_n: Node = reg.get("_floor_interactables_root") as Node if reg.get("_floor_interactables_root") is Node else reg
	parent_n.add_child(canvas)
	var d: Dictionary = {"canvas": canvas, "cells": [], "sig": "", "frame": -1}
	_region_cache[rid] = d
	return d


static func _update_support_cells(
	reg: Node,
	entry: Dictionary,
	lit_edges: Array[PackedVector2Array],
	sextant_edges: Array[PackedVector2Array],
	lit_tris: Array[PackedVector2Array],
	lan_v: Vector2
) -> void:
	var w: int = int(reg.get("width")) if reg.get("width") != null else 0
	var h: int = int(reg.get("height")) if reg.get("height") != null else 0
	var ts_v: Variant = reg.get("tile_size")
	var ts: float = float(ts_v) if (ts_v is int or ts_v is float) and float(ts_v) > 0.0 else 16.0
	var rects: Array[Rect2] = []

	if w > 0 and h > 0 and (not lit_edges.is_empty() or not sextant_edges.is_empty() or not lit_tris.is_empty()):
		var all_edges: Array[PackedVector2Array] = []
		all_edges.append_array(lit_edges)
		all_edges.append_array(sextant_edges)
		var min_x: float = INF; var min_y: float = INF; var max_x: float = -INF; var max_y: float = -INF
		for e: PackedVector2Array in all_edges:
			for p: Vector2 in e:
				min_x = minf(min_x, p.x); min_y = minf(min_y, p.y)
				max_x = maxf(max_x, p.x); max_y = maxf(max_y, p.y)
		for tri: PackedVector2Array in lit_tris:
			for p: Vector2 in tri:
				min_x = minf(min_x, p.x); min_y = minf(min_y, p.y)
				max_x = maxf(max_x, p.x); max_y = maxf(max_y, p.y)
		var tx0: int = maxi(0, int(floorf((min_x - 16.0) / ts)))
		var tx1: int = mini(w - 1, int(floorf((max_x + 16.0) / ts)))
		var ty0: int = maxi(0, int(floorf((min_y - 16.0) / ts)))
		var ty1: int = mini(h - 1, int(floorf((max_y + 16.0) / ts)))
		for ty: int in range(ty0, ty1 + 1):
			for tx: int in range(tx0, tx1 + 1):
				var tc := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
				var covered: bool = false
				for e: PackedVector2Array in all_edges:
					if Geometry2D.get_closest_point_to_segment(tc, e[0], e[1]).distance_to(tc) <= 10.5:
						covered = true
						break
				if not covered:
					for tri: PackedVector2Array in lit_tris:
						if Geometry2D.is_point_in_polygon(tc, tri):
							covered = true
							break
				if not covered and lan_v.is_finite() and tc.distance_to(lan_v) <= 12.0:
					covered = true
				if covered:
					rects.append(Rect2(float(tx) * ts, float(ty) * ts, ts, ts))

	var cells: Array = entry["cells"] as Array
	var parent_n: Node = reg.get("_floor_interactables_root") as Node if reg.get("_floor_interactables_root") is Node else reg
	var inter_list_v: Variant = reg.get("_interactables")
	if not (inter_list_v is Array):
		inter_list_v = reg.get("interactables")
	var inter_list: Array = inter_list_v as Array if inter_list_v is Array else []

	while cells.size() < rects.size():
		var c := StarSupportCell.new()
		c.region = reg
		parent_n.add_child(c)
		if inter_list_v is Array:
			inter_list.append(c)
		cells.append(c)

	for i: int in range(cells.size()):
		var c: StarSupportCell = cells[i] as StarSupportCell
		if c == null or not is_instance_valid(c):
			continue
		if i < rects.size():
			c.active = true
			c.cell_rect = rects[i]
		else:
			c.active = false
			c.cell_rect = Rect2()
