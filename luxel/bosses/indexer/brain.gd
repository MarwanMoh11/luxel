class_name LxIndexerBoss
extends LxBossBase
## Island 8 Mini-Boss: The Indexer (Archive of Lost Lamps, archive_r6).
## 5-segment mahogany card-catalogue centipede on brass casters (LxBossSegments).
## Front drawers resist frontal bolts (0.60x clank); glowing GOLDEN TAIL DRAWER takes
## 1.50x damage + bonus stagger (sneezing out alphabetized cream index cards!).
## P1 (100-50%): 5 linked drawers + Reject Stamp, Index Card Fan, Cross-Rail Rush.
## P2 (<=50%): Splits into 2 rail cars (3-drawer main + 2-drawer Split Car patrolling
## opposite track!) + 2 sliding shelf pillars + corner rail void cuts (auto-rollback!).

const SEG_COUNT_P1: int = 5
const SEG_COUNT_P2: int = 3
const SEG_SPACING: float = 14.0
const RUSH_SPEED: float = 205.0
const REJECT_SIZE: Vector2 = Vector2(36.0, 36.0)

var _rush_dir: Vector2 = Vector2.RIGHT
var _rush_hit: bool = false
var _split_active: bool = false
var _split_pos: Vector2 = Vector2.ZERO
var _split_tail: Vector2 = Vector2.ZERO
var _split_ang: float = 0.0
var _sneeze_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "indexer"
	boss_id = "indexer"
	boss_name_key = "ISL8_BOSS_INDEXER"
	island_id = 8
	is_miniboss = true
	reward_heart = "half"
	music_cue = "isl8_boss_minor_p1"
	music_p2_cue = "isl8_boss_minor_p2"
	max_hp = 122.0
	hp = 122.0
	body_radius = 12.0
	move_speed = 46.0
	stagger_threshold = 18.0
	stagger_duration = 1.75
	post_stagger_immunity = 3.8
	punish_dmg_mult = 1.38
	post_recover_cd = 0.28
	intro_duration = 0.58
	phase_shift_duration = 0.68
	death_duration = 2.3
	shard_drop = 28


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50])

	# Attack 1: Reject Stamp (tell 0.55s, commit 0.22s, recover 1.10s)
	register_attack("reject_stamp", {
		"weight": 1.25, "tell": 0.55, "commit": 0.22, "recover": 1.10, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var r1 := Rect2(clamp_to_arena(tgt) - REJECT_SIZE * 0.5, REJECT_SIZE)
			ground.warn_rect(r1, last_tell_duration, 1.0, "coral", "cream", 0.30)
			if phase >= 2:
				var off_p: Vector2 = clamp_to_arena(tgt.lerp(arena_rect.get_center(), 0.45))
				ground.warn_rect(Rect2(off_p - REJECT_SIZE * 0.5, REJECT_SIZE), last_tell_duration + 0.08, 1.0, "coral", "gold", 0.30)
			stage.play_sfx("drawer_clack", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 8 if phase >= 2 else 6, 126.0, aim_a + 0.55, 0.72, {"color": "coral", "source": "reject_stamp"})
			stage.shake(0.18)
			stage.play_sfx("bell_slam", pos),
	})

	# Attack 2: Index Card Fan (tell 0.50s, commit 0.28s, recover 1.05s)
	register_attack("index_card_fan", {
		"weight": 1.25, "tell": 0.50, "commit": 0.28, "recover": 1.05, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = aim.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + aim * 145.0), 12.0, last_tell_duration, 0.0, "cream", "coral")
			if _split_active:
				var saim: Vector2 = (tgt - _split_pos).normalized() if tgt.distance_to(_split_pos) > 1.0 else Vector2.LEFT
				ground.warn_lane(_split_pos, clamp_to_arena(_split_pos + saim * 130.0), 8.0, last_tell_duration, 0.0, "gold", "coral")
			stage.play_sfx("paper_snap", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			patterns.emit_fan(pos, aim, 7 if phase >= 2 else 5, 0.96, 146.0 if phase >= 2 else 132.0, {"color": "cream", "source": "index_card"})
			if _split_active:
				var saim: Vector2 = (tgt - _split_pos).normalized() if tgt.distance_to(_split_pos) > 1.0 else -aim
				patterns.emit_fan(_split_pos, saim, 3, 0.55, 134.0, {"color": "gold", "source": "split_card"})
			stage.shake(0.12)
			stage.play_sfx("paper_snap", pos),
	})

	# Attack 3: Cross-Rail Rush (tell 0.58s, commit 0.45s, recover 1.30s)
	register_attack("cross_rail_rush", {
		"weight": 1.20, "tell": 0.58, "commit": 0.45, "recover": 1.30, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_rush_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _rush_dir.angle()
			_rush_hit = false
			ground.warn_lane(pos, clamp_to_arena(pos + _rush_dir * (RUSH_SPEED * 0.48)), 13.0, last_tell_duration, 0.0, "coral", "gold")
			stage.play_sfx("drawer_clack", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			stage.shake(0.16)
			stage.play_sfx("drawer_clack", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, elapsed: float) -> void:
			var prev_p: Vector2 = pos
			move_boss(_rush_dir * RUSH_SPEED * dt, true)
			if pos.distance_to(prev_p) < RUSH_SPEED * dt * 0.35:
				_rush_dir = -_rush_dir
				facing = _rush_dir.angle()
			if not _rush_hit and check_contact_damage(19.0, _rush_dir, 1.0, "rail_rush"):
				_rush_hit = true
			if elapsed >= 0.22 and elapsed - dt < 0.22:
				var r_box := Rect2(clamp_to_arena(pos) - REJECT_SIZE * 0.45, REJECT_SIZE * 0.9)
				ground.warn_rect(r_box, 0.50, 1.0, "coral", "gold", 0.25),
	})


func _on_reset_encounter() -> void:
	_rush_hit = false
	_split_active = false
	_split_pos = home
	_split_tail = home
	_split_ang = 0.0
	_sneeze_t = 0.0
	_setup_drawers(SEG_COUNT_P1)


func _setup_drawers(count: int) -> void:
	segments.setup_follow_chain(count, SEG_SPACING, 7.0, 14.0, pos, facing)
	for i: int in range(segments.segments.size()):
		var s: Dictionary = segments.segments[i]
		var is_tail: bool = (i == segments.segments.size() - 1)
		s["color"] = "gold" if is_tail else "wine"
		s["glow"] = "cream" if is_tail else "apricot"
		s["lit"] = is_tail
		s["armoured"] = not is_tail


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		# P2 Split: main train shrinks to 3 drawers & 2-drawer Split Car patrols opposite rail!
		_setup_drawers(SEG_COUNT_P2)
		_split_active = true
		var c: Vector2 = arena_rect.get_center()
		_split_ang = PI
		_split_pos = clamp_to_arena(c + Vector2(64.0, -32.0))
		_split_tail = _split_pos + Vector2(14.0, 0.0)
		# Arena change: 2 mahogany shelf dividers + 2 small corner rail-void cuts
		props.spawn_pillar(c + Vector2(-56.0, 0.0), 16.0, "indexer_shelf_w")
		props.spawn_pillar(c + Vector2(56.0, 0.0), 16.0, "indexer_shelf_e")
		var cx_t: int = int(c.x / 16.0)
		var cy_t: int = int(c.y / 16.0)
		stage.set_tiles(world_ctx, Rect2i(maxi(2, cx_t - 6), maxi(2, cy_t - 3), 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(cx_t + 5, cy_t + 2, 1, 1), "pit")
		stage.darkness_pulse(0.60, 1.0)
		stage.shake(0.24)
		stage.play_sfx("drawer_clack", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_sneeze_t = maxf(0.0, _sneeze_t - dt)
	if _split_active:
		var c: Vector2 = arena_rect.get_center()
		_split_ang = wrapf(_split_ang + dt * 1.15, -PI, PI)
		var want: Vector2 = clamp_to_arena(c + Vector2(cos(_split_ang) * 76.0, sin(_split_ang) * 40.0))
		var prev: Vector2 = _split_pos
		_split_pos = _split_pos.lerp(want, minf(1.0, dt * 3.8))
		var dir: Vector2 = (_split_pos - prev).normalized() if _split_pos.distance_to(prev) > 0.1 else Vector2.LEFT
		_split_tail = _split_pos - dir * SEG_SPACING


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) < 0.92
	var bypass: bool = bool(h["pierce"]) or bool(h["cracks_armour"]) or src == LxHit.SOURCE_PRISM or src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_SUNFLARE or src == LxHit.SOURCE_BEAM

	# Check glowing tail drawer hit!
	var tail_hit: bool = false
	if not segments.segments.is_empty():
		var tail_p: Vector2 = segments.segments[segments.segments.size() - 1]["pos"] as Vector2
		if orig.distance_to(tail_p) <= 32.0 or absf(angle_difference(facing, rel.angle())) > 1.65:
			tail_hit = true
	if src == LxHit.SOURCE_SUNFLARE and _split_active:
		# Sunflare catches BOTH rail cars -> huge bonus + stagger!
		add_stagger(6.0)
		_sneeze_t = 0.95
		stage.play_sfx("paper_snap", pos)
		return dmg * 1.65
	if tail_hit or src == LxHit.SOURCE_PRISM or src == LxHit.SOURCE_THROW:
		_sneeze_t = 0.75
		add_stagger(1.8)
		stage.play_sfx("paper_snap", pos)
		return dmg * 1.45
	if from_front and not bypass and not is_punishable():
		clank_t = 0.10
		stage.play_sfx("drawer_clack", pos)
		return dmg * 0.65
	return dmg


func _on_death_start() -> void:
	_split_active = false
	stage.shake(0.24)
	stage.play_sfx("drawer_clack", pos)


func _body_color() -> Color:
	return (PAL["wine"] if phase == 1 else PAL["coral"]) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Highlight glowing golden tail drawer!
	if not segments.segments.is_empty() and boss_state != BossState.DEATH:
		var tp: Vector2 = ((segments.segments[segments.segments.size() - 1]["pos"] as Vector2) - pos).round()
		draw_arc(tp, 10.0, 0.0, TAU, 16, PAL["gold"] as Color, 1.8)
		draw_circle(tp, 3.5, PAL["cream"] as Color)
	# Draw P2 Split Car (2 mahogany drawers on opposite rail!)
	if _split_active and boss_state != BossState.DEATH:
		for dp_w: Vector2 in [_split_pos, _split_tail]:
			var dp: Vector2 = (dp_w - pos).round()
			draw_rect(Rect2(dp - Vector2(7.0, 6.0), Vector2(14.0, 12.0)), PAL["wine"] as Color)
			draw_rect(Rect2(dp - Vector2(7.0, 6.0), Vector2(14.0, 12.0)), PAL["gold"] as Color, false, 1.2)
			draw_rect(Rect2(dp + Vector2(-3.0, -1.0), Vector2(6.0, 2.0)), PAL["cream"] as Color)
	# Comedy beat: alphabetized cream index cards sneezing out on tail hit!
	if _sneeze_t > 0.0:
		for k: int in range(4):
			var a: float = anim_t * 5.0 + float(k) * 1.5
			var cp: Vector2 = (c + Vector2(cos(a) * 18.0, -14.0 + sin(a) * 8.0)).round()
			draw_rect(Rect2(cp, Vector2(4.0, 3.0)), PAL["cream"] as Color)
			draw_rect(Rect2(cp + Vector2(1.0, 1.0), Vector2(2.0, 1.0)), PAL["coral"] as Color)
