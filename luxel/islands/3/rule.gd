class_name LxIsland3Rule
extends RefCounted
## Island 3 (Thornwood Hollow) Rule Engine:
## - Shifting Woods (`wood_turn` 0/1/2): exiting an unpinned shifting clearing rotates `wood_turn = (wood_turn + 1) % 3`
##   with a readable tell (diegetic compass + HUD pill + timber groan); lit `wood_pin_lamp` pins that clearing.
##   Stops auto-turning after `island_3_relit` so endgame exploration is effortless. Never softlocks.
## - Tiny Size Mode (`size` "normal"|"tiny"): sets `wick.set_light_scale(1.8)` in tiny rooms (`underroot_*`,
##   `ow_tiny_moss`, `oak_r4b`, `_proof_i3_2`, or `"tiny": true`) and always restores `size="normal"` + `1.0` on non-tiny regions.
## - Sap Clocks (`oak_sap` "low"|"high") & Sap-Horn call helper for `beetle_mount` toys.
## - Lightweight HUD/diegetic indicator overlay (active only on Island 3 rule contexts; never disturbs legacy checks).

const ISLAND_ID: int = 3
const SCOPE_ISLAND: String = "island:3"
const SCOPE_OAK: String = "dungeon:hollow_oak"
const SCOPE_LOOM: String = "dungeon:loom"
const TINY_LIGHT_SCALE: float = 1.8
const NORMAL_LIGHT_SCALE: float = 1.0

const SHIFT_CLEARINGS: Dictionary = {
	"ow_shift_w": "w",
	"ow_shift_e": "e",
	"ow_shift_n": "n",
	"_proof_i3_1": "w",
}

const TINY_REGIONS: Dictionary = {
	"ow_tiny_moss": true,
	"oak_r4b": true,
	"_proof_i3_2": true,
}

const TURN_KEYS: Array[String] = ["ISL3_HUD_MOSS", "ISL3_HUD_SILK", "ISL3_HUD_CROWN"]
const TURN_NOTE_KEYS: Array[String] = ["ISL3_WOOD_TURNED_0", "ISL3_WOOD_TURNED_1", "ISL3_WOOD_TURNED_2"]

static var active_instance: LxIsland3Rule = null
## The controller is rebuilt on every region load; the clearing Wick just left must survive that or the wood never turns.
static var _carry: Dictionary = {}


