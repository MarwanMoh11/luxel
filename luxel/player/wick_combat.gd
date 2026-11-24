class_name LxWickCombat
extends RefCounted
## Damage, mercy frames, lethal void falls, and hit-landed ember/juice handling extracted from LxWick.


const VOID_RETRY_S: float = 0.45


static func take_damage(w: LxWick, amount: float, from_pos: Vector2, knock_dir: Vector2, source: String = "hazard") -> void:
	if w.dead:
		return
	if w.move_dash != null and w.move_dash.has_iframes():
		w.move_dash.on_perfect_dodge()
		return
	if w.is_gliding() and source == "shockwave" and (w.move_wings == null or w.move_wings.clears_shockwave()):
		if w.move_wings != null:
			w.move_wings.on_shockwave_cleared()
		return
	if w.is_invulnerable():
		return
	apply_damage_internal(w, amount, from_pos, knock_dir, source)


static func on_lantern_lost(w: LxWick, at_pos: Vector2, reason: String) -> void:
	w.spawn_ring(at_pos, 3.0, 20.0, 0.28, LxWick.PAL_CORAL, 1.5)
	w.spawn_sparks(at_pos, Vector2.UP, 10, LxWick.PAL_CORAL, 30.0, 95.0, 0.25)
	if not w.dead and w.mercy_t <= 0.0:
		apply_damage_internal(w, 1.0, at_pos, Vector2.ZERO, reason)


static func apply_damage_internal(w: LxWick, amount: float, from_pos: Vector2, knock_dir: Vector2, source: String) -> void:
	if w.is_grabbing(): w.release_grab(w._world_ctx)
	if w.is_carrying(): w.drop_carried()
	w._interact_held = false
	w._interact_cand = null
	var mult: float = clampf(float(Lx.save.settings.get("assist_damage_mult", 1.0)), 0.0, 1.0) if Lx.save != null else 1.0
	var dmg: float = 0.0 if w.god else maxf(0.0, amount * mult)
	if Lx.state != null:
		Lx.state.hearts = maxf(0.0, Lx.state.hearts - dmg)
		if dmg > 0.0:
			Lx.state.hits_taken += 1
		w._local_hearts = Lx.state.hearts
		w._local_max_hearts = Lx.state.max_hearts
	else:
		w._local_hearts = maxf(0.0, w._local_hearts - dmg)

	var kdir: Vector2 = knock_dir.normalized() if knock_dir.length_squared() > 0.0001 else ((w.global_position - from_pos).normalized() if w.global_position.distance_to(from_pos) > 0.1 else Vector2.ZERO)
	w.mercy_t = LxWick.MERCY_TIME
	w.hurt_flash = 1.0
	w.knock = kdir * 170.0
	w.trigger_hitstop(LxWick.HS_HURT)
	w.trigger_shake(LxWick.SHAKE_HURT)
	w.spawn_ring(w.global_position, 2.0, 16.0, 0.24, LxWick.PAL_CORAL, 1.5)
	w.spawn_sparks(w.global_position, kdir, 10, LxWick.PAL_CORAL, 35.0, 100.0, 0.26)
	w.emit_sfx("wick_hurt", w.global_position, false)
	if Lx.events != null:
		Lx.events.player_damaged.emit(dmg, from_pos, kdir, source)

	if w.get_hearts() <= 0.0 and not w.god and dmg > 0.0:
		w.dead = true
		if w.is_mounted(): w.dismount()
		if w.move_dash != null: w.move_dash.cancel()
		if w.move_wings != null: w.move_wings.stop_glide()
		if w.move_beam != null: w.move_beam.cancel()
		if w.move_throw != null: w.move_throw.cancel_zip()
		if Lx.state != null: Lx.state.deaths += 1
		if Lx.events != null: Lx.events.player_died.emit()


