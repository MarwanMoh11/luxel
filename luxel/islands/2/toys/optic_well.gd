class_name LxOpticWell
extends LxToy
## Island 2 Lighthouse 24x24 vertical optical relay shaft.
## Props: var_name ("relay_f1"|"relay_f2"|"relay_f3"), scope ("dungeon:lighthouse"),
## role ("receiver"|"emitter"), emit_dir ([x,y] or "n|e|s|w"; [0,0] redirects via mirror placed on well),
## requires_blue (bool), range (float), max_bounces (int), persist (bool), target_id/target_ids.

const RAY_STEP: float = 4.0
const MAX_SEGMENTS: int = 10

var var_name: String = "relay_f1"
var var_scope: String = "dungeon:lighthouse"
var role: String = "receiver" # "receiver" | "emitter"
var emit_dir: Vector2 = Vector2.ZERO
var requires_blue: bool = true
var max_range: float = 280.0
var max_bounces: int = 4

var state: String = "dormant" # "dormant" | "lit"
var lit: bool = false
var segments: Array[Dictionary] = []
var _ignite_t: float = 0.0
var _reject_t: float = 0.0
var _hit_sensors: Array[Dictionary] = []
var _hit_plants: Array[Dictionary] = []
var _cache_sig: String = ""


func _toy_setup() -> void:
	kind = "optic_well"
	size = _parse_size(props.get("size", [24.0, 24.0]), Vector2(24.0, 24.0))
	radius = maxf(12.0, maxf(size.x, size.y) * 0.5)
	var_name = str(props.get("var_name", "relay_f1")).strip_edges()
	if var_name.is_empty():
		var_name = "relay_f1"
	var_scope = str(props.get("scope", "dungeon:lighthouse")).strip_edges()
	if var_scope.is_empty():
		var_scope = "dungeon:lighthouse"
	role = str(props.get("role", "receiver")).strip_edges().to_lower()
	if role != "emitter":
		role = "receiver"
	emit_dir = Vector2.ZERO
	if props.has("emit_dir"):
		var raw_ed: Variant = props.get("emit_dir")
		if raw_ed is String:
			emit_dir = dir_vec("emit_dir", Vector2.ZERO)
		else:
			var v: Vector2 = _parse_vec2(raw_ed, Vector2.ZERO)
			if v.length_squared() > 0.001:
				emit_dir = v.normalized()
	requires_blue = bool(props.get("requires_blue", true))
	max_range = maxf(48.0, float(props.get("range", 280.0)))
	max_bounces = clampi(int(props.get("max_bounces", 4)), 0, 8)
	if not props.has("persist"):
		persist = true
	z_index = LxPhysDraw.floor_z(region, -4)
	segments.clear()
	_hit_sensors.clear()
	_hit_plants.clear()
	_cache_sig = ""
	_ignite_t = 0.0
	_reject_t = 0.0
	lit = powered or _read_relay_lit()
	state = "lit" if lit else "dormant"
	powered = lit
	if lit and role == "emitter":
		_retrace_beam(true)
	queue_redraw()


func reset_toy() -> void:
	if persist and lit:
		return
	lit = false
	state = "dormant"
	segments.clear()
	_hit_sensors.clear()
	_hit_plants.clear()
	_cache_sig = ""
	set_powered(false)
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or role != "receiver":
		return false
	if lit:
		return false
	var is_blue_hit: bool = (hit.has_method("is_blue") and hit.is_blue()) or hit.source == LxHit.SOURCE_PRISM
	if requires_blue and not is_blue_hit:
		if hit.source in ["bolt", "beam", "throw", "recall"]:
			_reject_t = 0.38
			_emit_sfx("mirror_ping")
			queue_redraw()
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		_ignite_well()
		return true
	return false


func receive_beam(beam_col: String, _from_id: String = "") -> void:
	if not active or role != "receiver" or lit:
		return
	var norm: String = LxToyDraw.normalize_light_color(beam_col)
	if requires_blue and norm != "blue":
		_reject_t = 0.25
		return
	_ignite_well()


func _on_power_changed(is_on: bool) -> void:
	if is_on and not lit:
		_ignite_well()


