class_name LxTideRaft
extends LxToy
## Island 2 buoyant 32x32 raft (mounts: none | blue_transformer | cargo).
## States: grounded (low solid floor, weighs pressure_plate/scale) vs floating (rises at half/flood
## or mid/high, drifts in currents/fields, towable by Sluice Harpoon, pinnable by Ballast Clamp).

const FLOAT_DRAG: float = 2.6
const TOW_SPEED: float = 132.0
const MAX_RAFT_SPEED: float = 150.0

var mounts: String = "none" # "none" | "blue_transformer" | "cargo"
var drift_dir: Vector2 = Vector2.ZERO
var drift_speed: float = 22.0
var tide_min: String = "half" # "half" | "flood" | "mid" | "high"
var tide_var: String = "" # auto: tower_tide / lock_water / tide
var lock_side: String = "" # "west" | "east" when tide_var == "lock_water"
var reflect_only_floating: bool = false
var rotatable: bool = true
var normal: Vector2 = Vector2(0.707107, 0.707107)
var angle_step_deg: float = 45.0
var double_sided: bool = true

var state: String = "grounded" # "grounded" | "floating"
var floating: bool = false
var clamped: bool = false
var origin_pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO

var _ext_vel: Vector2 = Vector2.ZERO
var _flash_t: float = 0.0
var _turn_t: float = 0.0
var _bob_t: float = 0.0
var _tow_fx_t: float = 0.0
var _float_h: float = 0.0


func _toy_setup() -> void:
	kind = "tide_raft"
	size = _parse_size(props.get("size", [32.0, 32.0]), Vector2(32.0, 32.0))
	radius = maxf(size.x, size.y) * 0.5
	mounts = str(props.get("mounts", "none")).strip_edges().to_lower()
	if mounts not in ["none", "blue_transformer", "cargo"]:
		mounts = "none"
	if not props.has("weight"):
		props["weight"] = 3.0 if mounts == "cargo" else 2.0
	origin_pos = pos
	drift_dir = Vector2.ZERO
	if props.has("drift_dir"):
		var dd: Vector2 = dir_vec("drift_dir", Vector2.ZERO)
		if dd.length_squared() > 0.001:
			drift_dir = dd.normalized()
	drift_speed = maxf(0.0, float(props.get("drift_speed", 22.0)))
	tide_min = str(props.get("tide_min", "half")).strip_edges().to_lower()
	tide_var = str(props.get("tide_var", "")).strip_edges()
	lock_side = str(props.get("lock_side", "")).strip_edges().to_lower()
	reflect_only_floating = bool(props.get("reflect_only_floating", false))
	rotatable = bool(props.get("rotatable", mounts == "blue_transformer"))
	angle_step_deg = float(props.get("angle_step_deg", 45.0))
	double_sided = bool(props.get("double_sided", true))
	if props.has("normal"):
		var n: Vector2 = _parse_vec2(props.get("normal"), normal)
		if n.length_squared() > 0.001:
			normal = n.normalized()
	elif props.has("angle_deg"):
		var rad: float = deg_to_rad(float(props.get("angle_deg", 45.0)))
		normal = Vector2(cos(rad), sin(rad)).normalized()
	vel = Vector2.ZERO
	_ext_vel = Vector2.ZERO
	clamped = false
	_flash_t = 0.0
	_turn_t = 0.0
	_tow_fx_t = 0.0
	floating = _compute_should_float()
	state = "floating" if floating else "grounded"
	_float_h = 3.0 if floating else 0.0
	z_index = LxPhysDraw.floor_z(region, -2)
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	pos = origin_pos
	position = pos.round()
	vel = Vector2.ZERO
	_ext_vel = Vector2.ZERO
	clamped = false
	floating = _compute_should_float()
	state = "floating" if floating else "grounded"
	_float_h = 3.0 if floating else 0.0
	queue_redraw()


func is_floating() -> bool:
	return floating


func is_grounded() -> bool:
	return not floating


func is_clamped() -> bool:
	return clamped


func is_platform_solid() -> bool:
	return active


