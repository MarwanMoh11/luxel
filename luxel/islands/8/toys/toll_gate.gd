class_name LxTollGate
extends LxToy
## Island 8 Toll Gate — barred brass archway that opens when Toll Weight, a Toll
## condition (`check`), or linked `requires_signals` (from toll_scale/toll_sensor) pass.
## Props: min_weight (int), check (String), size [w,h], requires_signals (Array),
##        allow_direct_pay (bool), persist (bool).

var opened: bool = false
var min_weight: int = 1
var check_expr: String = ""
var allow_direct_pay: bool = false
var required_signals: Array[String] = []
var _active_signals: Dictionary = {}
var _open_t: float = 0.0
var _rattle_t: float = 0.0
var _sold_ref: LxSold = null


func _toy_setup() -> void:
	size = LxMapFormat.to_vec2(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	min_weight = maxi(0, int(props.get("min_weight", 1)))
	check_expr = str(props.get("check", "")).strip_edges()
	allow_direct_pay = bool(props.get("allow_direct_pay", false))
	persist = bool(props.get("persist", true))
	opened = bool(props.get("opened", false))
	required_signals.clear()
	var req_v: Variant = props.get("requires_signals", [])
	if req_v is Array:
		for r: Variant in (req_v as Array):
			var rs: String = str(r).strip_edges()
			if not rs.is_empty():
				required_signals.append(rs)
	radius = maxf(size.x, size.y) * 0.5 + 4.0
	if Lx.state != null and not id.is_empty() and Lx.state.opened_doors.has(id):
		opened = true
		powered = true
	_bind_sold()
	_evaluate(false)
	queue_redraw()


func _exit_tree() -> void:
	_unbind_sold()


func is_solid() -> bool:
	return active and not opened


func is_solid_blocker() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_solid() else Rect2()


func tick(dt: float) -> void:
	super.tick(dt)
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt)
		queue_redraw()
	if _rattle_t > 0.0:
		_rattle_t = maxf(0.0, _rattle_t - dt)
		queue_redraw()


func on_signal(from_id: String, is_on: bool) -> void:
	if is_on:
		_active_signals[from_id] = true
	else:
		_active_signals.erase(from_id)
	_evaluate(true)


func interact(_actor: Node = null) -> bool:
	if not active or opened:
		return false
	if _conditions_met():
		_open_gate(true)
		return true
	if allow_direct_pay and LxIsland8Rule.active_instance != null:
		LxIsland8Rule.active_instance.open_toll_menu({
			"mode": "gate",
			"min_weight": maxi(1, min_weight),
			"source_id": id,
			"source_pos": pos,
		})
		return true
	_rattle_t = 0.24
	_emit_sfx("door_locked")
	queue_redraw()
	return false


func get_interact_prompt() -> String:
	if not active or opened:
		return ""
	return "ISL8_PROMPT_GATE_PAY" if allow_direct_pay else "ISL8_PROMPT_GATE_LOCKED"


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	d["opened"] = opened
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	opened = bool(d.get("opened", opened))
	if opened:
		powered = true
	_evaluate(false)
	queue_redraw()


func _conditions_met() -> bool:
	if not required_signals.is_empty():
		for req: String in required_signals:
			if not bool(_active_signals.get(req, false)):
				return false
		return true
	if not _active_signals.is_empty() and min_weight == 0 and check_expr.is_empty():
		return true
	var sold: LxSold = LxSold.current()
	if not check_expr.is_empty():
		return sold.eval_check(check_expr)
	if min_weight > 0:
		return sold.get_toll_weight() >= min_weight
	return not _active_signals.is_empty()


func _evaluate(play_fx: bool) -> void:
	if opened:
		return
	if _conditions_met():
		_open_gate(play_fx)


func _open_gate(play_fx: bool) -> void:
	if opened:
		return
	opened = true
	powered = true
	_open_t = 0.50 if play_fx else 0.0
	if persist and Lx.state != null and not id.is_empty() and not Lx.state.opened_doors.has(id):
		Lx.state.opened_doors.append(id)
	emit_power(true)
	if play_fx:
		_emit_sfx("door_open")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.14)
	queue_redraw()


func _on_sold_changed() -> void:
	_evaluate(true)
	queue_redraw()


func _bind_sold() -> void:
	_sold_ref = LxSold.current()
	if _sold_ref != null and not _sold_ref.state_changed.is_connected(_on_sold_changed):
		_sold_ref.state_changed.connect(_on_sold_changed)


