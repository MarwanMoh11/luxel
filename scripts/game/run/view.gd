extends RefCounted
## Camera follow and clamp, pans, painter layers, rim and physics queries, edge points, light pools, HUD warn
## points (ported from low_settings_island.gd). Drawing is split so actors y-sort with the props: ground effects,
## shadows (shade.gdshader) and trails go under the island's Sort layer, Wick (his body node) and every walker
## are nodes inside it, flyers, hazards, shots, impacts and shards draw on Above (after Over). In the PIXELS
## finale the enemies' eyes, the shards and the lantern draw on Top, above the dead pixels.

const SHADE := preload("res://scripts/cast/shade.gdshader")
const LIGHT := preload("res://scripts/cast/light_fx.gd")
const VIEW := Vector2(320, 180)
const FEET_RADIUS := 4.0 # Wick's walk collider, as the map's walker
const SPAWN_RINGS: Array[float] = [200.0, 240.0, 170.0] # px from Wick; the view's half-diagonal is 184
const WALK_LAYER := 1
const SHOT_LAYER := 2
const ROUGH_SPEED := 0.55 # speed factor on rough ground (Island.ROUGH_LAYER), Wick and walkers alike
const SHAKE_PX := 3
const POOL_COLOURS: Array[Color] = [Color8(255, 217, 140), Color8(245, 169, 106)] # gold, apricot: a pool's core
const POOL_CELL := 8 # px: core pixels are grouped in cells; touching cells make one pool

var run ## the Run (run.gd), duck-typed
var camera: Camera2D
var warn: Array = [] ## off-screen threats this step for the HUD pips: {pos, kind}
var pools := PackedVector3Array() ## light pools on the map: x, y, radius (all of them; light_pools() empties them once BRIGHTNESS is sold)
var body: CharacterBody2D ## Wick's feet on the walk layer; also the node that draws Wick in the Sort layer
var above: Node2D ## flyers, hazards, shots, impacts, shards
var shake := 0.0 ## seconds of screen shake left
var eyes_hidden := false ## the ending draws its own eyes (run.hide_eyes)

var _under: Array[Node2D] = []
var _rim := PackedVector2Array()
var _query := PhysicsPointQueryParameters2D.new()
var _origin := Vector2.ZERO # world position of the 320x180 game screen's top-left (shake included)
var _pan_to := Vector2.INF # world point the camera holds (INF = follow Wick)
var _pan_from := Vector2.ZERO
var _pan_t := 0.0
var _pan_len := 0.0
var _centre := Vector2.ZERO # the camera's aim before the clamp


## Keeps the back-reference to the run.
func setup(r) -> void:
	run = r


## Builds the camera and the painter layers in the island (Sort children, Above), and Wick's body.
func build() -> void:
	var island: Island = run.island
	_rim = (island.get_node("Bodies/Rim/Edge") as CollisionPolygon2D).polygon
	var sort := island.get_node("Sort")
	for painter: Callable in [_draw_ground_fx, _draw_shadows, _draw_trails]:
		var layer := Node2D.new()
		layer.draw.connect(painter.bind(layer))
		island.add_child(layer)
		island.move_child(layer, sort.get_index())
		_under.append(layer)
	var shade := ShaderMaterial.new()
	shade.shader = SHADE
	_under[1].material = shade
	above = Node2D.new()
	above.draw.connect(_paint_above)
	island.add_child(above) # after Over: above every prop
	body = CharacterBody2D.new()
	body.collision_layer = 0
	body.collision_mask = WALK_LAYER
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var feet := CollisionShape2D.new()
	feet.shape = CircleShape2D.new()
	(feet.shape as CircleShape2D).radius = FEET_RADIUS
	body.add_child(feet)
	body.draw.connect(_paint_wick)
	island.add_actor(body)
	body.position = island.spawn
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT # Display centres the game screen around it
	run.add_child(camera)
	camera.make_current()
	_centre = island.spawn
	run.top.draw.connect(_paint_top)
	_find_pools()


## Back to following Wick, no shake.
func reset() -> void:
	_pan_to = Vector2.INF
	shake = 0.0
	eyes_hidden = false
	warn.clear()