func get_platform_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if active else Rect2()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func is_weight_body() -> bool:
	# Weighs pressure_plate and scale ONLY when grounded (drained basin / ebb)
	return active and not floating


func is_reflective() -> bool:
	if not active or mounts != "blue_transformer":
		return false
	return floating if reflect_only_floating else true


func get_transform_color() -> String:
	return LxHit.COLOR_BLUE


func reflect_dir(in_dir: Vector2) -> Vector2:
	if not is_reflective() or in_dir.length_squared() <= 0.0001:
		return Vector2.ZERO
	var d: Vector2 = in_dir.normalized()
	var n: Vector2 = normal.normalized()
	if d.dot(n) > 0.0:
		if not double_sided:
			return Vector2.ZERO
		n = -n
	return d.bounce(n).normalized()


func reflect_bolt(_hit_pos: Vector2, in_dir: Vector2) -> Dictionary:
	if not is_reflective():
		return {"hit": false}
	var rdir: Vector2 = reflect_dir(in_dir)
	if rdir.length_squared() <= 0.0001:
		return {"hit": false}
	return {"hit": true, "pos": pos, "dir": rdir}


func on_ballast_clamp(pinned: bool, _anchor_pos: Vector2 = Vector2.ZERO) -> void:
	if clamped == pinned:
		return
	clamped = pinned
	if clamped:
		vel = Vector2.ZERO
		_ext_vel = Vector2.ZERO
		_emit_sfx("anchor_slam")
	queue_redraw()


func on_lantern_pull(pull_dir: Vector2, source: String = "recall") -> void:
	if not active or clamped or not floating or source == "zip":
		return
	if not _is_harpoon_allowed():
		return
	if pull_dir.length_squared() <= 0.001:
		return
	vel = (vel * 0.35 + pull_dir.normalized() * TOW_SPEED).limit_length(MAX_RAFT_SPEED)
	_tow_fx_t = 0.32
	_emit_sfx("zip_streak")
	queue_redraw()


func push_block_external(v: Vector2) -> void:
	if not active or clamped or not floating or not v.is_finite():
		return
	_ext_vel += v


func on_portal_warped(_from_p: Vector2, _to_p: Vector2, new_vel: Vector2) -> void:
	vel = new_vel
	_tow_fx_t = 0.25
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or mounts != "blue_transformer" or not rotatable:
		return false
	normal = normal.rotated(deg_to_rad(angle_step_deg)).normalized()
	_turn_t = 0.20
	_emit_sfx("mirror_turn")
	queue_redraw()
	return true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if is_reflective() and hit.source in ["bolt", "prism_bolt", "beam"]:
		_flash_t = 0.22
		_emit_sfx("mirror_ping")
		queue_redraw()
		return true
	return false


