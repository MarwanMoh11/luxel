class_name LxHit
extends RefCounted
## Immutable-style hit record passed through every damage path in Luxel 1.0.

const SOURCE_BOLT: String = "bolt"
const SOURCE_PRISM: String = "prism_bolt"
const SOURCE_PRISM_BOLT: String = SOURCE_PRISM
const SOURCE_BEAM: String = "beam"
const SOURCE_THROW: String = "throw"
const SOURCE_RECALL: String = "recall"
const SOURCE_ZIP: String = "zip"
const SOURCE_DASH: String = "dash"
const SOURCE_SUNFLARE: String = "sunflare"
const SOURCE_HAZARD: String = "hazard"

const COLOR_YELLOW: String = "yellow"
const COLOR_BLUE: String = "blue"

var source: String = SOURCE_BOLT
var light_color: String = COLOR_YELLOW
var damage: float = 0.0
var dir: Vector2 = Vector2.RIGHT
var pierce: bool = false
var shield_wear: float = 0.0
var stagger: bool = false
var origin: Vector2 = Vector2.ZERO
var attacker: Object = null
var cracks_armour: bool = false
var curve_angle_deg: float = 0.0


static func make(
	p_source: String,
	p_damage: float,
	p_dir: Vector2,
	p_origin: Vector2,
	p_shield_wear: float = 0.0,
	p_stagger: bool = false,
	p_pierce: bool = false,
	p_attacker: Object = null,
	p_cracks_armour: bool = false,
	p_light_color: String = "",
	p_curve_angle_deg: float = 0.0
) -> LxHit:
	var hit := LxHit.new()
	hit.source = p_source
	if not p_light_color.is_empty():
		hit.light_color = p_light_color
	else:
		hit.light_color = COLOR_BLUE if p_source == SOURCE_PRISM else COLOR_YELLOW
	hit.damage = maxf(0.0, p_damage)
	hit.dir = p_dir.normalized() if p_dir.length_squared() > 0.0001 else Vector2.RIGHT
	hit.origin = p_origin
	hit.shield_wear = maxf(0.0, p_shield_wear)
	hit.stagger = p_stagger
	hit.pierce = p_pierce
	hit.attacker = p_attacker
	hit.cracks_armour = p_cracks_armour
	hit.curve_angle_deg = maxf(0.0, p_curve_angle_deg)
	return hit


func is_blue() -> bool:
	return light_color == COLOR_BLUE or source == SOURCE_PRISM


func is_bolt() -> bool:
	return source == SOURCE_BOLT or source == SOURCE_PRISM


func is_heavy() -> bool:
	return source in [SOURCE_THROW, SOURCE_RECALL, SOURCE_ZIP, SOURCE_DASH, SOURCE_BEAM, SOURCE_SUNFLARE]
