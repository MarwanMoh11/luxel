class_name LxHudFx
extends RefCounted
## Diegetic HUD edge indicators (off-screen stolen/hung lantern compass)
## and Boss Phase escalation filigree on the boss bar.
## Uses strictly the 20 opaque Last Light colours (LxPalette.PAL).


static func flash_reduced() -> bool:
	return Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))


static func shake_enabled() -> bool:
	return Lx.save == null or float(Lx.save.settings.get("screen_shake", 1.0)) > 0.01


static func draw_cues(hud: CanvasItem, cues: Array[Dictionary], prompt_rect: Rect2) -> void:
	var has_prompt: bool = prompt_rect.has_area()
	var placed: Array[Rect2] = []
	for cue: Dictionary in cues:
		var t: float = float(cue["t"])
		var dur: float = float(cue["dur"])
		var fade_p: float = minf(t / 0.15, (dur - t) / 0.35)
		var col: Color = LxPalette.fade_step(fade_p, str(cue["color"]))
		if col.a <= 0.0:
			continue
		var screen_pos: Vector2 = cue["pos"] as Vector2
		if bool(cue["is_world"]) and Lx.camera != null:
			screen_pos = screen_pos - Lx.camera.global_position + Vector2(160.0, 90.0)
		screen_pos.y -= floorf(t * 14.0)
		var txt: String = str(cue["text"])
		var tw: float = float(LxPixelFont.width(txt, 1))
		screen_pos.x = clampf(roundf(screen_pos.x), 8.0 + tw * 0.5, 312.0 - tw * 0.5)
		screen_pos.y = clampf(roundf(screen_pos.y), 16.0, 152.0)
		var cr := Rect2(screen_pos.x - tw * 0.5 - 2.0, screen_pos.y - 1.0, tw + 4.0, 7.0)
		if has_prompt and cr.intersects(prompt_rect.grow(2.0)):
			screen_pos.y = maxf(14.0, prompt_rect.position.y - 8.0)
			cr.position.y = screen_pos.y - 1.0
		for prev: Rect2 in placed:
			if cr.intersects(prev):
				screen_pos.y = maxf(14.0, prev.position.y - 8.0)
				cr.position.y = screen_pos.y - 1.0
		placed.append(cr)
		LxPixelFont.draw_centered(hud, txt, screen_pos.x, screen_pos.y, col, 1)


static func draw_indicators(hud: CanvasItem, blink_t: float, boss_active: bool, boss_phase: int) -> void:
	var fred: bool = flash_reduced()
	_draw_lantern_edge_compass(hud, blink_t, fred)
	_draw_counter_ready_halo(hud, blink_t, fred)
	_draw_ember_ready_halo(hud, blink_t, fred)
	_draw_biome_rule_badge(hud, blink_t, fred)
	if boss_active and boss_phase >= 2:
		_draw_boss_phase_filigree(hud, blink_t, boss_phase, fred)


