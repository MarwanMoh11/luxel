class_name LxOwTwinClapperSeal
extends LxToy
## Belfry Forecourt Twin Clapper Seal (Island 1 grand dungeon gate).
## Displays Undercroft Spade (W) and Manor Clapper (E) sockets.
## - Enforces `undercroft_cleared` + `manor_cleared` so the Twin Clapper Seal opens into
##   The Great Toll (`toll_r1`) on first ascent and `belfry_r1` once `great_toll_done` is set.
## - Legacy saves that already passed the seal (`isl1_belfry_entered`, `tut_belfry_entered`,
##   `great_lamp_1`, `boss_bellkeeper_defeated`) remain permanently passed.
## - While Manor (`P1-B`) is still `debug_only` (not yet landed on disk), opens once `seal_broken_1`
##   is broken (unless `force_strict: true`) so neither players nor `island_check` softlock.

const LEGACY_PASS_FLAGS: PackedStringArray = [
	"isl1_belfry_entered",
	"tut_belfry_entered",
	"great_lamp_1",
	"boss_bellkeeper_defeated",
	"belfry_seal_passed",
]

var opened: bool = false
var force_strict: bool = false
var _open_t: float = 0.0
var _rattle_t: float = 0.0


func _toy_setup() -> void:
	kind = "ow_twin_clapper_seal"
	if not props.has("size"):
		size = Vector2(48.0, 16.0)
	radius = maxf(size.x, size.y) * 0.5 + 8.0
	persist = true
	force_strict = bool(props.get("force_strict", false))
	opened = _evaluate_open()
	powered = opened
	if opened and Lx.state != null and not id.is_empty() and not Lx.state.opened_doors.has(id):
		Lx.state.opened_doors.append(id)
	queue_redraw()


func _has_flag(flag_id: String) -> bool:
	if Lx.state == null or flag_id.is_empty():
		return false
	if region != null and region.has_method("is_flag_set"):
		if bool(region.call("is_flag_set", flag_id)):
			return true
	return bool(Lx.state.story_flags.get(flag_id, false)) or Lx.state.opened_doors.has(flag_id) or Lx.state.broken_seals.has(flag_id)


func _has_undercroft() -> bool:
	return _has_flag("undercroft_cleared") or _has_flag("dungeon_done:undercroft")


func _has_manor() -> bool:
	return _has_flag("manor_cleared") or _has_flag("dungeon_done:manor")


func _has_toll() -> bool:
	return _has_flag("great_toll_done") or _has_flag("dungeon_done:great_toll")


func _is_dungeon_live(dun_id: String) -> bool:
	if Lx.packs == null:
		return false
	var meta: Dictionary = Lx.packs.dungeon(dun_id)
	if meta.is_empty():
		return false
	return not bool(meta.get("debug_only", false))


func _has_legacy_pass() -> bool:
	if Lx.state == null:
		return false
	if not id.is_empty() and (Lx.state.opened_doors.has(id) or Lx.state.broken_seals.has(id)):
		return true
	for fl: String in LEGACY_PASS_FLAGS:
		if _has_flag(fl):
			return true
	return Lx.state.relit_islands.has(1) or Lx.state.defeated_bosses.has("bellkeeper")


func _evaluate_open() -> bool:
	if _has_legacy_pass():
		return true
	var uc_ok: bool = _has_undercroft()
	var mn_ok: bool = _has_manor()
	if uc_ok and mn_ok:
		return true
	# Before Manor (P1-B) leaves debug_only, allow seal_broken_1 to pass so Island 1 stays completable
	if not force_strict and not _is_dungeon_live("manor"):
		if _has_flag("seal_broken_1") or _has_flag("bell_arch_seal"):
			return true
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if _open_t > 0.0:
		_open_t = maxf(0.0, _open_t - dt)
		queue_redraw()
	if _rattle_t > 0.0:
		_rattle_t = maxf(0.0, _rattle_t - dt)
		queue_redraw()
	if not active:
		return
	if not opened and _evaluate_open():
		_open_seal()


func _open_seal() -> void:
	opened = true
	_open_t = 0.65
	set_powered(true)
	emit_power(true)
	if Lx.state != null:
		Lx.state.story_flags["belfry_seal_passed"] = true
		if not id.is_empty() and not Lx.state.opened_doors.has(id):
			Lx.state.opened_doors.append(id)
	_emit_sfx("seal_break")
	_emit_gust(64.0, 56.0)
	_emit_shake(0.22)
	if Lx.events != null:
		if LxStrings.has_id("ISL1_SEAL_OPEN"):
			Lx.events.narration_requested.emit("ISL1_SEAL_OPEN", "title", 3.0)
	queue_redraw()


func _emit_shake(amp: float) -> void:
	if Lx.events != null:
		Lx.events.shake_requested.emit(amp * (0.45 if LxHudFx.flash_reduced() else 1.0))


