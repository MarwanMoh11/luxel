class_name LxFireflyWorldContent
extends Node2D
## Manages all 24 Firefly Nectar Blooms (3 per island 1..8), all 8 Pollen Bell Relay Trials,
## and the Wick House Hub Pip Sanctuary Terrarium (0:overworld).
## Strictly 20 Last Light colours (LxPalette.PAL) and integer pixel-snapped drawing.

static var active_instance: LxFireflyWorldContent = null

const TERRARIUM_POS: Vector2 = Vector2(232.0, 184.0)
const FIRST_BLOOM_POS: Vector2 = Vector2(616.0, 344.0)

const PERCH_SPECS: Dictionary = {
	"1:belfry_r2": {"id": "perch_1_belfry_r2", "pos": Vector2(232.0, 120.0)},
	"1:belfry_r4": {"id": "perch_1_belfry_r4", "pos": Vector2(184.0, 104.0)},
	"2:galleon_r3": {"id": "perch_2_galleon_r3", "pos": Vector2(280.0, 232.0)},
	"2:galleon_r8": {"id": "perch_2_galleon_r8", "pos": Vector2(264.0, 152.0)},
	"3:loom_r3": {"id": "perch_3_loom_r3", "pos": Vector2(216.0, 168.0)},
	"3:loom_r8": {"id": "perch_3_loom_r8", "pos": Vector2(200.0, 136.0)},
	"4:hourglass_r3": {"id": "perch_4_hourglass_r3", "pos": Vector2(72.0, 120.0)},
	"4:hourglass_r8": {"id": "perch_4_hourglass_r8", "pos": Vector2(88.0, 88.0)},
	"5:orrery_r3": {"id": "perch_5_orrery_r3", "pos": Vector2(216.0, 88.0)},
	"5:orrery_r8": {"id": "perch_5_orrery_r8", "pos": Vector2(216.0, 56.0)},
	"6:kiln_r3": {"id": "perch_6_kiln_r3", "pos": Vector2(216.0, 168.0)},
	"6:kiln_r8": {"id": "perch_6_kiln_r8", "pos": Vector2(216.0, 88.0)},
	"7:palace_r3": {"id": "perch_7_palace_r3", "pos": Vector2(72.0, 248.0)},
	"7:palace_r8": {"id": "perch_7_palace_r8", "pos": Vector2(216.0, 168.0)},
	"8:sanctum_r2": {"id": "perch_8_sanctum_r2", "pos": Vector2(136.0, 120.0)},
	"8:sanctum_r4": {"id": "perch_8_sanctum_r4", "pos": Vector2(152.0, 120.0)},
}

const BLOOMS_BY_ISLAND: Dictionary = {
	1: [
		{"id": "bloom_1_plaza", "pos": Vector2(616.0, 344.0)},
		{"id": "bloom_1_obs", "pos": Vector2(216.0, 504.0)},
		{"id": "bloom_1_river", "pos": Vector2(1016.0, 344.0)},
	],
	2: [
		{"id": "bloom_2_harbor", "pos": Vector2(168.0, 360.0)},
		{"id": "bloom_2_quays", "pos": Vector2(264.0, 120.0)},
		{"id": "bloom_2_reef", "pos": Vector2(888.0, 472.0)},
	],
	3: [
		{"id": "bloom_3_trail", "pos": Vector2(280.0, 888.0)},
		{"id": "bloom_3_spore", "pos": Vector2(184.0, 616.0)},
		{"id": "bloom_3_canopy", "pos": Vector2(216.0, 376.0)},
	],
	4: [
		{"id": "bloom_4_fen", "pos": Vector2(280.0, 648.0)},
		{"id": "bloom_4_sunken", "pos": Vector2(216.0, 248.0)},
		{"id": "bloom_4_pier", "pos": Vector2(1000.0, 232.0)},
	],
	5: [
		{"id": "bloom_5_landing", "pos": Vector2(248.0, 632.0)},
		{"id": "bloom_5_brass", "pos": Vector2(392.0, 184.0)},
		{"id": "bloom_5_zenith", "pos": Vector2(936.0, 808.0)},
	],
	6: [
		{"id": "bloom_6_landing", "pos": Vector2(216.0, 280.0)},
		{"id": "bloom_6_ash", "pos": Vector2(408.0, 136.0)},
		{"id": "bloom_6_approach", "pos": Vector2(1320.0, 264.0)},
	],
	7: [
		{"id": "bloom_7_landing", "pos": Vector2(200.0, 392.0)},
		{"id": "bloom_7_basin", "pos": Vector2(264.0, 632.0)},
		{"id": "bloom_7_spire", "pos": Vector2(712.0, 312.0)},
	],
	8: [
		{"id": "bloom_8_hub", "pos": Vector2(456.0, 1096.0)},
		{"id": "bloom_8_tide", "pos": Vector2(376.0, 808.0)},
		{"id": "bloom_8_kiln", "pos": Vector2(408.0, 136.0)},
	],
}

