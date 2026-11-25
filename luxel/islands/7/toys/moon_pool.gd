class_name LxMoonPool
extends LxToy
## Island 7 Quicksilver Moon Pool: flips SILVER <-> BLACK in `Lx.vars` (`world_face`),
## runs a 1.2s mirror ripple + safe-tile ejection (SPEC 3.2), preserves carried `carry_orb`
## across flips when `item_moon_pocket` is owned (or `carry_bridge: true`), and shimmers
## cross-world hung lantern anchors.
## Props: scope (String), var ("world_face"), allow_bolt_flip (bool), carry_bridge (bool),
## radius_px (float, default 20), hidden (bool), locked (bool), step_flip (bool),
## persist (bool), target_id/target_ids.

enum State { SILVER_STILL, RIPPLING, BLACK_STILL, LOCKED }

const RIPPLE_DUR: float = 1.2

var var_scope: String = "island:7"
var var_name: String = "world_face"
var allow_bolt_flip: bool = true
var carry_bridge: bool = false
var radius_px: float = 20.0
var hidden_pool: bool = false
var locked_pool: bool = false
var step_flip: bool = false
var state: int = State.SILVER_STILL

var _ripple_t: float = 0.0
var _cd: float = 0.0
var _wick_was_in: bool = false
var _ghost_orb_pos: Vector2 = Vector2.INF
var _ghost_orb_t: float = 0.0
var _pocket_ring_t: float = 0.0


func _toy_setup() -> void:
	kind = "moon_pool"
	var raw_scope: String = str(props.get("scope", "")).strip_edges()
	var_scope = LxIsland7Rule.resolve_face_scope(region_id, raw_scope)
	var_name = str(props.get("var", "world_face")).strip_edges()
	if var_name.is_empty():
		var_name = "world_face"
	allow_bolt_flip = bool(props.get("allow_bolt_flip", true))
	carry_bridge = bool(props.get("carry_bridge", false))
	radius_px = maxf(12.0, float(props.get("radius_px", 20.0)))
	hidden_pool = bool(props.get("hidden", false))
	locked_pool = bool(props.get("locked", false))
	step_flip = bool(props.get("step_flip", false))
	if not props.has("persist"):
		persist = true
	radius = radius_px
	z_index = -5
	_ripple_t = 0.0
	_cd = 0.0
	_wick_was_in = false
	_ghost_orb_pos = Vector2.INF
	_ghost_orb_t = 0.0
	_pocket_ring_t = 0.0
	_sync_state()
	queue_redraw()


func reset_toy() -> void:
	if persist:
		return
	_ripple_t = 0.0
	_cd = 0.0
	_ghost_orb_t = 0.0
	_pocket_ring_t = 0.0
	_sync_state()
	queue_redraw()


func get_world_face() -> String:
	var raw: String = str(LxToyDraw.world_get_var(var_scope, var_name, "silver")).strip_edges().to_lower()
	return "black" if raw == "black" else "silver"


func _sync_state() -> void:
	if locked_pool:
		state = State.LOCKED
		powered = false
		return
	var is_blk: bool = get_world_face() == "black"
	powered = is_blk
	if _ripple_t > 0.0:
		state = State.RIPPLING
	else:
		state = State.BLACK_STILL if is_blk else State.SILVER_STILL


func tick(dt: float) -> void:
	super.tick(dt)
	var dirty: bool = false
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _ripple_t > 0.0:
		_ripple_t = maxf(0.0, _ripple_t - dt)
		dirty = true
	if _ghost_orb_t > 0.0:
		_ghost_orb_t = maxf(0.0, _ghost_orb_t - dt)
		dirty = true
	if _pocket_ring_t > 0.0:
		_pocket_ring_t = maxf(0.0, _pocket_ring_t - dt)
		dirty = true
	var prev_st: int = state
	_sync_state()
	if state != prev_st:
		dirty = true
	if active and step_flip and not hidden_pool and not locked_pool:
		var wp: Vector2 = wick_pos()
		var in_now: bool = wp.distance_to(pos) <= radius_px * 0.72 and (Lx.player == null or not bool(Lx.player.get("dead")))
		if in_now and not _wick_was_in and _cd <= 0.0:
			trigger_flip()
			dirty = true
		_wick_was_in = in_now
	if dirty:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active or hidden_pool or locked_pool or _cd > 0.0:
		if locked_pool:
			_emit_sfx("door_locked")
		return false
	return trigger_flip()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active or not allow_bolt_flip or hidden_pool or locked_pool or _cd > 0.0:
		return false
	if hit.source in ["bolt", "prism_bolt", "beam", "throw", "recall", "sunflare"]:
		return trigger_flip()
	return false


