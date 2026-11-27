class_name LxStairBoonRuntime
extends Node2D
## Island 8 Endless Stair Live 18-Boon Gameplay & Visual Runtime.
## Mounted by LxStairDirector while Wick climbs Endless Stair so every drafted
## boon visibly changes combat, movement, lantern play, and feedback in real time.

const PAL: Dictionary = LxPalette.PAL

var _dir: LxStairDirector = null
var _wick: LxWick = null
var _bolt_count: int = 0
var _hot_hook_t: float = 0.0
var _step_spark_t: float = 0.0
var _last_flares: int = 0
var _last_zips: int = 0
var _was_dashing: bool = false
var _zip_shield_t: float = 0.0
var _sun_echo_pending: Array[Dictionary] = [] # [{t, pos}]
var _pulse_rings: Array[Dictionary] = [] # [{pos, r0, r1, t, dur, col}]
var _clock: float = 0.0
var _events_bound: bool = false
var _hud_layer: CanvasLayer = null
var _hud_draw: Node2D = null


func _ready() -> void:
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mount_hud()
	_bind_events()
	_bind_wick()


func _exit_tree() -> void:
	_unbind_wick()
	_unbind_events()
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	_hud_layer = null
	_hud_draw = null


func bind_director(director: LxStairDirector) -> void:
	_dir = director
	_bind_events()
	_bind_wick()
	if _hud_draw != null and is_instance_valid(_hud_draw):
		_hud_draw.queue_redraw()


func on_boon_granted(boon_id: String, meta: Dictionary) -> void:
	_bind_wick()
	if _wick != null and is_instance_valid(_wick):
		var grp: String = str(meta.get("group", "WICK"))
		var col: Color = PAL["gold"] as Color if grp == "TOLL" else (PAL["sky"] as Color if grp == "LANTERN" else PAL["lime"] as Color)
		if boon_id == "boon_crowned_toll":
			col = PAL["cream"] as Color
		_add_ring(_wick.global_position, 4.0, 28.0, 0.36, col)
		_wick.spawn_sparks(_wick.global_position, Vector2.UP, 10, col, 32.0, 96.0, 0.28)
	if _hud_draw != null and is_instance_valid(_hud_draw):
		_hud_draw.queue_redraw()


func on_last_breath_triggered() -> void:
	_bind_wick()
	if _wick == null or not is_instance_valid(_wick):
		return
	var origin: Vector2 = _wick.global_position
	_wick.mercy_t = maxf(_wick.mercy_t, 1.65)
	_add_ring(origin, 6.0, 64.0, 0.42, PAL["gold"] as Color)
	_wick.spawn_sparks(origin, Vector2.UP, 14, PAL["cream"] as Color, 45.0, 120.0, 0.34)
	_damage_enemies_in_radius(origin, 64.0, 1.8, true, LxHit.SOURCE_SUNFLARE)
	if Lx.events != null and LxStrings.has_id("ISL8_BOON_LAST_BREATH"):
		Lx.events.narration_requested.emit("ISL8_BOON_LAST_BREATH", "title", 2.2)


func _process(dt: float) -> void:
	if _dir == null or not _dir.is_in_stair():
		visible = false
		if _hud_draw != null and is_instance_valid(_hud_draw):
			_hud_draw.visible = false
		return
	visible = true
	_clock += dt
	_bind_wick()
	_tick_boons(dt)
	_tick_rings(dt)
	queue_redraw()
	if _hud_draw != null and is_instance_valid(_hud_draw):
		_hud_draw.visible = _should_show_hud()
		if _hud_draw.visible:
			_hud_draw.queue_redraw()