const RELAYS_BY_ISLAND: Dictionary = {
	1: {"id": "relay_1_glasshouse", "island": 1, "bells": [Vector2(632.0, 584.0), Vector2(712.0, 584.0), Vector2(672.0, 648.0)], "cache_pos": Vector2(672.0, 616.0)},
	2: {"id": "relay_2_lighthouse", "island": 2, "bells": [Vector2(968.0, 232.0), Vector2(1048.0, 232.0), Vector2(1064.0, 152.0)], "cache_pos": Vector2(1016.0, 200.0)},
	3: {"id": "relay_3_briar", "island": 3, "bells": [Vector2(440.0, 616.0), Vector2(536.0, 600.0), Vector2(520.0, 680.0)], "cache_pos": Vector2(496.0, 632.0)},
	4: {"id": "relay_4_glass", "island": 4, "bells": [Vector2(520.0, 616.0), Vector2(600.0, 632.0), Vector2(600.0, 728.0)], "cache_pos": Vector2(568.0, 672.0)},
	5: {"id": "relay_5_orrery", "island": 5, "bells": [Vector2(520.0, 600.0), Vector2(584.0, 552.0), Vector2(536.0, 488.0)], "cache_pos": Vector2(552.0, 544.0)},
	6: {"id": "relay_6_cinder", "island": 6, "bells": [Vector2(808.0, 376.0), Vector2(872.0, 424.0), Vector2(952.0, 408.0)], "cache_pos": Vector2(880.0, 392.0)},
	7: {"id": "relay_7_court", "island": 7, "bells": [Vector2(1032.0, 376.0), Vector2(1128.0, 424.0), Vector2(1128.0, 504.0)], "cache_pos": Vector2(1088.0, 440.0)},
	8: {"id": "relay_8_mire", "island": 8, "bells": [Vector2(392.0, 632.0), Vector2(424.0, 552.0), Vector2(504.0, 552.0)], "cache_pos": Vector2(448.0, 592.0)},
}

var current_island_id: int = -1
var current_region_id: String = ""
var has_terrarium: bool = false

var _blooms: Array[LxFireflyBloom] = []
var _relays: Array[LxPollenRelay] = []
var _perches: Array[LxFireflyPerch] = []
var _sanctuary_active: bool = false
var _last_player_pos: Vector2 = Vector2.INF
var _guide_drawn: bool = false
var _clock: float = 0.0
var _terrarium_cd: float = 0.0
var _terrarium_flash_t: float = 0.0


func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	active_instance = self


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null


func setup_for_region(island_id: int, region_id: String, _region_loader: Node) -> void:
	active_instance = self
	clear_content()
	current_island_id = island_id
	current_region_id = region_id
	has_terrarium = (island_id == 0 and region_id == "overworld")
	if region_id == "overworld" and BLOOMS_BY_ISLAND.has(island_id):
		var b_specs: Array = BLOOMS_BY_ISLAND[island_id] as Array
		for spec_v: Variant in b_specs:
			if spec_v is Dictionary:
				var sd: Dictionary = spec_v as Dictionary
				var bloom := LxFireflyBloom.new()
				add_child(bloom)
				bloom.setup(str(sd["id"]), sd["pos"] as Vector2, island_id)
				_blooms.append(bloom)
	if region_id == "overworld" and RELAYS_BY_ISLAND.has(island_id):
		var r_spec: Dictionary = RELAYS_BY_ISLAND[island_id] as Dictionary
		var relay := LxPollenRelay.new()
		add_child(relay)
		relay.setup(r_spec)
		_relays.append(relay)
	var p_key: String = "%d:%s" % [island_id, region_id]
	if PERCH_SPECS.has(p_key):
		var pd: Dictionary = PERCH_SPECS[p_key] as Dictionary
		var perch := LxFireflyPerch.new()
		add_child(perch)
		perch.setup(str(pd["id"]), pd["pos"] as Vector2, island_id)
		_perches.append(perch)
	queue_redraw()