func _unbind_sold() -> void:
	if _sold_ref != null and _sold_ref.state_changed.is_connected(_on_sold_changed):
		_sold_ref.state_changed.disconnect(_on_sold_changed)
	_sold_ref = null


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var fr: bool = LxHudFx.flash_reduced()
	var rdx: float = (1.0 if int(floorf(_rattle_t * 36.0)) % 2 == 0 else -1.0) if (_rattle_t > 0.0 and LxHudFx.shake_enabled() and not fr) else 0.0
	var x0: float = floorf(-w * 0.5) + rdx
	var y0: float = floorf(-h * 0.5)
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var stone: Color = PAL["stone"] as Color
	var wine: Color = PAL["wine"] as Color
	var coral: Color = PAL["coral"] as Color
	var apr: Color = PAL["apricot"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var horiz: bool = w >= h
	var post_w: float = minf(6.0, floorf((w if horiz else h) * 0.25))

	if opened:
		# Clean open grand forged-iron & brass toll posts with inlaid open threshold
		if horiz:
			draw_rect(Rect2(x0 + post_w, y0 + h - 3.0, maxf(2.0, w - post_w * 2.0), 2.0), Color(dusk, 0.45))
			_draw_gate_post(Rect2(x0, y0 - 2.0, post_w, h + 3.0), false)
			_draw_gate_post(Rect2(x0 + w - post_w, y0 - 2.0, post_w, h + 3.0), false)
		else:
			draw_rect(Rect2(x0 + 2.0, y0 + post_w, maxf(2.0, w - 4.0), maxf(2.0, h - post_w * 2.0)), Color(dusk, 0.35))
			_draw_gate_post(Rect2(x0 - 1.0, y0, w + 2.0, post_w), false)
			_draw_gate_post(Rect2(x0 - 1.0, y0 + h - post_w, w + 2.0, post_w), false)
		if _open_t > 0.0:
			var a: float = clampf(_open_t / 0.50, 0.0, 1.0)
			draw_arc(Vector2.ZERO, roundf(6.0 + (1.0 - a) * 18.0), 0.0, TAU, 16, Color(cream, a * (0.6 if fr else 1.0)), 1.2)
		return

	# Grounded barrier shadow
	draw_rect(Rect2(x0 + 1.0, y0 + h, w, 3.0), Color(void_c, 0.38))

	# Heavy forged-iron & brass crossbar & vertical/horizontal barrier bars
	draw_rect(Rect2(x0, y0, w, h), void_c)
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), night)
	if horiz:
		# Forged iron grille bars with steel highlight
		var bx: float = x0 + post_w + 1.0
		while bx < x0 + w - post_w - 1.0:
			draw_rect(Rect2(bx, y0 + 2.0, 2.0, h - 4.0), void_c)
			draw_rect(Rect2(bx, y0 + 2.0, 1.0, h - 4.0), dusk)
			draw_rect(Rect2(bx, y0 + 2.0, 1.0, 2.0), stone)
			bx += 4.0
		# Heavy riveted forged-iron & brass horizontal crossbar
		var cy: float = roundf(y0 + h * 0.5) - 3.0
		draw_rect(Rect2(x0 + post_w - 1.0, cy, w - post_w * 2.0 + 2.0, 6.0), void_c)
		draw_rect(Rect2(x0 + post_w, cy + 1.0, w - post_w * 2.0, 4.0), dusk)
		draw_rect(Rect2(x0 + post_w, cy + 1.0, w - post_w * 2.0, 1.0), gold)
		draw_rect(Rect2(x0 + post_w, cy + 4.0, w - post_w * 2.0, 1.0), apr)
		# Locked ember seal glow running along crossbar lock seams
		draw_rect(Rect2(x0 + post_w + 1.0, cy + 2.0, w - post_w * 2.0 - 2.0, 2.0), wine)
		draw_rect(Rect2(x0 + post_w + 2.0, cy + 2.0, w - post_w * 2.0 - 4.0, 1.0), coral)
		# Grand flanking forged-iron & brass toll posts
		_draw_gate_post(Rect2(x0, y0 - 2.0, post_w, h + 3.0), true)
		_draw_gate_post(Rect2(x0 + w - post_w, y0 - 2.0, post_w, h + 3.0), true)
	else:
		var by: float = y0 + post_w + 1.0
		while by < y0 + h - post_w - 1.0:
			draw_rect(Rect2(x0 + 2.0, by, w - 4.0, 2.0), void_c)
			draw_rect(Rect2(x0 + 2.0, by, w - 4.0, 1.0), dusk)
			by += 4.0
		var cx: float = roundf(x0 + w * 0.5) - 3.0
		draw_rect(Rect2(cx, y0 + post_w - 1.0, 6.0, h - post_w * 2.0 + 2.0), void_c)
		draw_rect(Rect2(cx + 1.0, y0 + post_w, 4.0, h - post_w * 2.0), dusk)
		draw_rect(Rect2(cx + 1.0, y0 + post_w, 1.0, h - post_w * 2.0), gold)
		draw_rect(Rect2(cx + 2.0, y0 + post_w + 1.0, 2.0, h - post_w * 2.0 - 2.0), wine)
		draw_rect(Rect2(cx + 2.0, y0 + post_w + 2.0, 1.0, h - post_w * 2.0 - 4.0), coral)
		_draw_gate_post(Rect2(x0 - 1.0, y0, w + 2.0, post_w), true)
		_draw_gate_post(Rect2(x0 - 1.0, y0 + h - post_w, w + 2.0, post_w), true)

	# Carved brass coin / balance crest medallion centered on the heavy crossbar
	var mc := Vector2(roundf(rdx), 0.0)
	draw_rect(Rect2(mc.x - 5.0, mc.y - 6.0, 10.0, 12.0), void_c)
	draw_rect(Rect2(mc.x - 6.0, mc.y - 5.0, 12.0, 10.0), void_c)
	draw_rect(Rect2(mc.x - 5.0, mc.y - 4.0, 10.0, 8.0), apr)
	draw_rect(Rect2(mc.x - 4.0, mc.y - 5.0, 8.0, 10.0), gold)
	draw_rect(Rect2(mc.x - 4.0, mc.y - 5.0, 6.0, 1.0), cream)
	draw_rect(Rect2(mc.x - 3.0, mc.y - 3.0, 6.0, 6.0), night)
	# Balance scale symbol inside coin medallion + glowing locked ember seal
	draw_rect(Rect2(mc.x - 2.0, mc.y - 2.0, 5.0, 1.0), cream)
	draw_rect(Rect2(mc.x, mc.y - 3.0, 1.0, 5.0), gold)
	draw_rect(Rect2(mc.x - 3.0, mc.y, 2.0, 1.0), gold)
	draw_rect(Rect2(mc.x + 2.0, mc.y, 2.0, 1.0), gold)
	draw_rect(Rect2(mc.x - 1.0, mc.y + 2.0, 3.0, 2.0), coral)
	draw_rect(Rect2(mc.x, mc.y + 2.0, 1.0, 1.0), cream if _rattle_t > 0.0 else apr)

	# Weight pips mounted in a neat brass ledger bar above gate
	var need_p: int = clampi(min_weight, 1, 5)
	var got_p: int = LxSold.current().get_toll_weight()
	var span: float = float(need_p - 1) * 4.0
	for i: int in range(need_p):
		var px: float = roundf(-span * 0.5 + float(i) * 4.0 + rdx) - 1.0
		var py: float = y0 - 4.0
		draw_rect(Rect2(px - 1.0, py - 1.0, 4.0, 4.0), void_c)
		draw_rect(Rect2(px, py, 2.0, 2.0), cream if i < got_p else dusk)
		if i < got_p:
			draw_rect(Rect2(px, py + 1.0, 2.0, 1.0), gold)


