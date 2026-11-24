class_name LxMinibossPedestalArt
extends RefCounted
## Bespoke 16x18px grounded biome pedestals for Islands 2..8 Mini-Boss Arenas
## and Island 4 Boss Sanctum (Stained-Glass Rose Wind Chime).
## Strictly uses the 20 Last Light colours (LxPalette.PAL) and respects flash_reduced.

const PAL: Dictionary = LxPalette.PAL


static func _p(k: String) -> Color:
	return PAL[k] as Color


static func draw_pedestal_base(
	ci: CanvasItem, ap: Vector2, ready: bool, cd_frac: float, boss_vulnerable_pulse: bool,
	glow_col: Color, hi_col: Color, clock: float, settled: bool, fred: bool
) -> void:
	var p: Vector2 = ap.round()
	var sh_c := Color(_p("void"), 0.40)
	ci.draw_rect(Rect2(p + Vector2(-9.0, 0.0), Vector2(18.0, 3.0)), sh_c)
	ci.draw_rect(Rect2(p + Vector2(-7.0, -1.0), Vector2(14.0, 5.0)), sh_c)
	if settled:
		return
	if ready:
		var pulse: float = 0.0 if fred else sin(clock * (4.8 if boss_vulnerable_pulse else 2.8) + p.x * 0.03)
		var ra: float = (0.58 if boss_vulnerable_pulse else 0.34) + (0.0 if fred else pulse * (0.20 if boss_vulnerable_pulse else 0.08))
		var r_ring: float = roundf(11.0 + (pulse * 1.2 if boss_vulnerable_pulse else 0.0))
		ci.draw_arc(p + Vector2(0.0, 1.0), r_ring, 0.0, TAU, 18, Color(glow_col, clampf(ra, 0.2, 0.85)), 1.4 if boss_vulnerable_pulse else 1.0)
	else:
		var prog: float = clampf(cd_frac, 0.0, 1.0)
		ci.draw_arc(p + Vector2(0.0, 1.0), 10.0, 0.0, TAU, 16, Color(_p("dusk"), 0.45), 1.0)
		if prog > 0.01:
			ci.draw_arc(p + Vector2(0.0, 1.0), 10.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 16, Color(hi_col, 0.65), 1.2)


static func _draw_pedestal_fx(
	ci: CanvasItem, p: Vector2, head_off: Vector2, flash_t: float, flash_dur: float,
	shock_r: float, ready_t: float, c_out: Color, c_mid: Color, c_core: Color,
	settled: bool, fred: bool
) -> void:
	var hc: Vector2 = (p + head_off).round()
	if ready_t > 0.0 and not settled:
		var ru: float = 1.0 - clampf(ready_t / 0.42, 0.0, 1.0)
		ci.draw_arc(hc, roundf(lerpf(6.0, 22.0, ru)), 0.0, TAU, 16, Color(c_out, (1.0 - ru) * 0.65), 1.1)
	if flash_t > 0.0:
		var u: float = 1.0 - clampf(flash_t / maxf(0.1, flash_dur), 0.0, 1.0)
		var fa: float = (1.0 - u) * (0.56 if fred else 0.90)
		var r_out: float = roundf(lerpf(10.0, shock_r, u))
		ci.draw_arc(p, r_out, 0.0, TAU, 30, Color(c_out, fa), 2.0)
		ci.draw_arc(p, maxf(2.0, r_out - 3.0), 0.0, TAU, 26, Color(c_mid, fa * 0.72), 1.2)
		ci.draw_arc(p, roundf(lerpf(6.0, shock_r * 0.74, u)), 0.0, TAU, 22, Color(c_core, fa * 0.84), 1.2)
		for k: int in range(8):
			var kp: Vector2 = (p + Vector2.from_angle(float(k) * (TAU / 8.0) + u * 0.42) * r_out).round()
			ci.draw_rect(Rect2(kp - Vector2.ONE, Vector2(2.0, 2.0)), Color(c_core if k % 2 == 0 else c_out, fa))


