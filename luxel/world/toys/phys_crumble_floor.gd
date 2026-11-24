class_name LxPhysCrumbleFloor
extends LxToy
## Fragile stone slab over pit/void: SOLID -> SHAKING (delay) -> GONE (respawn) -> SOLID.
## Counts as platform support while intact or shaking; drops out when GONE.

enum State { SOLID, SHAKING, GONE }

var delay: float = 0.75
var respawn: float = 3.5
var state: State = State.SOLID
var timer: float = 0.0


func _toy_setup() -> void:
	kind = "crumble_floor"
	size = _parse_size(props.get("size", [24.0, 24.0]), Vector2(24.0, 24.0))
	radius = maxf(size.x, size.y) * 0.5
	delay = maxf(0.15, float(props.get("delay", 0.75)))
	respawn = maxf(0.5, float(props.get("respawn", 3.5)))
	state = State.SOLID
	timer = 0.0
	z_index = LxPhysDraw.floor_z(region, -4)
	queue_redraw()


func is_platform_solid() -> bool:
	return active and state != State.GONE


func get_platform_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_platform_solid() else Rect2()


func trigger_crumble() -> void:
	if state == State.SOLID:
		state = State.SHAKING
		timer = delay
		_emit_sfx("bolt_wall")
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	if not active:
		return
	var rect := Rect2(pos - size * 0.5, size)
	match state:
		State.SOLID:
			if Lx.player is LxWick and is_instance_valid(Lx.player):
				var w: LxWick = Lx.player as LxWick
				if not w.dead and not w.is_dashing() and not w.is_gliding() and not w.is_zipping() and not w.is_launched():
					if rect.has_point(w.global_position):
						trigger_crumble()
		State.SHAKING:
			timer -= dt
			if timer <= 0.0:
				state = State.GONE
				timer = respawn
				_emit_sfx("stone_break")
				if Lx.player is LxWick and is_instance_valid(Lx.player):
					(Lx.player as LxWick).spawn_sparks(pos, Vector2.DOWN, 6, PAL["stone"] as Color, 18.0, 52.0, 0.24)
			queue_redraw()
		State.GONE:
			timer -= dt
			if timer <= 0.0:
				state = State.SOLID
				timer = 0.0
				_emit_sfx("phantom_phase")
			queue_redraw()


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["state"] = int(state)
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist and d.has("state"):
		state = clampi(int(d.get("state", 0)), 0, 2) as State
		timer = respawn if state == State.GONE else (delay if state == State.SHAKING else 0.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2((-size * 0.5).round(), size.round())
	if state == State.GONE:
		# Faint corner anchor brackets showing respawn progress
		var frac: float = 1.0 - clampf(timer / maxf(respawn, 0.01), 0.0, 1.0)
		var c: Color = PAL["stone"] as Color if frac > 0.72 else PAL["dusk"] as Color
		for cp: Vector2 in [r.position, Vector2(r.end.x - 3.0, r.position.y), Vector2(r.position.x, r.end.y - 3.0), r.end - Vector2(3.0, 3.0)]:
			draw_rect(Rect2(cp, Vector2(3.0, 3.0)), Color(c, 0.75))
		if frac > 0.72:
			draw_rect(r.grow(-2.0), Color(biome("hi"), 0.25), false, 1.0)
		return

	var shake_off := Vector2.ZERO
	var frac_s: float = 0.0
	if state == State.SHAKING:
		frac_s = 1.0 - clampf(timer / maxf(delay, 0.01), 0.0, 1.0)
		if not LxHudFx.flash_reduced():
			shake_off = Vector2(roundf(sin(_clock * 48.0) * (1.0 + frac_s)), roundf(cos(_clock * 37.0) * 0.8))
	var dr := Rect2(r.position + shake_off, r.size)
	LxPhysDraw.draw_shadow_rect(self, dr, Vector2(0.0, 2.0), 0.45)
	var base_c: Color = PAL["plum"] as Color if state == State.SHAKING else PAL["mauve"] as Color
	var hi_c: Color = PAL["coral"] as Color if (state == State.SHAKING and frac_s > 0.55) else PAL["stone"] as Color
	LxPhysDraw.draw_bevel_box(self, dr, base_c, hi_c, PAL["dusk"] as Color, PAL["void"] as Color)
	# Carved fracture cracks that deepen while shaking
	var cc: Color = PAL["void"] as Color if state == State.SHAKING else PAL["dusk"] as Color
	draw_line(dr.position + Vector2(3.0, 3.0), dr.get_center(), cc, 1.0)
	draw_line(dr.get_center(), dr.end - Vector2(4.0, 5.0), cc, 1.0)
	if state == State.SHAKING:
		draw_line(Vector2(dr.end.x - 4.0, dr.position.y + 3.0), dr.get_center(), PAL["void"] as Color, 1.0)
		draw_line(dr.get_center(), Vector2(dr.position.x + 4.0, dr.end.y - 3.0), PAL["void"] as Color, 1.0)
