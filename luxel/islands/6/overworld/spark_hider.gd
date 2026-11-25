class_name LxSparkHider
extends LxInteractable
## Hiding Spark-Kid spot for Island 6 quest `q6_spark_hide` (`kind: "spark_hider"`).
## Peeks bright lantern eyes from cool basalt shadows; interact OR shine lantern light to find!
## Props: spot_id ("spark_1"|"spark_2"|"spark_3"), target_id (optional).

var spot_id: String = "spark_1"
var found: bool = false
var _found_fx_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "spark_hider"
	radius = 15.0
	spot_id = str(props.get("spot_id", id))
	found = LxQuests.current().has_flag("quest:hide:" + spot_id)
	active = not found
	visible = not found
	queue_redraw()


func get_interact_prompt() -> String:
	return "" if (found or not active) else "PROMPT_TALK"


func interact(_actor: Node = null) -> bool:
	return _discover()


func on_light(_light_radius: float, _source: String) -> void:
	if not found and active:
		_discover()


func _discover() -> bool:
	if found or not active:
		return false
	found = true
	active = false
	_found_fx_t = 0.65
	LxQuests.current().mark_hide_found(spot_id)
	if Lx.state != null:
		if LxQuests.current().has_flag("quest:hide:spark_1") \
				and LxQuests.current().has_flag("quest:hide:spark_2") \
				and LxQuests.current().has_flag("quest:hide:spark_3"):
			Lx.state.story_flags["q6_spark_all_found"] = true
	_emit_sfx("ember_pickup")
	_emit_gust(42.0, 38.0, Vector2(0.0, -4.0))
	if Lx.events != null:
		if LxStrings.has_id("ISL6_SPARK_FOUND"):
			Lx.events.narration_requested.emit("ISL6_SPARK_FOUND", "narration", 2.4)
		Lx.events.save_requested.emit("spark_hide_" + spot_id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _found_fx_t > 0.0:
		_found_fx_t = maxf(0.0, _found_fx_t - dt)
		visible = _found_fx_t > 0.0
		queue_redraw()
		return
	if not found and active:
		queue_redraw()


func get_light_pool() -> Vector4:
	if found or not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 18.0, 0.28)


func save_state() -> Dictionary:
	return {"active": active, "found": found}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	found = bool(d.get("found", found)) or LxQuests.current().has_flag("quest:hide:" + spot_id)
	active = not found
	visible = not found
	queue_redraw()


func _draw() -> void:
	if _found_fx_t > 0.0:
		var u: float = 1.0 - clampf(_found_fx_t / 0.65, 0.0, 1.0)
		draw_arc(Vector2(0.0, -6.0), roundf(4.0 + u * 20.0), 0.0, TAU, 14, PAL["gold"] as Color, 1.2)
		draw_rect(Rect2(-2.0, -8.0 - roundf(u * 14.0), 4.0, 4.0), PAL["cream"] as Color)
		return
	if found or not active:
		return
	var blink: bool = not LxHudFx.flash_reduced() and fmod(_clock + pos.x * 0.03, 3.2) > 3.0
	var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.0) * 1.0)
	# Cloaked little moth-spark silhouette hiding behind basalt shadow
	draw_rect(Rect2(-6.0, -10.0 + bob, 12.0, 11.0), PAL["void"] as Color)
	draw_rect(Rect2(-5.0, -9.0 + bob, 10.0, 9.0), PAL["night"] as Color)
	draw_rect(Rect2(-4.0, -10.0 + bob, 8.0, 3.0), PAL["plum"] as Color)
	if not blink:
		draw_rect(Rect2(-3.0, -6.0 + bob, 2.0, 2.0), PAL["gold"] as Color)
		draw_rect(Rect2(1.0, -6.0 + bob, 2.0, 2.0), PAL["gold"] as Color)
		draw_rect(Rect2(-2.0, -6.0 + bob, 1.0, 1.0), PAL["cream"] as Color)
		draw_rect(Rect2(2.0, -6.0 + bob, 1.0, 1.0), PAL["cream"] as Color)
