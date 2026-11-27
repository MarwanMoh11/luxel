class_name LxSoldFx
extends CanvasLayer
## Island 8 ("THE LANTERN ASKS") world-layer post-FX controller.
## Layer 7: sits above world + LxDarknessLayer (layer 5), below LxUiRoot (layer 10)
## and LxTollMenu (layer 15), so menus, Pause, Narration, and Boss Names stay crisp.
## Implements: palette_4, fps_step (24 fps / 30 fps reduced visual hold while physics
## stays 60 Hz), world_anims freeze (enemies/toys/tells keep 100% anim), sound_off 1 px
## visual tell rims, diegetic heart/ember rings, display_pixels dead blocks, 18-mote stream.

const SHADER_PATH: String = "res://luxel/world/sold_fx.gdshader"
const VIEW_SIZE := Vector2(320.0, 180.0)
const FPS_STEP_NORMAL: float = 24.0
const FPS_STEP_REDUCED: float = 30.0
const PALETTE_WIPE_S: float = 0.60
const SUNFLARE_SURGE_S: float = 2.50

static var active_instance: LxSoldFx = null

var _sold: LxSold = null
var _post_rect: ColorRect = null
var _mat: ShaderMaterial = null
var _overlay: Node2D = null

# Visual fps_step state + deterministic telemetry (physics runs 60 Hz).
var physics_ticks: int = 0
var visual_frames_updated: int = 0
var visual_frames_held: int = 0
var _fps_accum: float = 0.0
var _sunflare_surge_t: float = 0.0
var _hold_tex: ImageTexture = null
var _ghost_tex: ImageTexture = null
var _has_hold_frame: bool = false
var _has_ghost_frame: bool = false
var _last_viewport_img: Image = null

# Smooth transitions & animations.
var _palette_mix: float = 0.0
var _palette_wipe_y: float = 0.0
var _clear_radius_px: float = 0.0
var _dawn_clear_active: bool = false
var _world_anims_frozen: bool = false
var _saved_scenery_proc: Dictionary = {}
var _motes: Array[Dictionary] = []
var _clock: float = 0.0
var _is_headless: bool = false
var _modal_suppressed: bool = false


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_headless = DisplayServer.get_name() == "headless"
	active_instance = self
	_build_nodes()
	bind_sold(LxSold.current())


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null
	_set_world_anims_frozen(false)
	_unbind_sold()


func _build_nodes() -> void:
	_post_rect = ColorRect.new()
	_post_rect.name = "SoldPostRect"
	_post_rect.position = Vector2.ZERO
	_post_rect.size = VIEW_SIZE
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_rect.color = LxPalette.PAL["cream"] as Color
	if ResourceLoader.exists(SHADER_PATH):
		var sh: Resource = ResourceLoader.load(SHADER_PATH)
		if sh is Shader:
			_mat = ShaderMaterial.new()
			_mat.shader = sh as Shader
			_mat.set_shader_parameter("view_size", VIEW_SIZE)
			_post_rect.material = _mat
	add_child(_post_rect)

	_overlay = Node2D.new()
	_overlay.name = "SoldDiegeticOverlay"
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func bind_sold(sold: LxSold) -> void:
	_unbind_sold()
	_sold = sold
	if _sold == null:
		return
	if not _sold.state_changed.is_connected(_on_sold_changed):
		_sold.state_changed.connect(_on_sold_changed)
	if not _sold.fx_pulse_requested.is_connected(_on_fx_pulse):
		_sold.fx_pulse_requested.connect(_on_fx_pulse)
	if not _sold.all_restored.is_connected(_on_all_restored):
		_sold.all_restored.connect(_on_all_restored)
	_sync_all()


func _unbind_sold() -> void:
	if _sold == null:
		return
	if _sold.state_changed.is_connected(_on_sold_changed):
		_sold.state_changed.disconnect(_on_sold_changed)
	if _sold.fx_pulse_requested.is_connected(_on_fx_pulse):
		_sold.fx_pulse_requested.disconnect(_on_fx_pulse)
	if _sold.all_restored.is_connected(_on_all_restored):
		_sold.all_restored.disconnect(_on_all_restored)
	_sold = null


func set_modal_suppressed(suppressed: bool) -> void:
	_modal_suppressed = suppressed
	if suppressed:
		_has_hold_frame = false
		_sync_shader()


func trigger_sunflare_surge(duration_s: float = SUNFLARE_SURGE_S) -> void:
	_sunflare_surge_t = maxf(_sunflare_surge_t, duration_s)
	_has_hold_frame = false
	_sync_shader()


func reset_fps_telemetry() -> void:
	physics_ticks = 0
	visual_frames_updated = 0
	visual_frames_held = 0
	_fps_accum = 0.0


