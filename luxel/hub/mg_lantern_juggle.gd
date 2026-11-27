class_name LxMgLanternJuggle
extends LxHubTrialBase
## Lantern Juggling Trial (kind "mg_lantern_juggle") in the Moth Attic:
## Chain Throw -> Recall -> Zip strikes on floating Moth Crystal Motes to build combo!
## Alternating move types grants bonus points and extends the chain timer.

var chain_count: int = 0
var best_chain: int = 0
var chain_timer: float = 0.0
var last_source: String = ""
var _mote_seq: int = 0
var _motes: Array[LxGalleryTarget] = []
var _juggle_overlay: Node2D = null
var _pops: Array[Dictionary] = [] # {pos: Vector2, age: float, life: float, alt: bool}


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "mg_lantern_juggle"
	mg_id = "lantern_juggle"
	title_key = "HUB_MG_JUGGLE"
	lower_is_better = false
	bronze_goal = 10.0
	silver_goal = 22.0
	gold_goal = 36.0
	trial_time_limit = 40.0
	queue_redraw()


func _on_trial_start() -> void:
	chain_count = 0
	best_chain = 0
	chain_timer = 0.0
	last_source = ""
	_mote_seq = 0
	_pops.clear()
	_clear_motes()
	_ensure_overlay()
	_spawn_mote()
	_spawn_mote()
	trial_subtext = "CHAIN 0"


func _on_trial_end() -> void:
	_pops.clear()
	_clear_motes()
	_clear_overlay()


func _on_trial_tick(dt: float) -> void:
	if chain_timer > 0.0:
		chain_timer = maxf(0.0, chain_timer - dt)
		if chain_timer <= 0.0:
			chain_count = 0
			last_source = ""
	for pi: int in range(_pops.size() - 1, -1, -1):
		_pops[pi]["age"] = float(_pops[pi]["age"]) + dt
		if float(_pops[pi]["age"]) >= float(_pops[pi]["life"]):
			_pops.remove_at(pi)
	var alive: int = 0
	for i: int in range(_motes.size() - 1, -1, -1):
		var m: LxGalleryTarget = _motes[i]
		if not is_instance_valid(m) or not m.active:
			if is_instance_valid(m):
				if m.target_scored.is_connected(_on_mote_hit):
					m.target_scored.disconnect(_on_mote_hit)
				if is_instance_valid(region):
					region.remove_interactable(m.id)
			_motes.remove_at(i)
		else:
			alive += 1
	while alive < 2:
		_spawn_mote()
		alive += 1
	trial_subtext = "CHAIN x%d" % chain_count
	if _juggle_overlay != null and is_instance_valid(_juggle_overlay):
		_juggle_overlay.queue_redraw()


func _spawn_mote() -> void:
	if region == null:
		return
	var spots: Array[Vector2] = [
		Vector2(128.0, 120.0), Vector2(224.0, 108.0), Vector2(312.0, 128.0),
		Vector2(168.0, 176.0), Vector2(280.0, 176.0), Vector2(224.0, 148.0),
	]
	var sp: Vector2 = spots[_mote_seq % spots.size()]
	var tid: String = "juggle_mote_%d" % _mote_seq
	_mote_seq += 1
	var node: LxInteractable = region.spawn_interactable({
		"id": tid, "kind": "gallery_target", "pos": [sp.x, sp.y],
		"props": {"mode": "juggle", "points": 2, "amp": [16.0, 10.0], "speed": 1.8, "lifetime": 9.0},
	})
	if node is LxGalleryTarget:
		var gt: LxGalleryTarget = node as LxGalleryTarget
		gt.target_scored.connect(_on_mote_hit)
		_motes.append(gt)


func _on_mote_hit(tgt: LxGalleryTarget, hit: LxHit, pts: int) -> void:
	if not trial_running:
		return
	chain_count += 1
	best_chain = maxi(best_chain, chain_count)
	chain_timer = 5.0
	var alt_bonus: int = 2 if (not last_source.is_empty() and hit != null and hit.source != last_source) else 0
	if hit != null:
		last_source = hit.source
	trial_score += float(pts + alt_bonus)
	if tgt != null and is_instance_valid(tgt):
		_pops.append({"pos": tgt.pos.round(), "age": 0.0, "life": 0.32, "alt": alt_bonus > 0})
	_spawn_mote()


