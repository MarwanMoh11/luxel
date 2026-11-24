class_name LxDemoCasterBoss
extends LxBossBase
## Reference Boss 1 (Ground Caster): "The Cinder Cantor".
## Proves LxBossBase + Patterns + Ground (safe-zone inversion & rain) + Props + Adds + Stage tile edits.
## 3 phases, 3 distinct attacks, Phase 2 arena chasm edit + pillars + add wave, half-heart reward.

var _aim_dir: Vector2 = Vector2.LEFT
var _safe_spots: Array[Vector2] = []


func _init() -> void:
	super._init()
	kind = "demo_caster"
	boss_id = "demo_caster"
	boss_name_key = "BOSS_DEMO_CASTER"
	island_id = 1
	is_miniboss = true
	reward_heart = "half"
	music_cue = "boss_1"
	music_p2_cue = "boss_1_p2"
	max_hp = 68.0
	hp = 68.0
	body_radius = 9.0
	move_speed = 38.0
	stagger_threshold = 12.0
	stagger_duration = 1.45
	post_recover_cd = 0.28


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Ember Fan + P2 Gap Ring
	register_attack("ember_fan", {
		"weight": 1.25, "tell": 0.52, "commit": 0.34, "recover": 0.95, "cooldown": 1.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_lane(pos, pos + _aim_dir * 135.0, 10.0, last_tell_duration, 0.0, "coral", "gold"),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			var cnt: int = 7 if phase >= 2 else 5
			var spd: float = 148.0 if phase >= 3 else 132.0
			patterns.emit_fan(pos, _aim_dir, cnt, 0.85, spd, {"color": "coral", "source": "cinder_fan"})
			if phase >= 2:
				patterns.emit_gap_ring(pos, 12, 112.0, _aim_dir.angle() + PI * 0.45, 0.68, {"color": "gold", "source": "cinder_ring"})
			stage.shake(0.14)
			stage.play_sfx("bellkeeper_slam_fire", pos),
	})

	# Attack 2: Cinder Rain targeting Wick + arena corners (anti-corner-camping!)
	register_attack("cinder_rain", {
		"weight": 1.15, "tell": 0.56, "commit": 0.42, "recover": 1.00, "cooldown": 1.6,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var drops: Array[Vector2] = _build_rain_targets(tgt)
			patterns.emit_rain(ground, drops, last_tell_duration, 24.0, 1.0, "coral", "gold"),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			if phase >= 3:
				patterns.emit_expanding_square(pos, 3, 104.0, anim_t, 1, {"color": "apricot", "source": "cinder_square"})
			stage.shake(0.16)
			stage.play_sfx("sunflare_burst", pos),
	})

	# Attack 3: Sanctum Safe-Zone Inversion + Chain Lightning between pillars in P2+
	register_attack("sanctum_inversion", {
		"weight": 1.05, "tell": 0.85, "commit": 0.36, "recover": 1.12, "cooldown": 2.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			# Place one reachable safe circle 46px off Wick (never free for stationary campers!) + mirror circle
			var to_c: Vector2 = (c - tgt).normalized() if tgt.distance_to(c) > 4.0 else Vector2.RIGHT
			var s1: Vector2 = clamp_to_arena(tgt + to_c * 46.0)
			var s2: Vector2 = clamp_to_arena(c + (c - s1).limit_length(56.0))
			_safe_spots = [s1, s2]
			ground.warn_safe_inversion(arena_rect, _safe_spots, 28.0, last_tell_duration, 0.28, 1.0, "lime", "coral"),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			var p_pts: Array[Vector2] = props.get_positions("pillar")
			if phase >= 2 and p_pts.size() >= 2:
				patterns.emit_chain_lightning([p_pts[0], pos, p_pts[1]], 0.50, 9.0, 0.24, 1.0)
			elif phase >= 2:
				var c: Vector2 = arena_rect.get_center()
				patterns.emit_sweep_wall(Vector2(c.x, arena_rect.position.y + 8.0), Vector2.DOWN, arena_rect.size.x - 24.0, 9, 4, 2, 118.0, {"color": "gold", "source": "cinder_wall"})
			stage.light_burst(pos, 96.0, 1.45, 0.36)
			stage.shake(0.20),
	})


func _build_rain_targets(tgt: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var c: Vector2 = arena_rect.get_center()
	var inset: Rect2 = arena_rect.grow(-18.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	out.append(corners[0])
	if phase >= 2:
		out.append(corners[1])
		out.append(c.lerp(tgt, 0.5))
	return out


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# Arena tile change: open two outer corner chasms cleanly reverted on retry!
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 2), "pit")
		props.spawn_pillar(c + Vector2(-46.0, -28.0), 4.0, "cantor_pillar_w")
		props.spawn_pillar(c + Vector2(46.0, 28.0), 4.0, "cantor_pillar_e")
		adds.queue_wave([{"kind": "warden", "pos": c + Vector2(0.0, -44.0)}], 0.72, 1)
		stage.darkness_pulse(0.62, 1.0)
		stage.pan_to(pos, 0.55)
	elif new_phase == 3:
		props.spawn_chandelier(c, 2.5, "cantor_chandelier")
		stage.darkness_pulse(0.70, 1.1)
		stage.shake(0.24)


func _body_color() -> Color:
	return (PAL["coral"] if phase >= 3 else (PAL["wine"] if phase == 2 else PAL["plum"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	if _sprite_sheet != null:
		return
	var top: Vector2 = (off + Vector2(0.0, -body_radius)).round()
	draw_colored_polygon(PackedVector2Array([top + Vector2(-5.0, 1.0), top + Vector2(0.0, -7.0), top + Vector2(5.0, 1.0)]), PAL["gold"] as Color)
	draw_rect(Rect2(top + Vector2(-1.0, -4.0), Vector2(2.0, 2.0)), PAL["cream"] as Color)
