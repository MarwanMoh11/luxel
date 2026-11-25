class_name LxWoodPinLamp
extends LxToy
## Island 3 Shifting-Wood compass lamp.
## - Unlit: 3-wedge inlaid moss compass clearly shows `wood_turn` (0=MOSS triangle/lime, 1=SILK diamond/rose,
##   2=CROWN star/gold). Exiting this clearing while unlit advances `wood_turn = (wood_turn + 1) % 3`.
## - Lit: bolt/throw/beam/interact kindles lamp, sets `var_pin = 1` and `pin_turn_<clearing> = wood_turn`, locking
##   this clearing's dynamic `layers` and stopping exits from advancing `wood_turn`.
## - Intentional steering: interacting (E) when lit, OR shooting the dew-cap droplet atop the lit lamp (after a 0.35 s
##   debounce, or immediately with Blue/Dew hits) snuffs the lamp back to unlit (`var_pin = 0`).
## Props: clearing ("w"|"e"|"n"), var_pin (String), var_turn (String, "wood_turn"), lit (bool),
## snuff_on_hit (bool, true), persist (bool, true), target_id/target_ids.

const SCOPE_ISLAND: String = "island:3"
const TOGGLE_DEBOUNCE: float = 0.35

var clearing: String = "w"
var var_pin: String = "pin_w"
var var_turn: String = "wood_turn"
var lit: bool = false
var snuff_on_hit: bool = true
var _debounce_t: float = 0.0
var _pulse_t: float = 0.0
var _orbit_t: float = 0.0


func _toy_setup() -> void:
	kind = "wood_pin_lamp"
	radius = maxf(14.0, radius)
	clearing = str(props.get("clearing", "w")).strip_edges().to_lower()
	if clearing not in ["w", "e", "n"]:
		clearing = "w"
	var_pin = str(props.get("var_pin", "pin_" + clearing)).strip_edges()
	if var_pin.is_empty():
		var_pin = "pin_" + clearing
	var_turn = str(props.get("var_turn", "wood_turn")).strip_edges()
	if var_turn.is_empty():
		var_turn = "wood_turn"
	snuff_on_hit = bool(props.get("snuff_on_hit", true))
	if not props.has("persist"):
		persist = true
	# Sync initial lit state from Lx.vars if already pinned
	var stored_pin: int = int(LxToyDraw.world_get_var(SCOPE_ISLAND, var_pin, 0))
	lit = bool(props.get("lit", false)) or stored_pin != 0
	powered = lit
	_debounce_t = 0.0
	_pulse_t = 0.0
	_orbit_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	set_lit(false, false)


func current_turn() -> int:
	if lit:
		var pt: Variant = LxToyDraw.world_get_var(SCOPE_ISLAND, "pin_turn_" + clearing, null)
		if pt != null and str(pt) != "":
			return posmod(int(pt), 3)
	return posmod(int(LxToyDraw.world_get_var(SCOPE_ISLAND, var_turn, 0)), 3)


