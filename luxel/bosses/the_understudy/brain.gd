class_name LxTheUnderstudyBoss
extends LxBossBase
## Island 7 Boss: THE UNDERSTUDY (Doppel Theatre Grand Stage Boss, theatre_r12).
## Act V — Curtain Call: Armed with Wick's own kit! Each phase steals ONE move into a hovering
## Spotlight Mask via `duel.steal_move` + `Wick.set_move_locked`:
##   P1 (100-66%): steals "throw" (Mask HP 3.5) -> uses dark Throw+Zip!
##   P2 (66-33%): wing curtains drop + trapdoors + steals "dash" (Mask HP 4.0) -> Triple Flare-Dash!
##   P3 (<=33%): rotating spotlights + steals "bolt" (Mask HP 4.5) -> 5-Bolt Fan + Dark Beam!
## Shattering the hovering Spotlight Mask triggers a 2.0s standing-ovation boss stagger and
## restores the stolen move immediately.
## SAFETY LAW: Every stolen move is ALWAYS given back on mask break, death, retry, exit, and victory!

const PHASE_STEAL_MOVES: Array[String] = ["throw", "dash", "bolt"]
const PHASE_MASK_HP: Array[float] = [4.5, 5.0, 5.5]

var _aim_dir: Vector2 = Vector2.LEFT
var _dash_step: int = 0
var _mask_active: bool = false
var _mask_move: String = ""
var _mask_hp: float = 0.0
var _mask_max_hp: float = 3.5
var _mask_orbit_a: float = -PI * 0.5
var _mask_flash_t: float = 0.0
var _mask_reclaim_t: float = 0.0
var _spot_ang: float = 0.0
var _stolen_this_phase: bool = false


func _init() -> void:
	super._init()
	kind = "the_understudy"
	boss_id = "the_understudy"
	boss_name_key = "ISL7_BOSS_UNDER"
	island_id = 7
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island7_boss_p1"
	music_p2_cue = "island7_boss_p2"
	max_hp = 188.0
	hp = 188.0
	body_radius = 10.5
	move_speed = 42.0
	stagger_threshold = 24.0
	stagger_duration = 2.00
	post_recover_cd = 0.50
	shard_drop = 45


