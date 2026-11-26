class_name LxSilkLoomSpool
extends LxToy
## Island 3 brass silk spool stretching conducting & load-bearing silk threads.
## - `taut`: yellow bolt/beam/dew_ray ignites a gold spark travelling along linked threads at `conduct_speed` px/s,
##   blooming crossed `light_plant`s, lighting `brazier`/`timed_brazier`, burning `dry_root_knot`s, and chaining to
##   `linked_to` spools.
## - `frozen`: Blue hit locks spool `ice`-blue for `freeze_secs` (12 s): firebreak (blocks sparks!) & locks hoists UP.
## - `dry: true`: lantern Recall / Zip / Beam (or fire burn after `burn_delay`) snaps thread to `cut`, emitting power
##   (e.g. dropping counterweights / hoisting bridges) and regrowing after `regrow_secs` if > 0.
## - Brass Shuttle (`accepts_shuttle: true`): throwing Wick's lantern within 28 px of this spool stretches ONE live
##   custom conducting thread to the hanging lantern! Shooting the spool fires a spark right down your woven wire.
## Props: linked_to (String or Array[String]), state ("taut"|"slack"|"cut"|"frozen"), conduct_speed (float, 96.0),
## accepts_shuttle (bool), require_shuttle (bool, false), dry (bool), walkable (bool), burn_delay (float, 0.9),
## regrow_secs (float, 0.0), freeze_secs (float, 12.0), power_on_freeze (bool, true), persist (bool), target_id/target_ids.

const SHUTTLE_ATTACH_DIST: float = 28.0
const SPARK_TOUCH_RADIUS: float = 16.0

var linked_to: Array[String] = []
var thread_state: String = "taut"
var initial_state: String = "taut"
var conduct_speed: float = 96.0
var accepts_shuttle: bool = false
var require_shuttle: bool = false
var dry: bool = false
var walkable: bool = false
var burn_delay: float = 0.9
var regrow_secs: float = 0.0
var freeze_secs: float = 12.0
var power_on_freeze: bool = true

var frozen_t: float = 0.0
var regrow_t: float = 0.0
var burn_warn_t: float = 0.0
var shuttle_active: bool = false
var shuttle_end: Vector2 = Vector2.ZERO
var _shuttle_hook_tied: bool = false
var _sparks: Array[Dictionary] = [] # [{to: Vector2, target_id: String, t: float, len: float, hit_ids: Dictionary}]
var _was_lantern_near_on_throw: bool = false
var _last_lantern_state: int = 0


func _toy_setup() -> void:
	kind = "silk_loom_spool"
	radius = maxf(12.0, radius)
	linked_to.clear()
	var raw_link: Variant = props.get("linked_to", [])
	if raw_link is String and not (raw_link as String).strip_edges().is_empty():
		linked_to.append((raw_link as String).strip_edges())
	elif raw_link is Array:
		for item: Variant in (raw_link as Array):
			var sid: String = str(item).strip_edges()
			if not sid.is_empty() and not linked_to.has(sid):
				linked_to.append(sid)
	initial_state = str(props.get("state", "taut")).strip_edges().to_lower()
	if initial_state not in ["taut", "slack", "cut", "frozen"]:
		initial_state = "taut"
	thread_state = initial_state
	conduct_speed = maxf(24.0, float(props.get("conduct_speed", 96.0)))
	accepts_shuttle = bool(props.get("accepts_shuttle", false))
	require_shuttle = bool(props.get("require_shuttle", false))
	dry = bool(props.get("dry", false))
	walkable = bool(props.get("walkable", false))
	burn_delay = maxf(0.0, float(props.get("burn_delay", 0.9)))
	regrow_secs = maxf(0.0, float(props.get("regrow_secs", 0.0)))
	freeze_secs = maxf(1.0, float(props.get("freeze_secs", 12.0)))
	power_on_freeze = bool(props.get("power_on_freeze", not dry))
	frozen_t = freeze_secs if thread_state == "frozen" else 0.0
	regrow_t = 0.0
	burn_warn_t = 0.0
	shuttle_active = false
	shuttle_end = pos
	_shuttle_hook_tied = false
	_sparks.clear()
	_was_lantern_near_on_throw = false
	_last_lantern_state = 0
	powered = (thread_state == "frozen" and power_on_freeze) or (thread_state == "cut" and dry)
	queue_redraw()


