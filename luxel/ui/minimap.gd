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
	_draw_frame_accents(c, o, inner)
	_draw_exits(c, bounds, inner)
	_draw_interactables(c, bounds, inner, blink_t)
	_draw_boss_alerts(c, bounds, inner, blink_t)
	_draw_player(c, bounds, inner, blink_t)
	_draw_map_hint(c, o)


static func _draw_frame_accents(c: CanvasItem, o: Vector2, inner: Rect2) -> void:
	var gold: Color = LxPalette.PAL["gold"]
	var apr: Color = LxPalette.PAL["apricot"]
	var dusk: Color = LxPalette.PAL["dusk"]
	var x1: float = o.x + PANEL_W - 2.0
	var y1: float = o.y + PANEL_H - 2.0
	# 1 px brass corner accents on frame border.
	for corner: Array in [[o.x + 1.0, o.y + 1.0, 1.0, 1.0], [x1, o.y + 1.0, -1.0, 1.0], [o.x + 1.0, y1, 1.0, -1.0], [x1, y1, -1.0, -1.0]]:
		var cx0: float = float(corner[0])
		var cy0: float = float(corner[1])
		c.draw_rect(Rect2(cx0, cy0, 1.0, 1.0), gold)
		c.draw_rect(Rect2(cx0 + float(corner[2]), cy0, 1.0, 1.0), apr)
		c.draw_rect(Rect2(cx0, cy0 + float(corner[3]), 1.0, 1.0), apr)
	# Faint N/S/E/W cardinal tick notches on inner border.
	var mx: float = floorf(inner.position.x + inner.size.x * 0.5) - 1.0
	var my: float = floorf(inner.position.y + inner.size.y * 0.5) - 1.0
	c.draw_rect(Rect2(mx, o.y + 1.0, 2.0, 1.0), apr)
	c.draw_rect(Rect2(mx, inner.position.y, 2.0, 1.0), dusk)
	c.draw_rect(Rect2(mx, y1, 2.0, 1.0), dusk)
	c.draw_rect(Rect2(mx, inner.end.y - 1.0, 2.0, 1.0), dusk)
	c.draw_rect(Rect2(o.x + 1.0, my, 1.0, 2.0), dusk)
	c.draw_rect(Rect2(inner.position.x, my, 1.0, 2.0), dusk)
	c.draw_rect(Rect2(x1, my, 1.0, 2.0), dusk)
	c.draw_rect(Rect2(inner.end.x - 1.0, my, 1.0, 2.0), dusk)


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
		var lit: bool = Lx.world.has_method("is_zone_lit") and bool(Lx.world.call("is_zone_lit", str(z.get("id", ""))))
		var rx0: float = floorf(inner.position.x + clampf((zrect.position.x - bounds.position.x) / bounds.size.x, 0.0, 1.0) * inner.size.x)
		var ry0: float = floorf(inner.position.y + clampf((zrect.position.y - bounds.position.y) / bounds.size.y, 0.0, 1.0) * inner.size.y)
		var rx1: float = ceilf(inner.position.x + clampf((zrect.end.x - bounds.position.x) / bounds.size.x, 0.0, 1.0) * inner.size.x)
		var ry1: float = ceilf(inner.position.y + clampf((zrect.end.y - bounds.position.y) / bounds.size.y, 0.0, 1.0) * inner.size.y)
		var r := Rect2(rx0, ry0, clampf(maxf(1.0, rx1 - rx0), 0.0, inner.end.x - rx0), clampf(maxf(1.0, ry1 - ry0), 0.0, inner.end.y - ry0))
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		c.draw_rect(r, LxPalette.PAL["teal"] if lit else LxPalette.PAL["dusk"])
		if r.size.x > 2.0 and r.size.y > 2.0:
			c.draw_rect(r.grow(-1.0), LxPalette.PAL["pine"] if lit else LxPalette.PAL["void"])


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
				var ws_col: Color = LxPalette.PAL["ice"] if _prop_bool(obj, "lit") else (LxPalette.PAL["sky"] if pulse_on else LxPalette.PAL["blue"])
				_draw_pip(c, wpos, bounds, inner, 1.0, ws_col)
			"rest_shrine":
				_draw_pip(c, wpos, bounds, inner, 2.0, LxPalette.PAL["apricot"])
			"great_lamp", "great_belfry_brazier":
				var gp: Vector2 = _map_pt(wpos, bounds, inner, 3.0, 3.0)
				c.draw_rect(Rect2(gp.x + 1.0, gp.y, 1.0, 3.0), LxPalette.PAL["gold"])
				c.draw_rect(Rect2(gp.x, gp.y + 1.0, 3.0, 1.0), LxPalette.PAL["gold"])
				c.draw_rect(Rect2(gp.x + 1.0, gp.y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"])
			"door", "locked_door", "switch_door", "combat_gate", "ward_barrier", "dungeon_entrance":
				if _prop_bool(obj, "opened"):
					continue
				var dt_str: String = str(obj.get("door_type"))
				var dp: Vector2 = _map_pt(wpos, bounds, inner, 3.0, 2.0)
				if dt_str == "boss_key":
					c.draw_rect(Rect2(dp, Vector2(3.0, 2.0)), LxPalette.PAL["coral"] if pulse_on else LxPalette.PAL["plum"])
					c.draw_rect(Rect2(dp.x + 1.0, dp.y, 1.0, 2.0), LxPalette.PAL["gold"])
				elif dt_str == "ward_barrier" or kind == "ward_barrier":
					c.draw_rect(Rect2(dp, Vector2(3.0, 2.0)), LxPalette.PAL["deep"])
					c.draw_rect(Rect2(dp.x + 1.0, dp.y, 1.0, 2.0), LxPalette.PAL["ice"] if pulse_on else LxPalette.PAL["sky"])
				else:
					c.draw_rect(Rect2(dp, Vector2(3.0, 2.0)), LxPalette.PAL["plum"])
					c.draw_rect(Rect2(dp.x + 1.0, dp.y, 1.0, 2.0), LxPalette.PAL["apricot"])
			"wick_key", "boss_key", "keepers_flame":
				if _prop_bool(obj, "collected"):
					continue
				var is_boss_key: bool = kind == "boss_key" or kind == "keepers_flame" or str(obj.get("key_kind")) == "keepers_flame"
				if is_boss_key:
					var kp: Vector2 = _map_pt(wpos, bounds, inner, 3.0, 3.0)
					var kc: Color = LxPalette.PAL["gold"] if pulse_on else LxPalette.PAL["coral"]
					c.draw_rect(Rect2(kp.x + 1.0, kp.y, 1.0, 3.0), kc)
					c.draw_rect(Rect2(kp.x, kp.y + 1.0, 3.0, 1.0), kc)
					c.draw_rect(Rect2(kp.x + 1.0, kp.y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"])
				else:
					_draw_pip(c, wpos, bounds, inner, 2.0, LxPalette.PAL["gold"] if pulse_on else LxPalette.PAL["apricot"])
			"bridge", "bridge_platform":
				c.draw_rect(Rect2(_map_pt(wpos, bounds, inner, 3.0, 1.0), Vector2(3.0, 1.0)), LxPalette.PAL["apricot"])
			"road_lamp":
				if _prop_bool(obj, "lit"):
					_draw_pip(c, wpos, bounds, inner, 1.0, LxPalette.PAL["gold"])
			"chest":
				if not _prop_bool(obj, "opened"):
					c.draw_rect(Rect2(_map_pt(wpos, bounds, inner, 2.0, 1.0), Vector2(2.0, 1.0)), LxPalette.PAL["gold"] if pulse_on else LxPalette.PAL["apricot"])


static func _draw_exits(c: CanvasItem, bounds: Rect2, inner: Rect2) -> void:
	if not _prop_bool(Lx.world, "is_dungeon"):
		return
	var exits_v: Variant = Lx.world.get("exits")
	if not (exits_v is Array):
		return
	for ex_v: Variant in (exits_v as Array):
		if not (ex_v is Dictionary):
			continue
		var ex: Dictionary = ex_v as Dictionary
		var did: String = str(ex.get("locked_door_id", ""))
		if not did.is_empty() and Lx.world.has_method("find_interactable"):
			var door: Variant = Lx.world.call("find_interactable", did)
			if door is Object and (door as Object).has_method("is_solid") and bool((door as Object).call("is_solid")):
				continue
		var r: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
		if r.size.x > 0.0 and r.size.y > 0.0:
			_draw_pip(c, r.get_center(), bounds, inner, 2.0, LxPalette.PAL["gold"])


static func _draw_boss_alerts(c: CanvasItem, bounds: Rect2, inner: Rect2, blink_t: float) -> void:
	if not Lx.world.has_method("get_enemies"):
		return
	var enemies_v: Variant = Lx.world.call("get_enemies")
	if not (enemies_v is Array):
		return
	var pulse_on: bool = fmod(blink_t, 0.5) < 0.28
	for item: Variant in (enemies_v as Array):
		if item == null or not (item is Object) or not is_instance_valid(item):
			continue
		var obj: Object = item as Object
		if not _prop_bool(obj, "is_boss"):
			continue
		var alive: bool = bool(obj.call("is_alive")) if obj.has_method("is_alive") else (not (obj.get("hp") is float or obj.get("hp") is int) or float(obj.get("hp")) > 0.0)
		if not alive:
			continue
		var wpos: Vector2 = (obj as Node2D).global_position if obj is Node2D else (obj.get("pos") as Vector2 if obj.get("pos") is Vector2 else Vector2.ZERO)
		var pt: Vector2 = _map_pt(wpos, bounds, inner, 2.0, 2.0)
		if pulse_on:
			c.draw_rect(Rect2(pt.x - 1.0, pt.y - 1.0, 4.0, 4.0), LxPalette.PAL["void"])
		c.draw_rect(Rect2(pt, Vector2(2.0, 2.0)), LxPalette.PAL["coral"] if pulse_on else LxPalette.PAL["wine"])


static func _draw_player(c: CanvasItem, bounds: Rect2, inner: Rect2, blink_t: float) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return
	var lan_v: Variant = Lx.player.get("lantern")
	if lan_v is Object and is_instance_valid(lan_v) and (lan_v as Object).has_method("is_out") and bool((lan_v as Object).call("is_out")):
		var lpos_v: Variant = (lan_v as Object).get("pos")
		if lpos_v is Vector2:
			var lp: Vector2 = _map_pt(lpos_v as Vector2, bounds, inner, 2.0, 2.0)
			var stolen: bool = int((lan_v as Object).get("state")) == 4
			c.draw_rect(Rect2(lp, Vector2(2.0, 2.0)), LxPalette.PAL["coral"] if (stolen and fmod(blink_t, 0.4) < 0.2) else LxPalette.PAL["gold"])
	var p: Vector2 = _map_pt((Lx.player as Node2D).global_position, bounds, inner.grow(-2.0), 2.0, 2.0)
	var border_col: Color = LxPalette.PAL["gold"] if fmod(blink_t, 0.6) < 0.35 else LxPalette.PAL["apricot"]
	c.draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 4.0, 6.0), border_col)
	c.draw_rect(Rect2(p.x - 2.0, p.y - 1.0, 6.0, 4.0), border_col)
	c.draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 4.0, 4.0), LxPalette.PAL["void"])
	c.draw_rect(Rect2(p.x, p.y, 2.0, 2.0), LxPalette.PAL["cream"])


