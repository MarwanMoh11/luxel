class_name LxSanctumBellChain
extends LxToy
## Bell Sanctum r5 Eclipse Bell Chain Monument beside door_boss_8.
## Displays live status of the three deepened Sanctum trials:
##   - West Choir Seal (sanctum_seal_w from sanctum_r11 Hollow Wick Vigil)
##   - East Choir Seal (sanctum_seal_e from sanctum_r12 Rose-Window Seraph)
##   - Great Eclipse Bell (sanctum_bell_rung from sanctum_r13 Great Eclipse Belfry)
## Plus brass ledger pips reflecting Wick's Island 8 Sold Settings count.
## Once sanctum_bell_rung is set, interacting grants the Eclipse Bell Resonance Blessing
## (full heal, full Ember, +80 shards once) and emits power to linked threshold doors.

const CLAIMED_FLAG: String = "sanctum_bell_blessing_claimed"

var _flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "sanctum_bell_chain"
	radius = 18.0
	size = Vector2(28.0, 14.0)
	_flash_t = 0.0
	powered = _is_bell_rung()
	queue_redraw()


func _has_flag(fl: String) -> bool:
	return Lx.state != null and bool(Lx.state.story_flags.get(fl, false))


func _is_bell_rung() -> bool:
	return _has_flag("sanctum_bell_rung")


func _sold_count() -> int:
	if LxSold.current() != null:
		return LxSold.current().get_sold_count()
	if Lx.vars != null:
		return int(Lx.vars.get_var("game", "sold_count", 0))
	return 0


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-12.0, -4.0), Vector2(24.0, 10.0)) if active else Rect2()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_flash_t = 0.60
	if _is_bell_rung():
		set_powered(true)
		emit_power(true)
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			w.hp = Lx.state.max_hearts if Lx.state != null else w.hp
			w.ember = 1.0
		if Lx.state != null and not bool(Lx.state.story_flags.get(CLAIMED_FLAG, false)):
			Lx.state.story_flags[CLAIMED_FLAG] = true
			Lx.state.shards += 80
		_emit_sfx("sanctum_bell_toll")
		if Lx.events != null and LxStrings.has_id("ISL8_SC_CHAIN_READY"):
			Lx.events.narration_requested.emit("ISL8_SC_CHAIN_READY", "gold", 3.2)
	else:
		_emit_sfx("mirror_ping")
		if Lx.events != null and LxStrings.has_id("ISL8_SC_CHAIN_WAIT"):
			Lx.events.narration_requested.emit("ISL8_SC_CHAIN_WAIT", "narration", 3.0)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	var rung: bool = _is_bell_rung()
	if rung and not powered:
		set_powered(true)
		emit_power(true)
		queue_redraw()
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()


func get_interact_prompt() -> String:
	if not active:
		return ""
	return "ISL8_SC_PROMPT_CHAIN" if LxStrings.has_id("ISL8_SC_PROMPT_CHAIN") else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var lit_n: int = int(_has_flag("sanctum_seal_w")) + int(_has_flag("sanctum_seal_e")) + int(_is_bell_rung())
	return Vector4(pos.x, pos.y - 4.0, 26.0 + float(lit_n) * 9.0, 0.35 + float(lit_n) * 0.16)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var has_w: bool = _has_flag("sanctum_seal_w")
	var has_e: bool = _has_flag("sanctum_seal_e")
	var has_b: bool = _is_bell_rung()
	var sold_n: int = mini(6, _sold_count())

	draw_rect(Rect2(-13.0, -4.0, 26.0, 11.0), c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-12.0, -5.0, 24.0, 10.0), c_night, c_dusk, c_gold if has_b else c_sky, c_void)
	# Left Seal: West Vigil (amber/gold)
	draw_rect(Rect2(-10.0, -3.0, 5.0, 5.0), c_void)
	draw_rect(Rect2(-9.0, -2.0, 3.0, 3.0), c_apricot if has_w else c_night)
	# Center Seal: Great Eclipse Bell (gold/cream)
	draw_rect(Rect2(-3.0, -4.0, 6.0, 6.0), c_void)
	draw_rect(Rect2(-2.0, -3.0, 4.0, 4.0), c_gold if has_b else c_dusk)
	if has_b:
		draw_rect(Rect2(-1.0, -2.0, 2.0, 2.0), c_cream)
	# Right Seal: East Rose-Window Seraph (rose)
	draw_rect(Rect2(5.0, -3.0, 5.0, 5.0), c_void)
	draw_rect(Rect2(6.0, -2.0, 3.0, 3.0), c_rose if has_e else c_night)
	# Sold-settings brass pips along lower rim
	for i: int in range(6):
		var px: float = -10.0 + float(i) * 4.0
		draw_rect(Rect2(px, 3.0, 2.0, 1.0), c_gold if i < sold_n else c_dusk)
	if _flash_t > 0.0:
		draw_arc(Vector2.ZERO, roundf(lerpf(8.0, 24.0, 1.0 - _flash_t / 0.60)), 0.0, TAU, 18, c_cream, 1.4)
	_draw_signal_pulses()
