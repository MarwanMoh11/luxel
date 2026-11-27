class_name LxFallingBellPlatform
extends LxToy
## Island 1 Great Toll shaft ride controller (`toll_r2`, `toll_r4`).
## Forms a solid walkable 7x7 bronze bell crown over shaft void/pit tiles, drives vertical masonry
## parallax, spawns scrolling rail bells/beams/grates/moths on `rail_events`, responds to Dusk (freeze
## beams 2 s), War (shatter grates), and Dawn (engage arrestor brakes), and opens exit on completion.
## Props: radius_px (float, 52), scroll_speed (float, 72), duration_s (float, 45), brakes_needed (int, 0),
## auto_start (bool, false), complete_flag (String), rail_events ([{t, side, kind, tone}]), target_id/target_ids.

enum State { IDLE, FALLING, BRAKED, CRASHED }

var state: int = State.IDLE
var radius_px: float = 52.0
var scroll_speed: float = 72.0
var duration_s: float = 45.0
var brakes_needed: int = 0
var complete_flag: String = ""
var rail_events: Array[Dictionary] = []

var elapsed_s: float = 0.0
var brakes_engaged: int = 0
var _scroll_px: float = 0.0
var _beam_freeze_t: float = 0.0
var _crash_t: float = 0.0
var _fired_indices: Dictionary = {}
var _hazards: Array[Dictionary] = [] # [{kind, side, y, tone, broken, hit, bell_node}]


func _toy_setup() -> void:
	kind = "falling_bell_platform"
	radius_px = clampf(float(props.get("radius_px", 52.0)), 28.0, 80.0)
	scroll_speed = maxf(24.0, float(props.get("scroll_speed", 72.0)))
	duration_s = maxf(2.0, float(props.get("duration_s", 45.0)))
	brakes_needed = maxi(0, int(props.get("brakes_needed", 0)))
	complete_flag = str(props.get("complete_flag", "")).strip_edges()
	radius = radius_px
	size = Vector2(radius_px * 2.0, radius_px * 2.0)
	rail_events.clear()
	var raw_ev: Variant = props.get("rail_events", [])
	if raw_ev is Array:
		for item: Variant in (raw_ev as Array):
			if item is Dictionary:
				rail_events.append((item as Dictionary).duplicate(true))
	z_index = -4
	_reset_internal()
	if bool(props.get("auto_start", false)):
		start_fall()
	queue_redraw()


func _reset_internal() -> void:
	_clear_spawned_bells()
	state = State.IDLE
	elapsed_s = 0.0
	brakes_engaged = 0
	_scroll_px = 0.0
	_beam_freeze_t = 0.0
	_crash_t = 0.0
	_fired_indices.clear()
	_hazards.clear()


func reset_toy() -> void:
	if persist and state == State.CRASHED:
		return
	_reset_internal()
	set_powered(false)
	_notify_linked_targets(false)
	queue_redraw()


func _clear_spawned_bells() -> void:
	for hz: Dictionary in _hazards:
		var bn: Variant = hz.get("bell_node", null)
		if bn is LxInteractable and is_instance_valid(bn):
			if region != null and region.has_method("remove_interactable"):
				region.call("remove_interactable", (bn as LxInteractable).id)
			else:
				(bn as Node).queue_free()


func is_platform_solid() -> bool:
	return active


func get_platform_rect() -> Rect2:
	return Rect2(pos - Vector2(radius_px, radius_px), Vector2(radius_px * 2.0, radius_px * 2.0)) if active else Rect2()


func start_fall() -> void:
	if state != State.IDLE:
		return
	state = State.FALLING
	if region != null and region.has_method("set_room_anchor"):
		region.call("set_room_anchor", pos)
	_emit_sfx("bell_toll_heavy")
	_emit_shake(0.18)
	queue_redraw()


