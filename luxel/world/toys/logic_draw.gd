class_name LxToyDraw
extends RefCounted
## Shared pixel-art drawing, light-sampling, field-sampling, and world-var helpers for E0-3 toys.
## Uses strictly the 20 opaque Last Light palette colours (LxPalette.PAL / LxBiomePalette).

const PAL: Dictionary = LxPalette.PAL


static func col(key: String, fallback: String = "gold") -> Color:
	return LxPalette.color(key, fallback)


static func skin_triplet(island_id: int, skin: String = "") -> Array[Color]:
	var s: String = skin.strip_edges().to_lower()
	match s:
		"gold", "dawn", "yellow":
			return [col("wine"), col("apricot"), col("gold")]
		"blue", "dusk", "ice":
			return [col("deep"), col("blue"), col("sky")]
		"rose", "war", "coral":
			return [col("wine"), col("coral"), col("rose")]
		"leaf", "forest", "lime":
			return [col("pine"), col("jade"), col("lime")]
		"shadow", "moon", "void":
			return [col("night"), col("dusk"), col("plum")]
		_:
			return [
				LxBiomePalette.col(island_id, "dark"),
				LxBiomePalette.col(island_id, "mid"),
				LxBiomePalette.col(island_id, "hi"),
			]


static func color_triplet(name: String) -> Array[Color]:
	match name.strip_edges().to_lower():
		"blue", "dusk":
			return [col("blue"), col("sky"), col("ice")]
		"rose":
			return [col("wine"), col("rose"), col("cream")]
		"war", "coral":
			return [col("wine"), col("coral"), col("apricot")]
		"lime", "jade", "green":
			return [col("teal"), col("jade"), col("lime")]
		_:
			return [col("apricot"), col("gold"), col("cream")]


static func normalize_light_color(raw: String) -> String:
	var c: String = raw.strip_edges().to_lower()
	if c == "yellow" or c == "gold" or c == "dawn":
		return "gold"
	if c == "blue" or c == "ice" or c == "sky" or c == "dusk":
		return "blue"
	if c == "rose" or c == "pink" or c == "coral" or c == "war":
		return "rose"
	return "gold"


static func to_hit_color(raw: String) -> String:
	var c: String = normalize_light_color(raw)
	if c == "blue":
		return LxHit.COLOR_BLUE
	if c == "rose":
		return "rose"
	return LxHit.COLOR_YELLOW


static func draw_contact_shadow(ci: CanvasItem, center: Vector2, rx: float, ry: float) -> void:
	var c: Vector2 = center.round()
	var w: float = maxf(2.0, roundf(rx * 2.0))
	var h: float = maxf(1.0, roundf(ry * 2.0))
	var sh := Color(col("void"), 0.36)
	ci.draw_rect(Rect2(c.x - floorf(w * 0.5) + 1.0, c.y - floorf(h * 0.5), maxf(1.0, w - 2.0), h), sh)
	if h >= 3.0:
		ci.draw_rect(Rect2(c.x - floorf(w * 0.5), c.y - floorf(h * 0.5) + 1.0, w, maxf(1.0, h - 2.0)), sh)


static func draw_bevel_box(
	ci: CanvasItem,
	rect: Rect2,
	c_dark: Color,
	c_mid: Color,
	c_hi: Color,
	outline: Color = Color("0d0b1e")
) -> void:
	var x0: float = floorf(rect.position.x)
	var y0: float = floorf(rect.position.y)
	var w: float = maxf(4.0, roundf(rect.size.x))
	var h: float = maxf(4.0, roundf(rect.size.y))
	ci.draw_rect(Rect2(x0, y0, w, h), outline)
	ci.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), c_dark)
	if w >= 6.0 and h >= 6.0:
		ci.draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0), c_mid)
	ci.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, 1.0), c_hi)
	ci.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, 1.0, h - 2.0), c_hi)


