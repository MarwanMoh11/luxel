class_name LxOwLaunchPad
extends Node2D
## Island 1 East Launch Pad ambient glow and 3-phase take-off sequence toward Island 2.
## Mounted on 1:overworld; strictly 20 Last Light colours, pixel-snapped, flash_reduced-aware.

const PAL: Dictionary = LxPalette.PAL
const COMPASS_POS := Vector2(1160.0, 168.0)
const COMPASS_RADIUS: float = 20.0
const ALIGN_POS := Vector2(1212.0, 168.0)
const SAFE_RESTORE_POS := Vector2(1192.0, 168.0)
const MOON_TARGET := Vector2(1316.0, 74.0)
const RUNWAY_XS: Array[float] = [1192.0, 1208.0, 1224.0, 1240.0, 1256.0, 1272.0]
const RUNWAY_Y: float = 168.0
const PHASE1_END: float = 0.35; const PHASE2_END: float = 0.85; const TOTAL_DUR: float = 1.35
const TILE_STEP_S: float = 0.075; const MAX_SPARKS: int = 72; const MAX_TRAIL: int = 24

static var active_instance: LxOwLaunchPad = null

var _air_fx: Node2D = null; var _clock: float = 0.0
var _launching: bool = false; var _completed: bool = false; var _launch_t: float = 0.0
var _lit_tiles: int = -1; var _liftoff_fired: bool = false
var _start_pos: Vector2 = ALIGN_POS; var _cam_target: Vector2 = ALIGN_POS
var _wick: Node2D = null; var _dest_island: int = 2; var _dest_region: String = "overworld"
var _dest_spawn: Vector2 = Vector2(104.0, 248.0)
var _sparks: Array[Dictionary] = []; var _trail: Array[Vector2] = []

static func is_any_launching() -> bool:
	return active_instance != null and is_instance_valid(active_instance) and active_instance.is_launching()

static func cancel_active() -> void:
	if active_instance != null and is_instance_valid(active_instance): active_instance.cancel_launch()

static func mount_on(world: Node, cur: Node2D, script_res: GDScript) -> Node2D:
	if world == null or not is_instance_valid(world):
		return null
	if cur != null and is_instance_valid(cur) and not cur.is_queued_for_deletion() and cur.get_parent() == world:
		return cur
	var existing: Node = world.get_node_or_null("Island1LaunchPad")
	if existing is Node2D and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		return existing as Node2D
	var pad: Node2D = script_res.new() as Node2D if script_res != null else null
	if pad != null:
		pad.name = "Island1LaunchPad"
		world.add_child(pad)
	return pad

static func unmount_from(world: Node, cur: Node2D) -> void:
	if cur != null and is_instance_valid(cur):
		if cur.has_method("cancel_launch"): cur.call("cancel_launch")
		if cur.get_parent() != null: cur.get_parent().remove_child(cur)
		cur.queue_free()
	if world != null and is_instance_valid(world):
		var leftover: Node = world.get_node_or_null("Island1LaunchPad")
		if leftover != null and is_instance_valid(leftover) and not leftover.is_queued_for_deletion():
			if leftover.has_method("cancel_launch"): leftover.call("cancel_launch")
			if leftover.get_parent() != null: leftover.get_parent().remove_child(leftover)
			leftover.queue_free()

func _ready() -> void:
	z_index = -3; z_as_relative = false; texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	active_instance = self
	_air_fx = Node2D.new(); _air_fx.name = "LaunchPadAirFx"
	_air_fx.z_index = 5; _air_fx.z_as_relative = false; _air_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_air_fx.draw.connect(_draw_air_fx); add_child(_air_fx)

func _exit_tree() -> void:
	if _launching: cancel_launch()
	if active_instance == self: active_instance = null

func is_pad_ready() -> bool:
	if Lx.state == null or Lx.state.island_id != 1 or Lx.state.region_id != "overworld": return false
	return Lx.state.relit_islands.has(1) or bool(Lx.state.story_flags.get("great_lamp_1", false))

