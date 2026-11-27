class_name LxMemoryPlinth
extends LxToy
## Island 8 Memory Plinth — temporarily surrenders one Wick move (e.g. dash, throw,
## beam, wings) to hold a puzzle signal or open a vault.
## Anti-softlock guarantee: 1-tap reclaim at plinth, AND automatic full restore on
## room clear (when auto_return_on_clear), player death, region leave, or _exit_tree().
## NEVER mutates Lx.state.unlocked_moves (locks runtime LxWick move only).
## Props: move_id, target_id / target_ids, auto_return_on_clear (bool), clear_zone (String).
## States: EMPTY | HOLDING_MOVE | RETURNED.

enum State { EMPTY, HOLDING_MOVE, RETURNED }

var move_id: String = "dash"
var auto_return_on_clear: bool = true
var clear_zone: String = ""
var state: int = State.EMPTY
var _locked_wick: LxWick = null
var _saw_enemies: bool = false
var _events_ref: LxEventBus = null


func _toy_setup() -> void:
	move_id = str(props.get("move_id", "dash")).strip_edges().to_lower()
	auto_return_on_clear = bool(props.get("auto_return_on_clear", true))
	clear_zone = str(props.get("clear_zone", "")).strip_edges()
	radius = 18.0
	_bind_safety_events()
	_saw_enemies = _live_enemy_count() > 0
	queue_redraw()


func _exit_tree() -> void:
	_release_move_from_wick()
	_unbind_safety_events()


func get_state_name() -> String:
	match state:
		State.HOLDING_MOVE: return "HOLDING_MOVE"
		State.RETURNED: return "RETURNED"
		_: return "EMPTY"


func is_holding_move() -> bool:
	return state == State.HOLDING_MOVE


func tick(dt: float) -> void:
	super.tick(dt)
	if state != State.HOLDING_MOVE:
		return
	var live_n: int = _live_enemy_count()
	if live_n > 0:
		_saw_enemies = true
	if auto_return_on_clear and _saw_enemies and live_n == 0:
		_auto_return_on_clear()
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	if state == State.HOLDING_MOVE:
		return reclaim_move()
	if state == State.RETURNED:
		return false
	return surrender_move()


func surrender_move() -> bool:
	if state == State.HOLDING_MOVE:
		return false
	var w: LxWick = _get_wick()
	if w != null:
		if Lx.state != null and not Lx.state.has_move(move_id):
			_emit_sfx("door_locked")
			return false
		_lock_move_on_wick(w)
	state = State.HOLDING_MOVE
	set_powered(true)
	emit_power(true)
	_emit_sfx("plinth_lock")
	queue_redraw()
	return true


func reclaim_move() -> bool:
	if state != State.HOLDING_MOVE:
		return false
	_release_move_from_wick()
	state = State.EMPTY
	set_powered(false)
	emit_power(false)
	_emit_sfx("plinth_return")
	queue_redraw()
	return true


func _auto_return_on_clear() -> void:
	if state != State.HOLDING_MOVE:
		return
	_release_move_from_wick()
	state = State.RETURNED
	# Keep powered=true so doors opened by the cleared challenge remain open!
	_emit_sfx("plinth_return")
	if Lx.events != null and LxStrings.has_id("ISL8_PLINTH_RETURNED"):
		Lx.events.narration_requested.emit("ISL8_PLINTH_RETURNED", "narration", 2.4)
	queue_redraw()


func get_interact_prompt() -> String:
	if not active:
		return ""
	if state == State.HOLDING_MOVE:
		return "ISL8_PROMPT_PLINTH_TAKE"
	if state == State.EMPTY:
		return "ISL8_PROMPT_PLINTH_GIVE"
	return ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if state == State.HOLDING_MOVE:
		return Vector4(pos.x, pos.y - 6.0, 44.0, 0.82)
	return Vector4(pos.x, pos.y - 2.0, 22.0, 0.35)


func _lock_move_on_wick(w: LxWick) -> void:
	_locked_wick = w
	if w.has_method("set_move_locked"):
		w.call("set_move_locked", move_id, true)
	if w.moves.has(move_id):
		var mv: LxMove = w.moves[move_id] as LxMove
		if mv != null:
			mv.locked = true
			mv.unlocked = false


