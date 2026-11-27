class_name LxHubTracker
extends Node
## Persistent hub runtime coordinator attached under Lx.root so it survives leaving Island 0:
## 1) Boss Rematch Mirror warp -> live boss timer/no-hit -> return warp to Wick House Gallery
## 2) 6 Hub Quests that send Wick back to islands 1..6 with later moves to uncover secrets
## 3) Live Lantern Flame Colour aura on Wick

const HUB_QUEST_SECRETS: Array[Dictionary] = [
	{"quest_id": "q_hub_bell_echo", "island": 1, "need_move": "prism", "flag": "hub:secret:bell_echo", "cue": "HUB_Q_SECRET_FOUND"},
	{"quest_id": "q_hub_tide_chart", "island": 2, "need_move": "beam", "flag": "hub:secret:tide_chart", "cue": "HUB_Q_SECRET_FOUND"},
	{"quest_id": "q_hub_canopy_bulb", "island": 3, "need_move": "wings", "flag": "hub:secret:canopy_bulb", "cue": "HUB_Q_SECRET_FOUND"},
	{"quest_id": "q_hub_dusk_ink", "island": 4, "need_move": "lens", "flag": "hub:secret:dusk_ink", "cue": "HUB_Q_SECRET_FOUND"},
	{"quest_id": "q_hub_star_prism", "island": 5, "need_move": "sunflare", "flag": "hub:secret:star_prism", "cue": "HUB_Q_SECRET_FOUND"},
	{"quest_id": "q_hub_kiln_cinder", "island": 6, "need_move": "sunflare", "flag": "hub:secret:kiln_cinder", "cue": "HUB_Q_SECRET_FOUND"},
]

static var active: LxHubTracker = null

# Active Rematch Mirror session
var rematch_active: bool = false
var rematch_boss_id: String = ""
var rematch_boss_meta: Dictionary = {}
var rematch_target_island: int = 0
var rematch_target_region: String = ""
var rematch_elapsed: float = 0.0
var rematch_hits: int = 0
var rematch_returning: bool = false
var _rematch_slot_id: String = ""
var _return_delay_t: float = 0.0
var _stashed_defeated: Array[String] = []
var _hud_layer: CanvasLayer = null
var _hud_draw: Node2D = null
var _bound_events: LxEventBus = null
var _hit_flash_t: float = 0.0


static func ensure() -> LxHubTracker:
	if active != null and is_instance_valid(active):
		active._ensure_bound()
		active._ensure_flame_aura()
		return active
	var host: Node = Lx.root if (Lx.root != null and is_instance_valid(Lx.root)) else null
	if host == null:
		return null
	var existing: Node = host.get_node_or_null("LxHubTracker")
	if existing is LxHubTracker:
		active = existing as LxHubTracker
		active._ensure_bound()
		active._ensure_flame_aura()
		return active
	var inst := LxHubTracker.new()
	inst.name = "LxHubTracker"
	host.add_child(inst)
	active = inst
	inst._ensure_bound()
	inst._ensure_flame_aura()
	return inst


static func reset_singleton() -> void:
	if active != null and is_instance_valid(active):
		active._unbind()
		active.queue_free()
	active = null


func _exit_tree() -> void:
	_unbind()
	if _hud_draw != null and is_instance_valid(_hud_draw) and _hud_draw.draw.is_connected(_draw_rematch_hud):
		_hud_draw.draw.disconnect(_draw_rematch_hud)
	_hud_draw = null
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	_hud_layer = null
	if active == self:
		active = null


func _ensure_bound() -> void:
	if Lx.events == null or _bound_events == Lx.events:
		return
	_unbind()
	_bound_events = Lx.events
	_bound_events.region_entered.connect(_on_region_entered)
	_bound_events.boss_defeated.connect(_on_boss_defeated)
	_bound_events.player_damaged.connect(_on_player_damaged)
	_bound_events.player_died.connect(_on_player_died)
	_bound_events.great_lamp_relit.connect(_on_great_lamp_relit)


func _unbind() -> void:
	if _bound_events == null or not is_instance_valid(_bound_events):
		_bound_events = null
		return
	if _bound_events.region_entered.is_connected(_on_region_entered): _bound_events.region_entered.disconnect(_on_region_entered)
	if _bound_events.boss_defeated.is_connected(_on_boss_defeated): _bound_events.boss_defeated.disconnect(_on_boss_defeated)
	if _bound_events.player_damaged.is_connected(_on_player_damaged): _bound_events.player_damaged.disconnect(_on_player_damaged)
	if _bound_events.player_died.is_connected(_on_player_died): _bound_events.player_died.disconnect(_on_player_died)
	if _bound_events.great_lamp_relit.is_connected(_on_great_lamp_relit): _bound_events.great_lamp_relit.disconnect(_on_great_lamp_relit)
	_bound_events = null


func _ensure_flame_aura() -> void:
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return
	var w: Node2D = Lx.player as Node2D
	if w.get_node_or_null("LxHubFlameAura") == null:
		var aura := LxHubFlameAura.new()
		aura.name = "LxHubFlameAura"
		aura.bind_wick(w)
		w.add_child(aura)