func reset_toy() -> void:
	if persist and (thread_state == "cut" or powered):
		return
	thread_state = initial_state
	frozen_t = freeze_secs if thread_state == "frozen" else 0.0
	regrow_t = 0.0
	burn_warn_t = 0.0
	shuttle_active = false
	_shuttle_hook_tied = false
	_sparks.clear()
	set_powered(false)
	emit_power(false)
	queue_redraw()


func is_frozen() -> bool:
	return thread_state == "frozen"


func is_cut() -> bool:
	return thread_state == "cut"


func is_platform_solid() -> bool:
	return active and walkable and thread_state in ["taut", "frozen"]


func get_platform_rect() -> Rect2:
	if not is_platform_solid():
		return Rect2()
	var pts: Array[Vector2] = _linked_endpoints()
	if pts.is_empty():
		return Rect2(pos - Vector2(12.0, 8.0), Vector2(24.0, 16.0))
	var r := Rect2(pos, Vector2.ZERO)
	for p: Vector2 in pts:
		r = r.expand(p)
	return r.grow(8.0)


func freeze_spool(duration: float = -1.0) -> void:
	if not active or thread_state == "cut":
		return
	thread_state = "frozen"
	frozen_t = duration if duration > 0.0 else freeze_secs
	burn_warn_t = 0.0
	_sparks.clear()
	if power_on_freeze:
		set_powered(true)
		emit_power(true)
	_emit_sfx("mirror_ping")
	queue_redraw()


func snap_thread() -> bool:
	if not active or thread_state == "cut" or thread_state == "frozen":
		return false
	thread_state = "cut"
	burn_warn_t = 0.0
	shuttle_active = false
	_sparks.clear()
	if regrow_secs > 0.0:
		regrow_t = regrow_secs
	set_powered(true)
	emit_power(true)
	_emit_sfx("silk_snap")
	_emit_gust(42.0, 32.0)
	queue_redraw()
	return true


func ignite_sparks(from_id: String = "") -> bool:
	if not active or thread_state == "cut" or thread_state == "slack":
		return false
	# Frozen spool acts as a firebreak!
	if thread_state == "frozen":
		_emit_sfx("crystal_clank")
		return false
	if (dry or walkable) and burn_delay > 0.0 and burn_warn_t <= 0.0:
		burn_warn_t = burn_delay
		_emit_sfx("silk_spark_run")
	var launched: int = 0
	for tid: String in linked_to:
		if tid == from_id:
			continue
		var tgt: LxInteractable = _find_target(tid)
		if tgt == null or not tgt.active:
			continue
		# Skip if target is a frozen spool? No, launch spark so it visibly stops at the frozen firebreak!
		var d: float = pos.distance_to(tgt.pos)
		if d > 2.0:
			_sparks.append({"to": tgt.pos, "target_id": tid, "t": 0.0, "len": d, "hit_ids": {get_instance_id(): true}})
			launched += 1
	if shuttle_active and pos.distance_to(shuttle_end) > 4.0:
		_sparks.append({
			"to": shuttle_end, "target_id": "", "t": 0.0,
			"len": pos.distance_to(shuttle_end), "hit_ids": {get_instance_id(): true}, "shuttle": true,
		})
		launched += 1
	if launched > 0:
		_emit_sfx("silk_spark_run")
		queue_redraw()
		return true
	return burn_warn_t > 0.0


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.is_blue() and hit.source in [LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxDewLens.SOURCE_DEW_RAY, LxHit.SOURCE_BOLT]:
		freeze_spool(freeze_secs)
		return true
	if dry and hit.source in [LxHit.SOURCE_RECALL, LxHit.SOURCE_ZIP, LxHit.SOURCE_BEAM, LxHit.SOURCE_SUNFLARE]:
		return snap_thread()
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_BEAM, LxDewLens.SOURCE_DEW_RAY, LxHit.SOURCE_THROW, LxHit.SOURCE_SUNFLARE]:
		return ignite_sparks()
	return false


