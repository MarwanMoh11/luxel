class_name LxIsland1TutorialCues
extends Node2D
## Island 1 visual-first diegetic world cues (320x180 pixel art, strict Last Light 20-colour palette).
## Guides spawn -> floor lantern -> first enemy -> road lamps -> Orchard Beacon + Dash ->
## 32px Dash Chasm -> Moonlit River Throw/Zip with zero text walls. Flash-Reduction compliant.

const PAL: Dictionary = LxPalette.PAL
const POS_LANTERN := Vector2(640.0, 366.0)
const POS_WARDEN := Vector2(574.0, 366.0)
const POS_BEACON_ORCHARD := Vector2(224.0, 176.0)
const POS_SHRINE_DASH := Vector2(164.0, 176.0)
const POS_CHASM_TOP := Vector2(184.0, 232.0)
const POS_CHASM_BOT := Vector2(184.0, 280.0)
const POS_PIER_LIP := Vector2(984.0, 360.0)
const POS_BRAZIER_EAST := Vector2(1068.0, 360.0)
const LEADING_LAMPS: Array[Dictionary] = [
	{"id": "lamp_plaza_w", "pos": Vector2(512.0, 344.0)},
	{"id": "lamp_orchard_turn", "pos": Vector2(448.0, 304.0)},
	{"id": "lamp_orchard_e", "pos": Vector2(424.0, 216.0)},
]

var _clock: float = 0.0
var _s0_w: float = 0.0; var _s1_w: float = 0.0; var _s2_w: float = 0.0
var _s3_halo_w: float = 0.0; var _s3_gap_w: float = 0.0; var _s4_w: float = 0.0
var _prev_has_lantern: bool = false
var _pickup_burst_t: float = 0.0
var _pickup_burst_pos: Vector2 = POS_LANTERN
var _warden_hit: bool = false
var _prev_warden_alive: bool = false
var _warden_death_pos: Vector2 = POS_WARDEN
var _celebrate_t: float = 0.0
var _dash_crossed: bool = false; var _river_crossed: bool = false
var _has_thrown: bool = false; var _throw_hint_shown: bool = false
var _warden_blocks: int = 0
var _bound_events: LxEventBus = null


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_prev_has_lantern = _has_lantern()
	_throw_hint_shown = Lx.state != null and bool(Lx.state.story_flags.get("throw_combat_hint_shown", false))
	var w_en: LxEnemyBrain = _find_warden()
	_prev_warden_alive = w_en != null and w_en.is_alive()
	_sync_events()

func _exit_tree() -> void:
	_unbind_events()

func _sync_events() -> void:
	if Lx.events == null or not is_instance_valid(Lx.events) or _bound_events == Lx.events: return
	_unbind_events()
	_bound_events = Lx.events
	if not _bound_events.enemy_hit.is_connected(_on_enemy_hit): _bound_events.enemy_hit.connect(_on_enemy_hit)
	if not _bound_events.enemy_killed.is_connected(_on_enemy_killed): _bound_events.enemy_killed.connect(_on_enemy_killed)
	if not _bound_events.lantern_thrown.is_connected(_on_lantern_thrown): _bound_events.lantern_thrown.connect(_on_lantern_thrown)
	if _bound_events.has_signal("lantern_picked_up") and not _bound_events.is_connected("lantern_picked_up", _on_lantern_picked_up):
		_bound_events.connect("lantern_picked_up", _on_lantern_picked_up)

func _unbind_events() -> void:
	if _bound_events == null or not is_instance_valid(_bound_events): _bound_events = null; return
	if _bound_events.enemy_hit.is_connected(_on_enemy_hit): _bound_events.enemy_hit.disconnect(_on_enemy_hit)
	if _bound_events.enemy_killed.is_connected(_on_enemy_killed): _bound_events.enemy_killed.disconnect(_on_enemy_killed)
	if _bound_events.lantern_thrown.is_connected(_on_lantern_thrown): _bound_events.lantern_thrown.disconnect(_on_lantern_thrown)
	if _bound_events.has_signal("lantern_picked_up") and _bound_events.is_connected("lantern_picked_up", _on_lantern_picked_up):
		_bound_events.disconnect("lantern_picked_up", _on_lantern_picked_up)
	_bound_events = null

func _on_lantern_picked_up(_pickup_id: String, pickup_pos: Vector2) -> void:
	_pickup_burst_pos = pickup_pos; _pickup_burst_t = 0.65

func _on_lantern_thrown(_pos: Vector2, _dir: Vector2) -> void:
	_has_thrown = true

