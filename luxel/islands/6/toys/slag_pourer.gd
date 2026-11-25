class_name LxToySlagPourer
extends LxToy
## Island 6 Overhead Molten Slag Spout (bible section 6.3 — Great Kiln casting & anti-softlock).
## Pours molten push_block[slag] into a floor mold or respawns a slag_slime when `needs_var` holds.
## States: DORMANT (needs_var false / idle) -> POURING (0.7s coral-gold warning stream) -> COOLED (mold filled/cooled).
##
## Props:
##   spawn_pos: [x, y] (world position of floor mold; default [pos.x, pos.y + 20])
##   spawn_kind: "block" | "slime" (default "block")
##   needs_var: String (optional Lx.vars condition, e.g. "kiln_heat==surge")
##   cycle_secs: float (default 0.0; >0 repeats pour every cycle_secs while live < max_live)
##   max_live: int (default 1)
##   pour_warn_secs: float (default 0.7)
##   respawn_delay: float (default 2.5; anti-softlock wait after spawned block/slime disappears)
##   auto_pour: bool (default true)
##   target_id / target_ids: optional signal emitted when cast block cools (or pour finishes)

enum PourState { DORMANT, POURING, COOLED }

var spawn_pos: Vector2 = Vector2.ZERO
var spawn_kind: String = "block"
var needs_var: String = ""
var cycle_secs: float = 0.0
var max_live: int = 1
var pour_warn_secs: float = 0.7
var respawn_delay: float = 2.5
var auto_pour: bool = true

var state: int = PourState.DORMANT
var state_name: String = "DORMANT"
var _pour_t: float = 0.0
var _wait_t: float = 0.0
var _spawn_seq: int = 0
var _spawned: Array[Object] = []
var _was_cooled_signal: bool = false


func _toy_setup() -> void:
	kind = "slag_pourer"
	spawn_pos = _parse_vec2(props.get("spawn_pos", [pos.x, pos.y + 20.0]), pos + Vector2(0.0, 20.0))
	spawn_kind = str(props.get("spawn_kind", "block")).strip_edges().to_lower()
	if spawn_kind not in ["block", "slime"]:
		spawn_kind = "block"
	needs_var = str(props.get("needs_var", "")).strip_edges()
	cycle_secs = maxf(0.0, float(props.get("cycle_secs", 0.0)))
	max_live = maxi(1, int(props.get("max_live", 1)))
	pour_warn_secs = maxf(0.15, float(props.get("pour_warn_secs", 0.7)))
	respawn_delay = maxf(0.2, float(props.get("respawn_delay", 2.5)))
	auto_pour = bool(props.get("auto_pour", true))
	size = Vector2(20.0, 14.0)
	radius = 12.0
	_spawned.clear()
	_pour_t = 0.0
	_wait_t = 0.0
	_was_cooled_signal = false
	_set_state(PourState.DORMANT)
	queue_redraw()


func reset_toy() -> void:
	_clear_spawned()
	_pour_t = 0.0
	_wait_t = 0.0
	_was_cooled_signal = false
	_set_state(PourState.DORMANT)
	set_powered(false)
	queue_redraw()


func _clear_spawned() -> void:
	if region != null and is_instance_valid(region):
		for obj: Object in _spawned:
			if obj != null and is_instance_valid(obj):
				if obj is LxInteractable and region.has_method("remove_interactable"):
					region.call("remove_interactable", (obj as LxInteractable).id)
				elif obj is Node:
					(obj as Node).queue_free()
	_spawned.clear()


func _set_state(s: int) -> void:
	state = s
	state_name = "DORMANT" if s == PourState.DORMANT else ("POURING" if s == PourState.POURING else "COOLED")


func _var_allows_pour() -> bool:
	if needs_var.is_empty():
		return true
	if Lx.vars != null:
		if Lx.vars.eval(needs_var, island_id, region_id):
			return true
		if needs_var.contains("kiln_heat") and not needs_var.contains(".kiln_heat"):
			return Lx.vars.eval(needs_var.replace("kiln_heat", "dungeon:great_kiln.kiln_heat"), island_id, region_id)
		return false
	return true


