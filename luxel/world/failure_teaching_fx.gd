class_name LxFailureTeachingFx
extends Node2D
## Islands 2..8 zero-text 2-step & failure-recovery diegetic teaching layer (z_index = 6).
## Strictly excludes Island 1. Uses LxPixelGlyphs + 20 opaque Last Light colours (LxPalette.PAL).

const PAL: Dictionary = LxPalette.PAL; const REJECT_DUR: float = 0.85; const F6_REJECT_DUR: float = 0.75; const GUIDE_FADE: float = 0.45
static var _pending_f3: Dictionary = {}
static var _pending_f3_slot: String = ""

var _region: LxRegionLoader = null; var _island_id: int = 0; var _region_id: String = ""
var _clock: float = 0.0; var _cam_center: Vector2 = Vector2.ZERO; var _bound_events: LxEventBus = null
var _was_drawing: bool = false; var _prev_wick_pos: Vector2 = Vector2.INF
var _blue_targets: Array[LxInteractable] = []; var _blue_mirrors: Array[LxMirror] = []
var _beam_barriers: Array[LxInteractable] = []; var _seals: Array[LxObsidianSeal] = []
var _phantom_tiles: PackedVector2Array = PackedVector2Array(); var _phantom_plats: Array[LxPhantomPlatform] = []
var _anchor_lamps: PackedVector2Array = PackedVector2Array()
var _state_prev: Dictionary = {}; var _trig_prev: Dictionary = {}; var _f6_blocks: Dictionary = {}
var _f1_target: Vector2 = Vector2.ZERO; var _f1_mirror: Vector2 = Vector2.INF; var _f1_rej_t: float = 0.0; var _f1_g_t: float = 0.0
var _f2_target: Vector2 = Vector2.ZERO; var _f2_rej_t: float = 0.0; var _f2_g_t: float = 0.0
var _f3_lip: Vector2 = Vector2.ZERO; var _f3_dest: Vector2 = Vector2.INF; var _f3_rej_t: float = 0.0; var _f3_g_t: float = 0.0
var _f4_rej_p: Vector2 = Vector2.ZERO; var _f4_rej_t: float = 0.0; var _f4a_w: float = 0.0; var _f4_ph_p: Vector2 = Vector2.ZERO; var _f4b_w: float = 0.0; var _f4_anc_p: Vector2 = Vector2.ZERO
var _f5_seal: Vector2 = Vector2.ZERO; var _f5_rej_t: float = 0.0; var _f5_g_t: float = 0.0
var _f6_enemy: LxEnemyBrain = null; var _f6_pos: Vector2 = Vector2.ZERO; var _f6_mode: int = -1; var _f6_flag: String = ""; var _f6_rej_t: float = 0.0; var _f6_g_t: float = 0.0

func _ready() -> void: texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; z_index = 6
func _exit_tree() -> void: _unbind_events()
func clear() -> void:
	_unbind_events()
	_region = null; _island_id = 0; _region_id = ""; _clock = 0.0; _was_drawing = false; _prev_wick_pos = Vector2.INF
	_blue_targets.clear(); _blue_mirrors.clear(); _beam_barriers.clear(); _seals.clear()
	_phantom_tiles = PackedVector2Array(); _phantom_plats.clear(); _anchor_lamps = PackedVector2Array()
	_state_prev.clear(); _trig_prev.clear(); _f6_blocks.clear()
	_f1_rej_t = 0.0; _f1_g_t = 0.0; _f1_mirror = Vector2.INF; _f2_rej_t = 0.0; _f2_g_t = 0.0
	_f3_rej_t = 0.0; _f3_g_t = 0.0; _f3_dest = Vector2.INF; _f4_rej_t = 0.0; _f4a_w = 0.0; _f4b_w = 0.0
	_f5_rej_t = 0.0; _f5_g_t = 0.0; _f6_rej_t = 0.0; _f6_g_t = 0.0; _f6_enemy = null; _f6_mode = -1; _f6_flag = ""
	visible = false; queue_redraw()
