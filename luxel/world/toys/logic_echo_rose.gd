class_name LxEchoRose
extends LxToy
## Time-loop Echo Rose: records `secs` of Wick's positions, facing, and shots, then replays an Echo
## that presses pressure plates/scales, fires echo bolts (which bend in fields and bank off mirrors/
## blue_transformers), and acts as a targetable decoy for both enemies and bosses.
## Supports up to MAX_ACTIVE_ECHOES (3) simultaneous playing echoes per room (FIFO cap).
## Props: secs (float, default 6.0), loop (bool, default true), max_echoes (int, default 3),
## persist (bool), target_id/target_ids.

signal echo_hit(attacker: Object, hit_pos: Vector2)

enum Mode { IDLE, RECORDING, PLAYING }

const SAMPLE_HZ: float = 30.0
const ECHO_BOLT_SPEED: float = 280.0
const ECHO_BOLT_RANGE: float = 128.0
const ECHO_BOLT_MAX_BOUNCES: int = 3
const MAX_ACTIVE_ECHOES: int = 3
const HOUR_TWO_BLOOM_SECS: float = 8.0
const PLAYBACK_GRACE_SECS: float = 1.0

static var _seq_counter: int = 0

var secs: float = 6.0
var loop_replay: bool = true
var max_echoes: int = MAX_ACTIVE_ECHOES
var mode: int = Mode.IDLE

var echo_pos: Vector2 = Vector2.ZERO
var echo_facing: Vector2 = Vector2.RIGHT
var echo_active: bool = false
var echo_slot_index: int = 1

var _play_seq: int = 0
var _active_rec_secs: float = 6.0
var _rec_t: float = 0.0
var _play_t: float = 0.0
var _sample_accum: float = 0.0
var _last_shots: int = 0
var _samples: Array[Dictionary] = [] # [{t, pos, facing, shot}]
var _next_shot_idx: int = 0
var _bolts: Array[Dictionary] = []   # [{pos, prev, dir, dist, max_range, hit_ids, bounces, color, is_prism, curve_deg}]
var _cd: float = 0.0
var _disperse_t: float = 0.0
var _play_grace_t: float = 0.0


func _toy_setup() -> void:
	kind = "echo_rose"
	secs = maxf(0.5, float(props.get("secs", 6.0)))
	loop_replay = bool(props.get("loop", true))
	max_echoes = clampi(int(props.get("max_echoes", MAX_ACTIVE_ECHOES)), 1, MAX_ACTIVE_ECHOES)
	radius = maxf(12.0, radius)
	mode = Mode.IDLE
	echo_active = false
	echo_pos = pos
	echo_facing = Vector2.RIGHT
	echo_slot_index = 1
	_play_seq = 0
	_active_rec_secs = secs
	_samples.clear()
	_bolts.clear()
	_rec_t = 0.0
	_play_t = 0.0
	_cd = 0.0
	_disperse_t = 0.0
	_play_grace_t = 0.0
	add_to_group("lx_echo_decoys")
	add_to_group("lx_boss_targets")
	queue_redraw()


func reset_toy() -> void:
	stop_echo()


func stop_echo() -> void:
	mode = Mode.IDLE
	echo_active = false
	_play_seq = 0
	_samples.clear()
	_bolts.clear()
	_rec_t = 0.0
	_play_t = 0.0
	_disperse_t = 0.0
	_play_grace_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	_refresh_region_slot_indices()
	queue_redraw()


func is_echo_active() -> bool:
	return active and mode == Mode.PLAYING and echo_active


func is_boss_targetable() -> bool:
	return is_echo_active() and _disperse_t <= 0.0


func get_echo_pos() -> Vector2:
	return echo_pos


func get_echo_facing() -> Vector2:
	return echo_facing


func get_echo_radius() -> float:
	return 8.0


func get_echo_samples() -> Array[Dictionary]:
	return _samples.duplicate(true)


func get_effective_secs() -> float:
	if island_id == 4 and secs >= 2.0:
		var hr: int = int(LxToyDraw.world_get_var("island:4", "dusk_hour", 1))
		if hr == 2:
			return maxf(secs, HOUR_TWO_BLOOM_SECS)
	return secs


