class_name LxVigilCeremony
extends RefCounted
## Island 8 "THE LANTERN ASKS" signature introduction & HUD-to-lantern mote siphon scene.
## When the player sells a setting at a Toll Scale (especially the first voluntary trade in
## vigil_terrace), 18 gold-and-cream motes visibly rip out of the sacrificed HUD/screen region
## and arc across the viewport directly into Wick's lantern, igniting the West & East eclipse
## bridges across the abyss with a solemn chime. Fully honors flash_reduced().

const PAL: Dictionary = LxPalette.PAL
const MOTE_COUNT: int = 18
const SIPHON_DURATION_S: float = 1.15
const BRIDGE_WAVE_DURATION_S: float = 1.05
const VIEW_W: float = 320.0
const VIEW_H: float = 180.0

var _sold: LxSold = null
var _attached: bool = false
var _layer: CanvasLayer = null
var _canvas: _VigilCeremonyCanvas = null
var _region_id: String = ""
var _motes: Array[Dictionary] = []
var _flare_t: float = 0.0
var _flare_screen_pos: Vector2 = Vector2(160.0, 90.0)
var _bridge_wave_t: float = 0.0


func attach() -> void:
	if _attached:
		detach()
	_attached = true
	_sold = LxSold.current()
	if _sold != null and not _sold.setting_sold.is_connected(_on_setting_sold):
		_sold.setting_sold.connect(_on_setting_sold)
	_ensure_canvas()


func detach() -> void:
	if _sold != null and _sold.setting_sold.is_connected(_on_setting_sold):
		_sold.setting_sold.disconnect(_on_setting_sold)
	_sold = null
	_motes.clear()
	_flare_t = 0.0
	_bridge_wave_t = 0.0
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_canvas = null
	_attached = false


func on_region_loaded(region_id: String) -> void:
	_region_id = region_id
	_motes.clear()
	_flare_t = 0.0
	_bridge_wave_t = 0.0
	_ensure_canvas()
	if _canvas != null and is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _ensure_canvas() -> void:
	if _layer != null and is_instance_valid(_layer) and _canvas != null and is_instance_valid(_canvas):
		return
	var host: Node = _resolve_host()
	if host == null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "VigilCeremonyLayer"
	_layer.layer = 14 # Above HUD (10) and SoldFx (7), below TollMenu (15)
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(_layer)
	_canvas = _VigilCeremonyCanvas.new()
	_canvas.name = "VigilCeremonyCanvas"
	_canvas.owner_ceremony = self
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer.add_child(_canvas)


func _resolve_host() -> Node:
	if Lx.root != null and is_instance_valid(Lx.root):
		return Lx.root
	if Lx.world != null and is_instance_valid(Lx.world):
		return Lx.world.get_parent() if Lx.world.get_parent() != null else Lx.world
	return null


func _on_setting_sold(setting_id: String, _weight: int, total_weight: int) -> void:
	_ensure_canvas()
	_spawn_hud_mote_stream(setting_id)
	var is_first_trade: bool = false
	if Lx.state != null:
		if not bool(Lx.state.story_flags.get("vigil_first_trade_seen", false)):
			Lx.state.story_flags["vigil_first_trade_seen"] = true
			is_first_trade = true
		if total_weight >= 1:
			Lx.state.story_flags["toll_weight_1"] = true
	var in_vigil: bool = _region_id == "vigil_terrace"
	var in_boss: bool = Lx.world != null and LxBossHud.region_has_live_boss(Lx.world)
	if (is_first_trade and not in_boss) or in_vigil:
		_bridge_wave_t = BRIDGE_WAVE_DURATION_S
		if Lx.events != null:
			Lx.events.sfx_requested.emit("toll_mote_drink", Vector2.ZERO, false)
			if LxStrings.has_id("ISL8_ASK_PAID"):
				Lx.events.narration_requested.emit("ISL8_ASK_PAID", "title", 3.4)
			if is_first_trade and in_vigil and LxStrings.has_id("ISL8_VIGIL_BRIDGES_LIT"):
				Lx.events.narration_requested.emit("ISL8_VIGIL_BRIDGES_LIT", "narration", 3.8)
			Lx.events.shake_requested.emit(0.16 * (0.45 if LxHudFx.flash_reduced() else 1.0))
		if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("apply_layers"):
			Lx.world.call("apply_layers")
	if _canvas != null and is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _spawn_hud_mote_stream(setting_id: String) -> void:
	var origin: Vector2 = _origin_for_setting(setting_id)
	var target: Vector2 = _wick_screen_pos()
	var accent_key: String = _accent_for_setting(setting_id)
	for i: int in range(MOTE_COUNT):
		var frac: float = float(i) / float(maxi(1, MOTE_COUNT - 1))
		var spread := Vector2(cos(frac * TAU * 1.7) * 18.0, sin(frac * TAU * 1.3) * 10.0)
		var start_p: Vector2 = (origin + spread).clamp(Vector2(6.0, 6.0), Vector2(VIEW_W - 6.0, VIEW_H - 6.0))
		var mid: Vector2 = start_p.lerp(target, 0.48)
		var perp: Vector2 = (target - start_p).orthogonal().normalized()
		var arc_sign: float = -1.0 if (i % 2 == 0) else 1.0
		var ctrl_p: Vector2 = mid + perp * (18.0 + float(i % 5) * 9.0) * arc_sign + Vector2(0.0, -14.0)
		_motes.append({
			"p0": start_p,
			"p1": ctrl_p,
			"delay": frac * 0.32,
			"t": 0.0,
			"dur": SIPHON_DURATION_S - 0.25 + fmod(float(i) * 0.047, 0.28),
			"col": accent_key if (i % 3 == 0) else ("cream" if (i % 3 == 1) else "gold"),
			"size": 3.0 if (i % 4 == 0) else 2.0,
		})


