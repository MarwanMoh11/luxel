class_name LxBallastKeg
extends LxToy
## Island 2 16x16 oil-ship powder keg.
## States: resting | rolling (slides with tilt_group / galleon list / conveyors / fields, floats at flood,
## pinnable by Ballast Clamp, towable by Sluice Harpoon, battable by Skiff) | detonating (0.35s flash ->
## 4.0 HP blast + shatters cracked bulkheads) | respawning (reappears on rack after respawn_s).

const MAX_ROLL_SPEED: float = 135.0

var respawn_s: float = 5.0
var blast_r: float = 34.0
var blast_damage: float = 4.0
var fuse_s: float = 0.35
var tilt_speed: float = 78.0
var obey_list: bool = true

var state: String = "resting" # "resting" | "rolling" | "detonating" | "respawning"
var clamped: bool = false
var floating: bool = false
var origin_pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var _ext_vel: Vector2 = Vector2.ZERO
var _fuse_t: float = 0.0
var _respawn_t: float = 0.0
var _blast_fx_t: float = 0.0
var _blast_pos: Vector2 = Vector2.ZERO
var _roll_phase: float = 0.0


func _toy_setup() -> void:
	kind = "ballast_keg"
	size = _parse_size(props.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	radius = maxf(8.0, maxf(size.x, size.y) * 0.5)
	respawn_s = maxf(0.5, float(props.get("respawn_s", 5.0)))
	blast_r = maxf(16.0, float(props.get("blast_r", 34.0)))
	blast_damage = maxf(1.0, float(props.get("damage", 4.0)))
	fuse_s = maxf(0.10, float(props.get("fuse_s", 0.35)))
	tilt_speed = maxf(10.0, float(props.get("tilt_speed", 78.0)))
	obey_list = bool(props.get("obey_list", true))
	origin_pos = pos
	vel = Vector2.ZERO
	_ext_vel = Vector2.ZERO
	clamped = false
	floating = _is_over_water()
	state = "resting"
	_fuse_t = 0.0
	_respawn_t = 0.0
	_blast_fx_t = 0.0
	z_index = 0
	queue_redraw()


func reset_toy() -> void:
	pos = origin_pos
	position = pos.round()
	vel = Vector2.ZERO
	_ext_vel = Vector2.ZERO
	clamped = false
	floating = _is_over_water()
	state = "resting"
	_fuse_t = 0.0
	_respawn_t = 0.0
	_blast_fx_t = 0.0
	active = true
	queue_redraw()


func is_solid() -> bool:
	return active and state != "respawning"


func blocks_sight() -> bool:
	return false


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_solid() else Rect2()


func is_weight_body() -> bool:
	return active and state != "respawning" and not floating


func on_ballast_clamp(pinned: bool, _anchor_pos: Vector2 = Vector2.ZERO) -> void:
	if state == "respawning" or state == "detonating":
		clamped = false
		return
	clamped = pinned
	if clamped:
		vel = Vector2.ZERO
		_ext_vel = Vector2.ZERO
		state = "resting"
		_emit_sfx("anchor_slam")
	queue_redraw()


func on_lantern_pull(pull_dir: Vector2, _source: String = "recall") -> void:
	if not active or clamped or state == "respawning" or state == "detonating":
		return
	if not _is_harpoon_allowed():
		return
	if pull_dir.length_squared() <= 0.001:
		return
	vel = (vel * 0.3 + pull_dir.normalized() * 128.0).limit_length(MAX_ROLL_SPEED)
	state = "rolling"
	_emit_sfx("zip_streak")
	queue_redraw()


func on_skiff_bat(bat_dir: Vector2, bat_speed: float) -> void:
	if not active or clamped or state == "respawning":
		return
	vel = bat_dir.normalized() * clampf(bat_speed, 80.0, MAX_ROLL_SPEED)
	state = "rolling"
	queue_redraw()


func push_block_external(v: Vector2) -> void:
	if not active or clamped or state == "respawning" or not v.is_finite():
		return
	_ext_vel += v


func push_keg(v: Vector2) -> void:
	push_block_external(v)


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or state == "respawning":
		return false
	# Throwing lantern onto keg when Ballast Clamp is active clamps it safely without exploding!
	if hit.source == LxHit.SOURCE_THROW and _is_clamp_allowed():
		on_ballast_clamp(true, pos)
		return true
	if hit.source == LxHit.SOURCE_RECALL and _is_harpoon_allowed():
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "sunflare", "throw", "zip"]:
		start_detonate()
		return true
	return false


