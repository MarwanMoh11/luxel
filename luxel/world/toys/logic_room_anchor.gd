class_name LxRoomAnchor
extends LxToy
## Local room respawn checkpoint anchor: stepping near or interacting sets Wick's safe respawn point.
## Props: auto (bool, default true), activate_radius (float, default 24.0), persist (bool), target_id/target_ids.

var auto_activate: bool = true
var activate_radius: float = 24.0
var is_current_anchor: bool = false
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "room_anchor"
	z_index = -5
	auto_activate = bool(props.get("auto", true))
	activate_radius = maxf(12.0, float(props.get("activate_radius", 24.0)))
	radius = maxf(12.0, radius)
	is_current_anchor = powered
	_pulse_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and is_current_anchor:
		return
	is_current_anchor = false
	_pulse_t = 0.0
	if powered:
		set_powered(false)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()
	if not active or not auto_activate or is_current_anchor:
		return
	var wp: Vector2 = wick_pos()
	if wp.distance_to(pos) <= activate_radius:
		if Lx.player == null or not is_instance_valid(Lx.player) or not bool(Lx.player.get("dead")):
			claim_anchor()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	claim_anchor()
	return true


func get_interact_prompt() -> String:
	return "" if (not active or is_current_anchor) else "PROMPT_ANCHOR_SET"


func claim_anchor() -> void:
	var was_cur: bool = is_current_anchor
	# Deactivate sibling room anchors so only one shows as current
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if it_v is LxRoomAnchor and it_v != self:
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
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var c_hi: Color = PAL["cream"] as Color if is_current_anchor else PAL["stone"] as Color
	var c_rim: Color = c_glow if is_current_anchor else PAL["mauve"] as Color

	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -8.0, 16.0, 16.0), PAL["night"] as Color, PAL["dusk"] as Color, c_rim, c_void)
	# Cardinal compass ticks
	for off: Vector2 in [Vector2(0.0, -6.0), Vector2(0.0, 5.0), Vector2(-6.0, 0.0), Vector2(5.0, 0.0)]:
		draw_rect(Rect2(off, Vector2.ONE), c_hi)
	# Center anchor star
	LxToyDraw.draw_shape_glyph(self, Vector2.ZERO, 5, is_current_anchor, c_glow if is_current_anchor else PAL["mauve"] as Color, c_hi)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.45, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 18.0, u)), 0.0, TAU, 16, c_hi if u < 0.4 else c_glow, 1.0)
	_draw_signal_pulses()
