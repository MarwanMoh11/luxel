class_name LxIsland8Rule
extends RefCounted
## Island 8 (The Long Night — THE ISLAND THAT TAKES) Rule Engine.
## Wires together:
## - LxSold ("THE LANTERN ASKS" sold-settings engine & Toll Powers on Wick)
## - LxSoldFx (layer 7 post-FX: palette_4, 24/30 fps hold, world_anims freeze, tell rims, pixels)
## - LxTollMenu (layer 15 ledger UI: shop, gate, redemption, boon_toll, invoice, finale)
## - LxArchiveRemix (guarded Islands 1-7 remix helpers, Brass Receipt, Bookmark Sigil)
## - LxStairDirector (Endless Stair seeded pool, 18 boons, lifts, Iron Ascent score)
## Leaves legacy Island 8 regions (overworld, sanctum_r1..r6) completely untouched unless
## Island 8 Toll/Stair features are actively engaged.

const ISLAND_ID: int = 8
const PAL: Dictionary = LxPalette.PAL
const POST_DASH_WINDOW_S: float = 0.85

static var active_instance: LxIsland8Rule = null

var _events: LxEventBus = null
var _state: LxGameState = null
var _attached: bool = false

var sold: LxSold = null
var sold_fx: LxSoldFx = null
var toll_menu: LxTollMenu = null
var archive: LxArchiveRemix = null
var stair: LxStairDirector = null

var _tick_driver: Node = null
var _hud_layer: CanvasLayer = null
var _hud_node: Node2D = null
var _bound_wick: LxWick = null
var _current_region: String = ""
var _post_dash_t: float = 0.0
var _was_dashing: bool = false
var _was_sunflare_cd: float = 0.0


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	_attached = true
	active_instance = self

	sold = LxSold.current()
	sold.sync_from_state()
	archive = LxArchiveRemix.new()
	stair = LxStairDirector.new()

	_bind_events()
	_mount_nodes()
	_bind_wick()


func detach() -> void:
	if active_instance == self:
		active_instance = null
	_unbind_events()
	_unbind_wick()
	if archive != null:
		archive.deactivate()
		archive = null
	if stair != null:
		stair.clear_run_state()
		stair = null
	_unmount_nodes()
	_attached = false


func on_region_loaded(region_id: String) -> void:
	_current_region = region_id
	_mount_nodes()
	_bind_wick()
	if sold != null:
		sold.sync_from_state()
	if sold_fx != null and is_instance_valid(sold_fx):
		sold_fx.on_region_loaded()
	if archive != null:
		var rdata: Dictionary = {}
		if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.get("region_data") is Dictionary:
			rdata = Lx.world.get("region_data") as Dictionary
		archive.activate_for_region(region_id, rdata)
	if stair != null:
		stair.on_region_changed(ISLAND_ID, region_id)
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.queue_redraw()


func open_toll_menu(opts: Dictionary = {}) -> LxTollMenu:
	_mount_nodes()
	if toll_menu != null and is_instance_valid(toll_menu):
		toll_menu.open(opts)
	return toll_menu


func close_toll_menu() -> void:
	if toll_menu != null and is_instance_valid(toll_menu):
		toll_menu.close()


func trigger_sunflare_60fps_surge() -> void:
	if sold_fx != null and is_instance_valid(sold_fx):
		sold_fx.trigger_sunflare_surge()


func get_active_power_summary() -> Dictionary:
	if sold == null:
		return {}
	return {
		"toll_weight": sold.get_toll_weight(),
		"sold_count": sold.get_sold_count(),
		"post_dash_ready": _post_dash_t > 0.0 and sold.has_power("fps_step"),
		"wick_silent": sold.is_wick_silent(),
		"stair_floor": stair.get_floor() if stair != null else 0,
		"stair_boons": stair.get_boons() if stair != null else PackedStringArray(),
	}


