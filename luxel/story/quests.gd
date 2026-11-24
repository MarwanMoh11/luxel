class_name LxQuests
extends RefCounted
## Flag-graph quest system, lost-moth tracker, moth-lantern reward tiers, and bestiary ledger.
## State is stored in Lx.state.story_flags under "quest:", "moth:", "folk:", "bestiary:", "cosmetic:".

const MOTH_TIERS: Array[int] = [5, 10, 20, 35, 50, 65, 80]

static var active: LxQuests = null
var _bound_events: LxEventBus = null


static func current() -> LxQuests:
	if active == null:
		active = LxQuests.new()
	return active


static func reset_singleton() -> void:
	if active != null:
		active.unbind_events()
	active = null


func bind_events(events: LxEventBus = null) -> void:
	var ev: LxEventBus = events if events != null else Lx.events
	if ev == null or _bound_events == ev:
		return
	unbind_events()
	_bound_events = ev
	ev.enemy_hit.connect(_on_enemy_hit)
	ev.enemy_killed.connect(_on_enemy_killed)


func unbind_events() -> void:
	if _bound_events == null or not is_instance_valid(_bound_events):
		_bound_events = null
		return
	if _bound_events.enemy_hit.is_connected(_on_enemy_hit):
		_bound_events.enemy_hit.disconnect(_on_enemy_hit)
	if _bound_events.enemy_killed.is_connected(_on_enemy_killed):
		_bound_events.enemy_killed.disconnect(_on_enemy_killed)
	_bound_events = null


func _on_enemy_hit(enemy: Object, _hit: Object, _result: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var k: String = str(enemy.get("kind"))
	if not k.is_empty():
		record_bestiary_seen(k)


func _on_enemy_killed(_enemy: Object, kind: String, _pos: Vector2, _opened: bool) -> void:
	if not kind.is_empty():
		record_bestiary_defeated(kind)


# ---- Bestiary ----
func record_bestiary_seen(kind: String) -> void:
	if Lx.state == null or kind.is_empty():
		return
	var key: String = "bestiary:seen:" + kind
	Lx.state.story_flags[key] = int(Lx.state.story_flags.get(key, 0)) + 1


func record_bestiary_defeated(kind: String) -> void:
	if Lx.state == null or kind.is_empty():
		return
	var sk: String = "bestiary:seen:" + kind
	if int(Lx.state.story_flags.get(sk, 0)) <= 0:
		Lx.state.story_flags[sk] = 1
	var dk: String = "bestiary:defeated:" + kind
	Lx.state.story_flags[dk] = int(Lx.state.story_flags.get(dk, 0)) + 1


func get_bestiary_counts(kind: String) -> Vector2i:
	if Lx.state == null:
		return Vector2i.ZERO
	return Vector2i(
		int(Lx.state.story_flags.get("bestiary:seen:" + kind, 0)),
		int(Lx.state.story_flags.get("bestiary:defeated:" + kind, 0))
	)


# ---- Quests (flag graphs: fetch, carry_back, timed_delivery, hide_and_seek, light_view, trade_chain) ----
func all_quests() -> Array[Dictionary]:
	var qmap: Dictionary = LxFolkData.quests()
	var out: Array[Dictionary] = []
	for k: Variant in qmap.keys():
		if qmap[k] is Dictionary:
			out.append(qmap[k] as Dictionary)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ia: int = int(a.get("island", 0))
		var ib: int = int(b.get("island", 0))
		if ia != ib:
			return ia < ib
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return out


func get_quest(quest_id: String) -> Dictionary:
	return (LxFolkData.quests().get(quest_id, {}) as Dictionary)


func is_quest_done(quest_id: String) -> bool:
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get("quest:%s:done" % quest_id, false))


func is_quest_started(quest_id: String) -> bool:
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get("quest:%s:started" % quest_id, false)) or is_quest_done(quest_id)


func get_step_index(quest_id: String) -> int:
	if Lx.state == null:
		return 0
	return int(Lx.state.story_flags.get("quest:%s:step" % quest_id, 0))


func get_current_step(quest_id: String) -> Dictionary:
	var q: Dictionary = get_quest(quest_id)
	var steps: Array = q.get("steps", []) as Array
	if steps.is_empty():
		return {}
	var idx: int = clampi(get_step_index(quest_id), 0, steps.size() - 1)
	return steps[idx] as Dictionary if steps[idx] is Dictionary else {}