func on_lantern_pull(_pull_dir: Vector2, _source: String = "recall") -> void:
	if dry and active and thread_state == "taut":
		snap_thread()


func attach_shuttle(end_pos: Vector2) -> bool:
	if not active or not accepts_shuttle or thread_state == "cut":
		return false
	if require_shuttle and not LxRegionLoader.check_flag_static("brass_shuttle"):
		return false
	shuttle_active = true
	shuttle_end = end_pos
	_emit_sfx("silk_spark_run")
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var dirty: bool = false
	# 1. Frozen timer
	if thread_state == "frozen" and frozen_t > 0.0:
		frozen_t = maxf(0.0, frozen_t - dt)
		dirty = true
		if frozen_t <= 0.0:
			thread_state = "taut"
			if power_on_freeze:
				set_powered(false)
				emit_power(false)
			_emit_sfx("prop_rustle")
	# 2. Cut regrow timer
	if thread_state == "cut" and regrow_t > 0.0:
		regrow_t = maxf(0.0, regrow_t - dt)
		dirty = true
		if regrow_t <= 0.0:
			thread_state = "taut"
			set_powered(false)
			emit_power(false)
			_emit_sfx("seed_bloom")
	# 3. Walkable / dry ember warning countdown -> snap
	if burn_warn_t > 0.0:
		burn_warn_t = maxf(0.0, burn_warn_t - dt)
		dirty = true
		if burn_warn_t <= 0.0:
			snap_thread()
	# 4. Brass Shuttle auto-weave tracking on Wick's lantern throw
	if accepts_shuttle and thread_state != "cut":
		if _tick_brass_shuttle():
			dirty = true
	# 5. Advance live fire sparks along threads
	if not _sparks.is_empty():
		_tick_sparks(dt)
		dirty = true
	if dirty:
		queue_redraw()


func _tick_brass_shuttle() -> bool:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return false
	if require_shuttle and not LxRegionLoader.check_flag_static("brass_shuttle"):
		return false
	var w: LxWick = Lx.player as LxWick
	if w.lantern == null or not is_instance_valid(w.lantern):
		return false
	var st: int = int(w.lantern.state)
	var changed: bool = false
	# Detect throw starting while Wick is near this shuttle spool
	if st == LxLantern.State.FLYING and _last_lantern_state == LxLantern.State.IN_HAND:
		if w.global_position.distance_to(pos) <= SHUTTLE_ATTACH_DIST:
			_was_lantern_near_on_throw = true
	if st == LxLantern.State.HANGING and _was_lantern_near_on_throw:
		var end_p: Vector2 = w.lantern.pos
		var hook_it: LxInteractable = _find_shuttle_hook(end_p)
		if hook_it != null:
			end_p = hook_it.pos
			_shuttle_hook_tied = true
		if not shuttle_active or shuttle_end.distance_squared_to(end_p) > 1.0:
			shuttle_active = true
			shuttle_end = end_p
			changed = true
	elif st == LxLantern.State.IN_HAND or st == LxLantern.State.RECALLING:
		_was_lantern_near_on_throw = false
		if shuttle_active and not _shuttle_hook_tied:
			shuttle_active = false
			changed = true
	_last_lantern_state = st
	return changed


func _find_shuttle_hook(at_pos: Vector2) -> LxInteractable:
	if region == null or not region.has_method("get_interactables"):
		return null
	var best: LxInteractable = null
	var best_d: float = 28.0
	for it_v: Variant in (region.call("get_interactables") as Array):
		if not (it_v is LxInteractable):
			continue
		var it: LxInteractable = it_v as LxInteractable
		if not is_instance_valid(it) or not it.active or it == self:
			continue
		if it.kind == "lantern_hook":
			var d: float = it.pos.distance_to(at_pos)
			if d <= best_d:
				best_d = d
				best = it
	return best


