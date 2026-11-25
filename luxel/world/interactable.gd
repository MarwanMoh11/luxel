class_name LxInteractable
extends Node2D
## Base contract for every world interactable in Luxel 1.0.
## Subclasses override interact(), on_hit(), on_light(), save_state(), load_state(), and tick().

const PAL: Dictionary = {
	"void": Color("0d0b1e"),
	"night": Color("211a3b"),
	"dusk": Color("3d2c5c"),
	"plum": Color("6a3d6f"),
	"wine": Color("a0466a"),
	"coral": Color("e2725b"),
	"apricot": Color("f5a96a"),
	"gold": Color("ffd98c"),
	"cream": Color("fff4dc"),
	"pine": Color("1d3d4c"),
	"teal": Color("2b6b68"),
	"jade": Color("4c9e78"),
	"lime": Color("a3cf7d"),
	"deep": Color("263873"),
	"blue": Color("3e6db0"),
	"sky": Color("78a9da"),
	"ice": Color("c7e5ef"),
	"mauve": Color("8a6e91"),
	"stone": Color("c2a7ae"),
	"rose": Color("ec9fa8"),
}

const PROP_SHEET_PATH: String = "res://luxel/art/props/island1_props.json"
const PUZZLE_SHEET_PATH: String = "res://luxel/art/props/puzzle_interactables.json"

var id: String = ""
var kind: String = ""
var pos: Vector2 = Vector2.ZERO
var radius: float = 14.0
var active: bool = true
var props: Dictionary = {}

var region: Node = null
var island_id: int = 1
var region_id: String = ""
var _clock: float = 0.0
var _uses_prop_anim: bool = false
var _signal_pulses: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(spec: Dictionary) -> void:
	id = str(spec.get("id", id))
	kind = str(spec.get("kind", kind))
	var raw_props: Variant = spec.get("props", {})
	props = (raw_props as Dictionary).duplicate(true) if raw_props is Dictionary else {}
	pos = _parse_vec2(spec.get("pos", pos))
	position = pos.round()
	if spec.has("radius"):
		radius = maxf(2.0, float(spec.get("radius", radius)))
	elif props.has("radius"):
		radius = maxf(2.0, float(props.get("radius", radius)))
	active = bool(spec.get("active", props.get("active", true)))
	name = id if not id.is_empty() else kind
	queue_redraw()


func interact(_actor: Node = null) -> bool:
	return false


func on_hit(_hit: LxHit) -> bool:
	return false


func on_light(_light_radius: float, _source: String) -> void:
	pass


func on_signal(_from_id: String, _powered: bool) -> void:
	pass


func save_state() -> Dictionary:
	return {"active": active}


func load_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	active = bool(d.get("active", active))
	queue_redraw()


func tick(dt: float) -> void:
	_clock += dt
	if not _signal_pulses.is_empty():
		for i: int in range(_signal_pulses.size() - 1, -1, -1):
			_signal_pulses[i]["age"] = float(_signal_pulses[i]["age"]) + dt
			if float(_signal_pulses[i]["age"]) >= float(_signal_pulses[i]["life"]):
				_signal_pulses.remove_at(i)
		queue_redraw()
	if _uses_prop_anim:
		queue_redraw()


static func get_puzzle_sheet() -> LxSpriteSheet:
	return LxSpriteSheet.load_sheet(PUZZLE_SHEET_PATH)


func _draw_ground_shadow(rx: float, ry: float, offset: Vector2 = Vector2(2.0, 1.0)) -> void:
	var pts := PackedVector2Array()
	pts.resize(12)
	for i: int in range(12):
		var a: float = (TAU * float(i)) / 12.0
		var sx: float = cos(a) * rx + sin(a) * ry * 0.35 + offset.x
		var sy: float = sin(a) * ry + offset.y
		pts[i] = Vector2(roundf(sx), roundf(sy))
	draw_colored_polygon(pts, Color(PAL["void"] as Color, 0.32))