func rebuild(region: LxRegionLoader) -> void:
	clear()
	if region == null or region.current_island_id <= 1:
		_pending_f3.clear(); _pending_f3_slot = ""
		return
	_region = region; _island_id = region.current_island_id; _region_id = region.current_region_id
	_cam_center = region.spawn_pos if region.spawn_pos != Vector2.ZERO else region.bounds.get_center()
	_cache_region_nodes(region); _sync_events()
	for s: LxObsidianSeal in _seals:
		if s.shattered: _set_flag("tut_seal_shattered"); break
	if not _pending_f3.is_empty():
		var cur_slot: String = Lx.state.slot_id if Lx.state != null else ""
		if Lx.state == null or cur_slot != _pending_f3_slot or _island_id != 4 or str(_pending_f3.get("region", "")) != _region_id:
			_pending_f3.clear(); _pending_f3_slot = ""
		elif (_region_id == "conservatory_r5" or _region_id == "overworld") and not _flag("tut_wings_glided") and _has_move("wings"):
			var lip: Vector2 = _pending_f3.get("lip", region.spawn_pos) as Vector2
			var dest: Vector2 = _pending_f3.get("dest", Vector2.INF) as Vector2
			_pending_f3.clear(); _pending_f3_slot = ""
			if lip.distance_to(region.spawn_pos) <= 200.0:
				_f3_lip = lip; _f3_dest = dest; _f3_rej_t = REJECT_DUR; _f3_g_t = 3.0
		else:
			_pending_f3.clear(); _pending_f3_slot = ""
	visible = true; queue_redraw()
func _cache_region_nodes(region: LxRegionLoader) -> void:
	var is_orr: bool = _island_id == 5 and (_region_id == "orrery_r5" or _region_id == "orrery_r7")
	if is_orr and region.width > 0 and region.height > 0:
		var ts: float = float(region.tile_size)
		for ty: int in range(region.height):
			var row: PackedStringArray = region.grid[ty]
			for tx: int in range(region.width):
				if row[tx] == "phantom": _phantom_tiles.append(Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts))
	for it: LxInteractable in region.get_interactables():
		if it == null or not is_instance_valid(it): continue
		var iid: int = it.get_instance_id()
		if it is LxSwitchEye and (it as LxSwitchEye).requires_prism: _blue_targets.append(it); _state_prev[iid] = (it as LxSwitchEye).activated
		elif it is LxBluePortal and (it as LxBluePortal).requires_blue: _blue_targets.append(it); _state_prev[iid] = (it as LxBluePortal).powered
		elif it is LxMirror and ((it as LxMirror).transforms_to == LxHit.COLOR_BLUE or it.kind == "blue_transformer"): _blue_mirrors.append(it as LxMirror)
		elif it is LxBramble: _beam_barriers.append(it); _state_prev[iid] = (it as LxBramble).burned
		elif it is LxCrackedWall: _beam_barriers.append(it); _state_prev[iid] = (it as LxCrackedWall).broken
		elif it is LxObsidianSeal: _seals.append(it as LxObsidianSeal)
		elif is_orr and it is LxPhantomPlatform: _phantom_plats.append(it as LxPhantomPlatform)
		elif is_orr and it.kind == "road_lamp" and (it.id in ["lamp_o5_r5_mid", "lamp_o5_r7_p1", "lamp_o5_r7_p2"] or _nearest_phantom(it.pos, 96.0, false).is_finite()): _anchor_lamps.append(it.pos)

func _sync_events() -> void:
	if _island_id <= 1 or Lx.events == null or not is_instance_valid(Lx.events) or _bound_events == Lx.events: return
	_unbind_events(); _bound_events = Lx.events
	if not _bound_events.enemy_hit.is_connected(_on_enemy_hit): _bound_events.enemy_hit.connect(_on_enemy_hit)
	if not _bound_events.seal_broken.is_connected(_on_seal_broken): _bound_events.seal_broken.connect(_on_seal_broken)
	if not _bound_events.player_damaged.is_connected(_on_player_damaged): _bound_events.player_damaged.connect(_on_player_damaged)
func _unbind_events() -> void:
	if _bound_events == null or not is_instance_valid(_bound_events): _bound_events = null; return
	if _bound_events.enemy_hit.is_connected(_on_enemy_hit): _bound_events.enemy_hit.disconnect(_on_enemy_hit)
	if _bound_events.seal_broken.is_connected(_on_seal_broken): _bound_events.seal_broken.disconnect(_on_seal_broken)
	if _bound_events.player_damaged.is_connected(_on_player_damaged): _bound_events.player_damaged.disconnect(_on_player_damaged)
	_bound_events = null
