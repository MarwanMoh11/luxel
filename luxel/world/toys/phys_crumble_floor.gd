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
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_mauve: Color = PAL["mauve"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_coral: Color = PAL["coral"] as Color
	var c_apr: Color = PAL["apricot"] as Color

	if state == State.GONE:
		# Crisp dark chasm socket framed by broken corner masonry brackets (zero translucent wash)
		var frac: float = 1.0 - clampf(timer / maxf(respawn, 0.01), 0.0, 1.0)
		draw_rect(r.grow(-1.0), c_void)
		draw_rect(r.grow(-2.0), c_night)
		var br_c: Color = c_stone if frac > 0.72 else c_mauve
		var br_sh: Color = c_dusk
		# Four jagged broken stone corner ledges
		draw_rect(Rect2(r.position, Vector2(5.0, 2.0)), br_c)
		draw_rect(Rect2(r.position, Vector2(2.0, 5.0)), br_c)
		draw_rect(Rect2(r.position + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), br_sh)
		draw_rect(Rect2(r.end.x - 5.0, r.position.y, 5.0, 2.0), br_c)
		draw_rect(Rect2(r.end.x - 2.0, r.position.y, 2.0, 5.0), br_c)
		draw_rect(Rect2(r.position.x, r.end.y - 2.0, 5.0, 2.0), br_sh)
		draw_rect(Rect2(r.position.x, r.end.y - 5.0, 2.0, 5.0), br_sh)
		draw_rect(Rect2(r.end.x - 5.0, r.end.y - 2.0, 5.0, 2.0), br_sh)
		draw_rect(Rect2(r.end.x - 2.0, r.end.y - 5.0, 2.0, 5.0), br_sh)
		# Reforming stone pebbles gathering toward center right before respawn
		if frac > 0.55:
			var gather: float = clampf((frac - 0.55) / 0.45, 0.0, 1.0)
			var spread: float = lerpf(5.0, 1.0, gather)
			for off_p: Vector2 in [Vector2(-spread, -spread), Vector2(spread, -spread * 0.5), Vector2(-spread * 0.5, spread), Vector2(spread, spread)]:
				draw_rect(Rect2(off_p.round() - Vector2.ONE, Vector2(2.0, 2.0)), biome("hi") if frac > 0.8 else c_stone)
		return

	var shake_off := Vector2.ZERO
	var frac_s: float = 0.0
	if state == State.SHAKING:
		frac_s = 1.0 - clampf(timer / maxf(delay, 0.01), 0.0, 1.0)
		if not LxHudFx.flash_reduced():
			shake_off = Vector2(roundf(sin(_clock * 48.0) * (1.0 + frac_s)), roundf(cos(_clock * 37.0) * 0.8))
	var dr := Rect2((r.position + shake_off).round(), r.size)
	# Recessed chasm rim under flagstone
	draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 3.0), c_void)
	# Carved weathered flagstone body
	var base_c: Color = c_plum if state == State.SHAKING else c_mauve
	var hi_c: Color = c_coral if (state == State.SHAKING and frac_s > 0.5) else (c_apr if state == State.SHAKING else c_stone)
	LxPhysDraw.draw_bevel_box(self, dr, base_c, hi_c, c_dusk, c_void)
	# Subtle masonry notch corners & carved stone grain
	draw_rect(Rect2(dr.position + Vector2(2.0, 2.0), Vector2(2.0, 1.0)), hi_c)
	draw_rect(Rect2(dr.end - Vector2(4.0, 3.0), Vector2(2.0, 1.0)), c_night)
	# Branching jagged fracture cracks (clearly deeper and splitting while SHAKING)
	var cc: Color = c_void if state == State.SHAKING else c_night
	var c_edge: Color = c_coral if state == State.SHAKING else c_stone
	var mid: Vector2 = dr.get_center().round()
	draw_line(dr.position + Vector2(3.0, 2.0), mid + Vector2(-1.0, -1.0), cc, 1.0)
	draw_line(mid + Vector2(-1.0, -1.0), mid + Vector2(1.0, 1.0), cc, 1.0)
	draw_line(mid + Vector2(1.0, 1.0), dr.end - Vector2(3.0, 4.0), cc, 1.0)
	draw_line(mid + Vector2(0.0, -1.0), Vector2(dr.end.x - 3.0, dr.position.y + 4.0), cc, 1.0)
	draw_rect(Rect2(mid + Vector2(-2.0, 1.0), Vector2(1.0, 1.0)), c_edge)
	draw_rect(Rect2(mid + Vector2(2.0, -2.0), Vector2(1.0, 1.0)), c_edge)
	if state == State.SHAKING:
		# Second crossing chasm fracture + tumbling pebble chips
		draw_line(Vector2(dr.end.x - 3.0, dr.position.y + 2.0), mid, c_void, 2.0)
		draw_line(mid, Vector2(dr.position.x + 3.0, dr.end.y - 3.0), c_void, 2.0)
		draw_rect(Rect2(mid - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), c_coral)
		var drop: float = roundf(frac_s * 3.0)
		draw_rect(Rect2(dr.position.x + 2.0, dr.end.y + drop, 2.0, 1.0), c_stone)
		draw_rect(Rect2(dr.end.x - 4.0, dr.end.y + 1.0 + drop, 2.0, 1.0), c_mauve)
