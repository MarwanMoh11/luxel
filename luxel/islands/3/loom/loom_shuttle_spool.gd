class_name LxLoomShuttleSpool
extends LxSilkLoomSpool
## Brass Shuttle Weaver Spool for The Weaver's Loom (loom_r7, loom_r8, loom_r9).
## Throwing Wick's lantern from within 36 px of this spool onto a lantern_hook (or any point)
## ties a taut golden silk conducting wire that STAYS TIED to that hook when Wick recalls his
## lantern so he can shoot this spool and send a real fire spark racing down his woven wire.
## Also accepts E-interact while a wire is tied to strike a spark directly.

const WEAVE_ATTACH_DIST: float = 36.0
const HOOK_SNAP_DIST: float = 28.0
const CHAIN_END_DIST: float = 28.0

var tied_hook_id: String = ""
var wire_tied: bool = false
var _weave_flash_t: float = 0.0
var _near_throw: bool = false
var _prev_lan_st: int = 0


func _toy_setup() -> void:
	super._toy_setup()
	kind = "loom_shuttle_spool"
	accepts_shuttle = true
	tied_hook_id = ""
	wire_tied = false
	_weave_flash_t = 0.0
	_near_throw = false
	_prev_lan_st = 0
	queue_redraw()


func reset_toy() -> void:
	super.reset_toy()
	tied_hook_id = ""
	wire_tied = false
	_weave_flash_t = 0.0
	_near_throw = false
	_prev_lan_st = 0
	queue_redraw()


func tick(dt: float) -> void:
	if _weave_flash_t > 0.0:
		_weave_flash_t = maxf(0.0, _weave_flash_t - dt)
		queue_redraw()
	# Run our persistent Brass Shuttle hook-tying tracker BEFORE base tick clears shuttle_active
	var kept_active: bool = wire_tied
	var kept_end: Vector2 = shuttle_end
	_track_persistent_shuttle()
	if wire_tied:
		shuttle_active = true
		shuttle_end = _current_wire_end()
		kept_active = true
		kept_end = shuttle_end
	super.tick(dt)
	if kept_active and thread_state != "cut":
		shuttle_active = true
		shuttle_end = kept_end


func _track_persistent_shuttle() -> void:
	if not active or thread_state == "cut":
		return
	if require_shuttle and not LxRegionLoader.check_flag_static("brass_shuttle"):
		return
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.lantern == null or not is_instance_valid(w.lantern):
		return
	var st: int = int(w.lantern.state)
	if st == LxLantern.State.FLYING and _prev_lan_st == LxLantern.State.IN_HAND:
		if w.global_position.distance_to(pos) <= WEAVE_ATTACH_DIST:
			_near_throw = true
	if st == LxLantern.State.HANGING and _near_throw:
		var end_p: Vector2 = w.lantern.pos
		var hook_it: LxInteractable = _find_nearest_hook(end_p)
		if hook_it != null:
			tied_hook_id = hook_it.id
			shuttle_end = hook_it.pos
		else:
			tied_hook_id = ""
			shuttle_end = end_p
		if not wire_tied or _weave_flash_t <= 0.0:
			_emit_sfx("silk_spark_run")
		wire_tied = true
		shuttle_active = true
		_weave_flash_t = 0.45
		_near_throw = false
		queue_redraw()
	elif st == LxLantern.State.IN_HAND:
		_near_throw = false
	_prev_lan_st = st


func _find_nearest_hook(at_pos: Vector2) -> LxInteractable:
	if region == null or not region.has_method("get_interactables"):
		return null
	var best: LxInteractable = null
	var best_d: float = HOOK_SNAP_DIST
	for it_v: Variant in (region.call("get_interactables") as Array):
		if not (it_v is LxInteractable):
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not is_instance_valid(it) or not it.active or it == self:
			continue
		if it.kind == "lantern_hook":
			var d: float = it.pos.distance_to(at_pos)
			if d <= best_d:
				best_d = d
				best = it
	return best


func _current_wire_end() -> Vector2:
	if not tied_hook_id.is_empty():
		var h: LxInteractable = _find_target(tied_hook_id)
		if h != null and is_instance_valid(h) and h.active:
			return h.pos
	return shuttle_end


func ignite_sparks(from_id: String = "") -> bool:
	if wire_tied and thread_state != "cut":
		shuttle_active = true
		shuttle_end = _current_wire_end()
	var ok: bool = super.ignite_sparks(from_id)
	# Ensure custom shuttle spark chains into any spool sitting beside the tied hook!
	if ok and wire_tied and not _sparks.is_empty():
		var near_spool: LxInteractable = _find_nearest_spool(shuttle_end)
		if near_spool != null:
			for i: int in range(_sparks.size()):
				var sp: Dictionary = _sparks[i]
				if bool(sp.get("shuttle", false)) and str(sp.get("target_id", "")).is_empty():
					sp["target_id"] = near_spool.id
					_sparks[i] = sp
	return ok


func _find_nearest_spool(at_pos: Vector2) -> LxInteractable:
	if region == null or not region.has_method("get_interactables"):
		return null
	var best: LxInteractable = null
	var best_d: float = CHAIN_END_DIST
	for it_v: Variant in (region.call("get_interactables") as Array):
		if not (it_v is LxSilkLoomSpool) or it_v == self:
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not is_instance_valid(it) or not it.active:
			continue
		var d: float = it.pos.distance_to(at_pos)
		if d <= best_d:
			best_d = d
			best = it
	return best


func interact(_actor: Node = null) -> bool:
	if not active or thread_state == "cut" or thread_state == "frozen":
		return false
	if wire_tied:
		return ignite_sparks()
	return false


func get_interact_prompt() -> String:
	if active and wire_tied and thread_state == "taut":
		return "ISL3_PROMPT_WEAVE_SPARK"
	return ""


func _draw() -> void:
	super._draw()
	if wire_tied and thread_state != "cut":
		var rel: Vector2 = (_current_wire_end() - pos).round()
		var c_gold: Color = PAL["gold"] as Color
		var c_cream: Color = PAL["cream"] as Color
		if _weave_flash_t > 0.0:
			draw_line(Vector2.ZERO, rel, c_cream, 2.0)
		# Knot jewel at the tied hook endpoint
		draw_rect(Rect2(rel - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), PAL["void"] as Color)
		draw_rect(Rect2(rel - Vector2.ONE, Vector2(2.0, 2.0)), c_cream if _weave_flash_t > 0.0 else c_gold)
