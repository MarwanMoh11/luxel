class_name LxOwFoundryTrial
extends LxToy
## Island 1 Trial #1: Foundry Ring-Dash in cave_foundry_trial.
## Ring all 5 elevated foundry bells within 22s via Throw+Zip+Dash (Bronze <=28s, Silver <=22s, Gold <=15s).
## Powers linked reward gate (`door_ft_reward`) holding Pane `vesper_chime` + `moth_1_08`.

const TIME_LIMIT: float = 28.0
const TIME_SILVER: float = 22.0
const TIME_GOLD: float = 15.0

enum State { READY, RUNNING, WON }

var state: int = State.READY
var bell_ids: Array[String] = []
var rung_set: Dictionary = {}
var elapsed_s: float = 0.0
var _connected_region: Node = null
var _hud_layer: CanvasLayer = null
var _hud_draw: Node2D = null


func _toy_setup() -> void:
	kind = "ow_foundry_trial"
	size = Vector2(24.0, 18.0)
	radius = 20.0
	persist = true
	bell_ids.clear()
	var raw_b: Variant = props.get("bells", ["bell_ft_1", "bell_ft_2", "bell_ft_3", "bell_ft_4", "bell_ft_5"])
	if raw_b is Array:
		for v: Variant in (raw_b as Array):
			bell_ids.append(str(v))
	if Lx.state != null and bool(Lx.state.story_flags.get("foundry_trial_cleared", false)):
		state = State.WON
		powered = true
	else:
		state = State.READY
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
	return int(Lx.state.story_flags.get("trial_foundry_medal", 0)) if Lx.state != null else 0


func interact(_actor: Node = null) -> bool:
	if not active or state == State.RUNNING:
		return false
	_bind_region()
	state = State.RUNNING
	rung_set.clear()
	elapsed_s = 0.0
	_emit_sfx("boss_awaken")
	_ensure_hud()
	if Lx.events != null and LxStrings.has_id("ISL1_FTRIAL_START"):
		Lx.events.narration_requested.emit("ISL1_FTRIAL_START", "narration", 2.4)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	if not active or state == State.RUNNING:
		return ""
	return "PROMPT_START_TRIAL"


func tick(dt: float) -> void:
	super.tick(dt)
	_bind_region()
	if state != State.RUNNING:
		return
	elapsed_s += dt
	if elapsed_s >= TIME_LIMIT:
		_fail_trial()
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
		Lx.state.story_flags["foundry_trial_cleared"] = true
		if medal > _best_medal():
			Lx.state.story_flags["trial_foundry_medal"] = medal
		if medal >= 3 and not bool(Lx.state.story_flags.get("trial_foundry_gold_paid", false)):
			Lx.state.story_flags["trial_foundry_gold_paid"] = true
			Lx.state.add_shards(30)
		if Lx.events != null:
			Lx.events.save_requested.emit("foundry_trial_cleared")
	set_powered(true)
	emit_power(true)
	_emit_sfx("shrine_unlock")
	if Lx.events != null and LxStrings.has_id("ISL1_FTRIAL_WON"):
		Lx.events.narration_requested.emit("ISL1_FTRIAL_WON", "title", 3.0)
	queue_redraw()


func _fail_trial() -> void:
	state = State.READY if _best_medal() == 0 else State.WON
	rung_set.clear()
	_hide_hud()
	_emit_sfx("denied")
	if Lx.events != null and LxStrings.has_id("ISL1_FTRIAL_FAIL"):
		Lx.events.narration_requested.emit("ISL1_FTRIAL_FAIL", "narration", 2.2)
	queue_redraw()


func _ensure_hud() -> void:
	_hide_hud()
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "FoundryTrialHud"
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
	var rem: float = maxf(0.0, TIME_LIMIT - elapsed_s)
	var frac: float = clampf(rem / TIME_LIMIT, 0.0, 1.0)
	var low_t: bool = frac <= 0.28
	_hud_draw.draw_rect(Rect2(114.0, 10.0, 92.0, 10.0), c_void)
	_hud_draw.draw_rect(Rect2(115.0, 11.0, 90.0, 8.0), PAL["night"] as Color)
	var bar_c: Color = (PAL["apricot"] if red else PAL["coral"]) as Color if low_t else PAL["gold"] as Color
	var fill_w: float = roundf(88.0 * frac)
	if fill_w > 0.0:
		_hud_draw.draw_rect(Rect2(116.0, 12.0, fill_w, 6.0), bar_c)
		_hud_draw.draw_rect(Rect2(116.0, 12.0, fill_w, 1.0), c_cream)
	# Gold & Silver cutoff ticks for greyscale-legible medal pacing
	var gold_x: float = roundf(116.0 + 88.0 * ((TIME_LIMIT - TIME_GOLD) / TIME_LIMIT))
	var silv_x: float = roundf(116.0 + 88.0 * ((TIME_LIMIT - TIME_SILVER) / TIME_LIMIT))
	_hud_draw.draw_rect(Rect2(gold_x, 11.0, 1.0, 8.0), c_cream)
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
	var active_i: float = 0.65 if LxHudFx.flash_reduced() else 0.78
	return Vector4(pos.x, pos.y - 6.0, 48.0 if state != State.READY else 34.0, active_i if state != State.READY else 0.50) if active else Vector4.ZERO


func save_state() -> Dictionary:
	return {"active": active, "solved": state == State.WON}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if bool(d.get("solved", false)) or (Lx.state != null and bool(Lx.state.story_flags.get("foundry_trial_cleared", false))):
		state = State.WON
		powered = true
		_notify_linked_targets(true)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 12.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-12.0, -14.0, 6.0, 21.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["apricot"] as Color, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(6.0, -14.0, 6.0, 21.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["apricot"] as Color, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-13.0, -17.0, 26.0, 5.0), PAL["night"] as Color, PAL["plum"] as Color, PAL["gold"] as Color if state == State.WON else PAL["coral"] as Color, c_void)
	if state == State.RUNNING:
		draw_rect(Rect2(-3.0, -20.0, 6.0, 3.0), c_void)
		draw_rect(Rect2(-2.0, -19.0, 4.0, 2.0), PAL["gold"] as Color)
		draw_rect(Rect2(-1.0, -19.0, 2.0, 1.0), c_cream)
	var best: int = _best_medal()
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -6.0), 5 if state == State.WON else 1, state != State.READY, PAL["gold"] as Color if state == State.WON else PAL["coral"] as Color, c_cream)
	for m: int in range(3):
		var mc: Color = (PAL["gold"] if m == 2 else (PAL["ice"] if m == 1 else PAL["apricot"])) as Color
		var mx: float = -6.0 + float(m) * 4.0
		draw_rect(Rect2(mx, 4.0, 4.0, 4.0), c_void)
		draw_rect(Rect2(mx + 1.0, 5.0, 2.0, 2.0), mc if best > m else PAL["night"] as Color)
		if best > m:
			draw_rect(Rect2(mx + 1.0, 5.0, 1.0, 1.0), c_cream)
	_draw_signal_pulses()
