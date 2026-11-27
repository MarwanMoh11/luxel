class_name LxTollScale
extends LxToy
## Island 8 Toll Scale — the world-space altar for "THE LANTERN ASKS".
## Modes: "shop" | "gate" | "redemption" | "boon_toll".
## Props: mode, min_weight (int), target_id / target_ids, persist (bool), auto_sell_id (String), sets_flag (String).
## States: IDLE -> OPEN_LEDGER -> PAID (beam tilts right, gold bowl glows, emits power).

enum State { IDLE, OPEN_LEDGER, PAID }

const VALID_MODES: Array[String] = ["shop", "gate", "redemption", "boon_toll"]

var mode: String = "shop"
var min_weight: int = 1
var state: int = State.IDLE
var auto_sell_id: String = ""
var sets_flag: String = ""
var requires_flag: String = ""
var _tilt: float = 0.0 # 0.0 = level, 1.0 = tilted paid
var _pulse_t: float = 0.0
var _sold_ref: LxSold = null
var _menu_ref: LxTollMenu = null


func _toy_setup() -> void:
	mode = str(props.get("mode", "shop")).strip_edges().to_lower()
	if not VALID_MODES.has(mode):
		mode = "shop"
	min_weight = maxi(1, int(props.get("min_weight", 1)))
	auto_sell_id = str(props.get("auto_sell_id", "")).strip_edges().to_lower()
	sets_flag = str(props.get("sets_flag", "")).strip_edges()
	requires_flag = str(props.get("requires_flag", "")).strip_edges()
	radius = 20.0
	persist = bool(props.get("persist", true))
	_bind_sold()
	_evaluate_existing_state(false)
	queue_redraw()


func _exit_tree() -> void:
	_unbind_sold()
	_unbind_menu()


func get_state_name() -> String:
	match state:
		State.OPEN_LEDGER: return "OPEN_LEDGER"
		State.PAID: return "PAID"
		_: return "IDLE"


func is_paid() -> bool:
	return state == State.PAID


func tick(dt: float) -> void:
	super.tick(dt)
	var target_tilt: float = 1.0 if state == State.PAID else 0.0
	if not is_equal_approx(_tilt, target_tilt):
		_tilt = move_toward(_tilt, target_tilt, dt * 4.0)
		queue_redraw()
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	var sold: LxSold = LxSold.current()
	if mode == "gate" and sold.get_toll_weight() >= min_weight:
		_mark_paid(true)
		return true
	if mode == "redemption":
		if not requires_flag.is_empty() and (Lx.state == null or not bool(Lx.state.story_flags.get(requires_flag, false))):
			_emit_sfx("door_locked")
			if Lx.events != null and LxStrings.has_id("ISL8_REDEMPTION_LOCKED"):
				Lx.events.narration_requested.emit("ISL8_REDEMPTION_LOCKED", "narration", 3.0)
			return false
		if sold.is_redemption_used():
			if state == State.PAID:
				_mark_paid(false)
				return true
			_emit_sfx("door_locked")
			return false
	if mode == "boon_toll" and state == State.PAID:
		return true

	# Synthetic/headless bot path (room_check solutions) executes trade cleanly without hanging modal.
	var is_synthetic: bool = (Lx.input != null and bool(Lx.input.get("_use_synthetic"))) or bool(props.get("instant_trade", false))
	if is_synthetic:
		return _perform_direct_trade()

	# Interactive gameplay path: open the Toll Menu ledger UI.
	var menu: LxTollMenu = _acquire_menu()
	if menu == null:
		return _perform_direct_trade()
	state = State.OPEN_LEDGER
	_unbind_menu()
	_menu_ref = menu
	if not _menu_ref.closed.is_connected(_on_menu_closed):
		_menu_ref.closed.connect(_on_menu_closed)
	if not _menu_ref.trade_completed.is_connected(_on_menu_trade):
		_menu_ref.trade_completed.connect(_on_menu_trade)
	_emit_sfx("toll_weigh")
	_menu_ref.open({
		"mode": mode,
		"min_weight": min_weight,
		"source_id": id,
		"source_pos": pos,
		"pause_world": true,
	})
	queue_redraw()
	return true


func pay_direct(setting_id: String = "") -> bool:
	var prev: String = auto_sell_id
	if not setting_id.is_empty():
		auto_sell_id = setting_id.strip_edges().to_lower()
	var ok: bool = _perform_direct_trade()
	auto_sell_id = prev
	return ok


