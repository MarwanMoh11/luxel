class_name LxHubStation
extends LxInteractable
## Upgraded Wick House interactive stations (kind "hub_station"):
## Roles: moth_lantern, music_box, rematch_mirror, lead_forge, tailor_loom,
## journal_desk, pane_workbench, return_jetty.

var station_role: String = "moth_lantern"
var _pulse_t: float = 0.0
var _moth_phase: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "hub_station"
	radius = maxf(16.0, radius)
	station_role = str(props.get("role", props.get("station_role", "moth_lantern"))).strip_edges().to_lower()
	queue_redraw()


func get_interact_prompt() -> String:
	match station_role:
		"moth_lantern": return "PROMPT_MOTH_LANTERN"
		"music_box": return "PROMPT_MUSIC_BOX"
		"rematch_mirror": return "PROMPT_HUB_REMATCH"
		"lead_forge": return "PROMPT_HUB_LEAD_FORGE"
		"tailor_loom": return "PROMPT_HUB_TAILOR"
		"journal_desk": return "PROMPT_JOURNAL"
		"pane_workbench": return "PROMPT_PANE_WORKSHOP"
		"return_jetty": return "PROMPT_RETURN_ISLANDS"
		_: return "PROMPT_TALK"


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_pulse_t = 0.52
	match station_role:
		"moth_lantern":
			var host: LxHubMenuHost = LxHubMenuHost.ensure()
			if host != null:
				host.open_moth_ceremony()
		"music_box":
			var host_m: LxHubMenuHost = LxHubMenuHost.ensure()
			if host_m != null:
				host_m.open_music_box()
		"rematch_mirror":
			var host_r: LxHubMenuHost = LxHubMenuHost.ensure()
			if host_r != null:
				host_r.open_rematch()
		"lead_forge":
			var host_l: LxHubMenuHost = LxHubMenuHost.ensure()
			if host_l != null:
				host_l.open_lead_shop()
		"tailor_loom":
			var host_t: LxHubMenuHost = LxHubMenuHost.ensure()
			if host_t != null:
				host_t.open_tailor()
		"journal_desk":
			_emit_sfx("menu_open")
			if Lx.ui != null and Lx.ui.has_method("show_journal"):
				Lx.ui.call("show_journal", LxUiRoot.Screen.HUD)
		"pane_workbench":
			_emit_sfx("menu_open")
			if Lx.ui != null and Lx.ui.has_method("open_panes_menu"):
				Lx.ui.call("open_panes_menu")
		"return_jetty":
			_emit_sfx("waystone_warp")
			LxHubTravel.return_from_hub()
		_:
			return false
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	_moth_phase += dt
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()
	elif station_role in ["moth_lantern", "rematch_mirror", "tailor_loom", "music_box"]:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	match station_role:
		"moth_lantern":
			var mc: int = LxQuests.current().get_moth_count()
			return Vector4(pos.x, pos.y - 12.0, 56.0 + float(mini(mc, 80)) * 0.7, 1.2)
		"rematch_mirror":
			return Vector4(pos.x, pos.y - 14.0, 52.0, 0.9)
		"lead_forge", "pane_workbench":
			return Vector4(pos.x, pos.y - 8.0, 48.0, 0.9)
		"tailor_loom":
			return Vector4(pos.x, pos.y - 10.0, 44.0, 0.85)
		_:
			return Vector4(pos.x, pos.y - 8.0, 36.0, 0.65)


func _draw() -> void:
	if not active:
		return
	_draw_ground_shadow(11.0, 3.5, Vector2(0.0, 2.0))
	match station_role:
		"moth_lantern": _draw_moth_lantern()
		"rematch_mirror": _draw_rematch_mirror()
		"music_box": _draw_music_box()
		"lead_forge": _draw_lead_forge()
		"tailor_loom": _draw_tailor_loom()
		"pane_workbench": _draw_pane_bench()
		"journal_desk": _draw_journal_desk()
		_: _draw_jetty_post()
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.52, 0.0, 1.0)
		draw_arc(Vector2(0.0, -10.0), roundf(6.0 + u * 22.0), 0.0, TAU, 16, LxPalette.PAL["gold"], 1.0)


