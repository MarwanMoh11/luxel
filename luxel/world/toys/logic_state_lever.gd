class_name LxStateLever
extends LxToy
## World-state lever (Tide Organ, Brass Tide-Wheel, Ballast Valve / Pedal, Town Bell, Weather Wheel).
## Cycles `values` and writes to `Lx.vars` (`LxWorldState`), triggering `region.apply_layers()`.
## Bolt hits (from foot or Skiff) sound it unmistakably with an acoustic brass ring & pitched cue.
## Props: scope (String), var (String), values (Array), index (int), shootable (bool), style (String),
## step_trigger (bool), persist (bool), target_id/target_ids.

var var_scope: String = "island:1"
var var_name: String = "state"
var values: Array = ["off", "on"]
var current_index: int = 0
var shootable: bool = true
var style: String = "lever"
var step_trigger: bool = false
var _init_index: int = 0
var _cd: float = 0.0
var _shift_t: float = 0.0
var _sound_ring_t: float = 0.0
var _wick_was_on_pedal: bool = false
var _synced_val: String = ""


func _toy_setup() -> void:
	kind = "state_lever"
	var raw_scope: String = str(props.get("scope", "")).strip_edges()
	if raw_scope.is_empty() or raw_scope == "island":
		var_scope = "island:%d" % clampi(island_id, 1, 8)
	elif raw_scope == "room":
		var_scope = "room:%d:%s" % [clampi(island_id, 1, 8), region_id]
	else:
		var_scope = raw_scope
	var_name = str(props.get("var", "state")).strip_edges()
	if var_name.is_empty():
		var_name = "state"
	var raw_vals: Variant = props.get("values", ["off", "on"])
	values = (raw_vals as Array).duplicate() if (raw_vals is Array and not (raw_vals as Array).is_empty()) else ["off", "on"]
	_init_index = clampi(int(props.get("index", 0)), 0, values.size() - 1)
	current_index = _init_index
	shootable = bool(props.get("shootable", true))
	var raw_style: String = str(props.get("style", "auto")).strip_edges().to_lower()
	if raw_style == "auto" or raw_style.is_empty():
		if var_name == "tide":
			style = "tide_organ"
		elif var_name == "tower_tide":
			style = "tide_wheel"
		elif var_name == "list":
			style = "ballast_valve"
		elif var_name == "lock_water":
			style = "sluice_organ"
		else:
			style = "lever"
	else:
		style = raw_style
	step_trigger = bool(props.get("step_trigger", style == "pedal"))
	if not props.has("persist"):
		persist = true
	radius = maxf(13.0 if style in ["tide_organ", "sluice_organ", "tide_wheel"] else 12.0, radius)
	_cd = 0.0
	_shift_t = 0.0
	_sound_ring_t = 0.0
	_wick_was_on_pedal = false
	if not persist and var_scope.begins_with("room:"):
		_synced_val = str(get_current_value())
		LxToyDraw.world_set_var(var_scope, var_name, get_current_value())
	else:
		_sync_from_world_var()
	powered = current_index > 0
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	set_value_index(_init_index)


func _find_value_index(val: Variant) -> int:
	var s: String = str(val)
	for i: int in range(values.size()):
		if str(values[i]) == s:
			return i
	return -1


func _sync_from_world_var() -> void:
	var existing: Variant = LxToyDraw.world_get_var(var_scope, var_name, null)
	if existing == null:
		return
	var s: String = str(existing)
	if s == _synced_val:
		return
	_synced_val = s
	var found: int = _find_value_index(existing)
	if found >= 0 and found != current_index:
		current_index = found
		powered = current_index > 0
		queue_redraw()


func get_current_value() -> Variant:
	return values[clampi(current_index, 0, values.size() - 1)]


