class_name LxI5StarBell
extends LxToy
## Island 5 Star Bell: turns rooms, rotors, and islands in 90° quarter steps.
## Yellow hit/bolt/throw/interact advances (val + 90) % 360 (CW);
## Blue/Prism hit reverses (val + 270) % 360 (CCW, optional power_sextant gate).
## Updates Lx.vars, drives linked LxPhysRotor nodes, calls region.apply_layers(), and keeps Wick safe.

enum BellState { IDLE, TURNING }

const TURN_VISUAL_S: float = 1.0

var var_scope: String = "island:5"
var var_name: String = "ow_dial"
var rotors: PackedStringArray = PackedStringArray()
var allow_ccw_blue: bool = true
var require_sextant_ccw: bool = false
var allow_interact: bool = true
var ring_cooldown: float = 1.1

var bell_state: int = BellState.IDLE
var current_angle: int = 0
var last_turn_dir: int = 1
var _cd: float = 0.0
var _turn_t: float = 0.0
var _ring_color_blue: bool = false
var _vars_bound: LxWorldState = null


func _toy_setup() -> void:
	kind = "star_bell"
	radius = 12.0
	var_name = str(props.get("var_name", props.get("var", "ow_dial"))).strip_edges()
	if var_name.is_empty():
		var_name = "ow_dial"
	var raw_scope: String = str(props.get("scope", "")).strip_edges()
	if raw_scope.is_empty():
		var pack_scope: String = ""
		if Lx.packs != null:
			var sv: Dictionary = Lx.packs.state_vars()
			if sv.has(var_name) and sv[var_name] is Dictionary:
				pack_scope = str((sv[var_name] as Dictionary).get("scope", "")).strip_edges()
		var_scope = pack_scope if not pack_scope.is_empty() else ("island:%d" % clampi(island_id, 1, 8))
	elif raw_scope == "island":
		var_scope = "island:%d" % clampi(island_id, 1, 8)
	elif raw_scope == "dungeon":
		var did: String = Lx.packs.dungeon_of(island_id, region_id) if Lx.packs != null else ""
		var_scope = ("dungeon:" + did) if not did.is_empty() else ("island:%d" % clampi(island_id, 1, 8))
	elif raw_scope == "room":
		var_scope = "room:%d:%s" % [clampi(island_id, 1, 8), region_id]
	else:
		var_scope = raw_scope
	rotors = PackedStringArray()
	var raw_r: Variant = props.get("rotors", [])
	if raw_r is Array:
		for rv: Variant in (raw_r as Array):
			var rs: String = str(rv).strip_edges()
			if not rs.is_empty():
				rotors.append(rs)
	allow_ccw_blue = bool(props.get("allow_ccw_blue", true))
	require_sextant_ccw = bool(props.get("require_sextant_ccw", false))
	allow_interact = bool(props.get("allow_interact", true))
	ring_cooldown = maxf(0.25, float(props.get("cooldown", 1.1)))
	bell_state = BellState.IDLE
	_cd = 0.0
	_turn_t = 0.0
	_sync_from_var()
	_bind_vars()
	queue_redraw()


func _exit_tree() -> void:
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = null


func _bind_vars() -> void:
	if Lx.vars == null or _vars_bound == Lx.vars:
		return
	_vars_bound = Lx.vars
	if not _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.connect(_on_var_changed)


func _on_var_changed(scope: String, vname: String, val: Variant) -> void:
	if vname == var_name and (scope == var_scope or var_scope.is_empty()):
		current_angle = posmod(int(roundf(float(val))), 360) if (val is int or val is float or str(val).is_valid_float()) else 0
		powered = current_angle != 0
		queue_redraw()


func _sync_from_var() -> void:
	if Lx.vars != null:
		var v: Variant = Lx.vars.get_var(var_scope, var_name, 0)
		current_angle = posmod(int(roundf(float(v))), 360) if (v is int or v is float or str(v).is_valid_float()) else 0
	else:
		current_angle = 0
	powered = current_angle != 0


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-7.0, -5.0), Vector2(14.0, 12.0)) if is_solid() else Rect2()


func get_interact_prompt() -> String:
	return "I5_PROMPT_RING_BELL" if (active and allow_interact) else ""


func interact(_actor: Node = null) -> bool:
	if not active or not allow_interact or _cd > 0.0:
		return false
	return ring(false)


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _cd > 0.0:
		return false
	if hit.source not in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		return false
	var is_blue: bool = (hit.has_method("is_blue") and hit.is_blue()) or hit.source == LxHit.SOURCE_PRISM
	ring(is_blue)
	return true


