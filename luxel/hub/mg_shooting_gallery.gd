class_name LxMgShootingGallery
extends LxHubTrialBase
## Shooting Gallery Minigame (kind "mg_shooting_gallery"):
## 3 manual-aim sets: Set 1 Classic moving targets, Set 2 Prism Bounce (blue_transformer),
## Set 3 Gravity Curve (gravity_well). Shoot the plinth to cycle sets; interact to start!

const SET_NAMES: PackedStringArray = ["SET 1", "SET 2", "SET 3"]
const SET_KEYS: PackedStringArray = ["HUB_GAL_SET1", "HUB_GAL_SET2", "HUB_GAL_SET3"]

var set_idx: int = 0 # 0=Classic, 1=Prism, 2=Curve
var streak: int = 0
var hits_scored: int = 0
var _spawn_cd: float = 0.0
var _pattern_i: int = 0
var _targets: Array[LxGalleryTarget] = []
var _set_flash_t: float = 0.0
var _gallery_overlay: Node2D = null
var _pops: Array[Dictionary] = [] # {pos: Vector2, age: float, life: float, col: Color}


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "mg_shooting_gallery"
	mg_id = "shooting_gallery"
	title_key = "HUB_MG_GALLERY"
	lower_is_better = false
	bronze_goal = 100.0
	silver_goal = 210.0
	gold_goal = 340.0
	trial_time_limit = 45.0
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if not active or trial_running or hit == null:
		return false
	set_idx = (set_idx + 1) % 3
	_set_flash_t = 0.25
	_emit_sfx("ui_move")
	if Lx.events != null:
		Lx.events.narration_requested.emit(SET_KEYS[set_idx], "narration", 2.0)
	queue_redraw()
	return true


func set_mode(idx: int) -> void:
	set_idx = clampi(idx, 0, 2)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _set_flash_t > 0.0:
		_set_flash_t = maxf(0.0, _set_flash_t - dt)
		queue_redraw()


func _on_trial_start() -> void:
	streak = 0
	hits_scored = 0
	_pattern_i = 0
	_spawn_cd = 0.2
	_pops.clear()
	_clear_targets()
	_ensure_overlay()
	trial_subtext = SET_NAMES[set_idx]


func _on_trial_end() -> void:
	_pops.clear()
	_clear_targets()
	_clear_overlay()


func _on_trial_tick(dt: float) -> void:
	# Prune expired targets (reset streak if one timed out unhit)
	var alive_n: int = 0
	for i: int in range(_targets.size() - 1, -1, -1):
		var t: LxGalleryTarget = _targets[i]
		if not is_instance_valid(t) or not t.active:
			if is_instance_valid(t):
				if not t.hit_done:
					streak = 0
				if t.target_scored.is_connected(_on_target_scored):
					t.target_scored.disconnect(_on_target_scored)
				if is_instance_valid(region):
					region.remove_interactable(t.id)
			_targets.remove_at(i)
		else:
			alive_n += 1
	for pi: int in range(_pops.size() - 1, -1, -1):
		_pops[pi]["age"] = float(_pops[pi]["age"]) + dt
		if float(_pops[pi]["age"]) >= float(_pops[pi]["life"]):
			_pops.remove_at(pi)
	_spawn_cd -= dt
	if _spawn_cd <= 0.0 and alive_n < 3:
		_spawn_next_target()
		_spawn_cd = 1.15 if set_idx == 0 else 1.45
	trial_subtext = "%s x%d" % [SET_NAMES[set_idx], streak]
	if _gallery_overlay != null and is_instance_valid(_gallery_overlay):
		_gallery_overlay.queue_redraw()


func _spawn_next_target() -> void:
	if region == null:
		return
	var spec: Dictionary = {}
	var tid: String = "gal_tgt_%d_%d" % [set_idx, _pattern_i]
	if set_idx == 0:
		# Classic manual-aim lanes across the shooting range north wall
		var spots: Array[Vector2] = [
			Vector2(112.0, 72.0), Vector2(208.0, 68.0), Vector2(296.0, 76.0),
			Vector2(152.0, 96.0), Vector2(256.0, 92.0),
		]
		var sp: Vector2 = spots[_pattern_i % spots.size()]
		var amp: Array = [36.0, 0.0] if (_pattern_i % 2 == 1) else [0.0, 14.0]
		spec = {"id": tid, "kind": "gallery_target", "pos": [sp.x, sp.y], "props": {"mode": "classic", "points": 20, "amp": amp, "speed": 2.2, "lifetime": 6.5}}
	elif set_idx == 1:
		# Prism bounce targets behind cover aligned with the room's blue_transformer mirrors
		var spots_p: Array[Vector2] = [Vector2(120.0, 64.0), Vector2(208.0, 64.0), Vector2(296.0, 64.0)]
		var sp_p: Vector2 = spots_p[_pattern_i % spots_p.size()]
		spec = {"id": tid, "kind": "gallery_target", "pos": [sp_p.x, sp_p.y], "props": {"mode": "prism", "points": 25, "amp": [18.0, 0.0], "speed": 1.4, "lifetime": 8.5}}
	else:
		# Gravity-curve targets tucked beside the gravity_well field
		var spots_c: Array[Vector2] = [Vector2(144.0, 66.0), Vector2(272.0, 66.0), Vector2(208.0, 58.0)]
		var sp_c: Vector2 = spots_c[_pattern_i % spots_c.size()]
		spec = {"id": tid, "kind": "gallery_target", "pos": [sp_c.x, sp_c.y], "props": {"mode": "curve", "points": 30, "amp": [12.0, 8.0], "speed": 1.6, "lifetime": 9.0}}
	_pattern_i += 1
	var node: LxInteractable = region.spawn_interactable(spec)
	if node is LxGalleryTarget:
		var gt: LxGalleryTarget = node as LxGalleryTarget
		gt.target_scored.connect(_on_target_scored)
		_targets.append(gt)


