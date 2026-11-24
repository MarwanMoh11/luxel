class_name LxLightPlant
extends LxToy
## Seedlight flora that grows under light (`grow`: "bridge" | "bounce" | "wall" | "fruit") and decays in darkness.
## Island 3 rules:
## - Real line-of-sight light occlusion (pillars/crates starve walls into wilting).
## - Blue light (`hit.is_blue()`) frost-pins the plant for `frost_secs` (12 s): bridges/bounce/fruit lock GROWN;
##   dormant walls lock SHUT so Wick's sun-lantern cannot accidentally bloom them.
## - `"dew_ray"` blooms 2x fast; yellow `beam` slices/prunes grown `wall`s (`blocks_sight` defaults false so Beam pierces).
## - `grow: "fruit"` radiates light AND lets Wick pluck a glowing carryable `carry_orb{kind: "seed"}` (or `auto_drop: true`).
## Props: grow ("bridge"|"bounce"|"wall"|"fruit"), secs (float), decay (float; 0=permanent), frost_secs (float, 12.0),
## size [w,h], bounce_dir [x,y], bounce_dist (float), drop_orb (bool), auto_drop (bool), blocks_sight (bool),
## start_growth (float), persist (bool), target_id/target_ids.

enum Stage { SEED, SPROUT, GROWN }

var grow_kind: String = "bridge"
var grow_secs: float = 0.8
var decay_secs: float = 4.0
var frost_secs: float = 12.0
var bounce_dir: Vector2 = Vector2.ZERO
var bounce_dist: float = 56.0
var drop_orb: bool = true
var auto_drop: bool = false
var wall_blocks_sight: bool = false

var growth: float = 0.0
var stage: int = Stage.SEED
var frozen_t: float = 0.0
var frozen_locked_stage: int = Stage.SEED
var _lit_this_tick: bool = false
var _decay_grace: float = 0.0
var _prune_t: float = 0.0
var _bounce_cd: float = 0.0
var _bloom_t: float = 0.0
var _spawned_orb: LxInteractable = null


func _toy_setup() -> void:
	kind = "light_plant"
	grow_kind = str(props.get("grow", "bridge")).strip_edges().to_lower()
	if grow_kind not in ["bridge", "bounce", "wall", "fruit"]:
		grow_kind = "bridge"
	grow_secs = maxf(0.15, float(props.get("secs", 0.8)))
	decay_secs = maxf(0.0, float(props.get("decay", 4.0)))
	frost_secs = maxf(1.0, float(props.get("frost_secs", 12.0)))
	if not props.has("size"):
		size = Vector2(32.0, 16.0) if grow_kind == "bridge" else Vector2(16.0, 16.0)
	radius = maxf(size.x, size.y) * 0.5
	bounce_dir = LxMapFormat.to_vec2(props.get("bounce_dir", Vector2.ZERO), Vector2.ZERO)
	if bounce_dir.length_squared() > 0.001:
		bounce_dir = bounce_dir.normalized()
	bounce_dist = maxf(24.0, float(props.get("bounce_dist", 56.0)))
	drop_orb = bool(props.get("drop_orb", true))
	auto_drop = bool(props.get("auto_drop", false))
	wall_blocks_sight = bool(props.get("blocks_sight", false))
	growth = 1.0 if powered else clampf(float(props.get("start_growth", 0.0)), 0.0, 1.0)
	frozen_t = 0.0
	frozen_locked_stage = Stage.SEED
	_lit_this_tick = false
	_decay_grace = 0.0
	_prune_t = 0.0
	_bounce_cd = 0.0
	_bloom_t = 0.0
	_spawned_orb = null
	_sync_stage(false)
	queue_redraw()


func reset_toy() -> void:
	if persist and stage == Stage.GROWN:
		return
	growth = clampf(float(props.get("start_growth", 0.0)), 0.0, 1.0)
	frozen_t = 0.0
	_lit_this_tick = false
	_decay_grace = 0.0
	_prune_t = 0.0
	_clear_spawned_orb()
	_sync_stage(false)
	queue_redraw()


func is_frozen() -> bool:
	return frozen_t > 0.0