func start_detonate() -> void:
	if state == "detonating" or state == "respawning":
		return
	clamped = false
	state = "detonating"
	_fuse_t = fuse_s
	_emit_sfx("shield_strain")
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	if _blast_fx_t > 0.0:
		_blast_fx_t = maxf(0.0, _blast_fx_t - dt)
		dirty = true

	if state == "respawning":
		_respawn_t = maxf(0.0, _respawn_t - dt)
		if _respawn_t <= 0.0:
			pos = origin_pos
			position = pos.round()
			vel = Vector2.ZERO
			_ext_vel = Vector2.ZERO
			clamped = false
			floating = _is_over_water()
			state = "resting"
			_emit_sfx("footstep_wood")
			dirty = true
		if dirty:
			queue_redraw()
		return

	if state == "detonating":
		_fuse_t = maxf(0.0, _fuse_t - dt)
		if _fuse_t <= 0.0:
			_execute_blast()
		queue_redraw()
		return

	floating = _is_over_water()
	if not clamped:
		# Sample Galleon ship list var if set and not overridden
		var list_v: Vector2 = _sample_galleon_list_vel()
		if LxFields.has_fields():
			var fa: Vector2 = LxFields.accel_at(pos, "block")
			if fa.length_squared() > 1.0:
				vel = (vel + fa * dt).limit_length(MAX_ROLL_SPEED)
		var total_v: Vector2 = (vel + list_v + _ext_vel).limit_length(MAX_ROLL_SPEED)
		_ext_vel = Vector2.ZERO
		if total_v.length_squared() > 4.0:
			var step_p: Vector2 = _resolve_keg_step(pos, pos + total_v * dt)
			if step_p.distance_to(pos) > 0.02:
				_roll_phase += step_p.distance_to(pos) * 0.25
				pos = step_p
				position = pos.round()
				state = "rolling"
				if Lx.player is LxWick and is_instance_valid(Lx.player):
					LxPhysDraw.safe_eject_wick(Lx.player as Node2D, get_solid_rect(), region, id, total_v)
				dirty = true
			else:
				vel = Vector2.ZERO
				state = "resting"
		else:
			state = "resting"
		vel = vel.move_toward(Vector2.ZERO, (110.0 if floating else 160.0) * dt)
	else:
		_ext_vel = Vector2.ZERO
		vel = Vector2.ZERO

	if dirty or floating:
		queue_redraw()


func _sample_galleon_list_vel() -> Vector2:
	if not obey_list or Lx.vars == null:
		return Vector2.ZERO
	var lv: String = str(Lx.vars.get_var("dungeon:galleon", "list", "")).strip_edges().to_lower()
	if lv.is_empty():
		lv = str(Lx.vars.resolve_var("list", island_id, region_id, "")).strip_edges().to_lower()
	if lv == "port":
		return Vector2.LEFT * tilt_speed
	if lv == "starboard":
		return Vector2.RIGHT * tilt_speed
	return Vector2.ZERO


func _resolve_keg_step(from_p: Vector2, to_p: Vector2) -> Vector2:
	if _can_keg_place_at(to_p):
		return to_p
	var tx := Vector2(to_p.x, from_p.y)
	if _can_keg_place_at(tx):
		return tx
	var ty := Vector2(from_p.x, to_p.y)
	if _can_keg_place_at(ty):
		return ty
	return from_p


func _can_keg_place_at(p: Vector2) -> bool:
	if region == null or not is_instance_valid(region):
		return true
	var rect := Rect2(p - Vector2(6.0, 6.0), Vector2(12.0, 12.0))
	var b_v: Variant = region.get("bounds")
	if b_v is Rect2 and (b_v as Rect2).has_area():
		if not (b_v as Rect2).grow(-7.0).has_point(p):
			return false
	if region.has_method("tile_at"):
		for pt: Vector2 in [
			p, rect.position, Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y), rect.end,
		]:
			var tt: String = str(region.call("tile_at", pt))
			# Keg rolls on land/bridge and floats on water/tide; blocked by walls/pits/void/glass/cracked
			if tt in ["wall", "pit", "void", "glass", "mirror", "bramble", "cracked"]:
				if not (region.has_method("_is_tile_supported") and bool(region.call("_is_tile_supported", tt, pt))):
					return false
	if region.has_method("get_interactables"):
		for it_v: Variant in region.call("get_interactables") as Array:
			if it_v == self or not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if it.is_solid() and it.get_solid_rect().intersects(rect):
				return false
	return true


func _is_over_water() -> bool:
	if region == null or not region.has_method("tile_at"):
		return false
	var tt: String = str(region.call("tile_at", pos))
	return tt == "water" or tt == "tide"


