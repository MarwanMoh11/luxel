class_name LxToyCarCoupler
extends LxToy
## Island 6 Railway Car Coupler Latch (bible section 6.2 — Ember Express & Iron Collision).
## Three distinct lock types, each readable in greyscale by shape badge:
## - "bank":     uncoupled only by bounced bolts (Skip wall ricochet, Prism bounce, or curved >=20 deg)
## - "armoured": uncoupled by piercing / armor-cracking hits (Lance, Beam, Sunflare); non-solid so one Lance pierces lined-up latches
## - "pin":      uncoupled by lantern Throw+Recall or Zip pull (full 108px range & +36px railway vault boost with item_coupler_hook)
##
## Props:
##   lock_type: "bank" | "pin" | "armoured" (also accepts "armored"; default "bank")
##   target_id / target_ids: linked doors, mover_walls, logic_gates
##   needs_hook: bool (default false; if true on pin, remote pulls >48px require story_flags["item_coupler_hook"])
##   hook_vault: bool (default true on pin; Zip arrival with item_coupler_hook vaults Wick +36px forward)
##   release_block_id: String (optional push_block pushed by train inertia on uncouple)
##   release_dir: String | [x,y] (default "w")
##   release_speed: float (default 95.0)
##   sets_flag: String (optional story flag set on uncouple)
##   persist: bool (default true)

const HOOK_VAULT_SPEED: float = 225.0
const HOOK_VAULT_SECS: float = 0.16
const CLOSE_PIN_RANGE: float = 52.0

var lock_type: String = "bank"
var needs_hook: bool = false
var hook_vault: bool = true
var release_block_id: String = ""
var release_dir: Vector2 = Vector2.LEFT
var release_speed: float = 95.0
var sets_flag: String = ""
var uncoupled: bool = false
var _clank_t: float = 0.0
var _snap_t: float = 0.0


func _toy_setup() -> void:
	kind = "car_coupler"
	var raw_lt: String = str(props.get("lock_type", "bank")).strip_edges().to_lower()
	if raw_lt == "armored":
		raw_lt = "armoured"
	if raw_lt not in ["bank", "pin", "armoured"]:
		raw_lt = "bank"
	lock_type = raw_lt
	needs_hook = bool(props.get("needs_hook", false))
	hook_vault = bool(props.get("hook_vault", lock_type == "pin"))
	release_block_id = str(props.get("release_block_id", "")).strip_edges()
	release_dir = dir_vec("release_dir", Vector2.LEFT)
	release_speed = maxf(20.0, float(props.get("release_speed", 95.0)))
	sets_flag = str(props.get("sets_flag", "")).strip_edges()
	if not props.has("persist"):
		persist = true
	size = Vector2(18.0, 14.0)
	radius = 12.0
	uncoupled = bool(props.get("uncoupled", false))
	powered = uncoupled
	_clank_t = 0.0
	_snap_t = 0.0
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	uncoupled = false
	_clank_t = 0.0
	_snap_t = 0.0
	set_powered(false)
	emit_power(false)
	queue_redraw()


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return false


func _has_coupler_hook() -> bool:
	return Lx.state != null and bool(Lx.state.story_flags.get("item_coupler_hook", false))


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if uncoupled:
		if lock_type == "pin" and hit.source == LxHit.SOURCE_ZIP:
			_try_hook_vault(hit.dir)
		return false
	match lock_type:
		"bank":
			if _accepts_bank_hit(hit):
				_uncouple(hit.dir)
				return true
			_reject_hit(hit)
			return true
		"armoured":
			if _accepts_armoured_hit(hit):
				_uncouple(hit.dir)
				return true
			_reject_hit(hit)
			return true
		"pin":
			if hit.source in [LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP]:
				if _check_pin_hook_ok():
					_uncouple(hit.dir)
					if hit.source == LxHit.SOURCE_ZIP:
						_try_hook_vault(hit.dir)
				else:
					_reject_hit(hit)
				return true
			if hit.source == LxHit.SOURCE_THROW:
				if not needs_hook and _check_pin_hook_ok():
					_uncouple(hit.dir)
				else:
					_clank_t = 0.24
					_emit_sfx("shield_clang")
					queue_redraw()
				return true
			_reject_hit(hit)
			return true
	return false


func on_lantern_pull(pull_dir: Vector2, source: String = "recall") -> void:
	if not active or lock_type != "pin":
		return
	if source == "zip":
		_try_hook_vault(-pull_dir)
	if uncoupled:
		return
	if not _check_pin_hook_ok():
		_clank_t = 0.30
		_emit_sfx("denied")
		queue_redraw()
		return
	_uncouple(pull_dir)