func trigger_pour() -> bool:
	if not active or state == PourState.POURING:
		return false
	_prune_spawned()
	if _spawned.size() >= max_live:
		return false
	_set_state(PourState.POURING)
	_pour_t = pour_warn_secs
	_emit_sfx("furnace_draw")
	queue_redraw()
	return true


func _on_power_changed(is_on: bool) -> void:
	if is_on:
		trigger_pour()


func live_count() -> int:
	_prune_spawned()
	return _spawned.size()


func get_spawned() -> Array[Object]:
	_prune_spawned()
	return _spawned.duplicate()


func _prune_spawned() -> void:
	var kept: Array[Object] = []
	for obj: Object in _spawned:
		if obj == null or not is_instance_valid(obj):
			continue
		if obj is LxInteractable:
			if (obj as LxInteractable).active:
				kept.append(obj)
		elif obj.has_method("is_alive"):
			if bool(obj.call("is_alive")):
				kept.append(obj)
		else:
			kept.append(obj)
	_spawned = kept


func _complete_pour() -> void:
	_prune_spawned()
	if _spawned.size() >= max_live or region == null or not is_instance_valid(region):
		_set_state(PourState.COOLED)
		return
	_spawn_seq += 1
	var spawned_obj: Object = null
	var want_slime: bool = spawn_kind == "slime" and _can_spawn_slag_slime()
	if want_slime and region.has_method("spawn_enemy"):
		var espec: Dictionary = {
			"id": "%s_slime_%d" % [id if not id.is_empty() else "pour", _spawn_seq],
			"kind": "slag_slime",
			"pos": [spawn_pos.x, spawn_pos.y],
			"island_id": island_id,
		}
		var ev: Variant = region.call("spawn_enemy", espec)
		if ev is Object and is_instance_valid(ev as Object):
			spawned_obj = ev as Object
	elif region.has_method("spawn_interactable"):
		var bspec: Dictionary = {
			"id": "%s_slag_%d" % [id if not id.is_empty() else "pour", _spawn_seq],
			"kind": "push_block",
			"pos": [spawn_pos.x, spawn_pos.y],
			"props": {
				"variant": "slag",
				"cooled": false,
				"size": [16.0, 16.0],
				"persist": false,
			},
		}
		var iv: Variant = region.call("spawn_interactable", bspec)
		if iv is Object and is_instance_valid(iv as Object):
			spawned_obj = iv as Object
	if spawned_obj != null:
		_spawned.append(spawned_obj)
		_emit_sfx("magma_crack")
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			(Lx.player as LxWick).spawn_ring(spawn_pos, 2.0, 14.0, 0.24, PAL["coral"] as Color, 1.4)
			(Lx.player as LxWick).spawn_sparks(spawn_pos, Vector2.UP, 6, PAL["gold"] as Color, 22.0, 66.0, 0.22)
	_set_state(PourState.COOLED)
	_wait_t = cycle_secs if cycle_secs > 0.0 else respawn_delay
	queue_redraw()


static func _can_spawn_slag_slime() -> bool:
	if Lx.packs != null and not Lx.packs.enemy_script("slag_slime").is_empty():
		return true
	return LxEnemyFactory.known_kinds().has("slag_slime")


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	_prune_spawned()
	var can_pour: bool = _var_allows_pour()
	var any_cooled_block: bool = false
	for obj: Object in _spawned:
		if obj is LxInteractable and (obj as LxInteractable).kind == "push_block" and (obj.get("cooled") == true):
			any_cooled_block = true
			break
	if any_cooled_block and not _was_cooled_signal:
		_was_cooled_signal = true
		set_powered(true)
		emit_power(true)
	elif not any_cooled_block and _was_cooled_signal:
		_was_cooled_signal = false
		set_powered(false)

	match state:
		PourState.DORMANT:
			if can_pour and auto_pour and _spawned.size() < max_live:
				if _wait_t > 0.0:
					_wait_t = maxf(0.0, _wait_t - dt)
				else:
					trigger_pour()
		PourState.POURING:
			if not can_pour:
				_set_state(PourState.DORMANT)
				_pour_t = 0.0
			else:
				_pour_t -= dt
				if _pour_t <= 0.0:
					_complete_pour()
			queue_redraw()
		PourState.COOLED:
			if not can_pour:
				_set_state(PourState.DORMANT)
				queue_redraw()
			elif _spawned.size() < max_live and auto_pour:
				_wait_t = maxf(0.0, _wait_t - dt)
				if _wait_t <= 0.0:
					trigger_pour()
			elif not LxHudFx.flash_reduced():
				queue_redraw()


