class_name LxToyTemperAnvil
extends LxToy
## Island 6 Blacksmith Tempering Anvil (bible section 6.1).
## Reforges Wick's bolt temper ("", "skip", "scatter", "lance") via interact (E) or bolt/throw hit.
## Persists active temper + known flags through LxIsland6Rule, triggers the anvil ceremony,
## and renders a crisp wrought-iron anvil with a distinct greyscale-readable glyph per mode.
##
## Props:
##   mode: "skip" | "scatter" | "lance" | "base" | "cycle" (default "skip")
##   sets_flag: String (optional extra story flag set on strike)
##   hit_to_swap: bool (default true; bolt/throw/beam strikes also forge)
##   ceremony: bool (default true)
##   include_base: bool (default false; for cycle mode, whether "" is in the ring)
##   prompt_key: String (default "ISL6_PROMPT_ANVIL")

enum AnvilState { READY, STRUCK }

const STRUCK_DUR: float = 0.35

var mode: String = "skip"
var sets_flag: String = ""
var hit_to_swap: bool = true
var ceremony: bool = true
var include_base: bool = false
var state: int = AnvilState.READY
var last_forged: String = ""
var _struck_t: float = 0.0
var _cd: float = 0.0


func _toy_setup() -> void:
	kind = "temper_anvil"
	mode = str(props.get("mode", "skip")).strip_edges().to_lower()
	if mode not in ["skip", "scatter", "lance", "base", "cycle"]:
		mode = "skip"
	sets_flag = str(props.get("sets_flag", "")).strip_edges()
	hit_to_swap = bool(props.get("hit_to_swap", true))
	ceremony = bool(props.get("ceremony", true))
	include_base = bool(props.get("include_base", false))
	size = Vector2(18.0, 12.0)
	radius = 16.0
	state = AnvilState.READY
	last_forged = ""
	_struck_t = 0.0
	_cd = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	state = AnvilState.READY
	_struck_t = 0.0
	_cd = 0.0
	set_powered(false)
	queue_redraw()


func is_solid() -> bool:
	return active


func blocks_sight() -> bool:
	return false


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-8.0, -3.0), Vector2(16.0, 9.0)) if active else Rect2()


func get_interact_prompt() -> String:
	if not active:
		return ""
	var pk: String = str(props.get("prompt_key", "ISL6_PROMPT_ANVIL")).strip_edges()
	return pk if not pk.is_empty() else "ISL6_PROMPT_ANVIL"


func interact(_actor: Node = null) -> bool:
	if not active or _cd > 0.0:
		return false
	return _forge()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or not hit_to_swap or _cd > 0.0:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_BEAM, LxHit.SOURCE_ZIP, LxHit.SOURCE_SUNFLARE]:
		return _forge()
	return false


func _resolve_target_mode() -> String:
	if mode == "base":
		return ""
	if mode in ["skip", "scatter", "lance"]:
		return mode
	var cur: String = (Lx.player as LxWick).temper if (Lx.player is LxWick and is_instance_valid(Lx.player)) else LxIsland6Rule.get_saved_temper()
	return LxIsland6Rule.next_cycle_temper(cur, include_base)


func _forge() -> bool:
	var target_m: String = _resolve_target_mode()
	last_forged = LxIsland6Rule.apply_temper(target_m, pos + Vector2(0.0, -5.0), ceremony)
	if not sets_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag] = true
	state = AnvilState.STRUCK
	_struck_t = STRUCK_DUR
	_cd = 0.22
	_emit_gust(44.0, 48.0, Vector2(0.0, -4.0))
	set_powered(true)
	emit_power(true)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _struck_t > 0.0:
		_struck_t = maxf(0.0, _struck_t - dt)
		if _struck_t <= 0.0:
			state = AnvilState.READY
		dirty = true
	if not LxHudFx.flash_reduced():
		dirty = true
	if dirty:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 44.0 if state == AnvilState.STRUCK else 28.0, 0.78 if state == AnvilState.STRUCK else 0.42)


func _display_mode() -> String:
	if mode == "cycle":
		if not last_forged.is_empty():
			return last_forged
		var cur: String = (Lx.player as LxWick).temper if (Lx.player is LxWick and is_instance_valid(Lx.player)) else LxIsland6Rule.get_saved_temper()
		return cur if not cur.is_empty() else "cycle"
	return mode