func ring(is_blue: bool = false) -> bool:
	if not active or _cd > 0.0:
		return false
	var do_ccw: bool = is_blue and allow_ccw_blue
	if do_ccw and require_sextant_ccw:
		if Lx.state == null or not bool(Lx.state.story_flags.get("power_sextant", false)):
			do_ccw = false
	var step_deg: int = 270 if do_ccw else 90
	var dir_sign: int = -1 if do_ccw else 1
	_sync_from_var()
	var next_deg: int = posmod(current_angle + step_deg, 360)
	current_angle = next_deg
	last_turn_dir = dir_sign
	_ring_color_blue = do_ccw
	bell_state = BellState.TURNING
	_turn_t = TURN_VISUAL_S
	_cd = ring_cooldown

	# Drive explicitly linked rotors first (if they aren't auto-bound to the same var)
	if region != null and region.has_method("find_interactable"):
		for rid: String in rotors:
			var rnode: Variant = region.call("find_interactable", rid)
			if rnode is LxPhysRotor and is_instance_valid(rnode as Object):
				var rot: LxPhysRotor = rnode as LxPhysRotor
				if rot.linked_var != var_name:
					rot.trigger_quarter_turn(dir_sign)

	# Write Lx.vars (triggers region.apply_layers(true) + safe Wick relocation automatically)
	if Lx.vars != null:
		Lx.vars.set_var(var_scope, var_name, next_deg)
	if region != null and region.has_method("apply_layers"):
		region.call("apply_layers", true)

	set_powered(next_deg != 0)
	_notify_linked_targets(true)
	_emit_sfx("star_bell_turn")
	_emit_gust(64.0, 46.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.10)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _turn_t > 0.0:
		_turn_t = maxf(0.0, _turn_t - dt)
		dirty = true
		if _turn_t <= 0.0:
			bell_state = BellState.IDLE
	if dirty:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var boost: float = clampf(_turn_t / TURN_VISUAL_S, 0.0, 1.0)
	return Vector4(pos.x, pos.y - 3.0, 34.0 + boost * 36.0, 0.45 + boost * 0.55)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["current_angle"] = current_angle
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("current_angle"):
		current_angle = posmod(int(d["current_angle"]), 360)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var fr: bool = LxHudFx.flash_reduced()
	var turning: bool = bell_state == BellState.TURNING and _turn_t > 0.0
	var swing: float = 0.0
	if turning:
		var u: float = clampf(_turn_t / TURN_VISUAL_S, 0.0, 1.0)
		swing = sin(u * PI * (3.0 if fr else 6.0)) * (1.5 if fr else 3.0) * float(last_turn_dir)

	_draw_ground_shadow(9.0, 3.5, Vector2(2.0, 7.0))
	# Stone plinth + 4-quarter compass dial on base
	LxPhysDraw.draw_bevel_box(self, Rect2(-8.0, 1.0, 16.0, 7.0), PAL["night"] as Color, PAL["mauve"] as Color, PAL["dusk"] as Color, PAL["void"] as Color)
	var needle_ang: float = deg_to_rad(float(current_angle) - 90.0)
	var nd: Vector2 = Vector2.from_angle(needle_ang)
	draw_line(Vector2(0.0, 4.0), (Vector2(0.0, 4.0) + nd * 4.0).round(), PAL["cream"] as Color, 1.0)
	for qi: int in range(4):
		var qa: float = deg_to_rad(float(qi * 90) - 90.0)
		var qp: Vector2 = (Vector2(0.0, 4.0) + Vector2.from_angle(qa) * 5.0).round()
		draw_rect(Rect2(qp, Vector2.ONE), PAL["gold"] as Color if (qi * 90 == current_angle) else PAL["plum"] as Color)

	# Flared brass astrolabe bell body
	var bell_x: float = roundf(swing * 0.5)
	var body_c: Color = (PAL["ice"] if (turning and _ring_color_blue) else (PAL["cream"] if turning else PAL["gold"])) as Color
	var rim_c: Color = (PAL["sky"] if (turning and _ring_color_blue) else PAL["apricot"]) as Color
	draw_rect(Rect2(bell_x - 3.0, -11.0, 6.0, 2.0), PAL["void"] as Color)
	draw_rect(Rect2(bell_x - 2.0, -10.0, 4.0, 2.0), rim_c)
	draw_rect(Rect2(bell_x - 5.0, -9.0, 10.0, 5.0), PAL["void"] as Color)
	draw_rect(Rect2(bell_x - 4.0, -8.0, 8.0, 4.0), body_c)
	draw_rect(Rect2(bell_x - 7.0, -4.0, 14.0, 4.0), PAL["void"] as Color)
	draw_rect(Rect2(bell_x - 6.0, -4.0, 12.0, 3.0), rim_c)
	draw_rect(Rect2(bell_x - 4.0, -7.0, 2.0, 4.0), PAL["cream"] as Color)
	# Swinging star clapper underneath
	var clap_x: float = roundf(swing)
	draw_rect(Rect2(clap_x - 1.0, -1.0, 3.0, 3.0), PAL["void"] as Color)
	draw_rect(Rect2(clap_x, 0.0, 1.0, 1.0), PAL["cream"] as Color)
	# Crown 4-point star finial
	draw_rect(Rect2(bell_x - 1.0, -13.0, 2.0, 2.0), PAL["cream"] as Color)
	draw_line(Vector2(bell_x - 3.0, -12.0), Vector2(bell_x + 3.0, -12.0), PAL["gold"] as Color, 1.0)

	# Expanding turn ripple
	if turning:
		var ru: float = 1.0 - clampf(_turn_t / TURN_VISUAL_S, 0.0, 1.0)
		var ring_c: Color = (PAL["ice"] if _ring_color_blue else PAL["gold"]) as Color
		draw_arc(Vector2(0.0, -4.0), lerpf(8.0, 38.0, ru), 0.0, TAU, 24, Color(ring_c, (1.0 - ru) * 0.85), 1.4)
		draw_arc(Vector2(0.0, -4.0), lerpf(5.0, 26.0, ru), 0.0, TAU, 18, Color(PAL["cream"] as Color, (1.0 - ru) * 0.65), 1.0)
	_draw_signal_pulses()
