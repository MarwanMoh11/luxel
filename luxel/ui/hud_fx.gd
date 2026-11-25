class_name LxHudFx
extends RefCounted
## Diegetic HUD edge indicators (off-screen stolen/hung lantern compass)
## and Boss Phase escalation filigree on the boss bar.
## Uses strictly the 20 opaque Last Light colours (LxPalette.PAL).


static func flash_reduced() -> bool:
	return Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))


static func shake_enabled() -> bool:
	return Lx.save == null or float(Lx.save.settings.get("screen_shake", 1.0)) > 0.01


static func narration_has_title() -> bool:
	if Lx.ui == null:
		return false
	var nar_v: Variant = Lx.ui.get("narration")
	return nar_v is Object and is_instance_valid(nar_v) and (nar_v as Object).has_method("is_saying") and bool((nar_v as Object).call("is_saying", "title"))


static func is_ceremony_active() -> bool:
	if narration_has_title():
		return true
	if Lx.ui != null:
		var nar_v: Variant = Lx.ui.get("narration")
		if nar_v is Object and is_instance_valid(nar_v) and (nar_v as Object).has_method("is_letterbox_on") and bool((nar_v as Object).call("is_letterbox_on")):
			return true
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("get_interactables"):
		var items_v: Variant = Lx.world.call("get_interactables")
		if items_v is Array:
			for it: Variant in (items_v as Array):
				if not (it is Object) or not is_instance_valid(it):
					continue
				var obj: Object = it as Object
				var k: String = str(obj.get("kind"))
				if k != "shrine" and k != "great_lamp":
					continue
				for prop: String in ["_claim_t", "_relight_t", "_dawn_t"]:
					var tv: Variant = obj.get(prop)
					if (tv is float or tv is int) and float(tv) > 0.0:
						return true
	return false


static func sync_reticle_visibility(hud: Node) -> void:
	if Lx.ui == null:
		return
	var cn: Variant = Lx.ui.get("_cursor_node")
	if not (cn is CanvasItem) or not is_instance_valid(cn) or not (cn as CanvasItem).visible:
		return
	var vp: Viewport = hud.get_viewport()
	if vp == null:
		return
	var pos: Vector2 = vp.get_mouse_position().round()
	if Lx.input != null and Lx.input.last_device == "gamepad":
		var center := Vector2(160.0, 90.0)
		if Lx.player != null and Lx.camera != null and Lx.player is Node2D:
			center = (Lx.player as Node2D).global_position - Lx.camera.global_position + Vector2(160.0, 90.0)
		pos = (center + Lx.input.last_aim_dir.normalized() * 42.0).round()
		pos = Vector2(clampf(pos.x, 8.0, 312.0), clampf(pos.y, 8.0, 172.0))
	if Rect2(0.0, 150.0, 166.0, 30.0).has_point(pos) or Rect2(242.0, 156.0, 78.0, 24.0).has_point(pos):
		(cn as CanvasItem).visible = false


