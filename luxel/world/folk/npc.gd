class_name LxNpc
extends LxInteractable
## Lamp-folk NPC (kind "npc"): 16x20 sprite sheet with idle/talk/happy animations,
## pictogram bubble sequences advancing on E, gentle wander/idle routines,
## light reaction, quest hook, and optional rescue to Wick House hub (flag "folk:<id>").

var folk_id: String = "moth_kid"
var bubbles: Array = []          # Array of Array[String] or Dictionary {icons, line}
var quest_id: String = ""
var rescuable: bool = false
var rescue_flag: String = ""
var require_flag: String = ""
var hide_if_flag: String = ""
var wander_radius: float = 16.0
var light_view_id: String = ""

var home_pos: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var _anim_state: String = "idle"
var _talk_idx: int = -1
var _talk_t: float = 0.0
var _happy_t: float = 0.0
var _lit_t: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _wander_wait: float = 1.6
var _sheet: LxSpriteSheet = null
var _bubble: LxBubble = null
var _narrated_once: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "npc"
	radius = maxf(14.0, radius)
	folk_id = str(props.get("folk", props.get("folk_id", "moth_kid")))
	quest_id = str(props.get("quest", ""))
	rescuable = bool(props.get("rescuable", false))
	rescue_flag = str(props.get("rescue_flag", ("folk:" + folk_id) if rescuable else ""))
	require_flag = str(props.get("require_flag", ""))
	hide_if_flag = str(props.get("hide_if_flag", ""))
	wander_radius = maxf(0.0, float(props.get("wander_radius", 16.0)))
	light_view_id = str(props.get("light_view", ""))
	var f_v: Variant = props.get("facing", [0.0, 1.0])
	facing = _parse_vec2(f_v, Vector2.DOWN).normalized()
	home_pos = pos
	_wander_target = home_pos
	_wander_wait = 1.2 + fmod(absf(pos.x * 0.017 + pos.y * 0.013), 2.0)

	var raw_b: Variant = props.get("bubbles", [])
	bubbles = (raw_b as Array).duplicate(true) if raw_b is Array else []
	if bubbles.is_empty():
		var fspec: Dictionary = LxFolkData.folk_spec(folk_id)
		var def_b: Variant = fspec.get("default_bubbles", [["lantern", "happy"]])
		if def_b is Array:
			bubbles = (def_b as Array).duplicate(true)

	_sheet = LxSpriteSheet.load_sheet("res://luxel/art/folk/%s.json" % folk_id)
	_ensure_bubble()
	_sync_presence()
	queue_redraw()


func _ensure_bubble() -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		_bubble = LxBubble.new()
		_bubble.name = "Bubble"
		_bubble.position = Vector2(0.0, -20.0)
		add_child(_bubble)


func _sync_presence() -> void:
	var vis: bool = true
	if not require_flag.is_empty() and not LxQuests.current().has_flag(require_flag):
		vis = false
	if not hide_if_flag.is_empty() and LxQuests.current().has_flag(hide_if_flag):
		vis = false
	if rescuable and not rescue_flag.is_empty() and island_id != 0 and LxQuests.current().has_flag(rescue_flag):
		vis = false
	active = vis
	visible = vis


func is_rescued() -> bool:
	return not rescue_flag.is_empty() and LxQuests.current().has_flag(rescue_flag)


func get_bubble_node() -> LxBubble:
	_ensure_bubble()
	return _bubble


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "PROMPT_TALK_NEXT" if _talk_idx >= 0 else "PROMPT_TALK"


func on_light(_light_radius: float, _source: String) -> void:
	if not active:
		return
	_lit_t = 0.45
	if _happy_t < 0.35:
		_happy_t = 0.55
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		var d: Vector2 = (Lx.player as Node2D).global_position - pos
		if d.length_squared() > 4.0:
			facing = d.normalized()
	if not light_view_id.is_empty():
		LxQuests.current().mark_light_view(light_view_id)
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_ensure_bubble()
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		var d: Vector2 = (Lx.player as Node2D).global_position - pos
		if d.length_squared() > 4.0:
			facing = d.normalized()

	var pages: Array = _resolved_pages()
	if pages.is_empty():
		pages = [["lantern", "happy"]]

	_talk_idx += 1
	if _talk_idx >= pages.size():
		_finish_conversation()
		return true

	_show_page(pages, _talk_idx)
	_talk_t = 0.55
	_emit_sfx("folk_chirp_" + folk_id)
	queue_redraw()
	return true


func _resolved_pages() -> Array:
	if not quest_id.is_empty():
		var q: LxQuests = LxQuests.current()
		if q.is_quest_done(quest_id):
			return [["check", "heart", "lantern"]]
		var q_icons: Array[String] = q.get_active_bubble_icons(quest_id)
		if not q_icons.is_empty():
			return [q_icons]
	return bubbles


func _show_page(pages: Array, idx: int) -> void:
	var page: Variant = pages[idx]
	var icon_arr: Array[String] = []
	var line_id: String = ""
	if page is Array:
		for item: Variant in (page as Array):
			icon_arr.append(str(item))
	elif page is Dictionary:
		var pd: Dictionary = page as Dictionary
		var raw_ic: Variant = pd.get("icons", [])
		if raw_ic is Array:
			for item: Variant in (raw_ic as Array):
				icon_arr.append(str(item))
		line_id = str(pd.get("line", ""))
	if icon_arr.is_empty():
		icon_arr = ["lantern", "happy"]
	var accent: String = LxBiomePalette.key(maxi(1, island_id), "border")
	_bubble.show_strip(icon_arr, idx, pages.size(), accent)
	if not line_id.is_empty() and not _narrated_once and Lx.events != null:
		_narrated_once = true
		Lx.events.narration_requested.emit(line_id, "narration", 3.0)