func _accepts_bank_hit(hit: LxHit) -> bool:
	if hit.source == LxHit.SOURCE_PRISM:
		return true
	if bool(hit.get_meta("wall_bounced", false)):
		return true
	if int(hit.get_meta("bounces", 0)) >= 1:
		return true
	if hit.curve_angle_deg >= 20.0:
		return true
	return false


func _accepts_armoured_hit(hit: LxHit) -> bool:
	if hit.cracks_armour or hit.pierce:
		return true
	if hit.source in [LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]:
		return true
	return false


func _check_pin_hook_ok() -> bool:
	if not needs_hook or _has_coupler_hook():
		return true
	var wp: Vector2 = wick_pos()
	return wp.x > -9000.0 and wp.distance_to(pos) <= CLOSE_PIN_RANGE


func _try_hook_vault(dir_hint: Vector2) -> void:
	if not hook_vault or not _has_coupler_hook():
		return
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		var vdir: Vector2 = dir_hint.normalized() if dir_hint.length_squared() > 0.01 else w.facing.normalized()
		if vdir.length_squared() > 0.01:
			w.launch(vdir, HOOK_VAULT_SPEED, HOOK_VAULT_SECS)


func _reject_hit(hit: LxHit) -> void:
	_clank_t = 0.28
	_emit_sfx("shield_clang")
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_sparks(pos, -hit.dir, 4, PAL["stone"] as Color, 24.0, 68.0, 0.16)
	queue_redraw()


func _uncouple(hit_dir: Vector2) -> void:
	if uncoupled:
		return
	uncoupled = true
	_snap_t = 0.36
	if not sets_flag.is_empty() and Lx.state != null:
		Lx.state.story_flags[sets_flag] = true
	_emit_sfx("coupler_snap")
	_emit_gust(42.0, 46.0)
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		var sc: Color = _badge_color()
		w.spawn_ring(pos, 2.0, 16.0, 0.24, PAL["cream"] as Color, 1.4)
		w.spawn_sparks(pos, hit_dir, 8, sc, 30.0, 88.0, 0.22)
	if Lx.events != null:
		Lx.events.shake_requested.emit(0.03 if LxHudFx.flash_reduced() else 0.07)
	# Optional train-inertia block release (e.g. train_r2 luggage dolly!)
	if not release_block_id.is_empty() and region != null and region.has_method("find_interactable"):
		var blk: Variant = region.call("find_interactable", release_block_id)
		if blk is LxInteractable and is_instance_valid(blk as Object):
			var it_b: LxInteractable = blk as LxInteractable
			if it_b.get("slide_vel") is Vector2:
				it_b.set("slide_vel", release_dir * release_speed)
			elif it_b.has_method("push_block_external"):
				it_b.call("push_block_external", release_dir * release_speed)
	set_powered(true)
	emit_power(true)
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _clank_t > 0.0:
		_clank_t = maxf(0.0, _clank_t - dt)
		dirty = true
	if _snap_t > 0.0:
		_snap_t = maxf(0.0, _snap_t - dt)
		dirty = true
	if dirty:
		queue_redraw()


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["uncoupled"] = uncoupled
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("uncoupled"):
		uncoupled = bool(d.get("uncoupled", uncoupled))
		powered = uncoupled
	queue_redraw()