static func draw_cues(hud: CanvasItem, cues: Array[Dictionary], prompt_rect: Rect2, notice_rect: Rect2 = Rect2()) -> void:
	var has_prompt: bool = prompt_rect.has_area()
	var has_notice: bool = notice_rect.has_area()
	var hide_titles: bool = narration_has_title()
	var placed: Array[Rect2] = []
	for cue: Dictionary in cues:
		if bool(cue.get("hide_on_title", false)) and hide_titles:
			continue
		var t: float = float(cue["t"])
		var dur: float = float(cue["dur"])
		var fade_p: float = minf(t / 0.15, (dur - t) / 0.35)
		var col: Color = LxPalette.fade_step(fade_p, str(cue["color"]))
		if col.a <= 0.0:
			continue
		var is_world: bool = bool(cue["is_world"])
		var is_boss_callout: bool = bool(cue.get("boss_callout", false))
		var screen_pos: Vector2 = cue["pos"] as Vector2
		if is_world and Lx.camera != null:
			screen_pos = screen_pos - Lx.camera.global_position + Vector2(160.0, 90.0)
		if is_boss_callout:
			screen_pos.y = 126.0
		else:
			screen_pos.y -= floorf(t * 14.0)
		var txt: String = str(cue["text"])
		var tw: float = float(LxPixelFont.width(txt, 1))
		screen_pos.x = clampf(roundf(screen_pos.x), 8.0 + tw * 0.5, 312.0 - tw * 0.5)
		screen_pos.y = 126.0 if is_boss_callout else clampf(roundf(screen_pos.y), 16.0, 152.0)
		var pad_y: float = 1.0 if is_world else 2.0
		var box_h: float = 7.0 if is_world else 9.0
		var cr := Rect2(roundf(screen_pos.x - tw * 0.5) - (2.0 if is_world else 3.0), screen_pos.y - pad_y, tw + (4.0 if is_world else 6.0), box_h)
		if not is_boss_callout:
			if has_notice and cr.intersects(notice_rect.grow(2.0)):
				screen_pos.y = clampf(notice_rect.end.y + 3.0, 16.0, 152.0)
				cr.position.y = screen_pos.y - pad_y
			if has_prompt and cr.intersects(prompt_rect.grow(2.0)):
				var above_y: float = prompt_rect.position.y - (box_h + 1.0)
				var cand_above := Rect2(cr.position.x, above_y - pad_y, cr.size.x, cr.size.y)
				if above_y >= 16.0 and not (has_notice and cand_above.intersects(notice_rect.grow(2.0))):
					screen_pos.y = above_y
				else:
					screen_pos.y = clampf(prompt_rect.end.y + 3.0, 16.0, 152.0)
				cr.position.y = screen_pos.y - pad_y
			for prev: Rect2 in placed:
				if cr.intersects(prev):
					var next_y: float = prev.position.y - (box_h + 1.0)
					var cand_prev := Rect2(cr.position.x, next_y - pad_y, cr.size.x, cr.size.y)
					if next_y >= 16.0 and not (has_notice and cand_prev.intersects(notice_rect.grow(2.0))) and not (has_prompt and cand_prev.intersects(prompt_rect.grow(2.0))):
						screen_pos.y = next_y
					else:
						screen_pos.y = clampf(prev.end.y + 2.0, 16.0, 152.0)
					cr.position.y = screen_pos.y - pad_y
			if has_notice and cr.intersects(notice_rect.grow(2.0)):
				screen_pos.y = clampf(notice_rect.end.y + 3.0, 16.0, 152.0)
				cr.position.y = screen_pos.y - pad_y
			if has_prompt and cr.intersects(prompt_rect.grow(2.0)):
				screen_pos.y = clampf(prompt_rect.end.y + 3.0, 16.0, 152.0)
				cr.position.y = screen_pos.y - pad_y
		placed.append(cr)
		if is_boss_callout:
			var tx: float = roundf(screen_pos.x - tw * 0.5)
			var ty: float = roundf(screen_pos.y)
			hud.draw_rect(Rect2(tx - 5.0, ty - 2.0, tw + 10.0, 9.0), Color(LxPalette.PAL["void"] as Color, col.a))
			hud.draw_rect(Rect2(tx - 4.0, ty - 1.0, tw + 8.0, 7.0), Color(LxPalette.PAL["night"] as Color, col.a))
			hud.draw_rect(Rect2(tx - 3.0, ty + 2.0, 1.0, 1.0), Color(LxPalette.PAL["gold"] as Color, col.a))
			hud.draw_rect(Rect2(tx + tw + 2.0, ty + 2.0, 1.0, 1.0), Color(LxPalette.PAL["gold"] as Color, col.a))
		elif not is_world:
			var tx: float = roundf(screen_pos.x - tw * 0.5)
			var ty: float = roundf(screen_pos.y)
			var pill_col := Color(LxPalette.PAL["void"] as Color, 0.72 * col.a)
			hud.draw_rect(Rect2(tx - 2.0, ty - 2.0, tw + 4.0, 9.0), pill_col)
			hud.draw_rect(Rect2(tx - 3.0, ty - 1.0, 1.0, 7.0), pill_col)
			hud.draw_rect(Rect2(tx + tw + 2.0, ty - 1.0, 1.0, 7.0), pill_col)
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
	if br == null or not is_instance_valid(br):
		return
	var max_h: int = clampi(Lx.state.max_hearts if Lx.state != null else 4, 4, 12)
	var show_h: bool = bool(LxSold.current().get_hud_visibility().get("show_hearts", true))
	var o := Vector2(5.0, LxHudOverlays.compute_left_stack_y(max_h, show_h, true))
	var bg: Color = LxPalette.PAL["void"] as Color
	var night: Color = LxPalette.PAL["night"] as Color
	var bm: LxBiomeMechanics = LxBiomeMechanics.active_instance
	var has_top_badge: bool = false
	match br.island_id:
		1:
			if not br.is_dungeon and LxBellChimes.active_instance != null and is_instance_valid(LxBellChimes.active_instance):
				var rung_n: int = LxBellChimes.active_instance.get_rung_count()
				var tot_n: int = LxBellChimes.active_instance.get_total_count()
				if rung_n > 0 and tot_n > 0:
					has_top_badge = true
					var show_n: int = mini(tot_n, 6)
					for k: int in range(show_n):
						var cx: float = o.x + float(k) * 5.0
						hud.draw_rect(Rect2(cx, o.y, 4.0, 5.0), bg)
						if k < rung_n:
							hud.draw_rect(Rect2(cx + 1.0, o.y + 1.0, 2.0, 3.0), LxPalette.PAL["gold"] as Color)
							hud.draw_rect(Rect2(cx + 1.0, o.y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"] as Color)
						else:
							hud.draw_rect(Rect2(cx + 1.0, o.y + 1.0, 2.0, 3.0), night)
					if rung_n >= tot_n:
						_draw_discovery_crown(hud, Vector2(o.x + float(show_n) * 5.0 + 2.0, o.y + 2.0), LxPalette.PAL["gold"] as Color, blink_t, fred)
		2:
			var has_epic_tide: bool = LxHudOverlays.has_active_island_hud(2)
			if not br.is_dungeon and not has_epic_tide:
				has_top_badge = true
				hud.draw_rect(Rect2(o, Vector2(7.0, 7.0)), bg)
				draw_biome_crest(hud, 2, o + Vector2(3.0, 3.0), LxPalette.PAL["sky"] as Color, LxPalette.PAL["ice"] as Color)
				if br.tide_surging:
					hud.draw_rect(Rect2(o + Vector2(2.0, 1.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
				var bo2: Vector2 = o + Vector2(8.0, 1.0)
				var fill_w: float = floorf(18.0 * clampf(br.tide_phase, 0.0, 1.0))
				hud.draw_rect(Rect2(bo2, Vector2(22.0, 5.0)), bg)
				hud.draw_rect(Rect2(bo2 + Vector2(1.0, 1.0), Vector2(20.0, 3.0)), LxPalette.PAL["dusk"] as Color)
				hud.draw_rect(Rect2(bo2 + Vector2(1.0, 1.0), Vector2(20.0, 1.0)), LxPalette.PAL["mauve"] as Color)
				hud.draw_rect(Rect2(bo2 + Vector2(1.0, 1.0), Vector2(1.0, 3.0)), LxPalette.PAL["mauve"] as Color)
				hud.draw_rect(Rect2(bo2 + Vector2(2.0, 2.0), Vector2(18.0, 1.0)), night)
				var tc: Color = (LxPalette.PAL["ice"] if br.tide_surging else LxPalette.PAL["sky"]) as Color
				if fill_w > 0.0:
					hud.draw_rect(Rect2(bo2 + Vector2(2.0, 2.0), Vector2(fill_w, 1.0)), tc)
			if br.beam_buff_t > 0.0:
				has_top_badge = true
				var fo: Vector2 = (o + Vector2(33.0, 0.0)) if (not br.is_dungeon and not has_epic_tide) else o
				hud.draw_rect(Rect2(fo, Vector2(7.0, 7.0)), bg)
				hud.draw_rect(Rect2(fo + Vector2(2.0, 1.0), Vector2(3.0, 5.0)), LxPalette.PAL["gold"] as Color)
				hud.draw_rect(Rect2(fo + Vector2(1.0, 2.0), Vector2(5.0, 3.0)), LxPalette.PAL["gold"] as Color)
				hud.draw_rect(Rect2(fo + Vector2(3.0, 3.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
		3:
			if not br.is_dungeon:
				var lit_b: int = mini(3, br.get_lit_bloom_count())
				if lit_b > 0:
					has_top_badge = true
					for k: int in range(3):
						var lx: float = o.x + float(k) * 7.0
						hud.draw_rect(Rect2(lx, o.y, 6.0, 6.0), bg)
						if k < lit_b:
							hud.draw_rect(Rect2(lx + 1.0, o.y + 1.0, 4.0, 4.0), LxPalette.PAL["lime"] as Color)
							hud.draw_rect(Rect2(lx + 2.0, o.y + 2.0, 2.0, 2.0), LxPalette.PAL["cream"] as Color)
						else:
							hud.draw_rect(Rect2(lx + 1.0, o.y + 1.0, 4.0, 4.0), LxPalette.PAL["teal"] as Color)
							hud.draw_rect(Rect2(lx + 2.0, o.y + 2.0, 2.0, 2.0), night)
			else:
				has_top_badge = true
				var pulse_s: bool = fred or (int(blink_t * 3.0) % 2 == 0)
				hud.draw_rect(Rect2(o, Vector2(7.0, 7.0)), bg)
				hud.draw_rect(Rect2(o + Vector2(1.0, 1.0), Vector2(5.0, 5.0)), (LxPalette.PAL["jade"] if pulse_s else LxPalette.PAL["teal"]) as Color)
				hud.draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(3.0, 3.0)), LxPalette.PAL["lime"] as Color)
				hud.draw_rect(Rect2(o + Vector2(3.0, 3.0), Vector2.ONE), LxPalette.PAL["gold"] as Color)
		4:
			if bm != null and is_instance_valid(bm) and bm.tailwind_t > 0.0:
				has_top_badge = true
				var tw_w: float = maxf(1.0, floorf(18.0 * clampf(bm.tailwind_t / 2.2, 0.0, 1.0)))
				var half_tw: float = floorf(tw_w * 0.5)
				hud.draw_rect(Rect2(o, Vector2(22.0, 5.0)), bg)
				hud.draw_rect(Rect2(o + Vector2(1.0, 1.0), Vector2(20.0, 3.0)), night)
				if half_tw > 0.0:
					hud.draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(half_tw, 1.0)), LxPalette.PAL["rose"] as Color)
				hud.draw_rect(Rect2(o + Vector2(2.0 + half_tw, 2.0), Vector2(maxf(1.0, tw_w - half_tw), 1.0)), LxPalette.PAL["ice"] as Color)
				hud.draw_rect(Rect2(o + Vector2(2.0 + tw_w - 1.0, 2.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
		5:
			if br.starlight_surge_t > 0.0:
				has_top_badge = true
				var sw: float = floorf(18.0 * clampf(br.starlight_surge_t / 4.0, 0.0, 1.0))
				hud.draw_rect(Rect2(o, Vector2(22.0, 5.0)), bg)
				hud.draw_rect(Rect2(o + Vector2(2.0, 2.0), Vector2(maxf(1.0, sw), 1.0)), LxPalette.PAL["gold"] as Color)
				hud.draw_rect(Rect2(o + Vector2(2.0 + sw - 1.0, 2.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
		6:
			var has_epic_kiln: bool = LxHudOverlays.has_active_island_hud(6)
			if not has_epic_kiln:
				has_top_badge = true
				hud.draw_rect(Rect2(o, Vector2(7.0, 7.0)), bg)
				draw_biome_crest(hud, 6, o + Vector2(3.0, 3.0), LxPalette.PAL["coral"] as Color, LxPalette.PAL["gold"] as Color)
				if br.vent_cycle >= 0.56:
					hud.draw_rect(Rect2(o + Vector2(3.0, 3.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
				var bo6: Vector2 = o + Vector2(8.0, 1.0)
				var vw: float = floorf(18.0 * clampf(br.vent_cycle, 0.0, 1.0))
				hud.draw_rect(Rect2(bo6, Vector2(22.0, 5.0)), bg)
				hud.draw_rect(Rect2(bo6 + Vector2(1.0, 1.0), Vector2(20.0, 3.0)), LxPalette.PAL["dusk"] as Color)
				hud.draw_rect(Rect2(bo6 + Vector2(1.0, 1.0), Vector2(20.0, 1.0)), LxPalette.PAL["mauve"] as Color)
				hud.draw_rect(Rect2(bo6 + Vector2(1.0, 1.0), Vector2(1.0, 3.0)), LxPalette.PAL["mauve"] as Color)
				hud.draw_rect(Rect2(bo6 + Vector2(2.0, 2.0), Vector2(18.0, 1.0)), night)
				var vc: Color = (LxPalette.PAL["gold"] if br.vent_cycle >= 0.56 else LxPalette.PAL["coral"]) as Color
				if vw > 0.0:
					hud.draw_rect(Rect2(bo6 + Vector2(2.0, 2.0), Vector2(vw, 1.0)), vc)
			if bm != null and is_instance_valid(bm) and bm.molten_charges > 0:
				has_top_badge = true
				var mx0: float = o.x if has_epic_kiln else (o.x + 33.0)
				for k: int in range(bm.molten_charges):
					var px: float = mx0 + float(k) * 5.0
					hud.draw_rect(Rect2(px, o.y + 1.0, 4.0, 5.0), bg)
					hud.draw_rect(Rect2(px + 1.0, o.y + 2.0, 2.0, 3.0), LxPalette.PAL["coral"] as Color)
					hud.draw_rect(Rect2(px + 1.0, o.y + 2.0, 1.0, 1.0), LxPalette.PAL["cream"] as Color)
		7:
			has_top_badge = true
			var m: Vector2 = o + Vector2(1.0, 1.0)
			# Rounded 9x9 void backing behind sculpted 7x7 circular moon disk
			hud.draw_rect(Rect2(o + Vector2(2.0, 0.0), Vector2(5.0, 9.0)), bg)
			hud.draw_rect(Rect2(o + Vector2(1.0, 1.0), Vector2(7.0, 7.0)), bg)
			hud.draw_rect(Rect2(o + Vector2(0.0, 2.0), Vector2(9.0, 5.0)), bg)
			var full_m: bool = br.lunar_phase > 0.5
			var rim_c: Color = (LxPalette.PAL["sky"] if full_m else LxPalette.PAL["plum"]) as Color
			hud.draw_rect(Rect2(m + Vector2(2.0, 0.0), Vector2(3.0, 7.0)), rim_c)
			hud.draw_rect(Rect2(m + Vector2(1.0, 1.0), Vector2(5.0, 5.0)), rim_c)
			hud.draw_rect(Rect2(m + Vector2(0.0, 2.0), Vector2(7.0, 3.0)), rim_c)
			var body_c: Color = (LxPalette.PAL["ice"] if full_m else night) as Color
			hud.draw_rect(Rect2(m + Vector2(2.0, 1.0), Vector2(3.0, 5.0)), body_c)
			hud.draw_rect(Rect2(m + Vector2(1.0, 2.0), Vector2(5.0, 3.0)), body_c)
			if full_m:
				hud.draw_rect(Rect2(m + Vector2(2.0, 1.0), Vector2(2.0, 1.0)), LxPalette.PAL["cream"] as Color)
				hud.draw_rect(Rect2(m + Vector2(1.0, 2.0), Vector2(2.0, 1.0)), LxPalette.PAL["cream"] as Color)
				hud.draw_rect(Rect2(m + Vector2(1.0, 3.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
				hud.draw_rect(Rect2(m + Vector2(4.0, 3.0), Vector2.ONE), LxPalette.PAL["dusk"] as Color)
				hud.draw_rect(Rect2(m + Vector2(3.0, 5.0), Vector2.ONE), LxPalette.PAL["dusk"] as Color)
			else:
				hud.draw_rect(Rect2(m + Vector2(2.0, 0.0), Vector2.ONE), LxPalette.PAL["sky"] as Color)
				hud.draw_rect(Rect2(m + Vector2(1.0, 1.0), Vector2.ONE), LxPalette.PAL["sky"] as Color)
				hud.draw_rect(Rect2(m + Vector2(0.0, 2.0), Vector2(1.0, 3.0)), LxPalette.PAL["sky"] as Color)
				hud.draw_rect(Rect2(m + Vector2(1.0, 5.0), Vector2.ONE), LxPalette.PAL["sky"] as Color)
				hud.draw_rect(Rect2(m + Vector2(2.0, 6.0), Vector2.ONE), LxPalette.PAL["sky"] as Color)
				hud.draw_rect(Rect2(m + Vector2(2.0, 1.0), Vector2.ONE), LxPalette.PAL["ice"] as Color)
				hud.draw_rect(Rect2(m + Vector2(1.0, 2.0), Vector2(1.0, 3.0)), LxPalette.PAL["ice"] as Color)
				hud.draw_rect(Rect2(m + Vector2(2.0, 5.0), Vector2.ONE), LxPalette.PAL["ice"] as Color)
				hud.draw_rect(Rect2(m + Vector2(1.0, 2.0), Vector2(1.0, 2.0)), LxPalette.PAL["cream"] as Color)
			if bm != null and is_instance_valid(bm) and bm.mirror_echo_active:
				var sc: Vector2 = o + Vector2(13.0, 4.0)
				hud.draw_rect(Rect2(sc + Vector2(-1.0, -3.0), Vector2(3.0, 7.0)), bg)
				hud.draw_rect(Rect2(sc + Vector2(-3.0, -1.0), Vector2(7.0, 3.0)), bg)
				hud.draw_rect(Rect2(sc + Vector2(-2.0, -2.0), Vector2(5.0, 5.0)), bg)
				hud.draw_rect(Rect2(sc + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), LxPalette.PAL["sky"] as Color)
				hud.draw_rect(Rect2(sc + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), LxPalette.PAL["ice"] as Color)
				hud.draw_rect(Rect2(sc + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), LxPalette.PAL["ice"] as Color)
				hud.draw_rect(Rect2(sc + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), LxPalette.PAL["cream"] as Color)
				hud.draw_rect(Rect2(sc + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), LxPalette.PAL["cream"] as Color)
		8:
			has_top_badge = true
			var seals_b: int = bm.dawn_seals_broken if (bm != null and is_instance_valid(bm)) else 0
			var pulse_on: bool = fred or (int(blink_t * 4.0) % 2 == 0)
			for k: int in range(3):
				var so := Vector2(o.x + float(k) * 9.0, o.y)
				var dm: Vector2 = so + Vector2(1.0, 1.0)
				hud.draw_rect(Rect2(so + Vector2(3.0, 0.0), Vector2(3.0, 9.0)), bg)
				hud.draw_rect(Rect2(so + Vector2(2.0, 1.0), Vector2(5.0, 7.0)), bg)
				hud.draw_rect(Rect2(so + Vector2(1.0, 2.0), Vector2(7.0, 5.0)), bg)
				hud.draw_rect(Rect2(so + Vector2(0.0, 3.0), Vector2(9.0, 3.0)), bg)
				var broken: bool = k < seals_b
				var rim_d: Color = (LxPalette.PAL["gold"] if broken else (LxPalette.PAL["rose"] if pulse_on else LxPalette.PAL["plum"])) as Color
				hud.draw_rect(Rect2(dm + Vector2(3.0, 0.0), Vector2(1.0, 7.0)), rim_d)
				hud.draw_rect(Rect2(dm + Vector2(2.0, 1.0), Vector2(3.0, 5.0)), rim_d)
				hud.draw_rect(Rect2(dm + Vector2(1.0, 2.0), Vector2(5.0, 3.0)), rim_d)
				hud.draw_rect(Rect2(dm + Vector2(0.0, 3.0), Vector2(7.0, 1.0)), rim_d)
				if broken:
					hud.draw_rect(Rect2(dm + Vector2(3.0, 2.0), Vector2(1.0, 3.0)), LxPalette.PAL["cream"] as Color)
					hud.draw_rect(Rect2(dm + Vector2(2.0, 3.0), Vector2(3.0, 1.0)), LxPalette.PAL["cream"] as Color)
					hud.draw_rect(Rect2(dm + Vector2(2.0, 1.0), Vector2.ONE), LxPalette.PAL["cream"] as Color)
				else:
					hud.draw_rect(Rect2(dm + Vector2(3.0, 1.0), Vector2(1.0, 5.0)), night)
					hud.draw_rect(Rect2(dm + Vector2(2.0, 2.0), Vector2(3.0, 3.0)), night)
					hud.draw_rect(Rect2(dm + Vector2(1.0, 3.0), Vector2(5.0, 1.0)), night)
					hud.draw_rect(Rect2(dm + Vector2(3.0, 3.0), Vector2.ONE), bg)
	# Compact overworld micro-discovery pips (Islands 2..8) once at least 1 toy is discovered
	if not br.is_dungeon and br.island_id >= 2 and LxBiomeDiscoveries.active_instance != null and is_instance_valid(LxBiomeDiscoveries.active_instance):
		var found_d: int = LxBiomeDiscoveries.active_instance.get_found_count()
		var tot_d: int = LxBiomeDiscoveries.active_instance.get_total_count()
		if found_d > 0 and tot_d > 0:
			var dy: float = (o.y + (10.0 if (br.island_id == 7 or br.island_id == 8) else (8.0 if (br.island_id == 2 or br.island_id == 6) else 7.0))) if has_top_badge else o.y
			var d_col: Color = LxBiomePalette.col(br.island_id, "glow")
			var show_d: int = mini(tot_d, 5)
			for k: int in range(show_d):
				var dx: float = o.x + float(k) * 5.0
				hud.draw_rect(Rect2(dx, dy, 4.0, 4.0), bg)
				if k < found_d:
					hud.draw_rect(Rect2(dx + 1.0, dy + 1.0, 2.0, 2.0), d_col)
					hud.draw_rect(Rect2(dx + 1.0, dy + 1.0, 1.0, 1.0), LxPalette.PAL["cream"] as Color)
				else:
					hud.draw_rect(Rect2(dx + 1.0, dy + 1.0, 2.0, 2.0), night)
			if found_d >= tot_d:
				_draw_discovery_crown(hud, Vector2(o.x + float(show_d) * 5.0 + 2.0, dy + 2.0), d_col, blink_t, fred)


static func _draw_discovery_crown(hud: CanvasItem, center: Vector2, col: Color, blink_t: float, fred: bool) -> void:
	var c: Vector2 = center.round()
	var pulse: bool = fred or (int(blink_t * 4.5) % 2 == 0)
	hud.draw_rect(Rect2(c + Vector2(-2.0, -2.0), Vector2(5.0, 5.0)), LxPalette.PAL["void"] as Color)
	hud.draw_rect(Rect2(c + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), col)
	hud.draw_rect(Rect2(c + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), col)
	hud.draw_rect(Rect2(c, Vector2.ONE), (LxPalette.PAL["cream"] if pulse else LxPalette.PAL["gold"]) as Color)


static func _draw_ember_ready_halo(hud: CanvasItem, blink_t: float, fred: bool) -> void:
	if Lx.state == null or not Lx.state.has_move("sunflare"):
		return
	if Lx.player == null or not is_instance_valid(Lx.player) or not Lx.player.has_method("get_ember_ratio"):
		return
	if float(Lx.player.call("get_ember_ratio")) < 0.999:
		return
	var pulse: bool = fred or (int(blink_t * 6.0) % 2 == 0)
	var isl_e: int = Lx.state.island_id if Lx.state != null else 1
	var hi: Color = (LxPalette.PAL["cream"] if pulse else LxPalette.PAL["gold"]) as Color
	var warm: Color = LxBiomePalette.col(isl_e, "glow")
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
	var isl_c: int = Lx.state.island_id if Lx.state != null else 1
	var rim: Color = (LxPalette.PAL["coral"] as Color) if stolen else LxBiomePalette.col(isl_c, "glow")
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
	var isl_b: int = Lx.state.island_id if Lx.state != null else 1
	var b_glow: Color = LxBiomePalette.col(isl_b, "glow")
	var col: Color = (LxPalette.PAL["coral"] as Color) if phase >= 3 else b_glow
	var hi: Color = (LxPalette.PAL["cream"] as Color) if lit else col
	for side: float in [-1.0, 1.0]:
		var px: float = roundf(160.0 + side * 86.0)
		var py: float = 152.0
		hud.draw_rect(Rect2(px - 1.0, py - 1.0, 3.0, 3.0), LxPalette.PAL["void"] as Color)
		hud.draw_rect(Rect2(px, py, 1.0, 1.0), hi)
		hud.draw_rect(Rect2(px + side * 2.0, py, 2.0, 1.0), col)
		if not fred:
			var u_b: float = fmod(blink_t * (1.25 if phase >= 3 else 0.85) + (0.0 if side < 0.0 else 0.5), 1.0)
			var sy_b: float = roundf(py - 2.0 - u_b * 7.0)
			var sx_b: float = roundf(px + side * (1.0 + sin(blink_t * 4.0 + side) * 1.5))
			hud.draw_rect(Rect2(sx_b, sy_b, 1.0, 1.0), (LxPalette.PAL["cream"] as Color) if u_b < 0.35 else b_glow)
	# Crisp 2 px crimson-gold pulsing screen-corner rim vignette (4 L-brackets)
	var p_v: float = 0.45 if fred else (0.55 + 0.45 * sin(blink_t * (7.2 if phase >= 3 else 5.0)))
	var arm_h: float = 22.0 if phase >= 3 else 18.0
	var arm_v: float = 16.0 if phase >= 3 else 14.0
	var out_c := Color(LxPalette.PAL["coral"] as Color, 0.55 if fred else (0.65 + 0.30 * p_v))
	var in_c := Color(LxPalette.PAL["gold"] as Color, 0.48 if fred else (0.55 + 0.35 * p_v))
	for c: Vector2 in [Vector2(0.0, 0.0), Vector2(320.0, 0.0), Vector2(0.0, 180.0), Vector2(320.0, 180.0)]:
		var left: bool = c.x < 160.0
		var top: bool = c.y < 90.0
		hud.draw_rect(Rect2(0.0 if left else 320.0 - arm_h, 0.0 if top else 179.0, arm_h, 1.0), out_c)
		hud.draw_rect(Rect2(1.0 if left else 322.0 - arm_h, 1.0 if top else 178.0, arm_h - 3.0, 1.0), in_c)
		hud.draw_rect(Rect2(0.0 if left else 319.0, 0.0 if top else 180.0 - arm_v, 1.0, arm_v), out_c)
		hud.draw_rect(Rect2(1.0 if left else 318.0, 1.0 if top else 182.0 - arm_v, 1.0, arm_v - 3.0), in_c)
		if lit:
			hud.draw_rect(Rect2(1.0 if left else 318.0, 1.0 if top else 178.0, 1.0, 1.0), LxPalette.PAL["cream"] as Color)


static func draw_boss_biome_header(hud: CanvasItem, island_id: int, name_w: float, bar_x: float, bar_y: float, bar_w: float, phase: int) -> void:
	var pri: Color = LxBiomePalette.col(island_id, "hi")
	var glow: Color = LxBiomePalette.col(island_id, "glow")
	var cream: Color = LxPalette.PAL["cream"] as Color
	var half: float = floorf(name_w * 0.5) + 7.0
	var lx: float = maxf(bar_x + 3.0, 160.0 - half)
	draw_biome_crest(hud, island_id, Vector2(lx, bar_y - 6.0), pri, cream)
	if phase < 2 or (160.0 + half) < (bar_x + bar_w - 22.0):
		var rx: float = minf(bar_x + bar_w - 4.0, 160.0 + half)
		draw_biome_crest(hud, island_id, Vector2(rx, bar_y - 6.0), pri, cream)
	# Subtle biome-tinted outer gem tips on the boss bar brass endcaps
	hud.draw_rect(Rect2(bar_x - 2.0, bar_y + 3.0, 1.0, 2.0), glow)
	hud.draw_rect(Rect2(bar_x + bar_w + 1.0, bar_y + 3.0, 1.0, 2.0), glow)


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
