class_name LxDrownedChoirBoss
extends LxBossBase
## Island 4 Boss B (mausoleum_r12): The Drowned Choir.
## Five porcelain choral busts (V1..V5) singing in D minor (D5, F5, A5, C#6, D6) around a
## central Conductor Organ Bust! Silence the busts in exact singing order to crack their
## masks (3.5 dmg + Resonant Shatter stagger). Weather Wheel exposes veiled voices in P2/P3!

const BUST_COLORS: Array[String] = ["gold", "sky", "rose", "lime", "cream"]
const BUST_WEATHERS: Array[String] = ["sun", "rain", "any", "wind", "sun"]
const BUST_NOTES: Array[String] = [
	"choir_note_1", "choir_note_2", "choir_note_3", "choir_note_4", "choir_note_5",
]
const RESONANT_STAGGER_S: float = 2.10
const MASK_CRACK_DMG: float = 3.5

var _weather: String = "rain"
var _busts: Array[Dictionary] = []  # [{idx, pos, silenced, glow_t, flash_t, weather, color}]
var _stanza_seq: Array[int] = []
var _stanza_step: int = 0
var _stanza_active: bool = false
var _sing_timer: float = 0.0
var _sing_cursor: int = 0
var _wheel_pos: Vector2 = Vector2.ZERO
var _wheel_cd: float = 0.0
var _has_room_wheel: bool = false
var _death_petals: Array[Dictionary] = []


