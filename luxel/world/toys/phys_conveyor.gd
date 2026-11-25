class_name LxPhysConveyor
extends LxToy
## Directional conveyor belt pushing Wick, push_blocks, carry_orbs, mirrors (when movable/opted in),
## and grounded enemies. Reverses direction when signaled if flip_on_signal is true.
## Island 6 additions: boost_speed(mult, secs) for Stoker coal-shovel bursts, optional needs_var
## (e.g. "kiln_heat==surge") gating, and carrying blue_transformer / mirror blocks smoothly.

var belt_dir: Vector2 = Vector2.RIGHT
var speed: float = 56.0
var flip_on_signal: bool = true
var carry_mirrors: bool = false
var needs_var: String = ""
var speed_mult: float = 1.0
var _boost_mult: float = 1.0
var _boost_t: float = 0.0
var _scroll: float = 0.0
var _var_running: bool = true


func _toy_setup() -> void:
	kind = "conveyor"
	size = _parse_size(props.get("size", [48.0, 16.0]), Vector2(48.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	belt_dir = dir_vec("dir", Vector2.RIGHT)
	speed = maxf(8.0, float(props.get("speed", 56.0)))
	flip_on_signal = bool(props.get("flip_on_signal", true))
	carry_mirrors = bool(props.get("carry_mirrors", island_id == 6))
	needs_var = str(props.get("needs_var", "")).strip_edges()
	speed_mult = maxf(0.0, float(props.get("speed_mult", 1.0)))
	_boost_mult = 1.0
	_boost_t = 0.0
	_var_running = _check_needs_var()
	z_index = LxPhysDraw.floor_z(region, -4)
	queue_redraw()


func boost_speed(mult: float, secs: float) -> void:
	_boost_mult = clampf(mult, 0.25, 3.0)
	_boost_t = maxf(_boost_t, maxf(0.1, secs))
	_emit_sfx("furnace_draw")
	queue_redraw()


func set_speed_scale(mult: float) -> void:
	speed_mult = clampf(mult, 0.0, 3.0)
	queue_redraw()


func effective_speed() -> float:
	if not _var_running:
		return 0.0
	return speed * speed_mult * (_boost_mult if _boost_t > 0.0 else 1.0)


func _check_needs_var() -> bool:
	if needs_var.is_empty():
		return true
	if Lx.vars != null:
		if Lx.vars.eval(needs_var, island_id, region_id):
			return true
		if needs_var.contains("kiln_heat") and not needs_var.contains(".kiln_heat"):
			return Lx.vars.eval(needs_var.replace("kiln_heat", "dungeon:great_kiln.kiln_heat"), island_id, region_id)
		return false
	return true


func _effective_dir() -> Vector2:
	return -belt_dir if (flip_on_signal and powered) else belt_dir


func _on_power_changed(_is_on: bool) -> void:
	if flip_on_signal:
		_emit_sfx("clockwork_chime")
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if _boost_t > 0.0:
		_boost_t = maxf(0.0, _boost_t - dt)
		if _boost_t <= 0.0:
			_boost_mult = 1.0
	_var_running = _check_needs_var()
	var eff_spd: float = effective_speed()
	if eff_spd <= 0.1:
		queue_redraw()
		return

	var d: Vector2 = _effective_dir()
	var vis_mult: float = 0.5 if LxHudFx.flash_reduced() else 1.0
	_scroll = fposmod(_scroll + eff_spd * 0.65 * vis_mult * dt, 8.0)
	var rect := Rect2(pos - size * 0.5, size)

	# 1. Push Wick
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead and not w.is_dashing() and not w.is_gliding() and not w.is_zipping() and not w.is_launched() and not w.is_mounted():
			if rect.has_point(w.global_position):
				w.push_external(d * eff_spd, "conveyor")

	# 2. Push loose interactables (blocks / orbs / movable mirrors)
	if region != null and region.has_method("get_interactables"):
		for it_v: Variant in region.call("get_interactables") as Array:
			if not is_instance_valid(it_v) or it_v == self or not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not it.active or not rect.has_point(it.pos):
				continue
			if it.has_method("push_block_external"):
				it.call("push_block_external", d * eff_spd)
			elif it.kind == "carry_orb" and it.has_method("push_orb"):
				it.call("push_orb", d * eff_spd * dt)
			elif carry_mirrors and it.kind in ["mirror", "blue_transformer", "transformer"] and it.has_method("move_to"):
				var is_mov: bool = bool(it.get("movable")) or bool(it.props.get("on_conveyor", false))
				if is_mov:
					var nxt_m: Vector2 = it.pos + d * eff_spd * dt
					var ok_m: bool = true
					if region.has_method("can_place_rect") and it.has_method("get_push_rect_at"):
						ok_m = bool(region.call("can_place_rect", it.call("get_push_rect_at", nxt_m), it.id))
					if ok_m:
						it.call("move_to", nxt_m)

	# 3. Push grounded enemies
	if region != null and region.has_method("get_enemies"):
		for e_v: Variant in region.call("get_enemies") as Array:
			if e_v is Node2D and is_instance_valid(e_v as Object):
				var e: Node2D = e_v as Node2D
				if rect.has_point(e.global_position) and e.has_method("is_alive") and bool(e.call("is_alive")):
					if (e.has_method("is_flying") and bool(e.call("is_flying"))):
						continue
					var nxt: Vector2 = e.global_position + d * eff_spd * 0.7 * dt
					if region.has_method("collide"):
						nxt = region.call("collide", nxt, 6.0, false, false) as Vector2
					e.global_position = nxt
					if e.get("pos") is Vector2:
						e.set("pos", nxt)
	queue_redraw()


func _draw() -> void:
	var r := Rect2((-size * 0.5).round(), size.round())
	var d: Vector2 = _effective_dir()
	var horiz: bool = absf(d.x) >= absf(d.y)
	var running: bool = effective_speed() > 0.1
	var boosted: bool = running and _boost_t > 0.0 and _boost_mult > 1.05
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color

	# Grounded drop shadow & heavy iron chassis outline
	LxPhysDraw.draw_shadow_rect(self, r, Vector2(0.0, 2.0), 0.42)
	draw_rect(r, c_void)
	# Recessed belt trough
	draw_rect(Rect2(r.position + Vector2(1.0, 1.0), r.size - Vector2(2.0, 2.0)), c_night)

	# Bright metallic guide rails along the long edges (unmistakable bright edge!)
	var edge_hi: Color = c_cream if boosted else (c_gold if (running and powered) else (c_stone if running else c_mauve))
	var edge_mid: Color = c_coral if boosted else (biome("hi") if running else c_dusk)
	var chev_c: Color = c_cream if boosted else (c_gold if (running and powered) else (c_cream if running else c_dusk))
	var slat_a: Color = c_dusk if running else c_night
	var slat_b: Color = c_mauve if boosted else (c_night if running else c_void)
	var roller_hi: Color = c_cream if boosted else (c_gold if powered else c_stone)
	var roller_mid: Color = c_apr if boosted else (c_mauve if running else c_dusk)

	if horiz:
		# Top & bottom bright steel side rails
		draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, r.size.x - 2.0, 2.0), edge_mid)
		draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, r.size.x - 2.0, 1.0), edge_hi)
		draw_rect(Rect2(r.position.x + 1.0, r.end.y - 3.0, r.size.x - 2.0, 2.0), c_dusk)
		draw_rect(Rect2(r.position.x + 1.0, r.end.y - 2.0, r.size.x - 2.0, 1.0), edge_mid)
		# Moving belt slats + bold directional chevrons
		var sign_x: float = 1.0 if d.x >= 0.0 else -1.0
		var off: float = _scroll if sign_x > 0.0 else (8.0 - _scroll)
		var belt_y: float = r.position.y + 3.0
		var belt_h: float = maxf(4.0, r.size.y - 6.0)
		var x: float = r.position.x + 4.0 + off
		var si: int = 0
		while x < r.end.x - 4.0:
			var rx: float = roundf(x)
			draw_rect(Rect2(rx - 2.0, belt_y, 5.0, belt_h), slat_a if si % 2 == 0 else slat_b)
			draw_rect(Rect2(rx - 3.0, belt_y, 1.0, belt_h), c_void)
			draw_rect(Rect2(rx - 2.0, belt_y, 5.0, 1.0), c_mauve if running else c_dusk)
			LxPhysDraw.draw_chevron(self, Vector2(rx, 0.0), d, chev_c, c_void, 2.5)
			x += 8.0
			si += 1
		# Chunky end-cap rollers with specular ridge & brass bearings
		for end_x: float in [r.position.x + 1.0, r.end.x - 4.0]:
			draw_rect(Rect2(end_x, r.position.y + 1.0, 3.0, r.size.y - 2.0), c_void)
			draw_rect(Rect2(end_x, r.position.y + 2.0, 3.0, r.size.y - 4.0), roller_mid)
			draw_rect(Rect2(end_x + 1.0, r.position.y + 2.0, 1.0, r.size.y - 4.0), roller_hi)
			draw_rect(Rect2(end_x + 1.0, r.position.y + 1.0, 1.0, 1.0), c_gold if running else c_mauve)
			draw_rect(Rect2(end_x + 1.0, r.end.y - 2.0, 1.0, 1.0), c_gold if running else c_mauve)
	else:
		# Left & right bright steel side rails
		draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, 2.0, r.size.y - 2.0), edge_mid)
		draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, 1.0, r.size.y - 2.0), edge_hi)
		draw_rect(Rect2(r.end.x - 3.0, r.position.y + 1.0, 2.0, r.size.y - 2.0), c_dusk)
		draw_rect(Rect2(r.end.x - 2.0, r.position.y + 1.0, 1.0, r.size.y - 2.0), edge_mid)
		var sign_y: float = 1.0 if d.y >= 0.0 else -1.0
		var off_y: float = _scroll if sign_y > 0.0 else (8.0 - _scroll)
		var belt_x: float = r.position.x + 3.0
		var belt_w: float = maxf(4.0, r.size.x - 6.0)
		var y: float = r.position.y + 4.0 + off_y
		var sj: int = 0
		while y < r.end.y - 4.0:
			var ry: float = roundf(y)
			draw_rect(Rect2(belt_x, ry - 2.0, belt_w, 5.0), slat_a if sj % 2 == 0 else slat_b)
			draw_rect(Rect2(belt_x, ry - 3.0, belt_w, 1.0), c_void)
			draw_rect(Rect2(belt_x, ry - 2.0, 1.0, 5.0), c_mauve if running else c_dusk)
			LxPhysDraw.draw_chevron(self, Vector2(0.0, ry), d, chev_c, c_void, 2.5)
			y += 8.0
			sj += 1
		for end_y: float in [r.position.y + 1.0, r.end.y - 4.0]:
			draw_rect(Rect2(r.position.x + 1.0, end_y, r.size.x - 2.0, 3.0), c_void)
			draw_rect(Rect2(r.position.x + 2.0, end_y, r.size.x - 4.0, 3.0), roller_mid)
			draw_rect(Rect2(r.position.x + 2.0, end_y + 1.0, r.size.x - 4.0, 1.0), roller_hi)
			draw_rect(Rect2(r.position.x + 1.0, end_y + 1.0, 1.0, 1.0), c_gold if running else c_mauve)
			draw_rect(Rect2(r.end.x - 2.0, end_y + 1.0, 1.0, 1.0), c_gold if running else c_mauve)