func _tick_sparks(dt: float) -> void:
	var inters: Array = region.call("get_interactables") as Array if (region != null and region.has_method("get_interactables")) else []
	var i: int = _sparks.size() - 1
	while i >= 0:
		var sp: Dictionary = _sparks[i]
		var slen: float = maxf(1.0, float(sp["len"]))
		var prev_u: float = clampf(float(sp["t"]) / slen, 0.0, 1.0)
		sp["t"] = float(sp["t"]) + conduct_speed * dt
		var cur_u: float = clampf(float(sp["t"]) / slen, 0.0, 1.0)
		var dest: Vector2 = sp["to"] as Vector2
		var p_a: Vector2 = pos.lerp(dest, prev_u)
		var p_b: Vector2 = pos.lerp(dest, cur_u)
		var hit_ids: Dictionary = sp["hit_ids"] as Dictionary
		# Trigger crossed interactables along the conducting silk
		for it_v: Variant in inters:
			if not (it_v is LxInteractable):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it) or not it.active or it == self:
				continue
			var iid: int = it.get_instance_id()
			if hit_ids.has(iid):
				continue
			var cp: Vector2 = Geometry2D.get_closest_point_to_segment(it.pos, p_a, p_b)
			if cp.distance_to(it.pos) <= maxf(SPARK_TOUCH_RADIUS, it.radius + 4.0):
				hit_ids[iid] = true
				_deliver_spark_to(it)
		if float(sp["t"]) >= slen:
			var tid: String = str(sp.get("target_id", ""))
			if not tid.is_empty():
				var end_it: LxInteractable = _find_target(tid)
				if end_it != null and end_it.active:
					_deliver_spark_to(end_it)
			_sparks.remove_at(i)
		else:
			_sparks[i] = sp
		i -= 1


func _deliver_spark_to(it: LxInteractable) -> void:
	if it is LxSilkLoomSpool:
		var other: LxSilkLoomSpool = it as LxSilkLoomSpool
		if not other.is_frozen() and not other.is_cut():
			other.ignite_sparks(id)
		return
	if it.has_method("on_silk_spark"):
		it.call("on_silk_spark")
		return
	if it.kind in ["brazier", "timed_brazier"]:
		var fire_hit: LxHit = LxHit.make(LxHit.SOURCE_THROW, 1.0, (it.pos - pos).normalized(), pos, 0.0, false, false, self)
		it.on_hit(fire_hit)
		return
	it.on_light(48.0, "silk_spark")


func _find_target(tid: String) -> LxInteractable:
	if region != null and region.has_method("find_interactable"):
		var f: Variant = region.call("find_interactable", tid)
		if f is LxInteractable:
			return f as LxInteractable
	return null


