class_name LxHollowWickBoss
extends LxBossBase
## Moon Shoals Boss (Island 7, spire_r10): HOLLOW WICK UNMASKED — The Game's Rival Duel!
## Migrated onto LxBossBase while preserving hollow_wick_boss art (including phase2 anim),
## boss_id = "hollow_wick", LURE interactivity, and all Island 7 Bible 4.7 upgrades:
## - Rival Dark-Mantle Guard outside punish windows (bolts chip with silver-rose parry glint;
##   hanging your lantern LUREs Hollow Wick and opens his guard; punish windows & clashes reward burst!).
## - P1 (100-66%): Honest mirror duel — Dark Bolt Volley, Flare Dash Riposte, Dark Lantern Zip.
## - P2 (66-33% — "THE MIRROR CRACKS OPEN!"): Diagonal NW Silver / SE Black arena fault +
##   carved mirror-rift pits + obsidian prism pillars + Mirrored Clone (SE black-lantern shadow vs
##   NW lie shadow; Blue/Beam or flipping moon_pool shatters Clone for 1.60s stagger!) +
##   Dark Beam + Mirror Crossfire.
## - P3 (<= 33% — "UNMASKED"): Widening fault + Eclipse Flare + Stolen Lantern Clash (0.58s
##   ice-coral intercept window while Dark Lantern flies — shoot or Zip/Dash-intercept to knock it
##   free for 2.20s clash stagger + 6.0 clash damage!) + pale moth shimmer + peaceful sky-blue death.

signal hollow_bolt_fired(origin: Vector2, dir: Vector2, boss: LxEnemyBrain)
signal hollow_lantern_thrown(origin: Vector2, target: Vector2, boss: LxEnemyBrain)

const DASH_SPEED: float = 268.0
const DASH_HIT_R: float = 18.0
const ZIP_THROW_TIME: float = 0.22
const CLASH_THROW_TIME_P3: float = 0.58
const ZIP_FLY_TIME: float = 0.26
const ZIP_BURST_R: float = 26.0
const BEAM_RANGE: float = 160.0
const BEAM_HALF_W: float = 9.5
const FLARE_START_R: float = 10.0
const FLARE_MAX_R: float = 70.0
const FLARE_BAND: float = 10.0
const FLARE_COMMIT_TIME: float = 0.32
const CLONE_SHATTER_STAGGER: float = 1.60
const CLASH_STAGGER: float = 2.20
const CLASH_DAMAGE: float = 6.0

var commit_dir: Vector2 = Vector2.LEFT
var dark_lantern_out: bool = false
var dark_lantern_pos: Vector2 = Vector2.ZERO
var _zip_started: bool = false
var _zip_hit: bool = false
var _dash_hit: bool = false
var _beam_hit: bool = false
var _flare_hit: bool = false
var _flare_progress: float = 0.0
var _volley_shots: int = 0
var _lure_opened_t: float = 0.0

var p2_split_active: bool = false
var clone_active: bool = false
var clone_pos: Vector2 = Vector2.ZERO
var clone_flash_t: float = 0.0
var clone_respawn_cd: float = 0.0
var _last_world_face: String = "silver"
var clash_window_open: bool = false
var clash_flash_t: float = 0.0
var _armour_glint_t: float = 0.0
var _armour_glint_ang: float = 0.0


func _init() -> void:
	super._init()
	kind = "hollow_wick_boss"; boss_id = "hollow_wick"; boss_name_key = "BOSS_HOLLOW"
	island_id = 7; is_miniboss = false; reward_heart = "full"
	music_cue = "island7_boss_p1"; music_p2_cue = "island7_boss_p2"
	max_hp = 520.0; hp = 520.0; body_radius = 6.5; move_speed = 54.0
	stagger_threshold = 32.0; stagger_duration = 1.80; punish_dmg_mult = 1.25
	post_recover_cd = 0.30; intro_duration = 0.50; phase_shift_duration = 0.68
	death_duration = 2.2; shard_drop = 45


