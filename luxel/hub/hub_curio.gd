class_name LxHubCurio
extends LxInteractable
## Small corner interactions in Wick House (kind "hub_curio"):
## Gives every corner of every room a tactile micro-interaction (visual reaction, SFX, and short cue).

const CURIO_META: Dictionary = {
	"kettle": {"sfx": "switch_on", "cue": "HUB_CURIO_KETTLE", "light": 34.0, "color": "apricot"},
	"telescope": {"sfx": "ui_confirm", "cue": "HUB_CURIO_TELESCOPE", "light": 36.0, "color": "ice"},
	"moth_jar": {"sfx": "prop_chime", "cue": "HUB_CURIO_MOTH_JAR", "light": 40.0, "color": "gold"},
	"ship_bottle": {"sfx": "harbor_creak", "cue": "HUB_CURIO_SHIP", "light": 24.0, "color": "sky"},
	"herb_pot": {"sfx": "bush_rustle", "cue": "HUB_CURIO_HERBS", "light": 22.0, "color": "lime"},
	"star_chart": {"sfx": "ui_move", "cue": "HUB_CURIO_CHART", "light": 28.0, "color": "sky"},
	"anvil_spark": {"sfx": "shield_clang", "cue": "HUB_CURIO_ANVIL", "light": 36.0, "color": "coral"},
	"trophy_rack": {"sfx": "prop_chime", "cue": "HUB_CURIO_TROPHY", "light": 32.0, "color": "gold"},
	"cellar_cask": {"sfx": "footstep_wood", "cue": "HUB_CURIO_CASK", "light": 0.0, "color": "apricot"},
	"chime_rack": {"sfx": "prop_chime", "cue": "HUB_CURIO_CHIMES", "light": 28.0, "color": "gold"},
	"hearth_fire": {"sfx": "brazier_lit", "cue": "HUB_CURIO_HEARTH", "light": 62.0, "color": "coral"},
	"tally_board": {"sfx": "ui_move", "cue": "HUB_CURIO_TALLY", "light": 20.0, "color": "cream"},
	"pond_lantern": {"sfx": "tide_wave", "cue": "HUB_CURIO_POND", "light": 44.0, "color": "gold"},
	"old_trunk": {"sfx": "chest_open", "cue": "HUB_CURIO_TRUNK", "light": 0.0, "color": "plum"},
	"porch_bell": {"sfx": "prop_chime", "cue": "HUB_CURIO_PORCH_BELL", "light": 32.0, "color": "gold"},
	"weathervane": {"sfx": "dash_whoosh", "cue": "HUB_CURIO_VANE", "light": 26.0, "color": "ice"},
}

var curio_kind: String = "kettle"
var custom_cue: String = ""
var uses: int = 0
var _react_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "hub_curio"
	radius = maxf(13.0, radius)
	curio_kind = str(props.get("curio", props.get("curio_kind", "kettle"))).strip_edges().to_lower()
	if not CURIO_META.has(curio_kind):
		curio_kind = "kettle"
	custom_cue = str(props.get("string_id", ""))
	queue_redraw()


func get_interact_prompt() -> String:
	return "PROMPT_HUB_INSPECT"


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	uses += 1
	_react_t = 0.85
	var meta: Dictionary = CURIO_META[curio_kind] as Dictionary
	_emit_sfx(str(meta.get("sfx", "ui_move")))
	var cue_id: String = custom_cue if not custom_cue.is_empty() else str(meta.get("cue", "HUB_CURIO_KETTLE"))
	if Lx.events != null and LxStrings.has_id(cue_id):
		Lx.events.narration_requested.emit(cue_id, "narration", 2.4)
	queue_redraw()
	return true