func tick(dt: float, cam_center: Vector2) -> void:
	if _island_id <= 1 or _region == null: return
	if Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open")): visible = false; return
	visible = true
	if _bound_events != Lx.events: _sync_events()
	var s: float = maxf(0.0, dt); _clock += s; _cam_center = cam_center
	_f1_rej_t = maxf(0.0, _f1_rej_t - s); _f1_g_t = maxf(0.0, _f1_g_t - s); _f2_rej_t = maxf(0.0, _f2_rej_t - s); _f2_g_t = maxf(0.0, _f2_g_t - s)
	_f3_rej_t = maxf(0.0, _f3_rej_t - s); _f3_g_t = maxf(0.0, _f3_g_t - s); _f4_rej_t = maxf(0.0, _f4_rej_t - s)
	_f5_rej_t = maxf(0.0, _f5_rej_t - s); _f5_g_t = maxf(0.0, _f5_g_t - s); _f6_rej_t = maxf(0.0, _f6_rej_t - s); _f6_g_t = maxf(0.0, _f6_g_t - s)
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	_poll_f1_f2_f5(); _poll_f3_f4(s, wick)
	if _f6_enemy != null:
		if is_instance_valid(_f6_enemy) and _f6_enemy.is_alive(): _f6_pos = _f6_enemy.pos
		else: _f6_enemy = null; _f6_g_t = 0.0
	if wick != null and not wick.dead: _prev_wick_pos = wick.global_position
	var active_now: bool = _has_active_visual()
	if active_now or _was_drawing: _was_drawing = active_now; queue_redraw()

func _poll_f1_f2_f5() -> void:
	if _flag("tut_blue_refract_done"): _f1_rej_t = 0.0; _f1_g_t = 0.0
	else:
		for it: LxInteractable in _blue_targets:
			if it == null or not is_instance_valid(it): continue
			var iid: int = it.get_instance_id()
			var is_on: bool = (it as LxSwitchEye).activated if it is LxSwitchEye else (it as LxBluePortal).powered
			if is_on and not bool(_state_prev.get(iid, false)): _set_flag("tut_blue_refract_done"); _f1_rej_t = 0.0; _f1_g_t = 0.0; break
			_state_prev[iid] = is_on
			var rej: bool = (not is_on) and (((it as LxSwitchEye)._reject_t > 0.0) if it is LxSwitchEye else ((it as LxBluePortal)._reject_t > 0.0))
			if rej and not bool(_trig_prev.get(iid, false)):
				_f1_target = it.pos; _f1_mirror = _nearest_mirror(it.pos, 320.0); _f1_rej_t = REJECT_DUR; _f1_g_t = 2.40
			_trig_prev[iid] = rej
	if _flag("tut_beam_break_done"): _f2_rej_t = 0.0; _f2_g_t = 0.0
	else:
		var has_beam: bool = _has_move("beam")
		for it: LxInteractable in _beam_barriers:
			if it == null or not is_instance_valid(it): continue
			var iid: int = it.get_instance_id()
			var clr: bool = (it as LxBramble).burned if it is LxBramble else (it as LxCrackedWall).broken
			if clr and not bool(_state_prev.get(iid, false)): _set_flag("tut_beam_break_done"); _f2_rej_t = 0.0; _f2_g_t = 0.0; break
			_state_prev[iid] = clr
			var rej: bool = has_beam and (not clr) and (((it as LxBramble)._rustle_t > 0.0) if it is LxBramble else ((it as LxCrackedWall)._hint_t > 0.0))
			if rej and not bool(_trig_prev.get(iid, false)): _f2_target = it.pos; _f2_rej_t = REJECT_DUR; _f2_g_t = 2.40
			_trig_prev[iid] = rej
	if _flag("tut_seal_shattered"): _f5_rej_t = 0.0; _f5_g_t = 0.0
	elif _has_move("sunflare"):
		for s: LxObsidianSeal in _seals:
			if s == null or not is_instance_valid(s) or s.shattered: continue
			var iid: int = s.get_instance_id(); var res_on: bool = s._resonate_t > 0.0
			if res_on and not bool(_trig_prev.get(iid, false)): _f5_seal = s.pos; _f5_rej_t = REJECT_DUR; _f5_g_t = 2.80
			_trig_prev[iid] = res_on

