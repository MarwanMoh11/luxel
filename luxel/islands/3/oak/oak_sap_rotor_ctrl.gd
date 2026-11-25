class_name LxOakSapRotorCtrl
extends LxToy
## Sap-lubricated Growth-Ring Rotor controller (`oak_r6b`, Bible §3.4).
## When `oak_sap == "low"`, hitting/interacting plays a dry timber groan (`denied`).
## When `oak_sap == "high"`, rotates the Heartwood Growth-Ring (`room:3:oak_r6b.hub_rot` 0/1)
## between East (`oak_r7b`, Moving Chamber) and West (`oak_r7`, Weaver's Loom) AND turns any
## linked visual `rotor` toy!
## Props: rotor_id (String), var_name ("hub_rot"), scope ("room:3:oak_r6b"), sap_scope ("dungeon:hollow_oak").

var rotor_id: String = ""
var var_name: String = "hub_rot"
var var_scope: String = "room:3:oak_r6b"
var sap_scope: String = "dungeon:hollow_oak"
var _cd: float = 0.0
var _pulse_t: float = 0.0


func _toy_setup() -> void:
	kind = "oak_sap_rotor_ctrl"
	rotor_id = str(props.get("rotor_id", "")).strip_edges()
	var_name = str(props.get("var_name", "hub_rot")).strip_edges()
	var_scope = str(props.get("scope", "room:%d:%s" % [island_id, region_id])).strip_edges()
	sap_scope = str(props.get("sap_scope", "dungeon:hollow_oak")).strip_edges()
	radius = 12.0
	_cd = 0.0
	_pulse_t = 0.0
	if Lx.vars != null and str(Lx.vars.get_var(var_scope, var_name, "")).is_empty():
		Lx.vars.set_var(var_scope, var_name, 0)
	queue_redraw()


func is_lubricated() -> bool:
	return str(LxToyDraw.world_get_var(sap_scope, "oak_sap", "low")).strip_edges().to_lower() == "high"


func get_hub_rot() -> int:
	if Lx.vars == null:
		return 0
	return posmod(int(Lx.vars.get_var(var_scope, var_name, 0)), 2)


func trigger_turn() -> bool:
	if not active or _cd > 0.0:
		return false
	_cd = 0.30
	if not is_lubricated():
		_emit_sfx("denied")
		if Lx.events != null and LxStrings.has_id("ISL3_OAK_DRY_ROTOR"):
			Lx.events.narration_requested.emit("ISL3_OAK_DRY_ROTOR", "narration", 2.8)
		queue_redraw()
		return false
	var nxt: int = (get_hub_rot() + 1) % 2
	LxToyDraw.world_set_var(var_scope, var_name, nxt)
	_pulse_t = 0.40
	if not rotor_id.is_empty() and region != null and region.has_method("find_interactable"):
		var rt: Variant = region.call("find_interactable", rotor_id)
		if rt is Object and (rt as Object).has_method("trigger_quarter_turn"):
			(rt as Object).call("trigger_quarter_turn", 1)
	if region != null and is_instance_valid(region) and region.has_method("apply_layers"):
		region.call("apply_layers")
	set_powered(nxt == 1)
	emit_power(true)
	_emit_sfx("wood_shift")
	queue_redraw()
	return true


func interact(_actor: Node = null) -> bool:
	return trigger_turn()


func on_hit(hit: LxHit) -> bool:
	if hit == null or not active:
		return false
	if hit.source in [LxHit.SOURCE_BOLT, LxHit.SOURCE_PRISM, LxHit.SOURCE_BEAM, LxHit.SOURCE_THROW]:
		return trigger_turn()
	return false


func tick(dt: float) -> void:
	super.tick(dt)
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - dt)
	if _pulse_t > 0.0:
		_pulse_t = maxf(0.0, _pulse_t - dt)
		queue_redraw()


func get_interact_prompt() -> String:
	return "ISL3_PROMPT_TURN_ROTOR" if active else ""


func is_solid() -> bool:
	return active


func get_solid_rect() -> Rect2:
	return Rect2(pos - Vector2(6.0, 5.0), Vector2(12.0, 10.0)) if active else Rect2()


func get_light_pool() -> Vector4:
	if not active or not is_lubricated():
		return Vector4.ZERO
	return Vector4(pos.x, pos.y - 2.0, 38.0 if _pulse_t > 0.0 else 28.0, 0.60 if _pulse_t > 0.0 else 0.40)


func _draw() -> void:
	var c_void: Color = PAL["void"] as Color
	var c_night: Color = PAL["night"] as Color
	var c_dusk: Color = PAL["dusk"] as Color
	var c_jade: Color = PAL["jade"] as Color
	var c_apricot: Color = PAL["apricot"] as Color
	var c_gold: Color = PAL["gold"] as Color
	var c_cream: Color = PAL["cream"] as Color
	var lub: bool = is_lubricated()
	var rot: int = get_hub_rot()

	LxToyDraw.draw_contact_shadow(self, Vector2(1.0, 5.0), 7.0, 2.5)
	LxToyDraw.draw_bevel_box(self, Rect2(-6.0, -7.0, 12.0, 13.0), c_night, c_dusk, c_gold if lub else c_dusk, c_void)
	# Amber crystal prism diamond inside brass cradle
	var col: Color = c_gold if (lub and rot == 1) else (c_apricot if lub else c_dusk)
	LxToyDraw.draw_shape_glyph(self, Vector2(0.0, -1.0), 1, lub, col, c_cream if _pulse_t > 0.0 else c_jade)
	_draw_signal_pulses()
