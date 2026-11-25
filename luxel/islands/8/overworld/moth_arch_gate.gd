class_name LxMothArchGate
extends LxToy
## Island 8 Vigil Terrace — THE 80-MOTH ARCH guarding `superboss_first_dark`.
## Renders an obsidian eclipse arch ringed by 8 constellation pips (1 per 10 moths).
## Opens when Island 8 is relit (`great_lamp_8` / `island_8_relit`) AND all 80 Lost Moths
## are rescued (or `moths_80_override` story flag is set for testing).

const REQUIRED_MOTHS: int = 80

var opened: bool = false
var _open_t: float = 0.0
var _rattle_t: float = 0.0
var _moth_count: int = 0


func _toy_setup() -> void:
	kind = "moth_arch_gate"
	size = LxMapFormat.to_vec2(props.get("size", [48.0, 16.0]), Vector2(48.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5 + 8.0
	persist = bool(props.get("persist", true))
	opened = bool(props.get("opened", false))
	if Lx.state != null and not id.is_empty() and Lx.state.opened_doors.has(id):
		opened = true
	_evaluate(false)
	queue_redraw()


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
	if active and not opened:
		var mc: int = LxQuests.current().get_moth_count()
		if mc != _moth_count:
			_moth_count = mc
			queue_redraw()
		_evaluate(true)


func interact(_actor: Node = null) -> bool:
	if not active or opened:
		return false
	if _requirements_met():
		_open_arch(true)
		return true
	_rattle_t = 0.26
	_emit_sfx("door_locked")
	if Lx.events != null and LxStrings.has_id("ISL8_Q4_DARK"):
		Lx.events.narration_requested.emit("ISL8_Q4_DARK", "narration", 3.4)
	queue_redraw()
	return false


func get_interact_prompt() -> String:
	return "" if (not active or opened) else "ISL8_PROMPT_MOTH_ARCH"


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 62.0 if opened else 36.0, 0.92 if opened else 0.45)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	d["opened"] = opened
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	opened = bool(d.get("opened", opened))
	_evaluate(false)
	queue_redraw()


func _requirements_met() -> bool:
	if Lx.state == null:
		return false
	if bool(Lx.state.story_flags.get("moths_80_override", false)):
		return true
	var relit: bool = Lx.state.relit_islands.has(8) or bool(Lx.state.story_flags.get("great_lamp_8", false)) or bool(Lx.state.story_flags.get("island_8_relit", false))
	_moth_count = LxQuests.current().get_moth_count()
	return relit and _moth_count >= REQUIRED_MOTHS


func _evaluate(play_fx: bool) -> void:
	_moth_count = LxQuests.current().get_moth_count()
	if opened:
		return
	if _requirements_met():
		_open_arch(play_fx)


func _open_arch(play_fx: bool) -> void:
	if opened:
		return
	opened = true
	powered = true
	_open_t = 0.65 if play_fx else 0.0
	if Lx.state != null:
		Lx.state.story_flags["moth_arch_80_opened"] = true
		if persist and not id.is_empty() and not Lx.state.opened_doors.has(id):
			Lx.state.opened_doors.append(id)
	emit_power(true)
	if play_fx:
		_emit_sfx("seal_break")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.22)
			Lx.events.save_requested.emit("moth_arch_80_opened")
	queue_redraw()


func _draw() -> void:
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var rdx: float = (1.0 if int(floorf(_rattle_t * 36.0)) % 2 == 0 else -1.0) if (_rattle_t > 0.0 and LxHudFx.shake_enabled()) else 0.0
	var x0: float = floorf(-w * 0.5) + rdx
	var y0: float = floorf(-h * 0.5)
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var dusk: Color = PAL["dusk"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var lit_tiers: int = mini(8, _moth_count / 10)

	if opened:
		draw_rect(Rect2(x0, y0, 6.0, h), void_c)
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, 4.0, h - 2.0), dusk)
		draw_rect(Rect2(x0 + 4.0, y0 + 1.0, 1.0, h - 2.0), cream)
		draw_rect(Rect2(x0 + w - 6.0, y0, 6.0, h), void_c)
		draw_rect(Rect2(x0 + w - 5.0, y0 + 1.0, 4.0, h - 2.0), dusk)
		draw_rect(Rect2(x0 + w - 5.0, y0 + 1.0, 1.0, h - 2.0), cream)
		if _open_t > 0.0:
			var u: float = 1.0 - clampf(_open_t / 0.65, 0.0, 1.0)
			draw_arc(Vector2.ZERO, roundf(10.0 + u * 30.0), 0.0, TAU, 20, Color(gold, 1.0 - u), 1.5)
		return

	draw_rect(Rect2(x0, y0 + h, w, 2.0), void_c)
	draw_rect(Rect2(x0, y0, w, h), void_c)
	draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), night)
	draw_rect(Rect2(x0 + 2.0, y0 + 2.0, w - 4.0, h - 4.0), PAL["plum"] as Color)
	# 8 moth constellation pips (10 moths each)
	for i: int in range(8):
		var px: float = roundf(-18.0 + float(i) * 5.0 + rdx)
		var lit_p: bool = i < lit_tiers
		draw_rect(Rect2(px - 1.0, -2.0, 3.0, 4.0), void_c)
		draw_rect(Rect2(px, -1.0, 1.0, 2.0), cream if lit_p else dusk)
	# Central moth glyph
	draw_rect(Rect2(-3.0 + rdx, -6.0, 6.0, 2.0), gold if lit_tiers >= 8 else dusk)
