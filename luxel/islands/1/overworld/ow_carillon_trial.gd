class_name LxOwCarillonTrial
extends LxToy
## Island 1 Trial #3: Carillon Ear-Test in bell_yard (Chime Town).
## Repeat Bell Ringer Snail's 3 escalating Dawn-Dusk-War bell motifs (visual + audio).
## Round 1 -> Bronze (10 shards), Round 2 -> Silver (15 shards), Round 3 -> Gold (35 shards + trophy).

const ROUNDS: Array = [
	["dawn", "dusk", "dawn"],
	["dawn", "war", "dusk", "dawn"],
	["dusk", "dawn", "war", "dusk", "dawn"],
]
const DEMO_STEP_S: float = 0.62
const BELL_COLORS: Dictionary = {
	"dawn": "gold",
	"dusk": "ice",
	"war": "coral",
}
const BELL_SFX: Dictionary = {
	"dawn": "bell_dawn_ring",
	"dusk": "bell_dusk_ring",
	"war": "bell_war_ring",
}

enum Mode { IDLE, DEMO, LISTEN, WON }

var mode: int = Mode.IDLE
var round_idx: int = 0
var _demo_idx: int = 0
var _demo_t: float = 0.0
var _demo_tone: String = ""
var _input_idx: int = 0
var _flash_t: float = 0.0
var _connected_region: Node = null
var _bell_ids: Dictionary = {}


func _toy_setup() -> void:
	kind = "ow_carillon_trial"
	size = Vector2(20.0, 16.0)
	radius = 18.0
	persist = true
	_bell_ids = {
		"dawn": str(props.get("dawn_bell", "bell_carillon_dawn")),
		"dusk": str(props.get("dusk_bell", "bell_carillon_dusk")),
		"war": str(props.get("war_bell", "bell_carillon_war")),
	}
	mode = Mode.WON if _best_medal() >= 3 else Mode.IDLE
	_bind_region()
	queue_redraw()


func _exit_tree() -> void:
	if _connected_region != null and is_instance_valid(_connected_region):
		if _connected_region.has_signal("room_notified") and _connected_region.is_connected("room_notified", _on_room_notified):
			_connected_region.disconnect("room_notified", _on_room_notified)
	_connected_region = null


func _bind_region() -> void:
	if region != null and is_instance_valid(region) and region != _connected_region:
		if region.has_signal("room_notified") and not region.is_connected("room_notified", _on_room_notified):
			region.connect("room_notified", _on_room_notified)
			_connected_region = region


func _best_medal() -> int:
	if Lx.state == null:
		return 0
	return int(Lx.state.story_flags.get("trial_carillon_medal", 0))


func _set_medal(rank: int) -> void:
	if Lx.state == null:
		return
	var prev: int = _best_medal()
	if rank > prev:
		Lx.state.story_flags["trial_carillon_medal"] = rank
		if rank == 1:
			Lx.state.add_shards(10)
		elif rank == 2:
			Lx.state.add_shards(15)
		elif rank >= 3:
			Lx.state.add_shards(35)
			Lx.state.story_flags["trophy_carillon_gold"] = true
			set_powered(true)
			emit_power(true)
		if Lx.events != null:
			Lx.events.save_requested.emit("trial_carillon_%d" % rank)


func interact(_actor: Node = null) -> bool:
	if not active or mode == Mode.DEMO:
		return false
	_bind_region()
	round_idx = 0
	_start_demo()
	return true


func get_interact_prompt() -> String:
	if not active or mode == Mode.DEMO:
		return ""
	return "ISL1_PROMPT_CARILLON" if LxStrings.has_id("ISL1_PROMPT_CARILLON") else "PROMPT_START_TRIAL"


func _start_demo() -> void:
	mode = Mode.DEMO
	_demo_idx = 0
	_demo_t = 0.25
	_demo_tone = ""
	_input_idx = 0
	_flash_t = 0.3
	queue_redraw()


func _find_bell_pos(tone: String) -> Vector2:
	if region == null or not region.has_method("find_interactable"):
		return pos
	var bid: String = str(_bell_ids.get(tone, ""))
	var it: LxInteractable = region.call("find_interactable", bid) as LxInteractable
	return it.pos if it != null else pos


