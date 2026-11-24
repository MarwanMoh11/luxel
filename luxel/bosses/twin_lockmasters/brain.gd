class_name LxTwinLockmastersBoss
extends LxBossBase
## Island 2 Dungeon B Boss: THE TWIN LOCKMASTERS — Brine & Bilge (`twin_lockmasters`, `locks_r12`).
## Two crabs sharing ONE sea-glass hex shield across 4 Blue Portals & linked lock canals.
## - Brine (coral cleaver crab, primary pos) & Bilge (blue portal-sniper twin, live independent pos).
## - Shared shield teleports between them; hitting/lanterning mid-swap knocks it down 2.0s!
## - P2 (66%): Bilge flips `dungeon:locks` `lock_water` every 12s (sluice current LxFields + tile flood)
##   & unlocks Shield Swap.
## - P3 (33%): Both invade one canal with twin mines & Portal Pincer — dodge clear so twins collide & bicker 1.5s!

var _bilge_pos: Vector2 = Vector2.ZERO
var _bilge_facing: float = PI
var _portals: Array[Vector2] = []
var _portal_glow_idx: int = -1
var _portal_glow_t: float = 0.0
var _shield_holder: String = "brine" # "brine" | "bilge" | "flying" | "dropped"
var _shield_pos: Vector2 = Vector2.ZERO
var _shield_fly_u: float = 0.0
var _shield_dropped_t: float = 0.0
var _lock_water: String = "west_high"
var _lock_t: float = 0.0
var _bicker_t: float = 0.0
var _pincer_mid: Vector2 = Vector2.ZERO
var _pincer_hit: bool = false
var _aim_dir: Vector2 = Vector2.LEFT
var _sluice_field: _LockSluiceField = null


class _LockSluiceField:
	extends RefCounted
	var active: bool = false
	var dir_x: float = 1.0
	var strength: float = 58.0
	func is_field_active() -> bool:
		return active
	func field_accel(_p: Vector2, what: String) -> Vector2:
		if not active:
			return Vector2.ZERO
		if what in ["bolt", "lantern", "block"]:
			return Vector2(dir_x * strength, 0.0)
		return Vector2.ZERO


func _init() -> void:
	super._init()
	kind = "twin_lockmasters"
	boss_id = "twin_lockmasters"
	boss_name_key = "BOSS_TWINS"
	island_id = 2
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island2_boss_p1"
	music_p2_cue = "island2_boss_p2"
	max_hp = 68.0
	hp = 68.0
	body_radius = 11.0
	move_speed = 42.0
	stagger_threshold = 13.0
	stagger_duration = 1.55
	punish_dmg_mult = 1.45
	post_recover_cd = 0.32
	shard_drop = 32
	intro_duration = 0.75
	phase_shift_duration = 0.80
	death_duration = 2.4


