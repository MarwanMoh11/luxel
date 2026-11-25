class_name LxOwHideMoth
extends LxToy
## Hiding Moth-Friend for Quest `q1_midnight_hide` (bell_yard, vesper_graveyard, manor_gardens).
## Appears at Midnight (`bell_hour == "midnight"`). Ringing a nearby Dawn Bell (`on_ring("dawn", ...)`)
## wakes and finds the hiding friend, setting `quest:hide:<spot>` and optional extra flag!

var spot_id: String = "i1_town"
var extra_flag: String = ""
var found: bool = false
var _pop_t: float = 0.0


func _toy_setup() -> void:
	kind = "ow_hide_moth"
	size = Vector2(14.0, 14.0)
	radius = 14.0
	persist = true
	spot_id = str(props.get("spot_id", id))
	extra_flag = str(props.get("extra_flag", ""))
	found = LxQuests.current().has_flag("quest:hide:" + spot_id)
	powered = found
	queue_redraw()


func _is_midnight() -> bool:
	var v: Variant = Lx.vars.get_var("island:1", "bell_hour", "evening") if Lx.vars != null else LxToyDraw.world_get_var("island:1", "bell_hour", "evening")
	return str(v).strip_edges().to_lower() == "midnight"


func on_bell_hour_changed(_hour: String) -> void:
	queue_redraw()


func on_ring(tone: String, _dir: Vector2) -> bool:
	if not active or found or not _is_midnight():
		return false
	if tone.strip_edges().to_lower() != "dawn":
		return false
	_mark_found()
	return true


func interact(_actor: Node = null) -> bool:
	if not active or found or not _is_midnight():
		return false
	# Allow close inspect hint if player hasn't rung the Dawn bell yet
	if Lx.events != null and LxStrings.has_id("ISL1_HIDE_HINT"):
		Lx.events.narration_requested.emit("ISL1_HIDE_HINT", "narration", 2.4)
	_emit_sfx("ui_move")
	return true


func _mark_found() -> void:
	found = true
	_pop_t = 0.75
	LxQuests.current().mark_hide_found(spot_id)
	if not extra_flag.is_empty():
		LxQuests.current().set_flag(extra_flag, true)
	set_powered(true)
	emit_power(true)
	_emit_sfx("ember_pickup")
	_emit_gust(48.0, 42.0)
	if Lx.events != null:
		if LxStrings.has_id("ISL1_HIDE_FOUND"):
			Lx.events.narration_requested.emit("ISL1_HIDE_FOUND", "narration", 2.6)
		Lx.events.save_requested.emit("hide_" + spot_id)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _pop_t > 0.0:
		_pop_t = maxf(0.0, _pop_t - dt)
		queue_redraw()
	elif not found and _is_midnight():
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active or found or not _is_midnight():
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 22.0, 0.35)


func _draw() -> void:
	if not active:
		return
	if _pop_t > 0.0:
		var u: float = 1.0 - clampf(_pop_t / 0.75, 0.0, 1.0)
		var lift: float = -roundf(u * 14.0)
		draw_arc(Vector2(0.0, lift - 4.0), roundf(4.0 + u * 16.0), 0.0, TAU, 16, PAL["gold"] as Color, 1.0)
		draw_rect(Rect2(-4.0, lift - 6.0, 8.0, 6.0), PAL["gold"] as Color)
		draw_rect(Rect2(-2.0, lift - 5.0, 4.0, 4.0), PAL["cream"] as Color)
		return
	if found or not _is_midnight():
		return
	# Subtle golden eyes & fluttering wing tips peeking from cover at Midnight
	var peek: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 4.5) * 1.0)
	draw_rect(Rect2(-5.0, -4.0 + peek, 10.0, 6.0), PAL["night"] as Color)
	draw_rect(Rect2(-4.0, -3.0 + peek, 3.0, 3.0), PAL["apricot"] as Color)
	draw_rect(Rect2(1.0, -3.0 + peek, 3.0, 3.0), PAL["apricot"] as Color)
	draw_rect(Rect2(-2.0, -2.0 + peek, 1.0, 1.0), PAL["cream"] as Color)
	draw_rect(Rect2(1.0, -2.0 + peek, 1.0, 1.0), PAL["cream"] as Color)
