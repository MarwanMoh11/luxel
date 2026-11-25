extends SceneTree
## Headless verification of Endless Stair mechanics:
## 1) Floors stay varied across two full climbs (all 5 pool slots switch layers Climb 1 -> Climb 2)
## 2) All 18 boons exist, draft cleanly, and visibly/mechanically modify play
## 3) Express Lifts F4/F8/F12, Iron Ascent multiplier, and combat-death return to last lift (never start)

var _fails: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
		push_error("STAIR_VERIFY FAIL: " + msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Lx.load_all_data()
	Lx.state = LxGameState.new()
	Lx.events = LxEventBus.new()
	Lx.vars = LxWorldState.new()
	var sold: LxSold = LxSold.current()
	sold.restore_all("reset", false)

	var dir := LxStairDirector.new()

	# 1. Two full climbs pool variety check
	var slots: Array[Dictionary] = [
		{"floor": 1, "pool": ["stair_a1", "stair_a2"]},
		{"floor": 3, "pool": ["stair_a3", "stair_a4"]},
		{"floor": 5, "pool": ["stair_b1", "stair_b2"]},
		{"floor": 7, "pool": ["stair_b3", "stair_b4"]},
		{"floor": 9, "pool": ["stair_c1", "stair_c2", "stair_c3", "stair_c4"]},
	]
	dir.start_new_climb(false, 0)
	var climb1: Array[String] = []
	for s: Dictionary in slots:
		var t: Dictionary = dir.pick_floor_template(int(s["floor"]), s["pool"] as Array, 0)
		climb1.append(str(t.get("pool_layer", "")))

	dir.start_new_climb(true, 0)
	var climb2: Array[String] = []
	for s: Dictionary in slots:
		var t: Dictionary = dir.pick_floor_template(int(s["floor"]), s["pool"] as Array, 0)
		climb2.append(str(t.get("pool_layer", "")))

	var diffs: int = 0
	for i: int in range(slots.size()):
		if climb1[i] != climb2[i]:
			diffs += 1
	_check(diffs == slots.size(), "Two full climbs varied on every pool slot: climb1=%s climb2=%s" % [str(climb1), str(climb2)])

	# 2. All 18 boons catalog + live stat modifiers + immediate effects
	_check(LxStairDirector.BOON_CATALOG.size() == 18, "18 boons in BOON_CATALOG")
	_check(LxStairDirector.ROOM_TEMPLATES.size() == 12, "12 templates in ROOM_TEMPLATES")
	sold.sell("sound_off", {"save": false})
	sold.sell("palette_4", {"save": false})
	sold.sell("fps_step", {"save": false})
	Lx.state.max_hearts = 6
	Lx.state.hearts = 4.0
	for b: Dictionary in LxStairDirector.BOON_CATALOG:
		_check(dir.grant_boon(str(b["id"])), "grant_boon(%s)" % str(b["id"]))
	_check(dir.get_boons().size() == 18, "All 18 boons granted cleanly")
	_check(Lx.state.hearts >= 5.0, "boon_borrow_heart healed +1 heart immediately")
	_check(dir.modify_stair_stat("bolt_damage", 1.0, {"opened": true}) > 2.5, "Stacked damage boons significantly amplify bolt_damage")
	_check(dir.modify_stair_stat("move_speed", 1.0) > 1.4, "Quick Step + Crowned Toll boost move_speed")
	_check(dir.modify_stair_stat("ember_rate", 1.0) > 1.2, "Ember Sip boosts ember_rate")
	_check(dir.modify_stair_stat("throw_range", 1.0) > 1.25, "Long Throw boosts throw_range")
	_check(dir.modify_stair_stat("lens_radius", 1.0) > 1.3, "Wide Lens boosts lens_radius")
	_check(dir.modify_stair_stat("dash_cooldown", 1.0) < 0.85, "Frame Blink reduces dash_cooldown when fps_step sold")
	_check(dir.is_last_breath_armed() and dir.try_consume_last_breath() and not dir.try_consume_last_breath(), "Last Breath arms and triggers once per climb")

	# 3. Express Lifts + Iron Ascent score + Dying returns to last lift (never start)
	var sc4: Dictionary = dir.complete_floor(4)
	_check(dir.is_lift_unlocked(4), "Lift F4 unlocked")
	_check(is_equal_approx(float(sc4["multiplier"]), 1.45), "Iron Ascent mult == 1.45x with 3 sold settings")
	dir.on_region_changed(8, "stair_r5") # Floor 5..6
	var boons_before: int = dir.get_boons().size()
	Lx.events.player_died.emit()
	var cp4: Dictionary = dir.get_last_lift_checkpoint()
	_check(int(cp4.get("floor", 0)) == 4 and str(cp4.get("region", "")) == "stair_r4", "Dying at F5-6 returns to Lift F4 (stair_r4), never stair_r1")
	_check(dir.get_boons().size() == boons_before, "Dying in Endless Stair preserves drafted boons")

	dir.complete_floor(8)
	_check(dir.is_lift_unlocked(8), "Lift F8 unlocked")
	dir.on_region_changed(8, "stair_r9") # Floor 9..11
	Lx.events.player_died.emit()
	var cp8: Dictionary = dir.get_last_lift_checkpoint()
	_check(int(cp8.get("floor", 0)) == 8 and str(cp8.get("region", "")) == "stair_r8", "Dying at F9-11 returns to Lift F8 (stair_r8), never stair_r1")

	var sc12: Dictionary = dir.complete_floor(12)
	_check(dir.is_lift_unlocked(12) and dir.get_best_floor() == 12 and dir.get_best_score() >= int(sc12["score"]), "F12 unlocks Lift F12 and saves Iron Ascent best")

	# Leaving to stair_landing clears run boons while preserving Express Lifts!
	dir.on_region_changed(8, "stair_landing")
	_check(dir.get_boons().is_empty() and dir.get_floor() == 0, "Leaving to stair_landing clears run boons & floor")
	_check(dir.is_lift_unlocked(4) and dir.is_lift_unlocked(8) and dir.is_lift_unlocked(12), "All 3 Express Lifts persist after leaving")

	sold.restore_all("reset", false)
	if _fails.is_empty():
		print("STAIR_VERIFY PASS: climb1=%s climb2=%s boons=18 lifts=F4/F8/F12 death_return=last_lift score_f12=%d mult=%.2fx" % [
			",".join(climb1), ",".join(climb2), int(sc12["score"]), float(sc12["multiplier"])
		])
		quit(0)
	else:
		print("STAIR_VERIFY FAIL (%d):" % _fails.size())
		for f: String in _fails:
			print("  - " + f)
		quit(1)
