class_name LxPipTrial
extends Node2D
## Repeatable Wick House Hub (0:overworld) Pollen Flight Trial score-attack minigame.
## Mounted by LxFireflyWorldContent beside the Pip Terrarium.
## Strictly 20 Last Light colours (LxPalette.PAL), integer pixel-snapping, manual aim only.

const AIM_ASSIST_ENABLED: bool = false
const PEDESTAL_POS: Vector2 = Vector2(264.0, 152.0)
const TRIAL_DURATION_S: float = 35.0
const COMBO_DECAY_S: float = 4.5
const TARGET_LIFE_S: float = 6.8
const TARGET_MAX_ACTIVE: int = 2
const BRONZE_SCORE: int = 600
const SILVER_SCORE: int = 1200
const GOLD_SCORE: int = 2000
const RING_BASE_PTS: int = 100
const BELL_BASE_PTS: int = 150
const SPAWN_SPOTS: Array[Vector2] = [
	Vector2(200.0, 152.0), Vector2(296.0, 152.0), Vector2(296.0, 168.0), Vector2(200.0, 184.0),
	Vector2(264.0, 184.0), Vector2(296.0, 120.0), Vector2(200.0, 120.0), Vector2(184.0, 232.0),
	Vector2(312.0, 232.0), Vector2(152.0, 184.0), Vector2(328.0, 200.0), Vector2(248.0, 216.0),
]

var trial_running: bool = false
var time_left: float = 0.0
var score: int = 0
var combo: int = 1
var hits_count: int = 0
var active_targets: Array[Dictionary] = []

var _combo_t: float = 0.0
var _clock: float = 0.0
var _ped_cd: float = 0.0
var _spawn_seq: int = 0
var _pop_fx: Array[Dictionary] = []
var _hud_layer: CanvasLayer = null
var _hud_draw: Node2D = null

func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name = "LxPipTrial"
	queue_redraw()

func _exit_tree() -> void:
	teardown()

func teardown() -> void:
	trial_running = false; time_left = 0.0; _combo_t = 0.0
	active_targets.clear(); _pop_fx.clear()
	if _hud_draw != null and is_instance_valid(_hud_draw) and _hud_draw.draw.is_connected(_draw_hud_overlay):
		_hud_draw.draw.disconnect(_draw_hud_overlay)
	_hud_draw = null
	if _hud_layer != null and is_instance_valid(_hud_layer):
		var par: Node = _hud_layer.get_parent()
		if par != null: par.remove_child(_hud_layer)
		if not _hud_layer.is_queued_for_deletion(): _hud_layer.free()
	_hud_layer = null

func start_trial() -> bool:
	if not LxFireflyState.is_joined(): return false
	trial_running = true; time_left = TRIAL_DURATION_S
	score = 0; combo = 1; _combo_t = 0.0; hits_count = 0; _spawn_seq = 0
	active_targets.clear(); _pop_fx.clear()
	for _i: int in range(TARGET_MAX_ACTIVE): _spawn_target()
	_ensure_hud()
	if _hud_layer != null and is_instance_valid(_hud_layer): _hud_layer.visible = true
	if _hud_draw != null and is_instance_valid(_hud_draw):
		_hud_draw.visible = true; _hud_draw.queue_redraw()
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(PEDESTAL_POS, 76.0, 0.85 if LxHudFx.flash_reduced() else 1.22, 0.40)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_bond_up", PEDESTAL_POS, true)
		Lx.events.narration_requested.emit("PIP_TRIAL_START", "title", 2.2)
	queue_redraw()
	return true