func _configure_boss(spec: Dictionary) -> void:
	var base_hp: float = 520.0 * maxf(0.1, float(spec.get("hp_scale", 1.0)))
	max_hp = base_hp
	hp = base_hp
	kind = "hollow_wick_boss"
	boss_id = str(spec.get("boss_id", "hollow_wick"))
	island_id = int(spec.get("island_id", 7))
	configure_phases([0.66, 0.33])

	# Attack 1: Dark Bolt Volley — mirrors Wick's bolts & temper (3-bolt fan P1, 5-bolt spread P2+)
	register_attack("dark_bolt_volley", {
		"weight": 1.35, "tell": 0.46, "commit": 0.34, "recover": 1.00, "cooldown": 1.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var att: Vector2 = _attention_target(tgt)
			commit_dir = (att - pos).normalized() if att.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = commit_dir.angle()
			_volley_shots = 0
			ground.warn_lane(pos, clamp_to_arena(pos + commit_dir * 165.0), 10.0, last_tell_duration, 0.0, "sky", "gold")
			if tgt.distance_to(pos) > 95.0 or not _has_clear_view(pos, tgt):
				ground.warn_ring(tgt, 24.0, last_tell_duration, 1.0, "sky", "coral")
			stage.play_sfx("hollow_wick_tell", pos),
		"on_tell": func(_b: LxBossBase, tgt: Vector2, dt: float, _prog: float) -> void:
			if state_timer > 0.16 * get_tell_scale():
				var att: Vector2 = _attention_target(tgt)
				_face_point(att, 3.6, dt)
				commit_dir = Vector2.from_angle(facing),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_volley_shots = 0
			stage.play_sfx("bolt_fire", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, el: float) -> void:
			_step_volley_commit(el),
	})

	# Attack 2: Flare Dash Riposte — mirrors Wick's Flare Dash + shadow-spark fan at finish
	register_attack("flare_dash_riposte", {
		"weight": 1.25, "tell": 0.48, "commit": 0.28, "recover": 1.05, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var att: Vector2 = _attention_target(tgt)
			commit_dir = (att - pos).normalized() if att.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = commit_dir.angle()
			_dash_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + commit_dir * 96.0), 12.0, last_tell_duration, 0.0, "coral", "ice")
			stage.play_sfx("hollow_wick_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_dash_hit = false
			patterns.emit_fan(pos, -commit_dir, 3, 0.72, 118.0, {"color": "ice", "source": "hollow_dash_sparks", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("hollow_wick_commit", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(commit_dir * DASH_SPEED * dt, true)
			if not _dash_hit:
				_dash_hit = check_contact_damage(DASH_HIT_R, commit_dir, 1.0, "hollow_dash"),
	})

	# Attack 3: Dark Lantern Zip — mirrors Throw + Zip; P3 opens 0.58s Stolen Lantern Clash intercept window!
	register_attack("dark_lantern_zip", {
		"weight": 1.35, "tell": 0.52, "commit": 0.84, "recover": 1.10, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var att: Vector2 = _attention_target(tgt)
			commit_dir = (att - pos).normalized() if att.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = commit_dir.angle()
			dark_lantern_pos = clamp_to_arena(pos + commit_dir * clampf(att.distance_to(pos), 36.0, 240.0))
			_zip_started = false
			_zip_hit = false
			ground.warn_ring(dark_lantern_pos, ZIP_BURST_R, last_tell_duration, 0.0, "sky", "coral")
			stage.play_sfx("hollow_wick_tell", pos),
		"on_tell": func(_b: LxBossBase, tgt: Vector2, dt: float, _prog: float) -> void:
			if state_timer > 0.16 * get_tell_scale():
				var att: Vector2 = _attention_target(tgt)
				_face_point(att, 3.4, dt)
				commit_dir = Vector2.from_angle(facing)
				dark_lantern_pos = clamp_to_arena(pos + commit_dir * clampf(att.distance_to(pos), 36.0, 240.0)),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var th_dur: float = (CLASH_THROW_TIME_P3 * get_tell_scale()) if phase >= 3 else ZIP_THROW_TIME
			state_timer = th_dur + ZIP_FLY_TIME
			dark_lantern_pos = clamp_to_arena(dark_lantern_pos)
			dark_lantern_out = true
			clash_window_open = (phase >= 3)
			_zip_started = false
			_zip_hit = false
			hollow_lantern_thrown.emit(pos, dark_lantern_pos, self)
			stage.play_sfx("lantern_throw", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, el: float) -> void:
			_step_zip_commit(dt, el),
	})

	# Attack 4 (P2, P3): Dark Beam — piercing mirrored Lantern Beam (+ Clone shadow bolt in P2)
	register_attack("dark_beam", {
		"phases": [2, 3], "weight": 1.65, "tell": 0.56, "commit": 0.30, "recover": 1.18, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var att: Vector2 = _attention_target(tgt)
			commit_dir = (att - pos).normalized() if att.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = commit_dir.angle()
			_beam_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + commit_dir * BEAM_RANGE), BEAM_HALF_W, last_tell_duration, 0.0, "sky", "coral")
			if clone_active and phase == 2:
				var cd: Vector2 = (tgt - clone_pos).normalized() if tgt.distance_to(clone_pos) > 1.0 else -commit_dir
				ground.warn_lane(clone_pos, clamp_to_arena(clone_pos + cd * 110.0), 7.0, last_tell_duration, 0.0, "ice", "rose")
			stage.play_sfx("hollow_wick_tell", pos),
		"on_tell": func(_b: LxBossBase, tgt: Vector2, dt: float, _prog: float) -> void:
			if state_timer > 0.16 * get_tell_scale():
				var att: Vector2 = _attention_target(tgt)
				_face_point(att, 3.0, dt)
				commit_dir = Vector2.from_angle(facing),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_beam_hit = false
			LxDamageFx.boss_impact(pos, 0.16, 76.0, 72.0, 82.0, 1.40, 0.32, "ice")
			if clone_active and phase == 2:
				var cd: Vector2 = (tgt - clone_pos).normalized() if tgt.distance_to(clone_pos) > 1.0 else -commit_dir
				patterns.emit_fan(clone_pos, cd, 3, 0.45, 134.0, {"color": "ice", "source": "hollow_clone_bolt", "reflectable": true})
			stage.play_sfx("beam_fire", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, _el: float) -> void:
			_step_beam_commit(),
	})

	# Attack 5 (P2, P3): Mirror Crossfire — rains lunar-rift impacts on Wick & corners + crossing boomerangs
	register_attack("mirror_crossfire", {
		"phases": [2, 3], "weight": 1.55, "tell": 0.52, "commit": 0.34, "recover": 1.12, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			commit_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var spots: Array[Vector2] = _perimeter_targets(tgt, 4 if phase >= 3 else 3)
			patterns.emit_rain(ground, spots, last_tell_duration, 22.0, 1.0, "sky", "coral")
			stage.play_sfx("hollow_wick_tell", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else commit_dir
			patterns.emit_boomerang(pos, d.rotated(0.28), 146.0, 0.65, 0.55, {"color": "sky", "source": "hollow_boomerang", "reflectable": true})
			patterns.emit_boomerang(pos, d.rotated(-0.28), 146.0, 0.65, -0.55, {"color": "ice", "source": "hollow_boomerang", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("mirror_ping", pos),
	})

	# Attack 6 (P3): Eclipse Flare — mirrors Wick's Sunflare with 70px shockwave + 10-bolt gap-ring!
	register_attack("eclipse_flare", {
		"phases": [3], "weight": 2.40, "tell": 0.56, "commit": FLARE_COMMIT_TIME, "recover": 1.22, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			commit_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			_flare_hit = false
			_flare_progress = 0.0
			ground.warn_ring(pos, FLARE_MAX_R, last_tell_duration, 0.0, "sky", "coral")
			stage.play_sfx("hollow_wick_tell", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			_flare_hit = false
			_flare_progress = 0.0
			patterns.emit_gap_ring(pos, 10, 134.0, commit_dir.angle() + PI * 0.45, 0.78, {"color": "sky", "source": "hollow_eclipse_ring", "reflectable": true})
			LxDamageFx.boss_impact(pos, 0.24, 102.0, 100.0, 106.0, 1.48, 0.40, "ice")
			stage.play_sfx("sunflare_burst", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, _dt: float, _el: float) -> void:
			_step_flare_commit(),
	})


func _on_reset_encounter() -> void:
	dark_lantern_out = false; dark_lantern_pos = home
	_zip_started = false; _zip_hit = false; _dash_hit = false; _beam_hit = false
	_flare_hit = false; _flare_progress = 0.0; _volley_shots = 0; _lure_opened_t = 0.0
	p2_split_active = false; clone_active = false; clone_pos = home
	clone_flash_t = 0.0; clone_respawn_cd = 0.0; _last_world_face = _read_spire_face()
	clash_window_open = false; clash_flash_t = 0.0; _armour_glint_t = 0.0


func _on_attack_recover_start(_attack_id: String) -> void:
	dark_lantern_out = false
	clash_window_open = false


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	duel.tick_echo_recorder(dt)
	clone_flash_t = maxf(0.0, clone_flash_t - dt)
	clash_flash_t = maxf(0.0, clash_flash_t - dt)
	_armour_glint_t = maxf(0.0, _armour_glint_t - dt)
	_lure_opened_t = maxf(0.0, _lure_opened_t - dt)
	if _is_lured():
		_lure_opened_t = maxf(_lure_opened_t, 0.35)

	# P2 Mirror Clone tracking, world-flip shatter, & bolt interception
	if phase == 2 and boss_state != BossState.PHASE_SHIFT:
		var face_now: String = _read_spire_face()
		if face_now != _last_world_face:
			_last_world_face = face_now
			if clone_active:
				_shatter_mirror_clone()
		if clone_active:
			clone_pos = clamp_to_arena(home + (home - pos))
			_check_clone_bolts()
		elif clone_respawn_cd > 0.0:
			clone_respawn_cd = maxf(0.0, clone_respawn_cd - dt)
			if clone_respawn_cd <= 0.0 and boss_state == BossState.READY:
				clone_active = true
				clone_pos = clamp_to_arena(home + (home - pos))

	# P3 Flying Dark Lantern Clash intercept check
	if phase >= 3 and clash_window_open and dark_lantern_out and boss_state == BossState.COMMIT:
		_check_p3_lantern_clash()


func _step_volley_commit(el: float) -> void:
	var temper: String = duel.read_wick_temper()
	var max_shots: int = 5 if (phase >= 2 or temper == "scatter") else 3
	var interval: float = 0.065 if phase >= 2 else 0.10
	var expected: int = mini(max_shots, int(el / interval) + 1)
	var mid: float = float(max_shots - 1) * 0.5
	var spd: float = 162.0 if temper == "lance" else (148.0 if phase >= 2 else 136.0)
	while _volley_shots < expected:
		var bdir: Vector2 = commit_dir.rotated((float(_volley_shots) - mid) * 0.14)
		_volley_shots += 1
		hollow_bolt_fired.emit(pos, bdir, self)
		patterns.emit_fan(pos, bdir, 1, 0.0, spd, {"color": "sky" if phase >= 2 else "ice", "source": "hollow_bolt", "reflectable": true})


func _step_zip_commit(dt: float, el: float) -> void:
	var th_dur: float = (CLASH_THROW_TIME_P3 * get_tell_scale()) if phase >= 3 else ZIP_THROW_TIME
	if el < th_dur:
		return
	clash_window_open = false
	if not _zip_started:
		_zip_started = true
		stage.play_sfx("hollow_wick_zip", pos)
	var to_l: Vector2 = dark_lantern_pos - pos
	if to_l.length() > 3.0:
		move_boss(to_l.limit_length(340.0 * dt), true)
	if pos.distance_to(dark_lantern_pos) <= 7.0 and not _zip_hit:
		_zip_hit = true
		check_contact_damage(ZIP_BURST_R, commit_dir, 1.0, "hollow_zip")
		patterns.emit_fan(pos, commit_dir, 5 if phase >= 2 else 3, 1.05, 132.0, {"color": "ice", "source": "hollow_zip_burst", "reflectable": true})


func _step_beam_commit() -> void:
	var end_p: Vector2 = pos + commit_dir * BEAM_RANGE
	if not _beam_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, pos, end_p).distance_to(wp) <= BEAM_HALF_W and _has_clear_view(pos, wp):
			_beam_hit = true
			emit_boss_damage(commit_dir, 1.0, "hollow_dark_beam", pos, true)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= BEAM_HALF_W + 2.0 and Lx.events != null:
			Lx.events.lantern_struck.emit(lp)


func _step_flare_commit() -> void:
	_flare_progress = 1.0 - clampf(state_timer / FLARE_COMMIT_TIME, 0.0, 1.0)
	var ring_r: float = lerpf(FLARE_START_R, FLARE_MAX_R, _flare_progress)
	if not _flare_hit and _has_player():
		var wv: Vector2 = _get_wick_pos() - pos
		if absf(wv.length() - ring_r) <= FLARE_BAND:
			_flare_hit = true
			var push: Vector2 = wv.normalized() if wv.length() > 0.01 else commit_dir
			emit_boss_damage(push, 1.0, "shockwave", pos, true)
	if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= ring_r and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())


func _check_clone_bolts() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	for bi: int in range(w.bolts.size() - 1, -1, -1):
		var bv: Variant = w.bolts[bi]
		if bv is Object and (bv.get("pos") as Vector2).distance_to(clone_pos) <= 13.0:
			var is_b: bool = (str(bv.get("light_color")) == LxHit.COLOR_BLUE) or bool(bv.get("is_prism"))
			w.bolts.remove_at(bi)
			if is_b:
				_shatter_mirror_clone()
			else:
				clone_flash_t = 0.45
				stage.play_sfx("mirror_ping", clone_pos)
			break


func _check_p3_lantern_clash() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	for bi: int in range(w.bolts.size() - 1, -1, -1):
		var bv: Variant = w.bolts[bi]
		if bv is Object and (bv.get("pos") as Vector2).distance_to(dark_lantern_pos) <= 16.0:
			w.bolts.remove_at(bi)
			var cl_hit := LxHit.make(LxHit.SOURCE_BOLT, CLASH_DAMAGE, (dark_lantern_pos - w.global_position).normalized(), dark_lantern_pos, 1.0, true, true, w)
			_trigger_lantern_clash(cl_hit)
			return
	if (w.is_dashing() or w.is_zipping()) and w.global_position.distance_to(dark_lantern_pos) <= 24.0:
		var cl_hit2 := LxHit.make(LxHit.SOURCE_ZIP, CLASH_DAMAGE, (pos - w.global_position).normalized(), dark_lantern_pos, 1.0, true, true, w)
		_trigger_lantern_clash(cl_hit2)


func _trigger_lantern_clash(hit: LxHit) -> int:
	clash_window_open = false
	dark_lantern_out = false
	clash_flash_t = 0.65
	_release_token()
	active_attack_id = ""
	hp = maxf(0.0, hp - CLASH_DAMAGE)
	flash_t = 0.22
	LxDamageFx.boss_impact(dark_lantern_pos, 0.24, 96.0, 96.0, 94.0, 1.48, 0.36, "ice")
	stage.play_sfx("perfect_counter", dark_lantern_pos)
	stage.play_sfx("mirror_ping", dark_lantern_pos)
	if hp <= 0.001:
		opened_kill = true
		_begin_death(hit)
		return HitResult.KILLED
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, CLASH_STAGGER)
	staggered.emit(CLASH_STAGGER)
	_emit_enemy_hit(hit, HitResult.OPENED)
	return HitResult.OPENED


func _shatter_mirror_clone() -> void:
	if not clone_active:
		return
	clone_active = false
	clone_respawn_cd = 10.0
	clone_flash_t = 0.0
	LxDamageFx.boss_impact(clone_pos, 0.18, 76.0, 74.0, 76.0, 1.36, 0.30, "ice")
	stage.play_sfx("shield_shatter", clone_pos)
	_release_token()
	active_attack_id = ""
	dark_lantern_out = false
	clash_window_open = false
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, CLONE_SHATTER_STAGGER)
	staggered.emit(CLONE_SHATTER_STAGGER)


