class_name LxHubTravel
extends RefCounted
## Entry/exit helpers for the Wick House hub (island_id 0, region "overworld", waystone "ws_hub").
## Calls Lx.root.fast_travel_waystone(0, "ws_hub") when available; remembers last island for return.

const HUB_ISLAND_ID: int = 0
const HUB_REGION_ID: String = "overworld"
const HUB_WAYSTONE_ID: String = "ws_hub"
const FLAG_RETURN_ISLAND: String = "hub:return_island"
const FLAG_RETURN_WAYSTONE: String = "hub:return_waystone"


static func ensure_hub_waystone_unlocked() -> void:
	if Lx.state != null and not Lx.state.lit_waystones.has(HUB_WAYSTONE_ID):
		Lx.state.lit_waystones.append(HUB_WAYSTONE_ID)


static func fast_travel_to_hub() -> bool:
	if Lx.state != null and Lx.state.island_id > 0:
		Lx.state.story_flags[FLAG_RETURN_ISLAND] = Lx.state.island_id
		Lx.state.story_flags[FLAG_RETURN_WAYSTONE] = Lx.state.last_waystone_id
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