func _bind_events() -> void:
	if _events != null:
		if not _events.region_entered.is_connected(_on_region_entered):
			_events.region_entered.connect(_on_region_entered)
		if not _events.great_lamp_relit.is_connected(_on_great_lamp_relit):
			_events.great_lamp_relit.connect(_on_great_lamp_relit)
		if not _events.lantern_thrown.is_connected(_on_lantern_thrown):
			_events.lantern_thrown.connect(_on_lantern_thrown)
		if not _events.lantern_hung.is_connected(_on_lantern_hung):
			_events.lantern_hung.connect(_on_lantern_hung)
		if not _events.enemy_hit.is_connected(_on_enemy_hit):
			_events.enemy_hit.connect(_on_enemy_hit)
		if not _events.player_damaged.is_connected(_on_player_damaged):
			_events.player_damaged.connect(_on_player_damaged)
	if sold != null:
		if not sold.invoice_requested.is_connected(_on_invoice_requested):
			sold.invoice_requested.connect(_on_invoice_requested)
		if not sold.state_changed.is_connected(_on_sold_state_changed):
			sold.state_changed.connect(_on_sold_state_changed)


func _unbind_events() -> void:
	if _events != null:
		if _events.region_entered.is_connected(_on_region_entered):
			_events.region_entered.disconnect(_on_region_entered)
		if _events.great_lamp_relit.is_connected(_on_great_lamp_relit):
			_events.great_lamp_relit.disconnect(_on_great_lamp_relit)
		if _events.lantern_thrown.is_connected(_on_lantern_thrown):
			_events.lantern_thrown.disconnect(_on_lantern_thrown)
		if _events.lantern_hung.is_connected(_on_lantern_hung):
			_events.lantern_hung.disconnect(_on_lantern_hung)
		if _events.enemy_hit.is_connected(_on_enemy_hit):
			_events.enemy_hit.disconnect(_on_enemy_hit)
		if _events.player_damaged.is_connected(_on_player_damaged):
			_events.player_damaged.disconnect(_on_player_damaged)
	if sold != null:
		if sold.invoice_requested.is_connected(_on_invoice_requested):
			sold.invoice_requested.disconnect(_on_invoice_requested)
		if sold.state_changed.is_connected(_on_sold_state_changed):
			sold.state_changed.disconnect(_on_sold_state_changed)


func _bind_wick() -> void:
	if not (Lx.player is LxWick) or not is_instance_valid(Lx.player):
		return
	var w: LxWick = Lx.player as LxWick
	if _bound_wick == w:
		return
	_unbind_wick()
	_bound_wick = w
	if not _bound_wick.fired.is_connected(_on_wick_fired):
		_bound_wick.fired.connect(_on_wick_fired)


func _unbind_wick() -> void:
	if _bound_wick != null and is_instance_valid(_bound_wick):
		if _bound_wick.fired.is_connected(_on_wick_fired):
			_bound_wick.fired.disconnect(_on_wick_fired)
	_bound_wick = null


func _mount_nodes() -> void:
	var host: Node = _resolve_host_node()
	if host == null:
		return
	if sold_fx == null or not is_instance_valid(sold_fx) or sold_fx.is_queued_for_deletion():
		if LxSoldFx.active_instance != null and is_instance_valid(LxSoldFx.active_instance) and not LxSoldFx.active_instance.is_queued_for_deletion():
			sold_fx = LxSoldFx.active_instance
		else:
			sold_fx = LxSoldFx.new()
			sold_fx.name = "LxSoldFx"
			host.add_child(sold_fx)
	if toll_menu == null or not is_instance_valid(toll_menu) or toll_menu.is_queued_for_deletion():
		if LxTollMenu.active_instance != null and is_instance_valid(LxTollMenu.active_instance) and not LxTollMenu.active_instance.is_queued_for_deletion():
			toll_menu = LxTollMenu.active_instance
		else:
			toll_menu = LxTollMenu.new()
			toll_menu.name = "LxTollMenu"
			host.add_child(toll_menu)
	if _tick_driver == null or not is_instance_valid(_tick_driver):
		_tick_driver = _RuleTickDriver.new()
		_tick_driver.name = "Island8RuleTick"
		(_tick_driver as _RuleTickDriver).owner_rule = self
		host.add_child(_tick_driver)
	if _hud_layer == null or not is_instance_valid(_hud_layer):
		_hud_layer = CanvasLayer.new()
		_hud_layer.name = "Island8HudOverlay"
		_hud_layer.layer = 11
		_hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		host.add_child(_hud_layer)
		_hud_node = Node2D.new()
		_hud_node.name = "Island8Badge"
		_hud_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hud_node.draw.connect(_draw_hud_badge)
		_hud_layer.add_child(_hud_node)


