class_name LxAmbientLife
extends Node2D
## Deterministic, pixel-snapped ambient life and reactive world-space combat/discovery VFX
## using strictly the 20 opaque Last Light palette colours (LxPalette.PAL).

const PAL: Dictionary = LxPalette.PAL
const VIEW_W: float = 340.0
const VIEW_H: float = 200.0
const HALF_W: float = 170.0
const HALF_H: float = 100.0
const MAX_PARTICLES: int = 28
const MAX_SPARKS: int = 80
const MAX_RINGS: int = 14
const MAX_PILLARS: int = 4

enum Kind { GLOW, FLAKE, TWINKLE, STREAK, MOTE, SHOOT }
enum Ramp { GOLD, ICE, STEEL, SHADOW, CORAL, HEAL }

const SPARK_RAMPS: Array = [
	["cream", "gold", "apricot", "coral"],
	["cream", "ice", "sky", "blue"],
	["cream", "ice", "stone", "mauve"],
	["plum", "dusk", "mauve", "night"],
	["cream", "rose", "coral", "wine"],
	["cream", "lime", "jade", "teal"],
]

class Particle:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var push: Vector2 = Vector2.ZERO
	var phase: float = 0.0
	var freq: float = 1.0
	var sway: float = 0.0
	var kind: int = 0
	var col: Color = LxPalette.PAL["cream"] as Color
	var col2: Color = LxPalette.PAL["cream"] as Color
	var size: float = 1.0

var _island_id: int = 1
var _is_dungeon: bool = false
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _items: Array[Particle] = []
var _sparks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _pillars: Array[Dictionary] = []
var _slashes: Array[Dictionary] = []
var _shard_orbs: Array[Dictionary] = []
var _vfx_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bound_events: LxEventBus = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5
	_vfx_rng.seed = 42421
	_sync_events()

func _exit_tree() -> void:
	_set_events(_bound_events, false)
	_bound_events = null

func _sync_events() -> void:
	if Lx.events == null or not is_instance_valid(Lx.events) or _bound_events == Lx.events:
		return
	_set_events(_bound_events, false)
	_bound_events = Lx.events
	_set_events(_bound_events, true)

func _set_events(ev: LxEventBus, bind: bool) -> void:
	if ev == null or not is_instance_valid(ev):
		return
	var pairs: Array = [
		[&"enemy_hit", _on_enemy_hit], [&"enemy_killed", _on_enemy_killed],
		[&"boss_phase_changed", _on_boss_phase_changed], [&"boss_defeated", _on_boss_defeated],
		[&"great_lamp_relit", _on_great_lamp_relit], [&"shrine_claimed", _on_shrine_claimed],
		[&"beacon_lit", _on_beacon_lit], [&"waystone_lit", _on_waystone_lit],
		[&"seal_broken", _on_seal_broken], [&"lantern_hung", _on_lantern_hung],
		[&"lantern_caught", _on_lantern_caught], [&"lantern_struck", _on_lantern_struck],
		[&"player_damaged", _on_player_damaged], [&"player_healed", _on_player_healed],
		[&"ember_piece_collected", _on_ember_piece], [&"upgrade_purchased", _on_upgrade_purchased],
		[&"shard_collected", _on_shard_collected],
	]
	for pair: Array in pairs:
		var sig: StringName = pair[0] as StringName
		var cb: Callable = pair[1] as Callable
		if bind and not ev.is_connected(sig, cb):
			ev.connect(sig, cb)
		elif not bind and ev.is_connected(sig, cb):
			ev.disconnect(sig, cb)

