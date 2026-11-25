extends RefCounted
## Dual-Island Arena Rules, Comeback Beat & Phase Checkpoint Engine for LxTheHushBoss.
## Each phase transforms sanctum_r6 with two islands' mechanics:
##   P1 (1+2): Rings & Tides — Resonance Bells (freeze silence bolts / crack ward) + Tidal Surge Bands
##   P2 (3+4): Growth & The Loop — Snuffed Braziers + Briar Growth Fissures + 6 s Echo-Loop Ghost
##   P3 (5+6): Gravity & Moving Floor — Orbiting LxFields Gravity Well + Reversible Kiln Conveyor Bands
##   P4 (7+8): Mirrors & What Was Sold — Silver/Rose Mirror Silhouette + Closing Dark Band + Toll Sparks
## Plus: One-per-attempt 8-Island Comeback Beat ("EVERY LAMP ON EVERY ISLAND ANSWERS") &
##       Phase Checkpoints on retry (restart at highest reached phase after retry_from_death).

const CP_FLAG: String = "the_hush_phase_cp"
const PHASE_START_FRACS: Dictionary = {1: 1.0, 2: 0.75, 3: 0.50, 4: 0.25}


class HushGravityWell:
	extends RefCounted
	var pos: Vector2 = Vector2.ZERO
	var field_radius: float = 112.0
	var strength: float = 340.0
	var active: bool = false

	func is_field_active() -> bool:
		return active

	func field_accel(p: Vector2, what: String) -> Vector2:
		if not active:
			return Vector2.ZERO
		var delta: Vector2 = pos - p
		var d2: float = delta.length_squared()
		if d2 >= field_radius * field_radius or d2 <= 25.0:
			return Vector2.ZERO
		var dist: float = sqrt(d2)
		var u: float = clampf(1.0 - dist / field_radius, 0.0, 1.0)
		var mult: float = 0.14 if what == "wick" else 1.0
		return (delta / dist) * (strength * mult * (0.35 + 0.65 * u))


var boss: LxBossBase = null

# P1: Rings & Tides
var tide_level: float = 0.0
var tide_high: bool = false
var tide_clock: float = 0.0
var bell_resonance_t: float = 0.0
var _p1_flooded_tiles: Array[Vector2i] = []

# P2: Growth & The Loop
var echo_ghost_pos: Vector2 = Vector2.ZERO
var echo_ghost_active: bool = false
var echo_flash_t: float = 0.0
var briar_nodes: Array[Vector2] = []
var _snuffed_braziers: Array[Object] = []

# P3: Gravity & Moving Floor
var grav_well: HushGravityWell = null
var grav_registered: bool = false
var conveyor_dir: float = 1.0
var conveyor_scroll: float = 0.0
var conveyor_rects: Array[Rect2] = []

# P4: Mirrors & What Was Sold
var mirror_active: bool = false
var mirror_pos: Vector2 = Vector2.ZERO
var mirror_shatter_t: float = 0.0
var mirror_respawn_cd: float = 0.0
var mirror_fault_active: bool = false

# Comeback Beat ("The Eight Lamps Answer")
var comeback_used: bool = false
var comeback_surge_t: float = 0.0
var comeback_burst_t: float = 0.0


func _init(p_boss: LxBossBase = null) -> void:
	boss = p_boss


func cleanup() -> void:
	_unregister_gravity()
	_restore_braziers()
	_p1_flooded_tiles.clear()
	briar_nodes.clear()
	conveyor_rects.clear()
	tide_level = 0.0
	tide_high = false
	tide_clock = 0.0
	bell_resonance_t = 0.0
	echo_ghost_active = false
	echo_flash_t = 0.0
	conveyor_dir = 1.0
	conveyor_scroll = 0.0
	mirror_active = false
	mirror_shatter_t = 0.0
	mirror_respawn_cd = 0.0
	mirror_fault_active = false
	comeback_used = false
	comeback_surge_t = 0.0
	comeback_burst_t = 0.0