func clear_content() -> void:
	for b: LxFireflyBloom in _blooms:
		if is_instance_valid(b):
			b.queue_free()
	_blooms.clear()
	for r: LxPollenRelay in _relays:
		if is_instance_valid(r):
			r.queue_free()
	_relays.clear()
	for p: LxFireflyPerch in _perches:
		if is_instance_valid(p):
			p.queue_free()
	_perches.clear()
	_sanctuary_active = false
	_last_player_pos = Vector2.INF
	_guide_drawn = false
	has_terrarium = false
	_terrarium_cd = 0.0
	_terrarium_flash_t = 0.0
	queue_redraw()


func tick(dt: float, player_pos: Vector2) -> void:
	_clock += dt
	_last_player_pos = player_pos
	_terrarium_cd = maxf(0.0, _terrarium_cd - dt)
	_terrarium_flash_t = maxf(0.0, _terrarium_flash_t - dt)
	for b: LxFireflyBloom in _blooms:
		if is_instance_valid(b):
			b.tick(dt, player_pos)
	for r: LxPollenRelay in _relays:
		if is_instance_valid(r):
			r.tick(dt, player_pos)
	var pip_pos: Vector2 = Vector2.INF
	var pip_perched: bool = false
	if Lx.companion != null and is_instance_valid(Lx.companion):
		var pv: Variant = Lx.companion.get("pos")
		if pv is Vector2:
			pip_pos = pv as Vector2
		if Lx.companion.has_method("is_perched"):
			pip_perched = bool(Lx.companion.call("is_perched"))
	var any_hold: bool = false
	for p: LxFireflyPerch in _perches:
		if is_instance_valid(p) and p.tick(dt, pip_pos, pip_perched):
			any_hold = true
	_sanctuary_active = any_hold
	if has_terrarium or _guide_drawn or _should_draw_first_use_guide():
		queue_redraw()


func is_sanctuary_buff_active() -> bool:
	return _sanctuary_active


func on_pip_pass(pip_pos: Vector2, prev_pos: Vector2, radius: float, pip: Node) -> bool:
	var triggered: bool = false
	for b: LxFireflyBloom in _blooms:
		if not is_instance_valid(b) or b.collected:
			continue
		if Geometry2D.get_closest_point_to_segment(b.pos, prev_pos, pip_pos).distance_to(b.pos) <= radius + LxFireflyBloom.RADIUS:
			if b.try_pollinate(true):
				triggered = true
	for r: LxPollenRelay in _relays:
		if not is_instance_valid(r) or r.completed:
			continue
		if r.on_pip_pass(pip_pos, prev_pos, radius):
			triggered = true
	for p: LxFireflyPerch in _perches:
		if not is_instance_valid(p) or p.lit:
			continue
		if Geometry2D.get_closest_point_to_segment(p.pos, prev_pos, pip_pos).distance_to(p.pos) <= radius + LxFireflyPerch.RADIUS:
			if p.try_ignite(pip):
				triggered = true
	if has_terrarium and _terrarium_cd <= 0.0:
		if Geometry2D.get_closest_point_to_segment(TERRARIUM_POS, prev_pos, pip_pos).distance_to(TERRARIUM_POS) <= radius + 12.0:
			_cycle_terrarium_tint()
			triggered = true
	return triggered


func try_interact(_actor: Node, actor_pos: Vector2, reach: float = 24.0) -> bool:
	if not has_terrarium:
		return false
	if actor_pos.distance_to(TERRARIUM_POS) <= reach + 10.0:
		_cycle_terrarium_tint()
		return true
	return false


func get_interact_prompt_near(actor_pos: Vector2, reach: float = 24.0) -> String:
	if has_terrarium and actor_pos.distance_to(TERRARIUM_POS) <= reach + 10.0:
		return "PIP_TERRARIUM_PROMPT"
	return ""


func find_nearest_sense_target(from_pos: Vector2, max_dist: float) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = max_dist
	for b: LxFireflyBloom in _blooms:
		if not is_instance_valid(b) or b.collected:
			continue
		var d: float = from_pos.distance_to(b.pos)
		if d < best_d:
			best_d = d
			best = b.pos
	for r: LxPollenRelay in _relays:
		if not is_instance_valid(r) or r.completed:
			continue
		var bp: Vector2 = r.find_nearest_active_bell(from_pos, best_d)
		if bp.is_finite():
			var dr: float = from_pos.distance_to(bp)
			if dr < best_d:
				best_d = dr
				best = bp
	for p: LxFireflyPerch in _perches:
		if not is_instance_valid(p) or p.lit:
			continue
		var dp: float = from_pos.distance_to(p.pos)
		if dp < best_d:
			best_d = dp
			best = p.pos
	return best