func configure(island_id: int, world_bounds: Rect2, is_dungeon: bool) -> void:
	if _bound_events != Lx.events:
		_sync_events()
	_island_id = clampi(island_id, 1, 8)
	_is_dungeon = is_dungeon
	_clock = 0.0
	_cam_center = world_bounds.get_center()
	_items.clear()
	_sparks.clear()
	_rings.clear()
	_pillars.clear()
	_slashes.clear()
	_shard_orbs.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = int(_island_id * 7919 + (131 if is_dungeon else 17) + int(world_bounds.size.x) * 31)
	_vfx_rng.seed = rng.seed ^ 0x5A17
	var d: bool = is_dungeon
	match _island_id:
		1: # Bell Isle: warm fireflies, petals, void stars
			_add_group(rng, 8 if d else 10, Kind.GLOW, "gold", "", "cream", -5.0, 5.0, -4.0, 2.0, 8.0, 1.6, 2.8)
			_add_group(rng, 4 if d else 8, Kind.FLAKE, "rose", "cream", "cream", 3.0, 7.0, 6.0, 12.0, 10.0, 1.2, 2.2)
			_add_group(rng, 6 if d else 8, Kind.TWINKLE, "ice", "", "cream", -1.5, 1.5, -1.0, 1.0, 1.5, 1.4, 2.6)
		2: # Tidewater Harbor: sea-spray motes & lantern sparkles
			_add_group(rng, 8 if d else 16, Kind.MOTE, "ice", "sky", "ice", 10.0, 22.0, -3.0, 3.0, 4.0, 1.4, 2.4, 1.0, 2.0)
			_add_group(rng, 8 if d else 10, Kind.TWINKLE, "gold", "", "cream", -2.0, 4.0, -6.0, -2.0, 5.0, 2.0, 3.4)
		3: # Thornwood Hollow: rising bioluminescent spores
			_add_group(rng, 10 if d else 14, Kind.GLOW, "jade", "", "lime", -3.0, 3.0, -11.0, -5.0, 9.0, 1.3, 2.4)
			_add_group(rng, 8 if d else 12, Kind.GLOW, "lime", "", "cream", -4.0, 4.0, -8.0, -3.0, 7.0, 1.8, 3.0)
		4: # Mirefen Gardens: mist-rain streaks & fireflies
			if d:
				_add_group(rng, 8, Kind.MOTE, "sky", "ice", "ice", -6.0, -2.0, 4.0, 9.0, 3.0, 1.2, 2.0)
			else:
				_add_group(rng, 14, Kind.STREAK, "sky", "ice", "ice", -24.0, -18.0, 58.0, 74.0, 0.0, 1.0, 1.0)
			_add_group(rng, 10 if d else 12, Kind.GLOW, "gold", "", "cream", -4.0, 4.0, -3.0, 2.0, 8.0, 1.5, 2.6)
		5: # Starfall Observatory: stardust & shooting stars
			_add_group(rng, 9 if d else 12, Kind.TWINKLE, "gold", "", "cream", -3.0, 3.0, -4.0, 2.0, 4.0, 1.6, 3.0)
			_add_group(rng, 8 if d else 12, Kind.TWINKLE, "ice", "", "cream", -4.0, 4.0, -3.0, 3.0, 4.0, 1.8, 3.2)
			_add_group(rng, 1 if d else 2, Kind.SHOOT, "ice", "", "gold", 150.0, 150.0, 62.0, 62.0, 0.0, 6.5, 6.5)
		6: # Ashen Kiln: forge cinders & ash flakes
			_add_group(rng, 7 if d else 10, Kind.GLOW, "apricot", "", "gold", -5.0, 6.0, -22.0, -11.0, 11.0, 2.2, 3.8)
			_add_group(rng, 6 if d else 8, Kind.GLOW, "coral", "", "gold", -6.0, 6.0, -18.0, -9.0, 10.0, 2.0, 3.4)
			_add_group(rng, 5 if d else 8, Kind.FLAKE, "stone", "", "mauve", -4.0, 4.0, 4.0, 9.0, 8.0, 1.1, 2.0)
		7: # Moon Shoals: moonlit reflections & prism glints
			_add_group(rng, 9 if d else 14, Kind.MOTE, "ice", "sky", "ice", 4.0, 11.0, -4.0, 2.0, 6.0, 1.2, 2.2, 2.0, 2.0)
			_add_group(rng, 9 if d else 12, Kind.TWINKLE, "sky", "ice", "cream", -2.0, 2.0, -3.0, 1.0, 3.0, 2.0, 3.6)
		_: # Island 8 (The Long Night): void ash & eclipse embers
			_add_group(rng, 10 if d else 14, Kind.FLAKE, "mauve", "stone", "stone", -5.0, 3.0, 6.0, 13.0, 9.0, 1.0, 1.9)
			_add_group(rng, 8 if d else 12, Kind.GLOW, "coral", "", "gold", -4.0, 4.0, -9.0, -3.0, 7.0, 1.1, 2.0)
	queue_redraw()

