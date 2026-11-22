class_name LxChest
extends LxInteractable
## Reward chest granting light shards, an ember piece, or a dungeon key.

var opened: bool = false
var reward_kind: String = "shards"
var amount: int = 15
var dungeon_id: String = ""
var _glint_stage: int = 0
var _open_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "chest"
	reward_kind = str(props.get("reward_kind", "shards"))
	amount = maxi(1, int(props.get("amount", 15)))
	dungeon_id = str(props.get("dungeon_id", region_id))
	opened = bool(props.get("opened", false))
	_glint_stage = _get_glint_stage()
	_open_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	_uses_prop_anim = false
	super.tick(dt)
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt)
		queue_redraw()
	if opened:
		return
	var stage: int = _get_glint_stage()
	if stage != _glint_stage:
		_glint_stage = stage
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or opened:
		return false
	opened = true
	_glint_stage = 0
	_open_t = 0.44
	if Lx.state != null:
		match reward_kind:
			"ember_piece":
				var gained_heart: bool = Lx.state.add_ember_piece()
				if Lx.events != null:
					Lx.events.narration_requested.emit("CUE_HEART_GAINED" if gained_heart else "CUE_EMBER_FOUND", "title", 3.0)
				_emit_sfx("heart_pickup" if gained_heart else "ember_pickup")
			"wick_key", "keepers_flame":
				Lx.state.add_key(dungeon_id, reward_kind, amount)
				if Lx.events != null:
					Lx.events.narration_requested.emit("CUE_KEY_FOUND", "title", 2.8)
				_emit_sfx("key_pickup")
			_:
				Lx.state.add_shards(amount)
				_emit_sfx("shard_pickup")
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.10)
	_emit_sfx("chest_open")
	_emit_save("chest_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if opened:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 34.0, 0.65)


func get_interact_prompt() -> String:
	return "" if opened else "PROMPT_OPEN_CHEST"


func save_state() -> Dictionary:
	return {"active": active, "opened": opened}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	opened = bool(d.get("opened", opened))
	queue_redraw()


func _draw() -> void:
	var shadow: Color = PAL["void"] as Color
	draw_rect(Rect2(-9.0, 1.0, 18.0, 2.0), shadow)
	draw_rect(Rect2(-7.0, 0.0, 14.0, 4.0), shadow)
	if not _draw_prop_sprite("chest", Vector2.ZERO, 1 if opened else 0):
		_draw_fallback()
	if not opened:
		_draw_lid_glint(_get_glint_stage())
	elif _open_t > 0.0:
		var u: float = 1.0 - clampf(_open_t / 0.44, 0.0, 1.0)
		if u < 0.55:
			draw_arc(Vector2(0.0, -7.0), roundf(lerpf(3.0, 16.0, u / 0.55)), 0.0, TAU, 14, (PAL["cream"] if u < 0.25 else PAL["gold"]) as Color, 1.0, false)
		for k: int in range(6):
			var ang: float = -PI * 0.85 + float(k) * (PI * 0.70 / 5.0)
			var rad: float = lerpf(2.0, 15.0, u)
			var sx: float = roundf(cos(ang) * rad)
			var sy: float = roundf(-7.0 + sin(ang) * rad - u * 4.0)
			var sc: Color = (PAL["cream"] if u < 0.35 else (PAL["gold"] if k % 2 == 0 else PAL["apricot"])) as Color
			draw_rect(Rect2(sx, sy, 2.0 if u < 0.4 else 1.0, 2.0 if u < 0.4 else 1.0), sc)


func _draw_fallback() -> void:
	draw_rect(Rect2(-7.0, -6.0, 14.0, 10.0), PAL["night"])
	draw_rect(Rect2(-6.0, -5.0, 12.0, 8.0), PAL["wine"])
	if opened:
		draw_rect(Rect2(-6.0, -8.0, 12.0, 3.0), PAL["plum"])
		draw_rect(Rect2(-5.0, -4.0, 10.0, 3.0), PAL["dusk"])
	else:
		draw_rect(Rect2(-6.0, -5.0, 12.0, 2.0), PAL["gold"])
		draw_rect(Rect2(-2.0, -3.0, 4.0, 3.0), PAL["cream"])


func _get_glint_stage() -> int:
	if opened:
		return 0
	var phase: float = fmod(absf(pos.x * 0.037 + pos.y * 0.053), 2.4)
	var t: float = fmod(_clock + phase, 2.4)
	if t >= 0.4:
		return 0
	if t < 0.1:
		return 1
	if t < 0.28:
		return 2
	return 3


func _draw_lid_glint(stage: int) -> void:
	if stage <= 0:
		return
	var gx: float = 0.0
	var gy: float = -8.0
	if stage == 1:
		draw_rect(Rect2(gx, gy, 1.0, 1.0), PAL["gold"])
	elif stage == 2:
		var c_gold: Color = PAL["gold"] as Color
		draw_rect(Rect2(gx, gy - 1.0, 1.0, 1.0), c_gold)
		draw_rect(Rect2(gx, gy + 1.0, 1.0, 1.0), c_gold)
		draw_rect(Rect2(gx - 1.0, gy, 1.0, 1.0), c_gold)
		draw_rect(Rect2(gx + 1.0, gy, 1.0, 1.0), c_gold)
		draw_rect(Rect2(gx, gy, 1.0, 1.0), PAL["cream"])
	else:
		draw_rect(Rect2(gx, gy, 1.0, 1.0), PAL["cream"])