# ---- Rematch Mirror Session ----

func start_rematch(boss_id: String) -> bool:
	if Lx.state == null or Lx.packs == null or Lx.root == null:
		return false
	var meta: Dictionary = Lx.packs.boss_meta(boss_id)
	if meta.is_empty():
		return false
	var canon: String = str(meta.get("id", boss_id))
	var isl: int = int(meta.get("island", 1))
	var reg: String = str(meta.get("region", ""))
	if isl <= 0 or reg.is_empty():
		return false
	var map_path: String = "res://luxel/islands/%d/%s.map" % [isl, reg]
	if not FileAccess.file_exists(map_path):
		return false

	# Stash matching defeated_bosses entries so LxRegionRuntime spawns the boss cleanly,
	# then restore them immediately inside _on_region_entered BEFORE autosave runs.
	_stashed_defeated.clear()
	var keys_to_hide: Array[String] = [canon, boss_id]
	if canon == "hollow_wick_boss":
		keys_to_hide.append("hollow_wick")
	for k: String in keys_to_hide:
		if Lx.state.defeated_bosses.has(k):
			_stashed_defeated.append(k)
			Lx.state.defeated_bosses.erase(k)
	# Ensure campaign heart reward is already marked claimed so rematches never double-grant hearts
	Lx.state.story_flags["boss_heart_" + canon] = true
	Lx.state.heal_full()

	rematch_active = true
	rematch_returning = false
	_rematch_slot_id = str(Lx.state.slot_id)
	rematch_boss_id = canon
	rematch_boss_meta = meta.duplicate(true)
	rematch_target_island = isl
	rematch_target_region = reg
	rematch_elapsed = 0.0
	rematch_hits = 0
	_return_delay_t = 0.0
	_hit_flash_t = 0.0
	_ensure_rematch_hud()

	var ok: bool = bool(Lx.root.call("load_island_region", isl, reg))
	_restore_stashed_defeated()
	if not ok:
		cancel_rematch()
		return false
	if Lx.events != null:
		Lx.events.narration_requested.emit("HUB_REMATCH_START", "title", 2.0)
	return true


func cancel_rematch() -> void:
	_restore_stashed_defeated()
	rematch_active = false
	rematch_returning = false
	_rematch_slot_id = ""
	rematch_boss_id = ""
	rematch_boss_meta.clear()
	_return_delay_t = 0.0
	_hit_flash_t = 0.0
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.visible = false


func _restore_stashed_defeated() -> void:
	if Lx.state == null or _stashed_defeated.is_empty():
		return
	for k: String in _stashed_defeated:
		if not Lx.state.defeated_bosses.has(k):
			Lx.state.defeated_bosses.append(k)
	_stashed_defeated.clear()


func _process(delta: float) -> void:
	_ensure_flame_aura()
	if not rematch_active:
		return
	if Lx.state == null or (not _rematch_slot_id.is_empty() and str(Lx.state.slot_id) != _rematch_slot_id):
		cancel_rematch()
		return
	var flow_now: int = int(Lx.root.get("flow")) if (Lx.root != null and is_instance_valid(Lx.root) and Lx.root.get("flow") != null) else 2
	if flow_now != 2:
		if flow_now in [0, 1, 6, 7]:
			cancel_rematch()
		return
	if rematch_returning:
		_return_delay_t -= delta
		if _return_delay_t <= 0.0:
			_finish_return_to_mirror()
		if _hud_draw != null and is_instance_valid(_hud_draw):
			_hud_draw.queue_redraw()
		return
	if _hit_flash_t > 0.0:
		_hit_flash_t = maxf(0.0, _hit_flash_t - delta)
	rematch_elapsed += delta
	if _hud_draw != null and is_instance_valid(_hud_draw):
		_hud_draw.queue_redraw()


func _on_region_entered(island_id: int, region_id: String) -> void:
	_restore_stashed_defeated()
	_ensure_flame_aura()
	if rematch_active:
		if island_id != rematch_target_island or region_id != rematch_target_region:
			cancel_rematch()
	if island_id > 0:
		_check_hub_quest_revisit(island_id)


func _on_player_damaged(_amt: float, _from: Vector2, _kdir: Vector2, _src: String) -> void:
	if rematch_active and not rematch_returning:
		rematch_hits += 1
		_hit_flash_t = 0.35


func _on_player_died() -> void:
	if rematch_active:
		cancel_rematch()


func _on_boss_defeated(boss_id: String, _isl: int) -> void:
	if not rematch_active or rematch_returning:
		return
	var canon: String = str(Lx.packs.boss_meta(boss_id).get("id", boss_id)) if Lx.packs != null else boss_id
	if canon != rematch_boss_id and boss_id != rematch_boss_id:
		return
	var no_hit: bool = rematch_hits == 0
	var res: Dictionary = LxHubState.record_rematch_win(rematch_boss_id, rematch_elapsed, no_hit, rematch_boss_meta)
	rematch_returning = true
	_return_delay_t = 2.6
	if Lx.events != null:
		var rkey: String = str(res.get("reward_key", ""))
		Lx.events.narration_requested.emit(rkey if not rkey.is_empty() else "HUB_REMATCH_WIN", "title", 2.4)