func _add_group(rng: RandomNumberGenerator, count: int, kind: int, c1: String, c1_alt: String, c2: String, vx0: float, vx1: float, vy0: float, vy1: float, sway: float, f0: float, f1: float, sz: float = 1.0, sz_third: float = 0.0) -> void:
	for i: int in range(count):
		if _items.size() >= MAX_PARTICLES:
			return
		var p := Particle.new()
		p.pos = Vector2(_cam_center.x - HALF_W + rng.randf_range(0.0, VIEW_W), _cam_center.y - HALF_H + rng.randf_range(0.0, VIEW_H))
		p.vel = Vector2(vx0 if vx0 == vx1 else rng.randf_range(vx0, vx1), vy0 if vy0 == vy1 else rng.randf_range(vy0, vy1))
		p.phase = rng.randf_range(0.0, TAU)
		p.freq = f0 if f0 == f1 else rng.randf_range(f0, f1)
		p.sway = sway
		p.kind = kind
		p.col = LxPalette.color(c1 if (c1_alt.is_empty() or i % 2 == 0) else c1_alt)
		p.col2 = LxPalette.color(c2)
		p.size = sz_third if (sz_third > 0.0 and i % 3 == 0) else sz
		_items.append(p)

func tick(dt: float, cam_center: Vector2) -> void:
	if _bound_events != Lx.events:
		_sync_events()
	if _items.is_empty() and _sparks.is_empty() and _rings.is_empty() and _pillars.is_empty() and _slashes.is_empty() and _shard_orbs.is_empty():
		return
	_cam_center = cam_center
	_clock += dt
	var min_x: float = cam_center.x - HALF_W
	var min_y: float = cam_center.y - HALF_H
	var wick_pos: Vector2 = _player_pos()
	var wick_vel: Vector2 = Vector2.ZERO
	var wick_burst: bool = false
	if Lx.player != null and is_instance_valid(Lx.player):
		var vel_v: Variant = Lx.player.get("velocity")
		if vel_v is Vector2:
			wick_vel = vel_v as Vector2
		wick_burst = (Lx.player.has_method("is_dashing") and bool(Lx.player.call("is_dashing"))) \
			or (Lx.player.has_method("is_zipping") and bool(Lx.player.call("is_zipping"))) \
			or (Lx.player.has_method("is_gliding") and bool(Lx.player.call("is_gliding")))
	var wake_r: float = 44.0 if wick_burst else 24.0
	var wake_r2: float = wake_r * wake_r
	var wake_active: bool = wick_burst or wick_vel.length_squared() > 400.0
	for p: Particle in _items:
		if p.kind == Kind.SHOOT:
			var cyc: float = fposmod(_clock + p.phase, p.freq)
			if cyc < 0.45:
				p.pos += p.vel * dt
			elif cyc >= p.freq - maxf(dt, 0.02):
				p.pos = Vector2(min_x + fposmod(p.phase * 53.0, VIEW_W * 0.65), min_y + 14.0 + fposmod(p.phase * 29.0, VIEW_H * 0.35))
		else:
			if wake_active and p.kind != Kind.STREAK:
				var diff: Vector2 = p.pos - wick_pos
				var d2: float = diff.length_squared()
				if d2 > 1.0 and d2 < wake_r2:
					var d: float = sqrt(d2)
					var falloff: float = 1.0 - (d / wake_r)
					var away: Vector2 = diff / d
					var force: float = (180.0 if wick_burst else 65.0) * falloff * dt
					p.push += (away * force + wick_vel * (0.18 * falloff * dt))
					if p.push.length_squared() > 8100.0:
						p.push = p.push.normalized() * 90.0
			p.push *= maxf(0.0, 1.0 - 4.2 * dt)
			p.pos.x += (p.vel.x + p.push.x + sin(_clock * p.freq + p.phase) * p.sway) * dt
			p.pos.y += (p.vel.y + p.push.y + cos(_clock * p.freq * 0.7 + p.phase) * p.sway * 0.35) * dt
		p.pos.x = min_x + fposmod(p.pos.x - min_x, VIEW_W)
		p.pos.y = min_y + fposmod(p.pos.y - min_y, VIEW_H)

	for i: int in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		var age: float = float(s["age"]) + dt
		if age >= float(s["dur"]):
			_sparks.remove_at(i)
			continue
		var vel: Vector2 = (s["vel"] as Vector2) * maxf(0.0, 1.0 - float(s["drag"]) * dt)
		vel.y -= float(s["buoy"]) * dt
		s["vel"] = vel
		s["pos"] = (s["pos"] as Vector2) + vel * dt
		s["age"] = age
	_age_pool(_rings, dt)
	_age_pool(_pillars, dt)
	_age_pool(_slashes, dt)
	_tick_shard_orbs(dt)
	queue_redraw()

func _age_pool(pool: Array[Dictionary], dt: float) -> void:
	for i: int in range(pool.size() - 1, -1, -1):
		var item: Dictionary = pool[i]
		var age: float = float(item["age"]) + dt
		if age >= float(item["dur"]):
			pool.remove_at(i)
		else:
			item["age"] = age

