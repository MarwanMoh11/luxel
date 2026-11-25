class_name LxTheHushBoss
extends LxBossBase
## The Long Night Final Boss (Island 8, sanctum_r6): THE HUSH — Source of the Dark.
## Migrated onto LxBossBase: 4 grand phases, each pairing two islands' rules as arena changes:
##   P1 (100-75%): Rings & Tides (Isl 1+2) — Resonance Bells + Tidal Surge + Front Shadow Ward
##   P2 (75-50%):  Growth & The Loop (Isl 3+4) — Snuffed Braziers + Briar Growth + 6s Echo-Loop Ghost
##   P3 (50-25%):  Gravity & Moving Floor (Isl 5+6) — LxFields Gravity Well + Reversible Conveyor Bands
##   P4 (25-0%):   Mirrors & What Was Sold (Isl 7+8) — Mirror Fault & Twin + Veil + Dark Edge Band +
##                 Sold-Setting Reactions + 8-Island Comeback Beat + Phase-4 DISPLAY: OFF vs 25s Stand!
## Phase checkpoints on retry: after reaching P2/P3/P4 once, retry_from_death() resumes there.

signal hush_bolt_fired(origin: Vector2, dir: Vector2, source: LxEnemyBrain)

const Visuals := preload("res://luxel/bosses/the_hush/visuals.gd")
const ArenaRules := preload("res://luxel/bosses/the_hush/arena_rules.gd")
const Attacks := preload("res://luxel/bosses/the_hush/attacks.gd")
const FinalePanel := preload("res://luxel/bosses/the_hush/finale_ui.gd")

enum HushMove { VOLLEY, VOID_ZIP, SHADOW_DASH, SILENCE_RING, ECLIPSE_BEAM, WARD_BASH, RECALL_SLAM }
enum FinaleStage { NONE, SWELL, CHOICE, UNBROKEN_STAND, RESOLVED }

const P1_SHIELD_MAX: float = 4.2
const P1_SHIELD_REFORM: float = 5.4
const P4_VEIL_MAX: float = 5.0
const P4_VEIL_RES: float = 0.35
const WARD_BASH_HIT_R: float = 34.0
const WARD_BASH_ARC: float = 1.20
const RECALL_SLAM_BURST_R: float = 36.0
const RING_START_R: float = 12.0
const RING_MAX_R: float = 54.0
const RING_SINGLE_DUR: float = 0.34
const RING_GAP_DUR: float = 0.46
const BEAM_RANGE: float = 162.0
const BEAM_ARC: float = 1.42
const BEAM_DUR: float = 0.58
const UNBROKEN_STAND_SECS: float = 25.0
const SANCTUM_R6_CORE := Rect2(224.0, 126.0, 112.0, 58.0)
const SANCTUM_R6_ENGAGE := Rect2(128.0, 108.0, 256.0, 144.0)

# Compat & VFX fields read by visuals.gd, biome_boss_synergy.gd, boss_qa_capture.gd
var active_move: int = HushMove.VOLLEY
var shield_max: float = P1_SHIELD_MAX
var shield_hp: float = P1_SHIELD_MAX
var shield_gone_t: float = 0.0
var veil_intact: bool = false
var veil_hp: float = 0.0
var lens_lit_t: float = 0.0
var commit_dir: Vector2 = Vector2.RIGHT
var commit_elapsed: float = 0.0
var commit_hit: bool = false
var volley_shots: int = 0
var void_orb_pos: Vector2 = Vector2.ZERO
var void_orb_out: bool = false
var ring_stage: int = 0
var ring_progress: float = 0.0
var sweep_start_ang: float = 0.0
var sweep_sign: float = 1.0
var beam_angle: float = 0.0
var _beam_light_t: float = 0.0
var _zip_landed: bool = false
var _slam_burst_done: bool = false
var _roaring: bool = false
var finale_stage: int = FinaleStage.NONE
var unbroken_timer: float = 0.0
var dark_band_px: float = 0.0
var beauty_sparks: int = 0

var arena: ArenaRules = null
var _hud_drain_done: bool = false
var _finale_swell_t: float = 0.0
var _finale_panel: Node = null
var _pending_kill_hit: LxHit = null
var _armour_glint_t: float = 0.0
var _armour_glint_ang: float = 0.0
var _clank_sfx_cd: float = 0.0
var _ring_sub_t: float = 0.0
var _checkpoint_phase: int = 1
var _stand_cycle_idx: int = 0
var _phase_times: Dictionary = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}


