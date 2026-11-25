class_name LxHudCeremony
extends RefCounted
## Short skippable Boss Intro Cards, Reward Ceremonies, "Previously..." continue icon bar,
## and the soft diegetic "Next Light" mote cue (idle outdoors every 6-8 s, toggleable in Options).

const BOSS_INTRO_DUR: float = 2.0
const REWARD_DUR: float = 1.9
const PREV_DUR: float = 4.6
const IDLE_BEFORE_MOTE_S: float = 1.2
const MOTE_INTERVAL_S: float = 6.8
const MOTE_FLIGHT_S: float = 1.45

var boss_intro: Dictionary = {"active": false, "t": 0.0, "dur": BOSS_INTRO_DUR, "name": "", "boss_id": "", "island": 1, "phases": 2}
var reward_card: Dictionary = {"active": false, "t": 0.0, "dur": REWARD_DUR, "icon": "lantern", "title": "", "accent": "gold", "sub_icons": []}
var prev_bar: Dictionary = {"active": false, "t": 0.0, "dur": PREV_DUR, "icons": []}

var _idle_s: float = 0.0
var _mote_cd: float = 1.0
var _mote_t: float = -1.0
var _mote_dir: Vector2 = Vector2.ZERO
var _mote_origin: Vector2 = Vector2.ZERO
var _last_player_pos: Vector2 = Vector2.ZERO
var _boss_sheets: Dictionary = {}


func reset() -> void:
	boss_intro["active"] = false
	reward_card["active"] = false
	prev_bar["active"] = false
	_idle_s = 0.0
	_mote_t = -1.0
	_mote_cd = 1.5


func trigger_boss_intro(boss_id: String, name_key: String, phase_count: int = 2) -> void:
	var nm: String = LxFolkData.tr_id(name_key) if LxFolkData.has_str(name_key) else LxStrings.sanitize(boss_id, 22)
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	boss_intro = {
		"active": true, "t": 0.0, "dur": BOSS_INTRO_DUR,
		"name": nm, "boss_id": boss_id, "island": isl, "phases": maxi(1, phase_count),
	}


func trigger_reward(icon_id: String, title_id: String, accent_col: String = "gold", sub_icons: Array[String] = []) -> void:
	var txt: String = LxFolkData.tr_id(title_id) if LxFolkData.has_str(title_id) else LxStrings.sanitize(title_id, 26)
	reward_card = {
		"active": true, "t": 0.0, "dur": REWARD_DUR,
		"icon": icon_id, "title": txt,
		"accent": accent_col if LxPalette.is_valid_color(accent_col) else "gold",
		"sub_icons": sub_icons.duplicate(),
	}


func trigger_previously(icons: Array[String]) -> void:
	if icons.is_empty():
		return
	prev_bar = {"active": true, "t": 0.0, "dur": PREV_DUR, "icons": icons.duplicate()}


func trigger_mote_now(dir: Vector2, screen_origin: Vector2) -> void:
	if dir.length_squared() < 0.01:
		return
	_mote_dir = dir.normalized()
	_mote_origin = screen_origin
	_mote_t = 0.0
	_mote_cd = MOTE_INTERVAL_S


func has_skippable() -> bool:
	return bool(boss_intro.get("active", false)) or bool(reward_card.get("active", false)) or bool(prev_bar.get("active", false))


func try_skip(event: InputEvent) -> bool:
	if not has_skippable():
		return false
	var is_press: bool = false
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kc: Key = (event as InputEventKey).keycode
		is_press = kc in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE, KEY_E]
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		is_press = (event as InputEventJoypadButton).button_index in [JOY_BUTTON_A, JOY_BUTTON_B]
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		is_press = true
	if not is_press:
		return false
	if bool(boss_intro.get("active", false)) and float(boss_intro.get("t", 0.0)) >= 0.25:
		boss_intro["active"] = false
		return true
	if bool(reward_card.get("active", false)) and float(reward_card.get("t", 0.0)) >= 0.22:
		reward_card["active"] = false
		return true
	if bool(prev_bar.get("active", false)) and float(prev_bar.get("t", 0.0)) >= 0.35:
		prev_bar["active"] = false
		return true
	return false


func tick(delta: float, boss_active: bool) -> void:
	if bool(boss_intro.get("active", false)):
		boss_intro["t"] = float(boss_intro["t"]) + delta
		if float(boss_intro["t"]) >= float(boss_intro["dur"]):
			boss_intro["active"] = false
	if bool(reward_card.get("active", false)):
		reward_card["t"] = float(reward_card["t"]) + delta
		if float(reward_card["t"]) >= float(reward_card["dur"]):
			reward_card["active"] = false
	if bool(prev_bar.get("active", false)):
		prev_bar["t"] = float(prev_bar["t"]) + delta
		if float(prev_bar["t"]) >= float(prev_bar["dur"]):
			prev_bar["active"] = false
	_tick_next_light_mote(delta, boss_active)