func _linked_endpoints() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for tid: String in linked_to:
		var t: LxInteractable = _find_target(tid)
		if t != null and is_instance_valid(t):
			pts.append(t.pos)
	if shuttle_active:
		pts.append(shuttle_end)
	return pts


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if not _sparks.is_empty():
		var sp0: Dictionary = _sparks[0]
		var u: float = clampf(float(sp0["t"]) / maxf(1.0, float(sp0["len"])), 0.0, 1.0)
		var p: Vector2 = pos.lerp(sp0["to"] as Vector2, u)
		return Vector4(p.x, p.y, 42.0, 0.85)
	if thread_state == "frozen":
		return Vector4(pos.x, pos.y, 26.0, 0.45)
	return Vector4.ZERO


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["thread_state"] = thread_state
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("thread_state"):
		thread_state = str(d["thread_state"])
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var frz: bool = thread_state == "frozen"
	var cut: bool = thread_state == "cut"

	# 1. Draw linked silk threads
	if not cut:
		var line_w: float = 3.0 if walkable else 1.5
		var warn_blink: bool = burn_warn_t > 0.0 and (LxHudFx.flash_reduced() or int(floorf(_clock * 14.0)) % 2 == 0)
		var thread_c: Color = c_ice if frz else (c_coral if warn_blink else (c_apricot if dry else c_cream))
		var edge_c: Color = c_sky if frz else (c_gold if warn_blink else (c_wine if dry else c_stone))
		for tid: String in linked_to:
			var t: LxInteractable = _find_target(tid)
			if t == null or not is_instance_valid(t):
				continue
			var rel: Vector2 = (t.pos - pos).round()
			draw_line(Vector2.ZERO, rel, c_void, line_w + 2.0)
			draw_line(Vector2.ZERO, rel, edge_c, line_w + 0.5)
			draw_line(Vector2.ZERO, rel, thread_c, maxf(1.0, line_w - 0.5))
		if shuttle_active:
			var srel: Vector2 = (shuttle_end - pos).round()
			draw_line(Vector2.ZERO, srel, c_void, 3.0)
			draw_line(Vector2.ZERO, srel, c_gold, 1.5)
			draw_line(Vector2.ZERO, srel, c_cream, 1.0)
	else:
		# Frayed snapped stubs when cut
		draw_line(Vector2(-3.0, -2.0), Vector2(-7.0, 2.0), c_plum, 1.0)
		draw_line(Vector2(3.0, -2.0), Vector2(7.0, 1.0), c_plum, 1.0)

	# 2. Turned brass & wound-silk spool bobbin body
	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 7.0), 8.0, 3.0)
	# Bottom turned brass flange + axle peg
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, 3.0, 16.0, 4.0), c_wine, c_apricot, c_gold, c_void)
	draw_rect(Rect2(-6.0, 4.0, 7.0, 1.0), c_cream if not cut else c_gold)
	# Wound silk core barrel with diagonal glistening thread bands
	var core_r := Rect2(-6.0, -6.0, 12.0, 10.0)
	LxToyDraw.draw_bevel_box(
		self, core_r,
		PAL["deep"] as Color if frz else (c_dusk if cut else c_plum),
		c_sky if frz else (c_dusk if cut else (c_apricot if dry else c_stone)),
		c_ice if frz else (c_plum if cut else c_cream),
		c_void
	)
	if not cut:
		var band_hi: Color = c_cream if (frz or not dry) else c_gold
		var band_sh: Color = c_sky if frz else (c_wine if dry else PAL["mauve"] as Color)
		for wy: float in [-4.0, -1.0, 2.0]:
			draw_line(Vector2(-4.0, wy), Vector2(4.0, wy - 1.0), band_hi, 1.0)
			draw_line(Vector2(-4.0, wy + 1.0), Vector2(4.0, wy), band_sh, 1.0)
	# Top turned brass flange + center finial pin
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, -9.0, 16.0, 4.0), c_wine, c_apricot, c_ice if frz else c_gold, c_void)
	draw_rect(Rect2(-6.0, -8.0, 7.0, 1.0), c_cream)
	draw_rect(Rect2(-2.0, -11.0, 4.0, 2.0), c_void)
	draw_rect(Rect2(-1.0, -10.0, 2.0, 1.0), c_cream if frz else c_gold)
	if accepts_shuttle and not cut:
		# Brass shuttle diamond crest atop spool
		LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -13.0), 1, shuttle_active, c_apricot, c_cream if shuttle_active else c_gold)
	if frz:
		draw_arc(Vector2(0.0, -1.0), 10.0, 0.0, TAU, 14, c_ice, 1.0)
		LxToyDraw.draw_bar(self, Vector2(-7.0, 8.0), 14.0, clampf(frozen_t / freeze_secs, 0.0, 1.0), c_ice, c_sky)
	elif cut and regrow_secs > 0.0:
		LxToyDraw.draw_bar(self, Vector2(-7.0, 8.0), 14.0, 1.0 - clampf(regrow_t / regrow_secs, 0.0, 1.0), c_gold, c_plum)

	# 3. Travelling fire sparks along threads
	for sp: Dictionary in _sparks:
		var u: float = clampf(float(sp["t"]) / maxf(1.0, float(sp["len"])), 0.0, 1.0)
		var rel_p: Vector2 = ((sp["to"] as Vector2) - pos) * u
		var rp: Vector2 = rel_p.round()
		draw_circle(rp, 4.0, Color(c_gold, 0.55))
		draw_rect(Rect2(rp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), c_apricot)
		draw_rect(Rect2(rp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_cream)
	_draw_signal_pulses()
