class_name LxRestShop
extends Node2D
## Lamplighter's Rest upgrade shrine reading luxel/data/upgrades.json (SWARM_SPEC 3.5).

signal closed()
signal upgrade_bought(upgrade_id: String, new_rank: int)

const PANEL_RECT := Rect2(20.0, 12.0, 280.0, 156.0)
const VISIBLE_ROWS: int = 6
const SPARK_DUR: float = 0.45

const ICON_PAL: Dictionary = {
	"k": "void", "n": "night", "d": "dusk", "m": "mauve",
	"w": "wine", "r": "coral", "a": "apricot", "g": "gold",
	"c": "cream", "b": "blue", "s": "sky", "i": "ice",
}

const UPGRADE_ICONS: Dictionary = {
	"bolt_damage": ["...c...", "..cgc..", "..gag..", ".gacag.", ".argrr.", "..dgd..", "..nnn.."],
	"bolt_rate": ["...cg..", "..cga..", ".cgag..", "..agac.", ".s.gag.", "..cga..", ".s.a..."],
	"throw_damage": ["..aga..", ".dgggd.", ".a.c.a.", ".acgca.", ".a.g.a.", ".dgggd.", "..ddd.."],
	"dash_cooldown": [".g...g.", "gg.c.gg", "agacaga", ".a.c.a.", ".s.g.s.", "..s.s..", "...a..."],
	"prism_bounce": ["...g...", "..iic..", ".iissc.", ".iissb.", "gisbbbg", ".gbbbg.", "..ddd.."],
	"beam_charge": [".....c.", "....cg.", "..iicg.", ".isccag", "..iicg.", "....cg.", ".....c."],
	"wings_glide": [".i...i.", "iis.sii", "iscccsi", ".sgggs.", "..aga..", "..d.d..", "......."],
	"lens_duration": ["..sss..", ".siiis.", "siiccis", "sicgcis", "siiccis", ".siiis.", "..bbb.."],
	"ember_meter": [".rr.rr.", "ragagar", "ragcgar", "raggagr", ".rgggr.", "..rar..", "...w..."],
}
const DEFAULT_ICON: Array[String] = ["...g...", "..gag..", ".gacag.", "..gag..", "...g...", ".......", "......."]

var _upgrades: Array[Dictionary] = []
var _idx: int = 0
var _scroll: int = 0
var _close_hover: bool = false
var _feedback_txt: String = ""
var _feedback_col: String = "lime"
var _feedback_t: float = 0.0
var _elapsed: float = 0.0
var _spark_row: int = -1
var _spark_pip: int = -1
var _spark_t: float = 0.0
var _deny_row: int = -1
var _deny_t: float = 0.0


func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS; visible = false
func close() -> void: visible = false

func open() -> void:
	_load_upgrades()
	_idx = 0; _scroll = 0; _feedback_txt = ""; _feedback_t = 0.0; _elapsed = 0.0
	_spark_row = -1; _spark_pip = -1; _spark_t = 0.0; _deny_row = -1; _deny_t = 0.0
	visible = true
	_play_ui_sfx("menu_open")
	queue_redraw()

func _load_upgrades() -> void:
	_upgrades.clear()
	if Lx.data_upgrades.is_empty(): Lx.load_all_data()
	var arr: Variant = Lx.data_upgrades.get("upgrades", [])
	if arr is Array:
		for item: Variant in (arr as Array):
			if item is Dictionary: _upgrades.append(item as Dictionary)