## Colour-blind safe geometric glyph (shape 0=circle, 1=diamond, 2=triangle, 3=square, 4=plus, 5=star).
static func draw_shape_glyph(ci: CanvasItem, center: Vector2, shape_idx: int, filled: bool, c_main: Color, c_hi: Color) -> void:
	var c: Vector2 = center.round()
	var cv: Color = col("void")
	var k: int = posmod(shape_idx, 6)
	match k:
		0: # Circle / ring
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 3.0, 5.0, 7.0), cv)
			ci.draw_rect(Rect2(c.x - 3.0, c.y - 2.0, 7.0, 5.0), cv)
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 2.0, 3.0, 5.0), c_main)
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 1.0, 5.0, 3.0), c_main)
			if filled:
				ci.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 3.0, 3.0), c_hi)
			else:
				ci.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 3.0, 3.0), col("night"))
		1: # Diamond
			ci.draw_rect(Rect2(c.x, c.y - 3.0, 1.0, 7.0), cv)
			ci.draw_rect(Rect2(c.x - 3.0, c.y, 7.0, 1.0), cv)
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 2.0, 5.0, 5.0), cv)
			ci.draw_rect(Rect2(c.x, c.y - 2.0, 1.0, 5.0), c_main)
			ci.draw_rect(Rect2(c.x - 2.0, c.y, 5.0, 1.0), c_main)
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 3.0, 3.0), c_hi if filled else col("night"))
			if filled:
				ci.draw_rect(Rect2(c, Vector2.ONE), col("cream"))
		2: # Upward triangle
			ci.draw_rect(Rect2(c.x - 3.0, c.y + 1.0, 7.0, 2.0), cv)
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 1.0, 5.0, 2.0), cv)
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 3.0, 3.0, 2.0), cv)
			ci.draw_rect(Rect2(c.x - 2.0, c.y + 1.0, 5.0, 1.0), c_main)
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 3.0, 2.0), c_hi if filled else c_main)
			ci.draw_rect(Rect2(c.x, c.y - 2.0, 1.0, 2.0), c_hi)
			if not filled:
				ci.draw_rect(Rect2(c.x, c.y, 1.0, 1.0), col("night"))
		3: # Square
			ci.draw_rect(Rect2(c.x - 3.0, c.y - 3.0, 7.0, 7.0), cv)
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 2.0, 5.0, 5.0), c_main)
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 3.0, 3.0), c_hi if filled else col("night"))
		4: # Cross / plus
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 3.0, 3.0, 7.0), cv)
			ci.draw_rect(Rect2(c.x - 3.0, c.y - 1.0, 7.0, 3.0), cv)
			ci.draw_rect(Rect2(c.x, c.y - 2.0, 1.0, 5.0), c_hi if filled else c_main)
			ci.draw_rect(Rect2(c.x - 2.0, c.y, 5.0, 1.0), c_hi if filled else c_main)
			if filled:
				ci.draw_rect(Rect2(c, Vector2.ONE), col("cream"))
		_: # 4-point star
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 3.0, 3.0, 7.0), cv)
			ci.draw_rect(Rect2(c.x - 3.0, c.y - 1.0, 7.0, 3.0), cv)
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 2.0, 5.0, 5.0), cv)
			ci.draw_rect(Rect2(c.x, c.y - 2.0, 1.0, 5.0), c_main)
			ci.draw_rect(Rect2(c.x - 2.0, c.y, 5.0, 1.0), c_main)
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 3.0, 3.0), c_hi if filled else col("night"))
			if filled:
				ci.draw_rect(Rect2(c, Vector2.ONE), col("cream"))


static func draw_tone_crest(ci: CanvasItem, center: Vector2, tone: String, lit: bool) -> void:
	var c: Vector2 = center.round()
	var t: String = tone.strip_edges().to_lower()
	match t:
		"dusk": # Crescent moon (sky/ice)
			var cm: Color = col("ice") if lit else col("sky")
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 2.0, 4.0, 5.0), col("void"))
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 1.0, 3.0, 3.0), cm)
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 2.0, 2.0, 1.0), cm)
			ci.draw_rect(Rect2(c.x - 1.0, c.y + 2.0, 2.0, 1.0), cm)
			ci.draw_rect(Rect2(c.x, c.y - 1.0, 2.0, 3.0), col("night"))
			if lit:
				ci.draw_rect(Rect2(c.x - 2.0, c.y - 1.0, 1.0, 3.0), col("cream"))
		"war": # War horn / jagged chevron (coral/apricot)
			var cm: Color = col("apricot") if lit else col("coral")
			ci.draw_rect(Rect2(c.x - 3.0, c.y - 2.0, 7.0, 5.0), col("void"))
			ci.draw_rect(Rect2(c.x - 2.0, c.y + 1.0, 5.0, 1.0), cm)
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 1.0, 1.0, 2.0), cm)
			ci.draw_rect(Rect2(c.x + 2.0, c.y - 1.0, 1.0, 2.0), cm)
			ci.draw_rect(Rect2(c.x, c.y - 2.0, 1.0, 4.0), col("cream") if lit else cm)
		_: # Dawn sunburst (gold/cream)
			var cm: Color = col("gold") if lit else col("apricot")
			ci.draw_rect(Rect2(c.x - 2.0, c.y - 2.0, 5.0, 5.0), col("void"))
			ci.draw_rect(Rect2(c.x, c.y - 2.0, 1.0, 5.0), cm)
			ci.draw_rect(Rect2(c.x - 2.0, c.y, 5.0, 1.0), cm)
			ci.draw_rect(Rect2(c.x - 1.0, c.y - 1.0, 3.0, 3.0), col("cream") if lit else cm)


