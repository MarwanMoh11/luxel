class_name LxDamageFx
extends RefCounted
## Death's Door-inspired progressive enemy wear, strained shield fissures,
## and non-blocking boss arena awakening entrance beats (strictly 20 Last Light colours).


static func _flash_reduced() -> bool:
	return Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))


static func draw_wear(enemy: LxEnemyBrain, off: Vector2) -> void:
	if enemy == null or enemy.state == LxEnemyBrain.State.DEAD:
		return
	var pal: Dictionary = LxEnemyBrain.PAL
	var r: float = enemy.body_radius
	var t: float = enemy.anim_t
	var fred: bool = _flash_reduced()

	# 1. Boss Awakening Entrance Ring (0.55 s non-blocking gothic aura pulse)
	if enemy.awaken_t > 0.0:
		var prog: float = 1.0 - clampf(enemy.awaken_t / 0.55, 0.0, 1.0)
		var ease_p: float = 1.0 - pow(1.0 - prog, 2.0)
		var outer_r: float = lerpf(r + 3.0, r + 34.0, ease_p)
		var inner_r: float = lerpf(r + 1.0, r + 20.0, ease_p)
		var a_out: float = (1.0 - prog) * (0.55 if fred else 0.90)
		enemy.draw_arc(off, outer_r, 0.0, TAU, 24, Color(pal["gold"] as Color, a_out), 1.5)
		enemy.draw_arc(off, inner_r, 0.0, TAU, 18, Color(pal["cream"] as Color, a_out * 0.85), 1.0)
		for ci: int in range(4):
			var ang: float = float(ci) * (PI * 0.5) + prog * 0.45
			var p0: Vector2 = (off + Vector2.from_angle(ang) * (r + 4.0 + ease_p * 10.0)).round()
			var p1: Vector2 = (off + Vector2.from_angle(ang) * (r + 8.0 + ease_p * 16.0)).round()
			enemy.draw_line(p0, p1, Color(pal["apricot"] as Color, a_out), 1.0)

	if enemy.max_hp <= 0.01 or enemy.hp <= 0.0:
		return
	var hp_ratio: float = clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)

	# 2. Stage 1 Wear (<= 65% HP on bosses & heavy foes): subtle hairline fracture + drifting spark
	if hp_ratio <= 0.65 and (enemy.is_boss or enemy.max_hp >= 5.0):
		var c1: Vector2 = (off + Vector2(-r * 0.35, -r * 0.25)).round()
		enemy.draw_line(c1, c1 + Vector2(2.0, 3.0), pal["void"] as Color, 1.0)
		enemy.draw_rect(Rect2(c1 + Vector2(1.0, 1.0), Vector2.ONE), pal["apricot"] as Color)
		var dr: float = fmod(t * 1.4, 1.0)
		var sp1: Vector2 = (off + Vector2(sin(t * 2.3) * (r * 0.6), -r * 0.3 - dr * 7.0)).round()
		if dr < 0.72:
			enemy.draw_rect(Rect2(sp1, Vector2.ONE), pal["apricot"] as Color)

	# 3. Stage 2 Critical Wear (<= 35% HP on all foes): deep fracture + unstable coral embers
	if hp_ratio <= 0.35:
		var c2: Vector2 = (off + Vector2(r * 0.25, -r * 0.10)).round()
		enemy.draw_line(c2, c2 + Vector2(-3.0, 2.0), pal["night"] as Color, 1.0)
		enemy.draw_rect(Rect2(c2 + Vector2(-1.0, 1.0), Vector2.ONE), pal["coral"] as Color)
		var blink_ok: bool = fred or fmod(t * 3.5, 1.0) < 0.62
		if blink_ok:
			var ca: float = t * 4.2
			enemy.draw_rect(Rect2((off + Vector2(cos(ca) * (r + 1.0), -r * 0.4 + sin(ca * 1.3) * 3.0)).round(), Vector2(2.0, 1.0)), pal["coral"] as Color)
			enemy.draw_rect(Rect2((off + Vector2(-cos(ca * 0.9) * r, -r * 0.1 + cos(ca) * 2.5)).round(), Vector2.ONE), pal["apricot"] as Color)
		if enemy.is_boss:
			var pulse_a: float = 0.55 if fred else (0.38 + 0.34 * absf(sin(t * 5.2)))
			var bcol: Color = Color(pal["coral"] as Color, pulse_a)
			enemy.draw_arc(off, r + 4.0, t * 1.5, t * 1.5 + 1.15, 10, bcol, 1.0)
			enemy.draw_arc(off, r + 4.0, t * 1.5 + PI, t * 1.5 + PI + 1.15, 10, bcol, 1.0)


