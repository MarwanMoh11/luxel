class_name LxStairLiftPad
extends LxToy
## Endless Stair Express Lift Platform (`F4`, `F8`, `F12`, and return lifts to `F1`).
## Props: floor_num (int: 4|8|12|1), requires_flag (String), to_region (String), to_spawn ([x,y]).
## Displays locked obsidian seal vs glowing brass lift glyph; interacting when
## unlocked syncs LxStairDirector.warp_to_lift() and carries Wick to the landing.

var floor_num: int = 4
var requires_flag: String = ""
var to_region: String = ""
var to_spawn: Vector2 = Vector2(-1.0, -1.0)
var _unlocked: bool = false
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "stair_lift_pad"
	floor_num = int(props.get("floor_num", 4))
	requires_flag = str(props.get("requires_flag", "")).strip_edges()
	to_region = str(props.get("to_region", "")).strip_edges()
	var sp_v: Variant = props.get("to_spawn", [])
	if sp_v is Array and (sp_v as Array).size() >= 2:
		to_spawn = Vector2(float((sp_v as Array)[0]), float((sp_v as Array)[1]))
	radius = 20.0
	z_index = -2
	_sync_unlock()
	queue_redraw()


func is_floor_toy() -> bool:
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()
	var prev: bool = _unlocked
	_sync_unlock()
	if _unlocked != prev:
		queue_redraw()
	_sync_defeated_bosses()


func _sync_defeated_bosses() -> void:
	# Belt-and-suspenders for boss rooms with stair_controller: LxBossBase keeps
	# visible=true during BossState.DEATH (5), which stalls LxStairController._live_enemy_count().
	if region == null or not is_instance_valid(region) or not region.has_method("get_enemies"):
		return
	var en_v: Variant = region.call("get_enemies")
	if not (en_v is Array):
		return
	for ev: Variant in (en_v as Array):
		if not (ev is Node2D) or not is_instance_valid(ev):
			continue
		var en: Node2D = ev as Node2D
		if not en.visible:
			continue
		if (en.get("hp") != null and float(en.get("hp")) <= 0.0) or (en.get("boss_state") != null and int(en.get("boss_state")) == 5):
			en.visible = false


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_sync_unlock()
	if not _unlocked:
		_emit_sfx("door_locked")
		if Lx.events != null and LxStrings.has_id("ISL8_STAIR_LIFT_LOCKED"):
			Lx.events.narration_requested.emit("ISL8_STAIR_LIFT_LOCKED", "narration", 2.0)
		return false
	_pulse_t = 0.45
	_emit_sfx("boon_draft")
	var dir: LxStairDirector = _get_director()
	if dir != null and floor_num in [4, 8, 12]:
		dir.warp_to_lift(floor_num)
	set_powered(true)
	emit_power(true)
	if not to_region.is_empty() and Lx.root != null and is_instance_valid(Lx.root) and Lx.root.has_method("load_island_region"):
		if not (Lx.input != null and bool(Lx.input.get("_use_synthetic"))):
			Lx.root.call_deferred("load_island_region", 8, to_region, to_spawn)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL8_STAIR_PROMPT_LIFT" if active else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y, 38.0 if _unlocked else 18.0, 0.72 if _unlocked else 0.28)


func _sync_unlock() -> void:
	if requires_flag.is_empty():
		_unlocked = true
		return
	if region != null and region.has_method("is_flag_set"):
		_unlocked = bool(region.call("is_flag_set", requires_flag))
	elif Lx.state != null:
		_unlocked = bool(Lx.state.story_flags.get(requires_flag, false))
	else:
		_unlocked = false


func _get_director() -> LxStairDirector:
	if LxIsland8Rule.active_instance != null and LxIsland8Rule.active_instance.stair != null:
		return LxIsland8Rule.active_instance.stair
	return null


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var accent: Color = PAL["gold"] as Color if floor_num <= 4 else (PAL["sky"] as Color if floor_num <= 8 else PAL["rose"] as Color)

	# Octagonal brass lift pad
	draw_rect(Rect2(-12.0, -9.0, 24.0, 18.0), c_void)
	draw_rect(Rect2(-11.0, -8.0, 22.0, 16.0), accent if _unlocked else c_dusk)
	draw_rect(Rect2(-9.0, -6.0, 18.0, 12.0), c_night)
	if _unlocked:
		draw_rect(Rect2(-10.0, -7.0, 2.0, 2.0), c_cream)
		draw_rect(Rect2(8.0, -7.0, 2.0, 2.0), c_cream)
		draw_rect(Rect2(-10.0, 5.0, 2.0, 2.0), c_cream)
		draw_rect(Rect2(8.0, 5.0, 2.0, 2.0), c_cream)
	var lbl: String = "F%d" % floor_num
	LxPixelFont.draw_centered(self, lbl, 0.0, -2.0, c_cream if _unlocked else PAL["mauve"] as Color, 1, c_void)

	if _pulse_t > 0.0:
		var u: float = 1.0 - (_pulse_t / 0.45)
		draw_arc(Vector2.ZERO, roundf(10.0 + u * 18.0), 0.0, TAU, 16, Color(accent, 1.0 - u), 1.4)
	_draw_signal_pulses()