func get_interact_prompt() -> String:
	if not active:
		return ""
	if mode == "redemption":
		return "" if LxSold.current().is_redemption_used() else "ISL8_PROMPT_SCALE_REDEEM"
	if mode == "boon_toll":
		return "" if state == State.PAID else "ISL8_PROMPT_SCALE_BOON"
	if mode == "gate" and state == State.PAID:
		return ""
	return "ISL8_PROMPT_SCALE"


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var rad: float = 46.0 if state == State.PAID else 34.0
	var inten: float = 0.85 if state == State.PAID else 0.58
	return Vector4(pos.x, pos.y - 4.0, rad, inten)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	d["state"] = state
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	state = int(d.get("state", state))
	if state == State.PAID:
		_tilt = 1.0
		powered = true
	_evaluate_existing_state(false)
	queue_redraw()


func _perform_direct_trade() -> bool:
	var sold: LxSold = LxSold.current()
	if mode == "redemption":
		var sid: String = auto_sell_id
		if sid.is_empty() or not sold.can_redeem(sid):
			var sold_list: PackedStringArray = sold.get_sold_ids()
			sid = ""
			for cand: String in sold_list:
				if sold.can_redeem(cand):
					sid = cand
					break
		if sid.is_empty() or not sold.redeem(sid):
			_emit_sfx("door_locked")
			return false
		_emit_sfx("toll_redeem")
		_mark_paid(true)
		return true

	# Sell a setting (auto_sell_id if valid, else first available setting that meets weight).
	var pick: String = auto_sell_id
	if pick.is_empty() or not sold.can_sell(pick):
		var cands: Array[String] = sold.get_unsold_core_ids()
		pick = cands[0] if not cands.is_empty() else ""
	if pick.is_empty():
		return false
	if not sold.sell(pick, {"source_pos": pos, "save": true}):
		return false
	_emit_sfx("toll_weigh")
	if mode == "boon_toll":
		_grant_legendary_boon()
	if mode != "gate" or sold.get_toll_weight() >= min_weight:
		_mark_paid(true)
	return true


func _grant_legendary_boon() -> void:
	if LxIsland8Rule.active_instance != null and LxIsland8Rule.active_instance.stair != null:
		LxIsland8Rule.active_instance.stair.grant_boon("boon_crowned_toll")


func _mark_paid(play_fx: bool) -> void:
	state = State.PAID
	_tilt = 1.0
	_pulse_t = 0.55 if play_fx else 0.0
	if not sets_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag] = true
	set_powered(true)
	emit_power(true)
	if play_fx:
		_emit_sfx("toll_mote_drink")
	queue_redraw()


func _evaluate_existing_state(play_fx: bool) -> void:
	var sold: LxSold = LxSold.current()
	if mode == "gate" and sold.get_toll_weight() >= min_weight:
		if state != State.PAID:
			_mark_paid(play_fx)
	elif mode == "redemption" and sold.is_redemption_used():
		if state != State.PAID:
			_mark_paid(play_fx)


func _on_sold_changed() -> void:
	_evaluate_existing_state(false)
	queue_redraw()


func _on_menu_trade(_action: String, _sid: String, trade_mode: String) -> void:
	if trade_mode == "boon_toll":
		_grant_legendary_boon()
	var sold: LxSold = LxSold.current()
	if mode == "gate":
		if sold.get_toll_weight() >= min_weight:
			_mark_paid(true)
	else:
		_mark_paid(true)


func _on_menu_closed(res: Dictionary) -> void:
	_unbind_menu()
	if state == State.OPEN_LEDGER:
		if bool(res.get("paid", false)) and (mode != "gate" or LxSold.current().get_toll_weight() >= min_weight):
			_mark_paid(true)
		else:
			state = State.IDLE
	queue_redraw()


func _acquire_menu() -> LxTollMenu:
	if LxTollMenu.active_instance != null and is_instance_valid(LxTollMenu.active_instance):
		return LxTollMenu.active_instance
	if LxIsland8Rule.active_instance != null:
		return LxIsland8Rule.active_instance.open_toll_menu({})
	return null


func _bind_sold() -> void:
	_sold_ref = LxSold.current()
	if _sold_ref != null and not _sold_ref.state_changed.is_connected(_on_sold_changed):
		_sold_ref.state_changed.connect(_on_sold_changed)


func _unbind_sold() -> void:
	if _sold_ref != null and _sold_ref.state_changed.is_connected(_on_sold_changed):
		_sold_ref.state_changed.disconnect(_on_sold_changed)
	_sold_ref = null


