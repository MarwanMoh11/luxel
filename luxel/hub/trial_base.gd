class_name LxHubTrialBase
extends LxInteractable
## Shared base class for Wick House minigame pedestals/starters.
## Provides medal pips on the plinth, a crisp pixel HUD banner overlay (layer 11),
## start/finish lifecycle, best-score persistence, and Bronze/Silver/Gold reward grants.

var mg_id: String = ""
var title_key: String = "ZONE_WICK_HOUSE"
var lower_is_better: bool = false
var bronze_goal: float = 100.0
var silver_goal: float = 200.0
var gold_goal: float = 300.0

var trial_running: bool = false
var trial_elapsed: float = 0.0
var trial_time_limit: float = 0.0
var trial_score: float = 0.0
var trial_subtext: String = ""

var _result_banner_t: float = 0.0
var _result_medal: int = 0
var _result_new_best: bool = false
var _hud_layer: CanvasLayer = null
var _hud_draw: Node2D = null


func _exit_tree() -> void:
	if trial_running:
		stop_trial(false)
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
		_hud_layer = null


func get_interact_prompt() -> String:
	return "PROMPT_HUB_STOP_TRIAL" if trial_running else "PROMPT_HUB_START_TRIAL"


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	if trial_running:
		stop_trial(false)
	else:
		start_trial()
	return true


func start_trial() -> void:
	trial_running = true
	trial_elapsed = 0.0
	trial_score = 0.0
	trial_subtext = ""
	_result_banner_t = 0.0
	_ensure_hud()
	_emit_sfx("switch_on")
	_on_trial_start()
	queue_redraw()


func stop_trial(record: bool = false, final_val: float = 0.0) -> void:
	if not trial_running:
		return
	trial_running = false
	_on_trial_end()
	if record:
		var medal: int = evaluate_medal(final_val)
		var res: Dictionary = LxHubState.record_minigame_result(mg_id, final_val, medal, lower_is_better)
		_result_medal = medal
		_result_new_best = bool(res.get("new_best", false))
		_result_banner_t = 3.2
		_emit_sfx("hub_medal_gold" if medal >= LxHubState.MEDAL_GOLD else ("hub_medal_silver" if medal >= LxHubState.MEDAL_SILVER else ("hub_medal_bronze" if medal >= LxHubState.MEDAL_BRONZE else "ui_confirm")))
		if Lx.events != null:
			var cue: String = "HUB_MEDAL_GOLD" if medal >= 3 else ("HUB_MEDAL_SILVER" if medal == 2 else ("HUB_MEDAL_BRONZE" if medal == 1 else "HUB_TRIAL_DONE"))
			Lx.events.narration_requested.emit(cue, "title", 2.6)
	else:
		_emit_sfx("ui_back")
		if _hud_layer != null and is_instance_valid(_hud_layer):
			_hud_layer.visible = false
	queue_redraw()


func evaluate_medal(val: float) -> int:
	if lower_is_better:
		if val <= 0.0:
			return LxHubState.MEDAL_NONE
		if val <= gold_goal: return LxHubState.MEDAL_GOLD
		if val <= silver_goal: return LxHubState.MEDAL_SILVER
		if val <= bronze_goal: return LxHubState.MEDAL_BRONZE
		return LxHubState.MEDAL_NONE
	if val >= gold_goal: return LxHubState.MEDAL_GOLD
	if val >= silver_goal: return LxHubState.MEDAL_SILVER
	if val >= bronze_goal: return LxHubState.MEDAL_BRONZE
	return LxHubState.MEDAL_NONE


func tick(dt: float) -> void:
	super.tick(dt)
	if trial_running:
		trial_elapsed += dt
		_on_trial_tick(dt)
		if trial_time_limit > 0.0 and trial_elapsed >= trial_time_limit:
			stop_trial(true, trial_score)
		if _hud_draw != null and is_instance_valid(_hud_draw):
			_hud_draw.queue_redraw()
	elif _result_banner_t > 0.0:
		_result_banner_t = maxf(0.0, _result_banner_t - dt)
		if _hud_draw != null and is_instance_valid(_hud_draw):
			_hud_draw.queue_redraw()
		if _result_banner_t <= 0.0 and _hud_layer != null and is_instance_valid(_hud_layer):
			_hud_layer.visible = false


func _on_trial_start() -> void: pass
func _on_trial_tick(_dt: float) -> void: pass
func _on_trial_end() -> void: pass


func _get_hud_primary_text() -> String:
	if trial_time_limit > 0.0:
		var rem: float = maxf(0.0, trial_time_limit - trial_elapsed)
		return "%d PTS  %04.1fS" % [int(trial_score), rem]
	return "%04.1fS" % trial_elapsed