func tick(dt: float) -> void:
	super.tick(dt)
	_sync_from_world_var()
	var dirty: bool = false
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _shift_t > 0.0:
		_shift_t = maxf(0.0, _shift_t - dt)
		dirty = true
	if _sound_ring_t > 0.0:
		_sound_ring_t = maxf(0.0, _sound_ring_t - dt)
		dirty = true
	if step_trigger and active:
		var wp: Vector2 = wick_pos()
		var on_now: bool = wp.distance_to(pos) <= 10.0 and (Lx.player == null or Lx.player.get("dead") != true)
		if on_now and not _wick_was_on_pedal and _cd <= 0.0:
			cycle()
			dirty = true
		_wick_was_on_pedal = on_now
	if dirty:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or _cd > 0.0:
		return false
	cycle()
	return true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or not shootable or _cd > 0.0:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		cycle()
		return true
	return false


func get_interact_prompt() -> String:
	if not active:
		return ""
	var custom_p: String = str(props.get("prompt", "")).strip_edges()
	if not custom_p.is_empty() and LxStrings.has_id(custom_p):
		return custom_p
	if (style == "tide_organ" or style == "sluice_organ") and LxStrings.has_id("PROMPT_TIDE_ORGAN"):
		return "PROMPT_TIDE_ORGAN"
	if (style == "ballast_valve" or style == "pedal") and LxStrings.has_id("PROMPT_BALLAST"):
		return "PROMPT_BALLAST"
	return "PROMPT_PULL_LEVER"


func cycle() -> void:
	set_value_index((current_index + 1) % values.size())


func set_value_index(idx: int) -> void:
	current_index = posmod(idx, values.size())
	_cd = 0.25
	_shift_t = 0.36
	_sound_ring_t = 0.42
	var val: Variant = get_current_value()
	_synced_val = str(val)
	LxToyDraw.world_set_var(var_scope, var_name, val)
	if region != null and is_instance_valid(region) and region.has_method("apply_layers"):
		region.call("apply_layers")
	_play_sound_cue()
	_emit_gust(56.0, 38.0)
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("spawn_sparks"):
		Lx.player.call("spawn_sparks", pos + Vector2(0.0, -6.0), Vector2.UP, 6, LxBiomePalette.col(island_id, "glow"), 28.0, 72.0, 0.22)
	set_powered(current_index > 0)
	_notify_linked_targets(current_index > 0)
	queue_redraw()


func _play_sound_cue() -> void:
	if style == "tide_organ" or style == "sluice_organ":
		_emit_sfx("lighthouse_toll")
		_emit_sfx("tide_surge")
	elif style == "tide_wheel":
		_emit_sfx("clockwork_chime")
		_emit_sfx("tide_surge")
	elif style == "ballast_valve" or style == "pedal":
		_emit_sfx("harbor_creak")
	elif var_name.contains("tide"):
		_emit_sfx("tide_surge")
	else:
		_emit_sfx("mirror_turn")


func is_solid() -> bool:
	return active and not step_trigger


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	if style == "tide_organ" or style == "sluice_organ":
		return Rect2(pos + Vector2(-8.0, -4.0), Vector2(16.0, 10.0))
	return Rect2(pos + Vector2(-6.0, -2.0), Vector2(12.0, 8.0))


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var r: float = 42.0 if _sound_ring_t > 0.0 else (28.0 if style in ["tide_organ", "tide_wheel"] else 24.0)
	return Vector4(pos.x, pos.y - 4.0, r, 0.72 if _sound_ring_t > 0.0 else 0.38)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["index"] = current_index
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("index"):
		current_index = clampi(int(d["index"]), 0, values.size() - 1)
		powered = current_index > 0
		_synced_val = str(get_current_value())
		LxToyDraw.world_set_var(var_scope, var_name, get_current_value())
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var trip: Array[Color] = LxToyDraw.skin_triplet(island_id, skin)
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var c_cream: Color = PAL["cream"] as Color

	if style == "tide_organ" or style == "sluice_organ":
		_draw_tide_organ(c_void, c_glow, c_cream)
	elif style == "tide_wheel":
		_draw_tide_wheel(c_void, c_glow, c_cream)
	elif style == "pedal":
		_draw_pedal(c_void, trip, c_glow, c_cream)
	else:
		_draw_lever(c_void, trip, c_glow, c_cream)

	# Expanding acoustic brass ring on bolt hit / activation
	if _sound_ring_t > 0.0:
		var u: float = 1.0 - clampf(_sound_ring_t / 0.42, 0.0, 1.0)
		var rr: float = roundf(lerpf(6.0, 26.0, u))
		var alpha: float = (1.0 - u) * (0.55 if LxHudFx.flash_reduced() else 0.90)
		var rw: float = 2.0 if u < 0.4 else 1.0
		draw_arc(Vector2(0.0, -5.0), rr, 0.0, TAU, 18, Color(c_cream if u < 0.35 else c_glow, alpha), rw)
	_draw_signal_pulses()


