class_name LxIsland7Rule
extends RefCounted
## Island 7 (Moon Shoals - THE ISLAND THAT LIES) Rule Engine:
## - SILVER / BLACK world flip (`Lx.vars`: island:7 / dungeon:palace / dungeon:spire -> `world_face`).
## - Moon-Glass Pocket (`item_moon_pocket`): carry 1 `carry_orb` across Moon Pool flips + 48px Dual-World Throw Ripple.
## - Stagehand's Cue-Mirror (`item_cue_mirror`): golden spotlights let shots pierce velvet curtains & double `echo_rose` secs.
## - Truth Shadows helper: canonical SE truth / NW lie / absent / black-lantern shadow rendering (greyscale readable).
## - Move Theft (`set_move_locked` on every move + HUD cages): ALWAYS restored on leaving theft regions, dying, loading, or quitting.

const ISLAND_ID: int = 7
const SCOPE_ISLAND: String = "island:7"
const SCOPE_PALACE: String = "dungeon:palace"
const SCOPE_THEATRE: String = "dungeon:theatre"
const SCOPE_SPIRE: String = "dungeon:spire"

const ALL_MOVES: Array[String] = ["bolt", "dash", "throw", "prism", "beam", "wings", "lens", "sunflare"]
const MOVE_LABEL_KEYS: Dictionary = {
	"bolt": "ISL7_HUD_M_BOLT", "dash": "ISL7_HUD_M_DASH",
	"throw": "ISL7_HUD_M_THROW", "prism": "ISL7_HUD_M_PRISM",
	"beam": "ISL7_HUD_M_BEAM", "wings": "ISL7_HUD_M_WINGS",
	"lens": "ISL7_HUD_M_LENS", "sunflare": "ISL7_HUD_M_SUNFLARE",
}
const SHADOW_TRUTH := Vector2(3.0, 3.0)
const SHADOW_LIE := Vector2(-3.0, -3.0)
const POCKET_RIPPLE_RADIUS: float = 48.0

static var active_rule: LxIsland7Rule = null


