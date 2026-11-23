class_name LxOverworldWildlife
extends Node2D
## Charming, purely atmospheric, player-reactive micro-wildlife unique to each of the 8 overworlds.
## Strictly uses the 20 opaque Last Light colours (LxPalette.PAL); zero gameplay collision impact.
##
## - Island 1 (Bell Isle): Lantern Moths fluttering upward when Wick passes
## - Island 2 (Tidewater Harbor): Sandpiper Shore-Crabs scuttling sideways across piers
## - Island 3 (Thornwood Hollow): Emerald Canopy Beetles puffing lime dust when startled
## - Island 4 (Mirefen Gardens): Glass-Winged Dragonflies darting across the garden lagoon
## - Island 5 (Starfall Observatory): Tiny Clockwork Brass Motes hopping along star terraces
## - Island 6 (Ashen Kiln): Ember Skinks darting across warm basalt paths with cinder tails
## - Island 7 (Moon Shoals): Silver Mirror-Moths floating with crisp mirrored reflections
## - Island 8 (The Long Night): Memory Sparrows shifting plum->gold as Dawn Seals break

const PAL: Dictionary = LxPalette.PAL
const HALF_W: float = 196.0
const HALF_H: float = 124.0

var _island_id: int = 1
var _active: bool = false
var _clock: float = 0.0
var _cam_center: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()
var _critters: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2


func configure(rules: LxBiomeRules, region_node: Node) -> void:
	_island_id = rules.island_id if rules != null else 1
	_active = rules != null and not rules.is_dungeon
	_clock = 0.0
	_bounds = rules.bounds if rules != null else Rect2()
	_cam_center = _bounds.get_center()
	_critters.clear()
	if not _active or region_node == null or not is_instance_valid(region_node):
		queue_redraw()
		return
	var grid_v: Variant = region_node.get("grid")
	if not (grid_v is Array) or (grid_v as Array).is_empty():
		queue_redraw()
		return
	var grid: Array = grid_v as Array
	var gh: int = grid.size()
	var gw: int = (grid[0] as PackedStringArray).size()
	var ts: float = float(region_node.get("tile_size")) if region_node.get("tile_size") != null else 16.0
	var want_tiles: PackedStringArray = PackedStringArray(["water", "tide"]) if _island_id in [4, 7] else PackedStringArray(["ground", "path"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_island_id * 31337 + gw * 97 + gh * 53)
	var target_count: int = 16
	var tries: int = 0
	while _critters.size() < target_count and tries < 220:
		tries += 1
		var tx: int = rng.randi_range(3, maxi(3, gw - 4))
		var ty: int = rng.randi_range(3, maxi(3, gh - 4))
		var t: String = (grid[ty] as PackedStringArray)[tx]
		if not want_tiles.has(t):
			continue
		var p := Vector2((float(tx) + 0.5) * ts, (float(ty) + 0.5) * ts)
		var too_near: bool = false
		for c: Dictionary in _critters:
			if (c["home"] as Vector2).distance_squared_to(p) < 5184.0:
				too_near = true
				break
		if too_near:
			continue
		_critters.append({
			"home": p,
			"pos": p,
			"vel": Vector2.ZERO,
			"phase": rng.randf_range(0.0, TAU),
			"flee_t": 0.0,
			"dir": 1.0 if rng.randf() > 0.5 else -1.0,
			"hop": 0.0,
		})
	queue_redraw()


func tick(dt: float, cam_center: Vector2) -> void:
	_cam_center = cam_center
	if not _active or dt <= 0.0 or _critters.is_empty():
		return
	_clock += dt
	var wp: Vector2 = Vector2(-9999.0, -9999.0)
	var lp: Vector2 = Vector2(-9999.0, -9999.0)
	var w_fast: bool = false
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var w: LxWick = Lx.player as LxWick
		if not w.dead:
			wp = w.global_position
			w_fast = w.is_dashing() or w.is_gliding() or w.velocity.length_squared() > 1600.0
			if w.lantern != null and is_instance_valid(w.lantern) and w.lantern.is_out():
				lp = w.lantern.pos
	var relit_t: bool = Lx.state != null and Lx.state.relit_islands.has(_island_id)
	var harm_t: bool = Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % _island_id, false))
	var friendly: bool = relit_t or harm_t

	var any_vis: bool = false
	for c: Dictionary in _critters:
		var p: Vector2 = c["pos"] as Vector2
		if absf(p.x - _cam_center.x) > HALF_W + 40.0 or absf(p.y - _cam_center.y) > HALF_H + 40.0:
			continue
		any_vis = true
		var ft: float = float(c["flee_t"])
		var d2: float = p.distance_squared_to(wp)
		var scare_r2: float = 2500.0 if w_fast else 1296.0
		if ft <= 0.0 and d2 < scare_r2:
			if friendly and not w_fast:
				# Saved/Harmony islands: native wildlife trusts Wick's light & swirls in a joyful greeting arc!
				ft = 1.25
				var tang: Vector2 = (p - wp).normalized().rotated(PI * 0.42 * float(c["dir"])) if d2 > 4.0 else Vector2(float(c["dir"]), -0.4).normalized()
				c["vel"] = (tang + Vector2(0.0, -0.35)).normalized() * 34.0
				c["dir"] = 1.0 if tang.x >= 0.0 else -1.0
			else:
				ft = 1.45
				var away: Vector2 = (p - wp).normalized() if d2 > 1.0 else Vector2(float(c["dir"]), -0.5).normalized()
				if _island_id == 2: # Shore-crabs scuttle sideways!
					away = Vector2(signf(away.x) if absf(away.x) > 0.1 else float(c["dir"]), away.y * 0.25).normalized()
				elif _island_id in [1, 4, 7, 8]: # Moths, dragonflies, & sparrows lift skyward!
					away = (away + Vector2(0.0, -0.65)).normalized()
				c["vel"] = away * (56.0 if _island_id in [4, 6, 8] else 42.0)
				c["dir"] = 1.0 if away.x >= 0.0 else -1.0
		if ft > 0.0:
			ft = maxf(0.0, ft - dt)
			c["flee_t"] = ft
			var v: Vector2 = c["vel"] as Vector2
			p += v * dt
			c["vel"] = v * maxf(0.0, 1.0 - 1.4 * dt)
			c["hop"] = sin(ft * 14.0) * 3.0 if _island_id in [1, 4, 7, 8] else absf(sin(ft * 18.0)) * 2.0
			if ft <= 0.0:
				var home: Vector2 = c["home"] as Vector2
				if p.distance_to(home) > 72.0:
					c["home"] = p.clamp(_bounds.position + Vector2(32.0, 32.0), _bounds.end - Vector2(32.0, 32.0))
		else:
			var home: Vector2 = c["home"] as Vector2
			var ph: float = float(c["phase"])
			var goal: Vector2 = home + _idle_offset(ph)
			# Curious flying/glowing critters gently flutter near Wick's hung lantern!
			if lp.x > -9000.0 and _island_id in [1, 4, 5, 7, 8] and p.distance_squared_to(lp) < 5776.0:
				var orbit_a: float = _clock * 2.2 + ph
				goal = lp + Vector2(cos(orbit_a) * 14.0, sin(orbit_a) * 9.0)
			var delta: Vector2 = goal - p
			if delta.length_squared() > 1.0:
				p += delta.limit_length(22.0 * dt if (lp.x > -9000.0 and p.distance_squared_to(lp) < 5776.0) else 18.0 * dt)
				if absf(delta.x) > 1.5:
					c["dir"] = 1.0 if delta.x >= 0.0 else -1.0
			c["hop"] = 0.0
		c["pos"] = p
	if any_vis:
		queue_redraw()