func _init() -> void:
	super._init()
	kind = "the_hush"
	boss_id = "the_hush"
	boss_name_key = "BOSS_HUSH"
	island_id = 8
	is_miniboss = false
	reward_heart = "full"
	music_cue = "island8_boss_p1"
	music_p2_cue = "island8_boss_p2"
	max_hp = 1520.0
	hp = 1520.0
	body_radius = 11.0
	move_speed = 42.0
	stagger_threshold = 38.0
	stagger_duration = 1.90
	post_stagger_immunity = 4.6
	punish_dmg_mult = 1.35
	post_recover_cd = 0.44
	intro_duration = 0.55
	phase_shift_duration = 0.68
	death_duration = 2.2
	shard_drop = 60


func _exit_tree() -> void:
	if arena != null:
		arena.cleanup()
	_cleanup_finale_panel()


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	super.setup(spec, p_director, p_world)
	_apply_retry_checkpoint_if_needed()


func is_flying() -> bool:
	return true


func _is_sanctum_r6() -> bool:
	if world_ctx == null or not is_instance_valid(world_ctx):
		return false
	var reg: String = str(world_ctx.get("current_region_id")) if world_ctx.get("current_region_id") != null else str(world_ctx.get("region_id"))
	return reg == "sanctum_r6"


func _infer_arena_rect() -> Rect2:
	if _is_sanctum_r6():
		return SANCTUM_R6_CORE
	return super._infer_arena_rect()


func _configure_boss(spec: Dictionary) -> void:
	if arena == null:
		arena = ArenaRules.new(self)
	var base_hp: float = 1520.0 * maxf(0.1, float(spec.get("hp_scale", 1.0)))
	max_hp = base_hp
	hp = base_hp
	kind = "the_hush"
	boss_id = str(spec.get("boss_id", "the_hush"))
	island_id = int(spec.get("island_id", 8))
	configure_phases([0.75, 0.50, 0.25])
	Attacks.register_all(self)


# --- Lifecycle, Light, Armour, Veil, Finale & Checkpoints --------------------

func _on_reset_encounter() -> void:
	if arena != null:
		arena.cleanup()
	_cleanup_finale_panel()
	intro_duration = 0.55
	_checkpoint_phase = 1
	active_move = HushMove.VOLLEY
	shield_hp = P1_SHIELD_MAX; shield_gone_t = 0.0
	veil_intact = false; veil_hp = 0.0; lens_lit_t = 0.0
	commit_dir = Vector2.from_angle(facing); commit_elapsed = 0.0; commit_hit = false
	volley_shots = 0; void_orb_pos = home; void_orb_out = false
	ring_stage = 0; ring_progress = 0.0; _ring_sub_t = 0.0
	sweep_start_ang = facing; sweep_sign = 1.0; beam_angle = facing
	_beam_light_t = 0.0; _zip_landed = false; _slam_burst_done = false; _roaring = false
	finale_stage = FinaleStage.NONE; unbroken_timer = 0.0; dark_band_px = 0.0
	beauty_sparks = FinalePanel.get_beauty_sold_count()
	_hud_drain_done = false; _finale_swell_t = 0.0; _pending_kill_hit = null
	_armour_glint_t = 0.0; _clank_sfx_cd = 0.0; _stand_cycle_idx = 0
	_phase_times = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}


func _on_engage() -> void:
	arena.apply_phase_arena(phase, _on_p1_bell_rung)
	if phase == 4:
		veil_intact = true; veil_hp = P4_VEIL_MAX


func _on_attack_recover_start(_attack_id: String) -> void:
	void_orb_out = false
	ring_stage = 0


func on_light(a: Variant, b: Variant = Vector2.ZERO, source: Variant = "") -> void:
	if boss_state == BossState.DEATH:
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
		lens_lit_t = maxf(lens_lit_t, 2.8)
		patterns.freeze_bolts_in_radius(orig, rad, 0.45, "lens")
		if phase >= 3 and was_unlit:
			stage.play_sfx("phantom_reveal", pos)
	else:
		lens_lit_t = maxf(lens_lit_t, 0.50)


