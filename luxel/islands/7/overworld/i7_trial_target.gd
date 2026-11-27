class_name LxI7TrialTarget
extends LxToy
## Lunar Phase / Anvil Range optical target for Island 7 timed light_all trials.
## Exposes `lit`, `activated`, and `powered` booleans so LxChallenge._count_lit_targets()
## tracks hits cleanly with zero null-property errors.
## Props: requires_blue (bool), reset_time (float, 0 = latch), target_id/target_ids, persist (bool).

var requires_blue: bool = false
var reset_time: float = 0.0
var lit: bool = false
var activated: bool = false
var _timer: float = 0.0
var _flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "i7_trial_target"
	requires_blue = bool(props.get("requires_blue", false))
	reset_time = maxf(0.0, float(props.get("reset_time", 0.0)))
	if not props.has("persist"):
		persist = false
	radius = 12.0
	lit = powered
	activated = powered
	_timer = reset_time if (lit and reset_time > 0.0) else 0.0
	_flash_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and lit:
		return
	lit = false
	activated = false
	_timer = 0.0
	_flash_t = 0.0
	set_powered(false)
	emit_power(false)
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source not in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_SUNFLARE]:
		return false
	if requires_blue and not hit.is_blue():
		_emit_sfx("denied")
		_flash_t = 0.16
		queue_redraw()
		return true
	lit = true
	activated = true
	_timer = reset_time
	_flash_t = 0.35
	set_powered(true)
	emit_power(true)
	_emit_sfx("switch_on")
	_emit_gust(38.0, 28.0)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		dirty = true
	# Keep `lit`, `activated`, `powered` synchronized if LxChallenge resets `lit = false`
	if not lit and (activated or powered):
		activated = false
		_timer = 0.0
		set_powered(false)
		emit_power(false)
		dirty = true
	elif lit and reset_time > 0.0:
		_timer -= dt
		if _timer <= 0.0:
			lit = false
			activated = false
			_timer = 0.0
			set_powered(false)
			emit_power(false)
			dirty = true
	if dirty:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if lit:
		return Vector4(pos.x, pos.y, 38.0, 0.72)
	return Vector4(pos.x, pos.y, 20.0, 0.24)


func _draw() -> void:
	if not active:
		return
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_core: Color = (PAL["ice"] if requires_blue else PAL["gold"]) as Color
	var c_rim: Color = (PAL["sky"] if requires_blue else PAL["apricot"]) as Color
	var c_cream: Color = PAL["cream"] as Color

	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 5.0), 7.0, 2.5, "se_gold", lit)
	draw_circle(Vector2.ZERO, 9.0, c_void)
	draw_circle(Vector2.ZERO, 7.0, c_rim if lit else c_dusk)
	draw_circle(Vector2.ZERO, 5.0, c_core if lit else c_night)
	if requires_blue:
		# Diamond crest for Blue targets (greyscale-distinct from circular Yellow targets)
		var pts := PackedVector2Array([
			Vector2(0.0, -4.0), Vector2(4.0, 0.0), Vector2(0.0, 4.0), Vector2(-4.0, 0.0),
		])
		draw_colored_polygon(pts, c_cream if lit else c_rim)
	else:
		# Bullseye ring for Yellow targets
		draw_circle(Vector2.ZERO, 2.0, c_cream if lit else c_core)
	if _flash_t > 0.0:
		var u: float = 1.0 - clampf(_flash_t / 0.35, 0.0, 1.0)
		var fa: float = (1.0 - u) * (0.55 if LxHudFx.flash_reduced() else 0.95)
		draw_arc(Vector2.ZERO, roundf(8.0 + u * 12.0), 0.0, TAU, 16, Color(c_cream, fa), 1.5)
	_draw_signal_pulses()