func _exit_tree() -> void:
	_restore_all_stolen()


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Curtain Snatch — steals phase's signature move into hovering Spotlight Mask + curtain fan!
	register_attack("curtain_snatch", {
		"weight": 1.35, "tell": 0.62, "commit": 0.30, "recover": 1.15, "cooldown": 3.0,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			ground.warn_ring(pos, 46.0, last_tell_duration, 0.0, "gold", "coral")
			ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 140.0), 10.0, last_tell_duration, 0.0, "wine", "gold")
			stage.play_sfx("curtain_whoosh", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			if not _mask_active:
				_activate_phase_mask(phase)
			patterns.emit_fan(pos, _aim_dir, 5 if phase >= 2 else 3, 0.78, 140.0, {"color": "rose", "source": "snatch_ribbon", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("mask_steal", pos),
	})

	# Attack 2: Stolen Signature — wields the stolen move (P1 Throw+Zip, P2 Triple Flare-Dash, P3 5-Bolt Fan + Beam)
	register_attack("stolen_signature", {
		"weight": 1.45, "tell": 0.50, "commit": 0.34, "recover": 1.22, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_dash_step = 0
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			if phase == 1:
				var dest: Vector2 = clamp_to_arena(tgt)
				set_meta("_zip_dest", dest)
				ground.warn_ring(dest, 22.0, last_tell_duration, 0.0, "wine", "gold")
				stage.play_sfx("lantern_throw", pos)
			elif phase == 2:
				ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 88.0), 11.0, last_tell_duration, 0.0, "coral", "gold")
				stage.play_sfx("hollow_wick_tell", pos)
			else:
				ground.warn_lane(pos, clamp_to_arena(pos + _aim_dir * 165.0), 10.0, last_tell_duration, 0.0, "sky", "coral")
				stage.play_sfx("beam_charge", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
			if phase == 1:
				patterns.emit_boomerang(pos, _aim_dir, 138.0, 0.62, 0.65, {"color": "coral", "source": "stolen_throw", "reflectable": true})
				stage.play_sfx("hollow_wick_zip", pos)
			elif phase == 2:
				stage.play_sfx("hollow_dash", pos)
			else:
				patterns.emit_fan(pos, _aim_dir, 3, 0.85, 124.0, {"color": "ice", "source": "stolen_volley", "reflectable": true})
				patterns.emit_lane(pos, _aim_dir, 3, 146.0, 0.08, {"color": "coral", "source": "stolen_beam", "reflectable": true})
				stage.shake(0.16)
				stage.play_sfx("beam_fire", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, el: float) -> void:
			if phase == 1:
				var dest: Vector2 = get_meta("_zip_dest", pos) as Vector2
				move_boss((dest - pos).limit_length(250.0 * dt), true)
				if pos.distance_to(dest) <= 10.0:
					check_contact_damage(20.0, _aim_dir, 1.0, "stolen_zip")
			elif phase == 2:
				if _dash_step == 0 and el >= 0.12:
					_dash_step = 1
					_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
					patterns.emit_fan(pos, _aim_dir, 3, 0.65, 122.0, {"color": "coral", "source": "dash_trail", "reflectable": true})
					stage.play_sfx("hollow_dash", pos)
				elif _dash_step == 1 and el >= 0.24:
					_dash_step = 2
					_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else _aim_dir
					stage.play_sfx("hollow_dash", pos)
				move_boss(_aim_dir * 215.0 * dt, false)
				check_contact_damage(16.0, _aim_dir, 1.0, "stolen_dash"),
	})

	# Attack 3: Trapdoor Drop — coral floor trapdoors under Wick & corners (pressures all 8 perimeter spots!)
	register_attack("trapdoor_drop", {
		"weight": 1.15, "tell": 0.56, "commit": 0.30, "recover": 1.15, "cooldown": 2.2,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var spots: Array[Vector2] = _trapdoor_targets(tgt, 3 if phase >= 2 else 2)
			for i: int in range(spots.size()):
				var sp: Vector2 = spots[i]
				ground.warn_rect(Rect2(sp - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), last_tell_duration + float(i) * 0.06, 1.0, "coral", "gold", 0.8)
			stage.play_sfx("curtain_whoosh", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var d: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			patterns.emit_gap_ring(pos, 8, 118.0, d.angle() + PI, 0.80, {"color": "gold", "source": "trapdoor_sparks", "reflectable": true})
			stage.shake(0.14)
			stage.play_sfx("timpani_hit", pos),
	})

	# Attack 4: Encore Bow — 44px sweeping rose arc + reflectable foil daggers
	register_attack("encore_bow", {
		"weight": 1.25, "tell": 0.52, "commit": 0.26, "recover": 1.20, "cooldown": 1.7,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_aim_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 0.1 else Vector2.from_angle(facing)
			var a: float = _aim_dir.angle()
			ground.warn_sector(pos, a - 0.90, a + 0.90, 48.0, last_tell_duration, 1.0, "rose", "gold")
			stage.play_sfx("applause_ghost", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _aim_dir, 5 if phase >= 3 else 3, 0.72, 132.0, {"color": "rose", "source": "encore_arc", "reflectable": true})
			stage.shake(0.12)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, _tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_aim_dir * 125.0 * dt, false)
			check_contact_damage(18.0, _aim_dir, 1.0, "encore_bow"),
	})


func _on_reset_encounter() -> void:
	_restore_all_stolen()
	_mask_active = false
	_mask_move = ""
	_mask_hp = 0.0
	_mask_flash_t = 0.0
	_mask_reclaim_t = 0.0
	_spot_ang = 0.0
	_stolen_this_phase = false


func _on_engage() -> void:
	_activate_phase_mask(1)


