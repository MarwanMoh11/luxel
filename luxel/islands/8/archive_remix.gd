class_name LxArchiveRemix
extends RefCounted
## Island 8 Archive of Night (Dungeon 2) Memory Remix Helpers & Dungeon Powers:
## 1. Defensively loads & reuses Islands 1..7 rule scripts for archive_1..archive_8
##    (guarded with ResourceLoader.exists + has_method so in-progress islands never crash).
## 2. Synchronizes Archive tide memory (`dungeon:archive` / `mem_tide`: "flood"|"ebb").
## 3. Brass Receipt (`item_brass_receipt`): throwing lantern onto a pressure_plate or
##    scale leaves a 6.0 s golden Receipt Stamp weight body (`is_weight_body() -> true`)
##    so Wick can recall the lantern while the plate stays weighted.
## 4. Bookmark Sigil (`item_bookmark`): pins decaying toys (timed_brazier, light_plant,
##    echo_rose, lantern_hook) active for 12.0 s.

const SCOPE_ARCHIVE: String = "dungeon:archive"
const VAR_MEM_TIDE: String = "mem_tide"
const FLAG_RECEIPT: String = "item_brass_receipt"
const FLAG_BOOKMARK: String = "item_bookmark"
const RECEIPT_DURATION_S: float = 6.0
const BOOKMARK_DURATION_S: float = 12.0
const STAMP_SEARCH_RADIUS: float = 28.0
const BOOKMARK_SEARCH_RADIUS: float = 34.0

const ISLAND_RULE_PATHS: Dictionary = {
	1: "res://luxel/islands/1/rule.gd",
	2: "res://luxel/islands/2/rule.gd",
	3: "res://luxel/islands/3/rule.gd",
	4: "res://luxel/islands/4/rule.gd",
	5: "res://luxel/islands/5/rule.gd",
	6: "res://luxel/islands/6/rule.gd",
	7: "res://luxel/islands/7/rule.gd",
}

const ARCHIVE_REGION_MAP: Dictionary = {
	"archive_1": [1],
	"archive_2": [2],
	"archive_3": [3],
	"archive_4": [4],
	"archive_5": [5],
	"archive_6": [6],
	"archive_7": [7],
	"archive_8": [2, 5, 7],
}

const PINNABLE_KINDS: Array[String] = [
	"timed_brazier", "light_plant", "echo_rose", "lantern_hook",
]

var _active_rules: Dictionary = {} # island_num: int -> RefCounted rule instance
var _guarded_missing: Array[int] = []
var _pinned_toys: Dictionary = {} # instance_id -> {toy, remaining, kind}
var _active_stamps: Array[LxInteractable] = []


func has_brass_receipt() -> bool:
	return Lx.state != null and bool(Lx.state.story_flags.get(FLAG_RECEIPT, false))


func grant_brass_receipt() -> void:
	if Lx.state != null:
		Lx.state.story_flags[FLAG_RECEIPT] = true


func has_bookmark() -> bool:
	return Lx.state != null and bool(Lx.state.story_flags.get(FLAG_BOOKMARK, false))


func grant_bookmark() -> void:
	if Lx.state != null:
		Lx.state.story_flags[FLAG_BOOKMARK] = true


func get_mem_tide() -> String:
	if Lx.vars != null:
		var v: String = str(Lx.vars.get_var(SCOPE_ARCHIVE, VAR_MEM_TIDE, "flood")).strip_edges().to_lower()
		if v == "flood" or v == "ebb":
			return v
	return "flood"


func set_mem_tide(val: String) -> void:
	var v: String = val.strip_edges().to_lower()
	if v != "flood" and v != "ebb":
		return
	if Lx.vars != null:
		Lx.vars.set_var(SCOPE_ARCHIVE, VAR_MEM_TIDE, v)
		# Mirror into Island 2 tide var when Island 2 memory remix is active.
		if _active_rules.has(2):
			Lx.vars.set_var("island:2", "tide", "high" if v == "flood" else "low")