func take_hit(hit: LxHit) -> int:
	if boss_state == BossState.DEATH or hit == null:
		return HitResult.GLANCED
	if not engaged:
		if not arena_rect.grow(2.0).has_point(_get_wick_pos()):
			clank_t = 0.12
			_emit_enemy_hit(hit, HitResult.GLANCED)
			return HitResult.GLANCED
		engage()
	if boss_state == BossState.INTRO or boss_state == BossState.PHASE_SHIFT:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	if phase >= 3 and clash_window_open and dark_lantern_out:
		var h_cl: Dictionary = _read_hit(hit)
		var src_cl: String = str(h_cl["source"])
		if src_cl in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or hit.is_blue():
			return _trigger_lantern_clash(hit)
	return super.take_hit(hit)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var is_pierce: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["pierce"])

	if is_pierce:
		return dmg * (1.10 if boss_state == BossState.STAGGER else (0.96 if is_punishable() else 0.86))
	if boss_state == BossState.STAGGER:
		return dmg * 1.15
	if boss_state == BossState.RECOVER:
		return dmg
	if _lure_opened_t > 0.0:
		return dmg * 0.65

	# Rival Dark-Mantle Guard outside punish windows: bolts chip with silver-rose parry glint!
	_armour_glint_t = 0.22
	_armour_glint_ang = rel.angle() if rel.length() > 1.0 else facing
	clank_t = 0.12
	if src == LxHit.SOURCE_BOLT:
		stage.play_sfx("mirror_ping", pos)
		return dmg * 0.14
	return dmg * 0.28