func interact(_actor: Node = null) -> bool:
	if not active or opened:
		return false
	if _evaluate_open():
		_open_seal()
		return true
	_rattle_t = 0.28
	_emit_sfx("door_locked")
	if Lx.events != null:
		var msg_id: String = "ISL1_SEAL_NEED_BOTH"
		if _has_undercroft() and not _has_manor():
			msg_id = "ISL1_SEAL_NEED_MN"
		elif _has_manor() and not _has_undercroft():
			msg_id = "ISL1_SEAL_NEED_UC"
		if LxStrings.has_id(msg_id):
			Lx.events.narration_requested.emit(msg_id, "narration", 3.0)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	if not active or opened:
		return ""
	return "ISL1_PROMPT_FIT" if LxStrings.has_id("ISL1_PROMPT_FIT") else "PROMPT_INSPECT"


func is_solid() -> bool:
	return active and not opened


func is_solid_blocker() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	return Rect2(pos - size * 0.5, size) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	if opened:
		return Vector4(pos.x, pos.y, 44.0, 0.55)
	return Vector4(pos.x, pos.y - 4.0, 56.0, 0.82)


func save_state() -> Dictionary:
	return {"active": active, "opened": opened}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	opened = bool(d.get("opened", opened)) or _evaluate_open()
	powered = opened
	queue_redraw()


func _draw() -> void:
	var red: bool = LxHudFx.flash_reduced()
	var w: float = roundf(size.x)
	var h: float = roundf(size.y)
	var rx: float = (1.0 if int(_rattle_t * 36.0) % 2 == 0 else -1.0) if (_rattle_t > 0.0 and LxHudFx.shake_enabled() and not red) else 0.0
	var x0: float = floorf(-w * 0.5) + rx
	var y0: float = floorf(-h * 0.5)
	var uc_lit: bool = _has_undercroft()
	var mn_lit: bool = _has_manor()
	var c_void: Color = PAL["void"] as Color
	var c_cream: Color = PAL["cream"] as Color

	if opened:
		# Recessed bronze jambs with twin glowing clapper crests
		draw_rect(Rect2(x0, y0, 6.0, h), PAL["night"] as Color)
		draw_rect(Rect2(x0 + 1.0, y0 + 1.0, 4.0, h - 2.0), PAL["apricot"] as Color)
		draw_rect(Rect2(x0 + w - 6.0, y0, 6.0, h), PAL["night"] as Color)
		draw_rect(Rect2(x0 + w - 5.0, y0 + 1.0, 4.0, h - 2.0), PAL["apricot"] as Color)
		draw_rect(Rect2(x0 + 2.0, y0 + 3.0, 2.0, 4.0), PAL["gold"] as Color)
		draw_rect(Rect2(x0 + w - 4.0, y0 + 3.0, 2.0, 4.0), PAL["gold"] as Color)
		if _open_t > 0.0:
			var u: float = 1.0 - clampf(_open_t / 0.65, 0.0, 1.0)
			var r_col := Color(PAL["gold"] as Color, (1.0 - u) * (0.55 if red else 0.90))
			draw_arc(Vector2.ZERO, roundf(10.0 + u * (24.0 if red else 34.0)), 0.0, TAU, 20, r_col, 1.0 if red else 2.0)
		return

	# Grand bronze Twin Clapper Gate
	LxToyDraw.draw_bevel_box(self, Rect2(x0, y0, w, h), PAL["night"] as Color, PAL["dusk"] as Color, PAL["mauve"] as Color, c_void)
	# Center seal bar
	draw_rect(Rect2(-3.0 + rx, y0 + 2.0, 6.0, h - 4.0), PAL["plum"] as Color)
	draw_rect(Rect2(-1.0 + rx, y0 + 3.0, 2.0, h - 6.0), PAL["gold"] as Color if (uc_lit and mn_lit) else PAL["stone"] as Color)
	# Left socket: Undercroft Spade (pointed spade silhouette when lit vs empty hollow slot)
	var lx: float = -12.0 + rx
	draw_rect(Rect2(lx - 4.0, -4.0, 8.0, 8.0), c_void)
	draw_rect(Rect2(lx - 3.0, -3.0, 6.0, 6.0), (PAL["jade"] if uc_lit else PAL["night"]) as Color)
	if uc_lit:
		draw_rect(Rect2(lx - 2.0, -1.0, 4.0, 2.0), c_cream)
		draw_rect(Rect2(lx - 1.0, -3.0, 2.0, 5.0), c_cream)
		draw_rect(Rect2(lx - 2.0, 2.0, 4.0, 1.0), PAL["gold"] as Color)
	else:
		draw_rect(Rect2(lx - 1.0, -2.0, 2.0, 4.0), c_void)
	# Right socket: Manor Clapper (weighted pendulum bulb silhouette when lit vs empty hollow slot)
	var rxx: float = 12.0 + rx
	draw_rect(Rect2(rxx - 4.0, -4.0, 8.0, 8.0), c_void)
	draw_rect(Rect2(rxx - 3.0, -3.0, 6.0, 6.0), (PAL["coral"] if mn_lit else PAL["night"]) as Color)
	if mn_lit:
		draw_rect(Rect2(rxx - 1.0, -3.0, 2.0, 3.0), PAL["gold"] as Color)
		draw_rect(Rect2(rxx - 2.0, 0.0, 4.0, 3.0), c_cream)
	else:
		draw_rect(Rect2(rxx - 1.0, -2.0, 2.0, 4.0), c_void)
