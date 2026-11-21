class_name LxMinimap
extends RefCounted
## Compact 52x30 Last Light corner minimap rendered from Lx.world (LxRegionLoader).

const PANEL_W: float = 52.0
const PANEL_H: float = 30.0
const INNER_W: float = 48.0
const INNER_H: float = 26.0


static func draw_minimap(c: CanvasItem, origin: Vector2, blink_t: float) -> void:
	if c == null or Lx.world == null:
		return
	var bounds_v: Variant = Lx.world.call("get_bounds") if Lx.world.has_method("get_bounds") else Lx.world.get("bounds")
	if not (bounds_v is Rect2):
		return
	var bounds: Rect2 = bounds_v as Rect2
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return

	var o: Vector2 = origin.round()
	LxPixelFont.draw_panel(c, Rect2(o, Vector2(PANEL_W, PANEL_H)), "night", "mauve", "void")
	var inner := Rect2(o + Vector2(2.0, 2.0), Vector2(INNER_W, INNER_H))

	_draw_zones(c, bounds, inner)
	_draw_interactables(c, bounds, inner, blink_t)
	_draw_player(c, bounds, inner, blink_t)
	_draw_map_hint(c, o)


static func _draw_zones(c: CanvasItem, bounds: Rect2, inner: Rect2) -> void:
	if not Lx.world.has_method("get_zones"):
		return
	var zones_v: Variant = Lx.world.call("get_zones")
	if not (zones_v is Array):
		return
	for item: Variant in (zones_v as Array):
		if not (item is Dictionary):
			continue
		var z: Dictionary = item as Dictionary
		var zrect: Rect2 = LxMapFormat.to_rect2(z.get("rect", []))
		if zrect.size.x <= 0.0 or zrect.size.y <= 0.0:
			continue
		var zid: String = str(z.get("id", ""))
		var lit: bool = Lx.world.has_method("is_zone_lit") and bool(Lx.world.call("is_zone_lit", zid))
		var rx0: float = floorf(inner.position.x + clampf((zrect.position.x - bounds.position.x) / bounds.size.x, 0.0, 1.0) * inner.size.x)
		var ry0: float = floorf(inner.position.y + clampf((zrect.position.y - bounds.position.y) / bounds.size.y, 0.0, 1.0) * inner.size.y)
		var rx1: float = ceilf(inner.position.x + clampf((zrect.end.x - bounds.position.x) / bounds.size.x, 0.0, 1.0) * inner.size.x)
		var ry1: float = ceilf(inner.position.y + clampf((zrect.end.y - bounds.position.y) / bounds.size.y, 0.0, 1.0) * inner.size.y)
		var r := Rect2(
			rx0,
			ry0,
			clampf(maxf(1.0, rx1 - rx0), 0.0, inner.end.x - rx0),
			clampf(maxf(1.0, ry1 - ry0), 0.0, inner.end.y - ry0)
		)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var edge_col: Color = LxPalette.PAL["teal"] if lit else LxPalette.PAL["dusk"]
		var fill_col: Color = LxPalette.PAL["pine"] if lit else LxPalette.PAL["void"]
		c.draw_rect(r, edge_col)
		if r.size.x > 2.0 and r.size.y > 2.0:
			c.draw_rect(r.grow(-1.0), fill_col)


static func _draw_interactables(c: CanvasItem, bounds: Rect2, inner: Rect2, blink_t: float) -> void:
	if not Lx.world.has_method("get_interactables"):
		return
	var items_v: Variant = Lx.world.call("get_interactables")
	if not (items_v is Array):
		return
	var pulse_on: bool = fmod(blink_t, 0.7) < 0.35
	for item: Variant in (items_v as Array):
		if item == null or not (item is Object) or not is_instance_valid(item):
			continue
		var obj: Object = item as Object
		if not _prop_bool(obj, "active"):
			continue
		var kind: String = str(obj.get("kind"))
		var wpos_v: Variant = obj.get("pos")
		var wpos: Vector2 = (wpos_v as Vector2) if wpos_v is Vector2 else ((obj as Node2D).global_position if obj is Node2D else Vector2.ZERO)
		match kind:
			"beacon":
				var col: Color = LxPalette.PAL["gold"] if _prop_bool(obj, "lit") else (LxPalette.PAL["coral"] if pulse_on else LxPalette.PAL["apricot"])
				_draw_pip(c, wpos, bounds, inner, 2.0, col)
			"shrine":
				if not _prop_bool(obj, "claimed"):
					_draw_pip(c, wpos, bounds, inner, 2.0, LxPalette.PAL["sky"])
			"waystone":
				if _prop_bool(obj, "lit"):
					_draw_pip(c, wpos, bounds, inner, 1.0, LxPalette.PAL["ice"])
			"rest_shrine":
				_draw_pip(c, wpos, bounds, inner, 2.0, LxPalette.PAL["apricot"])
			"great_lamp":
				_draw_pip(c, wpos, bounds, inner, 2.0, LxPalette.PAL["gold"])


static func _draw_player(c: CanvasItem, bounds: Rect2, inner: Rect2, blink_t: float) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return
	var wpos: Vector2 = (Lx.player as Node2D).global_position
	var nx: float = clampf((wpos.x - bounds.position.x) / bounds.size.x, 0.0, 1.0)
	var ny: float = clampf((wpos.y - bounds.position.y) / bounds.size.y, 0.0, 1.0)
	var px: float = clampf(floorf(inner.position.x + nx * (inner.size.x - 2.0)), inner.position.x + 1.0, inner.end.x - 3.0)
	var py: float = clampf(floorf(inner.position.y + ny * (inner.size.y - 2.0)), inner.position.y + 1.0, inner.end.y - 3.0)
	var border_col: Color = LxPalette.PAL["gold"] if fmod(blink_t, 0.6) < 0.35 else LxPalette.PAL["apricot"]
	c.draw_rect(Rect2(px - 1.0, py - 1.0, 4.0, 4.0), border_col)
	c.draw_rect(Rect2(px, py, 2.0, 2.0), LxPalette.PAL["cream"])


static func _draw_map_hint(c: CanvasItem, origin: Vector2) -> void:
	var glyph: String = "-"
	if Lx.input != null:
		var raw: String = LxStrings.sanitize(Lx.input.get_glyph("lx_map"), 6)
		if not raw.is_empty():
			glyph = raw
	var hint: String = LxStrings.fmt("HUD_MAP_HINT", [glyph])
	LxPixelFont.draw_right(c, hint, origin.x + PANEL_W, origin.y + PANEL_H + 2.0, LxPalette.PAL["stone"], 1)


static func _draw_pip(c: CanvasItem, wpos: Vector2, bounds: Rect2, inner: Rect2, sz: float, col: Color) -> void:
	var nx: float = clampf((wpos.x - bounds.position.x) / bounds.size.x, 0.0, 1.0)
	var ny: float = clampf((wpos.y - bounds.position.y) / bounds.size.y, 0.0, 1.0)
	var px: float = clampf(floorf(inner.position.x + nx * (inner.size.x - sz)), inner.position.x, inner.end.x - sz)
	var py: float = clampf(floorf(inner.position.y + ny * (inner.size.y - sz)), inner.position.y, inner.end.y - sz)
	c.draw_rect(Rect2(px, py, sz, sz), col)


static func _prop_bool(obj: Object, prop: String) -> bool:
	var v: Variant = obj.get(prop)
	return v is bool and bool(v)