class Island3HudOverlay:
	extends CanvasLayer
	var rule: LxIsland3Rule = null
	var canvas: Node2D = null
	var shift_flash_t: float = 0.0

	func _ready() -> void:
		layer = 14
		canvas = Node2D.new()
		canvas.name = "Island3HudCanvas"
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		canvas.draw.connect(_on_draw)
		add_child(canvas)

	func _process(dt: float) -> void:
		if shift_flash_t > 0.0:
			shift_flash_t = maxf(0.0, shift_flash_t - dt)
			if canvas != null:
				canvas.queue_redraw()

	func refresh() -> void:
		if canvas != null:
			canvas.queue_redraw()

	func _on_draw() -> void:
		if rule == null or canvas == null:
			return
		if Lx.state == null or Lx.state.island_id != ISLAND_ID:
			return
		var fl: Variant = Lx.root.get("flow") if Lx.root != null else null
		if fl is int and int(fl) != 2:
			return
		var reg_id: String = Lx.state.region_id
		var is_tiny: bool = rule.is_tiny()
		var clearing: String = rule.clearing_for_region(reg_id)
		var show_sap: bool = reg_id.begins_with("oak_") or reg_id.begins_with("_proof_i3") or rule.get_oak_sap() == "high"
		var show_turn: bool = not clearing.is_empty() or shift_flash_t > 0.0
		if not is_tiny and not show_turn and not show_sap:
			return
		# Keep legacy oak_r1..r10 clean unless oak_sap is actively high
		if LxLegacy.is_legacy_region(ISLAND_ID, reg_id) and not is_tiny and not show_turn and rule.get_oak_sap() != "high":
			return

		var c_void: Color = LxPalette.PAL["void"] as Color
		var c_night: Color = LxPalette.PAL["night"] as Color
		var c_dusk: Color = LxPalette.PAL["dusk"] as Color
		var c_gold: Color = LxPalette.PAL["gold"] as Color
		var c_cream: Color = LxPalette.PAL["cream"] as Color
		var c_lime: Color = LxPalette.PAL["lime"] as Color
		var c_jade: Color = LxPalette.PAL["jade"] as Color
		var c_apricot: Color = LxPalette.PAL["apricot"] as Color
		var c_rose: Color = LxPalette.PAL["rose"] as Color
		var y_cur: float = 20.0

		if show_turn:
			var eff_t: int = rule.get_effective_turn(clearing) if not clearing.is_empty() else rule.get_wood_turn()
			var pinned: bool = (not clearing.is_empty()) and rule.is_clearing_pinned(clearing)
			var bx: float = 6.0
			var bw: float = 86.0
			var bh: float = 13.0
			var rim: Color = c_cream if (shift_flash_t > 0.0 and not LxHudFx.flash_reduced()) else (c_gold if pinned else c_dusk)
			canvas.draw_rect(Rect2(bx, y_cur, bw, bh), c_void)
			canvas.draw_rect(Rect2(bx + 1.0, y_cur + 1.0, bw - 2.0, bh - 2.0), c_night)
			canvas.draw_rect(Rect2(bx + 1.0, y_cur + 1.0, bw - 2.0, 1.0), rim)
			# 3-wedge compass pips: raised crowned active pip vs flat recessed inactive slots (greyscale-legible)
			for i: int in range(3):
				var px: float = bx + 4.0 + float(i) * 5.0
				var active_w: bool = i == eff_t
				var wc: Color = c_lime if i == 0 else (c_rose if i == 1 else c_gold)
				if active_w:
					canvas.draw_rect(Rect2(px, y_cur + 3.0, 3.0, 6.0), wc)
					canvas.draw_rect(Rect2(px + 1.0, y_cur + 4.0, 1.0, 4.0), c_cream)
				else:
					canvas.draw_rect(Rect2(px, y_cur + 6.0, 3.0, 2.0), c_dusk)
			var lbl_key: String = TURN_KEYS[clampi(eff_t, 0, 2)]
			var lbl: String = LxStrings.text(lbl_key) if LxStrings.has_id(lbl_key) else ""
			if not lbl.is_empty():
				LxPixelFont.draw(canvas, lbl, Vector2(bx + 22.0, y_cur + 4.0), c_cream if pinned else c_gold)
			if pinned:
				# Raised pin-corner studs on badge right edge
				canvas.draw_rect(Rect2(bx + bw - 3.0, y_cur + 2.0, 1.0, 2.0), c_cream)
				canvas.draw_rect(Rect2(bx + bw - 3.0, y_cur + bh - 4.0, 1.0, 2.0), c_cream)
				var pk: String = LxStrings.text("ISL3_HUD_PIN") if LxStrings.has_id("ISL3_HUD_PIN") else ""
				if not pk.is_empty():
					LxPixelFont.draw(canvas, pk, Vector2(bx + bw - 18.0, y_cur + 4.0), c_lime)
			elif not clearing.is_empty():
				var fk: String = LxStrings.text("ISL3_HUD_FREE") if LxStrings.has_id("ISL3_HUD_FREE") else ""
				if not fk.is_empty():
					LxPixelFont.draw(canvas, fk, Vector2(bx + bw - 20.0, y_cur + 4.0), c_apricot)
			y_cur += bh + 2.0

		if is_tiny:
			var bx2: float = 6.0
			var bw2: float = 66.0
			var bh2: float = 12.0
			canvas.draw_rect(Rect2(bx2, y_cur, bw2, bh2), c_void)
			canvas.draw_rect(Rect2(bx2 + 1.0, y_cur + 1.0, bw2 - 2.0, bh2 - 2.0), c_night)
			canvas.draw_rect(Rect2(bx2 + 1.0, y_cur + 1.0, bw2 - 2.0, 1.0), c_gold)
			# Mini sunburst icon with 4 cardinal ray ticks
			canvas.draw_rect(Rect2(bx2 + 4.0, y_cur + 4.0, 4.0, 4.0), c_apricot)
			canvas.draw_rect(Rect2(bx2 + 5.0, y_cur + 5.0, 2.0, 2.0), c_cream)
			canvas.draw_rect(Rect2(bx2 + 5.0, y_cur + 3.0, 2.0, 1.0), c_gold)
			canvas.draw_rect(Rect2(bx2 + 5.0, y_cur + 8.0, 2.0, 1.0), c_gold)
			canvas.draw_rect(Rect2(bx2 + 3.0, y_cur + 5.0, 1.0, 2.0), c_gold)
			canvas.draw_rect(Rect2(bx2 + 8.0, y_cur + 5.0, 1.0, 2.0), c_gold)
			var t_lbl: String = LxStrings.text("ISL3_HUD_TINY") if LxStrings.has_id("ISL3_HUD_TINY") else ""
			if not t_lbl.is_empty():
				LxPixelFont.draw(canvas, t_lbl, Vector2(bx2 + 12.0, y_cur + 4.0), c_cream)
			y_cur += bh2 + 2.0

		if show_sap:
			var sap_hi: bool = rule.get_oak_sap() == "high"
			var bx3: float = 6.0
			var bw3: float = 58.0
			var bh3: float = 12.0
			canvas.draw_rect(Rect2(bx3, y_cur, bw3, bh3), c_void)
			canvas.draw_rect(Rect2(bx3 + 1.0, y_cur + 1.0, bw3 - 2.0, bh3 - 2.0), c_night)
			canvas.draw_rect(Rect2(bx3 + 1.0, y_cur + 1.0, bw3 - 2.0, 1.0), c_apricot if sap_hi else c_jade)
			canvas.draw_rect(Rect2(bx3 + 4.0, y_cur + 3.0, 4.0, 6.0), c_dusk)
			if sap_hi:
				canvas.draw_rect(Rect2(bx3 + 4.0, y_cur + 3.0, 4.0, 6.0), c_gold)
				canvas.draw_rect(Rect2(bx3 + 4.0, y_cur + 3.0, 4.0, 1.0), c_cream)
			else:
				canvas.draw_rect(Rect2(bx3 + 4.0, y_cur + 7.0, 4.0, 2.0), c_jade)
			var s_key: String = "ISL3_HUD_SAP_HI" if sap_hi else "ISL3_HUD_SAP_LO"
			var s_lbl: String = LxStrings.text(s_key) if LxStrings.has_id(s_key) else ""
			if not s_lbl.is_empty():
				LxPixelFont.draw(canvas, s_lbl, Vector2(bx3 + 12.0, y_cur + 4.0), c_cream if sap_hi else c_lime)