func _execute_blast() -> void:
	_blast_pos = pos
	_blast_fx_t = 0.36
	state = "respawning"
	_respawn_t = respawn_s
	vel = Vector2.ZERO
	_ext_vel = Vector2.ZERO
	clamped = false
	_emit_sfx("stone_break")
	_emit_sfx("sunflare_burst")
	_emit_gust(blast_r * 1.8, 92.0)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.18 * (0.45 if LxHudFx.flash_reduced() else 1.0))
		Lx.events.hitstop_requested.emit(0.05)
	if LxGroundDecals.active_instance != null and is_instance_valid(LxGroundDecals.active_instance):
		LxGroundDecals.active_instance.add_decal(LxGroundDecals.Kind.CRATER, _blast_pos, 14.0, 8.0)
	if LxDarknessLayer.active_instance != null and is_instance_valid(LxDarknessLayer.active_instance):
		LxDarknessLayer.active_instance.add_burst_light(_blast_pos, 84.0, 0.95 if LxHudFx.flash_reduced() else 1.45, 0.32)

	# 1. Shatter cracked bulkheads & chain-detonate adjacent ballast kegs
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in region.call("get_interactables") as Array:
			if it_v == self or not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it) or not it.active:
				continue
			var d: float = it.pos.distance_to(_blast_pos)
			if d > blast_r + it.radius:
				continue
			var bdir: Vector2 = (it.pos - _blast_pos).normalized() if d > 0.5 else Vector2.RIGHT
			if it.kind == "ballast_keg" and it.has_method("start_detonate"):
				it.call("start_detonate")
			elif it.kind in ["cracked_wall", "bramble", "web"] and it.has_method("on_hit"):
				var bhit: LxHit = LxHit.make(LxHit.SOURCE_BEAM, blast_damage, bdir, _blast_pos, 4.0, true, true, Lx.player, true)
				it.on_hit(bhit)
	# 2. Deal 4.0 HP armor-cracking blast damage to enemies in blast_r
	if region != null and region.has_method("get_enemies"):
		for e_v: Variant in region.call("get_enemies") as Array:
			if not (e_v is LxEnemyBrain) or not is_instance_valid(e_v):
				continue
			var en: LxEnemyBrain = e_v as LxEnemyBrain
			if not en.is_alive():
				continue
			var ed: float = en.pos.distance_to(_blast_pos)
			if ed <= blast_r + en.body_radius:
				var edir: Vector2 = (en.pos - _blast_pos).normalized() if ed > 0.5 else Vector2.RIGHT
				var ehit: LxHit = LxHit.make(LxHit.SOURCE_SUNFLARE, blast_damage, edir, _blast_pos, 4.0, true, true, Lx.player, true)
				if en.has_method("apply_hit"):
					en.call("apply_hit", ehit)
				elif en.has_method("take_hit"):
					en.call("take_hit", ehit)
	_notify_linked_targets(true)
	queue_redraw()


func _is_clamp_allowed() -> bool:
	if bool(props.get("allow_clamp_always", false)):
		return true
	return Lx.state != null and bool(Lx.state.story_flags.get("power_ballast_clamp", false))


func _is_harpoon_allowed() -> bool:
	if bool(props.get("allow_harpoon_always", false)):
		return true
	return Lx.state != null and bool(Lx.state.story_flags.get("power_sluice_harpoon", false))


