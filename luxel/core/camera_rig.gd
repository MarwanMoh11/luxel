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
var _shake_trauma: float = 0.0
var _shake_clock: float = 0.0
var _shake_seed: float = 0.0
var _look_ahead: Vector2 = Vector2.ZERO
var _kick_offset: Vector2 = Vector2.ZERO
var _kick_vel: Vector2 = Vector2.ZERO
var _focus_pos: Vector2 = Vector2.ZERO
var _focus_t: float = 0.0
var _focus_dur: float = 0.55


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
	_look_ahead = Vector2.ZERO
	_kick_offset = Vector2.ZERO
	_kick_vel = Vector2.ZERO
	_focus_t = 0.0
	_shake_trauma = 0.0
	_shake_clock = 0.0
	_target_pos = _clamp_center(pos)
	global_position = _target_pos.round()


func slide_to_room(room_rect: Rect2, duration: float = DEFAULT_SLIDE_S) -> void:
	room_lock = true
	world_bounds = room_rect
	_look_ahead = Vector2.ZERO
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


func trigger_focus_nudge(world_pos: Vector2, duration: float = 0.55) -> void:
	_focus_pos = world_pos
	_focus_dur = maxf(0.15, duration)
	_focus_t = _focus_dur


func follow(target: Vector2, dt: float) -> void:
	if _slide_t < 1.0:
		_slide_t = minf(1.0, _slide_t + dt / _slide_dur)
		var ease_t: float = 1.0 - pow(1.0 - _slide_t, 3.0)
		_target_pos = _slide_from.lerp(_slide_to, ease_t)
	elif room_lock and world_bounds.size.x <= VIEW_SIZE.x + 2.0 and world_bounds.size.y <= VIEW_SIZE.y + 2.0:
		_look_ahead = Vector2.ZERO
		_target_pos = _clamp_center(target)
	else:
		var desired_lead: Vector2 = Vector2.ZERO
		var lead_rate: float = 3.8
		var follow_rate: float = 10.0
		if Lx.player != null and is_instance_valid(Lx.player):
			var is_zip: bool = Lx.player.has_method("is_zipping") and bool(Lx.player.call("is_zipping"))
			var lan_v: Variant = Lx.player.get("lantern")
			var framed: bool = false
			if lan_v is Object and is_instance_valid(lan_v):
				var lan_o: Object = lan_v as Object
				var is_lure: bool = lan_o.has_method("is_lure_active") and bool(lan_o.call("is_lure_active"))
				var is_stolen: bool = int(lan_o.get("state")) == 4
				if is_zip or is_lure or is_stolen:
					var lpos_v: Variant = lan_o.get("pos")
					if lpos_v is Vector2:
						var to_lan: Vector2 = (lpos_v as Vector2) - target
						if is_zip:
							desired_lead = (to_lan * 0.44).limit_length(36.0)
							lead_rate = 11.0
							follow_rate = 19.0
						else:
							desired_lead = (to_lan * (0.30 if is_stolen else 0.32)).limit_length(26.0 if is_stolen else 28.0)
						framed = true
			if not framed:
				var boss_lead: Vector2 = _find_active_boss_lead(target)
				if boss_lead.length_squared() > 0.01:
					desired_lead = boss_lead
					framed = true
			if not framed:
				var is_glide: bool = Lx.player.has_method("is_gliding") and bool(Lx.player.call("is_gliding"))
				var is_dash: bool = Lx.player.has_method("is_dashing") and bool(Lx.player.call("is_dashing"))
				if is_glide or is_dash:
					var trav_dir: Vector2 = Vector2.ZERO
					var md_v: Variant = Lx.player.get("move_dash")
					if md_v is Object and is_instance_valid(md_v) and (md_v as Object).has_method("get_active_velocity"):
						var avel_v: Variant = (md_v as Object).call("get_active_velocity")
						if avel_v is Vector2 and (avel_v as Vector2).length_squared() > 0.01:
							trav_dir = (avel_v as Vector2).normalized()
					if trav_dir.length_squared() <= 0.01:
						var vel_v: Variant = Lx.player.get("velocity")
						if vel_v is Vector2 and (vel_v as Vector2).length_squared() > 1.0:
							trav_dir = (vel_v as Vector2).normalized()
					if trav_dir.length_squared() <= 0.01:
						var fv_t: Variant = Lx.player.get("facing")
						if fv_t is Vector2 and (fv_t as Vector2).length_squared() > 0.01:
							trav_dir = (fv_t as Vector2).normalized()
					if trav_dir.length_squared() > 0.01:
						desired_lead = trav_dir * 22.0
						lead_rate = 5.2
				else:
					var fv: Variant = Lx.player.get("facing")
					if fv is Vector2 and (fv as Vector2).length_squared() > 0.01:
						var bm: Variant = Lx.player.get("move_beam")
						var charging_beam: bool = bm is Object and is_instance_valid(bm) and bool((bm as Object).get("charging"))
						desired_lead = (fv as Vector2).normalized() * (24.0 if charging_beam else 14.0)
		_look_ahead = _look_ahead.lerp(desired_lead, minf(1.0, dt * lead_rate))
		var clamped: Vector2 = _clamp_center(target + _look_ahead)
		_target_pos = _target_pos.lerp(clamped, minf(1.0, dt * follow_rate))

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
	var focus_off: Vector2 = Vector2.ZERO
	if _focus_t > 0.0:
		_focus_t = maxf(0.0, _focus_t - dt)
		var f_env: float = sin(clampf(_focus_t / _focus_dur, 0.0, 1.0) * PI)
		focus_off = (_focus_pos - target).limit_length(34.0) * f_env * 0.55
		if room_lock and world_bounds.size.x <= VIEW_SIZE.x + 2.0 and world_bounds.size.y <= VIEW_SIZE.y + 2.0:
			focus_off = focus_off.limit_length(6.0)
	global_position = (_target_pos + shake_off + _kick_offset + focus_off).round()


func is_on_screen(world_pos: Vector2, margin: float = 8.0) -> bool:
	var half: Vector2 = VIEW_SIZE * 0.5 + Vector2(margin, margin)
	var d: Vector2 = (world_pos - global_position).abs()
	return d.x <= half.x and d.y <= half.y


func _find_active_boss_lead(target: Vector2) -> Vector2:
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_enemies"):
		return Vector2.ZERO
	var enemies: Variant = Lx.world.call("get_enemies")
	if not (enemies is Array):
		return Vector2.ZERO
	for e: Variant in (enemies as Array):
		if e is Node2D and is_instance_valid(e):
			var obj: Object = e as Object
			if not bool(obj.get("is_boss")):
				continue
			if obj.has_method("is_alive") and not bool(obj.call("is_alive")):
				continue
			var bpos: Vector2 = (e as Node2D).global_position
			var delta: Vector2 = bpos - target
			if delta.length_squared() <= 36100.0:
				return (delta * 0.24).limit_length(22.0)
	return Vector2.ZERO


func _clamp_center(pos: Vector2) -> Vector2:
	var half: Vector2 = VIEW_SIZE * 0.5
	var min_x: float = world_bounds.position.x + half.x
	var max_x: float = world_bounds.end.x - half.x
	var min_y: float = world_bounds.position.y + half.y
	var max_y: float = world_bounds.end.y - half.y
	var cx: float = world_bounds.get_center().x if min_x >= max_x else clampf(pos.x, min_x, max_x)
	var cy: float = world_bounds.get_center().y if min_y >= max_y else clampf(pos.y, min_y, max_y)
	return Vector2(cx, cy)
