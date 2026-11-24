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


func _toy_setup() -> void:
	kind = "lore_stone"
	string_id = str(props.get("string_id", "")).strip_edges()
	icon_kind = str(props.get("icon", "lantern")).strip_edges().to_lower()
	duration = maxf(1.5, float(props.get("duration", 4.0)))
	style = str(props.get("style", "narration")).strip_edges()
	radius = maxf(12.0, radius)
	read_done = powered
	_glow_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist and read_done:
		return
	read_done = false
	_glow_t = 0.0
	if powered:
		set_powered(false)
		emit_power(false)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _glow_t > 0.0:
		_glow_t = maxf(0.0, _glow_t - dt)
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
	var c_glow: Color = LxBiomePalette.col(island_id, "glow")
	var lit: bool = read_done or _glow_t > 0.0

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 7.0, 2.5)
	# Beveled arched monolith
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, 1.0, 14.0, 5.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["stone"] as Color, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-6.0, -13.0, 12.0, 15.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["mauve"] as Color, c_void)
	draw_rect(Rect2(-4.0, -14.0, 8.0, 2.0), PAL["stone"] as Color)
	# Carved icon glyph
	var c_ic: Color = PAL["cream"] as Color if _glow_t > 0.0 else (c_glow if lit else PAL["stone"] as Color)
	_draw_icon(Vector2(0.0, -6.0), c_ic, lit)
	# Subtle inscribed lines below icon
	draw_rect(Rect2(-3.0, -1.0, 6.0, 1.0), c_glow if lit else PAL["mauve"] as Color)
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
