class_name LxPhysTiltGroup
extends LxToy
## Periodic deck-tilting controller (Island 2 Drowned Galleon / Island 6 Iron Colossus).
## On a readable clock (or driven externally by colossus_stride_cam), slides crates/ice blocks
## and carry_orbs toward the low side while cooled slag/stone stays planted, and biases Wick
## (reduced by 85% when Wick owns Cleated Heat-Boots: story_flags["item_heat_boots"]).

const TELEGRAPH_S: float = 0.75
const HEAT_BOOTS_MULT: float = 0.15

var period: float = 6.0
var tilt_axis: Vector2 = Vector2.RIGHT
var strength: float = 74.0
var tilt_side: int = 1 # -1 or +1
var tilt_amount: float = 0.0 # -1.0 .. +1.0
var telegraphing: bool = false
var external_sync: bool = false
var stabilized: bool = false
var speed_mult: float = 1.0
var slide_enemies: bool = false
var _zone_rect: Rect2 = Rect2()
var _ext_mult: float = 1.0
var _stabilized_flag: String = ""
var _target_ids: Array[String] = []


func _toy_setup() -> void:
	kind = "tilt_group"
	var has_sz: bool = props.has("size")
	size = _parse_size(props.get("size", [160.0, 120.0]), Vector2(160.0, 120.0)) if has_sz else Vector2.ZERO
	radius = maxf(size.x, size.y) * 0.5 if has_sz else 9999.0
	period = maxf(2.0, float(props.get("period", 6.0)))
	tilt_axis = dir_vec("axis", Vector2.RIGHT)
	strength = maxf(10.0, float(props.get("strength", 74.0)))
	slide_enemies = bool(props.get("slide_enemies", island_id == 6))
	_stabilized_flag = str(props.get("stabilized_flag", "")).strip_edges()
	_target_ids.clear()
	var raw_t: Variant = props.get("targets", [])
	if raw_t is Array:
		for item: Variant in (raw_t as Array):
			var tid: String = str(item).strip_edges()
			if not tid.is_empty():
				_target_ids.append(tid)
	tilt_side = 1
	tilt_amount = 0.0
	telegraphing = false
	external_sync = false
	stabilized = false
	speed_mult = 1.0
	_ext_mult = 1.0
	_zone_rect = Rect2(pos - size * 0.5, size) if has_sz else Rect2()
	z_index = LxPhysDraw.floor_z(region, -4)
	queue_redraw()


func set_external_tilt(side: int, is_telegraph: bool, amount_mult: float = 1.0, is_stabilized: bool = false) -> void:
	external_sync = true
	tilt_side = 1 if side >= 0 else -1
	telegraphing = is_telegraph
	_ext_mult = clampf(amount_mult, 0.0, 2.5)
	stabilized = is_stabilized


func _on_power_changed(is_on: bool) -> void:
	var mode: String = str(props.get("on_signal", "")).strip_edges().to_lower()
	if mode == "stabilize":
		stabilized = is_on
	elif mode == "flip":
		tilt_axis = -tilt_axis
	queue_redraw()


func _has_heat_boots() -> bool:
	return Lx.state != null and bool(Lx.state.story_flags.get("item_heat_boots", false))


func _is_stabilized() -> bool:
	if stabilized:
		return true
	if not _stabilized_flag.is_empty() and LxRegionLoader.check_flag_static(_stabilized_flag):
		return true
	return false


