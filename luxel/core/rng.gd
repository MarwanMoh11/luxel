class_name LxRng
extends RefCounted
## Deterministic seeded random generator for Luxel 1.0 simulations and tests.

var _rng := RandomNumberGenerator.new()
var seed_value: int = 101


func _init(initial_seed: int = 101) -> void:
	reseed(initial_seed)


func reseed(s: int) -> void:
	seed_value = s
	_rng.seed = s


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]