func _ignite_well() -> void:
	lit = true
	state = "lit"
	_ignite_t = 0.55
	LxToyDraw.world_set_var(var_scope, var_name, 1)
	if Lx.state != null:
		Lx.state.story_flags[var_name] = true
	set_powered(true)
	emit_power(true)
	_emit_sfx("prism_chain")
	_emit_sfx("waystone_lit")
	_emit_gust(60.0, 44.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.10 * (0.45 if LxHudFx.flash_reduced() else 1.0))
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, 84.0, 0.85 if LxHudFx.flash_reduced() else 1.35, 0.36)
	if region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	if role == "emitter":
		_retrace_beam(true)
	queue_redraw()


func _read_relay_lit() -> bool:
	var v: Variant = LxToyDraw.world_get_var(var_scope, var_name, 0)
	if v is bool:
		return bool(v)
	if v is int or v is float:
		return float(v) >= 1.0
	var s: String = str(v).strip_edges().to_lower()
	if s == "1" or s == "true" or s == "lit" or s == "on":
		return true
	if Lx.state != null and bool(Lx.state.story_flags.get(var_name, false)):
		return true
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		segments.clear()
		return
	var dirty: bool = false
	if _ignite_t > 0.0:
		_ignite_t = maxf(0.0, _ignite_t - dt)
		dirty = true
	if _reject_t > 0.0:
		_reject_t = maxf(0.0, _reject_t - dt)
		dirty = true

	var var_lit: bool = _read_relay_lit()
	if var_lit and not lit:
		lit = true
		state = "lit"
		_ignite_t = 0.45
		set_powered(true)
		emit_power(true)
		dirty = true
	elif not var_lit and lit and role == "emitter" and not powered:
		lit = false
		state = "dormant"
		segments.clear()
		_cache_sig = ""
		dirty = true

	if lit and role == "emitter":
		_retrace_beam(false)
		_deliver_beam_effects()
		dirty = true
	elif not lit and not segments.is_empty():
		segments.clear()
		_cache_sig = ""
		dirty = true

	if dirty:
		queue_redraw()


func _resolve_emit_direction() -> Vector2:
	if emit_dir.length_squared() > 0.001:
		return emit_dir
	# Vertical shaft well (e.g. lighthouse_r9 W3): if a mirror sits on top of the well, bend along its normal!
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in region.call("get_interactables") as Array:
			if it_v == self or not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if is_instance_valid(it) and it.active and it.is_reflective() and it.pos.distance_to(pos) <= 14.0:
				var nv: Variant = it.get("normal")
				if nv is Vector2 and (nv as Vector2).length_squared() > 0.001:
					return (nv as Vector2).normalized()
	return Vector2.ZERO


func _retrace_beam(force: bool) -> void:
	var dir_now: Vector2 = _resolve_emit_direction()
	if dir_now.length_squared() <= 0.001:
		if not segments.is_empty():
			segments.clear()
			_hit_sensors.clear()
			_hit_plants.clear()
			_cache_sig = ""
		return
	var sig: String = _build_signature(dir_now)
	if not force and sig == _cache_sig:
		return
	_cache_sig = sig
	segments.clear()
	_hit_sensors.clear()
	_hit_plants.clear()
	var inters: Array = region.call("get_interactables") as Array if (region != null and region.has_method("get_interactables")) else []
	var ignore_top: int = get_instance_id()
	if emit_dir.length_squared() <= 0.001:
		for it_v: Variant in inters:
			if it_v is LxInteractable and it_v != self and (it_v as LxInteractable).is_reflective() and (it_v as LxInteractable).pos.distance_to(pos) <= 14.0:
				ignore_top = (it_v as LxInteractable).get_instance_id()
				break
	var queue: Array[Dictionary] = [{
		"start": pos + dir_now * 10.0,
		"dir": dir_now,
		"color": "blue",
		"bounces": max_bounces,
		"ignore_id": ignore_top,
	}]
	while not queue.is_empty() and segments.size() < MAX_SEGMENTS:
		_trace_ray(queue.pop_front() as Dictionary, inters, queue)