func _draw_cross(pt: Vector2, arm_col: Color, core_col: Color) -> void:
	draw_rect(Rect2(pt + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), arm_col)
	draw_rect(Rect2(pt + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), arm_col)
	draw_rect(Rect2(pt, Vector2.ONE), core_col)

func _draw() -> void:
	if _items.is_empty() and _sparks.is_empty() and _rings.is_empty() and _pillars.is_empty() and _slashes.is_empty() and _shard_orbs.is_empty():
		return
	for p: Particle in _items:
		var pt: Vector2 = p.pos.round()
		match p.kind:
			Kind.GLOW:
				var pulse: float = 0.5 + 0.5 * sin(_clock * p.freq + p.phase)
				if pulse > 0.72:
					_draw_cross(pt, p.col, p.col2)
				elif pulse > 0.10:
					draw_rect(Rect2(pt, Vector2.ONE), p.col2 if pulse > 0.28 else p.col)
			Kind.FLAKE:
				draw_rect(Rect2(pt, Vector2(2.0, 1.0) if sin(_clock * p.freq * 1.4 + p.phase) >= 0.0 else Vector2(1.0, 2.0)), p.col)
			Kind.TWINKLE:
				var tw: float = maxf(0.0, sin(_clock * p.freq + p.phase))
				tw *= tw
				if tw > 0.65:
					_draw_cross(pt, p.col, p.col2)
				elif tw > 0.22:
					draw_rect(Rect2(pt, Vector2.ONE), p.col2)
			Kind.STREAK:
				draw_line(pt, pt + Vector2(2.0, -4.0), p.col, 1.0, false)
			Kind.MOTE:
				var sh: float = 0.5 + 0.5 * sin(_clock * p.freq + p.phase)
				if sh > 0.28:
					draw_rect(Rect2(pt, Vector2(p.size, 1.0)), p.col2 if sh > 0.78 else p.col)
			Kind.SHOOT:
				var cyc: float = fposmod(_clock + p.phase, p.freq)
				if cyc < 0.45:
					var tail: Vector2 = (Vector2(8.0, 3.0) * sin((cyc / 0.45) * PI)).round()
					if tail.length_squared() >= 1.0:
						draw_line(pt, pt - tail, p.col, 1.0, false)
					draw_rect(Rect2(pt, Vector2.ONE), p.col2)
	for pl: Dictionary in _pillars:
		_draw_pillar(pl)
	for r: Dictionary in _rings:
		_draw_ring(r)
	for sl: Dictionary in _slashes:
		_draw_slash(sl)
	for ob: Dictionary in _shard_orbs:
		_draw_shard_orb(ob)
	for s: Dictionary in _sparks:
		_draw_spark(s)

func _draw_pillar(pl: Dictionary) -> void:
	var u: float = clampf(float(pl["age"]) / maxf(0.01, float(pl["dur"])), 0.0, 1.0)
	var env: float = (u / 0.14) if u < 0.14 else pow(1.0 - (u - 0.14) / 0.86, 1.35)
	var w_px: int = int(round(float(pl["w"]) * env))
	if w_px <= 0:
		return
	var h_px: float = round(float(pl["h"]) * (0.45 + 0.55 * minf(1.0, u * 4.5)))
	var base: Vector2 = (pl["pos"] as Vector2).round()
	var top_y: float = base.y - h_px
	draw_rect(Rect2(round(base.x - float(w_px) * 0.5), top_y, float(w_px), h_px), pl["edge"] as Color)
	if w_px >= 4:
		var mid_w: int = maxi(2, w_px - 2)
		draw_rect(Rect2(round(base.x - float(mid_w) * 0.5), top_y + 4.0, float(mid_w), maxf(2.0, h_px - 4.0)), pl["mid"] as Color)
	if w_px >= 6:
		var core_w: int = maxi(2, w_px - 6)
		draw_rect(Rect2(round(base.x - float(core_w) * 0.5), top_y + 10.0, float(core_w), maxf(2.0, h_px - 10.0)), pl["core"] as Color)
	draw_rect(Rect2(round(base.x - float(w_px) * 0.5 - 2.0), base.y - 1.0, float(w_px + 4), 2.0), pl["mid"] as Color)

