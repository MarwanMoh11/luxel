class_name LxHubTravel
extends RefCounted
## Entry/exit helpers for the Wick House hub (island_id 0, region "overworld", waystone "ws_hub").
## Calls Lx.root.fast_travel_waystone(0, "ws_hub") when available; remembers last island for return.

const HUB_ISLAND_ID: int = 0
const HUB_REGION_ID: String = "overworld"
const HUB_WAYSTONE_ID: String = "ws_hub"
const FLAG_RETURN_ISLAND: String = "hub:return_island"
const FLAG_RETURN_WAYSTONE: String = "hub:return_waystone"


static func is_hub_unlocked() -> bool:
	if Lx.state == null:
		return false
	if not Lx.state.relit_islands.is_empty():
		return true
	return Lx.state.lit_waystones.has(HUB_WAYSTONE_ID) or bool(Lx.state.story_flags.get("hub:visited", false))


static func ensure_hub_waystone_unlocked() -> void:
	if Lx.state != null and not Lx.state.lit_waystones.has(HUB_WAYSTONE_ID):
		Lx.state.lit_waystones.append(HUB_WAYSTONE_ID)


static func fast_travel_to_hub() -> bool:
	if Lx.state != null and Lx.state.island_id > 0:
		var cur_isl: int = Lx.state.island_id
		var ret_ws: String = Lx.state.last_waystone_id
		if ret_ws.is_empty() or LxMapFormat.find_waystone(cur_isl, ret_ws).is_empty():
			var loc: Dictionary = LxRunPersistence.resolve_overworld_respawn(Lx.state)
			ret_ws = str(loc.get("waystone_id", Lx.state.last_waystone_id))
			if ret_ws.is_empty() or LxMapFormat.find_waystone(cur_isl, ret_ws).is_empty():
				for i: int in range(Lx.state.lit_waystones.size() - 1, -1, -1):
					var cand: String = Lx.state.lit_waystones[i]
					if not LxMapFormat.find_waystone(cur_isl, cand).is_empty():
						ret_ws = cand
						break
		Lx.state.story_flags[FLAG_RETURN_ISLAND] = cur_isl
		Lx.state.story_flags[FLAG_RETURN_WAYSTONE] = ret_ws
	ensure_hub_waystone_unlocked()
	if Lx.root != null and Lx.root.has_method("fast_travel_waystone"):
		return bool(Lx.root.call("fast_travel_waystone", HUB_ISLAND_ID, HUB_WAYSTONE_ID))
	return false


static func return_from_hub() -> bool:
	var ret_isl: int = 1
	var ret_ws: String = "ws_plaza"
	if Lx.state != null:
		ret_isl = clampi(int(Lx.state.story_flags.get(FLAG_RETURN_ISLAND, 1)), 1, 8)
		ret_ws = str(Lx.state.story_flags.get(FLAG_RETURN_WAYSTONE, "ws_plaza"))
		if ret_ws.is_empty() or ret_ws == HUB_WAYSTONE_ID:
			ret_ws = "ws_plaza"
	if Lx.root != null and Lx.root.has_method("fast_travel_waystone"):
		if bool(Lx.root.call("fast_travel_waystone", ret_isl, ret_ws)):
			return true
	if Lx.root != null and Lx.root.has_method("load_island_region"):
		return bool(Lx.root.call("load_island_region", ret_isl, "overworld"))
	return false