func get_light_pool() -> Vector4:
	if not active or state == PourState.DORMANT:
		return Vector4.ZERO
	if state == PourState.POURING:
		return Vector4(spawn_pos.x, spawn_pos.y, 48.0, 0.85)
	return Vector4(pos.x, pos.y, 26.0, 0.36)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var mold_rel: Vector2 = (spawn_pos - pos).round()

	# 1. Floor casting mold frame at spawn_pos (clearly distinct DORMANT vs POURING vs COOLED in greyscale!)
	var mold_r := Rect2(mold_rel - Vector2(9.0, 9.0), Vector2(18.0, 18.0))
	draw_rect(mold_r, Color(c_void, 0.65))
	var mold_edge: Color = c_gold if state == PourState.POURING else (PAL["ice"] as Color if _was_cooled_signal else (c_stone if state == PourState.COOLED else c_dusk))
	draw_rect(mold_r, mold_edge, false, 1.0)
	# Corner foundry mold lugs
	for corner: Vector2 in [mold_r.position, Vector2(mold_r.end.x - 3.0, mold_r.position.y), Vector2(mold_r.position.x, mold_r.end.y - 3.0), mold_r.end - Vector2(3.0, 3.0)]:
		draw_rect(Rect2(corner, Vector2(3.0, 3.0)), c_mauve if state == PourState.DORMANT else mold_edge)
	if state == PourState.DORMANT:
		# Recessed X inside dry empty mold
		draw_line(mold_r.position + Vector2(4.0, 4.0), mold_r.end - Vector2(5.0, 5.0), c_dusk, 1.0)
		draw_line(Vector2(mold_r.end.x - 5.0, mold_r.position.y + 4.0), Vector2(mold_r.position.x + 4.0, mold_r.end.y - 5.0), c_dusk, 1.0)

	# 2. Overhead riveted crucible spout housing at origin
	LxPhysDraw.draw_bevel_box(self, Rect2(-9.0, -7.0, 18.0, 12.0), c_dusk, c_stone if state != PourState.DORMANT else c_mauve, c_night, c_void, c_apr if state == PourState.POURING else c_mauve)
	# Spout mouth lip
	var mouth_c: Color = c_cream if state == PourState.POURING else (c_apr if state == PourState.COOLED else c_night)
	draw_rect(Rect2(-5.0, 3.0, 10.0, 4.0), c_void)
	draw_rect(Rect2(-4.0, 4.0, 8.0, 2.0), mouth_c)
	# Valve status pip on front plate
	var pip_c: Color = c_gold if state == PourState.POURING else (PAL["ice"] as Color if _was_cooled_signal else (c_coral if state == PourState.COOLED else c_night))
	draw_rect(Rect2(-2.0, -3.0, 4.0, 3.0), pip_c)

	# 3. Blazing coral-gold warning stream during POURING (0.7s)
	if state == PourState.POURING:
		var u: float = 1.0 - clampf(_pour_t / maxf(0.05, pour_warn_secs), 0.0, 1.0)
		var start_p := Vector2(0.0, 6.0)
		var end_p: Vector2 = start_p.lerp(mold_rel, clampf(u * 1.35, 0.15, 1.0))
		draw_line(start_p, end_p, c_coral, 4.0)
		draw_line(start_p, end_p, c_gold, 2.0)
		if not LxHudFx.flash_reduced() or fmod(_clock, 0.25) < 0.15:
			draw_line(start_p, end_p, c_cream, 1.0)
		draw_arc(mold_rel, lerpf(2.0, 10.0, u), 0.0, TAU, 12, c_gold, 1.2)
	_draw_signal_pulses()