func get_fps_telemetry() -> Dictionary:
	var target_fps: float = _target_visual_fps()
	var active: bool = _is_fps_step_active()
	return {
		"active": active,
		"target_visual_fps": target_fps if active else 60.0,
		"physics_ticks": physics_ticks,
		"visual_frames_updated": visual_frames_updated,
		"visual_frames_held": visual_frames_held,
		"surge_remaining_s": _sunflare_surge_t,
		"world_anims_frozen": _world_anims_frozen,
		"palette_4_mix": _palette_mix,
		"pixels_loss": _sold.get_display_pixels_pct() if _sold != null else 0.0,
	}


func on_region_loaded() -> void:
	_saved_scenery_proc.clear()
	_world_anims_frozen = false
	_sync_all()


func _physics_process(dt: float) -> void:
	physics_ticks += 1
	if _sold != null:
		_sold.tick_runtime(dt)
	_step_visual_cadence(dt)


func _process(dt: float) -> void:
	_clock += dt
	if _sunflare_surge_t > 0.0:
		_sunflare_surge_t = maxf(0.0, _sunflare_surge_t - dt)
	_step_palette_transition(dt)
	_step_dawn_clear(dt)
	_step_motes(dt)
	_sync_shader()
	if _overlay != null and is_instance_valid(_overlay):
		if _needs_overlay_redraw():
			_overlay.queue_redraw()


func _step_visual_cadence(dt: float) -> void:
	if not _is_fps_step_active():
		_fps_accum = 0.0
		_has_hold_frame = false
		_has_ghost_frame = false
		return
	var step_s: float = 1.0 / _target_visual_fps()
	_fps_accum += dt
	if _fps_accum >= step_s or visual_frames_updated == 0:
		while _fps_accum >= step_s:
			_fps_accum -= step_s
		visual_frames_updated += 1
		_capture_hold_frame()
	else:
		visual_frames_held += 1


func _capture_hold_frame() -> void:
	if _is_headless or _post_rect == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null or vp.get_texture() == null:
		return
	# Temporarily hide post rect for one sample? get_image() returns last rendered backbuffer.
	var img: Image = vp.get_texture().get_image()
	if img == null or img.is_empty():
		return
	if _last_viewport_img != null and not _last_viewport_img.is_empty():
		if _ghost_tex == null:
			_ghost_tex = ImageTexture.create_from_image(_last_viewport_img)
		else:
			_ghost_tex.update(_last_viewport_img)
		_has_ghost_frame = true
	if _hold_tex == null:
		_hold_tex = ImageTexture.create_from_image(img)
	else:
		_hold_tex.update(img)
	_last_viewport_img = img
	_has_hold_frame = true


func _target_visual_fps() -> float:
	return FPS_STEP_REDUCED if LxHudFx.flash_reduced() else FPS_STEP_NORMAL


func _is_fps_step_active() -> bool:
	if _sold == null or not _sold.is_sold("fps_step"):
		return false
	if _sunflare_surge_t > 0.0 or _modal_suppressed or get_tree().paused:
		return false
	return true


func _step_palette_transition(dt: float) -> void:
	var want_p4: bool = _sold != null and _sold.is_sold("palette_4")
	var reduced: bool = LxHudFx.flash_reduced()
	if want_p4:
		if reduced:
			_palette_mix = minf(1.0, _palette_mix + dt / PALETTE_WIPE_S)
			_palette_wipe_y = minf(1.0, _palette_wipe_y + dt / PALETTE_WIPE_S)
		else:
			_palette_mix = 1.0
			_palette_wipe_y = minf(1.0, _palette_wipe_y + dt * 4.5)
	else:
		_palette_mix = maxf(0.0, _palette_mix - dt * 3.0)
		if _palette_mix <= 0.001:
			_palette_wipe_y = 0.0


func _step_dawn_clear(dt: float) -> void:
	if not _dawn_clear_active:
		return
	_clear_radius_px += dt * 420.0
	if _clear_radius_px >= 420.0:
		_dawn_clear_active = false
		_clear_radius_px = 0.0


func _sync_all() -> void:
	var freeze_world: bool = _sold != null and _sold.is_sold("world_anims")
	_set_world_anims_frozen(freeze_world)
	if _sold != null and _sold.is_sold("palette_4") and not LxHudFx.flash_reduced():
		_palette_mix = 1.0
		_palette_wipe_y = 1.0
	elif _sold == null or not _sold.is_sold("palette_4"):
		_palette_mix = 0.0
		_palette_wipe_y = 0.0
	_sync_shader()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _is_suppressed() -> bool:
	if _modal_suppressed:
		return true
	if Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open")):
		return true
	if Lx.root != null and is_instance_valid(Lx.root) and Lx.root.get("flow") != null and int(Lx.root.get("flow")) != 2:
		return true
	return false


