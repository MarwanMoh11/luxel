class_name LxTheHushBoss
extends LxEnemyBrain
## The Long Night Final Boss (Island 8, sanctum_r6): THE HUSH, source of the dark.
## Upgraded (Bible §4.8): 4 phases, HP 34.0, Veil 4.0, every tell >= 0.50s, recover >= 0.90s.
## Preserves all 4 move-family phases (P1 Shooting, P2 Throwing, P3 Moving, P4 Light) AND adds:
## 1. Phase-Mutating Crown (P2 snuffs 2 braziers + E/W fissures, P3 center phantom ring warning, P4 36px dark edge band).
## 2. Guarded LxSold reactions (sold<=3 resists raw bolts; sold INTERFACE whiffs HUD drain for 1.2s punish;
##    sold BEAUTY orbits golden Toll Sparks chipping Veil on every manual hit!).
## 3. Phase-4 Finale Climax: DISPLAY: OFF (5-tap sell -> AUTO-SELL -> BIG BLAST) vs KEEP DISPLAY (25s Unbroken Stand).

signal hush_bolt_fired(origin: Vector2, dir: Vector2, source: LxEnemyBrain)

const Visuals := preload("res://luxel/bosses/the_hush/visuals.gd")
const FinalePanel := preload("res://luxel/bosses/the_hush/finale_ui.gd")

enum HushMove { VOLLEY, VOID_ZIP, SHADOW_DASH, SILENCE_RING, ECLIPSE_BEAM, WARD_BASH, RECALL_SLAM }
enum FinaleStage { NONE, SWELL, CHOICE, UNBROKEN_STAND, RESOLVED }

const P1_SHIELD_MAX: float = 2.4; const P1_SHIELD_REFORM: float = 5.0
const P4_VEIL_MAX: float = 4.0; const P4_VEIL_RES: float = 0.35
const VOLLEY_RANGE: float = 152.0; const WARD_BASH_RANGE: float = 64.0
const WARD_BASH_HIT_R: float = 32.0; const WARD_BASH_ARC: float = 1.18
const RECALL_SLAM_BURST_R: float = 38.0; const RING_START_R: float = 12.0
const RING_MAX_R: float = 84.0; const BEAM_RANGE: float = 158.0
const BEAM_ARC: float = 1.45; const UNBROKEN_STAND_SECS: float = 25.0

var active_move: int = HushMove.VOLLEY; var move_toggle: int = 0
var shield_max: float = P1_SHIELD_MAX; var shield_hp: float = P1_SHIELD_MAX; var shield_gone_t: float = 0.0
var veil_intact: bool = false; var veil_hp: float = 0.0; var lens_lit_t: float = 0.0
var commit_dir: Vector2 = Vector2.RIGHT; var commit_elapsed: float = 0.0; var commit_hit: bool = false
var volley_shots: int = 0; var void_orb_pos: Vector2 = Vector2.ZERO; var void_orb_out: bool = false
var ring_stage: int = 0; var ring_progress: float = 0.0
var sweep_start_ang: float = 0.0; var sweep_sign: float = 1.0; var beam_angle: float = 0.0
var _beam_light_t: float = 0.0; var _zip_landed: bool = false; var _slam_burst_done: bool = false
var _orbit_side: float = 1.0; var _roaring: bool = false
var finale_stage: int = FinaleStage.NONE; var unbroken_timer: float = 0.0
var dark_band_px: float = 0.0; var beauty_sparks: int = 0
var _hud_drain_done: bool = false; var _p2_braziers_snuffed: Array[Object] = []
var _finale_swell_t: float = 0.0; var _finale_panel: Node = null; var _pending_kill_hit: LxHit = null


func _init() -> void:
	kind = "the_hush"; boss_id = "the_hush"; island_id = 8; is_boss = true
	max_hp = 34.0; hp = 34.0; body_radius = 10.0; routine_speed = 42.0
	leash_radius = 190.0; notice_radius = 160.0; tell_time = 0.56
	recover_time = 1.05; give_up_time = 1.8; attack_damage = 1.0; shard_drop = 60


