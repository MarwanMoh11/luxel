class_name LxEclipseSealGate
extends LxToy
## Island 8 Sanctum Forecourt — THE TRIPLE ECLIPSE SEAL.
## Guards the Bell Sanctum cathedral entrance until all 3 Island 8 wings are cleared:
##   1) The Toll House (`toll_cleared` / `dungeon_done:toll_house`)
##   2) The Archive of Lost Lamps (`archive_cleared` / `dungeon_done:archive`)
##   3) The Endless Stair (`stair_cleared` / `dungeon_done:endless_stair`)
## Legacy saves that already entered Bell Sanctum (`isl8_sanctum_entered`, `ws_sanctum`,
## `great_lamp_8`, `boss_the_hush_defeated`, `island_8_relit`) stay passed automatically.
## While any of the 3 wings is still debug_only/unmerged during parallel construction,
## falls back cleanly to the 3 overworld beacons (`beacon_8_1..3`) so the island never softlocks.

const WING_DUNGEONS: Array[Dictionary] = [
	{"id": "toll_house", "flag": "toll_cleared", "col": "gold"},
	{"id": "archive", "flag": "archive_cleared", "col": "sky"},
	{"id": "endless_stair", "flag": "stair_cleared", "col": "rose"},
]

var opened: bool = false
var target_door_id: String = "door_triple_eclipse_seal"
var _open_t: float = 0.0
var _rattle_t: float = 0.0
var _lit_pips: Array[bool] = [false, false, false]


func _toy_setup() -> void:
	kind = "eclipse_seal_gate"
	size = LxMapFormat.to_vec2(props.get("size", [64.0, 16.0]), Vector2(64.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5 + 12.0
	persist = bool(props.get("persist", true))
	target_door_id = str(props.get("target_door_id", "door_triple_eclipse_seal"))
	opened = bool(props.get("opened", false))
	if Lx.state != null and not id.is_empty() and (Lx.state.opened_doors.has(id) or Lx.state.broken_seals.has(id)):
		opened = true
	_sync_door_policy()
	_evaluate(false)
	queue_redraw()


func _find_target_door() -> Node:
	if region == null or target_door_id.is_empty():
		return null
	if region.has_method("get_interactable"):
		var found: Variant = region.call("get_interactable", target_door_id)
		if found is Node:
			return found as Node
	return null


func _sync_door_policy() -> void:
	var door: Node = _find_target_door()
	if door == null:
		return
	if _is_legacy_passed() or opened:
		if door.has_method("_open") and not bool(door.get("opened")):
			door.call("_open", persist)
		return
	if _all_three_wings_live():
		var reqs: Array[String] = ["toll_cleared", "archive_cleared", "stair_cleared"]
		door.set("required_flags", reqs)
	else:
		var fallback: Array[String] = ["beacon_8_1", "beacon_8_2", "beacon_8_3"]
		door.set("required_flags", fallback)


func tick(dt: float) -> void:
	super.tick(dt)
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt)
		queue_redraw()
	if _rattle_t > 0.0:
		_rattle_t = maxf(0.0, _rattle_t - dt)
		queue_redraw()
	if active and not opened:
		_evaluate(true)


func interact(_actor: Node = null) -> bool:
	if not active or opened:
		return false
	if _requirements_met():
		_shatter_seal(true)
		return true
	_rattle_t = 0.28
	_emit_sfx("door_locked")
	if Lx.events != null and LxStrings.has_id("ISL8_SEAL_NEEDS_THREE"):
		Lx.events.narration_requested.emit("ISL8_SEAL_NEEDS_THREE", "narration", 3.2)
	queue_redraw()
	return false


func get_interact_prompt() -> String:
	return "" if (not active or opened) else "ISL8_PROMPT_ECLIPSE_SEAL"


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 56.0 if opened else 44.0, 0.85 if opened else 0.65)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	d["opened"] = opened
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	opened = bool(d.get("opened", opened))
	_evaluate(false)
	queue_redraw()


func _is_legacy_passed() -> bool:
	if Lx.state == null:
		return false
	if Lx.state.relit_islands.has(8) or Lx.state.defeated_bosses.has("the_hush"):
		return true
	if Lx.state.lit_waystones.has("ws_sanctum"):
		return true
	for fl: String in ["isl8_sanctum_entered", "great_lamp_8", "island_8_relit", "boss_the_hush_defeated", "triple_eclipse_broken"]:
		if bool(Lx.state.story_flags.get(fl, false)):
			return true
	return false


func _all_three_wings_live() -> bool:
	if Lx.packs == null:
		return false
	for w: Dictionary in WING_DUNGEONS:
		var meta: Dictionary = Lx.packs.dungeon(str(w["id"]))
		if meta.is_empty() or bool(meta.get("debug_only", false)):
			return false
	return true


func _wing_done(w: Dictionary) -> bool:
	var fl: String = str(w["flag"])
	var did: String = str(w["id"])
	return LxRegionLoader.check_flag_static(fl) or LxRegionLoader.check_flag_static("dungeon_done:" + did)