func apply_phase_arena(ph: int, on_bell_ring: Callable) -> void:
	if boss == null:
		return
	var ar: Rect2 = boss.arena_rect
	var c: Vector2 = ar.get_center()
	# Clear prior phase dynamic systems cleanly before staging the new pair of islands
	_unregister_gravity()
	conveyor_rects.clear()
	briar_nodes.clear()
	echo_ghost_active = false
	mirror_active = false
	mirror_fault_active = false

	if ph == 1:
		# Island 1 (Rings) + Island 2 (Tides): twin non-solid Resonance Bells + tidal rims
		tide_clock = 0.0
		tide_high = false
		_spawn_resonance_bells(ar, on_bell_ring)
	elif ph == 2:
		# Island 3 (Growth) + Island 4 (The Loop): snuff 2 braziers, bramble spurs, briar pods & 6s echo ghost
		boss.props.clear()
		_snuff_braziers(2)
		_carve_safe_tile(c + Vector2(-44.0, -20.0), "bramble")
		_carve_safe_tile(c + Vector2(44.0, 20.0), "bramble")
		briar_nodes = [
			_safe_pt(c + Vector2(-38.0, 16.0)),
			_safe_pt(c + Vector2(38.0, -16.0)),
		]
		echo_ghost_active = true
		echo_ghost_pos = boss.call("_get_wick_pos") as Vector2
	elif ph == 3:
		# Island 5 (Gravity) + Island 6 (Moving Floor): live LxFields Gravity Well + opposing conveyor belts
		boss.props.clear()
		boss.stage.revert_tiles(boss.world_ctx)
		_restore_braziers()
		_ensure_gravity(c)
		conveyor_dir = 1.0
		var bw: float = minf(84.0, ar.size.x * 0.72)
		conveyor_rects = [
			Rect2(c.x - bw * 0.5, c.y - 22.0, bw, 14.0),
			Rect2(c.x - bw * 0.5, c.y + 8.0, bw, 14.0),
		]
		_carve_safe_tile(c + Vector2(-46.0, 0.0), "cracked")
		_carve_safe_tile(c + Vector2(46.0, 0.0), "cracked")
	elif ph == 4:
		# Island 7 (Mirrors) + Island 8 (What Was Sold): Silver/Rose Mirror Split + Mirror Twin + Closing Dark
		boss.props.clear()
		boss.stage.revert_tiles(boss.world_ctx)
		_carve_safe_tile(c + Vector2(-44.0, 20.0), "mirror")
		_carve_safe_tile(c + Vector2(44.0, -20.0), "mirror")
		mirror_fault_active = true
		mirror_active = true
		mirror_respawn_cd = 0.0
		mirror_pos = _safe_pt(c + (c - boss.pos).limit_length(42.0))


func tick(dt: float, target: Vector2, on_mirror_shatter: Callable) -> void:
	if boss == null or boss.boss_state == LxBossBase.BossState.DEATH:
		return
	bell_resonance_t = maxf(0.0, bell_resonance_t - dt)
	echo_flash_t = maxf(0.0, echo_flash_t - dt)
	mirror_shatter_t = maxf(0.0, mirror_shatter_t - dt)
	comeback_surge_t = maxf(0.0, comeback_surge_t - dt)
	comeback_burst_t = maxf(0.0, comeback_burst_t - dt)

	# Comeback Beat check: once per attempt if Wick drops to <= 2.0 hearts (or enters P4 at <= 50% HP)
	_check_comeback_beat()

	var ph: int = boss.phase
	if ph == 1:
		tide_clock += dt
		tide_level = 0.5 + 0.5 * sin(tide_clock * 0.85)
		tide_high = tide_level > 0.65
	elif ph == 2:
		boss.duel.tick_echo_recorder(dt)
		var snap: Dictionary = boss.duel.get_echo_snapshot(2.4)
		if not snap.is_empty() and snap.get("pos") is Vector2:
			echo_ghost_pos = boss.clamp_to_arena(snap["pos"] as Vector2)
		else:
			echo_ghost_pos = boss.clamp_to_arena(target.lerp(boss.home, 0.35))
		_tick_briar_burn()
	elif ph == 3:
		if grav_well != null and grav_registered:
			var orbit_r: float = 34.0
			grav_well.pos = boss.arena_rect.get_center() + Vector2.from_angle(boss.anim_t * 0.95) * orbit_r
			grav_well.active = boss.boss_state != LxBossBase.BossState.PHASE_SHIFT
		var vis_m: float = 0.5 if boss.is_flash_reduced() else 1.0
		conveyor_scroll = fposmod(conveyor_scroll + 26.0 * vis_m * dt, 8.0)
		_tick_moving_floor(dt)
	elif ph == 4:
		if mirror_active:
			var c: Vector2 = boss.arena_rect.get_center()
			mirror_pos = _safe_pt(c + (c - boss.pos).limit_length(56.0))
			_tick_mirror_shatter(on_mirror_shatter)
		elif mirror_respawn_cd > 0.0:
			mirror_respawn_cd -= dt
			if mirror_respawn_cd <= 0.0 and boss.boss_state == LxBossBase.BossState.READY:
				mirror_active = true
				mirror_pos = _safe_pt(boss.arena_rect.get_center() + (boss.arena_rect.get_center() - boss.pos).limit_length(56.0))