func _on_phase_enter(new_phase: int) -> void:
	_restore_all_stolen()
	_stolen_this_phase = false
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		# Wing curtains drop + 2 stage trapdoor pits + 2 stage pillars!
		stage.set_tiles(world_ctx, Rect2i(3, 2, 1, 2), "pit")
		stage.set_tiles(world_ctx, Rect2i(16, 7, 1, 2), "pit")
		props.spawn_pillar(c + Vector2(-50.0, -24.0), 4.0, "stage_curtain_w")
		props.spawn_pillar(c + Vector2(50.0, 24.0), 4.0, "stage_curtain_e")
		stage.darkness_pulse(0.58, 1.0)
		stage.shake(0.24)
		stage.play_sfx("curtain_whoosh", pos)
	elif new_phase == 3:
		stage.darkness_pulse(0.68, 1.1)
		stage.shake(0.26)
		stage.play_sfx("applause_ghost", pos)
	_activate_phase_mask(new_phase)


func _activate_phase_mask(for_phase: int) -> void:
	_restore_all_stolen()
	var idx: int = clampi(for_phase - 1, 0, PHASE_STEAL_MOVES.size() - 1)
	var mid: String = PHASE_STEAL_MOVES[idx]
	_mask_move = mid
	_mask_max_hp = PHASE_MASK_HP[idx]
	_mask_hp = _mask_max_hp
	_mask_active = true
	_stolen_this_phase = true
	_mask_flash_t = 0.30
	# Lock via LxBossDuel + Wick.set_move_locked (and Island 7 HUD if active!)
	duel.steal_move(mid)
	if LxIsland7Rule.active_rule != null:
		LxIsland7Rule.active_rule.steal_moves([mid], "act5", "the_understudy")
	stage.play_sfx("mask_steal", pos)


func _restore_all_stolen() -> void:
	if duel != null:
		duel.restore_stolen_moves()
	if LxIsland7Rule.active_rule != null:
		LxIsland7Rule.active_rule.reclaim_moves(PHASE_STEAL_MOVES, "the_understudy")
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("set_move_locked"):
		for mid: String in PHASE_STEAL_MOVES:
			Lx.player.call("set_move_locked", mid, false)
		if Lx.player.has_method("sync_unlocks_from_state"):
			Lx.player.call("sync_unlocks_from_state")
	_mask_active = false
	_mask_move = ""
	_mask_hp = 0.0


func _mask_world_pos() -> Vector2:
	return clamp_to_arena(pos + Vector2(cos(_mask_orbit_a) * 24.0, -14.0 + sin(_mask_orbit_a) * 12.0))


func _damage_mask(amount: float) -> void:
	if not _mask_active or amount <= 0.0:
		return
	_mask_hp = maxf(0.0, _mask_hp - amount)
	_mask_flash_t = 0.20
	if _mask_hp <= 0.001:
		_shatter_mask()
	else:
		stage.play_sfx("mirror_ping", _mask_world_pos())


func _shatter_mask() -> void:
	var mp: Vector2 = _mask_world_pos()
	_restore_all_stolen()
	_mask_reclaim_t = 1.2
	LxDamageFx.boss_impact(mp, 0.22, 86.0, 84.0, 84.0, 1.40, 0.34)
	stage.play_sfx("mask_shatter", mp)
	stage.play_sfx("applause_ghost", pos)
	# Standing-ovation 2.0s boss stagger!
	stagger_immunity_t = 0.0
	stagger_meter = stagger_threshold
	add_stagger(1.0)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_mask_flash_t = maxf(0.0, _mask_flash_t - dt)
	_mask_reclaim_t = maxf(0.0, _mask_reclaim_t - dt)
	_mask_orbit_a = wrapf(_mask_orbit_a + dt * 1.9, -PI, PI)
	_spot_ang = wrapf(_spot_ang + dt * 1.15, -PI, PI)

	# Safety guarantee: if Wick dies mid-fight, immediately return every stolen move!
	if Lx.player != null and is_instance_valid(Lx.player) and bool(Lx.player.get("dead")):
		if _mask_active or not duel.stolen_moves.is_empty():
			_restore_all_stolen()
		return

	# Allow player bolts to directly shoot and shatter the hovering Spotlight Mask!
	if _mask_active and Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		var mp: Vector2 = _mask_world_pos()
		for bi: int in range(w.bolts.size() - 1, -1, -1):
			var bv: Variant = w.bolts[bi]
			if bv is Object:
				var bp: Vector2 = bv.get("pos") as Vector2
				if bp.distance_to(mp) <= 15.0:
					var bd: float = maxf(0.5, float(bv.get("damage")))
					w.bolts.remove_at(bi)
					_damage_mask(bd * 1.35)
					break


