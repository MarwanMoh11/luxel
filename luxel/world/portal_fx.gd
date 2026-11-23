class_name LxPortalFx
extends Node2D
## Living biome-bespoke glowing threshold runes & beckoning Bridge-of-Light portal arches
## rendered at open exits across all 81 regions (z_index = -1, strictly 20 Last Light colours).

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 196.0
const HALF_H: float = 124.0

static var active_instance: LxPortalFx = null

var _region: Node = null
var _island_id: int = 1
var _is_dungeon: bool = false
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _exits: Array[Dictionary] = [] # {rect, center, kind, next_isl, locked_id, req_flags}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1
	active_instance = self


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null


func configure(rules: LxBiomeRules, region_node: Node) -> void:
	active_instance = self
	_region = region_node
	_island_id = rules.island_id if rules != null else 1
	_is_dungeon = rules.is_dungeon if rules != null else false
	_clock = 0.0
	_cam_center = rules.bounds.get_center() if rules != null else Vector2.ZERO
	_exits.clear()
	if _region != null and is_instance_valid(_region):
		var ex_v: Variant = _region.get("exits")
		if ex_v is Array:
			for raw: Variant in (ex_v as Array):
				if not (raw is Dictionary):
					continue
				var ex: Dictionary = raw as Dictionary
				var r: Rect2 = LxMapFormat.to_rect2(ex.get("rect", []))
				if not r.has_area():
					continue
				var to_reg: String = str(ex.get("to_region", ""))
				var next_isl: int = int(ex.get("to_island", 0))
				if next_isl <= 0 and to_reg.begins_with("island") and to_reg.find(":") > 6:
					next_isl = int(to_reg.substr(6, to_reg.find(":") - 6))
				var kind: int = 2 # dungeon hall doorway
				if next_isl > 0 and next_isl != _island_id:
					kind = 0 # Bridge of Light to another island!
				elif not _is_dungeon and to_reg != "overworld":
					kind = 1 # Open overworld Dungeon Entrance!
				var req_f: PackedStringArray = PackedStringArray()
				var rf_v: Variant = ex.get("requires_flags", [])
				if rf_v is Array:
					for fv: Variant in (rf_v as Array):
						req_f.append(str(fv))
				_exits.append({
					"rect": r,
					"center": r.get_center().round(),
					"kind": kind,
					"next_isl": next_isl if next_isl > 0 else _island_id,
					"locked_id": str(ex.get("locked_door_id", "")),
					"req_flags": req_f,
				})
	queue_redraw()


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if dt <= 0.0 or _exits.is_empty():
		return
	_clock += dt
	queue_redraw()


func _is_exit_open(ex: Dictionary) -> bool:
	if _region == null or not is_instance_valid(_region):
		return false
	var did: String = str(ex["locked_id"])
	if not did.is_empty() and _region.has_method("find_interactable"):
		var door: Variant = _region.call("find_interactable", did)
		if door is Object and is_instance_valid(door) and (door as Object).has_method("is_solid"):
			if bool((door as Object).call("is_solid")):
				return false
	if _region.has_method("is_flag_set"):
		var req_f: PackedStringArray = ex["req_flags"] as PackedStringArray
		for f: String in req_f:
			if not f.is_empty() and not bool(_region.call("is_flag_set", f)):
				return false
	return true


func get_light_pools() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for ex: Dictionary in _exits:
		if not _is_exit_open(ex):
			continue
		var c: Vector2 = ex["center"] as Vector2
		var kind: int = int(ex["kind"])
		if kind == 0:
			out.append(Vector4(c.x, c.y, 48.0, 0.72))
		elif kind == 1:
			out.append(Vector4(c.x, c.y, 44.0, 0.62))
		else:
			out.append(Vector4(c.x, c.y, 30.0, 0.36))
	return out


func _draw() -> void:
	if _exits.is_empty():
		return
	var fred: bool = LxHudFx.flash_reduced()
	var c_glow: Color = LxBiomePalette.col(_island_id, "glow")
	var c_hi: Color = LxBiomePalette.col(_island_id, "hi")
	var c_cream: Color = PAL["cream"] as Color
	var wp: Vector2 = (Lx.player as Node2D).global_position if (Lx.player is Node2D and is_instance_valid(Lx.player)) else _cam_center
	for ex: Dictionary in _exits:
		var c: Vector2 = ex["center"] as Vector2
		if absf(c.x - _cam_center.x) > HALF_W or absf(c.y - _cam_center.y) > HALF_H:
			continue
		if not _is_exit_open(ex):
			continue
		var r: Rect2 = ex["rect"] as Rect2
		var kind: int = int(ex["kind"])
		var pulse: float = 0.72 if fred else (0.62 + 0.38 * sin(_clock * 3.0 + c.x * 0.02))
		if kind == 0:
			_draw_bridge_portal(r, c, int(ex["next_isl"]), c_glow, c_cream, pulse, fred)
		elif kind == 1:
			_draw_dungeon_entrance(r, c, c_glow, c_hi, c_cream, pulse, fred)
		else:
			_draw_room_threshold(r, c, c_glow, c_cream, pulse, wp)


