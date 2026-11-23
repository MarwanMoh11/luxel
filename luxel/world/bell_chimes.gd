class_name LxBellChimes
extends Node2D
## Island 1 (Bell Isle) interactive Golden Belfry Wind-Chimes:
## Walk, dash, or toss Wick's lantern through hanging brass wind-chimes across Bell Isle
## to ring harmonic D-minor chimes, bloom warm light bursts, and shake loose bonus Light Shards.
## Strictly uses the 20 opaque Last Light palette colours (LxPalette.PAL).

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 196.0
const HALF_H: float = 124.0

static var active_instance: LxBellChimes = null

var _active: bool = false
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _chimes: Array[Dictionary] = [] # {pos, swing_t, cd, rung, phase}
var _rings: Array[Dictionary] = []  # {pos, age, dur}
var _hint_dir: Vector2 = Vector2.ZERO
var _hint_alpha: float = 0.0
var _hint_wick_pos: Vector2 = Vector2.ZERO
var _hint_pulse_cd: float = 1.2


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2
	active_instance = self


func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null


func configure(rules: LxBiomeRules, region_node: Node) -> void:
	active_instance = self
	_active = rules != null and rules.island_id == 1 and not rules.is_dungeon
	_clock = 0.0
	_cam_center = rules.bounds.get_center() if rules != null else Vector2.ZERO
	_chimes.clear()
	_rings.clear()
	_hint_dir = Vector2.ZERO
	_hint_alpha = 0.0
	_hint_pulse_cd = 1.2
	if not _active or region_node == null or not is_instance_valid(region_node):
		queue_redraw()
		return
	var candidates: Array[Vector2] = [
		Vector2(576.0, 396.0), # Sundial Plaza west garland
		Vector2(704.0, 396.0), # Sundial Plaza east terrace
		Vector2(304.0, 224.0), # Lantern Orchard path
		Vector2(264.0, 368.0), # Observatory terrace
		Vector2(640.0, 512.0), # Glasshouse approach
		Vector2(968.0, 352.0), # Moonlit Bridge entrance
	]
	for idx: int in range(candidates.size()):
		var pt: Vector2 = _snap_walkable(region_node, candidates[idx])
		if pt != Vector2.ZERO:
			var was_rung: bool = Lx.state != null and bool(Lx.state.story_flags.get("chime_1_%d" % idx, false))
			_chimes.append({
				"idx": idx,
				"pos": pt,
				"swing_t": 0.0,
				"cd": 0.0,
				"rung": was_rung,
				"phase": float(idx) * 1.15,
			})
	queue_redraw()


static func _snap_walkable(region_node: Node, pt: Vector2) -> Vector2:
	if not region_node.has_method("tile_at"):
		return pt
	for off: Vector2 in [Vector2.ZERO, Vector2(0.0, 16.0), Vector2(0.0, -16.0), Vector2(16.0, 0.0), Vector2(-16.0, 0.0)]:
		var c: Vector2 = (pt + off).round()
		if str(region_node.call("tile_at", c)) in ["ground", "path"]:
			return c
	return Vector2.ZERO


func get_rung_count() -> int:
	var n: int = 0
	for ch: Dictionary in _chimes:
		if bool(ch["rung"]):
			n += 1
	return n


func get_total_count() -> int:
	return _chimes.size()


func get_found_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for ch: Dictionary in _chimes:
		if bool(ch["rung"]):
			out.append(ch["pos"] as Vector2)
	return out


