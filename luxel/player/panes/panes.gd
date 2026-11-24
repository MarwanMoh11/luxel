class_name LxPanes
extends RefCounted
## Stained-glass lantern pane build system (32 panes, 4 per island theme).
## Persists owned, equipped, slots (3..5), and lead budget inside Lx.state.story_flags
## under "panes:" keys until E0-1 adds dedicated fields on LxGameState.

const MIN_SLOTS: int = 3
const MAX_SLOTS: int = 5
const DEFAULT_MAX_LEAD: int = 6
const MAX_LEAD_CAP: int = 10

const FLAG_OWNED: String = "panes:owned"
const FLAG_EQUIPPED: String = "panes:equipped"
const FLAG_SLOTS: String = "panes:slots"
const FLAG_MAX_LEAD: String = "panes:max_lead"

const STAT_BOUNDS: Dictionary = {
	"bolt_damage": [0.15, 2.50],
	"bolt_cooldown": [0.08, 0.45],
	"bolt_range": [56.0, 220.0],
	"bolt_speed": [180.0, 560.0],
	"move_speed": [64.0, 138.0],
	"dash_cooldown": [0.22, 1.15],
	"throw_range": [64.0, 190.0],
	"throw_speed": [200.0, 520.0],
	"throw_damage": [0.80, 5.00],
	"recall_speed": [260.0, 640.0],
	"hang_time": [1.50, 9.00],
	"light_radius": [48.0, 165.0],
	"ember_gain": [0.35, 2.50],
	"recoil": [0.0, 180.0],
}

const PANE_SCRIPTS: Dictionary = {
	# Island 1: Bell Isle
	"bell_clapper": preload("res://luxel/player/panes/p_bell_clapper.gd"),
	"vesper_chime": preload("res://luxel/player/panes/p_vesper_chime.gd"),
	"toll_echo": preload("res://luxel/player/panes/p_toll_echo.gd"),
	"belfry_weight": preload("res://luxel/player/panes/p_belfry_weight.gd"),
	# Island 2: Tidewater Harbor
	"rip_tide": preload("res://luxel/player/panes/p_rip_tide.gd"),
	"sea_glass": preload("res://luxel/player/panes/p_sea_glass.gd"),
	"harbor_wake": preload("res://luxel/player/panes/p_harbor_wake.gd"),
	"anchor_lead": preload("res://luxel/player/panes/p_anchor_lead.gd"),
	# Island 3: Thornwood Hollow
	"ember_seed": preload("res://luxel/player/panes/p_ember_seed.gd"),
	"briar_thorn": preload("res://luxel/player/panes/p_briar_thorn.gd"),
	"vine_snare": preload("res://luxel/player/panes/p_vine_snare.gd"),
	"canopy_dew": preload("res://luxel/player/panes/p_canopy_dew.gd"),
	# Island 4: Mirefen Gardens
	"hourglass_sand": preload("res://luxel/player/panes/p_hourglass_sand.gd"),
	"petal_mirror": preload("res://luxel/player/panes/p_petal_mirror.gd"),
	"dusk_dew": preload("res://luxel/player/panes/p_dusk_dew.gd"),
	"rain_prism": preload("res://luxel/player/panes/p_rain_prism.gd"),
	# Island 5: Starfall Observatory
	"orbit_shard": preload("res://luxel/player/panes/p_orbit_shard.gd"),
	"comet_tail": preload("res://luxel/player/panes/p_comet_tail.gd"),
	"zenith_lens": preload("res://luxel/player/panes/p_zenith_lens.gd"),
	"null_well": preload("res://luxel/player/panes/p_null_well.gd"),
	# Island 6: Ashen Kiln
	"cinder_blast": preload("res://luxel/player/panes/p_cinder_blast.gd"),
	"slag_coat": preload("res://luxel/player/panes/p_slag_coat.gd"),
	"bellows_vent": preload("res://luxel/player/panes/p_bellows_vent.gd"),
	"anvil_strike": preload("res://luxel/player/panes/p_anvil_strike.gd"),
	# Island 7: Moon Shoals
	"silver_twin": preload("res://luxel/player/panes/p_silver_twin.gd"),
	"moon_phase": preload("res://luxel/player/panes/p_moon_phase.gd"),
	"glass_step": preload("res://luxel/player/panes/p_glass_step.gd"),
	"mirror_ward": preload("res://luxel/player/panes/p_mirror_ward.gd"),
	# Island 8: The Long Night
	"toll_wick": preload("res://luxel/player/panes/p_toll_wick.gd"),
	"hush_glass": preload("res://luxel/player/panes/p_hush_glass.gd"),
	"dawn_spark": preload("res://luxel/player/panes/p_dawn_spark.gd"),
	"last_glass": preload("res://luxel/player/panes/p_last_glass.gd"),
}

