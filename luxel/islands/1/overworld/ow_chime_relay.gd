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
	_hud_draw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var red: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var rem: float = maxf(0.0, TIME_BRONZE - elapsed_s)
	var frac: float = clampf(rem / TIME_BRONZE, 0.0, 1.0)
	var low_t: bool = frac <= 0.25
	_hud_draw.draw_rect(Rect2(114.0, 10.0, 92.0, 10.0), c_void)
	_hud_draw.draw_rect(Rect2(115.0, 11.0, 90.0, 8.0), PAL["night"] as Color)
	var bar_c: Color = (PAL["apricot"] if red else PAL["coral"]) as Color if low_t else PAL["ice"] as Color
	var fill_w: float = roundf(88.0 * frac)
	if fill_w > 0.0:
		_hud_draw.draw_rect(Rect2(116.0, 12.0, fill_w, 6.0), bar_c)
		_hud_draw.draw_rect(Rect2(116.0, 12.0, fill_w, 1.0), c_cream)
	# Gold & Silver cutoff ticks for greyscale-legible medal pacing
	var gold_x: float = roundf(116.0 + 88.0 * ((TIME_BRONZE - TIME_GOLD) / TIME_BRONZE))
	var silv_x: float = roundf(116.0 + 88.0 * ((TIME_BRONZE - TIME_SILVER) / TIME_BRONZE))
	_hud_draw.draw_rect(Rect2(gold_x, 11.0, 1.0, 8.0), PAL["gold"] as Color)
	_hud_draw.draw_rect(Rect2(silv_x, 11.0, 1.0, 8.0), PAL["stone"] as Color)
	for i: int in range(bell_ids.size()):
		var done: bool = i < rung_set.size()
		var px: float = 115.0 + float(i) * 8.0
		_hud_draw.draw_rect(Rect2(px, 21.0, 7.0, 5.0), c_void)
		if done:
			_hud_draw.draw_rect(Rect2(px + 1.0, 21.0, 5.0, 4.0), PAL["gold"] as Color)
			_hud_draw.draw_rect(Rect2(px + 1.0, 21.0, 2.0, 1.0), c_cream)
		else:
			_hud_draw.draw_rect(Rect2(px + 1.0, 23.0, 5.0, 2.0), PAL["dusk"] as Color)


func get_light_pool() -> Vector4:
	return Vector4(pos.x, pos.y - 4.0, 34.0, 0.45 if LxHudFx.flash_reduced() else 0.55) if active else Vector4.ZERO


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 10.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-10.0, -10.0, 20.0, 16.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["ice"] as Color, c_void)
	if state == State.RUNNING:
		draw_rect(Rect2(-3.0, -13.0, 6.0, 3.0), c_void)
		draw_rect(Rect2(-2.0, -12.0, 4.0, 2.0), PAL["ice"] as Color)
		draw_rect(Rect2(-1.0, -12.0, 2.0, 1.0), c_cream)
	var best: int = _best_medal()
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -3.0), 5 if best > 0 else 2, best > 0 or state == State.RUNNING, PAL["gold"] as Color if best > 0 else PAL["ice"] as Color, c_cream)
	for m: int in range(3):
		var mc: Color = (PAL["gold"] if m == 2 else (PAL["ice"] if m == 1 else PAL["apricot"])) as Color
		var mx: float = -6.0 + float(m) * 4.0
		draw_rect(Rect2(mx, 2.0, 4.0, 4.0), c_void)
		draw_rect(Rect2(mx + 1.0, 3.0, 2.0, 2.0), mc if best > m else PAL["night"] as Color)
		if best > m:
			draw_rect(Rect2(mx + 1.0, 3.0, 1.0, 1.0), c_cream)