var _events: LxEventBus = null
var _state: LxGameState = null
var _vars: LxWorldState = null
var _attached: bool = false
var _hud: Island3HudOverlay = null
var _active_region_id: String = ""
var _active_clearing: String = ""


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	_vars = Lx.vars
	_attached = true
	active_instance = self
	if _state != null and int(_carry.get("state", 0)) == int(_state.get_instance_id()):
		_active_region_id = str(_carry.get("region", ""))
		_active_clearing = str(_carry.get("clearing", ""))
	_carry = {}
	_ensure_defaults()
	if _events != null and not _events.region_entered.is_connected(_on_region_entered):
		_events.region_entered.connect(_on_region_entered)
	if _vars != null and not _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.connect(_on_var_changed)
	_attach_hud()


func detach() -> void:
	if _events != null and _events.region_entered.is_connected(_on_region_entered):
		_events.region_entered.disconnect(_on_region_entered)
	if _vars != null and _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.disconnect(_on_var_changed)
	# Always restore Wick's normal light scale when leaving Island 3
	_apply_wick_light_scale(NORMAL_LIGHT_SCALE)
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	if _attached and _state != null and _state.island_id == ISLAND_ID and not _active_region_id.is_empty():
		_carry = {"state": _state.get_instance_id(), "region": _active_region_id, "clearing": _active_clearing}
	else:
		_carry = {}
	_active_region_id = ""
	_active_clearing = ""
	_attached = false
	if active_instance == self:
		active_instance = null