func _draw_ring(r: Dictionary) -> void:
	var u: float = clampf(float(r["age"]) / maxf(0.01, float(r["dur"])), 0.0, 1.0)
	var rad: float = round(lerpf(float(r["r0"]), float(r["r1"]), 1.0 - (1.0 - u) * (1.0 - u)))
	if rad < 1.0:
		return
	var pt: Vector2 = (r["pos"] as Vector2).round()
	var col: Color = (r["c1"] as Color) if u < 0.45 else (r["c2"] as Color)
	var width: float = 2.0 if u < 0.38 else 1.0
	if u > 0.78:
		var dots: int = clampi(int(rad * 0.6), 6, 16)
		for k: int in range(dots):
			var a: float = (TAU * float(k)) / float(dots)
			draw_rect(Rect2((pt + Vector2(cos(a), sin(a)) * rad).round(), Vector2.ONE), col)
	elif bool(r["dia"]):
		draw_polyline(PackedVector2Array([pt + Vector2(0.0, -rad), pt + Vector2(rad, 0.0), pt + Vector2(0.0, rad), pt + Vector2(-rad, 0.0), pt + Vector2(0.0, -rad)]), col, width, false)
	else:
		draw_arc(pt, rad, 0.0, TAU, clampi(int(rad * 0.9), 12, 28), col, width, false)

func _draw_spark(s: Dictionary) -> void:
	var u: float = clampf(float(s["age"]) / maxf(0.01, float(s["dur"])), 0.0, 1.0)
	var ramp_arr: Array = SPARK_RAMPS[clampi(int(s["ramp"]), 0, SPARK_RAMPS.size() - 1)] as Array
	var col: Color = LxPalette.color(str(ramp_arr[clampi(int(u * float(ramp_arr.size())), 0, ramp_arr.size() - 1)]))
	var s0: int = int(s["sz"])
	var sz: int = s0 if u < 0.35 else (maxi(1, s0 - 1) if u < 0.72 else 1)
	var off: float = floor(float(sz) * 0.5)
	draw_rect(Rect2((s["pos"] as Vector2).round() - Vector2(off, off), Vector2(float(sz), float(sz))), col)

func _draw_slash(sl: Dictionary) -> void:
	var u: float = clampf(float(sl["age"]) / maxf(0.01, float(sl["dur"])), 0.0, 1.0)
	var half_l: float = roundf(float(sl["len"]) * (0.55 + 0.45 * u) * (1.0 - u * 0.65))
	if half_l < 2.0:
		return
	var c: Vector2 = (sl["pos"] as Vector2).round()
	var d: Vector2 = sl["dir"] as Vector2
	var a: Vector2 = (c - d * half_l).round()
	var b: Vector2 = (c + d * half_l).round()
	draw_line(a, b, sl["outer"] as Color, 3.0 if u < 0.35 else 1.0, false)
	if u < 0.65:
		draw_line((c - d * roundf(half_l * 0.7)).round(), (c + d * roundf(half_l * 0.7)).round(), sl["core"] as Color, 1.0, false)


func _spawn_slash(pos: Vector2, dir: Vector2, length: float, dur: float, core_k: String, outer_k: String) -> void:
	if _slashes.size() >= 10:
		_slashes.pop_front()
	var dn: Vector2 = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	_slashes.append({"pos": pos, "dir": dn, "len": length, "age": 0.0, "dur": dur, "core": LxPalette.color(core_k), "outer": LxPalette.color(outer_k)})


func _spawn_shard_orbs(pos: Vector2, count: int) -> void:
	var n: int = clampi(count, 1, 7)
	for i: int in range(n):
		if _shard_orbs.size() >= 20:
			_shard_orbs.pop_front()
		var ang: float = _vfx_rng.randf_range(0.0, TAU)
		var v: Vector2 = Vector2(cos(ang), sin(ang)) * _vfx_rng.randf_range(38.0, 74.0) + Vector2(0.0, -16.0)
		_shard_orbs.append({"pos": pos, "vel": v, "age": 0.0, "delay": 0.12 + float(i) * 0.045, "sound": i == 0 or i == n - 1})


func _tick_shard_orbs(dt: float) -> void:
	if _shard_orbs.is_empty():
		return
	var target: Vector2 = _player_pos() + Vector2(0.0, -5.0)
	for i: int in range(_shard_orbs.size() - 1, -1, -1):
		var ob: Dictionary = _shard_orbs[i]
		var age: float = float(ob["age"]) + dt
		ob["age"] = age
		var p: Vector2 = ob["pos"] as Vector2
		var v: Vector2 = ob["vel"] as Vector2
		if age < float(ob["delay"]):
			v *= maxf(0.0, 1.0 - 4.2 * dt)
			p += v * dt
		else:
			var to_p: Vector2 = target - p
			var d: float = to_p.length()
			if d <= 7.0 or age >= 1.35:
				if bool(ob["sound"]) and Lx.audio != null:
					Lx.audio.play_sfx("shard_pickup", target, false)
				_spawn_sparks(target, 2, Ramp.GOLD, 16.0, 38.0, 0.14, 0.24, 4.5, 16.0, 1, Vector2.UP)
				_shard_orbs.remove_at(i)
				continue
			var spd: float = minf(260.0, 115.0 + (age - float(ob["delay"])) * 240.0)
			v = v.lerp((to_p / d) * spd, minf(1.0, dt * 11.0))
			p += v * dt
		ob["pos"] = p
		ob["vel"] = v


