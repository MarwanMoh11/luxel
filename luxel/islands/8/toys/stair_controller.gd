class_name LxStairController
extends LxToy
## Island 8 Endless Stair Controller — manages a floor's seeded room pool layer,
## combat-clear detection, 3-pedestal Boon Draft, and unlocking the floor exit.
## Props: tier (1|2|3), floor_range ([a,b]), pool_layers (Array), boon_count (int, default 3),
##        target_exit_id (String), target_id / target_ids, seed (int), include_legendary (bool).
## States: COMBAT_ACTIVE -> BOON_DRAFT -> FLOOR_DONE.

enum State { COMBAT_ACTIVE, BOON_DRAFT, FLOOR_DONE }

var tier: int = 1
var floor_range: Vector2i = Vector2i(1, 4)
var pool_layers: Array[String] = []
var boon_count: int = 3
var target_exit_id: String = ""
var seed_val: int = 0
var include_legendary: bool = false

var state: int = State.COMBAT_ACTIVE
var active_floor: int = 1
var active_template: Dictionary = {}
var draft_options: Array[Dictionary] = []
var selected_boon_idx: int = 0
var chosen_boon_id: String = ""
var _local_director: LxStairDirector = null


func _toy_setup() -> void:
	tier = clampi(int(props.get("tier", 1)), 1, 3)
	var fr_v: Variant = props.get("floor_range", [1, 4])
	if fr_v is Array and (fr_v as Array).size() >= 2:
		floor_range = Vector2i(maxi(1, int((fr_v as Array)[0])), maxi(1, int((fr_v as Array)[1])))
	pool_layers.clear()
	var pl_v: Variant = props.get("pool_layers", [])
	if pl_v is Array:
		for p: Variant in (pl_v as Array):
			pool_layers.append(str(p))
	boon_count = clampi(int(props.get("boon_count", 3)), 1, 3)
	target_exit_id = str(props.get("target_exit_id", "")).strip_edges()
	seed_val = int(props.get("seed", 0))
	include_legendary = bool(props.get("include_legendary", false))
	radius = 28.0

	var dir: LxStairDirector = _get_director()
	var next_floor: int = maxi(floor_range.x, dir.get_floor())
	if next_floor > floor_range.y:
		next_floor = floor_range.x
	active_floor = next_floor
	if dir.get_floor() <= 0:
		dir.start_run(seed_val if seed_val != 0 else 8080, active_floor)
	active_template = dir.pick_floor_template(active_floor, pool_layers, seed_val)
	if Lx.vars != null and active_template.has("pool_layer"):
		Lx.vars.set_var(LxStairDirector.SCOPE_STAIR, "stair_layer", str(active_template["pool_layer"]))
	state = State.COMBAT_ACTIVE
	queue_redraw()


func get_state_name() -> String:
	match state:
		State.BOON_DRAFT: return "BOON_DRAFT"
		State.FLOOR_DONE: return "FLOOR_DONE"
		_: return "COMBAT_ACTIVE"


func get_draft_options() -> Array[Dictionary]:
	return draft_options.duplicate(true)


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if state == State.COMBAT_ACTIVE:
		if _live_enemy_count() == 0:
			_enter_boon_draft()
	elif state == State.BOON_DRAFT:
		# Auto-highlight whichever pedestal Wick stands closest to.
		var wp: Vector2 = wick_pos()
		var best_i: int = selected_boon_idx
		var best_d: float = 9999.0
		for i: int in range(draft_options.size()):
			var d: float = (pos + _pedestal_offset(i)).distance_to(wp)
			if d < best_d:
				best_d = d
				best_i = i
		if best_i != selected_boon_idx:
			selected_boon_idx = best_i
			queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	if state == State.COMBAT_ACTIVE:
		if _live_enemy_count() == 0:
			_enter_boon_draft()
			return true
		_emit_sfx("door_locked")
		return false
	if state == State.BOON_DRAFT:
		return pick_boon(selected_boon_idx)
	if state == State.FLOOR_DONE:
		emit_power(true)
		_signal_exit_target()
		return true
	return false


func pick_boon(index_or_id: Variant) -> bool:
	if state != State.BOON_DRAFT or draft_options.is_empty():
		return false
	var chosen: Dictionary = {}
	if index_or_id is int:
		var idx: int = clampi(int(index_or_id), 0, draft_options.size() - 1)
		chosen = draft_options[idx]
	else:
		var target_id: String = str(index_or_id).strip_edges().to_lower()
		for b: Dictionary in draft_options:
			if str(b.get("id", "")) == target_id:
				chosen = b
				break
		if chosen.is_empty():
			chosen = draft_options[0]
	var bid: String = str(chosen.get("id", ""))
	var dir: LxStairDirector = _get_director()
	dir.grant_boon(bid)
	dir.complete_floor(active_floor)
	chosen_boon_id = bid
	state = State.FLOOR_DONE
	set_powered(true)
	emit_power(true)
	_signal_exit_target()
	if Lx.events != null:
		Lx.events.sfx_requested.emit("boon_draft", pos, true)
		var nk: String = str(chosen.get("name_key", ""))
		if not nk.is_empty() and LxStrings.has_id(nk):
			Lx.events.narration_requested.emit(nk, "title", 2.4)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	if not active:
		return ""
	if state == State.BOON_DRAFT:
		return "ISL8_PROMPT_BOON_PICK"
	return ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if state == State.BOON_DRAFT:
		return Vector4(pos.x, pos.y, 56.0, 0.85)
	if state == State.FLOOR_DONE:
		return Vector4(pos.x, pos.y, 40.0, 0.65)
	return Vector4(pos.x, pos.y, 26.0, 0.42)