func _trigger_throw_combat_hint() -> void:
	if _throw_hint_shown: return
	_throw_hint_shown = true
	if Lx.state != null: Lx.state.story_flags["throw_combat_hint_shown"] = true
	if Lx.events != null: Lx.events.prompt_requested.emit("PROMPT_THROW", "lx_throw", 5.5)

func _on_enemy_hit(enemy: Object, hit: Object, result: int) -> void:
	if not (enemy is LxEnemyBrain): return
	var eb: LxEnemyBrain = enemy as LxEnemyBrain
	if eb.enemy_id == "warden_plaza_0": _warden_hit = true
	if _throw_hint_shown or _has_thrown or not _has_lantern() or Lx.state == null or not Lx.state.has_move("throw"):
		return
	var src: String = str(hit.get("source")) if (hit != null and hit.get("source") != null) else ""
	if result == LxEnemyBrain.HitResult.BLOCKED and src != "throw":
		if eb.kind == "snatcher":
			_trigger_throw_combat_hint()
		elif eb.kind == "warden" and eb.enemy_id != "warden_plaza_0":
			_warden_blocks += 1
			if _warden_blocks >= 2:
				_trigger_throw_combat_hint()

func _on_enemy_killed(enemy: Object, _kind: String, pos: Vector2, _opened: bool) -> void:
	if enemy is LxEnemyBrain and (enemy as LxEnemyBrain).enemy_id == "warden_plaza_0": _warden_death_pos = pos; _celebrate_t = 3.2

func _process(delta: float) -> void:
	if Lx.state == null or Lx.state.island_id != 1 or Lx.state.region_id != "overworld": visible = false; return
	if Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open")): visible = false; return
	visible = true
	if _bound_events != Lx.events: _sync_events()
	_clock += delta
	_pickup_burst_t = maxf(0.0, _pickup_burst_t - delta)
	_celebrate_t = maxf(0.0, _celebrate_t - delta)
	var wpos: Vector2 = _player_pos()
	var has_lan: bool = _has_lantern()
	if not _has_thrown and bool(_lantern_status()["out"]): _has_thrown = true
	if has_lan and not _prev_has_lantern: _pickup_burst_pos = _interactable_pos("lantern_pickup_1", POS_LANTERN); _pickup_burst_t = 0.65
	_prev_has_lantern = has_lan
	var warden: LxEnemyBrain = _find_warden()
	var warden_alive: bool = warden != null and warden.is_alive()
	if warden_alive and warden.hp < warden.max_hp: _warden_hit = true
	if _prev_warden_alive and not warden_alive: _celebrate_t = 3.2
	_prev_warden_alive = warden_alive
	var beacon_orchard_lit: bool = _is_beacon_lit("beacon_orchard")
	var has_dash: bool = Lx.state.has_move("dash") or Lx.state.claimed_shrines.has("shrine_dash")
	if has_dash and not _dash_crossed:
		if _is_beacon_lit("beacon_observatory") or _is_inter_bool("lamp_orchard_s", "lit") or (wpos.y >= 274.0 and absf(wpos.x - 184.0) <= 68.0) or (_player_is_dashing() and wpos.distance_to(Vector2(184.0, 250.0)) <= 52.0):
			_dash_crossed = true
	if not _river_crossed and wpos.x >= 1036.0 and wpos.y >= 260.0 and wpos.y <= 450.0: _river_crossed = true
	var t0: float = 1.0 if (not has_lan) else 0.0
	var t1: float = (0.56 if _warden_hit else 1.0) if (has_lan and warden_alive and wpos.distance_to(warden.pos) <= 220.0) else 0.0
	var t2: float = 1.0 if (has_lan and not warden_alive and not beacon_orchard_lit and wpos.x <= 780.0 and wpos.y <= 440.0) else 0.0
	var t3_h: float = 1.0 if (has_lan and (not has_dash or not beacon_orchard_lit) and wpos.distance_to(POS_SHRINE_DASH.lerp(POS_BEACON_ORCHARD, 0.5)) <= 160.0) else 0.0
	var dist_rim: float = wpos.distance_to(Vector2(clampf(wpos.x, 164.0, 204.0), 236.0))
	var t3_g: float = clampf((56.0 - dist_rim) / 28.0, 0.0, 1.0) if (has_dash and not _dash_crossed and dist_rim <= 56.0) else 0.0
	var t4: float = 1.0 if (has_lan and Lx.state.has_move("throw") and not _is_river_resolved() and wpos.x >= 870.0 and wpos.y >= 260.0 and wpos.y <= 450.0) else 0.0
	_s0_w = move_toward(_s0_w, t0, delta * (4.2 if t0 < _s0_w else 3.2))
	_s1_w = move_toward(_s1_w, t1, delta * (4.0 if t1 < _s1_w else 2.8))
	_s2_w = move_toward(_s2_w, t2, delta * 2.4)
	_s3_halo_w = move_toward(_s3_halo_w, t3_h, delta * 2.5)
	_s3_gap_w = move_toward(_s3_gap_w, t3_g, delta * 4.0)
	_s4_w = move_toward(_s4_w, t4, delta * 3.2)
	if _s0_w > 0.01 or _s1_w > 0.01 or _s2_w > 0.01 or _s3_halo_w > 0.01 or _s3_gap_w > 0.01 or _s4_w > 0.01 or _pickup_burst_t > 0.0:
		queue_redraw()