static func draw_bar(ci: CanvasItem, top_left: Vector2, w: float, frac: float, c_fill: Color, c_warn: Color = Color("e2725b")) -> void:
	var p: Vector2 = top_left.round()
	var bw: float = maxf(4.0, roundf(w))
	var f: float = clampf(frac, 0.0, 1.0)
	ci.draw_rect(Rect2(p.x - 1.0, p.y - 1.0, bw + 2.0, 4.0), col("void"))
	ci.draw_rect(Rect2(p.x, p.y, bw, 2.0), col("night"))
	var fw: float = roundf(bw * f)
	if fw >= 1.0:
		ci.draw_rect(Rect2(p.x, p.y, fw, 2.0), c_fill if f > 0.28 else c_warn)
		ci.draw_rect(Rect2(p.x, p.y, fw, 1.0), col("cream") if f > 0.28 else c_fill)


## Helper checking line-of-sight between a light emitter and a receiver, ignoring both nodes.
static func _clear_light_view(region: Node, a: Vector2, b: Vector2, ignore_a: Object, ignore_b: Object) -> bool:
	if region == null or not is_instance_valid(region):
		return true
	var dist: float = a.distance_to(b)
	if dist <= 1.0:
		return true
	if region is LxRegionLoader:
		var rl: LxRegionLoader = region as LxRegionLoader
		var steps: int = maxi(1, int(ceil(dist / 4.0)))
		var items: Array[LxInteractable] = rl.get_interactables()
		for i: int in range(1, steps):
			var pt: Vector2 = a.lerp(b, float(i) / float(steps))
			if LxMapFormat.blocks_sight_tile(rl.tile_at(pt)):
				return false
			for it: LxInteractable in items:
				if it == null or it == ignore_a or it == ignore_b:
					continue
				if it.blocks_sight() and it.get_solid_rect().has_point(pt):
					return false
		return true
	if region.has_method("clear_view"):
		return bool(region.call("clear_view", a, b))
	return true


## Samples total light intensity at world_pos from region light pools, Wick's lantern, and active beams.
## Respects clear_view occlusion (walls and sight-blocking solids block light per CONTRACTS.md).
static func sample_light_at(region: Node, world_pos: Vector2, ignore: Object = null) -> float:
	var best: float = 0.0
	if region != null and is_instance_valid(region) and region.has_method("get_interactables"):
		var items_v: Variant = region.call("get_interactables")
		if items_v is Array:
			for it_v: Variant in (items_v as Array):
				if not is_instance_valid(it_v) or not (it_v is LxInteractable) or it_v == ignore:
					continue
				var it: LxInteractable = it_v as LxInteractable
				if not it.active:
					continue
				var pool: Vector4 = it.get_light_pool()
				if pool.z > 1.0 and pool.w > 0.01:
					var pool_pos := Vector2(pool.x, pool.y)
					var d: float = world_pos.distance_to(pool_pos)
					if d < pool.z and _clear_light_view(region, pool_pos, world_pos, ignore, it):
						var fall: float = (1.0 - d / pool.z) * pool.w
						best = maxf(best, fall)
				if it.has_method("beam_illuminates_point") and bool(it.call("beam_illuminates_point", world_pos)):
					best = maxf(best, 1.0)
	if Lx.player != null and is_instance_valid(Lx.player):
		var lan_v: Variant = Lx.player.get("lantern")
		if is_instance_valid(lan_v) and lan_v is Object:
			var lan: Object = lan_v as Object
			var lpos: Vector2 = lan.get("pos") as Vector2 if lan.get("pos") is Vector2 else (
				(Lx.player as Node2D).global_position if Lx.player is Node2D else Vector2(-9999.0, -9999.0)
			)
			var lrad: float = float(lan.call("get_light_radius")) if lan.has_method("get_light_radius") else 84.0
			var has_l: bool = (not Lx.player.has_method("has_lantern")) or bool(Lx.player.call("has_lantern"))
			if has_l and lrad > 1.0:
				var dl: float = world_pos.distance_to(lpos)
				if dl < lrad and _clear_light_view(region, lpos, world_pos, ignore, null):
					best = maxf(best, (1.0 - dl / lrad) * 1.05)
	if Lx.companion != null and is_instance_valid(Lx.companion) and Lx.companion.has_method("get_light_pool"):
		var is_pip_out: bool = Lx.companion.has_method("is_out") and bool(Lx.companion.call("is_out"))
		if is_pip_out:
			var plp: Vector4 = Lx.companion.call("get_light_pool") as Vector4
			if plp.z > 1.0 and plp.w > 0.01:
				var ppos := Vector2(plp.x, plp.y)
				var dp: float = world_pos.distance_to(ppos)
				if dp < plp.z and _clear_light_view(region, ppos, world_pos, ignore, null):
					best = maxf(best, (1.0 - dp / plp.z) * plp.w)
	return best