func on_light(light_radius: float, source: String) -> void:
	if not active or light_radius <= 0.0:
		return
	if hidden_pool and source in ["lens", "lens_anchor"]:
		hidden_pool = false
		_emit_sfx("lens_reveal")
		queue_redraw()


func on_signal(_from_id: String, is_on: bool) -> void:
	if is_on:
		var changed: bool = false
		if locked_pool:
			locked_pool = false
			changed = true
		if hidden_pool:
			hidden_pool = false
			changed = true
		if changed:
			_sync_state()
			_emit_sfx("mirror_ping")
			queue_redraw()


func trigger_flip() -> bool:
	if not active or hidden_pool or locked_pool:
		return false
	var cur: String = get_world_face()
	var next_face: String = "black" if cur == "silver" else "silver"
	_cd = 0.28
	_ripple_t = RIPPLE_DUR
	state = State.RIPPLING

	# Moon-Glass Pocket: inspect carried orb before flipping layers
	var wick: LxWick = Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
	var carried: Node = wick.get_carried() if wick != null else null
	var has_pocket: bool = carry_bridge or (Lx.state != null and bool(Lx.state.story_flags.get("item_moon_pocket", false)))
	var bridged_orb: LxInteractable = null
	if carried is LxInteractable:
		if has_pocket:
			bridged_orb = carried as LxInteractable
		else:
			var drop_p: Vector2 = wick.global_position
			wick.drop_carried()
			_ghost_orb_pos = drop_p
			_ghost_orb_t = 3.2

	# Write Lx.vars and flip region layers (handles safe Wick ejection via SPEC 3.2)
	if LxIsland7Rule.active_rule != null:
		LxIsland7Rule.active_rule.set_world_face(var_scope, next_face, true, pos)
	else:
		LxToyDraw.world_set_var(var_scope, var_name, next_face)
		if region != null and is_instance_valid(region) and region.has_method("apply_layers"):
			region.call("apply_layers", true)
		_emit_sfx("moon_pool_black" if next_face == "black" else "moon_pool_silver")

	# Re-assert Moon Pocket carried orb visibility/activity even if layer toggles tried to hide it
	if bridged_orb != null and is_instance_valid(bridged_orb):
		bridged_orb.active = true
		bridged_orb.visible = true
		_pocket_ring_t = 0.65
		_emit_sfx("mirror_ping")
		if wick != null and wick.get_carried() != bridged_orb:
			wick.carry(bridged_orb)
		if wick != null:
			wick.spawn_ring(wick.global_position, 3.0, 18.0, 0.30, PAL["ice"] as Color, 1.5)

	powered = (next_face == "black")
	_notify_linked_targets(powered)
	_emit_gust(radius_px * 2.2, 42.0)
	if wick != null:
		var ring_c: Color = (PAL["rose"] if next_face == "black" else PAL["ice"]) as Color
		wick.spawn_ring(pos, 4.0, radius_px * 1.45, 0.38, ring_c, 1.5)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	if not active or hidden_pool or locked_pool:
		return ""
	return "ISL7_PROMPT_POOL" if LxStrings.has_id("ISL7_PROMPT_POOL") else "PROMPT_PULL_LEVER"


func get_light_pool() -> Vector4:
	if not active or hidden_pool:
		return Vector4.ZERO
	var is_blk: bool = get_world_face() == "black"
	var r: float = radius_px * (2.2 if _ripple_t > 0.0 else 1.5)
	return Vector4(pos.x, pos.y, r, 0.72 if _ripple_t > 0.0 else (0.36 if is_blk else 0.56))


func save_state() -> Dictionary:
	var d: Dictionary = super.save_state()
	if persist:
		d["hidden"] = hidden_pool
		d["locked"] = locked_pool
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	if persist:
		if d.has("hidden"):
			hidden_pool = bool(d["hidden"])
		if d.has("locked"):
			locked_pool = bool(d["locked"])
	_sync_state()
	queue_redraw()


