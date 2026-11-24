class_name LxWickFxExtra
extends RefCounted
## Extra rendering for E0-2 features: honest 60 px field curvature preview dots (zero aim assist),
## bolt temper reticle cues, launch arc trail, and carried-item aura.
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
		wick.draw_arc(Vector2(0.0, -4.0), 7.0, 0.0, TAU, 12, Color(LxWick.PAL_ICE, 0.55 if flash_red else 0.78), 1.0)