func _on_target_scored(tgt: LxGalleryTarget, _hit: LxHit, pts: int) -> void:
	if not trial_running:
		return
	streak += 1
	hits_scored += 1
	var bonus: int = mini(streak * 3, 24)
	trial_score += float(pts + bonus)
	if tgt != null and is_instance_valid(tgt):
		_pops.append({
			"pos": tgt.pos.round(),
			"age": 0.0,
			"life": 0.28,
			"col": LxPalette.color(_get_plinth_accent(), "gold"),
		})


func _exit_tree() -> void:
	_clear_overlay()
	_clear_targets()
	super._exit_tree()


func _ensure_overlay() -> void:
	if region == null:
		return
	_clear_overlay()
	_gallery_overlay = Node2D.new()
	_gallery_overlay.name = "ShootingGalleryOverlay"
	_gallery_overlay.z_index = 4
	_gallery_overlay.draw.connect(_draw_gallery_overlay)
	region.add_child(_gallery_overlay)


func _clear_overlay() -> void:
	if _gallery_overlay != null and is_instance_valid(_gallery_overlay):
		if _gallery_overlay.draw.is_connected(_draw_gallery_overlay):
			_gallery_overlay.draw.disconnect(_draw_gallery_overlay)
		_gallery_overlay.queue_free()
	_gallery_overlay = null


func _draw_gallery_overlay() -> void:
	if not trial_running or _gallery_overlay == null:
		return
	var fr: bool = LxHudFx.flash_reduced()
	for pop: Dictionary in _pops:
		var u: float = clampf(float(pop["age"]) / maxf(float(pop["life"]), 0.01), 0.0, 1.0)
		var pc: Vector2 = (pop["pos"] as Vector2) + Vector2(0.0, -8.0)
		var r: float = roundf(5.0 + u * (8.0 if fr else 14.0))
		_gallery_overlay.draw_arc(pc, r + 1.0, 0.0, TAU, 16, LxPalette.PAL["void"], 2.0)
		_gallery_overlay.draw_arc(pc, r, 0.0, TAU, 16, pop["col"] as Color, 1.0)


func _clear_targets() -> void:
	for t: LxGalleryTarget in _targets:
		if is_instance_valid(t):
			if t.target_scored.is_connected(_on_target_scored):
				t.target_scored.disconnect(_on_target_scored)
			if is_instance_valid(region):
				region.remove_interactable(t.id)
	_targets.clear()


func _get_plinth_icon() -> String: return "move_bolt"
func _get_plinth_accent() -> String: return "coral" if set_idx == 2 else ("sky" if set_idx == 1 else "gold")


func _draw() -> void:
	super._draw()
	if not active:
		return
	var fr: bool = LxHudFx.flash_reduced()
	var acc: Color = LxPalette.color(_get_plinth_accent(), "gold")
	var c_void: Color = LxPalette.PAL["void"]
	# Void-backed SET plaque positioned cleanly above the plinth beacon + 3 set pips
	var pill := Rect2(-15.0, -32.0, 30.0, 9.0)
	draw_rect(pill, c_void)
	draw_rect(pill.grow(-1.0), LxPalette.PAL["plum"] if (_set_flash_t > 0.0 and not fr) else LxPalette.PAL["night"])
	draw_rect(Rect2(pill.position.x + 1.0, pill.position.y + 1.0, pill.size.x - 2.0, 1.0), acc)
	LxPixelFont.draw_centered(self, SET_NAMES[set_idx], 0.0, pill.position.y + 3.0, acc, 1)
	var set_cols: Array[Color] = [LxPalette.PAL["gold"], LxPalette.PAL["sky"], LxPalette.PAL["coral"]]
	draw_rect(Rect2(-7.0, -23.0, 14.0, 3.0), c_void)
	for si: int in range(3):
		draw_rect(Rect2(-6.0 + float(si * 4), -22.0, 3.0, 1.0), set_cols[si] if si == set_idx else LxPalette.PAL["dusk"])