func _tick_boons(dt: float) -> void:
	if _wick == null or not is_instance_valid(_wick) or _dir == null:
		return
	var w: LxWick = _wick
	var crowned: bool = _dir.has_boon("boon_crowned_toll")

	# 1. Quick Step / Crowned Toll: visible lime/gold boot sparks while moving
	if (_dir.has_boon("boon_quick_step") or crowned) and w.velocity.length() > 24.0:
		_step_spark_t -= dt
		if _step_spark_t <= 0.0:
			_step_spark_t = 0.14 if crowned else 0.18
			var scol: Color = PAL["gold"] as Color if crowned else PAL["lime"] as Color
			w.spawn_sparks(w.global_position + Vector2(0.0, 4.0), -w.velocity.normalized(), 2, scol, 14.0, 36.0, 0.16)

	# 2. Hot Hook: hung lantern pulses fiery scorch rings damaging nearby foes
	if _dir.has_boon("boon_hot_hook") and w.lantern != null and w.lantern.is_hanging():
		_hot_hook_t -= dt
		if _hot_hook_t <= 0.0:
			_hot_hook_t = 0.85 if crowned else 0.95
			var rad: float = 58.0 if crowned else 48.0
			var dmg: float = 0.95 if crowned else 0.75
			_add_ring(w.lantern.pos, 4.0, rad, 0.30, PAL["coral"] as Color)
			_damage_enemies_in_radius(w.lantern.pos, rad, dmg, false, LxHit.SOURCE_THROW)
			w.spawn_sparks(w.lantern.pos, Vector2.UP, 6, PAL["apricot"] as Color, 24.0, 68.0, 0.22)
	else:
		_hot_hook_t = minf(_hot_hook_t, 0.25)

	# 3. Magnet Catch: wider catch pull & +5 Ember burst on recalling lantern
	if _dir.has_boon("boon_magnet_catch") and w.lantern != null:
		if w.lantern.state == LxLantern.State.RECALLING:
			var d_cat: float = w.lantern.pos.distance_to(w.global_position)
			if d_cat <= 32.0 and d_cat > 2.0:
				w.lantern.catch_by_wick(w)
				w.ember = minf(100.0, w.ember + 5.0)
				_add_ring(w.global_position, 3.0, 18.0, 0.22, PAL["sky"] as Color)

	# 4. Wide Lens: expands active True Lens reveal radius by +35%
	if _dir.has_boon("boon_wide_lens") and w.move_lens != null:
		if w.move_lens.is_pulse_active() and w.move_lens.pulse_radius < 136.0:
			w.move_lens.pulse_radius = 140.0
			w.move_lens.hung_radius = 105.0
			if Lx.world != null and is_instance_valid(Lx.world):
				w.move_lens.register_circle(Lx.world)
				_add_ring(w.global_position, 18.0, 140.0, 0.30, PAL["ice"] as Color)

	# 5. Sun Echo: schedules a 2nd golden Sunflare pulse 0.65s after every Sunflare
	if w.move_sunflare != null:
		var fc: int = w.move_sunflare.flares_fired
		if fc > _last_flares:
			_last_flares = fc
			if _dir.has_boon("boon_sun_echo"):
				_sun_echo_pending.append({"t": 0.65, "pos": w.move_sunflare.flare_origin})
	for i: int in range(_sun_echo_pending.size() - 1, -1, -1):
		var ev: Dictionary = _sun_echo_pending[i]
		ev["t"] = float(ev["t"]) - dt
		if float(ev["t"]) <= 0.0:
			var ep: Vector2 = ev["pos"] as Vector2
			_sun_echo_pending.remove_at(i)
			var erad: float = 78.0 if crowned else 68.0
			var edmg: float = 2.6 if crowned else 2.1
			_add_ring(ep, 6.0, erad, 0.36, PAL["gold"] as Color)
			_add_ring(ep, 2.0, erad * 0.72, 0.28, PAL["cream"] as Color)
			_damage_enemies_in_radius(ep, erad, edmg, true, LxHit.SOURCE_SUNFLARE)
			w.emit_sfx("sunflare_burst", ep, true)

	# 6. Zip Shield: brief golden guard aura after every Light Zip
	if w.zips_count > _last_zips:
		_last_zips = w.zips_count
		if _dir.has_boon("boon_zip_shield"):
			_zip_shield_t = 1.45
			w.mercy_t = maxf(w.mercy_t, 1.05)
			_add_ring(w.global_position, 4.0, 22.0, 0.28, PAL["gold"] as Color)
	if _zip_shield_t > 0.0:
		_zip_shield_t = maxf(0.0, _zip_shield_t - dt)

	# 7. Frame Blink: -20% dash cooldown when fps_step is sold
	var dashing: bool = w.is_dashing()
	if dashing and not _was_dashing:
		if _dir.has_boon("boon_frame_blink") and LxSold.current().is_sold("fps_step") and w.move_dash != null:
			w.move_dash.cooldown_left *= 0.80
			_add_ring(w.global_position, 2.0, 15.0, 0.18, PAL["ice"] as Color)
	_was_dashing = dashing

	# 8. Hide defeated bosses once defeated (hp <= 0 or boss_state == DEATH(5) or is_dead)
	#    so LxStairController._live_enemy_count() cleanly enters BOON_DRAFT on F4/F8 Warden defeat.
	_hide_defeated_bosses()


