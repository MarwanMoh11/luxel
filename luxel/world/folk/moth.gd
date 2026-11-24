class_name LxMoth
extends LxInteractable
## Lost Moth collectible (80 across the archipelago).
## Flutters & hides in the dark; comes toward lantern light; caught by lantern light, NOT by bolts.
## Persists in Lx.state.story_flags under "moth:<id>".

const LURE_CATCH_SECS: float = 0.65
const CATCH_DIST: float = 15.0

var moth_id: String = ""
var caught: bool = false
var _home_pos: Vector2 = Vector2.ZERO
var _lit_t: float = 0.0
var _lured_t: float = 0.0
var _startle_t: float = 0.0
var _catch_fx_t: float = 0.0
var _lure_target: Vector2 = Vector2.ZERO


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "moth"
	radius = 12.0
	moth_id = str(props.get("id", id))
	if moth_id.is_empty():
		moth_id = "moth_%d_01" % clampi(island_id, 1, 8)
	_home_pos = pos
	caught = LxQuests.current().is_moth_caught(moth_id)
	active = not caught
	visible = not caught
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	## Bolts NEVER catch a Lost Moth — they only startle it away with a dust puff!
	if caught or not active:
		return false
	_startle_t = 0.55
	_lured_t = 0.0
	var away: Vector2 = hit.dir.normalized() if hit != null and hit.dir.length_squared() > 0.01 else Vector2.UP
	pos += away * 10.0
	position = pos.round()
	_emit_sfx("ui_move")
	queue_redraw()
	return false


func on_light(light_radius: float, _source: String) -> void:
	if caught or not active:
		return
	if _startle_t > 0.0:
		return
	_lit_t = 0.25
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		var w: Node2D = Lx.player as Node2D
		var lan_v: Variant = w.get("lantern")
		if lan_v is Object and (lan_v as Object).has_method("is_out") and bool((lan_v as Object).call("is_out")):
			_lure_target = (lan_v as Object).get("pos") as Vector2
		else:
			_lure_target = w.global_position
	else:
		_lure_target = pos
	if light_radius >= 24.0 and pos.distance_to(_lure_target) <= CATCH_DIST:
		_catch_moth()


func _catch_moth() -> void:
	if caught:
		return
	caught = true
	active = false
	_catch_fx_t = 0.50
	LxQuests.current().catch_moth(moth_id)
	_emit_sfx("ember_pickup")
	_emit_gust(42.0, 38.0, Vector2(0.0, -4.0))
	if Lx.events != null:
		Lx.events.narration_requested.emit("MOTH_CAUGHT", "narration", 2.0)
	_notify_linked_targets(true)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _catch_fx_t > 0.0:
		_catch_fx_t = maxf(0.0, _catch_fx_t - dt)
		visible = _catch_fx_t > 0.0
		queue_redraw()
		return
	if caught or not active:
		visible = false
		return

	if _startle_t > 0.0:
		_startle_t = maxf(0.0, _startle_t - dt)
	if _lit_t > 0.0:
		_lit_t = maxf(0.0, _lit_t - dt)
		_lured_t += dt
		pos = pos.move_toward(_lure_target, 42.0 * dt)
		position = pos.round()
		if _lured_t >= LURE_CATCH_SECS or pos.distance_to(_lure_target) <= CATCH_DIST:
			_catch_moth()
	else:
		_lured_t = maxf(0.0, _lured_t - dt * 0.5)
		var orbit := Vector2(cos(_clock * 1.9 + _home_pos.x * 0.05) * 6.0, sin(_clock * 3.1 + _home_pos.y * 0.05) * 4.0)
		pos = pos.move_toward(_home_pos + orbit, 20.0 * dt)
		position = pos.round()
	queue_redraw()


func get_light_pool() -> Vector4:
	if caught or not active:
		return Vector4.ZERO
	if _lit_t > 0.0:
		return Vector4(pos.x, pos.y - 4.0, 26.0, 0.55)
	return Vector4(pos.x, pos.y - 4.0, 12.0, 0.18)


func save_state() -> Dictionary:
	return {"active": active, "caught": caught}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	caught = bool(d.get("caught", caught)) or LxQuests.current().is_moth_caught(moth_id)
	active = not caught
	visible = not caught
	queue_redraw()


func _draw() -> void:
	if _catch_fx_t > 0.0:
		var u: float = 1.0 - clampf(_catch_fx_t / 0.50, 0.0, 1.0)
		var r: float = roundf(3.0 + u * 18.0)
		draw_arc(Vector2(0.0, -5.0), r, 0.0, TAU, 14, LxPalette.PAL["gold"] if u < 0.5 else LxPalette.PAL["cream"], 1.0)
		for k: int in range(6):
			var a: float = float(k) * TAU / 6.0 + u * 1.4
			var sp := Vector2(roundf(cos(a) * r), roundf(-5.0 + sin(a) * r * 0.6 - u * 8.0))
			draw_rect(Rect2(sp, Vector2.ONE), LxPalette.PAL["cream"] if k % 2 == 0 else LxPalette.PAL["gold"])
		return
	if caught or not active:
		return
	var fr: bool = LxHudFx.flash_reduced()
	var flap: bool = fr or (int(_clock * (12.0 if _lit_t > 0.0 else 6.0)) % 2 == 0)
	var fy: float = -6.0 + (0.0 if fr else roundf(sin(_clock * 5.0) * 1.5))
	var wing_c: Color = LxPalette.PAL["gold"] if _lit_t > 0.0 else LxPalette.PAL["mauve"]
	var hi_c: Color = LxPalette.PAL["cream"] if _lit_t > 0.0 else LxPalette.PAL["stone"]
	# Tiny pixel moth silhouette (wings fold/open on flap)
	draw_rect(Rect2(-1.0, fy - 1.0, 2.0, 4.0), LxPalette.PAL["void"])
	draw_rect(Rect2(0.0, fy, 1.0, 2.0), hi_c)
	if flap:
		draw_rect(Rect2(-4.0, fy - 2.0, 3.0, 3.0), wing_c)
		draw_rect(Rect2(1.0, fy - 2.0, 3.0, 3.0), wing_c)
		draw_rect(Rect2(-3.0, fy - 1.0, 1.0, 1.0), hi_c)
		draw_rect(Rect2(2.0, fy - 1.0, 1.0, 1.0), hi_c)
	else:
		draw_rect(Rect2(-2.0, fy - 1.0, 2.0, 3.0), wing_c)
		draw_rect(Rect2(1.0, fy - 1.0, 2.0, 3.0), wing_c)
	if _lit_t > 0.0:
		var prog: float = clampf(_lured_t / LURE_CATCH_SECS, 0.0, 1.0)
		draw_arc(Vector2(0.0, fy), 6.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 12, LxPalette.PAL["cream"], 1.0)