const ORDERED_IDS: PackedStringArray = [
	"bell_clapper", "vesper_chime", "toll_echo", "belfry_weight",
	"rip_tide", "sea_glass", "harbor_wake", "anchor_lead",
	"ember_seed", "briar_thorn", "vine_snare", "canopy_dew",
	"hourglass_sand", "petal_mirror", "dusk_dew", "rain_prism",
	"orbit_shard", "comet_tail", "zenith_lens", "null_well",
	"cinder_blast", "slag_coat", "bellows_vent", "anvil_strike",
	"silver_twin", "moon_phase", "glass_step", "mirror_ward",
	"toll_wick", "hush_glass", "dawn_spark", "last_glass",
]

static var active: LxPanes = null

var _catalog: Dictionary = {}        # id -> LxPane
var _owned: Array[String] = []
var _equipped: Array[String] = []
var _slots: int = MIN_SLOTS
var _max_lead: int = DEFAULT_MAX_LEAD
var _bound_events: LxEventBus = null


static func current() -> LxPanes:
	var lx_panes: Variant = (Lx as Object).get("panes")
	if lx_panes is LxPanes:
		active = lx_panes as LxPanes
		return active
	if active == null:
		active = LxPanes.new()
		active.load_from_state()
	return active


static func reset_singleton() -> void:
	if active != null:
		active.unbind_events()
	active = null


func _init() -> void:
	register_all_panes()


func register_all_panes() -> void:
	_catalog.clear()
	for i: int in range(ORDERED_IDS.size()):
		var pid: String = ORDERED_IDS[i]
		var scr: Variant = PANE_SCRIPTS.get(pid, null)
		if scr is GDScript:
			var inst: Variant = (scr as GDScript).new()
			if inst is LxPane:
				var p: LxPane = inst as LxPane
				p.id = pid
				p.icon_index = i
				_catalog[pid] = p


func all_ids() -> PackedStringArray:
	return ORDERED_IDS


func get_pane(pane_id: String) -> LxPane:
	return _catalog.get(pane_id, null) as LxPane


func panes_for_island(isl: int) -> Array[LxPane]:
	var out: Array[LxPane] = []
	for pid: String in ORDERED_IDS:
		var p: LxPane = get_pane(pid)
		if p != null and (isl <= 0 or p.island_id == isl):
			out.append(p)
	return out


func grant_pane(pane_id: String) -> bool:
	if not _catalog.has(pane_id):
		return false
	if _owned.has(pane_id):
		return false
	_owned.append(pane_id)
	save_to_state()
	return true


func has_pane(pane_id: String) -> bool:
	return _owned.has(pane_id)


func owned_ids() -> PackedStringArray:
	return PackedStringArray(_owned)


func owned_count_for_island(isl: int) -> int:
	var n: int = 0
	for pid: String in _owned:
		var p: LxPane = get_pane(pid)
		if p != null and (isl <= 0 or p.island_id == isl):
			n += 1
	return n


func get_slots() -> int:
	return clampi(_slots, MIN_SLOTS, MAX_SLOTS)


func add_slot() -> bool:
	if _slots >= MAX_SLOTS:
		return false
	_slots = mini(MAX_SLOTS, _slots + 1)
	_max_lead = mini(MAX_LEAD_CAP, _max_lead + 2)
	save_to_state()
	return true


func get_max_lead() -> int:
	return clampi(_max_lead, DEFAULT_MAX_LEAD, MAX_LEAD_CAP)


func add_lead(amount: int) -> bool:
	if amount <= 0 or _max_lead >= MAX_LEAD_CAP:
		return false
	_max_lead = mini(MAX_LEAD_CAP, _max_lead + amount)
	save_to_state()
	return true


func used_lead() -> int:
	var total: int = 0
	for pid: String in _equipped:
		var p: LxPane = get_pane(pid)
		if p != null:
			total += p.lead_cost
	return total


func free_lead() -> int:
	return maxi(0, get_max_lead() - used_lead())


func equipped_ids() -> PackedStringArray:
	return PackedStringArray(_equipped)


func is_equipped(pane_id: String) -> bool:
	return _equipped.has(pane_id)