func get_interact_prompt() -> String:
	if active and mounts == "blue_transformer" and rotatable:
		return "PROMPT_TURN_MIRROR"
	return ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if mounts == "blue_transformer":
		return Vector4(pos.x, pos.y - _float_h, 36.0 if _flash_t > 0.0 else 28.0, 0.72 if _flash_t > 0.0 else 0.50)
	if clamped:
		return Vector4(pos.x, pos.y - _float_h, 30.0, 0.55)
	return Vector4.ZERO


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	_bob_t += dt * 2.6
	var dirty: bool = false
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		dirty = true
	if _turn_t > 0.0:
		_turn_t = maxf(0.0, _turn_t - dt)
		dirty = true
	if _tow_fx_t > 0.0:
		_tow_fx_t = maxf(0.0, _tow_fx_t - dt)
		dirty = true

	# Ballast Clamp pins BOTH position and elevation tier against tide drains
	if not clamped:
		var want_float: bool = _compute_should_float()
		if want_float != floating:
			floating = want_float
			state = "floating" if floating else "grounded"
			if not floating:
				vel = Vector2.ZERO
			_emit_sfx("tide_wave" if floating else "footstep_wood")
			dirty = true

	var target_h: float = 3.0 if floating else 0.0
	if not is_equal_approx(_float_h, target_h):
		_float_h = move_toward(_float_h, target_h, dt * 10.0)
		dirty = true

	if floating and not clamped:
		var drift_v: Vector2 = drift_dir * drift_speed if drift_dir.length_squared() > 0.001 else Vector2.ZERO
		if LxFields.has_fields():
			var fa: Vector2 = LxFields.accel_at(pos, "block")
			if fa.length_squared() > 0.01:
				vel = (vel + fa * dt).limit_length(MAX_RAFT_SPEED)
		vel *= exp(-FLOAT_DRAG * dt)
		if vel.length_squared() < 1.0:
			vel = Vector2.ZERO
		var step_v: Vector2 = (vel + drift_v + _ext_vel).limit_length(MAX_RAFT_SPEED)
		_ext_vel = Vector2.ZERO
		if step_v.length_squared() > 0.5:
			var prev_p: Vector2 = pos
			var nxt: Vector2 = _resolve_raft_step(pos, pos + step_v * dt)
			if nxt.distance_to(pos) > 0.01:
				var delta_p: Vector2 = nxt - prev_p
				pos = nxt
				position = pos.round()
				# Carry Wick gently if standing on deck
				if Lx.player is LxWick and is_instance_valid(Lx.player):
					var w: LxWick = Lx.player as LxWick
					if not w.dead and not w.is_mounted() and not w.is_dashing() and not w.is_zipping() and Rect2(prev_p - size * 0.5, size).has_point(w.global_position):
						w.global_position += delta_p
						w.last_pos += delta_p
				dirty = true
			elif vel.length_squared() > 16.0:
				vel = -vel * 0.25
		dirty = true
	else:
		_ext_vel = Vector2.ZERO

	if dirty or floating:
		queue_redraw()


func _resolve_raft_step(from_p: Vector2, to_p: Vector2) -> Vector2:
	if _can_raft_float_at(to_p):
		return to_p
	var tx := Vector2(to_p.x, from_p.y)
	if _can_raft_float_at(tx):
		return tx
	var ty := Vector2(from_p.x, to_p.y)
	if _can_raft_float_at(ty):
		return ty
	return from_p


func _can_raft_float_at(p: Vector2) -> bool:
	if region == null or not is_instance_valid(region):
		return true
	var half: Vector2 = size * 0.42
	var b_v: Variant = region.get("bounds")
	if b_v is Rect2 and (b_v as Rect2).has_area():
		if not (b_v as Rect2).grow(-maxf(half.x, half.y)).has_point(p):
			return false
	if region.has_method("tile_at"):
		var tt: String = str(region.call("tile_at", p))
		if tt != "water" and tt != "tide":
			return false
		for corner: Vector2 in [
			Vector2(half.x, 0.0), Vector2(-half.x, 0.0),
			Vector2(0.0, half.y), Vector2(0.0, -half.y),
		]:
			var tc: String = str(region.call("tile_at", p + corner))
			if tc != "water" and tc != "tide":
				return false
	if region.has_method("get_interactables"):
		var my_r := Rect2(p - half, half * 2.0)
		for it_v: Variant in region.call("get_interactables") as Array:
			if it_v == self or not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if it.is_solid() and it.get_solid_rect().intersects(my_r):
				return false
	return true


func _compute_should_float() -> bool:
	var vname: String = tide_var
	if vname.is_empty():
		if region_id.begins_with("lighthouse_"):
			vname = "tower_tide"
		elif region_id.begins_with("locks_") and not lock_side.is_empty():
			vname = "lock_water"
		else:
			vname = "tide"
	var cur_val: String = ""
	if Lx.vars != null:
		cur_val = str(Lx.vars.resolve_var(vname, island_id, region_id, "")).strip_edges().to_lower()
	else:
		cur_val = str(LxToyDraw.world_get_var("island:%d" % island_id, vname, "")).strip_edges().to_lower()
	if vname == "lock_water":
		if lock_side == "west":
			return cur_val == "west_high"
		if lock_side == "east":
			return cur_val == "east_high"
		return cur_val == "west_high" or cur_val == "east_high"
	var level_rank: int = _tide_rank(cur_val)
	var min_rank: int = _tide_rank(tide_min)
	if level_rank >= 0 and min_rank >= 0:
		return level_rank >= min_rank
	# Fallback: float if currently over water/tide tiles
	if region != null and region.has_method("tile_at"):
		var tt: String = str(region.call("tile_at", pos))
		return tt == "water" or tt == "tide"
	return false