func _draw_bridge_portal(r: Rect2, c: Vector2, next_isl: int, col_a: Color, cream: Color, pulse: float, fred: bool) -> void:
	var col_b: Color = LxBiomePalette.col(next_isl, "glow")
	var rad: float = minf(maxf(r.size.x, r.size.y) * 0.45, 22.0)
	draw_arc(c, roundf(rad), 0.0, TAU, 22, Color(col_a, 0.36 * pulse), 1.5)
	draw_arc(c, roundf(maxf(6.0, rad - 5.0)), _clock * 0.8, _clock * 0.8 + PI * 1.4, 16, Color(col_b, 0.52 * pulse), 1.4)
	# Heraldic Biome Crest of the destination island gleaming at the Bridge of Light threshold!
	LxHudFx.draw_biome_crest(self, next_isl, c, Color(col_b, 0.85 * pulse), Color(cream, 0.90))
	for k: int in range(4):
		var u: float = fposmod(_clock * 0.75 + float(k) * 0.25, 1.0)
		var mx: float = roundf(c.x + sin(_clock * 2.0 + float(k) * 1.7) * (rad * 0.55))
		var my: float = roundf(c.y + 8.0 - u * 24.0)
		draw_rect(Rect2(mx, my, 2.0 if (not fred and k % 2 == 0) else 1.0, 1.0), Color(cream if u < 0.35 else col_b, sin(u * PI) * 0.85))
	# Beckoning destination-biome chevrons orbiting the Bridge of Light threshold
	var ch_off: float = 0.0 if fred else roundf(sin(_clock * 3.0) * 2.0)
	for side: float in [-1.0, 1.0]:
		var tip := Vector2(roundf(c.x + side * (rad + 5.0 + ch_off)), roundf(c.y))
		draw_line(tip, tip + Vector2(-side * 3.0, -3.0), Color(col_b, 0.72 * pulse), 1.0)
		draw_line(tip, tip + Vector2(-side * 3.0, 3.0), Color(cream, 0.68 * pulse), 1.0)


func _draw_dungeon_entrance(r: Rect2, c: Vector2, col_g: Color, col_h: Color, cream: Color, pulse: float, fred: bool) -> void:
	var w: float = minf(r.size.x, 32.0)
	var x0: float = roundf(c.x - w * 0.5)
	var y0: float = roundf(c.y - 6.0)
	draw_rect(Rect2(x0, y0, w, 12.0), Color(col_h, 0.14 * pulse))
	draw_rect(Rect2(x0, y0, w, 1.0), Color(col_g, 0.55 * pulse))
	draw_rect(Rect2(x0, y0 + 11.0, w, 1.0), Color(col_g, 0.55 * pulse))
	_draw_biome_gateway_frame(c, w, col_g, col_h, cream, pulse, fred)
	LxHudFx.draw_biome_crest(self, _island_id, c, Color(col_g, 0.78 * pulse), Color(cream, 0.82))
	if not fred:
		for k: int in range(3):
			var u: float = fposmod(_clock * 0.65 + float(k) * 0.33, 1.0)
			var mx: float = roundf(c.x + float(k - 1) * 8.0)
			var my: float = roundf(c.y + 5.0 - u * 16.0)
			draw_rect(Rect2(mx, my, 1.0, 1.0), Color(cream if u < 0.4 else col_g, sin(u * PI) * 0.78))