func _unbind_menu() -> void:
	if _menu_ref != null and is_instance_valid(_menu_ref):
		if _menu_ref.closed.is_connected(_on_menu_closed):
			_menu_ref.closed.disconnect(_on_menu_closed)
		if _menu_ref.trade_completed.is_connected(_on_menu_trade):
			_menu_ref.trade_completed.disconnect(_on_menu_trade)
	_menu_ref = null


func _draw() -> void:
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var mauve: Color = PAL["mauve"] as Color
	var stone: Color = PAL["stone"] as Color
	var coral: Color = PAL["coral"] as Color
	var apricot: Color = PAL["apricot"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var lime: Color = PAL["lime"] as Color
	var sky: Color = PAL["sky"] as Color
	var ice: Color = PAL["ice"] as Color
	var fr: bool = LxHudFx.flash_reduced()
	var paid: bool = (state == State.PAID)
	var weighing: bool = (state == State.OPEN_LEDGER or paid)
	var accent: Color = lime if mode == "redemption" else (sky if mode == "boon_toll" else gold)
	var accent_hi: Color = cream if mode != "boon_toll" else ice

	# Grounded contact shadow beneath stone pedestal
	_draw_ground_shadow(13.0, 5.0, Vector2(1.0, 7.0))

	# Carved stepped stone altar base with brass corner studs
	draw_rect(Rect2(-11.0, 2.0, 22.0, 6.0), void_c)
	draw_rect(Rect2(-10.0, 3.0, 20.0, 4.0), dusk)
	draw_rect(Rect2(-10.0, 3.0, 12.0, 1.0), stone)
	draw_rect(Rect2(-10.0, 6.0, 20.0, 1.0), night)
	draw_rect(Rect2(-9.0, 4.0, 1.0, 1.0), gold)
	draw_rect(Rect2(8.0, 4.0, 1.0, 1.0), gold)
	# Upper plinth step
	draw_rect(Rect2(-8.0, 0.0, 16.0, 3.0), void_c)
	draw_rect(Rect2(-7.0, 1.0, 14.0, 2.0), night)
	draw_rect(Rect2(-7.0, 1.0, 8.0, 1.0), mauve)

	# Carved fluted stone column supporting the brass balance fulcrum
	draw_rect(Rect2(-3.0, -10.0, 6.0, 11.0), void_c)
	draw_rect(Rect2(-2.0, -9.0, 4.0, 10.0), dusk)
	draw_rect(Rect2(-2.0, -9.0, 1.0, 10.0), stone)
	draw_rect(Rect2(1.0, -9.0, 1.0, 10.0), night)
	# Brass column collar & ornamental mode-distinct fulcrum finial crown
	draw_rect(Rect2(-4.0, -11.0, 8.0, 3.0), void_c)
	draw_rect(Rect2(-3.0, -10.0, 6.0, 1.0), apricot)
	draw_rect(Rect2(-2.0, -13.0, 4.0, 3.0), void_c)
	draw_rect(Rect2(-1.0, -12.0, 2.0, 2.0), accent)
	draw_rect(Rect2(-1.0, -12.0, 1.0, 1.0), cream)
	if mode == "redemption":
		draw_rect(Rect2(-3.0, -12.0, 6.0, 1.0), lime)
		draw_rect(Rect2(-1.0, -14.0, 2.0, 3.0), cream)
	elif mode == "boon_toll":
		draw_rect(Rect2(-3.0, -14.0, 1.0, 2.0), ice)
		draw_rect(Rect2(0.0, -15.0, 1.0, 3.0), cream)
		draw_rect(Rect2(2.0, -14.0, 1.0, 2.0), ice)

	# Sculpted brass balance beam (tilts sharply right when PAID — unmistakable in greyscale!)
	var dy: float = roundf(_tilt * 4.0)
	var left_p := Vector2(-10.0, -9.0 - dy)
	var right_p := Vector2(10.0, -9.0 + dy)
	draw_line(left_p, right_p, void_c, 4.0)
	draw_line(left_p + Vector2(0.0, 1.0), right_p + Vector2(0.0, 1.0), apricot, 2.0)
	draw_line(left_p, right_p, accent, 1.0)
	draw_line(left_p + Vector2(0.0, -1.0), right_p + Vector2(0.0, -1.0), cream, 1.0)
	# Ornamental brass end-knobs & central diamond fulcrum brooch
	for ep: Vector2 in [left_p, right_p]:
		draw_rect(Rect2(ep - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), void_c)
		draw_rect(Rect2(ep - Vector2.ONE, Vector2(2.0, 2.0)), accent)
		draw_rect(Rect2(ep - Vector2.ONE, Vector2(1.0, 1.0)), cream)
	draw_rect(Rect2(-2.0, -11.0, 4.0, 4.0), void_c)
	draw_rect(Rect2(-1.0, -10.0, 2.0, 2.0), accent)
	draw_rect(Rect2(-1.0, -10.0, 1.0, 1.0), cream)

	# Hanging chain pans on left & right ends
	for side: int in [-1, 1]:
		var bp: Vector2 = left_p if side < 0 else right_p
		var pan_y: float = bp.y + 6.0
		# Twin pixel-snapped suspension chains
		draw_line(bp + Vector2(0.0, 1.0), Vector2(bp.x - 3.0, pan_y), void_c, 2.0)
		draw_line(bp + Vector2(0.0, 1.0), Vector2(bp.x + 3.0, pan_y), void_c, 2.0)
		draw_line(bp + Vector2(0.0, 1.0), Vector2(bp.x - 3.0, pan_y), stone, 1.0)
		draw_line(bp + Vector2(0.0, 1.0), Vector2(bp.x + 3.0, pan_y), mauve, 1.0)
		# Sculpted curved brass weighing pan bowl
		draw_rect(Rect2(bp.x - 5.0, pan_y, 10.0, 3.0), void_c)
		draw_rect(Rect2(bp.x - 4.0, pan_y + 2.0, 8.0, 2.0), void_c)
		draw_rect(Rect2(bp.x - 4.0, pan_y + 1.0, 8.0, 1.0), accent if (weighing and side > 0) else gold)
		draw_rect(Rect2(bp.x - 3.0, pan_y + 2.0, 6.0, 1.0), apricot)
		draw_rect(Rect2(bp.x - 4.0, pan_y + 1.0, 3.0, 1.0), cream)

		if side < 0:
			# Carved obsidian & stone counterweight coin resting in left pan
			draw_rect(Rect2(bp.x - 2.0, pan_y - 2.0, 4.0, 3.0), void_c)
			draw_rect(Rect2(bp.x - 1.0, pan_y - 1.0, 2.0, 2.0), stone)
			draw_rect(Rect2(bp.x - 1.0, pan_y - 1.0, 1.0, 1.0), cream)
		elif weighing:
			# Clear tilted weight glow on right pan when weighing a setting or PAID
			var glow_r: float = 6.0 if paid else 5.0
			var ga: float = 0.48 if fr else (0.55 + 0.25 * absf(sin(_clock * 4.0)))
			draw_arc(Vector2(bp.x, pan_y - 1.0), glow_r, 0.0, TAU, 14, Color(accent, ga), 1.0)
			draw_rect(Rect2(bp.x - 3.0, pan_y - 2.0, 6.0, 3.0), coral if mode == "shop" or mode == "gate" else accent)
			draw_rect(Rect2(bp.x - 2.0, pan_y - 3.0, 4.0, 3.0), accent)
			draw_rect(Rect2(bp.x - 1.0, pan_y - 4.0, 2.0, 3.0), accent_hi)
			draw_rect(Rect2(bp.x, pan_y - 4.0, 1.0, 1.0), cream)

	# Weight pips inlaid along front stone plinth (raised lit pip vs flat recessed slot)
	var pips: int = mini(min_weight, 4) if mode == "gate" else 1
	var got_w: int = LxSold.current().get_toll_weight()
	var span: float = float(pips - 1) * 4.0
	for i: int in range(pips):
		var px: float = roundf(-span * 0.5 + float(i) * 4.0) - 1.0
		var lit_p: bool = paid or (mode == "gate" and i < got_w)
		draw_rect(Rect2(px - 1.0, 3.0, 4.0, 4.0), void_c)
		if lit_p:
			draw_rect(Rect2(px, 3.0, 2.0, 3.0), cream)
			draw_rect(Rect2(px, 5.0, 2.0, 1.0), accent)
		else:
			draw_rect(Rect2(px, 5.0, 2.0, 1.0), night)

	if _pulse_t > 0.0:
		var u: float = 1.0 - (_pulse_t / 0.55)
		draw_arc(Vector2(0.0, -5.0), roundf(6.0 + u * 18.0), 0.0, TAU, 16, Color(cream, (1.0 - u) * (0.55 if fr else 0.92)), 1.0)
	_draw_signal_pulses()
