class_name LxWickKey
extends LxInteractable
## Dungeon key pickup: adds a small wick_key or boss keepers_flame into Lx.state.

var collected: bool = false
var key_kind: String = "wick_key"
var dungeon_id: String = ""
var _anim_frame: int = 0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	var raw_kind: String = str(spec.get("kind", "wick_key"))
	key_kind = str(props.get("key_kind", "keepers_flame" if raw_kind == "keepers_flame" else "wick_key"))
	kind = "wick_key"
	dungeon_id = str(props.get("dungeon_id", "island_%d" % island_id))
	if dungeon_id.is_empty():
		dungeon_id = "island_%d" % island_id
	collected = bool(props.get("collected", false))
	active = not collected
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if collected or not active:
		return
	var fr: int = int(floorf(_clock * 6.0 + absf(pos.x * 0.05))) % 24
	if fr != _anim_frame:
		_anim_frame = fr
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or collected:
		return false
	collected = true
	active = false
	if Lx.state != null:
		Lx.state.add_key(dungeon_id, key_kind, 1)
		var flag_name: String = str(props.get("flag_id", props.get("sets_flag", "")))
		if not flag_name.is_empty():
			Lx.state.story_flags[flag_name] = true
	_emit_sfx("key_pickup")
	_emit_save("key_" + id)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if collected or not active:
		return Vector4.ZERO
	var r: float = 42.0 if key_kind == "keepers_flame" else 30.0
	return Vector4(pos.x, pos.y - 4.0, r, 0.85)


func get_interact_prompt() -> String:
	return "" if collected else "PROMPT_TAKE_KEY"


func save_state() -> Dictionary:
	return {"active": active, "collected": collected}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	collected = bool(d.get("collected", collected))
	active = not collected
	queue_redraw()


func _draw() -> void:
	if collected or not active:
		return
	var bob: float = roundf(sin(float(_anim_frame) * TAU / 24.0) * 1.5)
	var is_boss: bool = key_kind == "keepers_flame"
	var body_c: Color = (PAL["coral"] if is_boss else PAL["apricot"]) as Color
	var hi_c: Color = (PAL["apricot"] if is_boss else PAL["gold"]) as Color
	var core_c: Color = PAL["cream"] as Color
	var sw: float = 6.0 if bob < 0.0 else 8.0
	draw_rect(Rect2(-floorf(sw * 0.5), 6.0, sw, 2.0), PAL["void"])
	draw_rect(Rect2(-floorf(sw * 0.5) + 1.0, 5.0, sw - 2.0, 1.0), PAL["night"])
	var y: float = bob - 1.0
	draw_rect(Rect2(-2.0, y - 8.0, 4.0, 2.0), PAL["void"])
	draw_rect(Rect2(-4.0, y - 6.0, 8.0, 5.0), PAL["void"])
	draw_rect(Rect2(-5.0, y - 5.0, 10.0, 3.0), PAL["void"])
	draw_rect(Rect2(-3.0, y - 1.0, 6.0, 2.0), PAL["void"])
	draw_rect(Rect2(-2.0, y + 1.0, 4.0, 6.0), PAL["void"])
	draw_rect(Rect2(1.0, y + 2.0, 4.0, 5.0), PAL["void"])
	draw_rect(Rect2(-1.0, y - 7.0, 2.0, 1.0), hi_c)
	draw_rect(Rect2(-3.0, y - 5.0, 6.0, 4.0), body_c)
	draw_rect(Rect2(-4.0, y - 4.0, 8.0, 2.0), body_c)
	draw_rect(Rect2(-3.0, y - 5.0, 4.0, 1.0), hi_c)
	draw_rect(Rect2(-4.0, y - 4.0, 1.0, 2.0), core_c)
	draw_rect(Rect2(-2.0, y - 4.0, 4.0, 2.0), PAL["night"])
	draw_rect(Rect2(-1.0, y - 4.0, 2.0, 2.0), PAL["gold"] if is_boss else hi_c)
	draw_rect(Rect2(-1.0, y - 4.0, 1.0, 1.0), core_c)
	draw_rect(Rect2(-2.0, y - 1.0, 4.0, 1.0), hi_c)
	draw_rect(Rect2(-1.0, y, 2.0, 6.0), body_c)
	draw_rect(Rect2(-1.0, y, 1.0, 5.0), hi_c)
	draw_rect(Rect2(1.0, y + 2.0, 3.0, 1.0), hi_c)
	draw_rect(Rect2(1.0, y + 3.0, 2.0, 1.0), body_c)
	draw_rect(Rect2(1.0, y + 5.0, 3.0, 1.0), hi_c)
	draw_rect(Rect2(2.0, y + 2.0, 1.0, 1.0), core_c)
	if _anim_frame >= 18 and _anim_frame <= 21:
		var sx: float = -4.0
		var sy: float = y - 6.0
		if _anim_frame == 19 or _anim_frame == 20:
			draw_rect(Rect2(sx - 1.0, sy, 3.0, 1.0), core_c)
			draw_rect(Rect2(sx, sy - 1.0, 1.0, 3.0), core_c)
		else:
			draw_rect(Rect2(sx, sy, 1.0, 1.0), PAL["gold"])