func _exit_tree() -> void:
	_cleanup_finale_panel()


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	max_hp = maxf(34.0, max_hp); hp = max_hp
	is_boss = true
	boss_id = str(spec.get("boss_id", "the_hush"))
	island_id = int(spec.get("island_id", 8))
	active_move = HushMove.VOLLEY; move_toggle = 0; shield_hp = P1_SHIELD_MAX; shield_gone_t = 0.0
	veil_intact = false; veil_hp = 0.0; lens_lit_t = 0.0; commit_dir = Vector2.from_angle(facing)
	commit_elapsed = 0.0; commit_hit = false; volley_shots = 0; void_orb_pos = pos; void_orb_out = false
	ring_stage = 0; ring_progress = 0.0; sweep_start_ang = facing; sweep_sign = 1.0; beam_angle = facing
	_slam_burst_done = false; _orbit_side = 1.0; _roaring = false
	finale_stage = FinaleStage.NONE; unbroken_timer = 0.0; dark_band_px = 0.0
	beauty_sparks = FinalePanel.get_beauty_sold_count(); _hud_drain_done = false
	_p2_braziers_snuffed.clear(); _finale_swell_t = 0.0; _pending_kill_hit = null
	_cleanup_finale_panel()


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: Variant = "") -> void:
	if state == State.DEAD:
		return
	var orig: Vector2 = Vector2.ZERO
	var rad: float = 0.0
	var src: String = str(source)
	var in_light: bool = true
	if a is Vector2 and (b is float or b is int):
		orig = a as Vector2; rad = float(b); in_light = pos.distance_to(orig) <= rad + body_radius
	elif a is float or a is int:
		rad = float(a)
		if b is Vector2:
			orig = b as Vector2; in_light = orig == Vector2.ZERO or pos.distance_to(orig) <= rad + body_radius
		elif b is String and src.is_empty():
			src = str(b)
	if not in_light or rad <= 0.0:
		return
	var was_unlit: bool = lens_lit_t <= 0.01
	if src == "lens":
		lens_lit_t = maxf(lens_lit_t, 1.35)
		if phase == 4 and was_unlit:
			_emit_sfx("phantom_reveal")
	else:
		lens_lit_t = maxf(lens_lit_t, 0.45)


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null or _roaring or finale_stage in [FinaleStage.SWELL, FinaleStage.CHOICE]:
		if hit != null and (_roaring or finale_stage in [FinaleStage.SWELL, FinaleStage.CHOICE]):
			_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_heavy: bool = bool(h["stagger"])
	var pierce: bool = bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"])
	var wear: float = float(h["shield_wear"])
	var is_blue_hit: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	var rel: Vector2 = (h["origin"] as Vector2) - pos
	if FinalePanel.is_setting_sold("hit_flash"):
		wear *= 1.40

	# Phase 1: front shadow mirror ward; prism/blue bolts bank straight through
	if _has_active_shield() and not is_blue_hit and not pierce and not cracks \
			and rel.length() > 0.01 and absf(angle_difference(facing, rel.angle())) < 1.05:
		clank_t = 0.14
		shield_hp -= wear
		if shield_hp <= 0.001:
			shield_hp = 0.0; shield_gone_t = P1_SHIELD_REFORM; _release_token()
			state = State.RECOVER; state_timer = 1.15; last_recover_duration = state_timer
			_boss_impact(0.20, 82.0, 88.0); _emit_sfx("hush_ward_break")
			_emit_enemy_hit(hit, HitResult.OPENED)
			return HitResult.OPENED
		if shield_hp <= P1_SHIELD_MAX * 0.45:
			clank_t = 0.18; _emit_sfx("shield_strain")
		else:
			_emit_sfx("warden_clank")
		_emit_enemy_hit(hit, HitResult.BLOCKED)
		return HitResult.BLOCKED

	if is_heavy and state == State.STAGGER and not cracks:
		_emit_enemy_hit(hit, HitResult.GLANCED)
		return HitResult.GLANCED

	var opened: bool = state == State.RECOVER or state == State.STAGGER
	if (phase == 1 and is_blue_hit) or (phase == 2 and _is_lured()):
		dmg *= 1.25; opened = true
	elif phase == 4:
		if lens_lit_t > 0.0:
			dmg *= 1.20; opened = true
		beauty_sparks = FinalePanel.get_beauty_sold_count()
		if beauty_sparks > 0:
			dmg += 0.08 * float(beauty_sparks)
		if veil_intact:
			var spark_chip: float = 0.25 * float(beauty_sparks)
			if cracks or pierce or src == LxHit.SOURCE_BEAM:
				dmg *= 1.25
				veil_hp = 0.0 if cracks else maxf(0.0, veil_hp - wear - spark_chip)
				veil_intact = veil_hp > 0.001; opened = true
				if not veil_intact:
					_boss_impact(0.26, 98.0, 105.0); _emit_sfx("hush_veil_shatter")
			else:
				# Sold-Setting Reaction: sold_count <= 3 resists raw bolt chip -25% more!
				var res_mult: float = P4_VEIL_RES * (0.75 if FinalePanel.get_sold_count() <= 3 else 1.0)
				dmg *= res_mult
				veil_hp -= (wear if is_heavy else wear * 0.35) + spark_chip
				if veil_hp <= 0.001:
					veil_intact = false
					_boss_impact(0.26, 98.0, 105.0); _emit_sfx("hush_veil_shatter")

	# During 25s Unbroken Stand, Hush holds at 1.0 HP until the 25s timer finishes!
	if finale_stage == FinaleStage.UNBROKEN_STAND and unbroken_timer > 0.0:
		hp = maxf(1.0, hp - dmg)
	else:
		hp -= dmg

	flash_t = 0.15 if (is_heavy or opened) else 0.08
	if rel.length() > 0.01:
		knock = -rel.normalized() * (85.0 if is_heavy else 18.0)

	# Trigger Phase-4 Finale Climax once when HP drops to <= 4.0 (or Veil shatters at <= 6.0)
	if phase == 4 and finale_stage == FinaleStage.NONE and (hp <= 4.0 or (not veil_intact and hp <= 6.0)):
		hp = maxf(1.0, hp)
		_pending_kill_hit = hit
		_begin_finale_climax()
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED

	if hp <= 0.001:
		opened_kill = opened
		void_orb_out = false
		_cleanup_finale_panel()
		_die(hit)
		return HitResult.KILLED
	if _check_phase_transition():
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if cracks or (is_heavy and not veil_intact and state != State.COMMIT):
		_release_token(); void_orb_out = false
		state = State.STAGGER
		state_timer = 1.40 if src == LxHit.SOURCE_SUNFLARE else 0.52
		_emit_enemy_hit(hit, HitResult.OPENED)
		return HitResult.OPENED
	if state == State.ROUTINE or state == State.RETURN:
		_enter_notice()
	var res: int = HitResult.OPENED if opened else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _check_phase_transition() -> bool:
	var target_p: int = 4 if hp <= max_hp * 0.25 else (3 if hp <= max_hp * 0.50 else (2 if hp <= max_hp * 0.75 else 1))
	if target_p <= phase:
		return false
	_enter_phase(target_p)
	return true


