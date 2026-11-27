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
					"greet_cd": 1.2,
				})
	queue_redraw()


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if dt <= 0.0 or _exits.is_empty():
		return
	_clock += dt
	var wp: Vector2 = (Lx.player as Node2D).global_position if (Lx.player is Node2D and is_instance_valid(Lx.player)) else Vector2(1e6, 1e6)
	for ex: Dictionary in _exits:
		var gcd: float = maxf(0.0, float(ex.get("greet_cd", 0.0)) - dt)
		ex["greet_cd"] = gcd
		if int(ex["kind"]) == 0 and gcd <= 0.0 and _is_exit_open(ex):
			var c: Vector2 = ex["center"] as Vector2
			if c.distance_squared_to(wp) <= 3364.0: # 58 px proximity whisper
				ex["greet_cd"] = 9.0
				if Lx.audio != null:
					Lx.audio.play_sfx(_bridge_whisper_sfx(int(ex["next_isl"])), c, true)
	queue_redraw()


func _bridge_whisper_sfx(next_isl: int) -> String:
	match next_isl:
		2:
			return "lighthouse_toll"
		3:
			return "prop_chime"
		4:
			return "wing_gale"
		5:
			return "clockwork_chime"
		6:
			return "forge_gust"
		7:
			return "lens_reveal"
		8:
			return "void_hum"
		_:
			return "bell_toll"


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
			_draw_bridge_portal(r, c, int(ex["next_isl"]), c_glow, c_cream, pulse, fred, wp)
		elif kind == 1:
			_draw_dungeon_entrance(r, c, c_glow, c_hi, c_cream, pulse, fred, wp)
		else:
			_draw_room_threshold(r, c, c_glow, c_cream, pulse, wp)


func _draw_bridge_portal(r: Rect2, c: Vector2, next_isl: int, col_a: Color, cream: Color, pulse: float, fred: bool, wp: Vector2) -> void:
	var col_b: Color = LxBiomePalette.col(next_isl, "glow")
	var col_b_hi: Color = LxBiomePalette.col(next_isl, "hi")
	var prox: float = clampf(1.0 - c.distance_to(wp) / 96.0, 0.0, 1.0)
	var rad: float = minf(maxf(r.size.x, r.size.y) * 0.45, 22.0)
	draw_arc(c, roundf(rad), 0.0, TAU, 22, Color(col_a, (0.36 + prox * 0.22) * pulse), 2.0)
	draw_arc(c, roundf(maxf(6.0, rad - 5.0)), _clock * 0.8, _clock * 0.8 + PI * 1.4, 16, Color(col_b, (0.52 + prox * 0.28) * pulse), 1.0)
	if prox > 0.05:
		draw_arc(c, roundf(rad + 4.0), -_clock * 0.45, -_clock * 0.45 + PI * 1.2, 18, Color(col_b_hi, 0.44 * prox * pulse), 1.0)
	# Heraldic Biome Crest of the destination island gleaming at the Bridge of Light threshold!
	LxHudFx.draw_biome_crest(self, next_isl, c, Color(col_b, (0.85 + prox * 0.12) * pulse), Color(cream, 0.90))
	for k: int in range(4):
		var u: float = fposmod(_clock * 0.75 + float(k) * 0.25, 1.0)
		var mx: float = roundf(c.x + sin(_clock * 2.0 + float(k) * 1.7) * (rad * 0.55))
		var my: float = roundf(c.y + 8.0 - u * 24.0)
		draw_rect(Rect2(mx, my, 2.0 if (not fred and k % 2 == 0) else 1.0, 1.0), Color(cream if u < 0.35 else col_b, sin(u * PI) * 0.85))
	# Destination-biome floating constellation embers streaming gently across the Bridge of Light
	var stream_n: int = 2 if fred else 4
	var horiz_b: bool = r.size.y >= r.size.x
	for si: int in range(stream_n):
		var su: float = fposmod(_clock * (0.32 if fred else 0.58) + float(si) * (1.0 / float(stream_n)), 1.0)
		var sa: float = sin(su * PI) * (0.48 + prox * 0.38)
		var off_s: float = lerpf(-rad - 4.0, rad + 6.0, su)
		var perp_s: float = sin(_clock * 1.8 + float(si) * 2.1) * 7.0
		var sp: Vector2 = (c + (Vector2(off_s, perp_s) if horiz_b else Vector2(perp_s, off_s))).round()
		draw_rect(Rect2(sp, Vector2(2.0 if si % 2 == 0 else 1.0, 1.0)), Color(cream if su > 0.6 else col_b, sa))
	# Beckoning destination-biome chevrons orbiting the Bridge of Light threshold
	var ch_off: float = 0.0 if fred else roundf(sin(_clock * 3.0) * 2.0)
	for side: float in [-1.0, 1.0]:
		var tip := Vector2(roundf(c.x + side * (rad + 5.0 + ch_off)), roundf(c.y))
		draw_line(tip, tip + Vector2(-side * 3.0, -3.0), Color(col_b, (0.72 + prox * 0.20) * pulse), 1.0)
		draw_line(tip, tip + Vector2(-side * 3.0, 3.0), Color(cream, (0.68 + prox * 0.22) * pulse), 1.0)
	# Floating miniature Destination Landmark Hologram shimmering above the Bridge when Wick approaches
	if prox > 0.12:
		_draw_destination_landmark(next_isl, c, col_b, col_b_hi, cream, prox, pulse, fred)


