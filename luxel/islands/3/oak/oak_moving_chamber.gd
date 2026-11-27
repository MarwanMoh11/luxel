class_name LxOakMovingChamber
extends LxToy
## Hollow Oak Moving Chamber controller (`oak_r7b`, Bible §3.4 — Astonishing Room).
## Whichever quadrant of the octagonal chamber is left DARK for `dark_secs` (1.5 s) while
## Wick hangs their lantern on a cardinal hook causes the unlit walls to GROAN and rotate
## 90 degrees clockwise (`room:3:oak_r7b.ring_rot` = 0..3), spinning Key #3's vault and the
## inner Blue Transformer around to Wick's landing!
## Anti-exploit #10: only rotates when Wick is outside the rotating wall band; center compass
## dial displays live `ring_rot` AND can also be tapped (interact) as an accessibility backup.
## Props: dark_secs (float, 1.5), hook_ids (Array[String]), var_name ("ring_rot"), scope ("room:3:oak_r7b").

var dark_secs: float = 1.5
var hook_ids: Array[String] = []
var var_name: String = "ring_rot"
var var_scope: String = "room:3:oak_r7b"

var _dark_timer: float = 0.0
var _rot_cd: float = 0.0
var _flash_t: float = 0.0
var _last_hook_id: String = ""


func _toy_setup() -> void:
	kind = "oak_moving_chamber"
	dark_secs = maxf(0.4, float(props.get("dark_secs", 1.5)))
	var_name = str(props.get("var_name", "ring_rot")).strip_edges()
	var_scope = str(props.get("scope", "room:%d:%s" % [island_id, region_id])).strip_edges()
	hook_ids.clear()
	var raw_h: Variant = props.get("hook_ids", [])
	if raw_h is Array:
		for hv: Variant in (raw_h as Array):
			var hs: String = str(hv).strip_edges()
			if not hs.is_empty():
				hook_ids.append(hs)
	radius = 18.0
	z_index = -5
	_dark_timer = 0.0
	_rot_cd = 0.0
	_flash_t = 0.0
	_last_hook_id = ""
	if Lx.vars != null:
		if str(Lx.vars.get_var(var_scope, var_name, "")).is_empty() or not LxRegionLoader.check_flag_static("oak_r7b_solved"):
			Lx.vars.set_var(var_scope, var_name, 0)
	queue_redraw()


func reset_toy() -> void:
	_dark_timer = 0.0
	_rot_cd = 0.0
	_flash_t = 0.0
	_last_hook_id = ""
	queue_redraw()


func get_rot() -> int:
	if Lx.vars == null:
		return 0
	return posmod(int(Lx.vars.get_var(var_scope, var_name, 0)), 4)


func rotate_chamber() -> bool:
	if not active or _rot_cd > 0.0:
		return false
	var nxt: int = (get_rot() + 1) % 4
	_rot_cd = 1.25
	_dark_timer = 0.0
	_flash_t = 0.55
	LxToyDraw.world_set_var(var_scope, var_name, nxt)
	if region != null and is_instance_valid(region) and region.has_method("apply_layers"):
		region.call("apply_layers")
	_emit_sfx("wood_shift")
	if Lx.events != null and LxHudFx.shake_enabled():
		Lx.events.shake_requested.emit(0.14 * (0.45 if LxHudFx.flash_reduced() else 1.0))
	emit_power(true)
	queue_redraw()
	return true


func interact(_actor: Node = null) -> bool:
	return rotate_chamber()


func _find_lit_hook() -> String:
	if region == null or not region.has_method("find_interactable"):
		return ""
	for hid: String in hook_ids:
		var it: Variant = region.call("find_interactable", hid)
		if it is LxInteractable and (it as LxInteractable).active and bool((it as LxInteractable).get("powered")):
			return hid
	return ""


func _is_wick_safe_for_rotation() -> bool:
	# Anti-exploit #10: never rotate while Wick stands inside the central pit/vault band
	var wp: Vector2 = wick_pos()
	if wp == Vector2.ZERO:
		return true
	var band := Rect2(pos - Vector2(68.0, 44.0), Vector2(136.0, 88.0))
	return not band.has_point(wp)


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _rot_cd > 0.0:
		_rot_cd = maxf(0.0, _rot_cd - dt)
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		dirty = true

	var hung_id: String = _find_lit_hook()
	if not hung_id.is_empty():
		if hung_id != _last_hook_id:
			_last_hook_id = hung_id
			_dark_timer = 0.0
		if _rot_cd <= 0.0 and _is_wick_safe_for_rotation():
			_dark_timer += dt
			dirty = true
			if _dark_timer >= dark_secs:
				rotate_chamber()
				# Wait for recall/re-hang before rotating again from the same hook
				_rot_cd = 1.6
	else:
		if _dark_timer > 0.0 or not _last_hook_id.is_empty():
			_dark_timer = 0.0
			_last_hook_id = ""
			dirty = true
	if dirty:
		queue_redraw()


func get_interact_prompt() -> String:
	return "ISL3_PROMPT_TURN_RING" if active else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if _flash_t > 0.0:
		return Vector4(pos.x, pos.y, 64.0, 0.52 if LxHudFx.flash_reduced() else 0.72)
	return Vector4(pos.x, pos.y, 28.0, 0.34)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var rot: int = get_rot()
	var red: bool = LxHudFx.flash_reduced()
	var flash_on: bool = _flash_t > 0.0 and not red

	# Heartwood Growth-Ring floor compass dial
	draw_circle(Vector2.ZERO, 17.0, c_void)
	draw_circle(Vector2.ZERO, 15.0, c_night)
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, c_apricot if flash_on else c_dusk, 2.0 if flash_on else 1.0)
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 16, c_jade, 1.0)
	# 4 cardinal pips: crowned arrow+orb for Key Vault (N=0,E=1,S=2,W=3), diamond for Prism, flat slots for dark
	var dirs: Array[Vector2] = [Vector2(0.0, -11.0), Vector2(11.0, 0.0), Vector2(0.0, 11.0), Vector2(-11.0, 0.0)]
	for i: int in range(4):
		var dp: Vector2 = dirs[i]
		var is_vault: bool = i == rot
		var is_prism: bool = i == ((rot + 1) % 4)
		if is_vault:
			draw_line(Vector2.ZERO, dp, c_gold, 2.0)
			draw_circle(dp, 3.0, c_gold)
			draw_rect(Rect2(dp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_cream)
		elif is_prism:
			LxToyDraw.draw_shape_glyph(self, dp, 1, true, c_sky, PAL["ice"] as Color)
		else:
			draw_rect(Rect2(dp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_pine)
	if _dark_timer > 0.0:
		var prog: float = clampf(_dark_timer / dark_secs, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 15.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 20, c_cream if flash_on else c_gold, 2.0)
	_draw_signal_pulses()
