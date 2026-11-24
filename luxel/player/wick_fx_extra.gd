class_name LxWickFxExtra
extends RefCounted
## Extra rendering for E0-2 features & Feel #10:
## - Honest 60 px field curvature preview dots (zero aim assist)
## - Bolt temper reticle cues & launch arc trail
## - Punchier 4x2 glowing bolt renderer with crisp night halo & cream nose (Feel #10)
## Kept separate from wick_fx.gd so wick_fx.gd stays <= 600 lines.


static func draw_overlays(wick: LxWick, off: Vector2, _clock_t: float) -> void:
	if wick.dead:
		return
	var flash_red: bool = LxHudFx.flash_reduced()
	# 1. Honest 60 px dotted trajectory preview when aiming inside/through a spatial field
	if LxFields.has_fields() and wick.has_lantern() and not wick.is_grabbing() and not wick.is_carrying():
		var lan_in_hand: bool = wick.lantern == null or wick.lantern.is_in_hand()
		if lan_in_hand and wick.facing.length_squared() > 0.0001:
			var spd: float = float(Lx.get_move_data("bolt").get("speed", 330.0))
			if wick.temper == "lance":
				spd *= 0.68
			elif wick.temper == "skip":
				spd *= 1.08
			var start_w: Vector2 = wick.global_position + wick.facing.normalized() * 6.0
			var res: Dictionary = LxFields.sample_curve(start_w, wick.facing, spd, "bolt", 60.0, 5.0, wick._world_ctx)
			if bool(res.get("bent", false)):
				var pts: PackedVector2Array = res.get("points", PackedVector2Array()) as PackedVector2Array
				var alpha_sc: float = 0.72 if flash_red else 0.92
				for idx: int in range(1, pts.size()):
					var lp: Vector2 = (pts[idx] + off + Vector2(0.0, -5.0)).round()
					var col: Color = LxWick.PAL_CREAM if (idx == pts.size() - 1) else (LxWick.PAL_ICE if (idx % 2 == 0) else LxWick.PAL_SKY)
					var a: float = alpha_sc * (1.0 - float(idx) / float(pts.size() + 4))
					wick.draw_rect(Rect2(lp + Vector2(0.0, 1.0), Vector2.ONE), Color(LxWick.PAL_VOID, a * 0.7))
					wick.draw_rect(Rect2(lp, Vector2.ONE), Color(col, a))

	# 2. Temper indicator pips near aim reticle (scatter / lance / skip)
	if not wick.temper.is_empty() and wick.has_lantern() and not wick.is_grabbing():
		var aim: Vector2 = wick.facing.normalized() if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
		var perp := Vector2(-aim.y, aim.x)
		var pip: Vector2 = (aim * 12.0 + Vector2(0.0, -6.0)).round()
		match wick.temper:
			"scatter":
				for sgn: float in [-1.0, 1.0]:
					var sp: Vector2 = (pip + perp * (sgn * 3.0) - aim * 1.0).round()
					wick.draw_rect(Rect2(sp, Vector2.ONE), LxWick.PAL_APRICOT)
			"lance":
				wick.draw_line((pip + aim * 2.0).round(), (pip + aim * 5.0).round(), LxWick.PAL_CORAL, 1.0)
				wick.draw_rect(Rect2((pip + aim * 5.0).round(), Vector2.ONE), LxWick.PAL_CREAM)
			"skip":
				wick.draw_rect(Rect2((pip + aim * 2.0 + perp * 2.0).round(), Vector2.ONE), LxWick.PAL_GOLD)
				wick.draw_rect(Rect2((pip + aim * 3.0).round(), Vector2.ONE), LxWick.PAL_CREAM)
				wick.draw_rect(Rect2((pip + aim * 2.0 - perp * 2.0).round(), Vector2.ONE), LxWick.PAL_GOLD)

	# 3. Launch wind ring cue while Wick is airborne from bounce_bloom / cart jump
	if wick.is_launched():
		for k: int in range(8):
			var a: float = float(k) * (TAU / 8.0) + _clock_t * 3.0
			wick.draw_rect(Rect2((Vector2(0.0, -4.0) + Vector2(cos(a) * 7.0, sin(a) * 4.5)).round(), Vector2.ONE), Color(LxWick.PAL_ICE, 0.55 if flash_red else 0.78))


