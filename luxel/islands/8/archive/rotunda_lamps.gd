class_name LxArchiveRotundaLamps
extends LxToy
## Reading Rotunda centerpiece (archive_r1): displays 8 Island Memory Lantern Pedestals
## in an arc, lighting each in its biome colour as `mem_1_lit..mem_8_lit` are set,
## and syncing `isl8_all_memories_lit` when all 8 glow.

const MEM_COLS: Array[String] = [
	"gold", "sky", "jade", "lime", "blue", "coral", "ice", "rose",
]

var lit_count: int = 0
var _lit_mask: Array[bool] = [false, false, false, false, false, false, false, false]
var _pulse_t: float = 0.0
var _announced_all: bool = false


func _toy_setup() -> void:
	kind = "archive_rotunda_lamps"
	radius = 24.0
	z_index = -2
	_sync_memories()
	queue_redraw()


func _sync_memories() -> void:
	var n: int = 0
	for i: int in range(8):
		var fl: String = "mem_%d_lit" % (i + 1)
		var is_on: bool = false
		if region != null and region.has_method("is_flag_set"):
			is_on = bool(region.call("is_flag_set", fl))
		elif Lx.state != null:
			is_on = bool(Lx.state.story_flags.get(fl, false))
		_lit_mask[i] = is_on
		if is_on:
			n += 1
	lit_count = n
	if n >= 8 and Lx.state != null:
		Lx.state.story_flags["isl8_all_memories_lit"] = true
		if not _announced_all:
			_announced_all = true
			set_powered(true)
			_notify_linked_targets(true)


func tick(dt: float) -> void:
	super.tick(dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
	var prev_n: int = lit_count
	_sync_memories()
	if lit_count != prev_n or _pulse_t > 0.0 or lit_count > 0:
		queue_redraw()


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_sync_memories()
	_pulse_t = 0.60
	_emit_sfx("clockwork_chime")
	if Lx.events != null:
		if lit_count >= 8 and LxStrings.has_id("ISL8_ARC_ALL_MEM"):
			Lx.events.narration_requested.emit("ISL8_ARC_ALL_MEM", "title", 3.0)
		elif LxStrings.has_id("ISL8_ARC_LORE_R1"):
			Lx.events.narration_requested.emit("ISL8_ARC_LORE_R1", "narration", 2.8)
	queue_redraw()
	return true


func get_interact_prompt() -> String:
	return "ISL8_PROMPT_ROTUNDA" if active else ""


func get_light_pool() -> Vector4:
	if not active:
		return Vector4.ZERO
	var rad: float = 42.0 + float(lit_count) * 6.0
	var strength: float = 0.55 + float(lit_count) * 0.08
	return Vector4(pos.x, pos.y, rad, strength)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var fred: bool = LxHudFx.flash_reduced()

	# Curved marble mosaic arc on the Rotunda floor
	draw_arc(Vector2.ZERO, 46.0, PI * 1.05, PI * 1.95, 24, Color(c_gold, 0.25), 2.0)
	draw_arc(Vector2.ZERO, 34.0, PI * 1.05, PI * 1.95, 20, Color(PAL["mauve"] as Color, 0.30), 1.0)

	# Eight Island Memory Lantern Pedestals arranged across the north semicircle
	for i: int in range(8):
		var u: float = float(i) / 7.0
		var ang: float = lerpf(PI * 1.12, PI * 1.88, u)
		var lp: Vector2 = Vector2(cos(ang) * 44.0, sin(ang) * 26.0).round()
		var lit: bool = _lit_mask[i]
		var col: Color = LxPalette.color(MEM_COLS[i], "gold")
		draw_rect(Rect2(lp.x - 4.0, lp.y - 2.0, 8.0, 6.0), c_void)
		draw_rect(Rect2(lp.x - 3.0, lp.y - 1.0, 6.0, 4.0), c_dusk if lit else c_night)
		draw_rect(Rect2(lp.x - 3.0, lp.y - 5.0, 6.0, 4.0), c_void)
		if lit:
			var glow_r: float = 6.0 if fred else roundf(6.0 + sin(_clock * 3.0 + float(i)) * 1.0)
			draw_circle(lp + Vector2(0.0, -3.0), glow_r, Color(col, 0.16 if fred else 0.22))
			draw_rect(Rect2(lp.x - 2.0, lp.y - 4.0, 4.0, 3.0), col)
			draw_rect(Rect2(lp.x - 1.0, lp.y - 6.0, 2.0, 2.0), c_cream)
			draw_rect(Rect2(lp.x - 1.0, lp.y - 4.0, 2.0, 1.0), c_cream)
		else:
			draw_rect(Rect2(lp.x - 2.0, lp.y - 4.0, 4.0, 3.0), c_night)
			draw_rect(Rect2(lp.x - 3.0, lp.y - 5.0, 6.0, 1.0), c_dusk)
			draw_rect(Rect2(lp.x - 1.0, lp.y - 3.0, 2.0, 1.0), PAL["mauve"] as Color)

	# Central brass index lectern plaque showing lit count (e.g. 0/8..8/8)
	draw_rect(Rect2(-12.0, -4.0, 24.0, 10.0), c_void)
	draw_rect(Rect2(-11.0, -3.0, 22.0, 8.0), c_night)
	draw_rect(Rect2(-11.0, -3.0, 22.0, 1.0), c_gold)
	if lit_count >= 8:
		draw_rect(Rect2(-9.0, -5.0, 2.0, 2.0), c_cream)
		draw_rect(Rect2(7.0, -5.0, 2.0, 2.0), c_cream)
	LxPixelFont.draw_centered(self, "%d/8" % lit_count, 0.0, -1.0, c_cream if lit_count >= 8 else c_gold, 1, c_void)

	if _pulse_t > 0.0:
		var p: float = 1.0 - clampf(_pulse_t / 0.60, 0.0, 1.0)
		var pa: float = (1.0 - p) * (0.50 if fred else 0.90)
		draw_arc(Vector2.ZERO, roundf(lerpf(10.0, 48.0, p)), 0.0, TAU, 24, Color(c_gold, pa), 1.0)
