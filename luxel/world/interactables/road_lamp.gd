class_name LxRoadLamp
extends LxInteractable
## Road lantern post that ignites when struck or when Wick's lantern passes near it.

var lit: bool = false
var _ignite_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "road_lamp"
	lit = bool(props.get("lit", false))
	_uses_prop_anim = lit
	_ignite_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	_uses_prop_anim = lit
	super.tick(dt)
	if _ignite_t > 0.0:
		_ignite_t = maxf(0.0, _ignite_t - dt)
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or lit:
		return false
	return _ignite()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or lit:
		return false
	if hit.source in ["bolt", "prism_bolt", "throw", "recall", "zip", "beam", "sunflare"]:
		return _ignite()
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or lit or light_radius < 20.0:
		return
	if source in ["wick_lantern", "thrown_lantern", "lantern", "sunflare", "beam", "lens"] or source.begins_with("lantern"):
		if source == "lantern_hand" or source == "lens":
			if Lx.player != null and is_instance_valid(Lx.player) and Lx.player is Node2D:
				if (Lx.player as Node2D).global_position.distance_to(pos) > 48.0:
					return
		_ignite()


func _ignite() -> bool:
	lit = true
	_ignite_t = 0.30
	_uses_prop_anim = true
	_emit_sfx("lamp_lit")
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if not lit:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 10.0, 54.0, 0.95)


func save_state() -> Dictionary:
	return {"active": active, "lit": lit}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	lit = bool(d.get("lit", lit))
	_uses_prop_anim = lit
	queue_redraw()


func _draw() -> void:
	var shadow: Color = PAL["void"] as Color
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), shadow)
	draw_rect(Rect2(-4.0, 0.0, 8.0, 4.0), shadow)
	var frame_ov: int = -1 if lit else 0
	if not _draw_prop_sprite("road_lamp" if lit else "road_lamp_unlit", Vector2.ZERO, frame_ov):
		_draw_fallback()
	if lit:
		_draw_lantern_embers()


func _draw_fallback() -> void:
	draw_rect(Rect2(-2.0, -14.0, 4.0, 16.0), PAL["night"] as Color)
	draw_rect(Rect2(-1.0, -13.0, 2.0, 14.0), PAL["plum"] as Color)
	draw_rect(Rect2(-4.0, -17.0, 8.0, 5.0), PAL["dusk"] as Color)
	if lit:
		draw_rect(Rect2(-3.0, -16.0, 6.0, 3.0), PAL["gold"] as Color)
		draw_rect(Rect2(-1.0, -15.0, 2.0, 2.0), PAL["cream"] as Color)
	else:
		draw_rect(Rect2(-3.0, -16.0, 6.0, 3.0), PAL["pine"] as Color)


func _draw_lantern_embers() -> void:
	var c_cream: Color = PAL["cream"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var phase: float = absf(pos.x * 0.029 + pos.y * 0.017)
	var gx: float = 4.0 if island_id >= 5 else 0.0
	for i: int in range(2):
		var t: float = fmod(_clock * 0.42 + phase + float(i) * 0.5, 1.0)
		var px: float = roundf(gx + sin(_clock * 1.6 + phase + float(i) * 3.1) * (2.5 + t * 2.5))
		var py: float = roundf(-12.0 - t * 11.0)
		draw_rect(Rect2(px, py, 1.0, 1.0), c_cream if t < 0.4 else c_gold)
	if _ignite_t > 0.0:
		var u: float = 1.0 - clampf(_ignite_t / 0.30, 0.0, 1.0)
		draw_arc(Vector2(gx, -14.0), roundf(lerpf(3.0, 14.0, u)), 0.0, TAU, 14, c_cream if u < 0.4 else c_gold, 1.0, false)