static func get_active_echoes_in_region(reg: Node) -> Array[LxEchoRose]:
	var out: Array[LxEchoRose] = []
	if reg == null or not is_instance_valid(reg) or not reg.has_method("get_interactables"):
		return out
	for it_v: Variant in (reg.call("get_interactables") as Array):
		if it_v is LxEchoRose and is_instance_valid(it_v):
			var r: LxEchoRose = it_v as LxEchoRose
			if r.is_echo_active():
				out.append(r)
	out.sort_custom(func(a: LxEchoRose, b: LxEchoRose) -> bool: return a._play_seq < b._play_seq)
	return out


## Allows enemies and bosses targeting the echo decoy to strike/disperse it harmlessly (then it loops).
func take_echo_hit(hit: Variant = null) -> int:
	if not is_echo_active():
		return -1
	var atk: Object = null
	var atk_v: Variant = (hit as Object).get("attacker") if (is_instance_valid(hit) and hit is Object) else ((hit as Dictionary).get("attacker") if hit is Dictionary else null)
	if is_instance_valid(atk_v) and atk_v is Object:
		atk = atk_v as Object
	_disperse_t = 0.35
	_emit_sfx("prop_rustle")
	echo_hit.emit(atk, echo_pos)
	if region != null and is_instance_valid(region) and region.has_method("notify"):
		region.call("notify", "echo_hit", {"rose_id": id, "pos": echo_pos, "attacker": atk})
	queue_redraw()
	return 1


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _cd > 0.0:
		return false
	if hit.attacker == self or hit.attacker is LxEchoRose:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return _activate()
	return false


func interact(_actor: Node = null) -> bool:
	if not active or _cd > 0.0:
		return false
	return _activate()


func get_interact_prompt() -> String:
	return "PROMPT_ECHO_ROSE" if active else ""


func _activate() -> bool:
	_cd = 0.30
	if mode == Mode.RECORDING and _rec_t >= 0.35 and not _samples.is_empty():
		_start_playback()
		return true
	if mode == Mode.PLAYING and echo_active and _play_grace_t > 0.0:
		return true
	_start_recording()
	return true


func _start_recording() -> void:
	mode = Mode.RECORDING
	echo_active = false
	_play_grace_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	_active_rec_secs = get_effective_secs()
	_samples.clear()
	_bolts.clear()
	_rec_t = 0.0
	_sample_accum = 0.0
	_last_shots = _read_wick_shots()
	_record_sample(false)
	_emit_sfx("echo_rose_record")
	queue_redraw()


func _start_playback() -> void:
	if _samples.is_empty():
		mode = Mode.IDLE
		echo_active = false
		return
	_seq_counter += 1
	_play_seq = _seq_counter
	mode = Mode.PLAYING
	echo_active = true
	_play_t = 0.0
	_play_grace_t = PLAYBACK_GRACE_SECS
	_next_shot_idx = 0
	echo_pos = _samples[0]["pos"] as Vector2
	echo_facing = _samples[0]["facing"] as Vector2
	_enforce_echo_cap()
	_refresh_region_slot_indices()
	set_powered(true)
	emit_power(true)
	_emit_sfx("echo_rose_replay")
	queue_redraw()


func _enforce_echo_cap() -> void:
	var active_list: Array[LxEchoRose] = get_active_echoes_in_region(region)
	var cap: int = maxi(1, max_echoes)
	while active_list.size() > cap:
		var oldest: LxEchoRose = active_list[0]
		active_list.remove_at(0)
		if oldest != self and is_instance_valid(oldest):
			oldest.stop_echo()


func _refresh_region_slot_indices() -> void:
	var active_list: Array[LxEchoRose] = get_active_echoes_in_region(region)
	for i: int in range(active_list.size()):
		active_list[i].echo_slot_index = i + 1
		active_list[i].queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _play_grace_t > 0.0:
		_play_grace_t = maxf(0.0, _play_grace_t - dt)
	if _disperse_t > 0.0:
		_disperse_t = maxf(0.0, _disperse_t - dt)
		queue_redraw()
	match mode:
		Mode.RECORDING:
			_tick_recording(dt)
		Mode.PLAYING:
			_tick_playback(dt)
	if not _bolts.is_empty():
		_tick_echo_bolts(dt)
		queue_redraw()


