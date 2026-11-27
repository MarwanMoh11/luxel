class_name LxPollenRelay
extends Node2D
## 3-Bell Firefly Relay Trial + linked Golden Nectar Cache.
## Send Pip through Bells 1 -> 2 -> 3 before the timer fades to crack open the Golden Cache
## (+2 Nectar, +60 Shards, +1 Half Lantern). Strictly 20 Last Light colours & integer pixel-snapping.

const BASE_TIMER_S: float = 8.5
const BELL_HIT_PAD: float = 10.0

var relay_id: String = ""
var island_id: int = 1
var bells: Array[Vector2] = []
var cache_pos: Vector2 = Vector2.ZERO
var completed: bool = false

var _next_idx: int = 0
var _timer: float = 0.0
var _timer_max: float = BASE_TIMER_S
var _clock: float = 0.0
var _bell_ring_t: Array[float] = [0.0, 0.0, 0.0]
var _cache_burst_t: float = 0.0
var _fail_flash_t: float = 0.0
var _player_near: bool = false


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(spec: Dictionary) -> void:
	relay_id = str(spec.get("id", ""))
	island_id = clampi(int(spec.get("island", 1)), 1, 8)
	bells.clear()
	var raw_b: Variant = spec.get("bells", [])
	if raw_b is Array:
		for bv: Variant in (raw_b as Array):
			if bv is Vector2:
				bells.append((bv as Vector2).round())
			elif bv is Array and (bv as Array).size() >= 2:
				bells.append(Vector2(float((bv as Array)[0]), float((bv as Array)[1])).round())
	var raw_c: Variant = spec.get("cache_pos", Vector2.ZERO)
	if raw_c is Vector2:
		cache_pos = (raw_c as Vector2).round()
	elif raw_c is Array and (raw_c as Array).size() >= 2:
		cache_pos = Vector2(float((raw_c as Array)[0]), float((raw_c as Array)[1])).round()
	completed = LxFireflyState.is_relay_completed(relay_id)
	_next_idx = 0
	_timer = 0.0
	_timer_max = BASE_TIMER_S
	_bell_ring_t = [0.0, 0.0, 0.0]
	_cache_burst_t = 0.0
	_fail_flash_t = 0.0
	name = relay_id if not relay_id.is_empty() else "PollenRelay"
	queue_redraw()


func tick(dt: float, player_pos: Vector2) -> void:
	_clock += dt
	for i: int in range(_bell_ring_t.size()):
		_bell_ring_t[i] = maxf(0.0, _bell_ring_t[i] - dt)
	_cache_burst_t = maxf(0.0, _cache_burst_t - dt)
	_fail_flash_t = maxf(0.0, _fail_flash_t - dt)
	_player_near = player_pos.is_finite() and player_pos.distance_squared_to(cache_pos) <= 220.0 * 220.0
	if not completed and _next_idx > 0 and _timer > 0.0:
		_timer -= dt
		if _timer <= 0.0:
			_next_idx = 0
			_timer = 0.0
			_fail_flash_t = 0.50
			if Lx.events != null:
				Lx.events.sfx_requested.emit("denied", cache_pos, true)
				Lx.events.narration_requested.emit("PIP_RELAY_FAIL", "warning", 2.2)
	queue_redraw()


func on_pip_pass(pip_pos: Vector2, prev_pos: Vector2, radius: float) -> bool:
	if completed or bells.size() < 3:
		return false
	var idx: int = clampi(_next_idx, 0, bells.size() - 1)
	var bpos: Vector2 = bells[idx]
	if Geometry2D.get_closest_point_to_segment(bpos, prev_pos, pip_pos).distance_to(bpos) > radius + BELL_HIT_PAD:
		return false
	_bell_ring_t[idx] = 0.65
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(bpos, 64.0, 0.85 if LxHudFx.flash_reduced() else 1.20, 0.36)
	if idx == 0:
		var assist_s: float = clampf(float(Lx.save.settings.get("assist_tell_scale", 1.0)), 1.0, 1.5) if Lx.save != null else 1.0
		_timer_max = BASE_TIMER_S * assist_s
		_timer = _timer_max
		if Lx.events != null:
			Lx.events.narration_requested.emit("PIP_RELAY_START", "narration", 2.4)
	_next_idx += 1
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_bloom", bpos, true)
	if _next_idx >= bells.size():
		_complete_trial()
	queue_redraw()
	return true