func _draw() -> void:
	if hidden_pool:
		# Subtle shimmer dust over hidden rug pool
		draw_rect(Rect2(-3.0, -1.0, 2.0, 1.0), Color(PAL["ice"] as Color, 0.25))
		draw_rect(Rect2(2.0, 1.0, 2.0, 1.0), Color(PAL["sky"] as Color, 0.25))
		return
	var r: float = roundf(radius_px)
	var is_blk: bool = get_world_face() == "black"
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_deep: Color = PAL["deep"] as Color
	var c_blue: Color = PAL["blue"] as Color
	var c_sky: Color = PAL["sky"] as Color
	var c_ice: Color = PAL["ice"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var c_plum: Color = PAL["plum"] as Color
	var c_wine: Color = PAL["wine"] as Color
	var c_rose: Color = PAL["rose"] as Color
	var c_coral: Color = PAL["coral"] as Color

	# Outer beveled moonstone rim
	draw_circle(Vector2(1.0, 2.0), r + 1.0, Color(c_void, 0.42))
	draw_circle(Vector2.ZERO, r, c_void)
	draw_circle(Vector2.ZERO, r - 1.5, c_plum if is_blk else c_stone_col())
	draw_circle(Vector2.ZERO, r - 3.0, c_night if is_blk else c_deep)
	# Pool mirror liquid (SILVER = luminous ice/sky quicksilver; BLACK = obsidian void/night + rose sheen)
	draw_circle(Vector2.ZERO, r - 4.0, c_void if is_blk else c_blue)
	draw_circle(Vector2(-1.0, -1.0), maxf(4.0, r - 6.0), c_night if is_blk else c_sky)
	if not is_blk:
		# Full silver moon crest inside pool (high-value filled disc: readable in greyscale!)
		draw_circle(Vector2.ZERO, maxf(3.0, r * 0.34), c_ice)
		draw_rect(Rect2(-2.0, -3.0, 3.0, 2.0), c_cream)
	else:
		# Hollow obsidian eclipsed crescent inside Black pool (dark center + bright rose rim!)
		draw_arc(Vector2.ZERO, maxf(3.5, r * 0.36), 0.0, TAU, 16, c_rose, 1.5)
		draw_circle(Vector2(1.5, 0.0), maxf(2.5, r * 0.28), c_void)
		draw_rect(Rect2(-roundf(r * 0.36), -1.0, 2.0, 2.0), c_cream)

	# Cross-world hung lantern reflection ghost inside pool
	if region != null and region.has_method("is_lantern_hung") and bool(region.call("is_lantern_hung")):
		draw_arc(Vector2(0.0, 2.0), 4.0, 0.0, TAU, 12, Color(PAL["gold"] as Color, 0.72), 1.0)
		draw_rect(Rect2(-1.0, 1.0, 2.0, 2.0), c_cream)

	# 1.2s expanding ripple transition waves
	if _ripple_t > 0.0:
		var u: float = 1.0 - clampf(_ripple_t / RIPPLE_DUR, 0.0, 1.0)
		var fred: bool = LxHudFx.flash_reduced()
		var a: float = (1.0 - u) * (0.55 if fred else 0.92)
		var wr1: float = roundf(lerpf(4.0, r * 1.55, u))
		var wr2: float = roundf(lerpf(2.0, r * 1.15, clampf(u * 1.25, 0.0, 1.0)))
		draw_arc(Vector2.ZERO, wr1, 0.0, TAU, 24, Color(c_rose if is_blk else c_ice, a), 1.5)
		draw_arc(Vector2.ZERO, wr2, 0.0, TAU, 20, Color(c_cream, a * 0.8), 1.0)

	# Moon Pocket carried-orb shimmer
	if _pocket_ring_t > 0.0:
		var pu: float = 1.0 - clampf(_pocket_ring_t / 0.65, 0.0, 1.0)
		draw_arc(Vector2.ZERO, roundf(lerpf(6.0, r + 8.0, pu)), 0.0, TAU, 18, Color(c_cream, 1.0 - pu), 1.0)

	# Ghostly memory indicator if an un-pocketed orb stayed in the other world
	if _ghost_orb_t > 0.0 and _ghost_orb_pos.is_finite():
		var gp: Vector2 = (_ghost_orb_pos - pos).round()
		var ga: float = clampf(_ghost_orb_t / 3.2, 0.0, 1.0) * 0.7
		draw_arc(gp, 6.0, 0.0, TAU, 12, Color(c_ice, ga), 1.0)
		draw_rect(Rect2(gp - Vector2.ONE, Vector2(2.0, 2.0)), Color(c_cream, ga))

	if locked_pool:
		draw_line(Vector2(-r * 0.6, -r * 0.6), Vector2(r * 0.6, r * 0.6), c_void, 3.0)
		draw_line(Vector2(r * 0.6, -r * 0.6), Vector2(-r * 0.6, r * 0.6), c_void, 3.0)
		draw_line(Vector2(-r * 0.6, -r * 0.6), Vector2(r * 0.6, r * 0.6), c_wine, 1.0)
		draw_line(Vector2(r * 0.6, -r * 0.6), Vector2(-r * 0.6, r * 0.6), c_wine, 1.0)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), c_coral)
	_draw_signal_pulses()


func c_stone_col() -> Color:
	return PAL["stone"] as Color
