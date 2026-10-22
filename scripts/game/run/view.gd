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
const PAL: Dictionary = preload("res://scripts/game/ui/palette.gd").PAL
const SOIL: Array[String] = ["mauve", "stone", "lime", "mauve"] # flecks a hop kicks up on rough ground: soil, leaf
const SOIL_LIFE := 0.35 # s
const SOIL_FALL := 160.0 # px/s^2
const SHAKE_PX := 3
const LIGHT_POOLS := preload("res://scripts/world/light_pools.gd") ## the map's light pools (light_pools_gen.gd)
const CELL := 4 ## px: open()'s lookup grid over the map
const CELL_LAYERS := 7 ## the physics layers the grid knows: walk, shots, rough
const CELL_INSIDE := 128 ## grid bit: the cell and 1 px around it are inside the rim
const CELL_EDGE := 64 ## grid bit while building: a rim edge comes within 1 px of the cell

var run ## the Run (run.gd), duck-typed
var camera: Camera2D
var warn: Array = [] ## off-screen threats this step for the HUD pips: {pos, kind}
var pools := PackedVector3Array() ## light pools on the map: x, y, radius (all of them; light_pools() empties them once BRIGHTNESS is sold)
var body: CharacterBody2D ## Wick's feet on the walk layer; also the node that draws Wick in the Sort layer
var above: Node2D ## flyers, hazards, shots, impacts, shards
var shake := 0.0 ## seconds of screen shake left
var eyes_hidden := false ## the ending draws its own eyes (run.hide_eyes)

var _soil: Array[Dictionary] = [] # kicked-up flecks: {pos, vel, t, c}
var _under: Array[Node2D] = []
var _rim := PackedVector2Array()
var _query := PhysicsPointQueryParameters2D.new()
var _space: PhysicsDirectSpaceState2D
var _cells := PackedByteArray() # per CELL square of the map: the layers of the colliders within 1 px | CELL_INSIDE
var _cols := 0
var _rows := 0
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
	_space = run.get_world_2d().direct_space_state
	_build_cells()
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
	_soil.clear()


## Camera: follows Wick, clamped to the map (unless a pan holds it); the soil flecks fly. Real seconds.
func step(dt: float) -> void:
	shake = maxf(shake - dt, 0.0)
	for f in _soil:
		var v: Vector2 = f["vel"] + Vector2(0.0, SOIL_FALL * dt)
		f["vel"] = v
		f["pos"] += v * dt
		f["t"] += dt
	if not _soil.is_empty():
		_soil = _soil.filter(func(f: Dictionary) -> bool: return f["t"] < SOIL_LIFE)
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
	if camera.position != _origin:
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
## (1 walk, 2 shots; 0 = the rim only). The grid answers wherever no rim edge or collider comes near.
func open(p: Vector2, mask := WALK_LAYER, rim := true) -> bool:
	var x := floori(p.x / CELL)
	var y := floori(p.y / CELL)
	var cell := CELL_LAYERS # off the grid: ask the polygon and the physics
	if x >= 0 and y >= 0 and x < _cols and y < _rows:
		cell = _cells[y * _cols + x]
	if rim and cell & CELL_INSIDE == 0 and not Geometry2D.is_point_in_polygon(p, _rim):
		return false
	if mask == 0 or (cell & mask == 0 and mask & ~CELL_LAYERS == 0):
		return true
	_query.position = p
	_query.collision_mask = mask
	return _space.intersect_point(_query, 1).is_empty()


## Speed factor for feet at `p`: ROUGH_SPEED on rough ground (flower beds, reeds), else 1.
func ground_speed(p: Vector2) -> float:
	return 1.0 if open(p, Island.ROUGH_LAYER, false) else ROUGH_SPEED


