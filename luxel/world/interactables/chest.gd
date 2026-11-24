class_name LxChest
extends LxInteractable
## Reward chest granting light shards, an ember piece, or a dungeon key.

const OPEN_DUR: float = 0.85
const RATTLE_DUR: float = 0.10

var opened: bool = false
var reward_kind: String = "shards"
var amount: int = 15
var dungeon_id: String = ""
var _glint_stage: int = 0
var _open_t: float = 0.0
var _pop_fired: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "chest"
	reward_kind = str(props.get("reward_kind", props.get("reward", "shards")))
	amount = maxi(1, int(props.get("amount", 15)))
	dungeon_id = str(props.get("dungeon_id", region_id))
	opened = bool(props.get("opened", false))
	_glint_stage = _get_glint_stage()
	_open_t = 0.0
	_pop_fired = false
	queue_redraw()


func tick(dt: float) -> void:
	_uses_prop_anim = false
	super.tick(dt)
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt)
		if not _pop_fired and (OPEN_DUR - _open_t) >= RATTLE_DUR:
			_fire_chest_pop()
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
	_open_t = OPEN_DUR
	_pop_fired = false
	if Lx.state != null:
		match reward_kind:
			"ember_piece":
				var gained_heart: bool = Lx.state.add_ember_piece()
				if not gained_heart:
					if Lx.events != null:
						Lx.events.narration_requested.emit("CUE_EMBER_FOUND", "title", 3.0)
					_emit_sfx("ember_pickup")
			"wick_key", "keepers_flame":
				Lx.state.add_key(dungeon_id, reward_kind, amount)
				if Lx.events != null:
					Lx.events.narration_requested.emit("CUE_BOSS_KEY_FOUND" if reward_kind == "keepers_flame" else "CUE_KEY_FOUND", "title", 2.8)
				_emit_sfx("key_pickup")
			_:
				Lx.state.add_shards(amount)
				_emit_sfx("shard_pickup")
	_emit_sfx("chest_open")
	_emit_save("chest_" + id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func _fire_chest_pop() -> void:
	_pop_fired = true
	var is_rare_r: bool = reward_kind == "ember_piece" or reward_kind == "keepers_flame"
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.16 if is_rare_r else 0.10)
		if is_rare_r:
			Lx.events.hitstop_requested.emit(0.07)
	if is_rare_r:
		if Lx.hitstop != null:
			Lx.hitstop.trigger(0.07)
		if Lx.camera != null and is_instance_valid(Lx.camera):
			Lx.camera.add_kick(Vector2.UP, 2.0)
		if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
			LxDarknessLayer.active_instance.trigger_focus_flash(0.55)
	_emit_gust(74.0 if is_rare_r else 56.0, 68.0 if is_rare_r else 52.0, Vector2(0.0, -6.0))
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR if is_rare_r else LxGroundDecals.Kind.BLOSSOM, pos, 15.0 if is_rare_r else 11.0, 6.0)