func _finish_return_to_mirror() -> void:
	var slot_ok: bool = Lx.state != null and (_rematch_slot_id.is_empty() or str(Lx.state.slot_id) == _rematch_slot_id)
	var flow_ok: bool = Lx.root == null or not is_instance_valid(Lx.root) or Lx.root.get("flow") == null or int(Lx.root.get("flow")) == 2
	cancel_rematch()
	if not slot_ok or not flow_ok:
		return
	if Lx.state != null:
		Lx.state.heal_full()
	if Lx.root != null and Lx.root.has_method("load_island_region"):
		Lx.root.call("load_island_region", 0, "gallery", Vector2(432.0, 128.0))


func _on_great_lamp_relit(_isl: int) -> void:
	LxHubTravel.ensure_hub_waystone_unlocked()
	LxHubState.sync_hub_vars()


func _check_hub_quest_revisit(island_id: int) -> void:
	if Lx.state == null:
		return
	var q: LxQuests = LxQuests.current()
	for spec: Dictionary in HUB_QUEST_SECRETS:
		if int(spec["island"]) != island_id:
			continue
		var qid: String = str(spec["quest_id"])
		var flag: String = str(spec["flag"])
		if not q.is_quest_started(qid) or q.is_quest_done(qid) or bool(Lx.state.story_flags.get(flag, false)):
			continue
		var need_mv: String = str(spec["need_move"])
		if need_mv.is_empty() or Lx.state.has_move(need_mv):
			Lx.state.story_flags[flag] = true
			if Lx.audio != null:
				Lx.audio.play_sfx("shrine_unlock", Vector2.ZERO, false)
			if Lx.events != null:
				Lx.events.narration_requested.emit(str(spec["cue"]), "title", 2.8)
				Lx.events.save_requested.emit("hub_secret_" + qid)


# ---- Rematch Timer & No-Hit HUD ----

func _ensure_rematch_hud() -> void:
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.visible = true
		return
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "RematchHud"
	_hud_layer.layer = 11
	add_child(_hud_layer)
	_hud_draw = Node2D.new()
	_hud_draw.name = "RematchDraw"
	_hud_draw.draw.connect(_draw_rematch_hud)
	_hud_layer.add_child(_hud_draw)


func _draw_rematch_hud() -> void:
	if not rematch_active or _hud_draw == null:
		return
	var fr: bool = LxHudFx.flash_reduced()
	var bar := Rect2(102.0, 4.0, 116.0, 15.0)
	var bdr_k: String = "coral" if (_hit_flash_t > 0.0 and (fr or int(_hit_flash_t * 20.0) % 2 == 0)) else "gold"
	_hud_draw.draw_rect(Rect2(bar.position + Vector2(1.0, 1.0), bar.size), LxPalette.PAL["void"])
	LxPixelFont.draw_panel(_hud_draw, bar, "night", bdr_k, "void")
	var t_str: String = "%02d:%04.1f" % [int(rematch_elapsed / 60.0), fmod(rematch_elapsed, 60.0)]
	var lbl: String = LxStrings.fmt("HUB_REMATCH_HUD", [t_str])
	LxPixelFont.draw(_hud_draw, lbl, Vector2(bar.position.x + 6.0, bar.position.y + 5.0), LxPalette.PAL["cream"], 1)
	var nh_col: Color = LxPalette.PAL["lime"] if rematch_hits == 0 else LxPalette.PAL["coral"]
	var nh_str: String = LxStrings.text("HUB_NO_HIT_OK" if rematch_hits == 0 else "HUB_NO_HIT_LOST")
	LxPixelFont.draw_right(_hud_draw, nh_str, bar.end.x - 6.0, bar.position.y + 5.0, nh_col, 1)
	# Compact void-backed live speed-medal pace tray (Bronze / Silver / Gold)
	var tgts: Vector3 = LxHubState.boss_time_targets(rematch_boss_meta)
	var pace_m: int = 3 if rematch_elapsed <= tgts.x else (2 if rematch_elapsed <= tgts.y else (1 if rematch_elapsed <= tgts.z else 0))
	var tx: float = 149.0
	var ty: float = bar.end.y
	_hud_draw.draw_rect(Rect2(tx, ty, 22.0, 5.0), LxPalette.PAL["void"])
	for mi: int in range(3):
		var mc: Color = LxPalette.PAL["gold"] if mi == 2 else (LxPalette.PAL["ice"] if mi == 1 else LxPalette.PAL["apricot"])
		var px: float = tx + 2.0 + float(mi * 6)
		_hud_draw.draw_rect(Rect2(px, ty + 1.0, 5.0, 3.0), mc if pace_m > mi else LxPalette.PAL["dusk"])
		if pace_m > mi:
			_hud_draw.draw_rect(Rect2(px, ty + 1.0, 1.0, 1.0), LxPalette.PAL["cream"])