func flip_conveyors() -> void:
	conveyor_dir = -conveyor_dir
	if boss != null:
		boss.stage.play_sfx("clockwork_chime", boss.pos)


func trigger_bell_resonance(bell_pos: Vector2) -> void:
	bell_resonance_t = 3.2
	if boss == null:
		return
	boss.patterns.freeze_bolts_in_radius(bell_pos, 165.0, 1.8, "bell")
	boss.stage.light_burst(bell_pos, 96.0, 1.4, 0.38)
	boss.stage.play_sfx("bell_toll_heavy", bell_pos)


func shatter_p4_mirror() -> void:
	if not mirror_active or boss == null:
		return
	mirror_active = false
	mirror_shatter_t = 0.70
	mirror_respawn_cd = 11.5
	LxDamageFx.boss_impact(mirror_pos, 0.22, 92.0, 96.0, 96.0, 1.48, 0.38, "ice")
	boss.stage.play_sfx("shield_shatter", mirror_pos)


func _check_comeback_beat() -> void:
	if comeback_used or boss == null or not boss.engaged:
		return
	if boss.boss_state in [LxBossBase.BossState.IDLE, LxBossBase.BossState.INTRO, LxBossBase.BossState.DEATH]:
		return
	if Lx.state == null or not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.dead:
		return
	var low_hp: bool = Lx.state.hearts <= 3.0 and Lx.state.hearts > 0.01
	var p4_wounded: bool = boss.phase >= 4 and Lx.state.hearts <= float(Lx.state.max_hearts) * 0.50 and Lx.state.hearts > 0.01
	if not low_hp and not p4_wounded:
		return
	comeback_used = true
	comeback_surge_t = 7.5
	comeback_burst_t = 0.85
	Lx.state.hearts = minf(float(Lx.state.max_hearts), Lx.state.hearts + 3.0)
	w.ember = 100.0
	boss.patterns.clear_bolts_in_radius(w.global_position, 140.0)
	boss.stage.light_burst(w.global_position, 136.0, 1.65, 0.55)
	boss.stage.shake(0.20)
	boss.stage.play_sfx("great_lamp_bloom", w.global_position)
	if Lx.events != null and LxStrings.has_id("ISL8_BRIDGE"):
		Lx.events.narration_requested.emit("ISL8_BRIDGE", "title", 3.2)