func _exit_tree() -> void:
	_unregister_field()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Brine Cleaver (wide coral cleaver sector + shell fan)
	register_attack("brine_cleaver", {
		"weight": 1.20, "tell": 0.54, "commit": 0.26, "recover": 1.15, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_sector(pos, _aim_dir.angle() - 0.95, _aim_dir.angle() + 0.95, 58.0, last_tell_duration, 1.0, "coral", "gold")
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 124.0), 8.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("crab_shell_clank", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			patterns.emit_fan(pos, _aim_dir, 5 if phase >= 2 else 3, 0.82, 144.0, {"color": "coral", "source": "brine_cleave", "field_scale": 0.85})
			stage.shake(0.16)
			stage.play_sfx("crab_shell_clank", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_aim_dir * 108.0 * dt, false)
			check_contact_damage(body_radius + 11.0, _aim_dir, 1.0, "brine_cleaver"),
	})

	# Attack 2: Bilge Portal Snipe (glows exit portal & snipes blue lane through portal!)
	register_attack("bilge_portal_snipe", {
		"weight": 1.25, "tell": 0.58, "commit": 0.24, "recover": 1.10, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var ex_i: int = _pick_portal_nearest(tgt)
			_portal_glow_idx = ex_i
			_portal_glow_t = last_tell_duration + 0.30
			var ex_p: Vector2 = _portals[ex_i] if ex_i >= 0 else _bilge_pos
			var s_dir: Vector2 = (tgt - ex_p).normalized() if tgt.distance_to(ex_p) > 2.0 else Vector2.LEFT
			ground.warn_ring(ex_p, 20.0, last_tell_duration, 0.0, "sky", "ice")
			ground.warn_lane(ex_p, clamp_to_arena(ex_p + s_dir * 160.0), 8.0, last_tell_duration, 1.0, "sky", "cream")
			stage.play_sfx("portal_swap_chime", ex_p),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var ex_p: Vector2 = _portals[_portal_glow_idx] if (_portal_glow_idx >= 0 and _portal_glow_idx < _portals.size()) else _bilge_pos
			var s_dir: Vector2 = (tgt - ex_p).normalized() if tgt.distance_to(ex_p) > 2.0 else Vector2.LEFT
			patterns.emit_lane(ex_p, s_dir, 4 if phase >= 2 else 3, 162.0, 0.07, {"color": "sky", "source": "bilge_snipe", "field_scale": 0.85})
			# Bilge warps to the opposite portal!
			if _portals.size() >= 4:
				_bilge_pos = _portals[(_portal_glow_idx + 2) % _portals.size()]
			stage.shake(0.15)
			stage.play_sfx("prism_bounce", ex_p),
	})

	# Attack 3: Twin Lock Volley (pressures Wick + perimeter corners so zero safe spots!)
	register_attack("twin_lock_volley", {
		"weight": 1.15, "tell": 0.56, "commit": 0.30, "recover": 1.05, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration, 22.0, 1.0, "coral", "gold")
			stage.play_sfx("tide_surge", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d_br: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			var d_bi: Vector2 = (tgt - _bilge_pos).normalized() if tgt.distance_to(_bilge_pos) > 1.0 else Vector2.RIGHT
			patterns.emit_fan(pos, d_br, 3 if phase < 3 else 5, 0.65, 136.0, {"color": "coral", "source": "brine_volley", "field_scale": 0.8})
			patterns.emit_fan(_bilge_pos, d_bi, 3 if phase < 3 else 5, 0.65, 136.0, {"color": "sky", "source": "bilge_volley", "field_scale": 0.8})
			stage.shake(0.14)
			stage.play_sfx("barnacle_fire", _bilge_pos),
	})

	# Attack 4 (P2/P3): Shield Swap (blue sea-glass shield arcs between twins — lantern knocks it down!)
	register_attack("shield_swap", {
		"phases": [2, 3], "weight": 1.45, "tell": 0.50, "commit": 0.30, "recover": 1.05, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			ground.warn_lane(pos, _bilge_pos, 9.0, last_tell_duration, 0.0, "ice", "cream")
			stage.play_sfx("portal_swap_chime", pos.lerp(_bilge_pos, 0.5)),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var mid: Vector2 = pos.lerp(_bilge_pos, 0.5)
			if _is_lantern_out() and _get_lantern_pos().distance_to(mid) <= 34.0:
				_knock_down_shield()
				return
			_shield_holder = "bilge" if _shield_holder == "brine" else "brine"
			_shield_fly_u = 1.0
			patterns.emit_gap_ring(mid, 12, 118.0, (tgt - mid).angle(), 0.75, {"color": "ice", "source": "shield_arc", "field_scale": 0.7})
			stage.shake(0.15)
			stage.play_sfx("portal_swap_chime", mid),
	})

	# Attack 5 (P3): Portal Pincer (both twins charge through twin coral portals — dodge so they collide & bicker!)
	register_attack("portal_pincer", {
		"phases": [3], "weight": 1.65, "tell": 0.66, "commit": 0.38, "recover": 1.35, "cooldown": 1.75,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_pincer_mid = clamp_to_arena(tgt)
			_pincer_hit = false
			var flank_w: Vector2 = clamp_to_arena(_pincer_mid + Vector2(-72.0, 0.0))
			var flank_e: Vector2 = clamp_to_arena(_pincer_mid + Vector2(72.0, 0.0))
			pos = flank_w
			position = pos.round()
			_bilge_pos = flank_e
			ground.warn_ring(flank_w, 16.0, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_ring(flank_e, 16.0, last_tell_duration, 0.0, "coral", "sky")
			ground.warn_lane(flank_w, flank_e, 13.0, last_tell_duration, 1.0, "coral", "gold")
			stage.play_sfx("portal_swap_chime", _pincer_mid),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, el: float) -> void:
			move_boss((_pincer_mid - pos).normalized() * 145.0 * dt, true)
			_bilge_pos = clamp_to_arena(_bilge_pos.move_toward(_pincer_mid, 145.0 * dt))
			if check_contact_damage(body_radius + 10.0, (_pincer_mid - pos).normalized(), 1.0, "pincer_brine"):
				_pincer_hit = true
			if not _pincer_hit and el >= 0.30 and pos.distance_to(_bilge_pos) <= 28.0:
				if tgt.distance_to(_pincer_mid) > 22.0:
					# Twins collided and blame each other — 1.5s bicker stagger!
					_bicker_t = 1.50
					_shield_dropped_t = 2.0
					_shield_holder = "dropped"
					stage.shake(0.22)
					stage.play_sfx("twin_bicker_clack", _pincer_mid)
					add_stagger(stagger_threshold),
	})