func _complete_trial() -> void:
	completed = true
	_timer = 0.0
	_cache_burst_t = 1.0
	var res: Dictionary = LxFireflyState.complete_relay(relay_id)
	if Lx.state != null:
		Lx.state.add_shards(60)
		Lx.state.add_half_lantern()
	elif Lx.events != null:
		Lx.events.shard_collected.emit(60)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(cache_pos, 112.0, 0.90 if LxHudFx.flash_reduced() else 1.38, 0.65)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_bond_up", cache_pos, false)
		Lx.events.narration_requested.emit("PIP_RELAY_CLEAR", "title", 3.0)
		Lx.events.save_requested.emit("pip_relay")
	if bool(res.get("ranked_up", false)):
		var rank: int = int(res.get("rank", LxFireflyState.get_bond_rank()))
		var desc_key: String = LxFireflyState.get_bond_desc_key(rank)
		var nar: Object = Lx.ui.get("narration") as Object if (Lx.ui != null and Lx.ui.get("narration") is Object) else null
		if nar != null and is_instance_valid(nar) and nar.has_method("say_lines"):
			var lines := PackedStringArray([LxStrings.fmt("PIP_BOND_UP_FMT", [rank])])
			if not desc_key.is_empty():
				lines.append(LxStrings.text(desc_key))
			nar.call("say_lines", lines, "title", 3.2, -1.0, 1, "title")


func get_light_pools() -> Array[Vector4]:
	var pools: Array[Vector4] = []
	for i: int in range(bells.size()):
		var bp: Vector2 = bells[i]
		if completed or i < _next_idx:
			pools.append(Vector4(bp.x, bp.y - 6.0, 42.0, 0.80))
		elif i == _next_idx:
			pools.append(Vector4(bp.x, bp.y - 6.0, 34.0, 0.65))
	pools.append(Vector4(cache_pos.x, cache_pos.y - 4.0, 56.0 if completed else 36.0, 0.95 if completed else 0.58))
	return pools


func find_nearest_active_bell(from_pos: Vector2, max_dist: float) -> Vector2:
	if completed or bells.is_empty():
		return Vector2.INF
	var target: Vector2 = bells[clampi(_next_idx, 0, bells.size() - 1)]
	return target if from_pos.distance_to(target) <= max_dist else Vector2.INF


func _draw() -> void:
	if bells.size() < 3:
		return
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var fred: bool = LxHudFx.flash_reduced()

	# Dotted lime-gold sightline toward active next bell
	if not completed and (_next_idx > 0 or _player_near):
		var start_p: Vector2 = bells[_next_idx - 1] if _next_idx > 0 else cache_pos
		var end_p: Vector2 = bells[clampi(_next_idx, 0, bells.size() - 1)]
		_draw_sightline(start_p + Vector2(0.0, -6.0), end_p + Vector2(0.0, -6.0), fred)

	# Draw the 3 hovering brass-and-pollen bells
	for i: int in range(bells.size()):
		_draw_bell(bells[i], i, fred)

	# Draw Golden Nectar Cache chalice/chest
	_draw_cache(fred)


func _draw_sightline(a: Vector2, b: Vector2, fred: bool) -> void:
	var pal: Dictionary = LxPalette.PAL
	var delta: Vector2 = b - a
	var dist: float = delta.length()
	if dist < 8.0:
		return
	var sdir: Vector2 = delta / dist
	var step: float = 8.0
	var cursor: float = fmod(_clock * (8.0 if fred else 18.0), step)
	var k: int = 0
	while cursor < dist:
		var pt: Vector2 = (a + sdir * cursor).round()
		draw_rect(Rect2(pt - Vector2.ONE, Vector2(3.0, 3.0)), pal["void"] as Color)
		draw_rect(Rect2(pt, Vector2.ONE), (pal["lime"] if (k % 2 == 0) else pal["gold"]) as Color)
		cursor += step
		k += 1


