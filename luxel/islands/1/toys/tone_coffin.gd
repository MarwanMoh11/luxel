class_name LxToneCoffin
extends LxToy
## Island 1 Undercroft resonant stone coffin on tracks.
## Responds to LxRingWave `on_ring(tone, dir)` via `tone_map`:
##   - "dawn" -> "slide": slides along `dir` by `slide_tiles` (forming a solid walkable bridge over pits; cycles to prevent softlock)
##   - "dusk" -> "freeze": locks coffin in place for `freeze_secs` (2.5 s) with ice crystal rim even mid-slide
##   - "war"  -> "shatter": shatters permanently and releases `contains` (shards, flag, or enabling a hidden interactable)
## Props: tone_map {dawn,dusk,war}, dir ("n"|"e"|"s"|"w"|[dx,dy]), slide_tiles (float, default 2),
## steps (int, default 1), speed (float, default 48), freeze_secs (float, default 2.5), contains (String),
## solid_blocker (bool, default false), platform_after_shatter (bool, default false), size [w,h], persist (bool).

enum State { CLOSED, SLIDING, FROZEN, SHATTERED }

var state: int = State.CLOSED
var tone_map: Dictionary = {"dawn": "slide", "dusk": "freeze", "war": "shatter"}
var track_dir: Vector2 = Vector2.RIGHT
var slide_tiles: float = 2.0
var steps: int = 1
var speed: float = 48.0
var freeze_secs: float = 2.5
var contains: String = ""
var solid_blocker: bool = false
var platform_after_shatter: bool = false

var origin_pos: Vector2 = Vector2.ZERO
var step_index: int = 0
var _target_pos: Vector2 = Vector2.ZERO
var _freeze_left: float = 0.0
var _shatter_t: float = 0.0
var _pulse_t: float = 0.0
var _reward_given: bool = false


func _toy_setup() -> void:
	kind = "tone_coffin"
	track_dir = dir_vec("dir", Vector2.RIGHT)
	if track_dir.length_squared() <= 0.001:
		track_dir = Vector2.RIGHT
	var def_sz: Vector2 = Vector2(32.0, 16.0) if absf(track_dir.x) >= absf(track_dir.y) else Vector2(16.0, 32.0)
	size = _parse_size(props.get("size", [def_sz.x, def_sz.y]), def_sz)
	radius = maxf(size.x, size.y) * 0.5
	tone_map = {"dawn": "slide", "dusk": "freeze", "war": "shatter"}
	var raw_tm: Variant = props.get("tone_map", null)
	if raw_tm is Dictionary:
		for k_v: Variant in (raw_tm as Dictionary).keys():
			tone_map[str(k_v).strip_edges().to_lower()] = str((raw_tm as Dictionary)[k_v]).strip_edges().to_lower()
	slide_tiles = maxf(0.5, float(props.get("slide_tiles", 2.0)))
	steps = maxi(1, int(props.get("steps", 1)))
	speed = maxf(12.0, float(props.get("speed", 48.0)))
	freeze_secs = maxf(0.5, float(props.get("freeze_secs", 2.5)))
	contains = str(props.get("contains", "")).strip_edges()
	solid_blocker = bool(props.get("solid_blocker", false))
	platform_after_shatter = bool(props.get("platform_after_shatter", false))
	origin_pos = pos
	_target_pos = origin_pos
	step_index = 0
	state = State.CLOSED
	_freeze_left = 0.0
	_shatter_t = 0.0
	_pulse_t = 0.0
	_reward_given = false
	z_index = 0 if solid_blocker else -4
	queue_redraw()


func reset_toy() -> void:
	if persist and state == State.SHATTERED:
		return
	state = State.CLOSED
	step_index = 0
	pos = origin_pos
	position = pos.round()
	_target_pos = origin_pos
	_freeze_left = 0.0
	_pulse_t = 0.0
	set_powered(false)
	_notify_linked_targets(false)
	z_index = 0 if solid_blocker else -4
	queue_redraw()


func is_platform_solid() -> bool:
	if not active:
		return false
	if state == State.SHATTERED:
		return platform_after_shatter
	if solid_blocker:
		return false
	return true


func get_platform_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_platform_solid() else Rect2()