func _process(delta: float) -> void:
	if not visible: return
	_elapsed += delta
	if _feedback_t > 0.0:
		_feedback_t = maxf(0.0, _feedback_t - delta)
		if _feedback_t <= 0.0: _feedback_txt = ""
	if _spark_t > 0.0:
		_spark_t = maxf(0.0, _spark_t - delta)
		if _spark_t <= 0.0: _spark_row = -1; _spark_pip = -1
	if _deny_t > 0.0:
		_deny_t = maxf(0.0, _deny_t - delta)
		if _deny_t <= 0.0: _deny_row = -1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		var over_close: bool = _close_btn_rect().has_point(pos)
		if over_close != _close_hover:
			_close_hover = over_close
			if over_close:
				_play_ui_sfx("ui_move")
			queue_redraw()
		for vis_i: int in range(VISIBLE_ROWS):
			var row_i: int = _scroll + vis_i
			if row_i >= _upgrades.size():
				break
			if _row_rect(vis_i).has_point(pos):
				if _idx != row_i:
					_idx = row_i
					_play_ui_sfx("ui_move")
					queue_redraw()
				return
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _close_btn_rect().has_point(mb.position):
				_play_ui_sfx("menu_close")
				closed.emit()
				get_viewport().set_input_as_handled()
				return
			for vis_i: int in range(VISIBLE_ROWS):
				var row_i: int = _scroll + vis_i
				if row_i >= _upgrades.size():
					break
				if _row_rect(vis_i).has_point(mb.position):
					_idx = row_i
					_try_buy(_idx)
					get_viewport().set_input_as_handled()
					return
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_play_ui_sfx("menu_close")
			closed.emit()
			get_viewport().set_input_as_handled()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var max_s: int = maxi(0, _upgrades.size() - VISIBLE_ROWS)
			var delta_s: int = -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			var next_s: int = clampi(_scroll + delta_s, 0, max_s)
			if next_s != _scroll:
				_scroll = next_s
				_idx = clampi(_idx, _scroll, mini(_upgrades.size() - 1, _scroll + VISIBLE_ROWS - 1))
				_play_ui_sfx("ui_move")
				queue_redraw()
			get_viewport().set_input_as_handled()
		return

	var count: int = maxi(1, _upgrades.size())
	if event.is_action_pressed("lx_move_up") or _key_just(event, KEY_UP):
		_idx = (_idx - 1 + count) % count
		_sync_scroll()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_move_down") or _key_just(event, KEY_DOWN):
		_idx = (_idx + 1) % count
		_sync_scroll()
		_play_ui_sfx("ui_move")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_accept") or _key_just(event, KEY_ENTER) or _key_just(event, KEY_SPACE):
		_try_buy(_idx)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lx_ui_cancel") or event.is_action_pressed("lx_pause") or _key_just(event, KEY_ESCAPE):
		_play_ui_sfx("menu_close")
		closed.emit()
		get_viewport().set_input_as_handled()


func _sync_scroll() -> void:
	if _idx < _scroll:
		_scroll = _idx
	elif _idx >= _scroll + VISIBLE_ROWS:
		_scroll = _idx - VISIBLE_ROWS + 1


func _try_buy(i: int) -> void:
	if i < 0 or i >= _upgrades.size() or Lx.state == null:
		return
	var u: Dictionary = _upgrades[i]
	var uid: String = str(u.get("id", ""))
	if not Lx.state.is_upgrade_unlocked(uid):
		_feedback_txt = LxStrings.fmt("SHOP_NEED_MOVE_FMT", [_req_move_name(u)])
		_feedback_col = "coral"
		_feedback_t = 1.3
		_deny_row = i
		_deny_t = 0.22
		_play_ui_sfx("denied")
	elif Lx.state.buy_upgrade(uid):
		var new_rank: int = Lx.state.get_upgrade_rank(uid)
		_feedback_txt = LxStrings.text("SHOP_BOUGHT")
		_feedback_col = "lime"
		_feedback_t = 1.6
		_spark_row = i
		_spark_pip = maxi(0, new_rank - 1)
		_spark_t = SPARK_DUR
		_play_ui_sfx("shop_buy")
		if Lx.events != null:
			Lx.events.save_requested.emit("upgrade")
		upgrade_bought.emit(uid, new_rank)
	else:
		var is_max: bool = Lx.state.get_upgrade_rank(uid) >= int(u.get("max_rank", 0))
		_feedback_txt = LxStrings.text("SHOP_MAXED" if is_max else "SHOP_NO_SHARDS")
		_feedback_col = "stone" if is_max else "coral"
		_feedback_t = 1.2
		_deny_row = i
		_deny_t = 0.22
		_play_ui_sfx("denied")
	queue_redraw()