func get_active_bubble_icons(quest_id: String) -> Array[String]:
	var step: Dictionary = get_current_step(quest_id)
	var out: Array[String] = []
	var arr: Variant = step.get("icons", [])
	if arr is Array:
		for v: Variant in (arr as Array):
			out.append(str(v))
	return out


func has_flag(flag_name: String) -> bool:
	if flag_name.is_empty():
		return true
	if Lx.state == null:
		return false
	if flag_name.begins_with("!"):
		return not has_flag(flag_name.substr(1))
	if flag_name.begins_with("moths>="):
		return get_moth_count() >= int(flag_name.substr(7))
	return bool(Lx.state.story_flags.get(flag_name, false))


func set_flag(flag_name: String, val: Variant = true) -> void:
	if Lx.state == null or flag_name.is_empty():
		return
	Lx.state.story_flags[flag_name] = val


func grant_quest_item(item_id: String, carry: bool = false) -> void:
	set_flag("quest:item:" + item_id, true)
	if carry:
		set_flag("quest:carrying", item_id)


func has_quest_item(item_id: String) -> bool:
	return has_flag("quest:item:" + item_id)


func mark_light_view(view_id: String) -> void:
	set_flag("quest:view:" + view_id, true)


func mark_hide_found(spot_id: String) -> void:
	set_flag("quest:hide:" + spot_id, true)


func start_timed_delivery(quest_id: String, seconds: float) -> void:
	if Lx.state == null:
		return
	Lx.state.story_flags["quest:timer:" + quest_id] = maxf(1.0, seconds)
	Lx.state.story_flags["quest:%s:started" % quest_id] = true


func get_timer_left(quest_id: String) -> float:
	if Lx.state == null:
		return 0.0
	return float(Lx.state.story_flags.get("quest:timer:" + quest_id, 0.0))


func tick(dt: float) -> void:
	if Lx.state == null:
		return
	var expired: Array[String] = []
	for k: Variant in Lx.state.story_flags.keys():
		var ks: String = str(k)
		if ks.begins_with("quest:timer:"):
			var rem: float = float(Lx.state.story_flags[ks]) - dt
			if rem <= 0.0:
				expired.append(ks)
			else:
				Lx.state.story_flags[ks] = rem
	for ks: String in expired:
		Lx.state.story_flags.erase(ks)
		var qid: String = ks.substr(12)
		Lx.state.story_flags["quest:%s:expired" % qid] = true
		if Lx.events != null:
			Lx.events.narration_requested.emit("QUEST_TIMER_EXPIRED", "narration", 2.4)


func advance_quest(quest_id: String) -> Dictionary:
	## Attempts to start or advance quest_id along its step graph.
	## Returns {status: "started"|"advanced"|"completed"|"waiting"|"done", step: int, reward: Dictionary}.
	var q: Dictionary = get_quest(quest_id)
	if q.is_empty() or Lx.state == null:
		return {"status": "waiting", "step": 0, "reward": {}}
	if is_quest_done(quest_id):
		return {"status": "done", "step": get_step_index(quest_id), "reward": {}}

	var steps: Array = q.get("steps", []) as Array
	if steps.is_empty():
		return {"status": "waiting", "step": 0, "reward": {}}

	var was_started: bool = is_quest_started(quest_id)
	if not was_started:
		set_flag("quest:%s:started" % quest_id, true)
		var tlim: float = float(q.get("time_limit_s", 0.0))
		if tlim > 0.0:
			start_timed_delivery(quest_id, tlim)

	var idx: int = clampi(get_step_index(quest_id), 0, steps.size() - 1)
	var step: Dictionary = steps[idx] as Dictionary
	var need: String = str(step.get("need", ""))
	if not need.is_empty():
		var all_met: bool = true
		for part: String in need.split("&&"):
			if not has_flag(part.strip_edges()):
				all_met = false
				break
		if not all_met:
			# Retry timed delivery cleanly if its timer expired
			var tlim2: float = float(q.get("time_limit_s", 0.0))
			if tlim2 > 0.0 and get_timer_left(quest_id) <= 0.0:
				start_timed_delivery(quest_id, tlim2)
			return {"status": "started" if not was_started else "waiting", "step": idx, "reward": {}}

	# Timed delivery must be within time limit on final turn-in if time_limit_s > 0
	var tlim_chk: float = float(q.get("time_limit_s", 0.0))
	if tlim_chk > 0.0 and idx == steps.size() - 1 and get_timer_left(quest_id) <= 0.0 and not bool(Lx.state.story_flags.get("quest:%s:timer_ok" % quest_id, false)):
		start_timed_delivery(quest_id, tlim_chk)
		return {"status": "waiting", "step": idx, "reward": {}}

	var grant_f: String = str(step.get("flag", ""))
	if not grant_f.is_empty():
		set_flag(grant_f, true)
	var give_item: String = str(step.get("give_item", ""))
	if not give_item.is_empty():
		grant_quest_item(give_item, false)
	var take_item: String = str(step.get("consume_item", ""))
	if not take_item.is_empty():
		set_flag("quest:item:" + take_item, false)
		if str(Lx.state.story_flags.get("quest:carrying", "")) == take_item:
			Lx.state.story_flags.erase("quest:carrying")

	if idx + 1 >= steps.size():
		set_flag("quest:%s:done" % quest_id, true)
		Lx.state.story_flags.erase("quest:timer:" + quest_id)
		var reward: Dictionary = q.get("reward", {}) as Dictionary
		grant_reward(reward)
		var rescue_folk: String = str(q.get("rescue_folk", ""))
		if not rescue_folk.is_empty():
			set_flag("folk:" + rescue_folk, true)
		if Lx.events != null:
			Lx.events.save_requested.emit("quest_" + quest_id)
		return {"status": "completed", "step": idx, "reward": reward}

	set_flag("quest:%s:step" % quest_id, idx + 1)
	if Lx.events != null:
		Lx.events.save_requested.emit("quest_step_" + quest_id)
	return {"status": "advanced", "step": idx + 1, "reward": {}}


