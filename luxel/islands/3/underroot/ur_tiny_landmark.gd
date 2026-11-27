class_name LxUrTinyLandmark
extends LxToy
## Under-Root bespoke tiny-scale architectural landmarks in strict 20-colour Last Light pixel art.
## Makes tiny scale read at a glance:
## - "thimble_tower": giant overturned hammered brass thimble (underroot_r4 centerpiece cover tower)
## - "grass_cathedral": towering curved grass blades arching overhead like cathedral trees
## - "acorn_boulder": colossal fallen acorn & cross-hatched cap resting like a boulder
## - "shed_exoskeleton": giant pale-chitin centipede ribcage spanning the gallery (underroot_r10)
## - "jar_shadow": sideways glass jar rim glints + Hundred Lamps' colossal gliding silhouette outside (underroot_r9)

var variant: String = "grass_cathedral"
var flip_x: bool = false
var span_px: float = 220.0
var _glide_t: float = 0.0


func _toy_setup() -> void:
	kind = "ur_tiny_landmark"
	variant = str(props.get("variant", "grass_cathedral")).strip_edges().to_lower()
	flip_x = bool(props.get("flip_x", false))
	span_px = maxf(64.0, float(props.get("span_px", 220.0)))
	radius = 8.0
	_glide_t = 0.0
	match variant:
		"jar_shadow":
			z_index = -3
		"shed_exoskeleton":
			z_index = 2
		"grass_cathedral":
			z_index = 1
		_:
			z_index = 0
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if variant in ["jar_shadow", "grass_cathedral"] and not LxHudFx.flash_reduced():
		_glide_t += dt
		queue_redraw()


func _draw() -> void:
	var sx: float = -1.0 if flip_x else 1.0
	match variant:
		"thimble_tower":
			_draw_thimble_tower()
		"grass_cathedral":
			_draw_grass_cathedral(sx)
		"acorn_boulder":
			_draw_acorn_boulder(sx)
		"shed_exoskeleton":
			_draw_shed_exoskeleton()
		"jar_shadow":
			_draw_jar_shadow()
		_:
			_draw_grass_cathedral(sx)


func _draw_thimble_tower() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	# Deep contact shadow around the overturned brass thimble
	draw_rect(Rect2(-24.0, 10.0, 50.0, 10.0), Color(c_void, 0.55))
	# Flared bottom rim (like a castle tower base)
	draw_rect(Rect2(-22.0, 4.0, 44.0, 10.0), c_void)
	draw_rect(Rect2(-20.0, 5.0, 40.0, 8.0), c_plum)
	draw_rect(Rect2(-19.0, 6.0, 38.0, 5.0), c_coral)
	draw_rect(Rect2(-18.0, 6.0, 26.0, 3.0), c_apricot)
	draw_rect(Rect2(-16.0, 6.0, 14.0, 2.0), c_gold)
	# Tapered hammered brass tower body
	draw_rect(Rect2(-19.0, -28.0, 38.0, 34.0), c_void)
	draw_rect(Rect2(-17.0, -26.0, 34.0, 31.0), c_wine)
	draw_rect(Rect2(-15.0, -26.0, 26.0, 30.0), c_coral)
	draw_rect(Rect2(-14.0, -26.0, 18.0, 29.0), c_apricot)
	draw_rect(Rect2(-11.0, -25.0, 9.0, 27.0), c_gold)
	draw_rect(Rect2(-9.0, -24.0, 3.0, 24.0), c_cream)
	# Domed crown top
	draw_rect(Rect2(-15.0, -34.0, 30.0, 8.0), c_void)
	draw_rect(Rect2(-13.0, -32.0, 26.0, 6.0), c_apricot)
	draw_rect(Rect2(-10.0, -32.0, 16.0, 4.0), c_gold)
	draw_rect(Rect2(-7.0, -31.0, 8.0, 2.0), c_cream)
	# Iconic hammered thimble dimple grid (reads immediately as a giant brass thimble!)
	for row: int in range(5):
		var dy: float = -24.0 + float(row) * 5.0
		var x_off: float = 2.0 if (row % 2 == 1) else 0.0
		for col: int in range(6):
			var dx: float = -13.0 + float(col) * 5.0 + x_off
			if dx > 12.0:
				continue
			draw_rect(Rect2(dx, dy, 2.0, 2.0), c_plum if dx > 4.0 else c_wine)
			draw_rect(Rect2(dx, dy, 1.0, 1.0), c_night)
			draw_rect(Rect2(dx + 1.0, dy + 2.0, 1.0, 1.0), c_cream if dx < -2.0 else c_gold)


