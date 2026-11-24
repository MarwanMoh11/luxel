class_name LxIsland0
extends RefCounted
## Island 0 controller: Wick House Hub (region "wick_house", file overworld.map/overworld.json).

const ISLAND_ID: int = 0
const REGIONS: Array[String] = ["overworld"]

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	if _events == null:
		return
	_attached = true
	_events.region_entered.connect(_on_region_entered)


func detach() -> void:
	if not _attached or _events == null:
		_attached = false
		return
	if _events.region_entered.is_connected(_on_region_entered):
		_events.region_entered.disconnect(_on_region_entered)
	_attached = false


func get_region_list() -> PackedStringArray:
	return PackedStringArray(REGIONS)


func on_region_loaded(_region_id: String) -> void:
	LxHubTravel.ensure_hub_waystone_unlocked()
	if Lx.audio != null:
		var track: String = str(Lx.state.story_flags.get("hub:music_track", "hub")) if Lx.state != null else "hub"
		Lx.audio.play_cue(track if not track.is_empty() else "hub")


func _on_region_entered(island_id: int, _region_id: String) -> void:
	if island_id != ISLAND_ID:
		return
	on_region_loaded(_region_id)
	var st: LxGameState = _state if _state != null else Lx.state
	if st != null and not bool(st.story_flags.get("hub:visited", false)):
		st.story_flags["hub:visited"] = true
		if _events != null:
			_events.narration_requested.emit("HUB_WELCOME", "narration", 3.2)


static func fast_travel_hub() -> bool:
	return LxHubTravel.fast_travel_to_hub()