static func _tide_rank(v: String) -> int:
	match v:
		"ebb", "low", "0": return 0
		"half", "mid", "1": return 1
		"flood", "high", "2": return 2
	return -1


func _is_harpoon_allowed() -> bool:
	if bool(props.get("allow_harpoon_always", false)):
		return true
	if Lx.state != null and bool(Lx.state.story_flags.get("power_sluice_harpoon", false)):
		return true
	return false


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["pos"] = [pos.x, pos.y]
		d["normal"] = [normal.x, normal.y]
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist:
		if d.has("pos"):
			pos = _parse_vec2(d.get("pos"), origin_pos)
			position = pos.round()
		if d.has("normal"):
			var n: Vector2 = _parse_vec2(d.get("normal"), normal)
			if n.length_squared() > 0.001:
				normal = n.normalized()
	floating = _compute_should_float()
	state = "floating" if floating else "grounded"
	_float_h = 3.0 if floating else 0.0
	queue_redraw()


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var bob: float = 0.0 if (red or not floating or clamped) else roundf(sin(_bob_t) * 0.9)
	var lift: float = roundf(_float_h) + bob
	var hw: float = floorf(size.x * 0.5)
	var hh: float = floorf(size.y * 0.5)
	var c_void: Color = PAL["void"] as Color

	# Water foam collar when floating (greyscale bright rim vs dark grounded shadow)
	if floating:
		var foam_r := Rect2(-hw - 2.0, -hh - 2.0, size.x + 4.0, size.y + 4.0)
		draw_rect(foam_r, Color(PAL["sky"] as Color, 0.45), false, 1.0)
		var wave_off: float = 0.0 if red else float(int(floorf(_bob_t * 2.0)) % 2)
		var fc: Color = PAL["cream"] as Color if _tow_fx_t > 0.0 else PAL["ice"] as Color
		draw_rect(Rect2(-hw - 1.0 + wave_off, -hh - 2.0, 5.0, 1.0), fc)
		draw_rect(Rect2(hw - 4.0 - wave_off, hh + 1.0, 5.0, 1.0), fc)
		draw_rect(Rect2(-hw - 2.0, -2.0 + wave_off, 1.0, 4.0), fc)
		draw_rect(Rect2(hw + 1.0, -2.0 - wave_off, 1.0, 4.0), fc)
	# Drop shadow beneath timber deck (deeper when floating)
	var sh_y: float = 3.0 if floating else 2.0
	draw_rect(Rect2(-hw + 1.0, -hh + sh_y, size.x, size.y), Color(c_void, 0.46))

	# Main weathered timber raft body (clearly pops against dusk stone even when grounded!)
	var deck := Rect2(-hw, -hh - lift, size.x, size.y)
	var base_c: Color = (PAL["wine"] if floating else PAL["plum"]) as Color
	var hi_c: Color = (PAL["gold"] if floating else PAL["apricot"]) as Color
	var plank_hi: Color = (PAL["apricot"] if floating else PAL["stone"]) as Color
	var sh_c: Color = PAL["night"] as Color
	LxPhysDraw.draw_bevel_box(self, deck, base_c, hi_c, sh_c, c_void, PAL["gold"] as Color)
	# Individual horizontal weathered timber planks with sunlit top highlight & dark seam
	var py: float = deck.position.y + 5.0
	var p_idx: int = 0
	while py < deck.end.y - 3.0:
		draw_line(Vector2(deck.position.x + 2.0, py), Vector2(deck.end.x - 3.0, py), sh_c, 1.0)
		draw_line(Vector2(deck.position.x + 2.0, py + 1.0), Vector2(deck.end.x - 3.0, py + 1.0), plank_hi, 1.0)
		var knot_x: float = deck.position.x + (11.0 if p_idx % 2 == 0 else deck.size.x - 13.0)
		draw_rect(Rect2(knot_x, py - 2.0, 2.0, 1.0), sh_c)
		py += 5.0
		p_idx += 1
	# Cross-beam lashings + coiled corner rope bindings (apricot/gold)
	for lx: float in [deck.position.x + 5.0, deck.end.x - 7.0]:
		draw_rect(Rect2(lx, deck.position.y + 1.0, 2.0, deck.size.y - 2.0), PAL["apricot"] as Color)
		draw_rect(Rect2(lx, deck.position.y + 1.0, 1.0, deck.size.y - 3.0), PAL["gold"] as Color)
		draw_rect(Rect2(lx - 1.0, deck.position.y + 2.0, 4.0, 2.0), PAL["cream"] as Color if floating else PAL["gold"] as Color)
		draw_rect(Rect2(lx - 1.0, deck.end.y - 4.0, 4.0, 2.0), PAL["cream"] as Color if floating else PAL["gold"] as Color)
	# Brass bow mooring ring on west rail
	draw_rect(Rect2(deck.position.x - 2.0, deck.position.y + floorf(size.y * 0.5) - 2.0, 3.0, 4.0), c_void)
	draw_rect(Rect2(deck.position.x - 1.0, deck.position.y + floorf(size.y * 0.5) - 1.0, 2.0, 2.0), PAL["gold"] as Color)

	# Mount payload (cargo crate OR blue_transformer mirror turret)
	var center := Vector2(0.0, -lift)
	if mounts == "cargo":
		var cr := Rect2(center - Vector2(8.0, 8.0), Vector2(16.0, 16.0))
		LxPhysDraw.draw_bevel_box(self, cr, PAL["wine"] as Color, PAL["gold"] as Color, PAL["night"] as Color, c_void, PAL["cream"] as Color)
		draw_line(cr.position + Vector2(2.0, 2.0), cr.end - Vector2(3.0, 3.0), PAL["night"] as Color, 1.0)
		draw_line(Vector2(cr.end.x - 3.0, cr.position.y + 2.0), Vector2(cr.position.x + 2.0, cr.end.y - 3.0), PAL["night"] as Color, 1.0)
		draw_rect(Rect2(center - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), PAL["apricot"] as Color)
	elif mounts == "blue_transformer":
		_draw_mounted_transformer(center, c_void)

	# Ballast Clamp locked jaws indicator (high-contrast gold/cream corners)
	if clamped:
		var cc: Color = PAL["cream"] as Color if (red or int(floorf(_bob_t * 3.0)) % 2 == 0) else PAL["gold"] as Color
		for cx: float in [deck.position.x - 1.0, deck.end.x - 3.0]:
			for cy: float in [deck.position.y - 1.0, deck.end.y - 3.0]:
				draw_rect(Rect2(cx, cy, 4.0, 4.0), c_void)
				draw_rect(Rect2(cx + 1.0, cy + 1.0, 2.0, 2.0), cc)
		draw_arc(center, 11.0, 0.0, TAU, 14, Color(PAL["gold"] as Color, 0.78), 1.0)


func _draw_mounted_transformer(center: Vector2, c_void: Color) -> void:
	var lit: bool = _flash_t > 0.0 or _turn_t > 0.0
	var pad := Rect2(center - Vector2(7.0, 7.0), Vector2(14.0, 14.0))
	LxPhysDraw.draw_bevel_box(self, pad, PAL["deep"] as Color, PAL["gold"] as Color, PAL["night"] as Color, c_void)
	# Angled sea-glass mirror bar perpendicular to normal
	var n: Vector2 = normal.normalized()
	var tang := Vector2(-n.y, n.x)
	var a: Vector2 = (center - tang * 6.0).round()
	var b: Vector2 = (center + tang * 6.0).round()
	draw_line(a, b, c_void, 4.0)
	draw_line(a, b, PAL["cream"] as Color if lit else PAL["ice"] as Color, 2.0)
	draw_line(a, b, PAL["sky"] as Color, 1.0)
	# Normal sight pips
	draw_rect(Rect2((center + n * 7.0).round(), Vector2(2.0, 2.0)), PAL["cream"] as Color if lit else PAL["ice"] as Color)
	draw_rect(Rect2((center + n * 10.0).round(), Vector2.ONE), PAL["gold"] as Color)