static func draw_island_pedestal(
	ci: CanvasItem, island_id: int, ap: Vector2, ready: bool, cd_frac: float,
	boss_pulse: bool, clock: float, settled: bool, fred: bool,
	flash_t: float = 0.0, ready_t: float = 0.0
) -> void:
	match island_id:
		2: draw_fresnel_post(ci, ap, ready, cd_frac, boss_pulse, clock, settled, fred, flash_t, ready_t)
		3: draw_sap_stump(ci, ap, ready, cd_frac, boss_pulse, clock, settled, fred, flash_t, ready_t)
		4: draw_rose_chime(ci, ap, ready, cd_frac, boss_pulse, clock, settled, fred, flash_t, ready_t, false, 115.0)
		5: draw_astrolabe_pedestal(ci, ap, ready, cd_frac, boss_pulse, clock, settled, fred, flash_t, ready_t)
		6: draw_forge_brazier(ci, ap, ready, cd_frac, boss_pulse, clock, settled, fred, flash_t, ready_t)
		7: draw_moon_mirror(ci, ap, ready, cd_frac, boss_pulse, clock, settled, fred, flash_t, ready_t)
		8: draw_cathedral_altar(ci, ap, ready, cd_frac, boss_pulse, clock, settled, fred, flash_t, ready_t)


# Island 2 — Brass Fresnel Lamp Post (lighthouse_r6)
static func draw_fresnel_post(
	ci: CanvasItem, ap: Vector2, ready: bool, cd_frac: float, boss_pulse: bool,
	clock: float, settled: bool, fred: bool, flash_t: float = 0.0, ready_t: float = 0.0
) -> void:
	var p: Vector2 = ap.round()
	var rdy: bool = ready and not settled
	draw_pedestal_base(ci, p, rdy, cd_frac, boss_pulse, _p("ice"), _p("sky"), clock, settled, fred)
	# Stepped sea-stone bollard (14x4)
	ci.draw_rect(Rect2(p + Vector2(-7.0, -1.0), Vector2(14.0, 2.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-6.0, -3.0), Vector2(12.0, 2.0)), _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-5.0, -4.0), Vector2(10.0, 1.0)), _p("stone") if rdy else _p("mauve"))
	# Narrow dark iron post (2x8) + brass collar
	ci.draw_rect(Rect2(p + Vector2(-1.0, -11.0), Vector2(2.0, 7.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-1.0, -10.0), Vector2(1.0, 6.0)), _p("mauve") if rdy else _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-3.0, -10.0), Vector2(6.0, 1.0)), _p("apricot") if rdy else _p("dusk"))
	# Caged octagonal Fresnel prism lantern head + mini brass finial
	var cage_c: Color = _p("gold") if rdy else (_p("dusk") if settled else _p("mauve"))
	var glass_a: Color = _p("sky") if rdy else (_p("deep") if settled else _p("blue"))
	var glass_b: Color = _p("ice") if rdy else (_p("blue") if settled else _p("deep"))
	var core_c: Color = _p("cream") if (rdy or flash_t > 0.25) else (_p("deep") if settled else _p("sky"))
	ci.draw_rect(Rect2(p + Vector2(-4.0, -15.0), Vector2(8.0, 5.0)), cage_c)
	ci.draw_rect(Rect2(p + Vector2(-3.0, -14.0), Vector2(6.0, 3.0)), glass_a)
	ci.draw_rect(Rect2(p + Vector2(-2.0, -14.0), Vector2(4.0, 3.0)), glass_b)
	ci.draw_rect(Rect2(p + Vector2(-1.0, -13.0), Vector2(2.0, 1.0)), core_c)
	ci.draw_rect(Rect2(p + Vector2(-3.0, -16.0), Vector2(6.0, 1.0)), _p("apricot") if rdy else _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-1.0, -17.0), Vector2(2.0, 1.0)), _p("gold") if rdy else _p("mauve"))
	# Rotating +/-8px lighthouse glint beams when ready
	if rdy:
		var pulse: float = 0.0 if fred else sin(clock * (5.2 if boss_pulse else 2.8) + p.x * 0.04)
		var sweep: float = 0.0 if fred else roundf(sin(clock * (4.0 if boss_pulse else 2.2) + p.x * 0.02) * 1.6)
		var span: float = 8.0 if (boss_pulse or pulse > 0.0) else 6.0
		var ba: float = clampf((0.78 if boss_pulse else 0.52) + pulse * 0.16, 0.35, 0.92)
		var hc: Vector2 = p + Vector2(0.0, -13.0)
		for sx: float in [-1.0, 1.0]:
			var tip: Vector2 = (hc + Vector2(sx * span, sweep * sx)).round()
			ci.draw_rect(Rect2(hc + Vector2(sx * 4.0, 0.0), Vector2(2.0 if sx > 0.0 else -2.0, 2.0)).abs(), Color(_p("cream"), ba))
			ci.draw_rect(Rect2(tip + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), Color(_p("ice"), ba * 0.85))
			ci.draw_line(hc + Vector2(sx * 4.0, 0.0), tip, Color(_p("ice"), ba * 0.72), 1.2)
	_draw_pedestal_fx(ci, p, Vector2(0.0, -13.0), flash_t, 0.52, 105.0, ready_t, _p("ice"), _p("sky"), _p("cream"), settled, fred)


