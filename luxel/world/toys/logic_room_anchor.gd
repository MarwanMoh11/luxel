class_name LxRoomAnchor
extends LxToy
## Local room respawn checkpoint anchor: stepping near or interacting sets Wick's safe respawn point.
## Props: auto (bool, default true), activate_radius (float, default 24.0), persist (bool), target_id/target_ids.

var auto_activate: bool = true
var activate_radius: float = 24.0
var is_current_anchor: bool = false
var _pulse_t: float = 0.0
var _hover: bool = false


func _toy_setup() -> void:
	kind = "room_anchor"
	z_index = -5
	auto_activate = bool(props.get("auto", true))
	activate_radius = maxf(12.0, float(props.get("activate_radius", 24.0)))
	radius = maxf(12.0, radius)
	is_current_anchor = powered
	_pulse_t = 0.0
	_hover = false
	queue_redraw()


func reset_toy() -> void:
	if persist and is_current_anchor:
		return
	is_current_anchor = false
	_pulse_t = 0.0
	_hover = false
	if powered:
		set_powered(false)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		dirty = true
	var wp: Vector2 = wick_pos()
	var want_hover: bool = active and not is_current_anchor and wp.x > -9000.0 and wp.distance_to(pos) <= activate_radius + 14.0
	if want_hover != _hover:
		_hover = want_hover
		dirty = true
	if dirty:
		queue_redraw()
	if not active or not auto_activate or is_current_anchor:
		return
	if wp.distance_to(pos) <= activate_radius:
		if Lx.player == null or not is_instance_valid(Lx.player) or Lx.player.get("dead") != true:
			claim_anchor()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	claim_anchor()
	return true


func get_interact_prompt() -> String:
	return "" if (not active or is_current_anchor) else "PROMPT_ANCHOR_SET"


func claim_anchor() -> void:
	if is_instance_valid(region):
		if region.has_method("is_lethal_void_at") and bool(region.call("is_lethal_void_at", pos)):
			return
		if region.has_method("tile_at") and LxMapFormat.is_solid_tile(str(region.call("tile_at", pos)), true, true):
			return
	var was_cur: bool = is_current_anchor
	# Deactivate sibling room anchors so only one shows as current
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if is_instance_valid(it_v) and it_v is LxRoomAnchor and it_v != self:
				var sib: LxRoomAnchor = it_v as LxRoomAnchor
				sib.is_current_anchor = false
				sib.powered = false
				sib.queue_redraw()
	is_current_anchor = true
	_pulse_t = 0.45
	set_powered(true)
	if region != null and is_instance_valid(region):
		if region.get("spawn_pos") is Vector2:
			region.set("spawn_pos", pos)
	if Lx.player != null and is_instance_valid(Lx.player):
		if Lx.player.get("_last_safe_pos") is Vector2:
			Lx.player.set("_last_safe_pos", pos)
	if not was_cur:
		_emit_sfx("waystone_lit")
		_notify_linked_targets(true)
		_emit_gust(42.0, 24.0)
	queue_redraw()


func get_light_pool() -> Vector4:
	if not active or not is_current_anchor:
		return Vector4.ZERO
	var surge: float = 16.0 if _pulse_t > 0.0 else 0.0
	return Vector4(pos.x, pos.y, 42.0 + surge, 0.72)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["is_current_anchor"] = is_current_anchor
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("is_current_anchor", false)):
		is_current_anchor = true
		powered = true
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var reduced: bool = LxHudFx.flash_reduced()

	# Grounded shadow disc
	draw_circle(Vector2(1.0, 1.0), 11.0, Color(c_void, 0.36))

	# Radiant golden claimed beacon ring (or gentle hover glow ring)
	if is_current_anchor:
		var halo_c: Color = c_cream if (reduced or int(floorf(_clock * 3.0)) % 2 == 0) else c_gold
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, Color(c_gold, 0.72), 2.0)
		draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 20, halo_c, 1.0)
	elif _hover:
		draw_arc(Vector2.ZERO, 11.5, 0.0, TAU, 20, Color(c_gold, 0.55), 1.0)

	# Carved stone medallion base disc
	draw_circle(Vector2.ZERO, 10.0, c_void)
	draw_circle(Vector2.ZERO, 9.0, c_dusk)
	draw_arc(Vector2.ZERO, 8.5, PI * 0.85, PI * 1.9, 14, c_stone, 1.0)
	draw_circle(Vector2.ZERO, 6.0, c_night)

	# Engraved brass compass ring
	var brass_c: Color = c_gold if is_current_anchor else (c_gold if _hover else c_apricot)
	draw_arc(Vector2.ZERO, 6.5, 0.0, TAU, 20, brass_c, 2.0)

	# Four cardinal stone compass points (N / S / E / W)
	var pt_hi: Color = c_cream if is_current_anchor else (c_gold if _hover else c_stone)
	var pt_mid: Color = c_gold if is_current_anchor else (c_apricot if _hover else c_mauve)
	# North & South points
	draw_rect(Rect2(-2.0, -11.0, 5.0, 4.0), c_void)
	draw_rect(Rect2(-1.0, -10.0, 3.0, 3.0), pt_mid)
	draw_rect(Rect2(0.0, -11.0, 1.0, 4.0), pt_hi)
	draw_rect(Rect2(-2.0, 8.0, 5.0, 4.0), c_void)
	draw_rect(Rect2(-1.0, 8.0, 3.0, 3.0), pt_mid)
	draw_rect(Rect2(0.0, 8.0, 1.0, 4.0), pt_hi)
	# West & East points
	draw_rect(Rect2(-11.0, -2.0, 4.0, 5.0), c_void)
	draw_rect(Rect2(-10.0, -1.0, 3.0, 3.0), pt_mid)
	draw_rect(Rect2(-11.0, 0.0, 4.0, 1.0), pt_hi)
	draw_rect(Rect2(8.0, -2.0, 4.0, 5.0), c_void)
	draw_rect(Rect2(8.0, -1.0, 3.0, 3.0), pt_mid)
	draw_rect(Rect2(8.0, 0.0, 4.0, 1.0), pt_hi)

	# Intercardinal brass ticks
	for d: Vector2 in [Vector2(-5.0, -5.0), Vector2(5.0, -5.0), Vector2(-5.0, 5.0), Vector2(5.0, 5.0)]:
		draw_rect(Rect2(d, Vector2.ONE), brass_c)

	# Center compass-rose star
	LxToyDraw.draw_shape_glyph(self, Vector2.ZERO, 5, is_current_anchor or _hover, c_gold if is_current_anchor else c_apricot, pt_hi)

	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.45, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(7.0, 20.0, u)), 0.0, TAU, 18, c_cream if u < 0.4 else c_gold, 1.0)
	_draw_signal_pulses()