func _draw() -> void:
	if not visible or Lx.state == null: return
	var fred: bool = LxHudFx.flash_reduced()
	var wpos: Vector2 = _player_pos()
	if _pickup_burst_t > 0.0:
		var u: float = 1.0 - clampf(_pickup_burst_t / 0.65, 0.0, 1.0)
		var col: Color = LxPalette.fade_step(1.0 - u, "cream" if u < 0.35 else "gold")
		if col.a > 0.0:
			draw_arc(_pickup_burst_pos.round(), roundf(lerpf(6.0, 26.0 if fred else 32.0, u)), 0.0, TAU, 20, col, 1.0, false)
	if _s0_w > 0.08: _draw_stage0_lantern_pull(wpos, _s0_w, fred)
	if _s1_w > 0.08: _draw_stage1_shoot_cue(wpos, _s1_w, fred)
	if _s2_w > 0.08: _draw_stage2_leading_path(wpos, _s2_w, fred)
	if _s3_halo_w > 0.08: _draw_stage3_orchard_harmony(_s3_halo_w, fred)
	if _s3_gap_w > 0.08: _draw_stage3_dash_chasm(_s3_gap_w, fred)
	if _s4_w > 0.08: _draw_stage4_river_throw(wpos, _s4_w, fred)


func _draw_stage0_lantern_pull(wpos: Vector2, w: float, fred: bool) -> void:
	var lpos: Vector2 = _interactable_pos("lantern_pickup_1", POS_LANTERN).round()
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0: return
	var spd: float = 0.35 if fred else 0.72
	for ri: int in range(2):
		var p: float = fmod(_clock * spd + float(ri) * 0.5, 1.0)
		var rcol: Color = LxPalette.fade_step(w * (1.0 - p * 0.78), "cream" if p < 0.32 else "gold")
		if rcol.a > 0.0: _draw_pixel_ellipse(lpos + Vector2(0.0, 1.0), roundf(lerpf(9.0, 21.0, p)), roundf(lerpf(4.0, 9.0, p)), 14, rcol)
	var start_p: Vector2 = wpos + Vector2(0.0, -5.0)
	var end_p: Vector2 = lpos + Vector2(0.0, -4.0)
	if start_p.distance_to(end_p) >= 16.0:
		var m_spd: float = 0.28 if fred else 0.52
		for mi: int in range(7):
			var u: float = fmod(_clock * m_spd + float(mi) / 7.0, 1.0)
			var mp: Vector2 = start_p.lerp(end_p, u)
			mp.y += roundf(sin(u * TAU + float(mi) * 1.3 + _clock * (1.2 if fred else 2.6)) * 3.5)
			draw_rect(Rect2(mp.round(), Vector2(2.0, 1.0) if u > 0.6 else Vector2.ONE), c_cream if u > 0.75 else (c_gold if u > 0.35 else c_apr))
	_draw_down_chevron(lpos + Vector2(0.0, -21.0 + (0.0 if fred else roundf(sin(_clock * 4.2) * 2.0))), c_cream, c_gold)

func _draw_stage1_shoot_cue(wpos: Vector2, w: float, fred: bool) -> void:
	var warden: LxEnemyBrain = _find_warden()
	var tpos: Vector2 = (warden.pos if (warden != null and warden.is_alive()) else POS_WARDEN) + Vector2(0.0, -7.0)
	var origin: Vector2 = wpos + Vector2(0.0, -6.0)
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0: return
	var delta_v: Vector2 = tpos - origin
	var dist: float = delta_v.length()
	if dist > 28.0:
		var dir: Vector2 = delta_v / dist
		var d: float = 15.0 + (0.0 if fred else fmod(_clock * 18.0, 8.0))
		while d < dist - 14.0:
			var dp: Vector2 = (origin + dir * d).round()
			draw_rect(Rect2(dp + Vector2(0.0, 1.0), Vector2(2.0, 1.0)), PAL["void"] as Color)
			draw_rect(Rect2(dp, Vector2(2.0, 1.0)), c_cream if d > dist - 34.0 else (c_gold if int(d / 8.0) % 2 == 0 else c_apr))
			d += 8.0
	var br: float = 11.0 + (0.0 if fred else roundf(sin(_clock * 4.0) * 1.2))
	_draw_target_brackets(tpos.round(), br, c_cream if (fred or sin(_clock * 4.0) > 0.2) else c_gold)
	_draw_pixel_mouse((wpos + Vector2(0.0, -27.0 + (0.0 if fred else roundf(sin(_clock * 3.4) * 1.0)))).round(), false, w, fred)