func _draw_biome_gateway_frame(c: Vector2, w: float, col_g: Color, col_h: Color, cream: Color, pulse: float, fred: bool) -> void:
	var hw: float = roundf(w * 0.5)
	var a_hi: float = 0.68 * pulse
	match _island_id:
		1: # Great Belfry: twin choir columns + golden bell-gable arch
			draw_line(c + Vector2(-hw, 6.0), c + Vector2(-hw, -7.0), Color(col_g, a_hi), 1.4)
			draw_line(c + Vector2(hw, 6.0), c + Vector2(hw, -7.0), Color(col_g, a_hi), 1.4)
			draw_arc(c + Vector2(0.0, -7.0), hw, PI, TAU, 14, Color(col_g, a_hi), 1.4)
			draw_rect(Rect2(c + Vector2(-1.0, -hw - 6.0), Vector2(2.0, 2.0)), Color(cream, a_hi))
		2: # The Lighthouse: curved lantern cupola + sweeping sea-ice glint
			draw_arc(c + Vector2(0.0, -4.0), hw, PI, TAU, 14, Color(PAL["ice"] as Color, a_hi), 1.4)
			var glint_x: float = roundf(c.x + (0.0 if fred else sin(_clock * 1.9) * (hw - 4.0)))
			draw_line(Vector2(glint_x, c.y - 6.0), Vector2(glint_x, c.y + 5.0), Color(PAL["ice"] as Color, 0.35 * pulse), 2.0)
		3: # Hollow Oak: intertwined pine/jade root-arch with lime canopy buds
			draw_arc(c + Vector2(0.0, -4.0), hw + 1.0, PI, TAU, 14, Color(PAL["jade"] as Color, a_hi), 1.8)
			for side3: float in [-1.0, 1.0]:
				draw_line(c + Vector2(side3 * hw, 6.0), c + Vector2(side3 * (hw + 3.0), 8.0), Color(PAL["pine"] as Color, a_hi), 1.5)
				draw_rect(Rect2(c + Vector2(side3 * (hw - 3.0), -10.0), Vector2(2.0, 2.0)), Color(PAL["lime"] as Color, a_hi))
		4: # Sunken Conservatory: pointed glasshouse gable + rose/ice transoms
			draw_line(c + Vector2(-hw, -5.0), c + Vector2(0.0, -14.0), Color(PAL["teal"] as Color, a_hi), 1.4)
			draw_line(c + Vector2(hw, -5.0), c + Vector2(0.0, -14.0), Color(PAL["teal"] as Color, a_hi), 1.4)
			draw_rect(Rect2(c + Vector2(-4.0, -10.0), Vector2(3.0, 3.0)), Color(PAL["rose"] as Color, 0.55 * pulse))
			draw_rect(Rect2(c + Vector2(1.0, -10.0), Vector2(3.0, 3.0)), Color(PAL["ice"] as Color, 0.55 * pulse))
		5: # Grand Orrery: brass zodiac ring with rotating cardinal ticks
			var rot5: float = 0.0 if fred else _clock * 0.7
			draw_arc(c, hw + 1.0, 0.0, TAU, 20, Color(PAL["gold"] as Color, 0.45 * pulse), 1.2)
			for t5: int in range(4):
				var ang5: float = rot5 + float(t5) * (PI * 0.5)
				var pt5: Vector2 = (c + Vector2.from_angle(ang5) * (hw + 1.0)).round()
				draw_rect(Rect2(pt5 - Vector2.ONE, Vector2(2.0, 2.0)), Color(cream if t5 % 2 == 0 else PAL["sky"] as Color, a_hi))
		6: # Great Kiln: stepped volcanic furnace lintel with glowing coral/gold vents
			draw_rect(Rect2(c + Vector2(-hw - 2.0, -9.0), Vector2(w + 4.0, 3.0)), Color(PAL["wine"] as Color, 0.65 * pulse))
			for vx: float in [-8.0, 0.0, 8.0]:
				draw_rect(Rect2(c + Vector2(vx - 1.0, -8.0), Vector2(2.0, 2.0)), Color(PAL["gold"] as Color if not fred else PAL["coral"] as Color, a_hi))
		7: # Moon Spire: twin silver crescent gateposts + lunar center seam
			draw_arc(c + Vector2(-hw - 1.0, 0.0), 6.0, -PI * 0.55, PI * 0.55, 8, Color(PAL["ice"] as Color, a_hi), 1.4)
			draw_arc(c + Vector2(hw + 1.0, 0.0), 6.0, PI * 0.45, PI * 1.55, 8, Color(PAL["ice"] as Color, a_hi), 1.4)
			draw_line(c + Vector2(0.0, -11.0), c + Vector2(0.0, 7.0), Color(PAL["sky"] as Color, 0.35 * pulse), 1.0)
		_: # Bell Sanctum: tall gothic rose-gold cathedral arch + radiant dawn keystone
			draw_line(c + Vector2(-hw, 6.0), c + Vector2(-hw, -8.0), Color(PAL["plum"] as Color, a_hi), 1.5)
			draw_line(c + Vector2(hw, 6.0), c + Vector2(hw, -8.0), Color(PAL["plum"] as Color, a_hi), 1.5)
			draw_line(c + Vector2(-hw, -8.0), c + Vector2(0.0, -16.0), Color(col_g, a_hi), 1.5)
			draw_line(c + Vector2(hw, -8.0), c + Vector2(0.0, -16.0), Color(col_g, a_hi), 1.5)
			draw_circle(c + Vector2(0.0, -14.0), 2.5, Color(cream, a_hi))


func _draw_room_threshold(r: Rect2, c: Vector2, col_g: Color, cream: Color, pulse: float, wp: Vector2) -> void:
	var near_boost: float = 1.45 if c.distance_squared_to(wp) <= 19600.0 else 0.85
	var a: float = clampf(0.30 * pulse * near_boost, 0.12, 0.62)
	var horiz: bool = r.size.x >= r.size.y
	if horiz:
		var span: float = minf(r.size.x - 4.0, 24.0)
		draw_rect(Rect2(roundf(c.x - span * 0.5), roundf(c.y), span, 1.0), Color(col_g, a))
		for k: int in range(-1, 2):
			draw_rect(Rect2(roundf(c.x + float(k) * 6.0), roundf(c.y - 1.0), 2.0, 2.0), Color(cream if k == 0 else col_g, a * 1.25))
	else:
		var span_v: float = minf(r.size.y - 4.0, 24.0)
		draw_rect(Rect2(roundf(c.x), roundf(c.y - span_v * 0.5), 1.0, span_v), Color(col_g, a))
		for k: int in range(-1, 2):
			draw_rect(Rect2(roundf(c.x - 1.0), roundf(c.y + float(k) * 6.0), 2.0, 2.0), Color(cream if k == 0 else col_g, a * 1.25))
