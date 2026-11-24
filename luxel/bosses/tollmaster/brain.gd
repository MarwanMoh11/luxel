class_name LxTollmasterBoss
extends LxBossBase
## Island 8 Boss: The Tollmaster (The Toll House, toll_r11).
## Tall plum-velvet ledger-wraith with brass-scale crown, monocle, iron Lectern Shield,
## and destructible Brass Register. At P2 (66%) & P3 (33%) issues a mid-fight INVOICE:
##  - Guarded LxSold / Lx.vars integration: if sold_count >= 12 -> OVERPAID auto-stagger!
##  - Otherwise raises a destructible Brass Register for 8.0s: pay a setting (via LxSold
##    when present) for full heal + surge OR smash the Brass Register in 8.0s for a huge
##    2.4s bankruptcy stagger & popped monocle (ignoring 8s summons 1-2 toll_clerks!).
## P3 drops corner floor scales into lethal pits (auto-rollback on reset_encounter).

const SLAM_R: float = 48.0
const REGISTER_HP: float = 4.5
const INVOICE_DURATION: float = 8.0
const BANKRUPT_STAGGER: float = 2.40

var _slam_dir: Vector2 = Vector2.LEFT
var _slam_hit: bool = false
var _tilt_left: bool = true
var _invoice_active: bool = false
var _invoice_timer: float = 0.0
var _invoice_sold_snap: int = 0
var _invoices_refused: int = 0
var _monocle_popped_t: float = 0.0
var _surge_t: float = 0.0
var _register_id: String = ""


func _init() -> void:
	super._init()
	kind = "tollmaster"
	boss_id = "tollmaster"
	boss_name_key = "ISL8_BOSS_TOLLMASTER"
	island_id = 8
	is_miniboss = false
	reward_heart = "half"
	music_cue = "island8_boss_p1"
	music_p2_cue = "island8_boss_p2"
	max_hp = 215.0
	hp = 215.0
	body_radius = 12.5
	move_speed = 40.0
	stagger_threshold = 22.0
	stagger_duration = 1.95
	post_stagger_immunity = 4.0
	punish_dmg_mult = 1.38
	post_recover_cd = 0.30
	intro_duration = 0.65
	phase_shift_duration = 0.80
	death_duration = 2.4
	shard_drop = 45