func _draw_puzzle_sprite(
	prop_key: String,
	offset: Vector2 = Vector2.ZERO,
	time_s: float = -1.0,
	modulate: Color = Color.WHITE,
	frame_override: int = -1
) -> bool:
	var sheet: LxSpriteSheet = get_puzzle_sheet()
	if sheet == null:
		return false
	var t_use: float = time_s if time_s >= 0.0 else _clock
	return sheet.draw_prop(self, offset, prop_key, t_use, modulate, frame_override)


func _draw_puzzle_tiled(
	prop_key: String,
	rect_size: Vector2,
	offset: Vector2 = Vector2.ZERO,
	time_s: float = -1.0,
	modulate: Color = Color.WHITE,
	frame_override: int = -1
) -> bool:
	var sheet: LxSpriteSheet = get_puzzle_sheet()
	if sheet == null or sheet.tex == null or not sheet.props.has(prop_key):
		return false
	var pinfo_v: Variant = sheet.props.get(prop_key, null)
	if not (pinfo_v is Dictionary):
		return false
	var pinfo: Dictionary = pinfo_v as Dictionary
	var rects_v: Variant = pinfo.get("rects", null)
	if not (rects_v is Array) or (rects_v as Array).is_empty():
		return false
	var rects: Array = rects_v as Array
	var idx: int = 0
	if frame_override >= 0:
		idx = clampi(frame_override, 0, rects.size() - 1)
	else:
		var ms_v: Variant = pinfo.get("ms", [])
		var ms_arr: Array = ms_v as Array if ms_v is Array else []
		var t_use: float = time_s if time_s >= 0.0 else _clock
		idx = LxSpriteSheet._pick_frame(rects.size(), ms_arr, t_use, bool(pinfo.get("loop", true)))
	var src: Rect2 = LxSpriteSheet._to_rect2(rects[idx])
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return false
	var w: float = roundf(rect_size.x)
	var h: float = roundf(rect_size.y)
	var x0: float = floorf(-w * 0.5) + roundf(offset.x)
	var y0: float = floorf(-h * 0.5) + roundf(offset.y)
	var ty: float = y0
	while ty < y0 + h - 0.01:
		var th: float = minf(src.size.y, y0 + h - ty)
		var sy_off: float = (src.size.y - th) if (th < src.size.y and ty > y0) else 0.0
		var tx: float = x0
		while tx < x0 + w - 0.01:
			var tw: float = minf(src.size.x, x0 + w - tx)
			var sx_off: float = (src.size.x - tw) if (tw < src.size.x and tx > x0) else 0.0
			var sub_src := Rect2(src.position.x + sx_off, src.position.y + sy_off, tw, th)
			draw_texture_rect_region(sheet.tex, Rect2(tx, ty, tw, th), sub_src, modulate)
			tx += tw
		ty += th
	return true


func _draw_prop_sprite(
	prop_key: String,
	offset: Vector2 = Vector2.ZERO,
	frame_override: int = -1,
	modulate: Color = Color.WHITE
) -> bool:
	var island_path: String = "res://luxel/art/props/island%d_props.json" % clampi(island_id, 1, 8)
	var sheet: LxSpriteSheet = LxSpriteSheet.load_sheet(island_path)
	if sheet != null and sheet.draw_prop(self, offset, prop_key, _clock, modulate, frame_override):
		_uses_prop_anim = frame_override < 0
		return true
	if island_path != PROP_SHEET_PATH:
		var fallback_sheet: LxSpriteSheet = LxSpriteSheet.load_sheet(PROP_SHEET_PATH)
		if fallback_sheet != null and fallback_sheet.draw_prop(self, offset, prop_key, _clock, modulate, frame_override):
			_uses_prop_anim = frame_override < 0
			return true
	return false


func is_solid() -> bool:
	return false


func blocks_sight() -> bool:
	return is_solid()


func get_solid_rect() -> Rect2:
	if not is_solid():
		return Rect2()
	return Rect2(pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))


func is_platform_solid() -> bool:
	return false


func get_platform_rect() -> Rect2:
	return Rect2()