# Island 3 — Amber Sap-Resin Lantern Stump (oak_r6)
static func draw_sap_stump(
	ci: CanvasItem, ap: Vector2, ready: bool, cd_frac: float, boss_pulse: bool,
	clock: float, settled: bool, fred: bool, flash_t: float = 0.0, ready_t: float = 0.0
) -> void:
	var p: Vector2 = ap.round()
	var rdy: bool = ready and not settled
	draw_pedestal_base(ci, p, rdy, cd_frac, boss_pulse, _p("lime"), _p("gold"), clock, settled, fred)
	# Gnarled hollow oak root-stump (14x5 roots, 8x7 trunk)
	ci.draw_rect(Rect2(p + Vector2(-7.0, -1.0), Vector2(14.0, 2.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-6.0, -3.0), Vector2(12.0, 3.0)), _p("pine"))
	ci.draw_rect(Rect2(p + Vector2(-7.0, -2.0), Vector2(2.0, 2.0)), _p("pine"))
	ci.draw_rect(Rect2(p + Vector2(5.0, -2.0), Vector2(2.0, 2.0)), _p("pine"))
	ci.draw_rect(Rect2(p + Vector2(-4.0, -10.0), Vector2(8.0, 7.0)), _p("pine"))
	ci.draw_rect(Rect2(p + Vector2(-3.0, -9.0), Vector2(2.0, 6.0)), _p("dusk") if settled else _p("teal"))
	ci.draw_rect(Rect2(p + Vector2(2.0, -9.0), Vector2(1.0, 5.0)), _p("dusk") if settled else _p("teal"))
	ci.draw_rect(Rect2(p + Vector2(-2.0, -9.0), Vector2(4.0, 4.0)), _p("void"))
	# Bulbous amber resin-sap orb cradled in the hollow
	var orb_out: Color = _p("apricot") if rdy else (_p("dusk") if settled else _p("mauve"))
	var orb_mid: Color = _p("gold") if rdy else (_p("mauve") if settled else _p("apricot"))
	var orb_core: Color = _p("cream") if (rdy or flash_t > 0.25) else (_p("mauve") if settled else _p("gold"))
	ci.draw_rect(Rect2(p + Vector2(-3.0, -13.0), Vector2(6.0, 5.0)), orb_out)
	ci.draw_rect(Rect2(p + Vector2(-2.0, -14.0), Vector2(4.0, 6.0)), orb_out)
	ci.draw_rect(Rect2(p + Vector2(-2.0, -13.0), Vector2(4.0, 4.0)), orb_mid)
	ci.draw_rect(Rect2(p + Vector2(-1.0, -12.0), Vector2(2.0, 2.0)), orb_core)
	# Two tiny jade/lime sprout leaves crowning the stump
	var leaf_a: Color = _p("jade")
	var leaf_b: Color = _p("jade") if settled else _p("lime")
	ci.draw_rect(Rect2(p + Vector2(-4.0, -15.0), Vector2(2.0, 2.0)), leaf_a)
	ci.draw_rect(Rect2(p + Vector2(-4.0, -16.0), Vector2(1.0, 1.0)), leaf_b)
	ci.draw_rect(Rect2(p + Vector2(2.0, -16.0), Vector2(2.0, 2.0)), leaf_a)
	ci.draw_rect(Rect2(p + Vector2(3.0, -17.0), Vector2(1.0, 1.0)), leaf_b)
	# Rising 1px lime/gold pollen motes + warm core pulse when ready
	if rdy:
		var spd: float = 1.35 if boss_pulse else 0.72
		for mi: int in range(3):
			var u: float = (0.35 + float(mi) * 0.28) if fred else fposmod(clock * spd + float(mi) * 0.33 + p.x * 0.01, 1.0)
			var mx: float = roundf(p.x + sin((0.0 if fred else clock * 2.6) + float(mi) * 2.1) * 4.5)
			var my: float = roundf(p.y - 12.0 - u * 8.0)
			var ma: float = sin(u * PI) * (0.72 if fred else 0.92)
			ci.draw_rect(Rect2(mx, my, 1.0, 1.0), Color(_p("gold") if mi % 2 == 0 else _p("lime"), ma))
		if boss_pulse and not fred:
			ci.draw_arc(p + Vector2(0.0, -11.0), roundf(6.0 + sin(clock * 6.0) * 1.2), 0.0, TAU, 14, Color(_p("gold"), 0.58), 1.1)
	_draw_pedestal_fx(ci, p, Vector2(0.0, -11.0), flash_t, 0.52, 110.0, ready_t, _p("lime"), _p("gold"), _p("cream"), settled, fred)


