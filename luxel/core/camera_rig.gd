class_name LxCameraRig
extends Camera2D
## 320x180 pixel-snapped camera with overworld bounds, 0.4 s dungeon room slides, and subtle shake.

const VIEW_SIZE := Vector2(320.0, 180.0)
const DEFAULT_SLIDE_S: float = 0.4

var world_bounds: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
var room_lock: bool = false
var shake_scale: float = 1.0 # 0.0..1.0 from Options screen_shake 0..100

var _target_pos: Vector2 = Vector2(160.0, 90.0)
var _slide_from: Vector2 = Vector2.ZERO
var _slide_to: Vector2 = Vector2.ZERO
var _slide_t: float = 1.0
var _slide_dur: float = DEFAULT_SLIDE_S
var _shake_mag: float = 0.0
var _shake_decay: float = 4.0


func _ready() -> void:
	enabled = true
	position_smoothing_enabled = false


func set_bounds(bounds: Rect2, locked_room: bool = false) -> void:
	world_bounds = bounds
	room_lock = locked_room


func snap_to(pos: Vector2) -> void:
	_slide_t = 1.0
	_target_pos = _clamp_center(pos)
	global_position = _target_pos.round()


func slide_to_room(room_rect: Rect2, duration: float = DEFAULT_SLIDE_S) -> void:
	room_lock = true
	world_bounds = room_rect
	_slide_from = global_position
	_slide_to = _clamp_center(room_rect.get_center())
	_slide_dur = maxf(0.05, duration)
	_slide_t = 0.0


func add_shake(intensity: float) -> void:
	_shake_mag = maxf(_shake_mag, clampf(intensity, 0.0, 1.0) * 6.0 * shake_scale)


func follow(target: Vector2, dt: float) -> void:
	if _slide_t < 1.0:
		_slide_t = minf(1.0, _slide_t + dt / _slide_dur)
		var ease_t: float = 1.0 - pow(1.0 - _slide_t, 3.0)
		_target_pos = _slide_from.lerp(_slide_to, ease_t)
	elif room_lock:
		_target_pos = _clamp_center(target)
	else:
		var clamped: Vector2 = _clamp_center(target)
		_target_pos = _target_pos.lerp(clamped, minf(1.0, dt * 10.0))

	var shake_off: Vector2 = Vector2.ZERO
	if _shake_mag > 0.05:
		shake_off = Vector2(randf_range(-_shake_mag, _shake_mag), randf_range(-_shake_mag, _shake_mag))
		_shake_mag = maxf(0.0, _shake_mag - _shake_decay * dt * 6.0)
	global_position = (_target_pos + shake_off).round()


func is_on_screen(world_pos: Vector2, margin: float = 8.0) -> bool:
	var half: Vector2 = VIEW_SIZE * 0.5 + Vector2(margin, margin)
	var d: Vector2 = (world_pos - global_position).abs()
	return d.x <= half.x and d.y <= half.y


func _clamp_center(pos: Vector2) -> Vector2:
	var half: Vector2 = VIEW_SIZE * 0.5
	var min_x: float = world_bounds.position.x + half.x
	var max_x: float = world_bounds.end.x - half.x
	var min_y: float = world_bounds.position.y + half.y
	var max_y: float = world_bounds.end.y - half.y
	var cx: float = world_bounds.get_center().x if min_x >= max_x else clampf(pos.x, min_x, max_x)
	var cy: float = world_bounds.get_center().y if min_y >= max_y else clampf(pos.y, min_y, max_y)
	return Vector2(cx, cy)