func _enter_phase(next_phase: int) -> void:
	phase = next_phase; _roaring = true; void_orb_out = false; ring_stage = 0; ring_progress = 0.0
	shield_hp = 0.0; shield_gone_t = 0.0; veil_intact = (phase == 4); veil_hp = P4_VEIL_MAX if phase == 4 else 0.0
	_release_token(); state = State.NOTICE; state_timer = 0.62
	beauty_sparks = FinalePanel.get_beauty_sold_count()
	if phase == 2:
		_snuff_crown_braziers(2)
	elif phase == 4 and FinalePanel.get_sold_count() <= 3:
		_emit_narr("ISL8_HUSH_FEW", "ominous", 2.8)
	if Lx.events != null:
		Lx.events.boss_phase_changed.emit(boss_id, phase)
		Lx.events.shake_requested.emit(0.36)
	LxDamageFx.trigger_boss_phase_reset(self, next_phase)
	_emit_sfx("hush_phase_shift")


func _begin_finale_climax() -> void:
	finale_stage = FinaleStage.SWELL
	_finale_swell_t = 0.45 if FinalePanel.is_automated_run() else 0.80
	_release_token()
	void_orb_out = false
	state = State.STAGGER
	state_timer = _finale_swell_t + 0.5
	_emit_narr("ISL8_FINALE_SWELL", "ominous", 2.4)
	_boss_impact(0.24, 110.0, 104.0)
	_emit_sfx("hush_pulse")