func _mode_color(m: String) -> Color:
	match m:
		"skip": return PAL["gold"] as Color
		"scatter": return PAL["apricot"] as Color
		"lance": return PAL["coral"] as Color
		"base": return PAL["stone"] as Color
		_: return PAL["cream"] as Color


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var fr: bool = LxHudFx.flash_reduced()
	var struck: bool = state == AnvilState.STRUCK
	var dm: String = _display_mode()
	var mc: Color = _mode_color(dm)
	var wick_has_this: bool = (Lx.player is LxWick and is_instance_valid(Lx.player) and (Lx.player as LxWick).temper == dm and mode != "cycle")

	# Grounded contact shadow beneath timber stump
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 8.0), 11.0, 3.5)

	# Sturdy blacksmith timber stump base with bark grain & forged-iron hoop band
	draw_rect(Rect2(-9.0, 2.0, 18.0, 7.0), c_void)
	draw_rect(Rect2(-8.0, 3.0, 16.0, 5.0), c_wine)
	draw_rect(Rect2(-8.0, 3.0, 16.0, 1.0), c_apr)
	draw_rect(Rect2(-8.0, 6.0, 16.0, 2.0), c_night)
	# Vertical timber grain striations
	for gx: float in [-6.0, -2.0, 2.0, 6.0]:
		draw_rect(Rect2(gx, 3.0, 1.0, 5.0), c_dusk)
	# Iron binding hoop wrapping the stump
	draw_rect(Rect2(-8.0, 5.0, 16.0, 2.0), c_dusk)
	draw_rect(Rect2(-8.0, 5.0, 10.0, 1.0), c_stone)
	draw_rect(Rect2(-5.0, 5.0, 1.0, 1.0), c_ice)
	draw_rect(Rect2(4.0, 5.0, 1.0, 1.0), c_ice)

	# Anvil forged base foot & sculpted tapered waist
	draw_rect(Rect2(-7.0, 0.0, 14.0, 3.0), c_void)
	draw_rect(Rect2(-6.0, 1.0, 12.0, 2.0), c_dusk)
	draw_rect(Rect2(-6.0, 1.0, 5.0, 1.0), c_stone)
	draw_rect(Rect2(-4.0, -2.0, 8.0, 3.0), c_void)
	draw_rect(Rect2(-3.0, -2.0, 6.0, 3.0), c_night)
	draw_rect(Rect2(-3.0, -2.0, 2.0, 2.0), c_dusk)

	# Sculpted wrought-iron anvil body + tapered steel horn (left) & hardy heel (right)
	draw_rect(Rect2(-11.0, -6.0, 21.0, 5.0), c_void)
	draw_rect(Rect2(-7.0, -2.0, 15.0, 2.0), c_void)
	# Tapered left horn with crisp sunlit steel top bevel (stone/ice)
	draw_rect(Rect2(-10.0, -5.0, 5.0, 2.0), c_stone)
	draw_rect(Rect2(-10.0, -5.0, 5.0, 1.0), c_cream if struck else c_ice)
	draw_rect(Rect2(-8.0, -3.0, 3.0, 1.0), c_dusk)
	# Heavy anvil body & sunlit steel top forging face
	draw_rect(Rect2(-5.0, -5.0, 14.0, 4.0), c_mauve if struck else c_dusk)
	draw_rect(Rect2(-5.0, -2.0, 12.0, 1.0), c_night)
	draw_rect(Rect2(-5.0, -5.0, 14.0, 1.0), c_cream if struck else c_ice)
	draw_rect(Rect2(-4.0, -4.0, 12.0, 1.0), c_gold if struck else c_stone)
	# Hardy hole notch on right heel
	draw_rect(Rect2(6.0, -5.0, 2.0, 1.0), c_void)

	# Bright molten tempering glow & rising forge sparks on anvil face when active or struck
	if struck or wick_has_this:
		var glow_hot: bool = struck or fr or (int(floorf(_clock * 5.0)) % 2 == 0)
		draw_rect(Rect2(-4.0, -5.0, 9.0, 1.0), c_cream if struck else (c_gold if glow_hot else c_apr))
		draw_rect(Rect2(-3.0, -4.0, 7.0, 1.0), c_apr if struck else c_coral)
		if wick_has_this:
			draw_rect(Rect2(-6.0, 2.0, 12.0, 1.0), mc)
		# Crisp pixel forge sparks rising off the tempering face
		var spark_n: int = 5 if struck else 3
		for si: int in range(spark_n):
			var su: float = (0.35 + float(si) * 0.14) if fr else fmod(_clock * (3.6 if struck else 1.8) + float(si) * 0.27, 1.0)
			var sx: float = roundf(-3.0 + float(si) * 2.2 + (0.0 if fr else sin(_clock * 6.0 + float(si) * 1.7) * 1.5))
			var sy: float = roundf(-6.0 - su * (8.0 if struck else 5.0))
			draw_rect(Rect2(sx, sy, 1.0, 1.0), c_cream if su < 0.35 else (c_gold if su < 0.7 else c_coral))

	# Floating forged bolt glyph above anvil (distinct silhouette per temper for greyscale legibility!)
	var bob: float = 0.0 if fr else roundf(sin(_clock * 4.0) * 1.2)
	var gy: float = -13.0 + bob
	var gc := Vector2(1.0, gy)
	if struck:
		var u: float = 1.0 - clampf(_struck_t / STRUCK_DUR, 0.0, 1.0)
		var rr: float = roundf(lerpf(4.0, 16.0, u))
		draw_arc(Vector2(1.0, -4.0), rr, 0.0, TAU, 14, Color(c_cream, (1.0 - u) * (0.6 if fr else 1.0)), 2.0)
	_draw_forged_glyph(gc, dm, c_cream if struck else mc, c_void, c_cream)
	_draw_signal_pulses()


