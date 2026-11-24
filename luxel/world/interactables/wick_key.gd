class_name LxWickKey
extends LxInteractable
## Dungeon key pickup: adds a small wick_key or boss keepers_flame into Lx.state.

var collected: bool = false
var key_kind: String = "wick_key"
var dungeon_id: String = ""
var requires_flag: String = ""
var _unlocked: bool = true
var _anim_frame: int = 0
var _pickup_t: float = 0.0


func _flag_satisfied() -> bool:
	if requires_flag.is_empty():
		return true
	if region != null and region.has_method("is_flag_set"):
		return bool(region.call("is_flag_set", requires_flag))
	return Lx.state != null and bool(Lx.state.story_flags.get(requires_flag, false))


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	var raw_kind: String = str(spec.get("kind", "wick_key"))
	key_kind = str(props.get("key_kind", "keepers_flame" if raw_kind == "keepers_flame" else "wick_key"))
	kind = "wick_key"
	dungeon_id = str(props.get("dungeon_id", "island_%d" % island_id))
	if dungeon_id.is_empty():
		dungeon_id = "island_%d" % island_id
	requires_flag = str(props.get("requires_flag", ""))
	collected = bool(props.get("collected", false))
	_unlocked = _flag_satisfied()
	active = (not collected) and _unlocked
	visible = active
	_pickup_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _pickup_t > 0.0:
		_pickup_t = maxf(0.0, _pickup_t - dt)
		visible = active or _pickup_t > 0.0
		queue_redraw()
		return
	if not collected and not _unlocked and _flag_satisfied():
		_unlocked = true
		active = true
		visible = true
		_emit_sfx("shrine_unlock")
		if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
			LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 14.0, 5.0)
		queue_redraw()
		return
	if collected or not active:
		return
	var fr: int = int(floorf(_clock * 6.0 + absf(pos.x * 0.05))) % 24
	if fr != _anim_frame:
		_anim_frame = fr
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or collected or not _unlocked:
		return false
	collected = true
	active = false
	_pickup_t = 0.36
	visible = true
	if Lx.state != null:
		Lx.state.add_key(dungeon_id, key_kind, 1)
		var flag_name: String = str(props.get("flag_id", props.get("sets_flag", "")))
		if not flag_name.is_empty():
			Lx.state.story_flags[flag_name] = true
	var is_boss: bool = key_kind == "keepers_flame"
	if Lx.events != null:
		Lx.events.narration_requested.emit("CUE_BOSS_KEY_FOUND" if is_boss else "CUE_KEY_FOUND", "title", 2.8 if is_boss else 2.4)
		Lx.events.shake_requested.emit(0.12 if is_boss else 0.08)
	if is_boss and Lx.hitstop != null:
		Lx.hitstop.trigger(0.05)
	_emit_gust(72.0 if is_boss else 52.0, 60.0 if is_boss else 42.0)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, pos, 16.0 if is_boss else 12.0, 6.0)
	_emit_sfx("key_pickup")
	_emit_save("key_" + id)
	queue_redraw()
	return true


func get_light_pool() -> Vector4:
	if _pickup_t > 0.0:
		var surge: float = sin((1.0 - clampf(_pickup_t / 0.36, 0.0, 1.0)) * PI) * (0.55 if LxHudFx.flash_reduced() else 1.0)
		return Vector4(pos.x, pos.y - 4.0, (56.0 if key_kind == "keepers_flame" else 42.0) * surge, 1.2 * surge)
	if collected or not active:
		return Vector4.ZERO
	var r: float = 42.0 if key_kind == "keepers_flame" else 30.0
	return Vector4(pos.x, pos.y - 4.0, r, 0.85)


func get_interact_prompt() -> String:
	return "" if (collected or not active or not _unlocked) else "PROMPT_TAKE_KEY"


func save_state() -> Dictionary:
	return {"active": active, "collected": collected}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	collected = bool(d.get("collected", collected))
	_unlocked = _flag_satisfied()
	active = (not collected) and _unlocked
	visible = active or _pickup_t > 0.0
	queue_redraw()


func _draw() -> void:
	if _pickup_t > 0.0:
		var u: float = 1.0 - clampf(_pickup_t / 0.36, 0.0, 1.0)
		var is_b: bool = key_kind == "keepers_flame"
		var b_gl: Color = LxBiomePalette.col(island_id, "glow")
		var ring_c: Color = (PAL["cream"] as Color) if u < 0.35 else ((PAL["coral"] as Color) if is_b else b_gl)
		draw_arc(Vector2(0.0, -3.0), roundf(lerpf(3.0, 22.0 if is_b else 18.0, u)), 0.0, TAU, 16, ring_c, 2.0 if u < 0.3 else 1.0, false)
		var scount: int = 8 if is_b else 6
		for k: int in range(scount):
			var a: float = (TAU * float(k)) / float(scount)
			var scol: Color = (PAL["cream"] as Color) if k % 2 == 0 else ((PAL["coral"] as Color) if is_b else b_gl)
			draw_rect(Rect2(roundf(cos(a) * lerpf(2.0, 18.0 if is_b else 15.0, u)), roundf(-3.0 + sin(a) * lerpf(2.0, 18.0 if is_b else 15.0, u) - u * 4.0), 1.0, 1.0), scol)
		return
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
	var gem_c: Color = (PAL["gold"] if is_boss else LxBiomePalette.col(island_id, "glow")) as Color
	draw_rect(Rect2(-1.0, y - 4.0, 2.0, 2.0), gem_c)
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
	# Subtle orbiting biome relic glints framing uncollected keys
	var k_spd: float = 0.14 if LxHudFx.flash_reduced() else 0.26
	var b_kg: Color = PAL["coral"] as Color if is_boss else LxBiomePalette.col(island_id, "glow")
	for oi: int in range(2):
		var oa: float = float(_anim_frame) * k_spd + float(oi) * PI
		var op := Vector2(roundf(cos(oa) * 7.0), roundf(y - 2.0 + sin(oa) * 3.5))
		draw_rect(Rect2(op, Vector2.ONE), core_c if oi == 0 else b_kg)
