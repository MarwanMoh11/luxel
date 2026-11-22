class_name LxHudFx
extends RefCounted
## Diegetic HUD edge indicators (off-screen stolen/hung lantern compass)
## and Boss Phase escalation filigree on the boss bar.
## Uses strictly the 20 opaque Last Light colours (LxPalette.PAL).


static func flash_reduced() -> bool:
	return Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))


static func shake_enabled() -> bool:
	return Lx.save == null or float(Lx.save.settings.get("screen_shake", 1.0)) > 0.01


static func draw_indicators(hud: CanvasItem, blink_t: float, boss_active: bool, boss_phase: int) -> void:
	var fred: bool = flash_reduced()
	_draw_lantern_edge_compass(hud, blink_t, fred)
	_draw_counter_ready_halo(hud, blink_t, fred)
	if boss_active and boss_phase >= 2:
		_draw_boss_phase_filigree(hud, blink_t, boss_phase, fred)


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