func _build_signature(dir_now: Vector2) -> String:
	var parts := PackedStringArray(["%.2f,%.2f" % [dir_now.x, dir_now.y]])
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in region.call("get_interactables") as Array:
			if it_v is LxInteractable and it_v != self and is_instance_valid(it_v as Object):
				var it: LxInteractable = it_v as LxInteractable
				var ns: String = ""
				if it.is_reflective() and it.get("normal") is Vector2:
					var nv: Vector2 = it.get("normal") as Vector2
					ns = "%.2f,%.2f" % [nv.x, nv.y]
				if it.is_solid() or it.is_reflective() or it.kind in ["beam_sensor", "light_sensor", "light_plant", "color_glass", "optic_well"]:
					parts.append("%d:%d:%.0f,%.0f:%s" % [it.get_instance_id(), 1 if it.active else 0, it.pos.x, it.pos.y, ns])
	return "|".join(parts)


func _trace_ray(ray: Dictionary, inters: Array, queue: Array[Dictionary]) -> void:
	var origin: Vector2 = ray["start"] as Vector2
	var dir: Vector2 = (ray["dir"] as Vector2).normalized()
	var col_name: String = str(ray["color"])
	var bounces_left: int = int(ray["bounces"])
	var ignore_id: int = int(ray["ignore_id"])
	var cur: Vector2 = origin
	var dist: float = 0.0
	var end_pt: Vector2 = origin
	var passed_glass: Dictionary = {}
	while dist < max_range:
		var step: float = minf(RAY_STEP, max_range - dist)
		var nxt: Vector2 = cur + dir * step
		dist += step
		if region != null and region.has_method("tile_at") and LxMapFormat.blocks_sight_tile(str(region.call("tile_at", nxt))):
			end_pt = cur
			break
		var stopped: bool = false
		for it_v: Variant in inters:
			if not (it_v is LxInteractable) or it_v == self:
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it) or not it.active or it.get_instance_id() == ignore_id:
				continue
			var hit_it: bool = (it.is_solid() and it.get_solid_rect().grow(1.0).has_point(nxt)) or (Geometry2D.get_closest_point_to_segment(it.pos, cur, nxt).distance_to(it.pos) <= maxf(7.0, it.radius * 0.85))
			if not hit_it:
				continue
			if it.has_method("get_tint_color") and not passed_glass.has(it.get_instance_id()):
				passed_glass[it.get_instance_id()] = true
				var nc: String = LxToyDraw.normalize_light_color(str(it.call("get_tint_color")))
				if nc != col_name:
					end_pt = it.pos
					queue.append({"start": it.pos + dir * (maxf(it.radius, 8.0) + 1.0), "dir": dir, "color": nc, "bounces": bounces_left, "ignore_id": it.get_instance_id()})
					stopped = true
					break
				continue
			if it.has_method("receive_beam"):
				_hit_sensors.append({"sensor": it, "color": col_name})
				if not bool(it.props.get("pass_through", false)):
					end_pt = it.pos
					stopped = true
					break
				continue
			if it.kind == "light_plant" or it.kind == "light_sensor":
				_hit_plants.append({"item": it})
				continue
			if it.is_reflective():
				end_pt = it.pos
				if bounces_left > 0:
					var rdir: Vector2 = it.reflect_dir(dir)
					if rdir.length_squared() > 0.001:
						queue.append({"start": it.pos + rdir * (maxf(it.radius, 8.0) + 2.0), "dir": rdir, "color": "blue", "bounces": bounces_left - 1, "ignore_id": it.get_instance_id()})
				stopped = true
				break
			if it.is_solid() and it.blocks_sight():
				end_pt = cur
				stopped = true
				break
		if stopped:
			break
		cur = nxt
		end_pt = nxt
	segments.append({"start": origin, "end": end_pt, "color": col_name})


func _deliver_beam_effects() -> void:
	for entry: Dictionary in _hit_sensors:
		var s: Object = entry["sensor"] as Object
		if s != null and is_instance_valid(s) and s.has_method("receive_beam"):
			s.call("receive_beam", str(entry["color"]), id)
	for pe: Dictionary in _hit_plants:
		var it: Object = pe["item"] as Object
		if it != null and is_instance_valid(it) and it.has_method("on_light"):
			it.call("on_light", 64.0, "beam")