func _spawn_resonance_bells(ar: Rect2, on_bell_ring: Callable) -> void:
	boss.props.clear()
	var c: Vector2 = ar.get_center()
	var w_p: Vector2 = _safe_pt(Vector2(c.x - minf(62.0, ar.size.x * 0.34), c.y))
	var e_p: Vector2 = _safe_pt(Vector2(c.x + minf(62.0, ar.size.x * 0.34), c.y))
	var bw: Dictionary = boss.props.spawn_bell(w_p, func(p: Dictionary) -> void:
		trigger_bell_resonance(p["pos"] as Vector2)
		if on_bell_ring.is_valid(): on_bell_ring.call("dawn", p["pos"] as Vector2), "hush_bell_dawn")
	bw["solid"] = false
	bw["color"] = "gold"
	var be: Dictionary = boss.props.spawn_bell(e_p, func(p: Dictionary) -> void:
		trigger_bell_resonance(p["pos"] as Vector2)
		if on_bell_ring.is_valid(): on_bell_ring.call("dusk", p["pos"] as Vector2), "hush_bell_dusk")
	be["solid"] = false
	be["color"] = "ice"


func _tick_briar_burn() -> void:
	if briar_nodes.is_empty() or not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	var beam_on: bool = w.move_beam != null and w.move_beam.beam_vis_t > 0.0
	var lan_out: bool = w.lantern != null and w.lantern.is_out()
	for i: int in range(briar_nodes.size() - 1, -1, -1):
		var bp: Vector2 = briar_nodes[i]
		var burned: bool = false
		if beam_on and Geometry2D.get_closest_point_to_segment(bp, w.move_beam.beam_start, w.move_beam.beam_end).distance_to(bp) <= 16.0:
			burned = true
		elif lan_out and w.lantern.pos.distance_to(bp) <= 18.0:
			burned = true
		if burned:
			briar_nodes.remove_at(i)
			boss.stage.play_sfx("bramble_burn", bp)
			boss.stage.light_burst(bp, 64.0, 1.3, 0.30)
			boss.add_stagger(boss.stagger_threshold * 0.45)


func _tick_moving_floor(dt: float) -> void:
	if conveyor_rects.is_empty() or not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.dead or w.is_dashing() or w.is_gliding() or w.is_zipping() or w.is_launched():
		return
	var wp: Vector2 = w.global_position
	var ctx: Node = boss.world_ctx
	for idx: int in range(conveyor_rects.size()):
		var r: Rect2 = conveyor_rects[idx]
		if r.has_point(wp) and boss.arena_rect.grow(-8.0).has_point(wp):
			var sgn: float = conveyor_dir if (idx % 2 == 0) else -conveyor_dir
			var push_v := Vector2(sgn * 22.0, 0.0)
			# Never push Wick near a wall or lethal pit/void!
			var probe: Vector2 = wp + push_v.normalized() * 48.0
			var safe: bool = true
			if ctx != null and is_instance_valid(ctx):
				if ctx.has_method("is_lethal_void_at") and bool(ctx.call("is_lethal_void_at", probe)):
					safe = false
				elif ctx.has_method("tile_at") and not (str(ctx.call("tile_at", probe)) in ["ground", "path", "bridge"]):
					safe = false
			if safe:
				w.push_external(push_v, "hush_conveyor")
			break
	var _unused_dt: float = dt


func _tick_mirror_shatter(on_shatter: Callable) -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.move_beam != null and w.move_beam.beam_vis_t > 0.0:
		if Geometry2D.get_closest_point_to_segment(mirror_pos, w.move_beam.beam_start, w.move_beam.beam_end).distance_to(mirror_pos) <= 16.0:
			shatter_p4_mirror()
			if on_shatter.is_valid(): on_shatter.call()
			return
	for bi: int in range(w.bolts.size() - 1, -1, -1):
		var bv: Variant = w.bolts[bi]
		if bv is Object and (bv.get("pos") as Vector2).distance_to(mirror_pos) <= 14.0:
			var is_b: bool = str(bv.get("color")) == LxHit.COLOR_BLUE
			w.bolts.remove_at(bi)
			if is_b:
				shatter_p4_mirror()
				if on_shatter.is_valid(): on_shatter.call()
				return
			boss.stage.play_sfx("mirror_ping", mirror_pos)
			return


func _ensure_gravity(center_p: Vector2) -> void:
	if grav_well == null:
		grav_well = HushGravityWell.new()
	grav_well.pos = center_p
	grav_well.active = true
	if not grav_registered:
		LxFields.add(grav_well)
		grav_registered = true


