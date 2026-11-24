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
	_clear_motes()
	_spawn_mote()
	_spawn_mote()
	trial_subtext = "CHAIN 0"


func _on_trial_end() -> void:
	_clear_motes()


func _on_trial_tick(dt: float) -> void:
	if chain_timer > 0.0:
		chain_timer = maxf(0.0, chain_timer - dt)
		if chain_timer <= 0.0:
			chain_count = 0
			last_source = ""
	var alive: int = 0
	for i: int in range(_motes.size() - 1, -1, -1):
		var m: LxGalleryTarget = _motes[i]
		if m == null or not is_instance_valid(m) or not m.active:
			if m != null and is_instance_valid(m) and region != null:
				region.remove_interactable(m.id)
			_motes.remove_at(i)
		else:
			alive += 1
	while alive < 2:
		_spawn_mote()
		alive += 1
	trial_subtext = "CHAIN x%d" % chain_count


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


func _on_mote_hit(_tgt: LxGalleryTarget, hit: LxHit, pts: int) -> void:
	if not trial_running:
		return
	chain_count += 1
	best_chain = maxi(best_chain, chain_count)
	chain_timer = 5.0
	var alt_bonus: int = 2 if (not last_source.is_empty() and hit != null and hit.source != last_source) else 0
	if hit != null:
		last_source = hit.source
	trial_score += float(pts + alt_bonus)
	_spawn_mote()


func _clear_motes() -> void:
	for m: LxGalleryTarget in _motes:
		if m != null and is_instance_valid(m) and region != null:
			region.remove_interactable(m.id)
	_motes.clear()


func _get_plinth_icon() -> String: return "move_throw"
func _get_plinth_accent() -> String: return "lime"
