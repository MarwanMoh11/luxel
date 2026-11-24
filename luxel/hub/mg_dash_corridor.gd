class_name LxMgDashCorridor
extends LxHubTrialBase
## Dash Corridor Minigame (kind "mg_dash_corridor") in the stone underpass (cave_1):
## Sweeps telegraphed energy waves along the corridor. Dashing through a wave during
## dash i-frames scores a PERFECT DODGE (+100 * streak) and refunds dash cooldown!

var dodges: int = 0
var streak: int = 0
var _waves: Array[Dictionary] = [] # {x, dir, speed, tell_t, hit_wick, dodged}
var _spawn_cd: float = 0.0
var _wave_idx: int = 0
var _prev_wick_pd: int = 0
var _wave_overlay: Node2D = null
var _corridor_rect: Rect2 = Rect2(64.0, 64.0, 416.0, 128.0)


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "mg_dash_corridor"
	mg_id = "dash_corridor"
	title_key = "HUB_MG_DASH"
	lower_is_better = false
	bronze_goal = 400.0
	silver_goal = 900.0
	gold_goal = 1500.0
	trial_time_limit = 35.0
	var r_v: Variant = props.get("rect", [64.0, 64.0, 416.0, 128.0])
	if r_v is Array and (r_v as Array).size() >= 4:
		var ra: Array = r_v as Array
		_corridor_rect = Rect2(float(ra[0]), float(ra[1]), float(ra[2]), float(ra[3]))
	queue_redraw()


func _exit_tree() -> void:
	_clear_overlay()
	super._exit_tree()


func _on_trial_start() -> void:
	dodges = 0
	streak = 0
	_waves.clear()
	_spawn_cd = 0.45
	_wave_idx = 0
	var w: LxWick = region.get_wick() if region != null else null
	_prev_wick_pd = w.perfect_dodges if w != null else 0
	_ensure_overlay()
	trial_subtext = "DODGE 0"


func _on_trial_end() -> void:
	_waves.clear()
	_clear_overlay()


func _on_trial_tick(dt: float) -> void:
	_spawn_cd -= dt
	if _spawn_cd <= 0.0:
		_spawn_wave()
		_spawn_cd = maxf(0.95, 1.85 - trial_elapsed * 0.025)
	var w: LxWick = region.get_wick() if region != null else null
	if w != null and w.perfect_dodges > _prev_wick_pd:
		var diff: int = w.perfect_dodges - _prev_wick_pd
		_prev_wick_pd = w.perfect_dodges
		for _k: int in range(diff):
			register_perfect_dodge(w)

	for i: int in range(_waves.size() - 1, -1, -1):
		var wv: Dictionary = _waves[i]
		if float(wv["tell_t"]) > 0.0:
			wv["tell_t"] = maxf(0.0, float(wv["tell_t"]) - dt)
			continue
		var dir_x: float = float(wv["dir"])
		var prev_x: float = float(wv["x"])
		var next_x: float = prev_x + dir_x * float(wv["speed"]) * dt
		wv["x"] = next_x
		if w != null and not bool(wv["dodged"]) and not bool(wv["hit_wick"]) and _corridor_rect.has_point(w.global_position):
			var crossed: bool = (prev_x - w.global_position.x) * (next_x - w.global_position.x) <= 0.0 or absf(next_x - w.global_position.x) <= 7.0
			if crossed:
				var in_iframe: bool = w.move_dash != null and (w.move_dash.iframes_left > 0.0 or w.move_dash.active)
				if in_iframe:
					wv["dodged"] = true
					register_perfect_dodge(w)
				else:
					wv["hit_wick"] = true
					streak = 0
					_emit_sfx("shield_clang")
					if w.has_method("spawn_ring"):
						w.spawn_ring(w.global_position, 2.0, 12.0, 0.16, LxPalette.PAL["coral"] as Color, 1.2)
		if next_x < _corridor_rect.position.x - 16.0 or next_x > _corridor_rect.end.x + 16.0:
			_waves.remove_at(i)
	trial_subtext = "DODGE %d x%d" % [dodges, streak]
	if _wave_overlay != null and is_instance_valid(_wave_overlay):
		_wave_overlay.queue_redraw()


func register_perfect_dodge(w: LxWick = null) -> void:
	if not trial_running:
		return
	dodges += 1
	streak += 1
	trial_score += float(100 + mini(streak - 1, 5) * 25)
	_emit_sfx("perfect_counter")
	if w != null:
		if w.move_dash != null:
			w.move_dash.cooldown_left = 0.0
		if w.has_method("spawn_ring"):
			w.spawn_ring(w.global_position, 3.0, 18.0, 0.22, LxPalette.PAL["gold"] as Color, 1.5)


func _spawn_wave() -> void:
	var from_left: bool = (_wave_idx % 2) == 0
	var spd: float = minf(240.0, 145.0 + float(_wave_idx) * 6.0)
	_waves.append({
		"x": _corridor_rect.position.x if from_left else _corridor_rect.end.x,
		"dir": 1.0 if from_left else -1.0,
		"speed": spd,
		"tell_t": 0.55,
		"hit_wick": false,
		"dodged": false,
	})
	_wave_idx += 1
	_emit_sfx("ui_move")


func _ensure_overlay() -> void:
	if region == null:
		return
	_clear_overlay()
	_wave_overlay = Node2D.new()
	_wave_overlay.name = "DashCorridorWaves"
	_wave_overlay.z_index = 4
	_wave_overlay.draw.connect(_draw_waves)
	region.add_child(_wave_overlay)


func _clear_overlay() -> void:
	if _wave_overlay != null and is_instance_valid(_wave_overlay):
		_wave_overlay.queue_free()
	_wave_overlay = null


func _draw_waves() -> void:
	if not trial_running or _wave_overlay == null:
		return
	var fred: bool = LxHudFx.flash_reduced()
	for wv: Dictionary in _waves:
		var wx: float = roundf(float(wv["x"]))
		var tell: float = float(wv["tell_t"])
		if tell > 0.0:
			var c: Color = LxPalette.PAL["apricot"] if fred else LxPalette.PAL["coral"]
			for sy: int in range(int(_corridor_rect.position.y), int(_corridor_rect.end.y), 10):
				_wave_overlay.draw_rect(Rect2(wx - 2.0, float(sy), 4.0, 5.0), c)
		else:
			var col: Color = LxPalette.PAL["lime"] if bool(wv["dodged"]) else LxPalette.PAL["coral"]
			_wave_overlay.draw_rect(Rect2(wx - 3.0, _corridor_rect.position.y, 6.0, _corridor_rect.size.y), LxPalette.PAL["void"])
			_wave_overlay.draw_rect(Rect2(wx - 2.0, _corridor_rect.position.y, 4.0, _corridor_rect.size.y), col)
			_wave_overlay.draw_rect(Rect2(wx - 1.0, _corridor_rect.position.y, 2.0, _corridor_rect.size.y), LxPalette.PAL["cream"])


func _get_plinth_icon() -> String: return "move_dash"
func _get_plinth_accent() -> String: return "rose"
