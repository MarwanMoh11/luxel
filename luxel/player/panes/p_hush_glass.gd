class_name LxPaneHushGlass
extends LxPane
## Long Night (Trial): Trade lantern glow radius for brisker footwork and dash cadence.


func _init() -> void:
	id = "hush_glass"
	island_id = 8
	source_kind = "trial"
	lead_cost = 2
	name_key = "PANE_HUSH_GLASS_NAME"
	desc_key = "PANE_HUSH_GLASS_DESC"
	tint_key = "plum"


func modify_stat(stat_name: String, value: float, _ctx: Dictionary = {}) -> float:
	if stat_name == "light_radius":
		return value - 26.0
	if stat_name == "move_speed":
		return value + 14.0
	if stat_name == "dash_cooldown":
		return value - 0.12
	return value