func _on_wick_fired(dir: Vector2, kind: String) -> void:
	if _dir == null or not _dir.is_in_stair() or _wick == null or not is_instance_valid(_wick):
		return
	var w: LxWick = _wick
	var crowned: bool = _dir.has_boon("boon_crowned_toll")

	if kind == "bolt":
		_bolt_count += 1
		# Prism Arc: +1 extra Prism bounce on every bolt
		if _dir.has_boon("boon_prism_arc") and not w.bolts.is_empty():
			var last_b: Variant = w.bolts[w.bolts.size() - 1]
			if last_b is LxMoveBolt.Bolt:
				(last_b as LxMoveBolt.Bolt).bounces_left += 1
				_add_ring(w.global_position + dir * 6.0, 2.0, 10.0, 0.14, PAL["sky"] as Color)
		# Twin Spark: every 4th bolt (or 3rd with Crowned Toll) fires a real manual-aim twin bolt!
		var cadence: int = 3 if crowned else 4
		if _dir.has_boon("boon_twin_spark") and (_bolt_count % cadence == 0) and not w.bolts.is_empty():
			var src_v: Variant = w.bolts[w.bolts.size() - 1]
			if src_v is LxMoveBolt.Bolt:
				var src: LxMoveBolt.Bolt = src_v as LxMoveBolt.Bolt
				var perp: Vector2 = Vector2(-dir.y, dir.x)
				var twin := LxMoveBolt.Bolt.new()
				twin.dir = dir.rotated(0.11).normalized()
				twin.pos = src.pos + perp * 4.5
				twin.prev_pos = twin.pos
				twin.speed = src.speed
				twin.base_speed = src.base_speed
				twin.max_range = src.max_range
				twin.damage = src.damage * 0.72
				twin.shield_wear = src.shield_wear * 0.8
				twin.bounces_left = src.bounces_left
				twin.light_color = src.light_color
				twin.biome_tint = "gold"
				w.bolts.append(twin)
				src.pos -= perp * 3.0
				_add_ring(w.global_position + dir * 7.0, 2.0, 13.0, 0.16, PAL["cream"] as Color)

	elif kind == "throw":
		# Long Throw: +30% lantern throw range
		if _dir.has_boon("boon_long_throw") and w.lantern != null:
			w.lantern.max_range *= 1.30
			_add_ring(w.global_position, 3.0, 16.0, 0.20, PAL["sky"] as Color)