func get_light_pool() -> Vector4:
	if _blast_fx_t > 0.0:
		return Vector4(_blast_pos.x, _blast_pos.y, 76.0, 1.35 * (_blast_fx_t / 0.36))
	if state == "detonating":
		return Vector4(pos.x, pos.y, 44.0, 0.95)
	if clamped:
		return Vector4(pos.x, pos.y, 28.0, 0.50)
	return Vector4.ZERO


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var c_void: Color = PAL["void"] as Color

	# Blast expansion ring when recently exploded
	if _blast_fx_t > 0.0:
		var u: float = 1.0 - clampf(_blast_fx_t / 0.36, 0.0, 1.0)
		var b_rel: Vector2 = (_blast_pos - pos).round()
		var rr: float = roundf(lerpf(6.0, blast_r, u))
		var ring_c: Color = PAL["cream"] as Color if u < 0.35 else PAL["coral"] as Color
		var ring_a: float = (1.0 - u * 0.5) * (0.55 if red else 1.0)
		draw_arc(b_rel, rr, 0.0, TAU, 20, Color(ring_c, ring_a), 1.0 if red else (2.0 if u < 0.45 else 1.0))
		draw_circle(b_rel, roundf(maxf(2.0, rr * (1.0 - u) * 0.65)), Color(PAL["gold"] as Color, (1.0 - u) * (0.35 if red else 0.55)))

	# Respawning rack silhouette
	if state == "respawning":
		var rack_rel: Vector2 = (origin_pos - pos).round()
		var frac: float = 1.0 - clampf(_respawn_t / maxf(respawn_s, 0.01), 0.0, 1.0)
		draw_rect(Rect2(rack_rel - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), Color(PAL["mauve"] as Color, 0.45), false, 1.0)
		LxToyDraw.draw_bar(self, rack_rel + Vector2(-6.0, 9.0), 12.0, frac, PAL["apricot"] as Color)
		return

	var bob: float = 0.0 if (red or not floating or clamped) else roundf(sin(_clock * 3.0) * 0.9)
	if floating:
		draw_arc(Vector2(0.0, 3.0), 9.0, 0.0, TAU, 12, Color(PAL["ice"] as Color, 0.50 if red else 0.65), 1.0)
	else:
		LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 7.0, 3.0)

	# Fuse danger radius preview while detonating
	if state == "detonating":
		var f_flash: bool = not red and int(floorf(_clock * 18.0)) % 2 == 0
		draw_arc(Vector2.ZERO, roundf(blast_r), 0.0, TAU, 24, Color(PAL["cream"] as Color if f_flash else PAL["coral"] as Color, 0.50 if red else 0.72), 1.0)

	# Sculpted rounded oil keg barrel silhouette (tapered top/bottom staves + 3/4 cap)
	var flash_det: bool = state == "detonating" and (not red and int(floorf(_clock * 18.0)) % 2 == 0)
	var wood_dark: Color = (PAL["coral"] if flash_det else PAL["night"]) as Color
	var wood_mid: Color = (PAL["apricot"] if flash_det else PAL["wine"]) as Color
	var wood_hi: Color = (PAL["cream"] if flash_det else PAL["coral"]) as Color
	var hoop_c: Color = (PAL["gold"] if clamped else PAL["deep"]) as Color
	var hoop_hi: Color = (PAL["cream"] if clamped else PAL["ice"]) as Color
	draw_rect(Rect2(-6.0, -8.0 - bob, 12.0, 16.0), c_void)
	draw_rect(Rect2(-8.0, -6.0 - bob, 16.0, 12.0), c_void)
	draw_rect(Rect2(-5.0, -7.0 - bob, 10.0, 14.0), wood_mid)
	draw_rect(Rect2(-7.0, -5.0 - bob, 14.0, 10.0), wood_mid)
	# Vertical stave shading (sunlit left, shaded right)
	draw_rect(Rect2(-6.0, -5.0 - bob, 3.0, 10.0), wood_hi)
	draw_rect(Rect2(4.0, -5.0 - bob, 3.0, 10.0), wood_dark)
	draw_rect(Rect2(-2.0, -6.0 - bob, 1.0, 12.0), wood_dark)
	draw_rect(Rect2(2.0, -6.0 - bob, 1.0, 12.0), wood_dark)
	# Top barrel lid oval with sunlit rim & fuse/bung plug
	draw_rect(Rect2(-5.0, -7.0 - bob, 10.0, 3.0), PAL["apricot"] as Color if not flash_det else PAL["cream"] as Color)
	draw_rect(Rect2(-4.0, -7.0 - bob, 6.0, 1.0), PAL["gold"] as Color if not flash_det else PAL["cream"] as Color)
	# Twin riveted iron/brass barrel hoops
	draw_rect(Rect2(-7.0, -4.0 - bob, 14.0, 2.0), hoop_c)
	draw_rect(Rect2(-7.0, 2.0 - bob, 14.0, 2.0), hoop_c)
	draw_rect(Rect2(-6.0, -4.0 - bob, 5.0, 1.0), hoop_hi)
	draw_rect(Rect2(-6.0, 2.0 - bob, 5.0, 1.0), hoop_hi)
	# Sparking fuse cord on top when detonating
	if state == "detonating":
		draw_rect(Rect2(-1.0, -10.0 - bob, 2.0, 3.0), PAL["apricot"] as Color)
		draw_rect(Rect2(-2.0, -12.0 - bob, 4.0, 3.0), PAL["cream"] as Color if flash_det else PAL["gold"] as Color)
	# Hazard oil diamond emblem in center (shifts slightly with roll phase)
	var r_off: float = roundf(sin(_roll_phase) * 2.0) if state == "rolling" else 0.0
	LxToyDraw.draw_shape_glyph(self, Vector2(r_off, -bob), 1, state == "detonating", PAL["coral"] as Color, PAL["gold"] as Color)
	# Ballast Clamp locked brackets
	if clamped:
		draw_rect(Rect2(-8.0, -8.0 - bob, 16.0, 16.0), PAL["gold"] as Color, false, 1.0)
		draw_rect(Rect2(-8.0, -8.0 - bob, 3.0, 3.0), PAL["cream"] as Color)
		draw_rect(Rect2(5.0, -8.0 - bob, 3.0, 3.0), PAL["cream"] as Color)
		draw_rect(Rect2(-8.0, 5.0 - bob, 3.0, 3.0), PAL["cream"] as Color)
		draw_rect(Rect2(5.0, 5.0 - bob, 3.0, 3.0), PAL["cream"] as Color)