func _tick_recording(dt: float) -> void:
	_rec_t += dt
	_sample_accum += dt
	var cur_shots: int = _read_wick_shots()
	var fired_now: bool = cur_shots > _last_shots
	_last_shots = cur_shots
	if fired_now or _sample_accum >= (1.0 / SAMPLE_HZ):
		_sample_accum = 0.0
		_record_sample(fired_now)
	if _rec_t >= _active_rec_secs:
		_start_playback()
	queue_redraw()


func _record_sample(fired: bool) -> void:
	var wp: Vector2 = wick_pos()
	if wp.x < -9000.0:
		wp = pos
	var wf: Vector2 = Vector2.RIGHT
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.get("facing") is Vector2:
		var fv: Vector2 = Lx.player.get("facing") as Vector2
		if fv.length_squared() > 0.001:
			wf = fv.normalized()
	_samples.append({"t": _rec_t, "pos": wp, "facing": wf, "shot": fired})


func _tick_playback(dt: float) -> void:
	if _samples.is_empty():
		mode = Mode.IDLE
		echo_active = false
		return
	var total_t: float = maxf(0.1, float(_samples[_samples.size() - 1]["t"]))
	_play_t += dt
	if _play_t > total_t:
		if loop_replay:
			_play_t = fmod(_play_t, total_t)
			_next_shot_idx = 0
		else:
			stop_echo()
			return
	var prev_s: Dictionary = _samples[0]
	var next_s: Dictionary = _samples[_samples.size() - 1]
	for i: int in range(_samples.size()):
		var s: Dictionary = _samples[i]
		if float(s["t"]) <= _play_t:
			prev_s = s
		else:
			next_s = s
			break
	var span: float = maxf(0.001, float(next_s["t"]) - float(prev_s["t"]))
	var u: float = clampf((_play_t - float(prev_s["t"])) / span, 0.0, 1.0)
	echo_pos = (prev_s["pos"] as Vector2).lerp(next_s["pos"] as Vector2, u)
	echo_facing = (prev_s["facing"] as Vector2).normalized()
	while _next_shot_idx < _samples.size() and float(_samples[_next_shot_idx]["t"]) <= _play_t:
		if bool(_samples[_next_shot_idx]["shot"]):
			var sdir: Vector2 = (_samples[_next_shot_idx]["facing"] as Vector2).normalized()
			_spawn_echo_bolt(echo_pos + sdir * 6.0, sdir)
		_next_shot_idx += 1
	queue_redraw()


func _spawn_echo_bolt(from_p: Vector2, dir: Vector2) -> void:
	_bolts.append({
		"pos": from_p,
		"prev": from_p,
		"dir": dir.normalized(),
		"dist": 0.0,
		"max_range": ECHO_BOLT_RANGE,
		"hit_ids": [],
		"bounces": 0,
		"color": "rose",
		"is_prism": false,
		"curve_deg": 0.0,
	})
	_emit_sfx("bolt_fire")


func _tick_echo_bolts(dt: float) -> void:
	var i: int = _bolts.size() - 1
	while i >= 0:
		var b: Dictionary = _bolts[i]
		var bp: Vector2 = b["pos"] as Vector2
		var bdir: Vector2 = (b["dir"] as Vector2).normalized()
		var fa: Vector2 = LxToyDraw.sample_fields_accel(bp, "bolt")
		if fa.length_squared() > 0.01:
			var vel: Vector2 = bdir * ECHO_BOLT_SPEED + fa * dt
			if vel.length_squared() > 1.0:
				var ndir: Vector2 = vel.normalized()
				b["curve_deg"] = float(b["curve_deg"]) + rad_to_deg(absf(bdir.angle_to(ndir)))
				bdir = ndir
				b["dir"] = bdir
		var step: float = ECHO_BOLT_SPEED * dt
		var nxt: Vector2 = bp + bdir * step
		var dead: bool = false
		if region != null and is_instance_valid(region):
			if region.has_method("get_interactables"):
				dead = _step_bolt_interactables(b, bp, nxt)
				bdir = (b["dir"] as Vector2).normalized()
				nxt = b["pos"] as Vector2
			if not dead and region.has_method("get_enemies"):
				dead = _step_bolt_enemies(b, bp, nxt)
			if not dead and region.has_method("tile_at") and LxMapFormat.blocks_sight_tile(str(region.call("tile_at", nxt))):
				dead = true
		b["prev"] = bp
		b["pos"] = nxt
		b["dist"] = float(b["dist"]) + step
		if dead or float(b["dist"]) >= float(b["max_range"]):
			_bolts.remove_at(i)
		i -= 1


