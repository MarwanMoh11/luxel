extends CharacterBody2D
## Placeholder walker for trying the map: arrows or WASD, the survivor core's speed and acceleration,
## a 4 px circle at the feet that collides with the walk layer.

const SPEED := 85.0
const ACCEL := 1000.0
const NIGHT := Color("211a3b")
const CREAM := Color("fff4dc")

var use_keys := true ## false lets a test drive it through input_dir
var input_dir := Vector2.ZERO


func _physics_process(delta: float) -> void:
	if use_keys:
		input_dir = Vector2(
			_key(KEY_RIGHT, KEY_D) - _key(KEY_LEFT, KEY_A),
			_key(KEY_DOWN, KEY_S) - _key(KEY_UP, KEY_W))
	velocity = velocity.move_toward(input_dir.normalized() * SPEED, ACCEL * delta)
	move_and_slide()


func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_key_pressed(a) or Input.is_key_pressed(b) else 0.0


func _draw() -> void:
	draw_rect(Rect2(-4, -9, 9, 10), NIGHT)
	draw_rect(Rect2(-3, -8, 7, 8), CREAM)
