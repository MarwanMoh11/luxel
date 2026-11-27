class_name LxCameraRig
extends Camera2D
## 320x180 pixel-snapped camera locked directly to Wick with overworld bounds,
## 0.4 s dungeon room slides, and subtle combat impact shake/kick.

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
var _shake_trauma: float = 0.0
var _shake_clock: float = 0.0
var _shake_seed: float = 0.0
var _kick_offset: Vector2 = Vector2.ZERO
var _kick_vel: Vector2 = Vector2.ZERO


func _ready() -> void:
	enabled = true
	position_smoothing_enabled = false
	var listener := AudioListener2D.new()
	listener.name = "AudioListener"
	add_child(listener)
	listener.make_current()


func set_bounds(bounds: Rect2, locked_room: bool = false) -> void:
	world_bounds = bounds
	room_lock = locked_room


func snap_to(pos: Vector2) -> void:
	_slide_t = 1.0
	_kick_offset = Vector2.ZERO
	_kick_vel = Vector2.ZERO
	_shake_trauma = 0.0
	_shake_clock = 0.0
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
	if _shake_trauma <= 0.02 and intensity > 0.02:
		_shake_seed = fmod(_shake_seed + 1.6180339, TAU)
	_shake_trauma = clampf(maxf(_shake_trauma, intensity), 0.0, 1.0)


func add_kick(dir: Vector2, px: float = 3.0) -> void:
	if shake_scale <= 0.01 or dir.length_squared() <= 0.0001:
		return
	var fr_k: float = 0.55 if (Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))) else 1.0
	var target_kick: Vector2 = dir.normalized() * clampf(px, 0.5, 5.0) * shake_scale * fr_k
	if target_kick.length_squared() >= _kick_offset.length_squared():
		_kick_offset = target_kick
		_kick_vel = target_kick * 5.0
	else:
		_kick_vel += target_kick * 3.5


func trigger_focus_nudge(_world_pos: Vector2, _duration: float = 0.55) -> void:
	# Camera sticks strictly to Wick; focus nudges are intentionally disabled.
	pass


func follow(target: Vector2, dt: float) -> void:
	if _slide_t < 1.0:
		_slide_t = minf(1.0, _slide_t + dt / _slide_dur)
		var ease_t: float = 1.0 - pow(1.0 - _slide_t, 3.0)
		_target_pos = _slide_from.lerp(_slide_to, ease_t)
	else:
		_target_pos = _clamp_center(target)

	var shake_off: Vector2 = Vector2.ZERO
	if _shake_trauma > 0.02:
		_shake_clock += dt
		var fr_sh: float = 0.45 if (Lx.save != null and bool(Lx.save.settings.get("flash_reduction", false))) else 1.0
		var mag: float = _shake_trauma * _shake_trauma * 6.5 * shake_scale * fr_sh
		var t30: float = floorf(_shake_clock * 30.0) / 30.0
		var sx: float = sin(t30 * 53.0 + _shake_seed) * 0.65 + sin(t30 * 89.0 + _shake_seed * 2.1) * 0.35
		var sy: float = cos(t30 * 47.0 + _shake_seed * 1.3) * 0.65 + sin(t30 * 79.0 - _shake_seed * 1.7) * 0.35
		shake_off = Vector2(sx * mag, sy * mag)
		_shake_trauma = maxf(0.0, _shake_trauma - dt * 2.6)
	else:
		_shake_trauma = 0.0
		_shake_clock = 0.0
	if _kick_offset.length_squared() > 0.0025 or _kick_vel.length_squared() > 0.25:
		var sdt: float = minf(dt, 0.033)
		var acc: Vector2 = -_kick_offset * 340.0 - _kick_vel * 26.0
		_kick_vel += acc * sdt
		_kick_offset = (_kick_offset + _kick_vel * sdt).limit_length(6.0)
	else:
		_kick_offset = Vector2.ZERO
		_kick_vel = Vector2.ZERO
	global_position = (_target_pos + shake_off + _kick_offset).round()


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