func _draw_shard_orb(ob: Dictionary) -> void:
	var p: Vector2 = (ob["pos"] as Vector2).round()
	var bright: bool = fmod(float(ob["age"]) * 8.0, 1.0) < 0.55
	draw_rect(Rect2(p + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), PAL["gold"])
	draw_rect(Rect2(p + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), PAL["gold"])
	draw_rect(Rect2(p, Vector2.ONE), PAL["cream"] if bright else PAL["apricot"])


func _spawn_ring(pos: Vector2, r0: float, r1: float, dur: float, c1: String, c2: String, dia: bool = false) -> void:
	if _rings.size() >= MAX_RINGS:
		_rings.pop_front()
	_rings.append({"pos": pos, "r0": r0, "r1": r1, "age": 0.0, "dur": dur, "c1": LxPalette.color(c1), "c2": LxPalette.color(c2), "dia": dia})

func _spawn_pillar(pos: Vector2, dur: float, w: float, h: float, core_k: String, mid_k: String, edge_k: String) -> void:
	if _pillars.size() >= MAX_PILLARS:
		_pillars.pop_front()
	_pillars.append({"pos": pos, "age": 0.0, "dur": dur, "w": w, "h": h, "core": LxPalette.color(core_k), "mid": LxPalette.color(mid_k), "edge": LxPalette.color(edge_k)})

func _spawn_sparks(pos: Vector2, count: int, ramp: int, smin: float, smax: float, dmin: float, dmax: float, drag: float = 4.5, buoy: float = 0.0, sz_max: int = 2, bias: Vector2 = Vector2.ZERO, spread: float = 3.0) -> void:
	for _i: int in range(count):
		if _sparks.size() >= MAX_SPARKS:
			_sparks.pop_front()
		var ang: float = _vfx_rng.randf_range(0.0, TAU)
		var v: Vector2 = Vector2(cos(ang), sin(ang)) * _vfx_rng.randf_range(smin, smax)
		if bias.length_squared() > 0.01:
			v = v * 0.55 + bias.normalized() * _vfx_rng.randf_range(smin, smax) * 0.75
		var base_pos: Vector2 = pos + Vector2(_vfx_rng.randf_range(-spread, spread), _vfx_rng.randf_range(-spread, spread))
		_sparks.append({"pos": base_pos, "vel": v, "age": 0.0, "dur": _vfx_rng.randf_range(dmin, dmax), "drag": drag, "buoy": buoy, "sz": _vfx_rng.randi_range(1, clampi(sz_max, 1, 3)), "ramp": ramp})

func _emit_juice(shake: float, hitstop: float = 0.0) -> void:
	if Lx.events == null or not is_instance_valid(Lx.events):
		return
	if shake > 0.0:
		Lx.events.shake_requested.emit(shake)
	if hitstop > 0.0:
		Lx.events.hitstop_requested.emit(hitstop)

func _player_pos() -> Vector2:
	if Lx.player != null and is_instance_valid(Lx.player):
		if Lx.player is Node2D:
			return (Lx.player as Node2D).global_position
		if Lx.player.has_method("get_pos"):
			return Lx.player.call("get_pos") as Vector2
	return _cam_center

func _interactable_pos(id: String, fallback_kind: String = "") -> Vector2:
	if Lx.world != null and is_instance_valid(Lx.world):
		if not id.is_empty() and Lx.world.has_method("find_interactable"):
			var it: Variant = Lx.world.call("find_interactable", id)
			if it is Node2D and is_instance_valid(it):
				return (it as Node2D).global_position
		if not fallback_kind.is_empty() and Lx.world.has_method("get_interactables"):
			var arr: Variant = Lx.world.call("get_interactables")
			if arr is Array:
				for item: Variant in (arr as Array):
					if item is Node2D and is_instance_valid(item) and str((item as Object).get("kind")) == fallback_kind:
						return (item as Node2D).global_position
	return _player_pos()

func _boss_pos(boss_id: String) -> Vector2:
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("get_enemies"):
		var enemies: Variant = Lx.world.call("get_enemies")
		if enemies is Array:
			for e: Variant in (enemies as Array):
				if e is Node2D and is_instance_valid(e) and (str((e as Object).get("kind")) == boss_id or bool((e as Object).get("is_boss"))):
					return (e as Node2D).global_position
	return _player_pos()