func _covers(p: Vector2) -> bool:
	return true if not _zone_rect.has_area() else _zone_rect.has_point(p)


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var is_calm: bool = _is_stabilized()
	if is_calm:
		telegraphing = false
		tilt_amount = move_toward(tilt_amount, 0.0, dt * 4.0)
		queue_redraw()
		return

	if not external_sync:
		var eff_p: float = maxf(1.5, period / maxf(0.25, speed_mult))
		var half_p: float = eff_p * 0.5
		var cycle: float = fposmod(_clock, eff_p)
		var prev_side: int = tilt_side
		tilt_side = 1 if cycle < half_p else -1
		var local_t: float = cycle if cycle < half_p else (cycle - half_p)
		var was_tele: bool = telegraphing
		telegraphing = local_t >= (half_p - TELEGRAPH_S)
		if telegraphing and not was_tele:
			_emit_sfx("harbor_creak")
		if tilt_side != prev_side:
			_emit_sfx("tide_surge")
		_ext_mult = 1.0

	var target_amt: float = float(tilt_side) * (0.35 if telegraphing else 1.0) * _ext_mult
	tilt_amount = move_toward(tilt_amount, target_amt, dt * 3.4)

	var slide_vec: Vector2 = tilt_axis * (tilt_amount * strength)
	if slide_vec.length_squared() > 1.0:
		# 1. Slide crate and ice push_blocks + carry_orbs inside zone (cooled slag/stone stays planted!)
		if region != null and region.has_method("get_interactables"):
			for it_v: Variant in region.call("get_interactables") as Array:
				if it_v == self or not (it_v is LxInteractable):
					continue
				var it: LxInteractable = it_v as LxInteractable
				if not it.active:
					continue
				if not _target_ids.is_empty() and not _target_ids.has(it.id):
					continue
				if not _covers(it.pos):
					continue
				if it.kind == "push_block":
					var v_str: String = str(it.get("variant"))
					if (v_str == "crate" or v_str == "ice") and it.has_method("push_block_external"):
						it.call("push_block_external", slide_vec)
				elif it.kind == "carry_orb" and it.has_method("push_orb"):
					it.call("push_orb", slide_vec * 0.65 * dt)

		# 2. Optional subtle slide on grounded enemies (e.g. slag_slime / piston_knight on Colossus)
		if slide_enemies and region != null and region.has_method("get_enemies"):
			for e_v: Variant in region.call("get_enemies") as Array:
				if not (e_v is Node2D) or not is_instance_valid(e_v as Object):
					continue
				var e: Node2D = e_v as Node2D
				if not _covers(e.global_position):
					continue
				if e.has_method("is_alive") and not bool(e.call("is_alive")):
					continue
				if (e.get("is_flying") == true):
					continue
				var nxt: Vector2 = e.global_position + slide_vec * 0.24 * dt
				if region.has_method("collide"):
					nxt = region.call("collide", nxt, 6.0, false, false) as Vector2
				e.global_position = nxt
				if e.get("pos") is Vector2:
					e.set("pos", nxt)

		# 3. Gentle bias on Wick (reduced 85% by Cleated Heat-Boots!)
		if Lx.player is LxWick and is_instance_valid(Lx.player):
			var w: LxWick = Lx.player as LxWick
			if not w.dead and not w.is_dashing() and not w.is_gliding() and not w.is_zipping() and not w.is_mounted() and _covers(w.global_position):
				var wick_mult: float = 0.28 * (HEAT_BOOTS_MULT if _has_heat_boots() else 1.0)
				w.push_external(slide_vec * wick_mult, "tilt_group")
	queue_redraw()


func _draw() -> void:
	var is_calm: bool = _is_stabilized()
	var has_boots: bool = _has_heat_boots()
	if _zone_rect.has_area():
		var r := Rect2((-size * 0.5).round(), size.round())
		draw_rect(r, Color(biome("mid"), 0.04 if is_calm else (0.11 if telegraphing else 0.06)))
		draw_rect(r, Color(PAL["ice"] as Color if is_calm else (PAL["gold"] as Color if telegraphing else biome("hi")), 0.26), false, 1.0)
		# Crisp directional deck floor ticks readable in greyscale
		if not is_calm:
			var sdir: Vector2 = tilt_axis * float(tilt_side)
			var step_n: int = clampi(int(maxf(size.x, size.y) / 48.0), 1, 4)
			for i: int in range(step_n):
				var u: float = (float(i) + 0.5) / float(step_n) - 0.5
				var pt: Vector2 = (tilt_axis * (u * (size.x if absf(tilt_axis.x) >= absf(tilt_axis.y) else size.y) * 0.65)).round()
				if pt.length() > 16.0:
					LxPhysDraw.draw_chevron(self, pt, sdir, PAL["cream"] as Color if telegraphing else biome("hi"), PAL["void"] as Color, 2.0)

	var badge := Rect2(-12.0, -7.0, 24.0, 14.0)
	var border_c: Color = PAL["ice"] as Color if is_calm else (PAL["gold"] as Color if telegraphing else PAL["stone"] as Color)
	LxPhysDraw.draw_bevel_box(self, badge, PAL["night"] as Color, border_c, PAL["dusk"] as Color, PAL["void"] as Color)
	# Pendulum level indicator showing live tilt angle
	var ang: float = 0.0 if is_calm else clampf(tilt_amount, -1.2, 1.2) * 0.55
	var bob: Vector2 = (Vector2(sin(ang) * 7.0, cos(ang) * 5.0) + Vector2(0.0, -4.0)).round()
	draw_line(Vector2(0.0, -4.0), bob, PAL["ice"] as Color if is_calm else PAL["gold"] as Color, 1.0)
	draw_rect(Rect2(bob - Vector2.ONE, Vector2(2.0, 2.0)), PAL["ice"] as Color if is_calm else (PAL["coral"] as Color if telegraphing else PAL["cream"] as Color))
	if not is_calm:
		LxPhysDraw.draw_chevron(self, tilt_axis * (float(tilt_side) * 8.0), tilt_axis * float(tilt_side), biome("glow"), PAL["void"] as Color, 2.0)
	if has_boots:
		# Small brass cleat anchor mark on badge corner when Heat-Boots brace Wick
		draw_rect(Rect2(-10.0, 3.0, 3.0, 2.0), PAL["apricot"] as Color)
		draw_rect(Rect2(-9.0, 2.0, 1.0, 1.0), PAL["cream"] as Color)