class Island7HudOverlay:
	extends CanvasLayer
	var rule: LxIsland7Rule = null
	var canvas: Node2D = null
	var flip_flash_t: float = 0.0
	var flip_to_black: bool = false
	var reclaim_flash_t: float = 0.0
	var lock_pulse_t: float = 0.0
	var _was_dead: bool = false
	var _prev_pressed: Dictionary = {}

	func _ready() -> void:
		layer = 14
		canvas = Node2D.new()
		canvas.name = "Island7HudCanvas"
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		canvas.draw.connect(_on_draw)
		add_child(canvas)

	func _exit_tree() -> void:
		if rule != null:
			rule.restore_all_moves("exit_tree")

	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
			if rule != null:
				rule.restore_all_moves("quit")

	func _process(dt: float) -> void:
		var dirty: bool = false
		if flip_flash_t > 0.0:
			flip_flash_t = maxf(0.0, flip_flash_t - dt); dirty = true
		if reclaim_flash_t > 0.0:
			reclaim_flash_t = maxf(0.0, reclaim_flash_t - dt); dirty = true
		if lock_pulse_t > 0.0:
			lock_pulse_t = maxf(0.0, lock_pulse_t - dt); dirty = true
		if rule != null and Lx.player != null and is_instance_valid(Lx.player):
			var dead_now: bool = bool(Lx.player.get("dead"))
			if dead_now and not _was_dead:
				rule.restore_all_moves("wick_dead"); dirty = true
			_was_dead = dead_now
			if rule.has_stolen_moves() and Lx.input != null:
				const ACT_MAP: Dictionary = {
					"lx_fire": "bolt", "lx_dash": "dash", "lx_throw": "throw",
					"lx_beam": "beam", "lx_lens": "lens", "lx_sunflare": "sunflare",
				}
				for act: String in ACT_MAP.keys():
					var now_p: bool = Lx.input.is_action_active(act)
					var was_p: bool = bool(_prev_pressed.get(act, false))
					_prev_pressed[act] = now_p
					if now_p and not was_p and rule.is_move_stolen(str(ACT_MAP[act])):
						lock_pulse_t = 0.45; dirty = true
						if Lx.events != null: Lx.events.sfx_requested.emit("denied", Vector2.ZERO, false)
		if dirty and canvas != null: canvas.queue_redraw()

	func refresh() -> void:
		if canvas != null:
			canvas.queue_redraw()

	func _on_draw() -> void:
		if rule == null or canvas == null:
			return
		if Lx.state == null or Lx.state.island_id != ISLAND_ID:
			return
		if Lx.root != null and int(Lx.root.get("flow")) != 2:
			return
		var reg_id: String = Lx.state.region_id
		var face: String = rule.get_active_world_face(reg_id)
		var stolen: Array[String] = rule.get_stolen_moves()
		var is_black: bool = face == "black"
		# Keep untouched legacy Island 7 regions completely clean unless a rule is actively engaged
		var is_leg: bool = LxLegacy.is_legacy_region(ISLAND_ID, reg_id)
		if is_leg and not is_black and stolen.is_empty() and flip_flash_t <= 0.0 and reclaim_flash_t <= 0.0:
			return

		var c_void: Color = LxPalette.PAL["void"] as Color
		var c_night: Color = LxPalette.PAL["night"] as Color
		var c_dusk: Color = LxPalette.PAL["dusk"] as Color
		var c_ice: Color = LxPalette.PAL["ice"] as Color
		var c_sky: Color = LxPalette.PAL["sky"] as Color
		var c_cream: Color = LxPalette.PAL["cream"] as Color
		var c_gold: Color = LxPalette.PAL["gold"] as Color
		var c_rose: Color = LxPalette.PAL["rose"] as Color
		var c_coral: Color = LxPalette.PAL["coral"] as Color
		var c_wine: Color = LxPalette.PAL["wine"] as Color
		var fred: bool = LxHudFx.flash_reduced()

		if flip_flash_t > 0.0:
			var u: float = 1.0 - clampf(flip_flash_t / 1.2, 0.0, 1.0)
			var alpha: float = sin(u * PI) * (0.35 if fred else 0.72)
			var sx: float = roundf(lerpf(0.0, 320.0, u))
			canvas.draw_rect(Rect2(sx - 3.0, 0.0, 6.0, 180.0), Color(c_rose if flip_to_black else c_ice, alpha * 0.45))
			canvas.draw_rect(Rect2(sx, 0.0, 1.0, 180.0), Color(c_cream, alpha))

		var y_cur: float = 24.0
		var bx: float = 246.0; var bw: float = 68.0; var bh: float = 13.0
		var rim_c: Color = c_cream if (flip_flash_t > 0.6 and not fred) else (c_rose if is_black else c_ice)
		canvas.draw_rect(Rect2(bx, y_cur, bw, bh), c_void)
		canvas.draw_rect(Rect2(bx + 1.0, y_cur + 1.0, bw - 2.0, bh - 2.0), c_void if is_black else c_night)
		canvas.draw_rect(Rect2(bx + 1.0, y_cur + 1.0, bw - 2.0, 1.0), rim_c)
		if is_black:
			canvas.draw_rect(Rect2(bx + 5.0, y_cur + 4.0, 5.0, 5.0), c_rose)
			canvas.draw_rect(Rect2(bx + 6.0, y_cur + 5.0, 3.0, 3.0), c_void)
			canvas.draw_rect(Rect2(bx + 5.0, y_cur + 5.0, 1.0, 3.0), c_cream)
		else:
			canvas.draw_rect(Rect2(bx + 5.0, y_cur + 4.0, 5.0, 5.0), c_sky)
			canvas.draw_rect(Rect2(bx + 6.0, y_cur + 4.0, 3.0, 5.0), c_ice)
			canvas.draw_rect(Rect2(bx + 6.0, y_cur + 5.0, 2.0, 2.0), c_cream)
		var fkey: String = "ISL7_HUD_BLACK" if is_black else "ISL7_HUD_SILVER"
		if LxStrings.has_id(fkey):
			LxPixelFont.draw(canvas, LxStrings.text(fkey), Vector2(bx + 14.0, y_cur + 4.0), c_rose if is_black else c_cream)
		y_cur += bh + 2.0

		# 2. Stolen Moves Cage Strip (top-right stack, crimson velvet + golden bars)
		if not stolen.is_empty():
			var pill_w: float = 98.0
			var pill_x: float = 314.0 - pill_w
			var row_h: float = 12.0
			var total_h: float = 12.0 + float(stolen.size()) * row_h
			var pulse_on: bool = lock_pulse_t > 0.0 and not fred
			canvas.draw_rect(Rect2(pill_x, y_cur, pill_w, total_h), c_void)
			canvas.draw_rect(Rect2(pill_x + 1.0, y_cur + 1.0, pill_w - 2.0, total_h - 2.0), c_wine if pulse_on else c_night)
			canvas.draw_rect(Rect2(pill_x + 1.0, y_cur + 1.0, pill_w - 2.0, 1.0), c_cream if pulse_on else c_coral)
			var hdr: String = LxStrings.text("ISL7_HUD_STOLEN") if LxStrings.has_id("ISL7_HUD_STOLEN") else ""
			if not hdr.is_empty():
				LxPixelFont.draw(canvas, hdr, Vector2(pill_x + 5.0, y_cur + 4.0), c_cream if pulse_on else c_gold)
			for i: int in range(stolen.size()):
				var mid: String = stolen[i]
				var ry: float = y_cur + 12.0 + float(i) * row_h
				# Barred miniature cage icon
				canvas.draw_rect(Rect2(pill_x + 4.0, ry + 1.0, 7.0, 7.0), c_void)
				canvas.draw_rect(Rect2(pill_x + 5.0, ry + 2.0, 5.0, 5.0), c_dusk)
				canvas.draw_rect(Rect2(pill_x + 6.0, ry + 2.0, 1.0, 5.0), c_coral)
				canvas.draw_rect(Rect2(pill_x + 8.0, ry + 2.0, 1.0, 5.0), c_coral)
				var mkey: String = str(LxIsland7Rule.MOVE_LABEL_KEYS.get(mid, ""))
				var mlbl: String = LxStrings.text(mkey) if (not mkey.is_empty() and LxStrings.has_id(mkey)) else ""
				if not mlbl.is_empty():
					LxPixelFont.draw(canvas, mlbl, Vector2(pill_x + 15.0, ry + 2.0), c_cream if pulse_on else c_rose)
			y_cur += total_h + 2.0
		elif reclaim_flash_t > 0.0:
			var rbx: float = 216.0
			var rbw: float = 98.0
			canvas.draw_rect(Rect2(rbx, y_cur, rbw, 12.0), c_void)
			canvas.draw_rect(Rect2(rbx + 1.0, y_cur + 1.0, rbw - 2.0, 10.0), c_night)
			canvas.draw_rect(Rect2(rbx + 1.0, y_cur + 1.0, rbw - 2.0, 1.0), c_gold)
			var rlbl: String = LxStrings.text("ISL7_HUD_RESTORED") if LxStrings.has_id("ISL7_HUD_RESTORED") else ""
			if not rlbl.is_empty():
				LxPixelFont.draw(canvas, rlbl, Vector2(rbx + 6.0, y_cur + 4.0), c_cream)
			y_cur += 14.0

		# 3. Dungeon Power Micro-Badges (Moon Pocket / Cue Mirror when active)
		if rule.has_moon_pocket():
			var pbx: float = 252.0
			var pbw: float = 62.0
			var carrying: bool = Lx.player != null and is_instance_valid(Lx.player) and Lx.player.has_method("is_carrying") and bool(Lx.player.call("is_carrying"))
			canvas.draw_rect(Rect2(pbx, y_cur, pbw, 11.0), c_void)
			canvas.draw_rect(Rect2(pbx + 1.0, y_cur + 1.0, pbw - 2.0, 9.0), c_night)
			canvas.draw_rect(Rect2(pbx + 1.0, y_cur + 1.0, pbw - 2.0, 1.0), c_cream if carrying else c_sky)
			var plbl: String = LxStrings.text("ISL7_HUD_POCKET") if LxStrings.has_id("ISL7_HUD_POCKET") else ""
			if not plbl.is_empty():
				LxPixelFont.draw(canvas, plbl, Vector2(pbx + 5.0, y_cur + 3.0), c_cream if carrying else c_ice)
			y_cur += 13.0
		if rule.has_cue_mirror():
			var in_spot: bool = false
			if Lx.player is Node2D and is_instance_valid(Lx.player):
				in_spot = LxIsland7Rule.is_in_cue_spotlight((Lx.player as Node2D).global_position)
			var cbx: float = 252.0
			var cbw: float = 62.0
			canvas.draw_rect(Rect2(cbx, y_cur, cbw, 11.0), c_void)
			canvas.draw_rect(Rect2(cbx + 1.0, y_cur + 1.0, cbw - 2.0, 9.0), c_night)
			canvas.draw_rect(Rect2(cbx + 1.0, y_cur + 1.0, cbw - 2.0, 1.0), c_cream if in_spot else c_gold)
			var clbl: String = LxStrings.text("ISL7_HUD_CUE") if LxStrings.has_id("ISL7_HUD_CUE") else ""
			if not clbl.is_empty():
				LxPixelFont.draw(canvas, clbl, Vector2(cbx + 5.0, y_cur + 3.0), c_cream if in_spot else c_gold)


