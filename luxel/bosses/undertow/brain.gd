class_name LxUndertowBoss
extends LxBossBase
## Island 2 Superboss: THE UNDERTOW (`undertow`, `cave_undertow_maw`).
## Circular abyssal maelstrom kraken-vortex — 100% Island 2 Mastery Exam!
## - Central live `LxFields` maelstrom gravity well pulls constantly + 2 orbiting sea-glass mirrors
##   & 4 cardinal mooring piling markers.
## - Opening beat: politely spits up a lost sailor's boot & broken wooden oar during INTRO!
## - P2 (66%): Tide Reversal flips suction <-> outward geyser every 9s + floods outer corners + Mine Orbit.
## - P3 (33%): Splits into twin counter-rotating `gravity_well`s + submerges outer pilings + Twin-Eye Riptide!

const REVERSAL_PERIOD_S: float = 9.0

var _aim_dir: Vector2 = Vector2.LEFT
var _spoke_ang: float = 0.0
var _mirror_ang: float = 0.0
var _reversal_t: float = 0.0
var _is_geyser: bool = false
var _twin_eye_pos: Vector2 = Vector2.ZERO
var _gulp_active: bool = false
var _debris_t: float = 0.0
var _orbit_mines: Array[Dictionary] = [] # {ang, r, batted, pos, vel}
var _main_well: _UndertowWell = null
var _twin_well: _UndertowWell = null


class _UndertowWell:
	extends RefCounted
	var active: bool = false
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 148.0
	var radial_strength: float = 88.0
	var swirl_strength: float = 52.0
	var is_push: bool = false
	var swirl_sign: float = 1.0
	func is_field_active() -> bool:
		return active
	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active:
			return Vector2.ZERO
		var delta: Vector2 = pos - p
		var d: float = delta.length()
		if d < 14.0 or d > radius:
			return Vector2.ZERO
		var dn: Vector2 = delta / d
		var tang := Vector2(-dn.y, dn.x) * swirl_sign
		var rad_v: Vector2 = (-dn if is_push else dn) * radial_strength
		var mult: float = 1.05 if what in ["bolt", "lantern", "beam"] else (0.24 if what == "wick" else 0.35)
		return (rad_v + tang * swirl_strength) * mult


func _init() -> void:
	super._init()
	kind = "undertow"
	boss_id = "undertow"
	boss_name_key = "BOSS_UNDERTOW"
	island_id = 2
	is_miniboss = false
	reward_heart = "full"
	music_cue = "island2_boss_p1"
	music_p2_cue = "island2_boss_p2"
	max_hp = 128.0
	hp = 128.0
	body_radius = 14.0
	move_speed = 38.0
	stagger_threshold = 18.0
	stagger_duration = 1.85
	punish_dmg_mult = 1.38
	post_recover_cd = 0.34
	shard_drop = 60
	intro_duration = 0.85
	phase_shift_duration = 0.85
	death_duration = 2.4


