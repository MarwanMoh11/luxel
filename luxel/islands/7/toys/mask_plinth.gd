class_name LxMaskPlinth
extends LxToy
## Island 7 Doppel Theatre Move-Theft Pedestal & Boss Spotlight Mask:
## - Calls `LxIsland7Rule.steal_moves` (`Lx.player.set_move_locked`) to cage moves per Act.
## - Shattering the Mask (`hp` -> 0) transitions `SEALED_STOLEN -> CRACKING -> RECLAIMED`,
##   restores the stolen moves, sets `release_flag`, and emits signal power.
## - ALWAYS releases its stolen moves on `_exit_tree()` (combined with rule.gd leave/death/load/quit guards).
## Props: act (1..5), steals (Array of move ids), mask_icon (String), release_flag (String),
## boss_mode (bool), hp (float, default 3.5), auto_steal (bool, default true),
## steal_radius (float, default 0), breakable (bool, default true), interact_reclaim (bool), persist (bool).

enum State { SEALED_STOLEN, CRACKING, RECLAIMED }

var act_num: int = 1
var steals: Array[String] = ["throw"]
var mask_icon: String = "throw"
var release_flag: String = ""
var boss_mode: bool = false
var max_hp: float = 3.5
var cur_hp: float = 3.5
var auto_steal: bool = true
var steal_radius: float = 0.0
var breakable: bool = true
var interact_reclaim: bool = false
var state: int = State.SEALED_STOLEN

var _theft_applied: bool = false
var _hit_flash_t: float = 0.0
var _reclaim_burst_t: float = 0.0
var _source_key: String = ""


func _toy_setup() -> void:
	kind = "mask_plinth"
	act_num = clampi(int(props.get("act", 1)), 1, 5)
	steals.clear()
	var raw_st: Variant = props.get("steals", ["throw"])
	if raw_st is Array:
		for m_v: Variant in (raw_st as Array):
			var ms: String = str(m_v).strip_edges().to_lower()
			if LxIsland7Rule.ALL_MOVES.has(ms) and not steals.has(ms):
				steals.append(ms)
	if steals.is_empty():
		steals.append("throw")
	mask_icon = str(props.get("mask_icon", steals[0])).strip_edges().to_lower()
	release_flag = str(props.get("release_flag", "")).strip_edges()
	boss_mode = bool(props.get("boss_mode", false))
	max_hp = maxf(0.0, float(props.get("hp", 3.5)))
	cur_hp = max_hp
	auto_steal = bool(props.get("auto_steal", true))
	steal_radius = maxf(0.0, float(props.get("steal_radius", 0.0)))
	breakable = bool(props.get("breakable", true))
	interact_reclaim = bool(props.get("interact_reclaim", max_hp <= 0.0))
	radius = maxf(13.0, radius)
	_source_key = id if not id.is_empty() else ("mask_plinth_%d" % get_instance_id())
	_theft_applied = false
	_hit_flash_t = 0.0
	_reclaim_burst_t = 0.0

	if _is_flag_released():
		state = State.RECLAIMED
		powered = true
	else:
		state = State.SEALED_STOLEN
		powered = false
		if auto_steal and steal_radius <= 0.0:
			apply_room_theft()
	queue_redraw()


func _exit_tree() -> void:
	_release_held_moves()


func reset_toy() -> void:
	if persist and state == State.RECLAIMED:
		return
	if _is_flag_released():
		state = State.RECLAIMED
		powered = true
		_release_held_moves()
	else:
		cur_hp = max_hp
		state = State.SEALED_STOLEN
		powered = false
		if auto_steal and steal_radius <= 0.0:
			apply_room_theft()
	queue_redraw()


func _is_flag_released() -> bool:
	return (not release_flag.is_empty()) and Lx.state != null and bool(Lx.state.story_flags.get(release_flag, false))


func apply_room_theft(force: bool = false) -> void:
	if not active or state == State.RECLAIMED or _is_flag_released():
		return
	if _theft_applied and not force:
		if LxIsland7Rule.active_rule == null or LxIsland7Rule.active_rule.is_move_stolen(steals[0]):
			return
	_theft_applied = true
	var act_id: String = "act%d" % act_num
	if LxIsland7Rule.active_rule != null:
		LxIsland7Rule.active_rule.steal_moves(steals, act_id, _source_key)
	elif Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		for mid: String in steals:
			w.set_move_locked(mid, true)
	_emit_sfx("mask_steal")
	queue_redraw()


func _release_held_moves() -> void:
	if not _theft_applied:
		return
	_theft_applied = false
	if LxIsland7Rule.active_rule != null:
		LxIsland7Rule.active_rule.reclaim_moves(steals, _source_key)
	elif Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		for mid: String in steals:
			w.set_move_locked(mid, false)
		w.sync_unlocks_from_state()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _hit_flash_t > 0.0:
		_hit_flash_t = maxf(0.0, _hit_flash_t - dt); dirty = true
	if _reclaim_burst_t > 0.0:
		_reclaim_burst_t = maxf(0.0, _reclaim_burst_t - dt); dirty = true
	if active and state != State.RECLAIMED and not _theft_applied and steal_radius > 0.0:
		var wp: Vector2 = wick_pos()
		if wp.x > -9000.0 and wp.distance_to(pos) <= steal_radius:
			apply_room_theft()
			dirty = true
	if dirty:
		queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or not breakable or state == State.RECLAIMED:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "zip", "dash", "sunflare"]:
		var dmg: float = maxf(0.5, hit.damage)
		cur_hp = maxf(0.0, cur_hp - dmg)
		_hit_flash_t = 0.22
		if cur_hp <= 0.0:
			reclaim()
		else:
			if cur_hp <= max_hp * 0.65:
				state = State.CRACKING
			_emit_sfx("mirror_ping")
			queue_redraw()
		return true
	return false