func toggle_mem_tide() -> String:
	var next: String = "flood" if get_mem_tide() == "ebb" else "ebb"
	set_mem_tide(next)
	return next


func activate_for_region(region_id: String, region_data: Dictionary = {}) -> Dictionary:
	deactivate()
	var wanted: Array[int] = _resolve_remix_islands(region_id, region_data)
	_guarded_missing.clear()
	for isl_n: int in wanted:
		var ok: bool = _attach_island_rule_guarded(isl_n, region_id)
		if not ok:
			_guarded_missing.append(isl_n)
	if not wanted.is_empty() and Lx.vars != null:
		if str(Lx.vars.get_var(SCOPE_ARCHIVE, VAR_MEM_TIDE, "")) not in ["flood", "ebb"]:
			Lx.vars.set_var(SCOPE_ARCHIVE, VAR_MEM_TIDE, "flood")
	return {
		"active_islands": get_loaded_rule_islands(),
		"guarded_missing": _guarded_missing.duplicate(),
		"mem_tide": get_mem_tide(),
	}


func deactivate() -> void:
	for isl_n: Variant in _active_rules.keys():
		var rule_obj: Variant = _active_rules[isl_n]
		if rule_obj is Object and is_instance_valid(rule_obj) and (rule_obj as Object).has_method("detach"):
			(rule_obj as Object).call("detach")
	_active_rules.clear()
	_guarded_missing.clear()
	_pinned_toys.clear()
	_clear_stamps()


func get_loaded_rule_islands() -> Array[int]:
	var out: Array[int] = []
	for k: Variant in _active_rules.keys():
		out.append(int(k))
	out.sort()
	return out


func tick(dt: float) -> void:
	_tick_pins(dt)
	_tick_stamps(dt)


func try_stamp_at(world_pos: Vector2, force: bool = false) -> LxInteractable:
	if not force and not has_brass_receipt():
		return null
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_interactables"):
		return null
	var target: LxInteractable = null
	var best_d: float = STAMP_SEARCH_RADIUS
	var items_v: Variant = Lx.world.call("get_interactables")
	if items_v is Array:
		for it_v: Variant in (items_v as Array):
			if not (it_v is LxInteractable) or not is_instance_valid(it_v):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not it.active:
				continue
			if it.kind == "pressure_plate" or it.kind == "scale":
				var d: float = it.pos.distance_to(world_pos)
				if d <= best_d:
					best_d = d
					target = it
	if target == null:
		return null
	return spawn_receipt_stamp(target.pos, RECEIPT_DURATION_S)


func spawn_receipt_stamp(at_pos: Vector2, duration_s: float = RECEIPT_DURATION_S) -> LxInteractable:
	if Lx.world == null or not is_instance_valid(Lx.world):
		return null
	var stamp := _BrassReceiptStamp.new()
	var sid: String = "brass_receipt_%d" % Time.get_ticks_usec()
	stamp.region = Lx.world
	stamp.island_id = int(Lx.world.get("current_island_id")) if Lx.world.get("current_island_id") != null else 8
	stamp.region_id = str(Lx.world.get("current_region_id")) if Lx.world.get("current_region_id") != null else ""
	stamp.setup({
		"id": sid,
		"kind": "brass_receipt_stamp",
		"pos": [at_pos.x, at_pos.y],
		"props": {"weight": 1.0, "duration": duration_s},
	})
	var root_v: Variant = Lx.world.get("_interactables_root")
	if root_v is Node and is_instance_valid(root_v):
		(root_v as Node).add_child(stamp)
	else:
		Lx.world.add_child(stamp)
	var list_v: Variant = Lx.world.get("_interactables")
	if list_v is Array:
		(list_v as Array).append(stamp)
	_active_stamps.append(stamp)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("invoice_stamp", at_pos, true)
	return stamp