func _mount_finale_panel() -> Node:
	if _finale_panel != null and is_instance_valid(_finale_panel):
		return _finale_panel
	var p: Node = FinalePanel.new()
	p.name = "HushFinalePanel"
	var host: Node = Lx.root if (Lx.root != null and is_instance_valid(Lx.root)) else get_tree().current_scene
	if host == null:
		host = self
	host.add_child(p)
	p.connect("display_off_completed", _on_display_off_completed)
	p.connect("keep_display_chosen", _on_keep_display_chosen)
	_finale_panel = p
	return p


func _cleanup_finale_panel() -> void:
	if _finale_panel != null and is_instance_valid(_finale_panel):
		if _finale_panel.has_method("hide_panel"):
			_finale_panel.call("hide_panel")
		_finale_panel.queue_free()
	_finale_panel = null


func _on_display_off_completed() -> void:
	finale_stage = FinaleStage.RESOLVED
	FinalePanel.record_finale_choice("display_off")
	_cleanup_finale_panel()
	if state != State.DEAD:
		hp = 0.0; opened_kill = true; void_orb_out = false
		_boss_impact(0.34, 148.0, 140.0); _emit_sfx("hush_big_blast")
		_die(_pending_kill_hit)


func _on_keep_display_chosen() -> void:
	finale_stage = FinaleStage.UNBROKEN_STAND
	unbroken_timer = UNBROKEN_STAND_SECS
	FinalePanel.record_finale_choice("dawn")
	_emit_narr("ISL8_FINALE_REFUSE", "title", 2.8)
	state = State.POSITION; cooldown = 0.45


func _step_brain(dt: float) -> void:
	lens_lit_t = maxf(0.0, lens_lit_t - dt)
	beauty_sparks = FinalePanel.get_beauty_sold_count()
	if phase == 4 and state != State.DEAD:
		dark_band_px = move_toward(dark_band_px, 36.0, 18.0 * dt)
	if phase == 1 and shield_gone_t > 0.0:
		shield_gone_t -= dt
		if shield_gone_t <= 0.0:
			shield_gone_t = 0.0; shield_hp = P1_SHIELD_MAX
	if finale_stage == FinaleStage.SWELL:
		_finale_swell_t -= dt
		if _finale_swell_t <= 0.0: _enter_finale_choice()
		return
	if finale_stage == FinaleStage.CHOICE:
		state_timer = 1.0
		if _finale_panel != null and is_instance_valid(_finale_panel) and _finale_panel.has_method("step_panel"):
			_finale_panel.call("step_panel", dt, true)
		return
	if finale_stage == FinaleStage.UNBROKEN_STAND and unbroken_timer > 0.0:
		unbroken_timer = maxf(0.0, unbroken_timer - dt)
		if _finale_panel != null and is_instance_valid(_finale_panel):
			_finale_panel.call("show_stand_hud", unbroken_timer)
		if unbroken_timer <= 0.0:
			finale_stage = FinaleStage.RESOLVED; _cleanup_finale_panel()
			_emit_narr("ISL8_FINALE_STAND_DONE", "title", 3.0)
			_release_token(); state = State.STAGGER; state_timer = 3.2; _emit_sfx("dawn_burst")
	match state:
		State.ROUTINE:
			if pos.distance_to(home) > 2.5:
				_move_step((home - pos).limit_length(routine_speed * 0.75 * dt), false)
			if _sees_target(): _enter_notice()
		State.NOTICE:
			var to_t: Vector2 = _attention_target() - pos
			if to_t.length() > 0.01: _turn_toward(to_t.angle(), 4.0, dt)
			state_timer -= dt
			if state_timer <= 0.0:
				_roaring = false
				if not _hud_drain_done and (phase == 2 or phase == 3) and FinalePanel.is_tab_sold("INTERFACE"):
					_hud_drain_done = true; _emit_narr("ISL8_HUSH_NONE", "title", 2.4)
					_emit_sfx("hush_ward_break"); state = State.STAGGER; state_timer = 1.20
				else:
					state = State.POSITION; cooldown = 0.35
		State.POSITION, State.WAIT_TOKEN: _step_position(dt)
		State.TELL: _step_tell(dt)
		State.COMMIT: _step_commit(dt)
		State.RECOVER:
			void_orb_out = false; state_timer -= dt
			if state_timer <= 0.0:
				_release_token(); cooldown = 0.65; _orbit_side = -_orbit_side
				state = State.RETURN if _should_give_up() else State.POSITION
		State.STAGGER:
			state_timer -= dt
			if state_timer <= 0.0:
				_release_token(); state = State.POSITION; cooldown = 0.50
		State.RETURN:
			void_orb_out = false
			var to_h: Vector2 = home - pos
			if to_h.length() <= 3.0:
				pos = home; state = State.ROUTINE; lost_t = 0.0
			else:
				facing = to_h.angle()
				_move_step(to_h.limit_length(routine_speed * 0.90 * dt), false)
				if _sees_target() and _attention_target().distance_to(home) <= leash_radius: _enter_notice()


