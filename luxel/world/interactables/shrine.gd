class_name LxShrine
extends LxInteractable
## Move Shrine: unlocks props.move_id, emits shrine_claimed + save_requested.

var claimed: bool = false
var move_id: String = ""
var _claim_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "shrine"
	move_id = str(props.get("move_id", ""))
	claimed = bool(props.get("claimed", false))
	if Lx.state != null:
		if Lx.state.claimed_shrines.has(id) or (not move_id.is_empty() and Lx.state.has_move(move_id)):
			claimed = true
	queue_redraw()


func tick(dt: float) -> void:
	_uses_prop_anim = not claimed
	super.tick(dt)
	if _claim_t > 0.0:
		_claim_t = maxf(0.0, _claim_t - dt)
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or claimed:
		return false
	claimed = true
	_claim_t = 0.65
	if Lx.state != null:
		if not move_id.is_empty():
			Lx.state.unlock_move(move_id)
		if not id.is_empty() and not Lx.state.claimed_shrines.has(id):
			Lx.state.claimed_shrines.append(id)
	if Lx.events != null:
		Lx.events.shrine_claimed.emit(id, move_id)
		Lx.events.shake_requested.emit(0.14)
	if Lx.hitstop != null:
		Lx.hitstop.trigger(0.06)
	_emit_gust(108.0, 92.0, Vector2(0.0, -10.0))
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 18.0, 8.0)
	_emit_sfx("shrine_claimed")
	var accent_sfx: String = _move_accent_sfx()
	if not accent_sfx.is_empty() and Lx.audio != null:
		Lx.audio.play_sfx(accent_sfx, pos, true)
	_emit_save("shrine_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if _claim_t > 0.0:
		var surge: float = sin((1.0 - clampf(_claim_t / 0.65, 0.0, 1.0)) * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)
		return Vector4(pos.x, pos.y - 10.0, 42.0 + surge * 74.0, 0.72 + surge * 0.85)
	if not claimed:
		return Vector4(pos.x, pos.y - 10.0, 68.0, 1.15)
	return Vector4(pos.x, pos.y - 8.0, 42.0, 0.72)


func get_interact_prompt() -> String:
	return "" if claimed else "PROMPT_CLAIM_SHRINE"


func save_state() -> Dictionary:
	return {"active": active, "claimed": claimed}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	claimed = bool(d.get("claimed", claimed))
	if Lx.state != null and Lx.state.claimed_shrines.has(id):
		claimed = true
	queue_redraw()


func _draw() -> void:
	var shadow: Color = PAL["void"] as Color
	draw_rect(Rect2(-12.0, 2.0, 24.0, 2.0), shadow)
	draw_rect(Rect2(-10.0, 1.0, 20.0, 4.0), shadow)
	draw_rect(Rect2(-7.0, 0.0, 14.0, 5.0), shadow)
	var is_throw: bool = move_id == "throw"
	var colors: Array[Color] = _move_palette()
	var c_main: Color = colors[0]
	var c_hi: Color = colors[1]
	if not claimed:
		_draw_floor_ring(false, c_main, c_hi)
	var prop_key: String = "shrine_throw" if is_throw else "shrine"
	var frame_ov: int = 0 if claimed else -1
	var tint: Color = (PAL["mauve"] as Color) if claimed else Color.WHITE
	if not _draw_prop_sprite(prop_key, Vector2.ZERO, frame_ov, tint):
		_draw_fallback()
	if not claimed:
		_draw_floor_ring(true, c_main, c_hi)
		_draw_move_emblem(c_main, c_hi)
		_draw_starlight_motes(c_main, c_hi)
	else:
		# Sacred memory spark gently orbiting the claimed Shrine pedestal
		var fred_s: bool = LxHudFx.flash_reduced()
		var ma: float = _clock * (0.65 if fred_s else 1.25)
		var mp := Vector2(roundf(cos(ma) * 9.0), roundf(-16.0 + sin(ma) * 3.0))
		draw_rect(Rect2(mp, Vector2(2.0, 1.0)), Color(c_main, 0.65))
		draw_rect(Rect2(mp, Vector2.ONE), Color(c_hi, 0.85))
	if _claim_t > 0.0:
		_draw_claim_burst(c_main, c_hi)
	_draw_signal_pulses()


func _move_palette() -> Array[Color]:
	match move_id:
		"dash":
			return [PAL["apricot"] as Color, PAL["gold"] as Color]
		"throw":
			return [PAL["gold"] as Color, PAL["cream"] as Color]
		"prism":
			return [PAL["sky"] as Color, PAL["ice"] as Color]
		"beam":
			return [PAL["jade"] as Color, PAL["lime"] as Color]
		"wings":
			return [PAL["rose"] as Color, PAL["cream"] as Color]
		"lens":
			return [PAL["gold"] as Color, PAL["sky"] as Color]
		"sunflare":
			return [PAL["coral"] as Color, PAL["gold"] as Color]
		_:
			return [PAL["sky"] as Color, PAL["ice"] as Color]


func _move_accent_sfx() -> String:
	match move_id:
		"prism":
			return "prism_chain"
		"beam":
			return "prop_chime"
		"wings":
			return "wing_gale"
		"lens":
			return "phantom_phase"
		"sunflare":
			return "forge_gust"
		_:
			return ""


func _draw_move_emblem(c_main: Color, c_hi: Color) -> void:
	var cy: float = -24.0 + roundf(sin(_clock * 2.6) * 1.5)
	match move_id:
		"dash": # Twin glowing flare-dash chevrons streaking right
			var sx: float = roundf(sin(_clock * 4.5) * 2.0)
			for ci: int in range(2):
				var ox: float = sx + float(ci) * 5.0 - 3.0
				var col: Color = c_hi if ci == 1 else c_main
				draw_line(Vector2(ox - 2.0, cy - 3.0), Vector2(ox + 1.0, cy), col, 1.0)
				draw_line(Vector2(ox - 2.0, cy + 3.0), Vector2(ox + 1.0, cy), col, 1.0)
		"throw": # Tiny suspended brass lantern swaying gently above the shrine
			var sw: float = roundf(sin(_clock * 3.0) * 1.5)
			draw_rect(Rect2(sw - 1.0, cy - 4.0, 3.0, 1.0), c_main)
			draw_rect(Rect2(sw - 2.0, cy - 3.0, 5.0, 5.0), c_main)
			draw_rect(Rect2(sw - 1.0, cy - 2.0, 3.0, 3.0), c_hi)
			draw_rect(Rect2(sw, cy - 1.0, 1.0, 1.0), PAL["cream"] as Color)
			draw_rect(Rect2(sw - 1.0, cy + 2.0, 3.0, 1.0), c_main)
		"prism": # Rotating 3-vertex diamond prism ring
			for k: int in range(3):
				var a: float = _clock * 2.2 + float(k) * (TAU / 3.0)
				var pt := Vector2(roundf(cos(a) * 9.0), roundf(cy + sin(a) * 4.0))
				draw_rect(Rect2(pt, Vector2(2.0, 2.0)), c_hi if k == 0 else c_main)
		"beam": # Focused vertical emerald-gold spire aura
			draw_line(Vector2(0.0, cy - 10.0), Vector2(0.0, cy + 6.0), Color(c_main, 0.72), 2.0)
			draw_line(Vector2(0.0, cy - 12.0), Vector2(0.0, cy + 4.0), c_hi, 1.0)
		"wings": # Fluttering dual-wing motes
			var fl: float = roundf(sin(_clock * 6.5) * 2.0)
			draw_rect(Rect2(-9.0, cy + fl, 3.0, 2.0), c_main)
			draw_rect(Rect2(6.0, cy + fl, 3.0, 2.0), c_main)
			draw_rect(Rect2(-7.0, cy + fl - 1.0, 2.0, 1.0), c_hi)
			draw_rect(Rect2(5.0, cy + fl - 1.0, 2.0, 1.0), c_hi)
		"lens": # Counter-rotating golden/sky astrolabe halo
			draw_arc(Vector2(0.0, cy), 8.0, _clock * 2.4, _clock * 2.4 + 2.2, 10, c_main, 1.2)
			draw_arc(Vector2(0.0, cy), 8.0, -_clock * 2.4, -_clock * 2.4 + 2.2, 10, c_hi, 1.2)
		"sunflare": # Blazing solar corona flares
			for k: int in range(6):
				var a: float = _clock * 1.8 + float(k) * (TAU / 6.0)
				var p0 := Vector2(cos(a) * 5.0, cy + sin(a) * 5.0).round()
				var p1 := Vector2(cos(a) * 10.0, cy + sin(a) * 10.0).round()
				draw_line(p0, p1, c_hi if k % 2 == 0 else c_main, 1.0)


func _draw_fallback() -> void:
	draw_rect(Rect2(-8.0, -3.0, 16.0, 7.0), PAL["night"])
	draw_rect(Rect2(-6.0, -12.0, 12.0, 11.0), PAL["mauve"])
	draw_rect(Rect2(-5.0, -11.0, 10.0, 9.0), PAL["stone"])
	if not claimed:
		draw_circle(Vector2(0.0, -14.0), 4.5, PAL["apricot"])
		draw_circle(Vector2(0.0, -14.0), 2.5, PAL["gold"])
		draw_circle(Vector2(0.0, -14.0), 1.2, PAL["cream"])
	else:
		draw_rect(Rect2(-3.0, -13.0, 6.0, 3.0), PAL["dusk"])


func _draw_floor_ring(front: bool, c_main: Color, c_hi: Color) -> void:
	for i: int in range(6):
		var a: float = _clock * 0.85 + (TAU * float(i)) / 6.0
		var sa: float = sin(a)
		if (sa >= 0.0) != front:
			continue
		var px: float = roundf(cos(a) * 14.0)
		var py: float = roundf(1.0 + sa * 5.0)
		draw_rect(Rect2(px, py, 2.0, 1.0), c_hi if (i % 2 == 0) else c_main)


func _draw_starlight_motes(c_main: Color, c_hi: Color) -> void:
	for i: int in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var phase: float = float(i) * PI
		var px: float = roundf(side * (10.0 + sin(_clock * 1.4 + phase) * 1.5))
		var py: float = roundf(-25.0 + sin(_clock * 2.4 + phase) * 2.5)
		draw_rect(Rect2(px, py, 1.0, 1.0), c_hi)
		if sin(_clock * 4.2 + phase) > 0.35:
			draw_rect(Rect2(px + side, py, 1.0, 1.0), c_main)


func _draw_claim_burst(c_main: Color, c_hi: Color) -> void:
	var p: float = 1.0 - clampf(_claim_t / 0.65, 0.0, 1.0)
	var col_w: float = roundf(maxf(0.0, (1.0 - p) * 10.0))
	if col_w >= 2.0:
		draw_rect(Rect2(-floorf(col_w * 0.5), -44.0, col_w, 46.0), c_main)
	if p < 0.72:
		draw_rect(Rect2(-1.0, -44.0, 2.0, 46.0), c_hi)
	draw_arc(Vector2(0.0, -6.0), roundf(6.0 + p * 26.0), 0.0, TAU, 20, c_hi if p < 0.35 else c_main, 1.0)
	for i: int in range(8):
		var a: float = float(i) * TAU / 8.0 + p * 1.4
		var d: float = roundf(5.0 + p * 24.0)
		var pt := Vector2(roundf(cos(a) * d), roundf(-10.0 + sin(a) * d * 0.55 - p * 14.0))
		draw_rect(Rect2(pt, Vector2(2.0 if p < 0.4 else 1.0, 2.0 if p < 0.4 else 1.0)), c_hi if i % 2 == 0 else c_main)