func _draw_stage2_leading_path(wpos: Vector2, w: float, fred: bool) -> void:
	var pts: Array[Vector2] = [
		_warden_death_pos + Vector2(0.0, -6.0),
		_interactable_pos("lamp_plaza_w", LEADING_LAMPS[0]["pos"] as Vector2) + Vector2(0.0, -10.0),
		_interactable_pos("lamp_orchard_turn", LEADING_LAMPS[1]["pos"] as Vector2) + Vector2(0.0, -10.0),
		_interactable_pos("lamp_orchard_e", LEADING_LAMPS[2]["pos"] as Vector2) + Vector2(0.0, -10.0),
		_interactable_pos("beacon_orchard", POS_BEACON_ORCHARD) + Vector2(0.0, -10.0),
	]
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0: return
	var count: int = 14 if _celebrate_t > 0.0 else 8
	var spd: float = (0.20 if fred else 0.36) if _celebrate_t > 0.0 else (0.10 if fred else 0.18)
	for i: int in range(count):
		var u: float = fmod(_clock * spd + float(i) / float(count), 1.0)
		var sway := Vector2.ZERO if fred else Vector2(cos(_clock * 2.3 + float(i) * 2.1) * 2.0, sin(_clock * 3.0 + float(i) * 1.7) * 3.0)
		var fp: Vector2 = (_sample_polyline(pts, u) + sway).round()
		var bright: bool = (i % 3 == 0) or _celebrate_t > 0.5
		draw_rect(Rect2(fp, Vector2(2.0, 1.0) if bright else Vector2.ONE), c_cream if bright else c_gold)
		if not fred and bright:
			draw_rect(Rect2(fp + Vector2(2.0, 1.0), Vector2.ONE), c_apr)
	var next_pos: Vector2 = _interactable_pos("beacon_orchard", POS_BEACON_ORCHARD)
	var targeting_beacon: bool = true
	for entry: Dictionary in LEADING_LAMPS:
		var lid: String = str(entry["id"])
		if not _is_inter_bool(lid, "lit"):
			next_pos = _interactable_pos(lid, entry["pos"] as Vector2)
			targeting_beacon = false
			break
	if targeting_beacon and wpos.distance_to(next_pos) <= 96.0:
		return
	var head: Vector2 = (next_pos + Vector2(0.0, -14.0)).round()
	var pu: float = 0.45 if fred else fmod(_clock * 0.85, 1.0)
	var lcol: Color = LxPalette.fade_step(w * (1.0 - pu * 0.7), "cream" if pu < 0.35 else "gold")
	if lcol.a > 0.0:
		draw_arc(head, roundf(lerpf(5.0, 14.0, pu)), 0.0, TAU, 16, lcol, 1.0, false)
	if fred or int(_clock * 4.0) % 2 == 0:
		draw_rect(Rect2(head + Vector2(0.0, -6.0), Vector2.ONE), c_cream)


func _draw_stage3_orchard_harmony(w: float, fred: bool) -> void:
	# Delicate floor-level golden mote link strictly in the stone gap between Shrine and Beacon.
	var s_pos: Vector2 = _interactable_pos("shrine_dash", POS_SHRINE_DASH) + Vector2(15.0, 2.0)
	var b_pos: Vector2 = _interactable_pos("beacon_orchard", POS_BEACON_ORCHARD) + Vector2(-15.0, 2.0)
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0: return
	var ctrl: Vector2 = s_pos.lerp(b_pos, 0.5) + Vector2(0.0, 3.0)
	var spd: float = 0.14 if fred else 0.28
	for i: int in range(4):
		var u: float = fmod(_clock * spd + float(i) * 0.25, 1.0)
		var pt: Vector2 = _quad_bezier(s_pos, ctrl, b_pos, u).round()
		draw_rect(Rect2(pt, Vector2.ONE), c_gold if (i % 2 == 0) else c_apr)


