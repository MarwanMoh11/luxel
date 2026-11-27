class_name LxHubNpc
extends LxNpc
## Wick House Lamp-Folk NPC (kind "hub_npc"):
## Extends LxNpc with purposeful multi-waypoint routines, pictogram bubbles that react
## to the last island relit, hub quests, and optional direct service menus (lead_shop / tailor).

const ISLAND_REACTIONS: Dictionary = {
	1: {"icons": ["isl_1", "bell", "music", "happy"], "line": "HUB_REACT_ISL1"},
	2: {"icons": ["isl_2", "toy_skiff", "wave", "happy"], "line": "HUB_REACT_ISL2"},
	3: {"icons": ["isl_3", "seed", "toy_plant", "heart"], "line": "HUB_REACT_ISL3"},
	4: {"icons": ["isl_4", "clock", "eye", "spark"], "line": "HUB_REACT_ISL4"},
	5: {"icons": ["isl_5", "star", "toy_gravity", "happy"], "line": "HUB_REACT_ISL5"},
	6: {"icons": ["isl_6", "ember", "flame", "gear"], "line": "HUB_REACT_ISL6"},
	7: {"icons": ["isl_7", "mirror", "spark", "eye"], "line": "HUB_REACT_ISL7"},
	8: {"icons": ["isl_8", "crown", "lantern", "heart"], "line": "HUB_REACT_ISL8"},
}

var service_mode: String = "" # "", "lead_shop", "tailor", "journal", "panes"
var routine_points: Array[Dictionary] = [] # {pos: Vector2, wait: float, anim: String}
var _routine_idx: int = 0
var _routine_wait: float = 0.0
var _routine_anim: String = "idle"
var _hub_narrated_isl: int = -1


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "hub_npc"
	service_mode = str(props.get("service", "")).strip_edges().to_lower()
	routine_points.clear()
	var raw_r: Variant = props.get("routine", [])
	if raw_r is Array:
		for item: Variant in (raw_r as Array):
			if item is Dictionary:
				var rd: Dictionary = item as Dictionary
				var p: Vector2 = _parse_vec2(rd.get("pos", [home_pos.x, home_pos.y]), home_pos)
				routine_points.append({
					"pos": p,
					"wait": maxf(0.8, float(rd.get("wait", 2.4))),
					"anim": str(rd.get("anim", "idle")),
				})
	_routine_idx = 0
	_routine_wait = 1.2
	_routine_anim = "idle"


func get_interact_prompt() -> String:
	if not active:
		return ""
	if _talk_idx >= 0:
		return "PROMPT_TALK_NEXT"
	match service_mode:
		"lead_shop": return "PROMPT_HUB_LEAD_FORGE"
		"tailor": return "PROMPT_HUB_TAILOR"
		"journal": return "PROMPT_JOURNAL"
		"panes": return "PROMPT_PANE_WORKSHOP"
		_: return "PROMPT_TALK"


func interact(_actor: Node = null) -> bool:
	if _talk_idx < 0:
		var last_isl: int = LxHubState.get_last_relit_island()
		if last_isl > 0 and _hub_narrated_isl != last_isl:
			_narrated_once = false
	return super.interact(_actor)


func _resolved_pages() -> Array:
	var pages: Array = []
	# 1. Active hub quest bubble takes top priority if not finished
	if not quest_id.is_empty():
		var q: LxQuests = LxQuests.current()
		if not q.is_quest_done(quest_id):
			var q_icons: Array[String] = q.get_active_bubble_icons(quest_id)
			if not q_icons.is_empty():
				pages.append(q_icons)
				return pages
	# 2. Reactive pictogram bubble to the most recently relit island!
	var last_isl: int = LxHubState.get_last_relit_island()
	if last_isl > 0 and ISLAND_REACTIONS.has(last_isl):
		var react: Dictionary = ISLAND_REACTIONS[last_isl] as Dictionary
		var p_dict: Dictionary = {"icons": (react["icons"] as Array).duplicate()}
		if _hub_narrated_isl != last_isl:
			p_dict["line"] = str(react["line"])
		pages.append(p_dict)
	# 3. Append folk's personal hub bubbles
	for b: Variant in bubbles:
		pages.append(b)
	if pages.is_empty():
		pages.append(["home", "lantern", "heart"])
	return pages


func _finish_conversation() -> void:
	var last_isl: int = LxHubState.get_last_relit_island()
	if last_isl > 0:
		_hub_narrated_isl = last_isl
	super._finish_conversation()
	# Open service menu after speaking (if folk runs a workshop service)
	if not service_mode.is_empty():
		match service_mode:
			"lead_shop":
				var h1: LxHubMenuHost = LxHubMenuHost.ensure()
				if h1 != null:
					h1.open_lead_shop()
			"tailor":
				var h2: LxHubMenuHost = LxHubMenuHost.ensure()
				if h2 != null:
					h2.open_tailor()
			"journal":
				if Lx.ui != null and Lx.ui.has_method("show_journal"):
					Lx.ui.call("show_journal", LxUiRoot.Screen.HUD)
			"panes":
				if Lx.ui != null and Lx.ui.has_method("open_panes_menu"):
					Lx.ui.call("open_panes_menu")