func can_start_launch() -> bool: return not _launching and not _completed and is_pad_ready()
func is_launching() -> bool: return _launching
func get_camera_target() -> Vector2: return _cam_target

func _process(dt: float) -> void:
	if _launching: return
	var ready_now: bool = is_pad_ready()
	if visible != ready_now: visible = ready_now
	if not ready_now: return
	_clock += dt; _age_sparks(dt); queue_redraw()
	if _air_fx != null: _air_fx.queue_redraw()

func begin_launch(wick: Node2D, next_island: int, next_region: String, next_spawn: Vector2) -> void:
	if wick == null or not is_instance_valid(wick): return
	_wick = wick; _dest_island = next_island; _dest_region = next_region; _dest_spawn = next_spawn
	_launching = true; _completed = false; _launch_t = 0.0; _lit_tiles = -1; _liftoff_fired = false
	_start_pos = wick.global_position; _cam_target = ALIGN_POS + Vector2(8.0, 0.0)
	_sparks.clear(); _trail.clear(); visible = true
	_prep_wick_for_launch(wick)
	if Lx.audio != null:
		Lx.audio.play_stinger("stinger_lamp")
		Lx.audio.play_sfx("bell_toll", COMPASS_POS, false)
	var fred: bool = LxHudFx.flash_reduced()
	_burst_light(COMPASS_POS, 124.0, 0.93 if fred else 1.50, 0.52)
	if Lx.camera != null: Lx.camera.add_shake(0.05 if fred else 0.12)
	_spawn_radial_sparks(COMPASS_POS, 6 if fred else 10, 22.0, 56.0, 0.42, false)
	queue_redraw()
	if _air_fx != null: _air_fx.queue_redraw()

func step_launch(dt: float, _raw_dt: float, wick: Node2D) -> Dictionary:
	if not _launching: return {}
	if wick != null and is_instance_valid(wick): _wick = wick
	_launch_t += dt; _clock += dt; _age_sparks(dt)
	var fred: bool = LxHudFx.flash_reduced()
	var w: LxWick = _wick as LxWick if (_wick is LxWick and is_instance_valid(_wick)) else null
	if w != null:
		w.mercy_t = maxf(w.mercy_t, 0.35); w.velocity = Vector2.ZERO; w.knock = Vector2.ZERO
	if _launch_t < PHASE1_END:
		var e1: float = 1.0 - pow(1.0 - clampf(_launch_t / PHASE1_END, 0.0, 1.0), 2.4)
		_place_wick(w, _start_pos.lerp(ALIGN_POS, e1), Vector2.RIGHT)
		_cam_target = ALIGN_POS.lerp(ALIGN_POS + Vector2(14.0, -2.0), e1)
	elif _launch_t < PHASE2_END:
		var p2_t: float = _launch_t - PHASE1_END
		var u2: float = clampf(p2_t / (PHASE2_END - PHASE1_END), 0.0, 1.0)
		var target_tile: int = clampi(int(floorf(p2_t / TILE_STEP_S)), 0, RUNWAY_XS.size() - 1)
		while _lit_tiles < target_tile:
			_lit_tiles += 1; _ignite_runway_tile(_lit_tiles, fred)
		_place_wick(w, ALIGN_POS, Vector2.RIGHT)
		if w != null and not fred:
			var sq: float = sin(u2 * PI) * 0.09
			w.scale = Vector2(1.0 + sq, 1.0 - sq)
		_cam_target = (ALIGN_POS + Vector2(14.0, -2.0)).lerp(ALIGN_POS + Vector2(28.0, -8.0), u2)
	else:
		while _lit_tiles < RUNWAY_XS.size() - 1:
			_lit_tiles += 1; _ignite_runway_tile(_lit_tiles, fred)
		if not _liftoff_fired:
			_liftoff_fired = true; _trigger_liftoff(w, fred)
		var u3: float = clampf((_launch_t - PHASE2_END) / (TOTAL_DUR - PHASE2_END), 0.0, 1.0)
		var arc_p := Vector2(
			lerpf(ALIGN_POS.x, MOON_TARGET.x, u3 * u3 * (0.40 + 0.60 * u3)),
			lerpf(ALIGN_POS.y, MOON_TARGET.y, u3 * u3 * (0.25 + 0.75 * u3)) - sin(u3 * PI) * 8.0
		)
		_place_wick(w, arc_p, Vector2(0.84, -0.54).normalized())
		if w != null:
			w.z_index = 5
			if not fred: w.scale = Vector2(1.0 + 0.14 * u3, 1.0 - 0.06 * u3)
			w.modulate = Color(1.0, 1.0, 1.0, clampf(1.0 - (u3 - 0.78) / 0.22, 0.0, 1.0) if u3 > 0.78 else 1.0)
		if _trail.size() >= MAX_TRAIL: _trail.remove_at(0)
		_trail.append(arc_p + Vector2(0.0, -5.0))
		if int(floorf(_launch_t * 60.0)) % (3 if fred else 2) == 0:
			var sp_n: int = _sparks.size()
			_add_spark(arc_p + Vector2(-3.0, -4.0), Vector2(-34.0 - float(sp_n % 5) * 6.0, 12.0 + float(sp_n % 3) * 5.0), 0.34, "cream" if sp_n % 3 == 0 else "gold", 2.0 if sp_n % 4 == 0 else 1.0)
		_cam_target = (ALIGN_POS + Vector2(28.0, -8.0)).lerp(Vector2(1248.0, 134.0), 1.0 - pow(1.0 - u3, 2.0))
	queue_redraw()
	if _air_fx != null: _air_fx.queue_redraw()
	if _launch_t >= TOTAL_DUR:
		_restore_wick_visuals(_wick, false)
		_launching = false; _completed = true
		return {"done": true, "island": _dest_island, "region": _dest_region, "spawn": _dest_spawn}
	return {}