func _sync_shader() -> void:
	if _post_rect == null:
		return
	var suppressed: bool = _is_suppressed()
	var pix_loss: float = _sold.get_display_pixels_pct() if _sold != null else 0.0
	var hold_on: bool = _is_fps_step_active() and _has_hold_frame and _hold_tex != null
	var need_post: bool = (_palette_mix > 0.001) or (pix_loss > 0.001) or hold_on or _dawn_clear_active
	_post_rect.visible = need_post and not suppressed
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = not suppressed
	if _mat == null or not _post_rect.visible:
		return
	var reduced: bool = LxHudFx.flash_reduced()
	_mat.set_shader_parameter("palette_4_mix", _palette_mix)
	_mat.set_shader_parameter("palette_wipe_y", _palette_wipe_y)
	_mat.set_shader_parameter("pixels_loss", pix_loss)
	_mat.set_shader_parameter("reduced_mode", reduced)
	_mat.set_shader_parameter("hold_active", hold_on)
	if hold_on and _hold_tex != null:
		_mat.set_shader_parameter("hold_tex", _hold_tex)
	var use_ghost: bool = hold_on and _has_ghost_frame and _ghost_tex != null and not reduced
	_mat.set_shader_parameter("ghost_active", use_ghost)
	_mat.set_shader_parameter("ghost_alpha", 0.24 if use_ghost else 0.0)
	if use_ghost:
		_mat.set_shader_parameter("ghost_tex", _ghost_tex)
	_mat.set_shader_parameter("clear_radius_px", _clear_radius_px if _dawn_clear_active else 0.0)


func _set_world_anims_frozen(freeze: bool) -> void:
	if _world_anims_frozen == freeze:
		return
	_world_anims_frozen = freeze
	if Lx.world == null or not is_instance_valid(Lx.world):
		return
	var scenery_v: Variant = Lx.world.get("_scenery_props")
	if scenery_v is Array:
		for item: Variant in (scenery_v as Array):
			if item is LxSceneryProp and is_instance_valid(item):
				var sp: LxSceneryProp = item as LxSceneryProp
				var iid: int = sp.get_instance_id()
				if freeze:
					_saved_scenery_proc[iid] = sp.is_processing()
					sp.set_process(false)
					sp.set("_clock", 0.0)
					sp.queue_redraw()
				else:
					var was_proc: bool = bool(_saved_scenery_proc.get(iid, true))
					sp.set_process(was_proc)
					sp.queue_redraw()
	for node_prop: String in ["_water_fx", "_ambient_life"]:
		var nv: Variant = Lx.world.get(node_prop)
		if nv is Node and is_instance_valid(nv):
			var n: Node = nv as Node
			if freeze:
				n.set_process(false)
				n.set_physics_process(false)
			else:
				n.set_process(true)
				n.set_physics_process(true)
	if not freeze:
		_saved_scenery_proc.clear()


func _on_sold_changed() -> void:
	_sync_all()


func _on_all_restored(reason: String) -> void:
	if reason == "dawn":
		_dawn_clear_active = true
		_clear_radius_px = 4.0
	else:
		_dawn_clear_active = false
		_clear_radius_px = 0.0
	_has_hold_frame = false
	_has_ghost_frame = false
	_sync_all()


func _on_fx_pulse(kind: String, payload: Dictionary) -> void:
	if kind != "mote_stream":
		return
	var count: int = clampi(int(payload.get("count", 18)), 6, 24)
	var src_world: Vector2 = payload.get("source_pos", Vector2.ZERO) as Vector2
	var src_screen: Vector2 = _world_to_screen(src_world) if src_world != Vector2.ZERO else Vector2(160.0, 56.0)
	for i: int in range(count):
		var ang: float = TAU * float(i) / float(count) + 0.17
		var spread: Vector2 = Vector2(cos(ang), sin(ang)) * (10.0 + float(i % 4) * 5.0)
		_motes.append({
			"from": src_screen + spread,
			"age": -float(i) * 0.018,
			"life": 0.52 + float(i % 3) * 0.06,
			"bright": (i % 2 == 0),
		})
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _step_motes(dt: float) -> void:
	if _motes.is_empty():
		return
	for i: int in range(_motes.size() - 1, -1, -1):
		var m: Dictionary = _motes[i]
		m["age"] = float(m["age"]) + dt
		if float(m["age"]) >= float(m["life"]):
			_motes.remove_at(i)