static func draw_bolts(wick: LxWick, off: Vector2) -> void:
	for b_var: Variant in wick.bolts:
		var b: LxMoveBolt.Bolt = b_var as LxMoveBolt.Bolt
		if b == null:
			continue
		var bdir: Vector2 = b.dir.normalized() if b.dir.length_squared() > 0.0001 else Vector2.RIGHT
		var perp := Vector2(-bdir.y, bdir.x)
		var bp: Vector2 = (b.pos + off).round()
		if b.is_split_shard:
			wick.draw_line((bp - bdir * 7.0).round(), bp, LxWick.PAL_SKY, 1.0)
			wick.draw_line((bp - bdir * 3.0).round(), bp, LxWick.PAL_ICE, 1.0)
			wick.draw_line((bp - perp * 2.0).round(), (bp + perp * 2.0).round(), LxWick.PAL_ICE, 1.0)
			wick.draw_line((bp - bdir * 2.0).round(), (bp + bdir * 2.0).round(), LxWick.PAL_ICE, 1.0)
			wick.draw_rect(Rect2(bp - Vector2.ONE, Vector2(2.0, 2.0)), LxWick.PAL_CREAM)
			wick.draw_rect(Rect2((bp + bdir).round(), Vector2.ONE), LxWick.PAL_CREAM)
			continue
		var has_bt: bool = not b.biome_tint.is_empty() and LxPalette.PAL.has(b.biome_tint)
		var bt_col: Color = (LxPalette.PAL[b.biome_tint] as Color) if has_bt else LxWick.PAL_GOLD
		var is_blue: bool = b.is_prism or b.light_color == LxHit.COLOR_BLUE
		var c_body: Color = LxWick.PAL_ICE if is_blue else (LxWick.PAL_CORAL if b.is_pierce else (bt_col if has_bt else (LxWick.PAL_CREAM if b.is_counter else LxWick.PAL_GOLD)))
		var c_tail: Color = LxWick.PAL_SKY if is_blue else (LxWick.PAL_APRICOT if b.is_pierce else (LxWick.PAL_SKY if b.biome_tint == "ice" else (LxWick.PAL_GOLD if (b.is_counter or has_bt) else LxWick.PAL_APRICOT)))
		var mid_end: Vector2 = (bp - bdir * (7.0 if (b.is_counter or b.is_pierce or has_bt or b.bounce_count >= 2) else 5.5)).round()
		var tail_end: Vector2 = (bp - bdir * (13.0 if (b.is_counter or b.is_pierce or has_bt or b.bounce_count >= 2) else 10.0)).round()
		# Crisp dark contrast halo so bolts read cleanly against pale floors (Feel #10)
		wick.draw_line(mid_end + Vector2(0.0, 1.0), bp + Vector2(0.0, 1.0), Color(LxWick.PAL_NIGHT, 0.72), 3.0)
		wick.draw_line(tail_end, mid_end, Color(c_tail, 0.88), 1.5)
		wick.draw_rect(Rect2(tail_end, Vector2.ONE), c_tail)
		wick.draw_line(mid_end, bp, c_body, 2.5)
		# Punchy 4x2 glowing core along bolt axis + bright 2x2 cream leading head
		var horiz: bool = absf(bdir.x) >= absf(bdir.y)
		var core_sz := Vector2(4.0, 2.0) if horiz else Vector2(2.0, 4.0)
		var core_pos: Vector2 = (bp - bdir * 1.0 - core_sz * 0.5).round()
		wick.draw_rect(Rect2(core_pos, core_sz), c_body)
		wick.draw_rect(Rect2(bp - Vector2.ONE, Vector2(2.0, 2.0)), LxWick.PAL_CREAM)
		wick.draw_rect(Rect2((bp + bdir).round(), Vector2.ONE), LxWick.PAL_CREAM)
		if is_blue:
			var arm: float = 4.0 if b.bounce_count >= 2 else 3.0
			wick.draw_line(bp + Vector2(-arm, 0.0), bp + Vector2(arm, 0.0), LxWick.PAL_ICE, 1.0)
			wick.draw_line(bp + Vector2(0.0, -arm), bp + Vector2(0.0, arm), LxWick.PAL_ICE, 1.0)
			if b.bounce_count >= 2:
				wick.draw_rect(Rect2(bp + Vector2(-2.0, -2.0), Vector2.ONE), LxWick.PAL_CREAM)
				wick.draw_rect(Rect2(bp + Vector2(2.0, 2.0), Vector2.ONE), LxWick.PAL_CREAM)
		elif b.is_pierce:
			wick.draw_line(bp + Vector2(-3.0, 0.0), bp + Vector2(3.0, 0.0), LxWick.PAL_CORAL, 1.0)
			wick.draw_line(bp + Vector2(0.0, -3.0), bp + Vector2(0.0, 3.0), LxWick.PAL_GOLD, 1.0)
		elif b.is_counter or has_bt:
			var star_c: Color = bt_col if has_bt else LxWick.PAL_GOLD
			wick.draw_line(bp + Vector2(-3.0, 0.0), bp + Vector2(3.0, 0.0), star_c, 1.0)
			wick.draw_line(bp + Vector2(0.0, -3.0), bp + Vector2(0.0, 3.0), star_c, 1.0)
