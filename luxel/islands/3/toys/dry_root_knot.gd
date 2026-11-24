class_name LxDryRootKnot
extends LxToy
## Tiny-world dry root-knot barrier burned by focused `"dew_ray"` (or Beam / Sunflare).
## Plain yellow bolts and prism bolts rustle it harmlessly — proves `"dew_ray"` burns tiny knots
## while big-world `cracked_wall` ignores `"dew_ray"`.
## Props: size ([16,16]), burned (bool), persist (bool, true), sets_flag (String), target_id/target_ids.

var burned: bool = false
var sets_flag: String = ""
var _burn_t: float = 0.0
var _rustle_t: float = 0.0


func _toy_setup() -> void:
	kind = "dry_root_knot"
	if not props.has("size"):
		size = Vector2(16.0, 16.0)
	if not props.has("persist"):
		persist = true
	radius = maxf(size.x, size.y) * 0.55
	burned = bool(props.get("burned", false))
	sets_flag = str(props.get("sets_flag", "")).strip_edges()
	active = not burned
	powered = burned
	z_index = -4 if burned else 0
	_burn_t = 0.0
	_rustle_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and burned:
		return
	burned = bool(props.get("burned", false))
	active = not burned
	powered = burned
	z_index = -4 if burned else 0
	_burn_t = 0.0
	_rustle_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _burn_t > 0.0:
		_burn_t = maxf(0.0, _burn_t - dt)
		dirty = true
	if _rustle_t > 0.0:
		_rustle_t = maxf(0.0, _rustle_t - dt)
		dirty = true
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or burned:
		return false
	if hit.source in [LxDewLens.SOURCE_DEW_RAY, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]:
		_burn_away()
		return true
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL]:
		_rustle_t = 0.28
		_emit_sfx("prop_rustle")
		queue_redraw()
		return false
	return false


func on_silk_spark() -> void:
	if active and not burned:
		_burn_away()


func _burn_away() -> void:
	burned = true
	active = false
	z_index = -4
	_burn_t = 0.40
	_rustle_t = 0.0
	set_powered(true)
	if not sets_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag] = true
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.12)
	_emit_gust(maxf(size.x, size.y) + 28.0, 60.0)
	_emit_sfx("bramble_burn")
	emit_power(true)
	if region != null and region.has_method("apply_layers"):
		region.call("apply_layers")
	if region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	_emit_save("dry_knot_" + id)
	queue_redraw()


func is_solid() -> bool:
	return active and not burned


func blocks_sight() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if _burn_t > 0.0:
		var u: float = clampf(_burn_t / 0.40, 0.0, 1.0)
		return Vector4(pos.x, pos.y, 54.0 * u, (0.85 if LxHudFx.flash_reduced() else 1.25) * u)
	return Vector4.ZERO


func save_state() -> Dictionary:
	return {"active": active, "burned": burned}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	burned = bool(d.get("burned", burned))
	active = not burned
	powered = burned
	z_index = -4 if burned else 0
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)

	if burned:
		# Charred dry twig ring on floor
		draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0), Color(c_night, 0.45))
		draw_rect(Rect2(-4.0, -2.0, 3.0, 1.0), c_plum)
		draw_rect(Rect2(2.0, 1.0, 3.0, 1.0), c_wine)
		if _burn_t > 0.0:
			var u: float = 1.0 - clampf(_burn_t / 0.40, 0.0, 1.0)
			for i: int in range(6):
				var a: float = TAU * float(i) / 6.0 + 0.3
				var p := Vector2(roundf(cos(a) * lerpf(3.0, 12.0, u)), roundf(sin(a) * lerpf(3.0, 10.0, u) - u * 6.0))
				draw_rect(Rect2(p, Vector2(2.0 if u < 0.4 else 1.0, 2.0 if u < 0.4 else 1.0)), c_cream if u < 0.3 else c_gold)
		_draw_signal_pulses()
		return

	var jx: float = (1.0 if int(floorf(_rustle_t * 36.0)) % 2 == 0 else -1.0) if (_rustle_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, floorf(h * 0.5)), w * 0.46, 2.5)
	# Tangled amber-brown dry root-knot (clearly distinct from stone cracked_wall in greyscale & colour)
	LxToyDraw.draw_bevel_box(self, Rect2(x0 + jx, y0, w, h), c_wine, c_plum, c_apricot, c_void)
	# Diagonal twisted dry root bands + glowing sun-tinder core glyph (signals magnifying fire weakness)
	draw_line(Vector2(x0 + 2.0 + jx, y0 + 2.0), Vector2(x0 + w - 3.0 + jx, y0 + h - 3.0), c_apricot, 2.0)
	draw_line(Vector2(x0 + w - 3.0 + jx, y0 + 2.0), Vector2(x0 + 2.0 + jx, y0 + h - 3.0), c_coral, 2.0)
	draw_rect(Rect2(-2.0 + jx, -2.0, 4.0, 4.0), c_void)
	draw_rect(Rect2(-1.0 + jx, -1.0, 2.0, 2.0), c_gold)
	if _rustle_t > 0.0:
		draw_rect(Rect2(-5.0, -5.0, 1.0, 1.0), c_cream)
		draw_rect(Rect2(4.0, -4.0, 1.0, 1.0), c_apricot)
	_draw_signal_pulses()