static func check_void_fall(w: LxWick, world_ctx: Node) -> void:
	if w.dead or w.is_dashing() or w.is_gliding() or w.is_zipping() or w.is_launched() or w.is_mounted():
		return
	var ctx: Node = world_ctx if world_ctx != null else w._world_ctx
	if ctx == null:
		return
	var lethal: bool = false
	if ctx.has_method("is_lethal_void_at"):
		lethal = bool(ctx.call("is_lethal_void_at", w.global_position))
	elif ctx.has_method("tile_at"):
		lethal = str(ctx.call("tile_at", w.global_position)) in ["pit", "void"]
	if not lethal:
		w._last_safe_pos = w.global_position
		return
	kill_by_void(w, w.global_position)


static func kill_by_void(w: LxWick, at_pos: Vector2) -> void:
	if w.dead:
		return
	var assist_zero: bool = (Lx.save != null and float(Lx.save.settings.get("assist_damage_mult", 1.0)) <= 0.001) \
			or (Lx.state != null and Lx.state.get("assist_damage_mult") != null and float(Lx.state.get("assist_damage_mult")) <= 0.001)
	if w.god or assist_zero:
		if w._last_safe_pos != Vector2.ZERO:
			w.global_position = w._last_safe_pos
			w.last_pos = w._last_safe_pos
		w.velocity = Vector2.ZERO
		w.knock = Vector2.ZERO
		return
	if w.is_grabbing(): w.release_grab(w._world_ctx)
	if w.is_carrying(): w.drop_carried()
	if w.is_mounted(): w.dismount()
	w._interact_held = false
	w._interact_cand = null
	var lost_hp: float = maxf(1.0, w.get_hearts())
	if Lx.state != null:
		Lx.state.hearts = 0.0
		Lx.state.hits_taken += 1
		Lx.state.deaths += 1
		w._local_hearts = 0.0
	else:
		w._local_hearts = 0.0
	w.dead = true
	w._void_retry_t = VOID_RETRY_S
	w.velocity = Vector2.ZERO
	w.knock = Vector2.ZERO
	w.hurt_flash = 1.0
	if w.move_dash != null: w.move_dash.cancel()
	if w.move_wings != null: w.move_wings.stop_glide()
	if w.move_beam != null: w.move_beam.cancel()
	if w.move_throw != null: w.move_throw.cancel_zip()
	w.trigger_hitstop(LxWick.HS_HURT)
	w.trigger_shake(LxWick.SHAKE_HURT)
	w.spawn_ring(at_pos, 10.0, 2.0, 0.28, LxWick.PAL_DUSK, 2.0)
	w.spawn_ring(at_pos, 2.0, 14.0, 0.24, LxWick.PAL_CORAL, 1.2)
	w.spawn_sparks(at_pos, Vector2.UP, 10, LxWick.PAL_CORAL, 20.0, 75.0, 0.28)
	w.emit_sfx("wick_hurt", at_pos, false)
	if Lx.state != null and Lx.state.has_method("append_run_log"):
		Lx.state.append_run_log("death")
	if Lx.events != null:
		Lx.events.player_damaged.emit(lost_hp, at_pos, Vector2.ZERO, "void")


static func tick_void_retry(w: LxWick, dt: float, world_ctx: Node) -> bool:
	if not w.dead or w._void_retry_t <= 0.0:
		return false
	w._void_retry_t = maxf(0.0, w._void_retry_t - dt)
	if w._void_retry_t > 0.0:
		return true
	var respawn_p: Vector2 = _find_void_respawn_pos(w, world_ctx)
	w.dead = false
	w.global_position = respawn_p
	w.last_pos = respawn_p
	w._last_safe_pos = respawn_p
	w.velocity = Vector2.ZERO
	w.knock = Vector2.ZERO
	w._field_vel = Vector2.ZERO
	w._launch_t = 0.0
	w._launch_vel = Vector2.ZERO
	w.mercy_t = 0.90
	w.hurt_flash = 0.0
	if Lx.state != null:
		Lx.state.hearts = float(Lx.state.max_hearts)
		w._local_hearts = Lx.state.hearts
		w._local_max_hearts = Lx.state.max_hearts
	else:
		w._local_hearts = float(w._local_max_hearts)
	if w.lantern != null:
		w.lantern.reset_to_hand(respawn_p)
	w.spawn_ring(respawn_p, 2.0, 16.0, 0.24, LxWick.PAL_GOLD, 1.5)
	w.spawn_sparks(respawn_p, Vector2.UP, 6, LxWick.PAL_CREAM, 20.0, 60.0, 0.20)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.trigger_transition_fade(0.20)
	w.emit_sfx("phantom_phase", respawn_p, false)
	return true


