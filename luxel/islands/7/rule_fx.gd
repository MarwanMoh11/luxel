class_name LxIsland7RuleFx
extends RefCounted
## Pixel-art draw helpers for Island 7 (Moon Shoals & Mirror Spire):
## - Two-Worlds HUD badge (Silver Full Moon vs Black Obsidian Eclipse) + subtle Black-World corner brackets
## - World-flip mirror-wipe ripple (with calm flash_reduced alternative)
## - Stolen Moves Cage Strip & Moon-Glass Pocket / Cue-Mirror micro-badges
## - Canonical Truth Shadow renderer (SE gold / NW wrong / black_lantern)
## - Mirror Avatar reflection tether, state silhouettes, and pixel-snapped bolts/beams
## Strictly uses the 20-colour Last Light palette (LxPalette.PAL).

const PAL: Dictionary = LxPalette.PAL
const SHADOW_TRUTH := Vector2(6.0, 5.0)
const SHADOW_LIE := Vector2(-6.0, -5.0)


static func draw_hud(
	canvas: Node2D,
	rule: LxIsland7Rule,
	reg_id: String,
	flip_flash_t: float,
	flip_to_black: bool,
	reclaim_flash_t: float,
	lock_pulse_t: float
) -> void:
	if rule == null or canvas == null:
		return
	var face: String = rule.get_active_world_face(reg_id)
	var stolen: Array[String] = rule.get_stolen_moves()
	var is_black: bool = face == "black"
	# Keep untouched legacy Island 7 regions completely clean unless a rule is actively engaged
	var is_leg: bool = LxLegacy.is_legacy_region(LxIsland7Rule.ISLAND_ID, reg_id)
	if is_leg and not is_black and stolen.is_empty() and flip_flash_t <= 0.0 and reclaim_flash_t <= 0.0:
		return

	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var fred: bool = LxHudFx.flash_reduced()

	# Peripheral Two-Worlds framing: subtle obsidian-rose corner filigree in Black World
	if is_black:
		var ba: float = 0.34 if fred else 0.52
		var bc: Color = Color(c_rose, ba)
		var bw_c: Color = Color(c_wine, ba * 0.85)
		for corner: Array in [[2.0, 2.0, 1.0, 1.0], [317.0, 2.0, -1.0, 1.0], [2.0, 177.0, 1.0, -1.0], [317.0, 177.0, -1.0, -1.0]]:
			var cx: float = float(corner[0])
			var cy: float = float(corner[1])
			var sx_d: float = float(corner[2])
			var sy_d: float = float(corner[3])
			canvas.draw_rect(Rect2(cx if sx_d > 0.0 else cx - 5.0, cy, 6.0, 1.0), bc)
			canvas.draw_rect(Rect2(cx, cy if sy_d > 0.0 else cy - 5.0, 1.0, 6.0), bc)
			canvas.draw_rect(Rect2(cx + sx_d * 2.0, cy + sy_d * 2.0, 1.0, 1.0), bw_c)

	# World-transition mirror-wipe ripple (calm steady edge tint when flash_reduced)
	if flip_flash_t > 0.0:
		var u: float = 1.0 - clampf(flip_flash_t / 1.2, 0.0, 1.0)
		var wave_c: Color = c_rose if flip_to_black else c_ice
		if fred:
			var fa: float = sin(u * PI) * 0.22
			canvas.draw_rect(Rect2(0.0, 0.0, 320.0, 3.0), Color(wave_c, fa))
			canvas.draw_rect(Rect2(0.0, 177.0, 320.0, 3.0), Color(wave_c, fa))
		else:
			var alpha: float = sin(u * PI) * 0.70
			var sx: float = roundf(lerpf(0.0, 320.0, u))
			var sx2: float = roundf(lerpf(0.0, 320.0, clampf(u - 0.08, 0.0, 1.0)))
			canvas.draw_rect(Rect2(sx - 3.0, 0.0, 6.0, 180.0), Color(wave_c, alpha * 0.42))
			canvas.draw_rect(Rect2(sx, 0.0, 1.0, 180.0), Color(c_cream, alpha))
			if u > 0.08:
				canvas.draw_rect(Rect2(sx2, 0.0, 1.0, 180.0), Color(wave_c, alpha * 0.55))

	# 1. Silver / Black World Face Pill
	var y_cur: float = 64.0
	var show_world_pill: bool = is_black or (not reg_id.begins_with("theatre_") and not reg_id.begins_with("masq_"))
	if show_world_pill:
		var bx: float = 246.0
		var bw: float = 68.0
		var bh: float = 13.0
		var rim_c: Color = c_cream if (flip_flash_t > 0.6 and not fred) else (c_rose if is_black else c_ice)
		canvas.draw_rect(Rect2(bx, y_cur, bw, bh), c_void)
		canvas.draw_rect(Rect2(bx + 1.0, y_cur + 1.0, bw - 2.0, bh - 2.0), c_void if is_black else c_night)
		canvas.draw_rect(Rect2(bx + 1.0, y_cur + 1.0, bw - 2.0, 1.0), rim_c)
		canvas.draw_rect(Rect2(bx + 1.0, y_cur + bh - 2.0, bw - 2.0, 1.0), c_wine if is_black else c_sky)
		if is_black:
			# Eclipsed obsidian moon with crisp rose corona & cream diamond flare
			canvas.draw_rect(Rect2(bx + 4.0, y_cur + 4.0, 6.0, 5.0), c_wine)
			canvas.draw_rect(Rect2(bx + 5.0, y_cur + 3.0, 4.0, 7.0), c_rose)
			canvas.draw_rect(Rect2(bx + 6.0, y_cur + 4.0, 3.0, 5.0), c_void)
			canvas.draw_rect(Rect2(bx + 5.0, y_cur + 5.0, 1.0, 3.0), c_cream)
		else:
			# Luminous Silver full lunar disc with specular glint
			canvas.draw_rect(Rect2(bx + 5.0, y_cur + 3.0, 4.0, 7.0), c_sky)
			canvas.draw_rect(Rect2(bx + 4.0, y_cur + 4.0, 6.0, 5.0), c_ice)
			canvas.draw_rect(Rect2(bx + 5.0, y_cur + 4.0, 2.0, 2.0), c_cream)
		var fkey: String = "ISL7_HUD_BLACK" if is_black else "ISL7_HUD_SILVER"
		if LxStrings.has_id(fkey):
			LxPixelFont.draw(canvas, LxStrings.text(fkey), Vector2(bx + 14.0, y_cur + 4.0), c_rose if is_black else c_cream)
		y_cur += bh + 2.0

	# 2. Stolen Moves Cage Strip (top-right stack, crimson velvet + golden bars)
	if not stolen.is_empty():
		var pill_w: float = 98.0
		var pill_x: float = 314.0 - pill_w
		var row_h: float = 12.0
		var total_h: float = 12.0 + float(stolen.size()) * row_h
		var pulse_on: bool = lock_pulse_t > 0.0 and not fred
		var calm_hit: bool = lock_pulse_t > 0.0 and fred
		canvas.draw_rect(Rect2(pill_x, y_cur, pill_w, total_h), c_void)
		canvas.draw_rect(Rect2(pill_x + 1.0, y_cur + 1.0, pill_w - 2.0, total_h - 2.0), c_wine if pulse_on else c_night)
		canvas.draw_rect(Rect2(pill_x + 1.0, y_cur + 1.0, pill_w - 2.0, 1.0), c_cream if pulse_on else (c_rose if calm_hit else c_coral))
		var hdr: String = LxStrings.text("ISL7_HUD_STOLEN") if LxStrings.has_id("ISL7_HUD_STOLEN") else ""
		if not hdr.is_empty():
			LxPixelFont.draw(canvas, hdr, Vector2(pill_x + 5.0, y_cur + 4.0), c_cream if pulse_on else c_gold)
		for i: int in range(stolen.size()):
			var mid: String = stolen[i]
			var ry: float = y_cur + 12.0 + float(i) * row_h
			canvas.draw_rect(Rect2(pill_x + 4.0, ry + 1.0, 7.0, 7.0), c_void)
			canvas.draw_rect(Rect2(pill_x + 5.0, ry + 2.0, 5.0, 5.0), c_dusk)
			canvas.draw_rect(Rect2(pill_x + 6.0, ry + 2.0, 1.0, 5.0), c_coral)
			canvas.draw_rect(Rect2(pill_x + 8.0, ry + 2.0, 1.0, 5.0), c_coral)
			var mkey: String = str(LxIsland7Rule.MOVE_LABEL_KEYS.get(mid, ""))
			var mlbl: String = LxStrings.text(mkey) if (not mkey.is_empty() and LxStrings.has_id(mkey)) else ""
			if not mlbl.is_empty():
				LxPixelFont.draw(canvas, mlbl, Vector2(pill_x + 15.0, ry + 2.0), c_cream if pulse_on else c_rose)
		y_cur += total_h + 2.0
	elif reclaim_flash_t > 0.0:
		var rbx: float = 216.0
		var rbw: float = 98.0
		canvas.draw_rect(Rect2(rbx, y_cur, rbw, 12.0), c_void)
		canvas.draw_rect(Rect2(rbx + 1.0, y_cur + 1.0, rbw - 2.0, 10.0), c_night)
		canvas.draw_rect(Rect2(rbx + 1.0, y_cur + 1.0, rbw - 2.0, 1.0), c_gold)
		var rlbl: String = LxStrings.text("ISL7_HUD_RESTORED") if LxStrings.has_id("ISL7_HUD_RESTORED") else ""
		if not rlbl.is_empty():
			LxPixelFont.draw(canvas, rlbl, Vector2(rbx + 6.0, y_cur + 4.0), c_cream)
		y_cur += 14.0

	# 3. Dungeon Power Micro-Badges (Moon Pocket / Cue Mirror with greyscale-distinct icons)
	if rule.has_moon_pocket():
		var pbx: float = 248.0
		var pbw: float = 66.0
		var carrying: bool = Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("is_carrying") and bool(Lx.player.call("is_carrying"))
		canvas.draw_rect(Rect2(pbx, y_cur, pbw, 11.0), c_void)
		canvas.draw_rect(Rect2(pbx + 1.0, y_cur + 1.0, pbw - 2.0, 9.0), c_night)
		canvas.draw_rect(Rect2(pbx + 1.0, y_cur + 1.0, pbw - 2.0, 1.0), c_cream if carrying else c_sky)
		# Split Silver/Black Moon-Glass icon (4x5)
		canvas.draw_rect(Rect2(pbx + 4.0, y_cur + 3.0, 2.0, 5.0), c_cream if carrying else c_ice)
		canvas.draw_rect(Rect2(pbx + 6.0, y_cur + 3.0, 2.0, 5.0), c_rose)
		var plbl: String = LxStrings.text("ISL7_HUD_POCKET") if LxStrings.has_id("ISL7_HUD_POCKET") else ""
		if not plbl.is_empty():
			LxPixelFont.draw(canvas, plbl, Vector2(pbx + 11.0, y_cur + 3.0), c_cream if carrying else c_ice)
		y_cur += 13.0
	if rule.has_cue_mirror():
		var in_spot: bool = false
		if Lx.player is Node2D and is_instance_valid(Lx.player):
			in_spot = LxIsland7Rule.is_in_cue_spotlight((Lx.player as Node2D).global_position)
		var cbx: float = 248.0
		var cbw: float = 66.0
		canvas.draw_rect(Rect2(cbx, y_cur, cbw, 11.0), c_void)
		canvas.draw_rect(Rect2(cbx + 1.0, y_cur + 1.0, cbw - 2.0, 9.0), c_night)
		canvas.draw_rect(Rect2(cbx + 1.0, y_cur + 1.0, cbw - 2.0, 1.0), c_cream if in_spot else c_gold)
		# Gilded Cue-Mirror spotlight diamond icon (5x5)
		canvas.draw_rect(Rect2(cbx + 5.0, y_cur + 3.0, 1.0, 5.0), c_cream if in_spot else c_gold)
		canvas.draw_rect(Rect2(cbx + 3.0, y_cur + 5.0, 5.0, 1.0), c_cream if in_spot else c_gold)
		canvas.draw_rect(Rect2(cbx + 5.0, y_cur + 5.0, 1.0, 1.0), c_ice)
		var clbl: String = LxStrings.text("ISL7_HUD_CUE") if LxStrings.has_id("ISL7_HUD_CUE") else ""
		if not clbl.is_empty():
			LxPixelFont.draw(canvas, clbl, Vector2(cbx + 11.0, y_cur + 3.0), c_cream if in_spot else c_gold)