func get_light_pool() -> Vector4:
	if _open_t > 0.0:
		var u: float = clampf(_open_t / OPEN_DUR, 0.0, 1.0)
		var peak: float = 0.95 if LxHudFx.flash_reduced() else 1.40
		return Vector4(pos.x, pos.y - 6.0, 68.0 * (0.45 + 0.55 * u), peak * u)
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
	var el: float = OPEN_DUR - _open_t
	var in_rattle: bool = opened and _open_t > 0.0 and el < RATTLE_DUR
	var r_dx: float = (1.0 if int(floorf(el * 60.0)) % 2 == 0 else -1.0) if (in_rattle and LxHudFx.shake_enabled()) else 0.0
	var r_off := Vector2(r_dx, 1.0 if in_rattle else 0.0)
	var show_open: bool = opened and not in_rattle
	if not _draw_prop_sprite("chest", r_off, 1 if show_open else 0):
		_draw_fallback(show_open, r_off)
	if not opened:
		if reward_kind == "ember_piece" or reward_kind == "keepers_flame":
			var bg_c: Color = LxBiomePalette.col(island_id, "glow")
			var pa_c: float = 0.55 if LxHudFx.flash_reduced() else (0.38 + 0.34 * sin(_clock * 3.0 + pos.x * 0.04))
			draw_rect(Rect2(-6.0, -7.0, 1.0, 1.0), Color(bg_c, pa_c))
			draw_rect(Rect2(5.0, -7.0, 1.0, 1.0), Color(bg_c, pa_c))
		_draw_lid_glint(_get_glint_stage())
	elif in_rattle:
		var ru: float = clampf(el / RATTLE_DUR, 0.0, 1.0)
		var kr: float = roundf(lerpf(2.0, 6.0, ru))
		draw_line(Vector2(r_dx - kr, -3.0), Vector2(r_dx + kr, -3.0), PAL["gold"] as Color, 1.0)
		draw_line(Vector2(r_dx, -3.0 - kr), Vector2(r_dx, -3.0 + kr), PAL["gold"] as Color, 1.0)
		draw_rect(Rect2(r_dx - 1.0, -4.0, 2.0, 2.0), PAL["cream"] as Color)
	elif _open_t > 0.0:
		var u: float = clampf((el - RATTLE_DUR) / (OPEN_DUR - RATTLE_DUR), 0.0, 1.0)
		var is_rare: bool = reward_kind == "ember_piece" or reward_kind == "keepers_flame"
		var b_glow: Color = LxBiomePalette.col(island_id, "glow")
		var b_hi: Color = LxBiomePalette.col(island_id, "hi")
		if is_rare:
			var crest_y: float = roundf(-10.0 - u * 12.0)
			LxHudFx.draw_biome_crest(self, island_id, Vector2(0.0, crest_y), Color(b_glow, (1.0 - u) * 0.85), Color(PAL["cream"] as Color, (1.0 - u) * 0.92))
		if u < 0.48:
			var ru2: float = u / 0.48
			var rc: Color = (PAL["cream"] if ru2 < 0.3 else ((PAL["coral"] as Color) if is_rare else b_glow)) as Color
			draw_arc(Vector2(0.0, -7.0), roundf(lerpf(3.0, 20.0 if is_rare else 16.0, ru2)), 0.0, TAU, 16, Color(rc, 1.0 - ru2), 1.5 if ru2 < 0.35 else 1.0, false)
		if u < 0.65:
			var su: float = u / 0.65
			for k: int in range(8):
				var ang: float = -PI * 0.90 + float(k) * (PI * 0.80 / 7.0)
				var rad: float = lerpf(2.0, 17.0, su)
				var sx: float = roundf(cos(ang) * rad)
				var sy: float = roundf(-7.0 + sin(ang) * rad - su * 4.0)
				var alt_c: Color = (PAL["coral"] as Color) if is_rare else b_hi
				var sc: Color = (PAL["cream"] as Color) if su < 0.35 else (b_glow if k % 2 == 0 else alt_c)
				draw_rect(Rect2(sx, sy, 2.0 if su < 0.35 else 1.0, 2.0 if su < 0.35 else 1.0), Color(sc, 1.0 - su))
		# Physical hovering pixel reward icon rising smoothly y = -6 -> -22px + 4-point star glint
		var rise_u: float = 1.0 - pow(1.0 - clampf(u / 0.34, 0.0, 1.0), 3.0)
		var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(u * 12.0) * 1.0)
		var icon_y: float = roundf(lerpf(-6.0, -22.0, rise_u)) + (bob if u > 0.34 else 0.0)
		var icon_a: float = clampf((1.0 - u) / 0.22, 0.0, 1.0) if u > 0.78 else 1.0
		_draw_reward_icon(icon_y, icon_a, u)
	_draw_signal_pulses()