func _draw_destination_landmark(next_isl: int, c: Vector2, col_b: Color, col_hi: Color, cream: Color, prox: float, pulse: float, fred: bool) -> void:
	var bob: float = 0.0 if fred else roundf(sin(_clock * 2.4 + float(next_isl)) * 1.5)
	var base: Vector2 = (c + Vector2(0.0, -19.0 + bob)).round()
	var a_main: float = clampf((prox - 0.12) / 0.88, 0.0, 1.0) * (0.68 if fred else 0.86) * (0.78 + 0.22 * pulse)
	var c_m := Color(col_b, a_main)
	var c_h := Color(col_hi, a_main * 0.78)
	var c_c := Color(cream, minf(0.95, a_main * 1.12))
	# Soft projection cradle beneath the floating miniature silhouette
	draw_line(c + Vector2(-4.0, -7.0), base + Vector2(-5.0, 2.0), Color(col_hi, a_main * 0.28), 1.0)
	draw_line(c + Vector2(4.0, -7.0), base + Vector2(5.0, 2.0), Color(col_hi, a_main * 0.28), 1.0)
	draw_rect(Rect2(base + Vector2(-6.0, 1.0), Vector2(12.0, 1.0)), c_h)
	match next_isl:
		1: # Bell Isle: Great Belfry gable & hanging bell
			draw_rect(Rect2(base + Vector2(-4.0, -6.0), Vector2(1.0, 7.0)), c_m)
			draw_rect(Rect2(base + Vector2(3.0, -6.0), Vector2(1.0, 7.0)), c_m)
			draw_line(base + Vector2(-5.0, -6.0), base + Vector2(0.0, -11.0), c_c, 1.0)
			draw_line(base + Vector2(5.0, -6.0), base + Vector2(0.0, -11.0), c_c, 1.0)
			draw_rect(Rect2(base + Vector2(-1.0, -6.0), Vector2(2.0, 3.0)), c_c)
		2: # Tidewater Harbor: Lighthouse tower + sweeping Fresnel beam
			draw_rect(Rect2(base + Vector2(-2.0, -8.0), Vector2(4.0, 9.0)), c_m)
			draw_rect(Rect2(base + Vector2(-3.0, -9.0), Vector2(6.0, 2.0)), c_h)
			draw_rect(Rect2(base + Vector2(-1.0, -11.0), Vector2(2.0, 2.0)), c_c)
			var b_len: float = 7.0 if fred else (5.0 + absf(sin(_clock * 2.5)) * 4.0)
			draw_line(base + Vector2(-2.0, -10.0), base + Vector2(-2.0 - b_len, -11.0), c_c, 1.0)
			draw_line(base + Vector2(2.0, -10.0), base + Vector2(2.0 + b_len, -11.0), c_c, 1.0)
		3: # Thornwood Hollow: Hollow Oak arched trunk & layered emerald canopy
			draw_rect(Rect2(base + Vector2(-2.0, -5.0), Vector2(4.0, 6.0)), c_h)
			draw_circle(base + Vector2(0.0, -8.0), 4.0, c_m)
			draw_circle(base + Vector2(-4.0, -6.0), 2.5, c_m)
			draw_circle(base + Vector2(4.0, -6.0), 2.5, c_m)
			draw_rect(Rect2(base + Vector2(-1.0, -10.0), Vector2(2.0, 1.0)), c_c)
		4: # Mirefen Gardens: Pointed Conservatory glasshouse dome
			draw_rect(Rect2(base + Vector2(-5.0, -5.0), Vector2(10.0, 6.0)), c_h)
			draw_line(base + Vector2(-5.0, -5.0), base + Vector2(0.0, -10.0), c_m, 1.0)
			draw_line(base + Vector2(5.0, -5.0), base + Vector2(0.0, -10.0), c_m, 1.0)
			draw_line(base + Vector2(0.0, -10.0), base + Vector2(0.0, 1.0), c_c, 1.0)
			draw_rect(Rect2(base + Vector2(-3.0, -4.0), Vector2(2.0, 3.0)), c_c)
			draw_rect(Rect2(base + Vector2(1.0, -4.0), Vector2(2.0, 3.0)), c_c)
		5: # Starfall Observatory: Orrery dome + tilted golden astrolabe ring
			draw_arc(base + Vector2(0.0, -2.0), 5.0, PI, TAU, 10, c_m, 1.0)
			draw_line(base + Vector2(-7.0, -2.0), base + Vector2(7.0, -9.0), c_c, 1.0)
			draw_rect(Rect2(base + Vector2(0.0, -9.0), Vector2(1.0, 2.0)), c_c)
		6: # Ashen Kiln: Stepped volcanic furnace chimney & hearth crown
			draw_rect(Rect2(base + Vector2(-4.0, -4.0), Vector2(8.0, 5.0)), c_h)
			draw_rect(Rect2(base + Vector2(-3.0, -8.0), Vector2(6.0, 4.0)), c_m)
			draw_rect(Rect2(base + Vector2(-2.0, -10.0), Vector2(4.0, 2.0)), c_c)
			draw_rect(Rect2(base + Vector2(-1.0, -3.0), Vector2(2.0, 3.0)), c_c)
		7: # Moon Shoals: Twin-horned silver Lunar Mirror Spire
			draw_rect(Rect2(base + Vector2(-1.0, -9.0), Vector2(2.0, 10.0)), c_h)
			draw_arc(base + Vector2(0.0, -10.0), 4.0, 0.25, PI - 0.25, 8, c_c, 1.0)
			draw_rect(Rect2(base + Vector2(-4.0, -12.0), Vector2(1.0, 2.0)), c_m)
			draw_rect(Rect2(base + Vector2(3.0, -12.0), Vector2(1.0, 2.0)), c_m)
		_: # The Long Night: Twin-spired Gothic Eclipse Cathedral + Dawn star
			draw_rect(Rect2(base + Vector2(-5.0, -9.0), Vector2(2.0, 10.0)), c_h)
			draw_rect(Rect2(base + Vector2(3.0, -9.0), Vector2(2.0, 10.0)), c_h)
			draw_line(base + Vector2(-4.0, -9.0), base + Vector2(0.0, -12.0), c_m, 1.0)
			draw_line(base + Vector2(4.0, -9.0), base + Vector2(0.0, -12.0), c_m, 1.0)
			draw_rect(Rect2(base + Vector2(-1.0, -8.0), Vector2(3.0, 1.0)), c_c)
			draw_rect(Rect2(base + Vector2(0.0, -9.0), Vector2(1.0, 3.0)), c_c)