func _attach_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		return
	if Lx.root == null or not is_instance_valid(Lx.root):
		return
	_hud = Island3HudOverlay.new()
	_hud.name = "Island3HudOverlay"
	_hud.rule = self
	Lx.root.add_child(_hud)


func _ensure_defaults() -> void:
	if _vars == null:
		return
	if str(_vars.get_var(SCOPE_ISLAND, "wood_turn", "")).is_empty():
		_vars.set_var(SCOPE_ISLAND, "wood_turn", 0)
	for c: String in ["w", "e", "n"]:
		if str(_vars.get_var(SCOPE_ISLAND, "pin_" + c, "")).is_empty():
			_vars.set_var(SCOPE_ISLAND, "pin_" + c, 0)
		if str(_vars.get_var(SCOPE_ISLAND, "pin_turn_" + c, "")).is_empty():
			_vars.set_var(SCOPE_ISLAND, "pin_turn_" + c, 0)
	if str(_vars.get_var(SCOPE_ISLAND, "size", "")).is_empty():
		_vars.set_var(SCOPE_ISLAND, "size", "normal")
	if str(_vars.get_var(SCOPE_LOOM, "loom_warp", "")).is_empty():
		_vars.set_var(SCOPE_LOOM, "loom_warp", "high")
	if str(_vars.get_var(SCOPE_OAK, "oak_sap", "")).is_empty():
		_vars.set_var(SCOPE_OAK, "oak_sap", "low")
	_sync_effective_turns()


func get_wood_turn() -> int:
	if _vars == null:
		return 0
	return posmod(int(_vars.get_var(SCOPE_ISLAND, "wood_turn", 0)), 3)


func is_clearing_pinned(clearing: String) -> bool:
	if _vars == null or clearing.is_empty():
		return false
	return int(_vars.get_var(SCOPE_ISLAND, "pin_" + clearing, 0)) != 0


func get_effective_turn(clearing: String) -> int:
	if _vars == null:
		return 0
	if not clearing.is_empty() and is_clearing_pinned(clearing):
		return posmod(int(_vars.get_var(SCOPE_ISLAND, "pin_turn_" + clearing, get_wood_turn())), 3)
	return get_wood_turn()


func set_clearing_pinned(clearing: String, pinned: bool) -> void:
	if _vars == null or clearing.is_empty():
		return
	var c: String = clearing.strip_edges().to_lower()
	var turn_now: int = get_wood_turn()
	_vars.set_var(SCOPE_ISLAND, "pin_" + c, 1 if pinned else 0)
	if pinned:
		_vars.set_var(SCOPE_ISLAND, "pin_turn_" + c, turn_now)
	_sync_effective_turns()
	if _hud != null:
		_hud.refresh()


func get_size() -> String:
	if _vars == null:
		return "normal"
	var s: String = str(_vars.get_var(SCOPE_ISLAND, "size", "normal")).strip_edges().to_lower()
	return "tiny" if s == "tiny" else "normal"


func is_tiny() -> bool:
	return get_size() == "tiny"