func _step_bolt_interactables(b: Dictionary, bp: Vector2, nxt: Vector2) -> bool:
	var hit_ids: Array = b["hit_ids"] as Array
	var bdir: Vector2 = (b["dir"] as Vector2).normalized()
	for it_v: Variant in (region.call("get_interactables") as Array):
		if not is_instance_valid(it_v) or not (it_v is LxInteractable) or it_v == self:
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not is_instance_valid(it) or not it.active:
			continue
		var iid: int = it.get_instance_id()
		if hit_ids.has(iid):
			continue
		var hit_r: float = it.radius + 3.0
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(it.pos, bp, nxt)
		if closest.distance_to(it.pos) > hit_r:
			continue
		hit_ids.append(iid)
		if it.kind == "color_glass":
			var gc: String = LxToyDraw.to_hit_color(str(it.get("glass_color")))
			b["color"] = gc
			if gc == LxHit.COLOR_BLUE:
				b["is_prism"] = true
			continue
		if _try_reflect_echo_bolt(b, it, closest, bdir):
			return false
		var is_blue: bool = bool(b["is_prism"]) or str(b["color"]) == LxHit.COLOR_BLUE
		var src: String = LxHit.SOURCE_PRISM if is_blue else LxHit.SOURCE_BOLT
		var col: String = LxHit.COLOR_BLUE if is_blue else str(b["color"])
		var eh: LxHit = LxHit.make(src, 0.0, bdir, bp, 0.0, false, false, self, false, col)
		eh.curve_angle_deg = float(b["curve_deg"])
		if it.on_hit(eh):
			b["pos"] = nxt
			return true
	b["pos"] = nxt
	return false


func _try_reflect_echo_bolt(b: Dictionary, it: LxInteractable, hit_pt: Vector2, bdir: Vector2) -> bool:
	if it.kind not in ["mirror", "blue_transformer"] and not (it is LxMirror):
		return false
	if int(b["bounces"]) >= ECHO_BOLT_MAX_BOUNCES:
		return false
	var norm_v: Variant = it.get("normal")
	if not (norm_v is Vector2):
		return false
	var n: Vector2 = (norm_v as Vector2).normalized()
	if n.length_squared() < 0.01:
		return false
	if bdir.dot(n) > 0.0:
		if it.get("double_sided") == true:
			n = -n
		else:
			return false
	var refl: Vector2 = bdir.bounce(n).normalized()
	b["dir"] = refl
	b["pos"] = it.pos + refl * 4.0
	b["bounces"] = int(b["bounces"]) + 1
	b["max_range"] = float(b["max_range"]) + 96.0
	var makes_blue: bool = it.kind == "blue_transformer" or str(it.props.get("transforms_to", "")).to_lower() == "blue"
	if makes_blue or (it.get("transforms_to") != null and str(it.get("transforms_to")).to_lower() == "blue"):
		b["color"] = LxHit.COLOR_BLUE
		b["is_prism"] = true
	var eh: LxHit = LxHit.make(LxHit.SOURCE_PRISM if bool(b["is_prism"]) else LxHit.SOURCE_BOLT, 0.0, bdir, hit_pt, 0.0, false, false, self, false, str(b["color"]))
	it.on_hit(eh)
	_emit_sfx("prism_bounce" if bool(b["is_prism"]) else "mirror_ping")
	return true


func _step_bolt_enemies(b: Dictionary, bp: Vector2, nxt: Vector2) -> bool:
	var hit_ids: Array = b["hit_ids"] as Array
	var bdir: Vector2 = (b["dir"] as Vector2).normalized()
	var is_blue: bool = bool(b["is_prism"]) or str(b["color"]) == LxHit.COLOR_BLUE
	for e_v: Variant in (region.call("get_enemies") as Array):
		if not (e_v is LxEnemyBrain) or not is_instance_valid(e_v):
			continue
		var en: LxEnemyBrain = e_v as LxEnemyBrain
		if not en.is_alive() or not en.visible:
			continue
		var eid: int = en.get_instance_id()
		if hit_ids.has(eid):
			continue
		var er: float = maxf(6.0, en.body_radius) + 3.0
		if Geometry2D.get_closest_point_to_segment(en.pos, bp, nxt).distance_to(en.pos) > er:
			continue
		hit_ids.append(eid)
		var src: String = LxHit.SOURCE_PRISM if is_blue else LxHit.SOURCE_BOLT
		var col: String = LxHit.COLOR_BLUE if is_blue else str(b["color"])
		var dmg: float = 0.5 if is_blue else 0.0
		var eh: LxHit = LxHit.make(src, dmg, bdir, bp, 0.0, false, false, self, false, col)
		eh.curve_angle_deg = float(b["curve_deg"])
		if en.has_method("on_echo_bolt_hit"):
			en.call("on_echo_bolt_hit", eh)
			return true
		if is_blue and (en.is_boss or not en.boss_id.is_empty()):
			en.apply_hit(eh)
			return true
	return false