# Island 4 — Stained-Glass Rose Wind Chime (conservatory_r6 + conservatory_r10 boss sanctum)
static func draw_rose_chime(
	ci: CanvasItem, ap: Vector2, ready: bool, cd_frac: float, boss_pulse: bool,
	clock: float, settled: bool, fred: bool, flash_t: float = 0.0, ready_t: float = 0.0,
	sunlit_clear: bool = false, shock_r: float = 115.0
) -> void:
	var p: Vector2 = ap.round()
	var rdy: bool = ready and not settled
	draw_pedestal_base(ci, p, rdy, cd_frac, boss_pulse, _p("rose"), _p("ice"), clock, settled, fred)
	# Mossy marble conservatory plinth (14x4)
	ci.draw_rect(Rect2(p + Vector2(-7.0, -1.0), Vector2(14.0, 2.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-6.0, -3.0), Vector2(12.0, 2.0)), _p("teal"))
	ci.draw_rect(Rect2(p + Vector2(-5.0, -4.0), Vector2(10.0, 1.0)), _p("stone") if (rdy or sunlit_clear) else _p("mauve"))
	ci.draw_rect(Rect2(p + Vector2(-5.0, -3.0), Vector2(3.0, 1.0)), _p("jade"))
	# Arched iron hook (10x12)
	ci.draw_rect(Rect2(p + Vector2(3.0, -15.0), Vector2(2.0, 11.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(3.0, -14.0), Vector2(1.0, 10.0)), _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-4.0, -17.0), Vector2(8.0, 2.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-3.0, -16.0), Vector2(6.0, 1.0)), _p("mauve") if rdy else _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-4.0, -15.0), Vector2(2.0, 2.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-1.0, -15.0), Vector2(2.0, 2.0)), _p("dusk"))
	# Hanging stained-glass diamond rose prism + 3 dangling chime rods
	var sway: float = 0.0
	if not fred and not settled:
		if flash_t > 0.0:
			sway = roundf(sin(clock * 24.0) * 2.2 * clampf(flash_t / 0.55, 0.0, 1.0))
		elif rdy:
			sway = roundf(sin(clock * (4.4 if boss_pulse else 2.5) + p.x * 0.03) * 1.0)
	var pc: Vector2 = (p + Vector2(sway, -11.0)).round()
	var lead_c: Color = _p("dusk") if settled else _p("void")
	var rim_c: Color = _p("wine") if rdy else (_p("rose") if (settled and sunlit_clear) else (_p("dusk") if settled else _p("plum")))
	var mid_c: Color = _p("rose") if rdy else (_p("gold") if (settled and sunlit_clear) else (_p("plum") if settled else _p("wine")))
	var ctr_c: Color = _p("cream") if (rdy or flash_t > 0.25) else (_p("ice") if (settled and sunlit_clear) else _p("mauve"))
	ci.draw_rect(Rect2(pc + Vector2(-3.0, -1.0), Vector2(6.0, 2.0)), lead_c)
	ci.draw_rect(Rect2(pc + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), rim_c)
	ci.draw_rect(Rect2(pc + Vector2(-1.0, -3.0), Vector2(2.0, 6.0)), rim_c)
	ci.draw_rect(Rect2(pc + Vector2(-1.0, -2.0), Vector2(2.0, 4.0)), mid_c)
	ci.draw_rect(Rect2(pc + Vector2(-2.0, -1.0), Vector2(4.0, 2.0)), mid_c)
	ci.draw_rect(Rect2(pc + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), ctr_c)
	var rod_a: Color = _p("ice") if (rdy or (settled and sunlit_clear)) else _p("mauve")
	var rod_b: Color = _p("sky") if rdy else (_p("gold") if (settled and sunlit_clear) else _p("dusk"))
	ci.draw_rect(Rect2(pc + Vector2(-3.0, 2.0), Vector2(1.0, 3.0)), rod_a)
	ci.draw_rect(Rect2(pc + Vector2(0.0, 3.0), Vector2(1.0, 4.0)), rod_b)
	ci.draw_rect(Rect2(pc + Vector2(2.0, 2.0), Vector2(1.0, 3.0)), rod_a)
	# Orbiting ice/rose wind petals when ready
	if rdy:
		var rot: float = 0.0 if fred else clock * (3.2 if boss_pulse else 1.8)
		for k: int in range(2):
			var ang: float = rot + float(k) * PI + p.x * 0.02
			var pt: Vector2 = (p + Vector2(cos(ang) * 10.0, -9.0 + sin(ang) * 4.5)).round()
			ci.draw_rect(Rect2(pt, Vector2(2.0, 1.0)), Color(_p("rose") if k == 0 else _p("ice"), 0.85))
	_draw_pedestal_fx(ci, p, Vector2(0.0, -11.0), flash_t, 0.55, shock_r, ready_t, _p("rose"), _p("ice"), _p("cream"), settled, fred)


