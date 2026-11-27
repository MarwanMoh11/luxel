class_name LxI5PolarityWell
extends LxPhysGravityWell
## Island 5 Switchable Polarity Well (extends LxPhysGravityWell & registers with LxFields).
## PULL (indigo inward) <-> PUSH (gold outward) toggled by shooting its center prism,
## flipping a linked crystal_toggle, or syncing with an Lx.vars phase variable (`well_phase`).
## Supports Apogee Clasp (`power_orbit_ring`) tangential lantern orbit capture & `lens_only`.

const PRISM_FLIP_CD: float = 0.28

var linked_crystal: String = ""
var linked_var: String = ""
var var_scope: String = ""
var writes_var: bool = false

var _prism_cd: float = 0.0
var _vars_bound: LxWorldState = null


func _toy_setup() -> void:
	# Apply Island 5 bible defaults before super._toy_setup() reads props
	if not props.has("radius"):
		props["radius"] = 72.0
	if not props.has("strength"):
		props["strength"] = 420.0
	if not props.has("orbit_capture"):
		props["orbit_capture"] = true
	if not props.has("orbit_r"):
		props["orbit_r"] = 34.0
	super._toy_setup()
	kind = "polarity_well"
	radius = 10.0 # Center prism toggle hitbox; grazing shots > 12px curve without flipping
	linked_crystal = str(props.get("linked_crystal", "")).strip_edges()
	linked_var = str(props.get("linked_var", "")).strip_edges()
	writes_var = bool(props.get("writes_var", false))
	var raw_scope: String = str(props.get("scope", "")).strip_edges()
	if raw_scope.is_empty():
		var pack_scope: String = ""
		if not linked_var.is_empty() and Lx.packs != null:
			var sv: Dictionary = Lx.packs.state_vars()
			if sv.has(linked_var) and sv[linked_var] is Dictionary:
				pack_scope = str((sv[linked_var] as Dictionary).get("scope", "")).strip_edges()
		if not pack_scope.is_empty():
			var_scope = pack_scope
		else:
			var did: String = Lx.packs.dungeon_of(island_id, region_id) if Lx.packs != null else ""
			var_scope = ("dungeon:" + did) if not did.is_empty() else ("island:%d" % clampi(island_id, 1, 8))
	else:
		var_scope = raw_scope
	_prism_cd = 0.0
	if not linked_var.is_empty():
		_sync_from_var()
		_bind_vars()
	powered = is_push
	queue_redraw()


func _exit_tree() -> void:
	super._exit_tree()
	if _vars_bound != null and _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.disconnect(_on_var_changed)
	_vars_bound = null


func _bind_vars() -> void:
	if Lx.vars == null or _vars_bound == Lx.vars:
		return
	_vars_bound = Lx.vars
	if not _vars_bound.var_changed.is_connected(_on_var_changed):
		_vars_bound.var_changed.connect(_on_var_changed)


func _sync_from_var() -> void:
	if Lx.vars == null or linked_var.is_empty():
		return
	var v: Variant = Lx.vars.resolve_var(linked_var, island_id, region_id, "pull")
	var s: String = str(v).strip_edges().to_lower()
	is_push = (s == "push" or s == "1" or s == "true")
	powered = is_push


func _on_var_changed(_scope: String, vname: String, val: Variant) -> void:
	if linked_var.is_empty() or vname != linked_var:
		return
	var s: String = str(val).strip_edges().to_lower()
	var want_push: bool = (s == "push" or s == "1" or s == "true")
	if want_push != is_push:
		is_push = want_push
		powered = is_push
		_flip_flash_t = 0.28
		_emit_sfx("polarity_flip")
		queue_redraw()


## Calibrated curve multipliers so bible default strength=420 bends bolts 45-95° around stone baffles
## within the 118 px bolt range and curves meteor_orbs cleanly around chasms.
func _what_multiplier(what: String) -> float:
	match what:
		"bolt", "beam":
			return 3.8
		"lantern":
			return 2.4
		"block":
			return 2.6
		"enemy":
			return 0.48
		"wick":
			return 0.08
	return 1.0


func get_mode() -> String:
	return "push" if is_push else "pull"


