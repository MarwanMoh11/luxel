class_name LxDungeonStoryFx
extends RefCounted
## 8 Bespoke Reactive Environmental Micro-Toys tucked along dungeon gallery walls (Dungeons 1..8).
## Purely atmospheric & tactile (zero blocking collision, strictly 20 Last Light colours, Flash-Reduction safe).

const PAL: Dictionary = LxPalette.PAL

var _rules: LxBiomeRules = null
var _island_id: int = 1
var _room_idx: int = 1
var _active: bool = false
var _clock: float = 0.0
var _sfx_cd: float = 0.0
var _toys: Array[Dictionary] = [] # {pos, phase, swing_t, cd, dir}
var _motes: Array[Dictionary] = [] # {pos, vel, age, dur, col}


func configure(rules: LxBiomeRules, room_idx: int, rid: String) -> void:
	_rules = rules
	_toys.clear()
	_motes.clear()
	_clock = 0.0
	_sfx_cd = 0.0
	_island_id = rules.island_id if rules != null else 1
	_room_idx = clampi(room_idx, 1, 10)
	_active = rules != null and rules.is_dungeon and not LxBiomeBossSynergy.BOSS_REGIONS.has(rid)
	if not _active:
		return
	var b: Rect2 = rules.bounds
	if b.size.x < 128.0 or b.size.y < 96.0:
		return
	var cx: float = b.get_center().x
	var cy: float = b.get_center().y
	var top_y: float = b.position.y + 24.0
	var span_x: float = minf(84.0, maxf(36.0, b.size.x * 0.28))
	var pts: Array[Vector2]
	if _island_id in [2, 6, 7]: # Flanking gallery alcoves (portholes, forge chains, floating mirrors)
		pts = [
			Vector2(b.position.x + 28.0, cy - 22.0).round(),
			Vector2(b.end.x - 28.0, cy + 22.0).round(),
		]
	elif _island_id == 4: # Conservatory stained-glass floor kaleidoscopes
		pts = [
			Vector2(cx - span_x * 0.72, cy).round(),
			Vector2(cx + span_x * 0.72, cy).round(),
		]
	else: # Upper choir arches / ceiling vines / pendulums / floating bell-shards
		pts = [
			Vector2(cx - span_x, top_y).round(),
			Vector2(cx + span_x, top_y).round(),
		]
	for i: int in range(pts.size()):
		_toys.append({
			"pos": pts[i],
			"phase": float(i) * 2.1 + float(_room_idx) * 0.7,
			"swing_t": 0.0,
			"cd": 0.0,
			"dir": 1.0 if i == 0 else -1.0,
		})


func tick(dt: float, w: LxWick) -> void:
	if not _active or dt <= 0.0:
		return
	_clock += dt
	_sfx_cd = maxf(0.0, _sfx_cd - dt)
	for i: int in range(_motes.size() - 1, -1, -1):
		var m: Dictionary = _motes[i]
		m["age"] = float(m["age"]) + dt
		m["pos"] = (m["pos"] as Vector2) + (m["vel"] as Vector2) * dt
		if float(m["age"]) >= float(m["dur"]):
			_motes.remove_at(i)
	var wp: Vector2 = w.global_position if (w != null and not w.dead) else Vector2(-9999.0, -9999.0)
	var fast: bool = w != null and not w.dead and (w.is_dashing() or w.is_gliding() or w.velocity.length_squared() > 900.0)
	var lp: Vector2 = w.lantern.pos if (w != null and w.lantern != null and is_instance_valid(w.lantern) and w.lantern.is_out()) else Vector2(-9999.0, -9999.0)
	for toy: Dictionary in _toys:
		toy["cd"] = maxf(0.0, float(toy["cd"]) - dt)
		toy["swing_t"] = maxf(0.0, float(toy["swing_t"]) - dt)
		if float(toy["cd"]) > 0.0:
			continue
		var tp: Vector2 = toy["pos"] as Vector2
		if (fast and wp.distance_to(tp) <= 24.0) or lp.distance_to(tp) <= 22.0:
			_trigger(toy, signf(tp.x - wp.x) if wp.x > -9000.0 else 1.0, w)


func try_hit_segment(from_p: Vector2, to_p: Vector2, w: LxWick = null) -> void:
	if not _active:
		return
	for toy: Dictionary in _toys:
		if float(toy["cd"]) > 0.0:
			continue
		var tp: Vector2 = toy["pos"] as Vector2
		if Geometry2D.get_closest_point_to_segment(tp, from_p, to_p).distance_to(tp) <= 15.0:
			_trigger(toy, signf(to_p.x - from_p.x), w)
			return