# Island 5 — Brass Astrolabe Dial Pedestal (orrery_r6)
static func draw_astrolabe_pedestal(
	ci: CanvasItem, ap: Vector2, ready: bool, cd_frac: float, boss_pulse: bool,
	clock: float, settled: bool, fred: bool, flash_t: float = 0.0, ready_t: float = 0.0
) -> void:
	var p: Vector2 = ap.round()
	var rdy: bool = ready and not settled
	draw_pedestal_base(ci, p, rdy, cd_frac, boss_pulse, _p("gold"), _p("sky"), clock, settled, fred)
	# Deep-blue slate pillar (12x6 base + 6x6 column)
	ci.draw_rect(Rect2(p + Vector2(-6.0, -2.0), Vector2(12.0, 3.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-5.0, -4.0), Vector2(10.0, 3.0)), _p("deep"))
	ci.draw_rect(Rect2(p + Vector2(-4.0, -5.0), Vector2(8.0, 1.0)), _p("blue") if rdy else _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-3.0, -10.0), Vector2(6.0, 5.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-2.0, -10.0), Vector2(4.0, 5.0)), _p("deep"))
	ci.draw_rect(Rect2(p + Vector2(-1.0, -9.0), Vector2(2.0, 4.0)), _p("blue") if rdy else _p("dusk"))
	# Twin interlocking brass astrolabe rings (10x10) around hovering star-crystal
	var ac: Vector2 = (p + Vector2(0.0, -13.0)).round()
	var ring_a: Color = _p("apricot") if rdy else (_p("dusk") if settled else _p("mauve"))
	var ring_b: Color = _p("gold") if rdy else _p("mauve")
	ci.draw_arc(ac, 4.5, 0.0, TAU, 16, ring_a, 1.3)
	ci.draw_arc(ac, 3.0, 0.4, TAU - 0.4, 14, ring_b, 1.0)
	var step_rot: float = 0.0 if (fred or not rdy) else floorf(clock * (5.0 if boss_pulse else 2.4)) * (PI * 0.25)
	for k: int in range(4):
		var a: float = step_rot + float(k) * (PI * 0.5)
		var gp: Vector2 = (ac + Vector2.from_angle(a) * 5.0).round()
		ci.draw_rect(Rect2(gp, Vector2.ONE), ring_b)
	# Hovering sky/ice/cream star-crystal
	var cr_out: Color = _p("sky") if rdy else (_p("deep") if settled else _p("blue"))
	var cr_mid: Color = _p("ice") if rdy else (_p("deep") if settled else _p("sky"))
	ci.draw_rect(Rect2(ac + Vector2(-2.0, 0.0), Vector2(4.0, 1.0)), cr_out)
	ci.draw_rect(Rect2(ac + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), cr_out)
	ci.draw_rect(Rect2(ac + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), cr_mid)
	if rdy or flash_t > 0.25:
		ci.draw_rect(Rect2(ac, Vector2.ONE), _p("cream"))
	if rdy:
		var ta: float = 0.55 if fred else (0.48 + 0.30 * absf(sin(clock * (4.6 if boss_pulse else 2.6))))
		for td: Vector2 in [Vector2(-7.0, 0.0), Vector2(7.0, 0.0), Vector2(0.0, -6.0)]:
			ci.draw_rect(Rect2((ac + td).round(), Vector2(2.0 if td.y == 0.0 else 1.0, 1.0 if td.y == 0.0 else 2.0)), Color(_p("sky"), ta))
	_draw_pedestal_fx(ci, p, Vector2(0.0, -13.0), flash_t, 0.52, 120.0, ready_t, _p("gold"), _p("sky"), _p("cream"), settled, fred)