func frost_pin(duration: float = -1.0) -> void:
	if not active:
		return
	var dur: float = duration if duration > 0.0 else frost_secs
	frozen_t = maxf(frozen_t, dur)
	if grow_kind == "wall":
		if stage == Stage.GROWN:
			frozen_locked_stage = Stage.GROWN
			growth = 1.0
		else:
			frozen_locked_stage = Stage.SEED
			growth = 0.0
	else:
		frozen_locked_stage = Stage.GROWN
		growth = 1.0
	_decay_grace = 0.45
	_bloom_t = 0.30
	_sync_stage(true)
	_emit_sfx("mirror_ping")
	queue_redraw()


func on_silk_spark() -> void:
	if not active:
		return
	if is_frozen() and frozen_locked_stage == Stage.SEED:
		return
	growth = 1.0
	_lit_this_tick = true
	_decay_grace = 0.90
	_prune_t = 0.0
	_sync_stage(true)
	queue_redraw()


func on_light(light_radius: float, _source: String) -> void:
	if active and light_radius > 0.0 and _prune_t <= 0.0:
		if is_frozen() and frozen_locked_stage == Stage.SEED:
			return
		_lit_this_tick = true


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.is_blue() and hit.source in ["prism_bolt", "beam", "dew_ray", "bolt"]:
		frost_pin(frost_secs)
		return true
	if grow_kind == "wall" and hit.source in ["beam", "sunflare"] and not hit.is_blue():
		# Yellow Beam / Sunflare slices thorn-walls cleanly back to SEED with brief prune grace
		frozen_t = 0.0
		growth = 0.0
		_prune_t = 1.8
		_decay_grace = 0.0
		_lit_this_tick = false
		_sync_stage(true)
		_emit_sfx("bramble_burn")
		_emit_gust(48.0, 42.0)
		queue_redraw()
		return true
	if hit.source == "dew_ray":
		if is_frozen() and frozen_locked_stage == Stage.SEED:
			return true
		growth = minf(1.0, growth + 0.95)
		_lit_this_tick = true
		_decay_grace = 0.90
		_prune_t = 0.0
		_sync_stage(true)
		queue_redraw()
		return true
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		if is_frozen() and frozen_locked_stage == Stage.SEED:
			return false
		var boost: float = 0.55 if hit.source in ["beam", "sunflare"] else 0.32
		growth = minf(1.0, growth + boost)
		_lit_this_tick = true
		_decay_grace = 0.50
		_prune_t = 0.0
		_sync_stage(true)
		queue_redraw()
		return true
	return false


func interact(actor: Node = null) -> bool:
	if not active or grow_kind != "fruit" or stage != Stage.GROWN or not drop_orb:
		return false
	var orb: LxInteractable = _ensure_seed_orb(pos + Vector2(0.0, 8.0))
	if orb == null:
		return false
	if actor is LxWick and not (actor as LxWick).is_carrying():
		if (actor as LxWick).carry(orb):
			_emit_sfx("seed_bloom")
			return true
	_emit_sfx("spore_pop")
	return true


func get_interact_prompt() -> String:
	if active and grow_kind == "fruit" and stage == Stage.GROWN and drop_orb and not _has_live_orb():
		return "PROMPT_CARRY_ORB"
	return ""


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	if _bounce_cd > 0.0:
		_bounce_cd = maxf(0.0, _bounce_cd - dt)
	if _prune_t > 0.0:
		_prune_t = maxf(0.0, _prune_t - dt)
	if _bloom_t > 0.0:
		_bloom_t = maxf(0.0, _bloom_t - dt)
		queue_redraw()
	if frozen_t > 0.0:
		frozen_t = maxf(0.0, frozen_t - dt)
		if frozen_locked_stage == Stage.GROWN:
			growth = 1.0
		else:
			growth = 0.0
		_lit_this_tick = false
		_sync_stage(false)
		queue_redraw()
		if stage == Stage.GROWN and grow_kind == "bounce" and _bounce_cd <= 0.0:
			_check_bounce_wick()
		return

	var sampled: float = _sample_occluded_light()
	var lit_now: bool = (_lit_this_tick or sampled >= 0.35) and _prune_t <= 0.0
	_lit_this_tick = false
	var prev_g: float = growth
	if lit_now:
		_decay_grace = 0.30
		growth = minf(1.0, growth + dt / grow_secs)
	elif _decay_grace > 0.0:
		_decay_grace = maxf(0.0, _decay_grace - dt)
	elif decay_secs > 0.0 and growth > 0.0:
		growth = maxf(0.0, growth - dt / decay_secs)
	if not is_equal_approx(prev_g, growth):
		_sync_stage(true)
		queue_redraw()
	if stage == Stage.GROWN and grow_kind == "bounce" and _bounce_cd <= 0.0:
		_check_bounce_wick()