func _draw_forged_glyph(c: Vector2, m: String, col: Color, outline: Color, hi: Color) -> void:
	var p: Vector2 = c.round()
	match m:
		"skip": # Bent ricochet arrow (up then right-down)
			draw_rect(Rect2(p.x - 4.0, p.y - 3.0, 9.0, 7.0), outline)
			draw_rect(Rect2(p.x - 3.0, p.y + 1.0, 3.0, 1.0), col)
			draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 1.0, 3.0), col)
			draw_rect(Rect2(p.x, p.y - 2.0, 3.0, 1.0), hi)
			draw_rect(Rect2(p.x + 2.0, p.y - 1.0, 2.0, 2.0), col)
		"scatter": # 3-bolt diverging fan
			for off: Vector2 in [Vector2(-3.0, -2.0), Vector2(0.0, -3.0), Vector2(3.0, -2.0)]:
				draw_rect(Rect2(p + off - Vector2.ONE, Vector2(3.0, 4.0)), outline)
				draw_rect(Rect2(p + off, Vector2(1.0, 2.0)), col)
			draw_rect(Rect2(p.x, p.y - 3.0, 1.0, 1.0), hi)
		"lance": # Tall piercing spearhead
			draw_rect(Rect2(p.x - 2.0, p.y - 5.0, 5.0, 10.0), outline)
			draw_rect(Rect2(p.x, p.y - 4.0, 1.0, 8.0), col)
			draw_rect(Rect2(p.x - 1.0, p.y - 3.0, 3.0, 2.0), hi)
			draw_rect(Rect2(p.x - 1.0, p.y + 1.0, 3.0, 1.0), col)
		"cycle": # 3-temper rotating triad ring
			draw_rect(Rect2(p.x - 4.0, p.y - 4.0, 9.0, 8.0), outline)
			draw_rect(Rect2(p.x - 3.0, p.y + 1.0, 2.0, 2.0), PAL["gold"] as Color)
			draw_rect(Rect2(p.x, p.y - 3.0, 2.0, 2.0), PAL["apricot"] as Color)
			draw_rect(Rect2(p.x + 2.0, p.y + 1.0, 2.0, 2.0), PAL["coral"] as Color)
		_: # Base diamond
			draw_rect(Rect2(p.x - 2.0, p.y - 2.0, 5.0, 5.0), outline)
			draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 3.0, 3.0), col)
			draw_rect(Rect2(p.x, p.y - 1.0, 1.0, 1.0), hi)