# Island 6 — Foundry Bellows Anvil Brazier (kiln_r6)
static func draw_forge_brazier(
	ci: CanvasItem, ap: Vector2, ready: bool, cd_frac: float, boss_pulse: bool,
	clock: float, settled: bool, fred: bool, flash_t: float = 0.0, ready_t: float = 0.0
) -> void:
	var p: Vector2 = ap.round()
	var rdy: bool = ready and not settled
	draw_pedestal_base(ci, p, rdy, cd_frac, boss_pulse, _p("coral"), _p("gold"), clock, settled, fred)
	# Chunky volcanic basalt forge-pedestal (16x5 base)
	ci.draw_rect(Rect2(p + Vector2(-8.0, -2.0), Vector2(16.0, 3.0)), _p("void"))
	ci.draw_rect(Rect2(p + Vector2(-7.0, -4.0), Vector2(14.0, 3.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-6.0, -5.0), Vector2(12.0, 2.0)), _p("dusk"))
	# Slotted ember hearth (10x6)
	ci.draw_rect(Rect2(p + Vector2(-5.0, -11.0), Vector2(10.0, 6.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-4.0, -11.0), Vector2(8.0, 6.0)), _p("dusk"))
	if settled:
		ci.draw_rect(Rect2(p + Vector2(-3.0, -9.0), Vector2(6.0, 3.0)), _p("night"))
		ci.draw_rect(Rect2(p + Vector2(-2.0, -8.0), Vector2(1.0, 1.0)), _p("wine"))
		ci.draw_rect(Rect2(p + Vector2(1.0, -7.0), Vector2(1.0, 1.0)), _p("wine"))
	else:
		var hot: bool = rdy and (boss_pulse or (not fred and sin(clock * 8.0 + p.x) > 0.0))
		ci.draw_rect(Rect2(p + Vector2(-3.0, -10.0), Vector2(6.0, 1.0)), _p("gold") if hot else (_p("apricot") if rdy else _p("wine")))
		ci.draw_rect(Rect2(p + Vector2(-3.0, -8.0), Vector2(6.0, 1.0)), _p("apricot") if rdy else _p("wine"))
		ci.draw_rect(Rect2(p + Vector2(-3.0, -6.0), Vector2(6.0, 1.0)), _p("coral") if rdy else _p("plum"))
	# Notched iron anvil lip (12x3)
	ci.draw_rect(Rect2(p + Vector2(-6.0, -14.0), Vector2(12.0, 3.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-7.0, -14.0), Vector2(2.0, 2.0)), _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(5.0, -14.0), Vector2(2.0, 2.0)), _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-6.0, -15.0), Vector2(12.0, 2.0)), _p("mauve") if rdy else _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-5.0, -15.0), Vector2(10.0, 1.0)), _p("stone") if rdy else _p("mauve"))
	# Flame crest + rising coral/gold sparks when ready
	if rdy:
		var fl_h: float = 2.0 if (fred or not boss_pulse) else (2.0 + roundf(absf(sin(clock * 11.0 + p.x))))
		ci.draw_rect(Rect2(p + Vector2(-3.0, -15.0 - fl_h), Vector2(6.0, fl_h)), _p("coral"))
		ci.draw_rect(Rect2(p + Vector2(-2.0, -15.0 - fl_h), Vector2(4.0, maxf(1.0, fl_h - 0.5))), _p("gold"))
		ci.draw_rect(Rect2(p + Vector2(-1.0, -16.0), Vector2(2.0, 1.0)), _p("cream"))
		var spd: float = 1.6 if boss_pulse else 0.95
		for si: int in range(3):
			var u: float = (0.3 + float(si) * 0.28) if fred else fposmod(clock * spd + float(si) * 0.33 + p.x * 0.02, 1.0)
			var sx: float = roundf(p.x + sin((0.0 if fred else clock * 4.0) + float(si) * 2.2) * 4.5)
			var sy: float = roundf(p.y - 15.0 - u * 7.0)
			ci.draw_rect(Rect2(sx, sy, 1.0, 1.0), Color(_p("gold") if si % 2 == 0 else _p("coral"), sin(u * PI) * 0.9))
	_draw_pedestal_fx(ci, p, Vector2(0.0, -11.0), flash_t, 0.52, 96.0, ready_t, _p("coral"), _p("gold"), _p("cream"), settled, fred)