func _origin_for_setting(setting_id: String) -> Vector2:
	match setting_id:
		"hud_hearts": return Vector2(36.0, 14.0)
		"minimap_hud": return Vector2(288.0, 18.0)
		"ember_hud": return Vector2(44.0, 166.0)
		"cursor_ring": return Vector2(160.0, 90.0)
		"music_off": return Vector2(286.0, 162.0)
		"sound_off": return Vector2(268.0, 162.0)
		"palette_4": return Vector2(160.0, 14.0)
		"fps_step": return Vector2(302.0, 90.0)
		"dash_trail": return Vector2(22.0, 90.0)
		"hit_flash": return Vector2(160.0, 166.0)
		"camera_shake": return Vector2(160.0, 22.0)
		"world_anims": return Vector2(28.0, 142.0)
		_: return Vector2(44.0, 18.0)


func _accent_for_setting(setting_id: String) -> String:
	match setting_id:
		"hud_hearts", "hit_flash": return "coral"
		"minimap_hud", "camera_shake": return "sky"
		"palette_4", "music_off", "sound_off", "fps_step": return "rose"
		_: return "apricot"


func _wick_screen_pos() -> Vector2:
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		var wp: Vector2 = (Lx.player as Node2D).global_position
		if Lx.camera != null and is_instance_valid(Lx.camera):
			var cam_p: Vector2 = Lx.camera.global_position
			var rel: Vector2 = wp - cam_p + Vector2(VIEW_W * 0.5, VIEW_H * 0.5)
			return rel.clamp(Vector2(24.0, 24.0), Vector2(VIEW_W - 24.0, VIEW_H - 24.0))
	return Vector2(VIEW_W * 0.5, VIEW_H * 0.5)


func _is_overlay_allowed() -> bool:
	if Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open")):
		return false
	if Lx.root != null and is_instance_valid(Lx.root):
		var fl: Variant = Lx.root.get("flow")
		if fl is int:
			return int(fl) == 2
	return true