func _finish_conversation() -> void:
	_talk_idx = -1
	if _bubble != null:
		_bubble.hide_bubble()
	_happy_t = 1.1

	if not quest_id.is_empty():
		var res: Dictionary = LxQuests.current().advance_quest(quest_id)
		var status: String = str(res.get("status", ""))
		if status == "completed":
			_emit_sfx("quest_done")
			_bubble.show_strip(["check", "gift", "happy"], 0, 1, "lime")
			_happy_t = 1.8
		elif status == "advanced":
			_emit_sfx("switch_on")
			_bubble.show_strip(LxQuests.current().get_active_bubble_icons(quest_id), 0, 1, "gold")
	if rescuable and not rescue_flag.is_empty() and not LxQuests.current().has_flag(rescue_flag):
		LxQuests.current().set_flag(rescue_flag, true)
		_emit_sfx("quest_done")
		_bubble.show_strip(["home", "heart", "happy"], 0, 1, "gold")
		if Lx.events != null:
			Lx.events.narration_requested.emit("FOLK_RESCUED", "title", 2.8)
			Lx.events.save_requested.emit("rescue_" + folk_id)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	_sync_presence()
	if not active:
		return
	if _talk_t > 0.0:
		_talk_t = maxf(0.0, _talk_t - dt)
	if _happy_t > 0.0:
		_happy_t = maxf(0.0, _happy_t - dt)
	if _lit_t > 0.0:
		_lit_t = maxf(0.0, _lit_t - dt)

	# Close speech bubble if Wick walks away
	if _bubble != null and _bubble.visible:
		_bubble.tick(dt)
		if Lx.player is Node2D and is_instance_valid(Lx.player):
			if (Lx.player as Node2D).global_position.distance_to(pos) > 68.0:
				_talk_idx = -1
				_bubble.hide_bubble()

	# Gentle wander routine when not talking
	if wander_radius > 0.5 and _talk_idx < 0:
		_tick_wander(dt)

	_anim_state = "talk" if _talk_t > 0.0 else ("happy" if (_happy_t > 0.0 or _lit_t > 0.0) else "idle")
	queue_redraw()


func _tick_wander(dt: float) -> void:
	var to_t: Vector2 = _wander_target - pos
	if to_t.length() <= 2.0:
		_wander_wait -= dt
		if _wander_wait <= 0.0:
			_wander_wait = 1.8 + fmod(_clock * 1.37 + home_pos.x * 0.03, 2.2)
			var ang: float = fmod(_clock * 2.13 + home_pos.y * 0.07, TAU)
			var dist: float = wander_radius * (0.35 + 0.65 * fmod(absf(sin(_clock * 0.91 + home_pos.x)), 1.0))
			_wander_target = home_pos + Vector2.from_angle(ang) * dist
		return
	var step: Vector2 = to_t.normalized() * minf(16.0 * dt, to_t.length())
	var cand: Vector2 = pos + step
	var blocked: bool = false
	if region != null and region.has_method("is_blocked"):
		blocked = bool(region.call("is_blocked", cand, 5.0, false))
	if not blocked:
		pos = cand
		position = pos.round()
		facing = to_t.normalized()
	else:
		_wander_target = home_pos
		_wander_wait = 1.5


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 8.0, 32.0 if _lit_t > 0.0 else 22.0, 0.55 if _lit_t > 0.0 else 0.32)


func _draw() -> void:
	if not active:
		return
	_draw_ground_shadow(6.0, 2.5, Vector2(0.0, 1.0))
	var drew: bool = false
	if _sheet != null:
		drew = _sheet.draw_actor(self, Vector2.ZERO, _anim_state, facing, _clock)
	if not drew:
		draw_rect(Rect2(-5.0, -14.0, 10.0, 14.0), LxPalette.PAL["plum"])
		draw_rect(Rect2(-3.0, -12.0, 6.0, 6.0), LxPalette.PAL["gold"])
	# Quest available / turn-in floating pip above head when bubble is closed
	if (_bubble == null or not _bubble.visible) and not quest_id.is_empty():
		var q: LxQuests = LxQuests.current()
		if not q.is_quest_done(quest_id):
			var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.5) * 1.0)
			var py: float = -24.0 + bob
			draw_rect(Rect2(-2.0, py - 1.0, 5.0, 5.0), LxPalette.PAL["void"])
			draw_rect(Rect2(-1.0, py, 3.0, 3.0), LxPalette.PAL["gold"] if q.is_quest_started(quest_id) else LxPalette.PAL["cream"])
			draw_rect(Rect2(0.0, py + 1.0, 1.0, 1.0), LxPalette.PAL["coral"])
	elif _lit_t > 0.0 and (_bubble == null or not _bubble.visible):
		# Warm sparkle reaction to lantern light
		draw_rect(Rect2(-1.0, -21.0, 3.0, 1.0), LxPalette.PAL["gold"])
		draw_rect(Rect2(0.0, -22.0, 1.0, 3.0), LxPalette.PAL["cream"])
