class_name LxLoomWarpWheel
extends LxToy
## Tension Warp-Wheel in The Heddle Hub (loom_r2).
## Shifts dungeon:loom var `loom_warp` from "high" to "low" for `snap_secs` (5.5 s) before groaning
## back to "high" UNLESS the linked lock spool (`lock_spool_id`) is frozen blue, in which case
## the wheel frost-locks in "low" for the full freeze duration (and latches `sets_flag` if configured).
## Props: lock_spool_id (String), snap_secs (float, 5.5), scope (String, "dungeon:loom"),
## var (String, "loom_warp"), sets_flag (String), persist (bool), target_id/target_ids.

var lock_spool_id: String = ""
var snap_secs: float = 5.5
var var_scope: String = "dungeon:loom"
var var_name: String = "loom_warp"
var sets_flag: String = ""

var is_low: bool = false
var frost_locked: bool = false
var snap_t: float = 0.0
var _cd: float = 0.0
var _spin_t: float = 0.0


func _toy_setup() -> void:
	kind = "loom_warp_wheel"
	radius = 14.0
	lock_spool_id = str(props.get("lock_spool_id", "")).strip_edges()
	snap_secs = maxf(2.0, float(props.get("snap_secs", 5.5)))
	var_scope = str(props.get("scope", "dungeon:loom")).strip_edges()
	var_name = str(props.get("var", "loom_warp")).strip_edges()
	sets_flag = str(props.get("sets_flag", "")).strip_edges()
	var cur_v: String = str(LxToyDraw.world_get_var(var_scope, var_name, "high"))
	var flag_done: bool = (not sets_flag.is_empty()) and Lx.state != null and bool(Lx.state.story_flags.get(sets_flag, false))
	is_low = (cur_v == "low") or flag_done
	frost_locked = flag_done or (is_low and _is_spool_frozen())
	snap_t = 0.0
	_cd = 0.0
	_spin_t = 0.0
	if is_low:
		LxToyDraw.world_set_var(var_scope, var_name, "low")
	powered = is_low and frost_locked
	queue_redraw()


func reset_toy() -> void:
	if persist and frost_locked:
		return
	is_low = false
	frost_locked = false
	snap_t = 0.0
	LxToyDraw.world_set_var(var_scope, var_name, "high")
	if region != null and region.has_method("apply_layers"):
		region.call("apply_layers")
	set_powered(false)
	emit_power(false)
	queue_redraw()


func _is_spool_frozen() -> bool:
	if lock_spool_id.is_empty() or region == null or not region.has_method("find_interactable"):
		return false
	var sp: Variant = region.call("find_interactable", lock_spool_id)
	if sp is LxSilkLoomSpool:
		return (sp as LxSilkLoomSpool).is_frozen()
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _spin_t > 0.0:
		_spin_t = maxf(0.0, _spin_t - dt)
		dirty = true
	var spool_frz: bool = _is_spool_frozen()
	if is_low:
		if spool_frz:
			if not frost_locked:
				frost_locked = true
				snap_t = 0.0
				set_powered(true)
				emit_power(true)
				if not sets_flag.is_empty() and Lx.state != null:
					Lx.state.story_flags[sets_flag] = true
				_emit_sfx("mirror_ping")
				dirty = true
		elif not frost_locked:
			if snap_t > 0.0:
				snap_t = maxf(0.0, snap_t - dt)
				dirty = true
				if snap_t <= 0.0:
					_snap_back_high()
					dirty = true
		elif not persist and not spool_frz:
			# Thawed after freeze expired when not persistent
			frost_locked = false
			snap_t = 1.8
			dirty = true
	if dirty:
		queue_redraw()


func _set_low() -> void:
	is_low = true
	_cd = 0.25
	_spin_t = 0.36
	frost_locked = _is_spool_frozen()
	snap_t = 0.0 if frost_locked else snap_secs
	LxToyDraw.world_set_var(var_scope, var_name, "low")
	if region != null and region.has_method("apply_layers"):
		region.call("apply_layers")
	if frost_locked:
		set_powered(true)
		emit_power(true)
		if not sets_flag.is_empty() and Lx.state != null:
			Lx.state.story_flags[sets_flag] = true
	_emit_sfx("harbor_creak")
	_emit_gust(54.0, 36.0)
	queue_redraw()