func _draw_dungeon_entrance(r: Rect2, c: Vector2, col_g: Color, col_h: Color, cream: Color, pulse: float, fred: bool, wp: Vector2) -> void:
	var prox: float = clampf(1.0 - c.distance_to(wp) / 88.0, 0.0, 1.0)
	var w: float = minf(r.size.x, 28.0)
	var hw: float = floorf(w * 0.5)
	var x0: float = roundf(c.x - hw)
	var y0: float = roundf(c.y - 4.0)
	var base_a: float = (0.12 + prox * 0.14) * pulse
	# Soft architectural floor light-spill from the open dungeon doorway
	draw_rect(Rect2(x0 + 2.0, y0, w - 4.0, 4.0), Color(col_g, base_a * 1.15))
	draw_rect(Rect2(x0 + 4.0, y0 + 4.0, w - 8.0, 4.0), Color(col_h, base_a * 0.72))
	draw_rect(Rect2(x0 + 6.0, y0 + 8.0, w - 12.0, 3.0), Color(col_h, base_a * 0.36))
	# Recessed flanking doorframe sconce glints
	for side: float in [-1.0, 1.0]:
		var sx: float = roundf(c.x + side * (hw + 1.0))
		draw_rect(Rect2(sx - 1.0, y0 - 1.0, 2.0, 3.0), Color(PAL["night"] as Color, 0.75))
		draw_rect(Rect2(sx, y0, 1.0, 1.0), Color(cream if prox > 0.3 else col_g, (0.58 + prox * 0.32) * pulse))
	_draw_biome_gateway_frame(c, w, col_g, col_h, cream, pulse * (0.72 + prox * 0.24), fred)
	if not fred:
		for k: int in range(2):
			var u: float = fposmod(_clock * 0.55 + float(k) * 0.5, 1.0)
			var mx: float = roundf(c.x + float(k * 2 - 1) * 5.0)
			var my: float = roundf(c.y + 4.0 - u * (12.0 + prox * 5.0))
			draw_rect(Rect2(mx, my, 1.0, 1.0), Color(cream if u < 0.35 else col_g, sin(u * PI) * (0.55 + prox * 0.22)))