func _draw_stage3_dash_chasm(w: float, fred: bool) -> void:
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	if c_gold.a <= 0.0: return
	var spd: float = 0.45 if fred else 1.15
	for ci: int in range(3):
		var u: float = fmod(_clock * spd + float(ci) / 3.0, 1.0)
		var cy: float = roundf(lerpf(POS_CHASM_TOP.y + 6.0, POS_CHASM_BOT.y - 4.0, u))
		_draw_down_chevron(Vector2(POS_CHASM_TOP.x, cy), c_cream if u > 0.65 else (c_gold if u > 0.28 else c_apr), c_gold)
	draw_rect(Rect2(POS_CHASM_BOT.x - 4.0, POS_CHASM_BOT.y + 2.0, 9.0, 1.0), LxPalette.fade_step(w, "mauve"))
	draw_rect(Rect2(POS_CHASM_BOT.x - 2.0, POS_CHASM_BOT.y + 2.0, 5.0, 1.0), c_gold)
	_draw_dash_keycap(Vector2(216.0, 252.0 + (0.0 if fred else roundf(sin(_clock * 3.4) * 1.0))).round(), w, fred)


func _draw_stage4_river_throw(wpos: Vector2, w: float, fred: bool) -> void:
	var brazier_pos: Vector2 = _interactable_pos("brazier_river_east", POS_BRAZIER_EAST)
	var lan: Dictionary = _lantern_status()
	var bob: float = 0.0 if fred else roundf(sin(_clock * 3.4) * 1.0)
	var mpos: Vector2 = (wpos + Vector2(0.0, -30.0 + bob)).round()
	if mpos.y > 304.0 and (absf(mpos.x - 970.0) < 16.0 or absf(mpos.x - 948.0) < 16.0):
		mpos.y = roundf(302.0 + bob)
	if bool(lan["out"]) and (lan["pos"] as Vector2).x >= 1004.0:
		var lpos: Vector2 = (lan["pos"] as Vector2) + Vector2(0.0, -4.0)
		var origin: Vector2 = wpos + Vector2(0.0, -6.0)
		var c_ice: Color = LxPalette.fade_step(w, "ice")
		var c_sky: Color = LxPalette.fade_step(w, "sky")
		var c_cream: Color = LxPalette.fade_step(w, "cream")
		if c_ice.a > 0.0:
			var spd_z: float = 0.55 if fred else 1.35
			for zi: int in range(4):
				var u: float = fmod(_clock * spd_z + float(zi) * 0.25, 1.0)
				_draw_right_chevron(origin.lerp(lpos, lerpf(0.16, 0.84, u)).round(), c_cream if u > 0.65 else c_ice, c_sky)
			draw_arc(lpos.round(), 10.0 + (0.0 if fred else roundf(sin(_clock * 5.0) * 1.5)), 0.0, TAU, 16, c_ice, 1.0, false)
		_draw_pixel_mouse(mpos, false, w, fred)
		return
	var c_gold: Color = LxPalette.fade_step(w, "gold")
	var c_cream: Color = LxPalette.fade_step(w, "cream")
	var c_apr: Color = LxPalette.fade_step(w, "apricot")
	var c_mist: Color = LxPalette.fade_step(w, "stone")
	var c_slate: Color = LxPalette.fade_step(w, "mauve")
	if c_gold.a <= 0.0: return
	var start_p := Vector2(clampf(wpos.x + 8.0, 948.0, POS_PIER_LIP.x), clampf(wpos.y - 6.0, 336.0, 380.0))
	var end_p: Vector2 = brazier_pos + Vector2(0.0, -14.0)
	var ctrl: Vector2 = start_p.lerp(end_p, 0.5) + Vector2(0.0, -20.0)
	var shift: float = 0.0 if fred else fmod(_clock * 0.55, 1.0 / 11.0)
	for i: int in range(11):
		var u: float = clampf(float(i) / 11.0 + shift, 0.04, 0.96)
		var pt: Vector2 = _quad_bezier(start_p, ctrl, end_p, u).round()
		var sz: Vector2 = Vector2(2.0, 1.0) if u > 0.55 else Vector2.ONE
		draw_rect(Rect2(pt + Vector2(0.0, 1.0), sz), PAL["void"] as Color)
		draw_rect(Rect2(pt, sz), c_cream if u > 0.78 else (c_gold if i % 2 == 0 else c_apr))
	var bc: Vector2 = brazier_pos.round()
	# Cool cold-slate/mist smoke wisp rising from dark unlit coals (unmistakably unlit!)
	var wisp_spd: float = 0.25 if fred else 0.52
	for wi: int in range(3):
		var wu: float = fmod(_clock * wisp_spd + float(wi) / 3.0, 1.0)
		var wx: float = roundf(sin(_clock * (1.2 if fred else 2.2) + float(wi) * 2.1) * (1.2 + wu * 1.6))
		var wy: float = roundf(-9.0 - wu * 10.0)
		var wc: Color = c_slate if wu < 0.45 else (c_mist if wu < 0.80 else (PAL["dusk"] as Color))
		draw_rect(Rect2(bc + Vector2(wx, wy), Vector2(2.0, 1.0) if wu < 0.55 else Vector2.ONE), wc)
	# Small pulsing golden target diamond + downward chevron floating cleanly ABOVE the dark basin
	var tbob: float = 0.0 if fred else roundf(sin(_clock * 4.2) * 1.5)
	var dc: Vector2 = bc + Vector2(0.0, -29.0 + tbob)
	var hot_d: bool = fred or sin(_clock * 4.2) > 0.1
	draw_rect(Rect2(dc + Vector2(0.0, -3.0), Vector2(1.0, 7.0)), PAL["void"] as Color)
	draw_rect(Rect2(dc + Vector2(-3.0, 0.0), Vector2(7.0, 1.0)), PAL["void"] as Color)
	draw_rect(Rect2(dc + Vector2(-1.0, -1.0), Vector2(3.0, 3.0)), c_gold)
	draw_rect(Rect2(dc + Vector2(0.0, -2.0), Vector2(1.0, 5.0)), c_cream if hot_d else c_gold)
	draw_rect(Rect2(dc + Vector2(-2.0, 0.0), Vector2(5.0, 1.0)), c_cream if hot_d else c_gold)
	_draw_down_chevron(bc + Vector2(0.0, -20.0 + tbob), c_cream if hot_d else c_gold, c_apr)
	_draw_pixel_mouse(mpos, true, w, fred)