func can_equip(pane_id: String, replacing_slot: int = -1) -> String:
	var p: LxPane = get_pane(pane_id)
	if p == null or not _owned.has(pane_id):
		return "PANE_ERR_UNOWNED"
	if _equipped.has(pane_id):
		return "PANE_ERR_EQUIPPED"
	var rep_cost: int = 0
	var has_rep: bool = replacing_slot >= 0 and replacing_slot < _equipped.size()
	if has_rep:
		var rp: LxPane = get_pane(_equipped[replacing_slot])
		if rp != null:
			rep_cost = rp.lead_cost
	elif _equipped.size() >= get_slots():
		return "PANE_ERR_SLOTS"
	if used_lead() - rep_cost + p.lead_cost > get_max_lead():
		return "PANE_ERR_LEAD"
	return ""


func equip(pane_id: String, at_slot: int = -1) -> bool:
	var err: String = can_equip(pane_id, at_slot)
	if not err.is_empty():
		return false
	var p: LxPane = get_pane(pane_id)
	if p != null:
		p.reset_runtime()
	if at_slot >= 0 and at_slot < _equipped.size():
		_equipped[at_slot] = pane_id
	else:
		_equipped.append(pane_id)
	save_to_state()
	return true


func unequip(pane_id: String) -> bool:
	var idx: int = _equipped.find(pane_id)
	if idx < 0:
		return false
	_equipped.remove_at(idx)
	save_to_state()
	return true


