class_name LxRoseSeraphBoss
extends LxBossBase
## Island 8 Mini-Boss: The Rose-Window Seraph (Bell Sanctum East Bell-Gallery, sanctum_r12).
## Six-winged stained-glass seraph whose halo hue (gold / sky / rose) sets BOTH the safe
## stained-carpet stripe AND her wing weakness! Beam / Sunflare / Prism-blue OR hitting from
## the halo-matching carpet stripe shatters her stained wings for a 2.0s stagger!

const HUES: Array[String] = ["gold", "sky", "rose"]
const HUE_CYCLE_P1: float = 9.0
const HUE_CYCLE_P2: float = 6.0

var hue_idx: int = 0
var _hue_timer: float = HUE_CYCLE_P1
var _wings_shattered_t: float = 0.0
var _shatter_flash_t: float = 0.0
var _carpet_safe_band: int = 0 # 0=west, 1=center, 2=east matching HUES[0..2]


func _init() -> void:
	super._init()
	kind = "rose_seraph"
	boss_id = "rose_seraph"
	boss_name_key = "ISL8_BOSS_SERAPH"
	island_id = 8
	is_miniboss = true
	reward_heart = "half"
	music_cue = "isl8_boss_minor_p1"
	music_p2_cue = "isl8_boss_minor_p2"
	max_hp = 128.0
	hp = 128.0
	body_radius = 12.0
	move_speed = 46.0
	stagger_threshold = 14.0
	stagger_duration = 2.00
	post_stagger_immunity = 3.8
	punish_dmg_mult = 1.40
	post_recover_cd = 0.30
	intro_duration = 0.50
	phase_shift_duration = 0.60
	death_duration = 2.2
	shard_drop = 30


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.50]) # 2 Phases!

	# Attack 1: Stained Carpet Flare (unsafe carpet stripes glow coral -> stand on matching hue stripe!)
	register_attack("stained_carpet_flare", {
		"weight": 1.25, "tell": 0.62, "commit": 0.30, "recover": 1.15, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_carpet_safe_band = hue_idx
			var band_w: float = arena_rect.size.x / 3.0
			for bi: int in range(3):
				if bi == _carpet_safe_band:
					continue
				var br := Rect2(arena_rect.position.x + float(bi) * band_w + 2.0, arena_rect.position.y + 4.0, band_w - 4.0, arena_rect.size.y - 8.0)
				ground.warn_rect(br, last_tell_duration, 1.0, "coral", HUES[hue_idx])
			# Also pressure camping on the safe stripe with a dodgeable ring!
			ground.warn_ring(clamp_to_arena(tgt), 22.0, last_tell_duration + 0.08, 1.0, HUES[hue_idx], "cream")
			stage.play_sfx("lens_reveal", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.DOWN
			patterns.emit_fan(pos, aim, 3, 0.56, 136.0, {"color": HUES[hue_idx], "source": "carpet_flare"})
			stage.shake(0.18)
			stage.play_sfx("prism_chain", pos),
	})

	# Attack 2: Lead-Cane Volley (5 stained glass shards + aimed rings)
	register_attack("lead_cane_volley", {
		"weight": 1.25, "tell": 0.50, "commit": 0.28, "recover": 1.05, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			facing = aim.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + aim * 155.0), 10.0, last_tell_duration, 0.0, HUES[hue_idx], "cream")
			patterns.emit_rain(ground, [clamp_to_arena(tgt)], last_tell_duration + 0.05, 19.0, 1.0, HUES[hue_idx], "coral")
			stage.play_sfx("seraph_hue_shift", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			patterns.emit_fan(pos, aim, 5, 0.88, 142.0 if phase >= 2 else 130.0, {"color": HUES[hue_idx], "source": "lead_cane", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("prism_chain", pos),
	})

	# Attack 3: Rose Mandala Ring (stained-glass gap ring + orbiting shards)
	register_attack("rose_mandala_ring", {
		"weight": 1.15, "tell": 0.54, "commit": 0.34, "recover": 1.10, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			ground.warn_ring(pos, 50.0, last_tell_duration, 0.0, HUES[hue_idx], "cream")
			patterns.emit_rain(ground, [clamp_to_arena(tgt), clamp_to_arena(tgt.lerp(arena_rect.get_center(), 0.45))], last_tell_duration + 0.04, 18.0, 1.0, HUES[hue_idx], "gold")
			stage.play_sfx("lens_reveal", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aa: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 124.0, aa + 0.55, 0.78, {"color": HUES[hue_idx], "source": "mandala_shard"})
			patterns.emit_orbit(pos, 4, 42.0, 2.0, 1.8, {"color": HUES[(hue_idx + 1) % 3], "source": "mandala_orbit"})
			stage.shake(0.16)
			stage.play_sfx("prism_chain", pos),
	})

	# Attack 4 (P2): Prismatic Ribbon (twin sweeping cathedral glass rays!)
	register_attack("prismatic_ribbon", {
		"phases": [2], "weight": 2.10, "tell": 0.56, "commit": 0.48, "recover": 1.25, "cooldown": 1.3,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.LEFT
			facing = aim.angle()
			var p1: Vector2 = clamp_to_arena(pos + aim.rotated(-0.34) * 160.0)
			var p2: Vector2 = clamp_to_arena(pos + aim.rotated(0.34) * 160.0)
			patterns.emit_chain_lightning([pos, p1], last_tell_duration, 8.5, 0.34, 1.0)
			patterns.emit_chain_lightning([pos, p2], last_tell_duration + 0.08, 8.5, 0.34, 1.0)
			ground.warn_lane(pos, clamp_to_arena(pos + aim * 160.0), 10.0, last_tell_duration, 0.0, "rose", "cream")
			stage.play_sfx("beam_charge", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aa: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_spiral(pos, 3, 134.0, aa, 0.52, 2, 0.14, {"color": HUES[hue_idx], "source": "prismatic_ribbon"})
			stage.shake(0.20)
			stage.play_sfx("beam_fire", pos),
	})


func _on_reset_encounter() -> void:
	hue_idx = 0
	_hue_timer = HUE_CYCLE_P1
	_wings_shattered_t = 0.0
	_shatter_flash_t = 0.0
	_carpet_safe_band = 0


func _on_phase_enter(new_phase: int) -> void:
	if new_phase == 2:
		_advance_hue()
		var c: Vector2 = arena_rect.get_center()
		props.spawn_pillar(clamp_to_arena(c + Vector2(-58.0, -28.0)), 4.0, "glass_pane_w")
		props.spawn_pillar(clamp_to_arena(c + Vector2(58.0, 28.0)), 4.0, "glass_pane_e")
		stage.darkness_pulse(0.60, 0.95)
		stage.shake(0.22)
		stage.play_sfx("hush_veil_shatter", pos)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_wings_shattered_t = maxf(0.0, _wings_shattered_t - dt)
	_shatter_flash_t = maxf(0.0, _shatter_flash_t - dt)
	_hue_timer -= dt
	if _hue_timer <= 0.0:
		_advance_hue()


func _advance_hue() -> void:
	hue_idx = (hue_idx + 1) % HUES.size()
	_carpet_safe_band = hue_idx
	_hue_timer = HUE_CYCLE_P2 if phase >= 2 else HUE_CYCLE_P1
	stage.play_sfx("seraph_hue_shift", pos)


func _is_point_on_matching_carpet(p: Vector2) -> bool:
	if not arena_rect.has_area():
		return false
	var band_w: float = arena_rect.size.x / 3.0
	var b: int = clampi(int((p.x - arena_rect.position.x) / maxf(band_w, 1.0)), 0, 2)
	return b == hue_idx


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var filtered_match: bool = src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE or src == LxHit.SOURCE_PRISM or hit.is_blue() or _is_point_on_matching_carpet(orig)
	if filtered_match:
		if _wings_shattered_t <= 0.0 and (src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_SUNFLARE):
			_wings_shattered_t = 5.0
			_shatter_flash_t = 0.65
			stage.play_sfx("seraph_glass_shatter", pos)
			add_stagger(stagger_threshold)
		return dmg * 1.40
	if _wings_shattered_t > 0.0 or is_punishable():
		return dmg * 1.25
	# Unfiltered bolts glance partially through intact stained-glass wings
	return dmg * 0.72


func _on_death_start() -> void:
	stage.light_burst(pos, 110.0, 1.5, 0.45)
	stage.shake(0.24)
	stage.play_sfx("hush_veil_shatter", pos)


func _body_color() -> Color:
	return LxPalette.color(HUES[hue_idx], "gold")


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	var fred: bool = is_flash_reduced()
	# Three stained-glass carpet bands across the nave (matching hue glows brightest!)
	if arena_rect.has_area() and boss_state != BossState.DEATH:
		var band_w: float = arena_rect.size.x / 3.0
		for bi: int in range(3):
			var col: Color = LxPalette.color(HUES[bi], "gold")
			var active_h: bool = (bi == hue_idx)
			var loc_p: Vector2 = (Vector2(arena_rect.position.x + float(bi) * band_w + 3.0, arena_rect.position.y + 4.0) - pos + off).round()
			var r_loc := Rect2(loc_p, Vector2(band_w - 6.0, arena_rect.size.y - 8.0))
			draw_rect(r_loc, Color(col, (0.14 if active_h else 0.05) if not fred else (0.10 if active_h else 0.04)), true)
			if active_h:
				draw_rect(r_loc, Color(col, 0.48), false, 1.0)
	# Glowing Halo Hue Ring around the Rose-Window Seraph
	if boss_state != BossState.DEATH:
		var hc: Color = LxPalette.color(HUES[hue_idx], "gold")
		draw_arc(c + Vector2(0.0, -16.0), 21.0, 0.0, TAU, 24, hc, 1.6)
		if _wings_shattered_t > 0.0:
			draw_arc(c + Vector2(0.0, -16.0), 25.0, anim_t * 2.0, anim_t * 2.0 + PI, 14, PAL["cream"] as Color, 1.2)
	if _shatter_flash_t > 0.0:
		var u: float = 1.0 - clampf(_shatter_flash_t / 0.65, 0.0, 1.0)
		draw_arc(c, lerpf(14.0, 62.0, u), 0.0, TAU, 24, Color(PAL["cream"] as Color, 1.0 - u), 2.0)