func _poll_f3_f4(dt: float, wick: LxWick) -> void:
	if _flag("tut_wings_glided"): _f3_rej_t = 0.0; _f3_g_t = 0.0
	elif wick != null and not wick.dead and _island_id == 4 and (_region_id == "conservatory_r5" or _region_id == "overworld") \
			and _has_move("wings") and _prev_wick_pos.is_finite() and not wick.is_dashing() and not wick.is_gliding() and not wick.is_zipping():
		if wick.global_position.distance_to(_prev_wick_pos) >= 16.0 and wick.global_position.distance_to(wick._last_safe_pos) <= 2.0 and _region.is_lethal_void_at(_prev_wick_pos):
			_f3_lip = wick.global_position; _f3_dest = _nearest_updraft_or_shore(_f3_lip, _prev_wick_pos); _f3_rej_t = REJECT_DUR; _f3_g_t = 3.0
	if _island_id != 5 or not (_region_id == "orrery_r5" or _region_id == "orrery_r7") or wick == null or wick.dead or not _has_move("lens"):
		_f4a_w = 0.0; _f4b_w = 0.0; return
	var ml: LxMoveLens = wick.move_lens
	var p_on: bool = ml != null and ml.is_pulse_active(); var a_on: bool = ml != null and ml.is_anchor_active()
	if p_on and not _flag("tut_lens_pulsed"): _set_flag("tut_lens_pulsed")
	if a_on and not _flag("tut_lens_anchored") and wick.lantern != null and (wick.lantern.is_hanging() or _nearest_phantom(wick.lantern.pos, 84.0, false).is_finite()):
		_set_flag("tut_lens_anchored")
	var wpos: Vector2 = wick.global_position; var want_a: bool = false; var want_b: bool = false
	if not p_on and not a_on:
		if not _flag("tut_lens_pulsed"):
			var pn: Vector2 = _nearest_phantom(wpos, 36.0, true)
			if pn.is_finite(): _f4_ph_p = pn; want_a = true
		elif not _flag("tut_lens_anchored"):
			var ln: Vector2 = _nearest_in_packed(_anchor_lamps, wpos, 58.0)
			if ln.is_finite(): _f4_anc_p = ln; want_b = true
	_f4a_w = move_toward(_f4a_w, 1.0 if want_a else 0.0, dt * 4.2); _f4b_w = move_toward(_f4b_w, 1.0 if want_b else 0.0, dt * 4.2)

func _on_seal_broken(_isl: int, seal_id: String) -> void:
	if _island_id <= 1 or _region == null or not (_region.find_interactable(seal_id) is LxObsidianSeal): return
	_set_flag("tut_seal_shattered"); _f5_rej_t = 0.0; _f5_g_t = 0.0
func _on_player_damaged(_amount: float, from_pos: Vector2, _knock_dir: Vector2, source: String) -> void:
	if _island_id <= 1 or not (source in ["void", "water", "pit", "hazard"]): return
	if _island_id == 4 and (_region_id == "conservatory_r5" or _region_id == "overworld") and _has_move("wings") and not _flag("tut_wings_glided"):
		var lip: Vector2 = from_pos
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var sp: Vector2 = (Lx.player as LxWick)._last_safe_pos
			if sp != Vector2.ZERO and sp.distance_to(from_pos) <= 72.0: lip = sp
		_f3_lip = lip; _f3_dest = _nearest_updraft_or_shore(lip, from_pos); _f3_rej_t = REJECT_DUR; _f3_g_t = 3.0
		_pending_f3 = {"region": _region_id, "lip": lip, "dest": _f3_dest}
		_pending_f3_slot = Lx.state.slot_id if Lx.state != null else ""
	elif _island_id == 5 and (_region_id == "orrery_r5" or _region_id == "orrery_r7") and _has_move("lens") and not _flag("tut_lens_pulsed"):
		_f4_rej_p = from_pos; _f4_rej_t = REJECT_DUR
func _on_enemy_hit(enemy: Object, _hit: Object, result: int) -> void:
	if _island_id <= 1 or not (enemy is LxEnemyBrain): return
	var eb: LxEnemyBrain = enemy as LxEnemyBrain; var mode: int = -1; var fk: String = ""
	match eb.kind:
		"crab_warden", "tide_captain": mode = 0; fk = "tut_blue_guard_crack"
		"orrery_sentinel", "clockwork_warden": mode = 1; fk = "tut_clockwork_flank"
		"cinder_golem", "forge_warden": mode = 2; fk = "tut_armour_crack"
		"moonshade_warden", "spire_warden", "night_harbinger": mode = 3; fk = "tut_lunar_guard_crack"
		_: return
	if _flag(fk): return
	if result == LxEnemyBrain.HitResult.OPENED:
		_set_flag(fk)
		if _f6_flag == fk or _f6_enemy == eb: _f6_rej_t = 0.0; _f6_g_t = 0.0; _f6_enemy = null
		return
	if result != LxEnemyBrain.HitResult.BLOCKED and not (mode == 2 and result == LxEnemyBrain.HitResult.CHIPPED and eb.get("armour_intact") == true): return
	var cnt: int = int(_f6_blocks.get(fk, 0)) + 1
	if cnt >= 2: _f6_blocks[fk] = 0; _f6_enemy = eb; _f6_pos = eb.pos; _f6_mode = mode; _f6_flag = fk; _f6_rej_t = F6_REJECT_DUR; _f6_g_t = 2.60
	else: _f6_blocks[fk] = cnt