func _draw_pixel_mouse(center: Vector2, right_btn: bool, w: float, fred: bool) -> void:
	if Lx.input != null and Lx.input.last_device == "gamepad":
		_draw_gamepad_glyph(center, "lx_throw" if right_btn else "lx_fire", w, fred)
		return
	var flash_on: bool = fred or fmod(_clock, 0.76) < 0.42
	var c_hi: Color = LxPalette.fade_step(w, "cream" if flash_on else "gold")
	var c_rim: Color = LxPalette.fade_step(w, "gold" if flash_on else "apricot")
	if c_hi.a <= 0.0: return
	var tl: Vector2 = (center - Vector2(4.0, 5.0)).round()
	var cv: Color = PAL["void"] as Color
	var cs: Color = PAL["stone"] as Color
	var cm: Color = PAL["mauve"] as Color
	var cn: Color = PAL["night"] as Color
	for r: Rect2 in [Rect2(0.0, -2.0, 9.0, 15.0), Rect2(-1.0, -1.0, 11.0, 13.0), Rect2(-2.0, 0.0, 13.0, 11.0)]:
		draw_rect(Rect2(tl + r.position, r.size), cv)
	for r2: Rect2 in [Rect2(1.0, 0.0, 7.0, 11.0), Rect2(0.0, 1.0, 9.0, 9.0)]:
		draw_rect(Rect2(tl + r2.position, r2.size), cs)
	draw_rect(Rect2(tl + Vector2(1.0, 1.0), Vector2(7.0, 9.0)), PAL["dusk"] as Color)
	draw_rect(Rect2(tl + Vector2(2.0, 8.0), Vector2(5.0, 1.0)), cm)
	draw_rect(Rect2(tl + Vector2(1.0, 5.0), Vector2(7.0, 1.0)), cn)
	draw_rect(Rect2(tl + Vector2(4.0, 1.0), Vector2(1.0, 4.0)), cn)
	draw_rect(Rect2(tl + Vector2(4.0, 2.0), Vector2(1.0, 2.0)), cs)
	draw_rect(Rect2(tl + Vector2(1.0, 1.0), Vector2(3.0, 4.0)), cm if right_btn else c_hi)
	draw_rect(Rect2(tl + Vector2(5.0, 1.0), Vector2(3.0, 4.0)), c_hi if right_btn else cm)
	draw_rect(Rect2(tl + Vector2(5.0 if right_btn else 1.0, 4.0), Vector2(3.0, 1.0)), c_rim)
	if flash_on and not fred:
		draw_rect(Rect2(tl + Vector2(10.0 if right_btn else -2.0, 0.0), Vector2.ONE), c_hi)
		draw_rect(Rect2(tl + Vector2(9.0 if right_btn else -1.0, -2.0), Vector2.ONE), c_rim)

