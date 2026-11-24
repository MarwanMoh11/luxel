class_name LxArchivistBoss
extends LxBossBase
## Island 8 Boss: The Archivist (Archive of Lost Lamps, archive_r12).
## Hooded moth-owl librarian with 8 biome ribbons & floating Open Folio Tome.
## Cycles 3 Chapters borrowing signature moves from the 7 Island Keepers you beat:
##   Ch.1 (100-66%, Bells & Tide): Bellkeeper Double-Toll + Hermit Fresnel Beam (reflectable -> 1.8s stagger)
##   Ch.2 (66-33%, Growth & Dusk): Briar Matron thorn lanes + Abbess Echo Clone + central Dusk Bell K
##   Ch.3 (<=33%, Stars, Kiln & Mirror): Astronomer Gravity Orbit + Kilnmother cross + Hollow Wick Zip-Feint!

class ArchiveGravityWell:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 92.0
	var strength: float = 360.0
	var active: bool = false

	func is_field_active() -> bool:
		return active

	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active or what == "wick":
			return Vector2.ZERO
		var delta: Vector2 = pos - p
		var d2: float = delta.length_squared()
		if d2 >= radius * radius or d2 <= 0.01:
			return Vector2.ZERO
		var dist: float = sqrt(d2)
		var u: float = clampf(1.0 - dist / radius, 0.0, 1.0)
		return (delta / dist) * (strength * (0.35 + 0.65 * u))


const RIBBON_COLS: Array[String] = ["gold", "sky", "jade", "lime", "blue", "coral", "ice", "rose"]
const KEEPER_IDS: Array[String] = [
	"bellkeeper", "lighthouse_hermit", "briar_matron", "heron_abbess",
	"astronomer", "kilnmother", "hollow_wick_boss",
]

var _borrowed_mask: Array[bool] = [true, true, true, true, true, true, true]
var _fresnel_ang: float = 0.0
var _echo_pos: Vector2 = Vector2.ZERO
var _echo_silenced_t: float = 0.0
var _feint_dest: Vector2 = Vector2.ZERO
var _feint_hit: bool = false
var _grav_well: ArchiveGravityWell = null
var _field_reg: bool = false
var _page_flash_t: float = 0.0
var _tome_open_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "archivist"
	boss_id = "archivist"
	boss_name_key = "ISL8_BOSS_ARCHIVIST"
	island_id = 8
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island8_boss_p1"
	music_p2_cue = "island8_boss_p2"
	max_hp = 220.0
	hp = 220.0
	body_radius = 13.0
	move_speed = 42.0
	stagger_threshold = 22.0
	stagger_duration = 1.80
	post_stagger_immunity = 4.0
	punish_dmg_mult = 1.35
	post_recover_cd = 0.30
	intro_duration = 0.60
	phase_shift_duration = 0.65
	death_duration = 2.4
	shard_drop = 48