func _tick_next_light_mote(delta: float, boss_active: bool) -> void:
	if _mote_t >= 0.0:
		_mote_t += delta
		if _mote_t >= MOTE_FLIGHT_S:
			_mote_t = -1.0
	if boss_active or not LxUiNav.is_next_light_cue_enabled():
		_idle_s = 0.0
		return
	if Lx.player == null or not is_instance_valid(Lx.player) or not (Lx.player is Node2D):
		return
	var ppos: Vector2 = (Lx.player as Node2D).global_position
	if ppos.distance_squared_to(_last_player_pos) > 1.0:
		_last_player_pos = ppos
		_idle_s = 0.0
		return
	_idle_s += delta
	_mote_cd = maxf(0.0, _mote_cd - delta)
	if _idle_s >= IDLE_BEFORE_MOTE_S and _mote_cd <= 0.0 and _mote_t < 0.0:
		var dir: Vector2 = LxUiNav.compute_pin_world_dir()
		if dir.length_squared() > 0.01:
			var sp: Vector2 = ppos - Lx.camera.global_position + Vector2(160.0, 90.0) if Lx.camera != null else Vector2(160.0, 90.0)
			trigger_mote_now(dir, sp)


func draw(ci: CanvasItem) -> void:
	_draw_next_light_mote(ci)
	if bool(prev_bar.get("active", false)):
		_draw_previously_bar(ci)
	if bool(reward_card.get("active", false)):
		_draw_reward_ceremony(ci)
	if bool(boss_intro.get("active", false)):
		_draw_boss_intro(ci)


func _draw_next_light_mote(ci: CanvasItem) -> void:
	if _mote_t < 0.0 or _mote_t >= MOTE_FLIGHT_S:
		return
	var u: float = clampf(_mote_t / MOTE_FLIGHT_S, 0.0, 1.0)
	var fade: float = minf(u / 0.22, (1.0 - u) / 0.30)
	var col: Color = LxPalette.fade_step(fade, "gold")
	if col.a <= 0.0:
		return
	var fr: bool = LxHudFx.flash_reduced()
	var perp := Vector2(-_mote_dir.y, _mote_dir.x)
	var sway: float = 0.0 if fr else sin(u * TAU * 1.5) * 2.5
	var dist: float = lerpf(10.0, 38.0, 1.0 - pow(1.0 - u, 2.0))
	var head: Vector2 = (_mote_origin + _mote_dir * dist + perp * sway).round()
	# Soft trailing dust flecks
	for ti: int in range(1, 4):
		var tu: float = maxf(0.0, u - float(ti) * 0.09)
		var td: float = lerpf(10.0, 38.0, 1.0 - pow(1.0 - tu, 2.0))
		var tsway: float = 0.0 if fr else sin(tu * TAU * 1.5) * 2.5
		var tp: Vector2 = (_mote_origin + _mote_dir * td + perp * tsway).round()
		var tc: Color = LxPalette.fade_step(fade * (1.0 - float(ti) * 0.24), "apricot")
		if tc.a > 0.0:
			ci.draw_rect(Rect2(tp, Vector2.ONE), tc)
	ci.draw_rect(Rect2(head - Vector2.ONE, Vector2(4.0, 4.0)), Color(LxPalette.PAL["void"] as Color, 0.45))
	ci.draw_rect(Rect2(head, Vector2(2.0, 2.0)), col)
	if fade > 0.45:
		ci.draw_rect(Rect2(head, Vector2.ONE), LxPalette.PAL["cream"] as Color)


func _draw_boss_intro(ci: CanvasItem) -> void:
	var t: float = float(boss_intro["t"])
	var dur: float = float(boss_intro["dur"])
	var fade: float = minf(t / 0.22, (dur - t) / 0.30)
	var isl: int = clampi(int(boss_intro.get("island", 1)), 1, 8)
	var pal: Dictionary = LxPalette.PAL
	var bar_h: float = roundf(12.0 * clampf(fade * 1.4, 0.0, 1.0))
	if bar_h > 0.0:
		ci.draw_rect(Rect2(0.0, 0.0, 320.0, bar_h), pal["void"] as Color)
		ci.draw_rect(Rect2(0.0, 180.0 - bar_h, 320.0, bar_h), pal["void"] as Color)
	var card := Rect2(44.0, 56.0, 232.0, 48.0)
	ci.draw_rect(Rect2(card.position + Vector2(2.0, 2.0), card.size), pal["void"] as Color)
	LxPixelFont.draw_panel(ci, card, "night", LxBiomePalette.key(isl, "border"), "void")
	var glow: Color = LxBiomePalette.col(isl, "glow")
	ci.draw_rect(Rect2(card.position.x + 12.0, card.position.y + 4.0, card.size.x - 24.0, 1.0), glow)
	ci.draw_rect(Rect2(card.position.x + 12.0, card.end.y - 5.0, card.size.x - 24.0, 1.0), glow)
	LxHudFx.draw_biome_crest(ci, isl, Vector2(card.position.x + 14.0, card.get_center().y), glow, pal["cream"] as Color)
	LxHudFx.draw_biome_crest(ci, isl, Vector2(card.end.x - 15.0, card.get_center().y), glow, pal["cream"] as Color)
	var nm: String = str(boss_intro.get("name", ""))
	var sc: int = 2 if nm.length() <= 14 else 1
	var ny: float = 69.0 if sc == 2 else 73.0
	LxPixelFont.draw_faded(ci, nm, Vector2(160.0, ny), fade, "gold", sc, HORIZONTAL_ALIGNMENT_CENTER)
	# Phase pips under boss name
	var ph: int = clampi(int(boss_intro.get("phases", 2)), 1, 4)
	var px0: float = roundf(160.0 - float(ph * 6 - 2) * 0.5)
	for pi: int in range(ph):
		ci.draw_rect(Rect2(px0 + float(pi * 6), 88.0, 4.0, 2.0), pal["coral"] as Color)
	if t >= 0.30:
		LxPixelFont.draw_right(ci, LxStrings.text("INTRO_SKIP"), card.end.x - 6.0, card.end.y - 12.0, pal["mauve"] as Color, 1)


