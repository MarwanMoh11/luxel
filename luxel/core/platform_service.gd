class_name LxPlatformService
extends RefCounted
## No-op platform / Steamworks integration interface for 1.0 (SWARM_SPEC 3.10).

var initialized: bool = false


func init() -> bool:
	initialized = true
	return true


func shutdown() -> void:
	initialized = false


func unlock_achievement(_achievement_id: String) -> void:
	pass


func sync_cloud_save(_slot_num: int) -> void:
	pass


func is_steam_deck() -> bool:
	return OS.get_environment("SteamDeck") == "1"
