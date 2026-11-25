class_name LxPane
extends RefCounted
## Base class for stained-glass lantern panes (Luxel Epic builds).
## Every concrete pane changes how Wick plays with a trade-off or trick.
## No flat percentage buffs, no aim assist, no homing.

var id: String = ""
var island_id: int = 1
var source_kind: String = "dungeon" # dungeon | trial | quest | secret
var lead_cost: int = 1 # 1..3
var name_key: String = ""
var desc_key: String = ""
var tint_key: String = "gold"
var icon_index: int = 0

var _room_counter: int = 0
var _timer: float = 0.0
var _active_flag: bool = false


func reset_runtime() -> void:
	_room_counter = 0
	_timer = 0.0
	_active_flag = false


func on_bolt_fired(_ctx: Dictionary) -> void:
	pass


func on_bolt_hit(_ctx: Dictionary) -> void:
	pass


func on_throw(_ctx: Dictionary) -> void:
	pass


func on_recall(_ctx: Dictionary) -> void:
	pass


func on_zip(_ctx: Dictionary) -> void:
	pass


func on_dash(_ctx: Dictionary) -> void:
	pass


func on_perfect_dodge(_ctx: Dictionary) -> void:
	pass


func on_kill(_ctx: Dictionary) -> void:
	pass


func on_hurt(_ctx: Dictionary) -> void:
	pass


func on_room_enter(_ctx: Dictionary) -> void:
	_room_counter = 0
	_timer = 0.0


func modify_stat(_stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	return value


func tick(dt: float, _ctx: Dictionary) -> void:
	if _timer > 0.0:
		_timer = maxf(0.0, _timer - dt)


func _fx(ctx: Dictionary) -> LxPaneFx:
	var fx_v: Variant = ctx.get("fx", null)
	if is_instance_valid(fx_v) and fx_v is LxPaneFx:
		return fx_v as LxPaneFx
	return LxPaneFx.ensure_in_world()


func _wick(ctx: Dictionary) -> Node2D:
	var w_v: Variant = ctx.get("wick", Lx.player)
	if is_instance_valid(w_v) and w_v is Node2D:
		return w_v as Node2D
	return null


func _world(ctx: Dictionary) -> Node:
	var wr_v: Variant = ctx.get("world", Lx.world)
	if is_instance_valid(wr_v) and wr_v is Node:
		return wr_v as Node
	return null


func _spawn_ring(ctx: Dictionary, pos: Vector2, r0: float, r1: float, dur: float, col_key: String) -> void:
	var w: Node2D = _wick(ctx)
	if w != null and w.has_method("spawn_ring"):
		w.call("spawn_ring", pos, r0, r1, dur, LxPalette.color(col_key), 1.4)


func _spawn_sparks(ctx: Dictionary, pos: Vector2, dir: Vector2, count: int, col_key: String) -> void:
	var w: Node2D = _wick(ctx)
	if w != null and w.has_method("spawn_sparks"):
		w.call("spawn_sparks", pos, dir, count, LxPalette.color(col_key), 24.0, 88.0, 0.22)


func _pulse_aoe(ctx: Dictionary, center: Vector2, radius: float, dmg: float, wear: float, stagger: bool, source: String) -> int:
	var w: Node2D = _wick(ctx)
	var wr: Node = _world(ctx)
	if w == null or wr == null or not w.has_method("world_get_enemies"):
		return 0
	var hits: int = 0
	var enemies: Array = w.call("world_get_enemies", wr) as Array
	for ev: Variant in enemies:
		if not is_instance_valid(ev) or not (ev is Object):
			continue
		var enemy: Object = ev as Object
		if w.has_method("is_entity_alive") and not bool(w.call("is_entity_alive", enemy)):
			continue
		var epos: Vector2 = w.call("get_entity_pos", enemy) as Vector2 if w.has_method("get_entity_pos") else Vector2.ZERO
		if epos.distance_to(center) <= radius:
			var kdir: Vector2 = (epos - center).normalized() if epos.distance_to(center) > 0.1 else Vector2.RIGHT
			var hit: LxHit = LxHit.make(source, dmg, kdir, center, wear, stagger, false, w, false)
			if w.has_method("apply_hit_to_entity"):
				w.call("apply_hit_to_entity", enemy, hit)
			hits += 1
	return hits