func _draw_moth_lantern() -> void:
	var mc: int = LxQuests.current().get_moth_count()
	draw_rect(Rect2(-11.0, -4.0, 22.0, 6.0), LxPalette.PAL["void"])
	draw_rect(Rect2(-10.0, -3.0, 20.0, 4.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(-7.0, -26.0, 14.0, 23.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-6.0, -25.0, 12.0, 21.0), LxPalette.PAL["gold"] if mc >= 5 else LxPalette.PAL["plum"])
	draw_rect(Rect2(-4.0, -23.0, 8.0, 17.0), LxPalette.PAL["cream"] if mc >= 20 else LxPalette.PAL["apricot"])
	draw_rect(Rect2(-8.0, -28.0, 16.0, 3.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(-3.0, -30.0, 6.0, 2.0), LxPalette.PAL["gold"])
	LxBubble.draw_icon(self, "moth", Vector2(-4.0, -19.0), 1.0)
	# Orbiting caught moths around the lantern (up to 16 visible)
	var orbit_n: int = mini(mc, 16)
	var fred: bool = LxHudFx.flash_reduced()
	for i: int in range(orbit_n):
		var ang: float = (_moth_phase * (0.4 if fred else 1.25)) + float(i) * (TAU / float(maxi(1, orbit_n)))
		var rad: float = 13.0 + float(i % 3) * 4.0
		var mp := Vector2(roundf(cos(ang) * rad), roundf(-16.0 + sin(ang) * rad * 0.5))
		draw_rect(Rect2(mp, Vector2(2.0, 1.0)), LxPalette.PAL["cream"] if i % 2 == 0 else LxPalette.PAL["gold"])
	# 7 Tier pips (5/10/20/35/50/65/80)
	for ti: int in range(LxQuests.MOTH_TIERS.size()):
		var reached: bool = mc >= LxQuests.MOTH_TIERS[ti]
		var claimed: bool = LxQuests.current().is_moth_tier_claimed(LxQuests.MOTH_TIERS[ti])
		var tc: Color = LxPalette.PAL["lime"] if claimed else (LxPalette.PAL["gold"] if reached else LxPalette.PAL["dusk"])
		draw_rect(Rect2(-10.0 + float(ti * 3), 3.0, 2.0, 2.0), tc)


func _draw_rematch_mirror() -> void:
	draw_rect(Rect2(-11.0, -28.0, 22.0, 30.0), LxPalette.PAL["void"])
	draw_rect(Rect2(-10.0, -27.0, 20.0, 28.0), LxPalette.PAL["blue"])
	draw_rect(Rect2(-8.0, -25.0, 16.0, 24.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-7.0, -24.0, 14.0, 22.0), LxPalette.PAL["deep"])
	var shimmer: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_moth_phase * 2.2) * 3.0)
	draw_rect(Rect2(-6.0, -20.0 + shimmer, 12.0, 2.0), LxPalette.PAL["ice"])
	draw_rect(Rect2(-5.0, -14.0 - shimmer, 10.0, 1.0), LxPalette.PAL["sky"])
	draw_rect(Rect2(-9.0, -27.0, 18.0, 2.0), LxPalette.PAL["ice"])
	LxBubble.draw_icon(self, "crown", Vector2(-4.0, -17.0), 1.0)


func _draw_music_box() -> void:
	draw_rect(Rect2(-8.0, -12.0, 16.0, 14.0), LxPalette.PAL["void"])
	draw_rect(Rect2(-7.0, -11.0, 14.0, 12.0), LxPalette.PAL["wine"])
	draw_rect(Rect2(-6.0, -10.0, 12.0, 4.0), LxPalette.PAL["gold"])
	# Brass horn
	draw_rect(Rect2(2.0, -18.0, 5.0, 6.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(4.0, -20.0, 4.0, 3.0), LxPalette.PAL["gold"])
	LxBubble.draw_icon(self, "music", Vector2(-6.0, -22.0), 1.0)


func _draw_lead_forge() -> void:
	draw_rect(Rect2(-12.0, -12.0, 24.0, 14.0), LxPalette.PAL["void"])
	draw_rect(Rect2(-11.0, -11.0, 22.0, 12.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(-9.0, -9.0, 8.0, 6.0), LxPalette.PAL["coral"])
	draw_rect(Rect2(-8.0, -8.0, 6.0, 4.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(2.0, -10.0, 8.0, 7.0), LxPalette.PAL["stone"])
	draw_rect(Rect2(3.0, -9.0, 6.0, 2.0), LxPalette.PAL["cream"])
	LxBubble.draw_icon(self, "ember", Vector2(-4.0, -20.0), 1.0)


func _draw_tailor_loom() -> void:
	var fid: String = LxHubState.get_equipped_flame()
	draw_rect(Rect2(-11.0, -22.0, 22.0, 24.0), LxPalette.PAL["void"])
	draw_rect(Rect2(-10.0, -21.0, 20.0, 22.0), LxPalette.PAL["plum"])
	draw_rect(Rect2(-8.0, -19.0, 16.0, 16.0), LxPalette.PAL["night"])
	# Hanging dyed silk threads in Last Light flame colours
	var cols: Array[String] = ["gold", "coral", "rose", "lime", "sky", "ice"]
	for i: int in range(cols.size()):
		draw_rect(Rect2(-6.0 + float(i * 2), -17.0, 2.0, 12.0), LxPalette.color(cols[i], "gold"))
	draw_rect(Rect2(-3.0, -9.0, 6.0, 6.0), LxPalette.color(fid, "gold"))
	LxBubble.draw_icon(self, "flame", Vector2(-4.0, -29.0), 1.0)


func _draw_pane_bench() -> void:
	draw_rect(Rect2(-12.0, -10.0, 24.0, 12.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-11.0, -9.0, 22.0, 10.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(-11.0, -9.0, 22.0, 3.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(-8.0, -16.0, 16.0, 7.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-7.0, -15.0, 4.0, 5.0), LxPalette.PAL["coral"])
	draw_rect(Rect2(-2.0, -15.0, 4.0, 5.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(3.0, -15.0, 4.0, 5.0), LxPalette.PAL["sky"])
	LxBubble.draw_icon(self, "pane", Vector2(-4.0, -6.0), 1.0)


func _draw_journal_desk() -> void:
	draw_rect(Rect2(-9.0, -12.0, 18.0, 14.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-8.0, -11.0, 16.0, 11.0), LxPalette.PAL["plum"])
	draw_rect(Rect2(-7.0, -10.0, 14.0, 7.0), LxPalette.PAL["cream"])
	draw_rect(Rect2(-1.0, -10.0, 2.0, 7.0), LxPalette.PAL["mauve"])
	LxBubble.draw_icon(self, "book", Vector2(-4.0, -19.0), 1.0)


func _draw_jetty_post() -> void:
	draw_rect(Rect2(-9.0, -18.0, 18.0, 20.0), LxPalette.PAL["void"])
	draw_rect(Rect2(-8.0, -17.0, 16.0, 18.0), LxPalette.PAL["teal"])
	draw_rect(Rect2(-6.0, -15.0, 12.0, 14.0), LxPalette.PAL["night"])
	LxBubble.draw_icon(self, "toy_skiff", Vector2(-4.0, -12.0), 1.0)