func cancel_launch() -> void:
	if not _launching: return
	_restore_wick_visuals(_wick, true)
	_launching = false; _launch_t = 0.0; _lit_tiles = -1; _liftoff_fired = false
	_sparks.clear(); _trail.clear(); queue_redraw()
	if _air_fx != null: _air_fx.queue_redraw()

func _prep_wick_for_launch(wick: Node2D) -> void:
	if not (wick is LxWick): return
	var w: LxWick = wick as LxWick
	if w.is_grabbing(): w.release_grab(Lx.world)
	if w.is_carrying(): w.drop_carried()
	if w.move_dash != null: w.move_dash.cancel()
	if w.move_beam != null: w.move_beam.cancel()
	if w.move_throw != null: w.move_throw.cancel_zip()
	if w.move_wings != null: w.move_wings.stop_glide(false)
	w.velocity = Vector2.ZERO; w.knock = Vector2.ZERO; w.facing = Vector2.RIGHT; w.mercy_t = maxf(w.mercy_t, 1.5)
	if w.lantern != null: w.lantern.reset_to_hand(w.global_position)
	w.queue_redraw()

func _place_wick(w: LxWick, pos: Vector2, dir: Vector2) -> void:
	if w == null: return
	w.global_position = pos; w.last_pos = pos; w.facing = dir
	if w.lantern != null: w.lantern.reset_to_hand(pos)
	w.queue_redraw()

func _restore_wick_visuals(wick: Node2D, snap_safe: bool) -> void:
	if wick == null or not is_instance_valid(wick): return
	wick.z_index = 0; wick.scale = Vector2.ONE; wick.rotation = 0.0; wick.modulate = Color.WHITE; wick.visible = true
	if snap_safe:
		wick.global_position = SAFE_RESTORE_POS
		if wick is LxWick:
			var w: LxWick = wick as LxWick
			w.last_pos = SAFE_RESTORE_POS; w.velocity = Vector2.ZERO; w.knock = Vector2.ZERO
			if w.lantern != null: w.lantern.reset_to_hand(SAFE_RESTORE_POS)
			w.queue_redraw()