func on_ring(in_tone: String, _dir: Vector2) -> void:
	if not active or state == State.CRASHED:
		return
	var t: String = in_tone.strip_edges().to_lower()
	if t == "dusk":
		_beam_freeze_t = 2.0
		_emit_sfx(_pick_sfx("bell_dusk_ring", "crystal_clank"))
	elif t == "war":
		var broke: bool = false
		for hz: Dictionary in _hazards:
			if str(hz.get("kind", "")) == "grate" and not bool(hz.get("broken", false)):
				hz["broken"] = true
				broke = true
		if broke:
			_emit_sfx("stone_break")
	elif t == "dawn":
		brakes_engaged += 1
		_emit_sfx(_pick_sfx("bell_dawn_ring", "bell_toll"))
		if brakes_needed > 0 and brakes_engaged >= brakes_needed and state == State.FALLING:
			state = State.BRAKED
			elapsed_s = maxf(elapsed_s, duration_s - 0.8)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if island_id == 1 and Lx.world == region and region != null:
		var rnode: Node = region.get_node_or_null("Island1RuleOverlay")
		if rnode != null and rnode.has_method("tick_from_toy"):
			rnode.call("tick_from_toy", self, dt)
	if not active:
		return
	if state == State.IDLE:
		if get_platform_rect().has_point(wick_pos()):
			start_fall()
		return
	if state == State.CRASHED:
		if _crash_t > 0.0:
			_crash_t = maxf(0.0, _crash_t - dt)
			queue_redraw()
		return

	elapsed_s += dt
	var eff_spd: float = scroll_speed * (0.35 if state == State.BRAKED else 1.0)
	_scroll_px = fposmod(_scroll_px + eff_spd * dt, 32.0)
	if _beam_freeze_t > 0.0:
		_beam_freeze_t = maxf(0.0, _beam_freeze_t - dt)

	_spawn_due_events()
	_tick_hazards(dt, eff_spd)

	if elapsed_s >= duration_s:
		_complete_crash()
	queue_redraw()


func _spawn_due_events() -> void:
	for idx: int in range(rail_events.size()):
		if _fired_indices.has(idx):
			continue
		var ev: Dictionary = rail_events[idx]
		if elapsed_s < float(ev.get("t", 0.0)):
			continue
		_fired_indices[idx] = true
		var hk: String = str(ev.get("kind", "beam")).strip_edges().to_lower()
		var side: String = str(ev.get("side", "l")).strip_edges().to_lower()
		var tone: String = str(ev.get("tone", "dusk")).strip_edges().to_lower()
		var entry: Dictionary = {
			"kind": hk, "side": side, "tone": tone,
			"y": -radius_px - 36.0, "broken": false, "hit": false, "bell_node": null,
		}
		if hk == "bell" and region != null and region.has_method("spawn_interactable"):
			var bx: float = pos.x + (-radius_px - 22.0 if side == "l" else radius_px + 22.0)
			var bspec: Dictionary = {
				"id": "%s_rail_%d" % [id, idx],
				"kind": "bell",
				"pos": [bx, pos.y - radius_px - 36.0],
				"props": {"tone": tone, "wave_radius": radius_px * 2.6, "speed": 185.0},
			}
			var bn: Variant = region.call("spawn_interactable", bspec)
			if bn is LxInteractable:
				entry["bell_node"] = bn
		_hazards.append(entry)