func _enter_boon_draft() -> void:
	if state != State.COMBAT_ACTIVE:
		return
	var dir: LxStairDirector = _get_director()
	draft_options = dir.roll_boon_draft(boon_count, include_legendary, seed_val)
	selected_boon_idx = 0
	state = State.BOON_DRAFT
	_emit_sfx("boon_draft")
	queue_redraw()


func _signal_exit_target() -> void:
	if target_exit_id.is_empty() or region == null or not region.has_method("find_interactable"):
		return
	var tgt: Variant = region.call("find_interactable", target_exit_id)
	if tgt is LxInteractable:
		(tgt as LxInteractable).on_signal(id, true)


func _get_director() -> LxStairDirector:
	if LxIsland8Rule.active_instance != null and LxIsland8Rule.active_instance.stair != null:
		return LxIsland8Rule.active_instance.stair
	if _local_director == null:
		_local_director = LxStairDirector.new()
	return _local_director


func _live_enemy_count() -> int:
	if region == null or not is_instance_valid(region) or not region.has_method("get_enemies"):
		return 0
	var arr: Variant = region.call("get_enemies")
	if not (arr is Array):
		return 0
	var count: int = 0
	for ev: Variant in (arr as Array):
		if ev is Node2D and is_instance_valid(ev):
			var en: Node2D = ev as Node2D
			if en.has_method("is_dead") and bool(en.call("is_dead")):
				continue
			if en.visible and not (en.get("dead") == true):
				count += 1
	return count


func _pedestal_offset(idx: int) -> Vector2:
	var n: int = maxi(1, draft_options.size())
	var span: float = float(n - 1) * 26.0
	return Vector2(roundf(-span * 0.5 + float(idx) * 26.0), 0.0)


func _draw() -> void:
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var sky: Color = PAL["sky"] as Color
	var lime: Color = PAL["lime"] as Color
	var fred: bool = LxHudFx.flash_reduced()

	if state == State.COMBAT_ACTIVE:
		# Recessed sealed stair medallion with flanking lock bars (greyscale-distinct)
		draw_rect(Rect2(-10.0, -6.0, 20.0, 12.0), void_c)
		draw_rect(Rect2(-9.0, -5.0, 18.0, 10.0), night)
		draw_rect(Rect2(-7.0, -3.0, 14.0, 6.0), dusk)
		draw_rect(Rect2(-9.0, -1.0, 2.0, 2.0), void_c)
		draw_rect(Rect2(7.0, -1.0, 2.0, 2.0), void_c)
		LxPixelFont.draw_centered(self, "F%d" % active_floor, 0.0, -2.0, gold, 1, void_c)
		return

	if state == State.BOON_DRAFT:
		# 3 raised brass Boon Pedestals with selection chevron + greyscale-distinct group crests
		var bob: float = 0.0 if fred else roundf(sin(_clock * 4.0) * 1.0)
		for i: int in range(draft_options.size()):
			var b: Dictionary = draft_options[i]
			var off: Vector2 = _pedestal_offset(i)
			var sel: bool = (i == selected_boon_idx)
			var grp: String = str(b.get("group", "WICK"))
			var gcol: Color = gold if grp == "TOLL" else (sky if grp == "LANTERN" else lime)
			draw_rect(Rect2(off.x - 9.0, off.y - 6.0, 18.0, 12.0), void_c)
			draw_rect(Rect2(off.x - 8.0, off.y - 5.0, 16.0, 10.0), cream if sel else dusk)
			draw_rect(Rect2(off.x - 7.0, off.y - 4.0, 14.0, 8.0), night)
			# Group-distinct top jewel silhouette (TOLL = wide bar, LANTERN = diamond, WICK = tall flame)
			if grp == "TOLL":
				draw_rect(Rect2(off.x - 4.0, off.y - 10.0, 8.0, 4.0), void_c)
				draw_rect(Rect2(off.x - 3.0, off.y - 9.0, 6.0, 2.0), cream if sel else gcol)
			elif grp == "LANTERN":
				draw_rect(Rect2(off.x - 3.0, off.y - 10.0, 6.0, 4.0), void_c)
				draw_rect(Rect2(off.x - 2.0, off.y - 9.0, 4.0, 2.0), cream if sel else gcol)
				draw_rect(Rect2(off.x - 1.0, off.y - 11.0, 2.0, 6.0), cream if sel else gcol)
			else:
				draw_rect(Rect2(off.x - 2.0, off.y - 11.0, 4.0, 5.0), void_c)
				draw_rect(Rect2(off.x - 1.0, off.y - 10.0, 2.0, 3.0), cream if sel else gcol)
			if sel:
				var cy: float = off.y - 14.0 + bob
				draw_rect(Rect2(off.x - 2.0, cy, 4.0, 1.0), cream)
				draw_rect(Rect2(off.x - 1.0, cy + 1.0, 2.0, 1.0), cream)
			LxPixelFont.draw_centered(self, grp.left(3), off.x, off.y - 2.0, cream if sel else gcol, 1, void_c)
		return

	# FLOOR_DONE: lit stair seal with 4 cardinal corner sparks
	draw_rect(Rect2(-10.0, -6.0, 20.0, 12.0), void_c)
	draw_rect(Rect2(-9.0, -5.0, 18.0, 10.0), gold)
	draw_rect(Rect2(-8.0, -4.0, 16.0, 8.0), night)
	draw_rect(Rect2(-9.0, -5.0, 2.0, 2.0), cream)
	draw_rect(Rect2(7.0, -5.0, 2.0, 2.0), cream)
	draw_rect(Rect2(-9.0, 3.0, 2.0, 2.0), cream)
	draw_rect(Rect2(7.0, 3.0, 2.0, 2.0), cream)
	LxPixelFont.draw_centered(self, "OK", 0.0, -2.0, cream, 1, void_c)
	_draw_signal_pulses()