## Camera: follows Wick, clamped to the map (unless a pan holds it). Real seconds.
func step(dt: float) -> void:
	shake = maxf(shake - dt, 0.0)
	var target: Vector2 = run.wick_feet()
	if _pan_to != Vector2.INF:
		_pan_t = minf(_pan_t + dt, _pan_len)
		var u := 1.0 if _pan_len <= 0.0 else _pan_t / _pan_len
		target = _pan_from.lerp(_pan_to, u * u * (3.0 - 2.0 * u))
	elif _pan_len > 0.0: # handing back to Wick
		_pan_t = minf(_pan_t + dt, _pan_len)
		var u := _pan_t / _pan_len
		target = _pan_from.lerp(target, u * u * (3.0 - 2.0 * u))
		if _pan_t >= _pan_len:
			_pan_len = 0.0
	_centre = target


## Pans the camera to world `pos` over `secs` and holds it there.
func pan_to(pos: Vector2, secs: float) -> void:
	_pan_from = _centre
	_pan_to = pos
	_pan_t = 0.0
	_pan_len = maxf(secs, 0.0)


## Gives the camera back to Wick (a short glide when a pan held it).
func follow_wick() -> void:
	if _pan_to == Vector2.INF:
		return
	_pan_from = _centre
	_pan_to = Vector2.INF
	_pan_t = 0.0
	_pan_len = 0.4


## Camera on its aim, nodes on their ground points, every layer redrawn. The whole view (the 320x180 game screen
## plus Display's margin around it on a bigger screen) stays inside the map.
func sync() -> void:
	var island: Island = run.island
	var top := (_centre - VIEW / 2).round().clamp(Display.margin, island.map_size - Display.view_size + Display.margin)
	var jolt := Vector2(randi_range(-SHAKE_PX, SHAKE_PX), randi_range(-SHAKE_PX, SHAKE_PX)) if shake > 0.0 else Vector2.ZERO
	_origin = top + jolt
	camera.position = _origin
	body.queue_redraw()
	for layer in _under:
		layer.queue_redraw()
	above.queue_redraw()
	for e in run.enemies:
		_place(e)
	for r in run.remnants:
		_place(r)
	run.top.queue_redraw()


## World position of the game screen's top-left pixel (the camera, shake included).
func origin() -> Vector2:
	return _origin


## Wick's body node to `feet` (restart, intro).
func place_wick(feet: Vector2) -> void:
	body.position = feet


## True if `p` is on the island (unless `rim` is false) and clear of colliders on physics `mask`
## (1 walk, 2 shots; 0 = the rim only).
func open(p: Vector2, mask := WALK_LAYER, rim := true) -> bool:
	if rim and not Geometry2D.is_point_in_polygon(p, _rim):
		return false
	if mask == 0:
		return true
	_query.position = p
	_query.collision_mask = mask
	return run.get_world_2d().direct_space_state.intersect_point(_query, 1).is_empty()


## Speed factor for feet at `p`: ROUGH_SPEED on rough ground (the flower beds' soil), else 1.
func ground_speed(p: Vector2) -> float:
	return 1.0 if open(p, Island.ROUGH_LAYER, false) else ROUGH_SPEED


## A walkable point on the island just outside the view, so enemies walk in from off-screen ground.
func edge_point() -> Vector2:
	var reach := Display.view_size.length() / VIEW.length() # a fullscreen view past 320x180 pushes them out too
	var feet: Vector2 = run.wick_feet()
	for ring in SPAWN_RINGS:
		for i in 8:
			var p := feet + Vector2.from_angle(randf() * TAU) * ring * reach
			if open(p, WALK_LAYER):
				return p
	return run.island.spawn


## The visible world rectangle (the 320x180 game screen plus any fullscreen margin).
func view_rect() -> Rect2:
	return Rect2(_origin - Display.margin, Display.view_size)


func _place(b) -> void:
	if b != null and b.node != null:
		b.node.position = b.pos.round()
		b.node.queue_redraw()


# --- painters --------------------------------------------------------------------------------------------------

func _draw_ground_fx(ci: CanvasItem) -> void:
	if run.light != null:
		run.light.draw_layer(ci, LIGHT.GROUND, run.wick_feet(), run.lantern())


func _draw_shadows(ci: CanvasItem) -> void:
	for e in run.enemies:
		e.draw_shadow(ci)
	for r in run.remnants:
		r.draw_shadow(ci)
	for h in run.hazards:
		h.draw_shadow(ci)
	if run.wick_visible():
		run.wick.draw_shadow(ci, run.wick_feet(), Color.WHITE) # the shade shader picks the real colour