func _tick_hazards(dt: float, eff_spd: float) -> void:
	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for i: int in range(_hazards.size() - 1, -1, -1):
		var hz: Dictionary = _hazards[i]
		var hk: String = str(hz["kind"])
		var move_spd: float = 0.0 if (hk == "beam" and _beam_freeze_t > 0.0) else eff_spd
		hz["y"] = float(hz["y"]) + move_spd * dt
		var hy: float = float(hz["y"])
		var bn: Variant = hz.get("bell_node", null)
		if bn is LxInteractable and is_instance_valid(bn):
			var bi: LxInteractable = bn as LxInteractable
			bi.pos.y = pos.y + hy
			bi.position = bi.pos.round()
		# Hazard collision with Wick on the bell rim (never cheap instakill: 1 heart + breaks through)
		if w != null and not w.dead and not bool(hz["broken"]) and not bool(hz["hit"]):
			if hk in ["beam", "grate"] and absf((pos.y + hy) - w.global_position.y) <= 7.0 and absf(w.global_position.x - pos.x) <= radius_px:
				if not w.is_dashing() and not w.is_zipping():
					hz["hit"] = true
					if hk == "grate":
						hz["broken"] = true
					w.take_damage(1.0, Vector2(w.global_position.x, pos.y + hy), Vector2.DOWN, "toll_" + hk)
		if hy > radius_px + 48.0:
			if bn is LxInteractable and is_instance_valid(bn):
				if region != null and region.has_method("remove_interactable"):
					region.call("remove_interactable", (bn as LxInteractable).id)
				else:
					(bn as Node).queue_free()
			_hazards.remove_at(i)


func _complete_crash() -> void:
	_clear_spawned_bells()
	_hazards.clear()
	state = State.CRASHED
	_crash_t = 0.65
	if not complete_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[complete_flag] = true
	_emit_sfx("bell_toll_heavy")
	_emit_shake(0.28)
	set_powered(true)
	_notify_linked_targets(true)
	if region != null and region.has_method("notify"):
		region.call("notify", "falling_bell_crashed", {"id": id, "brakes": brakes_engaged})
	queue_redraw()


func _emit_shake(amp: float) -> void:
	if Lx.events != null:
		Lx.events.shake_requested.emit(amp * (0.45 if LxHudFx.flash_reduced() else 1.0))


func _pick_sfx(preferred: String, fallback: String) -> String:
	if Lx.packs != null and not Lx.packs.sfx_cue(preferred).is_empty():
		return preferred
	return fallback