func _on_boss_tick(dt: float, target: Vector2) -> void:
	if boss_state != BossState.IDLE and boss_state != BossState.DEATH:
		_phase_times[phase] = float(_phase_times.get(phase, 0.0)) + dt
	if boss_state != BossState.PHASE_SHIFT:
		_roaring = false
	lens_lit_t = maxf(0.0, lens_lit_t - dt)
	_armour_glint_t = maxf(0.0, _armour_glint_t - dt)
	_clank_sfx_cd = maxf(0.0, _clank_sfx_cd - dt)
	beauty_sparks = FinalePanel.get_beauty_sold_count()
	if phase == 4 and boss_state != BossState.DEATH:
		dark_band_px = move_toward(dark_band_px, 36.0, 18.0 * dt)
	if phase == 1 and shield_gone_t > 0.0:
		shield_gone_t = maxf(0.0, shield_gone_t - dt)
		if shield_gone_t <= 0.0:
			shield_hp = P1_SHIELD_MAX
	if arena != null:
		arena.tick(dt, target, _on_p4_mirror_shattered)

	if finale_stage == FinaleStage.SWELL:
		_finale_swell_t -= dt
		state_timer = maxf(0.5, _finale_swell_t + 0.4)
		if _finale_swell_t <= 0.0:
			_enter_finale_choice()
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
			finale_stage = FinaleStage.RESOLVED
			_cleanup_finale_panel()
			_emit_narr("ISL8_FINALE_STAND_DONE", "title", 3.0)
			_release_token(); active_attack_id = ""
			_set_boss_state(BossState.STAGGER, 3.2)
			stage.play_sfx("dawn_burst", pos)


func _pick_next_attack(dist: float) -> String:
	if finale_stage == FinaleStage.UNBROKEN_STAND:
		var stand_pool: Array[String] = ["p1_ward_volley", "p2_void_zip_briar", "p3_double_silence_ring", "p4_eclipse_beam_sweep"]
		var chosen: String = stand_pool[_stand_cycle_idx % stand_pool.size()]
		_stand_cycle_idx += 1
		return chosen
	return super._pick_next_attack(dist)