var _events: LxEventBus = null
var _state: LxGameState = null
var _vars: LxWorldState = null
var _attached: bool = false
var _hud: Island7HudOverlay = null
var _stolen_sources: Dictionary = {} # move_id -> Array[String] of source_ids
var _active_region_id: String = ""


func attach(events: LxEventBus = null, state: LxGameState = null) -> void:
	if _attached:
		detach()
	_events = events if events != null else Lx.events
	_state = state if state != null else Lx.state
	_vars = Lx.vars
	_attached = true
	active_rule = self
	_ensure_defaults()
	# Always start clean on attach/load (active mask plinths re-apply theft in their region)
	restore_all_moves("attach")
	if _events != null:
		if not _events.region_entered.is_connected(_on_region_entered):
			_events.region_entered.connect(_on_region_entered)
		if not _events.player_died.is_connected(_on_player_died):
			_events.player_died.connect(_on_player_died)
		if not _events.lantern_thrown.is_connected(_on_lantern_thrown):
			_events.lantern_thrown.connect(_on_lantern_thrown)
	if _vars != null and not _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.connect(_on_var_changed)
	_attach_hud()


func detach() -> void:
	restore_all_moves("detach")
	if _events != null:
		if _events.region_entered.is_connected(_on_region_entered):
			_events.region_entered.disconnect(_on_region_entered)
		if _events.player_died.is_connected(_on_player_died):
			_events.player_died.disconnect(_on_player_died)
		if _events.lantern_thrown.is_connected(_on_lantern_thrown):
			_events.lantern_thrown.disconnect(_on_lantern_thrown)
	if _vars != null and _vars.var_changed.is_connected(_on_var_changed):
		_vars.var_changed.disconnect(_on_var_changed)
	if _hud != null and is_instance_valid(_hud):
		_hud.rule = null
		_hud.queue_free()
	_hud = null
	_active_region_id = ""
	if active_rule == self:
		active_rule = null
	_attached = false