func _draw_gamepad_glyph(center: Vector2, action_id: String, w: float, fred: bool) -> void:
	var pulse: bool = fred or fmod(_clock, 0.76) < 0.42
	var glyph: String = LxStrings.sanitize(Lx.input.get_glyph(action_id), 6) if Lx.input != null else ""
	var c_txt: Color = LxPalette.fade_step(w, "cream" if pulse else "gold")
	if c_txt.a <= 0.0: return
	var bw: float = maxf(15.0, (float(LxPixelFont.width(glyph, 1)) if not glyph.is_empty() else 7.0) + 8.0)
	var rect := Rect2(roundf(center.x - bw * 0.5), roundf(center.y - 5.5), bw, 11.0)
	draw_rect(Rect2(rect.position + Vector2(2.0, -1.0), Vector2(bw - 4.0, 1.0)), PAL["void"] as Color)
	LxPixelFont.draw_panel(self, rect, "dusk", "cream" if pulse else "gold", "void")
	draw_rect(Rect2(rect.position + Vector2(2.0, 1.0), Vector2(bw - 4.0, 1.0)), LxPalette.fade_step(w, "gold" if pulse else "apricot"))
	if not glyph.is_empty(): LxPixelFont.draw_centered(self, glyph, rect.position.x + bw * 0.5, rect.position.y + 3.0, c_txt, 1)
	else: draw_rect(Rect2(center - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_txt)

func _draw_dash_keycap(center: Vector2, w: float, fred: bool) -> void:
	var pulse: bool = fred or fmod(_clock, 0.8) < 0.44
	var glyph: String = LxStrings.sanitize(Lx.input.get_glyph("lx_dash"), 6) if Lx.input != null else ""
	var bw: float = maxf(15.0, (float(LxPixelFont.width(glyph, 1)) if not glyph.is_empty() else 7.0) + 8.0)
	var rect := Rect2(roundf(center.x - bw * 0.5), roundf(center.y - 5.5), bw, 11.0)
	LxPixelFont.draw_panel(self, rect, "night", "cream" if pulse else "gold", "void")
	var col: Color = LxPalette.fade_step(w, "cream" if pulse else "gold")
	if not glyph.is_empty(): LxPixelFont.draw_centered(self, glyph, rect.position.x + bw * 0.5, rect.position.y + 3.0, col, 1)
	else:
		var c := Vector2(roundf(rect.position.x + bw * 0.5), roundf(rect.position.y + 5.0))
		for r: Rect2 in [Rect2(0.0, -2.0, 1.0, 5.0), Rect2(-2.0, 0.0, 5.0, 1.0), Rect2(-1.0, -1.0, 3.0, 1.0)]: draw_rect(Rect2(c + r.position, r.size), col)

func _draw_down_chevron(tip: Vector2, c_hi: Color, c_mid: Color) -> void:
	var p: Vector2 = tip.round()
	var cv: Color = PAL["void"] as Color
	for r: Rect2 in [Rect2(-4.0, -4.0, 3.0, 2.0), Rect2(2.0, -4.0, 3.0, 2.0), Rect2(-2.0, -2.0, 5.0, 3.0), Rect2(-1.0, 0.0, 3.0, 2.0)]: draw_rect(Rect2(p + r.position, r.size), cv)
	for rm: Rect2 in [Rect2(-3.0, -3.0, 2.0, 1.0), Rect2(2.0, -3.0, 2.0, 1.0)]: draw_rect(Rect2(p + rm.position, rm.size), c_mid)
	for rh: Rect2 in [Rect2(-2.0, -2.0, 2.0, 1.0), Rect2(1.0, -2.0, 2.0, 1.0), Rect2(-1.0, -1.0, 3.0, 1.0), Rect2(0.0, 0.0, 1.0, 1.0)]: draw_rect(Rect2(p + rh.position, rh.size), c_hi)

func _draw_right_chevron(tip: Vector2, c_hi: Color, c_mid: Color) -> void:
	var p: Vector2 = tip.round()
	for rm: Rect2 in [Rect2(-3.0, -3.0, 1.0, 2.0), Rect2(-3.0, 2.0, 1.0, 2.0)]: draw_rect(Rect2(p + rm.position, rm.size), c_mid)
	for rh: Rect2 in [Rect2(-2.0, -2.0, 1.0, 2.0), Rect2(-2.0, 1.0, 1.0, 2.0), Rect2(-1.0, -1.0, 1.0, 3.0), Rect2(0.0, 0.0, 1.0, 1.0)]: draw_rect(Rect2(p + rh.position, rh.size), c_hi)

func _draw_target_brackets(center: Vector2, r: float, col: Color) -> void:
	var cv: Color = PAL["void"] as Color
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var cx: float = center.x + sx * r; var cy: float = center.y + sy * r
			var hx: float = cx if sx < 0.0 else cx - 2.0; var vy: float = cy if sy < 0.0 else cy - 2.0
			draw_rect(Rect2(hx - 1.0, cy - 1.0, 5.0, 3.0), cv); draw_rect(Rect2(cx - 1.0, vy - 1.0, 3.0, 5.0), cv)
			draw_rect(Rect2(hx, cy, 3.0, 1.0), col); draw_rect(Rect2(cx, vy, 1.0, 3.0), col)

func _draw_pixel_ellipse(center: Vector2, rx: float, ry: float, segs: int, col: Color) -> void:
	for i: int in range(segs):
		var a: float = float(i) * TAU / float(segs)
		draw_rect(Rect2(Vector2(roundf(center.x + cos(a) * rx), roundf(center.y + sin(a) * ry)), Vector2.ONE), col)

static func _quad_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inv: float = 1.0 - t
	return a * (inv * inv) + b * (2.0 * inv * t) + c * (t * t)

static func _sample_polyline(pts: Array[Vector2], t: float) -> Vector2:
	if pts.size() <= 1: return pts[0] if not pts.is_empty() else Vector2.ZERO
	var total: float = 0.0; var lens: Array[float] = []
	for i: int in range(pts.size() - 1):
		var d: float = pts[i].distance_to(pts[i + 1])
		lens.append(d); total += d
	var target_d: float = clampf(t, 0.0, 1.0) * maxf(0.001, total); var acc: float = 0.0
	for i: int in range(lens.size()):
		if acc + lens[i] >= target_d or i == lens.size() - 1:
			return pts[i].lerp(pts[i + 1], clampf((target_d - acc) / maxf(0.001, lens[i]), 0.0, 1.0))
		acc += lens[i]
	return pts[pts.size() - 1]

func _has_lantern() -> bool:
	if Lx.state == null: return true
	if Lx.state.has_method("has_lantern"): return bool(Lx.state.call("has_lantern"))
	if bool(Lx.state.story_flags.get("lantern_picked_up", false)): return true
	if Lx.world != null and Lx.world.has_method("find_interactable"): return Lx.world.call("find_interactable", "lantern_pickup_1") == null
	return true

func _player_pos() -> Vector2:
	return (Lx.player as Node2D).global_position if (Lx.player is Node2D and is_instance_valid(Lx.player)) else Vector2(708.0, 366.0)

func _player_is_dashing() -> bool:
	return Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("is_dashing") and bool(Lx.player.call("is_dashing"))

func _lantern_status() -> Dictionary:
	if Lx.player == null or not is_instance_valid(Lx.player): return {"out": false, "pos": Vector2.ZERO}
	var lv: Variant = Lx.player.get("lantern")
	if not (lv is Object) or not is_instance_valid(lv): return {"out": false, "pos": Vector2.ZERO}
	var lan: Object = lv as Object
	return {"out": lan.has_method("is_lure_active") and bool(lan.call("is_lure_active")), "pos": lan.get("pos") as Vector2 if lan.get("pos") is Vector2 else Vector2.ZERO}

func _find_warden() -> LxEnemyBrain:
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_enemies"): return null
	var arr: Variant = Lx.world.call("get_enemies")
	if arr is Array:
		for e: Variant in (arr as Array):
			if e is LxEnemyBrain and is_instance_valid(e) and (e as LxEnemyBrain).enemy_id == "warden_plaza_0": return e as LxEnemyBrain
	return null

func _interactable_pos(id: String, fallback: Vector2) -> Vector2:
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("find_interactable"):
		var it: Variant = Lx.world.call("find_interactable", id)
		if it is LxInteractable and is_instance_valid(it): return (it as LxInteractable).pos
	return fallback

func _is_inter_bool(id: String, prop: String) -> bool:
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("find_interactable"):
		var it: Variant = Lx.world.call("find_interactable", id)
		if it is LxInteractable and is_instance_valid(it): return bool((it as Object).get(prop))
	return false

func _is_beacon_lit(bid: String) -> bool:
	return (Lx.state != null and (Lx.state.lit_beacons.has(bid) or bool(Lx.state.story_flags.get(bid, false)))) or _is_inter_bool(bid, "lit")

func _is_river_resolved() -> bool:
	if _river_crossed: return true
	if Lx.state != null and (bool(Lx.state.story_flags.get("river_bridge_raised", false)) or _is_beacon_lit("beacon_bridge")): return true
	return _is_inter_bool("brazier_river_east", "lit") or _is_inter_bool("door_river_bridge", "opened")