func _sample_occluded_light() -> float:
	var best: float = 0.0
	var has_cv: bool = region != null and is_instance_valid(region) and region.has_method("clear_view")
	if region != null and is_instance_valid(region) and region.has_method("get_interactables"):
		for it_v: Variant in (region.call("get_interactables") as Array):
			if not (it_v is LxInteractable) or it_v == self:
				continue
			var it: LxInteractable = it_v as LxInteractable
			if not is_instance_valid(it) or not it.active:
				continue
			var pool: Vector4 = it.get_light_pool()
			if pool.z > 1.0 and pool.w > 0.01:
				var psrc := Vector2(pool.x, pool.y)
				var d: float = pos.distance_to(psrc)
				if d < pool.z and (not has_cv or bool(region.call("clear_view", psrc, pos))):
					best = maxf(best, (1.0 - d / pool.z) * pool.w)
			# Ripened seed carry_orb acts as a mobile seedlight courier (e.g. ant roads in underroot_r3)
			if it.kind == "carry_orb" and str(it.get("orb_kind")) in ["seed", "light"]:
				var d_orb: float = pos.distance_to(it.pos)
				if d_orb < 44.0 and (not has_cv or bool(region.call("clear_view", it.pos, pos))):
					best = maxf(best, (1.0 - d_orb / 44.0) * 0.95)
			if it.has_method("beam_illuminates_point") and bool(it.call("beam_illuminates_point", pos)):
				best = maxf(best, 1.0)
	if Lx.player != null and is_instance_valid(Lx.player):
		var lan_v: Variant = Lx.player.get("lantern")
		if lan_v is Object and is_instance_valid(lan_v):
			var lan: Object = lan_v as Object
			var lpos: Vector2 = lan.get("pos") as Vector2 if lan.get("pos") is Vector2 else (
				(Lx.player as Node2D).global_position if Lx.player is Node2D else Vector2(-9999.0, -9999.0)
			)
			var lrad: float = float(lan.call("get_light_radius")) if lan.has_method("get_light_radius") else 84.0
			var has_l: bool = (not Lx.player.has_method("has_lantern")) or bool(Lx.player.call("has_lantern"))
			if has_l and lrad > 1.0:
				var dl: float = pos.distance_to(lpos)
				if dl < lrad and (not has_cv or bool(region.call("clear_view", lpos, pos))):
					best = maxf(best, (1.0 - dl / lrad) * 1.05)
	return best


func _sync_stage(with_fx: bool) -> void:
	var prev_stage: int = stage
	var next_stage: int = Stage.SEED
	if growth >= 0.999 or (prev_stage == Stage.GROWN and growth > 0.35):
		next_stage = Stage.GROWN
	elif growth >= 0.35:
		next_stage = Stage.SPROUT
	# Anti-crush: never lock a solid thorn-wall directly on top of Wick
	if next_stage == Stage.GROWN and grow_kind == "wall" and prev_stage != Stage.GROWN:
		if rect_at(pos).grow(3.0).has_point(wick_pos()):
			next_stage = Stage.SPROUT
			growth = minf(growth, 0.95)
	stage = next_stage
	z_index = -4 if grow_kind == "bridge" else 0
	if stage == Stage.GROWN and prev_stage != Stage.GROWN:
		_bloom_t = 0.36
		set_powered(true)
		emit_power(true)
		if grow_kind == "fruit" and drop_orb and auto_drop:
			_ensure_seed_orb(pos + Vector2(0.0, 10.0))
		if with_fx:
			_emit_sfx("bridge_rise" if grow_kind == "bridge" else "seed_bloom")
			_emit_gust(48.0, 32.0)
	elif stage != Stage.GROWN and prev_stage == Stage.GROWN:
		set_powered(false)
		emit_power(false)
		if with_fx:
			_emit_sfx("seed_wilt")


func _has_live_orb() -> bool:
	return _spawned_orb != null and is_instance_valid(_spawned_orb) and _spawned_orb.active


