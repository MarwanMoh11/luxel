class_name LxMireSnufferBrain
extends LxSnatcherBrain
## Mire Snuffer (Island 4): hunts hung lanterns and snuffs them faster when unguarded
## (tell 0.42s, run 112 px/s, snuff/grab 0.65s). Unlike Magpie, bolts CAN damage and
## stagger it to reward intercepting it before it snuffs the light.

const SNUFF_TELL: float = 0.42
const SNUFF_RUN_SPEED: float = 112.0
const SNUFF_GRAB_UNGUARDED: float = 0.65
const SNUFF_GRAB_GUARDED: float = 0.85
const GUARD_CHECK_R: float = 60.0
const BOLT_STAGGER_TIME: float = 0.42
const SNUFF_CARRY_SPEED: float = 40.0

var snuff_fx_t: float = 0.0


func _init() -> void:
	super._init()
	kind = "mire_snuffer"
	island_id = 4
	max_hp = 1.75
	hp = 1.75
	body_radius = 4.5
	routine_speed = 46.0
	leash_radius = 160.0
	notice_radius = 176.0
	tell_time = SNUFF_TELL
	recover_time = SNUFF_GRAB_UNGUARDED
	run_speed = SNUFF_RUN_SPEED
	grab_time = SNUFF_GRAB_UNGUARDED
	carry_speed = SNUFF_CARRY_SPEED
	shard_drop = 3


func setup(spec: Dictionary, p_director: LxAttackDirector = null, p_world: Node = null) -> void:
	var merged: Dictionary = spec.duplicate()
	if not merged.has("run_speed"):
		merged["run_speed"] = SNUFF_RUN_SPEED
	if not merged.has("grab_time"):
		merged["grab_time"] = SNUFF_GRAB_UNGUARDED
	if not merged.has("carry_speed"):
		merged["carry_speed"] = SNUFF_CARRY_SPEED
	super.setup(merged, p_director, p_world)
	snuff_fx_t = 0.0


func catch_lantern() -> bool:
	return false


func try_catch_lantern(_lantern_obj: Object = null) -> bool:
	return false


func take_hit(hit: LxHit) -> int:
	if state == State.DEAD or hit == null:
		return HitResult.GLANCED
	var h: Dictionary = _read_hit(hit)
	var src: String = str(h["source"])
	var dmg: float = float(h["damage"])
	var orig: Vector2 = h["origin"] as Vector2
	var is_bolt: bool = src == LxHit.SOURCE_BOLT or src == LxHit.SOURCE_PRISM
	var is_heavy: bool = bool(h["stagger"])
	var is_opening: bool = sub_state == SubState.TELL or sub_state == SubState.RUN \
			or sub_state == SubState.GRAB or sub_state == SubState.CARRY or sub_state == SubState.STAGGER

	# Unlike Magpie, bolts DO damage and stagger Mire Snuffer so players can intercept it!
	hp -= dmg
	flash_t = 0.14 if (is_heavy or is_bolt) else 0.08
	var rel: Vector2 = orig - pos
	if rel.length() > 0.01:
		knock = -rel.normalized() * (KNOCK_SPEED if is_heavy else 88.0)

	_drop_carried_lantern()
	_release_all_claims()

	if hp <= 0.001:
		opened_kill = is_opening
		_die(hit)
		return HitResult.KILLED

	sub_state = SubState.STAGGER
	state = State.STAGGER
	state_timer = STAGGER_TIME if is_heavy else BOLT_STAGGER_TIME
	_emit_sfx("snuffer_intercept")
	_emit_enemy_hit(hit, HitResult.OPENED)
	return HitResult.OPENED


func _step_brain(dt: float) -> void:
	snuff_fx_t = maxf(0.0, snuff_fx_t - dt)
	# Snuff faster (0.65s) when the hung lantern is unguarded; slightly slower (0.85s) if Wick guards it.
	if sub_state == SubState.RUN:
		var unguarded: bool = not _has_player() or _get_wick_pos().distance_to(_get_lantern_pos()) > GUARD_CHECK_R
		grab_time = SNUFF_GRAB_UNGUARDED if unguarded else SNUFF_GRAB_GUARDED
	super._step_brain(dt)


func _take_lantern() -> void:
	var lan_p: Vector2 = _get_lantern_pos()
	var unguarded: bool = not _has_player() or _get_wick_pos().distance_to(lan_p) > GUARD_CHECK_R
	if unguarded:
		# Unguarded hung lantern gets snuffed outright, forcing recall & retreat.
		snuff_fx_t = 0.45
		carrying_lantern = false
		_release_all_claims()
		if Lx.events != null:
			Lx.events.lantern_struck.emit(lan_p)
		_emit_sfx("snuffer_snuff")
		cooldown = AGAIN_CD * 1.4
		_go_to(_far_perch(), SubState.SHY, State.POSITION)
		return
	super._take_lantern()


func _body_color() -> Color:
	return PAL["teal"] as Color


func _draw_extra(off: Vector2) -> void:
	# Hooded candle-snuffer bell cone silhouette (distinct from Magpie bird).
	var pts := PackedVector2Array([
		off + Vector2(0.0, -body_radius - 6.0),
		off + Vector2(-body_radius - 2.0, -1.0),
		off + Vector2(body_radius + 2.0, -1.0),
	])
	draw_colored_polygon(pts, PAL["pine"] as Color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), PAL["night"] as Color, 1.0)
	draw_circle(off + Vector2(-1.5, -2.0), 1.0, PAL["lime"] as Color)
	draw_circle(off + Vector2(1.5, -2.0), 1.0, PAL["lime"] as Color)
	if sub_state == SubState.GRAB:
		var r: float = body_radius + 5.0 + sin(anim_t * 18.0) * 1.5
		draw_arc(off, r, 0.0, TAU, 14, PAL["dusk"] as Color, 2.0)
	elif snuff_fx_t > 0.0:
		draw_arc(off, body_radius + 9.0, 0.0, TAU, 16, PAL["plum"] as Color, 2.0)
	elif carrying_lantern:
		draw_circle(off + Vector2(0.0, 4.0), 3.0, PAL["gold"] as Color)
		draw_circle(off + Vector2(0.0, 4.0), 1.5, PAL["cream"] as Color)