func _exit_tree() -> void:
	_clear_overlay()
	_clear_motes()
	super._exit_tree()


func _ensure_overlay() -> void:
	if region == null:
		return
	_clear_overlay()
	_juggle_overlay = Node2D.new()
	_juggle_overlay.name = "LanternJuggleOverlay"
	_juggle_overlay.z_index = 4
	_juggle_overlay.draw.connect(_draw_juggle)
	region.add_child(_juggle_overlay)


func _clear_overlay() -> void:
	if _juggle_overlay != null and is_instance_valid(_juggle_overlay):
		if _juggle_overlay.draw.is_connected(_draw_juggle):
			_juggle_overlay.draw.disconnect(_draw_juggle)
		_juggle_overlay.queue_free()
	_juggle_overlay = null


func _draw_juggle() -> void:
	if not trial_running or _juggle_overlay == null:
		return
	var fr: bool = LxHudFx.flash_reduced()
	var c_void: Color = LxPalette.PAL["void"]
	# Subtle dashed pixel tether between live motes while a chain is hot
	if chain_count >= 2 and _motes.size() >= 2:
		var m0: LxGalleryTarget = _motes[0]
		var m1: LxGalleryTarget = _motes[1]
		if is_instance_valid(m0) and is_instance_valid(m1) and m0.active and m1.active:
			var a: Vector2 = m0.pos.round() + Vector2(0.0, -8.0)
			var b: Vector2 = m1.pos.round() + Vector2(0.0, -8.0)
			for si: int in range(1, 5):
				var pt: Vector2 = a.lerp(b, float(si) / 5.0).round()
				_juggle_overlay.draw_rect(Rect2(pt + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), c_void)
				_juggle_overlay.draw_rect(Rect2(pt, Vector2(1.0, 1.0)), LxPalette.PAL["lime"] if fr else LxPalette.PAL["gold"])
	# Score hit-pop rings (integer radii & stroke width)
	for pop: Dictionary in _pops:
		var u: float = clampf(float(pop["age"]) / maxf(float(pop["life"]), 0.01), 0.0, 1.0)
		var pc: Vector2 = (pop["pos"] as Vector2) + Vector2(0.0, -8.0)
		var r: float = roundf(5.0 + u * (9.0 if fr else 15.0))
		var col: Color = (LxPalette.PAL["gold"] if bool(pop["alt"]) else LxPalette.PAL["lime"])
		_juggle_overlay.draw_arc(pc, r + 1.0, 0.0, TAU, 16, c_void, 2.0)
		_juggle_overlay.draw_arc(pc, r, 0.0, TAU, 16, col, 1.0)
	# Chain-decay bar & last-move badge above the plinth
	if chain_timer > 0.0:
		var frac: float = clampf(chain_timer / 5.0, 0.0, 1.0)
		var bx: float = roundf(pos.x - 16.0)
		var by: float = roundf(pos.y - 28.0)
		var bar_c: Color = LxPalette.PAL["coral"] if frac < 0.25 else (LxPalette.PAL["gold"] if frac < 0.5 else LxPalette.PAL["lime"])
		_juggle_overlay.draw_rect(Rect2(bx, by, 32.0, 5.0), c_void)
		_juggle_overlay.draw_rect(Rect2(bx + 1.0, by + 1.0, 30.0, 3.0), LxPalette.PAL["night"])
		_juggle_overlay.draw_rect(Rect2(bx + 1.0, by + 1.0, roundf(30.0 * frac), 3.0), bar_c)
		if not last_source.is_empty():
			var ic: String = "move_dash" if last_source == LxHit.SOURCE_ZIP else ("lantern" if last_source == LxHit.SOURCE_RECALL else "move_throw")
			_juggle_overlay.draw_rect(Rect2(bx + 34.0, by - 3.0, 10.0, 10.0), c_void)
			LxBubble.draw_icon(_juggle_overlay, ic, Vector2(bx + 35.0, by - 2.0), 1.0)


func _clear_motes() -> void:
	for m: LxGalleryTarget in _motes:
		if is_instance_valid(m):
			if m.target_scored.is_connected(_on_mote_hit):
				m.target_scored.disconnect(_on_mote_hit)
			if is_instance_valid(region):
				region.remove_interactable(m.id)
	_motes.clear()


func _get_plinth_icon() -> String: return "move_throw"
func _get_plinth_accent() -> String: return "lime"