func _on_reset_encounter() -> void:
	_unregister_field()
	_rebuild_portals()
	_bilge_pos = _portals[1] if _portals.size() >= 2 else (home + Vector2(-64.0, 0.0))
	_bilge_facing = 0.0
	_portal_glow_idx = -1
	_portal_glow_t = 0.0
	_shield_holder = "brine"
	_shield_pos = home
	_shield_fly_u = 0.0
	_shield_dropped_t = 0.0
	_lock_water = "west_high"
	_lock_t = 0.0
	_bicker_t = 0.0


func _on_engage() -> void:
	_rebuild_portals()
	if _portals.size() >= 4:
		_bilge_pos = _portals[0]
	stage.play_sfx("portal_swap_chime", pos)


func _rebuild_portals() -> void:
	var inset: Rect2 = arena_rect.grow(-26.0)
	_portals = [
		inset.position,
		Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y),
		inset.end,
	]


func _on_phase_enter(new_phase: int) -> void:
	var ts: float = 16.0
	var tx_w: int = int(floorf((arena_rect.position.x + 8.0) / ts))
	var tx_e: int = int(floorf((arena_rect.end.x - 20.0) / ts))
	var ty_n: int = int(floorf((arena_rect.position.y + 8.0) / ts))
	var ty_s: int = int(floorf((arena_rect.end.y - 20.0) / ts))
	if new_phase == 2:
		if _sluice_field == null:
			_sluice_field = _LockSluiceField.new()
		_sluice_field.active = true
		_sluice_field.dir_x = 1.0
		LxFields.add(_sluice_field)
		stage.set_tiles(world_ctx, Rect2i(tx_w, ty_n, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(tx_e, ty_n, 1, 2), "water")
		_flip_lock_water()
		stage.darkness_pulse(0.58, 0.95)
		stage.shake(0.22)
		stage.play_sfx("portal_swap_chime", pos)
	elif new_phase == 3:
		stage.set_tiles(world_ctx, Rect2i(tx_w, ty_s - 1, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(tx_e, ty_s - 1, 1, 2), "water")
		stage.darkness_pulse(0.66, 1.05)
		stage.shake(0.26)
		stage.play_sfx("twin_bicker_clack", pos)


func _on_death_start() -> void:
	_unregister_field()
	if Lx.state != null:
		Lx.state.story_flags["locks_done"] = true
	stage.play_sfx("shield_shatter", pos)


func _unregister_field() -> void:
	if _sluice_field != null:
		_sluice_field.active = false
		LxFields.remove(_sluice_field)
		_sluice_field = null


func _flip_lock_water() -> void:
	_lock_water = "east_high" if _lock_water == "west_high" else "west_high"
	if Lx.vars != null:
		Lx.vars.set_var("dungeon:locks", "lock_water", _lock_water)
	if _sluice_field != null:
		_sluice_field.dir_x = 1.0 if _lock_water == "west_high" else -1.0
	stage.play_sfx("tide_surge", arena_rect.get_center())


func _knock_down_shield() -> void:
	_shield_holder = "dropped"
	_shield_dropped_t = 2.0
	stage.shake(0.20)
	stage.play_sfx("shield_shatter", _shield_pos)
	add_stagger(stagger_threshold * 0.65)


func _on_boss_tick(dt: float, target: Vector2) -> void:
	_portal_glow_t = maxf(0.0, _portal_glow_t - dt)
	_bicker_t = maxf(0.0, _bicker_t - dt)
	_shield_fly_u = maxf(0.0, _shield_fly_u - dt * 3.0)
	if _shield_dropped_t > 0.0:
		_shield_dropped_t = maxf(0.0, _shield_dropped_t - dt)
		if _shield_dropped_t <= 0.0:
			_shield_holder = "brine"
	# Bilge circles opposite Brine & tracks target
	if boss_state != BossState.COMMIT and boss_state != BossState.STAGGER:
		var opp: Vector2 = clamp_to_arena(arena_rect.get_center() * 2.0 - pos)
		_bilge_pos = _bilge_pos.move_toward(opp, 38.0 * dt)
	if target.distance_to(_bilge_pos) > 1.0:
		_bilge_facing = (target - _bilge_pos).angle()
	# Update shared sea-glass shield position
	if _shield_holder == "brine":
		_shield_pos = pos + Vector2.from_angle(anim_t * 2.2) * 16.0
	elif _shield_holder == "bilge":
		_shield_pos = _bilge_pos + Vector2.from_angle(anim_t * 2.2) * 16.0
	# P2+ 12s linked lock-water flip
	if phase >= 2:
		_lock_t += dt
		if _lock_t >= 12.0:
			_lock_t = 0.0
			_flip_lock_water()


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	if _shield_dropped_t > 0.0:
		return dmg * 1.45
	if hit.is_blue() or hit.source == LxHit.SOURCE_BEAM or hit.cracks_armour:
		return dmg * 1.35
	if _shield_holder == "brine" and not is_punishable() and hit.source == LxHit.SOURCE_BOLT and not hit.pierce:
		clank_t = 0.10
		return dmg * 0.42
	return dmg


func _pick_portal_nearest(pt: Vector2) -> int:
	if _portals.is_empty():
		return -1
	var best_i: int = 0
	var best_d: float = INF
	for i: int in range(_portals.size()):
		var d: float = _portals[i].distance_squared_to(pt)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _perimeter_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
	if phase >= 3:
		out.append(corners[2])
	return out


func _body_color() -> Color:
	return PAL["coral"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	# 1. Draw the 4 arena Blue Portals
	for i: int in range(_portals.size()):
		var pp: Vector2 = (_portals[i] - pos + off).round()
		var glow: bool = (i == _portal_glow_idx and _portal_glow_t > 0.0)
		draw_arc(pp, 11.0 if glow else 9.0, 0.0, TAU, 16, PAL["cream" if glow else "blue"] as Color, 2.0 if glow else 1.2)
		draw_circle(pp, 5.5 if glow else 4.0, Color(PAL["ice" if glow else "sky"] as Color, 0.45 if glow else 0.25))

	# 2. Draw live twin Bilge (blue portal-sniper crab with brass monocle!)
	var bp: Vector2 = (_bilge_pos - pos + off).round()
	var b_bob: float = roundf(sin(anim_t * 5.0) * 1.2)
	var b_c: Vector2 = bp + Vector2(0.0, b_bob)
	draw_circle(bp + Vector2(0.0, 7.0), 9.0, Color(PAL["void"] as Color, 0.36))
	# Crab legs
	for sgn: float in [-1.0, 1.0]:
		draw_line(b_c + Vector2(sgn * 7.0, 1.0), b_c + Vector2(sgn * 13.0, 6.0), PAL["deep"] as Color, 1.6)
		draw_line(b_c + Vector2(sgn * 6.0, 4.0), b_c + Vector2(sgn * 11.0, 8.0), PAL["blue"] as Color, 1.4)
	# Blue armored carapace + keyhole crown
	draw_circle(b_c, 10.5, PAL["night"] as Color)
	draw_circle(b_c, 9.2, PAL["blue"] as Color)
	draw_circle(b_c + Vector2(-2.0, -2.5), 5.0, PAL["sky"] as Color)
	draw_rect(Rect2(b_c + Vector2(-3.0, -13.0), Vector2(6.0, 5.0)), PAL["gold"] as Color)
	draw_rect(Rect2(b_c + Vector2(-1.0, -11.5), Vector2(2.0, 2.0)), PAL["void"] as Color)
	# Face + gleaming brass sniper monocle!
	draw_rect(Rect2(b_c + Vector2(-6.0, -2.0), Vector2(12.0, 4.0)), PAL["void"] as Color)
	draw_rect(Rect2(b_c + Vector2(-4.0, -1.0), Vector2(2.0, 2.0)), PAL["ice"] as Color)
	draw_circle(b_c + Vector2(3.0, 0.0), 2.8, PAL["gold"] as Color)
	draw_circle(b_c + Vector2(3.0, 0.0), 1.6, PAL["cream"] as Color)
	# Sniper claw aiming along _bilge_facing
	var sdir: Vector2 = Vector2.from_angle(_bilge_facing)
	draw_line(b_c + sdir * 6.0, (b_c + sdir * 16.0).round(), PAL["sky"] as Color, 2.6)
	draw_circle((b_c + sdir * 16.0).round(), 2.2, PAL["cream"] as Color)

	# 3. Shared Sea-Glass Hex Shield & transfer ribbon
	if _shield_fly_u > 0.0:
		draw_line(off.round(), b_c, PAL["ice"] as Color, 2.0)
	if _shield_holder != "dropped":
		var sp: Vector2 = (_shield_pos - pos + off).round()
		var hex := PackedVector2Array()
		for k: int in range(7):
			var ha: float = anim_t * 2.0 + float(k % 6) * (TAU / 6.0)
			hex.append((sp + Vector2.from_angle(ha) * 7.5).round())
		draw_polyline(hex, PAL["cream"] as Color, 1.6)
		draw_circle(sp, 2.4, PAL["sky"] as Color)

	# 4. P3 Bicker clack sparks between twins
	if _bicker_t > 0.0 and not is_flash_reduced():
		var mid: Vector2 = off.lerp(b_c, 0.5).round()
		draw_arc(mid, 10.0 + sin(anim_t * 24.0) * 3.0, 0.0, TAU, 12, PAL["gold"] as Color, 1.5)