func _trigger(toy: Dictionary, push_dir: float, w: LxWick = null) -> void:
	var tp: Vector2 = toy["pos"] as Vector2
	toy["cd"] = 3.8
	toy["swing_t"] = 0.85
	toy["dir"] = push_dir if absf(push_dir) > 0.1 else 1.0
	var wick: LxWick = w if (w != null and is_instance_valid(w)) else (Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null)
	var bm: LxBiomeMechanics = LxBiomeMechanics.active_instance
	var burst_r: float = 52.0
	match _island_id:
		1:
			if wick != null and not wick.dead and wick.move_sunflare != null and wick.move_sunflare.unlocked:
				wick.ember = minf(wick.move_sunflare.get_ember_max(), wick.ember + 2.0)
		2:
			if _rules != null and is_instance_valid(_rules):
				_rules.beam_buff_t = maxf(_rules.beam_buff_t, 1.2)
		3:
			burst_r = 68.0
			if wick != null and not wick.dead and wick.move_sunflare != null and wick.move_sunflare.unlocked:
				wick.ember = minf(wick.move_sunflare.get_ember_max(), wick.ember + 3.0)
		4:
			if bm != null and is_instance_valid(bm):
				bm.tailwind_t = maxf(bm.tailwind_t, 1.2)
		5:
			if _rules != null and is_instance_valid(_rules):
				_rules.starlight_surge_t = maxf(_rules.starlight_surge_t, 1.4)
		6:
			if bm != null and is_instance_valid(bm) and bm.molten_charges <= 0:
				bm.grant_molten_overdrive(1)
		7:
			burst_r = 74.0
			if _rules != null and is_instance_valid(_rules):
				_rules.lunar_phase = clampf(_rules.lunar_phase + 0.16, 0.0, 1.0)
		8:
			burst_r = 78.0
			if wick != null and not wick.dead and wick.move_sunflare != null and wick.move_sunflare.unlocked:
				wick.ember = minf(wick.move_sunflare.get_ember_max(), wick.ember + 5.0)
	var k_glow: String = LxBiomePalette.key(_island_id, "glow")
	var k_hi: String = LxBiomePalette.key(_island_id, "hi")
	for k: int in range(5):
		var ang: float = float(k) * (TAU / 5.0) + _clock * 0.5
		var vy: float = -18.0 if _island_id in [3, 6, 8] else (10.0 + sin(ang) * 14.0)
		_motes.append({
			"pos": tp,
			"vel": Vector2(cos(ang) * 20.0 + float(toy["dir"]) * 8.0, vy),
			"age": 0.0,
			"dur": 0.45,
			"col": "cream" if k == 0 else (k_glow if k % 2 == 0 else k_hi),
		})
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(tp, burst_r, 0.58 if LxHudFx.flash_reduced() else 0.90, 0.34)
	if _sfx_cd <= 0.0 and Lx.audio != null:
		_sfx_cd = 0.65
		var sfx_id: String = "prop_chime"
		match _island_id:
			2: sfx_id = "footstep_water"
			3: sfx_id = "prop_rustle"
			5: sfx_id = "clockwork_chime"
			6: sfx_id = "forge_gust"
			7: sfx_id = "lens_reveal"
		Lx.audio.play_sfx(sfx_id, tp, true)