func _unmount_nodes() -> void:
	if _tick_driver != null and is_instance_valid(_tick_driver):
		_tick_driver.queue_free()
	_tick_driver = null
	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	_hud_layer = null
	_hud_node = null
	if toll_menu != null and is_instance_valid(toll_menu):
		toll_menu.close()
		if LxTollMenu.active_instance == toll_menu:
			LxTollMenu.active_instance = null
		toll_menu.queue_free()
	toll_menu = null
	if sold_fx != null and is_instance_valid(sold_fx):
		if LxSoldFx.active_instance == sold_fx:
			LxSoldFx.active_instance = null
		sold_fx.queue_free()
	sold_fx = null


func _resolve_host_node() -> Node:
	if Lx.root != null and is_instance_valid(Lx.root):
		return Lx.root
	if Lx.world != null and is_instance_valid(Lx.world):
		return Lx.world.get_parent() if Lx.world.get_parent() != null else Lx.world
	return null


func _tick(dt: float) -> void:
	if _post_dash_t > 0.0:
		_post_dash_t = maxf(0.0, _post_dash_t - dt)
	if archive != null:
		archive.tick(dt)
	_tick_wick_powers(dt)
	if _hud_layer != null and is_instance_valid(_hud_layer):
		var show_badge: bool = _should_show_badge()
		_hud_layer.visible = show_badge
		if _hud_node != null and is_instance_valid(_hud_node):
			_hud_node.visible = show_badge
			if show_badge:
				_hud_node.queue_redraw()


func _tick_wick_powers(dt: float) -> void:
	_bind_wick()
	if _bound_wick == null or not is_instance_valid(_bound_wick) or sold == null:
		return
	var w: LxWick = _bound_wick
	# Track dash transitions for Frame Skip (1.6x bolt after dash)
	var dashing: bool = w.has_method("is_dashing") and bool(w.call("is_dashing"))
	if dashing and not _was_dashing:
		_post_dash_t = POST_DASH_WINDOW_S
	_was_dashing = dashing
	# Track Sunflare trigger for 2.5s 60fps surge under fps_step
	if w.move_sunflare != null:
		var cd_v: Variant = w.move_sunflare.get("cooldown_t")
		if cd_v is float or cd_v is int:
			var cd: float = float(cd_v)
			if cd > _was_sunflare_cd + 0.5:
				trigger_sunflare_60fps_surge()
			_was_sunflare_cd = cd
	# Apply Silent Wick notice radius multiplier to live enemies
	if sold.has_power("sound_off") and Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("get_enemies"):
		var enemies_v: Variant = Lx.world.call("get_enemies")
		if enemies_v is Array:
			for ev: Variant in (enemies_v as Array):
				if ev is Object and is_instance_valid(ev):
					var eo: Object = ev as Object
					if not bool(eo.get_meta("_lx_silent_applied", false)) and eo.get("notice_radius") != null:
						var base_r: float = float(eo.get("notice_radius"))
						eo.set_meta("_lx_base_notice", base_r)
						eo.set_meta("_lx_silent_applied", true)
						eo.set("notice_radius", base_r * 0.70)
	# Apply Wayfinder (+12% move speed) / Stair Quick Step subtle velocity assist when moving
	if w.velocity.length_squared() > 1.0:
		var mult: float = sold.modify_stat("move_speed", 1.0)
		if stair != null:
			mult = stair.modify_stair_stat("move_speed", mult)
		if mult > 1.001:
			w.global_position += w.velocity * (mult - 1.0) * dt * 0.5
	# Suppress Wick dash afterimages cleanly when dash_trail is sold
	if sold.is_sold("dash_trail") and w.get("_fx") != null:
		var fx_v: Variant = w.get("_fx")
		if fx_v is Object and (fx_v as Object).get("afterimages") is Array:
			((fx_v as Object).get("afterimages") as Array).clear()


