class_name LxRestShrine
extends LxInteractable
## Lamplighter's Rest upgrade shrine: heals Wick and opens the lantern upgrade UI.


var _heal_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "rest_shrine"
	_uses_prop_anim = active
	_heal_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	_uses_prop_anim = active
	super.tick(dt)
	if _heal_t > 0.0:
		_heal_t = maxf(0.0, _heal_t - dt)
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_heal_t = 0.48
	if Lx.state != null:
		Lx.state.heal_full()
	_emit_sfx("rest_shrine")
	_emit_gust(62.0, 50.0, Vector2(0.0, -8.0))
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.BLOSSOM, pos, 15.0, 6.0)
	if Lx.ui != null and Lx.ui.has_method("open_rest_shop"):
		Lx.ui.call("open_rest_shop")
	elif Lx.events != null:
		Lx.events.prompt_requested.emit("SHOP_TITLE", "lx_interact", 2.0)
	_emit_save("rest_shrine")
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	var surge: float = (sin((1.0 - clampf(_heal_t / 0.48, 0.0, 1.0)) * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)) if _heal_t > 0.0 else 0.0
	return Vector4(pos.x, pos.y - 10.0, 74.0 + surge * 34.0, 1.2 + surge * 0.35)


func get_interact_prompt() -> String:
	return "PROMPT_REST_SHRINE"


func _draw() -> void:
	var shadow: Color = PAL["void"] as Color
	draw_rect(Rect2(-16.0, 2.0, 32.0, 2.0), shadow)
	draw_rect(Rect2(-14.0, 1.0, 28.0, 4.0), shadow)
	draw_rect(Rect2(-10.0, 0.0, 20.0, 6.0), shadow)
	if active:
		_draw_hearth_ring()
	var frame_ov: int = -1 if active else 0
	if not _draw_prop_sprite("rest_shrine", Vector2.ZERO, frame_ov):
		_draw_fallback()
	if active:
		_draw_hearth_embers()
	if _heal_t > 0.0:
		var p: float = 1.0 - clampf(_heal_t / 0.48, 0.0, 1.0)
		var c_hi: Color = LxBiomePalette.col(island_id, "core")
		var c_gl: Color = LxBiomePalette.col(island_id, "glow")
		draw_arc(Vector2(0.0, -8.0), roundf(6.0 + p * 24.0), 0.0, TAU, 20, c_hi if p < 0.35 else c_gl, 1.0)
		for j: int in range(6):
			var a: float = float(j) * TAU / 6.0 + p * 0.8
			var sp := Vector2(roundf(cos(a) * (5.0 + p * 18.0)), roundf(-10.0 + sin(a) * (2.0 + p * 7.0) - p * 10.0))
			draw_rect(Rect2(sp, Vector2.ONE), c_hi if j % 2 == 0 else c_gl)


func _draw_fallback() -> void:
	draw_rect(Rect2(-10.0, -4.0, 20.0, 8.0), PAL["night"] as Color)
	draw_rect(Rect2(-9.0, -6.0, 18.0, 8.0), PAL["mauve"] as Color)
	draw_rect(Rect2(-6.0, -16.0, 12.0, 12.0), PAL["stone"] as Color)
	draw_circle(Vector2(0.0, -12.0), 4.0, LxBiomePalette.col(island_id, "hi"))
	draw_circle(Vector2(0.0, -12.0), 2.5, LxBiomePalette.col(island_id, "glow"))
	draw_circle(Vector2(0.0, -12.0), 1.2, LxBiomePalette.col(island_id, "core"))


func _draw_hearth_ring() -> void:
	var fr: bool = LxHudFx.flash_reduced()
	var breath: float = 0.0 if fr else sin(_clock * 2.2) * 1.4
	var rx: float = 19.0 + breath
	var ry: float = 5.2 + breath * 0.3
	var c_gold: Color = LxBiomePalette.col(island_id, "glow")
	var c_apr: Color = LxBiomePalette.col(island_id, "hi")
	var c_dim := Color(c_apr, 0.42)
	# Subtle biome-framed sanctuary floor notches flanking the hearth
	draw_rect(Rect2(-21.0, 2.0, 3.0, 1.0), c_dim)
	draw_rect(Rect2(18.0, 2.0, 3.0, 1.0), c_dim)
	draw_rect(Rect2(-3.0, 7.0, 6.0, 1.0), c_dim)
	LxHudFx.draw_biome_crest(self, island_id, Vector2(0.0, 6.0), c_gold, LxBiomePalette.col(island_id, "core"))
	var spin: float = 0.0 if fr else _clock * 0.45
	for i: int in range(4):
		var a: float = spin + (TAU * float(i)) / 4.0
		var px: float = roundf(cos(a) * rx)
		var py: float = roundf(2.0 + sin(a) * ry)
		draw_rect(Rect2(px - 1.0, py, 2.0, 1.0), c_gold if i % 2 == 0 else c_apr)
	if Lx.player is Node2D and is_instance_valid(Lx.player):
		var d_w: float = (Lx.player as Node2D).global_position.distance_to(pos)
		if d_w <= 56.0:
			var prox: float = clampf(1.0 - d_w / 56.0, 0.0, 1.0)
			var wa: float = (0.30 if fr else 0.44) * prox
			var c_core: Color = LxBiomePalette.col(island_id, "core")
			draw_arc(Vector2(0.0, 2.0), roundf(22.0 + breath * 0.4), spin, spin + PI * 0.8, 12, Color(c_gold, wa), 1.0)
			draw_arc(Vector2(0.0, 2.0), roundf(22.0 + breath * 0.4), spin + PI, spin + PI * 1.8, 12, Color(c_core, wa), 1.0)
			for si: int in range(2):
				var su: float = fposmod(_clock * 0.65 + float(si) * 0.5, 1.0)
				var sx: float = roundf((-14.0 if si == 0 else 14.0) + sin(_clock * 2.0 + float(si) * 3.1) * 2.0)
				draw_rect(Rect2(sx, roundf(0.0 - su * 18.0), 1.0, 1.0), Color(c_core if su < 0.45 else c_gold, sin(su * PI) * prox * 0.85))


func _draw_hearth_embers() -> void:
	var fr: bool = LxHudFx.flash_reduced()
	var c_cream: Color = LxBiomePalette.col(island_id, "core")
	var c_gold: Color = LxBiomePalette.col(island_id, "glow")
	var c_apr: Color = LxBiomePalette.col(island_id, "hi")
	var crown_y: float = -24.0 + (0.0 if fr else roundf(sin(_clock * 2.2) * 1.0))
	draw_rect(Rect2(-1.0, crown_y, 3.0, 1.0), c_gold)
	draw_rect(Rect2(0.0, crown_y - 1.0, 1.0, 3.0), c_gold)
	draw_rect(Rect2(0.0, crown_y, 1.0, 1.0), c_cream)
	for i: int in range(3):
		var t: float = fmod(_clock * 0.46 + float(i) * 0.33, 1.0)
		var px: float = roundf(sin(_clock * 1.6 + float(i) * 2.1) * (2.5 + t * 3.0))
		var py: float = roundf(-20.0 - t * 18.0)
		var col: Color = c_cream if t < 0.3 else (c_gold if t < 0.7 else c_apr)
		draw_rect(Rect2(px, py, 1.0, 1.0), col)