func _draw_reward_ceremony(ci: CanvasItem) -> void:
	var t: float = float(reward_card["t"])
	var dur: float = float(reward_card["dur"])
	var fade: float = minf(t / 0.18, (dur - t) / 0.28)
	var pal: Dictionary = LxPalette.PAL
	var acc_k: String = str(reward_card.get("accent", "gold"))
	var acc_c: Color = LxPalette.color(acc_k, "gold")
	var title_s: String = str(reward_card.get("title", ""))
	var box_w: float = clampf(float(LxPixelFont.width(title_s, 1)) + 44.0, 112.0, 240.0)
	var box := Rect2(roundf(160.0 - box_w * 0.5), 52.0, box_w, 40.0)
	ci.draw_rect(Rect2(box.position + Vector2(2.0, 2.0), box.size), pal["void"] as Color)
	LxPixelFont.draw_panel(ci, box, "night", acc_k, "void")
	# Subtle radial pixel sparks (static when flash_reduced)
	var fr: bool = LxHudFx.flash_reduced()
	for si: int in range(6):
		var ang: float = TAU * float(si) / 6.0 + (0.0 if fr else t * 1.4)
		var sp: Vector2 = (Vector2(160.0, box.position.y + 13.0) + Vector2(cos(ang) * 14.0, sin(ang) * 7.0)).round()
		ci.draw_rect(Rect2(sp, Vector2.ONE), (pal["cream"] if si % 2 == 0 else acc_c) as Color)
	# Centered 2x icon medallion
	var ic_box := Rect2(150.0, box.position.y + 4.0, 20.0, 20.0)
	ci.draw_rect(ic_box, pal["void"] as Color)
	ci.draw_rect(ic_box, acc_c, false, 1.0)
	LxBubble.draw_icon(ci, str(reward_card.get("icon", "lantern")), Vector2(151.0, box.position.y + 5.0), 2.0)
	LxPixelFont.draw_faded(ci, title_s, Vector2(160.0, box.position.y + 27.0), fade, acc_k, 1, HORIZONTAL_ALIGNMENT_CENTER)
	var subs: Array = reward_card.get("sub_icons", []) as Array
	for k: int in range(mini(subs.size(), 3)):
		LxBubble.draw_icon(ci, str(subs[k]), Vector2(box.position.x + 6.0 + float(k * 11), box.position.y + 8.0), 1.0)
	if t >= 0.25:
		LxPixelFont.draw_right(ci, LxStrings.text("INTRO_SKIP"), box.end.x - 4.0, box.position.y + 4.0, pal["mauve"] as Color, 1)


func _draw_previously_bar(ci: CanvasItem) -> void:
	var t: float = float(prev_bar["t"])
	var dur: float = float(prev_bar["dur"])
	var fade: float = minf(t / 0.25, (dur - t) / 0.45)
	if fade <= 0.08:
		return
	var icons: Array = prev_bar.get("icons", []) as Array
	if icons.is_empty():
		return
	var lbl: String = LxUiNav.tr_any("HUD_PREVIOUSLY", "SLOT_CONTINUE")
	var lw: float = float(LxPixelFont.width(lbl, 1))
	var strip_w: float = float(icons.size()) * 11.0 + 4.0
	var box_w: float = roundf(lw + strip_w + 18.0)
	var box := Rect2(roundf(160.0 - box_w * 0.5), 31.0, box_w, 15.0)
	LxPixelFont.draw_panel(ci, box, "night", "gold", "void")
	LxPixelFont.draw_left(ci, lbl, box.position + Vector2(6.0, 5.0), LxPalette.fade_step(fade, "gold"), 1)
	var ix: float = box.position.x + lw + 12.0
	for i: int in range(icons.size()):
		LxBubble.draw_icon(ci, str(icons[i]), Vector2(ix + float(i * 11), box.position.y + 3.0), 1.0)
