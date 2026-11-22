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
	if _sprite_sheet == null:
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
	var c := Vector2(roundf(off.x), roundf(off.y))
	if sub_state == SubState.GRAB:
		var spin: float = anim_t * 6.5
		var vr: float = roundf(body_radius + 5.5 + sin(anim_t * 16.0) * 1.0)
		for vi: int in range(3):
			var a0: float = spin + float(vi) * (TAU / 3.0)
			draw_arc(c, vr + 1.5, a0, a0 + 1.15, 8, PAL["night"] as Color, 2.2)
			draw_arc(c, vr, a0 + 0.15, a0 + 1.25, 8, PAL["dusk"] as Color, 1.6)
			draw_arc(c, maxf(2.0, vr - 2.0), a0 + 0.40, a0 + 1.15, 6, PAL["plum"] as Color, 1.1)
		for wi: int in range(4):
			var wt: float = fmod(anim_t * 2.0 + float(wi) * 0.25, 1.0)
			var wr: float = lerpf(body_radius + 11.0, body_radius + 1.5, wt)
			var wa: float = spin * 0.8 + float(wi) * (PI * 0.5) + wt * 1.8
			var wp := Vector2(roundf(c.x + cos(wa) * wr), roundf(c.y + sin(wa) * wr))
			draw_rect(Rect2(wp, Vector2(1.0, 1.0)), PAL["lime"] as Color, true)
			draw_rect(Rect2(roundf(c.x + cos(wa - 0.22) * (wr + 1.5)), roundf(c.y + sin(wa - 0.22) * (wr + 1.5)), 1.0, 1.0), PAL["teal"] as Color, true)
	elif snuff_fx_t > 0.0:
		var sp: float = 1.0 - clampf(snuff_fx_t / 0.45, 0.0, 1.0)
		var sr: float = roundf(body_radius + 4.0 + sp * 9.5)
		draw_arc(c, sr + 1.5, 0.0, TAU, 16, PAL["dusk"] as Color, 2.0)
		draw_arc(c, sr, 0.0, TAU, 16, PAL["plum"] as Color, 1.4)
		draw_arc(c, maxf(2.0, sr - 2.5), 0.0, TAU, 12, PAL["stone"] as Color, 1.0)
		for pi: int in range(6):
			var pa: float = float(pi) * (TAU / 6.0) + sp * 0.45
			var pp := Vector2(roundf(c.x + cos(pa) * sr), roundf(c.y + sin(pa) * sr - sp * 3.0))
			var pc: Color = (PAL["dusk"] as Color) if (pi % 3 == 0) else ((PAL["plum"] as Color) if (pi % 3 == 1) else (PAL["stone"] as Color))
			draw_circle(pp, 2.0 if sp < 0.55 else 1.2, pc)
	elif carrying_lantern:
		var sway: float = roundf(sin(anim_t * 9.5) * 1.5)
		var lx: float = c.x + sway
		var ly: float = c.y + 5.0
		draw_rect(Rect2(lx - 3.0, ly - 4.0, 7.0, 2.0), PAL["night"] as Color, true)
		draw_rect(Rect2(lx - 3.0, ly - 2.0, 7.0, 6.0), PAL["void"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly - 1.0, 5.0, 4.0), PAL["gold"] as Color, true)
		var flick: float = 0.0 if (int(anim_t * 10.0) % 2 == 0) else 1.0
		draw_rect(Rect2(lx, ly + flick, 1.0, 1.0), PAL["cream"] as Color, true)
		draw_rect(Rect2(lx - 1.0, ly - 2.0, 1.0, 5.0), PAL["night"] as Color, true)
		draw_rect(Rect2(lx + 1.0, ly - 2.0, 1.0, 5.0), PAL["night"] as Color, true)
		draw_rect(Rect2(lx - 2.0, ly + 3.0, 5.0, 1.0), PAL["apricot"] as Color, true)
		var back: Vector2 = -Vector2.from_angle(facing)
		draw_rect(Rect2(roundf(lx + back.x * 5.0), roundf(ly + back.y * 5.0 - 1.0), 1.0, 1.0), PAL["mauve"] as Color, true)
