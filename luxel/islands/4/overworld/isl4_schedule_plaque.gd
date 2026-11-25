class_name LxIsl4SchedulePlaque
extends LxToy
## Island 4 Dusk Schedule Obelisk (`isl4_schedule_plaque`):
## Makes Mirefen's 6-hour dusk schedule visible BEFORE it matters.
## Displays 6 colour-coded hour pips synced live to `dusk_hour` (1..6) and
## narrates the active hour's garden event on interact.
## Props: highlight_hours (Array[int]).

const HOUR_STRINGS: Array[String] = [
	"ISL4_SCHED_H1",
	"ISL4_SCHED_H2",
	"ISL4_SCHED_H3",
	"ISL4_SCHED_H4",
	"ISL4_SCHED_H5",
	"ISL4_SCHED_H6",
]

var highlight_hours: Array[int] = []
var current_hour: int = 1
var _flash_t: float = 0.0


func _toy_setup() -> void:
	kind = "isl4_schedule_plaque"
	radius = 16.0
	highlight_hours.clear()
	var raw_h: Variant = props.get("highlight_hours", [])
	if raw_h is Array:
		for v: Variant in (raw_h as Array):
			highlight_hours.append(int(v))
	_sync_hour()
	queue_redraw()


func _sync_hour() -> void:
	var h: int = 1
	if Lx.vars != null:
		var v: Variant = Lx.vars.get_var("island:4", "dusk_hour", 1)
		if str(v).is_valid_float():
			h = clampi(int(v), 1, 6)
	if h != current_hour:
		current_hour = h
		queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	_sync_hour()
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_sync_hour()
	_flash_t = 0.65
	_emit_sfx("clockwork_chime")
	var idx: int = clampi(current_hour - 1, 0, HOUR_STRINGS.size() - 1)
	var sid: String = HOUR_STRINGS[idx]
	if Lx.events != null and LxStrings.has_id(sid):
		Lx.events.narration_requested.emit(sid, "narration", 3.4)
	set_powered(true)
	emit_power(true)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL4_PROMPT_READ_DIAL" if active else ""


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos + Vector2(-7.0, -3.0), Vector2(14.0, 9.0)) if is_solid() else Rect2()


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 38.0 if _flash_t > 0.0 else 28.0, 0.62 if _flash_t > 0.0 else 0.40)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_stone: Color = PAL["stone"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var hour_cols: Array[Color] = [
		PAL["mauve"] as Color,
		PAL["rose"] as Color,
		PAL["sky"] as Color,
		PAL["ice"] as Color,
		PAL["gold"] as Color,
		PAL["coral"] as Color,
	]

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 6.0), 8.0, 2.8)
	LxToyDraw.draw_bevel_box(self, Rect2(-8.0, 0.0, 16.0, 6.0), c_night, c_dusk, c_stone, c_void)
	LxToyDraw.draw_bevel_box(self, Rect2(-7.0, -17.0, 14.0, 18.0), c_night, c_dusk, c_gold, c_void)

	# 6-hour schedule ledger bars (2 columns x 3 rows)
	for i: int in range(6):
		var hr: int = i + 1
		var col_i: int = i / 3
		var row_i: int = i % 3
		var px: float = -5.0 + float(col_i) * 6.0
		var py: float = -14.0 + float(row_i) * 4.0
		var is_cur: bool = (hr == current_hour)
		var is_hi: bool = highlight_hours.has(hr)
		var c: Color = c_cream if is_cur else (hour_cols[i] if (is_hi or highlight_hours.is_empty()) else c_dusk)
		draw_rect(Rect2(px, py, 4.0, 2.0), c)
		if is_cur:
			draw_rect(Rect2(px - 1.0, py, 1.0, 2.0), c_gold)
	if _flash_t > 0.0:
		var u: float = 1.0 - clampf(_flash_t / 0.65, 0.0, 1.0)
		draw_arc(Vector2(0.0, -8.0), roundf(lerpf(6.0, 16.0, u)), 0.0, TAU, 14, c_cream, 1.0)
