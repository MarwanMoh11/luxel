class_name LxFireflyPerch
extends Node2D
## Dungeon Firefly Sanctuary Perch: ignites when Pip passes or perches near it.
## Grants +1 Nectar (with Bond Rank check), +25 shards, and +0.5 heart when Wick is injured.
## While Pip perches here, projects a wide golden-lime sanctuary pool and flags sanctuary buff.
## Strictly uses the 20 Last Light colours (LxPalette.PAL) and integer pixel-snapped drawing.

const RADIUS: float = 14.0
const HOLD_RADIUS: float = 22.0

var perch_id: String = ""
var pos: Vector2 = Vector2.ZERO
var island_id: int = 1
var lit: bool = false
var pip_holding: bool = false

var _clock: float = 0.0
var _ignite_t: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(p_id: String, p_pos: Vector2, p_island: int) -> void:
	perch_id = p_id
	pos = p_pos.round()
	island_id = clampi(p_island, 1, 8)
	position = pos
	lit = LxFireflyState.is_perch_lit(p_id)
	pip_holding = false
	_ignite_t = 0.0
	_phase = absf(pos.x * 0.027 + pos.y * 0.019)
	name = p_id if not p_id.is_empty() else "FireflyPerch"
	queue_redraw()


func tick(dt: float, pip_pos: Vector2, pip_perched: bool) -> bool:
	_clock += dt
	if _ignite_t > 0.0:
		_ignite_t = maxf(0.0, _ignite_t - dt)
	pip_holding = pip_perched and pip_pos.is_finite() and pip_pos.distance_to(pos) <= HOLD_RADIUS
	queue_redraw()
	return pip_holding


func try_ignite(_pip: Node = null) -> bool:
	if lit:
		return false
	lit = true
	_ignite_t = 0.90
	var res: Dictionary = LxFireflyState.light_perch(perch_id)
	if Lx.state != null:
		Lx.state.add_shards(25)
		if Lx.state.hearts < float(Lx.state.max_hearts):
			Lx.state.hearts = minf(float(Lx.state.max_hearts), Lx.state.hearts + 0.5)
			if Lx.events != null:
				Lx.events.player_healed.emit(0.5)
	elif Lx.events != null:
		Lx.events.shard_collected.emit(25)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		var eff_i: float = 0.88 if LxHudFx.flash_reduced() else 1.32
		LxDarknessLayer.active_instance.add_burst_light(pos, 104.0, eff_i, 0.55)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_bloom", pos, true)
	if bool(res.get("ranked_up", false)):
		_announce_bond_up(int(res.get("rank", LxFireflyState.get_bond_rank())))
	elif Lx.events != null:
		Lx.events.narration_requested.emit("PIP_PERCH_LIT", "narration", 2.6)
	if Lx.events != null:
		Lx.events.save_requested.emit("pip_perch")
	queue_redraw()
	return true


func _announce_bond_up(rank: int) -> void:
	if Lx.events != null:
		Lx.events.sfx_requested.emit("pip_bond_up", pos, false)
	var desc_key: String = LxFireflyState.get_bond_desc_key(rank)
	var nar: Object = Lx.ui.get("narration") as Object if (Lx.ui != null and Lx.ui.get("narration") is Object) else null
	if nar != null and is_instance_valid(nar) and nar.has_method("say_lines"):
		var lines := PackedStringArray([LxStrings.fmt("PIP_BOND_UP_FMT", [rank])])
		if not desc_key.is_empty():
			lines.append(LxStrings.text(desc_key))
		nar.call("say_lines", lines, "title", 3.2, -1.0, 1, "title")
	elif Lx.events != null and not desc_key.is_empty():
		Lx.events.narration_requested.emit(desc_key, "title", 3.0)


func get_light_pool() -> Vector4:
	return Vector4(
		pos.x,
		pos.y - 6.0,
		108.0 if pip_holding else (76.0 if lit else 34.0),
		1.24 if pip_holding else (0.98 if lit else 0.55)
	)


