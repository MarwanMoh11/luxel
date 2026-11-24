class_name LxStumpShrink
extends LxToy
## Island 3 hollow stump portal switching `Lx.vars` `island:3` `size` (`normal` <-> `tiny`).
## Props: to_region (String; empty or same region toggles/shifts size in place), to_spawn ([x,y]),
## target_size ("tiny"|"normal"|"toggle", default "tiny"), powered_by_sap (bool, default false),
## requires_flag (String), persist (bool), target_id/target_ids.
## States: dormant (dry bark when sap is low or flag missing) <-> open (swirling jade/lime or gold vortex).

const TRANSITION_SECS: float = 0.40

var to_region: String = ""
var to_spawn: Vector2 = Vector2(-1.0, -1.0)
var target_size: String = "tiny"
var powered_by_sap: bool = false
var requires_flag: String = ""

var open: bool = true
var _trans_t: float = 0.0
var _trans_actor: LxWick = null
var _swirl_phase: float = 0.0


func _toy_setup() -> void:
	kind = "stump_shrink"
	if not props.has("size"):
		size = Vector2(20.0, 20.0)
	radius = maxf(14.0, maxf(size.x, size.y) * 0.55)
	to_region = str(props.get("to_region", "")).strip_edges()
	var raw_sp: Variant = props.get("to_spawn", null)
	if raw_sp is Array and (raw_sp as Array).size() >= 2:
		to_spawn = Vector2(float((raw_sp as Array)[0]), float((raw_sp as Array)[1]))
	else:
		to_spawn = Vector2(-1.0, -1.0)
	target_size = str(props.get("target_size", "tiny")).strip_edges().to_lower()
	if target_size not in ["tiny", "normal", "toggle"]:
		target_size = "tiny"
	powered_by_sap = bool(props.get("powered_by_sap", false))
	requires_flag = str(props.get("requires_flag", "")).strip_edges()
	_trans_t = 0.0
	_trans_actor = null
	_swirl_phase = 0.0
	_refresh_open_state()
	queue_redraw()


func reset_toy() -> void:
	_trans_t = 0.0
	_trans_actor = null
	_refresh_open_state()
	queue_redraw()


func _refresh_open_state() -> bool:
	var ok: bool = true
	if powered_by_sap:
		var sap_v: String = str(LxToyDraw.world_get_var("dungeon:hollow_oak", "oak_sap", "low")).strip_edges().to_lower()
		if sap_v != "high":
			ok = false
	if ok and not requires_flag.is_empty():
		if not LxRegionLoader.check_flag_static(requires_flag):
			ok = false
	var changed: bool = ok != open
	open = ok
	if changed:
		set_powered(open)
		queue_redraw()
	return open


func is_open() -> bool:
	return active and _refresh_open_state()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	_refresh_open_state()
	if open:
		_swirl_phase += dt * (2.2 if LxHudFx.flash_reduced() else 4.8)
		queue_redraw()
	if _trans_t > 0.0:
		_trans_t = maxf(0.0, _trans_t - dt)
		queue_redraw()
		if _trans_t <= 0.0:
			_finish_transition()


func interact(actor: Node = null) -> bool:
	if not active or _trans_t > 0.0:
		return false
	if not _refresh_open_state():
		_emit_sfx("denied")
		queue_redraw()
		return false
	_trans_actor = actor as LxWick if actor is LxWick else (Lx.player as LxWick if Lx.player is LxWick else null)
	_trans_t = TRANSITION_SECS
	_emit_sfx("shrink_swirl")
	_emit_gust(48.0, 38.0)
	if _trans_actor != null and is_instance_valid(_trans_actor):
		var col: Color = (PAL["lime"] if _resolved_size() == "tiny" else PAL["gold"]) as Color
		_trans_actor.spawn_ring(pos, 12.0 if _resolved_size() == "tiny" else 3.0, 3.0 if _resolved_size() == "tiny" else 16.0, 0.34, col, 1.5)
	queue_redraw()
	return true


func _resolved_size() -> String:
	if target_size == "toggle":
		var cur: String = str(LxToyDraw.world_get_var("island:3", "size", "normal")).strip_edges().to_lower()
		return "normal" if cur == "tiny" else "tiny"
	return target_size


func _finish_transition() -> void:
	var next_size: String = _resolved_size()
	LxToyDraw.world_set_var("island:3", "size", next_size)
	var scale_val: float = LxIsland3Rule.TINY_LIGHT_SCALE if next_size == "tiny" else LxIsland3Rule.NORMAL_LIGHT_SCALE
	var w: LxWick = _trans_actor if (_trans_actor != null and is_instance_valid(_trans_actor)) else (Lx.player as LxWick if Lx.player is LxWick else null)
	if w != null and is_instance_valid(w):
		w.set_light_scale(scale_val)
	emit_power(true)
	_trans_actor = null
	# Warp to target region (or reposition in-place when same/empty region)
	if not to_region.is_empty() and to_region != region_id:
		if Lx.root != null and is_instance_valid(Lx.root) and Lx.root.has_method("load_island_region"):
			Lx.root.call("load_island_region", island_id, to_region, to_spawn)
			return
	elif to_spawn.x >= 0.0 and w != null and is_instance_valid(w):
		w.global_position = to_spawn
		w.last_pos = to_spawn
	if region != null and is_instance_valid(region) and region.has_method("apply_layers"):
		region.call("apply_layers")