func _draw_reward_icon(ry: float, alpha: float, u: float) -> void:
	if alpha <= 0.02:
		return
	var cream := Color(PAL["cream"] as Color, alpha)
	var gold := Color(PAL["gold"] as Color, alpha)
	var apr := Color(PAL["apricot"] as Color, alpha)
	var coral := Color(PAL["coral"] as Color, alpha)
	var night := Color(PAL["night"] as Color, alpha)
	match reward_kind:
		"wick_key", "keepers_flame":
			var is_boss_k: bool = reward_kind == "keepers_flame"
			draw_rect(Rect2(-4.0, ry - 4.0, 8.0, 9.0), Color(PAL["void"] as Color, alpha * 0.85))
			draw_rect(Rect2(-3.0, ry - 3.0, 6.0, 4.0), coral if is_boss_k else gold)
			draw_rect(Rect2(-2.0, ry - 2.0, 4.0, 2.0), gold if is_boss_k else apr)
			draw_rect(Rect2(-1.0, ry - 2.0, 2.0, 1.0), cream)
			draw_rect(Rect2(-1.0, ry + 1.0, 2.0, 4.0), gold)
			draw_rect(Rect2(1.0, ry + 2.0, 2.0, 1.0), cream)
			draw_rect(Rect2(1.0, ry + 4.0, 2.0, 1.0), gold)
		"ember_piece":
			draw_rect(Rect2(-4.0, ry - 3.0, 8.0, 6.0), night)
			draw_rect(Rect2(-3.0, ry - 3.0, 2.0, 3.0), coral)
			draw_rect(Rect2(1.0, ry - 3.0, 2.0, 3.0), coral)
			draw_rect(Rect2(-3.0, ry - 2.0, 6.0, 3.0), coral)
			draw_rect(Rect2(-2.0, ry + 1.0, 4.0, 1.0), coral)
			draw_rect(Rect2(-1.0, ry + 2.0, 2.0, 1.0), apr)
			draw_rect(Rect2(-2.0, ry - 2.0, 4.0, 2.0), gold)
			draw_rect(Rect2(-2.0, ry - 2.0, 2.0, 1.0), cream)
		_:
			var ice := Color(PAL["ice"] as Color, alpha)
			var offsets: Array[Vector2] = [Vector2(0.0, -2.0), Vector2(-4.0, 1.0), Vector2(3.0, 1.0), Vector2(-1.0, 3.0)]
			for idx: int in range(offsets.size()):
				var p: Vector2 = offsets[idx] + Vector2(0.0, ry)
				var sc: Color = cream if idx == 0 else (gold if idx < 3 else ice)
				draw_rect(Rect2(p.x - 1.0, p.y - 1.0, 3.0, 3.0), night)
				draw_rect(Rect2(p.x, p.y - 1.0, 1.0, 3.0), sc)
				draw_rect(Rect2(p.x - 1.0, p.y, 3.0, 1.0), sc)
				draw_rect(Rect2(p.x, p.y, 1.0, 1.0), cream)
	# Crisp 4-point star glint orbiting upper-right corner of the hovering reward
	var gx: float = 5.0
	var gy: float = ry - 4.0
	var g_arm: float = 2.0 if (LxHudFx.flash_reduced() or int(floorf(u * 14.0)) % 2 == 0) else 3.0
	draw_line(Vector2(gx - g_arm, gy), Vector2(gx + g_arm, gy), gold, 1.0)
	draw_line(Vector2(gx, gy - g_arm), Vector2(gx, gy + g_arm), gold, 1.0)
	draw_rect(Rect2(gx, gy, 1.0, 1.0), cream)


func _draw_fallback(show_open: bool = false, r_off: Vector2 = Vector2.ZERO) -> void:
	draw_rect(Rect2(-7.0 + r_off.x, -6.0 + r_off.y, 14.0, 10.0), PAL["night"])
	draw_rect(Rect2(-6.0 + r_off.x, -5.0 + r_off.y, 12.0, 8.0), PAL["wine"])
	if show_open:
		draw_rect(Rect2(-6.0 + r_off.x, -8.0 + r_off.y, 12.0, 3.0), PAL["plum"])
		draw_rect(Rect2(-5.0 + r_off.x, -4.0 + r_off.y, 10.0, 3.0), PAL["dusk"])
	else:
		draw_rect(Rect2(-6.0 + r_off.x, -5.0 + r_off.y, 12.0, 2.0), PAL["gold"])
		draw_rect(Rect2(-2.0 + r_off.x, -3.0 + r_off.y, 4.0, 3.0), PAL["cream"])


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
	var is_rare: bool = reward_kind == "ember_piece" or reward_kind == "keepers_flame"
	var primary: Color = (PAL["coral"] if is_rare else PAL["gold"]) as Color
	if stage == 1:
		draw_rect(Rect2(gx, gy, 1.0, 1.0), primary)
	elif stage == 2:
		draw_rect(Rect2(gx, gy - 1.0, 1.0, 1.0), primary)
		draw_rect(Rect2(gx, gy + 1.0, 1.0, 1.0), primary)
		draw_rect(Rect2(gx - 1.0, gy, 1.0, 1.0), primary)
		draw_rect(Rect2(gx + 1.0, gy, 1.0, 1.0), primary)
		draw_rect(Rect2(gx, gy, 1.0, 1.0), PAL["cream"])
	else:
		draw_rect(Rect2(gx, gy, 1.0, 1.0), PAL["gold" if is_rare else "cream"])