func take_hit(hit: LxHit) -> int:
	if boss_state == BossState.DEATH or hit == null:
		return HitResult.GLANCED
	if finale_stage in [FinaleStage.SWELL, FinaleStage.CHOICE]:
		_emit_enemy_hit(hit, HitResult.GLANCED); return HitResult.GLANCED
	if not engaged:
		var eng_r: Rect2 = SANCTUM_R6_ENGAGE if _is_sanctum_r6() else arena_rect.grow(2.0)
		if not eng_r.has_point(_get_wick_pos()):
			clank_t = 0.12; _emit_enemy_hit(hit, HitResult.GLANCED); return HitResult.GLANCED
		engage()
	if boss_state == BossState.INTRO or boss_state == BossState.PHASE_SHIFT:
		_emit_enemy_hit(hit, HitResult.GLANCED); return HitResult.GLANCED

	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var is_open: bool = is_punishable()
	var is_blue: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	var pierce: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"]) or src == LxHit.SOURCE_SUNFLARE
	var wear: float = float(h["shield_wear"]) * (1.40 if FinalePanel.is_setting_sold("hit_flash") else 1.0)
	var rel: Vector2 = (h["origin"] as Vector2) - pos

	if _has_active_shield() and not is_blue and not pierce and not cracks and not is_open \
			and rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) < 1.05:
		clank_t = 0.14; _armour_glint_t = 0.22; _armour_glint_ang = rel.angle()
		shield_hp -= wear
		if shield_hp <= 0.001:
			shield_hp = 0.0; shield_gone_t = P1_SHIELD_REFORM
			_boss_impact(0.20, 82.0, 88.0); stage.play_sfx("hush_ward_break", pos)
			stagger_immunity_t = 0.0; add_stagger(stagger_threshold)
			_emit_enemy_hit(hit, HitResult.OPENED); return HitResult.OPENED
		if _clank_sfx_cd <= 0.0:
			_clank_sfx_cd = 0.22; stage.play_sfx("warden_clank", pos)
		_emit_enemy_hit(hit, HitResult.BLOCKED); return HitResult.BLOCKED

	if is_open:
		dmg *= punish_dmg_mult
	dmg = _modify_incoming_damage(hit, dmg)
	if arena != null and arena.comeback_surge_t > 0.0:
		dmg *= 1.25

	if finale_stage == FinaleStage.UNBROKEN_STAND and unbroken_timer > 0.0:
		hp = maxf(1.0, hp - dmg)
	elif phase < 4:
		hp = maxf(max_hp * 0.24, hp - dmg)
	elif finale_stage == FinaleStage.NONE:
		hp = maxf(1.0, hp - dmg)
	else:
		hp = maxf(0.0, hp - dmg)
	flash_t = 0.14 if is_open else 0.07
	if rel.length() > 0.01:
		knock = -rel.normalized() * (48.0 if bool(h["stagger"]) else 12.0)

	if phase == 4 and finale_stage == FinaleStage.NONE and hp <= max_hp * 0.055:
		hp = maxf(1.0, hp); _pending_kill_hit = hit
		_begin_finale_climax()
		_emit_enemy_hit(hit, HitResult.OPENED); return HitResult.OPENED

	if hp <= 0.001:
		opened_kill = is_open; void_orb_out = false
		_cleanup_finale_panel(); _begin_death(hit)
		return HitResult.KILLED
	if _check_phase_thresholds():
		_emit_enemy_hit(hit, HitResult.OPENED); return HitResult.OPENED
	var stag_gain: float = dmg * (1.45 if (bool(h["stagger"]) or cracks) else 0.48)
	if add_stagger(stag_gain):
		_emit_enemy_hit(hit, HitResult.OPENED); return HitResult.OPENED
	var res: int = HitResult.OPENED if is_open else HitResult.CHIPPED
	_emit_enemy_hit(hit, res)
	return res


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var is_blue: bool = hit.is_blue() or src == LxHit.SOURCE_PRISM
	var is_pierce: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["pierce"])
	var cracks: bool = bool(h["cracks_armour"]) or src == LxHit.SOURCE_SUNFLARE
	var wear: float = float(h["shield_wear"])
	var rel: Vector2 = (h["origin"] as Vector2) - pos

	if phase == 1 and (is_blue or (arena != null and arena.bell_resonance_t > 0.0)):
		dmg *= 1.25
	elif phase == 2 and _is_lured():
		dmg *= 1.28
	elif phase >= 3 and lens_lit_t > 0.0:
		dmg *= 1.22

	if phase == 4:
		beauty_sparks = FinalePanel.get_beauty_sold_count()
		if beauty_sparks > 0:
			dmg += 0.14 * float(beauty_sparks)
		if veil_intact:
			var spark_chip: float = 0.25 * float(beauty_sparks)
			if cracks or is_pierce:
				veil_hp = 0.0 if cracks else maxf(0.0, veil_hp - wear - spark_chip)
				veil_intact = veil_hp > 0.001
				if not veil_intact:
					_boss_impact(0.26, 98.0, 105.0); stage.play_sfx("hush_veil_shatter", pos)
				return dmg * 1.25
			var res_m: float = P4_VEIL_RES * (0.75 if FinalePanel.get_sold_count() <= 3 else 1.0)
			veil_hp = maxf(0.0, veil_hp - wear * 0.45 - spark_chip)
			if veil_hp <= 0.001:
				veil_intact = false; _boss_impact(0.26, 98.0, 105.0); stage.play_sfx("hush_veil_shatter", pos)
			return dmg * res_m

	if is_pierce or cracks:
		return dmg * (1.15 if boss_state == BossState.STAGGER else (1.0 if is_punishable() else 0.88))
	if boss_state == BossState.STAGGER:
		return dmg * 1.18
	if is_punishable():
		return dmg

	_armour_glint_t = 0.20; _armour_glint_ang = rel.angle() if rel.length() > 1.0 else facing; clank_t = 0.10
	if _clank_sfx_cd <= 0.0:
		_clank_sfx_cd = 0.28; stage.play_sfx("mirror_ping", pos)
	return dmg * (0.16 if src == LxHit.SOURCE_BOLT else 0.36)


func _enter_phase(next_phase: int) -> void:
	phase = clampi(next_phase, 1, 4)
	if not phases_reached.has(phase):
		phases_reached.append(phase)
	_on_phase_enter(phase)