func _snap_back_high() -> void:
	is_low = false
	frost_locked = false
	snap_t = 0.0
	_spin_t = 0.30
	LxToyDraw.world_set_var(var_scope, var_name, "high")
	if region != null and region.has_method("apply_layers"):
		region.call("apply_layers")
	set_powered(false)
	emit_power(false)
	_emit_sfx("wood_shift")
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or _cd > 0.0:
		return false
	if not is_low:
		_set_low()
		return true
	if not frost_locked:
		snap_t = snap_secs
		_cd = 0.25
		_spin_t = 0.25
		_emit_sfx("harbor_creak")
		queue_redraw()
		return true
	return false


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or _cd > 0.0:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL]:
		return interact(null)
	return false


func get_interact_prompt() -> String:
	if not active or (is_low and frost_locked):
		return ""
	return "ISL3_PROMPT_WARP_WHEEL"


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-7.0, -4.0), Vector2(14.0, 10.0)) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if frost_locked:
		return Vector4(pos.x, pos.y - 4.0, 44.0, 0.72)
	if is_low:
		return Vector4(pos.x, pos.y - 4.0, 38.0, 0.65)
	return Vector4(pos.x, pos.y - 4.0, 26.0, 0.40)


func save_state() -> Dictionary:
	return {"active": active, "is_low": is_low, "frost_locked": frost_locked}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	is_low = bool(d.get("is_low", is_low))
	frost_locked = bool(d.get("frost_locked", frost_locked))
	if is_low and frost_locked:
		LxToyDraw.world_set_var(var_scope, var_name, "low")
		powered = true
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 9.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -1.0, 16.0, 7.0), c_plum, c_wine, c_apricot, c_void)
	var center := Vector2(0.0, -6.0)
	var red: bool = LxHudFx.flash_reduced()
	var rim_c: Color = c_ice if frost_locked else (c_gold if is_low else c_apricot)
	var spoke_c: Color = c_sky if frost_locked else (c_cream if is_low else c_gold)
	var rot: float = (PI * 0.5 if is_low else 0.0) + (0.0 if red else _spin_t * 4.0)
	draw_circle(center, 8.0, c_void)
	draw_arc(center, 6.0, 0.0, TAU, 16, rim_c, 2.0)
	for k: int in range(6):
		var a: float = rot + float(k) * (TAU / 6.0)
		var tip: Vector2 = (center + Vector2(cos(a) * 7.0, sin(a) * 7.0)).round()
		draw_line(center, tip, spoke_c, 1.0)
	draw_rect(Rect2(center - Vector2.ONE, Vector2(2.0, 2.0)), c_cream)
	if frost_locked:
		# 4 cardinal ice lock studs + crystal diamond crest (greyscale-distinct frost lock)
		for off: Vector2 in [Vector2(0.0, -7.0), Vector2(0.0, 7.0), Vector2(-7.0, 0.0), Vector2(7.0, 0.0)]:
			draw_rect(Rect2(center + off - Vector2.ONE, Vector2(2.0, 2.0)), c_void)
			draw_rect(Rect2(center + off - Vector2.ONE, Vector2(1.0, 1.0)), c_cream)
		LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -16.0), 1, true, c_sky, c_ice)
	elif is_low:
		# Downward micro-chevron above wheel indicating lowered warp
		draw_rect(Rect2(-2.0, -17.0, 5.0, 1.0), c_gold)
		draw_rect(Rect2(-1.0, -16.0, 3.0, 1.0), c_cream)
		draw_rect(Rect2(0.0, -15.0, 1.0, 1.0), c_cream)
		if snap_t > 0.0:
			LxToyDraw.draw_bar(self, Vector2(-7.0, 7.0), 14.0, clampf(snap_t / snap_secs, 0.0, 1.0), c_gold, PAL["coral"] as Color)
	else:
		# Upward micro-chevron above wheel indicating high tension
		draw_rect(Rect2(0.0, -17.0, 1.0, 1.0), c_cream)
		draw_rect(Rect2(-1.0, -16.0, 3.0, 1.0), c_apricot)
		draw_rect(Rect2(-2.0, -15.0, 5.0, 1.0), c_apricot)
	_draw_signal_pulses()