func _has_active_shield() -> bool:
	return _mask_active


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var is_pierce: bool = src in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE] or bool(h["pierce"])
	# While the hovering Spotlight Mask holds Wick's stolen light, Understudy wears a spotlight veil!
	if _mask_active:
		var is_heavy: bool = is_pierce or src in [LxHit.SOURCE_THROW, LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_DASH] or hit.is_blue()
		_damage_mask(dmg * (0.90 if is_heavy else 0.50))
		if is_pierce:
			return dmg * 0.85
		return dmg * (0.24 if is_punishable() else 0.15)
	if is_pierce:
		return dmg * 0.85
	if boss_state == BossState.STAGGER:
		return dmg * 0.72
	if boss_state == BossState.RECOVER:
		return dmg * 0.55
	return dmg * 0.30


func _on_death_start() -> void:
	_restore_all_stolen()
	stage.play_sfx("mask_shatter", pos)
	stage.play_sfx("applause_ghost", pos)


func _trapdoor_targets(tgt: Vector2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = [clamp_to_arena(tgt)]
	var inset: Rect2 = arena_rect.grow(-22.0)
	var corners: Array[Vector2] = [
		inset.position, Vector2(inset.end.x, inset.position.y),
		Vector2(inset.position.x, inset.end.y), inset.end,
	]
	corners.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(tgt) < b.distance_squared_to(tgt))
	for i: int in range(mini(count - 1, corners.size())):
		out.append(clamp_to_arena(corners[i]))
	return out


func _body_color() -> Color:
	return PAL["plum"] as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# P3 Rotating Golden Floor Spotlights (Cue-Mirror synergy!)
	if phase >= 3:
		var ctr: Vector2 = arena_rect.get_center() - pos
		for si: int in range(2):
			var sa: float = _spot_ang + float(si) * PI
			var sp: Vector2 = (ctr + Vector2.from_angle(sa) * 56.0).round()
			draw_circle(sp, 20.0, Color(PAL["gold"] as Color, 0.16))
			draw_arc(sp, 20.0, 0.0, TAU, 18, Color(PAL["gold"] as Color, 0.45), 1.0)

	# Hovering Spotlight Mask holding the stolen move!
	if _mask_active:
		var mp: Vector2 = (_mask_world_pos() - pos).round()
		# Golden spotlight cone & tether ribbon from chest medallion
		draw_line(c + Vector2(0.0, -6.0), mp, Color(PAL["gold"] as Color, 0.65), 1.4)
		draw_circle(mp, 12.0, Color(PAL["gold"] as Color, 0.22))
		draw_arc(mp, 11.0, 0.0, TAU, 18, PAL["cream"] as Color if _mask_flash_t > 0.0 else PAL["gold"] as Color, 1.5)
		draw_rect(Rect2(mp - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), PAL["void"] as Color)
		draw_rect(Rect2(mp - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), PAL["cream"] as Color if _mask_flash_t > 0.0 else PAL["ice"] as Color)
		# Iron cage bars + HP bar
		for bx: float in [-2.0, 1.0]:
			draw_rect(Rect2(mp + Vector2(bx, -5.0), Vector2(1.0, 10.0)), PAL["coral"] as Color)
		var frac: float = clampf(_mask_hp / maxf(_mask_max_hp, 0.1), 0.0, 1.0)
		draw_rect(Rect2(mp + Vector2(-7.0, 8.0), Vector2(14.0, 2.0)), PAL["void"] as Color)
		draw_rect(Rect2(mp + Vector2(-7.0, 8.0), Vector2(roundf(14.0 * frac), 2.0)), PAL["coral"] as Color)
	elif _mask_reclaim_t > 0.0:
		var u: float = 1.0 - clampf(_mask_reclaim_t / 1.2, 0.0, 1.0)
		draw_arc(c, roundf(lerpf(12.0, 42.0, u)), 0.0, TAU, 22, Color(PAL["gold"] as Color, 1.0 - u), 1.6)
