class_name LxGalListDriver
extends LxToy
## Drowned Galleon Ballast-Roll Controller (`gal_list_driver`):
## Watches `dungeon:galleon` `list` ("port" = -X / "starboard" = +X).
## Whenever `list` shifts (or on optional `initial_surge`), fires a smooth roll surge
## sliding unclamped crates (`targets`), rail-mounted mirrors/blocks (`rail_targets`),
## and compass-table orbs (`orb_targets`) downhill while respecting Ballast Clamp.
## Optionally checks `beam_reset_id` (a `beam_emitter`) to reset unshielded orbs.

const DEFAULT_SPEED: float = 128.0
const DEFAULT_SURGE_SECS: float = 2.4
const CLAMP_RADIUS: float = 24.0

var targets: Array[String] = []
var rail_targets: Array[String] = []
var orb_targets: Array[String] = []
var shield_targets: Array[String] = []
var rail_min_x: float = 40.0
var rail_max_x: float = 360.0
var rail_gap: float = 22.0
var speed: float = DEFAULT_SPEED
var surge_secs: float = DEFAULT_SURGE_SECS
var continuous: bool = false
var beam_reset_id: String = ""
var orb_reset_pos: Vector2 = Vector2.INF
var table_rect: Rect2 = Rect2()

var current_list: String = "port"
var surge_left: float = 0.0
var _rail_ys: Array[float] = []
var _last_dir_x: float = -1.0


func _toy_setup() -> void:
	kind = "gal_list_driver"
	z_index = LxPhysDraw.floor_z(region, -4)
	radius = 12.0
	targets = _parse_str_list(props.get("targets", []))
	rail_targets = _parse_str_list(props.get("rail_targets", []))
	orb_targets = _parse_str_list(props.get("orb_targets", []))
	shield_targets = _parse_str_list(props.get("shield_targets", []))
	rail_min_x = float(props.get("rail_min_x", 40.0))
	rail_max_x = float(props.get("rail_max_x", 360.0))
	rail_gap = maxf(16.0, float(props.get("rail_gap", 22.0)))
	speed = maxf(24.0, float(props.get("speed", DEFAULT_SPEED)))
	surge_secs = maxf(0.4, float(props.get("surge_secs", DEFAULT_SURGE_SECS)))
	continuous = bool(props.get("continuous", false))
	beam_reset_id = str(props.get("beam_reset_id", "")).strip_edges()
	if props.has("orb_reset_pos"):
		orb_reset_pos = _parse_vec2(props.get("orb_reset_pos"), Vector2.INF)
	else:
		orb_reset_pos = Vector2.INF
	table_rect = Rect2()
	var tr: Variant = props.get("table_rect", null)
	if tr is Array and (tr as Array).size() >= 4:
		var a: Array = tr as Array
		table_rect = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	current_list = _read_list_var()
	_last_dir_x = -1.0 if current_list == "port" else 1.0
	surge_left = surge_secs if bool(props.get("initial_surge", false)) else 0.0
	_rail_ys.clear()
	queue_redraw()