static func draw_shield_arc(enemy: LxEnemyBrain, off: Vector2, base_col: Color) -> void:
	if enemy == null:
		return
	var pal: Dictionary = LxEnemyBrain.PAL
	var r: float = enemy.body_radius
	var rad: float = r + 3.0
	var sh_v: Variant = enemy.get("shield_hp")
	var sm_v: Variant = enemy.get("shield_max")
	var sfrac: float = 1.0
	if (sh_v is float or sh_v is int) and (sm_v is float or sm_v is int) and float(sm_v) > 0.01:
		sfrac = clampf(float(sh_v) / float(sm_v), 0.0, 1.0)

	var fred: bool = _flash_reduced()
	var col: Color = base_col
	if enemy.clank_t > 0.0:
		col = pal["cream"] as Color
	elif sfrac <= 0.45:
		if fred:
			col = pal["apricot"] as Color
		else:
			col = (pal["coral"] if int(enemy.anim_t * 10.0) % 2 == 0 else pal["apricot"]) as Color

	enemy.draw_arc(off, rad, enemy.facing - 1.05, enemy.facing + 1.05, 12, col, 2.5)

	# Visible hairline fractures across the shield as it wears down
	if sfrac <= 0.65:
		var a0: float = enemy.facing - 0.25
		var p_in: Vector2 = (off + Vector2.from_angle(a0) * (rad - 1.5)).round()
		var p_out: Vector2 = (off + Vector2.from_angle(a0) * (rad + 2.0)).round()
		enemy.draw_line(p_in, p_out, pal["night"] as Color, 1.0)
		enemy.draw_rect(Rect2(p_out, Vector2.ONE), pal["gold"] as Color)
	if sfrac <= 0.45:
		var a1: float = enemy.facing + 0.42
		var q_in: Vector2 = (off + Vector2.from_angle(a1) * (rad - 1.5)).round()
		var q_out: Vector2 = (off + Vector2.from_angle(a1) * (rad + 2.5)).round()
		enemy.draw_line(q_in, q_out, pal["void"] as Color, 1.0)
		enemy.draw_rect(Rect2(q_out, Vector2.ONE), pal["cream"] as Color)


static func trigger_boss_awaken(boss: LxEnemyBrain) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_alive():
		return
	if boss.has_meta("_lx_awakened"):
		return
	boss.set_meta("_lx_awakened", true)
	boss.awaken_t = 0.55
	if Lx.camera != null and is_instance_valid(Lx.camera):
		if Lx.camera.has_method("trigger_focus_nudge"):
			Lx.camera.call("trigger_focus_nudge", boss.pos, 0.55)
		Lx.camera.add_shake(0.20)
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", boss.pos, 96.0, 95.0)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(boss.pos, 72.0, 1.35, 0.55)
		LxDarknessLayer.active_instance.trigger_focus_flash(0.45)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("boss_awaken", boss.pos, true)


static func trigger_boss_phase_burst(boss_id: String, at_pos: Vector2) -> void:
	gust_arena(at_pos, 118.0, 125.0)
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_enemies"):
		return
	var enemies: Variant = Lx.world.call("get_enemies")
	if not (enemies is Array):
		return
	for e: Variant in (enemies as Array):
		if e is LxEnemyBrain and is_instance_valid(e):
			var b: LxEnemyBrain = e as LxEnemyBrain
			if b.is_alive() and (b.boss_id == boss_id or b.kind == boss_id or b.is_boss):
				b.awaken_t = 0.55
				break


static func gust_arena(at_pos: Vector2, radius: float, strength: float) -> void:
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", at_pos, radius, strength)