func try_hit_segment(from_p: Vector2, to_p: Vector2, w: LxWick) -> bool:
	if not _active:
		return false
	for ch: Dictionary in _chimes:
		if float(ch["cd"]) > 0.0:
			continue
		var cp: Vector2 = ch["pos"] as Vector2
		if Geometry2D.get_closest_point_to_segment(cp, from_p, to_p).distance_to(cp) <= 14.0:
			_ring_chime(ch, w)
			return true
	return false


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if not _active or dt <= 0.0:
		return
	_clock += dt
	for i: int in range(_rings.size() - 1, -1, -1):
		var rg: Dictionary = _rings[i]
		rg["age"] = float(rg["age"]) + dt
		if float(rg["age"]) >= float(rg["dur"]):
			_rings.remove_at(i)

	var w: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var wp: Vector2 = w.global_position if (w != null and not w.dead) else Vector2(-9999.0, -9999.0)
	var lp: Vector2 = Vector2(-9999.0, -9999.0)
	if w != null and w.lantern != null and is_instance_valid(w.lantern) and w.lantern.is_out():
		lp = w.lantern.pos

	var any_vis: bool = not _rings.is_empty()
	_hint_pulse_cd = maxf(0.0, _hint_pulse_cd - dt)
	var best_unrung_d: float = 120.0
	var best_unrung_p: Vector2 = Vector2.ZERO
	for ch: Dictionary in _chimes:
		ch["swing_t"] = maxf(0.0, float(ch["swing_t"]) - dt)
		ch["cd"] = maxf(0.0, float(ch["cd"]) - dt)
		var cp: Vector2 = ch["pos"] as Vector2
		if absf(cp.x - _cam_center.x) <= HALF_W and absf(cp.y - _cam_center.y) <= HALF_H:
			any_vis = true
		if not bool(ch["rung"]) and w != null and not w.dead:
			var ud: float = cp.distance_to(wp)
			if ud < best_unrung_d:
				best_unrung_d = ud
				best_unrung_p = cp
		if float(ch["cd"]) <= 0.0:
			var hit_w: bool = w != null and not w.dead and cp.distance_to(wp) <= (22.0 if w.is_dashing() else 16.0)
			var hit_l: bool = cp.distance_to(lp) <= 22.0
			if hit_w or hit_l:
				_ring_chime(ch, w)
	if best_unrung_d < 116.0 and best_unrung_d > 26.0 and w != null and not w.dead:
		_hint_wick_pos = wp
		_hint_dir = (best_unrung_p - wp).normalized()
		_hint_alpha = clampf(1.0 - (best_unrung_d - 26.0) / 90.0, 0.15, 0.85)
		any_vis = true
		if best_unrung_d <= 98.0 and _hint_pulse_cd <= 0.0:
			_hint_pulse_cd = 2.8
			_rings.append({"pos": best_unrung_p + Vector2(0.0, -10.0), "age": 0.0, "dur": 0.52})
	else:
		_hint_alpha = 0.0
	if any_vis:
		queue_redraw()


func _ring_chime(ch: Dictionary, w: LxWick) -> void:
	var cp: Vector2 = ch["pos"] as Vector2
	var first_ring: bool = not bool(ch["rung"])
	ch["rung"] = true
	ch["swing_t"] = 1.35
	ch["cd"] = 4.0
	_rings.append({"pos": cp + Vector2(0.0, -8.0), "age": 0.0, "dur": 0.42})
	if Lx.state != null and bool(Lx.state.story_flags.get("disc_all_1", false)):
		_rings.append({"pos": cp + Vector2(0.0, -8.0), "age": 0.0, "dur": 0.62})
	if Lx.audio != null:
		Lx.audio.play_sfx("prop_chime", cp, true)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(cp, 68.0, 0.78 if LxHudFx.flash_reduced() else 1.12, 0.44)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.BLOSSOM, cp, 12.0, 5.5)
	if first_ring:
		if Lx.state != null:
			Lx.state.story_flags["chime_1_%d" % int(ch.get("idx", 0))] = true
			Lx.state.add_shards(2)
		elif Lx.events != null:
			Lx.events.shard_collected.emit(2)
		if w != null and is_instance_valid(w):
			w.spawn_sparks(cp + Vector2(0.0, -8.0), Vector2.UP, 5, LxWick.PAL_GOLD, 20.0, 52.0, 0.28)
		if get_total_count() > 0 and get_rung_count() >= get_total_count() and Lx.state != null and not bool(Lx.state.story_flags.get("disc_all_1", false)):
			_celebrate_all_rung(cp, w)


func _celebrate_all_rung(cp: Vector2, w: LxWick) -> void:
	if Lx.state != null:
		Lx.state.story_flags["disc_all_1"] = true
		Lx.state.add_shards(10)
	for other: Dictionary in _chimes:
		other["swing_t"] = 2.0
		_rings.append({"pos": (other["pos"] as Vector2) + Vector2(0.0, -8.0), "age": 0.0, "dur": 0.65})
	if Lx.audio != null:
		Lx.audio.play_sfx("great_lamp_bloom", cp, true)
	if Lx.events != null:
		Lx.events.narration_requested.emit("CUE_HARMONY_1", "title", 3.4)
	if Lx.camera != null and is_instance_valid(Lx.camera):
		Lx.camera.add_shake(0.30)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(cp, 132.0, 0.85 if LxHudFx.flash_reduced() else 1.25, 0.72)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.PRISM_STAR, cp, 16.0, 8.0)
	if w != null and is_instance_valid(w):
		w.spawn_sparks(cp + Vector2(0.0, -8.0), Vector2.UP, 10, LxWick.PAL_GOLD, 28.0, 68.0, 0.42)