func _draw() -> void:
	if _island_id <= 1 or _region == null or not _has_active_visual(): return
	var fred: bool = LxHudFx.flash_reduced(); var bob: float = 0.0 if fred else roundf(sin(_clock * 3.6) * 1.2)
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var wpos: Vector2 = wick.global_position if wick != null else _cam_center
	_draw_f1_f2_f3(wpos, wick, bob, fred); _draw_f4_f5(wpos, wick, bob, fred); _draw_f6(wpos, wick, bob, fred)
func _draw_f1_f2_f3(wpos: Vector2, wick: LxWick, bob: float, fred: bool) -> void:
	if _f1_rej_t > 0.0: LxPixelGlyphs.draw_reject_x(self, _f1_target + Vector2(0.0, -6.0), 1.0 - _f1_rej_t / REJECT_DUR, 1.0, fred)
	if _f1_g_t > 0.0 and _f1_mirror.is_finite():
		var w1: float = clampf(_f1_g_t / GUIDE_FADE, 0.0, 1.0)
		_draw_brackets(_f1_mirror + Vector2(0.0, -3.0), 10.0 + (0.0 if fred else roundf(sin(_clock * 5.0) * 1.2)), w1, "ice" if (fred or sin(_clock * 5.0) > 0.0) else "sky")
		_draw_chevrons(_f1_mirror, _f1_target, 3, w1, "ice", "sky", fred)
		if wick != null: _draw_cap(wpos, _f1_mirror, "lx_fire", w1, bob, fred, "ice")
	if _f2_rej_t > 0.0: LxPixelGlyphs.draw_reject_x(self, _f2_target + Vector2(0.0, -4.0), 1.0 - _f2_rej_t / REJECT_DUR, 1.0, fred)
	if _f2_g_t > 0.0 and wick != null:
		var w2: float = clampf(_f2_g_t / GUIDE_FADE, 0.0, 1.0); var chg: bool = wick.is_beam_charging()
		_draw_chevrons(wpos + Vector2(0.0, -5.0), _f2_target, 3, w2, "cream" if chg else "gold", "gold" if chg else "apricot", fred)
		if chg: _draw_brackets(_f2_target, 10.0, w2, "cream")
		_draw_cap(wpos, _f2_target, "lx_beam", w2, bob, fred, "cream" if chg else "gold")
	if _f3_rej_t > 0.0: LxPixelGlyphs.draw_reject_x(self, _f3_lip + Vector2(0.0, -4.0), 1.0 - _f3_rej_t / REJECT_DUR, 1.0, fred)
	if _f3_g_t > 0.0 and _f3_dest.is_finite():
		var w3: float = clampf(_f3_g_t / GUIDE_FADE, 0.0, 1.0)
		var orig: Vector2 = wpos if (wick != null and wpos.distance_squared_to(_f3_dest) < _f3_lip.distance_squared_to(_f3_dest)) else _f3_lip
		_draw_chevrons(orig, _f3_dest, 3, w3, "rose", "ice", fred); _draw_brackets(_f3_dest, 9.0, w3, "rose")
		if wick != null: _draw_cap(wpos, _f3_dest, "lx_dash", w3, bob, fred, "rose", true)