func _on_phase_enter(new_phase: int) -> void:
	dark_lantern_out = false
	clash_window_open = false
	_flare_progress = 0.0
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		p2_split_active = true
		clone_active = true
		clone_pos = clamp_to_arena(home + (home - pos))
		_last_world_face = _read_spire_face()
		_carve_safe_pit(0.32, 0.34)
		_carve_safe_pit(0.68, 0.64)
		props.spawn_pillar(clamp_to_arena(c + Vector2(-62.0, 26.0)), 4.5, "hw_prism_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(62.0, -26.0)), 4.5, "hw_prism_e")
		stage.darkness_pulse(0.60, 1.1)
		stage.shake(0.32)
		stage.play_sfx("hollow_wick_phase", pos)
	elif new_phase == 3:
		clone_active = false
		_carve_safe_pit(0.36, 0.64)
		_carve_safe_pit(0.64, 0.34)
		stage.darkness_pulse(0.68, 1.2)
		stage.shake(0.34)
		stage.play_sfx("hollow_wick_phase", pos)


func _on_death_start() -> void:
	clone_active = false
	dark_lantern_out = false
	clash_window_open = false
	stage.light_burst(pos, 108.0, 1.45, 0.45)
	stage.play_sfx("lens_reveal", pos)
	stage.play_sfx("great_lamp_bloom", pos)


func _is_lured() -> bool:
	return _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= 136.0


func _attention_target(fallback_tgt: Vector2) -> Vector2:
	return _get_lantern_pos() if _is_lured() else fallback_tgt


func _read_spire_face() -> String:
	if Lx.vars == null:
		return "silver"
	return "black" if Lx.vars.eval("world_face==black", 7, "spire_r10") else "silver"


func _carve_safe_pit(fx: float, fy: float) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return
	var wp := Vector2(lerpf(arena_rect.position.x, arena_rect.end.x, fx), lerpf(arena_rect.position.y, arena_rect.end.y, fy))
	var tx: int = int(wp.x / 16.0)
	var ty: int = int(wp.y / 16.0)
	var center_p := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	if world_ctx.has_method("tile_at") and str(world_ctx.call("tile_at", center_p)) in ["ground", "path"]:
		stage.set_tiles(world_ctx, Rect2i(tx, ty, 1, 1), "pit")


func _perimeter_targets(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, corners.size())):
		out.append(clamp_to_arena(corners[i]))
	return out