func _draw() -> void:
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var bdr_k: String = LxBiomePalette.key(isl, "border")
	LxPixelFont.draw_panel(self, PANEL_RECT, "dusk", bdr_k, "night")
	_draw_frame_ornaments(isl)
	_draw_brazier_icon(Vector2(27.0, 16.0), isl)
	LxPixelFont.draw_left(self, LxStrings.text("SHOP_TITLE"), Vector2(38.0, 18.0), LxBiomePalette.col(isl, "glow"), 1)
	var title_end: float = 38.0 + float(LxPixelFont.width(LxStrings.text("SHOP_TITLE"), 1)) + 8.0
	LxHudFx.draw_biome_crest(self, isl, Vector2(title_end, 20.0), LxBiomePalette.col(isl, "glow"), LxPalette.PAL["cream"] as Color)

	var shards: int = Lx.state.shards if Lx.state != null else 0
	var shard_txt: String = LxStrings.fmt("SHOP_SHARDS_FMT", [shards])
	var gem_x: float = 292.0 - float(LxPixelFont.width(shard_txt, 1)) - 10.0
	_draw_shard_gem_icon(Vector2(gem_x, 16.0))
	LxPixelFont.draw_right(self, shard_txt, 292.0, 18.0, LxPalette.PAL["cream"] if _spark_t > 0.24 else LxPalette.PAL["apricot"], 1)

	# Total upgrades progress badge (X/Y) in header.
	var prog: Vector2i = Lx.state.get_upgrade_totals() if Lx.state != null else Vector2i(0, 20)
	var prog_txt: String = LxStrings.fmt("SHOP_PROGRESS_FMT", [prog.x, prog.y])
	var pw: float = float(LxPixelFont.width(prog_txt, 1)) + 8.0
	var all_done: bool = prog.y > 0 and prog.x >= prog.y
	var pill_r := Rect2(roundf(gem_x - pw - 6.0), 15.0, pw, 11.0)
	LxPixelFont.draw_panel(self, pill_r, "night", "lime" if all_done else "mauve", "void")
	LxPixelFont.draw_centered(self, prog_txt, pill_r.get_center().x, 18.0, LxPalette.PAL["lime" if all_done else "cream"], 1)

	LxPixelFont.draw_left(self, LxStrings.text("SHOP_SUBTITLE"), Vector2(28.0, 27.0), LxPalette.PAL["stone"], 1)

	for vis_i: int in range(VISIBLE_ROWS):
		var row_i: int = _scroll + vis_i
		if row_i >= _upgrades.size():
			break
		_draw_upgrade_row(vis_i, row_i, _upgrades[row_i])
	_draw_scrollbar()

	# Selected item description + live mechanical stat-delta + shard-balance preview pill.
	var desc_rect := Rect2(28.0, 129.0, 264.0, 23.0)
	LxPixelFont.draw_panel(self, desc_rect, "night", "mauve", "void")
	if not _feedback_txt.is_empty():
		LxPixelFont.draw_centered(self, _feedback_txt, 160.0, 138.0, LxPalette.color(_feedback_col), 1)
	elif _idx >= 0 and _idx < _upgrades.size():
		var sel_u: Dictionary = _upgrades[_idx]
		var sel_uid: String = str(sel_u.get("id", ""))
		var unlocked: bool = Lx.state == null or Lx.state.is_upgrade_unlocked(sel_uid)
		var desc_key: String = str(sel_u.get("desc_key", ""))
		if not unlocked:
			LxPixelFont.draw_left(self, LxStrings.fmt("SHOP_NEED_MOVE_FMT", [_req_move_name(sel_u)]), Vector2(34.0, 133.0), LxPalette.PAL["coral"], 1)
			LxPixelFont.draw_left(self, LxStrings.text(desc_key), Vector2(34.0, 142.0), LxPalette.PAL["stone"], 1)
		else:
			LxPixelFont.draw_left(self, LxStrings.text(desc_key), Vector2(34.0, 133.0), LxPalette.PAL["cream"], 1)
			var is_max: bool = Lx.state != null and Lx.state.get_upgrade_rank(sel_uid) >= int(sel_u.get("max_rank", 1))
			LxPixelFont.draw_left(self, _stat_delta_text(sel_u), Vector2(34.0, 142.0), LxPalette.PAL["lime" if is_max else "sky"], 1)
		_draw_shard_preview_pill(desc_rect, sel_u, shards, unlocked)

	LxPixelFont.draw_left(self, LxStrings.text("SHOP_BUY_HINT"), Vector2(28.0, 157.0), LxPalette.PAL["stone"], 1)
	var cr: Rect2 = _close_btn_rect()
	LxPixelFont.draw_panel(self, cr, "plum" if _close_hover else "night", "gold" if _close_hover else "mauve", "void")
	LxPixelFont.draw_centered(self, LxStrings.text("SHOP_CLOSE"), cr.get_center().x, cr.position.y + 3.0, LxPalette.PAL["gold"] if _close_hover else LxPalette.PAL["cream"], 1)