func _draw() -> void:
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var bio_dark: Color = LxBiomePalette.col(island_id, "dark")
	var bio_mid: Color = LxBiomePalette.col(island_id, "mid")
	var bio_hi: Color = LxBiomePalette.col(island_id, "hi")
	var brass_hi: Color = (pal["gold"] if (lit or pip_holding) else pal["apricot"]) as Color
	var brass_mid: Color = (pal["apricot"] if (lit or pip_holding) else pal["mauve"]) as Color

	# Gentle expanding sanctuary ring when Pip is holding the perch
	if pip_holding:
		var pulse_u: float = 0.45 if fred else fmod(_clock * 0.72 + _phase, 1.0)
		var ring_r: float = roundf(lerpf(12.0, 26.0, pulse_u))
		draw_arc(Vector2(0.0, -7.0), ring_r, 0.0, TAU, 20, void_c, 3.0)
		draw_arc(Vector2(0.0, -7.0), ring_r, 0.0, TAU, 20, (pal["lime"] if pulse_u < 0.55 else pal["gold"]) as Color, 1.0)
		draw_arc(Vector2(0.0, -7.0), 11.0, 0.0, TAU, 16, void_c, 3.0)
		draw_arc(Vector2(0.0, -7.0), 11.0, 0.0, TAU, 16, pal["cream"] as Color, 1.0)

	# Void-backed ornate pedestal & hanging crook silhouette
	draw_rect(Rect2(-6.0, -2.0, 12.0, 5.0), void_c)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 3.0), void_c)
	draw_rect(Rect2(-2.0, -16.0, 4.0, 14.0), void_c)
	draw_rect(Rect2(-5.0, -16.0, 10.0, 3.0), void_c)
	draw_rect(Rect2(-5.0, -13.0, 10.0, 9.0), void_c)

	# Dark stone & brass pedestal base
	draw_rect(Rect2(-5.0, -1.0, 10.0, 3.0), pal["dusk"] as Color)
	draw_rect(Rect2(-4.0, -1.0, 8.0, 1.0), pal["plum"] as Color)
	draw_rect(Rect2(-3.0, -3.0, 6.0, 2.0), brass_mid)
	draw_rect(Rect2(-2.0, -3.0, 4.0, 1.0), brass_hi)

	# Hanging brass frame & finial cap
	draw_rect(Rect2(-4.0, -15.0, 8.0, 1.0), brass_hi)
	draw_rect(Rect2(-1.0, -16.0, 2.0, 1.0), pal["cream"] as Color if lit else brass_hi)
	draw_rect(Rect2(-4.0, -14.0, 1.0, 9.0), brass_mid)
	draw_rect(Rect2(3.0, -14.0, 1.0, 9.0), brass_mid)
	draw_rect(Rect2(-3.0, -5.0, 6.0, 1.0), brass_hi)

	# Biome-tinted glass pollen bulb
	draw_rect(Rect2(-3.0, -13.0, 6.0, 8.0), pal["night"] as Color)
	draw_rect(Rect2(-2.0, -12.0, 4.0, 6.0), bio_mid if (lit or pip_holding) else bio_dark)
	draw_rect(Rect2(-3.0, -12.0, 1.0, 5.0), pal["ice"] as Color if lit else pal["sky"] as Color)
	draw_rect(Rect2(2.0, -12.0, 1.0, 5.0), bio_hi if lit else pal["blue"] as Color)

	# Inner firefly beacon or dormant faint spark
	if pip_holding or lit:
		var pulse_on: bool = fred or (int(floorf(_clock * 4.0 + _phase)) % 2 == 0)
		var core_c: Color = (pal["cream"] if (pip_holding or pulse_on) else pal["gold"]) as Color
		var glow_c: Color = (pal["lime"] if (pip_holding or not pulse_on) else pal["gold"]) as Color
		draw_rect(Rect2(-2.0, -11.0, 4.0, 4.0), glow_c)
		draw_rect(Rect2(-1.0, -10.0, 2.0, 2.0), core_c)
		if pip_holding:
			draw_rect(Rect2(-1.0, -12.0, 2.0, 1.0), pal["cream"] as Color)
		# Gentle rising pollen specks
		var mote_n: int = 1 if fred else (3 if pip_holding else 2)
		for i: int in range(mote_n):
			var u: float = fmod(_clock * (0.30 if fred else 0.65) + _phase + float(i) * 0.33, 1.0)
			var mx: float = roundf(sin(_clock * 2.2 + float(i) * 2.1 + _phase) * (2.0 + u * 3.0))
			var my: float = roundf(-14.0 - u * 9.0)
			draw_rect(Rect2(mx - 1.0, my - 1.0, 3.0, 3.0), void_c)
			draw_rect(Rect2(mx, my, 1.0, 1.0), (pal["cream"] if u < 0.35 else pal["lime"]) as Color)
	else:
		var sy: float = -9.0 if fred else roundf(-9.0 + sin(_clock * 2.4 + _phase) * 1.0)
		var faint_on: bool = fred or (int(floorf(_clock * 2.2 + _phase)) % 2 == 0)
		draw_rect(Rect2(-1.0, sy, 2.0, 1.0), (pal["lime"] if faint_on else pal["jade"]) as Color)
		draw_rect(Rect2(0.0, sy, 1.0, 1.0), pal["gold"] as Color if faint_on else pal["lime"] as Color)

	# Ignite flare ring
	if _ignite_t > 0.0:
		var iu: float = 1.0 - clampf(_ignite_t / 0.90, 0.0, 1.0)
		var ir: float = roundf(lerpf(5.0, 28.0, iu))
		draw_arc(Vector2(0.0, -9.0), ir, 0.0, TAU, 18, void_c, 3.0)
		draw_arc(Vector2(0.0, -9.0), ir, 0.0, TAU, 18, (pal["cream"] if iu < 0.35 else pal["lime"]) as Color, 2.0)