func _beacons_done() -> bool:
	return LxRegionLoader.check_flag_static("beacon_8_1") \
		and LxRegionLoader.check_flag_static("beacon_8_2") \
		and LxRegionLoader.check_flag_static("beacon_8_3")


func _requirements_met() -> bool:
	if _is_legacy_passed():
		return true
	var done_all: bool = true
	for i: int in range(WING_DUNGEONS.size()):
		var ok: bool = _wing_done(WING_DUNGEONS[i])
		_lit_pips[i] = ok
		if not ok:
			done_all = false
	if done_all:
		return true
	if not _all_three_wings_live():
		return _beacons_done()
	return false


func _evaluate(play_fx: bool) -> void:
	if opened:
		_lit_pips = [true, true, true]
		return
	if _requirements_met():
		_shatter_seal(play_fx)


func _shatter_seal(play_fx: bool) -> void:
	if opened:
		return
	opened = true
	powered = true
	_lit_pips = [true, true, true]
	_open_t = 0.60 if play_fx else 0.0
	if Lx.state != null:
		Lx.state.story_flags["triple_eclipse_broken"] = true
		if persist and not id.is_empty():
			if not Lx.state.opened_doors.has(id):
				Lx.state.opened_doors.append(id)
			if not Lx.state.broken_seals.has(id):
				Lx.state.broken_seals.append(id)
	var door: Node = _find_target_door()
	if door != null and door.has_method("_open") and not bool(door.get("opened")):
		door.call("_open", persist)
	emit_power(true)
	if play_fx:
		_emit_sfx("seal_break")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.24 * (0.45 if LxHudFx.flash_reduced() else 1.0))
			if LxStrings.has_id("ISL8_SEAL_SHATTER"):
				Lx.events.narration_requested.emit("ISL8_SEAL_SHATTER", "title", 3.4)
			Lx.events.save_requested.emit("triple_eclipse_broken")
	queue_redraw()


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var fred: bool = LxHudFx.flash_reduced()
	var rdx: float = (1.0 if int(floorf(_rattle_t * 36.0)) % 2 == 0 else -1.0) if (_rattle_t > 0.0 and LxHudFx.shake_enabled() and not fred) else 0.0
	var x0: float = floorf(-w * 0.5) + rdx
	var y0: float = floorf(-h * 0.5)
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color

	if opened:
		# Parted obsidian cathedral jambs with lit gold trim & raised open finials
		draw_rect(Rect2(x0, y0, 6.0, h), void_c)
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, 4.0, h - 2.0), dusk)
		draw_rect(Rect2(x0 + 4.0, y0 + 1.0, 1.0, h - 2.0), gold)
		draw_rect(Rect2(x0 + 2.0, y0 - 2.0, 2.0, 2.0), cream)
		draw_rect(Rect2(x0 + w - 6.0, y0, 6.0, h), void_c)
		draw_rect(Rect2(x0 + w - 5.0, y0 + 1.0, 4.0, h - 2.0), dusk)
		draw_rect(Rect2(x0 + w - 5.0, y0 + 1.0, 1.0, h - 2.0), gold)
		draw_rect(Rect2(x0 + w - 4.0, y0 - 2.0, 2.0, 2.0), cream)
		if _open_t > 0.0:
			var u: float = 1.0 - clampf(_open_t / 0.60, 0.0, 1.0)
			var oa: float = (1.0 - u) * (0.55 if fred else 0.95)
			draw_arc(Vector2.ZERO, roundf(8.0 + u * 28.0), 0.0, TAU, 20, Color(cream, oa), 1.0 if fred else 2.0)
		return

	# Sealed Triple Eclipse Barrier
	draw_rect(Rect2(x0, y0 + h, w, 2.0), void_c)
	draw_rect(Rect2(x0, y0, w, h), void_c)
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), night)
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0), dusk)
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, 1.0), PAL["mauve"] as Color)

	# Three Eclipse Medallions: Toll (Gold), Archive (Sky), Stair (Rose)
	# Lit = raised crown spark + bright cross core; Unlit = recessed barred cavity (greyscale-legible)
	for i: int in range(3):
		var mx: float = roundf(float(i - 1) * 14.0 + rdx)
		var col: Color = PAL[str(WING_DUNGEONS[i]["col"])] as Color
		var lit_m: bool = _lit_pips[i]
		draw_rect(Rect2(mx - 4.0, -4.0, 8.0, 8.0), void_c)
		if lit_m:
			draw_rect(Rect2(mx - 1.0, -6.0, 2.0, 2.0), cream)
			draw_rect(Rect2(mx - 3.0, -3.0, 6.0, 6.0), col)
			draw_rect(Rect2(mx - 2.0, -1.0, 4.0, 2.0), cream)
			draw_rect(Rect2(mx - 1.0, -2.0, 2.0, 4.0), cream)
		else:
			draw_rect(Rect2(mx - 3.0, -3.0, 6.0, 6.0), night)
			draw_rect(Rect2(mx - 3.0, -1.0, 6.0, 2.0), void_c)
			draw_rect(Rect2(mx - 1.0, -1.0, 2.0, 1.0), dusk)