func interact(_actor: Node = null) -> bool:
	if not active or state == State.RECLAIMED:
		return false
	if interact_reclaim or max_hp <= 0.0:
		reclaim()
		return true
	if not _theft_applied:
		apply_room_theft()
		return true
	return false


func reclaim() -> void:
	if state == State.RECLAIMED:
		return
	cur_hp = 0.0
	state = State.RECLAIMED
	_reclaim_burst_t = 0.55
	_release_held_moves()
	if not release_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[release_flag] = true
	set_powered(true)
	emit_power(true)
	_emit_sfx("mask_shatter")
	_emit_gust(60.0, 46.0)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_ring(pos, 4.0, 28.0, 0.34, PAL["gold"] as Color, 1.5)
	if not boss_mode and Lx.events != null and LxStrings.has_id("ISL7_ACT_RECLAIM"):
		Lx.events.narration_requested.emit("ISL7_ACT_RECLAIM", "gold", 2.8)
	queue_redraw()


func is_solid() -> bool:
	return active and state != State.RECLAIMED and not boss_mode


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-7.0, -4.0), Vector2(14.0, 10.0)) if is_solid() else Rect2()


func get_interact_prompt() -> String:
	if not active or state == State.RECLAIMED:
		return ""
	if interact_reclaim or max_hp <= 0.0:
		return "ISL7_PROMPT_RECLAIM" if LxStrings.has_id("ISL7_PROMPT_RECLAIM") else ""
	return ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if state == State.RECLAIMED:
		return Vector4(pos.x, pos.y - 4.0, 36.0 if _reclaim_burst_t > 0.0 else 22.0, 0.70 if _reclaim_burst_t > 0.0 else 0.34)
	return Vector4(pos.x, pos.y - 6.0, 44.0 if boss_mode else 34.0, 0.68)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["reclaimed"] = (state == State.RECLAIMED)
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("reclaimed", false)):
		state = State.RECLAIMED
		powered = true
		_release_held_moves()
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_ice: Color = PAL["ice"] as Color

	LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 5.0), 8.0, 3.0, "se_gold", false)
	# Velvet theatrical plinth
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -2.0, 16.0, 8.0), c_night, c_wine, c_gold, c_void)
	draw_rect(Rect2(-6.0, 0.0, 12.0, 4.0), c_wine)

	if state == State.RECLAIMED:
		# Broken porcelain shards + warm open cushion
		draw_rect(Rect2(-4.0, -3.0, 3.0, 2.0), c_cream)
		draw_rect(Rect2(2.0, -2.0, 3.0, 2.0), c_ice)
		draw_rect(Rect2(-1.0, -5.0, 2.0, 2.0), c_gold)
		if _reclaim_burst_t > 0.0:
			var u: float = 1.0 - clampf(_reclaim_burst_t / 0.55, 0.0, 1.0)
			draw_arc(Vector2(0.0, -6.0), roundf(lerpf(5.0, 24.0, u)), 0.0, TAU, 18, Color(c_cream, 1.0 - u), 1.5)
		_draw_signal_pulses()
		return

	# Hovering Porcelain Move Mask
	var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.2) * 1.5)
	var my: float = -12.0 + bob
	var rim_c: Color = c_cream if _hit_flash_t > 0.0 else (c_coral if state == State.CRACKING else c_gold)
	if boss_mode:
		draw_arc(Vector2(0.0, my + 2.0), 11.0, 0.0, TAU, 18, Color(c_gold, 0.45), 1.0)
	draw_rect(Rect2(-6.0, my - 5.0, 12.0, 11.0), c_void)
	draw_rect(Rect2(-5.0, my - 4.0, 10.0, 9.0), c_cream if _hit_flash_t > 0.0 else c_ice)
	draw_rect(Rect2(-5.0, my - 4.0, 10.0, 1.0), rim_c)
	# Move glyph inside mask
	var shape_i: int = _move_shape_index(mask_icon)
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, my), shape_i, true, c_coral if state == State.CRACKING else c_wine, c_gold)
	# Iron cage bars over sealed mask (clearly distinct from reclaimed!)
	for bx: float in [-3.0, 0.0, 3.0]:
		draw_rect(Rect2(bx, my - 5.0, 1.0, 11.0), c_coral if state == State.CRACKING else c_void)
	if state == State.CRACKING:
		draw_line(Vector2(-4.0, my - 3.0), Vector2(3.0, my + 4.0), c_coral, 1.0)
		draw_line(Vector2(4.0, my - 2.0), Vector2(-2.0, my + 3.0), c_rose, 1.0)
	if breakable and max_hp > 0.0:
		LxToyDraw.draw_bar(self, Vector2(-7.0, 7.0), 14.0, cur_hp / max_hp, c_coral, c_rose)
	_draw_signal_pulses()


static func _move_shape_index(move_id: String) -> int:
	match move_id:
		"bolt": return 5
		"dash": return 2
		"throw": return 0
		"prism": return 1
		"beam": return 4
		"wings": return 2
		"lens": return 0
		"sunflare": return 5
		_: return 3