func _badge_color() -> Color:
	match lock_type:
		"pin": return PAL["apricot"] as Color
		"armoured": return PAL["coral"] as Color
		_: return PAL["gold"] as Color


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var bc: Color = _badge_color()
	var fr: bool = LxHudFx.flash_reduced()
	var rattle: Vector2 = Vector2.ZERO
	if _clank_t > 0.0 and not fr:
		rattle = Vector2(roundf(sin(_clock * 60.0) * 1.5), 0.0)

	# Grounded contact shadow under railway coupler assembly
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 12.0, 4.0)

	# Heavy forged-iron railway coupling jaws & drawbar shanks
	var spread: float = 5.0 if uncoupled else 0.0
	var jaw_c: Color = c_mauve if _clank_t > 0.0 else (c_dusk if not uncoupled else c_night)
	var bevel_c: Color = c_cream if _snap_t > 0.0 else (c_stone if not uncoupled else c_mauve)
	var glint_c: Color = c_ice if not uncoupled else c_stone

	# Outer rail buffer shanks
	var lx: float = roundf(-11.0 - spread + rattle.x)
	var rx: float = roundf(1.0 + spread + rattle.x)
	draw_rect(Rect2(lx - 2.0, -3.0, 3.0, 6.0), c_void)
	draw_rect(Rect2(lx - 1.0, -2.0, 2.0, 4.0), c_night)
	draw_rect(Rect2(lx - 1.0, -2.0, 2.0, 1.0), bevel_c)
	draw_rect(Rect2(rx + 9.0, -3.0, 3.0, 6.0), c_void)
	draw_rect(Rect2(rx + 9.0, -2.0, 2.0, 4.0), c_night)
	draw_rect(Rect2(rx + 9.0, -2.0, 2.0, 1.0), bevel_c)

	# Chunky forged-iron left & right interlocking coupling jaws (10x11 each)
	var left_j := Rect2(lx, -5.0, 10.0, 11.0)
	var right_j := Rect2(rx, -5.0, 10.0, 11.0)
	LxPhysDraw.draw_bevel_box(self, left_j, jaw_c, bevel_c, c_night, c_void, c_stone)
	LxPhysDraw.draw_bevel_box(self, right_j, jaw_c, bevel_c, c_night, c_void, c_stone)
	# Sunlit forged steel top bevel highlight along upper knuckle ridge
	draw_rect(Rect2(left_j.position.x + 2.0, left_j.position.y + 1.0, 6.0, 1.0), glint_c)
	draw_rect(Rect2(right_j.position.x + 2.0, right_j.position.y + 1.0, 6.0, 1.0), glint_c)
	# Inner interlocking jaw hooks
	draw_rect(Rect2(left_j.end.x - 2.0, -2.0, 2.0, 5.0), c_night)
	draw_rect(Rect2(right_j.position.x, -2.0, 2.0, 5.0), c_night)

	if uncoupled:
		# Sprung open coupling gap + crisp jade/lime released indicator + retracted pin stub
		draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), c_void)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), c_night)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), c_jade)
		draw_rect(Rect2(-1.0, -1.0, 1.0, 1.0), c_lime)
		if _snap_t > 0.0:
			var u: float = 1.0 - clampf(_snap_t / 0.36, 0.0, 1.0)
			draw_arc(Vector2.ZERO, roundf(lerpf(5.0, 16.0, u)), 0.0, TAU, 14, Color(bc, 1.0 - u), 1.5)
	else:
		# Glowing molten/gold locked clamp collar gripping the coupled jaws
		var p := Vector2(roundf(rattle.x), 0.0)
		var hot_c: Color = c_cream if (_clank_t > 0.0 or fr) else c_gold
		draw_rect(Rect2(p.x - 5.0, p.y - 6.0, 10.0, 13.0), c_void)
		# Molten forge clamp seam along top & bottom collar
		draw_rect(Rect2(p.x - 4.0, p.y - 5.0, 8.0, 11.0), c_coral)
		draw_rect(Rect2(p.x - 3.0, p.y - 5.0, 6.0, 11.0), c_apr)
		draw_rect(Rect2(p.x - 4.0, p.y - 4.0, 8.0, 9.0), c_gold)
		draw_rect(Rect2(p.x - 4.0, p.y - 4.0, 8.0, 1.0), hot_c)

		# Brass locking pin head protruding above the clamp
		draw_rect(Rect2(p.x - 3.0, p.y - 9.0, 6.0, 4.0), c_void)
		draw_rect(Rect2(p.x - 2.0, p.y - 8.0, 4.0, 2.0), c_gold)
		draw_rect(Rect2(p.x - 2.0, p.y - 8.0, 3.0, 1.0), c_cream)
		draw_rect(Rect2(p.x - 1.0, p.y - 6.0, 2.0, 1.0), c_apr)

		# Distinct greyscale-readable lock_type badge mounted on the locked clamp
		match lock_type:
			"bank": # Bent ricochet chevron (gold/cream)
				draw_rect(Rect2(p.x - 3.0, p.y - 3.0, 6.0, 7.0), c_night)
				draw_rect(Rect2(p.x - 2.0, p.y + 1.0, 2.0, 1.0), bc)
				draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 1.0, 3.0), bc)
				draw_rect(Rect2(p.x, p.y - 2.0, 2.0, 1.0), c_cream)
				draw_rect(Rect2(p.x + 1.0, p.y - 1.0, 1.0, 2.0), bc)
			"pin": # Brass circular hitch ring (apricot/cream)
				draw_rect(Rect2(p.x - 3.0, p.y - 3.0, 6.0, 7.0), c_night)
				draw_arc(p + Vector2(0.0, 0.5), 3.0, 0.0, TAU, 12, c_cream if _clank_t > 0.0 else bc, 1.5)
				draw_rect(Rect2(p.x - 1.0, p.y, 2.0, 1.0), c_cream)
			"armoured": # Heavy beveled octagonal armor plate (coral/wine)
				LxPhysDraw.draw_bevel_box(self, Rect2(p.x - 4.0, p.y - 4.0, 8.0, 9.0), PAL["wine"] as Color, bc, c_night, c_void)
				draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 2.0, 5.0), c_cream if _clank_t > 0.0 else bc)
				draw_rect(Rect2(p.x - 2.0, p.y, 4.0, 1.0), c_cream)
	_draw_signal_pulses()