func _draw_tide_organ(c_void: Color, c_glow: Color, c_cream: Color) -> void:
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 9.0, 3.0)
	# Harbor stone plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -2.0, 18.0, 8.0), PAL["night"] as Color, PAL["deep"] as Color, PAL["stone"] as Color, c_void)
	# Three stepped brass organ pipes: lit pipe count = current_index + 1 (greyscale distinct!)
	var heights: Array[float] = [8.0, 12.0, 16.0]
	var xs: Array[float] = [-6.0, -1.0, 4.0]
	var lit_count: int = clampi(current_index + 1, 1, 3)
	for i: int in range(3):
		var ph: float = heights[i]
		var px: float = xs[i]
		var is_lit: bool = i < lit_count
		var body_c: Color = (PAL["gold"] if is_lit else PAL["dusk"]) as Color
		var hi_c: Color = (c_cream if is_lit else PAL["mauve"]) as Color
		draw_rect(Rect2(px - 1.0, -2.0 - ph, 5.0, ph + 1.0), c_void)
		draw_rect(Rect2(px, -1.0 - ph, 3.0, ph), body_c)
		draw_rect(Rect2(px, -1.0 - ph, 1.0, ph), hi_c)
		# Pipe lip / sound mouth
		draw_rect(Rect2(px, -3.0, 3.0, 1.0), c_void)
		if is_lit:
			draw_rect(Rect2(px + 1.0, -2.0 - ph, 1.0, 1.0), c_cream if _sound_ring_t > 0.0 else c_glow)
	# Front tide-level pips
	for i: int in range(mini(3, values.size())):
		var is_cur: bool = i == current_index
		draw_rect(Rect2(-5.0 + float(i) * 4.0, 2.0, 3.0, 2.0), c_cream if is_cur else PAL["night"] as Color)


func _draw_tide_wheel(c_void: Color, c_glow: Color, c_cream: Color) -> void:
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, 0.0, 14.0, 6.0), PAL["night"] as Color, PAL["deep"] as Color, PAL["stone"] as Color, c_void)
	var center := Vector2(0.0, -5.0)
	var rot: float = float(current_index) * (PI / 3.0)
	draw_circle(center, 7.0, c_void)
	draw_arc(center, 5.5, 0.0, TAU, 14, PAL["apricot"] as Color, 2.0)
	for k: int in range(6):
		var a: float = rot + float(k) * (TAU / 6.0)
		var tip: Vector2 = (center + Vector2(cos(a) * 7.0, sin(a) * 7.0)).round()
		draw_line(center, tip, PAL["gold"] as Color if k % 2 == 0 else PAL["apricot"] as Color, 1.0)
		draw_rect(Rect2(tip, Vector2.ONE), c_cream if k == 0 else PAL["gold"] as Color)
	draw_rect(Rect2(center - Vector2.ONE, Vector2(2.0, 2.0)), c_cream if current_index > 0 else c_glow)
	for i: int in range(mini(3, values.size())):
		draw_rect(Rect2(-4.0 + float(i) * 4.0, 2.0, 2.0, 2.0), c_cream if i == current_index else PAL["night"] as Color)


func _draw_pedal(c_void: Color, trip: Array[Color], c_glow: Color, c_cream: Color) -> void:
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 9.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -5.0, 18.0, 10.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["stone"] as Color, c_void)
	for rx: float in [-8.0, 7.0]:
		for ry: float in [-4.0, 3.0]:
			draw_rect(Rect2(rx, ry, 1.0, 1.0), c_gold if current_index > 0 else c_apricot)
	var tilt_x: float = -4.0 if current_index == 0 else 1.0
	draw_rect(Rect2(-6.0, -2.0, 12.0, 4.0), c_void)
	draw_rect(Rect2(-5.0, -1.0, 10.0, 2.0), PAL["night"] as Color)
	draw_rect(Rect2(tilt_x - 1.0, -3.0, 6.0, 6.0), c_void)
	draw_rect(Rect2(tilt_x, -2.0, 4.0, 4.0), c_glow if current_index > 0 else c_apricot)
	draw_rect(Rect2(tilt_x, -2.0, 3.0, 1.0), c_cream if current_index > 0 else c_gold)
	draw_rect(Rect2(tilt_x + 3.0, -1.0, 1.0, 3.0), trip[0])