func get_interact_prompt() -> String:
	if not active or not _refresh_open_state() or _trans_t > 0.0:
		return ""
	return "PROMPT_SHRINK_STUMP" if _resolved_size() == "tiny" else "PROMPT_GROW_STUMP"


func get_light_pool() -> Vector4:
	if not active or not open:
		return Vector4.ZERO
	var boost: float = 18.0 if _trans_t > 0.0 else 0.0
	return Vector4(pos.x, pos.y - 2.0, 34.0 + boost, 0.58 if _trans_t > 0.0 else 0.36)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var shrink_mode: bool = _resolved_size() == "tiny"

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 10.0, 3.5)
	# Sculpted hollow tree stump outer bark ring (roots + knotty rim)
	draw_rect(Rect2(-10.0, -5.0, 20.0, 12.0), c_void)
	draw_rect(Rect2(-9.0, -6.0, 18.0, 12.0), c_void)
	draw_rect(Rect2(-9.0, -4.0, 18.0, 10.0), c_dusk if not open else c_wine)
	draw_rect(Rect2(-8.0, -5.0, 16.0, 9.0), c_plum if not open else c_apricot)
	# Bark root buttresses
	draw_rect(Rect2(-11.0, 3.0, 4.0, 4.0), c_void)
	draw_rect(Rect2(-10.0, 3.0, 3.0, 3.0), c_dusk if not open else c_wine)
	draw_rect(Rect2(7.0, 3.0, 4.0, 4.0), c_void)
	draw_rect(Rect2(7.0, 3.0, 3.0, 3.0), c_dusk if not open else c_wine)
	# Top cut timber rim
	draw_rect(Rect2(-8.0, -6.0, 16.0, 2.0), c_void)
	draw_rect(Rect2(-7.0, -5.0, 14.0, 2.0), PAL["stone"] as Color if not open else c_gold)
	# Inner hollow opening
	draw_rect(Rect2(-6.0, -3.0, 12.0, 7.0), c_void)
	draw_rect(Rect2(-5.0, -2.0, 10.0, 5.0), c_night)

	if not open:
		# Dormant dry bark seal + hollow sap drop glyph (readable in greyscale)
		draw_rect(Rect2(-4.0, -1.0, 8.0, 3.0), c_dusk)
		if powered_by_sap:
			draw_rect(Rect2(-1.0, -2.0, 2.0, 1.0), c_apricot)
			draw_rect(Rect2(-2.0, -1.0, 4.0, 3.0), c_dusk)
			draw_rect(Rect2(-1.0, 0.0, 2.0, 1.0), c_gold)
		return

	# Open swirling portal vortex (jade/lime inward spiral for tiny, gold/cream outward for normal)
	var v_dark: Color = c_pine if shrink_mode else c_wine
	var v_mid: Color = c_jade if shrink_mode else c_apricot
	var v_hi: Color = c_lime if shrink_mode else c_gold
	draw_rect(Rect2(-5.0, -2.0, 10.0, 5.0), v_dark)
	draw_rect(Rect2(-4.0, -1.0, 8.0, 3.0), v_mid)
	for i: int in range(4):
		var a: float = _swirl_phase + float(i) * (PI * 0.5)
		var r: float = 3.5 if (_trans_t <= 0.0) else lerpf(4.5, 1.0, 1.0 - _trans_t / TRANSITION_SECS)
		var sp := Vector2(roundf(cos(a) * r), roundf(sin(a) * r * 0.55))
		draw_rect(Rect2(sp, Vector2(1.0, 1.0)), c_cream if i % 2 == 0 else v_hi)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), c_cream if _trans_t > 0.0 else v_hi)
	# Crisp directional arrow pip above rim (down-inward chevron for tiny, up-outward for normal)
	if shrink_mode:
		draw_rect(Rect2(-2.0, -9.0, 5.0, 1.0), c_lime)
		draw_rect(Rect2(-1.0, -8.0, 3.0, 1.0), c_cream)
		draw_rect(Rect2(0.0, -7.0, 1.0, 1.0), c_cream)
	else:
		draw_rect(Rect2(0.0, -10.0, 1.0, 1.0), c_cream)
		draw_rect(Rect2(-1.0, -9.0, 3.0, 1.0), c_cream)
		draw_rect(Rect2(-2.0, -8.0, 5.0, 1.0), c_gold)
	_draw_signal_pulses()