func _tick_wander(dt: float) -> void:
	if routine_points.is_empty():
		super._tick_wander(dt)
		return
	var wp: Dictionary = routine_points[_routine_idx]
	var target: Vector2 = wp["pos"] as Vector2
	var to_t: Vector2 = target - pos
	if to_t.length() <= 2.5:
		_routine_anim = str(wp.get("anim", "idle"))
		if _routine_anim == "happy":
			_happy_t = maxf(_happy_t, 0.25)
		_routine_wait -= dt
		if _routine_wait <= 0.0:
			_routine_idx = (_routine_idx + 1) % routine_points.size()
			_routine_wait = float(routine_points[_routine_idx].get("wait", 2.4))
		return
	var step: Vector2 = to_t.normalized() * minf(18.0 * dt, to_t.length())
	var cand: Vector2 = pos + step
	var blocked: bool = false
	if region != null and region.has_method("is_blocked"):
		blocked = bool(region.call("is_blocked", cand, 5.0, false))
	if not blocked:
		pos = cand
		position = pos.round()
		facing = to_t.normalized()
	else:
		_routine_idx = (_routine_idx + 1) % routine_points.size()
		_routine_wait = 1.4


func _draw() -> void:
	super._draw()
	if not active or (_bubble != null and _bubble.visible):
		return
	var fr: bool = LxHudFx.flash_reduced()
	var bob: float = 0.0 if fr else roundf(sin(_clock * 3.5) * 1.0)
	var c_void: Color = LxPalette.PAL["void"]
	var c_cream: Color = LxPalette.PAL["cream"]
	# 1. Quest status badge (! available / ! ready to turn in / ? in progress)
	if not quest_id.is_empty():
		var q: LxQuests = LxQuests.current()
		if not q.is_quest_done(quest_id):
			var started: bool = q.is_quest_started(quest_id)
			var step: Dictionary = q.get_current_step(quest_id)
			var need: String = str(step.get("need", ""))
			var ready: bool = started and (need.is_empty() or q.has_flag(need))
			var py: float = -29.0 + bob
			draw_rect(Rect2(-3.0, py - 1.0, 7.0, 10.0), c_void)
			if not started or ready:
				var col: Color = LxPalette.PAL["lime"] if ready else LxPalette.PAL["gold"]
				draw_rect(Rect2(-1.0, py, 3.0, 5.0), col)
				draw_rect(Rect2(0.0, py, 1.0, 2.0), c_cream)
				draw_rect(Rect2(-1.0, py + 6.0, 3.0, 2.0), c_cream if ready else col)
			else:
				# Crisp pixel '?' for active in-progress hub quest
				var col_q: Color = LxPalette.PAL["sky"]
				draw_rect(Rect2(-2.0, py, 5.0, 2.0), col_q)
				draw_rect(Rect2(1.0, py + 2.0, 2.0, 2.0), LxPalette.PAL["ice"])
				draw_rect(Rect2(-1.0, py + 3.0, 2.0, 2.0), col_q)
				draw_rect(Rect2(-1.0, py + 6.0, 2.0, 2.0), LxPalette.PAL["ice"])
			return
	# 2. Fresh island-relit reaction spark badge
	var last_isl: int = LxHubState.get_last_relit_island()
	if last_isl > 0 and ISLAND_REACTIONS.has(last_isl) and _hub_narrated_isl != last_isl:
		var ry: float = -26.0 + bob
		draw_rect(Rect2(-3.0, ry - 1.0, 7.0, 7.0), c_void)
		draw_rect(Rect2(-1.0, ry, 3.0, 5.0), LxPalette.PAL["gold"])
		draw_rect(Rect2(-2.0, ry + 1.0, 5.0, 3.0), LxPalette.PAL["gold"])
		draw_rect(Rect2(0.0, ry + 2.0, 1.0, 1.0), c_cream)
		return
	# 3. Workshop service emblem pip when NPC offers a direct service menu
	if not service_mode.is_empty():
		var sy: float = -25.0 + bob
		var sc: Color = LxPalette.PAL["apricot"] if service_mode == "lead_shop" else (LxPalette.PAL["rose"] if service_mode == "tailor" else (LxPalette.PAL["ice"] if service_mode == "journal" else LxPalette.PAL["sky"]))
		draw_rect(Rect2(-3.0, sy - 1.0, 7.0, 5.0), c_void)
		draw_rect(Rect2(-2.0, sy, 5.0, 3.0), sc)
		draw_rect(Rect2(-1.0, sy, 2.0, 1.0), c_cream)