func _exit_dir_for_turn(turn: int) -> Vector2:
	# Points toward the clearing exit that opens on `turn` (0=MOSS, 1=SILK, 2=CROWN)
	match clearing:
		"w":
			if turn == 0:
				return Vector2(-0.82, 0.57).normalized() # SW Great Stump -> underroot_r1
			elif turn == 1:
				return Vector2(-1.0, -0.15).normalized() # W -> cave_amber_well
			return Vector2(0.0, -1.0) # N -> ow_shift_n
		"e":
			if turn == 0:
				return Vector2(0.55, 0.83).normalized() # SE -> cave_burrow_den
			elif turn == 1:
				return Vector2(0.92, 0.39).normalized() # ESE Silk Arch -> loom_r1
			return Vector2(0.45, -0.89).normalized() # N/NE -> ow_shift_n & sprint
		"n":
			if turn == 2:
				return Vector2(0.0, -1.0) # N/NW/S Crown Ring open
			return Vector2(1.0, 0.0) # E -> overworld
		_:
			return Vector2(0.0, -1.0)


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _debounce_t > 0.0:
		_debounce_t = maxf(0.0, _debounce_t - dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		dirty = true
	if not lit and not LxHudFx.flash_reduced():
		_orbit_t = fmod(_orbit_t + dt * 1.15, TAU)
		dirty = true
	var stored_pin: bool = int(LxToyDraw.world_get_var(SCOPE_ISLAND, var_pin, 0)) != 0
	if stored_pin != lit:
		lit = stored_pin
		powered = lit
		dirty = true
	if dirty:
		queue_redraw()


func set_lit(want_lit: bool, with_fx: bool = true) -> void:
	if lit == want_lit and _debounce_t > 0.0:
		return
	lit = want_lit
	_debounce_t = TOGGLE_DEBOUNCE
	_pulse_t = 0.36
	var cur_turn: int = posmod(int(LxToyDraw.world_get_var(SCOPE_ISLAND, var_turn, 0)), 3)
	LxToyDraw.world_set_var(SCOPE_ISLAND, var_pin, 1 if lit else 0)
	if lit:
		LxToyDraw.world_set_var(SCOPE_ISLAND, "pin_turn_" + clearing, cur_turn)
	LxToyDraw.world_set_var(SCOPE_ISLAND, "eff_turn_" + clearing, cur_turn if lit else posmod(int(LxToyDraw.world_get_var(SCOPE_ISLAND, var_turn, 0)), 3))
	if not region_id.is_empty():
		LxToyDraw.world_set_var("room:3:" + region_id, "clearing_turn", current_turn())
	set_powered(lit)
	emit_power(lit)
	if region != null and is_instance_valid(region) and region.has_method("apply_layers"):
		region.call("apply_layers")
	if with_fx:
		_emit_sfx("lamp_lit" if lit else "snuffer_snuff")
		_emit_gust(48.0, 32.0)
		if lit and Lx.state != null and not bool(Lx.state.story_flags.get("isl3_pin_taught", false)):
			Lx.state.story_flags["isl3_pin_taught"] = true
			if Lx.events != null and LxStrings.has_id("ISL3_WOOD_PINNED"):
				Lx.events.narration_requested.emit("ISL3_WOOD_PINNED", "narration", 3.2)
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or _debounce_t > 0.0:
		return false
	set_lit(not lit, true)
	return true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source not in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_SUNFLARE, LxDewLens.SOURCE_DEW_RAY]:
		return false
	if not lit:
		if _debounce_t > 0.0:
			return false
		set_lit(true, true)
		return true
	# Lit lamp: blue/dew-cap hit snuffs immediately, or any hit after debounce if snuff_on_hit
	if hit.is_blue() or hit.source == LxDewLens.SOURCE_DEW_RAY or (snuff_on_hit and _debounce_t <= 0.0):
		set_lit(false, true)
		return true
	return false


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "PROMPT_SNUFF_WOOD" if lit else "PROMPT_PIN_WOOD"


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(6.0, 4.0), Vector2(12.0, 10.0)) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active or not lit:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 8.0, 76.0, 1.05)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["lit"] = lit
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("lit"):
		lit = bool(d["lit"])
		powered = lit
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var turn: int = current_turn()

	# 1. Ground-inlaid 3-wedge moss compass ring (readable in greyscale via shape + directional arrow)
	var center := Vector2(0.0, 3.0)
	var wedge_dirs: Array[Vector2] = [Vector2(-1.0, 0.5).normalized(), Vector2(1.0, 0.5).normalized(), Vector2(0.0, -1.0)]
	var wedge_cols: Array[Color] = [c_lime, c_rose, c_gold]
	var wedge_shapes: Array[int] = [2, 1, 5] # 0=triangle (MOSS), 1=diamond (SILK), 2=star (CROWN)
	var cur_col: Color = wedge_cols[turn]
	draw_circle(center, 16.0, c_void)
	draw_circle(center, 15.0, c_night)
	if lit:
		# Solid golden lock-ring + 4 cardinal pin-ticks (reads immediately as PINNED)
		draw_arc(center, 15.0, 0.0, TAU, 24, c_gold, 1.5)
		draw_arc(center, 12.0, 0.0, TAU, 20, cur_col, 1.0)
		for k: int in range(4):
			var ka: float = float(k) * (PI * 0.5)
			var kp: Vector2 = (center + Vector2(cos(ka), sin(ka)) * 16.0).round()
			draw_rect(Rect2(kp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_cream)
	else:
		# Slowly orbiting 3-arc turn indicator (reads immediately as UNPINNED / WILL ROTATE)
		draw_arc(center, 14.0, 0.0, TAU, 20, c_dusk, 1.0)
		for k: int in range(3):
			var a0: float = _orbit_t + float(k) * (TAU / 3.0)
			draw_arc(center, 15.0, a0, a0 + 0.85, 8, cur_col, 1.5)
	for i: int in range(3):
		var wp: Vector2 = (center + wedge_dirs[i] * 9.5).round()
		var is_cur: bool = i == turn
		LxToyDraw.draw_shape_glyph(self, wp, wedge_shapes[i], is_cur, wedge_cols[i] if is_cur else c_dusk, c_cream if is_cur else c_pine)
		if is_cur:
			draw_line(center, wp, c_cream if lit else wedge_cols[i], 1.5)
	# Crisp outer directional pointer pointing straight toward the currently open exit!
	var edir: Vector2 = _exit_dir_for_turn(turn)
	var eperp := Vector2(-edir.y, edir.x)
	var tip: Vector2 = (center + edir * 22.0).round()
	var b1: Vector2 = (center + edir * 16.0 + eperp * 4.0).round()
	var b2: Vector2 = (center + edir * 16.0 - eperp * 4.0).round()
	draw_colored_polygon(PackedVector2Array([tip + edir, b1 - edir * 0.5 + eperp, b2 - edir * 0.5 - eperp]), c_void)
	draw_colored_polygon(PackedVector2Array([tip, b1, b2]), c_cream if lit else cur_col)

	# 2. Brass woodland lantern post
	LxToyDraw.draw_bevel_box(self, Rect2(-5.0, -1.0, 10.0, 6.0), c_night, c_dusk, PAL["stone"] as Color, c_void)
	draw_rect(Rect2(-2.0, -11.0, 4.0, 11.0), c_void)
	draw_rect(Rect2(-1.0, -10.0, 2.0, 9.0), c_apricot if lit else PAL["stone"] as Color)
	# Lantern cage
	LxToyDraw.draw_bevel_box(self, Rect2(-5.0, -17.0, 10.0, 8.0), c_night, c_apricot if lit else c_dusk, c_gold if lit else PAL["stone"] as Color, c_void)
	if lit:
		draw_rect(Rect2(-3.0, -15.0, 6.0, 4.0), c_gold)
		draw_rect(Rect2(-1.0, -14.0, 2.0, 2.0), c_cream)
		# Dew-cap droplet atop the lit lamp (visual tell: shoot to snuff!)
		draw_rect(Rect2(-2.0, -21.0, 4.0, 3.0), c_void)
		draw_rect(Rect2(-1.0, -20.0, 2.0, 2.0), c_sky)
		draw_rect(Rect2(-1.0, -20.0, 1.0, 1.0), c_ice)
	else:
		draw_rect(Rect2(-3.0, -15.0, 6.0, 4.0), c_night)
		draw_rect(Rect2(-1.0, -14.0, 2.0, 2.0), c_dusk)

	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.36, 0.0, 1.0)
		draw_arc(Vector2(0.0, -12.0), roundf(lerpf(5.0, 16.0, u)), 0.0, TAU, 16, c_cream if lit else c_sky, 1.0)
	_draw_signal_pulses()