func _draw_scrollbar() -> void:
	if _upgrades.size() <= VISIBLE_ROWS:
		return
	var track := Rect2(289.0, 38.0, 3.0, 88.0)
	draw_rect(track.grow(1.0), LxPalette.PAL["night"])
	draw_rect(track, LxPalette.PAL["void"])
	var thumb_h: float = maxf(14.0, track.size.y * float(VISIBLE_ROWS) / float(_upgrades.size()))
	var frac: float = float(_scroll) / float(maxi(1, _upgrades.size() - VISIBLE_ROWS))
	var thumb_y: float = roundf(track.position.y + (track.size.y - thumb_h) * frac)
	draw_rect(Rect2(track.position.x, thumb_y, track.size.x, roundf(thumb_h)), LxPalette.PAL["gold"])
	draw_rect(Rect2(track.position.x, thumb_y, track.size.x, 1.0), LxPalette.PAL["cream"])


func _draw_upgrade_row(vis_i: int, row_i: int, u: Dictionary) -> void:
	var r: Rect2 = _row_rect(vis_i)
	var denied: bool = _deny_t > 0.0 and row_i == _deny_row
	if denied and LxHudFx.shake_enabled():
		r.position.x += roundf(sin(_deny_t * 54.0) * 1.6)
	var sel: bool = row_i == _idx
	var uid: String = str(u.get("id", ""))
	var unlocked: bool = Lx.state == null or Lx.state.is_upgrade_unlocked(uid)
	var rank: int = Lx.state.get_upgrade_rank(uid) if Lx.state != null else 0
	var max_rank: int = int(u.get("max_rank", 1))
	var costs: Array = u.get("costs", []) as Array
	var maxed: bool = rank >= max_rank
	var affordable: bool = Lx.state != null and Lx.state.can_buy_upgrade(uid)

	if sel:
		var fill_k: String = "night" if not unlocked else "plum"
		var bdr_k: String = "coral" if denied else ("mauve" if not unlocked else "gold")
		LxPixelFont.draw_panel(self, r, fill_k, bdr_k, "night")
		var bob: float = 0.0 if (denied or LxHudFx.flash_reduced()) else (1.0 if fmod(_elapsed * 3.0, 1.0) < 0.5 else 0.0)
		var cx: float = 23.0 + bob
		var cy: float = r.position.y + 4.0
		var c_out: Color = LxPalette.PAL["coral"] if denied else (LxPalette.PAL["mauve"] if not unlocked else LxPalette.PAL["gold"])
		var c_hi: Color = LxPalette.PAL["apricot"] if denied else (LxPalette.PAL["stone"] if not unlocked else LxPalette.PAL["cream"])
		draw_rect(Rect2(cx - 1.0, cy - 1.0, 3.0, 7.0), LxPalette.PAL["void"])
		draw_rect(Rect2(cx, cy, 1.0, 5.0), c_out)
		draw_rect(Rect2(cx + 1.0, cy + 1.0, 1.0, 3.0), c_hi)
		draw_rect(Rect2(cx + 2.0, cy + 2.0, 1.0, 1.0), c_out)
	else:
		LxPixelFont.draw_panel(self, r, "void" if not unlocked else "night", "night" if not unlocked else "dusk", "void")

	_draw_upgrade_icon(r.position + Vector2(5.0, 3.0), uid, sel and unlocked, not unlocked)
	var name_key: String = str(u.get("name_key", ""))
	var name_col: Color = (LxPalette.PAL["stone"] if sel else LxPalette.PAL["mauve"]) if not unlocked else (LxPalette.PAL["gold"] if sel else LxPalette.PAL["cream"])
	LxPixelFont.draw_left(self, LxStrings.text(name_key), r.position + Vector2(16.0, 4.0), name_col, 1)

	# Polished glowing crystal rank pips (up to 4).
	var pip_x: float = r.position.x + 140.0
	for p: int in range(max_rank):
		var pr := Rect2(pip_x + float(p * 8), r.position.y + 4.0, 5.0, 5.0)
		_draw_rank_pip(pr, p < rank, sel and unlocked, p, unlocked and sel and not maxed and affordable and p == rank)
	if _spark_t > 0.0 and row_i == _spark_row and _spark_pip >= 0:
		_draw_purchase_sparkle(Vector2(pip_x + float(_spark_pip * 8) + 2.0, r.position.y + 6.0))

	if not unlocked:
		LxPixelFont.draw_right(self, LxStrings.text("SHOP_LOCKED_MOVE"), r.end.x - 6.0, r.position.y + 4.0, LxPalette.PAL["coral"] if denied else LxPalette.PAL["mauve"], 1)
	elif maxed:
		LxPixelFont.draw_right(self, LxStrings.text("SHOP_MAXED"), r.end.x - 6.0, r.position.y + 4.0, LxPalette.PAL["lime"], 1)
	else:
		var cost: int = int(costs[rank]) if rank < costs.size() else 0
		var c_col: Color = LxPalette.PAL["gold"] if affordable else LxPalette.PAL["coral"]
		LxPixelFont.draw_right(self, LxStrings.fmt("SHOP_COST_FMT", [cost]), r.end.x - 6.0, r.position.y + 4.0, c_col, 1)