func _clear_spawned_orb() -> void:
	if _spawned_orb != null and is_instance_valid(_spawned_orb):
		if region != null and region.has_method("remove_interactable"):
			region.call("remove_interactable", _spawned_orb.id)
		else:
			_spawned_orb.queue_free()
	_spawned_orb = null


func _ensure_seed_orb(at_pos: Vector2) -> LxInteractable:
	if _has_live_orb():
		return _spawned_orb
	if region == null or not region.has_method("spawn_interactable"):
		return null
	var orb_id: String = "%s_seed_orb" % (id if not id.is_empty() else "fruit")
	var existing: Variant = region.call("find_interactable", orb_id) if region.has_method("find_interactable") else null
	if existing is LxInteractable and is_instance_valid(existing):
		_spawned_orb = existing as LxInteractable
		return _spawned_orb
	var spawned: Variant = region.call("spawn_interactable", {
		"id": orb_id,
		"kind": "carry_orb",
		"pos": [at_pos.x, at_pos.y],
		"props": {"kind": "seed"},
	})
	if spawned is LxInteractable:
		_spawned_orb = spawned as LxInteractable
	return _spawned_orb


func _check_bounce_wick() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if w.dead or w.is_zipping() or w.global_position.distance_to(pos) > maxf(size.x, size.y) * 0.55:
		return
	var ldir: Vector2 = bounce_dir
	if ldir.length_squared() <= 0.001:
		ldir = w.velocity.normalized() if w.velocity.length_squared() > 16.0 else w.facing.normalized()
	if ldir.length_squared() <= 0.001:
		ldir = Vector2.UP
	_bounce_cd = 0.45
	_bloom_t = 0.25
	if w.has_method("launch"):
		w.call("launch", ldir, bounce_dist * 3.8, 0.26)
	else:
		w.knock = ldir * (bounce_dist * 3.6)
		w.bounce_t = 0.22
	_emit_sfx("spore_pop")
	queue_redraw()


func is_platform_solid() -> bool:
	return active and grow_kind == "bridge" and stage == Stage.GROWN


func get_platform_rect() -> Rect2:
	return rect_at(pos) if is_platform_solid() else Rect2()


func is_solid() -> bool:
	return active and grow_kind == "wall" and stage == Stage.GROWN


func blocks_sight() -> bool:
	return is_solid() and wall_blocks_sight