func _on_enemy_hit(enemy: Object, hit: Object, result: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var pos: Vector2 = ((enemy as Node2D).global_position if enemy is Node2D else _player_pos()) + Vector2(0.0, -5.0)
	var hdir: Vector2 = (hit.get("dir") as Vector2) if (hit != null and hit.get("dir") is Vector2) else (pos - _player_pos()).normalized()
	if result <= 0:
		_spawn_sparks(pos, 4, Ramp.STEEL, 34.0, 68.0, 0.16, 0.26, 6.0, 0.0, 2)
		_spawn_ring(pos, 2.0, 10.0, 0.18, "ice", "stone", true)
	elif result == 1:
		_spawn_sparks(pos, 5, Ramp.GOLD, 32.0, 64.0, 0.18, 0.30, 5.2, 8.0, 2, hdir)
		_spawn_slash(pos, hdir, 10.0, 0.10, "cream", "gold")
	elif result == 2:
		_spawn_sparks(pos, 10, Ramp.GOLD, 48.0, 96.0, 0.24, 0.42, 4.2, 16.0, 3, hdir)
		_spawn_ring(pos, 3.0, 22.0, 0.28, "cream", "gold", false)
		_spawn_slash(pos, hdir, 18.0, 0.15, "cream", "apricot")
		if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("add_kick"):
			Lx.camera.call("add_kick", hdir, 2.8)
		_emit_juice(0.24, 0.032)

func _on_enemy_killed(e: Object, _k: String, pos: Vector2, opened: bool) -> void:
	var p: Vector2 = pos + Vector2(0.0, -4.0)
	_spawn_sparks(p, 6, Ramp.SHADOW, 20.0, 52.0, 0.28, 0.48, 3.6, 12.0, 2)
	_spawn_sparks(p, 10 if opened else 6, Ramp.GOLD, 34.0, 82.0, 0.26, 0.50, 3.8, 28.0, 3 if opened else 2)
	_spawn_ring(p, 4.0, 26.0, 0.34, "cream" if opened else "gold", "gold" if opened else "apricot", false)
	var drop_v: Variant = e.get("shard_drop") if (e != null and is_instance_valid(e)) else 2
	var drop_n: int = int(drop_v) if (drop_v is int or drop_v is float) else 2
	if drop_n > 0:
		_spawn_shard_orbs(p, mini(7, maxi(2, drop_n / 2 + (1 if opened else 0))))
	_gust_particles(p, 56.0 if opened else 40.0, 58.0 if opened else 38.0)
	_emit_juice(0.30 if opened else 0.16)

func _gust_particles(origin: Vector2, radius: float, strength: float) -> void:
	var r2: float = radius * radius
	for p: Particle in _items:
		if p.kind == Kind.SHOOT or p.kind == Kind.STREAK:
			continue
		var diff: Vector2 = p.pos - origin
		var d2: float = diff.length_squared()
		if d2 > 1.0 and d2 < r2:
			var d: float = sqrt(d2)
			p.push += (diff / d) * (strength * (1.0 - d / radius))
			if p.push.length_squared() > 14400.0:
				p.push = p.push.normalized() * 120.0

func _on_boss_phase_changed(boss_id: String, _phase: int) -> void:
	var p: Vector2 = _boss_pos(boss_id)
	_spawn_ring(p, 6.0, 48.0, 0.44, "coral", "wine", false)
	_spawn_ring(p, 4.0, 38.0, 0.38, "cream", "gold", true)
	_spawn_sparks(p, 10, Ramp.CORAL, 46.0, 108.0, 0.28, 0.52, 3.4, 14.0, 3)
	_spawn_sparks(p, 8, Ramp.GOLD, 40.0, 92.0, 0.30, 0.55, 3.2, 22.0, 3)
	_gust_particles(p, 96.0, 95.0)
	_emit_juice(0.48, 0.055)

func _grand_burst(pos: Vector2, slowmo: bool = false) -> void:
	_spawn_pillar(pos, 0.78, 14.0, 114.0, "cream", "gold", "apricot")
	_spawn_sparks(pos, 26, Ramp.GOLD, 24.0, 96.0, 0.44, 0.80, 2.2, 52.0, 3, Vector2.UP, 9.0)
	_spawn_ring(pos, 6.0, 68.0, 0.56, "cream", "gold", false)
	_spawn_ring(pos, 3.0, 44.0, 0.44, "gold", "apricot", true)
	_gust_particles(pos, 120.0, 115.0)
	_emit_juice(0.58, 0.11 if slowmo else 0.06)
	if slowmo and Lx.hitstop != null and is_instance_valid(Lx.hitstop) and Lx.hitstop.has_method("trigger_slowmo"):
		Lx.hitstop.call("trigger_slowmo", 0.34, 0.42)

func _discovery_burst(pos: Vector2, warm: bool) -> void:
	_spawn_pillar(pos, 0.65, 10.0, 88.0, "cream", "gold" if warm else "ice", "apricot" if warm else "sky")
	_spawn_sparks(pos, 12, Ramp.GOLD if warm else Ramp.ICE, 18.0, 56.0, 0.36, 0.68, 2.6, 42.0, 2, Vector2.UP, 6.0)
	_spawn_ring(pos, 4.0, 32.0, 0.40, "cream", "gold" if warm else "sky", not warm)
	_emit_juice(0.25)

func _on_boss_defeated(bid: String, _i: int) -> void: _grand_burst(_boss_pos(bid), true)
func _on_great_lamp_relit(_i: int) -> void: _grand_burst(_interactable_pos("great_lamp", "great_lamp"), true)
func _on_shrine_claimed(sid: String, _m: String) -> void: _discovery_burst(_interactable_pos(sid, "shrine"), true)
func _on_beacon_lit(_i: int, bid: String) -> void: _discovery_burst(_interactable_pos(bid, "beacon"), true)
func _on_waystone_lit(_i: int, wid: String) -> void: _discovery_burst(_interactable_pos(wid, "waystone"), false)
func _on_seal_broken(_i: int, sid: String) -> void: _discovery_burst(_interactable_pos(sid, "seal"), false)

func _on_lantern_hung(pos: Vector2) -> void:
	_spawn_ring(pos, 3.0, 18.0, 0.26, "cream", "gold", false)
	_spawn_sparks(pos, 7, Ramp.GOLD, 22.0, 56.0, 0.22, 0.38, 4.4, 18.0, 2)

func _on_lantern_caught(pos: Vector2) -> void:
	_spawn_ring(pos, 3.0, 16.0, 0.22, "cream", "gold", true)
	_spawn_sparks(pos, 6, Ramp.GOLD, 24.0, 52.0, 0.18, 0.32, 4.8, 12.0, 2)

func _on_lantern_struck(pos: Vector2) -> void:
	_spawn_ring(pos, 4.0, 24.0, 0.30, "cream", "gold", false)
	_spawn_sparks(pos, 10, Ramp.GOLD, 38.0, 86.0, 0.24, 0.44, 4.0, 20.0, 3)
	_gust_particles(pos, 64.0, 62.0)

func _on_player_damaged(_a: float, from_pos: Vector2, knock_dir: Vector2, _s: String) -> void:
	var p: Vector2 = _player_pos() + Vector2(0.0, -5.0)
	var kdir: Vector2 = knock_dir if knock_dir.length_squared() > 0.01 else (p - from_pos)
	_spawn_sparks(p, 8, Ramp.CORAL, 40.0, 84.0, 0.20, 0.36, 4.8, 0.0, 2, kdir, 3.0)
	if Lx.camera != null and is_instance_valid(Lx.camera) and Lx.camera.has_method("add_kick"):
		Lx.camera.call("add_kick", kdir, 3.4)
	_emit_juice(0.42)

func _on_player_healed(_a: float) -> void:
	_spawn_sparks(_player_pos() + Vector2(0.0, -4.0), 8, Ramp.HEAL, 14.0, 38.0, 0.36, 0.62, 2.8, 40.0, 2, Vector2.UP, 6.0)

func _on_ember_piece(_total: int) -> void:
	_discovery_burst(_player_pos(), true)

func _on_upgrade_purchased(_id: String, _rank: int) -> void:
	var p: Vector2 = _player_pos() + Vector2(0.0, -6.0)
	_spawn_ring(p, 4.0, 30.0, 0.38, "cream", "gold", false)
	_spawn_sparks(p, 12, Ramp.GOLD, 18.0, 62.0, 0.30, 0.56, 3.0, 36.0, 2, Vector2.UP, 6.0)

func _on_shard_collected(amount: int) -> void:
	if amount < 10:
		return
	var p: Vector2 = _player_pos() + Vector2(0.0, -6.0)
	_spawn_ring(p, 3.0, 22.0, 0.30, "cream", "gold", true)
	_spawn_sparks(p, 10, Ramp.GOLD, 20.0, 56.0, 0.24, 0.46, 3.2, 30.0, 2, Vector2.UP, 5.0)
