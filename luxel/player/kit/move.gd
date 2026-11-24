class_name LxMove
extends RefCounted
## Base contract for every move in Wick's kit (moves unlock from data/moves.json + save state).

var id: String = ""
var unlocked: bool = false
var locked: bool = false
var cooldown_left: float = 0.0
var wick: LxWick = null


func setup(p_wick: LxWick, p_id: String) -> void:
	wick = p_wick
	id = p_id
	cooldown_left = 0.0
	sync_unlock()


func sync_unlock() -> void:
	if Lx.state != null:
		unlocked = Lx.state.has_move(id)
	else:
		var data: Dictionary = get_data()
		unlocked = bool(data.get("start_unlocked", false))


func is_locked() -> bool:
	return locked


func can_use() -> bool:
	return unlocked and not locked and cooldown_left <= 0.0 and wick != null


func press() -> bool:
	return false


func release() -> void:
	pass


func tick(dt: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - dt)


func reset() -> void:
	cooldown_left = 0.0


func get_data() -> Dictionary:
	return Lx.get_move_data(id)