func _get_plinth_icon() -> String: return "spark"
func _get_plinth_accent() -> String: return "gold"


func _ensure_hud() -> void:
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.visible = true
		return
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "TrialHud_" + mg_id
	_hud_layer.layer = 11
	add_child(_hud_layer)
	_hud_draw = Node2D.new()
	_hud_draw.name = "TrialHudDraw"
	_hud_draw.draw.connect(_draw_hud)
	_hud_layer.add_child(_hud_draw)


func _draw_hud() -> void:
	if _hud_draw == null or (not trial_running and _result_banner_t <= 0.0):
		return
	var box := Rect2(82.0, 4.0, 156.0, 24.0)
	_hud_draw.draw_rect(box, LxPalette.PAL["void"])
	_hud_draw.draw_rect(box.grow(-1.0), LxPalette.PAL["night"])
	var accent: Color = LxPalette.color(_get_plinth_accent(), "gold")
	_hud_draw.draw_rect(Rect2(box.position.x + 1.0, box.position.y + 1.0, box.size.x - 2.0, 1.0), accent)
	LxPixelFont.draw(_hud_draw, LxStrings.text(title_key), Vector2(box.position.x + 6.0, box.position.y + 4.0), accent, 1)

	if trial_running:
		var prim: String = _get_hud_primary_text()
		LxPixelFont.draw(_hud_draw, prim, Vector2(box.position.x + 6.0, box.position.y + 13.0), LxPalette.PAL["cream"], 1)
		if not trial_subtext.is_empty():
			LxPixelFont.draw(_hud_draw, trial_subtext, Vector2(box.end.x - float(trial_subtext.length() * 4) - 5.0, box.position.y + 13.0), LxPalette.PAL["gold"], 1)
		# Live medal progress pips
		var cur_m: int = evaluate_medal(trial_score if not lower_is_better else trial_elapsed)
		if lower_is_better:
			cur_m = LxHubState.get_minigame_medal(mg_id)
		for mi: int in range(3):
			var mc: Color = LxPalette.PAL["gold"] if mi == 2 else (LxPalette.PAL["ice"] if mi == 1 else LxPalette.PAL["apricot"])
			_hud_draw.draw_rect(Rect2(box.end.x - 22.0 + float(mi * 6), box.position.y + 4.0, 4.0, 4.0), mc if cur_m > mi else LxPalette.PAL["dusk"])
	else:
		var m_key: String = "HUB_MEDAL_GOLD" if _result_medal >= 3 else ("HUB_MEDAL_SILVER" if _result_medal == 2 else ("HUB_MEDAL_BRONZE" if _result_medal == 1 else "HUB_TRIAL_DONE"))
		LxPixelFont.draw(_hud_draw, LxStrings.text(m_key), Vector2(box.position.x + 6.0, box.position.y + 13.0), LxPalette.PAL["gold"] if _result_medal > 0 else LxPalette.PAL["stone"], 1)
		if _result_new_best:
			var nb: String = LxStrings.text("HUB_NEW_BEST")
			LxPixelFont.draw(_hud_draw, nb, Vector2(box.end.x - float(nb.length() * 4) - 5.0, box.position.y + 13.0), LxPalette.PAL["lime"], 1)


func get_light_pool() -> Vector4:
	return Vector4(pos.x, pos.y - 8.0, 44.0 if trial_running else 30.0, 0.85 if trial_running else 0.55)


func _draw() -> void:
	if not active:
		return
	_draw_ground_shadow(10.0, 3.0, Vector2(0.0, 2.0))
	var acc: Color = LxPalette.color(_get_plinth_accent(), "gold")
	draw_rect(Rect2(-9.0, -16.0, 18.0, 18.0), LxPalette.PAL["void"])
	draw_rect(Rect2(-8.0, -15.0, 16.0, 16.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(-7.0, -14.0, 14.0, 3.0), acc if not trial_running else LxPalette.PAL["lime"])
	LxBubble.draw_icon(self, _get_plinth_icon(), Vector2(-4.0, -10.0), 1.0)
	# 3 saved medal pips along plinth base
	var best_m: int = LxHubState.get_minigame_medal(mg_id)
	for mi: int in range(3):
		var mc: Color = LxPalette.PAL["gold"] if mi == 2 else (LxPalette.PAL["ice"] if mi == 1 else LxPalette.PAL["apricot"])
		draw_rect(Rect2(-7.0 + float(mi * 6), 3.0, 4.0, 3.0), mc if best_m > mi else LxPalette.PAL["night"])
