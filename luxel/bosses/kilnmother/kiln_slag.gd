class_name LxKilnSlagHelper
extends RefCounted
## Helper for upgraded Kilnmother on LxBossBase (Island 6 Bible §4.8):
## Tracks lobbed molten/cooled slag boulders, triggers room slag_pourers,
## cools boulders on Blue hits, computes 4-Way Furnace Cross occlusion by cooled boulders
## or frozen slag_slimes, and renders boulders + P2 cracked outer lava channels.

const PAL: Dictionary = LxPalette.PAL
const MAX_BOULDERS: int = 2
const BOULDER_TTL: float = 18.0

var boulders: Array[Dictionary] = []
var lob_targets: Array[Vector2] = []
var rim_cracked: bool = false


func reset() -> void:
	boulders.clear()
	lob_targets.clear()
	rim_cracked = false


func trigger_room_pourers(world_ctx: Node) -> void:
	if world_ctx == null or not is_instance_valid(world_ctx) or not world_ctx.has_method("get_interactables"):
		return
	for it_v: Variant in (world_ctx.call("get_interactables") as Array):
		if it_v is LxInteractable and (it_v as LxInteractable).kind == "slag_pourer" and (it_v as Object).has_method("trigger_pour"):
			(it_v as Object).call("trigger_pour")


func pick_lob_targets(boss_pos: Vector2, target_pos: Vector2, world_ctx: Node) -> Array[Vector2]:
	var to_t: Vector2 = target_pos - boss_pos
	var dir: Vector2 = to_t.normalized() if to_t.length() > 0.1 else Vector2.DOWN
	var perp := Vector2(-dir.y, dir.x)
	var mid: Vector2 = boss_pos + dir * clampf(to_t.length() * 0.65, 36.0, 82.0)
	var p1: Vector2 = _clamp_to_world(mid + perp * 26.0, world_ctx)
	var p2: Vector2 = _clamp_to_world(mid - perp * 26.0, world_ctx)
	lob_targets = [p1, p2]
	return lob_targets


func commit_lobs(owner: LxEnemyBrain) -> void:
	for tp: Vector2 in lob_targets:
		while boulders.size() >= MAX_BOULDERS:
			boulders.pop_front()
		boulders.append({"pos": tp, "cooled": false, "ttl": BOULDER_TTL})
		if owner != null and owner.has_method("_has_player") and bool(owner.call("_has_player")):
			var wp: Vector2 = owner.call("_get_wick_pos") as Vector2
			if wp.distance_to(tp) <= 22.0:
				var push: Vector2 = (wp - tp).normalized() if wp.distance_to(tp) > 0.1 else Vector2.DOWN
				if owner.has_method("emit_boss_damage"):
					owner.call("emit_boss_damage", push, 0.5, "slag_lob", tp, true)
				else:
					owner.call("_emit_player_hit", push, 0.5)
	lob_targets.clear()


func tick(dt: float, owner: LxEnemyBrain) -> void:
	var wick_node: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	for i: int in range(boulders.size() - 1, -1, -1):
		var b: Dictionary = boulders[i]
		b["ttl"] = float(b["ttl"]) - dt
		if float(b["ttl"]) <= 0.0:
			boulders.remove_at(i)
			continue
		if not bool(b["cooled"]) and wick_node != null:
			var bp: Vector2 = b["pos"] as Vector2
			for bi: int in range(wick_node.bolts.size() - 1, -1, -1):
				var bv: Variant = wick_node.bolts[bi]
				if bv is Object and (bv.get("pos") as Vector2).distance_to(bp) <= 11.0:
					if str(bv.get("light_color")).to_lower() == LxHit.COLOR_BLUE:
						b["cooled"] = true
						b["ttl"] = BOULDER_TTL
						if owner != null and owner.has_method("_emit_sfx"):
							owner.call("_emit_sfx", "magma_crack")
						wick_node.bolts.remove_at(bi)
						break


func arm_length_with_cover(origin: Vector2, dir: Vector2, max_len: float, half_w: float, world_ctx: Node, owner: LxEnemyBrain) -> float:
	var best: float = max_len
	var covers: Array[Vector2] = []
	for b: Dictionary in boulders:
		if bool(b["cooled"]):
			covers.append(b["pos"] as Vector2)
	if world_ctx != null and is_instance_valid(world_ctx):
		if world_ctx.has_method("get_interactables"):
			for it_v: Variant in (world_ctx.call("get_interactables") as Array):
				if it_v is LxInteractable and (it_v as LxInteractable).kind == "push_block" and bool((it_v as Object).get("cooled")):
					covers.append((it_v as LxInteractable).pos)
		if world_ctx.has_method("get_enemies"):
			for ev: Variant in (world_ctx.call("get_enemies") as Array):
				if ev is LxEnemyBrain and ev != owner and (ev as LxEnemyBrain).is_alive() and (ev as Object).has_method("is_frozen_block") and bool((ev as Object).call("is_frozen_block")):
					covers.append((ev as LxEnemyBrain).pos)
	for cp: Vector2 in covers:
		var rel: Vector2 = cp - origin
		var proj: float = rel.dot(dir)
		if proj > 16.0 and proj < best and (rel - dir * proj).length() <= half_w + 5.0:
			best = proj
	return best


func draw_slag(ci: CanvasItem, boss_pos: Vector2, off: Vector2, tell_prog: float, is_lob_tell: bool, clock: float) -> void:
	if rim_cracked:
		for sx: float in [-112.0, 112.0]:
			var rp: Vector2 = (off + Vector2(sx, -42.0)).round()
			ci.draw_rect(Rect2(rp, Vector2(8.0, 84.0)), Color(PAL["coral"] as Color, 0.24), true)
			ci.draw_rect(Rect2(rp, Vector2(8.0, 84.0)), Color(PAL["gold"] as Color, 0.55), false, 1.0)
	if is_lob_tell:
		for tp: Vector2 in lob_targets:
			LxBossTelegraphFx.draw_ground_danger_ring(ci, (tp - boss_pos) + off, 22.0, tell_prog, clock, "coral", "gold")
	for b: Dictionary in boulders:
		var bp: Vector2 = ((b["pos"] as Vector2) - boss_pos + off).round()
		var cool: bool = bool(b["cooled"])
		ci.draw_circle(bp, 9.0, PAL["night"] as Color)
		ci.draw_circle(bp, 7.2, (PAL["mauve"] if cool else PAL["coral"]) as Color)
		ci.draw_arc(bp, 7.8, 0.0, TAU, 14, (PAL["ice"] if cool else PAL["gold"]) as Color, 1.4)


static func _clamp_to_world(p: Vector2, world_ctx: Node) -> Vector2:
	if world_ctx != null and is_instance_valid(world_ctx) and world_ctx.has_method("get_bounds"):
		var b: Rect2 = (world_ctx.call("get_bounds") as Rect2).grow(-28.0)
		if b.has_area():
			return Vector2(clampf(p.x, b.position.x, b.end.x), clampf(p.y, b.position.y, b.end.y))
	return p