func _body_color() -> Color:
	if phase >= 3:
		return PAL["dusk"] as Color
	return (PAL["deep"] if phase >= 2 else PAL["night"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = is_flash_reduced()

	# Bible 4.7: P2 diagonal NW Silver / SE Black split & truth shadow
	if p2_split_active and boss_state != BossState.DEATH:
		var hc: Vector2 = (home - pos).round()
		draw_line(hc + Vector2(-130.0, 82.0), hc + Vector2(130.0, -82.0), Color(PAL["ice"] as Color, 0.45), 2.0)
		draw_line(hc + Vector2(-130.0, 82.0), hc + Vector2(130.0, -82.0), Color(PAL["rose"] as Color, 0.65), 1.0)
	if phase >= 2 and boss_state != BossState.DEATH:
		LxIsland7Rule.draw_truth_shadow(self, Vector2(0.0, 4.0), 8.0, 3.0, "black_lantern", false)

	# P2 Mirrored Clone (NW lie shadow! Flashes silver on decoy bolt hit)
	if clone_active and phase == 2:
		var cl: Vector2 = (clone_pos - pos).round()
		LxIsland7Rule.draw_truth_shadow(self, cl + Vector2(0.0, 4.0), 7.5, 2.8, "nw_wrong", false)
		draw_circle(cl, body_radius + 1.0, Color(PAL["deep"] as Color, 0.72))
		draw_arc(cl, body_radius + 2.5, 0.0, TAU, 14, (PAL["cream"] if clone_flash_t > 0.0 else PAL["ice"]) as Color, 1.0)
		if clone_flash_t > 0.0:
			draw_arc(cl, body_radius + 8.0, 0.0, TAU, 16, PAL["sky"] as Color, 1.0)

	# P3 Unmasked pale moth shimmer
	if phase >= 3 and boss_state != BossState.DEATH:
		draw_arc(c + Vector2(0.0, -4.0), 5.0, 0.0, TAU, 12, Color(PAL["ice"] as Color, 0.65), 1.0)

	# Rival Dark-Mantle parry glint when bolts chip outside openings
	if _armour_glint_t > 0.0 and boss_state != BossState.DEATH:
		var ga: float = clampf(_armour_glint_t / 0.22, 0.0, 1.0)
		draw_arc(c, body_radius + 5.0, _armour_glint_ang - 0.85, _armour_glint_ang + 0.85, 10, Color(PAL["rose"] as Color, ga), 2.0)
		draw_arc(c, body_radius + 3.5, _armour_glint_ang - 0.55, _armour_glint_ang + 0.55, 8, Color(PAL["ice"] as Color, ga), 1.0)

	# Flying Dark Lantern & P3 Stolen Lantern Clash tell
	if dark_lantern_out and boss_state != BossState.DEATH:
		var lp: Vector2 = (dark_lantern_pos - pos).round()
		draw_circle(lp, 4.5, PAL["void"] as Color)
		draw_arc(lp, 5.5, 0.0, TAU, 14, PAL["sky"] as Color, 1.0)
		if phase >= 3 and clash_window_open:
			var cu: float = clampf(_commit_elapsed / maxf(CLASH_THROW_TIME_P3 * get_tell_scale(), 0.05), 0.0, 1.0)
			var cr: float = roundf(lerpf(18.0, 8.0, cu))
			draw_arc(lp, cr, 0.0, TAU, 18, PAL["void"] as Color, 3.0)
			draw_arc(lp, cr, 0.0, TAU, 18, PAL["coral"] as Color, 2.0)
			draw_arc(lp, 11.0, 0.0, TAU, 16, PAL["ice"] as Color, 1.0)
			var tc: Color = (PAL["cream"] if (fred or int(anim_t * 8.0) % 2 == 0) else PAL["gold"]) as Color
			for ti: int in range(4):
				var td: Vector2 = Vector2.from_angle(float(ti) * (PI * 0.5))
				var p0: Vector2 = (lp + td * (cr - 2.0)).round()
				var p1: Vector2 = (lp + td * (cr + (2.0 if fred else 3.0))).round()
				draw_line(p0, p1, PAL["void"] as Color, 3.0)
				draw_line(p0, p1, tc, 1.0)
			draw_circle(lp, 2.5, PAL["cream"] as Color)

	if clash_flash_t > 0.0:
		var cf: float = 1.0 - clampf(clash_flash_t / 0.65, 0.0, 1.0)
		draw_arc(c, roundf(lerpf(10.0, 38.0, cf)), 0.0, TAU, 22, Color(PAL["ice"] as Color, 1.0 - cf), 2.0)

	if boss_state == BossState.COMMIT and active_attack_id == "dark_beam":
		var b_end: Vector2 = (off + commit_dir * BEAM_RANGE).round()
		draw_line(c, b_end, PAL["deep"] as Color, 7.0)
		draw_line(c, b_end, PAL["blue"] as Color, 5.0)
		draw_line(c, b_end, PAL["sky"] as Color, 3.0)
		draw_line(c, b_end, PAL["ice"] as Color, 2.0)
		draw_line(c, b_end, PAL["cream"] as Color, 1.0)
	elif boss_state == BossState.COMMIT and active_attack_id == "eclipse_flare":
		var ring_r: float = lerpf(FLARE_START_R, FLARE_MAX_R, _flare_progress)
		draw_arc(c, ring_r + 2.6, 0.0, TAU, 36, PAL["blue"] as Color, 2.0)
		draw_arc(c, ring_r, 0.0, TAU, 36, PAL["sky"] as Color, 3.0)
		draw_arc(c, maxf(2.0, ring_r - 2.2), 0.0, TAU, 28, PAL["ice"] as Color, 2.0)
		draw_arc(c, maxf(2.0, ring_r - 4.0), 0.0, TAU, 24, PAL["cream"] as Color, 1.0)
	elif boss_state == BossState.PHASE_SHIFT:
		var rp: float = 1.0 - clampf(state_timer / maxf(phase_shift_duration, 0.05), 0.0, 1.0)
		var rr: float = body_radius + 10.0 + rp * 18.0
		var rot: float = anim_t * (1.2 if fred else 3.4)
		draw_arc(c, rr + 2.5, 0.0, TAU, 26, PAL["blue"] as Color, 2.0)
		draw_arc(c, rr, 0.0, TAU, 26, PAL["ice"] as Color, 2.0)
		for ci: int in range(2):
			var base_a: float = rot + float(ci) * PI
			draw_arc(c, rr * 0.78 + float(ci) * 3.5, base_a, base_a + PI * 0.72, 14, (PAL["sky"] if ci == 0 else PAL["ice"]) as Color, 2.0)
