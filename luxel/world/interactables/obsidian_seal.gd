class_name LxObsidianSeal
extends LxInteractable
## Heavy obsidian barrier shattered only by Sunflare.

var shattered: bool = false
var size: Vector2 = Vector2(32.0, 16.0)
var _resonate_t: float = 0.0
var _pulse_stage: int = 0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "obsidian_seal"
	size = _parse_size(props.get("size", [32.0, 16.0]), Vector2(32.0, 16.0))
	radius = maxf(size.x, size.y) * 0.5
	shattered = bool(props.get("shattered", false))
	if Lx.state != null and Lx.state.broken_seals.has(id):
		shattered = true
	active = not shattered
	_resonate_t = 0.0
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if _resonate_t > 0.0:
		_resonate_t = maxf(0.0, _resonate_t - dt)
		queue_redraw()
		return
	if active and not shattered:
		var st: int = int(floorf(_clock * 2.2 + absf(pos.x * 0.03))) % 4
		if st != _pulse_stage:
			_pulse_stage = st
			queue_redraw()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or shattered:
		return false
	if hit.source == "sunflare":
		shattered = true
		active = false
		if Lx.state != null and not id.is_empty() and not Lx.state.broken_seals.has(id):
			Lx.state.broken_seals.append(id)
		if Lx.events != null:
			Lx.events.seal_broken.emit(island_id, id)
			Lx.events.shake_requested.emit(0.24)
		_emit_sfx("seal_shatter")
		_emit_save("seal_" + id)
		_notify_linked_targets(true)
		queue_redraw()
		return true
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "dash"]:
		_resonate_t = 0.22
		_emit_sfx("shield_clang")
		queue_redraw()
		return true
	return false


func is_solid() -> bool:
	return active and not shattered


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - size * 0.5, size)


func save_state() -> Dictionary:
	return {"active": active, "shattered": shattered}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	shattered = bool(d.get("shattered", shattered))
	if Lx.state != null and Lx.state.broken_seals.has(id):
		shattered = true
	active = not shattered
	queue_redraw()


func _draw() -> void:
	if shattered or not active:
		return
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var x0: float = floorf(-w * 0.5)
	var y0: float = floorf(-h * 0.5)
	var res: bool = _resonate_t > 0.0
	draw_rect(Rect2(x0 + 1.0, y0, w - 2.0, h), PAL["void"])
	draw_rect(Rect2(x0, y0 + 2.0, w, h - 4.0), PAL["void"])
	draw_rect(Rect2(x0 + 2.0, y0 + 1.0, w - 4.0, h - 2.0), PAL["night"])
	draw_rect(Rect2(x0 + 1.0, y0 + 3.0, w - 2.0, h - 6.0), PAL["night"])
	draw_rect(Rect2(x0 + 3.0, y0 + 2.0, floorf(w * 0.45), floorf(h * 0.55)), PAL["dusk"])
	draw_rect(Rect2(x0 + floorf(w * 0.5), y0 + 2.0, floorf(w * 0.35), floorf(h * 0.45)), PAL["dusk"])
	draw_rect(Rect2(x0 + 3.0, y0 + 2.0, floorf(w * 0.4), 1.0), PAL["mauve"])
	draw_rect(Rect2(x0 + 2.0, y0 + 3.0, 1.0, floorf(h * 0.45)), PAL["mauve"])
	draw_rect(Rect2(x0 + floorf(w * 0.58), y0 + 2.0, floorf(w * 0.25), 1.0), PAL["mauve"])
	var v_outer: Color = (PAL["coral"] if res else PAL["wine"]) as Color
	var v_mid: Color = (PAL["gold"] if res else (PAL["apricot"] if _pulse_stage < 2 else PAL["coral"])) as Color
	var v_hot: Color = (PAL["cream"] if res else PAL["gold"]) as Color
	var veins: Array = [
		[Vector2(0.0, 0.0), Vector2(floorf(-w * 0.24), -2.0), Vector2(floorf(-w * 0.42), floorf(-h * 0.32))],
		[Vector2(0.0, 0.0), Vector2(floorf(w * 0.22), -1.0), Vector2(floorf(w * 0.42), floorf(-h * 0.28))],
		[Vector2(0.0, 0.0), Vector2(floorf(-w * 0.2), 2.0), Vector2(floorf(-w * 0.38), floorf(h * 0.34))],
		[Vector2(0.0, 0.0), Vector2(floorf(w * 0.24), 2.0), Vector2(floorf(w * 0.4), floorf(h * 0.32))],
	]
	for raw_br: Variant in veins:
		var br: Array = raw_br as Array
		var a: Vector2 = br[0] as Vector2
		var b: Vector2 = br[1] as Vector2
		var c: Vector2 = br[2] as Vector2
		draw_line(a, b, v_outer, 2.0)
		draw_line(b, c, v_outer, 1.0)
		draw_line(a, b, v_mid, 1.0)
		draw_rect(Rect2(b, Vector2(1.0, 1.0)), v_hot)
	draw_rect(Rect2(-5.0, -5.0, 10.0, 10.0), PAL["void"])
	draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), PAL["night"])
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), v_outer)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), v_mid)
	draw_rect(Rect2(0.0, -5.0, 1.0, 2.0), v_hot)
	draw_rect(Rect2(0.0, 3.0, 1.0, 2.0), v_hot)
	draw_rect(Rect2(-5.0, 0.0, 2.0, 1.0), v_hot)
	draw_rect(Rect2(3.0, 0.0, 2.0, 1.0), v_hot)
	if res:
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - 2.0, h - 2.0), PAL["gold"], false, 1.0)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), PAL["cream"])
	else:
		var core_c: Color = (PAL["cream"] if _pulse_stage == 0 else PAL["gold"]) as Color
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), core_c)