func _ignite_runway_tile(idx: int, fred: bool) -> void:
	var tc := Vector2(RUNWAY_XS[clampi(idx, 0, RUNWAY_XS.size() - 1)], RUNWAY_Y)
	if Lx.audio != null: Lx.audio.play_sfx("prop_chime", tc, false)
	_burst_light(tc, 76.0, 0.85 if fred else 1.20, 0.38)
	var count: int = 3 if fred else 6
	for k: int in range(count):
		var dy: float = -12.0 + float(k) * (24.0 / float(maxi(1, count - 1)))
		_add_spark(tc + Vector2(-4.0, dy * 0.5), Vector2(18.0 + float(k % 3) * 14.0, -16.0 - float(k % 2) * 12.0), 0.38, "cream" if k % 2 == 0 else "gold", 2.0 if k == 0 else 1.0)

func _trigger_liftoff(w: LxWick, fred: bool) -> void:
	if Lx.audio != null:
		Lx.audio.play_sfx("waystone_warp", ALIGN_POS, false)
		Lx.audio.play_sfx("wing_gale", ALIGN_POS, false)
	_burst_light(ALIGN_POS, 148.0, 1.05 if fred else 1.65, 0.55)
	if Lx.camera != null:
		Lx.camera.add_kick(Vector2(0.75, -0.65), 3.0)
		Lx.camera.add_shake(0.06 if fred else 0.16)
	_spawn_radial_sparks(ALIGN_POS, 8 if fred else 16, 26.0, 88.0, 0.48, true)
	if w != null: w.z_index = 5; w.scale = Vector2.ONE

func _burst_light(pos: Vector2, rad: float, intensity: float, dur: float) -> void:
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(pos, rad, intensity, dur)

func _spawn_radial_sparks(center: Vector2, count: int, spd_min: float, spd_max: float, life: float, include_ice: bool) -> void:
	for i: int in range(count):
		var a: float = TAU * float(i) / float(maxi(1, count)) + 0.18
		var spd: float = lerpf(spd_min, spd_max, float((i * 7) % 5) / 4.0)
		var ck: String = "cream" if i % 3 == 0 else ("ice" if (include_ice and i % 5 == 0) else "gold")
		_add_spark(center + Vector2(cos(a) * 4.0, sin(a) * 3.0), Vector2(cos(a) * spd, sin(a) * spd - 10.0), life, ck, 2.0 if i % 3 == 0 else 1.0)

func _add_spark(p: Vector2, v: Vector2, life: float, col_key: String, sz: float) -> void:
	if _sparks.size() >= MAX_SPARKS: _sparks.remove_at(0)
	_sparks.append({"pos": p, "vel": v, "age": 0.0, "life": life, "col": col_key, "sz": sz})

func _age_sparks(dt: float) -> void:
	for i: int in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s["age"] = float(s["age"]) + dt
		var v: Vector2 = s["vel"] as Vector2
		s["pos"] = (s["pos"] as Vector2) + v * dt; s["vel"] = v * pow(0.14, dt)
		if float(s["age"]) >= float(s["life"]): _sparks.remove_at(i)