static func _draw_biome_rule_badge(hud: CanvasItem, blink_t: float, fred: bool) -> void:
	var br: LxBiomeRules = LxBiomeRules.active_instance
	if br == null or not is_instance_valid(br) or br.island_id <= 1:
		return
	var o := Vector2(5.0, 22.0)
	var bg: Color = LxPalette.PAL["void"] as Color
	var night: Color = LxPalette.PAL["night"] as Color
	var bm: LxBiomeMechanics = LxBiomeMechanics.active_instance
	match br.island_id:
		2:
			if not br.is_dungeon:
				var fill_w: float = floorf(18.0 * clampf(br.tide_phase, 0.0, 1.0))
				hud.draw_rect(Rect2(o, Vector2(22.0, 5.0)), bg)
				hud.draw_rect(Rect2(o + Vector2(1.0, 1.0), Vector2(20.0, 3.0)), night)
				var tc: Color = (LxPalette.PAL["ice"] if br.tide_surging else LxPalette.PAL["sky"]) as Color
				if fill_w > 0.0:
					hud.draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(fill_w, 1.0)), tc)
			elif br.beam_buff_t > 0.0:
				hud.draw_rect(Rect2(o, Vector2(7.0, 7.0)), bg)
				hud.draw_rect(Rect2(o + Vector2(2.0, 1.0), Vector2(3.0, 5.0)), LxPalette.PAL["gold"] as Color)
				hud.draw_rect(Rect2(o + Vector2(1.0, 2.0), Vector2(5.0, 3.0)), LxPalette.PAL["gold"] as Color)
				hud.draw_rect(Rect2(o + Vector2(3.0, 3.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
		4:
			if bm != null and is_instance_valid(bm) and bm.tailwind_t > 0.0:
				var tw_w: float = floorf(18.0 * clampf(bm.tailwind_t / 2.2, 0.0, 1.0))
				hud.draw_rect(Rect2(o, Vector2(22.0, 5.0)), bg)
				hud.draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(maxf(1.0, tw_w), 1.0)), LxPalette.PAL["ice"] as Color)
				hud.draw_rect(Rect2(o + Vector2(2.0 + tw_w - 1.0, 2.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
		5:
			if br.starlight_surge_t > 0.0:
				var sw: float = floorf(18.0 * clampf(br.starlight_surge_t / 4.0, 0.0, 1.0))
				hud.draw_rect(Rect2(o, Vector2(22.0, 5.0)), bg)
				hud.draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(maxf(1.0, sw), 1.0)), LxPalette.PAL["gold"] as Color)
				hud.draw_rect(Rect2(o + Vector2(2.0 + sw - 1.0, 2.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
		6:
			var vw: float = floorf(18.0 * clampf(br.vent_cycle, 0.0, 1.0))
			hud.draw_rect(Rect2(o, Vector2(22.0, 5.0)), bg)
			hud.draw_rect(Rect2(o + Vector2(1.0, 1.0), Vector2(20.0, 3.0)), night)
			var vc: Color = (LxPalette.PAL["gold"] if br.vent_cycle >= 0.56 else LxPalette.PAL["coral"]) as Color
			if vw > 0.0:
				hud.draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(vw, 1.0)), vc)
			if bm != null and is_instance_valid(bm) and bm.molten_charges > 0:
				for k: int in range(bm.molten_charges):
					var px: float = o.x + 25.0 + float(k) * 5.0
					hud.draw_rect(Rect2(px, o.y, 4.0, 5.0), bg)
					hud.draw_rect(Rect2(px + 1.0, o.y + 1.0, 2.0, 3.0), LxPalette.PAL["coral"] as Color)
					hud.draw_rect(Rect2(px + 1.0, o.y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"] as Color)
		7:
			hud.draw_rect(Rect2(o, Vector2(9.0, 9.0)), bg)
			hud.draw_rect(Rect2(o + Vector2(1.0, 1.0), Vector2(7.0, 7.0)), night)
			var full_m: bool = br.lunar_phase > 0.5
			hud.draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(5.0, 5.0)), (LxPalette.PAL["ice"] if full_m else LxPalette.PAL["plum"]) as Color)
			if full_m:
				hud.draw_rect(Rect2(o + Vector2(3.0, 3.0), Vector2(3.0, 3.0)), LxPalette.PAL["cream"] as Color)
				if bm != null and is_instance_valid(bm) and bm.mirror_echo_active:
					hud.draw_rect(Rect2(o + Vector2(11.0, 2.0), Vector2(5.0, 5.0)), bg)
					hud.draw_rect(Rect2(o + Vector2(12.0, 3.0), Vector2(3.0, 3.0)), LxPalette.PAL["ice"] as Color)
					hud.draw_rect(Rect2(o + Vector2(13.0, 4.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
			else:
				hud.draw_rect(Rect2(o + Vector2(4.0, 2.0), Vector2(3.0, 5.0)), night)
				hud.draw_rect(Rect2(o + Vector2(2.0, 3.0), Vector2(1.0, 3.0)), LxPalette.PAL["sky"] as Color)
		8:
			var seals_b: int = bm.dawn_seals_broken if (bm != null and is_instance_valid(bm)) else 0
			for k: int in range(3):
				var sx: float = o.x + float(k) * 7.0
				hud.draw_rect(Rect2(sx, o.y, 6.0, 6.0), bg)
				if k < seals_b:
					hud.draw_rect(Rect2(sx + 1.0, o.y + 1.0, 4.0, 4.0), LxPalette.PAL["gold"] as Color)
					hud.draw_rect(Rect2(sx + 2.0, o.y + 2.0, 2.0, 2.0), LxPalette.PAL["cream"] as Color)
				else:
					var pulse_on: bool = fred or (int(blink_t * 4.0) % 2 == 0)
					hud.draw_rect(Rect2(sx + 1.0, o.y + 1.0, 4.0, 4.0), (LxPalette.PAL["rose"] if pulse_on else LxPalette.PAL["plum"]) as Color)
					hud.draw_rect(Rect2(sx + 2.0, o.y + 2.0, 2.0, 2.0), bg)


static func _draw_ember_ready_halo(hud: CanvasItem, blink_t: float, fred: bool) -> void:
	if Lx.state == null or not Lx.state.has_move("sunflare"):
		return
	if Lx.player == null or not is_instance_valid(Lx.player) or not Lx.player.has_method("get_ember_ratio"):
		return
	if float(Lx.player.call("get_ember_ratio")) < 0.999:
		return
	var pulse: bool = fred or (int(blink_t * 6.0) % 2 == 0)
	var hi: Color = (LxPalette.PAL["cream"] if pulse else LxPalette.PAL["gold"]) as Color
	var warm: Color = LxPalette.PAL["apricot"] as Color
	var bg: Color = LxPalette.PAL["void"] as Color
	# Left & right brass starlight pips framing the Ember gauge (246..314, 166..174)
	for sx: float in [243.0, 315.0]:
		hud.draw_rect(Rect2(sx - 1.0, 168.0, 3.0, 3.0), bg)
		hud.draw_rect(Rect2(sx, 169.0, 1.0, 1.0), hi)
		hud.draw_rect(Rect2(sx, 167.0, 1.0, 1.0), warm)
		hud.draw_rect(Rect2(sx, 171.0, 1.0, 1.0), warm)
	if not fred:
		for mi: int in range(3):
			var u: float = fmod(blink_t * 0.95 + float(mi) * 0.33, 1.0)
			var mx: float = roundf(254.0 + float(mi) * 24.0 + sin(blink_t * 2.4 + float(mi) * 2.0) * 3.0)
			var my: float = roundf(165.0 - u * 5.0)
			hud.draw_rect(Rect2(mx, my, 1.0, 1.0), (LxPalette.PAL["cream"] if u < 0.35 else LxPalette.PAL["gold"]) as Color)


static func _draw_counter_ready_halo(hud: CanvasItem, blink_t: float, fred: bool) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player):
		return
	var md_v: Variant = Lx.player.get("move_dash")
	if not (md_v is Object) or not is_instance_valid(md_v):
		return
	var ct: float = float((md_v as Object).get("counter_t"))
	if ct <= 0.01:
		return
	var frac: float = clampf(ct / 1.45, 0.0, 1.0)
	var pulse: bool = fred or (int(blink_t * 10.0) % 2 == 0)
	var col: Color = (LxPalette.PAL["cream"] if pulse else LxPalette.PAL["ice"]) as Color
	var accent: Color = LxPalette.PAL["gold"] as Color
	# Crisp 1-px highlight corners & draining counter bar directly above the Bolt slot (5, 160)
	var bx: float = 5.0
	var by: float = 158.0
	var bar_w: float = maxf(2.0, floorf(13.0 * frac))
	hud.draw_rect(Rect2(bx - 1.0, by - 1.0, 15.0, 3.0), LxPalette.PAL["void"] as Color)
	hud.draw_rect(Rect2(bx, by, bar_w, 1.0), col)
	hud.draw_rect(Rect2(bx + bar_w - 1.0, by, 1.0, 1.0), accent)
	# Corner sparkles framing the primary kit slot while counter empowerment is live
	hud.draw_rect(Rect2(bx - 1.0, 160.0, 1.0, 2.0), col)
	hud.draw_rect(Rect2(bx + 13.0, 160.0, 1.0, 2.0), col)


static func _draw_lantern_edge_compass(hud: CanvasItem, blink_t: float, fred: bool) -> void:
	if Lx.player == null or not is_instance_valid(Lx.player) or Lx.camera == null:
		return
	var lan_v: Variant = Lx.player.get("lantern")
	if not (lan_v is Object) or not is_instance_valid(lan_v):
		return
	var lan: Object = lan_v as Object
	var st: int = int(lan.get("state"))
	var stolen: bool = st == 4 # LxLantern.State.CARRIED
	var hung: bool = st == 1 or st == 2 # FLYING or HANGING
	if not stolen and not hung:
		return
	var lp_v: Variant = lan.get("pos")
	if not (lp_v is Vector2):
		return
	var sp: Vector2 = (lp_v as Vector2) - Lx.camera.global_position + Vector2(160.0, 90.0)
	if sp.x >= 8.0 and sp.x <= 312.0 and sp.y >= 8.0 and sp.y <= 172.0:
		return

	var center := Vector2(160.0, 90.0)
	var delta: Vector2 = sp - center
	if delta.length_squared() <= 1.0:
		return
	var dir: Vector2 = delta.normalized()
	var tx: float = (148.0 / absf(dir.x)) if absf(dir.x) > 0.001 else 9999.0
	var ty: float = (78.0 / absf(dir.y)) if absf(dir.y) > 0.001 else 9999.0
	var edge: Vector2 = (center + dir * minf(tx, ty)).round()
	var pulse: bool = fred or (int(blink_t * (8.0 if stolen else 4.0)) % 2 == 0)

	var bg: Color = LxPalette.PAL["void"] as Color
	var rim: Color = (LxPalette.PAL["coral"] if stolen else LxPalette.PAL["apricot"]) as Color
	var core: Color = (LxPalette.PAL["cream"] if pulse else LxPalette.PAL["gold"]) as Color
	hud.draw_rect(Rect2(edge + Vector2(-4.0, -4.0), Vector2(9.0, 9.0)), bg)
	hud.draw_rect(Rect2(edge + Vector2(-3.0, -3.0), Vector2(7.0, 7.0)), rim)
	hud.draw_rect(Rect2(edge + Vector2(-2.0, -2.0), Vector2(5.0, 5.0)), LxPalette.PAL["night"] as Color)
	hud.draw_rect(Rect2(edge + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), core)
	# Crisp directional pointer chevron toward the off-screen lantern
	var tip: Vector2 = (edge + dir * 6.0).round()
	var perp := Vector2(-dir.y, dir.x)
	hud.draw_rect(Rect2(tip - Vector2.ONE, Vector2(3.0, 3.0)), bg)
	hud.draw_rect(Rect2(tip, Vector2.ONE), core)
	hud.draw_rect(Rect2((edge + dir * 4.5 + perp * 2.0).round(), Vector2.ONE), rim)
	hud.draw_rect(Rect2((edge + dir * 4.5 - perp * 2.0).round(), Vector2.ONE), rim)


static func _draw_boss_phase_filigree(hud: CanvasItem, blink_t: float, phase: int, fred: bool) -> void:
	var lit: bool = fred or (int(blink_t * 6.0) % 2 == 0)
	var col: Color = (LxPalette.PAL["coral"] if phase >= 3 else LxPalette.PAL["gold"]) as Color
	var hi: Color = (LxPalette.PAL["cream"] if lit else col) as Color
	for side: float in [-1.0, 1.0]:
		var px: float = roundf(160.0 + side * 86.0)
		var py: float = 15.0
		hud.draw_rect(Rect2(px - 1.0, py - 1.0, 3.0, 3.0), LxPalette.PAL["void"] as Color)
		hud.draw_rect(Rect2(px, py, 1.0, 1.0), hi)
		hud.draw_rect(Rect2(px + side * 2.0, py, 2.0, 1.0), col)


static func draw_biome_crest(canvas: CanvasItem, island_id: int, center: Vector2, primary: Color, hi: Color) -> void:
	var c: Vector2 = center.round()
	match clampi(island_id, 1, 8):
		1: # Brass Bell
			canvas.draw_rect(Rect2(c + Vector2(-1.0, -2.0), Vector2(3.0, 3.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(-2.0, 1.0), Vector2(5.0, 1.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), hi)
		2: # Tidal Wave Crest
			canvas.draw_rect(Rect2(c + Vector2(-2.0, 0.0), Vector2(5.0, 2.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(-1.0, -2.0), Vector2(2.0, 2.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(-1.0, -2.0), Vector2(3.0, 1.0)), hi)
		3: # Emerald Forest Leaf
			canvas.draw_rect(Rect2(c + Vector2(-1.0, -2.0), Vector2(3.0, 4.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(-2.0, -1.0), Vector2(5.0, 2.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), hi)
		4: # Botanical Lotus Diamond
			canvas.draw_rect(Rect2(c + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), hi)
		5: # 4-Point Astral Star
			canvas.draw_rect(Rect2(c + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), primary)
			canvas.draw_rect(Rect2(c, Vector2.ONE), hi)
		6: # Forged Kiln Flame
			canvas.draw_rect(Rect2(c + Vector2(-2.0, 0.0), Vector2(5.0, 2.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(-1.0, -2.0), Vector2(3.0, 2.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(0.0, -1.0), Vector2(1.0, 2.0)), hi)
		7: # Silver Crescent Moon
			canvas.draw_rect(Rect2(c + Vector2(-2.0, -2.0), Vector2(4.0, 5.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(0.0, -1.0), Vector2(2.0, 3.0)), LxPalette.PAL["night"] as Color)
			canvas.draw_rect(Rect2(c + Vector2(-2.0, -1.0), Vector2(1.0, 3.0)), hi)
		8: # Eclipsed Dawn Sunburst
			canvas.draw_rect(Rect2(c + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), primary)
			canvas.draw_rect(Rect2(c + Vector2(0.0, -2.0), Vector2(1.0, 1.0)), hi)
			canvas.draw_rect(Rect2(c + Vector2(0.0, 2.0), Vector2(1.0, 1.0)), hi)
			canvas.draw_rect(Rect2(c + Vector2(-2.0, 0.0), Vector2(1.0, 1.0)), hi)
			canvas.draw_rect(Rect2(c + Vector2(2.0, 0.0), Vector2(1.0, 1.0)), hi)
			canvas.draw_rect(Rect2(c, Vector2.ONE), hi)