func on_hit(hit: LxHit) -> bool:
	if not active or hit == null:
		return false
	if curio_kind in ["chime_rack", "porch_bell", "anvil_spark", "weathervane"]:
		_react_t = 0.65
		var meta: Dictionary = CURIO_META[curio_kind] as Dictionary
		_emit_sfx(str(meta.get("sfx", "prop_chime")))
		queue_redraw()
		return true
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if _react_t > 0.0:
		_react_t = maxf(0.0, _react_t - dt)
		queue_redraw()
	elif curio_kind in ["hearth_fire", "moth_jar", "pond_lantern", "kettle", "chime_rack"]:
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var meta: Dictionary = CURIO_META[curio_kind] as Dictionary
	var r: float = float(meta.get("light", 0.0))
	if r <= 0.0:
		return Vector4.ZERO
	var fr: bool = LxHudFx.flash_reduced()
	var boost: float = (5.0 if fr else 10.0) if _react_t > 0.0 else 0.0
	var strength: float = (0.84 if fr else 0.98) if _react_t > 0.0 else (0.64 if fr else 0.72)
	return Vector4(pos.x, pos.y - 6.0, r + boost, strength)


func _draw() -> void:
	if not active:
		return
	_draw_ground_shadow(7.0, 3.0, Vector2(0.0, 1.0))
	var fr: bool = LxHudFx.flash_reduced()
	var wobble: float = 0.0 if (fr or _react_t <= 0.0) else roundf(sin(_react_t * 26.0) * 1.5)
	var meta: Dictionary = CURIO_META[curio_kind] as Dictionary
	var accent: Color = LxPalette.color(str(meta.get("color", "gold")), "gold")
	var c_void: Color = LxPalette.PAL["void"]
	var c_night: Color = LxPalette.PAL["night"]
	var c_dusk: Color = LxPalette.PAL["dusk"]
	var c_stone: Color = LxPalette.PAL["stone"]
	var c_cream: Color = LxPalette.PAL["cream"]
	var c_gold: Color = LxPalette.PAL["gold"]
	var c_apricot: Color = LxPalette.PAL["apricot"]

	match curio_kind:
		"hearth_fire":
			var relit_n: int = Lx.state.relit_islands.size() if Lx.state != null else 0
			var extra_h: float = 1.0 if relit_n >= 4 else 0.0
			draw_rect(Rect2(-12.0, -15.0, 24.0, 17.0), c_void)
			draw_rect(Rect2(-11.0, -14.0, 22.0, 15.0), c_dusk)
			draw_rect(Rect2(-11.0, -14.0, 22.0, 2.0), c_stone)
			draw_rect(Rect2(-7.0, -9.0, 14.0, 10.0), c_night)
			draw_rect(Rect2(-6.0, -2.0, 12.0, 2.0), LxPalette.PAL["wine"])
			var fh: float = (6.0 + extra_h) if fr else (5.0 + extra_h + roundf(sin(_clock * 8.0) * 1.0))
			draw_rect(Rect2(-5.0, -1.0 - fh, 10.0, fh), LxPalette.PAL["coral"])
			draw_rect(Rect2(-3.0, -fh, 6.0, fh - 1.0), c_gold)
			draw_rect(Rect2(-1.0, -fh + 2.0, 2.0, 2.0), c_cream)
		"kettle":
			# Copper kettle on iron stove trivet with rising steam puff
			draw_rect(Rect2(-6.0, -3.0, 12.0, 4.0), c_void)
			draw_rect(Rect2(-5.0, -2.0, 10.0, 2.0), c_dusk)
			draw_rect(Rect2(-6.0 + wobble, -10.0, 12.0, 8.0), c_void)
			draw_rect(Rect2(-5.0 + wobble, -9.0, 10.0, 6.0), c_apricot)
			draw_rect(Rect2(-4.0 + wobble, -8.0, 4.0, 3.0), c_gold)
			draw_rect(Rect2(-3.0 + wobble, -8.0, 2.0, 1.0), c_cream)
			draw_rect(Rect2(-8.0 + wobble, -9.0, 3.0, 3.0), c_void)
			draw_rect(Rect2(-7.0 + wobble, -8.0, 2.0, 2.0), c_gold)
			draw_rect(Rect2(-3.0 + wobble, -13.0, 6.0, 3.0), c_void)
			draw_rect(Rect2(-2.0 + wobble, -12.0, 4.0, 1.0), c_stone)
			draw_rect(Rect2(-1.0 + wobble, -11.0, 2.0, 2.0), c_gold)
			var st_y: float = -13.0 if fr else -13.0 - roundf(fmod(_clock * 4.5, 4.0))
			draw_rect(Rect2(-8.0 + wobble, st_y, 2.0, 2.0), c_cream if (_react_t > 0.0 and not fr) else LxPalette.PAL["ice"])
		"telescope":
			draw_rect(Rect2(-5.0, -3.0, 2.0, 4.0), c_dusk)
			draw_rect(Rect2(3.0, -3.0, 2.0, 4.0), c_dusk)
			draw_rect(Rect2(-2.0, -9.0, 4.0, 10.0), c_void)
			draw_rect(Rect2(-1.0, -8.0, 2.0, 9.0), c_stone)
			draw_rect(Rect2(-8.0 + wobble, -15.0, 16.0, 6.0), c_void)
			draw_rect(Rect2(-7.0 + wobble, -14.0, 13.0, 4.0), LxPalette.PAL["blue"])
			draw_rect(Rect2(-5.0 + wobble, -13.0, 10.0, 2.0), c_gold)
			draw_rect(Rect2(5.0 + wobble, -14.0, 3.0, 4.0), LxPalette.PAL["ice"])
			draw_rect(Rect2(6.0 + wobble, -13.0, 1.0, 2.0), c_cream)
		"moth_jar":
			var mc: int = LxQuests.current().get_moth_count()
			var moth_vis: int = 3 if mc >= 20 else (2 if mc >= 5 else 1)
			draw_rect(Rect2(-5.0, -14.0, 10.0, 15.0), c_void)
			draw_rect(Rect2(-4.0, -12.0, 8.0, 12.0), LxPalette.PAL["deep"])
			draw_rect(Rect2(-3.0, -11.0, 1.0, 9.0), LxPalette.PAL["sky"])
			draw_rect(Rect2(-4.0, -14.0, 8.0, 2.0), c_apricot)
			var base_pts: Array[Vector2] = [Vector2(-2.0, -7.0), Vector2(0.0, -10.0), Vector2(-3.0, -4.0)]
			for mi: int in range(moth_vis):
				var bp: Vector2 = base_pts[mi]
				var dy: float = 0.0 if fr else roundf(sin(_clock * 5.0 + float(mi) * 2.1) * 1.0)
				draw_rect(Rect2(bp.x, bp.y + dy, 3.0, 2.0), c_gold)
				draw_rect(Rect2(bp.x + 1.0, bp.y + dy, 1.0, 1.0), c_cream)
		"ship_bottle":
			# Miniature ship inside glass bottle on cradle stand
			draw_rect(Rect2(-7.0, -3.0, 14.0, 4.0), c_void)
			draw_rect(Rect2(-5.0, -2.0, 2.0, 2.0), LxPalette.PAL["wine"])
			draw_rect(Rect2(3.0, -2.0, 2.0, 2.0), LxPalette.PAL["wine"])
			draw_rect(Rect2(-9.0 + wobble, -11.0, 16.0, 9.0), c_void)
			draw_rect(Rect2(6.0 + wobble, -9.0, 4.0, 5.0), c_void)
			draw_rect(Rect2(-8.0 + wobble, -10.0, 14.0, 7.0), LxPalette.PAL["deep"])
			draw_rect(Rect2(-7.0 + wobble, -10.0, 12.0, 1.0), LxPalette.PAL["ice"])
			draw_rect(Rect2(7.0 + wobble, -8.0, 2.0, 3.0), c_apricot)
			draw_rect(Rect2(-5.0 + wobble, -5.0, 8.0, 2.0), c_apricot)
			draw_rect(Rect2(-4.0 + wobble, -9.0, 3.0, 4.0), c_cream)
			draw_rect(Rect2(0.0 + wobble, -8.0, 2.0, 3.0), c_cream)
		"herb_pot":
			draw_rect(Rect2(-7.0, -7.0, 14.0, 8.0), c_void)
			draw_rect(Rect2(-6.0, -6.0, 12.0, 6.0), LxPalette.PAL["wine"])
			draw_rect(Rect2(-5.0, -5.0, 10.0, 4.0), LxPalette.PAL["coral"])
			draw_rect(Rect2(-6.0 + wobble, -13.0, 12.0, 7.0), LxPalette.PAL["jade"])
			draw_rect(Rect2(-4.0 + wobble, -15.0, 8.0, 5.0), LxPalette.PAL["lime"])
			draw_rect(Rect2(-1.0 + wobble, -14.0, 2.0, 2.0), c_cream)
		"star_chart":
			# Angled oak lectern with celestial star parchment
			draw_rect(Rect2(-5.0, -4.0, 10.0, 5.0), c_void)
			draw_rect(Rect2(-2.0, -8.0, 4.0, 8.0), LxPalette.PAL["wine"])
			draw_rect(Rect2(-9.0 + wobble, -16.0, 18.0, 11.0), c_void)
			draw_rect(Rect2(-8.0 + wobble, -15.0, 16.0, 9.0), LxPalette.PAL["deep"])
			draw_rect(Rect2(-8.0 + wobble, -15.0, 16.0, 1.0), c_apricot)
			draw_rect(Rect2(-8.0 + wobble, -7.0, 16.0, 1.0), c_apricot)
			draw_line(Vector2(-5.0 + wobble, -12.0), Vector2(0.0 + wobble, -10.0), LxPalette.PAL["sky"], 1.0)
			draw_line(Vector2(0.0 + wobble, -10.0), Vector2(5.0 + wobble, -13.0), LxPalette.PAL["sky"], 1.0)
			draw_rect(Rect2(-6.0 + wobble, -13.0, 2.0, 2.0), c_gold)
			draw_rect(Rect2(-1.0 + wobble, -11.0, 2.0, 2.0), c_cream)
			draw_rect(Rect2(4.0 + wobble, -14.0, 2.0, 2.0), LxPalette.PAL["ice"])
		"anvil_spark":
			draw_rect(Rect2(-6.0, -4.0, 12.0, 5.0), c_void)
			draw_rect(Rect2(-5.0, -3.0, 10.0, 3.0), LxPalette.PAL["wine"])
			draw_rect(Rect2(-9.0, -10.0, 18.0, 7.0), c_void)
			draw_rect(Rect2(-8.0, -9.0, 15.0, 3.0), c_stone)
			draw_rect(Rect2(-8.0, -9.0, 12.0, 1.0), c_cream)
			draw_rect(Rect2(-5.0, -6.0, 9.0, 3.0), c_dusk)
			if _react_t > 0.0:
				draw_rect(Rect2(-2.0 + wobble, -12.0, 2.0, 2.0), c_apricot if fr else c_gold)
				if not fr:
					draw_rect(Rect2(2.0 - wobble, -13.0, 2.0, 2.0), c_cream)
		"trophy_rack":
			# 6 individual minigame medal cubbies: empty dark plinth vs Bronze / Silver / Gold cup
			draw_rect(Rect2(-11.0, -16.0, 22.0, 17.0), c_void)
			draw_rect(Rect2(-10.0, -15.0, 20.0, 15.0), LxPalette.PAL["wine"])
			draw_rect(Rect2(-10.0, -15.0, 20.0, 2.0), c_apricot)
			draw_rect(Rect2(-9.0, -7.0, 18.0, 1.0), c_dusk)
			for i: int in range(mini(6, LxHubState.MINIGAME_IDS.size())):
				var cx: float = -9.0 + float((i % 3) * 6)
				var cy: float = -12.0 + float((i / 3) * 6)
				draw_rect(Rect2(cx, cy, 5.0, 5.0), c_night)
				var m: int = LxHubState.get_minigame_medal(LxHubState.MINIGAME_IDS[i])
				if m <= 0:
					# Empty locked plinth silhouette
					draw_rect(Rect2(cx + 1.0, cy + 3.0, 3.0, 1.0), c_dusk)
				else:
					var cup_c: Color = c_gold if m >= 3 else (LxPalette.PAL["ice"] if m == 2 else c_apricot)
					if m >= 3:
						draw_rect(Rect2(cx, cy + 1.0, 5.0, 2.0), cup_c)
					else:
						draw_rect(Rect2(cx + 1.0, cy + 1.0, 3.0, 2.0), cup_c)
					draw_rect(Rect2(cx + 2.0, cy + 3.0, 1.0, 1.0), cup_c)
					draw_rect(Rect2(cx + 1.0, cy + 4.0, 3.0, 1.0), c_apricot if m >= 3 else cup_c)
					if m >= 2:
						draw_rect(Rect2(cx + 1.0, cy + 1.0, 1.0, 1.0), c_cream)
		"cellar_cask":
			# Banded oak cellar barrel with brass tap spigot
			draw_rect(Rect2(-7.0 + wobble, -14.0, 14.0, 15.0), c_void)
			draw_rect(Rect2(-6.0 + wobble, -13.0, 12.0, 13.0), LxPalette.PAL["wine"])
			draw_rect(Rect2(-4.0 + wobble, -12.0, 3.0, 11.0), c_apricot)
			draw_rect(Rect2(-6.0 + wobble, -11.0, 12.0, 2.0), c_stone)
			draw_rect(Rect2(-6.0 + wobble, -5.0, 12.0, 2.0), c_stone)
			draw_rect(Rect2(5.0 + wobble, -8.0, 3.0, 2.0), c_gold)
		"chime_rack":
			# Arched timber stand with 4 hanging brass tubular chimes
			draw_rect(Rect2(-9.0, -16.0, 18.0, 3.0), c_void)
			draw_rect(Rect2(-8.0, -15.0, 16.0, 2.0), LxPalette.PAL["wine"])
			draw_rect(Rect2(-8.0, -14.0, 2.0, 15.0), c_void)
			draw_rect(Rect2(6.0, -14.0, 2.0, 15.0), c_void)
			var sway: float = 0.0 if fr else roundf(sin(_clock * 2.4) * 1.0) + wobble
			var lens: Array[float] = [10.0, 8.0, 11.0, 7.0]
			for ci: int in range(4):
				var cx: float = -5.0 + float(ci * 3) + sway
				draw_rect(Rect2(cx, -13.0, 2.0, lens[ci]), c_gold if ci % 2 == 0 else c_apricot)
				draw_rect(Rect2(cx, -13.0, 1.0, 2.0), c_cream)
		"tally_board":
			# Framed slate scoreboard on wooden easel legs
			draw_rect(Rect2(-7.0, -3.0, 2.0, 4.0), c_dusk)
			draw_rect(Rect2(5.0, -3.0, 2.0, 4.0), c_dusk)
			draw_rect(Rect2(-9.0 + wobble, -16.0, 18.0, 14.0), c_void)
			draw_rect(Rect2(-8.0 + wobble, -15.0, 16.0, 12.0), c_apricot)
			draw_rect(Rect2(-7.0 + wobble, -14.0, 14.0, 10.0), c_night)
			draw_rect(Rect2(-6.0 + wobble, -13.0, 12.0, 1.0), c_gold)
			for ti: int in range(4):
				draw_rect(Rect2(-5.0 + float(ti * 3) + wobble, -10.0, 1.0, 4.0), c_cream)
			draw_line(Vector2(-6.0 + wobble, -8.0), Vector2(4.0 + wobble, -9.0), c_gold, 1.0)
		"pond_lantern":
			# Carved stone garden lantern with warm glowing core
			draw_rect(Rect2(-5.0, -3.0, 10.0, 4.0), c_void)
			draw_rect(Rect2(-4.0, -2.0, 8.0, 2.0), c_stone)
			draw_rect(Rect2(-3.0, -10.0, 6.0, 8.0), c_void)
			draw_rect(Rect2(-2.0, -9.0, 4.0, 6.0), c_gold)
			var glow_h: float = 4.0 if fr else 3.0 + roundf(sin(_clock * 6.0) * 1.0)
			draw_rect(Rect2(-1.0, -8.0, 2.0, glow_h), c_cream)
			draw_rect(Rect2(-7.0, -13.0, 14.0, 4.0), c_void)
			draw_rect(Rect2(-6.0, -12.0, 12.0, 2.0), LxPalette.PAL["mauve"])
			draw_rect(Rect2(-3.0, -14.0, 6.0, 2.0), c_stone)
		"old_trunk":
			# Domed plum travel trunk with brass straps and lock clasp
			draw_rect(Rect2(-9.0 + wobble, -12.0, 18.0, 13.0), c_void)
			draw_rect(Rect2(-8.0 + wobble, -11.0, 16.0, 11.0), LxPalette.PAL["plum"])
			draw_rect(Rect2(-7.0 + wobble, -11.0, 14.0, 3.0), LxPalette.PAL["mauve"])
			draw_rect(Rect2(-8.0 + wobble, -8.0, 16.0, 1.0), c_void)
			draw_rect(Rect2(-6.0 + wobble, -11.0, 2.0, 11.0), c_apricot)
			draw_rect(Rect2(4.0 + wobble, -11.0, 2.0, 11.0), c_apricot)
			draw_rect(Rect2(-2.0 + wobble, -9.0, 4.0, 4.0), c_gold)
			draw_rect(Rect2(-1.0 + wobble, -8.0, 2.0, 2.0), c_cream)
		"porch_bell":
			# Timber post bracket with hanging flared brass bell and cord
			draw_rect(Rect2(-7.0, -16.0, 3.0, 17.0), c_void)
			draw_rect(Rect2(-6.0, -15.0, 1.0, 15.0), LxPalette.PAL["wine"])
			draw_rect(Rect2(-6.0, -16.0, 13.0, 3.0), c_void)
			draw_rect(Rect2(-5.0, -15.0, 11.0, 1.0), c_apricot)
			draw_rect(Rect2(-1.0 + wobble, -13.0, 6.0, 7.0), c_void)
			draw_rect(Rect2(0.0 + wobble, -12.0, 4.0, 5.0), c_gold)
			draw_rect(Rect2(-1.0 + wobble, -8.0, 6.0, 2.0), c_apricot)
			draw_rect(Rect2(1.0 + wobble, -11.0, 1.0, 3.0), c_cream)
			draw_rect(Rect2(1.0 + wobble, -6.0, 2.0, 4.0), LxPalette.PAL["coral"])
		"weathervane":
			# Wrought-iron post with compass crossbar and gilded directional vane
			draw_rect(Rect2(-2.0, -15.0, 4.0, 16.0), c_void)
			draw_rect(Rect2(-1.0, -14.0, 2.0, 14.0), c_stone)
			draw_rect(Rect2(-6.0, -9.0, 12.0, 2.0), c_dusk)
			draw_rect(Rect2(-8.0 + wobble, -15.0, 16.0, 3.0), c_void)
			draw_rect(Rect2(-7.0 + wobble, -14.0, 14.0, 1.0), c_gold)
			draw_rect(Rect2(5.0 + wobble, -16.0, 3.0, 5.0), c_gold)
			draw_rect(Rect2(6.0 + wobble, -15.0, 1.0, 3.0), c_cream)
			draw_rect(Rect2(-7.0 + wobble, -16.0, 3.0, 3.0), LxPalette.PAL["ice"])
		_:
			draw_rect(Rect2(-6.0 + wobble, -12.0, 12.0, 13.0), c_void)
			draw_rect(Rect2(-5.0 + wobble, -11.0, 10.0, 11.0), c_dusk)
			draw_rect(Rect2(-4.0 + wobble, -10.0, 8.0, 4.0), accent)
			draw_rect(Rect2(-2.0 + wobble, -5.0, 4.0, 3.0), c_cream)

	if _react_t > 0.0:
		var u: float = 1.0 - clampf(_react_t / 0.85, 0.0, 1.0)
		var sy: float = roundf(-18.0 - u * (4.0 if fr else 9.0))
		draw_rect(Rect2(-3.0, sy - 1.0, 6.0, 4.0), c_void)
		draw_rect(Rect2(-2.0, sy, 4.0, 2.0), accent)
		draw_rect(Rect2(-1.0, sy - 1.0, 2.0, 4.0), accent if fr else c_cream)