static func _draw_map_hint(c: CanvasItem, origin: Vector2) -> void:
	var glyph: String = "-"
	if Lx.input != null:
		var raw: String = LxStrings.sanitize(Lx.input.get_glyph("lx_map"), 6)
		if not raw.is_empty():
			glyph = raw
	var hint: String = LxStrings.fmt("HUD_MAP_HINT", [glyph])
	LxPixelFont.draw_right(c, hint, origin.x + PANEL_W, origin.y + PANEL_H + 2.0, LxPalette.PAL["stone"], 1)


static func _map_pt(wpos: Vector2, bounds: Rect2, inner: Rect2, w: float, h: float) -> Vector2:
	var nx: float = clampf((wpos.x - bounds.position.x) / bounds.size.x, 0.0, 1.0)
	var ny: float = clampf((wpos.y - bounds.position.y) / bounds.size.y, 0.0, 1.0)
	var px: float = clampf(floorf(inner.position.x + nx * (inner.size.x - w)), inner.position.x, inner.end.x - w)
	var py: float = clampf(floorf(inner.position.y + ny * (inner.size.y - h)), inner.position.y, inner.end.y - h)
	return Vector2(px, py)


static func _draw_pip(c: CanvasItem, wpos: Vector2, bounds: Rect2, inner: Rect2, sz: float, col: Color) -> void:
	c.draw_rect(Rect2(_map_pt(wpos, bounds, inner, sz, sz), Vector2(sz, sz)), col)


static func _prop_bool(obj: Object, prop: String) -> bool:
	var v: Variant = obj.get(prop)
	return v is bool and bool(v)
