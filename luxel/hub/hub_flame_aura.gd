class_name LxHubFlameAura
extends Node2D
## Live Lantern Flame Colour Aura attached to Wick when a custom flame colour is equipped
## at the Tailor Spider or Moth Lantern. Strict 20-colour Last Light palette; flash-reduced safe.

var _clock: float = 0.0
var _wick: Node2D = null


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func bind_wick(wick: Node2D) -> void:
	_wick = wick


func _process(delta: float) -> void:
	if _wick == null or not is_instance_valid(_wick):
		queue_free()
		return
	_clock += delta
	var fid: String = LxHubState.get_equipped_flame()
	visible = fid != "gold" and _wick.get("dead") != true
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible or _wick == null:
		return
	var fid: String = LxHubState.get_equipped_flame()
	if fid == "gold":
		return
	var spec: Dictionary = LxHubState.get_flame_spec(fid)
	var main_c: Color = LxPalette.color(fid, "gold")
	var rim_c: Color = LxPalette.color(str(spec.get("rim", "apricot")), "apricot")
	var core_c: Color = LxPalette.color(str(spec.get("core", "cream")), "cream")
	var fred: bool = LxHudFx.flash_reduced()

	# Position halo over lantern (in hand or thrown)
	var center := Vector2(0.0, -7.0)
	var lan: Variant = _wick.get("lantern")
	if lan is Node2D and is_instance_valid(lan as Node) and (lan as Node).has_method("is_out") and bool((lan as Node).call("is_out")):
		center = ((lan as Node2D).global_position - _wick.global_position).round() + Vector2(0.0, -5.0)
	else:
		var facing_v: Variant = _wick.get("facing")
		if facing_v is Vector2 and (facing_v as Vector2).length_squared() > 0.01:
			center += (facing_v as Vector2).normalized() * 5.0
		center = center.round()

	# Crisp opaque Last Light pixel halo ring + rising ember pips (zero semi-transparent fog)
	var r: float = 7.0 if fred else 7.0 + roundf(sin(_clock * 4.5) * 1.0)
	for i: int in range(6):
		var ang: float = (0.0 if fred else (_clock * 1.8)) + float(i) * (TAU / 6.0)
		var pt := (center + Vector2(cos(ang) * r, sin(ang) * r * 0.72)).round()
		draw_rect(Rect2(pt, Vector2(1.0, 1.0)), main_c if i % 2 == 0 else rim_c)
	# Void-backed bright tinted core pip right on the lantern wick
	var bob: float = 0.0 if fred else roundf(sin(_clock * 6.5) * 0.6)
	draw_rect(Rect2(center + Vector2(-2.0, -3.0 + bob), Vector2(4.0, 4.0)), LxPalette.PAL["void"])
	draw_rect(Rect2(center + Vector2(-1.0, -2.0 + bob), Vector2(2.0, 2.0)), main_c)
	draw_rect(Rect2(center + Vector2(0.0, -2.0 + bob), Vector2(1.0, 1.0)), core_c)
	# Gentle rising sparks (single steady ember under flash_reduced)
	if fred:
		draw_rect(Rect2(center + Vector2(0.0, -6.0), Vector2(1.0, 1.0)), main_c)
	else:
		for si: int in range(2):
			var ph: float = fmod(_clock * 0.9 + float(si) * 0.5, 1.0)
			var sx: float = roundf(sin(_clock * 2.1 + float(si) * PI) * 3.0)
			var sy: float = roundf(-4.0 - ph * 9.0)
			draw_rect(Rect2(center + Vector2(sx, sy), Vector2(1.0, 1.0)), core_c if ph < 0.45 else main_c)
