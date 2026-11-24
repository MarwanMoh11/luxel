class_name LxPanePickup
extends LxInteractable
## World collectible granting one of the 32 stained-glass lantern panes.

const SHEET_PATH: String = "res://luxel/art/ui/panes.json"

var pane_id: String = "bell_clapper"
var collected: bool = false
var _collect_t: float = 0.0


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "pane_pickup"
	radius = 14.0
	pane_id = str(props.get("pane", props.get("pane_id", "bell_clapper")))
	collected = LxPanes.current().has_pane(pane_id)
	active = not collected
	visible = not collected
	queue_redraw()


func get_interact_prompt() -> String:
	return "" if collected else "PROMPT_TAKE_PANE"


func interact(_actor: Node = null) -> bool:
	if collected or not active:
		return false
	collected = true
	active = false
	_collect_t = 0.55
	LxPanes.current().grant_pane(pane_id)
	_emit_sfx("shrine_unlock")
	_emit_gust(54.0, 48.0, Vector2(0.0, -8.0))
	var p: LxPane = LxPanes.current().get_pane(pane_id)
	if Lx.events != null:
		Lx.events.narration_requested.emit(p.name_key if p != null else "PANE_FOUND", "title", 2.8)
		Lx.events.save_requested.emit("pane_" + pane_id)
	_notify_linked_targets(true)
	queue_redraw()
	return true


func tick(dt: float) -> void:
	super.tick(dt)
	if _collect_t > 0.0:
		_collect_t = maxf(0.0, _collect_t - dt)
		visible = _collect_t > 0.0
		queue_redraw()
		return
	if not collected and active:
		queue_redraw()


func get_light_pool() -> Vector4:
	if collected or not active:
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 8.0, 40.0, 0.78)


func save_state() -> Dictionary:
	return {"active": active, "collected": collected}


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	collected = bool(d.get("collected", collected)) or LxPanes.current().has_pane(pane_id)
	active = not collected
	visible = not collected
	queue_redraw()


func _draw() -> void:
	if _collect_t > 0.0:
		var u: float = 1.0 - clampf(_collect_t / 0.55, 0.0, 1.0)
		draw_arc(Vector2(0.0, -8.0), roundf(4.0 + u * 22.0), 0.0, TAU, 16, LxPalette.PAL["gold"] if u < 0.5 else LxPalette.PAL["cream"], 1.2)
		return
	if collected or not active:
		return
	_draw_ground_shadow(6.0, 2.5, Vector2(0.0, 1.0))
	var bob: float = 0.0 if LxHudFx.flash_reduced() else roundf(sin(_clock * 3.2) * 1.5)
	var cy: float = -10.0 + bob
	var p: LxPane = LxPanes.current().get_pane(pane_id)
	var tint: Color = LxPalette.color(p.tint_key if p != null else "gold")
	draw_rect(Rect2(-7.0, cy - 7.0, 14.0, 14.0), LxPalette.PAL["void"])
	var sheet: LxSpriteSheet = LxSpriteSheet.load_sheet(SHEET_PATH)
	if sheet == null or not sheet.draw_prop(self, Vector2(0.0, cy), pane_id, _clock):
		draw_rect(Rect2(-5.0, cy - 5.0, 10.0, 10.0), tint)
		draw_rect(Rect2(-2.0, cy - 2.0, 4.0, 4.0), LxPalette.PAL["cream"])
	var ang: float = 0.0 if LxHudFx.flash_reduced() else _clock * 2.2
	for i: int in range(4):
		var a: float = ang + float(i) * (PI * 0.5)
		var sp := Vector2(roundf(cos(a) * 9.0), roundf(cy + sin(a) * 5.0))
		draw_rect(Rect2(sp, Vector2.ONE), LxPalette.PAL["cream"] if i % 2 == 0 else tint)