# Island 7 — Silver Moon-Mirror Pedestal (spire_r6)
static func draw_moon_mirror(
	ci: CanvasItem, ap: Vector2, ready: bool, cd_frac: float, boss_pulse: bool,
	clock: float, settled: bool, fred: bool, flash_t: float = 0.0, ready_t: float = 0.0
) -> void:
	var p: Vector2 = ap.round()
	var rdy: bool = ready and not settled
	draw_pedestal_base(ci, p, rdy, cd_frac, boss_pulse, _p("ice"), _p("sky"), clock, settled, fred)
	# Slender faceted glass column (12x4 base + 4x8 shaft)
	ci.draw_rect(Rect2(p + Vector2(-6.0, -1.0), Vector2(12.0, 2.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-5.0, -3.0), Vector2(10.0, 2.0)), _p("dusk") if settled else _p("deep"))
	ci.draw_rect(Rect2(p + Vector2(-4.0, -4.0), Vector2(8.0, 1.0)), _p("sky") if rdy else _p("blue"))
	ci.draw_rect(Rect2(p + Vector2(-2.0, -11.0), Vector2(4.0, 7.0)), _p("dusk") if settled else _p("deep"))
	ci.draw_rect(Rect2(p + Vector2(-2.0, -11.0), Vector2(1.0, 7.0)), _p("blue"))
	ci.draw_rect(Rect2(p + Vector2(1.0, -11.0), Vector2(1.0, 6.0)), _p("sky") if rdy else _p("blue"))
	# Tilted silver crescent mirror basin (10x6)
	var mc: Vector2 = (p + Vector2(0.0, -13.0)).round()
	ci.draw_rect(Rect2(mc + Vector2(-5.0, 0.0), Vector2(10.0, 2.0)), _p("blue") if not settled else _p("dusk"))
	ci.draw_arc(mc + Vector2(0.0, -1.0), 5.0, 0.12, PI - 0.12, 12, _p("sky") if rdy else (_p("stone") if settled else _p("blue")), 1.6)
	ci.draw_arc(mc + Vector2(0.0, -1.0), 3.6, 0.25, PI - 0.25, 10, _p("ice") if rdy else _p("blue"), 1.1)
	if rdy:
		ci.draw_rect(Rect2(mc + Vector2(-3.0, -1.0), Vector2(2.0, 1.0)), _p("cream"))
	# Suspended moon-drop crystal above basin
	var bob: float = 0.0 if (fred or not rdy) else roundf(sin(clock * (4.8 if boss_pulse else 2.6) + p.x * 0.03))
	var dc: Vector2 = (p + Vector2(0.0, -16.0 + bob)).round()
	ci.draw_rect(Rect2(dc + Vector2(-1.0, -1.0), Vector2(2.0, 3.0)), _p("ice") if rdy else _p("blue"))
	if rdy or flash_t > 0.25:
		ci.draw_rect(Rect2(dc, Vector2.ONE), _p("cream"))
	# Shimmering vertical ice reflection ticks when ready
	if rdy:
		var ra: float = 0.62 if fred else clampf(0.45 + 0.35 * absf(sin(clock * (5.2 if boss_pulse else 2.8) + p.x)), 0.3, 0.9)
		for sx: float in [-6.0, 6.0]:
			ci.draw_rect(Rect2(mc + Vector2(sx, -3.0), Vector2(1.0, 4.0)), Color(_p("ice"), ra))
			if boss_pulse:
				ci.draw_rect(Rect2(mc + Vector2(sx * 1.35, -2.0), Vector2(1.0, 2.0)), Color(_p("cream"), ra * 0.85))
	_draw_pedestal_fx(ci, p, Vector2(0.0, -13.0), flash_t, 0.52, 110.0, ready_t, _p("ice"), _p("sky"), _p("cream"), settled, fred)