func _configure_boss(_spec: Dictionary) -> void:
	configure_phases([0.66, 0.33])

	# Attack 1: Ledger Slam Arc (tell 0.54s, commit 0.24s, recover 1.15s)
	register_attack("ledger_slam_arc", {
		"weight": 1.25, "tell": 0.54, "commit": 0.24, "recover": 1.15, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			_slam_dir = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = _slam_dir.angle()
			_slam_hit = false
			ground.warn_sector(pos, facing - 1.22, facing + 1.22, SLAM_R, last_tell_duration, 0.0, "coral", "gold")
			ground.warn_lane(pos, clamp_to_arena(pos + _slam_dir * 140.0), 9.0, last_tell_duration, 0.0, "gold", "cream")
			stage.play_sfx("invoice_stamp", pos),
		"on_commit_start": func(_b: LxBossBase, _tgt: Vector2) -> void:
			patterns.emit_fan(pos, _slam_dir, 5 if phase >= 2 else 3, 0.82, 144.0 if phase >= 2 else 128.0, {"color": "gold", "source": "ledger_wave"})
			stage.shake(0.18)
			stage.play_sfx("warden_swing", pos),
		"on_commit": func(_b: LxBossBase, tgt: Vector2, dt: float, _el: float) -> void:
			move_boss(_slam_dir * 115.0 * dt, true)
			if not _slam_hit and pos.distance_to(tgt) <= SLAM_R:
				var rel: Vector2 = tgt - pos
				if rel.length() < 1.0 or absf(angle_difference(facing, rel.angle())) <= 1.28:
					_slam_hit = true
					emit_boss_damage(_slam_dir, 1.0, "ledger_slam", pos, true),
	})

	# Attack 2: Coin-Slot Barrage (tell 0.52s, commit 0.32s, recover 1.10s)
	register_attack("coin_slot_barrage", {
		"weight": 1.25, "tell": 0.52, "commit": 0.32, "recover": 1.10, "cooldown": 1.5,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = aim.angle()
			ground.warn_lane(pos, clamp_to_arena(pos + aim * 155.0), 12.0, last_tell_duration, 0.0, "gold", "coral")
			var drops: Array[Vector2] = [clamp_to_arena(tgt), clamp_to_arena(tgt.lerp(arena_rect.get_center(), 0.45))]
			patterns.emit_rain(ground, drops, last_tell_duration + 0.06, 20.0, 1.0, "gold", "coral")
			stage.play_sfx("register_chime", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			var n: int = 7 if phase >= 3 else 5
			patterns.emit_fan(pos, aim, n, 1.05, 148.0 if phase >= 2 else 132.0, {"color": "gold", "source": "coin_barrage"})
			stage.shake(0.14)
			stage.play_sfx("register_chime", pos),
	})

	# Attack 3: Scale Tilt Wave (tell 0.60s, commit 0.36s, recover 1.25s)
	register_attack("scale_tilt_wave", {
		"weight": 1.15, "tell": 0.60, "commit": 0.36, "recover": 1.25, "cooldown": 1.8,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var c: Vector2 = arena_rect.get_center()
			# Tilt whichever half Wick currently stands on so they cross to the raised safe half!
			_tilt_left = tgt.x <= c.x
			var half_w: float = arena_rect.size.x * 0.48
			var rx: float = arena_rect.position.x if _tilt_left else (c.x + 4.0)
			var danger_r := Rect2(rx, arena_rect.position.y + 4.0, half_w, arena_rect.size.y - 8.0)
			ground.warn_rect(danger_r, last_tell_duration, 1.0, "coral", "gold", 0.30)
			stage.play_sfx("invoice_stamp", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_gap_ring(pos, 10 if phase >= 2 else 8, 126.0, aim_a + 0.55, 0.72, {"color": "apricot", "source": "scale_tilt"})
			stage.shake(0.22)
			stage.play_sfx("bell_slam", pos),
	})

	# Attack 4: Foreclosure Sweep (P2 & P3, sweeping golden foreclosure beam!)
	register_attack("foreclosure_sweep", {
		"phases": [2, 3], "weight": 2.10, "tell": 0.62, "commit": 0.45, "recover": 1.35, "cooldown": 1.4,
		"on_tell_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim: Vector2 = (tgt - pos).normalized() if tgt.distance_to(pos) > 1.0 else Vector2.from_angle(facing)
			facing = aim.angle()
			var p1: Vector2 = clamp_to_arena(pos + aim.rotated(-0.30) * 148.0)
			var p2: Vector2 = clamp_to_arena(pos + aim.rotated(0.30) * 148.0)
			patterns.emit_chain_lightning([pos, p1], last_tell_duration, 8.0, 0.34, 1.0)
			patterns.emit_chain_lightning([pos, p2], last_tell_duration + 0.08, 8.0, 0.34, 1.0)
			ground.warn_lane(pos, clamp_to_arena(pos + aim * 155.0), 10.0, last_tell_duration, 0.0, "coral", "cream")
			stage.play_sfx("beam_charge", pos),
		"on_commit_start": func(_b: LxBossBase, tgt: Vector2) -> void:
			var aim_a: float = (tgt - pos).angle() if tgt.distance_to(pos) > 1.0 else facing
			patterns.emit_spiral(pos, 3, 134.0, aim_a, 0.48, 3 if phase >= 3 else 2, 0.14, {"color": "coral", "source": "foreclosure"})
			stage.shake(0.22)
			stage.play_sfx("beam_fire", pos),
	})


func _on_reset_encounter() -> void:
	_slam_hit = false
	_tilt_left = true
	_invoice_active = false
	_invoice_timer = 0.0
	_invoice_sold_snap = _get_sold_count()
	_invoices_refused = 0
	_monocle_popped_t = 0.0
	_surge_t = 0.0
	_register_id = ""


func _get_sold_count() -> int:
	# Guarded LxSold integration: safely works whether T8's LxSold is present or absent!
	if ResourceLoader.exists("res://luxel/islands/8/sold.gd"):
		var sc: Variant = ResourceLoader.load("res://luxel/islands/8/sold.gd")
		if sc is GDScript and (sc as GDScript).has_method("sold_count"):
			return int((sc as GDScript).call("sold_count"))
	if Lx.vars != null:
		return int(Lx.vars.get_var("island:8", "sold_count", 0))
	return 0


func _emit_narr(string_id: String, style: String = "narration", dur: float = 2.6) -> void:
	if Lx.events != null and LxStrings.has_id(string_id):
		Lx.events.narration_requested.emit(string_id, style, dur)


func _on_phase_enter(new_phase: int) -> void:
	var c: Vector2 = arena_rect.get_center()
	if new_phase == 2:
		_trigger_invoice(1)
		stage.darkness_pulse(0.60, 1.0)
		stage.shake(0.24)
		stage.play_sfx("invoice_stamp", pos)
	elif new_phase == 3:
		# P3 Arena Change: corner floor scales drop into lethal pits (rolled back on reset!)
		var cx_t: int = int(c.x / 16.0)
		var cy_t: int = int(c.y / 16.0)
		stage.set_tiles(world_ctx, Rect2i(maxi(2, cx_t - 6), maxi(2, cy_t - 3), 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(cx_t + 5, maxi(2, cy_t - 3), 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(maxi(2, cx_t - 6), cy_t + 3, 1, 1), "pit")
		stage.set_tiles(world_ctx, Rect2i(cx_t + 5, cy_t + 3, 1, 1), "pit")
		_trigger_invoice(2)
		stage.darkness_pulse(0.72, 1.2)
		stage.shake(0.28)
		stage.play_sfx("invoice_stamp", pos)


func _trigger_invoice(num: int) -> void:
	var sold_now: int = _get_sold_count()
	# Bible 11.3 #8: if 12/12 settings already sold -> auto-stagger OVERPAID!
	if sold_now >= 12:
		_invoice_active = false
		_emit_narr("ISL8_OVERPAID", "title", 2.8)
		_trigger_bankruptcy_stagger(0.0)
		return
	_invoice_active = true
	_invoice_timer = INVOICE_DURATION
	_invoice_sold_snap = sold_now
	_emit_narr("ISL8_INVOICE", "title", 2.8)
	# Spawn destructible Brass Register at north-center counter!
	var reg_pos: Vector2 = Vector2(arena_rect.get_center().x, arena_rect.position.y + 24.0)
	_register_id = "brass_register_%d" % num
	var p: Dictionary = props.spawn_crate(reg_pos, REGISTER_HP, _register_id)
	p["color"] = "gold"
	p["radius"] = 11.0
	p["on_break"] = func(_prop: Dictionary) -> void:
		_on_register_smashed()


func _on_register_smashed() -> void:
	if not _invoice_active:
		return
	_invoice_active = false
	_invoices_refused += 1
	_monocle_popped_t = 3.2
	stage.play_sfx("register_shatter", pos)
	if _invoices_refused >= 2:
		_emit_narr("ISL8_TAX_EVASION", "title", 2.8)
	else:
		_emit_narr("ISL8_TAX_EVADE", "title", 2.6)
	_trigger_bankruptcy_stagger(3.5)


func _trigger_bankruptcy_stagger(bonus_dmg: float) -> void:
	if bonus_dmg > 0.0 and hp > bonus_dmg + 1.0:
		hp -= bonus_dmg
	_release_token()
	active_attack_id = ""
	stagger_meter = 0.0
	_set_boss_state(BossState.STAGGER, BANKRUPT_STAGGER)
	staggered.emit(BANKRUPT_STAGGER)
	stage.shake(0.26)
	LxDamageFx.boss_impact(pos, 0.22, 86.0, 92.0, 88.0, 1.42, 0.34)


func _on_boss_tick(dt: float, _target: Vector2) -> void:
	_monocle_popped_t = maxf(0.0, _monocle_popped_t - dt)
	_surge_t = maxf(0.0, _surge_t - dt)
	if _invoice_active:
		# Check if player paid a voluntary setting mid-fight via LxSold / Lx.vars!
		if _get_sold_count() > _invoice_sold_snap:
			_invoice_active = false
			_surge_t = 12.0
			if Lx.state != null:
				Lx.state.hearts = float(Lx.state.max_hearts)
			stage.play_sfx("register_chime", pos)
			var rp: Dictionary = props.get_prop(_register_id)
			if not rp.is_empty():
				rp["state"] = "broken"; rp["solid"] = false
			return
		# Also allow Beam/Throw/Sunflare to smash the Brass Register quickly!
		var reg: Dictionary = props.get_prop(_register_id)
		if not reg.is_empty() and str(reg["state"]) == "idle":
			var reg_p: Vector2 = reg["pos"] as Vector2
			var wick_n: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
			if wick_n != null and wick_n.move_beam != null and wick_n.move_beam.beam_vis_t > 0.0:
				if Geometry2D.get_closest_point_to_segment(reg_p, wick_n.move_beam.beam_start, wick_n.move_beam.beam_end).distance_to(reg_p) <= 14.0:
					props._damage_prop(reg, 6.0 * dt)
		_invoice_timer -= dt
		if _invoice_timer <= 0.0:
			_invoice_active = false
			var reg2: Dictionary = props.get_prop(_register_id)
			if not reg2.is_empty():
				reg2["state"] = "broken"; reg2["solid"] = false
			# Fair punishment for ignoring Invoice 8s: summons 1-2 toll_clerks!
			var c: Vector2 = arena_rect.get_center()
			adds.queue_wave([{"kind": "toll_clerk", "pos": clamp_to_arena(c + Vector2(-52.0, -24.0))}], 0.70, 2)
			stage.play_sfx("invoice_stamp", pos)


func _modify_incoming_damage(hit: LxHit, dmg: float) -> float:
	if hit == null:
		return dmg
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var orig: Vector2 = h["origin"] as Vector2
	var rel: Vector2 = orig - pos
	var from_front: bool = rel.length() > 1.0 and absf(angle_difference(facing, rel.angle())) < 0.95
	var bypass: bool = bool(h["pierce"]) or bool(h["cracks_armour"]) or src == LxHit.SOURCE_PRISM or src == LxHit.SOURCE_BEAM or src == LxHit.SOURCE_THROW or src == LxHit.SOURCE_SUNFLARE
	var out_dmg: float = dmg * (1.35 if _surge_t > 0.0 else 1.0)
	# Front iron Lectern Shield reduces raw frontal bolts unless flanked/Prism/Beam/punishable!
	if from_front and not bypass and not is_punishable():
		clank_t = 0.10
		stage.play_sfx("warden_clank", pos)
		return out_dmg * 0.62
	return out_dmg


func _on_death_start() -> void:
	_invoice_active = false
	stage.shake(0.28)
	stage.play_sfx("register_chime", pos)


func _body_color() -> Color:
	return (PAL["plum"] if phase == 1 else (PAL["wine"] if phase == 2 else PAL["coral"])) as Color


func _draw_boss_extra(off: Vector2) -> void:
	var c: Vector2 = off.round()
	# Lectern Shield front arc when active
	if not is_punishable() and boss_state != BossState.DEATH:
		draw_arc(c, body_radius + 4.5, facing - 0.95, facing + 0.95, 14, PAL["gold"] as Color, 2.2)
	# Active Invoice countdown ring over Brass Register!
	if _invoice_active:
		var reg: Dictionary = props.get_prop(_register_id)
		if not reg.is_empty() and str(reg["state"]) == "idle":
			var rp: Vector2 = ((reg["pos"] as Vector2) - pos).round()
			var frac: float = clampf(_invoice_timer / INVOICE_DURATION, 0.0, 1.0)
			draw_arc(rp, 16.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, PAL["gold"] as Color, 2.2)
			draw_rect(Rect2(rp + Vector2(-5.0, -6.0), Vector2(10.0, 8.0)), PAL["gold"] as Color)
			draw_rect(Rect2(rp + Vector2(-3.0, -4.0), Vector2(6.0, 4.0)), PAL["coral"] as Color)
	# Popped monocle comedy cue!
	if _monocle_popped_t > 0.0:
		var mp: Vector2 = (c + Vector2(15.0, -body_radius - 14.0 + sin(anim_t * 6.0) * 2.0)).round()
		draw_arc(mp, 3.5, 0.0, TAU, 12, PAL["gold"] as Color, 1.4)