func try_bookmark_near(world_pos: Vector2, force: bool = false) -> LxInteractable:
	if not force and not has_bookmark():
		return null
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_interactables"):
		return null
	var best: LxInteractable = null
	var best_d: float = BOOKMARK_SEARCH_RADIUS
	var items_v: Variant = Lx.world.call("get_interactables")
	if items_v is Array:
		for it_v: Variant in (items_v as Array):
			if not (it_v is LxInteractable) or not is_instance_valid(it_v):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not it.active or not PINNABLE_KINDS.has(it.kind):
				continue
			var d: float = it.pos.distance_to(world_pos)
			if d <= best_d:
				best_d = d
				best = it
	if best == null:
		return null
	pin_toy(best, BOOKMARK_DURATION_S)
	return best


func pin_toy(toy: LxInteractable, duration_s: float = BOOKMARK_DURATION_S) -> bool:
	if toy == null or not is_instance_valid(toy) or not PINNABLE_KINDS.has(toy.kind):
		return false
	var iid: int = toy.get_instance_id()
	_pinned_toys[iid] = {
		"toy": toy,
		"kind": toy.kind,
		"remaining": maxf(0.5, duration_s),
	}
	_apply_pin_step(toy, duration_s)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("bookmark_pin", toy.pos, true)
	return true


func is_toy_pinned(toy: LxInteractable) -> bool:
	if toy == null or not is_instance_valid(toy):
		return false
	var iid: int = toy.get_instance_id()
	return _pinned_toys.has(iid) and float((_pinned_toys[iid] as Dictionary).get("remaining", 0.0)) > 0.0


func get_pinned_toys() -> Array[LxInteractable]:
	var out: Array[LxInteractable] = []
	for entry: Variant in _pinned_toys.values():
		if entry is Dictionary:
			var t: Variant = (entry as Dictionary).get("toy")
			if t is LxInteractable and is_instance_valid(t):
				out.append(t as LxInteractable)
	return out


func get_active_stamp_count() -> int:
	var n: int = 0
	for s: LxInteractable in _active_stamps:
		if s != null and is_instance_valid(s) and s.active:
			n += 1
	return n


func _apply_pin_step(toy: LxInteractable, rem: float) -> void:
	match toy.kind:
		"timed_brazier":
			if toy.get("lit") != null:
				toy.set("lit", true)
			if toy.get("time_left") != null:
				var secs_v: Variant = toy.get("secs")
				var hold_t: float = minf(rem, float(secs_v) if secs_v != null else 4.0)
				toy.set("time_left", maxf(float(toy.get("time_left")), maxf(0.4, hold_t)))
			if toy.has_method("set_powered"):
				toy.call("set_powered", true)
		"light_plant":
			if toy.has_method("frost_pin"):
				toy.call("frost_pin", rem)
			else:
				if toy.get("growth") != null:
					toy.set("growth", 1.0)
				if toy.has_method("set_powered"):
					toy.call("set_powered", true)
		"echo_rose":
			if toy.get("loop_replay") != null:
				toy.set("loop_replay", true)
			if toy.has_method("set_powered"):
				toy.call("set_powered", true)
		"lantern_hook":
			if toy.get("hooked") != null:
				toy.set("hooked", true)
			if toy.has_method("set_powered"):
				toy.call("set_powered", true)
	toy.queue_redraw()


func _tick_pins(dt: float) -> void:
	if _pinned_toys.is_empty():
		return
	var expired: Array[int] = []
	for iid_v: Variant in _pinned_toys.keys():
		var iid: int = int(iid_v)
		var entry: Dictionary = _pinned_toys[iid] as Dictionary
		var toy_v: Variant = entry.get("toy")
		if not (toy_v is LxInteractable) or not is_instance_valid(toy_v):
			expired.append(iid)
			continue
		var toy: LxInteractable = toy_v as LxInteractable
		var rem: float = float(entry.get("remaining", 0.0)) - dt
		entry["remaining"] = rem
		if rem <= 0.0:
			expired.append(iid)
		else:
			_apply_pin_step(toy, rem)
	for iid: int in expired:
		_pinned_toys.erase(iid)