func _draw_grass_cathedral(sx: float) -> void:
	var c_void: Color = PAL["void"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_teal: Color = PAL["teal"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var sway: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_glide_t * 1.4 + pos.x * 0.05) * 1.5)
	draw_rect(Rect2(-12.0, 2.0, 24.0, 5.0), Color(c_void, 0.45))
	# Three towering tree-sized grass blades curving like gothic nave ribs
	var blades: Array[Dictionary] = [
		{"bx": -8.0 * sx, "tx": (-16.0 + sway) * sx, "h": 44.0, "w": 6.0, "c1": c_pine, "c2": c_teal, "c3": c_jade},
		{"bx": 0.0, "tx": (10.0 + sway) * sx, "h": 54.0, "w": 7.0, "c1": c_teal, "c2": c_jade, "c3": c_lime},
		{"bx": 8.0 * sx, "tx": (18.0 + sway * 0.8) * sx, "h": 38.0, "w": 5.0, "c1": c_pine, "c2": c_jade, "c3": c_lime},
	]
	for b: Dictionary in blades:
		var bx: float = float(b["bx"])
		var tx: float = float(b["tx"])
		var bh: float = float(b["h"])
		var bw: float = float(b["w"])
		var steps: int = 8
		for i: int in range(steps):
			var u: float = float(i) / float(steps)
			var cx: float = roundf(lerpf(bx, tx, u * u))
			var cy: float = roundf(-u * bh)
			var seg_w: float = maxf(2.0, roundf(bw * (1.0 - u * 0.72)))
			var seg_h: float = ceilf(bh / float(steps)) + 1.0
			var lx: float = floorf(cx - seg_w * 0.5)
			draw_rect(Rect2(lx - 1.0, cy - seg_h, seg_w + 2.0, seg_h + 1.0), c_void)
			draw_rect(Rect2(lx, cy - seg_h, seg_w, seg_h), b["c1"] as Color)
			if seg_w >= 3.0:
				draw_rect(Rect2(lx, cy - seg_h, maxf(1.0, seg_w - 2.0), seg_h), b["c2"] as Color)
				draw_rect(Rect2(lx, cy - seg_h, 1.0, seg_h), b["c3"] as Color)
	# Clinging giant dewdrop on tallest blade
	var dx: float = roundf(lerpf(0.0, (10.0 + sway) * sx, 0.55))
	var dpx: float = roundf(dx + 2.0 * sx)
	draw_circle(Vector2(dpx, -36.0), 3.0, c_void)
	draw_circle(Vector2(dpx, -36.0), 2.0, c_ice)
	draw_rect(Rect2(roundf(dx + 1.0 * sx), -37.0, 1.0, 1.0), c_cream)