func _init() -> void:
	super._init()
	kind = "boss_drowned_choir"
	boss_id = "boss_drowned_choir"
	boss_name_key = "ISL4_BOSS_CHOIR"
	island_id = 4
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island4_boss_p1"
	music_p2_cue = "island4_boss_p2"
	max_hp = 104.0
	hp = 104.0
	body_radius = 12.0
	move_speed = 26.0
	stagger_threshold = 15.0
	stagger_duration = 1.85
	post_recover_cd = 0.30
	shard_drop = 65
	death_duration = 2.4


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.36])

	# Attack 1: Choral Stanza — sings 3 (P1) / 4 (P2) / 5 (P3) voices in order + glass-note volleys!
	register_attack("choral_stanza", {
		"weight": 1.40, "tell": 0.62, "commit": 0.44, "recover": 1.05, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_begin_new_stanza()
			var first_bi: int = _stanza_seq[0] if not _stanza_seq.is_empty() else 2
			var bp: Vector2 = _busts[first_bi]["pos"] as Vector2
			ground.warn_ring(bp, 20.0, last_tell_duration, 0.0, BUST_COLORS[first_bi], "cream")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.06, 1.0, "sky", "gold")
			stage.play_sfx(BUST_NOTES[first_bi], bp),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			# Each active voice in the stanza sings a resonant bolt toward Wick!
			for bi: int in _stanza_seq:
				if bi < 0 or bi >= _busts.size():
					continue
				var bp: Vector2 = _busts[bi]["pos"] as Vector2
				var d: Vector2 = (tgt - bp).normalized() if tgt.distance_to(bp) > 1.0 else Vector2.DOWN
				patterns.emit_fan(bp, d, 1 if phase == 1 else 2, 0.24, 132.0 + float(phase) * 8.0, {"color": BUST_COLORS[bi], "source": "choral_note"})
			stage.play_sfx("choir_chord", pos),
	})

	# Attack 2: Raindrop Curtain — sweeping wall across the nave + corner rain chime
	register_attack("raindrop_curtain", {
		"weight": 1.20, "tell": 0.58, "commit": 0.45, "recover": 1.00, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var horiz: bool = int(anim_t * 10.0) % 2 == 0
			if horiz:
				ground.warn_lane(Vector2(arena_rect.position.x + 10.0, c.y), Vector2(arena_rect.end.x - 10.0, c.y), arena_rect.size.y * 0.36, last_tell_duration, 0.0, "sky", "ice")
			else:
				ground.warn_lane(Vector2(c.x, arena_rect.position.y + 10.0), Vector2(c.x, arena_rect.end.y - 10.0), arena_rect.size.x * 0.36, last_tell_duration, 0.0, "sky", "ice")
			var drops: Array[Vector2] = [clamp_to_arena(tgt), _nearest_corner(tgt)]
			patterns.emit_rain(ground, drops, last_tell_duration, 22.0, 1.0, "sky", "cream")
			stage.play_sfx("deacon_rain_chime", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			var horiz: bool = int(anim_t * 10.0) % 2 == 0
			var gap_i: int = 3 if int(anim_t) % 2 == 0 else 5
			if horiz:
				patterns.emit_sweep_wall(Vector2(arena_rect.position.x + 12.0, c.y), Vector2.RIGHT, arena_rect.size.y - 22.0, 10, gap_i, 2, 124.0, {"color": "sky", "source": "raindrop_curtain"})
			else:
				patterns.emit_sweep_wall(Vector2(c.x, arena_rect.position.y + 12.0), Vector2.DOWN, arena_rect.size.x - 24.0, 11, gap_i, 2, 122.0, {"color": "ice", "source": "raindrop_curtain"})
			stage.shake(0.15)
			stage.play_sfx("marsh_splash", pos),
	})

	# Attack 3 (Phase 2 & 3): Tide Pulse Ring — expanding choral flood shockwave + gap ring
	register_attack("tide_pulse_ring", {
		"phases": [2, 3], "weight": 1.45, "tell": 0.55, "commit": 0.36, "recover": 1.05, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 58.0, last_tell_duration, 1.0, "sky", "coral")
			var drops: Array[Vector2] = [clamp_to_arena(tgt), _nearest_corner(tgt)]
			patterns.emit_rain(ground, drops, last_tell_duration + 0.05, 22.0, 1.0, "blue", "ice")
			stage.play_sfx("tide_surge", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var gap_a: float = (tgt - pos).angle() + 0.44
			patterns.emit_gap_ring(pos, 14 if phase >= 3 else 12, 124.0, gap_a, 0.72, {"color": "sky", "source": "tide_pulse_ring"})
			stage.light_burst(pos, 90.0, 1.35, 0.32)
			stage.shake(0.18)
			stage.play_sfx("choir_chord", pos),
	})

	# Attack 4 (Phase 3): Five-Voice Canon — grand Conductor Organ harmonic spiral + choral pillars!
	register_attack("five_voice_canon", {
		"phases": [3], "weight": 1.80, "tell": 0.64, "commit": 0.48, "recover": 1.18, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var pts: Array[Vector2] = [
				clamp_to_arena(tgt),
				_nearest_corner(tgt),
				clamp_to_arena(arena_rect.get_center().lerp(tgt, 0.5)),
			]
			patterns.emit_pillars(pts, last_tell_duration, 18.0, 0.48, 1.0, "gold")
			stage.play_sfx("choir_organ_swell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var base_a: float = (tgt - pos).angle()
			patterns.emit_spiral(pos, 5, 122.0, base_a, 0.36, 3, 0.16, {"color": "rose", "source": "five_voice_canon"})
			stage.shake(0.22)
			stage.play_sfx("choir_chord", pos),
	})


func _on_reset_encounter() -> void:
	_weather = _read_weather()
	_wheel_pos = arena_rect.get_center() + Vector2(0.0, 32.0)
	_wheel_cd = 0.0
	_has_room_wheel = _detect_room_wheel()
	_stanza_seq.clear()
	_stanza_step = 0
	_stanza_active = false
	_sing_timer = 0.0
	_sing_cursor = 0
	_death_petals.clear()
	_layout_choir_busts()


func _layout_choir_busts() -> void:
	_busts.clear()
	var c: Vector2 = arena_rect.get_center()
	var rx: float = minf(108.0, arena_rect.size.x * 0.38)
	var ry: float = minf(48.0, arena_rect.size.y * 0.32)
	for i: int in range(5):
		var frac: float = float(i) / 4.0
		var ang: float = lerpf(-PI * 0.88, -PI * 0.12, frac)
		var bp: Vector2 = clamp_to_arena(c + Vector2(cos(ang) * rx, sin(ang) * ry - 6.0))
		_busts.append({
			"idx": i, "pos": bp, "silenced": false, "glow_t": 0.0, "flash_t": 0.0,
			"weather": BUST_WEATHERS[i], "color": BUST_COLORS[i],
		})


func _begin_new_stanza() -> void:
	for b_d: Dictionary in _busts:
		b_d["silenced"] = false
	var count: int = 5 if phase >= 3 else (4 if phase == 2 else 3)
	var base_orders: Array = [
		[0, 2, 4, 1, 3],
		[2, 1, 3, 0, 4],
		[1, 3, 2, 4, 0],
	]
	var pick: Array = base_orders[int(attack_counts.get("choral_stanza", 0)) % base_orders.size()] as Array
	_stanza_seq.clear()
	for i: int in range(count):
		_stanza_seq.append(int(pick[i]))
	_stanza_step = 0
	_stanza_active = true
	_sing_cursor = 0
	_sing_timer = 0.42


func on_weather_changed(new_weather: String, _wind_dir: Vector2) -> void:
	var w: String = new_weather.strip_edges().to_lower()
	if w in ["sun", "rain", "wind"]:
		_weather = w


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# Outer choir stalls flood in RAIN (cleanly rolled back on reset!)
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(16, 2, 1, 2), "water")
		_weather = "rain"
		if Lx.vars != null:
			Lx.vars.set_var("dungeon:mausoleum", "weather", "rain")
		stage.darkness_pulse(0.60, 0.95)
		stage.shake(0.22)
		stage.play_sfx("choir_organ_swell", pos)
	elif new_phase == 3:
		# Conductor Organ rises fully with 2 acoustic organ pillars!
		props.spawn_pillar(clamp_to_arena(c + Vector2(-54.0, 20.0)), 4.0, "organ_pillar_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(54.0, 20.0)), 4.0, "organ_pillar_e")
		stage.darkness_pulse(0.70, 1.05)
		stage.shake(0.26)
		stage.play_sfx("choir_organ_swell", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_wheel_cd = maxf(0.0, _wheel_cd - dt)
	var live_w: String = _read_weather()
	if not live_w.is_empty():
		_weather = live_w

	for b_d: Dictionary in _busts:
		b_d["glow_t"] = maxf(0.0, float(b_d["glow_t"]) - dt)
		b_d["flash_t"] = maxf(0.0, float(b_d["flash_t"]) - dt)

	# Visual + audio stanza rehearsal pulse (0.55 s per note!)
	if _stanza_active and _sing_cursor < _stanza_seq.size():
		_sing_timer -= dt
		if _sing_timer <= 0.0:
			var bi: int = _stanza_seq[_sing_cursor]
			if bi >= 0 and bi < _busts.size():
				_busts[bi]["glow_t"] = 0.65
				stage.play_sfx(BUST_NOTES[bi], _busts[bi]["pos"] as Vector2)
			_sing_cursor += 1
			_sing_timer = 0.55

	_check_player_bust_shots()

	for pt: Dictionary in _death_petals:
		pt["pos"] = (pt["pos"] as Vector2) + (pt["vel"] as Vector2) * dt


func _check_player_bust_shots() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.move_bolt == null or not (w.move_bolt.get("bolts") is Array):
		return
	for b_v: Variant in (w.move_bolt.get("bolts") as Array):
		if not (b_v is Dictionary):
			continue
		var bd: Dictionary = b_v as Dictionary
		if not bool(bd.get("active", true)):
			continue
		var bp: Vector2 = bd.get("pos", Vector2.INF) as Vector2
		if not bp.is_finite():
			continue
		if not _has_room_wheel and _wheel_cd <= 0.0 and bp.distance_to(_wheel_pos) <= 13.0:
			_wheel_cd = 0.55
			_cycle_local_weather()
			bd["active"] = false
			continue
		if not _stanza_active or _stanza_step >= _stanza_seq.size():
			continue
		for b_d: Dictionary in _busts:
			if bool(b_d["silenced"]):
				continue
			var bpos: Vector2 = b_d["pos"] as Vector2
			if bp.distance_to(bpos) <= 13.0:
				bd["active"] = false
				_on_bust_shot(int(b_d["idx"]), bpos)
				break


func _on_bust_shot(bust_idx: int, bpos: Vector2) -> void:
	var expected: int = _stanza_seq[_stanza_step]
	if bust_idx == expected and _is_bust_exposed(bust_idx):
		_busts[bust_idx]["silenced"] = true
		_busts[bust_idx]["flash_t"] = 0.30
		_stanza_step += 1
		stage.play_sfx(BUST_NOTES[bust_idx], bpos)
		# Mask crack bonus damage directly into Conductor Organ!
		var crack_hit := LxHit.make(LxHit.SOURCE_PRISM, MASK_CRACK_DMG, Vector2.DOWN, bpos, 1.5, false, true, Lx.player)
		take_hit(crack_hit)
		if _stanza_step >= _stanza_seq.size():
			_stanza_active = false
			_trigger_resonant_shatter()
	else:
		# Wrong order or weather-veiled bust: mild telegraphed 36 px warning ripple (never unwarned!)
		_busts[bust_idx]["flash_t"] = 0.24
		ground.warn_ring(bpos, 36.0, 0.50, 1.0, "coral", "rose")
		stage.play_sfx("choir_discord", bpos)


func _is_bust_exposed(bust_idx: int) -> bool:
	if phase == 1:
		return true
	var need: String = str(_busts[bust_idx]["weather"])
	return need == "any" or need == _weather


func _trigger_resonant_shatter() -> void:
	stagger_immunity_t = 0.0
	stagger_meter = 0.0
	_release_token()
	active_attack_id = ""
	_set_boss_state(BossState.STAGGER, RESONANT_STAGGER_S)
	staggered.emit(RESONANT_STAGGER_S)
	LxDamageFx.boss_impact(pos, 0.22, 92.0, 92.0, 96.0, 1.44, 0.38, "ice")
	stage.play_sfx("choir_shatter", pos)


func _modify_incoming_damage(_hit: LxHit, dmg: float) -> float:
	if boss_state == BossState.STAGGER:
		return dmg * 1.75
	if not is_punishable():
		return dmg * 0.72
	return dmg


func _on_death_start() -> void:
	for b_d: Dictionary in _busts:
		b_d["silenced"] = true
	_death_petals.clear()
	for i: int in range(5):
		var bp: Vector2 = _busts[i]["pos"] as Vector2 if i < _busts.size() else pos
		_death_petals.append({"pos": bp, "vel": Vector2(0.0, -20.0 - float(i) * 3.0), "color": BUST_COLORS[i]})
	stage.play_sfx("choir_chord", pos)


func _cycle_local_weather() -> void:
	var order: Array[String] = ["sun", "rain", "wind"]
	_weather = order[(order.find(_weather) + 1) % order.size()]
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:mausoleum", "weather", _weather)
	stage.play_sfx("weather_shift_" + _weather, _wheel_pos)


func _read_weather() -> String:
	if Lx.vars != null:
		var ws: String = str(Lx.vars.get_var("dungeon:mausoleum", "weather", "")).strip_edges().to_lower()
		if ws in ["sun", "rain", "wind"]:
			return ws
	return _weather


func _detect_room_wheel() -> bool:
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_interactables"):
		for it_v: Variant in (world_ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and str((it_v as LxInteractable).kind) == "weather_wheel":
				return true
	return false


func _nearest_corner(tgt: Vector2) -> Vector2:
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	return corners[0]


func _body_color() -> Color:
	return (PAL["ice"] if phase >= 3 else (PAL["sky"] if phase == 2 else PAL["stone"])) as Color


func _draw_boss_extra(_off: Vector2) -> void:
	# Fallback center weather wheel in boss_lab
	if not _has_room_wheel:
		var wp: Vector2 = (_wheel_pos - pos).round()
		var wc: Color = (PAL["gold"] if _weather == "sun" else (PAL["ice"] if _weather == "wind" else PAL["sky"])) as Color
		draw_circle(wp, 10.0, Color(PAL["night"] as Color, 0.80))
		draw_arc(wp, 10.0, 0.0, TAU, 16, wc, 1.4)
		draw_circle(wp, 3.0, wc)

	# Draw the 5 Porcelain Choral Busts (V1..V5) with Roman pips, singing halos, & peaceful closed eyes!
	var next_target: int = _stanza_seq[_stanza_step] if (_stanza_active and _stanza_step < _stanza_seq.size()) else -1
	for b_d: Dictionary in _busts:
		var bi: int = int(b_d["idx"])
		var bp: Vector2 = ((b_d["pos"] as Vector2) - pos).round()
		var silenced: bool = bool(b_d["silenced"])
		var exposed: bool = _is_bust_exposed(bi)
		var col: Color = LxPalette.color(str(b_d["color"]), "gold")
		var is_next: bool = (bi == next_target and not silenced)
		var glowing: bool = float(b_d["glow_t"]) > 0.0 or is_next

		# Floor stave halo glow
		if glowing and not silenced:
			var r_h: float = 13.0 + (0.0 if is_flash_reduced() else sin(anim_t * 10.0) * 1.5)
			draw_arc(bp, r_h, 0.0, TAU, 16, col, 1.8 if is_next else 1.2)
		# Porcelain pedestal & bust head
		draw_circle(bp + Vector2(0.0, 4.0), 7.5, Color(PAL["void"] as Color, 0.45))
		draw_rect(Rect2(bp + Vector2(-6.0, -4.0), Vector2(12.0, 9.0)), (PAL["dusk"] if silenced else PAL["stone"]) as Color)
		var head_c: Color = (PAL["cream"] if float(b_d["flash_t"]) > 0.0 else (PAL["mauve"] if not exposed else (PAL["dusk"] if silenced else PAL["ice"]))) as Color
		draw_circle(bp + Vector2(0.0, -7.0), 5.5, head_c)
		draw_arc(bp + Vector2(0.0, -7.0), 5.5, 0.0, TAU, 12, PAL["night"] as Color, 1.1)
		if silenced:
			# Eyes closed peacefully
			draw_line(bp + Vector2(-3.0, -8.0), bp + Vector2(-1.0, -8.0), PAL["night"] as Color, 1.0)
			draw_line(bp + Vector2(1.0, -8.0), bp + Vector2(3.0, -8.0), PAL["night"] as Color, 1.0)
		else:
			# Open singing mouth ring in voice color
			draw_circle(bp + Vector2(0.0, -4.5), 2.4 if glowing else 1.5, col)
			draw_circle(bp + Vector2(0.0, -4.5), 1.0, PAL["void"] as Color)
		# Roman numeral pip bar below bust (1..5 pips)
		for pi: int in range(bi + 1):
			draw_rect(Rect2(bp + Vector2(-float(bi) + float(pi) * 2.0, 7.0), Vector2(1.0, 2.0)), col if not silenced else (PAL["mauve"] as Color))

	# Floating death crystal petals
	for pt: Dictionary in _death_petals:
		var pp: Vector2 = ((pt["pos"] as Vector2) - pos).round()
		var pc: Color = LxPalette.color(str(pt["color"]), "ice")
		draw_circle(pp, 3.0, pc)
		draw_rect(Rect2(pp, Vector2.ONE), PAL["cream"] as Color)