func is_reflective() -> bool:
	return false


func reflect_dir(in_dir: Vector2) -> Vector2:
	return in_dir


func get_light_pool() -> Vector4:
	return Vector4.ZERO


func get_interact_prompt() -> String:
	return ""


func get_state_key() -> String:
	return "%d:%s:%s" % [island_id, region_id, id]


## Any interactable may carry `sets_flag`: the story flag it raises once when it is solved, lit, opened or pressed.
func raise_flag_prop() -> void:
	var sf: String = str(props.get("sets_flag", "")).strip_edges()
	if sf.is_empty() or Lx.state == null or bool(Lx.state.story_flags.get(sf, false)):
		return
	Lx.state.story_flags[sf] = true


func _notify_linked_targets(powered: bool = true) -> void:
	if region == null or not region.has_method("find_interactable"):
		return
	var targets: Array[String] = []
	var single: String = str(props.get("target_id", ""))
	if not single.is_empty():
		targets.append(single)
	var multi: Variant = props.get("target_ids", [])
	if multi is Array:
		for item: Variant in multi:
			var tid: String = str(item)
			if not tid.is_empty() and not targets.has(tid):
				targets.append(tid)
	for tid: String in targets:
		var target: Variant = region.call("find_interactable", tid)
		if target is LxInteractable:
			var it_t: LxInteractable = target as LxInteractable
			it_t.on_signal(id, powered)
			if powered and it_t.pos.distance_to(pos) > 8.0:
				_signal_pulses.append({"to": it_t.pos - pos, "age": 0.0, "life": 0.44})
				queue_redraw()


func _draw_signal_pulses() -> void:
	if _signal_pulses.is_empty():
		return
	for sp: Dictionary in _signal_pulses:
		var u: float = clampf(float(sp["age"]) / maxf(float(sp["life"]), 0.01), 0.0, 1.0)
		var dest: Vector2 = sp["to"] as Vector2
		var start := Vector2(0.0, -6.0)
		var arc_h: float = minf(26.0, dest.length() * 0.18 + 8.0)
		var b_sig_g: Color = LxBiomePalette.col(island_id, "glow")
		var b_sig_h: Color = LxBiomePalette.col(island_id, "hi")
		for k: int in range(3):
			var uk: float = clampf(u - float(k) * 0.08, 0.0, 1.0)
			var pt: Vector2 = (start.lerp(dest, uk) + Vector2(0.0, -sin(uk * PI) * arc_h)).round()
			var col: Color = (PAL["cream"] as Color) if k == 0 else (b_sig_g if k == 1 else b_sig_h)
			var sz: float = 3.0 if k == 0 else (2.0 if k == 1 else 1.0)
			draw_rect(Rect2(pt - Vector2(floorf(sz * 0.5), floorf(sz * 0.5)), Vector2(sz, sz)), col)


func _emit_sfx(sfx_id: String) -> void:
	if Lx.events != null:
		Lx.events.sfx_requested.emit(sfx_id, pos, true)


func _emit_save(reason: String) -> void:
	if Lx.events != null:
		Lx.events.save_requested.emit(reason)


func _emit_gust(gust_radius: float, strength: float, offset: Vector2 = Vector2.ZERO) -> void:
	if Lx.world != null and is_instance_valid(Lx.world):
		var amb: Variant = Lx.world.get("_ambient_life")
		if amb is Object and is_instance_valid(amb) and (amb as Object).has_method("_gust_particles"):
			(amb as Object).call("_gust_particles", pos + offset, gust_radius, strength)


static func _parse_vec2(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Vector2:
		return v as Vector2
	if v is Array and (v as Array).size() >= 2:
		var arr: Array = v as Array
		return Vector2(float(arr[0]), float(arr[1]))
	return fallback


static func _parse_size(v: Variant, fallback: Vector2) -> Vector2:
	var s: Vector2 = _parse_vec2(v, fallback)
	return Vector2(maxf(4.0, s.x), maxf(4.0, s.y))
