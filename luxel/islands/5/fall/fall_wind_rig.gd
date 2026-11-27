class_name LxFallWindRig
extends LxToy
## Island 5 Set Piece Fall (fall_r1..fall_r3): Atmospheric free-fall director.
## Draws rushing vertical star-wind streaks and snapped brass dome chains plunging past
## the drifting marble debris islands, strictly within the 20-colour Last Light palette.

var _t: float = 0.0
var _span_w: float = 480.0
var _span_h: float = 300.0
var _speed: float = 110.0


func _toy_setup() -> void:
	kind = "fall_wind_rig"
	radius = 8.0
	_span_w = float(props.get("width", 480.0))
	_span_h = float(props.get("height", 300.0))
	_speed = float(props.get("speed", 110.0))
	z_index = -3
	queue_redraw()


func tick(dt: float) -> void:
	super.tick(dt)
	var spd_mul: float = 0.45 if LxHudFx.flash_reduced() else 1.0
	_t += dt * spd_mul
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var pal: Dictionary = LxPalette.PAL
	var ice: Color = pal["ice"] as Color
	var sky: Color = pal["sky"] as Color
	var apricot: Color = pal["apricot"] as Color
	var night: Color = pal["night"] as Color
	var fred: bool = LxHudFx.flash_reduced()
	var streaks: int = 8 if fred else 16
	var half_w: float = _span_w * 0.5
	var half_h: float = _span_h * 0.5

	# Rushing star-wind streaks rising past falling debris
	for i: int in range(streaks):
		var u: float = (float(i) + 0.5) / float(streaks)
		var sx: float = roundf(-half_w + u * _span_w)
		var sy: float = roundf(-half_h + fposmod(-_t * _speed + float(i) * 43.0, _span_h))
		var slen: float = 10.0 + float(i % 3) * 5.0
		var c: Color = ice if (i % 3 == 0) else sky
		draw_line(Vector2(sx, sy), Vector2(sx, sy + slen), Color(c, 0.30), 1.0)

	# Distant tumbling snapped brass anchor chain silhouettes along outer flanks
	var chains: int = 2 if fred else 4
	for ci: int in range(chains):
		var cx: float = (-half_w + 36.0 + float(ci) * ((_span_w - 72.0) / maxf(1.0, float(chains - 1))))
		var cy: float = -half_h + fposmod(-_t * (_speed * 0.65) + float(ci) * 89.0, _span_h)
		for link: int in range(4):
			var lp := Vector2(roundf(cx + sin(_t * 2.2 + float(ci + link)) * 2.5), roundf(cy + float(link) * 8.0))
			draw_circle(lp, 2.5, night)
			draw_arc(lp, 2.5, 0.0, TAU, 8, Color(apricot, 0.45), 1.0)