func _attach_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		return
	if Lx.root == null or not is_instance_valid(Lx.root):
		return
	_hud = Island7HudOverlay.new()
	_hud.name = "Island7HudOverlay"
	_hud.rule = self
	Lx.root.add_child(_hud)


func _ensure_defaults() -> void:
	if _vars == null:
		return
	for sc: String in [SCOPE_ISLAND, SCOPE_PALACE, SCOPE_SPIRE]:
		var v: String = str(_vars.get_var(sc, "world_face", "")).strip_edges().to_lower()
		if v != "silver" and v != "black":
			_vars.set_var(sc, "world_face", "silver")
	var act_v: String = str(_vars.get_var(SCOPE_THEATRE, "stolen_act", "")).strip_edges().to_lower()
	if act_v.is_empty():
		_vars.set_var(SCOPE_THEATRE, "stolen_act", "none")


# ---- SILVER / BLACK World State ----

static func resolve_face_scope(region_id: String, explicit_scope: String = "") -> String:
	var exp_s: String = explicit_scope.strip_edges()
	if not exp_s.is_empty():
		if exp_s == "island":
			return SCOPE_ISLAND
		if exp_s == "room":
			return "room:%d:%s" % [ISLAND_ID, region_id]
		return exp_s
	if region_id.begins_with("palace_"):
		return SCOPE_PALACE
	if region_id.begins_with("spire_"):
		return SCOPE_SPIRE
	return SCOPE_ISLAND


func get_world_face(scope: String = SCOPE_ISLAND) -> String:
	if _vars == null:
		return "silver"
	var raw: String = str(_vars.get_var(scope, "world_face", "silver")).strip_edges().to_lower()
	return "black" if raw == "black" else "silver"