func _draw_shard_preview_pill(desc_rect: Rect2, u: Dictionary, shards: int, unlocked: bool) -> void:
	var uid: String = str(u.get("id", ""))
	var rank: int = Lx.state.get_upgrade_rank(uid) if Lx.state != null else 0
	var max_rank: int = int(u.get("max_rank", 1))
	var costs: Array = u.get("costs", []) as Array
	var maxed: bool = rank >= max_rank
	var pill_h: float = 11.0
	var py: float = desc_rect.position.y + 6.0
	var pr_end: float = desc_rect.end.x - 5.0
	if not unlocked:
		var l_txt: String = LxStrings.text("SHOP_LOCKED_MOVE")
		var lw: float = float(LxPixelFont.width(l_txt, 1)) + 10.0
		var lpill := Rect2(pr_end - lw, py, lw, pill_h)
		LxPixelFont.draw_panel(self, lpill, "void", "coral", "night")
		LxPixelFont.draw_centered(self, l_txt, lpill.get_center().x, py + 3.0, LxPalette.PAL["coral"], 1)
		return
	if maxed:
		var m_txt: String = LxStrings.text("SHOP_MAXED")
		var mw: float = float(LxPixelFont.width(m_txt, 1)) + 10.0
		var pill := Rect2(pr_end - mw, py, mw, pill_h)
		LxPixelFont.draw_panel(self, pill, "void", "pine", "night")
		LxPixelFont.draw_centered(self, m_txt, pill.get_center().x, py + 3.0, LxPalette.PAL["lime"], 1)
		return
	var cost: int = int(costs[rank]) if rank < costs.size() else 0
	var affordable: bool = shards >= cost
	var before_txt: String = LxStrings.fmt("HUD_SHARDS_FMT", [shards])
	var after_txt: String = LxStrings.fmt("HUD_SHARDS_FMT", [shards - cost])
	var bw: float = float(LxPixelFont.width(before_txt, 1))
	var aw: float = float(LxPixelFont.width(after_txt, 1))
	var pill_w: float = 28.0 + bw + aw
	var pill := Rect2(pr_end - pill_w, py, pill_w, pill_h)
	LxPixelFont.draw_panel(self, pill, "void", "gold" if affordable else "coral", "night")
	var gx: float = pill.position.x + 4.0
	var gy: float = py + 3.0
	draw_rect(Rect2(gx + 1.0, gy, 1.0, 5.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(gx, gy + 1.0, 3.0, 3.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(gx + 1.0, gy + 1.0, 1.0, 2.0), LxPalette.PAL["cream"])
	var bx: float = gx + 6.0
	LxPixelFont.draw_left(self, before_txt, Vector2(bx, gy), LxPalette.PAL["stone"], 1)
	var ax: float = bx + bw + 3.0
	var arr_col: Color = LxPalette.PAL["apricot"] if affordable else LxPalette.PAL["coral"]
	draw_rect(Rect2(ax, gy + 2.0, 5.0, 1.0), arr_col)
	draw_rect(Rect2(ax + 3.0, gy + 1.0, 1.0, 3.0), arr_col)
	draw_rect(Rect2(ax + 2.0, gy, 1.0, 1.0), arr_col)
	draw_rect(Rect2(ax + 2.0, gy + 4.0, 1.0, 1.0), arr_col)
	LxPixelFont.draw_left(self, after_txt, Vector2(ax + 8.0, gy), LxPalette.PAL["gold"] if affordable else LxPalette.PAL["coral"], 1)


func _req_move_name(u: Dictionary) -> String:
	var req: String = str(u.get("requires_move", ""))
	if req.is_empty():
		return ""
	var mdata: Dictionary = Lx.get_move_data(req)
	var mkey: String = str(mdata.get("name_key", ""))
	if not mkey.is_empty() and LxStrings.has_id(mkey):
		return LxStrings.text(mkey)
	return LxStrings.sanitize(req, 16)


func _stat_delta_text(u: Dictionary) -> String:
	var uid: String = str(u.get("id", ""))
	var rank: int = Lx.state.get_upgrade_rank(uid) if Lx.state != null else 0
	var vals: Array = u.get("values", []) as Array
	var cur_v: float = _current_stat_val(uid)
	if rank >= vals.size():
		return LxStrings.fmt("SHOP_STAT_MAX_FMT", [_fmt_stat_val(uid, cur_v)])
	var nxt_v: float = float(vals[rank])
	return LxStrings.fmt("SHOP_DELTA_FMT", [_fmt_stat_val(uid, cur_v), _fmt_stat_val(uid, nxt_v)])


func _current_stat_val(uid: String) -> float:
	if Lx.state == null:
		return 0.0
	match uid:
		"bolt_damage": return Lx.state.get_effective_bolt_damage()
		"bolt_rate": return Lx.state.get_effective_bolt_cooldown()
		"throw_damage": return Lx.state.get_effective_throw_damage()
		"dash_cooldown": return Lx.state.get_effective_dash_cooldown()
		"prism_bounce": return float(Lx.state.get_effective_prism_bounces())
		"beam_charge": return Lx.state.get_effective_beam_charge()
		"wings_glide": return Lx.state.get_effective_wings_glide()
		"lens_duration": return Lx.state.get_effective_lens_duration()
		"ember_meter": return Lx.state.get_effective_ember_max()
	return 0.0


func _fmt_stat_val(uid: String, v: float) -> String:
	match uid:
		"prism_bounce":
			return str(roundi(v))
		"ember_meter":
			var base_e: float = float(Lx.get_move_data("sunflare").get("ember_max", 100.0))
			var eff_v: float = v if v > 0.0 else base_e
			return LxStrings.fmt("FMT_PCT", [roundi((base_e / maxf(1.0, eff_v)) * 100.0)])
		"wings_glide":
			return LxStrings.fmt("SHOP_UNIT_PX_FMT", [str(roundi(v))])
		"bolt_rate":
			var s3: String = "%.3f" % v
			if s3.ends_with("0"):
				s3 = s3.substr(0, s3.length() - 1)
			return LxStrings.fmt("SHOP_UNIT_SEC_FMT", [s3])
		"dash_cooldown", "beam_charge":
			return LxStrings.fmt("SHOP_UNIT_SEC_FMT", ["%.2f" % v])
		"lens_duration":
			return LxStrings.fmt("SHOP_UNIT_SEC_FMT", ["%.1f" % v])
		"throw_damage":
			var st: String = "%.2f" % v
			if st.ends_with("0"):
				st = st.substr(0, st.length() - 1)
			return st
		_:
			return "%.2f" % v


func _draw_frame_ornaments(isl: int) -> void:
	var p: Vector2 = PANEL_RECT.position
	var e: Vector2 = PANEL_RECT.end
	var gold: Color = LxBiomePalette.col(isl, "glow")
	var apr: Color = LxBiomePalette.col(isl, "hi")
	var dusk: Color = LxPalette.PAL["dusk"]
	var night: Color = LxPalette.PAL["night"]
	for rv: Vector2 in [
		Vector2(p.x + 3.0, p.y + 3.0), Vector2(e.x - 5.0, p.y + 3.0),
		Vector2(p.x + 3.0, e.y - 5.0), Vector2(e.x - 5.0, e.y - 5.0),
	]:
		draw_rect(Rect2(rv + Vector2(1.0, 1.0), Vector2(2.0, 2.0)), night)
		draw_rect(Rect2(rv, Vector2(2.0, 2.0)), apr)
		draw_rect(Rect2(rv, Vector2(1.0, 1.0)), gold)
	var dy: float = 35.0
	draw_rect(Rect2(28.0, dy, 264.0, 1.0), night)
	draw_rect(Rect2(32.0, dy, 256.0, 1.0), dusk)
	var x: float = 36.0
	while x < 284.0:
		draw_rect(Rect2(x, dy, 3.0, 1.0), apr if int(x) % 12 == 0 else dusk)
		x += 6.0
	draw_rect(Rect2(158.0, dy, 5.0, 1.0), apr)
	draw_rect(Rect2(159.0, dy - 1.0, 3.0, 3.0), gold)
	draw_rect(Rect2(160.0, dy, 1.0, 1.0), LxPalette.PAL["cream"])
	if not LxHudFx.flash_reduced():
		for ei: int in range(4):
			var eu: float = fposmod(_elapsed * 0.28 + float(ei) * 0.25, 1.0)
			var ex: float = (p.x + 3.0 + float(ei % 2) * 2.0) if ei < 2 else (e.x - 5.0 + float(ei % 2))
			var ey: float = roundf(e.y - 16.0 - eu * 116.0)
			var ea: float = sin(eu * PI) * 0.72
			if ea > 0.05:
				draw_rect(Rect2(ex, ey, 1.0, 1.0), Color((LxPalette.PAL["cream"] as Color) if ei % 2 == 0 else gold, ea))
	if Lx.state != null and not _upgrades.is_empty():
		var tot: Vector2i = Lx.state.get_upgrade_totals()
		if tot.y > 0 and tot.x >= tot.y:
			draw_rect(Rect2(158.0, dy, 5.0, 1.0), LxPalette.PAL["gold"])
			draw_rect(Rect2(160.0, dy - 2.0, 1.0, 5.0), LxPalette.PAL["gold"])
			draw_rect(Rect2(160.0, dy, 1.0, 1.0), LxPalette.PAL["cream"])


func _draw_brazier_icon(at: Vector2, isl: int) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	var fr: bool = LxHudFx.flash_reduced()
	var tip: float = 0.0 if (fr or fmod(_elapsed * 5.2, 1.0) < 0.5) else 1.0
	var flare: bool = _spark_t > 0.0
	var bright: bool = fr or flare or fmod(_elapsed * 2.6, 1.0) < 0.55
	var c_core: Color = LxBiomePalette.col(isl, "core")
	var c_glow: Color = LxBiomePalette.col(isl, "glow")
	var c_hi: Color = LxBiomePalette.col(isl, "hi")
	var c_mid: Color = LxBiomePalette.col(isl, "mid")
	if flare:
		draw_rect(Rect2(x + 3.0, y - 2.0, 1.0, 2.0), c_core)
		draw_rect(Rect2(x + 2.0, y - 1.0, 3.0, 2.0), c_glow)
		draw_rect(Rect2(x + 1.0, y - 2.0, 1.0, 1.0), c_glow)
		draw_rect(Rect2(x + 5.0, y - 2.0, 1.0, 1.0), c_core)
	draw_rect(Rect2(x + 2.0 + tip, y, 1.0, 1.0), c_core if bright else c_glow)
	draw_rect(Rect2(x + 2.0, y + 1.0, 3.0, 2.0), c_glow)
	draw_rect(Rect2(x + 3.0, y + 1.0, 1.0, 2.0), c_core)
	draw_rect(Rect2(x + 1.0, y + 2.0, 5.0, 2.0), c_hi)
	draw_rect(Rect2(x + 2.0, y + 2.0, 3.0, 2.0), c_glow)
	draw_rect(Rect2(x + 3.0, y + 3.0, 1.0, 1.0), c_core)
	draw_rect(Rect2(x, y + 4.0, 7.0, 1.0), c_mid)
	draw_rect(Rect2(x + 1.0, y + 5.0, 5.0, 1.0), c_hi)
	draw_rect(Rect2(x + 2.0, y + 6.0, 3.0, 1.0), LxPalette.PAL["dusk"])
	draw_rect(Rect2(x + 1.0, y + 7.0, 5.0, 1.0), LxPalette.PAL["night"])


func _draw_shard_gem_icon(at: Vector2) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	var glint: bool = LxHudFx.flash_reduced() or fmod(_elapsed * 2.2, 1.0) < 0.45
	draw_rect(Rect2(x + 3.0, y, 1.0, 1.0), LxPalette.PAL["cream"] if glint else LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 2.0, y + 1.0, 3.0, 1.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 1.0, y + 2.0, 5.0, 3.0), LxPalette.PAL["apricot"])
	draw_rect(Rect2(x + 2.0, y + 2.0, 3.0, 2.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(x + 2.0, y + 2.0, 1.0, 2.0), LxPalette.PAL["cream"])
	draw_rect(Rect2(x + 4.0, y + 3.0, 1.0, 2.0), LxPalette.PAL["coral"])
	draw_rect(Rect2(x + 2.0, y + 5.0, 3.0, 1.0), LxPalette.PAL["coral"])
	draw_rect(Rect2(x + 3.0, y + 6.0, 1.0, 1.0), LxPalette.PAL["wine"])
	if glint:
		draw_rect(Rect2(x + 5.0, y + 1.0, 1.0, 1.0), LxPalette.PAL["cream"])


func _draw_upgrade_icon(at: Vector2, uid: String, sel: bool, dimmed: bool = false) -> void:
	var x: float = roundf(at.x)
	var y: float = roundf(at.y)
	var rows: Array = UPGRADE_ICONS.get(uid, DEFAULT_ICON) as Array
	for r_i: int in range(rows.size()):
		var row: String = str(rows[r_i])
		for c_i: int in range(row.length()):
			var ch: String = row[c_i]
			if ch == ".":
				continue
			var key: String = ("mauve" if (ch == "c" or ch == "g" or ch == "i") else "dusk") if dimmed else str(ICON_PAL.get(ch, "cream"))
			draw_rect(Rect2(x + float(c_i), y + float(r_i), 1.0, 1.0), LxPalette.color(key))
	if sel and not dimmed and (LxHudFx.flash_reduced() or fmod(_elapsed * 3.0, 1.0) < 0.45):
		draw_rect(Rect2(x + 6.0, y, 1.0, 1.0), LxPalette.PAL["cream"])


func _draw_rank_pip(pr: Rect2, filled: bool, sel: bool, idx: int, next_buy: bool = false) -> void:
	var fr: bool = LxHudFx.flash_reduced()
	draw_rect(pr.grow(1.0), LxPalette.PAL["gold"] if (next_buy and (fr or fmod(_elapsed * 3.6, 1.0) < 0.55)) else (LxPalette.PAL["apricot"] if next_buy else LxPalette.PAL["void"]))
	if not filled:
		draw_rect(pr, LxPalette.PAL["night"])
		draw_rect(Rect2(pr.position.x + 1.0, pr.end.y - 1.0, 4.0, 1.0), LxPalette.PAL["dusk"])
		draw_rect(Rect2(pr.end.x - 1.0, pr.position.y + 1.0, 1.0, 4.0), LxPalette.PAL["dusk"])
		draw_rect(Rect2(pr.position.x + 2.0, pr.position.y + 2.0, 1.0, 1.0), LxPalette.PAL["gold"] if next_buy else LxPalette.PAL["dusk"])
		return
	var shimmer: bool = fr or fmod(_elapsed * 2.5 + float(idx) * 0.35, 1.0) < 0.4
	draw_rect(pr, LxPalette.PAL["apricot"])
	draw_rect(Rect2(pr.position.x + 1.0, pr.position.y, 3.0, 5.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(pr.position.x, pr.position.y + 1.0, 5.0, 3.0), LxPalette.PAL["gold"])
	draw_rect(Rect2(pr.position.x + 2.0, pr.position.y + 2.0, 1.0, 1.0), LxPalette.PAL["cream"])
	if shimmer or sel:
		draw_rect(Rect2(pr.position.x + 2.0, pr.position.y + 1.0, 1.0, 3.0), LxPalette.PAL["cream"])


func _draw_purchase_sparkle(center: Vector2) -> void:
	var isl: int = Lx.state.island_id if Lx.state != null else 1
	var prog: float = clampf(1.0 - (_spark_t / SPARK_DUR), 0.0, 1.0)
	var dist: float = roundf(3.0 + prog * 7.0)
	var d_diag: float = roundf(dist * 0.7)
	var col: Color = (LxPalette.PAL["cream"] as Color) if prog < 0.3 else (LxBiomePalette.col(isl, "glow") if prog < 0.65 else LxBiomePalette.col(isl, "hi"))
	var dirs: Array[Vector2] = [
		Vector2(dist, 0.0), Vector2(-dist, 0.0), Vector2(0.0, dist), Vector2(0.0, -dist),
		Vector2(d_diag, d_diag), Vector2(-d_diag, d_diag), Vector2(d_diag, -d_diag), Vector2(-d_diag, -d_diag),
	]
	if prog < 0.35:
		draw_rect(Rect2(center - Vector2(3.0, 3.0), Vector2(7.0, 1.0)), LxPalette.PAL["cream"])
		draw_rect(Rect2(center + Vector2(-3.0, 3.0), Vector2(7.0, 1.0)), LxPalette.PAL["cream"])
	for off: Vector2 in dirs:
		draw_rect(Rect2((center + off).round(), Vector2(1.0, 1.0)), col)


func _row_rect(vis_i: int) -> Rect2:
	return Rect2(28.0, 38.0 + float(vis_i) * 15.0, 257.0 if _upgrades.size() > VISIBLE_ROWS else 264.0, 13.0)

func _close_btn_rect() -> Rect2: return Rect2(230.0, 154.0, 62.0, 11.0)
func _play_ui_sfx(sfx_id: String) -> void:
	if Lx.audio != null: Lx.audio.play_sfx(sfx_id, Vector2.ZERO, false, true)
static func _key_just(event: InputEvent, kc: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == kc