func grant_reward(reward: Dictionary) -> bool:
	if reward.is_empty() or Lx.state == null:
		return false
	var kind: String = str(reward.get("kind", ""))
	var val: String = str(reward.get("value", ""))
	var amt: int = maxi(1, int(reward.get("amount", 1)))
	match kind:
		"pane":
			return LxPanes.current().grant_pane(val)
		"ember_piece":
			for _i: int in range(amt):
				Lx.state.add_ember_piece()
			return true
		"moth":
			var mid: String = val if not val.is_empty() else "quest_bonus"
			set_flag("moth:" + mid, true)
			return true
		"lead":
			return LxPanes.current().add_lead(amt)
		"slot":
			return LxPanes.current().add_slot()
		"shards":
			Lx.state.add_shards(amt)
			return true
		"flame":
			var cname: String = val if LxPalette.is_valid_color(val) else "gold"
			set_flag("cosmetic:flame_" + cname, true)
			set_flag("cosmetic:flame", cname)
			return true
		_:
			return false


# ---- Lost Moths (80 total, 10 per island) & Wick House Moth Lantern Tiers ----
func catch_moth(moth_id: String) -> bool:
	if Lx.state == null or moth_id.is_empty():
		return false
	var key: String = "moth:" + moth_id
	if bool(Lx.state.story_flags.get(key, false)):
		return false
	Lx.state.story_flags[key] = true
	if Lx.events != null:
		Lx.events.save_requested.emit("moth_" + moth_id)
	return true


func is_moth_caught(moth_id: String) -> bool:
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get("moth:" + moth_id, false))


func get_moth_count() -> int:
	if Lx.state == null:
		return 0
	var count: int = 0
	for k: Variant in Lx.state.story_flags.keys():
		var ks: String = str(k)
		if ks.begins_with("moth:") and not ks.begins_with("moth:tier_") and bool(Lx.state.story_flags[ks]):
			count += 1
	return count


func get_moths_for_island(isl: int) -> Vector2i:
	var caught: int = 0
	var total: int = 0
	for md: Dictionary in LxFolkData.moths():
		if int(md.get("island", 0)) == isl:
			total += 1
			if is_moth_caught(str(md.get("id", ""))):
				caught += 1
	return Vector2i(caught, total)


func is_moth_tier_claimed(tier: int) -> bool:
	if Lx.state == null:
		return false
	return bool(Lx.state.story_flags.get("moth:tier_%d" % tier, false))


func claim_next_moth_tier() -> Dictionary:
	## Claims the lowest unclaimed Moth Lantern reward tier reached by current moth count.
	var count: int = get_moth_count()
	for td: Dictionary in LxFolkData.moth_tiers():
		var req: int = int(td.get("count", 0))
		if req <= 0 or count < req or is_moth_tier_claimed(req):
			continue
		set_flag("moth:tier_%d" % req, true)
		var reward: Dictionary = td.get("reward", {}) as Dictionary
		grant_reward(reward)
		if Lx.events != null:
			Lx.events.save_requested.emit("moth_tier_%d" % req)
		return td
	return {}