func draw_toys(canvas: CanvasItem, rules: LxBiomeRules, fred: bool) -> void:
	if not _active or rules == null:
		return
	var a_base: float = 0.48 if fred else 0.72
	for toy: Dictionary in _toys:
		var p: Vector2 = (toy["pos"] as Vector2).round()
		var ph: float = float(toy["phase"])
		var sw_t: float = float(toy["swing_t"])
		var sw: float = (0.0 if fred else sin(_clock * 1.8 + ph) * 1.5) + (sin(sw_t * 18.0) * 4.5 * (sw_t / 0.85) * float(toy["dir"]) if sw_t > 0.0 else 0.0)
		var sw_r: float = roundf(sw)
		match _island_id:
			1: # Hanging brass bell-clapper
				canvas.draw_line(p + Vector2(0.0, -8.0), p + Vector2(sw_r, 2.0), Color(PAL["stone"] as Color, a_base), 1.0)
				canvas.draw_rect(Rect2(p + Vector2(sw_r - 2.0, 1.0), Vector2(5.0, 3.0)), Color(PAL["gold"] as Color, a_base))
				canvas.draw_rect(Rect2(p + Vector2(sw_r, 4.0), Vector2.ONE), PAL["cream"] as Color)
			2: # Harbor porthole sea-spray vent
				canvas.draw_arc(p, 5.0, 0.0, TAU, 10, Color(PAL["sky"] as Color, a_base), 1.2)
				canvas.draw_circle(p, 3.0, Color(PAL["deep"] as Color, a_base * 0.8))
				canvas.draw_rect(Rect2(p + Vector2(-1.0 + clampf(sw_r, -1.0, 1.0), -1.0), Vector2(2.0, 1.0)), Color(PAL["ice"] as Color, a_base))
			3: # Swaying bioluminescent vine-lantern
				canvas.draw_line(p + Vector2(0.0, -9.0), p + Vector2(sw_r, 2.0), Color(PAL["pine"] as Color, a_base * 1.1), 1.4)
				canvas.draw_circle(p + Vector2(sw_r, 3.0), 2.5, Color(PAL["jade"] as Color, a_base))
				canvas.draw_rect(Rect2(p + Vector2(sw_r, 2.0), Vector2.ONE), PAL["lime"] as Color)
			4: # Stained-glass floor kaleidoscope diamond
				var d4 := PackedVector2Array([p + Vector2(0.0, -6.0), p + Vector2(6.0, 0.0), p + Vector2(0.0, 6.0), p + Vector2(-6.0, 0.0)])
				canvas.draw_colored_polygon(d4, Color((PAL["rose"] if sw_t > 0.0 else PAL["ice"]) as Color, 0.22 if fred else 0.34))
				canvas.draw_polyline(PackedVector2Array([d4[0], d4[1], d4[2], d4[3], d4[0]]), Color(PAL["gold"] as Color, a_base * 0.7), 1.0)
			5: # Rhythmic brass astrolabe pendulum
				var p_ang: float = sin(_clock * 2.6 + ph) * 0.45 + (sw_t * 0.6 * float(toy["dir"]))
				var bob: Vector2 = (p + Vector2(sin(p_ang) * 9.0, cos(p_ang) * 9.0)).round()
				canvas.draw_line(p + Vector2(0.0, -4.0), bob, Color(PAL["gold"] as Color, a_base), 1.0)
				canvas.draw_circle(bob, 2.0, Color(PAL["sky"] as Color, a_base))
				canvas.draw_rect(Rect2(bob, Vector2.ONE), PAL["cream"] as Color)
			6: # Hanging forge chain & glowing slag-brazier
				canvas.draw_line(p + Vector2(0.0, -8.0), p + Vector2(sw_r * 0.5, 2.0), Color(PAL["dusk"] as Color, a_base), 1.4)
				canvas.draw_rect(Rect2(p + Vector2(-2.0, 2.0), Vector2(5.0, 3.0)), Color(PAL["wine"] as Color, a_base))
				canvas.draw_rect(Rect2(p + Vector2(-1.0, 1.0), Vector2(3.0, 2.0)), Color((PAL["gold"] if sw_t > 0.0 else PAL["coral"]) as Color, a_base))
			7: # Floating silver mirror shard reflecting lunar_phase
				var bob7: float = 0.0 if fred else roundf(sin(_clock * 1.9 + ph) * 2.0)
				var m7 := PackedVector2Array([p + Vector2(0.0, -5.0 + bob7), p + Vector2(3.0, bob7), p + Vector2(0.0, 5.0 + bob7), p + Vector2(-3.0, bob7)])
				canvas.draw_colored_polygon(m7, Color(PAL["ice"] as Color, a_base * (0.55 + 0.45 * rules.lunar_phase)))
				canvas.draw_rect(Rect2(p + Vector2(0.0, -1.0 + bob7), Vector2.ONE), PAL["cream"] as Color)
			_: # D8 Bell Sanctum: levitating shattered bell-fragment brightening r1 -> r6
				var bob8: float = 0.0 if fred else roundf(sin(_clock * 1.6 + ph) * 2.5)
				var c8: Color = (PAL["cream"] if _room_idx >= 5 else (PAL["gold"] if _room_idx >= 3 else PAL["rose"])) as Color
				canvas.draw_rect(Rect2(p + Vector2(-2.0 + sw_r * 0.4, -2.0 + bob8), Vector2(4.0, 4.0)), Color(PAL["plum"] as Color, a_base))
				canvas.draw_rect(Rect2(p + Vector2(-1.0 + sw_r * 0.4, -1.0 + bob8), Vector2(2.0, 2.0)), Color(c8, a_base * 1.15))
		if sw_t > 0.0:
			var su: float = 1.0 - clampf(sw_t / 0.85, 0.0, 1.0)
			canvas.draw_arc(p, roundf(lerpf(4.0, 22.0, su)), 0.0, TAU, 14, Color(LxBiomePalette.col(_island_id, "glow"), (1.0 - su) * a_base), 1.0)
	for m: Dictionary in _motes:
		var u: float = clampf(float(m["age"]) / maxf(float(m["dur"]), 0.01), 0.0, 1.0)
		var mp: Vector2 = (m["pos"] as Vector2).round()
		canvas.draw_rect(Rect2(mp, Vector2.ONE), Color(PAL[str(m["col"])] as Color, (1.0 - u) * 0.85))
