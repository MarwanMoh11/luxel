class_name LxSkiffTether
extends LxToy
## Harbor Quay mooring cleat & painter rope for Island 2's Skiff.
## Shoot with a bolt, throw the lantern, or interact to snap the rope,
## setting story_flags["skiff_unlocked"] = true and teaching recoil sailing.

var cut: bool = false
var rope_to: Vector2 = Vector2.ZERO
var _snap_t: float = 0.0


func _toy_setup() -> void:
	kind = "skiff_tether"
	radius = 16.0
	rope_to = _parse_vec2(props.get("rope_to", [pos.x + 24.0, pos.y + 16.0]), pos + Vector2(24.0, 16.0))
	cut = powered or (Lx.state != null and bool(Lx.state.story_flags.get("skiff_unlocked", false)))
	if cut:
		powered = true
	_snap_t = 0.0
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	return _cut_rope()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or cut:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]:
		return _cut_rope()
	return false


func on_lantern_pull(_pull_dir: Vector2, _source: String = "recall") -> void:
	_cut_rope()


func _cut_rope() -> bool:
	if not active or cut:
		return false
	cut = true
	_snap_t = 0.45
	set_powered(true)
	emit_power(true)
	if Lx.state != null:
		Lx.state.story_flags["skiff_unlocked"] = true
	_emit_sfx("harbor_creak")
	_emit_sfx("switch_on")
	_emit_gust(48.0, 32.0)
	if Lx.events != null:
		if LxStrings.has_id("ISL2_SKIFF_CUT"):
			Lx.events.narration_requested.emit("ISL2_SKIFF_CUT", "title", 3.4)
		Lx.events.save_requested.emit("skiff_unlocked")
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "" if (not active or cut) else "PROMPT_UNTETHER"


func tick(dt: float) -> void:
	super.tick(dt)
	if not cut and Lx.state != null and bool(Lx.state.story_flags.get("skiff_unlocked", false)):
		cut = true
		powered = true
		queue_redraw()
	if _snap_t > 0.0:
		_snap_t = maxf(0.0, _snap_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active or cut:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 2.0, 28.0, 0.48)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["cut"] = cut
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if d.has("cut"):
		cut = bool(d.get("cut", false))
	if Lx.state != null and bool(Lx.state.story_flags.get("skiff_unlocked", false)):
		cut = true
	powered = cut
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_wine: Color = PAL["wine"] as Color

	# Timber mooring cleat base
	draw_rect(Rect2(-6.0, -3.0, 12.0, 7.0), c_void)
	draw_rect(Rect2(-5.0, -2.0, 10.0, 5.0), c_dusk)
	draw_rect(Rect2(-4.0, -2.0, 8.0, 2.0), PAL["stone"] as Color)
	draw_rect(Rect2(-2.0, -5.0, 4.0, 4.0), c_void)
	draw_rect(Rect2(-1.0, -4.0, 2.0, 3.0), c_gold if not cut else PAL["mauve"] as Color)

	if not cut:
		var rel: Vector2 = (rope_to - pos).round()
		var mid: Vector2 = rel * 0.5 + Vector2(0.0, 3.0 + (0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.0))))
		draw_line(Vector2.ZERO, mid, c_void, 3.0)
		draw_line(mid, rel, c_void, 3.0)
		draw_line(Vector2.ZERO, mid, c_apricot, 1.5)
		draw_line(mid, rel, c_apricot, 1.5)
		# Glowing cut target pip on the rope
		var hot: bool = LxHudFx.flash_reduced() or int(floorf(_clock * 4.0)) % 2 == 0
		draw_rect(Rect2(mid.x - 2.0, mid.y - 2.0, 4.0, 4.0), c_void)
		draw_rect(Rect2(mid.x - 1.0, mid.y - 1.0, 2.0, 2.0), c_cream if hot else c_gold)
	elif _snap_t > 0.0:
		var u: float = 1.0 - clampf(_snap_t / 0.45, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(4.0, 18.0, u)), 0.0, TAU, 14, c_cream, 1.2)
		draw_line(Vector2.ZERO, Vector2(6.0, 4.0) * (1.0 - u), c_wine, 1.0)
	_draw_signal_pulses()