func _enter_finale_choice() -> void:
	finale_stage = FinaleStage.CHOICE
	var forced: String = FinalePanel.forced_finale_choice()
	var panel: Node = _mount_finale_panel()
	if forced == "dawn":
		if panel.has_method("show_stand_hud"): panel.call("show_stand_hud", UNBROKEN_STAND_SECS)
		_on_keep_display_chosen()
		return
	if forced == "display_off" or FinalePanel.is_automated_run():
		if panel.has_method("start_auto_display_off"): panel.call("start_auto_display_off")
		else: _on_display_off_completed()
		return
	_emit_narr("ISL8_ASK_FINALE_1", "title", 3.5)
	if panel.has_method("open_choice"): panel.call("open_choice")


func _step_position(dt: float) -> void:
	if _should_give_up():
		lost_t += dt
		if lost_t >= give_up_time:
			_release_token(); state = State.RETURN; lost_t = 0.0; return
	else:
		lost_t = 0.0
	var target: Vector2 = _attention_target()
	var to_t: Vector2 = target - pos
	var dist: float = to_t.length()
	if dist > 0.01:
		_turn_toward(to_t.angle(), 3.6, dt)
	state = State.POSITION if _can_claim_token() else State.WAIT_TOKEN
	if cooldown <= 0.0 and dist <= notice_radius and _is_on_screen() and _claim_token():
		_begin_phase_attack(target, dist); return
	if dist > 0.01:
		var radial: Vector2 = to_t / dist
		var mv: Vector2 = (radial.rotated(PI * 0.5 * _orbit_side) + radial * clampf((dist - 64.0) / 48.0, -0.5, 0.5)).normalized()
		_move_step(mv * routine_speed * 0.84 * dt, false)