func get_light_pools() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for b: LxFireflyBloom in _blooms:
		if is_instance_valid(b):
			out.append(b.get_light_pool())
	for r: LxPollenRelay in _relays:
		if is_instance_valid(r):
			for p: Vector4 in r.get_light_pools():
				out.append(p)
	for perch: LxFireflyPerch in _perches:
		if is_instance_valid(perch):
			out.append(perch.get_light_pool())
	if has_terrarium:
		out.append(Vector4(TERRARIUM_POS.x, TERRARIUM_POS.y - 6.0, 56.0, 0.92))
	return out


func _cycle_terrarium_tint() -> void:
	_terrarium_cd = 0.45
	_terrarium_flash_t = 0.55
	var next_tint: String = LxFireflyState.cycle_tint()
	var rank: int = LxFireflyState.get_bond_rank()
	var nectar: int = LxFireflyState.get_nectar_count()
	var label_key: String = LxFireflyState.get_tint_label_key(next_tint)
	var tint_label: String = LxStrings.text(label_key)
	var line: String = LxStrings.fmt("PIP_TERRARIUM_FMT", [rank, nectar, tint_label])
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_chirp", TERRARIUM_POS, true)
		Lx.events.save_requested.emit("pip_tint")
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(TERRARIUM_POS, 64.0, 0.85 if LxHudFx.flash_reduced() else 1.15, 0.36)
	var nar: Object = Lx.ui.get("narration") as Object if (Lx.ui != null and Lx.ui.get("narration") is Object) else null
	if nar != null and is_instance_valid(nar) and nar.has_method("say_lines"):
		nar.call("say_lines", PackedStringArray([line]), "narration", 3.2, -1.0, 1, "main")
	elif Lx.events != null:
		Lx.events.narration_requested.emit("PIP_TERRARIUM_PROMPT", "narration", 2.6)
	queue_redraw()


func _should_draw_first_use_guide() -> bool:
	if current_island_id != 1 or current_region_id != "overworld":
		return false
	if not LxFireflyState.is_joined():
		return false
	if Lx.state != null and bool(Lx.state.story_flags.get("pip_sent_once", false)):
		return false
	if LxFireflyState.is_bloom_collected("bloom_1_plaza"):
		return false
	if LxHudFx.is_ceremony_active():
		return false
	if Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open")):
		return false
	return true


func _draw() -> void:
	if has_terrarium:
		_draw_terrarium()
	if _should_draw_first_use_guide():
		_guide_drawn = true
		_draw_first_use_guide()
	else:
		_guide_drawn = false