func _draw_biome_gateway_frame(c: Vector2, w: float, col_g: Color, col_h: Color, cream: Color, pulse: float, fred: bool) -> void:
	var hw: float = roundf(w * 0.5)
	var a_hi: float = 0.68 * pulse
	match _island_id:
		1: # Great Belfry: twin choir columns + golden bell-gable arch
			draw_line(c + Vector2(-hw, 6.0), c + Vector2(-hw, -7.0), Color(col_g, a_hi), 2.0)
			draw_line(c + Vector2(hw, 6.0), c + Vector2(hw, -7.0), Color(col_g, a_hi), 2.0)
			draw_arc(c + Vector2(0.0, -7.0), hw, PI, TAU, 14, Color(col_g, a_hi), 2.0)
			draw_rect(Rect2(c + Vector2(-1.0, -hw - 6.0), Vector2(2.0, 2.0)), Color(cream, a_hi))
		2: # The Lighthouse: curved lantern cupola + sweeping sea-ice glint
			draw_arc(c + Vector2(0.0, -4.0), hw, PI, TAU, 14, Color(PAL["ice"] as Color, a_hi), 2.0)
			var glint_x: float = roundf(c.x + (0.0 if fred else sin(_clock * 1.9) * (hw - 4.0)))
			draw_line(Vector2(glint_x, c.y - 6.0), Vector2(glint_x, c.y + 5.0), Color(PAL["ice"] as Color, 0.35 * pulse), 2.0)
		3: # Hollow Oak: intertwined pine/jade root-arch with lime canopy buds
			draw_arc(c + Vector2(0.0, -4.0), hw + 1.0, PI, TAU, 14, Color(PAL["jade"] as Color, a_hi), 2.0)
			for side3: float in [-1.0, 1.0]:
				draw_line(c + Vector2(side3 * hw, 6.0), c + Vector2(side3 * (hw + 3.0), 8.0), Color(PAL["pine"] as Color, a_hi), 2.0)
				draw_rect(Rect2(c + Vector2(side3 * (hw - 3.0), -10.0), Vector2(2.0, 2.0)), Color(PAL["lime"] as Color, a_hi))
		4: # Sunken Conservatory: pointed glasshouse gable + rose/ice transoms
			draw_line(c + Vector2(-hw, -5.0), c + Vector2(0.0, -14.0), Color(PAL["teal"] as Color, a_hi), 2.0)
			draw_line(c + Vector2(hw, -5.0), c + Vector2(0.0, -14.0), Color(PAL["teal"] as Color, a_hi), 2.0)
			draw_rect(Rect2(c + Vector2(-4.0, -10.0), Vector2(3.0, 3.0)), Color(PAL["rose"] as Color, 0.55 * pulse))
			draw_rect(Rect2(c + Vector2(1.0, -10.0), Vector2(3.0, 3.0)), Color(PAL["ice"] as Color, 0.55 * pulse))
		5: # Grand Orrery: brass zodiac ring with rotating cardinal ticks
			var rot5: float = 0.0 if fred else _clock * 0.7
			draw_arc(c, hw + 1.0, 0.0, TAU, 20, Color(PAL["gold"] as Color, 0.45 * pulse), 1.0)
			for t5: int in range(4):
				var ang5: float = rot5 + float(t5) * (PI * 0.5)
				var pt5: Vector2 = (c + Vector2.from_angle(ang5) * (hw + 1.0)).round()
				draw_rect(Rect2(pt5 - Vector2.ONE, Vector2(2.0, 2.0)), Color(cream if t5 % 2 == 0 else PAL["sky"] as Color, a_hi))
		6: # Great Kiln: stepped volcanic furnace lintel with glowing coral/gold vents
			draw_rect(Rect2(c + Vector2(-hw - 2.0, -9.0), Vector2(w + 4.0, 3.0)), Color(PAL["wine"] as Color, 0.65 * pulse))
			for vx: float in [-8.0, 0.0, 8.0]:
				draw_rect(Rect2(c + Vector2(vx - 1.0, -8.0), Vector2(2.0, 2.0)), Color(PAL["gold"] as Color if not fred else PAL["coral"] as Color, a_hi))
		7: # Moon Spire: twin silver crescent gateposts + lunar center seam
			draw_arc(c + Vector2(-hw - 1.0, 0.0), 6.0, -PI * 0.55, PI * 0.55, 8, Color(PAL["ice"] as Color, a_hi), 2.0)
			draw_arc(c + Vector2(hw + 1.0, 0.0), 6.0, PI * 0.45, PI * 1.55, 8, Color(PAL["ice"] as Color, a_hi), 2.0)
			draw_line(c + Vector2(0.0, -11.0), c + Vector2(0.0, 7.0), Color(PAL["sky"] as Color, 0.35 * pulse), 1.0)
		_: # Bell Sanctum: tall gothic rose-gold cathedral arch + radiant dawn keystone
			draw_line(c + Vector2(-hw, 6.0), c + Vector2(-hw, -8.0), Color(PAL["plum"] as Color, a_hi), 2.0)
			draw_line(c + Vector2(hw, 6.0), c + Vector2(hw, -8.0), Color(PAL["plum"] as Color, a_hi), 2.0)
			draw_line(c + Vector2(-hw, -8.0), c + Vector2(0.0, -16.0), Color(col_g, a_hi), 2.0)
			draw_line(c + Vector2(hw, -8.0), c + Vector2(0.0, -16.0), Color(col_g, a_hi), 2.0)
			draw_circle(c + Vector2(0.0, -14.0), 2.5, Color(cream, a_hi))