func _begin_phase_attack(target: Vector2, dist: float) -> void:
	move_toggle += 1
	var odd: bool = (move_toggle % 2 == 1)
	if finale_stage == FinaleStage.UNBROKEN_STAND:
		# Unbroken Stand cycles ALL 4 move families in fair staggered turns!
		var stand_cycle: Array[int] = [HushMove.VOLLEY, HushMove.VOID_ZIP, HushMove.SILENCE_RING, HushMove.ECLIPSE_BEAM]
		active_move = stand_cycle[move_toggle % stand_cycle.size()]
	elif phase == 1:
		active_move = HushMove.WARD_BASH if (dist <= WARD_BASH_RANGE or (move_toggle % 3 == 0 and dist <= 82.0)) else HushMove.VOLLEY
	elif phase == 2:
		active_move = HushMove.VOID_ZIP if odd else HushMove.RECALL_SLAM
	elif phase == 3:
		active_move = HushMove.SHADOW_DASH if odd else HushMove.SILENCE_RING
	else:
		active_move = HushMove.ECLIPSE_BEAM if odd else HushMove.SILENCE_RING
	state = State.TELL; is_counter_attack = false
	var tells: Array[float] = [0.54, 0.56, 0.52, 0.58, 0.62, 0.52, 0.56]
	last_tell_duration = _scaled_tell(maxf(0.52, tells[active_move]), false, attack_damage)
	state_timer = last_tell_duration
	if target.distance_to(pos) > 0.01:
		facing = (target - pos).angle()
	commit_dir = Vector2.from_angle(facing)
	sweep_sign = -sweep_sign
	sweep_start_ang = wrapf(facing - sweep_sign * (BEAM_ARC * 0.5), -PI, PI)
	beam_angle = sweep_start_ang
	ring_stage = 0; ring_progress = 0.0
	if active_move == HushMove.RECALL_SLAM:
		void_orb_pos = _clamp_pt(pos + commit_dir * clampf(dist + 22.0, 56.0, 108.0)); void_orb_out = true
	elif active_move == HushMove.VOID_ZIP:
		void_orb_pos = _clamp_pt(pos + commit_dir * clampf(dist, 36.0, 96.0)); void_orb_out = false
	else:
		void_orb_out = false
	_emit_attack_started()
	_emit_sfx("beam_charge" if active_move == HushMove.ECLIPSE_BEAM else "hush_tell")


func _step_tell(dt: float) -> void:
	if state_timer > 0.22:
		var tpos: Vector2 = _attention_target()
		var to_t: Vector2 = tpos - pos
		if to_t.length() > 0.01:
			_turn_toward(to_t.angle(), 2.8, dt)
			commit_dir = Vector2.from_angle(facing)
			if active_move == HushMove.ECLIPSE_BEAM:
				sweep_start_ang = wrapf(facing - sweep_sign * (BEAM_ARC * 0.5), -PI, PI)
				beam_angle = sweep_start_ang
			elif active_move == HushMove.RECALL_SLAM:
				void_orb_pos = _clamp_pt(pos + commit_dir * clampf(to_t.length() + 22.0, 56.0, 108.0))
			elif active_move == HushMove.VOID_ZIP:
				void_orb_pos = _clamp_pt(pos + commit_dir * clampf(to_t.length(), 36.0, 96.0))
	state_timer -= dt
	if state_timer <= 0.0:
		state = State.COMMIT; commit_elapsed = 0.0; commit_hit = false; volley_shots = 0
		ring_stage = 0; ring_progress = 0.0; _beam_light_t = 0.0; _zip_landed = false; _slam_burst_done = false
		var durs: Array[float] = [0.36, 0.46, 0.26, 0.34, 0.58, 0.24, 0.42]
		state_timer = durs[active_move]
		if active_move == HushMove.VOID_ZIP:
			void_orb_pos = _clamp_pt(void_orb_pos); void_orb_out = true
		elif active_move == HushMove.RECALL_SLAM:
			void_orb_out = true
		elif active_move == HushMove.WARD_BASH:
			_boss_impact(0.16, 74.0, 80.0)
		elif active_move == HushMove.SILENCE_RING:
			_boss_impact(0.24, 112.0, 108.0)
		elif active_move == HushMove.ECLIPSE_BEAM:
			beam_angle = sweep_start_ang; _boss_impact(0.18, 86.0, 84.0)
		var csfx: Array[String] = ["bolt_fire", "zip_streak", "hollow_dash", "hush_pulse", "beam_fire", "warden_swing", "zip_streak"]
		_emit_sfx(csfx[active_move])


