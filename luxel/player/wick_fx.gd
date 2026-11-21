class_name LxWickFx
extends RefCounted
## Particle pools, sprite loading, and Last Light 20-colour rendering for LxWick and his 8-move kit.

var afterimages: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var sprite_tex: Texture2D = null
var sprite_frame_size: Vector2i = Vector2i(24, 24)


func clear() -> void:
	afterimages.clear()
	rings.clear()
	sparks.clear()


func spawn_afterimage(at_pos: Vector2, col: Color) -> void:
	afterimages.append({"pos": at_pos, "age": 0.0, "life": 0.20, "col": col})


func spawn_ring(at_pos: Vector2, r0: float, r1: float, life: float, col: Color, width: float = 1.0) -> void:
	rings.append({"pos": at_pos, "r0": r0, "r1": r1, "age": 0.0, "life": maxf(0.02, life), "col": col, "w": width})


func spawn_sparks(at_pos: Vector2, base_dir: Vector2, count: int, col: Color, min_spd: float, max_spd: float, life: float) -> void:
	var dn: Vector2 = base_dir.normalized() if base_dir.length_squared() > 0.0001 else Vector2.RIGHT
	for _i: int in range(count):
		sparks.append({
			"pos": at_pos,
			"vel": dn.rotated(randf_range(-0.65, 0.65)) * randf_range(min_spd, max_spd),
			"age": 0.0,
			"life": life,
			"col": col,
		})


func age(dt: float) -> void:
	for arr: Array[Dictionary] in [afterimages, rings]:
		for i: int in range(arr.size() - 1, -1, -1):
			arr[i]["age"] = float(arr[i]["age"]) + dt
			if float(arr[i]["age"]) >= float(arr[i]["life"]):
				arr.remove_at(i)
	for i: int in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["age"] = float(s["age"]) + dt
		var vel: Vector2 = s["vel"] as Vector2
		s["pos"] = (s["pos"] as Vector2) + vel * dt
		s["vel"] = vel * pow(0.08, dt)
		if float(s["age"]) >= float(s["life"]):
			sparks.remove_at(i)


func try_load_sprite() -> void:
	if sprite_tex != null:
		return
	for path: String in ["res://luxel/art/wick/wick.png", "res://luxel/art/wick/sheet.png"]:
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is Texture2D:
				sprite_tex = res as Texture2D
				return


func draw(wick: LxWick, walk_phase: float, clock_t: float) -> void:
	var off: Vector2 = -wick.global_position
	if wick.move_lens != null:
		wick.move_lens.draw_fx(wick, off)
	if wick.move_sunflare != null:
		wick.move_sunflare.draw_fx(wick, off)

	for a: Dictionary in afterimages:
		var t: float = 1.0 - clampf(float(a["age"]) / float(a["life"]), 0.0, 1.0)
		wick.draw_rect(
			Rect2(((a["pos"] as Vector2) + off).round() + Vector2(-4.0, -10.0), Vector2(8.0, 10.0)),
			Color(a["col"] as Color, t * 0.55)
		)
	for r: Dictionary in rings:
		var t: float = clampf(float(r["age"]) / float(r["life"]), 0.0, 1.0)
		wick.draw_arc(
			((r["pos"] as Vector2) + off).round(),
			lerpf(float(r["r0"]), float(r["r1"]), t),
			0.0, TAU, 20, Color(r["col"] as Color, 1.0 - t), float(r["w"])
		)
	for s: Dictionary in sparks:
		wick.draw_rect(Rect2(((s["pos"] as Vector2) + off).round(), Vector2(1.0, 1.0)), s["col"] as Color)
	for b_var: Variant in wick.bolts:
		var b: LxMoveBolt.Bolt = b_var as LxMoveBolt.Bolt
		if b != null:
			var bp: Vector2 = (b.pos + off).round()
			wick.draw_line((bp - b.dir * 5.0).round(), bp, LxWick.PAL_ICE if b.is_prism else LxWick.PAL_GOLD, 2.0)
			wick.draw_rect(Rect2(bp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxWick.PAL_CREAM)

	var flash_red: bool = Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))
	var alpha: float = 0.40 if (wick.mercy_t > 0.0 and not flash_red and (int(wick.mercy_t * 14.0) % 2 == 0)) else 1.0
	var glide_lift: float = -3.0 if wick.is_gliding() else 0.0
	var hop_y: float = -roundf(absf(sin(walk_phase)) * 2.0)
	var base: Vector2 = (-wick.facing * clampf(wick.recoil_vis * 1.5, 0.0, 1.5)).round() + Vector2(0.0, hop_y + glide_lift)
	var lan_in_hand: bool = wick.lantern == null or wick.lantern.is_in_hand()
	var hand_pos: Vector2 = (base + wick.facing * 6.0 + Vector2(0.0, -6.0)).round()

	wick.draw_rect(Rect2(Vector2(-4.0, -1.0), Vector2(8.0, 3.0)), Color(LxWick.PAL_VOID, 0.45))
	if lan_in_hand:
		var pulse: float = 0.92 + 0.08 * sin(clock_t * 7.0)
		wick.draw_circle(hand_pos, 13.0 * pulse, Color(LxWick.PAL_GOLD, 0.10))
		wick.draw_circle(hand_pos, 6.5 * pulse, Color(LxWick.PAL_APRICOT, 0.15))

	var hit_white: bool = wick.hurt_flash > 0.55 and not flash_red
	if sprite_tex != null:
		var sz := Vector2(sprite_frame_size)
		var mod: Color = Color(LxWick.PAL_CREAM, alpha) if hit_white else Color(1.0, 1.0, 1.0, alpha)
		wick.draw_texture_rect_region(sprite_tex, Rect2(base + Vector2(-sz.x * 0.5, -sz.y), sz), Rect2(Vector2.ZERO, sz), mod)
	else:
		_draw_fallback_moth(wick, base, hit_white, alpha, lan_in_hand, hand_pos)

	if wick.move_beam != null:
		wick.move_beam.draw_fx(wick, off, hand_pos)

	wick.draw_rect(Rect2((wick.facing * 12.0 + Vector2(0.0, -6.0)).round() - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), LxWick.PAL_GOLD)
	if wick.muzzle_t > 0.0:
		wick.draw_circle(hand_pos, 3.5, LxWick.PAL_CREAM)