static func draw_truth_shadow(
	ci: CanvasItem,
	base_pos: Vector2,
	rx: float,
	ry: float,
	shadow_mode: String = "se_gold",
	lens_boost: bool = false
) -> void:
	var mode: String = shadow_mode.strip_edges().to_lower()
	if mode == "none":
		return
	var c_void: Color = PAL["void"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var alpha: float = 0.86 if lens_boost else 0.72
	var off: Vector2 = SHADOW_LIE if mode == "nw_wrong" else SHADOW_TRUTH
	var mid: Vector2 = (base_pos + off * 0.48).round()
	var c: Vector2 = (base_pos + off).round()
	var w: float = maxf(6.0, roundf(rx * 2.0))
	var h: float = maxf(3.0, roundf(ry * 2.0))
	ci.draw_rect(Rect2(mid.x - floorf(w * 0.4), mid.y - floorf(h * 0.4), maxf(3.0, w * 0.8), maxf(2.0, h * 0.8)), Color(c_void, alpha * 0.88))
	ci.draw_rect(Rect2(c.x - floorf(w * 0.5) + 1.0, c.y - floorf(h * 0.5), maxf(2.0, w - 2.0), h), Color(c_void, alpha))
	ci.draw_rect(Rect2(c.x - floorf(w * 0.5), c.y - floorf(h * 0.5) + 1.0, w, maxf(1.0, h - 2.0)), Color(c_void, alpha))
	if mode == "se_gold":
		var sx: float = c.x + floorf(w * 0.5) - 3.0
		var sy: float = c.y + floorf(h * 0.5) - 1.0
		ci.draw_rect(Rect2(sx, sy, 4.0, 2.0), Color(c_gold, 0.92 if lens_boost else 0.78))
		ci.draw_rect(Rect2(sx + 2.0, sy, 2.0, 1.0), Color(c_cream, 0.95 if lens_boost else 0.74))
	elif mode == "nw_wrong":
		var nx: float = c.x - floorf(w * 0.5) - 2.0
		var ny: float = c.y - floorf(h * 0.5) - 2.0
		ci.draw_rect(Rect2(nx, ny, 4.0, 3.0), Color(c_void, minf(0.95, alpha + 0.16)))
		ci.draw_rect(Rect2(nx, ny, 2.0, 2.0), c_rose if lens_boost else c_plum)
	elif mode == "black_lantern":
		var lp: Vector2 = (c + Vector2(rx + 3.0, 1.0)).round()
		ci.draw_rect(Rect2(lp.x - 3.0, lp.y - 3.0, 7.0, 7.0), c_void)
		ci.draw_rect(Rect2(lp.x - 2.0, lp.y - 2.0, 5.0, 5.0), c_rose if lens_boost else c_wine)
		ci.draw_rect(Rect2(lp.x - 1.0, lp.y - 1.0, 3.0, 3.0), c_void)
		ci.draw_rect(Rect2(lp.x - 1.0, lp.y - 4.0, 3.0, 1.0), c_cream if lens_boost else c_rose)


static func draw_mirror_avatar(
	ci: CanvasItem,
	pos: Vector2,
	state: int,
	in_blk: bool,
	facing: Vector2,
	pivot: Vector2,
	link_range: float,
	wp: Vector2,
	blocked_t: float,
	shot_flash_t: float,
	resync_t: float,
	bolts: Array[Dictionary],
	beam_segs: Array[Dictionary],
	beam_vis_t: float
) -> void:
	var c_void: Color = PAL["void"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var fred: bool = LxHudFx.flash_reduced()

	if state == LxMirrorAvatar.State.SHATTERED:
		for sp: Vector2 in [Vector2(-4.0, 2.0), Vector2(3.0, -1.0), Vector2(1.0, 4.0)]:
			ci.draw_rect(Rect2(sp, Vector2(2.0, 2.0)), c_ice)
		return

	var c_cloak_d: Color = (PAL["night"] if in_blk else PAL["deep"]) as Color
	var c_cloak_m: Color = (PAL["plum"] if in_blk else PAL["sky"]) as Color
	var c_cloak_h: Color = (PAL["rose"] if in_blk else c_ice) as Color
	var is_blocked: bool = (state == LxMirrorAvatar.State.DESYNCED_WALL) or (blocked_t > 0.0)
	var is_dim: bool = (state == LxMirrorAvatar.State.PHANTOM_DIM)
	var c_eye: Color = c_coral if is_blocked else c_cream
	var body_a: float = 0.45 if is_dim else 1.0

	# Diegetic reflection tether & pixel-snapped alignment tick toward mirror axis / Wick
	if not is_dim and wp.x > -9000.0 and wp.distance_to(pos) <= link_range:
		var anchor_w: Vector2 = pivot if pivot.is_finite() else (pos + wp) * 0.5
		var rel_a: Vector2 = (anchor_w - pos).round()
		var tether_len: float = rel_a.length()
		if tether_len >= 12.0 and tether_len <= link_range:
			var t_col: Color = c_coral if is_blocked else c_cloak_h
			var ta: float = 0.16 if fred else (0.30 if is_blocked else 0.24)
			var dir_t: Vector2 = rel_a / tether_len
			var step_px: float = 8.0
			var d_cur: float = 8.0
			while d_cur < tether_len - 4.0:
				var p0: Vector2 = (dir_t * d_cur).round()
				var p1: Vector2 = (dir_t * minf(tether_len - 4.0, d_cur + 3.0)).round()
				ci.draw_line(p0 + Vector2(0.0, -4.0), p1 + Vector2(0.0, -4.0), Color(t_col, ta), 1.0)
				d_cur += step_px
			# Crisp 3x3 axis-alignment diamond tick at mirror midpoint
			var mp: Vector2 = rel_a + Vector2(0.0, -4.0)
			ci.draw_rect(Rect2(mp.x - 1.0, mp.y - 1.0, 3.0, 3.0), Color(c_cream, ta + 0.14))

	draw_truth_shadow(ci, Vector2(0.0, 4.0), 5.5, 2.2, "nw_wrong" if in_blk else "se_gold", false)
	# Hollow reflective diamond pip above hood (distinguishes reflection from real Wick even in greyscale)
	ci.draw_rect(Rect2(-1.0, -17.0, 3.0, 1.0), Color(c_cloak_h, body_a))
	ci.draw_rect(Rect2(-2.0, -16.0, 5.0, 1.0), Color(c_cream, body_a))
	ci.draw_rect(Rect2(-1.0, -15.0, 3.0, 1.0), Color(c_cloak_h, body_a))
	ci.draw_rect(Rect2(0.0, -16.0, 1.0, 1.0), Color(c_void, body_a))

	# Cloaked mirror-Wick silhouette (distinct Silver-Ice vs Obsidian-Rose world palette)
	ci.draw_rect(Rect2(-3.0, -13.0, 6.0, 3.0), Color(c_void, body_a))
	ci.draw_rect(Rect2(-5.0, -10.0, 10.0, 12.0), Color(c_void, body_a))
	ci.draw_rect(Rect2(-2.0, -12.0, 4.0, 2.0), Color(c_cloak_h, body_a))
	ci.draw_rect(Rect2(-4.0, -9.0, 8.0, 10.0), Color(c_cloak_d, body_a))
	ci.draw_rect(Rect2(-3.0, -9.0, 6.0, 9.0), Color(c_cloak_m, body_a))
	ci.draw_rect(Rect2(-3.0, -9.0, 2.0, 7.0), Color(c_cloak_h, body_a))
	ci.draw_rect(Rect2(-2.0, -7.0, 4.0, 3.0), Color(c_void, body_a))
	ci.draw_rect(Rect2(-2.0, -6.0, 1.0, 1.0), Color(c_eye, body_a))
	ci.draw_rect(Rect2(1.0, -6.0, 1.0, 1.0), Color(c_eye, body_a))
	# Unmistakable coral wall-desync X-bracket when blocked
	if is_blocked:
		ci.draw_rect(Rect2(-6.0, -11.0, 1.0, 4.0), c_coral)
		ci.draw_rect(Rect2(5.0, -11.0, 1.0, 4.0), c_coral)
		ci.draw_rect(Rect2(-2.0, -10.0, 4.0, 1.0), c_coral)
	# Held mirrored lantern orb
	var lpos: Vector2 = (facing * 7.0 + Vector2(0.0, -4.0)).round()
	var flash_c: Color = c_cream if (shot_flash_t > 0.0 and not fred) else c_cloak_h
	ci.draw_rect(Rect2(lpos - Vector2.ONE, Vector2(3.0, 3.0)), Color(flash_c, body_a))
	ci.draw_rect(Rect2(lpos, Vector2.ONE), Color(c_cream, body_a))
	if resync_t > 0.0:
		var ra: float = clampf(resync_t / 0.35, 0.0, 1.0) * (0.55 if fred else 0.92)
		ci.draw_arc(Vector2(0.0, -4.0), 10.0, 0.0, TAU, 16, Color(c_cream, ra), 1.0)
	# Live mirrored bolts
	for b: Dictionary in bolts:
		var bp: Vector2 = ((b["pos"] as Vector2) - pos).round()
		var bc: Color = (c_ice if bool(b["prism"]) else (PAL["rose"] if in_blk else PAL["gold"])) as Color
		ci.draw_rect(Rect2(bp - Vector2.ONE, Vector2(3.0, 3.0)), bc)
		ci.draw_rect(Rect2(bp, Vector2.ONE), c_cream)
	# Pixel-snapped mirrored beam segments
	if beam_vis_t > 0.0:
		var ba: float = clampf(beam_vis_t / 0.24, 0.0, 1.0) * (0.65 if fred else 1.0)
		for seg: Dictionary in beam_segs:
			var s0: Vector2 = ((seg["start"] as Vector2) - pos).round()
			var s1: Vector2 = ((seg["end"] as Vector2) - pos).round()
			var sc: Color = (c_ice if str(seg["color"]) == LxHit.COLOR_BLUE else PAL["gold"]) as Color
			ci.draw_line(s0, s1, Color(sc, ba), 3.0)
			ci.draw_line(s0, s1, Color(c_cream, ba), 1.0)
