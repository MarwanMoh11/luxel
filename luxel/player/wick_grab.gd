class_name LxWickGrab
extends RefCounted
## Handles Wick's interact, Zelda grab/push-pull, carry/drop/throw, and vehicle mount/dismount.
## Extracted from LxWick so luxel/player/wick.gd stays <= 600 lines.

const INTERACT_RADIUS: float = 24.0
const GRAB_HOLD_DELAY: float = 0.16
const GRAB_SLIDE_SPEED: float = 58.0


static func is_obj_movable(obj: Object) -> bool:
	return obj != null and is_instance_valid(obj) and obj.has_method("is_movable") and bool(obj.call("is_movable"))


static func get_interact_candidates(wick: LxWick, world_ctx: Node) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for it_var: Variant in wick.world_get_interactables(world_ctx):
		if not is_instance_valid(it_var) or not (it_var is Object):
			continue
		var obj: Object = it_var as Object
		if obj == wick.carried_item:
			continue
		if not obj.has_method("interact") and not is_obj_movable(obj):
			continue
		if obj.get("active") is bool and not bool(obj.get("active")):
			continue
		if obj.get("opened") is bool and bool(obj.get("opened")):
			continue
		if obj.get("collected") is bool and bool(obj.get("collected")):
			continue
		if obj.get("shattered") is bool and bool(obj.get("shattered")):
			continue
		var irad_v: Variant = obj.get("radius")
		var reach: float = maxf(INTERACT_RADIUS, (float(irad_v) if (irad_v is float or irad_v is int) else 0.0) + 6.0)
		var d: float = wick.get_entity_pos(obj).distance_to(wick.global_position)
		if d <= reach:
			var has_prompt: bool = obj.has_method("get_interact_prompt") and not str(obj.call("get_interact_prompt")).is_empty()
			candidates.append({"obj": obj, "d": d, "prompted": has_prompt})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap: bool = bool(a.get("prompted", false))
		var bp: bool = bool(b.get("prompted", false))
		if ap != bp:
			return ap
		return float(a.get("d", INF)) < float(b.get("d", INF))
	)
	return candidates


static func call_interact_on(wick: LxWick, cand_obj: Object, world_ctx: Node) -> bool:
	if cand_obj == null or not is_instance_valid(cand_obj) or not cand_obj.has_method("interact"):
		return false
	var arity: int = wick.get_method_arity(cand_obj, "interact")
	var res: Variant = cand_obj.call("interact", wick) if arity >= 1 else cand_obj.call("interact")
	if res is bool and bool(res):
		if world_ctx != null and world_ctx.has_method("save_interactables_to_state"):
			world_ctx.call("save_interactables_to_state")
		return true
	return false


static func press_interact(wick: LxWick, world_ctx: Node) -> void:
	if wick.dead:
		return
	if wick.is_mounted():
		if wick.mounted_vehicle.has_method("try_dismount"):
			wick.mounted_vehicle.call("try_dismount", wick)
		else:
			wick.dismount()
		return
	if wick.is_carrying():
		wick.drop_carried()
		return
	var cands: Array[Dictionary] = get_interact_candidates(wick, world_ctx)
	if cands.is_empty():
		return
	var top: Object = cands[0].get("obj") as Object
	if is_obj_movable(top):
		wick._interact_held = true
		wick._interact_hold_t = 0.0
		wick._interact_cand = top
		return
	try_interact(wick, world_ctx)


static func release_interact(wick: LxWick, world_ctx: Node) -> void:
	if wick.is_grabbing():
		release_grab(wick, world_ctx)
		wick._interact_held = false
		wick._interact_hold_t = 0.0
		wick._interact_cand = null
		return
	if wick._interact_held and wick._interact_cand != null and is_instance_valid(wick._interact_cand):
		call_interact_on(wick, wick._interact_cand, world_ctx)
	wick._interact_held = false
	wick._interact_hold_t = 0.0
	wick._interact_cand = null


static func tick_grab_hold(wick: LxWick, dt: float, world_ctx: Node) -> void:
	if not wick._interact_held or wick.is_grabbing():
		return
	if wick._interact_cand == null or not is_instance_valid(wick._interact_cand) or not is_obj_movable(wick._interact_cand):
		wick._interact_held = false
		wick._interact_cand = null
		return
	var irad_v: Variant = wick._interact_cand.get("radius")
	var reach: float = maxf(INTERACT_RADIUS, (float(irad_v) if (irad_v is float or irad_v is int) else 0.0) + 8.0)
	if wick.get_entity_pos(wick._interact_cand).distance_to(wick.global_position) > reach:
		wick._interact_held = false
		wick._interact_cand = null
		return
	wick._interact_hold_t += dt
	if wick._interact_hold_t >= GRAB_HOLD_DELAY or wick.get_move_input().length() > 0.25:
		begin_grab(wick, wick._interact_cand, world_ctx)


