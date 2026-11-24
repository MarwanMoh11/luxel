class_name LxTrainingDummy
extends LxInteractable
## Wick House Training Dummy: absorbs any player hit and displays damage numbers as crisp glowing pips!

var _hit_t: float = 0.0
var _recoil_dir: Vector2 = Vector2.RIGHT
var _pips: Array[Dictionary] = [] # {pips: int, heavy: bool, age: float, pos: Vector2}
var total_hits: int = 0
var last_damage: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "training_dummy"
	radius = 11.0
	queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if not active or hit == null:
		return false
	total_hits += 1
	last_damage = hit.damage
	_hit_t = 0.28
	_recoil_dir = hit.dir.normalized() if hit.dir.length_squared() > 0.01 else Vector2.RIGHT
	var pip_count: int = clampi(roundi(hit.damage * 4.0), 1, 12)
	_pips.append({
		"pips": pip_count,
		"heavy": hit.is_heavy() or hit.is_blue(),
		"age": 0.0,
		"life": 1.15,
		"dx": float((total_hits % 3) - 1) * 4.0,
	})
	if _pips.size() > 6:
		_pips.remove_at(0)
	_emit_sfx("heavy_hit" if hit.is_heavy() else "bolt_chip")
	if Lx.events != null:
		Lx.events.enemy_hit.emit(self, hit, 1)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _hit_t > 0.0:
		_hit_t = maxf(0.0, _hit_t - dt)
		dirty = true
	for i: int in range(_pips.size() - 1, -1, -1):
		_pips[i]["age"] = float(_pips[i]["age"]) + dt
		if float(_pips[i]["age"]) >= float(_pips[i]["life"]):
			_pips.remove_at(i)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	_draw_ground_shadow(7.0, 2.5, Vector2(0.0, 1.0))
	var tilt: float = 0.0
	if _hit_t > 0.0:
		tilt = roundf(sin(_hit_t * 36.0) * 2.5 * signf(_recoil_dir.x if absf(_recoil_dir.x) > 0.1 else 1.0))
	# Post & burlap lantern-target dummy
	draw_rect(Rect2(-2.0, -4.0, 4.0, 6.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-1.0, -3.0, 2.0, 4.0), LxPalette.PAL["dusk"])
	var body_c: Color = LxPalette.PAL["cream"] if _hit_t > 0.20 else LxPalette.PAL["stone"]
	draw_rect(Rect2(-6.0 + tilt, -14.0, 12.0, 10.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-5.0 + tilt, -13.0, 10.0, 8.0), body_c)
	# Crossbar arms & brass bullseye
	draw_rect(Rect2(-9.0 + tilt, -11.0, 18.0, 2.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(-2.0 + tilt, -11.0, 4.0, 4.0), LxPalette.PAL["coral"])
	draw_rect(Rect2(-1.0 + tilt, -10.0, 2.0, 2.0), LxPalette.PAL["gold"])
	# Head lantern cap
	draw_rect(Rect2(-4.0 + tilt, -20.0, 8.0, 6.0), LxPalette.PAL["night"])
	draw_rect(Rect2(-3.0 + tilt, -19.0, 6.0, 4.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(-2.0 + tilt, -18.0, 1.0, 1.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(1.0 + tilt, -18.0, 1.0, 1.0), LxPalette.PAL["gold"])

	# Floating damage pips!
	for entry: Dictionary in _pips:
		var age: float = float(entry["age"])
		var life: float = float(entry["life"])
		var u: float = clampf(age / maxf(life, 0.01), 0.0, 1.0)
		var count: int = int(entry["pips"])
		var heavy: bool = bool(entry["heavy"])
		var col: Color = LxPalette.PAL["gold"] if heavy else LxPalette.PAL["cream"]
		if u > 0.72:
			col = LxPalette.PAL["mauve"]
		var py: float = roundf(-25.0 - u * 16.0)
		var row_w: float = float(count * 3 - 1)
		var px0: float = roundf(float(entry["dx"]) - row_w * 0.5)
		draw_rect(Rect2(px0 - 1.0, py - 1.0, row_w + 2.0, 4.0), LxPalette.PAL["void"])
		for p: int in range(count):
			draw_rect(Rect2(px0 + float(p * 3), py, 2.0, 2.0), col)