func _draw_bell(bp: Vector2, idx: int, fred: bool) -> void:
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var rung: bool = completed or idx < _next_idx
	var is_next: bool = (not completed) and idx == _next_idx
	var ring_t: float = _bell_ring_t[idx] if idx < _bell_ring_t.size() else 0.0
	var bob: float = 0.0 if fred else roundf(sin(_clock * (10.0 if ring_t > 0.0 else 3.2) + float(idx) * 1.4) * (2.0 if ring_t > 0.0 else 1.0))
	var c := (bp + Vector2(0.0, -7.0 + bob)).round()

	# Ground shadow
	draw_rect(Rect2(bp + Vector2(-3.0, 1.0), Vector2(6.0, 2.0)), void_c)
	# Countdown arc around active next bell
	if is_next and _next_idx > 0 and _timer > 0.0:
		var frac: float = clampf(_timer / maxf(0.1, _timer_max), 0.0, 1.0)
		var arc_c: Color = (pal["coral"] if frac < 0.28 else pal["lime"]) as Color
		draw_arc(c, 9.0, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(c, 9.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, arc_c, 1.0)

	# Bell body (void outline + brass/pollen shell)
	draw_rect(Rect2(c + Vector2(-4.0, -4.0), Vector2(9.0, 8.0)), void_c)
	draw_rect(Rect2(c + Vector2(-5.0, 1.0), Vector2(11.0, 3.0)), void_c)
	var body_c: Color = (pal["coral"] if _fail_flash_t > 0.0 else (pal["gold"] if rung else (pal["apricot"] if is_next else pal["mauve"]))) as Color
	var hi_c: Color = (pal["cream"] if (ring_t > 0.0 or rung) else (pal["lime"] if is_next else pal["stone"])) as Color
	draw_rect(Rect2(c + Vector2(-3.0, -3.0), Vector2(7.0, 6.0)), body_c)
	draw_rect(Rect2(c + Vector2(-4.0, 2.0), Vector2(9.0, 1.0)), body_c)
	draw_rect(Rect2(c + Vector2(-1.0, -3.0), Vector2(2.0, 4.0)), hi_c)
	draw_rect(Rect2(c + Vector2(0.0, 3.0), Vector2(1.0, 1.0)), pal["cream"] as Color if rung else pal["gold"] as Color)

	# 1 / 2 / 3 pip sequence indicator below bell
	var pip_n: int = idx + 1
	var px0: float = bp.x - float(pip_n * 2 - 1)
	var pip_c: Color = (pal["lime"] if rung else (pal["gold"] if is_next else pal["stone"])) as Color
	draw_rect(Rect2(px0 - 1.0, bp.y + 3.0, float(pip_n * 4) - 1.0, 3.0), void_c)
	for p: int in range(pip_n):
		draw_rect(Rect2(px0 + float(p * 4), bp.y + 4.0, 2.0, 1.0), pip_c)

	if ring_t > 0.0:
		var ru: float = 1.0 - clampf(ring_t / 0.65, 0.0, 1.0)
		var rr: float = roundf(lerpf(5.0, 18.0, ru))
		draw_arc(c, rr, 0.0, TAU, 14, void_c, 3.0)
		draw_arc(c, rr, 0.0, TAU, 14, (pal["cream"] if ru < 0.35 else pal["lime"]) as Color, 1.0)


func _draw_cache(fred: bool) -> void:
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var cp: Vector2 = cache_pos.round()
	# Ground plinth & void silhouette
	draw_rect(Rect2(cp + Vector2(-6.0, -7.0), Vector2(12.0, 10.0)), void_c)
	draw_rect(Rect2(cp + Vector2(-5.0, -6.0), Vector2(10.0, 8.0)), pal["dusk"] as Color)
	draw_rect(Rect2(cp + Vector2(-4.0, -5.0), Vector2(8.0, 6.0)), pal["apricot"] as Color if completed else pal["plum"] as Color)
	draw_rect(Rect2(cp + Vector2(-4.0, -5.0), Vector2(8.0, 2.0)), pal["gold"] as Color if completed else pal["mauve"] as Color)
	if completed:
		var shimmer: bool = fred or (int(floorf(_clock * 4.0)) % 2 == 0)
		draw_rect(Rect2(cp + Vector2(-2.0, -8.0), Vector2(4.0, 4.0)), void_c)
		draw_rect(Rect2(cp + Vector2(-1.0, -7.0), Vector2(2.0, 2.0)), pal["cream"] as Color if shimmer else pal["gold"] as Color)
		draw_rect(Rect2(cp + Vector2(-2.0, -3.0), Vector2(4.0, 2.0)), pal["lime"] as Color)
	else:
		draw_rect(Rect2(cp + Vector2(-1.0, -3.0), Vector2(2.0, 2.0)), pal["gold"] as Color)
		draw_rect(Rect2(cp + Vector2(0.0, -3.0), Vector2.ONE), pal["cream"] as Color)
	if _cache_burst_t > 0.0:
		var u: float = 1.0 - clampf(_cache_burst_t, 0.0, 1.0)
		var r: float = roundf(lerpf(6.0, 28.0, u))
		draw_arc(cp + Vector2(0.0, -3.0), r, 0.0, TAU, 18, void_c, 3.0)
		draw_arc(cp + Vector2(0.0, -3.0), r, 0.0, TAU, 18, (pal["cream"] if u < 0.35 else pal["gold"]) as Color, 2.0)