# Island 8 — Sunken Cathedral Chime Altar (sanctum_r4)
static func draw_cathedral_altar(
	ci: CanvasItem, ap: Vector2, ready: bool, cd_frac: float, boss_pulse: bool,
	clock: float, settled: bool, fred: bool, flash_t: float = 0.0, ready_t: float = 0.0
) -> void:
	var p: Vector2 = ap.round()
	var rdy: bool = ready and not settled
	draw_pedestal_base(ci, p, rdy, cd_frac, boss_pulse, _p("gold"), _p("rose"), clock, settled, fred)
	# Cracked purple-stone stepped reliquary altar (16x5)
	ci.draw_rect(Rect2(p + Vector2(-8.0, -1.0), Vector2(16.0, 2.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-7.0, -3.0), Vector2(14.0, 2.0)), _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-6.0, -5.0), Vector2(12.0, 2.0)), _p("dusk") if settled else _p("plum"))
	ci.draw_rect(Rect2(p + Vector2(-5.0, -5.0), Vector2(10.0, 1.0)), _p("rose") if rdy else _p("mauve"))
	ci.draw_rect(Rect2(p + Vector2(-2.0, -4.0), Vector2(1.0, 2.0)), _p("void"))
	# Twin gothic spires + arch framing the eclipse bell
	ci.draw_rect(Rect2(p + Vector2(-6.0, -15.0), Vector2(2.0, 10.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(4.0, -15.0), Vector2(2.0, 10.0)), _p("night"))
	ci.draw_rect(Rect2(p + Vector2(-5.0, -14.0), Vector2(1.0, 9.0)), _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(4.0, -14.0), Vector2(1.0, 9.0)), _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-6.0, -17.0), Vector2(1.0, 2.0)), _p("rose") if rdy else _p("mauve"))
	ci.draw_rect(Rect2(p + Vector2(5.0, -17.0), Vector2(1.0, 2.0)), _p("rose") if rdy else _p("mauve"))
	ci.draw_rect(Rect2(p + Vector2(-5.0, -15.0), Vector2(10.0, 2.0)), _p("dusk"))
	ci.draw_rect(Rect2(p + Vector2(-4.0, -15.0), Vector2(8.0, 1.0)), _p("gold") if rdy else _p("mauve"))
	# Hanging golden-rose eclipse bell
	var sway: float = 0.0
	if not fred and not settled:
		if flash_t > 0.0:
			sway = roundf(sin(clock * 26.0) * 2.4 * clampf(flash_t / 0.52, 0.0, 1.0))
		elif rdy and boss_pulse:
			sway = roundf(sin(clock * 4.4 + p.x * 0.02) * 1.0)
	var bc: Vector2 = (p + Vector2(sway, -10.0)).round()
	var b_sh: Color = _p("wine") if rdy else _p("plum")
	var b_mid: Color = _p("rose") if rdy else (_p("plum") if settled else _p("mauve"))
	var b_rim: Color = _p("cream") if flash_t > 0.32 else (_p("gold") if rdy else (_p("stone") if settled else _p("mauve")))
	ci.draw_rect(Rect2(bc + Vector2(-1.0, -4.0), Vector2(2.0, 2.0)), _p("gold") if rdy else _p("mauve"))
	ci.draw_rect(Rect2(bc + Vector2(-2.0, -2.0), Vector2(4.0, 3.0)), b_sh)
	ci.draw_rect(Rect2(bc + Vector2(-1.0, -2.0), Vector2(2.0, 3.0)), b_mid)
	ci.draw_rect(Rect2(bc + Vector2(-3.0, 1.0), Vector2(6.0, 2.0)), b_rim)
	ci.draw_rect(Rect2(bc + Vector2(-1.0, 3.0), Vector2(2.0, 1.0)), _p("cream") if (rdy or flash_t > 0.25) else _p("mauve"))
	# Swaying eclipse chime arcs echoing Island 1's belfry motif
	if rdy:
		var pulse: float = 0.0 if fred else sin(clock * (4.8 if boss_pulse else 2.8) + p.x * 0.03)
		var wa: float = (0.72 if boss_pulse else 0.44) * (0.75 if fred else (0.85 + 0.15 * pulse))
		var wr1: float = roundf(8.5 + (0.0 if fred else fposmod(clock * 4.4, 3.0)))
		for side_a: float in [0.0, PI]:
			ci.draw_arc(bc, wr1, side_a - 0.50, side_a + 0.50, 6, Color(_p("gold") if boss_pulse else _p("rose"), wa), 1.2)
			if boss_pulse:
				var wr2: float = roundf(12.0 + (0.0 if fred else fposmod(clock * 4.4 + 1.5, 3.5)))
				ci.draw_arc(bc, wr2, side_a - 0.42, side_a + 0.42, 6, Color(_p("rose"), wa * 0.72), 1.0)
	_draw_pedestal_fx(ci, p, Vector2(0.0, -10.0), flash_t, 0.52, 118.0, ready_t, _p("gold"), _p("rose"), _p("cream"), settled, fred)