func _step_commit(dt: float) -> void:
	commit_elapsed += dt
	state_timer = maxf(0.0, state_timer - dt)
	match active_move:
		HushMove.VOLLEY:
			var expected: int = mini(5, int(commit_elapsed / 0.07) + 1)
			while volley_shots < expected:
				var bdir: Vector2 = commit_dir.rotated((float(volley_shots) - 2.0) * 0.14)
				volley_shots += 1
				hush_bolt_fired.emit(pos, bdir, self)
				_check_line_hit(bdir, VOLLEY_RANGE, 8.5, true)
		HushMove.WARD_BASH:
			_move_step(commit_dir * 215.0 * dt, false)
			if not commit_hit and _has_player():
				var wv: Vector2 = _get_wick_pos() - pos
				if wv.length() <= WARD_BASH_HIT_R and (wv.length() < 0.01 or absf(angle_difference(commit_dir.angle(), wv.angle())) <= WARD_BASH_ARC):
					commit_hit = true; _emit_player_hit(commit_dir)
					if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("apply_recoil"):
						Lx.player.call("apply_recoil", commit_dir * 85.0)
			if _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= WARD_BASH_HIT_R + 2.0 and Lx.events != null:
				Lx.events.lantern_struck.emit(_get_lantern_pos())
		HushMove.VOID_ZIP:
			if commit_elapsed >= 0.20:
				if void_orb_pos.distance_to(pos) > 3.0:
					_move_step((void_orb_pos - pos).limit_length(350.0 * dt), true)
				if pos.distance_to(void_orb_pos) <= 7.0:
					if not _zip_landed:
						_zip_landed = true; _boss_impact(0.16, 78.0, 82.0)
					_check_area_hit(26.0)
		HushMove.RECALL_SLAM:
			var prev_orb: Vector2 = void_orb_pos
			if not _slam_burst_done:
				void_orb_pos = void_orb_pos.move_toward(pos, 380.0 * dt)
				if not commit_hit and _has_player():
					var wp: Vector2 = _get_wick_pos()
					if Geometry2D.get_closest_point_to_segment(wp, prev_orb, void_orb_pos).distance_to(wp) <= 13.0:
						commit_hit = true
						var pull_d: Vector2 = (pos - prev_orb).normalized() if pos.distance_to(prev_orb) > 0.01 else -commit_dir
						_emit_player_hit(pull_d)
				if void_orb_pos.distance_to(pos) <= 5.0:
					_slam_burst_done = true; void_orb_out = false
					_boss_impact(0.22, 96.0, 98.0); _emit_sfx("hush_pulse")
					_check_area_hit(RECALL_SLAM_BURST_R)
			else:
				_check_area_hit(RECALL_SLAM_BURST_R)
		HushMove.SHADOW_DASH:
			_move_step(commit_dir * 290.0 * dt, true); _check_area_hit(16.0)
		HushMove.SILENCE_RING:
			if _tick_ring():
				return
		HushMove.ECLIPSE_BEAM:
			beam_angle = wrapf(sweep_start_ang + sweep_sign * BEAM_ARC * (1.0 - clampf(state_timer / 0.58, 0.0, 1.0)), -PI, PI)
			facing = beam_angle
			var eb_dir: Vector2 = Vector2.from_angle(beam_angle)
			_beam_light_t -= dt
			if _beam_light_t <= 0.0:
				_beam_light_t = 0.14
				LxDamageFx.boss_impact(pos + eb_dir * 72.0, 0.0, 0.0, 0.0, 82.0, 1.48, 0.22)
			_check_line_hit(eb_dir, BEAM_RANGE, 9.5, false)
	if state_timer <= 0.0:
		void_orb_out = false; state = State.RECOVER
		state_timer = maxf(0.90, 1.15 if active_move == HushMove.ECLIPSE_BEAM else (1.10 if active_move == HushMove.SILENCE_RING else 1.00))
		last_recover_duration = state_timer


func _tick_ring() -> bool:
	if ring_stage == 1:
		if state_timer <= 0.0:
			ring_stage = 2; state_timer = 0.34; ring_progress = 0.0; commit_hit = false
			_boss_impact(0.24, 112.0, 108.0); _emit_sfx("hush_pulse")
		return true
	ring_progress = 1.0 - clampf(state_timer / 0.34, 0.0, 1.0)
	var ring_r: float = lerpf(RING_START_R, RING_MAX_R, ring_progress)
	if not commit_hit and _has_player() and absf((_get_wick_pos() - pos).length() - ring_r) <= 10.0:
		commit_hit = true
		var prev_kind: String = kind; kind = "shockwave"
		var wv: Vector2 = _get_wick_pos() - pos
		_emit_player_hit(wv.normalized() if wv.length() > 0.01 else commit_dir)
		kind = prev_kind
	if _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= ring_r and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())
	if state_timer <= 0.0 and ring_stage == 0 and phase == 3:
		ring_stage = 1; state_timer = _scaled_tell(0.44, false, attack_damage); ring_progress = 0.0; commit_hit = false
		return true
	return false