func _read_wick_shots() -> int:
	if Lx.player != null and is_instance_valid(Lx.player):
		var sf_v: Variant = Lx.player.get("shots_fired")
		if sf_v is int or sf_v is float:
			return int(sf_v)
	return 0


func get_light_pool() -> Vector4:
	if not active or mode == Mode.IDLE:
		return Vector4.ZERO
	if mode == Mode.PLAYING and echo_active:
		return Vector4(echo_pos.x, echo_pos.y - 4.0, 42.0, 0.72)
	return Vector4(pos.x, pos.y - 4.0, 38.0, 0.65)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var reduced: bool = LxHudFx.flash_reduced()
	var blooming: bool = mode != Mode.IDLE
	var pulse_on: bool = blooming and (reduced or int(floorf(_clock * 6.0)) % 2 == 0)

	# Grounded shadow + fluted stone pedestal
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, 2.0, 14.0, 4.0), c_night, c_dusk, c_stone, c_void)
	draw_rect(Rect2(-5.0, -3.0, 10.0, 6.0), c_void)
	draw_rect(Rect2(-4.0, -2.0, 8.0, 4.0), c_dusk)
	for fx: float in [-3.0, 0.0, 3.0]:
		draw_rect(Rect2(fx, -2.0, 1.0, 4.0), c_mauve if fx > 0.0 else c_stone)
	for gx: float in [-2.0, 1.0]:
		draw_rect(Rect2(gx, -2.0, 1.0, 4.0), c_night)
	draw_rect(Rect2(-6.0, -3.0, 12.0, 1.0), c_stone)

	# Leafy calyx & side leaves (pine / jade / lime)
	draw_rect(Rect2(-9.0, -6.0, 5.0, 4.0), c_void)
	draw_rect(Rect2(4.0, -6.0, 5.0, 4.0), c_void)
	draw_rect(Rect2(-8.0, -5.0, 4.0, 2.0), c_jade)
	draw_rect(Rect2(-8.0, -5.0, 3.0, 1.0), c_lime)
	draw_rect(Rect2(-6.0, -3.0, 2.0, 1.0), c_pine)
	draw_rect(Rect2(4.0, -5.0, 4.0, 2.0), c_jade)
	draw_rect(Rect2(5.0, -5.0, 3.0, 1.0), c_lime)
	draw_rect(Rect2(4.0, -3.0, 2.0, 1.0), c_pine)
	draw_rect(Rect2(-5.0, -6.0, 10.0, 4.0), c_void)
	draw_rect(Rect2(-4.0, -5.0, 8.0, 2.0), c_pine)
	draw_rect(Rect2(-3.0, -5.0, 6.0, 1.0), c_jade)

	# Sculpted layered rose petals (wider & luminous when recording/playing)
	var ex: float = 1.0 if blooming else 0.0
	draw_rect(Rect2(-5.0 - ex, -12.0 - ex, 10.0 + ex * 2.0, 7.0 + ex), c_void)
	draw_rect(Rect2(-4.0 - ex, -13.0 - ex, 8.0 + ex * 2.0, 2.0), c_void)
	var c_outer: Color = c_coral if blooming else c_wine
	var c_mid: Color = c_rose if blooming else c_coral
	var c_heart: Color = c_cream if mode == Mode.PLAYING else (PAL["gold"] as Color if mode == Mode.RECORDING else c_rose)
	draw_rect(Rect2(-4.0 - ex, -11.0 - ex, 8.0 + ex * 2.0, 5.0 + ex), c_wine)
	draw_rect(Rect2(-4.0 - ex, -11.0 - ex, 3.0, 4.0), c_outer)
	draw_rect(Rect2(1.0 + ex, -11.0 - ex, 3.0, 4.0), c_outer)
	draw_rect(Rect2(-3.0, -12.0 - ex, 6.0, 5.0), c_mid)
	draw_rect(Rect2(-3.0, -12.0 - ex, 2.0, 1.0), c_cream if blooming else c_rose)
	draw_rect(Rect2(1.0, -12.0 - ex, 2.0, 1.0), c_rose)
	draw_rect(Rect2(-2.0, -10.0 - ex, 4.0, 3.0), c_wine if not blooming else c_coral)
	draw_rect(Rect2(-1.0, -11.0 - ex, 3.0, 2.0), c_heart)
	draw_rect(Rect2(0.0, -10.0 - ex, 1.0, 1.0), c_cream if blooming else c_wine)

	if mode == Mode.RECORDING:
		var frac: float = clampf(_rec_t / maxf(_active_rec_secs, 0.1), 0.0, 1.0)
		LxToyDraw.draw_bar(self, Vector2(-7.0, 8.0), 14.0, frac, c_coral, c_rose)
		if pulse_on:
			draw_arc(Vector2(0.0, -9.0), 9.0, 0.0, TAU, 16, c_rose, 1.0)
	elif mode == Mode.PLAYING and echo_active:
		if pulse_on:
			draw_arc(Vector2(0.0, -9.0), 8.0, 0.0, TAU, 16, Color(c_cream, 0.65), 1.0)
		var ep: Vector2 = (echo_pos - pos).round()
		var alpha: float = 0.45 if _disperse_t > 0.0 else (0.76 if reduced else 0.90)
		LxToyDraw.draw_contact_shadow(self, ep + Vector2(0.0, 4.0), 5.0, 2.0)
		draw_rect(Rect2(ep.x - 3.0, ep.y - 12.0, 6.0, 3.0), Color(c_void, alpha * 0.85))
		draw_rect(Rect2(ep.x - 5.0, ep.y - 9.0, 10.0, 11.0), Color(c_void, alpha * 0.85))
		draw_rect(Rect2(ep.x - 2.0, ep.y - 11.0, 4.0, 2.0), Color(c_rose, alpha))
		draw_rect(Rect2(ep.x - 4.0, ep.y - 8.0, 8.0, 9.0), Color(c_wine, alpha))
		draw_rect(Rect2(ep.x - 3.0, ep.y - 8.0, 6.0, 7.0), Color(c_rose, alpha))
		draw_rect(Rect2(ep.x - 2.0, ep.y - 6.0, 4.0, 3.0), Color(c_void, alpha))
		draw_rect(Rect2(ep.x - 1.0, ep.y - 5.0, 1.0, 1.0), Color(c_cream, alpha))
		draw_rect(Rect2(ep.x + 1.0, ep.y - 5.0, 1.0, 1.0), Color(c_cream, alpha))
		var pips: int = clampi(echo_slot_index, 1, MAX_ACTIVE_ECHOES)
		var p_span: float = float(pips - 1) * 3.0
		for pi: int in range(pips):
			var px: float = roundf(ep.x - p_span * 0.5 + float(pi) * 3.0)
			draw_rect(Rect2(px - 1.0, ep.y - 16.0, 3.0, 3.0), Color(c_void, alpha * 0.85))
			draw_rect(Rect2(px, ep.y - 15.0, 1.0, 1.0), Color(c_cream, alpha))
		var tip: Vector2 = (ep + echo_facing * 7.0 + Vector2(0.0, -4.0)).round()
		draw_rect(Rect2(tip - Vector2.ONE, Vector2(3.0, 3.0)), Color(c_rose, alpha))
		draw_rect(Rect2(tip, Vector2.ONE), Color(c_cream, alpha))
	for b: Dictionary in _bolts:
		var bp: Vector2 = ((b["pos"] as Vector2) - pos).round()
		var is_b: bool = bool(b["is_prism"]) or str(b["color"]) == LxHit.COLOR_BLUE
		var bc: Color = (PAL["sky"] as Color) if is_b else c_rose
		draw_rect(Rect2(bp - Vector2.ONE, Vector2(3.0, 3.0)), bc)
		draw_rect(Rect2(bp, Vector2.ONE), PAL["ice"] as Color if is_b else c_cream)
	_draw_signal_pulses()