func _draw_acorn_boulder(sx: float) -> void:
	var c_void: Color = PAL["void"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	# Colossal fallen acorn resting on its side like a smooth boulder
	draw_rect(Rect2(-16.0, 5.0, 32.0, 7.0), Color(c_void, 0.5))
	# Smooth nut shell
	draw_rect(Rect2(-14.0, -14.0, 28.0, 22.0), c_void)
	draw_rect(Rect2(-12.0, -12.0, 24.0, 18.0), c_wine)
	draw_rect(Rect2(-11.0, -11.0, 20.0, 14.0), c_coral)
	draw_rect(Rect2(-9.0, -10.0, 14.0, 8.0), c_apricot)
	draw_rect(Rect2(-7.0, -9.0, 7.0, 3.0), c_gold)
	# Textured cross-hatched acorn cap
	var cap_x: float = -16.0 if sx > 0.0 else 4.0
	draw_rect(Rect2(cap_x, -16.0, 12.0, 26.0), c_void)
	draw_rect(Rect2(cap_x + 1.0, -15.0, 10.0, 24.0), c_dusk)
	draw_rect(Rect2(cap_x + 2.0, -14.0, 8.0, 22.0), c_plum)
	for gy: float in [-12.0, -6.0, 0.0, 6.0]:
		draw_rect(Rect2(cap_x + 2.0, gy, 8.0, 1.0), c_void)
		draw_rect(Rect2(cap_x + 3.0, gy + 2.0, 2.0, 2.0), c_apricot)
		draw_rect(Rect2(cap_x + 7.0, gy + 2.0, 2.0, 2.0), c_coral)
	# Woody stem nub
	var stem_x: float = -20.0 if sx > 0.0 else 15.0
	draw_rect(Rect2(stem_x, -4.0, 5.0, 4.0), c_void)
	draw_rect(Rect2(stem_x + 1.0, -3.0, 3.0, 2.0), c_plum)


func _draw_shed_exoskeleton() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_cream: Color = PAL["cream"] as Color
	# Giant arched translucent chitin ribs of Hundred Lamps' shed husk spanning the hall
	for rx: float in [-64.0, -40.0, -16.0, 16.0, 40.0, 64.0]:
		draw_rect(Rect2(rx - 5.0, -24.0, 10.0, 48.0), Color(c_void, 0.72))
		draw_rect(Rect2(rx - 4.0, -22.0, 8.0, 44.0), c_dusk)
		draw_rect(Rect2(rx - 3.0, -20.0, 6.0, 40.0), c_plum)
		draw_rect(Rect2(rx - 2.0, -18.0, 3.0, 36.0), c_mauve)
		draw_rect(Rect2(rx - 2.0, -16.0, 1.0, 28.0), c_stone)
		# Darkened hollow lamp-sockets along the shed ridge (foreshadows Hundred Lamps!)
		draw_rect(Rect2(rx - 2.0, -25.0, 4.0, 4.0), c_night)
		draw_rect(Rect2(rx - 1.0, -24.0, 2.0, 2.0), c_cream if absf(rx) > 32.0 else c_dusk)


func _draw_jar_shadow() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_gold: Color = PAL["gold"] as Color
	# Curved glass jar specular bands across top & bottom walls
	var half_s: float = roundf(span_px * 0.5)
	var red: bool = LxHudFx.flash_reduced()
	draw_line(Vector2(-half_s, -78.0), Vector2(half_s, -78.0), Color(c_sky, 0.35), 2.0)
	draw_line(Vector2(-half_s + 16.0, -76.0), Vector2(half_s - 24.0, -76.0), Color(c_ice, 0.55), 1.0)
	draw_line(Vector2(-half_s + 40.0, -75.0), Vector2(-half_s + 110.0, -75.0), Color(c_cream, 0.65), 1.0)
	draw_line(Vector2(-half_s, 78.0), Vector2(half_s, 78.0), Color(c_sky, 0.28), 2.0)
	# Wordless horror/wonder scene: Hundred Lamps' colossal dark shadow gliding outside the glass!
	var cycle: float = 0.48 if red else fmod(_glide_t * 0.34, 1.0)
	var head_x: float = lerpf(-half_s - 90.0, half_s + 120.0, cycle)
	for si: int in range(8):
		var px: float = roundf(head_x - float(si) * 24.0)
		if px < -half_s - 20.0 or px > half_s + 20.0:
			continue
		var wave_y: float = -96.0 if red else (-96.0 + roundf(sin(_glide_t * 2.2 + float(si) * 0.7) * 4.0))
		draw_circle(Vector2(px, wave_y), 13.0, Color(c_void, 0.55 if red else 0.62))
		draw_circle(Vector2(px, wave_y), 9.0, Color(c_night, 0.45 if red else 0.50))
		# Faint golden lantern-organ dot gleaming through the frosted glass
		if si % 2 == 0:
			draw_rect(Rect2(px - 1.0, wave_y - 1.0, 2.0, 2.0), Color(c_gold, 0.35 if red else 0.45))
		# Skittering outer leg silhouettes (held calm under flash_reduced)
		var leg_off: float = 0.0 if red else roundf(sin(_glide_t * 6.0 + float(si)) * 3.0)
		draw_line(Vector2(px, wave_y + 10.0), Vector2(px + leg_off, wave_y + 20.0), Color(c_void, 0.45 if red else 0.52), 2.0)
