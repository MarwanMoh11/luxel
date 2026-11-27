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

var boss_door_id: String = "door_boss_8"
var _flash_t: float = 0.0
var _boss_locked: bool = false


func _toy_setup() -> void:
	kind = "sanctum_bell_chain"
	radius = 22.0
	size = Vector2(40.0, 14.0)
	boss_door_id = str(props.get("boss_door_id", "door_boss_8")).strip_edges()
	_flash_t = 0.0
	_boss_locked = false
	powered = _is_bell_rung()
	_sync_boss_door_lock()
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


func _sync_boss_door_lock() -> void:
	if region == null or boss_door_id.is_empty():
		return
	var bd: LxInteractable = region.find_interactable(boss_door_id)
	if bd == null or not bd.has_method("set_script_locked"):
		return
	var want_lock: bool = active and not _is_bell_rung()
	if want_lock and not _boss_locked:
		bd.call("set_script_locked", true)
		_boss_locked = true
	elif not want_lock and _boss_locked:
		bd.call("set_script_locked", false)
		_boss_locked = false


func is_solid() -> bool:
	return active and not _is_bell_rung()


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-20.0, -7.0), Vector2(40.0, 14.0)) if is_solid() else Rect2()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	if _is_bell_rung() and _has_flag(CLAIMED_FLAG):
		return false
	_flash_t = 0.60
	if _is_bell_rung():
		set_powered(true)
		emit_power(true)
		if Lx.state != null:
			Lx.state.heal_full()
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			w.ember = Lx.state.get_effective_ember_max() if Lx.state != null else 100.0
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
	_sync_boss_door_lock()
	var rung: bool = _is_bell_rung()
	if rung and not powered:
		set_powered(true)
		emit_power(true)
		queue_redraw()
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()


func get_interact_prompt() -> String:
	if not active or (_is_bell_rung() and _has_flag(CLAIMED_FLAG)):
		return ""
	return "ISL8_SC_PROMPT_CHAIN" if LxStrings.has_id("ISL8_SC_PROMPT_CHAIN") else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var lit_n: int = int(_has_flag("sanctum_seal_w")) + int(_has_flag("sanctum_seal_e")) + int(_is_bell_rung())
	return Vector4(pos.x, pos.y - 4.0, 30.0 + float(lit_n) * 10.0, 0.42 + float(lit_n) * 0.16)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var has_w: bool = _has_flag("sanctum_seal_w")
	var has_e: bool = _has_flag("sanctum_seal_e")
	var has_b: bool = _is_bell_rung()
	var claimed_b: bool = _has_flag(CLAIMED_FLAG)
	var fred: bool = LxHudFx.flash_reduced()
	var sold_n: int = mini(6, _sold_count())

	# Left & Right wing-seal stanchion posts framing the boss threshold
	for side: int in [-1, 1]:
		var sx: float = float(side) * 18.0
		draw_rect(Rect2(sx - 4.0, -5.0, 8.0, 12.0), c_void)
		draw_rect(Rect2(sx - 3.0, -4.0, 6.0, 10.0), c_dusk)
		draw_rect(Rect2(sx - 2.0, -3.0, 4.0, 8.0), c_plum if has_b else c_night)
		var seal_on: bool = has_w if side < 0 else has_e
		var seal_c: Color = (c_apricot if side < 0 else c_rose) if seal_on else c_dusk
		draw_rect(Rect2(sx - 2.0, -2.0, 4.0, 4.0), c_void)
		if seal_on:
			draw_rect(Rect2(sx - 1.0, -1.0, 2.0, 2.0), c_cream)
			draw_rect(Rect2(sx - 1.0, -7.0, 2.0, 2.0), seal_c)
		else:
			draw_rect(Rect2(sx - 2.0, -1.0, 4.0, 1.0), c_dusk)
		# Wing pointer pips on stanchion cap
		draw_rect(Rect2(sx - 2.0, -5.0, 4.0, 1.0), c_gold if (has_b or seal_on) else c_mauve)

	if not has_b:
		# Twin heavy iron chains stretched across the boss archway holding THE SILENT BELL
		draw_line(Vector2(-15.0, -1.0), Vector2(15.0, -1.0), c_void, 4.0)
		for cx: int in range(-14, 15, 4):
			draw_rect(Rect2(float(cx), -2.0, 3.0, 2.0), c_mauve if (cx / 4) % 2 == 0 else c_dusk)
		# Center darkened Silent Bell emblem (unmistakable silhouette + coral silence bar)
		draw_rect(Rect2(-8.0, -9.0, 16.0, 16.0), c_void)
		draw_rect(Rect2(-5.0, -8.0, 10.0, 3.0), c_dusk)
		draw_rect(Rect2(-6.0, -5.0, 12.0, 7.0), c_dusk)
		draw_rect(Rect2(-7.0, 2.0, 14.0, 2.0), c_mauve)
		draw_rect(Rect2(-4.0, -6.0, 2.0, 6.0), c_mauve)
		draw_rect(Rect2(-1.0, 4.0, 2.0, 2.0), c_night) # silent clapper
		# Coral silence slash across the silent bell
		draw_line(Vector2(-6.0, -6.0), Vector2(6.0, 4.0), c_coral, 2.0)
		# Directional wing arrows (< W | E >) beneath chains
		draw_rect(Rect2(-12.0, 3.0, 3.0, 1.0), c_apricot if has_w else c_gold)
		draw_rect(Rect2(9.0, 3.0, 3.0, 1.0), c_rose if has_e else c_gold)
	else:
		# Parted chains + radiant golden rung bell crest on stanchions (path wide open)
		for bx: float in [-22.0, 14.0]:
			draw_rect(Rect2(bx, -11.0, 8.0, 6.0), c_void)
			draw_rect(Rect2(bx + 1.0, -10.0, 6.0, 4.0), c_gold)
			draw_rect(Rect2(bx + 2.0, -9.0, 2.0, 2.0), c_cream if not claimed_b else c_apricot)
			if not claimed_b:
				draw_rect(Rect2(bx + 3.0, -13.0, 2.0, 2.0), c_cream)

	# Sold-settings brass pips along lower stanchions
	for i: int in range(6):
		var px: float = (-21.0 + float(i) * 2.0) if i < 3 else (15.0 + float(i - 3) * 2.0)
		draw_rect(Rect2(px, 5.0, 1.0, 1.0), c_gold if i < sold_n else c_dusk)
	if _flash_t > 0.0:
		var u: float = 1.0 - clampf(_flash_t / 0.60, 0.0, 1.0)
		var fa: float = (1.0 - u) * (0.50 if fred else 0.90)
		var fc: Color = Color(c_cream if has_b else c_coral, fa)
		draw_arc(Vector2.ZERO, roundf(lerpf(8.0, 24.0, u)), 0.0, TAU, 18, fc, 1.0 if fred else 2.0)
	_draw_signal_pulses()