func _draw() -> void:
	if not _active:
		return
	var fred: bool = LxHudFx.flash_reduced()
	for ch: Dictionary in _chimes:
		var cp: Vector2 = (ch["pos"] as Vector2).round()
		if absf(cp.x - _cam_center.x) > HALF_W or absf(cp.y - _cam_center.y) > HALF_H:
			continue
		var sw_t: float = float(ch["swing_t"])
		var rung: bool = bool(ch["rung"])
		var ph: float = float(ch["phase"])
		var sway: float = 0.0 if fred else roundf(sin(_clock * (12.0 if sw_t > 0.0 else 2.2) + ph) * (2.5 if sw_t > 0.0 else 0.8))
		# Ground shadow + slender stone/brass bell-chime post
		draw_rect(Rect2(cp + Vector2(-4.0, 1.0), Vector2(8.0, 2.0)), Color(PAL["void"] as Color, 0.48))
		draw_rect(Rect2(cp + Vector2(-1.0, -13.0), Vector2(2.0, 14.0)), PAL["night"] as Color)
		draw_rect(Rect2(cp + Vector2(-1.0, -13.0), Vector2(1.0, 13.0)), PAL["mauve"] as Color)
		# Crossbar + 3 hanging brass chime pipes
		draw_rect(Rect2(cp + Vector2(-4.0, -14.0), Vector2(9.0, 2.0)), PAL["apricot"] as Color)
		draw_rect(Rect2(cp + Vector2(-3.0, -14.0), Vector2(7.0, 1.0)), PAL["gold"] as Color)
		var pipe_col: Color = (PAL["cream"] if sw_t > 0.35 else (PAL["gold"] if rung else PAL["apricot"])) as Color
		draw_rect(Rect2(cp + Vector2(-3.0 + sway, -12.0), Vector2(1.0, 5.0)), pipe_col)
		draw_rect(Rect2(cp + Vector2(0.0 + sway, -12.0), Vector2(1.0, 7.0)), PAL["cream"] if (sw_t > 0.0 or rung) else PAL["gold"])
		draw_rect(Rect2(cp + Vector2(3.0 + sway, -12.0), Vector2(1.0, 5.0)), pipe_col)
		# Subtle inviting glint above un-rung chimes; twinkling Harmony Crown once all chimes ring
		if not rung and (fred or fmod(_clock * 1.8 + ph, 1.4) < 0.55):
			draw_rect(Rect2(cp + Vector2(0.0, -16.0), Vector2.ONE), PAL["cream"] as Color)
		elif rung and Lx.state != null and bool(Lx.state.story_flags.get("disc_all_1", false)):
			var st_y: float = -17.0 + (0.0 if fred else roundf(sin(_clock * 2.4 + ph) * 1.0))
			draw_rect(Rect2(cp + Vector2(-1.0, st_y), Vector2(3.0, 1.0)), PAL["gold"] as Color)
			draw_rect(Rect2(cp + Vector2(0.0, st_y - 1.0), Vector2(1.0, 3.0)), PAL["gold"] as Color)
			draw_rect(Rect2(cp + Vector2(0.0, st_y), Vector2.ONE), PAL["cream"] as Color)
	if _hint_alpha > 0.01:
		var shimmer: float = 0.72 if fred else (0.55 + 0.45 * sin(_clock * 4.2))
		var gp: Vector2 = (_hint_wick_pos + Vector2(0.0, -5.0) + _hint_dir * 19.0).round()
		draw_rect(Rect2(gp + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(PAL["gold"] as Color, _hint_alpha * shimmer * 0.72))
		draw_rect(Rect2(gp + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(PAL["gold"] as Color, _hint_alpha * shimmer * 0.72))
		draw_rect(Rect2(gp, Vector2.ONE), Color(PAL["cream"] as Color, _hint_alpha * shimmer))
	for rg: Dictionary in _rings:
		var u: float = clampf(float(rg["age"]) / maxf(float(rg["dur"]), 0.01), 0.0, 1.0)
		var r: float = roundf(lerpf(4.0, 24.0, u))
		var a: float = (1.0 - u) * (0.55 if fred else 0.85)
		draw_arc((rg["pos"] as Vector2).round(), r, 0.0, TAU, 16, Color((PAL["cream"] if u < 0.35 else PAL["gold"]) as Color, a), 1.2)
