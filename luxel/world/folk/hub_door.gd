class_name LxHubDoor
extends LxInteractable
## Wick House Hub station & door interactable (kind "hub_door").
## Roles: moth_lantern, pane_workshop, journal_desk, music_box, gallery, race, rematch, return_waystone.

const MUSIC_TRACKS: PackedStringArray = [
	"hub", "explore", "island1_dungeon", "island1_boss_p1", "title", "ending_dawn",
]

var door_role: String = "gallery"
var _pulse_t: float = 0.0
var _music_idx: int = 0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "hub_door"
	radius = maxf(16.0, radius)
	door_role = str(props.get("door_role", props.get("role", "gallery")))
	queue_redraw()


func get_interact_prompt() -> String:
	match door_role:
		"moth_lantern": return "PROMPT_MOTH_LANTERN"
		"pane_workshop": return "PROMPT_PANE_WORKSHOP"
		"journal_desk": return "PROMPT_JOURNAL"
		"music_box": return "PROMPT_MUSIC_BOX"
		"gallery": return "PROMPT_HUB_GALLERY"
		"race": return "PROMPT_HUB_RACE"
		"rematch": return "PROMPT_HUB_REMATCH"
		"return_waystone": return "PROMPT_RETURN_ISLANDS"
		_: return "PROMPT_TALK"


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_pulse_t = 0.48
	match door_role:
		"moth_lantern":
			var claimed: Dictionary = LxQuests.current().claim_next_moth_tier()
			if not claimed.is_empty():
				_emit_sfx("shrine_unlock")
				if Lx.events != null:
					Lx.events.narration_requested.emit(str(claimed.get("cue_key", "MOTH_REWARD_CLAIMED")), "title", 3.0)
			else:
				_emit_sfx("ui_move")
				if Lx.events != null:
					Lx.events.narration_requested.emit("MOTH_LANTERN_INFO", "narration", 2.4)
		"pane_workshop":
			_emit_sfx("menu_open")
			if Lx.ui != null and Lx.ui.has_method("open_panes_menu"):
				Lx.ui.call("open_panes_menu")
		"journal_desk":
			_emit_sfx("menu_open")
			if Lx.ui != null and Lx.ui.has_method("show_journal"):
				Lx.ui.call("show_journal", LxUiRoot.Screen.HUD)
		"music_box":
			_music_idx = (_music_idx + 1) % MUSIC_TRACKS.size()
			var cue: String = MUSIC_TRACKS[_music_idx]
			if Lx.state != null:
				Lx.state.story_flags["hub:music_track"] = cue
			if Lx.audio != null:
				Lx.audio.play_cue(cue)
			_emit_sfx("ui_confirm")
			if Lx.events != null:
				Lx.events.narration_requested.emit("HUB_MUSIC_NEXT", "narration", 2.0)
		"return_waystone":
			_emit_sfx("waystone_warp")
			LxHubTravel.return_from_hub()
		_:
			# Gallery / Race / Rematch doors: shell present now, minigames unlocked in later waves
			_emit_sfx("ui_move")
			if Lx.events != null:
				Lx.events.narration_requested.emit("HUB_DOOR_SOON", "narration", 2.4)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if door_role == "moth_lantern":
		var mc: int = LxQuests.current().get_moth_count()
		return Vector4(pos.x, pos.y - 12.0, 52.0 + float(mini(mc, 80)) * 0.65, 1.15)
	if door_role == "pane_workshop":
		return Vector4(pos.x, pos.y - 8.0, 44.0, 0.85)
	return Vector4(pos.x, pos.y - 8.0, 32.0, 0.55)


func _draw() -> void:
	_draw_ground_shadow(11.0, 3.5, Vector2(0.0, 2.0))
	match door_role:
		"moth_lantern": _draw_moth_lantern()
		"pane_workshop": _draw_pane_workshop()
		"journal_desk": _draw_journal_desk()
		"music_box": _draw_music_box()
		"rematch": _draw_arch_door("crown", "ice", "blue")
		"race": _draw_arch_door("toy_skiff", "sky", "teal")
		"gallery": _draw_arch_door("move_bolt", "gold", "coral")
		_: _draw_arch_door("home", "gold", "plum")
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.48, 0.0, 1.0)
		draw_arc(Vector2(0.0, -10.0), roundf(6.0 + u * 22.0), 0.0, TAU, 16, LxPalette.PAL["gold"], 1.0)


func _draw_moth_lantern() -> void:
	var mc: int = LxQuests.current().get_moth_count()
	draw_rect(Rect2(-9.0, -4.0, 18.0, 6.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-8.0, -3.0, 16.0, 4.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(-6.0, -22.0, 12.0, 19.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-5.0, -21.0, 10.0, 17.0), LxPalette.PAL["gold"] if mc >= 5 else LxPalette.PAL["plum"])
	draw_rect(Rect2(-3.0, -19.0, 6.0, 13.0), LxPalette.PAL["cream"] if mc >= 20 else LxPalette.PAL["apricot"])
	draw_rect(Rect2(-7.0, -24.0, 14.0, 3.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(-3.0, -26.0, 6.0, 2.0), LxPalette.PAL["gold"])
	LxBubble.draw_icon(self, "moth", Vector2(-4.0, -17.0), 1.0)
	# Tier progress bar (7 pips for 5/10/20/35/50/65/80)
	for i: int in range(LxQuests.MOTH_TIERS.size()):
		var reached: bool = mc >= LxQuests.MOTH_TIERS[i]
		draw_rect(Rect2(-10.0 + float(i * 3), 3.0, 2.0, 2.0), LxPalette.PAL["gold"] if reached else LxPalette.PAL["dusk"])


func _draw_pane_workshop() -> void:
	draw_rect(Rect2(-11.0, -10.0, 22.0, 12.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-10.0, -9.0, 20.0, 10.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(-10.0, -9.0, 20.0, 3.0), LxPalette.PAL["apricot"])
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
	LxBubble.draw_icon(self, "book", Vector2(-4.0, -18.0), 1.0)


func _draw_music_box() -> void:
	draw_rect(Rect2(-7.0, -10.0, 14.0, 12.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-6.0, -9.0, 12.0, 10.0), LxPalette.PAL["wine"])
	draw_rect(Rect2(-5.0, -8.0, 10.0, 3.0), LxPalette.PAL["gold"])
	LxBubble.draw_icon(self, "music", Vector2(-4.0, -18.0), 1.0)


func _draw_arch_door(icon_name: String, hi_key: String, mid_key: String) -> void:
	draw_rect(Rect2(-10.0, -24.0, 20.0, 26.0), LxPalette.PAL["void"])
	draw_rect(Rect2(-9.0, -23.0, 18.0, 24.0), LxPalette.color(mid_key))
	draw_rect(Rect2(-7.0, -21.0, 14.0, 22.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-6.0, -20.0, 12.0, 20.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(-8.0, -23.0, 16.0, 2.0), LxPalette.color(hi_key))
	LxBubble.draw_icon(self, icon_name, Vector2(-4.0, -16.0), 1.0)