func stop_trial(completed: bool, override_score: int = -1) -> Dictionary:
	if override_score >= 0: score = override_score
	trial_running = false; time_left = 0.0; _combo_t = 0.0
	active_targets.clear()
	if _hud_layer != null and is_instance_valid(_hud_layer): _hud_layer.visible = false
	queue_redraw()
	if not completed: return {"completed": false, "score": score, "medal": 0}
	var res: Dictionary = LxFireflyState.record_trial_result(score)
	var medal: int = clampi(int(res.get("medal", 0)), 0, 3)
	var prev_medal: int = clampi(int(res.get("prev_medal", 0)), 0, 3)
	var shard_gain: int = 0
	if medal >= 1 and prev_medal < 1: shard_gain += 25
	if medal >= 2 and prev_medal < 2: shard_gain += 50
	if medal >= 3 and prev_medal < 3: shard_gain += 100
	if medal >= 1 and shard_gain == 0: shard_gain = 10
	if shard_gain > 0:
		if Lx.state != null: Lx.state.add_shards(shard_gain)
		elif Lx.events != null: Lx.events.shard_collected.emit(shard_gain)
	var medal_key: String = "PIP_TRIAL_MEDAL_%d" % medal
	var nar: Object = Lx.ui.get("narration") as Object if (Lx.ui != null and Lx.ui.get("narration") is Object) else null
	if nar != null and is_instance_valid(nar) and nar.has_method("say_lines"):
		var line: String = LxStrings.fmt("PIP_TRIAL_DONE_FMT", [score, LxStrings.text(medal_key)])
		nar.call("say_lines", PackedStringArray([line]), "title", 3.2, -1.0, 1, "title")
	elif Lx.events != null:
		Lx.events.narration_requested.emit(medal_key, "title", 3.0)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_bond_up" if medal >= 1 else "denied", PEDESTAL_POS, false)
		Lx.events.save_requested.emit("pip_trial")
	return res

func tick(dt: float, _player_pos: Vector2) -> void:
	_clock += dt
	_ped_cd = maxf(0.0, _ped_cd - dt)
	for i: int in range(_pop_fx.size() - 1, -1, -1):
		var fx: Dictionary = _pop_fx[i]
		var age: float = float(fx["age"]) + dt
		if age >= float(fx["dur"]): _pop_fx.remove_at(i)
		else: fx["age"] = age
	if trial_running:
		time_left -= dt
		if time_left <= 0.0:
			stop_trial(true); queue_redraw(); return
		if _combo_t > 0.0:
			_combo_t -= dt
			if _combo_t <= 0.0: _combo_t = 0.0; combo = 1
		for i: int in range(active_targets.size() - 1, -1, -1):
			var t: Dictionary = active_targets[i]
			var age: float = float(t["age"]) + dt
			t["age"] = age
			if age >= float(t["life"]):
				active_targets.remove_at(i); combo = 1; _combo_t = 0.0
		while active_targets.size() < TARGET_MAX_ACTIVE: _spawn_target()
		if _hud_draw != null and is_instance_valid(_hud_draw):
			var modal_open: bool = Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open"))
			_hud_draw.visible = not modal_open
			_hud_draw.queue_redraw()
	queue_redraw()

func on_pip_pass(pip_pos: Vector2, prev_pos: Vector2, radius: float, _pip: Node) -> bool:
	if not trial_running:
		if _ped_cd <= 0.0 and LxFireflyState.is_joined():
			if Geometry2D.get_closest_point_to_segment(PEDESTAL_POS, prev_pos, pip_pos).distance_to(PEDESTAL_POS) <= radius + 12.0:
				_ped_cd = 0.75; return start_trial()
		return false
	for i: int in range(active_targets.size() - 1, -1, -1):
		var t: Dictionary = active_targets[i]
		var tpos: Vector2 = t["pos"] as Vector2
		if Geometry2D.get_closest_point_to_segment(tpos, prev_pos, pip_pos).distance_to(tpos) <= radius + float(t["radius"]):
			_score_target(i); return true
	return false

func try_interact(_actor: Node, actor_pos: Vector2, reach: float = 24.0) -> bool:
	if actor_pos.distance_to(PEDESTAL_POS) <= reach + 10.0:
		if trial_running: stop_trial(false); return true
		_ped_cd = 0.75; return start_trial()
	return false