func _on_phase_enter(new_phase: int) -> void:
	_roaring = true; void_orb_out = false; ring_stage = 0; ring_progress = 0.0
	shield_hp = 0.0; shield_gone_t = 0.0
	veil_intact = (new_phase == 4); veil_hp = P4_VEIL_MAX if new_phase == 4 else 0.0
	beauty_sparks = FinalePanel.get_beauty_sold_count()
	ArenaRules.save_checkpoint(new_phase)
	if arena != null:
		arena.apply_phase_arena(new_phase, _on_p1_bell_rung)
	if not _hud_drain_done and (new_phase == 2 or new_phase == 3) and FinalePanel.is_tab_sold("INTERFACE"):
		_hud_drain_done = true
		_emit_narr("ISL8_HUSH_NONE", "title", 2.6)
		stage.play_sfx("hush_ward_break", pos)
		_set_boss_state(BossState.STAGGER, 1.40)
	elif new_phase == 4 and FinalePanel.get_sold_count() <= 3:
		_emit_narr("ISL8_HUSH_FEW", "ominous", 2.8)
	stage.darkness_pulse(0.68 if new_phase < 4 else 0.78, 1.1)
	stage.shake(0.36); stage.play_sfx("hush_phase_shift", pos)


func _on_p1_bell_rung(_tone: String, _at: Vector2) -> void:
	if phase == 1 and shield_hp > 0.0:
		shield_hp = maxf(0.0, shield_hp - 2.2)
		if shield_hp <= 0.001:
			shield_hp = 0.0; shield_gone_t = P1_SHIELD_REFORM
			stage.play_sfx("hush_ward_break", pos); add_stagger(stagger_threshold)


func _on_p4_mirror_shattered() -> void:
	if veil_intact:
		veil_hp = maxf(0.0, veil_hp - 2.5)
		if veil_hp <= 0.001:
			veil_intact = false; stage.play_sfx("hush_veil_shatter", pos)
	stagger_immunity_t = 0.0; add_stagger(stagger_threshold * 0.85)


func _on_death_start() -> void:
	void_orb_out = false; veil_intact = false
	if arena != null: arena.cleanup()
	ArenaRules.clear_checkpoint(); _cleanup_finale_panel()
	stage.revert_tiles(world_ctx)
	stage.light_burst(pos, 152.0, 1.7, 0.55); stage.play_sfx("hush_veil_shatter", pos)


# --- Phase-4 Finale Climax (DISPLAY: OFF vs 25s Unbroken Stand) --------------

func _begin_finale_climax() -> void:
	finale_stage = FinaleStage.SWELL
	_finale_swell_t = 0.45 if FinalePanel.is_automated_run() else 0.80
	_release_token(); active_attack_id = ""; void_orb_out = false
	patterns.clear(); ground.clear()
	_set_boss_state(BossState.STAGGER, _finale_swell_t + 0.5)
	_emit_narr("ISL8_FINALE_SWELL", "ominous", 2.4)
	_boss_impact(0.24, 110.0, 104.0); stage.play_sfx("hush_pulse", pos)


func _enter_finale_choice() -> void:
	finale_stage = FinaleStage.CHOICE
	var forced: String = FinalePanel.forced_finale_choice()
	var panel: Node = _mount_finale_panel()
	if forced == "dawn":
		if panel.has_method("show_stand_hud"): panel.call("show_stand_hud", UNBROKEN_STAND_SECS)
		_on_keep_display_chosen(); return
	if forced == "display_off" or FinalePanel.is_automated_run():
		if panel.has_method("start_auto_display_off"): panel.call("start_auto_display_off")
		else: _on_display_off_completed()
		return
	if panel.has_method("open_choice"): panel.call("open_choice")


func _mount_finale_panel() -> Node:
	if _finale_panel != null and is_instance_valid(_finale_panel):
		return _finale_panel
	var p: Node = FinalePanel.new()
	p.name = "HushFinalePanel"
	var host: Node = Lx.root if (Lx.root != null and is_instance_valid(Lx.root)) else get_tree().current_scene
	if host == null: host = self
	host.add_child(p)
	p.connect("display_off_completed", _on_display_off_completed)
	p.connect("keep_display_chosen", _on_keep_display_chosen)
	_finale_panel = p
	return p