func _on_enemy_hit(enemy: Object, hit: Object, result: int) -> void:
	if _dir == null or not _dir.is_in_stair() or _wick == null or not is_instance_valid(_wick):
		return
	var epos: Vector2 = _wick.get_entity_pos(enemy) if enemy != null and is_instance_valid(enemy) else _wick.global_position
	var hdir: Vector2 = hit.get("dir") as Vector2 if (hit != null and hit.get("dir") is Vector2) else Vector2.UP

	# Ember Sip: +25% bonus Ember gain on hits & kills
	if _dir.has_boon("boon_ember_sip"):
		var bonus_e: float = 5.0 if result == LxEnemyBrain.HitResult.KILLED else 1.8
		_wick.ember = minf(100.0, _wick.ember + bonus_e)
		_wick.spawn_sparks(epos, (_wick.global_position - epos).normalized(), 3, PAL["gold"] as Color, 40.0, 90.0, 0.18)

	# Glass Edge: crisp ice shard pop
	if _dir.has_boon("boon_glass_edge"):
		_wick.spawn_sparks(epos, hdir, 4, PAL["ice"] as Color, 32.0, 82.0, 0.18)

	# Heavy Ledger: brass coin burst scaling with toll_weight
	if _dir.has_boon("boon_heavy_ledger"):
		var tw: int = LxSold.current().get_toll_weight()
		if tw > 0:
			_wick.spawn_sparks(epos, Vector2.UP, mini(8, 2 + tw), PAL["apricot"] as Color, 28.0, 74.0, 0.20)

	# Silent Blade: crisp cream slash arc when sound_off sold
	if _dir.has_boon("boon_silent_blade") and LxSold.current().is_sold("sound_off"):
		_add_ring(epos, 2.0, 14.0, 0.16, PAL["cream"] as Color)

	# Greyscale Crit: apricot/cream burst on opened hit when palette_4 sold
	if _dir.has_boon("boon_grey_crit") and LxSold.current().is_sold("palette_4") and result == LxEnemyBrain.HitResult.OPENED:
		_add_ring(epos, 3.0, 18.0, 0.22, PAL["apricot"] as Color)
		if hit != null and hit.get("damage") != null and enemy != null and is_instance_valid(enemy) and enemy.get("hp") != null:
			enemy.set("hp", maxf(0.0, float(enemy.get("hp")) - float(hit.get("damage")) * 0.35))


func _damage_enemies_in_radius(origin: Vector2, rad: float, dmg: float, cracks: bool, source: String) -> void:
	if _wick == null or not is_instance_valid(_wick) or Lx.world == null or not is_instance_valid(Lx.world):
		return
	var enemies: Array = _wick.world_get_enemies(Lx.world)
	for ev: Variant in enemies:
		if not (ev is Object) or not is_instance_valid(ev as Object):
			continue
		var en: Object = ev as Object
		if not _wick.is_entity_alive(en):
			continue
		var ep: Vector2 = _wick.get_entity_pos(en)
		var er: float = _wick.get_entity_radius(en, 8.0)
		if ep.distance_to(origin) <= rad + er:
			var d: Vector2 = (ep - origin).normalized() if ep.distance_to(origin) > 0.1 else Vector2.UP
			var h: LxHit = LxHit.make(source, dmg, d, origin, 1.5 if cracks else 0.4, cracks, cracks, _wick, cracks)
			_wick.apply_hit_to_entity(en, h)


func _add_ring(p: Vector2, r0: float, r1: float, dur: float, col: Color) -> void:
	_pulse_rings.append({"pos": p, "r0": r0, "r1": r1, "t": dur, "dur": dur, "col": col})


func _tick_rings(dt: float) -> void:
	for i: int in range(_pulse_rings.size() - 1, -1, -1):
		var r: Dictionary = _pulse_rings[i]
		r["t"] = float(r["t"]) - dt
		if float(r["t"]) <= 0.0:
			_pulse_rings.remove_at(i)