func get_interact_prompt_info(actor_pos: Vector2, reach: float = 24.0) -> Dictionary:
	if LxFireflyState.is_joined() and actor_pos.distance_to(PEDESTAL_POS) <= reach + 10.0:
		return {"prompt": "PIP_TRIAL_STOP" if trial_running else "PIP_TRIAL_PROMPT", "pos": PEDESTAL_POS}
	return {}

func get_light_pools() -> Array[Vector4]:
	var out: Array[Vector4] = [Vector4(PEDESTAL_POS.x, PEDESTAL_POS.y - 8.0, 62.0 if trial_running else 48.0, 0.96 if trial_running else 0.78)]
	if trial_running:
		for t: Dictionary in active_targets:
			var tp: Vector2 = t["pos"] as Vector2
			var is_bell: bool = str(t["kind"]) == "bell"
			out.append(Vector4(tp.x, tp.y - 6.0, 52.0 if is_bell else 46.0, 0.92 if is_bell else 0.82))
	return out

func _ensure_hud() -> void:
	if _hud_layer == null or not is_instance_valid(_hud_layer):
		_hud_layer = CanvasLayer.new()
		_hud_layer.name = "LxPipTrialHudLayer"; _hud_layer.layer = 18
		add_child(_hud_layer)
	if _hud_draw == null or not is_instance_valid(_hud_draw):
		_hud_draw = Node2D.new()
		_hud_draw.name = "LxPipTrialHudDraw"; _hud_draw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hud_draw.draw.connect(_draw_hud_overlay)
		_hud_layer.add_child(_hud_draw)

func _spawn_target() -> void:
	var n: int = SPAWN_SPOTS.size()
	var spot_idx: int = (_spawn_seq * 5) % n
	for _tries: int in range(n):
		var taken: bool = false
		for t: Dictionary in active_targets:
			if int(t["spot_idx"]) == spot_idx: taken = true; break
		if not taken: break
		spot_idx = (spot_idx + 1) % n
	var is_bell: bool = (_spawn_seq % 3 == 2)
	var assist_s: float = clampf(float(Lx.save.settings.get("assist_tell_scale", 1.0)), 1.0, 1.5) if Lx.save != null else 1.0
	active_targets.append({
		"pos": SPAWN_SPOTS[spot_idx].round(), "kind": "bell" if is_bell else "ring",
		"radius": 11.0 if is_bell else 13.0, "age": 0.0, "life": TARGET_LIFE_S * assist_s, "spot_idx": spot_idx,
	})
	_spawn_seq += 1