func get_active_world_face(region_id: String = "") -> String:
	var rid: String = region_id if not region_id.is_empty() else _active_region_id
	return get_world_face(resolve_face_scope(rid))


func set_world_face(scope: String, face: String, trigger_fx: bool = true, origin: Vector2 = Vector2.ZERO) -> String:
	var norm: String = "black" if face.strip_edges().to_lower() == "black" else "silver"
	var sc: String = scope if not scope.is_empty() else SCOPE_ISLAND
	if _vars != null:
		_vars.set_var(sc, "world_face", norm)
	if Lx.world != null and is_instance_valid(Lx.world) and Lx.world.has_method("apply_layers"):
		Lx.world.call("apply_layers", trigger_fx)
	if trigger_fx:
		if _events != null:
			_events.sfx_requested.emit("moon_pool_flip", origin, origin != Vector2.ZERO)
		if _hud != null:
			_hud.flip_to_black = (norm == "black")
			_hud.flip_flash_t = 1.2
			_hud.refresh()
	elif _hud != null:
		_hud.refresh()
	return norm


func flip_world_face(scope: String = SCOPE_ISLAND, origin: Vector2 = Vector2.ZERO) -> String:
	var cur: String = get_world_face(scope)
	var nxt: String = "black" if cur == "silver" else "silver"
	return set_world_face(scope, nxt, true, origin)


# ---- Move Theft & Bulletproof Restoration ----

func steal_moves(moves: Array, act_id: String = "act1", source_id: String = "plinth") -> void:
	var w: LxWick = _get_wick()
	var any_new: bool = false
	for mv_v: Variant in moves:
		var mid: String = str(mv_v).strip_edges().to_lower()
		if not ALL_MOVES.has(mid):
			continue
		var srcs: Array = _stolen_sources.get(mid, []) as Array
		if not srcs.has(source_id):
			srcs.append(source_id)
			_stolen_sources[mid] = srcs
			any_new = true
		_apply_single_move_lock(w, mid, true)
	if _vars != null and not act_id.is_empty():
		_vars.set_var(SCOPE_THEATRE, "stolen_act", act_id)
	if any_new and _hud != null:
		_hud.lock_pulse_t = 0.65
		_hud.refresh()


func reclaim_moves(moves: Array, source_id: String = "") -> void:
	var w: LxWick = _get_wick()
	var released_any: bool = false
	for mv_v: Variant in moves:
		var mid: String = str(mv_v).strip_edges().to_lower()
		if not _stolen_sources.has(mid):
			continue
		var srcs: Array = _stolen_sources[mid] as Array
		if source_id.is_empty():
			srcs.clear()
		else:
			srcs.erase(source_id)
		if srcs.is_empty():
			_stolen_sources.erase(mid)
			_apply_single_move_lock(w, mid, false)
			released_any = true
		else:
			_stolen_sources[mid] = srcs
	if _stolen_sources.is_empty() and _vars != null:
		_vars.set_var(SCOPE_THEATRE, "stolen_act", "none")
	if released_any and _hud != null:
		_hud.reclaim_flash_t = 1.6
		_hud.refresh()


func restore_all_moves(_reason: String = "") -> void:
	_stolen_sources.clear()
	var w: LxWick = _get_wick()
	if w != null:
		for mid: String in ALL_MOVES:
			w.set_move_locked(mid, false)
		w.sync_unlocks_from_state()
	if _vars != null:
		_vars.set_var(SCOPE_THEATRE, "stolen_act", "none")
	if _hud != null:
		_hud.refresh()


func is_move_stolen(move_id: String) -> bool:
	return _stolen_sources.has(move_id.strip_edges().to_lower())


func has_stolen_moves() -> bool:
	return not _stolen_sources.is_empty()


func get_stolen_moves() -> Array[String]:
	var out: Array[String] = []
	for mid: String in ALL_MOVES:
		if _stolen_sources.has(mid):
			out.append(mid)
	return out


