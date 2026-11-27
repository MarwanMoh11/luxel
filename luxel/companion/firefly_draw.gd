class_name LxFireflyDraw
extends RefCounted
## Pure pixel-snapped drawing helpers extracted from LxFireflyCompanion.
## Strictly uses the 20 Last Light colours (LxPalette.PAL) and integer stroke widths.


static func draw_companion(ci: CanvasItem, pip: LxFireflyCompanion) -> void:
	var pal: Dictionary = LxPalette.PAL
	var void_c: Color = pal["void"] as Color
	var tint: Dictionary = LxFireflyState.get_tint_colors()
	var c_core: Color = tint["core"] as Color
	var c_glow: Color = tint["glow"] as Color
	var c_wing: Color = tint["wing"] as Color
	var c_rim: Color = tint["rim"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var anim_t: float = pip._anim_t
	var gpos: Vector2 = pip.global_position
	var has_prism: bool = LxFireflyState.has_charm("prism_wing")
	var has_spark: bool = LxFireflyState.has_charm("sea_spark")

	if pip.tether_active:
		_draw_light_bridge(ci, pip, gpos, anim_t, fred, void_c, c_rim, c_glow, c_core, pal, has_spark)
	if pip.state == LxFireflyCompanion.State.GUIDE:
		_draw_guide_breadcrumbs(ci, pip, anim_t, fred, void_c, pal, has_prism)
	_draw_trail(ci, pip, gpos, void_c, c_core, c_glow, c_rim)
	if pip.state == LxFireflyCompanion.State.PERCH:
		var frac: float = clampf(pip.perch_timer / maxf(0.1, pip.perch_max), 0.0, 1.0)
		ci.draw_arc(Vector2(0.0, 2.0), 7.0, 0.0, TAU, 16, void_c, 3.0)
		ci.draw_arc(Vector2(0.0, 2.0), 7.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, c_glow if pip.perch_timer > 1.5 else (pal["coral"] as Color), 1.0)
	elif pip._hold_active and pip._hold_t > 0.12:
		var lim: float = LxFireflyCompanion.HOLD_SPECIAL_S if pip._hold_will_special else LxFireflyCompanion.HOLD_GUIDE_S
		var hfrac: float = clampf((pip._hold_t - 0.12) / maxf(0.08, lim - 0.12), 0.0, 1.0)
		var hcol: Color = (pal["gold"] if pip._hold_will_special else pal["lime"]) as Color
		ci.draw_arc(Vector2(0.0, -3.0), 7.0, 0.0, TAU, 14, void_c, 3.0)
		ci.draw_arc(Vector2(0.0, -3.0), 7.0, -PI * 0.5, -PI * 0.5 + TAU * hfrac, 14, hcol, 1.0)
	elif pip.state == LxFireflyCompanion.State.SPECIAL:
		ci.draw_arc(Vector2(0.0, -3.0), 9.0, 0.0, TAU, 16, void_c, 3.0)
		ci.draw_arc(Vector2(0.0, -3.0), 9.0, 0.0, TAU, 16, pal["gold"] as Color, 2.0)
	_draw_rings_and_sparks(ci, pip, gpos, void_c)
	_draw_body(ci, pip, anim_t, fred, void_c, c_wing, c_rim, c_glow, c_core, pal, has_prism)


static func _draw_light_bridge(
	ci: CanvasItem, pip: LxFireflyCompanion, gpos: Vector2, anim_t: float, fred: bool,
	void_c: Color, c_rim: Color, c_glow: Color, c_core: Color, pal: Dictionary, has_spark: bool
) -> void:
	var a := Vector2(0.0, -3.0)
	var b: Vector2 = (pip._tether_end + Vector2(0.0, -4.0) - gpos).round()
	var seg: Vector2 = b - a
	var total: float = seg.length()
	if total <= 4.0:
		return
	var sdir: Vector2 = seg / total
	ci.draw_line(a, b, void_c, 3.0)
	ci.draw_line(a, b, (pal["sky"] as Color) if has_spark else c_rim, 1.0)
	var off: float = fmod(anim_t * (12.0 if fred else 22.0), 9.0)
	var bi: int = 0
	while off < total:
		var bp: Vector2 = (a + sdir * off).round()
		ci.draw_rect(Rect2(bp - Vector2.ONE, Vector2(3.0, 3.0)), void_c)
		ci.draw_rect(Rect2(bp, Vector2(2.0, 2.0)), c_glow if (bi % 2 == 0) else (pal["gold"] as Color))
		ci.draw_rect(Rect2(bp, Vector2.ONE), c_core)
		off += 9.0
		bi += 1


static func _draw_guide_breadcrumbs(
	ci: CanvasItem, pip: LxFireflyCompanion, anim_t: float, fred: bool,
	void_c: Color, pal: Dictionary, has_prism: bool
) -> void:
	if pip._guide_dir.length_squared() < 0.01:
		return
	var is_sec: bool = has_prism and (pip._guide_kind in ["moth", "cracked_wall", "phantom_platform"])
	var c0: Color = (pal["ice"] if is_sec else pal["gold"]) as Color
	var c1: Color = (pal["sky"] if is_sec else pal["lime"]) as Color
	var phase: float = 0.0 if fred else fmod(anim_t * 2.4, 1.0)
	for i: int in range(3):
		var d: float = 8.0 + (float(i) + phase) * 6.0
		var bp: Vector2 = (Vector2(0.0, -3.0) + pip._guide_dir * d).round()
		var sz: float = 2.0 if i == 0 else 1.0
		ci.draw_rect(Rect2(bp - Vector2.ONE, Vector2(sz + 2.0, sz + 2.0)), void_c)
		ci.draw_rect(Rect2(bp, Vector2(sz, sz)), c0 if i < 2 else c1)


static func _draw_trail(
	ci: CanvasItem, pip: LxFireflyCompanion, gpos: Vector2,
	void_c: Color, c_core: Color, c_glow: Color, c_rim: Color
) -> void:
	for tm: Dictionary in pip._trail:
		var u: float = clampf(float(tm["age"]) / maxf(0.01, float(tm["life"])), 0.0, 1.0)
		var tp: Vector2 = ((tm["pos"] as Vector2) - gpos).round()
		var sz: float = 2.0 if u < 0.45 else 1.0
		ci.draw_rect(Rect2(tp - Vector2.ONE, Vector2(sz + 2.0, sz + 2.0)), void_c)
		ci.draw_rect(Rect2(tp, Vector2(sz, sz)), c_core if u < 0.3 else (c_glow if u < 0.68 else c_rim))


static func _draw_rings_and_sparks(ci: CanvasItem, pip: LxFireflyCompanion, gpos: Vector2, void_c: Color) -> void:
	for rg: Dictionary in pip._rings:
		var u: float = clampf(float(rg["age"]) / maxf(0.01, float(rg["life"])), 0.0, 1.0)
		var r: float = roundf(lerpf(float(rg["r0"]), float(rg["r1"]), u))
		var rp: Vector2 = ((rg["pos"] as Vector2) - gpos).round()
		ci.draw_arc(rp, r, 0.0, TAU, 20, void_c, 3.0)
		ci.draw_arc(rp, r, 0.0, TAU, 20, LxPalette.color(str(rg["col"]), "lime"), roundf(float(rg["w"])))
	for sp: Dictionary in pip._sparks:
		var sp_p: Vector2 = ((sp["pos"] as Vector2) - gpos).round()
		ci.draw_rect(Rect2(sp_p - Vector2.ONE, Vector2(3.0, 3.0)), void_c)
		ci.draw_rect(Rect2(sp_p, Vector2.ONE), LxPalette.color(str(sp["col"]), "lime"))


static func _draw_body(
	ci: CanvasItem, pip: LxFireflyCompanion, anim_t: float, fred: bool,
	void_c: Color, c_wing: Color, c_rim: Color, c_glow: Color, c_core: Color, pal: Dictionary, has_prism: bool
) -> void:
	var c := Vector2(0.0, -4.0 + (0.0 if fred else roundf(sin(anim_t * 6.5))))
	if not (pip.state == LxFireflyCompanion.State.FOLLOW and pip._idle_t > 3.2 and not pip._sense_active):
		ci.draw_rect(Rect2(-2.0, 2.0, 4.0, 1.0), void_c)
	var flap: float = 0.0 if fred else (1.0 if (int(floorf(anim_t * 18.0)) % 2 == 0) else -1.0)
	ci.draw_rect(Rect2(c + Vector2(-4.0, -3.0 + flap), Vector2(3.0, 3.0)), void_c)
	ci.draw_rect(Rect2(c + Vector2(1.0, -3.0 - flap), Vector2(3.0, 3.0)), void_c)
	ci.draw_rect(Rect2(c + Vector2(-2.0, -2.0), Vector2(5.0, 6.0)), void_c)
	ci.draw_rect(Rect2(c + Vector2(-3.0, -2.0 + flap), Vector2(2.0, 1.0)), c_wing)
	ci.draw_rect(Rect2(c + Vector2(2.0, -2.0 - flap), Vector2(2.0, 1.0)), c_wing)
	ci.draw_rect(Rect2(c + Vector2(-1.0, -1.0), Vector2(3.0, 2.0)), c_rim)
	ci.draw_rect(Rect2(c + Vector2(-1.0, 1.0), Vector2(3.0, 2.0)), c_glow)
	ci.draw_rect(Rect2(c + Vector2(0.0, 1.0), Vector2(1.0, 2.0)), c_core)
	if LxFireflyState.get_bond_rank() >= 3:
		ci.draw_rect(Rect2(c + Vector2(-1.0, -3.0), Vector2(1.0, 1.0)), pal["gold"] as Color)
		ci.draw_rect(Rect2(c + Vector2(1.0, -3.0), Vector2(1.0, 1.0)), pal["gold"] as Color)
	if LxFireflyState.get_charm_count() >= 4 and (fred or int(floorf(anim_t * 4.0)) % 2 == 0):
		ci.draw_rect(Rect2(c + Vector2(0.0, -4.0), Vector2(1.0, 1.0)), pal["cream"] as Color)
	if has_prism and pip._sense_active and pip._sense_is_secret and (fred or int(floorf(anim_t * 5.0)) % 2 == 0):
		ci.draw_rect(Rect2(c + Vector2(0.0, -6.0), Vector2(1.0, 1.0)), pal["ice"] as Color)