func _exit_tree() -> void:
	_unregister_well()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33]) # 3 Chapters!

	# Shared All-Chapter Attack: Illuminated Bookmark Barrage (pressures all 8 perimeter spots)
	register_attack("folio_bookmark_barrage", {
		"weight": 0.90, "tell": 0.52, "commit": 0.34, "recover": 1.05, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = aim.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + aim * 150.0), 10.0, last_tell_duration, 0.0, _chapter_color(), "cream")
			patterns.emit_rain(ground, [clamp_to_arena(tgt), clamp_to_arena(tgt.lerp(pos, 0.32))], last_tell_duration + 0.04, 20.0, 1.0, _chapter_color(), "gold")
			stage.play_sfx("page_turn_heavy", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var cnt: int = 5 if phase < 3 else 7
			patterns.emit_fan(pos, aim, cnt, 0.92, 138.0 + float(phase) * 8.0, {"color": _chapter_color(), "source": "bookmark_dart", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("paper_snap", pos),
	})

	# Chapter 1A (Bellkeeper + Hermit): Bell-Fresnel Duet (Double-Toll + reflectable Fresnel Beam!)
	register_attack("ch1_bell_fresnel", {
		"phases": [1], "weight": 1.45, "tell": 0.58, "commit": 0.42, "recover": 1.20, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_fresnel_ang = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			var d1: Vector2 = Vector2.from_angle(_fresnel_ang)
			ground.warn_ring(pos, 52.0, last_tell_duration, 1.0, "gold", "cream")
			ground.warn_lane(pos, clamp_to_arena(pos + d1 * 170.0), 9.0, last_tell_duration, 0.0, "sky", "cream")
			stage.play_sfx("bell_toll_heavy", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var d1: Vector2 = Vector2.from_angle(_fresnel_ang)
			patterns.emit_chain_lightning([pos, clamp_to_arena(pos + d1 * 170.0)], 0.46, 9.0, 0.30, 1.0)
			patterns.emit_lane(pos, d1, 3, 152.0, 0.08, {"color": "sky", "source": "fresnel_beam", "reflectable": true})
			patterns.emit_gap_ring(pos, 10, 122.0, _fresnel_ang + 0.65, 0.78, {"color": "gold", "source": "double_toll"})
			stage.shake(0.20)
			stage.play_sfx("lighthouse_beam", pos),
	})

	# Chapter 1B (Bellkeeper + Tidewater): Tidal Bell-Toll Rain
	register_attack("ch1_tide_chord", {
		"phases": [1], "weight": 1.35, "tell": 0.54, "commit": 0.38, "recover": 1.12, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			var drops: Array[Vector2] = [clamp_to_arena(tgt), clamp_to_arena(tgt + aim.rotated(1.1) * 38.0), clamp_to_arena(tgt + aim.rotated(-1.1) * 38.0)]
			patterns.emit_rain(ground, drops, last_tell_duration, 21.0, 1.0, "sky", "gold")
			stage.play_sfx("bell_toll_heavy", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			patterns.emit_sweep_wall(pos, aim, 132.0, 7, 3, 2, 122.0, {"color": "sky", "source": "tide_wave_bolt", "reflectable": true})
			stage.shake(0.16)
			stage.play_sfx("bell_slam", pos),
	})

	# Chapter 2A (Briar Matron): Thorn-Lane Page (3 briar lanes + thorn petals)
	register_attack("ch2_briar_lanes", {
		"phases": [2], "weight": 1.50, "tell": 0.56, "commit": 0.46, "recover": 1.20, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			facing = aim.angle()
			for ang_off: float in [-0.42, 0.0, 0.42]:
				var d_v: Vector2 = aim.rotated(ang_off)
				ground.warn_lane(pos, clamp_to_arena(pos + d_v * 155.0), 8.0, last_tell_duration, 1.0, "jade", "lime", 1.1)
			stage.play_sfx("page_turn_heavy", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			patterns.emit_fan(pos, aim, 5, 1.05, 134.0, {"color": "jade", "source": "briar_thorn"})
			patterns.emit_pillars([clamp_to_arena(tgt), clamp_to_arena(tgt.lerp(pos, 0.42))], 0.52, 15.0, 0.55, 1.0, "lime")
			stage.shake(0.18)
			stage.play_sfx("thorn_burst", pos),
	})

	# Chapter 2B (Heron Abbess): Dusk Echo Clone Volley (silenced by central Dusk Bell K!)
	register_attack("ch2_echo_wing", {
		"phases": [2], "weight": 1.40, "tell": 0.54, "commit": 0.42, "recover": 1.18, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			_echo_pos = clamp_to_arena(c + (c - pos).limit_length(74.0))
			ground.warn_ring(_echo_pos, 22.0, last_tell_duration, 0.0, "lime", "cream")
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.04, 1.0, "jade", "gold")
			stage.play_sfx("wing_gale", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_main: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			patterns.emit_fan(pos, aim_main, 3, 0.52, 146.0, {"color": "lime", "source": "abbess_gust"})
			if _echo_silenced_t <= 0.0:
				var aim_e: Vector2 = (tgt - _echo_pos).normalized() if tgt.distance_to(_echo_pos) > 1.0 else Vector2.RIGHT
				patterns.emit_fan(_echo_pos, aim_e, 3, 0.48, 138.0, {"color": "ice", "source": "echo_clone"})
			stage.shake(0.16)
			stage.play_sfx("gust_whoosh", pos),
	})

	# Chapter 3A (Astronomer + Kilnmother): Star-Kiln Cross Finale
	register_attack("ch3_star_kiln_cross", {
		"phases": [3], "weight": 1.55, "tell": 0.62, "commit": 0.48, "recover": 1.35, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var ang: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			for k: int in range(4):
				var d_v: Vector2 = Vector2.from_angle(ang + float(k) * (PI * 0.5))
				ground.warn_lane(pos, clamp_to_arena(pos + d_v * 165.0), 8.5, last_tell_duration, 1.0, "coral", "gold", 1.2)
			stage.play_sfx("forge_gust", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			patterns.emit_orbit(pos, 5, 48.0, 2.1, 2.2, {"color": "sky", "source": "star_orbit"})
			patterns.emit_boomerang(pos, aim.rotated(0.32), 146.0, 0.64, 0.80, {"color": "gold", "source": "star_shard"})
			patterns.emit_boomerang(pos, aim.rotated(-0.32), 146.0, 0.64, -0.80, {"color": "coral", "source": "kiln_shard"})
			stage.shake(0.22)
			stage.play_sfx("forge_gust", pos),
	})

	# Chapter 3B (Hollow Wick Torn Page): Ink-Shadow Zip-Feint!
	register_attack("ch3_hollow_feint", {
		"phases": [3], "weight": 1.50, "tell": 0.58, "commit": 0.44, "recover": 1.30, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var to_t: Vector2 = tgt - pos
			var d_v: Vector2 = to_t.normalized() if to_t.length() > 1.0 else Vector2.LEFT
			_feint_dest = clamp_to_arena(tgt - d_v * 14.0)
			_feint_hit = false
			ground.warn_lane(pos, _feint_dest, 12.0, last_tell_duration, 0.0, "plum", "rose")
			ground.warn_ring(_feint_dest, 30.0, last_tell_duration + 0.08, 1.0, "rose", "cream")
			stage.play_sfx("hollow_dash", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.18)
			stage.play_sfx("zip_streak", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, el: float) -> void:
			if el < 0.28:
				var step_v: Vector2 = (_feint_dest - pos).limit_length(320.0 * dt)
				move_boss(step_v, true)
				if not _feint_hit and pos.distance_to(tgt) <= 22.0:
					_feint_hit = true
					var push: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.5 else Vector2.LEFT
					emit_boss_damage(push, 1.0, "hollow_zip_feint", pos, true)
			elif not _feint_hit:
				_feint_hit = true
				var aim_f: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
				patterns.emit_fan(pos, aim_f, 5, 0.88, 152.0, {"color": "ice", "source": "hollow_ink"})
	})


func _on_reset_encounter() -> void:
	_unregister_well()
	_refresh_borrowed_chapters()
	_fresnel_ang = facing
	_echo_pos = pos
	_echo_silenced_t = 0.0
	_feint_dest = pos
	_feint_hit = false
	_page_flash_t = 0.0
	_tome_open_t = 0.0


func _refresh_borrowed_chapters() -> void:
	var any_defeated: bool = false
	if Lx.state != null and not Lx.state.defeated_bosses.is_empty():
		for i: int in range(KEEPER_IDS.size()):
			var has_k: bool = Lx.state.defeated_bosses.has(KEEPER_IDS[i])
			_borrowed_mask[i] = has_k
			any_defeated = any_defeated or has_k
	if not any_defeated:
		for i: int in range(_borrowed_mask.size()):
			_borrowed_mask[i] = true


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	_page_flash_t = 0.70
	_tome_open_t = 2.4
	stage.play_sfx("page_turn_heavy", pos)
	if new_phase == 2:
		# Spawn central Dusk Bell K to silence the Ch.2 Echo Clone & stagger Tome!
		props.spawn_bell(c, _on_dusk_bell_rung, "archivist_bell")
		var cx_t: int = int(c.x / 16.0)
		var cy_t: int = int(c.y / 16.0)
		stage.set_tiles(world_ctx, Rect2i(maxi(2, cx_t - 5), maxi(2, cy_t - 2), 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(cx_t + 4, cy_t + 2, 1, 1), "pit")
		stage.darkness_pulse(0.62, 1.0)
		stage.shake(0.24)
	elif new_phase == 3:
		# Torn Island 7 page: activate subtle Starfall gravity well!
		_ensure_well()
		stage.darkness_pulse(0.72, 1.2)
		stage.shake(0.28)
		stage.play_sfx("bell_toll_heavy", pos)


func _on_dusk_bell_rung(_prop: Dictionary) -> void:
	_echo_silenced_t = 6.5
	stage.play_sfx("bell_toll_heavy", pos)
	stage.light_burst(arena_rect.get_center(), 84.0, 1.35, 0.35)
	if boss_state != BossState.STAGGER and boss_state != BossState.PHASE_SHIFT and boss_state != BossState.DEATH:
		add_stagger(stagger_threshold)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_echo_silenced_t = maxf(0.0, _echo_silenced_t - dt)
	_page_flash_t = maxf(0.0, _page_flash_t - dt)
	_tome_open_t = maxf(0.0, _tome_open_t - dt)
	if _grav_well != null and _field_reg:
		_grav_well.pos = arena_rect.get_center() + Vector2.from_angle(anim_t * 1.1) * 34.0


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	# Counterplay rewards matching the active Chapter's Keeper weakness!
	if phase == 1 and (hit.is_blue() or src == LxHit.SOURCE_PRISM or src == LxHit.SOURCE_BEAM):
		add_stagger(2.8)
		return dmg * 1.35
	if phase == 2 and (src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE or _echo_silenced_t > 0.0):
		return dmg * 1.30
	if phase == 3 and (src == LxHit.SOURCE_SUNFLARE or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_DASH):
		add_stagger(2.5)
		return dmg * 1.35
	return dmg


func _on_death_start() -> void:
	_unregister_well()
	stage.light_burst(pos, 118.0, 1.55, 0.50)
	stage.shake(0.28)
	stage.play_sfx("page_turn_heavy", pos)


func _ensure_well() -> void:
	if _grav_well == null:
		_grav_well = ArchiveGravityWell.new()
	_grav_well.pos = arena_rect.get_center()
	_grav_well.active = true
	if not _field_reg:
		LxFields.add(_grav_well)
		_field_reg = true


func _unregister_well() -> void:
	if _field_reg and _grav_well != null:
		_grav_well.active = false
		LxFields.remove(_grav_well)
		_field_reg = false


func _chapter_color() -> String:
	return "gold" if phase == 1 else ("jade" if phase == 2 else "rose")


func _body_color() -> Color:
	return LxPalette.color(_chapter_color(), "gold")


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = is_flash_reduced()
	# Giant glowing floor Tome illustration naming/framing the active Chapter!
	var center_loc: Vector2 = (arena_rect.get_center() - pos + off).round()
	var ch_col: Color = LxPalette.color(_chapter_color(), "gold")
	var page_r := Rect2(center_loc + Vector2(-42.0, -24.0), Vector2(84.0, 48.0))
	draw_rect(page_r, Color(ch_col, 0.10 if fred else 0.14), true)
	draw_rect(page_r, Color(ch_col, 0.35), false, 1.0)
	draw_line(center_loc + Vector2(0.0, -24.0), center_loc + Vector2(0.0, 24.0), Color(PAL["gold"] as Color, 0.40), 1.0)
	# Island 7's torn black-ink half-page in Chapter 3!
	if phase >= 3:
		var torn := Rect2(center_loc + Vector2(2.0, -22.0), Vector2(38.0, 44.0))
		draw_rect(torn, Color(PAL["void"] as Color, 0.45), true)
		draw_line(center_loc + Vector2(2.0, -22.0), center_loc + Vector2(18.0, 22.0), PAL["rose"] as Color, 1.2)
	# 8 biome ribbons orbiting the Archivist's Tome
	for i: int in range(8):
		var lit: bool = i == 7 or _borrowed_mask[mini(i, 6)]
		var a: float = anim_t * (0.75 if fred else 1.35) + float(i) * (TAU / 8.0)
		var rp: Vector2 = (c + Vector2(cos(a) * 24.0, sin(a) * 14.0 - 10.0)).round()
		var rcol: Color = LxPalette.color(RIBBON_COLS[i], "gold") if lit else (PAL["dusk"] as Color)
		draw_rect(Rect2(rp - Vector2.ONE, Vector2(2.0, 2.0)), rcol)
	# Ch.2 Dusk Echo Clone ghost marker when active
	if phase == 2 and _echo_silenced_t <= 0.0 and boss_state != BossState.DEATH:
		var ep: Vector2 = (_echo_pos - pos + off).round()
		draw_arc(ep, 10.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.2)
		draw_circle(ep, 4.0, Color(PAL["deep"] as Color, 0.55))
	# Ch.3 orbiting Starfall Gravity Well visual cue
	if _grav_well != null and _field_reg:
		var gp: Vector2 = (_grav_well.pos - pos + off).round()
		draw_arc(gp, 18.0, 0.0, TAU, 18, Color(PAL["sky"] as Color, 0.38), 1.0)
		draw_circle(gp, 3.0, PAL["cream"] as Color)
	# Page-turn golden sweep burst
	if _page_flash_t > 0.0:
		var u: float = 1.0 - clampf(_page_flash_t / 0.70, 0.0, 1.0)
		draw_arc(c, lerpf(12.0, 68.0, u), 0.0, TAU, 24, Color(PAL["cream"] as Color, 1.0 - u), 2.0)