func set_size(mode: String) -> void:
	var norm: String = "tiny" if mode.strip_edges().to_lower() == "tiny" else "normal"
	if _vars != null:
		_vars.set_var(SCOPE_ISLAND, "size", norm)
	_apply_wick_light_scale(TINY_LIGHT_SCALE if norm == "tiny" else NORMAL_LIGHT_SCALE)
	if _hud != null:
		_hud.refresh()


func get_oak_sap() -> String:
	if _vars == null:
		return "low"
	var s: String = str(_vars.get_var(SCOPE_OAK, "oak_sap", "low")).strip_edges().to_lower()
	return "high" if s == "high" else "low"


func set_oak_sap(level: String) -> void:
	var norm: String = "high" if level.strip_edges().to_lower() == "high" else "low"
	if _vars != null:
		_vars.set_var(SCOPE_OAK, "oak_sap", norm)
	if _hud != null:
		_hud.refresh()


func is_tiny_region(region_id: String, region_data: Dictionary = {}) -> bool:
	if region_id.is_empty():
		return false
	if region_id.begins_with("underroot_") or TINY_REGIONS.has(region_id):
		return true
	if bool(region_data.get("tiny", false)):
		return true
	if str(region_data.get("theme", "")).strip_edges().to_lower() == "isl3_underroot":
		return true
	return false


func clearing_for_region(region_id: String, region_data: Dictionary = {}) -> String:
	var explicit: String = str(region_data.get("shift_clearing", "")).strip_edges().to_lower()
	if not explicit.is_empty():
		return explicit
	if SHIFT_CLEARINGS.has(region_id):
		return str(SHIFT_CLEARINGS[region_id])
	return ""


func _is_island_relit() -> bool:
	var st: LxGameState = _state if _state != null else Lx.state
	if st == null:
		return false
	return st.relit_islands.has(ISLAND_ID) or bool(st.story_flags.get("island_3_relit", false))


func _on_region_entered(island_id: int, region_id: String) -> void:
	if island_id != ISLAND_ID:
		set_size("normal")
		return
	var rdata: Dictionary = _current_region_data()
	# 1. Shifting Woods: leaving an unpinned shifting clearing rotates `wood_turn` +1 mod 3
	if not _active_clearing.is_empty() and region_id != _active_region_id:
		if not is_clearing_pinned(_active_clearing) and not _is_island_relit():
			advance_wood_turn(true)

	_active_region_id = region_id
	_active_clearing = clearing_for_region(region_id, rdata)
	if _active_clearing.is_empty():
		_active_clearing = _detect_clearing_from_lamps()
	_sync_effective_turns()

	# 2. Tiny Size Mode: tiny regions enforce tiny (1.8x sun-lantern); non-tiny regions ALWAYS restore normal (1.0x)
	if is_tiny_region(region_id, rdata):
		set_size("tiny")
	else:
		set_size("normal")

	# 3. Ensure region layers match the freshly updated room/island vars immediately
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("apply_layers"):
		Lx.world.call("apply_layers", false)
	if _hud != null:
		_hud.refresh()


func on_region_loaded(region_id: String) -> void:
	# Re-apply Wick light scale after main.gd's reset_for_room() runs
	var rdata: Dictionary = _current_region_data()
	var want_tiny: bool = is_tiny_region(region_id, rdata) or is_tiny()
	if not is_tiny_region(region_id, rdata):
		want_tiny = false
	_apply_wick_light_scale(TINY_LIGHT_SCALE if want_tiny else NORMAL_LIGHT_SCALE)
	if _hud != null:
		_hud.refresh()


