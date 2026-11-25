class_name LxIsland1RuleFx
extends Node2D
## World-space diegetic FX overlay + compact HUD indicator for Island 1 (Bell Isle).
## Renders Midnight indigo atmosphere & ghost-stone bridge shimmer, 1.2 s Town Bell shift ring,
## Dusk-frozen ice rims & countdown bars, Shutter Hood cloak ring, and top-left EVE/MID badge.

var rule: LxIsland1Rule = null
var _clock: float = 0.0
var _driver_id: int = 0
var _ticked_by_toy: bool = false
var _hud_layer: CanvasLayer = null
var _hud_draw: Node2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 4
	_ensure_hud()


func _exit_tree() -> void:
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	_hud_layer = null
	_hud_draw = null


func _ensure_hud() -> void:
	if _hud_layer != null and is_instance_valid(_hud_layer):
		return
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "Island1RuleHud"
	_hud_layer.layer = 11
	_hud_draw = Node2D.new()
	_hud_draw.name = "Badge"
	_hud_draw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hud_draw.draw.connect(_draw_hud_badge)
	_hud_layer.add_child(_hud_draw)
	add_child(_hud_layer)
	sync_hud_visible()


func sync_hud_visible() -> void:
	if _hud_layer == null or not is_instance_valid(_hud_layer):
		return
	var modal_open: bool = Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open"))
	_hud_layer.visible = (not modal_open) and rule != null and rule.should_show_hud_badge()
	if _hud_layer.visible and _hud_draw != null and is_instance_valid(_hud_draw):
		_hud_draw.queue_redraw()


func _process(_dt: float) -> void:
	sync_hud_visible()


func tick_from_toy(toy: Object, dt: float) -> void:
	if rule == null or toy == null:
		return
	var tid: int = toy.get_instance_id()
	if _driver_id == 0:
		_driver_id = tid
	else:
		var drv: Object = instance_from_id(_driver_id)
		if drv == null or not is_instance_valid(drv) or (drv.get("active") is bool and not bool(drv.get("active"))):
			_driver_id = tid
	if tid == _driver_id:
		_ticked_by_toy = true
		_clock += dt
		rule.tick(dt)


func _physics_process(dt: float) -> void:
	if rule == null:
		return
	if _ticked_by_toy:
		_ticked_by_toy = false
		return
	_clock += dt
	rule.tick(dt)


func _draw() -> void:
	if rule == null or rule._region == null or not is_instance_valid(rule._region):
		return
	var reg: LxRegionLoader = rule._region
	var b: Rect2 = reg.bounds
	var red: bool = LxHudFx.flash_reduced()

	# 1. Midnight indigo veil + ghost-stone shimmer on '+' bridges
	if rule.is_midnight():
		draw_rect(b, Color(LxPalette.PAL["deep"] as Color, 0.14 if red else 0.18))
		var ts: float = float(reg.tile_size)
		for ty: int in range(reg.height):
			var row: PackedStringArray = reg.grid[ty]
			for tx: int in range(reg.width):
				if row[tx] == "bridge":
					var p := Vector2(float(tx) * ts, float(ty) * ts)
					var ph: float = fmod(_clock * 2.2 + float(tx * 3 + ty * 5) * 0.17, 1.0)
					var c_gl: Color = LxPalette.PAL["ice"] as Color if (red or ph < 0.5) else LxPalette.PAL["sky"] as Color
					draw_rect(Rect2(p + Vector2(2.0, 2.0), Vector2(2.0, 1.0)), Color(c_gl, 0.65))
					draw_rect(Rect2(p + Vector2(12.0, 13.0), Vector2(2.0, 1.0)), Color(c_gl, 0.55))

	# 2. 1.2 s Town Bell Evening <-> Midnight transition ring
	if rule.transition_t > 0.0:
		var u: float = 1.0 - clampf(rule.transition_t / LxIsland1Rule.HOUR_TRANSITION_S, 0.0, 1.0)
		var org: Vector2 = reg.get_wick_pos()
		if org.x < -9000.0:
			org = b.get_center()
		var r_px: float = lerpf(8.0, maxf(b.size.x, b.size.y) * 0.75, u)
		var col_w: Color = LxPalette.PAL["sky"] as Color if rule.transition_to_midnight else LxPalette.PAL["gold"] as Color
		draw_arc(org.round(), roundf(r_px), 0.0, TAU, 36, Color(col_w, (1.0 - u) * (0.45 if red else 0.85)), 2.0)

	# 3. Crisp ice-crystal frost rims on Dusk-frozen toys & enemies
	for ent_v: Variant in rule._frozen.values():
		if not (ent_v is Dictionary):
			continue
		var ent: Dictionary = ent_v as Dictionary
		var obj: Object = ent.get("obj", null) as Object
		if obj == null or not is_instance_valid(obj):
			continue
		var op: Vector2 = obj.get("pos") as Vector2 if obj.get("pos") is Vector2 else (
			(obj as Node2D).global_position if obj is Node2D else Vector2.INF
		)
		if not op.is_finite():
			continue
		var r_fr: float = float(obj.get("radius")) if (obj.get("radius") is float or obj.get("radius") is int) else 10.0
		r_fr = clampf(r_fr, 8.0, 32.0)
		var fr_rect := Rect2((op - Vector2(r_fr, r_fr)).round(), Vector2(r_fr * 2.0, r_fr * 2.0).round())
		draw_rect(fr_rect, Color(LxPalette.PAL["ice"] as Color, 0.22))
		draw_rect(fr_rect, LxPalette.PAL["ice"] as Color, false, 1.0)
		var frac: float = clampf(float(ent["left"]) / maxf(0.1, float(ent["max_t"])), 0.0, 1.0)
		LxToyDraw.draw_bar(self, Vector2(op.x - 7.0, op.y - r_fr - 5.0), 14.0, frac, LxPalette.PAL["ice"] as Color)

	# 4. Subtle Shutter Hood shadow-cloak ring around cloaked Wick
	if rule.is_wick_cloaked() and Lx.player is LxWick and is_instance_valid(Lx.player):
		var wp: Vector2 = (Lx.player as LxWick).global_position.round()
		draw_arc(wp + Vector2(0.0, -3.0), 9.0, 0.0, TAU, 16, Color(LxPalette.PAL["plum"] as Color, 0.72), 1.0)
		draw_rect(Rect2(wp + Vector2(-3.0, -11.0), Vector2(6.0, 2.0)), LxPalette.PAL["night"] as Color)
		draw_rect(Rect2(wp + Vector2(-2.0, -11.0), Vector2(4.0, 1.0)), LxPalette.PAL["sky"] as Color)


