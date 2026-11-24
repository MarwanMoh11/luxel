class_name LxBossAdds
extends RefCounted
## Director-compliant boss add wave manager.
## All spawned adds share the boss's LxAttackDirector (peak committing attackers <= 1),
## telegraph with summon rings >= 0.55 s, spawn away from Wick, and clean up cleanly on reset/death.

const MIN_SUMMON_DELAY: float = 0.55
const MIN_WICK_DIST: float = 36.0

var boss: LxEnemyBrain = null
var _pending: Array[Dictionary] = []
var _live_adds: Array[LxEnemyBrain] = []
var _clock: float = 0.0


func _init(p_boss: LxEnemyBrain = null) -> void:
	boss = p_boss


func clear_all() -> void:
	_pending.clear()
	for a: LxEnemyBrain in _live_adds:
		if a != null and is_instance_valid(a):
			if a.director != null:
				a.director.unregister(a)
			a.queue_free()
	_live_adds.clear()


func alive_count() -> int:
	_prune_dead()
	return _live_adds.size()


func pending_count() -> int:
	return _pending.size()


func get_adds() -> Array[LxEnemyBrain]:
	_prune_dead()
	return _live_adds


func queue_wave(specs: Array[Dictionary], summon_delay: float = 0.75, max_alive: int = 3) -> int:
	_prune_dead()
	var room_left: int = maxi(0, max_alive - (_live_adds.size() + _pending.size()))
	if room_left <= 0:
		return 0
	var delay: float = maxf(MIN_SUMMON_DELAY, summon_delay)
	var added: int = 0
	var arena: Rect2 = boss.call("get_arena_rect") as Rect2 if (boss != null and boss.has_method("get_arena_rect")) else Rect2()
	var wp: Vector2 = boss.call("_get_wick_pos") as Vector2 if (boss != null and boss.has_method("_get_wick_pos")) else Vector2(-9999.0, -9999.0)

	for raw: Dictionary in specs:
		if added >= room_left:
			break
		var s: Dictionary = raw.duplicate(true)
		var pt: Vector2 = LxEnemyBrain._to_vec2(s.get("pos", boss.home if boss != null else Vector2.ZERO))
		if arena.has_area():
			var inner: Rect2 = arena.grow(-18.0)
			if inner.has_area():
				pt = Vector2(clampf(pt.x, inner.position.x, inner.end.x), clampf(pt.y, inner.position.y, inner.end.y))
		# Never materialize directly on top of Wick
		if pt.distance_to(wp) < MIN_WICK_DIST:
			var away: Vector2 = (pt - wp).normalized() if pt.distance_to(wp) > 0.1 else Vector2.RIGHT
			pt = wp + away * MIN_WICK_DIST
			if arena.has_area():
				var inner2: Rect2 = arena.grow(-18.0)
				if inner2.has_area():
					pt = Vector2(clampf(pt.x, inner2.position.x, inner2.end.x), clampf(pt.y, inner2.position.y, inner2.end.y))
		s["pos"] = pt
		if not s.has("home"):
			s["home"] = pt
		if boss != null:
			s["island_id"] = boss.island_id
			s["zone"] = boss.zone
		_pending.append({
			"spec": s, "pos": pt, "elapsed": 0.0, "dur": delay,
			"col": str(s.get("summon_color", "gold")),
		})
		added += 1
	return added


func tick(dt: float, world_ctx: Node) -> void:
	_clock += dt
	_prune_dead()
	for i: int in range(_pending.size() - 1, -1, -1):
		var item: Dictionary = _pending[i]
		item["elapsed"] = float(item["elapsed"]) + dt
		if float(item["elapsed"]) >= float(item["dur"]):
			_spawn_now(item["spec"] as Dictionary, world_ctx)
			_pending.remove_at(i)


func _spawn_now(spec: Dictionary, world_ctx: Node) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_alive():
		return
	var dir: LxAttackDirector = boss.director
	var spawned: LxEnemyBrain = null
	if world_ctx != null and is_instance_valid(world_ctx):
		if world_ctx.has_method("spawn_enemy"):
			var res: Variant = world_ctx.call("spawn_enemy", spec)
			if res is LxEnemyBrain:
				spawned = res as LxEnemyBrain
		elif world_ctx.has_method("add_enemy_node"):
			var kind: String = str(spec.get("kind", "warden"))
			spawned = LxEnemyFactory.create(kind, spec, dir, world_ctx)
			if spawned != null:
				world_ctx.call("add_enemy_node", spawned)
	if spawned == null and boss.get_parent() != null:
		var kind2: String = str(spec.get("kind", "warden"))
		spawned = LxEnemyFactory.create(kind2, spec, dir, world_ctx)
		if spawned != null:
			boss.get_parent().add_child(spawned)
	if spawned != null:
		spawned.director = dir
		if dir != null:
			dir.register(spawned)
		_live_adds.append(spawned)
		LxDamageFx.boss_impact(spawned.pos, 0.08, 42.0, 48.0, 52.0, 1.25, 0.25)


func draw_summons(ci: CanvasItem, origin_world: Vector2) -> void:
	var off: Vector2 = -origin_world
	for item: Dictionary in _pending:
		var prog: float = clampf(float(item["elapsed"]) / maxf(float(item["dur"]), 0.05), 0.0, 1.0)
		LxBossTelegraphFx.draw_ground_summon_ring(ci, (item["pos"] as Vector2) + off, 16.0, prog, _clock, str(item["col"]))


func _prune_dead() -> void:
	for i: int in range(_live_adds.size() - 1, -1, -1):
		var a: LxEnemyBrain = _live_adds[i]
		if a == null or not is_instance_valid(a) or not a.is_alive():
			_live_adds.remove_at(i)