func _apply_single_move_lock(w: LxWick, move_id: String, locked: bool) -> void:
	if w == null:
		return
	w.set_move_locked(move_id, locked)
	# Also guard moves whose kit scripts don't yet check LxMove.locked (without mutating Lx.state!)
	if w.moves.has(move_id) and w.moves[move_id] is LxMove:
		var mv: LxMove = w.moves[move_id] as LxMove
		if locked:
			mv.unlocked = false
			if move_id == "lens" and w.move_lens != null:
				w.move_lens.reset()
		else:
			mv.sync_unlock()


func _reapply_active_locks_to_wick() -> void:
	var w: LxWick = _get_wick()
	if w == null:
		return
	for mid: String in ALL_MOVES:
		_apply_single_move_lock(w, mid, _stolen_sources.has(mid))


# ---- Moon-Glass Pocket & Cue-Mirror ----

func has_moon_pocket() -> bool:
	var st: LxGameState = _state if _state != null else Lx.state
	return st != null and bool(st.story_flags.get("item_moon_pocket", false))


func has_cue_mirror() -> bool:
	var st: LxGameState = _state if _state != null else Lx.state
	return st != null and bool(st.story_flags.get("item_cue_mirror", false))


static func is_in_cue_spotlight(world_pos: Vector2, region_node: Node = null) -> bool:
	var ctx: Node = region_node if region_node != null else Lx.world
	if ctx == null or not is_instance_valid(ctx) or not ctx.has_method("get_interactables"):
		return false
	for it_v: Variant in (ctx.call("get_interactables") as Array):
		if it_v is LxMirror and (it_v as LxMirror).contains_spotlight(world_pos):
			return true
	return false


static func trigger_pocket_ripple(origin: Vector2, region_node: Node = null) -> int:
	var ctx: Node = region_node if region_node != null else Lx.world
	var pinged: int = 0
	if ctx != null and is_instance_valid(ctx) and ctx.has_method("get_interactables"):
		for it_v: Variant in (ctx.call("get_interactables") as Array):
			if not (it_v is LxInteractable) or not is_instance_valid(it_v):
				continue
			var it: LxInteractable = it_v as LxInteractable
			if it.pos.distance_to(origin) > POCKET_RIPPLE_RADIUS + it.radius:
				continue
			if it.has_method("on_moon_pocket_ripple"):
				it.call("on_moon_pocket_ripple", origin)
				pinged += 1
			elif it.kind in ["light_sensor", "beam_sensor", "switch_eye", "brazier", "timed_brazier", "light_plant"]:
				if it.has_method("on_light"):
					it.call("on_light", POCKET_RIPPLE_RADIUS, "moon_pocket")
					pinged += 1
				if it.kind == "switch_eye" and it.has_method("on_hit"):
					var rhit: LxHit = LxHit.make(LxHit.SOURCE_PRISM, 1.0, (it.pos - origin).normalized(), origin, 0.5, false, false, Lx.player, false, LxHit.COLOR_BLUE)
					it.call("on_hit", rhit)
					pinged += 1
	if Lx.player is LxWick and is_instance_valid(Lx.player):
		(Lx.player as LxWick).spawn_ring(origin, 4.0, POCKET_RIPPLE_RADIUS, 0.34, LxPalette.PAL["ice"] as Color, 1.5)
	if Lx.events != null:
		Lx.events.sfx_requested.emit("mirror_ping", origin, true)
	return pinged


func _apply_cue_mirror_echo_bonus() -> void:
	if not has_cue_mirror():
		return
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_interactables"):
		return
	for it_v: Variant in (Lx.world.call("get_interactables") as Array):
		if it_v is LxEchoRose:
			var rose: LxEchoRose = it_v as LxEchoRose
			if not rose.has_meta("cue_mirror_doubled"):
				rose.set_meta("cue_mirror_doubled", true)
				rose.secs *= 2.0


# ---- Truth Shadows Law (Canonical Pixel Renderer) ----