func _draw_gate_post(r: Rect2, locked_glow: bool) -> void:
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var stone: Color = PAL["stone"] as Color
	var coral: Color = PAL["coral"] as Color
	var apr: Color = PAL["apricot"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var pr := Rect2(r.position.round(), r.size.round())
	draw_rect(pr, void_c)
	if pr.size.x >= 3.0 and pr.size.y >= 3.0:
		draw_rect(Rect2(pr.position.x + 1.0, pr.position.y + 1.0, pr.size.x - 2.0, pr.size.y - 2.0), dusk)
		draw_rect(Rect2(pr.position.x + 1.0, pr.position.y + 1.0, 1.0, pr.size.y - 2.0), stone)
		draw_rect(Rect2(pr.end.x - 2.0, pr.position.y + 1.0, 1.0, pr.size.y - 2.0), night)
		# Brass collar bands & gilded crown finial
		draw_rect(Rect2(pr.position.x + 1.0, pr.position.y + 1.0, pr.size.x - 2.0, 2.0), gold)
		draw_rect(Rect2(pr.position.x + 1.0, pr.position.y + 1.0, maxf(1.0, pr.size.x - 3.0), 1.0), cream)
		draw_rect(Rect2(pr.position.x + 1.0, pr.end.y - 3.0, pr.size.x - 2.0, 1.0), apr)
		if locked_glow and pr.size.y >= 8.0:
			var my: float = roundf(pr.position.y + pr.size.y * 0.5)
			draw_rect(Rect2(pr.position.x + 1.0, my, pr.size.x - 2.0, 2.0), coral)
			draw_rect(Rect2(pr.position.x + 2.0, my, maxf(1.0, pr.size.x - 4.0), 1.0), gold)