func _score_target(idx: int) -> void:
	var t: Dictionary = active_targets[idx]
	var tpos: Vector2 = t["pos"] as Vector2
	var kind: String = str(t["kind"])
	score += (BELL_BASE_PTS if kind == "bell" else RING_BASE_PTS) * combo
	hits_count += 1; combo = mini(4, combo + 1); _combo_t = COMBO_DECAY_S
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(tpos, 72.0 if kind == "bell" else 60.0, 0.85 if LxHudFx.flash_reduced() else 1.25, 0.38)
	_pop_fx.append({"pos": tpos, "age": 0.0, "dur": 0.55, "kind": kind})
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_bloom" if kind == "bell" else "pip_tag", tpos, true)
	active_targets.remove_at(idx)
	_spawn_target()
	if _hud_draw != null and is_instance_valid(_hud_draw): _hud_draw.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var fred: bool = LxHudFx.flash_reduced()
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var p: Vector2 = PEDESTAL_POS.round()
	var best_m: int = LxFireflyState.get_trial_medal()
	var jewel_k: String = "gold" if best_m >= 3 else ("ice" if best_m == 2 else ("apricot" if best_m == 1 else "dusk"))
	if trial_running:
		var pulse: bool = fred or (int(floorf(_clock * 5.0)) % 2 == 0)
		draw_arc(p + Vector2(0.0, -11.0), 10.0, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(p + Vector2(0.0, -11.0), 10.0, 0.0, TAU, 16, (pal["lime"] if pulse else pal["gold"]) as Color, 1.0)
	draw_rect(Rect2(p + Vector2(-6.0, -2.0), Vector2(12.0, 5.0)), void_c)
	draw_rect(Rect2(p + Vector2(-4.0, -16.0), Vector2(8.0, 15.0)), void_c)
	draw_rect(Rect2(p + Vector2(-5.0, -14.0), Vector2(10.0, 6.0)), void_c)
	draw_rect(Rect2(p + Vector2(-5.0, -1.0), Vector2(10.0, 3.0)), pal["dusk"] as Color)
	draw_rect(Rect2(p + Vector2(-4.0, -1.0), Vector2(8.0, 1.0)), pal["apricot"] as Color)
	draw_rect(Rect2(p + Vector2(-3.0, -8.0), Vector2(6.0, 7.0)), pal["night"] as Color)
	draw_rect(Rect2(p + Vector2(-2.0, -8.0), Vector2(4.0, 6.0)), pal["dusk"] as Color)
	draw_rect(Rect2(p + Vector2(-2.0, -8.0), Vector2(1.0, 5.0)), pal["mauve"] as Color)
	draw_rect(Rect2(p + Vector2(-4.0, -13.0), Vector2(8.0, 4.0)), pal["plum"] as Color)
	draw_rect(Rect2(p + Vector2(-3.0, -15.0), Vector2(6.0, 2.0)), pal["apricot"] as Color)
	draw_rect(Rect2(p + Vector2(-2.0, -13.0), Vector2(4.0, 4.0)), pal["night"] as Color)
	draw_rect(Rect2(p + Vector2(-1.0, -12.0), Vector2(2.0, 2.0)), pal[jewel_k] as Color)
	if best_m >= 1 or trial_running:
		draw_rect(Rect2(p + Vector2(-1.0, -12.0), Vector2.ONE), pal["cream"] as Color)
	for m_i: int in range(3):
		var mc: Color = (pal["apricot"] if m_i == 0 else (pal["ice"] if m_i == 1 else pal["gold"])) as Color if m_i < best_m else (pal["night"] as Color)
		draw_rect(Rect2(p + Vector2(-4.0 + float(m_i * 3), 0.0), Vector2(2.0, 1.0)), mc)
	if trial_running:
		for t: Dictionary in active_targets: _draw_target(t, fred, pal, void_c)
	for fx: Dictionary in _pop_fx:
		var u: float = clampf(float(fx["age"]) / maxf(0.05, float(fx["dur"])), 0.0, 1.0)
		var r: float = roundf(lerpf(5.0, 22.0, u))
		var fp: Vector2 = (fx["pos"] as Vector2).round() + Vector2(0.0, -7.0)
		var fc: Color = (pal["cream"] if u < 0.35 else (pal["gold"] if str(fx["kind"]) == "bell" else pal["lime"])) as Color
		draw_arc(fp, r, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(fp, r, 0.0, TAU, 16, fc, 1.0)

func _draw_target(t: Dictionary, fred: bool, pal: Dictionary, void_c: Color) -> void:
	var tp: Vector2 = (t["pos"] as Vector2).round()
	var is_bell: bool = str(t["kind"]) == "bell"
	var frac: float = clampf(1.0 - float(t["age"]) / maxf(0.1, float(t["life"])), 0.0, 1.0)
	var bob: float = 0.0 if fred else roundf(sin(_clock * 4.2 + float(int(t["spot_idx"]))) * 1.5)
	var c: Vector2 = (tp + Vector2(0.0, -7.0 + bob)).round()
	draw_rect(Rect2(tp + Vector2(-4.0, 1.0), Vector2(8.0, 2.0)), void_c)
	var arc_r: float = 10.0 if is_bell else 12.0
	var arc_c: Color = (pal["coral"] if frac < 0.28 else (pal["gold"] if is_bell else pal["lime"])) as Color
	draw_arc(c, arc_r, 0.0, TAU, 18, void_c, 3.0)
	draw_arc(c, arc_r, -PI * 0.5, -PI * 0.5 + TAU * frac, 18, arc_c, 1.0)
	if is_bell:
		draw_rect(Rect2(c + Vector2(-4.0, -5.0), Vector2(9.0, 8.0)), void_c)
		draw_rect(Rect2(c + Vector2(-5.0, 0.0), Vector2(11.0, 3.0)), void_c)
		draw_rect(Rect2(c + Vector2(-3.0, -4.0), Vector2(7.0, 6.0)), pal["gold"] as Color)
		draw_rect(Rect2(c + Vector2(-4.0, 1.0), Vector2(9.0, 1.0)), pal["gold"] as Color)
		draw_rect(Rect2(c + Vector2(2.0, -3.0), Vector2(2.0, 4.0)), pal["apricot"] as Color)
		draw_rect(Rect2(c + Vector2(-2.0, -3.0), Vector2(2.0, 4.0)), pal["cream"] as Color)
		draw_rect(Rect2(c + Vector2(0.0, 2.0), Vector2.ONE), pal["cream"] as Color)
	else:
		draw_arc(c, 9.0, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(c, 9.0, 0.0, TAU, 16, pal["sky"] as Color, 1.0)
		draw_arc(c, 6.0, 0.0, TAU, 14, void_c, 3.0)
		draw_arc(c, 6.0, 0.0, TAU, 14, pal["lime"] as Color, 1.0)
		var pulse_c: bool = fred or (int(floorf(_clock * 6.0 + float(int(t["spot_idx"])))) % 2 == 0)
		draw_rect(Rect2(c - Vector2.ONE, Vector2(3.0, 3.0)), void_c)
		draw_rect(Rect2(c, Vector2.ONE), (pal["cream"] if pulse_c else pal["ice"]) as Color)

func _draw_hud_overlay() -> void:
	if not trial_running or _hud_draw == null or not is_instance_valid(_hud_draw): return
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var low_t: bool = time_left <= 6.0
	var pulse_low: bool = low_t and (fred or (int(floorf(_clock * 6.0)) % 2 == 0))
	_hud_draw.draw_rect(Rect2(82.0, 18.0, 156.0, 13.0), void_c)
	_hud_draw.draw_rect(Rect2(83.0, 19.0, 154.0, 11.0), (pal["coral"] if pulse_low else pal["gold"]) as Color)
	_hud_draw.draw_rect(Rect2(84.0, 20.0, 152.0, 9.0), pal["night"] as Color)
	var bar_w: float = floorf(150.0 * clampf(time_left / TRIAL_DURATION_S, 0.0, 1.0))
	_hud_draw.draw_rect(Rect2(85.0, 28.0, 150.0, 1.0), pal["dusk"] as Color)
	if bar_w > 0.0:
		_hud_draw.draw_rect(Rect2(85.0, 28.0, bar_w, 1.0), (pal["coral"] if low_t else pal["lime"]) as Color)
	var tenths_tot: int = int(floorf(maxf(0.0, time_left) * 10.0))
	var hud_txt: String = LxStrings.fmt("PIP_TRIAL_HUD_FMT", [tenths_tot / 10, tenths_tot % 10, score])
	LxPixelFont.draw_centered(_hud_draw, hud_txt, 150.0 if combo > 1 else 160.0, 21.0, (pal["coral"] if pulse_low else pal["cream"]) as Color, 1, void_c)
	if combo > 1:
		var badge_c: Color = (pal["gold"] if combo >= 4 else (pal["sky"] if combo == 3 else pal["lime"])) as Color
		_hud_draw.draw_rect(Rect2(217.0, 20.0, 1.0, 8.0), void_c)
		_hud_draw.draw_rect(Rect2(218.0, 20.0, 17.0, 8.0), pal["dusk"] as Color)
		LxPixelFont.draw_centered(_hud_draw, LxStrings.fmt("PIP_TRIAL_COMBO_FMT", [combo]), 227.0, 21.0, badge_c, 1, void_c)