func _needs_overlay_redraw() -> bool:
	if not _motes.is_empty():
		return true
	if _sold == null:
		return false
	return _sold.is_sold("sound_off") or _sold.is_sold("hud_hearts") or _sold.is_sold("ember_hud")


func _draw_overlay() -> void:
	if _overlay == null or _modal_suppressed:
		return
	var gold: Color = LxPalette.PAL["gold"] as Color
	var cream: Color = LxPalette.PAL["cream"] as Color
	var coral: Color = LxPalette.PAL["coral"] as Color
	var void_c: Color = LxPalette.PAL["void"] as Color

	# 1. Sound-off crisp 1 px visual tell rims on telegraphing enemies.
	if _sold != null and _sold.is_sold("sound_off") and Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("get_enemies"):
		var enemies_v: Variant = Lx.world.call("get_enemies")
		if enemies_v is Array:
			for ev: Variant in (enemies_v as Array):
				if not (ev is Node2D) or not is_instance_valid(ev):
					continue
				var en: Node2D = ev as Node2D
				if not en.visible or bool(en.get("dead")):
					continue
				var st_s: String = str(en.get("state_name")).to_lower() if en.get("state_name") != null else ""
				var st_i: int = int(en.get("state")) if en.get("state") is int else 0
				var telegraphing: bool = st_s.contains("tell") or st_s.contains("wind") or st_s.contains("charge") or st_s.contains("attack") or st_i in [2, 3]
				if not telegraphing:
					continue
				var sp: Vector2 = _world_to_screen(en.global_position).round()
				if sp.x < -12.0 or sp.x > 332.0 or sp.y < -12.0 or sp.y > 192.0:
					continue
				var rad: float = clampf(float(en.get("radius")) + 3.0 if en.get("radius") != null else 10.0, 8.0, 24.0)
				_overlay.draw_arc(sp, rad + 1.0, 0.0, TAU, 16, void_c, 1.0)
				_overlay.draw_arc(sp, rad, 0.0, TAU, 16, cream, 1.0)

	# 2. Diegetic low-HP & full-Ember cues around Wick when HUD bars are sold.
	if _sold != null and Lx.player is Node2D and is_instance_valid(Lx.player):
		var wp: Vector2 = _world_to_screen((Lx.player as Node2D).global_position).round()
		if _sold.is_sold("hud_hearts") and Lx.state != null and Lx.state.hearts <= 2.0 and Lx.state.hearts > 0.0:
			var blink: bool = LxHudFx.flash_reduced() or (int(_clock * 5.0) % 2 == 0)
			var col_h: Color = coral if Lx.state.hearts <= 1.0 else gold
			if blink:
				_overlay.draw_arc(wp + Vector2(0.0, -4.0), 11.0, 0.0, TAU, 14, void_c, 2.0)
				_overlay.draw_arc(wp + Vector2(0.0, -4.0), 11.0, 0.0, TAU, 14, col_h, 1.0)
		if _sold.is_sold("ember_hud") and Lx.player.has_method("get_ember_ratio") and float(Lx.player.call("get_ember_ratio")) >= 0.999:
			var cy: float = wp.y - 15.0
			_overlay.draw_rect(Rect2(wp.x - 3.0, cy - 1.0, 7.0, 3.0), void_c)
			_overlay.draw_rect(Rect2(wp.x - 2.0, cy, 5.0, 1.0), gold)
			_overlay.draw_rect(Rect2(wp.x, cy - 1.0, 1.0, 3.0), cream)

	# 3. 18-mote gold stream flowing into Wick's lantern upon setting sale.
	if not _motes.is_empty():
		var dest: Vector2 = Vector2(160.0, 90.0)
		if Lx.player is Node2D and is_instance_valid(Lx.player):
			dest = _world_to_screen((Lx.player as Node2D).global_position + Vector2(0.0, -5.0))
		for m: Dictionary in _motes:
			var age: float = float(m["age"])
			if age < 0.0:
				continue
			var u: float = clampf(age / maxf(0.05, float(m["life"])), 0.0, 1.0)
			var eu: float = u * u * (3.0 - 2.0 * u)
			var p: Vector2 = (m["from"] as Vector2).lerp(dest, eu) + Vector2(0.0, -sin(eu * PI) * 14.0)
			p = p.round()
			var sz: float = 2.0 if bool(m["bright"]) else 1.0
			_overlay.draw_rect(Rect2(p - Vector2.ONE, Vector2(sz + 2.0, sz + 2.0)), void_c)
			_overlay.draw_rect(Rect2(p, Vector2(sz, sz)), cream if bool(m["bright"]) else gold)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	if Lx.camera != null and is_instance_valid(Lx.camera):
		return world_pos - Lx.camera.global_position + VIEW_SIZE * 0.5
	return world_pos