func is_solid() -> bool:
	return active and solid_blocker and state != State.SHATTERED


func blocks_sight() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_solid() else Rect2()


func on_ring(in_tone: String, _dir: Vector2) -> void:
	if not active or state == State.SHATTERED:
		return
	var t: String = in_tone.strip_edges().to_lower()
	var action: String = str(tone_map.get(t, ""))
	match action:
		"slide":
			if state == State.FROZEN:
				_pulse_t = 0.22
				_emit_sfx("crystal_clank")
				queue_redraw()
				return
			_advance_slide()
		"freeze":
			state = State.FROZEN
			_freeze_left = freeze_secs
			_pulse_t = 0.28
			_emit_sfx(_pick_sfx("bell_dusk_ring", "crystal_clank"))
			set_powered(true)
			_notify_linked_targets(true)
			queue_redraw()
		"shatter":
			_shatter()


func _advance_slide() -> void:
	step_index = (step_index + 1) % (steps + 1)
	var step_px: float = (slide_tiles * 16.0) / float(steps)
	_target_pos = origin_pos + track_dir * (step_px * float(step_index))
	state = State.SLIDING
	_pulse_t = 0.25
	_emit_sfx(_pick_sfx("coffin_slide", "golem_stomp"))
	_emit_gust(maxf(size.x, size.y) + 14.0, 36.0)
	set_powered(step_index > 0)
	_notify_linked_targets(step_index > 0)
	queue_redraw()


func _shatter() -> void:
	state = State.SHATTERED
	_freeze_left = 0.0
	_shatter_t = 0.42
	z_index = -4
	_emit_sfx("stone_break")
	_emit_gust(maxf(size.x, size.y) + 28.0, 68.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.16)
	if not _reward_given and not contains.is_empty():
		_reward_given = true
		_spawn_contents()
	set_powered(true)
	_notify_linked_targets(true)
	if persist and region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	queue_redraw()


func _spawn_contents() -> void:
	if contains.begins_with("shards:"):
		var amt: int = maxi(1, int(contains.substr(7)))
		if Lx.state != null:
			Lx.state.shards += amt
		if Lx.events != null:
			Lx.events.shard_collected.emit(amt)
	elif contains.begins_with("flag:"):
		var fl: String = contains.substr(5).strip_edges()
		if Lx.state != null and not fl.is_empty():
			Lx.state.story_flags[fl] = true
	elif region != null and region.has_method("find_interactable"):
		var target_it: Variant = region.call("find_interactable", contains)
		if target_it is LxInteractable and is_instance_valid(target_it):
			var it: LxInteractable = target_it as LxInteractable
			it.active = true
			it.visible = true
			it.queue_redraw()
		elif Lx.state != null:
			Lx.state.story_flags[contains] = true


func tick(dt: float) -> void:
	super.tick(dt)
	if island_id == 1 and Lx.world == region and region != null:
		var rnode: Node = region.get_node_or_null("Island1RuleOverlay")
		if rnode != null and rnode.has_method("tick_from_toy"):
			rnode.call("tick_from_toy", self, dt)
	var dirty: bool = false
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		dirty = true
	if _shatter_t > 0.0:
		_shatter_t = maxf(0.0, _shatter_t - dt)
		dirty = true
	if state == State.FROZEN:
		_freeze_left -= dt
		dirty = true
		if _freeze_left <= 0.0:
			_freeze_left = 0.0
			state = State.SLIDING if pos.distance_to(_target_pos) > 0.5 else State.CLOSED
	elif state == State.SLIDING:
		var old_pos: Vector2 = pos
		var old_rect := Rect2(old_pos - size * 0.5, size)
		pos = pos.move_toward(_target_pos, speed * dt)
		position = pos.round()
		var delta: Vector2 = pos - old_pos
		if delta.length_squared() > 0.00001:
			_carry_riders(old_rect, delta)
			dirty = true
		if pos.distance_to(_target_pos) <= 0.25:
			pos = _target_pos
			position = pos.round()
			state = State.CLOSED
			dirty = true
	if dirty:
		queue_redraw()