func _cleanup_finale_panel() -> void:
	if _finale_panel != null and is_instance_valid(_finale_panel):
		if _finale_panel.is_connected("display_off_completed", _on_display_off_completed):
			_finale_panel.disconnect("display_off_completed", _on_display_off_completed)
		if _finale_panel.is_connected("keep_display_chosen", _on_keep_display_chosen):
			_finale_panel.disconnect("keep_display_chosen", _on_keep_display_chosen)
		if _finale_panel.has_method("hide_panel"): _finale_panel.call("hide_panel")
		_finale_panel.queue_free()
	_finale_panel = null


func _on_display_off_completed() -> void:
	finale_stage = FinaleStage.RESOLVED
	FinalePanel.record_finale_choice("display_off")
	_cleanup_finale_panel()
	if boss_state != BossState.DEATH:
		hp = 0.0; opened_kill = true; void_orb_out = false
		_boss_impact(0.34, 148.0, 140.0); stage.play_sfx("hush_big_blast", pos)
		_begin_death(_pending_kill_hit)


func _on_keep_display_chosen() -> void:
	finale_stage = FinaleStage.UNBROKEN_STAND
	unbroken_timer = UNBROKEN_STAND_SECS
	FinalePanel.record_finale_choice("dawn")
	_emit_narr("ISL8_FINALE_REFUSE", "title", 2.8)
	_set_boss_state(BossState.READY, 0.0); cooldown = 0.45


# --- Combat Helpers ----------------------------------------------------------

func _prep_move(move_enum: int, tgt: Vector2) -> void:
	active_move = move_enum
	commit_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
	facing = commit_dir.angle(); commit_hit = false; commit_elapsed = 0.0


func _pick_sanctuary_circles(tgt: Vector2) -> Array[Vector2]:
	var c: Vector2 = arena_rect.get_center()
	var near_w: Vector2 = arena._safe_pt(tgt.lerp(c, 0.32))
	var opp: Vector2 = arena._safe_pt(c + (c - near_w).limit_length(70.0))
	return [near_w, opp]


func _perimeter_targets(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [tgt]
	var inset: Rect2 = arena_rect.grow(-14.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, corners.size())):
		out.append(clamp_to_arena(corners[i]))
	return out


func _apply_retry_checkpoint_if_needed() -> void:
	if Lx.state == null or Lx.state.defeated_bosses.has(boss_id):
		return
	var retries: int = int(Lx.state.boss_retries.get(boss_id, 0))
	var cp: int = ArenaRules.read_checkpoint()
	if retries <= 0 or cp < 2:
		return
	_checkpoint_phase = cp; intro_duration = 0.28; phase = cp
	hp = ArenaRules.phase_start_hp(max_hp, cp)
	for p_i: int in range(1, cp + 1):
		if not phases_reached.has(p_i): phases_reached.append(p_i)


func _emit_narr(string_id: String, style: String, dur: float) -> void:
	if Lx.events != null and LxStrings.has_id(string_id):
		Lx.events.narration_requested.emit(string_id, style, dur)


func _is_lured() -> bool:
	return (phase == 1 or phase == 2) and _is_lantern_out() and _get_lantern_pos().distance_to(pos) <= 155.0


func _attention_target(fallback: Vector2) -> Vector2:
	return _get_lantern_pos() if _is_lured() else fallback


func _has_active_shield() -> bool:
	return phase == 1 and shield_gone_t <= 0.0 and shield_hp > 0.001 and boss_state != BossState.DEATH and boss_state != BossState.STAGGER


func debug_state() -> Dictionary:
	var d: Dictionary = super.debug_state()
	d["phase_times"] = _phase_times.duplicate()
	d["checkpoint_phase"] = ArenaRules.read_checkpoint()
	d["finale_stage"] = finale_stage
	d["comeback_used"] = arena.comeback_used if arena != null else false
	return d


func _body_color() -> Color:
	if phase == 4: return (PAL["wine"] if not veil_intact else PAL["void"]) as Color
	return (PAL["deep"] if phase == 3 else (PAL["dusk"] if phase == 2 else PAL["night"])) as Color


func _shield_color() -> Color:
	return PAL["sky"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	Visuals.draw_hush(self, off)


func _boss_impact(shake: float, gust_r: float, gust_s: float) -> void:
	LxDamageFx.boss_impact(pos, shake, gust_r, gust_s, gust_r * 1.18, 1.56, 0.44)
