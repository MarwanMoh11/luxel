class_name LxLoomLandmark
extends LxToy
## Bespoke Last Light pixel-art landmarks for The Weaver's Loom (pure _draw, strict 20-colour palette).
## Variants:
## - "hanging_bobbin": Glass Boss Key bobbin suspended over loom_r2 hub pit by two anchor cables.
## - "loom_tapestry": Tailor Spider's woven Hollow Wick tapestry in loom_r10.
## - "overhead_beam": Dry-silk suspended timber shuttle beam in loom_r4 (drops when powered).
## - "counterweight": Giant brass counterweight hanging in loom_r9 (drops on loom_r9_hoisted).
## Props: variant (String), flip_x (bool), drop_flag (String).

var variant: String = "hanging_bobbin"
var flip_x: bool = false
var drop_flag: String = ""
var _dropped: bool = false


func _toy_setup() -> void:
	kind = "loom_landmark"
	variant = str(props.get("variant", "hanging_bobbin")).strip_edges().to_lower()
	flip_x = bool(props.get("flip_x", false))
	drop_flag = str(props.get("drop_flag", "")).strip_edges()
	z_index = -2 if variant in ["hanging_bobbin", "counterweight"] else 0
	_dropped = _is_flag_set(drop_flag)
	queue_redraw()


func _is_flag_set(fl: String) -> bool:
	if fl.is_empty():
		return false
	if region != null and region.has_method("is_flag_set"):
		return bool(region.call("is_flag_set", fl))
	return Lx.state != null and bool(Lx.state.story_flags.get(fl, false))


func on_signal(_from_id: String, is_on: bool) -> void:
	if is_on and not _dropped:
		_dropped = true
		_emit_sfx("bell_slam")
		if Lx.events != null:
			Lx.events.shake_requested.emit(0.16)
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not drop_flag.is_empty() and not _dropped and _is_flag_set(drop_flag):
		_dropped = true
		queue_redraw()
	if variant in ["hanging_bobbin", "loom_tapestry"] and not LxHudFx.flash_reduced():
		if int(floorf(_clock * 4.0)) != int(floorf((_clock - dt) * 4.0)):
			queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if variant == "hanging_bobbin" and not _is_flag_set("loom_r9_hoisted"):
		return Vector4(pos.x, pos.y - 4.0, 52.0, 0.78)
	if variant == "loom_tapestry":
		return Vector4(pos.x, pos.y - 8.0, 44.0, 0.56)
	return Vector4.ZERO


func _draw() -> void:
	match variant:
		"hanging_bobbin":
			_draw_hanging_bobbin()
		"loom_tapestry":
			_draw_loom_tapestry()
		"overhead_beam":
			_draw_overhead_beam()
		"counterweight":
			_draw_counterweight()


func _draw_hanging_bobbin() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var a1_cut: bool = _is_flag_set("loom_anchor_1")
	var hoisted: bool = _is_flag_set("loom_r9_hoisted")
	var sway: float = 0.0 if (LxHudFx.flash_reduced() or hoisted) else roundf(sin(_clock * 2.2) * 1.5)
	# Two diagonal suspension cables from upper corners
	if not a1_cut and not hoisted:
		draw_line(Vector2(-32.0, -24.0), Vector2(-6.0 + sway, -10.0), c_void, 3.0)
		draw_line(Vector2(-32.0, -24.0), Vector2(-6.0 + sway, -10.0), c_gold, 1.0)
	if not hoisted:
		draw_line(Vector2(32.0, -24.0), Vector2(6.0 + sway, -10.0), c_void, 3.0)
		draw_line(Vector2(32.0, -24.0), Vector2(6.0 + sway, -10.0), c_gold, 1.0)
		# Glass bobbin housing + glowing Boss Key silhouette inside
		LxToyDraw.draw_bevel_box(self, Rect2(-9.0 + sway, -13.0, 18.0, 4.0), PAL["wine"] as Color, c_apricot, c_gold, c_void)
		LxToyDraw.draw_bevel_box(self, Rect2(-7.0 + sway, -9.0, 14.0, 14.0), PAL["deep"] as Color, c_sky, c_ice, c_void)
		draw_rect(Rect2(-5.0 + sway, -7.0, 10.0, 10.0), PAL["night"] as Color)
		# Mini keepers_flame silhouette inside glass bobbin
		draw_rect(Rect2(-2.0 + sway, -6.0, 4.0, 4.0), c_coral)
		draw_rect(Rect2(-1.0 + sway, -5.0, 2.0, 5.0), c_gold)
		draw_rect(Rect2(-1.0 + sway, -5.0, 2.0, 2.0), c_cream)
		LxToyDraw.draw_bevel_box(self, Rect2(-9.0 + sway, 5.0, 18.0, 4.0), PAL["wine"] as Color, c_apricot, c_gold, c_void)
	else:
		# Empty parted cradle rim
		draw_rect(Rect2(-8.0, -2.0, 16.0, 4.0), c_void)
		draw_rect(Rect2(-7.0, -1.0, 14.0, 2.0), PAL["dusk"] as Color)