func _draw_f4_f5(wpos: Vector2, wick: LxWick, bob: float, fred: bool) -> void:
	if _f4_rej_t > 0.0: LxPixelGlyphs.draw_reject_x(self, _f4_rej_p, 1.0 - _f4_rej_t / REJECT_DUR, 1.0, fred)
	if _f4a_w > 0.05 and wick != null:
		_draw_brackets(_f4_ph_p, 8.0, _f4a_w, "ice")
		var u: float = 0.55 if fred else fposmod(_clock * 0.85, 1.0)
		var ac: Color = LxPalette.fade_step(_f4a_w * (1.0 - u * 0.6), "ice" if u < 0.45 else "sky")
		if ac.a > 0.0: _draw_dotted_circle(wpos + Vector2(0.0, -4.0), roundf(lerpf(12.0, 42.0, u)), 12, ac)
		_draw_cap(wpos, _f4_ph_p, "lx_lens", _f4a_w, bob, fred, "sky")
	if _f4b_w > 0.05 and wick != null:
		_draw_brackets(_f4_anc_p + Vector2(0.0, -4.0), 9.0, _f4b_w, "gold")
		_draw_chevrons(wpos + Vector2(0.0, -5.0), _f4_anc_p, 2, _f4b_w, "gold", "apricot", fred)
		_draw_cap(wpos, _f4_anc_p, "lx_throw", _f4b_w, bob, fred, "gold")
	if _f5_rej_t > 0.0: LxPixelGlyphs.draw_reject_x(self, _f5_seal + Vector2(0.0, -4.0), 1.0 - _f5_rej_t / REJECT_DUR, 1.0, fred)
	if _f5_g_t <= 0.0 or wick == null or wick.move_sunflare == null: return
	var w5: float = clampf(_f5_g_t / GUIDE_FADE, 0.0, 1.0)
	if wick.ember >= wick.move_sunflare.get_ember_max() - 0.5:
		var hot: bool = fred or fmod(_clock, 0.52) < 0.26; var ck: String = "cream" if hot else "gold"
		var rc: Color = LxPalette.fade_step(w5, ck)
		if rc.a > 0.0: _draw_dotted_circle(_f5_seal, 76.0, 24, rc); LxPixelGlyphs.draw_target_brackets(self, _f5_seal.round(), 12.0, rc)
		_draw_cap(wpos, _f5_seal, "lx_sunflare", w5, bob, fred, ck)
	else:
		var pc: Color = LxPalette.fade_step(w5 if (fred or fmod(_clock, 0.44) < 0.24) else w5 * 0.42, "coral")
		if pc.a > 0.0:
			var bp: Vector2 = (wpos + Vector2(-5.0, -15.0 + bob)).round()
			draw_rect(Rect2(bp - Vector2.ONE, Vector2(12.0, 4.0)), PAL["void"] as Color)
			for pi: int in range(3): draw_rect(Rect2(bp + Vector2(float(pi) * 4.0, 0.0), Vector2(2.0, 2.0)), pc)
		var vp: Vector2 = _nearest_magma_vent(wpos, 240.0); var tgt: Vector2 = vp if vp.is_finite() else _nearest_live_enemy(wpos, 240.0)
		if tgt.is_finite():
			_draw_chevrons(wpos + Vector2(0.0, -4.0), tgt, 3, w5, "gold", "apricot", fred)
			_draw_cap(wpos, tgt, "lx_dash" if vp.is_finite() else "lx_fire", w5, bob, fred, "apricot")