func advance_wood_turn(with_tell: bool = true) -> int:
	var nxt: int = (get_wood_turn() + 1) % 3
	if _vars != null:
		_vars.set_var(SCOPE_ISLAND, "wood_turn", nxt)
	_sync_effective_turns()
	if with_tell:
		if _events != null:
			_events.sfx_requested.emit("wood_shift", Vector2.ZERO, false)
			_emit_shake(0.08)
			var note_key: String = TURN_NOTE_KEYS[clampi(nxt, 0, 2)]
			var st: LxGameState = _state if _state != null else Lx.state
			var taught: bool = st != null and bool(st.story_flags.get("isl3_pin_taught", false))
			if not taught and LxStrings.has_id(note_key):
				_events.narration_requested.emit(note_key, "narration", 3.0)
		if _hud != null:
			_hud.shift_flash_t = 2.4
			_hud.refresh()
	return nxt


func _sync_effective_turns() -> void:
	if _vars == null:
		return
	var base: int = get_wood_turn()
	for c: String in ["w", "e", "n"]:
		var eff: int = get_effective_turn(c)
		_vars.set_var(SCOPE_ISLAND, "eff_turn_" + c, eff)
	if not _active_region_id.is_empty():
		var room_turn: int = get_effective_turn(_active_clearing) if not _active_clearing.is_empty() else base
		_vars.set_var("room:3:" + _active_region_id, "clearing_turn", room_turn)


func _detect_clearing_from_lamps() -> String:
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_interactables"):
		return ""
	for it_v: Variant in (Lx.world.call("get_interactables") as Array):
		if it_v is LxInteractable and (it_v as LxInteractable).kind == "wood_pin_lamp":
			var c: String = str((it_v as LxInteractable).get("clearing"))
			if not c.is_empty():
				return c
	return ""


func _on_var_changed(scope: String, var_name: String, value: Variant) -> void:
	if scope == SCOPE_ISLAND and var_name == "size":
		var is_t: bool = str(value).strip_edges().to_lower() == "tiny"
		_apply_wick_light_scale(TINY_LIGHT_SCALE if is_t else NORMAL_LIGHT_SCALE)
	elif scope == SCOPE_ISLAND and (var_name == "wood_turn" or var_name.begins_with("pin_")):
		_sync_effective_turns()
	elif var_name == "oak_sap":
		if _events != null:
			_events.sfx_requested.emit("sap_clock_tick", Vector2.ZERO, false)
	if _hud != null:
		_hud.refresh()


func _apply_wick_light_scale(scale_val: float) -> void:
	if Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("set_light_scale"):
		Lx.player.call("set_light_scale", scale_val)


func _current_region_data() -> Dictionary:
	if Lx.world != null and is_instance_valid(Lx.world):
		var rd: Variant = Lx.world.get("region_data")
		if rd is Dictionary:
			return rd as Dictionary
	return {}


func _emit_shake(amp: float) -> void:
	if _events != null and LxHudFx.shake_enabled():
		_events.shake_requested.emit(amp * (0.45 if LxHudFx.flash_reduced() else 1.0))


## Sap-Horn acoustic pulse: commands/halts all `beetle_mount` toys within `call_radius`.
static func call_sap_horn(origin: Vector2, call_radius: float = 220.0, region_node: Node = null) -> int:
	var ctx: Node = region_node if region_node != null else Lx.world
	var count: int = 0
	if ctx != null and is_instance_valid(ctx) and ctx.has_method("get_interactables"):
		for it_v: Variant in (ctx.call("get_interactables") as Array):
			if it_v is LxInteractable and is_instance_valid(it_v):
				var it: LxInteractable = it_v as LxInteractable
				if it.active and it.has_method("on_sap_horn") and it.pos.distance_to(origin) <= call_radius:
					it.call("on_sap_horn", origin)
					count += 1
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		var red: bool = LxHudFx.flash_reduced()
		var ring_col: Color = Color(LxPalette.PAL["gold"] as Color, 0.70 if red else 1.0)
		(Lx.player as LxWick).spawn_ring(origin, 4.0, roundf(minf(48.0, call_radius * 0.4)), 0.30, ring_col, 1.0 if red else 2.0)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("sap_horn_call", origin, true)
	return count