func get_light_pool() -> Vector4:
	return Vector4(pos.x, pos.y, radius_px + 28.0, 0.72) if active else Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["state"] = state
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("state"):
		state = int(d.get("state", State.IDLE))
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var r: float = roundf(radius_px)
	var red: bool = LxHudFx.flash_reduced()

	# Rushing shaft masonry parallax lines flanking the bell
	if state in [State.FALLING, State.BRAKED]:
		var off_y: float = 0.0 if red else roundf(_scroll_px)
		for side_s: float in [-1.0, 1.0]:
			var sx: float = side_s * (r + 12.0)
			var yy: float = -r - 24.0 + off_y
			while yy < r + 24.0:
				draw_rect(Rect2(sx - 2.0, yy, 4.0, 12.0), c_dusk)
				draw_rect(Rect2(sx - 1.0, yy + 1.0, 2.0, 4.0), c_mauve)
				yy += 32.0

	# Grounded drop shadow & stepped 3/4 bronze bell crown platform
	draw_circle(Vector2(2.0, 4.0), r + 2.0, Color(c_void, 0.50))
	draw_circle(Vector2.ZERO, r + 1.0, c_void)
	draw_circle(Vector2.ZERO, r, c_night)
	draw_circle(Vector2(0.0, -1.0), r - 1.0, c_dusk)
	# Concentric stepped cast-bronze crown rings
	draw_circle(Vector2(0.0, -1.0), r - 6.0, c_plum)
	draw_circle(Vector2(0.0, -1.0), r - 12.0, c_dusk)
	draw_arc(Vector2(0.0, -1.0), r - 2.0, 0.0, TAU, 32, c_gold if state == State.BRAKED else c_apricot, 2.0)
	# Sunlit WNW rim highlight
	draw_arc(Vector2(0.0, -1.0), r - 2.0, PI * 0.85, PI * 1.65, 16, c_cream if state != State.IDLE else c_gold, 1.0)
	draw_arc(Vector2(0.0, -1.0), r - 11.0, 0.0, TAU, 24, c_wine, 1.0)
	draw_arc(Vector2(0.0, -1.0), r - 12.0, PI * 0.85, PI * 1.65, 14, c_mauve, 1.0)

	# 8 radial cast-bronze bell ribs & brass rim rivets
	for i: int in range(8):
		var a: float = (TAU * float(i)) / 8.0
		var inner_p := Vector2(roundf(cos(a) * 11.0), roundf(sin(a) * 11.0 - 1.0))
		var outer_p := Vector2(roundf(cos(a) * (r - 5.0)), roundf(sin(a) * (r - 5.0) - 1.0))
		draw_line(inner_p + Vector2(0.0, 1.0), outer_p + Vector2(0.0, 1.0), c_night, 1.0)
		draw_line(inner_p, outer_p, c_apricot if (i % 2 == 0) else c_mauve, 1.0)
		var rp := Vector2(roundf(cos(a) * (r - 5.0)), roundf(sin(a) * (r - 5.0) - 1.0))
		draw_rect(Rect2(rp - Vector2.ONE, Vector2(3.0, 3.0)), c_void)
		draw_rect(Rect2(rp, Vector2(2.0, 2.0)), c_cream if state == State.BRAKED else c_gold)

	# Sculpted central bronze bell boss with sunlit top-left specular crescent
	draw_circle(Vector2(1.0, 1.0), 10.0, c_void)
	draw_circle(Vector2.ZERO, 9.0, c_wine)
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 16, c_apricot, 1.0)
	var boss_c: Color = c_cream if state == State.CRASHED else (c_gold if state == State.BRAKED else c_apricot)
	draw_circle(Vector2.ZERO, 5.0, boss_c)
	draw_rect(Rect2(-3.0, -3.0, 3.0, 2.0), c_cream)
	if state == State.FALLING and not red and int(floorf(_clock * 10.0)) % 2 == 0:
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 16, c_gold, 1.0)
	if state in [State.FALLING, State.BRAKED]:
		LxToyDraw.draw_bar(self, Vector2(-16.0, r + 5.0), 32.0, clampf(elapsed_s / duration_s, 0.0, 1.0), c_gold)
	elif _crash_t > 0.0:
		var cu: float = 1.0 - clampf(_crash_t / 0.65, 0.0, 1.0)
		var ring_c := Color(c_gold, (1.0 - cu) * (0.50 if red else 0.88))
		draw_arc(Vector2.ZERO, roundf(r * 0.5 + cu * (r * 0.65 if red else r * 0.95)), 0.0, TAU, 24, ring_c, 1.0 if red else 2.0)

	# Active scrolling timber beams and cracked stone grates
	for hz: Dictionary in _hazards:
		if bool(hz.get("broken", false)):
			continue
		var hk: String = str(hz["kind"])
		var hy: float = roundf(float(hz["y"]))
		if hk == "beam":
			var frozen: bool = _beam_freeze_t > 0.0
			var bc: Color = PAL["ice"] as Color if frozen else c_wine
			var bh: Color = c_cream if frozen else c_apricot
			LxToyDraw.draw_bevel_box(self, Rect2(-r, hy - 4.0, r * 2.0, 8.0), c_night, bc, bh, c_void)
			if frozen:
				draw_rect(Rect2(-r + 2.0, hy - 2.0, 3.0, 2.0), c_cream)
				draw_rect(Rect2(r - 5.0, hy - 2.0, 3.0, 2.0), c_cream)
		elif hk == "grate":
			LxToyDraw.draw_bevel_box(self, Rect2(-r, hy - 5.0, r * 2.0, 10.0), c_night, PAL["coral"] as Color, c_apricot, c_void)
			var gx: float = -r + 8.0
			while gx <= r - 8.0:
				if absf(gx) > 8.0:
					draw_rect(Rect2(roundf(gx), hy - 4.0, 2.0, 8.0), c_void)
				gx += 10.0
			LxToyDraw.draw_tone_crest(self, Vector2(0.0, hy), "war", true)
	_draw_signal_pulses()