## open()'s grid: per cell the physics layers of the collider shapes within 1 px of it, and whether the cell lies
## inside the rim with no rim edge within 1 px. Colliders never move (Island), so a cell no shape on the asked
## layers reaches answers open() as the query would, and an inside cell as the polygon test would.
func _build_cells() -> void:
	var island: Island = run.island
	_cols = ceili(island.map_size.x / CELL)
	_rows = ceili(island.map_size.y / CELL)
	_cells.resize(_cols * _rows)
	_cells.fill(0)
	for obj: CollisionObject2D in island.find_children("*", "CollisionObject2D", true, false):
		var layers := obj.collision_layer & CELL_LAYERS
		if layers == 0:
			continue
		for owner_id in obj.get_shape_owners():
			var xf := obj.global_transform * obj.shape_owner_get_transform(owner_id)
			for i in obj.shape_owner_get_shape_count(owner_id):
				var shape := obj.shape_owner_get_shape(owner_id, i)
				if shape is ConvexPolygonShape2D:
					_mark_convex(xf * (shape as ConvexPolygonShape2D).points, layers)
				elif shape is ConcavePolygonShape2D:
					var segs := xf * (shape as ConcavePolygonShape2D).segments
					for k in range(0, segs.size() - 1, 2):
						_mark_convex(PackedVector2Array([segs[k], segs[k + 1]]), layers)
				else: # any other shape: its bounding box
					var r := shape.get_rect()
					_mark_convex(xf * PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
						Vector2(r.position.x, r.end.y)]), layers)
	# Geometry2D.is_point_in_polygon counts the edges crossed by the line from the point to a far corner, which
	# miscounts where that line grazes a vertex: those lines (from each vertex, away from the corner) count as edges.
	var hi := Vector2(-1e20, -1e20)
	var lo := Vector2(1e20, 1e20)
	for v in _rim:
		hi = hi.max(v)
		lo = lo.min(v)
	var far := hi + (hi - lo) * Vector2(1.221313, 1.512312)
	var reach := island.map_size.length() * 2.0
	for i in _rim.size():
		_mark_convex(PackedVector2Array([_rim[i], _rim[(i + 1) % _rim.size()]]), CELL_EDGE)
		_mark_convex(PackedVector2Array([_rim[i], _rim[i] + (_rim[i] - far).normalized() * reach]), CELL_EDGE)
	for y in _rows: # a run of cells no edge reaches is all inside or all outside: one polygon test per run
		var inside := false
		var fresh := true
		for x in _cols:
			var k := y * _cols + x
			if _cells[k] & CELL_EDGE:
				_cells[k] &= ~CELL_EDGE
				fresh = true
				continue
			if fresh:
				inside = Geometry2D.is_point_in_polygon((Vector2(x, y) + Vector2(0.5, 0.5)) * CELL, _rim)
				fresh = false
			if inside:
				_cells[k] |= CELL_INSIDE


## Sets `bits` on every grid cell that convex polygon `points` (or a segment, as two points) comes within 1 px of.
## Column by column: within a column the polygon spans the rows its edges' pieces over the column (grown by 1 px)
## span.
func _mark_convex(points: PackedVector2Array, bits: int) -> void:
	var box := Rect2(points[0], Vector2.ZERO)
	for q in points:
		box = box.expand(q)
	var c0 := maxi(floori((box.position.x - 1.0) / CELL), 0)
	var c1 := mini(floori((box.end.x + 1.0) / CELL), _cols - 1)
	if c1 < c0:
		return
	var lo := PackedFloat64Array()
	var hi := PackedFloat64Array()
	lo.resize(c1 - c0 + 1)
	hi.resize(c1 - c0 + 1)
	lo.fill(INF)
	hi.fill(-INF)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if a.x > b.x:
			var t := a
			a = b
			b = t
		for x in range(maxi(floori((a.x - 1.0) / CELL), c0), mini(floori((b.x + 1.0) / CELL), c1) + 1):
			var y0 := a.y
			var y1 := b.y
			if b.x > a.x:
				y0 = lerpf(a.y, b.y, (maxf(a.x, x * CELL - 1.0) - a.x) / (b.x - a.x))
				y1 = lerpf(a.y, b.y, (minf(b.x, (x + 1) * CELL + 1.0) - a.x) / (b.x - a.x))
			lo[x - c0] = minf(lo[x - c0], minf(y0, y1))
			hi[x - c0] = maxf(hi[x - c0], maxf(y0, y1))
	for x in range(c0, c1 + 1):
		if lo[x - c0] > hi[x - c0]:
			continue
		for y in range(maxi(floori((lo[x - c0] - 1.0) / CELL), 0), mini(floori((hi[x - c0] + 1.0) / CELL), _rows - 1) + 1):
			_cells[y * _cols + x] |= bits


## A hop landing on rough ground: a few soil and leaf flecks kick up around the feet.
func kick_soil(feet: Vector2) -> void:
	for c: String in SOIL:
		_soil.append({"pos": feet + Vector2(randf_range(-3.0, 3.0), -1.0),
			"vel": Vector2(randf_range(-22.0, 22.0), randf_range(-38.0, -18.0)), "t": 0.0, "c": PAL[c]})


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
		var at: Vector2 = b.pos.round()
		if b.node.position != at:
			b.node.position = at
		if b.body_key() < 0:
			b.node.queue_redraw()
		else: # paint_brain draws relative to the node: an unchanged body only moves (brain body_key)
			b.redraw_body.call_deferred()


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
	for f in _soil:
		body.draw_rect(Rect2((f["pos"] as Vector2).round(), Vector2.ONE), f["c"])
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



## The orchard's light pools, scanned from the pools' ground art ahead of time (light_pools_gen.gd).
func _find_pools() -> void:
	pools = PackedVector3Array(LIGHT_POOLS.POOLS)
