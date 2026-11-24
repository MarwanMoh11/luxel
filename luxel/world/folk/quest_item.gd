class_name LxQuestItem
extends LxInteractable
## Collectible quest item (kind "quest_item"): instant pickup or carry-back relic.

var item_id: String = ""
var icon_id: String = "key"
var carry_mode: bool = false
var collected: bool = false


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "quest_item"
	radius = 14.0
	item_id = str(props.get("id", id))
	icon_id = str(props.get("icon", "key"))
	carry_mode = bool(props.get("carry", false))
	collected = LxQuests.current().has_quest_item(item_id)
	active = not collected
	visible = not collected
	queue_redraw()


func get_interact_prompt() -> String:
	return "" if collected else "PROMPT_PICKUP"


func interact(_actor: Node = null) -> bool:
	if collected or not active:
		return false
	collected = true
	active = false
	visible = false
	LxQuests.current().grant_quest_item(item_id, carry_mode)
	_emit_sfx("key_pickup")
	_emit_save("qitem_" + item_id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if not collected and active:
		queue_redraw()


func get_light_pool() -> Vector4:
	if collected or not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 6.0, 28.0, 0.58)


func save_state() -> Dictionary:
	return {"active": active, "collected": collected}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	collected = bool(d.get("collected", collected)) or LxQuests.current().has_quest_item(item_id)
	active = not collected
	visible = not collected
	queue_redraw()


func _draw() -> void:
	if collected or not active:
		return
	_draw_ground_shadow(5.0, 2.0, Vector2(0.0, 1.0))
	var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.4) * 1.2)
	var cy: float = -10.0 + bob
	draw_rect(Rect2(-6.0, cy - 6.0, 12.0, 12.0), LxPalette.PAL["void"])
	draw_rect(Rect2(-5.0, cy - 5.0, 10.0, 10.0), LxPalette.PAL["night"])
	LxBubble.draw_icon(self, icon_id, Vector2(-4.0, cy - 4.0), 1.0)