func _tick_stamps(dt: float) -> void:
	if _active_stamps.is_empty():
		return
	for i: int in range(_active_stamps.size() - 1, -1, -1):
		var st: LxInteractable = _active_stamps[i]
		if st == null or not is_instance_valid(st):
			_active_stamps.remove_at(i)
			continue
		st.tick(dt)
		if not st.active:
			_remove_stamp(st)
			_active_stamps.remove_at(i)


func _clear_stamps() -> void:
	for st: LxInteractable in _active_stamps:
		if st != null and is_instance_valid(st):
			_remove_stamp(st)
	_active_stamps.clear()


func _remove_stamp(st: LxInteractable) -> void:
	if Lx.world != null and is_instance_valid(Lx.world):
		var list_v: Variant = Lx.world.get("_interactables")
		if list_v is Array:
			(list_v as Array).erase(st)
	st.queue_free()


func _resolve_remix_islands(region_id: String, region_data: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var raw_rem: Variant = region_data.get("remix_islands", region_data.get("remix_island", null))
	if raw_rem is int or raw_rem is float:
		var n: int = int(raw_rem)
		if n >= 1 and n <= 7:
			out.append(n)
	elif raw_rem is Array:
		for item: Variant in (raw_rem as Array):
			var n: int = int(item)
			if n >= 1 and n <= 7 and not out.has(n):
				out.append(n)
	if out.is_empty() and ARCHIVE_REGION_MAP.has(region_id):
		for item: Variant in (ARCHIVE_REGION_MAP[region_id] as Array):
			out.append(int(item))
	return out


func _attach_island_rule_guarded(isl_n: int, region_id: String) -> bool:
	var spath: String = str(ISLAND_RULE_PATHS.get(isl_n, ""))
	if spath.is_empty() or not ResourceLoader.exists(spath):
		return false
	var res: Resource = ResourceLoader.load(spath)
	if not (res is GDScript):
		return false
	var inst: Variant = (res as GDScript).new()
	if not (inst is Object):
		return false
	var obj: Object = inst as Object
	if obj.has_method("attach"):
		obj.call("attach", Lx.events, Lx.state)
	if obj.has_method("on_region_loaded"):
		obj.call("on_region_loaded", region_id)
	_active_rules[isl_n] = obj
	return true


## Lightweight golden Receipt Stamp interactable that acts as a weight body for 6.0 s.
class _BrassReceiptStamp:
	extends LxInteractable

	var remaining: float = RECEIPT_DURATION_S
	var total_dur: float = RECEIPT_DURATION_S

	func setup(spec: Dictionary) -> void:
		super.setup(spec)
		total_dur = maxf(0.5, float(props.get("duration", RECEIPT_DURATION_S)))
		remaining = total_dur
		radius = 8.0
		z_index = 2

	func is_weight_body() -> bool:
		return active and remaining > 0.0

	func tick(dt: float) -> void:
		super.tick(dt)
		if not active:
			return
		remaining -= dt
		if remaining <= 0.0:
			remaining = 0.0
			active = false
		queue_redraw()

	func get_light_pool() -> Vector4:
		if not active:
			return Vector4.ZERO
		return Vector4(pos.x, pos.y, 24.0, 0.55)

	func _draw() -> void:
		if not active:
			return
		var frac: float = clampf(remaining / maxf(0.01, total_dur), 0.0, 1.0)
		var void_c: Color = PAL["void"] as Color
		var gold: Color = PAL["gold"] as Color
		var cream: Color = PAL["cream"] as Color
		var apricot: Color = PAL["apricot"] as Color
		draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), void_c)
		draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), apricot)
		draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), gold)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), cream)
		draw_arc(Vector2.ZERO, 7.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 14, cream, 1.0)