func _carry_riders(old_rect: Rect2, delta: Vector2) -> void:
	if solid_blocker:
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			LxPhysDraw.safe_eject_wick(Lx.player as Node2D, get_solid_rect(), region, id, delta)
		return
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead and not w.is_dashing() and not w.is_gliding() and not w.is_zipping() and not w.is_launched() and not w.is_mounted():
			if old_rect.grow(1.5).has_point(w.global_position):
				var np: Vector2 = w.global_position + delta
				if region != null and region.has_method("collide"):
					np = region.call("collide", np, LxWick.BODY_RADIUS, true, true) as Vector2
				w.global_position = np
				w.last_pos = np
		if w.lantern != null and w.lantern.is_hanging() and old_rect.grow(2.0).has_point(w.lantern.pos):
			w.lantern.pos += delta
			w.lantern.prev_pos = w.lantern.pos
			w.lantern.global_position = w.lantern.pos.round()


func _pick_sfx(preferred: String, fallback: String) -> String:
	if Lx.packs != null and not Lx.packs.sfx_cue(preferred).is_empty():
		return preferred
	return fallback


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["state"] = state
		d["step_index"] = step_index
		d["pos"] = [pos.x, pos.y]
		d["reward_given"] = _reward_given
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("state"):
		state = int(d.get("state", State.CLOSED))
		step_index = int(d.get("step_index", 0))
		pos = _parse_vec2(d.get("pos"), origin_pos)
		position = pos.round()
		_target_pos = pos
		_reward_given = bool(d.get("reward_given", false))
		z_index = -4 if (state == State.SHATTERED or not solid_blocker) else 0
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var end_local: Vector2 = (origin_pos + track_dir * (slide_tiles * 16.0) - pos).round()
	var start_local: Vector2 = (origin_pos - pos).round()

	# Recessed stone coffin track rail
	draw_line(start_local, end_local, c_void, 5.0, false)
	draw_line(start_local, end_local, c_night, 3.0, false)
	draw_line(start_local, end_local, c_dusk, 1.0, false)

	var r := Rect2((-size * 0.5).round(), size.round())
	if state == State.SHATTERED:
		if platform_after_shatter:
			LxToyDraw.draw_bevel_box(self, r, c_night, c_dusk, c_mauve, c_void)
		# Shattered stone slabs
		draw_rect(Rect2(r.position + Vector2(2.0, 2.0), Vector2(6.0, 4.0)), c_mauve)
		draw_rect(Rect2(r.end - Vector2(9.0, 6.0), Vector2(7.0, 4.0)), c_stone)
		draw_rect(Rect2(-3.0, -2.0, 5.0, 3.0), c_dusk)
		if _shatter_t > 0.0:
			var u: float = 1.0 - clampf(_shatter_t / 0.42, 0.0, 1.0)
			for k: int in range(6):
				var a: float = (TAU * float(k)) / 6.0
				var dp := Vector2(roundf(cos(a) * lerpf(3.0, 16.0, u)), roundf(sin(a) * lerpf(3.0, 16.0, u)))
				draw_rect(Rect2(dp, Vector2(2.0, 2.0)), PAL["coral"] as Color if k % 2 == 0 else c_stone)
		_draw_signal_pulses()
		return

	# Coffin body shadow + stepped 3/4 carved sarcophagus plinth & bevelled lid
	draw_rect(Rect2(r.position + Vector2(2.0, 3.0), r.size), Color(c_void, 0.48))
	var lid_dark: Color = PAL["deep"] as Color if state == State.FROZEN else c_night
	var lid_mid: Color = PAL["sky"] as Color if state == State.FROZEN else (PAL["apricot"] as Color if state == State.SLIDING else c_mauve)
	var lid_hi: Color = PAL["ice"] as Color if state == State.FROZEN else (PAL["gold"] as Color if state == State.SLIDING else c_stone)
	var lid_top: Color = PAL["cream"] as Color if state in [State.FROZEN, State.SLIDING] else c_stone
	# Stepped stone base + raised chamfered sarcophagus lid
	LxToyDraw.draw_bevel_box(self, r, c_night, c_dusk, c_mauve, c_void)
	var cap := Rect2(r.position + Vector2(2.0, 1.0), r.size - Vector2(4.0, 3.0))
	LxToyDraw.draw_bevel_box(self, cap, lid_dark, lid_mid, lid_hi, c_void)
	# Crisp sunlit WNW ridge along lid top
	draw_rect(Rect2(cap.position + Vector2(2.0, 1.0), Vector2(maxf(2.0, cap.size.x - 4.0), 1.0)), lid_top)

	# Carved recessed sarcophagus masonry, brass clasps & iron handles
	var inner := Rect2(cap.position + Vector2(2.0, 2.0), Vector2(maxf(2.0, cap.size.x - 4.0), maxf(2.0, cap.size.y - 4.0)))
	draw_rect(inner, c_night, false, 1.0)
	var clasp_col: Color = PAL["gold"] as Color if state == State.SLIDING else (PAL["ice"] as Color if state == State.FROZEN else PAL["apricot"] as Color)
	draw_rect(Rect2(r.position + Vector2(2.0, 2.0), Vector2(2.0, 2.0)), clasp_col)
	draw_rect(Rect2(Vector2(r.end.x - 4.0, r.position.y + 2.0), Vector2(2.0, 2.0)), clasp_col)
	draw_rect(Rect2(Vector2(r.position.x + 2.0, r.end.y - 4.0), Vector2(2.0, 2.0)), clasp_col)
	draw_rect(Rect2(r.end - Vector2(4.0, 4.0), Vector2(2.0, 2.0)), clasp_col)
	if size.x >= size.y:
		draw_line(Vector2(inner.position.x + 2.0, -1.0), Vector2(inner.end.x - 2.0, -1.0), lid_top, 1.0)
		draw_line(Vector2(-3.0, inner.position.y + 1.0), Vector2(-3.0, inner.end.y - 1.0), lid_top, 1.0)
		draw_rect(Rect2(r.position.x + 6.0, r.position.y - 1.0, 4.0, 2.0), PAL["gold"] as Color)
		draw_rect(Rect2(r.end.x - 10.0, r.position.y - 1.0, 4.0, 2.0), PAL["gold"] as Color)
		draw_rect(Rect2(r.position.x + 6.0, r.end.y - 1.0, 4.0, 2.0), PAL["wine"] as Color)
		draw_rect(Rect2(r.end.x - 10.0, r.end.y - 1.0, 4.0, 2.0), PAL["wine"] as Color)
	else:
		draw_line(Vector2(0.0, inner.position.y + 2.0), Vector2(0.0, inner.end.y - 2.0), lid_top, 1.0)
		draw_line(Vector2(inner.position.x + 1.0, -3.0), Vector2(inner.end.x - 1.0, -3.0), lid_top, 1.0)
		draw_rect(Rect2(r.position.x - 1.0, r.position.y + 6.0, 2.0, 4.0), PAL["gold"] as Color)
		draw_rect(Rect2(r.end.x - 1.0, r.position.y + 6.0, 2.0, 4.0), PAL["wine"] as Color)
		draw_rect(Rect2(r.position.x - 1.0, r.end.y - 10.0, 2.0, 4.0), PAL["gold"] as Color)
		draw_rect(Rect2(r.end.x - 1.0, r.end.y - 10.0, 2.0, 4.0), PAL["wine"] as Color)

	# State icon & Dusk ice crystal rim + timer bar
	if state == State.FROZEN:
		draw_rect(r.grow(1.0), PAL["ice"] as Color, false, 1.0)
		draw_rect(Rect2(r.position - Vector2(2.0, 2.0), Vector2(3.0, 3.0)), PAL["cream"] as Color)
		draw_rect(Rect2(r.end - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), PAL["cream"] as Color)
		LxToyDraw.draw_bar(self, Vector2(-7.0, r.position.y - 5.0), 14.0, _freeze_left / maxf(0.1, freeze_secs), PAL["ice"] as Color)
	elif state == State.SLIDING:
		LxToyDraw.draw_tone_crest(self, Vector2(0.0, -1.0), "dawn", true)
	elif solid_blocker:
		LxToyDraw.draw_tone_crest(self, Vector2(0.0, -1.0), "war", _pulse_t > 0.0)
	else:
		LxToyDraw.draw_tone_crest(self, Vector2(0.0, -1.0), "dawn", _pulse_t > 0.0)
	_draw_signal_pulses()