func _draw_loom_tapestry() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	# Tall wooden tapestry crossbeam + woven cloth
	LxToyDraw.draw_bevel_box(self, Rect2(-22.0, -34.0, 44.0, 5.0), c_plum, c_wine, PAL["apricot"] as Color, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-18.0, -29.0, 36.0, 32.0), c_plum, c_wine, c_rose, c_void)
	draw_rect(Rect2(-15.0, -26.0, 30.0, 26.0), c_dusk)
	# Woven motif: dark twin-winged Hollow Wick figure holding a cold ice lantern over ash
	draw_rect(Rect2(-12.0, -21.0, 8.0, 10.0), c_void)
	draw_rect(Rect2(4.0, -21.0, 8.0, 10.0), c_void)
	draw_rect(Rect2(-3.0, -23.0, 6.0, 16.0), c_void)
	draw_rect(Rect2(-1.0, -20.0, 2.0, 2.0), c_ice)
	draw_rect(Rect2(6.0, -14.0, 4.0, 5.0), c_ice)
	# Gold thread border & ash horizon
	draw_rect(Rect2(-15.0, -4.0, 30.0, 2.0), PAL["stone"] as Color)
	draw_rect(Rect2(-16.0, -27.0, 32.0, 1.0), c_gold)
	draw_rect(Rect2(-16.0, 1.0, 32.0, 1.0), c_gold)


func _draw_overhead_beam() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	if _dropped:
		LxToyDraw.draw_contact_shadow(self, Vector2(0.0, 4.0), 16.0, 4.0)
		LxToyDraw.draw_bevel_box(self, Rect2(-14.0, -4.0, 28.0, 8.0), PAL["plum"] as Color, c_wine, c_apricot, c_void)
		draw_rect(Rect2(-10.0, -2.0, 20.0, 2.0), c_gold)
	else:
		draw_line(Vector2(-10.0, -24.0), Vector2(-10.0, -14.0), PAL["cream"] as Color, 1.0)
		draw_line(Vector2(10.0, -24.0), Vector2(10.0, -14.0), PAL["cream"] as Color, 1.0)
		LxToyDraw.draw_bevel_box(self, Rect2(-14.0, -16.0, 28.0, 7.0), PAL["plum"] as Color, c_wine, c_apricot, c_void)
		draw_rect(Rect2(-11.0, 4.0, 22.0, 3.0), Color(c_void, 0.45))


func _draw_counterweight() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	if _dropped:
		draw_rect(Rect2(-4.0, -2.0, 8.0, 4.0), PAL["dusk"] as Color)
		return
	draw_line(Vector2(0.0, -24.0), Vector2(0.0, -8.0), c_gold, 2.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-10.0, -8.0, 20.0, 16.0), PAL["wine"] as Color, c_apricot, c_gold, c_void)
	draw_rect(Rect2(-6.0, -3.0, 12.0, 6.0), PAL["plum"] as Color)
	draw_rect(Rect2(-3.0, -1.0, 6.0, 2.0), PAL["cream"] as Color)
