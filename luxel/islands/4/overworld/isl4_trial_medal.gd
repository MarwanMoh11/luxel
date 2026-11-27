class_name LxIsl4TrialMedal
extends LxToy
## Island 4 Trial Medal Pedestal (`isl4_trial_medal`):
## Listens to a linked `trial_gate` signal, grades completion time into Bronze / Silver / Gold,
## saves best medal tier in Lx.state.story_flags, awards bonus shards on new tiers, and renders
## the earned medal crest right beside the trial course.
## Props: trial_id (String), gold_s (float), silver_s (float), bronze_s (float).

var trial_id: String = "wing_spire"
var gold_s: float = 24.0
var silver_s: float = 34.0
var bronze_s: float = 45.0
var medal_tier: int = 0  # 0=none, 1=bronze, 2=silver, 3=gold
var _flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "isl4_trial_medal"
	radius = 14.0
	trial_id = str(props.get("trial_id", "wing_spire")).strip_edges()
	gold_s = maxf(5.0, float(props.get("gold_s", 24.0)))
	silver_s = maxf(gold_s + 2.0, float(props.get("silver_s", 34.0)))
	bronze_s = maxf(silver_s + 2.0, float(props.get("bronze_s", 45.0)))
	_sync_from_state()
	queue_redraw()


func _sync_from_state() -> void:
	if Lx.state == null:
		return
	var saved: int = int(Lx.state.story_flags.get("medal_" + trial_id, 0))
	if saved <= 0 and bool(Lx.state.story_flags.get("trial_" + trial_id + "_done", false)):
		on_signal("trial_flag", true)
		return
	medal_tier = clampi(saved, 0, 3)
	powered = medal_tier > 0


func on_signal(_from_id: String, is_on: bool) -> void:
	if not is_on:
		return
	var elapsed: float = bronze_s
	if region != null and is_instance_valid(region):
		var scr: Variant = region.get("room_script")
		if scr is Object and is_instance_valid(scr):
			var ch: Variant = (scr as Object).get("active_challenge")
			if ch is Object and is_instance_valid(ch) and (ch as Object).get("elapsed_s") != null:
				elapsed = float((ch as Object).get("elapsed_s"))
	var earned: int = 3 if elapsed <= gold_s else (2 if elapsed <= silver_s else 1)
	_award_medal(earned)


func _award_medal(tier: int) -> void:
	if Lx.state == null:
		return
	var prev: int = clampi(int(Lx.state.story_flags.get("medal_" + trial_id, 0)), 0, 3)
	if tier > prev:
		Lx.state.story_flags["medal_" + trial_id] = tier
		var bonus: int = (tier - prev) * 25
		Lx.state.add_shards(bonus)
		if Lx.events != null:
			Lx.events.save_requested.emit("medal_" + trial_id)
	medal_tier = maxi(prev, tier)
	set_powered(true)
	_flash_t = 0.85
	var cue: String = "ISL4_TRIAL_MEDAL_GOLD" if tier >= 3 else ("ISL4_TRIAL_MEDAL_SILVER" if tier == 2 else "ISL4_TRIAL_MEDAL_BRONZE")
	if Lx.events != null and LxStrings.has_id(cue):
		Lx.events.narration_requested.emit(cue, "title", 2.8)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	_sync_from_state()
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()


func get_light_pool() -> Vector4:
	if not active or medal_tier <= 0:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 36.0 + float(medal_tier) * 6.0, 0.55 + float(medal_tier) * 0.1)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_medal: Color = PAL["mauve"] as Color
	if medal_tier == 1:
		c_medal = PAL["apricot"] as Color
	elif medal_tier == 2:
		c_medal = PAL["ice"] as Color
	elif medal_tier >= 3:
		c_medal = PAL["gold"] as Color

	var fred: bool = LxHudFx.flash_reduced()
	var c_cream: Color = PAL["cream"] as Color
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 7.0, 3.0)
	LxToyDraw.draw_bevel_box(self, Rect2(-6.0, -10.0, 12.0, 14.0), c_night, c_dusk, c_medal if medal_tier > 0 else c_stone, c_void)
	# Winged medal disc with tier-distinct silhouette (stubs=Bronze, wings=Silver, wings+crown=Gold)
	if medal_tier >= 1:
		var ww: float = 3.0 if medal_tier >= 2 else 2.0
		draw_rect(Rect2(-4.0 - ww, -6.0, ww, 3.0), c_void)
		draw_rect(Rect2(4.0, -6.0, ww, 3.0), c_void)
		draw_rect(Rect2(-3.0 - ww, -5.0, ww, 2.0), c_medal)
		draw_rect(Rect2(3.0, -5.0, ww, 2.0), c_medal)
	if medal_tier >= 3:
		draw_rect(Rect2(-2.0, -10.0, 4.0, 3.0), c_void)
		draw_rect(Rect2(-1.0, -10.0, 2.0, 2.0), c_cream)
	draw_circle(Vector2(0.0, -4.0), 4.0, c_void)
	draw_circle(Vector2(0.0, -4.0), 3.0, c_medal if medal_tier > 0 else c_dusk)
	if medal_tier > 0:
		draw_rect(Rect2(-1.0, -5.0, 2.0, 2.0), c_cream)
	# 3 permanent tier sockets along plinth bottom (raised 2x2 earned vs flat 2x1 empty)
	for p: int in range(3):
		var sx: float = -4.0 + float(p) * 3.0
		if p < medal_tier:
			draw_rect(Rect2(sx, 1.0, 2.0, 2.0), c_medal)
			draw_rect(Rect2(sx, 1.0, 2.0, 1.0), c_cream)
		else:
			draw_rect(Rect2(sx, 2.0, 2.0, 1.0), c_void)
	if _flash_t > 0.0:
		var u: float = 1.0 - clampf(_flash_t / 0.85, 0.0, 1.0)
		var fa: float = (1.0 - u) * (0.48 if fred else 0.88)
		draw_arc(Vector2(0.0, -4.0), roundf(lerpf(5.0, 18.0, u)), 0.0, TAU, 16, Color(c_cream, fa), 1.0)