## Guarded call to E0-2's LxFields.accel_at (returns Vector2.ZERO if fields.gd hasn't landed yet).
static var _fields_checked: bool = false
static var _fields_script: GDScript = null

static func sample_fields_accel(world_pos: Vector2, what: String) -> Vector2:
	if not _fields_checked:
		_fields_checked = true
		if ResourceLoader.exists("res://luxel/world/fields.gd"):
			var res: Resource = ResourceLoader.load("res://luxel/world/fields.gd")
			if res is GDScript:
				_fields_script = res as GDScript
	if _fields_script != null and _fields_script.has_method("accel_at"):
		var v: Variant = _fields_script.call("accel_at", world_pos, what)
		if v is Vector2:
			return v as Vector2
	return Vector2.ZERO


## Guarded Lx.vars (LxWorldState) variable access (works both before and after E0-1 lands).
static func _get_vars_service() -> Object:
	var lx_scr: Object = Lx as Object
	if lx_scr == null:
		return null
	var v: Variant = lx_scr.get("vars")
	if is_instance_valid(v) and v is Object:
		var obj: Object = v as Object
		if obj.has_method("get_var") and obj.has_method("set_var"):
			return obj
	return null


static func world_get_var(scope: String, var_name: String, default_val: Variant = "") -> Variant:
	var vs: Object = _get_vars_service()
	if vs != null:
		return vs.call("get_var", scope, var_name, default_val)
	if Lx.state != null:
		var k: String = "wvar:%s:%s" % [scope, var_name]
		if Lx.state.story_flags.has(k):
			return Lx.state.story_flags[k]
	return default_val


static func world_set_var(scope: String, var_name: String, value: Variant) -> void:
	var vs: Object = _get_vars_service()
	if vs != null:
		vs.call("set_var", scope, var_name, value)
		return
	if Lx.state != null:
		var k: String = "wvar:%s:%s" % [scope, var_name]
		Lx.state.story_flags[k] = value


static func assist_tell_scale() -> float:
	if Lx.save != null and Lx.save.settings.has("assist_tell_scale"):
		return clampf(float(Lx.save.settings["assist_tell_scale"]), 1.0, 1.5)
	return 1.0


## Resets linked targets (or all non-persistent LxToy nodes in region when no targets are set).
static func trigger_room_reset(source: LxInteractable) -> int:
	if source == null or source.region == null or not source.region.has_method("get_interactables"):
		return 0
	var count: int = 0
	var targets: Array[String] = []
	var s1: String = str(source.props.get("target_id", "")).strip_edges()
	if not s1.is_empty():
		targets.append(s1)
	var multi: Variant = source.props.get("target_ids", [])
	if multi is Array:
		for item: Variant in (multi as Array):
			var sid: String = str(item).strip_edges()
			if not sid.is_empty() and not targets.has(sid):
				targets.append(sid)
	var inters: Array = source.region.call("get_interactables") as Array
	for it_v: Variant in inters:
		if not is_instance_valid(it_v) or not (it_v is LxInteractable) or it_v == source:
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not targets.is_empty() and not targets.has(it.id):
			continue
		if it.has_method("reset_toy"):
			it.call("reset_toy")
			count += 1
	return count