func _unregister_gravity() -> void:
	if grav_registered and grav_well != null:
		grav_well.active = false
		LxFields.remove(grav_well)
		grav_registered = false


func _snuff_braziers(max_n: int) -> void:
	var ctx: Node = boss.world_ctx
	if ctx == null or not is_instance_valid(ctx) or not ctx.has_method("get_interactables"):
		return
	var count: int = 0
	for it_v: Variant in (ctx.call("get_interactables") as Array):
		if it_v is Object and str((it_v as Object).get("kind")) == "brazier" and bool((it_v as Object).get("lit")):
			(it_v as Object).set("lit", false)
			if it_v is CanvasItem: (it_v as CanvasItem).queue_redraw()
			_snuffed_braziers.append(it_v as Object)
			count += 1
			if count >= max_n: break


func _restore_braziers() -> void:
	for b_obj: Object in _snuffed_braziers:
		if b_obj != null and is_instance_valid(b_obj):
			b_obj.set("lit", true)
			if b_obj is CanvasItem: (b_obj as CanvasItem).queue_redraw()
	_snuffed_braziers.clear()


func _carve_safe_tile(world_pt: Vector2, tile_name: String) -> void:
	var ctx: Node = boss.world_ctx
	if ctx == null or not is_instance_valid(ctx) or not ctx.has_method("tile_at"):
		return
	var p: Vector2 = boss.clamp_to_arena(world_pt)
	var tx: int = int(floorf(p.x / 16.0))
	var ty: int = int(floorf(p.y / 16.0))
	var cp := Vector2((float(tx) + 0.5) * 16.0, (float(ty) + 0.5) * 16.0)
	var wp: Vector2 = boss.call("_get_wick_pos") as Vector2
	if str(ctx.call("tile_at", cp)) == "ground" and cp.distance_to(boss.home) > 42.0 and cp.distance_to(wp) > 28.0:
		boss.stage.set_tiles(ctx, Rect2i(tx, ty, 1, 1), tile_name)


func _safe_pt(pt: Vector2) -> Vector2:
	var p: Vector2 = boss.clamp_to_arena(pt)
	var ctx: Node = boss.world_ctx
	if ctx == null or not is_instance_valid(ctx) or not ctx.has_method("tile_at"):
		return p
	if str(ctx.call("tile_at", p)) in ["ground", "path", "bridge"]:
		return p
	for r_s: float in [16.0, 32.0, 48.0]:
		for k: int in range(8):
			var cand: Vector2 = boss.clamp_to_arena(p + Vector2.from_angle(float(k) * (TAU / 8.0)) * r_s)
			if str(ctx.call("tile_at", cand)) in ["ground", "path", "bridge"]:
				return cand
	return boss.home


# --- Phase Checkpoints on Retry (P2, P3, P4) ---------------------------------

static func save_checkpoint(ph: int) -> void:
	var best: int = maxi(clampi(ph, 1, 4), read_checkpoint())
	if Lx.state != null:
		Lx.state.story_flags[CP_FLAG] = best
	if Lx.vars != null:
		Lx.vars.set_var("island:8", CP_FLAG, best)


static func read_checkpoint() -> int:
	var cp: int = 1
	if Lx.state != null:
		cp = maxi(cp, int(Lx.state.story_flags.get(CP_FLAG, 1)))
	if Lx.vars != null:
		cp = maxi(cp, int(Lx.vars.get_var("island:8", CP_FLAG, 1)))
	return clampi(cp, 1, 4)


static func clear_checkpoint() -> void:
	if Lx.state != null:
		Lx.state.story_flags.erase(CP_FLAG)
	if Lx.vars != null:
		Lx.vars.set_var("island:8", CP_FLAG, 1)


static func phase_start_hp(max_hp_val: float, ph: int) -> float:
	return max_hp_val * float(PHASE_START_FRACS.get(clampi(ph, 1, 4), 1.0))