func reset_toy() -> void:
	current_list = _read_list_var()
	_last_dir_x = -1.0 if current_list == "port" else 1.0
	surge_left = 0.0
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func _parse_str_list(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for v: Variant in (raw as Array):
			var s: String = str(v).strip_edges()
			if not s.is_empty():
				out.append(s)
	return out


func _read_list_var() -> String:
	if Lx.vars != null:
		var lv: String = str(Lx.vars.get_var("dungeon:galleon", "list", "")).strip_edges().to_lower()
		if lv == "port" or lv == "starboard":
			return lv
		var rv: String = str(Lx.vars.resolve_var("list", island_id, region_id, "port")).strip_edges().to_lower()
		if rv == "port" or rv == "starboard":
			return rv
	return "port"


func _is_clamped(it: LxInteractable) -> bool:
	if it == null or not is_instance_valid(it):
		return false
	if it.get("clamped") is bool and bool(it.get("clamped")):
		return true
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		var lan: LxLantern = w.lantern
		if lan != null and is_instance_valid(lan):
			if lan.state == LxLantern.State.HANGING or lan.state == LxLantern.State.FLYING:
				var clamp_ok: bool = (Lx.state != null and bool(Lx.state.story_flags.get("power_ballast_clamp", false))) or bool(it.props.get("allow_clamp_always", false))
				if clamp_ok and lan.pos.distance_to(it.pos) <= CLAMP_RADIUS:
					return true
	return false


func _is_grabbed(it: LxInteractable) -> bool:
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		return (Lx.player as LxWick).grabbed_block == it
	return false


func _cache_rail_ys() -> void:
	if not _rail_ys.is_empty() or rail_targets.is_empty() or region == null or not region.has_method("find_interactable"):
		return
	for rid: String in rail_targets:
		var it: LxInteractable = region.call("find_interactable", rid) as LxInteractable
		if it != null and is_instance_valid(it):
			var found: bool = false
			for ry: float in _rail_ys:
				if absf(ry - it.pos.y) < 4.0:
					found = true
					break
			if not found:
				_rail_ys.append(it.pos.y)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active or region == null or not is_instance_valid(region):
		return
	_cache_rail_ys()

	var lv: String = _read_list_var()
	if lv != current_list:
		current_list = lv
		_last_dir_x = -1.0 if current_list == "port" else 1.0
		surge_left = surge_secs
		queue_redraw()

	var sliding: bool = continuous or surge_left > 0.0
	if surge_left > 0.0:
		surge_left = maxf(0.0, surge_left - dt)
		queue_redraw()

	if sliding:
		var dir_x: float = -1.0 if current_list == "port" else 1.0
		_step_crate_targets(dir_x)
		_step_rail_targets(dir_x, dt)
		_step_orb_targets(dir_x, dt)

	if not beam_reset_id.is_empty() and not orb_targets.is_empty():
		_check_beam_resets()


func _step_crate_targets(dir_x: float) -> void:
	if targets.is_empty() or not region.has_method("find_interactable"):
		return
	var v := Vector2(dir_x * speed, 0.0)
	for tid: String in targets:
		var it: LxInteractable = region.call("find_interactable", tid) as LxInteractable
		if it == null or not is_instance_valid(it) or not it.active:
			continue
		if _is_clamped(it) or _is_grabbed(it):
			continue
		if it.has_method("push_block_external"):
			it.call("push_block_external", v)


func _step_rail_targets(dir_x: float, dt: float) -> void:
	if rail_targets.is_empty() or not region.has_method("find_interactable"):
		return
	# Sort so leading objects along dir_x advance first and trailing objects stop cleanly behind them
	var items: Array[LxInteractable] = []
	for rid: String in rail_targets:
		var it: LxInteractable = region.call("find_interactable", rid) as LxInteractable
		if it != null and is_instance_valid(it) and it.active:
			items.append(it)
	items.sort_custom(func(a: LxInteractable, b: LxInteractable) -> bool:
		return (a.pos.x > b.pos.x) if dir_x > 0.0 else (a.pos.x < b.pos.x)
	)
	for it: LxInteractable in items:
		if _is_clamped(it) or _is_grabbed(it):
			continue
		var want_x: float = clampf(it.pos.x + dir_x * speed * dt, rail_min_x, rail_max_x)
		for other: LxInteractable in items:
			if other == it or absf(other.pos.y - it.pos.y) > 12.0:
				continue
			if dir_x > 0.0 and other.pos.x > it.pos.x:
				want_x = minf(want_x, other.pos.x - rail_gap)
			elif dir_x < 0.0 and other.pos.x < it.pos.x:
				want_x = maxf(want_x, other.pos.x + rail_gap)
		if absf(want_x - it.pos.x) > 0.02:
			var np := Vector2(want_x, it.pos.y)
			if it.has_method("move_to"):
				it.call("move_to", np)
			else:
				it.pos = np
				it.position = np.round()


func _step_orb_targets(dir_x: float, dt: float) -> void:
	if orb_targets.is_empty() or not region.has_method("find_interactable"):
		return
	for oid: String in orb_targets:
		var it: LxInteractable = region.call("find_interactable", oid) as LxInteractable
		if it == null or not is_instance_valid(it) or not it.active:
			continue
		if it.get("carrier") != null or bool(it.get("airborne")) or _is_clamped(it):
			continue
		if table_rect.has_area() and not table_rect.has_point(it.pos):
			continue
		if it.has_method("push_orb"):
			it.call("push_orb", Vector2(dir_x * speed * 0.78 * dt, 0.0))


func _check_beam_resets() -> void:
	if not region.has_method("find_interactable"):
		return
	var em: LxInteractable = region.call("find_interactable", beam_reset_id) as LxInteractable
	if em == null or not is_instance_valid(em) or not bool(em.get("beam_on")):
		return
	var segs_v: Variant = em.get("segments")
	if not (segs_v is Array):
		return
	var segs: Array = segs_v as Array
	for oid: String in orb_targets:
		var orb: LxInteractable = region.call("find_interactable", oid) as LxInteractable
		if orb == null or not is_instance_valid(orb) or not orb.active:
			continue
		if orb.get("carrier") != null:
			continue
		var hit_beam: bool = false
		for sv: Variant in segs:
			if not (sv is Dictionary):
				continue
			var sd: Dictionary = sv as Dictionary
			var a: Vector2 = sd.get("start", sd.get("a", Vector2.ZERO)) as Vector2
			var b: Vector2 = sd.get("end", sd.get("b", Vector2.ZERO)) as Vector2
			if Geometry2D.get_closest_point_to_segment(orb.pos, a, b).distance_to(orb.pos) <= 9.0:
				if not _is_shielded_along_beam(a, orb.pos):
					hit_beam = true
					break
		if hit_beam:
			var rst: Vector2 = orb_reset_pos if orb_reset_pos.is_finite() else (orb.get("origin_pos") as Vector2)
			orb.pos = rst
			orb.position = rst.round()
			orb.queue_redraw()
			_emit_sfx("phantom_phase")
			if Lx.player is LxWick and is_instance_valid(Lx.player):
				(Lx.player as LxWick).spawn_ring(rst, 3.0, 12.0, 0.22, PAL["rose"] as Color, 1.2)


func _is_shielded_along_beam(beam_start: Vector2, orb_pos: Vector2) -> bool:
	if shield_targets.is_empty() or region == null or not region.has_method("find_interactable"):
		return false
	for sid: String in shield_targets:
		var sh: LxInteractable = region.call("find_interactable", sid) as LxInteractable
		if sh == null or not is_instance_valid(sh) or not sh.active:
			continue
		var cp: Vector2 = Geometry2D.get_closest_point_to_segment(sh.pos, beam_start, orb_pos)
		if cp.distance_to(sh.pos) <= maxf(10.0, sh.radius + 2.0):
			if beam_start.distance_to(sh.pos) < beam_start.distance_to(orb_pos):
				return true
	return false


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color

	# Draw crisp brass deck tracks for any rail_targets
	for ry: float in _rail_ys:
		var ly: float = roundf(ry - pos.y)
		var x0: float = roundf(rail_min_x - pos.x) - 6.0
		var x1: float = roundf(rail_max_x - pos.x) + 6.0
		var w: float = maxf(8.0, x1 - x0)
		draw_rect(Rect2(x0, ly - 5.0, w, 10.0), c_void)
		draw_rect(Rect2(x0 + 1.0, ly - 4.0, w - 2.0, 8.0), c_night)
		draw_rect(Rect2(x0 + 1.0, ly - 3.0, w - 2.0, 1.0), PAL["apricot"] as Color)
		draw_rect(Rect2(x0 + 1.0, ly + 2.0, w - 2.0, 1.0), PAL["apricot"] as Color)
		var tx: float = x0 + 6.0
		while tx < x1 - 4.0:
			draw_rect(Rect2(tx, ly - 2.0, 2.0, 4.0), PAL["dusk"] as Color)
			tx += 12.0

	# Draw recessed brass inclinometer badge at driver pos
	var active_roll: bool = continuous or surge_left > 0.0
	var badge := Rect2(-12.0, -7.0, 24.0, 14.0)
	LxPhysDraw.draw_bevel_box(self, badge, c_night, c_gold if active_roll else c_stone, PAL["dusk"] as Color, c_void)
	var dir_x: float = -1.0 if current_list == "port" else 1.0
	var bob := Vector2(dir_x * 6.0, 2.0)
	draw_line(Vector2(0.0, -4.0), bob, c_cream if active_roll else c_gold, 1.0)
	draw_rect(Rect2(bob - Vector2.ONE, Vector2(2.0, 2.0)), c_ice if current_list == "port" else c_gold)
	LxPhysDraw.draw_chevron(self, Vector2(dir_x * 8.0, 0.0), Vector2(dir_x, 0.0), c_cream if active_roll else c_gold, c_void, 2.0)