func _on_region_entered(island_id: int, region_id: String) -> void:
	if island_id == ISLAND_ID:
		on_region_loaded(region_id)
	else:
		if archive != null:
			archive.deactivate()
		if stair != null:
			stair.on_region_changed(island_id, region_id)
		var show_b: bool = _should_show_badge()
		if _hud_layer != null and is_instance_valid(_hud_layer):
			_hud_layer.visible = show_b
		if _hud_node != null and is_instance_valid(_hud_node):
			_hud_node.visible = show_b


func _on_great_lamp_relit(island_id: int) -> void:
	if island_id == ISLAND_ID and sold != null:
		sold.restore_all("dawn", true)


func _on_lantern_thrown(pos: Vector2, _dir: Vector2) -> void:
	if archive != null and archive.has_bookmark():
		archive.try_bookmark_near(pos, false)


func _on_lantern_hung(pos: Vector2) -> void:
	if archive != null:
		if archive.has_brass_receipt():
			archive.try_stamp_at(pos, false)
		if archive.has_bookmark():
			archive.try_bookmark_near(pos, false)


func _on_wick_fired(_dir: Vector2, kind: String) -> void:
	if sold == null or _bound_wick == null or not is_instance_valid(_bound_wick):
		return
	if kind == "bolt" and sold.has_power("fps_step") and _post_dash_t > 0.0:
		_post_dash_t = 0.0
		# Empower the newest bolt fired by Wick (1.6x Frame Skip damage).
		if not _bound_wick.bolts.is_empty():
			var b: Variant = _bound_wick.bolts[_bound_wick.bolts.size() - 1]
			if b is Dictionary and (b as Dictionary).has("damage"):
				(b as Dictionary)["damage"] = float((b as Dictionary)["damage"]) * 1.60
			elif b is Object and (b as Object).get("damage") != null:
				(b as Object).set("damage", float((b as Object).get("damage")) * 1.60)


func _on_enemy_hit(enemy: Object, hit: Object, _result: int) -> void:
	if sold == null or enemy == null or not is_instance_valid(enemy):
		return
	if sold.has_power("ember_hud") and _bound_wick != null and is_instance_valid(_bound_wick):
		_bound_wick.ember = minf(100.0, _bound_wick.ember + 1.5)
	if hit != null and is_instance_valid(hit) and hit.get("damage") != null:
		var base_d: float = float(hit.get("damage"))
		var bonus_mult: float = sold.modify_stat("bolt_damage", 1.0, {"hearts": Lx.state.hearts if Lx.state != null else 4.0})
		if stair != null:
			bonus_mult = stair.modify_stair_stat("bolt_damage", bonus_mult)
		if bonus_mult > 1.01 and enemy.get("hp") != null:
			var extra: float = base_d * (bonus_mult - 1.0)
			enemy.set("hp", maxf(0.0, float(enemy.get("hp")) - extra))