func _idle_offset(ph: float) -> Vector2:
	match _island_id:
		2: # Sideways pier patrol
			return Vector2(sin(_clock * 1.1 + ph) * 14.0, cos(_clock * 0.6 + ph) * 2.0)
		4: # Hovering figure-8 dragonfly dart
			return Vector2(sin(_clock * 1.6 + ph) * 16.0, sin(_clock * 3.2 + ph) * 7.0)
		5: # Rhythmic clockwork hexagon orbit
			var a: float = _clock * 1.2 + ph
			return Vector2(cos(a) * 10.0, sin(a) * 6.0)
		6: # Quick volcanic dart-pause
			return Vector2(sin(_clock * 1.8 + ph) * 12.0, cos(_clock * 1.3 + ph) * 8.0)
		_:
			return Vector2(sin(_clock * 0.9 + ph) * 10.0, cos(_clock * 0.75 + ph) * 7.0)


func _draw() -> void:
	if not _active or _critters.is_empty():
		return
	var fred: bool = LxHudFx.flash_reduced()
	var relit: bool = Lx.state != null and Lx.state.relit_islands.has(_island_id)
	var harm: bool = Lx.state != null and bool(Lx.state.story_flags.get("disc_all_%d" % _island_id, false))
	var blessed: bool = relit or harm
	var bio_glow: Color = LxBiomePalette.col(_island_id, "glow")
	var seals_b: int = LxBiomeMechanics.active_instance.dawn_seals_broken if (LxBiomeMechanics.active_instance != null and is_instance_valid(LxBiomeMechanics.active_instance)) else 0
	for c: Dictionary in _critters:
		var p: Vector2 = (c["pos"] as Vector2).round()
		if absf(p.x - _cam_center.x) > HALF_W or absf(p.y - _cam_center.y) > HALF_H:
			continue
		var ph: float = float(c["phase"])
		var dir_x: float = float(c["dir"])
		var hop: float = float(c["hop"])
		var fleeing: bool = float(c["flee_t"]) > 0.0
		var wing: float = 0.0 if fred else roundf(sin(_clock * (18.0 if fleeing else 10.0) + ph))
		match _island_id:
			1: # Lantern Moths (gold/cream flutter)
				var mp := p + Vector2(0.0, -4.0 - absf(hop))
				draw_rect(Rect2(mp + Vector2(-2.0, wing), Vector2(2.0, 1.0)), PAL["gold"] as Color)
				draw_rect(Rect2(mp + Vector2(1.0, wing), Vector2(2.0, 1.0)), PAL["gold"] as Color)
				draw_rect(Rect2(mp, Vector2.ONE), PAL["cream"] as Color)
			2: # Sandpiper Shore-Crabs (coral body + apricot claws)
				draw_rect(Rect2(p + Vector2(-2.0, 1.0), Vector2(5.0, 1.0)), Color(PAL["void"] as Color, 0.45))
				draw_rect(Rect2(p + Vector2(-2.0, -1.0 - hop), Vector2(4.0, 2.0)), PAL["coral"] as Color)
				draw_rect(Rect2(p + Vector2(-1.0, -1.0 - hop), Vector2(2.0, 1.0)), PAL["apricot"] as Color)
				draw_rect(Rect2(p + Vector2(-3.0, -2.0 - hop + wing), Vector2.ONE), PAL["apricot"] as Color)
				draw_rect(Rect2(p + Vector2(2.0, -2.0 - hop - wing), Vector2.ONE), PAL["apricot"] as Color)
			3: # Emerald Canopy Beetles (jade shell + lime glow)
				draw_rect(Rect2(p + Vector2(-1.0, 1.0), Vector2(3.0, 1.0)), Color(PAL["void"] as Color, 0.45))
				draw_rect(Rect2(p + Vector2(-1.0, -1.0 - hop), Vector2(3.0, 2.0)), PAL["jade"] as Color)
				draw_rect(Rect2(p + Vector2(0.0, -1.0 - hop), Vector2.ONE), PAL["lime"] as Color)
				if fleeing:
					draw_rect(Rect2(p + Vector2(-dir_x * 3.0, -2.0), Vector2.ONE), PAL["cream"] as Color)
			4: # Glass-Winged Dragonflies (rose tail + ice wings)
				var dp := p + Vector2(0.0, -6.0 - absf(hop))
				draw_line(dp - Vector2(dir_x * 3.0, 0.0), dp, PAL["rose"] as Color, 1.0)
				draw_rect(Rect2(dp + Vector2(-1.0, -1.0 + wing), Vector2(3.0, 1.0)), PAL["ice"] as Color)
				draw_rect(Rect2(dp, Vector2.ONE), PAL["cream"] as Color)
			5: # Clockwork Brass Fire-Ticks (tiny spinning gold/sky astrolabe motes)
				var sp := p + Vector2(0.0, -3.0 - absf(hop))
				draw_rect(Rect2(sp + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), PAL["gold"] as Color)
				draw_rect(Rect2(sp + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), PAL["sky"] as Color)
				draw_rect(Rect2(sp, Vector2.ONE), PAL["cream"] as Color)
			6: # Ember Skinks (coral body + gold spark tail)
				var kp := p + Vector2(0.0, -hop)
				draw_line(kp - Vector2(dir_x * 4.0, 0.0), kp, PAL["coral"] as Color, 1.4)
				draw_rect(Rect2(kp, Vector2(2.0, 1.0)), PAL["gold"] as Color)
				if fleeing:
					draw_rect(Rect2(kp - Vector2(dir_x * 5.0, 1.0), Vector2.ONE), PAL["cream"] as Color)
			7: # Silver Mirror-Moths + crisp reflected pixel twin beneath!
				var lp := p + Vector2(0.0, -5.0 - absf(hop))
				draw_rect(Rect2(lp + Vector2(-2.0, wing), Vector2(2.0, 1.0)), PAL["ice"] as Color)
				draw_rect(Rect2(lp + Vector2(1.0, wing), Vector2(2.0, 1.0)), PAL["ice"] as Color)
				draw_rect(Rect2(lp, Vector2.ONE), PAL["cream"] as Color)
				# Mirrored water reflection directly underneath
				var ref_p := p + Vector2(0.0, 4.0 + absf(hop) * 0.5)
				draw_rect(Rect2(ref_p + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(PAL["sky"] as Color, 0.45))
			8: # Memory Sparrows -> radiant Golden Dawn Sparrows as Eclipse Seals break / relit!
				var dawn_on: bool = relit or seals_b >= 2
				var col_w: Color = (PAL["gold"] if dawn_on else PAL["rose"]) as Color
				var col_c: Color = (PAL["cream"] if dawn_on else PAL["plum"]) as Color
				var bp := p + Vector2(0.0, -6.0 - absf(hop) * 1.4)
				draw_line(bp + Vector2(-3.0, wing), bp, col_w, 1.0)
				draw_line(bp, bp + Vector2(3.0, wing), col_w, 1.0)
				draw_rect(Rect2(bp, Vector2.ONE), col_c)
		if blessed and (fleeing or (not fred and sin(_clock * 3.0 + ph) > 0.72)):
			var sp_pt: Vector2 = (p + Vector2(-dir_x * 3.0, -4.0 - absf(hop))).round()
			draw_rect(Rect2(sp_pt, Vector2.ONE), (PAL["cream"] if harm else bio_glow) as Color)