func _draw_terrarium() -> void:
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var tint: Dictionary = LxFireflyState.get_tint_colors()
	var c_glow: Color = tint["glow"] as Color
	var c_core: Color = tint["core"] as Color
	var c_rim: Color = tint["rim"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var p: Vector2 = TERRARIUM_POS.round()

	# Pedestal shadow & void outline
	draw_rect(Rect2(p + Vector2(-7.0, -14.0), Vector2(14.0, 17.0)), void_c)
	# Carved timber & brass plinth
	draw_rect(Rect2(p + Vector2(-6.0, -3.0), Vector2(12.0, 5.0)), pal["dusk"] as Color)
	draw_rect(Rect2(p + Vector2(-5.0, -3.0), Vector2(10.0, 2.0)), pal["apricot"] as Color)
	draw_rect(Rect2(p + Vector2(-4.0, -3.0), Vector2(8.0, 1.0)), pal["gold"] as Color)
	# Glass jar dome
	draw_rect(Rect2(p + Vector2(-5.0, -12.0), Vector2(10.0, 9.0)), pal["night"] as Color)
	draw_rect(Rect2(p + Vector2(-4.0, -11.0), Vector2(8.0, 7.0)), pal["pine"] as Color)
	# Glass specular rim + brass cap
	draw_rect(Rect2(p + Vector2(-5.0, -11.0), Vector2(1.0, 7.0)), pal["sky"] as Color)
	draw_rect(Rect2(p + Vector2(4.0, -11.0), Vector2(1.0, 7.0)), pal["blue"] as Color)
	draw_rect(Rect2(p + Vector2(-4.0, -11.0), Vector2(1.0, 3.0)), pal["ice"] as Color)
	draw_rect(Rect2(p + Vector2(-4.0, -13.0), Vector2(8.0, 2.0)), pal["apricot"] as Color)
	draw_rect(Rect2(p + Vector2(-2.0, -14.0), Vector2(4.0, 1.0)), pal["gold"] as Color)
	# Moss bed inside jar
	draw_rect(Rect2(p + Vector2(-4.0, -5.0), Vector2(8.0, 1.0)), pal["jade"] as Color)
	draw_rect(Rect2(p + Vector2(-2.0, -6.0), Vector2(3.0, 1.0)), pal["lime"] as Color)
	# Fluttering nectar firefly specks inside and gently orbiting above the glass dome
	var speck_n: int = mini(24, LxFireflyState.get_nectar_count())
	var spd: float = 0.45 if fred else 1.95
	for i: int in range(speck_n):
		var a: float = _clock * spd + float(i) * 1.17
		var sc: Color = c_core if (i % 3 == 0) else (c_glow if (i % 3 == 1) else (pal["gold"] as Color))
		if i < 10:
			var fx: float = roundf(p.x + sin(a * 1.1 + float(i)) * 3.0)
			var fy: float = roundf(p.y - 8.0 + cos(a * 1.45 + float(i) * 0.7) * 2.5)
			draw_rect(Rect2(fx, fy, 1.0, 1.0), sc)
		else:
			var tier: float = float((i - 10) % 4)
			var rx: float = 7.0 + tier * 2.5
			var ry: float = 2.5 + float((i - 10) % 3) * 1.2
			var ox: float = roundf(p.x + cos(a * 0.85 + float(i) * 0.9) * rx)
			var oy: float = roundf(p.y - 16.0 - tier * 2.5 + sin(a * 1.25 + float(i)) * ry)
			draw_rect(Rect2(ox - 1.0, oy - 1.0, 3.0, 3.0), void_c)
			draw_rect(Rect2(ox, oy, 1.0, 1.0), sc)
	# Tint-cycle chime ring
	if _terrarium_flash_t > 0.0:
		var u: float = 1.0 - clampf(_terrarium_flash_t / 0.55, 0.0, 1.0)
		var r: float = roundf(lerpf(5.0, 20.0, u))
		draw_arc(p + Vector2(0.0, -8.0), r, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(p + Vector2(0.0, -8.0), r, 0.0, TAU, 16, c_glow if u < 0.6 else c_rim, 1.0)


func _draw_first_use_guide() -> void:
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var target: Vector2 = FIRST_BLOOM_POS + Vector2(0.0, -7.0)
	var origin: Vector2 = Vector2.INF
	if Lx.companion != null and is_instance_valid(Lx.companion):
		var pv: Variant = Lx.companion.get("pos")
		if pv is Vector2:
			origin = (pv as Vector2) + Vector2(0.0, -4.0)
	if not origin.is_finite() and _last_player_pos.is_finite():
		origin = _last_player_pos + Vector2(0.0, -6.0)
	if origin.is_finite():
		var dist: float = origin.distance_to(target)
		if dist >= 12.0 and dist <= 260.0:
			var ctrl: Vector2 = origin.lerp(target, 0.5) + Vector2(0.0, -14.0)
			var steps: int = clampi(int(roundf(dist / 9.0)), 4, 24)
			var phase: float = 0.0 if fred else fmod(_clock * 1.4, 1.0)
			for i: int in range(steps):
				var t: float = clampf((float(i) + phase) / float(steps), 0.05, 0.96)
				var mt: float = 1.0 - t
				var pt: Vector2 = (mt * mt * origin + 2.0 * mt * t * ctrl + t * t * target).round()
				draw_rect(Rect2(pt - Vector2.ONE, Vector2(3.0, 3.0)), void_c)
				draw_rect(Rect2(pt, Vector2.ONE), (pal["lime"] if (i % 2 == 0) else pal["gold"]) as Color)
	# Tiny void-backed keycap pill above bloom_1_plaza
	var glyph: String = Lx.input.get_glyph("lx_firefly") if Lx.input != null else "F"
	if glyph.is_empty() or glyph == "-":
		glyph = "F"
	var bob: float = 0.0 if fred else roundf(sin(_clock * 3.6) * 1.5)
	var tw: int = LxPixelFont.width(glyph, 1)
	var pw: float = float(maxi(10, tw + 6))
	var ph: float = 9.0
	var cx: float = roundf(FIRST_BLOOM_POS.x)
	var py: float = roundf(FIRST_BLOOM_POS.y - 26.0 + bob)
	var px: float = roundf(cx - pw * 0.5)
	draw_rect(Rect2(px - 1.0, py - 1.0, pw + 2.0, ph + 2.0), void_c)
	draw_rect(Rect2(px, py, pw, ph), pal["night"] as Color)
	draw_rect(Rect2(px, py, pw, 1.0), pal["lime"] as Color)
	draw_rect(Rect2(px, py + ph - 1.0, pw, 1.0), pal["gold"] as Color)
	LxPixelFont.draw_centered(self, glyph, cx, py + 2.0, pal["cream"] as Color, 1, void_c)