func _tick(dt: float) -> void:
	var allowed: bool = _is_overlay_allowed()
	if not allowed and Lx.root != null and is_instance_valid(Lx.root):
		var fl: Variant = Lx.root.get("flow")
		if fl is int and int(fl) in [0, 1, 7, 8]:
			_motes.clear()
			_flare_t = 0.0
			_bridge_wave_t = 0.0
	if _layer != null and is_instance_valid(_layer):
		_layer.visible = allowed and (not _motes.is_empty() or _flare_t > 0.0 or _bridge_wave_t > 0.0)
	if not allowed:
		return
	var dirty: bool = false
	if _flare_t > 0.0:
		_flare_t = maxf(0.0, _flare_t - dt)
		dirty = true
	if _bridge_wave_t > 0.0:
		_bridge_wave_t = maxf(0.0, _bridge_wave_t - dt)
		dirty = true
	if not _motes.is_empty():
		dirty = true
		var target: Vector2 = _wick_screen_pos()
		for i: int in range(_motes.size() - 1, -1, -1):
			var m: Dictionary = _motes[i]
			var del: float = float(m["delay"])
			if del > 0.0:
				m["delay"] = maxf(0.0, del - dt)
				continue
			m["t"] = float(m["t"]) + dt
			if float(m["t"]) >= float(m["dur"]):
				_flare_t = maxf(_flare_t, 0.36)
				_flare_screen_pos = target
				_motes.remove_at(i)
	if dirty and _canvas != null and is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _draw_overlay(ci: CanvasItem) -> void:
	if not _is_overlay_allowed():
		return
	var fred: bool = LxHudFx.flash_reduced()
	var target: Vector2 = _wick_screen_pos().round()

	# Twin horizontal golden bridge-ignition beams sweeping West & East from Wick!
	if _bridge_wave_t > 0.0:
		var u: float = 1.0 - clampf(_bridge_wave_t / BRIDGE_WAVE_DURATION_S, 0.0, 1.0)
		var alpha: float = (1.0 - u) * (0.45 if fred else 0.78)
		var reach: float = roundf(lerpf(16.0, 168.0, u))
		var gold_c: Color = Color(PAL["gold"] as Color, alpha)
		var cream_c: Color = Color(PAL["cream"] as Color, alpha)
		ci.draw_line(target + Vector2(-8.0, 0.0), target + Vector2(-reach, 0.0), gold_c, 3.0)
		ci.draw_line(target + Vector2(8.0, 0.0), target + Vector2(reach, 0.0), gold_c, 3.0)
		ci.draw_line(target + Vector2(-8.0, 0.0), target + Vector2(-reach, 0.0), cream_c, 1.0)
		ci.draw_line(target + Vector2(8.0, 0.0), target + Vector2(reach, 0.0), cream_c, 1.0)
		ci.draw_arc(target, roundf(8.0 + u * 26.0), 0.0, TAU, 20, cream_c, 1.0)

	# 18 HUD-to-lantern Bezier mote streams!
	for m: Dictionary in _motes:
		if float(m["delay"]) > 0.0:
			continue
		var u: float = clampf(float(m["t"]) / maxf(0.01, float(m["dur"])), 0.0, 1.0)
		var ease_u: float = u * u * (3.0 - 2.0 * u)
		var p0: Vector2 = m["p0"] as Vector2
		var p1: Vector2 = m["p1"] as Vector2
		var pos: Vector2 = _quad_bezier(p0, p1, target, ease_u).round()
		var tail: Vector2 = _quad_bezier(p0, p1, target, maxf(0.0, ease_u - 0.10)).round()
		var col: Color = PAL[str(m["col"])] as Color
		var sz: float = roundf(float(m["size"]))
		var half: float = floorf(sz * 0.5)
		if not fred:
			ci.draw_line(tail, pos, Color(col, 0.55), 1.0)
		ci.draw_rect(Rect2(pos - Vector2(half, half), Vector2(sz, sz)), PAL["void"] as Color)
		var inner_sz: float = maxf(1.0, sz - 2.0) if sz >= 3.0 else 1.0
		var inner_off: float = floorf(inner_sz * 0.5)
		ci.draw_rect(Rect2(pos - Vector2(inner_off, inner_off), Vector2(inner_sz, inner_sz)), col)

	# Lantern drink flare ring (steady & crisp under flash_reduced)
	if _flare_t > 0.0:
		var fu: float = 1.0 - clampf(_flare_t / 0.36, 0.0, 1.0)
		var fa: float = (1.0 - fu) * (0.50 if fred else 0.90)
		ci.draw_arc(_flare_screen_pos.round(), roundf(5.0 + fu * 16.0), 0.0, TAU, 16, Color(PAL["gold"] as Color, fa), 1.0 if fred else 2.0)
		ci.draw_arc(_flare_screen_pos.round(), roundf(3.0 + fu * 9.0), 0.0, TAU, 12, Color(PAL["cream"] as Color, fa), 1.0)


static func _quad_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inv: float = 1.0 - t
	return inv * inv * a + 2.0 * inv * t * b + t * t * c


class _VigilCeremonyCanvas:
	extends Node2D
	var owner_ceremony: LxVigilCeremony = null

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(dt: float) -> void:
		if owner_ceremony != null:
			owner_ceremony._tick(dt)

	func _draw() -> void:
		if owner_ceremony != null:
			owner_ceremony._draw_overlay(self)
