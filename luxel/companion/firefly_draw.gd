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

	_draw_marked_enemies(ci, pip, gpos, anim_t, fred, void_c, c_glow, c_core, pal, has_prism)
	if pip.tether_active:
		_draw_tether(ci, pip, gpos, anim_t, fred, void_c, c_rim, c_glow, c_core, pal, has_spark)
	_draw_trail(ci, pip, gpos, void_c, c_core, c_glow, c_rim)
	if pip.state == LxFireflyCompanion.State.PERCH:
		var frac: float = clampf(pip.perch_timer / maxf(0.1, pip.perch_max), 0.0, 1.0)
		ci.draw_arc(Vector2(0.0, 2.0), 7.0, 0.0, TAU, 16, void_c, 3.0)
		ci.draw_arc(Vector2(0.0, 2.0), 7.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 16, c_glow if pip.perch_timer > 1.5 else (pal["coral"] as Color), 1.0)
	_draw_rings_and_sparks(ci, pip, gpos, void_c)
	_draw_body(ci, pip, anim_t, fred, void_c, c_wing, c_rim, c_glow, c_core, pal)


static func _draw_marked_enemies(
	ci: CanvasItem, pip: LxFireflyCompanion, gpos: Vector2, anim_t: float, fred: bool,
	void_c: Color, c_glow: Color, c_core: Color, pal: Dictionary, has_prism: bool
) -> void:
	var wick: LxWick = pip._owner_wick
	if wick == null or not is_instance_valid(wick):
		return
	for e_v: Variant in wick.world_get_enemies(pip._world_ctx):
		if not is_instance_valid(e_v) or not (e_v is Object):
			continue
		var enemy: Object = e_v as Object
		if not wick.is_entity_alive(enemy) or not pip.is_enemy_marked(enemy):
			continue
		var erad: float = wick.get_entity_radius(enemy, 8.0)
		var bob: float = 0.0 if fred else roundf(sin(anim_t * 6.0))
		var mp: Vector2 = (wick.get_entity_pos(enemy) + Vector2(0.0, -erad - 11.0 + bob) - gpos).round()
		ci.draw_rect(Rect2(mp + Vector2(-2.0, -2.0), Vector2(5.0, 5.0)), void_c)
		ci.draw_rect(Rect2(mp + Vector2(0.0, -3.0), Vector2(1.0, 7.0)), void_c)
		ci.draw_rect(Rect2(mp + Vector2(-3.0, 0.0), Vector2(7.0, 1.0)), void_c)
		ci.draw_rect(Rect2(mp + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), (pal["ice"] as Color) if has_prism else c_glow)
		ci.draw_rect(Rect2(mp + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), (pal["sky"] as Color) if has_prism else c_glow)
		ci.draw_rect(Rect2(mp + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), pal["gold"] as Color)
		ci.draw_rect(Rect2(mp, Vector2.ONE), c_core)


static func _draw_tether(
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
	ci.draw_line(a, b, void_c, 4.0 if has_spark else 3.0)
	ci.draw_line(a, b, (pal["sky"] as Color) if has_spark else c_rim, 2.0 if has_spark else 1.0)
	var off: float = fmod(anim_t * (14.0 if fred else 28.0), 8.0)
	var bi: int = 0
	while off < total:
		var bp: Vector2 = (a + sdir * off).round()
		ci.draw_rect(Rect2(bp - Vector2.ONE, Vector2(3.0, 3.0)), void_c)
		ci.draw_rect(Rect2(bp, Vector2(2.0, 2.0)), c_glow if (bi % 2 == 0) else (pal["gold"] as Color))
		ci.draw_rect(Rect2(bp, Vector2.ONE), c_core)
		off += 8.0
		bi += 1


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
	void_c: Color, c_wing: Color, c_rim: Color, c_glow: Color, c_core: Color, pal: Dictionary
) -> void:
	var c := Vector2(0.0, -4.0 + (0.0 if fred else roundf(sin(anim_t * 6.5))))
	if not (pip.state == LxFireflyCompanion.State.FOLLOW and pip._idle_t > 3.5 and not pip._sense_active):
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