func _draw_lever(c_void: Color, trip: Array[Color], c_glow: Color, c_cream: Color) -> void:
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var is_on: bool = current_index > 0
	var n_vals: int = maxi(2, values.size())
	var frac: float = float(current_index) / float(n_vals - 1)

	# Grounded drop shadow beneath chunky housing
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 10.0, 3.0)

	# Chunky riveted stone/brass floor housing
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -3.0, 18.0, 9.0), c_night, c_dusk, c_stone, c_void)
	# Brass side cheek plates & corner rivets
	draw_rect(Rect2(-8.0, -2.0, 2.0, 6.0), c_apricot if not is_on else c_gold)
	draw_rect(Rect2(6.0, -2.0, 2.0, 6.0), c_apricot if not is_on else c_gold)
	for rx: float in [-8.0, 7.0]:
		for ry: float in [-2.0, 4.0]:
			draw_rect(Rect2(rx, ry, 1.0, 1.0), c_cream if is_on else c_gold)

	# Recessed slot track across housing top
	draw_rect(Rect2(-6.0, -2.0, 12.0, 4.0), c_void)
	draw_rect(Rect2(-5.0, -1.0, 10.0, 2.0), c_night)
	draw_rect(Rect2(-5.0, -2.0, 10.0, 1.0), c_mauve)

	# Sliding pivot collar & bold tilted lever shaft
	var pivot_x: float = roundf(lerpf(-3.0, 3.0, frac))
	var base := Vector2(pivot_x, -1.0)
	var angle: float = lerpf(-0.72, 0.72, frac)
	var knob: Vector2 = (base + Vector2(sin(angle) * 12.0, -cos(angle) * 12.0)).round()
	draw_rect(Rect2(pivot_x - 2.0, -2.0, 5.0, 4.0), c_void)
	draw_rect(Rect2(pivot_x - 1.0, -1.0, 3.0, 2.0), c_gold if is_on else c_apricot)

	# Thick shadowed handle rod with bright metallic catch-light
	draw_line(base, knob, c_void, 4.0, false)
	draw_line(base, knob, c_mauve, 2.0, false)
	draw_line(base + Vector2(-1.0, 0.0), knob + Vector2(-1.0, 0.0), c_gold if is_on else c_stone, 1.0, false)

	# Bright sculpted pommel knob at handle tip
	draw_rect(Rect2(knob.x - 3.0, knob.y - 3.0, 7.0, 7.0), c_void)
	draw_rect(Rect2(knob.x - 2.0, knob.y - 2.0, 5.0, 5.0), c_apricot if is_on else trip[0])
	draw_rect(Rect2(knob.x - 2.0, knob.y - 2.0, 4.0, 4.0), c_gold if is_on else c_apricot)
	draw_rect(Rect2(knob.x - 2.0, knob.y - 2.0, 2.0, 2.0), c_cream)

	# Glowing state pip bezel along front edge of housing
	var span: float = float(n_vals - 1) * 4.0
	var bz_x: float = roundf(-span * 0.5) - 2.0
	draw_rect(Rect2(bz_x, 2.0, span + 5.0, 4.0), c_void)
	for i: int in range(n_vals):
		var px: float = roundf(-span * 0.5 + float(i) * 4.0)
		var is_cur: bool = i == current_index
		if is_cur:
			draw_rect(Rect2(px - 1.0, 3.0, 3.0, 2.0), c_glow if is_on else c_gold)
			draw_rect(Rect2(px, 3.0, 1.0, 2.0), c_cream)
		else:
			draw_rect(Rect2(px, 3.0, 1.0, 2.0), c_dusk)