func beam_illuminates_point(world_p: Vector2) -> bool:
	if not active or not lit:
		return false
	for seg: Dictionary in segments:
		if Geometry2D.get_closest_point_to_segment(world_p, seg["start"] as Vector2, seg["end"] as Vector2).distance_to(world_p) <= 14.0:
			return true
	return false


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if lit:
		return Vector4(pos.x, pos.y, 64.0 if _ignite_t > 0.0 else 48.0, 1.05 if _ignite_t > 0.0 else 0.82)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["lit"] = lit
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("lit"):
		lit = bool(d["lit"])
		state = "lit" if lit else "dormant"
		powered = lit
		if lit:
			LxToyDraw.world_set_var(var_scope, var_name, 1)
	queue_redraw()


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color
	var hw: float = floorf(size.x * 0.5)
	var hh: float = floorf(size.y * 0.5)

	# Outer octagonal brass bezel
	LxPhysDraw.draw_bevel_box(self, Rect2(-hw, -hh, size.x, size.y), PAL["night"] as Color, PAL["gold"] as Color if lit else PAL["stone"] as Color, PAL["dusk"] as Color, c_void, PAL["cream"] as Color if lit else PAL["mauve"] as Color)
	# Concentric Fresnel lens shaft rings (dormant deep indigo vs blazing ice/cream core)
	var lens_outer: Color = (PAL["coral"] if _reject_t > 0.0 else (PAL["sky"] if lit else PAL["deep"])) as Color
	var lens_mid: Color = (PAL["apricot"] if _reject_t > 0.0 else (PAL["ice"] if lit else PAL["night"])) as Color
	var lens_core: Color = (PAL["cream"] if lit else PAL["dusk"]) as Color
	draw_circle(Vector2.ZERO, 8.0, c_void)
	draw_circle(Vector2.ZERO, 7.0, lens_outer)
	draw_circle(Vector2.ZERO, 4.0, lens_mid)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), lens_core)
	if lit:
		# Crisp 4-point energized starburst reticle (greyscale-distinct lit vs dormant hollow square)
		draw_rect(Rect2(0.0, -4.0, 1.0, 9.0), PAL["cream"] as Color)
		draw_rect(Rect2(-4.0, 0.0, 9.0, 1.0), PAL["cream"] as Color)
	elif _reject_t > 0.0:
		draw_line(Vector2(-3.0, -3.0), Vector2(3.0, 3.0), PAL["cream"] as Color, 1.0)
		draw_line(Vector2(3.0, -3.0), Vector2(-3.0, 3.0), PAL["cream"] as Color, 1.0)
	# Role glyph: inward receiver arrows vs outward emitter chevrons (greyscale distinct!)
	var g_col: Color = PAL["cream"] as Color if lit else PAL["stone"] as Color
	if role == "receiver":
		for dir_v: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			LxPhysDraw.draw_chevron(self, (dir_v * 9.0).round(), -dir_v, g_col, c_void, 2.0)
	else:
		var ed: Vector2 = _resolve_emit_direction()
		if ed.length_squared() > 0.001:
			LxPhysDraw.draw_chevron(self, (ed * 10.0).round(), ed, g_col, c_void, 3.0)
		else:
			for dir_v: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				LxPhysDraw.draw_chevron(self, (dir_v * 9.0).round(), dir_v, g_col, c_void, 2.0)

	# Live emitted blue optical beam
	if lit and role == "emitter":
		var outer_w: float = 2.0 if red else 3.0
		var glow_a: float = 0.45 if red else 0.65
		for seg: Dictionary in segments:
			var a: Vector2 = ((seg["start"] as Vector2) - pos).round()
			var b: Vector2 = ((seg["end"] as Vector2) - pos).round()
			var st: Array[Color] = LxToyDraw.color_triplet(str(seg["color"]))
			draw_line(a, b, Color(st[0], glow_a), outer_w + 1.0, false)
			draw_line(a, b, st[1], outer_w - 1.0, false)
			draw_line(a, b, PAL["cream"] as Color, 1.0, false)
			draw_rect(Rect2(b - Vector2.ONE, Vector2(3.0, 3.0)), st[2])
	if _ignite_t > 0.0:
		var u: float = 1.0 - clampf(_ignite_t / 0.55, 0.0, 1.0)
		var ic: Color = PAL["cream"] as Color if u < 0.4 else PAL["ice"] as Color
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 22.0, u)), 0.0, TAU, 16, Color(ic, (1.0 - u) * (0.55 if red else 0.90)), 1.0 if red else 2.0)
	_draw_signal_pulses()