func unequip_slot(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= _equipped.size():
		return false
	_equipped.remove_at(slot_idx)
	save_to_state()
	return true


func swap_slots(slot_a: int, slot_b: int) -> bool:
	if slot_a < 0 or slot_b < 0 or slot_a >= _equipped.size() or slot_b >= _equipped.size() or slot_a == slot_b:
		return false
	var tmp: String = _equipped[slot_a]
	_equipped[slot_a] = _equipped[slot_b]
	_equipped[slot_b] = tmp
	save_to_state()
	return true


func clear_equipped() -> void:
	_equipped.clear()
	save_to_state()


func save_to_state(state: LxGameState = null) -> void:
	var st: LxGameState = state if state != null else Lx.state
	if st == null:
		return
	st.story_flags[FLAG_OWNED] = _owned.duplicate()
	st.story_flags[FLAG_EQUIPPED] = _equipped.duplicate()
	st.story_flags[FLAG_SLOTS] = _slots
	st.story_flags[FLAG_MAX_LEAD] = _max_lead


func load_from_state(state: LxGameState = null) -> void:
	var st: LxGameState = state if state != null else Lx.state
	_owned.clear()
	_equipped.clear()
	_slots = MIN_SLOTS
	_max_lead = DEFAULT_MAX_LEAD
	if st == null:
		return
	_slots = clampi(int(st.story_flags.get(FLAG_SLOTS, MIN_SLOTS)), MIN_SLOTS, MAX_SLOTS)
	_max_lead = clampi(int(st.story_flags.get(FLAG_MAX_LEAD, DEFAULT_MAX_LEAD)), DEFAULT_MAX_LEAD, MAX_LEAD_CAP)
	var own_v: Variant = st.story_flags.get(FLAG_OWNED, [])
	if own_v is Array:
		for item: Variant in (own_v as Array):
			var pid: String = str(item)
			if _catalog.has(pid) and not _owned.has(pid):
				_owned.append(pid)
	var eq_v: Variant = st.story_flags.get(FLAG_EQUIPPED, [])
	if eq_v is Array:
		for item: Variant in (eq_v as Array):
			var pid: String = str(item)
			if _owned.has(pid) and can_equip(pid).is_empty():
				_equipped.append(pid)


func bind_events(events: LxEventBus = null) -> void:
	var ev: LxEventBus = events if events != null else Lx.events
	if ev == null or _bound_events == ev:
		return
	unbind_events()
	_bound_events = ev
	ev.enemy_hit.connect(_ev_enemy_hit)
	ev.enemy_killed.connect(_ev_enemy_killed)
	ev.lantern_thrown.connect(_ev_lantern_thrown)
	ev.lantern_recalled.connect(_ev_lantern_recalled)
	ev.player_damaged.connect(_ev_player_damaged)
	ev.region_entered.connect(_ev_region_entered)
	ev.room_changed.connect(_ev_room_changed)


func unbind_events() -> void:
	if _bound_events == null or not is_instance_valid(_bound_events):
		_bound_events = null
		return
	if _bound_events.enemy_hit.is_connected(_ev_enemy_hit): _bound_events.enemy_hit.disconnect(_ev_enemy_hit)
	if _bound_events.enemy_killed.is_connected(_ev_enemy_killed): _bound_events.enemy_killed.disconnect(_ev_enemy_killed)
	if _bound_events.lantern_thrown.is_connected(_ev_lantern_thrown): _bound_events.lantern_thrown.disconnect(_ev_lantern_thrown)
	if _bound_events.lantern_recalled.is_connected(_ev_lantern_recalled): _bound_events.lantern_recalled.disconnect(_ev_lantern_recalled)
	if _bound_events.player_damaged.is_connected(_ev_player_damaged): _bound_events.player_damaged.disconnect(_ev_player_damaged)
	if _bound_events.region_entered.is_connected(_ev_region_entered): _bound_events.region_entered.disconnect(_ev_region_entered)
	if _bound_events.room_changed.is_connected(_ev_room_changed): _bound_events.room_changed.disconnect(_ev_room_changed)
	_bound_events = null


func _ev_enemy_hit(enemy: Object, hit: Object, result: int) -> void:
	if hit is LxHit and (hit as LxHit).is_bolt():
		fire_bolt_hit({"enemy": enemy, "hit": hit, "result": result, "pos": _entity_pos(enemy)})


func _ev_enemy_killed(enemy: Object, kind: String, pos: Vector2, opened_kill: bool) -> void:
	fire_kill({"enemy": enemy, "kind": kind, "pos": pos, "opened_kill": opened_kill})


func _ev_lantern_thrown(pos: Vector2, dir: Vector2) -> void:
	fire_throw({"pos": pos, "dir": dir})


func _ev_lantern_recalled(pos: Vector2) -> void:
	fire_recall({"pos": pos})


func _ev_player_damaged(amount: float, from_pos: Vector2, knock_dir: Vector2, source: String) -> void:
	fire_hurt({"amount": amount, "from_pos": from_pos, "knock_dir": knock_dir, "source": source})


func _ev_region_entered(island_id: int, region_id: String) -> void:
	fire_room_enter({"island_id": island_id, "region_id": region_id})


func _ev_room_changed(island_id: int, room_id: String) -> void:
	fire_room_enter({"island_id": island_id, "room_id": room_id})


func _make_ctx(extra: Dictionary) -> Dictionary:
	var ctx: Dictionary = extra.duplicate()
	if not ctx.has("wick"): ctx["wick"] = Lx.player
	if not ctx.has("world"): ctx["world"] = Lx.world
	if not ctx.has("state"): ctx["state"] = Lx.state
	if not ctx.has("fx"): ctx["fx"] = LxPaneFx.active_instance
	return ctx


func fire_bolt_fired(extra: Dictionary = {}) -> void:
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_bolt_fired(ctx)


func fire_bolt_hit(extra: Dictionary = {}) -> void:
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_bolt_hit(ctx)


func fire_throw(extra: Dictionary = {}) -> void:
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_throw(ctx)


func fire_recall(extra: Dictionary = {}) -> void:
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_recall(ctx)


func fire_zip(extra: Dictionary = {}) -> void:
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_zip(ctx)


func fire_dash(extra: Dictionary = {}) -> void:
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_dash(ctx)


func fire_perfect_dodge(extra: Dictionary = {}) -> void:
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_perfect_dodge(ctx)


func fire_kill(extra: Dictionary = {}) -> void:
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_kill(ctx)


func fire_hurt(extra: Dictionary = {}) -> void:
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_hurt(ctx)


func fire_room_enter(extra: Dictionary = {}) -> void:
	var fx: LxPaneFx = LxPaneFx.active_instance
	if fx != null and is_instance_valid(fx):
		fx.clear_all()
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped: get_pane(pid).on_room_enter(ctx)


func modify_stat(stat_name: String, base_value: float, extra: Dictionary = {}) -> float:
	var v: float = base_value
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped:
		v = get_pane(pid).modify_stat(stat_name, v, ctx)
	if STAT_BOUNDS.has(stat_name):
		var b: Array = STAT_BOUNDS[stat_name] as Array
		v = clampf(v, float(b[0]), float(b[1]))
	return v


func tick(dt: float, extra: Dictionary = {}) -> void:
	var fx: LxPaneFx = LxPaneFx.active_instance
	if fx != null and is_instance_valid(fx):
		fx.tick(dt)
	var ctx: Dictionary = _make_ctx(extra)
	for pid: String in _equipped:
		get_pane(pid).tick(dt, ctx)


static func _entity_pos(obj: Object) -> Vector2:
	if obj == null or not is_instance_valid(obj):
		return Vector2.ZERO
	if obj is Node2D:
		return (obj as Node2D).global_position
	var pv: Variant = obj.get("pos")
	return pv as Vector2 if pv is Vector2 else Vector2.ZERO
