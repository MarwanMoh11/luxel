class_name LxLoreStone
extends LxToy
## Carved pictogram lore stele: interacts to display a string_id narration and show its carved emblem.
## Strictly uses string IDs (never raw prose literals).
## Props: string_id (String), icon ("lantern"|"bell"|"tide"|"leaf"|"clock"|"star"|"flame"|"moon"|"sun"|"key"),
## duration (float), style (String), persist (bool), target_id/target_ids.

var string_id: String = ""
var icon_kind: String = "lantern"
var duration: float = 4.0
var style: String = "narration"
var read_done: bool = false
var _glow_t: float = 0.0
var _hover: bool = false


func _toy_setup() -> void:
	kind = "lore_stone"
	string_id = str(props.get("string_id", "")).strip_edges()
	icon_kind = str(props.get("icon", "lantern")).strip_edges().to_lower()
	duration = maxf(1.5, float(props.get("duration", 4.0)))
	style = str(props.get("style", "narration")).strip_edges()
	radius = maxf(12.0, radius)
	read_done = powered
	_glow_t = 0.0
	_hover = false
	queue_redraw()


func reset_toy() -> void:
	if persist and read_done:
		return
	read_done = false
	_glow_t = 0.0
	_hover = false
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _glow_t > 0.0:
		_glow_t = maxf(0.0, _glow_t - dt)
		dirty = true
	var wp: Vector2 = wick_pos()
	var want_hover: bool = active and wp.x > -9000.0 and wp.distance_to(pos) <= radius + 12.0
	if want_hover != _hover:
		_hover = want_hover
		dirty = true
	if dirty:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	read_done = true
	_glow_t = 1.2
	set_powered(true)
	emit_power(true)
	_emit_sfx("prop_chime")
	if not string_id.is_empty() and Lx.events != null:
		Lx.events.narration_requested.emit(string_id, style, duration)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "PROMPT_READ_LORE" if active else ""


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-6.0, -3.0), Vector2(12.0, 9.0)) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if _glow_t > 0.0 or read_done:
		return Vector4(pos.x, pos.y - 6.0, 44.0 if _glow_t > 0.0 else 30.0, 0.72 if _glow_t > 0.0 else 0.42)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["read_done"] = read_done
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and bool(d.get("read_done", false)):
		read_done = true
		powered = true
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var lit: bool = read_done or _glow_t > 0.0
	var glow_on: bool = lit or _hover

	# Grounded drop shadow
	LxToyDraw.draw_contact_shadow(self, Vector2(2.0, 6.0), 8.0, 3.0)

	# Stepped ancient stone plinth base
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, 1.0, 16.0, 5.0), c_night, c_dusk, c_stone, c_void)
	draw_rect(Rect2(-3.0, 3.0, 1.0, 2.0), c_night)
	draw_rect(Rect2(4.0, 2.0, 1.0, 3.0), c_night)

	# Monolith body with sunlit chamfered top crown
	draw_rect(Rect2(-4.0, -17.0, 8.0, 3.0), c_void)
	draw_rect(Rect2(-6.0, -15.0, 12.0, 4.0), c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-6.0, -14.0, 12.0, 16.0), c_night, c_dusk, c_stone, c_void)
	# Chamfered cap stones catching sunlight on top-left
	draw_rect(Rect2(-5.0, -14.0, 10.0, 2.0), c_mauve)
	draw_rect(Rect2(-3.0, -16.0, 6.0, 2.0), c_stone)
	draw_rect(Rect2(-3.0, -16.0, 4.0, 1.0), c_cream)
	draw_rect(Rect2(-5.0, -14.0, 3.0, 1.0), c_cream)
	# Inner carved tablet face
	draw_rect(Rect2(-4.0, -12.0, 8.0, 12.0), c_night)
	draw_rect(Rect2(-4.0, -12.0, 8.0, 1.0), c_mauve if not glow_on else c_gold)

	# Mossy base tufts hugging the plinth corners
	draw_rect(Rect2(-8.0, 3.0, 3.0, 3.0), c_pine)
	draw_rect(Rect2(-7.0, 2.0, 2.0, 2.0), c_jade)
	draw_rect(Rect2(-7.0, 2.0, 1.0, 1.0), c_lime)
	draw_rect(Rect2(5.0, 3.0, 3.0, 3.0), c_pine)
	draw_rect(Rect2(5.0, 2.0, 2.0, 2.0), c_jade)
	draw_rect(Rect2(6.0, 2.0, 1.0, 1.0), c_lime)

	# Carved pictogram icon (glows clearly on hover or read)
	var c_ic: Color = c_cream if _glow_t > 0.0 else (c_gold if _hover and not lit else (c_glow if lit else c_stone))
	_draw_icon(Vector2(0.0, -8.0), c_ic, glow_on)

	# Two etched rune lines below the icon that illuminate on hover/read
	var rune_c: Color = c_cream if _glow_t > 0.0 else (c_gold if glow_on else c_mauve)
	var rune_hi: Color = c_cream if glow_on else c_stone
	draw_rect(Rect2(-3.0, -3.0, 2.0, 1.0), rune_hi)
	draw_rect(Rect2(0.0, -3.0, 3.0, 1.0), rune_c)
	draw_rect(Rect2(-3.0, -1.0, 4.0, 1.0), rune_c)
	draw_rect(Rect2(2.0, -1.0, 1.0, 1.0), rune_hi)

	# Subtle steady hover/read crown glint (flash_reduced-safe)
	if glow_on:
		var glint_on: bool = LxHudFx.flash_reduced() or _glow_t > 0.0 or int(floorf(_clock * 4.0)) % 2 == 0
		if glint_on:
			draw_rect(Rect2(-1.0, -15.0, 2.0, 1.0), c_cream)
	_draw_signal_pulses()


func _draw_icon(center: Vector2, col: Color, lit: bool) -> void:
	match icon_kind:
		"bell":
			LxHudFx.draw_biome_crest(self, 1, center, col, PAL["cream"] as Color if lit else col)
		"tide":
			LxHudFx.draw_biome_crest(self, 2, center, col, PAL["cream"] as Color if lit else col)
		"leaf":
			LxHudFx.draw_biome_crest(self, 3, center, col, PAL["cream"] as Color if lit else col)
		"clock":
			LxToyDraw.draw_shape_glyph(self, center, 0, lit, col, PAL["cream"] as Color)
		"star":
			LxHudFx.draw_biome_crest(self, 5, center, col, PAL["cream"] as Color if lit else col)
		"flame":
			LxHudFx.draw_biome_crest(self, 6, center, col, PAL["cream"] as Color if lit else col)
		"moon":
			LxHudFx.draw_biome_crest(self, 7, center, col, PAL["cream"] as Color if lit else col)
		"sun":
			LxHudFx.draw_biome_crest(self, 8, center, col, PAL["cream"] as Color if lit else col)
		"key":
			LxToyDraw.draw_shape_glyph(self, center, 4, lit, col, PAL["cream"] as Color)
		_:
			LxToyDraw.draw_shape_glyph(self, center, 1, lit, col, PAL["cream"] as Color)