static func draw_truth_shadow(
	ci: CanvasItem,
	base_pos: Vector2,
	rx: float,
	ry: float,
	shadow_mode: String = "se_gold",
	lens_boost: bool = false
) -> void:
	var mode: String = shadow_mode.strip_edges().to_lower()
	if mode == "none":
		return
	var c_void: Color = LxPalette.PAL["void"] as Color
	var c_gold: Color = LxPalette.PAL["gold"] as Color
	var c_rose: Color = LxPalette.PAL["rose"] as Color
	var c_wine: Color = LxPalette.PAL["wine"] as Color
	var alpha: float = 0.62 if lens_boost else 0.44
	var off: Vector2 = SHADOW_LIE if mode == "nw_wrong" else SHADOW_TRUTH
	var c: Vector2 = (base_pos + off).round()
	var w: float = maxf(4.0, roundf(rx * 2.0))
	var h: float = maxf(2.0, roundf(ry * 2.0))
	ci.draw_rect(Rect2(c.x - floorf(w * 0.5) + 1.0, c.y - floorf(h * 0.5), maxf(2.0, w - 2.0), h), Color(c_void, alpha))
	ci.draw_rect(Rect2(c.x - floorf(w * 0.5), c.y - floorf(h * 0.5) + 1.0, w, maxf(1.0, h - 2.0)), Color(c_void, alpha))
	if mode == "se_gold":
		# Crisp SE directional glint so truth shadows read cleanly even in greyscale
		ci.draw_rect(Rect2(c.x + floorf(w * 0.5) - 2.0, c.y + floorf(h * 0.5) - 1.0, 2.0, 1.0), Color(c_gold, 0.72 if lens_boost else 0.48))
	elif mode == "nw_wrong":
		# Distinct NW directional tail pointing wrong-way up-left
		ci.draw_rect(Rect2(c.x - floorf(w * 0.5) - 1.0, c.y - floorf(h * 0.5) - 1.0, 2.0, 2.0), Color(c_void, alpha + 0.16))
		if lens_boost:
			ci.draw_rect(Rect2(c.x - floorf(w * 0.5) - 1.0, c.y - floorf(h * 0.5) - 1.0, 1.0, 1.0), c_rose)
	elif mode == "black_lantern":
		# Hollow dark lantern ring carried by the shadow itself (Hollow Wick Cotillion tell!)
		var lp: Vector2 = (c + Vector2(rx + 2.0, 0.0)).round()
		ci.draw_rect(Rect2(lp.x - 2.0, lp.y - 2.0, 5.0, 5.0), c_void)
		ci.draw_rect(Rect2(lp.x - 1.0, lp.y - 1.0, 3.0, 3.0), c_rose if lens_boost else c_wine)
		ci.draw_rect(Rect2(lp.x, lp.y, 1.0, 1.0), c_void)


# ---- Event Handlers ----

func _on_region_entered(island_id: int, region_id: String) -> void:
	# Always restore stolen moves on every region change; any active mask_plinth in the new room re-applies cleanly
	restore_all_moves("region_change")
	if island_id != ISLAND_ID:
		_active_region_id = ""
		if _hud != null:
			_hud.refresh()
		return
	_active_region_id = region_id
	_apply_cue_mirror_echo_bonus()
	_activate_region_mask_plinths()
	if _hud != null:
		_hud.refresh()


func on_region_loaded(region_id: String) -> void:
	_active_region_id = region_id
	_apply_cue_mirror_echo_bonus()
	_reapply_active_locks_to_wick()
	if _hud != null:
		_hud.refresh()


func _activate_region_mask_plinths() -> void:
	if Lx.world == null or not is_instance_valid(Lx.world) or not Lx.world.has_method("get_interactables"):
		return
	for it_v: Variant in (Lx.world.call("get_interactables") as Array):
		if it_v is LxInteractable and (it_v as LxInteractable).kind == "mask_plinth":
			var mp: LxInteractable = it_v as LxInteractable
			if bool(mp.get("auto_steal")) and float(mp.get("steal_radius")) <= 0.0 and mp.has_method("apply_room_theft"):
				mp.call("apply_room_theft", true)


func _on_player_died() -> void:
	restore_all_moves("player_died")


func _on_lantern_thrown(at_pos: Vector2, _dir: Vector2) -> void:
	if has_moon_pocket():
		trigger_pocket_ripple(at_pos)


func _on_var_changed(_scope: String, var_name: String, value: Variant) -> void:
	if var_name == "world_face" and _hud != null:
		_hud.flip_to_black = str(value).strip_edges().to_lower() == "black"
		_hud.flip_flash_t = maxf(_hud.flip_flash_t, 1.2)
		_hud.refresh()
	elif var_name == "stolen_act" and _hud != null:
		_hud.refresh()


func _get_wick() -> LxWick:
	return Lx.player as LxWick if (Lx.player is LxWick and is_instance_valid(Lx.player)) else null