func tick(dt: float) -> void:
	super.tick(dt)
	_bind_region()
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()
	if mode == Mode.DEMO:
		_demo_t -= dt
		if _demo_t <= 0.0:
			var seq: Array = ROUNDS[round_idx] as Array
			if _demo_idx < seq.size():
				_demo_tone = str(seq[_demo_idx])
				_demo_idx += 1
				_demo_t = DEMO_STEP_S
				_flash_t = 0.42
				var bpos: Vector2 = _find_bell_pos(_demo_tone)
				_emit_sfx(str(BELL_SFX.get(_demo_tone, "bell_dawn_ring")))
				if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
					LxDarknessLayer.active_instance.add_burst_light(bpos, 52.0, 0.72 if LxHudFx.flash_reduced() else 1.1, 0.36)
				queue_redraw()
			else:
				_demo_tone = ""
				mode = Mode.LISTEN
				_input_idx = 0
				if Lx.events != null and LxStrings.has_id("ISL1_CARILLON_GO"):
					Lx.events.narration_requested.emit("ISL1_CARILLON_GO", "narration", 2.0)
				queue_redraw()


func _on_room_notified(event_name: String, data: Dictionary) -> void:
	if mode != Mode.LISTEN or event_name != "bell_rung":
		return
	if bool(data.get("echo", false)):
		return
	var bid: String = str(data.get("id", ""))
	if not _bell_ids.values().has(bid):
		return
	var tone: String = str(data.get("tone", "")).strip_edges().to_lower()
	var seq: Array = ROUNDS[round_idx] as Array
	var want: String = str(seq[_input_idx])
	if tone == want:
		_input_idx += 1
		_flash_t = 0.25
		if _input_idx >= seq.size():
			_set_medal(round_idx + 1)
			round_idx += 1
			if round_idx >= ROUNDS.size():
				mode = Mode.WON
				_emit_sfx("shrine_unlock")
				if Lx.events != null and LxStrings.has_id("ISL1_CARILLON_GOLD"):
					Lx.events.narration_requested.emit("ISL1_CARILLON_GOLD", "title", 3.0)
			else:
				_emit_sfx("switch_on")
				_start_demo()
		queue_redraw()
	else:
		_emit_sfx("denied")
		mode = Mode.IDLE
		_demo_tone = ""
		if Lx.events != null and LxStrings.has_id("ISL1_CARILLON_MISS"):
			Lx.events.narration_requested.emit("ISL1_CARILLON_MISS", "narration", 2.0)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 44.0 if mode != Mode.IDLE else 28.0, 0.72 if mode != Mode.IDLE else 0.42)


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 9.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-9.0, -8.0, 18.0, 13.0), PAL["night"] as Color, PAL["dusk"] as Color, PAL["apricot"] as Color, c_void)
	# 3 stepped miniature tone chime bars (distinct heights + specular cap for greyscale readability)
	var bar_cols: Array[Color] = [PAL["gold"] as Color, PAL["ice"] as Color, PAL["coral"] as Color]
	var bar_tones: Array[String] = ["dawn", "dusk", "war"]
	var bar_hs: Array[float] = [7.0, 6.0, 5.0]
	for i: int in range(3):
		var bx: float = -6.0 + float(i) * 5.0
		var bh: float = bar_hs[i]
		var by: float = 1.0 - bh
		var lit: bool = (_demo_tone == bar_tones[i] and _flash_t > 0.0) or mode == Mode.WON
		draw_rect(Rect2(bx - 1.0, by - 1.0, 5.0, bh + 2.0), c_void)
		draw_rect(Rect2(bx, by, 3.0, bh), c_cream if (lit and not red) else bar_cols[i])
		if lit:
			draw_rect(Rect2(bx, by - 1.0, 3.0, 2.0), c_cream)
	# Void-backed medal pips below plinth (Bronze / Silver / Gold) with cream glint when earned
	var best: int = _best_medal()
	for m: int in range(3):
		var mc: Color = (PAL["gold"] if m == 2 else (PAL["ice"] if m == 1 else PAL["apricot"])) as Color
		var mx: float = -6.0 + float(m) * 4.0
		draw_rect(Rect2(mx, 2.0, 4.0, 4.0), c_void)
		draw_rect(Rect2(mx + 1.0, 3.0, 2.0, 2.0), mc if best > m else PAL["night"] as Color)
		if best > m:
			draw_rect(Rect2(mx + 1.0, 3.0, 1.0, 1.0), c_cream)
	# Highlight active demo bell in world space relative to self (ring + tone crest for greyscale/deaf players)
	if mode == Mode.DEMO and not _demo_tone.is_empty() and _flash_t > 0.0:
		var rel: Vector2 = (_find_bell_pos(_demo_tone) - pos).round()
		var col: Color = PAL[str(BELL_COLORS.get(_demo_tone, "gold"))] as Color
		draw_arc(rel, 14.0, 0.0, TAU, 16, Color(col, 0.62 if red else 0.94), 1.0 if red else 2.0)
		draw_arc(rel, 10.0, 0.0, TAU, 12, Color(c_cream, 0.55 if red else 0.90), 1.0)
		LxToyDraw.draw_tone_crest(self, rel + Vector2(0.0, -18.0), _demo_tone, true)