func _draw_fallback_moth(wick: LxWick, base: Vector2, hit_white: bool, alpha: float, lan_in_hand: bool, hand_pos: Vector2) -> void:
	var c_out := Color(LxWick.PAL_NIGHT, alpha)
	var c_cloak := Color(
		LxWick.PAL_CREAM if hit_white else (
			LxWick.PAL_ICE if wick.is_dashing() else (
				LxWick.PAL_SKY if wick.is_gliding() else (
					LxWick.PAL_GOLD if wick.is_zipping() else LxWick.PAL_DUSK
				)
			)
		), alpha
	)
	var c_wing := Color(LxWick.PAL_CREAM if hit_white else (LxWick.PAL_ICE if wick.is_gliding() else LxWick.PAL_PLUM), alpha)
	var wing_w: float = 14.0 if wick.is_gliding() else 10.0
	wick.draw_rect(Rect2(base + Vector2(-wing_w * 0.5, -10.0), Vector2(wing_w, 6.0)), c_out)
	wick.draw_rect(Rect2(base + Vector2(-wing_w * 0.5 + 1.0, -9.0), Vector2(wing_w - 2.0, 4.0)), c_wing)
	wick.draw_rect(Rect2(base + Vector2(-4.0, -11.0), Vector2(8.0, 10.0)), c_out)
	wick.draw_rect(Rect2(base + Vector2(-3.0, -10.0), Vector2(6.0, 8.0)), c_cloak)
	wick.draw_rect(Rect2(base + Vector2(-3.0, -15.0), Vector2(6.0, 5.0)), c_out)
	wick.draw_rect(Rect2(base + Vector2(-2.0, -14.0), Vector2(4.0, 3.0)), Color(LxWick.PAL_CREAM, alpha))
	wick.draw_rect(Rect2(base + Vector2(-2.0, -17.0), Vector2(1.0, 2.0)), Color(LxWick.PAL_GOLD, alpha))
	wick.draw_rect(Rect2(base + Vector2(1.0, -17.0), Vector2(1.0, 2.0)), Color(LxWick.PAL_GOLD, alpha))
	if lan_in_hand:
		wick.draw_rect(Rect2(hand_pos + Vector2(-2.0, -2.0), Vector2(4.0, 5.0)), c_out)
		wick.draw_rect(Rect2(hand_pos + Vector2(-1.0, -1.0), Vector2(2.0, 3.0)), Color(LxWick.PAL_GOLD, alpha))
		wick.draw_rect(Rect2(hand_pos + Vector2(-1.0, 0.0), Vector2(2.0, 1.0)), Color(LxWick.PAL_CREAM, alpha))