func _release_move_from_wick() -> void:
	var w: LxWick = _locked_wick if (_locked_wick != null and is_instance_valid(_locked_wick)) else _get_wick()
	_locked_wick = null
	if w == null or not is_instance_valid(w):
		return
	if w.has_method("set_move_locked"):
		w.call("set_move_locked", move_id, false)
	if w.moves.has(move_id):
		var mv: LxMove = w.moves[move_id] as LxMove
		if mv != null:
			mv.locked = false
			if mv.has_method("sync_unlock"):
				mv.call("sync_unlock")
			elif Lx.state != null:
				mv.unlocked = Lx.state.has_move(move_id)


func _get_wick() -> LxWick:
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		return Lx.player as LxWick
	return null


func _live_enemy_count() -> int:
	if region == null or not is_instance_valid(region) or not region.has_method("get_enemies"):
		return 0
	var arr: Variant = region.call("get_enemies")
	if not (arr is Array):
		return 0
	var count: int = 0
	for ev: Variant in (arr as Array):
		if ev is Node2D and is_instance_valid(ev):
			var en: Node2D = ev as Node2D
			if en.visible and not (en.get("dead") == true):
				count += 1
	return count


func _on_player_died() -> void:
	if state == State.HOLDING_MOVE:
		reclaim_move()


func _on_region_entered(_isl: int, reg: String) -> void:
	if reg != region_id and state == State.HOLDING_MOVE:
		_release_move_from_wick()
		state = State.EMPTY
		set_powered(false)


func _bind_safety_events() -> void:
	_events_ref = Lx.events
	if _events_ref == null:
		return
	if not _events_ref.player_died.is_connected(_on_player_died):
		_events_ref.player_died.connect(_on_player_died)
	if not _events_ref.region_entered.is_connected(_on_region_entered):
		_events_ref.region_entered.connect(_on_region_entered)


func _unbind_safety_events() -> void:
	if _events_ref == null:
		return
	if _events_ref.player_died.is_connected(_on_player_died):
		_events_ref.player_died.disconnect(_on_player_died)
	if _events_ref.region_entered.is_connected(_on_region_entered):
		_events_ref.region_entered.disconnect(_on_region_entered)
	_events_ref = null