static func begin_grab(wick: LxWick, block: Object, world_ctx: Node = null) -> bool:
	if wick.dead or not is_obj_movable(block) or wick.is_mounted() or wick.is_carrying():
		return false
	if wick.is_dashing() or wick.is_gliding() or wick.is_zipping() or wick.is_beam_charging():
		return false
	var bpos: Vector2 = wick.get_entity_pos(block)
	var rel: Vector2 = bpos - wick.global_position
	if rel.length_squared() <= 0.0001:
		rel = wick.facing if wick.facing.length_squared() > 0.0001 else Vector2.RIGHT
	if absf(rel.x) >= absf(rel.y):
		wick.grab_axis = Vector2(1.0 if rel.x >= 0.0 else -1.0, 0.0)
	else:
		wick.grab_axis = Vector2(0.0, 1.0 if rel.y >= 0.0 else -1.0)
	wick.grabbed_block = block
	wick.facing = wick.grab_axis
	wick.grab_slide_speed = 0.0
	wick.velocity = Vector2.ZERO
	wick.knock = Vector2.ZERO
	var ctx: Node = world_ctx if world_ctx != null else wick._world_ctx
	var half_b: float = 8.0
	if block.has_method("get_solid_rect"):
		var srect: Rect2 = block.call("get_solid_rect") as Rect2
		if srect.has_area():
			half_b = (srect.size.x * 0.5) if absf(wick.grab_axis.x) > 0.5 else (srect.size.y * 0.5)
	var ideal_pos: Vector2 = bpos - wick.grab_axis * (half_b + LxWick.BODY_RADIUS + 1.5)
	var bid: String = str(block.get("id")) if block.get("id") != null else ""
	if ctx != null and ctx.has_method("collide_ignoring"):
		var checked: Vector2 = ctx.call("collide_ignoring", ideal_pos, LxWick.BODY_RADIUS, bid, false, false) as Vector2
		if checked.distance_to(ideal_pos) < 1.5:
			wick.global_position = checked
	wick.emit_sfx("mirror_turn", bpos, true)
	return true


static func release_grab(wick: LxWick, world_ctx: Node = null) -> void:
	if not wick.is_grabbing():
		wick.grabbed_block = null
		wick.grab_axis = Vector2.ZERO
		wick.grab_slide_speed = 0.0
		return
	var blk: Object = wick.grabbed_block
	var ctx: Node = world_ctx if world_ctx != null else wick._world_ctx
	if blk != null and is_instance_valid(blk) and blk.has_method("move_to"):
		var bpos: Vector2 = wick.get_entity_pos(blk)
		var snapped := Vector2(roundf(bpos.x / 8.0) * 8.0, roundf(bpos.y / 8.0) * 8.0)
		if snapped.distance_to(bpos) <= 3.2 and snapped.distance_to(bpos) > 0.01:
			var bid: String = str(blk.get("id")) if blk.get("id") != null else ""
			var can_snap: bool = true
			if ctx != null and ctx.has_method("can_place_rect") and blk.has_method("get_push_rect_at"):
				var prect: Rect2 = blk.call("get_push_rect_at", snapped) as Rect2
				can_snap = bool(ctx.call("can_place_rect", prect, bid))
			if can_snap:
				blk.call("move_to", snapped)
				if ctx != null and ctx.has_method("collide"):
					wick.global_position = ctx.call("collide", wick.global_position, LxWick.BODY_RADIUS, false, false) as Vector2
		if ctx != null and ctx.has_method("save_interactables_to_state"):
			ctx.call("save_interactables_to_state")
	wick.grabbed_block = null
	wick.grab_axis = Vector2.ZERO
	wick.grab_slide_speed = 0.0


static func tick_grab_move(wick: LxWick, dt: float, world_ctx: Node) -> void:
	if not wick.is_grabbing() or not is_obj_movable(wick.grabbed_block):
		release_grab(wick, world_ctx)
		return
	var blk: Object = wick.grabbed_block
	var move_in: Vector2 = wick.get_move_input()
	var proj: float = move_in.dot(wick.grab_axis)
	if absf(proj) <= 0.15:
		wick.velocity = Vector2.ZERO
		wick.grab_slide_speed = 0.0
		return
	# Ice block shove: pushing triggers a full slide and releases grab cleanly.
	if proj > 0.15 and blk.has_method("start_ice_slide"):
		if bool(blk.call("start_ice_slide", wick.grab_axis)):
			release_grab(wick, world_ctx)
			return
	var step: Vector2 = wick.grab_axis * (signf(proj) * GRAB_SLIDE_SPEED * dt)
	var bpos: Vector2 = wick.get_entity_pos(blk)
	var bnext: Vector2 = bpos + step
	var wnext: Vector2 = wick.global_position + step
	var bid: String = str(blk.get("id")) if blk.get("id") != null else ""
	var ctx: Node = world_ctx if world_ctx != null else wick._world_ctx
	var block_ok: bool = true
	if ctx != null and ctx.has_method("can_place_rect") and blk.has_method("get_push_rect_at"):
		var prect: Rect2 = blk.call("get_push_rect_at", bnext) as Rect2
		block_ok = bool(ctx.call("can_place_rect", prect, bid))
	var wick_ok: bool = true
	if ctx != null and ctx.has_method("collide_ignoring"):
		var wchk: Vector2 = ctx.call("collide_ignoring", wnext, LxWick.BODY_RADIUS, bid, false, false) as Vector2
		if wchk.distance_to(wnext) > 0.35:
			wick_ok = false
	if block_ok and wick_ok:
		if blk.has_method("move_to"):
			blk.call("move_to", bnext)
		wick.global_position = wnext
		wick.velocity = step / maxf(dt, 0.0001)
		wick.grab_slide_speed = wick.velocity.length()
	else:
		wick.velocity = Vector2.ZERO
		wick.grab_slide_speed = 0.0


