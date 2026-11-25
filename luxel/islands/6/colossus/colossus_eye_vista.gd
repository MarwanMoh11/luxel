class_name LxColossusEyeVista
extends LxToy
## Crown Cockpit Furnace Eye-Windows (`colossus_r10`): renders the giant's
## twin blazing viewport panes overlooking Ashen Kiln's miniature lava caldera.
## Displays the diegetic 4-orb compass pips (Left Eye: 2nd=1 pip, 4th=2 pips;
## Right Eye: 1st=3 pips, 3rd=4 pips -> sequence 3-1-4-2) and pans the caldera
## horizon eastward toward High Trestle when `colossus_steered` is set!

var steered_flag: String = "colossus_steered"
var _pan_u: float = 0.0


func _toy_setup() -> void:
	kind = "colossus_eye_vista"
	size = _parse_size(props.get("size", [256.0, 24.0]), Vector2(256.0, 24.0))
	radius = 12.0
	steered_flag = str(props.get("steered_flag", "colossus_steered")).strip_edges()
	_pan_u = 1.0 if _is_steered() else 0.0
	z_index = -2
	queue_redraw()


func _is_steered() -> bool:
	if steered_flag.is_empty():
		return powered
	if region != null and region.has_method("is_flag_set"):
		return bool(region.call("is_flag_set", steered_flag))
	return Lx.state != null and bool(Lx.state.story_flags.get(steered_flag, false))


func is_solid() -> bool:
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var target_u: float = 1.0 if _is_steered() else 0.0
	if not is_equal_approx(_pan_u, target_u):
		_pan_u = move_toward(_pan_u, target_u, dt * 0.65)
		queue_redraw()
	elif not LxHudFx.flash_reduced() and int(floorf(_clock * 4.0)) != int(floorf((_clock - dt) * 4.0)):
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y + 12.0, 88.0, 0.72)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var pan_px: float = roundf(_pan_u * 26.0)

	# Draw Left & Right Furnace Eye-Slits (-68px and +68px from center)
	for side_i: int in range(2):
		var cx: float = -68.0 if side_i == 0 else 68.0
		var frame := Rect2(cx - 46.0, -10.0, 92.0, 20.0)
		LxToyDraw.draw_bevel_box(self, frame, c_night, c_dusk, c_stone, c_void)
		var glass := Rect2(cx - 42.0, -7.0, 84.0, 14.0)
		draw_rect(glass, c_plum)
		# Twilight sky band + lava caldera horizon
		draw_rect(Rect2(glass.position.x, glass.position.y + 7.0, glass.size.x, 7.0), c_wine)
		draw_rect(Rect2(glass.position.x, glass.position.y + 10.0, glass.size.x, 4.0), c_coral)
		# Miniature Great Kiln caldera peak + High Trestle viaduct panning into center when steered!
		var peak_x: float = clampf(glass.position.x + 18.0 + pan_px, glass.position.x + 4.0, glass.end.x - 14.0)
		draw_rect(Rect2(peak_x, glass.position.y + 3.0, 10.0, 7.0), c_night)
		draw_rect(Rect2(peak_x + 2.0, glass.position.y + 1.0, 6.0, 3.0), c_dusk)
		draw_rect(Rect2(peak_x + 4.0, glass.position.y + 2.0, 2.0, 2.0), c_gold)
		# Viaduct trestle silhouette
		var trestle_x: float = clampf(glass.position.x + 46.0 + pan_px * 0.65, glass.position.x + 6.0, glass.end.x - 22.0)
		draw_rect(Rect2(trestle_x, glass.position.y + 6.0, 20.0, 2.0), c_dusk)
		draw_rect(Rect2(trestle_x + 3.0, glass.position.y + 8.0, 2.0, 5.0), c_night)
		draw_rect(Rect2(trestle_x + 14.0, glass.position.y + 8.0, 2.0, 5.0), c_night)
		# Mullion iron bars dividing each eye into two clue panes
		draw_rect(Rect2(cx - 1.0, -8.0, 2.0, 16.0), c_void)
		# Diegetic orb-order clue pips etched in gold/cream glass
		# Left eye: Step 2 = Orb 1 (1 pip), Step 4 = Orb 2 (2 pips)
		# Right eye: Step 1 = Orb 3 (3 pips), Step 3 = Orb 4 (4 pips)
		var pips_a: int = 1 if side_i == 0 else 3
		var pips_b: int = 2 if side_i == 0 else 4
		_draw_pip_cluster(Vector2(cx - 21.0, -3.0), pips_a, c_cream if _pan_u > 0.5 else c_gold, c_void)
		_draw_pip_cluster(Vector2(cx + 21.0, -3.0), pips_b, c_cream if _pan_u > 0.5 else c_apricot, c_void)
		# Steered alignment reticle when turned toward High Trestle
		if _pan_u > 0.85:
			draw_rect(Rect2(cx - 3.0, 2.0, 6.0, 1.0), c_cream)
			draw_rect(Rect2(cx, 0.0, 1.0, 5.0), c_cream)


func _draw_pip_cluster(center: Vector2, n: int, fg: Color, bg: Color) -> void:
	var span: float = float(n - 1) * 4.0
	for i: int in range(n):
		var px: float = roundf(center.x - span * 0.5 + float(i) * 4.0)
		draw_rect(Rect2(px - 1.0, center.y - 1.0, 3.0, 3.0), bg)
		draw_rect(Rect2(px, center.y, 1.0, 1.0), fg)