func _draw() -> void:
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var mauve: Color = PAL["mauve"] as Color
	var stone: Color = PAL["stone"] as Color
	var apr: Color = PAL["apricot"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var blue: Color = PAL["blue"] as Color
	var sky: Color = PAL["sky"] as Color
	var ice: Color = PAL["ice"] as Color
	var jade: Color = PAL["jade"] as Color
	var lime: Color = PAL["lime"] as Color
	var fr: bool = LxHudFx.flash_reduced()
	var holding: bool = (state == State.HOLDING_MOVE)
	var returned: bool = (state == State.RETURNED)

	# Grounded shadow under sculpted obsidian memory shrine
	_draw_ground_shadow(11.0, 4.0, Vector2(1.0, 7.0))

	# Stepped obsidian altar base with gold inlay corners
	draw_rect(Rect2(-10.0, 2.0, 20.0, 6.0), void_c)
	draw_rect(Rect2(-9.0, 3.0, 18.0, 4.0), night)
	draw_rect(Rect2(-9.0, 3.0, 18.0, 1.0), dusk)
	draw_rect(Rect2(-8.0, 3.0, 6.0, 1.0), gold if holding else stone)
	draw_rect(Rect2(-9.0, 5.0, 2.0, 1.0), gold if holding else apr)
	draw_rect(Rect2(7.0, 5.0, 2.0, 1.0), gold if holding else apr)

	# Sculpted obsidian shrine body with gold side pilasters
	draw_rect(Rect2(-8.0, -7.0, 16.0, 10.0), void_c)
	draw_rect(Rect2(-7.0, -6.0, 14.0, 9.0), night)
	draw_rect(Rect2(-7.0, -6.0, 2.0, 9.0), dusk)
	draw_rect(Rect2(5.0, -6.0, 2.0, 9.0), dusk)
	draw_rect(Rect2(-6.0, -6.0, 1.0, 8.0), gold if holding else mauve)
	draw_rect(Rect2(5.0, -6.0, 1.0, 8.0), apr if holding else dusk)

	# Gilded stepped crown cornice + twin spire finials
	draw_rect(Rect2(-9.0, -9.0, 18.0, 3.0), void_c)
	draw_rect(Rect2(-8.0, -8.0, 16.0, 2.0), apr if not holding else gold)
	draw_rect(Rect2(-8.0, -8.0, 10.0, 1.0), cream if holding else gold)
	draw_rect(Rect2(-8.0, -11.0, 3.0, 3.0), void_c)
	draw_rect(Rect2(-7.0, -10.0, 1.0, 2.0), gold if holding else stone)
	draw_rect(Rect2(5.0, -11.0, 3.0, 3.0), void_c)
	draw_rect(Rect2(6.0, -10.0, 1.0, 2.0), gold if holding else stone)

	# Recessed keystone frame carved into the shrine front
	var frame_c: Color = gold if holding else (lime if returned else stone)
	draw_rect(Rect2(-5.0, -6.0, 10.0, 8.0), void_c)
	draw_rect(Rect2(-4.0, -5.0, 8.0, 6.0), night)
	# Arch bevel + keystone cap at top center of recess
	draw_rect(Rect2(-4.0, -5.0, 8.0, 1.0), frame_c)
	draw_rect(Rect2(-2.0, -6.0, 4.0, 2.0), frame_c)
	draw_rect(Rect2(-1.0, -6.0, 2.0, 1.0), cream if holding else gold)
	draw_rect(Rect2(-4.0, -5.0, 1.0, 6.0), dusk if not holding else apr)
	draw_rect(Rect2(3.0, -5.0, 1.0, 6.0), dusk if not holding else apr)
	draw_rect(Rect2(-4.0, 1.0, 8.0, 1.0), apr if holding else dusk)

	# Carved move initial centered inside the recessed keystone frame (readable in greyscale!)
	var letter: String = move_id.left(1).to_upper()
	LxPixelFont.draw_centered(self, letter, 0.0, -3.0, cream if holding else (lime if returned else stone), 1, void_c)

	if holding:
		# Soft vertical golden light tether from crown socket to hovering crystal
		var bob: float = 0.0 if fr else roundf(sin(_clock * 4.0) * 1.5)
		var cy: float = -16.0 + bob
		draw_rect(Rect2(-1.0, cy + 5.0, 2.0, maxf(1.0, -8.0 - (cy + 5.0))), Color(gold, 0.45))

		# Faceted hovering memory crystal / sigil above the shrine
		var crys_out := PackedVector2Array([
			Vector2(0.0, cy - 6.0), Vector2(5.0, cy),
			Vector2(0.0, cy + 6.0), Vector2(-5.0, cy),
		])
		var crys_l := PackedVector2Array([
			Vector2(0.0, cy - 5.0), Vector2(0.0, cy + 5.0), Vector2(-4.0, cy),
		])
		var crys_r := PackedVector2Array([
			Vector2(0.0, cy - 5.0), Vector2(4.0, cy), Vector2(0.0, cy + 5.0),
		])
		draw_colored_polygon(crys_out, void_c)
		draw_colored_polygon(crys_l, ice)
		draw_colored_polygon(crys_r, sky)
		draw_rect(Rect2(-2.0, cy - 2.0, 2.0, 3.0), cream)
		draw_rect(Rect2(1.0, cy, 2.0, 2.0), blue)
		draw_rect(Rect2(-1.0, cy - 1.0, 2.0, 2.0), gold)
		draw_rect(Rect2(0.0, cy - 1.0, 1.0, 1.0), cream)

		# Golden sigil halo + orbiting rune motes
		var halo_a: float = 0.55 if fr else (0.58 + 0.30 * absf(sin(_clock * 3.5)))
		draw_arc(Vector2(0.0, cy), 7.0, 0.0, TAU, 16, Color(gold, halo_a), 1.0)
		var orb_a: float = 0.0 if fr else _clock * 2.4
		for oi: int in range(2):
			var oa: float = orb_a + float(oi) * PI
			var op := Vector2(roundf(cos(oa) * 8.0), roundf(cy + sin(oa) * 3.0))
			draw_rect(Rect2(op, Vector2(1.0, 1.0)), cream if oi == 0 else gold)
	elif returned:
		# Serene open emerald/lime lotus crest indicating move was returned
		draw_rect(Rect2(-4.0, -13.0, 8.0, 4.0), void_c)
		draw_rect(Rect2(-3.0, -12.0, 6.0, 2.0), jade)
		draw_rect(Rect2(-2.0, -13.0, 4.0, 3.0), lime)
		draw_rect(Rect2(-1.0, -13.0, 2.0, 1.0), cream)
	else:
		# Empty recessed crown cradle awaiting a lent move
		draw_rect(Rect2(-3.0, -10.0, 6.0, 2.0), void_c)
		draw_rect(Rect2(-2.0, -9.0, 4.0, 1.0), dusk)

	_draw_signal_pulses()
