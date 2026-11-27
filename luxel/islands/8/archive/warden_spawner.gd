class_name LxArchiveWardenSpawner
extends LxToy
## Bell-Call Pedestal for archive_r2 (Memory I - Bell Isle): prevents softlocks if the
## patrolling Memory Warden is defeated before the enemy pressure plate latches.
## Ringing any Dawn bell (`on_ring("dawn", ...)`) respawns a fresh Memory Warden on the
## north patrol track whenever `mem_1_lit` is still unset and no warden is alive.

var spawn_pos: Vector2 = Vector2(248.0, 88.0)
var route_pts: Array = [[192.0, 88.0], [296.0, 88.0]]
var _cd: float = 0.0
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "archive_warden_spawner"
	radius = 12.0
	z_index = -3
	spawn_pos = LxMapFormat.to_vec2(props.get("spawn_pos", [pos.x, pos.y]), pos)
	var raw_r: Variant = props.get("route", [])
	if raw_r is Array and not (raw_r as Array).is_empty():
		route_pts = (raw_r as Array).duplicate(true)
	_cd = 0.0
	_pulse_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()


func on_ring(tone: String, _dir: Vector2) -> void:
	if not active or _cd > 0.0 or tone != "dawn":
		return
	if region == null or not is_instance_valid(region):
		return
	if region.has_method("is_flag_set") and bool(region.call("is_flag_set", "mem_1_lit")):
		return
	if _has_live_warden():
		return
	_cd = 2.0
	_pulse_t = 0.65
	if region.has_method("spawn_enemy"):
		region.call("spawn_enemy", {
			"id": "warden_r2_recall_%d" % Time.get_ticks_msec(),
			"kind": "warden",
			"pos": [spawn_pos.x, spawn_pos.y],
			"route": route_pts,
			"zone": "archive_mem1",
			"leash": 112.0,
		})
	_emit_sfx("clockwork_chime")
	queue_redraw()


func _has_live_warden() -> bool:
	if region == null or not region.has_method("get_enemies"):
		return false
	for ev: Variant in (region.call("get_enemies") as Array):
		if ev is LxEnemyBrain and is_instance_valid(ev):
			var eb: LxEnemyBrain = ev as LxEnemyBrain
			if eb.kind == "warden" and eb.is_alive():
				return true
	return false


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var armed: bool = active and _cd <= 0.0
	draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), c_void)
	draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), c_dusk if armed else c_night)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), c_gold if armed else c_dusk, false, 1.0)
	# Crisp mini bell silhouette (greyscale-distinct armed vs cooling down)
	if armed:
		draw_rect(Rect2(-1.0, -3.0, 2.0, 2.0), c_gold)
		draw_rect(Rect2(-2.0, -1.0, 4.0, 3.0), c_gold)
		draw_rect(Rect2(-3.0, 2.0, 6.0, 1.0), c_cream)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 1.0), c_cream)
	else:
		draw_rect(Rect2(-2.0, -1.0, 4.0, 2.0), c_void)
		draw_rect(Rect2(-1.0, 0.0, 2.0, 1.0), c_dusk)
	if _pulse_t > 0.0:
		var u: float = 1.0 - clampf(_pulse_t / 0.65, 0.0, 1.0)
		var pa: float = (1.0 - u) * (0.50 if fred else 0.85)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, 24.0, u)), 0.0, TAU, 16, Color(c_gold, pa), 1.0)