func _draw_room_threshold(r: Rect2, c: Vector2, col_g: Color, cream: Color, pulse: float, wp: Vector2) -> void:
	var prox: float = clampf(1.0 - c.distance_to(wp) / 96.0, 0.0, 1.0)
	var spill_a: float = clampf((0.12 + prox * 0.10) * pulse, 0.06, 0.24)
	var sconce_a: float = clampf((0.52 + prox * 0.34) * pulse, 0.32, 0.90)
	var b_center: Vector2 = _cam_center
	if _region != null and is_instance_valid(_region) and _region.get("bounds") is Rect2:
		b_center = (_region.get("bounds") as Rect2).get_center()
	var spill_c: Color = (PAL["apricot"] as Color) if _island_id in [1, 6, 8] else col_g
	var horiz: bool = r.size.x >= r.size.y
	if horiz:
		var span: float = clampf(r.size.x - 4.0, 12.0, 28.0)
		var half_s: float = floorf(span * 0.5)
		var in_y: float = 1.0 if c.y < b_center.y else -1.0
		var sill_y: float = roundf(c.y + in_y * (r.size.y * 0.5 - 2.0))
		# Soft 3-step warm floor light-spill tapering gently into the room
		draw_rect(Rect2(roundf(c.x - half_s + 1.0), sill_y, span - 2.0, 2.0), Color(spill_c, spill_a * 1.15))
		draw_rect(Rect2(roundf(c.x - half_s + 3.0), sill_y + in_y * 2.0, maxf(4.0, span - 6.0), 3.0), Color(spill_c, spill_a * 0.68))
		draw_rect(Rect2(roundf(c.x - half_s + 5.0), sill_y + in_y * 5.0, maxf(2.0, span - 10.0), 3.0), Color(col_g, spill_a * 0.32))
		# Tiny recessed doorframe sconce glints flanking the opening
		for side: float in [-1.0, 1.0]:
			var sx: float = roundf(c.x + side * (half_s + 2.0))
			draw_rect(Rect2(sx - 1.0, sill_y - 1.0, 2.0, 2.0), Color(PAL["night"] as Color, 0.72))
			draw_rect(Rect2(sx, sill_y, 1.0, 1.0), Color(cream if prox > 0.35 else col_g, sconce_a))
	else:
		var span_v: float = clampf(r.size.y - 4.0, 12.0, 28.0)
		var half_v: float = floorf(span_v * 0.5)
		var in_x: float = 1.0 if c.x < b_center.x else -1.0
		var sill_x: float = roundf(c.x + in_x * (r.size.x * 0.5 - 2.0))
		draw_rect(Rect2(sill_x, roundf(c.y - half_v + 1.0), 2.0, span_v - 2.0), Color(spill_c, spill_a * 1.15))
		draw_rect(Rect2(sill_x + in_x * 2.0, roundf(c.y - half_v + 3.0), 3.0, maxf(4.0, span_v - 6.0)), Color(spill_c, spill_a * 0.68))
		draw_rect(Rect2(sill_x + in_x * 5.0, roundf(c.y - half_v + 5.0), 3.0, maxf(2.0, span_v - 10.0)), Color(col_g, spill_a * 0.32))
		for side: float in [-1.0, 1.0]:
			var sy: float = roundf(c.y + side * (half_v + 2.0))
			draw_rect(Rect2(sill_x - 1.0, sy - 1.0, 2.0, 2.0), Color(PAL["night"] as Color, 0.72))
			draw_rect(Rect2(sill_x, sy, 1.0, 1.0), Color(cream if prox > 0.35 else col_g, sconce_a))