static func try_interact(wick: LxWick, world_ctx: Node) -> bool:
	var candidates: Array[Dictionary] = get_interact_candidates(wick, world_ctx)
	for cand: Dictionary in candidates:
		var cand_obj: Object = cand.get("obj") as Object
		if call_interact_on(wick, cand_obj, world_ctx):
			return true
	return false


static func carry_item(wick: LxWick, item: Node) -> bool:
	if wick.dead or item == null or not is_instance_valid(item) or wick.is_carrying() or wick.is_grabbing():
		return false
	wick.carried_item = item
	if item.has_method("on_carried"):
		item.call("on_carried", wick)
	wick.catch_anim_t = 0.16
	wick.emit_sfx("lantern_catch", wick.global_position, false)
	return true


static func drop_carried(wick: LxWick, throw_dir: Vector2 = Vector2.ZERO, throw_speed: float = 0.0) -> Node:
	if not wick.is_carrying():
		wick.carried_item = null
		return null
	var item: Node = wick.carried_item
	wick.carried_item = null
	var d: Vector2 = throw_dir.normalized() if throw_dir.length_squared() > 0.01 else (wick.facing.normalized() if wick.facing.length_squared() > 0.01 else Vector2.RIGHT)
	var drop_p: Vector2 = wick.global_position + d * 10.0
	if wick._world_ctx != null and wick._world_ctx.has_method("collide"):
		drop_p = wick._world_ctx.call("collide", drop_p, 5.0, throw_speed > 1.0, throw_speed > 1.0) as Vector2
	if throw_speed > 1.0 and item.has_method("on_thrown"):
		item.call("on_thrown", drop_p, d, throw_speed)
		wick.throw_anim_t = 0.20
		wick.emit_sfx("lantern_throw", wick.global_position, false)
	elif item.has_method("on_dropped"):
		item.call("on_dropped", drop_p)
		wick.emit_sfx("lantern_land", drop_p, true)
	elif item is Node2D:
		(item as Node2D).global_position = drop_p.round()
	return item


static func tick_carried(wick: LxWick) -> void:
	if not wick.is_carrying():
		wick.carried_item = null
		return
	var hold_p: Vector2 = wick.global_position + Vector2(0.0, -14.0)
	if wick.carried_item.has_method("set_carry_pos"):
		wick.carried_item.call("set_carry_pos", hold_p)
	elif wick.carried_item is Node2D:
		(wick.carried_item as Node2D).global_position = hold_p.round()


static func mount_vehicle(wick: LxWick, vehicle: Node) -> bool:
	if wick.dead or vehicle == null or not is_instance_valid(vehicle):
		return false
	if wick.is_grabbing():
		release_grab(wick, wick._world_ctx)
	if wick.is_mounted() and wick.mounted_vehicle != vehicle:
		dismount_vehicle(wick)
	wick.mounted_vehicle = vehicle
	wick.velocity = Vector2.ZERO
	wick.knock = Vector2.ZERO
	wick._launch_t = 0.0
	wick._launch_vel = Vector2.ZERO
	if wick.move_dash != null: wick.move_dash.cancel()
	if wick.move_wings != null: wick.move_wings.stop_glide(false)
	if wick.move_beam != null: wick.move_beam.cancel()
	if wick.move_throw != null: wick.move_throw.cancel_zip()
	if vehicle.has_method("on_mounted"):
		vehicle.call("on_mounted", wick)
	return true


static func dismount_vehicle(wick: LxWick, exit_pos: Vector2 = Vector2.INF) -> bool:
	if not wick.is_mounted():
		wick.mounted_vehicle = null
		return false
	var prev_v: Node = wick.mounted_vehicle
	wick.mounted_vehicle = null
	if exit_pos.is_finite():
		wick.global_position = exit_pos
		wick.last_pos = exit_pos
	if prev_v != null and is_instance_valid(prev_v) and prev_v.has_method("on_dismounted"):
		prev_v.call("on_dismounted", wick)
	return true