func _draw_hud_badge() -> void:
	if rule == null or _hud_draw == null or _hud_layer == null or not _hud_layer.visible:
		return
	var st: LxGameState = rule._get_state()
	var y0: float = 22.0 if (st != null and st.max_hearts > 6) else 15.0
	var x0: float = 5.0
	var is_mid: bool = rule.is_midnight()
	var has_echo: bool = rule.has_echo_clapper()
	var has_hood: bool = rule.has_shutter_hood()
	var w_box: float = 34.0 + (10.0 if has_echo else 0.0) + (10.0 if has_hood else 0.0)
	var c_void: Color = LxPalette.PAL["void"] as Color
	var c_rim: Color = LxPalette.PAL["sky"] as Color if is_mid else LxPalette.PAL["gold"] as Color
	_hud_draw.draw_rect(Rect2(x0, y0, w_box, 10.0), Color(c_void, 0.78))
	_hud_draw.draw_rect(Rect2(x0, y0, w_box, 10.0), c_rim, false, 1.0)
	LxToyDraw.draw_tone_crest(_hud_draw, Vector2(x0 + 5.0, y0 + 5.0), "dusk" if is_mid else "dawn", true)
	var lbl_id: String = "ISL1_HUD_MID" if is_mid else "ISL1_HUD_EVE"
	var lbl: String = LxStrings.text(lbl_id) if LxStrings.has_id(lbl_id) else ""
	LxPixelFont.draw_left(_hud_draw, lbl, Vector2(x0 + 10.0, y0 + 2.0), LxPalette.PAL["ice"] as Color if is_mid else LxPalette.PAL["cream"] as Color, 1)
	var cx: float = x0 + 34.0
	if has_echo:
		_hud_draw.draw_arc(Vector2(cx + 4.0, y0 + 5.0), 3.0, 0.0, TAU, 10, LxPalette.PAL["gold"] as Color, 1.0)
		_hud_draw.draw_rect(Rect2(cx + 3.0, y0 + 4.0, 2.0, 2.0), LxPalette.PAL["cream"] as Color)
		cx += 10.0
	if has_hood:
		var cloak: bool = rule.is_wick_cloaked()
		var c_h: Color = LxPalette.PAL["ice"] as Color if cloak else (LxPalette.PAL["coral"] as Color if rule.stealth_alert == "spotted" else LxPalette.PAL["mauve"] as Color)
		_hud_draw.draw_rect(Rect2(cx + 1.0, y0 + 2.0, 6.0, 6.0), LxPalette.PAL["night"] as Color)
		_hud_draw.draw_rect(Rect2(cx + 2.0, y0 + 4.0, 4.0, 2.0), c_h)