func _snuff_crown_braziers(max_n: int) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return
	var count: int = 0
	for it_v: Variant in (world_ctx.call("get_interactables") as Array):
		if it_v is Object and str((it_v as Object).get("kind")) == "brazier" and bool((it_v as Object).get("lit")):
			(it_v as Object).set("lit", false)
			if it_v is CanvasItem: (it_v as CanvasItem).queue_redraw()
			_p2_braziers_snuffed.append(it_v as Object)
			count += 1
			if count >= max_n: break


func _emit_narr(string_id: String, style: String, dur: float) -> void:
	if Lx.events != null and LxStrings.has_id(string_id):
		Lx.events.narration_requested.emit(string_id, style, dur)


func _check_line_hit(dir_v: Vector2, length: float, half_w: float, need_los: bool) -> void:
	var end_p: Vector2 = pos + dir_v * length
	if not commit_hit and _has_player():
		var wp: Vector2 = _get_wick_pos()
		if Geometry2D.get_closest_point_to_segment(wp, pos, end_p).distance_to(wp) <= half_w \
				and (not need_los or _has_clear_view(pos, wp)):
			commit_hit = true; _emit_player_hit(dir_v)
	if _is_lantern_out():
		var lp: Vector2 = _get_lantern_pos()
		if Geometry2D.get_closest_point_to_segment(lp, pos, end_p).distance_to(lp) <= half_w + 2.0 and Lx.events != null:
			Lx.events.lantern_struck.emit(lp)


func _check_area_hit(rad: float) -> void:
	if not commit_hit and _has_player() and pos.distance_to(_get_wick_pos()) <= rad:
		commit_hit = true; _emit_player_hit(commit_dir)
	if _is_lantern_out() and pos.distance_to(_get_lantern_pos()) <= rad + 3.0 and Lx.events != null:
		Lx.events.lantern_struck.emit(_get_lantern_pos())


func _is_lured() -> bool:
	return (phase == 1 or phase == 2) and _is_lantern_out() and _get_lantern_pos().distance_to(home) <= leash_radius + 32.0
func _attention_target() -> Vector2: return _get_lantern_pos() if _is_lured() else _get_wick_pos()
func _sees_target() -> bool: return (pos.distance_to(_get_lantern_pos()) <= notice_radius) if _is_lured() else (_has_player() and pos.distance_to(_get_wick_pos()) <= notice_radius)
func _should_give_up() -> bool: return (not _is_lured()) and (not _has_player() or _get_wick_pos().distance_to(home) > leash_radius + 16.0)
func _enter_notice() -> void:
	state = State.NOTICE; state_timer = 0.32; alert_t = 0.85; lost_t = 0.0; _emit_sfx("hush_notice")
func _clamp_pt(pt: Vector2) -> Vector2:
	var cap: float = maxf(0.0, leash_radius - 2.0)
	var out: Vector2 = home + (pt - home).normalized() * cap if pt.distance_to(home) > cap else pt
	return _collide_move(pos, out, true)
func _has_active_shield() -> bool:
	return phase == 1 and shield_gone_t <= 0.0 and shield_hp > 0.001 and state != State.DEAD and state != State.STAGGER
func _body_color() -> Color:
	if phase == 4: return (PAL["wine"] as Color) if not veil_intact else (PAL["void"] as Color)
	return (PAL["deep"] as Color) if phase == 3 else ((PAL["dusk"] as Color) if phase == 2 else (PAL["night"] as Color))
func _shield_color() -> Color: return PAL["sky"] as Color
func _draw_extra(off: Vector2) -> void: Visuals.draw_hush(self, off)
func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.18, 1.56, 0.44)