func _on_player_damaged(_amount: float, _from_pos: Vector2, _knock_dir: Vector2, _source: String) -> void:
	if stair != null and Lx.state != null and Lx.state.hearts <= 0.0:
		if stair.try_consume_last_breath():
			Lx.state.hearts = 1.0
			if Lx.events != null:
				Lx.events.player_healed.emit(1.0)


func _on_invoice_requested(boss_id: String, required_weight: int, context: Dictionary) -> void:
	var opts: Dictionary = context.duplicate(true)
	opts["mode"] = "invoice"
	opts["boss_id"] = boss_id
	opts["min_weight"] = required_weight
	open_toll_menu(opts)


func _on_sold_state_changed() -> void:
	if _hud_node != null and is_instance_valid(_hud_node):
		_hud_node.queue_redraw()


func _should_show_badge() -> bool:
	if Lx.root != null and is_instance_valid(Lx.root) and Lx.root.get("flow") != null and int(Lx.root.get("flow")) != 2:
		return false
	if Lx.ui != null and Lx.ui.has_method("is_modal_open") and bool(Lx.ui.call("is_modal_open")):
		return false
	if sold != null and sold.get_toll_weight() > 0:
		return true
	if stair != null and stair.is_in_stair():
		return true
	return false


func _draw_hud_badge() -> void:
	if _hud_node == null or not _should_show_badge():
		return
	var c: Node2D = _hud_node
	var void_c: Color = PAL["void"] as Color
	var night: Color = PAL["night"] as Color
	var gold: Color = PAL["gold"] as Color
	var cream: Color = PAL["cream"] as Color
	var sky: Color = PAL["sky"] as Color
	var in_stair: bool = stair != null and stair.is_in_stair()
	var frame_ready: bool = _post_dash_t > 0.0 and sold != null and sold.has_power("fps_step")
	var fred: bool = LxHudFx.flash_reduced()
	var tw: int = sold.get_toll_weight() if sold != null else 0
	var sc: int = sold.get_sold_count() if sold != null else 0
	var txt: String = "TOLL:%d" % tw
	if in_stair:
		txt = "F%d B:%d W:%d" % [stair.get_floor(), stair.get_boons().size(), tw]
	elif sc > 0:
		txt = "TOLL:%d S:%d" % [tw, sc]
	var w_px: float = float(LxPixelFont.width(txt, 1)) + 13.0
	var bx: float = roundf(315.0 - w_px)
	var by: float = 63.0
	var accent: Color = sky if in_stair else gold
	c.draw_rect(Rect2(bx, by, w_px, 11.0), void_c)
	c.draw_rect(Rect2(bx + 1.0, by + 1.0, w_px - 2.0, 9.0), night)
	c.draw_rect(Rect2(bx + 1.0, by + 1.0, 1.0, 9.0), cream if (frame_ready and not fred) else accent)
	# Greyscale-distinct mode icon (3x5 stair steps vs balance-scale T-bar)
	if in_stair:
		c.draw_rect(Rect2(bx + 4.0, by + 6.0, 2.0, 2.0), accent)
		c.draw_rect(Rect2(bx + 5.0, by + 4.0, 2.0, 2.0), accent)
		c.draw_rect(Rect2(bx + 6.0, by + 3.0, 2.0, 1.0), cream)
	else:
		c.draw_rect(Rect2(bx + 4.0, by + 3.0, 5.0, 1.0), cream)
		c.draw_rect(Rect2(bx + 6.0, by + 3.0, 1.0, 5.0), accent)
		c.draw_rect(Rect2(bx + 4.0, by + 5.0, 1.0, 1.0), accent)
		c.draw_rect(Rect2(bx + 8.0, by + 5.0, 1.0, 1.0), accent)
	LxPixelFont.draw(c, txt, Vector2(bx + 11.0, by + 3.0), cream, 1, void_c)


class _RuleTickDriver:
	extends Node
	var owner_rule: LxIsland8Rule = null

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(dt: float) -> void:
		if owner_rule != null:
			owner_rule._tick(dt)