func _draw_trails(ci: CanvasItem) -> void:
	if run.light == null:
		return
	run.light.draw_layer(ci, LIGHT.MOON, run.wick_feet(), run.lantern())
	run.light.draw_layer(ci, LIGHT.TRAIL, run.wick_feet(), run.lantern())


## Hazards, flyers (live and remnants), shots, impacts, then shards over everything on the map.
func _paint_above() -> void:
	for h in run.hazards:
		h.draw(above)
	for e in run.enemies:
		if e.flyer():
			e.draw_body(above)
	for r in run.remnants:
		if r.flyer():
			r.draw_body(above)
	if run.light != null:
		run.light.draw_shots(above, run.bullets, false)
		run.light.draw_layer(above, LIGHT.OVER, run.wick_feet(), run.lantern())
	if not run.finale():
		run.paint_shards(above, Vector2.ZERO)


## Wick with the fireflies around, the launch smear and new shots under him, and the flare at the lantern
## (behind Wick when the lantern is).
func _paint_wick() -> void:
	body.draw_set_transform(-body.position)
	if not run.wick_visible() or run.light == null:
		return
	var light = run.light
	var feet: Vector2 = run.wick_feet()
	var emit: Vector2 = run.lantern()
	var flies: bool = not run.dead()
	if flies:
		light.draw_flies(body, feet, true)
	light.draw_layer(body, LIGHT.UNDER_HERO, feet, emit)
	light.draw_shots(body, run.bullets, true)
	var behind: bool = run.wick.lantern_behind()
	if behind:
		light.draw_layer(body, LIGHT.OVER_HERO, feet, emit)
	run.wick.draw(body, feet)
	if not behind:
		light.draw_layer(body, LIGHT.OVER_HERO, feet, emit)
	if flies:
		light.draw_flies(body, feet, false)


## A walker's body in the Sort layer (flyers draw on Above).
func paint_brain(b) -> void:
	if b.node == null or b.flyer():
		return
	b.node.draw_set_transform(-b.node.position)
	b.draw_body(b.node)


## Above the screen effects: in the finale the enemies' eyes, the shards and the lantern; at DISPLAY: OFF the
## eyes (until the ending takes them over with run.hide_eyes) and Wick for the ending.
func _paint_top() -> void:
	var top: Node2D = run.top
	if not (run.finale() or run.display_off()):
		return
	top.draw_set_transform(-_origin)
	if not eyes_hidden:
		for e in run.enemies:
			e.draw_eyes(top)
		for r in run.remnants:
			r.draw_eyes(top)
		if not run.display_off():
			for h in run.hazards:
				h.draw_eyes(top)
	var feet: Vector2 = run.wick_feet()
	if run.display_off():
		run.wick.draw(top, feet)
	else:
		run.paint_shards(top, Vector2.ZERO)
		run.wick.draw(top, feet, false, true)
	top.draw_set_transform(Vector2.ZERO)



## The orchard's light pools, from the pools' ground art: touching cells of core (gold, apricot) pixels.
func _find_pools() -> void:
	pools.clear()
	var sprite := run.island.get_node_or_null("GroundProps/orchard_lightpools") as Sprite2D
	if sprite == null:
		return
	var img := sprite.texture.get_image()
	if img == null or img.is_empty(): # no readback (some web GPUs): no pools, the lantern still reveals
		return
	if img.is_compressed():
		img.decompress()
	var cells := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and (c.is_equal_approx(POOL_COLOURS[0]) or c.is_equal_approx(POOL_COLOURS[1])):
				var k := Vector2i(x / POOL_CELL, y / POOL_CELL)
				cells[k] = int(cells.get(k, 0)) + 1
	var at0 := sprite.position + sprite.offset
	var seen := {}
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		seen[start] = true
		var todo: Array[Vector2i] = [start]
		var sum := Vector2.ZERO
		var n := 0
		var count := 0
		while not todo.is_empty():
			var k: Vector2i = todo.pop_back()
			count += 1
			n += cells[k]
			sum += (Vector2(k) + Vector2(0.5, 0.5)) * POOL_CELL * cells[k]
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nk := k + Vector2i(dx, dy)
					if cells.has(nk) and not seen.has(nk):
						seen[nk] = true
						todo.append(nk)
		if n >= 12: # a lone glint is not a pool
			var at := at0 + sum / n
			pools.append(Vector3(at.x, at.y, 14.0 + POOL_CELL * sqrt(count)))
