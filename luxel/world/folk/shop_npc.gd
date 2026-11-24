class_name LxShopNpc
extends LxNpc
## Specialized Lamp-Folk NPC (kind "shop_npc"): opens Panes Workshop, Rest Shop, or Journal on E.

var shop_mode: String = "panes" # panes | upgrades | journal


func setup(spec: Dictionary) -> void:
	super.setup(spec)
	kind = "shop_npc"
	shop_mode = str(props.get("shop_mode", "panes"))


func get_interact_prompt() -> String:
	if not active:
		return ""
	match shop_mode:
		"upgrades": return "PROMPT_REST_SHRINE"
		"journal": return "PROMPT_JOURNAL"
		_: return "PROMPT_PANE_WORKSHOP"


func interact(_actor: Node = null) -> bool:
	if not active:
		return false
	_happy_t = 0.9
	_emit_sfx("ui_confirm")
	if Lx.ui != null:
		match shop_mode:
			"upgrades":
				if Lx.ui.has_method("open_rest_shop"):
					Lx.ui.call("open_rest_shop")
			"journal":
				if Lx.ui.has_method("show_journal"):
					Lx.ui.call("show_journal", LxUiRoot.Screen.HUD)
			_:
				if Lx.ui.has_method("open_panes_menu"):
					Lx.ui.call("open_panes_menu")
	queue_redraw()
	return true
