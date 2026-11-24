class_name LxOwChimeRelay
extends LxToy
## Island 1 Trial #2: Estate Chime Relay in manor_gardens.
## Stealth-ring 4 garden bells without entering any Lamp Butler cone (`stealth_alert == "spotted"`).
## Medals: Bronze <= 45s (15 sh), Silver <= 32s (25 sh), Gold <= 22s (45 sh + Manor hint).

const TIME_BRONZE: float = 45.0
const TIME_SILVER: float = 32.0
const TIME_GOLD: float = 22.0

enum State { READY, RUNNING, WON }

var state: int = State.READY
var bell_ids: Array[String] = []
var rung_set: Dictionary = {}
var elapsed_s: float = 0.0
var _connected_region: Node = null
var _hud_layer: CanvasLayer = null
var _hud_draw: Node2D = null


func _toy_setup() -> void:
	kind = "ow_chime_relay"
	size = Vector2(22.0, 16.0)
	radius = 18.0
	persist = true
	bell_ids.clear()
	var raw_b: Variant = props.get("bells", ["bell_mg_1", "bell_mg_2", "bell_mg_3", "bell_mg_4"])
	if raw_b is Array:
		for v: Variant in (raw_b as Array):
			bell_ids.append(str(v))
	state = State.WON if _best_medal() >= 1 else State.READY
	_bind_region()
	queue_redraw()


func _exit_tree() -> void:
	_hide_hud()
	if _connected_region != null and is_instance_valid(_connected_region):
		if _connected_region.has_signal("room_notified") and _connected_region.is_connected("room_notified", _on_room_notified):
			_connected_region.disconnect("room_notified", _on_room_notified)
	_connected_region = null


func _bind_region() -> void:
	if region != null and is_instance_valid(region) and region != _connected_region:
		if region.has_signal("room_notified") and not region.is_connected("room_notified", _on_room_notified):
			region.connect("room_notified", _on_room_notified)
			_connected_region = region


func _best_medal() -> int:
	return int(Lx.state.story_flags.get("trial_relay_medal", 0)) if Lx.state != null else 0


func interact(_actor: Node = null) -> bool:
	if not active or state == State.RUNNING:
		return false
	_bind_region()
	state = State.RUNNING
	rung_set.clear()
	elapsed_s = 0.0
	_emit_sfx("boss_awaken")
	_ensure_hud()
	if Lx.events != null and LxStrings.has_id("ISL1_RELAY_START"):
		Lx.events.narration_requested.emit("ISL1_RELAY_START", "narration", 2.6)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	if not active or state == State.RUNNING:
		return ""
	return "ISL1_PROMPT_RELAY" if LxStrings.has_id("ISL1_PROMPT_RELAY") else "PROMPT_START_TRIAL"


func tick(dt: float) -> void:
	super.tick(dt)
	_bind_region()
	if state != State.RUNNING:
		return
	elapsed_s += dt
	if LxIsland1Rule.active_instance != null and LxIsland1Rule.active_instance.stealth_alert == "spotted":
		_fail_trial("ISL1_RELAY_SPOTTED")
		return
	if elapsed_s >= TIME_BRONZE:
		_fail_trial("ISL1_RELAY_TIMEOUT")
		return
	if _hud_draw != null and is_instance_valid(_hud_draw):
		_hud_draw.queue_redraw()


func _on_room_notified(event_name: String, data: Dictionary) -> void:
	if state != State.RUNNING or event_name != "bell_rung":
		return
	var bid: String = str(data.get("id", ""))
	if bell_ids.has(bid) and not rung_set.has(bid):
		rung_set[bid] = true
		_emit_sfx("switch_on")
		if _hud_draw != null and is_instance_valid(_hud_draw):
			_hud_draw.queue_redraw()
		if rung_set.size() >= bell_ids.size():
			_win_trial()


func _win_trial() -> void:
	state = State.WON
	_hide_hud()
	var medal: int = 3 if elapsed_s <= TIME_GOLD else (2 if elapsed_s <= TIME_SILVER else 1)
	if Lx.state != null:
		var prev: int = _best_medal()
		if medal > prev:
			Lx.state.story_flags["trial_relay_medal"] = medal
		if not bool(Lx.state.story_flags.get("trial_relay_rewarded", false)):
			Lx.state.story_flags["trial_relay_rewarded"] = true
			Lx.state.story_flags["clue_manor_relay"] = true
			Lx.state.add_shards(45)
		if Lx.events != null:
			Lx.events.save_requested.emit("trial_relay")
	set_powered(true)
	emit_power(true)
	_emit_sfx("shrine_unlock")
	if Lx.events != null and LxStrings.has_id("ISL1_RELAY_WON"):
		Lx.events.narration_requested.emit("ISL1_RELAY_WON", "title", 3.2)
	queue_redraw()


func _fail_trial(msg_id: String) -> void:
	state = State.READY if _best_medal() == 0 else State.WON
	rung_set.clear()
	_hide_hud()
	_emit_sfx("denied")
	if Lx.events != null and LxStrings.has_id(msg_id):
		Lx.events.narration_requested.emit(msg_id, "narration", 2.4)
	queue_redraw()


func _ensure_hud() -> void:
	_hide_hud()
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "RelayTrialHud"
	_hud_layer.layer = 25
	add_child(_hud_layer)
	_hud_draw = Node2D.new()
	_hud_draw.draw.connect(_draw_hud)
	_hud_layer.add_child(_hud_draw)


func _hide_hud() -> void:
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	_hud_layer = null
	_hud_draw = null


func _draw_hud() -> void:
	if _hud_draw == null or state != State.RUNNING:
		return
	var rem: float = maxf(0.0, TIME_BRONZE - elapsed_s)
	var frac: float = clampf(rem / TIME_BRONZE, 0.0, 1.0)
	_hud_draw.draw_rect(Rect2(114.0, 10.0, 92.0, 10.0), PAL["void"] as Color)
	_hud_draw.draw_rect(Rect2(116.0, 12.0, roundf(88.0 * frac), 6.0), (PAL["ice"] if frac > 0.25 else PAL["coral"]) as Color)
	for i: int in range(bell_ids.size()):
		var done: bool = i < rung_set.size()
		_hud_draw.draw_rect(Rect2(116.0 + float(i) * 8.0, 21.0, 5.0, 3.0), (PAL["gold"] if done else PAL["dusk"]) as Color)


func get_light_pool() -> Vector4:
	return Vector4(pos.x, pos.y - 4.0, 34.0, 0.55) if active else Vector4.ZERO


func _draw() -> void:
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 10.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(-10.0, -10.0, 20.0, 16.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["ice"] as Color, PAL["void"] as Color)
	var best: int = _best_medal()
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -3.0), 5 if best > 0 else 2, best > 0 or state == State.RUNNING, PAL["gold"] as Color if best > 0 else PAL["ice"] as Color, PAL["cream"] as Color)
	for m: int in range(3):
		var mc: Color = (PAL["gold"] if m == 2 else (PAL["ice"] if m == 1 else PAL["apricot"])) as Color
		draw_rect(Rect2(-5.0 + float(m) * 4.0, 3.0, 3.0, 2.0), mc if best > m else PAL["void"] as Color)
