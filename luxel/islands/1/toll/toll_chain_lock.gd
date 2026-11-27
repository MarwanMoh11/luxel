class_name LxTollChainLock
extends LxToy
## Island 1 Set Piece (`toll_r3`): Coral Chain-Lock pinning the Great Bell on the escapement gear.
## Shatters permanently when struck by any WAR Ring Wave (from War Bell or a `toll_moth` burst!).
## Persists broken state across pit respawn & room re-entry.
## Props: target_id/target_ids, size ([24, 24]), persist (bool, default true).

var broken: bool = false
var _break_t: float = 0.0


func _toy_setup() -> void:
	kind = "toll_chain_lock"
	if not props.has("size"):
		size = Vector2(24.0, 24.0)
	radius = maxf(size.x, size.y) * 0.5 + 4.0
	persist = bool(props.get("persist", true))
	broken = bool(props.get("broken", false))
	powered = broken
	_break_t = 0.0
	if broken:
		_notify_linked_targets(true)
	queue_redraw()


func reset_toy() -> void:
	if persist and broken:
		return
	broken = false
	_break_t = 0.0
	set_powered(false)
	_notify_linked_targets(false)
	queue_redraw()


func on_ring(in_tone: String, _dir: Vector2) -> void:
	if not active or broken:
		return
	if in_tone.strip_edges().to_lower() == "war":
		_shatter()


func on_hit(hit: LxHit) -> bool:
	if not active or broken or hit == null:
		return false
	if hit.source in ["beam", "sunflare"] or hit.cracks_armour:
		_shatter()
		return true
	_emit_sfx("shield_clang")
	return true


func _shatter() -> void:
	broken = true
	_break_t = 0.45
	set_powered(true)
	emit_power(true)
	_emit_sfx("chain_snap")
	_emit_gust(54.0, 46.0)
	_emit_shake(0.18)
	if region != null and region.has_method("save_interactables_to_state"):
		region.call("save_interactables_to_state")
	queue_redraw()


func _emit_shake(amp: float) -> void:
	if Lx.events != null:
		Lx.events.shake_requested.emit(amp * (0.45 if LxHudFx.flash_reduced() else 1.0))


func tick(dt: float) -> void:
	super.tick(dt)
	if _break_t > 0.0:
		_break_t = maxf(0.0, _break_t - dt)
		queue_redraw()


func is_solid() -> bool:
	return active and not broken


func is_solid_blocker() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active or broken:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 34.0, 0.58)


func save_state() -> Dictionary:
	return {"active": active, "broken": broken}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	broken = bool(d.get("broken", broken))
	powered = broken
	if broken:
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var r := Rect2(x0, y0, w, h)

	if broken:
		# Snapped chain links resting on floor with clear center gap
		var lx: float = roundf(-w * 0.35)
		var rx: float = roundf(w * 0.15)
		draw_rect(Rect2(lx - 1.0, -3.0, 7.0, 6.0), c_void)
		draw_rect(Rect2(rx - 1.0, -3.0, 7.0, 6.0), c_void)
		draw_rect(Rect2(lx, -2.0, 5.0, 4.0), c_dusk)
		draw_rect(Rect2(rx, -2.0, 5.0, 4.0), c_dusk)
		draw_rect(Rect2(lx + 1.0, -1.0, 3.0, 2.0), c_apricot)
		draw_rect(Rect2(rx + 1.0, -1.0, 3.0, 2.0), c_apricot)
		if _break_t > 0.0:
			var u: float = 1.0 - clampf(_break_t / 0.45, 0.0, 1.0)
			var r_col := Color(c_coral, (1.0 - u) * (0.55 if red else 0.90))
			draw_arc(Vector2.ZERO, roundf(6.0 + u * (16.0 if red else 22.0)), 0.0, TAU, 16, r_col, 1.0 if red else 2.0)
		return

	_draw_ground_shadow(roundf(w * 0.48), 4.0, Vector2(0.0, roundf(h * 0.45)))
	LxToyDraw.draw_bevel_box(self, r, c_night, c_dusk, c_coral, c_void)
	# Heavy iron chain band with recessed link notches & War coral seal crest
	draw_rect(Rect2(x0 + 2.0, -3.0, w - 4.0, 6.0), c_void)
	draw_rect(Rect2(x0 + 3.0, -2.0, w - 6.0, 4.0), c_apricot)
	draw_rect(Rect2(x0 + 6.0, -2.0, 1.0, 4.0), c_void)
	draw_rect(Rect2(x0 + w - 7.0, -2.0, 1.0, 4.0), c_void)
	draw_circle(Vector2.ZERO, 5.0, c_night)
	draw_circle(Vector2.ZERO, 3.0, c_coral)
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), c_gold)
	LxToyDraw.draw_tone_crest(self, Vector2(0.0, y0 - 6.0), "war", false)
	_draw_signal_pulses()