func _draw() -> void:
	if _dir == null or not _dir.is_in_stair():
		return
	var fred: bool = LxHudFx.flash_reduced()
	# Expanding boon pulse rings in world space
	for r: Dictionary in _pulse_rings:
		var dur: float = maxf(0.01, float(r["dur"]))
		var u: float = 1.0 - clampf(float(r["t"]) / dur, 0.0, 1.0)
		var rad: float = roundf(lerpf(float(r["r0"]), float(r["r1"]), u))
		var col: Color = r["col"] as Color
		var alpha: float = (1.0 - u) * (0.48 if fred else 0.90)
		draw_arc((r["pos"] as Vector2).round(), rad, 0.0, TAU, 20, Color(col, alpha), 1.0)

	if _wick == null or not is_instance_valid(_wick) or _wick.dead:
		return
	var wp: Vector2 = _wick.global_position.round()

	# Orbiting golden Crowned Toll motes (steady cardinal halo under flash_reduced)
	if _dir.has_boon("boon_crowned_toll"):
		var base_a: float = 0.0 if fred else (_clock * 2.4)
		for k: int in range(4):
			var a: float = base_a + float(k) * (TAU * 0.25)
			var mp: Vector2 = (wp + Vector2(cos(a) * 12.0, sin(a) * 8.0 - 4.0)).round()
			draw_rect(Rect2(mp - Vector2.ONE, Vector2(2.0, 2.0)), PAL["gold"] as Color)
			draw_rect(Rect2(mp, Vector2.ONE), PAL["cream"] as Color)

	# Armed Last Breath halo pip (steady crown pip under flash_reduced)
	if _dir.is_last_breath_armed():
		var la: float = -PI * 0.5 if fred else (-_clock * 1.8)
		var lp: Vector2 = (wp + Vector2(cos(la) * 10.0, sin(la) * 6.0 - 9.0)).round()
		draw_rect(Rect2(lp - Vector2.ONE, Vector2(3.0, 3.0)), PAL["void"] as Color)
		draw_rect(Rect2(lp, Vector2(1.0, 1.0)), PAL["cream"] as Color)

	# Active Zip Shield ring (cardinal ticks for greyscale legibility + calm alpha under flash_reduced)
	if _zip_shield_t > 0.0:
		var sa: float = clampf(_zip_shield_t / 1.45, 0.25, 0.55 if fred else 0.90)
		var sc: Vector2 = wp + Vector2(0.0, -3.0)
		draw_arc(sc, 11.0, 0.0, TAU, 16, Color(PAL["gold"] as Color, sa), 1.0)
		for tick_off: Vector2 in [Vector2(-11.0, 0.0), Vector2(11.0, 0.0), Vector2(0.0, -11.0), Vector2(0.0, 11.0)]:
			draw_rect(Rect2((sc + tick_off).round(), Vector2.ONE), Color(PAL["cream"] as Color, sa))


func _mount_hud() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "StairBoonHudLayer"
	_hud_layer.layer = 11
	host.add_child(_hud_layer)
	_hud_draw = Node2D.new()
	_hud_draw.name = "StairBoonHudDraw"
	_hud_draw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hud_draw.draw.connect(_draw_hud)
	_hud_layer.add_child(_hud_draw)


func _should_show_hud() -> bool:
	if _dir == null or not _dir.is_in_stair():
		return false
	if Lx.root != null and is_instance_valid(Lx.root) and int(Lx.root.get("flow")) == 0:
		return false
	return true