func get_solid_rect() -> Rect2:
	return rect_at(pos) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active or grow_kind != "fruit" or stage != Stage.GROWN:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 4.0, 68.0, 1.05)


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["growth"] = growth
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("growth"):
		growth = clampf(float(d["growth"]), 0.0, 1.0)
		_sync_stage(false)
	queue_redraw()


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_pine: Color = PAL["pine"] as Color
	var c_teal: Color = PAL["teal"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_lime: Color = PAL["lime"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var frz: bool = is_frozen()
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)

	if stage == Stage.SEED:
		LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 4.0), 5.0, 2.0)
		draw_rect(Rect2(-4.0, -3.0, 8.0, 7.0), c_void)
		draw_rect(Rect2(-3.0, -2.0, 6.0, 5.0), PAL["deep"] as Color if frz else c_pine)
		draw_rect(Rect2(-2.0, -1.0, 4.0, 3.0), c_sky if frz else c_teal)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 1.0), c_ice if frz else c_jade)
		if frz:
			LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -1.0), 1, true, c_sky, c_ice)
			LxToyDraw.draw_bar(self, Vector2(-6.0, 6.0), 12.0, clampf(frozen_t / frost_secs, 0.0, 1.0), c_ice, c_sky)
		elif growth > 0.05:
			LxToyDraw.draw_bar(self, Vector2(-6.0, 6.0), 12.0, growth, c_lime)
		return

	if stage == Stage.SPROUT:
		LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 4.0), 6.0, 2.0)
		draw_rect(Rect2(-5.0, -5.0, 10.0, 9.0), c_void)
		draw_rect(Rect2(-4.0, -4.0, 8.0, 7.0), c_teal)
		draw_rect(Rect2(-3.0, -3.0, 6.0, 5.0), c_jade)
		draw_rect(Rect2(-1.0, -4.0, 2.0, 3.0), c_lime)
		LxToyDraw.draw_bar(self, Vector2(-6.0, 6.0), 12.0, growth, c_lime)
		return

	match grow_kind:
		"bridge":
			draw_rect(Rect2(x0, y0 + h, w, 2.0), c_void)
			LxToyDraw.draw_bevel_box(
				self, Rect2(x0, y0, w, h),
				PAL["deep"] as Color if frz else c_pine,
				c_sky if frz else c_teal,
				c_ice if frz else c_lime,
				c_void
			)
			var rx: float = x0 + 4.0
			while rx < x0 + w - 4.0:
				draw_rect(Rect2(rx, y0 + 2.0, 2.0, h - 4.0), c_ice if frz else c_jade)
				draw_rect(Rect2(rx, y0 + 2.0, 1.0, 2.0), c_cream if frz else c_lime)
				rx += 6.0
		"bounce":
			LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 2.5)
			draw_rect(Rect2(-4.0, 0.0, 8.0, 6.0), c_void)
			draw_rect(Rect2(-3.0, 1.0, 6.0, 4.0), c_sky if frz else c_teal)
			draw_rect(Rect2(-1.0, 1.0, 2.0, 4.0), c_ice if frz else c_jade)
			LxToyDraw.draw_bevel_box(
				self, Rect2(-8.0, -7.0, 16.0, 9.0),
				PAL["deep"] as Color if frz else c_pine,
				c_sky if frz else c_jade,
				c_ice if frz else c_lime,
				c_void
			)
			draw_rect(Rect2(-6.0, -8.0, 12.0, 2.0), c_ice if frz else c_lime)
			draw_rect(Rect2(-4.0, -6.0, 8.0, 2.0), c_cream)
			if bounce_dir.length_squared() > 0.01:
				LxPixelGlyphs.draw_dir_chevron(self, (bounce_dir * 8.0).round(), bounce_dir, c_cream, c_ice if frz else c_lime)
		"wall":
			draw_rect(Rect2(x0 + 1.0, y0 + h, w - 2.0, 2.0), c_void)
			LxToyDraw.draw_bevel_box(
				self, Rect2(x0, y0 - 3.0, w, h + 3.0),
				PAL["deep"] as Color if frz else c_pine,
				c_sky if frz else c_teal,
				c_ice if frz else c_jade,
				c_void
			)
			draw_rect(Rect2(x0 + 2.0, y0 - 1.0, w - 4.0, 2.0), c_ice if frz else c_lime)
			for tx: float in [x0 + 2.0, -1.0, x0 + w - 4.0]:
				draw_rect(Rect2(tx, y0 - 5.0, 2.0, 2.0), c_void)
				draw_rect(Rect2(tx, y0 - 4.0, 1.0, 2.0), c_ice if frz else c_lime)
			LxToyDraw.draw_shape_glyph(self, Vector2(0.0, 0.0), 1 if frz else 4, true, c_sky if frz else c_pine, c_ice if frz else c_lime)
		"fruit":
			LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 7.0, 2.5)
			draw_rect(Rect2(-3.0, -1.0, 6.0, 7.0), c_void)
			draw_rect(Rect2(-2.0, 0.0, 4.0, 5.0), c_teal)
			draw_rect(Rect2(-6.0, 2.0, 12.0, 3.0), c_pine)
			draw_rect(Rect2(-5.0, 2.0, 10.0, 2.0), c_jade)
			draw_rect(Rect2(-6.0, -10.0, 12.0, 10.0), c_void)
			draw_rect(Rect2(-5.0, -9.0, 10.0, 8.0), c_sky if frz else c_jade)
			draw_rect(Rect2(-4.0, -8.0, 8.0, 6.0), c_ice if frz else c_gold)
			draw_rect(Rect2(-2.0, -7.0, 4.0, 3.0), c_cream)
	if frz:
		LxToyDraw.draw_bar(self, Vector2(-6.0, floorf(h * 0.5) + 3.0), 12.0, clampf(frozen_t / frost_secs, 0.0, 1.0), c_ice, c_sky)
	elif decay_secs > 0.0 and growth < 0.99:
		LxToyDraw.draw_bar(self, Vector2(-6.0, floorf(h * 0.5) + 3.0), 12.0, growth, c_lime)
	_draw_signal_pulses()