func _draw_f6(wpos: Vector2, wick: LxWick, bob: float, fred: bool) -> void:
	if _f6_rej_t > 0.0: LxPixelGlyphs.draw_reject_x(self, _f6_pos + Vector2(0.0, -8.0), 1.0 - _f6_rej_t / F6_REJECT_DUR, 1.0, fred)
	if _f6_g_t <= 0.0 or wick == null: return
	var w: float = clampf(_f6_g_t / GUIDE_FADE, 0.0, 1.0)
	if _f6_mode == 0 or _f6_mode == 3:
		var mir: Vector2 = _nearest_mirror(_f6_pos, 240.0); var ped: Vector2 = _nearest_arena_pedestal(_f6_pos, 240.0)
		var anc: Vector2 = ped if (ped.is_finite() and (not mir.is_finite() or ped.distance_squared_to(_f6_pos) < mir.distance_squared_to(_f6_pos))) else mir
		if anc.is_finite():
			_draw_brackets(anc + Vector2(0.0, -4.0), 10.0, w, "ice"); _draw_chevrons(anc, _f6_pos, 3, w, "ice", "sky", fred)
			_draw_cap(wpos, anc, "lx_fire", w, bob, fred, "ice")
		else: _draw_cap(wpos, _f6_pos, "lx_throw", w, bob, fred, "gold")
	elif _f6_mode == 1:
		var bd: Vector2 = -Vector2.from_angle(_f6_enemy.facing) if (_f6_enemy != null and is_instance_valid(_f6_enemy)) else (wpos - _f6_pos).normalized()
		var rp: Vector2 = _f6_pos + bd * 20.0; var sd := Vector2(-bd.y, bd.x)
		if sd.dot(wpos - _f6_pos) < 0.0: sd = -sd
		var ctrl: Vector2 = _f6_pos + sd * 26.0; var ch: Color = LxPalette.fade_step(w, "gold"); var cm: Color = LxPalette.fade_step(w, "apricot")
		if ch.a > 0.0:
			LxPixelGlyphs.draw_target_brackets(self, rp.round(), 7.0, ch)
			var spd: float = 0.50 if fred else 1.15
			for i: int in range(3):
				var u: float = fposmod(_clock * spd + float(i) / 3.0, 1.0); var inv: float = 1.0 - u
				LxPixelGlyphs.draw_dir_chevron(self, wpos * (inv * inv) + ctrl * (2.0 * inv * u) + rp * (u * u), (ctrl - wpos) * (2.0 * inv) + (rp - ctrl) * (2.0 * u), ch, cm)
		_draw_cap(wpos, _f6_pos, "lx_lens" if _has_move("lens") else "lx_dash", w, bob, fred, "sky" if _has_move("lens") else "gold")
	elif _f6_mode == 2:
		if wick.move_sunflare != null and wick.move_sunflare.unlocked and wick.ember >= wick.move_sunflare.get_ember_max() - 0.5:
			_draw_brackets(_f6_pos, 11.0, w, "gold"); _draw_cap(wpos, _f6_pos, "lx_sunflare", w, bob, fred, "gold")
		else:
			var ped: Vector2 = _nearest_arena_pedestal(wpos, 220.0); var tgt: Vector2 = ped if ped.is_finite() else _nearest_magma_vent(wpos, 220.0)
			if tgt.is_finite():
				_draw_brackets(tgt + Vector2(0.0, -4.0), 10.0, w, "apricot"); _draw_chevrons(wpos + Vector2(0.0, -4.0), tgt, 3, w, "gold", "apricot", fred)
				_draw_cap(wpos, tgt, "lx_fire" if ped.is_finite() else "lx_dash", w, bob, fred, "apricot")
			elif _has_move("beam"): _draw_cap(wpos, _f6_pos, "lx_beam", w, bob, fred, "gold")

func _draw_brackets(center: Vector2, r: float, w: float, col_k: String) -> void:
	var c: Color = LxPalette.fade_step(w, col_k)
	if c.a > 0.0: LxPixelGlyphs.draw_target_brackets(self, center.round(), r, c)
func _draw_cap(wpos: Vector2, tgt: Vector2, act: String, w: float, bob: float, fred: bool, acc: String, hold_prefix: bool = false) -> void:
	LxPixelGlyphs.draw_action_keycap(self, LxPixelGlyphs.opposite_glyph_pos(wpos, tgt, bob), act, w, _clock, fred, acc, hold_prefix)
func _draw_chevrons(a: Vector2, b: Vector2, count: int, w: float, hi_k: String, mid_k: String, fred: bool) -> void:
	var dv: Vector2 = b - a
	if dv.length_squared() < 256.0: return
	var ch: Color = LxPalette.fade_step(w, hi_k); var cm: Color = LxPalette.fade_step(w, mid_k)
	if ch.a <= 0.0: return
	var dir: Vector2 = dv.normalized(); var spd: float = 0.48 if fred else 1.18
	for i: int in range(count):
		LxPixelGlyphs.draw_dir_chevron(self, a.lerp(b, lerpf(0.18, 0.84, fposmod(_clock * spd + float(i) / float(count), 1.0))), dir, ch, cm)
func _draw_dotted_circle(center: Vector2, rad: float, dots: int, col: Color) -> void:
	var c: Vector2 = center.round()
	for k: int in range(dots):
		var ang: float = (TAU * float(k)) / float(dots) + _clock * 0.22
		draw_rect(Rect2((c + Vector2(cos(ang), sin(ang)) * rad).round(), Vector2.ONE), col)
func _nearest_mirror(from_p: Vector2, max_d: float) -> Vector2:
	var best := Vector2.INF; var bd2: float = max_d * max_d
	for m: LxMirror in _blue_mirrors:
		if m != null and is_instance_valid(m) and m.active and m.pos.distance_squared_to(from_p) < bd2: bd2 = m.pos.distance_squared_to(from_p); best = m.pos
	return best