static func _find_void_respawn_pos(w: LxWick, world_ctx: Node) -> Vector2:
	var ctx: Node = world_ctx if world_ctx != null else w._world_ctx
	# 1. Prefer an active room_anchor interactable if set, else last safe ground, else room spawn
	if ctx != null:
		for it_v: Variant in w.world_get_interactables(ctx):
			if it_v is Object and is_instance_valid(it_v as Object):
				var it: Object = it_v as Object
				if str(it.get("kind")) == "room_anchor" and bool(it.get("active")):
					var is_cur: bool = (it.get("activated") is bool and bool(it.get("activated"))) \
						or (it.get("lit") is bool and bool(it.get("lit"))) \
						or (it.get("powered") is bool and bool(it.get("powered")))
					if is_cur:
						var ap: Vector2 = w.get_entity_pos(it)
						if not (ctx.has_method("is_lethal_void_at") and bool(ctx.call("is_lethal_void_at", ap))):
							return ap
	if w._last_safe_pos != Vector2.ZERO:
		if ctx == null or not (ctx.has_method("is_lethal_void_at") and bool(ctx.call("is_lethal_void_at", w._last_safe_pos))):
			return w._last_safe_pos
	if ctx != null and ctx.has_method("get_spawn_pos"):
		return ctx.call("get_spawn_pos") as Vector2
	return w.global_position


static func on_hit_landed(w: LxWick, hit: LxHit, result: int, target_pos: Vector2, hitstop_s: float, shake_i: float) -> void:
	if result < 0:
		return
	if result == 0:
		w.trigger_hitstop(LxWick.HS_BLOCK)
		w.trigger_shake(LxWick.SHAKE_BLOCK)
		w.spawn_sparks(target_pos, -hit.dir, 5, LxWick.PAL_STONE, 25.0, 75.0, 0.16)
		w.emit_sfx("shield_clang", target_pos, true)
		return
	w.trigger_hitstop(hitstop_s)
	w.trigger_shake(shake_i)
	var heavy: bool = hit.is_heavy()
	w.spawn_sparks(target_pos, hit.dir, 8 if heavy else 4, LxWick.PAL_GOLD if heavy else LxWick.PAL_CREAM, 30.0, 95.0, 0.20)
	if heavy:
		w.spawn_ring(target_pos, 2.0, 14.0, 0.20, LxWick.PAL_GOLD, 1.0)
	w.emit_sfx("heavy_hit" if heavy else "bolt_chip", target_pos, true)
	if hit.source != LxHit.SOURCE_SUNFLARE:
		var sd: Dictionary = Lx.get_move_data("sunflare")
		var gain: float = float(sd.get("ember_per_kill", 20.0)) if result == LxEnemyBrain.HitResult.KILLED else (float(sd.get("ember_per_heavy", 18.0)) if heavy else float(sd.get("ember_per_bolt", 6.0)))
		var panes_e: LxPanes = LxPanes.current()
		if panes_e != null and not panes_e.equipped_ids().is_empty():
			gain *= panes_e.modify_stat("ember_gain", 1.0, {"wick": w, "hit": hit, "result": result})
		var emax: float = w.move_sunflare.get_ember_max() if w.move_sunflare != null else (Lx.state.get_effective_ember_max() if Lx.state != null else float(sd.get("ember_max", 100.0)))
		var was_full: bool = w.ember >= emax - 0.001
		w.ember = minf(emax, w.ember + gain)
		if not was_full and w.ember >= emax - 0.001 and w.move_sunflare != null and w.move_sunflare.unlocked:
			w.spawn_ring(w.global_position, 3.0, 18.0, 0.28, LxWick.PAL_GOLD, 1.5)
			w.emit_sfx("beam_ready", w.global_position, false)