func _exit_tree() -> void:
	_unregister_wells()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Spoke Sweeps (4 rotating sky spokes + eye volley + targeted whirlpool burst)
	register_attack("spoke_sweeps", {
		"weight": 1.25, "tell": 0.58, "commit": 0.40, "recover": 1.10, "cooldown": 1.45,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_spoke_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else 0.0
			for k: int in range(4):
				var sa: float = _spoke_ang + float(k) * (PI * 0.5)
				var sd: Vector2 = Vector2.from_angle(sa)
				ground.warn_lane(pos, pos + sd * 184.0, 8.5, last_tell_duration, 0.0, "sky", "ice")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.04, 1.0, "sky", "gold")
			stage.play_sfx("maelstrom_drone", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.RIGHT
			patterns.emit_spiral(pos, 4, 148.0 if phase >= 2 else 132.0, _spoke_ang, 0.30, 3 if phase >= 2 else 2, 0.14, {"color": "sky", "source": "undertow_spoke", "field_scale": 0.30})
			patterns.emit_fan(pos, aim, 3, 0.44, 168.0, {"color": "gold", "source": "undertow_fang", "field_scale": 0.20})
			stage.shake(0.16)
			stage.play_sfx("riptide_crack", pos),
	})

	# Attack 2: Abyssal Gulp (coral double-pull + perimeter rain -> Blue/Prism hits stun 1.6x!)
	register_attack("abyssal_gulp", {
		"weight": 1.25, "tell": 0.66, "commit": 0.55, "recover": 1.35, "cooldown": 1.65,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_gulp_active = true
			ground.warn_ring(pos, 64.0, last_tell_duration, 0.0, "coral", "gold")
			patterns.emit_rain(ground, _perimeter_targets(tgt), last_tell_duration, 24.0, 1.0, "coral", "gold")
			stage.play_sfx("undertow_inhale", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			if _main_well != null:
				_main_well.radial_strength = 140.0
				_main_well.is_push = false
			var gap_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else 0.0
			patterns.emit_gap_ring(pos, 16 if phase >= 2 else 12, 138.0, gap_a, 0.72, {"color": "coral", "source": "undertow_gulp", "field_scale": 0.25})
			stage.shake(0.20)
			stage.play_sfx("riptide_crack", pos),
		"on_recover": func(_b: LxBossBase, _dt: float) -> void:
			_gulp_active = false
			if _main_well != null:
				_main_well.radial_strength = 92.0
				_main_well.is_push = _is_geyser,
	})

	# Attack 3 (P2/P3): Mine Orbit (3 spiraling mines + expanding vortex wave — bat/harpoon mine into eye!)
	register_attack("mine_orbit", {
		"phases": [2, 3], "weight": 1.45, "tell": 0.56, "commit": 0.42, "recover": 1.15, "cooldown": 1.65,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			for k: int in range(3):
				var ma: float = anim_t + float(k) * (TAU / 3.0)
				ground.warn_ring(clamp_to_arena(pos + Vector2.from_angle(ma) * 56.0), 16.0, last_tell_duration, 0.0, "gold", "coral")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.06, 1.0, "coral", "gold")
			stage.play_sfx("mine_clang", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_orbit_mines.clear()
			for k: int in range(3):
				var ma: float = anim_t + float(k) * (TAU / 3.0)
				_orbit_mines.append({"ang": ma, "r": 58.0, "batted": false, "pos": pos + Vector2.from_angle(ma) * 58.0, "vel": Vector2.ZERO})
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			patterns.emit_fan(pos, aim, 5, 0.78, 152.0, {"color": "ice", "source": "undertow_mine_spray", "field_scale": 0.30})
			stage.shake(0.18)
			stage.play_sfx("tide_surge", pos),
	})

	# Attack 4 (P3): Twin-Eye Riptide (figure-8 dual-vortex lanes + twin counter-rotating spirals!)
	register_attack("twin_eye_riptide", {
		"phases": [3], "weight": 2.40, "tell": 0.68, "commit": 0.52, "recover": 1.30, "cooldown": 1.15,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_lane(pos, _twin_eye_pos, 11.0, last_tell_duration, 0.0, "sky", "gold")
			ground.warn_ring(clamp_to_arena(tgt), 24.0, last_tell_duration + 0.04, 1.0, "coral", "gold")
			ground.warn_ring(_twin_eye_pos, 32.0, last_tell_duration, 0.0, "sky", "cream")
			stage.play_sfx("maelstrom_drone", arena_rect.get_center()),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var a1: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else 0.0
			var a2: float = (tgt - _twin_eye_pos).angle() if tgt.distance_to(_twin_eye_pos) > 1.0 else PI
			patterns.emit_spiral(pos, 3, 126.0, a1, 0.36, 3, 0.14, {"color": "sky", "source": "riptide_eye_a", "field_scale": 0.85})
			patterns.emit_spiral(_twin_eye_pos, 3, 122.0, a2, -0.36, 3, 0.14, {"color": "gold", "source": "riptide_eye_b", "field_scale": 0.85})
			stage.shake(0.22)
			stage.play_sfx("riptide_crack", arena_rect.get_center()),
	})


func _on_reset_encounter() -> void:
	_unregister_wells()
	_spoke_ang = 0.0
	_mirror_ang = 0.0
	_reversal_t = 0.0
	_is_geyser = false
	_gulp_active = false
	_debris_t = 0.0
	_orbit_mines.clear()
	_twin_eye_pos = arena_rect.get_center() + Vector2(-46.0, 0.0)


func _on_engage() -> void:
	_debris_t = 1.6 # Politely spits up a sailor's boot & broken oar!
	if _main_well == null:
		_main_well = _UndertowWell.new()
	_main_well.pos = pos
	_main_well.active = true
	_main_well.is_push = false
	LxFields.add(_main_well)
	stage.play_sfx("maelstrom_drone", pos)


func _on_phase_enter(new_phase: int) -> void:
	var ts: float = 16.0
	var tx_w: int = int(floorf((arena_rect.position.x + 8.0) / ts))
	var tx_e: int = int(floorf((arena_rect.end.x - 20.0) / ts))
	var ty_n: int = int(floorf((arena_rect.position.y + 8.0) / ts))
	var ty_s: int = int(floorf((arena_rect.end.y - 20.0) / ts))
	if new_phase == 2:
		_is_geyser = true
		_reversal_t = 0.0
		if _main_well != null:
			_main_well.is_push = true
			_main_well.radial_strength = 96.0
		stage.set_tiles(world_ctx, Rect2i(tx_w, ty_n, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(tx_e, ty_s - 1, 1, 2), "water")
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.24)
		stage.play_sfx("riptide_crack", pos)
	elif new_phase == 3:
		if _twin_well == null:
			_twin_well = _UndertowWell.new()
		_twin_well.active = true
		_twin_well.swirl_sign = -1.0
		_twin_well.is_push = not _is_geyser
		_twin_well.radial_strength = 84.0
		LxFields.add(_twin_well)
		stage.set_tiles(world_ctx, Rect2i(tx_e, ty_n, 1, 2), "water")
		stage.set_tiles(world_ctx, Rect2i(tx_w, ty_s - 1, 1, 2), "water")
		stage.darkness_pulse(0.70, 1.1)
		stage.shake(0.28)
		stage.play_sfx("undertow_inhale", pos)


func _on_death_start() -> void:
	_unregister_wells()
	_orbit_mines.clear()
	if Lx.state != null:
		Lx.state.story_flags["undertow_defeated"] = true
	stage.play_sfx("abyss_chime", pos)


func _unregister_wells() -> void:
	if _main_well != null:
		_main_well.active = false
		LxFields.remove(_main_well)
		_main_well = null
	if _twin_well != null:
		_twin_well.active = false
		LxFields.remove(_twin_well)
		_twin_well = null


func _on_boss_tick(dt: float, target: Vector2) -> void:
	_debris_t = maxf(0.0, _debris_t - dt)
	_mirror_ang = wrapf(_mirror_ang + (0.95 if phase >= 2 else 0.62) * dt, -PI, PI)
	if phase >= 2:
		_reversal_t += dt
		if _reversal_t >= REVERSAL_PERIOD_S:
			_reversal_t = 0.0
			_is_geyser = not _is_geyser
			if _main_well != null and not _gulp_active:
				_main_well.is_push = _is_geyser
			if _twin_well != null:
				_twin_well.is_push = not _is_geyser
			stage.play_sfx("undertow_inhale" if not _is_geyser else "riptide_crack", pos)
	var c: Vector2 = arena_rect.get_center()
	if _main_well != null:
		_main_well.pos = pos
	if phase >= 3:
		_twin_eye_pos = clamp_to_arena(c - (pos - c))
		if _twin_well != null:
			_twin_well.pos = _twin_eye_pos
	_tick_orbit_mines(dt, target)


func _step_boss_reposition(dt: float, target: Vector2) -> void:
	var c: Vector2 = arena_rect.get_center()
	var r_orb: float = 36.0 if phase >= 3 else 18.0
	var des: Vector2 = clamp_to_arena(c + Vector2.from_angle(_mirror_ang * 0.7) * r_orb)
	move_boss((des - pos).limit_length(move_speed * dt), true)
	_face_point(target, 3.0, dt)


func _tick_orbit_mines(dt: float, target: Vector2) -> void:
	var lan_out: bool = _is_lantern_out()
	var lan_p: Vector2 = _get_lantern_pos()
	for i: int in range(_orbit_mines.size() - 1, -1, -1):
		var m: Dictionary = _orbit_mines[i]
		var mp: Vector2 = m["pos"] as Vector2
		if not bool(m["batted"]):
			m["ang"] = float(m["ang"]) + 1.55 * dt
			mp = clamp_to_arena(pos + Vector2.from_angle(float(m["ang"])) * float(m["r"]))
			if (lan_out and mp.distance_to(lan_p) <= 24.0) or (Lx.player is LxWick and is_instance_valid(Lx.player) and ((Lx.player as LxWick).is_dashing() or (Lx.player as LxWick).is_mounted()) and mp.distance_to(target) <= 24.0):
				m["batted"] = true
				m["vel"] = (pos - mp).normalized() * 175.0
				stage.play_sfx("mine_clang", mp)
		else:
			mp = clamp_to_arena(mp + (m["vel"] as Vector2) * dt)
			if mp.distance_to(pos) <= body_radius + 12.0:
				hp = maxf(0.5, hp - 4.0)
				add_stagger(stagger_threshold)
				stage.shake(0.24)
				stage.play_sfx("mine_blast", mp)
				_orbit_mines.remove_at(i)
				continue
		m["pos"] = mp


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	if hit.is_blue() or hit.source == LxHit.SOURCE_BEAM or hit.cracks_armour:
		if _gulp_active:
			add_stagger(4.0)
			return dmg * 1.60
		return dmg * 1.35
	# Swirling sea-glass vortex deflects a slice of un-curved off-window yellow bolts
	if not is_punishable() and hit.source == LxHit.SOURCE_BOLT and not hit.pierce:
		return dmg * 0.52
	return dmg


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
	return PAL["blue"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	# 1. Swirling maelstrom current ring (blue suction vs coral geyser)
	var vc: Color = PAL["coral"] as Color if _is_geyser else PAL["sky"] as Color
	draw_arc(off.round(), 54.0, anim_t * 1.6, anim_t * 1.6 + PI * 1.5, 24, Color(vc, 0.36), 1.4)
	# 2. 2 orbiting sea-glass mirrors
	for k: int in range(2):
		var ma: float = _mirror_ang + float(k) * PI
		var mp: Vector2 = (off + Vector2.from_angle(ma) * 66.0).round()
		var tang := Vector2(-sin(ma), cos(ma))
		draw_line((mp - tang * 7.0).round(), (mp + tang * 7.0).round(), PAL["blue"] as Color, 3.0)
		draw_line((mp - tang * 6.0).round(), (mp + tang * 6.0).round(), PAL["ice"] as Color, 1.4)
	# 3. P3 Twin Counter-Rotating Vortex Eye
	if phase >= 3:
		var tp: Vector2 = (_twin_eye_pos - pos + off).round()
		draw_arc(tp, 16.0, -anim_t * 2.4, -anim_t * 2.4 + PI * 1.6, 18, PAL["gold"] as Color, 1.8)
		draw_circle(tp, 9.0, PAL["deep"] as Color)
		draw_circle(tp, 4.5, PAL["coral" if not _is_geyser else "sky"] as Color)
		draw_circle(tp, 2.0, PAL["cream"] as Color)
	# 4. Orbiting P2/P3 mines
	for m: Dictionary in _orbit_mines:
		var mp2: Vector2 = ((m["pos"] as Vector2) - pos + off).round()
		draw_circle(mp2, 5.0, PAL["night"] as Color)
		draw_circle(mp2, 3.6, PAL["gold" if bool(m["batted"]) else "coral"] as Color)
	# 5. Opening beat: politely spat sailor's boot & broken wooden oar!
	if _debris_t > 0.0:
		var u: float = 1.0 - clampf(_debris_t / 1.6, 0.0, 1.0)
		var boot_p: Vector2 = (off + Vector2(-18.0 - u * 24.0, -14.0 - sin(u * PI) * 18.0)).round()
		var oar_p: Vector2 = (off + Vector2(18.0 + u * 26.0, -10.0 - sin(u * PI) * 16.0)).round()
		draw_rect(Rect2(boot_p, Vector2(5.0, 6.0)), PAL["wine"] as Color)
		draw_rect(Rect2(boot_p + Vector2(3.0, 3.0), Vector2(4.0, 3.0)), PAL["plum"] as Color)
		draw_line(oar_p + Vector2(-5.0, -3.0), oar_p + Vector2(5.0, 3.0), PAL["apricot"] as Color, 2.0)