func _draw() -> void:
	if not visible: return
	var fred: bool = LxHudFx.flash_reduced()
	var c_gold: Color = PAL["gold"] as Color; var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color; var c_ice: Color = PAL["ice"] as Color
	var breath: float = 0.78 if fred else (0.64 + 0.36 * sin(_clock * 2.8))
	var flare: float = 0.0
	if _launching:
		flare = sin(clampf(_launch_t / PHASE1_END, 0.0, 1.0) * PI) if _launch_t < PHASE1_END else clampf(1.0 - (_launch_t - PHASE1_END) / 0.85, 0.28, 0.85)
		if fred: flare *= 0.65
	# Compass rose breathing glow & flare at [1160, 168], radius 20
	draw_circle(COMPASS_POS, COMPASS_RADIUS, Color(c_apricot, (0.10 + flare * 0.16) * breath))
	draw_circle(COMPASS_POS, 11.0, Color(c_gold, (0.14 + flare * 0.24) * breath))
	draw_arc(COMPASS_POS, COMPASS_RADIUS, 0.0, TAU, 24, Color(c_gold if flare < 0.35 else c_cream, clampf((0.44 + flare * 0.48) * breath, 0.0, 0.95)), 1.5 if flare > 0.25 else 1.0)
	draw_arc(COMPASS_POS, 12.0, 0.0, TAU, 16, Color(c_cream, clampf((0.28 + flare * 0.46) * breath, 0.0, 0.92)), 1.0)
	for k: int in range(8):
		var ang: float = float(k) * (PI * 0.25)
		var is_card: bool = (k % 2 == 0)
		var r_in: float = 5.0 if is_card else 12.0
		var r_out: float = (19.0 if k == 0 else 17.0) if is_card else 16.0
		draw_line((COMPASS_POS + Vector2.from_angle(ang) * r_in).round(), (COMPASS_POS + Vector2.from_angle(ang) * r_out).round(), Color(c_cream if (k == 0 or flare > 0.45) else c_gold, clampf((0.52 + flare * 0.42) * breath, 0.0, 0.95)), 1.0)
	draw_rect(Rect2(COMPASS_POS - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(c_gold, clampf(0.55 + flare * 0.40, 0.0, 0.95)))
	draw_rect(Rect2(COMPASS_POS - Vector2.ONE, Vector2(2.0, 2.0)), Color(c_cream, clampf(0.75 + flare * 0.25, 0.0, 1.0)))
	# Runway guide pips & tile-by-tile ignition across tiles x=74..79 (1184..1280), y=144..192
	var wave: float = fposmod(_clock * (0.65 if fred else 1.45), float(RUNWAY_XS.size()))
	for i: int in range(RUNWAY_XS.size()):
		var cx: float = RUNWAY_XS[i]
		if _launching and i <= _lit_tiles:
			var hot: float = clampf(1.0 - maxf(0.0, (_launch_t - PHASE1_END) - float(i) * TILE_STEP_S) * 2.2, 0.0, 1.0)
			draw_rect(Rect2(cx - 8.0, RUNWAY_Y - 3.0, 16.0, 6.0), Color(c_apricot, 0.36 + hot * 0.24))
			draw_rect(Rect2(cx - 8.0, RUNWAY_Y - 2.0, 16.0, 4.0), Color(c_gold, 0.78 + hot * 0.20))
			draw_rect(Rect2(cx - 7.0, RUNWAY_Y - 1.0, 14.0, 2.0), Color(c_cream, 0.82 + hot * 0.18))
			_draw_chevron(Vector2(cx + 3.0, RUNWAY_Y), c_cream if hot > 0.35 else c_gold, 0.95, 4.0)
			for ey: float in [150.0, 185.0]:
				draw_rect(Rect2(cx - 2.0, ey, 4.0, 2.0), Color(c_gold, 0.85))
				draw_rect(Rect2(cx - 1.0, ey, 2.0, 1.0), Color(c_cream if hot > 0.2 else c_ice, 0.92))
		else:
			var d_w: float = minf(absf(float(i) - wave), float(RUNWAY_XS.size()) - absf(float(i) - wave))
			var pip: float = 0.55 if fred else clampf(1.0 - d_w * 0.55, 0.24, 1.0)
			draw_rect(Rect2(cx - 4.0, RUNWAY_Y - 1.0, 8.0, 2.0), Color(c_gold, 0.32 * pip * breath))
			_draw_chevron(Vector2(cx + 2.0, RUNWAY_Y), c_cream if pip > 0.72 else c_gold, 0.62 * pip * breath, 3.0)
			for ey: float in [150.0, 185.0]:
				draw_rect(Rect2(cx - 1.0, ey, 2.0, 1.0), Color(c_apricot if pip < 0.65 else c_gold, 0.55 * pip))

func _draw_chevron(tip: Vector2, col: Color, alpha: float, arm: float) -> void:
	var t: Vector2 = tip.round(); var c := Color(col, clampf(alpha, 0.0, 1.0))
	draw_line(t, (t + Vector2(-arm, -arm)).round(), c, 1.0)
	draw_line(t, (t + Vector2(-arm, arm)).round(), c, 1.0)

func _draw_air_fx() -> void:
	if not visible or _air_fx == null: return
	var fred: bool = LxHudFx.flash_reduced()
	var c_gold: Color = PAL["gold"] as Color; var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color; var c_ice: Color = PAL["ice"] as Color
	if not _launching:
		for m: int in range(3):
			var u: float = fposmod(_clock * (0.28 if fred else 0.45) + float(m) * 0.333, 1.0)
			_air_fx.draw_rect(Rect2(roundf(COMPASS_POS.x + sin(_clock * 1.4 + float(m) * 2.1) * 12.0), roundf(COMPASS_POS.y + 5.0 - u * 22.0), 1.0, 1.0), Color(c_cream if u < 0.4 else c_gold, sin(u * PI) * 0.75))
		return
	if _launch_t < 0.52:
		var u_r: float = clampf(_launch_t / 0.52, 0.0, 1.0)
		_air_fx.draw_arc(COMPASS_POS, roundf(lerpf(6.0, 32.0 if fred else 38.0, u_r)), 0.0, TAU, 24, Color(c_cream if u_r < 0.35 else c_gold, (1.0 - u_r) * (0.65 if fred else 0.92)), 1.5)
	if _liftoff_fired:
		var u_l: float = clampf((_launch_t - PHASE2_END) / 0.42, 0.0, 1.0)
		if u_l < 1.0:
			_air_fx.draw_arc(ALIGN_POS, roundf(lerpf(5.0, 30.0 if fred else 38.0, u_l)), 0.0, TAU, 22, Color(c_gold, (1.0 - u_l) * 0.85), 1.5)
			_air_fx.draw_arc(ALIGN_POS, roundf(lerpf(3.0, 22.0, u_l)), 0.0, TAU, 18, Color(c_cream, (1.0 - u_l) * 0.90), 1.0)
	if _trail.size() >= 2:
		var n: int = _trail.size()
		for i: int in range(1, n):
			var frac: float = float(i) / float(n - 1)
			var p0: Vector2 = _trail[i - 1].round(); var p1: Vector2 = _trail[i].round()
			_air_fx.draw_line(p0, p1, Color(c_apricot if frac < 0.45 else c_gold, frac * 0.82), 3.0 if frac > 0.6 else 2.0)
			_air_fx.draw_line(p0, p1, Color(c_cream, frac * 0.94), 1.0)
		var head: Vector2 = _trail[n - 1].round()
		var u3: float = clampf((_launch_t - PHASE2_END) / (TOTAL_DUR - PHASE2_END), 0.0, 1.0)
		if u3 > 0.68:
			var star_a: float = sin(clampf((u3 - 0.68) / 0.32, 0.0, 1.0) * PI)
			var arm: float = roundf(lerpf(3.0, 7.0 if fred else 10.0, star_a))
			_air_fx.draw_line(head + Vector2(-arm, 0.0), head + Vector2(arm, 0.0), Color(c_cream, star_a), 1.0)
			_air_fx.draw_line(head + Vector2(0.0, -arm), head + Vector2(0.0, arm), Color(c_ice, star_a), 1.0)
			_air_fx.draw_rect(Rect2(head - Vector2.ONE, Vector2(2.0, 2.0)), Color(c_cream, star_a))
	for s: Dictionary in _sparks:
		var sa: float = 1.0 - clampf(float(s["age"]) / maxf(0.01, float(s["life"])), 0.0, 1.0)
		var sz: float = float(s["sz"])
		_air_fx.draw_rect(Rect2((s["pos"] as Vector2).round(), Vector2(sz, sz)), Color(PAL.get(str(s["col"]), c_gold) as Color, sa))