func _nearest_arena_pedestal(from_p: Vector2, max_d: float) -> Vector2:
	var bm: LxBiomeMechanics = LxBiomeMechanics.active_instance
	var bs: Variant = bm.get("_boss_synergy") if (bm != null and is_instance_valid(bm)) else null
	var mbs: Variant = (bs as Object).get("_mb_synergy") if (bs is Object and is_instance_valid(bs)) else null
	var ancs: Variant = (mbs as Object).get("_anchors") if (mbs is Object and is_instance_valid(mbs)) else null
	if not (ancs is Array): return Vector2.INF
	var best := Vector2.INF; var bd2: float = max_d * max_d
	for av: Variant in (ancs as Array):
		if av is Dictionary and (av as Dictionary).get("pos") is Vector2:
			var ap: Vector2 = (av as Dictionary)["pos"] as Vector2
			var sc: float = ap.distance_squared_to(from_p) + (1600.0 if float((av as Dictionary).get("cd", 0.0)) > 0.0 else 0.0)
			if sc < bd2: bd2 = sc; best = ap
	return best
func _nearest_magma_vent(from_p: Vector2, max_d: float) -> Vector2:
	var br: LxBiomeRules = LxBiomeRules.active_instance
	if br == null or not is_instance_valid(br): return Vector2.INF
	var best := Vector2.INF; var bd2: float = max_d * max_d
	for v: Dictionary in br._vents:
		var vp: Vector2 = v["pos"] as Vector2
		var sc: float = vp.distance_squared_to(from_p) + (0.0 if fposmod(br.vent_cycle + float(v["phase"]), 1.0) >= 0.45 else 3600.0)
		if sc < bd2: bd2 = sc; best = vp
	return best
func _nearest_live_enemy(from_p: Vector2, max_d: float) -> Vector2:
	var best := Vector2.INF; var bd2: float = max_d * max_d
	for e: LxEnemyBrain in _region.get_enemies():
		if e != null and is_instance_valid(e) and e.is_alive() and e.pos.distance_squared_to(from_p) < bd2: bd2 = e.pos.distance_squared_to(from_p); best = e.pos
	return best
func _nearest_updraft_or_shore(lip: Vector2, drop_p: Vector2) -> Vector2:
	var br: LxBiomeRules = LxBiomeRules.active_instance
	if br != null and is_instance_valid(br):
		var best := Vector2.INF; var bd2: float = 19600.0
		for u: Dictionary in br._updrafts:
			var up: Vector2 = u["pos"] as Vector2; var d2: float = up.distance_squared_to(lip)
			if d2 < bd2 and d2 >= 64.0: bd2 = d2; best = up
		if best.is_finite(): return best
	var dir: Vector2 = (drop_p - lip).normalized() if drop_p.distance_squared_to(lip) > 4.0 else Vector2.RIGHT
	for si: int in range(3, 8):
		var probe: Vector2 = lip + dir * (float(si) * 16.0)
		if not _region.is_lethal_void_at(probe): return probe.round()
	return (lip + dir * 72.0).round()
func _nearest_phantom(p: Vector2, max_d: float, only_hidden: bool) -> Vector2:
	var best: Vector2 = _nearest_in_packed(_phantom_tiles, p, max_d)
	var bd2: float = best.distance_squared_to(p) if best.is_finite() else (max_d * max_d)
	for pp: LxPhantomPlatform in _phantom_plats:
		if pp != null and is_instance_valid(pp) and (not only_hidden or not pp.revealed) and pp.pos.distance_squared_to(p) < bd2: bd2 = pp.pos.distance_squared_to(p); best = pp.pos
	return best
static func _nearest_in_packed(arr: PackedVector2Array, from_p: Vector2, max_d: float) -> Vector2:
	var best := Vector2.INF; var bd2: float = max_d * max_d
	for i: int in range(arr.size()):
		if arr[i].distance_squared_to(from_p) < bd2: bd2 = arr[i].distance_squared_to(from_p); best = arr[i]
	return best
func _has_active_visual() -> bool: return _f1_rej_t > 0.0 or _f1_g_t > 0.0 or _f2_rej_t > 0.0 or _f2_g_t > 0.0 or _f3_rej_t > 0.0 or _f3_g_t > 0.0 or _f4_rej_t > 0.0 or _f4a_w > 0.05 or _f4b_w > 0.05 or _f5_rej_t > 0.0 or _f5_g_t > 0.0 or _f6_rej_t > 0.0 or _f6_g_t > 0.0
static func _flag(key: String) -> bool: return Lx.state != null and bool(Lx.state.story_flags.get(key, false))
static func _set_flag(key: String) -> void:
	if Lx.state != null: Lx.state.story_flags[key] = true
static func _has_move(move_id: String) -> bool: return Lx.state != null and Lx.state.has_move(move_id)