func set_mode(mode_s: String, broadcast_var: bool = false) -> void:
	var want_push: bool = mode_s.strip_edges().to_lower() == "push"
	if want_push == is_push:
		return
	is_push = want_push
	powered = is_push
	_flip_flash_t = 0.28
	if broadcast_var and not linked_var.is_empty() and Lx.vars != null:
		Lx.vars.set_var(var_scope, linked_var, get_mode())
	_emit_sfx("polarity_flip")
	_notify_linked_targets(is_push)
	queue_redraw()


func flip_polarity() -> void:
	set_mode("pull" if is_push else "push", writes_var)


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _prism_cd > 0.0:
		return false
	if lens_only and _revealed_t <= 0.0:
		return false
	if hit.source not in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "sunflare"]:
		return false
	_prism_cd = PRISM_FLIP_CD
	flip_polarity()
	return true


func interact(_actor: Node = null) -> bool:
	if not active or _prism_cd > 0.0:
		return false
	if lens_only and _revealed_t <= 0.0:
		return false
	_prism_cd = PRISM_FLIP_CD
	flip_polarity()
	return true


func on_signal(from_id: String, is_on: bool) -> void:
	if not linked_crystal.is_empty() and from_id == linked_crystal:
		set_mode("push" if is_on else "pull", writes_var)
		return
	super.on_signal(from_id, is_on)


## Compatibility hook for LxCrystalToggle group broadcast
func set_group_phase(new_phase: int) -> void:
	if linked_crystal.is_empty():
		return
	set_mode("push" if new_phase == 1 else "pull", writes_var)


func tick(dt: float) -> void:
	if _prism_cd > 0.0:
		_prism_cd = maxf(0.0, _prism_cd - dt)
	if not linked_crystal.is_empty() and region != null and region.has_method("find_interactable"):
		var cr: Variant = region.call("find_interactable", linked_crystal)
		if cr is Object and is_instance_valid(cr as Object) and (cr as Object).get("phase") is int:
			var want_push: bool = int((cr as Object).get("phase")) == 1
			if want_push != is_push:
				set_mode("push" if want_push else "pull", writes_var)
	super.tick(dt)


func _draw() -> void:
	super._draw()
	if not active or (lens_only and _revealed_t <= 0.0):
		return
	var fr: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color
	var d_col: Color = (PAL["cream"] if is_push else PAL["ice"]) as Color
	var e_col: Color = (PAL["coral"] if is_push else PAL["sky"]) as Color
	var rim_col: Color = (PAL["gold"] if is_push else PAL["sky"]) as Color
	var collar_a: float = 0.62 if fr else 0.88

	# Calm steady outer polarity guide ring + cardinal direction ticks for instant still-frame readability
	draw_arc(Vector2.ZERO, roundf(field_radius * 0.56), 0.0, TAU, 24, Color(rim_col, 0.24 if fr else 0.16), 1.0)
	for ci: int in range(4):
		var cdir := Vector2.from_angle(float(ci) * PI * 0.5)
		var r_a: float = 11.0 if is_push else 14.0
		var r_b: float = 14.0 if is_push else 11.0
		draw_line((cdir * r_a).round(), (cdir * r_b).round(), Color(e_col, collar_a), 1.0)
		draw_rect(Rect2((cdir * r_b).round(), Vector2.ONE), Color(d_col, collar_a))

	# Distinct switchable center crystal prism diamond (tells player: shoot center to flip!)
	var diamond := PackedVector2Array([Vector2(0.0, -5.0), Vector2(5.0, 0.0), Vector2(0.0, 5.0), Vector2(-5.0, 0.0)])
	draw_colored_polygon(diamond, c_void)
	var inner := PackedVector2Array([Vector2(0.0, -3.0), Vector2(3.0, 0.0), Vector2(0.0, 3.0), Vector2(-3.0, 0.0)])
	draw_colored_polygon(inner, Color(d_col, 0.88 if fr else 1.0))
	for i: int in range(4):
		draw_line(diamond[i], diamond[(i + 1) % 4], Color(e_col, collar_a), 1.0)
	if not is_push:
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["deep"] as Color)
	elif not fr and _flip_flash_t > 0.0:
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), PAL["cream"] as Color)
	if _flip_flash_t > 0.0 and fr:
		# Reduced-flash steady confirmation halo instead of bright expanding strobe
		var fu: float = clampf(_flip_flash_t / 0.28, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 16, Color(rim_col, fu * 0.55), 1.0)
	_draw_signal_pulses()