func _draw_hud() -> void:
	if _hud_draw == null or not _should_show_hud():
		return
	var c: Node2D = _hud_draw
	var boons: PackedStringArray = _dir.get_boons()
	var sc: Dictionary = _dir.compute_score(_dir.get_floor(), LxSold.current().get_sold_count(), _dir.get_run_deaths())
	var mult_s: String = "%.2f" % float(sc.get("multiplier", 1.0))
	var tag: String = "IRON %d x%s" % [int(sc.get("score", 0)), mult_s]
	if boons.size() > 0:
		tag = "B:%d  SCORE:%d x%s" % [boons.size(), int(sc.get("score", 0)), mult_s]
	var w_px: float = float(LxPixelFont.width(tag, 1)) + 8.0
	var bx: float = roundf(315.0 - w_px)
	var by: float = 146.0
	c.draw_rect(Rect2(bx, by, w_px, 11.0), PAL["void"] as Color)
	c.draw_rect(Rect2(bx + 1.0, by + 1.0, w_px - 2.0, 9.0), PAL["night"] as Color)
	c.draw_rect(Rect2(bx + 1.0, by + 1.0, 1.0, 9.0), PAL["rose"] as Color if _dir.is_iron_ascent() else PAL["gold"] as Color)
	LxPixelFont.draw(c, tag, Vector2(bx + 4.0, by + 3.0), PAL["cream"] as Color, 1, PAL["void"] as Color)

	# Active boon pips stacked cleanly above the Iron Ascent score bar (greyscale-distinct shapes)
	if not boons.is_empty():
		var px: float = 312.0
		var py: float = 139.0
		for i: int in range(boons.size() - 1, -1, -1):
			var meta: Dictionary = _dir.get_boon_meta(boons[i])
			var grp: String = str(meta.get("group", "WICK"))
			var is_crown: bool = (boons[i] == "boon_crowned_toll")
			var col: Color = PAL["cream"] as Color if is_crown else (PAL["gold"] as Color if grp == "TOLL" else (PAL["sky"] as Color if grp == "LANTERN" else PAL["lime"] as Color))
			c.draw_rect(Rect2(px - 4.0, py, 5.0, 5.0), PAL["void"] as Color)
			c.draw_rect(Rect2(px - 3.0, py + 1.0, 3.0, 3.0), col)
			if is_crown:
				c.draw_rect(Rect2(px - 2.0, py - 1.0, 1.0, 1.0), PAL["cream"] as Color)
			elif grp == "TOLL":
				c.draw_rect(Rect2(px - 2.0, py + 2.0, 1.0, 1.0), PAL["void"] as Color)
			elif grp == "LANTERN":
				c.draw_rect(Rect2(px - 2.0, py + 1.0, 1.0, 1.0), PAL["cream"] as Color)
			px -= 6.0


func _bind_wick() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if _wick == w:
		return
	_unbind_wick()
	_wick = w
	_last_flares = _wick.move_sunflare.flares_fired if _wick.move_sunflare != null else 0
	_last_zips = _wick.zips_count
	if not _wick.fired.is_connected(_on_wick_fired):
		_wick.fired.connect(_on_wick_fired)


func _unbind_wick() -> void:
	if _wick != null and is_instance_valid(_wick):
		if _wick.fired.is_connected(_on_wick_fired):
			_wick.fired.disconnect(_on_wick_fired)
	_wick = null


func _bind_events() -> void:
	if _events_bound or Lx.events == null:
		return
	if not Lx.events.enemy_hit.is_connected(_on_enemy_hit):
		Lx.events.enemy_hit.connect(_on_enemy_hit)
	if not Lx.events.boss_defeated.is_connected(_on_boss_defeated):
		Lx.events.boss_defeated.connect(_on_boss_defeated)
	_events_bound = true


func _unbind_events() -> void:
	if not _events_bound:
		return
	if Lx.events != null and Lx.events.enemy_hit.is_connected(_on_enemy_hit):
		Lx.events.enemy_hit.disconnect(_on_enemy_hit)
	if Lx.events != null and Lx.events.boss_defeated.is_connected(_on_boss_defeated):
		Lx.events.boss_defeated.disconnect(_on_boss_defeated)
	_events_bound = false


func _on_boss_defeated(_boss_id: String, _isl: int) -> void:
	if _dir == null or not _dir.is_in_stair():
		return
	_hide_defeated_bosses()


func _hide_defeated_bosses() -> void:
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_enemies"):
		return
	var en_v: Variant = Lx.world.call("get_enemies")
	if not (en_v is Array):
		return
	for ev: Variant in (en_v as Array):
		if not (ev is LxBossBase) or not is_instance_valid(ev):
			continue
		var bb: LxBossBase = ev as LxBossBase
		if not bb.visible:
			continue
		if bb.boss_state == LxBossBase.BossState.DEATH and bb.hp <= 0.0 and (bb.state_timer <= 0.05 or bool(bb.get("_death_emitted"))):
			bb.visible = false
